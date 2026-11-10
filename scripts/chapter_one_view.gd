extends RefCounted
## Chapter I presentation: the fenced field, the party gate and its sign, the
## path, the opening walk-in, and the small Herobrine of the duel. Reads world
## state only.
const Atmosphere = preload("res://scripts/ui/atmosphere.gd")
const GATE_X := 1024.0
const FENCE_S := 2026.0
const GAP := [984.0, 1048.0]
const PATH_HALF := 18.0
const SIGN_POST := Vector2(984, 2026)

static func assets(g) -> Dictionary:
	if not g.has_meta("ch1_assets"):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_one_assets.json"))
		for name in data.sprites:
			if not g.textures.has(name):g.load_texture(name)
		g.set_meta("ch1_assets", data)
	return g.get_meta("ch1_assets")

static func unload(g):
	if not g.has_meta("ch1_assets"):return
	for name in g.get_meta("ch1_assets").sprites:g.textures.erase(name)
	g.remove_meta("ch1_assets")

static func h(i: int, salt: int) -> float:
	return Atmosphere.hash01(i, salt, 17)

static func row_of(dir: Vector2) -> int:
	return 2 if absf(dir.x) > absf(dir.y) else (1 if dir.y < 0 else 0)

## One frame of the shared player-model atlases (same rig as chapter IV).
static func figure(g, sheet: String, who: String, pose: String, t: float, p: Vector2, dir: Vector2, scale: float = 1.0, tint: Color = Color.WHITE, loop: bool = true):
	var a: Dictionary = assets(g)
	var layout: Dictionary = a[who]
	if not layout.has(pose):pose = "idle"
	var clip: Dictionary = layout[pose]
	var fps: float = 5.0 if pose in ["idle", "aura", "laugh", "shrug", "donut_hold", "lift"] else 10.0
	var index: int = int(t * fps)
	index = index % int(clip.count) if loop else mini(int(clip.count) - 1, index)
	var col: int = int(clip.start) + index
	var size = Vector2(a.frame[0], a.frame[1])
	var anchor = Vector2(a.anchor[0], a.anchor[1])
	var row = row_of(dir)
	var flip = dir.x < 0 and row == 2
	if not g.textures.has(sheet):return
	g.draw_set_transform(p.floor(), 0, Vector2(-1 if flip else 1, 1))
	g.draw_texture_rect_region(g.textures[sheet], Rect2(-anchor * scale, size * scale), Rect2(Vector2(col * size.x, row * size.y), size), tint)
	g.draw_set_transform(Vector2.ZERO)

static func gate_grow(g) -> float:
	return float(g.world.get("gate_grow")) if "gate_grow" in g.world else 1.0

# ------------------------------------------------------------------ ground

static func ground(g, offset: Vector2):
	assets(g)
	var w = g.world
	# The area beyond the south fence only shows during the walk-in.
	var edge: float = w.SIZE + offset.y
	if edge < 360 and g.textures.has("ground"):
		var top: float = maxf(edge, 0)
		g.draw_texture_rect_region(g.textures.ground, Rect2(0, top, 640, 360 - top), Rect2(-offset.x, top - edge, 640, 360 - top))
	path(g, offset)

static func path(g, offset: Vector2):
	if not g.textures.has("ch1_path"):return
	var tex: Texture2D = g.textures.ch1_path
	var y0: int = int(floorf((-offset.y - 16) / 16.0)) * 16
	for y in range(maxi(y0, 1856), mini(y0 + 400, 2320), 16):
		var fade: float = clampf((y - 1856) / 120.0, 0, 1)
		for x in range(int(GATE_X - 32), int(GATE_X + 32), 16):
			var i: int = x / 16 * 997 + y / 16
			var inner: bool = absf(x + 8 - GATE_X) < PATH_HALF
			if not inner and h(i, 1) > 0.45 * fade:continue
			if inner and h(i, 2) > 0.25 + fade:continue
			var p := Vector2(x, y) + offset
			if p.y < -16 or p.y > 360:continue
			g.draw_texture_rect(tex, Rect2(p, Vector2(16, 16)), false, Color(1, 1, 1, 0.85 if inner else 0.55))

# ------------------------------------------------------------------ fence

static func post(g, s: Vector2, height: float = 1.0):
	var tex: Texture2D = g.textures.get("ch1_fence_post")
	if tex == null:return
	var size: Vector2 = tex.get_size()
	var shown: float = size.y * height
	g.draw_texture_rect_region(tex, Rect2(s - Vector2(size.x / 2, shown - 3), Vector2(size.x, shown)), Rect2(0, 0, size.x, shown))

static func rail(g, s: Vector2, height: float = 1.0):
	var tex: Texture2D = g.textures.get("ch1_fence_rail")
	if tex == null:return
	var size: Vector2 = tex.get_size()
	var shown: float = size.y * height
	g.draw_texture_rect_region(tex, Rect2(s - Vector2(size.x / 2, shown - 3), Vector2(size.x, shown)), Rect2(0, 0, size.x, shown))

## North, west and east sides: drawn before actors; trees stand outside.
static func border(g, offset: Vector2):
	assets(g)
	var w = g.world
	var dead: bool = w.finale.active and w.finale.scorch() > .2
	for j in range(65):
		var t := 24.0 + j * 32
		for side in range(3):
			var p: Vector2 = Vector2(t, 22) if side == 0 else (Vector2(22, t) if side == 1 else Vector2(2026, t))
			var s: Vector2 = p + offset
			if not Rect2(-48, -60, 736, 480).has_point(s):continue
			var out: Vector2 = [Vector2(0, -16), Vector2(-14, 0), Vector2(14, 0)][side]
			g.sprite(("tree_dead_" if dead else "tree_") + str((j + side) % 3), s + out - Vector2(32, 58))
	for j in range(65):
		var t := 24.0 + j * 32
		for side in range(3):
			var p: Vector2 = Vector2(t, 22) if side == 0 else (Vector2(22, t) if side == 1 else Vector2(2026, t))
			var s: Vector2 = p + offset
			if not Rect2(-40, -40, 720, 440).has_point(s):continue
			if side == 0:
				if j < 64:rail(g, s + Vector2(16, 0))
				post(g, s)
			else:
				if j < 64 and g.textures.has("ch1_planks"):
					for k in [7.0, 12.0]:
						g.draw_texture_rect_region(g.textures.ch1_planks, Rect2(s + Vector2(-1, -k), Vector2(2, 32)), Rect2(4, 0, 2, 16), Color(.9, .9, .9))
				post(g, s)

## The south side with the gate, sorted with actors at its line.
static func south(g, offset: Vector2):
	assets(g)
	var grow: float = gate_grow(g)
	for j in range(65):
		var x := 24.0 + j * 32
		var s := Vector2(x, FENCE_S) + offset
		if not Rect2(-40, -40, 720, 440).has_point(s):continue
		var gate_rail: bool = x >= GAP[0] and x < GAP[1]
		if j < 64:
			if gate_rail:
				if grow > 0.01:rail(g, s + Vector2(16, 0), grow)
			else:rail(g, s + Vector2(16, 0))
		var gate_post: bool = x > GAP[0] and x < GAP[1]
		if gate_post:
			if grow > 0.01:post(g, s, grow)
		else:post(g, s, 1.0)
	# The gate posts are taller, with a crossbar the sign used to hang from.
	for x in GAP:
		var s := Vector2(x, FENCE_S) + offset
		if not Rect2(-60, -80, 760, 520).has_point(s):continue
		if g.textures.has("ch1_planks"):
			g.draw_texture_rect_region(g.textures.ch1_planks, Rect2(s + Vector2(-3, -27), Vector2(6, 27)), Rect2(5, 0, 6, 16))
			g.draw_rect(Rect2(s + Vector2(-3, -27), Vector2(6, 27)), Color(.2, .13, .07, .5), false, 1)
	var a := Vector2(GAP[0], FENCE_S) + offset;var b := Vector2(GAP[1], FENCE_S) + offset
	if g.textures.has("ch1_planks") and Rect2(-80, -80, 800, 520).has_point(a):
		g.draw_texture_rect_region(g.textures.ch1_planks, Rect2(a + Vector2(-4, -30), Vector2(b.x - a.x + 8, 4)), Rect2(0, 6, 16, 4))
		g.draw_rect(Rect2(a + Vector2(-4, -30), Vector2(b.x - a.x + 8, 4)), Color(.2, .13, .07, .6), false, 1)
	party_sign(g, offset)
	# Forest outside the fence, parted by the path.
	var dead: bool = g.world.finale.active and g.world.finale.scorch() > .2
	for i in range(140):
		var x: float = 16 + (i % 35) * 58.0 + h(i, 3) * 26
		var y: float = 2058 + floorf(i / 35.0) * 54 + h(i, 4) * 18
		if absf(x - GATE_X) < 54:continue
		var s := Vector2(x, y) + offset
		if not Rect2(-70, -80, 780, 520).has_point(s):continue
		g.oval(s, Vector2(18, 5), Color(0.08, 0.16, 0.12, 0.3))
		g.sprite(("tree_dead_" if dead else "tree_") + str(i % 3), s - Vector2(32, 67), Vector2(64, 72))
	if gate_grow(g) < 1.0:grow_dust(g, offset)

static func grow_dust(g, offset: Vector2):
	var grow: float = gate_grow(g)
	if grow <= 0.0:return
	var k: float = sin(grow * PI)
	for i in range(26):
		var x: float = GAP[0] + 4 + h(i, 5) * (GAP[1] - GAP[0] - 8)
		var t: float = fposmod(h(i, 6) + grow * 2.0, 1.0)
		var p := Vector2(x, FENCE_S - t * 14) + offset
		g.draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(.42, .3, .18, k * (1 - t)))
		if i % 3 == 0:g.draw_rect(Rect2((p + Vector2(1, -4)).floor(), Vector2(1, 1)), Color(.35, .6, .25, k * (1 - t)))

## The party sign, hanging off one chain from the crossbar: the other gave way.
static func party_sign(g, offset: Vector2):
	if not g.textures.has("ch1_sign"):return
	var anchor := Vector2(GAP[0] + 9, FENCE_S - 28) + offset
	if not Rect2(-80, -80, 800, 520).has_point(anchor):return
	var swing: float = sin(g.world.clock * 1.3) * 0.05
	var angle: float = 0.42 + swing
	var tex: Texture2D = g.textures.ch1_sign
	var size: Vector2 = tex.get_size() * 2.0
	for k in range(4):
		g.draw_rect(Rect2((anchor + Vector2(0, k * 2)).floor(), Vector2(1, 1)), Color(.25, .25, .27))
	var hinge := anchor + Vector2(0, 8)
	g.draw_set_transform(hinge, angle, Vector2.ONE)
	g.draw_texture_rect(tex, Rect2(Vector2(-2, 0), size), false)
	var label := "Вечеринка"
	var width: float = g.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	# The word is squeezed to the board, never past its edges.
	var fit: float = minf(1.0, (size.x - 6) / width)
	g.draw_set_transform(hinge + Vector2(-2 + (size.x - width * fit) / 2, size.y / 2 + 3).rotated(angle), angle, Vector2(fit, fit))
	g.draw_string(g.font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.18, .11, .05))
	g.draw_set_transform(Vector2.ZERO)
	# The broken chain dangles from the other corner of the crossbar.
	var loose := anchor + Vector2(size.x - 4, 0)
	for k in range(3):
		g.draw_rect(Rect2((loose + Vector2(sin(g.world.clock * 1.7 + k) * 0.6, k * 2)).floor(), Vector2(1, 1)), Color(.25, .25, .27))

# ------------------------------------------------------------------ opening overlay

static func intro_overlay(g):
	var w = g.world
	var a: float = w.intro_age
	var bars: float = 22.0 * (1 - smoothstep(w.INTRO_LENGTH - 1.2, w.INTRO_LENGTH, a))
	g.draw_rect(Rect2(0, 0, 640, bars), Color.BLACK);g.draw_rect(Rect2(0, 360 - bars, 640, bars), Color.BLACK)
	if a < 1.4:g.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 1 - smoothstep(0, 1.4, a)))
	if a > 0.8 and a < 3.6:
		var k: float = smoothstep(0.8, 1.6, a) * (1 - smoothstep(2.9, 3.6, a))
		g.centered("Глава I · До рассвета", 60, 16, Color(1, 1, 1, k), true)
	if a > 3.9 and a < 5.7:sign_closeup(g, smoothstep(3.9, 4.3, a) * (1 - smoothstep(5.3, 5.7, a)))
	if a > 1.5 and a < w.INTRO_LENGTH - 1.0:
		g.text_at("Пробел — пропустить", Vector2(522, 350), 8, Color(1, 1, 1, .35))

## What Steve reads: the sign, close, on its one chain.
static func sign_closeup(g, k: float):
	if k <= 0 or not g.textures.has("ch1_sign"):return
	var tex: Texture2D = g.textures.ch1_sign
	var size: Vector2 = tex.get_size() * 6
	var hinge := Vector2(320 - size.x / 2 + 12, 52)
	var angle: float = 0.2 + sin(g.world.clock * 1.3) * 0.03
	g.draw_rect(Rect2(hinge + Vector2(-2, -40), Vector2(4, 40)), Color(.22, .22, .24, k))
	for i in range(5):g.draw_rect(Rect2(hinge + Vector2(-3, -38 + i * 8), Vector2(6, 5)), Color(.3, .3, .33, k), false, 1)
	g.draw_set_transform(hinge, angle, Vector2.ONE)
	g.draw_texture_rect(tex, Rect2(Vector2(-12, 0), size), false, Color(1, 1, 1, k))
	var label := "Вечеринка"
	var font_size := 16
	while font_size > 8 and g.bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x - 24:font_size -= 8
	var width: float = g.bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	g.draw_string(g.bold, Vector2(-12 + (size.x - width) / 2, size.y / 2 + font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(.2, .12, .05, k))
	g.draw_set_transform(Vector2.ZERO)
	var loose := Vector2(320 + size.x / 2 - 4, 52)
	for i in range(3):g.draw_rect(Rect2(loose + Vector2(-3, -38 + i * 8), Vector2(6, 5)), Color(.3, .3, .33, k), false, 1)
