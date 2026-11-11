extends Node
## The two 3D fights of chapter V, built in code inside a SubViewport and
## drawn onto the 2D canvas. Reads the fighter / quake state only.
const PX := 1.0 / 16.0
var viewport: SubViewport
var scene: Node3D
var mode := ""
var cache: Dictionary = {}
var rigs: Dictionary = {}
var nodes: Dictionary = {}
var pool: Dictionary = {}

func tex(name: String) -> Texture2D:
	if not cache.has(name):cache[name] = load("res://assets/sprites/%s.png" % name)
	return cache[name]

func material(name: String, triplanar := false, emission := 0.0, alpha := false) -> StandardMaterial3D:
	var key: String = "%s|%s|%s|%s" % [name, triplanar, emission, alpha]
	if cache.has(key):return cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if triplanar:
		m.uv1_triplanar = true;m.uv1_world_triplanar = true;m.uv1_scale = Vector3.ONE
	if emission > 0:
		m.emission_enabled = true;m.emission_texture = tex(name);m.emission_energy_multiplier = emission
	if alpha:m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;m.alpha_scissor_threshold = .5
	cache[key] = m
	return m

func flat(color: Color, emission := 0.0, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emission > 0:m.emission_enabled = true;m.emission = color;m.emission_energy_multiplier = emission
	if transparent:m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func ensure(g, which: String, size: Vector2i):
	if viewport == null or not is_instance_valid(viewport):
		viewport = SubViewport.new()
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		add_child(viewport)
	if viewport.size != size:viewport.size = size
	if mode == which:return
	mode = which
	if scene != null:scene.queue_free()
	rigs.clear();nodes.clear();pool.clear()
	scene = Node3D.new();viewport.add_child(scene)
	match which:
		"fighter", "fists":build_fighter()
		"erase":build_erase()
		"chair":build_chair()
		"flight":build_flight()
		_:build_quake()

func release():
	if viewport != null and is_instance_valid(viewport):viewport.queue_free()
	viewport = null;scene = null;mode = "";rigs.clear();nodes.clear();pool.clear()

# ------------------------------------------------------------------ the player model

## One Minecraft box with the vanilla UV unwrap of a 64×64 skin.
func skin_box(size_px: Vector3, uv: Vector2, inflate: float = 0.0) -> ArrayMesh:
	var w: float = size_px.x;var h: float = size_px.y;var d: float = size_px.z
	var e: Vector3 = (size_px * .5 + Vector3.ONE * inflate) * PX
	var u: float = uv.x;var v: float = uv.y
	var faces := [
		[[Vector3(-e.x, e.y, e.z), Vector3(e.x, e.y, e.z), Vector3(e.x, -e.y, e.z), Vector3(-e.x, -e.y, e.z)], Rect2(u + d, v + d, w, h), Vector3.BACK],
		[[Vector3(e.x, e.y, -e.z), Vector3(-e.x, e.y, -e.z), Vector3(-e.x, -e.y, -e.z), Vector3(e.x, -e.y, -e.z)], Rect2(u + 2 * d + w, v + d, w, h), Vector3.FORWARD],
		[[Vector3(-e.x, e.y, -e.z), Vector3(-e.x, e.y, e.z), Vector3(-e.x, -e.y, e.z), Vector3(-e.x, -e.y, -e.z)], Rect2(u, v + d, d, h), Vector3.LEFT],
		[[Vector3(e.x, e.y, e.z), Vector3(e.x, e.y, -e.z), Vector3(e.x, -e.y, -e.z), Vector3(e.x, -e.y, e.z)], Rect2(u + d + w, v + d, d, h), Vector3.RIGHT],
		[[Vector3(-e.x, e.y, -e.z), Vector3(e.x, e.y, -e.z), Vector3(e.x, e.y, e.z), Vector3(-e.x, e.y, e.z)], Rect2(u + d, v, w, d), Vector3.UP],
		[[Vector3(-e.x, -e.y, e.z), Vector3(e.x, -e.y, e.z), Vector3(e.x, -e.y, -e.z), Vector3(-e.x, -e.y, -e.z)], Rect2(u + d + w, v, w, d), Vector3.DOWN]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var c: Array = f[0];var r: Rect2 = f[1]
		var uvs := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(f[2]);st.set_uv(uvs[i] / 64.0);st.add_vertex(c[i])
	return st.commit()

func part(parent: Node3D, skin: String, size_px: Vector3, uv: Vector2, overlay: Vector2, offset: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = skin_box(size_px, uv);mesh.material_override = material(skin)
	mesh.position = offset
	parent.add_child(mesh)
	var outer := MeshInstance3D.new()
	outer.mesh = skin_box(size_px, overlay, .5 if size_px.x == 8 and size_px.y == 8 else .25)
	outer.material_override = material(skin, false, 0.0, true)
	mesh.add_child(outer)
	return mesh

func pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new();n.position = at;parent.add_child(n);return n

## Feet at the root origin, facing +Z.
func make_rig(skin: String) -> Dictionary:
	var root := Node3D.new();scene.add_child(root)
	var hips := pivot(root, Vector3(0, 12 * PX, 0))
	var torso := pivot(hips, Vector3.ZERO)
	part(torso, skin, Vector3(8, 12, 4), Vector2(16, 16), Vector2(16, 32), Vector3(0, 6 * PX, 0))
	var head := pivot(torso, Vector3(0, 12 * PX, 0))
	part(head, skin, Vector3(8, 8, 8), Vector2(0, 0), Vector2(32, 0), Vector3(0, 4 * PX, 0))
	var ra := pivot(torso, Vector3(-5 * PX, 10 * PX, 0))
	part(ra, skin, Vector3(4, 12, 4), Vector2(40, 16), Vector2(40, 32), Vector3(-1 * PX, -4 * PX, 0))
	var la := pivot(torso, Vector3(5 * PX, 10 * PX, 0))
	part(la, skin, Vector3(4, 12, 4), Vector2(32, 48), Vector2(48, 48), Vector3(1 * PX, -4 * PX, 0))
	var rl := pivot(hips, Vector3(-1.9 * PX, 0, 0))
	part(rl, skin, Vector3(4, 12, 4), Vector2(0, 16), Vector2(0, 32), Vector3(0, -6 * PX, 0))
	var ll := pivot(hips, Vector3(1.9 * PX, 0, 0))
	part(ll, skin, Vector3(4, 12, 4), Vector2(16, 48), Vector2(0, 48), Vector3(0, -6 * PX, 0))
	return {"root":root, "hips":hips, "torso":torso, "head":head, "ra":ra, "la":la, "rl":rl, "ll":ll}

func pose(r: Dictionary, p: Dictionary):
	for k in ["torso", "head", "ra", "la", "rl", "ll"]:r[k].rotation = p.get(k, Vector3.ZERO)
	r.hips.position = Vector3(0, 12 * PX + p.get("drop", 0.0), 0)

# ------------------------------------------------------------------ fighter

func build_fighter():
	var env := WorldEnvironment.new();env.environment = Environment.new();var e: Environment = env.environment
	e.background_mode = Environment.BG_COLOR;e.background_color = Color(.015, .02, .04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color = Color(.45, .5, .65);e.ambient_light_energy = .7
	e.fog_enabled = true;e.fog_light_color = Color(.03, .08, .1);e.fog_density = .02
	scene.add_child(env);nodes.env = e
	var sun := DirectionalLight3D.new();sun.rotation = Vector3(-.75, .45, 0);sun.light_energy = 1.0;sun.shadow_enabled = true;scene.add_child(sun)
	var rim := OmniLight3D.new();rim.position = Vector3(0, 3.5, -2.5);rim.omni_range = 16;rim.light_color = Color(.3, 1, .85);rim.light_energy = 1.6;scene.add_child(rim);nodes.rim = rim
	var floor := MeshInstance3D.new();var fb := BoxMesh.new();fb.size = Vector3(30, 1, 9);floor.mesh = fb;floor.position = Vector3(0, -.5, 0)
	floor.material_override = material("ch5q_polished_deepslate", true);scene.add_child(floor)
	var trim := MeshInstance3D.new();var tb := BoxMesh.new();tb.size = Vector3(30, .3, .6);trim.mesh = tb;trim.position = Vector3(0, .05, 2.2);trim.material_override = material("ch5q_gilded_blackstone", true);scene.add_child(trim)
	for i in range(14):
		var line := MeshInstance3D.new();var lb := BoxMesh.new();lb.size = Vector3(.04, .02, 4);line.mesh = lb
		line.position = Vector3(-6.5 + i, .01, 0);line.material_override = flat(Color(.3, 1, .9), 1.5);scene.add_child(line)
	for k in [-1, 1]:
		for j in range(3):
			var pillar := MeshInstance3D.new();var pb := BoxMesh.new();pb.size = Vector3(1, 6, 1);pillar.mesh = pb
			pillar.position = Vector3(k * (8.5 + j * 3.5), 3, -2 - j * 1.6);pillar.material_override = material("ch5q_polished_blackstone_bricks", true);scene.add_child(pillar)
			var rune := MeshInstance3D.new();var rb := BoxMesh.new();rb.size = Vector3(1.02, .2, 1.02);rune.mesh = rb;rune.position = pillar.position + Vector3(0, 1.6, 0)
			rune.material_override = flat(Color(.3, 1, .8), 3.0);scene.add_child(rune)
	var wall := MeshInstance3D.new();var wb := BoxMesh.new();wb.size = Vector3(26, 9, .5);wall.mesh = wb;wall.position = Vector3(0, 4.5, -7);wall.material_override = material("ch5q_deepslate_tiles", true);scene.add_child(wall)
	for k in range(5):
		var screen := MeshInstance3D.new();var sb := BoxMesh.new();sb.size = Vector3(3.2, 1.9, .1);screen.mesh = sb
		screen.position = Vector3(-8 + k * 4, 4.6 + (k % 2) * .6, -6.7);screen.material_override = flat(Color(.02, .22, .1), 1.4);scene.add_child(screen)
	var code: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_code.json")).lines
	for i in range(16):
		var l := Label3D.new();l.text = code[(i * 5) % code.size()];l.font_size = 40;l.pixel_size = .009;l.outline_size = 0
		l.modulate = Color(.3, 1, .6, .16 + (i % 3) * .06);l.position = Vector3(-9 + (i % 2) * 3.5, 1.2 + (i % 8) * .42, -6.3);l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST;scene.add_child(l);nodes["code%d" % i] = l
	var cam := Camera3D.new();cam.fov = 40;scene.add_child(cam);nodes.cam = cam
	rigs.steve = make_rig("ch5_skin_steve");rigs.notch = make_rig("ch5_skin_notch")
	nodes.super_sword = sword_in(rigs.steve.ra, .03)

func fighter_pose(f: Dictionary, fi) -> Dictionary:
	var p: Dictionary = {}
	var swing: float = sin(f.walk * 3.2)
	if absf(f.vx) > .3 and f.y <= 0 and f.move.is_empty():
		p = {"rl":Vector3(swing * .8, 0, 0), "ll":Vector3(-swing * .8, 0, 0), "ra":Vector3(-.8 - swing * .3, 0, -.25), "la":Vector3(-.8 + swing * .3, 0, .25), "torso":Vector3(.12, 0, 0)}
	else:
		var breathe: float = sin(fi.age * 3.0 + (0.0 if f.who == "steve" else 1.5)) * .04
		p = {"ra":Vector3(-1.1, .2, -.35), "la":Vector3(-.8, -.2, .3), "torso":Vector3(.12 + breathe, .25, 0), "head":Vector3(-.05, -.2, 0), "rl":Vector3(-.25, 0, .05), "ll":Vector3(.2, 0, -.05), "drop":-.04 + breathe * .5}
	if f.y > 0 and f.move.is_empty():p.rl = Vector3(-1.0, 0, 0);p.ll = Vector3(-.5, 0, 0);p.ra = Vector3(-2.2, 0, -.3);p.la = Vector3(-.6, 0, .3)
	if f.get("crouch", false):p.drop = -.35;p.rl = Vector3(-1.2, 0, 0);p.ll = Vector3(-1.2, 0, 0);p.torso = Vector3(.4, 0, 0)
	var ph: String = fi.phase_of(f)
	var k: float = 1.0 if ph == "active" else (.45 if ph == "start" else .25)
	match f.move:
		"jab":p.ra = Vector3(-1.57 * k - .2, 0, 0);p.torso = Vector3(.1, -.3 * k, 0)
		"jab2":p.la = Vector3(-1.57 * k - .2, 0, 0);p.torso = Vector3(.1, .3 * k, 0)
		"hook":p.ra = Vector3(-1.3, .9 * k, -.9 * k);p.torso = Vector3(.15, -.7 * k, 0)
		"kick":p.rl = Vector3(-1.65 * k, 0, 0);p.torso = Vector3(.35 * k, 0, 0);p.ra = Vector3(.4, 0, -.7);p.la = Vector3(.4, 0, .7)
		"sweep":p.drop = -.5;p.rl = Vector3(-1.5, 0, -.3 * k);p.ll = Vector3(-1.6, 0, 0);p.torso = Vector3(.5, -.8 * k, 0)
		"launcher", "uppercut":p.ra = Vector3(-3.0 * k, 0, -.2);p.torso = Vector3(-.35 * k, 0, 0);p.rl = Vector3(-.4, 0, 0)
		"air":p.rl = Vector3(-1.3, 0, 0);p.ll = Vector3(.3, 0, 0);p.torso = Vector3(.45, 0, 0)
		"spin":p.rl = Vector3(-1.6, 0, 0);p.torso = Vector3(.2, f.t * 20.0, 0)
		"tnt", "code":p.ra = Vector3(-2.6 + 1.8 * k, 0, -.2);p.torso = Vector3(.2 * k, -.3, 0)
		"wall":p.ra = Vector3(-1.4, 0, -.3);p.la = Vector3(-1.4, 0, .3);p.drop = -.15
		"pearl":p.ra = Vector3(-2.4, 0, 0)
		"beam":p.ra = Vector3(-1.0, 0, -.2);p.la = Vector3(-1.0, 0, .2);p.torso = Vector3(.6 * k, 0, 0)
		"throw":p.ra = Vector3(-1.5, 0, -.1);p.la = Vector3(-1.5, 0, .1);p.torso = Vector3(-.3 * k, PI * .5 * k, 0)
		"swing":p.ra = Vector3(-2.6 + 2.0 * k, 0, -.4);p.torso = Vector3(.3 * k, -.4, 0)
		"super":
			if f.who == "steve":p.ra = Vector3(-1.57 + sin(f.t * 30.0) * 1.2, 0, -.3);p.torso = Vector3(.25, sin(f.t * 30.0) * .4, 0)
			else:p.ra = Vector3(-3.0, 0, -.4);p.la = Vector3(-3.0, 0, .4);p.head = Vector3(-.5, 0, 0)
	if f.block:p.ra = Vector3(-1.9, 0, .55);p.la = Vector3(-1.9, 0, -.55);p.drop = -.1;p.head = Vector3(.3, 0, 0)
	if f.stun > 0 and f.move.is_empty():p.torso = Vector3(-.5, 0, .1);p.head = Vector3(-.5, 0, 0);p.ra = Vector3(.3, 0, -.9);p.la = Vector3(.3, 0, .9)
	return p

func sync_fighter(fi):
	for f in fi.fighters:
		var r: Dictionary = rigs[f.who]
		r.root.position = Vector3(f.x, f.y, 0)
		r.root.rotation = Vector3(0, PI / 2 * f.face, 0)
		if f.ko or f.down > 0:
			r.root.rotation.x = -1.45 * (minf(1.0, fi.age * 3.0) if f.ko else 1.0);r.root.position.y = f.y + .15
		elif f.stun > 0 and f.y > .3:r.root.rotation.x = -.6
		else:r.root.rotation.x = 0.0
		var fp: Dictionary = fighter_pose(f, fi)
		if fi.mode == "fists" and f.who == "notch" and fi.state in ["finisher", "wire", "done"]:
			fp = {"rl":Vector3(-1.5, 0, 0), "ll":Vector3(0, 0, 0), "drop":-.45, "torso":Vector3(.35, 0, 0), "head":Vector3(.4, 0, 0), "ra":Vector3(.2, 0, -.2), "la":Vector3(.2, 0, .2)}
			if fi.state != "finisher":fp.torso = Vector3(-.2, 0, 0);fp.head = Vector3(-.5, 0, 0);fp.ra = Vector3(-.4, 0, -.6);fp.la = Vector3(-.4, 0, .6)
		if fi.mode == "fists" and f.who == "steve" and fi.state in ["wire", "done"]:fp.ra = Vector3(-1.57, 0, 0);fp.torso = Vector3(0, -.4, 0)
		if fi.held(fi.fighters.find(f)) != null and f.move.is_empty():fp.ra = Vector3(-.4, 0, -.2)
		pose(r, fp)
		r.root.visible = f.glitch <= 0 or int(fi.age * 30) % 2 == 0
		var flash: bool = f.flash > 0
		for part in ["torso", "head", "ra", "la", "rl", "ll"]:
			for c in r[part].get_children():
				if c is MeshInstance3D:c.transparency = 0.0
		r.root.scale = Vector3.ONE * (1.0 if f.who == "steve" else 1.08) * (1.06 if flash else 1.0)
	(nodes.super_sword as Node3D).visible = fi.steve().move == "super"
	var mid: float = (fi.fighters[0].x + fi.fighters[1].x) / 2.0
	var spread: float = absf(fi.fighters[0].x - fi.fighters[1].x)
	var cam: Camera3D = nodes.cam
	var z: float = 7.6 + spread * .35 - fi.zoom * 2.2
	var top: float = maxf(fi.fighters[0].y, fi.fighters[1].y)
	cam.position = Vector3(mid, 1.9 + top * .4 - fi.zoom * .3, z)
	if fi.hitstop > 0:cam.position += Vector3(sin(fi.age * 90) * .06, cos(fi.age * 77) * .05, 0)
	cam.look_at(Vector3(mid, 1.1 + top * .35, 0))
	cam.fov = 40 - fi.zoom * 6
	var shown: Array = []
	for bo in fi.bolts:
		var n: Node3D = take("bolt", bo.kind)
		n.position = Vector3(bo.x, bo.y, 0);n.rotation = Vector3(fi.age * 8, fi.age * 5, 0) if bo.kind != "beam" else Vector3.ZERO;shown.append(n)
	for wl in fi.walls:
		var n: Node3D = take("cobble", "");n.position = Vector3(wl.x, .75, 0);n.scale = Vector3(1, minf(1.0, (3.0 - wl.life) * 6.0 + .05), 1);shown.append(n)
	for fl in fi.falls:
		var n: Node3D = take("cobble", "");n.position = Vector3(fl.x, fl.y + .5, 0);n.scale = Vector3(.7, .7, .7);shown.append(n)
	for sp in fi.sparks:
		var big: bool = sp.get("boom", false)
		var n: Node3D = take("blast" if big else "spark", "")
		n.position = Vector3(sp.x, sp.y, .3)
		n.scale = Vector3.ONE * ((.6 + sp.age * 5.0) if big else ((.6 + sp.age * (3.5 if sp.get("heavy", false) else 2.5)) * (1.0 - sp.age / .45)))
		if big:((n as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = .7 * (1 - sp.age / .45)
		shown.append(n)
		if sp.get("heavy", false):
			for j in range(6):
				var px: Node3D = take("pixel", str(j % 2));var ang: float = j * 1.05 + sp.x
				px.position = Vector3(sp.x + cos(ang) * sp.age * 3.0, sp.y + sin(ang) * sp.age * 3.0 - sp.age * sp.age * 4.0, .35);px.scale = Vector3.ONE * 1.4;shown.append(px)
	for i in range(fi.items.size()):
		var it: Dictionary = fi.items[i]
		var key: String = "item%d" % i
		if not nodes.has(key):
			var l := Label3D.new();l.text = it.text;l.font_size = 36;l.pixel_size = .008;l.modulate = Color(1, .85, .35)
			l.outline_size = 8;l.outline_modulate = Color(.2, .05, 0);scene.add_child(l);nodes[key] = l
		var label: Label3D = nodes[key]
		label.visible = true
		if it.holder >= 0:
			var hand: Node3D = rigs[fi.fighters[it.holder].who].ra
			label.global_position = hand.global_position + hand.global_transform.basis * Vector3(0, -.75, .35)
			label.rotation = Vector3(0, 0, PI / 2 * fi.fighters[it.holder].face)
		else:
			label.position = Vector3(it.x, .12 + sin(fi.age * 2 + i) * .05, .6);label.rotation = Vector3(-PI / 2.4, 0, 0)
	if fi.mode == "fists" and fi.state in ["wire", "done"]:
		var w: Node3D = take("wire", "")
		var s: Dictionary = fi.steve();var n: Dictionary = fi.notch()
		var k: float = clampf(fi.age / .25, 0, 1)
		var from := Vector3(s.x + s.face * .4, 1.1, 0);var to := Vector3(n.x + s.face * 1.2 * k, 1.05, 0)
		w.position = (from + to) / 2.0;w.scale = Vector3(maxf(.01, from.distance_to(to)), 1, 1);shown.append(w)
		for j in range(3):
			var sp: Node3D = take("spark", "");sp.position = Vector3(n.x, 1.05 + sin(fi.age * 30 + j) * .2, .2);sp.scale = Vector3.ONE * (.6 + fmod(fi.age * 7 + j, 1.0));shown.append(sp)
	hide_rest(shown)
	nodes.rim.light_energy = 1.6 + fi.zoom * 2.0
	for i in range(16):
		var l: Label3D = nodes["code%d" % i]
		l.position.x = fmod(-9 + (i % 2) * 3.5 + fi.age * (.2 + i % 4 * .1), 22.0) - 4

func take(kind: String, variant: String) -> Node3D:
	var key: String = kind + variant
	if not pool.has(key):pool[key] = []
	for n in pool[key]:
		if not n.get_meta("used", false):n.set_meta("used", true);n.visible = true;return n
	var n := MeshInstance3D.new()
	match kind:
		"bolt":
			var b := BoxMesh.new()
			match variant:
				"tnt":b.size = Vector3(.45, .45, .45);n.material_override = material("ch5q_tnt", true)
				"beam":b.size = Vector3(1.4, .12, .5);n.material_override = flat(Color(.97, 0, .86), 4.0)
				_:b.size = Vector3(.4, .4, .4);n.material_override = flat(Color(.3, 1, .9), 3.0)
			n.mesh = b
		"cobble":
			var b := BoxMesh.new();b.size = Vector3(.8, 1.5, .8);n.mesh = b;n.material_override = material("ch5q_cobblestone", true)
		"spark":
			var s := SphereMesh.new();s.radius = .12;s.height = .24;n.mesh = s;n.material_override = flat(Color(1, .85, .3, .9), 6.0, true)
		"rocket":
			var b := BoxMesh.new();b.size = Vector3(.16, .16, .5);n.mesh = b;n.material_override = flat(Color(.85, .3, .1), 2.0)
		"trail":
			var b := BoxMesh.new();b.size = Vector3(.12, .12, .12);n.mesh = b;n.material_override = flat(Color(.6, .6, .6, .5), 0.0, true)
		"blast":
			var s := SphereMesh.new();s.radius = 1.0;s.height = 2.0;n.mesh = s;n.material_override = flat(Color(1, .55, .15, .6), 5.0, true)
		"pixel":
			var b := BoxMesh.new();b.size = Vector3(.07, .07, .07);n.mesh = b;n.material_override = flat(Color(.97, 0, .86) if variant == "0" else Color(.2, 1, 1), 3.0)
		"wire":
			var b := BoxMesh.new();b.size = Vector3(1, .05, .05);n.mesh = b;n.material_override = flat(Color(.15, .15, .17))
		"star":
			var b := BoxMesh.new();b.size = Vector3(.06, .06, .6);n.mesh = b;n.material_override = flat(Color(.9, .95, 1), 3.0)
		"glyph":
			var l := Label3D.new();l.text = "01";l.font_size = 32;l.pixel_size = .01;l.modulate = Color(.3, 1, .7)
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED;l.set_meta("used", true);scene.add_child(l);pool[key].append(l);return l
	n.set_meta("used", true);scene.add_child(n);pool[key].append(n)
	return n

func hide_rest(_shown: Array):
	for key in pool:
		for n in pool[key]:
			if not n.get_meta("used", false):n.visible = false
			n.set_meta("used", false)

# ------------------------------------------------------------------ quake

func build_quake():
	var env := WorldEnvironment.new();var e := Environment.new();env.environment = e
	e.background_mode = Environment.BG_COLOR;e.background_color = Color(.05, .03, .02)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color = Color(.55, .42, .3);e.ambient_light_energy = .55
	e.fog_enabled = true;e.fog_light_color = Color(.22, .12, .06);e.fog_density = .035
	scene.add_child(env)
	var q = load("res://scripts/chapter_five_quake.gd").new();q.reset()
	for b in q.boxes:
		var m := MeshInstance3D.new();var bm := BoxMesh.new();bm.size = b[1] - b[0];m.mesh = bm
		m.position = (b[0] + b[1]) / 2.0;m.material_override = material("ch5q_" + b[2], true);scene.add_child(m)
	for lv in q.lava:
		var m := MeshInstance3D.new();var bm := BoxMesh.new();bm.size = Vector3(lv[1].x - lv[0].x, .1, lv[1].z - lv[0].z);m.mesh = bm
		m.position = Vector3((lv[0].x + lv[1].x) / 2, .02, (lv[0].z + lv[1].z) / 2);m.material_override = material("ch5q_lava_still", true, 2.5);scene.add_child(m)
		var l := OmniLight3D.new();l.position = m.position + Vector3(0, 1, 0);l.light_color = Color(1, .45, .1);l.omni_range = 7;l.light_energy = 2.0;scene.add_child(l)
	for pad in q.pads:
		var m := MeshInstance3D.new();var bm := BoxMesh.new();bm.size = Vector3(1.6, .12, 1.6);m.mesh = bm
		m.position = pad.p + Vector3(0, .06, 0);m.material_override = material("ch5q_redstone_block", true, 2.0);scene.add_child(m)
	for c in [Vector3(-9, 4.2, -7.7), Vector3(9, 4.2, -7.7), Vector3(-9, 4.2, 10.3), Vector3(9, 4.2, 10.3), Vector3(0, 4.5, 0)]:
		var l := OmniLight3D.new();l.position = c;l.light_color = Color(1, .7, .4);l.omni_range = 11;l.light_energy = 1.6;scene.add_child(l)
		var lamp := MeshInstance3D.new();var lb := BoxMesh.new();lb.size = Vector3(.5, .5, .5);lamp.mesh = lb;lamp.position = c + Vector3(0, .6, 0)
		lamp.material_override = material("ch5q_glowstone", true, 3.0);scene.add_child(lamp);nodes["lamp%d" % nodes.size()] = l
	var cam := Camera3D.new();cam.fov = 88;cam.near = .05;scene.add_child(cam);nodes.cam = cam
	var gun := Node3D.new();cam.add_child(gun);gun.position = Vector3(.32, -.3, -.55);nodes.gun = gun
	var body := MeshInstance3D.new();var gb := BoxMesh.new();gb.size = Vector3(.16, .16, .7);body.mesh = gb;body.material_override = material("ch5q_iron_block", true);gun.add_child(body)
	var barrel := MeshInstance3D.new();var bb := BoxMesh.new();bb.size = Vector3(.1, .1, .3);barrel.mesh = bb;barrel.position = Vector3(0, .04, -.45);barrel.material_override = material("ch5q_polished_blackstone_bricks", true);gun.add_child(barrel)
	var flash := OmniLight3D.new();flash.position = Vector3(0, 0, -.8);flash.light_color = Color(1, .7, .3);flash.omni_range = 5;flash.light_energy = 0;gun.add_child(flash);nodes.flash = flash
	rigs.notch = make_rig("ch5_skin_notch")
	var launcher := MeshInstance3D.new();var lm := BoxMesh.new();lm.size = Vector3(.14, .14, .6);launcher.mesh = lm;launcher.material_override = material("ch5q_iron_block", true)
	launcher.position = Vector3(-1 * PX, -10 * PX, .2);rigs.notch.ra.add_child(launcher)
	for i in range(q.items.size()):
		var s := Sprite3D.new();s.pixel_size = .05;s.billboard = BaseMaterial3D.BILLBOARD_ENABLED;s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.texture = tex({"health":"ch5q_item_golden_apple", "armor":"ch5q_item_iron_chestplate", "ammo":"ch5q_item_firework_rocket", "quad":"icon_command_block"}[q.items[i].kind])
		scene.add_child(s);nodes["item%d" % i] = s

func sync_quake(qk):
	var s: Dictionary = qk.steve();var n: Dictionary = qk.notch()
	var cam: Camera3D = nodes.cam
	cam.position = qk.eye(s) + Vector3(0, sin(s.walk * 2.2) * .04 if s.grounded else 0.0, 0)
	cam.rotation = Vector3(s.pitch, s.yaw, 0)
	if s.dead > 0:cam.position.y = s.p.y + .3;cam.rotation.z = .4
	var gun: Node3D = nodes.gun
	gun.position = Vector3(.32 + sin(s.walk * 1.1) * .015, -.3 - s.fired * .6 + absf(cos(s.walk * 1.1)) * .01, -.55 + s.fired * .8)
	gun.visible = s.dead <= 0
	nodes.flash.light_energy = 4.0 if s.fired > .06 else 0.0
	var r: Dictionary = rigs.notch
	r.root.visible = n.dead <= 0 or n.dead > 1.4
	r.root.position = n.p
	r.root.rotation = Vector3(0, n.yaw + PI, 0)
	var swing: float = sin(n.walk * 2.5)
	pose(r, {"rl":Vector3(swing * .7, 0, 0), "ll":Vector3(-swing * .7, 0, 0), "ra":Vector3(-1.4 - n.pitch, 0, 0), "la":Vector3(-1.2 - n.pitch, 0, .5), "head":Vector3(-n.pitch * .5, 0, 0)})
	if n.dead > 0:r.root.rotation.x = -1.4
	var shown: Array = []
	for rk in qk.rockets:
		var m: Node3D = take("rocket", "")
		m.position = rk.p;m.look_at(rk.p + rk.v, Vector3.UP);shown.append(m)
		for k in range(4):
			var t: Node3D = take("trail", "");t.position = rk.p - rk.v.normalized() * (k + 1) * .35;t.scale = Vector3.ONE * (1 + k * .4);shown.append(t)
	for b in qk.blasts:
		var m: Node3D = take("blast", "");m.position = b.p;m.scale = Vector3.ONE * (.4 + b.age * 5.0)
		(m.material_override as StandardMaterial3D).albedo_color.a = .7 * (1 - b.age / .5);shown.append(m)
	hide_rest(shown)
	for i in range(qk.items.size()):
		var it: Dictionary = qk.items[i];var sp: Sprite3D = nodes["item%d" % i]
		sp.visible = it.left <= 0
		sp.position = it.p + Vector3(0, .5 + sin(qk.age * 2.5 + i) * .12, 0)
	for k in nodes:
		if String(k).begins_with("lamp"):nodes[k].light_energy = 1.4 + sin(qk.age * 9.0 + k.length()) * .15 + (0.6 if int(qk.age * 13 + k.length()) % 17 == 0 else 0.0)

# ------------------------------------------------------------------ cinematic helpers

func room(bg: Color, ambient: Color, energy := .7) -> Environment:
	var env := WorldEnvironment.new();var e := Environment.new();env.environment = e
	e.background_mode = Environment.BG_COLOR;e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color = ambient;e.ambient_light_energy = energy
	scene.add_child(env);nodes.env = e
	return e

func block(at: Vector3, size: Vector3, tex_name: String, emission := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new();var b := BoxMesh.new();b.size = size;m.mesh = b;m.position = at
	m.material_override = material(tex_name, true, emission);scene.add_child(m);return m

func glow_box(at: Vector3, size: Vector3, color: Color, energy: float) -> MeshInstance3D:
	var m := MeshInstance3D.new();var b := BoxMesh.new();b.size = size;m.mesh = b;m.position = at
	m.material_override = flat(color, energy);scene.add_child(m);return m

func label(text: String, at: Vector3, size: int, color: Color, px := .006) -> Label3D:
	var l := Label3D.new();l.text = text;l.position = at;l.font_size = size;l.pixel_size = px;l.modulate = color
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT;l.outline_size = 0;scene.add_child(l);return l

func omni(at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new();l.position = at;l.light_color = color;l.light_energy = energy;l.omni_range = reach;scene.add_child(l);return l

## A held sword: blade along the arm, in the arm's swing plane.
func sword_in(hand: Node3D, px := .03) -> Node3D:
	var holder := Node3D.new();holder.position = Vector3(-1 * PX, -10 * PX, 0);holder.rotation = Vector3(0, PI / 2, 0);hand.add_child(holder)
	var s := Sprite3D.new();s.texture = tex("ch5q_item_iron_sword");s.pixel_size = px;s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.double_sided = true;s.shaded = true;s.rotation = Vector3(0, 0, deg_to_rad(-135));s.position = Vector3(0, -8.5 * px, 0);holder.add_child(s)
	return holder

func shot(cam: Camera3D, from: Vector3, to: Vector3, fov: float, shake := 0.0, clock := 0.0):
	cam.fov = fov
	cam.position = from + Vector3(sin(clock * 13.0), cos(clock * 11.0), 0) * shake
	cam.look_at(to)

func burst(at: Vector3, count: int, clock: float, spread: float, rise: float, life: float, glyphs := true) -> Array:
	var out: Array = []
	for k in range(count):
		var t: float = fmod(clock * .7 + k * .137, life) / life
		var d := Vector3(sin(k * 2.39996), 0, cos(k * 2.39996)) * spread * t
		var n: Node3D = take("glyph" if glyphs else "pixel", str(k % 2))
		n.position = at + d + Vector3(0, rise * t, 0)
		if not glyphs:n.scale = Vector3.ONE * (1.0 - t * .6);n.rotation = Vector3(t * 4.0, k, t * 3.0)
		if glyphs:(n as Label3D).text = ["0", "1", "{", "}", ";", "()", "//"][k % 7];(n as Label3D).modulate.a = 1.0 - t
		out.append(n)
	return out

# ------------------------------------------------------------------ the erasure

func build_erase():
	room(Color(.01, .012, .02), Color(.3, .4, .5), .5)
	block(Vector3(0, -.5, 0), Vector3(20, 1, 14), "ch5q_polished_deepslate")
	block(Vector3(0, 2.2, -3.2), Vector3(5.2, 3.2, .4), "ch5q_polished_blackstone_bricks")
	var screen := glow_box(Vector3(0, 2.3, -2.98), Vector3(4.4, 2.4, .05), Color(.02, .2, .08), 1.0);nodes.screen = screen
	for k in [-1, 1]:
		block(Vector3(k * 4.2, 1.6, -2.6), Vector3(2.2, 1.6, .3), "ch5q_polished_blackstone_bricks").rotation.y = -k * .35
		var side := glow_box(Vector3(k * 4.15, 1.6, -2.42), Vector3(1.9, 1.3, .04), Color(.02, .2, .08), 1.0);side.rotation.y = -k * .35;nodes["side%d" % k] = side
	for k in range(9):
		var l := label("", Vector3(-2.05, 3.35 - k * .25, -2.94), 30, Color(.35, 1, .5));nodes["line%d" % k] = l
	for k in range(6):glow_box(Vector3(-3 + k * 1.2, .02, -1.5 + k * .3), Vector3(.06, .04, 3.0), Color(.05, .05, .06), 0.0)
	nodes.light = omni(Vector3(0, 2.4, -1.6), Color(.3, 1, .6), 2.5, 9.0)
	nodes.key = omni(Vector3(-3, 3.5, 3), Color(.7, .75, 1.0), 1.4, 12.0)
	rigs.notch = make_rig("ch5_skin_notch");rigs.steve = make_rig("ch5_skin_steve")
	nodes.sword = sword_in(rigs.steve.ra)
	var flying := Sprite3D.new();flying.texture = tex("ch5q_item_iron_sword");flying.pixel_size = .04;flying.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST;flying.double_sided = true
	scene.add_child(flying);nodes.flying = flying
	var cam := Camera3D.new();scene.add_child(cam);nodes.cam = cam

const ERASE_CODE := ["delete(steve);", "for (Pixel p : steve.pixels())", "    p.remove();", "steve.memory.clear();", "// he was never here", "gc.collect(steve);", "> deleting… %d%%", "", "> _"]

func sync_erase(f, clock: float):
	var a: float = f.age;var cam: Camera3D = nodes.cam
	var n: Dictionary = rigs.notch;var s: Dictionary = rigs.steve
	var broken: bool = f.thrown >= .6
	n.root.position = Vector3(1.3, 0, -1.4);n.root.rotation = Vector3(0, -.6, 0)
	var typing: float = sin(clock * 18) * .15
	if not broken:pose(n, {"ra":Vector3(-1.2 + typing, 0, -.2), "la":Vector3(-1.2 - typing, 0, .2), "head":Vector3(.2, .3, 0)})
	else:
		var k: float = clampf((f.thrown - .6) / .5, 0, 1)
		n.root.position += Vector3(.9, 0, .4) * k;n.root.rotation.x = -k * 1.3
		pose(n, {"ra":Vector3(-.3, 0, -1.0), "la":Vector3(-.3, 0, 1.0), "head":Vector3(-.4, 0, 0)})
	s.root.position = Vector3(-1.6, 0, 1.2);s.root.rotation = Vector3(0, PI * .75, 0)
	var resist: float = clampf(f.presses / 14.0, 0, 1)
	var sp := {"rl":Vector3(-.2, 0, 0), "ll":Vector3(.2, 0, 0), "torso":Vector3(.35 * (1 - resist), 0, 0), "head":Vector3(.3, 0, 0), "ra":Vector3(-.4, 0, 0), "la":Vector3(-.2, 0, 0), "drop":-.15 * (1 - resist)}
	if f.thrown >= 0 and f.thrown < .6:sp.ra = Vector3(-3.0 + f.thrown * 5.0, 0, 0);sp.torso = Vector3(-.2, .5, 0)
	pose(s, sp)
	var order := ["ll", "rl", "la", "ra", "torso", "head"]
	for i in range(order.size()):
		var gone: bool = f.erase * 6.4 > i + 1
		var flick: bool = f.erase * 6.4 > i + .6 and not gone and int(clock * 24) % 2 == 0
		for c in s[order[i]].get_children():
			if c is MeshInstance3D:
				c.visible = not gone and not flick
	(nodes.sword as Node3D).visible = f.thrown < 0
	var fl: Sprite3D = nodes.flying
	fl.visible = f.thrown >= 0 and f.thrown < .6
	if fl.visible:
		var t: float = f.thrown / .6
		fl.position = Vector3(-1.4, 1.5, 1.0).lerp(Vector3(0, 2.4, -2.9), t) + Vector3(0, sin(t * PI) * .5, 0)
		fl.rotation = Vector3(0, 0, -t * 18.0)
	for k in range(9):
		var l: Label3D = nodes["line%d" % k]
		var txt: String = ERASE_CODE[k] % int(f.erase * 100) if "%d" in ERASE_CODE[k] else ERASE_CODE[k]
		if broken:txt = ["FATAL ERROR", "", "  0x0000DEAD", "", "  terminal.exe", "  has stopped", "", "", ""][k] if f.thrown < 1.6 else ""
		l.text = txt.substr(0, mini(txt.length(), int(a * 30) - k * 6)) if not broken else txt
		l.modulate = Color(1, .25, .2) if broken else Color(.35, 1, .5)
	var scr: StandardMaterial3D = (nodes.screen as MeshInstance3D).material_override
	if broken:
		var dead: float = clampf((f.thrown - 1.2) / .8, 0, 1)
		scr.emission = Color(1, .1, .05).lerp(Color(0, 0, 0), dead) if int(clock * 20) % 3 != 0 or dead > .9 else Color(1, 1, 1)
		nodes.light.light_color = Color(1, .2, .1);nodes.light.light_energy = (3.0 + sin(clock * 40) * 2.0) * (1 - dead) + .2
		for k in [-1, 1]:((nodes["side%d" % k] as MeshInstance3D).material_override as StandardMaterial3D).emission = Color(.6, 0, 0) * (1 - dead)
	else:
		scr.emission = Color(.02, .25, .1);nodes.light.light_energy = 2.2 + sin(clock * 3) * .2
	var shown: Array = []
	if f.erase > .02:shown += burst(s.root.position + Vector3(0, .6, 0), int(6 + f.erase * 14), clock, .8, 2.2, 1.4, false)
	if broken and f.thrown < 2.4:shown += burst(Vector3(0, 2.3, -2.7), 24, clock * 2.0, 3.0, 1.0, .9, true)
	hide_rest(shown)
	if f.thrown < 0:
		if a < 3.2:shot(cam, Vector3(-2.6, 1.9, 3.6), Vector3(.6, 1.6, -1.6), 46, 0.0, clock)
		else:
			var push: float = clampf((a - 3.2) / 8.0, 0, 1)
			shot(cam, Vector3(-.4 - push * .3, 1.4, 2.6 - push * .8), Vector3(-1.6, 1.0, 1.2), 50 - push * 10, .01 * f.erase, clock)
	elif f.thrown < .6:shot(cam, Vector3(1.8, 1.8, 2.4), fl.position, 55, 0.0, clock)
	elif f.thrown < 1.4:shot(cam, Vector3(.6, 2.2, -.4), Vector3(0, 2.3, -3.0), 60, .06 * (1.4 - f.thrown), clock)
	else:shot(cam, Vector3(-2.2, 1.6, 3.2), Vector3(1.6, .8, -1.0), 48, 0.0, clock)

# ------------------------------------------------------------------ the chair

func build_chair():
	room(Color(.01, .01, .015), Color(.25, .28, .35), .45)
	var lamp := SpotLight3D.new();lamp.position = Vector3(0, 3.6, .2);lamp.rotation = Vector3(-PI / 2, 0, 0);lamp.spot_range = 6;lamp.spot_angle = 30
	lamp.light_energy = 4.0;lamp.light_color = Color(1, .92, .8);lamp.shadow_enabled = true;scene.add_child(lamp);nodes.lamp = lamp
	var bulb := glow_box(Vector3(0, 3.55, .2), Vector3(.18, .18, .18), Color(1, .9, .7), 6.0);nodes.bulb = bulb
	var wire := glow_box(Vector3(0, 4.2, .2), Vector3(.02, 1.2, .02), Color(.05, .05, .05), 0.0);nodes.wire = wire
	nodes.glow = omni(Vector3(2.2, 1.6, -1.0), Color(.3, 1, .7), 1.2, 5.0)
	block(Vector3(0, -.5, 0), Vector3(16, 1, 12), "ch5q_polished_deepslate")
	block(Vector3(0, 3, -4), Vector3(16, 7, .5), "ch5q_deepslate_tiles")
	for x in [-.35, .35]:
		for z in [-.35, .35]:block(Vector3(x, .25, z), Vector3(.12, .5, .12), "ch5q_dark_oak_planks")
	block(Vector3(0, .55, 0), Vector3(.9, .1, .9), "ch5q_dark_oak_planks")
	block(Vector3(0, 1.15, -.42), Vector3(.9, 1.1, .1), "ch5q_dark_oak_planks")
	block(Vector3(2.3, .9, -1.2), Vector3(1.4, 1.1, .3), "ch5q_polished_blackstone_bricks")
	nodes.screen = label("scan: 0%", Vector3(1.7, 1.25, -1.03), 28, Color(.3, 1, .6))
	rigs.notch = make_rig("ch5_skin_notch");rigs.steve = make_rig("ch5_skin_steve")
	nodes.sword = sword_in(rigs.steve.ra, .032)
	var cable := MeshInstance3D.new();var cb := BoxMesh.new();cb.size = Vector3(1, .03, .03);cable.mesh = cb;cable.material_override = flat(Color(.08, .08, .1));scene.add_child(cable);nodes.cable = cable
	for k in range(3):
		var chain := MeshInstance3D.new();var ch := BoxMesh.new();ch.size = Vector3(.6, .07, .36);chain.mesh = ch;chain.material_override = material("ch5q_iron_block", true)
		scene.add_child(chain);nodes["chain%d" % k] = chain
	var cam := Camera3D.new();scene.add_child(cam);nodes.cam = cam

func sync_chair(f, clock: float):
	var a: float = f.age
	var n: Dictionary = rigs.notch;var s: Dictionary = rigs.steve;var cam: Camera3D = nodes.cam
	var swing: float = sin(clock * .9) * .12
	nodes.lamp.rotation = Vector3(-PI / 2 + swing, 0, swing * .5);nodes.bulb.position = Vector3(sin(swing) * .8, 3.55, .2);nodes.wire.position = Vector3(sin(swing) * .4, 4.2, .2)
	nodes.lamp.light_energy = 5.5 - (2.0 if int(clock * 17) % 23 == 0 else 0.0)
	var stab: float = f.CHAIR_STAB
	n.root.position = Vector3(0, .6 - 12 * PX + .02, .05);n.root.rotation = Vector3.ZERO
	var struggle: float = sin(clock * 9) * .09 if a > 20.8 and a < 30 else 0.0
	var np := {"rl":Vector3(-1.57, 0, .05), "ll":Vector3(-1.57, 0, -.05), "ra":Vector3(.55, 0, -.2), "la":Vector3(.55, 0, .2), "head":Vector3(-.05 + struggle, struggle * 2, 0), "torso":Vector3(struggle * .5, 0, 0)}
	if a < 1.4:np.head = Vector3(.6 - a * .45, 0, 0)
	if a > 12.6 and a < 21.0:np.head = Vector3(.1, -.25, 0)
	var fade: float = clampf((a - (stab + 3.0)) / 5.0, 0, 1)
	if a > stab:
		var k: float = clampf((a - stab) / .5, 0, 1)
		np.torso = Vector3(-.25 * k + .5 * fade, 0, 0);np.head = Vector3(-.5 * k + .9 * fade, 0, .15 * fade)
	pose(n, np)
	for part in ["ll", "rl", "la", "ra", "torso", "head"]:
		var gone: bool = fade > [.15, .25, .4, .5, .75, .95][["ll", "rl", "la", "ra", "torso", "head"].find(part)]
		for c in n[part].get_children():
			if c is MeshInstance3D:c.visible = not gone and not (fade > .05 and int(clock * 30 + part.length()) % 7 == 0)
	for k in range(3):
		var c: MeshInstance3D = nodes["chain%d" % k]
		var drop: float = clampf((fade - .6) / .4, 0, 1)
		c.position = Vector3(0, .82 + k * .22 - drop * (.75 + k * .2), .05);c.rotation = Vector3(drop * .3 * (k - 1), 0, drop * .2)
	# Steve: waits by the console, then the sword and the walk.
	var walk: float = clampf((a - (f.CHAIR_SWORD + .8)) / 1.6, 0, 1)
	var from := Vector3(-1.6, 0, .4);var to := Vector3(0, 0, 1.05)
	s.root.position = from.lerp(to, walk)
	s.root.rotation = Vector3(0, lerpf(PI / 2, PI, walk), 0)
	var gait: float = sin(a * 7) * .6 if walk > 0 and walk < 1 else 0.0
	var sp := {"ra":Vector3(-.5, 0, -.1), "la":Vector3(.05, 0, .1), "rl":Vector3(gait, 0, 0), "ll":Vector3(-gait, 0, 0)}
	if a > f.CHAIR_SWORD:sp.ra = Vector3(-.3, 0, -.15)
	if a > stab - .45:
		var k: float = clampf((a - (stab - .45)) / .45, 0, 1)
		sp.ra = Vector3(-.3 - 1.25 * k, 0, 0);sp.torso = Vector3(.15 * k, 0, 0);sp.rl = Vector3(-.4 * k, 0, 0);sp.ll = Vector3(.3 * k, 0, 0)
		s.root.position = to + Vector3(0, 0, -.22 * k)
	if a > stab + 2.6:sp.head = Vector3(.35, 0, 0)
	if a > stab + 6.5:sp.ra = Vector3(-.2, 0, -.1);s.root.position = to + Vector3(0, 0, .2)
	pose(s, sp)
	(nodes.sword as Node3D).visible = a > f.CHAIR_SWORD
	var scanning: bool = a > f.CHAIR_SCAN[0] and a < f.CHAIR_SWORD
	var cable: MeshInstance3D = nodes.cable
	cable.visible = scanning
	if scanning:
		var c_from: Vector3 = Vector3(2.0, 1.0, -1.0);var c_to: Vector3 = n.head.global_position + Vector3(0, .3, 0)
		cable.position = (c_from + c_to) / 2.0;cable.scale = Vector3(c_from.distance_to(c_to), 1, 1);cable.look_at(c_to, Vector3.UP);cable.rotate_object_local(Vector3.UP, PI / 2)
	(nodes.screen as Label3D).text = "scan: %d%%\n%s" % [int(f.scan() * 100), "exit() found" if f.scan() >= 1.0 else "reading…"]
	nodes.glow.light_energy = (1.0 + sin(clock * 12) * .4) if scanning else (.25 if a < f.CHAIR_SCAN[0] else 0.0)
	var shown: Array = []
	if scanning:
		for k in range(10):
			var g: Node3D = take("glyph", "");var t: float = fmod(clock * .6 + k * .1, 1.0)
			g.position = (n.head.global_position + Vector3(0, .4, 0)).lerp(Vector3(2.3, 1.3, -1.0), t) + Vector3(0, sin(t * PI) * .5, 0)
			(g as Label3D).text = ["0", "1", "{", "}", ";", "()"][k % 6];(g as Label3D).modulate.a = 1.0;shown.append(g)
	if fade > 0 and fade < 1:shown += burst(Vector3(0, 1.0, .1), 26, clock, 1.2, 2.4, 1.6, true)
	hide_rest(shown)
	var h: float = clock
	if a < 4.0:shot(cam, Vector3(3.4 - a * .25, 2.6, 4.4 - a * .3), Vector3(0, 1.0, 0), 40, 0.0, h)
	elif a < 12.6:shot(cam, Vector3(-2.2, 1.65, 1.6), Vector3(0, 1.25, 0), 36, .005, h)
	elif a < 21.4:shot(cam, Vector3(.35, 1.45, 1.35), Vector3(0, 1.32, 0), 34, .008, h)
	elif a < f.CHAIR_SWORD:shot(cam, Vector3(.6, .55, 1.7), Vector3(0, 1.3, 0), 44, .012, h)
	elif a < stab - .5:shot(cam, Vector3(-3.8, 1.7, 3.2), Vector3(-.5, 1.0, .5), 40, 0.0, h)
	elif a < stab + 1.6:shot(cam, Vector3(4.2, 1.35, .7), Vector3(0, 1.05, .45), 30 - clampf(a - stab, 0, 1) * 5, .03 * clampf(1.0 - absf(a - stab) * 2, 0, 1), h)
	elif a < stab + 7.5:shot(cam, Vector3(.25, 1.35, 1.0), Vector3(0, 1.2, .05), 36, 0.0, h)
	else:shot(cam, Vector3(2.8, 2.4, 4.0), Vector3(0, .9, 0), 44, 0.0, h)

# ------------------------------------------------------------------ the door, the flight, the other world

func pixel_world() -> ImageTexture:
	var im := Image.create(64, 36, false, Image.FORMAT_RGBA8)
	for y in range(36):
		for x in range(64):
			var hill: float = 22 + sin(x * .21) * 4 + sin(x * .07 + 1.3) * 3
			var c := Color(.35, .6, 1.0).lerp(Color(.7, .85, 1.0), y / 36.0)
			if y > hill:c = Color(.45, .3, .15) if y > hill + 2 else Color(.25, .75, .2)
			if (x * 7 + y * 3) % 97 == 0 and y < 14:c = Color(1, 1, 1)
			if x % 16 == 5 and y > hill - 6 and y <= hill:c = Color(.15, .5, .15) if y < hill - 2 else Color(.4, .25, .1)
			if x >= 30 and x <= 33 and y >= int(hill) - 4 and y < int(hill):c = Color(.9, .2, .2) if y < int(hill) - 2 else Color(.2, .3, .9)
			im.set_pixel(x, y, c)
	return ImageTexture.create_from_image(im)

func neon_grid() -> ImageTexture:
	var im := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):im.set_pixel(x, y, Color(1, .2, .8) if x % 8 == 0 or y % 8 == 0 else Color(.08, 0, .12))
	return ImageTexture.create_from_image(im)

func diorama(kind: int, at: Vector3, scale: float) -> Node3D:
	var root := Node3D.new();root.position = at;root.scale = Vector3.ONE * scale;scene.add_child(root)
	match kind:
		0:
			var q := MeshInstance3D.new();var qm := QuadMesh.new();qm.size = Vector2(16, 9);q.mesh = qm
			var m := StandardMaterial3D.new();m.albedo_texture = pixel_world();m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST;m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;m.cull_mode = BaseMaterial3D.CULL_DISABLED
			q.material_override = m;root.add_child(q)
			var frame := MeshInstance3D.new();var fm := BoxMesh.new();fm.size = Vector3(16.6, 9.6, .2);frame.mesh = fm;frame.position.z = -.15;frame.material_override = flat(Color(.1, .1, .12));root.add_child(frame)
		1:
			var track := MeshInstance3D.new();var tm := TorusMesh.new();tm.inner_radius = 6;tm.outer_radius = 8;track.mesh = tm;track.scale = Vector3(1, .15, 1)
			track.material_override = flat(Color(.25, .25, .28));root.add_child(track)
			for k in range(4):
				var car := MeshInstance3D.new();var cm := BoxMesh.new();cm.size = Vector3(1.0, .5, 1.8);car.mesh = cm
				car.material_override = flat([Color(1, .2, .2), Color(.2, .5, 1), Color(1, .85, .2), Color(.2, .9, .4)][k], .8)
				car.position = Vector3(sin(k * 1.57) * 7, .4, cos(k * 1.57) * 7);car.rotation.y = k * 1.57;root.add_child(car);car.name = "car%d" % k
		2:
			var island := MeshInstance3D.new();var cm := CylinderMesh.new();cm.top_radius = 5;cm.bottom_radius = .5;cm.height = 5;island.mesh = cm
			island.material_override = material("ch5q_dark_oak_planks", true);root.add_child(island)
			var grass := MeshInstance3D.new();var gm := CylinderMesh.new();gm.top_radius = 5.1;gm.bottom_radius = 5.1;gm.height = .4;grass.mesh = gm;grass.position.y = 2.6
			grass.material_override = flat(Color(.3, .7, .3));root.add_child(grass)
			for k in range(3):
				var tower := MeshInstance3D.new();var tw := CylinderMesh.new();tw.top_radius = .7;tw.bottom_radius = .8;tw.height = 3 + k;tower.mesh = tw
				tower.position = Vector3(-1.8 + k * 1.8, 4.3 + k * .5, 0);tower.material_override = flat(Color(.85, .82, .75));root.add_child(tower)
				var roof := MeshInstance3D.new();var rf := CylinderMesh.new();rf.top_radius = 0;rf.bottom_radius = 1.0;rf.height = 1.6;roof.mesh = rf
				roof.position = tower.position + Vector3(0, (3 + k) / 2.0 + .8, 0);roof.material_override = flat(Color(.6, .15, .2));root.add_child(roof)
		3:
			var ship := MeshInstance3D.new();var pm := PrismMesh.new();pm.size = Vector3(6, 2, 10);ship.mesh = pm;ship.rotation = Vector3(-PI / 2, 0, 0)
			ship.material_override = material("ch5q_iron_block", true);root.add_child(ship)
			for k in [-1, 1]:
				var eng := MeshInstance3D.new();var em := SphereMesh.new();em.radius = .8;em.height = 1.6;eng.mesh = em;eng.position = Vector3(k * 1.6, 0, 5.2)
				eng.material_override = flat(Color(.3, .8, 1), 6.0);root.add_child(eng)
		4:
			var floor := MeshInstance3D.new();var fm := PlaneMesh.new();fm.size = Vector2(18, 18);floor.mesh = fm
			var m := StandardMaterial3D.new();m.albedo_texture = neon_grid();m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST;m.emission_enabled = true;m.emission_texture = m.albedo_texture;m.emission_energy_multiplier = 2.0
			m.uv1_scale = Vector3(4, 4, 4);floor.material_override = m;root.add_child(floor)
			var sun := MeshInstance3D.new();var sm := SphereMesh.new();sm.radius = 4;sm.height = 8;sun.mesh = sm;sun.position = Vector3(0, 3, -8);sun.material_override = flat(Color(1, .5, .2), 3.0);root.add_child(sun)
		5:
			var planet := MeshInstance3D.new();var sm := SphereMesh.new();sm.radius = 6;sm.height = 12;planet.mesh = sm
			planet.material_override = material(["ch5q_cut_copper", "ch5q_crying_obsidian", "ch5q_magma"][int(at.z) % 3], true, 1.0);root.add_child(planet)
			var ring := MeshInstance3D.new();var rm := TorusMesh.new();rm.inner_radius = 8;rm.outer_radius = 9.5;ring.mesh = rm;ring.scale = Vector3(1, .05, 1);ring.rotation.z = .4
			ring.material_override = flat(Color(.9, .8, .6), 1.0);root.add_child(ring)
	return root

## Logos of other games, if the player put them in assets/logos/.
func logos() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://assets/logos")
	if dir == null:return out
	for f in dir.get_files():
		if f.ends_with(".png"):out.append(load("res://assets/logos/" + f))
	return out

func build_flight():
	var e := room(Color(0, 0, 0), Color(.6, .6, .7), .7)
	e.glow_enabled = true;e.glow_intensity = .6;e.glow_bloom = 0.0;e.glow_hdr_threshold = 1.2
	var sun := DirectionalLight3D.new();sun.rotation = Vector3(-.5, .4, 0);sun.light_energy = 1.0;scene.add_child(sun);nodes.sun = sun
	rigs.steve = make_rig("ch5_skin_steve")
	var door := Node3D.new();door.position = Vector3(1.0, 0, -6);scene.add_child(door);nodes.door = door
	var leaf := MeshInstance3D.new();var lb := BoxMesh.new();lb.size = Vector3(1.0, 2.0, .12);leaf.mesh = lb;leaf.position = Vector3(-.5, 1.0, 0)
	leaf.material_override = material("ch5q_iron_block", true);door.add_child(leaf)
	var opening := glow_box(door.position + Vector3(-.5, 1.0, -.12), Vector3(1.0, 2.0, .05), Color(1, 1, 1), 8.0);nodes.opening = opening
	var frame := block(door.position + Vector3(-.5, 1.05, -.05), Vector3(1.3, 2.25, .1), "ch5q_polished_blackstone_bricks");nodes.frame = frame
	for k in range(5):
		var beam := MeshInstance3D.new();var bm := BoxMesh.new();bm.size = Vector3(.9 - k * .1, .02, 7);beam.mesh = bm
		beam.material_override = flat(Color(1, 1, 1, .06), 1.0, true);beam.position = door.position + Vector3(-.5, .3 + k * .4, 3.4);scene.add_child(beam);nodes["beam%d" % k] = beam
	nodes.door_light = omni(door.position + Vector3(-.5, 1.0, .6), Color(1, 1, 1), 0.0, 9.0)
	for k in range(40):
		var g := label(["0", "1", "{", "}"][k % 4], Vector3(sin(k * 2.4) * 6, fmod(k * .7, 5.0), -3 - fmod(k * 1.3, 10.0)), 40, Color(.3, 1, .6, .4), .01)
		g.billboard = BaseMaterial3D.BILLBOARD_ENABLED;nodes["void%d" % k] = g
	var rings: Array = []
	for k in range(14):
		var r := MeshInstance3D.new();var tm := TorusMesh.new();tm.inner_radius = 6.5;tm.outer_radius = 7;r.mesh = tm;r.rotation.x = PI / 2
		r.material_override = flat(Color(.3, 1, .7), 3.0);r.position = Vector3(0, 2, -20 - k * 22);scene.add_child(r);rings.append(r)
	nodes.rings = rings
	var worlds: Array = []
	var marks: Array = logos()
	for i in range(12):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(side * (16 + (i % 3) * 7), (i % 3 - 1) * 7.0 + 2, -70 - i * 42)
		var d := diorama(i % 6, at, 1.0 + (i % 2) * .4)
		d.rotation.y = -side * .6;worlds.append(d)
		if not marks.is_empty():
			var logo := Sprite3D.new();logo.texture = marks[i % marks.size()];logo.pixel_size = 9.0 / maxf(1, logo.texture.get_width());logo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			logo.position = at + Vector3(0, 9, 0);scene.add_child(logo);worlds.append(logo)
	nodes.worlds = worlds
	var portal := MeshInstance3D.new();var pm := SphereMesh.new();pm.radius = 6;pm.height = 12;portal.mesh = pm;portal.material_override = flat(Color(1, .95, .85), 8.0)
	portal.position = Vector3(0, 2, -620);scene.add_child(portal);nodes.portal = portal
	build_other()
	var cam := Camera3D.new();cam.far = 900;scene.add_child(cam);nodes.cam = cam

## The world Steve lands in: warm light, a dusty canyon, wooden buildings,
## no blocks anywhere.
func build_other():
	var other := Node3D.new();other.position = Vector3(0, 0, -1500);scene.add_child(other);nodes.other = other;other.visible = false
	var ground := MeshInstance3D.new();var gm := PlaneMesh.new();gm.size = Vector2(120, 120);gm.subdivide_width = 24;gm.subdivide_depth = 24;ground.mesh = gm
	var gmat := StandardMaterial3D.new();gmat.albedo_color = Color(.55, .38, .22);gmat.roughness = 1.0;ground.material_override = gmat;other.add_child(ground)
	for k in range(9):
		var cliff := MeshInstance3D.new();var cm := BoxMesh.new();cm.size = Vector3(12 + k % 3 * 6, 14 + k % 4 * 5, 10);cliff.mesh = cm
		var mat := StandardMaterial3D.new();mat.albedo_color = Color(.62, .38, .22).lerp(Color(.8, .55, .35), (k % 3) / 3.0);mat.roughness = 1.0;cliff.material_override = mat
		var side: float = -1.0 if k % 2 == 0 else 1.0
		cliff.position = Vector3(side * (20 + k * 2), cm.size.y / 2 - 2, -10 - k * 9);cliff.rotation.y = k * .3;other.add_child(cliff)
	for k in range(2):
		var base := MeshInstance3D.new();var bm := BoxMesh.new();bm.size = Vector3(10, 7, 8);base.mesh = bm;base.position = Vector3(-7 + k * 18, 3.5, -22 - k * 6)
		var mat := StandardMaterial3D.new();mat.albedo_color = Color(.65, .18, .14) if k == 0 else Color(.2, .3, .6);mat.roughness = .9;base.material_override = mat;other.add_child(base)
		var roof := MeshInstance3D.new();var rm := PrismMesh.new();rm.size = Vector3(11, 3, 8.4);roof.mesh = rm;roof.position = base.position + Vector3(0, 5, 0)
		var rmat := StandardMaterial3D.new();rmat.albedo_color = Color(.35, .25, .18);roof.material_override = rmat;other.add_child(roof)
	var bridge := MeshInstance3D.new();var brm := BoxMesh.new();brm.size = Vector3(3, .3, 16);bridge.mesh = brm;bridge.position = Vector3(0, .15, -6)
	var bmat := StandardMaterial3D.new();bmat.albedo_color = Color(.5, .35, .2);bridge.material_override = bmat;other.add_child(bridge)

func sync_flight(f, clock: float):
	var a: float = f.age
	var s: Dictionary = rigs.steve;var cam: Camera3D = nodes.cam;var env: Environment = nodes.env
	var shown: Array = []
	var other: bool = a >= f.FLIGHT_OTHER
	nodes.other.visible = other
	for w in nodes.worlds:w.visible = not other
	for r in nodes.rings:r.visible = not other and a >= 5.0
	nodes.portal.visible = not other and a >= 5.0
	for k in range(40):nodes["void%d" % k].visible = a < 5.0
	if a < 5.0:
		var walk: float = clampf(a / 3.2, 0, 1)
		s.root.position = Vector3(.5, 0, -.8 - walk * 4.4);s.root.rotation = Vector3(0, PI, 0)
		var sw: float = sin(a * 7) * .7 if walk < 1 else 0.0
		pose(s, {"rl":Vector3(sw, 0, 0), "ll":Vector3(-sw, 0, 0), "ra":Vector3(-sw * .6 - (1.3 if a > 3.2 else 0.0), 0, 0), "la":Vector3(sw * .6, 0, 0)})
		var open: float = clampf((a - 3.3) / .9, 0, 1)
		nodes.door.rotation = Vector3(0, -open * 1.7, 0);nodes.door.visible = true;nodes.frame.visible = true
		nodes.opening.visible = open > 0;nodes.door_light.light_energy = open * 6.0
		for k in range(5):nodes["beam%d" % k].visible = open > 0
		env.background_color = Color(0, 0, 0)
		for k in range(40):
			var g: Label3D = nodes["void%d" % k];g.position.y = fmod(k * .7 + clock * .3, 5.0)
		if a < 3.0:shot(cam, Vector3(1.8, .35, 1.6), Vector3(.3, 1.4, -5.5), 52, 0.0, clock)
		else:shot(cam, Vector3(-.6, 1.2, -1.6), Vector3(.5, 1.0, -6), 50, 0.0, clock)
	elif not other:
		nodes.door.visible = false;nodes.frame.visible = false;nodes.opening.visible = false;nodes.door_light.light_energy = 0
		for k in range(5):nodes["beam%d" % k].visible = false
		var t: float = a - 5.0
		var z: float = -t * 26.0 - pow(maxf(0, t - 17.0), 2) * 6.0
		var bob: float = sin(clock * 1.7) * .3
		s.root.position = Vector3(0, 2.0 + bob, z);s.root.rotation = Vector3(-1.3, PI, sin(clock * .8) * .1)
		pose(s, {"ra":Vector3(.25, 0, -.2), "la":Vector3(.25, 0, .2), "rl":Vector3(.15 + sin(clock * 2) * .1, 0, 0), "ll":Vector3(-.1, 0, 0), "head":Vector3(-1.1, sin(clock * .5) * .4, 0)})
		env.background_color = Color(.01, .005, .03).lerp(Color(.07, .02, .12), .5 + .5 * sin(t * .4))
		for k in range(70):
			var st: Node3D = take("star", "")
			var sx: float = fmod(k * 37.7, 44.0) - 22.0;var sy: float = fmod(k * 23.3, 28.0) - 12.0
			st.position = Vector3(sx, sy, z - fmod(k * 13.0 - t * 60.0, 140.0) - 4.0);st.scale = Vector3(1, 1, 1.0 + clampf(t - 15.0, 0, 6.0));shown.append(st)
		for w in nodes.worlds:
			if w is Sprite3D:continue
			w.rotation.y += .002
			for c in w.get_children():
				if String(c.name).begins_with("car"):
					var k: int = int(String(c.name).substr(3));var ang: float = clock * 1.2 + k * 1.57
					c.position = Vector3(sin(ang) * 7, .4, cos(ang) * 7);c.rotation.y = ang + PI / 2
		if t < 6.0:shot(cam, Vector3(1.6, 3.0, z + 6.0), Vector3(0, 2.2, z - 8), 62, 0.0, clock)
		elif t < 11.0:shot(cam, Vector3(1.1, 2.3, z - 1.2), Vector3(0, 2.4, z - .3), 40, .01, clock)
		elif t < 17.0:shot(cam, Vector3(-6.0, -1.0, z - 14.0), Vector3(0, 2.0, z), 70, 0.0, clock)
		else:shot(cam, Vector3(.8, 2.6, z + 4.0), Vector3(0, 2.0, z - 30), 58 + (t - 17.0) * 3.0, .02 * (t - 17.0) / 5.0, clock)
	else:
		var t: float = a - f.FLIGHT_OTHER
		var base: Vector3 = nodes.other.position
		var land: float = clampf(t / .8, 0, 1)
		s.root.position = base + Vector3(0, .3 + (1 - land) * 3.0, -2.0);s.root.rotation = Vector3(0, PI * .9 + clampf(t - 1.2, 0, 1.2) * .6, 0)
		pose(s, {"drop":-.12 * (1 - clampf(t - .8, 0, .4) / .4), "head":Vector3(-.1, clampf(t - 1.5, 0, 1.0) * .5, 0), "ra":Vector3(.1, 0, -.15), "la":Vector3(.1, 0, .15)})
		env.background_color = Color(.85, .5, .28).lerp(Color(.4, .55, .85), clampf(t / 3.0, 0, 1) * .5)
		env.ambient_light_color = Color(.8, .65, .55);env.ambient_light_energy = .3
		env.glow_enabled = false
		nodes.sun.light_color = Color(1, .82, .6);nodes.sun.light_energy = 1.05;nodes.sun.rotation = Vector3(-.3, -.9, 0);nodes.sun.shadow_enabled = true
		for k in range(16):
			var dust: Node3D = take("spark", "");var dt2: float = fmod(clock * .3 + k * .11, 1.0)
			dust.position = base + Vector3(-6 + fmod(k * 3.7, 12.0) + dt2 * 6, .4 + fmod(k * .9, 2.5), -4 - fmod(k * 2.3, 8.0));dust.scale = Vector3.ONE * .25;shown.append(dust)
		shot(cam, base + Vector3(3.2 - t * .2, 1.4, 3.6 - t * .3), base + Vector3(-1.0, 1.4, -8.0), 46, 0.0, clock)
	hide_rest(shown)

## Credits: a slow drift past the other worlds.
func sync_credits(f, clock: float):
	var t: float = f.age
	var s: Dictionary = rigs.steve;s.root.visible = false
	nodes.other.visible = false;nodes.door.visible = false;nodes.frame.visible = false;nodes.opening.visible = false
	for k in range(5):nodes["beam%d" % k].visible = false
	for k in range(40):nodes["void%d" % k].visible = false
	for w in nodes.worlds:w.visible = true
	for r in nodes.rings:r.visible = false
	nodes.portal.visible = false
	nodes.env.background_color = Color(.005, .003, .015);nodes.sun.light_energy = .8;nodes.sun.light_color = Color(.8, .85, 1)
	var z: float = -60.0 - t * 9.0
	var shown: Array = []
	for k in range(50):
		var st: Node3D = take("star", "")
		st.position = Vector3(fmod(k * 37.7, 60.0) - 30.0, fmod(k * 23.3, 34.0) - 14.0, z - fmod(k * 17.0 - t * 6.0, 160.0) - 10.0);st.scale = Vector3.ONE;shown.append(st)
	hide_rest(shown)
	shot(nodes.cam, Vector3(sin(t * .07) * 4.0, 3.0 + sin(t * .11) * 1.5, z), Vector3(sin(t * .05) * 10.0, 1.0, z - 60), 58, 0.0, clock)
