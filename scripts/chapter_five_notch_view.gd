extends RefCounted
## Notch on screen: his figure, the fight's attacks, the battle box and the
## lanes. Reads the notch state only.
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
	g.oval(p, Vector2(10, 3), Color(0, 0, 0, .35))
	glow(g, p, 1.0, w.clock)
	var m = n.notch_mob(w) if n.id >= 0 else null
	var tint := Color(1.8, 1.8, 1.8) if m != null and m.flash > 0 and g.settings.flashes else Color.WHITE
	var lift: float = round(sin(w.clock * 2.0) * 1.5) + 3
	figure(g, n.pose, n.pose_age, p - Vector2(0, lift), n.dir, 1.5, tint)

static func air(g, offset: Vector2):
	var w = g.world;var n = w.notch
	if n.phase != "fight":return
	for wl in n.walls:
		var x: float = wl.x + offset.x
		for y in range(0, 360, 8):
			var wy: float = y - offset.y
			if absf(wy - wl.gap) < 26:continue
			var q := Vector2(x - 4, y)
			for k in range(2):g.draw_rect(Rect2(q + Vector2(0, k * 4), Vector2(4, 4)), Color(.97, 0, .86) if (k + y / 8) % 2 == 0 else Color(0, 0, 0))
			g.draw_rect(Rect2(q + Vector2(4, 0), Vector2(4, 4)), Color(0, 0, 0) if (y / 8) % 2 == 0 else Color(.97, 0, .86))
	for f in n.falls:
		var k: float = clampf(f.age / f.delay, 0, 1)
		var q: Vector2 = f.p + offset
		if f.age < f.delay:
			var height: float = (1 - k) * 160
			var icon: String = "icon_pvz_obsidian" if f.block == "obsidian" else ""
			if not icon.is_empty() and g.textures.has(icon):g.draw_texture_rect(g.textures[icon], Rect2(q - Vector2(8, 16 + height), Vector2(16, 16)), false)
			else:g.draw_rect(Rect2(q - Vector2(7, 14 + height), Vector2(14, 14)), Color(.5, .5, .52) if f.block == "stone" else Color(.48, .33, .2))
	for pu in n.popups:
		if pu.get("screen", false):continue
		var k: float = pu.age / 1.8
		var q: Vector2 = pu.p + offset - Vector2(0, 48 + k * 14)
		var wd: float = g.font.get_string_size(pu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		g.draw_rect(Rect2((q - Vector2(wd / 2 + 4, 9)).floor(), Vector2(wd + 8, 12)), Color(0, 0, 0, .7 * (1 - k)))
		g.draw_string(g.font, (q - Vector2(wd / 2, 0)).floor(), pu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.4, 1, .9, 1 - k))
	if n.slow_left > 0:g.draw_arc(w.player + offset - Vector2(0, 10), 14, 0, TAU, 16, Color(.4, 1, .9, .5), 1)

static func overlay(g):
	var w = g.world;var n = w.notch
	if n.phase == "fight" and n.id >= 0:
		g.centered("Нотч", 41, 8, Color.WHITE, true)
		g.draw_rect(Rect2(191, 46, 258, 6), Color(.15, .15, .2))
		g.draw_rect(Rect2(192, 47, 256 * clampf(n.hp / n.FIGHT_HP, 0, 1), 4), Color(.3, 1, .9))
	if n.phase == "intro":
		g.draw_rect(Rect2(0, 0, 640, 24), Color.BLACK);g.draw_rect(Rect2(0, 336, 640, 24), Color.BLACK)
		if n.age > 1.5:g.text_at("Пробел — пропустить", Vector2(522, 351), 8, Color(1, 1, 1, .35))
	retry(g, n)
	subtitles(g, n, 278.0 if n.phase == "fight" else 316.0)

static func subtitles(g, n, y: float):
	if n.line.is_empty():return
	var a: float = minf(1, n.line_age / .15) * minf(1, (n.line_length - n.line_age) / .2)
	var wd: float = g.font.get_string_size(n.line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	g.draw_rect(Rect2((640 - wd) / 2 - 8, y, wd + 16, 16), Color(0, 0, 0, .65 * a))
	g.centered(n.line, y + 11, 8, Color(.6, 1, .95, a))

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
			im.set_pixel(x, y, Color(1, 1, 1, 1) if l > .42 else (Color(.55, .55, .55, 1) if l > .2 else Color(0, 0, 0, 1)))
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
	g.draw_rect(Rect2(0, 0, 640, 360), Color(.01, .02, .03))
	# His dimension behind the box: falling columns of code and a slow grid.
	for c in range(32):
		var x: float = 10 + c * 20
		var speed: float = 18.0 + fmod(c * 7.3, 22.0)
		for r in range(7):
			var y: float = fposmod(w.clock * speed + r * 54 + c * 31, 380.0) - 10
			var a: float = (.05 + .07 * float(r == 6)) * (1.0 - absf(x - 320) / 400.0)
			g.draw_string(g.font, Vector2(x, y), ["0", "1", "{", "}", ";", "=", "<", ">"][(c * 3 + r + int(w.clock * 2)) % 8], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.3, 1, .6, a))
	for k in range(9):
		var gy: float = 300 - pow(k / 8.0, 1.6) * 140
		g.draw_line(Vector2(0, gy), Vector2(640, gy), Color(.2, .9, .8, .05), 1)
	var shake: Vector2 = Vector2(round(sin(w.clock * 60) * 3), 0) if n.ut_flash > 0 else Vector2.ZERO
	var np := Vector2(320, 150 + sin(w.clock * 1.6) * 3) + shake
	glow(g, np, 3.6, w.clock)
	var pose: String = "exhausted" if n.ut_state == "end" else ("stagger" if n.ut_flash > 0 else ("cast" if n.ut_state == "wave" else "idle"))
	if int(w.clock * 7) % 23 == 0:figure(g, pose, n.age, np + Vector2(5, 0), Vector2.DOWN, 3.8, Color(.97, 0, .86, .5))
	figure(g, pose, n.age, np, Vector2.DOWN, 3.8, Color(1.6, 1.6, 1.6) if n.ut_flash > 0 and int(w.clock * 30) % 2 == 0 else Color.WHITE)
	if n.ut_slash >= 0 and n.ut_slash < .45:
		var k: float = n.ut_slash / .45
		for i in range(3):g.draw_line(np + Vector2(-34 + i * 10, -130), (np + Vector2(-34 + i * 10, -130)).lerp(np + Vector2(40 + i * 10, -40), k), Color(1, .1, .1), 3)
	if n.ut_number_age < 1.2:
		var bounce: float = -absf(sin(n.ut_number_age * 9.0)) * 10.0 * (1 - n.ut_number_age)
		var txt: String = "ПРОМАХ" if n.ut_number < 0 else str(n.ut_number)
		g.draw_string(g.bold, Vector2(320 - g.bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x / 2, 64 + bounce), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, .15, .15) if n.ut_number >= 0 else Color(.7, .7, .7))
		if n.ut_number >= 0:
			g.draw_rect(Rect2(260, 74, 120, 8), Color(.3, .3, .3));g.draw_rect(Rect2(260, 74, 120 * clampf(n.ut_hp / n.UT_HP, 0, 1), 8), Color(.1, .9, .2))
	var box: Rect2 = n.UT_BOX if n.ut_state == "wave" else Rect2(40, 168, 560, 104)
	g.draw_rect(box, Color(0, 0, 0, .92))
	g.draw_rect(box.grow(4), Color(.3, 1, .85, .12 + .06 * sin(w.clock * 3)), false, 3)
	g.draw_rect(box.grow(1), Color(.92, 1, .97), false, 3)
	for cpt in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		g.draw_rect(Rect2(cpt - Vector2(4, 4), Vector2(8, 8)), Color(.3, 1, .85))
	match n.ut_state:
		"wave":
			for bl in n.ut_blasters:
				var dir := Vector2.from_angle(bl.angle)
				if bl.age < .75:
					g.draw_line(bl.p, bl.p + dir * 400, Color(1, 1, 1, .25 + .2 * sin(bl.age * 40)), 1)
				elif bl.age < 1.15:
					var o: Vector2 = dir.orthogonal() * 9
					g.draw_colored_polygon(PackedVector2Array([bl.p + o, bl.p + o + dir * 420, bl.p - o + dir * 420, bl.p - o]), Color(1, 1, 1, 1.0 - (bl.age - .75) * 1.5))
				g.draw_set_transform(bl.p, bl.angle + PI / 2, Vector2.ONE)
				g.draw_texture_rect(view(g).tex("icon_command_block") if g.textures.has("icon_command_block") == false else g.textures.icon_command_block, Rect2(-11, -11 - (4 if bl.age > .75 else 0), 22, 22), false)
				g.draw_set_transform(Vector2.ZERO)
			for b in n.ut_bullets:
				if not box.grow(-2).has_point(b.p) and not b.get("ring", false):continue
				match b.get("shape", "dot"):
					"block":
						g.draw_rect(Rect2(b.p - b.size / 2, b.size), Color.WHITE);g.draw_rect(Rect2(b.p - b.size / 2 + Vector2(2, 2), b.size - Vector2(4, 4)), Color.BLACK)
					"line":g.draw_rect(Rect2(b.p - b.size / 2, b.size), Color(.3, .7, 1) if n.ut_mode == "blue" else Color.WHITE)
					"cursor":
						var d: Vector2 = b.v.normalized() if b.v.length() > .1 else Vector2.RIGHT
						var o2: Vector2 = d.orthogonal()
						g.draw_colored_polygon(PackedVector2Array([b.p + d * 6, b.p - d * 5 + o2 * 4, b.p - d * 2, b.p - d * 5 - o2 * 4]), Color.WHITE)
					"ring":g.draw_arc(b.p, b.r, 0, TAU, 24, Color(1, 1, 1, clampf(1 - b.r / 60.0, 0, 1)), 2)
					"key":
						g.draw_rect(Rect2(b.p - b.size / 2, b.size), Color.WHITE)
						g.draw_string(g.bold, b.p + Vector2(-3, 4), b.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.BLACK)
					"anvil":
						if b.has("delay"):
							var warn: float = .25 + .25 * sin(b.age * 40)
							g.draw_rect(Rect2(b.p.x - 8, box.position.y, 16, box.size.y), Color(1, .2, .1, warn * .5))
							continue
						g.draw_rect(Rect2(b.p - b.size / 2, b.size), Color(.3, .3, .33))
						g.draw_rect(Rect2(b.p + Vector2(-8, -7), Vector2(16, 4)), Color(.45, .45, .5))
						g.draw_rect(Rect2(b.p + Vector2(-4, -3), Vector2(8, 6)), Color(.25, .25, .28))
					"tnt":
						var blink: bool = int(b.age * (6 + b.age * 14)) % 2 == 0
						g.draw_texture_rect(v.tex("ch5q_tnt"), Rect2(b.p - b.size / 2, b.size), false, Color(2, 2, 2) if blink else Color.WHITE)
						g.draw_line(Vector2(box.position.x, b.p.y), Vector2(box.end.x, b.p.y), Color(1, .4, .1, .12 + .1 * float(blink)), 1)
						g.draw_line(Vector2(b.p.x, box.position.y), Vector2(b.p.x, box.end.y), Color(1, .4, .1, .12 + .1 * float(blink)), 1)
					"fire":
						var k2: float = 1.0 - float(b.get("age", 0.0)) / b.life
						g.draw_rect(Rect2(b.p - b.size / 2, b.size), Color(1, .55, .1, k2))
						g.draw_rect(Rect2(b.p - b.size / 2 + Vector2(0, b.size.y * .3) * float(b.size.x > b.size.y) + Vector2(b.size.x * .3, 0) * float(b.size.x <= b.size.y), b.size * Vector2(1, .4) if b.size.x > b.size.y else b.size * Vector2(.4, 1)), Color(1, .95, .6, k2))
					_:g.draw_circle(b.p, 3.5, Color(1, .6, .2) if b.get("reversed", false) else Color.WHITE)
			var ht: Color = (Color(.5, .7, 1.6) if n.ut_mode == "blue" else Color.WHITE) if w.invulnerable <= 0 or int(w.clock * 20) % 2 == 0 else Color(1, 1, 1, .25)
			g.draw_texture_rect(g.textures.heart if g.textures.has("heart") else v.tex("heart"), Rect2(n.soul - Vector2(6, 6), Vector2(12, 12)), false, ht)
			if 6.5 - n.ut_timer < 2.8 and not n.ut_bubble.is_empty():
				var bt: String = n.ut_bubble
				var bwid: float = minf(220.0, g.font.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 16)
				var r := Rect2(392, 40, bwid, 34)
				g.draw_rect(r, Color.WHITE);g.draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, 12), r.position + Vector2(-10, 18), r.position + Vector2(0, 22)]), Color.WHITE)
				g.draw_string(g.font, r.position + Vector2(8, 14), bt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 8, Color.BLACK)
		"bar", "slash", "miss":
			var r := Rect2(box.position + Vector2(18, 14), Vector2(box.size.x - 36, box.size.y - 28))
			g.draw_rect(r, Color(.05, .05, .05))
			var c: Vector2 = r.get_center()
			for i in range(1, 6):
				var wd: float = r.size.x * i / 6.0
				g.draw_rect(Rect2(c - Vector2(wd / 2, r.size.y / 2 - i * 3), Vector2(wd, r.size.y - i * 6)), Color(.2 + i * .1, .7, .3 + i * .05) if i % 2 else Color(.05, .05, .05), false, 2)
			g.draw_rect(Rect2(c - Vector2(2, r.size.y / 2), Vector2(4, r.size.y)), Color(1, 1, 1, .5))
			var cx: float = r.position.x + r.size.x * clampf(n.bar, 0, 1)
			var bar_col: Color = Color.WHITE if n.ut_state == "bar" or int(w.clock * 16) % 2 == 0 else Color.BLACK
			g.draw_rect(Rect2(cx - 3, r.position.y - 4, 6, r.size.y + 8), bar_col);g.draw_rect(Rect2(cx - 3, r.position.y - 4, 6, r.size.y + 8), Color.BLACK, false, 1)
		_:
			var shown: String = n.ut_text.substr(0, int(n.ut_type))
			var lines: PackedStringArray = shown.split("\n")
			for i in range(lines.size()):g.draw_string(g.bold, box.position + Vector2(20, 34 + i * 26), lines[i], HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 30, 16, Color.WHITE)
	var hp: float = maxf(0, w.hp)
	for k in range(10):
		var hx := Vector2(232 + k * 18, 280)
		g.draw_texture_rect(v.tex("heart_empty") if g.textures.has("heart_empty") == false else g.textures.heart_empty, Rect2(hx, Vector2(16, 16)), false)
		var fill: float = hp - k * 2
		if fill >= 2:g.draw_texture_rect(g.textures.heart, Rect2(hx, Vector2(16, 16)), false)
		elif fill >= 1:g.draw_texture_rect(g.textures.heart_half, Rect2(hx, Vector2(16, 16)), false)
	g.draw_string(g.bold, Vector2(40, 294), "STEVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	g.draw_rect(Rect2(110, 288, 100, 4), Color(0, 0, 0));g.draw_rect(Rect2(110, 288, 64, 4), Color(.5, 1, .2))
	g.draw_string(g.bold, Vector2(150, 286), "19", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.5, 1, .2))
	var labels := {"fight":"БИТЬ", "act":"ДЕЙСТВ", "item":"ВЕЩИ", "mercy":"ПОЩАДА"}
	var options: Array = n.menu_options()
	for i in range(4):
		var r: Rect2 = n.menu_rect(i)
		if i >= options.size():
			if n.mercy_gone and int(w.clock * 3) % 4 == 0:g.draw_string(g.font, r.position + Vector2(16, 17), "null", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.97, 0, .86, .6))
			continue
		var on: bool = n.ut_state == "menu" and n.ut_choice == i
		# Hotbar slots with the item that does the job.
		g.draw_rect(r, Color(.18, .18, .2, .95));g.draw_rect(r, Color(.05, .05, .06), false, 2)
		g.draw_line(r.position + Vector2(2, 2), Vector2(r.end.x - 2, r.position.y + 2), Color(.45, .45, .5), 1)
		if on:g.draw_rect(r.grow(2), Color(1, 1, 1), false, 2)
		var icon: String = {"fight":"ch5q_item_iron_sword", "act":"ch5q_item_book", "item":"ch5q_item_golden_apple", "mercy":"ch5q_item_paper"}[options[i]]
		g.draw_texture_rect(v.tex(icon), Rect2(r.position + Vector2(4, 2 - (2 if on else 0)), Vector2(20, 20)), false)
		g.draw_string(g.bold, r.position + Vector2(30, 16), labels[options[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, .6) if on else Color(.85, .85, .85))
	retry(g, n)

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
	g.draw_actor("steve", Vector2(40, top + 96), Vector2.RIGHT, w.clock, false, Color.WHITE, "idle", 1.0, {"state":"idle", "time":w.clock})
	g.draw_texture_rect(T.call("ch5p_dirt"), Rect2(66, top - 18, n.LANE_ORIGIN.x - 66, bottom - top + 18), true, Color(.85, .75, .62))
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
						g.draw_texture_rect(g.textures.icon_pvz_snow, Rect2(base - Vector2(13 + kick, 24), Vector2(26, 26)), false, tint)
						g.draw_texture_rect(g.textures.icon_pvz_snow_golem, Rect2(base - Vector2(11 + kick, 42), Vector2(22, 22)), false, tint)
						for k in [-1, 1]:g.draw_line(base + Vector2(k * 10, -16), base + Vector2(k * 18, -24), Color(.35, .22, .1), 2)
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
		g.draw_texture_rect(g.textures["icon_pvz_" + spec[0]], Rect2(r.position + Vector2(r.size.x / 2 - 12, 6), Vector2(24, 24)), false, Color.WHITE if ready else Color(.5, .5, .5))
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
	if f.thrown >= .6 and f.thrown < .78 and g.settings.flashes:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, (.78 - f.thrown) * 5.0))
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
	var v = view(g);v.ensure(g, "chair", Vector2i(640, 360));v.sync_chair(f, w.clock)
	g.draw_texture_rect(v.viewport.get_texture(), Rect2(0, 0, 640, 360), false)
	g.draw_rect(Rect2(0, 0, 640, 26), Color.BLACK);g.draw_rect(Rect2(0, 334, 640, 26), Color.BLACK)
	if f.age < 1.0:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 1 - f.age))
	if f.age > f.CHAIR_LENGTH - 2.0:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, clampf((f.age - (f.CHAIR_LENGTH - 2.0)) / 1.6, 0, 1)))
	if f.age > f.CHAIR_STAB and f.age < f.CHAIR_STAB + .12 and g.settings.flashes:g.draw_rect(Rect2(0, 0, 640, 360), Color(.6, 0, 0, .4))
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
	if f.age > 3.0:g.text_at("Пробел — пропустить", Vector2(530, 348), 8, Color(1, 1, 1, .25))
	if f.age > f.CREDITS_LENGTH - 1.5:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, clampf((f.age - (f.CREDITS_LENGTH - 1.5)) / 1.5, 0, 1)))

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
