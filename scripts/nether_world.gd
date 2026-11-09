extends "res://scripts/campaign_world.gd"
## Chapter II is a solo world. No RPC, snapshot or cooperative rules enter here.
const NEW_WEAPONS=["axe","hoe","bed","tnt","crossbow","fishing"]
const PIGLINS=["piglin_sword","piglin_crossbow"]
const ARENA=Rect2(736,800,576,448)
const INTRO_DURATION=preload("res://scripts/ghast_intro.gd").DURATION
var ghast=preload("res://scripts/ghast_intro.gd").new()
var stage="survival"
var stage_age=0.0
var magma: Array=[]
var explosives: Array=[]
var tnt_groups: Array=[]
var hazards: Array=[]
var player_burn=0.0
var player_wither=0.0
var wither_tick=0.0
var burn_tick=0.0
var regen_tick=5.0
var pearl=false
var portal_lit=false
var portal_camera_focus=false
var portal_position=Vector2(1024,1024)
var boss_hits=0
var tracked_velocity=Vector2.ZERO
var transition_camera=Vector2.ZERO
var jump_start=Vector2.ZERO
var defeated_boss: Dictionary={}
var arena_camera=Vector2(1024,1040)
var soul_sand=PackedByteArray()
var encounter=preload("res://scripts/wither_encounter.gd").new()

func chapter_number() -> int:return 2

func reset(seed_value: int = 0):
	stage="survival"
	stage_age=0
	magma.clear()
	explosives.clear()
	tnt_groups.clear()
	hazards.clear()
	player_burn=0
	player_wither=0;wither_tick=0
	burn_tick=0
	regen_tick=5
	pearl=false
	portal_lit=false
	portal_camera_focus=false
	boss_hits=0
	tracked_velocity=Vector2.ZERO
	transition_camera=Vector2.ZERO
	jump_start=Vector2.ZERO
	defeated_boss={}
	ghast.reset()
	super.reset(seed_value)
	arena_camera=Vector2(1024,1040)
	soul_sand.resize(128*128)
	soul_sand.fill(0)
	var terrain: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/nether_terrain.json"))
	for cell in terrain.soul_sand_cells:soul_sand[int(cell)]=1
	var extra: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/nether_animations.json"))
	animation=preload("res://scripts/animation.gd").new()
	animation.data.actors.merge(extra.actors,true)
	animation.data.weapons.merge(extra.weapons,true)


func make_map():
	for y in range(2,8):
		for x in range(2,8):
			var p=Vector2(x*240+rng.randf_range(-42,42),y*240+rng.randf_range(-42,42))
			if p.distance_to(player)<145:continue
			add_prop("rock",p)
			if (x+y)%3==0:add_prop("tree",p+Vector2(34,12))
	for i in range(32):
		var angle=i*2.39996
		var distance=145+i%6*132
		var p=(player+Vector2.from_angle(angle)*distance).clamp(Vector2(80,80),Vector2(1960,1960))
		props.append({"type":"pumpkin","p":p,"hp":12.0,"id":next_id(),"radius":7.0})
	for i in range(24):
		var p=Vector2(rng.randf_range(120,1928),rng.randf_range(120,1928))
		if p.distance_to(player)>145:magma.append({"p":p,"radius":22.0+float(i%3)*5})

	assign_healing()

func camera() -> Vector2:
	if stage=="departure":return transition_camera+Vector2(0,-smoothstep(0,1.6,stage_age)*14)
	if stage=="arrival":return Vector2(1024,1000).lerp(Vector2(1024,1040),smoothstep(0,INTRO_DURATION,stage_age))
	if stage!="survival":return arena_camera
	return super.camera()

func move_actor(p: Vector2, velocity: Vector2, radius: float) -> Vector2:
	var q=super.move_actor(p,velocity,radius)
	if stage not in ["survival","departure"]:q=q.clamp(ARENA.position+Vector2.ONE*radius,ARENA.end-Vector2.ONE*radius)
	return q

func step(dt: float, movement: Vector2 = Vector2.ZERO):
	if state!="RUNNING":return
	track_progress(dt)
	clock+=dt
	stage_age+=dt
	if stage=="survival":time=minf(720,time+dt)
	invulnerable=maxf(0,invulnerable-dt)
	shake=maxf(0,shake-dt)
	message_timer=maxf(0,message_timer-dt)
	ghast.step(self,dt)
	var before=player
	if movement.length_squared()>0 and stage in ["survival","wither","portal"]:
		facing=movement.normalized()
		player=move_actor(player,movement.limit_length()*movement_speed()*dt,6)
		moved+=dt
	tracked_velocity=tracked_velocity.lerp((player-before)/maxf(.0001,dt),minf(1,dt*10))
	player_visual.travel=before.distance_to(player)
	player_moving=player_visual.travel>.0001
	flow_timer-=dt
	if flow_timer<=0 and flow_cell!=Vector2i(player/CELL):update_flow();flow_timer=.25
	if stage=="survival":spawn_wave(dt)
	if stage in ["survival","wither"]:
		move_mobs(dt)
		rebuild_hit_grid()
		update_attacks(dt)
		update_projectiles(dt)
		update_explosives(dt)
		update_hazards(dt)
		update_fire(dt)
		resolve_deaths()
	update_effects(dt)
	pickup(dt)
	update_particles(dt)
	animation.advance(self,dt)
	advance_nether_poses()
	update_arena_camera(dt)
	regen_tick-=dt
	if regen_tick<=0:
		regen_tick+=5
		if hp>0:hp=minf(20,hp+.3*items.get("ghast_tear",0))
	if hp<=0:
		state="RESULT"
		victory=false
		sound("death")
		return
	match stage:
		"survival":
			if time>=720:begin_arena();return
		"departure":
			if stage_age>=1.6:prepare_arena()
		"arrival":
			if stage_age>=INTRO_DURATION:
				stage="wither"
				stage_age=0
				invulnerable=.4
		"defeat":
			if stage_age>=2.8:
				stage="portal"
				stage_age=0
				loot.append({"kind":"ender_eye","p":defeated_boss.p.clamp(ARENA.position+Vector2(40,40),ARENA.end-Vector2(40,40))})
		"portal":
			if pearl and not portal_lit and player.distance_to(portal_position)<58:
				pearl=false
				stage="lighting"
				stage_age=0
				facing=player.direction_to(portal_position)
				sound("portal_ignite")
			elif portal_lit and player.distance_to(portal_position)<16:enter_portal()
		"lighting":
			if stage_age>=1.8:
				portal_lit=true
				stage="portal"
				stage_age=0
				sound("portal_open")
		"jump":
			if stage_age>=3.1:
				stage="crossing"
				stage_age=0
				win_music=false
		"crossing":
			if stage_age>=1.0:
				stage="end"
				state="RESULT"
				victory=true

	if stage in ["survival","wither"]:
		if xp>=db.required_xp(level):next_level()
		elif not pending_chest.is_empty():open_chest(pending_chest)

func enter_portal() -> bool:
	if state!="RUNNING" or stage!="portal" or not portal_lit or player.distance_to(portal_position)>36:return false
	stage="jump"
	stage_age=0
	jump_start=player
	if player.distance_to(portal_position)>.1:facing=player.direction_to(portal_position)
	sound("portal_travel")
	return true

func begin_arena():
	time=720
	win_music=false
	ghast.reset()
	transition_camera=super.camera()
	stage="departure"
	stage_age=0
	player_burn=0
	player_wither=0;wither_tick=0
	tracked_velocity=Vector2.ZERO
	invulnerable=2
	message=""
	message_timer=0

func prepare_arena():
	stage="arrival"
	stage_age=0
	arena_camera=Vector2(1024,1040)
	player=Vector2(1024,1140)
	facing=Vector2.UP
	hp=minf(20,hp+8)
	player_burn=0
	player_wither=0;wither_tick=0
	invulnerable=INTRO_DURATION
	portal_camera_focus=false
	ghast.begin(int(rng.seed))
	for pool in [mobs,projectiles,effects,particles,pixels,loot,orbs,tasks,props,explosives,tnt_groups,hazards,magma,pending_events]:pool.clear()
	pending_chest={}
	hit_grid.clear()
	solid_grid.clear()
	blocked.clear()
	update_flow()
	spawn("wither",Vector2(1024,1030))
	message=""
	message_timer=0

func spawn(kind: String, at = null) -> bool:
	if kind in ["piglin_crossbow","blaze_nether"]:
		var count=0
		for m in mobs:
			if m.kind==kind and m.hp>0:count+=1
		if count>=10:return false
	if not super.spawn(kind,at):return false
	var m: Dictionary=mobs.back()
	m.aggro=0.0
	m.fire_aspect=kind=="piglin_sword" and (m.id%4==0)
	m.slow=0.0
	m.boss=false
	m.attack_tick=1.6
	m.slam_tick=6.0
	m.mark=Vector2.ZERO
	m.rage=false
	m.pattern=0
	m.windup=1.0
	m.burst_left=0
	m.burst_tick=0.0
	m.orbit_tick=4.0
	m.stun=0.0;m.pull_left=0.0;m.pull_dir=Vector2.ZERO;m.pull_stun=0.0;m.control_resist=0.0
	if kind in ["brute","wither"]:
		m.hp=db.data.mobs[kind].hp
		m.max_hp=m.hp
		m.boss=true
		message="Пиглин-брут" if kind=="brute" else "Иссушитель"
		message_timer=3
		if kind!="wither" or stage!="arrival":sound("warning")
	return true

func neutral(m: Dictionary) -> bool:
	return items.has("gold_boots") and m.kind in PIGLINS and m.aggro<=0

func nearest(p: Vector2, radius: float = 260):
	var best=radius*radius
	var result=null
	for m in in_radius(p,radius):
		if neutral(m):continue
		var distance=p.distance_squared_to(m.p)
		if distance<best:best=distance;result=m
	return result

func hurt(m: Dictionary, amount: float, push: Vector2 = Vector2.ZERO):
	if m.hp<=0:return
	if m.kind in PIGLINS or m.kind=="zombified_piglin":
		for other in in_radius(m.p,130):
			if other.kind in PIGLINS or other.kind=="zombified_piglin":other.aggro=maxf(4,14-2*items.get("gold_boots",0))
		m.aggro=maxf(4,14-2*items.get("gold_boots",0))
	var factor=1+.12*items.get("feather",0)
	if m.kind=="wither":factor=.12;boss_hits+=1
	super.hurt(m,amount,push*factor)

func sound(id: String, gap: float = .04):
	var aliases={"hurt_blaze_nether":"hurt_blaze","hurt_piglin_sword":"hurt_piglin","hurt_piglin_crossbow":"hurt_piglin","hurt_brute":"hurt_piglin_brute"}
	super.sound(aliases.get(id,id),gap)

func move_mobs(dt: float):
	for m in mobs:
		if m.hp<=0:continue
		m.animation+=dt
		m.flash=maxf(0,m.flash-dt)
		m.control_resist=maxf(0,m.control_resist-dt)
		var controlled=m.pull_left>0 or m.stun>0
		if not controlled:m.timer-=dt
		m.aggro=maxf(0,m.aggro-dt)
		m.slow=maxf(0,m.slow-dt)
		if m.burn>0:
			m.burn-=dt;m.burn_tick-=dt
			if m.burn_tick<=0:m.burn_tick+=.5;hurt(m,burn_damage(m))
		if m.hp<=0:continue
		var old: Vector2=m.p
		if m.kind=="wither":encounter.passive(self,m,dt)
		if controlled:
			if m.pull_left>0:
				var travel=minf(m.pull_left,(220 if m.boss else 360)*dt)
				m.p=move_actor(m.p,m.pull_dir*travel,m.radius)
				m.pull_left=maxf(0,m.pull_left-travel)
				if m.pull_left<=.01:m.stun=m.pull_stun
			else:m.stun=maxf(0,m.stun-dt)
			m.moving=m.p.distance_squared_to(old)>.0001
			m.visual.travel=m.p.distance_to(old)
			continue
		var distance=old.distance_to(player)
		var direction=navigation(old)
		var speed: float=m.speed*(.4 if m.slow>0 else 1)
		if m.kind!="blaze_nether":speed*=terrain_factor(m.p,0)
		if neutral(m):
			direction=Vector2.from_angle(float(m.id)*2.4+floor(clock/4)*.8)
			speed=8
		elif m.kind=="wither":
			boss_step(m,dt)
			direction=m.dir
			speed=0
		elif m.kind in ["piglin_crossbow","blaze_nether"]:
			if distance<95:direction=-old.direction_to(player)
			elif distance<190:speed=0
			if m.timer<=0 and distance<280 and visible(old) and line_clear(old,player):
				var burning=m.kind=="blaze_nether"
				for j in range(3 if burning else 1):
					fire_projectile("enemy_flame" if burning else "enemy_arrow",old,old.direction_to(player).rotated((j-1)*.14 if burning else 0),{"speed":100 if burning else 145,"damage":m.damage,"range":310,"radius":4},false)
				m.timer=3.7 if burning else 2.8
				m.visual.shot_age=0
				sound("fire" if burning else "arrow",.1)
		elif m.kind in ["brute","hoglin","zoglin"]:
			if m.phase=="walk" and m.timer<=0 and distance<145:
				m.phase="windup";m.timer=.7;m.charge=old.direction_to(player)
			elif m.phase=="windup":
				speed=0
				if m.timer<=0:m.phase="charge";m.timer=.65
			elif m.phase=="charge":
				direction=m.charge;speed=160
				if m.timer<=0:m.phase="rest";m.timer=.9
			elif m.phase=="rest":
				speed=0
				if m.timer<=0:m.phase="walk";m.timer=3
		if m.kind!="wither":m.p=move_actor(old,(direction*speed+m.knock)*dt,m.radius)
		m.dir=direction
		m.moving=m.p.distance_squared_to(old)>.0001
		m.visual.travel=m.p.distance_to(old)
		m.knock=m.knock.move_toward(Vector2.ZERO,dt*400)
		if not neutral(m) and m.phase!="windup" and m.hp>0 and player.distance_to(m.p)<m.radius+6:
			var can_burn=m.fire_aspect or m.kind=="blaze_nether"
			if can_burn:ignite(2.5)
			var health_before=hp
			damage_player(m.damage)
			if m.kind=="wither_skeleton" and hp<health_before:
				if player_wither<=0:wither_tick=.8
				player_wither=maxf(player_wither,3.2)
		if m.phase=="windup":animation.set_pose(m.visual,"windup",.7-m.timer)

func boss_step(m: Dictionary, dt: float):
	encounter.step(self,m,dt)

func ignite(seconds: float):
	if hp>0:player_burn=maxf(player_burn,seconds)

func fire_damage(amount: float):
	if invulnerable>0 or hp<=0:return
	var before=hp
	hp-=maxf(.1,amount*(1-.16*items.get("fire_resist",0)))
	run_progress.damage(before-hp)
	invulnerable=.35
	player_visual.hurt=.12
	sound("hurt",.2)

func update_fire(dt: float):
	for patch in magma:
		if player.distance_to(patch.p)<patch.radius:ignite(1.2);break
	if player_burn>0:
		player_burn=maxf(0,player_burn-dt)
		burn_tick-=dt
		if burn_tick<=0:burn_tick+=.75;fire_damage(1.5)
	else:burn_tick=0
	if player_wither>0:
		player_wither=maxf(0,player_wither-dt);wither_tick-=dt
		if wither_tick<=0:wither_tick+=.8;fire_damage(1.5)

func hook_target(m: Dictionary, evolved_hook: bool):
	if m.control_resist>0:return
	var distance=maxf(0,m.p.distance_to(player)-m.radius-16)
	m.pull_left=minf((70 if m.boss else 150)*(1+.12*items.get("feather",0)),distance)
	m.pull_dir=m.p.direction_to(player)
	m.pull_stun=(.4 if evolved_hook else .25) if m.boss else (.95 if evolved_hook else .6)
	m.control_resist=1.8 if m.boss else .8
	m.knock=Vector2.ZERO
	if m.kind=="wither" and m.phase not in ["walk","recover","roar"]:
		m.phase="recover";m.timer=.45;m.burst_left=0
	elif m.kind in ["brute","hoglin","zoglin"] and m.phase in ["windup","charge"]:
		m.phase="rest";m.timer=.6
	if m.pull_left<=.01:m.stun=m.pull_stun
	add_effect("fishing_line",m.p,.3,{"end":player})

func update_attacks(dt: float):
	var all=build
	build={}
	for id in all:
		if id not in NEW_WEAPONS:build[id]=all[id]
	super.update_attacks(dt)
	build=all
	for id in build:
		if id not in NEW_WEAPONS:continue
		cooldowns[id]=cooldowns.get(id,0.0)-dt
		if cooldowns[id]>0:continue
		var target=nearest(player,320)
		if target==null and id not in ["axe","bed","tnt"]:continue
		var s=db.stats(id,build[id],evolved.has(id),items)
		var direction=player.direction_to(target.p) if target!=null else facing
		cooldowns[id]=s.interval
		animation.strike(self,id,direction)
		match id:
			"axe":
				for m in in_radius(player,s.radius):hurt(m,s.damage,player.direction_to(m.p))
				break_props(player,s.radius,s.damage)
				add_effect("axe_spin",player,.62 if evolved.has(id) else .34,{"radius":s.radius,"direction":direction,"return_damage":s.damage*.65 if evolved.has(id) else 0.0,"returned":false})
				sound("swing")
			"hoe":
				for j in range(int(s.count)):fire_projectile("hoe",player,direction.rotated(j*.18),s,evolved.has(id))
				sound("trident")
			"crossbow":
				for j in range(int(s.count)):fire_projectile("rocket" if evolved.has(id) else "bolt",player,direction.rotated((j-(s.count-1)/2)*.12),s,evolved.has(id))
				sound("arrow")
			"fishing":
				var targets=in_radius(player,s.range)
				targets.sort_custom(func(a,b):return player.distance_squared_to(a.p)<player.distance_squared_to(b.p))
				var caught=0
				for m in targets:
					if neutral(m):continue
					fire_projectile("hook",player,player.direction_to(m.p),s,evolved.has(id))
					caught+=1
					if caught>=s.count:break
				sound("trident")
			"bed","tnt":place_explosive(id,s)

func place_explosive(kind: String, s: Dictionary):
	var count=0
	for b in explosives:
		if b.kind==kind:count+=1
	if count>=(2 if kind=="bed" else 24):return
	var center=move_actor(player,facing*(42 if kind=="bed" else 12),7)
	var group=next_id()
	if kind=="bed":
		explosives.append({"kind":"bed","p":center,"v":Vector2.ZERO,"age":0.0,"fuse":-1.0,"stats":s.duplicate(),"group":group,"first":true,"launched":false})
	else:
		explosives.append(tnt_charge(center,s,group,true,1.5))
		if int(s.count)>1:tnt_groups.append({"anchor":center,"stats":s.duplicate(),"group":group,"age":0.0,"next":.32,"index":1,"remaining":int(s.count)-1})
		sound("hiss",.2)

func tnt_charge(at: Vector2, s: Dictionary, group: int, first: bool, fuse: float, child: bool=false) -> Dictionary:
	return {"kind":"tnt","p":at,"v":Vector2.ZERO,"age":0.0,"fuse":fuse,"stats":s.duplicate(),"group":group,"first":first,"launched":false,"child":child,"height":0.0,"lift":0.0}

func split_tnt(b: Dictionary):
	var aim: Vector2=b.v.normalized() if b.v.length()>5 else b.get("launch_dir",facing)
	var stats: Dictionary=b.stats.duplicate();stats.cluster=false;stats.damage*=.4;stats.radius*=.6
	for j in range(3):
		if explosives.size()>=24:break
		var dir=aim.rotated((j-1)*.65)
		var child=tnt_charge(b.p,stats,b.group,false,.45+j*.05,true)
		child.v=dir*125;child.height=b.height;child.lift=75;child.launched=true
		explosives.append(child)
	add_effect("tnt_split",b.p,.3,{"height":b.height})

func update_explosives(dt: float):
	for i in range(tnt_groups.size()-1,-1,-1):
		var g=tnt_groups[i];g.age+=dt
		while g.remaining>0 and g.age>=g.next:
			var spread=[-.12,.12,-.24,.24][(g.index-1)%4]
			var dir=facing.rotated(spread)
			var at=move_actor(g.anchor,dir*(19+g.index*3),4)
			if explosives.size()<24:
				var charge=tnt_charge(at,g.stats,g.group,false,maxf(.1,1.5-g.age+.8+g.index*.06))
				charge.launch_dir=dir
				explosives.append(charge);sound("hiss",.15)
			g.remaining-=1;g.index+=1;g.next+=.32
		if g.remaining<=0:tnt_groups.remove_at(i)
	for i in range(explosives.size()-1,-1,-1):
		var b=explosives[i]
		b.age+=dt
		b.p=move_actor(b.p,b.v*dt,4)
		b.v=b.v.move_toward(Vector2.ZERO,dt*45)
		if b.kind=="bed":
			if b.age>.65 and player.distance_to(b.p)<19:
				add_effect("foot_block",player,.85,{"direction":player.direction_to(b.p)})
				explode(b.p,b.stats.radius,b.stats.damage)
				explosives.remove_at(i)
			elif b.age>25:explosives.remove_at(i)
			continue
		if b.launched:
			b.height=maxf(0,b.height+b.lift*dt);b.lift-=300*dt
			if b.height<=0:b.lift=0
		b.fuse-=dt
		if b.fuse<=0:
			if b.first:
				for other in explosives:
					if other==b or other.kind!="tnt" or other.p.distance_to(b.p)>b.stats.radius:continue
					other.v=b.p.direction_to(other.p)*145
					if other.v.length_squared()<1:other.v=Vector2.RIGHT*145
					other.launch_dir=other.v.normalized()
					other.height=0;other.lift=120
					other.fuse=maxf(other.fuse,.72)
					other.launched=true
			if not b.first and not b.child and b.stats.get("cluster",false):split_tnt(b)
			explode(b.p,b.stats.radius,b.stats.damage)
			explosives.remove_at(i)

func fire_projectile(kind: String, p: Vector2, direction: Vector2, s: Dictionary, evolution: bool):
	var enemy_count=0
	for b in projectiles:
		if b.kind=="wither_skull":enemy_count+=1
	if kind=="wither_skull":
		if enemy_count>=430:return
	elif projectiles.size()-enemy_count>=int(db.data.projectile_cap):return
	projectiles.append({"kind":kind,"p":p,"origin":p,"dir":direction,"speed":s.speed,"damage":s.damage,"range":s.range,"radius":s.radius,"pierce":s.get("pierce",0),"distance":0.0,"hit":{},"returning":false,"evolved":evolution,"lightning":false,"life":s.get("life",6.5 if kind=="wither_skull" else 6.0),"age":0.0,"turn_age":0.0,"duration":s.get("duration",2.5),"turn":s.get("turn",0.0),"acceleration":s.get("acceleration",0.0),"orbit_owner":s.get("orbit_owner",-1),"orbit_angle":direction.angle(),"orbit_speed":s.get("orbit_speed",0.0)})

func update_projectiles(dt: float):
	var ordinary: Array=[]
	var custom: Array=[]
	for b in projectiles:
		if b.kind in ["hoe","bolt","rocket","hook","enemy_flame","wither_skull"]:custom.append(b)
		else:ordinary.append(b)
	projectiles=ordinary
	super.update_projectiles(dt)
	for b in custom:
		var old: Vector2=b.p
		b.age+=dt;b.life-=dt
		b.dir=b.dir.rotated(b.get("turn",0.0)*dt)
		b.speed=minf(165,b.speed+b.get("acceleration",0.0)*dt) if b.kind=="wither_skull" else b.speed
		if b.get("orbit_owner",-1)>=0:
			var owner=null
			for m in mobs:
				if m.id==b.orbit_owner and m.hp>0:owner=m;break
			if owner==null:continue
			b.orbit_angle+=b.orbit_speed*dt
			b.dir=Vector2.from_angle(b.orbit_angle)
			b.p=owner.p+b.dir*(42+minf(110,b.age*32))
		else:b.p+=b.dir*b.speed*dt
		b.distance+=b.speed*dt
		var dead=b.life<=0 or b.distance>=b.range
		if b.kind in ["enemy_flame","wither_skull"]:
			if Geometry2D.get_closest_point_to_segment(player,old,b.p).distance_to(player)<10:
				if b.kind=="enemy_flame":ignite(3);fire_damage(b.damage)
				else:damage_player(b.damage)
				dead=true
			if dead and b.kind=="wither_skull":
				add_effect("wither_impact",b.p,.6,{"radius":22.0})
		else:
			for m in in_radius((old+b.p)/2,old.distance_to(b.p)/2+6):
				if b.hit.has(m.id) or Geometry2D.get_closest_point_to_segment(m.p,old,b.p).distance_to(m.p)>m.radius+4:continue
				b.hit[m.id]=true
				match b.kind:
					"hoe":
						add_effect("hoe_spin",m.p,b.duration,{"radius":b.radius,"damage":b.damage,"tick":0.0,"evolved":b.evolved})
						dead=true
					"rocket":explode(m.p,b.radius,b.damage);dead=true
					"hook":
						hurt(m,b.damage)
						hook_target(m,b.evolved)
						dead=true
					"bolt":hurt(m,b.damage,b.dir);dead=b.hit.size()>b.pierce
				if dead:break
			if not dead:
				for obj in props:
					if obj.type=="pumpkin" and obj.hp>0 and not b.hit.has(obj.id) and Geometry2D.get_closest_point_to_segment(obj.p,old,b.p).distance_to(obj.p)<10:
						b.hit[obj.id]=true;obj.hp-=b.damage
						if obj.hp<=0:break_pumpkin(obj)
			if dead and b.kind=="rocket" and b.hit.is_empty():explode(b.p,b.radius,b.damage)
		if not dead:projectiles.append(b)

func update_effects(dt: float):
	for e in effects:
		if e.kind=="axe_spin" and e.get("return_damage",0)>0 and not e.returned and e.age+dt>=.3:
			e.returned=true
			for m in in_radius(player,e.radius):hurt(m,e.return_damage,player.direction_to(m.p))
			break_props(player,e.radius,e.return_damage);sound("swing")
	super.update_effects(dt)
	for e in effects:
		if e.kind!="hoe_spin":continue
		e.tick-=dt
		if e.tick<=0:
			e.tick+=.3
			for m in in_radius(e.p,e.radius):hurt(m,e.damage)
			break_props(e.p,e.radius,e.damage)

func break_props(at: Vector2, radius: float, damage: float):
	for p in props:
		if p.type=="pumpkin" and p.hp>0 and at.distance_to(p.p)<radius+7:
			p.hp-=damage
			if p.hp<=0:break_pumpkin(p)

func break_pumpkin(p: Dictionary):
	if p.get("has_heal",false):loot.append({"kind":"golden_carrot","p":p.p})
	add_effect("break",p.p,.3)
	sound("pot_break")

func update_hazards(dt: float):
	for i in range(hazards.size()-1,-1,-1):
		var h=hazards[i]
		h.wait-=dt
		if h.wait>0:continue
		if not h.get("triggered",false):
			h.triggered=true
			h.remaining=h.get("remaining",.1)
			h.tick=0.0
			add_effect("soul_eruption",h.p,.85,{"radius":h.radius})
			sound("wither_shoot",.08)
		h.remaining-=dt;h.tick-=dt
		if h.tick<=0:
			h.tick+=.2
			if player.distance_to(h.p)<h.radius:
				if h.get("fire",false):ignite(1.5);fire_damage(h.damage)
				else:damage_player(h.damage)
		if h.remaining<=0:hazards.remove_at(i)

func resolve_deaths():
	var boss_dead=false
	var corpse={}
	for m in mobs:
		if m.hp>0:continue
		if m.kind=="brute":loot.append({"kind":"chest","p":m.p,"born":time})
		if m.kind=="wither":boss_dead=true;corpse=m.duplicate(true)
	super.resolve_deaths()
	if boss_dead:
		stage="defeat"
		stage_age=0
		defeated_boss=corpse
		victory=true
		for pool in [mobs,projectiles,explosives,tnt_groups,hazards,effects]:pool.clear()
		player_burn=0
		player_wither=0;wither_tick=0
		rebuild_hit_grid()
		message=""
		message_timer=0
		sound("wither_death")

func apply_upgrade(id: String):
	if id=="ender_eye":pearl=true;portal_camera_focus=true;sound("pickup")
	else:super.apply_upgrade(id)

func discard(id: String) -> bool:
	if not super.discard(id):return false
	if id in ["bed","tnt"]:
		if id=="tnt":tnt_groups.clear()
		for i in range(explosives.size()-1,-1,-1):
			if explosives[i].kind==id:explosives.remove_at(i)
	if id in ["hoe","axe"]:
		for i in range(effects.size()-1,-1,-1):
			if effects[i].kind==id+"_spin":effects.remove_at(i)
	return true

func advance_nether_poses():
	for m in mobs:
		if m.stun>0 or m.pull_left>0:
			animation.set_pose(m.visual,"hurt",.08)
			continue
		if m.kind in ["brute","hoglin","zoglin"]:
			if m.phase=="windup":animation.set_pose(m.visual,"windup",(.7-m.timer)/.7*.16);m.visual_dir=m.charge
			elif m.phase=="charge":animation.set_pose(m.visual,"attack",fposmod(.65-m.timer,.09));m.visual_dir=m.charge
			elif m.phase=="rest":animation.set_pose(m.visual,"recover",(.9-m.timer)/.9*.24)
		elif m.kind in ["piglin_crossbow","blaze_nether"] and not neutral(m):
			if m.visual.shot_age<.14:animation.set_pose(m.visual,"attack",m.visual.shot_age)
			elif m.visual.shot_age<.4:animation.set_pose(m.visual,"recover",m.visual.shot_age-.14)
			elif m.timer>0 and m.timer<.5:animation.set_pose(m.visual,"windup",(.5-m.timer)/.5*.16)
			if m.visual.state in ["windup","attack","recover"]:m.visual_dir=m.p.direction_to(player)
		elif m.kind=="wither":
			if stage=="arrival":animation.set_pose(m.visual,"roar",maxf(0,stage_age-ghast.BURST)*.7)
			elif m.phase in ["volley","bombard","spiral"]:animation.set_pose(m.visual,"cast",(m.windup-m.timer)/m.windup*.6)
			elif m.phase in ["dash","rush"]:
				animation.set_pose(m.visual,"dash",(m.windup-m.timer)*.6)
				m.visual_dir=m.charge
			elif m.phase in ["roar","channel"]:animation.set_pose(m.visual,"roar",maxf(0,1.35-m.timer))
			elif m.phase=="recover":animation.set_pose(m.visual,"recover",(.7-m.timer)/.7*.24)

func terrain_factor(at: Vector2, boots: int=0) -> float:
	if stage!="survival" or soul_sand.is_empty():return 1.0
	var tile=Vector2i(at/16)
	if tile.x<0 or tile.y<0 or tile.x>=128 or tile.y>=128:return 1.0
	if not soul_sand[tile.y*128+tile.x]:return 1.0
	# Visible magma replaces the terrain beneath it.
	for patch in magma:
		var offset: Vector2=at-patch.p
		var cell=(offset/16).round()
		if absf(cell.x)<=2 and absf(cell.y)<=2 and (cell*16).length()<patch.radius:return 1.0
	return 1-.42*(1-.2*clampi(boots,0,5))

func movement_speed() -> float:
	return super.movement_speed()*terrain_factor(player,items.get("gold_boots",0))

func update_arena_camera(dt: float):
	if stage not in ["wither","defeat","portal","lighting","jump"]:return
	var anchor=defeated_boss.get("p",Vector2(1024,1030))
	for m in mobs:
		if m.kind=="wither":anchor=m.p;break
	var midpoint: Vector2=(player+anchor)/2+Vector2(0,-28)
	if portal_camera_focus and stage in ["portal","lighting","jump"]:
		midpoint=player.lerp(portal_position,.65)+Vector2(0,-18)
	# Stay at the midpoint while the hero fits comfortably; release only the
	# excess distance so the boss remains in view for as long as possible.
	var target=midpoint
	target.x=clampf(target.x,player.x-264,player.x+264)
	target.y=clampf(target.y,player.y-124,player.y+110)
	if arena_camera.distance_to(target)>5:
		arena_camera=arena_camera.lerp(target,1-exp(-dt*2.5))
	arena_camera=arena_camera.clamp(player-Vector2(292,150),player+Vector2(292,140))
