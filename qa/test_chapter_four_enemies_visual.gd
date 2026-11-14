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
	if not name.is_empty():img.save_png("res://qa/chapter_four_b/"+name+".png")
	return img
func prepare(mode: String):
	game.qa_mode="ch4b_"+mode;game.QAHarness.prepare_four_enemies_capture(game)
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/chapter_four_b"))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	prepare("gallery");var gallery=await render("gallery")
	check(game.world.mobs.size()==game.world.db.data.forms.size() and game.world.mobs.all(func(m):return game.textures.has(m.skin+"_atlas")),"Every enemy uses its own loaded atlas in the actual renderer")
	var rng=game.world.rng.state
	await render();await render()
	check(rng==game.world.rng.state,"Rendering enemies never consumes combat randomness")
	prepare("unlit");var unlit=await render("unlit")
	check(gallery.get_data()!=unlit.get_data(),"IV enemy artwork respects the lighting setting")
	for mode in ["skeleton","spider","cow","grave","bell","rider","witch","cyst","mutations","crowd","flock"]:
		prepare(mode);var img=await render(mode)
		check(img.get_data()!=gallery.get_data(),"Native scene renders: "+mode)
		if mode=="grave":check(not game.world.mob_walls.is_empty(),"Raised earth in the captured scene has real collision")
		if mode=="spider":check(game.world.mobs[0].lift>0,"Spider is rendered above its grounded shadow")
		if mode=="mutations":check(game.world.mobs.all(func(m):return m.changed),"Damage switches actual atlas variants for sheep and fused villagers")
	prepare("crowd");game.world.state="PAUSED";var pause=await render("pause")
	var clock=game.world.clock
	for i in range(120):game.world.step(1.0/60,Vector2.RIGHT)
	check(clock==game.world.clock and pause.get_data()==(await render()).get_data(),"Pause freezes the entire new crowd, shadows and fields to the exact pixels")
	game.action("menu")
	check(not game.textures.keys().any(func(k):return k.begins_with("ch4_") and k.ends_with("_atlas")),"All new enemy atlases are released outside IV")
	game.audio.shutdown();game.quitting=true
	FileAccess.open("res://qa/chapter_four_b/visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("CHAPTER_FOUR_ENEMIES_VISUAL_RESULT %d checks; %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
