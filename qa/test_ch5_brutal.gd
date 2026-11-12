extends SceneTree
var game
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS ",text)
 else:failures.append(text);push_error(text)
func advance(w,seconds: float,move:=Vector2.ZERO):
 for k in range(ceili(seconds*60)):w.step(1.0/60,move)
func draw():
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
 game.action("chapter_5");var w=game.world;var n=w.notch;var f=n.finale
 check(w.db.weapons.has("repeating_block") and w.db.passives.has("breakpoint"),"New equipment belongs to V reward pool")
 check(w.db.recipes.repeating_block.passive=="breakpoint","New weapon has an obtainable evolution")
 w.items.breakpoint=1;w.invulnerable=0;w.hp=20;w.damage_player(4)
 check(w.hp==20 and w.arsenal.breakpoint_ready>17,"Breakpoint blocks a real hit")
 w.invulnerable=0;w.damage_player(4);check(w.hp==16,"Breakpoint cooldown prevents permanent immunity")
 w.loot.clear();w.break_pumpkin({"p":w.player,"has_heal":true});check(w.loot[0].kind=="healing_v","Crate drops a healing potion")
 w.pickup(1.0/60);check(w.hp==20,"Potion actually restores four HP")
 check(w.db.title("healing_v")=="Зелье лечения","Healing item has the correct name")
 w.loot.clear();w.mobs.clear();w.time=100;w.cache_ready=0
 for i in range(12):w.spawn("array",w.player+Vector2(150,i*5));w.mobs[-1].hp=0
 w.resolve_deaths();check(w.loot.size()==1,"Many ordinary code enemies yield one spaced cache")
 w.build={"repeating_block":1};w.cooldowns={};w.spawn("token",w.player+Vector2(40,0));w.rebuild_hit_grid();w.arsenal.update_attacks(w,.1)
 check(w.arsenal.commands.size()==3,"Repeating command block schedules a three-pulse attack")
 n.begin(w);n.start_lanes(w);n.schedule=[{"at":999,"kind":"zombie","row":0}];var start: Vector2i=n.cursor
 var key:=InputEventKey.new();key.physical_keycode=KEY_D;key.keycode=KEY_D;key.pressed=true
 game._input(key);w.step(1.0/60,Vector2.RIGHT)
 check(n.cursor==start+Vector2i.RIGHT,"Physical keydown plus held input advances exactly one PvZ cell")
 advance(w,.20,Vector2.RIGHT);check(n.cursor==start+Vector2i.RIGHT,"Short press does not autorepeat")
 advance(w,.15,Vector2.RIGHT);check(n.cursor==start+Vector2i.RIGHT*2,"Held key repeats only after initial delay")
 advance(w,.02);n.press(w,"left");advance(w,.02,Vector2.LEFT)
 check(n.cursor==start+Vector2i.RIGHT,"Direction change still advances one cell")
 n.change("erase");f.begin_erase();advance(w,10.1)
 check(n.phase=="bad_end","Ignoring deletion enters bad ending")
 advance(w,18.3);check(w.state=="RESULT" and not w.victory,"Deletion failure is a genuine defeat")
 w.state="RUNNING";n.change("erase");f.begin_erase()
 for i in range(14):n.press(w,"accept");advance(w,.18)
 advance(w,3.8);check(n.phase=="qte","Resisting deletion starts the cinematic QTE")
 var q=n.qte
 # Six deliberate successes, plus block/dodge, complete the full sequence.
 for i in range(q.ACTIONS.size()):
  advance(w,.4);n.press(w,q.expected());advance(w,2.01)
 check(n.phase=="qte" and q.finishing,"Successful QTE reaches its knockout finisher")
 advance(w,3.7);check(n.phase=="chair","Knockout at the table reaches the chair")
 n.start_qte(w);advance(w,7.3)
 check(n.phase=="bad_end","Three missed QTE prompts cause bad ending")
 n.age=3;await draw();n.start_qte(w);await draw()
 var reset_view=game.get_meta("ch5_view3d")
 check(reset_view.rigs.steve.material.get_shader_parameter("erase_amount")==0 and reset_view.rigs.notch.root.visible,"Restarting a staged QTE resets erased materials and visibility")
 w.state="RUNNING";n.start_qte(w);advance(w,.4);n.press(w,"right")
 check(q.mistakes==1,"Wrong direction has a consequence")
 n.press(w,q.expected());check(q.mistakes==1 and not q.success,"Repeated keys cannot overwrite a missed beat")
 # Real image freeze, including freshly emitted impact fragments.
 for sample in [["to_ut",1.95],["qte",1.2],["chair",33.1],["flight",1.0],["flight",12.0],["bad_end",2.8],["finisher",.5]]:
  n.change(sample[0]);n.age=sample[1];f.change(sample[0]);f.age=sample[1];w.clock=sample[1]
  if n.phase=="finisher":n.change("qte");q.finishing=true;q.finish_age=sample[1]
  elif n.phase=="qte":q.reset();q.beat=1;q.age=sample[1];q.resolved=true;q.success=true
  await draw();await draw();var v=game.get_meta("ch5_view3d");var a=v.viewport.get_texture().get_image().get_data();var clock_before: float=w.clock
  w.state="PAUSED";advance(w,.5);game.ui_time+=1;await draw()
  check(a==v.viewport.get_texture().get_image().get_data() and w.clock==clock_before,"Exact pause: %s %.2f"%sample);w.state="RUNNING"
 n.change("flight");f.change("flight");f.age=1;await draw();var v=game.get_meta("ch5_view3d")
 var door_blood: float=v.rigs.steve.material.get_shader_parameter("blood_amount")
 f.age=12;await draw();var mid_blood: float=v.rigs.steve.material.get_shader_parameter("blood_amount")
 f.age=25;await draw();var end_blood: float=v.rigs.steve.material.get_shader_parameter("blood_amount")
 check(door_blood>.6 and mid_blood>0 and mid_blood<door_blood and end_blood==0,"Blood visibly sheds over the flight")
 check(f.FLIGHT_THEME==13 and f.FLIGHT_FADE==23.5 and f.FLIGHT_STING==30.6,"Ending theme/fade/sting retain original events")
 v.release();await process_frame;game.audio.shutdown();game.quitting=true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/ch5_brutal"))
 FileAccess.open("res://qa/ch5_brutal/tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("BRUTAL_RESULT ",checks," checks; ",failures.size()," failures");quit(1 if not failures.is_empty() else 0)
