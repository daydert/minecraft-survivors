extends RefCounted
## Chapter IV impact layer: gore, stains, smoke, shells, shockwaves and light.
## Presentation only. It runs on the world clock (so pause freezes it), owns a
## separate RNG, and is never read by combat, spawning or rewards.
const STAIN_CELL := 14.0
const STAIN_CAP := 520
var rng := RandomNumberGenerator.new()
var stains: Array = []
var stain_cells: Dictionary = {}
var pools: Array = []
var gibs: Array = []
var drops: Array = []
var shells: Array = []
var smoke: Array = []
var sparks: Array = []
var flashes: Array = []
var rings: Array = []
var bursts: Array = []
var wisps: Array = []
var risers: Array = []
var kick := Vector2.ZERO
var budget := 0
var glow := 0.0
var glow_id := ""
var bat_was := false
var tremor := 0.0
var tremor_next := 0.0
var opening := 0
var deaths := 0
## Chapter III: purple ender blood and dust instead of red.
var ender := false

func reset(_w):
	rng.seed = 40417
	for list in [stains, pools, gibs, drops, shells, smoke, sparks, flashes, rings, bursts, wisps, risers]:list.clear()
	stain_cells.clear()
	kick = Vector2.ZERO;budget = 0;glow = 0.0;glow_id = "";bat_was = false
	tremor = 0.0;tremor_next = 0.0;opening = 0;deaths = 0

func seen(w, p: Vector2, pad: float = 60.0) -> bool:
	return w.visible(p, pad)

func material(m: Dictionary) -> String:
	var kind: String = str(m.get("skin", m.get("kind", "")))
	if m.get("encounter_actor", "") in ["guardian", "guardian_torch"]:return "stone"
	if m.get("encounter_actor", "") == "golem":return "iron"
	if "skeleton" in kind or "rider" in kind:return "bone"
	if ender:return "ender"
	return "flesh"

# ------------------------------------------------------------------ ground

func stain(p: Vector2, r: float, kind: String = "blood", clock: float = 0.0, extra: Dictionary = {}):
	var cell := Vector2i((p / STAIN_CELL).floor())
	if kind == "blood" and stain_cells.has(cell):
		var old: Dictionary = stain_cells[cell]
		old.r = minf(11.0, old.r + r * 0.3)
		return
	var s := {"p": p, "r": r, "kind": kind, "seed": rng.randi() % 4096, "born": clock, "cell": cell}
	s.merge(extra, true)
	stains.append(s)
	if kind == "blood":stain_cells[cell] = s
	while stains.size() > STAIN_CAP:
		var gone: Dictionary = stains.pop_front()
		if stain_cells.has(gone.cell) and is_same(stain_cells[gone.cell], gone):stain_cells.erase(gone.cell)

func pool(p: Vector2, size: float, clock: float):
	for old in pools:
		if old.p.distance_to(p) < 26:
			old.size = minf(34.0, old.size + size * 0.35);return
	pools.append({"p": p, "size": size, "born": clock})
	if pools.size() > 14:pools.pop_front()

# ------------------------------------------------------------------ pieces

func drop(p: Vector2, v: Vector2, vz: float, z: float = 12.0, size: float = 2.0):
	if budget <= 0 or drops.size() >= 300:return
	budget -= 1
	drops.append({"p": p, "v": v, "z": z, "vz": vz, "size": size})

func gib(p: Vector2, v: Vector2, vz: float, kind: String, z: float = 12.0):
	if budget <= 0 or gibs.size() >= 170:return
	budget -= 2
	gibs.append({"p": p, "v": v, "z": z, "vz": vz, "kind": kind, "size": 2 + rng.randi() % 3, "seed": rng.randi() % 997, "age": 0.0, "rest": 0.0, "life": 5.0 + rng.randf() * 5.0, "bounced": false})

func puff(p: Vector2, v: Vector2, r: float, life: float, color: Color, z: float = 8.0):
	if smoke.size() >= 150:return
	smoke.append({"p": p, "v": v, "r": r, "age": 0.0, "life": life, "color": color, "z": z})

func spark(p: Vector2, v: Vector2, life: float, color: Color, z: float = 10.0, vz: float = 0.0):
	if sparks.size() >= 220:return
	sparks.append({"p": p, "v": v, "age": 0.0, "life": life, "color": color, "z": z, "vz": vz})

func flash(p: Vector2, r: float, color: Color, life: float, power: float = 0.9):
	if flashes.size() >= 10:flashes.pop_front()
	flashes.append({"p": p, "r": r, "color": color, "age": 0.0, "life": life, "power": power})

func ring(p: Vector2, r: float, life: float, kind: String, extra: Dictionary = {}):
	if rings.size() >= 40:rings.pop_front()
	var e := {"p": p, "r": r, "age": 0.0, "life": life, "kind": kind, "seed": rng.randi() % 997}
	e.merge(extra, true)
	rings.append(e)

func burst(p: Vector2, big: bool, blood: bool):
	if bursts.size() >= 8:bursts.pop_front()
	bursts.append({"p": p, "age": 0.0, "big": big, "blood": blood, "seed": rng.randi() % 997})

func freeze(w, seconds: float):
	w.hitstop = maxf(w.hitstop, seconds)

func shove(w, direction: Vector2, amount: float, shake: float = 0.0):
	kick += direction * amount
	kick = kick.limit_length(7.0)
	if shake > 0:w.shake = maxf(w.shake, shake)

func spray(p: Vector2, direction: Vector2, count: int, speed: float, spread: float, lift: float = 60.0, z: float = 12.0):
	for j in range(count):
		var d: Vector2 = (direction.rotated((rng.randf() - 0.5) * spread) if direction.length_squared() > 0.01 else Vector2.from_angle(rng.randf() * TAU))
		drop(p, d * speed * (0.35 + rng.randf() * 0.9), lift * (0.4 + rng.randf()), z, 1.0 + float(rng.randi() % 3))

func chunks(p: Vector2, direction: Vector2, count: int, speed: float, spread: float, kind: String, lift: float = 110.0):
	for j in range(count):
		var d: Vector2 = (direction.rotated((rng.randf() - 0.5) * spread) if direction.length_squared() > 0.01 else Vector2.from_angle(rng.randf() * TAU))
		gib(p, d * speed * (0.3 + rng.randf() * 0.9), lift * (0.5 + rng.randf() * 0.8), kind)

func dust(p: Vector2, count: int, spread: float, color: Color = Color(0.36, 0.3, 0.29, 0.5)):
	for j in range(count):
		var d := Vector2.from_angle(rng.randf() * TAU)
		puff(p + d * Vector2(spread, spread * 0.5) * rng.randf(), d * (8 + rng.randf() * 14) + Vector2(0, -6), 4 + rng.randf() * 5, 0.5 + rng.randf() * 0.5, color, 3.0)

# ------------------------------------------------------------------ combat hooks

func hit(w, m: Dictionary, amount: float, push: Vector2, owner: String):
	m.fx_dir = push
	m.fx_owner = owner
	m.fx_near = m.p.distance_to(w.player)
	if not seen(w, m.p, 30):return
	var kind := material(m)
	var heavy: bool = m.get("boss", false) or not m.get("encounter_actor", "").is_empty()
	var count: int = clampi(1 + int(amount / 14.0), 1, 4) + (2 if heavy else 0)
	if owner in ["blood_pool", "red_torch", "fire", "potion"]:count = 1
	var at: Vector2 = m.p
	if kind in ["flesh", "ender"]:spray(at, push, count, 95.0, 1.1, 70.0, 14.0)
	elif kind == "bone":
		for j in range(mini(2, count)):gib(at, (push.rotated(rng.randf() - 0.5) if push.length_squared() > 0.01 else Vector2.from_angle(rng.randf() * TAU)) * (50 + rng.randf() * 60), 80 + rng.randf() * 60, "bone", 14.0)
	else:
		for j in range(count):spark(at, (push.rotated(rng.randf() * 1.6 - 0.8) if push.length_squared() > 0.01 else Vector2.from_angle(rng.randf() * TAU)) * (60 + rng.randf() * 80), 0.25, Color(0.85, 0.78, 0.62), 16.0, 40.0)
	if heavy and amount >= 20 and bursts.size() < 3:burst(at - Vector2(0, 16), false, kind == "flesh")

func death(w, m: Dictionary):
	if not seen(w, m.p, 40):return
	deaths += 1
	var kind := material(m)
	var direction: Vector2 = m.get("fx_dir", Vector2.ZERO)
	var owner: String = m.get("fx_owner", "")
	var close: bool = owner == "shotgun" and float(m.get("fx_near", 999.0)) < 85.0
	var blown: bool = owner in ["sky_tnt", "tnt", "bed", "explosion"]
	var big: bool = m.get("boss", false)
	var at: Vector2 = m.p
	if kind == "ender":
		chunks(at, direction, 3, 100.0, 2.0, "ender", 130.0)
		spray(at, direction, 6, 90.0, 1.8)
		if big:pool(at, 12.0, w.clock)
	elif kind == "flesh":
		if close:
			chunks(at, direction, 6, 210.0, 0.7, "flesh", 120.0)
			spray(at, direction, 10, 170.0, 0.7, 80.0)
			stain(at + direction * 16, 5.0, "blood", w.clock)
			stain(at + direction * 34, 3.5, "blood", w.clock)
		elif blown:
			chunks(at, Vector2.ZERO, 5, 120.0, TAU, "flesh", 220.0)
			spray(at, Vector2.ZERO, 8, 120.0, TAU, 170.0)
		else:
			chunks(at, direction, 2 + (1 if deaths % 3 == 0 else 0), 90.0, 1.6, "flesh")
			spray(at, direction, 6, 90.0, 1.8)
		stain(at, 4.0 + rng.randf() * 3.0, "blood", w.clock)
		if deaths % 4 == 0 or big:pool(at, 9.0 + rng.randf() * 5.0, w.clock)
	elif kind == "bone":
		chunks(at, direction, 7 if close or blown else 4, 190.0 if close else 110.0, 0.8 if close else 2.2, "bone", 200.0 if blown else 120.0)
		dust(at, 3, 8, Color(0.62, 0.6, 0.55, 0.45))
	else:
		chunks(at, direction, 6, 110.0, 2.4, "stone")
		dust(at, 4, 10)
	if big:
		chunks(at, Vector2.ZERO, 9, 150.0, TAU, kind, 200.0)
		spray(at, Vector2.ZERO, 14, 150.0, TAU, 160.0)
		burst(at - Vector2(0, 18), true, kind == "flesh")
		shove(w, Vector2.ZERO, 0, 0.16)
		flash(at, 110.0, Color(1, 0.35, 0.3), 0.22, 0.7)

func muzzle(w, p: Vector2, direction: Vector2):
	var side := direction.orthogonal()
	flash(p + direction * 18, 96.0, Color(1.0, 0.78, 0.42), 0.11, 1.0)
	for j in range(5):puff(p + direction * (14 + j * 5), direction * (30 + j * 16) + side * (rng.randf() - 0.5) * 30, 4.0 + j, 0.45 + rng.randf() * 0.35, Color(0.72, 0.7, 0.68, 0.38), 10.0)
	for j in range(9):spark(p + direction * 12, direction.rotated((rng.randf() - 0.5) * 0.9) * (160 + rng.randf() * 180), 0.12 + rng.randf() * 0.14, Color(1, 0.86, 0.5), 10.0)
	for j in range(2):
		if shells.size() >= 60:shells.pop_front()
		shells.append({"p": p - direction * 3, "v": -side * (45 + rng.randf() * 40) * (1 if j == 0 else -1) - direction * (20 + rng.randf() * 20), "z": 11.0, "vz": 95.0 + rng.randf() * 40, "age": 0.0, "spin": rng.randf() * TAU, "bounced": false})
	shove(w, -direction, 4.0, 0.07)

func pellet_hit(w, p: Vector2, direction: Vector2):
	if not seen(w, p, 20):return
	for j in range(2):spark(p, (-direction).rotated((rng.randf() - 0.5) * 1.8) * (50 + rng.randf() * 70), 0.14, Color(1, 0.8, 0.5), 12.0)

func blast(w, p: Vector2, radius: float):
	if not seen(w, p, radius):return
	flash(p, radius * 2.6, Color(1.0, 0.62, 0.28), 0.16, 0.95)
	stain(p, radius * 0.42, "scorch", w.clock)
	for j in range(3):puff(p + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * radius * 0.6, Vector2((rng.randf() - 0.5) * 20, -18 - rng.randf() * 16), 7 + rng.randf() * 6, 0.8 + rng.randf() * 0.6, Color(0.16, 0.14, 0.14, 0.55), 6.0)
	chunks(p, Vector2.ZERO, 3, 120.0, TAU, "dirt", 190.0)
	for j in range(4):spark(p, Vector2.from_angle(rng.randf() * TAU) * (70 + rng.randf() * 110), 0.3 + rng.randf() * 0.25, Color(1, 0.7, 0.3), 6.0, 90.0)
	shove(w, Vector2.ZERO, 0, 0.1)

func toll(w, p: Vector2, radius: float, ghost: bool = false):
	ring(p, radius, 0.55, "toll", {"ghost": ghost})
	for j in range(10):
		var d := Vector2.from_angle(j * TAU / 10 + rng.randf() * 0.4)
		puff(p + d * Vector2(radius, radius * 0.55) * 0.55, d * 40, 4 + rng.randf() * 3, 0.5, Color(0.5, 0.44, 0.36, 0.34), 2.0)
	flash(p - Vector2(0, 14), 80.0, Color(1.0, 0.85, 0.5), 0.14, 0.6)
	shove(w, Vector2(0, 1), 2.5, 0.08)

func slash(w, p: Vector2, direction: Vector2, radius: float, half_arc: float=1.15):
	ring(p, radius, 0.38, "slash", {"dir": direction,"half_arc":half_arc})
	var end: Vector2 = p + direction * radius
	stain(p + direction * radius * 0.55, radius * 0.5, "crack", w.clock, {"end": end, "dir": direction})
	dust(end, 5, 12)
	chunks(p + direction * radius * 0.7, direction, 3, 90.0, 1.4, "dirt", 120.0)
	shove(w, direction, 3.5, 0.1)

func spike(w, p: Vector2):
	if not seen(w, p, 20):return
	spray(p, Vector2.ZERO, 2, 40.0, TAU, 130.0, 6.0)

func bite(w, p: Vector2, direction: Vector2):
	if not seen(w, p, 20):return
	spray(p, direction, 4, 70.0, 1.6, 90.0)
	ring(p - Vector2(0, 12), 9.0, 0.2, "jaws", {"dir": direction})

func saw(w, p: Vector2, direction: Vector2):
	if not seen(w, p, 20):return
	spray(p, direction.orthogonal(), 2, 120.0, 0.8, 90.0)
	spark(p, direction.orthogonal().rotated(rng.randf() - 0.5) * 120, 0.16, Color(0.95, 0.9, 0.78), 12.0, 50.0)

func leech(w, from: Vector2):
	if wisps.size() >= 24 or not seen(w, from, 20):return
	wisps.append({"from": from - Vector2(0, 12), "age": 0.0, "life": 0.42, "bend": (rng.randf() - 0.5) * 40})

func pulse(w, kind: String):
	ring(w.player, 60.0 if kind == "heart" else 46.0, 0.6 if kind == "heart" else 0.4, kind)
	if kind == "heart":flash(w.player - Vector2(0, 12), 120.0, Color(1, 0.12, 0.1), 0.3, 0.8)
	elif kind == "revive":
		flash(w.player - Vector2(0, 12), 160.0, Color(0.7, 1.0, 0.5), 0.5, 0.9)
		for j in range(18):rise(w.player + Vector2((rng.randf() - 0.5) * 30, 0), Color(0.62, 0.9, 0.36), 0.7 + rng.randf() * 0.6)
	elif kind == "thorns":
		for j in range(8):spark(w.player, Vector2.from_angle(j * TAU / 8) * 150, 0.16, Color(0.85, 0.85, 0.9), 12.0)

func rise(p: Vector2, color: Color, life: float):
	if risers.size() >= 90:return
	risers.append({"p": p, "age": 0.0, "life": life, "color": color, "sway": rng.randf() * TAU, "speed": 22 + rng.randf() * 30})

func flock(w, p: Vector2, gathering: bool):
	for j in range(8):puff(p - Vector2(0, 10), Vector2.from_angle(rng.randf() * TAU) * (18 if gathering else 46), 5 + rng.randf() * 4, 0.4, Color(0.05, 0.01, 0.02, 0.6), 12.0)
	flash(p - Vector2(0, 12), 70.0, Color(0.8, 0.1, 0.12), 0.18, 0.6)

func evolve(w, id: String):
	glow = 2.2;glow_id = id
	ring(w.player, 150.0, 0.9, "evolve")
	flash(w.player - Vector2(0, 12), 220.0, Color(1.0, 0.92, 0.7), 0.6, 1.0)
	for j in range(26):rise(w.player + Vector2((rng.randf() - 0.5) * 44, (rng.randf() - 0.5) * 16), Color(1, 0.86, 0.5) if j % 3 else Color(1, 1, 1), 0.8 + rng.randf() * 0.9)
	shove(w, Vector2.ZERO, 0, 0.14)

func quake(w, p: Vector2, strength: float, crack_to = null):
	if not seen(w, p, 140):return
	shove(w, Vector2(0, 1), 2.0 * strength, 0.1 + 0.08 * strength)
	dust(p, int(4 + 4 * strength), 18 * strength)
	if crack_to != null:stain(p.lerp(crack_to, 0.5), p.distance_to(crack_to) * 0.5, "crack", w.clock, {"end": crack_to, "dir": p.direction_to(crack_to)})

func erupt(w, p: Vector2, kind: String, count: int):
	if not seen(w, p, 60):return
	chunks(p, Vector2.ZERO, count, 110.0, TAU, kind, 170.0)
	dust(p, 4, 12)

# ------------------------------------------------------------------ clock

func update(w, dt: float):
	budget = 90
	kick = kick.move_toward(Vector2.ZERO, dt * 46.0)
	glow = maxf(0.0, glow - dt)
	for i in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]
		d.p += d.v * dt;d.z += d.vz * dt;d.vz -= 420.0 * dt
		if d.z <= 0:
			if d.size >= 2 or rng.randf() < 0.3:stain(d.p, 0.8 + d.size * 0.55, "blood", w.clock)
			drops.remove_at(i)
	for i in range(gibs.size() - 1, -1, -1):
		var c: Dictionary = gibs[i]
		c.age += dt
		if c.rest > 0:
			c.rest += dt
			if c.rest > c.life:gibs.remove_at(i)
			continue
		c.p += c.v * dt;c.z += c.vz * dt;c.vz -= 440.0 * dt
		if c.z <= 0:
			c.z = 0.0
			if c.kind == "flesh":stain(c.p, 1.5 + c.size * 0.5, "blood", w.clock)
			if not c.bounced and absf(c.vz) > 70:
				c.bounced = true;c.vz = -c.vz * 0.34;c.v *= 0.45
			else:c.rest = 0.001;c.v = Vector2.ZERO
	for i in range(shells.size() - 1, -1, -1):
		var s: Dictionary = shells[i]
		s.age += dt
		if s.z > 0 or s.vz > 0:
			s.p += s.v * dt;s.z += s.vz * dt;s.vz -= 430.0 * dt;s.spin += dt * 18
			if s.z <= 0:
				s.z = 0.0
				if not s.bounced:s.bounced = true;s.vz = 55.0;s.v *= 0.4
				else:s.vz = 0.0;s.v = Vector2.ZERO
		if s.age > 7.0:shells.remove_at(i)
	for i in range(smoke.size() - 1, -1, -1):
		var s: Dictionary = smoke[i]
		s.age += dt;s.p += s.v * dt;s.v *= maxf(0.0, 1.0 - dt * 2.2);s.z += dt * 9.0
		if s.age >= s.life:smoke.remove_at(i)
	for i in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s.age += dt;s.p += s.v * dt;s.z = maxf(0.0, s.z + s.vz * dt);s.vz -= 260.0 * dt
		if s.age >= s.life:sparks.remove_at(i)
	for list in [flashes, rings, bursts, wisps, risers]:
		for i in range(list.size() - 1, -1, -1):
			list[i].age += dt
			if list[i].age >= list[i].get("life", 0.7):list.remove_at(i)
	var bats: bool = "arsenal" in w and w.arsenal.bat_left > 0
	if bats != bat_was:
		bat_was = bats
		flock(w, w.player, not bats)
	escalate(w, dt)

## The world gives way as the twelfth minute approaches: tremors and dust.
func escalate(w, dt: float):
	if not "ending" in w or w.stage != "survival" or w.db.data.chapter_four.exploration_only:return
	var left: float = float(w.db.data.duration) - float(w.time)
	if left > 150.0 or left <= 0.0:return
	tremor = maxf(0.0, tremor - dt)
	tremor_next -= dt
	if tremor_next > 0:return
	var urgency: float = 1.0 - left / 150.0
	tremor_next = lerpf(19.0, 5.5, urgency)
	tremor = 0.9 + urgency * 0.8
	w.shake = maxf(w.shake, 0.18 + urgency * 0.3)
	w.sound("ch4_ground_slam", 2.0)
	for j in range(int(6 + urgency * 8)):
		var p: Vector2 = w.player + Vector2((rng.randf() - 0.5) * 560, (rng.randf() - 0.5) * 300)
		puff(p, Vector2((rng.randf() - 0.5) * 10, -8), 5 + rng.randf() * 6, 0.9 + rng.randf() * 0.6, Color(0.4, 0.33, 0.32, 0.4), 2.0)
		if j % 3 == 0:gib(p, Vector2((rng.randf() - 0.5) * 30, 0), 90 + rng.randf() * 60, "dirt", 0.0)
