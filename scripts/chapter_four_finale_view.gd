extends RefCounted
## Chapter IV finale presentation: Herobrine, every telegraph of his attacks,
## the island, the fistfight close-up, the living text, the head, the note,
## the road and the black door. Reads the finale state; never changes combat.
const Tells = preload("res://scripts/chapter_four_tells.gd")
const Atmosphere = preload("res://scripts/ui/atmosphere.gd")
const ROWS := {"down": 0, "up": 1, "side": 2}

static func assets(g) -> Dictionary:
	if not g.has_meta("ch4_finale_assets"):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_finale_assets.json"))
		for name in data.sprites:
			if not g.textures.has(name):g.load_texture(name)
		g.set_meta("ch4_finale_assets", data)
	return g.get_meta("ch4_finale_assets")

static func row_of(dir: Vector2) -> int:
	return 2 if absf(dir.x) > absf(dir.y) else (1 if dir.y < 0 else 0)

## One posed frame of Herobrine or Steve from the finale atlases.
static func figure(g, sheet: String, who: String, pose: String, t: float, p: Vector2, dir: Vector2, scale: float = 1.0, tint: Color = Color.WHITE, loop: bool = true):
	var a: Dictionary = assets(g)
	var layout: Dictionary = a[who]
	if not layout.has(pose):pose = "idle"
	var clip: Dictionary = layout[pose]
	var fps: float = 6.0 if pose in ["idle", "float", "lying"] else 10.0
	var index: int = int(t * fps)
	index = index % int(clip.count) if loop else mini(int(clip.count) - 1, index)
	var col: int = int(clip.start) + index
	var size = Vector2(a.frame[0], a.frame[1])
	var anchor = Vector2(a.anchor[0], a.anchor[1])
	var row = row_of(dir)
	var flip = dir.x < 0 and row == 2
	if not g.textures.has(sheet):return
	var dest = Rect2(-anchor * scale, size * scale)
	g.draw_set_transform(p.floor(), 0, Vector2(-1 if flip else 1, 1))
	g.draw_texture_rect_region(g.textures[sheet], dest, Rect2(Vector2(col * size.x, row * size.y), size), tint)
	g.draw_set_transform(Vector2.ZERO)

static func herobrine(g, offset: Vector2, scale: float = 1.0):
	var e = g.world.ending
	var hb: Dictionary = e.hb
	if hb.is_empty():return
	var p: Vector2 = hb.p + offset
	var lift = 0.0
	if e.pose == "float":lift = 7.0 + sin(g.world.clock * 2.0) * 2.0
	var tint = Color(1.6, 1.6, 1.6) if hb.flash > 0 and g.settings.flashes else Color.WHITE
	g.oval(p + Vector2(0, 1), Vector2(9, 3) * scale * (1.0 - lift / 40.0), Color(0, 0, 0, 0.5))
	var loop: bool = e.pose in ["idle", "walk", "float", "lying", "invite", "guard"]
	figure(g, "ch4_hb_" + e.face, "herobrine", e.pose, e.pose_age, p - Vector2(0, lift * scale), hb.visual_dir, scale, tint, loop)
	# The eyes stay lit in any darkness; they gutter out with his power.
	if e.face != "dim" and e.pose not in ["lying", "lying_hit", "headless", "fall"] and row_of(hb.visual_dir) != 1:
		var eye_y: float = p.y - lift * scale - 26.0 * scale
		var side = row_of(hb.visual_dir) == 2
		var x0: float = p.x + (2.0 * signf(hb.visual_dir.x) * scale if side else 0.0)
		var gap: float = 1.0 if side else 2.5 * scale
		var glow = Color(1, 1, 1, 0.35)
		g.draw_rect(Rect2(Vector2(x0 - gap - 2, eye_y - 1).floor(), Vector2(4 + gap * 2, 3)), glow)
		g.draw_rect(Rect2(Vector2(x0 - gap - 1, eye_y).floor(), Vector2(1.0 * scale, 1)), Color.WHITE)
		g.draw_rect(Rect2(Vector2(x0 + gap, eye_y).floor(), Vector2(1.0 * scale, 1)), Color.WHITE)

static func steve(g, offset: Vector2, scale: float = 1.0):
	var e = g.world.ending
	var p: Vector2 = g.world.player + offset
	g.oval(p + Vector2(0, 1), Vector2(8, 3) * scale, Color(0, 0, 0, 0.5))
	var tint: Color = g.invulnerable_tint()
	var dir: Vector2 = g.world.facing if g.world.facing.length_squared() > 0 else Vector2.RIGHT
	if e.phase in ["three", "retry"]:dir = Vector2.RIGHT
	figure(g, "ch4_fist_steve", "steve", e.steve_pose, e.steve_pose_age, p, dir, scale, tint, e.steve_pose in ["idle", "walk", "guard", "mount"])

# ------------------------------------------------------------------ world layer (stages I–II)

static func floor_layer(g, offset: Vector2):
	var e = g.world.ending
	if e.phase == "" or e.phase == "summit":return
	var clock: float = g.world.clock
	var w = g.world
	if e.phase in ["one", "two", "kneel"]:arena_edge(g, e, offset)
	for m in e.marks:
		var k: float = clampf(m.age / float(e.data.one.lightning.windup), 0, 1)
		if not m.hit:
			var q: Vector2 = (m.p + offset).floor()
			Tells.ring(g, q, float(e.data.one.lightning.radius), k, clock, Color(0.75, 0.88, 1.0))
			# A thin column of light gathers from the sky onto the mark.
			var a: float = 0.15 + 0.6 * k
			if k > 0.85:a = 0.75 + 0.25 * sin(clock * 40.0)
			g.draw_rect(Rect2(q.x - 1, q.y - 150, 3, 150), Color(0.7, 0.85, 1.0, a * 0.35))
			g.draw_rect(Rect2(q.x, q.y - 150, 1, 150), Color(1, 1, 1, a))
			g.oval(q, Vector2(float(e.data.one.lightning.radius), float(e.data.one.lightning.radius) * 0.5) * (0.4 + 0.6 * k), Color(0.6, 0.8, 1.0, 0.12 + 0.18 * k))
	for ring in e.rings:fire_ring(g, e, ring, offset)
	for lane in e.lanes:
		if not lane.hit:Tells.lane(g, lane.a + offset, lane.b + offset, float(e.data.one.strike.width), clampf(lane.age / float(e.data.one.strike.windup), 0, 1), int(lane.a.x), clock)
	if not e.hole.is_empty():black_hole(g, e, offset)
	for i in range(e.path.size()):
		var leg: Dictionary = e.path[i]
		if not leg.get("marked", false):continue
		var a: Vector2 = leg.a + offset
		var b: Vector2 = leg.b + offset
		var done: float = leg.t if e.move == "blitz_dash" else 0.0
		g.draw_line(a.lerp(b, minf(1, done)).floor(), b.floor(), Color(0, 0, 0, 0.6), 5)
		g.draw_line(a.lerp(b, minf(1, done)).floor(), b.floor(), Color(1, 1, 1, 0.85 if done == 0.0 else 0.4), 2)
		g.draw_rect(Rect2((b - Vector2(3, 3)).floor(), Vector2(6, 6)), Color(1, 1, 1, 0.8))
	for s in e.strips:rift_strip(g, e, s, offset)
	if not e.seam.is_empty():tear(g, e, offset)

static func arena_edge(g, e, offset: Vector2):
	var r: Rect2 = e.arena
	var corners = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in range(4):
		var a: Vector2 = corners[i] + offset
		var b: Vector2 = corners[(i + 1) % 4] + offset
		var n = int(a.distance_to(b) / 16.0)
		for j in range(n + 1):
			var q: Vector2 = a.lerp(b, float(j) / maxf(1, n)).floor()
			g.draw_rect(Rect2(q - Vector2(5, 3), Vector2(10, 6)), Color(0.08, 0.06, 0.09))
			g.draw_rect(Rect2(q - Vector2(5, 3), Vector2(10, 1)), Color(0.32, 0.26, 0.34))
			if j % 4 == 0:
				g.draw_rect(Rect2(q - Vector2(1, 12), Vector2(2, 9)), Color(0.35, 0.25, 0.2))
				g.draw_rect(Rect2(q - Vector2(1, 14), Vector2(2, 2)), Color(1, 0.25, 0.12, 0.7 + 0.3 * sin(g.world.clock * 9 + j)))

static func fire_ring(g, e, ring: Dictionary, offset: Vector2):
	var r: Dictionary = e.data.one.ring
	var clock: float = g.world.clock
	var p: Vector2 = ring.p + offset
	if ring.age < float(r.windup):
		var k: float = ring.age / float(r.windup)
		Tells.ring(g, p, float(r.start), k, clock)
		var gp: Vector2 = p + Vector2.from_angle(ring.gap) * Vector2(1, 0.5) * float(r.start)
		g.draw_rect(Rect2(gp.floor() - Vector2(2, 2), Vector2(4, 4)), Color(1, 1, 1, 0.8))
		return
	var radius: float = ring.get("r", float(r.start))
	var count = int(clampf(radius * 0.45, 8, 40))
	for i in range(count):
		var a = i * TAU / count
		if absf(angle_difference(a, ring.gap)) < float(r.gap) * 0.5:continue
		var q: Vector2 = p + Vector2(cos(a), sin(a) * 0.5) * radius
		g.draw_clip("fire_animation", (q - Vector2(5, 12)).floor(), Vector2(10, 12), clock + i * 0.07)

static func black_hole(g, e, offset: Vector2):
	var h: Dictionary = e.data.two.hole
	var p: Vector2 = e.hole.p + offset
	var k: float = clampf(e.hole.age / float(h.grow), 0, 1)
	var clock: float = g.world.clock
	if not e.hole.burst:
		for ring_i in range(4):
			var rr = fposmod(1.0 - clock * 0.8 - ring_i * 0.25, 1.0)
			var radius = 14.0 + rr * 70.0 * k
			var dots = PackedVector2Array()
			for j in range(24):
				var a = j * TAU / 24 + clock * (1.5 + ring_i)
				var q = (p + Vector2(cos(a), sin(a) * 0.55) * radius).floor()
				dots.append_array([q, q + Vector2.RIGHT])
			g.draw_multiline(dots, Color(0.75, 0.55, 1.0, 0.25 + 0.5 * (1.0 - rr) * k), 1)
		for j in range(10):
			var a = j * 2.39 + clock * 2.4
			var dist = fposmod(60.0 - clock * 45.0 + j * 13.0, 60.0) * k + 10
			var q = (p + Vector2(cos(a), sin(a) * 0.55) * dist - Vector2(0, 6 + j % 3 * 3)).floor()
			g.draw_rect(Rect2(q, Vector2(3, 3)), Color(0.3, 0.26, 0.3))
		g.oval(p, Vector2(9 + 9 * k, 5 + 4 * k), Color(0, 0, 0, 0.95))
		g.draw_arc(p, 9 + 9 * k, 0, TAU, 24, Color(0.85, 0.65, 1.0, 0.6), 1)
	else:
		var t: float = e.hole.age - float(h.grow)
		g.draw_arc(p, 18 + t * 160, 0, TAU, 40, Color(1, 0.9, 1, maxf(0, 0.8 - t)), 2)

static func rift_strip(g, e, s: Dictionary, offset: Vector2):
	var rr: Dictionary = e.data.two.rift
	var clock: float = g.world.clock
	var height: float = float(rr.height)
	var gap: float = float(rr.gap)
	var y: float = s.y + offset.y
	var x0: float = e.arena.position.x + offset.x
	var x1: float = e.arena.end.x + offset.x
	var segments: Array = []
	var cursor = x0
	var gaps: Array = s.gaps.duplicate()
	gaps.sort()
	for gx in gaps:
		segments.append([cursor, gx + offset.x]); cursor = gx + offset.x + gap
	segments.append([cursor, x1])
	if not s.raised:
		var k: float = clampf(e.move_age / float(rr.windup), 0, 1)
		for seg in segments:
			for edge in [-height / 2, height / 2]:Tells.crack(g, Vector2(seg[0], y + edge), Vector2(seg[1], y + edge), k, int(seg[0] + edge), 1.5, 1.0, clock)
		return
	for seg in segments:
		var x: float = seg[0]
		while x < seg[1] - 1:
			var wdt = minf(16.0, seg[1] - x)
			var q = Vector2(x, y - height / 2 - 10).floor()
			g.draw_rect(Rect2(q + Vector2(0, height + 8), Vector2(wdt, 4)), Color(0, 0, 0, 0.5))
			if g.textures.has("block_blackstone"):
				g.draw_texture_rect_region(g.textures.block_blackstone, Rect2(q, Vector2(wdt, height + 8)), Rect2(0, 0, wdt, 16), Color(0.7, 0.62, 0.72))
			g.draw_rect(Rect2(q, Vector2(wdt, 2)), Color(0.75, 0.2, 0.18, 0.7))
			x += 16.0

static func tear(g, e, offset: Vector2):
	var t: Dictionary = e.data.two.tear
	var x: float = e.seam.x + offset.x
	var top: float = e.arena.position.y + offset.y
	var bottom: float = e.arena.end.y + offset.y
	var clock: float = g.world.clock
	var k: float = clampf(e.move_age / float(t.windup), 0, 1)
	if e.move_age < float(t.windup):
		Tells.crack(g, Vector2(x, top), Vector2(x, bottom), k, int(x), 3.0, 1.0, clock)
		return
	# The two halves no longer meet: a black seam with a slipped edge.
	g.draw_rect(Rect2(x - 3, top, 6, bottom - top), Color(0, 0, 0, 0.92))
	g.draw_rect(Rect2(x + 3, top, 1, bottom - top), Color(0.85, 0.75, 1.0, 0.5))
	for b in e.seam.bridges:
		var y: float = b + offset.y
		g.draw_rect(Rect2(x - 8, y - 14, 16, 28), Color(0.2, 0.17, 0.2))
		g.draw_rect(Rect2(x - 8, y - 14, 16, 1), Color(0.5, 0.45, 0.5))
	for y0 in e.seam.get("pulses", []):
		var y: float = y0 + offset.y
		g.draw_rect(Rect2(x - float(t.width), y - 3, float(t.width) * 2, 6), Color(0.85, 0.6, 1.0, 0.85))
		g.draw_rect(Rect2(x - 1, y - 10, 2, 20), Color(1, 1, 1, 0.9))

static func air_layer(g, offset: Vector2):
	var e = g.world.ending
	if e.phase == "":return
	for b in e.shots:
		var p: Vector2 = (b.p + offset).floor()
		var c = Color(1, 1, 1) if b.kind in ["rain", "day"] else Color(0.65, 0.55, 0.7)
		if b.kind == "rain":g.draw_line(p - Vector2(0, 7), p, Color(1, 1, 1, 0.35), 1)
		elif b.kind == "day":g.draw_line(p - b.v.normalized() * 6, p, Color(1, 0.85, 0.6, 0.4), 2)
		g.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0, 0, 0, 0.7))
		g.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), c)

static func effect(g, ef: Dictionary, offset: Vector2) -> bool:
	var p: Vector2 = ef.p + offset
	var k: float = clampf(ef.age / maxf(0.001, ef.total), 0, 1)
	match ef.kind:
		"ch4_hb_blink":
			figure(g, "ch4_hb_calm", "herobrine", "idle", 0.0, p, ef.dir, 1.0, Color(0, 0, 0, 0.6 * (1 - k)))
			for j in range(6):
				g.draw_rect(Rect2((p + Vector2(sin(j * 2.4) * 8, -10 - j * 4 - k * 10)).floor(), Vector2(2, 1)), Color(1, 1, 1, 1 - k))
		"ch4_hb_bolt":
			var top = p - Vector2(10, 140)
			var last = top
			for j in range(1, 9):
				var q = top.lerp(p, j / 8.0) + Vector2(sin(j * 7.0 + ef.p.x) * 6, 0)
				g.draw_line(last.floor(), q.floor(), Color(0.55, 0.75, 1, 0.6 * (1 - k)), 4)
				g.draw_line(last.floor(), q.floor(), Color(1, 1, 1, 1 - k), 1)
				last = q
			g.draw_arc(p, ef.radius * (1 + k), 0, TAU, 24, Color(1, 1, 1, 1 - k), 1)
		"ch4_hb_slash":
			var end: Vector2 = ef.end + offset
			g.draw_line(p, end, Color(1, 1, 1, 1 - k), 3)
			g.draw_line(p, end, Color(0.2, 0.0, 0.03, (1 - k) * 0.8), 7)
		"ch4_hb_head":head_burst(g, p, ef.age)
		_:return false
	return true

## The final blow: cubes of the head scatter with the two white eye pixels.
static func head_burst(g, p: Vector2, age: float):
	# Local space: the caller scales it to the close-up. No helpers that reset the transform.
	var colors = [Color("2e1f10"), Color("b4846d"), Color("aa7d66"), Color("6b2a1c"), Color("7a0c10"), Color("4a0508")]
	var fly: float = minf(age, 0.42)
	var pool: float = minf(1.0, age * 0.8)
	for j in range(5):
		var w: float = (10.0 + j * 4.0) * pool
		g.draw_rect(Rect2((p + Vector2(-w / 2, 9 - j * 0.6)).floor(), Vector2(w, 2 + j % 2)), Color(0.32, 0.0, 0.02, 0.9))
	for j in range(26):
		var a: float = -PI * 0.5 + (Atmosphere.hash01(j, 1, 7) - 0.5) * 2.6
		var speed: float = 30.0 + Atmosphere.hash01(j, 2, 7) * 55.0
		var q: Vector2 = p + Vector2(cos(a), sin(a)) * speed * fly + Vector2(0, 150 * fly * fly)
		if age > 0.42:q.y = maxf(q.y, p.y + 6 + Atmosphere.hash01(j, 3, 7) * 5)
		var size: float = 1.0 + float(j % 2)
		g.draw_rect(Rect2(q.floor(), Vector2(size, size)), colors[j % colors.size()])
	for j in range(2):
		var q: Vector2 = p + Vector2(-5 + j * 10, -14) * minf(1.0, age * 3.0) + Vector2(0, 90 * fly * fly)
		if age > 0.42:q.y = maxf(q.y, p.y + 6)
		g.draw_rect(Rect2(q.floor(), Vector2.ONE), Color.WHITE)

# ------------------------------------------------------------------ overlays (after lighting)

static func overlay(g, offset: Vector2):
	var e = g.world.ending
	if e.phase == "":return
	var clock: float = g.world.clock
	if e.phase == "summit" and not g.world.visible(e.center, 0):
		var dir: Vector2 = g.world.camera().direction_to(e.center)
		var q: Vector2 = Vector2(320, 180) + dir * Vector2(292, 134)
		g.draw_colored_polygon(PackedVector2Array([q + dir * 8, q - dir * 5 + dir.orthogonal() * 6, q - dir * 5 - dir.orthogonal() * 6]), Color(1, 0.3, 0.2))
	if e.sky > 0.0 or e.split > 0.0:day_sky(g, e, offset)
	if e.phase in ["erase", "three", "death", "retry"]:island(g, e, offset)
	if e.phase in ["three", "retry", "death"]:duel(g, e, offset)
	if e.phase in ["one", "two"]:boss_bar(g, e)
	if e.phase == "three":prompt(g, e)
	words(g, e, offset)
	if e.phase == "erase":erase_fx(g, e, offset)
	if e.phase == "coords":coords(g, e)
	if e.phase in ["road", "door"]:letterbox(g, e)
	if e.phase == "door":door(g, e, offset)
	if e.phase == "retry":
		g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, smoothstep(0.0, 1.0, e.age) * (1.0 - smoothstep(1.6, 2.2, e.age))))
	if e.glitch > 0 and g.settings.flashes:
		for j in range(6):
			var y = int(Atmosphere.hash01(int(clock * 30), j, 5) * 360)
			g.draw_rect(Rect2(0, y, 640, 2 + j % 3), Color(1, 1, 1, 0.15) if j % 2 else Color(0, 0, 0, 0.6))
	if e.flash > 0 and g.settings.flashes:
		g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, e.flash * 1.5))

static func boss_bar(g, e):
	var hb: Dictionary = e.hb
	g.draw_rect(Rect2(209, 46, 222, 5), Color("1a1416"))
	g.draw_rect(Rect2(209, 46, 222 * maxf(0, hb.hp) / maxf(1, hb.max_hp), 5), Color("c8c8c8") if e.phase == "one" else Color("b8182a"))
	g.centered("Херобрин", 41, 8, g.INK)

## Day acceleration: a sweeping sun, long shadows, and the frozen impossible sky.
static func day_sky(g, e, offset: Vector2):
	var sun: float = e.sky
	g.draw_rect(Rect2(0, 0, 640, 360), Color(1.0, 0.86, 0.62, 0.32 * sun))
	var angle: float = g.world.clock * (2.0 + 6.0 * sun)
	var p: Vector2 = e.hb.p + offset
	var shadow_dir = Vector2.from_angle(angle)
	g.draw_colored_polygon(PackedVector2Array([p + shadow_dir.orthogonal() * 5, p - shadow_dir.orthogonal() * 5, p + shadow_dir * 160 - shadow_dir.orthogonal() * 14, p + shadow_dir * 160 + shadow_dir.orthogonal() * 14]), Color(0, 0, 0, 0.35 * sun))
	if e.split > 0:
		var k: float = e.split
		g.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(380, 0), Vector2(260, 360), Vector2(0, 360)]), Color(1.0, 0.9, 0.72, 0.4 * k))
		g.draw_colored_polygon(PackedVector2Array([Vector2(380, 0), Vector2(640, 0), Vector2(640, 360), Vector2(260, 360)]), Color(0.0, 0.02, 0.08, 0.6 * k))
		for j in range(30):
			var q = Vector2(360 + Atmosphere.hash01(j, 1, 9) * 280, Atmosphere.hash01(j, 2, 9) * 360)
			if q.x > 380 - q.y / 3.0:g.draw_rect(Rect2(q.floor(), Vector2.ONE), Color(1, 1, 1, 0.8 * k))
		g.draw_line(Vector2(380, 0), Vector2(260, 360), Color(1, 1, 1, 0.8 * k), 1)

## Everything beyond the last patch of ground is erased to a void.
static func island(g, e, offset: Vector2):
	var c: Vector2 = e.center + offset
	var radius: float = float(e.data.arena.island)
	if e.phase == "erase":radius = lerpf(380.0, radius, smoothstep(0.4, 2.2, e.age))
	var outer = 900.0
	var n = 48
	for i in range(n):
		var a0 = i * TAU / n
		var a1 = (i + 1) * TAU / n
		var r0 = radius + sin(i * 2.7) * 4.0
		var r1 = radius + sin((i + 1) * 2.7) * 4.0
		g.draw_colored_polygon(PackedVector2Array([c + Vector2(cos(a0), sin(a0) * 0.62) * r0, c + Vector2(cos(a1), sin(a1) * 0.62) * r1, c + Vector2(cos(a1), sin(a1)) * outer, c + Vector2(cos(a0), sin(a0)) * outer]), Color(0.008, 0.006, 0.01))
	for j in range(16):
		var a = j * TAU / 16 + g.world.clock * 0.05
		var q = (c + Vector2(cos(a), sin(a) * 0.62) * (radius + 3) + Vector2(0, fposmod(g.world.clock * 14 + j * 7, 30))).floor()
		g.draw_rect(Rect2(q, Vector2(2, 2)), Color(0.25, 0.2, 0.22, 1.0 - fposmod(g.world.clock * 14 + j * 7, 30) / 30.0))

## The fistfight and the death are shown close: both figures at double size.
static func duel(g, e, offset: Vector2):
	var hb_first: bool = e.hb.p.y < g.world.player.y
	var scale = 2.0
	var c: Vector2 = e.center + offset
	var hp: Vector2 = c + (e.hb.p - e.center) * scale
	var sp: Vector2 = c + (g.world.player - e.center) * scale
	var dodge = 0.0
	if e.steve_pose in ["dodge_l", "dodge_r"]:dodge = (-1.0 if e.steve_pose == "dodge_l" else 1.0) * minf(1.0, e.steve_pose_age * 6.0) * 6.0
	var order = [0, 1] if hb_first else [1, 0]
	for who in order:
		if who == 0:
			var saved: Vector2 = e.hb.p
			e.hb.p = hp - offset
			herobrine(g, offset, scale)
			e.hb.p = saved
			if e.head_at >= 0.0:
				var head: Vector2 = hp + Vector2(-17, -8)
				g.draw_set_transform(head, 0, Vector2(scale, scale))
				head_burst(g, Vector2.ZERO, e.age - e.head_at)
				g.draw_set_transform(Vector2.ZERO)
		else:
			var saved: Vector2 = g.world.player
			g.world.player = sp - offset + Vector2(0, dodge)
			steve(g, offset, scale)
			g.world.player = saved

static func key_glyph(g, at: Vector2, action: String, k: float, state: String):
	var c = Color(1, 1, 1, 0.95)
	if state == "ok":c = Color(1, 1, 1, 1)
	elif state == "fail":c = Color(0.9, 0.12, 0.12)
	g.draw_rect(Rect2(at - Vector2(13, 13), Vector2(26, 26)), Color(0, 0, 0, 0.75))
	g.draw_rect(Rect2(at - Vector2(13, 13), Vector2(26, 26)), c, false, 1)
	if action == "attack" or action == "hold":
		g.text_at("ПРОБЕЛ", at + Vector2(-17, 30), 8, c, true)
		g.draw_rect(Rect2(at - Vector2(8, 3), Vector2(16, 6)), c)
		return
	var dir: Vector2 = {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}[action]
	var side = dir.orthogonal()
	g.draw_colored_polygon(PackedVector2Array([at + dir * 9, at + side * 7 - dir * 1, at + side * 3 - dir * 1, at + side * 3 - dir * 8, at - side * 3 - dir * 8, at - side * 3 - dir * 1, at - side * 7 - dir * 1]), c)

## QTE prompt: the key, a ring closing on the window, a bar for holding.
static func prompt(g, e):
	var q: Dictionary = e.qte
	if q.is_empty() or q.age < q.windup - 0.15:return
	var at = Vector2(320, 96)
	var window: float = float(q.window)
	var left: float = clampf(1.0 - (q.age - q.windup) / window, 0, 1)
	var state: String = q.result
	match q.kind:
		"dodge":key_glyph(g, at, q.dir, left, state)
		"attack":key_glyph(g, at, "attack", left, state)
		"hold":
			key_glyph(g, at, "hold", left, state)
			var fill: float = clampf(q.held / (window * 0.75), 0, 1)
			g.draw_rect(Rect2(at + Vector2(-30, 44), Vector2(60, 4)), Color(0, 0, 0, 0.8))
			g.draw_rect(Rect2(at + Vector2(-30, 44), Vector2(60 * fill, 4)), Color(1, 1, 1))
		"seq":
			var n: int = q.dirs.size()
			for i in range(n):
				var s = "ok" if i < q.progress else state if state == "fail" else ""
				key_glyph(g, at + Vector2((i - (n - 1) / 2.0) * 34, 0), q.dirs[i], left, s)
	if state == "":
		g.draw_arc(at, 20 + 14 * left, 0, TAU, 32, Color(1, 1, 1, 0.7), 1)

# ------------------------------------------------------------------ the living text

static func words(g, e, offset: Vector2):
	for t in e.text_events:
		var age: float = e.age - t.at
		match t.style:
			"calm":calm_line(g, e, t, age, offset)
			"laugh":laugh(g, t, age)
			"crawl":crawl(g, t, age)
			"plead":plead(g, t, age)

static func calm_line(g, e, t: Dictionary, age: float, offset: Vector2):
	var shown = mini(t.text.length(), int(age * 18.0))
	var text: String = t.text.substr(0, shown)
	var fade: float = 1.0 - smoothstep(t.life - 0.6, t.life, age)
	var p: Vector2 = (e.hb.p + offset - Vector2(0, 50)) if not e.hb.is_empty() else Vector2(320, 120)
	var width: float = g.font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	g.text_at(text, Vector2(p.x - width / 2, p.y).floor(), 8, Color(0.92, 0.92, 0.92, fade))

## "АХАХАХАХАХХАХА": every letter lives on its own — jitter, swelling, ghosts.
static func laugh(g, t: Dictionary, age: float):
	var text: String = t.text
	var cut_k: float = smoothstep(t.cut - 0.05, t.cut + 0.35, age)
	var frame = int(age * 24.0)
	var n = text.length()
	for copy in range(3):
		for i in range(n):
			var appear: float = i * 0.07
			if age < appear:continue
			var local: float = age - appear
			var swell = 8 + int(minf(16.0, local * 10.0 + sin(local * 7.0 + i) * 4.0)) / 8 * 8
			var jitter = Vector2(Atmosphere.hash01(frame, i + copy * 50, 11) - 0.5, Atmosphere.hash01(frame, i + copy * 50, 12) - 0.5) * (4.0 + local * 3.0)
			var base = Vector2(320 + (i - n / 2.0) * (18 + local * 4.0), 120 + sin(local * 3.0 + i * 0.8) * (8 + local * 6.0) + copy * 30)
			if cut_k > 0:base += Vector2.from_angle(i * 2.39) * cut_k * 200.0
			var a: float = (1.0 if copy == 0 else 0.35 / copy) * (1.0 - cut_k)
			if a <= 0.01:continue
			g.text_at(text[i], (base + jitter).floor() + Vector2(1, 1), swell, Color(0.6, 0.0, 0.05, a))
			g.text_at(text[i], (base + jitter).floor(), swell, Color(1, 1, 1, a))

## "ТЫ НИЧЕРТА НЕ ПОНЯЛ": letters slowly drift apart and sink, wrong and heavy.
static func crawl(g, t: Dictionary, age: float):
	var text: String = t.text
	var cut_k: float = smoothstep(t.cut - 0.05, t.cut + 0.3, age)
	var frame = int(age * 12.0)
	var n = text.length()
	for i in range(n):
		var appear: float = i * 0.09
		if age < appear or text[i] == " ":continue
		var local: float = age - appear
		var drift = Vector2(sin(i * 1.7 + local * 0.9) * local * 3.0, local * local * 2.0 * Atmosphere.hash01(i, 3, 13))
		var jitter = Vector2(Atmosphere.hash01(frame, i, 14) - 0.5, Atmosphere.hash01(frame, i, 15) - 0.5) * 2.0
		var p = Vector2(320 + (i - n / 2.0) * 14, 150) + drift + jitter
		if cut_k > 0:p += Vector2(0, -1).rotated((i - n / 2.0) * 0.2) * cut_k * 140.0
		var a: float = 1.0 - cut_k
		g.text_at(text[i], p.floor() + Vector2(1, 1), 16, Color(0.5, 0.0, 0.04, a))
		g.text_at(text[i], p.floor(), 16, Color(0.95, 0.92, 0.9, a))

## The last plea types out too fast, trembling, and is broken off by the blow.
static func plead(g, t: Dictionary, age: float):
	var text: String = t.text
	var typed = mini(text.length(), int(age * 13.0))
	var stop: int = text.length() - 2
	var cut: bool = age >= t.cut
	if cut:typed = mini(typed, stop)
	var frame = int(age * 30.0)
	var lines = [text.substr(0, 27), text.substr(27)]
	var index = 0
	for li in range(2):
		var line: String = lines[li]
		for i in range(line.length()):
			if index >= typed:break
			var shake: float = 1.5 + age * 0.6
			var jitter = Vector2(Atmosphere.hash01(frame, index, 16) - 0.5, Atmosphere.hash01(frame, index, 17) - 0.5) * shake
			var p = Vector2(320 + (i - line.length() / 2.0) * 13, 118 + li * 24) + jitter
			var a = 1.0
			if cut:
				var since: float = age - t.cut
				var from_end: int = typed - index
				if from_end <= 6:
					p += Vector2.from_angle(index * 2.4) * since * 160.0 * (7 - from_end) / 6.0
					a = maxf(0.0, 1.0 - since * 2.0)
				else:
					a = maxf(0.0, 1.0 - since * 1.2)
			g.text_at(line[i], p.floor() + Vector2(1, 1), 16, Color(0.5, 0.0, 0.04, a))
			g.text_at(line[i], p.floor(), 16, Color(1, 1, 1, a))
			index += 1

# ------------------------------------------------------------------ erase, note, road, door

static func erase_fx(g, e, offset: Vector2):
	if e.stored.is_empty() or e.age > 3.0:return
	var t: float = e.age - 1.2
	var ids: Array = e.stored.build.keys() + e.stored.items.keys()
	var origin: Vector2 = g.world.player + offset - Vector2(0, 14)
	for i in range(ids.size()):
		var dir = Vector2.from_angle(i * TAU / maxf(1, ids.size()) - PI / 2)
		var p = origin + dir * (24 + t * 50) + Vector2(0, t * t * 60)
		if t < 0.6:
			g.item_icon(ids[i], (p - Vector2(8, 8)).floor())
		else:
			for j in range(6):
				var q = p + Vector2.from_angle(j * 1.05) * (t - 0.6) * 40
				g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(0.8, 0.8, 0.85, maxf(0, 1.6 - t)))

static func coords(g, e):
	if e.age < 3.0:return
	var k: float = smoothstep(3.0, 3.6, e.age) * (1.0 - smoothstep(e.data.coords.duration - 0.8, e.data.coords.duration, e.age))
	g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.55 * k))
	g.panel(Rect2(220, 128, 200, 84))
	var text: String = e.data.coords.text
	var glitch: Array = e.data.coords.glitch
	if e.age >= float(glitch[0]) and e.age < float(glitch[1]):
		var scrambled = ""
		for i in range(text.length()):
			scrambled += text[i] if text[i] == " " else str(int(Atmosphere.hash01(int(e.age * 40), i, 21) * 10))
		text = scrambled
	var width: float = g.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	g.text_at(text, Vector2(320 - width / 2, 176).floor(), 8, Color(0.95, 0.95, 0.95, k))
	g.sprite("icon_ch4_note", Vector2(312, 140), Vector2(16, 16), Color(1, 1, 1, k))

static func letterbox(g, e):
	var bars = 22.0
	g.draw_rect(Rect2(0, 0, 640, bars), Color.BLACK)
	g.draw_rect(Rect2(0, 360 - bars, 640, bars), Color.BLACK)
	if e.phase == "road":
		var each: float = float(e.data.road.each)
		var local: float = fposmod(e.age, each)
		var fade: float = 1.0 - minf(smoothstep(0.0, 0.6, local), 1.0 - smoothstep(each - 0.6, each, local))
		g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, fade))

## A door that does not belong: flat, perfectly black, unlit by anything.
static func door(g, e, offset: Vector2):
	var p: Vector2 = Vector2(e.data.door.p[0], e.data.door.p[1]) + offset
	var size = Vector2(22, 44)
	var top_left: Vector2 = p - Vector2(size.x / 2, size.y)
	# The far tree has a door-shaped piece missing from it.
	var tree = p + Vector2(96, -36)
	g.sprite("tree_dead_1", tree - Vector2(32, 67), Vector2.ZERO, Color(0.55, 0.5, 0.5))
	g.draw_rect(Rect2(tree + Vector2(-5, -40), Vector2(10, 20)), Color(0, 0, 0))
	var open: float = 0.0
	match e.door_state:
		"open", "look", "enter", "gone":open = 1.0 if e.door_state != "open" else smoothstep(4.0, 5.0, e.age)
		"closed":open = 1.0 - smoothstep(9.6, 9.75, e.age)
	g.draw_rect(Rect2(top_left, size), Color(0, 0, 0))
	if open > 0:
		var panel = size.x * (1.0 - open)
		g.draw_rect(Rect2(top_left, Vector2(maxf(1, panel), size.y)), Color(0.03, 0.03, 0.035))
	if e.door_state == "enter":
		var steve_p: Vector2 = g.world.player + offset
		if Rect2(top_left, size).grow(2).has_point(steve_p - Vector2(0, 4)):
			var into: float = clampf((top_left.y + size.y - steve_p.y) / 12.0, 0, 1)
			g.draw_rect(Rect2(top_left.x, steve_p.y - 40, size.x, 40 + 2), Color(0, 0, 0, into))
	if e.door_state in ["gone", "closed"] and e.age > 10.6:
		g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, smoothstep(10.6, 12.2, e.age)))
