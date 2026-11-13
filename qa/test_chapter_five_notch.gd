extends SceneTree
## Chapter V stage D: Notch's talk, the fight, the battle box and the lanes.
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
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var image=root.get_texture().get_image()
	if not name.is_empty():image.save_png(out+name+".png")
	return image
func advance(seconds: float,movement: Vector2=Vector2.ZERO):
	for i in range(ceili(seconds*60)):
		var w=game.world
		if w.state=="LEVEL_UP":w.skip_reward()
		elif w.state=="CHEST":w.chest_delay=0;w.close_chest()
		else:w.step(1.0/60,movement)
func until(phase: String,limit: float=60.0,movement: Vector2=Vector2.ZERO):
	var t:=0.0
	while game.world.notch.phase!=phase and t<limit:advance(1.0/60,movement);t+=1.0/60
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.action("chapter_5");var w=game.world;var n=w.notch
	w.db.data.waves=[{"at":0,"rate":0,"weights":{"token":1}}]
	for id in w.next_event:w.next_event[id]=99999.0
	w.bosses.terminal_done=true;w.bosses.loop_done=true
	w.time=719.5;w.spawn("token",w.player+Vector2(50,0));advance(.6)
	check(w.stage=="notch" and n.phase=="intro" and w.mobs.is_empty() and w.state=="RUNNING","At 12:00 the arena clears for Notch")
	advance(4.0);await render("d_intro")
	check(not n.line.is_empty(),"He talks")
	n.skip();advance(.2)
	check(n.phase=="fight" and n.notch_mob(w)!=null,"Skipping the talk starts the fight")
	w.build={"sword":6,"bow":5};w.cooldowns={"sword":0.0,"bow":0.0};w.invulnerable=999
	var hp: float=n.hp;advance(3.0)
	check(n.hp<hp,"Your weapons reach him")
	var seen={}
	for i in range(6):
		n.attack_timer=0;n.busy=0;advance(.4);seen[n.attack_index]=true
		check(n.hz.size()>0 or n.spiral_left>0 or n.slam_age>=0,"Attack %d puts a telegraph on the field"%i)
		if i==0:await render("d_paste")
		if i==1:advance(.4);await render("d_rain")
		if i==2:advance(.6);await render("d_sweep")
	check(seen.size()==6,"He cycles through his attacks")
	n.hp=n.FIGHT_HP*.45;advance(.2)
	check(n.enraged and n.busy>0,"Half HP: the second phase starts with a pause")
	advance(1.6);check(n.dark>.9 and w.tone()>.9,"…and the page goes black")
	# checkpoint
	w.invulnerable=0;w.hp=1;w.damage_player(10);advance(.1)
	check(n.phase=="retry","Dying in the fight goes to a checkpoint, not the results")
	advance(2.6);check(n.phase=="fight" and n.hp==n.FIGHT_HP and w.hp==20,"…and restarts the fight with full health")
	n.hp=1;w.hurt(n.notch_mob(w),5);advance(.1)
	check(n.phase=="to_ut","Beating him leads to his games")
	until("ut",5.0);await render("d_ut_menu")
	check(n.ut_state=="menu","The battle box opens on the menu")
	n.press(w,"right");n.press(w,"right");n.press(w,"right");n.press(w,"accept")
	check(n.mercy_gone and n.menu_options().size()==3,"MERCY gets deleted")
	await render("d_ut_mercy")
	advance(.4);n.press(w,"accept");n.press(w,"accept");check(n.ut_state=="wave","Then his turn")
	w.invulnerable=999;advance(1.5,Vector2(1,-1));await render("d_ut_wave")
	advance(5.7);check(n.ut_state=="menu","The turn ends")
	for k in range(4):
		n.ut_state="text";n.ut_type=999;n.ut_timer=0;n.press(w,"accept");advance(1.6);await render("d_ut_wave%d" % (k+2))
		n.ut_timer=0;advance(.05)
	var before: float=n.ut_hp;n.ut_choice=0;n.press(w,"accept");advance(.65);await render("d_ut_bar");n.press(w,"accept")
	check(n.ut_hp<before,"FIGHT is a timing bar")
	advance(1.4);n.ut_hp=1;n.ut_state="menu";n.ut_choice=0;n.press(w,"accept");n.press(w,"accept");advance(1.7)
	check(n.ut_state=="end","Enough hits end the battle")
	until("lanes",8.0);await render("d_lanes_start")
	check(n.phase=="lanes" and n.redstone==150,"Then the lanes")
	n.card=1;n.cursor=Vector2i(0,0);n.press(w,"accept");n.card=0;n.cursor=Vector2i(1,2);n.press(w,"accept")
	check(n.plants.size()==2 and n.redstone==0,"Blocks cost redstone")
	n.redstone=999;n.card_ready=[0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
	for r in range(5):
		n.card=0;n.card_ready[0]=0;n.cursor=Vector2i(1,r);n.press(w,"accept")
		n.card=2;n.card_ready[2]=0;n.cursor=Vector2i(4,r);n.press(w,"accept")
	advance(30.0);await render("d_lanes")
	check(n.zombies.size()>0 or n.lane_age>30,"His zombies walk the lanes")
	var t:=0.0
	while n.phase=="lanes" and t<240.0:
		n.redstone=999;advance(1.0);t+=1.0
	check(n.phase in ["lanes_won","done"] or w.state=="RESULT","A held line wins the lanes")
	until("fighter",5.0);check(n.phase=="fighter","…and leads into the fighting game")
	game.action("chapter_5");w=game.world;n=w.notch;w.bosses.terminal_done=true;w.bosses.loop_done=true
	n.begin(w);n.start_lanes(w);n.carts[0].state="used";n.zombies.append({"kind":"zombie","row":0,"x":n.LANE_ORIGIN.x-50,"hp":10.0,"max":10.0,"speed":9.0,"bite":0.0,"flash":0.0,"visual":w.animation.actor(),"age":0.0});advance(.1)
	check(n.phase=="retry" and n.retry_of=="lanes","A zombie through the line restarts the lanes")
	n.start_lanes(w);n.zombies.append({"kind":"zombie","row":2,"x":n.LANE_ORIGIN.x-8,"hp":10.0,"max":10.0,"speed":9.0,"bite":0.0,"flash":0.0,"visual":w.animation.actor(),"age":0.0});advance(1.5)
	check(n.phase=="lanes" and n.carts[2].state!="ready","The minecart saves the row once")
	n.drop_at(Vector2(300,20),200.0);var rs: int=n.redstone;n.click(w,n.drops.back().p)
	check(n.redstone==rs+25,"Falling redstone is collected with a click")
	print("CHAPTER_FIVE_NOTCH_RESULT %d checks; %d failures" % [checks,failures.size()])
	if game.has_meta("ch5_view3d"):game.get_meta("ch5_view3d").release()
	await process_frame;game.audio.shutdown();game.quitting=true
	quit(1 if failures.size() else 0)
