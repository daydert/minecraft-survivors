extends SceneTree
var game
func _initialize():run.call_deferred()
func shot(path: String):
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(path)
func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.set_process_input(true);root.size=Vector2i(640,360)
 game.achievements.load_profile("user://qa_export_chapter_access.json");game.action("chapters")
 await shot(args[0]+"_locked.png")
 if not game.achievements.chapter_available(1) or game.achievements.chapter_available(2):quit(1);return
 for code in [KEY_T,KEY_E,KEY_S,KEY_T,KEY_E,KEY_R,KEY_ENTER]:
  var event=InputEventKey.new();event.pressed=true;event.physical_keycode=code;event.keycode=KEY_J;game.input_lock=1;game._input(event)
 await shot(args[0]+"_tester.png")
 var visible=["chapter_1","chapter_2","chapter_3","chapter_4","chapter_5"].all(func(id):return game.buttons.any(func(b):return b.id==id))
 var reloaded=game.achievements.get_script().new();reloaded.load_profile("user://qa_export_chapter_access.json")
 if not visible or not reloaded.tester_access or not reloaded.unlocked.is_empty():quit(1);return
 print("EXPORTED_CHAPTER_ACCESS_OK five_buttons=true persistent=true achievements_unchanged=true")
 game.audio.shutdown();game.coop.diagnostics.close();game.quitting=true;quit()
