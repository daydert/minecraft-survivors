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
	for i in range(1500):
		if game.world.finale.phase==phase:return
		game.world.step(1.0/60)
	check(false,"Reached phase "+phase)
func render(name: String="") -> Image:
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var im=root.get_texture().get_image()
	if not name.is_empty():im.save_png("res://qa/"+name+".png")
	return im
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_process(false);game.set_physics_process(false);game.qa_mode="herobrine_review"
	game.settings.shake=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.action("chapter_1");game.world.reset(724);game.world.build={}
	game.world.finale.begin(game.world);game.world.finale.skip_to_fight(game.world);advance(.1)
	await render("herobrine_seated")
	check(game.world.finale.phase=="storm","Solo encounter renders its first stage")
	game.world.finale.fight_age=16
	game.world.finale.boss.hp=0;game.world.step(1.0/60);advance(.6)
	var rise_a=await render("herobrine_rise_start")
	advance(2)
	var rise_b=await render("herobrine_rise_end")
	check(rise_a.get_data()!=rise_b.get_data(),"Standing uses distinct articulated poses")
	until("summon");advance(.25);await render("herobrine_teleport_depart")
	advance(.5);await render("herobrine_teleport_arrive")
	check(game.world.finale.teleported,"Hero rematerializes at the throne")
	until("kneel");advance(.95);await render("herobrine_kneel")
	until("rift");advance(.75);await render("herobrine_rift_open")
	advance(1.4);var before=await render("herobrine_blood_rift")
	check(game.blood_rift.visible and game.world.hp==0,"Blood distortion renders through the production screen shader")
	game.pause_from="FINALE";game.world.state="PAUSED"
	var clock=game.world.clock;var age=game.world.finale.phase_age
	var a=await render("herobrine_ritual_paused");game.ui_time+=30;game.world.step(5);var b=await render()
	check(a.get_data()==b.get_data() and game.world.clock==clock and game.world.finale.phase_age==age,"Pause freezes the ritual, including all particles")
	game.world.state="FINALE";var resumed=await render()
	check(resumed.get_data()==before.get_data(),"Resuming restores the exact distortion frame")
	until("vanish");advance(.9);await render("herobrine_vanish")
	until("portal");advance(1.5);await render("herobrine_nether_portal")
	until("fall");advance(2.1);await render("herobrine_fall")
	until("end");await render("herobrine_chapter_end")
	check(game.world.finale.complete and game.buttons.any(func(btn):return btn.id=="chapter_2"),"New ritual preserves the route into chapter II")
	game.action("chapter_2")
	check(game.world.chapter_number()==2 and not game.world.win_music,"Entering the next location resets the post-victory track")
	FileAccess.open("res://qa/herobrine_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	game.audio.shutdown();await create_timer(.3).timeout;game.free();game=null;await process_frame
	print("HEROBRINE_VISUAL_RESULT ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
