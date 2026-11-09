extends SceneTree
var game
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func render(name: String="") -> Image:
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var img=root.get_texture().get_image()
	if not name.is_empty():img.save_png("res://qa/chapter_four_c/"+name+".png")
	return img
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/chapter_four_c"))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.start_chapter(4)
	check(game.four_held_cache.is_empty(),"Entering IV loads no large player equipment atlas eagerly")
	for mode in ["bedrock","shotgun","pool","pet","bell","saw","torch","sky","heart","bat","potion","recipes","recipes2","inventory"]:
		game.qa_mode="ch4c_"+mode;game.QAHarness.prepare_four_arsenal_capture(game)
		var rng=game.world.rng.state;var img=await render(mode)
		check(not img.is_empty(),"Actual Chapter IV scene renders: "+mode)
		check(game.world.rng.state==rng,"Drawing equipment preserves combat RNG: "+mode)
		if mode=="shotgun":check(game.world.effects.any(func(e):return e.kind=="ch4_muzzle"),"Shotgun capture includes the actual muzzle burst")
		if mode=="torch":check(game.textures.has("ch4_red_torch") and game.world.arsenal.links.size()>=3,"Friendly torch capture includes native objects and real linked segments")
	game.qa_mode="ch4c_saw";game.QAHarness.prepare_four_arsenal_capture(game)
	game.world.state="PAUSED";var image=await render("pause");var clock: float=game.world.clock
	for i in range(90):game.world.step(1.0/60,Vector2.RIGHT)
	check(clock==game.world.clock and image.get_data()==(await render()).get_data(),"Pause preserves exact pixels of full Steve, chain, wings, armour and enemies")
	check(not game.world.active_item("heart") and not game.world.active_item("bat"),"Paused input never queues active equipment")
	for id in ["sword_iron","sword_diamond","sword_netherite","bedrock","shotgun","bell","fishing","sky_tnt","bone_saw","potion"]:game.four_held_texture("ch4_held_"+id+"_w3_a1")
	check(game.four_held_cache.size()==8 and game.textures.keys().filter(func(k):return k.begins_with("ch4_held_")).size()==8,"Equipment GPU cache stays bounded at eight actual combinations")
	game.action("menu")
	check(game.four_held_cache.is_empty() and not game.textures.keys().any(func(k):return k.begins_with("ch4_held_") or k.begins_with("ch4_pet_")),"Leaving IV releases held models and companion textures")
	game.audio.shutdown();game.quitting=true
	FileAccess.open("res://qa/chapter_four_c/visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("CHAPTER_FOUR_ARSENAL_VISUAL_RESULT %d checks; %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
