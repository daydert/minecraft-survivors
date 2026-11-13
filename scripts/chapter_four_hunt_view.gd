extends RefCounted
## Presentation of chapter_four_hunt.gd: rescue rings, stirring pillars, rising
## ground, affix marks, marksman lasers, butcher/crucified tells and the HUD.
const Tells = preload("res://scripts/chapter_four_tells.gd")
const BossBar = preload("res://scripts/ui/boss_bar.gd")
const AFFIX_COLORS = {"vampiric": Color(.85, .08, .12), "volatile": Color(1, .55, .15), "shielded": Color(.55, .75, 1), "frenzied": Color(.95, .25, .7)}

static func ellipse(g, p: Vector2, r: Vector2, from: float, to: float, color: Color, width: float = 1.0):
	var points := PackedVector2Array()
	var steps := maxi(6, int(absf(to - from) / TAU * 40))
	for i in range(steps + 1):
		var a: float = lerpf(from, to, float(i) / steps)
		points.append((p + Vector2(cos(a) * r.x, sin(a) * r.y)).floor())
	g.draw_polyline(points, color, width)

static func wedge(g, p: Vector2, dir: Vector2, reach: float, arc: float, k: float, clock: float):
	var points := PackedVector2Array([p])
	for i in range(13):
		var a: float = dir.angle() - arc * .5 + arc * i / 12.0
		points.append(p + Vector2(cos(a), sin(a) * .62) * reach)
	g.draw_colored_polygon(points, Color(.75, .05, .05, .08 + .2 * k))
	var edge := PackedVector2Array()
	for i in range(13):
		var a: float = dir.angle() - arc * .5 + arc * i / 12.0
		edge.append((p + Vector2(cos(a), sin(a) * .62) * reach * (.55 + .45 * k)).floor())
	g.draw_polyline(edge, Tells.hot(k, clock), 1)

static func floor_layer(g, offset: Vector2):
	var w = g.world
	var h = w.hunt
	if h.data.is_empty():return
	var view := Rect2(-60, -60, 760, 480)
	for mark in h.pillars(w):
		var p: Vector2 = mark.p + offset
		if not view.has_point(p) or not h.hanging(mark):continue
		var radius: float = float(h.data.rescue.radius)
		var d: float = w.player.distance_to(mark.p)
		if mark.get("state", "") == "stirring":
			var left: float = clampf((mark.stir_until - w.clock) / float(h.data.stir.warn), 0, 1)
			var beat: float = .5 + .5 * sin(w.clock * lerpf(14.0, 4.0, left))
			g.oval(p + Vector2(0, 2), Vector2(26, 9), Color(.55, .02, .03, .25 + .25 * beat))
		if d < radius * 4 or mark.get("progress", 0.0) > 0:
			var k: float = clampf(mark.get("progress", 0.0) / float(h.data.rescue.time), 0, 1)
			var near: bool = d < radius
			var rr := Vector2(radius, radius * .45)
			ellipse(g, p + Vector2(0, 2), rr, 0, TAU, Color(.9, .8, .6, .35 if near else .18), 1)
			if k > 0:
				ellipse(g, p + Vector2(0, 2), rr, -PI / 2, -PI / 2 + TAU * k, Color(1, .86, .45, .95), 2)
			if not near and k <= 0 and d < radius * 3:
				var hint := "Встань рядом, чтобы снять"
				var width: float = g.font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
				g.text_at(hint, (p + Vector2(-width / 2, 20)).floor(), 8, Color(.9, .85, .75, .7))
	for r in h.rises:
		var p: Vector2 = r.p + offset
		if not view.has_point(p):continue
		var k: float = clampf((w.clock - r.born) / maxf(.01, r.at - r.born), 0, 1)
		Tells.bulge(g, p, k, int(r.seed), w.clock)
		g.oval(p, Vector2(7, 3) * (.5 + .5 * k), Color(.05, .02, .02, .35 * k))
	for b in h.blasts:
		var k: float = clampf((w.clock - b.born) / maxf(.01, b.at - b.born), 0, 1)
		Tells.ring(g, b.p + offset, b.radius, k, w.clock)
	for m in w.mobs:
		if m.hp <= 0:continue
		var p: Vector2 = m.p + offset
		if not view.has_point(p):continue
		if m.has("affixes"):affix_floor(g, m, p, w)
		if not m.has("form"):continue
		var k: float = clampf(m.get("phase_age", 0.0) / maxf(.01, m.get("phase_duration", 1.0)), 0, 1)
		match m.form:
			"marksman":
				if m.phase == "windup":laser(g, m, p, k, w)
			"crucified":
				if m.phase == "windup":
					if m.cast == "ram":Tells.lane(g, p, p + m.charge * float(m.ai.dash_speed) * float(m.ai.ram_attack), m.radius + 6, k, int(m.id) * 7, w.clock)
					else:wedge(g, p, m.charge, float(m.ai.reach) + 12, float(m.ai.arc), k, w.clock)
			"butcher":
				if m.phase == "windup":
					if m.cast == "lunge":Tells.lane(g, p, p + m.charge * float(m.ai.dash_speed) * float(m.ai.lunge_attack), m.radius + 7, k, int(m.id) * 5, w.clock)
					else:wedge(g, p, m.charge, float(m.ai.reach) + 14, float(m.ai.arc), k, w.clock)
				g.oval(p + Vector2(0, 1), Vector2(20, 6), Color(.25, 0, 0, .25 + .1 * sin(w.clock * 3)))

static func laser(g, m: Dictionary, p: Vector2, k: float, w):
	var locked: bool = m.timer <= float(m.ai.lock)
	var a: Vector2 = p - Vector2(0, 14)
	var length: float = float(m.ai.range)
	var color := Color(1, .15, .1, .25 + .45 * k) if not locked else Color(1, .9, .6, .55 + .45 * sin(w.clock * 60))
	var steps := int(length / 6)
	for i in range(1, steps):
		if not locked and (i + int(w.clock * 20)) % 3 == 0:continue
		var q: Vector2 = (a + m.charge * i * 6).floor()
		g.draw_rect(Rect2(q, Vector2(2 if locked else 1, 1)), color)
	if locked:g.draw_line(a, a + m.charge * length, Color(1, .3, .2, .18), 3)

static func affix_floor(g, m: Dictionary, p: Vector2, w):
	var list: Array = m.affixes
	for i in range(list.size()):
		var c: Color = AFFIX_COLORS[list[i]]
		var r := Vector2(m.radius + 7 + i * 4, (m.radius + 7 + i * 4) * .42)
		var spin: float = w.clock * (1.2 if i == 0 else -1.6)
		for j in range(3):ellipse(g, p + Vector2(0, 2), r, spin + j * TAU / 3, spin + j * TAU / 3 + 1.4, Color(c, .7), 1)
	if "shielded" in list and m.get("shield_n", 0) >= int(w.hunt.data.affixes.shield_needed):
		var radius: float = float(w.hunt.data.affixes.shield_radius)
		for other in w.mobs:
			if other.hp > 0 and other.id != m.id and not other.get("boss", false) and other.p.distance_to(m.p) < radius:
				var q: Vector2 = other.p + (p - m.p) - Vector2(0, 10)
				g.draw_line(q, p - Vector2(0, 16), Color(.55, .75, 1, .22 + .12 * sin(w.clock * 6 + other.id)), 1)

## Drawn over actors: shield shells, frenzy steam, snipe streaks.
static func air_layer(g, offset: Vector2):
	var w = g.world
	if w.hunt.data.is_empty():return
	for b in w.enemy_shots:
		if not b.get("snipe", false):continue
		var p: Vector2 = b.p + offset - Vector2(0, 8)
		g.draw_line(p - b.dir * 22, p, Color(1, .85, .6, .35), 1)
		g.draw_line(p - b.dir * 10, p, Color(1, .95, .8, .8), 1)
	for m in w.mobs:
		if m.hp <= 0 or not m.has("affixes"):continue
		var p: Vector2 = m.p + offset
		if "shielded" in m.affixes and m.get("shield_n", 0) >= int(w.hunt.data.affixes.shield_needed):
			ellipse(g, p - Vector2(0, 16), Vector2(m.radius + 6, m.radius + 12), 0, TAU, Color(.6, .8, 1, .3 + .15 * sin(w.clock * 5)), 1)
		if m.get("frenzy", false):
			for j in range(3):
				var phase: float = fposmod(w.clock * 1.4 + j * .33, 1)
				g.draw_rect(Rect2((p + Vector2((j - 1) * 6, -30 - phase * 12)).floor(), Vector2(2, 2)), Color(.95, .3, .7, (1 - phase) * .7))
		if "vampiric" in m.affixes:
			var phase: float = fposmod(w.clock * .9 + m.id * .1, 1)
			g.draw_rect(Rect2((p + Vector2(sin(m.id) * 5, -24 + phase * 18)).floor(), Vector2(1, 2)), Color(.8, .05, .08, 1 - phase))
		if "volatile" in m.affixes and int(w.clock * 6 + m.id) % 4 == 0:
			g.draw_rect(Rect2((p + Vector2(cos(w.clock * 9) * 7, -18 + sin(w.clock * 7) * 6)).floor(), Vector2(2, 2)), Color(1, .7, .3, .8))

static func effect(g, e: Dictionary, offset: Vector2) -> bool:
	var p: Vector2 = e.p + offset
	var k: float = clampf(e.age / e.total, 0, 1)
	match e.kind:
		"ch4h_sweep":
			var arc: float = e.arc
			var a0: float = e.dir.angle() - arc * .5
			for layer in range(3):
				var r: float = e.reach * (.7 + .15 * layer)
				var points := PackedVector2Array()
				var reach_k: float = minf(1, k * 2.4)
				for i in range(11):
					var a: float = a0 + arc * reach_k * i / 10.0
					points.append(p + Vector2(cos(a), sin(a) * .62) * r - Vector2(0, 10))
				g.draw_polyline(points, Color(1, .9 - layer * .25, .8 - layer * .3, (1 - k) * (.9 - layer * .25)), 2 - layer * .5)
		"ch4h_freed":
			for j in range(14):
				var phase: float = fposmod(k + j * .071, 1)
				var q: Vector2 = p + Vector2(sin(j * 2.4) * 16, -10 - phase * 46 * k)
				g.draw_rect(Rect2(q.floor(), Vector2(1, 2)), Color(1, .9, .6, (1 - k) * .9))
			g.oval(p + Vector2(0, 2), Vector2(18 + 20 * k, 6 + 7 * k), Color(1, .85, .5, (1 - k) * .3))
		"ch4h_tear":
			for j in range(10):
				var d: Vector2 = Vector2.from_angle(j * 2.4 - PI / 2)
				var q: Vector2 = p - Vector2(0, 40) + d * 40 * k + Vector2(0, 60 * k * k)
				g.draw_rect(Rect2(q.floor(), Vector2(3, 2)), Color(.4, .3, .25, 1 - k))
		"ch4h_drain":
			var end: Vector2 = e.end + offset - Vector2(0, 16)
			var start: Vector2 = p - Vector2(0, 12)
			for j in range(6):
				var t: float = fposmod(k * 1.5 + j / 6.0, 1)
				g.draw_rect(Rect2(start.lerp(end, t).floor() + Vector2(0, sin(t * PI) * -8), Vector2(2, 2)), Color(.85, .05, .1, 1 - k))
		"ch4h_frenzy", "ch4h_stagger":
			var c := Color(.95, .3, .7) if e.kind == "ch4h_frenzy" else Color(1, .85, .5)
			ellipse(g, p - Vector2(0, 14), Vector2(10 + 18 * k, 6 + 9 * k), 0, TAU, Color(c, 1 - k), 1)
		"ch4h_raise":
			for j in range(6):
				var q: Vector2 = p + Vector2(sin(j * 2.1) * 10, -30 - k * 18 + cos(j * 2.1) * 4)
				g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(.5, .9, .45, (1 - k) * .8))
		_:return false
	return true

static func lights(g):
	var w = g.world
	var h = w.hunt
	if h.data.is_empty():return
	if not h.stirring.is_empty():
		var left: float = clampf((h.stirring.stir_until - w.clock) / float(h.data.stir.warn), 0, 1)
		g.ambient_lights.append({"p": h.stirring.p - Vector2(0, 30), "r": 70.0, "c": Color(1, .15, .1), "power": .55 + .3 * sin(w.clock * lerpf(14.0, 4.0, left)), "glow": .15})
	for mark in h.pillars(w):
		if mark.get("state", "") == "freed" and w.clock - mark.get("freed_at", -9.0) < 1.5:
			g.ambient_lights.append({"p": mark.p - Vector2(0, 20), "r": 90.0, "c": Color(1, .85, .5), "power": .8 * (1 - (w.clock - mark.freed_at) / 1.5), "glow": .2})
	var b = h.butcher(w)
	if b != null:g.ambient_lights.append({"p": b.p - Vector2(0, 20), "r": 46.0, "c": Color(.9, .1, .08), "power": .35, "glow": .05})

static func sink_depth(g, m: Dictionary) -> float:
	if not m.has("sinking"):return 0.0
	return minf(40.0, (g.world.clock - m.sinking) * 44.0)

static func hud(g):
	var w = g.world
	var h = w.hunt
	if w.stage != "survival" or h.data.is_empty():return
	var b = h.butcher(w)
	if b != null and w.encounters.title().is_empty():
		BossBar.draw(g, "Мясник — его не убить, только пережить", clampf((b.leave_at - w.clock) / float(h.data.butcher.life), 0, 1), Color("6b0f0f"), "ch4_butcher")
	if not h.stirring.is_empty():
		var left: float = maxf(0, h.stirring.stir_until - w.clock)
		var y := 84 if b != null or not w.encounters.title().is_empty() else 46
		g.centered("Житель сорвётся со столба через %d с" % ceili(left), y, 8, Color(1, .45, .4) if left < 10 else Color(.95, .8, .7), true)
		marker(g, h.stirring.p, Color(1, .2, .15, .6 + .4 * sin(w.clock * 8)))
	if w.clock < h.vengeance_until:
		var t := "Возмездие %d с" % ceili(h.vengeance_until - w.clock)
		g.text_at(t, Vector2(8, 352), 8, Color(1, .55, .45))
	if w.clock - h.reward_at < 2.6 and not h.last_reward.is_empty():
		g.centered(h.last_reward, 84, 8, Color(1, .85, .55, 1 - maxf(0, w.clock - h.reward_at - 1.8) / .8), true)
	if h.surge_left > 0:
		var a: float = minf(1, h.surge_left / 2.0) * (.16 + .08 * sin(w.clock * 6))
		for j in range(6):
			var c := Color(.5, 0, 0, a * (1 - j / 6.0))
			g.draw_rect(Rect2(0, j * 3, 640, 3), c);g.draw_rect(Rect2(0, 357 - j * 3, 640, 3), c)
			g.draw_rect(Rect2(j * 3, 0, 3, 360), c);g.draw_rect(Rect2(637 - j * 3, 0, 3, 360), c)

static func marker(g, p: Vector2, color: Color):
	var delta: Vector2 = p - g.world.player
	if delta.length() < 170:return
	var direction: Vector2 = delta.normalized()
	var q: Vector2 = Vector2(320, 170) + direction * Vector2(270, 108)
	var side: Vector2 = direction.orthogonal()
	g.draw_colored_polygon(PackedVector2Array([q + direction * 7, q - direction * 4 + side * 5, q - direction * 4 - side * 5]), color)
	g.draw_rect(Rect2(q - direction * 12 - Vector2(1, 5), Vector2(2, 7)), color)
	g.draw_rect(Rect2(q - direction * 12 - Vector2(4, 3), Vector2(8, 2)), color)
