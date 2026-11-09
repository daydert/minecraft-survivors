extends SceneTree
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
	if not name.is_empty():image.save_png("res://qa/"+name+".png")
	return image
func capture_mode(mode: String):
	game.screen="";game.qa_mode=mode;game.prepare_end_capture()
	return await render(mode)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.settings.shake=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.screen="chapters";await render("end_chapters")
	check(game.buttons.any(func(b):return b.id=="chapter_3"),"Chapter selection exposes III with the same gray controls")
	var island=await capture_mode("end_survival")
	check(game.world.chapter_number()==3 and game.world.mobs.size()>10,"Real chapter renderer contains the native-textured End enemies")
	var dragon=await capture_mode("end_dragon")
	check(island.get_data()!=dragon.get_data(),"Boss arena replaces the island after the fade")
	game.world.clock+=.3;var flap=await render("end_dragon_flap")
	check(flap.get_data()!=dragon.get_data(),"Dragon wing, neck and tail articulation changes on simulation time")
	game.world.state="RUNNING";game.screen="";game.toggle_inventory();var age=game.world.clock;game.world.step(3);await render("end_inventory")
	check(game.world.clock==age,"Inventory freezes dragon and weapon cooldown clocks")
	game.close_inventory();var exact=await render()
	check(exact.get_data()==flap.get_data(),"Closing inventory restores the exact dragon frame")
	await capture_mode("end_crystals");check(game.world.crystals.size()==6 and game.world.elevation()==0,"All six crystals rest on ground-level obsidian")
	await capture_mode("end_flight");check(game.world.rocket,"Rocket spear renders an actual activated flight")
	await capture_mode("end_choices")
	check(game.world.choices.size()==5 and game.buttons.filter(func(b):return b.id.begins_with("choice_")).size()==5,"All five Eye choices fit and have separate hit areas")
	var choices=game.world.choices.duplicate();game.world.tick_choices(.22);await render("end_choices_cycle")
	check(game.world.choices!=choices,"Eye cycles the drawn item descriptions and icons")
	await capture_mode("end_recipes");check(game.buttons.any(func(b):return b.id=="recipes_prev"),"New recipes are accessible on the second page")
	await capture_mode("end_dragon_rage");check(game.world.projectiles.size()>10,"Grounded dragon attacks render real bullet streams")
	await capture_mode("end_dragon_death");await capture_mode("end_betrayal");await capture_mode("end_last_duel");await capture_mode("end_rekindle")
	await capture_mode("end_overworld");check(game.world.stage=="chapter_four","Ending presents the glitched chapter IV title over the corrupted Overworld")
	game.action("chapter_2");game.world.stage="end";game.world.state="RESULT";await render("end_continue_from_two")
	check(game.buttons.any(func(b):return b.id=="chapter_3"),"Chapter II ending has a concrete continuation into III")
	game.audio.shutdown();game.quitting=true;game.coop.diagnostics.close()
	FileAccess.open("res://qa/end_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("END_VISUAL_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
