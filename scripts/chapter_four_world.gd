extends "res://scripts/arsenal_world.gd"
## IV owns its terrain and scenario. Stage A is exploration and environmental
## combat; the wave/actor drafts remain data for the subsequent content stage.
const TERRAIN := "res://data/chapter_four_terrain.json"
var terrain: Dictionary = {}
var pools: Dictionary = {}
var landmarks: Array = []
var threats: Array = []
var blood_shots: Array = []
var blood_hand: Dictionary = {}
var hand_cooldown := 0.0
var held := 0.0
var note_read := false
var note_pending := false
var note_presented := false
var aura_state := "none"
var aura_changed_at := -10.0
var victory_stage := ""

func chapter_number() -> int:
	return 4

func reset(seed_value: int = 0):
	terrain = JSON.parse_string(FileAccess.get_file_as_string(TERRAIN))
	pools.clear();landmarks.clear();threats.clear();blood_shots.clear()
	blood_hand.clear();hand_cooldown = 2.0;held = 0.0
	note_read = false;note_pending = false;note_presented = false
	aura_state = "none";aura_changed_at = -10.0;victory_stage = ""
	super.reset(seed_value)
	stage = "arrival"
	facing = Vector2.UP

func add_solid(p: Vector2, radius: float):
	var cell := Vector2i(p / 64.0)
	if not solid_grid.has(cell):solid_grid[cell] = []
	solid_grid[cell].append({"p": p, "r": radius})
	blocked[Vector2i(p / CELL)] = true

func make_map():
	for cell in terrain.pool_cells:
		pools[Vector2i(int(cell) % 128, int(cell) / 128)] = true
	for item in terrain.props:
		var p := Vector2(item.p[0], item.p[1])
		if item.type == "trunk":
			add_prop("tree", p)
			props.back().variant = int(item.variant)
			continue
		var mark := {"kind": item.type, "p": p, "variant": int(item.get("variant", 0)), "id": next_id(), "phase": fposmod(p.x * .137 + p.y * .071, TAU)}
		landmarks.append(mark)
		match item.type:
			"house":
				# Ruined rear and side walls; the doorway and note remain accessible.
				for x in range(-30, 31, 10):add_solid(p + Vector2(x, -10), 5)
				for y in range(-28, -9, 8):add_solid(p + Vector2(-30, y), 5)
			"crucifix":add_solid(p, 5)
			"growth", "growth_big":
				make_threat(mark, db.data.chapter_four.growth)
				if mark.kind == "growth_big":
					mark.radius = float(db.data.chapter_four.growth.large_radius)
					mark.hp = float(db.data.chapter_four.growth.large_hp);mark.max_hp = mark.hp
				add_solid(mark.p, mark.radius)
			"torch":
				mark.hostile = item.get("hostile", false)
				if mark.hostile:make_threat(mark, db.data.chapter_four.cursed_torch)
	var pyramid := Vector2(terrain.pyramid[0], terrain.pyramid[1])
	landmarks.append({"kind": "pyramid", "p": pyramid, "variant": 0, "id": next_id(), "phase": 0.0})
	# The baked solid occupies the whole stepped footprint, not a thin back row.
	for x in range(-110, 111, 12):
		for y in range(-62, 11, 12):add_solid(pyramid + Vector2(x, y), 8)
	var note := Vector2(terrain.note[0], terrain.note[1])
	landmarks.append({"kind": "note", "p": note, "variant": 0, "id": next_id(), "phase": 0.0})
	for i in range(18):
		var p: Vector2 = player + Vector2.from_angle(i * 2.39996) * (150 + i % 5 * 130)
		if free_at(p, 10) and not in_blood(p):
			props.append({"type": "pumpkin", "p": p, "hp": 12.0, "id": next_id(), "radius": 7.0})
	assign_healing()

func make_threat(mark: Dictionary, rules: Dictionary):
	mark.merge({"hp": float(rules.hp), "max_hp": float(rules.hp), "radius": float(rules.radius), "timer": 2.0 + fposmod(mark.phase, 3), "attack": "idle", "flash": 0.0, "burn": 0.0, "burn_tick": .5, "visual": animation.actor(), "knock": Vector2.ZERO, "boss": false, "control_resist": 0.0, "aim": Vector2.DOWN, "link": -1, "dead": false})
	threats.append(mark)

func in_blood(p: Vector2) -> bool:
	return pools.has(Vector2i((p / 16).floor()))

func move_actor(p: Vector2, velocity: Vector2, radius: float) -> Vector2:
	# Keep long steps from tunnelling through the ruined walls and pyramid.
	var steps := maxi(1, ceili(velocity.length() / 4.0))
	for i in range(steps):p = super.move_actor(p, velocity / steps, radius)
	return p

func camera() -> Vector2:
	var cam: Vector2 = super.camera()
	if stage == "arrival":cam += Vector2(0, -24 * (1 - smoothstep(0, float(db.data.chapter_four.arrival_duration), stage_age)))
	return cam

func rebuild_hit_grid():
	super.rebuild_hit_grid()
	for m in threats:
		if m.hp <= 0:continue
		var cell := Vector2i(m.p / CELL)
		if not hit_grid.has(cell):hit_grid[cell] = []
		hit_grid[cell].append(m)

func hurt(m: Dictionary, amount: float, push: Vector2 = Vector2.ZERO):
	if not m.has("attack"):
		super.hurt(m, amount, push)
		return
	if m.hp <= 0:return
	damage_by[damage_owner] = damage_by.get(damage_owner, 0.0) + minf(m.hp, amount)
	m.hp -= amount;m.flash = .1
	emit_pixels("impact", m.p - Vector2(0, 10), 3, push)
	if m.hp <= 0:
		m.attack = "dead";m.dead = true
		if m.kind != "torch":
			var grid_cell := Vector2i(m.p / 64.0)
			solid_grid[grid_cell] = solid_grid[grid_cell].filter(func(s):return s.p != m.p)
			var nav_cell := Vector2i(m.p / CELL)
			if not nearby_solids(m.p).any(func(s):return Vector2i(s.p/CELL) == nav_cell):blocked.erase(nav_cell)
			update_flow()
		drop_xp(m.p, 3 if m.kind == "torch" else 6)
		sound("ch4_break")

func hook_target(m: Dictionary, evolved_hook: bool):
	if not m.has("attack"):super.hook_target(m, evolved_hook)

func aura_near() -> bool:
	for mark in landmarks:
		if mark.kind == "crucifix" and player.distance_to(mark.p) < float(db.data.aura.radius):return true
	return false

func update_aura():
	var next := ("rage" if note_read else "despair") if aura_near() else "none"
	if next != aura_state:
		aura_state = next;aura_changed_at = clock
		if next != "none":sound("ch4_rage" if next == "rage" else "ch4_despair", 1.0)
	db.data.aura_damage = 1.0 if next == "none" else float(db.data.aura[next + "_damage"])
	db.data.aura_interval = 1.0 if next == "none" else float(db.data.aura[next + "_interval"])

func read_note():
	if note_read:return
	note_read = true;note_pending = false
	update_aura()
	aura_changed_at = clock
	sound("ch4_note")

func update_threats(dt: float):
	for m in threats:
		if m.hp <= 0:continue
		m.flash = maxf(0, m.flash - dt)
		if m.burn > 0:
			m.burn -= dt;m.burn_tick -= dt
			if m.burn_tick <= 0:
				m.burn_tick += .5;damage_owner = "fire";hurt(m, burn_damage(m))
		if m.hp <= 0:continue
		m.timer -= dt
		var rules: Dictionary = db.data.chapter_four.cursed_torch if m.kind == "torch" else db.data.chapter_four.growth
		if m.attack == "idle" and m.timer <= 0 and m.p.distance_to(player) < float(rules.range):
			m.attack = "windup";m.timer = float(rules.windup);m.aim = m.p.direction_to(player)
			if m.kind == "torch":
				m.link = -1
				for other in threats:
					if other.kind == "torch" and other.hp > 0 and other.id != m.id and other.p.distance_to(m.p) < 150:
						m.link = other.id;break
				if m.link < 0:m.attack = "idle";m.timer = rules.cooldown;continue
			if visible(m.p, 40):sound("ch4_charge", .8)
		elif m.attack == "windup" and m.timer <= 0:
			if m.kind == "torch":
				var other = linked_torch(m)
				if other != null:
					add_effect("ch4_arc", m.p, .22, {"end": other.p, "seed": m.id})
					if Geometry2D.get_closest_point_to_segment(player, m.p, other.p).distance_to(player) < float(rules.width):damage_player(rules.damage)
			else:
				for j in range(int(rules.count)):
					var a := (float(j) / maxf(1, rules.count - 1) - .5) * float(rules.spread)
					blood_shots.append({"p": m.p, "dir": m.aim.rotated(a), "life": float(rules.range) / float(rules.speed), "speed": float(rules.speed), "damage": float(rules.damage)})
				if visible(m.p, 40):sound("ch4_pulse", .3)
			m.attack = "recover";m.timer = .45
		elif m.attack == "recover" and m.timer <= 0:
			m.attack = "idle";m.timer = float(rules.cooldown)
		if m.kind == "torch" and m.attack == "windup" and linked_torch(m) == null:
			m.attack = "idle";m.timer = float(rules.cooldown)
	for i in range(blood_shots.size() - 1, -1, -1):
		var b = blood_shots[i]
		var before: Vector2 = b.p
		b.p += b.dir * b.speed * dt;b.life -= dt
		if Geometry2D.get_closest_point_to_segment(player, before, b.p).distance_to(player) < 8:
			damage_player(b.damage);b.life = 0
		if b.life <= 0:blood_shots.remove_at(i)
	update_hand(dt)

func linked_torch(m: Dictionary):
	for other in threats:
		if other.id == m.link and other.hp > 0:return other
	return null

func update_hand(dt: float):
	held = maxf(0, held - dt)
	hand_cooldown -= dt
	var rules: Dictionary = db.data.chapter_four.blood_hand
	if blood_hand.is_empty():
		if hand_cooldown <= 0 and in_blood(player):
			blood_hand = {"p": player, "age": 0.0, "caught": false}
			sound("ch4_hand")
		return
	blood_hand.age += dt
	if blood_hand.age >= float(rules.windup) and not blood_hand.caught:
		blood_hand.caught = true
		if in_blood(player) and player.distance_to(blood_hand.p) < float(rules.radius):
			damage_player(rules.damage);held = float(rules.hold)
	if blood_hand.age >= float(rules.windup) + .8:
		blood_hand.clear();hand_cooldown = float(rules.cooldown)

func step(dt: float, movement: Vector2 = Vector2.ZERO):
	if state != "RUNNING":return
	track_progress(dt)
	clock += dt;stage_age += dt
	invulnerable = maxf(0, invulnerable - dt);shake = maxf(0, shake - dt)
	message_timer = maxf(0, message_timer - dt)
	if stage == "arrival":
		player_visual.travel = 0;player_moving = false
		animation.advance(self, dt)
		if stage_age >= float(db.data.chapter_four.arrival_duration):stage = "survival";stage_age = 0
		return
	time = minf(db.data.duration, time + dt)
	var before: Vector2 = player
	if movement.length_squared() > 0:
		facing = movement.normalized()
		player = move_actor(player, movement.limit_length() * movement_speed() * dt, 6)
		moved += dt
	tracked_velocity = tracked_velocity.lerp((player - before) / maxf(.0001, dt), minf(1, dt * 10))
	player_visual.travel = before.distance_to(player);player_moving = player_visual.travel > .0001
	flow_timer -= dt
	if flow_timer <= 0 and flow_cell != Vector2i(player / CELL):update_flow();flow_timer = .25
	update_aura()
	if not db.data.chapter_four.exploration_only:spawn_wave(dt)
	move_mobs(dt)
	rebuild_hit_grid()
	update_attacks(dt);update_projectiles(dt);update_explosives(dt)
	update_hazards(dt);update_fire(dt);update_threats(dt);resolve_deaths()
	update_effects(dt);pickup(dt);update_particles(dt)
	animation.advance(self, dt);update_regeneration(dt)
	if hp <= 0:
		state = "RESULT";victory = false;sound("death");return
	if xp >= db.required_xp(level):next_level()
	elif not pending_chest.is_empty():open_chest(pending_chest)
	if not note_presented:
		var note := Vector2(terrain.note[0], terrain.note[1])
		if player.distance_to(note) < 18:note_presented = true;note_pending = true

func movement_speed() -> float:
	return float(db.data.player_speed) * (1 + .08 * items.get("sugar", 0)) * (.15 if held > 0 else 1.0)
