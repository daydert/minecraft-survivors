extends SceneTree
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: "+label)
	else:failures.append(label);push_error(label)
func key(code: int, echo: bool=false):
	var e=InputEventKey.new();e.physical_keycode=code;e.keycode=KEY_F if code in [KEY_D,KEY_A,KEY_V,KEY_I,KEY_S] else code;e.pressed=true;e.echo=echo
	game._input(e)
func secret():
	for code in [KEY_D,KEY_A,KEY_V,KEY_I,KEY_S,KEY_ENTER]:key(code)
func advance(seconds: float):
	for i in range(ceili(seconds*60)):game.world.step(1.0/60)
func until(phase: String):
	for i in range(2400):
		if game.world.finale.phase==phase:return
		game.world.step(1.0/60)
	check(false,"Reached "+phase)
func render(name: String="") -> Image:
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var image=root.get_texture().get_image()
	if not name.is_empty():image.save_png("res://qa/polish_"+name+".png")
	return image
func difference(a: Image,b: Image) -> float:
	var sum=0.0
	for y in range(20,340,4):
		for x in range(0,640,4):
			var ca=a.get_pixel(x,y);var cb=b.get_pixel(x,y)
			sum+=absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)
	return sum/(160*80*3)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_process(false);game.set_physics_process(false);game.qa_mode="review"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360);game.settings.shake=false
	game.action("chapter_1");var old_world=game.world
	key(KEY_I);check(game.screen=="inventory","Ordinary I still opens the inventory")
	key(KEY_ESCAPE);key(KEY_D,true);check(game.secret_keys.is_empty(),"Autorepeat cannot enter secret letters")
	for code in [KEY_D,KEY_A,KEY_V,KEY_I,KEY_S]:key(code)
	check(game.screen.is_empty() and game.secret_keys=="davis","Typing the secret does not open inventory on its I")
	key(KEY_ENTER)
	check(game.screen=="boss_lab" and game.world.state=="PAUSED","Physical DAVIS then Enter opens the hidden loadout screen")
	await render("boss_lab_herobrine")
	var clock=game.world.clock;game.world.step(10)
	check(game.world.clock==clock,"The hidden selector pauses the exact current encounter")
	key(KEY_ESCAPE)
	check(game.screen.is_empty() and game.world==old_world and game.world.state=="RUNNING","Cancel restores the existing run without replacing it")
	secret();game.action("lab_chapter_2");await render("boss_lab_wither")
	check(game.buttons.filter(func(b):return b.id.begins_with("lab_build_")).size()==4,"Four distinct ready-made top loadouts use the existing buttons")
	game.action("lab_build_0")
	check(game.is_nether() and game.world.stage=="departure" and game.world.build.has("fishing"),"Selected build grants gear and starts the Wither transition")
	advance(1.6+game.world.INTRO_DURATION+.2);await render("wither_arena")
	check(game.world.stage=="wither" and game.world.items.size()==8 and game.world.build.size()==6,"Boss test preserves normal arena arrival and slot limits")
	game.world.build={};game.world.projectiles.clear();game.world.mobs[0].attack_tick=100
	var arena=game.world.ARENA
	for corner in [Vector2(70,70),Vector2(arena.size.x-70,70),Vector2(70,arena.size.y-70),arena.size-Vector2(70,70)]:
		game.world.player=arena.position+corner;game.world.mobs[0].p=game.world.player+Vector2(30,0)
		game.world.arena_camera=(game.world.player+game.world.mobs[0].p)/2+Vector2(0,-28)
		await render("arena_corner_"+str(int(corner.x))+"_"+str(int(corner.y)))
	game.action("chapter_2");game.world.build={};game.world.magma.clear()
	game.world.place_explosive("bed",game.world.db.stats("bed",1))
	game.world.player-=Vector2(0,-18);game.world.player_wither=3
	await render("bed_and_withered_hearts")
	check(game.textures.has("heart_wither") and game.world.explosives[0].kind=="bed","Corrected vanilla bed and original withered hearts render together")
	game.action("chapter_1");game.world.build={};game.world.finale.begin(game.world);advance(4.1)
	game.world.hp=0;game.world.step(.02);await render("herobrine_loss")
	check(game.world.state=="FINALE" and game.world.finale.phase=="defeated","First-stage death keeps the story scene on screen")
	until("fall");advance(2);await render("loss_fall_into_nether")
	until("end");await render("loss_chapter_complete")
	check(game.buttons.any(func(b):return b.id=="chapter_2") and not game.buttons.any(func(b):return b.id=="retry"),"Both outcomes lead to chapter II without the ordinary defeat screen")
	game.action("chapter_1");game.world.build={};game.world.finale.begin(game.world);advance(4.1)
	game.world.finale.boss.hp=0;game.world.step(.02);until("rift")
	advance(1.5);await render("rift_local")
	advance(2.3);await render("rift_expanding")
	advance(1.35);var before=await render("rift_screen_edges")
	until("vanish");var after=await render("rift_wipe_start")
	check(game.blood_rift.visible and difference(before,after)<.06,"The expanded hole remains continuous when the black wave starts")
	advance(.8);await render("black_wave_inner")
	advance(.8);var frozen=await render("black_wave_middle")
	game.world.state="PAUSED";var time=game.world.clock;var age=game.world.finale.phase_age
	await render();game.world.step(3)
	check(game.world.clock==time and game.world.finale.phase_age==age,"Pause also freezes the clearing wave")
	game.world.state="FINALE";var resumed=await render()
	check(frozen.get_data()==resumed.get_data(),"Resuming restores the exact screen-wide wave")
	advance(1.25);await render("black_wave_edges");until("portal");await render("rift_cleared")
	check(not game.blood_rift.visible,"The shader is removed after the black wave has covered the screen")
	game.coop.active=true
	var blocked=true
	for code in [KEY_D,KEY_A,KEY_V,KEY_I,KEY_S,KEY_ENTER]:
		var e=InputEventKey.new();e.physical_keycode=code
		blocked=blocked and not game.secret_input(e)
	game.coop.active=false
	check(blocked and game.screen!="boss_lab","The secret cannot change a coop game")
	FileAccess.open("res://qa/boss_polish_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	game.audio.shutdown();await create_timer(.25).timeout;game.free();game=null
	print("BOSS_POLISH_VISUAL_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
