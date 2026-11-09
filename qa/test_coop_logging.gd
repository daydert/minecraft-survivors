extends SceneTree
const Diagnostics = preload("res://scripts/coop_diagnostics.gd")
var checks = 0
var failures: Array = []

func _initialize(): run.call_deferred()

func check(ok: bool, label: String):
	checks += 1
	if ok: print("PASS: "+label)
	else: failures.append(label); push_error(label)

func run():
	var directory = "user://qa_diagnostics_"+str(OS.get_process_id())
	var logger = Diagnostics.new()
	logger.directory = directory
	logger.max_file_bytes = 1024
	logger.max_history_files = 1000
	logger.start({"role":"peer","nick":"Друг_тест","protocol":"test"})
	for i in range(100): logger.event("ordered",{"index":i,"text":"данные для проверки ".repeat(5)})
	for value in [10.0,50.0,100.0]: logger.measure("frame_ms",value)
	logger.count("packets",7)
	logger.sample({"tick":120,"epoch":1})
	logger.limited_event("position_correction",{"px":5},10000)
	logger.limited_event("position_correction",{"px":6},10000)
	logger.event("session_end",{"reason":"test"})
	logger.close()
	check(not logger.enabled and logger.writer_status().error.is_empty(),"Async writer drains and closes without an I/O error")
	var rows: Array = []
	var files: Array = Array(DirAccess.get_files_at(directory))
	files.sort()
	var cap_ok = true
	var valid = true
	for name in files:
		var path = directory.path_join(name)
		cap_ok = cap_ok and FileAccess.get_file_as_bytes(path).size() <= 1024
		for line in FileAccess.get_file_as_string(path).split("\n",false):
			var value = JSON.parse_string(line)
			if not value is Dictionary or not value.has("event"): valid = false
			else: rows.append(value)
	check(files.size() > 1 and cap_ok,"Rotation respects the configured byte limit for every UTF-8 file")
	check(valid and files.all(func(n):return not n.ends_with(".active.jsonl")),"Every completed file is valid JSONL and marked closed")
	var ordered = rows.filter(func(r):return r.event == "ordered")
	check(ordered.size() == 100 and range(100).all(func(i):return ordered[i].index == i),"Queued records keep their order across rotations and close")
	var samples = rows.filter(func(r):return r.event == "sample")
	check(samples.size() == 1 and samples[0].metrics.frame_ms.max == 100 and samples[0].metrics.frame_ms.p95 == 100 and samples[0].counters.packets == 7,"Sampling preserves frame spikes, percentile and packet counters")
	check(rows.filter(func(r):return r.event == "position_correction").size() == 1,"Repeated correction events are rate limited")
	check(rows.any(func(r):return r.event == "session_end"),"Session footer survives immediate writer shutdown")
	FileAccess.open(directory.path_join("foreign.txt"),FileAccess.WRITE).store_string("keep")
	logger.max_history_files = 3
	logger.start({"role":"host","nick":"Ведущий"})
	logger.event("session_end")
	logger.close()
	var final_files: Array = Array(DirAccess.get_files_at(directory))
	check(final_files.filter(func(n):return n.begins_with(Diagnostics.PREFIX)).size() <= 3 and final_files.has("foreign.txt"),"History pruning is bounded and preserves unrelated files")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false);game.set_process(false)
	game.set_physics_process(false)
	game.coop.diagnostics.directory = directory
	check(game.coop.host("Ведущий"),"Hosting starts local diagnostics automatically")
	game.world = load("res://scripts/coop_world.gd").new(724)
	game.world.configure(724,{1:"Ведущий",2:"Друг",3:"Друг_2",4:"Друг_3"},1)
	game.coop.running = true
	game.screen = ""
	var prefix = game.coop.diagnostics.file_prefix
	var clock = game.world.clock
	var rng_state = game.world.rng.state
	var e = InputEventKey.new()
	e.keycode = KEY_F8
	e.pressed = true
	game._input(e)
	check(game.world.clock == clock and game.world.rng.state == rng_state and game.world.can_step(),"F8 records a marker without pausing combat or consuming gameplay RNG")
	game.coop.leave()
	var marked = false
	for name in DirAccess.get_files_at(directory):
		if not name.begins_with(prefix.get_file()): continue
		for line in FileAccess.get_file_as_string(directory.path_join(name)).split("\n",false):
			var row = JSON.parse_string(line)
			if row.event == "user_marker": marked = row.actors.size() == 4 and row.epoch == 0
	check(marked,"The actual F8 marker contains all four identities and the epoch")
	game.audio.shutdown()
	await create_timer(.6).timeout
	game.free()
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	FileAccess.open("res://qa/coop_logging_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	quit(0 if failures.is_empty() else 1)
