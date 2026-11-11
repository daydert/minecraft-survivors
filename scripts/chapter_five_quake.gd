extends RefCounted
## Notch's favourite game: a two-level deathmatch arena, four weapons, first
## to three frags. Quake movement (air strafing), timed items, a bot that
## picks weapons by range, dodges your aim and goes for the strong items.
## Units are blocks; y is up. Pure simulation.
const GRAVITY := 22.0
const JUMP := 7.0
const RUN := 8.0
const ACCEL := 60.0
const AIR_ACCEL := 9.0
const AIR_CAP := 1.3
const HALF := Vector3(.35, .9, .35)
const EYE := 1.55
const ROCKET_SPEED := 17.0
const SPLASH := 2.6
const FRAGS := 3
## name, cooldown, ammo kind.
const WEAPONS := {
	"pickaxe": {"name":"Алмазная кирка", "cool":.45, "ammo":""},
	"charges": {"name":"Огненные заряды", "cool":.11, "ammo":"charges"},
	"rockets": {"name":"TNT-пушка", "cool":.8, "ammo":"rockets"},
	"crossbow": {"name":"Арбалет", "cool":1.4, "ammo":"bolts"}}
const ORDER := ["pickaxe", "charges", "rockets", "crossbow"]
var boxes: Array = []
var lava: Array = []
var pads: Array = []
var spawns: Array = []
var items: Array = []
var players: Array = []
var rockets: Array = []
var shots: Array = []
var beams: Array = []
var blasts: Array = []
var gibs: Array = []
var feed: Array = []
var numbers: Array = []
var age := 0.0
var state := "intro"
var winner := -1
var bot_timer := 0.0
var bot_goal := Vector3.ZERO
var bot_strafe := 1.0
var bot_dodge := 0.0
var bot_history: Array = []
var serial := 0
var ai := true
var sounds: Array = []

func reset():
	for list in [boxes, lava, pads, spawns, items, rockets, shots, beams, blasts, gibs, feed, numbers, bot_history]:list.clear()
	age = 0.0;state = "intro";winner = -1;bot_timer = 0.0;bot_strafe = 1.0;bot_dodge = 0.0;serial = 0
	build_map()
	players = [make("steve", spawns[0], 0.0), make("notch", spawns[2], PI)]

func box(a: Vector3, b: Vector3, tex: String):boxes.append([a, b, tex])

func build_map():
	var w := 18.0
	box(Vector3(-w - 1, -1, -w - 1), Vector3(w + 1, 0, w + 1), "polished_deepslate")
	box(Vector3(-w - 1, 0, -w - 1), Vector3(w + 1, 7, -w), "polished_blackstone_bricks")
	box(Vector3(-w - 1, 0, w), Vector3(w + 1, 7, w + 1), "polished_blackstone_bricks")
	box(Vector3(-w - 1, 0, -w), Vector3(-w, 7, w), "polished_blackstone_bricks")
	box(Vector3(w, 0, -w), Vector3(w + 1, 7, w), "polished_blackstone_bricks")
	# Upper galleries north and south, with stairs at their ends.
	for s in [-1, 1]:
		var z0: float = -18.0 if s < 0 else 14.0
		box(Vector3(-11, 0, z0), Vector3(11, 3.2, z0 + 4), "deepslate_tiles")
		for k in range(8):
			var h: float = .4 * (k + 1)
			box(Vector3(11 + (7 - k) * .7, 0, z0), Vector3(11 + (8 - k) * .7, h, z0 + 2.2), "cut_copper")
			box(Vector3(-11 - (8 - k) * .7, 0, z0 + 1.8), Vector3(-11 - (7 - k) * .7, h, z0 + 4), "cut_copper")
		box(Vector3(-11, 3.2, z0 + (0.0 if s > 0 else 3.6)), Vector3(11, 3.7, z0 + (0.4 if s > 0 else 4.0)), "copper_grate")
	for c in [Vector3(-9, 0, -6), Vector3(9, 0, -6), Vector3(-9, 0, 6), Vector3(9, 0, 6)]:
		box(c - Vector3(1, 0, 1), c + Vector3(1, 5, 1), "exposed_cut_copper")
	box(Vector3(-3, 0, -3), Vector3(3, 2.8, 3), "deepslate_tiles")
	box(Vector3(-15.5, 0, -2), Vector3(-14, 1.2, 2), "iron_block")
	box(Vector3(14, 0, -2), Vector3(15.5, 1.2, 2), "iron_block")
	lava = [[Vector3(-12, -.1, -1.2), Vector3(-6, .05, 1.2)], [Vector3(6, -.1, -1.2), Vector3(12, .05, 1.2)]]
	pads = [{"p":Vector3(0, 0, 6.5), "push":Vector3(0, 11.5, -3.8)}, {"p":Vector3(0, 0, -6.5), "push":Vector3(0, 11.5, 3.8)}, {"p":Vector3(-16, 0, 0), "push":Vector3(1.0, 12.5, -6.2)}, {"p":Vector3(16, 0, 0), "push":Vector3(-1.0, 12.5, 6.2)}]
	spawns = [Vector3(-14, 0, 10), Vector3(14, 0, 10), Vector3(14, 0, -10), Vector3(-14, 0, -10)]
	items = [{"kind":"mega", "p":Vector3(0, 2.8, 0), "left":15.0, "every":35.0},
		{"kind":"crossbow", "p":Vector3(0, 3.2, -16), "left":0.0, "every":20.0},
		{"kind":"rockets", "p":Vector3(0, 3.2, 16), "left":0.0, "every":20.0},
		{"kind":"armor", "p":Vector3(-14.8, 1.2, 0), "left":0.0, "every":25.0},
		{"kind":"armor", "p":Vector3(14.8, 1.2, 0), "left":0.0, "every":25.0},
		{"kind":"health", "p":Vector3(-9, 0, -9.5), "left":0.0, "every":15.0}, {"kind":"health", "p":Vector3(9, 0, 9.5), "left":0.0, "every":15.0},
		{"kind":"health", "p":Vector3(9, 0, -9.5), "left":0.0, "every":15.0}, {"kind":"health", "p":Vector3(-9, 0, 9.5), "left":0.0, "every":15.0},
		{"kind":"charges", "p":Vector3(-16.5, 0, -16.5), "left":0.0, "every":12.0}, {"kind":"charges", "p":Vector3(16.5, 0, 16.5), "left":0.0, "every":12.0},
		{"kind":"quad", "p":Vector3(0, 3.7, 16.2), "left":30.0, "every":60.0}]

func make(who: String, at: Vector3, yaw: float) -> Dictionary:
	return {"who":who, "p":at, "v":Vector3.ZERO, "yaw":yaw, "pitch":0.0, "hp":100.0, "armor":0.0, "ammo":10, "charges":60, "bolts":0,
		"owned":{"pickaxe":true, "charges":true, "rockets":true, "crossbow":false}, "weapon":"rockets", "cool":0.0,
		"frags":0, "dead":0.0, "quad":0.0, "flash":0.0, "grounded":true, "walk":0.0, "fired":0.0, "lava":0.0, "hitmark":0.0, "swing":0.0}

func steve() -> Dictionary:return players[0]
func notch() -> Dictionary:return players[1]
func eye(pl: Dictionary) -> Vector3:return pl.p + Vector3(0, EYE, 0)
func look(pl: Dictionary) -> Vector3:
	return Vector3(-sin(pl.yaw) * cos(pl.pitch), sin(pl.pitch), -cos(pl.yaw) * cos(pl.pitch))

func ammo_of(pl: Dictionary, weapon: String) -> int:
	match WEAPONS[weapon].ammo:
		"rockets":return pl.ammo
		"charges":return pl.charges
		"bolts":return pl.bolts
	return 999

func select(pl: Dictionary, weapon: String):
	if pl.owned.get(weapon, false) and pl.weapon != weapon:
		pl.weapon = weapon;pl.cool = maxf(pl.cool, .25);sounds.append("switch" if pl.who == "steve" else "")

func solid(p: Vector3, half: Vector3) -> Array:
	var out: Array = []
	for b in boxes:
		if p.x + half.x > b[0].x and p.x - half.x < b[1].x and p.y + half.y * 2 > b[0].y and p.y < b[1].y and p.z + half.z > b[0].z and p.z - half.z < b[1].z:out.append(b)
	return out

func move(pl: Dictionary, dt: float):
	var d: Vector3 = pl.v * dt
	for axis in [0, 2, 1]:
		var q: Vector3 = pl.p
		q[axis] += d[axis]
		var hit: Array = solid(q, HALF)
		if hit.is_empty():pl.p = q;continue
		if axis == 1:
			if d.y < 0:
				var top := -INF
				for b in hit:top = maxf(top, b[1].y)
				pl.p.y = top;pl.grounded = true
			pl.v.y = 0.0
		else:
			var up: Vector3 = q + Vector3(0, .45, 0)
			if pl.grounded and solid(up, HALF).is_empty():pl.p = up
			else:pl.v[axis] = 0.0

## Quake movement: ground friction and acceleration, air strafing.
func walk(pl: Dictionary, wish: Vector3, jump: bool, dt: float):
	pl.grounded = not solid(pl.p - Vector3(0, .05, 0), HALF).is_empty()
	var flat := Vector3(pl.v.x, 0, pl.v.z)
	if pl.grounded:
		if jump:
			pl.v.y = JUMP;pl.grounded = false
		else:
			var speed: float = flat.length()
			if speed > .01:flat *= maxf(0, speed - maxf(speed, 4.0) * 6.0 * dt) / speed
		if pl.grounded:
			var add: float = RUN - flat.dot(wish)
			if add > 0:flat += wish * minf(add, ACCEL * dt)
	if not pl.grounded:
		var add: float = AIR_CAP - flat.dot(wish)
		if add > 0 and wish.length() > 0:flat += wish * minf(add, AIR_ACCEL * RUN * dt)
	pl.v.x = flat.x;pl.v.z = flat.z
	pl.v.y -= GRAVITY * dt
	move(pl, dt)
	pl.walk += flat.length() * dt
	for pad in pads:
		if pl.grounded and Vector2(pl.p.x - pad.p.x, pl.p.z - pad.p.z).length() < .9:
			pl.v = pad.push;pl.grounded = false;sounds.append("pad")

func fire(pl: Dictionary):
	if pl.cool > 0 or pl.dead > 0:return
	var weapon: String = pl.weapon
	if ammo_of(pl, weapon) <= 0:
		for wpn in ["rockets", "crossbow", "charges", "pickaxe"]:
			if pl.owned.get(wpn, false) and ammo_of(pl, wpn) > 0:select(pl, wpn);break
		return
	var spec: Dictionary = WEAPONS[weapon]
	pl.cool = spec.cool;pl.fired = .12
	var dir: Vector3 = look(pl);var from: Vector3 = eye(pl) + Vector3(0, -.12, 0)
	var mult: float = 4.0 if pl.quad > 0 else 1.0
	match weapon:
		"pickaxe":
			pl.swing = .3;sounds.append("swing" if pl.who == "steve" else "nswing")
			var o: Dictionary = notch() if pl.who == "steve" else steve()
			var to: Vector3 = (o.p + Vector3(0, .9, 0)) - eye(pl)
			if o.dead <= 0 and to.length() < 2.0 and to.normalized().dot(dir) > .6:
				hurt(o, 40.0 * mult, pl.who, "pickaxe");o.v += dir * 6.0;mark(pl, o, 40.0 * mult)
		"charges":
			pl.charges -= 1
			shots.append({"owner":pl.who, "p":from + dir * .5, "v":dir * 34.0, "age":0.0, "damage":9.0 * mult})
			sounds.append("charge" if pl.who == "steve" else "ncharge")
		"rockets":
			pl.ammo -= 1
			rockets.append({"owner":pl.who, "p":from + dir * .6, "v":dir * ROCKET_SPEED, "age":0.0, "quad":pl.quad > 0})
			sounds.append("rocket")
		"crossbow":
			pl.bolts -= 1
			var o: Dictionary = notch() if pl.who == "steve" else steve()
			var end: Vector3 = trace(from, dir, 60.0)
			var c: Vector3 = o.p + Vector3(0, .9, 0)
			var closest: Vector3 = Geometry3D.get_closest_point_to_segment(c, from, end)
			if o.dead <= 0 and closest.distance_to(c) < .55:
				end = closest;hurt(o, 85.0 * mult, pl.who, "crossbow");o.v += dir * 4.0;mark(pl, o, 85.0 * mult)
			beams.append({"a":from, "b":end, "age":0.0, "owner":pl.who})
			sounds.append("bolt")

func mark(pl: Dictionary, o: Dictionary, dmg: float):
	if pl.who == "steve":
		pl.hitmark = .25;sounds.append("hitmark")
		numbers.append({"p":o.p + Vector3(0, 2.1, 0), "value":int(dmg), "age":0.0})

func trace(from: Vector3, dir: Vector3, reach: float) -> Vector3:
	var steps := 120
	for k in range(1, steps + 1):
		var q: Vector3 = from + dir * reach * k / steps
		if q.y <= 0.0 or not solid(q - Vector3(0, .01, 0), Vector3(.01, .005, .01)).is_empty():return q
	return from + dir * reach

func hurt(pl: Dictionary, amount: float, by: String, how: String):
	if pl.dead > 0:return
	var save: float = minf(pl.armor, amount * .6)
	pl.armor -= save;pl.hp -= amount - save;pl.flash = .2
	if pl.hp <= 0:
		pl.dead = 1.8;pl.hp = 0.0
		var killer: Dictionary = steve() if by == "steve" else notch()
		if by != pl.who:killer.frags += 1
		else:pl.frags = maxi(0, pl.frags - 1)
		feed.append({"text":obituary(pl.who, by, how), "age":0.0})
		sounds.append("gib")
		for k in range(16):
			gibs.append({"p":pl.p + Vector3(0, 1.0, 0), "v":Vector3(sin(k * 2.4) * 4.0, 4.0 + k % 4 * 1.5, cos(k * 2.4) * 4.0), "age":0.0, "red":k % 3 != 0})

func obituary(victim: String, by: String, how: String) -> String:
	var names := {"steve":"Стив", "notch":"Нотч"}
	var killer: String = "Нотча" if by == "notch" else "Стива"
	if victim == by:return "%s словил собственную ракету" % names[victim]
	match how:
		"lava":return "%s решил искупаться в лаве" % names[victim]
		"crossbow":return "%s получил болт от %s" % [names[victim], killer]
		"pickaxe":return "%s выкопан киркой %s" % [names[victim], killer]
		"charges":return "%s поджарен огнём %s" % [names[victim], killer]
	return "%s поймал ракету %s" % [names[victim], killer]

func explode(r: Dictionary, at: Vector3, direct = null):
	blasts.append({"p":at, "age":0.0})
	sounds.append("boom")
	var mult: float = 4.0 if r.quad else 1.0
	for pl in players:
		if pl.dead > 0:continue
		var center: Vector3 = pl.p + Vector3(0, .9, 0)
		var d: float = center.distance_to(at)
		if pl == direct:d = 0.0
		if d > SPLASH:continue
		var k: float = 1.0 - d / SPLASH
		var dmg: float = (100.0 if pl == direct else 80.0 * k) * mult
		if pl.who == r.owner:dmg *= .45
		var push: Vector3 = (center - at).normalized() if d > .01 else Vector3.UP
		pl.v += push * 13.0 * k * (1.6 if pl.who == r.owner else 1.0)
		pl.grounded = false
		if pl.who != r.owner:mark(steve() if r.owner == "steve" else notch(), pl, dmg)
		hurt(pl, dmg, r.owner, "rocket")

func update_projectiles(dt: float):
	for i in range(rockets.size() - 1, -1, -1):
		var r: Dictionary = rockets[i]
		r.age += dt
		var next: Vector3 = r.p + r.v * dt
		var done := false
		for pl in players:
			if (pl.who == r.owner and r.age < .2) or pl.dead > 0:continue
			var c: Vector3 = pl.p + Vector3(0, .9, 0)
			if Geometry3D.get_closest_point_to_segment(c, r.p, next).distance_to(c) < .55:
				explode(r, c, pl);done = true;break
		if not done:
			for k in range(1, 5):
				var q: Vector3 = r.p.lerp(next, k / 4.0)
				if not solid(q - Vector3(0, .01, 0), Vector3(.01, .005, .01)).is_empty() or q.y <= 0.0:
					explode(r, q - r.v.normalized() * .1);done = true;break
		if done or r.age > 4.0:rockets.remove_at(i)
		else:r.p = next
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		s.age += dt
		var next: Vector3 = s.p + s.v * dt
		var done := false
		for pl in players:
			if pl.who == s.owner or pl.dead > 0:continue
			var c: Vector3 = pl.p + Vector3(0, .9, 0)
			if Geometry3D.get_closest_point_to_segment(c, s.p, next).distance_to(c) < .5:
				hurt(pl, s.damage, s.owner, "charges");mark(steve() if s.owner == "steve" else notch(), pl, s.damage);done = true;break
		if not done and (next.y <= 0 or not solid(next - Vector3(0, .01, 0), Vector3(.01, .005, .01)).is_empty()):done = true
		if done or s.age > 1.5:shots.remove_at(i)
		else:s.p = next
	for list in [blasts, beams]:
		for b in list:b.age += dt
	blasts = blasts.filter(func(b):return b.age < .5)
	beams = beams.filter(func(b):return b.age < .45)
	for g in gibs:
		g.age += dt;g.v.y -= GRAVITY * dt;g.p += g.v * dt
		if g.p.y < .05:g.p.y = .05;g.v *= .5
	gibs = gibs.filter(func(g):return g.age < 2.5)
	for nm in numbers:nm.age += dt;nm.p.y += dt * .8
	numbers = numbers.filter(func(nm):return nm.age < .8)

func line_clear(a: Vector3, b: Vector3) -> bool:
	for k in range(1, 24):
		var q: Vector3 = a.lerp(b, k / 24.0)
		if not solid(q - Vector3(0, .01, 0), Vector3(.01, .005, .01)).is_empty():return false
	return true

func respawn(pl: Dictionary):
	var other: Dictionary = notch() if pl.who == "steve" else steve()
	var best: Vector3 = spawns[0];var far := -1.0
	for s in spawns:
		var d: float = s.distance_to(other.p)
		if d > far:far = d;best = s
	pl.p = best;pl.v = Vector3.ZERO;pl.hp = 100.0;pl.armor = 0.0;pl.quad = 0.0
	pl.ammo = maxi(pl.ammo, 8);pl.charges = maxi(pl.charges, 50);pl.bolts = 0;pl.owned.crossbow = false;pl.weapon = "rockets"
	pl.yaw = atan2(-(other.p.x - best.x), -(other.p.z - best.z))
	sounds.append("spawn")

## Input for Steve: wish (x strafe, y forward), look delta, fire, jump, weapon.
func step(dt: float, wish: Vector2, turn: Vector2, firing: bool, jump: bool, weapon := ""):
	age += dt
	sounds.clear()
	for f in feed:f.age += dt
	feed = feed.filter(func(f):return f.age < 5.0)
	if state == "intro":
		if age >= 2.0:state = "fight"
		return
	if state in ["won", "lost"]:return
	var s: Dictionary = steve()
	if not weapon.is_empty():
		if weapon in ["next", "prev"]:
			var i: int = ORDER.find(s.weapon)
			for k in range(1, 5):
				var cand: String = ORDER[posmod(i + (k if weapon == "next" else -k), 4)]
				if s.owned.get(cand, false):select(s, cand);break
		else:select(s, weapon)
	s.yaw -= turn.x;s.pitch = clampf(s.pitch - turn.y, -1.45, 1.45)
	var fwd := Vector3(-sin(s.yaw), 0, -cos(s.yaw));var right := Vector3(cos(s.yaw), 0, -sin(s.yaw))
	for pl in players:
		pl.cool = maxf(0, pl.cool - dt);pl.flash = maxf(0, pl.flash - dt);pl.fired = maxf(0, pl.fired - dt);pl.quad = maxf(0, pl.quad - dt)
		pl.hitmark = maxf(0, pl.hitmark - dt);pl.swing = maxf(0, pl.swing - dt)
		if pl.dead > 0:
			pl.dead -= dt
			if pl.dead <= 0:respawn(pl)
			continue
		if pl == s:
			walk(pl, (fwd * wish.y + right * wish.x).limit_length(1.0), jump, dt)
			if firing:fire(pl)
		elif ai:bot(pl, s, dt)
		else:walk(pl, Vector3.ZERO, false, dt)
		for lv in lava:
			if pl.p.x > lv[0].x and pl.p.x < lv[1].x and pl.p.z > lv[0].z and pl.p.z < lv[1].z and pl.p.y < .3:
				pl.lava -= dt
				if pl.lava <= 0:pl.lava = .3;hurt(pl, 10.0, pl.who, "lava")
	update_projectiles(dt)
	pickups(dt)
	for i in range(2):
		if players[i].frags >= FRAGS:winner = i;state = "won" if i == 0 else "lost"

func pickups(dt: float):
	for it in items:
		it.left = maxf(0, it.left - dt)
		if it.left > 0:continue
		for pl in players:
			if pl.dead > 0 or pl.p.distance_to(it.p) > 1.1:continue
			match it.kind:
				"health":
					if pl.hp >= 100:continue
					pl.hp = minf(100.0, pl.hp + 25.0)
				"mega":pl.hp = minf(200.0, pl.hp + 100.0)
				"armor":
					if pl.armor >= 100:continue
					pl.armor = minf(100.0, pl.armor + 50.0)
				"charges":pl.charges += 40
				"rockets":pl.ammo += 6;pl.owned.rockets = true
				"crossbow":
					pl.bolts += 6;pl.owned.crossbow = true
					if pl.who == "steve":select(pl, "crossbow")
				"quad":pl.quad = 10.0;feed.append({"text":("Стив" if pl.who == "steve" else "Нотч") + " взял Quad Damage", "age":0.0})
			it.left = it.every
			sounds.append(("pickup_" + it.kind) if pl.who == "steve" else "npickup")
			break

# ------------------------------------------------------------------ Notch

## Weapon by range and ammo; aims at where you were a moment ago plus your
## velocity, at your feet with rockets; dodges when you line up on him.
func bot(n: Dictionary, s: Dictionary, dt: float):
	bot_history.append(s.p);if bot_history.size() > 12:bot_history.pop_front()
	var seen_at: Vector3 = bot_history[0]
	var sees: bool = s.dead <= 0 and line_clear(eye(n), eye(s))
	var dist: float = n.p.distance_to(s.p)
	bot_timer -= dt;bot_dodge = maxf(0, bot_dodge - dt)
	if bot_timer <= 0:
		bot_timer = .5
		bot_goal = choose_goal(n, s, sees, dist)
	var wanted: String = "pickaxe" if dist < 1.8 else ("crossbow" if n.owned.crossbow and n.bolts > 0 and dist > 9 else ("rockets" if n.ammo > 0 and dist > 3.5 else "charges"))
	select(n, wanted)
	var to_goal: Vector3 = bot_goal - n.p;to_goal.y = 0
	var wish: Vector3 = to_goal.normalized() if to_goal.length() > .8 else Vector3.ZERO
	var jump := false
	# Dodge: you are looking straight at him, or a rocket is coming.
	var aimed: bool = sees and look(s).dot((eye(n) - eye(s)).normalized()) > .985
	var incoming := false
	for r in rockets:
		if r.owner == "steve" and r.p.distance_to(n.p) < 6.0 and r.v.normalized().dot((n.p - r.p).normalized()) > .8:incoming = true
	if (aimed or incoming) and bot_dodge <= 0:
		bot_dodge = .55;bot_strafe = -bot_strafe;jump = n.grounded and int(age * 7) % 3 != 0
	if sees:
		var to_s: Vector3 = s.p - n.p;to_s.y = 0
		var side := Vector3(to_s.z, 0, -to_s.x).normalized() * bot_strafe
		var keep_range: float = {"crossbow":13.0, "rockets":8.0, "charges":5.0, "pickaxe":0.0}[n.weapon]
		var keep: float = clampf((to_s.length() - keep_range) / 4.0, -1, 1)
		if to_goal.length() < 3.0 or n.hp > 60:wish = (to_s.normalized() * keep + side * (1.4 if bot_dodge > 0 else .8)).normalized()
		var speed: float = {"crossbow":0.0, "rockets":ROCKET_SPEED, "charges":34.0, "pickaxe":0.0}[n.weapon]
		var flight: float = n.p.distance_to(s.p) / speed if speed > 0 else 0.0
		var aim: Vector3 = seen_at.lerp(s.p, .6) + Vector3(s.v.x, s.v.y * .3, s.v.z) * flight
		aim += Vector3(0, .15, 0) if n.weapon == "rockets" and s.grounded else Vector3(0, .95, 0)
		var err: float = sin(age * 2.7) * (.07 if n.weapon == "crossbow" else .04) * (1.0 + float(steve().frags) * -.2)
		var d: Vector3 = (aim - eye(n)).normalized()
		var want_yaw: float = atan2(-d.x, -d.z) + err;var want_pitch: float = asin(clampf(d.y, -1, 1))
		n.yaw = lerp_angle(n.yaw, want_yaw, minf(1.0, dt * 9.0));n.pitch = lerpf(n.pitch, want_pitch, minf(1.0, dt * 9.0))
		var lined: bool = absf(angle_difference(n.yaw, want_yaw)) < (.04 if n.weapon == "crossbow" else .12)
		if lined and n.cool <= 0:fire(n)
	else:
		if wish.length() > 0:n.yaw = lerp_angle(n.yaw, atan2(-wish.x, -wish.z), minf(1.0, dt * 6.0));n.pitch = 0.0
	# Rocket jump to the galleries when the goal is up there.
	if bot_goal.y > 2.5 and n.p.y < 1.0 and to_goal.length() < 4.0 and n.ammo > 2 and n.hp > 70 and n.grounded and n.cool <= 0:
		select(n, "rockets");n.pitch = -1.45;fire(n);jump = true
	walk(n, wish, jump, dt)
	if n.ammo <= 0 and n.charges <= 0:n.charges = 30

func choose_goal(n: Dictionary, s: Dictionary, sees: bool, dist: float) -> Vector3:
	var best = null;var score := -INF
	for it in items:
		if it.left > 0:continue
		var value: float = 0.0
		match it.kind:
			"mega":value = 90.0
			"quad":value = 80.0
			"health":value = (100.0 - n.hp) * .9
			"armor":value = (100.0 - n.armor) * .5
			"crossbow":value = 50.0 if not n.owned.crossbow else 15.0
			"rockets":value = 30.0 if n.ammo < 6 else 5.0
			"charges":value = 12.0 if n.charges < 30 else 0.0
		value -= n.p.distance_to(it.p) * 2.2
		if value > score:score = value;best = it.p
	if best != null and (score > 20.0 or not sees or n.hp < 50):return best
	return s.p + Vector3(cos(age * .7) * 7, 0, sin(age * .7) * 7)
