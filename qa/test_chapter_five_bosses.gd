extends SceneTree
## Chapter V stage C: the Terminal and its copy of Steve, the Infinite Loop.
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
func fresh(time: float):
	game.action("chapter_5");var w=game.world
	w.db.data.waves=[{"at":0,"rate":0,"weights":{"token":1}}]
	for id in w.next_event:w.next_event[id]=99999.0
	w.time=time;w.invulnerable=999
	return w
func kind(w,k: String):
	for m in w.mobs:
		if m.kind==k and m.hp>0:return m
	return null
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	# Terminal
	var w=fresh(239.5);w.build={"sword":4,"bow":3,"command_block":2};w.cooldowns={"sword":0.3,"bow":0.3,"command_block":0.3}
	advance(.6);var t=kind(w,"terminal")
	check(t!=null and w.bosses.active(),"At 4:00 the Terminal boots")
	advance(1.0);await render("c_terminal_boot")
	advance(2.0);var c=kind(w,"clone")
	check(c!=null and c.build.has("bow") and c.build.has("command_block"),"It runs a copy of Steve with his own build")
	var hp: float=t.hp;w.hurt(t,50);check(t.hp==hp,"The Terminal is locked while the copy runs")
	var seen:=0
	for i in range(150):
		advance(1.0/60);seen=maxi(seen,w.shots.size()+w.zones.size())
	await render("c_clone")
	check(seen>0,"The copy attacks with your weapons")
	w.build={}
	for i in range(int(30*60)):
		w.step(1.0/60,Vector2.from_angle(w.clock).orthogonal() if i%120<60 else Vector2.ZERO)
		if c.learned:break
	check(c.learned,"After a while the copy learns how you move")
	var evaded:=0
	for i in range(40):
		var before: float=c.hp;w.hurt(c,1);if c.hp==before:evaded+=1
	check(evaded>=4 and evaded<=30,"…and starts dodging some of your hits")
	c.hp=0;w.resolve_deaths();advance(.1)
	check(not t.locked,"With the copy gone the Terminal opens")
	await render("c_terminal_open")
	w.hurt(t,50);check(t.hp<hp,"An open Terminal takes damage")
	advance(16.5);check(kind(w,"clone")!=null,"Left alone, it boots the copy again")
	t.hp=0;w.resolve_deaths()
	check(not w.bosses.active() and w.bosses.terminal_done and kind(w,"clone")==null and w.loot.any(func(o):return o.kind=="chest"),"Closing the Terminal ends the fight with a chest")
	# Infinite loop
	w=fresh(479.5);w.build={};w.bosses.terminal_done=true;advance(.6);var b=kind(w,"loop_boss")
	check(b!=null,"At 8:00 the Infinite Loop starts")
	w.spawn("token",w.player+Vector2(150,0));var tok=w.mobs.back();tok.speed=40.0
	w.bosses.snapshot(w)
	var at: Vector2=tok.p
	advance(3.0,Vector2.RIGHT);check(tok.p.distance_to(at)>20,"Mobs move during the iteration")
	await render("c_loop")
	hp=b.hp;w.hurt(b,40)
	var it: int=w.bosses.loop.i
	for i in range(600):
		if w.bosses.loop.i>it:break
		w.step(1.0/60)
	check(b.hp==hp and tok.p.distance_to(at)<1,"Too little damage: the iteration rolls back, health and positions included")
	check(w.bosses.ghosts.size()==1,"A past self walks the last iteration's path")
	advance(1.5,Vector2.LEFT);await render("c_ghost")
	w.hurt(b,b.max_hp*0.25);var kept: float=b.hp;advance(9.0)
	check(b.hp==kept,"Breaking a fifth of it in one iteration keeps the damage")
	advance(22.0);check(w.bosses.ghosts.size()==3,"Up to three past selves at once")
	await render("c_ghosts")
	b.hp=0;w.resolve_deaths()
	check(not w.bosses.active() and w.bosses.ghosts.is_empty(),"break; ends the loop and its ghosts")
	print("CHAPTER_FIVE_BOSSES_RESULT %d checks; %d failures" % [checks,failures.size()])
	quit(1 if failures.size() else 0)
