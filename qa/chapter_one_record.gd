extends SceneTree
## Diagnostic film of the reworked chapter I: the walk-in through the party
## gate, Herobrine's greeting and dodges, the rebuilt throne, a villager wrung
## into a crawler, the canonical "fun" punch and the secret deflection.
var game
var folder:="res://qa/recordings/chapter_one_frames"
var state:={"frame":0,"cues":[],"music":[],"last_music":""}
func _initialize():run.call_deferred()
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game.action("chapter_1");var w=game.world;game.settings.shake=true;game.settings.numbers=false
	while w.state=="INTRO":await tick(w,Vector2.ZERO)
	await run_for(w,2.0,Vector2.UP*.6)
	w.build={"sword":7,"bow":5};w.items={"armor":3}
	w.finale.begin(w)
	while w.finale.phase!="tease":await tick(w,Vector2.ZERO)
	while w.finale.phase=="tease":await tick(w,((w.finale.hb_p+Vector2(0,30)-w.player)/40.0).limit_length())
	while w.finale.phase!="storm":await tick(w,Vector2.ZERO)
	w.invulnerable=999
	var f0: float=w.finale.fight_age
	while w.finale.fight_age<f0+10.5:await tick(w,Vector2.from_angle(w.clock*.8)*.5)
	while w.mobs.any(func(m):return m.kind=="ch1_crawler") and w.finale.fight_age<f0+14:await tick(w,Vector2.ZERO)
	await run_for(w,1.0,Vector2.ZERO)
	w.invulnerable=0;w.hp=0
	while not w.finale.complete:await tick(w,Vector2.ZERO)
	for i in range(30):await shoot(w)
	# Secret ending.
	game.action("chapter_1");w=game.world;w.skip_intro();w.finale.begin(w)
	while w.finale.phase!="storm":
		if w.finale.phase=="arrival" or w.finale.phase=="greet":w.finale.phase_age+=.1
		if w.finale.phase=="tease":w.finale.begin_throne(w)
		w.step(1.0/60)
	w.finale.fight_age=1.0
	await run_for(w,1.5,Vector2.ZERO)
	w.finale.boss.hp=0
	while not w.finale.complete:await tick(w,Vector2.ZERO)
	for i in range(30):await shoot(w)
	var timeline={"fps":30,"frames":state.frame,"sound_events":state.cues,"music":state.music}
	FileAccess.open("res://qa/recordings/chapter_one_timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline,"  "))
	game.audio.shutdown();game.quitting=true
	print("CHAPTER_ONE_FILM ",state.frame," frames");quit()

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
	var theme: String="herobrine" if w.finale.active and not w.finale.complete else "music"
	if w.finale.active and w.finale.phase in ["descend"] and w.finale.phase_age>w.finale.WHISPER[0]-.2 and w.finale.phase_age<w.finale.WHISPER[1]:theme="silence"
	if theme!=state.last_music:state.last_music=theme;state.music.append({"track":theme,"time":state.frame/30.0})
	game.ui_time+=1.0/30
	game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+"/%05d.png"%state.frame);state.frame+=1
