extends SceneTree
## Chapter V survival ending (tester pack 13.11): purge terminal, snap or core,
## overload with over-cap levels, transcendence, stopped time and the crack.
var game
var checks=0
var failures=[]
var out="res://qa/ch5_purge/"
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func render(name: String=""):
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	if not name.is_empty():root.get_texture().get_image().save_png(out+name+".png")
func advance(seconds: float,movement: Vector2=Vector2.ZERO):
	for i in range(ceili(seconds*60)):
		var w=game.world
		if w.state=="LEVEL_UP":w.choose(0)
		elif w.state=="CHEST":w.chest_delay=0;w.close_chest()
		else:w.step(1.0/60,movement)
func fresh():
	game.action("chapter_5");var w=game.world
	w.sword_drop={}
	for id in w.next_event:w.next_event[id]=99999.0
	w.bosses.terminal_done=true;w.bosses.loop_done=true
	w.time=599.5;w.invulnerable=999
	return w
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	var w=fresh()
	advance(1.0)
	var u=w.purge
	check(u.phase=="countdown" and w.mob_by_id(u.id)!=null,"At 10:00 the purge terminal appears and the countdown starts")
	advance(20.0);await render("countdown")
	check(u.left<u.COUNTDOWN-19 and u.left>u.COUNTDOWN-22,"The deletion counts down in real time")
	u.left=.05;advance(.2)
	check(u.phase=="snap","Out of time: Steve is deleted")
	advance(1.4);await render("snap")
	advance(3.0)
	check(w.state=="RESULT" and not w.victory,"Deletion is a defeat")
	w=fresh();advance(1.0);u=w.purge
	var t=w.mob_by_id(u.id);w.hurt(t,t.hp+10);advance(.1)
	check(u.phase=="core","Breaking the terminal tears out the core")
	advance(1.4);await render("core_fly");advance(.8);await render("core_held")
	var victims: Array=[]
	for i in range(20):
		if w.spawn("token",w.player+Vector2.from_angle(i)*120):victims.append(w.mobs.back())
	advance(1.6)
	check(u.phase=="surge" and w.overcap,"The core is absorbed: overload with no upgrade limits")
	advance(.4);await render("shockwave")
	advance(1.0)
	w.invulnerable=999;w.hp=20
	check(victims.size()>10 and victims.all(func(m):return m.hp<=0),"The shockwave wipes out everything nearby")
	w.build["debug_stick"]=8;w.overcap=true;w.apply_upgrade("debug_stick")
	check(w.build.debug_stick==9 and w.db.stats("debug_stick",12).interval>0,"Weapons level past 8 with the table repeating")
	var lv: int=w.level;advance(16.0);await render("surge")
	check(w.level>=lv+2,"Levels pour in during the overload")
	var t0: float=w.time;advance(5.0);var r1: float=w.time-t0
	u.age=100.0;t0=w.time;advance(5.0);var r2: float=w.time-t0
	check(r2>r1*2.5,"The clock races faster and faster")
	advance(16.0)
	check(u.phase=="ascend","After two minutes he transcends")
	advance(3.0);await render("ascend")
	advance(3.2)
	check(u.phase=="stop","White-out, then time stops")
	await render("white")
	var shot_count: int=w.shots.size();w.spawn("token",w.player+Vector2(30,0));var frozen=w.mobs.back();var fp: Vector2=frozen.p
	advance(3.0);await render("stopped")
	check(frozen.p==fp and w.hp>0,"Nothing moves in stopped time and nothing hurts him")
	var dir: Vector2=w.player.direction_to(u.crack)
	for i in range(1400):
		if w.stage=="notch":break
		advance(1.0/60,w.player.direction_to(u.crack))
		if i==150:await render("crack")
	check(w.stage=="notch","He walks into the crack and reaches Notch")
	check(w.notch.INTRO_SCRIPT[0][0].contains("2 миллионов мощи"),"Notch sees the power he reached")
	print("CH5_PURGE_RESULT %d checks; %d failures" % [checks, failures.size()])
	quit(1 if failures.size()>0 else 0)
