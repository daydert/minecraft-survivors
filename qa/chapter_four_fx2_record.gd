extends SceneTree
## Diagnostic film of the second IV pass: ground, last-minutes tremors, elite
## entrance, evolution scene, golem and guardian (bosses: invulnerable hero).
func _initialize():run.call_deferred()
var game
var folder:="res://qa/recordings/chapter_four_fx_frames"
var state:={"frame":0,"cues":[],"segments":[]}
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false)
	game.qa_mode="film"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await late();await elite();await evolution();await golem();await guardian()
	var timeline={"fps":30,"frames":state.frame,"segments":state.segments,"sound_events":state.cues,"diagnostic":"prepared builds; bosses with invulnerable hero and scripted kills"}
	FileAccess.open("res://qa/recordings/chapter_four_fx_timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline,"  "))
	game.audio.shutdown();game.quitting=true
	print("CHAPTER_FOUR_FX2_FILM ",state.frame," frames");quit()

func shoot():
	var w=game.world
	for id in w.sounds:state.cues.append({"id":id,"time":state.frame/30.0})
	w.sounds.clear();game.ui_time+=1.0/30;game.update_camera_lead()
	game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+"/%05d.png"%state.frame);state.frame+=1

func base(seed: int):
	game.start_chapter(4);game.world.reset(seed)
	var w=game.world;w.state="RUNNING";w.stage="survival";w.stage_age=30;w.note_presented=true;w.note_read=true;w.fx.opening=1
	game.settings.shake=true
	return w

func tick(w,move:=Vector2.ZERO,frames:=1):
	for f in range(frames):
		for i in range(2):
			if w.state=="LEVEL_UP":w.skip_reward()
			if w.state=="CHEST":w.chest_delay=0;w.close_chest()
			w.hp=maxf(w.hp,12);w.step(1.0/60,move)
		await shoot()

func late():
	state.segments.append({"mode":"last minutes","time":state.frame/30.0})
	var w=base(911);w.time=650;w.clock=650;w.build={"sword":8,"shotgun":8,"bell":6};w.evolved={"shotgun":true};w.items={"armor":4,"gunpowder":5}
	w.player=Vector2(1300,1250)
	await tick(w,Vector2(.6,.3),240)

func elite():
	state.segments.append({"mode":"elite","time":state.frame/30.0})
	var w=base(912);w.time=270;w.clock=270;w.build={"sword":8,"shotgun":6};w.db.data.chapter_four.exploration_only=true
	await tick(w,Vector2.ZERO,10)
	w.spawn("gravedigger")
	await tick(w,Vector2.ZERO,120)

func evolution():
	state.segments.append({"mode":"evolution","time":state.frame/30.0})
	var w=base(913);w.time=420;w.clock=420;w.db.data.chapter_four.exploration_only=true
	w.build={"shotgun":8,"sword":6};w.items={"gunpowder":5,"armor":3}
	await tick(w,Vector2.ZERO,20)
	w.open_chest({"kind":"chest","p":w.player,"born":400.0})
	while w.chest_delay>0:
		w.chest_delay=maxf(0,w.chest_delay-1.0/30);await shoot()
	for f in range(36):await shoot()
	w.close_chest()
	for i in range(6):
		var p: Vector2=w.player+Vector2.from_angle(i*1.1)*80
		w.spawn(["flayed_zombie","open_cow","hungry_wolf"][i%3],p)
	await tick(w,Vector2.ZERO,90)

func boss_tick(w,target: Vector2,t: float,radius: float):
	var want: Vector2=target+target.direction_to(w.player).rotated(.5*sin(t*.6))*radius
	for i in range(2):
		if w.state=="CHEST":w.chest_delay=0;w.close_chest()
		w.invulnerable=999;w.hp=maxf(w.hp,10);w.step(1.0/60,((want-w.player)/30.0).limit_length())
	await shoot()

func golem():
	state.segments.append({"mode":"golem","time":state.frame/30.0})
	var w=base(724);var e=w.encounters;w.db.data.chapter_four.exploration_only=true
	w.build={"sword":7,"shotgun":8};w.items={"armor":3}
	w.time=160;e.golem.visible=true;w.player=e.golem.p+Vector2(0,110);e.launch_golem(w)
	for f in range(300):
		if f==150:
			for n in e.nodes:
				if n.encounter_actor=="golem_node":e.hurt(w,n,n.hp+1,Vector2.ZERO)
		await boss_tick(w,e.golem.p,f/30.0,90.0)

func guardian():
	state.segments.append({"mode":"guardian","time":state.frame/30.0})
	var w=base(724);var e=w.encounters;w.db.data.chapter_four.exploration_only=true
	w.build={"sword":7,"shotgun":8,"bell":6};w.items={"armor":3}
	w.time=520;w.player=e.arena().get_center()+Vector2(0,60);e.launch_guardian(w)
	for f in range(450):
		if f==330:e.hurt(w,e.guardian,e.guardian.hp+1,Vector2.ZERO)
		await boss_tick(w,e.guardian.p,f/30.0,110.0)
