extends SceneTree
## Chapter V stage E: the side-view fighting game and the deathmatch arena.
var game
var checks=0
var failures=[]
var out="res://qa/chapter_five/"
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func render(name: String="") -> Image:
	game.queue_redraw();await process_frame;await process_frame;await process_frame;RenderingServer.force_draw(false)
	var image=root.get_texture().get_image()
	if not name.is_empty():image.save_png(out+name+".png")
	return image
func advance(seconds: float,movement: Vector2=Vector2.ZERO):
	for i in range(ceili(seconds*60)):game.world.step(1.0/60,movement)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.action("chapter_5");var w=game.world;var n=w.notch
	n.begin(w);n.start_fighter(w);var fi=n.fighter
	check(n.phase=="fighter" and fi.state=="intro","After the lanes comes the fighting game")
	advance(1.0);await render("e_round")
	advance(1.4);check(fi.state=="fight","Round one starts")
	var s=fi.steve();var nt=fi.notch()
	s.x=nt.x-1.0;fi.ai=false
	var hp: float=nt.hp;n.press(w,"accept");advance(.2)
	check(nt.hp<hp or nt.block,"A punch lands or is blocked")
	advance(.3);await render("e_fight")
	nt.block=true;nt.move="";nt.stun=0;nt.down=0;hp=nt.hp;s.move="";s.stun=0;fi.start(s,"kick");s.x=nt.x-1.2;s.face=1.0;nt.face=-1.0
	for i in range(30):
		nt.block=true;fi.step(1.0/60,Vector2.ZERO)
	check(hp-nt.hp<3.0,"Blocking soaks most of a kick")
	s.cool=0;s.move="";s.stun=0;nt.x=s.x+4.0;hp=nt.hp;n.press(w,"special");advance(.3)
	check(fi.bolts.size()>0 and fi.bolts[0].kind=="tnt","Q throws TNT")
	advance(1.0);check(nt.hp<hp,"…which explodes on him")
	s.cool=0;s.move="";s.stun=0;nt.x=s.x+1.0;nt.move="";nt.stun=0;nt.down=0;nt.block=false;fi.input_dir=Vector2(0,-1);fi.press("special")
	check(s.move=="uppercut","Q+up is the pickaxe uppercut")
	advance(.4);check(nt.y>.5 or nt.vy>0,"…which launches")
	advance(2.0);s.cool=0;s.move="";s.stun=0;s.meter=100.0;nt.x=s.x+1.2;nt.y=0;nt.vy=0;nt.down=0;nt.stun=0;nt.move="";nt.block=false;hp=nt.hp;fi.press("super");advance(2.2)
	check(nt.hp<hp-15,"The super is a long flurry")
	await render("e_super")
	fi.wins[0]=1;s.hp=100;nt.hp=1;s.x=nt.x-1.0;nt.block=false;nt.move="";nt.stun=0;nt.down=0;s.move="";s.stun=0;fi.start(s,"jab");advance(.3)
	check(fi.state=="finish" and fi.winner==0 and fi.wins[0]==2,"Second round won: Notch stays up for a finishing move")
	advance(.8);await render("e_finish")
	fi.paused=true;await render("e_menu")
	check(fi.MOVE_LIST.size()>=12 and fi.COMBOS.size()>=4,"Esc opens a move list with combos and the fatality")
	fi.paused=false
	s.x=nt.x-1.5;s.face=1.0;s.move="";s.stun=0
	for d in [Vector2(0,1),Vector2.ZERO,Vector2(1,0),Vector2.ZERO,Vector2(0,1)]:
		fi.step(1.0/60,d);fi.step(1.0/60,d)
	fi.input_dir=Vector2(0,1);fi.press("punch")
	check(fi.state=="fatality","Down, forward, down + punch is the fatality")
	advance(1.5);await render("e_fatality_bolt")
	advance(1.4);await render("e_fatality_boom")
	advance(1.0);await render("e_fatality_text")
	check(fi.fatality and w.run_progress.awarded.has("fatality"),"The fatality earns its achievement")
	advance(4.0);check(n.phase=="to_quake","Winning the fight leads to his favourite game")
	# Parry and cancels.
	n.start_fighter(w);fi=n.fighter;advance(2.4);fi.ai=false;s=fi.steve();nt=fi.notch()
	s.x=0.0;nt.x=1.0;s.face=1.0;nt.face=-1.0;fi.input_dir=Vector2(0,1);fi.press("special");fi.input_dir=Vector2.ZERO;advance(.06)
	fi.start(nt,"kick");hp=s.hp;advance(.4)
	check(s.hp==hp and nt.stun>0,"The shield parries a kick and staggers Notch")
	s.move="";s.cool=0;nt.stun=0;nt.move="";nt.down=0;nt.block=false;nt.x=s.x+1.0;fi.start(s,"jab");advance(.1)
	fi.input_dir=Vector2(1,0);fi.press("special");fi.input_dir=Vector2.ZERO
	check(s.move=="dash","A landed jab cancels into the sword dash")
	advance(.5);fi.ai=true
	fi.ai=true
	n.start_fighter(w);fi=n.fighter;advance(2.4);fi.wins[1]=1;fi.steve().hp=0;advance(4.0)
	check(n.phase=="retry" and n.retry_of=="fighter","Losing the fight returns to its checkpoint")
	# arena
	n.start_quake(w);var qk=n.quake
	advance(2.2);check(qk.state=="fight","The deathmatch starts")
	await render("e_quake_start")
	var st=qk.steve();var start: Vector3=st.p
	n.quake_input={"wish":Vector2(0,1),"turn":Vector2.ZERO,"fire":false,"jump":false};advance(.5)
	check(st.p.distance_to(start)>2.0,"W walks forward")
	n.quake_input={"wish":Vector2.ZERO,"turn":Vector2(0,1.4),"fire":true,"jump":true};advance(1.0/60)
	n.quake_input={"wish":Vector2.ZERO,"turn":Vector2.ZERO,"fire":false,"jump":false}
	var peak:=0.0
	for i in range(60):
		advance(1.0/60);peak=maxf(peak,st.p.y)
	check(peak>2.5 and st.hp<100,"A rocket at your feet launches you: rocket jump")
	await render("e_quake_air")
	advance(1.5);qk.ai=false;var nb=qk.notch();st.p=Vector3(-14,0,8);st.v=Vector3.ZERO;nb.p=Vector3(-14,0,2);nb.v=Vector3.ZERO;nb.hp=10;st.yaw=0.0;st.pitch=-.12;st.cool=0;st.dead=0
	n.quake_input={"wish":Vector2.ZERO,"turn":Vector2.ZERO,"fire":true,"jump":false};advance(.6)
	n.quake_input={"wish":Vector2.ZERO,"turn":Vector2.ZERO,"fire":false,"jump":false}
	check(st.frags==1 and not qk.feed.is_empty(),"A rocket into Notch is a frag with an obituary")
	await render("e_quake_frag")
	advance(2.0);check(nb.dead<=0 and nb.hp==100,"He respawns")
	qk.ai=true
	var shots_before: int=qk.rockets.size();advance(3.0)
	check(nb.ammo<20 or qk.rockets.size()!=shots_before,"Notch shoots back")
	await render("e_quake_fight")
	qk.ai=false;st.frags=2;st.p=Vector3(-14,0,8);st.v=Vector3.ZERO;st.dead=0;nb.p=Vector3(-14,0,2);nb.v=Vector3.ZERO;nb.dead=0;nb.hp=5;st.yaw=0.0;st.pitch=-.12;st.cool=0;st.ammo=10
	n.quake_input={"wish":Vector2.ZERO,"turn":Vector2.ZERO,"fire":true,"jump":false};advance(.6)
	n.quake_input={"wish":Vector2.ZERO,"turn":Vector2.ZERO,"fire":false,"jump":false}
	check(n.phase=="quake_won","Three frags win the arena")
	advance(3.6);check(n.phase=="to_code","…and lead into the code duel")
	game.action("chapter_5");w=game.world;n=w.notch;n.begin(w);n.start_quake(w);n.quake.notch().frags=3;advance(2.2)
	check(n.phase=="retry" and n.retry_of=="quake","Three frags for Notch return to the checkpoint")
	print("CHAPTER_FIVE_3D_RESULT %d checks; %d failures" % [checks,failures.size()])
	quit(1 if failures.size() else 0)
