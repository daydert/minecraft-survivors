extends SceneTree
## Diagnostic setups, real simulation/render/audio. Invulnerability is used
## for the camera pilot; this is a presentation review, not a survival run.
var game
var frames:=0
var sounds: Array=[]
var music: Array=[]
var segments: Array=[]
var folder:="res://qa/recordings/chapter_four_combat_polish_frames"
func _initialize():run.call_deferred()
func mark(name: String):segments.append({"name":name,"time":frames/30.0});print("COMBAT_FILM_SEGMENT ",name," ",frames/30.0)
func tick(w,move:=Vector2.ZERO):
 for j in range(2):
  if w.state=="LEVEL_UP":w.skip_reward()
  elif w.state=="CHEST":w.chest_delay=0;w.close_chest()
  w.step(1.0/60,move)
  for id in w.sounds:sounds.append({"id":id,"time":frames/30.0+j/60.0})
  w.sounds.clear()
 var track: String=w.ending.music if game.is_four() and w.stage=="finale" else "ch4" if game.is_four() else ""
 if music.is_empty() or music[-1].track!=track:music.append({"track":track,"time":frames/30.0})
 game.ui_time+=1.0/30;game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(folder+"/%05d.png"%frames);frames+=1
 if frames%600==0:print("COMBAT_FILM_CAPTURE ",frames)
func idle(w,time: float,move:=Vector2.ZERO):
 for i in range(roundi(time*30)):await tick(w,move)
func quiet(w):
 w.state="RUNNING";w.invulnerable=999;w.build={};w.items={};w.mobs.clear();w.props.clear();w.solid_grid.clear();w.blocked.clear()
 w.db.data.events=[];w.db.data.waves=[{"at":0,"rate":0,"weights":{"zombie":1}}]
func boss(phase: String):
 game.action("chapter_4");var w=game.world;quiet(w);w.stage="finale";w.note_presented=true;w.time=720
 var e=w.ending;e.begin_summit(w);e.start_intro(w);e.phase=phase;e.hb.perched=false;e.tower_h=0;e.hb.p=e.center;w.player=e.center+Vector2(110,65);e.camera_at=e.center;e.music="boss_two" if phase=="two" else "boss_one"
 return w
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film";game.settings.shake=true;root.size=Vector2i(640,360)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 game.action("chapter_1");var w=game.world;w.skip_intro();quiet(w);w.player=Vector2(1024,1024);w.clock=80;w.time=80;game.settings.lighting=false
 mark("cloud_shadows_lighting_disabled");await idle(w,4,Vector2.RIGHT)
 game.settings.lighting=true;w.spawn("skeleton",w.player+Vector2(70,0));w.mobs.back().timer=0
 mark("skeleton_retreat_no_fire");await idle(w,3)
 mark("skeleton_fires_after_retreat");await idle(w,2.5,Vector2.LEFT)
 w.mobs.clear();w.projectiles.clear();w.spawn("witch",w.player+Vector2(170,0));w.mobs.back().timer=.2
 mark("witch_potion_and_floor_puddle");await idle(w,4)
 w.mobs.clear();w.effects.clear();w.items={"hopper":5};w.level=20;w.hp=12
 for i in range(18):w.orbs.append({"p":w.player+Vector2.from_angle(i*2.39996)*(80+i%3*12),"value":1,"attracted":false})
 w.loot=[{"kind":"apple","p":w.player+Vector2(-65,0)}];mark("hopper_v");await idle(w,2)
 game.action("chapter_3");w=game.world;quiet(w);w.stage="survival";w.build={"spear":1}
 var bridge: Array=[]
 for y in range(24,105):
  if not bridge.is_empty():break
  for x in range(20,108):
   var p:=Vector2(x*16+8,y*16+8)
   if not w.supported_at(p,6) or w.on_land(p+Vector2(16,0)):continue
   for span in range(3,8):
    var end: Vector2=p+Vector2(span*16,0)
    if w.supported_at(end,8) and w.supported_at(end+Vector2(16,0),8):bridge=[p,end];break
   if not bridge.is_empty():break
 assert(not bridge.is_empty(),"A real gap with two supported ends is required")
 w.player=bridge[0];w.last_safe=w.player;w.facing=Vector2.RIGHT
 mark("spear_crosses_real_gap");await idle(w,.6)
 w.start_dash(w.player.distance_to(bridge[1])/(w.movement_speed()*w.db.stats("spear",1,false,{}).speed));await idle(w,1.4)
 w.prepare_arena();w.mobs.clear();w.crystals.clear();w.stage="clash";w.player=Vector2(1045,1100);w.npc={"from":Vector2(1024,1100),"p":Vector2(1024,1100),"dir":Vector2.RIGHT,"side":Vector2.RIGHT}
 w.build={"sword":8,"spear":8,"bow":5};w.items={"armor":4,"feather":3,"hopper":3};w.evolved={"sword":true}
 mark("endersteve_breaks_all_gear");await idle(w,6.6)
 game.action("chapter_4");w=game.world;w.begin_sword_drop();mark("chapter_iv_starts_with_sword");await idle(w,4.5)
 w.stage="survival";w.time=100;w.invulnerable=999;w.note_presented=true;w.db.data.chapter_four.exploration_only=true;w.build={"sword":8};w.evolved={"sword":true};w.mobs.clear();w.props.clear();w.solid_grid.clear();w.blocked.clear()
 for i in range(7):
  w.spawn("flayed_zombie",w.player+Vector2.from_angle(i*TAU/7)*60);w.mobs.back().hp=240;w.mobs.back().max_hp=240
 mark("bedrock_sword_auto_aim_movement");await idle(w,5,Vector2.RIGHT)
 w.mobs.clear();w.build={"sword":1};w.evolved={};w.time=690;w.clock=690
 var fissures: Array=game.four_renderer.FxView.visible_fissures(game,Vector2(320,180)-w.camera())
 if not fissures.is_empty():w.player=(fissures[0][0]+fissures[0][1])*.5
 mark("walk_on_floor_cracks");await idle(w,4,Vector2.RIGHT)
 w=boss("one");w.ending.start(w,"spiral");mark("spiral_spikes_full");await idle(w,4.6)
 w=boss("two");w.ending.start(w,"fault_smash");mark("ground_punch_six_faults_full");await idle(w,3.95)
 w.ending.clear_hazards();w.ending.start(w,"fault_smash");mark("ground_punch_new_pattern");await idle(w,3.95)
 for kind in ["hole","rain","rift","tear","day"]:
  w=boss("two");w.ending.start(w,kind);mark("moving_cast_"+kind);await idle(w,5.7 if kind=="rain" else 4.8)
 FileAccess.open("res://qa/recordings/chapter_four_combat_polish_timeline.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":30,"frames":frames,"sound_events":sounds,"music":music,"segments":segments,"diagnostic":"staged mechanics/attack setups; invulnerable pilot; real simulation and renderer"},"  "))
 game.action("menu");game.audio.shutdown();game.quitting=true;print("COMBAT_FILM_COMPLETE ",frames);quit()
