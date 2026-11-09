extends RefCounted
## Chapter IV finale: Herobrine in three stages, the fistfight, his death, the
## coordinates, the road and the black door. One state machine on world time;
## every warning, hit and pose reads the same geometry. Its own RNG (seeded from
## the run) never touches the combat RNG of the rest of the chapter.
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_finale.json"))
var rng := RandomNumberGenerator.new()
var phase := ""            # summit intro one kneel two erase three death coords road door done retry
var age := 0.0
var started := false
var hb: Dictionary = {}
var center := Vector2.ZERO
var arena := Rect2()
var move := ""             # current Herobrine action in a fight stage
var move_age := 0.0
var move_time := 0.0
var queue: Array = []
var shots: Array = []
var marks: Array = []      # lightning marks
var rings: Array = []
var lanes: Array = []
var hole: Dictionary = {}
var path: Array = []       # blitz points
var strips: Array = []     # rift strips
var seam: Dictionary = {}
var sky := 0.0             # 0 night .. 1 day (stage II day acceleration)
var split := 0.0           # frozen impossible day+night
var looked := false
var face := "calm"
var pose := "idle"
var pose_age := 0.0
var day_done: Array = []
var stored: Dictionary = {}
var checkpoint: Dictionary = {}
var qte_index := 0
var qte: Dictionary = {}
var presses: Array = []
var hold := false
var steve_pose := "idle"
var steve_pose_age := 0.0
var steve_at := Vector2.ZERO
var text_events: Array = []
var silence := false
var music := ""
var camera_at := Vector2.ZERO
var retry_from := ""
var flash := 0.0
var glitch := 0.0
var road_index := 0
var door_state := ""

func reset(w):
	rng.seed = int(w.rng.seed) ^ 0x4e7b19
	phase = ""; age = 0.0; started = false; hb = {}; move = ""; queue.clear(); shots.clear(); marks.clear(); rings.clear()
	lanes.clear(); hole = {}; path.clear(); strips.clear(); seam = {}; sky = 0.0; split = 0.0; looked = false; face = "calm"
	pose = "idle"; pose_age = 0.0; day_done.clear(); stored = {}; checkpoint = {}; qte_index = 0; qte = {}; presses.clear()
	hold = false; steve_pose = "idle"; text_events.clear(); silence = false; music = ""; retry_from = ""; flash = 0.0; glitch = 0.0
	road_index = 0; door_state = ""
	var pyramid := Vector2(w.terrain.pyramid[0], w.terrain.pyramid[1])
	center = pyramid + Vector2(data.arena.offset[0], data.arena.offset[1])
	var size := Vector2(data.arena.size[0], data.arena.size[1])
	arena = Rect2(center - size / 2, size)

func active() -> bool:
	return phase != "" and phase != "done"

## Phases in which the world stands still: no spawns, weapons or free movement.
func locked() -> bool:
	return phase in ["intro", "kneel", "erase", "three", "death", "coords", "road", "door", "retry"]

func fighting() -> bool:
	return phase in ["one", "two"]

# ------------------------------------------------------------------ entry

func begin_summit(w):
	phase = "summit"; age = 0.0
	for m in w.mobs:
		if m.has("form") and m.hp > 0:
			m.expired = true; m.hp = 0
			w.add_effect("ch4_remains", m.p, .6, {"skin": m.skin, "dir": m.visual_dir})
	w.message = "Пирамида"; w.message_timer = 3; w.sound("ch4_guardian_awake")

func start_intro(w):
	phase = "intro"; age = 0.0; started = true
	w.mobs = w.mobs.filter(func(m): return not m.has("form"))
	clear_arena(w)
	hb = {"finale_actor": "herobrine", "id": w.next_id(), "kind": "herobrine4", "p": center + Vector2(0, -110), "hp": float(data.one.hp),
		"max_hp": float(data.one.hp), "radius": float(data.one.radius), "boss": true, "undead": true, "allied": false, "flash": 0.0,
		"burn": 0.0, "burn_tick": .5, "stun": 0.0, "pull_left": 0.0, "control_resist": 99.0, "slow": 0.0, "visual": w.animation.actor(),
		"dir": Vector2.UP, "visual_dir": Vector2.UP, "animation": 0.0, "moving": false, "knock": Vector2.ZERO, "xp": 0, "speed": 0.0,
		"damage": 3.0, "timer": 0.0, "phase": "idle", "deflect": -10.0, "ch4_cracks": 0}
	w.player = center + Vector2(0, 104); w.facing = Vector2.UP
	set_pose("cast"); face = "calm"; music = ""
	camera_at = w.player

func clear_arena(w):
	var grow := arena.grow(30)
	w.props = w.props.filter(func(o): return not grow.has_point(o.p))
	for key in w.solid_grid.keys():
		w.solid_grid[key] = w.solid_grid[key].filter(func(s): return not grow.has_point(s.p))
	for cell in w.blocked.keys():
		if grow.has_point(Vector2(cell) * w.CELL):w.blocked.erase(cell)
	for mark in w.landmarks:
		if mark.kind != "pyramid" and grow.has_point(mark.p):mark.dead = true
	w.update_flow()

func set_pose(name: String):
	if pose != name:
		pose = name; pose_age = 0.0

func set_steve(name: String):
	if steve_pose != name:
		steve_pose = name; steve_pose_age = 0.0

func say(text: String, style: String, duration: float, cut: float = -1.0):
	text_events.append({"text": text, "style": style, "at": age, "life": duration, "cut": cut, "phase": phase})

# ------------------------------------------------------------------ world hooks

func candidates() -> Array:
	return [hb] if fighting() and not hb.is_empty() and hb.hp > 0 else []

func hurt(w, m: Dictionary, amount: float, push: Vector2):
	if not fighting() or m.hp <= 0:
		return
	var scale := 1.0
	if move == "day" and move_age < move_time - float(data.two.day.stun):scale = float(data.two.day.float_guard)
	if move in ["stunned", "landed"]:scale = float(data.two.day.stun_bonus) if move == "stunned" else 1.5
	if move == "look":scale = 1.25
	var dealt := minf(m.hp, amount * scale)
	m.hp -= dealt; m.flash = .1; m.visual.hurt = .12
	w.damage_by[w.damage_owner] = w.damage_by.get(w.damage_owner, 0.0) + dealt
	w.add_effect("damage", m.p - Vector2(0, 26), .5, {"amount": ceili(dealt)})
	w.emit_pixels("impact", m.p - Vector2(0, 14), 3, push)
	if phase == "one":
		m.deflect = w.clock
		if not looked and m.hp < m.max_hp * float(data.one.look_threshold) and move != "blink":
			looked = true; begin_move(w, "look", float(data.one.look_time))
	if m.hp <= 0:
		m.hp = 0
		if phase == "one":begin_kneel(w)
		elif phase == "two":begin_erase(w)

func hooked(_w, _m: Dictionary):
	pass

func camera(w) -> Vector2:
	match phase:
		"intro":
			var focus: Vector2 = hb.p + Vector2(0, 30)
			return w.player.lerp(focus, smoothstep(0.4, 2.2, age) * (1.0 - smoothstep(6.4, 7.4, age) * 0.6))
		"one", "two":
			var mid: Vector2 = (w.player + hb.p) / 2 + Vector2(0, -12)
			mid.x = clampf(mid.x, w.player.x - 230, w.player.x + 230); mid.y = clampf(mid.y, w.player.y - 110, w.player.y + 100)
			camera_at = camera_at.lerp(mid, .08)
			return camera_at
		"kneel", "erase":
			return (w.player + hb.p) / 2 + Vector2(0, -16)
		"three", "death", "retry":
			return center + Vector2(0, -6)
		"coords":
			return w.player + Vector2(0, -10)
		"road", "door":
			return camera_at
	return w.player

# ------------------------------------------------------------------ step

func step(w, dt: float, movement: Vector2):
	age += dt
	pose_age += dt; steve_pose_age += dt
	flash = maxf(0.0, flash - dt); glitch = maxf(0.0, glitch - dt)
	for i in range(text_events.size() - 1, -1, -1):
		if age - text_events[i].at > text_events[i].life:text_events.remove_at(i)
	if not hb.is_empty():
		hb.animation += dt; hb.flash = maxf(0, hb.flash - dt)
		if hb.visual.has("hurt"):hb.visual.hurt = maxf(0, hb.visual.hurt - dt)
	match phase:
		"summit":
			if w.player.distance_to(center) < float(data.summit_trigger):start_intro(w)
		"intro":step_intro(w)
		"one", "two":step_fight(w, dt)
		"kneel":step_kneel(w)
		"erase":step_erase(w)
		"three":step_three(w, dt)
		"retry":
			if age > 2.2:restore_checkpoint(w)
		"death":step_death(w, dt)
		"coords":step_coords(w)
		"road":step_road(w, dt)
		"door":step_door(w, dt)
	update_shots(w, dt)
	if w.hp <= 0 and phase in ["one", "two", "three"]:
		begin_retry(w)

func step_intro(w):
	var turn: Array = data.intro.turn
	if age < turn[0]:
		set_pose("cast"); hb.visual_dir = Vector2.UP
	elif age < turn[1]:
		set_pose("idle")
		var k: float = (age - float(turn[0])) / (float(turn[1]) - float(turn[0]))
		hb.visual_dir = Vector2.UP if k < 0.35 else (Vector2.RIGHT if k < 0.7 else Vector2.DOWN)
		if pose_age < .02 or abs(k - 0.35) < .01 or abs(k - 0.7) < .01:w.sound("ch4_hb_twitch", .3)
	else:
		hb.visual_dir = Vector2.DOWN
	if age >= float(data.intro.line_at) and text_events.is_empty() and age < float(data.intro.line_at) + .1:
		say("Ты опять здесь.", "calm", 2.6)
	if age >= 6.2:set_pose("invite"); face = "smile"
	if age >= float(data.intro.duration):
		phase = "one"; age = 0.0; face = "calm"; set_pose("idle"); music = "boss_one"
		begin_move(w, "rest", 1.0); save_checkpoint(w, "one")

func step_kneel(w):
	var k: Dictionary = data.kneel
	if age < float(k.rise_at):set_pose("kneel"); silence = true
	elif age < float(k.rise_at) + 1.3:set_pose("rise"); face = "smile"
	else:set_pose("idle")
	if age >= float(k.line_at) and not text_events.any(func(t): return t.phase == "kneel"):
		say("Хорошо. Давай всерьёз.", "calm", 2.4)
	if age >= float(k.duration):
		phase = "two"; age = 0.0; silence = false; music = "boss_two"
		hb.hp = float(data.two.hp); hb.max_hp = hb.hp; face = "smile"
		begin_move(w, "invite", 1.6); save_checkpoint(w, "two")

func begin_kneel(w):
	phase = "kneel"; age = 0.0; clear_hazards(); face = "calm"; music = ""
	w.sound("ch4_hb_freeze")

func begin_erase(w):
	phase = "erase"; age = 0.0; clear_hazards(); face = "rage"; music = ""; sky = 0.0; split = 0.0
	set_pose("cast"); glitch = 1.2; w.sound("ch4_hb_glitch")
	hb.p = center + Vector2(30, -6); w.player = center + Vector2(-30, 6); w.facing = Vector2.RIGHT; hb.visual_dir = Vector2.LEFT

func step_erase(w):
	var d: float = float(data.erase.duration)
	if age > 1.2 and stored.is_empty():
		stored = {"build": w.build.duplicate(), "items": w.items.duplicate(), "evolved": w.evolved.duplicate()}
		w.build = {}; w.items = {}; w.evolved = {}
		w.sound("ch4_hb_shatter"); flash = .3
	if age > 2.4:face = "dim"
	if age > 3.0 and age < 3.1:set_pose("guard"); w.sound("ch4_hb_freeze"); glitch = .5
	if age > 3.6:set_pose("idle")
	if age >= d:
		phase = "three"; age = 0.0; qte_index = 0; qte = {}
		w.hp = maxf(w.hp, float(data.three.steve_hp))
		hb.p = center + Vector2(26, 0); w.player = center + Vector2(-26, 0); w.facing = Vector2.RIGHT
		save_checkpoint(w, "three"); next_qte(w)

# ------------------------------------------------------------------ stages I / II

func begin_move(_w, name: String, duration: float):
	move = name; move_age = 0.0; move_time = duration

func step_fight(w, dt: float):
	move_age += dt
	var two := phase == "two"
	var angry: bool = two and hb.hp < hb.max_hp * float(data.two.angry_below)
	var speed: float = float(data.two.angry_speed) if angry else 1.0
	if two:face = "smile" if hb.hp > hb.max_hp * .7 else ("rage" if angry else "calm")
	hb.visual_dir = hb.p.direction_to(w.player) if move not in ["blitz_dash"] else hb.visual_dir
	# Stage I: a close hero gets a short contemptuous blink away.
	if phase == "one" and move == "rest" and w.player.distance_to(hb.p) < float(data.one.blink_range) and w.clock - hb.get("blinked", -10.0) > float(data.one.blink_cooldown):
		blink(w, hb.p + w.player.direction_to(hb.p).rotated(rng.randf_range(-1, 1)) * float(data.one.blink_distance))
	match move:
		"rest":
			set_pose("deflect" if w.clock - hb.deflect < .35 and phase == "one" else "idle")
			if move_age >= move_time:next_attack(w)
		"look":
			set_pose("look_hand")
			if move_age >= move_time:begin_move(w, "rest", .6); face = "calm"
		"invite":
			set_pose("invite")
			if move_age >= move_time:begin_move(w, "rest", .4)
		"lightning":step_lightning(w)
		"ring":step_ring(w, dt)
		"strike":step_strike(w)
		"hole":step_hole(w, dt)
		"blitz_mark", "blitz_dash", "landed":step_blitz(w, dt)
		"rain":step_rain(w)
		"rift":step_rift(w)
		"tear":step_tear(w)
		"day":step_day(w)
		"stunned":
			set_pose("kneel" if move_age < move_time - .8 else "rise")
			if move_age >= move_time:begin_move(w, "rest", .8)
	if move_age > 0 and speed > 1.0 and move in ["rest"]:move_age += dt * (speed - 1.0)
	hb.p = hb.p.clamp(arena.position + Vector2(20, 20), arena.end - Vector2(20, 20))

func next_attack(w):
	if queue.is_empty():
		if phase == "one":
			queue = ["lightning", "ring", "strike", "lightning", "strike", "ring"]
		else:
			queue = ["hole", "blitz", "rain", "rift", "tear", "blitz", "hole", "rain"]
	if phase == "two":
		for i in range(data.two.day.at.size()):
			if not day_done.has(i) and hb.hp < hb.max_hp * float(data.two.day.at[i]):
				day_done.append(i); start(w, "day"); return
	start(w, queue.pop_front())

func rest(w, extra: float = 0.0):
	var r = data.one.rest if phase == "one" else [data.two.rest, data.two.rest]
	begin_move(w, "rest", rng.randf_range(float(r[0]), float(r[1])) + extra)

func start(w, name: String):
	match name:
		"lightning":
			var l: Dictionary = data.one.lightning
			marks.clear()
			for i in range(3):
				var off := Vector2.from_angle(i * TAU / 3 + rng.randf() * TAU) * float(l.spread) * (0.4 if i == 0 else 1.0)
				marks.append({"p": w.player + w.tracked_velocity * 0.35 + off, "age": 0.0, "hit": false})
			begin_move(w, "lightning", float(l.windup) + .5); set_pose("cast"); w.sound("ch4_hb_charge", .2)
		"ring":
			var r: Dictionary = data.one.ring
			rings = [{"p": w.player, "gap": rng.randf() * TAU, "age": 0.0}]
			begin_move(w, "ring", float(r.windup) + float(r.time)); set_pose("cast"); w.sound("ch4_hb_fire", .2)
		"strike":
			blink(w, w.player - w.facing.normalized() * 58 if w.facing.length_squared() > 0 else w.player + Vector2(0, 58))
			var s: Dictionary = data.one.strike
			lanes = [{"a": hb.p, "b": hb.p + hb.p.direction_to(w.player) * float(s.length), "age": 0.0, "hit": false}]
			begin_move(w, "strike", float(s.windup) + .35); set_pose("slam")
		"hole":
			var at: Vector2 = (w.player + Vector2.from_angle(rng.randf() * TAU) * 90.0).clamp(arena.position + Vector2(40, 40), arena.end - Vector2(40, 40))
			hole = {"p": at, "age": 0.0, "burst": false}
			begin_move(w, "hole", float(data.two.hole.grow) + 1.2); set_pose("cast"); w.sound("ch4_hb_blackhole", .2)
		"blitz":
			path.clear()
			var b: Dictionary = data.two.blitz
			var last: Vector2 = hb.p
			for i in range(int(b.points)):
				var target: Vector2 = w.player + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40.0, 110.0)
				target = target.clamp(arena.position + Vector2(24, 24), arena.end - Vector2(24, 24))
				path.append({"a": last, "b": target, "t": 0.0})
				last = target
			begin_move(w, "blitz_mark", float(b.mark) * path.size() + float(b.delay)); set_pose("guard")
		"rain":
			var r: Dictionary = data.two.rain
			begin_move(w, "rain", float(r.time)); set_pose("cast"); w.sound("ch4_hb_rain", .2)
		"rift":
			strips.clear()
			var rr: Dictionary = data.two.rift
			for i in range(int(rr.strips)):
				var y: float = arena.position.y + arena.size.y * (0.33 + 0.34 * i) + rng.randf_range(-20, 20)
				var gaps: Array = [rng.randf_range(arena.position.x + 40, arena.end.x - 120)]
				gaps.append(gaps[0] + rng.randf_range(110, 180))
				strips.append({"y": y, "gaps": gaps, "raised": false})
			begin_move(w, "rift", float(rr.windup) + float(rr.hold)); set_pose("cast"); w.sound("ch4_hb_rift", .2)
		"tear":
			var t: Dictionary = data.two.tear
			var x: float = clampf(w.player.x + rng.randf_range(-60, 60), arena.position.x + 60, arena.end.x - 60)
			var bridges: Array = []
			for i in range(int(t.bridges)):bridges.append(arena.position.y + arena.size.y * (0.25 + 0.5 * i) + rng.randf_range(-24, 24))
			seam = {"x": x, "bridges": bridges, "pulses": []}
			begin_move(w, "tear", float(t.windup) + float(t.time)); set_pose("cast"); w.sound("ch4_hb_rift", .2)
		"day":
			hb.p = center + Vector2(0, -40)
			var d: Dictionary = data.two.day
			var total := 0.0
			for c in d.cycles:total += float(c)
			begin_move(w, "day", 1.0 + total + float(d.freeze) + 1.2 + float(d.stun)); set_pose("float"); w.sound("ch4_hb_day", .2)
			hb.ring_fired = []

func blink(w, to: Vector2):
	w.add_effect("ch4_hb_blink", hb.p, .45, {"dir": hb.visual_dir})
	hb.p = to.clamp(arena.position + Vector2(20, 20), arena.end - Vector2(20, 20))
	hb.blinked = w.clock
	w.add_effect("ch4_hb_blink", hb.p, .45, {"dir": hb.visual_dir})
	w.sound("ch4_hb_teleport", .2)

func step_lightning(w):
	var l: Dictionary = data.one.lightning
	for m in marks:
		m.age = move_age
		if not m.hit and move_age >= float(l.windup):
			m.hit = true
			w.add_effect("ch4_hb_bolt", m.p, .4, {"radius": float(l.radius)})
			if w.player.distance_to(m.p) < float(l.radius):w.receive_hit(float(l.damage), hb)
			flash = .12; w.sound("ch4_hb_lightning", .1)
	if move_age >= move_time:marks.clear(); rest(w)

func step_ring(w, dt: float):
	var r: Dictionary = data.one.ring
	for ring in rings:
		ring.age = move_age
		if move_age < float(r.windup):continue
		var k := clampf((move_age - float(r.windup)) / float(r.time), 0, 1)
		ring.r = lerpf(float(r.start), float(r.end), k)
		var off: Vector2 = w.player - ring.p
		var a := off.angle()
		var in_gap := absf(angle_difference(a, ring.gap)) < float(r.gap) * 0.5
		if absf(off.length() - ring.r) < float(r.band) and not in_gap:w.receive_hit(float(r.damage), hb)
	if move_age >= move_time:rings.clear(); rest(w)

func step_strike(w):
	var s: Dictionary = data.one.strike
	for lane in lanes:
		lane.age = move_age
		if not lane.hit and move_age >= float(s.windup):
			lane.hit = true
			hb.p = lane.b
			w.add_effect("ch4_hb_slash", lane.a, .3, {"end": lane.b, "width": float(s.width)})
			if Geometry2D.get_closest_point_to_segment(w.player, lane.a, lane.b).distance_to(w.player) < float(s.width):w.receive_hit(float(s.damage), hb)
			w.sound("ch4_heavy", .1)
	if move_age >= move_time:lanes.clear(); rest(w)

func step_hole(w, dt: float):
	var h: Dictionary = data.two.hole
	hole.age = move_age
	var grow: float = float(h.grow)
	if move_age < grow:
		var pull: float = float(h.pull) * smoothstep(0.0, grow, move_age)
		w.player = w.move_actor(w.player, w.player.direction_to(hole.p) * pull * dt, 6)
		for b in shots:b.v = b.v.lerp(b.p.direction_to(hole.p) * b.v.length(), dt * 0.8)
	elif not hole.burst:
		hole.burst = true
		if w.player.distance_to(hole.p) < float(h.radius):w.receive_hit(float(h.damage), hb)
		var count := int(h.debris)
		var gap_every := count / int(h.gaps)
		var turn := rng.randf() * TAU
		for i in range(count):
			if i % gap_every < 2:continue
			var dir := Vector2.from_angle(turn + i * TAU / count)
			shots.append({"p": hole.p, "v": dir * float(h.speed), "r": 4.0, "damage": 3.0, "kind": "debris", "life": 3.0})
		flash = .15; w.shake = .25; w.sound("ch4_hb_collapse", .1)
	if move_age >= move_time:hole = {}; rest(w)

func step_blitz(w, dt: float):
	var b: Dictionary = data.two.blitz
	var mark_time: float = float(b.mark)
	if move == "blitz_mark":
		var shown := int(move_age / mark_time)
		for i in range(path.size()):
			if i < shown and not path[i].get("marked", false):
				path[i].marked = true; hb.p = path[i].b; w.sound("ch4_hb_teleport", .1)
				w.add_effect("ch4_hb_blink", hb.p, .3, {"dir": hb.visual_dir})
		if move_age >= move_time:
			hb.p = path[0].a; begin_move(w, "blitz_dash", 9.0); set_pose("jab"); hb.leg = 0; hb.leg_t = 0.0
			w.sound("ch4_hb_blitz", .1)
	elif move == "blitz_dash":
		var leg: Dictionary = path[hb.leg]
		var length: float = maxf(1.0, leg.a.distance_to(leg.b))
		hb.leg_t += float(b.speed) * dt / length
		var before: Vector2 = hb.p
		hb.p = leg.a.lerp(leg.b, minf(1.0, hb.leg_t))
		hb.visual_dir = leg.a.direction_to(leg.b)
		leg.t = hb.leg_t
		if Geometry2D.get_closest_point_to_segment(w.player, before, hb.p).distance_to(w.player) < float(b.width):w.receive_hit(float(b.damage), hb)
		if hb.leg_t >= 1.0:
			hb.leg += 1; hb.leg_t = 0.0
			if hb.leg >= path.size():
				begin_move(w, "landed", float(b.stagger)); set_pose("stagger"); w.shake = .2; w.sound("ch4_ground_slam", .1)
				path.clear()
	elif move == "landed":
		set_pose("kneel" if move_age < move_time * 0.7 else "rise")
		if move_age >= move_time:rest(w)

func step_rain(w):
	var r: Dictionary = data.two.rain
	var lanes_n := int(r.lanes)
	var every: float = float(r.every)
	var tick := int(move_age / every)
	if tick != hb.get("rain_tick", -1):
		hb.rain_tick = tick
		var safe := int(round((sin(move_age * 1.3 + hb.max_hp) * 0.5 + 0.5) * (lanes_n - 1)))
		for i in range(lanes_n):
			if absi(i - safe) <= int(r.safe) - 1:continue
			if (i + tick) % 2 == 1:continue
			var x: float = arena.position.x + (i + 0.5) * arena.size.x / lanes_n
			shots.append({"p": Vector2(x, arena.position.y - 10), "v": Vector2(0, float(r.speed)), "r": 3.0, "damage": float(r.damage), "kind": "rain", "life": 2.2})
		hb.rain_safe = safe
	if move_age >= move_time:rest(w)

func step_rift(w):
	var rr: Dictionary = data.two.rift
	var windup: float = float(rr.windup)
	for s in strips:
		if move_age >= windup and not s.raised:
			s.raised = true
			raise_strip(w, s, true); w.shake = .2; w.sound("ch4_stone_rise", .1)
	if move_age >= move_time:
		for s in strips:raise_strip(w, s, false)
		strips.clear(); rest(w)

func raise_strip(w, s: Dictionary, up: bool):
	var height: float = float(data.two.rift.height)
	var gap: float = float(data.two.rift.gap)
	var x := arena.position.x
	while x < arena.end.x:
		var open := false
		for g in s.gaps:
			if x > g and x < g + gap:open = true
		if not open:
			for dy in [-height / 3, 0.0, height / 3]:
				var p := Vector2(x, s.y + dy)
				var cell := Vector2i(p / 64.0)
				if up:
					if not w.solid_grid.has(cell):w.solid_grid[cell] = []
					w.solid_grid[cell].append({"p": p, "r": 7.0, "rift": true})
				elif w.solid_grid.has(cell):
					w.solid_grid[cell] = w.solid_grid[cell].filter(func(o): return not o.get("rift", false))
		x += 12.0
	# The hero is never sealed inside a raised strip.
	if up and absf(w.player.y - s.y) < height * 0.7:
		w.player.y = s.y + (height * 0.8 if w.player.y >= s.y else -height * 0.8)

func step_tear(w):
	var t: Dictionary = data.two.tear
	if move_age >= float(t.windup):
		var run := move_age - float(t.windup)
		seam.pulses = []
		for i in range(int(t.pulses)):
			var y := fposmod(run * float(t.pulse_speed) + i * arena.size.y / float(t.pulses), arena.size.y) + arena.position.y
			seam.pulses.append(y)
			var on_bridge := false
			for b in seam.bridges:
				if absf(y - b) < 18:on_bridge = true
			if not on_bridge and absf(w.player.x - seam.x) < float(t.width) and absf(w.player.y - y) < 12:w.receive_hit(float(t.damage), hb)
	if move_age >= move_time:seam = {}; rest(w)

func step_day(w):
	var d: Dictionary = data.two.day
	var t := move_age - 1.0
	var cycles: Array = d.cycles
	var elapsed := 0.0
	split = 0.0
	if t < 0:
		sky = 0.0; set_pose("float"); return
	for i in range(cycles.size()):
		var c: float = float(cycles[i])
		if t < elapsed + c:
			var k := (t - elapsed) / c
			sky = 0.5 - 0.5 * cos(k * TAU)
			if k >= 0.5 and not hb.ring_fired.has(i):
				hb.ring_fired.append(i)
				radial(w, int(d.ring), float(d.speed) * (1.0 + i * 0.18), i * 0.37)
				w.sound("ch4_hb_pulse", .05)
			set_pose("float"); return
		elapsed += c
	t -= elapsed
	if t < float(d.freeze):
		sky = 0.5; split = 1.0; set_pose("cast"); return
	t -= float(d.freeze)
	if t < 1.2:
		split = 1.0 - t / 1.2
		var n := int(t / (1.2 / float(d.finale_rings)))
		if not hb.ring_fired.has(10 + n) and n < int(d.finale_rings):
			hb.ring_fired.append(10 + n); radial(w, int(d.ring) + 6, float(d.speed) * 1.5, n * 0.5); flash = .1
		set_pose("slam"); return
	sky = 0.0; split = 0.0
	if move != "stunned":
		begin_move(w, "stunned", float(d.stun)); w.sound("ch4_hb_freeze")

func radial(_w, count: int, speed: float, turn: float):
	for i in range(count):
		var dir := Vector2.from_angle(turn + i * TAU / count)
		shots.append({"p": hb.p, "v": dir * speed, "r": 3.0, "damage": float(data.two.day.damage), "kind": "day", "life": 3.0})

func update_shots(w, dt: float):
	for i in range(shots.size() - 1, -1, -1):
		var b: Dictionary = shots[i]
		var before: Vector2 = b.p
		b.p += b.v * dt; b.life -= dt
		var dead: bool = b.life <= 0 or not arena.grow(40).has_point(b.p)
		if fighting() and Geometry2D.get_closest_point_to_segment(w.player, before, b.p).distance_to(w.player) < b.r + 5:
			w.receive_hit(b.damage, hb); dead = true
		if dead:shots.remove_at(i)

func clear_hazards():
	shots.clear(); marks.clear(); rings.clear(); lanes.clear(); hole = {}; path.clear(); seam = {}
	move = ""; sky = 0.0; split = 0.0

# ------------------------------------------------------------------ stage III: the fistfight

func press(action: String):
	if phase == "three":presses.append(action)

func next_qte(w):
	var events: Array = data.three.events
	if qte_index >= events.size():
		begin_death(w); return
	qte = events[qte_index].duplicate(true)
	qte.age = 0.0; qte.windup = 0.55; qte.progress = 0; qte.held = 0.0; qte.result = ""
	presses.clear()
	set_pose(qte.hb if qte.kind != "attack" else "guard"); set_steve("guard")
	if qte.kind == "hold":set_pose("grab")

func step_three(w, dt: float):
	if qte.is_empty():return
	qte.age += dt
	var open: bool = qte.age >= qte.windup and qte.result == ""
	var close: float = qte.windup + float(qte.window)
	if qte.result == "":
		if open:
			match qte.kind:
				"dodge":
					for p in presses:
						if p == qte.dir:qte.result = "ok"
						elif p != "attack":qte.result = "fail"
				"attack":
					for p in presses:
						if p == "attack":qte.result = "ok"
				"hold":
					qte.held = qte.held + dt if hold else maxf(0.0, qte.held - dt * 0.5)
					if qte.held >= float(qte.window) * 0.75:qte.result = "ok"
				"seq":
					for p in presses:
						if qte.progress < qte.dirs.size() and p == qte.dirs[qte.progress]:qte.progress += 1
						elif p != "attack":qte.result = "fail"
					if qte.progress >= qte.dirs.size():qte.result = "ok"
			presses.clear()
			if qte.result == "" and qte.age >= close:qte.result = "fail"
		else:
			presses.clear()
		if qte.result != "":
			qte.resolved = qte.age
			resolve_qte(w, qte.result == "ok")
	elif qte.age - qte.resolved > (1.0 if qte.result == "ok" else 1.35):
		qte_index += 1
		if qte.result == "fail" and qte.kind in ["hold", "seq"]:qte_index -= 1
		next_qte(w)
	music = "" if qte_index > 6 else "boss_fade"

func resolve_qte(w, ok: bool):
	var kind: String = qte.kind
	if ok:
		match kind:
			"dodge":set_steve("dodge_l" if qte.dir in ["left", "up"] else "dodge_r"); set_pose(qte.hb); w.sound("ch4_punch_miss", .05)
			"attack":set_steve("jab" if qte_index % 2 == 0 else "hook"); set_pose(qte.hb); w.sound("ch4_punch_heavy" if qte.hb == "fall" else "ch4_punch", .05); flash = .06
			"hold":set_steve("resist"); set_pose("stagger"); w.sound("ch4_punch", .05)
			"seq":set_steve("throw"); set_pose("fall" if qte_index > 8 else "stagger"); w.sound("ch4_punch_heavy", .05); w.shake = .2
	else:
		set_steve("stagger"); set_pose("jab" if kind != "hold" else "throw")
		w.hp = maxf(0.0, w.hp - float(data.three.hit)); w.player_visual.hurt = .12
		w.sound("ch4_hurt", .05); w.shake = .15; flash = .05
	w.sound("ch4_breath", .4)

func begin_death(w):
	phase = "death"; age = 0.0; set_pose("lying"); face = "smile"; set_steve("walk"); music = ""; silence = true
	w.sound("ch4_body_fall")

func step_death(w, dt: float):
	var d: Dictionary = data.death
	var mount_at := 1.0
	steve_at = hb.p + Vector2(-2, -6)
	if age < mount_at:set_steve("walk"); w.player = w.player.lerp(steve_at, minf(1, dt * 4))
	else:w.player = steve_at
	for line in d.lines:
		if age >= float(line.at) and not text_events.any(func(t): return t.text == line.text):
			say(line.text, line.style, float(line.cut) - float(line.at) + 0.5, float(line.cut) - float(line.at))
	for t in d.punches:
		if age >= float(t) and age - dt < float(t):
			set_steve("mount"); steve_pose_age = 0.0; set_pose("lying_hit"); w.sound("ch4_punch_heavy", .02)
			w.shake = .12; w.emit_pixels("impact", hb.p - Vector2(0, 6), 6, Vector2.UP)
	var final_t: float = float(d.final)
	if age >= mount_at and age < final_t - 0.7 and steve_pose != "mount":set_steve("mount")
	if age >= final_t - 0.7 and age < final_t:set_steve("mount"); steve_pose_age = 0.0
	if age >= final_t and age - dt < final_t:
		set_pose("headless"); flash = .5; w.shake = .4; w.sound("ch4_head_break", .02); w.sound("ch4_bone_crack", .02)
		w.add_effect("ch4_hb_head", hb.p + Vector2(-8, -4), 1.6)
		text_events.clear()
	if age >= final_t and age < float(d.stand):set_steve("mount"); steve_pose_age = 0.0
	if age >= float(d.stand):set_steve("lower_arm")
	if age >= float(d.duration):
		phase = "coords"; age = 0.0; w.player = hb.p + Vector2(-26, 8); set_steve("idle"); music = "coords"; silence = false

func step_coords(w):
	if age > 1.2 and age < 2.6:set_steve("walk"); w.player = w.player.move_toward(hb.p + Vector2(-12, 10), 0.4)
	else:set_steve("idle")
	if age >= 3.4 and age < 3.7:glitch = maxf(glitch, .1)
	if age >= float(data.coords.duration):
		phase = "road"; age = 0.0; road_index = 0

func step_road(w, dt: float):
	var scenes: Array = data.road.scenes
	var each: float = float(data.road.each)
	road_index = int(age / each)
	if road_index >= scenes.size():
		phase = "door"; age = 0.0; door_state = "approach"
		var door := Vector2(data.door.p[0], data.door.p[1])
		w.player = door + Vector2(-120, 30); camera_at = door + Vector2(-50, 0); w.facing = Vector2.RIGHT
		return
	var base := Vector2(scenes[road_index][0], scenes[road_index][1])
	var k := fposmod(age, each) / each
	w.player = base + Vector2(-60 + 120 * k, 40); w.facing = Vector2.RIGHT; w.player_moving = true
	camera_at = base + Vector2(0, 10)
	set_steve("walk")

func step_door(w, dt: float):
	var door := Vector2(data.door.p[0], data.door.p[1])
	var target := door + Vector2(0, 22)
	if age < 4.0:
		w.player = w.player.move_toward(target + Vector2(-26, 0), 34 * dt); w.facing = Vector2.RIGHT; set_steve("walk")
	elif age < 5.2:
		door_state = "open"; set_steve("idle")
		if age - dt < 4.0:w.sound("ch4_door_open"); silence = true
	elif age < 7.0:
		door_state = "look"; w.facing = Vector2.LEFT; set_steve("idle")
	elif age < 9.0:
		door_state = "enter"; w.facing = Vector2.UP; set_steve("walk")
		w.player = w.player.move_toward(door + Vector2(0, 2), 22 * dt)
	elif age < 9.6:
		door_state = "gone"
	else:
		if door_state != "closed":door_state = "closed"; w.sound("ch4_door_close")
	camera_at = camera_at.lerp(door + Vector2(-10, 10), minf(1, dt * 1.5))
	if age >= float(data.door.duration):
		phase = "done"; w.state = "RESULT"; w.victory = true
		if not stored.is_empty():w.build = stored.build; w.items = stored.items; w.evolved = stored.evolved
		w.run_progress.finish(w)

# ------------------------------------------------------------------ checkpoints

func save_checkpoint(w, from: String):
	checkpoint = {"from": from, "hp": maxf(w.hp, 12.0), "hb_hp": hb.hp, "player": w.player, "build": w.build.duplicate(), "items": w.items.duplicate(), "evolved": w.evolved.duplicate()}

func begin_retry(w):
	retry_from = checkpoint.get("from", "one")
	phase = "retry"; age = 0.0; clear_hazards(); text_events.clear(); qte = {}
	for key in w.solid_grid.keys():w.solid_grid[key] = w.solid_grid[key].filter(func(o): return not o.get("rift", false))
	w.hp = 1.0

func restore_checkpoint(w):
	w.hp = float(checkpoint.hp); w.invulnerable = 1.5
	w.build = checkpoint.build.duplicate(); w.items = checkpoint.items.duplicate(); w.evolved = checkpoint.evolved.duplicate()
	hb.hp = float(checkpoint.hb_hp); hb.max_hp = float(data.one.hp if retry_from == "one" else data.two.hp)
	w.player = checkpoint.player
	phase = retry_from; age = 0.0
	if phase == "one" or phase == "two":
		hb.p = center + Vector2(0, -80); begin_move(w, "rest", 1.2)
		if phase == "two":day_done.clear()
		music = "boss_one" if phase == "one" else "boss_two"
	else:
		hb.p = center + Vector2(26, 0); w.player = center + Vector2(-26, 0); qte_index = 0; next_qte(w)
