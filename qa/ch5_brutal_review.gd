extends SceneTree
var game
var folder := "res://qa/ch5_brutal/"
func _initialize():run.call_deferred()
func draw(name: String):
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(folder+name+".png")
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
 game.action("chapter_5");var w=game.world;var n=w.notch;var f=n.finale;n.begin(w)
 for phase in ["to_ut","to_quake"]:
  n.change(phase)
  for t in [.89,1.01,1.72,1.80,1.95,2.45]:n.age=t;w.clock=t;await draw(phase+"_%04.2f"%t)
 n.start_qte(w)
 for beat in [0,1,4]:
  for t in [.3,1,1.17,1.6]:
   n.qte.beat=beat;n.qte.age=t;n.qte.resolved=t>.5;n.qte.success=true;await draw("qte_%d_%04.2f"%[beat,t])
 n.begin_bad_end(w)
 for t in [1.0,2.8,4.0]:n.age=t;await draw("bad_%04.2f"%t)
 n.change("chair");f.change("chair")
 for t in [1,22,32.66,32.9,33,33.15,38,39]:f.age=t;w.clock=t;await draw("chair_%05.2f"%t)
 n.change("flight");f.change("flight")
 for t in [1,4.0,6,12,20,25]:f.age=t;w.clock=t;await draw("flight_%05.2f"%t)
 game.audio.shutdown();game.quitting=true;quit()
