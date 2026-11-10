extends SceneTree
## Actual Compatibility renders, exact pause and the finale GPU resource lifetime.
var game
var checks:=0
var failures: Array=[]
const MODES=["intro","tower","vortex_cut","one_strike","two_hole_burst","day_split","last","erase_end","three_hit","death_drag","death_final","death_hold","door_enter"]

func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)

func snapshot() -> String:
	var w=game.world
	return var_to_str([w.clock,w.player,w.hp,w.rng.state,w.ending.age,w.ending.qte,w.ending.hb])

func render(name: String="") -> Image:
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var img=root.get_texture().get_image()
	if not name.is_empty():img.save_png("res://qa/chapter_four_e/"+name+".png")
	return img

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/chapter_four_e"))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false)
	game.settings.shake=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	for mode in MODES:
		game.qa_mode="ch4e_"+mode;game.QAHarness.prepare_four_finale_capture(game)
		var before=snapshot();var img=await render(mode)
		check(not img.is_empty() and before==snapshot(),"Finale renders without advancing combat: "+mode)
	game.qa_mode="ch4e_three_hit";game.QAHarness.prepare_four_finale_capture(game)
	game.world.state="PAUSED";var img=await render("pause");var before=snapshot()
	for i in range(120):game.world.step(1.0/60)
	check(before==snapshot() and img.get_data()==(await render()).get_data(),"Pause preserves the exact fistfight state and pixels")
	game.world.state="RUNNING";game.screen="";game.toggle_stats();before=snapshot()
	for i in range(60):game.world.step(1.0/60)
	game.close_stats()
	check(game.world.state=="RUNNING" and game.screen.is_empty() and before==snapshot(),"Stats restore the same QTE and simulation clock")
	var specs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_finale_assets.json"))
	check(specs.sprites.all(func(n):return game.textures.has(n)),"The finale loads all of its native atlases")
	game.action("menu");await render()
	check(not game.has_meta("ch4_finale_assets") and not game.has_meta("ch4_enc_memory") and not specs.sprites.any(func(n):return game.textures.has(n)),"Menu releases the finale textures and presentation cache")
	game.qa_mode="ch4e_death_final";game.QAHarness.prepare_four_finale_capture(game);await render()
	check(specs.sprites.all(func(n):return game.textures.has(n)),"Re-entering IV reloads the finale after its cache was released")
	game.action("menu");await render()
	check(not specs.sprites.any(func(n):return game.textures.has(n)),"A second exit also releases every finale atlas")
	game.audio.shutdown();game.quitting=true
	FileAccess.open("res://qa/chapter_four_e/visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("CHAPTER_FOUR_FINALE_VISUAL_RESULT %d checks; %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
