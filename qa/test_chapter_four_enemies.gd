extends SceneTree
const FW=preload("res://scripts/chapter_four_world.gd")
const E=preload("res://scripts/chapter_four_enemies.gd")
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func fresh():
	var w=FW.new();w.reset(724);w.state="RUNNING";w.stage="survival";w.build={};w.note_presented=true
	w.db.data.chapter_four.exploration_only=true
	w.threats.clear();w.landmarks.clear();w.solid_grid.clear();w.blocked.clear();w.props.clear();w.update_flow()
	return w
func advance(w,seconds: float,movement:=Vector2.ZERO):
	for i in range(ceili(seconds*60)):
		if w.state=="LEVEL_UP":w.skip_reward()
		w.step(1.0/60,movement)
func mob(w,kind: String,offset:=Vector2(70,0)):
	assert(w.spawn(kind,w.player+offset));w.rebuild_hit_grid();return w.mobs.back()
func run():
	var w=fresh()
	# Scripted IV arrivals (Crucified, butcher) exceed the elite limit on purpose.
	w.hunt.forcing=true
	for kind in w.db.data.forms:
		var m=mob(w,kind,Vector2(160,0))
		check(m.kind==kind and m.form==kind and m.undead and m.skin=="ch4_"+kind,"Dedicated undead form: "+kind)
		check(w.animation.data.actors.has(m.skin),"Own animation metadata: "+kind)
	w.hunt.forcing=false
	w=fresh();var m=mob(w,"growth_skeleton",Vector2(160,0));m.timer=0
	advance(w,.5)
	check(m.phase=="windup" and w.enemy_shots.is_empty(),"Skeleton draws a bone arrow before firing")
	advance(w,.08);var locked: Vector2=m.charge;w.player+=Vector2(0,60);advance(w,.2)
	check(not w.enemy_shots.is_empty() and w.enemy_shots[0].dir.is_equal_approx(locked),"Skeleton locks aim during the final 0.2 seconds")
	w=fresh();m=mob(w,"flayed_zombie",Vector2(24,0));m.timer=0;var hp=w.hp
	advance(w,.35)
	check(w.hp==hp and m.phase=="windup","Zombie lunge cannot hit during its preparation")
	advance(w,.25);check(w.hp<hp,"Zombie lunge hits the prepared segment")
	w=fresh();m=mob(w,"bloated_creeper",Vector2(20,0));advance(w,.8)
	check(m.hp>0 and m.phase=="windup" and w.hp==20,"Bloated creeper has a full warning before exploding")
	advance(w,.4)
	check(w.mobs.is_empty() and w.hp<20 and w.threats.size()==1,"Explosion leaves exactly one living cyst")
	var cyst=w.threats[0];w.hurt(cyst,999);advance(w,3)
	check(w.mobs.is_empty(),"Destroying the cyst prevents its parasites")
	w=fresh();m=mob(w,"bloated_creeper",Vector2(20,0));advance(w,4)
	check(w.mobs.size()==3 and w.mobs.all(func(a):return a.kind=="parasite"),"A surviving cyst emits three parasites once")
	advance(w,12,Vector2.RIGHT)
	check(w.mobs.is_empty() and w.orbs.is_empty(),"Parasites expire and do not create an XP farm")
	w=fresh()
	for i in range(40):w.spawn("parasite",w.player+Vector2(100,i))
	check(w.mobs.size()==int(w.db.data.chapter_four.enemy_limits.parasites),"Parasites respect their separate population cap")
	w=fresh();m=mob(w,"matted_sheep");var speed: float=m.speed;w.hurt(m,m.max_hp*.6)
	check(m.changed and m.skin=="ch4_sheared_sheep" and m.speed>speed and m.hp<=9,"Sheep sheds its coat and becomes fast and fragile")
	w.hurt(m,999);w.resolve_deaths();check(w.mobs.is_empty(),"Sheep never resurrects after lethal damage")
	w=fresh();m=mob(w,"fused_villagers");speed=m.speed;w.hurt(m,m.max_hp*.6)
	check(m.changed and m.skin=="ch4_fused_lower" and m.speed>speed,"Fused villagers lose the upper body and speed up")
	m.timer=0;advance(w,4)
	check(w.enemy_shots.is_empty(),"The remaining lower body cannot fire the lost head's clots")
	w=fresh();m=mob(w,"infected_witch",Vector2(150,0));var ally=mob(w,"flayed_zombie",Vector2(155,8));ally.hp=2;m.timer=0
	advance(w,.02);check(m.cast=="heal" and m.phase=="windup","Witch prepares a heal for damaged undead")
	w.hurt(m,1);check(m.phase=="recover" and ally.hp==2,"Any real hit interrupts a prepared witch heal")
	m.timer=0;m.phase="walk";advance(w,.95)
	check(ally.hp>2 and ally.hp<=ally.max_hp,"Uninterrupted healing restores ally HP without exceeding its maximum")
	w=fresh();m=mob(w,"infected_witch",Vector2(150,0));m.timer=0;advance(w,1.6)
	check(w.enemy_fields.any(func(f):return f.kind=="poison"),"Enemy potion lands as a bounded poison cloud")
	w=fresh();m=mob(w,"open_cow",Vector2(85,0));m.timer=0;advance(w,.7)
	check(m.phase=="windup" and w.hp==20,"Cow opens its chest before a charge")
	w.add_solid(m.p+Vector2(-30,0),12);advance(w,.6)
	check(m.stun>0,"Charging cow is stunned by a solid obstacle")
	w=fresh();m=mob(w,"torn_spider",Vector2(80,0));m.timer=0;advance(w,.85)
	check(m.phase=="attack" and m.lift>0,"Spider has a real visible jump after crouching")
	advance(w,.5);check(w.enemy_fields.any(func(f):return f.kind=="web"),"Spider leaves a small temporary web on landing")
	w=fresh();var wolves=[]
	for i in range(3):wolves.append(mob(w,"hungry_wolf",Vector2(60,i*5)))
	check(wolves[0].timer!=wolves[1].timer and wolves[1].timer!=wolves[2].timer,"Pack jumps have staggered initial timing")
	w=fresh();m=mob(w,"crawler");m.timer=0;advance(w,.1)
	check(w.enemy_fields.any(func(f):return f.kind=="rot"),"Crawler leaves infected ground")
	w=fresh();m=mob(w,"bellringer");ally=mob(w,"flayed_zombie",Vector2(85,0));m.timer=0;advance(w,.1)
	w.hurt(m,1);advance(w,1.4)
	check(ally.haste==0,"Damaging the bellringer interrupts the acceleration")
	m.timer=0;m.phase="walk";advance(w,1.4)
	check(ally.haste>0 and ally.haste_scale>1,"Completed bell ring accelerates nearby enemies")
	w=fresh();m=mob(w,"gravedigger",Vector2(100,0));m.timer=0;advance(w,1.2)
	check(not w.mob_walls.is_empty() and m.phase=="smash_wait","Gravedigger raises a temporary wall before the broad smash")
	check(w.free_at(w.player,6) and w.flow[int(w.player.y/32)*64+int(w.player.x/32)]==0,"Raised wall never occupies or seals the hero's cell")
	var wall: Vector2=w.mob_walls[0].p;check(not w.free_at(wall,6),"Visible earth blocks have physical collision")
	m.hp=0;w.resolve_deaths();advance(w,2.5)
	check(w.mob_walls.is_empty() and w.free_at(wall,6),"Temporary earth and its navigation block expire even after owner death")
	w=fresh();m=mob(w,"bone_rider",Vector2(150,0));m.timer=0;advance(w,.8)
	check(m.phase=="windup" and w.hp==20,"Bone rider marks its track before moving")
	advance(w,7.3)
	check(m.phase in ["recover","walk"] and m.passes==0,"Three horse passes end in an attack window")
	w=fresh();m=mob(w,"bone_rider",Vector2(150,0));m.timer=0
	var passes: Array=[];var pass_start:=Vector2.ZERO;var previous: String=m.phase
	for i in range(460):
		advance(w,1.0/60)
		if m.phase=="attack" and previous!="attack":pass_start=m.p
		if previous=="attack" and m.phase!="attack":passes.append(m.p.distance_to(pass_start))
		previous=m.phase
	check(passes.size()==3 and passes.all(func(v):return v>140),"All three horse passes actually cover the warned distance")
	w=fresh();m=mob(w,"bellringer");m.timer=0;advance(w,.1);w.hook_target(m,false);advance(w,.8)
	check(m.phase!="windup" and m.control_resist>0,"Hook control interrupts an elite cast and applies repeat protection")
	E.windup(w,m,Vector2.LEFT);w.hook_target(m,false)
	check(m.phase=="windup","Repeat-control protection also prevents repeated cast interruption")
	w=fresh();m=mob(w,"flayed_zombie",Vector2(10,0));ally=mob(w,"flayed_zombie",Vector2(16,0));ally.allied=true
	var health: float=ally.hp;w.heal_undead(w.player,40,3)
	check(m.hp<m.max_hp and ally.hp==health,"Healing-damage hook hurts all hostile undead and excludes allies")
	w=fresh()
	for i in range(90):E.field(w,"web",w.player,20,2,0)
	check(w.enemy_fields.size()==int(w.db.data.chapter_four.enemy_limits.fields),"Residue fields have a global cap")
	advance(w,.1);check(w.mob_slow>=.7,"Overlapping slow fields do not multiply into permanent immobilization")
	w.state="PAUSED";var snapshot=JSON.stringify([w.clock,w.mobs,w.enemy_fields,w.chickens]);advance(w,1)
	check(snapshot==JSON.stringify([w.clock,w.mobs,w.enemy_fields,w.chickens]),"Pause freezes every enemy, field and atmospheric chicken")
	w.reset(725);check(w.enemy_fields.is_empty() and w.mob_walls.is_empty() and w.enemy_shots.is_empty(),"Reset clears the new enemy queues")
	var a=FW.new();a.reset(726);a.stage="survival";var b=FW.new();b.reset(726);b.stage="survival"
	advance(a,35,Vector2.RIGHT);advance(b,35,Vector2.RIGHT)
	check(JSON.stringify([a.mobs,a.player,a.hp,a.rng.state])==JSON.stringify([b.mobs,b.player,b.hp,b.rng.state]),"IV waves and enemy decisions reproduce from the same seed and inputs")
	print("CHAPTER_FOUR_ENEMIES_RESULT %d checks; %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
