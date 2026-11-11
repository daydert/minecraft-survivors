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
	var grip := Node3D.new();grip.position = Vector3(-1 * PX, -10 * PX, 0);rigs.steve.ra.add_child(grip)
	nodes.super_sword = voxel_sword(grip, .8, "ch5q_item_diamond_sword")
	# The parry shield on the left forearm, the real shield plate.
	var sh := MeshInstance3D.new();var shb := BoxMesh.new();shb.size = Vector3(1 * PX, 22 * PX * .8, 12 * PX * .8);sh.mesh = shb
	var shm: StandardMaterial3D = material("ch5q_shield", false).duplicate();shm.uv1_scale = Vector3(1, 1, 1);sh.material_override = shm
	sh.position = Vector3(3 * PX, -7 * PX, 0);rigs.steve.la.add_child(sh);nodes.shield_s = sh
	var sh2: MeshInstance3D = sh.duplicate();rigs.notch.la.add_child(sh2);nodes.shield_n = sh2
	for who in ["steve", "notch"]:
		var ghosts: Array = []
		for k in range(4):
			var gr: Dictionary = make_rig("ch5_skin_" + who)
			for part in ["torso", "head", "ra", "la", "rl", "ll"]:
				for c in gr[part].get_children():
					if c is MeshInstance3D:c.transparency = .55 + k * .1;c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			gr.root.visible = false;ghosts.append(gr)
		nodes["ghosts_" + who] = ghosts;nodes["hist_" + who] = []
	var bolt := Node3D.new();scene.add_child(bolt);nodes.lightning = bolt;bolt.visible = false
	for k in range(9):
		var seg := MeshInstance3D.new();var sb := BoxMesh.new();sb.size = Vector3(.16, 1.5, .16);seg.mesh = sb;seg.material_override = flat(Color(.8, .85, 1), 9.0)
		bolt.add_child(seg)
	nodes.flash = omni(Vector3(0, 4, 2), Color(.75, .8, 1), 0.0, 22.0)
	var img: Image = tex("ch5_skin_notch").get_image()
	var bits: Array = []
	for at in [Vector2i(10, 10), Vector2i(9, 2), Vector2i(12, 14), Vector2i(20, 22), Vector2i(22, 26), Vector2i(4, 22), Vector2i(44, 22), Vector2i(6, 28)]:bits.append(img.get_pixel(at.x, at.y))
	nodes.notch_bits = bits
	nodes.pose_clock = 0.0

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
	var mv: Dictionary = fi.MOVES.get(f.move, {})
	# 0 → 1 through the windup, held at 1 when active, easing back in recovery.
	var k: float = 0.0
	if ph == "start":k = -clampf(f.t / maxf(.01, float(mv.get("start", .1))), 0, 1) * .5
	elif ph == "active":k = 1.0
	elif ph == "recover":k = 1.0 - clampf((f.t - float(mv.start) - float(mv.active)) / maxf(.01, float(mv.recover)), 0, 1) * .7
	var wind: float = maxf(0.0, -k) * 2.0
	k = maxf(0.0, k)
	match f.move:
		"jab":p.ra = Vector3(-1.57 * k - .3 + wind * .6, 0, -.1);p.la = Vector3(-1.2, 0, .4);p.torso = Vector3(.15, -.45 * k + wind * .2, 0);p.drop = -.08
		"jab2":p.la = Vector3(-1.62 * k - .3 + wind * .6, 0, .1);p.ra = Vector3(-1.2, 0, -.4);p.torso = Vector3(.15, .5 * k - wind * .2, 0);p.drop = -.08
		"hook":p.ra = Vector3(-1.4 - .3 * k, 1.1 * k - wind * .6, -1.0 * k);p.torso = Vector3(.2, -.9 * k + wind * .6, 0);p.rl = Vector3(-.5, 0, 0);p.ll = Vector3(.4, 0, 0);p.drop = -.12
		"kick":p.rl = Vector3(-1.9 * k + wind * .4, 0, 0);p.torso = Vector3(-.45 * k, -.2, 0);p.ra = Vector3(.5, 0, -.9);p.la = Vector3(-.9, 0, .6);p.ll = Vector3(.15, 0, 0)
		"sweep":p.drop = -.55;p.rl = Vector3(-1.5, 0, -.5 * k);p.ll = Vector3(-1.7, 0, 0);p.torso = Vector3(.6, -1.2 * k, 0);p.la = Vector3(.2, 0, .9)
		"launcher":p.ra = Vector3(-3.0 * k + wind * .5, 0, -.2);p.la = Vector3(.4, 0, .5);p.torso = Vector3(-.4 * k + wind * .3, -.3, 0);p.rl = Vector3(-.5, 0, 0);p.drop = -.25 * wind
		"uppercut":p.ra = Vector3(-3.1 * k, 0, -.15);p.la = Vector3(.5, 0, .7);p.torso = Vector3(-.5 * k, -.4, 0);p.rl = Vector3(-.9 * k, 0, 0);p.ll = Vector3(.3, 0, 0);p.drop = -.3 * wind
		"air":p.rl = Vector3(-1.4, 0, 0);p.ll = Vector3(.4, 0, 0);p.torso = Vector3(.5, 0, 0);p.ra = Vector3(-1.7 * k, 0, -.3)
		"spin":p.rl = Vector3(-1.7, 0, 0);p.ll = Vector3(-.4, 0, 0);p.torso = Vector3(.2, f.t * 22.0, 0);p.ra = Vector3(-1.5, 0, -1.2);p.la = Vector3(-1.5, 0, 1.2)
		"tnt", "code":p.ra = Vector3(-2.8 + 2.2 * k, 0, -.25);p.la = Vector3(-.6, 0, .4);p.torso = Vector3(.3 * k - .2 * wind, -.4, 0);p.rl = Vector3(-.4, 0, 0)
		"dash":p.ra = Vector3(-1.6, 0, -.1);p.la = Vector3(.6, 0, .4);p.torso = Vector3(.5 * k, -.3, 0);p.rl = Vector3(-1.1 * k, 0, 0);p.ll = Vector3(.8 * k, 0, 0);p.drop = -.15
		"dive":p.ra = Vector3(-.4, 0, -.2);p.la = Vector3(-.4, 0, .2);p.rl = Vector3(-.3, 0, 0);p.ll = Vector3(-.3, 0, 0);p.torso = Vector3(.3, 0, 0)
		"shield":p.la = Vector3(-1.45, -.5, .1);p.ra = Vector3(-.5, 0, -.3);p.torso = Vector3(.1, .35, 0);p.drop = -.18;p.rl = Vector3(-.4, 0, 0);p.ll = Vector3(.3, 0, 0)
		"pearl":p.ra = Vector3(-2.6 + 1.4 * k, 0, 0);p.torso = Vector3(.2, -.3, 0)
		"beam":p.ra = Vector3(-1.2, 0, -.2);p.la = Vector3(-1.2, 0, .2);p.torso = Vector3(.6 * k, 0, 0)
		"throw":p.ra = Vector3(-1.6, 0, -.1);p.la = Vector3(-1.6, 0, .1);p.torso = Vector3(-.4 * k, PI * .6 * k, 0)
		"swing":p.ra = Vector3(-2.8 + 2.4 * k, 0, -.4);p.torso = Vector3(.35 * k, -.5, 0)
		"super":
			if f.who == "steve":p.ra = Vector3(-1.57 + sin(f.t * 30.0) * 1.3, 0, -.3);p.torso = Vector3(.3, sin(f.t * 30.0) * .5, 0);p.rl = Vector3(-.6, 0, 0)
			else:p.ra = Vector3(-3.0, 0, -.4);p.la = Vector3(-3.0, 0, .4);p.head = Vector3(-.5, 0, 0)
	if f.block:p.ra = Vector3(-1.9, 0, .55);p.la = Vector3(-1.9, 0, -.55);p.drop = -.1;p.head = Vector3(.3, 0, 0)
	if f.stun > 0 and f.move.is_empty():p.torso = Vector3(-.5, 0, .1);p.head = Vector3(-.5, 0, 0);p.ra = Vector3(.3, 0, -.9);p.la = Vector3(.3, 0, .9)
	return p

func blend_pose(r: Dictionary, target: Dictionary, k: float):
	if not r.has("cur"):r.cur = target.duplicate();pose(r, target);return
	var cur: Dictionary = r.cur
	for key in ["torso", "head", "ra", "la", "rl", "ll"]:
		var a: Vector3 = cur.get(key, Vector3.ZERO);var b: Vector3 = target.get(key, Vector3.ZERO)
		cur[key] = a.lerp(b, k)
	cur.drop = lerpf(float(cur.get("drop", 0.0)), float(target.get("drop", 0.0)), k)
	pose(r, cur)

func sync_fighter(fi):
	var dt: float = clampf(fi.age - float(nodes.pose_clock), 0.0, .1) if fi.age >= float(nodes.pose_clock) else 1.0 / 60.0
	nodes.pose_clock = fi.age
	for f in fi.fighters:
		var r: Dictionary = rigs[f.who]
		r.root.position = Vector3(f.x, f.y, 0)
		r.root.rotation = Vector3(0, PI / 2 * f.face, 0)
		if f.ko or f.down > 0:
			r.root.rotation.x = -1.45 * (minf(1.0, fi.age * 3.0) if f.ko else 1.0);r.root.position.y = f.y + .15
		elif f.stun > 0 and f.y > .3:r.root.rotation.x = -.6
		elif f.move == "dive":r.root.rotation.x = .5
		elif f.move == "dash" and fi.phase_of(f) == "active":r.root.rotation.x = .35
		else:r.root.rotation.x = 0.0
		var fp: Dictionary = fighter_pose(f, fi)
		if fi.mode == "fists" and f.who == "notch" and fi.state in ["finisher", "wire", "done"]:
			fp = {"rl":Vector3(-1.5, 0, 0), "ll":Vector3(0, 0, 0), "drop":-.45, "torso":Vector3(.35, 0, 0), "head":Vector3(.4, 0, 0), "ra":Vector3(.2, 0, -.2), "la":Vector3(.2, 0, .2)}
			if fi.state != "finisher":fp.torso = Vector3(-.2, 0, 0);fp.head = Vector3(-.5, 0, 0);fp.ra = Vector3(-.4, 0, -.6);fp.la = Vector3(-.4, 0, .6)
		if fi.mode == "fists" and f.who == "steve" and fi.state in ["wire", "done"]:fp.ra = Vector3(-1.57, 0, 0);fp.torso = Vector3(0, -.4, 0)
		if fi.held(fi.fighters.find(f)) != null and f.move.is_empty():fp.ra = Vector3(-.4, 0, -.2)
		if f.who == "notch" and fi.state in ["finish", "fatality"]:
			var sway: float = sin(fi.age * 2.2)
			fp = {"rl":Vector3(-.1, 0, .08), "ll":Vector3(.1, 0, -.08), "torso":Vector3(.25 + sway * .08, 0, sway * .12), "head":Vector3(.45, 0, -sway * .2), "ra":Vector3(.15, 0, -.15 - sway * .1), "la":Vector3(.15, 0, .15 + sway * .1), "drop":-.08}
			r.root.rotation.z = sway * .06
			if fi.state == "fatality" and fi.age > 1.3:
				var fry: float = sin(fi.age * 60.0) * .25
				fp.ra = Vector3(-2.6 + fry, 0, -.9);fp.la = Vector3(-2.6 - fry, 0, .9);fp.head = Vector3(-.6, fry, 0);fp.torso = Vector3(-.3, 0, fry * .3)
				r.root.position += Vector3(sin(fi.age * 47.0) * .04, minf(.5, (fi.age - 1.3) * .5), 0)
		if f.who == "steve" and fi.state == "fatality":
			var a: float = fi.age
			if a < 1.3:fp.ra = Vector3(-3.1 * clampf(a / .5, 0, 1), 0, -.15);fp.torso = Vector3(-.15, 0, 0);fp.head = Vector3(-.5, 0, 0)
			elif a < 3.3:fp.ra = Vector3(-3.1, 0, -.15);fp.la = Vector3(-.4, 0, .5);fp.head = Vector3(-.2, 0, 0)
			else:fp.ra = Vector3(-2.9, 0, -.4);fp.la = Vector3(.2, 0, .3);fp.torso = Vector3(-.1, -.4, 0);fp.head = Vector3(-.2, .3, 0)
		var active: bool = fi.phase_of(f) == "active" or f.flash > 0
		blend_pose(r, fp, 1.0 - exp(-dt * (48.0 if active else 20.0)))
		var gone: bool = f.who == "notch" and fi.state == "fatality" and fi.age >= 2.5
		r.root.visible = not gone and (f.glitch <= 0 or int(fi.age * 30) % 2 == 0 or (f.who == "notch" and fi.state == "fatality"))
		r.root.scale = Vector3.ONE * (1.0 if f.who == "steve" else 1.08) * (1.06 if f.flash > 0 else 1.0)
		(nodes["shield_s" if f.who == "steve" else "shield_n"] as Node3D).visible = f.move == "shield"
		# Afterimages for the fast, heavy moves.
		var hist: Array = nodes["hist_" + f.who]
		hist.push_front({"pos":r.root.position, "rot":r.root.rotation, "pose":r.cur.duplicate(), "scale":r.root.scale})
		while hist.size() > 13:hist.pop_back()
		var trail: bool = f.move in ["dash", "uppercut", "dive", "super", "pearl"] or (f.stun > 0 and absf(f.vx) > 5.0) or (fi.state == "fatality" and f.who == "steve" and fi.age < 1.3)
		var ghosts: Array = nodes["ghosts_" + f.who]
		for k in range(ghosts.size()):
			var gr: Dictionary = ghosts[k];var idx: int = (k + 1) * 3
			gr.root.visible = trail and r.root.visible and hist.size() > idx
			if gr.root.visible:
				var hp: Dictionary = hist[idx]
				gr.root.position = hp.pos;gr.root.rotation = hp.rot;gr.root.scale = hp.scale;pose(gr, hp.pose)
	(nodes.super_sword as Node3D).visible = fi.steve().move == "super" or fi.state == "fatality"
	var mid: float = (fi.fighters[0].x + fi.fighters[1].x) / 2.0
	var spread: float = absf(fi.fighters[0].x - fi.fighters[1].x)
	var cam: Camera3D = nodes.cam
	var z: float = 7.6 + spread * .35 - fi.zoom * 2.2
	var top: float = maxf(fi.fighters[0].y, fi.fighters[1].y)
	cam.position = Vector3(mid, 1.9 + top * .4 - fi.zoom * .3, z)
	if fi.hitstop > 0:cam.position += Vector3(sin(fi.age * 90) * .06, cos(fi.age * 77) * .05, 0)
	cam.look_at(Vector3(mid, 1.1 + top * .35, 0))
	cam.fov = 40 - fi.zoom * 6
	var nx: float = fi.notch().x;var sx: float = fi.steve().x
	if fi.state == "finish":
		shot(cam, Vector3(mid + sin(fi.age * .4) * 1.2, 1.5, 5.4), Vector3(mid, 1.2, 0), 38, 0.0, fi.age)
	elif fi.state == "fatality":
		var a: float = fi.age
		if a < 1.3:shot(cam, Vector3(sx - fi.steve().face * .6, .45, 2.4), Vector3(sx, 1.9, 0), 46, 0.0, a)
		elif a < 2.5:shot(cam, Vector3(nx + 2.6, .9, 3.6), Vector3(nx, 1.6, 0), 44, .04, a)
		elif a < 3.3:shot(cam, Vector3(nx + 1.5, 1.6, 6.5), Vector3(nx, 1.0, 0), 50, .05 * (3.3 - a), a)
		else:shot(cam, Vector3(mid + (a - 3.3) * .4, 2.6, 7.5), Vector3(mid, 1.0, 0), 44, 0.0, a)
	var shown: Array = []
	for bo in fi.bolts:
		var n: Node3D = take("bolt", bo.kind)
		n.position = Vector3(bo.x, bo.y, 0);n.rotation = Vector3(fi.age * 8, fi.age * 5, 0) if bo.kind != "beam" else Vector3.ZERO;shown.append(n)
	for wl in fi.walls:
		var n: Node3D = take("cobble", "");n.position = Vector3(wl.x, .75, 0);n.scale = Vector3(1, minf(1.0, (3.0 - wl.life) * 6.0 + .05), 1);shown.append(n)
	for fl in fi.falls:
		var n: Node3D = take("cobble", "");n.position = Vector3(fl.x, fl.y + .5, 0);n.scale = Vector3(.7, .7, .7);shown.append(n)
	for sp in fi.sparks:
		var at := Vector3(sp.x, sp.y, .4)
		if sp.get("boom", false):
			mc_explosion(at, sp.age, 1.6, shown);continue
		if sp.get("dust", false):
			for k in range(6):shown.append(mcfx("smoke", at + Vector3((k - 2.5) * .3, sp.age * .8, 0), sp.age / .45, .6, Color(.75, .7, .65, 1 - sp.age / .45)))
			continue
		if sp.get("parry", false):
			var tp: float = sp.age / .45
			for k in range(10):
				var ang: float = k * .628
				shown.append(mcfx("magic", at + Vector3(cos(ang), sin(ang), 0) * (.2 + tp * 1.4), tp, .3))
			shown.append(mcfx("sweep", at, tp, 2.2, Color(.6, .9, 1)))
			continue
		var t: float = sp.age / .45
		for k in range(5 if sp.get("heavy", false) else 3):
			var ang: float = k * 1.257 + sp.x
			shown.append(mcfx("crit" if not sp.blocked else "spark", at + Vector3(cos(ang), sin(ang), 0) * (.15 + t * .9), t, .22, Color(1, 1, 1, 1 - t)))
		if sp.get("heavy", false):shown.append(mcfx("sweep", at + Vector3(0, -.1, .05), t, 1.3))
		if sp.get("heavy", false):
			for j in range(6):
				var px: Node3D = take("pixel", str(j % 2));var ang: float = j * 1.05 + sp.x
				px.position = Vector3(sp.x + cos(ang) * sp.age * 3.0, sp.y + sin(ang) * sp.age * 3.0 - sp.age * sp.age * 4.0, .35);px.scale = Vector3.ONE * 1.4;shown.append(px)
	var bolt: Node3D = nodes.lightning
	bolt.visible = false;(nodes.flash as OmniLight3D).light_energy = 0.0
	for f in fi.fighters:
		var at := Vector3(f.x, .1, .1)
		if f.move == "dash" and fi.phase_of(f) == "active":
			for k in range(3):shown.append(mcfx("smoke", at + Vector3(-f.face * k * .35, .1 + k * .05, 0), fmod(fi.age * 4 + k * .3, 1.0), .5, Color(.8, .8, .8, .6)))
			shown.append(mcfx("sweep", Vector3(f.x + f.face * .9, 1.1, .3), clampf((f.t - .07) / .24, 0, .99), 1.8))
		if f.move == "uppercut" and fi.phase_of(f) != "recover":
			for k in range(4):shown.append(mcfx("flame", Vector3(f.x + f.face * .4, f.y + .6 + k * .45, .2), fmod(fi.age * 5 + k * .25, 1.0), .35))
		if f.move == "dive":
			for k in range(3):shown.append(mcfx("crit", Vector3(f.x - f.face * .2 * k, f.y + 1.0 + k * .3, .2), fmod(fi.age * 6 + k * .3, 1.0), .3))
		if f.move == "shield" and fi.phase_of(f) == "active":
			for k in range(6):
				var ang: float = fi.age * 5 + k * 1.047
				shown.append(mcfx("magic", Vector3(f.x + f.face * .55, f.y + 1.0 + sin(ang) * .6, cos(ang) * .6), fmod(fi.age * 3 + k * .16, 1.0), .25))
		if fi.state == "finish" and f.who == "notch":
			for k in range(3):
				var ang: float = fi.age * 3 + k * 2.09
				shown.append(mcfx("crit", Vector3(f.x + cos(ang) * .45, 2.2 + sin(fi.age * 4 + k) * .05, sin(ang) * .45), fmod(fi.age + k * .3, 1.0), .2))
	if fi.state == "fatality":
		var a: float = fi.age
		if a > 1.3 and a < 2.4:
			bolt.visible = int(a * 24) % 3 != 0
			for k in range(bolt.get_child_count()):
				var seg: MeshInstance3D = bolt.get_child(k)
				var jx: float = sin(k * 2.3 + floor(a * 12) * 1.7) * .35
				seg.position = Vector3(nx + jx, 1.0 + k * 1.4, 0);seg.rotation = Vector3(0, 0, sin(k * 1.9 + floor(a * 12)) * .4)
			(nodes.flash as OmniLight3D).position = Vector3(nx, 3, 1.5);(nodes.flash as OmniLight3D).light_energy = 8.0 if bolt.visible else 2.0
			for k in range(6):shown.append(mcfx("spark", Vector3(nx + sin(k * 1.3 + a * 9) * .5, .6 + fmod(a * 3 + k * .2, 1.6), .3), fmod(a * 4 + k * .2, 1.0), .3))
		if a > 2.5:
			var t: float = a - 2.5
			if t < 1.4:mc_explosion(Vector3(nx, 1.2, .2), t, 2.2, shown)
			var bits: Array = nodes.notch_bits
			for k in range(48):
				var ang: float = k * 2.39996
				var v := Vector3(cos(ang) * (2.0 + fmod(k * .37, 1.0) * 3.5), 4.0 + fmod(k * .61, 1.0) * 6.0, sin(ang) * (1.0 + fmod(k * .23, 1.0) * 2.0))
				var p: Vector3 = Vector3(nx, 1.2, 0) + v * t + Vector3(0, -GRAV_GIB * t * t, 0)
				if p.y < .06:p.y = .06
				var n: Node3D = take("bit", str(k % bits.size()));n.position = p;n.rotation = Vector3(t * (3 + k % 5), t * (2 + k % 3), 0) if p.y > .07 else Vector3(0, k, 0);shown.append(n)
			if t < 2.0:shown += blood_spray(Vector3(nx, 1.2, 0), t * .8, a)
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

const GRAV_GIB := 9.0
var fx_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_five_fx.json"))

## A vanilla particle as a camera-facing sprite: kind from chapter_five_fx.json, t in 0..1.
func mcfx(kind: String, at: Vector3, t: float, size: float, tint := Color.WHITE) -> Node3D:
	var d: Dictionary = fx_data[kind]
	var n: Sprite3D = take("mcfx", kind)
	var frame: int = mini(int(d.count) - 1, int(t * d.count))
	n.region_rect = Rect2(frame * d.frame[0], 0, d.frame[0], d.frame[1])
	n.pixel_size = size / float(d.frame[0]);n.position = at;n.modulate = tint
	return n

## The Minecraft explosion: a cluster of puffs, each running its frames.
func mc_explosion(at: Vector3, age: float, scale: float, shown: Array):
	for k in range(7):
		var start: float = k * .045
		var t: float = (age - start) / .5
		if t < 0 or t >= 1:continue
		var off := Vector3(sin(k * 2.39996), cos(k * 1.7) * .6, cos(k * 2.39996)) * scale * (.15 + .25 * (k % 3))
		shown.append(mcfx("explosion", at + off, t, scale * (1.0 + (k % 2) * .4)))
	for k in range(5):
		var t: float = (age - .15) / 1.0
		if t < 0 or t >= 1:continue
		shown.append(mcfx("smoke", at + Vector3(sin(k * 1.3) * .4, t * 1.2, cos(k * 1.3) * .4) * scale, t, scale * .7, Color(.6, .6, .6, 1 - t)))

func take(kind: String, variant: String) -> Node3D:
	var key: String = kind + variant
	if not pool.has(key):pool[key] = []
	for n in pool[key]:
		if not n.get_meta("used", false):n.set_meta("used", true);n.visible = true;return n
	if kind == "mcfx":
		var sp := Sprite3D.new();sp.texture = tex(fx_data[variant].sprite);sp.region_enabled = true;sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST;sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED;sp.shaded = false;sp.no_depth_test = false
		sp.set_meta("used", true);scene.add_child(sp);pool[key].append(sp);return sp
	var n := MeshInstance3D.new()
	match kind:
		"bolt":
			var b := BoxMesh.new()
			match variant:
				"tnt":b.size = Vector3(.45, .45, .45);n.material_override = material("ch5q_tnt", false)
				"beam":b.size = Vector3(1.4, .12, .5);n.material_override = flat(Color(.97, 0, .86), 4.0)
				_:b.size = Vector3(.4, .4, .4);n.material_override = flat(Color(.3, 1, .9), 3.0)
			n.mesh = b
		"cobble":
			var b := BoxMesh.new();b.size = Vector3(.8, 1.5, .8);n.mesh = b;n.material_override = material("ch5q_cobblestone", false)
		"spark":
			var s := SphereMesh.new();s.radius = .12;s.height = .24;n.mesh = s;n.material_override = flat(Color(1, .85, .3, .9), 6.0, true)
		"rocket":
			var b := BoxMesh.new();b.size = Vector3(.16, .16, .5);n.mesh = b;n.material_override = flat(Color(.85, .3, .1), 2.0)
		"trail":
			var b := BoxMesh.new();b.size = Vector3(.12, .12, .12);n.mesh = b;n.material_override = flat(Color(.6, .6, .6, .5), 0.0, true)
		"blast":
			var s := SphereMesh.new();s.radius = 1.0;s.height = 2.0;n.mesh = s;n.material_override = flat(Color(1, .55, .15, .6), 5.0, true)
		"blood":
			var b := BoxMesh.new();b.size = Vector3(.075, .075, .075);n.mesh = b;n.material_override = flat(Color(.7, .03, .04) if variant == "0" else Color(.5, .02, .03), .6)
		"fireball":
			var sm := SphereMesh.new();sm.radius = .14;sm.height = .28;n.mesh = sm;n.material_override = flat(Color(1, .5, .1), 5.0)
		"beam":
			var b := BoxMesh.new();b.size = Vector3(.05, .05, 1.0);n.mesh = b;n.material_override = flat(Color(.6, .9, 1, .8), 6.0, true)
		"bit":
			var b := BoxMesh.new();b.size = Vector3(.16, .16, .16);n.mesh = b;n.material_override = flat(nodes.notch_bits[int(variant)] if nodes.has("notch_bits") else Color.WHITE)
		"gib":
			var b := BoxMesh.new();b.size = Vector3(.14, .14, .14);n.mesh = b;n.material_override = flat(Color(.65, .05, .05) if variant == "red" else Color(.75, .55, .45))
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

## A held item: its sprite pushed out into a block of voxels, one per pixel.
func extrude(name: String, depth := 1.0) -> ArrayMesh:
	var im: Image = tex(name).get_image()
	im.convert(Image.FORMAT_RGBA8)
	var w: int = im.get_width();var h: int = im.get_height()
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var px: float = 1.0 / 16.0;var dz: float = depth * px * .5
	var solid = func(x: int, y: int) -> bool:return x >= 0 and y >= 0 and x < w and y < h and im.get_pixel(x, y).a > .5
	for y in range(h):
		for x in range(w):
			if not solid.call(x, y):continue
			var c: Color = im.get_pixel(x, y)
			var x0: float = (x - w / 2.0) * px;var x1: float = x0 + px;var y0: float = (h / 2.0 - y - 1) * px;var y1: float = y0 + px
			var quads := [[Vector3(x0, y1, dz), Vector3(x1, y1, dz), Vector3(x1, y0, dz), Vector3(x0, y0, dz), 1.0],
				[Vector3(x1, y1, -dz), Vector3(x0, y1, -dz), Vector3(x0, y0, -dz), Vector3(x1, y0, -dz), .7]]
			if not solid.call(x - 1, y):quads.append([Vector3(x0, y1, -dz), Vector3(x0, y1, dz), Vector3(x0, y0, dz), Vector3(x0, y0, -dz), .6])
			if not solid.call(x + 1, y):quads.append([Vector3(x1, y1, dz), Vector3(x1, y1, -dz), Vector3(x1, y0, -dz), Vector3(x1, y0, dz), .8])
			if not solid.call(x, y - 1):quads.append([Vector3(x0, y1, -dz), Vector3(x1, y1, -dz), Vector3(x1, y1, dz), Vector3(x0, y1, dz), .9])
			if not solid.call(x, y + 1):quads.append([Vector3(x0, y0, dz), Vector3(x1, y0, dz), Vector3(x1, y0, -dz), Vector3(x0, y0, -dz), .5])
			for q in quads:
				var shade: Color = Color(c.r * q[4], c.g * q[4], c.b * q[4])
				for i in [0, 1, 2, 0, 2, 3]:st.set_color(shade);st.add_vertex(q[i])
	var mesh := st.commit()
	return mesh

func voxel(name: String, scale: float, depth := 1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new();m.mesh = extrude(name, depth);m.scale = Vector3.ONE * scale
	var mat := StandardMaterial3D.new();mat.vertex_color_use_as_albedo = true;mat.cull_mode = BaseMaterial3D.CULL_DISABLED;m.material_override = mat
	return m

func build_quake():
	var env := WorldEnvironment.new();var e := Environment.new();env.environment = e
	e.background_mode = Environment.BG_COLOR;e.background_color = Color(.05, .03, .02)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color = Color(.55, .42, .3);e.ambient_light_energy = .6
	e.fog_enabled = true;e.fog_light_color = Color(.22, .12, .06);e.fog_density = .03
	scene.add_child(env)
	var q = load("res://scripts/chapter_five_quake.gd").new();q.reset()
	for b in q.boxes:
		var m := MeshInstance3D.new();var bm := BoxMesh.new();bm.size = b[1] - b[0];m.mesh = bm
		m.position = (b[0] + b[1]) / 2.0;m.material_override = material("ch5q_" + b[2], true);scene.add_child(m)
	for lv in q.lava:
		var m := MeshInstance3D.new();var bm := BoxMesh.new();bm.size = Vector3(lv[1].x - lv[0].x, .1, lv[1].z - lv[0].z);m.mesh = bm
		m.position = Vector3((lv[0].x + lv[1].x) / 2, .02, (lv[0].z + lv[1].z) / 2);m.material_override = material("ch5q_lava_still", true, 2.5);scene.add_child(m)
		omni(m.position + Vector3(0, 1, 0), Color(1, .45, .1), 2.0, 7.0)
	for pad in q.pads:
		var m := MeshInstance3D.new();var bm := BoxMesh.new();bm.size = Vector3(1.6, .12, 1.6);m.mesh = bm
		m.position = pad.p + Vector3(0, .06, 0);m.material_override = material("ch5q_redstone_block", true, 2.0);scene.add_child(m)
	var lamp_spots := [Vector3(-9, 5.6, -6), Vector3(9, 5.6, -6), Vector3(-9, 5.6, 6), Vector3(9, 5.6, 6), Vector3(0, 5.0, 0), Vector3(0, 6.0, -16), Vector3(0, 6.0, 16)]
	for i in range(lamp_spots.size()):
		var c: Vector3 = lamp_spots[i]
		var l := omni(c, Color(1, .7, .4), 1.6, 11.0)
		var lamp := MeshInstance3D.new();var lb := BoxMesh.new();lb.size = Vector3(.5, .5, .5);lamp.mesh = lb;lamp.position = c + Vector3(0, .5, 0)
		lamp.material_override = material("ch5q_glowstone", true, 3.0);scene.add_child(lamp);nodes["lamp%d" % i] = l
	var cam := Camera3D.new();cam.fov = 88;cam.near = .05;scene.add_child(cam);nodes.cam = cam
	var guns := {}
	var holder := Node3D.new();cam.add_child(holder);holder.position = Vector3(.3, -.28, -.5);nodes.gun = holder
	var pick := voxel("ch5q_item_diamond_pickaxe", .55);pick.rotation = Vector3(0, PI / 2 - .2, .3);holder.add_child(pick);guns.pickaxe = pick
	var charges := Node3D.new();holder.add_child(charges);guns.charges = charges
	var rod := voxel("ch5q_item_blaze_rod", .55);rod.rotation = Vector3(-1.2, 0, -.6);rod.position = Vector3(.02, -.02, .05);charges.add_child(rod)
	var ball := voxel("ch5q_item_fire_charge", .32, 3.0);ball.position = Vector3(-.02, .13, -.14);charges.add_child(ball);nodes.ball = ball
	var launcher := Node3D.new();holder.add_child(launcher);guns.rockets = launcher
	var body := MeshInstance3D.new();var bb := BoxMesh.new();bb.size = Vector3(.2, .2, .2);body.mesh = bb;body.material_override = material("ch5q_furnace_side", false);launcher.add_child(body)
	var face := MeshInstance3D.new();var fb := QuadMesh.new();fb.size = Vector2(.2, .2);face.mesh = fb;face.position = Vector3(0, 0, -.101);face.rotation.y = PI
	var fmat := StandardMaterial3D.new();fmat.albedo_texture = tex("ch5q_dispenser_front");fmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST;face.material_override = fmat;launcher.add_child(face)
	var barrel := MeshInstance3D.new();var brm := BoxMesh.new();brm.size = Vector3(.11, .11, .5);barrel.mesh = brm;barrel.position = Vector3(0, .02, -.3);barrel.material_override = material("ch5q_iron_block", false);launcher.add_child(barrel)
	var tnt := MeshInstance3D.new();var tm := BoxMesh.new();tm.size = Vector3(.1, .1, .1);tnt.mesh = tm;tnt.position = Vector3(0, .15, .02);tnt.material_override = material("ch5q_tnt", false);launcher.add_child(tnt)
	var bow := voxel("ch5q_item_crossbow_standby", .6);bow.rotation = Vector3(0, PI / 2 + .3, PI / 4 + .2);guns.crossbow = bow;holder.add_child(bow)
	nodes.guns = guns
	var flash := OmniLight3D.new();flash.position = Vector3(0, 0, -.8);flash.light_color = Color(1, .7, .3);flash.omni_range = 5;flash.light_energy = 0;holder.add_child(flash);nodes.flash = flash
	rigs.notch = make_rig("ch5_skin_notch")
	var held := Node3D.new();rigs.notch.ra.add_child(held);held.position = Vector3(-1 * PX, -10 * PX, .15);nodes.notch_hand = held
	var item_tex := {"health":"ch5q_item_golden_apple", "mega":"ch5q_item_golden_apple", "armor":"ch5q_item_iron_chestplate", "charges":"ch5q_item_fire_charge", "rockets":"ch5q_item_tnt_minecart", "crossbow":"ch5q_item_crossbow_standby", "quad":"icon_command_block"}
	for i in range(q.items.size()):
		var it: Dictionary = q.items[i]
		var s := voxel(item_tex[it.kind], 1.0 if it.kind != "mega" else 1.4, 2.0) if it.kind != "quad" else null
		var n: Node3D
		if s != null:n = s
		else:
			var sp := Sprite3D.new();sp.pixel_size = .05;sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED;sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST;sp.texture = tex(item_tex[it.kind]);n = sp
		scene.add_child(n);nodes["item%d" % i] = n
		if it.kind in ["mega", "quad"]:
			var gl := omni(it.p + Vector3(0, .8, 0), Color(1, .85, .3) if it.kind == "mega" else Color(.4, .5, 1), 1.5, 4.0);nodes["itemlight%d" % i] = gl

func sync_quake(qk):
	var s: Dictionary = qk.steve();var n: Dictionary = qk.notch()
	var cam: Camera3D = nodes.cam
	cam.position = qk.eye(s) + Vector3(0, sin(s.walk * 2.2) * .035 if s.grounded else 0.0, 0)
	cam.rotation = Vector3(s.pitch + s.fired * .25, s.yaw, 0)
	if s.dead > 0:cam.position.y = s.p.y + .3;cam.rotation.z = .4
	var gun: Node3D = nodes.gun
	gun.position = Vector3(.3 + sin(s.walk * 1.1) * .015, -.28 - s.fired * .3 + absf(cos(s.walk * 1.1)) * .01, -.5 + s.fired * .5)
	gun.rotation = Vector3(s.swing * 3.0, 0, -s.swing * 1.5)
	gun.visible = s.dead <= 0
	for k in nodes.guns:(nodes.guns[k] as Node3D).visible = k == s.weapon
	(nodes.ball as Node3D).rotation.y = qk.age * 6.0
	nodes.flash.light_energy = 4.0 if s.fired > .06 and s.weapon != "pickaxe" else 0.0
	var r: Dictionary = rigs.notch
	r.root.visible = n.dead <= 0 or n.dead > 1.6
	r.root.position = n.p
	r.root.rotation = Vector3(0, n.yaw + PI, 0)
	var swing: float = sin(n.walk * 2.5)
	pose(r, {"rl":Vector3(swing * .7, 0, 0), "ll":Vector3(-swing * .7, 0, 0), "ra":Vector3(-1.4 - n.pitch - n.swing * 3.0, 0, 0), "la":Vector3(-1.2 - n.pitch, 0, .5), "head":Vector3(-n.pitch * .5, 0, 0)})
	var hand: Node3D = nodes.notch_hand
	if hand.get_meta("weapon", "") != n.weapon:
		for c in hand.get_children():c.queue_free()
		var model: Node3D = {"pickaxe":func():return voxel("ch5q_item_diamond_pickaxe", .9), "charges":func():return voxel("ch5q_item_blaze_rod", .9), "rockets":func():
			var b := MeshInstance3D.new();var bm := BoxMesh.new();bm.size = Vector3(.25, .25, .7);b.mesh = bm;b.material_override = material("ch5q_furnace_side", false);return b, "crossbow":func():return voxel("ch5q_item_crossbow_standby", 1.0)}[n.weapon].call()
		model.rotation = Vector3(-PI / 2, 0, 0);hand.add_child(model);hand.set_meta("weapon", n.weapon)
	if n.dead > 0:r.root.rotation.x = -1.4
	var shown: Array = []
	for rk in qk.rockets:
		var m: Node3D = take("rocket", "")
		m.position = rk.p;m.look_at(rk.p + rk.v, Vector3.UP);shown.append(m)
		for k in range(5):
			shown.append(mcfx("smoke", rk.p - rk.v.normalized() * (k + 1) * .3, k / 5.0, .25 + k * .06, Color(.7, .7, .7, 1 - k / 5.0)))
		shown.append(mcfx("flame", rk.p - rk.v.normalized() * .15, 0.0, .3))
	for sh in qk.shots:
		var m: Node3D = take("fireball", "");m.position = sh.p;shown.append(m)
		shown.append(mcfx("flame", sh.p - sh.v.normalized() * .2, 0.0, .28))
		shown.append(mcfx("smoke", sh.p - sh.v.normalized() * .45, .5, .2, Color(.5, .5, .5, .6)))
	for bm in qk.beams:
		var m: Node3D = take("beam", "");m.position = (bm.a + bm.b) / 2.0;m.look_at(bm.b, Vector3.UP);m.scale = Vector3(1.0 - bm.age / .45, 1.0 - bm.age / .45, bm.a.distance_to(bm.b));shown.append(m)
	for b in qk.blasts:mc_explosion(b.p, b.age, 1.4, shown)
	for g in qk.gibs:
		var m: Node3D = take("gib", "red" if g.red else "skin");m.position = g.p;m.rotation = Vector3(g.age * 7, g.age * 5, 0);shown.append(m)
	hide_rest(shown)
	for i in range(qk.items.size()):
		var it: Dictionary = qk.items[i];var sp: Node3D = nodes["item%d" % i]
		sp.visible = it.left <= 0
		sp.position = it.p + Vector3(0, .6 + sin(qk.age * 2.5 + i) * .12, 0)
		if not (sp is Sprite3D):sp.rotation.y = qk.age * 1.8 + i
		if nodes.has("itemlight%d" % i):nodes["itemlight%d" % i].visible = it.left <= 0
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

## A voxel sword whose blade points along the parent's -Y (down the arm),
## handle at the parent's origin.
func voxel_sword(parent: Node3D, scale := 1.0, item := "ch5q_item_iron_sword") -> Node3D:
	var holder := Node3D.new();parent.add_child(holder)
	var v := voxel(item, scale, 1.4)
	v.rotation = Vector3(0, PI / 2, deg_to_rad(-135))
	v.position = Vector3(0, -.42 * scale, 0)
	holder.add_child(v)
	return holder

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
	var flying := Node3D.new();scene.add_child(flying);nodes.flying = flying
	var mid := Node3D.new();mid.rotation = Vector3(-PI / 2, 0, 0);flying.add_child(mid)
	var blade := voxel("ch5q_item_iron_sword", 1.1, 1.4);blade.rotation = Vector3(0, 0, deg_to_rad(-45));mid.add_child(blade);nodes.flying_blade = blade
	var cracks := label("", Vector3(0, 2.4, -2.9), 90, Color(1, 1, 1, .9), .004);cracks.text = "╳";nodes.cracks = cracks
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
	var fl: Node3D = nodes.flying
	var target := Vector3(.3, 2.5, -2.7)
	fl.visible = f.thrown >= 0
	(nodes.cracks as Label3D).visible = f.thrown >= .6
	if fl.visible:
		var t: float = clampf(f.thrown / .6, 0, 1)
		var from := Vector3(-1.3, 1.6, 1.0)
		var pos: Vector3 = from.lerp(target, t) + Vector3(0, sin(t * PI) * .25, 0)
		var ahead: Vector3 = from.lerp(target, minf(1.0, t + .05)) + Vector3(0, sin(minf(1.0, t + .05) * PI) * .25, 0)
		fl.position = pos
		if t < 1.0:
			fl.look_at(ahead if ahead.distance_to(pos) > .001 else target, Vector3.UP)
			fl.rotate_object_local(Vector3.FORWARD, t * 14.0)
		else:
			fl.position = target + (target - from).normalized() * .25
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
	elif f.thrown < .6:shot(cam, Vector3(1.9, 1.7, 2.6), Vector3(-.4, 1.9, -1.0), 50, 0.0, clock)
	elif f.thrown < 1.4:shot(cam, Vector3(.6, 2.2, -.4), Vector3(0, 2.3, -3.0), 60, .06 * (1.4 - f.thrown), clock)
	else:shot(cam, Vector3(-2.2, 1.6, 3.2), Vector3(1.6, .8, -1.0), 48, 0.0, clock)

# ------------------------------------------------------------------ the chair

func build_chair():
	room(Color(.01, .01, .015), Color(.32, .34, .42), .75)
	omni(Vector3(-2.5, 2.2, 2.5), Color(.55, .65, 1.0), 1.1, 7.0)
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
	var grip := Node3D.new();grip.position = Vector3(-1 * PX, -10 * PX, 0);rigs.steve.ra.add_child(grip)
	nodes.sword = voxel_sword(grip, .85)
	var pool_mesh := MeshInstance3D.new();var pm := CylinderMesh.new();pm.top_radius = 1.0;pm.bottom_radius = 1.0;pm.height = .01;pool_mesh.mesh = pm
	pool_mesh.material_override = flat(Color(.38, .02, .03));pool_mesh.position = Vector3(0, .012, .25);scene.add_child(pool_mesh);nodes.pool = pool_mesh
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
	# After the blade: he slumps and stays in the chair.
	var after: float = clampf((a - stab) / .6, 0, 1)
	var limp: float = clampf((a - (stab + 2.4)) / 2.5, 0, 1)
	if a > stab:
		np.torso = Vector3(-.3 * after * (1 - limp) + .45 * limp, 0, .05 * limp)
		np.head = Vector3(-.55 * after * (1 - limp) + .95 * limp, 0, .2 * limp)
		np.ra = Vector3(.55 + .25 * limp, 0, -.2 - .25 * limp);np.la = Vector3(.55 + .25 * limp, 0, .2 + .25 * limp)
		if a < stab + 1.2:np.head += Vector3(sin(clock * 40) * .03, 0, 0)
	pose(n, np)
	n.root.visible = true
	for part in ["ll", "rl", "la", "ra", "torso", "head"]:
		for c in n[part].get_children():
			if c is MeshInstance3D:c.visible = true
	for k in range(3):
		var c: MeshInstance3D = nodes["chain%d" % k]
		c.position = Vector3(0, .82 + k * .22, .05 - after * .03);c.rotation = Vector3.ZERO
	var pool_k: float = clampf((a - stab - .8) / 6.0, 0, 1)
	(nodes.pool as MeshInstance3D).visible = pool_k > 0
	(nodes.pool as MeshInstance3D).scale = Vector3(.1 + pool_k * .55, 1, .1 + pool_k * .45)
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
	if a > stab + 5.5:
		var pull: float = clampf((a - (stab + 5.5)) / .6, 0, 1)
		sp.ra = Vector3(-1.55 + 1.2 * pull, 0, -.1 * pull);s.root.position = to + Vector3(0, 0, -.22 + .5 * pull);sp.torso = Vector3(.1 - .2 * pull, 0, 0)
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
	if a > stab and a < stab + 2.2:shown += blood_spray(Vector3(0, 1.05, -.05), a - stab, clock)
	if a > stab + .3 and a < stab + 12.0:shown += blood_drips(Vector3(0, .95, .12), a - stab, clock)
	if a > stab + 5.5 and a < stab + 7.0:shown += blood_spray(Vector3(0, 1.05, .25), (a - stab - 5.5) * 1.6, clock)
	hide_rest(shown)
	var h: float = clock
	if a < 4.0:shot(cam, Vector3(3.4 - a * .25, 2.6, 4.4 - a * .3), Vector3(0, 1.0, 0), 40, 0.0, h)
	elif a < 12.6:shot(cam, Vector3(-2.2, 1.65, 1.6), Vector3(0, 1.25, 0), 36, .005, h)
	elif a < 21.4:shot(cam, Vector3(.35, 1.45, 1.35), Vector3(0, 1.32, 0), 34, .008, h)
	elif a < f.CHAIR_SWORD:shot(cam, Vector3(.6, .55, 1.7), Vector3(0, 1.3, 0), 44, .012, h)
	elif a < stab - .5:shot(cam, Vector3(-3.8, 1.7, 3.2), Vector3(-.5, 1.0, .5), 40, 0.0, h)
	elif a < stab + 1.8:shot(cam, Vector3(3.6, 1.3, .25), Vector3(0, 1.05, .3), 34 - clampf(a - stab, 0, 1) * 6, .035 * clampf(1.0 - absf(a - stab) * 2, 0, 1), h)
	elif a < stab + 3.4:shot(cam, Vector3(-2.6, .75, 2.3), Vector3(0, 1.0, .35), 38, 0.0, h)
	elif a < stab + 5.5:shot(cam, Vector3(-2.3, 2.0, 2.7), Vector3(0, 1.0, .15), 36, 0.0, h)
	elif a < stab + 7.5:shot(cam, Vector3(3.3, 1.35, .9), Vector3(0, 1.05, .45), 36, 0.0, h)
	else:shot(cam, Vector3(2.8, 2.4, 4.0), Vector3(0, .9, 0), 44, 0.0, h)

func blood_spray(at: Vector3, t: float, clock: float) -> Array:
	var out: Array = []
	for k in range(44):
		var ang: float = k * 2.39996
		var speed: float = 1.4 + fmod(k * .37, 1.0) * 1.8
		var dir := Vector3(sin(ang) * .6, .3 + fmod(k * .53, 1.0) * .8, -.6 - cos(ang) * .4 if k % 3 else .5)
		var p: Vector3 = at + dir * speed * t + Vector3(0, -4.0 * t * t, 0)
		if p.y < .02:p.y = .02
		var m: Node3D = take("blood", str(k % 2));m.position = p;m.scale = Vector3.ONE * (1.0 - t * .3);out.append(m)
	return out

func blood_drips(at: Vector3, t: float, clock: float) -> Array:
	var out: Array = []
	for k in range(6):
		var ph: float = fmod(t * .8 + k * .17, 1.0)
		var m: Node3D = take("blood", "1");m.position = at + Vector3(-.12 + k * .05, -ph * .9, 0);m.scale = Vector3(.6, 1.2, .6);out.append(m)
	return out

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

## Painterly world material: smooth filtering, tiled every `tile` units.
func wmat(name: String, tile := 4.0, rough := 1.0, emission := 0.0) -> StandardMaterial3D:
	var key: String = "w|%s|%s|%s|%s" % [name, tile, rough, emission]
	if cache.has(key):return cache[key]
	var m := StandardMaterial3D.new();m.albedo_texture = tex(name);m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.uv1_triplanar = true;m.uv1_scale = Vector3.ONE / tile;m.roughness = rough
	if emission > 0:m.emission_enabled = true;m.emission_texture = m.albedo_texture;m.emission_energy_multiplier = emission
	cache[key] = m;return m

func gloss(color: Color, rough := .3, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new();m.albedo_color = color;m.roughness = rough;m.metallic_specular = .8
	if emission > 0:m.emission_enabled = true;m.emission = color;m.emission_energy_multiplier = emission
	return m

func mesh_at(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new();m.mesh = mesh;m.position = at;m.rotation = rot;m.material_override = mat;parent.add_child(m);return m

func wbox(parent: Node3D, at: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new();b.size = size;return mesh_at(parent, b, at, mat, rot)

func ball(parent: Node3D, at: Vector3, r: float, mat: Material, squash := Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new();sm.radius = r;sm.height = r * 2;var m := mesh_at(parent, sm, at, mat);m.scale = squash;return m

func tube(parent: Node3D, at: Vector3, r_top: float, r_bottom: float, h: float, mat: Material, rot := Vector3.ZERO, sides := 16) -> MeshInstance3D:
	var c := CylinderMesh.new();c.top_radius = r_top;c.bottom_radius = r_bottom;c.height = h;c.radial_segments = sides;return mesh_at(parent, c, at, mat, rot)

func screen_quad(parent: Node3D, texname: String, size: Vector2, at: Vector3) -> MeshInstance3D:
	var q := QuadMesh.new();q.size = size
	var m := StandardMaterial3D.new();m.albedo_texture = tex(texname);m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST;m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mesh_at(parent, q, at, m)

func billboard(parent: Node3D, texname: String, at: Vector3, height: float) -> Sprite3D:
	var sp := Sprite3D.new();sp.texture = tex(texname);sp.pixel_size = height / float(sp.texture.get_height());sp.position = at
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y;sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD;sp.shaded = true;parent.add_child(sp);return sp

func mark(n: Node3D, kind: String, speed := 1.0) -> Node3D:
	n.set_meta("anim", kind);n.set_meta("speed", speed);n.set_meta("home", n.position);return n

## The other games, each in its own look: 0 GTA V, 1 Spore, 2 Dota 2,
## 3 Black Souls, 4 Fear & Hunger, 5 The Sims, 6 LEGO Batman 2, 7 Zuma, 8 Half-Life 2,
## 9 Command & Conquer: Generals, 10 Europa Universalis IV.
func diorama(kind: int, at: Vector3, scale: float) -> Node3D:
	var root := Node3D.new();root.position = at;root.scale = Vector3.ONE * scale;scene.add_child(root)
	match kind:
		0:
			wbox(root, Vector3(0, -.25, 0), Vector3(16, .5, 16), wmat("ch5w_tf2_concrete", 6))
			wbox(root, Vector3(0, .02, 0), Vector3(4, .05, 16), wmat("ch5w_gta_road", 4))
			var sky := QuadMesh.new();sky.size = Vector2(24, 12);var sm := StandardMaterial3D.new();sm.albedo_texture = tex("ch5w_gta_sky");sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh_at(root, sky, Vector3(0, 5, -9), sm)
			for k in range(6):
				var hgt: float = 5.0 + fmod(k * 3.7, 9.0)
				var x: float = -6.5 + k * 2.6
				wbox(root, Vector3(x, hgt / 2, -5.5 + (k % 2) * 1.2), Vector3(2.0, hgt, 2.0), wmat("ch5w_gta_glass" if k % 2 == 0 else "ch5w_gta_office", 4, .25))
			for k in range(6):billboard(root, "ch5w_gta_palm", Vector3(-2.8 if k % 2 == 0 else 2.8, 1.6, -5 + k * 2.2), 3.4)
			var car := Node3D.new();car.position = Vector3(.9, .3, 2);root.add_child(car);mark(car, "drive", 1.0)
			wbox(car, Vector3(0, .1, 0), Vector3(1.1, .35, 2.4), gloss(Color(.9, .45, .05), .2))
			wbox(car, Vector3(0, .38, -.15), Vector3(.9, .28, 1.1), gloss(Color(.05, .06, .1), .1))
			for w in [Vector3(-.55, -.05, .8), Vector3(.55, -.05, .8), Vector3(-.55, -.05, -.8), Vector3(.55, -.05, -.8)]:tube(car, w, .2, .2, .16, gloss(Color(.05, .05, .05), .8), Vector3(0, 0, PI / 2))
			for k in [-1, 1]:ball(car, Vector3(k * .35, .12, 1.21), .08, gloss(Color(1, .95, .8), .1, 4.0))
		1:
			tube(root, Vector3(0, -1, 0), 7.0, 5.5, 2.0, wmat("ch5w_spore_ground", 3), Vector3.ZERO, 32)
			var cr := Node3D.new();cr.position = Vector3(0, 1.6, 1);root.add_child(cr);mark(cr, "bob", 2.0)
			var skin: StandardMaterial3D = wmat("ch5w_spore_skin", 1.0, .6)
			ball(cr, Vector3.ZERO, 1.2, skin, Vector3(1.3, .9, 1.0))
			ball(cr, Vector3(0, .5, 1.1), .7, skin)
			for k in range(4):tube(cr, Vector3(-.9 + (k % 2) * 1.8, -1.1, -.4 + (k / 2) * .8), .12, .2, 1.2, skin)
			for k in [-1, 1]:
				tube(cr, Vector3(k * .25, 1.2, 1.1), .05, .05, .7, skin)
				ball(cr, Vector3(k * .25, 1.65, 1.15), .22, gloss(Color(1, 1, 1), .2))
				ball(cr, Vector3(k * .25, 1.65, 1.36), .1, gloss(Color(.02, .02, .05), .1))
			ball(cr, Vector3(0, .35, 1.75), .25, flat(Color(.35, .05, .1)), Vector3(1.4, .5, .5))
			for k in range(7):
				var pa := Vector3(cos(k * .9) * 5, 0, sin(k * .9) * 4 - 1)
				tube(root, pa + Vector3(0, 1.2, 0), .1, .18, 2.4, gloss(Color(.4, .9, .6), .6))
				ball(root, pa + Vector3(0, 2.6, 0), .6 + (k % 3) * .2, gloss([Color(1, .5, .8), Color(.5, .9, 1), Color(1, .9, .3)][k % 3], .4, .6))
			var ufo := Node3D.new();ufo.position = Vector3(3, 6, -3);root.add_child(ufo);mark(ufo, "hover", 1.0)
			ball(ufo, Vector3.ZERO, 1.6, gloss(Color(.75, .78, .85), .15), Vector3(1.0, .25, 1.0))
			ball(ufo, Vector3(0, .35, 0), .7, gloss(Color(.4, 1, .8, 1), .05, 1.5))
			for k in range(6):ball(ufo, Vector3(cos(k * 1.05) * 1.4, -.1, sin(k * 1.05) * 1.4), .12, gloss(Color(1, .9, .4), .1, 5.0))
		2:
			wbox(root, Vector3(0, -.5, 0), Vector3(16, 1, 16), wmat("ch5w_dota_grass", 5))
			wbox(root, Vector3(4, -.45, 4), Vector3(9, 1, 9), wmat("ch5w_dota_dire", 4))
			wbox(root, Vector3(0, -.42, 0), Vector3(3, 1, 22), wmat("ch5w_dota_river", 4, .2, .4), Vector3(0, PI / 4, 0))
			tube(root, Vector3(-5.5, .6, -5.5), 1.4, 1.8, 1.2, wmat("ch5w_dota_stone", 2))
			var anc := MeshInstance3D.new();var pr := PrismMesh.new();pr.size = Vector3(1.6, 3.2, 1.6);anc.mesh = pr;anc.position = Vector3(-5.5, 2.8, -5.5);anc.material_override = gloss(Color(.5, 1, .6), .2, 1.8);root.add_child(anc);mark(anc, "spin", .6)
			tube(root, Vector3(5.5, .6, 5.5), 1.4, 1.8, 1.2, wmat("ch5w_dota_stone", 2))
			for k in range(5):
				var sp: MeshInstance3D = tube(root, Vector3(5.5 + cos(k * 1.26) * .7, 2.2, 5.5 + sin(k * 1.26) * .7), 0, .3, 2.8, gloss(Color(.9, .15, .1), .3, 1.6), Vector3(sin(k * 1.26) * .4, 0, cos(k * 1.26) * .4))
			for k in range(4):
				var tp := Vector3(-6 + k * 1.2, 0, 3 - k * 3) if k < 2 else Vector3(2 + (k - 2) * 2, 0, -6 + (k - 2) * 1.0)
				tube(root, tp + Vector3(0, 1.2, 0), .35, .5, 2.4, wmat("ch5w_dota_stone", 1.5))
				ball(root, tp + Vector3(0, 2.7, 0), .35, gloss(Color(.4, 1, .6) if k < 2 else Color(1, .3, .2), .2, 3.0))
			for k in range(6):
				var c: MeshInstance3D = wbox(root, Vector3(-1.5 + k * .6, .3, -1.5 + k * .6), Vector3(.35, .6, .35), gloss(Color(.3, .8, .3) if k < 3 else Color(.8, .2, .15), .6))
		3, 4:
			var frame := wbox(root, Vector3(0, 4.5, -.25), Vector3(17.4, 13.4, .4), wmat("ch5q_dark_oak_planks" if kind == 3 else "ch5w_tf2_rock", 2))
			frame.material_override = material("ch5q_dark_oak_planks", true) if kind == 3 else gloss(Color(.25, .2, .16), .9)
			screen_quad(root, "ch5w_rpg_black" if kind == 3 else "ch5w_rpg_fear", Vector2(16, 12), Vector3(0, 4.5, 0))
			if kind == 3:
				for k in range(10):
					var petal: MeshInstance3D = wbox(root, Vector3(-8 + k * 1.7, 4 + sin(k) * 5, .6), Vector3(.25, .12, .05), gloss(Color(.8, .05, .1), .5, .8))
					mark(petal, "fall", .6 + fmod(k * .37, .6))
			else:
				for k in [-1, 1]:
					tube(root, Vector3(k * 9.4, 1.2, .4), .25, .25, 2.4, gloss(Color(.85, .8, .7), .8))
					var fl: MeshInstance3D = ball(root, Vector3(k * 9.4, 2.6, .4), .2, gloss(Color(1, .6, .15), .5, 6.0), Vector3(1, 1.6, 1));mark(fl, "flicker", 1.0)
				omni(root.position + Vector3(0, 2, 3), Color(1, .6, .3), 1.2, 14.0)
		5:
			wbox(root, Vector3(0, -.25, 0), Vector3(16, .5, 16), wmat("ch5w_sims_grass", 5))
			wbox(root, Vector3(0, .1, -1), Vector3(10, .2, 8), wmat("ch5w_sims_floor", 2))
			wbox(root, Vector3(0, 1.4, -5), Vector3(10, 2.6, .25), wmat("ch5w_sims_wall", 2))
			wbox(root, Vector3(-5, 1.4, -1), Vector3(.25, 2.6, 8), wmat("ch5w_sims_wall", 2))
			wbox(root, Vector3(1.5, 1.4, -1), Vector3(.25, 2.6, 4), wmat("ch5w_sims_wall", 2))
			wbox(root, Vector3(-3, .55, -3.8), Vector3(2.2, .5, 1.6), gloss(Color(.3, .45, .8), .7))
			wbox(root, Vector3(-3, .9, -4.5), Vector3(2.2, .5, .25), gloss(Color(.5, .3, .2), .6))
			wbox(root, Vector3(3.5, 1.1, -4.3), Vector3(1, 2, .9), gloss(Color(.92, .92, .9), .2))
			wbox(root, Vector3(-1, .7, 1.5), Vector3(2.5, .9, 1), gloss(Color(.85, .4, .3), .7))
			var sim := Node3D.new();sim.position = Vector3(0, .2, -.5);root.add_child(sim)
			wbox(sim, Vector3(0, .5, 0), Vector3(.35, .8, .25), gloss(Color(.2, .5, .9), .7))
			wbox(sim, Vector3(0, 1.1, 0), Vector3(.45, .45, .4), gloss(Color(.95, .78, .62), .7))
			wbox(sim, Vector3(0, 1.38, 0), Vector3(.5, .12, .45), gloss(Color(.35, .2, .1), .8))
			var gem := Node3D.new();gem.position = Vector3(0, 2.3, -.5);root.add_child(gem);mark(gem, "spin", 2.0)
			var top := MeshInstance3D.new();var cm := CylinderMesh.new();cm.top_radius = 0;cm.bottom_radius = .28;cm.height = .5;cm.radial_segments = 4;top.mesh = cm;top.position.y = .25;top.material_override = gloss(Color(.2, 1, .25), .1, 2.5);gem.add_child(top)
			var bot := MeshInstance3D.new();bot.mesh = cm;bot.position.y = -.25;bot.rotation.x = PI;bot.material_override = top.material_override;gem.add_child(bot)
			var roof := MeshInstance3D.new();var rm := PrismMesh.new();rm.size = Vector3(11, 2.6, 9);roof.mesh = rm;roof.position = Vector3(0, 6.5, -1);roof.material_override = wmat("ch5w_sims_roof", 2);root.add_child(roof);mark(roof, "hover", .4)
		6:
			var plate: StandardMaterial3D = gloss(Color(.45, .47, .5), .35)
			wbox(root, Vector3(0, -.2, 0), Vector3(16, .4, 16), plate)
			var stud := CylinderMesh.new();stud.top_radius = .22;stud.bottom_radius = .22;stud.height = .18;stud.radial_segments = 10
			for x in range(-7, 8, 2):
				for z in range(-7, 8, 2):mesh_at(root, stud, Vector3(x, .09, z), plate)
			for k in range(4):
				var hgt: float = 4.0 + k * 2.2
				var bx := Vector3(-6 + k * 4, hgt / 2, -5.5)
				wbox(root, bx, Vector3(3, hgt, 3), wmat("ch5w_lego_windows", 3, .3))
				for sx in [-1, 1]:
					for sz in [-1, 1]:mesh_at(root, stud, bx + Vector3(sx * .7, hgt / 2 + .09, sz * .7), gloss(Color(.25, .26, .3), .3))
			var bm := Node3D.new();bm.position = Vector3(0, .6, 2);root.add_child(bm);mark(bm, "drive", .8)
			var black: StandardMaterial3D = gloss(Color(.06, .06, .08), .25)
			wbox(bm, Vector3(0, 0, 0), Vector3(1.6, .5, 3.6), black)
			wbox(bm, Vector3(0, .4, -.3), Vector3(1.0, .4, 1.4), gloss(Color(.15, .25, .35), .05))
			for k in [-1, 1]:
				wbox(bm, Vector3(k * .7, .45, -1.6), Vector3(.12, .7, .6), black)
				for w in [-1.1, 1.1]:tube(bm, Vector3(k * .85, -.15, w), .35, .35, .3, gloss(Color(.1, .1, .1), .8), Vector3(0, 0, PI / 2))
			for sx in [-.4, .4]:
				for sz in [-1.2, 0.6, 1.4]:mesh_at(bm, stud, Vector3(sx, .34, sz), black)
			mesh_at(bm, stud, Vector3(0, .1, 1.82), gloss(Color(1, .9, .4), .1, 4.0), Vector3(PI / 2, 0, 0))
			var beam := tube(root, Vector3(4, 7, -4), 2.2, .2, 9.0, flat(Color(1, .95, .6, .12), 1.0, true), Vector3(.5, 0, -.3))
			var disc := tube(root, Vector3(5.5, 10.5, -6), 1.8, 1.8, .1, gloss(Color(1, .9, .3), .2, 3.0), Vector3(PI / 2 - .2, 0, 0))
			var bat := wbox(root, Vector3(5.5, 10.5, -5.9), Vector3(2.2, .6, .05), flat(Color(.05, .05, .05)), Vector3(-.2, 0, 0))
		7:
			tube(root, Vector3(0, -.6, 0), 8.0, 8.5, 1.2, wmat("ch5w_zuma_stone", 3), Vector3.ZERO, 8)
			var cols: Array = [Color(.95, .15, .1), Color(1, .85, .1), Color(.15, .8, .25), Color(.15, .45, 1), Color(.7, .2, .9)]
			var chain := Node3D.new();root.add_child(chain);mark(chain, "spin", -.15)
			for k in range(46):
				var t: float = k / 46.0
				var ang: float = t * PI * 3.4
				var rad: float = 7.0 - t * 4.6
				ball(chain, Vector3(cos(ang) * rad, .45, sin(ang) * rad), .42, gloss(cols[(k * 7 / 3) % cols.size()], .15))
			ball(root, Vector3(0, .4, 2.4), .8, gloss(Color(1, .8, .2), .2, .8))
			var frog := Node3D.new();frog.position = Vector3(0, .5, 0);root.add_child(frog);mark(frog, "spin", .3)
			var fm: StandardMaterial3D = wmat("ch5w_zuma_frog", 1.0, .4)
			ball(frog, Vector3(0, .6, 0), 1.3, fm, Vector3(1.0, .7, 1.2))
			for k in [-1, 1]:
				ball(frog, Vector3(k * .55, 1.35, .6), .35, gloss(Color(1, .9, .3), .2))
				ball(frog, Vector3(k * .55, 1.42, .88), .14, gloss(Color(.05, .05, .05), .1))
			ball(frog, Vector3(0, .7, 1.5), .42, gloss(cols[1], .15))
			for k in range(8):wbox(root, Vector3(cos(k * .785) * 8.4, 1.0, sin(k * .785) * 8.4), Vector3(.9, 2.2, .9), wmat("ch5w_zuma_stone", 2), Vector3(0, -k * .785, 0))
		8:
			wbox(root, Vector3(0, -.25, 0), Vector3(16, .5, 16), wmat("ch5w_hl2_ground", 2))
			for k in range(5):
				var side: float = -1.0 if k % 2 == 0 else 1.0
				wbox(root, Vector3(side * 5.5, 3.0, -6 + k * 3), Vector3(4, 6 + (k % 2) * 2, 2.8), wmat("ch5w_hl2_panel", 4))
			var cit := tube(root, Vector3(0, 13, -9), 1.2, 2.6, 26.0, wmat("ch5w_hl2_citadel", 4, .4), Vector3(0, 0, .03), 6)
			for k in range(8):ball(root, Vector3(cos(k) * 2.0, 3 + k * 3, -9 + sin(k) * 2.0), .12, gloss(Color(.4, .8, 1), .1, 6.0))
			var strider := Node3D.new();strider.position = Vector3(1, 0, -2);root.add_child(strider);mark(strider, "stride", .7)
			var grey: StandardMaterial3D = gloss(Color(.55, .58, .6), .5)
			ball(strider, Vector3(0, 6.2, 0), 1.0, grey, Vector3(1.4, .6, 1.0))
			ball(strider, Vector3(0, 6.1, .9), .2, gloss(Color(.4, .8, 1), .1, 4.0))
			for k in range(3):
				var ang: float = k * 2.09
				var foot := Vector3(cos(ang) * 2.6, 0, sin(ang) * 2.6)
				var mid: Vector3 = (Vector3(0, 6, 0) + foot) / 2.0
				var leg := tube(strider, mid, .08, .12, Vector3(0, 6, 0).distance_to(foot), grey)
				leg.look_at_from_position(strider.position + mid, strider.position + foot, Vector3.UP);leg.rotate_object_local(Vector3.RIGHT, PI / 2)
		9:
			wbox(root, Vector3(0, -.25, 0), Vector3(16, .5, 16), wmat("ch5w_cnc_sand", 5))
			for k in range(4):ball(root, Vector3(-7 + k * 4.5, -.6, -7 + (k % 2) * 2), 3.0, wmat("ch5w_cnc_sand", 5), Vector3(1.4, .45, 1.0))
			var cc := Node3D.new();cc.position = Vector3(-3.5, 0, -4);root.add_child(cc)
			wbox(cc, Vector3(0, 1.2, 0), Vector3(5, 2.4, 3.6), wmat("ch5w_cnc_concrete", 2))
			wbox(cc, Vector3(0, 2.8, 0), Vector3(3, 1, 2.6), wmat("ch5w_cnc_concrete", 2))
			tube(cc, Vector3(1.6, 3.8, .6), .05, .05, 2.0, gloss(Color(.3, .3, .3), .5))
			var dish: MeshInstance3D = ball(cc, Vector3(-1, 3.6, 0), .7, gloss(Color(.8, .8, .78), .4), Vector3(1, .35, 1));mark(dish, "spin", .5)
			wbox(cc, Vector3(0, .9, 1.85), Vector3(1.6, 1.4, .1), gloss(Color(.15, .15, .14), .7))
			for k in range(3):
				var tank := Node3D.new();tank.position = Vector3(1 + k * 2.2, .35, 1.5 + (k % 2) * 1.6);tank.rotation.y = -.4 + k * .3;root.add_child(tank)
				var camo: StandardMaterial3D = wmat("ch5w_cnc_camo", 1.0, .7)
				wbox(tank, Vector3(0, 0, 0), Vector3(1.3, .45, 2.0), camo)
				for t in [-1, 1]:wbox(tank, Vector3(t * .7, -.1, 0), Vector3(.3, .42, 2.1), gloss(Color(.12, .12, .1), .9))
				ball(tank, Vector3(0, .38, -.1), .45, camo, Vector3(1, .5, 1.2))
				tube(tank, Vector3(0, .42, .9), .07, .07, 1.3, camo, Vector3(PI / 2, 0, 0))
			var heli := Node3D.new();heli.position = Vector3(2, 5, -2);root.add_child(heli);mark(heli, "hover", .7)
			var hm: StandardMaterial3D = gloss(Color(.25, .28, .22), .5)
			ball(heli, Vector3.ZERO, .7, hm, Vector3(.8, .7, 1.6))
			tube(heli, Vector3(0, .1, -1.6), .1, .2, 2.0, hm, Vector3(PI / 2, 0, 0))
			var rotor := Node3D.new();rotor.position = Vector3(0, .65, 0);heli.add_child(rotor);mark(rotor, "spin", 22.0)
			wbox(rotor, Vector3.ZERO, Vector3(4.2, .04, .2), gloss(Color(.1, .1, .1), .6));wbox(rotor, Vector3.ZERO, Vector3(.2, .04, 4.2), gloss(Color(.1, .1, .1), .6))
			var scud := Node3D.new();scud.position = Vector3(5, 0, -5);root.add_child(scud)
			wbox(scud, Vector3(0, .5, 0), Vector3(1.4, .8, 3.4), wmat("ch5w_cnc_camo", 1.0))
			tube(scud, Vector3(0, 1.6, -.2), .25, .3, 3.0, gloss(Color(.8, .8, .75), .4), Vector3(-1.0, 0, 0))
			tube(scud, Vector3(0, 2.4, -1.4), 0, .25, .6, gloss(Color(.8, .2, .1), .4), Vector3(-1.0, 0, 0))
			var flag := wbox(root, Vector3(-6, 3.2, 2), Vector3(1.4, .8, .03), gloss(Color(.15, .3, .7), .7));tube(root, Vector3(-6.7, 2, 2), .04, .04, 4.0, gloss(Color(.7, .7, .7), .3))
		10:
			wbox(root, Vector3(0, -.4, 0), Vector3(17, .8, 10), wmat("ch5w_eu4_wood", 3))
			var map := QuadMesh.new();map.size = Vector2(16, 8);var mm := StandardMaterial3D.new();mm.albedo_texture = tex("ch5w_eu4_map");mm.roughness = .9
			mesh_at(root, map, Vector3(0, .02, 0), mm, Vector3(-PI / 2, 0, 0))
			for k in range(4):tube(root, Vector3((k % 2 * 2 - 1) * 7.8, -3, (k / 2 * 2 - 1) * 4.4), .35, .35, 5.0, wmat("ch5w_eu4_wood", 2))
			var cols: Array = [Color(.8, .2, .18), Color(.22, .35, .7), Color(.9, .78, .3), Color(.35, .6, .28)]
			for k in range(9):
				var piece := Node3D.new();piece.position = Vector3(-6 + fmod(k * 4.3, 12.0), .05, -3 + fmod(k * 2.7, 6.0));root.add_child(piece)
				var c: Color = cols[k % cols.size()]
				tube(piece, Vector3(0, .1, 0), .35, .4, .2, gloss(Color(.75, .6, .3), .3))
				wbox(piece, Vector3(0, .55, 0), Vector3(.25, .7, .2), gloss(c, .5))
				ball(piece, Vector3(0, 1.0, 0), .14, gloss(Color(.95, .8, .65), .6))
				wbox(piece, Vector3(.3, .9, 0), Vector3(.45, .3, .02), gloss(c, .5))
				tube(piece, Vector3(.1, .8, 0), .02, .02, 1.0, gloss(Color(.4, .3, .2), .7))
			for k in range(3):
				var ship := Node3D.new();ship.position = Vector3(-2 + k * 3.5, .1, 2.6 - k * 1.3);root.add_child(ship);mark(ship, "bob", .8)
				wbox(ship, Vector3(0, .1, 0), Vector3(.4, .25, 1.1), gloss(Color(.45, .3, .18), .7))
				tube(ship, Vector3(0, .65, 0), .03, .03, 1.0, gloss(Color(.4, .3, .2), .7))
				wbox(ship, Vector3(0, .7, 0), Vector3(.02, .5, .6), gloss(Color(.95, .93, .85), .8))
			for k in range(2):
				var candle := tube(root, Vector3((k * 2 - 1) * 7.6, .4, -4.2), .15, .15, .8, gloss(Color(.95, .9, .8), .7))
				var fl: MeshInstance3D = ball(root, Vector3((k * 2 - 1) * 7.6, .95, -4.2), .1, gloss(Color(1, .7, .2), .3, 6.0), Vector3(1, 1.6, 1));mark(fl, "flicker", 1.0)
	return root

## Logos of the other games (downloaded from their Steam store pages).
const LOGOS := ["0_gta5", "1_spore", "2_dota2", "3_black_souls", "4_fear_and_hunger", "5_sims", "6_lego_batman_2", "7_zuma", "8_half_life_2", "9_cnc_generals", "10_eu4"]
func logos() -> Array:
	var out: Array = []
	for n in LOGOS:
		var path: String = "res://assets/logos/%s.png" % n
		out.append(load(path) if ResourceLoader.exists(path) else null)
	return out

func build_flight():
	var e := room(Color(0, 0, 0), Color(.6, .6, .7), .7)
	e.glow_enabled = true;e.glow_intensity = .6;e.glow_bloom = 0.0;e.glow_hdr_threshold = 1.2
	var sun := DirectionalLight3D.new();sun.rotation = Vector3(-.5, .4, 0);sun.light_energy = 1.0;scene.add_child(sun);nodes.sun = sun
	rigs.steve = make_rig("ch5_skin_steve")
	var door := Node3D.new();door.position = Vector3(1.0, 0, -6);scene.add_child(door);nodes.door = door
	var leaf := MeshInstance3D.new();var lb := BoxMesh.new();lb.size = Vector3(1.0, 2.0, .12);leaf.mesh = lb;leaf.position = Vector3(-.5, 1.0, 0)
	leaf.material_override = material("ch5q_iron_block", true);door.add_child(leaf)
	var opening := glow_box(door.position + Vector3(-.5, 1.0, -.3), Vector3(1.0, 2.0, .05), Color(1, 1, 1), 8.0);nodes.opening = opening
	var frame := Node3D.new();scene.add_child(frame);nodes.frame = frame
	for bar in [[Vector3(-1.075, 1.1, -.05), Vector3(.15, 2.2, .3)], [Vector3(.075, 1.1, -.05), Vector3(.15, 2.2, .3)], [Vector3(-.5, 2.125, -.05), Vector3(1.3, .15, .3)]]:
		var b := block(door.position + bar[0], bar[1], "ch5q_polished_blackstone_bricks");b.reparent(frame)
	# The door stands in a wall of code-dark stone with a real hole: nothing behind shows until it opens.
	var wall := Node3D.new();scene.add_child(wall);nodes.door_wall = wall
	var cx: float = door.position.x - .5
	for part in [[Vector3(cx - 8.0, 3.0, -6.2), Vector3(15.0, 9, .4)], [Vector3(cx + 8.0, 3.0, -6.2), Vector3(15.0, 9, .4)], [Vector3(cx, 5.1, -6.2), Vector3(1.0, 4.8, .4)]]:
		var b := block(part[0], part[1], "ch5q_deepslate_tiles");b.material_override = material("ch5q_deepslate_tiles", true);b.reparent(wall)
	var hole_mask := glow_box(door.position + Vector3(-.5, 1.0, -.36), Vector3(1.0, 2.0, .04), Color(0, 0, 0), 0.0);nodes.door_hole = hole_mask
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
	for i in range(LOGOS.size()):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(side * (15 + (i % 3) * 4), (i % 3 - 1) * 5.0 - 2.0, -60 - i * 48)
		var d := diorama(i, at, 1.0)
		d.rotation.y = -side * .55;worlds.append(d)
		if marks[i] != null:
			var logo := Sprite3D.new();logo.texture = marks[i];logo.pixel_size = 11.0 / maxf(1, logo.texture.get_width());logo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			logo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;logo.shaded = false;logo.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			logo.position = at + Vector3(0, {3:14.5, 4:14.5, 8:15.0}.get(i, 11.5), 0);scene.add_child(logo);worlds.append(logo)
		omni(at + Vector3(-side * 6, 8, 8), Color(1, .95, .9), 1.6, 30.0)
	nodes.worlds = worlds
	var portal := MeshInstance3D.new();var pm := SphereMesh.new();pm.radius = 6;pm.height = 12;portal.mesh = pm;portal.material_override = flat(Color(1, .95, .85), 8.0)
	portal.position = Vector3(0, 2, -620);scene.add_child(portal);nodes.portal = portal
	build_other()
	var cam := Camera3D.new();cam.far = 900;scene.add_child(cam);nodes.cam = cam

## The world Steve lands in: warm light, a dusty canyon, wooden buildings,
## no blocks anywhere.
func build_other():
	var o := Node3D.new();o.position = Vector3(0, 0, -1500);scene.add_child(o);nodes.other = o;o.visible = false
	# The mill yard is modelled in Blender (scripts/blender_mill_yard.py) and exported as glTF.
	var fort: Node3D = (load("res://assets/models/ch5_mill_yard.glb") as PackedScene).instantiate();o.add_child(fort)
	var stack: Array = [fort]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n
			if mi.name.begins_with("water"):nodes.tf2_water = mi
			for i in range(mi.mesh.get_surface_count()):
				var m: Material = mi.mesh.surface_get_material(i)
				if m is BaseMaterial3D:
					var bm: BaseMaterial3D = m
					bm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
					if bm.resource_name.begins_with("fence") or bm.resource_name.begins_with("sign_happy") or bm.resource_name.begins_with("sign_two"):
						bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;bm.alpha_scissor_threshold = .5;bm.cull_mode = BaseMaterial3D.CULL_DISABLED
					if bm.resource_name.begins_with("sign") or bm.resource_name.begins_with("window") or bm.resource_name.begins_with("watch") or bm.resource_name.begins_with("blu_logo"):
						bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sky := Sky.new();var pano := PanoramaSkyMaterial.new();pano.panorama = tex("ch5w_tf2_sky");sky.sky_material = pano;nodes.tf2_sky = sky
	# Warm lamps inside the halls and the culverts so the openings read as rooms.
	for side in [-1.0, 1.0]:
		for x in [-9.5, 0.0, 9.5]:
			var l := OmniLight3D.new();l.position = Vector3(x, 3.0 if x != 0.0 else 9.0, side * 17.2);l.light_color = Color(1, .8, .55);l.light_energy = 2.2;l.omni_range = 6.0;o.add_child(l)
		var c := OmniLight3D.new();c.position = Vector3(0, -1.0, side * 8.0);c.light_color = Color(1, .8, .55);c.light_energy = 1.6;c.omni_range = 7.0;o.add_child(c)

func sync_flight(f, clock: float):
	var a: float = f.age
	var s: Dictionary = rigs.steve;var cam: Camera3D = nodes.cam;var env: Environment = nodes.env
	var shown: Array = []
	var other: bool = a >= f.FLIGHT_OTHER
	nodes.other.visible = other
	for w in nodes.worlds:w.visible = not other and a >= 5.0
	for r in nodes.rings:r.visible = not other and a >= 5.0
	nodes.portal.visible = not other and a >= 5.0
	for k in range(40):nodes["void%d" % k].visible = a < 5.0
	if a < 5.0:
		var walk: float = clampf(a / 3.2, 0, 1)
		s.root.position = Vector3(.5, 0, -.8 - walk * 4.4);s.root.rotation = Vector3(0, PI, 0)
		var sw: float = sin(a * 7) * .7 if walk < 1 else 0.0
		pose(s, {"rl":Vector3(sw, 0, 0), "ll":Vector3(-sw, 0, 0), "ra":Vector3(-sw * .6 - (1.3 if a > 3.2 else 0.0), 0, 0), "la":Vector3(sw * .6, 0, 0)})
		var open: float = clampf((a - 3.3) / .9, 0, 1)
		nodes.door.rotation = Vector3(0, -open * 1.7, 0);nodes.door.visible = true;nodes.frame.visible = true;nodes.door_wall.visible = true;nodes.door_hole.visible = open <= 0
		nodes.opening.visible = open > 0;nodes.door_light.light_energy = open * 6.0
		for k in range(5):nodes["beam%d" % k].visible = open > 0
		env.background_mode = Environment.BG_COLOR;env.background_color = Color(0, 0, 0)
		for k in range(40):
			var g: Label3D = nodes["void%d" % k];g.position.y = fmod(k * .7 + clock * .3, 5.0)
		if a < 3.0:shot(cam, Vector3(2.4, 1.1, 2.6 - a * .5), Vector3(.5, 1.2, -6.0), 42, 0.0, clock)
		else:shot(cam, Vector3(-1.9, 1.5, -1.2), Vector3(.5, 1.1, -6.2), 44, 0.0, clock)
	elif not other:
		nodes.door.visible = false;nodes.frame.visible = false;nodes.opening.visible = false;nodes.door_light.light_energy = 0;nodes.door_wall.visible = false;nodes.door_hole.visible = false
		for k in range(5):nodes["beam%d" % k].visible = false
		var t: float = a - 5.0
		var z: float = -t * 26.0 - pow(maxf(0, t - 17.0), 2) * 6.0
		var bob: float = sin(clock * 1.7) * .3
		s.root.position = Vector3(0, 2.0 + bob, z);s.root.rotation = Vector3(-1.3, PI, sin(clock * .8) * .1)
		pose(s, {"ra":Vector3(.25, 0, -.2), "la":Vector3(.25, 0, .2), "rl":Vector3(.15 + sin(clock * 2) * .1, 0, 0), "ll":Vector3(-.1, 0, 0), "head":Vector3(-1.1, sin(clock * .5) * .4, 0)})
		env.background_mode = Environment.BG_COLOR;env.fog_enabled = false
		env.background_color = Color(.01, .005, .03).lerp(Color(.07, .02, .12), .5 + .5 * sin(t * .4))
		for k in range(70):
			var st: Node3D = take("star", "")
			var sx: float = fmod(k * 37.7, 44.0) - 22.0;var sy: float = fmod(k * 23.3, 28.0) - 12.0
			st.position = Vector3(sx, sy, z - fmod(k * 13.0 - t * 60.0, 140.0) - 4.0);st.scale = Vector3(1, 1, 1.0 + clampf(t - 15.0, 0, 6.0));shown.append(st)
		animate_worlds(clock)
		if t < 6.0:shot(cam, Vector3(1.6, 3.0, z + 6.0), Vector3(0, 2.2, z - 8), 62, 0.0, clock)
		elif t < 11.0:shot(cam, Vector3(1.1, 2.3, z - 1.2), Vector3(0, 2.4, z - .3), 40, .01, clock)
		elif t < 17.0:shot(cam, Vector3(-6.0, -1.0, z - 14.0), Vector3(0, 2.0, z), 70, 0.0, clock)
		else:shot(cam, Vector3(.8, 2.6, z + 4.0), Vector3(0, 2.0, z - 30), 58 + (t - 17.0) * 3.0, .02 * (t - 17.0) / 5.0, clock)
		if nodes.has("cam_override"):
			for wd in nodes.worlds:wd.visible = true
			shot(cam, nodes.cam_override[0], nodes.cam_override[1], 50, 0.0, clock)
	else:
		var t: float = a - f.FLIGHT_OTHER
		var base: Vector3 = nodes.other.position
		var land: float = clampf(t / .8, 0, 1)
		s.root.position = base + Vector3(9.0, (1 - land) * 3.0, 8.0);s.root.rotation = Vector3(0, PI * .95 + clampf(t - 1.2, 0, 1.2) * .5, 0)
		pose(s, {"drop":-.12 * (1 - clampf(t - .8, 0, .4) / .4), "head":Vector3(-.15 - clampf(t - 1.5, 0, 1.0) * .2, clampf(t - 1.5, 0, 1.0) * .5, 0), "ra":Vector3(.1, 0, -.15), "la":Vector3(.1, 0, .15)})
		env.background_mode = Environment.BG_SKY;env.sky = nodes.tf2_sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color = Color(.55, .64, .8);env.ambient_light_energy = .32
		env.glow_enabled = false;env.tonemap_mode = Environment.TONE_MAPPER_FILMIC;env.tonemap_exposure = .95;env.tonemap_white = 2.2;env.background_energy_multiplier = 1.0
		env.adjustment_enabled = true;env.adjustment_saturation = 1.18;env.adjustment_contrast = 1.05
		env.fog_enabled = true;env.fog_light_color = Color(.72, .8, .9);env.fog_density = .004
		nodes.sun.light_color = Color(1, .9, .76);nodes.sun.light_energy = 1.05;nodes.sun.rotation = Vector3(-.75, .5, 0);nodes.sun.shadow_enabled = true
		nodes.sun.directional_shadow_max_distance = 80.0
		if nodes.has("tf2_water"):(nodes.tf2_water as MeshInstance3D).position.x = sin(clock * .3) * .5
		for k in range(10):
			var dust: Node3D = mcfx("generic", base + Vector3(-6 + fmod(k * 3.7 + clock * .6, 14.0), .4 + fmod(k * .9, 2.5), -2 - fmod(k * 2.3, 8.0)), fmod(clock * .2 + k * .1, 1.0), .15, Color(1, .95, .85, .5))
			shown.append(dust)
		if t < 1.6:shot(cam, base + Vector3(12.0, 2.4, 13.5), base + Vector3(9.0, 1.0, 8.0), 50, .03 * (1 - land), clock)
		else:shot(cam, base + Vector3(13.5 - t * .4, 1.6 + t * .15, 14.5 - t * .3), base + Vector3(-1.0, 5.5, -16.0), 66, 0.0, clock)
		if nodes.has("cam_override"):shot(cam, nodes.cam_override[0], nodes.cam_override[1], 55, 0.0, clock)
	hide_rest(shown)

func animate_worlds(clock: float):
	for w in nodes.worlds:
		if w is Sprite3D:continue
		for c in w.get_children():
			if not c.has_meta("anim"):continue
			var sp: float = c.get_meta("speed");var home: Vector3 = c.get_meta("home")
			match String(c.get_meta("anim")):
				"spin":c.rotation.y = clock * sp
				"bob":c.position = home + Vector3(0, abs(sin(clock * sp * 2.0)) * .3, 0)
				"hover":c.position = home + Vector3(sin(clock * sp) * .8, sin(clock * sp * 1.7) * .4, 0);c.rotation.y = clock * sp
				"drive":c.position = home + Vector3(0, 0, -fmod(clock * sp * 4.0, 12.0) + 6.0)
				"fall":c.position = home + Vector3(sin(clock * sp * 2.0) * .6, -fmod(clock * sp * 2.0, 10.0) + 5.0, 0);c.rotation = Vector3(clock * sp * 3, clock * sp * 2, 0)
				"flicker":c.scale = Vector3(1, 1.5 + sin(clock * 23.0) * .3, 1)
				"stride":c.position = home + Vector3(sin(clock * sp) * 1.5, 0, 0)

## Credits: a slow drift past the other worlds.
func sync_credits(f, clock: float):
	var t: float = f.age
	var s: Dictionary = rigs.steve;s.root.visible = false
	nodes.other.visible = false;nodes.door.visible = false;nodes.frame.visible = false;nodes.opening.visible = false;nodes.door_wall.visible = false;nodes.door_hole.visible = false
	for k in range(5):nodes["beam%d" % k].visible = false
	for k in range(40):nodes["void%d" % k].visible = false
	for w in nodes.worlds:w.visible = true
	animate_worlds(clock)
	for r in nodes.rings:r.visible = false
	nodes.portal.visible = false
	nodes.env.background_mode = Environment.BG_COLOR;nodes.env.fog_enabled = false;nodes.env.adjustment_enabled = false;nodes.env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	nodes.env.background_color = Color(.005, .003, .015);nodes.sun.light_energy = .8;nodes.sun.light_color = Color(.8, .85, 1)
	var z: float = -60.0 - t * 9.0
	var shown: Array = []
	for k in range(50):
		var st: Node3D = take("star", "")
		st.position = Vector3(fmod(k * 37.7, 60.0) - 30.0, fmod(k * 23.3, 34.0) - 14.0, z - fmod(k * 17.0 - t * 6.0, 160.0) - 10.0);st.scale = Vector3.ONE;shown.append(st)
	hide_rest(shown)
	shot(nodes.cam, Vector3(sin(t * .07) * 4.0, 3.0 + sin(t * .11) * 1.5, z), Vector3(sin(t * .05) * 10.0, 1.0, z - 60), 58, 0.0, clock)
