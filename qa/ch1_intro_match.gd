extends SceneTree
func _initialize():run.call_deferred()
func run():
 var g=load('res://scenes/main.tscn').instantiate();root.add_child(g)
 g.set_process(false);g.set_physics_process(false);g.set_process_input(false);g.qa_mode='review';g.settings.shake=false
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
 g.start_chapter(1)
 assert(g.world.state=='INTRO')
 g.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png('res://qa/cinematics/ch1_intro/game_intro_first.png')
 g.audio.shutdown();g.quitting=true;quit()
