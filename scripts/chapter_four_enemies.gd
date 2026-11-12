extends RefCounted
## All Chapter IV enemy behaviour is isolated here. Timers are simulation time;
## warnings, effects and hits read the same locked aim/segment/landing point.
static func enter(m: Dictionary, phase: String, duration: float):
	m.phase=phase;m.timer=duration;m.phase_duration=duration;m.phase_age=0.0

static func windup(w, m: Dictionary, aim: Vector2):
	m.charge=aim;enter(m,"windup",m.ai.windup)
	if m.kind=="gravedigger":
		m.wall_points=[]
		for j in range(3):
			var p: Vector2=m.p+aim*48+aim.orthogonal()*(22+j*18)
			if w.free_at(p,12) and p.distance_to(w.player)>26:m.wall_points.append(p)
	if w.visible(m.p,25):w.sound("ch4_bell_warn" if m.kind=="bellringer" else "ch4_mob_warn",.45)

static func cancel(m: Dictionary, wait: float = 1.1):
	enter(m,"recover",wait);m.cast="";m.wall_points=[]

static func update(w, dt: float):
	for m in w.mobs:
		if not m.has("form") or m.hp<=0:continue
		m.animation+=dt
		if m.stun<=0 and m.pull_left<=0:m.phase_age+=dt
		m.flash=maxf(0,m.flash-dt)
		m.haste=maxf(0,m.haste-dt);m.control_resist=maxf(0,m.control_resist-dt)
		m.stun=maxf(0,m.stun-dt);m.slow=maxf(0,m.slow-dt)
		if m.burn>0:
			m.burn-=dt;m.burn_tick-=dt
			if m.burn_tick<=0:m.burn_tick+=.5;w.damage_owner="fire";w.hurt(m,w.burn_damage(m))
		if m.hp<=0:continue
		if m.kind=="parasite" and w.clock>=m.expires:m.expired=true;m.hp=0;continue
		var before: Vector2=m.p
		var was_attacking: bool=m.phase=="attack"
		if m.pull_left>0:
			var distance: float=minf(m.pull_left,380*dt)
			m.p=w.move_actor(m.p,m.pull_dir*distance,m.radius);m.pull_left-=distance
			if m.pull_left<=.1:m.stun=m.pull_stun
		elif m.stun<=0:
			act(w,m,dt)
		m.p=w.move_actor(m.p,m.knock*dt,m.radius);m.knock=m.knock.move_toward(Vector2.ZERO,dt*400)
		m.moving=m.p.distance_squared_to(before)>.0001;m.visual.travel=m.p.distance_to(before)
		if (m.phase=="attack" or was_attacking) and m.kind in ["open_cow","bone_rider","torn_spider","hungry_wolf"]:
			if Geometry2D.get_closest_point_to_segment(w.player,before,m.p).distance_to(w.player)<m.radius+6:w.receive_hit(m.damage,m)
		elif m.kind not in ["bloated_creeper","growth_skeleton","bellringer","infected_witch","gravedigger"] and m.phase=="walk":
			contact(w,m,m.radius+5)

static func travel(w, m: Dictionary, direction: Vector2, speed: float, dt: float):
	m.dir=direction
	var buff: float=m.haste_scale if m.haste>0 else 1.0
	m.p=w.move_actor(m.p,direction*speed*buff*(.65 if m.slow>0 else 1.0)*dt,m.radius)

static func act(w, m: Dictionary, dt: float):
	m.timer-=dt
	var ai: Dictionary=m.ai
	var distance: float=m.p.distance_to(w.player)
	var toward: Vector2=m.p.direction_to(w.player)
	if m.phase=="smash_wait":return
	if m.phase=="recover":
		if m.timer<=0:enter(m,"walk",ai.get("cooldown",2.0))
		return
	if m.phase=="attack":
		if m.kind in ["open_cow","bone_rider","torn_spider","hungry_wolf"]:
			var before: Vector2=m.p
			travel(w,m,m.charge,ai.dash_speed,dt)
			var blocked: bool=m.p.distance_to(before)<float(ai.dash_speed)*dt*.4
			if blocked and m.kind in ["open_cow","bone_rider"]:
				m.stun=float(ai.get("stun",1.6));m.passes=0;cancel(m,1.8)
				w.add_effect("ch4_stun",m.p,.7);return
			if m.kind=="torn_spider":m.lift=sin(clampf(m.phase_age/ai.attack,0,1)*PI)*15
		if m.timer<=0:
			m.lift=0
			if m.kind=="torn_spider":field(w,"web",m.p,22,5,0)
			if m.kind=="bone_rider":
				m.passes+=1
				if m.passes<int(ai.passes):enter(m,"turn",.65);return
				m.passes=0
			enter(m,"recover",ai.get("recover",.8))
		return
	if m.phase=="turn":
		var destination: Vector2=m.pass_origin if m.passes%2==1 else m.pass_end
		m.dir=m.dir.slerp(m.p.direction_to(destination),minf(1,dt*6))
		if m.timer<=0:windup(w,m,m.p.direction_to(destination))
		return
	if m.phase=="windup":
		if m.kind in ["growth_skeleton","infected_witch"] and distance<110:
			cancel(m,.18);return
		if m.kind=="growth_skeleton" and m.timer>.2:m.charge=toward
		if m.timer<=0:
			strike(w,m)
		return
	# Walking/idle: simple mobs form the crowd; stronger ones reserve clear tells.
	var direction: Vector2=w.navigation(m.p)
	var speed: float=m.speed
	if m.boss and w.encounters.busy() and distance<float(w.encounters.data.rules.elite_radius):
		m.timer=maxf(m.timer,.8+float(m.id%3)*.4)
		travel(w,m,direction,speed*.55,dt)
		return
	match m.kind:
		"flayed_zombie":
			if m.timer<=0 and distance<ai.reach:windup(w,m,toward);return
		"growth_skeleton":
			if distance<110:direction=-toward
			elif distance<180:speed=0
			if m.timer<=0 and distance>=110 and distance<ai.range and w.line_clear(m.p,w.player):windup(w,m,toward);return
		"bloated_creeper":
			if distance<ai.reach:windup(w,m,toward);return
		"torn_spider","hungry_wolf":
			if distance<150 and distance>60:direction=direction.rotated(.38 if m.id%2 else -.38)
			if m.timer<=0 and distance<ai.reach:windup(w,m,toward);return
		"open_cow":
			if m.timer<=0 and distance<ai.reach:windup(w,m,toward);return
		"crawler":
			if m.timer<=0:field(w,"rot",m.p,11,ai.trail_life,1);m.timer=ai.trail_interval
		"infected_witch":
			if distance<110:direction=-toward
			elif distance<175:speed=0
			if m.timer<=0 and distance>=110 and distance<ai.range:
				m.cast="poison";m.mark=w.player+w.tracked_velocity*.2
				for other in w.mobs:
					if other.id!=m.id and other.hp>0 and not other.get("allied",false) and other.hp<other.max_hp*.7 and m.p.distance_to(other.p)<ai.heal_radius:
						m.cast="heal";m.mark=other.p;break
				windup(w,m,toward);return
		"fused_villagers":
			if not m.changed and m.timer<=0 and distance<ai.range:windup(w,m,toward);return
		"gravedigger":
			if m.timer<=0 and distance<ai.reach:windup(w,m,toward);return
		"bellringer":
			if m.timer<=0 and distance<260:windup(w,m,toward);return
		"bone_rider":
			if m.timer<=0 and distance<ai.reach:
				m.pass_origin=m.p
				m.pass_end=m.p+toward*ai.dash_speed*ai.attack
				windup(w,m,toward);return
	travel(w,m,direction,speed,dt)

static func strike(w, m: Dictionary):
	var ai: Dictionary=m.ai
	match m.kind:
		"flayed_zombie":
			var end: Vector2=m.p+m.charge*ai.reach
			w.add_effect("ch4_slam",m.p,.18,{"end":end,"width":9.0})
			if Geometry2D.get_closest_point_to_segment(w.player,m.p,end).distance_to(w.player)<11:w.receive_hit(m.damage,m)
		"growth_skeleton":shoot(w,m.p,m.charge,"bone",ai.speed,m.damage)
		"bloated_creeper":
			contact(w,m,ai.radius)
			w.add_effect("ch4_burst",m.p,.4,{"radius":float(ai.radius)})
			m.exploded=true;m.hp=0;w.sound("ch4_creeper_burst");return
		"infected_witch":
			if m.cast=="heal":
				for other in w.mobs:
					if other.hp>0 and other.get("undead",false) and not other.get("allied",false) and other.p.distance_to(m.mark)<ai.heal_radius*.65:other.hp=minf(other.max_hp,other.hp+ai.heal_amount)
				w.add_effect("ch4_heal",m.mark,.7);w.sound("ch4_mob_heal")
			else:
				w.enemy_bottles.append({"p":m.p,"end":m.mark,"age":0.0,"total":.55,"radius":float(ai.cloud_radius),"life":float(ai.cloud_life),"damage":float(m.damage)})
		"fused_villagers":
			for angle in [-.2,0.0,.2]:shoot(w,m.p,m.charge.rotated(angle),"clot",75,m.damage)
		"gravedigger":
			for p in m.wall_points:
				w.add_solid(p,ai.wall_radius)
				w.mob_walls.append({"p":p,"r":float(ai.wall_radius),"life":float(ai.wall_life),"age":0.0,"owner":m.id})
			w.update_flow()
			# Wall rises first; the broad smash follows after another preparation.
			enter(m,"smash_wait",.7);return
		"bellringer":
			for other in w.mobs:
				if other.hp>0 and not other.get("allied",false) and other.p.distance_to(m.p)<ai.buff_radius:other.haste=ai.buff_life;other.haste_scale=ai.buff_speed
			w.add_effect("ch4_bell_wave",m.p,.65);w.sound("ch4_bell")
	enter(m,"attack",ai.get("attack",.2))

static func smash(w,m: Dictionary):
	var end: Vector2=m.p+m.charge*m.ai.slam_length
	w.add_effect("ch4_slam",m.p,.3,{"end":end,"width":float(m.ai.slam_width)})
	if Geometry2D.get_closest_point_to_segment(w.player,m.p,end).distance_to(w.player)<float(m.ai.slam_width):w.receive_hit(m.damage,m)
	for wall in w.mob_walls:
		if wall.owner==m.id:wall.life=0
	w.sound("ch4_ground_slam");enter(m,"attack",m.ai.attack)

static func shoot(w, p: Vector2, dir: Vector2, kind: String, speed: float, damage: float):
	if w.enemy_shots.size()>=int(w.db.data.chapter_four.enemy_limits.shots):return
	w.enemy_shots.append({"p":p,"dir":dir,"kind":kind,"speed":speed,"damage":damage,"life":3.2})
	if w.visible(p,20):w.sound("ch4_bone_shoot" if kind=="bone" else "ch4_pulse",.15)

static func field(w, kind: String, p: Vector2, radius: float, life: float, damage: float):
	if w.enemy_fields.size()>=int(w.db.data.chapter_four.enemy_limits.fields):return
	w.enemy_fields.append({"kind":kind,"p":p,"radius":radius,"life":life,"total":life,"damage":damage,"tick":.4})

static func environment(w,dt: float):
	w.mob_slow=1.0
	for i in range(w.enemy_shots.size()-1,-1,-1):
		var b=w.enemy_shots[i];var before: Vector2=b.p
		b.p+=b.dir*b.speed*dt;b.life-=dt
		if Geometry2D.get_closest_point_to_segment(w.player,before,b.p).distance_to(w.player)<8:w.damage_player(b.damage);b.life=0
		if b.life<=0:w.enemy_shots.remove_at(i)
	for i in range(w.enemy_bottles.size()-1,-1,-1):
		var b=w.enemy_bottles[i];b.age+=dt
		if b.age>=b.total:
			field(w,"poison",b.end,b.radius,b.life,b.damage);w.enemy_bottles.remove_at(i);w.sound("ch4_poison")
	for i in range(w.enemy_fields.size()-1,-1,-1):
		var f=w.enemy_fields[i];f.life-=dt;f.tick-=dt
		if w.player.distance_to(f.p)<f.radius:
			w.mob_slow=minf(w.mob_slow,float(w.db.data.chapter_four.enemy_limits.field_slow))
			if f.tick<=0 and f.damage>0:w.damage_player(f.damage)
		if f.tick<=0:f.tick+=.8
		if f.life<=0:w.enemy_fields.remove_at(i)
	for i in range(w.mob_walls.size()-1,-1,-1):
		var wall=w.mob_walls[i];wall.life-=dt;wall.age+=dt
		if wall.life<=0:
			w.remove_mob_solid(wall.p);w.mob_walls.remove_at(i)
	for m in w.mobs:
		if m.get("phase","")=="smash_wait" and m.hp>0 and m.stun<=0 and m.pull_left<=0:
			# phase timer advances in update(), independent of renderer/real time.
			if m.timer<=0:smash(w,m)
	for cyst in w.threats:
		if cyst.hp<=0 or not cyst.has("parasite_at"):continue
		if cyst.parasites_left>0 and w.clock>=cyst.parasite_at:
			for j in range(int(cyst.parasites_left)):
				var p: Vector2=cyst.p+Vector2.from_angle(j*TAU/3)*15
				if w.free_at(p,5):w.spawn("parasite",p)
			cyst.parasites_left=0
		if w.clock>=cyst.expires_at:cyst.expiring=true;w.hurt(cyst,cyst.hp)
	for flock in w.chickens:
		flock.age+=dt
		if flock.state=="watch" and w.player.distance_to(flock.p)<75:flock.state="flee";flock.age=0
		if flock.state=="flee":flock.p=w.move_actor(flock.p,flock.p.direction_to(w.player)*-42*dt,3)
		flock.dir=flock.p.direction_to(w.player) if flock.state=="watch" else w.player.direction_to(flock.p)

static func poses(w):
	for m in w.mobs:
		if not m.has("form"):continue
		m.visual_dir=m.charge if m.phase in ["windup","attack","smash_wait"] else m.dir
		if m.phase in ["windup","smash_wait"]:w.animation.set_pose(m.visual,"windup",clampf(m.phase_age/maxf(.01,m.phase_duration),0,.999)*.16)
		elif m.phase=="attack":w.animation.set_pose(m.visual,"attack",fposmod(m.phase_age,.09))
		elif m.phase in ["recover","turn"]:w.animation.set_pose(m.visual,"recover",clampf(m.phase_age/maxf(.01,m.phase_duration),0,.999)*.24)
		if m.stun>0:w.animation.set_pose(m.visual,"hurt",.06)

static func contact(w,m: Dictionary,radius: float):
	if w.player.distance_to(m.p)<radius:w.receive_hit(m.damage,m)
