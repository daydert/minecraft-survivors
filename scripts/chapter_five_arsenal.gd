extends RefCounted
## Chapter V equipment: the game's hidden vanilla items, used as weapons.
const OWN := ["debug_stick","command_block","barrier","structure_block","spawn_egg","repeating_block"]
const ALLY_KINDS := ["zombie","zombified_piglin","skeleton"]
var stick_flip := false
## Pending /kill pulses and structure pastes: {p, wait, ...}.
var commands: Array = []
var pastes: Array = []
## Presentation records with an age (beams, pulse text, paste frames).
var beams: Array = []
var notes: Array = []
var orbit := 0.0
var barrier_hits: Dictionary = {}
var light_tick := 0.0
var allies: Array = []
var ally_serial := 0
var history: Array = []
var history_tick := 0.0
var compass_ready := 0.0
var breakpoint_ready := 0.0
var rewinds := 0

func reset():
	stick_flip = false;commands.clear();pastes.clear();beams.clear();notes.clear()
	orbit = 0.0;barrier_hits.clear();light_tick = 0.0;allies.clear();ally_serial = 0
	history.clear();history_tick = 0.0;compass_ready = 0.0;rewinds = 0;breakpoint_ready=0

func rules(w) -> Dictionary:return w.db.data.five_arsenal.rules

func stats(w, id: String) -> Dictionary:
	return w.db.stats(id, w.build[id], w.evolved.has(id), w.items)

## The mob with the most others around it, from the nearest few.
func cluster(w, radius: float, reach: float, avoid: Array = []):
	var near: Array = w.in_radius(w.player, reach).filter(func(m):return m.kind not in ["condition"] and avoid.all(func(q):return q.distance_to(m.p) > radius * 1.5))
	near.sort_custom(func(a, b):return w.player.distance_squared_to(a.p) < w.player.distance_squared_to(b.p))
	near = near.slice(0, 24)
	var best = null;var best_count := -1
	for m in near:
		var count := 0
		for o in near:
			if o.p.distance_to(m.p) < radius:count += 1
		if count > best_count:best_count = count;best = m
	return best

func update_attacks(w, dt: float):
	for id in OWN:
		if not w.build.has(id):continue
		w.cooldowns[id] = w.cooldowns.get(id, 0.0) - dt
		if id == "barrier":continue
		if w.cooldowns[id] > 0:continue
		var s: Dictionary = stats(w, id)
		var evo: bool = w.evolved.has(id)
		match id:
			"debug_stick":
				var target = w.nearest(w.player, s.range)
				if target == null:continue
				stick(w, target, s, evo)
			"repeating_block":
				var c = cluster(w,s.radius,s.range)
				if c==null:continue
				for k in range(int(s.count)+(2 if evo else 0)):
					commands.append({"p":c.p,"wait":.5+k*.24,"radius":s.radius,"damage":s.damage,"chain":0,"done":[],"owner":"repeating_block","stun":evo})
			"command_block":
				var c = cluster(w, s.radius, s.range)
				if c == null:continue
				commands.append({"p":c.p,"wait":float(rules(w).command_delay),"radius":s.radius,"damage":s.damage,"chain":2 if evo else 0,"done":[]})
				w.sound("ch4_hb_tick", .1)
			"structure_block":
				var c = cluster(w, s.radius, s.range)
				if c == null:continue
				pastes.append({"p":c.p,"size":Vector2(s.radius * 2.2, s.radius * 1.5),"wait":float(rules(w).paste_delay),"damage":s.damage,"stun":evo,"age":0.0})
				if evo:
					var other = cluster(w, s.radius, s.range, [c.p])
					if other != null:pastes.append({"p":other.p,"size":Vector2(s.radius * 2.2, s.radius * 1.5),"wait":float(rules(w).paste_delay) + .35,"damage":s.damage,"stun":true,"age":0.0})
				w.sound("ch4_hb_strip", .1)
			"spawn_egg":
				var cap: int = int(s.count)
				if allies.size() >= cap and not evo:
					allies.sort_custom(func(a, b):return a.life < b.life)
					allies.pop_front()
				if allies.size() < cap:
					ally_serial += 1
					var p: Vector2 = w.player + Vector2.from_angle(ally_serial * 2.39996) * 22.0
					allies.append({"p":p,"kind":ALLY_KINDS[ally_serial % ALLY_KINDS.size()],"life":float(s.duration) + 2.0 * w.items.get("name_tag", 0),"bite":0.0,"visual":w.animation.actor(),"dir":Vector2.DOWN,"moving":false,"age":0.0})
					w.add_effect("ch5_spawn", p, .4)
					w.sound("ch4_mob_heal", .1)
		w.cooldowns[id] = s.interval

func stick(w, first: Dictionary, s: Dictionary, evo: bool):
	var targets: Array = [first]
	var reach: int = int(s.count) + (2 if evo else 0)
	while targets.size() < reach:
		var last: Dictionary = targets.back()
		var next = null;var best := 90.0 * 90.0
		for m in w.in_radius(last.p, 90):
			if m in targets or m.kind == "condition":continue
			var d: float = last.p.distance_squared_to(m.p)
			if d < best:best = d;next = m
		if next == null:break
		targets.append(next)
	stick_flip = not stick_flip
	var from: Vector2 = w.player
	for m in targets:
		beams.append({"a":from,"b":m.p,"age":0.0,"mode":"slow" if stick_flip else "shove"})
		from = m.p
		w.damage_owner = "debug_stick"
		if evo and m.hp < m.max_hp * float(rules(w).stick_execute) and m.kind not in ["hijack"] and not (m.kind == "while_loop" and not m.broken):
			w.hurt(m, m.hp + 1)
			notes.append({"p":m.p,"text":"state = DEAD","age":0.0})
			continue
		w.hurt(m, s.damage, w.player.direction_to(m.p))
		if stick_flip or evo:m.slow = maxf(m.get("slow", 0.0), s.duration)
		if not stick_flip or evo:
			if m.kind not in ["condition","hijack","array","while_loop"]:m.knock = w.player.direction_to(m.p) * float(rules(w).stick_shove)
	w.sound("ch4_hb_twitch", .08)

func step(w, dt: float):
	breakpoint_ready=maxf(0,breakpoint_ready-dt)
	var r: Dictionary = rules(w)
	for list in [beams, notes]:
		for i in range(list.size() - 1, -1, -1):
			list[i].age += dt
			if list[i].age > .7:list.remove_at(i)
	for i in range(commands.size() - 1, -1, -1):
		var c: Dictionary = commands[i]
		c.wait -= dt
		if c.wait > 0:continue
		commands.remove_at(i)
		w.damage_owner = c.get("owner","command_block")
		for m in w.in_radius(c.p, c.radius):
			w.hurt(m, c.damage, c.p.direction_to(m.p))
			if c.get("stun",false) and not m.get("boss",false):m.stun=maxf(m.stun,.22)
		w.break_props(c.p, c.radius, c.damage)
		notes.append({"p":c.p,"text":"/kill @e[r=%d]" % int(c.radius / 8),"age":0.0,"radius":c.radius})
		w.add_effect("ch5_kill", c.p, .45, {"radius":c.radius})
		w.sound("ch4_hb_shatter", .06);w.shake = maxf(w.shake, .06)
		if c.chain > 0:
			var done: Array = c.done + [c.p]
			var next = cluster(w, c.radius, 260, done)
			if next != null:commands.append({"p":next.p,"wait":float(r.chain_delay),"radius":c.radius,"damage":c.damage,"chain":c.chain - 1,"done":done})
	for i in range(pastes.size() - 1, -1, -1):
		var p: Dictionary = pastes[i]
		p.age += dt;p.wait -= dt
		if p.wait > 0 or p.get("hit", false):
			if p.get("hit", false) and p.age > p.get("hit_at", 0.0) + .4:pastes.remove_at(i)
			continue
		p.hit = true;p.hit_at = p.age
		var rect := Rect2(p.p - p.size / 2.0, p.size)
		var inside: Array = w.mobs.filter(func(m):return m.hp > 0 and rect.has_point(m.p))
		var damage: float = p.damage * minf(float(r.paste_cap), 1.0 + float(r.paste_bonus) * inside.size())
		w.damage_owner = "structure_block"
		for m in inside:
			w.hurt(m, damage)
			if p.stun and m.get("control_resist", 0.0) <= 0:m.stun = .6;m.control_resist = .8
		w.sound("ch4_ground_slam", .08);w.shake = maxf(w.shake, .1)
	# Barrier blocks orbit the hero; snuff enemy shots and bruise what they touch.
	if w.build.has("barrier"):
		var s: Dictionary = stats(w, "barrier")
		orbit += dt * s.speed
		var count: int = int(s.count)
		var evo: bool = w.evolved.has("barrier")
		light_tick -= dt
		for k in range(count):
			var q: Vector2 = w.player + Vector2.from_angle(orbit + k * TAU / count) * s.radius
			for j in range(w.shots.size() - 1, -1, -1):
				if w.shots[j].delay <= 0 and w.shots[j].p.distance_to(q) < 9:
					w.shots.remove_at(j);notes.append({"p":q,"text":"","age":.35})
			for m in w.in_radius(q, 10):
				if w.clock < barrier_hits.get(m.id, -1.0):continue
				barrier_hits[m.id] = w.clock + s.interval
				w.damage_owner = "barrier"
				w.hurt(m, s.damage, w.player.direction_to(m.p))
			if evo and light_tick <= 0:
				var dir: Vector2 = w.player.direction_to(q)
				var end: Vector2 = q + dir * float(r.beam_length)
				beams.append({"a":q,"b":end,"age":0.0,"mode":"light"})
				w.damage_owner = "barrier"
				for m in w.in_radius(q + dir * float(r.beam_length) / 2.0, float(r.beam_length) / 2.0 + 8):
					if Geometry2D.get_closest_point_to_segment(m.p, q, end).distance_to(m.p) < 10:w.hurt(m, s.damage * 1.5, dir)
		if evo and light_tick <= 0:light_tick = float(r.beam_every)
	update_allies(w, dt)
	# Ctrl+Z: remember where you were, a few seconds back.
	compass_ready = maxf(0, compass_ready - dt)
	history_tick -= dt
	if history_tick <= 0:
		history_tick = .25
		history.append({"p":w.player,"hp":w.hp,"time":w.time})
		while history.size() > 16:history.pop_front()

func update_allies(w, dt: float):
	if not w.build.has("spawn_egg"):
		allies.clear();return
	var s: Dictionary = stats(w, "spawn_egg")
	var evo: bool = w.evolved.has("spawn_egg")
	var damage: float = s.damage * (1.0 + .15 * w.items.get("name_tag", 0)) * (1.6 if evo else 1.0)
	for i in range(allies.size() - 1, -1, -1):
		var a: Dictionary = allies[i]
		a.age += dt;a.bite = maxf(0, a.bite - dt)
		if not evo:
			a.life -= dt
			if a.life <= 0:
				w.add_effect("ch5_spawn", a.p, .4);allies.remove_at(i);continue
		var target = w.nearest(a.p, 200)
		var old: Vector2 = a.p
		var goal: Vector2 = target.p if target != null else w.player + Vector2.from_angle(i * 2.1) * 30
		if a.p.distance_to(goal) > (12 if target != null else 6):
			a.dir = a.p.direction_to(goal)
			a.p = w.move_actor(a.p, a.dir * s.speed * dt, 6)
		if a.p.distance_to(w.player) > 260:a.p = w.player + Vector2.from_angle(i * 2.1) * 30
		if target != null and a.p.distance_to(target.p) < 16 and a.bite <= 0:
			a.bite = float(rules(w).ally_bite)
			w.damage_owner = "spawn_egg"
			w.hurt(target, damage, a.p.direction_to(target.p))
			a.visual.shot_age = 0.0
		a.moving = a.p.distance_squared_to(old) > .0001
		a.visual.gait += a.p.distance_to(old) / 30.0
		w.animation.set_pose(a.visual, "walk" if a.moving else "idle", a.visual.gait if a.moving else a.age)
		if a.visual.shot_age < .25:w.animation.set_pose(a.visual, "attack", a.visual.shot_age)
		a.visual.shot_age += dt

## Called when a blow would kill the hero.
func rewind(w) -> bool:
	var level: int = w.items.get("recovery_compass", 0)
	if level <= 0 or compass_ready > 0 or history.is_empty():return false
	var back: float = float(rules(w).compass_back)
	var mark: Dictionary = history[0]
	for h in history:
		if w.time - h.time >= back:mark = h
	w.add_effect("ch5_rewind", w.player, .5, {"to":mark.p})
	w.player = mark.p
	w.hp = maxf(float(rules(w).compass_hp), minf(mark.hp, 20.0))
	w.invulnerable = 1.5
	compass_ready = float(rules(w).compass_cooldown[mini(level, 5) - 1])
	rewinds += 1
	history.clear()
	notes.append({"p":w.player,"text":"Ctrl+Z","age":0.0})
	w.message = "Ctrl+Z";w.message_timer = 1.2
	w.sound("ch4_hb_teleport", .1)
	return true
