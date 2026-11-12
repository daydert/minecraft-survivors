extends RefCounted
## Draws the chapter IV impact layer. Reads `world.fx` and the paused world
## clock only; never writes simulation state.
const FinaleView = preload("res://scripts/chapter_four_finale_view.gd")
const Atmosphere = preload("res://scripts/ui/atmosphere.gd")
const SCREEN := Rect2(-70, -70, 780, 500)
const GIB := {"ender": Color(0.45, 0.16, 0.6), "flesh": Color(0.47, 0.03, 0.05), "bone": Color(0.8, 0.77, 0.68), "stone": Color(0.5, 0.47, 0.44), "dirt": Color(0.24, 0.19, 0.18), "iron": Color(0.7, 0.7, 0.66)}

static func hh(i: int, salt: int) -> float:
	return Atmosphere.hash01(i, salt, 43)

# ------------------------------------------------------------------ ground

static func floor_layer(g, offset: Vector2):
	var w = g.world
	var fx = w.fx
	dread_floor(g, offset)
	for pool in fx.pools:
		var p: Vector2 = pool.p + offset
		if not SCREEN.has_point(p):continue
		if fx.ender:
			var sz: float = pool.size * smoothstep(0.0, 1.6, w.clock - pool.born)
			g.oval(p, Vector2(sz * 1.7 + 1, sz * 0.42 + 1), Color(0.12, 0.02, 0.18, 0.9));g.oval(p, Vector2(sz * 1.6, sz * 0.38), Color(0.4, 0.14, 0.55, 0.9))
			continue
		FinaleView.blood_pool(g, p, pool.size * smoothstep(0.0, 1.6, w.clock - pool.born), w.clock)
	for s in fx.stains:
		var p: Vector2 = s.p + offset
		if not SCREEN.has_point(p):continue
		match s.kind:
			"blood":
				if fx.ender:
					g.oval(p, Vector2(s.r * 1.2 + 1, s.r * 0.45 + 1), Color(0.14, 0.03, 0.2, 0.75));g.oval(p, Vector2(s.r * 1.1, s.r * 0.4), Color(0.42, 0.16, 0.58, 0.8))
					continue
				if s.r < 2.4:
					g.draw_rect(Rect2(p.floor() - Vector2(1, 0), Vector2(3, 2)), Color(0.13, 0.0, 0.01, 0.9))
					g.draw_rect(Rect2(p.floor(), Vector2(2, 1)), Color(0.38, 0.0, 0.03, 0.95))
				else:FinaleView.splat(g, p, s.r * 0.62, int(s.seed), minf(1.0, 0.4 + (w.clock - s.born) * 4.0))
			"scorch":scorch(g, p, s, w.clock)
			"crack":crack(g, s, offset, w.clock)
	for f in fx.flashes:
		var k: float = 1.0 - f.age / f.life
		g.oval(f.p + offset, Vector2(f.r * 0.62, f.r * 0.32), Color(f.color, 0.2 * k * k))
	for r in fx.rings:ground_ring(g, r, offset, w.clock)
	for c in fx.gibs:
		var p: Vector2 = c.p + offset
		if not SCREEN.has_point(p):continue
		if c.rest > 0:
			var fade: float = clampf((c.life - c.rest) / 1.2, 0.0, 1.0)
			chunk(g, p, c, fade)
		else:g.oval(p, Vector2(c.size * 0.8, 1), Color(0, 0, 0, 0.3))
	for s in fx.shells:
		var p: Vector2 = s.p + offset
		if s.z > 0:
			g.oval(p, Vector2(2, 1), Color(0, 0, 0, 0.3))
			continue
		var fade: float = clampf((7.0 - s.age) / 1.0, 0.0, 1.0)
		g.draw_rect(Rect2(p.floor() - Vector2(1, 0), Vector2(3, 1)), Color(0.72, 0.56, 0.24, fade))
		g.draw_rect(Rect2(p.floor() - Vector2(1, 0), Vector2(1, 1)), Color(0.95, 0.85, 0.5, fade))

static func chunk(g, p: Vector2, c: Dictionary, alpha: float):
	var color: Color = GIB.get(c.kind, GIB.flesh)
	var size := Vector2(c.size + (1 if int(c.seed) % 2 else 0), c.size)
	g.draw_rect(Rect2(p.floor() - Vector2(size.x * 0.5, size.y), size), Color(color.darkened(0.45), alpha))
	g.draw_rect(Rect2(p.floor() - Vector2(size.x * 0.5, size.y), size - Vector2(1, 1)), Color(color, alpha))
	if c.kind == "flesh":g.draw_rect(Rect2(p.floor() - Vector2(size.x * 0.5, size.y), Vector2(1, 1)), Color(0.85, 0.5, 0.45, alpha))
	elif c.kind == "bone":g.draw_rect(Rect2(p.floor() - Vector2(size.x * 0.5, size.y), Vector2(size.x, 1)), Color(0.96, 0.94, 0.86, alpha))

static func scorch(g, p: Vector2, s: Dictionary, clock: float):
	var age: float = clock - s.born
	var r: float = s.r
	g.oval(p, Vector2(r * 1.5, r * 0.78), Color(0.03, 0.02, 0.02, 0.42))
	g.oval(p, Vector2(r * 0.95, r * 0.5), Color(0.0, 0.0, 0.0, 0.45))
	for j in range(7):
		var a: float = hh(j + int(s.seed), 3) * TAU
		var q: Vector2 = p + Vector2(cos(a) * r * 1.5, sin(a) * r * 0.8) * (0.7 + hh(j + int(s.seed), 4) * 0.5)
		g.draw_rect(Rect2(q.floor(), Vector2(2, 1)), Color(0.02, 0.01, 0.01, 0.55))
	if age < 3.0:
		for j in range(5):
			var a: float = hh(j + int(s.seed), 5) * TAU
			var q: Vector2 = p + Vector2(cos(a) * r, sin(a) * r * 0.5) * hh(j + int(s.seed), 6)
			g.draw_rect(Rect2(q.floor(), Vector2(1, 1)), Color(1.0, 0.5, 0.18, (1.0 - age / 3.0) * (0.5 + 0.5 * sin(clock * 9.0 + j))))

static func crack_points(a: Vector2, b: Vector2, seed: int, jag: float) -> PackedVector2Array:
	var length := a.distance_to(b)
	var dir := (b - a) / maxf(1.0, length)
	var side := dir.orthogonal()
	var steps := maxi(3, int(length / 6.0))
	var points := PackedVector2Array([a.floor()])
	for i in range(1, steps + 1):
		var t := float(i) / steps
		points.append((a + dir * length * t + side * (hh(i, seed) - 0.5) * 2.0 * jag * sin(t * PI)).floor())
	return points

static func crack(g, s: Dictionary, offset: Vector2, clock: float):
	var end: Vector2 = s.end + offset
	var start: Vector2 = s.p + offset - s.dir * s.r * 0.6
	var age: float = clock - s.born
	var points := crack_points(start, end, int(s.seed), 4.0)
	var shown: int = clampi(int(points.size() * minf(1.0, age * 9.0)) + 1, 2, points.size())
	points = points.slice(0, shown)
	g.draw_polyline(points, Color(0.02, 0.01, 0.015, 0.9), 2)
	for i in range(1, points.size() - 1, 2):
		var branch: Vector2 = s.dir.orthogonal() * (1 if hh(i, int(s.seed) + 7) > 0.5 else -1) * (3.0 + hh(i, int(s.seed) + 9) * 6.0)
		g.draw_line(points[i], (points[i] + branch + s.dir * 2).floor(), Color(0.02, 0.01, 0.015, 0.75), 1)
	if age < 0.5:g.draw_polyline(points, Color(1, 0.95, 0.85, 0.8 * (1.0 - age / 0.5)), 1)

static func broken_arc(g, p: Vector2, radius: Vector2, seed: int, color: Color, width: float, pieces: int = 9, fill: float = 0.62):
	for j in range(pieces):
		var a0: float = (j + hh(j, seed) * 0.3) * TAU / pieces
		var a1: float = a0 + TAU / pieces * fill
		var points := PackedVector2Array()
		for k in range(5):
			var a: float = lerpf(a0, a1, k / 4.0)
			points.append(p + Vector2(cos(a), sin(a)) * radius)
		g.draw_polyline(points, color, width)

static func ground_ring(g, r: Dictionary, offset: Vector2, clock: float):
	var p: Vector2 = r.p + offset
	var k: float = clampf(r.age / r.life, 0.0, 1.0)
	var ease: float = 1.0 - pow(1.0 - k, 3.0)
	match r.kind:
		"toll":
			var base: Color = Color(0.72, 0.8, 0.95) if r.get("ghost", false) else Color(0.95, 0.78, 0.42)
			for j in range(3):
				var e: float = clampf(ease - j * 0.14, 0.0, 1.0)
				if e <= 0:continue
				var rad := Vector2(r.r, r.r * 0.55) * e
				broken_arc(g, p, rad, int(r.seed) + j * 5, Color(0.05, 0.03, 0.02, 0.5 * (1.0 - k)), 3.0 - j)
				broken_arc(g, p - Vector2(0, 1), rad, int(r.seed) + j * 5, Color(base, (0.85 - j * 0.22) * (1.0 - k)), 2.0 - j * 0.5)
			for j in range(14):
				var d := Vector2.from_angle(j * TAU / 14 + hh(j, int(r.seed)) * 0.4)
				var q: Vector2 = p + d * Vector2(r.r, r.r * 0.55) * ease
				g.draw_rect(Rect2((q - Vector2(0, sin(k * PI) * (5 + j % 4 * 2))).floor(), Vector2(2, 2)), Color(0.4, 0.33, 0.28, 1.0 - k))
		"slash":
			var dir: Vector2 = r.dir
			var half_arc: float=float(r.get("half_arc",1.15))
			var sweep: float = lerpf(-half_arc, half_arc, minf(1.0, k * 2.2))
			var last := Vector2.ZERO
			for j in range(15):
				var a: float = dir.angle() + lerpf(-half_arc, sweep, j / 14.0)
				var taper: float = sin(j / 14.0 * PI)
				var q: Vector2 = p + Vector2(cos(a), sin(a) * 0.72) * (r.r - 5.0 * taper) - Vector2(0, 9)
				if j > 0:
					g.draw_line(last, q, Color(0.04, 0.03, 0.04, 0.7 * (1.0 - k)), 3.0 + 11.0 * taper)
					g.draw_line(last + Vector2(cos(a), sin(a) * 0.72) * 5.0 * taper, q + Vector2(cos(a), sin(a) * 0.72) * 5.0 * taper, Color(0.93, 0.91, 0.87, 1.0 - k), 2)
				last = q
		"heart":
			broken_arc(g, p, Vector2(r.r, r.r * 0.5) * ease, int(r.seed), Color(0.95, 0.1, 0.1, 0.8 * (1.0 - k)), 2, 14, 0.8)
			broken_arc(g, p, Vector2(r.r, r.r * 0.5) * ease * 0.6, int(r.seed) + 3, Color(0.6, 0.02, 0.04, 0.6 * (1.0 - k)), 1, 10, 0.7)
		"revive", "thorns":
			broken_arc(g, p, Vector2(r.r, r.r * 0.5) * ease, int(r.seed), Color(0.7, 0.95, 0.45, 1.0 - k) if r.kind == "revive" else Color(0.85, 0.85, 0.9, 1.0 - k), 2, 12, 0.7)
		"evolve":
			for j in range(2):
				var e: float = clampf(ease - j * 0.2, 0.0, 1.0)
				broken_arc(g, p, Vector2(r.r, r.r * 0.52) * e, int(r.seed) + j, Color(1.0, 0.86, 0.5, (0.9 - j * 0.3) * (1.0 - k)), 2, 16, 0.85)
			for j in range(16):
				var d := Vector2.from_angle(j * TAU / 16)
				var q: Vector2 = p + d * Vector2(r.r, r.r * 0.52) * ease
				g.draw_line(q, q + d * Vector2(10, 5) * (1.0 - k), Color(1, 0.95, 0.7, 1.0 - k), 1)

# ------------------------------------------------------------------ air

static func air_layer(g, offset: Vector2):
	var w = g.world
	var fx = w.fx
	for c in fx.gibs:
		if c.rest > 0:continue
		var p: Vector2 = c.p + offset - Vector2(0, c.z)
		if not SCREEN.has_point(p):continue
		chunk(g, p, c, 1.0)
		if c.kind == "flesh":g.draw_line(p - Vector2(0, c.size * 0.5), p - Vector2(0, c.size * 0.5) - (c.v * 0.02 + Vector2(0, -c.vz * 0.02)), Color(0.45, 0.0, 0.03, 0.8), 1)
	for d in fx.drops:
		var p: Vector2 = d.p + offset - Vector2(0, d.z)
		if not SCREEN.has_point(p):continue
		var tail: Vector2 = (d.v + Vector2(0, -d.vz)) * 0.028
		g.draw_line(p - tail, p, Color(0.32, 0.08, 0.45, 0.9) if fx.ender else Color(0.42, 0.0, 0.03, 0.9), maxf(1.0, d.size * 0.6))
		g.draw_rect(Rect2(p.floor(), Vector2(d.size, d.size).ceil()), Color(0.66, 0.3, 0.88) if fx.ender else Color(0.66, 0.02, 0.05))
		if d.size >= 2:g.draw_rect(Rect2(p.floor(), Vector2.ONE), Color(1, 0.45, 0.45))
	for s in fx.shells:
		if s.z <= 0:continue
		var p: Vector2 = s.p + offset - Vector2(0, s.z)
		var d := Vector2.from_angle(s.spin) * 1.5
		g.draw_line(p - d, p + d, Color(0.85, 0.68, 0.3), 1)
	for s in fx.smoke:
		var p: Vector2 = s.p + offset - Vector2(0, s.z)
		if not SCREEN.has_point(p):continue
		var k: float = s.age / s.life
		var r: float = s.r * (0.7 + k * 1.1)
		g.oval(p, Vector2(r, r * 0.72), Color(s.color, s.color.a * (1.0 - k) * (1.0 - k)))
	for s in fx.sparks:
		var p: Vector2 = s.p + offset - Vector2(0, s.z)
		var k: float = s.age / s.life
		g.draw_line(p - (s.v + Vector2(0, -s.vz)) * 0.025, p, Color(s.color, 1.0 - k), 1)
	for r in fx.rings:
		if r.kind != "jaws":continue
		var p: Vector2 = r.p + offset
		var k: float = clampf(r.age / r.life, 0, 1)
		var gap: float = 7.0 * (1.0 - smoothstep(0.0, 0.55, k))
		for side in [-1, 1]:
			for j in range(4):
				var q: Vector2 = p + Vector2((j - 1.5) * 3.2, side * (gap + 1))
				g.draw_colored_polygon(PackedVector2Array([q + Vector2(-1.5, side * 3), q + Vector2(0, -side * 1.5), q + Vector2(1.5, side * 3)]), Color(0.95, 0.9, 0.82, 1.0 - k * 0.6))
	for b in fx.bursts:
		if g.settings.flashes or b.age > 0.1:FinaleView.impact_burst(g, b.p + offset, b.age, b.big, int(b.seed), b.blood)
	for wisp in fx.wisps:
		var k: float = clampf(wisp.age / wisp.life, 0, 1)
		var from: Vector2 = wisp.from + offset
		var to: Vector2 = w.player + offset - Vector2(0, 14)
		var mid: Vector2 = from.lerp(to, 0.5) + Vector2(0, -18) + (to - from).orthogonal().normalized() * wisp.bend
		for j in range(4):
			var t: float = clampf(k - j * 0.07, 0, 1)
			var q: Vector2 = from.lerp(mid, t).lerp(mid.lerp(to, t), t)
			g.draw_rect(Rect2(q.floor(), Vector2(2, 2) if j == 0 else Vector2.ONE), Color(1.0, 0.25, 0.25, 0.9 - j * 0.2))
	for r in fx.risers:
		var k: float = r.age / r.life
		var p: Vector2 = r.p + offset + Vector2(sin(r.sway + r.age * 5.0) * 3.0, -r.age * r.speed - 4)
		g.draw_rect(Rect2(p.floor(), Vector2(1, 2)), Color(r.color, sin(k * PI)))
	if fx.glow > 0:evolve_glow(g, w.player + offset, fx.glow, w.clock)

static func evolve_glow(g, p: Vector2, left: float, clock: float):
	var k: float = clampf(left / 2.2, 0, 1)
	var rise: float = smoothstep(0.0, 0.25, 1.0 - k)
	g.draw_rect(Rect2(p.x - 7 * k, p.y - 200, 14 * k, 200), Color(1, 0.93, 0.7, 0.16 * k * rise))
	g.draw_rect(Rect2(p.x - 1, p.y - 200, 2, 200), Color(1, 1, 0.9, 0.5 * k * rise))
	for j in range(10):
		var a: float = clock * 3.0 + j * TAU / 10
		var q: Vector2 = p + Vector2(cos(a) * 15, sin(a) * 6 - 14 - sin(clock * 2.0 + j) * 8)
		g.draw_rect(Rect2(q.floor(), Vector2(2, 2) if j % 2 else Vector2.ONE), Color(1, 0.9, 0.55, 0.9 * k))

static func lights(g):
	var fx = g.world.fx
	for f in fx.flashes:
		var k: float = 1.0 - f.age / f.life
		g.ambient_lights.append({"p": f.p, "r": f.r * (0.7 + 0.3 * k), "c": f.color, "power": f.power * k, "glow": 0.3 * k})
	if "arsenal" in g.world and g.world.arsenal.bat_left > 0:
		g.ambient_lights.append({"p": g.world.player - Vector2(0, 12), "r": 90.0, "c": Color(1, 0.3, 0.3), "power": 0.75, "glow": 0.12})
	if fx.glow > 0:
		g.ambient_lights.append({"p": g.world.player - Vector2(0, 14), "r": 150.0, "c": Color(1, 0.9, 0.6), "power": 0.8 * clampf(fx.glow, 0, 1), "glow": 0.18 * clampf(fx.glow, 0, 1)})

# ------------------------------------------------------------------ bats

static func bat(g, p: Vector2, direction: Vector2, phase: float, tint: Color = Color.WHITE):
	if not g.textures.has("ch4_fx_bat"):return
	var row: int = 2 if absf(direction.x) > absf(direction.y) * 1.2 else (0 if direction.y >= 0 else 1)
	var frame: int = int(fposmod(phase, 1.0) * 6) % 6
	var region := Rect2(frame * 28, row * 24, 28, 24)
	if row == 2 and direction.x < 0:
		g.draw_set_transform(p.floor(), 0, Vector2(-1, 1))
		g.draw_texture_rect_region(g.textures.ch4_fx_bat, Rect2(Vector2(-14, -16), Vector2(28, 24)), region, tint)
		g.draw_set_transform(Vector2.ZERO)
	else:g.draw_texture_rect_region(g.textures.ch4_fx_bat, Rect2(p.floor() - Vector2(14, 16), Vector2(28, 24)), region, tint)

## The hero is gone; a flock crosses the ground in its place.
static func flock(g, p: Vector2, direction: Vector2, clock: float, left: float, total: float):
	var k: float = clampf(1.0 - left / maxf(0.01, total), 0, 1)
	var spread: float = smoothstep(0.0, 0.18, k) * (1.0 - smoothstep(0.82, 1.0, k))
	g.oval(p + Vector2(0, 1), Vector2(16, 5) * (0.5 + spread * 0.5), Color(0, 0, 0, 0.35))
	for j in range(5):
		var back: Vector2 = p - direction * (10 + j * 9) - Vector2(0, 12)
		g.oval(back, Vector2(9 - j, 5 - j * 0.6), Color(0.1, 0.0, 0.02, 0.22 - j * 0.04))
	var order: Array = []
	for j in range(13):
		var a: float = clock * (7.0 + j % 3 * 1.6) + j * 2.39996
		var radius := Vector2(15 + j % 4 * 4, 7 + j % 3 * 3) * (0.25 + 0.75 * spread)
		var q: Vector2 = p + Vector2(cos(a), sin(a)) * radius - Vector2(0, 11 + sin(clock * 9.0 + j) * 4.0) + direction * (j % 5 - 2) * 3.0
		order.append({"q": q, "j": j, "v": (Vector2(-sin(a), cos(a)) * 0.6 + direction).normalized()})
	order.sort_custom(func(a, b):return a.q.y < b.q.y)
	for o in order:
		bat(g, o.q + Vector2(0, 1), o.v, clock * 4.2 + o.j * 0.37, Color(0.9, 0.1, 0.12, 0.55))
		bat(g, o.q, o.v, clock * 4.2 + o.j * 0.37, Color(2.4, 1.5, 1.5) if o.j % 4 == 0 else Color(1.9, 1.5, 1.5))
		if o.j % 3 == 0:
			g.draw_rect(Rect2((o.q - o.v * 9).floor(), Vector2(2, 1)), Color(0.7, 0.05, 0.08, 0.7))

# ------------------------------------------------------------------ dread

static func urgency(w) -> float:
	if not "ending" in w:return 0.0
	if w.stage != "survival":return 1.0 if w.stage == "finale" and w.ending.phase in ["", "summit"] else 0.0
	return clampf(1.0 - (float(w.db.data.duration) - float(w.time)) / 150.0, 0.0, 1.0)

static func fissure(w, cx: int, cy: int, u: float):
	# One deterministic fissure per 72 px cell, pointing at the place where it ends.
	if Atmosphere.hash01(cx, cy, 31) > u * 0.55 + 0.02:return null
	var a := Vector2(cx * 72 + 10 + Atmosphere.hash01(cx, cy, 32) * 52, cy * 72 + 10 + Atmosphere.hash01(cx, cy, 33) * 52)
	var toward: Vector2 = a.direction_to(w.ending.center)
	if toward == Vector2.ZERO:toward = Vector2.DOWN
	var length: float = (20.0 + Atmosphere.hash01(cx, cy, 34) * 34.0) * (0.45 + 0.55 * u)
	return [a - toward * length * 0.5, a + toward * length * 0.5, cx * 131 + cy * 17]

static func visible_fissures(g, offset: Vector2) -> Array:
	var w = g.world
	var u := urgency(w)
	if u <= 0.0 or not "ending" in w or w.ending.phase not in ["", "summit"]:return []
	var result: Array = []
	var origin := Vector2i((-offset / 72.0).floor())
	for cy in range(origin.y - 1, origin.y + 7):
		for cx in range(origin.x - 1, origin.x + 11):
			var f = fissure(w, cx, cy, u)
			if f != null:result.append(f)
	return result

static func dread_floor(g, offset: Vector2):
	for f in visible_fissures(g, offset):
		var points := crack_points(f[0] + offset, f[1] + offset, int(f[2]), 5.0)
		g.draw_polyline(points, Color(0.015, 0.0, 0.01, 0.95), 3)

## Light leaks from below through the fissures; drawn over the darkness.
static func dread_glow(g, offset: Vector2, ground := false):
	var w = g.world
	var u := urgency(w)
	if u <= 0.0:return
	var beat: float = 0.55 + 0.45 * pow(maxf(0.0, sin(w.clock * 2.4)), 4.0)
	var shake: float = clampf(w.fx.tremor, 0.0, 1.0)
	for f in visible_fissures(g, offset):
		var points := crack_points(f[0] + offset, f[1] + offset, int(f[2]), 5.0)
		if ground:
			g.draw_polyline(points, Color(1.0, 0.93, 0.9, (0.3 + 0.45 * u) * beat + 0.25 * shake), 1)
			continue
		var seed: int = int(f[2])
		for j in range(2):
			var t: float = fposmod(w.clock * (0.35 + hh(j, seed) * 0.3) + hh(j, seed + 1), 1.0)
			var q: Vector2 = points[int(hh(j, seed + 2) * (points.size() - 1))] - Vector2(0, t * (14 + 22 * u))
			g.draw_rect(Rect2(q.floor(), Vector2(1, 2)), Color(1, 0.96, 0.92, (1.0 - t) * (0.35 + 0.5 * u)))
	if ground:return
	if u > 0.0:Atmosphere.draw_edges(g, Color(0.42, 0.0, 0.03, 0.26 * u + 0.12 * shake))
	if shake > 0.0:
		for j in range(18):
			var x: float = fposmod(j * 53.7 + w.clock * 11.0, 660.0) - 10
			var y: float = fposmod(j * 91.3 + w.clock * (150.0 + j % 5 * 30), 380.0) - 10
			g.draw_rect(Rect2(Vector2(x, y).floor(), Vector2(1, 2 + j % 3)), Color(0.5, 0.42, 0.4, 0.5 * shake))

## He is already there when the title fades: a figure up the road, then gone.
static func arrival_watcher(g, offset: Vector2):
	var w = g.world
	if w.stage != "arrival":return
	var total: float = w.db.data.chapter_four.arrival_duration
	var t: float = w.stage_age
	var gone: float = total - 1.25
	if t < 1.4 or t > gone + 0.12:return
	var p: Vector2 = (w.player + Vector2(0, -118) + offset).floor()
	var alpha: float = smoothstep(1.4, 2.4, t)
	if t > gone:
		alpha = 1.0 if int(t * 60.0) % 2 == 0 else 0.25
		p.x += (hh(int(t * 60.0), 9) - 0.5) * 10.0
	g.draw_actor("steve", p, Vector2.DOWN, 0.0, false, Color(0.02, 0.02, 0.03, alpha), "idle", 1.0, {"state": "idle", "time": 0.0})
	g.draw_rect(Rect2(p + Vector2(-3, -20), Vector2(2, 1)), Color(1, 1, 1, alpha))
	g.draw_rect(Rect2(p + Vector2(1, -20), Vector2(2, 1)), Color(1, 1, 1, alpha))

## A body climbing out of the ground: the lower part is still under the soil.
static func emerging(g, m: Dictionary, offset: Vector2) -> float:
	var born: float = m.get("emerge", -99.0)
	var age: float = g.world.clock - born
	if age < 0.0 or age >= 1.2:return 0.0
	return (1.0 - smoothstep(0.0, 1.05, age)) * 26.0

static func soil_cover(g, m: Dictionary, offset: Vector2, depth: float):
	var p: Vector2 = (m.p + offset).floor()
	var cover := Rect2(p + Vector2(-16, 1), Vector2(32, depth + 4))
	g.draw_texture_rect_region(g.textures.ch4_ground, cover, Rect2(cover.position - offset, cover.size))
	g.oval(p + Vector2(0, 1), Vector2(13, 4), Color(0.05, 0.03, 0.03, 0.9))
	for j in range(7):
		var a: float = j * TAU / 7 + int(m.id)
		g.draw_rect(Rect2((p + Vector2(cos(a) * 12, sin(a) * 4)).floor() - Vector2(1, 1), Vector2(3, 2)), Color(0.2, 0.15, 0.14))
