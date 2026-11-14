extends RefCounted
## Chapter IV attack tells in one diegetic language: the ground itself reacts.
## Cracks grow toward the impact as the windup progresses (k = 0..1), claw
## grooves rake ahead of a lunge, rings of blood close in on a landing point.
## Every shape is the hit geometry; nothing here reads or writes combat state.
## Pixel-crisp: positions are floored, lines are 1–2 px, no soft translucent
## slabs. A last bright pulse in the final 15 % says "now".
const CORE := Color(0.05, 0.0, 0.01)
const HOT := Color(1.0, 0.36, 0.2)
const EMBER := Color(1.0, 0.75, 0.5)
static func h01(i: int, salt: int) -> float:
	var h := (i * 374761393 + salt * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65536.0

static func hot(k: float, clock: float) -> Color:
	# Brightens with the windup; the final pulse flickers so "now" is unmissable.
	var c := HOT.lerp(EMBER, smoothstep(0.6, 1.0, k))
	c.a = 0.45 + 0.45 * k
	if k > 0.85:
		c.a = 0.75 + 0.25 * sin(clock * 40.0)
	return c

## Jagged crack polyline from a toward b, revealed up to fraction k.
static func crack(g, a: Vector2, b: Vector2, k: float, seed: int, jag: float, width: float, clock: float):
	var length := a.distance_to(b)
	if length < 1:
		return
	var dir := (b - a) / length
	var side := dir.orthogonal()
	var steps := maxi(3, int(length / 7.0))
	var shown := int(ceil(steps * clampf(k, 0, 1)))
	var points := PackedVector2Array([a.floor()])
	for i in range(1, shown + 1):
		var t := float(i) / steps
		var off := (h01(i, seed) - 0.5) * 2.0 * jag * sin(t * PI)
		points.append((a + dir * length * t + side * off).floor())
	if points.size() < 2:
		return
	g.draw_polyline(points, CORE, width + 1.0)
	g.draw_polyline(points, hot(k, clock), 1.0)
	# Branching hairline cracks along the way.
	for i in range(1, points.size() - 1, 2):
		var branch := side * (1 if h01(i, seed + 7) > 0.5 else -1) * (3.0 + h01(i, seed + 9) * 5.0)
		g.draw_line(points[i], (points[i] + branch + dir * 2).floor(), Color(CORE, 0.8), 1)

## A lane that the attack will sweep: two edge cracks and a dark CORE.
static func lane(g, a: Vector2, b: Vector2, half_width: float, k: float, seed: int, clock: float):
	var side := (b - a).normalized().orthogonal() * half_width
	crack(g, a + side, b + side, k, seed, 2.5, 1.0, clock)
	crack(g, a - side, b - side, k, seed + 31, 2.5, 1.0, clock)
	crack(g, a, a.lerp(b, k), 1.0, seed + 57, 4.0, 2.0, clock)
	if k > 0.85:
		var end := b.floor()
		for j in range(4):
			var d := Vector2.from_angle(j * PI / 2 + PI / 4) * (4 + 2 * sin(clock * 30))
			g.draw_line(end - d, end + d, hot(k, clock), 1)

## Three claw grooves raked ahead of a short lunge.
static func claws(g, p: Vector2, dir: Vector2, reach: float, k: float, seed: int, clock: float):
	var side := dir.orthogonal()
	for j in range(3):
		var start := p + dir * 8 + side * (j - 1) * 5
		crack(g, start, start + dir * reach + side * (j - 1) * 3, k, seed + j * 13, 1.5, 1.0, clock)

## A ring that closes onto the landing point; its final radius is the hit radius.
static func ring(g, p: Vector2, radius: float, k: float, clock: float, color: Color = HOT):
	# A ring of hot points that tightens onto the real hit radius.
	var r := lerpf(radius * 1.6, radius, smoothstep(0.0, 1.0, k))
	var c := hot(k, clock) if color == HOT else Color(color, 0.45 + 0.5 * k)
	var dots := PackedVector2Array()
	var count := int(clampf(radius * 0.9, 14.0, 48.0))
	for j in range(count):
		var a := j * TAU / count + clock * 0.4
		var q := (p + Vector2(cos(a), sin(a) * 0.5) * r).floor()
		dots.append_array([q, q + Vector2(2 if j % 3 == 0 else 1, 0)])
	g.draw_multiline(dots, c, 1)
	if k > 0.85:
		var inner := PackedVector2Array()
		for j in range(count / 2):
			var a := j * TAU / (count / 2) - clock * 0.8
			var q := (p + Vector2(cos(a), sin(a) * 0.5) * radius * 0.55).floor()
			inner.append_array([q, q + Vector2.RIGHT])
		g.draw_multiline(inner, Color(c, c.a * 0.6), 1)

## Earth swelling before a wall erupts: broken outline plus lifting grit.
static func bulge(g, p: Vector2, k: float, seed: int, clock: float):
	for j in range(7):
		var a := j * TAU / 7 + h01(j, seed) * 0.6
		var q := (p + Vector2(cos(a) * 10, sin(a) * 5) * (0.6 + 0.4 * k)).floor()
		g.draw_line(q, (q + Vector2(cos(a), sin(a) * 0.5) * 3).floor(), hot(k, clock), 1)
	for j in range(5):
		var phase := fposmod(clock * 1.8 + j * 0.21, 1.0)
		var q := (p + Vector2((h01(j, seed + 3) - 0.5) * 16, -phase * 10 * k)).floor()
		g.draw_rect(Rect2(q, Vector2.ONE), Color(0.45, 0.36, 0.32, (1.0 - phase) * k))

## Aim of a ranged shot: a CORE of bone dust that grows and locks before firing.
static func aim(g, p: Vector2, dir: Vector2, length: float, k: float, clock: float):
	var reach := 0.25 + 0.75 * clampf(k, 0, 1)
	var a := p.floor()
	var b := (p + dir * length * reach).floor()
	var c := hot(k, clock)
	g.draw_line(a, b, Color(CORE, 0.55 + 0.3 * k), 3)
	g.draw_line(a, b, c, 1)
	var side := dir.orthogonal()
	for i in range(1, 7):
		var t := float(i) / 7.0
		if t > reach:
			break
		var q := (p + dir * length * t + side * (2.0 if i % 2 == 0 else -2.0)).floor()
		g.draw_rect(Rect2(q, Vector2.ONE), Color(c, c.a * 0.7))
	if k > 0.85:
		g.draw_line(b, (b - dir * 4 + side * 3).floor(), c, 1)
		g.draw_line(b, (b - dir * 4 - side * 3).floor(), c, 1)

## A thread of current between two cursed torches: flickering, sparking, thin.
static func thread(g, a: Vector2, b: Vector2, k: float, seed: int, clock: float):
	var last := a.floor()
	var side := (b - a).normalized().orthogonal()
	var steps := maxi(4, int(a.distance_to(b) / 10.0))
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var q := (a.lerp(b, t) + side * sin(t * 13.0 + clock * 22.0 + seed) * 2.0 * sin(t * PI)).floor()
		if h01(i + int(clock * 15.0), seed) > 0.18:
			g.draw_line(last, q, CORE, 3)
			g.draw_line(last, q, hot(k, clock), 1)
		last = q
	var spark := a.lerp(b, fposmod(clock * 1.7 + seed * 0.1, 1.0)).floor()
	g.draw_rect(Rect2(spark - Vector2.ONE, Vector2(3, 3)), Color(EMBER, 0.9))

## A creeper's fuse: a burning line runs around the blast radius, ember at its head.
static func fuse(g, p: Vector2, radius: float, k: float, seed: int, clock: float):
	var count := int(clampf(radius * 0.9, 16.0, 44.0))
	var lit := int(ceil(count * clampf(k, 0, 1)))
	var last := Vector2.ZERO
	for j in range(count):
		var a := -PI / 2 + j * TAU / count
		var q := (p + Vector2(cos(a), sin(a) * 0.5) * radius).floor()
		if j < lit:
			if j > 0:
				g.draw_line(last, q, CORE, 2)
				g.draw_line(last, q, hot(k, clock), 1)
		elif j % 2 == 0:
			g.draw_rect(Rect2(q, Vector2.ONE), Color(CORE, 0.7))
		last = q
	if lit > 0 and lit < count:
		var a := -PI / 2 + lit * TAU / count
		var head := (p + Vector2(cos(a), sin(a) * 0.5) * radius).floor()
		g.draw_rect(Rect2(head - Vector2.ONE, Vector2(3, 3)), EMBER)
		for s in range(2):
			var t := fposmod(clock * 3.0 + s * 0.5 + seed * 0.13, 1.0)
			var d := Vector2(h01(int(clock * 3.0) + s, seed) - 0.5, -1.0) * (2 + t * 6)
			g.draw_rect(Rect2((head + d).floor(), Vector2.ONE), Color(EMBER, 1.0 - t))
	if k > 0.85:
		ring(g, p, radius * 0.6, k, clock)

## An axe biting the ground: an arc of cracks at reach, split by radial cuts.
static func chop(g, p: Vector2, dir: Vector2, reach: float, spread: float, k: float, seed: int, clock: float):
	var base := dir.angle()
	var steps := maxi(5, int(reach * spread / 6.0))
	var half := int(ceil(steps * 0.5 * clampf(k * 1.3, 0, 1)))
	var centre := steps / 2
	var points := PackedVector2Array()
	for i in range(centre - half, centre + half + 1):
		var t := float(i) / steps - 0.5
		var r := reach + (h01(i, seed) - 0.5) * 3.0
		points.append((p + Vector2.from_angle(base + t * spread) * Vector2(1, 0.6) * r).floor())
	if points.size() >= 2:
		g.draw_polyline(points, CORE, 2)
		g.draw_polyline(points, hot(k, clock), 1)
	for j in range(3):
		var a := base + (j - 1) * spread * 0.35
		var from := p + Vector2.from_angle(a) * Vector2(1, 0.6) * 6.0
		crack(g, from, p + Vector2.from_angle(a) * Vector2(1, 0.6) * reach, k, seed + j * 11, 1.5, 1.0, clock)

## Hoofprints stamped along a charge, the herd's path before it runs.
static func hooves(g, a: Vector2, b: Vector2, k: float, seed: int, clock: float):
	var length := a.distance_to(b)
	if length < 1:
		return
	var dir := (b - a) / length
	var side := dir.orthogonal()
	var count := int(length / 14.0)
	for i in range(1, count + 1):
		var t := float(i) / count
		if t > k:
			break
		var q := a + dir * length * t + side * (4.0 if i % 2 == 0 else -4.0) + side * (h01(i, seed) - 0.5) * 3.0
		for d in [Vector2.ZERO, dir * 3.0]:
			var r: Vector2 = (q + d).floor()
			g.draw_rect(Rect2(r - Vector2.ONE, Vector2(3, 2)), CORE)
			g.draw_rect(Rect2(r - Vector2(1, 2), Vector2(3, 1)), hot(k, clock))

## Wind chevrons racing ahead of a swoop from the sky.
static func chevrons(g, a: Vector2, b: Vector2, k: float, clock: float):
	var length := a.distance_to(b)
	if length < 1:
		return
	var dir := (b - a) / length
	var side := dir.orthogonal()
	var count := maxi(3, int(length / 18.0))
	for i in range(count):
		var t := fposmod(float(i) / count + clock * 0.9, 1.0)
		if t > 0.2 + 0.8 * k:
			continue
		var q := a + dir * length * t
		var c := hot(k, clock)
		c.a *= 1.0 - t * 0.5
		g.draw_line((q - dir * 4 + side * 4).floor(), q.floor(), c, 1)
		g.draw_line((q - dir * 4 - side * 4).floor(), q.floor(), c, 1)

## Two tusk furrows ploughed ahead of a goring charge, dust kicked at the start.
static func tusks(g, p: Vector2, dir: Vector2, length: float, k: float, seed: int, clock: float):
	var side := dir.orthogonal()
	for j in [-1, 1]:
		var start: Vector2 = p + dir * 6 + side * j * 4
		crack(g, start, start + dir * length + side * j * 2, k, seed + j * 17, 1.2, 2.0, clock)
	for s in range(4):
		var t := fposmod(clock * 2.2 + s * 0.25, 1.0)
		var q := p - dir * (2 + t * 8) + side * (h01(s, seed) - 0.5) * 12 - Vector2(0, t * 5)
		g.draw_rect(Rect2(q.floor(), Vector2.ONE), Color(0.45, 0.36, 0.32, (1.0 - t) * k))
	if k > 0.85:
		var end := (p + dir * (length + 6)).floor()
		g.draw_line(end - side * 4, end + side * 4, hot(k, clock), 1)

## A potion's landing: the ring closes while shards of glass fall into it.
static func splash(g, p: Vector2, radius: float, k: float, seed: int, clock: float):
	ring(g, p, radius, k, clock)
	for j in range(6):
		var a := j * TAU / 6 + h01(j, seed) * 0.8
		var q := p + Vector2(cos(a), sin(a) * 0.5) * radius * 0.55 - Vector2(0, (1.0 - k) * 26.0 + h01(j, seed + 4) * 6.0)
		g.draw_rect(Rect2(q.floor(), Vector2(1, 2)), Color(hot(k, clock), 0.4 + 0.6 * k))

## A crossbow lock on the target: four ticks close in, then hold.
static func lock(g, p: Vector2, k: float, clock: float):
	var r := lerpf(12.0, 5.0, smoothstep(0.0, 1.0, k))
	var c := hot(k, clock)
	for j in range(4):
		var d := Vector2.from_angle(j * PI / 2)
		g.draw_line((p + d * r).floor(), (p + d * (r + 3)).floor(), c, 1)

## Embers drifting up from a body that is about to fire.
static func embers(g, p: Vector2, k: float, seed: int, clock: float):
	for s in range(6):
		var t := fposmod(clock * 1.4 + s / 6.0, 1.0)
		var q := p + Vector2((h01(s, seed) - 0.5) * 14, -t * 18 * (0.5 + k))
		g.draw_rect(Rect2(q.floor(), Vector2.ONE * (2 if s % 3 == 0 else 1)), Color(EMBER if s % 2 else HOT, (1.0 - t) * (0.4 + 0.6 * k)))

