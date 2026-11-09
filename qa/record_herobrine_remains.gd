extends SceneTree
var game
var frame=0
var phases={}
func _initialize():run.call_deferred()
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_process(false);game.set_physics_process(false);game.qa_mode="remains_film"
	game.audio.update_volumes(0,0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360);game.settings.shake=false
	game.action("chapter_1");game.world.reset(724);game.world.build={};game.world.finale.begin(game.world)
	for i in range(248):game.world.step(1.0/60)
	game.world.finale.boss.hp=0;game.world.step(1.0/60)
	while game.world.finale.phase!="rift":game.world.step(1.0/60)
	for i in range(270):game.world.step(1.0/60)
	DirAccess.make_dir_recursive_absolute("res://qa/recordings/remains_frames")
	while not game.world.finale.complete:
		game.world.step(1.0/30)
		if not phases.has(game.world.finale.phase):phases[game.world.finale.phase]=frame/30.0
		game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://qa/recordings/remains_frames/%05d.png" % frame);frame+=1
	FileAccess.open("res://qa/recordings/herobrine_remains_timeline.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":30,"frames":frame,"phases":phases,"first_stage_skipped_for_recording":true},"  "))
	game.audio.shutdown();await create_timer(.15).timeout;game.free();game=null;print("REMAINS_FILM_FRAMES ",frame);quit()
