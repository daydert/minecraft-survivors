extends SceneTree
var game
var folder := "res://qa/ch5_scene_repairs/"
func _initialize():run.call_deferred()
func draw(name: String):
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(folder+name+".png")
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
 for chapter in range(1,6):
  game.action("chapter_%d"%chapter);var w=game.world
  if chapter==1:w.state="RUNNING"
  var id: String=w.db.recipes.keys()[0]
  w.build={id:8};w.items={};w.evolved={id:true};w.state="CHEST";w.chest_reward={"id":id,"evolution":true,"text":w.db.recipes[id].effect}
  for delay in [1.4,.8,.2,0.0]:
   w.chest_delay=delay;await draw("evolution_%d_%03.1f"%[chapter,delay])
 game.action("chapter_5");var w=game.world;var n=w.notch;n.begin(w)
 for t in [100,239,300,500,537,540,600,660]:w.stage="survival";w.time=t;w.clock=t;await draw("floor_%d"%t)
 w.stage="notch";n.start_qte(w);n.qte.beat=2;n.qte.age=2.4;n.qte.success=false;await draw("qte_last")
 n.begin_bad_end(w)
 for t in [0.0,.2,1.5,3.0,4.2,5.2,5.55,6.0,7.0,9.2,9.35,10.5,11.0,12.4,14.5,15.8,17.6,18.5,20.0,21.5]:n.age=t;w.clock=100+t;await draw("bad_qte_%05.2f"%t)
 if game.has_meta("ch5_view3d"):game.get_meta("ch5_view3d").release()
 await process_frame;game.audio.shutdown();game.quitting=true;quit()
