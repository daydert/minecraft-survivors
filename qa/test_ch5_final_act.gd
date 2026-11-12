extends SceneTree
var game
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS ",text)
 else:failures.append(text);push_error(text)
func advance(w,seconds: float):
 for k in range(ceili(seconds*60)):w.step(1.0/60,Vector2.ZERO)
func draw():
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
 game.action("chapter_5");var w=game.world;var n=w.notch;var f=n.finale;n.begin(w)
 var revenge := false;var old_line := false
 for line in f.CHAIR:
  if line[1]=="Мстить — дело слабых.":revenge=line[0]<f.CHAIR_STAB and line[0]+line[2]<=f.CHAIR_STAB
  if str(line[1]).contains("С ней"):old_line=true
 check(revenge and not old_line,"Revenge line completes before the stab; old final line is gone")
 n.change("erase");f.begin_erase();f.erase=.95;f.age=9.5;await draw();var v=game.get_meta("ch5_view3d")
 var arm_visible := true
 for part in ["ra","re"]:
  for mesh in v.rigs.steve[part].get_children():
   if mesh is MeshInstance3D:arm_visible=arm_visible and mesh.visible
 check(arm_visible,"Last deletion warning retains a connected attacking arm")
 check(float(v.rigs.steve.material.get_shader_parameter("erase_amount"))>.2,"Deletion already erodes pixels before the failed attack")
 n.begin_bad_end(w);advance(w,2.4);await draw();v=game.get_meta("ch5_view3d")
 check(v.mode=="bad_end" and v.rigs.notch.root.visible and not v.rigs.steve.root.visible,"Steve disappears mid-attack while Notch remains")
 check(not v.nodes.bad_sword.visible,"Sword dissolves with the attacking hand")
 advance(w,.8);check(n.line=="Пора бы завязать с тестированием.","Notch speaks after Steve has disappeared")
 advance(w,3.8);await draw()
 check(v.nodes.beer.global_position.distance_to(v.rigs.notch.grip.to_global(Vector3(0,.015,.15)))<.001,"Beer can is held by the actual hand")
 check(w.state=="RUNNING","Bad ending waits for Notch's full action")
 advance(w,6.7);await draw();check(absf(v.nodes.bad_door.rotation.y)>.6,"Notch opens the exit before leaving")
 advance(w,4.6);check(w.state=="RESULT" and not w.victory,"Full bad ending still ends in real defeat")
 w.state="RUNNING";n.start_qte(w);var q=n.qte
 var events: Array=[]
 while n.phase=="qte":
  if not q.finishing and not q.resolved and q.age>=.4:n.press(w,q.expected())
  w.step(1.0/60,Vector2.ZERO);events.append_array(q.events)
 check(n.phase=="chair","All successful defensive/attacking beats and knockout reach chair")
 check("ko_punch" in events and "table_hit" in events and not "wire" in events,"Finisher emits face and tabletop contacts instead of wire/glass")
 check(events.count("block")==2 and events.count("counter")==2 and events.count("dodge")==2,"Parries, guard counters and evasions have distinct timed events")
 n.start_qte(w);q.finishing=true;q.finish_age=1.4;await draw();v=game.get_meta("ch5_view3d")
 var jaw: Vector3=v.rigs.notch.head.to_global(Vector3(0,.02,.25))
 check(absf(jaw.y-.96)<.06 and jaw.z>.92,"Jaw reaches the tabletop without sinking through it")
 check(v.nodes.ko_table.visible,"Table belongs to the knockout shot")
 q.finishing=false;q.age=.4;await draw();check(not v.nodes.ko_table.visible,"Table does not pop into the middle of earlier exchanges")
 var spec: Dictionary=v.cache.cinema_tracks
 var keys: Array=[]
 for track in q.TRACKS:
  var poses: Array=[]
  for i in [15,27,30,45]:poses.append(spec["qte_"+track].frames[i].steve)
  keys.append(JSON.stringify(poses))
 var distinct: Dictionary={}
 for key in keys:distinct[key]=true
 check(distinct.size()==8,"All eight actions have distinct authored body mechanics")
 var first_cam: Array=spec.qte_jab.frames[0].cam;var last_cam: Array=spec.qte_jab.frames[-1].cam
 check(first_cam!=last_cam,"Camera follows the exchange")
 var i0: Array=spec.portal_0.frames[26].notch.head;var i1: Array=spec.portal_0.frames[29].notch.head
 check(i0!=i1,"First portal punch visibly snaps the recipient's head")
 for sample in [["bad_end",1.4],["bad_end",6.2],["bad_end",12.1],["qte",1.1],["finisher",1.3],["to_ut",.96],["chair",32.8]]:
  n.change(sample[0]);n.age=sample[1];f.change(sample[0]);f.age=sample[1];w.clock=100+sample[1]
  if sample[0] in ["qte","finisher"]:
   n.change("qte");q.reset();q.beat=3;q.age=sample[1];q.resolved=true;q.success=true;q.resolved_age=.4;q.finishing=sample[0]=="finisher";q.finish_age=sample[1]
  await draw();await draw();v=game.get_meta("ch5_view3d");var before=v.viewport.get_texture().get_image().get_data();var rng_before: int=w.rng.state;var clock_before: float=w.clock
  w.state="PAUSED";advance(w,.4);game.ui_time+=1;await draw()
  check(before==v.viewport.get_texture().get_image().get_data() and w.clock==clock_before,"Exact pause: %s %.2f"%sample)
  check(w.rng.state==rng_before,"Presentation preserves RNG")
  w.state="RUNNING"
 n.start_qte(w);advance(w,7.3);check(n.phase=="bad_end","Missed inputs still lead to the authored bad ending")
 v.release();await process_frame;game.audio.shutdown();game.quitting=true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/ch5_final_act"))
 FileAccess.open("res://qa/ch5_final_act/tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("FINAL_ACT_RESULT ",checks," checks; ",failures.size()," failures");quit(1 if not failures.is_empty() else 0)
