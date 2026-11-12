extends SceneTree
var game
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures.append(label);push_error(label)
func image_now() -> Image:
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false);return root.get_texture().get_image()
func advance(w,seconds: float):
 for j in range(ceili(seconds*60)):w.step(1.0/60,Vector2.ZERO)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;root.size=Vector2i(640,360)
 game.action("chapter_1");var w=game.world;w.state="RUNNING";w.player=Vector2(1024,1024);w.clock=80;game.settings.lighting=false;await image_now()
 check(game.textures.has("cloud_shadow") and game.textures.cloud_shadow.get_width()==256,"Original square cloud mask loads even with lighting disabled")
 var cloud: Image=game.textures.cloud_shadow.get_image();var max_alpha:=0.0
 for x in range(cloud.get_width()):
  for y in range(cloud.get_height()):max_alpha=maxf(max_alpha,cloud.get_pixel(x,y).a)
 check(max_alpha<=.103 and max_alpha>=.09,"Cloud shadow opacity stays near 10 percent")
 w.state="PAUSED";var before:=await image_now();var rng_before: int=w.rng.state;advance(w,.5);game.ui_time+=1;var after:=await image_now()
 check(before.get_data()==after.get_data() and w.rng.state==rng_before,"Clouds freeze with the world, without RNG changes")
 w.state="RUNNING";before=await image_now();w.add_effect("potion_splash",w.player,.5,{"radius":34.0});w.effects.back().age=.2;var puddle:=await image_now()
 check(game.textures.has("witch_puddle") and before.get_data()!=puddle.get_data(),"Witch puddle draws as a real floor texture")
 game.action("chapter_4");w=game.world;w.state="RUNNING";w.stage="finale";w.build={};w.items={};w.invulnerable=999;w.time=720;game.settings.lighting=true
 var e=w.ending;e.begin_summit(w);e.start_intro(w);e.phase="one";e.hb.p=e.center;e.hb.perched=false;e.tower_h=0;w.player=e.center+Vector2(120,60);e.start(w,"spiral");advance(w,1.4);await image_now()
 check(game.textures.has("ch4p_spiral_raise") and game.textures.has("ch4_spiral_spike"),"Actual spiral body animation and stone geometry are imported")
 var texture: Texture2D=game.textures.ch4p_spiral_raise;check(texture.get_width()==1536 and texture.get_height()==168,"Spiral atlas has all three directions and all frames")
 e.clear_hazards();e.phase="two";e.start(w,"fault_smash");advance(w,1.16);var impact:=await image_now()
 check(game.textures.has("ch4p_ground_smash"),"Connected hand-to-ground pose is present in the real Godot renderer")
 advance(w,1.2);var beams:=await image_now();check(impact.get_data()!=beams.get_data(),"Dark cracks, red ignition and vertical beams are distinct rendered stages")
 w.state="PAUSED";before=await image_now();var clock: float=w.clock;rng_before=w.rng.state;advance(w,.5);game.ui_time+=2;after=await image_now()
 check(before.get_data()==after.get_data() and w.clock==clock and w.rng.state==rng_before,"New boss effects, camera and pose preserve the exact paused frame")
 w.state="RUNNING";e.clear_hazards();e.start(w,"rain");advance(w,1.9);await image_now();check(game.textures.has("ch4p_cast_step"),"Stationary casts actually render their planted-step animation")
 game.action("menu");check(not game.has_meta("ch4_combat_animations") and not game.textures.has("ch4p_ground_smash") and not game.textures.has("ch4_spiral_spike"),"New chapter IV animation textures release on leaving the chapter")
 game.audio.shutdown();game.quitting=true
 FileAccess.open("res://qa/ch4_combat_polish/visual.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("COMBAT_POLISH_VISUAL_RESULT ",checks," checks; ",failures.size()," failures");quit(1 if not failures.is_empty() else 0)
