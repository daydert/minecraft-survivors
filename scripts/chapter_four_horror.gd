extends RefCounted
## Chapter IV dread: eyes that stay lit beyond the hero's light, a white-eyed
## watcher at the edge of vision, veins pulsing through the flesh, low red fog,
## film grain and a heavy vignette. Presentation only: it reads the world and
## the paused clock, keeps its own state on the canvas, never touches combat.
const Atmosphere = preload("res://scripts/ui/atmosphere.gd")

static var grain: ImageTexture

static func hash01(x: int, y: int, salt: int) -> float:
	return Atmosphere.hash01(x, y, salt)

# ------------------------------------------------------------------ floor

## Veins crawling through flesh tiles; a pulse runs along them like a heartbeat.
static func veins(g, offset: Vector2):
	var w = g.world
	if not "terrain" in w or not g.settings.get("lighting", true):
		return
	if not g.has_meta("ch4_flesh"):
		var cells := {}
		for c in w.terrain.get("flesh_cells", []):
			cells[Vector2i(int(c) % 128, int(c) / 128)] = true
		g.set_meta("ch4_flesh", cells)
	var flesh: Dictionary = g.get_meta("ch4_flesh")
	var t0 := Vector2i(((-offset) / 16).floor())
	var beat := pow(maxf(0.0, sin(w.clock * 2.4)), 6.0)
	var lines := PackedVector2Array()
	var hot := PackedVector2Array()
	for ty in range(t0.y - 1, t0.y + 25):
		for tx in range(t0.x - 1, t0.x + 42):
			var cell := Vector2i(tx, ty)
			if not flesh.has(cell) or hash01(tx, ty, 61) > 0.45:
				continue
			var a := Vector2(tx * 16 + 2 + hash01(tx, ty, 62) * 12, ty * 16 + 2 + hash01(tx, ty, 63) * 12) + offset
			var dir := Vector2.from_angle(hash01(tx, ty, 64) * TAU)
			var b := a + dir * 9 + dir.orthogonal() * 3
			var c := b + dir.rotated(0.7) * 7
			lines.append_array([a.floor(), b.floor(), b.floor(), c.floor()])
			var wave := pow(maxf(0.0, sin(w.clock * 2.4 - (tx + ty) * 0.35)), 8.0)
			if wave > 0.5:
				hot.append_array([a.floor(), b.floor()])
	if not lines.is_empty():
		g.draw_multiline(lines, Color(0.16, 0.0, 0.02, 0.85), 1)
	if not hot.is_empty():
		g.draw_multiline(hot, Color(1.0, 0.22, 0.2, 0.55 + 0.3 * beat), 1)

# ------------------------------------------------------------------ after lighting

static func eye_row(g, m: Dictionary) -> float:
	var meta: Dictionary = g.world.animation.data.actors.get(m.get("skin", m.kind), {})
	var anchor: float = float(meta.get("anchor", [0, 29])[1]) if meta.has("anchor") else 29.0
	return anchor * 0.68 + float(m.get("lift", 0.0))

## Glinting eyes for every enemy outside the hero's light. Readable in the
## dark and the first thing the player sees of a flanking pack.
static func eyes(g, offset: Vector2):
	var w = g.world
	if not g.settings.get("lighting", true):
		return
	var dots := PackedVector2Array()
	var dim := PackedVector2Array()
	for m in w.mobs:
		if m.hp <= 0 or not m.has("form") or m.get("allied", false):
			continue
		var distance: float = m.p.distance_to(w.player)
		var dark := smoothstep(70.0, 135.0, distance)
		if dark <= 0.05:
			continue
		var p: Vector2 = (m.p + offset).floor()
		if not Rect2(-10, -10, 660, 380).has_point(p):
			continue
		# Rare, unsynchronised blinks.
		var blink := fposmod(w.clock * 0.37 + float(m.id) * 0.61, 1.0)
		if blink < 0.035:
			continue
		var face: Vector2 = m.get("visual_dir", Vector2.DOWN)
		if face.y < -0.5:
			continue
		var y := p.y - eye_row(g, m)
		var spread := 1.0 if absf(face.x) > absf(face.y) else 3.0
		var x := p.x + (signf(face.x) * 3.0 if absf(face.x) > absf(face.y) else 0.0)
		var bucket := dots if dark > 0.5 else dim
		bucket.append_array([Vector2(x - spread, y), Vector2(x - spread + 1, y), Vector2(x + spread - 1, y), Vector2(x + spread, y)])
	if not dim.is_empty():
		g.draw_multiline(dim, Color(1.0, 0.55, 0.5, 0.45), 1)
	if not dots.is_empty():
		g.draw_multiline(dots, Color(1.0, 0.86, 0.8, 0.95), 1)

## Herobrine is never far: a still figure at the edge of the light that is gone
## the moment the hero comes close. Its own canvas state; frozen on pause.
static func watcher(g, offset: Vector2):
	var w = g.world
	if w.stage != "survival" or w.state != "RUNNING" and w.state != "PAUSED":
		return
	if "encounters" in w and w.encounters.busy():
		return
	var window := int(w.clock / 47.0)
	var state: Dictionary = g.get_meta("ch4_watcher") if g.has_meta("ch4_watcher") else {}
	if state.get("window", -1) != window:
		state = {"window": window, "shown": false, "gone": false}
		if hash01(window, 7, 71) < 0.7 and w.clock > 40:
			state.at = float(window) * 47.0 + 9.0 + hash01(window, 8, 72) * 20.0
		g.set_meta("ch4_watcher", state)
	if not state.has("at") or state.gone or w.clock < state.at:
		return
	if not state.shown:
		var away: Vector2 = -w.facing if w.facing.length_squared() > 0 else Vector2.DOWN
		var dir := away.rotated((hash01(window, 9, 73) - 0.5) * 1.6)
		state.p = w.player + dir * 225.0
		state.shown = true
		state.seen_at = w.clock
	var age: float = w.clock - state.seen_at
	if w.player.distance_to(state.p) < 165.0 or age > 4.5:
		state.gone = true
		state.vanish = w.clock
		g.set_meta("ch4_watcher", state)
		return
	var p: Vector2 = (state.p + offset).floor()
	var alpha := smoothstep(0.0, 0.8, age) * (0.9 if int(w.clock * 60.0) % 97 != 3 else 0.2)
	g.draw_actor("steve", p, p.direction_to(w.player + offset), 0.0, false, Color(0.02, 0.02, 0.03, alpha), "idle", 1.0, {"state": "idle", "time": 0.0})
	if alpha > 0.4:
		g.draw_rect(Rect2(p + Vector2(-3, -20), Vector2(2, 1)), Color(1, 1, 1, alpha))
		g.draw_rect(Rect2(p + Vector2(1, -20), Vector2(2, 1)), Color(1, 1, 1, alpha))

## Low red-black fog, moving with the world but slower than the ground.
static func fog(g, offset: Vector2):
	var clock: float = g.world.clock
	for j in range(9):
		var p := Vector2(fposmod(j * 173.0 + offset.x * 0.85 + clock * 4.0, 900.0) - 130.0, fposmod(j * 97.0 + offset.y * 0.85, 520.0) - 80.0)
		for k in range(3):
			g.oval(p, Vector2(150, 34) * (1.0 - k * 0.25) * (0.8 + (j % 3) * 0.2), Color(0.09, 0.0, 0.02, 0.045))

static func grain_texture() -> ImageTexture:
	if grain == null:
		var img := Image.create(128, 72, false, Image.FORMAT_RGBA8)
		for y in range(72):
			for x in range(128):
				var v := hash01(x, y, 91)
				img.set_pixel(x, y, Color(1, 1, 1, 0.0) if v < 0.82 else Color(1, 0.9, 0.9, (v - 0.82) * 1.6) if v > 0.97 else Color(0, 0, 0, (v - 0.82) * 2.4))
		grain = ImageTexture.create_from_image(img)
	return grain

## Grain and vignette over the whole world layer, under the HUD.
static func grade(g):
	if not g.settings.get("lighting", true):
		return
	var frame := int(g.world.clock * 12.0)
	var shift := Vector2(hash01(frame, 1, 93) * 128.0, hash01(frame, 2, 94) * 72.0).floor()
	g.draw_texture_rect(grain_texture(), Rect2(-shift, Vector2(768, 432)), true, Color(1, 1, 1, 0.16))
	Atmosphere.draw_edges(g, Color(0, 0, 0, 0.58))
