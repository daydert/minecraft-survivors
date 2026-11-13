extends SceneTree
## Chapter V stage F: code duel (both modes), erasure, brawl and wire,
## the chair, the door and the flight into another game.
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
	game.action("chapter_5");var w=game.world;var n=w.notch;var f=n.finale
	n.begin(w);n.change("quake_won");advance(3.3)
	check(n.phase=="to_code","After the arena he calls the last game")
	advance(4.5);check(n.phase=="code" and f.phase=="pick","The code duel opens on the language choice")
	await render("f_pick")
	f.press("right");f.press("accept")
	check(f.lang()=="python" and f.phase=="duel" and not f.advanced,"Python, beginner mode")
	advance(1.0);await render("f_beginner")
	var sol: Array=f.SOLUTIONS["python"]
	var wrong: int=-1
	for i in range(f.pool.size()):
		if sol[f.pool[i]]!=sol[f.built.size()]:wrong=i;break
	f.pick(wrong);check(f.penalty>0 and f.built.is_empty(),"A wrong line costs time")
	while not f.pool.is_empty():
		for i in range(f.pool.size()):
			if sol[f.pool[i]]==sol[f.built.size()]:f.pick(i);break
	check(f.result_ok,"The assembled program passes every test")
	advance(.1);check(n.phase=="erase","Beating him to it leads to the erasure")
	# advanced, typing (JS)
	n.start_code(w);f=n.finale;f.lang_index=2;f.advanced=true;f.start_duel()
	for ch in "for (let i = 0; i < a.length; i++)":f.type_text(ch)
	f.key("enter");f.type_text("for (let j = 0; j + 1 < a.length - i; j++)");f.key("enter")
	f.type_text("if (a[j] > a[j + 1]) { let t = a[j]; a[j] = a[j + 1]; a[j + 1] = t; }")
	advance(.5);await render("f_advanced")
	f.key("run");check(f.result_ok,"Typed JavaScript runs and sorts")
	n.start_code(w);f=n.finale;f.lang_index=0;f.advanced=true;f.start_duel()
	f.type_text("while (true) { }");f.key("run")
	check(not f.result_ok and f.result.contains("бесконечный"),"An infinite loop is caught, not frozen")
	f.advanced=false;f.age=99.0;advance(.1)
	check(n.phase=="retry" and n.retry_of=="code","If Notch finishes first: checkpoint")
	advance(2.6);check(n.phase=="code" and f.phase=="duel" and f.lang()=="java","The retry keeps the chosen language")
	# erasure
	f.begin_erase();n.change("erase")
	advance(3.0);await render("f_erase")
	advance(5.0);await render("f_erase_late")
	check(f.erase>0,"He starts deleting Steve")
	for i in range(14):n.press(w,"accept")
	advance(.5);await render("f_throw")
	advance(.6);await render("f_console")
	advance(3.0);check(n.phase=="qte","The sword breaks the console and starts the cinematic QTE")
	for beat in range(n.qte.ACTIONS.size()):
		advance(.4);n.press(w,n.qte.expected());advance(2.01)
	advance(3.7);check(n.phase=="chair","The completed QTE and table knockout lead to the chair")
	# The old fists mechanics remain available to isolate their earlier tests.
	n.start_fists(w)
	var fi=n.fighter
	check(fi.mode=="fists" and fi.items.size()==4,"Lines of code lie on the floor")
	advance(2.4);fi.ai=false;var s=fi.steve();s.x=fi.items[1].x;n.press(w,"grab");advance(.05)
	check(fi.held(0)!=null,"E picks a line up")
	var nt=fi.notch();nt.x=s.x+1.4;var hp: float=nt.hp;n.press(w,"accept");advance(.4)
	check(hp-nt.hp>=12,"Swinging a line hits harder")
	await render("f_brawl")
	nt.hp=1;s.move="";s.stun=0;fi.start(s,"jab");nt.x=s.x+1.0;nt.block=false;nt.down=0;advance(.4)
	check(fi.state=="finisher","Notch goes down — finisher")
	advance(.5);await render("f_finisher");n.press(w,"accept");advance(1.0);await render("f_wire")
	advance(2.2);check(n.phase=="chair","The wire, then the chair")
	advance(6.0);await render("f_chair_scan")
	check(f.scan()>0,"The scan reads him")
	advance(16.0);await render("f_chair_rage")
	advance(15.8);await render("f_chair_stab")
	n.skip();advance(.1)
	advance(17.8);check(n.phase=="flight","…then the door")
	advance(2.5);await render("f_door")
	advance(6.0);await render("f_flight")
	var themed: bool=false
	for i in range(int(16*60)):
		w.step(1.0/60)
		if w.sounds.has("ch5_ending_theme"):themed=true
		w.sounds.clear()
		if n.finale.age>=f.FLIGHT_OTHER+1.0:break
	check(themed,"The TF2 theme starts near the end of the flight")
	advance(1.5);await render("f_other")
	var stung: bool=false
	for i in range(int(7*60)):
		if n.phase=="credits":break
		w.step(1.0/60)
		if w.sounds.has("ch5_ending_sting"):stung=true
		w.sounds.clear()
	check(stung and n.phase=="credits","A sharp sting, black screen, then the credits")
	advance(12.0);await render("f_credits")
	n.skip();advance(.2);check(w.state!="RESULT","Credits cannot be skipped")
	advance(26.0);check(w.state=="RESULT" and w.victory,"Credits end the chapter")
	print("CHAPTER_FIVE_FINALE_RESULT %d checks; %d failures" % [checks,failures.size()])
	quit(1 if failures.size() else 0)
