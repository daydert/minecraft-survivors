class_name SurvivorWorld
extends RefCounted

const SIZE = 2048.0
const CELL = 32
const GRID = 64
const VIEW = Vector2(640, 360)
var db = GameData.new()
var animation = preload("res://scripts/animation.gd").new()
var finale=preload("res://scripts/chapter_finale.gd").new()
var player_visual: Dictionary = {}
## Chapter V core: weapons and items level past their limits, the upgrade table repeating.
var overcap := false
## Eye of Ender IV: two more options above and below the centre card.
## Eye of Ender V: a small chance that an offered weapon comes already evolved.
var side_choices: Array = []
var evolved_offer: Dictionary = {}
const EYE_EVOLVED_CHANCE := .04
var attack_visuals: Dictionary = {}
var weapon_visuals: Dictionary = {}
var rng = RandomNumberGenerator.new()
var state = "MENU"
var time = 0.0
var clock = 0.0
var player = Vector2(1024, 1024)
var facing = Vector2.DOWN
var hp = 20.0
var invulnerable = 0.0
var xp = 0
var level = 1
var kills = 0
var score = 0
var build = {"sword":1}
var items = {}
var evolved = {}
var cooldowns = {}
var mobs: Array = []
var projectiles: Array = []
var orbs: Array = []
var loot: Array = []
var props: Array = []
var effects: Array = []
var particles: Array = []
var pixels: Array = []
var tasks: Array = []
var choices: Array = []
var sounds: Array = []
var events_done = {}
var pending_events: Array = []
var spawn_credit = 0.0
var uid = 0
var hit_grid = {}
var solid_grid = {}
var blocked = {}
var flow = PackedInt32Array()
var flow_cell = Vector2i(-1, -1)
var flow_timer = 0.0
var poison_timer = 0.0
var victory = false
var chest_reward = {}
var chest_delay = 0.0
var pending_chest = {}
var shake = 0.0
var moved = 0.0
var player_moving = false
var message = ""
var message_timer = 0.0
var sound_times = {}
var mob_multiplier = 1

func _init(seed_value: int = 724):
	rng.seed = seed_value
	reset(seed_value)
	state = "MENU"

func reset(seed_value: int = 0):
	finale.reset()
	overcap = false
	if seed_value: rng.seed = seed_value
	else: rng.randomize()
	state = "RUNNING"
	player_visual = animation.actor()
	attack_visuals.clear()
	weapon_visuals.clear()
	time = 0.0
	clock = 0.0
	player = Vector2(1024, 1024)
	facing = Vector2.DOWN
	hp = float(db.data.player_hp)
	invulnerable = 0.0
	xp = 0
	level = 1
	kills = 0
	score = 0
	build = {"sword":1}
	items = {}
	evolved = {}
	cooldowns = {"sword":0.35}
	for arr in [mobs, projectiles, orbs, loot, props, effects, particles, pixels, tasks, choices, sounds, pending_events]: arr.clear()
	events_done.clear()
	spawn_credit = 0.0
	uid = 0
	hit_grid.clear()
	solid_grid.clear()
	blocked.clear()
	flow_timer = 0
	poison_timer = 0
	flow_cell = Vector2i(-1, -1)
	victory = false
	chest_reward = {}
	pending_chest = {}
	chest_delay = 0
	shake = 0
	moved = 0
	player_moving = false
	message = ""
	message_timer = 0
	sound_times.clear()
	make_map()
	update_flow()

func camera() -> Vector2:
	if finale.active:return finale.camera(self)
	return player.clamp(VIEW / 2.0, Vector2.ONE * SIZE - VIEW / 2.0)

func visible(p: Vector2, pad: float = 0) -> bool:
	return Rect2(camera() - VIEW / 2.0 - Vector2.ONE * pad, VIEW + Vector2.ONE * pad * 2).has_point(p)

func sound(id: String, gap: float = 0.04):
	if clock - sound_times.get(id, -100.0) >= gap:
		sounds.append(id)
		sound_times[id] = clock

func make_map():
	# Clusters stay far apart: most of the arena consists of open, readable grass.
	for cy in range(1, 8):
		for cx in range(1, 8):
			var center = Vector2(cx * 256 + rng.randf_range(-40, 40), cy * 256 + rng.randf_range(-40, 40))
			if center.distance_to(player) < 135: continue
			for j in range(rng.randi_range(2, 4)):
				var p = center + Vector2(rng.randf_range(-30, 30), rng.randf_range(-26, 26))
				add_prop("tree" if rng.randf() < 0.72 else "rock", p)
	for i in range(12):
		var a = TAU * i / 12.0
		var p = player + Vector2.from_angle(a) * (130 + i % 3 * 94)
		props.append({"type":"pumpkin", "p":p, "hp":8.0, "id":next_id(), "radius":7.0})
	for i in range(28):
		props.append({"type":"stump" if i % 3 else "flowers", "p":Vector2(rng.randf_range(64, 1984),rng.randf_range(64, 1984)), "hp":-1.0, "id":next_id(), "radius":0.0})

func add_prop(kind: String, p: Vector2):
	var r = 8.0 if kind == "tree" else 11.0
	props.append({"type":kind, "p":p, "hp":-1.0, "radius":r, "id":next_id()})
	var c = Vector2i(p / 64.0)
	if not solid_grid.has(c): solid_grid[c] = []
	solid_grid[c].append({"p":p, "r":r})
	blocked[Vector2i(p / CELL)] = true

func next_id() -> int:
	uid += 1
	return uid

func nearby_solids(p: Vector2) -> Array:
	var list: Array = []
	var c = Vector2i(p / 64.0)
	for y in range(c.y - 1, c.y + 2):
		for x in range(c.x - 1, c.x + 2):
			list.append_array(solid_grid.get(Vector2i(x,y), []))
	return list

func free_at(p: Vector2, radius: float = 6) -> bool:
	if p.x < 24 + radius or p.y < 24 + radius or p.x > SIZE - 24 - radius or p.y > SIZE - 24 - radius: return false
	for s in nearby_solids(p):
		if p.distance_squared_to(s.p) < pow(radius + s.r, 2): return false
	return true

func move_actor(p: Vector2, v: Vector2, radius: float) -> Vector2:
	var q = (p + v).clamp(Vector2.ONE * (25 + radius), Vector2.ONE * (SIZE - 25 - radius))
	for s in nearby_solids(q):
		var off: Vector2 = q - s.p
		var r: float = radius + s.r
		if off.length_squared() < r * r:
			q = s.p + off.normalized() * r if off.length_squared() > 0.01 else q + Vector2.RIGHT * r
	return q

func update_flow():
	flow.resize(GRID * GRID)
	flow.fill(-1)
	flow_cell = Vector2i(player / CELL)
	var start = flow_cell.y * GRID + flow_cell.x
	flow[start] = 0
	var queue = PackedInt32Array([start])
	var head = 0
	while head < queue.size():
		var index = queue[head]
		head += 1
		var c = Vector2i(index % GRID, index / GRID)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n = c + d
			if n.x < 1 or n.y < 1 or n.x >= GRID - 1 or n.y >= GRID - 1: continue
			var k = n.y * GRID + n.x
			if flow[k] >= 0 or blocked.has(n): continue
			flow[k] = flow[index] + 1
			queue.append(k)

func navigation(p: Vector2) -> Vector2:
	var c = Vector2i(p / CELL).clamp(Vector2i.ONE, Vector2i(62,62))
	if not blocked.has(Vector2i((p + p.direction_to(player) * 28) / CELL)):
		return p.direction_to(player)
	var best = flow[c.y * GRID + c.x]
	var target = player
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n = c + d
		var v = flow[n.y * GRID + n.x]
		if v >= 0 and (v < best or best < 0):
			best = v
			target = Vector2(n * CELL) + Vector2.ONE * CELL / 2
	return p.direction_to(target)

func normal_count() -> int:
	var count = 0
	for m in mobs:
		if m.hp > 0 and m.kind not in ["elite", "ravager"]: count += 1
	return count

func spawn(kind: String, at = null) -> bool:
	if kind not in ["elite", "ravager"] and normal_count() >= int(db.data.mob_cap) * mob_multiplier: return false
	if kind == "skeleton":
		var count = 0
		for m in mobs:
			if m.kind == "skeleton" and m.hp > 0: count += 1
		if count >= 12 * mob_multiplier: return false
	var p = Vector2.ZERO
	if at != null: p = at
	else:
		var found = false
		var cam = camera()
		for attempt in range(12):
			var side = rng.randi_range(0,3)
			var margin = rng.randf_range(32,80)
			if side < 2:
				p = cam + Vector2((320 + margin) * (-1 if side == 0 else 1), rng.randf_range(-180,180))
			else:
				p = cam + Vector2(rng.randf_range(-320,320), (180 + margin) * (-1 if side == 2 else 1))
			var cell = Vector2i(p / CELL)
			if cell.x < 1 or cell.y < 1 or cell.x >= 63 or cell.y >= 63: continue
			if free_at(p, 22 if kind == "ravager" else 10) and flow[cell.y * GRID + cell.x] >= 0:
				found = true
				break
		if not found: return false
	var def = db.data.mobs[kind]
	var special = kind in ["elite", "ravager"]
	var health = def.hp * (1.0 if special else 1.0 + 0.08 * floor(time / 60))
	mobs.append({"id":next_id(),"kind":kind,"p":p,"dir":Vector2.DOWN,"hp":health,"max_hp":health,"speed":float(def.speed),"damage":def.damage * (1.0 if special else 1.0 + 0.04 * floor(time / 60)),"xp":int(def.xp),"radius":float(def.radius),"timer":rng.randf_range(1.5,3),"fuse":-1.0,"flash":0.0,"burn":0.0,"burn_tick":0.5,"phase":"walk","charge":Vector2.ZERO,"animation":rng.randf() * 9,"knock":Vector2.ZERO,"visual":animation.actor(),"moving":true,"visual_dir":Vector2.DOWN})
	mobs.back().visual.gait=mobs.back().animation
	if kind in ["elite", "ravager"]:
		message = "РАЗОРИТЕЛЬ" if kind == "ravager" else "Зомби в железной броне"
		message_timer = 3
		sound("warning")
	return true

func rebuild_hit_grid():
	hit_grid.clear()
	for m in mobs:
		if m.hp <= 0: continue
		var c = Vector2i(m.p / CELL)
		if not hit_grid.has(c): hit_grid[c] = []
		hit_grid[c].append(m)

func in_radius(p: Vector2, radius: float) -> Array:
	var result: Array = []
	var a = Vector2i((p - Vector2.ONE * (radius + 24)) / CELL)
	var b = Vector2i((p + Vector2.ONE * (radius + 24)) / CELL)
	for y in range(a.y,b.y + 1):
		for x in range(a.x,b.x + 1):
			for m in hit_grid.get(Vector2i(x,y), []):
				if m.hp > 0 and p.distance_squared_to(m.p) <= pow(radius + m.radius, 2): result.append(m)
	return result

func nearest(p: Vector2, radius: float = 260):
	var target = null
	var best = radius * radius
	for m in in_radius(p,radius):
		var dist = p.distance_squared_to(m.p)
		if dist < best:
			best = dist
			target = m
	if target==null and finale.active and finale.phase in ["storm","inferno"] and p.distance_to(finale.CENTER)<radius:
		return {"p":finale.CENTER,"id":-1}
	return target

func line_clear(a: Vector2, b: Vector2) -> bool:
	var steps = maxi(1, int(a.distance_to(b) / 16))
	for i in range(1, steps):
		if blocked.has(Vector2i(a.lerp(b,float(i) / steps) / CELL)): return false
	return true

func step(dt: float, movement: Vector2 = Vector2.ZERO):
	if state=="FINALE":
		clock+=dt
		finale.step(self,dt,movement)
		return
	if state != "RUNNING": return
	time += dt
	clock += dt
	invulnerable = maxf(0, invulnerable - dt)
	shake = maxf(0, shake - dt)
	message_timer = maxf(0, message_timer - dt)
	player_moving = movement.length_squared() > 0
	var old_player=player
	if player_moving:
		movement = movement.limit_length()
		facing = movement.normalized()
		player = move_actor(player, movement * db.data.player_speed * (1 + 0.08 * items.get("sugar",0)) * dt, 6)
		moved += dt
	player_visual.travel=player.distance_to(old_player)
	player_moving=player_visual.travel>0.0001
	flow_timer -= dt
	if flow_timer <= 0 and flow_cell != Vector2i(player / CELL):
		update_flow()
		flow_timer = 0.2
	spawn_wave(dt)
	move_mobs(dt)
	rebuild_hit_grid()
	update_attacks(dt)
	update_projectiles(dt)
	update_effects(dt)
	resolve_deaths()
	pickup(dt)
	update_particles(dt)
	animation.advance(self,dt)
	# Ordinary deaths still end a run. Surviving 12:00 starts the chapter finale.
	if hp <= 0:
		state = "RESULT"
		victory = false
		sound("death")
		return
	if time >= float(db.data.duration):
		finale.begin(self)
		return
	if xp >= db.required_xp(level): next_level()
	elif not pending_chest.is_empty(): open_chest(pending_chest)

func spawn_wave(dt: float):
	for i in range(db.data.events.size()):
		var e = db.data.events[i]
		if time >= e.at and not events_done.has(i):
			events_done[i] = true
			for copy in range(mob_multiplier): pending_events.append(e.type)
	if not pending_events.is_empty() and spawn(pending_events[0]): pending_events.pop_front()
	if time < 2: return
	var wave = db.wave(time)
	spawn_credit += wave.rate * dt * mob_multiplier
	while spawn_credit >= 1:
		spawn_credit -= 1
		if normal_count() >= int(db.data.mob_cap) * mob_multiplier: continue
		var roll = rng.randf()
		for kind in wave.weights:
			roll -= wave.weights[kind]
			if roll <= 0:
				spawn(kind)
				break

func move_mobs(dt: float):
	for m in mobs:
		if m.hp <= 0: continue
		select_mob_target(m.p)
		m.animation += dt
		m.flash = maxf(0, m.flash - dt)
		if m.burn > 0:
			m.burn -= dt
			m.burn_tick -= dt
			if m.burn_tick <= 0:
				m.burn_tick += 0.5
				hurt(m, burn_damage(m), Vector2.ZERO)
		if m.hp <= 0: continue
		var p: Vector2 = m.p
		var distance = p.distance_to(player)
		var direction = navigation(p)
		var speed: float = m.speed
		m.timer -= dt
		if m.kind == "skeleton":
			if distance < 120: direction = -p.direction_to(player)
			elif distance < 180 and line_clear(p,player): speed = 0
			if m.timer <= 0 and distance >= 120 and visible(p, -8) and distance <= 220 and line_clear(p,player):
				fire_projectile("enemy_arrow", p, p.direction_to(player), {"speed":110,"damage":m.damage,"range":220,"radius":3,"pierce":0}, false)
				m.visual.shot_age = 0.0
				sound("arrow",0.09)
				m.timer = 3
			elif m.timer <= 0: m.timer = 0
			if distance >= 120 and m.timer < 0.5 and visible(p): speed = 0
		if m.kind == "creeper":
			if m.fuse < 0 and distance <= 24:
				m.fuse = 0.9
				sound("hiss", 0.15)
			if m.fuse >= 0:
				speed = 0
				m.fuse -= dt
				if m.fuse <= 0:
					add_effect("enemy_explosion", p, 0.38, {"radius":36.0,"direction":m.dir})
					damage_area(p,42,6.0,Vector2.ZERO,true)
					m.hp = 0
					shake = 0.17
					sound("explosion",0.1)
		if m.kind in ["slime","small_slime"]:
			speed *= 2.8 if fmod(m.animation, 1.1) < 0.35 else 0.15
		if m.kind == "ravager":
			if m.phase == "walk" and m.timer <= 0:
				m.phase = "windup"
				m.timer = 0.8
				m.charge = p.direction_to(player)
				sound("warning",0.5)
			elif m.phase == "windup":
				speed = 0
				if m.timer <= 0:
					m.phase = "charge"
					m.timer = 1.2
			elif m.phase == "charge":
				direction = m.charge
				speed = 130
				if m.timer <= 0:
					m.phase = "rest"
					m.timer = 1
			elif m.phase == "rest":
				speed = 0
				if m.timer <= 0:
					m.phase = "walk"
					m.timer = 3.5 if m.hp <= m.max_hp * 0.5 else 5.0
		if m.kind=="vindicator":
			if m.phase=="walk" and m.timer<=0 and distance<32:
				m.phase="windup"
				m.timer=.5
				m.charge=p.direction_to(player)
			elif m.phase=="windup":
				speed=0
				if m.timer<=0:
					m.phase="attack"
					m.timer=.14
					m.visual.shot_age=0
					add_effect("vindicator_slash",p,.2,{"direction":m.charge,"radius":32.0})
					sound("swing",.15)
					damage_area(p,32,m.damage,m.charge)
			elif m.phase=="attack":
				speed=60
				direction=m.charge
				if m.timer<=0:
					m.phase="recover"
					m.timer=.7
			elif m.phase=="recover":
				speed=0
				if m.timer<=0:
					m.phase="walk"
					m.timer=.4
		m.dir = direction
		m.p = move_actor(p, (direction * speed + m.knock) * dt, m.radius)
		m.moving = m.p.distance_squared_to(p)>0.0001
		m.visual.travel=m.p.distance_to(p)
		m.knock = m.knock.move_toward(Vector2.ZERO, dt * 400)
		if m.hp > 0 and m.kind not in ["creeper","vindicator"]:
			damage_area(m.p,m.radius+6,6 if m.kind == "ravager" and m.phase == "charge" else m.damage)

# Single-player defaults; the cooperative world supplies per-player contexts.
func select_mob_target(_at: Vector2):
	pass

func select_attack_owner(_attack: Dictionary):
	pass

func burn_damage(_mob: Dictionary) -> float:
	return 2 * (1 + 0.1 * items.get("blaze",0))

func damage_area(at: Vector2, radius: float, amount: float, direction: Vector2 = Vector2.ZERO, inclusive: bool = false):
	var distance = at.distance_to(player)
	if (distance <= radius if inclusive else distance < radius) and (direction == Vector2.ZERO or direction.dot(at.direction_to(player)) > .35):
		damage_player(amount)

func enemy_arrow_hit(a: Vector2, b: Vector2, amount: float) -> bool:
	if Geometry2D.get_closest_point_to_segment(player,a,b).distance_to(player) < 9:
		damage_player(amount)
		return true
	return false

func damage_player(amount: float):
	if invulnerable > 0 or hp <= 0: return
	hp -= maxf(1, amount - 0.2 * items.get("armor",0))
	invulnerable = 0.65
	player_visual.hurt = 0.12
	shake = 0.12
	sound("hurt",0.15)
	add_effect("player_hit", player, 0.22)

func hurt(m: Dictionary, amount: float, push: Vector2 = Vector2.ZERO):
	if m.hp <= 0: return
	m.hp -= amount
	m.flash = 0.07
	m.visual.hurt = 0.12
	if visible(m.p): emit_pixels("impact",m.p+Vector2(0,-9),3,push)
	m.knock = push * (18 if m.kind == "ravager" else 65)
	add_effect("damage", m.p + Vector2(0,-20), 0.5, {"amount":int(ceil(amount))})
	if visible(m.p): sound("hurt_"+({"elite":"zombie","small_slime":"slime"}.get(m.kind,m.kind)),0.1)

func update_attacks(dt: float):
	for i in range(tasks.size()-1,-1,-1):
		var task = tasks[i]
		task.wait -= dt
		if task.wait > 0: continue
		tasks.remove_at(i)
		if task.kind == "sword": swing(task.direction,task.stats)
		elif task.kind == "fire":
			animation.strike(self,"fire",task.direction)
			fire_projectile("fire",player,task.direction,task.stats,false)
			sound("fire",0.1)
	for id in build:
		cooldowns[id] = cooldowns.get(id, 0.0) - dt
		if cooldowns[id] > 0: continue
		var s = db.stats(id,build[id],evolved.has(id),items)
		var target = nearest(player)
		if id != "sword" and target == null: continue
		cooldowns[id] = s.interval
		var direction: Vector2 = player.direction_to(target.p) if target != null else facing
		match id:
			"sword":
				swing(facing,s)
				if s.back > 0: tasks.append({"wait":0.15,"kind":"sword","direction":-facing,"stats":s})
			"bow":
				animation.strike(self,id,direction)
				for i in range(int(s.count)):
					var angle = 0.0 if s.count == 1 else deg_to_rad((i - (s.count - 1) / 2.0) * (12 if s.count == 2 else 10))
					fire_projectile("arrow",player,direction.rotated(angle),s,evolved.has(id))
				sound("arrow",0.09)
			"trident":
				animation.strike(self,id,direction)
				for i in range(int(s.count)):
					fire_projectile("trident",player,direction.rotated(deg_to_rad(i * 12)),s,evolved.has(id))
				sound("trident")
			"fire":
				animation.strike(self,id,direction)
				fire_projectile("fire",player,direction,s,false)
				sound("fire",0.1)
				if s.count > 1: tasks.append({"wait":0.2,"kind":"fire","direction":direction,"stats":s})
			"potion":
				animation.strike(self,id,direction)
				for i in range(int(s.count)):
					var point: Vector2 = target.p + Vector2(i * 30, i * -15)
					add_effect("bottle",player,0.55,{"end":point,"stats":s})
				sound("potion_throw")
			"fangs":
				animation.strike(self,id,direction)
				var hit = {}
				for row in range(int(s.rows)):
					var dir = direction.rotated(deg_to_rad(row * 25))
					for j in range(int(s.count)):
						add_effect("fangs",player + dir * (20 + j * 20),0.65 + j * 0.1,{"delay":j*0.1,"radius":s.radius,"damage":s.damage,"hit":hit,"dir":dir})
				sound("fangs")

func swing(direction: Vector2, s: Dictionary):
	animation.strike(self,"sword",direction)
	if evolved.has("sword"): emit_pixels("ember",player+direction*s.radius*0.7,4,direction)
	add_effect("swing",player,0.22,{"direction":direction,"radius":s.radius,"evolved":evolved.has("sword")})
	for m in in_radius(player,s.radius):
		if direction.dot(player.direction_to(m.p)) >= cos(deg_to_rad(60)):
			hurt(m,s.damage,player.direction_to(m.p))
	for p in props:
		if p.type == "pumpkin" and p.hp > 0 and player.distance_to(p.p) <= s.radius + 7 and direction.dot(player.direction_to(p.p)) >= 0.5:
			p.hp -= s.damage
			if p.hp <= 0: break_pumpkin(p)
	sound("swing",0.08)

func fire_projectile(kind: String, p: Vector2, direction: Vector2, s: Dictionary, evolution: bool):
	if projectiles.size() >= int(db.data.projectile_cap): return
	projectiles.append({"kind":kind,"p":p,"origin":p,"dir":direction,"speed":s.speed,"damage":s.damage,"range":s.range,"radius":s.radius,"pierce":s.get("pierce",0),"distance":0.0,"hit":{},"returning":false,"evolved":evolution,"lightning":false,"life":6.0,"age":0.0,"turn_age":0.0})

func update_projectiles(dt: float):
	for i in range(projectiles.size()-1,-1,-1):
		var b = projectiles[i]
		select_attack_owner(b)
		var old: Vector2 = b.p
		b.age += dt
		if b.returning: b.turn_age += dt
		b.life -= dt
		if b.kind == "trident" and b.returning: b.dir = old.direction_to(player)
		b.p += b.dir * b.speed * dt
		b.distance += b.speed * dt
		var dead = b.life <= 0
		if b.kind == "enemy_arrow":
			if enemy_arrow_hit(old,b.p,b.damage): dead = true
		else:
			for m in in_radius((old + b.p) / 2,old.distance_to(b.p)/2 + 5):
				if b.hit.has(m.id) or Geometry2D.get_closest_point_to_segment(m.p,old,b.p).distance_to(m.p) > m.radius + 3: continue
				b.hit[m.id] = true
				if b.kind == "fire":
					explode(b.p,b.radius,b.damage)
					dead = true
					break
				hurt(m,b.damage,b.dir)
				if b.evolved and b.kind == "arrow":
					m.burn = 3.0
					if b.has("owner"): m.burn_owner = b.owner
				if b.evolved and b.kind == "trident" and not b.returning and not b.lightning:
					b.lightning = true
					var r = 36 * (1 + 0.1 * items.get("amethyst",0))
					for n in in_radius(m.p,r): hurt(n,30 * (1 + 0.1 * items.get("blaze",0)))
					add_effect("lightning",m.p,0.35,{"radius":r})
					sound("lightning",0.1)
				if b.kind == "arrow" and b.hit.size() > b.pierce:
					dead = true
					break
			for p in props:
				if dead or p.type != "pumpkin" or p.hp <= 0 or b.hit.has(p.id): continue
				if Geometry2D.get_closest_point_to_segment(p.p,old,b.p).distance_to(p.p) <= 9:
					b.hit[p.id] = true
					p.hp -= b.damage
					if p.hp <= 0: break_pumpkin(p)
					if b.kind == "fire": explode(b.p,b.radius,b.damage)
					if b.kind in ["arrow","fire"]: dead = true
		if b.kind == "trident":
			if not b.returning and b.distance >= b.range:
				b.returning = true
				b.hit = {}
				emit_pixels("return",b.p+Vector2(0,-9),4,-b.dir)
			if b.returning and b.p.distance_to(player) < 10:
				dead = true
				emit_pixels("return",player+Vector2(0,-8),3,b.dir)
		elif b.distance >= b.range:
			if b.kind == "fire" and not dead: explode(b.p,b.radius,b.damage)
			dead = true
		if dead: projectiles.remove_at(i)

func explode(p: Vector2, radius: float, amount: float):
	for m in in_radius(p,radius): hurt(m,amount,p.direction_to(m.p))
	for obj in props:
		if obj.type == "pumpkin" and obj.hp > 0 and p.distance_to(obj.p) < radius + 7:
			obj.hp -= amount
			if obj.hp <= 0: break_pumpkin(obj)
	add_effect("explosion",p,0.4,{"radius":radius})
	sound("explosion",0.1)
	shake = 0.13

func add_effect(kind: String, p: Vector2, life: float, extra: Dictionary = {}):
	if effects.size() >= effect_cap(): return
	var e = {"kind":kind,"p":p,"life":life,"total":life,"age":0.0}
	e.merge(extra,true)
	effects.append(e)

func effect_cap() -> int:
	return 320*mob_multiplier

func update_effects(dt: float):
	poison_timer -= dt
	var poison: Dictionary = {}
	for i in range(effects.size()-1,-1,-1):
		var e = effects[i]
		select_attack_owner(e)
		e.life -= dt
		e.age += dt
		if e.kind == "bottle" and e.life <= 0:
			add_effect("cloud",e.end,e.stats.get("duration",3.0),{"radius":e.stats.radius,"damage":e.stats.damage})
			emit_pixels("glass",e.end,10,Vector2.UP)
			sound("potion")
		if e.kind == "fangs" and e.age >= e.delay:
			if e.age-dt<e.delay: sound("fangs",0.08)
			for m in in_radius(e.p,e.radius):
				if not e.hit.has(m.id):
					e.hit[m.id] = true
					hurt(m,e.damage)
		if e.kind == "cloud" and poison_timer <= 0:
			for m in in_radius(e.p,e.radius):
				poison[m.id] = {"mob":m,"damage":maxf(e.damage,poison.get(m.id,{"damage":0}).damage)}
		if e.life <= 0: effects.remove_at(i)
	if poison_timer <= 0:
		poison_timer += 0.5
		for dot in poison.values(): hurt(dot.mob,dot.damage)

func resolve_deaths():
	var split: Array = []
	for i in range(mobs.size()-1,-1,-1):
		var m = mobs[i]
		if m.hp > 0: continue
		kills += 1
		if m.xp > 0: drop_xp(m.p,m.xp)
		if m.kind in ["elite","ravager"]: loot.append({"kind":"chest","p":m.p,"born":time})
		if m.kind == "slime":
			split.append(m.p + Vector2(-8,0))
			split.append(m.p + Vector2(8,0))
		if visible(m.p,24):
			emit_pixels("smoke",m.p+Vector2(0,-12),6,Vector2.UP)
			for j in range(6):
				if particles.size() >= int(db.data.particle_cap): break
				particles.append({"p":m.p + Vector2(0,-8),"v":Vector2(rng.randf_range(-32,32),rng.randf_range(-50,5)),"life":0.3,"color":Color("619d69") if m.kind not in ["skeleton","ravager"] else Color("b6b5a4"),"size":3.0})
		mobs.remove_at(i)
	for p in split: spawn("small_slime",p)

func break_pumpkin(p: Dictionary):
	loot.append({"kind":"apple" if rng.randf() < 0.35 else "emerald", "p":p.p})
	add_effect("break",p.p,0.3)
	sound("break")

func drop_xp(p: Vector2, value: int):
	if value <= 0: return
	if orbs.size() >= int(db.data.orb_cap):
		var nearest_orb = orbs[0]
		for o in orbs:
			if p.distance_squared_to(o.p) < p.distance_squared_to(nearest_orb.p): nearest_orb = o
		nearest_orb.value += value
	else: orbs.append({"p":p,"value":value,"attracted":false})

func pickup(dt: float):
	var radius: float = pickup_radius()
	for i in range(orbs.size()-1,-1,-1):
		var o = orbs[i]
		if not can_pickup_orb(o): continue
		var distance = o.p.distance_to(player)
		if distance <= radius: o.attracted = true
		if o.attracted: o.p = o.p.move_toward(player,dt * orb_pull_speed())
		if o.p.distance_to(player) < 7:
			xp += o.value
			orbs.remove_at(i)
			sound("xp",0.09)
	for i in range(loot.size()-1,-1,-1):
		var o = loot[i]
		pull_healing_loot(o,dt)
		if o.p.distance_to(player) > 10: continue
		if o.kind == "chest":
			if not pending_chest.is_empty(): continue
			pending_chest = o.duplicate()
		else: apply_upgrade(o.kind)
		loot.remove_at(i)

## Virtual pickup policy: solo campaign can tune its item without changing
## legacy coop collection. No random numbers are consumed by attraction.
func pickup_radius() -> float:return 24.0*(1.0+.3*items.get("hopper",0))
func orb_pull_speed() -> float:return 190.0
func pull_healing_loot(_loot: Dictionary,_dt: float):pass

func can_pickup_orb(_orb: Dictionary) -> bool:
	return true

func update_particles(dt: float):
	for pool in [particles,pixels]:
		for i in range(pool.size()-1,-1,-1):
			var p = pool[i]
			p.life -= dt
			p.age = p.get("age",0.0)+dt
			p.p += p.v * dt
			p.v.y += -24*dt if p.get("kind","")=="smoke" else 100*dt
			if p.life <= 0: pool.remove_at(i)

func emit_pixels(kind: String, at: Vector2, count: int, direction: Vector2):
	# Presentation randomness is derived from IDs, leaving the gameplay RNG intact.
	if not visible(at,40): return
	var palette = {"impact":Color("ddc290"),"smoke":Color("b9b9a4"),"ember":Color("dd985a"),"return":Color("8bbdb1"),"glass":Color("b5d8b0")}
	for j in range(count):
		if pixels.size()>=160: break
		var a = j*2.39996+float(uid%7)
		var velocity = Vector2.from_angle(a)*(15+j%4*8)+direction*12
		pixels.append({"p":at,"v":velocity,"life":0.38 if kind=="smoke" else 0.24,"age":0.0,"kind":kind,"size":3.0 if kind=="smoke" else 2.0,"color":palette[kind]})

func eligible() -> Array:
	var list: Array = []
	for id in db.weapons:
		if build.has(id) and (build[id] < 8 or overcap) and not evolved.has(id): list.append(id)
		elif not build.has(id) and build.size() < 6: list.append(id)
	for id in db.passives:
		if items.has(id) and (items[id] < 5 or overcap): list.append(id)
		elif not items.has(id) and items.size() < 6: list.append(id)
	return list

func make_choices() -> Array:
	var pool = eligible()
	var result: Array = []
	var owned: Array = []
	for id in pool:
		if build.has(id) or items.has(id): owned.append(id)
	if not owned.is_empty():
		var first = owned[rng.randi_range(0,owned.size()-1)]
		result.append(first)
		pool.erase(first)
	while result.size() < 3 and not pool.is_empty():
		var total = 0.0
		for id in pool: total += 2 if build.has(id) or items.has(id) else 1
		var roll = rng.randf() * total
		for id in pool:
			roll -= 2 if build.has(id) or items.has(id) else 1
			if roll <= 0:
				result.append(id)
				pool.erase(id)
				break
	for fallback in ["apple","emerald"]:
		if result.size() < 3: result.append(fallback)
	# Shuffle using the seeded project RNG, rather than the global random state.
	for i in range(result.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var swap = result[i]
		result[i] = result[j]
		result[j] = swap
	return result

func next_level():
	xp -= db.required_xp(level)
	level += 1
	choices = make_choices()
	eye_extras()
	state = "LEVEL_UP"
	sound("level")

func eye_extras():
	side_choices = [];evolved_offer = {}
	var eye: int = int(items.get("end_eye", 0))
	if eye >= 4:
		var pool: Array = eligible().filter(func(id): return not choices.has(id))
		for k in range(2):
			if pool.is_empty():side_choices.append(["apple","emerald"][k]);continue
			var i: int = rng.randi_range(0, pool.size() - 1);side_choices.append(pool[i]);pool.remove_at(i)
	if eye >= 5:
		for id in choices + side_choices:
			if db.weapons.has(id) and db.recipes.has(id) and not evolved.has(id) and rng.randf() < EYE_EVOLVED_CHANCE:evolved_offer[id] = true

## A side option takes the centre card's place, then is chosen like any card.
func choose_side(k: int):
	if state != "LEVEL_UP" or k < 0 or k >= side_choices.size() or choices.is_empty(): return
	var centre: int = choices.size() / 2
	choices[centre] = side_choices[k];side_choices = []
	choose(centre)

func choose(index: int):
	if state != "LEVEL_UP" or index < 0 or index >= choices.size(): return
	if evolved_offer.has(choices[index]):evolved[choices[index]] = true
	apply_upgrade(choices[index])
	side_choices = []
	choices.clear()
	if xp >= db.required_xp(level): next_level()
	elif not pending_chest.is_empty(): open_chest(pending_chest)
	else: state = "RUNNING"

func apply_upgrade(id: String):
	if db.weapons.has(id):
		if evolved.has(id) or (build.get(id,0) >= 8 and not overcap) or (not build.has(id) and build.size() >= 6): return
		build[id] = build.get(id,0) + 1
		cooldowns[id] = minf(cooldowns.get(id,0),0.3)
	elif db.passives.has(id):
		if (items.get(id,0) >= 5 and not overcap) or (not items.has(id) and items.size() >= 6): return
		items[id] = items.get(id,0) + 1
	elif id == "apple":
		hp = minf(20, hp + 4)
		sound("pickup")
	elif id == "emerald":
		score += 25
		sound("pickup")

func evolution_candidates(born: float) -> Array:
	var candidates: Array = []
	if born < 360: return candidates
	for id in db.recipes:
		if build.get(id,0) == 8 and items.has(db.recipes[id].passive) and not evolved.has(id): candidates.append(id)
	return candidates

func open_chest(chest: Dictionary):
	var candidates = evolution_candidates(chest.born)
	if not candidates.is_empty():
		var id = candidates[rng.randi_range(0,candidates.size()-1)]
		evolved[id] = true
		chest_reward = {"id":id,"evolution":true,"text":db.recipes[id].effect}
	else:
		var owned: Array = []
		for id in eligible():
			if build.has(id) or items.has(id): owned.append(id)
		if not owned.is_empty():
			var id = owned[rng.randi_range(0,owned.size()-1)]
			chest_reward = {"id":id,"evolution":false,"text":db.description(id,build.get(id,items.get(id,0)))}
			apply_upgrade(id)
		else:
			apply_upgrade("apple")
			apply_upgrade("emerald")
			chest_reward = {"id":"apple","evolution":false,"text":"Восстановлено 4 HP · +25 очков"}
	pending_chest = {}
	chest_delay = 0.65
	state = "CHEST"
	sound("chest")

func close_chest():
	if state != "CHEST" or chest_delay > 0: return
	if xp >= db.required_xp(level): next_level()
	else: state = "RUNNING"
