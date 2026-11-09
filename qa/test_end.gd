extends SceneTree
const EW=preload("res://scripts/end_world.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool, label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func fresh():
	var w=EW.new();w.reset(724);w.state="RUNNING";w.stage="survival";w.db.data.waves=[{"at":0,"rate":0,"weights":{"endermite":1}}];w.db.data.events=[];return w
func advance(w, seconds: float, dir: Vector2=Vector2.ZERO):
	for i in range(ceili(seconds*60)):w.step(1.0/60,dir)
func run():
	var w=fresh()
	check(w.chapter_number()==3 and w.db.weapons.size()==18 and w.db.passives.size()==13,"Chapter III retains all previous equipment and adds six weapons/five enhancements, without Nether-only passives")
	check(w.props.filter(func(p):return p.type=="pumpkin" and p.has_heal).size()==w.props.filter(func(p):return p.type=="pumpkin").size()/2,"Half the chorus plants contain fruit")
	check(w.land.count(0)>3500 and w.land.count(1)>9000,"Finite End island has substantial traversable terrain and void")
	for id in w.END_WEAPONS:
		check(w.db.stats(id,8,false).damage>=w.db.stats(id,1,false).damage and not w.db.description(id,0).is_empty(),"Real upgrades and concise description for "+id)
	w.build={"spear":8};w.items={"sugar":5};w.spawn("endermite",w.player+Vector2(25,0));w.facing=Vector2.RIGHT;w.rebuild_hit_grid();w.update_attacks(.02)
	check(w.dash_left>0 and w.invulnerable>0,"Spear starts an invulnerable forward dash")
	var p=w.player;advance(w,.1)
	check(w.player.x>p.x+15 and w.kills>0,"Spear moves and applies real contact damage")
	check(w.db.stats("spear",8,false,{"sugar":5}).damage>w.db.stats("spear",8).damage,"Spear scales damage from movement speed")
	w=fresh();w.build={"mace":8};w.spawn("endermite_brood",w.player+Vector2(20,0));w.rebuild_hit_grid();w.update_attacks(.02);var hp=w.mobs[0].hp
	advance(w,.45);check(w.jump_height>60 and w.mobs[0].hp==hp,"Mace rises with wind charge before impact")
	advance(w,.6);check(w.mobs.is_empty() or w.mobs[0].hp<hp,"Mace landing deals area damage scaled by actual jump height")
	w=fresh();w.items={"elytra":5,"ender_pearl":5};w.build={}
	check(w.active_item("elytra") and not w.active_item("elytra"),"Elytra activation consumes its cooldown")
	w.evolved={"spear":true};w.build={"spear":8};check(w.active_item("rocket") and w.rocket and w.invulnerable>0,"Shift evolution enables invulnerable rocket flight")
	w=fresh();w.build={};w.items={"ender_pearl":3};w.facing=Vector2.RIGHT;p=w.player
	check(w.active_item("ender_pearl"),"E throws a pearl")
	advance(w,.7);check(w.player.distance_to(p)>100 and w.on_land(w.player),"Pearl lands on safe terrain and teleports after its visible flight")
	w=fresh();w.build={};w.hp=6;var source=w.player;w.spawn("endermite",source+Vector2(10,0));w.loot.append({"kind":"chorus_fruit","p":source,"source":source});w.pickup(.01)
	check(w.hp==10 and w.player.distance_to(source)<=160 and w.player.distance_to(w.mobs[0].p)>30 and w.on_land(w.player),"Chorus heals and teleports within ten blocks away from enemies")
	w=fresh();w.build={"shield":8};w.shield_charges=2;w.facing=Vector2.RIGHT
	check(not w.contact_hit(w.player+Vector2(20,0),4) and w.hp==20 and w.shield_charges==1,"Shield blocks a frontal hit and consumes capacity")
	w.invulnerable=0;check(w.contact_hit(w.player-Vector2(20,0),4) and w.hp==16,"Shield leaves the rear exposed")
	w.invulnerable=0;w.shield_guard=0;w.contact_hit(w.player+Vector2(20,0),4);check(w.shield_charges==0 and w.shield_timer>0,"Empty shield enters recharge")
	advance(w,8);check(w.shield_charges==7,"Shield reload restores upgraded capacity")
	w.evolved.shield=true;w.shield_charges=3;w.shield_guard=0;w.invulnerable=0;w.block_hit(w.player+Vector2(20,0),{"dir":Vector2.LEFT,"damage":3})
	check(w.projectiles.any(func(b):return b.kind=="bolt" and b.damage>=24),"Evolved shield reflects hostile shots as damaging bolts")
	w=fresh();w.build={"knockback_stick":8};w.facing=Vector2.RIGHT;w.spawn("endermite_brood",w.player+Vector2(20,0));w.spawn("endermite_brood",w.player+Vector2(58,0));w.rebuild_hit_grid();w.update_attacks(.01)
	advance(w,.15);check(w.mobs[1].hp<w.mobs[1].max_hp,"Launched enemies damage neighbours by collision")
	w=fresh();w.build={};w.spawn("enderman",w.player+Vector2(35,0));w.rebuild_hit_grid();var m=w.mobs[0];p=m.p
	w.fire_projectile("arrow",w.player,Vector2.RIGHT,{"speed":200,"damage":100,"range":250,"radius":3},false)
	for i in range(12):w.update_projectiles(1.0/60)
	check(m.hp==m.max_hp and m.p!=p,"Enderman teleports before an arrow can hit")
	w=fresh();w.build={};w.spawn("shulker",w.player+Vector2(-100,-70));m=w.mobs[0];m.timer=0;w.move_mobs(.01)
	check(w.projectiles.size()==1 and w.projectiles[0].kind=="shulker_bullet","Shulker fires a guided projectile")
	var axes={};var b=w.projectiles[0]
	for i in range(90):
		w.update_projectiles(1.0/60)
		if w.projectiles.is_empty():break
		axes[str(b.axis)]=true
	check(axes.size()>=2 and b.trail.size()>4,"Shulker bullet follows alternating cardinal axes with a visible trail")
	w=fresh();w.build={};check(w.spawn("endersteve",w.player+Vector2(80,0)) and not w.spawn("endersteve",w.player+Vector2(90,0)),"Only one reborn EnderSteve exists at a time")
	w.mobs[0].hp=0;w.resolve_deaths();check(w.spawn("endersteve",w.player+Vector2(80,0)),"EnderSteve can return after death")
	w=fresh();w.build={};w.items={"end_eye":1};w.next_level();check(w.choices.size()==4,"Eye I gives four choices")
	w.items.end_eye=2;w.state="RUNNING";w.next_level();check(w.rerolls==1 and w.reroll_choices() and w.rerolls==0 and not w.reroll_choices(),"Eye II gives exactly one reroll per reward")
	w.items.end_eye=5;w.state="RUNNING";w.next_level();var choices=w.choices.duplicate();w.tick_choices(.22)
	check(w.choices.size()==5 and w.choices.slice(0,2)==choices.slice(0,2) and w.choices!=choices,"Eye V cycles three out of five choices, leaving two stable")
	var rng_state=w.rng.state;w.tick_choices(.22);check(w.rng.state==rng_state,"Cycling presentation does not consume combat RNG")
	w.state="PAUSED";var age=w.choice_age;w.tick_choices(5);check(w.choice_age==age,"Inventory/pause freezes reward cycling")
	w=fresh();w.build={};w.prepare_arena();check(w.crystals.size()==6 and w.mobs.size()==7,"Dragon arena creates six real crystals and one boss")
	var dragon=w.mobs.back();w.stage="dragon";m=w.mobs[0];hp=m.hp;w.hurt(m,50)
	check(m.hp<hp,"Ground-level crystals take ordinary damage on obsidian")
	w.player=Vector2(1024,1150);w.damage_source="projectile";w.hurt(dragon,99999);w.damage_source="melee";check(dragon.hp==dragon.max_hp*.5,"First phase cannot bypass its crystal objective")
	hp=dragon.hp;w.hurt(dragon,50);check(dragon.hp==hp,"Ground melee cannot hit the dragon while it is airborne")
	dragon.hp=4000;w.end_boss.dragon(w,dragon,.1);check(dragon.hp>4000,"Live crystals restore the dragon's HP")
	for t in w.crystals:t.alive=false
	dragon.hp=dragon.max_hp*.5;w.end_boss.dragon(w,dragon,.01);check(dragon.phase_two and dragon.phase=="rage","All destroyed crystals plus half HP start phase two")
	dragon.hp=0;w.resolve_deaths();check(w.stage=="dragon_death" and not w.victory,"Dragon death leads to the portal sequence, not the final result")
	advance(w,4.6);check(w.stage=="exit_portal" and w.portal_lit,"Dragon death lights the bedrock portal")
	w.player=w.portal_position+Vector2(0,60);advance(w,.02);check(w.stage=="betrayal","Approaching the egg triggers EnderSteve's arrival")
	advance(w,3.3);check(not w.portal_lit,"EnderSteve destroys the portal and egg")
	advance(w,5.5);check(w.stage=="last_duel" and w.mobs.any(func(v):return v.kind=="endersteve_final"),"The third encounter starts a damageable final duel")
	w.mobs[0].hp=0;w.resolve_deaths();advance(w,7.7);check(w.stage=="hand" and w.loot.size()==1 and w.loot[0].kind=="end_hand","Final defeat leaves only EnderSteve's hand")
	p=w.player;advance(w,8);check(w.stage=="hand" and w.player==p,"Victory waits for the player to approach the hand")
	w.player=w.loot[0].p;advance(w,.02);check(w.stage=="hand_pickup" and w.hand_taken,"Approaching the hand starts its pickup animation")
	p=w.player;advance(w,4);check(w.stage=="return_portal" and w.player==p and not w.portal_lit,"Picking up the hand never moves the hero to the portal")
	w.player=w.portal_position+Vector2(0,48);advance(w,.02,Vector2.UP);check(w.stage=="rekindle","Walking up with the hand starts portal ignition")
	p=w.player;advance(w,3);check(w.stage=="portal_ready" and w.portal_lit and w.player==p,"Ignition restores the portal without moving or jumping the hero")
	advance(w,4);check(w.stage=="portal_ready" and w.player==p,"The lit portal waits for manual entry")
	advance(w,.6,Vector2.UP);check(w.stage=="exit_jump","Walking into the portal starts the authored jump")
	advance(w,3.5);check(w.stage=="chapter_four" and w.end_complete and w.victory,"The voluntary jump reaches the corrupted Overworld teaser")
	w=fresh();w.items={"elytra":5};w.active_item("elytra");w.state="PAUSED";var clock=w.clock;var flight=w.flight;w.step(4)
	check(w.clock==clock and w.flight==flight,"Pause freezes active flight and simulation clocks")
	w.reset(724);check(w.flight==0 and w.crystals.is_empty() and not w.hand_taken and not w.end_complete,"Retry clears all Chapter III transient state")
	w=fresh();w.build={};var hole=Vector2.ZERO
	for i in range(w.land.size()):
		var point=Vector2(i%128*16+8,i/128*16+8)
		if w.land[i]==0 and point.distance_to(w.player)<600:hole=point;break
	w.player=hole;var safe=w.last_safe;w.step(.01);check(w.fall_age>=0,"Walking into a real island hole starts a fall")
	advance(w,.9);check(w.player==safe and w.hp==14,"A void fall returns to the last landing and costs health")
	w=fresh();w.build={};w.items={"elytra":2};w.player=hole;w.active_item("elytra");w.step(.1)
	check(w.fall_age<0 and w.player==hole,"Active elytra can remain over an actual hole")
	w.flight=0;w.step(.01);check(w.fall_age>=0,"Ending flight over the void starts falling")
	w=fresh();w.build={};w.items={"shulker_shell":5};w.player=hole;advance(w,1)
	check(w.hp==20 and w.shell_cooldown>0,"Shulker shell rescues one void fall and enters cooldown")
	w.player=hole;advance(w,1);check(w.hp<20,"A shell on cooldown does not grant unlimited void immunity")
	w=fresh();w.build={"end_crystal":8};w.spawn("endermite_brood",w.player+Vector2(34,0));w.rebuild_hit_grid();w.update_attacks(.01);hp=w.mobs[0].hp
	w.update_effects(.5);check(w.mobs[0].hp==hp,"Placed crystal visibly waits before detonation")
	w.update_effects(.2);check(w.mobs[0].hp<hp,"Crystal detonation deals real damage around its obsidian base")
	w=fresh();w.build={"dragon_breath":8};w.spawn("endermite_brood",w.player+Vector2(80,0));w.rebuild_hit_grid();w.update_attacks(.01);hp=w.mobs[0].hp;w.update_effects(.4)
	check(w.mobs[0].hp<hp,"Dragon-breath clouds deal actual periodic damage")
	w=fresh();w.build={};w.items={"rabbit_foot":5}
	for i in range(100):w.spawn("endermite",w.player+Vector2(i%10*12,60+i/10*12));w.mobs.back().hp=0
	w.resolve_deaths();check(w.loot.any(func(o):return o.kind=="golden_carrot") and not w.loot.any(func(o):return o.kind=="apple"),"Maximum rabbit foot upgrades real mob healing drops to golden carrots")
	w=fresh();check(not w.db.passives.has("gold_boots") and not w.db.passives.has("fire_resist"),"Gold boots and magma cream never enter the End reward pool")
	check(w.db.recipes.fishing.passive=="ender_pearl" and w.db.recipes.bed.passive=="shulker_shell" and w.db.recipes.dragon_breath.passive=="ghast_tear","End recipes use obtainable ingredients after the pool revision")
	w=fresh();w.build={"sword":8,"spear":8,"mace":8,"end_crystal":8,"shield":8,"knockback_stick":8};w.items={"elytra":5,"ender_pearl":5,"rabbit_foot":5,"end_eye":5,"shulker_shell":5,"sugar":5,"armor":5,"feather":5}
	w.next_level();check(w.choices.size()==5,"Fully capped equipment still receives five useful Eye rewards")
	for i in range(8):w.tick_choices(.22)
	check(w.choices.all(func(id):return id in ["apple","golden_carrot","experience"]),"A capped build never offers an impossible extra equipment slot")
	w=fresh();w.build={"spear":8,"mace":8,"end_crystal":8};w.items={"elytra":5,"ender_pearl":5};w.evolved={"spear":true};w.active_item("rocket");w.active_item("ender_pearl");w.state="PAUSED"
	w.discard("spear");w.discard("ender_pearl");check(w.dash_left==0 and not w.rocket and not w.effects.any(func(e):return e.kind=="end_pearl"),"Removing active equipment clears its delayed movement and pearl")
	w=fresh();w.build={};w.state="RUNNING";w.fire_projectile("slow_arrow",w.player+Vector2(12,0),Vector2.LEFT,{"speed":100,"damage":2,"range":100,"radius":3},false);w.update_projectiles(.05)
	check(w.slow_time>0 and w.movement_speed()<w.db.data.player_speed,"Slowing arrows affect actual movement speed")
	w.invulnerable=0;w.fire_projectile("poison_arrow",w.player+Vector2(12,0),Vector2.LEFT,{"speed":100,"damage":2,"range":100,"radius":3},false);w.update_projectiles(.05)
	check(w.poison_time>0,"Poison arrows apply a lasting status on a real hit")
	w=fresh();w.build={};w.fire_projectile("shulker_bullet",w.player+Vector2(6,0),Vector2.LEFT,{"speed":72,"damage":2,"range":100,"radius":3},false);w.update_projectiles(.01)
	check(w.levitation==10,"A successful shulker hit applies ten seconds of levitation")
	w=fresh();w.build={};w.prepare_arena();w.stage="dragon";var boss=w.mobs.back();w.player=boss.p+Vector2(90,0);var before=boss.p;w.hook_target(boss,true);w.move_mobs(.1)
	check(boss.p.distance_to(w.player)<before.distance_to(w.player) and boss.control_resist>0,"Fishing physically pulls the dragon and applies repeat-control protection")
	w.mobs.clear();w.spawn("endersteve_final",w.player+Vector2(80,0));boss=w.mobs[0];boss.phase="cast";before=boss.p;w.hook_target(boss,true);w.move_mobs(.1)
	check(boss.p!=before and boss.phase=="recover","Fishing pulls EnderSteve and interrupts a prepared attack")
	w=fresh();w.build={};w.hp=8;w.last_safe=Vector2(1600,1600);w.spawn("endermite_brood",w.player);w.mobs[0].radius=300;w.loot.append({"kind":"chorus_fruit","p":w.player,"source":w.player})
	w.pickup(.01);check(w.hp==8 and w.loot.filter(func(o):return o.kind=="chorus_fruit").size()==1,"Chorus waits rather than teleporting into an enemy or outside ten blocks when no landing is safe")
	w=fresh();w.build={};var inner=w.last_safe;var edge=Vector2.ZERO
	for i in range(w.land.size()):
		var point=Vector2(i%128*16+8,i/128*16+8)
		if w.on_land(point) and not w.supported_at(point):edge=point;break
	w.player=edge;w.step(.01);check(w.last_safe==inner,"A narrow edge never replaces the stable void-return checkpoint")
	w.player=hole;advance(w,1);check(w.supported_at(w.player) and w.last_safe==inner,"Void recovery returns to a supported landing rather than trapping the hero at the edge")
	w=fresh();w.build={};w.spawn("endersteve_final",w.player+Vector2(60,0));boss=w.mobs[0];boss.phase="rush";boss.timer=.7;w.clock=100;w.update_end_poses(.01)
	check(boss.visual.state=="slash" and boss.visual.time==0,"A sword rush starts at its own first animation frame")
	w.clock+=123;w.update_end_poses(.05);check(boss.visual.time>0 and boss.visual.time<.05,"The sword animation follows attack age rather than the global clock")
	w.state="PAUSED";var pose_age=boss.pose_age;w.step(2);check(boss.pose_age==pose_age,"Pausing freezes the exact local sword pose")
	FileAccess.open("res://qa/end_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("END_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
