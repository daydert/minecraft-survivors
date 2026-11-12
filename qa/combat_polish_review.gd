extends SceneTree
var game
var folder:="res://qa/ch4_combat_polish/"
func _initialize():run.call_deferred()
func shot(name: String):
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(folder+name+".png")
func advance(w,t: float):
 for i in range(ceili(t*60)):
  if w.state=="LEVEL_UP":w.skip_reward()
  w.step(1.0/60,Vector2.ZERO)
func setup_boss():
 game.action("chapter_4");var w=game.world;w.state="RUNNING";w.stage="finale";w.build={};w.items={};w.invulnerable=999;w.note_presented=true;w.time=720
 var e=w.ending;e.begin_summit(w);e.start_intro(w);e.phase="one";e.hb.perched=false;e.tower_h=0;e.hb.p=e.center;w.player=e.center+Vector2(100,50);e.camera_at=e.center;e.music="boss_one"
 return w
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
 game.action("chapter_1");var w=game.world;w.state="RUNNING";w.player=Vector2(1024,1024);w.clock=80;w.time=80;game.settings.lighting=false;await shot("clouds_no_lighting")
 game.settings.lighting=true;await shot("clouds_normal")
 w.add_effect("potion_splash",w.player,.5,{"radius":34.0});w.effects.back().age=.2;await shot("witch_puddle_under_player")
 game.action("chapter_3");w=game.world;w.state="RUNNING";w.stage="clash";w.player=Vector2(1045,1100);w.npc={"from":Vector2(1024,1100),"p":Vector2(1024,1100),"dir":Vector2.RIGHT,"side":Vector2.RIGHT}
 w.build={"sword":8,"spear":8,"bow":5};w.items={"armor":4,"feather":3,"hopper":3};w.evolved={"sword":true}
 for t in [2.0,2.26,2.55,3.1]:
  advance(w,t-w.stage_age);await shot("gear_%04.2f"%t)
 game.action("chapter_4");w=game.world;w.begin_sword_drop();w.stage_age=3;await shot("arrival_has_sword")
 w.stage="survival";w.state="RUNNING";w.time=690;w.clock=690;w.fx.tremor=.4
 var fissures: Array=game.four_renderer.FxView.visible_fissures(game,Vector2(320,180)-w.camera())
 if not fissures.is_empty():w.player=(fissures[0][0]+fissures[0][1])*.5
 await shot("cracks_under_player")
 w.enemy_fields=[{"kind":"poison","p":w.player,"radius":36.0,"life":3.0,"total":4.0,"damage":1,"tick":1}];await shot("infected_witch_puddle")
 w=setup_boss();var e=w.ending;e.start(w,"spiral");var prev:=0.0
 for t in [.5,1.25,1.9,2.65,3.2]:advance(w,t-prev);prev=t;await shot("spiral_%04.2f"%t)
 w=setup_boss();e=w.ending;e.phase="two";e.start(w,"fault_smash");prev=0
 for t in [.3,.9,1.15,1.7,2.05,2.3,2.55,3.0]:advance(w,t-prev);prev=t;await shot("faults_%04.2f"%t)
 for kind in ["hole","rain","rift","tear","day"]:
  w=setup_boss();e=w.ending;e.phase="two";e.start(w,kind);advance(w,1.9);await shot("cast_step_"+kind)
 game.action("menu");game.audio.shutdown();game.quitting=true;print("COMBAT_REVIEW_COMPLETE");quit()
