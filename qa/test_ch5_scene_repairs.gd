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
 check(v.nodes.has("film") and (v.nodes.film as VideoStreamPlayer).is_playing(),"Bad ending plays the rendered film")
 w.state="PAUSED";await draw();check((v.nodes.film as VideoStreamPlayer).paused,"Pause also pauses the film and its sound")
 w.state="RUNNING";n.age=n.BAD_FILM_LENGTH-.01;advance(w,.1);check(n.phase=="bad_credits","After the film: bad-ending card and credits")
 check(w.run_progress.awarded.has("bad_ending"),"Bad ending awards its achievement")
 await draw();n.age=n.BAD_CREDITS_LENGTH-.01;advance(w,.1);check(w.state=="RESULT" and not w.victory,"Credits end in genuine defeat")
 w.state="RUNNING";var flips:=0;var last:=1.0;var continuous:=true
 for i in range(480*60,720*60):
  w.time=i/60.0;var tone: float=w.tone()
  if (tone>.5)!=(last>.5):flips+=1
  if absf(tone-last)>.006:continuous=false
  last=tone
 check(flips<=4 and continuous,"Late chapter changes tone at most four times, with gradual five-second fades")
 if is_instance_valid(v):v.release()
 await process_frame;game.audio.shutdown();game.quitting=true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/ch5_scene_repairs"))
 FileAccess.open("res://qa/ch5_scene_repairs/tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("SCENE_REPAIRS_RESULT ",checks," checks; ",failures.size()," failures");quit(1 if not failures.is_empty() else 0)
