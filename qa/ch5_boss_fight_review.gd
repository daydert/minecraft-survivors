extends SceneTree
## Stage one of the Notch fight: each attack frozen at its telegraph and its hit.
var game
var folder := "res://qa/ch5_boss/"
func _initialize():run.call_deferred()
func draw(name: String):
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(folder+name+".png")
func sim(w, secs: float, move := Vector2.ZERO):
 for i in range(int(secs*60)):w.notch.step(w,1.0/60,move);w.clock+=1.0/60;w.hp=20.0;w.invulnerable=0.0
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
 game.action("chapter_5");var w=game.world;var n=w.notch;n.begin(w);n.start_fight(w)
 for enraged in [false,true]:
  if enraged:n.hp=n.FIGHT_HP*.49;sim(w,2.4);await draw("fight_rage")
  for kind in n.PHASE_ONE:
   n.hz.clear();n.spiral_left=0;n.slam_age=-1;n.busy=0;n.attack_timer=99
   n.launch(w,kind);n.busy=99
   var last:=0.0
   for t in [.5,1.0,1.5,2.2]:
    sim(w,t-last,Vector2(.4,-.2));last=t
    await draw("fight_%s%s_%03.1f"%["B_" if enraged else "A_",kind,t])
 if game.has_meta("ch5_view3d"):game.get_meta("ch5_view3d").release()
 await process_frame;game.audio.shutdown();game.quitting=true;quit()
