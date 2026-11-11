extends RefCounted
## The iron sword at the spawn of every chapter: stuck in the grass (I),
## rising out of lava (II), falling from the sky (III), made of the purple
## motes Ender Steve left (IV), assembled out of the void (V).
const Atmosphere = preload("res://scripts/ui/atmosphere.gd")
const SCALE := 1.0

static func h(i: int, salt: int) -> float:
	return Atmosphere.hash01(i, salt, 23)

## The sword stuck point-down with its tip at `tip`. `out` is how much of it
## shows above the ground (1 = all): the rest is sunk below `tip`.
static func sword(g, tip: Vector2, tint: Color = Color.WHITE, lean: float = 0.0, out: float = 1.0):
	if not g.textures.has("icon_sword_iron"):g.load_texture("icon_sword_iron")
	var tex: Texture2D = g.textures.get("icon_sword_iron")
	if tex == null or out <= 0.0:return
	out = minf(out, 1.0)
	var sunk: Vector2 = Vector2(0, (1.0 - out) * 22.6 * SCALE)
	g.draw_set_transform((tip + sunk).floor(), PI * 0.75 + lean, Vector2.ONE * SCALE)
	var s: float = 16.0 * out
	g.draw_texture_rect_region(tex, Rect2(-16, 16 - s, s, s), Rect2(0, 16 - s, s, s), tint)
	g.draw_set_transform(Vector2.ZERO)

static func draw(g, offset: Vector2):
	var w = g.world
	if not "sword_drop" in w or w.sword_drop.is_empty() or not w.sword_drop.has("p"):return
	var d: Dictionary = w.sword_drop
	var p: Vector2 = d.p + offset
	if not Rect2(-60, -260, 760, 640).has_point(p):return
	var a: float = d.age
	var land: float = w.SWORD_LAND[d.style]
	if d.taken:
		var k: float = d.take_age
		for i in range(12):
			var q: Vector2 = p + Vector2.from_angle(i * TAU / 12.0) * k * 40 - Vector2(0, 14)
			g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(1, 1, .85, maxf(0, 1 - k * 2)))
		return
	match d.style:
		"ground":ground(g, p, a, land, w.clock)
		"lava":lava(g, p, a, land, w.clock)
		"sky":sky(g, p, a, land, w.clock)
		"ender":ender(g, p, a, land, w.clock)
		"void":void_(g, p, a, land, w.clock)
	if a >= land:
		var bob: float = round(sin(w.clock * 4.0) * 1.5)
		g.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -30 + bob), p + Vector2(3, -30 + bob), p + Vector2(0, -26 + bob)]), Color(1, 1, 1, .8))
		var label := "Подбери меч"
		var width: float = g.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		g.text_at(label, Vector2(p.x - width / 2, p.y - 34 + bob), 8, Color(1, 1, 1, minf(1, (a - land) * 2)))

static func glint(g, tip: Vector2, clock: float):
	var t: float = fposmod(clock * .6, 1.6)
	if t > 1.0:return
	var q: Vector2 = tip - Vector2(0, 4 + t * 18)
	g.draw_rect(Rect2((q - Vector2(1, 1)).floor(), Vector2(3, 3)), Color(1, 1, 1, .7 * sin(t * PI)))

static func ground(g, p: Vector2, a: float, land: float, clock: float):
	var k: float = smoothstep(0, land, a)
	g.oval(p + Vector2(0, 1), Vector2(6, 2), Color(0, 0, 0, .3))
	# Pushed up out of the grass, as if it had always been there.
	sword(g, p, Color.WHITE, 0.08, k)
	for i in range(8):
		var t: float = fposmod(h(i, 1) + a * 1.5, 1.0)
		if a > land + .4:break
		g.draw_rect(Rect2((p + Vector2(-6 + h(i, 2) * 12, -t * 8)).floor(), Vector2(1, 1)), Color(.35, .25, .15, 1 - t))
	if a >= land:glint(g, p, clock)

static func lava(g, p: Vector2, a: float, land: float, clock: float):
	# The pool flares, the sword rises red-hot, and both cool down.
	var cool: float = smoothstep(land - .2, land + 1.6, a)
	var size: float = smoothstep(0, .5, a) * (1 - cool * .45)
	var hot := Color(1, .55, .12).lerp(Color(.22, .12, .1), cool)
	g.oval(p + Vector2(0, 1), Vector2(16, 6) * size, Color(.35, .08, .02, .9))
	g.oval(p + Vector2(0, 1), Vector2(13, 4.5) * size, hot)
	for i in range(6):
		var t: float = fposmod(h(i, 3) + clock * .9, 1.0)
		var q: Vector2 = p + Vector2(-10 + h(i, 4) * 20, 1 - t * 4)
		g.draw_rect(Rect2(q.floor(), Vector2(2, 1)), Color(1, .8, .3, (1 - t) * (1 - cool)))
	var rise: float = smoothstep(.5, land, a)
	var tint := Color(2.2, .9, .4).lerp(Color.WHITE, smoothstep(land, land + 1.4, a))
	sword(g, p, tint, 0.0, rise)
	for i in range(10):
		var t: float = fposmod(h(i, 5) + a * .7, 1.0)
		var steam: float = smoothstep(land - .3, land + .2, a) * (1 - smoothstep(land + 1.2, land + 2.2, a))
		var q: Vector2 = p + Vector2(-5 + h(i, 6) * 10 + sin(t * 6 + i) * 2, -8 - t * 26)
		g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(.85, .85, .85, .5 * (1 - t) * steam))

static func sky(g, p: Vector2, a: float, land: float, clock: float):
	var k: float = clampf(a / land, 0, 1)
	var y: float = lerpf(-230, 0, k * k)
	g.oval(p + Vector2(0, 1), Vector2(7, 2) * (0.3 + k * .7), Color(0, 0, 0, .15 + .2 * k))
	if a < land:
		for i in range(6):g.draw_rect(Rect2(p + Vector2(-1, y - 30 - i * 8), Vector2(2, 6)), Color(1, 1, 1, .35 - i * .05))
		sword(g, p + Vector2(0, y), Color.WHITE, 0.0)
		return
	var t: float = a - land
	var wobble: float = sin(t * 30) * .12 * maxf(0, 1 - t * 2.5)
	sword(g, p + Vector2(0, 3), Color.WHITE, wobble)
	if t < .6:
		g.draw_arc(p, 6 + t * 40, 0, TAU, 24, Color(.85, .8, .7, .6 * (1 - t / .6)), 1)
		for i in range(10):
			var q: Vector2 = p + Vector2.from_angle(PI + i * PI / 9) * t * 30
			g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(.75, .72, .6, 1 - t / .6))
	glint(g, p + Vector2(0, 3), clock)

static func ender(g, p: Vector2, a: float, land: float, clock: float):
	var k: float = smoothstep(.2, land, a)
	for i in range(28):
		var t: float = clampf(k * 1.3 - h(i, 7) * .3, 0, 1)
		var from: Vector2 = p + Vector2.from_angle(h(i, 8) * TAU) * (40 + h(i, 9) * 30) - Vector2(0, 14)
		var to: Vector2 = p - Vector2(0, h(i, 10) * 22)
		var q: Vector2 = from.lerp(to, t * t)
		g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(.75, .42, 1, (1 - t) * .9 + .1 * sin(clock * 8 + i)))
	g.oval(p + Vector2(0, 1), Vector2(6, 2), Color(0, 0, 0, .3 * k))
	sword(g, p, Color(1.4, 1.0, 1.6, smoothstep(.5, land, a)).lerp(Color.WHITE, smoothstep(land, land + 1.0, a)))
	if a >= land:glint(g, p, clock)

static func void_(g, p: Vector2, a: float, land: float, clock: float):
	# A tear in the floor; white fragments pull together into the sword.
	var open: float = smoothstep(0, .5, a) * (1 - smoothstep(land, land + .6, a))
	if open > 0:
		g.draw_rect(Rect2(p + Vector2(-13, -30) * open, Vector2(26, 34) * open), Color(0, 0, 0, .95))
		for i in range(6):
			var y: float = fposmod(h(i, 11) * 34 + clock * 40, 34) - 30
			g.draw_rect(Rect2((p + Vector2(-13 + h(i, 12) * 22, y) * open).floor(), Vector2(3 + i % 3 * 2, 1)), Color(.9, .95, 1, .7))
	var k: float = smoothstep(.4, land, a)
	for i in range(24):
		var t: float = clampf(k * 1.25 - h(i, 13) * .25, 0, 1)
		var from: Vector2 = p + Vector2(-60 + h(i, 14) * 120, -80 + h(i, 15) * 90)
		var q: Vector2 = from.lerp(p - Vector2(0, h(i, 16) * 22), t)
		if t < 1:g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(1, 1, 1, .9))
	if a >= land - .25:
		var jitter: Vector2 = Vector2(round(sin(clock * 50)), 0) if a < land + .4 else Vector2.ZERO
		g.oval(p + Vector2(0, 1), Vector2(6, 2), Color(0, 0, 0, .3))
		sword(g, p + jitter, Color.WHITE if int(clock * 20) % 7 else Color(.6, 1, 1))
	if a >= land:glint(g, p, clock)
