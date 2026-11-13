extends RefCounted
## Notch on screen: his figure, the fight's attacks, the battle box and the
## lanes. Reads the notch state only.
const FourPrompt = preload("res://scripts/chapter_four_finale_view.gd")
const Atmosphere = preload("res://scripts/ui/atmosphere.gd")
const ROWS := {"down": 0, "up": 1, "side": 2}
const WHITE := Color(1, 1, 1)
const ORANGE := Color(1, .62, .15)
const YELLOW := Color(1, .95, .3)

static func data(g) -> Dictionary:
	if not g.has_meta("ch5_notch"):
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_assets.json")).notch
		if not g.textures.has(d.sheet):g.load_texture(d.sheet)
		g.set_meta("ch5_notch", d)
	return g.get_meta("ch5_notch")

static func figure(g, pose: String, t: float, p: Vector2, dir: Vector2, scale: float = 1.0, tint: Color = Color.WHITE):
	var d: Dictionary = data(g)
	var layout: Dictionary = d.layout
	if not layout.has(pose):pose = "idle"
	var clip: Dictionary = layout[pose]
	var loop: bool = pose in ["idle", "walk", "aura", "float", "invite", "exhausted", "lying"]
	var index: int = int(t * (6.0 if loop else 10.0))
	index = index % int(clip.count) if loop else mini(int(clip.count) - 1, index)
	var size := Vector2(d.frame[0], d.frame[1]);var anchor := Vector2(d.anchor[0], d.anchor[1])
	var row: int = 2 if absf(dir.x) > absf(dir.y) else (1 if dir.y < 0 else 0)
	var flip: bool = dir.x < 0 and row == 2
	g.draw_set_transform(p.floor(), 0, Vector2(-1 if flip else 1, 1))
	g.draw_texture_rect_region(g.textures[d.sheet], Rect2(-anchor * scale, size * scale), Rect2(Vector2((int(clip.start) + index) * size.x, row * size.y), size), tint)
	g.draw_set_transform(Vector2.ZERO)

static func glow(g, p: Vector2, scale: float, clock: float):
	for i in range(14):
		var t: float = fposmod(clock * .6 + i * .071, 1.0)
		var q: Vector2 = p + Vector2(sin(i * 2.4) * 12 * scale, -t * 50 * scale)
		g.draw_string(g.font, q.floor(), "01"[i % 2], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.3, 1, .9, (1 - t) * .7))

# ------------------------------------------------------------------ in the code space

static func actor(g, offset: Vector2):
	var w = g.world;var n = w.notch
	if not (n.phase in ["intro", "fight", "to_ut", "retry"] and (n.phase != "retry" or n.retry_of == "fight")):return
	var p: Vector2 = n.p + offset
	var height: float = 0.0
	if n.phase == "fight" and n.slam_age >= 0:height = (n.slam_at - n.p).y
	g.oval(n.p + Vector2(0, height) + offset, Vector2(10, 3) * (1.0 - clampf(height / 300.0, 0, .7)), Color(0, 0, 0, .35))
	glow(g, p, 1.0, w.clock)
	var m = n.notch_mob(w) if n.id >= 0 else null
	var tint := Color(1.8, 1.8, 1.8) if m != null and m.flash > 0 and g.settings.flashes else Color.WHITE
	if n.phase == "fight" and n.enraged:
		# Red static around him once he is angry.
		for i in range(10):
			var a: float = i * .628 + w.clock * 3.0
			var q: Vector2 = p + Vector2(cos(a) * 16, sin(a) * 8 - 18 - fposmod(w.clock * 40 + i * 9, 30))
			g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(1, .1, .15, .7))
		if int(w.clock * 9) % 7 == 0:figure(g, n.pose, n.pose_age, p + Vector2(4, -3), n.dir, 1.5, Color(1, .1, .3, .5))
	var lift: float = round(sin(w.clock * 2.0) * 1.5) + 3
	figure(g, n.pose, n.pose_age, p - Vector2(0, lift), n.dir, 1.5, tint)

const RED := Color(.93, .16, .14)
const SELECT := Color(.25, .5, 1)

## Under the actors: selections, shadows of falling blocks, craters, dash lines.
static func ground(g, offset: Vector2):
	var w = g.world;var n = w.notch
	if n.phase != "fight":return
	var v = view(g)
	var ink: Color = Color(.08, .08, .1).lerp(Color(.9, .92, 1), n.dark)
	for h in n.hz:
		if h.age < 0:continue
		match h.kind:
			"select":
				var r := Rect2(h.rect.position + offset, h.rect.size)
				var del: float = h.drag + h.hold
				if h.age < del:
					var k: float = 1.0 - pow(1.0 - clampf(h.age / h.drag, 0, 1), 3)
					var anchors := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
					var from: Vector2 = anchors[h.corner];var to: Vector2 = anchors[(h.corner + 2) % 4]
					var cur: Vector2 = from.lerp(to, k)
					var shown := Rect2(from, cur - from).abs()
					var hold: float = clampf((h.age - h.drag) / h.hold, 0, 1)
					g.draw_rect(shown, Color(SELECT, .18 + .1 * hold))
					if h.age > h.drag:
						g.draw_rect(shown, Color(RED, hold * .3 * (.6 + .4 * sin(h.age * 40))))
						g.text_at("Del", shown.get_center() - Vector2(8, -3), 8, Color(RED, .5 + hold * .5))
					dashed_rect(g, shown, SELECT.lerp(RED, hold), h.age * 30.0)
					cursor_arrow(g, cur)
				else:
					# Deleted: a hole of nothing with dead pixels, closing again.
					var t: float = h.age - del
					var close: float = 1.0 - smoothstep(.6, .9, t)
					var hole: Rect2 = r.grow_individual(-r.size.x * (1 - close) / 2, -r.size.y * (1 - close) / 2, -r.size.x * (1 - close) / 2, -r.size.y * (1 - close) / 2)
					if t < .08:g.draw_rect(r, Color.WHITE)
					else:
						g.draw_rect(hole, Color(0, 0, 0, .95) if n.dark < .5 else Color(.95, .95, 1, .9))
						for i in range(26):
							var q: Vector2 = hole.position + hole.size * Vector2(Atmosphere.hash01(i, int(t * 20), 71), Atmosphere.hash01(i, int(t * 20), 72))
							g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), [Color(.97, 0, .86), Color(.3, 1, .9), RED][i % 3])
						g.draw_rect(hole, RED, false, 1)
			"block":
				var k: float = clampf(h.age / h.fall, 0, 1)
				var q: Vector2 = h.p + offset
				if h.age < h.fall:
					g.oval(q, Vector2(4 + 9 * k, 2 + 4 * k), Color(0, 0, 0, .15 + .35 * k))
					g.draw_arc(q, 17, 0, TAU, 20, Color(RED, .25 + .35 * k), 1)
				else:
					var t: float = h.age - h.fall
					crack(g, q, 12.0, Color(ink, .5 * (1.0 - t)), int(h.p.x))
					if h.block == "ch5q_tnt" and t < .7:
						g.draw_arc(q, 52, 0, TAU, 32, Color(RED, .4 + .4 * float(int(t * 14) % 2)), 2)
						g.draw_circle(q, 52, Color(RED, .08))
			"crater":
				var t: float = h.age / 2.0
				crack(g, h.p + offset, 40.0, Color(ink, .7 * (1 - t)), int(h.p.x))
			"clone":
				if h.age < h.warn + .1:
					var d: Vector2 = h.from.direction_to(h.target)
					var a: Vector2 = h.from + offset;var b: Vector2 = a + d * 420.0
					var k: float = clampf(h.age / h.warn, 0, 1)
					g.draw_line(a, b, Color(RED, .15 + .25 * k), 9.0 * k + 1)
					for s in range(0, 420, 14):
						var q: Vector2 = a + d * (s + fposmod(h.age * 120.0, 14.0))
						g.draw_line(q, q + d * 6, Color(RED, .8), 2)
	if n.slam_age >= 0:
		var hunt: float = 1.05;var lock: float = .35
		var q: Vector2 = n.slam_at + offset
		var locked: bool = n.slam_age >= hunt
		var spin: float = w.clock * (2.0 if not locked else 0.0)
		var c: Color = RED if locked and int(n.slam_age * 20) % 2 == 0 else Color(RED, .7)
		g.draw_arc(q, 46, 0, TAU, 36, Color(c, .8), 2)
		g.draw_circle(q, 46, Color(RED, .1 + (.15 if locked else 0.0)))
		for k in range(4):
			var a: float = spin + k * PI / 2
			g.draw_line(q + Vector2.from_angle(a) * 30, q + Vector2.from_angle(a) * 54, c, 2)

static func crack(g, at: Vector2, size: float, c: Color, seed: int):
	if c.a <= 0:return
	for i in range(7):
		var a: float = i * .9 + Atmosphere.hash01(seed, i, 80) * .6
		var q: Vector2 = at
		for s in range(3):
			var nq: Vector2 = q + Vector2.from_angle(a + (Atmosphere.hash01(seed, i * 3 + s, 81) - .5) * .9) * size / 3.0
			g.draw_line(q.floor(), nq.floor(), c, 1)
			q = nq

## Over the actors: falling blocks, beams, the clones, bolts, the shockwave, popups.
static func air(g, offset: Vector2):
	var w = g.world;var n = w.notch
	if n.phase != "fight":return
	var v = view(g)
	var mouth: Vector2 = n.p + offset + Vector2(0, -14)
	for h in n.hz:
		if h.age < 0:continue
		match h.kind:
			"block":
				var k: float = clampf(h.age / h.fall, 0, 1)
				var q: Vector2 = h.p + offset
				if h.age < h.fall:
					cube(g, v, h.block, q - Vector2(0, (1 - k * k) * 260.0), 22.0, 1.0)
				else:
					var t: float = h.age - h.fall
					if h.block == "ch5q_tnt":
						if t < .7:cube(g, v, h.block, q, 22.0, 1.0, Color(2.4, 2.4, 2.4) if int(t * (8 + t * 20)) % 2 == 0 else Color.WHITE)
						else:mc_boom(g, v, q, t - .7, 1.3)
						continue
					if t < .12:cube(g, v, h.block, q + Vector2(0, -2), 22.0, 1.0)
					# It breaks into its own pixels.
					for i in range(12):
						var a: float = i * 2.39996
						var fp: Vector2 = q + Vector2(cos(a) * (8 + t * 70), -10 - t * 50 * (1 + sin(a)) + t * t * 160)
						if t < .6:g.draw_texture_rect_region(v.tex(h.block), Rect2(fp.floor(), Vector2(4, 4)), Rect2((i % 4) * 4, (i / 4) * 4, 4, 4), Color(1, 1, 1, 1 - t / .6))
					if t < .25:g.draw_arc(q, 10 + t * 120, 0, TAU, 24, Color(1, 1, 1, .8 * (1 - t / .25)), 2)
			"beam":
				var d: Vector2 = Vector2.from_angle(h.angle)
				if h.age < h.warn:
					var k: float = h.age / h.warn
					g.draw_line(mouth, mouth + d * 700, Color(RED, .3 + .5 * k * float(int(h.age * 18) % 2)), 1 + int(k * 2))
					# An arrow shows which way it will turn.
					var tip: Vector2 = mouth + d * 70
					var side: Vector2 = d.orthogonal() * signf(h.spin)
					g.draw_line(tip, tip + side * 16, Color(RED, .8), 2);g.draw_line(tip + side * 16, tip + side * 10 + d * 5, Color(RED, .8), 2)
				elif h.age < h.warn + h.life + .25:
					var t: float = h.age - h.warn
					var fade: float = 1.0 - smoothstep(h.life, h.life + .25, t)
					var wd: float = (9.0 + 2.0 * sin(t * 50)) * minf(1, t / .08) * fade
					var o: Vector2 = d.orthogonal()
					g.draw_colored_polygon(PackedVector2Array([mouth + o * wd * 1.8, mouth + o * wd * 1.8 + d * 700, mouth - o * wd * 1.8 + d * 700, mouth - o * wd * 1.8]), Color(.3, 1, .9, .25 * fade))
					g.draw_colored_polygon(PackedVector2Array([mouth + o * wd, mouth + o * wd + d * 700, mouth - o * wd + d * 700, mouth - o * wd]), Color(1, 1, 1, .95 * fade))
					g.draw_colored_polygon(PackedVector2Array([mouth + o * wd * .35, mouth + o * wd * .35 + d * 700, mouth - o * wd * .35 + d * 700, mouth - o * wd * .35]), Color(.6, 1, .95, fade))
					for i in range(10):
						var s: float = fposmod(t * 300 + i * 70, 700)
						g.draw_string(g.font, (mouth + d * s + o * (wd + 4) * (1 if i % 2 else -1)).floor(), "01{}"[i % 4], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.3, 1, .9, .8 * fade))
					g.draw_circle(mouth, wd * 1.6, Color(1, 1, 1, fade))
			"clone":
				var d: Vector2 = h.from.direction_to(h.target)
				var q: Vector2 = h.p + offset
				if h.age >= h.warn:
					for i in range(5):
						var back: Vector2 = q - d * (i + 1) * 16 * clampf((h.age - h.warn) / .1, 0, 1)
						figure(g, "lunge", 0.0, back, d, 1.5, Color(1, .2, .4, .35 - i * .06))
				var glitch: Vector2 = Vector2(round(sin(w.clock * 47 + h.from.x) * 2), 0)
				var alpha: float = clampf(h.age / .15, 0, 1) * (1.0 - clampf((h.age - h.warn - h.dash) / .35, 0, 1))
				figure(g, "lunge" if h.age >= h.warn else "snap", h.age, q + glitch + Vector2(2, 0), d, 1.5, Color(.2, 1, 1, .45 * alpha))
				figure(g, "lunge" if h.age >= h.warn else "snap", h.age, q + glitch, d, 1.5, Color(1, .35, .5, alpha))
			"bolt":
				var q: Vector2 = h.p + offset
				g.draw_circle(q, 6, Color(RED, .25))
				g.draw_rect(Rect2((q - Vector2(4, 4)).floor(), Vector2(8, 8)), Color(.05, .05, .07))
				g.draw_rect(Rect2((q - Vector2(4, 4)).floor(), Vector2(8, 8)), RED, false, 1)
				g.draw_string(g.font, (q + Vector2(-2, 3)).floor(), h.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, .85, .8))
			"wave":
				var r: float = h.age * 290.0
				var fade: float = 1.0 - clampf(r / 420.0, 0, 1)
				var c: Vector2 = h.p + offset
				for gi in range(24):
					var a0: float = gi * TAU / 24.0;var a1: float = a0 + TAU / 24.0
					var mid: float = (a0 + a1) / 2
					var safe := false
					for gp in h.gaps:safe = safe or absf(angle_difference(mid, gp)) < .3
					if safe:continue
					g.draw_arc(c, r, a0, a1, 4, Color(1, 1, 1, fade), 10)
					g.draw_arc(c, r, a0, a1, 4, Color(RED, fade), 5)
				if r < 60:g.draw_circle(c, 46 - r * .5, Color(1, 1, 1, .7 * (1 - r / 60)))
	for pu in n.popups:
		if pu.get("screen", false):continue
		var k: float = pu.age / 1.8
		var q: Vector2 = pu.p + offset - Vector2(0, 48 + k * 14)
		var wd: float = g.font.get_string_size(pu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		g.draw_rect(Rect2((q - Vector2(wd / 2 + 4, 9)).floor(), Vector2(wd + 8, 12)), Color(0, 0, 0, .75 * (1 - k)))
		g.draw_string(g.font, (q - Vector2(wd / 2, 0)).floor(), pu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.4, 1, .9, 1 - k))

## A block seen from above-front: the texture as the face, a darker top strip.
static func cube(g, v, block: String, at: Vector2, size: float, alpha: float, tint := Color.WHITE):
	var r := Rect2((at - Vector2(size / 2, size)).floor(), Vector2(size, size))
	g.draw_texture_rect(v.tex(block), Rect2(r.position + Vector2(0, -6), Vector2(size, 6)), false, Color(tint.r * 1.15, tint.g * 1.15, tint.b * 1.15, alpha))
	g.draw_texture_rect(v.tex(block), r, false, Color(tint.r * .8, tint.g * .8, tint.b * .8, alpha))
	g.draw_rect(Rect2(r.position + Vector2(0, -6), Vector2(size, size + 6)), Color(0, 0, 0, .6 * alpha), false, 1)

static func overlay(g):
	var w = g.world;var n = w.notch
	if n.phase == "fight":
		if n.flash > 0 and g.settings.flashes:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, .1, .1, n.flash * .35))
		if n.enraged:
			var pulse: float = .18 + .08 * sin(w.clock * 4.0)
			for i in range(8):g.draw_rect(Rect2(i * 4, i * 4, 640 - i * 8, 360 - i * 8), Color(.8, 0, .05, pulse * (1.0 - i / 8.0)), false, 4)
	if n.phase == "fight" and n.id >= 0:
		g.centered("Нотч" if not n.enraged else "Нотч · HARDCORE", 41, 8, Color.WHITE if not n.enraged else Color(1, .35, .35), true)
		g.draw_rect(Rect2(159, 46, 322, 9), Color(0, 0, 0, .8))
		var k: float = clampf(n.hp / n.FIGHT_HP, 0, 1)
		g.draw_rect(Rect2(160, 47, 320 * k, 7), Color(.3, 1, .9) if not n.enraged else Color(.95, .15, .2))
		g.draw_rect(Rect2(160, 47, 320 * k, 2), Color(1, 1, 1, .45))
		g.draw_rect(Rect2(319, 45, 2, 11), Color(1, 1, 1, .8))
	if n.phase == "intro":
		g.draw_rect(Rect2(0, 0, 640, 24), Color.BLACK);g.draw_rect(Rect2(0, 336, 640, 24), Color.BLACK)
		if n.age > 1.5:g.text_at("Пробел — пропустить", Vector2(522, 351), 8, Color(1, 1, 1, .35))
	retry(g, n)
	subtitles(g, n, 278.0 if n.phase == "fight" else 316.0)

## Long phrases wrap to two rows; a phrase in capitals is a scream: big, red, every letter shaking.
static func subtitles(g, n, y: float):
	if n.line.is_empty():return
	var a: float = minf(1, n.line_age / .15) * minf(1, (n.line_length - n.line_age) / .2)
	var size: int = 16 if n.scream else 8
	var rows: Array = wrap_rows(g, n.line, size, 580.0)
	var row_h: float = 22.0 if n.scream else 12.0
	var top: float = y - (rows.size() - 1) * row_h - (10.0 if n.scream else 0.0)
	var widest := 0.0
	for r in rows:widest = maxf(widest, g.font.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	if n.scream:g.draw_rect(Rect2(0, 0, 640, 360), Color(.5, 0, .03, .3 * (1 - smoothstep(0, .45, n.line_age))))
	g.draw_rect(Rect2((640 - widest) / 2 - 8, top, widest + 16, rows.size() * row_h + (10.0 if n.scream else 4.0)), Color(0, 0, 0, .65 * a))
	for i in range(rows.size()):
		var row: String = rows[i]
		if not n.scream:
			g.centered(row, top + 11 + i * row_h, 8, Color(.6, 1, .95, a));continue
		var rw: float = g.font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var shake: float = 2.4 * (1 - smoothstep(0, 1.2, n.line_age)) + .7;var tick: int = int(g.world.clock * 30)
		for c in range(row.length()):
			var x: float = (640 - rw) / 2 + g.font.get_string_size(row.substr(0, c), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var j := Vector2(Atmosphere.hash01(c + i * 97, tick, 61) - .5, Atmosphere.hash01(c + i * 97, tick, 62) - .5) * 2 * shake
			g.text_at(row[c], (Vector2(x + 1.5, top + 18 + i * row_h) + j).floor(), size, Color(.2, .9, 1, .35 * a))
			g.text_at(row[c], (Vector2(x, top + 18 + i * row_h) + j).floor(), size, Color(1, .12, .16, a))

static func wrap_rows(g, text: String, size: int, limit: float) -> Array:
	if g.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= limit:return [text]
	var rows: Array = [];var row := ""
	for word in text.split(" "):
		var next: String = word if row == "" else row + " " + word
		if row != "" and g.font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > limit:rows.append(row);row = word
		else:row = next
	rows.append(row)
	return rows

static func retry(g, n):
	if n.phase != "retry":return
	g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, minf(1, n.age / .6) * .85))
	g.centered("Чекпоинт", 170, 16, Color(1, 1, 1, minf(1, n.age / .8)), true)

# ------------------------------------------------------------------ the battle box

## Notch drawn the way Undertale draws its monsters: white, grey and black.
static func bw(g) -> Texture2D:
	if g.has_meta("ch5_notch_bw"):return g.get_meta("ch5_notch_bw")
	var d: Dictionary = data(g)
	var im: Image = g.textures[d.sheet].get_image()
	im.convert(Image.FORMAT_RGBA8)
	for y in range(im.get_height()):
		for x in range(im.get_width()):
			var c: Color = im.get_pixel(x, y)
			if c.a < .1:continue
			var l: float = c.get_luminance()
			im.set_pixel(x, y, Color(1, 1, 1, 1) if l > .58 else (Color(.6, .6, .6, 1) if l > .3 else (Color(.25, .25, .25, 1) if l > .16 else Color(0, 0, 0, 1))))
	var t := ImageTexture.create_from_image(im)
	g.set_meta("ch5_notch_bw", t)
	return t

static func bw_figure(g, pose: String, t: float, p: Vector2, scale: float, clock: float):
	var d: Dictionary = data(g)
	var layout: Dictionary = d.layout
	var clip: Dictionary = layout.get(pose, layout.idle)
	var index: int = int(t * 6.0) % int(clip.count)
	var size := Vector2(d.frame[0], d.frame[1]);var anchor := Vector2(d.anchor[0], d.anchor[1])
	var tex: Texture2D = bw(g)
	var col: int = int(clip.start) + index
	# Slices sway separately, the way Undertale monsters breathe.
	for y in range(0, int(size.y), 4):
		var sway: float = round(sin(clock * 2.2 + y * .09) * (1.5 if y < 30 else .5))
		g.draw_texture_rect_region(tex, Rect2((p - anchor * scale + Vector2(sway, y * scale)).floor(), Vector2(size.x, 4) * scale), Rect2(Vector2(col * size.x, y), Vector2(size.x, 4)))

static func ut_icon(g, kind: String, at: Vector2, c: Color):
	match kind:
		"fight":
			g.draw_line(at + Vector2(-5, 5), at + Vector2(5, -5), c, 2);g.draw_line(at + Vector2(-6, 2), at + Vector2(-2, 6), c, 2)
		"act":
			g.draw_rect(Rect2(at - Vector2(6, 5), Vector2(12, 8)), c, false, 2);g.draw_line(at + Vector2(-3, 3), at + Vector2(-5, 7), c, 2)
		"item":
			g.draw_rect(Rect2(at - Vector2(5, 3), Vector2(10, 9)), c, false, 2);g.draw_arc(at - Vector2(0, 3), 3, PI, TAU, 8, c, 2)
		"mercy":
			g.draw_line(at - Vector2(5, 5), at + Vector2(5, 5), c, 2);g.draw_line(at + Vector2(-5, 5), at + Vector2(5, -5), c, 2)

static func battle(g):
	var w = g.world;var n = w.notch
	var v = view(g)
	var quake: Vector2 = Vector2(round(sin(w.clock * 83) * 4), round(cos(w.clock * 71) * 3)) * minf(1.0, n.ut_quake / .2) if g.settings.shake else Vector2.ZERO
	g.set_meta("ut_quake", quake);g.draw_set_transform(quake)
	g.draw_rect(Rect2(-8, -8, 656, 376), Color(0, 0, 0))
	# His dimension behind the box: slow columns of code, dim and far away.
	for c in range(32):
		var x: float = 10 + c * 20
		var speed: float = 14.0 + fmod(c * 7.3, 18.0)
		for r in range(7):
			var y: float = fposmod(w.clock * speed + r * 54 + c * 31, 380.0) - 10
			var a: float = (.035 + .05 * float(r == 6)) * (1.0 - absf(x - 320) / 400.0)
			g.draw_string(g.font, Vector2(x, y), ["0", "1", "{", "}", ";", "=", "<", ">"][(c * 3 + r + int(w.clock * 2)) % 8], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.3, 1, .6, a))
	# Notch, Undertale-style: white, grey and black, breathing in slices.
	var hit_shake: float = 0.0
	if n.ut_state == "slash" and n.ut_number_age >= 0 and n.ut_number_age < .5:hit_shake = sin(n.ut_number_age * 70) * 9 * (1 - n.ut_number_age / .5)
	var np := Vector2(320 + hit_shake, 142 + sin(w.clock * 1.6) * 2)
	var pose: String = "exhausted" if n.ut_state == "end" else ("stagger" if n.ut_flash > 0 and n.ut_number_age >= 0 else ("cast" if n.ut_state == "wave" else "idle"))
	if n.ut_state == "wave" and n.ut_pattern == 5 and n.pose == "throw" and n.pose_age < .4:pose = "throw"
	if int(w.clock * 7) % 23 == 0:bw_figure_tint(g, pose, n.age, np + Vector2(5, 0), 3.6, w.clock, Color(.97, 0, .86, .45))
	bw_figure(g, pose, n.age, np, 3.6, w.clock)
	if n.ut_flash > 0 and n.ut_number_age >= 0 and int(w.clock * 30) % 2 == 0:bw_figure_tint(g, pose, n.age, np, 3.6, w.clock, Color(1, .2, .2, .55))
	# FIGHT: a red slash across him, then the number, then his HP drains.
	if n.ut_slash >= 0 and n.ut_slash < .4:
		var k: float = n.ut_slash / .4
		var a0: Vector2 = np + Vector2(-46, -128);var a1: Vector2 = np + Vector2(46, -24)
		var tip: Vector2 = a0.lerp(a1, minf(1, k * 1.6))
		var tail: Vector2 = a0.lerp(a1, maxf(0, k * 1.6 - .6))
		for i in range(3):
			var o := Vector2(-5 + i * 5, 0)
			g.draw_line(tail + o, tip + o, Color(1, .15, .15) if i != 1 else Color(1, .9, .9), 5 - absi(i - 1) * 2)
	if n.ut_number_age >= 0 and n.ut_number_age < 1.3:
		var bounce: float = -absf(sin(n.ut_number_age * 9.0)) * 14.0 * maxf(0, 1 - n.ut_number_age * 1.5)
		var txt: String = "ПРОМАХ" if n.ut_number < 0 else str(n.ut_number)
		var size: int = 40 if n.ut_crit and n.ut_number >= 0 else 32
		var tw: float = g.bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		g.draw_string(g.bold, Vector2(320 - tw / 2 + 2, 54 + bounce + 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0))
		g.draw_string(g.bold, Vector2(320 - tw / 2, 54 + bounce), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, .15, .15) if n.ut_number >= 0 else Color(.75, .75, .75))
		if n.ut_crit and n.ut_number >= 0:g.centered("КРИТ", 72 + bounce, 8, Color(1, .9, .3), true)
		if n.ut_number >= 0:
			g.draw_rect(Rect2(250, 80, 140, 9), Color(.25, .25, .25));g.draw_rect(Rect2(250, 80, 140 * clampf(n.ut_hp_shown / n.UT_HP, 0, 1), 9), Color(.1, .95, .2))
	var box: Rect2 = n.ut_box
	g.draw_rect(box, Color(0, 0, 0))
	if n.ut_mode == "blue" and n.ut_state == "wave":
		# The wall that pulls: a faint blue edge on the side gravity points to.
		var gr: Vector2 = n.ut_grav
		var edge := Rect2(box.position, Vector2(box.size.x, 3)) if gr.y < 0 else (Rect2(Vector2(box.position.x, box.end.y - 3), Vector2(box.size.x, 3)) if gr.y > 0 else (Rect2(box.position, Vector2(3, box.size.y)) if gr.x < 0 else Rect2(Vector2(box.end.x - 3, box.position.y), Vector2(3, box.size.y))))
		g.draw_rect(edge, Color(.25, .45, 1, .5))
	match n.ut_state:
		"wave":wave(g, n, v, box, w)
		"bar", "slash", "miss":
			var r := Rect2(box.position + Vector2(14, 10), Vector2(box.size.x - 28, box.size.y - 20))
			var c: Vector2 = r.get_center()
			# The target: concentric bands, a bright stripe in the middle.
			for i in range(14):
				var wd: float = r.size.x * (1.0 - i / 14.0)
				g.draw_rect(Rect2(c.x - wd / 2, r.position.y + i * 1.5, wd, r.size.y - i * 3), Color(.05, .05, .05) if i % 2 else Color(.12 + i * .05, .55 + i * .03, .25), false, 1)
			g.draw_rect(Rect2(c.x - 3, r.position.y, 6, r.size.y), Color(.95, .95, .9))
			var cx: float = r.position.x + r.size.x * clampf(n.bar, 0, 1)
			var lit: bool = n.ut_state == "bar" or int(w.clock * 16) % 2 == 0
			g.draw_rect(Rect2(cx - 4, r.position.y - 6, 8, r.size.y + 12), Color.WHITE if lit else Color.BLACK)
			g.draw_rect(Rect2(cx - 4, r.position.y - 6, 8, r.size.y + 12), Color.BLACK, false, 2)
			g.draw_rect(Rect2(cx - 2, r.position.y - 4, 4, r.size.y + 8), Color.WHITE if lit else Color(.3, .3, .3), false, 1)
		_:
			var shown: String = n.ut_text.substr(0, int(n.ut_type))
			var lines: PackedStringArray = shown.split("\n")
			for i in range(lines.size()):g.draw_string(g.bold, box.position + Vector2(22, 34 + i * 26), lines[i], HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 30, 16, Color.WHITE)
	g.draw_rect(box.grow(2), Color.WHITE, false, 4)
	for s in n.ut_sparks:
		var k: float = 1.0 - s.age / s.life
		g.draw_rect(Rect2(s.p.floor() - Vector2(1, 1), Vector2(3, 3) * (0.5 + k)), Color(s.col, k))
	# A hit tints the screen edge red.
	if n.ut_hurt > 0:
		for i in range(6):g.draw_rect(Rect2(i * 3, i * 3, 640 - i * 6, 360 - i * 6), Color(1, 0, 0, n.ut_hurt * (.5 - i * .07)), false, 3)
	stats(g, w, n, v)
	g.draw_set_transform(Vector2.ZERO)
	retry(g, n)

static func bw_figure_tint(g, pose: String, t: float, p: Vector2, scale: float, clock: float, tint: Color):
	var d: Dictionary = data(g)
	var clip: Dictionary = d.layout.get(pose, d.layout.idle)
	var index: int = int(t * 6.0) % int(clip.count)
	var size := Vector2(d.frame[0], d.frame[1]);var anchor := Vector2(d.anchor[0], d.anchor[1])
	var col: int = int(clip.start) + index
	for y in range(0, int(size.y), 4):
		var sway: float = round(sin(clock * 2.2 + y * .09) * (1.5 if y < 30 else .5))
		g.draw_texture_rect_region(bw(g), Rect2((p - anchor * scale + Vector2(sway, y * scale)).floor(), Vector2(size.x, 4) * scale), Rect2(Vector2(col * size.x, y), Vector2(size.x, 4)), tint)

## Undertale's bottom line: name, LV, HP bar and the four orange buttons.
static func stats(g, w, n, v):
	var hp: float = clampf(w.hp, 0, 20)
	var y: float = 294
	g.draw_string(g.bold, Vector2(40, y), "STEVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	g.draw_string(g.bold, Vector2(122, y), "LV 19", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	g.draw_string(g.bold, Vector2(222, y - 2), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	g.draw_rect(Rect2(244, y - 13, 60, 14), Color(.8, 0, 0))
	g.draw_rect(Rect2(244, y - 13, 60 * hp / 20.0, 14), Color(1, 1, 0) if n.ut_hurt <= 0 or int(w.clock * 20) % 2 else Color(1, 1, 1))
	g.draw_string(g.bold, Vector2(316, y), "%d / 20" % int(ceil(hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	var labels := {"fight":"БИТЬ", "act":"ДЕЙСТВ", "item":"ВЕЩИ", "mercy":"ПОЩАДА"}
	var options: Array = n.menu_options()
	for i in range(4):
		var r: Rect2 = n.menu_rect(i)
		if i >= options.size():
			if n.mercy_gone and int(w.clock * 3) % 4 == 0:g.draw_string(g.font, r.position + Vector2(16, 17), "null", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.97, 0, .86, .6))
			continue
		var on: bool = n.ut_state == "menu" and n.ut_choice == i
		var c: Color = Color(1, 1, .25) if on else Color(1, .5, .12)
		g.draw_rect(r, Color.BLACK);g.draw_rect(r, c, false, 2)
		if on:
			g.draw_texture_rect(g.textures.heart, Rect2(r.position + Vector2(5, 4), Vector2(16, 16)), false)
		else:
			var icon: String = {"fight":"ch5q_item_iron_sword", "act":"ch5q_item_book", "item":"ch5q_item_golden_apple", "mercy":"ch5q_item_paper"}[options[i]]
			g.draw_texture_rect(v.tex(icon), Rect2(r.position + Vector2(4, 2), Vector2(20, 20)), false, Color(1, .75, .5))
		g.draw_string(g.bold, r.position + Vector2(28, 17), labels[options[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)

static func wave(g, n, v, box: Rect2, w):
	var inner: Rect2 = box.grow(-1)
	# Selections first: they lie under everything.
	for s in n.ut_selects:
		if s.age < 0:continue
		var r: Rect2 = s.rect
		var k: float = clampf(s.age / s.drag, 0, 1);k = 1.0 - pow(1.0 - k, 3)
		var anchors := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		var from: Vector2 = anchors[s.corner];var to: Vector2 = anchors[(s.corner + 2) % 4]
		var cur: Vector2 = from.lerp(to, k)
		var shown := Rect2(from, cur - from).abs().intersection(inner)
		var deleted: bool = s.age >= s.drag + s.hold
		if not deleted:
			var blink: bool = s.age > s.drag and int(s.age * 14) % 2 == 0
			g.draw_rect(shown, Color(.2, .45, 1, .22 if not blink else .38))
			dashed_rect(g, shown, Color(.55, .75, 1), s.age * 30.0)
			if s.age > s.drag:
				var warn: float = (s.age - s.drag) / s.hold
				g.draw_rect(shown, Color(1, .15, .1, warn * .35))
				g.text_at("DEL", shown.get_center() - Vector2(9, -4), 8, Color(1, 1, 1, .5 + .5 * warn))
			cursor_arrow(g, cur)
		else:
			var t: float = s.age - s.drag - s.hold
			if t < .12:g.draw_rect(shown, Color(1, 1, 1, .95))
			elif t < .22:g.draw_rect(shown, Color(1, .15, .1, .8))
			# The selection breaks into its pixels.
			for i in range(24):
				var fx: float = fposmod(i * .618, 1.0);var fy: float = fposmod(i * .377 + .2, 1.0)
				var p0: Vector2 = shown.position + shown.size * Vector2(fx, fy)
				var p1: Vector2 = p0 + Vector2(fx - .5, fy - .9) * 120.0 * t + Vector2(0, 160 * t * t)
				if inner.has_point(p1):g.draw_rect(Rect2(p1.floor(), Vector2(3, 3)), Color(.55, .75, 1, 1.0 - t / .5))
	for b in n.ut_bullets:
		var shape: String = b.get("shape", "dot")
		if shape == "spike":spike(g, n, b, box);continue
		if shape == "anvil" and b.has("delay"):
			var warn: float = .3 + .3 * sin(b.age * 40)
			g.draw_rect(Rect2(b.p.x - 9, box.position.y, 18, box.size.y), Color(1, .2, .1, warn * .45))
			g.draw_rect(Rect2(b.p.x - 9, box.position.y, 18, box.size.y), Color(1, .3, .2, warn), false, 1)
			continue
		if not inner.grow(14).has_point(b.p) or b.p.y < -100:continue
		var r := Rect2(b.p - b.get("size", Vector2(8, 8)) / 2, b.get("size", Vector2(8, 8)))
		match shape:
			"block":
				g.draw_texture_rect(v.tex("ch5q_cobblestone"), clip(r, inner), false, Color(1.25, 1.25, 1.25))
			"fence":
				var cr: Rect2 = clip(r, inner)
				g.draw_rect(cr, Color(.95, .95, .95));g.draw_rect(Rect2(cr.position + Vector2(2, 0), Vector2(2, cr.size.y)), Color(.7, .7, .7))
				for yy in range(int(cr.position.y) + 4, int(cr.end.y), 9):g.draw_rect(Rect2(cr.position.x - 2, yy, cr.size.x + 4, 2), Color(.85, .85, .85))
			"key":
				var cr: Rect2 = clip(r, inner)
				g.draw_rect(cr, Color.WHITE);g.draw_rect(Rect2(cr.position + Vector2(0, cr.size.y - 3), Vector2(cr.size.x, 3)), Color(.6, .6, .6))
				g.draw_string(g.bold, b.p + Vector2(-3, 3), b.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.BLACK)
			"anvil":
				g.draw_texture_rect(v.tex("ch5q_anvil"), clip(r, inner), false, Color(1.3, 1.3, 1.35))
			"tnt":
				var blink: bool = int(b.age * (6 + b.age * 16)) % 2 == 0
				g.draw_texture_rect(v.tex("ch5q_tnt"), r, false, Color(2.2, 2.2, 2.2) if blink else Color.WHITE)
				var warn: float = clampf(b.age / b.fuse, 0, 1)
				g.draw_rect(Rect2(box.position.x, b.p.y - 6, box.size.x, 12), Color(1, .4, .1, .1 * warn + .08 * float(blink)))
				g.draw_rect(Rect2(b.p.x - 6, box.position.y, 12, box.size.y), Color(1, .4, .1, .1 * warn + .08 * float(blink)))
			"fire":
				var k2: float = 1.0 - float(b.get("age", 0.0)) / b.life
				var cr: Rect2 = clip(r.grow(2.0 * k2), inner)
				g.draw_rect(cr, Color(1, .45, .08, k2))
				g.draw_rect(cr.grow_individual(-cr.size.x * .2 * float(cr.size.y > cr.size.x), -cr.size.y * .3 * float(cr.size.x >= cr.size.y), -cr.size.x * .2 * float(cr.size.y > cr.size.x), -cr.size.y * .3 * float(cr.size.x >= cr.size.y)), Color(1, .95, .7, k2))
			_:g.draw_circle(b.p, 3.5, Color.WHITE)
	for bl in n.ut_blasters:ghast(g, bl)
	var blink_off: bool = w.invulnerable > 0 and int(w.clock * 20) % 2 == 1
	if not blink_off:g.draw_texture_rect(g.textures.heart, Rect2(n.soul - Vector2(7, 7), Vector2(14, 14)), false, Color(.5, .7, 1.8) if n.ut_mode == "blue" else Color.WHITE)
	if n.WAVE_LENGTH - n.ut_timer < 2.8 and not n.ut_bubble.is_empty():
		var bt: String = n.ut_bubble
		var rows: Array = []
		for part in bt.split("\n"):rows.append_array(wrap_rows(g, part, 8, 200.0))
		var bwid := 0.0
		for row in rows:bwid = maxf(bwid, g.font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
		var r := Rect2(384, 36, minf(220.0, bwid + 16), 10 + rows.size() * 11)
		g.draw_rect(r, Color.WHITE);g.draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, 10), r.position + Vector2(-10, 16), r.position + Vector2(0, 20)]), Color.WHITE)
		var shown: int = int((n.WAVE_LENGTH - n.ut_timer) * 34.0)
		for i in range(rows.size()):
			g.draw_string(g.font, r.position + Vector2(8, 14 + i * 11), rows[i].substr(0, maxi(0, shown)), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 8, Color.BLACK)
			shown -= rows[i].length()

static func clip(r: Rect2, inner: Rect2) -> Rect2:
	var c: Rect2 = r.intersection(inner)
	return c if c.has_area() else Rect2(r.position, Vector2.ZERO)

static func dashed_rect(g, r: Rect2, c: Color, phase: float):
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for e in range(4):
		var a: Vector2 = corners[e];var b: Vector2 = corners[(e + 1) % 4]
		var length: float = a.distance_to(b)
		if length < 1:continue
		var d: Vector2 = (b - a) / length
		var s: float = -fposmod(phase, 8.0)
		while s < length:
			var s0: float = maxf(0, s);var s1: float = minf(length, s + 4)
			if s1 > s0:g.draw_line(a + d * s0, a + d * s1, c, 1)
			s += 8

static func cursor_arrow(g, at: Vector2):
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 13), Vector2(3, 10), Vector2(6, 16), Vector2(8, 15), Vector2(5, 9), Vector2(9, 9)])
	var outline := PackedVector2Array()
	for p in pts:outline.append(at + p)
	g.draw_colored_polygon(outline, Color.WHITE)
	outline.append(at)
	g.draw_polyline(outline, Color.BLACK, 1)

## Fence posts rising out of the wall the soul was slammed into; a red strip warns first.
static func spike(g, n, b: Dictionary, box: Rect2):
	if b.age < b.warn:
		var full: Rect2 = n.spike_rect({"p":b.p, "wall":b.wall, "size":b.size, "rise":1.0})
		g.draw_rect(full, Color(1, .15, .1, .25 + .25 * sin(b.age * 50)))
		return
	var r: Rect2 = n.spike_rect(b)
	if not r.has_area():return
	g.draw_rect(r.grow_individual(-1, 0, -1, 0) if b.wall in ["down", "up"] else r.grow_individual(0, -1, 0, -1), Color.WHITE)
	var tip: Vector2
	match b.wall:
		"down":tip = Vector2(r.get_center().x, r.position.y - 3)
		"up":tip = Vector2(r.get_center().x, r.end.y + 3)
		"left":tip = Vector2(r.end.x + 3, r.get_center().y)
		_:tip = Vector2(r.position.x - 3, r.get_center().y)
	g.draw_circle(tip, 2.5, Color.WHITE)

## A ghast head: white, eyes shut while it slides in, mouth open when it fires.
static func ghast(g, bl: Dictionary):
	var fire: float = bl.get("charge", .75)
	var d := Vector2.from_angle(bl.angle)
	var width: float = bl.get("width", 11.0)
	if bl.age < fire:
		var k: float = bl.age / fire
		g.draw_line(bl.p, bl.p + d * 520, Color(1, 1, 1, .12 + .25 * k * (.5 + .5 * sin(bl.age * 50))), 1 + int(k * 2))
	else:
		var t: float = (bl.age - fire) / .55
		var wd: float = width * (1.0 + .25 * sin(bl.age * 60)) * (1.0 - t * t)
		var o: Vector2 = d.orthogonal() * wd
		var base: Vector2 = bl.p + d * 10
		g.draw_colored_polygon(PackedVector2Array([base + o * 1.5, base + o * 1.5 + d * 560, base - o * 1.5 + d * 560, base - o * 1.5]), Color(.6, .85, 1, .35 * (1 - t)))
		g.draw_colored_polygon(PackedVector2Array([base + o, base + o + d * 560, base - o + d * 560, base - o]), Color(1, 1, 1, 1 - t * .6))
	var recoil: float = 6.0 * sin(clampf((bl.age - fire) / .2, 0, 1) * PI) if bl.age > fire else 0.0
	var quake: Vector2 = g.get_meta("ut_quake", Vector2.ZERO)
	g.draw_set_transform(bl.p - d * recoil + quake, bl.angle - PI / 2, Vector2(2, 2))
	var open: float = clampf((bl.age - fire * .6) / (fire * .4), 0, 1)
	g.draw_rect(Rect2(-8, -8, 16, 16), Color(.96, .96, .96))
	g.draw_rect(Rect2(-8, -8, 16, 2), Color(.82, .82, .82))
	for x in [-5, 2]:
		if open < .5:g.draw_rect(Rect2(x, -2, 3, 1), Color(.3, .3, .3))
		else:g.draw_rect(Rect2(x, -4, 3, 4), Color(0, 0, 0))
	var mouth: float = 1.0 + open * 4.0
	g.draw_rect(Rect2(-3, 8 - mouth - 1, 6, mouth), Color(0, 0, 0) if open < .9 else Color(1, .9, .8))
	g.draw_set_transform(quake)

static func heart(g, c: Vector2, col: Color):
	var pts := PackedVector2Array([c + Vector2(0, 4), c + Vector2(-4, 0), c + Vector2(-4, -2), c + Vector2(-2, -4), c + Vector2(0, -2), c + Vector2(2, -4), c + Vector2(4, -2), c + Vector2(4, 0)])
	g.draw_colored_polygon(pts, col)

# ------------------------------------------------------------------ the lanes

static func mcfx(g, v, kind: String, at: Vector2, t: float, size: float, tint := Color.WHITE):
	var d: Dictionary = v.fx_data[kind]
	var frame: int = mini(int(d.count) - 1, int(t * d.count))
	g.draw_texture_rect_region(v.tex(d.sprite), Rect2(at - Vector2(size, size) / 2, Vector2(size, size)), Rect2(frame * d.frame[0], 0, d.frame[0], d.frame[1]), tint)

## The Minecraft explosion in 2D: puffs running their frames, then smoke.
static func mc_boom(g, v, at: Vector2, age: float, scale: float):
	if age < .18:
		var fl: float = 1.0 - age / .18
		g.draw_circle(at, (30 + age * 260) * scale, Color(1, .75, .3, .55 * fl));g.draw_circle(at, (16 + age * 120) * scale, Color(1, .97, .8, .9 * fl))
	for k in range(10):
		var t: float = age / .9
		if t >= 1:break
		var ang: float = k * 2.39996;var dist: float = (10 + t * 70 + (k % 3) * 8) * scale
		var p: Vector2 = at + Vector2(cos(ang), sin(ang) * .7) * dist + Vector2(0, t * t * 60 * scale)
		g.draw_rect(Rect2(p - Vector2(2, 2) * scale, Vector2(4, 4) * scale), [Color(.45, .3, .2), Color(.6, .1, .08), Color(.3, .3, .3)][k % 3] * Color(1, 1, 1, 1 - t))
	for k in range(5):
		var t: float = (age - .3 - k * .05) / .9
		if t >= 0 and t < 1:mcfx(g, v, "smoke", at + Vector2(sin(k * 1.9) * 18, -t * 26) * scale, t, 26 * scale, Color(.55, .55, .55, 1 - t))
	for k in range(8):
		var t: float = (age - k * .04) / .5
		if t < 0 or t >= 1:continue
		var warm: Color = Color(1, .78, .42).lerp(Color(.72, .7, .68), clampf(t * 1.6, 0, 1))
		mcfx(g, v, "explosion", at + Vector2(sin(k * 2.39996), cos(k * 2.39996) * .6) * (8 + (k % 3) * 14) * scale, t, (34 + (k % 2) * 14) * scale, warm)

static func lanes(g):
	var w = g.world;var n = w.notch;var v = view(g)
	var T = func(name: String) -> Texture2D:return v.tex(name)
	g.draw_rect(Rect2(0, 0, 640, 360), Color(.42, .62, .9))
	for i in range(6):
		var cx: float = fposmod(i * 131.0 + w.clock * 6.0, 760.0) - 60
		g.draw_rect(Rect2(cx, 64 + (i % 3) * 6, 48, 10), Color(1, 1, 1, .85));g.draw_rect(Rect2(cx + 10, 58 + (i % 3) * 6, 26, 8), Color(1, 1, 1, .85))
	var top: float = n.LANE_ORIGIN.y;var bottom: float = n.LANE_ORIGIN.y + n.ROWS * n.CELL.y
	var right: float = n.LANE_ORIGIN.x + n.COLS * n.CELL.x
	g.draw_texture_rect(T.call("ch5p_cobblestone"), Rect2(right, top - 12, 640 - right, bottom - top + 24), true, Color(.75, .75, .8))
	g.draw_texture_rect(T.call("ch5p_dirt"), Rect2(0, bottom, 640, 360 - bottom), true, Color(.8, .7, .6))
	for c in range(n.COLS):
		for r in range(n.ROWS):
			var rect: Rect2 = n.cell_rect(Vector2i(c, r))
			g.draw_texture_rect(T.call("ch5p_grass"), rect, true, Color(1.08, 1.08, 1.0) if (r + c) % 2 == 0 else Color(.86, .9, .82))
	g.draw_rect(Rect2(n.LANE_ORIGIN.x, top - 3, right - n.LANE_ORIGIN.x, 3), Color(0, 0, 0, .25))
	for x in range(int(n.LANE_ORIGIN.x), int(right), 18):
		g.draw_texture_rect_region(T.call("ch5p_oak_planks"), Rect2(x, top - 18, 4, 16), Rect2(6, 0, 4, 16))
	g.draw_texture_rect_region(T.call("ch5p_oak_planks"), Rect2(n.LANE_ORIGIN.x, top - 14, right - n.LANE_ORIGIN.x, 3), Rect2(0, 6, 16, 3))
	# The house: planks, logs, a window and the door the zombies want.
	var house := Rect2(0, top - 34, 66, bottom - top + 44)
	g.draw_texture_rect(T.call("ch5p_oak_planks"), house, true)
	g.draw_texture_rect(T.call("ch5p_oak_log"), Rect2(56, house.position.y, 12, house.size.y), true)
	g.draw_texture_rect(T.call("ch5p_glass"), Rect2(14, top + 10, 32, 32), true)
	g.draw_texture_rect(T.call("ch5p_oak_door_top"), Rect2(18, top + 120, 24, 24), false);g.draw_texture_rect(T.call("ch5p_oak_door_bottom"), Rect2(18, top + 144, 24, 24), false)
	g.draw_texture_rect(T.call("ch5p_bricks"), Rect2(0, top - 50, 70, 18), true)
	g.draw_texture_rect(T.call("ch5p_dirt"), Rect2(66, top - 18, n.LANE_ORIGIN.x - 66, bottom - top + 18), true, Color(.85, .75, .62))
	# Steve watches from the ground path below the minecart track.
	g.draw_actor("steve", Vector2(84, bottom + 22), Vector2.RIGHT, w.clock, false, Color.WHITE, "idle", 1.0, {"state":"idle", "time":w.clock})
	for r in range(n.ROWS):
		var y: float = n.row_y(r)
		g.draw_texture_rect(T.call("ch5p_rail"), Rect2(66, y + 2, 46, 16), true, Color(.95, .95, .95))
		var cart: Dictionary = n.carts[r]
		if cart.state != "used":
			g.oval(Vector2(cart.x + 12, y + 16), Vector2(12, 3), Color(0, 0, 0, .3))
			g.draw_texture_rect(T.call("ch5p_item_minecart"), Rect2(cart.x, y - 6, 24, 24), false)
	# Notch on a stack of command blocks, throwing the next one.
	for k in range(3):g.draw_texture_rect(g.textures.icon_command_block, Rect2(590, 210 + k * 30, 30, 30), false)
	figure(g, n.pose, n.pose_age, Vector2(605, 212), Vector2.LEFT, 1.5)
	glow(g, Vector2(605, 212), 1.5, w.clock)
	var items: Array = []
	for c in n.plants:items.append({"y":n.row_y(c.y), "kind":"plant", "c":c})
	for z in n.zombies:items.append({"y":n.row_y(z.row) + .5, "kind":"zombie", "z":z})
	for cp in n.corpses:items.append({"y":n.row_y(cp.row) + .4, "kind":"corpse", "z":cp})
	items.sort_custom(func(a2, b2):return a2.y < b2.y)
	var cr: Rect2 = n.cell_rect(n.cursor)
	g.draw_rect(cr.grow(-1), Color(1, 1, 1, .18 + .1 * sin(w.clock * 6)))
	for it in items:
		match it.kind:
			"plant":
				var c: Vector2i = it.c;var pl: Dictionary = n.plants[c];var rect: Rect2 = n.cell_rect(c);var base := rect.get_center() + Vector2(0, 12)
				var kick: float = clampf(pl.timer - 1.3, 0, .2) * 20.0 if pl.kind == "dispenser" else 0.0
				var pulse: float = float(pl.get("pulse", 0.0));pl.pulse = maxf(0, pulse - 1.0 / 60.0)
				g.oval(base, Vector2(14, 4), Color(0, 0, 0, .35))
				var tint := Color(1.7, 1.7, 1.7) if pl.kind == "tnt" and int(pl.timer * 12) % 2 == 0 else Color(1 + pulse, 1, 1)
				match pl.kind:
					"magma":
						var heat: float = .55 + .25 * sin(w.clock * 3 + c.x)
						g.draw_texture_rect(v.tex("ch5p_magma"), rect.grow(-4), true, Color(1, 1, 1))
						g.draw_rect(rect.grow(-4), Color(1, .45, .1, heat * .35))
						for k in range(4):
							var t: float = fposmod(w.clock * .7 + k * .25, 1.0)
							g.draw_rect(Rect2(rect.position + Vector2(10 + k * 9, rect.size.y - 8 - t * 26), Vector2(2, 2)), Color(.3, .3, .3, .6 * (1 - t)))
					"snow_golem":
						var bob: float = -absf(sin(w.clock * 2.0 + c.y)) * 1.5
						g.draw_texture_rect(g.textures.icon_pvz_snow_golem, Rect2(base - Vector2(20 + kick, 46 - bob), Vector2(40, 48)), false, tint)
					"piston":
						var ext: float = clampf(pl.push / .3, 0, 1) * 16.0
						if ext > 0:
							g.draw_rect(Rect2(base + Vector2(8, -20), Vector2(ext, 4)), Color(.55, .45, .3))
							g.draw_texture_rect(v.tex("ch5p_piston_top"), Rect2(base + Vector2(6 + ext, -30), Vector2(6, 24)), false)
						g.draw_texture_rect(g.textures.icon_pvz_piston, Rect2(base - Vector2(16, 30), Vector2(32, 32)), false, tint)
					"cactus":
						g.draw_texture_rect(g.textures.icon_pvz_cactus, Rect2(base - Vector2(14, 44), Vector2(28, 28)), false, tint)
						g.draw_texture_rect(g.textures.icon_pvz_cactus, Rect2(base - Vector2(14, 26), Vector2(28, 28)), false, tint)
					_:
						g.draw_texture_rect(g.textures["icon_pvz_" + pl.kind], Rect2(base - Vector2(16 + kick, 30), Vector2(32, 32)), false, tint)
				if pl.kind == "redstone_ore":
					for k in range(3):
						var t: float = fposmod(w.clock * .8 + k * .33, 1.0)
						g.draw_rect(Rect2(base + Vector2(-10 + k * 9, -30 - t * 14), Vector2(2, 2)), Color(1, .15, .1, 1 - t))
				if pl.kind == "obsidian" and pl.hp < n.PLANT_HP.obsidian:
					var dmg: float = 1.0 - pl.hp / n.PLANT_HP.obsidian
					for k in range(int(dmg * 5)):g.draw_line(base + Vector2(-8 + k * 4, -26), base + Vector2(-4 + k * 3, -12 - k * 2), Color(.6, .5, .8), 1)
				elif pl.hp < n.PLANT_HP[pl.kind] and pl.kind not in ["tnt", "magma"]:
					g.draw_rect(Rect2(rect.position + Vector2(10, rect.size.y - 4), Vector2((rect.size.x - 20) * pl.hp / n.PLANT_HP[pl.kind], 2)), Color(.95, .3, .25))
			"zombie", "corpse":
				var z: Dictionary = it.z
				var q := Vector2(z.x, n.row_y(z.row) + 14)
				var kind: String = {"zombie":"zombie", "elite":"elite", "glitch":"zombie", "creeper":"creeper", "baby":"zombie", "spider":"spider", "slime":"slime", "small_slime":"small_slime", "vindicator":"vindicator", "skeleton":"skeleton", "ravager":"ravager"}.get(z.kind, "zombie")
				var size_k: float = {"baby":.8, "ravager":.85, "spider":1.0, "slime":1.3, "small_slime":1.6}.get(z.kind, 1.2)
				if z.get("air", false):q.y -= sin(clampf(z.jump / .55, 0, 1) * PI) * 30
				if it.kind == "corpse":
					var k: float = minf(1.0, z.age / .4)
					g.draw_set_transform(q, -k * PI / 2, Vector2.ONE)
					g.draw_actor(kind, Vector2.ZERO, Vector2.LEFT, 0.0, false, Color(1, 1, 1, 1 - clampf((z.age - .6) / .6, 0, 1)), "hurt", size_k, {"state":"hurt", "time":.1})
					g.draw_set_transform(Vector2.ZERO)
					continue
				var tint := Color(1.8, 1.8, 1.8) if z.flash > 0 else (Color(.6, 1, 1) if z.kind == "glitch" else Color.WHITE)
				if z.get("slow", 0.0) > 0 and z.flash <= 0:tint = Color(.6, .8, 1.3)
				if z.get("burn", 0.0) > 0 and z.flash <= 0:tint = Color(1.4, .8, .5)
				g.oval(Vector2(q.x, n.row_y(z.row) + 14), Vector2(10, 3), Color(0, 0, 0, .35))
				g.draw_actor(kind, q, Vector2.LEFT, z.age, z.get("moving", true), tint, "walk", size_k, z.visual)
				if z.get("slow", 0.0) > 0:
					for k in range(3):g.draw_rect(Rect2(q + Vector2(-8 + k * 7, -30 + sin(w.clock * 5 + k) * 3), Vector2(2, 2)), Color(.85, .95, 1, .8))
				if z.kind == "glitch" and int(w.clock * 12) % 3 == 0:g.draw_rect(Rect2(q + Vector2(-6, -32), Vector2(8, 8)), Color(.97, 0, .86))
				if z.hp < z.max:g.draw_rect(Rect2(q + Vector2(-10, -40), Vector2(20 * z.hp / z.max, 2)), Color(.95, .3, .25))
	g.draw_rect(cr.grow(-1), Color(1, 1, .6, .6 + .3 * sin(w.clock * 6)), false, 2)
	for a2 in n.arrows:
		var y: float = n.row_y(a2.row) - 4
		if a2.get("snow", false):
			g.draw_texture_rect(v.tex("ch5p_item_snowball"), Rect2(a2.x - 6, y - 6, 12, 12), false);continue
		g.draw_set_transform(Vector2(a2.x, y), PI / 4, Vector2.ONE)
		g.draw_texture_rect(v.tex("ch5p_item_arrow"), Rect2(-8, -8, 16, 16), false)
		g.draw_set_transform(Vector2.ZERO)
	for b2 in n.bone_arrows:
		g.draw_set_transform(Vector2(b2.x, n.row_y(b2.row) - 6), PI / 4 + PI, Vector2.ONE)
		g.draw_texture_rect(v.tex("ch5p_item_arrow"), Rect2(-8, -8, 16, 16), false)
		g.draw_set_transform(Vector2.ZERO)
	for bl in n.blasts:mc_boom(g, v, bl.p, bl.age, 1.0)
	for d in n.drops:
		var p: Vector2 = d.p + Vector2(0, sin(w.clock * 4 + d.p.x) * 1.5 if not d.taken else 0.0)
		g.draw_circle(p, 9, Color(1, .1, .05, .25))
		g.draw_texture_rect(v.tex("ch5p_item_redstone"), Rect2(p - Vector2(8, 8), Vector2(16, 16)), false, Color(1, 1, 1, 1 - d.age * 2.0 if d.taken else 1.0))
	# Seed packets.
	g.draw_rect(Rect2(8, 4, 92, 52), Color(.32, .2, .1));g.draw_rect(Rect2(8, 4, 92, 52), Color(.15, .08, .03), false, 2)
	g.draw_texture_rect(v.tex("ch5p_item_redstone"), Rect2(14, 10, 32, 32), false)
	g.draw_string(g.bold, Vector2(50, 36), str(n.redstone), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, YELLOW)
	for i in range(n.CARDS.size()):
		var r: Rect2 = n.card_rect(i)
		var spec: Array = n.CARDS[i]
		var ready: bool = n.card_ready[i] <= 0 and n.redstone >= int(spec[1])
		var on: bool = n.card == i
		if on:r.position.y -= 3
		g.draw_rect(r, Color(.88, .8, .58) if ready else Color(.55, .5, .4))
		g.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y - 16)), Color(.62, .78, .52) if ready else Color(.4, .45, .38))
		var isz: Vector2 = Vector2(20, 24) if spec[0] == "snow_golem" else Vector2(24, 24)
		g.draw_texture_rect(g.textures["icon_pvz_" + spec[0]], Rect2(r.position + Vector2(r.size.x / 2 - isz.x / 2, 6), isz), false, Color.WHITE if ready else Color(.5, .5, .5))
		var cost: String = str(spec[1])
		g.draw_string(g.bold, r.position + Vector2(r.size.x / 2 - g.bold.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x / 2, r.size.y - 4), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.2, .1, .05))
		g.draw_rect(r, YELLOW if on else Color(.35, .22, .1), false, 2)
		g.draw_string(g.font, r.position + Vector2(3, 10), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.2, .1, .05, .7))
		if n.card_ready[i] > 0:g.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * n.card_ready[i] / float(spec[2]))), Color(0, 0, 0, .45))
	var left: int = n.schedule.size() + n.zombies.size()
	g.draw_rect(Rect2(488, 14, 140, 14), Color(0, 0, 0, .5))
	var total: float = maxf(1.0, float(n.lane_total))
	g.draw_rect(Rect2(490, 16, 136 * clampf(1.0 - left / total, 0, 1), 10), Color(.4, .85, .3))
	g.text_at("Волна", Vector2(490, 42), 8, Color(1, 1, 1, .8), true)
	g.text_at("1–8 блок · стрелки/мышь клетка · Пробел поставить · наведи на редстоун — собрать", Vector2(112, 352), 8, Color(1, 1, 1, .7))
	subtitles(g, n, 300.0)
	retry(g, n)

# ------------------------------------------------------------------ 3D phases

static func view(g):
	if not g.has_meta("ch5_view3d"):
		var v = load("res://scripts/chapter_five_view3d.gd").new()
		g.add_child(v);g.set_meta("ch5_view3d", v)
	return g.get_meta("ch5_view3d")

static func release(g):
	if g.has_meta("ch5_view3d"):
		var v = g.get_meta("ch5_view3d")
		if is_instance_valid(v):v.release();v.queue_free()
		g.remove_meta("ch5_view3d")

static func fighter(g):
	var w = g.world;var n = w.notch;var fi = n.fighter
	var v = view(g);v.ensure(g, "fighter", Vector2i(640, 360));v.sync_fighter(fi)
	var shake: Vector2 = Vector2(round(sin(w.clock * 70) * 3), round(cos(w.clock * 61) * 2)) * (n.shake3d / .4) if g.settings.shake else Vector2.ZERO
	g.draw_texture_rect(v.viewport.get_texture(), Rect2(shake, Vector2(640, 360)), false)
	fight_hud(g, fi, v)
	if fi.state != "fatality":g.text_at("←/→ ход · ↑ прыжок · назад — блок · Пробел/E удары · Q(+стрелка) приём · F бросок · R супер · Esc — приёмы", Vector2(14, 352), 8, Color(1, 1, 1, .4))
	subtitles(g, n, 300.0)
	retry(g, n)

static func fight_hud(g, fi, v):
	if fi.state == "fatality":
		fight_banner(g, fi);return
	var s: Dictionary = fi.steve();var nt: Dictionary = fi.notch()
	var skins := ["ch5_skin_steve", "ch5_skin_notch"]
	for i in range(2):
		var f: Dictionary = fi.fighters[i]
		var right: bool = i == 1
		var face := Rect2(8 if not right else 596, 10, 36, 36)
		g.draw_rect(face.grow(2), Color(0, 0, 0, .8));g.draw_texture_rect_region(v.tex(skins[i]), face, Rect2(8, 8, 8, 8), Color(1, .6, .6) if f.flash > 0 else Color.WHITE)
		g.draw_rect(face.grow(2), YELLOW, false, 1)
		bar(g, Rect2(52 if not right else 356, 16, 232, 14), f.hp / f.max, right)
		var name: String = "STEVE" if not right else "NOTCH"
		var nx: float = 52.0 if not right else 588.0 - g.bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		g.text_at(name, Vector2(nx, 50), 16, Color.WHITE, true)
		if fi.mode == "fight":
			for k in range(2):
				var mx: float = (238 + k * 14) if not right else (390 - k * 14)
				var won: bool = fi.wins[i] > k
				g.draw_colored_polygon(PackedVector2Array([Vector2(mx, 38), Vector2(mx + 5, 43), Vector2(mx, 48), Vector2(mx - 5, 43)]), Color(.4, 1, .9) if won else Color(.15, .15, .2))
			var m := Rect2(52 if not right else 444, 332, 144, 6)
			g.draw_rect(m.grow(1), Color(0, 0, 0, .8));g.draw_rect(Rect2(m.position + Vector2(m.size.x * (1 - f.meter / 100.0) if right else 0.0, 0), Vector2(m.size.x * f.meter / 100.0, m.size.y)), Color(.3, .7, 1) if f.meter < 100 else Color(1, .9, .3, .6 + .4 * sin(fi.age * 10)))
			g.text_at("СУПЕР" if f.meter >= 100 else "", Vector2(m.position.x, m.position.y - 3), 8, YELLOW, true)
		if f.combo >= 2 and f.combo_t > 0:
			var cx: float = 60.0 if not right else 500.0
			g.draw_string(g.bold, Vector2(cx + 2, 112), "%d УДАРА" % f.combo if f.combo < 5 else "%d УДАРОВ" % f.combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, .8))
			g.draw_string(g.bold, Vector2(cx, 110), "%d УДАРА" % f.combo if f.combo < 5 else "%d УДАРОВ" % f.combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, .8, .2) if not right else Color(.4, 1, .9))
	if fi.mode == "fight":
		g.draw_rect(Rect2(298, 12, 44, 26), Color(0, 0, 0, .7))
		g.centered(str(int(ceil(fi.clock))), 32, 16, Color(1, .3, .3) if fi.clock < 10 else Color.WHITE, true)
	if s.cool > 0 and fi.mode == "fight":
		g.draw_rect(Rect2(52, 62, 60, 3), Color(0, 0, 0, .6));g.draw_rect(Rect2(52, 62, 60 * (1 - minf(1.0, s.cool / 4.0)), 3), Color(1, .4, .3))
	fight_banner(g, fi)

static func fight_banner(g, fi):
	if fi.announce_age < 2.2 and not fi.announce.is_empty():
		var k: float = clampf(fi.announce_age / .15, 0, 1) * clampf((2.2 - fi.announce_age) / .4, 0, 1)
		var size: int = 48 if fi.announce == "FATALITY" else 32
		var col: Color = Color(1, .25, .2, k) if fi.announce in ["K.O.", "ДОБЕЙ ЕГО!", "FATALITY"] else Color(1, .88, .3, k)
		var wd: float = g.bold.get_string_size(fi.announce, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var pos := Vector2((640 - wd) / 2, 176 + (1 - clampf(fi.announce_age / .15, 0, 1)) * 20)
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(3, 3)]:
			g.draw_string(g.bold, pos + o, fi.announce, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, k))
		g.draw_string(g.bold, pos, fi.announce, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	if fi.hitstop > .08 and g.settings.flashes:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, .08))
	if fi.state == "fatality" and fi.age > 1.3 and fi.age < 1.45 and g.settings.flashes:g.draw_rect(Rect2(0, 0, 640, 360), Color(.85, .9, 1, .7))
	if fi.state in ["finish", "fatality"]:
		var bars: float = 26.0 * clampf(fi.age / .4, 0, 1)
		g.draw_rect(Rect2(0, 0, 640, bars), Color.BLACK);g.draw_rect(Rect2(0, 360 - bars, 640, bars), Color.BLACK)
	if fi.state == "finish":
		var left: float = fi.FINISH_TIME - fi.age
		g.centered("%.1f" % maxf(0, left), 64, 16, Color(1, .3, .25), true)
	if fi.paused:move_menu(g, fi)
	elif fi.mode == "fight" and fi.state in ["intro", "fight"]:
		g.text_at("Esc — приёмы и комбо", Vector2(520, 70), 8, Color(1, 1, 1, .45))

## The MK-style pause menu: move list, combos and the fatality.
static func move_menu(g, fi):
	g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, .72))
	var panel := Rect2(40, 24, 560, 312)
	g.draw_rect(panel, Color(.06, .03, .02, .96))
	g.draw_rect(panel, Color(.75, .55, .2), false, 2);g.draw_rect(panel.grow(-4), Color(.35, .2, .08), false, 1)
	var title := "СПИСОК ПРИЁМОВ — STEVE"
	g.draw_string(g.bold, Vector2(320 - g.bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / 2, 50), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, .82, .3))
	g.draw_line(Vector2(60, 58), Vector2(580, 58), Color(.75, .55, .2, .6), 1)
	var y := 72.0
	for m in fi.MOVE_LIST:
		g.draw_string(g.font, Vector2(60, y), m[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, .95, .85))
		g.draw_string(g.bold, Vector2(208, y), m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, .75, .25))
		g.draw_string(g.font, Vector2(340, y), m[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.75, .7, .62))
		y += 11.0
	y += 4.0
	g.draw_string(g.bold, Vector2(60, y), "КОМБО", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, .82, .3));y += 11.0
	for c in fi.COMBOS:
		g.draw_string(g.font, Vector2(60, y), c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, .95, .85))
		g.draw_string(g.bold, Vector2(160, y), c[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.5, .95, 1))
		y += 11.0
	y += 4.0
	g.draw_string(g.bold, Vector2(60, y), "ФАТАЛИТИ", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, .25, .2))
	g.draw_string(g.bold, Vector2(160, y), fi.FATALITY_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, .45, .35))
	g.draw_string(g.font, Vector2(60, 326), "Esc — продолжить бой   ·   Backspace — меню паузы", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, .6))

static func bar(g, r: Rect2, k: float, mirror: bool):
	g.draw_rect(r.grow(2), Color(0, 0, 0, .8))
	g.draw_rect(r, Color(.5, .05, .05))
	var wd: float = r.size.x * clampf(k, 0, 1)
	g.draw_rect(Rect2(r.position + Vector2(r.size.x - wd if mirror else 0.0, 0), Vector2(wd, r.size.y)), YELLOW)
	g.draw_rect(r.grow(2), Color(1, 1, 1, .8), false, 1)

static func quake(g):
	var w = g.world;var n = w.notch;var qk = n.quake
	var v = view(g);v.ensure(g, "quake", Vector2i(320, 180));v.sync_quake(qk)
	g.draw_texture_rect(v.viewport.get_texture(), Rect2(0, 0, 640, 360), false)
	var s: Dictionary = qk.steve()
	if s.flash > 0:g.draw_rect(Rect2(0, 0, 640, 360), Color(.8, 0, 0, s.flash * 1.5))
	if s.quad > 0:g.draw_rect(Rect2(0, 0, 640, 360), Color(.2, .3, 1, .12))
	var cc := Vector2(320, 180)
	var spread: float = 3.0 + s.fired * 20.0
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:g.draw_line(cc + d * spread, cc + d * (spread + 5), Color.WHITE, 1)
	if s.hitmark > 0:
		var a: float = s.hitmark / .25
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:g.draw_line(cc + d * 5, cc + d * 10, Color(1, .3, .3, a), 2)
	var cam: Camera3D = v.nodes.cam
	for nm in qk.numbers:
		if cam.is_position_behind(nm.p):continue
		var sp: Vector2 = cam.unproject_position(nm.p) * 2.0
		g.draw_string(g.bold, sp + Vector2(1, 1), str(nm.value), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 1 - nm.age / .8))
		g.draw_string(g.bold, sp, str(nm.value), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, .85, .3, 1 - nm.age / .8))
	g.draw_rect(Rect2(0, 316, 640, 44), Color(.16, .1, .06))
	for x in range(0, 640, 32):g.draw_rect(Rect2(x, 316, 31, 43), Color(.2, .13, .08))
	g.draw_line(Vector2(0, 316), Vector2(640, 316), Color(.45, .3, .15), 2)
	var skin: Texture2D = v.tex("ch5_skin_steve")
	g.draw_texture_rect_region(skin, Rect2(222, 320, 36, 36), Rect2(8, 8, 8, 8), Color(1, .6 + .4 * minf(1.0, s.hp / 100.0), .6 + .4 * minf(1.0, s.hp / 100.0)))
	big(g, str(int(s.armor)), Vector2(56, 352), Color(.8, .8, .8))
	g.draw_texture_rect(v.tex("ch5q_item_iron_chestplate"), Rect2(14, 324, 32, 32), false)
	big(g, str(int(s.hp)), Vector2(270, 352), Color(1, .35, .3) if s.hp < 25 else YELLOW)
	var icons := {"pickaxe":"ch5q_item_diamond_pickaxe", "charges":"ch5q_item_fire_charge", "rockets":"ch5q_item_tnt_minecart", "crossbow":"ch5q_item_crossbow_standby"}
	for i in range(qk.ORDER.size()):
		var wpn: String = qk.ORDER[i]
		var r := Rect2(372 + i * 46, 320, 40, 36)
		var owned: bool = s.owned.get(wpn, false)
		var on: bool = s.weapon == wpn
		g.draw_rect(r, Color(.3, .2, .1) if on else Color(.12, .08, .05))
		g.draw_rect(r, YELLOW if on else Color(.45, .3, .15), false, 2 if on else 1)
		g.draw_texture_rect(v.tex(icons[wpn]), Rect2(r.position + Vector2(4, 2), Vector2(22, 22)), false, Color.WHITE if owned else Color(.25, .25, .25))
		g.draw_string(g.font, r.position + Vector2(30, 11), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, .6))
		var ammo: int = qk.ammo_of(s, wpn)
		g.draw_string(g.bold, r.position + Vector2(4, 33), "∞" if wpn == "pickaxe" else str(ammo), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, YELLOW if owned and ammo > 0 else Color(.6, .4, .3))
	g.text_at(qk.WEAPONS[s.weapon].name, Vector2(372, 312), 8, Color(1, .9, .6), true)
	var nt: Dictionary = qk.notch()
	g.draw_rect(Rect2(460, 6, 174, 18), Color(0, 0, 0, .55))
	g.text_at("Стив %d : %d Нотч · до %d" % [s.frags, nt.frags, qk.FRAGS], Vector2(468, 19), 8, Color.WHITE, true)
	for i in range(qk.feed.size()):g.text_at(qk.feed[i].text, Vector2(10, 18 + i * 12), 8, Color(1, .9, .6, 1 - qk.feed[i].age / 5.0))
	if s.quad > 0:g.text_at("QUAD %d" % int(ceil(s.quad)), Vector2(10, 300), 16, Color(.5, .6, 1), true)
	if s.hp > 100:g.text_at("МЕГА", Vector2(222, 312), 8, Color(1, .85, .3), true)
	if s.dead > 0:g.centered("Ты убит. Возрождение…", 150, 16, Color(1, .3, .3), true)
	if qk.state == "intro":g.centered("ДЕЗМАТЧ · ДО 3 ФРАГОВ", 120, 16, Color(1, .8, .3), true)
	if qk.age < 7.0:g.text_at("WASD · мышь — обзор · ЛКМ огонь · Пробел прыжок · 1–4 или колесо — оружие · стрейф в прыжке разгоняет", Vector2(14, 300), 8, Color(1, 1, 1, .55 * (1 - qk.age / 7.0)))
	subtitles(g, n, 280.0)
	retry(g, n)

static func big(g, text: String, at: Vector2, c: Color):
	g.draw_string(g.bold, at + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0, 0, 0, .8))
	g.draw_string(g.bold, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, c)

# ------------------------------------------------------------------ the code duel

const KEYWORDS := ["for", "int", "if", "else", "while", "let", "in", "range", "len", "def", "void", "function", "return"]

static func code_line(g, text: String, at: Vector2, size: int, dim := false):
	var x: float = at.x
	var word := ""
	var parts: Array = []
	for c in text + " ":
		if c.is_valid_identifier() or c.is_valid_int() or c == "_":word += c
		else:
			if not word.is_empty():parts.append(word);word = ""
			parts.append(c)
	for p in parts:
		var col := Color(.85, .87, .92)
		if p in KEYWORDS:col = Color(.85, .55, 1)
		elif p.is_valid_int():col = Color(.6, .9, .6)
		elif p in ["{", "}", "(", ")", "[", "]"]:col = Color(.95, .8, .4)
		if dim:col.a = .5
		g.draw_string(g.font, Vector2(x, at.y), p, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += g.font.get_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

static func code(g):
	var w = g.world;var n = w.notch;var f = n.finale
	g.draw_rect(Rect2(0, 0, 640, 360), Color(.03, .035, .05))
	if f.phase == "pick":
		g.centered("Последняя игра: пузырьковая сортировка", 70, 16, Color.WHITE, true)
		g.centered("Успей раньше Нотча.", 92, 8, Color(1, 1, 1, .6))
		for i in range(f.LANGS.size()):
			var r := Rect2(130 + i * 132, 130, 116, 40)
			var on: bool = i == f.lang_index
			g.draw_rect(r, Color(.1, .12, .16));g.draw_rect(r, YELLOW if on else Color(.4, .4, .5), false, 2 if on else 1)
			g.draw_string(g.bold, r.position + Vector2((r.size.x - g.bold.get_string_size(f.LANG_NAMES[f.LANGS[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) / 2, 27), f.LANG_NAMES[f.LANGS[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, YELLOW if on else Color.WHITE)
		for i in range(2):
			var r := Rect2(150 + i * 176, 196, 164, 52)
			var on: bool = f.advanced == (i == 1)
			g.draw_rect(r, Color(.1, .12, .16));g.draw_rect(r, YELLOW if on else Color(.4, .4, .5), false, 2 if on else 1)
			g.draw_string(g.bold, r.position + Vector2(10, 20), ["Новичок", "Не новичок"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, YELLOW if on else Color.WHITE)
			g.draw_string(g.font, r.position + Vector2(10, 38), ["собрать из строк · 55 с", "написать самому · 3 мин"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, .6))
		g.centered("←/→ — язык · ↑/↓ — режим · Пробел — начать", 290, 8, Color(1, 1, 1, .45))
		retry(g, n);return
	var lang: String = f.lang()
	var header: Array = f.HEADERS[lang]
	var left := Rect2(14, 40, 380, 270)
	var right := Rect2(404, 40, 222, 270)
	g.draw_rect(left, Color(.06, .065, .09));g.draw_rect(left, Color(.3, .35, .45), false, 1)
	g.draw_rect(right, Color(.06, .065, .09));g.draw_rect(right, Color(.3, 1, .9, .5), false, 1)
	g.text_at("steve." + {"java":"java", "python":"py", "js":"js"}[lang], left.position + Vector2(6, -6), 8, Color(1, 1, 1, .7))
	g.text_at("notch.java", right.position + Vector2(6, -6), 8, Color(.3, 1, .9, .8))
	var y: float = left.position.y + 16
	code_line(g, header[0], Vector2(left.position.x + 8, y), 8, true);y += 12
	var indent: float = 16.0
	if f.advanced:
		for i in range(f.editor.size()):
			code_line(g, f.editor[i], Vector2(left.position.x + 8 + indent, y + i * 12), 8)
			if i == f.row and int(w.clock * 2.5) % 2 == 0:
				var cx: float = left.position.x + 8 + indent + g.font.get_string_size(f.editor[i].substr(0, f.col), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
				g.draw_rect(Rect2(cx, y + i * 12 - 9, 1, 11), Color.WHITE)
		y += f.editor.size() * 12
	else:
		var sol: Array = f.SOLUTIONS[lang]
		for i in f.built:
			code_line(g, sol[i], Vector2(left.position.x + 8 + indent, y), 8);y += 12
		g.draw_rect(Rect2(left.position.x + 8 + indent, y - 9, 140, 11), Color(1, 1, 1, .06 + .05 * sin(w.clock * 5)))
		y += 12
	if not header[1].is_empty():code_line(g, header[1], Vector2(left.position.x + 8, y), 8, true)
	if not f.advanced:
		var sol: Array = f.SOLUTIONS[lang]
		var by := 214.0
		g.text_at("Следующая строка (↑/↓ + Пробел или 1–9):", Vector2(left.position.x + 8, left.end.y - 8 - f.pool.size() * 12 - 6), 8, Color(1, 1, 1, .5))
		for i in range(f.pool.size()):
			var py: float = left.end.y - 8 - (f.pool.size() - 1 - i) * 12
			var on: bool = i == f.pool_choice
			if on:g.draw_rect(Rect2(left.position.x + 4, py - 9, left.size.x - 8, 11), Color(1, .9, .3, .15))
			g.draw_string(g.font, Vector2(left.position.x + 8, py), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, YELLOW)
			code_line(g, sol[f.pool[i]].strip_edges(), Vector2(left.position.x + 24, py), 8)
		if f.wrong_flash > 0:g.draw_rect(left, Color(1, .2, .2, f.wrong_flash * .5))
	else:
		var rb := Rect2(520, 326, 100, 22)
		g.draw_rect(rb, Color(.1, .3, .15));g.draw_rect(rb, Color(.3, 1, .5), false, 1)
		g.draw_string(g.bold, rb.position + Vector2(10, 15), "Запуск · F5", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.4, 1, .6))
		g.text_at("Массив — a. Сортируй на месте. Ctrl+Enter или F5 — запуск.", Vector2(14, 340), 8, Color(1, 1, 1, .45))
	var shown: int = int(f.NOTCH_CODE.length() * f.notch_progress)
	var lines: PackedStringArray = f.NOTCH_CODE.substr(0, shown).split("\n")
	for i in range(lines.size()):code_line(g, lines[i], Vector2(right.position.x + 6, right.position.y + 16 + i * 12), 8)
	g.draw_rect(Rect2(right.position.x, right.end.y + 6, right.size.x, 6), Color(0, 0, 0, .6))
	g.draw_rect(Rect2(right.position.x, right.end.y + 6, right.size.x * f.notch_progress, 6), Color(.3, 1, .9))
	figure(g, "snap" if f.notch_progress > .9 else "idle", n.age, right.get_center() + Vector2(60, 110), Vector2.LEFT, 1.0)
	var secs: int = int(ceil(f.duration() * (1 - f.notch_progress)))
	g.centered("%d:%02d" % [secs / 60, secs % 60], 26, 16, Color(1, .4, .3) if secs < 10 else Color.WHITE, true)
	if not f.result.is_empty():
		g.draw_rect(Rect2(14, 314, 500, 14), Color(0, 0, 0, .7))
		g.text_at(f.result, Vector2(18, 325), 8, Color(.4, 1, .5) if f.result_ok else Color(1, .4, .35))
	subtitles(g, n, 296.0)
	retry(g, n)

# ------------------------------------------------------------------ the erasure

static func erase(g):
	var w = g.world;var n = w.notch;var f = n.finale
	var v = view(g);v.ensure(g, "erase", Vector2i(640, 360));v.sync_erase(f, w.clock)
	g.draw_texture_rect(v.viewport.get_texture(), Rect2(0, 0, 640, 360), false)
	g.draw_rect(Rect2(0, 0, 640, 24), Color.BLACK);g.draw_rect(Rect2(0, 336, 640, 24), Color.BLACK)
	if f.age < .8:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 1 - f.age / .8))
	if f.thrown >= 0:
		# letterbox closes in for the throw; speed lines while the blade flies; impact frame on the hit
		var bars: float = 24 + 18 * smoothstep(0, .4, f.thrown) * (1 - smoothstep(3.6, 4.4, f.thrown))
		g.draw_rect(Rect2(0, 0, 640, bars), Color.BLACK);g.draw_rect(Rect2(0, 360 - bars, 640, bars), Color.BLACK)
		if f.thrown >= .56 and f.thrown < 1.0:
			var k: float = (f.thrown - .56) / .44
			for i in range(22):
				var a: float = i * 2.39996;var d := Vector2(cos(a), sin(a) * .6)
				var r0: float = 120 + fmod(i * 37.0 + f.thrown * 900.0, 200.0)
				g.draw_line(Vector2(320, 170) + d * r0, Vector2(320, 170) + d * (r0 + 40 + 60 * k), Color(1, 1, 1, .35 * k), 1)
		if f.thrown >= 1.0 and f.thrown < 1.12 and g.settings.flashes:
			g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, .9))
			g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, .55 if int(f.thrown * 60) % 2 == 0 else 0.0))
		elif f.thrown >= 1.12 and f.thrown < 1.5 and g.settings.flashes:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, .5, .3, (1.5 - f.thrown) * .9))
	if f.erase > .05 and f.thrown < 0:
		for i in range(int(f.erase * 10)):
			var y: float = fmod(i * 47.0 + w.clock * 300.0, 312.0) + 24
			g.draw_rect(Rect2(0, y, 640, 2), Color(.97, 0, .86, .18))
	if f.thrown < 0:
		g.centered("Пробел — держаться!", 318, 16, Color(1, 1, 1, .6 + .4 * sin(w.clock * 8)), true)
		g.draw_rect(Rect2(220, 324, 200, 4), Color(0, 0, 0, .6));g.draw_rect(Rect2(220, 324, 200 * clampf(f.presses / 14.0, 0, 1), 4), Color(.4, 1, .6))
	subtitles(g, n, 30.0)

# ------------------------------------------------------------------ brawl, chair, flight

static func fists(g):
	var w = g.world;var n = w.notch;var fi = n.fighter
	var v = view(g);v.ensure(g, "fists", Vector2i(640, 360));v.sync_fighter(fi)
	var shake: Vector2 = Vector2(round(sin(w.clock * 70) * 3), round(cos(w.clock * 61) * 2)) * (n.shake3d / .4) if g.settings.shake else Vector2.ZERO
	g.draw_texture_rect(v.viewport.get_texture(), Rect2(shake, Vector2(640, 360)), false)
	fight_hud(g, fi, v)
	if fi.state == "finisher" and fi.age > .6:g.centered("Пробел — провод", 214, 16, Color(1, 1, 1, .6 + .4 * sin(w.clock * 8)), true)
	if fi.state == "fight":g.text_at("F — подобрать строку кода · с ней удар сильнее", Vector2(30, 350), 8, Color(1, 1, 1, .45))
	if fi.state in ["wire", "done"] and fi.age > 1.6:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, clampf((fi.age - 1.6) / 1.0, 0, 1)))
	subtitles(g, n, 300.0)
	retry(g, n)

static func chair(g):
	var w = g.world;var n = w.notch;var f = n.finale
	var v = view(g)
	if f.age >= f.KILL_FILM_AT:
		# The kill itself is a film (scripts/cinematics/build_ch5_kill.py); the lines stay on top.
		v.ensure(g, "kill", Vector2i(640, 360));v.seek_film(f.age - f.KILL_FILM_AT);v.sync_bad_film(w.state == "PAUSED", g.settings.effects)
	else:
		v.ensure(g, "chair", Vector2i(640, 360));v.sync_chair(f, w.clock)
	g.draw_texture_rect(v.viewport.get_texture(), Rect2(0, 0, 640, 360), false)
	g.draw_rect(Rect2(0, 0, 640, 26), Color.BLACK);g.draw_rect(Rect2(0, 334, 640, 26), Color.BLACK)
	if f.age < 1.0:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 1 - f.age))
	# The film's first decoded frame lands a moment late: a short dip hides it and softens the cut.
	var into: float = f.age - f.KILL_FILM_AT
	if into >= 0 and into < .4:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, clampf(1.0 - (into - .1) / .3, 0, 1)))
	if f.age > f.CHAIR_LENGTH - 2.0:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, clampf((f.age - (f.CHAIR_LENGTH - 2.0)) / 1.6, 0, 1)))
	if f.age > f.CHAIR_STAB and f.age < f.CHAIR_STAB + .08 and g.settings.flashes:g.draw_rect(Rect2(0, 0, 640, 360), Color(.6, 0, 0, .35))
	if f.age > 2.0:g.text_at("Пробел — дальше", Vector2(540, 350), 8, Color(1, 1, 1, .3))
	subtitles(g, n, 306.0)

static func credits(g):
	var w = g.world;var n = w.notch;var f = n.finale
	var v = view(g);v.ensure(g, "flight", Vector2i(640, 360));v.sync_credits(f, w.clock)
	g.draw_texture_rect(v.viewport.get_texture(), Rect2(0, 0, 640, 360), false)
	g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, .55 + .45 * (1 - clampf(f.age / 2.0, 0, 1))))
	g.draw_rect(Rect2(120, 140, 400, 70), Color(0, 0, 0, .35))
	g.draw_rect(Rect2(0, 0, 640, 30), Color.BLACK);g.draw_rect(Rect2(0, 330, 640, 30), Color.BLACK)
	for c in f.CREDITS:
		var t: float = f.age - c[0]
		if t < 0 or t > 4.6:continue
		var k: float = clampf(t / .9, 0, 1) * clampf((4.6 - t) / .9, 0, 1)
		var rise: float = (1 - k) * 6
		if c[0] == 1.0:
			g.centered(c[1], 168 + rise, 32, Color(1, 1, 1, k), true)
			g.centered("глава V · Исходный код", 196 + rise, 8, Color(.6, 1, .9, k * .8))
			continue
		if not c[1].is_empty():g.centered(c[1], (148 if not c[2].is_empty() else 176) + rise, 8 if not c[2].is_empty() else 16, Color(.6, 1, .9, k * .85), c[2].is_empty())
		if not c[2].is_empty():g.centered(c[2], 196 + rise, 32 if c[1] != "" else 16, Color(1, 1, 1, k), true)
	for i in range(18):
		var y: float = fmod(i * 61.0 + w.clock * (8 + i % 4 * 3), 300.0) + 30
		g.draw_string(g.font, Vector2(fmod(i * 97.0, 620.0) + 10, y), "01{};"[i % 5], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.3, 1, .7, .12))
	if f.age > f.CREDITS_LENGTH - 1.5:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, clampf((f.age - (f.CREDITS_LENGTH - 1.5)) / 1.5, 0, 1)))

## Bad ending: a heavy title card on black, then slow grey credits under falling ash.
static func bad_credits(g):
	var w = g.world;var n = w.notch;var a: float = n.age
	g.draw_rect(Rect2(0, 0, 640, 360), Color(.015, .01, .012))
	for i in range(40):
		var x: float = fmod(i * 83.0 + sin(w.clock * .3 + i) * 12.0, 640.0)
		var y: float = fmod(i * 47.0 + w.clock * (6 + i % 5 * 2), 380.0) - 10
		g.draw_rect(Rect2(Vector2(x, y).floor(), Vector2(1 + i % 2, 1 + i % 2)), Color(.45, .42, .42, .25))
	var title: float = clampf((a - .8) / 1.2, 0, 1) * (1 - clampf((a - 4.6) / .8, 0, 1))
	if title > 0:
		var tick: int = int(w.clock * 12)
		var jitter := Vector2(Atmosphere.hash01(tick, 1, 71) - .5, 0) * (3.0 if Atmosphere.hash01(tick, 2, 71) > .85 else 0.0)
		g.centered("ПЛОХАЯ КОНЦОВКА", 170 + jitter.y, 32, Color(.62, .06, .08, title), true)
		g.draw_rect(Rect2(170 + jitter.x, 186, 300, 1), Color(.62, .06, .08, title * .6))
		g.centered("глава V · Исходный код", 204, 8, Color(.55, .55, .55, title * .8))
	for c in n.BAD_CREDITS:
		var t: float = a - c[0]
		if t < 0 or t > 4.4:continue
		var k: float = clampf(t / 1.1, 0, 1) * clampf((4.4 - t) / 1.1, 0, 1)
		g.centered(c[1], 160 + (1 - k) * 4, 8, Color(.55, .55, .58, k * .8))
		g.centered(c[2], 184 + (1 - k) * 4, 16, Color(.82, .8, .8, k), true)
	if a < .6:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 1 - a / .6))
	if a > n.BAD_CREDITS_LENGTH - 1.5:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, clampf((a - (n.BAD_CREDITS_LENGTH - 1.5)) / 1.5, 0, 1)))

static func portal(g):
	var w = g.world;var n = w.notch
	var v = view(g);v.ensure(g, "portal", Vector2i(640, 360));v.sync_portal(n.phase, n.age, w.clock)
	var shake: Vector2 = Vector2(round(sin(w.clock * 70) * 6), round(cos(w.clock * 61) * 4)) * (n.shake3d / .8) if g.settings.shake else Vector2.ZERO
	var a: float = n.age
	# Camera punch-in on contact: the picture jumps a little closer, then eases back.
	var punch: float = 0.0
	for h in n.PORTAL_HITS:
		var d: float = a - float(h)
		if d >= 0 and d < .6:punch = maxf(punch, (1.0 - smoothstep(n.PORTAL_HOLD, .6, d)) * (.06 if h < 1.0 else .1))
	var size := Vector2(640, 360) * (1.0 + punch)
	g.draw_texture_rect(v.viewport.get_texture(), Rect2(shake - (size - Vector2(640, 360)) / 2, size), false)
	var spec: Array = v.PORTALS.get(n.phase, v.PORTALS.to_ut)
	# One white frame, then a red bruise of the screen that fades with the hit-stop.
	for h in n.PORTAL_HITS:
		var d: float = a - float(h)
		if d >= 0 and d < .035 and g.settings.flashes:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, .55))
		elif d >= .035 and d < .45:g.draw_rect(Rect2(0, 0, 640, 360), Color(.55, 0, .02, .28 * (1.0 - d / .45)))
	if a < .5:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 1.0 - a / .5))
	if a > 3.7:
		var k: float = clampf((a - 3.7) / .5, 0, 1)
		g.draw_rect(Rect2(0, 0, 640, 360), (spec[1] as Color).lerp(Color.WHITE, .5) * Color(1, 1, 1, k))
	subtitles(g, n, 300.0)

static func flight(g):
	var w = g.world;var n = w.notch;var f = n.finale
	var v = view(g);v.ensure(g, "flight", Vector2i(640, 360));v.sync_flight(f, w.clock)
	g.draw_texture_rect(v.viewport.get_texture(), Rect2(0, 0, 640, 360), false)
	var a: float = f.age
	if a < 1.0:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 1 - a))
	if a > 4.0 and a < 5.6:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, 1 - absf(a - 4.8) / .8))
	if a > f.FLIGHT_OTHER - .8 and a < f.FLIGHT_OTHER + .8:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, 1 - absf(a - f.FLIGHT_OTHER) / .8))
	if a >= f.FLIGHT_STING:g.draw_rect(Rect2(0, 0, 640, 360), Color.BLACK)
	if a >= f.FLIGHT_STING + 1.0:g.centered("…", 176, 16, Color(1, 1, 1, clampf(a - f.FLIGHT_STING - 1.0, 0, 1)), true)

## Contact: a one-frame flash, then speed lines pulling to the blow.
static func impact_frames(g,q):
	var at: float=-1.0;var good := true
	if q.finishing:at=q.finish_age-.65
	else:
		var track: String=q.TRACKS[mini(q.beat,q.TRACKS.size()-1)]
		if not q.resolved:return
		good=q.success
		at=q.age-(1.4 if good and track in ["parry","guard"] else 1.0)
		if good and track in ["slip","roll"]:at=-1.0
	if at<0 or at>.3:return
	if at<.05 and g.settings.flashes:g.draw_rect(Rect2(0,0,640,360),Color(1,1,1,.85) if good else Color(.8,0,0,.6))
	var k: float=1.0-at/.3
	for i in range(28):
		var a: float=i*2.39996
		var r0: float=90.0+Atmosphere.hash01(i,7,90)*80.0+at*200.0
		var d := Vector2(cos(a),sin(a)*.62)
		g.draw_line(Vector2(320,180)+d*r0,Vector2(320,180)+d*(r0+60+k*90),Color(1,1,1,.55*k) if good else Color(1,.2,.2,.5*k),2)

static func qte(g):
	var w=g.world;var n=w.notch;var v=view(g)
	v.ensure(g,"bad_end" if n.phase=="bad_end" else "qte",Vector2i(640,360))
	if n.phase=="bad_end":
		v.sync_bad_film(w.state=="PAUSED",g.settings.effects)
		g.draw_texture_rect(v.viewport.get_texture(),Rect2(0,0,640,360),false)
		if n.age<.15:g.draw_rect(Rect2(0,0,640,360),Color.BLACK)
		return
	v.sync_qte(n.qte)
	g.draw_texture_rect(v.viewport.get_texture(),Rect2(0,0,640,360),false)
	g.draw_rect(Rect2(0,0,640,24),Color.BLACK);g.draw_rect(Rect2(0,330,640,30),Color.BLACK)
	var q=n.qte
	impact_frames(g,q)
	if q.finishing:return
	# The prompt window: the edges close in while the decision is yours.
	if q.age>.2 and (not q.resolved or q.age<q.resolved_age+.2):
		var k: float=smoothstep(.2,.4,q.age)*(1.0-smoothstep(0,.2,q.age-q.resolved_age) if q.resolved else 1.0)
		for i in range(10):g.draw_rect(Rect2(i*6,24+i*4,640-i*12,306-i*8),Color(0,0,0,.09*k),false,6)
	var feedback: float=maxf(0,q.age-q.resolved_age)
	if not q.resolved or feedback<.28:
		var at := Vector2(320,74)
		var left: float=clampf((.90-q.age)/.65,0,1)
		var state: String="ok" if q.resolved and q.success else "fail" if q.resolved else ""
		var scale_key: float=1.25+(.13*sin(feedback*PI/.28) if q.resolved else 0)
		if state=="fail":at.x+=sin(feedback*70)*3*(1-feedback/.28)
		FourPrompt.key_glyph(g,at,"attack" if q.expected()=="accept" else q.expected(),left,state,scale_key)
		if state.is_empty():
			g.draw_arc(at,25+19*left,-PI/2,-PI/2+TAU*left,40,Color(1,1,1,.8),2)
			if q.expected()!="accept":g.text_at({"left":"A","right":"D","up":"W","down":"S"}[q.expected()],Vector2(264,78),8,Color(.8,.82,.85))
		elif state=="ok":g.draw_arc(at,25+feedback*85,0,TAU,40,Color(1,1,1,maxf(0,1-feedback/.28)),2)
	for i in range(8):
		g.draw_rect(Rect2(285+i*9,344,5,3),Color(.85,.85,.8) if i<q.beat else Color(.27,.29,.31))
	for i in range(3):g.draw_rect(Rect2(589+i*10,344,5,3),Color(.8,.12,.10) if i<q.mistakes else Color(.22,.23,.25))
