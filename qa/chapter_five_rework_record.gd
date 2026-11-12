extends SceneTree
## Film of the chapter V rework: fighter, battle box, lanes, arena, ending.
var game
var folder:="res://qa/recordings/chapter_five_frames"
var state:={"frame":0,"cues":[],"music":[]}
func _initialize():run.call_deferred()
func shoot(w):
	for id in w.sounds:state.cues.append({"id":id,"time":state.frame/30.0})
	var th: String=game.ch5_music() if w.get("notch")!=null and w.stage=="notch" else "silence"
	th=th.get_slice(":",1) if th.begins_with("chapter_four_end:") else th
	if state.music.is_empty() or state.music[-1].track!=th:state.music.append({"track":th,"time":state.frame/30.0})
	w.sounds.clear()
	game.ui_time+=1.0/30
	game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+"/%05d.png"%state.frame);state.frame+=1
func tick(w,move:=Vector2.ZERO,hold:=true):
	for i in range(2):
		if hold:w.hp=maxf(w.hp,12)
		w.step(1.0/60,move)
	await shoot(w)
func idle(w,seconds: float,move:=Vector2.ZERO):
	for f in range(int(seconds*30)):await tick(w,move)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game.action("chapter_5");var w=game.world;game.settings.shake=true;var n=w.notch
	n.begin(w);n.start_fighter(w);var fi=n.fighter
	await idle(w,2.4)
	fi.paused=true;await idle(w,3.0);fi.paused=false
	var plan=[["walk",.8],["punch",0],["punch",.15],["punch",.15],["walk",.4],["special_up",0],["wait",1.2],["walk",.6],["kick",0],["wait",.6],["back",.6],["special",0],["wait",1.4],["special_back",0],["wait",.5],["punch",0],["punch",.15],["punch",.15],["wait",.8],["special_down",0],["wait",1.0],["walk",.5],["punch",0],["special_fwd",0],["wait",1.0],["jump",0],["wait",.25],["special",0],["wait",1.0],["walk",.8],["grab",0],["wait",1.2],["super",0],["wait",2.4],["walk",.8],["punch",0],["punch",.15],["punch",.15],["wait",1.0]]
	for loop in range(3):
		for step in plan:
			var s=fi.steve();var nt=fi.notch();var d: float=signf(nt.x-s.x)
			s.hp=maxf(s.hp,40)
			match step[0]:
				"walk":
					for f in range(int(step[1]*30)):
						if absf(nt.x-s.x)<1.1:break
						await tick(w,Vector2(d,0))
				"back":
					for f in range(int(step[1]*30)):await tick(w,Vector2(-d,0))
				"wait":await idle(w,step[1])
				"punch":n.press(w,"accept");await idle(w,maxf(step[1],.05))
				"kick":n.press(w,"kick");await idle(w,.05)
				"grab":n.press(w,"grab");await idle(w,.05)
				"super":s.meter=100.0;n.press(w,"super");await idle(w,.05)
				"special":fi.input_dir=Vector2.ZERO;n.press(w,"special");s.cool=0;await idle(w,.05)
				"special_up":s.cool=0;fi.input_dir=Vector2(0,-1);fi.press("special");await idle(w,.05)
				"special_down":s.cool=0;fi.input_dir=Vector2(0,1);fi.press("special");await idle(w,.05)
				"special_back":s.cool=0;fi.input_dir=Vector2(-d,0);fi.press("special");await idle(w,.05)
				"special_fwd":s.cool=0;fi.input_dir=Vector2(d,0);fi.press("special");await idle(w,.05)
				"jump":
					for f2 in range(3):await tick(w,Vector2(d * .5,-1))
			if fi.state!="fight":break
		if fi.state=="finish":
			await idle(w,1.2)
			var s2=fi.steve();var nt2=fi.notch();var d2: float=signf(nt2.x-s2.x)
			for f3 in range(40):
				if absf(nt2.x-s2.x)<1.6:break
				await tick(w,Vector2(d2,0))
			for dv in [Vector2(0,1),Vector2.ZERO,Vector2(d2,0),Vector2.ZERO,Vector2(0,1)]:
				await tick(w,dv);await tick(w,dv)
			fi.input_dir=Vector2(0,1);fi.press("punch")
			while fi.state=="fatality":await idle(w,.2)
			break
		while fi.state in ["ko","intro"]:await idle(w,.2)
		if n.phase!="fighter":break
		if loop==1:fi.notch().hp=minf(fi.notch().hp,15)
	n.start_ut(w);n.ut_wave=6;await idle(w,1.5);n.press(w,"right");await idle(w,.3);n.press(w,"right");await idle(w,.3);n.press(w,"right");await idle(w,.3);n.press(w,"accept")
	await idle(w,1.6);n.press(w,"accept");n.press(w,"accept")
	for k in range(4):
		for f in range(int(6.6*30)):
			var dodge=Vector2.ZERO
			for b in n.ut_bullets:
				var dd: Vector2=n.soul-b.p
				if dd.length()<24:dodge+=dd.normalized()*(24-dd.length())
			dodge+=(n.UT_BOX.get_center()-n.soul)*.03
			if n.ut_mode=="blue" and f%25==0:dodge.y=-1
			w.hp=maxf(w.hp,10);w.invulnerable=maxf(w.invulnerable,.0)
			for i in range(2):w.step(1.0/60,dodge.limit_length())
			await shoot(w)
		await idle(w,.8)
		if k%2==0:
			n.ut_choice=0;n.press(w,"accept");await idle(w,.6);n.press(w,"accept");await idle(w,1.6);n.press(w,"accept");n.press(w,"accept")
		else:
			n.ut_choice=1;n.press(w,"accept");await idle(w,1.8);n.press(w,"accept");n.press(w,"accept")
	n.start_lanes(w);await idle(w,2.0)
	var plants=[[1,0,2],[1,0,1],[0,1,2],[4,1,1],[0,1,3],[1,0,3],[5,4,2],[4,1,0],[0,1,4],[6,3,1],[7,5,3],[2,4,0],[7,6,2],[5,4,4]]
	for p in plants:
		await idle(w,1.0);n.redstone=maxi(n.redstone,200);n.card_ready[p[0]]=0.0;n.card=p[0];n.cursor=Vector2i(p[1],p[2]);n.press(w,"accept")
		for d in n.drops:
			if not d.taken and d.life>1.0:n.click(w,d.p)
	var kinds=["baby","spider","slime","vindicator","skeleton","zombie","creeper","ravager"]
	for k in range(kinds.size()):
		n.spawn_walker(w,kinds[k],k%5,n.LANE_ORIGIN.x+n.COLS*n.CELL.x+20);await idle(w,1.2)
	await idle(w,18.0)
	n.start_quake(w);var qk=n.quake
	for f in range(int(32*30)):
		var st=qk.steve();var nb=qk.notch()
		var to: Vector3=nb.p-st.p
		var dy: float=angle_difference(st.yaw,atan2(-to.x,-to.z))
		var pw: float=atan2(to.y+.4,Vector2(to.x,to.z).length())-.06
		var sees: bool=qk.line_clear(qk.eye(st),qk.eye(nb))
		var weapon=""
		if f==60:weapon="charges"
		if f==300:weapon="rockets"
		if f==560:weapon="pickaxe"
		if f==640:weapon="rockets"
		n.quake_input={"weapon":weapon,"wish":Vector2(sin(f*.04),1.0 if to.length()>8 else -.3),"turn":Vector2(clampf(-dy,-.08,.08),clampf(st.pitch-pw,-.05,.05)),"fire":sees and absf(dy)<.15,"jump":f%55==0}
		for i in range(2):
			st.hp=maxf(st.hp,30);nb.frags=mini(nb.frags,1)
			if st.dead>0:st.dead=0;st.hp=100
			if f>600:nb.hp=minf(nb.hp,40)
			w.step(1.0/60,Vector2.ZERO);n.quake_input.turn=Vector2.ZERO;n.quake_input.weapon=""
		await shoot(w)
		if n.phase!="quake":break
	await idle(w,3.0)
	var f=n.finale
	f.begin_erase();n.change("erase");await idle(w,4.0)
	for k in range(15):
		await idle(w,.25);n.press(w,"accept")
	await idle(w,3.8)
	f.change("chair");n.change("chair");await idle(w,9.0);f.age=19.0;await idle(w,4.0);f.age=29.0;await idle(w,15.5)
	await idle(w,f.FLIGHT_LENGTH+.3)
	await idle(w,f.CREDITS_LENGTH)
	var timeline={"fps":30,"frames":state.frame,"sound_events":state.cues,"music":state.music}
	FileAccess.open("res://qa/recordings/chapter_five_timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline,"  "))
	game.audio.shutdown();game.quitting=true
	print("CHAPTER_FIVE_FILM ",state.frame," frames");quit()
