extends SceneTree
var game
var frame=0
var timeline={}
var sound_events=[]
func _initialize():run.call_deferred()
func shot():
	if not timeline.has(game.world.stage):timeline[game.world.stage]=frame/30.0
	for id in game.world.sounds:
		if game.world.stage=="arrival" and (id.begins_with("ghast_intro_") or id in ["herobrine","wither_charge"]):sound_events.append({"id":id,"time":frame/30.0})
	game.world.sounds.clear()
	game.queue_redraw();await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://qa/recordings/wither_frames/%05d.png" % frame)
	frame+=1
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_process(false);game.set_physics_process(false);game.qa_mode="film"
	root.size=Vector2i(640,360);game.settings.shake=false
	DirAccess.make_dir_recursive_absolute("res://qa/recordings/wither_frames")
	game.action("chapter_2");game.world.reset(724);game.world.state="RUNNING"
	game.world.time=719.9;game.world.build={}
	game.world.step(.1)
	for i in range(190):
		game.world.step(1.0/30);await shot()
	var bot=load("res://qa/nether_bot.gd").new()
	var movement=Vector2.ZERO
	for i in range(900):
		# Diagnostic recording only. Real damage is exercised by nether_runs.gd.
		if i==390:
			game.world.mobs[0].hp=game.world.mobs[0].max_hp*.49
			timeline.phase_two=frame/30.0
		game.world.invulnerable=1
		if i%5==0:movement=bot.boss_movement(game.world,false)
		game.world.step(1.0/30,movement)
		await shot()
	timeline.victory=frame/30.0
	game.world.mobs[0].hp=0;game.world.resolve_deaths()
	while game.world.stage=="defeat":game.world.step(1.0/30);await shot()
	var pearl_position: Vector2=game.world.loot.filter(func(o):return o.kind=="ender_eye")[0].p
	while not game.world.pearl and game.world.stage=="portal":
		game.world.step(1.0/30,game.world.player.direction_to(pearl_position));await shot()
	while game.world.stage not in ["end"]:
		var portal_movement=Vector2.ZERO
		if game.world.stage=="portal":portal_movement=game.world.player.direction_to(game.world.portal_position)
		game.world.step(1.0/30,portal_movement);await shot()
	for i in range(30):await shot()
	FileAccess.open("res://qa/recordings/wither_timeline.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":30,"frames":frame,"events":timeline,"sound_events":sound_events,"artificial_invulnerability":true,"diagnostic_phase_switch_and_kill":true},"  "))
	game.audio.shutdown();await create_timer(.15).timeout;game.free();game=null
	print("WITHER_FILM_FRAMES ",frame);quit()
