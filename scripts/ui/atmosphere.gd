extends RefCounted
## Chapter atmosphere: grass, fireflies and mist (I), ash, embers and souls (II),
## hit and health feedback for every chapter. Presentation only: positions come
## from integer hashes of world cells and the paused world clock, never from the
## simulation RNG.
const Lighting = preload("res://scripts/ui/lighting.gd")

static var ground_image: Image
static var vignette: ImageTexture

static func hash01(x: int, y: int, salt: int = 0) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65536.0

## Soft white edge mask, generated once; tinted by the caller.
static func edge_mask() -> ImageTexture:
	if vignette == null:
		var img := Image.create(320, 180, false, Image.FORMAT_RGBA8)
		for y in range(180):
			for x in range(320):
				var d := Vector2((x - 159.5) / 160.0, (y - 89.5) / 90.0).length()
				img.set_pixel(x, y, Color(1, 1, 1, smoothstep(0.55, 1.15, d)))
		vignette = ImageTexture.create_from_image(img)
	return vignette

static func draw_edges(g, color: Color):
	if color.a <= 0.003:
		return
	g.draw_texture_rect(edge_mask(), Rect2(0, 0, 640, 360), false, color)

## 0 at dawn, 1 in the deepest chapter I night.
static func night(g) -> float:
	var m: Dictionary = Lighting.mood(g)
	return clampf((m.dark - 0.07) / 0.43, 0.0, 1.0) if not g.is_nether() and not g.is_end() else 0.0

# ------------------------------------------------------------------ chapter I

static func grass_green(p: Vector2) -> bool:
	if ground_image == null:
		return false
	var x := int(p.x)
	var y := int(p.y)
	if x < 0 or y < 0 or x >= ground_image.get_width() or y >= ground_image.get_height():
		return false
	var c := ground_image.get_pixel(x, y)
	return c.g > c.r * 1.12 and c.g > c.b * 1.1

## Swaying grass blades on green ground; they lean away from the hero.
static func overworld_grass(g, offset: Vector2):
	var w = g.world
	if not g.settings.get("lighting", true) or w.finale.active:
		return
	if ground_image == null and g.textures.has("ground"):
		ground_image = g.textures.ground.get_image()
		if ground_image != null and ground_image.is_compressed():
			ground_image.decompress()
	var cam: Vector2 = -offset + Vector2(320, 180)
	var clock: float = w.clock if w.state != "MENU" else g.ui_time
	var c0 := Vector2i(((cam - Vector2(330, 190)) / 24).floor())
	var c1 := Vector2i(((cam + Vector2(330, 200)) / 24).ceil())
	var hero: Vector2 = w.player
	# Batched: one multiline call per blade shade keeps draw calls flat.
	var shadow := PackedVector2Array()
	var dark := PackedVector2Array()
	var mid := PackedVector2Array()
	var light := PackedVector2Array()
	var bright := PackedVector2Array()
	for cy in range(c0.y, c1.y):
		for cx in range(c0.x, c1.x):
			var roll := hash01(cx, cy, 11)
			if roll > 0.3:
				continue
			var p := Vector2(cx * 24 + hash01(cx, cy, 12) * 20, cy * 24 + hash01(cx, cy, 13) * 20)
			if not grass_green(p):
				continue
			var sway := sin(clock * 1.7 + p.x * 0.045 + p.y * 0.02) * 1.5
			var away := p - hero
			if w.state != "MENU" and away.length_squared() < 256:
				sway += signf(away.x if absf(away.x) > 0.5 else 1.0) * (16.0 - away.length()) * 0.3
			var s := (p + offset).floor()
			var tall := 5.0 + float(int(roll * 37) % 4)
			shadow.append_array([s + Vector2(-2, 1), s + Vector2(5, 1)])
			dark.append_array([s + Vector2(-1, 0), s + Vector2(-3 + sway * 0.6, -tall + 2)])
			mid.append_array([s + Vector2(2, 0), s + Vector2(4 + sway * 0.7, -tall + 1)])
			light.append_array([s, s + Vector2(sway * 0.8, -tall)])
			bright.append_array([s + Vector2(1, 0), s + Vector2(1 + sway, -tall - 1)])
			if roll < 0.035:
				var bloom: Color = [Color(0.95, 0.85, 0.3), Color(0.9, 0.9, 0.95), Color(0.75, 0.55, 0.95)][int(roll * 1000) % 3]
				g.draw_rect(Rect2(s + Vector2(sway, -tall - 2), Vector2(2, 2)), bloom)
	if shadow.is_empty():
		return
	g.draw_multiline(shadow, Color(0.06, 0.14, 0.04, 0.4), 1)
	g.draw_multiline(dark, Color(0.13, 0.26, 0.08), 1)
	g.draw_multiline(mid, Color(0.18, 0.34, 0.1), 1)
	g.draw_multiline(light, Color(0.36, 0.58, 0.18), 1)
	g.draw_multiline(bright, Color(0.5, 0.72, 0.26), 1)

static func fireflies(g, offset: Vector2) -> Array:
	var w = g.world
	var amount := night(g)
	var result := []
	if amount <= 0.02 or w.finale.active:
		return result
	var cam: Vector2 = -offset + Vector2(320, 180)
	var clock: float = w.clock if w.state != "MENU" else g.ui_time
	var c0 := Vector2i(((cam - Vector2(360, 220)) / 96).floor())
	var c1 := Vector2i(((cam + Vector2(360, 220)) / 96).ceil())
	for cy in range(c0.y, c1.y):
		for cx in range(c0.x, c1.x):
			if hash01(cx, cy, 21) > 0.55:
				continue
			var phase := hash01(cx, cy, 22) * TAU
			var center := Vector2(cx * 96 + 48, cy * 96 + 48) + Vector2(hash01(cx, cy, 23) - 0.5, hash01(cx, cy, 24) - 0.5) * 70
			var p := center + Vector2(sin(clock * 0.43 + phase) * 22, cos(clock * 0.57 + phase * 1.3) * 14 - 10)
			var blink := pow(maxf(0.0, sin(clock * 1.9 + phase * 3.0)), 2.0) * amount
			if blink > 0.03:
				result.append({"p": p, "blink": blink})
	return result

static func mist(g, offset: Vector2):
	var fog: float = g.world.fog_amount() if g.world.has_method("fog_amount") else 0.0
	var amount := minf(1.0, night(g) + fog * 2.5)
	if amount <= 0.02 or g.world.finale.active:
		return
	var cam: Vector2 = -offset + Vector2(320, 180)
	var clock: float = g.world.clock if g.world.state != "MENU" else g.ui_time
	var c0 := Vector2i(((cam - Vector2(500, 330)) / 220).floor())
	var c1 := Vector2i(((cam + Vector2(500, 330)) / 220).ceil())
	for cy in range(c0.y, c1.y):
		for cx in range(c0.x, c1.x):
			if hash01(cx, cy, 31) > 0.5:
				continue
			var p := Vector2(cx * 220 + hash01(cx, cy, 32) * 160, cy * 220 + hash01(cx, cy, 33) * 160) + Vector2(clock * 3.0 + sin(clock * 0.1 + cx) * 30, 0) + offset
			var size := Vector2(110, 34) * (0.8 + hash01(cx, cy, 34) * 0.6)
			for k in range(4):
				g.oval(p, size * (1.0 - k * 0.2), Color(0.62, 0.7, 0.82, 0.018 * amount * (1.0 + fog * 2.0)))
	if fog > 0:
		g.draw_rect(Rect2(0, 0, 640, 360), Color(0.55, 0.6, 0.66, 0.13 * fog))

# ------------------------------------------------------------------ chapter II

static func nether_lights(g, offset: Vector2):
	var w = g.world
	if w.stage != "survival" or w.soul_sand.is_empty():
		return
	var cam: Vector2 = -offset + Vector2(320, 180)
	var t0 := Vector2i(((cam - Vector2(330, 190)) / 16).floor())
	var t1 := Vector2i(((cam + Vector2(330, 190)) / 16).ceil())
	for ty in range(maxi(0, t0.y), mini(128, t1.y)):
		for tx in range(maxi(0, t0.x), mini(128, t1.x)):
			if w.soul_sand[ty * 128 + tx] and hash01(tx, ty, 41) < 0.025:
				g.ambient_lights.append({"p": Vector2(tx * 16 + 8, ty * 16 + 4), "r": 28.0, "c": Color(0.35, 0.8, 1.0), "power": 0.55, "glow": 0.14})

static func nether_air(g, offset: Vector2):
	var w = g.world
	if not g.settings.get("lighting", true) or w.stage not in ["survival", "wither"]:
		return
	var clock: float = w.clock
	# Soul flames over soul sand (positions mirror nether_lights).
	for l in g.ambient_lights:
		var base: Vector2 = l.p + offset
		for j in range(3):
			var phase := fposmod(clock * 0.8 + j * 0.33 + l.p.x * 0.01, 1.0)
			var q := base + Vector2(sin(clock * 3.0 + j * 2.0) * 2.0, -phase * 14.0)
			g.draw_rect(Rect2(q.floor(), Vector2.ONE * (2 if j == 0 else 1)), Color(0.55, 0.9, 1.0, (1.0 - phase) * 0.85))
	# Embers rising from magma.
	for patch in w.magma:
		var c: Vector2 = patch.p + offset
		if c.x < -60 or c.y < -60 or c.x > 700 or c.y > 420:
			continue
		for j in range(6):
			var phase := fposmod(clock * 0.45 + j * 0.17 + patch.p.y * 0.003, 1.0)
			var q := c + Vector2(sin(j * 2.1 + patch.p.x) * patch.radius * 0.7 + sin(clock * 2.0 + j) * 3.0, -phase * 46.0)
			g.draw_rect(Rect2(q.floor(), Vector2.ONE), Color(1.0, 0.75 - phase * 0.5, 0.2, (1.0 - phase) * 0.9))
	# Falling ash, slightly parallaxed.
	for j in range(46):
		var x := fposmod(j * 97.31 + offset.x * 1.1 + sin(clock * 0.4 + j) * 9.0, 660.0) - 10.0
		var y := fposmod(j * 53.17 + clock * (9.0 + j % 5 * 2.0) + offset.y * 1.1, 380.0) - 10.0
		g.draw_rect(Rect2(Vector2(x, y).floor(), Vector2.ONE * (1 + j % 2)), Color(0.55, 0.5, 0.5, 0.32))
	draw_edges(g, Color(0.12, 0.01, 0.0, 0.38))

# ------------------------------------------------------------------ every chapter

## Collected before lighting so presentation lights reach the darkness mesh.
static func collect(g, offset: Vector2):
	g.ambient_lights.clear()
	if g.is_end():
		return
	if g.is_nether():
		nether_lights(g, offset)
		return
	if "landmarks" in g.world:
		for mark in g.world.landmarks:
			if mark.kind == "mine_entrance":
				var flick := 1.0 + 0.07 * sin(g.world.clock * 11.0) + 0.04 * sin(g.world.clock * 23.0)
				g.ambient_lights.append({"p": mark.p + Vector2(-20, -22), "r": 70.0 * flick, "c": Color(1.0, 0.6, 0.25), "power": 0.9, "glow": 0.22})
	for f in fireflies(g, offset):
		g.ambient_lights.append({"p": f.p, "r": 22.0, "c": Color(0.85, 1.0, 0.45), "power": 0.55 * f.blink, "glow": 0.22 * f.blink})

## Drawn after lighting: glowing points and air layers stay bright at night.
static func after_lighting(g, offset: Vector2):
	if g.is_nether():
		nether_air(g, offset)
	elif not g.is_end():
		mist(g, offset)
		for f in fireflies(g, offset):
			var s: Vector2 = (f.p + offset).floor()
			g.draw_rect(Rect2(s - Vector2.ONE, Vector2(3, 3)), Color(0.8, 1.0, 0.4, 0.25 * f.blink))
			g.draw_rect(Rect2(s, Vector2.ONE), Color(1.0, 1.0, 0.7, f.blink))
	level_burst(g, offset)

## Ring around the hero after a level-up, played on the world clock.
static func level_burst(g, offset: Vector2):
	var w = g.world
	if w.state == "MENU" or (g.coop.active and not g.coop.running):
		return
	if w.level > g.burst_level:
		if g.burst_level > 0:
			g.burst_clock = w.clock
		g.burst_level = w.level
	elif w.level < g.burst_level:
		g.burst_level = w.level
	var age: float = w.clock - g.burst_clock
	if age < 0.0 or age > 0.7:
		return
	var k := age / 0.7
	var p: Vector2 = w.player + offset - Vector2(0, 10)
	var color := Color(0.6, 1.0, 0.3, (1.0 - k) * 0.8)
	g.draw_arc(p, 10.0 + k * 46.0, 0, TAU, 40, color, 2)
	for j in range(10):
		var dir := Vector2.from_angle(j * TAU / 10 + 0.3)
		g.draw_line(p + dir * (8 + k * 30), p + dir * (14 + k * 40), Color(0.9, 1.0, 0.6, (1.0 - k) * 0.7), 1)

## Hurt flash and low-health warning at the screen edges, under the HUD.
static func health_edges(g):
	var w = g.world
	if w.state not in ["RUNNING", "FINALE"]:
		return
	var hurt: float = w.player_visual.get("hurt", 0.0) if w.player_visual is Dictionary else 0.0
	var alpha := 0.0
	if hurt > 0 and g.settings.flashes:
		alpha = hurt / 0.12 * 0.32
	if w.hp > 0 and w.hp <= 6:
		var low: float = (1.0 - w.hp / 6.0) * 0.3 + 0.08
		if g.settings.flashes:
			low *= 0.75 + 0.25 * sin(w.clock * 6.0)
		alpha = maxf(alpha, low)
	draw_edges(g, Color(0.7, 0.0, 0.02, alpha))
