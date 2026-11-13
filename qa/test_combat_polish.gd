extends SceneTree
const W=preload("res://scripts/world.gd")
const NW=preload("res://scripts/nether_world.gd")
const OW=preload("res://scripts/overworld_world.gd")
const EW=preload("res://scripts/end_world.gd")
const FW=preload("res://scripts/chapter_four_world.gd")
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures.append(label);push_error(label)
func prepare(w):
 w.reset(439);w.state="RUNNING";w.player=Vector2(1024,1024);w.props.clear();w.solid_grid.clear();w.blocked.clear();w.mobs.clear();w.projectiles.clear();w.effects.clear()
 if "stage" in w:w.stage="survival"
 return w
func advance(w,seconds: float,move:=Vector2.ZERO):
 for i in range(ceili(seconds*60)):w.step(1.0/60,move)
func boss():
 var w=prepare(FW.new());w.db.data.chapter_four.exploration_only=true;w.note_presented=true;w.stage="finale";w.build={};w.items={};w.time=720;var e=w.ending
 e.begin_summit(w);e.start_intro(w);e.phase="one";e.hb.perched=false;e.tower_h=0;e.hb.p=e.center;w.player=e.center+Vector2(120,60);w.invulnerable=999
 return w
func run():
 var w=prepare(W.new());w.spawn("skeleton",w.player+Vector2(65,0));var m=w.mobs.back();m.timer=0;var p: Vector2=m.p;w.move_mobs(.1)
 check(w.projectiles.is_empty() and m.p.distance_to(w.player)>p.distance_to(w.player),"Skeleton retreats instead of shooting or planting to aim")
 m.p=w.player+Vector2(160,0);m.timer=0;w.move_mobs(.1);check(not w.projectiles.is_empty(),"Skeleton fires after establishing distance")
 var nw=prepare(NW.new())
 for kind in ["piglin_crossbow","blaze_nether"]:
  nw.mobs.clear();nw.projectiles.clear();nw.spawn(kind,nw.player+Vector2(60,0));m=nw.mobs.back();m.timer=0;m.aggro=5;nw.move_mobs(.1)
  check(nw.projectiles.is_empty(),kind+" cannot fire while retreating")
  m.p=nw.player+Vector2(155,0);m.timer=0;nw.move_mobs(.1);check(not nw.projectiles.is_empty(),kind+" resumes firing at range")
 var ow=prepare(OW.new());ow.spawn("witch",ow.player+Vector2(55,0));m=ow.mobs.back();m.timer=0;ow.move_witch(m,.1)
 check(not ow.effects.any(func(e):return e.kind=="witch_potion"),"Witch keeps its potion while backing away")
 var ew=prepare(EW.new());ew.land.fill(1);ew.spawn("dispenser_enderman",ew.player+Vector2(60,0));m=ew.mobs.back();m.timer=0;ew.move_mobs(.1)
 check(ew.projectiles.is_empty(),"Dispenser Enderman cannot fire while retreating")
 var fw=prepare(FW.new());fw.db.data.chapter_four.exploration_only=true
 for kind in ["growth_skeleton","infected_witch"]:
  fw.mobs.clear();fw.enemy_shots.clear();fw.enemy_bottles.clear();fw.spawn(kind,fw.player+Vector2(65,0));m=fw.mobs.back();m.timer=0;fw.Enemies.act(fw,m,.1)
  check(m.phase=="walk" and fw.enemy_shots.is_empty() and fw.enemy_bottles.is_empty(),kind+" retreats without beginning a cast")
  fw.Enemies.windup(fw,m,Vector2.LEFT);m.timer=0;fw.Enemies.act(fw,m,.1)
  check(m.phase=="recover",kind+" cancels an unfinished ranged windup when rushed")
 fw=prepare(FW.new());fw.begin_sword_drop();check(fw.build.get("sword",0)==1 and fw.sword_drop.is_empty(),"IV starts with EnderSteve's sword and no pickup sequence")
 var base: Dictionary=fw.db.stats("sword",8,false,{})
 var upgraded: Dictionary=fw.db.stats("sword",8,true,{})
 check(upgraded.damage>base.damage and upgraded.radius>base.radius and upgraded.interval<base.interval,"Bedrock sword improves damage, reach and rate instead of slowing down")
 fw.build={"sword":8};fw.evolved={"sword":true};fw.facing=Vector2.LEFT;fw.spawn("flayed_zombie",fw.player+Vector2(30,0));m=fw.mobs.back();m.hp=1000;fw.rebuild_hit_grid();fw.cooldowns.sword=0;fw.arsenal.update_attacks(fw,.02)
 check(fw.arsenal.actions.sword.dir.dot(Vector2.RIGHT)>.9,"Bedrock sword aims at the enemy independently of movement facing")
 var old: Vector2=fw.player;fw.arsenal.step(fw,.6);check(m.hp<1000 and fw.player==old,"Auto-aimed bedrock swing lands without taking control of movement")
 ew=prepare(EW.new());ew.land.fill(1);ew.build={"spear":1};ew.stage="survival";ew.facing=Vector2.RIGHT;ew.start_dash(.5)
 var cell:=Vector2i(ew.player/16)
 for x in range(cell.x,cell.x+9):ew.land[cell.y*128+x]=0
 ew.step(.05);check(ew.dash_left>0 and ew.fall_age<0 and ew.falls==0,"Active spear dash crosses unsupported tiles without starting a fall")
 ew.dash_left=0;ew.rocket=false;ew.step(.01);check(ew.fall_age>=0,"Unsupported ground becomes dangerous again after the dash")
 ew=prepare(EW.new());ew.build={"sword":8,"spear":5};ew.items={"feather":3,"armor":4,"hopper":2};ew.evolved={"sword":true};ew.npc={"from":ew.player-Vector2(20,0),"p":ew.player-Vector2(20,0)};ew.stage="clash";ew.stage_age=ew.end_boss.CLASH_BREAK
 ew.end_boss.story(ew,.01)
 check(ew.build.is_empty() and ew.items.is_empty() and ew.evolved.is_empty() and ew.broken_gear.size()==5,"Final clash destroys every weapon and passive, retaining only fragment descriptors")
 ew.stage="sit";ew.stage_age=float(ew.end_boss.SIT_MARKS.gift)+2.005;ew.end_boss.story(ew,.01)
 check(ew.build=={"sword":1} and ew.items.is_empty(),"EnderSteve's later gift restores only the starter sword")
 var solo=prepare(OW.new());solo.items={"hopper":5};solo.orbs=[{"p":solo.player+Vector2(110,0),"value":2,"attracted":false}];solo.pickup(.1)
 check(solo.orbs[0].attracted and solo.orbs[0].p.x<solo.player.x+90,"Hopper V reaches and quickly pulls experience from 110 pixels away")
 solo.loot=[{"p":solo.player+Vector2(60,0),"kind":"apple"},{"p":solo.player+Vector2(60,20),"kind":"chest","born":10}];var chest: Vector2=solo.loot[1].p;solo.pickup(.1)
 check(solo.loot[0].p.x<solo.player.x+60 and solo.loot[1].p==chest,"Hopper attracts healing while keeping chests manual")
 var legacy=prepare(W.new());legacy.items={"hopper":5};check(is_equal_approx(legacy.pickup_radius(),60),"Legacy cooperative pickup radius remains unchanged")
 fw=prepare(FW.new());fw.items={"feather":5};check(is_equal_approx(fw.knock_factor({}),1.6),"Feather V supplies the documented +60% knockback")
 check(not fw.db.recipes.fishing.effect.contains("оглуш"),"Evolved fishing rod no longer advertises stun")
 fw=boss();var e=fw.ending;e.start(fw,"spiral")
 check(e.terrain_attack.spikes.size()>24 and e.pose=="spiral_raise","Spiral uses a substantial, authored chain of raised floor spikes")
 var point: Vector2=e.terrain_attack.spikes[8].p;fw.player=point;fw.invulnerable=0;fw.hp=20;e.move_age=e.terrain_attack.spikes[8].born-.03;e.terrain_attack.step(e,fw,0)
 check(fw.hp==20,"Spiral warning itself does no damage")
 e.move_age=e.terrain_attack.spikes[8].born+.13;e.terrain_attack.step(e,fw,0);check(fw.hp<20,"An emerged spike damages at its visible floor position")
 fw=boss();e=fw.ending;e.phase="two";e.start(fw,"fault_smash");e.move_age=e.move_time;e.step_smash_dash(fw)
 check(e.terrain_attack.faults.size()==6 and e.pose=="ground_smash","Ground punch creates exactly six irregular stored fault paths")
 var fault: Dictionary=e.terrain_attack.faults[0];fw.player=fault.points[3];fw.hp=20;fw.invulnerable=0;e.move_age=2.0;e.terrain_attack.step(e,fw,0)
 check(fw.hp==20 and not e.terrain_attack.emitted,"Faults stay safe during their full one-second ignition warning")
 e.move_age=2.2;e.terrain_attack.step(e,fw,0);check(e.terrain_attack.emitted and fw.hp<20,"Red eruption hits the very path that was telegraphed")
 fw=boss();e=fw.ending;e.phase="two"
 for kind in ["hole","rain","rift","tear","day"]:
  e.clear_hazards();e.start(fw,kind);e.move_age=1.8;var before: Vector2=e.hb.p;e.terrain_attack.step_motion(e,fw,.1)
  check(e.hb.p.distance_to(before)>0 and not e.terrain_attack.echoes.is_empty(),kind+" includes a finite cast step and a sampled residual trail")
 e.clear_hazards();check(e.terrain_attack.faults.is_empty() and e.terrain_attack.spikes.is_empty() and e.terrain_attack.echoes.is_empty(),"All added hazards/trails clear at phase transitions")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/ch4_combat_polish"))
 FileAccess.open("res://qa/ch4_combat_polish/mechanics.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("COMBAT_POLISH_RESULT ",checks," checks; ",failures.size()," failures");quit(1 if not failures.is_empty() else 0)
