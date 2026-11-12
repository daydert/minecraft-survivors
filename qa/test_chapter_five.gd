extends SceneTree
## Chapter V stage A: tone phases, each code enemy's rule, world events.
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
func fresh():
	game.action("chapter_5");var w=game.world
	w.db.data.waves=[{"at":0,"rate":0,"weights":{"token":1}}]
	for id in w.next_event:w.next_event[id]=99999.0
	w.build={};w.invulnerable=0
	return w
func last(w):return w.mobs.back()
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	var w=fresh()
	check(w.chapter_number()==5 and game.is_five() and w.tone()==0.0 and w.phase_name()=="white","Chapter V starts in the white space")
	w.time=300;check(w.tone()==1.0 and w.phase_name()=="dark","After 4:00 the space is dark")
	w.time=481;var a: float=w.tone();w.time=541;check(a!=w.tone() and w.phase_name()=="flicker","After 8:00 inversions are spaced a minute apart")
	w.time=0
	# for
	w.spawn("for_loop",w.player+Vector2(0,-70));var m=last(w);m.timer=0;w.invulnerable=999
	advance(1.2);check(m.phase=="loop" and m.iter>=0 and w.shots.size()>=5,"for fires one ring per iteration and counts them")
	advance(.3);await render("for_loop")
	advance(3.0);check(m.phase in ["rest","walk"],"for ends after n iterations")
	# while
	w=fresh();w.spawn("while_loop",w.player+Vector2(120,0));m=w.mobs.filter(func(o):return o.kind=="while_loop")[0]
	var cond=w.mobs.filter(func(o):return o.kind=="condition")[0]
	var hp: float=m.hp;w.hurt(m,50);check(m.hp==hp,"while(true) cannot be hurt while its condition stands")
	w.invulnerable=999;advance(.4);await render("while_loop")
	w.hurt(cond,99);w.resolve_deaths();check(m.broken,"Breaking the condition breaks the loop")
	w.hurt(m,10);check(m.hp==hp-10,"A broken loop takes damage")
	# if / else
	w=fresh();w.invulnerable=999;w.spawn("if_else",w.player+Vector2(80,0));m=last(w);m.timer=0;advance(.05)
	check(m.branch==0 and w.shots.size()==3,"Standing on the if side draws its shots")
	await render("if_branch")
	w.shots.clear();w.player=m.p+Vector2(70,0);m.timer=0;advance(.05)
	check(m.branch==1 and w.zones.size()==1,"Standing on the else side draws its slam")
	advance(.4);await render("else_branch")
	# function
	w=fresh();w.invulnerable=999;w.spawn("function",w.player+Vector2(0,-90));m=last(w);m.timer=0;advance(.1)
	check(w.mobs.filter(func(o):return o.kind=="arg").size()==3,"A function calls three arguments")
	advance(.5);await render("function")
	m.hp=0;w.resolve_deaths();check(w.mobs.filter(func(o):return o.kind=="arg").is_empty(),"Its arguments die with it")
	# recursion
	w=fresh();w.spawn("recursion",w.player+Vector2(0,-90));m=last(w);m.hp=0;w.resolve_deaths()
	check(w.mobs.size()==2 and w.mobs[0].depth==1,"Recursion splits one level down")
	for o in w.mobs:o.hp=0
	w.resolve_deaths();check(w.mobs.size()==4 and w.mobs[0].depth==0,"…and again at depth 1")
	for o in w.mobs:o.hp=0
	w.resolve_deaths();check(w.mobs.is_empty(),"Depth 0 is the base case")
	# try / catch
	w=fresh();w.invulnerable=999;w.spawn("try_catch",w.player+Vector2(0,-60));m=last(w);hp=m.hp;w.hurt(m,10)
	check(m.hp==hp and not m.shield and w.shots.size()==1,"try/catch catches the first hit and throws it back")
	w.hurt(m,10);check(m.hp==hp-10,"The next hit lands")
	advance(5.2);check(m.shield,"The catch block re-arms")
	# null
	w=fresh();w.invulnerable=999;w.spawn("null_ref",w.player+Vector2(0,-120));m=last(w);advance(.1)
	check(m.reveal==0.0,"null is unseen at a distance")
	w.hurt(m,1);check(m.reveal>0,"A hit reveals it")
	# array
	w=fresh();w.invulnerable=999;w.spawn("array",w.player+Vector2(0,-100));m=last(w);m.timer=0;advance(.05)
	check(m.index==1 and w.shots.size()==1,"The array fires from the cell under its index")
	advance(1.0);await render("array")
	# glitched mobs
	w=fresh();w.invulnerable=999;w.spawn("glitch_zombie",w.player+Vector2(40,-40));w.spawn("glitch_skeleton",w.player+Vector2(-60,-30));w.spawn("glitch_creeper",w.player+Vector2(0,60))
	check(w.mobs.all(func(o):return o.glitch and not o.code) and w.mobs[0].kind=="zombie","Glitched mobs are vanilla mobs with a glitch flag")
	advance(.5);await render("glitched")
	# world: lag
	w=fresh();w.invulnerable=999;w.spawn("token",w.player+Vector2(200,0));m=last(w);w.next_event.lag=0.0
	advance(.1);check(not w.hint.is_empty() and w.hint.id=="lag","The debug screen announces the next world event")
	await render("hint")
	advance(2.0);var clock: float=w.clock;var at: Vector2=m.p;advance(.2)
	check(w.lag>0 and w.clock==clock and m.p==at,"A lag spike holds the whole simulation")
	await render("lag")
	advance(.4);check(w.lag<=0 and m.p.distance_to(at)>15,"After the spike mobs arrive where they would have been")
	# world: items
	w=fresh();w.next_event.items=0.0;w.invulnerable=999;advance(2.3)
	check(w.shots.size()==5 and not w.shots[0].icon.is_empty(),"Items come alive around the hero")
	await render("items")
	# world: delete
	w=fresh();w.time=250;w.next_event.delete=0.0;w.invulnerable=999;advance(1.0);await render("delete_hint");advance(2.2)
	check(w.deleted.size()==1 and w.deleted[0].age<w.five.world.delete.warn,"A region is marked missing before it goes")
	await render("delete_warn")
	advance(1.2);w.invulnerable=0;hp=w.hp;w.player=w.deleted[0].rect.get_center();advance(.6)
	check(w.hp<hp,"Standing in deleted floor hurts")
	await render("delete_void")
	# world: hijack
	w=fresh();w.time=500;w.next_event.hijack=0.0;w.invulnerable=999;advance(2.2)
	check(w.invert>0,"The world takes the controls: movement is inverted")
	var x: float=w.player.x;advance(.5,Vector2.RIGHT);check(w.player.x<x,"Pressing right walks left")
	advance(4.0);check(not w.hijack.is_empty() and w.mobs.any(func(o):return o.kind=="hijack"),"Then a double appears")
	await render("hijack")
	m=w.mobs.filter(func(o):return o.kind=="hijack")[0];m.hp=0;w.resolve_deaths()
	check(w.hijack.is_empty() and w.invert==0,"Killing the double returns the controls")
	w=fresh();w.time=500;w.next_event.hijack=0.0;w.invulnerable=999;advance(6.5);w.invulnerable=0;hp=w.hp;advance(15.2)
	check(w.hp<hp and w.hijack.is_empty() and w.invert>0,"Failing to kill it in time costs health and control")
	# a natural minute in each tone, for the frames
	for shot in [[60.0,"white"],[330.0,"dark"],[520.0,"flicker"]]:
		game.action("chapter_5");w=game.world;w.time=shot[0];w.build={"sword":6,"bow":5,"axe":4};w.invulnerable=9999
		for id in w.next_event:w.next_event[id]=maxf(w.next_event[id],w.time+8.0)
		advance(14.0,Vector2.ZERO);await render("play_"+shot[1])
	print("CHAPTER_FIVE_RESULT %d checks; %d failures" % [checks,failures.size()])
	quit(1 if failures.size() else 0)
