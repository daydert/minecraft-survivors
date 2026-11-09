extends SceneTree
## Native 640x360 captures plus pause/settings/resource checks in the real UI.
var game
var checks := 0
var failures: Array = []
func _initialize():run.call_deferred()
func check(ok: bool, label: String):
	checks += 1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func render(name: String = "") -> Image:
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var result = root.get_texture().get_image()
	if not name.is_empty():result.save_png("res://qa/chapter_four/"+name+".png")
	return result
func prepare(mode: String):
	game.qa_mode="ch4_"+mode
	game.QAHarness.prepare_four_capture(game)
	game.settings.shake=false;game.settings.flashes=true;game.settings.lighting=true
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/chapter_four"))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	game.screen="chapters";await render("selection")
	check(game.buttons.any(func(b):return b.id=="chapter_4"),"Chapter IV has an actual selection button")
	prepare("arrival");var arrival=await render("arrival")
	prepare("village");var village=await render("village")
	check(arrival.get_data()!=village.get_data(),"Arrival uses its own framing and chapter title")
	var w=game.world;var rng_state=w.rng.state
	for i in range(6):await render()
	check(w.rng.state==rng_state,"Lighting, mist and object animation never consume combat RNG")
	prepare("rage");var rage=await render("rage")
	check(village.get_data()!=rage.get_data(),"Reading the note visibly transforms the pillar aura")
	prepare("note");await render("note")
	check(game.screen=="ch4_note" and game.world.state=="PAUSED" and game.buttons.any(func(b):return b.id=="ch4_note_close"),"The note renders as a paused router overlay")
	var snap=await render()
	for i in range(60):game.world.step(1.0/60,Vector2.RIGHT)
	check(snap.get_data()==(await render()).get_data(),"Every pixel behind the note stays frozen")
	game.close_four_note()
	check(game.world.note_read and game.world.state=="RUNNING","The note returns control through the router")
	prepare("pool");var pool=await render("pool")
	prepare("warning");var warning=await render("hand_warning")
	prepare("hand");var hand=await render("hand")
	check(pool.get_data()!=warning.get_data() and warning.get_data()!=hand.get_data(),"Water, warning shadow and connected grasp have distinct frames")
	game.world.state="PAUSED";var paused=await render("pause")
	var time=game.world.clock
	for i in range(120):game.world.step(1.0/60,Vector2.RIGHT)
	check(game.world.clock==time and paused.get_data()==(await render()).get_data(),"Pause freezes hand animation, water, mist and camera exactly")
	prepare("chain");await render("chain")
	check(game.world.threats.any(func(m):return m.kind=="torch" and m.attack=="windup"),"Hostile torch chains are captured in their warning state")
	prepare("pyramid");var lit=await render("pyramid")
	game.settings.lighting=false;var unlit=await render("unlit")
	check(lit.get_data()!=unlit.get_data(),"The lighting setting controls IV's existing lighting layer")
	var ground=game.textures.ch4_ground.get_image()
	if ground.is_compressed():ground.decompress()
	var sample:=Vector2i(580,280)
	var world_pixel:=Vector2i(game.world.camera().floor()-Vector2(320,180))+sample
	var texel: Color=ground.get_pixelv(world_pixel)
	check(unlit.get_pixelv(sample).is_equal_approx(texel),"Unlit ground is the original opaque baked surface")
	game.cam_lead=Vector2(8,0);var lead=await render()
	check(lead.get_pixelv(sample).is_equal_approx(ground.get_pixelv(world_pixel+Vector2i(8,0))),"Camera lead moves terrain by the same integer offset as the objects")
	game.settings.flashes=false;game.world.stage="arrival";game.world.stage_age=2.4;game.cam_lead=Vector2.ZERO
	await render("reduced_flashes")
	game.audio.set_boss_theme("chapter_four");game.audio._process(1)
	check(game.audio.four_music.playing and game.audio.four_music.stream.resource_path.ends_with("chapter_four/ancestry.ogg") and game.audio.music_mix==1,"Chapter IV uses the imported local Ancestry OGG")
	game.action("menu");game.audio._process(1)
	check(not is_instance_valid(game.audio.four_music) and not game.four_assets_loaded,"Leaving releases IV's music and textures")
	FileAccess.open("res://qa/chapter_four/visual_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	game.audio.shutdown();game.quitting=true
	print("CHAPTER_FOUR_VISUAL_RESULT %d checks; %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
