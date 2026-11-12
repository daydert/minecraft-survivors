extends "res://scripts/arsenal_world.gd"
## Chapter V: the game's own code space. White, then dark, then flickering.
## Enemies are pieces of code with the behaviour of what they are; the world
## itself lags, deletes its floor, throws items and steals the controls.
const CODE_KINDS := ["token","for_loop","while_loop","condition","if_else","function","arg","recursion","try_catch","null_ref","array","hijack","terminal","clone","loop_boss","notch"]
const BOSS_KINDS := ["terminal","clone","loop_boss","notch"]
const TOKENS := ["int","void","float","final","static","return;","break;","new","this",";","==","!=","&&","{ }","i++","0x1F","NaN","true","long","char"]
var five: Dictionary = {}
## Enemy projectiles (glyphs and living items) and delayed ground strikes.
var shots: Array = []
var zones: Array = []
## Deleted floor: {rect, age}; "missing texture" first, then a hole.
var deleted: Array = []
var void_tick := 0.0
## Presentation only: glyphs of a destroyed piece of code flying apart.
var shards: Array = []
var lag := 0.0
var lag_count := 0
var next_event: Dictionary = {}
var pending: Array = []
var hint: Dictionary = {}
var invert := 0.0
var hijack: Dictionary = {}
var double_pending := false
var cache_ready := 0.0
var crate_timer := 75.0
var arsenal = preload("res://scripts/chapter_five_arsenal.gd").new()
var bosses = preload("res://scripts/chapter_five_bosses.gd").new()
var notch = preload("res://scripts/chapter_five_notch.gd").new()

func chapter_number() -> int:
	return 5

func reset(seed_value: int = 0):
	shots.clear();zones.clear();deleted.clear();shards.clear();pending.clear()
	void_tick = 0.0;lag = 0.0;lag_count = 0;hint = {};invert = 0.0;hijack = {};double_pending = false;crate_timer = 75.0
	arsenal.reset()
	bosses.reset()
	notch.reset()
	cache_ready=0.0
	super.reset(seed_value)
	five = db.data.chapter_five
	for id in arsenal.OWN:animation.data.weapons[id] = {"windup":.2,"attack":.12,"recover":.36}
	next_event = {}
	for id in ["lag","items","delete","hijack"]:next_event[id] = float(five.world[id].from)

func make_map():
	# An empty plane: only a few data crates to break.
	for i in range(14):
		var a := TAU * i / 14.0
		props.append({"type":"pumpkin","p":player + Vector2.from_angle(a) * (150 + i % 4 * 110),"hp":8.0,"id":next_id(),"radius":7.0})

# ------------------------------------------------------------------ tone

func phase_name() -> String:
	if time < float(five.phases.dark_at):return "white"
	return "dark" if time < float(five.phases.flicker_at) else "flicker"

## Presentation only: one gradual dusk, then a deliberate inversion once a
## minute. No strobing at phase boundaries; combat clocks/RNG are unchanged.
func tone() -> float:
	var dark_at: float = five.phases.dark_at
	var flicker_at: float = five.phases.flicker_at
	if time < dark_at:return smoothstep(dark_at-6.0,dark_at,time)
	if time < flicker_at:return 1.0
	var period: float = five.phases.flicker_period
	var age: float = time-flicker_at
	var cycle: int = int(age/period)
	var from: float = 1.0 if cycle%2==0 else 0.0
	var fade: float = smoothstep(period-5.0,period,fposmod(age,period))
	return lerpf(from,1.0-from,fade)

# ------------------------------------------------------------------ spawning

func spawn(kind: String, at = null) -> bool:
	var glitch := kind.begins_with("glitch_")
	var base: String = kind.trim_prefix("glitch_")
	if not super.spawn(base, at):return false
	var m: Dictionary = mobs.back()
	m.code = base in CODE_KINDS
	m.glitch = glitch
	m.owner = 0;m.depth = 0;m.shield = false;m.recharge = 0.0;m.reveal = 0.0;m.index = 0;m.count = 0;m.broken = false;m.orbit = 0.0;m.iter = -1
	if glitch:
		m.hp = float(five.glitch[base]) * (1.0 + 0.05 * floor(time / 60));m.max_hp = m.hp;m.xp = 4
	match base:
		"token":m.word = TOKENS[m.id % TOKENS.size()]
		"for_loop":m.timer = 1.5
		"while_loop":
			var c: Vector2 = m.p + Vector2(46, 0)
			if super.spawn("condition", c):
				var cond: Dictionary = mobs.back()
				cond.code = true;cond.glitch = false;cond.owner = m.id;cond.orbit = float(m.id % 7);cond.depth = 0;cond.shield = false;cond.reveal = 0.0;cond.broken = false
		"if_else":m.timer = 2.0
		"function":m.timer = 2.5
		"recursion":m.depth = 2
		"try_catch":m.shield = true
		"array":m.timer = 1.0
	return true

## Plain spawn for the bosses module (no chapter V extras).
func super_spawn(kind: String, at) -> bool:
	return super.spawn(kind, at)

func notes_add(p: Vector2, text: String):
	arsenal.notes.append({"p":p,"text":text,"age":0.0})

func spawn_wave(dt: float):
	super.spawn_wave(dt * (float(five.bosses.spawn_scale) if bosses.active() else 1.0))

func mob_by_id(id: int):
	for m in mobs:
		if m.id == id and m.hp > 0:return m
	return null

# ------------------------------------------------------------------ damage rules

func hurt(m: Dictionary, amount: float, push: Vector2 = Vector2.ZERO):
	if m.hp <= 0:return
	if m.kind == "notch":
		notch.hurt(self, m, amount);return
	if m.kind in BOSS_KINDS:
		if bosses.intercept(self, m, amount):return
		if m.kind != "clone":push = Vector2.ZERO
	if m.kind == "while_loop" and not m.broken:
		m.flash = 0.05
		return
	if m.kind == "try_catch" and m.shield:
		m.shield = false;m.recharge = 5.0;m.flash = 0.1
		shoot(m.p + Vector2(0, -10), m.p.direction_to(player) * 170.0, 3.0, "throw")
		sound("shield_block", 0.1)
		return
	if m.kind == "null_ref":m.reveal = 0.8
	if m.kind in ["condition","hijack","array","function","while_loop"]:push = Vector2.ZERO
	super.hurt(m, amount, push)

func sound(id: String, gap: float = .04):
	if id.begins_with("hurt_") and id.trim_prefix("hurt_") in CODE_KINDS:id = "ch4_hb_tick"
	super.sound(id, gap)

func shoot(p: Vector2, v: Vector2, damage: float, glyph: String, delay: float = 0.0, icon: String = ""):
	if shots.size() >= 220:return
	shots.append({"p":p,"v":v,"life":3.2,"damage":damage,"glyph":glyph,"delay":delay,"icon":icon,"age":0.0})

func strike(p: Vector2, radius: float, delay: float, damage: float):
	zones.append({"p":p,"r":radius,"age":0.0,"delay":delay,"damage":damage,"hit":false})

func resolve_deaths():
	var born: Array = []
	for m in mobs:
		if m.hp > 0 or not m.get("code", false):continue
		shards.append({"p":m.p + Vector2(0, -12),"age":0.0,"seed":m.id,"kind":m.kind})
		match m.kind:
			"condition":
				var owner = mob_by_id(m.owner)
				if owner != null:
					owner.broken = true;owner.speed = 14.0;owner.flash = 0.2
					sound("ch4_hb_shatter", 0.1)
			"function":
				for other in mobs:
					if other.kind == "arg" and other.owner == m.id:other.hp = 0
			"recursion":
				if m.depth > 0:
					for side in [-1, 1]:born.append({"p":m.p + Vector2(side * 9, 0),"depth":m.depth - 1})
			"terminal","loop_boss":bosses.boss_died(self, m)
			"hijack":
				if not hijack.is_empty():
					hijack = {};invert = 0.0
					message = "Управление возвращено";message_timer = 2.0
					sound("ch4_mirror", 0.1)
	for m in mobs:
		if m.hp<=0 and m.kind in ["while_loop","array"] and time>=cache_ready:
			cache_ready=time+80.0
			loot.append({"kind":"chest","p":m.p,"born":time,"data_cache":true})
			add_effect("ch5_spawn",m.p,.8)
	super.resolve_deaths()
	for b in born:
		if super.spawn("recursion", b.p):
			var m: Dictionary = mobs.back()
			m.code = true;m.glitch = false;m.depth = b.depth;m.owner = 0;m.shield = false;m.reveal = 0.0;m.broken = false
			m.hp *= 0.5 if b.depth == 1 else 0.25;m.max_hp = m.hp
			m.speed += (2 - b.depth) * 14.0;m.radius = 8.0 if b.depth == 1 else 6.0;m.xp = 2

# ------------------------------------------------------------------ mobs

func move_mobs(dt: float):
	# Glitched vanilla mobs keep their vanilla behaviour.
	var all: Array = mobs
	mobs = all.filter(func(m):return not m.get("code", false))
	super.move_mobs(dt)
	mobs = all
	damage_owner = "fire"
	for m in mobs.duplicate():
		if m.hp <= 0 or not m.get("code", false):continue
		m.animation += dt
		m.flash = maxf(0, m.flash - dt)
		m.control_resist = maxf(0, m.control_resist - dt)
		if m.burn > 0:
			m.burn -= dt;m.burn_tick -= dt
			if m.burn_tick <= 0:m.burn_tick += .5;hurt(m, burn_damage(m))
		if m.hp <= 0:continue
		var old: Vector2 = m.p
		if m.pull_left > 0 or m.stun > 0:
			if m.pull_left > 0:
				var travel: float = minf(m.pull_left, 360 * dt)
				m.p = move_actor(m.p, m.pull_dir * travel, m.radius);m.pull_left = maxf(0, m.pull_left - travel)
				if m.pull_left <= .01:m.stun = m.pull_stun
			else:m.stun = maxf(0, m.stun - dt)
			continue
		m.timer -= dt
		var to: Vector2 = old.direction_to(player)
		var distance: float = old.distance_to(player)
		var speed: float = m.speed
		var direction: Vector2 = to
		var contact := true
		match m.kind:
			"for_loop":speed = for_loop(m, dt, distance)
			"while_loop":pass
			"condition":
				contact = false
				var owner = mob_by_id(m.owner)
				if owner == null:m.hp = 0;continue
				m.orbit += dt * 1.3
				m.p = owner.p + Vector2.from_angle(m.orbit) * 44.0
				m.dir = Vector2.DOWN
				continue
			"if_else":
				if m.timer <= 0:
					m.timer = 2.4
					if player.x < m.p.x:
						m.branch = 0
						for k in [-1, 0, 1]:shoot(m.p + Vector2(0, -10), to.rotated(k * 0.22) * 150.0, 2.0, "<")
					else:
						m.branch = 1
						strike(player, 30.0, 0.8, 4.0)
					m.branch_age = 0.0
				m.branch_age = float(m.get("branch_age", 9.0)) + dt
			"function":
				if m.timer <= 0:
					m.timer = 4.5
					if mobs.filter(func(o):return o.kind == "arg" and o.owner == m.id and o.hp > 0).size() < 6:
						m.count += 1
						for k in range(3):
							if super.spawn("arg", m.p + Vector2.from_angle(k * TAU / 3 + m.count) * 20.0):
								var a: Dictionary = mobs.back()
								a.code = true;a.glitch = false;a.owner = m.id;a.index = k;a.depth = 0;a.shield = false;a.reveal = 0.0;a.broken = false
						m.flash = 0.12
			"try_catch":
				if not m.shield:
					m.recharge -= dt
					if m.recharge <= 0:m.shield = true
			"null_ref":
				m.reveal = maxf(0, m.reveal - dt)
				if distance < 46 + 22 * items.get("light_block", 0):m.reveal = maxf(m.reveal, 0.25)
			"array":
				if m.timer <= 0:
					m.timer = 0.7
					m.index = (m.index + 1) % 5
					var cell: Vector2 = m.p + Vector2((m.index - 2) * 14.0, -10)
					shoot(cell, cell.direction_to(player) * 120.0, 2.0, str(m.index))
			"terminal","loop_boss","clone","notch":
				m.dir = Vector2.DOWN if m.kind not in ["clone","notch"] else m.dir
				continue
			"hijack":
				contact = false
				m.p = (hijack.anchor * 2.0 - player).clamp(Vector2(40, 40), Vector2(SIZE - 40, SIZE - 40))
				m.dir = -facing
				m.moving = player_moving
				continue
		m.dir = direction
		m.p = move_actor(old, (direction * speed + m.knock) * dt, m.radius)
		m.moving = m.p.distance_squared_to(old) > 0.0001
		m.visual.travel = m.p.distance_to(old)
		m.knock = m.knock.move_toward(Vector2.ZERO, dt * 400)
		if contact and m.p.distance_to(player) < m.radius + 6:damage_player(m.damage)

## for i in range(n): one ring of shots per iteration, counted out loud.
func for_loop(m: Dictionary, dt: float, distance: float) -> float:
	match m.phase:
		"walk":
			var busy: int = mobs.filter(func(o):return o.kind == "for_loop" and o.phase in ["windup","loop"]).size()
			if m.timer <= 0 and distance < 130 and busy < 2:
				m.phase = "windup";m.timer = 0.7;m.iter = -1
				sound("ch4_mob_warn", 0.3)
			return m.speed
		"windup":
			if m.timer <= 0:m.phase = "loop";m.timer = 0.0;m.iter = -1
		"loop":
			if m.timer <= 0:
				m.iter += 1
				var n: int = 3 + int(time / 240.0)
				if m.iter >= n:
					m.phase = "rest";m.timer = 2.2;m.iter = -1
				else:
					m.timer = 0.38
					for k in range(5):shoot(m.p + Vector2(0, -10), Vector2.from_angle(k * TAU / 5 + m.iter * 0.3) * 95.0, 1.5, str(m.iter))
					sound("ch4_hb_tick", 0.05)
		"rest":
			if m.timer <= 0:m.phase = "walk";m.timer = 1.0
			return m.speed * 0.5
	return 0.0

func update_shots(dt: float):
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		s.age += dt
		if s.delay > 0:
			s.delay -= dt
			continue
		s.p += s.v * dt;s.life -= dt
		if s.p.distance_to(player) < 8:
			damage_player(s.damage * void_factor());shots.remove_at(i)
		elif s.life <= 0:shots.remove_at(i)
	for i in range(zones.size() - 1, -1, -1):
		var z: Dictionary = zones[i]
		z.age += dt
		if z.age >= z.delay and not z.hit:
			z.hit = true
			if z.p.distance_to(player) < z.r:damage_player(z.damage)
			if visible(z.p, 40):sound("ch4_stone_hit", 0.1);shake = maxf(shake, 0.08)
		if z.age > z.delay + 0.3:zones.remove_at(i)
	for i in range(shards.size() - 1, -1, -1):
		shards[i].age += dt
		if shards[i].age > 0.6:shards.remove_at(i)

# ------------------------------------------------------------------ the world itself

func schedule(id: String, at: Vector2):
	var warn: float = five.world.hint
	pending.append({"id":id,"p":at,"left":warn})
	hint = {"id":id,"p":at,"left":warn,"total":warn}
	next_event[id] = time + float(five.world[id].every)

func update_world(dt: float):
	for id in ["lag","items","delete","hijack"]:
		if bosses.active():
			next_event[id] = maxf(float(next_event[id]), time + 4.0);continue
		if time < float(next_event[id]) or not pending.is_empty():continue
		if id == "hijack" and (not hijack.is_empty() or invert > 0):
			next_event[id] = time + 5.0;continue
		var at: Vector2 = player
		if id == "delete":at = (player + facing * 30.0).clamp(Vector2(120, 90), Vector2(SIZE - 120, SIZE - 90))
		schedule(id, at)
		break
	if not hint.is_empty():
		hint.left -= dt
		if hint.left <= -0.8:hint = {}
	for i in range(pending.size() - 1, -1, -1):
		var e: Dictionary = pending[i]
		e.left -= dt
		if e.left > 0:continue
		pending.remove_at(i)
		fire_event(e.id, e.p)
	for i in range(deleted.size() - 1, -1, -1):
		var d: Dictionary = deleted[i]
		d.age += dt
		if d.age > float(five.world.delete.warn) + float(five.world.delete.life):deleted.remove_at(i)
	void_tick -= dt
	if void_tick <= 0:
		void_tick = 0.5
		for d in deleted:
			if d.age < float(five.world.delete.warn):continue
			if d.rect.has_point(player):damage_player(float(five.world.delete.damage) * void_factor())
			for m in mobs:
				if m.hp > 0 and m.kind not in ["hijack","condition","terminal","loop_boss","clone"] and not (m.kind == "while_loop" and not m.broken) and d.rect.has_point(m.p):
					m.hp -= float(five.world.delete.mob_damage);m.flash = 0.08
	if invert > 0 and hijack.is_empty():
		invert -= dt
		if invert <= 0 and double_pending:
			double_pending = false;begin_double()
	if not hijack.is_empty():
		hijack.left -= dt
		if hijack.left <= 0:
			var m = mob_by_id(hijack.id)
			if m != null:m.hp = 0;m.xp = 0
			hijack = {}
			invulnerable = 0
			damage_player(float(five.world.hijack.damage))
			invert = float(five.world.hijack.after)
			message = "Поглощение";message_timer = 2.0
			sound("ch4_hb_glitch", 0.1)

func fire_event(id: String, at: Vector2):
	var def: Dictionary = five.world[id]
	match id:
		"lag":
			lag = float(def.freeze);lag_count += 1
			message = "Lag: %d ms" % int(def.freeze * 1000);message_timer = 1.6
			sound("ch4_hb_freeze", 0.2)
		"items":
			var icons := ["arrow","sword_iron","splash_potion","trident","arrow"]
			for k in range(int(def.count)):
				var from: Vector2 = player + Vector2.from_angle(k * TAU / int(def.count) + time) * float(def.radius)
				shoot(from, from.direction_to(player) * float(def.speed), float(def.damage), "", float(def.delay) + k * 0.12, icons[k % icons.size()])
			sound("ch4_hb_twitch", 0.2)
		"delete":
			var size := Vector2(def.size[0], def.size[1])
			deleted.append({"rect":Rect2(at - size / 2.0, size),"age":0.0})
			sound("ch4_hb_strip", 0.2)
		"hijack":
			invert = float(def.invert);double_pending = true
			message = "Управление перехвачено";message_timer = 2.5
			sound("ch4_hb_glitch", 0.2)

func begin_double():
	var anchor: Vector2 = (player + facing * 46.0).clamp(Vector2(80, 80), Vector2(SIZE - 80, SIZE - 80))
	if not super.spawn("hijack", anchor * 2.0 - player):
		return
	var m: Dictionary = mobs.back()
	m.code = true;m.glitch = false;m.owner = 0;m.depth = 0;m.shield = false;m.reveal = 0.0;m.broken = false
	m.hp = float(db.data.mobs.hijack.hp) + level * 6.0;m.max_hp = m.hp
	hijack = {"id":m.id,"anchor":anchor,"left":float(five.world.hijack.limit)}
	message = "Это не ты";message_timer = 2.0
	sound("ch4_mirror", 0.2)

## After a lag spike everything that was moving arrives where it would have been.
func rubber_band():
	var skip: float = five.world.lag.skip
	for m in mobs:
		if m.hp <= 0 or m.kind in ["condition","hijack","array","terminal","loop_boss","clone"]:continue
		m.p = move_actor(m.p, m.p.direction_to(player) * minf(m.speed * skip, maxf(0, m.p.distance_to(player) - 26)), m.radius)
	for s in shots:
		if s.delay <= 0:s.p += s.v * skip * 0.35
	sound("ch4_hb_teleport", 0.2)

# ------------------------------------------------------------------ equipment

func update_attacks(dt: float):
	var all: Dictionary = build
	build = {}
	for id in all:
		if id not in arsenal.OWN:build[id] = all[id]
	super.update_attacks(dt)
	build = all
	arsenal.update_attacks(self, dt)

func damage_player(amount: float):
	if invulnerable > 0 or hp <= 0:return
	if items.has("breakpoint") and arsenal.breakpoint_ready<=0:
		arsenal.breakpoint_ready=20.0-items.breakpoint*2.0;invulnerable=.45
		for m in in_radius(player,90):
			if not m.get("boss",false) and m.kind not in BOSS_KINDS:m.stun=maxf(m.stun,.45)
		add_effect("ch5_breakpoint",player,.5);sound("shield_block",.1)
		return
	var before: float = hp
	super.damage_player(amount)
	if hp <= 0 and before > 0:arsenal.rewind(self)

func drop_xp(p: Vector2, value: int):
	super.drop_xp(p, int(round(value * (1.0 + 0.1 * items.get("knowledge_book", 0)))))

## Shots and deleted floor: the structure void soaks part of each.
func void_factor() -> float:
	return maxf(0.25, 1.0 - 0.15 * items.get("structure_void", 0))

func discard(id: String) -> bool:
	if id == "spawn_egg":arsenal.allies.clear()
	return super.discard(id)

func break_pumpkin(p: Dictionary):
	if p.get("has_heal",false):loot.append({"kind":"healing_v","p":p.p})
	else:drop_xp(p.p,4)
	add_effect("break",p.p,.3);sound("break")

func apply_upgrade(id: String):
	if id=="healing_v":super.apply_upgrade("apple")
	else:super.apply_upgrade(id)

# ------------------------------------------------------------------ step

func camera() -> Vector2:
	if stage == "notch":
		var mid: Vector2 = player.lerp(notch.p, .4)
		return mid.clamp(VIEW / 2.0, Vector2.ONE * SIZE - VIEW / 2.0)
	return super.camera()

func movement_speed() -> float:
	return float(db.data.player_speed) * (1 + 0.08 * items.get("sugar", 0))

func step(dt: float, movement: Vector2 = Vector2.ZERO):
	if sword_step(dt, movement):return
	if state != "RUNNING":return
	if stage == "notch":
		clock += dt
		track_progress(dt)
		notch.step(self, dt, movement)
		return
	if lag > 0:
		lag -= dt
		if lag <= 0:rubber_band()
		return
	track_progress(dt)
	clock += dt
	stage_age += dt
	time = minf(db.data.duration, time + dt)
	invulnerable = maxf(0, invulnerable - dt)
	shake = maxf(0, shake - dt)
	message_timer = maxf(0, message_timer - dt)
	if invert > 0:movement = -movement
	var before: Vector2 = player
	if movement.length_squared() > 0:
		facing = movement.normalized()
		player = move_actor(player, movement.limit_length() * movement_speed() * dt, 6)
		moved += dt
	tracked_velocity = tracked_velocity.lerp((player - before) / maxf(.0001, dt), minf(1, dt * 10))
	player_visual.travel = before.distance_to(player)
	player_moving = player_visual.travel > .0001
	flow_timer -= dt
	if flow_timer <= 0 and flow_cell != Vector2i(player / CELL):update_flow();flow_timer = .25
	spawn_wave(dt)
	update_world(dt)
	var before_move: Dictionary = {}
	for m in mobs:before_move[m.id] = m.p
	move_mobs(dt)
	bosses.step(self, dt)
	for m in mobs:
		if m.get("slow", 0.0) > 0 and before_move.has(m.id) and m.kind not in ["condition","hijack","terminal","loop_boss"]:
			m.p = before_move[m.id].lerp(m.p, float(arsenal.rules(self).stick_slow))
			m.slow = maxf(0, m.slow - dt)
	update_shots(dt)
	rebuild_hit_grid()
	update_attacks(dt)
	update_projectiles(dt)
	update_explosives(dt)
	update_hazards(dt)
	update_fire(dt)
	resolve_deaths()
	arsenal.step(self, dt)
	# A data crate with an apple surfaces now and then, never under the hero.
	crate_timer -= dt
	if crate_timer <= 0:
		crate_timer = 75.0
		var at: Vector2 = (player + Vector2.from_angle(time * 1.7) * 120.0).clamp(Vector2(80, 80), Vector2(SIZE - 80, SIZE - 80))
		props.append({"type":"pumpkin","p":at,"hp":8.0,"id":next_id(),"radius":7.0,"has_heal":true})
		add_effect("ch5_spawn", at, .4)
	update_effects(dt)
	pickup(dt)
	update_particles(dt)
	animation.advance(self, dt)
	update_regeneration(dt)
	if hp <= 0:
		state = "RESULT";victory = false
		sound("death")
		return
	if time >= float(db.data.duration):
		notch.begin(self)
		return
	if xp >= db.required_xp(level):next_level()
	elif not pending_chest.is_empty():open_chest(pending_chest)
