extends RefCounted
## Chapter V presentation: the white/dark code plane, code enemies drawn as
## editor cards, glitched vanilla mobs, deleted floor and the debug overlay.
const Atmosphere = preload("res://scripts/ui/atmosphere.gd")
const KEY := Color(.9, .5, .22)
const FLOW := Color(.78, .5, .95)
const NUM := Color(.55, .85, .55)
const TEXT := Color(.82, .84, .9)
const CARD := Color(.075, .08, .11)
const NotchView = preload("res://scripts/chapter_five_notch_view.gd")
var code: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_code.json")).lines
var widths: Dictionary = {}
var vignette: GradientTexture2D

func _init():
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0));gradient.set_color(1, Color(0, 0, 0, 1))
	gradient.add_point(0.45, Color(0, 0, 0, 0.12))
	vignette = GradientTexture2D.new()
	vignette.gradient = gradient;vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(.5, .5);vignette.fill_to = Vector2(1, .5);vignette.width = 128;vignette.height = 128

static func h(i: int, salt: int) -> float:
	return Atmosphere.hash01(i, salt, 55)

func width(g, text: String) -> float:
	if not widths.has(text):widths[text] = g.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	return widths[text]

func world(g):
	var w = g.world
	if w.stage == "notch":
		var ph: String = w.notch.phase if w.notch.phase != "retry" else w.notch.retry_of
		if ph in ["ut", "to_lanes"] or (ph == "ut"):
			NotchView.battle(g);return
		if ph in ["lanes", "lanes_won"]:
			NotchView.lanes(g);return
		if ph in ["fighter", "to_quake"]:
			NotchView.fighter(g);return
		if ph in ["quake", "quake_won"]:
			NotchView.quake(g);return
	NotchView.release(g)
	var offset: Vector2 = Vector2(320, 180) - w.camera().floor()
	if g.settings.get("camera_lead", false):offset -= g.cam_lead.round()
	if w.shake > 0 and g.settings.shake and w.state == "RUNNING":offset += Vector2(sin(w.clock * 75), cos(w.clock * 87)).round()
	var tone: float = w.tone()
	var paper: Color = Color(.93, .93, .95).lerp(Color(.025, .025, .04), tone)
	var ink: Color = Color(.1, .1, .14).lerp(Color(.75, .8, .95), tone)
	g.draw_rect(Rect2(0, 0, 640, 360), paper)
	floor_code(g, offset, ink, tone)
	edges(g, offset, ink, paper)
	deleted(g, offset)
	for z in w.zones:
		var p: Vector2 = z.p + offset
		var k: float = clampf(z.age / z.delay, 0, 1)
		if z.age < z.delay:
			g.draw_arc(p, z.r, 0, TAU, 28, Color(.95, .3, .25, .8), 1)
			g.draw_arc(p, z.r * k, 0, TAU, 28, Color(.95, .3, .25, .45), 1)
			g.text_at("else", p - Vector2(10, -3), 8, Color(.95, .3, .25, .8))
		else:g.draw_circle(p, z.r, Color(.95, .3, .25, .5 * (1 - (z.age - z.delay) / .3)))
	var actors: Array = []
	for obj in w.props:
		if obj.hp > 0 and Rect2(-30, -30, 700, 420).has_point(obj.p + offset):actors.append({"sort":obj.p.y,"kind":"prop","obj":obj})
	for m in w.mobs:
		if Rect2(-80, -80, 800, 520).has_point(m.p + offset):actors.append({"sort":m.p.y,"kind":"mob","obj":m})
	for o in w.loot:
		if Rect2(-24, -24, 688, 408).has_point(o.p + offset):actors.append({"sort":o.p.y,"kind":"loot","obj":o})
	actors.append({"sort":w.player.y,"kind":"player"})
	for gh in w.bosses.ghosts:
		if Rect2(-40, -40, 720, 440).has_point(gh.p + offset):actors.append({"sort":gh.p.y,"kind":"ghost","obj":gh})
	for a in w.arsenal.allies:
		if Rect2(-40, -40, 720, 440).has_point(a.p + offset):actors.append({"sort":a.p.y,"kind":"ally","obj":a})
	if w.stage == "notch":actors.append({"sort":w.notch.p.y,"kind":"notch"})
	actors.sort_custom(func(a, b):return a.sort < b.sort)
	for actor in actors:
		match actor.kind:
			"notch":NotchView.actor(g, offset)
			"prop":crate(g, actor.obj.p + offset, actor.obj.id, ink, actor.obj.get("has_heal", false))
			"loot":
				var o = actor.obj
				g.oval(o.p + offset, Vector2(6, 2), Color(0, 0, 0, .25))
				g.item_icon(o.kind, o.p + offset - Vector2(8, 16 + sin(w.clock * 3) * 2))
			"player":
				var p: Vector2 = w.player + offset
				g.oval(p, Vector2(8, 3), Color(0, 0, 0, .3))
				if w.invert > 0 and int(w.clock * 20) % 2 == 0:
					g.draw_actor("steve", p + Vector2(2, 0), w.facing, w.clock, w.player_moving, Color(.2, 1, 1, .5), "walk", 1.0, w.player_visual)
					g.draw_actor("steve", p - Vector2(2, 0), w.facing, w.clock, w.player_moving, Color(1, .2, .3, .5), "walk", 1.0, w.player_visual)
				g.draw_actor("steve", p, w.facing, w.clock, w.player_moving, g.invulnerable_tint(), "walk", 1.0, w.player_visual)
				g.draw_held_weapons(p)
			"ally":ally(g, actor.obj, offset)
			"ghost":ghost(g, actor.obj, offset)
			"mob":
				var m = actor.obj
				if m.kind == "notch":pass
				elif m.get("code", false):entity(g, m, offset, tone)
				else:glitched(g, m, offset)
	for o in w.orbs:
		var p: Vector2 = (o.p + offset).floor()
		if Rect2(-8, -8, 656, 376).has_point(p):g.draw_texture_rect_region(g.textures.experience_orb, Rect2(p - Vector2(4, 5), Vector2(8, 8)), Rect2(0, 0, 16, 16), Color(.5, 1, .35))
	for b in w.projectiles:g.draw_projectile(b, offset)
	shots(g, offset, tone)
	equipment(g, offset, tone)
	NotchView.air(g, offset)
	for e in w.effects:
		if not effect(g, e, offset):g.draw_effect(e, offset)
	for s in w.shards:shard(g, s, offset, ink)
	for pool in [w.particles, w.pixels]:
		for particle in pool:
			g.draw_rect(Rect2((particle.p + offset).floor(), Vector2.ONE * ceilf(particle.get("size", 2))), Color(particle.color, clampf(particle.life / .1, 0, 1)))
	darkness(g, offset, tone)
	tears(g, tone)
	# Readable HUD on a white world.
	var strip: float = .3 * (1 - tone)
	if strip > 0.01:
		for i in range(26):
			var k: float = 1 - i / 26.0
			g.draw_rect(Rect2(0, i * 2, 640, 2), Color(0, 0, 0, strip * k * k))
			g.draw_rect(Rect2(0, 358 - i * 3, 640, 3), Color(0, 0, 0, strip * k * k))
	if w.bosses.rewind_flash > 0:rewind(g, w.bosses.rewind_flash)
	boss_bar(g)
	if w.stage == "notch":NotchView.overlay(g)
	else:debug(g, offset)

# ------------------------------------------------------------------ the plane

func floor_code(g, offset: Vector2, ink: Color, tone: float):
	var w = g.world
	for gx in range(int(floorf(-offset.x / 64.0)), int(floorf((-offset.x + 640) / 64.0)) + 1):
		var x: float = gx * 64 + offset.x
		g.draw_line(Vector2(x, 0), Vector2(x, 360), Color(ink, .05), 1)
	for gy in range(int(floorf(-offset.y / 64.0)), int(floorf((-offset.y + 360) / 64.0)) + 1):
		var y: float = gy * 64 + offset.y
		g.draw_line(Vector2(0, y), Vector2(640, y), Color(ink, .05), 1)
	# Rows of the game's own source, lying on the floor.
	var first: int = int(floorf(-offset.y / 22.0))
	for row in range(first, first + 18):
		var line: String = code[posmod(row * 7, code.size())]
		var drift: float = fposmod(w.clock * (4.0 + h(row, 1) * 6.0) * (1 if row % 2 == 0 else -1) + h(row, 2) * 900.0, 900.0)
		var x: float = fposmod(drift + offset.x, 900.0) - 260.0
		var y: float = row * 22 + offset.y + 14
		var alpha: float = .13 + .07 * h(row, 3) + tone * .05
		g.draw_string(g.font, Vector2(x, y).floor(), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(ink, alpha))

## Outside the map there is nothing: the opposite colour, hard-edged.
func edges(g, offset: Vector2, ink: Color, paper: Color):
	var size: float = g.world.SIZE
	var a: Vector2 = Vector2(24, 24) + offset;var b: Vector2 = Vector2(size - 24, size - 24) + offset
	var c := Color(ink, 1.0)
	if a.x > 0:g.draw_rect(Rect2(0, 0, a.x, 360), c)
	if a.y > 0:g.draw_rect(Rect2(0, 0, 640, a.y), c)
	if b.x < 640:g.draw_rect(Rect2(b.x, 0, 640 - b.x, 360), c)
	if b.y < 360:g.draw_rect(Rect2(0, b.y, 640, 360 - b.y), c)
	for i in range(40):
		var t: float = fposmod(g.world.clock * .4 + h(i, 5), 1.0)
		var along: float = h(i, 6) * size
		for edge in [Vector2(a.x - 8 - t * 60, along + offset.y), Vector2(b.x + 8 + t * 60, along + offset.y), Vector2(along + offset.x, a.y - 8 - t * 60), Vector2(along + offset.x, b.y + 8 + t * 60)]:
			if Rect2(0, 0, 640, 360).has_point(edge):g.draw_string(g.font, edge.floor(), "01"[i % 2], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(paper, 1 - t))

func deleted(g, offset: Vector2):
	var w = g.world
	var warn: float = w.five.world.delete.warn
	for d in w.deleted:
		var r: Rect2 = Rect2(d.rect.position + offset, d.rect.size)
		if not r.intersects(Rect2(0, 0, 640, 360)):continue
		var gone: bool = d.age >= warn
		var closing: float = clampf((warn + float(w.five.world.delete.life) - d.age) / .6, 0, 1)
		for cy in range(int(r.size.y / 16) + 1):
			for cx in range(int(r.size.x / 16) + 1):
				var cell := Rect2(r.position + Vector2(cx, cy) * 16, Vector2(minf(16, r.size.x - cx * 16), minf(16, r.size.y - cy * 16)))
				if cell.size.x <= 0 or cell.size.y <= 0:continue
				var order: float = h(cx * 31 + cy, 9)
				if gone:
					if order > closing:continue
					g.draw_rect(cell, Color(.1, 0, .09))
				elif order < d.age / warn * 1.2:
					for q in range(4):
						g.draw_rect(Rect2(cell.position + Vector2(q % 2, q / 2) * 8, cell.size / 2), Color(.97, 0, .86) if (q % 2 + q / 2) % 2 == 0 else Color(0, 0, 0))
		if gone:
			g.draw_rect(r, Color(.97, 0, .86, .5 * closing), false, 1)
			for i in range(10):
				var t: float = fposmod(w.clock * .7 + h(i, 10), 1.0)
				g.draw_string(g.font, (r.position + Vector2(h(i, 11) * r.size.x, t * r.size.y)).floor(), "01"[i % 2], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.3, 1, .4, .7 * (1 - t) * closing))

func crate(g, p: Vector2, id: int, ink: Color, heal: bool = false):
	g.oval(p, Vector2(9, 3), Color(0, 0, 0, .25))
	var r := Rect2(p - Vector2(8, 17), Vector2(16, 16))
	var c: Color = Color(1, .45, .4) if heal and g.world.crate_timer < 74.0 else Color(.4, .9, .5)
	g.draw_rect(r, CARD)
	g.draw_rect(r, Color(c, .8), false, 1)
	g.draw_string(g.font, (p + Vector2(-6, -6)).floor(), "{}" if id % 2 else "[]", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)

# ------------------------------------------------------------------ code entities

## Lines of an entity as [[text, colour], ...] per line.
func lines_of(w, m: Dictionary) -> Array:
	match m.kind:
		"token":return [[[m.get("word", "id"), TEXT]]]
		"for_loop":
			var n: int = 3 + int(w.time / 240.0)
			var body: Array = [["  i = ", TEXT], [str(m.iter), NUM], [";", TEXT]] if m.iter >= 0 else [["  hit();", TEXT]]
			return [[["for ", FLOW], ["(", TEXT], ["int ", KEY], ["i < ", TEXT], [str(n), NUM], ["; i++) {", TEXT]], body, [["}", TEXT]]]
		"while_loop":return [[["while ", FLOW], ["(", TEXT], ["false" if m.broken else "true", Color(.95, .35, .3) if m.broken else NUM], [") {", TEXT]], [["  chase();", TEXT]], [["}", TEXT]]]
		"condition":return [[["true", NUM]]]
		"if_else":
			var live: int = int(m.get("branch", -1)) if float(m.get("branch_age", 9.0)) < .5 else -1
			return [[["if ", FLOW], ["(x < me) {", TEXT]], [["  shot();", Color.WHITE if live == 0 else TEXT]], [["} ", TEXT], ["else ", FLOW], ["{", TEXT]], [["  slam();", Color.WHITE if live == 1 else TEXT]], [["}", TEXT]]]
		"function":return [[["void ", KEY], ["call", Color(.5, .75, 1)], ["() {", TEXT]], [["  spawn(", TEXT], ["3", NUM], [");", TEXT]], [["}", TEXT]]]
		"arg":return [[["arg" + str(m.get("index", 0)), Color(.5, .75, 1)]]]
		"recursion":return [[["f", Color(.5, .75, 1)], ["(", TEXT], [str(m.depth), NUM], [");", TEXT]]]
		"try_catch":return [[["try ", FLOW], ["{ }", TEXT]], [["catch ", FLOW if m.shield else Color(.4, .4, .45)], ["(", TEXT], ["Exception", KEY], [" e)", TEXT]]]
		"null_ref":return [[["null", Color(.95, .35, .3)]]]
		"array":
			var cells: Array = [["int", KEY], ["[] ", TEXT]]
			for i in range(5):cells.append(["[" + str(i) + "]", Color.WHITE if i == m.index else TEXT])
			return [cells]
	return [[["?", TEXT]]]

func entity(g, m: Dictionary, offset: Vector2, tone: float):
	var w = g.world
	var p: Vector2 = m.p + offset
	if m.kind == "hijack":
		double(g, m, p);return
	if m.kind == "terminal":
		terminal(g, m, p, tone);return
	if m.kind == "clone":
		clone(g, m, p);return
	if m.kind == "loop_boss":
		loop_card(g, m, p, tone);return
	var alpha: float = 1.0
	if m.kind == "null_ref":alpha = clampf(.07 + m.reveal * 3.0, 0, 1)
	var lines: Array = lines_of(w, m)
	var wide: float = 0.0
	for line in lines:
		var total: float = 0.0
		for part in line:total += width(g, part[0])
		wide = maxf(wide, total)
	var size := Vector2(wide + 8, lines.size() * 9 + 5)
	var bob: float = round(sin(w.clock * 3.0 + m.id) * 1.5)
	var origin: Vector2 = (p - Vector2(size.x / 2, size.y + 7 + bob)).floor()
	g.oval(p, Vector2(size.x * .35, 3), Color(0, 0, 0, .22 + .1 * (1 - tone)))
	if m.kind == "condition":
		var owner = w.mob_by_id(m.owner)
		if owner != null:g.draw_line(p - Vector2(0, 12), owner.p + offset - Vector2(0, 14), Color(NUM, .5), 1)
	var card: Color = Color(1, 1, 1) if m.flash > 0 and g.settings.flashes else CARD
	g.draw_rect(Rect2(origin, size), Color(card, alpha * (.94 if m.kind != "null_ref" else .5)))
	var rim: Color = Color(.45, .5, .7).lerp(Color(.6, .7, 1), tone)
	if m.kind == "while_loop" and not m.broken:rim = NUM
	if m.kind == "try_catch" and m.shield:rim = FLOW
	if m.kind == "for_loop" and m.phase == "windup":rim = Color(.95, .3, .25) if int(w.clock * 12) % 2 == 0 else rim
	g.draw_rect(Rect2(origin, size), Color(rim, alpha), false, 1)
	g.draw_rect(Rect2(origin, Vector2(2, size.y)), Color(rim, alpha))
	for i in range(lines.size()):
		var x: float = origin.x + 5
		for part in lines[i]:
			g.draw_string(g.font, Vector2(x, origin.y + 9 + i * 9), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(part[1], alpha))
			x += width(g, part[0])
	if m.kind == "try_catch" and m.shield:
		g.draw_arc(p - Vector2(0, size.y / 2 + 7), minf(size.x * .62, 34.0), -.9, .9, 10, Color(FLOW, .7), 1)
		g.draw_arc(p - Vector2(0, size.y / 2 + 7), minf(size.x * .62, 34.0), PI - .9, PI + .9, 10, Color(FLOW, .7), 1)
	if m.kind == "array":
		var cell: float = width(g, "[0]")
		var cx: float = origin.x + 5 + width(g, "int") + width(g, "[] ") + m.index * cell
		g.draw_rect(Rect2(cx, origin.y + size.y, cell, 2), Color.WHITE)
	if m.hp < m.max_hp and m.kind not in ["token","arg","condition"]:
		g.draw_rect(Rect2(origin + Vector2(0, -3), Vector2(size.x * clampf(m.hp / m.max_hp, 0, 1), 1)), Color(.95, .3, .25, alpha))

func double(g, m: Dictionary, p: Vector2):
	var w = g.world
	var line: float = clampf(w.hijack.get("left", 0.0) / float(w.five.world.hijack.limit), 0, 1)
	g.oval(p, Vector2(8, 3), Color(0, 0, 0, .3))
	var j: Vector2 = Vector2(round((h(int(w.clock * 20), 20) - .5) * 4), 0)
	g.draw_actor("steve", p + j + Vector2(2, 0), m.dir, w.clock, m.moving, Color(.1, 1, 1, .55), "walk", 1.0, w.player_visual)
	g.draw_actor("steve", p + j - Vector2(2, 0), m.dir, w.clock, m.moving, Color(1, .1, .4, .55), "walk", 1.0, w.player_visual)
	g.draw_actor("steve", p + j, m.dir, w.clock, m.moving, Color(1.6, 1.6, 1.6) if m.flash > 0 else Color(.25, .25, .3), "walk", 1.0, w.player_visual)
	g.draw_rect(Rect2(p + Vector2(-14, -40), Vector2(28, 3)), Color(0, 0, 0, .6))
	g.draw_rect(Rect2(p + Vector2(-14, -40), Vector2(28 * clampf(m.hp / m.max_hp, 0, 1), 2)), Color(.95, .3, .25))
	g.draw_rect(Rect2(p + Vector2(-14, -36), Vector2(28 * line, 1)), Color(.3, 1, .9))

## A vanilla mob whose sprite no longer holds together.
func glitched(g, m: Dictionary, offset: Vector2):
	var w = g.world
	var p: Vector2 = m.p + offset
	var tick: int = int(w.clock * 12) + m.id
	var tint := Color(1.8, 1.8, 1.8) if g.settings.flashes and m.flash > 0 else Color.WHITE
	if m.get("glitch", false) and h(tick, 30) > .55:
		var d: float = round((h(tick, 31) - .5) * 8)
		g.draw_actor(m.kind, p + Vector2(d, 0), m.visual_dir, m.animation, m.moving, Color(.1, 1, 1, .5), m.phase, 1.0, m.visual)
		g.draw_actor(m.kind, p - Vector2(d, 0), m.visual_dir, m.animation, m.moving, Color(1, .1, .5, .5), m.phase, 1.0, m.visual)
	g.draw_actor(m.kind, p, m.visual_dir, m.animation, m.moving, tint, m.phase, 1.0, m.visual)
	if m.get("glitch", false):
		var q: Vector2 = p + Vector2(-8 + int(h(m.id, 32) * 3) * 4, -26 + int(h(tick / 4, 33) * 4) * 5)
		for i in range(4):g.draw_rect(Rect2(q + Vector2(i % 2, i / 2) * 4, Vector2(4, 4)), Color(.97, 0, .86) if (i % 2 + i / 2) % 2 == 0 else Color(0, 0, 0))
	if m.kind == "skeleton" and m.visual.state in ["windup", "attack", "recover"]:
		g.draw_bow(p + m.visual_dir * 8 + Vector2(0, -10), m.visual_dir, clampf(m.visual.time / 0.5, 0, 1) if m.visual.state == "windup" else 0)

func shots(g, offset: Vector2, tone: float):
	var w = g.world
	for s in w.shots:
		var p: Vector2 = s.p + offset
		if not Rect2(-20, -20, 680, 400).has_point(p):continue
		if not s.icon.is_empty():
			var dir: Vector2 = s.v.normalized()
			if s.delay > 0:
				g.draw_line(p, p + dir * 150, Color(.95, .3, .25, .35), 1)
				var jitter: Vector2 = Vector2(h(int(w.clock * 30) + int(s.p.x), 40) - .5, h(int(w.clock * 30), 41) - .5) * 3
				g.item_icon(s.icon, p - Vector2(8, 8) + jitter)
			else:
				g.draw_set_transform(p, dir.angle() + PI / 4, Vector2.ONE)
				g.item_icon(s.icon, Vector2(-8, -8))
				g.draw_set_transform(Vector2.ZERO)
			continue
		var c: Color = Color(.95, .3, .25) if s.glyph == "throw" else Color(1, .75, .3)
		g.draw_rect(Rect2((p - Vector2(5, 5)).floor(), Vector2(10, 10)), Color(CARD, .9))
		g.draw_rect(Rect2((p - Vector2(5, 5)).floor(), Vector2(10, 10)), c, false, 1)
		g.draw_string(g.font, (p + Vector2(-3, 3)).floor(), "!" if s.glyph == "throw" else s.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)

func shard(g, s: Dictionary, offset: Vector2, ink: Color):
	var k: float = s.age / .6
	for i in range(7):
		var dir := Vector2.from_angle(h(s.seed * 13 + i, 50) * TAU)
		var p: Vector2 = s.p + offset + dir * (6 + k * 34 * (.5 + h(s.seed + i, 51))) + Vector2(0, k * k * 14)
		g.draw_string(g.font, p.floor(), "{};=01()"[(s.seed + i) % 8], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color([KEY, FLOW, NUM, ink][i % 4], 1 - k))

# ------------------------------------------------------------------ screen layers

func darkness(g, offset: Vector2, tone: float):
	if tone < 0.02:return
	var p: Vector2 = g.world.player + offset - Vector2(0, 10)
	var r: float = 300.0 * (1.0 + .18 * g.world.items.get("light_block", 0))
	var a: float = tone * .72
	var box := Rect2(p - Vector2(r, r), Vector2(r, r) * 2)
	g.draw_texture_rect(vignette, box, false, Color(1, 1, 1, a))
	var c := Color(0, 0, 0, a)
	if box.position.x > 0:g.draw_rect(Rect2(0, 0, box.position.x, 360), c)
	if box.end.x < 640:g.draw_rect(Rect2(box.end.x, 0, 640 - box.end.x, 360), c)
	if box.position.y > 0:g.draw_rect(Rect2(maxf(0, box.position.x), 0, minf(640, box.end.x) - maxf(0, box.position.x), box.position.y), c)
	if box.end.y < 360:g.draw_rect(Rect2(maxf(0, box.position.x), box.end.y, minf(640, box.end.x) - maxf(0, box.position.x), 360 - box.end.y), c)

## Bars of the other colour during a switch and during lag.
func tears(g, tone: float):
	var w = g.world
	var switching: bool = w.time > float(w.five.phases.dark_at) - 3.0 and (tone > 0.01 and tone < 0.99 or absf(tone - prev_tone) > .5)
	prev_tone = tone
	if w.lag > 0:
		for i in range(7):
			var y: float = h(int(w.lag * 40) + i, 60) * 360
			g.draw_rect(Rect2(0, y, 640, 2 + h(i, 61) * 9), Color(.97, 0, .86, .25) if i % 2 else Color(.2, 1, 1, .25))
		g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, .06))
	if switching and g.settings.flashes:
		for i in range(5):
			var y: float = h(int(w.clock * 30) + i, 62) * 360
			g.draw_rect(Rect2(0, y, 640, 3 + h(i, 63) * 14), Color(1 - tone, 1 - tone, 1 - tone, .35))
var prev_tone := 0.0

## The F3 screen: the world prints what it is about to do.
func debug(g, offset: Vector2):
	var w = g.world
	var names := {"lag":"tick_skip()","items":"spawn_items(player)","delete":"delete_region()","hijack":"input.swap(player)"}
	g.text_at("tps: %d  ent: %d  phase: %s" % [20 if w.lag <= 0 else 0, w.mobs.size(), w.phase_name()], Vector2(12, 62), 8, Color(.4, 1, .5, .55))
	if w.invert > 0:g.text_at("input: INVERTED %.1f" % w.invert, Vector2(12, 86), 8, Color(1, .3, .35, .9))
	if not w.hijack.is_empty():g.text_at("double: %.1f" % w.hijack.left, Vector2(12, 86), 8, Color(.3, 1, .9, .9))
	if w.hint.is_empty() or w.bosses.active():return
	var left: float = maxf(0, w.hint.left)
	var blink: bool = int(w.clock * 8) % 2 == 0
	g.text_at("next: %s in %.1f" % [names.get(w.hint.id, w.hint.id), left], Vector2(12, 74), 8, Color(1, .85, .3, 1.0 if blink else .6))
	if w.hint.id == "delete" and w.hint.left > 0:
		var size := Vector2(w.five.world.delete.size[0], w.five.world.delete.size[1])
		g.draw_rect(Rect2(w.hint.p + offset - size / 2, size), Color(1, .85, .3, .7 if blink else .3), false, 1)

# ------------------------------------------------------------------ equipment

func equipment(g, offset: Vector2, tone: float):
	var w = g.world;var ar = w.arsenal
	var line: Color = Color(.15, .15, .2).lerp(Color(.9, .92, 1), tone)
	for c in ar.commands:
		var p: Vector2 = c.p + offset
		var k: float = 1.0 - c.wait / .5
		g.draw_arc(p, c.radius, 0, TAU, 32, Color(.95, .62, .25, .35 + .4 * k), 1)
		g.draw_arc(p, c.radius * clampf(k, 0, 1), 0, TAU, 32, Color(.95, .62, .25, .5), 1)
	for pa in ar.pastes:
		var rect := Rect2(pa.p + offset - pa.size / 2.0, pa.size)
		if not pa.get("hit", false):
			var k: float = clampf(pa.age / maxf(.01, pa.age + pa.wait), 0, 1)
			dashed(g, rect, Color(1, .85, .3, .9))
			var lift: float = (1 - k) * 46
			g.draw_rect(Rect2(rect.position - Vector2(0, lift), rect.size), Color(1, .85, .3, .12 + .1 * k))
			dashed(g, Rect2(rect.position - Vector2(0, lift), rect.size), Color(1, .85, .3, .5))
		else:
			var t: float = (pa.age - pa.hit_at) / .4
			g.draw_rect(rect, Color(1, .85, .3, .45 * (1 - t)))
			dashed(g, rect.grow(t * 8), Color(1, .85, .3, 1 - t))
	if w.build.has("barrier"):
		var s: Dictionary = ar.stats(w, "barrier")
		var count: int = int(s.count)
		for k in range(count):
			var q: Vector2 = w.player + offset + Vector2.from_angle(ar.orbit + k * TAU / count) * s.radius
			var flick: float = .55 + .45 * sin(w.clock * 9 + k)
			g.draw_rect(Rect2((q - Vector2(5, 15)).floor(), Vector2(10, 10)), Color(1, .15, .15, .18 * flick))
			g.draw_texture_rect(g.textures.icon_barrier, Rect2((q - Vector2(6, 16)).floor(), Vector2(12, 12)), false, Color(1, 1, 1, .45 + .4 * flick))
	for b in ar.beams:
		var k: float = b.age / (.35 if b.mode != "light" else .45)
		if k >= 1:continue
		var a: Vector2 = b.a + offset - Vector2(0, 10);var e: Vector2 = b.b + offset - Vector2(0, 10)
		var c: Color = Color(.75, .4, 1) if b.mode == "slow" else Color(1, .45, .3) if b.mode == "shove" else Color(1, 1, .8)
		g.draw_line(a, e, Color(c, .9 * (1 - k)), 3 if b.mode == "light" else 2)
		g.draw_line(a, e, Color(1, 1, 1, .8 * (1 - k)), 1)
		if b.mode != "light":
			g.draw_string(g.font, (e + Vector2(-14, -8)).floor(), "slow" if b.mode == "slow" else "push", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(c, 1 - k))
	for n in ar.notes:
		var k: float = n.age / .7
		var p: Vector2 = n.p + offset - Vector2(0, 22 + k * 12)
		if n.text.is_empty():
			g.draw_circle(n.p + offset - Vector2(0, 12), 6 * (1 - k) + 2, Color(1, .3, .3, .6 * (1 - k)));continue
		var wd: float = width(g, n.text)
		g.draw_rect(Rect2((p - Vector2(wd / 2 + 3, 8)).floor(), Vector2(wd + 6, 11)), Color(0, 0, 0, .6 * (1 - k)))
		g.draw_string(g.font, (p - Vector2(wd / 2, 0)).floor(), n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.4, 1, .5, 1 - k))
	if ar.compass_ready > 0 and w.items.has("recovery_compass"):
		g.draw_arc(w.player + offset - Vector2(0, 34), 3, -PI / 2, -PI / 2 + TAU * (1 - ar.compass_ready / float(w.db.data.five_arsenal.rules.compass_cooldown[mini(w.items.recovery_compass, 5) - 1])), 10, Color(.3, .9, 1, .6), 1)

func dashed(g, r: Rect2, c: Color):
	for edge in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.position.x, r.end.y), r.end], [r.position, Vector2(r.position.x, r.end.y)], [Vector2(r.end.x, r.position.y), r.end]]:
		var a: Vector2 = edge[0];var b: Vector2 = edge[1];var n: int = int(a.distance_to(b) / 6)
		for i in range(0, n, 2):g.draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), c, 1)

func ally(g, a: Dictionary, offset: Vector2):
	var w = g.world
	var p: Vector2 = a.p + offset
	var fade: float = 1.0 if w.evolved.has("spawn_egg") else clampf(a.life / 1.0, 0, 1)
	g.oval(p, Vector2(8, 3), Color(0, 0, 0, .3))
	g.draw_actor(a.kind, p, a.dir, a.age, a.moving, Color(.75, 1, .8, fade), "walk", 1.0, a.visual)
	g.draw_rect(Rect2((p + Vector2(-1, -32)).floor(), Vector2(3, 3)), Color(.3, 1, .45, fade))

func effect(g, e: Dictionary, offset: Vector2) -> bool:
	var p: Vector2 = e.p + offset
	var k: float = e.age / e.total
	match e.kind:
		"ch5_spawn":
			for i in range(10):
				var d := Vector2.from_angle(i * TAU / 10) * (4 + k * 18)
				g.draw_rect(Rect2((p + d - Vector2(0, 12)).floor(), Vector2(2, 2)), Color(.4, 1, .5, 1 - k))
		"ch5_kill":
			g.draw_circle(p, e.radius * (.4 + .6 * k), Color(1, .55, .2, .3 * (1 - k)))
			g.draw_arc(p, e.radius, 0, TAU, 32, Color(1, .8, .4, 1 - k), 2)
		"ch5_rewind":
			var to: Vector2 = e.to + offset
			for i in range(12):
				var t := float(i) / 11.0
				g.draw_rect(Rect2((p.lerp(to, t) - Vector2(1, 14 + sin(t * PI) * 10)).floor(), Vector2(2, 2)), Color(.3, .9, 1, (1 - k) * (.4 + .6 * t)))
		_:return false
	return true

# ------------------------------------------------------------------ mini-bosses

func terminal(g, m: Dictionary, p: Vector2, tone: float):
	var w = g.world
	var screen := Rect2((p - Vector2(66, 66)).floor(), Vector2(132, 54))
	g.oval(p, Vector2(30, 6), Color(0, 0, 0, .3))
	g.draw_rect(Rect2(p - Vector2(6, 12), Vector2(12, 12)), Color(.22, .22, .25))
	g.draw_rect(Rect2(p - Vector2(18, 4), Vector2(36, 5)), Color(.28, .28, .32))
	g.draw_rect(screen.grow(4), Color(.75, .74, .7) if m.flash <= 0 else Color.WHITE)
	g.draw_rect(screen.grow(4), Color(.3, .3, .3), false, 1)
	g.draw_rect(screen, Color(.01, .04, .02))
	var lines: Array = w.bosses.screen
	for i in range(lines.size()):
		var l: Dictionary = lines[i]
		var shown: int = mini(l.text.length(), int(l.age * 30))
		g.draw_string(g.font, screen.position + Vector2(3, 10 + i * 9), l.text.substr(0, shown), HORIZONTAL_ALIGNMENT_LEFT, screen.size.x - 6, 8, Color(.35, 1, .45, .95))
	if int(w.clock * 2) % 2 == 0:g.draw_rect(Rect2(screen.position + Vector2(3, 3 + lines.size() * 9), Vector2(5, 7)), Color(.35, 1, .45))
	for y in range(int(screen.position.y), int(screen.end.y), 2):g.draw_line(Vector2(screen.position.x, y), Vector2(screen.end.x, y), Color(0, 0, 0, .25))
	var locked: bool = m.get("locked", false)
	g.draw_rect(screen.grow(6), Color(.35, 1, .45, .6) if locked else Color(1, .3, .3, .5 + .4 * sin(w.clock * 8)), false, 1)
	g.draw_string(g.font, screen.position + Vector2(0, -9), "[locked]" if locked else "[open]", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.35, 1, .45) if locked else Color(1, .35, .35))

func clone(g, m: Dictionary, p: Vector2):
	var w = g.world
	var j: Vector2 = Vector2(round((h(int(w.clock * 14) + m.id, 70) - .5) * 3), 0)
	g.oval(p, Vector2(8, 3), Color(0, 0, 0, .3))
	if m.get("build", {}).has("barrier"):
		for k in range(mini(4, int(m.build.barrier / 2) + 1)):
			var q: Vector2 = p + Vector2.from_angle(m.orbit + k * TAU / 3) * 30.0
			g.draw_texture_rect(g.textures.icon_barrier, Rect2((q - Vector2(5, 14)).floor(), Vector2(10, 10)), false, Color(1, 1, 1, .6))
	g.draw_actor("steve", p + j + Vector2(1, 0), m.dir, w.clock, m.moving, Color(.1, 1, 1, .5), "walk", 1.0, m.visual)
	g.draw_actor("steve", p + j - Vector2(1, 0), m.dir, w.clock, m.moving, Color(1, .1, .4, .5), "walk", 1.0, m.visual)
	g.draw_actor("steve", p + j, m.dir, w.clock, m.moving, Color(1.7, 1.7, 1.7) if m.flash > 0 else Color(.78, .88, 1), "walk", 1.0, m.visual)
	var name: String = "Steve (1)"
	var wd: float = width(g, name)
	g.draw_rect(Rect2((p + Vector2(-wd / 2 - 2, -44)).floor(), Vector2(wd + 4, 10)), Color(0, 0, 0, .45))
	g.draw_string(g.font, (p + Vector2(-wd / 2, -36)).floor(), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, .9))
	g.draw_rect(Rect2(p + Vector2(-14, -32), Vector2(28 * clampf(m.hp / m.max_hp, 0, 1), 2)), Color(.95, .3, .25))
	if m.get("haste", 0.0) > 0:
		for k in range(4):g.draw_rect(Rect2((p + Vector2(-8 + k * 5, -4 - fposmod(w.clock * 30 + k * 5, 14))).floor(), Vector2(1, 3)), Color(.5, .8, 1, .7))

func loop_card(g, m: Dictionary, p: Vector2, tone: float):
	var w = g.world
	var lp: Dictionary = w.bosses.loop
	var i: int = lp.get("i", 0)
	var k: float = clampf(float(lp.get("age", 0.0)) / float(w.five.bosses.loop.iteration), 0, 1)
	var lines: Array = [[["while ", FLOW], ["(", TEXT], ["true", NUM], [") {", TEXT]], [["  i = ", TEXT], [str(i), NUM], [";", TEXT]], [["  world.rollback(", TEXT], ["10", NUM], [");", TEXT]], [["}", TEXT]]]
	var wd := 0.0
	for line in lines:
		var t := 0.0
		for part in line:t += width(g, part[0])
		wd = maxf(wd, t)
	var size := Vector2(wd + 16, lines.size() * 11 + 10)
	var origin: Vector2 = (p - Vector2(size.x / 2, size.y + 14 + round(sin(w.clock * 2) * 2))).floor()
	g.oval(p, Vector2(30, 6), Color(0, 0, 0, .3))
	g.draw_arc(p - Vector2(0, size.y / 2 + 14), size.x * .7, -PI / 2, -PI / 2 + TAU * k, 40, Color(.95, .7, .3, .8), 2)
	g.draw_arc(p - Vector2(0, size.y / 2 + 14), size.x * .7, 0, TAU, 40, Color(.95, .7, .3, .15), 1)
	g.draw_rect(Rect2(origin, size), Color(1, 1, 1) if m.flash > 0 and g.settings.flashes else CARD)
	g.draw_rect(Rect2(origin, size), Color(.95, .7, .3), false, 1)
	g.draw_rect(Rect2(origin, Vector2(3, size.y)), Color(.95, .7, .3))
	for li in range(lines.size()):
		var x: float = origin.x + 8
		for part in lines[li]:
			g.draw_string(g.font, Vector2(x, origin.y + 13 + li * 11), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, part[1])
			x += width(g, part[0])
	var need: float = m.max_hp * float(w.five.bosses.loop.break_share)
	var done: float = clampf(float(lp.get("dealt", 0.0)) / need, 0, 1)
	g.draw_rect(Rect2(origin + Vector2(0, size.y + 3), Vector2(size.x, 3)), Color(0, 0, 0, .5))
	g.draw_rect(Rect2(origin + Vector2(0, size.y + 3), Vector2(size.x * done, 3)), Color(.35, 1, .45) if done >= 1 else Color(.95, .7, .3))

func ghost(g, gh: Dictionary, offset: Vector2):
	var w = g.world
	var p: Vector2 = gh.p + offset
	g.draw_actor("steve", p, gh.dir, w.clock, true, Color(.6, .8, 1, .38), "walk", 1.0, gh.visual)
	g.draw_string(g.font, (p + Vector2(-8, -34)).floor(), "i-" + str(w.bosses.loop.get("i", 0) - gh.n + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.6, .8, 1, .7))

func rewind(g, k: float):
	for i in range(9):
		var y: float = h(i + int(g.world.clock * 20), 80) * 360
		g.draw_rect(Rect2(0, y, 640, 2 + h(i, 81) * 6), Color(.95, .7, .3, .35 * k / .5))
	g.centered("<<", 170, 32, Color(1, 1, 1, k / .5), true)

func boss_bar(g):
	var w = g.world
	var target = null
	var title := ""
	if not w.bosses.terminal.is_empty():
		target = w.mob_by_id(w.bosses.terminal.id);title = "Терминал"
		var c = w.mob_by_id(w.bosses.terminal.clone) if w.bosses.terminal.clone >= 0 else null
		if c != null:target = c;title = "Steve (1)"
	elif not w.bosses.loop.is_empty():
		target = w.mob_by_id(w.bosses.loop.id);title = "Бесконечный цикл"
	if target == null:return
	g.centered(title, 41, 8, Color.WHITE, true)
	g.draw_rect(Rect2(211, 46, 218, 5), Color(.15, .15, .2))
	g.draw_rect(Rect2(212, 47, 216 * clampf(target.hp / target.max_hp, 0, 1), 3), Color(.35, 1, .45) if title == "Бесконечный цикл" else Color(.95, .35, .3))
