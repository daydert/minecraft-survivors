extends "res://scripts/world.gd"
## One authoritative arena, independent inventories and one life per participant.
## Context switching reuses the original weapon/collision formulas without running
## the arena twice. Only the host calls step_coop; clients are presentation replicas.
const ACTOR_FIELDS = ["player","facing","hp","invulnerable","xp","level","build","items","evolved","cooldowns","tasks","choices","player_visual","attack_visuals","weapon_visuals","pending_chest","chest_reward","chest_delay","moved","player_moving","flow","flow_cell","flow_timer"]
const SPAWN_OFFSETS = [Vector2(-18,0),Vector2(18,0),Vector2(-18,28),Vector2(18,28)]
const PARTY_OFFSETS = [Vector2(-60,-18),Vector2(60,-18),Vector2(-60,38),Vector2(60,38)]
var players: Dictionary = {}
var local_id = 1
var active_id = 0
var run_state = "RUNNING"
var simulating = false
var spawn_index = 0
var finale_driver = 1
var network_sounds: Array = []
var sound_sequence = 0
var navigation_neighbors: Array[PackedInt32Array] = []

func make_map():
	super.make_map()
	# The map is static. Cache exactly the same traversable neighbors used by
	# the original BFS, avoiding thousands of Vector2i/dictionary operations
	# whenever any of four heroes crosses a navigation cell.
	navigation_neighbors.clear()
	for y in range(GRID):
		for x in range(GRID):
			var adjacent = PackedInt32Array()
			for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var n = Vector2i(x,y)+direction
				if n.x < 1 or n.y < 1 or n.x >= GRID-1 or n.y >= GRID-1 or blocked.has(n): continue
				adjacent.append(n.y*GRID+n.x)
			navigation_neighbors.append(adjacent)

func update_flow():
	flow.resize(GRID*GRID)
	flow.fill(-1)
	flow_cell = Vector2i(player/CELL)
	var start = flow_cell.y*GRID+flow_cell.x
	flow[start] = 0
	var queue = PackedInt32Array([start])
	var head = 0
	while head < queue.size():
		var index = queue[head]
		head += 1
		for next in navigation_neighbors[index]:
			if flow[next] >= 0: continue
			flow[next] = flow[index]+1
			queue.append(next)

func configure(seed_value: int, roster: Dictionary, view_id: int):
	active_id = 0
	players.clear()
	reset(seed_value)
	mob_multiplier = 2
	local_id = view_id
	run_state = "RUNNING"
	spawn_index = 0
	network_sounds.clear()
	sound_sequence = 0
	var template = {}
	for field in ACTOR_FIELDS: template[field] = get(field)
	var slot = 0
	for id in roster:
		var a: Dictionary = template.duplicate(true)
		a.merge({"id":id,"nick":roster[id],"slot":slot,"alive":true,"connected":true,"paused":false,"phase":"RUNNING","in_finale":false},true)
		a.player += PARTY_OFFSETS[slot] if roster.size() > 2 else SPAWN_OFFSETS[slot]
		players[id] = a
		slot += 1
	use_actor(local_id)
	refresh_state()

func save_actor():
	if not players.has(active_id): return
	for field in ACTOR_FIELDS: players[active_id][field] = get(field)

func use_actor(id: int):
	if id == active_id or not players.has(id): return
	save_actor()
	active_id = id
	for field in ACTOR_FIELDS: set(field,players[id][field])

func living() -> Array:
	save_actor()
	return players.keys().filter(func(id): return players[id].alive)

func nearest_actor(at: Vector2) -> int:
	var result = active_id
	var best = INF
	for a in players.values():
		if not a.alive: continue
		var distance: float = at.distance_squared_to(a.player)
		if distance < best:
			best = distance
			result = a.id
	return result

func blocked_by() -> String:
	for a in players.values():
		if a.paused or (a.alive and a.phase in ["LEVEL_UP","CHEST"]): return a.nick
	return ""

func can_step() -> bool:
	return run_state in ["RUNNING","FINALE"] and blocked_by().is_empty()

func refresh_state():
	save_actor()
	use_actor(local_id)
	if not players.has(local_id): return
	var a: Dictionary = players[local_id]
	if a.paused: state = "PAUSED"
	elif a.alive and a.phase in ["LEVEL_UP","CHEST"] and run_state == "RUNNING": state = a.phase
	elif run_state == "RESULT": state = "RESULT"
	elif not blocked_by().is_empty(): state = "WAITING"
	elif run_state == "FINALE": state = "FINALE"
	elif not a.alive: state = "SPECTATING"
	else: state = "RUNNING"

func set_paused(id: int, value: bool):
	if not players.has(id) or run_state == "RESULT": return
	players[id].paused = value
	refresh_state()

func choose_for(id: int, index: int):
	if not players.has(id) or not players[id].alive or players[id].phase != "LEVEL_UP": return
	use_actor(id)
	state = "LEVEL_UP"
	super.choose(index)
	players[id].phase = state
	save_actor()
	refresh_state()

func chest_for(id: int):
	if not players.has(id) or players[id].phase != "CHEST": return
	use_actor(id)
	state = "CHEST"
	if chest_delay > 0: chest_delay = 0
	else: super.close_chest()
	players[id].phase = state
	save_actor()
	refresh_state()

func disconnect_actor(id: int):
	if not players.has(id): return
	use_actor(id)
	hp = 0
	save_actor()
	players[id].connected = false
	players[id].paused = false
	players[id].in_finale = false
	if finale.active and id == finale_driver:
		for actor in players.values():
			if actor.id != id and actor.alive and actor.connected and actor.in_finale:
				finale_driver = actor.id
				break
	if run_state == "FINALE":
		# Scripted zero HP after 24 s is part of the portal sequence. A guest
		# leaving must consume only their life, not turn every staged body into
		# an ordinary death and truncate the remaining cinematic.
		players[id].alive = false
		players[id].phase = "DEAD"
		for pool in [tasks,choices,pending_chest,weapon_visuals]: pool.clear()
		if living().is_empty(): run_state = "RESULT"
	else: mark_deaths()
	refresh_state()

func mark_deaths():
	save_actor()
	var saved = active_id
	for a in players.values():
		if a.alive and a.hp <= 0:
			a.hp = 0.0
			a.alive = false
			a.paused = false
			a.phase = "DEAD"
			a.tasks.clear()
			a.choices.clear()
			a.pending_chest.clear()
			a.weapon_visuals.clear()
			sound("death")
	active_id = 0
	use_actor(saved)
	if living().is_empty():
		run_state = "RESULT"
		victory = false

func camera() -> Vector2:
	if simulating: return super.camera()
	var id = local_id
	if players.has(id) and not players[id].alive and not players[id].in_finale:
		for other in players:
			if players[other].alive or players[other].in_finale:
				id = other
				break
	if id == active_id: return super.camera()
	var saved = active_id
	use_actor(id)
	var result = super.camera()
	use_actor(saved)
	return result

func spawn(kind: String, at = null) -> bool:
	var saved = active_id
	var alive = living()
	if at == null and not alive.is_empty():
		use_actor(alive[spawn_index % alive.size()])
		spawn_index += 1
	var result = super.spawn(kind,at)
	use_actor(saved)
	return result

func select_mob_target(at: Vector2):
	use_actor(nearest_actor(at))

func select_attack_owner(attack: Dictionary):
	use_actor(int(attack.get("owner",active_id)))

func burn_damage(mob: Dictionary) -> float:
	var owner: int = mob.get("burn_owner",active_id)
	return 2*(1+.1*players[owner].items.get("blaze",0)) if players.has(owner) else super.burn_damage(mob)

func move_mobs(dt: float):
	var saved = active_id
	save_actor()
	super.move_mobs(dt)
	use_actor(saved)

func update_projectiles(dt: float):
	var saved = active_id
	super.update_projectiles(dt)
	use_actor(saved)

func update_effects(dt: float):
	var saved = active_id
	super.update_effects(dt)
	use_actor(saved)

func sound(id: String, gap: float = .04):
	var count = sounds.size()
	super.sound(id,gap)
	if sounds.size() > count:
		sound_sequence += 1
		network_sounds.append([sound_sequence,id])
		if network_sounds.size() > 32: network_sounds.pop_front()

func damage_area(at: Vector2, radius: float, amount: float, direction: Vector2 = Vector2.ZERO, inclusive: bool = false):
	var saved = active_id
	for a in players.values():
		if not a.alive: continue
		var distance: float = at.distance_squared_to(a.player)
		if distance > radius*radius if inclusive else distance >= radius*radius: continue
		use_actor(a.id)
		super.damage_area(at,radius,amount,direction,inclusive)
	use_actor(saved)

func enemy_arrow_hit(a: Vector2, b: Vector2, amount: float) -> bool:
	var saved = active_id
	var target = 0
	var best = INF
	for actor in players.values():
		if not actor.alive: continue
		var p: Vector2 = actor.player
		var closest = Geometry2D.get_closest_point_to_segment(p,a,b)
		if closest.distance_to(p) < 9 and a.distance_squared_to(closest) < best:
			best = a.distance_squared_to(closest)
			target = actor.id
	if target:
		use_actor(target)
		damage_player(amount)
	use_actor(saved)
	return target != 0

func fire_projectile(kind: String, p: Vector2, direction: Vector2, s: Dictionary, evolution: bool):
	var count = projectiles.size()
	# Weapon capacity follows the party size; enemy spawn remains fixed at x2.
	var multiplier = maxi(2,players.size())
	if count >= int(db.data.projectile_cap) * multiplier: return
	if count >= int(db.data.projectile_cap):
		var old_cap = db.data.projectile_cap
		db.data.projectile_cap = old_cap * multiplier
		super.fire_projectile(kind,p,direction,s,evolution)
		db.data.projectile_cap = old_cap
	else: super.fire_projectile(kind,p,direction,s,evolution)
	if projectiles.size() > count: projectiles.back().merge({"id":next_id(),"owner":active_id})

func add_effect(kind: String, p: Vector2, life: float, extra: Dictionary = {}):
	var fields = extra.duplicate()
	fields.merge({"id":next_id(),"owner":active_id})
	super.add_effect(kind,p,life,fields)

func effect_cap() -> int:
	return 320*maxi(2,players.size())

func drop_xp(p: Vector2, value: int):
	super.drop_xp(p,value)
	if not orbs.is_empty() and not orbs.back().has("id"): orbs.back().id = next_id()

func apply_upgrade(id: String):
	# An apple can never resurrect a hero killed earlier in this same tick.
	if id == "apple" and hp <= 0: return
	super.apply_upgrade(id)

func can_pickup_orb(orb: Dictionary) -> bool:
	var owner: int = orb.get("collector",0)
	if owner and (not players.has(owner) or not players[owner].alive):
		owner = 0
		orb.attracted = false
	if not owner:
		var best = INF
		for a in players.values():
			if not a.alive: continue
			var radius = 24*(1+.3*a.items.get("hopper",0))
			var distance: float = a.player.distance_squared_to(orb.p)
			if distance <= radius*radius and distance < best:
				owner = a.id
				best = distance
		orb.collector = owner
	return owner == active_id

func step_coop(dt: float, inputs: Dictionary):
	if not can_step():
		refresh_state()
		return
	simulating = true
	if run_state == "FINALE":
		step_finale(dt,inputs)
		simulating = false
		refresh_state()
		return
	time += dt
	clock += dt
	shake = maxf(0,shake-dt)
	message_timer = maxf(0,message_timer-dt)
	for id in living():
		use_actor(id)
		invulnerable = maxf(0,invulnerable-dt)
		move_player(dt,inputs.get(id,Vector2.ZERO))
		flow_timer -= dt
		if flow_timer <= 0 and flow_cell != Vector2i(player/CELL):
			update_flow()
			flow_timer = .2
	spawn_wave(dt)
	move_mobs(dt)
	rebuild_hit_grid()
	for id in living():
		use_actor(id)
		if hp > 0: update_attacks(dt)
	update_projectiles(dt)
	update_effects(dt)
	resolve_deaths()
	for id in living():
		use_actor(id)
		if hp > 0: pickup(dt)
	update_particles(dt)
	var first = true
	for id in living():
		use_actor(id)
		animation.advance(self,dt,first)
		if first:
			for mob in mobs:
				if mob.kind == "skeleton" and mob.visual.state in ["windup","attack","recover"]:
					mob.visual_dir = mob.p.direction_to(players[nearest_actor(mob.p)].player)
		first = false
	mark_deaths()
	if run_state != "RESULT":
		if time >= float(db.data.duration): begin_finale()
		else:
			for id in living():
				use_actor(id)
				state = "RUNNING"
				if xp >= db.required_xp(level): next_level()
				elif not pending_chest.is_empty(): open_chest(pending_chest)
				players[id].phase = state
	simulating = false
	refresh_state()

func move_player(dt: float, movement: Vector2):
	var old = player
	movement = movement.limit_length()
	if movement != Vector2.ZERO:
		facing = movement.normalized()
		player = move_actor(player,movement*db.data.player_speed*(1+.08*items.get("sugar",0))*dt,6)
		moved += dt
	player_visual.travel = old.distance_to(player)
	player_moving = player_visual.travel > .0001

func begin_finale():
	var alive = living()
	if alive.is_empty(): return
	finale_driver = alive[0]
	use_actor(finale_driver)
	finale.begin(self)
	run_state = "FINALE"
	for id in alive:
		use_actor(id)
		var spacing = 108 if alive.size() > 2 else 36
		player = finale.CENTER+Vector2((alive.find(id)-(alive.size()-1)/2.0)*spacing,112)
		facing = Vector2.UP
		invulnerable = 0
		player_moving = false
		players[id].in_finale = true
		players[id].phase = "RUNNING"
		for pool in [tasks,choices,attack_visuals,weapon_visuals,pending_chest]: pool.clear()
	save_actor()

func step_finale(dt: float, inputs: Dictionary):
	clock += dt
	use_actor(finale_driver)
	state = "FINALE"
	finale.step(self,dt,inputs.get(finale_driver,Vector2.ZERO))
	save_actor()
	for id in players:
		if id == finale_driver or not players[id].in_finale: continue
		use_actor(id)
		invulnerable = maxf(0,invulnerable-dt)
		if finale.phase in ["storm","inferno"]:
			move_player(dt,inputs.get(id,Vector2.ZERO))
			update_attacks(dt)
			for s in finale.strikes:
				if s.age >= .7 and s.age-dt < .7 and s.p.distance_to(player) < 26: finale.hit(self,5)
			for wave in finale.waves:
				if absf(player.distance_to(finale.CENTER)-wave.radius) < 24: finale.hit(self,6)
			animation.advance(self,dt,false)
		if finale.elapsed >= 24:
			hp = 0.0
			player_moving = false
			weapon_visuals.clear()
		save_actor()
	if finale.complete:
		for a in players.values():
			a.hp = 0.0
			a.alive = false
		run_state = "RESULT"
		victory = false
