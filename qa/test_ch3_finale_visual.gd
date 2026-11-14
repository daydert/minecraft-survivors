extends SceneTree
## Rendered frames of the reworked chapter III finale: qa/ch3_finale_*.png.
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func render(name: String="") -> Image:
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var image=root.get_texture().get_image()
	if not name.is_empty():image.save_png("res://qa/ch3_finale_"+name+".png")
	return image
func advance(seconds: float,movement: Vector2=Vector2.ZERO):
	for i in range(ceili(seconds*60)):
		if game.world.state=="PAUSED":game.world.state="RUNNING"
		game.world.step(1.0/60,movement)
func wait_until(cond: Callable, limit: float=30.0) -> bool:
	var t=0.0
	while not cond.call() and t<limit:advance(1.0/60);t+=1.0/60
	if not cond.call():print("WAIT FAILED stage=",game.world.stage," state=",game.world.state," hp=",game.world.hp)
	return cond.call()
func arena(w):
	w.state="RUNNING";w.build={"mace":3};w.items={};w.prepare_arena();w.duel={"fight":1,"adapt":{},"style":{},"checkpoint":{},"phase_start":{}};w.race={};w.framed=0.0;w.lines.clear();w.stage="last_duel";w.mobs.clear();w.crystals.clear();w.portal_lit=false
	w.spawn("endersteve_final",Vector2(1024,1000));w.player=Vector2(1024,1110);w.scene_camera=Vector2(1024,1060);w.invulnerable=999;w.hit_grace=999
	return w.mobs[0]
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.settings.shake=false;game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.action("chapter_3");var w=game.world;w.db.data.events=[];w.db.data.waves=[{"at":0,"rate":0,"weights":{"endermite":1}}]
	var m=arena(w);var b=w.steve_boss
	b.begin(w,m,b.PROJECTION);advance(.5);await render("projection_stance")
	advance(.5);await render("projection_preview")
	m.p=Vector2(1024,1000);m.phase="projection";m.lap=1;m.seg=1;m.after=0.0;m.path=[m.p,Vector2(1100,1060),w.player,Vector2(960,1150)];w.hit_grace=0;w.blink_grace=0
	advance(.1);await render("projection_lap")
	wait_until(func():return w.framed>0,2.0)
	check(w.framed>0,"The capture is reachable in the rendered scene "+m.phase)
	await render("framed");advance(.6);await render("framed_strike");advance(.5);await render("crush")
	m=arena(w);m.hp=m.max_hp*.55;m.phase="walk";m.timer=99;advance(.1);advance(.6);await render("clock_running")
	m.phase="recover";m.timer=99;w.damage_owner="mace";w.hurt(m,m.max_hp*.13);advance(.05);advance(.5);await render("clock_rewind")
	advance(1.2);w.hp=20;await render("adapt_hud")
	m=arena(w);w.jump_age=0.0;w.jump_stats={"height":30,"damage":1,"radius":10};w.air_serial+=1;w.duel.learned="mace";w.duel.fight=2;m.p=w.player+Vector2(90,0);m.phase="walk";m.timer=99;w.hit_grace=0
	advance(.25);await render("intercept")
	m=arena(w);w.save_duel_checkpoint("fight1");m.phase="recover";m.hp=0;w.hp=20;w.resolve_deaths()
	advance(1.0);await render("rebirth_death");advance(2.4);await render("rebirth_gone");advance(1.4);await render("rebirth_form")
	wait_until(func():return w.stage=="last_duel")
	advance(.6);await render("phase_two")
	w.duel.fight=2;w.damage_by={"mace":900.0};m=w.mobs[0];m.hp=0;w.resolve_deaths()
	advance(.8);await render("standoff");advance(1.4);await render("clash_hit");advance(1.0);await render("clash_break")
	wait_until(func():return w.stage=="sword_race")
	advance(.4);await render("race_intro");advance(.9)
	for i in range(5):w.sword_race.press("attack")
	await render("race_mash")
	for i in range(8):w.sword_race.press("attack")
	wait_until(func():return w.sword_race.beat>=1,5)
	advance(.45);await render("race_dodge");w.sword_race.press(w.sword_race.dir)
	wait_until(func():return w.sword_race.beat>=2,5)
	advance(.6);await render("race_grab")
	advance(.3);w.sword_race.press("attack")
	wait_until(func():return w.stage!="sword_race",15)
	var e=w.end_boss
	advance(.8);await render("mercy_kneel");advance(1.4);await render("mercy_wait")
	advance(e.MERCY_MARKS.why-e.RAISE_BEFORE-2.2+.6);await render("mercy_raise")
	advance(e.RAISE_HOLD+.6);await render("mercy_lower")
	advance(e.MERCY_MARKS.free-(e.MERCY_MARKS.why-e.RAISE_BEFORE+e.RAISE_HOLD+.6)+.1);await render("mercy_free")
	wait_until(func():return w.stage!="mercy",60)
	advance(2.0);await render("talk");advance(e.SIT_MARKS.delete-2.0+.5);await render("talk_delete");advance(e.SIT_MARKS.gift-e.SIT_MARKS.delete+.5);await render("talk_gift")
	wait_until(func():return w.stage=="restore",120)
	advance(.3);await render("restore")
	# The bad ending.
	m=arena(w);w.save_duel_checkpoint("fight1");w.duel.fight=2;m.hp=0;w.resolve_deaths()
	wait_until(func():return w.stage=="sword_race")
	wait_until(func():return w.stage!="sword_race",15)
	check(w.stage=="bad_end","Without input the race is lost")
	advance(.3);await render("bad_grab");advance(1.4);await render("bad_line");advance(e.BAD_STRIKE-1.7-.2);await render("bad_raise");advance(.25);await render("bad_strike")
	wait_until(func():return w.stage=="bad_card",20)
	advance(2.0);var card=await render("bad_card")
	check(game.buttons.any(func(x):return x.id=="end_retry"),"The bad ending offers to retry the duel")
	game.action("end_retry");advance(.1)
	check(w.stage=="last_arrival","Retry from the card restarts the duel")
	w.hp=0;advance(.1);advance(1.6);await render("fallen")
	check(game.buttons.any(func(x):return x.id=="end_retry"),"The fallen card offers to retry")
	print("CH3_FINALE_VISUAL_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
