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

static func battle(g):
	var w = g.world;var n = w.notch
	g.draw_rect(Rect2(0, 0, 640, 360), Color.BLACK)
	var shake: Vector2 = Vector2(round(sin(w.clock * 60) * 2), 0) if n.ut_flash > 0 else Vector2.ZERO
	figure(g, "exhausted" if n.ut_state == "end" else ("stagger" if n.ut_flash > 0 else "idle"), n.age, Vector2(320, 140) + shake, Vector2.DOWN, 2.0)
	glow(g, Vector2(320, 140), 2.0, w.clock)
	var box: Rect2 = n.UT_BOX
	if n.ut_state != "wave":box = Rect2(60, 160, 520, 110)
	g.draw_rect(box, Color.BLACK)
	g.draw_rect(box, WHITE, false, 2)
	match n.ut_state:
		"wave":
			for b in n.ut_bullets:
				if not box.grow(-2).has_point(b.p):continue
				g.draw_string(g.bold, (b.p + Vector2(-3, 4)).floor(), b.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 8 if b.glyph != "■" else 16, WHITE)
			heart(g, n.soul, Color(1, .1, .1) if w.invulnerable <= 0 or int(w.clock * 20) % 2 == 0 else Color(.5, .1, .1))
		"bar":
			var r := Rect2(box.position + Vector2(20, 30), Vector2(box.size.x - 40, 50))
			g.draw_rect(r, Color(.08, .08, .08));g.draw_rect(r, WHITE, false, 1)
			for k in range(9):
				var x: float = r.position.x + r.size.x * (k / 8.0)
				g.draw_line(Vector2(x, r.position.y + 6), Vector2(x, r.end.y - 6), Color(.3, 1, .9, .25 + .5 * (1 - absf(k - 4) / 4.0)), 2)
			var cx: float = r.position.x + r.size.x * n.bar
			g.draw_rect(Rect2(cx - 3, r.position.y - 4, 6, r.size.y + 8), WHITE)
		_:
			var lines: PackedStringArray = n.ut_text.split("\n")
			for i in range(lines.size()):g.draw_string(g.bold, box.position + Vector2(18, 30 + i * 22), lines[i], HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 30, 16, WHITE)
	g.text_at("STEVE   LV 19", Vector2(60, 290), 8, WHITE, true)
	g.text_at("HP", Vector2(220, 290), 8, WHITE, true)
	g.draw_rect(Rect2(240, 282, 60, 10), Color(.7, 0, 0));g.draw_rect(Rect2(240, 282, 60 * clampf(w.hp / 20.0, 0, 1), 10), YELLOW)
	g.text_at("%d / 20" % int(maxf(0, w.hp)), Vector2(308, 290), 8, WHITE, true)
	var labels := {"fight":"БИТЬ", "act":"ДЕЙСТВ.", "item":"ПРЕДМЕТ", "mercy":"ПОЩАДА"}
	var options: Array = n.menu_options()
	for i in range(options.size()):
		var r: Rect2 = n.menu_rect(i)
		var on: bool = n.ut_state == "menu" and n.ut_choice == i
		var c: Color = YELLOW if on else ORANGE
		g.draw_rect(r, c, false, 2)
		if on:heart(g, r.position + Vector2(12, 12), Color(1, .1, .1))
		g.draw_string(g.bold, r.position + Vector2(24 if on else 14, 16), labels[options[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)
	if n.mercy_gone and int(w.clock * 3) % 5 == 0:
		g.draw_string(g.font, n.menu_rect(3).position + Vector2(10, 16), "null", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.97, 0, .86, .5))
	for pu in n.popups:
		if pu.get("screen", false):g.centered(pu.text, 70 - pu.age * 10, 16, Color(1, .2, .2, 1 - pu.age / 1.8), true)
	subtitles(g, n, 334.0)
	retry(g, n)

static func heart(g, c: Vector2, col: Color):
	var pts := PackedVector2Array([c + Vector2(0, 4), c + Vector2(-4, 0), c + Vector2(-4, -2), c + Vector2(-2, -4), c + Vector2(0, -2), c + Vector2(2, -4), c + Vector2(4, -2), c + Vector2(4, 0)])
	g.draw_colored_polygon(pts, col)

# ------------------------------------------------------------------ the lanes

static func lanes(g):
	var w = g.world;var n = w.notch
	g.draw_rect(Rect2(0, 0, 640, 360), Color(.05, .06, .08))
	for r in range(n.ROWS):
		for c in range(n.COLS):
			var rect: Rect2 = n.cell_rect(Vector2i(c, r))
			g.draw_rect(rect, Color(.1, .13, .1) if (r + c) % 2 == 0 else Color(.08, .11, .09))
			g.draw_rect(rect, Color(.3, 1, .45, .08), false, 1)
	var right: float = n.LANE_ORIGIN.x + n.COLS * n.CELL.x
	g.draw_rect(Rect2(right, n.LANE_ORIGIN.y, 640 - right, n.ROWS * n.CELL.y), Color(.07, .05, .08))
	for r in range(n.ROWS):
		var y: float = n.row_y(r)
		g.draw_actor("steve", Vector2(70, y + 12), Vector2.RIGHT, 0.0, false, Color.WHITE, "idle", 1.0, {"state":"idle", "time":w.clock + r})
	figure(g, n.pose, n.pose_age, Vector2(600, 250), Vector2.LEFT, 1.6)
	glow(g, Vector2(600, 250), 1.6, w.clock)
	for c in n.plants:
		var pl: Dictionary = n.plants[c]
		var rect: Rect2 = n.cell_rect(c)
		var icon: String = "icon_pvz_" + pl.kind
		var bob: float = round(sin(pl.age * 3) * 1) if pl.kind == "redstone_ore" else 0.0
		var tint := Color(1.6, 1.6, 1.6) if pl.kind == "tnt" and int(pl.timer * 10) % 2 == 0 else Color.WHITE
		if g.textures.has(icon):g.draw_texture_rect(g.textures[icon], Rect2(rect.get_center() - Vector2(14, 16 + bob), Vector2(28, 28)), false, tint)
		if pl.hp < n.PLANT_HP[pl.kind] and pl.kind != "tnt":
			g.draw_rect(Rect2(rect.position + Vector2(8, rect.size.y - 5), Vector2((rect.size.x - 16) * pl.hp / n.PLANT_HP[pl.kind], 2)), Color(.95, .3, .25))
	var cr: Rect2 = n.cell_rect(n.cursor)
	g.draw_rect(cr.grow(-1), Color(1, 1, 1, .5 + .4 * sin(w.clock * 6)), false, 2)
	var sorted: Array = n.zombies.duplicate()
	sorted.sort_custom(func(a, b):return a.row < b.row)
	for z in sorted:
		var q := Vector2(z.x, n.row_y(z.row) + 12)
		var kind: String = {"zombie":"zombie", "elite":"elite", "glitch":"zombie", "creeper":"creeper"}[z.kind]
		var tint := Color(1.8, 1.8, 1.8) if z.flash > 0 else (Color(.6, 1, 1) if z.kind == "glitch" else Color.WHITE)
		g.oval(q, Vector2(9, 3), Color(0, 0, 0, .35))
		g.draw_actor(kind, q, Vector2.LEFT, z.age, z.moving, tint, "walk", 1.2, z.visual)
		if z.kind == "glitch" and int(w.clock * 12) % 3 == 0:g.draw_rect(Rect2(q + Vector2(-6, -30), Vector2(8, 8)), Color(.97, 0, .86))
	for a in n.arrows:
		var y: float = n.row_y(a.row) - 6
		g.draw_line(Vector2(a.x - 8, y), Vector2(a.x, y), Color(.85, .8, .7), 2)
		g.draw_rect(Rect2(a.x - 1, y - 2, 3, 4), Color(.6, .6, .65))
	for b in n.blasts:
		var k: float = b.age / .5
		g.draw_circle(b.p, 20 + k * 50, Color(1, .6, .2, .5 * (1 - k)))
	for i in range(n.CARDS.size()):
		var r: Rect2 = n.card_rect(i)
		var spec: Array = n.CARDS[i]
		var ready: bool = n.card_ready[i] <= 0 and n.redstone >= int(spec[1])
		g.draw_rect(r, Color(.12, .12, .14))
		g.draw_rect(r, YELLOW if n.card == i else Color(.5, .5, .55), false, 2 if n.card == i else 1)
		if g.textures.has("icon_pvz_" + spec[0]):g.draw_texture_rect(g.textures["icon_pvz_" + spec[0]], Rect2(r.position + Vector2(13, 4), Vector2(24, 24)), false, Color.WHITE if ready else Color(.4, .4, .4))
		g.draw_string(g.font, r.position + Vector2(4, 40), str(spec[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, .3, .3))
		g.draw_string(g.font, r.position + Vector2(40, 12), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, .5))
		if n.card_ready[i] > 0:g.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * n.card_ready[i] / float(spec[2]))), Color(0, 0, 0, .55))
	if g.textures.has("icon_pvz_redstone"):g.draw_texture_rect(g.textures.icon_pvz_redstone, Rect2(46, 50, 24, 24), false)
	g.text_at(str(n.redstone), Vector2(48, 86), 8, Color(1, .35, .3), true)
	var left: int = n.schedule.size() + n.zombies.size()
	g.text_at("Осталось: %d" % left, Vector2(352, 60), 8, Color(1, 1, 1, .7))
	g.text_at("1–4 — блок · стрелки/мышь — клетка · пробел — поставить", Vector2(112, 336), 8, Color(1, 1, 1, .4))
	for pu in n.popups:
		if pu.get("screen", false):g.draw_string(g.font, (pu.p - Vector2(8, 20 + pu.age * 14)).floor(), pu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, .35, .3, 1 - pu.age / 1.8))
	subtitles(g, n, 316.0)
	retry(g, n)
