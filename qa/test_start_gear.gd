extends SceneTree
## Why every chapter starts from nothing: gear lost on death (I), melted by
## the Wither's blast (II), broken in the last exchange with Ender Steve (III);
## and the iron sword turning up at the spawn in each chapter.
var game
var checks=0
var failures=[]
var out="res://qa/start_gear/"
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
		if game.world.state=="LEVEL_UP":game.world.choose(0)
		elif game.world.state=="CHEST":game.world.chest_delay=0;game.world.close_chest()
		else:game.world.step(1.0/60,movement)
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film";game.settings.shake=false;game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	# The sword at the spawn, in every chapter.
	game.action("chapter_1");game.world.skip_intro();game.world.begin_sword_drop()
	check(game.world.build.get("sword",0)==1 and game.world.sword_drop.is_empty(),"In chapter I Steve walks in with his sword")
	for chapter in [2,3,5]:
		game.action("chapter_%d"%chapter);var w=game.world
		w.begin_sword_drop()
		var guard:=0
		while not w.sword_ready() and guard<60*30:w.step(1.0/60);guard+=1
		check(w.build.is_empty(),"Chapter %d starts unarmed"%chapter)
		advance(.1)
		var t0: float=w.time
		var land: float=w.SWORD_LAND[w.sword_drop.style]
		advance(land*.5);await render("sword_%d_appear"%chapter)
		advance(land*.5+.3);await render("sword_%d_landed"%chapter)
		check(w.time==t0 and w.mobs.filter(func(m):return m.kind not in ["arena_crystal"]).size()==w.mobs.size(),"Chapter %d clock waits for the sword"%chapter)
		for i in range(120):
			if not w.sword_waiting():break
			advance(1.0/60,w.player.direction_to(w.sword_drop.p))
		check(w.build.get("sword",0)==1,"Chapter %d: walking onto the sword picks it up"%chapter)
		advance(.5)
		check(w.time>t0,"Chapter %d run starts once the sword is taken"%chapter)
	game.action("chapter_4");game.world.begin_sword_drop()
	check(game.world.build.get("sword",0)==1 and game.world.sword_drop.is_empty(),"Chapter IV retains EnderSteve's gift without another pickup")
	# II: the Wither's blast melts the gear.
	game.action("chapter_2");var n=game.world
	n.build={"sword":6,"bow":4,"trident":3};n.items={"armor":2,"sugar":1}
	n.begin_arena()
	var guard2:=0
	while n.stage!="wither" and guard2<60*30:n.step(1.0/60);guard2+=1
	var boss=n.mobs.filter(func(m):return m.kind=="wither")[0]
	boss.hp=1;n.hurt(boss,10);n.resolve_deaths()
	check(n.stage=="defeat" and n.molten.size()==5,"The Wither's death takes stock of everything Steve carries")
	advance(1.5);await render("melt_blast")
	advance(1.4);await render("melt_hot")
	advance(1.2);await render("melt_running")
	while n.stage=="defeat" and n.stage_age<n.melt_done()+.1:n.step(1.0/60)
	await render("melt_gone")
	check(n.build.is_empty() and n.items.is_empty(),"Nothing survives the blast")
	advance(1.2)
	check(n.stage=="portal","The chapter goes on to the portal after the gear is gone")
	# III: the last exchange.
	game.action("chapter_3");var e=game.world
	e.prepare_arena();e.mobs.clear();e.stage="last_duel"
	for crystal in e.crystals:crystal.alive=false
	e.spawn("endersteve_final",e.portal_position+Vector2(0,-35));e.player=e.portal_position+Vector2(40,-30)
	e.mobs[0].hp=0;e.resolve_deaths()
	check(e.stage=="clash","Ender Steve's defeat starts a last exchange of blows")
	advance(.4);await render("clash_guard")
	advance(.4);await render("clash_windup")
	advance(.25);await render("clash_hit")
	advance(1.2);await render("clash_break")
	advance(.35);await render("clash_thrown")
	advance(.5);await render("clash_fall")
	while e.stage=="clash":advance(1.0/60)
	advance(5.2);await render("down_talk")
	advance(3.8);await render("down_rise")
	advance(.6);await render("down_rise2")
	advance(1.2);await render("down_spent")
	while e.stage=="down":advance(1.0/60)
	check(e.stage=="to_edge","They get up and walk to the edge as before")
	while e.stage!="sit":advance(1.0/60)
	advance(32.0);await render("sit_sword")
	# I: gear spills on death.
	game.action("chapter_1");var o=game.world;o.skip_intro()
	o.build={"sword":5,"bow":3};o.items={"armor":2}
	o.finale.begin(o);o.finale.skip_to_fight(o);advance(.2)
	o.invulnerable=0;o.hp=0;advance(1.0/60)
	while o.finale.phase_age<o.finale.SHOW_PUNCH+.6:o.step(1.0/60)
	check(o.finale.lost.size()==3,"Steve's gear spills out with the killing blow")
	await render("death_items")
	print("START_GEAR_RESULT %d checks; %d failures" % [checks,failures.size()])
	quit(1 if failures.size() else 0)
