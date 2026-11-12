extends SceneTree
var game
var checks := 0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool, text: String):
 checks+=1
 if ok:print("PASS ",text)
 else:failures.append(text);push_error(text)
func draw():
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";root.size=Vector2i(640,360)
 game.action("chapter_5");var w=game.world;var n=w.notch;var f=n.finale;n.begin(w)
 for sample in [["chair",32.55],["chair",33.0],["chair",38.7],["erase",9.0],["flight",3.7],["flight",29.2],["to_ut",2.3],["to_quake",1.76],["fists",.8]]:
  n.change(sample[0]);f.change(sample[0]);f.age=sample[1];n.age=sample[1];w.clock=100+sample[1]
  if sample[0]=="erase":f.erase=.7;f.thrown=.4
  if sample[0]=="fists":
   n.start_fists(w);n.fighter.state="wire";n.fighter.age=.8;n.fighter.steve().x=-.5;n.fighter.notch().x=.5
  await draw();await draw()
  var v=game.get_meta("ch5_view3d");var image=v.viewport.get_texture().get_image().get_data()
  var before: float=w.clock;var age: float=f.age;var pa: float=n.age;var rng_state: int=w.rng.state
  w.state="PAUSED"
  for i in range(20):w.step(1.0/60,Vector2.ZERO)
  game.ui_time+=2;await draw()
  check(w.clock==before and f.age==age and n.age==pa,"Pause preserves clocks: %s %.2f"%sample)
  check(v.viewport.get_texture().get_image().get_data()==image,"Exact paused image: %s %.2f"%sample)
  check(w.rng.state==rng_state,"View and pause preserve combat RNG")
  w.state="FINALE"
 n.change("chair");f.change("chair");f.age=33;await draw()
 var v=game.get_meta("ch5_view3d")
 for t in [5.0,10.0,14.0,18.0,22.0,26.0]:
  f.age=t;await draw()
  var head: Node3D=v.rigs.notch.head
  var facing: Vector3=head.global_basis.z
  var camera_direction: Vector3=(v.nodes.cam.global_position-head.global_position).normalized()
  check(facing.dot(camera_direction)>.2,"Speaking face visible while tracking Steve: %.1f"%t)
 f.age=33;await draw()
 check(v.nodes.sword.get_parent()==v.rigs.steve.grip,"Sword remains attached to wrist control")
 check(v.rigs.steve.re.get_parent()==v.rigs.steve.ra and v.rigs.steve.rk.get_parent()==v.rigs.steve.rl,"Elbow and knee hierarchy is connected")
 var planted: Vector3=v.rigs.steve.rk.to_global(Vector3(0,-.375,0))
 check(absf(planted.y)<.08,"Leading foot supports the stab")
 f.age=32.7;await draw();var support: Vector3=v.rigs.steve.rk.to_global(Vector3(0,-.375,0))
 f.age=33.2;await draw()
 check(v.rigs.steve.rk.to_global(Vector3(0,-.375,0)).distance_to(support)<.002,"Support foot stays planted through the thrust")
 f.age=32.666666667;await draw();var cut_from: Vector3=v.nodes.cam.position
 f.age=32.68;await draw();check(v.nodes.cam.position.distance_to(cut_from)<.002,"60 Hz frame before a cut stays in the outgoing shot")
 f.age=32.7;await draw();check(v.nodes.cam.position.distance_to(cut_from)>.8,"Contact cut selects the incoming shot")
 f.age=32.55;await draw();var prepared: Transform3D=v.rigs.steve.grip.global_transform
 f.age=40;await draw();f.age=32.55;await draw()
 check(v.rigs.steve.grip.global_transform.is_equal_approx(prepared),"Seeking restores the exact preparation pose")
 for phase in ["to_ut","to_lanes","lanes_won","to_quake","to_code"]:
  n.change(phase);n.age=2.3;await draw()
  check(v.rigs.steve.root.scale==Vector3.ONE and v.rigs.notch.root.scale==Vector3.ONE,"Full-scale portal crossing: "+phase)
  check(v.rigs.steve.material.get_shader_parameter("clip_enabled"),"Physical plane clipping: "+phase)
 n.change("flight");f.change("flight");f.age=29.2;await draw()
 check(v.nodes.worlds.size()==11,"Exactly eleven logo universes")
 check(v.nodes.worlds.all(func(x):return x is Sprite3D),"Flight instantiates logos only")
 check(v.nodes.tf2_waters.size()>0,"2Fort water uses simulation-clock materials")
 check(f.CHAIR_STAB==33 and f.FLIGHT_THEME==13 and f.FLIGHT_FADE==23.5 and f.FLIGHT_STING==30.6,"Original event timing contract retained")
 v.release();await process_frame;game.audio.shutdown();game.quitting=true
 print("CH5_CINEMA_RESULT ",checks," checks; ",failures.size()," failures")
 FileAccess.open("res://qa/ch5_cinema/test_result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 quit(1 if not failures.is_empty() else 0)
