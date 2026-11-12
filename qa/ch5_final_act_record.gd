extends SceneTree
## Diagnostic showcase: selected survival/boss setups, both failures,
## all portal punches; continuous successful deletion/QTE/chair/ending.
var game
var frames:=0
var cues: Array=[]
var music: Array=[]
var segments: Array=[]
var folder := "res://qa/recordings/ch5_final_act_frames"
func _initialize():run.call_deferred()
func mark(name: String):segments.append({"name":name,"time":frames/30.0});print("FINAL_ACT_SEGMENT ",name," ",frames/30.0)
func tick(w,move:=Vector2.ZERO):
 for k in range(2):
  w.step(1.0/60,move)
  for id in w.sounds:cues.append({"id":id,"time":frames/30.0+k/60.0})
  w.sounds.clear()
 var track: String=game.ch5_music()
 if music.is_empty() or music[-1].track!=track:music.append({"track":track,"time":frames/30.0})
 game.ui_time+=1.0/30;game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(folder+"/%05d.png"%frames);frames+=1
 if frames%900==0:print("FINAL_ACT_CAPTURE ",frames)
func idle(w,seconds: float,move:=Vector2.ZERO):
 for k in range(roundi(seconds*30)):await tick(w,move)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film";game.settings.shake=true;root.size=Vector2i(640,360)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 game.action("chapter_5");var w=game.world;var n=w.notch;var f=n.finale
 n.begin(w)
 for phase in ["to_ut","to_lanes","lanes_won","to_quake","to_code"]:
  n.change(phase);mark(phase);await idle(w,4.4)
 n.change("erase");f.begin_erase();mark("deletion_failure_full")
 while n.phase=="erase":await tick(w)
 while n.phase=="bad_end" and w.state!="RESULT":await tick(w)
 w.state="RUNNING";n.start_qte(w);mark("qte_failure_full")
 while n.phase=="qte":await tick(w)
 while n.phase=="bad_end" and w.state!="RESULT":await tick(w)
 w.state="RUNNING";n.change("erase");f.begin_erase();mark("success_deletion")
 await idle(w,4)
 for k in range(14):n.press(w,"accept");await idle(w,.2)
 while n.phase=="erase":await tick(w)
 assert(n.phase=="qte")
 mark("success_qte_full")
 while n.phase=="qte":
  var q=n.qte
  if not q.finishing and not q.resolved and q.age>=.40:n.press(w,q.expected())
  await tick(w)
 assert(n.phase=="chair");mark("chair_full")
 while n.phase=="chair":await tick(w)
 mark("door_flight_full")
 while n.phase=="flight":await tick(w)
 mark("credits_full")
 while n.phase=="credits":await tick(w)
 FileAccess.open("res://qa/recordings/ch5_final_act_timeline.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":30,"frames":frames,"sound_events":cues,"music":music,"music_volume":.45,"effects_volume":.65,"segments":segments,"diagnostic_montage":true},"  "))
 if game.has_meta("ch5_view3d"):game.get_meta("ch5_view3d").release()
 await process_frame;game.audio.shutdown();game.quitting=true;print("FINAL_ACT_CAPTURE_COMPLETE ",frames);quit()
