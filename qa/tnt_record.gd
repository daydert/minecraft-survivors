extends SceneTree
var game
var frame=0
var sound_events=[]
func _initialize():run.call_deferred()
func shot():
	for id in game.world.sounds:sound_events.append({"id":id,"time":frame/30.0})
	game.world.sounds.clear()
	game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://qa/recordings/tnt_frames/%05d.png" % frame);frame+=1
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_process(false);game.set_physics_process(false);game.qa_mode="film"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360);game.settings.shake=false
	game.action("chapter_2");game.world.reset(724);game.world.state="RUNNING";game.world.time=400
	game.world.build={"tnt":8};game.world.magma.clear();game.world.mobs.clear()
	DirAccess.make_dir_recursive_absolute("res://qa/recordings/tnt_frames")
	for evolution in [false,true]:
		game.world.evolved={"tnt":true} if evolution else {}
		game.world.facing=Vector2.RIGHT;game.world.message="Цепная реакция" if evolution else "ТНТ VIII";game.world.message_timer=100
		game.world.place_explosive("tnt",game.world.db.stats("tnt",8,evolution))
		for i in range(135):
			game.world.facing=Vector2.UP if i<16 else Vector2.LEFT if i<26 else Vector2.DOWN if i<36 else Vector2.RIGHT
			game.world.clock+=1.0/30;game.world.update_explosives(1.0/30);game.world.update_effects(1.0/30);game.world.update_particles(1.0/30)
			game.world.animation.advance(game.world,1.0/30);await shot()
	FileAccess.open("res://qa/recordings/tnt_timeline.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":30,"frames":frame,"sound_events":sound_events,"segments":{"ordinary":0.0,"evolved":4.5},"scripted_facing":true},"  "))
	game.audio.shutdown();await create_timer(.15).timeout;game.free();game=null;print("TNT_FILM_FRAMES ",frame);quit()
