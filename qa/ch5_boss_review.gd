extends SceneTree
## Snapshots of the Notch fight: stage 1, battle box patterns, close-combat QTE.
var game
var folder := "res://qa/ch5_boss/"
func _initialize():run.call_deferred()
func draw(name: String):
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(folder+name+".png")
func sim(w, secs: float, move := Vector2.ZERO):
 for i in range(int(secs*60)):w.notch.step(w,1.0/60,move);w.clock+=1.0/60
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
 game.action("chapter_5");var w=game.world;var n=w.notch;n.begin(w)
 var only: String=OS.get_environment("ONLY")
 if only.is_empty() or only=="fight":
  n.start_fight(w)
  for k in range(8):
   n.attack_timer=99.0;n.attack(w)
   for t in [.3,.75,1.3]:
    sim(w,t-(0.0 if t==.3 else [.3,.75,1.3][[.3,.75,1.3].find(t)-1]),Vector2(.3,0))
    w.hp=20.0;await draw("fight_%d_%04.2f"%[k,t])
   sim(w,1.2)
 if only.is_empty() or only=="ut":
  n.start_ut(w)
  await draw("ut_menu")
  for wave in range(1,10):
   n.ut_wave=wave-1;n.begin_wave(w)
   for t in [1.3,2.6,4.2,5.8]:

    while (n.WAVE_LENGTH - n.ut_timer) < t and n.ut_state=="wave":
     n.step(w,1.0/60,Vector2(sin(w.clock*2),cos(w.clock*1.3))*.6);w.clock+=1.0/60;w.hp=20.0
    await draw("ut_w%d_%03.1f"%[wave,t])
  n.ut_state="bar";n.bar=.4;await draw("ut_bar")
  n.strike(w);sim(w,.3);await draw("ut_slash")
 if only.is_empty() or only=="qte":
  n.start_qte(w)
  for beat in range(8):
   for t in [.5,.9,1.03,1.2,1.5,2.0]:
    n.qte.beat=beat;n.qte.age=t;n.qte.resolved=t>.6;n.qte.success=true;n.qte.resolved_age=.6;await draw("qte_%d_%04.2f"%[beat,t])
  n.qte.beat=3;n.qte.age=1.1;n.qte.resolved=true;n.qte.success=false;await draw("qte_miss")
  n.qte.finishing=true
  for t in [.3,.6,.72,1.0,1.2,2.5]:n.qte.finish_age=t;await draw("fin_%04.2f"%t)
 if game.has_meta("ch5_view3d"):game.get_meta("ch5_view3d").release()
 await process_frame;game.audio.shutdown();game.quitting=true;quit()
