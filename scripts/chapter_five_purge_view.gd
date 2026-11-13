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
	var t_text: String = "%02d:%02d" % [int(left), int(fposmod(left, 1.0) * 100)]
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
			if u.age < 2.4:g.draw_actor("steve", p, Vector2.UP if u.age > 1.6 else w.facing, w.clock, false, Color.WHITE, "walk", 1.0, w.player_visual)
			else:
				g.draw_actor("steve", p, Vector2.DOWN, w.clock, false, Color(1.4, 1.6, 1.5), "walk", 1.0, w.player_visual)
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
	if u.phase == "core":
		var c: Vector2 = u.core_at(w) + offset
		var pulse: float = 1 + .2 * sin(w.clock * 12)
		if u.age < .6:
			g.draw_circle(u.core_from + offset + Vector2(0, -60), 70 * (1 - u.age / .6), Color(1, .4, .4, .5 * (1 - u.age / .6)))
			for i in range(24):
				var d: Vector2 = Vector2.from_angle(h(i, 20) * TAU)
				g.draw_rect(Rect2(u.core_from + offset + Vector2(0, -60) + d * u.age * 260, Vector2(4, 4)), Color(.15, .15, .17))
		for i in range(8):
			var a: float = w.clock * 2 + i * TAU / 8
			g.draw_line(c, c + Vector2.from_angle(a) * (20 + 10 * sin(w.clock * 7 + i)) * pulse, Color(CORE, .5), 1)
		g.draw_circle(c, 13 * pulse, Color(CORE, .25))
		g.draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), Color(.8, 1, .95))
		g.draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), Color(.2, .9, .6), false, 1)
		g.draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)
		if u.age > 1.9:
			var k: float = smoothstep(1.9, 2.4, u.age)
			g.draw_circle(c, 40 * k, Color(CORE, .3 * (1 - smoothstep(2.6, u.CORE, u.age))))
	if u.wave >= 0:
		var c: Vector2 = u.wave_from + offset
		var r: float = u.wave
		for i in range(4):g.draw_arc(c, maxf(1, r - i * 9), 0, TAU, 96, Color(CORE.lerp(Color.WHITE, i * .25), .75 - i * .17), 4 - i)
		g.draw_arc(c, maxf(1, r * .82), 0, TAU, 96, Color(1, 1, 1, .12), 18)
	if u.phase == "ascend":
		var r: float = u.aura(w)
		var c: Vector2 = w.player + offset + Vector2(0, -12)
		g.draw_circle(c, r, Color(1, 1, 1, .07))
		for i in range(3):g.draw_arc(c, r - i * 6, w.clock * (1 + i), w.clock * (1 + i) + TAU * .8, 48, Color(CORE.lerp(Color.WHITE, .6), .6 - i * .15), 2)
	if u.phase in ["stop", "enter"]:crack(g, u.crack + offset, smoothstep(u.WHITE, u.WHITE + u.CRACK_OPEN, u.age), w.clock)

## A tear in the stopped world: jagged, deep, light pouring up out of it.
static func crack(g, c: Vector2, k: float, clock: float):
	if k <= 0:return
	var pts_l: PackedVector2Array = []
	var pts_r: PackedVector2Array = []
	var n := 12
	for i in range(n + 1):
		var t: float = float(i) / n
		var y: float = (t - .5) * 170 * k
		var wide: float = sin(t * PI) * 26 * k * (.7 + .3 * h(i, 30))
		var x: float = (h(i, 31) - .5) * 14
		pts_l.append(c + Vector2(x - wide, y));pts_r.append(c + Vector2(x + wide, y))
	var poly: PackedVector2Array = pts_l.duplicate()
	for i in range(n, -1, -1):poly.append(pts_r[i])
	g.draw_colored_polygon(poly, Color(.02, 0, .05))
	g.draw_polyline(pts_l, Color(CORE, .9), 2);g.draw_polyline(pts_r, Color(CORE, .9), 2)
	for i in range(16):
		var t: float = fposmod(clock * .6 + h(i, 32), 1.0)
		var q: Vector2 = c + Vector2((h(i, 33) - .5) * 20 * k, (h(i, 34) - .5) * 100 * k - t * 30)
		g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(CORE, (1 - t) * k))
	g.draw_circle(c, 46 * k, Color(CORE, .1))
	g.draw_circle(c, 22 * k, Color(CORE, .12))

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
			g.centered("%02d:%02d" % [int(left), int(fposmod(left, 1.0) * 100)], 72, 16, RED if urgent and int(w.clock * 4) % 2 == 0 else Color.WHITE, true)
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
			var bars: float = 34 * smoothstep(0, .4, u.age) * (1 - smoothstep(u.CORE - .3, u.CORE, u.age))
			g.draw_rect(Rect2(0, 0, 640, bars), Color.BLACK);g.draw_rect(Rect2(0, 360 - bars, 640, bars), Color.BLACK)
			if u.age > 1.9:
				var a: float = smoothstep(1.9, 2.3, u.age) * (1 - smoothstep(3.2, u.CORE, u.age))
				g.centered("ЯДРО ИГРЫ", 92, 32, Color(CORE, a), true)
				g.centered("core.dll", 112, 8, Color(1, 1, 1, a * .7))
			if u.age > 3.25:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, smoothstep(3.25, u.CORE, u.age)))
		"surge":
			if u.flash > 0:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, u.flash / .6))
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
			if u.phase == "enter":g.draw_rect(Rect2(0, 0, 640, 360), Color(.02, 0, .05, smoothstep(0, .9, u.age)))

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
	var text: String = "Мощь: " + group(value)
	g.text_at(text, Vector2(12, 46), 8, Color(CORE, .85))

static func group(v: int) -> String:
	var s: String = str(v);var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:out += " "
		out += s[i]
	return out
