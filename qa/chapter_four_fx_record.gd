extends SceneTree
## Diagnostic film of the IV impact pass: opening, weapons, gore and bosses.
## Ordinary HP for weapon segments; bosses use the invulnerable scripted orbit.
func _initialize():run.call_deferred()
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false)
	game.qa_mode="film"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	var folder:="res://qa/recordings/chapter_four_fx_frames"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var state:={"frame":0,"cues":[],"segments":[]}
	await opening(game,folder,state)
	for mode in ["shotgun","bedrock","bell","sky","saw","pet","bat"]:await weapon(game,folder,state,mode)
	await late(game,folder,state)
	await boss(game,folder,state,"mass")
	var timeline={"fps":30,"frames":state.frame,"segments":state.segments,"sound_events":state.cues,"diagnostic":"cuts between prepared builds; bosses with invulnerable scripted orbit"}
	FileAccess.open("res://qa/recordings/chapter_four_fx_timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline,"  "))
	game.audio.shutdown();game.quitting=true
	print("CHAPTER_FOUR_FX_FILM ",state.frame," frames")
	quit()

func shoot(game,folder: String,state: Dictionary):
	var w=game.world
	for id in w.sounds:state.cues.append({"id":id,"time":state.frame/30.0})
	w.sounds.clear();game.ui_time+=1.0/30;game.update_camera_lead()
	game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+"/%05d.png"%state.frame);state.frame+=1

func opening(game,folder: String,state: Dictionary):
	state.segments.append({"mode":"opening","time":state.frame/30.0})
	game.start_chapter(4);game.world.reset(724)
	var w=game.world;w.state="RUNNING";game.settings.shake=true
	for f in range(int(8.5*30)):
		for tick in range(2):
			if w.state=="LEVEL_UP":w.skip_reward()
			w.step(1.0/60,Vector2.ZERO)
		await shoot(game,folder,state)

func weapon(game,folder: String,state: Dictionary,mode: String):
	state.segments.append({"mode":mode,"time":state.frame/30.0})
	game.qa_mode="ch4c_"+mode;game.QAHarness.prepare_four_arsenal_capture(game);var w=game.world
	game.settings.shake=true
	for m in w.mobs:m.hp=m.max_hp/5.0*1.6;m.max_hp=m.hp
	var length:=150 if mode in ["shotgun","bat"] else 110
	for i in range(length):
		if i==70 and mode=="bat":w.arsenal.bat_recharge=0;w.facing=Vector2.LEFT;w.active_item("bat")
		if i%35==0 and mode!="bat":
			for j in range(5):
				var p: Vector2=w.player+Vector2.from_angle(i*.3+j*1.256)*float(70+j%2*30)
				w.spawn(["flayed_zombie","growth_skeleton","open_cow","hungry_wolf","fused_villagers"][j],p)
		for tick in range(2):
			if w.state=="LEVEL_UP":w.skip_reward()
			w.hp=maxf(w.hp,12)
			var move:=Vector2.ZERO
			if mode=="bat" and i<60:move=Vector2.RIGHT
			w.step(1.0/60,move)
		await shoot(game,folder,state)

func late(game,folder: String,state: Dictionary):
	state.segments.append({"mode":"late","time":state.frame/30.0})
	game.start_chapter(4);game.world.reset(911)
	var w=game.world;w.state="RUNNING";w.stage="survival";w.stage_age=30;w.note_presented=true;w.note_read=true
	w.fx.opening=1;w.time=640;w.clock=640;w.build={"sword":8,"shotgun":8,"bell":6};w.evolved={"shotgun":true};w.items={"armor":4,"gunpowder":5}
	game.settings.shake=true
	for f in range(int(9*30)):
		for tick in range(2):
			if w.state=="LEVEL_UP":w.skip_reward()
			if w.state=="CHEST":w.chest_delay=0;w.close_chest()
			w.hp=maxf(w.hp,12)
			var t: float=f/30.0
			w.step(1.0/60,Vector2(cos(t*.7),sin(t*.9)*.6))
		await shoot(game,folder,state)

func boss(game,folder: String,state: Dictionary,scene: String):
	state.segments.append({"mode":scene,"time":state.frame/30.0})
	game.start_chapter(4);game.world.reset(724)
	var w=game.world;var e=w.encounters
	w.state="RUNNING";w.stage="survival";w.stage_age=30;w.note_presented=true;w.note_read=true;w.fx.opening=1
	w.db.data.chapter_four.exploration_only=true;w.build={"sword":7,"shotgun":8,"bell":6};w.evolved={"shotgun":true};w.items={"armor":3}
	game.settings.shake=true
	w.time=361;e.launch_mass(w);w.player=e.mass.p+Vector2(0,130)
	var length:=16.0;var killed:=false
	for f in range(int(length*30)):
		var t: float=f/30.0
		for tick in range(2):
			if w.state=="LEVEL_UP":w.skip_reward()
			if w.state=="CHEST":w.chest_delay=0;w.close_chest()
			w.invulnerable=maxf(w.invulnerable,.3) if t<9 else w.invulnerable;w.hp=maxf(w.hp,10)
			var target: Vector2=e.mass.p
			var want: Vector2=target+target.direction_to(w.player).rotated(.5*sin(t*.6))*75.0
			if not killed and t>length-5.0:e.hurt(w,e.mass,e.mass.hp+1,Vector2.ZERO);killed=true
			w.step(1.0/60,((want-w.player)/30.0).limit_length())
		await shoot(game,folder,state)
