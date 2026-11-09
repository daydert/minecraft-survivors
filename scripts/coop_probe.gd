extends Node
## Real separate-process ENet exercise. Driven by test_network.py's UDP proxy.
var game
var root: Window
var role = "host"
var scenario = "story"
var port = 24767
var report_path = ""
var started = -1.0
var boot = 0.0
var stages: Dictionary = {}
var checks: Dictionary = {}
var samples: Array = []
var sim_ms: Array = []
var last_position = Vector2.ZERO
var max_step = 0.0
var paused_clock = -1.0
var finishing = false
var traveled = 0.0
var simulation_samples: Array = []
var snapshot_samples: Array = []
var present_samples: Array = []
var frame_samples: Array = []
var visual = false
var party_size = 2
var seat = 0
var start_positions: Dictionary = {}
var seen_inputs: Dictionary = {}
var previous_clock = -1.0
var ready_path = ""
var paused_observed_at = -1.0
var last_ui_action = -1.0

func _ready(): run.call_deferred()

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.get_slice("=",1)
		if arg.begins_with("--scenario="): scenario = arg.get_slice("=",1)
		if arg.begins_with("--test-port="): port = arg.get_slice("=",1).to_int()
		if arg.begins_with("--report="): report_path = arg.get_slice("=",1)
		if arg.begins_with("--ready-file="): ready_path = arg.get_slice("=",1)
		if arg.begins_with("--players="): party_size = arg.get_slice("=",1).to_int()
		if arg.begins_with("--seat="): seat = arg.get_slice("=",1).to_int()
		if arg == "--visual": visual = true
	if role != "host" and seat == 0: seat = 1
	root = get_tree().root
	if visual:
		# Four windows share one compositor in QA. Use a common 60 Hz budget
		# instead of mixing the focused window's vsync with background pacing.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 60
	game.set_physics_process(false)
	game.set_process(false)
	game.screen = "multiplayer"
	boot = Time.get_ticks_msec()/1000.0
	if role == "host": game.coop.host(nick_for_seat(0),port)
	else: game.coop.join("127.0.0.1",nick_for_seat(seat),port)

func nick_for_seat(index: int) -> String:
	return "Ведущий" if index == 0 else ("Друг" if index == 1 else "Друг_"+str(index))

func id_for_seat(index: int) -> int:
	for id in game.coop.roster:
		if game.coop.roster[id] == nick_for_seat(index): return id
	return 0

func _process(dt: float):
	if game and visual and game.coop.running:
		game.queue_redraw()
		if started > 0 and Time.get_ticks_msec()/1000.0-started > 1: frame_samples.append(dt*1000)
	return

func once(key: String, condition: bool) -> bool:
	if not condition or stages.has(key): return false
	stages[key] = true
	return true

func _physics_process(dt):
	if not game or finishing: return
	var net = game.coop
	var now_value = Time.get_ticks_msec()/1000.0
	if now_value-boot > 24:
		checks.timeout = false
		finish()
		return
	if role == "host" and net.roster.size() == party_size and not net.running and not net.loading: net.start_run(724)
	if net.loading: checks.loading_barrier = game.world.time == 0
	if scenario == "host_leave" and seat > 0 and started >= 0 and not net.active:
		checks.server_lost = game.world.state == "MENU" and game.screen == "multiplayer" and not net.status.is_empty()
		finish()
		return
	if not net.running: return
	if started < 0:
		started = now_value
		last_position = game.world.player
		if role == "host" and not ready_path.is_empty(): FileAccess.open(ready_path,FileAccess.WRITE).store_string("ready")
	var elapsed = now_value-started
	var w = game.world
	if once("log_marker",elapsed > 3.1): net.mark_lag()
	if once("started",true):
		checks.connected = w.players.size() == party_size
		checks.own_identity = w.players[w.local_id].nick == nick_for_seat(seat)
		if role == "host":
			checks.loaded_all = net.awaiting_loaded.is_empty() and net.input_streams.size() == party_size-1
			for id in w.players:
				start_positions[id] = w.players[id].player
				w.use_actor(id)
				w.invulnerable = 100000
				w.build = {"sword":4,"bow":5,"trident":4,"fire":3,"potion":2,"fangs":3}
				w.cooldowns = {}
			w.use_actor(1)
			if scenario == "stress":
				for i in range(500): w.spawn("zombie",Vector2(700+i%30*10,700+i/30*10))
			else:
				for i in range(65): w.spawn(["zombie","skeleton","creeper","vindicator"][i%4],w.player+Vector2.from_angle(i*2.39)*200)
	if seat == 1:
		if once("pause",elapsed > 2): net.command("pause",1)
		if w.state == "PAUSED" and paused_clock < 0:
			paused_clock = w.clock
			paused_observed_at = now_value
		if once("unpause",elapsed > 2.8 and paused_clock >= 0 and now_value-paused_observed_at >= .25):
			checks.pause = paused_clock >= 0 and is_equal_approx(paused_clock,w.clock)
			net.command("pause",0)
	elif seat > 1 and w.state == "WAITING" and w.clock == previous_clock:
		checks.common_pause = true
	previous_clock = w.clock
	if w.state in ["LEVEL_UP","CHEST"] and now_value-last_ui_action >= .2:
		net.command("choice" if w.state == "LEVEL_UP" else "chest",0)
		last_ui_action = now_value
	if role == "host":
		if scenario == "host_leave" and elapsed > 4.5:
			checks.clean_leave = true
			finish()
			return
		if once("moved",elapsed > 4):
			checks.remote_moved = net.remote_ids().all(func(id): return w.players[id].player.distance_to(start_positions[id]) > 10)
			checks.independent_inputs = seen_inputs.size() == party_size-1
		if scenario == "disconnect":
			if once("disconnect_check",elapsed > 6):
				checks.disconnect_life = not w.players[id_for_seat(1)].alive and w.players[1].alive and w.mob_multiplier == 2
				checks.other_guests_survive = w.players.values().all(func(a):return a.nick == nick_for_seat(1) or a.alive)
			if elapsed > 8.5:
				finish()
				return
		elif scenario in ["story","host_dead","restart"]:
			if once("kill_guest",elapsed > 5):
				w.use_actor(1 if scenario == "host_dead" else id_for_seat(1))
				w.hp = 0
				w.use_actor(1)
			if once("finale",elapsed > 6): w.time = 719.99
			if once("inferno",elapsed > 8): w.finale.elapsed = 13
			if once("collapse",elapsed > 9): w.finale.elapsed = 24
			if once("fall",elapsed > 10): w.finale.elapsed = 29
			if once("end",elapsed > 11): w.finale.elapsed = 34
			if scenario == "restart" and once("restart",elapsed > 12):
				checks.first_ending = w.finale.complete
				net.start_run(725)
			if scenario == "restart" and once("restart_checked",elapsed > 13):
				checks.clean_restart = net.epoch == 2 and not w.finale.active and w.players.values().all(func(a):return a.alive) and w.time < 4
			if scenario == "restart" and once("restart_done",elapsed > 16):
				finish()
				return
			if scenario != "restart" and once("finish",elapsed > 13):
				checks.canonical_end = w.finale.complete and w.hp == 0 and not w.victory
				finish()
				return
		elif once("stress_end",elapsed > 8):
			checks.stress_cap = w.normal_count() <= 500
			finish()
			return
	else:
		if once("spectator",elapsed > 5.6) and scenario in ["story","restart"]:
			checks.spectator = not w.players[w.local_id].alive and w.state in ["SPECTATING","WAITING","FINALE"] if seat == 1 else w.players[w.local_id].alive and not w.players[id_for_seat(1)].alive
		if once("host_dead",elapsed > 5.6) and scenario == "host_dead": checks.surviving_guest = not w.players[1].alive and w.players[w.local_id].alive
		if once("finale_check",elapsed > 7) and scenario in ["story","restart","host_dead"]: checks.finale = w.finale.active and (w.players[w.local_id].in_finale == (scenario == "host_dead" or seat > 1))
		if scenario in ["story","host_dead"] and w.finale.complete:
			checks.canonical_end = w.finale.complete and not w.victory
			finish()
			return
		if scenario == "restart" and elapsed > 14:
			checks.clean_restart = net.epoch == 2 and not w.finale.active and w.players[w.local_id].alive and w.time < 4 and w.mobs.size() < 20
			finish()
			return
		if scenario == "stress" and net.main_tick >= 390:
			checks.entities = net.received_buckets > 100 and not w.mobs.is_empty()
			finish()
			return
		if scenario == "disconnect" and seat == 1 and elapsed > 4.5:
			checks.clean_leave = true
			finish()
			return
		if scenario == "disconnect" and seat > 1 and elapsed > 7.5:
			checks.sibling_disconnect = not w.players[id_for_seat(1)].alive and w.players[w.local_id].alive
			finish()
			return
	var movement = Vector2.from_angle(elapsed*.9+(seat-1)*TAU/maxi(1,party_size-1)) if seat > 0 else Vector2.from_angle(elapsed*.9)*-.5
	var begin = Time.get_ticks_usec()
	net.tick(dt,movement)
	if role == "host":
		for id in net.input_streams:
			if net.input_streams[id].ack > 0: seen_inputs[id] = true
		simulation_samples.append(net.last_sim_ms)
		snapshot_samples.append(net.last_snapshot_ms)
	sim_ms.append((Time.get_ticks_usec()-begin)/1000.0)
	var present_begin = Time.get_ticks_usec()
	net.present(dt)
	present_samples.append((Time.get_ticks_usec()-present_begin)/1000.0)
	game.world.sounds.clear()
	if seat > 0 and elapsed > 1 and elapsed < 4.8:
		var distance: float = last_position.distance_to(w.player)
		max_step = maxf(max_step,distance)
		traveled += distance
	last_position = w.player

	return

func finish():
	if finishing: return
	finishing = true
	var net = game.coop
	var ordered: Array = sim_ms.duplicate()
	ordered.sort()
	var corrections: Array = net.corrections.duplicate()
	corrections.sort()
	simulation_samples.sort()
	snapshot_samples.sort()
	present_samples.sort()
	frame_samples.sort()
	var report = {"role":role,"scenario":scenario,"checks":checks,"received_frames":net.received_frames,"received_buckets":net.received_buckets,"max_render_step":max_step,"traveled":traveled,"bytes_sent":net.bytes_sent,"max_bucket_bytes":net.max_bucket_bytes,"p95_sim_ms":ordered[int(ordered.size()*.95)] if not ordered.is_empty() else 0,"p95_correction":corrections[int(corrections.size()*.95)] if not corrections.is_empty() else 0,"max_correction":corrections.back() if not corrections.is_empty() else 0}
	report.players = party_size
	report.seat = seat
	report.diagnostics = net.correction_diagnostics
	report.input_packets = net.input_packets
	if not present_samples.is_empty(): report.p95_present_ms = present_samples[int(present_samples.size()*.95)]
	if not frame_samples.is_empty(): report.p95_frame_ms = frame_samples[int(frame_samples.size()*.95)]
	if net.peer and not net.hosting:
		report.enet_throttle = net.peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)
	if not simulation_samples.is_empty():
		report.p95_world_ms = simulation_samples[int(simulation_samples.size()*.95)]
		report.p95_snapshot_ms = snapshot_samples[int(snapshot_samples.size()*.95)]
	if seat > 0 and scenario not in ["disconnect","host_leave"]:
		checks.no_movement_teleports = max_step < 12
		checks.receives_authority = net.received_frames > (20 if scenario == "restart" else 40)
	if seat == 1: checks.pause_observed = stages.has("unpause")
	report.diagnostic_prefix = net.diagnostics.file_prefix
	net.leave()
	report.diagnostic_writer = net.diagnostics.writer_status()
	checks.diagnostics_saved = FileAccess.file_exists(report.diagnostic_prefix+"_000.jsonl") and report.diagnostic_writer.error.is_empty() and report.diagnostic_writer.dropped == 0
	if not report_path.is_empty(): FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("NETWORK_RESULT ",JSON.stringify(report))
	game.audio.shutdown()
	await get_tree().create_timer(.6).timeout
	var tree = get_tree()
	var exit_code = 0 if checks.values().all(func(value): return value) else 1
	tree.create_timer(.1).timeout.connect(tree.quit.bind(exit_code))
	game.queue_free()
