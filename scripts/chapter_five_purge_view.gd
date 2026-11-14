extends RefCounted
## Presentation of the chapter V purge (see chapter_five_purge.gd): the purge
## terminal, Steve being deleted or turning to dust, the core, the shockwave,
## the overload aura, the white-out, the stopped world and the crack.
const Atmosphere = preload("res://scripts/ui/atmosphere.gd")
const RED := Color(1, .22, .25)
const GREEN := Color(.35, 1, .55)
const CORE := Color(.55, 1, .85)

static func h(i: int, salt: int) -> float:return Atmosphere.hash01(i, salt, 77)

## The big purge terminal: a server tower with a red screen counting down.
static func terminal(g, m: Dictionary, p: Vector2):
	var w = g.world;var u = w.purge
	var k: float = u.progress()
	var j: Vector2 = Vector2(round((h(int(w.clock * 30), 1) - .5) * 4 * k), 0)
	p += j
	g.oval(p, Vector2(46, 9), Color(0, 0, 0, .35))
	# cables into the floor
	for i in range(6):
		var a: Vector2 = p + Vector2(-50 + i * 20, 0)
		var b: Vector2 = a + Vector2((h(i, 2) - .5) * 80, 22 + h(i, 3) * 26)
		g.draw_line(a, b, Color(.05, .05, .07), 3)
		var t: float = fposmod(w.clock * (1.2 + h(i, 4)), 1.0)
		g.draw_rect(Rect2(a.lerp(b, t) - Vector2(1, 1), Vector2(3, 3)), Color(RED, .8))
	# housing
	var body := Rect2(p + Vector2(-58, -128), Vector2(116, 128))
	g.draw_rect(body, Color(.11, .11, .13) if m.flash <= 0 else Color(1, 1, 1))
	g.draw_rect(Rect2(body.position + Vector2(116, 6), Vector2(10, 122)), Color(.06, .06, .08))
	g.draw_colored_polygon(PackedVector2Array([body.position, body.position + Vector2(10, -8), body.position + Vector2(126, -8), body.position + Vector2(116, 0)]), Color(.2, .2, .23))
	for i in range(8):
		var on: bool = fposmod(w.clock * 3 + i * .37, 1.0) < .5
		g.draw_rect(Rect2(body.position + Vector2(8 + i * 13, 104), Vector2(6, 3)), Color(RED, .9) if on else Color(.2, .05, .05))
	for y in range(3):g.draw_rect(Rect2(body.position + Vector2(8, 112 + y * 4), Vector2(100, 1)), Color(0, 0, 0, .6))
	# screen
	var scr := Rect2(body.position + Vector2(8, 8), Vector2(100, 88))
	g.draw_rect(scr, Color(.06, 0, .01))
	var lines := ["> sudo rm -rf", "  ./players/Steve.dat", "", "deleting..."]
	for i in range(lines.size()):g.draw_string(g.font, scr.position + Vector2(4, 11 + i * 9), lines[i], HORIZONTAL_ALIGNMENT_LEFT, scr.size.x - 6, 8, Color(1, .4, .4, .9))
	var left: float = maxf(0, u.left)
	var t_text: String = timer_text(left)
	var tw: float = g.font.get_string_size(t_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	g.draw_string(g.font, scr.position + Vector2((scr.size.x - tw) / 2, 64), t_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, RED if int(w.clock * 4) % 2 == 0 or left > 10 else Color.WHITE)
	g.draw_rect(Rect2(scr.position + Vector2(6, 74), Vector2(scr.size.x - 12, 6)), Color(.25, 0, .02))
	g.draw_rect(Rect2(scr.position + Vector2(6, 74), Vector2((scr.size.x - 12) * k, 6)), RED)
	for y in range(int(scr.position.y), int(scr.end.y), 2):g.draw_line(Vector2(scr.position.x, y), Vector2(scr.end.x, y), Color(0, 0, 0, .3))
	g.draw_rect(scr.grow(2), Color(RED, .35 + .3 * sin(w.clock * 6)), false, 1)
	# hp
	g.draw_rect(Rect2(body.position + Vector2(0, -16), Vector2(116, 4)), Color(0, 0, 0, .6))
	g.draw_rect(Rect2(body.position + Vector2(0, -16), Vector2(116 * clampf(m.hp / m.max_hp, 0, 1), 4)), GREEN)

## Steve while being deleted / turning to dust / holding the core / glowing.
static func player(g, p: Vector2) -> bool:
	var w = g.world;var u = w.purge
	match u.phase:
		"countdown":
			var k: float = u.progress()
			var t = w.mob_by_id(u.id)
			if t != null:
				var from: Vector2 = t.p + (p - w.player) + Vector2(0, -60)
				var flick: float = .25 + .25 * sin(w.clock * 20)
				g.draw_line(from, p + Vector2(0, -16), Color(RED, flick * (.3 + k)), 1)
				for i in range(4):
					var q: Vector2 = from.lerp(p + Vector2(0, -16), fposmod(w.clock * 1.5 + i * .25, 1.0))
					g.draw_rect(Rect2(q - Vector2(1, 1), Vector2(2, 2)), Color(RED, .8))
			g.draw_actor("steve", p, w.facing, w.clock, w.player_moving, g.invulnerable_tint(), "walk", 1.0, w.player_visual)
			g.draw_held_weapons(p)
			# the file is being eaten: pixels go missing, more each second
			var n: int = int(k * 26)
			for i in range(n):
				var seed: int = i * 7 + int(w.clock * (2 + k * 8))
				var q: Vector2 = p + Vector2(-7 + h(seed, 5) * 14, -30 + h(seed, 6) * 30)
				g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(.97, 0, .86) if i % 3 == 0 else Color(0, 0, 0))
			return true
		"snap":
			# Thanos: he crumbles from the top down into dust that blows away.
			var k: float = clampf(u.age / (u.SNAP * .75), 0, 1)
			if k < 1:g.draw_actor("steve", p, w.facing, w.clock, false, Color(1, 1, 1, 1 - k * k), "walk", 1.0, w.player_visual)
			for i in range(170):
				var born: float = (1.0 - h(i, 7)) * u.SNAP * .6
				var a: float = u.age - born
				if a < 0:continue
				var start: Vector2 = p + Vector2(-7 + h(i, 8) * 14, -32 + h(i, 9) * 32)
				var drift: Vector2 = Vector2(30 + h(i, 10) * 50, -14 - h(i, 11) * 26) * a + Vector2(sin(a * 3 + i) * 4, 0)
				var al: float = clampf(1.0 - a / 2.2, 0, 1)
				var c: Color = [Color(.36, .25, .2), Color(.0, .55, .62), Color(.16, .17, .55), Color(.62, .42, .30)][i % 4]
				g.draw_rect(Rect2((start + drift).floor(), Vector2(2, 2)), Color(c, al))
			return true
		"core":
			if u.age < 3.9:
				var look: Vector2 = (u.core_at(w) - w.player).normalized()
				g.draw_actor("steve", p, look if look != Vector2.ZERO else w.facing, w.clock, false, Color.WHITE, "walk", 1.0, w.player_visual)
			else:
				var k: float = smoothstep(3.9, u.CORE, u.age)
				var lift: float = 6.0 * k
				g.oval(p, Vector2(9 - 3 * k, 3), Color(0, 0, 0, .3))
				g.draw_actor("steve", p - Vector2(0, lift), Vector2.DOWN, w.clock, false, Color(1, 1, 1).lerp(Color(1.6, 1.9, 1.8), k), "walk", 1.0, w.player_visual)
			return true
		"surge", "ascend", "stop", "enter":
			var k: float = clampf(u.age / u.SURGE, 0, 1) if u.phase == "surge" else 1.0
			var glow: Color = CORE.lerp(Color.WHITE, k)
			var r: float = 14 + 6 * sin(w.clock * 5) + k * 6
			for i in range(3):g.draw_arc(p + Vector2(0, -14), r + i * 5, 0, TAU, 28, Color(glow, (.28 - i * .08) * (.5 + k)), 2)
			for i in range(int(6 + k * 10)):
				var t: float = fposmod(w.clock * (.7 + h(i, 12)) + h(i, 13), 1.0)
				var q: Vector2 = p + Vector2(-10 + h(i, 14) * 20, -t * 40)
				g.draw_rect(Rect2(q.floor(), Vector2(2, 3)), Color(glow, 1 - t))
			var tint: Color = Color(1, 1, 1).lerp(Color(1.5, 1.8, 1.7), .3 + .5 * k)
			g.draw_actor("steve", p, w.facing, w.clock, w.player_moving, tint, "walk", 1.0, w.player_visual)
			if u.phase in ["surge", "ascend"]:g.draw_held_weapons(p)
			return true
	return false

## World-space effects drawn over the actors.
static func air(g, offset: Vector2):
	var w = g.world;var u = w.purge
	if u.phase == "core":core_scene(g, offset)
	if u.wave >= 0:
		var c: Vector2 = u.wave_from + offset
		var r: float = u.wave
		g.draw_arc(c, maxf(1, r * .8), 0, TAU, 128, Color(1, 1, 1, .1), 26)
		for i in range(4):g.draw_arc(c, maxf(1, r - i * 9), 0, TAU, 128, Color(CORE.lerp(Color.WHITE, i * .25), .8 - i * .17), 5 - i)
		glyph_ring(g, c, r - 16, w.clock * .3, 64, Color(CORE, .75 * (1 - r / 1400.0)))
	if u.phase == "surge":surge_air(g, offset)
	if u.phase == "ascend":
		var r: float = u.aura(w)
		var c: Vector2 = w.player + offset + Vector2(0, -12)
		g.draw_circle(c, r, Color(1, 1, 1, .07))
		for i in range(3):g.draw_arc(c, r - i * 6, w.clock * (1 + i), w.clock * (1 + i) + TAU * .8, 48, Color(CORE.lerp(Color.WHITE, .6), .6 - i * .15), 2)
		glyph_ring(g, c, r + 8, -w.clock * .8, 40, Color(CORE, .6))
	if u.phase in ["stop", "enter"]:
		var e: float = clampf(u.age / u.ENTER, 0, 1) if u.phase == "enter" else 0.0
		var k: float = smoothstep(u.WHITE, u.WHITE + u.CRACK_OPEN, u.age) if u.phase == "stop" else 1.0
		rift(g, u.crack + offset, k, w.clock, e, w.player + offset)

const GLYPHS := ["0","1","{","}",";","()","=>","&&","new","int","null","0x","[]","//","++","!=","<>","::","true","void"]

static func glyph_ring(g, c: Vector2, r: float, turn: float, n: int, col: Color, squash: float = 1.0):
	if r <= 4 or col.a <= .01:return
	for i in range(n):
		var a: float = turn + i * TAU / n
		var q: Vector2 = c + Vector2(cos(a) * r, sin(a) * r * squash)
		g.draw_string(g.font, q.floor(), GLYPHS[(i * 7) % GLYPHS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)

static func lightning(g, a: Vector2, b: Vector2, seed: int, col: Color, width: float = 2.0, jag: float = 8.0):
	var pts := PackedVector2Array([a])
	var n: int = maxi(3, int(a.distance_to(b) / 12))
	var side: Vector2 = (b - a).orthogonal().normalized()
	for i in range(1, n):
		var t: float = float(i) / n
		pts.append(a.lerp(b, t) + side * (h(seed + i, 60) - .5) * 2 * jag * sin(t * PI))
	pts.append(b)
	g.draw_polyline(pts, Color(col, col.a * .35), width + 4)
	g.draw_polyline(pts, col, width)
	g.draw_polyline(pts, Color(1, 1, 1, col.a), 1)

static var _tex := {}
static func block(name: String) -> Texture2D:
	if not _tex.has(name):
		var path: String = "res://assets/minecraft/textures/block/%s.png" % name
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]

## The game's core as Minecraft would make it: a spinning command block.
static func core_block(g, c: Vector2, size: float, spin: float, glow: float):
	g.draw_circle(c, size * 2.4, Color(CORE, .08 * glow))
	g.draw_circle(c, size * 1.5, Color(CORE, .16 * glow))
	var t: Texture2D = block("repeating_command_block_front")
	for layer in range(2):
		var s: float = size * (1.0 if layer == 0 else .62)
		g.draw_set_transform(c, spin * (1 if layer == 0 else -1.6) + layer * PI / 4, Vector2.ONE)
		if t != null:g.draw_texture_rect_region(t, Rect2(-s / 2, -s / 2, s, s), Rect2(0, 0, 16, 16), Color(1, 1, 1) if layer == 0 else Color(.7, 1, .9, .85))
		else:g.draw_rect(Rect2(-s / 2, -s / 2, s, s), CORE)
		g.draw_rect(Rect2(-s / 2, -s / 2, s, s), Color(.8, 1, .95, .9), false, 1)
	g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	g.draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)

## Terminal shatters, the core rises with rays and orbiting code, everything
## in the level streams into it, it flies to Steve and he takes it in.
static func core_scene(g, offset: Vector2):
	var w = g.world;var u = w.purge;var a: float = u.age
	var from: Vector2 = u.core_from + offset
	var c: Vector2 = u.core_at(w) + offset
	var me: Vector2 = w.player + offset
	# shatter: flash, housing pieces and loose code
	if a < 1.6:
		var k: float = a / 1.6
		if a < .5:g.draw_circle(from + Vector2(0, -60), 30 + 120 * a, Color(1, .45, .45, .55 * (1 - a / .5)))
		for i in range(36):
			var d: Vector2 = Vector2.from_angle(h(i, 20) * TAU) * (120 + h(i, 21) * 220)
			var q: Vector2 = from + Vector2(0, -60) + d * (1 - pow(1 - k, 3)) * .9 + Vector2(0, 160 * k * k)
			var al: float = 1 - k
			if i % 3 == 0:g.draw_string(g.font, q.floor(), GLYPHS[i % GLYPHS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, .5, .5, al))
			else:
				var sz: float = 3 + h(i, 22) * 6
				g.draw_set_transform(q, a * (4 + h(i, 23) * 8), Vector2.ONE)
				g.draw_rect(Rect2(-sz / 2, -sz / 2, sz, sz), Color(.12, .12, .14, al))
				g.draw_rect(Rect2(-sz / 2, -sz / 2, sz, 1), Color(RED, al * .8))
				g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# light pillar while it rises and waits
	var lift: float = smoothstep(.5, 1.4, a) * (1 - smoothstep(2.8, 3.2, a))
	if lift > 0:
		var top: Vector2 = Vector2(c.x, -40)
		var wd: float = 10 + 6 * sin(w.clock * 9)
		g.draw_colored_polygon(PackedVector2Array([c + Vector2(-wd * 2, 0), c + Vector2(wd * 2, 0), top + Vector2(wd * 4, 0), top + Vector2(-wd * 4, 0)]), Color(CORE, .1 * lift))
		g.draw_colored_polygon(PackedVector2Array([c + Vector2(-wd * .6, 0), c + Vector2(wd * .6, 0), top + Vector2(wd, 0), top + Vector2(-wd, 0)]), Color(1, 1, 1, .25 * lift))
	# god rays and orbiting code around the core
	var shine: float = smoothstep(.6, 1.6, a) * (1 - smoothstep(3.8, 4.1, a))
	if shine > 0:
		for i in range(14):
			var ang: float = w.clock * .4 + i * TAU / 14
			var ln: float = (110 + 90 * h(i, 24)) * shine
			var wd: float = .05 + .03 * h(i, 25)
			g.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(ang - wd) * ln, c + Vector2.from_angle(ang + wd) * ln]), Color(CORE.lerp(Color.WHITE, .5), .12 * shine))
		glyph_ring(g, c, 34, w.clock * 1.6, 18, Color(CORE, .85 * shine), .45)
		glyph_ring(g, c, 52, -w.clock * 1.1, 26, Color(1, 1, 1, .5 * shine), .3)
	# 1.9-3.0: the whole level pours into it
	if a > 1.7 and a < 3.3:
		var st: float = smoothstep(1.7, 2.1, a) * (1 - smoothstep(3.0, 3.3, a))
		for i in range(60):
			var t: float = fposmod(w.clock * (.9 + h(i, 26) * .8) + h(i, 27), 1.0)
			var edge: Vector2 = c + Vector2.from_angle(h(i, 28) * TAU) * (260 + 120 * h(i, 29))
			var curl: Vector2 = (edge - c).orthogonal() * .25 * sin(t * PI)
			var q: Vector2 = edge.lerp(c, t * t) + curl * (1 - t)
			if i % 2 == 0:g.draw_string(g.font, q.floor(), GLYPHS[i % GLYPHS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(CORE.lerp(Color.WHITE, t), st * t))
			else:g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(1, 1, 1, st * t))
	# flight trail
	if a >= 3.0 and a < 3.95:
		for i in range(8):
			var back: float = a - i * .035
			var saved: float = u.age;u.age = back
			var q: Vector2 = u.core_at(w) + offset
			u.age = saved
			g.draw_circle(q, 10 - i, Color(CORE, .3 * (1 - i / 8.0)))
	# absorbed: veins of light, collapsing rings, the ground cracks under him
	if a >= 3.9:
		var k: float = smoothstep(3.9, u.CORE, a)
		for i in range(10):
			var ang: float = i * TAU / 10 + h(i, 30)
			var tip: Vector2 = me + Vector2(cos(ang) * (40 + 120 * k), sin(ang) * (18 + 50 * k))
			lightning(g, me, tip, i * 13 + int(w.clock * 12), Color(CORE, .7 * k), 1, 5)
		for i in range(3):
			var r: float = (1 - fposmod(w.clock * 1.5 + i / 3.0, 1.0)) * 90
			g.draw_arc(me + Vector2(0, -16), r, 0, TAU, 48, Color(CORE.lerp(Color.WHITE, .5), .5 * k), 2)
		g.draw_circle(me + Vector2(0, -16), 18 + 30 * k, Color(1, 1, 1, .12 + .25 * k))
	if a < 3.95:core_block(g, c, 16 + 2 * sin(w.clock * 10), w.clock * 2.4, 1.0)

## Overload: a rune circle on the floor, the pulse ring and the lightning.
static func surge_air(g, offset: Vector2):
	var w = g.world;var u = w.purge
	var k: float = clampf(u.age / u.SURGE, 0, 1)
	var me: Vector2 = w.player + offset
	var r: float = u.aura(w) + 20
	# rune circle on the floor (flattened)
	g.draw_arc(me, r, 0, TAU, 64, Color(CORE, .5), 1)
	for i in range(2):
		g.draw_set_transform(me, 0, Vector2(1, .45))
		g.draw_arc(Vector2.ZERO, r * (1.6 + i * .5), w.clock * (.6 - i * 1.2), w.clock * (.6 - i * 1.2) + TAU * .85, 64, Color(CORE.lerp(Color.WHITE, .4), .35 + .2 * k), 2)
		g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	glyph_ring(g, me, r * 2.0, -w.clock * .5, 24, Color(CORE, .45 + .3 * k), .45)
	# the pulse
	if u.pulse >= 0:
		var reach: float = u.pulse_reach(k)
		var pr: float = minf(u.pulse, reach)
		var fade: float = 1 - pr / reach
		g.draw_arc(me + Vector2(0, -8), pr, 0, TAU, 96, Color(1, 1, 1, .7 * fade), 3)
		g.draw_arc(me + Vector2(0, -8), maxf(1, pr - 6), 0, TAU, 96, Color(CORE, .5 * fade), 6)
		glyph_ring(g, me + Vector2(0, -8), pr - 12, w.clock, 36, Color(CORE, .8 * fade))
	for a in u.arcs:
		lightning(g, a.from + offset, a.to + offset, a.seed, Color(CORE.lerp(Color.WHITE, .3), a.t / .22), 2, 10)
		g.draw_circle(a.to + offset, 8 * a.t / .22, Color(1, 1, 1, .5 * a.t / .22))

const RIFT_TEXT := ["NullPointerException","0xDEADBEEF","Steve.dat","world.save()","}","return;","notch.jar","while(true)","ERR_TIME_STOPPED","goto end;"]
const RIFT_BLOCKS := ["stone","grass_block_side","dirt","cobblestone","obsidian","command_block_side","oak_planks","bedrock","end_stone","diamond_block"]

## Half-width of the tear at height t in [0, 1] (0 = top).
static func rift_width(t: float, k: float, i: int) -> float:
	return sin(t * PI) * (30 + 8 * h(i, 31)) * k * (.75 + .25 * sin(t * 9 + 1.3))

## A tear in the stopped world, in the language of the game: block-stepped
## edges, light pouring out, an End-like depth full of falling code, blocks of
## the world sucked into it and the floor fractured around it.
static func rift(g, c: Vector2, k: float, clock: float, e: float, me: Vector2):
	if k <= 0:return
	var grow: float = 1.0 + e * e * 7.0
	var height: float = 250 * minf(1.0, k * 1.6) * grow
	var wk: float = maxf(0, (k - .2) / .8) * grow
	var top: float = c.y - height * .62
	# opening: a white line splitting the air with branches
	if k < .45:
		var o: float = k / .45
		var a := Vector2(c.x, c.y - 155 * o);var b := Vector2(c.x, c.y + 95 * o)
		lightning(g, a, b, int(clock * 20), Color(1, 1, 1, .95), 2, 6)
		for i in range(5):
			var q: Vector2 = a.lerp(b, h(i, 40))
			lightning(g, q, q + Vector2((h(i, 41) - .5) * 120, (h(i, 42) - .5) * 40) * o, i * 7 + int(clock * 15), Color(CORE, .7), 1, 5)
	# fractures in the floor
	for i in range(12):
		var ang: float = i * TAU / 12 + h(i, 43) * .4
		var ln: float = (70 + 110 * h(i, 44)) * smoothstep(.2, .9, k) * grow
		var pts := PackedVector2Array([c + Vector2(0, 80 * minf(1, k * 1.6) * grow * .4)])
		for j in range(1, 6):
			var t: float = j / 5.0
			pts.append(pts[0] + Vector2(cos(ang) * ln * t + (h(i * 9 + j, 45) - .5) * 10, sin(ang) * ln * t * .42 + (h(i * 9 + j, 46) - .5) * 5))
		g.draw_polyline(pts, Color(CORE, .25), 4);g.draw_polyline(pts, Color(.9, 1, 1, .8), 1)
	if wk <= 0:return
	var n := 22
	var left := PackedVector2Array();var right := PackedVector2Array()
	var grid: float = 3.0
	for i in range(n + 1):
		var t: float = float(i) / n
		var y: float = top + t * height
		var wd: float = rift_width(t, wk, i)
		var x: float = c.x + (h(i, 32) - .5) * 10 * wk
		left.append(Vector2(snappedf(x - wd, grid), snappedf(y, grid)));right.append(Vector2(snappedf(x + wd, grid), snappedf(y, grid)))
	# light shafts up out of it
	for i in range(6):
		var sx: float = c.x + (h(i, 47) - .5) * 50 * wk
		var sw: float = (8 + 14 * h(i, 48)) * wk
		var al: float = .05 + .04 * sin(clock * (1 + h(i, 49)) + i)
		g.draw_colored_polygon(PackedVector2Array([Vector2(sx - sw, top + 30), Vector2(sx + sw, top + 30), Vector2(sx + sw * 3 + 40, -60), Vector2(sx - sw * 3 + 40, -60)]), Color(CORE.lerp(Color.WHITE, .6), al))
	# outer glow: the same tear grown twice
	for layer in [[2.2, .07], [1.5, .14]]:
		var poly := PackedVector2Array()
		for i in range(n + 1):poly.append(left[i] + (left[i] - Vector2(c.x, left[i].y)) * (layer[0] - 1))
		for i in range(n, -1, -1):poly.append(right[i] + (right[i] - Vector2(c.x, right[i].y)) * (layer[0] - 1))
		g.draw_colored_polygon(poly, Color(CORE.lerp(Color.WHITE, .3), layer[1]))
	var body := PackedVector2Array(left)
	for i in range(n, -1, -1):body.append(right[i])
	g.draw_colored_polygon(body, Color(.015, .01, .05))
	# the depth: End-portal specks drifting at three speeds
	var palette := [Color(.29, .82, .69), Color(.42, .23, .62), Color(.18, .45, .73), Color(.56, .9, .35), Color(.9, .95, 1)]
	for i in range(140):
		var layer: int = i % 3
		var t: float = fposmod(h(i, 50) + clock * (.02 + layer * .025), 1.0)
		var row: int = clampi(int(t * n), 0, n - 1)
		var wd: float = rift_width(t, wk, row) * .9
		var x: float = c.x + (h(i, 51) * 2 - 1) * wd
		var y: float = top + t * height
		var col: Color = palette[i % palette.size()]
		g.draw_rect(Rect2(Vector2(x, y).floor(), Vector2(1 + layer, 1 + layer)), Color(col, .5 + .3 * layer))
	# code raining down inside
	for col_i in range(9):
		var cx: float = (col_i - 4) / 4.0
		for j in range(7):
			var t: float = fposmod(h(col_i, 52) + j / 7.0 + clock * (.12 + .05 * h(col_i, 53)), 1.0)
			var row: int = clampi(int(t * n), 0, n - 1)
			var wd: float = rift_width(t, wk, row) - 5
			if wd < 4:continue
			var q := Vector2(c.x + cx * wd, top + t * height)
			var ch: String = ["0","1","{","}",";","λ","#","=","+"][(col_i * 3 + j + int(clock * 6)) % 9]
			var bright: bool = j == int(fposmod(clock * 4 + col_i, 7.0))
			g.draw_string(g.font, q.floor() - Vector2(2, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.85, 1, .95, .9) if bright else Color(.3, .95, .6, .55 * sin(t * PI)))
	# edges: chromatic split, then the bright rim
	var flick: float = .85 + .15 * sin(clock * 23)
	for side in [left, right]:
		g.draw_polyline(side, Color(1, .2, .35, .5), 2, false)
	g.draw_set_transform(Vector2(2, 0), 0, Vector2.ONE)
	for side in [left, right]:g.draw_polyline(side, Color(.2, .5, 1, .5), 2, false)
	g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for side in [left, right]:
		g.draw_polyline(side, Color(CORE, .55 * flick), 5)
		g.draw_polyline(side, Color(.9, 1, 1, flick), 2)
	# blocks of the world spiralling in, spinning, shrinking into the dark
	for i in range(16):
		var t: float = fposmod(clock * (.10 + .06 * h(i, 54)) + h(i, 55), 1.0)
		var r0: float = (90 + 120 * h(i, 56)) * grow
		var ang: float = h(i, 57) * TAU + t * 4.0
		var q: Vector2 = c + Vector2(cos(ang), sin(ang) * .55) * r0 * (1 - t * t)
		var sz: float = (10 + 6 * h(i, 58)) * (1 - t * .8)
		var tex: Texture2D = block(RIFT_BLOCKS[i % RIFT_BLOCKS.size()])
		g.draw_set_transform(q, t * 9 + i, Vector2.ONE)
		if tex != null:g.draw_texture_rect(tex, Rect2(-sz / 2, -sz / 2, sz, sz), false, Color(1, 1, 1, 1 - t * t))
		g.draw_rect(Rect2(-sz / 2, -sz / 2, sz, sz), Color(CORE, .35 * (1 - t)), false, 1)
		g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# text torn out of the game, rising
	for i in range(RIFT_TEXT.size()):
		var t: float = fposmod(clock * .13 + i / float(RIFT_TEXT.size()), 1.0)
		var q := Vector2(c.x + (h(i, 59) - .5) * 70 * wk + sin(t * 5 + i) * 6, top + 20 - t * 120)
		g.draw_string(g.font, q.floor() - Vector2(g.font.get_string_size(RIFT_TEXT[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x / 2, 0), RIFT_TEXT[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(CORE.lerp(Color.WHITE, .5), sin(t * PI) * .8))
	# it pulls at him as he comes close
	var near: float = 1 - clampf(me.distance_to(c) / 160.0, 0, 1)
	if near > 0:
		for i in range(14):
			var t: float = fposmod(clock * 1.4 + h(i, 61), 1.0)
			var q: Vector2 = (me + Vector2((h(i, 62) - .5) * 20, -10 - h(i, 63) * 22)).lerp(c, t)
			g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(CORE, near * (1 - t)))
	if e > 0:g.draw_circle(c, 40 + 600 * e * e, Color(.9, 1, 1, .25 * e))

## Screen-space layers: letterbox, flashes, white-out, the stopped grade, HUD.
static func screen(g):
	var w = g.world;var u = w.purge
	match u.phase:
		"countdown":
			var left: float = maxf(0, u.left)
			var urgent: bool = left < 15
			g.draw_rect(Rect2(190, 44, 260, 34), Color(.05, 0, .01, .78))
			g.draw_rect(Rect2(190, 44, 260, 34), Color(RED, .6 if not urgent or int(w.clock * 4) % 2 == 0 else 1.0), false, 1)
			g.centered("УДАЛЕНИЕ  Steve.dat", 55, 8, Color(1, .6, .6))
			g.centered(timer_text(left), 72, 16, RED if urgent and int(w.clock * 4) % 2 == 0 else Color.WHITE, true)
			g.draw_rect(Rect2(196, 80, 248, 3), Color(.25, 0, .02))
			g.draw_rect(Rect2(196, 80, 248 * u.progress(), 3), RED)
			if left < 10:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 0, 0, .05 + .05 * sin(w.clock * 8)))
			# Arrival banner, same language as the other bosses but red.
			if u.age < 3.0:
				var op: float = smoothstep(0, .25, u.age) * (1 - smoothstep(2.2, 3.0, u.age))
				g.draw_rect(Rect2(0, 96, 640, 54), Color(.06, 0, .01, .86 * op))
				for i in range(5):g.draw_rect(Rect2(0, 96 + h(int(w.clock * 20) + i, 50) * 54, 640, 1), Color(RED, .3 * op))
				g.centered("УДАЛЕНИЕ ИГРОКА", 122, 24, Color(1, .3, .3, op), true)
				g.centered("sudo rm -rf ./players/Steve.dat", 140, 8, Color(1, .75, .75, op * .85))
		"snap":
			var k: float = clampf(u.age / u.SNAP, 0, 1)
			g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, k * .7))
			if u.age > 1.4:g.centered("Steve.dat не найден", 180, 16, Color(1, .4, .4, smoothstep(1.4, 2.0, u.age)), true)
		"core":
			var a0: float = u.age
			if a0 < .25:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, .9, .9, .6 * (1 - a0 / .25)))
			var bars: float = 38 * smoothstep(0, .5, a0) * (1 - smoothstep(u.CORE - .3, u.CORE, a0))
			g.draw_rect(Rect2(0, 0, 640, bars), Color.BLACK);g.draw_rect(Rect2(0, 360 - bars, 640, bars), Color.BLACK)
			# the level fades out around the core: only the core and Steve matter
			g.draw_rect(Rect2(0, 0, 640, 360), Color(0, .02, .03, .35 * smoothstep(.6, 1.6, a0) * (1 - smoothstep(3.9, 4.3, a0))))
			if a0 > 1.0:
				var a: float = smoothstep(1.0, 1.5, a0) * (1 - smoothstep(2.9, 3.2, a0))
				var jx: float = (h(int(w.clock * 30), 70) - .5) * 3 if int(w.clock * 9) % 7 == 0 else 0.0
				g.centered("ЯДРО ИГРЫ", 92, 32, Color(CORE, a), true)
				g.draw_string(g.font, Vector2(320 - g.font.get_string_size("core.dll  ·  2 147 483 647 B", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x / 2 + jx, 112), "core.dll  ·  2 147 483 647 B", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, a * .7))
			if a0 > 3.9:
				var a: float = smoothstep(3.95, 4.3, a0)
				g.centered("ПОГЛОЩЕНИЕ", 300, 16, Color(1, 1, 1, a * (1 - smoothstep(5.0, u.CORE, a0))), true)
				var bar: float = smoothstep(3.95, 5.2, a0)
				g.draw_rect(Rect2(220, 312, 200, 4), Color(0, 0, 0, .6 * a));g.draw_rect(Rect2(220, 312, 200 * bar, 4), Color(CORE, a))
			if a0 > 3.9 and a0 < 4.1:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, .5 * (1 - (a0 - 3.9) / .2)))
			if a0 > 5.1:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, smoothstep(5.1, u.CORE, a0)))
		"surge":
			var k: float = clampf(u.age / u.SURGE, 0, 1)
			var beat: float = 1.0 - clampf(u.pulse / 120.0, 0, 1) if u.pulse >= 0 else 0.0
			for i in range(14):
				var f: float = 1 - i / 14.0
				var al: float = (.05 + .07 * k + .1 * beat) * f * f
				g.draw_rect(Rect2(0, i * 4, 640, 4), Color(CORE, al));g.draw_rect(Rect2(0, 356 - i * 4, 640, 4), Color(CORE, al))
				g.draw_rect(Rect2(i * 4, 0, 4, 360), Color(CORE, al));g.draw_rect(Rect2(636 - i * 4, 0, 4, 360), Color(CORE, al))
			if u.flash > 0:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, minf(1, u.flash / .6)))
			if u.age < 3.5:
				var a: float = smoothstep(0, .3, u.age) * (1 - smoothstep(2.6, 3.5, u.age))
				g.centered("ПЕРЕГРУЗКА", 122, 32, Color(CORE, a), true)
				g.centered("лимиты сняты · уровни · оружие · слоты", 142, 8, Color(1, 1, 1, a * .8))
			clock(g, 0.0)
			power(g)
		"ascend":
			var k: float = u.age / u.ASCEND
			clock(g, k)
			power(g)
			g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, smoothstep(.45, 1.0, k)))
		"stop", "enter":
			# The instant time stops: a ring of stillness rolls out from him.
			if u.phase == "stop" and u.age < u.WHITE + 1.2:
				var k: float = clampf((u.age - u.WHITE * .4) / 1.4, 0, 1)
				var c: Vector2 = w.player - w.camera() + Vector2(320, 166)
				g.draw_arc(c, 20 + k * 520, 0, TAU, 96, Color(.85, .95, 1, .55 * (1 - k)), 3)
				g.draw_arc(c, 10 + k * 470, 0, TAU, 96, Color(.6, .8, 1, .3 * (1 - k)), 1)
			# Everything is frozen: cold, drained grade; a slow white fade back in.
			g.draw_rect(Rect2(0, 0, 640, 360), Color(.55, .6, .72, .2))
			for i in range(18):
				var k: float = 1 - i / 18.0
				g.draw_rect(Rect2(0, i * 3, 640, 3), Color(0, 0, 0, .25 * k * k));g.draw_rect(Rect2(0, 357 - i * 3, 640, 3), Color(0, 0, 0, .25 * k * k))
			if u.phase == "stop" and u.age < u.WHITE:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, 1 - smoothstep(0, u.WHITE, u.age)))
			g.centered("00:00", 24, 16, Color(.85, .9, 1, .35 + .1 * sin(w.clock)), true)
			if u.age > u.WHITE + 1.2 and u.phase == "stop":g.centered("Время остановлено", 330, 8, Color(.85, .9, 1, .5 * smoothstep(u.WHITE + 1.2, u.WHITE + 2.2, u.age)))
			# a cold glow at the screen edge points at the crack while it is off-screen
			var rel: Vector2 = u.crack - w.camera()
			if absf(rel.x) > 300 or absf(rel.y) > 160:
				var edge: Vector2 = Vector2(320, 180) + rel.normalized() * Vector2(290, 150)
				g.draw_circle(edge, 10 + 3 * sin(w.clock * 3), Color(CORE, .35))
				g.draw_line(edge, edge - rel.normalized() * 18, Color(CORE, .7), 2)
			if u.phase == "enter":
				g.draw_rect(Rect2(0, 0, 640, 360), Color(.85, 1, 1, .5 * smoothstep(0, .5, u.age) * (1 - smoothstep(.7, 1.1, u.age))))
				g.draw_rect(Rect2(0, 0, 640, 360), Color(.02, 0, .05, smoothstep(.8, u.ENTER, u.age)))

## The run clock racing ahead, then leaving the screen.
static func clock(g, out: float):
	var w = g.world;var u = w.purge
	var t: float = w.time
	var text: String = "%d:%02d" % [int(t / 60), int(fposmod(t, 60))]
	var rate: float = u.rate()
	var size: int = 16 if rate < 3 else 32
	var j: Vector2 = Vector2((h(int(w.clock * 40), 40) - .5), (h(int(w.clock * 40), 41) - .5)) * minf(6, rate * .8)
	var y: float = 24 - out * out * 80
	var x: float = 320 - g.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2
	g.draw_string(g.font, Vector2(x, y) + j + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, .5))
	g.draw_string(g.font, Vector2(x, y) + j, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, CORE.lerp(Color.WHITE, clampf(rate / 7, 0, 1)))
	if rate > 2:g.text_at("x%.1f" % rate, Vector2(x + g.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 8, y - 4) + j, 8, Color(CORE, .8))

static func power(g):
	var w = g.world;var u = w.purge
	var k: float = clampf(u.age / u.SURGE, 0, 1) if u.phase == "surge" else 1.0 + u.age / u.ASCEND
	var value: int = int(1000.0 * pow(2000.0, clampf(k * .5, 0, 1)))
	var text: String = "МОЩЬ  " + group(value)
	var beat: float = 1.0 - clampf(u.pulse / 120.0, 0, 1) if u.pulse >= 0 else 0.0
	g.text_at(text, Vector2(13, 49), 16, Color(0, 0, 0, .5), true)
	g.text_at(text, Vector2(12, 48), 16, CORE.lerp(Color.WHITE, beat * .7), true)

static func timer_text(left: float) -> String:
	return "%d:%02d.%02d" % [int(left / 60), int(left) % 60, int(fposmod(left, 1.0) * 100)]

static func group(v: int) -> String:
	var s: String = str(v);var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:out += " "
		out += s[i]
	return out
