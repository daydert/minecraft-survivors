extends RefCounted
## Chapter IV finale presentation: Herobrine at full size with his aura, every
## telegraph of his attacks, the island, the fistfight close-up, the living
## text, the head, the note, the road and the black door. Reads the finale
## state; never changes combat.
const Tells = preload("res://scripts/chapter_four_tells.gd")
const Atmosphere = preload("res://scripts/ui/atmosphere.gd")
const ROWS := {"down": 0, "up": 1, "side": 2}
const DUEL := 2.6
const DEATH := 3.0
static var profile := false

static func assets(g) -> Dictionary:
	if not g.has_meta("ch4_finale_assets"):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_finale_assets.json"))
		for name in data.sprites:
			if not g.textures.has(name):g.load_texture(name)
		g.set_meta("ch4_finale_assets", data)
	return g.get_meta("ch4_finale_assets")

static func row_of(dir: Vector2) -> int:
	return 2 if absf(dir.x) > absf(dir.y) else (1 if dir.y < 0 else 0)

static func h(i: int, salt: int) -> float:
	return Atmosphere.hash01(i, salt, 41)

## One posed frame of Herobrine or Steve from the finale atlases.
static func figure(g, sheet: String, who: String, pose: String, t: float, p: Vector2, dir: Vector2, scale: float = 1.0, tint: Color = Color.WHITE, loop: bool = true):
	var a: Dictionary = assets(g)
	var layout: Dictionary = a[who]
	if not layout.has(pose):pose = "idle"
	var clip: Dictionary = layout[pose]
	var fps: float = 6.0 if pose in ["idle", "float", "lying", "aura", "exhausted", "mount_still"] else 10.0
	var index: int = int(t * fps)
	index = index % int(clip.count) if loop else mini(int(clip.count) - 1, index)
	var col: int = int(clip.start) + index
	var size = Vector2(a.frame[0], a.frame[1])
	var anchor = Vector2(a.anchor[0], a.anchor[1])
	var row = row_of(dir)
	if profile and row == 2:row = 3
	var flip = dir.x < 0 and row >= 2
	if not g.textures.has(sheet):return
	var dest = Rect2(-anchor * scale, size * scale)
	g.draw_set_transform(p.floor(), 0, Vector2(-1 if flip else 1, 1))
	g.draw_texture_rect_region(g.textures[sheet], dest, Rect2(Vector2(col * size.x, row * size.y), size), tint)
	g.draw_set_transform(Vector2.ZERO)

static func aura_color(e) -> Color:
	return Color(0.85, 0.9, 1.0) if e.phase in ["intro", "one", "kneel", "summit"] else Color(1.0, 0.28, 0.22)

static func herobrine(g, offset: Vector2, scale: float = -1.0, tint_override: Color = Color(0, 0, 0, 0)):
	var e = g.world.ending
	var hb: Dictionary = e.hb
	if hb.is_empty():return
	var s: float = e.scale() if scale < 0 else scale
	var p: Vector2 = hb.p + offset
	if hb.get("perched", false):p.y -= e.tower_h
	var clock: float = g.world.clock
	var lift = 0.0
	if e.pose == "float":lift = 6.0 + sin(clock * 2.0) * 2.0
	if e.phase == "last":lift = 10.0 * smoothstep(0.0, float(e.data.last.rise), e.age) + sin(clock * 3.0) * 1.5
	if e.phase == "intro" and e.age > float(e.data.intro.rise_at):lift = 4.0 * smoothstep(float(e.data.intro.rise_at), float(e.data.intro.rise_at) + 1.0, e.age)
	var intensity: float = float(hb.get("aura", 1.0)) if e.phase not in ["three", "death", "retry", "coords"] else 0.0
	var tint = Color(1.6, 1.6, 1.6) if hb.flash > 0 and g.settings.flashes else Color.WHITE
	if tint_override.a > 0:tint = tint_override
	if intensity > 0.01:aura_back(g, e, p, s, intensity, clock)
	g.oval(p + Vector2(0, 1), Vector2(9, 3) * s * (1.0 - lift / 40.0), Color(0, 0, 0, 0.5))
	var loop: bool = e.pose in ["idle", "walk", "float", "lying", "invite", "guard", "aura", "exhausted"]
	# While he shrinks, the larger self flickers around him for a frame or two.
	if e.phase == "erase" and e.glitch > 0 and s < float(e.data.giant):
		figure(g, "ch4_hb_" + e.face, "herobrine", e.pose, e.pose_age, p, hb.visual_dir, minf(float(e.data.giant), s + 0.2), Color(1, 1, 1, 0.35))
	figure(g, "ch4_hb_" + e.face, "herobrine", e.pose, e.pose_age, p - Vector2(0, lift * s), hb.visual_dir, s, tint, loop)
	eyes(g, e, p - Vector2(0, lift * s), s)
	if intensity > 0.01:aura_front(g, e, p - Vector2(0, lift * s * 0.5), s, intensity, clock)

## The eyes stay lit in any darkness; they gutter out with his power.
static func eyes(g, e, p: Vector2, s: float):
	var hb: Dictionary = e.hb
	if e.face == "dim" or e.pose in ["lying", "lying_hit", "headless", "fall"] or row_of(hb.visual_dir) == 1:return
	var eye_y: float = p.y - 26.0 * s
	var side = row_of(hb.visual_dir) == 2
	var x0: float = p.x + (2.0 * signf(hb.visual_dir.x) * s if side else 0.0)
	var gap: float = 1.0 if side else 2.5 * s
	var glow = Color(1, 1, 1, 0.3)
	g.draw_rect(Rect2(Vector2(x0 - gap - 2 * s, eye_y - 1.5 * s).floor(), Vector2(gap * 2 + 4 * s, 3 * s)), glow)
	var w: float = maxf(1.0, s)
	g.draw_rect(Rect2(Vector2(x0 - gap - w * 0.5, eye_y).floor(), Vector2(w, maxf(1.0, s * 0.7))), Color.WHITE)
	g.draw_rect(Rect2(Vector2(x0 + gap - w * 0.5, eye_y).floor(), Vector2(w, maxf(1.0, s * 0.7))), Color.WHITE)

## Behind him: the ground gives under his weight, black smoke leaves him.
static func aura_back(g, e, p: Vector2, s: float, k: float, clock: float):
	var c: Color = aura_color(e)
	g.oval(p, Vector2(22, 7) * s * (1.0 + 0.06 * sin(clock * 3.0)), Color(0, 0, 0, 0.35 * minf(1.0, k)))
	for j in range(7):
		var a: float = j * TAU / 7 + h(j, 1) * 0.6
		var length: float = (12.0 + h(j, 2) * 16.0) * s * minf(1.2, k)
		var last: Vector2 = p
		for step in range(1, 5):
			var q: Vector2 = p + Vector2(cos(a), sin(a) * 0.45) * length * step / 4.0 + Vector2(h(j * 7 + step, 3) - 0.5, h(j * 7 + step, 4) - 0.5) * 3.0
			g.draw_line(last.floor(), q.floor(), Color(0, 0, 0, 0.7), 2)
			g.draw_line(last.floor(), q.floor(), Color(c, (0.25 + 0.2 * sin(clock * 4.0 + j)) * minf(1.0, k)), 1)
			last = q
	for j in range(12):
		var ph: float = fposmod(clock * (0.45 + h(j, 5) * 0.3) + h(j, 6), 1.0)
		var x: float = p.x + (h(j, 7) - 0.5) * 18.0 * s + sin(clock * 2.0 + j) * 2.0 * s
		var y: float = p.y - ph * 52.0 * s
		var size: float = (2.0 + h(j, 8) * 3.0) * maxf(1.0, s * 0.7) * (1.0 - ph * 0.5)
		g.draw_rect(Rect2(Vector2(x, y).floor(), Vector2(size, size)), Color(0.0, 0.0, 0.0, (1.0 - ph) * 0.75 * minf(1.0, k)))
		g.draw_rect(Rect2(Vector2(x, y).floor(), Vector2(1, size)), Color(c, (1.0 - ph) * 0.25 * minf(1.0, k)))

## In front: stones float around him, sparks rise off him.
static func aura_front(g, e, p: Vector2, s: float, k: float, clock: float):
	var c: Color = aura_color(e)
	for j in range(8):
		var a: float = clock * (0.5 + h(j, 9) * 0.4) + j * TAU / 8
		var r: float = (17.0 + h(j, 10) * 10.0) * s
		var bob: float = (4.0 + h(j, 11) * 8.0) * s * minf(1.0, k) + sin(clock * 2.2 + j) * 2.0
		var q: Vector2 = p + Vector2(cos(a) * r, sin(a) * r * 0.35 - bob)
		var size: float = 2.0 + floorf(h(j, 12) * 3.0)
		var front: bool = sin(a) > 0
		var shade: float = 0.22 + h(j, 13) * 0.15
		g.draw_rect(Rect2(q.floor(), Vector2(size, size)), Color(shade, shade * 0.92, shade * 0.95, 1.0 if front else 0.6))
		g.draw_rect(Rect2(q.floor(), Vector2(size, 1)), Color(shade + 0.25, shade + 0.22, shade + 0.24, 1.0 if front else 0.6))
	for j in range(16):
		var ph: float = fposmod(clock * (0.7 + h(j, 14) * 0.6) + h(j, 15), 1.0)
		var q: Vector2 = p + Vector2((h(j, 16) - 0.5) * 30.0 * s + sin(clock * 3.0 + j * 2.0) * 3.0, -ph * 70.0 * s)
		var spark: Color = Color.WHITE if j % 3 == 0 else c
		g.draw_rect(Rect2(q.floor(), Vector2(1, 1 + (j % 2))), Color(spark, (1.0 - ph) * minf(1.0, k)))

static func steve(g, offset: Vector2, scale: float = 1.0, dir_override: Vector2 = Vector2.ZERO, tint_override: Color = Color(0, 0, 0, 0)):
	var e = g.world.ending
	var p: Vector2 = g.world.player + offset
	if tint_override.a == 0:g.oval(p + Vector2(0, 1), Vector2(8, 3) * scale, Color(0, 0, 0, 0.5))
	var tint: Color = g.invulnerable_tint() if tint_override.a == 0 else tint_override
	var dir: Vector2 = g.world.facing if g.world.facing.length_squared() > 0 else Vector2.RIGHT
	if dir_override != Vector2.ZERO:dir = dir_override
	figure(g, "ch4_fist_steve", "steve", e.steve_pose, e.steve_pose_age, p, dir, scale, tint, e.steve_pose in ["idle", "walk", "guard", "mount", "mount_still"])

# ------------------------------------------------------------------ world layer (stages I–II)

static func floor_layer(g, offset: Vector2):
	var e = g.world.ending
	if e.phase == "" or e.phase == "summit":return
	var clock: float = g.world.clock
	if e.phase in ["one", "two", "kneel"]:arena_edge(g, e, offset)
	for m in e.marks:
		if m.age < 0:continue
		var k: float = clampf(m.age / float(m.get("windup", e.data.one.lightning.windup)), 0, 1)
		if not m.hit:
			var q: Vector2 = (m.p + offset).floor()
			var r: float = float(m.get("r", e.data.one.lightning.radius))
			Tells.ring(g, q, r, k, clock, Color(0.75, 0.88, 1.0))
			var a: float = 0.15 + 0.6 * k
			if k > 0.85:a = 0.75 + 0.25 * sin(clock * 40.0)
			g.draw_rect(Rect2(q.x - 2, q.y - 220, 5, 220), Color(0.7, 0.85, 1.0, a * 0.25))
			g.draw_rect(Rect2(q.x, q.y - 220, 1, 220), Color(1, 1, 1, a))
			g.oval(q, Vector2(r, r * 0.5) * (0.4 + 0.6 * k), Color(0.6, 0.8, 1.0, 0.12 + 0.18 * k))
	for ring in e.rings:fire_ring(g, e, ring, offset)
	for wv in e.waves:fire_wave(g, e, wv, offset)
	for lane in e.lanes:
		if not lane.hit:Tells.lane(g, lane.a + offset, lane.b + offset, float(e.data.one.strike.width), clampf(lane.age / float(e.data.one.strike.windup), 0, 1), int(lane.a.x), clock)
	if not e.hole.is_empty():black_hole_floor(g, e, offset)
	for i in range(e.path.size()):
		var leg: Dictionary = e.path[i]
		if not leg.get("marked", false):continue
		var a: Vector2 = leg.a + offset
		var b: Vector2 = leg.b + offset
		var done: float = leg.t if e.move == "blitz_dash" else 0.0
		Tells.lane(g, a.lerp(b, minf(1, done)), b, float(e.data.two.blitz.width), 1.0 if done == 0.0 else 0.6, i * 31, clock)
		g.draw_rect(Rect2((b - Vector2(3, 3)).floor(), Vector2(6, 6)), Color(1, 1, 1, 0.8))
	for s in e.strips:rift_strip(g, e, s, offset)
	if not e.seam.is_empty():tear(g, e, offset)
	for d in e.drops:
		var k: float = clampf(d.age / float(e.data.two.rain.heavy_windup), 0, 1)
		if not d.hit:Tells.ring(g, (d.p + offset).floor(), float(e.data.two.rain.heavy_radius), k, clock, Color(0.9, 0.95, 1.0))
	if e.move == "day":day_floor(g, e, offset)

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

## Chapter I's fire waves, rolling out from the foot of his tower.
static func fire_wave(g, e, wv: Dictionary, offset: Vector2):
	if wv.age < 0:
		var k: float = clampf(1.0 + wv.age / 0.8, 0, 1)
		Tells.ring(g, wv.p + offset, 30.0, k, g.world.clock)
		return
	var gap: float = float(e.data.tower.waves.gap)
	var count: int = maxi(16, int(TAU * wv.r / 13.0))
	var clock: float = g.world.clock
	for i in range(count):
		var a: float = i * TAU / count
		if absf(angle_difference(a, wv.gap)) < gap * 0.5:continue
		var q: Vector2 = wv.p + offset + Vector2(cos(a), sin(a) * 0.5) * wv.r
		if not Rect2(-20, -30, 680, 420).has_point(q):continue
		g.draw_clip("fire_animation", (q - Vector2(8, 20)).floor(), Vector2(16, 20), clock + i * 0.05)
	var gp: Vector2 = wv.p + offset + Vector2(cos(wv.gap), sin(wv.gap) * 0.5) * wv.r
	g.draw_rect(Rect2(gp.floor() - Vector2(2, 2), Vector2(4, 4)), Color(1, 1, 1, 0.7))

## The tower he raises out of the arena: blackstone, cracked with fire, the
## two fire sockets of the throne from chapter I on its crown.
static func tower(g, offset: Vector2):
	var e = g.world.ending
	if e.tower_h <= 0:return
	var base: Vector2 = e.tower_base() + offset
	var h: float = e.tower_h
	var wdt := 46.0
	var clock: float = g.world.clock
	g.oval(base + Vector2(0, 2), Vector2(34, 9), Color(0, 0, 0, 0.55))
	var top: float = base.y - h
	var y: float = top
	while y < base.y:
		var hh: float = minf(16.0, base.y - y)
		for x in range(int(wdt / 16.0) + 1):
			var ww: float = minf(16.0, wdt - x * 16)
			if ww <= 0:continue
			var shade: float = 0.62 if x < 2 else 0.45
			if g.textures.has("block_blackstone"):
				g.draw_texture_rect_region(g.textures.block_blackstone, Rect2(base.x - wdt / 2 + x * 16, y, ww, hh), Rect2(0, 0, ww, hh), Color(shade, shade * 0.9, shade))
		y += 16.0
	g.draw_rect(Rect2(base.x + wdt / 2 - 10, top, 10, h), Color(0, 0, 0, 0.35))
	for j in range(5):
		var cy: float = top + 10 + j * (h - 14) / 5.0
		var cx: float = base.x - wdt / 2 + 6 + h01i(j, 1) * (wdt - 12)
		g.draw_line(Vector2(cx, cy), Vector2(cx + 5, cy + 6), Color(1, 0.3, 0.1, 0.5 + 0.3 * sin(clock * 3 + j)), 1)
	g.draw_rect(Rect2(base.x - wdt / 2 - 3, top - 4, wdt + 6, 5), Color(0.12, 0.1, 0.12))
	for j in range(4):
		g.draw_rect(Rect2(base.x - wdt / 2 - 3 + j * 14, top - 9, 7, 5), Color(0.16, 0.13, 0.16))
	for side in [-1, 1]:
		g.draw_clip("fire_animation", Vector2(base.x + side * (wdt / 2 - 2) - 7, top - 26).floor(), Vector2(14, 20), clock + side)
	if e.phase == "tower" and e.age < float(e.data.tower.rise):
		for j in range(18):
			var q := base + Vector2((h01i(j, 2) - 0.5) * 80, -fposmod(clock * 30 + j * 7, 24))
			g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(0.35, 0.3, 0.32, 0.8))

static func h01i(i: int, salt: int) -> float:
	return Atmosphere.hash01(i, salt, 47)

## Chapter I's vortex closes around him — and he cuts it open from inside.
static func vortex(g, e, offset: Vector2):
	var v: Dictionary = e.data.vortex
	var clock: float = g.world.clock
	var q: Vector2 = e.vortex_at() + offset - Vector2(0, 12)
	var warp: float = float(v.warp)
	if e.age < warp + 0.7:
		var alpha: float = sin(clampf(e.age / (warp + 0.7), 0, 1) * PI)
		for i in range(38):
			var t: float = fposmod(i * 0.173 + e.age * 1.3, 1)
			var p: Vector2 = e.vortex_from.lerp(e.vortex_at(), t) + offset + Vector2(sin(i * 2.4) * 13, -sin(t * PI) * 30 - i % 4 * 2)
			g.draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(0.6, 0.35, 0.8, alpha * 0.8))
	var grow: float = smoothstep(float(v.grow[0]), float(v.grow[1]), e.age)
	var squeeze: float = 1.0 - 0.6 * smoothstep(float(v.squeeze[0]), float(v.squeeze[1]), e.age)
	var cut: float = float(v.cut)
	var split: float = float(v.split)
	var r: float = 54.0 * grow
	if e.age < cut:
		g.oval(q, Vector2(r * 1.2, r), Color(0.035, 0, 0.009, 0.92))
		if e.age >= warp:steve_squeezed(g, e.vortex_at() + offset, squeeze, grow, clock)
		for i in range(110):
			var t: float = fposmod(clock * 0.8 + i * 0.113, 1)
			var angle: float = i * 2.399 + t * 6
			var radius: float = (1 - t) * 92 * grow
			var p: Vector2 = q + Vector2(cos(angle) * radius * 1.2, sin(angle) * radius)
			g.draw_rect(Rect2(p.floor(), Vector2(1 + i % 3, 1 + i % 2)), Color(0.35 + i % 4 * 0.08, 0.005, 0.025, (1 - t) * grow))
		g.draw_arc(q, r, 0, TAU, 48, Color(0.75, 0.05, 0.08, 0.8 * grow), 2)
		g.draw_arc(q, r + 4, 0, TAU, 48, Color(0.5, 0.0, 0.03, 0.35 * grow), 3)
		return
	var t: float = e.age - cut
	var dir := Vector2(1, -0.45).normalized()
	var line_k: float = clampf(t / 0.08, 0, 1)
	var a: Vector2 = q - dir * (r + 30) * line_k
	var b: Vector2 = q + dir * (r + 30) * line_k
	var sep: float = smoothstep(split - cut, split - cut + 0.9, t) * 70.0
	var fade: float = 1.0 - smoothstep(split - cut + 0.3, split - cut + 1.2, t)
	if fade > 0:
		for side in [-1, 1]:
			var n: Vector2 = dir.orthogonal() * side
			var pts := PackedVector2Array()
			for j in range(25):
				var ang: float = dir.angle() + (0.0 if side < 0 else PI) + PI * j / 24.0
				var pt: Vector2 = q + Vector2(cos(ang) * r * 1.2, sin(ang) * r)
				pts.append(pt + n * sep * -1.0 + Vector2(0, sep * 0.3))
			g.draw_colored_polygon(pts, Color(0.035, 0, 0.009, 0.92 * fade))
			g.draw_polyline(pts, Color(0.7, 0.05, 0.08, fade), 2)
		for i in range(60):
			var ang: float = h01i(i, 3) * TAU
			var p: Vector2 = q + Vector2.from_angle(ang) * (t * (120 + h01i(i, 4) * 160)) + Vector2(0, t * t * 80)
			g.draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(0.5, 0.02, 0.05, fade))
	if t < 0.6:
		g.draw_line(a, b, Color(1, 1, 1, 0.25 * (1 - t / 0.6)), 12)
		g.draw_line(a, b, Color(1, 1, 1, 1 - t / 0.6), 3)
	var saved: Vector2 = g.world.player
	steve(g, offset, 1.0, Vector2.RIGHT)
	g.world.player = saved

static func steve_squeezed(g, p: Vector2, compression: float, strength: float, clock: float):
	var a: Dictionary = assets(g)
	var clip: Dictionary = a.steve.guard
	var size = Vector2(a.frame[0], a.frame[1])
	var anchor = Vector2(a.anchor[0], a.anchor[1])
	if not g.textures.has("ch4_fist_steve"):return
	var col: int = int(clip.start)
	for i in range(24):
		var shift: float = sin(clock * 6 + i * 0.7) * strength * 5.0
		var sx: float = (i * 2 - 24) * compression + shift
		var h: float = size.y * (0.4 + 0.6 * compression)
		g.draw_texture_rect_region(g.textures.ch4_fist_steve, Rect2(p + Vector2(sx, -anchor.y * (0.4 + 0.6 * compression)), Vector2(2 * compression + 0.5, h)),
			Rect2(col * size.x + i * 2, 0, 2, size.y), Color(1, 1 - strength * 0.45, 1 - strength * 0.4))

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
	var count = int(clampf(radius * 0.5, 8, 56))
	for i in range(count):
		var a = i * TAU / count
		if absf(angle_difference(a, ring.gap)) < float(r.gap) * 0.5:continue
		var q: Vector2 = p + Vector2(cos(a), sin(a) * 0.5) * radius
		g.draw_clip("fire_animation", (q - Vector2(7, 17)).floor(), Vector2(14, 17), clock + i * 0.07)

## The well: the ground darkens, chunks of it are torn up and spiral in.
static func black_hole_floor(g, e, offset: Vector2):
	var hd: Dictionary = e.data.two.hole
	var p: Vector2 = e.hole.p + offset
	var k: float = clampf(e.hole.age / float(hd.grow), 0, 1)
	var clock: float = g.world.clock
	var reach: float = float(hd.reach) * k
	if e.hole.burst:
		var t: float = e.hole.age - float(hd.grow)
		g.oval(p, Vector2(40, 20) * (1.0 + t), Color(0, 0, 0, maxf(0, 0.8 - t)))
		return
	for i in range(6):
		var rr: float = reach * (1.0 - i / 6.0)
		g.oval(p, Vector2(rr, rr * 0.55), Color(0.0, 0.0, 0.01, 0.12 + 0.03 * i))
	for j in range(18):
		var life: float = fposmod(clock * (0.35 + h(j, 20) * 0.25) + h(j, 21), 1.0)
		var r: float = reach * 1.15 * (1.0 - life * life)
		var a: float = h(j, 22) * TAU + life * (3.0 + h(j, 23) * 3.0)
		var q: Vector2 = p + Vector2(cos(a), sin(a) * 0.55) * r - Vector2(0, life * 10.0)
		var size: float = (3.0 + floorf(h(j, 24) * 4.0)) * (1.0 - life * 0.6)
		g.draw_rect(Rect2(q.floor(), Vector2(size, size)), Color(0.13, 0.11, 0.13))
		g.draw_rect(Rect2(q.floor(), Vector2(size, 1)), Color(0.36, 0.32, 0.36))
	for j in range(24):
		var a: float = j * TAU / 24 + clock * 0.3
		var t: float = fposmod(-clock * 1.4 + h(j, 25), 1.0)
		var r: float = reach * (0.35 + t * 0.75)
		var q: Vector2 = p + Vector2(cos(a), sin(a) * 0.55) * r
		var q2: Vector2 = p + Vector2(cos(a), sin(a) * 0.55) * (r - 8)
		g.draw_line(q.floor(), q2.floor(), Color(0.75, 0.65, 1.0, 0.35 * t * k), 1)

## The hole itself, drawn above the darkness so it burns through it.
static func black_hole_glow(g, e, offset: Vector2):
	var hd: Dictionary = e.data.two.hole
	var p: Vector2 = e.hole.p + offset
	var k: float = clampf(e.hole.age / float(hd.grow), 0, 1)
	var clock: float = g.world.clock
	if e.hole.burst:
		var t: float = e.hole.age - float(hd.grow)
		for i in range(3):
			var rr: float = 20.0 + t * (260.0 + i * 90.0)
			g.draw_arc(p, rr, 0, TAU, 64, Color(1, 0.92, 1, maxf(0, 0.9 - t * 1.2 - i * 0.2)), 3 - i)
		return
	var horizon: float = 8.0 + 20.0 * k
	var disk: float = horizon * 3.2
	# Accretion disk: rings of light on tilted orbits, white-hot inside, red at the rim.
	var tilt := 0.34
	for front in [false, true]:
		for ring in range(7):
			var u: float = ring / 6.0
			var r: float = horizon * (1.3 + u * 2.9)
			var c: Color = Color(1, 1, 1).lerp(Color(0.78, 0.5, 1.0), u).lerp(Color(0.95, 0.18, 0.2), u * u)
			var pts := PackedVector2Array()
			var spin: float = clock * 5.0 / pow(r / horizon, 1.5)
			for j in range(25):
				var a: float = (PI if front else 0.0) + PI * j / 24.0
				pts.append(p + Vector2(cos(a) * r, -sin(a) * r * tilt))
			g.draw_polyline(pts, Color(c, (0.55 - u * 0.3) * k * (1.0 if front else 0.7)), 2.0 if ring < 3 else 1.0)
			for j in range(10):
				var a: float = spin + j * TAU / 10 + ring
				if (sin(a) > 0) != front:continue
				var q: Vector2 = p + Vector2(cos(a) * r, sin(a) * r * tilt)
				g.draw_rect(Rect2(q.floor() - Vector2(1, 0), Vector2(3, 2)), Color(c, k))
		if not front:
			g.oval(p, Vector2(horizon + 3, horizon + 3), Color(0.8, 0.6, 1.0, 0.35 * k))
			g.oval(p, Vector2(horizon, horizon), Color(0, 0, 0, 1))
	# Lensed light bent over and under the horizon.
	g.draw_arc(p, horizon + 1.5, 0, TAU, 48, Color(1, 0.95, 1, 0.75 + 0.25 * sin(clock * 20.0)), 1.5)
	g.draw_arc(p + Vector2(0, -1), horizon * 1.35, PI * 1.08, PI * 1.92, 32, Color(1, 0.8, 0.95, 0.6 * k), 2)
	g.draw_arc(p + Vector2(0, 1), horizon * 1.2, PI * 0.12, PI * 0.88, 24, Color(0.9, 0.5, 0.9, 0.35 * k), 1)
	for j in range(40):
		var a: float = h(j, 32) * TAU + clock * (3.0 + h(j, 33))
		var r: float = disk * 0.6 + h(j, 34) * disk * 0.4
		var q: Vector2 = p + Vector2(cos(a) * r, sin(a) * r * 0.28)
		if sin(a) > 0:g.draw_rect(Rect2(q.floor(), Vector2.ONE), Color(1, 1, 1, k))

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
	g.draw_rect(Rect2(x - 4, top, 8, bottom - top), Color(0, 0, 0, 0.95))
	g.draw_rect(Rect2(x + 4, top, 1, bottom - top), Color(0.85, 0.75, 1.0, 0.5))
	for b in e.seam.bridges:
		var y: float = b + offset.y
		g.draw_rect(Rect2(x - 9, y - 14, 18, 28), Color(0.2, 0.17, 0.2))
		g.draw_rect(Rect2(x - 9, y - 14, 18, 1), Color(0.5, 0.45, 0.5))
	for y0 in e.seam.get("pulses", []):
		var y: float = y0 + offset.y
		g.draw_rect(Rect2(x - float(t.width), y - 3, float(t.width) * 2, 6), Color(0.85, 0.6, 1.0, 0.85))
		g.draw_rect(Rect2(x - 1, y - 12, 2, 24), Color(1, 1, 1, 0.9))

## Day acceleration on the ground: the clock face and his shadow, its hand.
static func day_floor(g, e, offset: Vector2):
	var p: Vector2 = e.hb.p + offset
	var clock: float = g.world.clock
	var sh: Dictionary = e.data.two.day.shadow
	var face_r: float = 58.0
	for i in range(12):
		var a: float = i * TAU / 12.0
		var q: Vector2 = p + Vector2(cos(a), sin(a) * 0.62) * face_r
		var q2: Vector2 = p + Vector2(cos(a), sin(a) * 0.62) * (face_r - (8.0 if i % 3 == 0 else 4.0))
		g.draw_line(q.floor(), q2.floor(), Color(0.85, 0.85, 0.9, 0.55), 2 if i % 3 == 0 else 1)
	var angles: Array = [e.shadow_angle]
	if e.split > 0:angles = [PI * 0.25, PI * 0.75]
	for a in angles:
		var dir := Vector2(cos(a), sin(a) * 0.62).normalized()
		var side := dir.orthogonal()
		var length: float = float(sh.length)
		var wid: float = float(sh.width) * 0.5
		var poly := PackedVector2Array([p + side * wid * 0.5, p - side * wid * 0.5, p + dir * length - side * wid * 1.5, p + dir * length + side * wid * 1.5])
		var on: bool = e.shadow_on or e.split > 0
		g.draw_colored_polygon(poly, Color(0, 0, 0, 0.82 if on else 0.22))
		if e.shadow_on:
			g.draw_line(p + side * wid * 0.5, p + dir * length + side * wid * 1.5, Color(1, 0.2, 0.15, 0.6 + 0.3 * sin(clock * 20.0)), 1)
			g.draw_line(p - side * wid * 0.5, p + dir * length - side * wid * 1.5, Color(1, 0.2, 0.15, 0.6 + 0.3 * sin(clock * 20.0)), 1)

static func air_layer(g, offset: Vector2):
	var e = g.world.ending
	if e.phase == "":return
	var clock: float = g.world.clock
	for b in e.shots:
		var p: Vector2 = (b.p + offset).floor()
		match b.kind:
			"rain":
				var dir: Vector2 = b.v.normalized()
				g.draw_line(p - dir * 16, p, Color(1, 1, 1, 0.3), 1)
				g.draw_line(p - dir * 6, p, Color(1, 1, 1, 0.8), 2)
				g.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color.WHITE)
			"knife":
				var dir: Vector2 = b.dir
				var side: Vector2 = dir.orthogonal()
				var glint: float = 0.6 + 0.4 * sin(clock * 9.0 + b.p.x * 0.3)
				g.draw_colored_polygon(PackedVector2Array([p + dir * 6, p + side * 2, p - dir * 4, p - side * 2]), Color(0, 0, 0, 0.8))
				g.draw_colored_polygon(PackedVector2Array([p + dir * 5, p + side * 1.2, p - dir * 3, p - side * 1.2]), Color(1, 1, 1, glint))
				if not b.get("frozen", false):g.draw_line(p - dir * 14, p, Color(1, 1, 1, 0.3), 1)
			"debris":
				var spin: float = clock * 8.0 + b.get("spin", 0.0)
				var size: float = 5.0
				var q := p + Vector2(cos(spin), sin(spin)) * 0.5
				g.draw_rect(Rect2(q - Vector2(size, size) / 2, Vector2(size, size)), Color(0.18, 0.15, 0.18))
				g.draw_rect(Rect2(q - Vector2(size, size) / 2, Vector2(size, 1 + int(spin) % 2)), Color(0.5, 0.45, 0.5))
				g.draw_line(p, p - b.v.normalized() * 8, Color(0.8, 0.6, 1.0, 0.4), 1)
			_:
				var c = Color(1, 0.9, 0.75) if b.kind == "day" else Color(1, 0.3, 0.25)
				g.draw_line(p - b.v.normalized() * 7, p, Color(c, 0.4), 2)
				g.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0, 0, 0, 0.7))
				g.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), c)
	for d in e.drops:
		if d.hit:continue
		var k: float = clampf(d.age / float(e.data.two.rain.heavy_windup), 0, 1)
		var q: Vector2 = (d.p + offset - Vector2(0, 200 * (1.0 - k * k))).floor()
		g.draw_line(q - Vector2(0, 26), q, Color(1, 1, 1, 0.35), 3)
		g.draw_rect(Rect2(q - Vector2(3, 6), Vector2(6, 8)), Color.WHITE)
	if e.move == "rain":rain_sky(g, e, offset)

## The torn sky over the arena the white rain falls from.
static func rain_sky(g, e, offset: Vector2):
	var clock: float = g.world.clock
	var top: float = e.arena.position.y + offset.y - 14
	var x0: float = e.arena.position.x + offset.x
	var n: int = int(e.arena.size.x / 10.0)
	for i in range(n):
		var x: float = x0 + i * 10.0
		var depth: float = 8.0 + 6.0 * sin(clock * 1.7 + i * 0.6) + h(i, 40) * 8.0
		g.draw_rect(Rect2(x, top - 10, 10, depth + 10), Color(0.02, 0.02, 0.03, 0.85))
		g.draw_rect(Rect2(x, top + depth - 1, 10, 1), Color(1, 1, 1, 0.35 + 0.3 * sin(clock * 5.0 + i)))

static func effect(g, ef: Dictionary, offset: Vector2) -> bool:
	var p: Vector2 = ef.p + offset
	var k: float = clampf(ef.age / maxf(0.001, ef.total), 0, 1)
	match ef.kind:
		"ch4_hb_blink":
			var s: float = ef.get("scale", 1.0)
			figure(g, "ch4_hb_calm", "herobrine", "idle", 0.0, p, ef.dir, s, Color(0, 0, 0, 0.6 * (1 - k)))
			for j in range(10):
				g.draw_rect(Rect2((p + Vector2(sin(j * 2.4) * 8 * s, -10 * s - j * 4 * s - k * 14 * s)).floor(), Vector2(2, 1)), Color(1, 1, 1, 1 - k))
		"ch4_hb_bolt":
			var top = p - Vector2(14, 230)
			for branch in range(3):
				var last = top + Vector2(branch * 9 - 9, 0)
				var end: Vector2 = p if branch == 1 else p + Vector2((branch - 1) * 26, -40 - branch * 10)
				for j in range(1, 11):
					var q = last.lerp(end, 1.0 / (11 - j)) + Vector2(sin(j * 7.0 + ef.p.x + branch) * 7, 0)
					var width: float = 5.0 if branch == 1 else 2.0
					g.draw_line(last.floor(), q.floor(), Color(0.55, 0.75, 1, 0.6 * (1 - k)), width)
					g.draw_line(last.floor(), q.floor(), Color(1, 1, 1, 1 - k), 1 if branch != 1 else 2)
					last = q
			g.draw_arc(p, ef.radius * (1 + k * 1.5), 0, TAU, 32, Color(1, 1, 1, 1 - k), 2)
			g.oval(p, Vector2(ef.radius, ef.radius * 0.5) * (1.0 - k), Color(1, 1, 1, 0.5 * (1 - k)))
		"ch4_hb_scorch":
			g.oval(p, Vector2(ef.radius, ef.radius * 0.5) * 0.8, Color(0, 0, 0, 0.6 * (1 - k)))
			for j in range(8):
				var q = p + Vector2((h(j, 50) - 0.5) * ef.radius * 1.4, (h(j, 51) - 0.5) * ef.radius * 0.6 - k * 20.0 * h(j, 52))
				g.draw_rect(Rect2(q.floor(), Vector2.ONE), Color(0.7, 0.85, 1.0, (1 - k) * 0.9))
		"ch4_hb_slash":
			var end: Vector2 = ef.end + offset
			var s: float = ef.get("scale", 1.0)
			for j in range(4):
				var q: Vector2 = p.lerp(end, j / 3.0)
				figure(g, "ch4_hb_calm", "herobrine", "lunge", 0.1, q, ef.get("dir", Vector2.RIGHT), s, Color(0, 0, 0, (0.15 + 0.12 * j) * (1 - k)))
			g.draw_line(p, end, Color(0.2, 0.0, 0.03, (1 - k) * 0.8), 9)
			g.draw_line(p, end, Color(1, 1, 1, 1 - k), 3)
		"ch4_hb_cast":
			var s: float = ef.get("scale", 1.0)
			var big: bool = ef.get("big", false)
			var r: float = (30.0 + k * (140.0 if big else 80.0)) * s * 0.6
			g.draw_arc(p, r, 0, TAU, 48, Color(1, 1, 1, (1 - k) * 0.8), 2)
			g.draw_arc(p, r * 0.7, 0, TAU, 48, Color(aura_color(g.world.ending), (1 - k) * 0.6), 1)
			var col: float = (1 - k) * (0.5 if big else 0.25)
			g.draw_rect(Rect2(p.x - 4 * s, p.y - 260, 8 * s, 260), Color(1, 1, 1, col * 0.3))
			g.draw_rect(Rect2(p.x - 1, p.y - 260, 2, 260), Color(1, 1, 1, col))
			for j in range(14):
				var a: float = j * TAU / 14 + h(j, 53)
				var q: Vector2 = p + Vector2(cos(a), sin(a) * 0.5) * r * (0.6 + h(j, 54) * 0.5)
				g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(0.4, 0.36, 0.4, 1 - k))
		"ch4_hb_splash":
			g.draw_arc(p, ef.radius * (0.5 + k), 0, TAU, 24, Color(1, 1, 1, 1 - k), 2)
			for j in range(10):
				var a: float = -PI * (0.1 + 0.8 * h(j, 55))
				var q: Vector2 = p + Vector2(cos(a), sin(a)) * k * 26.0 + Vector2(0, k * k * 30.0)
				g.draw_rect(Rect2(q.floor(), Vector2(2, 2)), Color(1, 1, 1, 1 - k))
		"ch4_hb_strip":
			var to: Vector2 = ef.to + offset
			var q: Vector2 = p.lerp(to, k * k) + Vector2(0, -sin(k * PI) * 40.0)
			if k < 0.8:
				g.item_icon(ef.id, (q - Vector2(8, 8)).floor())
				g.draw_line(p.lerp(to, maxf(0, k * k - 0.1)) + Vector2(0, -sin(maxf(0, k - 0.1) * PI) * 40.0), q, Color(1, 1, 1, 0.4), 1)
			else:
				for j in range(8):
					var d = Vector2.from_angle(j * 0.8) * (k - 0.8) * 120.0
					g.draw_rect(Rect2((q + d).floor(), Vector2(2, 2)), Color(1, 1, 1, (1 - k) * 5.0))
		"ch4_hb_drain":pass
		"ch4_hb_head":head_burst(g, p, ef.age)
		"ch4_hb_ignite":
			var fire_k = 1.0 - k
			g.draw_clip("fire_animation", (p - Vector2(6, 14)).floor(), Vector2(12, 14), ef.age)
			for j in range(8):
				var q = p + Vector2(sin(j * 2.4) * 6, -k * 24 - j * 2)
				g.draw_rect(Rect2(q.floor(), Vector2.ONE), Color(1, 0.4, 0.2, fire_k))
		_:return false
	return true

## The final blow: cubes of the head scatter with the two white eye pixels.
## Local space (the head on the ground at the origin); the caller scales it.
static func head_burst(g, p: Vector2, age: float):
	var colors = [Color("2e1f10"), Color("b4846d"), Color("aa7d66"), Color("6b2a1c"), Color("7a0c10"), Color("4a0508")]
	var ground: float = p.y + 4.0
	var pool: float = minf(1.0, age * 0.6)
	for j in range(6):
		var w: float = (8.0 + j * 4.0) * pool
		g.draw_rect(Rect2(Vector2(p.x - w / 2 - 2, ground - 1 + j * 0.4).floor(), Vector2(w, 1.5 + j % 2)), Color(0.32, 0.0, 0.02, 0.9))
	for j in range(34):
		var a: float = -PI * 0.5 + (h(j, 60) - 0.5) * 2.9
		var speed: float = 22.0 + h(j, 61) * 50.0
		var t: float = minf(age, 0.9)
		var q: Vector2 = p + Vector2(cos(a), sin(a)) * speed * t + Vector2(0, 120.0 * t * t)
		q.y = minf(q.y, ground + h(j, 62) * 2.0)
		var size: float = 1.0 + float(j % 3 == 0)
		g.draw_rect(Rect2(q.floor(), Vector2(size, size)), colors[j % colors.size()])
	for j in range(2):
		var t: float = minf(age, 0.9)
		var q: Vector2 = p + Vector2(-3 + j * 6, -9) * minf(1.0, age * 3.0) + Vector2(0, 80.0 * t * t)
		q.y = minf(q.y, ground)
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
	if not e.hole.is_empty():black_hole_glow(g, e, offset)
	if e.move == "day" and (e.sky > 0.0 or e.split > 0.0 or e.sun > 0.0):day_sky(g, e, offset)
	if e.phase == "last":last_attack(g, e, offset)
	if e.phase == "vortex":vortex(g, e, offset)
	if e.phase in ["erase", "three", "death", "retry"]:island(g, e, offset, -1.0)
	if e.phase in ["erase", "three", "retry", "death"]:duel(g, e, offset)
	if e.phase in ["one", "two"]:boss_bar(g, e)
	if e.phase == "three":prompt(g, e)
	words(g, e, offset)
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
	var k: float = maxf(0, hb.hp) / maxf(1, hb.max_hp)
	g.draw_rect(Rect2(169, 46, 302, 6), Color("1a1416"))
	g.draw_rect(Rect2(169, 46, 302 * k, 6), Color("d0d0d4") if e.phase == "one" else Color("b8182a"))
	g.draw_rect(Rect2(169, 46, 302 * k, 1), Color(1, 1, 1, 0.5))
	g.centered("Херобрин", 40, 8, g.INK)

## Day acceleration: sun and moon race over the sky leaving trails, the stars
## wheel; when time stops both hang in one sky and everything goes cold.
static func day_sky(g, e, offset: Vector2):
	var clock: float = g.world.clock
	var night: float = 1.0 - e.sky
	g.draw_rect(Rect2(0, 0, 640, 360), Color(1.0, 0.85, 0.6, 0.08 * e.sky))
	var cycles: Array = e.data.two.day.cycles
	var c: float = float(cycles[mini(int(e.sun), cycles.size() - 1)])
	var pole := Vector2(320, -40)
	if e.split <= 0.0:
		for j in range(46):
			var r: float = 60.0 + h(j, 70) * 380.0
			var a0: float = h(j, 71) * TAU + e.sun * TAU * 0.5
			var arc: float = minf(1.2, 0.5 / c)
			var pts := PackedVector2Array()
			for s in range(6):
				var a: float = a0 - arc * s / 5.0
				pts.append(pole + Vector2(cos(a), sin(a)) * r)
			g.draw_polyline(pts, Color(1, 1, 1, 0.35 * night), 1)
	var bodies: Array = []
	if e.split > 0.0:
		bodies = [["ch4_sun", PI * 0.78, 1.0], ["ch4_moon", PI * 0.22, 1.0]]
	else:
		var th: float = (fposmod(e.sun, 1.0) - 0.25) * TAU
		bodies = [["ch4_sun", th, 1.0], ["ch4_moon", th + PI, 1.0]]
	for body in bodies:
		var trail: int = 0 if e.split > 0.0 else 9
		for j in range(trail, -1, -1):
			var th: float = body[1] - j * 0.05 * (3.0 / c)
			var q := Vector2(320 - cos(th) * 340, 320 - sin(th) * 270)
			if q.y > 330:continue
			var a: float = 1.0 if j == 0 else 0.25 * (1.0 - j / 10.0)
			var size: float = 44.0
			if j == 0:
				var warm: Color = Color(1, 0.9, 0.7) if body[0] == "ch4_sun" else Color(0.75, 0.8, 1.0)
				for ring in range(4):g.draw_circle(q, size * (0.7 + ring * 0.35), Color(warm, 0.07))
			if g.textures.has(body[0]):
				g.draw_texture_rect(g.textures[body[0]], Rect2(q - Vector2(size, size) / 2, Vector2(size, size)), false, Color(1, 1, 1, a))
	if e.split > 0.0:
		var k: float = e.split
		g.draw_rect(Rect2(0, 0, 640, 360), Color(0.55, 0.62, 0.8, 0.16 * k))
		Atmosphere.draw_edges(g, Color(0.85, 0.9, 1.0, 0.4 * k))
		for j in range(40):
			var q := Vector2(h(j, 72) * 640, h(j, 73) * 360)
			g.draw_rect(Rect2(q.floor(), Vector2.ONE), Color(1, 1, 1, 0.5 * k))

## The last attack: the world is erased from the edges in, beams sweep.
static func last_attack(g, e, offset: Vector2):
	var clock: float = g.world.clock
	island(g, e, offset, e.void_r)
	var p: Vector2 = e.hb.p + offset - Vector2(0, 14 * e.scale())
	for b in e.beams:
		var dir := Vector2.from_angle(b.a)
		var end: Vector2 = p + dir * 700
		if not b.hot:
			var flick: float = 0.4 + 0.4 * sin(clock * 30.0)
			g.draw_line(p, end, Color(1, 1, 1, flick * 0.6), 1)
		else:
			var wdt: float = float(e.data.last.beam_width)
			g.draw_line(p, end, Color(1, 1, 1, 0.12), wdt * 2.2)
			g.draw_line(p, end, Color(0.85, 0.85, 1.0, 0.45), wdt)
			g.draw_line(p, end, Color(1, 1, 1, 1), 3)
	var k: float = smoothstep(0.0, float(e.data.last.duration), e.age)
	var orb: Vector2 = p - Vector2(0, 34 * e.scale())
	g.draw_circle(orb, 6.0 * (1.0 + k + 0.15 * sin(clock * 25.0)), Color(1, 1, 1, 0.35))
	g.draw_circle(orb, 3.0 * (1.0 + k), Color(1, 1, 1, 0.95))
	if e.age > float(e.data.last.duration) - 1.2:
		var t: float = (e.age - (float(e.data.last.duration) - 1.2)) / 1.2
		g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, t * t * 0.9))

## Everything beyond the last patch of ground is erased to a void.
static func island(g, e, offset: Vector2, radius: float):
	var c: Vector2 = e.center + offset
	if radius < 0:
		radius = float(e.data.arena.island)
		if e.phase == "erase":radius = lerpf(float(e.data.last.void_to), radius, smoothstep(0.0, 1.0, e.age))
	var outer = 1200.0
	var n = 56
	for i in range(n):
		var a0 = i * TAU / n
		var a1 = (i + 1) * TAU / n
		var r0 = radius + sin(i * 2.7) * 4.0
		var r1 = radius + sin((i + 1) * 2.7) * 4.0
		g.draw_colored_polygon(PackedVector2Array([c + Vector2(cos(a0), sin(a0) * 0.62) * r0, c + Vector2(cos(a1), sin(a1) * 0.62) * r1, c + Vector2(cos(a1), sin(a1)) * outer, c + Vector2(cos(a0), sin(a0)) * outer]), Color(0.008, 0.006, 0.01))
	for j in range(24):
		var a = j * TAU / 24 + g.world.clock * 0.05
		var fall: float = fposmod(g.world.clock * 14 + j * 7, 30)
		var q = (c + Vector2(cos(a), sin(a) * 0.62) * (radius + 3) + Vector2(0, fall)).floor()
		g.draw_rect(Rect2(q, Vector2(2, 2)), Color(0.35, 0.3, 0.32, 1.0 - fall / 30.0))
		if e.phase == "last":g.draw_rect(Rect2(q - Vector2(0, fall + 2), Vector2(1, 1)), Color(1, 1, 1, 0.8))

# ------------------------------------------------------------------ the fistfight

static func bump(t: float, rise: float = 0.07, fall: float = 0.35) -> float:
	if t < 0:return 0.0
	if t < rise:return t / rise
	return maxf(0.0, 1.0 - (t - rise) / fall)

## Screen offsets of both fighters from the current exchange.
static func duel_offsets(e) -> Array:
	var hb_d := Vector2.ZERO
	var st_d := Vector2.ZERO
	var q: Dictionary = e.qte
	if e.phase != "three" or q.is_empty():return [hb_d, st_d]
	var wind: float = clampf(q.age / q.windup, 0, 1)
	if q.result == "":
		if q.kind in ["dodge", "hold", "seq"]:hb_d.x += 8.0 * wind
		else:st_d.x -= 6.0 * wind
		if q.kind == "hold" and q.age >= q.windup:
			var push: float = sin(e.age * 30.0) * 1.5
			hb_d.x -= 14.0; st_d.x += 10.0 + push
		return [hb_d, st_d]
	var t: float = q.age - q.resolved
	if q.result == "ok":
		match q.kind:
			"dodge":
				hb_d.x -= 44.0 * bump(t, 0.08, 0.5)
				match q.dir:
					"left":st_d.x -= 26.0 * bump(t, 0.06, 0.6)
					"up":st_d.y -= 18.0 * bump(t, 0.06, 0.6)
					"down":st_d.y += 18.0 * bump(t, 0.06, 0.6)
					_:st_d.y += 16.0 * bump(t, 0.06, 0.6); st_d.x -= 8.0 * bump(t, 0.06, 0.6)
			"attack":
				st_d.x += 20.0 * bump(t, 0.06, 0.5)
				hb_d.x += (120.0 * smoothstep(0.0, 0.5, t)) if q.hb == "fall" else 30.0 * bump(t, 0.05, 0.7)
			"hold", "seq", "mash":
				st_d.x += 18.0 * bump(t, 0.06, 0.5)
				hb_d.x += 40.0 * bump(t, 0.06, 0.8)
	else:
		hb_d.x -= 26.0 * bump(t, 0.06, 0.5)
		st_d.x -= 34.0 * bump(t, 0.08, 0.8)
	for imp in e.impacts:
		var since: float = e.age - imp.at
		if imp.on == "hb" and q.result == "":hb_d.x += 12.0 * bump(since, 0.03, 0.25); st_d.x += 10.0 * bump(since, 0.03, 0.2)
	return [hb_d, st_d]

## The fistfight and the death are shown close, in clean profile.
static func duel(g, e, offset: Vector2):
	profile = true
	duel_inner(g, e, offset)
	profile = false

static func duel_inner(g, e, offset: Vector2):
	var clock: float = g.world.clock
	var c: Vector2 = e.center + offset
	if e.phase == "death":
		death_scene(g, e, c, offset)
		return
	if e.phase == "erase":
		erase_scene(g, e, c, offset)
		return
	var punch: float = 0.0
	for imp in e.impacts:punch = maxf(punch, bump(e.age - imp.at, 0.02, 0.3) * (0.18 if imp.big else 0.07))
	var s: float = DUEL * (1.0 + punch)
	var offs: Array = duel_offsets(e)
	var hp: Vector2 = c + (e.hb.p - e.center) * s + offs[0]
	var sp: Vector2 = c + (g.world.player - e.center) * s + offs[1]
	var open: bool = not e.qte.is_empty() and e.qte.result == "" and e.qte.age >= e.qte.windup
	if open or e.impact_frame > 0:speed_lines(g, (hp + sp) / 2 - Vector2(0, 22 * s), clock, 0.25 if open else 0.6)
	if e.impact_frame > 0 and g.settings.flashes:
		g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1))
		draw_hb_at(g, e, hp, offset, s, Color(0, 0, 0))
		var saved: Vector2 = g.world.player
		g.world.player = sp - offset
		steve(g, offset, s, Vector2.RIGHT, Color(0, 0, 0))
		g.world.player = saved
		var mid: Vector2 = (hp + sp) / 2 - Vector2(0, 22 * s)
		for j in range(16):
			var d := Vector2.from_angle(j * TAU / 16 + h(j, 80) * 0.3)
			g.draw_line(mid + d * 30, mid + d * (120 + h(j, 81) * 200), Color(0, 0, 0), 2 + j % 3)
		g.draw_line(mid + Vector2(-90, 50), mid + Vector2(90, -50), Color(0.75, 0.0, 0.05), 5)
		return
	g.oval(c + Vector2(0, 2), Vector2(70, 10), Color(1, 1, 1, 0.04))
	draw_hb_at(g, e, hp, offset, s, Color(0, 0, 0, 0))
	var saved: Vector2 = g.world.player
	g.world.player = sp - offset
	steve(g, offset, s, Vector2.RIGHT)
	g.world.player = saved
	for imp in e.impacts:
		var at: Vector2 = (hp if imp.on == "hb" else sp) + Vector2(-10 * s if imp.on == "hb" else 10 * s, -22 * s)
		impact_burst(g, at, e.age - imp.at, imp.big, int(imp.seed), imp.on == "hb")
	if not e.qte.is_empty() and e.qte.result == "fail":
		var t: float = e.qte.age - e.qte.resolved
		Atmosphere.draw_edges(g, Color(0.7, 0.0, 0.03, 0.5 * bump(t, 0.03, 0.6)))

## Spent: the giant shrinks on the last patch of ground, close up.
static func erase_scene(g, e, c: Vector2, offset: Vector2):
	var hs: float = DUEL * e.scale()
	var hp: Vector2 = c + (e.hb.p - e.center) * DUEL
	var sp: Vector2 = c + (g.world.player - e.center) * DUEL
	g.oval(c + Vector2(0, 2), Vector2(80, 12), Color(1, 1, 1, 0.04))
	for ef in g.world.effects:
		if ef.kind != "ch4_hb_drain":continue
		var k: float = clampf(ef.age / maxf(0.001, ef.total), 0, 1)
		var gs: float = DUEL * float(ef.scale) * (1.0 + k * 0.25)
		figure(g, "ch4_hb_rage", "herobrine", "exhausted", 0.0, hp, Vector2.LEFT, gs, Color(1, 1, 1, 0.35 * (1 - k)))
		for j in range(22):
			var a: float = -PI * 0.5 + (h(j, 56) - 0.5) * 2.8
			var q: Vector2 = hp - Vector2(0, 24 * hs) + Vector2(cos(a), sin(a)) * k * (90.0 + 120.0 * h(j, 57))
			g.draw_line(q.floor(), (q - Vector2(cos(a), sin(a)) * 10).floor(), Color(1, 1, 1, 1 - k), 2)
	draw_hb_at(g, e, hp, offset, hs, Color(0, 0, 0, 0))
	var saved: Vector2 = g.world.player
	g.world.player = sp - offset
	steve(g, offset, DUEL, Vector2.RIGHT)
	g.world.player = saved
	if e.age < 0.8:g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, 1.0 - e.age / 0.8))

static func draw_hb_at(g, e, at: Vector2, offset: Vector2, s: float, tint: Color):
	var saved: Vector2 = e.hb.p
	e.hb.p = at - offset
	herobrine(g, offset, s, tint)
	e.hb.p = saved

static func speed_lines(g, at: Vector2, clock: float, alpha: float):
	for j in range(28):
		var d := Vector2.from_angle(j * TAU / 28 + h(j + int(clock * 12) * 3, 82) * 0.2)
		var r0: float = 120.0 + h(j, 83) * 80.0
		g.draw_line(at + d * r0, at + d * (r0 + 120 + h(j, 84) * 200), Color(1, 1, 1, alpha * (0.4 + 0.6 * h(j + int(clock * 20), 85))), 1)

static func impact_burst(g, at: Vector2, t: float, big: bool, seed: int, blood: bool):
	if t < 0 or t > 0.7:return
	var k: float = t / 0.7
	var size: float = (1.6 if big else 1.0)
	if t < 0.1:
		g.draw_circle(at, (8.0 + t * 140.0) * size, Color(1, 1, 1, 0.9 - t * 8.0))
	for j in range(10):
		var d := Vector2.from_angle(j * TAU / 10 + h(j + seed, 86) * 0.5)
		var r0: float = (8.0 + t * 120.0) * size
		g.draw_line(at + d * r0, at + d * (r0 + (24.0 - t * 30.0) * size), Color(1, 1, 1, 1.0 - k * 1.4), 2)
	g.draw_arc(at, (10.0 + t * 110.0) * size, 0, TAU, 32, Color(1, 1, 1, 0.7 - k * 1.2), 2)
	if blood:
		for j in range(12):
			var a: float = -PI * 0.5 + (h(j + seed, 87) - 0.2) * 2.4
			var q: Vector2 = at + Vector2(cos(a), sin(a)) * t * (90.0 + 80.0 * h(j + seed, 88)) * size + Vector2(0, t * t * 260.0)
			g.draw_rect(Rect2(q.floor(), Vector2(2, 2) * (1 + int(big))), Color(0.6, 0.02, 0.05, 1.0 - k))

## His end: one baked tableau of both bodies, the hero astride his chest.
static func tableau(g, clip: String, t: float, at: Vector2, s: float, tint: Color = Color.WHITE):
	var tab: Dictionary = assets(g).tableau
	if not tab.clips.has(clip) or not g.textures.has("ch4_death_tableau"):return
	var c: Dictionary = tab.clips[clip]
	var fps: float = 3.0 if clip.begins_with("still") else (4.0 if clip.begins_with("stand") else 11.0)
	var index: int = int(t * fps)
	index = index % int(c.count) if clip.begins_with("still") else mini(int(c.count) - 1, index)
	var size := Vector2(tab.frame[0], tab.frame[1])
	var anchor := Vector2(tab.anchor[0], tab.anchor[1])
	g.draw_texture_rect_region(g.textures.ch4_death_tableau, Rect2((at - anchor * s).floor(), size * s), Rect2(Vector2((int(c.start) + index) * size.x, 0), size), tint)

static func death_scene(g, e, c: Vector2, offset: Vector2):
	var s: float = DEATH
	var at: Vector2 = c + Vector2(-8, 34)
	var tab: Dictionary = assets(g).tableau
	var head: Vector2 = at + Vector2(tab.head[0], tab.head[1]) * s
	var clip: String = {"mount_raise": "raise", "mount_slam": "slam", "lower_arm": "stand"}.get(e.steve_pose, "still")
	if e.pose == "headless":clip += "_x"
	if e.impact_frame > 0 and g.settings.flashes:
		g.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1))
		tableau(g, clip, e.steve_pose_age, at, s, Color(0, 0, 0))
		for j in range(16):
			var d := Vector2.from_angle(j * TAU / 16 + h(j, 89) * 0.3)
			g.draw_line(head + d * 20, head + d * (100 + h(j, 90) * 220), Color(0.7, 0.0, 0.04), 2 + j % 3)
		return
	g.oval(at + Vector2(0, 3), Vector2(70, 10), Color(1, 1, 1, 0.04))
	var hits: int = 0
	for t in e.data.death.punches:
		if e.age >= float(t):hits += 1
	if hits > 0:
		var pool: float = 6.0 + hits * 3.0 + (14.0 if e.head_at >= 0 else 0.0) * minf(1.0, (e.age - e.head_at) * 0.5)
		g.oval(Vector2(head.x + 4, at.y + 1), Vector2(pool * 1.6, pool * 0.35), Color(0.3, 0.0, 0.02, 0.9))
	tableau(g, clip, e.steve_pose_age, at, s)
	# The swing: a pale arc from the drawn-back fist down onto his face.
	var since: float = e.age - e.punch_at
	var swing: float = since if e.head_at < 0 else e.age - e.head_at
	if swing >= 0.0 and swing < 0.22 and clip.begins_with("slam"):
		var shoulder: Vector2 = at + Vector2(-1, -22) * s
		var radius: float = shoulder.distance_to(head)
		var a1: float = (head - shoulder).angle()
		var a0: float = a1 - 2.2
		for k in range(3):
			var pts := PackedVector2Array()
			for j in range(13):
				pts.append(shoulder + Vector2.from_angle(lerpf(a0, a1, j / 12.0)) * (radius - k * 5.0))
			g.draw_polyline(pts, Color(1, 1, 1, (0.7 - k * 0.2) * (1.0 - swing / 0.22)), 3 - k)
	if since >= 0.0 and since < 0.5 and e.head_at < 0.0:
		impact_burst(g, head + Vector2(0, -2), since, false, int(e.punch_at * 10), true)
		Atmosphere.draw_edges(g, Color(0.5, 0.0, 0.03, 0.4 * (1.0 - since / 0.5)))
	if e.head_at >= 0.0:
		var t: float = e.age - e.head_at
		g.draw_set_transform(head, 0, Vector2(s, s))
		head_burst(g, Vector2.ZERO, t)
		g.draw_set_transform(Vector2.ZERO)
		if t < 0.6:impact_burst(g, head, t, true, 99, true)
		Atmosphere.draw_edges(g, Color(0.45, 0.0, 0.03, 0.6 * maxf(0.0, 1.0 - t * 0.5)))

static func key_glyph(g, at: Vector2, action: String, k: float, state: String, size: float = 1.4):
	var c = Color(1, 1, 1, 0.95)
	if state == "ok":c = Color(1, 1, 1, 1)
	elif state == "fail":c = Color(0.9, 0.12, 0.12)
	var half: float = 13.0 * size
	g.draw_rect(Rect2(at - Vector2(half, half), Vector2(half, half) * 2), Color(0, 0, 0, 0.8))
	g.draw_rect(Rect2(at - Vector2(half, half), Vector2(half, half) * 2), c, false, 2)
	if action == "attack" or action == "hold":
		g.text_at("ПРОБЕЛ", at + Vector2(-17, half + 16), 8, c, true)
		g.draw_rect(Rect2(at - Vector2(8, 3) * size, Vector2(16, 6) * size), c)
		return
	var dir: Vector2 = {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}[action] * size
	var side = dir.orthogonal()
	g.draw_colored_polygon(PackedVector2Array([at + dir * 9, at + side * 7 - dir * 1, at + side * 3 - dir * 1, at + side * 3 - dir * 8, at - side * 3 - dir * 8, at - side * 3 - dir * 1, at - side * 7 - dir * 1]), c)

## QTE prompt: the key, a ring closing on the window, a bar for holding.
static func prompt(g, e):
	var q: Dictionary = e.qte
	if q.is_empty() or q.age < q.windup - 0.15:return
	var at = Vector2(320, 74)
	var window: float = float(q.window)
	var left: float = clampf(1.0 - (q.age - q.windup) / window, 0, 1)
	var state: String = q.result
	var shake := Vector2.ZERO
	if state == "fail":shake = Vector2(sin(e.age * 80.0), 0) * 3.0 * maxf(0, 1.0 - (q.age - q.resolved) * 3.0)
	at += shake
	match q.kind:
		"dodge":key_glyph(g, at, q.dir, left, state)
		"attack":key_glyph(g, at, "attack", left, state, 1.6 if q.hb == "fall" else 1.4)
		"hold":
			key_glyph(g, at, "hold", left, state)
			var fill: float = clampf(q.held / (window * 0.75), 0, 1)
			g.draw_rect(Rect2(at + Vector2(-40, 46), Vector2(80, 5)), Color(0, 0, 0, 0.8))
			g.draw_rect(Rect2(at + Vector2(-40, 46), Vector2(80 * fill, 5)), Color(1, 1, 1))
		"mash":
			var pulse: float = 1.4 + 0.15 * sin(e.age * 40.0)
			key_glyph(g, at, "attack", left, state, pulse)
			var n: int = int(q.count)
			for i in range(n):
				var x: float = at.x + (i - (n - 1) / 2.0) * 10
				g.draw_rect(Rect2(Vector2(x - 3, at.y + 50), Vector2(6, 6)), Color(1, 1, 1) if i < q.progress else Color(1, 1, 1, 0.25))
		"seq":
			var n: int = q.dirs.size()
			for i in range(n):
				var s = "ok" if i < q.progress else state if state == "fail" else ""
				key_glyph(g, at + Vector2((i - (n - 1) / 2.0) * 44, 0), q.dirs[i], left, s, 1.2)
	if state == "":
		g.draw_arc(at, 26 + 22 * left, 0, TAU, 40, Color(1, 1, 1, 0.75), 2)
	elif state == "ok":
		var t: float = q.age - q.resolved
		g.draw_arc(at, 26 + t * 120.0, 0, TAU, 40, Color(1, 1, 1, maxf(0, 1.0 - t * 2.5)), 2)

# ------------------------------------------------------------------ the living text

static func words(g, e, offset: Vector2):
	for t in e.text_events:
		var age: float = e.age - t.at
		match t.style:
			"calm":calm_line(g, e, t, age, offset)
			"roar":roar(g, t, age)
			"laugh":laugh(g, t, age)
			"crawl":crawl(g, t, age)
			"plead":plead(g, t, age)

static func calm_line(g, e, t: Dictionary, age: float, offset: Vector2):
	var shown = mini(t.text.length(), int(age * 11.0))
	var text: String = t.text.substr(0, shown)
	var fade: float = 1.0 - smoothstep(t.life - 0.6, t.life, age)
	var p: Vector2 = (e.hb.p + offset - Vector2(0, 50 + 56 * (e.scale() - 1.0))) if not e.hb.is_empty() else Vector2(320, 120)
	# Cold and still: large letters, slow reveal, no tremble at all.
	var width: float = g.font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var at = Vector2(clampf(p.x - width / 2, 8, 632 - width), maxf(64, p.y)).floor()
	g.text_at(text, at + Vector2(1, 1), 16, Color(0, 0, 0, fade))
	g.text_at(text, at, 16, Color(0.92, 0.92, 0.95, fade))

## «ХВАТИТ.» — one word, huge, shaking the screen it is written on.
static func roar(g, t: Dictionary, age: float):
	var text: String = t.text
	var fade: float = 1.0 - smoothstep(t.life - 0.5, t.life, age)
	var size: int = 32
	var width: float = g.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var frame: int = int(age * 30.0)
	var shake: float = maxf(1.5, 8.0 * (1.0 - age * 1.5))
	var base := Vector2(320 - width / 2, 120)
	for copy in range(3):
		var j := Vector2(Atmosphere.hash01(frame, copy, 18) - 0.5, Atmosphere.hash01(frame, copy, 19) - 0.5) * shake * (1 + copy)
		var col: Color = [Color(1, 1, 1, fade), Color(0.8, 0.0, 0.05, fade * 0.6), Color(0.2, 0.0, 0.0, fade * 0.4)][copy]
		g.text_at(text, (base + j).floor(), size, col)

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
			var base = Vector2(320 + (i - n / 2.0) * (18 + local * 4.0), 74 + sin(local * 3.0 + i * 0.8) * (8 + local * 6.0) + copy * 26)
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
		var p = Vector2(320 + (i - n / 2.0) * 14, 84) + drift + jitter
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
			var p = Vector2(320 + (i - line.length() / 2.0) * 13, 62 + li * 24) + jitter
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

# ------------------------------------------------------------------ note, road, door

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

## A door that does not belong: a solid black slab standing on nothing. When
## it opens, pale light and black flakes fall out of it — not darkness, a
## colourless light the world has no shadow for.
static func door(g, e, offset: Vector2):
	var clock: float = g.world.clock
	var p: Vector2 = Vector2(e.data.door.p[0], e.data.door.p[1]) + offset
	var size = Vector2(24, 48)
	var depth = Vector2(7, -5)
	var top_left: Vector2 = p - Vector2(size.x / 2, size.y)
	var tree = p + Vector2(110, -36)
	g.sprite("tree_dead_1", tree - Vector2(32, 67), Vector2.ZERO, Color(0.55, 0.5, 0.5))
	g.draw_rect(Rect2(tree + Vector2(-5, -40), Vector2(10, 20)), Color(0, 0, 0))
	var open: float = 0.0
	match e.door_state:
		"open", "look", "enter", "gone":open = 1.0 if e.door_state != "open" else smoothstep(4.0, 5.2, e.age)
		"closed":open = 1.0 - smoothstep(10.4, 10.55, e.age)
	# Its shadow falls the wrong way, towards the light.
	g.draw_colored_polygon(PackedVector2Array([p + Vector2(-size.x / 2, 0), p + Vector2(size.x / 2, 0) + depth, p + Vector2(size.x / 2 + 30, 10) + depth, p + Vector2(-size.x / 2 + 30, 10)]), Color(0, 0, 0, 0.5))
	# Light spilling onto the ground in front of the opening.
	if open > 0:
		var spill: float = open * (0.85 + 0.15 * sin(clock * 2.0))
		for i in range(8):
			var k: float = i / 8.0
			var wdt: float = size.x * (1.0 + k * 1.8)
			var y: float = p.y + k * 40.0
			g.draw_rect(Rect2(p.x - wdt / 2, y, wdt, 5), Color(0.92, 0.94, 1.0, 0.2 * (1.0 - k) * spill))
	# The slab: a side face and a top face give it weight.
	g.draw_colored_polygon(PackedVector2Array([top_left + Vector2(size.x, 0), top_left + Vector2(size.x, 0) + depth, top_left + size + depth, top_left + size]), Color(0.035, 0.035, 0.04))
	g.draw_colored_polygon(PackedVector2Array([top_left, top_left + depth, top_left + Vector2(size.x, 0) + depth, top_left + Vector2(size.x, 0)]), Color(0.06, 0.06, 0.065))
	g.draw_rect(Rect2(top_left, size), Color(0, 0, 0))
	if open > 0:
		# The opening: not dark. A cold even light with black flakes falling through it.
		var inner := Rect2(top_left + Vector2(3, 3), size - Vector2(6, 3))
		var cut: float = inner.size.x * open
		var lit := Rect2(inner.position, Vector2(cut, inner.size.y))
		for i in range(int(lit.size.y)):
			var k: float = i / lit.size.y
			g.draw_rect(Rect2(lit.position.x, lit.position.y + i, lit.size.x, 1), Color(0.78 + 0.18 * (1.0 - k), 0.8 + 0.17 * (1.0 - k), 0.86 + 0.13 * (1.0 - k), open))
		for j in range(18):
			var fall: float = fposmod(clock * (12.0 + h(j, 91) * 10.0) + h(j, 92) * 60.0, 60.0)
			var q := Vector2(lit.position.x + h(j, 93) * lit.size.x, lit.position.y + fall)
			if fall < lit.size.y and q.x < lit.end.x:
				g.draw_rect(Rect2(q.floor(), Vector2(1, 2)), Color(0, 0, 0, 0.8 * open))
			elif fall >= lit.size.y:
				var out := Vector2(p.x + (h(j, 93) - 0.5) * (size.x + (fall - lit.size.y) * 1.4), p.y + (fall - lit.size.y) * 0.6)
				g.draw_rect(Rect2(out.floor(), Vector2(1, 1)), Color(0, 0, 0, 0.7 * open * (1.0 - (fall - lit.size.y) / 14.0)))
		var panel_w: float = size.x * (1.0 - open)
		if panel_w > 0.5:g.draw_rect(Rect2(top_left + Vector2(size.x - panel_w, 0), Vector2(panel_w, size.y)), Color(0.02, 0.02, 0.025))
		g.draw_rect(Rect2(top_left, Vector2(size.x, 3)), Color(0, 0, 0))
	# The hero walks into the opening: the light takes him, the frame stays in front.
	if e.door_state not in ["gone", "closed"]:
		var sp: Vector2 = g.world.player + offset
		var into: float = clampf((p.y + 18.0 - sp.y) / 16.0, 0, 1) if e.door_state == "enter" else 0.0
		var tint := Color(0.82, 0.82, 0.86).lerp(Color(1.8, 1.8, 1.9), into)
		tint.a = 1.0 - into * 0.95
		steve(g, offset, 1.0 - into * 0.15, Vector2.ZERO, tint)
		if e.door_state == "enter":
			g.draw_rect(Rect2(top_left, Vector2(3, size.y)), Color(0, 0, 0))
			g.draw_rect(Rect2(top_left + Vector2(size.x - 3, 0), Vector2(3, size.y)), Color(0, 0, 0))
			g.draw_rect(Rect2(top_left, Vector2(size.x, 3)), Color(0, 0, 0))
	if e.door_state in ["gone", "closed"] and e.age > 11.2:
		g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, smoothstep(11.2, 13.2, e.age)))
