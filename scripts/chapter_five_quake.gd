extends RefCounted
## Notch's favourite game: a small deathmatch arena, rockets only, first to
## three frags. Units are blocks; y is up. Pure simulation.
const GRAVITY := 22.0
const JUMP := 7.2
const RUN := 8.0
const AIR := 2.2
const HALF := Vector3(.35, .9, .35)
const EYE := 1.55
const ROCKET_SPEED := 17.0
const SPLASH := 2.6
const FRAGS := 3
## Solid boxes: [min, max, texture].
var boxes: Array = []
var lava: Array = []
var pads: Array = []
var spawns: Array = []
var items: Array = []
var players: Array = []
var rockets: Array = []
var blasts: Array = []
var feed: Array = []
var age := 0.0
var state := "intro"
var winner := -1
var bot_timer := 0.0
var bot_goal := Vector3.ZERO
var bot_strafe := 1.0
var serial := 0
## Tests can hold Notch still.
var ai := true

func reset():
	boxes.clear();lava.clear();pads.clear();spawns.clear();items.clear();rockets.clear();blasts.clear();feed.clear()
	age = 0.0;state = "intro";winner = -1;bot_timer = 0.0;bot_strafe = 1.0;serial = 0
	build_map()
	players = [make("steve", spawns[0], 0.0), make("notch", spawns[2], PI)]

func box(a: Vector3, b: Vector3, tex: String):boxes.append([a, b, tex])

func build_map():
	var w := 18.0
	box(Vector3(-w - 1, -1, -w - 1), Vector3(w + 1, 0, w + 1), "polished_deepslate")
	box(Vector3(-w - 1, 0, -w - 1), Vector3(w + 1, 6, -w), "polished_blackstone_bricks")
	box(Vector3(-w - 1, 0, w), Vector3(w + 1, 6, w + 1), "polished_blackstone_bricks")
	box(Vector3(-w - 1, 0, -w), Vector3(-w, 6, w), "polished_blackstone_bricks")
	box(Vector3(w, 0, -w), Vector3(w + 1, 6, w), "polished_blackstone_bricks")
	for c in [Vector3(-9, 0, -9), Vector3(9, 0, -9), Vector3(-9, 0, 9), Vector3(9, 0, 9)]:
		box(c - Vector3(1, 0, 1), c + Vector3(1, 5, 1), "cut_copper")
	box(Vector3(-3.5, 0, -3.5), Vector3(3.5, 2.6, 3.5), "deepslate_tiles")
	box(Vector3(-14, 0, -2), Vector3(-12.5, 1.4, 2), "exposed_cut_copper")
	box(Vector3(12.5, 0, -2), Vector3(14, 1.4, 2), "exposed_cut_copper")
	box(Vector3(-2, 0, 12.5), Vector3(2, 1.4, 14), "iron_block")
	box(Vector3(-2, 0, -14), Vector3(2, 1.4, -12.5), "iron_block")
	lava = [[Vector3(-16, -.1, 5.5), Vector3(-11, .05, 8.5)], [Vector3(11, -.1, -8.5), Vector3(16, .05, -5.5)]]
	pads = [{"p":Vector3(0, 0, 6.0), "push":Vector3(0, 11.5, -3.6)}, {"p":Vector3(0, 0, -6.0), "push":Vector3(0, 11.5, 3.6)}]
	spawns = [Vector3(-14, 0, 14), Vector3(14, 0, 14), Vector3(14, 0, -14), Vector3(-14, 0, -14)]
	items = [{"kind":"health", "p":Vector3(-13, 1.4, 0), "left":0.0}, {"kind":"health", "p":Vector3(13, 1.4, 0), "left":0.0},
		{"kind":"armor", "p":Vector3(0, 1.4, 13), "left":0.0}, {"kind":"ammo", "p":Vector3(0, 1.4, -13), "left":0.0},
		{"kind":"quad", "p":Vector3(0, 2.6, 0), "left":10.0}, {"kind":"health", "p":Vector3(-9, 0, 0), "left":0.0}, {"kind":"health", "p":Vector3(9, 0, 0), "left":0.0}]

func make(who: String, at: Vector3, yaw: float) -> Dictionary:
	return {"who":who, "p":at, "v":Vector3.ZERO, "yaw":yaw, "pitch":0.0, "hp":100.0, "armor":0.0, "ammo":20, "cool":0.0,
		"frags":0, "dead":0.0, "quad":0.0, "flash":0.0, "grounded":true, "walk":0.0, "fired":0.0, "lava":0.0}

func steve() -> Dictionary:return players[0]
func notch() -> Dictionary:return players[1]

func eye(pl: Dictionary) -> Vector3:return pl.p + Vector3(0, EYE, 0)
func look(pl: Dictionary) -> Vector3:
	return Vector3(-sin(pl.yaw) * cos(pl.pitch), sin(pl.pitch), -cos(pl.yaw) * cos(pl.pitch))

func solid(p: Vector3, half: Vector3) -> Array:
	var out: Array = []
	for b in boxes:
		if p.x + half.x > b[0].x and p.x - half.x < b[1].x and p.y + half.y * 2 > b[0].y and p.y < b[1].y and p.z + half.z > b[0].z and p.z - half.z < b[1].z:out.append(b)
	return out

## Axis-separated movement: x, z, then y; landing on box tops.
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
			# Small steps up onto low ledges.
			var up: Vector3 = q + Vector3(0, .45, 0)
			if pl.grounded and solid(up, HALF).is_empty():pl.p = up
			else:pl.v[axis] = 0.0

func walk(pl: Dictionary, wish: Vector3, jump: bool, dt: float):
	pl.grounded = not solid(pl.p - Vector3(0, .05, 0), HALF).is_empty()
	var flat := Vector3(pl.v.x, 0, pl.v.z)
	if pl.grounded:
		flat = flat.move_toward(wish * RUN, dt * 60.0)
		if jump:pl.v.y = JUMP;pl.grounded = false
	else:
		flat += wish * AIR * dt * 10.0
		if flat.length() > maxf(RUN, Vector3(pl.v.x, 0, pl.v.z).length()):flat = flat.normalized() * maxf(RUN, Vector3(pl.v.x, 0, pl.v.z).length())
	pl.v.x = flat.x;pl.v.z = flat.z
	pl.v.y -= GRAVITY * dt
	move(pl, dt)
	pl.walk += flat.length() * dt
	for pad in pads:
		if pl.grounded and Vector2(pl.p.x - pad.p.x, pl.p.z - pad.p.z).length() < .9:
			pl.v = pad.push;pl.grounded = false;feed_sound("pad")

var sounds: Array = []
func feed_sound(id: String):sounds.append(id)

func fire(pl: Dictionary):
	if pl.cool > 0 or pl.ammo <= 0 or pl.dead > 0:return
	pl.cool = .8;pl.ammo -= 1;pl.fired = .12
	var dir: Vector3 = look(pl)
	rockets.append({"owner":pl.who, "p":eye(pl) + dir * .6 + Vector3(0, -.15, 0), "v":dir * ROCKET_SPEED, "age":0.0, "quad":pl.quad > 0})
	feed_sound("rocket")

func hurt(pl: Dictionary, amount: float, by: String, how: String):
	if pl.dead > 0:return
	var save: float = minf(pl.armor, amount * .6)
	pl.armor -= save;pl.hp -= amount - save;pl.flash = .2
	if pl.hp <= 0:
		pl.dead = 1.6;pl.hp = 0.0
		var killer: Dictionary = steve() if by == "steve" else notch()
		if by != pl.who:killer.frags += 1
		else:pl.frags = maxi(0, pl.frags - 1)
		feed.append({"text":obituary(pl.who, by, how), "age":0.0})
		feed_sound("gib")

func obituary(victim: String, by: String, how: String) -> String:
	var names := {"steve":"Стив", "notch":"Нотч"}
	if victim == by:return "%s словил собственную ракету" % names[victim]
	if how == "lava":return "%s решил искупаться в лаве" % names[victim]
	return "%s поймал ракету %s" % [names[victim], "Нотча" if by == "notch" else "Стива"]

func explode(r: Dictionary, at: Vector3, direct = null):
	blasts.append({"p":at, "age":0.0})
	feed_sound("boom")
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
		hurt(pl, dmg, r.owner, "rocket")

func update_rockets(dt: float):
	for i in range(rockets.size() - 1, -1, -1):
		var r: Dictionary = rockets[i]
		r.age += dt
		var next: Vector3 = r.p + r.v * dt
		var done := false
		for pl in players:
			if pl.who == r.owner and r.age < .2:continue
			if pl.dead > 0:continue
			var c: Vector3 = pl.p + Vector3(0, .9, 0)
			if Geometry3D.get_closest_point_to_segment(c, r.p, next).distance_to(c) < .55:
				explode(r, c, pl);done = true;break
		if not done:
			var steps := 4
			for k in range(1, steps + 1):
				var q: Vector3 = r.p.lerp(next, float(k) / steps)
				if not solid(q - Vector3(0, .01, 0), Vector3(.01, .005, .01)).is_empty() or q.y <= 0.0:
					explode(r, q - r.v.normalized() * .1);done = true;break
		if done or r.age > 4.0:rockets.remove_at(i)
		else:r.p = next
	for b in blasts:b.age += dt
	blasts = blasts.filter(func(b):return b.age < .5)

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
	pl.p = best;pl.v = Vector3.ZERO;pl.hp = 100.0;pl.armor = 0.0;pl.ammo = maxi(pl.ammo, 12);pl.quad = 0.0
	pl.yaw = atan2(-(other.p.x - best.x), -(other.p.z - best.z))
	feed_sound("spawn")

## Input for Steve: wish (x = strafe, y = forward), look deltas, fire, jump.
func step(dt: float, wish: Vector2, turn: Vector2, firing: bool, jump: bool):
	age += dt
	sounds.clear()
	for f in feed:f.age += dt
	feed = feed.filter(func(f):return f.age < 5.0)
	if state == "intro":
		if age >= 2.0:state = "fight"
		return
	if state == "won" or state == "lost":return
	var s: Dictionary = steve()
	s.yaw -= turn.x;s.pitch = clampf(s.pitch - turn.y, -1.45, 1.45)
	var fwd := Vector3(-sin(s.yaw), 0, -cos(s.yaw));var right := Vector3(cos(s.yaw), 0, -sin(s.yaw))
	for pl in players:
		pl.cool = maxf(0, pl.cool - dt);pl.flash = maxf(0, pl.flash - dt);pl.fired = maxf(0, pl.fired - dt);pl.quad = maxf(0, pl.quad - dt)
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
	update_rockets(dt)
	for it in items:
		it.left = maxf(0, it.left - dt)
		if it.left > 0:continue
		for pl in players:
			if pl.dead > 0 or pl.p.distance_to(it.p) > 1.1:continue
			match it.kind:
				"health":
					if pl.hp >= 100:continue
					pl.hp = minf(100.0, pl.hp + 25.0);it.left = 15.0
				"armor":pl.armor = minf(100.0, pl.armor + 50.0);it.left = 25.0
				"ammo":pl.ammo += 8;it.left = 15.0
				"quad":pl.quad = 10.0;it.left = 40.0;feed.append({"text":("Стив" if pl.who == "steve" else "Нотч") + " взял Quad Damage", "age":0.0})
			feed_sound("pickup_" + it.kind)
			break
	for i in range(2):
		if players[i].frags >= FRAGS:
			winner = i;state = "won" if i == 0 else "lost"

## Notch: goes for items and high ground, strafes, leads his shots.
func bot(n: Dictionary, s: Dictionary, dt: float):
	bot_timer -= dt
	var sees: bool = s.dead <= 0 and line_clear(eye(n), eye(s))
	if bot_timer <= 0:
		bot_timer = 2.5
		bot_strafe = -bot_strafe
		var options: Array = items.filter(func(it):return it.left <= 0 and (it.kind != "health" or n.hp < 70))
		if not options.is_empty() and (not sees or n.hp < 50):
			options.sort_custom(func(a, b):return n.p.distance_to(a.p) < n.p.distance_to(b.p))
			bot_goal = options[0].p
		else:bot_goal = s.p + Vector3(cos(age) * 6, 0, sin(age) * 6)
	var to_goal: Vector3 = bot_goal - n.p;to_goal.y = 0
	var wish: Vector3 = to_goal.normalized() if to_goal.length() > 1 else Vector3.ZERO
	if sees:
		var to_s: Vector3 = s.p - n.p;to_s.y = 0
		var side := Vector3(to_s.z, 0, -to_s.x).normalized() * bot_strafe
		var keep: float = clampf((to_s.length() - 9.0) / 6.0, -1, 1)
		wish = (to_s.normalized() * keep + side).normalized()
		var flight: float = n.p.distance_to(s.p) / ROCKET_SPEED
		var aim: Vector3 = s.p + Vector3(s.v.x, 0, s.v.z) * flight * .7 + Vector3(0, .3, 0)
		var err: float = sin(age * 2.3) * .06
		var d: Vector3 = (aim - eye(n)).normalized()
		n.yaw = atan2(-d.x, -d.z) + err;n.pitch = asin(clampf(d.y, -1, 1))
		if n.cool <= 0 and n.ammo > 0:fire(n)
	else:
		if wish.length() > 0:n.yaw = atan2(-wish.x, -wish.z);n.pitch = 0.0
	walk(n, wish, sees and int(age * 3) % 7 == 0, dt)
	if n.ammo <= 0:n.ammo = 6
