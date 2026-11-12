extends SceneTree
var game
var folder := "res://qa/ch5_final_act/"
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
  for t in [.89,.95,1.08,1.30,1.8]:n.age=t;w.clock=t;await draw(phase+"_%04.2f"%t)
 n.start_qte(w)
 for beat in range(8):
  for t in [.35,1.05,1.5]:
   n.qte.beat=beat;n.qte.age=t;n.qte.resolved=t>.6;n.qte.success=true;n.qte.resolved_age=.4;await draw("qte_%d_%04.2f"%[beat,t])
 n.qte.finishing=true
 for t in [.1,.65,1.0,1.15,1.5,3.3]:n.qte.finish_age=t;await draw("finisher_%04.2f"%t)
 n.begin_bad_end(w)
 for t in [.5,1.2,1.9,2.5,3.4,4.5,5.8,6.6,8,10,12,13.5,15]:n.age=t;w.clock=t;await draw("bad_%05.2f"%t)
 n.change("chair");f.change("chair")
 for t in [30.9,32.0,33.1,35]:
  f.age=t;f.line="";f.cues=0;n.line="";f.chair_step(0);n.finale_sounds(w,"");w.clock=t;await draw("chair_%05.2f"%t)
 if game.has_meta("ch5_view3d"):game.get_meta("ch5_view3d").release()
 await process_frame;game.audio.shutdown();game.quitting=true;quit()
