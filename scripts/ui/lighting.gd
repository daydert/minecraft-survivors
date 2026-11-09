extends RefCounted
## Screen-space lighting for the world layer. A vertex-coloured darkness mesh is
## appended to the game canvas after the world and before the HUD; light
## sources reveal and tint it. Pure presentation: it reads the world and its
## paused clock, never the simulation RNG, and never writes.
const CELL := 16
const COLS := 42
const ROWS := 25
const NIGHT := Color(0.02, 0.04, 0.11)
const DAWN := Color(0.30, 0.13, 0.16)
const WARM := Color(1.0, 0.82, 0.55)
const FIRE := Color(1.0, 0.55, 0.18)
const ENDER := Color(0.72, 0.38, 1.0)
const XP := Color(0.55, 1.0, 0.3)

static var points := PackedVector2Array()
static var indices := PackedInt32Array()

static func ensure_mesh():
	if not points.is_empty():
		return
	for y in range(ROWS):
		for x in range(COLS):
			points.append(Vector2(x * CELL, y * CELL))
	for y in range(ROWS - 1):
		for x in range(COLS - 1):
			var i := y * COLS + x
			indices.append_array([i, i + 1, i + COLS, i + 1, i + COLS + 1, i + COLS])

## Ambient darkness for the current chapter and moment: {dark, color}.
static func mood(g) -> Dictionary:
	var w = g.world
	if g.is_four():
		var e = g.world.ending
		if g.world.stage == "finale" and e.phase != "":
			if e.phase in ["three","death","retry","erase"]:return {"dark": 0.6, "color": Color(0.01,0.008,0.015)}
			return {"dark": lerpf(0.52, 0.06, e.sky), "color": Color(0.018,0.02,0.04).lerp(Color(0.3,0.22,0.12), e.sky)}
		return {"dark": 0.5, "color": Color(0.018,0.02,0.04)}
	if g.is_end():
		if w.stage in ["survival", "end_arrival", "departure"]:
			return {"dark": 0.17, "color": Color(0.06, 0.02, 0.11)}
		if w.stage in ["dragon", "last_duel", "hand", "hand_pickup", "return_portal", "portal_ready", "exit_portal"]:
			return {"dark": 0.26, "color": Color(0.05, 0.01, 0.10)}
		return {"dark": 0.0, "color": NIGHT}
	if g.is_nether():
		if w.stage == "survival":
			return {"dark": 0.30, "color": Color(0.10, 0.015, 0.0)}
		if w.stage in ["wither", "defeat", "portal", "lighting", "arrival"]:
			return {"dark": 0.24, "color": Color(0.07, 0.0, 0.02)}
		return {"dark": 0.0, "color": NIGHT}
	if w.finale.active:
		return {"dark": 0.0, "color": NIGHT}
	# Chapter I "До рассвета": the night deepens, then the first dawn arrives at 12:00.
	var t: float = w.time
	var dark := lerpf(0.30, 0.50, smoothstep(0.0, 360.0, t))
	var dawn := smoothstep(540.0, 718.0, t)
	var color := NIGHT.lerp(DAWN, dawn)
	var moon: float = w.blood_moon() if w.has_method("blood_moon") else 0.0
	return {"dark": lerpf(dark, 0.07, dawn) + 0.05 * moon, "color": color.lerp(Color(0.3, 0.0, 0.04), moon * 0.6)}

static func light(list: Array, p: Vector2, radius: float, color: Color, power: float = 1.0, glow: float = 0.0):
	if p.x < -radius or p.y < -radius or p.x > 640 + radius or p.y > 360 + radius:
		return
	list.append({"p": p, "r": radius, "c": color, "power": power, "glow": glow})

## Every light on screen, in screen coordinates.
static func sources(g, offset: Vector2) -> Array:
	var w = g.world
	var list := []
	var clock: float = w.clock
	var flicker := func(seed_value: float) -> float: return 1.0 + 0.06 * sin(clock * 13.0 + seed_value * 1.7) + 0.04 * sin(clock * 21.0 + seed_value)
	if g.coop.active and (g.coop.running or g.coop.loading):
		for a in w.players.values():
			if a.alive or a.in_finale:
				light(list, a.player + offset - Vector2(0, 10), 135, WARM, 1.0, 0.03)
	elif w.state != "MENU":
		var lift: float = w.elevation() if w.has_method("elevation") else 0.0
		light(list, w.player + offset - Vector2(0, 10 + lift), 125 if g.is_four() else 135, Color(0.92, 0.88, 0.86) if g.is_four() else WARM, 1.0, 0.02 if g.is_four() else 0.03)
	var orbs := 0
	for o in w.orbs:
		orbs += 1
		if orbs > 60:
			break
		light(list, o.p + offset, 20, XP, 0.45, 0.10)
	for o in w.loot:
		light(list, o.p + offset - Vector2(0, 8), 44 if o.kind == "chest" else 26, Color(1, 0.85, 0.4), 0.7, 0.12)
	for m in w.mobs:
		if m.hp <= 0:
			continue
		var p: Vector2 = m.p + offset
		if m.get("burn", 0.0) > 0:
			light(list, p - Vector2(0, 10), 52 * flicker.call(m.id), FIRE, 0.8, 0.22)
		if m.kind == "blaze_nether":
			light(list, p - Vector2(0, 14), 64 * flicker.call(m.id), FIRE, 0.9, 0.25)
		elif m.kind == "creeper" and m.get("fuse", -1.0) >= 0:
			light(list, p - Vector2(0, 10), 40, Color(1, 1, 0.85), 0.6, 0.15)
		elif m.kind in ["endersteve", "endersteve_final"]:
			light(list, p - Vector2(0, 14), 48, ENDER, 0.45, 0.14)
	for b in w.projectiles:
		var p: Vector2 = b.p + offset - Vector2(0, 9)
		match b.kind:
			"fire", "enemy_flame", "rocket":
				light(list, p, 46 * flicker.call(b.age), FIRE, 0.85, 0.22)
			"shulker_bullet", "end_bullet", "end_blade":
				light(list, p, 34, ENDER, 0.6, 0.18)
			"dragon_fireball":
				light(list, p, 58, ENDER, 0.8, 0.25)
			"wither_skull":
				light(list, p, 26, Color(0.6, 0.5, 0.7), 0.35, 0.05)
			"arrow":
				if b.get("evolved", false):
					light(list, p, 34, FIRE, 0.6, 0.15)
	for e in w.effects:
		var p: Vector2 = e.p + offset
		var fade := 1.0 - clampf(e.age / maxf(0.001, e.total), 0.0, 1.0)
		match e.kind:
			"explosion", "enemy_explosion":
				light(list, p, e.radius * 2.6, Color(1, 0.8, 0.45), fade * 1.2, 0.35 * fade)
			"lightning":
				light(list, p, 150, Color(0.8, 0.9, 1.0), fade * 1.4, 0.3 * fade)
			"crystal_blast", "mace_impact", "dragon_impact", "end_teleport":
				light(list, p, e.get("radius", 30.0) * 2.0, ENDER, fade, 0.25 * fade)
			"friendly_breath", "dragon_cloud":
				light(list, p, e.get("radius", 30.0) * 1.3, ENDER, 0.5, 0.12)
			"hoe_spin", "axe_spin":
				pass
	if "magma" in w:
		for patch in w.magma:
			light(list, patch.p + offset, patch.radius * 2.8 * flicker.call(patch.p.x), FIRE, 0.95, 0.24)
	if "explosives" in w:
		for b in w.explosives:
			if b.kind == "tnt" and b.fuse > 0 and fmod(b.fuse, 0.3) < 0.15:
				light(list, b.p + offset - Vector2(0, 8 + b.get("height", 0.0)), 30, Color(1, 1, 0.9), 0.6, 0.18)
	if "portal_lit" in w and w.portal_lit:
		light(list, w.portal_position + offset - Vector2(0, 20), 120, ENDER, 1.0, 0.18)
	if "crystals" in w:
		for t in w.crystals:
			if t.alive:
				light(list, t.p + offset - Vector2(0, 18), 96 * flicker.call(t.id), ENDER, 1.0, 0.22)
	for f in g.ambient_lights:
		light(list, f.p + offset, f.r, f.c, f.power, f.glow)
	return list

static func draw(g, offset: Vector2):
	if not g.settings.get("lighting", true):
		return
	var m := mood(g)
	var dark: float = m.dark
	if dark <= 0.001:
		return
	ensure_mesh()
	# The grid is anchored to world cells so gradients never swim with the camera.
	var shift := Vector2(fposmod(offset.x, CELL), fposmod(offset.y, CELL)) - Vector2(CELL, CELL)
	var count := points.size()
	var lit := PackedFloat32Array()
	lit.resize(count)
	var tint := PackedColorArray()
	tint.resize(count)
	tint.fill(Color(0, 0, 0, 0))
	for l in sources(g, offset):
		var p: Vector2 = l.p - shift
		var r: float = l.r
		var x0 := maxi(0, int(floor((p.x - r) / CELL)))
		var x1 := mini(COLS - 1, int(ceil((p.x + r) / CELL)))
		var y0 := maxi(0, int(floor((p.y - r) / CELL)))
		var y1 := mini(ROWS - 1, int(ceil((p.y + r) / CELL)))
		var color: Color = l.c
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var i := y * COLS + x
				var d := points[i].distance_to(p)
				if d >= r:
					continue
				var k := 1.0 - d / r
				var f: float = l.power * k * k
				lit[i] += f
				var t := tint[i]
				tint[i] = Color(t.r + color.r * f, t.g + color.g * f, t.b + color.b * f, t.a + l.glow * k * k)
	var ambient: Color = m.color
	var colors := PackedColorArray()
	colors.resize(count)
	for i in range(count):
		var amount := minf(1.0, lit[i])
		if amount <= 0.0:
			colors[i] = Color(ambient.r, ambient.g, ambient.b, dark)
			continue
		var t := tint[i]
		var weight := maxf(0.0001, lit[i])
		var hue := Color(t.r / weight, t.g / weight, t.b / weight)
		var c := ambient.lerp(hue, amount)
		colors[i] = Color(c.r, c.g, c.b, dark * (1.0 - amount) + minf(0.32, t.a))
	var item: RID = g.get_canvas_item()
	RenderingServer.canvas_item_add_set_transform(item, Transform2D(0.0, shift))
	RenderingServer.canvas_item_add_triangle_array(item, indices, points, colors)
	RenderingServer.canvas_item_add_set_transform(item, Transform2D.IDENTITY)
