extends "res://scripts/campaign_world.gd"
## Solo chapter I "До рассвета": landmarks, night events, witches and phantoms.
## Coop keeps world.gd and its 0.6.1 rules. Landmark placement uses its own RNG
## so the base map and spawn stream keep their original order.

var night: Dictionary = {}
var landmarks: Array = []
var water: Dictionary = {}
var ring_done: Dictionary = {}
var witch_timer := 0.0
var phantom_timer := 0.0
var fog_announced := false
var moon_announced := false
var phantoms_announced := false
var slain: Dictionary = {}

## The walk-in: Steve follows the path through the party gate, and the gap
## grows shut behind him. Only main.gd starts it; tests begin at once.
const INTRO_LENGTH := 11.6
const INTRO_START := Vector2(1024, 2196)
const INTRO_SIGN := Vector2(1024, 2062)
const RUN_START := Vector2(1024, 1978)
var intro_age := -1.0
var gate_grow := 1.0
var intro_step_timer := 0.0
var intro_cues := 0
var intro_from_prologue := false

func chapter_number() -> int:
	return 1

func begin_intro(from_prologue: bool = false):
	state = "INTRO"
	intro_from_prologue = from_prologue
	intro_age = 0.0
	gate_grow = 0.0
	intro_cues = 0
	intro_step_timer = 0.0
	player = INTRO_START
	facing = Vector2.UP

func skip_intro():
	if state != "INTRO":
		return
	finish_intro()

func finish_intro():
	player = RUN_START
	facing = Vector2.UP
	gate_grow = 1.0
	intro_age = -1.0
	player_moving = false
	state = "RUNNING"
	update_flow()

func intro_cue(bit: int, at: float, id: String) -> bool:
	if intro_age >= at and not (intro_cues & (1 << bit)):
		intro_cues |= 1 << bit
		if not id.is_empty():
			sound(id, 0.02)
		return true
	return false

func intro_step(dt: float):
	clock += dt
	intro_age += dt
	var a: float = intro_age
	var old: Vector2 = player
	if a < 3.8:
		player = INTRO_START.lerp(INTRO_SIGN, smoothstep(0.0, 1.0, a / 3.8) * 0.3 + a / 3.8 * 0.7)
		facing = Vector2.UP
	elif a < 5.6:
		player = INTRO_SIGN
		facing = Vector2(-0.6, -1).normalized()
	elif a < 7.6:
		player = INTRO_SIGN.lerp(RUN_START, (a - 5.6) / 2.0)
		facing = Vector2.UP
	else:
		player = RUN_START
		facing = Vector2.DOWN if a < 9.8 else Vector2.UP
	gate_grow = smoothstep(7.5, 8.9, a)
	intro_cue(0, 7.55, "ch1_fence_grow")
	intro_cue(1, 7.7, "ch1_wood_place")
	intro_cue(2, 8.1, "ch1_wood_place")
	intro_cue(3, 8.5, "ch1_wood_place")
	intro_cue(4, 8.95, "ch1_fence_grow")
	player_visual.travel = player.distance_to(old)
	player_moving = player_visual.travel > 0.0001
	if player_moving:
		intro_step_timer -= dt
		if intro_step_timer <= 0:
			intro_step_timer = 0.42
			sound("ch1_step", 0.1)
	animation.advance(self, dt)
	update_particles(dt)
	if a >= INTRO_LENGTH:
		finish_intro()

func camera() -> Vector2:
	if state == "INTRO":
		var normal: Vector2 = RUN_START.clamp(VIEW / 2.0, Vector2.ONE * SIZE - VIEW / 2.0)
		var follow := Vector2(1024, maxf(normal.y, player.y - 34))
		return follow.lerp(normal, smoothstep(INTRO_LENGTH - 2.0, INTRO_LENGTH - 0.2, intro_age))
	return super.camera()

func reset(seed_value: int = 0):
	landmarks.clear()
	water.clear()
	ring_done.clear()
	witch_timer = 0.0
	phantom_timer = 0.0
	fog_announced = false
	moon_announced = false
	phantoms_announced = false
	slain.clear()
	intro_age = -1.0
	gate_grow = 1.0
	intro_from_prologue = false
	super.reset(seed_value)
	night = db.data.night
	var extra: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/v2_assets.json"))
	animation.data.actors.merge(extra.actors, true)

func make_map():
	super.make_map()
	place_landmarks()

# ------------------------------------------------------------------ landmarks

func clear_props_near(p: Vector2, radius: float):
	for i in range(props.size() - 1, -1, -1):
		if props[i].type in ["tree", "rock", "stump", "flowers"] and props[i].p.distance_to(p) < radius:
			var c := Vector2i(props[i].p / 64.0)
			if solid_grid.has(c):
				solid_grid[c] = solid_grid[c].filter(func(s): return s.p != props[i].p)
			blocked.erase(Vector2i(props[i].p / CELL))
			props.remove_at(i)

func add_solid(p: Vector2, r: float):
	var c := Vector2i(p / 64.0)
	if not solid_grid.has(c):
		solid_grid[c] = []
	solid_grid[c].append({"p": p, "r": r})
	blocked[Vector2i(p / CELL)] = true

func place_landmarks():
	var place := RandomNumberGenerator.new()
	place.seed = int(rng.seed) ^ 0x2b4d71
	var spots: Array = []
	var kinds := ["ruin_0", "ruin_1", "well", "mine_entrance", "pond"]
	for kind in kinds:
		var p := Vector2.ZERO
		for attempt in range(60):
			var angle := place.randf() * TAU
			var distance := place.randf_range(320.0, 760.0)
			p = (player + Vector2.from_angle(angle) * distance).clamp(Vector2(220, 220), Vector2(1828, 1828))
			if spots.all(func(q): return q.distance_to(p) > 380.0):
				break
		spots.append(p)
		clear_props_near(p, 90.0 if kind == "pond" else 70.0)
		var mark := {"kind": kind, "p": p, "id": next_id()}
		match kind:
			"ruin_0", "ruin_1":
				# The wall line and the corner post block movement.
				for j in range(6):
					add_solid(p + Vector2(-26 + j * 9, -8), 6.0)
				add_solid(p + Vector2(-30, 0), 6.0)
				if kind == "ruin_0":
					loot.append({"kind": "chest", "p": p + Vector2(8, 18), "born": 0.0})
			"well":
				add_solid(p, 15.0)
			"mine_entrance":
				for j in range(5):
					add_solid(p + Vector2(-22 + j * 11, -6), 7.0)
			"pond":
				var radius := place.randf_range(44.0, 60.0)
				for ty in range(-5, 6):
					for tx in range(-5, 6):
						var q := p + Vector2(tx, ty) * 16
						var wobble := sin(tx * 1.7 + ty * 0.9) * 8.0
						if q.distance_to(p) < radius + wobble:
							var cell := Vector2i((q / 16).floor())
							water[cell] = true
							add_solid(Vector2(cell * 16) + Vector2(8, 8), 7.0)
				mark.radius = radius
		landmarks.append(mark)
	update_flow()

# ------------------------------------------------------------------ night events

func blood_moon() -> float:
	var t: float = time - float(night.blood_moon_at)
	if t < 0 or t > float(night.blood_moon_duration):
		return 0.0
	return clampf(minf(t, float(night.blood_moon_duration) - t) / 4.0, 0.0, 1.0)

func fog_amount() -> float:
	var t: float = time - float(night.fog_at)
	if t < 0 or t > float(night.fog_duration):
		return 0.0
	return clampf(minf(t, float(night.fog_duration) - t) / 4.0, 0.0, 1.0)

func count_kind(kind: String) -> int:
	var n := 0
	for m in mobs:
		if m.kind == kind and m.hp > 0:
			n += 1
	return n

func spawn_wave(dt: float):
	super.spawn_wave(dt)
	if state != "RUNNING":
		return
	if time >= float(night.blood_moon_at) + float(night.blood_moon_duration) and hp > 0:
		run_progress.award("blood_moon")
	if blood_moon() > 0:
		spawn_credit += db.wave(time).rate * dt * float(night.blood_moon_rate)
		if not moon_announced:
			moon_announced = true
			message = "Кровавая луна"
			message_timer = 3
			sound("warning")
	if time >= float(night.fog_at) and not fog_announced:
		fog_announced = true
		message = "Туман сгущается"
		message_timer = 3
		sound("cave")
	for burst in night.ring_bursts:
		var at: float = float(night.fog_at) + float(burst)
		if time >= at and not ring_done.has(burst):
			ring_done[burst] = true
			encircle(int(night.ring_size), float(burst) * 0.4)
	if time >= float(night.witch_from):
		witch_timer -= dt
		var cap := int(night.witch_cap_late if time >= float(night.witch_late_at) else night.witch_cap)
		if witch_timer <= 0:
			witch_timer = float(night.witch_every)
			if count_kind("witch") < cap:
				spawn("witch")
	if time >= float(night.phantom_from):
		if not phantoms_announced:
			phantoms_announced = true
			message = "Фантомы"
			message_timer = 3
			sound("phantom_swoop")
		phantom_timer -= dt
		if phantom_timer <= 0:
			phantom_timer = float(night.phantom_every)
			for j in range(int(night.phantom_count)):
				if count_kind("phantom") < int(night.phantom_cap):
					spawn("phantom")

## Zombies step out of the fog on every side of the hero at once.
func encircle(count: int, turn: float):
	for j in range(count):
		var p: Vector2 = player + Vector2.from_angle(turn + j * TAU / count) * float(night.ring_radius)
		if free_at(p, 10):
			spawn("zombie", p)

func spawn(kind: String, at = null) -> bool:
	if not super.spawn(kind, at):
		return false
	var m: Dictionary = mobs.back()
	if blood_moon() > 0 and kind not in ["elite", "ravager"]:
		m.xp = int(ceil(m.xp * float(night.blood_moon_xp)))
		m.speed *= float(night.blood_moon_speed)
		m.blood_moon = true
	match kind:
		"witch":
			m.timer = 1.5
			m.heal_timer = float(night.witch_heal_every)
		"phantom":
			m.phase = "circle"
			m.altitude = float(night.phantom_altitude)
			m.orbit = player.angle_to_point(m.p)
			m.timer = rng.randf_range(night.phantom_circle[0], night.phantom_circle[1])
			m.mark = Vector2.ZERO
			m.visual.airborne = true
	return true

# ------------------------------------------------------------------ new mobs

func step(dt: float, movement: Vector2 = Vector2.ZERO):
	if state == "INTRO":
		intro_step(dt)
		return
	if sword_step(dt, movement):
		return
	super.step(dt, movement)
	for m in mobs:
		if m.kind == "witch":
			if m.phase == "throw":
				var age: float = m.visual.shot_age
				if age < 0.25:animation.set_pose(m.visual, "windup", age)
				else:animation.set_pose(m.visual, "attack", age - 0.25)
				m.visual_dir = m.p.direction_to(player)
		elif m.kind == "phantom":
			match m.phase:
				"windup":animation.set_pose(m.visual, "windup", float(night.phantom_windup) - m.timer)
				"dive":animation.set_pose(m.visual, "attack", m.animation)
				"climb":animation.set_pose(m.visual, "recover", float(night.phantom_climb) - m.timer)
				_:animation.set_pose(m.visual, "walk", m.animation)

const CUSTOM := ["witch", "phantom"]

func move_mobs(dt: float):
	var all := mobs
	mobs = all.filter(func(m): return m.kind not in CUSTOM)
	super.move_mobs(dt)
	mobs = all
	for m in mobs:
		if m.hp <= 0 or m.kind not in CUSTOM:
			continue
		m.animation += dt
		m.flash = maxf(0, m.flash - dt)
		if m.burn > 0:
			m.burn -= dt
			m.burn_tick -= dt
			if m.burn_tick <= 0:
				m.burn_tick += 0.5
				hurt(m, burn_damage(m), Vector2.ZERO)
		if m.hp <= 0:
			continue
		m.timer -= dt
		if m.kind == "witch":
			move_witch(m, dt)
		else:
			move_phantom(m, dt)

func move_witch(m: Dictionary, dt: float):
	var p: Vector2 = m.p
	var distance := p.distance_to(player)
	var direction := navigation(p)
	var speed: float = m.speed
	if distance < float(night.witch_keep[0]):
		direction = -p.direction_to(player)
	elif distance < float(night.witch_keep[1]):
		speed = 0
	if m.timer <= 0 and distance >= float(night.witch_keep[0]) and distance < 260 and visible(p, -8):
		m.timer = float(night.witch_throw_every)
		var target: Vector2 = player + facing * (18.0 if player_moving else 0.0)
		add_effect("witch_potion", p, float(night.witch_throw_flight), {"start": p, "end": target, "radius": float(night.witch_splash_radius), "damage": m.damage, "owner": m.id})
		m.phase = "throw"
		m.visual.shot_age = 0.0
		sound("witch_throw", 0.2)
	m.heal_timer -= dt
	if m.heal_timer <= 0:
		m.heal_timer = float(night.witch_heal_every)
		var healed := false
		for other in in_radius(p, float(night.witch_heal_radius)):
			if other == m or other.hp >= other.max_hp:
				continue
			other.hp = minf(other.max_hp, other.hp + other.max_hp * float(night.witch_heal_share))
			healed = true
		if healed:
			add_effect("witch_heal", p, 0.9, {"radius": float(night.witch_heal_radius)})
			sound("witch_laugh", 0.5)
	if m.phase == "throw" and m.visual.shot_age > 0.45:
		m.phase = "walk"
	m.dir = direction
	m.p = move_actor(p, (direction * speed + m.knock) * dt, m.radius)
	m.moving = m.p.distance_squared_to(p) > 0.0001
	m.visual.travel = m.p.distance_to(p)
	m.knock = m.knock.move_toward(Vector2.ZERO, dt * 400)
	if distance < m.radius + 6:
		damage_area(m.p, m.radius + 6, 1.0)

func move_phantom(m: Dictionary, dt: float):
	var p: Vector2 = m.p
	var high := float(night.phantom_altitude)
	match m.phase:
		"circle":
			m.orbit += dt * 0.9
			var goal: Vector2 = player + Vector2.from_angle(m.orbit) * float(night.phantom_orbit)
			m.dir = p.direction_to(goal)
			m.p = p.move_toward(goal, m.speed * dt)
			m.altitude = move_toward(m.altitude, high, dt * 30)
			if m.timer <= 0:
				m.phase = "windup"
				m.timer = float(night.phantom_windup)
				m.mark = player + facing * (24.0 if player_moving else 0.0)
				sound("phantom_flap", 0.3)
		"windup":
			m.dir = p.direction_to(m.mark)
			m.altitude = move_toward(m.altitude, high + 8, dt * 20)
			if m.timer <= 0:
				m.phase = "dive";m.bit = false
				m.timer = float(night.phantom_dive_time)
				m.charge = p.direction_to(m.mark)
				sound("phantom_swoop", 0.3)
		"dive":
			var reach: float = float(night.phantom_dive_speed) * dt
			m.p = p + m.charge * reach
			m.dir = m.charge
			var left := maxf(0.0, m.timer / float(night.phantom_dive_time))
			m.altitude = lerpf(3.0, high, left * left)
			if m.altitude < 18 and m.p.distance_to(player) < m.radius + 9 and not m.get("bit",false):
				m.bit = true;damage_player(m.damage);shake = maxf(shake, .14);sound("phantom_flap", .1)
			if m.timer <= 0:
				m.phase = "climb"
				m.timer = float(night.phantom_climb)
		"climb":
			m.p = p + m.charge * float(night.phantom_dive_speed) * 0.45 * dt
			m.altitude = move_toward(m.altitude, high, dt * 50)
			if m.timer <= 0:
				m.phase = "circle"
				m.orbit = player.angle_to_point(m.p)
				m.timer = rng.randf_range(night.phantom_circle[0], night.phantom_circle[1])
	m.p = m.p.clamp(Vector2(30, 30), Vector2(SIZE - 30, SIZE - 30))
	m.p += m.knock * dt
	m.knock = m.knock.move_toward(Vector2.ZERO, dt * 400)
	m.moving = true
	m.visual.travel = m.p.distance_to(p)

func update_effects(dt: float):
	for e in effects:
		if e.kind == "witch_potion" and e.age + dt >= e.total and not e.get("burst", false):
			e.burst = true
			if player.distance_to(e.end) < e.radius:
				damage_player(e.damage)
			add_effect("potion_splash", e.end, 0.5, {"radius": e.radius})
			emit_pixels("glass", e.end, 8, Vector2.UP)
			sound("potion_splash", 0.1)
	super.update_effects(dt)

func resolve_deaths():
	for m in mobs:
		if m.hp <= 0 and m.kind in CUSTOM:
			slain[m.kind] = slain.get(m.kind, 0) + 1
			if slain.get("witch", 0) >= 12:run_progress.award("witch_hunter")
			if slain.get("phantom", 0) >= 10:run_progress.award("phantom_slayer")
	super.resolve_deaths()

func hurt(m: Dictionary, amount: float, push: Vector2 = Vector2.ZERO):
	if m.kind == "phantom":
		# A blow knocks it out of the air for a moment: hits read, it is catchable.
		push *= 0.8
		m.altitude = maxf(4.0, float(m.get("altitude", 0.0)) * 0.45)
		if m.phase == "circle":m.timer = maxf(m.timer, 0.6)
	super.hurt(m, amount, push)
