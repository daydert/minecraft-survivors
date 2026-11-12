extends SceneTree
## Diagnostic montage: real evolution reveals in I–V, quiet code floor,
## both full failures; continuous successful deletion/QTE/chair/ending.
var game
var frames:=0
var cues: Array=[]
var music: Array=[]
var segments: Array=[]
var folder := "res://qa/recordings/ch5_scene_repairs_frames"
func _initialize():run.call_deferred()
func mark(name: String):segments.append({"name":name,"time":frames/30.0});print("SCENE_REPAIRS_SEGMENT ",name," ",frames/30.0)
func tick(w,move:=Vector2.ZERO):
 for k in range(2):
  if w.state=="CHEST":w.chest_delay=maxf(0,w.chest_delay-1.0/60)
  w.step(1.0/60,move)
  for id in w.sounds:cues.append({"id":id,"time":frames/30.0+k/60.0})
  w.sounds.clear()
 var track: String=game.ch5_music() if game.is_five() else "silence"
 if music.is_empty() or music[-1].track!=track:music.append({"track":track,"time":frames/30.0})
 game.ui_time+=1.0/30;game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(folder+"/%05d.png"%frames);frames+=1
 if frames%900==0:print("SCENE_REPAIRS_CAPTURE ",frames)
func idle(w,seconds: float,move:=Vector2.ZERO):
 for k in range(roundi(seconds*30)):await tick(w,move)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film";game.settings.shake=true;root.size=Vector2i(640,360)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 for chapter in range(1,6):
  game.action("chapter_%d"%chapter);var evo_world=game.world;evo_world.state="RUNNING"
  evo_world.build={"sword":8};evo_world.items={};evo_world.evolved={}
  if chapter==4:
   for part in evo_world.Equipment.components(evo_world.db,"sword"):
    if part.kind=="weapon":evo_world.build[part.id]=int(part.level)
    else:evo_world.items[part.id]=int(part.level)
  else:evo_world.items[evo_world.db.recipes.sword.passive]=5
  mark("evolution_chapter_%d"%chapter);evo_world.open_chest({"born":600.0});await idle(evo_world,2.7)
 game.action("chapter_5");var w=game.world;var n=w.notch;var f=n.finale
 for time in [100.0,300.0,520.0,540.0]:
  w.time=time;w.clock=time;mark("code_plane_%d"%time);await idle(w,2.0)
 w.stage="notch";n.begin(w)
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
 FileAccess.open("res://qa/recordings/ch5_scene_repairs_timeline.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":30,"frames":frames,"sound_events":cues,"music":music,"music_volume":.45,"effects_volume":.65,"segments":segments,"diagnostic_montage":true},"  "))
 if game.has_meta("ch5_view3d"):game.get_meta("ch5_view3d").release()
 await process_frame;game.audio.shutdown();game.quitting=true;print("SCENE_REPAIRS_CAPTURE_COMPLETE ",frames);quit()
