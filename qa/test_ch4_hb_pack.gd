extends SceneTree
## Herobrine changes from the tester pack (13.11): the Alex lure before the fight,
## orbiting blocks, dash-then-slam, zombies out of the ground, magma walls.
var game
var checks=0
var failures=[]
var folder:="res://qa/ch4_hb_pack/"
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func shot(name: String):
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+name+".png")
func advance(w,t: float):
	for i in range(ceili(t*60)):
		if w.state=="LEVEL_UP":w.skip_reward()
		w.step(1.0/60,Vector2.ZERO)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
	game.action("chapter_4");var w=game.world;w.state="RUNNING";w.stage="finale";w.build={};w.items={};w.invulnerable=999;w.note_presented=true;w.time=720
	var e=w.ending;e.begin_summit(w);w.player=e.center+Vector2(0,150);advance(w,.1)
	check(e.phase=="lure" and e.hb.get("disguise",false),"Herobrine waits disguised as Alex")
	advance(w,1.5);await shot("lure_call")
	advance(w,3.0);await shot("lure_walk")
	advance(w,2.6);await shot("lure_reveal_a")
	advance(w,.25);await shot("lure_reveal_b")
	check(not e.hb.get("disguise",true),"The skin tears off and he shoves Steve")
	advance(w,1.2);await shot("lure_laugh")
	advance(w,3.5);await shot("lure_mock")
	advance(w,8.5)
	check(e.phase in ["intro","tower"],"The lure hands over to his entrance")
	# stage II
	e.clear_hazards();e.phase="two";e.hb.perched=false;e.tower_h=0;e.hb.p=e.center;e.hb.hp=float(e.data.two.hp);e.hb.max_hp=e.hb.hp;e.hb.scale=float(e.data.giant)
	w.player=e.center+Vector2(110,60);e.camera_at=e.center;e.begin_move(w,"rest",.5)
	advance(w,.6);await shot("orbit")
	check(e.hb.has("orbit") and e.hb.orbit.size()==5,"Five blocks circle him in stage II")
	advance(w,4.0)
	var thrown := false
	for i in range(300):
		advance(w,1.0/60)
		if e.shots.any(func(b):return b.kind=="block"):thrown=true;break
	check(thrown,"He flings his blocks at the hero")
	e.start(w,"fault_smash");advance(w,.3);await shot("dash_tell")
	check(e.move=="smash_dash","The ground slam starts with a dash")
	advance(w,.6);check(e.move=="fault_smash","…and only then the slam")
	advance(w,.5);await shot("slam")
	advance(w,3.0);e.start(w,"zombies");advance(w,.6);await shot("graves")
	advance(w,.8);await shot("zombies")
	check(w.mobs.filter(func(m):return m.get("summoned",false)).size()>=4,"Zombies rise out of the ground")
	advance(w,2.0);e.start(w,"magma");advance(w,.8);await shot("magma_walls")
	advance(w,1.0);await shot("magma_throw")
	check(e.hb.walls.size()==4 and e.hb.walls.any(func(x):return x.v!=Vector2.ZERO),"Magma walls rise around him and are thrown one by one")
	print("CH4_HB_PACK_RESULT %d checks; %d failures" % [checks, failures.size()])
	quit(1 if failures.size()>0 else 0)
