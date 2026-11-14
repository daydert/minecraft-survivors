extends SceneTree
## Diagnostic film of the reworked EnderSteve finale (2026-11-14): the portal break,
## fight one (Projection, the clock), Return by Death, fight two (the Loop), the clash,
## the race for the sword, mercy, the talk by the portal; then the bad ending.
## Scripted moves and kills; HP is held up between hits. Sounds are the game's own.
var game
var folder:="res://qa/recordings/ch3_finale_frames"
var state:={"frame":0,"cues":[],"music":[],"last_music":""}
func _initialize():run.call_deferred()
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game.action("chapter_3");var w=game.world;game.settings.shake=true
	w.build={"sword":6,"mace":6,"spear":5};w.items={"armor":3,"elytra":2}
	w.damage_by={"mace":40000.0,"sword":9000.0}
	w.state="RUNNING";w.prepare_arena();w.mobs.clear();w.crystals.clear();w.portal_lit=true;w.stage="exit_portal";w.player=w.portal_position+Vector2(0,110)
	while w.stage=="exit_portal":await tick(w,w.player.direction_to(w.portal_position))
	while w.stage!="last_duel":await tick(w,Vector2.ZERO)
	var b=w.steve_boss;var m=boss(w)
	await run_for(w,6.0,"orbit")
	# Projection: the hero stands still and is caught in the frame.
	m=boss(w);w.player=m.p+Vector2(0,120);b.begin(w,m,b.PROJECTION)
	while w.framed<=0 and m.phase!="winded":await tick(w,Vector2.ZERO)
	while w.framed>0 or m.phase=="framed_strike":await tick(w,Vector2.ZERO)
	await run_for(w,2.0,"orbit")
	# The clock: hit him hard and he turns time back.
	m=boss(w);m.hp=m.max_hp*.58;m.phase="walk";m.timer=0
	while m.get("clock",{}).get("state","")!="running":await tick(w,Vector2.ZERO)
	await run_for(w,2.5,"orbit")
	m.phase="recover";m.timer=1;w.damage_owner="mace";w.hurt(m,m.max_hp*.14)
	while m.get("clock",{}).get("state","")=="rewind" or m.get("clock",{}).get("state","")=="running":await tick(w,Vector2.ZERO)
	await run_for(w,3.0,"orbit")
	m=boss(w);m.clock={"state":"spent"};m.clocks=1;m.hp=1;m.phase="recover";w.damage_owner="mace";w.hurt(m,50)
	while w.stage!="last_duel":await tick(w,Vector2.ZERO)
	await run_for(w,5.0,"orbit")
	m=boss(w);m.phase="windup";m.pattern=b.LOOP;m.timer=0;m.history=[0,4,5]
	await run_for(w,3.5,"orbit")
	m=boss(w);m.hp=1;m.phase="recover";w.hurt(m,50)
	while w.stage!="sword_race":await tick(w,Vector2.ZERO)
	await race(w,true)
	while w.stage!="portal_ready":await tick(w,Vector2.ZERO)
	await run_for(w,.6,"")
	while w.stage=="portal_ready":await tick(w,w.player.direction_to(w.portal_position))
	for i in range(75):await tick(w,Vector2.ZERO)
	# The bad ending, from the duel's checkpoint.
	w.state="RUNNING";w.restore_duel_checkpoint("fight2");w.stage="last_duel"
	m=boss(w);m.hp=1;m.phase="recover";w.hurt(m,50)
	while w.stage!="sword_race":await tick(w,Vector2.ZERO)
	await race(w,false)
	while w.stage!="bad_card":await tick(w,Vector2.ZERO)
	for i in range(90):await tick(w,Vector2.ZERO)
	var timeline={"fps":30,"frames":state.frame,"sound_events":state.cues,"music":state.music,"diagnostic":"scripted duel, HP held up"}
	FileAccess.open("res://qa/recordings/ch3_finale_timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline,"  "))
	game.audio.shutdown();game.quitting=true
	print("CH3_FINALE_FILM ",state.frame," frames");quit()

func boss(w):
	for v in w.mobs:
		if v.kind=="endersteve_final" and v.hp>0:return v
	return {}

func race(w, good: bool):
	var q=w.sword_race;var t:=0.0
	while w.stage=="sword_race":
		t+=1.0/30
		if good and q.live():
			match q.beat:
				0:if fmod(t,.1)<1.0/30:q.press("attack")
				1:if q.age>.55:q.press(q.dir)
				2:if q.age>=.9:q.press("attack")
		elif not good and q.live() and q.beat==0 and fmod(t,.25)<1.0/30:q.press("attack")
		await tick(w,Vector2.ZERO)

func run_for(w,seconds: float,mode: String):
	for f in range(int(seconds*30)):
		var move:=Vector2.ZERO
		if mode=="orbit":
			var m=boss(w)
			if not m.is_empty():
				var target: Vector2=m.p+m.p.direction_to(w.player).rotated(.6*sin(f/30.0*.7))*95
				move=((target-w.player)/30.0).limit_length()
		await tick(w,move)

func tick(w,move: Vector2):
	for i in range(2):
		if w.state=="LEVEL_UP":w.skip_reward()
		if w.state=="CHEST":w.chest_delay=0;w.close_chest()
		if w.stage=="last_duel":w.hp=maxf(w.hp,11)
		w.step(1.0/60,move)
	await shoot(w)

func shoot(w):
	for id in w.sounds:state.cues.append({"id":id,"time":state.frame/30.0})
	w.sounds.clear()
	var theme: String="victory" if w.win_music else "endersteve" if w.stage in ["last_arrival","last_duel"] else "relic" if w.stage in ["talk","restore","portal_ready","exit_jump","chapter_four"] else "silence"
	if theme!=state.last_music:state.last_music=theme;state.music.append({"track":theme,"time":state.frame/30.0})
	game.ui_time+=1.0/30;game.update_camera_lead()
	game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+"/%05d.png"%state.frame);state.frame+=1
