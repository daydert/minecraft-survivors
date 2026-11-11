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
	if which == "fighter":build_fighter()
	else:build_quake()

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
	var env := WorldEnvironment.new();env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR;env.environment.background_color = Color(.02, .025, .05)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color = Color(.5, .55, .7);env.environment.ambient_light_energy = .9
	scene.add_child(env)
	var sun := DirectionalLight3D.new();sun.rotation = Vector3(-.7, .5, 0);sun.light_energy = 1.1;scene.add_child(sun)
	var rim := OmniLight3D.new();rim.position = Vector3(0, 3, -2);rim.omni_range = 14;rim.light_color = Color(.3, 1, .9);rim.light_energy = 1.4;scene.add_child(rim)
	var floor := MeshInstance3D.new();var fb := BoxMesh.new();fb.size = Vector3(30, 1, 8);floor.mesh = fb;floor.position = Vector3(0, -.5, 0)
	floor.material_override = material("ch5q_polished_deepslate", true);scene.add_child(floor)
	for i in range(13):
		var line := MeshInstance3D.new();var lb := BoxMesh.new();lb.size = Vector3(.04, .02, 8);line.mesh = lb
		line.position = Vector3(-6 + i, .01, 0);line.material_override = flat(Color(.3, 1, .9), 1.5);scene.add_child(line)
	var code: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_code.json")).lines
	for i in range(16):
		var l := Label3D.new();l.text = code[(i * 5) % code.size()];l.font_size = 40;l.pixel_size = .009;l.outline_size = 0
		l.modulate = Color(.3, 1, .6, .35 + (i % 3) * .1);l.position = Vector3(-9 + (i % 2) * 3.5, .4 + i * .42, -4 - (i % 3));l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST;scene.add_child(l);nodes["code%d" % i] = l
	var cam := Camera3D.new();cam.fov = 40;scene.add_child(cam);nodes.cam = cam
	rigs.steve = make_rig("ch5_skin_steve");rigs.notch = make_rig("ch5_skin_notch")

func fighter_pose(f: Dictionary, fi) -> Dictionary:
	var p: Dictionary = {}
	var swing: float = sin(f.walk * 3.2)
	var guard := {"ra":Vector3(-.9, 0, -.2), "la":Vector3(-.9, 0, .2)}
	if absf(f.vx) > .3 and f.y <= 0:
		p = {"rl":Vector3(swing * .8, 0, 0), "ll":Vector3(-swing * .8, 0, 0), "ra":Vector3(-.7 - swing * .3, 0, -.2), "la":Vector3(-.7 + swing * .3, 0, .2)}
	else:
		p = guard.duplicate();p.torso = Vector3(.05, 0, 0)
		p.head = Vector3(sin(fi.age * 2.0) * .03, 0, 0)
	if f.y > 0:p.rl = Vector3(-.9, 0, 0);p.ll = Vector3(-.4, 0, 0)
	var ph: String = fi.phase_of(f)
	var k: float = 1.0 if ph == "active" else (.5 if ph == "start" else .3)
	match f.move:
		"punch":p.ra = Vector3(-1.57 * k, 0, 0);p.torso = Vector3(0, -.35 * k, 0)
		"punch3":p.la = Vector3(-1.57 * k, 0, 0);p.torso = Vector3(0, .4 * k, 0)
		"kick":p.rl = Vector3(-1.5 * k, 0, 0);p.torso = Vector3(.25 * k, 0, 0);p.ra = Vector3(.3, 0, -.6);p.la = Vector3(.3, 0, .6)
		"dive":p.rl = Vector3(-1.2, 0, 0);p.ll = Vector3(.3, 0, 0);p.torso = Vector3(.4, 0, 0)
		"uppercut":p.ra = Vector3(-2.9 * k, 0, 0);p.torso = Vector3(-.3 * k, 0, 0)
		"cast":p.ra = Vector3(-1.5, 0, -.3);p.la = Vector3(-1.5, 0, .3)
	if f.block:p.ra = Vector3(-1.9, 0, .5);p.la = Vector3(-1.9, 0, -.5);p.drop = -.08
	if f.stun > 0:p.torso = Vector3(-.4, 0, 0);p.head = Vector3(-.4, 0, 0)
	return p

func sync_fighter(fi):
	for f in fi.fighters:
		var r: Dictionary = rigs[f.who]
		r.root.position = Vector3(f.x, f.y, 0)
		r.root.rotation = Vector3(0, PI / 2 * f.face, 0)
		if f.ko:r.root.rotation.x = -minf(1.0, fi.age * 3.0) * 1.45;r.root.position.y = f.y + .15
		else:r.root.rotation.x = 0.0
		pose(r, fighter_pose(f, fi))
		r.root.visible = f.glitch <= 0 or int(fi.age * 30) % 2 == 0
		r.root.scale = Vector3.ONE * (1.0 if f.who == "steve" else 1.12)
	var mid: float = (fi.fighters[0].x + fi.fighters[1].x) / 2.0
	var spread: float = absf(fi.fighters[0].x - fi.fighters[1].x)
	var cam: Camera3D = nodes.cam
	cam.position = Vector3(mid, 1.9, 7.5 + spread * .35)
	cam.look_at(Vector3(mid, 1.1, 0))
	var shown: Array = []
	for bo in fi.bolts:
		var n: Node3D = take("bolt", bo.owner)
		n.position = Vector3(bo.x, bo.y, 0);n.rotation = Vector3(fi.age * 8, fi.age * 5, 0);shown.append(n)
	for sp in fi.sparks:
		var n: Node3D = take("spark", "")
		n.position = Vector3(sp.x, sp.y, .3);n.scale = Vector3.ONE * (1.0 + sp.age * 6);shown.append(n)
	hide_rest(shown)
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
			var b := BoxMesh.new();b.size = Vector3(.35, .35, .35);n.mesh = b
			n.material_override = flat(Color(1, .15, .1) if variant == "steve" else Color(.3, 1, .9), 3.0)
		"spark":
			var s := SphereMesh.new();s.radius = .12;s.height = .24;n.mesh = s;n.material_override = flat(Color(1, .95, .6, .8), 4.0, true)
		"rocket":
			var b := BoxMesh.new();b.size = Vector3(.16, .16, .5);n.mesh = b;n.material_override = flat(Color(.85, .3, .1), 2.0)
		"trail":
			var b := BoxMesh.new();b.size = Vector3(.12, .12, .12);n.mesh = b;n.material_override = flat(Color(.6, .6, .6, .5), 0.0, true)
		"blast":
			var s := SphereMesh.new();s.radius = 1.0;s.height = 2.0;n.mesh = s;n.material_override = flat(Color(1, .55, .15, .6), 5.0, true)
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
