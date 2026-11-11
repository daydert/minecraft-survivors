extends SceneTree
## Diagnostic film: the sword at each chapter's spawn, the melted gear (II),
## the last exchange with Ender Steve (III) and the gear spilling on death (I).
var game
var folder:="res://qa/recordings/start_gear_frames"
var state:={"frame":0,"cues":[],"music":[]}
func _initialize():run.call_deferred()
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game.settings.shake=true;game.settings.numbers=false
	for chapter in [2,3,4,5]:
		game.action("chapter_%d"%chapter);var w=game.world
		w.begin_sword_drop()
		while not w.sword_ready():w.step(1.0/60)
		await run_for(w,w.SWORD_LAND[w.sword_drop.style]+.8,Vector2.ZERO)
		while w.sword_waiting():await tick(w,w.player.direction_to(w.sword_drop.p)*.7)
		await run_for(w,1.2,Vector2.ZERO)
	game.action("chapter_2");var n=game.world
	n.build={"sword":6,"bow":4,"trident":3};n.items={"armor":2,"sugar":1}
	n.begin_arena()
	while n.stage!="wither":n.step(1.0/60)
	await run_for(n,1.0,Vector2.ZERO)
	var boss=n.mobs.filter(func(m):return m.kind=="wither")[0]
	boss.hp=1;n.hurt(boss,10);n.resolve_deaths()
	while n.stage=="defeat":await tick(n,Vector2.ZERO)
	await run_for(n,1.0,Vector2.ZERO)
	game.action("chapter_3");var e=game.world
	e.prepare_arena();e.mobs.clear();e.stage="last_duel"
	for crystal in e.crystals:crystal.alive=false
	e.spawn("endersteve_final",e.portal_position+Vector2(0,-35));e.player=e.portal_position+Vector2(40,-30)
	await run_for(e,.6,Vector2.ZERO)
	e.mobs[0].hp=0;e.resolve_deaths()
	while e.stage in ["clash","down","to_edge"]:await tick(e,Vector2.ZERO)
	while e.stage=="sit" and e.stage_age<29.5:e.step(1.0/60)
	while e.stage=="sit":await tick(e,Vector2.ZERO)
	game.action("chapter_1");var o=game.world;o.skip_intro()
	o.build={"sword":5,"bow":3};o.items={"armor":2}
	o.finale.begin(o);o.finale.skip_to_fight(o);o.step(.1)
	o.invulnerable=0;o.hp=0
	while o.finale.phase!="fall":await tick(o,Vector2.ZERO)
	var timeline={"fps":30,"frames":state.frame,"sound_events":state.cues,"music":[]}
	FileAccess.open("res://qa/recordings/start_gear_timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline,"  "))
	game.audio.shutdown();game.quitting=true
	print("START_GEAR_FILM ",state.frame," frames");quit()
func run_for(w,seconds: float,move: Vector2):
	for f in range(int(seconds*30)):await tick(w,move)
func tick(w,move: Vector2):
	for i in range(2):
		if w.state=="LEVEL_UP":w.choose(0)
		if w.state=="CHEST":w.chest_delay=0;w.close_chest()
		w.step(1.0/60,move)
	await shoot(w)
func shoot(w):
	for id in w.sounds:state.cues.append({"id":id,"time":state.frame/30.0})
	w.sounds.clear()
	game.ui_time+=1.0/30
	game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+"/%05d.png"%state.frame);state.frame+=1
