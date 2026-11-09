extends SceneTree
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: "+label)
	else:failures.append(label);push_error(label)
func key(code: int, physical=false):
	var e=InputEventKey.new();e.pressed=true
	if physical:e.physical_keycode=code
	else:e.keycode=code
	game.input_lock=0;game._input(e)
func render(name: String="") -> Image:
	game.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var im=root.get_texture().get_image()
	if not name.is_empty():im.save_png("res://qa/"+name+".png")
	return im
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_process(false);game.set_physics_process(false);game.qa_mode="nether_qa"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.settings.shake=false
	await render()
	check(game.buttons.size()==4,"Main menu retains its four controls")
	game.action("chapters");await render("nether_chapters")
	check(game.buttons.any(func(b):return b.id=="chapter_2"),"Play exposes chapter II selection")
	game.action("chapter_2");game.world.reset(724)
	check(game.world.chapter_number()==2 and game.world.state=="RUNNING","Chapter selection starts Nether")
	game.world.build={"sword":4,"axe":4,"hoe":4,"tnt":4,"crossbow":4,"fishing":4}
	game.world.items={"gold_boots":2,"fire_resist":3,"feather":2,"ghast_tear":2,"armor":3,"blaze":2,"redstone":2,"hopper":2}
	game.world.time=420
	var kinds=["piglin_sword","piglin_crossbow","zombified_piglin","brute","blaze_nether","wither_skeleton","hoglin","zoglin"]
	for i in range(kinds.size()):game.world.spawn(kinds[i],game.world.player+Vector2(-190+(i%4)*118,-60+(i/4)*130))
	game.world.rebuild_hit_grid();game.world.update_attacks(.01)
	game.world.add_effect("hoe_spin",game.world.player+Vector2(90,-10),3,{"radius":36.0,"damage":5.0,"tick":.2,"evolved":false})
	await render("nether_battle")
	for state in ["RUNNING","PAUSED","LEVEL_UP","CHEST"]:
		game.world.state=state
		key(KEY_I,true)
		var clock=game.world.clock;game.world.step(2,Vector2.RIGHT)
		check(game.screen=="inventory" and game.world.clock==clock,"I freezes exact state "+state)
		if state=="RUNNING":
			var a=await render("nether_inventory");game.ui_time+=50;var b=await render()
			check(a.get_data()==b.get_data(),"Inventory and its animations stay frozen")
		key(KEY_ESCAPE)
		check(game.screen.is_empty() and game.world.state==state,"Inventory restores "+state)
	game.world.state="RUNNING";key(KEY_I);game.action("recipes");await render("nether_recipes");check(game.screen=="recipes" and game.world.db.recipes.size()==9,"Recipe book exposes every evolution");key(KEY_ESCAPE);game.action("discard_axe");check(not game.world.build.has("axe"),"Inventory control deletes a selected weapon");key(KEY_I)
	key(KEY_L);await render("nether_stats");key(KEY_L)
	game.world.state="PAUSED";game.screen="settings"
	game.settings.music=.1;game.settings.effects=1
	await render("nether_settings")
	game.action("volume_music_down");game.action("volume_effects_up")
	check(game.settings.music==0 and game.settings.effects==1,"Volume controls reach zero and clamp at one hundred")
	check(game.audio.music.stream_paused,"Zero music volume pauses playback completely")
	game.action("volume_music_up");game.action("volume_effects_down")
	check(is_equal_approx(game.settings.music,.1) and is_equal_approx(game.settings.effects,.9),"Volume controls step in exact ten percent increments")
	game.screen="";game.world.state="RUNNING";game.world.begin_arena()
	await render("wither_departure_start")
	for i in range(60):game.world.step(1.0/60)
	await render("wither_departure_fade")
	while game.world.stage=="departure":game.world.step(1.0/60)
	for i in range(150):game.world.step(1.0/60)
	await render("wither_arrival")
	while game.world.stage=="arrival":game.world.step(1.0/60)
	game.world.mobs[0].attack_tick=0;game.world.move_mobs(.01)
	await render("nether_wither")
	game.world.mobs[0].hp=game.world.mobs[0].max_hp*.4
	game.world.hazards.append({"p":game.world.player+Vector2(40,0),"radius":44.0,"wait":1.0,"damage":4.0,"fire":false})
	await render("nether_wither_rage")
	key(KEY_I);var a=await render();game.world.step(10);game.ui_time+=100;var b=await render()
	check(a.get_data()==b.get_data(),"Inventory freezes boss telegraphs and hazard clocks")
	key(KEY_I);game.world.mobs[0].hp=0;game.world.resolve_deaths()
	for i in range(65):game.world.step(1.0/60)
	await render("wither_collapse")
	while game.world.stage=="defeat":game.world.step(1.0/60)
	game.world.player=game.world.loot.filter(func(o):return o.kind=="ender_eye")[0].p;game.world.pickup(.01)
	game.world.player=game.world.portal_position+Vector2(42,0);game.world.step(.01)
	for i in range(18):game.world.step(1.0/60)
	await render("wither_pearl_throw")
	for i in range(50):game.world.step(1.0/60)
	await render("wither_portal_ignition")
	while game.world.stage=="lighting":game.world.step(1.0/60)
	await render("nether_end_portal")
	game.world.player=game.world.portal_position;game.world.step(.01)
	for i in range(30):game.world.step(1.0/60)
	await render("wither_portal_jump")
	while game.world.stage in ["jump","crossing"]:game.world.step(1.0/60)
	await render("nether_end")
	check(game.world.stage=="end" and game.buttons.any(func(btn):return btn.id=="retry"),"End screen follows automatic portal entry and supports retry")
	game.action("retry");check(game.world.stage=="survival" and game.world.build=={"sword":1},"Retry remains in chapter II with a clean build")
	game.action("menu");game.world.reset(724);game.world.finale.begin(game.world)
	game.world.finale.boss.hp=0
	while not game.world.finale.complete and game.world.state=="FINALE":game.world.step(1.0/60)
	await render("nether_chapter_one_link")
	check(game.buttons.any(func(btn):return btn.id=="chapter_2"),"Chapter I ending offers continuation to chapter II")
	FileAccess.open("res://qa/nether_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	game.audio.shutdown();await create_timer(.2).timeout;game.free();game=null;await process_frame
	print("NETHER_UI_RESULT ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
