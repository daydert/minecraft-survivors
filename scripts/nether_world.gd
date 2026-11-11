extends "res://scripts/arsenal_world.gd"
## Chapter II is a solo world. No RPC, snapshot or cooperative rules enter here.
const PIGLINS=["piglin_sword","piglin_crossbow"]
const ARENA=Rect2(736,800,576,448)
const INTRO_DURATION=preload("res://scripts/ghast_intro.gd").DURATION
var ghast=preload("res://scripts/ghast_intro.gd").new()
var portal_camera_focus=false
var boss_hits=0
var transition_camera=Vector2.ZERO
var arena_camera=Vector2(1024,1040)
var soul_sand=PackedByteArray()
var encounter=preload("res://scripts/wither_encounter.gd").new()
## Version 2: the bastion opens at 6:00; holding it during the assault earns a chest.
var landmarks: Array=[]
var bastion: Dictionary={}

func chapter_number() -> int:return 2

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

	place_bastion()
	assign_healing()

func place_bastion():
	var rules: Dictionary=db.data.bastion
	var place=RandomNumberGenerator.new();place.seed=int(rng.seed)^0x6a51c3
	var angle=place.randf()*TAU
	var p=(player+Vector2.from_angle(angle)*float(rules.distance)).clamp(Vector2(260,260),Vector2(1788,1788))
	for i in range(props.size()-1,-1,-1):
		if props[i].type in ["rock","tree"] and props[i].p.distance_to(p)<130:
			var c=Vector2i(props[i].p/64.0)
			if solid_grid.has(c):solid_grid[c]=solid_grid[c].filter(func(s):return s.p!=props[i].p)
			blocked.erase(Vector2i(props[i].p/CELL))
			props.remove_at(i)
	magma=magma.filter(func(m):return m.p.distance_to(p)>150)
	for x in range(-66,67,12):
		var q=p+Vector2(x,-14)
		var c=Vector2i(q/64.0)
		if not solid_grid.has(c):solid_grid[c]=[]
		solid_grid[c].append({"p":q,"r":8.0});blocked[Vector2i(q/CELL)]=true
	bastion={"p":p,"state":"closed","timer":0.0,"wave":0.0,"brute":false}
	landmarks=[{"kind":"bastion","p":p,"id":next_id()}]
	update_flow()

func update_bastion(dt: float):
	if bastion.is_empty():return
	var rules: Dictionary=db.data.bastion
	match bastion.state:
		"closed":
			if time>=float(rules.open_at):
				bastion.state="open";message="Бастион открыт";message_timer=3;sound("warning")
		"open":
			if player.distance_to(bastion.p)<float(rules.trigger):
				bastion.state="assault";bastion.timer=float(rules.duration);bastion.wave=0.0
				message="Штурм бастиона";message_timer=3;sound("warning")
				for offset in rules.turrets:
					if spawn("blaze_nether",bastion.p+Vector2(offset[0],offset[1])):
						mobs.back().turret=true;mobs.back().aggro=999.0
		"assault":
			bastion.timer-=dt;bastion.wave-=dt
			if bastion.wave<=0:
				bastion.wave=float(rules.wave_every)
				for j in range(int(rules.wave_size)):
					var gate=bastion.p+Vector2(-80 if j%2==0 else 80,30+j*6)
					if spawn(PIGLINS[j%2],gate):mobs.back().aggro=999.0
			if not bastion.brute and bastion.timer<=float(rules.duration)*.5:
				bastion.brute=true
				if spawn("brute",bastion.p+Vector2(0,44)):mobs.back().aggro=999.0
			if bastion.timer<=0:
				bastion.state="won";message="Бастион взят";message_timer=3;run_progress.award("bastion")
				loot.append({"kind":"chest","p":bastion.p+Vector2(0,18),"born":time})
				for j in range(int(rules.reward_orbs)):drop_xp(bastion.p+Vector2.from_angle(j*2.4)*(20+j*3),8)
				sound("chest_open")

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
	if sword_step(dt, movement):return
	if state!="RUNNING":return
	track_progress(dt)
	clock+=dt
	stage_age+=dt
	if stage=="survival":time=minf(db.data.duration,time+dt)
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
	if stage=="survival":spawn_wave(dt);update_bastion(dt)
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
	update_regeneration(dt)
	if hp<=0:
		state="RESULT"
		victory=false
		sound("death")
		return
	match stage:
		"survival":
			if time>=db.data.duration:begin_arena();return
		"departure":
			if stage_age>=1.6:prepare_arena()
		"arrival":
			if stage_age>=INTRO_DURATION:
				stage="wither"
				stage_age=0
				invulnerable=.4
		"defeat":
			# The Wither goes up in a blast hot enough to melt the gear on Steve.
			if stage_age>=MELT_BLAST and stage_age-dt<MELT_BLAST:
				for id in ["explosion","wither_death","ghast_intro_burst"]:sound(id,.01)
				shake=.8
			for i in range(molten.size()):
				var at: float=MELT_START+i*MELT_STEP
				if stage_age>=at and stage_age-dt<at:sound("fire",.05)
				if stage_age>=at+.7 and stage_age-dt<at+.7:sound("ch4_poison" if i%2 else "potion_splash",.05)
			if stage_age>=melt_done() and stage_age-dt<melt_done():
				build={};items={};evolved={};weapon_visuals.clear();attack_visuals.clear()
			if stage_age>=melt_done()+1.0:
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
	time=db.data.duration
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
	landmarks.clear()
	bastion={}
	hit_grid.clear()
	solid_grid.clear()
	blocked.clear()
	update_flow()
	spawn("wither",Vector2(1024,1030))
	message=""
	message_timer=0

func move_mobs(dt: float):
	damage_owner="fire"
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
			if m.get("turret",false):speed=0
			elif distance<95:direction=-old.direction_to(player)
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

func break_pumpkin(p: Dictionary):
	if p.get("has_heal",false):loot.append({"kind":"golden_carrot","p":p.p})
	add_effect("break",p.p,.3)
	sound("pot_break")

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
	return 1-rule("soul_sand_slow")*(1-rule("gold_boots_relief")*clampi(boots,0,5))

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

func reset(seed_value: int = 0):
	portal_camera_focus=false
	molten.clear()
	boss_hits=0
	transition_camera=Vector2.ZERO
	ghast.reset()
	super.reset(seed_value)
	arena_camera=Vector2(1024,1040)
	soul_sand.resize(128*128)
	soul_sand.fill(0)
	var terrain: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/nether_terrain.json"))
	for cell in terrain.soul_sand_cells:soul_sand[int(cell)]=1

func spawn(kind: String, at = null) -> bool:
	if kind in ["piglin_crossbow","blaze_nether"]:
		var count=0
		for m in mobs:
			if m.kind==kind and m.hp>0:count+=1
		if count>=10:return false
	if not super.spawn(kind,at):return false
	var m: Dictionary=mobs.back()
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

func knock_factor(m: Dictionary) -> float:
	return .12 if m.kind=="wither" else super.knock_factor(m)

func hurt(m: Dictionary, amount: float, push: Vector2 = Vector2.ZERO):
	if m.hp<=0:return
	if m.kind in PIGLINS or m.kind=="zombified_piglin":
		for other in in_radius(m.p,130):
			if other.kind in PIGLINS or other.kind=="zombified_piglin":other.aggro=maxf(4,14-2*items.get("gold_boots",0))
		m.aggro=maxf(4,14-2*items.get("gold_boots",0))
	if m.kind=="wither":boss_hits+=1
	super.hurt(m,amount,push)

func sound(id: String, gap: float = .04):
	var aliases={"hurt_blaze_nether":"hurt_blaze","hurt_piglin_sword":"hurt_piglin","hurt_piglin_crossbow":"hurt_piglin","hurt_brute":"hurt_piglin_brute"}
	super.sound(aliases.get(id,id),gap)

func resolve_deaths():
	var boss_dead=false
	var corpse={}
	for m in mobs:
		if m.hp>0:continue
		if m.kind=="brute":loot.append({"kind":"chest","p":m.p,"born":time})
		if m.kind=="wither":boss_dead=true;corpse=m.duplicate(true)
	super.resolve_deaths()
	if boss_dead:
		molten.clear()
		for id in build:molten.append({"id":id,"evolved":evolved.has(id)})
		for id in items:molten.append({"id":id,"evolved":false})
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

const MELT_BLAST:=1.4
const MELT_START:=2.3
const MELT_STEP:=.32
## What Steve carried when the Wither blew: drawn melting in the inventory.
var molten: Array=[]
func melt_done() -> float:return MELT_START+maxi(0,molten.size()-1)*MELT_STEP+1.3

func apply_upgrade(id: String):
	if id=="ender_eye":pearl=true;portal_camera_focus=true;sound("pickup")
	else:super.apply_upgrade(id)
