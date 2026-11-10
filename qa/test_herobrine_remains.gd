extends SceneTree
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: "+label)
	else:failures.append(label);push_error(label)
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
	if not name.is_empty():image.save_png("res://qa/remains_"+name+".png")
	return image
func body_pixels(image: Image) -> int:
	var p: Vector2=game.world.player+Vector2(320,180)-game.world.camera()
	var total=0
	for y in range(int(p.y)-32,int(p.y)+25):
		for x in range(int(p.x)-30,int(p.x)+30):
			var c=image.get_pixel(x,y)
			if c.g>.15 and c.b>.1 and c.g>c.r*1.4:total+=1
	return total
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_process(false);game.set_physics_process(false);game.qa_mode="remains_review"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360);game.settings.shake=false
	game.action("chapter_1");game.world.reset(724);game.world.build={}
	game.world.finale.begin(game.world);game.world.finale.skip_to_fight(game.world);advance(.1);game.world.finale.boss.hp=0;game.world.step(.02)
	until("vanish");advance(1.6);var emerging=await render("after_wave")
	var view=game.finale_renderer.duel.remains_view
	check(is_instance_valid(view) and view.visible and body_pixels(emerging)>=12,"The damaged body is clearly visible while the clearing wave passes")
	until("portal");advance(1.45);var before=await render("on_portal")
	check(body_pixels(before)>=12,"The body stays visible above the dark scene and the portal")
	check(view.z_index>game.blood_rift.z_index,"The full-screen wipe cannot black out the body")
	var state=game.world.rng.state;var clock=game.world.clock;var age=game.world.finale.phase_age
	game.world.state="PAUSED";var a=await render("paused");game.ui_time+=20;game.world.step(8);var b=await render()
	check(a.get_data()==b.get_data() and game.world.clock==clock and game.world.finale.phase_age==age,"Pause freezes the corpse and the portal scene")
	game.world.state="FINALE";var resumed=await render()
	check(resumed.get_data()==before.get_data(),"Resuming restores the same corpse frame")
	check(game.world.rng.state==state,"Rendering the damaged body leaves combat RNG untouched")
	until("fall");advance(.35);var falling=await render("fall_start");var first=body_pixels(falling)
	advance(.5);var middle=await render("fall_middle");var second=body_pixels(middle)
	check(first>0 and second>0 and falling.get_data()!=middle.get_data(),"The distorted body visibly sinks into the open portal")
	advance(.95);await render("submerged")
	check(not view.visible,"The body disappears only after sinking below the portal surface")
	until("end");await render("chapter_end")
	check(game.world.finale.complete and not game.world.victory and game.buttons.any(func(b):return b.id=="chapter_2"),"The original chapter ending and route into the Nether remain intact")
	game.action("chapter_2");await render()
	check(not view.visible,"The corpse layer stays hidden in another chapter")
	game.action("chapter_1");game.world.build={};game.world.finale.begin(game.world);game.world.finale.skip_to_fight(game.world);advance(.1)
	game.world.hp=0;game.world.step(.02);advance(.9);var defeated=await render("ordinary_defeated")
	check(body_pixels(defeated)>=35,"Ordinary death keeps Steve visible as the room darkens")
	until("portal");advance(1);var ordinary=await render("ordinary_loss")
	check(not view.visible and not game.world.finale.first_stage_won,"Ordinary first-stage loss keeps its original body pose")
	check(body_pixels(ordinary)>=35,"Ordinary Steve remains clearly visible above the opening portal")
	until("fall");advance(.5);var fall_start=await render("ordinary_fall_start")
	advance(.5);var fall_middle=await render("ordinary_fall_middle")
	check(body_pixels(fall_start)>=20 and body_pixels(fall_middle)>=12 and fall_start.get_data()!=fall_middle.get_data(),"The ordinary falling body stays visible and animates into the portal")
	game.world.state="PAUSED";var ordinary_paused=await render();var ordinary_clock=game.world.clock
	game.ui_time+=10;game.world.step(3);var ordinary_still=await render()
	check(ordinary_paused.get_data()==ordinary_still.get_data() and game.world.clock==ordinary_clock,"Pause freezes the ordinary falling body")
	game.world.state="FINALE";var ordinary_resumed=await render()
	check(ordinary_resumed.get_data()==fall_middle.get_data(),"Resuming restores the exact ordinary fall frame")
	until("end");await render("ordinary_chapter_end")
	check(game.world.finale.complete and not game.world.victory and game.buttons.any(func(b):return b.id=="chapter_2"),"Ordinary death still ends with the route into the Nether")
	FileAccess.open("res://qa/herobrine_remains_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	game.audio.shutdown();await create_timer(.25).timeout;game.free();game=null;await process_frame
	print("HEROBRINE_REMAINS_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
