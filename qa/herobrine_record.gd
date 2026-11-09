extends SceneTree
## Diagnostic phase selection; real-health duel runs are herobrine_runs.gd.
var game
var frame=0
var timeline={}
func _initialize():run.call_deferred()
func shot():
	var phase: String=game.world.finale.phase
	if not timeline.has(phase):timeline[phase]=frame/30.0
	game.queue_redraw();await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://qa/recordings/herobrine_frames/%05d.png" % frame)
	frame+=1
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_process(false);game.set_physics_process(false);game.qa_mode="film"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.settings.shake=false
	DirAccess.make_dir_recursive_absolute("res://qa/recordings/herobrine_frames")
	game.action("chapter_1");game.world.reset(724);game.world.build={}
	game.world.finale.begin(game.world)
	for i in range(12*30):
		game.world.step(1.0/30,Vector2.from_angle(i*.013)*.3 if i>120 else Vector2.ZERO)
		await shot()
	# Only the recording skips the rest of the ordinary first-stage fight.
	game.world.finale.boss.hp=0
	while not game.world.finale.complete:
		game.world.step(1.0/30);await shot()
	for i in range(45):await shot()
	FileAccess.open("res://qa/recordings/herobrine_timeline.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":30,"frames":frame,"phase_start_seconds":timeline,"diagnostic_first_stage_kill":true,"audio":"Herobrine theme only. The optional first-stage win has no victory cue."},"  "))
	game.audio.shutdown();await create_timer(.15).timeout;game.free();game=null
	print("HEROBRINE_FILM_FRAMES ",frame);quit()
