extends SceneTree
## Diagnostic film of chapter V stage A: the three tones, code enemies and
## world events. Strong build, bot movement, time jumps between segments.
var game
var folder:="res://qa/recordings/chapter_five_frames"
var state:={"frame":0,"cues":[],"music":[{"track":"music","time":0.0}]}
var bot=SurvivorBot.new("sword")
func _initialize():run.call_deferred()
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game.action("chapter_5");var w=game.world;game.settings.shake=true;game.settings.numbers=false
	w.bosses.terminal_done=true;w.bosses.loop_done=true
	jump(w,712.0,{"sword":8,"bow":7,"command_block":6,"barrier":6,"debug_stick":6})
	await segment(w,9.0)
	var n=w.notch
	await idle(w,13.0)
	n.age=n.INTRO_LENGTH-2.6
	await idle(w,3.0)
	await segment(w,22.0)
	n.hp=minf(n.hp,120.0)
	while n.phase=="fight":await segment(w,.5)
	await idle(w,4.0)
	await idle(w,1.0);n.press(w,"right");await idle(w,.4);n.press(w,"right");await idle(w,.4);n.press(w,"right");await idle(w,.6);n.press(w,"accept")
	await idle(w,1.5);n.press(w,"accept")
	await soul(w,6.2)
	await idle(w,.6);n.ut_choice=0;n.press(w,"accept");await idle(w,.62);n.press(w,"accept")
	await idle(w,1.2);n.press(w,"accept")
	await soul(w,6.2)
	await idle(w,.4);n.ut_choice=1;n.press(w,"accept");await idle(w,1.6);n.press(w,"accept")
	await soul(w,6.2)
	n.ut_hp=10;await idle(w,.4);n.ut_choice=0;n.press(w,"accept");await idle(w,.62);n.press(w,"accept")
	await idle(w,6.0)
	var plan=[[1,0,0],[1,0,2],[0,1,1],[0,1,3],[1,0,4],[0,1,2],[2,4,1],[2,4,3],[0,1,0],[0,1,4],[3,6,2]]
	for step in plan:
		await idle(w,1.2)
		n.redstone=maxi(n.redstone,200);n.card_ready[step[0]]=0.0
		n.card=step[0];n.cursor=Vector2i(step[1],step[2]);n.press(w,"accept")
	await idle(w,28.0)
	n.schedule.clear()
	for z in n.zombies:z.hp=0
	await idle(w,5.0)
	var timeline={"fps":30,"frames":state.frame,"sound_events":state.cues,"music":state.music}
	FileAccess.open("res://qa/recordings/chapter_five_timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline,"  "))
	game.audio.shutdown();game.quitting=true
	print("CHAPTER_FIVE_FILM ",state.frame," frames");quit()

func jump(w,time: float,build: Dictionary):
	w.time=time;w.build=build;w.level=int(time/14);w.arsenal.allies.clear()
	for id in w.next_event:w.next_event[id]=maxf(w.next_event[id],time+60.0)
	for id in build:
		if not w.cooldowns.has(id):w.cooldowns[id]=0.3
	for k in range(int(8+time/30)):
		var wave=w.db.wave(time);var kinds=wave.weights.keys()
		w.spawn(kinds[k%kinds.size()],w.player+Vector2.from_angle(k*2.4)*(170+k%5*30))

func idle(w,seconds: float):
	for f in range(int(seconds*30)):
		for i in range(2):
			w.hp=maxf(w.hp,14)
			if w.state=="RUNNING":w.step(1.0/60,Vector2.ZERO)
		await shoot(w)

func soul(w,seconds: float):
	for f in range(int(seconds*30)):
		var n=w.notch
		var dodge=Vector2.ZERO
		for b in n.ut_bullets:
			var d: Vector2=n.soul-b.p
			if d.length()<26:dodge+=d.normalized()*(26-d.length())
		dodge+=(n.UT_BOX.get_center()-n.soul)*.02
		for i in range(2):
			w.hp=maxf(w.hp,10)
			w.step(1.0/60,dodge.limit_length())
		await shoot(w)

func shoot(w):
	for id in w.sounds:state.cues.append({"id":id,"time":state.frame/30.0})
	w.sounds.clear()
	game.ui_time+=1.0/30
	game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+"/%05d.png"%state.frame);state.frame+=1

func segment(w,seconds: float):
	for f in range(int(seconds*30)):
		for i in range(2):
			if w.state=="LEVEL_UP":w.skip_reward()
			if w.state=="CHEST":w.chest_delay=0;w.close_chest()
			w.hp=maxf(w.hp,14)
			var move: Vector2=bot.movement(w)
			if w.invert>0:move=-move
			w.step(1.0/60,move)
		for id in w.sounds:state.cues.append({"id":id,"time":state.frame/30.0})
		w.sounds.clear()
		game.ui_time+=1.0/30
		game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(folder+"/%05d.png"%state.frame);state.frame+=1
