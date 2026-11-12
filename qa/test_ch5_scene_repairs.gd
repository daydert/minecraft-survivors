extends SceneTree
var game
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
 else:print("PASS ",label)
func draw():
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
func advance(w,t: float):
 for k in range(ceili(t*60)):w.step(1.0/60,Vector2.ZERO)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
 for ch in range(1,6):
  game.action("chapter_%d"%ch);var w=game.world;w.state="RUNNING"
  var id: String="sword"
  w.build={id:8};w.items={};w.evolved={}
  if ch==4:
   for part in w.Equipment.components(w.db,id):
    if part.kind=="weapon":w.build[part.id]=int(part.level)
    else:w.items[part.id]=int(part.level)
  else:w.items[w.db.recipes[id].passive]=5
  var ready: bool=id in w.evolution_candidates(600)
  check(ready,"Chapter %d: real recipe eligible"%ch)
  w.open_chest({"born":600.0,"p":w.player})
  check(w.state=="CHEST" and w.chest_reward.evolution and is_equal_approx(w.chest_delay,1.7),"Chapter %d: IV reveal duration through real chest flow"%ch)
  w.chest_delay=.2;await draw()
  var im: Image=root.get_texture().get_image();var cyan:=0
  for x in range(286,354):
   for y in range(128,226):
    var color: Color=im.get_pixel(x,y)
    if color.g>color.r*1.4 and color.b>color.r*1.4 and color.g>.2:cyan+=1
  check(cyan>40,"Chapter %d: Steve is actually visible in the reveal"%ch)
  var before: int=w.rng.state;var clock: float=w.clock
  w.state="PAUSED";advance(w,.5);game.ui_time+=2;await draw()
  check(w.rng.state==before and w.clock==clock and is_equal_approx(w.chest_delay,.2),"Chapter %d: reveal pause does not tick simulation/reward timer"%ch)
 game.action("chapter_5");var w=game.world;var n=w.notch;w.stage="notch";n.begin(w);n.start_qte(w)
 n.qte.beat=2;n.qte.age=2.4;n.qte.resolved=true;n.qte.success=false;await draw()
 var v=game.get_meta("ch5_view3d");var entry: Transform3D=v.rigs.steve.root.transform;var cam: Transform3D=v.nodes.cam.transform
 n.begin_bad_end(w);await draw();v=game.get_meta("ch5_view3d")
 check(n.bad_from_qte and v.rigs.steve.root.transform.is_equal_approx(entry) and v.nodes.cam.transform.is_equal_approx(cam),"QTE failure preserves actual body and camera at its first frame")
 check(not v.nodes.bad_sword.visible,"Last sword draw starts after recovery, not inside the opponent")
 n.age=4.2;await draw();var bridge: Transform3D=v.rigs.steve.root.transform
 n.bad_from_qte=false;n.age=0;await draw()
 check(v.rigs.steve.root.transform.is_equal_approx(bridge),"Recovery joins the authored thrust without a reset pose")
 n.age=5.1;await draw();var at: Vector3=v.nodes.beer.global_position
 check(at.distance_to(Vector3(.9,1.1,-1.85))<.015,"Pickup has no snap from the table to a guessed palm")
 n.age=6.9;await draw()
 var rim: Vector3=v.nodes.beer.to_global(Vector3(0,.174,0));var mouth: Vector3=v.rigs.notch.head.to_global(Vector3(0,.18,.275))
 check(rim.distance_to(mouth)<.025,"Beer rim contacts the mouth; centre does not intersect the head")
 n.age=14.05;await draw();check(absf(v.nodes.bad_door.rotation.y)>1.6,"Door opens fully before Notch enters its opening")
 var minimum:=100.0
 for i in range(585,1000):
  n.age=i/60.0;v.sync_bad_end(n);var p: Vector3=v.rigs.notch.root.position
  var table_distance: float=Vector2(maxf(.2-p.x,0)+maxf(p.x-1.1,0),maxf(-2.6-p.z,0)+maxf(p.z+1.7,0)).length()
  minimum=minf(minimum,table_distance)
 check(minimum>.30,"Full exit route clears table by the body radius")
 n.age=10.2;await draw();await draw();var pixels=v.viewport.get_texture().get_image().get_data();var clock: float=w.clock;var rng: int=w.rng.state
 w.state="PAUSED";advance(w,.5);game.ui_time+=1;await draw()
 check(pixels==v.viewport.get_texture().get_image().get_data() and w.clock==clock and w.rng.state==rng,"Pickup/camera freeze exactly on pause")
 w.state="RUNNING";n.age=18.0;advance(w,.3);check(w.state=="RESULT" and not w.victory,"Full exit still ends in genuine defeat")
 w.state="RUNNING";var flips:=0;var last:=1.0;var continuous:=true
 for i in range(480*60,720*60):
  w.time=i/60.0;var tone: float=w.tone()
  if (tone>.5)!=(last>.5):flips+=1
  if absf(tone-last)>.006:continuous=false
  last=tone
 check(flips<=4 and continuous,"Late chapter changes tone at most four times, with gradual five-second fades")
 v.release();await process_frame;game.audio.shutdown();game.quitting=true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/ch5_scene_repairs"))
 FileAccess.open("res://qa/ch5_scene_repairs/tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("SCENE_REPAIRS_RESULT ",checks," checks; ",failures.size()," failures");quit(1 if not failures.is_empty() else 0)
