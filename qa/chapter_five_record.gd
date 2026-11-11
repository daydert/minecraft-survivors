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
	var n=w.notch
	n.begin(w);n.start_fighter(w)
	var fi=n.fighter
	await idle(w,2.4)
	for f in range(int(26*30)):
		var s=fi.steve();var nt=fi.notch()
		var d: float=nt.x-s.x
		var move=Vector2(signf(d) if absf(d)>1.1 else 0.0,0)
		if nt.move in ["punch","kick","punch3"] and fi.phase_of(nt)=="start" and absf(d)<1.8:move=Vector2(0,1)
		if f%40==0 and absf(d)>3:n.press(w,"special")
		elif absf(d)<1.3 and f%9==0:n.press(w,"accept" if f%27!=0 else "kick")
		if f%150==75:move=Vector2(signf(d),-1)
		for i in range(2):
			s.hp=maxf(s.hp,30)
			if f>600:nt.hp=minf(nt.hp,40)
			w.step(1.0/60,move)
		await shoot(w)
		if fi.state!="fight":break
	await idle(w,6.5)
	await idle(w,2.5)
	var qk=n.quake
	for f in range(int(48*30)):
		var st=qk.steve();var nb=qk.notch()
		var to: Vector3=nb.p-st.p
		var want_yaw: float=atan2(-to.x,-to.z)
		var dy: float=angle_difference(st.yaw,want_yaw)
		var pitch_want: float=atan2(to.y+.4,Vector2(to.x,to.z).length())-.06
		var turn=Vector2(clampf(-dy,-.08,.08),clampf(st.pitch-pitch_want,-.05,.05))
		var sees: bool=qk.line_clear(qk.eye(st),qk.eye(nb))
		var wish=Vector2(sin(f*.03),1.0 if to.length()>9 else -.4)
		var fire: bool=sees and absf(dy)<.12 and nb.dead<=0
		var jump: bool=f%70==0
		if f==200:turn.y=1.5;fire=true;jump=true
		n.quake_input={"wish":wish,"turn":turn,"fire":fire,"jump":jump}
		for i in range(2):
			st.hp=maxf(st.hp,30);nb.frags=mini(nb.frags,1)
			if st.dead>0:st.dead=0;st.hp=100
			if f>500:nb.hp=minf(nb.hp,30)
			w.step(1.0/60,Vector2.ZERO)
			n.quake_input.turn=Vector2.ZERO;n.quake_input.fire=false if i==0 else n.quake_input.fire
		await shoot(w)
		if n.phase!="quake":break
	await idle(w,4.0)
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
