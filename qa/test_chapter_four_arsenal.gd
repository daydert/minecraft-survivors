extends SceneTree
## IV-only combat contracts. Targets use real enemy dictionaries and hit grids.
const FW=preload("res://scripts/chapter_four_world.gd")
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func fresh():
	var w=FW.new();w.reset(874);w.stage="survival";w.state="RUNNING";w.db.data.chapter_four.exploration_only=true
	w.build={};w.items={};w.props=[];w.landmarks=[];w.threats=[];w.solid_grid={};w.blocked={};w.pools={};w.chickens=[];w.player=Vector2(1024,1024);w.facing=Vector2.RIGHT;w.arsenal.reset(w)
	return w
func mob(w,delta:=Vector2(35,0)) -> Dictionary:
	w.spawn("flayed_zombie",w.player+delta)
	var m: Dictionary=w.mobs.back();m.hp=10000;m.max_hp=10000;m.speed=0;m.timer=100
	w.rebuild_hit_grid();return m
func advance(w,seconds: float,move:=Vector2.ZERO):
	for j in range(ceili(seconds*60)):w.step(1.0/60,move)
func release(w,id: String):
	var s: Dictionary=w.db.stats(id,w.build.get(id,8),w.evolved.has(id),w.items)
	w.arsenal.release(w,id,{"stats":s,"dir":Vector2.RIGHT})
func run():
	var w=fresh()
	check(not w.eligible().has("sky_tnt") and not w.eligible().has("crossbow"),"Fusion is never a random pickup; shotgun replaces ordinary crossbow in IV")
	for id in w.db.recipes:
		for component in w.Equipment.components(w.db,id):
			check((w.db.weapons if component.kind=="weapon" else w.db.passives).has(component.id),"Recipe ingredient is obtainable: "+id+" / "+component.id)
	w.build={"fishing":8,"tnt":8};w.evolved={"fishing":true}
	check(not w.evolution_candidates(600).has("sky_tnt"),"Fusion requires both evolved weapons")
	w.evolved.tnt=true
	check(w.evolution_candidates(359).is_empty() and w.evolution_candidates(360).has("sky_tnt"),"Chest age gates all IV evolutions")
	w.open_chest({"born":600})
	check(w.build=={"sky_tnt":8} and w.evolved.has("sky_tnt") and not w.evolved.has("fishing"),"Fusion consumes both weapons and occupies one slot")
	check(not w.eligible().has("tnt") and not w.eligible().has("fishing"),"Fused components cannot create duplicate late attacks")
	w=fresh();w.items={"armor":5,"thorns":3};w.open_chest({"born":600})
	check(w.evolved.has("armor") and w.build.is_empty() and w.items.armor==5,"Passive evolution retains its passive slot and never creates a weapon")
	w=fresh();w.items={"bat_wings":5,"empty_totem":1};w.open_chest({"born":600})
	check(w.evolved.has("bat_wings") and w.build.is_empty(),"Active-form evolution also uses the actual recipe book conditions")
	for id in ["shotgun","blood_pool","embryo","bell","bone_saw","potion","sky_tnt"]:
		w=fresh();w.build={id:8}
		if id=="sky_tnt":w.evolved[id]=true
		w.arsenal.kills=48
		var m=mob(w,Vector2(24,0) if id!="potion" else Vector2(20,0))
		advance(w,3.8)
		check(m.hp<m.max_hp and w.damage_by.get(id,0)>0,"Ordinary combat deals and attributes damage: "+id)
		check(w.hp>0 and w.state=="RUNNING","Weapon update remains playable: "+id)
	w=fresh();var popup_target=mob(w);w.damage_owner="shotgun";w.hurt(popup_target,5);w.hurt(popup_target,7)
	var numbers: Array=w.effects.filter(func(e):return e.kind=="damage")
	check(popup_target.hp==9988 and w.damage_by.shotgun==12 and numbers.size()==1 and numbers[0].amount==12,"Rapid impacts combine only their text while preserving every point of damage")
	w=fresh();w.build={"sword":8};w.evolved={"sword":true}
	var m=mob(w);m.guard=.8;m.phase="windup";m.timer=10
	release(w,"sword")
	check(absf((10000-m.hp)-w.db.stats("sword",8,true,{}).damage)<.001 and m.stun>0,"Bedrock sword pierces guard and interrupts a prepared enemy attack")
	w=fresh();w.build={"shotgun":8};m=mob(w,Vector2.from_angle(-.4)*40);release(w,"shotgun")
	for i in range(100):w.arsenal.step(w,.005)
	var close_damage: float=10000-m.hp
	w=fresh();w.build={"shotgun":8};m=mob(w,Vector2.from_angle(-.4)*200);release(w,"shotgun")
	for i in range(140):w.arsenal.step(w,.005)
	check(close_damage>10000-m.hp and m.hp<10000,"Pellet collision has real close-range damage falloff")
	w=fresh();w.build={"sky_tnt":8};release(w,"sky_tnt")
	check(w.arsenal.drops.size()==67 and w.arsenal.drops.filter(func(b):return not b.get("big",false)).map(func(b):return b.ring).max()==5 and w.arsenal.drops.filter(func(b):return b.get("big",false)).size()==1,"Sky cast: six bounded rings, then one huge charge on the crowd")
	var waits: Array=w.arsenal.drops.map(func(b):return b.wait)
	check(waits.min()<waits.max(),"Outer TNT rings start sequentially")
	w.state="PAUSED";var snap=JSON.stringify(w.arsenal.drops);advance(w,1)
	check(snap==JSON.stringify(w.arsenal.drops),"Pause freezes falling charges exactly")
	w.state="PAUSED";w.discard("sky_tnt")
	check(w.arsenal.drops.is_empty(),"Discard cancels outstanding sky charges")
	w=fresh();w.build={"blood_pool":8};release(w,"blood_pool")
	for i in range(30):w.arsenal.after_kill(w,{"p":w.player})
	check(w.arsenal.pools[0].power==10,"Blood pool growth has a hard cap")
	w.player+=Vector2(200,0);w.arsenal.step(w,16)
	check(w.arsenal.pools.is_empty(),"Leaving the accumulated pool eventually loses its power")
	w=fresh();w.build={"embryo":8};var xp: int=w.xp
	for i in range(48):w.arsenal.after_kill(w,{"p":w.player})
	w.arsenal.update_pet(w,.01)
	check(w.arsenal.pet.stage==4 and w.xp==xp,"Nearby kills grow the pet through four stages without stealing XP")
	w.arsenal.kills=0
	for i in range(60):w.arsenal.after_kill(w,{"p":w.player+Vector2(500,0)})
	check(w.arsenal.kills==0,"Distant kills do not grow the pet")
	m=mob(w);m.boss=true;w.arsenal.kills=48;w.arsenal.pet_bite=0;w.arsenal.update_pet(w,.6)
	check(m.stun==0 and w.arsenal.events.filter(func(e):return e.kind=="pet_follow").size()==2,"Final pet uses multiple strikes against a boss without a grab")
	w=fresh();w.build={"red_torch":8};w.evolved={"red_torch":true}
	for i in range(3):w.arsenal.torches.append({"p":w.player+Vector2.from_angle(i*TAU/3)*30,"id":i,"life":13.0})
	m=mob(w,Vector2(15,0));w.arsenal.update_torches(w,.01)
	check(w.arsenal.links.size()==3 and w.arsenal.links.filter(func(l):return l.live).size()==1,"Evolved torches close a circuit and energize one segment at a time")
	w.state="PAUSED";w.discard("red_torch")
	check(w.arsenal.links.is_empty() and w.arsenal.torches.is_empty(),"Discard removes both friendly torch objects and their damage links")
	w=fresh();w.items={"heart_booster":5,"armor":5,"thorns":5};w.evolved={"armor":true};w.arsenal.tick(w,.01,Vector2.ZERO)
	check(w.active_item("heart") and w.hp==18 and w.arsenal.heart_charges==1,"Heart cost bypasses armour and never triggers retaliation")
	w.arsenal.tick(w,.01,Vector2.ZERO)
	check(w.db.data.four_buffs.speed==10 and w.arsenal.heart_price==4,"Maximum heart level accelerates attacks tenfold and raises the next price")
	w.hp=4;w.arsenal.heart_buff=0
	check(not w.active_item("heart") and w.hp==4,"Heart refuses activation without enough HP to survive its cost")
	w.state="PAUSED";w.discard("heart_booster");w.apply_upgrade("heart_booster")
	check(w.arsenal.heart_price==4 and w.arsenal.heart_charges==1,"Removing and reacquiring heart cannot reset its price or restore charges")
	w.state="RUNNING";w.hp=10;w.items.bat_wings=5;w.arsenal.vamp_budget=10;w.arsenal.vampire(w,5);w.arsenal.heal_potion(w,5)
	check(w.hp==10,"Heart's healing lock prevents immediate lifesteal or potion refunds")
	w.arsenal.heart_buff=0;w.arsenal.tick(w,51,Vector2.ZERO)
	check(w.arsenal.heart_price==2,"A prolonged quiet interval cools the heart price")
	w=fresh();w.items={"empty_totem":1};w.damage_player(100)
	check(w.hp==6 and w.arsenal.totem_spent and w.invulnerable>2,"Empty totem rescues a lethal hit once")
	w.state="PAUSED";w.discard("empty_totem");w.apply_upgrade("empty_totem");w.state="RUNNING";w.invulnerable=0;w.damage_player(100)
	check(w.hp<=0 and w.arsenal.totem_spent,"Discard and reacquire cannot grant a second resurrection")
	w=fresh();w.items={"armor":5,"thorns":3};w.evolved={"armor":true};m=mob(w)
	w.hp=12;w.receive_hit(4,m);var reflected: float=10000-m.hp
	check(reflected>0 and w.hp>9 and w.invulnerable>.65,"Iron Maiden returns contact damage, heals a bounded amount and extends grace time")
	w.invulnerable=0;w.receive_hit(4,m)
	check(10000-m.hp==reflected,"Retaliation has a separate cooldown")
	w=fresh();w.items={"bat_wings":5};w.build={"sword":8};m=mob(w);w.hp=10;w.arsenal.tick(w,.01,Vector2.ZERO)
	for i in range(20):w.arsenal.hit(w,m,1,"sword")
	check(w.hp>10 and w.hp<=10.601,"Many melee contacts share one capped lifesteal budget")
	w.arsenal.vamp_budget=1;var before: float=w.hp;w.arsenal.hit(w,m,5,"shotgun")
	check(w.hp==before,"Ranged shots do not grant melee lifesteal")
	w=fresh();w.items={"mirror_shard":5};w.build={"sword":8};m=mob(w)
	for i in range(3):w.clock+=1;w.animation.strike(w,"sword",Vector2.RIGHT);w.arsenal.hit(w,m,1,"sword")
	check(w.arsenal.mirror_ready and w.arsenal.echoes.is_empty(),"Mirror charges on separate successful melee attacks")
	w.clock+=1;w.animation.strike(w,"sword",Vector2.RIGHT);w.arsenal.hit(w,m,1,"sword")
	check(w.arsenal.echoes.size()==1 and w.damage_by.get("mirror_shard",0)==0,"Charged mirror delays the next attack instead of duplicating it immediately")
	w.arsenal.step(w,.3)
	check(w.damage_by.get("mirror_shard",0)>0 and not w.arsenal.mirror_ready and w.arsenal.mirror_count==0,"Echo deals reduced attributed damage without recharging itself")
	w=fresh();w.items={"black_candle":5,"bedrock":5};var basic: float=w.db.stats("sword",1).damage
	for i in range(250):w.arsenal.tick(w,.02,Vector2.ZERO)
	check(w.db.stats("sword",1).damage>basic and w.arsenal.still>.7,"Standing still builds candle damage and stationary protection")
	w.damage_player(10)
	check(is_equal_approx(w.hp,12) and w.resist_displacement(Vector2(10,0)).x==4,"Bedrock reduces a stationary hit and external displacement")
	w.arsenal.tick(w,1,Vector2.RIGHT)
	check(w.arsenal.candle==0 and w.arsenal.still==0,"Moving spends the candle charge and removes stationary protection")
	w=fresh();w.build={"bone_saw":8};w.items={"heart_booster":5};m=mob(w);w.arsenal.tick(w,.01,Vector2.ZERO);w.active_item("heart");w.arsenal.tick(w,.01,Vector2.ZERO);w.update_attacks(.01)
	for i in range(6):
		if not w.arsenal.actions.has("bone_saw"):break
		var cast: Dictionary=w.arsenal.actions.bone_saw
		var k: float=clampf((cast.age+1.0/60-cast.wind)/(cast.duration-cast.wind),0,1)
		m.p=w.player+cast.dir.rotated(-.65+sin(k*PI)*1.3)*cast.stats.radius*(.3+.7*sin(k*PI));w.rebuild_hit_grid();w.arsenal.step(w,1.0/60)
	check(w.damage_by.get("bone_saw",0)>0,"Tenfold heart speed still allows real saw contact before the shortened cycle ends")
	w=fresh();w.build={"potion":1};w.hp=10;release(w,"potion")
	check(w.hp>10 and w.arsenal.events.is_empty(),"Potion I drinks a real healing dose")
	w.build.potion=2;w.arsenal.potion_heal_left=0;m=mob(w,Vector2(15,0));release(w,"potion");w.arsenal.step(w,.25)
	check(m.hp<10000 and w.hp>11.2,"Healing splash also damages nearby undead")
	w=fresh();w.build={"potion":5};m=mob(w);w.arsenal.potion(w,true);w.arsenal.step(w,.5)
	check(m.hp<10000 and m.slow>0,"Later poison splash adds actual slowing")
	w=fresh();w.build={"potion":8};m=mob(w);m.allied=true;w.hp=10
	for i in range(8):release(w,"potion");w.arsenal.step(w,.21)
	check(w.arsenal.clouds.size()==4 and m.hp==10000,"Mist clouds stay bounded and never harm an ally")
	w.arsenal.potion_heal_left=0;before=w.hp;w.arsenal.step(w,.7)
	check(w.hp-before<=.321,"Overlapping healing mists share one healing gate")
	w.state="PAUSED";snap=JSON.stringify([w.clock,w.hp,w.arsenal.clouds,w.arsenal.pet,w.arsenal.heart_price,w.arsenal.events]);advance(w,1)
	check(snap==JSON.stringify([w.clock,w.hp,w.arsenal.clouds,w.arsenal.pet,w.arsenal.heart_price,w.arsenal.events]),"Pause freezes the full arsenal, active costs and pet")
	w.reset(88)
	check(not w.arsenal.totem_spent and w.arsenal.heart_price==2 and w.arsenal.clouds.is_empty(),"A genuine new run resets persistent equipment state")
	print("CHAPTER_FOUR_ARSENAL_RESULT %d checks; %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
