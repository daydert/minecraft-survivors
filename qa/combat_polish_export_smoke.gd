extends SceneTree
var game
func _initialize():run.call_deferred()
func draw():
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";root.size=Vector2i(640,360)
 game.action("chapter_1");game.world.skip_intro();game.world.player=Vector2(1024,1024);game.settings.lighting=false;await draw()
 assert(game.textures.has("cloud_shadow") and game.textures.cloud_shadow.get_width()==256)
 game.action("chapter_4");var w=game.world;w.begin_sword_drop();assert(w.build.get("sword",0)==1 and w.sword_drop.is_empty())
 w.state="RUNNING";w.stage="finale";w.build={};w.items={};w.invulnerable=999;w.time=720;game.settings.lighting=true
 var e=w.ending;e.begin_summit(w);e.start_intro(w);e.phase="one";e.hb.perched=false;e.tower_h=0;e.hb.p=e.center;w.player=e.center+Vector2(110,65)
 e.start(w,"spiral")
 for k in range(90):w.step(1.0/60)
 await draw();assert(game.textures.has("ch4p_spiral_raise") and game.textures.has("ch4_spiral_spike"))
 e.clear_hazards();e.phase="two";e.start(w,"fault_smash")
 for k in range(144):w.step(1.0/60)
 await draw();assert(game.textures.ch4p_ground_smash.get_width()==2016 and e.terrain_attack.faults.size()==6)
 assert(not root.get_texture().get_image().is_empty())
 var normal: Dictionary=w.db.stats("sword",8,false,{});var evolved: Dictionary=w.db.stats("sword",8,true,{})
 assert(evolved.interval<normal.interval and evolved.damage>normal.damage)
 assert(not w.db.recipes.fishing.effect.contains("оглуш"))
 game.action("menu");assert(not game.has_meta("ch4_combat_animations"))
 print("PACKED_COMBAT_ANIMATIONS_SHA256 ",FileAccess.get_sha256("res://data/chapter_four_combat_animations.json"))
 print("COMBAT_EXPORT_SMOKE PASS: cloud texture, sword continuity, spiral, ground slam/6 faults, atlas frames, improved sword, cleanup, Compatibility")
 game.audio.shutdown();game.quitting=true;quit()
