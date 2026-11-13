"""Chapter I prologue v2: garden -> eclipse -> Herobrine -> loss -> sword.
Runs inside Blender (MCP execute_blender_code or --background --python). Saves the .blend; never renders."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix

ROOT = Path('/home/daydert/MinecraftSurvivors2'); SRC = ROOT / 'assets/art_source/ch1_intro_v2'
NAME = 'CH1_Prologue_v2'; FPS = 24; LENGTH = 53.0; FRAMES = int(LENGTH * FPS)
RES = (1280, 720)

# ---------------------------------------------------------------- scene
if NAME in bpy.data.scenes:
    old = bpy.data.scenes[NAME]
    for ob in list(old.objects): bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.scenes.remove(old)
for blk in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights, bpy.data.actions):
    for d in list(blk):
        if d.users == 0: blk.remove(d)
sc = bpy.data.scenes.new(NAME); sc['ch1_owned'] = True
if bpy.context.window: bpy.context.window.scene = sc
sc.render.engine = 'BLENDER_EEVEE'
sc.render.fps = FPS; sc.frame_start = 1; sc.frame_end = FRAMES
sc.render.resolution_x, sc.render.resolution_y = RES; sc.render.resolution_percentage = 100
sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGB'
sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Medium High Contrast'
sc.render.use_motion_blur = True; sc.render.motion_blur_shutter = .42
ee = sc.eevee
for attr, val in [('taa_render_samples', 32), ('use_shadows', True), ('use_volumetric_shadows', True),
                  ('volumetric_tile_size', '4'), ('volumetric_end', 60.0), ('use_raytracing', False),
                  ('shadow_ray_count', 2), ('shadow_step_count', 8), ('use_gtao', True)]:
    try: setattr(ee, attr, val)
    except Exception as e: print('eevee attr', attr, e)

world = bpy.data.worlds.new('CH1v2_World'); sc.world = world; world.use_nodes = True
wn = world.node_tree.nodes; bg = wn['Background']

COL = {}
for nm in ['Set', 'Characters', 'FX', 'Cameras', 'Lights']:
    c = bpy.data.collections.new('CH1v2_' + nm); sc.collection.children.link(c); COL[nm] = c

def link(ob, col='Set'): COL[col].objects.link(ob); return ob

def qrot(x=0, y=0, z=0): return (Matrix.Rotation(z, 3, 'Z') @ Matrix.Rotation(x, 3, 'X') @ Matrix.Rotation(y, 3, 'Y')).to_quaternion()
# ---------------------------------------------------------------- materials
def image(file):
    im = bpy.data.images.load(str(SRC / file), check_existing=True)
    if not im.packed_file: im.pack()
    return im

def material(name, file=None, color=(1, 1, 1, 1), emit=0.0, rough=.9, alpha_clip=True, spec=.15):
    m = bpy.data.materials.new('CH1v2_' + name); m.diffuse_color = color
    try: m.surface_render_method = 'DITHERED'
    except Exception: pass
    m.use_nodes = True; nt = m.node_tree; bs = nt.nodes['Principled BSDF']
    bs.inputs['Base Color'].default_value = color; bs.inputs['Roughness'].default_value = rough
    bs.inputs['Specular IOR Level'].default_value = spec
    if file:
        tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = image(file); tex.interpolation = 'Closest'
        nt.links.new(tex.outputs['Color'], bs.inputs['Base Color'])
        if alpha_clip: nt.links.new(tex.outputs['Alpha'], bs.inputs['Alpha'])
    if emit:
        bs.inputs['Emission Color'].default_value = color; bs.inputs['Emission Strength'].default_value = emit
    return m

def pixel_texture(name, rows, palette):
    h = len(rows); w = len(rows[0]); im = bpy.data.images.new('CH1v2_' + name, w, h, alpha=True)
    px = []
    for y in range(h - 1, -1, -1):
        for ch in rows[y]: px += list(palette.get(ch, (0, 0, 0, 0)))
    im.pixels = px; im.pack(); return im

def image_material(name, im, emit=0.0, rough=.35):
    m = bpy.data.materials.new('CH1v2_' + name)
    try: m.surface_render_method = 'DITHERED'
    except Exception: pass
    m.use_nodes = True; nt = m.node_tree; bs = nt.nodes['Principled BSDF']
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = im; tex.interpolation = 'Closest'
    nt.links.new(tex.outputs['Color'], bs.inputs['Base Color']); nt.links.new(tex.outputs['Alpha'], bs.inputs['Alpha'])
    bs.inputs['Roughness'].default_value = rough
    if emit:
        nt.links.new(tex.outputs['Color'], bs.inputs['Emission Color']); bs.inputs['Emission Strength'].default_value = emit
    return m

TEX = ['steve', 'alex', 'herobrine', 'grass_block_top', 'grass_block_side', 'dirt', 'dirt_path_top', 'farmland_moist',
       'wheat_stage7', 'oak_log', 'oak_log_top', 'oak_leaves', 'oak_planks', 'cobblestone', 'normal', 'iron_sword', 'wheat',
       'short_grass', 'poppy', 'dandelion', 'hay_block_side', 'hay_block_top', 'spruce_log', 'dark_oak_leaves', 'stone',
       'coarse_dirt', 'podzol_top']
MAT = {n: material(n, n + '.png') for n in TEX}
MAT['water'] = material('water', color=(.05, .22, .36, 1), rough=.05, spec=.6)
MAT['eye'] = material('hb_eye', color=(.85, .95, 1, 1), emit=0.0)
MAT['black'] = material('void', color=(.004, .003, .006, 1), rough=1)
MAT['ember'] = material('ember', color=(1, .12, .03, 1), emit=6)
MAT['sun'] = material('sun', color=(1, .82, .55, 1), emit=12)
MAT['corona'] = material('corona', color=(1, .08, .02, 1), emit=0)
MAT['crack'] = material('sky_crack', color=(1, .2, .1, 1), emit=0)
MAT['mobeye_r'] = material('spider_eye', color=(1, .05, .03, 1), emit=0)
MAT['mobeye_p'] = material('ender_eye', color=(.85, .2, 1, 1), emit=0)
MAT['moon'] = material('moon', color=(.85, .9, 1, 1), emit=3)
MAT['glint'] = material('glint', color=(1, 1, 1, 1), emit=25)
MAT['sky'] = material('sky_dome', color=(1, 1, 1, 1))
MAT['tooth'] = material('tooth', color=(.95, .95, .9, 1), emit=.4)
MAT['lid'] = material('lid_skin', color=(.0, .0, .0, 1))
MAT['brow'] = material('brow', color=(.17, .09, .05, 1))

BLOOD_PAL = {'a': (.33, .0, .01, 1), 'b': (.20, .0, .005, 1), 'c': (.48, .02, .02, 1), 'd': (.09, .0, .0, 1)}
blood_im = pixel_texture('blood', ['..a..b....', '.aabbba..c', 'abbcbbbaa.', '.abbdbbcba', 'aabddbbba.', '.cabbdbba.', '..abbbbaa.', '.aa.bab.a.', '..a..a....', '....a.....'], BLOOD_PAL)
wound_im = pixel_texture('wound', ['..aab.a.', '.abbbba.', 'abbddbba', 'abdddbb.', 'abddddba', '.bbddbba', 'aabbbba.', '.a.ab.a.'], BLOOD_PAL)
MAT['blood'] = image_material('blood_splat', blood_im, rough=.45)
MAT['blood'].node_tree.nodes['Principled BSDF'].inputs['Specular IOR Level'].default_value = .25
MAT['wound'] = image_material('wound', wound_im, rough=.2)
MAT['blood_solid'] = material('blood_drop', color=(.30, .0, .01, 1), rough=.38, spec=.3)
MAT['blood_hand'] = material('blood_hand', color=(.09, .0, .003, 1), rough=.25, spec=.4)
MAT['smoke'] = material('aura_smoke', color=(.015, .01, .02, 1), rough=1)
MAT['smoke'].node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value = .85

# Sky dome: vertical gradient driven by animated colors (day blue -> crimson -> night).
sky_nt = MAT['sky'].node_tree; sbs = sky_nt.nodes['Principled BSDF']
sky_emit = sky_nt.nodes.new('ShaderNodeEmission'); sky_out = sky_nt.nodes['Material Output']
geo = sky_nt.nodes.new('ShaderNodeNewGeometry'); sep = sky_nt.nodes.new('ShaderNodeSeparateXYZ')
mapr = sky_nt.nodes.new('ShaderNodeMapRange'); mapr.inputs['From Min'].default_value = -.05; mapr.inputs['From Max'].default_value = .55
mix_sky = sky_nt.nodes.new('ShaderNodeMix'); mix_sky.data_type = 'RGBA'
sky_nt.links.new(geo.outputs['Incoming'], sep.inputs[0])
inv = sky_nt.nodes.new('ShaderNodeMath'); inv.operation = 'MULTIPLY'; inv.inputs[1].default_value = -1
sky_nt.links.new(sep.outputs['Z'], inv.inputs[0]); sky_nt.links.new(inv.outputs[0], mapr.inputs['Value'])
sky_nt.links.new(mapr.outputs['Result'], mix_sky.inputs['Factor'])
sky_nt.links.new(mix_sky.outputs['Result'], sky_emit.inputs['Color'])
sky_nt.links.new(sky_emit.outputs[0], sky_out.inputs['Surface'])
SKY_LOW = mix_sky.inputs[6]; SKY_HIGH = mix_sky.inputs[7]; SKY_STR = sky_emit.inputs['Strength']

# ---------------------------------------------------------------- batched static geometry
class Batch:
    def __init__(self): self.parts = {}
    def box(self, at, size, mat, uv16=True, rot_z=0.0):
        x, y, z = [s / 2 for s in size]; c, s = math.cos(rot_z), math.sin(rot_z)
        vs = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
        vs = [(at[0] + vx * c - vy * s, at[1] + vx * s + vy * c, at[2] + vz) for vx, vy, vz in vs]
        fs = [(0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7), (4, 5, 6, 7), (3, 2, 1, 0)]
        # texel-true UV: one texture tile per world metre
        dims = [(size[0], size[2]), (size[0], size[2]), (size[1], size[2]), (size[1], size[2]), (size[0], size[1]), (size[0], size[1])]
        self._add(mat, vs, fs, [(min(1, w), min(1, h)) for w, h in dims])
    def plane(self, at, w, h, mat, rot_z):
        c, s = math.cos(rot_z), math.sin(rot_z)
        vs = [(at[0] - w / 2 * c, at[1] - w / 2 * s, at[2]), (at[0] + w / 2 * c, at[1] + w / 2 * s, at[2]),
              (at[0] + w / 2 * c, at[1] + w / 2 * s, at[2] + h), (at[0] - w / 2 * c, at[1] - w / 2 * s, at[2] + h)]
        self._add(mat, vs, [(0, 1, 2, 3)], [(1, 1)])
    def _add(self, mat, vs, fs, uvd):
        p = self.parts.setdefault(mat, ([], [], []))
        base = len(p[0]); p[0].extend(vs)
        for f, (w, h) in zip(fs, uvd):
            p[1].append(tuple(base + i for i in f)); p[2].append([(0, 0), (w, 0), (w, h), (0, h)])
    def build(self, name, col='Set'):
        out = []
        for mat, (vs, fs, uvs) in self.parts.items():
            me = bpy.data.meshes.new('CH1v2_' + name + '_' + mat); me.from_pydata(vs, [], fs); me.materials.append(MAT[mat])
            layer = me.uv_layers.new()
            for poly, uv in zip(me.polygons, uvs):
                for li, co in zip(poly.loop_indices, uv): layer.data[li].uv = co
            out.append(link(bpy.data.objects.new(me.name, me), col))
        return out

R = random.Random(111226)
B = Batch()
# Ground: 1 m blocks. Field behind the actors (+Y), grass where they stand, path to the forest gap.
for x in range(-16, 17):
    for y in range(-14, 26):
        field = -4 <= x <= 4 and 2 <= y <= 4
        path = (x in (-1, 0) and 4 < y < 12) or (-3 <= x <= -1 and 0 <= y <= 1 and x == -2)
        top = 'farmland_moist' if field else 'dirt_path_top' if path else ('podzol_top' if y > 9 and R.random() < .5 else 'grass_block_top')
        if top == 'farmland_moist' and x == 0: top = 'water'
        B.box((x, y, -.5 if top != 'water' else -.55), (1, 1, 1), top)
        if field and x != 0:
            for dx, dy in [(-.25, -.22), (.24, .22)]:
                for ang in (math.pi / 4, -math.pi / 4): B.plane((x + dx, y + dy, 0), .7, .75 + R.uniform(-.05, .08), 'wheat_stage7', ang)
        elif not field and not path and R.random() < .28 and not (-3 < x < 2 and -1 < y < 2):
            m = 'short_grass' if R.random() < .82 else R.choice(['poppy', 'dandelion'])
            for ang in (math.pi / 4, -math.pi / 4): B.plane((x + R.uniform(-.3, .3), y + R.uniform(-.3, .3), 0), .6, .55, m, ang)
# Fence around the garden, gap where the path leaves north.
for x in range(-6, 7):
    if x in (-1, 0): continue
    B.box((x, 5.2, .5), (.25, .25, 1), 'oak_planks')
    for h in (.38, .78): B.box((x + .5, 5.2, h), (.75, .12, .18), 'oak_planks')
for y in range(-3, 6):
    for x in (-6.5, 6.5): B.box((x, y, .5), (.25, .25, 1), 'oak_planks')
# Hay and composter props for a lived-in farm.
for p in [(-4.6, .8, .5), (-4.6, 1.8, .5), (-3.6, 1.6, .5), (-4.2, 1.3, 1.5)]: B.box(p, (1, 1, 1), 'hay_block_side')
B.box((5.2, 1.0, .5), (1, 1, 1), 'oak_log')
# Cottage at rear left.
for x in range(-11, -7):
    for y in range(3, 8):
        B.box((x, y, .25), (1, 1, .5), 'cobblestone')
        if x in (-11, -8) or y in (3, 7):
            for z in (1, 2, 3):
                if y == 3 and x == -9 and z < 3: continue
                if y == 3 and x == -10 and z == 2: continue
                B.box((x, y, z - .0), (1, 1, 1), 'oak_log' if x in (-11, -8) else 'oak_planks')
for h in range(4): B.box((-9.5, 5, 3.9 + h * .5), (5.6 - h * 1.3, 6.2, .5), 'spruce_log' if h % 2 else 'oak_planks')
# Forest: dense north, sparse sides; trunks with layered crowns.
def tree(x, y, h, leaves='oak_leaves'):
    B.box((x, y, h / 2), (.7, .7, h), 'oak_log' if leaves == 'oak_leaves' else 'spruce_log')
    for j in range(3):
        s = 3.2 - j * .8
        B.box((x + R.uniform(-.3, .3), y + R.uniform(-.3, .3), h - .4 + j * .9), (s, s, .9), leaves)
for i in range(150):
    x = R.uniform(-16, 16); y = R.uniform(-14, 25)
    if -7.5 < x < 7.5 and -4 < y < 7: continue
    if -12 < x < -6 and 2 < y < 9: continue
    if y < -4 and abs(x) < 9: continue
    if abs(x + .5) < 1.6 and 6 < y < 11: continue
    tree(x, y, R.uniform(4, 7.5), 'dark_oak_leaves' if y > 9 else 'oak_leaves')
static = B.build('set')
# Sky dome and sun / eclipse.
bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=120)
dome = bpy.context.active_object; dome.name = 'CH1v2_SkyDome'
for c in dome.users_collection: c.objects.unlink(dome)
link(dome); dome.data.materials.append(MAT['sky'])
for p in dome.data.polygons: p.use_smooth = True
dome.visible_shadow = False
SUN_DIR = Vector((-.25, 1, .62)).normalized(); SUN_POS = SUN_DIR * 95

def disc(name, radius, mat, at, col='FX', segs=40, inner=0.0):
    vs = []; fs = []
    for i in range(segs):
        a = i / segs * math.tau
        vs.append((math.cos(a) * radius, 0, math.sin(a) * radius))
        if inner: vs.append((math.cos(a) * inner, 0, math.sin(a) * inner))
    if inner:
        for i in range(segs):
            j = (i + 1) % segs; fs.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
    else: fs = [tuple(range(segs))]
    me = bpy.data.meshes.new('CH1v2_' + name); me.from_pydata(vs, [], fs); me.materials.append(MAT[mat])
    ob = link(bpy.data.objects.new(me.name, me), col); ob.location = at
    ob.rotation_euler = (-SUN_DIR).to_track_quat('Y', 'Z').to_euler(); ob.visible_shadow = False
    return ob
sun_disc = disc('SunDisc', 5.5, 'sun', SUN_POS)
moon_disc = disc('EclipseDisc', 5.7, 'black', SUN_POS - SUN_DIR * 2)
corona = disc('Corona', 11, 'corona', SUN_POS + SUN_DIR * 1, inner=5.6)
cracks = []
for i in range(9):
    me = bpy.data.meshes.new('CH1v2_crack'); a = i / 9 * math.tau + R.uniform(-.2, .2)
    pts = [Vector((0, 0, 0))]
    for k in range(5): pts.append(pts[-1] + Vector((math.cos(a + R.uniform(-.5, .5)), 0, math.sin(a + R.uniform(-.5, .5)))) * R.uniform(3, 6))
    vs = []; fs = []
    for k, p in enumerate(pts):
        w = .45 * (1 - k / 6); vs += [p + Vector((0, 0, w)), p - Vector((0, 0, w))]
        if k: fs.append((2 * k - 2, 2 * k - 1, 2 * k + 1, 2 * k))
    me.from_pydata([tuple(v) for v in vs], [], fs); me.materials.append(MAT['crack'])
    ob = link(bpy.data.objects.new(me.name, me), 'FX'); ob.location = SUN_POS + SUN_DIR * 1.5
    ob.rotation_euler = (-SUN_DIR).to_track_quat('Y', 'Z').to_euler(); ob.visible_shadow = False; cracks.append(ob)
# Atmosphere: low fog volume, density animated with darkness.
bpy.ops.mesh.primitive_cube_add(size=1)
fog = bpy.context.active_object; fog.name = 'CH1v2_Fog'
for c in fog.users_collection: c.objects.unlink(fog)
link(fog, 'FX'); fog.scale = (60, 60, 14); fog.location = (0, 6, 6)
fmat = bpy.data.materials.new('CH1v2_fog'); fmat.use_nodes = True; fnt = fmat.node_tree
fnt.nodes.remove(fnt.nodes['Principled BSDF'])
vol = fnt.nodes.new('ShaderNodeVolumePrincipled'); fnt.links.new(vol.outputs[0], fnt.nodes['Material Output'].inputs['Volume'])
vol.inputs['Density'].default_value = .006; vol.inputs['Color'].default_value = (.8, .85, 1, 1)
fog.data.materials.append(fmat); FOG_DENS = vol.inputs['Density']; FOG_COL = vol.inputs['Color']

# ---------------------------------------------------------------- character rigs
def empty(name, at=(0, 0, 0), parent=None, col='Characters'):
    ob = link(bpy.data.objects.new('CH1v2_' + name, None), col); ob.parent = parent; ob.location = at
    ob.rotation_mode = 'QUATERNION'; ob.empty_display_size = .08; return ob

def skin_box(name, at, size, mat, parent, uv, start=0, pixels=None, grow=0.0, col='Characters', extend_top=0.0):
    """Minecraft skin cube. extend_top lengthens a lower limb segment upward to hide the bend gap."""
    x, y, z = [s / 2 + grow for s in size]
    vs = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z + extend_top), (x, -y, z + extend_top), (x, y, z + extend_top), (-x, y, z + extend_top)]
    fs = [(0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7), (4, 5, 6, 7), (3, 2, 1, 0)]
    me = bpy.data.meshes.new('CH1v2_' + name); me.from_pydata(vs, [], fs); me.materials.append(mat); layer = me.uv_layers.new()
    u, v, w, h, d = uv; cnt = pixels if pixels is not None else h
    rects = [(u + d, v + d + start, w, cnt), (u + 2 * d + w, v + d + start, w, cnt), (u + d + w, v + d + start, d, cnt), (u, v + d + start, d, cnt), (u + d, v, w, d), (u + d + w, v, w, d)]
    for f, (uu, vv, ww, hh) in zip(me.polygons, rects):
        # right/left faces of limbs swap with the actual side; vanilla cube layout handles it.
        for li, (s, t) in zip(f.loop_indices, [(uu, vv + hh), (uu + ww, vv + hh), (uu + ww, vv), (uu, vv)]): layer.data[li].uv = (s / 64, 1 - t / 64)
    ob = link(bpy.data.objects.new(me.name, me), col); ob.parent = parent; ob.location = at; return ob

def plain_box(name, at, size, mat, parent, col='Characters'):
    x, y, z = [s / 2 for s in size]
    vs = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
    fs = [(0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7), (4, 5, 6, 7), (3, 2, 1, 0)]
    me = bpy.data.meshes.new('CH1v2_' + name); me.from_pydata(vs, [], fs); me.materials.append(mat)
    uv = me.uv_layers.new()
    for f in me.polygons:
        for li, co in zip(f.loop_indices, [(0, 0), (1, 0), (1, 1), (0, 1)]): uv.data[li].uv = co
    ob = link(bpy.data.objects.new(me.name, me), col); ob.parent = parent; ob.location = at; return ob

def rig(name, skin, slim=False):
    n = {}
    n['root'] = empty(name + '_Root'); n['hips'] = empty(name + '_Hips', (0, 0, .75), n['root'])
    n['torso'] = empty(name + '_Torso', (0, 0, 0), n['hips']); n['head'] = empty(name + '_Head', (0, 0, .75), n['torso'])
    skin_box(name + '_body', (0, 0, .375), (.5, .25, .75), skin, n['torso'], (16, 16, 8, 12, 4))
    skin_box(name + '_jacket', (0, 0, .375), (.5, .25, .75), skin, n['torso'], (16, 32, 8, 12, 4), grow=.016)
    skin_box(name + '_head', (0, 0, .25), (.5, .5, .5), skin, n['head'], (0, 0, 8, 8, 8))
    skin_box(name + '_hat', (0, 0, .25), (.5, .5, .5), skin, n['head'], (32, 0, 8, 8, 8), grow=.03)
    for side, sgn in (('R', -1), ('L', 1)):
        w = 3 if slim else 4; ax = sgn * (.25 + w / 32)
        n[side + 'arm'] = empty(name + '_' + side + 'Shoulder', (ax, 0, .625), n['torso'])
        n[side + 'elbow'] = empty(name + '_' + side + 'Elbow', (0, 0, -.3125), n[side + 'arm'])
        n[side + 'wrist'] = empty(name + '_' + side + 'Wrist', (0, 0, -.3125), n[side + 'elbow'])
        auv = (40, 16, w, 12, 4) if side == 'R' else (32, 48, w, 12, 4)
        suv = (40, 32, w, 12, 4) if side == 'R' else (48, 48, w, 12, 4)
        # upper arm includes the shoulder cap (vanilla arm pivot sits 2px below the top)
        skin_box(name + '_' + side + 'upper', (0, 0, -.125), (w / 16, .25, .4375), skin, n[side + 'arm'], auv, 0, 6)
        skin_box(name + '_' + side + 'upperS', (0, 0, -.125), (w / 16, .25, .4375), skin, n[side + 'arm'], suv, 0, 6, grow=.014)
        skin_box(name + '_' + side + 'lower', (0, 0, -.1875 - .0), (w / 16, .25, .375), skin, n[side + 'elbow'], auv, 6, 6, extend_top=.07)
        skin_box(name + '_' + side + 'lowerS', (0, 0, -.1875), (w / 16, .25, .375), skin, n[side + 'elbow'], suv, 6, 6, grow=.014, extend_top=.07)
        n[side + 'leg'] = empty(name + '_' + side + 'Hip', (sgn * .125, 0, 0), n['hips'])
        n[side + 'knee'] = empty(name + '_' + side + 'Knee', (0, 0, -.375), n[side + 'leg'])
        luv = (0, 16, 4, 12, 4) if side == 'R' else (16, 48, 4, 12, 4)
        lsv = (0, 32, 4, 12, 4) if side == 'R' else (0, 48, 4, 12, 4)
        skin_box(name + '_' + side + 'thigh', (0, 0, -.1875), (.25, .25, .375), skin, n[side + 'leg'], luv, 0, 6)
        skin_box(name + '_' + side + 'shin', (0, 0, -.1875), (.25, .25, .375), skin, n[side + 'knee'], luv, 6, 6, extend_top=.07)
        skin_box(name + '_' + side + 'pants', (0, 0, -.1875), (.25, .25, .375), skin, n[side + 'leg'], lsv, 0, 6, grow=.012)
    return n

S = rig('Steve', MAT['steve']); A = rig('Alex', MAT['alex'], True); H = rig('Herobrine', MAT['herobrine'])
# Herobrine face: glowing eye planes + a pixel grin with teeth that appears for the invitation.
hb_eyes = [plain_box('HB_eye', (x, -.258, .21875), (.125, .006, .0625), MAT['eye'], H['head']) for x in (-.125, .125)]
grin = []
for i, x in enumerate([-.1875, -.125, -.0625, 0, .0625, .125, .1875]):
    zz = .094 + (.0 if abs(x) < .15 else .03125)
    grin.append(plain_box('HB_grin', (x, -.259, zz), (.0625, .006, .03125), MAT['black'], H['head']))
    if 0 < i < 6 and i % 2 == 1: grin.append(plain_box('HB_tooth', (x, -.262, zz + .002), (.05, .004, .025), MAT['tooth'], H['head']))
# Steve: angry brows and blinking lids; Alex: closed eyes after death.
s_brows = [plain_box('S_brow', (sg * .14, -.258, .31), (.14, .006, .035), MAT['brow'], S['head']) for sg in (-1, 1)]
a_lids = [plain_box('A_lid', (x, -.257, .21875), (.125, .006, .0625), MAT['alex'], A['head']) for x in (-.125, .125)]
s_lids = [plain_box('S_lid', (x, -.257, .21875), (.125, .006, .0625), MAT['steve'], S['head']) for x in (-.125, .125)]
for ob in a_lids:
    ob.data.materials[0] = material('alex_lid', color=(.80, .55, .38, 1))
for ob in s_lids:
    ob.data.materials[0] = material('steve_lid', color=(.62, .42, .30, 1))
# Wound decals and blood on actors.
a_wound_front = plain_box('A_wound_f', (.02, -.131, .45), (.2, .004, .2), MAT['wound'], A['torso'], 'FX')
a_wound_back = plain_box('A_wound_b', (.02, .131, .45), (.2, .004, .2), MAT['wound'], A['torso'], 'FX')
a_stain = plain_box('A_stain', (.02, -.1335, .33), (.34, .004, .44), MAT['blood'], A['torso'], 'FX')
a_mouth = plain_box('A_mouthblood', (.02, -.2565, .07), (.0625, .004, .14), MAT['blood_solid'], A['head'], 'FX')
hb_blood = [plain_box('HB_bloodarm', (0, 0, -.22), (.27, .27, .26), MAT['blood_hand'], H['Relbow'], 'FX')]
s_splat = [plain_box('S_splat', (x, -.2565, z), (.045, .004, .045), MAT['blood_solid'], S['head'], 'FX') for x, z in [(-.12, .2), (.05, .1), (.16, .28), (-.02, .33), (.1, .05)]]
s_hands_blood = [plain_box('S_handblood', (0, 0, -.33), (.27, .27, .1), MAT['blood_hand'], S[k], 'FX') for k in ('Lelbow', 'Relbow')]

# Props: chest with hinged lid, iron sword (voxel extrusion), wheat bundle item.
chest = empty('Chest', (-2.6, 1.15, 0), col='Set')
chest_body = skin_box('chest_body', (0, 0, .3), (.875, .875, .625), MAT['normal'], chest, (0, 19, 14, 10, 14))
# hollow: drop the top face, add inner walls and a dark floor so the hand really goes inside
import bmesh
_bm = bmesh.new(); _bm.from_mesh(chest_body.data); _bm.faces.ensure_lookup_table()
bmesh.ops.delete(_bm, geom=[f for f in _bm.faces if f.normal.z > .9], context='FACES'); _bm.to_mesh(chest_body.data); _bm.free()
_inner = material('chest_inner', color=(.10, .06, .035, 1))
_rim = material('chest_rim', color=(.36, .22, .1, 1))
for _at, _sz in [((0, -.40, .3), (.8, .06, .6)), ((0, .40, .3), (.8, .06, .6)), ((-.40, 0, .3), (.06, .8, .6)), ((.40, 0, .3), (.06, .8, .6))]:
    plain_box('chest_wall', _at, _sz, _inner, chest, 'Set')
plain_box('chest_floor', (0, 0, .1), (.8, .8, .04), _inner, chest, 'Set')
for _at, _sz in [((0, -.405, .6), (.875, .065, .05)), ((0, .405, .6), (.875, .065, .05)), ((-.405, 0, .6), (.065, .875, .05)), ((.405, 0, .6), (.065, .875, .05))]:
    plain_box('chest_rim', _at, _sz, _rim, chest, 'Set')
lid = empty('Chest_lid', (0, .4375, .625), chest, 'Set')
skin_box('chest_lid', (0, -.4375, .1), (.875, .875, .3125), MAT['normal'], lid, (0, 0, 14, 5, 14))
plain_box('chest_latch', (0, -.89, .02), (.125, .06, .25), material('latch', color=(.55, .55, .58, 1), rough=.3, spec=.6), lid, 'Set')

def voxel_item(name, file, parent, grip, scale=.05, col='FX'):
    """Extruded 16x16 item. grip=(px,py) is placed at the parent origin; blade goes along local -Z->+Z diag."""
    root = empty(name, parent=parent, col=col)
    im = bpy.data.images.load(str(SRC / file), check_existing=True); W = im.size[0]; pix = list(im.pixels)
    bat = {}
    for y in range(W):
        for x in range(W):
            i = ((W - 1 - y) * W + x) * 4
            if pix[i + 3] > .5:
                rgba = tuple(round(((c + .055) / 1.055) ** 2.4 if c > .04045 else c / 12.92, 3) for c in pix[i:i + 3]) + (1.0,); bat.setdefault(rgba, []).append((x, y))
    vs = []; fs = []; mats = []; matidx = []
    me = bpy.data.meshes.new('CH1v2_' + name)
    for k, (rgba, cells) in enumerate(bat.items()):
        mats.append(material(name + '_px', color=rgba, rough=.25 if 'sword' in file else .8, spec=.7 if 'sword' in file else .1))
        for x, y in cells:
            px = (x - grip[0]) * scale; py = (grip[1] - y) * scale
            xx = (px - py) / math.sqrt(2); zz = (px + py) / math.sqrt(2)
            h = scale / 2; d = scale * .65
            base = len(vs)
            for dx, dy, dz in [(-h, -d, -h), (h, -d, -h), (h, d, -h), (-h, d, -h), (-h, -d, h), (h, -d, h), (h, d, h), (-h, d, h)]:
                # rotate the cell square by 45 degrees in XZ so pixels stay aligned to the blade
                rx = (dx - dz) / math.sqrt(2); rz = (dx + dz) / math.sqrt(2)
                vs.append((xx + rx, dy, zz + rz))
            for f in [(0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7), (4, 5, 6, 7), (3, 2, 1, 0)]:
                fs.append(tuple(base + i for i in f)); matidx.append(k)
    me.from_pydata(vs, [], fs)
    for m in mats: me.materials.append(m)
    for p, k in zip(me.polygons, matidx): p.material_index = k
    ob = link(bpy.data.objects.new(me.name, me), col); ob.parent = root
    return root

sword = voxel_item('Sword', 'iron_sword.png', S['Rwrist'], (3, 13), .046)
sword.rotation_quaternion = qrot(math.pi / 2)
sword_glint = plain_box('Sword_glint', (0, 0, .62), (.02, .02, .02), MAT['glint'], sword, 'FX')
wheat_item = voxel_item('WheatBundle', 'wheat.png', None, (8, 8), .024)

# ---------------------------------------------------------------- particles (pooled cubes)
def pool(name, count, mat, size):
    return [plain_box(name, (0, 0, -50), (size, size, size), MAT[mat], None, 'FX') for _ in range(count)]
P_blood = pool('blood_drop', 260, 'blood_solid', .05)
P_drip = pool('blood_drip', 44, 'blood_solid', .035)
P_smoke = pool('aura', 70, 'smoke', .12)
P_ember = pool('ember', 36, 'ember', .03)
P_dust = pool('vanish', 90, 'smoke', .09)
P_ash = pool('ash', 60, 'smoke', .025)
blood_pool = plain_box('blood_pool', (0, 0, -50), (1.4, 1.4, .004), MAT['blood'], None, 'FX')
splats = [plain_box('blood_splat', (0, 0, -50), (.38, .38, .004), MAT['blood'], None, 'FX') for _ in range(20)]
for ob in P_smoke + P_dust + P_ash + P_ember + P_blood + P_drip + splats + [blood_pool]: ob.rotation_mode = 'XYZ'
for ob in P_ember: ob.visible_shadow = False
# Mob eyes in the forest for the final shot.
mob_eyes = []
for i, (x, y, z, kind) in enumerate([(-3.5, 11, .5, 'r'), (2.2, 12.5, .45, 'r'), (4.5, 10.5, .5, 'r'), (-1.8, 14, 2.7, 'p'), (1.2, 15.5, 2.8, 'p'), (-6, 12, .45, 'r'), (6.5, 13.5, .5, 'r')]):
    m = MAT['mobeye_r'] if kind == 'r' else MAT['mobeye_p']
    gap = .18 if kind == 'r' else .22
    for sx in (-1, 1):
        ob = plain_box('mob_eye', (x + sx * gap / 2, y, z), (.07 if kind == 'r' else .13, .02, .05), m, None, 'FX')
        ob.visible_shadow = False; mob_eyes.append((ob, i))

# ---------------------------------------------------------------- lights
def light(name, typ, energy, color, at=(0, 0, 5), size=1.0):
    d = bpy.data.lights.new('LGT_CH1v2_' + name, typ); d.energy = energy; d.color = color
    if typ == 'AREA': d.shape = 'DISK'; d.size = size
    if typ in ('POINT', 'SPOT'): d.shadow_soft_size = size
    ob = link(bpy.data.objects.new(d.name, d), 'Lights'); ob.location = at; return ob
sun = light('Sun', 'SUN', 4.5, (1, .78, .5)); sun.rotation_euler = (-SUN_DIR).to_track_quat('-Z', 'Y').to_euler(); sun.data.angle = .03
moon = light('Moon', 'SUN', 0.0, (.45, .6, 1)); moon.rotation_euler = Vector((.3, -1, -.7)).to_track_quat('-Z', 'Y').to_euler()
hb_light = light('HB_red', 'POINT', 0.0, (1, .05, .02), size=.3)
eye_light = light('HB_eye', 'POINT', 0.0, (.75, .9, 1), size=.05)
key = light('Key', 'AREA', 0.0, (1, .9, .8), size=2)
rim = light('Rim', 'AREA', 0.0, (.5, .65, 1), size=3)
glint_light = light('Glint', 'POINT', 0.0, (1, 1, 1), size=.05)

# ---------------------------------------------------------------- recorder -> fcurves (fast)
REC = {}
def rec(idb, path, values, frame):
    for i, v in enumerate(values if hasattr(values, '__len__') else [values]):
        REC.setdefault((idb, path, i), []).append((frame, float(v)))

def flush():
    for (idb, path, idx), keys in REC.items():
        ad = idb.animation_data or idb.animation_data_create()
        if ad.action is None:
            act = bpy.data.actions.new('AN_CH1v2_' + idb.name); ad.action = act
            if hasattr(ad, 'action_slot') and ad.action_slot is None and len(act.slots): ad.action_slot = act.slots[0]
        fc = ad.action.fcurve_ensure_for_datablock(idb, path, index=idx)
        # drop interior keys of constant runs
        slim = [keys[0]]
        for j in range(1, len(keys) - 1):
            if not (abs(keys[j][1] - keys[j - 1][1]) < 1e-6 and abs(keys[j][1] - keys[j + 1][1]) < 1e-6): slim.append(keys[j])
        if len(keys) > 1: slim.append(keys[-1])
        fc.keyframe_points.add(len(slim))
        flat = [c for k in slim for c in k]
        fc.keyframe_points.foreach_set('co', flat)
        fc.keyframe_points.foreach_set('interpolation', [bpy.types.Keyframe.bl_rna.properties['interpolation'].enum_items['LINEAR'].value] * len(slim))
        fc.update()

# ---------------------------------------------------------------- math helpers
def clamp(x, a=0.0, b=1.0): return max(a, min(b, x))
def sm(a, b, t): x = clamp((t - a) / (b - a)); return x * x * (3 - 2 * x)
def eo(a, b, t): x = clamp((t - a) / (b - a)); return 1 - (1 - x) ** 3
def ei(a, b, t): x = clamp((t - a) / (b - a)); return x ** 3
def back(a, b, t, s=1.6):
    x = clamp((t - a) / (b - a)); x -= 1; return x * x * ((s + 1) * x + s) + 1
def mix(a, b, k): return a + (b - a) * k
def V(*a): return Vector(a if len(a) == 3 else (a[0], a[1], 0))
def lerp(a, b, k): return Vector(a).lerp(Vector(b), k)

def K(t, keys):
    """Auto-clamped cubic through (time, value) keys; values are floats or tuples. Flat tangent at extremes."""
    vec = isinstance(keys[0][1], tuple)
    if t <= keys[0][0]: v = keys[0][1]; return Vector(v) if vec else v
    if t >= keys[-1][0]: v = keys[-1][1]; return Vector(v) if vec else v
    ts = [k[0] for k in keys]; vs = [list(k[1]) if vec else [k[1]] for k in keys]; n = len(vs[0])
    i = max(j for j in range(len(ts) - 1) if ts[j] <= t)
    def tan(j):
        if j == 0 or j == len(ts) - 1: return [0.0] * n
        out = []
        for c in range(n):
            d0 = (vs[j][c] - vs[j - 1][c]) / (ts[j] - ts[j - 1]); d1 = (vs[j + 1][c] - vs[j][c]) / (ts[j + 1] - ts[j])
            out.append(2 * d0 * d1 / (d0 + d1) if d0 * d1 > 0 else 0.0)
        return out
    h = ts[i + 1] - ts[i]; u = (t - ts[i]) / h
    h00 = 2 * u ** 3 - 3 * u ** 2 + 1; h10 = u ** 3 - 2 * u ** 2 + u; h01 = -2 * u ** 3 + 3 * u ** 2; h11 = u ** 3 - u ** 2
    m0 = tan(i); m1 = tan(i + 1)
    r = [vs[i][c] * h00 + m0[c] * h10 * h + vs[i + 1][c] * h01 + m1[c] * h11 * h for c in range(n)]
    return Vector(r) if vec else r[0]

def qrot(x=0, y=0, z=0): return (Matrix.Rotation(z, 3, 'Z') @ Matrix.Rotation(x, 3, 'X') @ Matrix.Rotation(y, 3, 'Y')).to_quaternion()
def rot(ob, x=0, y=0, z=0): ob.rotation_quaternion = qrot(x, y, z)
def addrot(ob, x=0, y=0, z=0): ob.rotation_quaternion = ob.rotation_quaternion @ qrot(x, y, z)
def wm(ob):
    local = Matrix.Translation(ob.location) @ ob.rotation_quaternion.to_matrix().to_4x4() @ Matrix.Diagonal((*ob.scale, 1))
    return wm(ob.parent) @ local if ob.parent else local
def fwd(yaw): return Vector((math.sin(yaw), -math.cos(yaw), 0))
def right(yaw): return Vector((-math.cos(yaw), -math.sin(yaw), 0))
def yaw_to(a, b): d = Vector(b) - Vector(a); return math.atan2(d.x, -d.y)

def reset(n, pos, yaw=0.0, hip=.75):
    for ob in n.values(): ob.rotation_quaternion = Quaternion();
    n['root'].location = Vector(pos); n['root'].scale = (1, 1, 1); rot(n['root'], z=yaw); n['hips'].location = (0, 0, hip)

def ik(n, side, arm, target, pole):
    top = n[side + ('arm' if arm else 'leg')]; low = n[side + ('elbow' if arm else 'knee')]
    base = (wm(top.parent) @ top.location); vec = Vector(target) - base; L1 = .3125 if arm else .375; L2 = .3125 if arm else .375
    dist = max(.02, min(L1 + L2 - .002, vec.length)); d = vec.normalized(); pv = Vector(pole) - base; perp = pv - d * pv.dot(d)
    if perp.length < 1e-5: perp = Vector((1, 0, 0)).cross(d)
    perp.normalize(); along = (L1 * L1 - L2 * L2 + dist * dist) / (2 * dist); mid = d * along + perp * math.sqrt(max(0, L1 * L1 - along * along))
    wtop = Vector((0, 0, -1)).rotation_difference(mid.normalized())
    # keep the limb's twist aligned with the parent so skins do not spin
    parent_q = wm(top.parent).to_quaternion()
    top.rotation_quaternion = parent_q.inverted() @ wtop
    wlow = Vector((0, 0, -1)).rotation_difference((d * dist - mid).normalized())
    low.rotation_quaternion = wtop.inverted() @ wlow

def foot(n, side, p, yaw):
    """Leg IK: knee pole points forward of the character."""
    ik(n, side, False, p, Vector(p) + fwd(yaw) * 1.0 + Vector((0, 0, .5)))

def hand(n, side, p, pole=None):
    sh = wm(n[side + 'arm']).translation; yaw = n['root'].rotation_quaternion.to_euler().z
    if pole is None: pole = sh + right(yaw) * (.6 if side == 'R' else -.6) + Vector((0, 0, -.5)) - fwd(yaw) * .4
    ik(n, side, True, p, pole)

def stand(n, yaw, spread=.13, shift=(0, 0)):
    r = n['root'].location; rt = right(yaw)
    for side, sg in (('R', 1), ('L', -1)):
        foot(n, side, r + rt * (sg * spread) + fwd(yaw) * shift[0 if side == 'R' else 1] + Vector((0, 0, .02)), yaw)

def look(n, point, limit=1.2, amount=1.0):
    p = wm(n['torso']).inverted() @ Vector(point) - Vector((0, 0, 1.0))
    yaw = clamp(math.atan2(p.x, -p.y), -limit, limit); pitch = clamp(math.atan2(-p.z, math.hypot(p.x, p.y)), -.7, .8)
    rot(n['head'], pitch * amount, 0, yaw * amount)

def locomote(n, t, t0, t1, p0, p1, yaw, stride=.62, run=False, ease_in=True, ease_out=True):
    """Distance-driven walk/run with planted feet. Returns body progress 0..1."""
    D = (Vector(p1) - Vector(p0)).length
    x = clamp((t - t0) / (t1 - t0))
    if ease_in and ease_out: u = x * x * (3 - 2 * x)
    elif ease_in: u = x * x * (2 - x)
    elif ease_out: u = x + x * x - x ** 3
    else: u = x
    s = D * u; base = Vector(p0).lerp(Vector(p1), u); dirv = (Vector(p1) - Vector(p0)).normalized() if D > 1e-6 else fwd(yaw)
    stance = .55 if run else 1.25; L = stride
    reset(n, base, yaw, .74)
    feet = []; swing_amt = []
    for side, sg, off in (('R', 1, 0.0), ('L', -1, L)):
        ph = (s + L * .6 - off) / (2 * L); k = math.floor(ph); fr = ph - k
        P = off + 2 * L * k  # plant centre along path
        lat = right(yaw) * (sg * .125)
        st_half = stance * L / 2
        land = P - st_half; lift = P + st_half
        if s < lift and s >= land - 1e-9 or fr * 2 * L < 0:
            pos = Vector(p0) + dirv * clamp(P, 0, D + L) + lat; sw = 0
        else:
            nxt = P + 2 * L; a = lift; b = nxt - st_half
            w = clamp((s - a) / max(1e-6, b - a))
            pos = Vector(p0) + dirv * mix(clamp(P, -L, D + L), clamp(nxt, -L, D + L), sm(0, 1, w)) + lat
            pos.z += math.sin(math.pi * w) * (.22 if run else .12); sw = math.sin(math.pi * w)
        if u >= 1:  # settle: both feet beside the body
            settle = sm(t1, t1 + .3, t); tgt = base + lat
            pos = pos.lerp(tgt, settle); pos.z = max(0, pos.z * (1 - settle))
        pos.z += .02; feet.append((side, pos)); swing_amt.append(sw)
    # body bob, lean, arm swing opposite legs
    rel = [(p - base).dot(dirv) for _, p in feet]
    moving = sm(t0, t0 + .25, t) * (1 - sm(t1 - .2, t1 + .1, t))
    bob = (abs(rel[0] - rel[1]) / (2 * L)) * moving
    n['hips'].location.z = (.70 if run else .735) - bob * (.06 if run else .03) + (.025 if run else 0) * moving
    rot(n['hips'], 0, 0, (rel[0] - rel[1]) * .35 * moving)
    rot(n['torso'], (.32 if run else .05) * moving, 0, -(rel[0] - rel[1]) * .55 * moving)
    for side, p in feet: foot(n, side, p, yaw)
    swing = (rel[0] - rel[1]) / L * moving
    rot(n['Rarm'], swing * (.9 if run else .45), 0, .05); rot(n['Larm'], -swing * (.9 if run else .45), 0, -.05)
    rot(n['Relbow'], -(1.2 if run else .25) * moving - .05); rot(n['Lelbow'], -(1.2 if run else .25) * moving - .05)
    return u

class Path2:
    """Polyline with arc-length lookup; directions are smoothed over a window so turns are gradual."""
    def __init__(self, pts):
        self.p = [Vector(x) for x in pts]; self.c = [0.0]
        for a, b in zip(self.p, self.p[1:]): self.c.append(self.c[-1] + (b - a).length)
        self.L = self.c[-1]
    def at(self, s):
        s = clamp(s, 0, self.L)
        for i in range(len(self.p) - 1):
            if s <= self.c[i + 1] or i == len(self.p) - 2:
                k = (s - self.c[i]) / max(1e-6, self.c[i + 1] - self.c[i]); return self.p[i].lerp(self.p[i + 1], clamp(k))
    def dir(self, s, win=.45):
        d = self.at(s + win) - self.at(s - win)
        return d.normalized() if d.length > 1e-6 else Vector((0, 1, 0))

def locomote_path(n, t, t0, t1, path, stride=.62, start_yaw=None):
    """Walk along a polyline with planted feet; body yaw follows the smoothed path direction."""
    x = clamp((t - t0) / (t1 - t0)); u = x * x * (2 - x) if x < 1 else 1
    D = path.L; s = D * u; L = stride; stance = 1.25
    base = path.at(s); dv = path.dir(s); yaw = math.atan2(dv.x, -dv.y)
    if start_yaw is not None:
        d = (yaw - start_yaw + math.pi) % math.tau - math.pi; yaw = start_yaw + d * sm(t0, t0 + .7, t)
    reset(n, base, yaw, .74)
    feet = []
    for side, sg, off in (('R', 1, 0.0), ('L', -1, L)):
        ph = (s + L * .6 - off) / (2 * L); k = math.floor(ph)
        P = off + 2 * L * k; st_half = stance * L / 2; land = P - st_half; lift = P + st_half
        def plant(q):
            q = clamp(q, 0, D); d = path.dir(q); yw = math.atan2(d.x, -d.y)
            return path.at(q) + right(yw) * (sg * .125)
        if land - 1e-9 <= s < lift:
            pos = plant(P)
        else:
            nxt = P + 2 * L; w = clamp((s - lift) / max(1e-6, nxt - st_half - lift))
            pos = plant(P).lerp(plant(nxt), sm(0, 1, w)); pos.z += math.sin(math.pi * w) * .12
        if u >= 1:
            settle = sm(t1, t1 + .3, t); pos = pos.lerp(base + right(yaw) * (sg * .125), settle); pos.z *= (1 - settle)
        pos.z += .02; feet.append((side, pos))
    rel = [(p - base).dot(dv) for _, p in feet]
    moving = sm(t0, t0 + .3, t) * (1 - sm(t1 - .2, t1 + .1, t))
    bob = (abs(rel[0] - rel[1]) / (2 * L)) * moving
    n['hips'].location.z = .735 - bob * .03
    rot(n['hips'], 0, 0, (rel[0] - rel[1]) * .35 * moving)
    rot(n['torso'], .07 * moving, 0, -(rel[0] - rel[1]) * .5 * moving)
    for side, p in feet: foot(n, side, p, yaw)
    swing = (rel[0] - rel[1]) / L * moving
    rot(n['Rarm'], swing * .45, 0, .05); rot(n['Larm'], -swing * .45, 0, -.05)
    rot(n['Relbow'], -.25 * moving - .05); rot(n['Lelbow'], -.25 * moving - .05)
    return yaw

def breathe(n, t, amp=.012, rate=1.6, phase=0.0):
    addrot(n['torso'], amp * math.sin(t * rate + phase), 0, 0)

# ---------------------------------------------------------------- staging constants
A0 = V(.35, .3); S0 = V(-2.0, .25); H0 = V(.70, .14)
YA = yaw_to(A0, S0)  # Alex faces Steve
YS = yaw_to(S0, A0)
YH = YA
CHEST = Vector((-2.6, 1.15, 0))
RS = 1.0  # sign of right(yaw) that points to the character's right hand
SWORD_STAND = CHEST + Vector((0, -.86, 0))
WALK_PATH = Path2([SWORD_STAND, V(-1.75, .3), V(-1.4, 2.4), V(-.45, 4.6), V(-.4, 6.2), V(-.2, 10.0)])

SHOTS = [  # name, start, end, lens
    ('Garden', 0.0, 4.5, 28), ('Together', 4.5, 9.6, 40), ('Shudder', 9.6, 12.0, 24), ('Dark', 12.0, 14.0, 45),
    ('Reveal', 14.0, 16.4, 32), ('Pierce', 16.4, 18.4, 30), ('SteveFace', 18.4, 19.8, 70), ('Charge', 19.8, 21.2, 26),
    ('Invitation', 21.2, 25.4, 55), ('Vanish', 25.4, 32.0, 30), ('Loss', 32.0, 37.5, 50),
    ('Rage', 37.5, 42.0, 22), ('Sword', 42.0, 46.5, 35), ('IntoDark', 46.5, 53.0, 30)]
HIT = 16.92        # hand exits Alex's chest
FREEZE = (16.92, 17.10)  # hit-stop
STOP0, STOP1 = 21.2, 25.35  # time stop during the invitation
VANISH = 25.45
CATCH0, CATCH1 = 26.6, 29.0  # both sink to the ground in one continuous move

def shot_at(t):
    for s in SHOTS:
        if s[1] <= t < s[2]: return s
    return SHOTS[-1]

def darkness(t): return sm(10.3, 11.4, t)

# ---------------------------------------------------------------- acting
def pose_alex(t):
    if t < 9.6:
        reset(A, A0, YA, .75)
        # 0-3.5: bent over harvesting, standing up with the bundle, 4.5-6: winds up and tosses at 6.0
        bend = K(t, [(0, .55), (1.4, .62), (2.6, .05), (3.2, -.04), (3.8, 0.0), (5.4, .02), (5.75, -.12), (6.05, .16), (6.5, 0.0), (9.6, 0)])
        knee = K(t, [(0, .18), (1.6, .2), (2.7, .0), (9.6, 0)])
        A['hips'].location.z = .75 - knee * .2
        rot(A['torso'], bend, 0, K(t, [(0, 0), (5.4, 0), (5.8, -.35), (6.1, .25), (6.6, 0)]))
        stand(A, YA, .14, (knee * .1, -knee * .05))
        look(A, wm(S['head']).translation + Vector((0, 0, .2)), amount=K(t, [(0, 0), (2.4, 0), (3.2, 1), (9.6, 1)]))
        addrot(A['head'], K(t, [(0, .45), (2.2, .4), (3, 0), (7.0, 0), (7.3, -.15), (7.6, .05), (8.0, -.1), (8.6, 0)]), K(t, [(0, 0), (7, 0), (7.4, .2), (8.4, .15), (9.6, 0)]), 0)
        yaw = YA
        loc = lambda q: A0 + fwd(yaw) * q[0] + right(yaw) * q[1] + Vector((0, 0, q[2]))
        if t < 6.05:
            p = K(t, [(0, (.38, .1, .35)), (.9, (.42, .05, .28)), (1.5, (.36, .1, .42)), (2.8, (.22, .14, 1.0)), (4.8, (.2, .14, 1.02)), (5.6, (-.18, .3, 1.5)), (6.05, (.45, .18, 1.38))])
        else:
            p = K(t, [(6.05, (.45, .18, 1.38)), (6.5, (.3, .2, .9)), (7.0, (.12, .25, .7)), (9.6, (.1, .25, .68))])
        hand(A, 'R', loc(p))
        lp = K(t, [(0, (.35, -.15, .4)), (2.6, (.12, -.3, .72)), (7.0, (.1, -.28, .7)), (7.35, (.25, -.06, 1.58)), (8.3, (.24, -.05, 1.56)), (8.9, (.1, -.28, .7))])
        hand(A, 'L', loc(lp))
        laugh = sm(7.0, 7.3, t) * (1 - sm(8.6, 9.2, t))
        addrot(A['torso'], -.08 * laugh + .03 * math.sin(t * 22) * laugh, 0, 0)
        A['hips'].location.z += .012 * math.sin(t * 22) * laugh
        breathe(A, t)
        # sky reaction (9.6+ handled below)
        return
    # 9.6+: alarmed looking up, then speared and carried, then collapse
    reset(A, A0, YA, .75)
    up = sm(9.9, 10.5, t)
    if t < HIT:
        stand(A, YA, .14)
        rot(A['torso'], -.05 * up, 0, 0)
        sky = SUN_POS
        look(A, sky, amount=up * (1 - sm(12.9, 13.5, t)))
        addrot(A['head'], -.15 * up * (1 - sm(12.9, 13.5, t)), 0, .25 * up * (1 - sm(12.9, 13.5, t)))
        if t > 12.9: look(A, wm(S['head']).translation, amount=sm(12.9, 13.6, t))
        # arms drawn in, fearful
        fear = sm(10.0, 10.6, t)
        loc = lambda q: A0 + fwd(YA) * q[0] + right(YA) * q[1] + Vector((0, 0, q[2]))
        hand(A, 'R', loc((.16, .2, mix(.72, .88, fear))))
        hand(A, 'L', loc((.16, -.2, mix(.72, .86, fear))))
        # shiver of awareness right before the strike
        addrot(A['head'], 0, 0, .04 * math.sin(t * 9) * sm(15.5, 16.5, t))
        return
    # impaled: arch, lifted onto toes, arms fling then go limp; held until vanish
    k = sm(HIT, HIT + .08, t); limp = sm(17.4, 19.2, t)
    held = t < VANISH
    if held:
        A['hips'].location.z = .75 + .06 * k - .05 * limp
        rot(A['hips'], -.05 * k, 0, 0)
        rot(A['torso'], -.32 * k + .55 * limp, 0, .05 * limp)
        rot(A['head'], -.55 * k + 1.0 * limp, .25 * limp, .2 * limp)
        stand(A, YA, .12, (.1 * k - .02, .12 * k))
        # toes drag: knees soften as she hangs
        loc = lambda q: A0 + fwd(YA) * q[0] + right(YA) * q[1] + Vector((0, 0, q[2]))
        fling = sm(HIT, HIT + .1, t) * (1 - limp)
        hand(A, 'R', loc((mix(.1, .38, fling) + .05 * limp, mix(-.32, -.5, fling), mix(.45, 1.25, fling))))
        hand(A, 'L', loc((mix(.1, .38, fling) + .05 * limp, mix(.32, .45, fling), mix(.45, 1.15, fling))))
        if t > STOP0 and t < STOP1:  # frozen moment: imperceptible drift
            pass
        return
    # collapse forward into Steve's arms, then one continuous sink to the ground across his lap
    if t < CATCH1:
        alex_collapse(min(t, CATCH0))
        if t <= CATCH0: return
        s0 = snap(A); reset(A, A0, YA, .75); alex_lap(CATCH1); s1 = snap(A)
        blend(A, s0, s1, catch_k(t))
        return
    alex_lap(t)

def alex_collapse(t):
    reset(A, A0, YA, .75)
    c = sm(VANISH, VANISH + 1.0, t)
    A['root'].location = A0.lerp(A0 + fwd(YA) * .3, c)
    A['hips'].location.z = mix(.75, .56, c)
    rot(A['hips'], .4 * c, 0, 0)
    rot(A['torso'], .4 * c, 0, -.1 * c)
    rot(A['head'], mix(1.0, .7, c), .2, .1)
    rot(A['Rleg'], -.15 * c); rot(A['Rknee'], .6 * c); rot(A['Lleg'], .1 * c); rot(A['Lknee'], .5 * c)
    rot(A['Rarm'], -.15 * c, 0, -.1); rot(A['Larm'], -.2 * c, 0, .15); rot(A['Relbow'], -.2); rot(A['Lelbow'], -.15)

def snap(n): return {k: (ob.location.copy(), ob.rotation_quaternion.copy()) for k, ob in n.items()}
def blend(n, s0, s1, k):
    for key, ob in n.items():
        (l0, q0), (l1, q1) = s0[key], s1[key]
        ob.location = l0.lerp(l1, k); ob.rotation_quaternion = q0.slerp(q1, k)
def catch_k(t):
    x = clamp((t - CATCH0) / (CATCH1 - CATCH0)); return x * x * x * (x * (6 * x - 15) + 10)

def alex_lap(t):
    # cradled across Steve's lap: reclined, head toward his left arm; lowered to the grass at 37.4-38.8
    sp = steve_kneel_spot()
    lay = sm(37.4, 38.8, t)
    yl = YS + math.pi / 2
    base = sp + fwd(YS) * mix(.42, .5, lay) - right(YS) * mix(.18, .3, lay)
    reset(A, base, yl, mix(.34, .14, lay))
    recl = mix(1.05, 1.52, lay)
    rot(A['hips'], -recl, 0, 0)
    rot(A['Rleg'], -(math.pi / 2 - recl) + .05); rot(A['Lleg'], -(math.pi / 2 - recl) - .05)
    rot(A['Rknee'], .45 * (1 - lay)); rot(A['Lknee'], .25 * (1 - lay))
    rot(A['torso'], .1 * (1 - lay), 0, 0)
    rot(A['head'], mix(-.3, -.1, lay), 0, K(t, [(27, -.5), (33, -.55), (34.4, -.8), (37.5, -.75), (38.8, -.35)]))
    drop = back(34.25, 34.75, t, 1.2)
    rot(A['Rarm'], mix(-.5, .2, drop), 0, mix(-.25, -.9, drop)); rot(A['Relbow'], mix(-.9, -.05, drop))
    rot(A['Larm'], -.15, 0, .35); rot(A['Lelbow'], -.5)

def steve_kneel_spot(): return A0 + fwd(YA) * .9

def pose_steve(t):
    yaw = YS
    if t < 9.6:
        reset(S, S0, yaw, .75)
        stand(S, yaw, .14, (.05, -.05))
        look(S, wm(A['head']).translation + Vector((0, 0, .1)), amount=K(t, [(0, .3), (3.5, .3), (4.3, 1), (9.6, 1)]))
        # 0-4: hoeing motion with both hands low; 6.3-6.8 catches bundle at chest; laughs, nudge
        loc = lambda q: S0 + fwd(yaw) * q[0] + right(yaw) * q[1] + Vector((0, 0, q[2]))
        hoe = math.sin(t * 3.2) * (1 - sm(3.4, 4.0, t))
        rot(S['torso'], .25 * (1 - sm(3.4, 4.2, t)) + .06 * hoe * (1 - sm(3.4, 4, t)), 0, 0)
        rp = K(t, [(0, (.42, .1, .62)), (4.0, (.42, .1, .62)), (4.6, (.18, .25, .78)), (6.0, (.16, .25, .8)), (6.45, (.45, .09, 1.2)), (6.75, (.3, .07, 1.1)), (7.4, (.28, .1, 1.05)), (9.6, (.22, .14, .95))])
        lp = K(t, [(0, (.42, -.1, .66)), (4.0, (.42, -.1, .66)), (4.6, (.18, -.25, .78)), (6.0, (.16, -.25, .8)), (6.45, (.45, -.09, 1.2)), (6.75, (.3, -.07, 1.1)), (7.4, (.28, -.1, 1.05)), (9.6, (.22, -.14, .95))])
        hoff = Vector((0, 0, .05 * hoe))
        hand(S, 'R', loc(rp) + hoff); hand(S, 'L', loc(lp) + hoff)
        laugh = sm(6.9, 7.2, t) * (1 - sm(8.7, 9.3, t))
        addrot(S['torso'], -.1 * laugh, 0, 0); addrot(S['head'], -.3 * laugh + .05 * math.sin(t * 20) * laugh, 0, 0)
        S['hips'].location.z += .01 * math.sin(t * 20) * laugh
        breathe(S, t, phase=1)
        return
    if t < 19.8:
        reset(S, S0, yaw, .75)
        recoil = sm(HIT + .15, HIT + .5, t)
        stand(S, yaw, .14, (.05 - .12 * recoil, -.05))
        up = sm(9.95, 10.6, t)
        look(S, SUN_POS, amount=up * (1 - sm(12.8, 13.4, t)))
        if t > 12.8: look(S, wm(A['head']).translation, amount=sm(12.8, 13.4, t))
        rot(S['torso'], -.08 * up * (1 - sm(12.8, 13.4, t)) - .1 * recoil, 0, 0)
        loc = lambda q: S0 + fwd(yaw) * q[0] + right(yaw) * q[1] + Vector((0, 0, q[2]))
        drop = sm(HIT + .1, HIT + .4, t)
        hand(S, 'R', loc((mix(.2, .05, drop), -.25, mix(.9, .62, drop))))
        hand(S, 'L', loc((mix(.2, .05, drop), .25, mix(.9, .62, drop))))
        # trembling breath in the close-up
        addrot(S['head'], .02 * math.sin(t * 13) * sm(18.4, 18.8, t), 0, 0)
        return
    # charge: run at Herobrine; time stops mid-lunge; the fist lands where his head was
    end = A0 + fwd(YA) * .8
    pre = end - fwd(YS) * .28
    if t < STOP0:
        locomote(S, t, 19.85, STOP0, S0, pre, yaw, stride=.85, run=True, ease_in=True, ease_out=False)
        return
    loc = lambda q, base: base + fwd(yaw) * q[0] + right(yaw) * q[1] + Vector((0, 0, q[2]))
    if CATCH0 < t < CATCH1:
        steve_catch(CATCH0); s0 = snap(S); steve_lap(CATCH1); s1 = snap(S)
        k = catch_k(t); blend(S, s0, s1, k)
        # hands stay on her back and under her knees all the way down
        hand(S, 'R', wm(A['torso']) @ Vector((-.2, .05, .55)).lerp(Vector((0, .16, .55)), k))
        hand(S, 'L', wm(A['torso']) @ Vector((.2, .05, .55)).lerp(Vector((0, .16, .1)), k))
        look(S, wm(A['head']).translation, amount=.9)
        return
    if t <= CATCH0:
        steve_catch(t); return
    steve_lap(t)

def steve_catch(t):
    yaw = YS
    end = A0 + fwd(YA) * .8
    pre = end - fwd(YS) * .28
    loc = lambda q, base: base + fwd(yaw) * q[0] + right(yaw) * q[1] + Vector((0, 0, q[2]))
    if True:
        k = sm(STOP1, STOP1 + .12, t)
        base = pre.lerp(end, k)
        reset(S, base, yaw, .70)
        rot(S['torso'], .35 - .1 * k, 0, mix(.35, -.35, k))
        stand(S, yaw, .16, (.3, -.35))
        hand(S, 'R', loc((mix(-.25, .8, k), mix(.3, .05, k), mix(1.25, 1.62, k)), base))
        hand(S, 'L', loc((.35, -.25, 1.15), base))
        look(S, wm(H['head']).translation if t < VANISH else wm(A['head']).translation)
        catch = sm(VANISH + .25, 26.6, t)
        if catch > 0:
            sp = steve_kneel_spot()
            S['root'].location = end.lerp(sp, catch)
            S['hips'].location.z = mix(.70, .55, catch)
            rot(S['torso'], mix(.25, .4, catch), 0, 0)
            stand(S, yaw, .18, (.25 * catch, -.25))
            hand(S, 'R', (wm(A['torso']) @ Vector((-.2, .05, .55))).lerp(loc((.8, .05, 1.62), end), 1 - catch))
            hand(S, 'L', wm(A['torso']) @ Vector((.2, .05, .55)))
        return

def steve_lap(t):
    yaw = YS
    loc = lambda q, base: base + fwd(yaw) * q[0] + right(yaw) * q[1] + Vector((0, 0, q[2]))
    sp = steve_kneel_spot()
    if t < 41.6:
        # kneeling with her across his lap -> lays her down -> rises on one knee -> stands
        hh = K(t, [(27.0, .5), (39.1, .5), (39.7, .5), (40.5, .64), (41.2, .75)])
        reset(S, sp, yaw, hh)
        rot(S['Rleg'], K(t, [(27, 0), (39.6, 0), (40.5, .15), (41.2, 0)])); rot(S['Rknee'], K(t, [(27, 1.55), (39.6, 1.55), (40.5, .6), (41.2, 0)]))
        rot(S['Lleg'], K(t, [(27, 0), (39.1, 0), (39.6, -1.2), (40.4, -.8), (41.2, 0)])); rot(S['Lknee'], K(t, [(27, 1.55), (39.1, 1.55), (39.6, 1.2), (40.4, .8), (41.2, 0)]))
        grief = sm(33.5, 36.5, t)
        lean = K(t, [(27, .3), (33, .32), (36.5, .42), (37.4, .4), (38.6, .5), (39.4, .3), (40.4, .35), (41.2, .06)])
        rot(S['torso'], lean, 0, 0)
        breathe(S, t, .025 * (1 + grief), 2.4)
        addrot(S['torso'], .025 * math.sin(t * 15) * grief * (1 - sm(36.3, 37.0, t)), 0, 0)
        head_t = wm(A['head']).translation
        hold_back = wm(A['torso']) @ Vector((0, .16, .55))
        hold_hip = wm(A['torso']) @ Vector((0, .16, .1))
        cheek = wm(A['head']) @ Vector((.27, 0, .2))
        rel = sm(38.8, 39.4, t)
        # released hands hang as clenched fists well out at his sides (never in front of the hips)
        side_l = loc((.06, -.44, hh + .05), sp); side_r = loc((.06, .44, hh + .05), sp)
        rp = hold_hip if t < 33.6 else hold_hip.lerp(cheek, sm(33.6, 34.3, t))
        hand(S, 'R', hold_back.lerp(side_r, rel))
        hand(S, 'L', rp.lerp(side_l, rel))
        if t < 37.5:
            look(S, head_t, amount=1 - sm(34.9, 35.8, t))
            addrot(S['head'], .2 * grief * (1 - sm(34.9, 35.8, t)) - .55 * sm(34.9, 35.8, t), 0, .04 * math.sin(t * 13) * sm(35.0, 35.5, t))
        else:
            anger = sm(37.6, 39.0, t)
            look(S, head_t, amount=1 - anger)
            addrot(S['head'], mix(.2, -.12, anger), 0, 0)
            # heavy angry breathing in the chest, arms stay still
            addrot(S['torso'], .03 * math.sin(t * 7.5) * anger, 0, 0)
        return
    # stands still, staring ahead; the shot ends on his face and cuts to the chest
    if t < 42.0:
        reset(S, sp, yaw, .75); stand(S, yaw, .15)
        rot(S['torso'], .06, 0, 0); addrot(S['torso'], .03 * math.sin(t * 7.5), 0, 0)
        hand(S, 'L', loc((.06, -.44, .8), sp)); hand(S, 'R', loc((.06, .44, .8), sp))
        rot(S['head'], -.12 + .02 * math.sin(t * 7.5), 0, 0)
        return
    if t < 46.5:
        # Sword shot starts with Steve at the chest
        yaw3 = math.pi
        reset(S, SWORD_STAND, yaw3, .74)
        crouch = sm(42.3, 42.8, t) * (1 - sm(44.0, 44.6, t))
        S['hips'].location.z = .74 - .14 * crouch
        rot(S['torso'], .45 * crouch, 0, 0)
        stand(S, yaw3, .16, (.08, -.12))
        look(S, CHEST + Vector((0, 0, .6)), amount=1 - sm(44.4, 45.0, t))
        loc = lambda q: SWORD_STAND + fwd(yaw3) * q[0] + right(yaw3) * q[1] + Vector((0, 0, q[2]))
        # left hand lifts the lid, right reaches in, then raises the sword
        lp = K(t, [(42.0, (.25, -RS * .3, .85)), (42.5, (.62, -RS * .2, .8)), (42.8, (.62, -RS * .25, .82)), (43.2, (.7, -RS * .3, 1.25)), (44.0, (.6, -RS * .3, 1.1)), (44.6, (.25, -RS * .3, .85))])
        # right hand dips below the rim (wall top .625), grips, then lifts in an arc out to his right side
        rp = K(t, [(42.0, (.2, RS * .3, .85)), (43.1, (.25, RS * .3, .85)), (43.5, (.8, RS * .05, .42)), (43.95, (.78, RS * .06, .44)),
                   (44.3, (.62, RS * .28, 1.0)), (44.55, (.42, RS * .5, 1.55)), (44.8, (.22, RS * .52, 1.98)), (45.6, (.2, RS * .52, 1.96)), (46.2, (.12, RS * .4, .8))])
        hand(S, 'L', loc(lp)); hand(S, 'R', loc(rp), pole=wm(S['Rarm']).translation + right(yaw3) * RS * .9 + Vector((0, 0, -.3)))
        rot(S['Rwrist'], K(t, [(43.5, .3), (43.95, .3), (44.4, 1.0), (44.8, 1.55), (45.6, 1.55), (46.2, 1.3)]), 0, 0)
        if t > 45.0: rot(S['head'], -.08, 0, 0)
        return
    # walk into the dark forest, sword low: around the chest, through the fence gap
    locomote_path(S, t, 46.6, 53.5, WALK_PATH, stride=.6, start_yaw=math.pi)
    rot(S['Rarm'], -.15, 0, -.12); rot(S['Relbow'], -.25); rot(S['Rwrist'], 1.3, 0, 0)
    rot(S['head'], .05, 0, 0)

def pose_herobrine(t):
    vis = 13.0 <= t < VANISH + .05
    reset(H, H0, YH, .75)
    if not vis:
        H['root'].scale = (.0001, .0001, .0001); return vis
    # emergence from darkness: lean out from behind Alex's head (to her left, camera side)
    lean_out = K(t, [(13.0, .0), (13.6, .6), (14.0, .62), (15.6, .5), (16.3, .0)])
    weight = sm(14.0, 14.8, t)
    # cocky contrapposto, chin up, head tilt
    rot(H['hips'], 0, .04 * weight, 0)
    stand(H, YH, .14, (.05, -.08))
    hip = K(t, [(13, .75), (16.2, .75), (16.7, .72), (HIT, .73)])
    H['hips'].location.z = hip
    tilt = .18 * weight
    rot(H['torso'], 0, lean_out * .45, 0)
    rot(H['head'], -.12 * weight, tilt + lean_out * .3, 0)
    loc = lambda q: H0 + fwd(YH) * q[0] + right(YH) * q[1] + Vector((0, 0, q[2]))
    # left hand lazily hanging; right hand: slow raise (flat blade) -> drive through
    hand(H, 'L', loc((.06, -.33, .6 + .02 * math.sin(t * 1.3))))
    exit_pt = A0 + fwd(YA) * .32 + Vector((0, 0, 1.18)) + right(YA) * -.03
    back_pt = A0 + fwd(YA) * -.13 + Vector((0, 0, 1.18))
    if t < HIT:
        cock = sm(14.6, 16.2, t)
        pull = sm(16.2, 16.78, t)
        p = loc((mix(.06, .05, cock), mix(.33, .36, cock), mix(.6, 1.15, cock)))
        p = p.lerp(loc((-.2, .32, 1.25)), pull)  # chambered back at shoulder height
        drive = ei(16.78, HIT, t)
        p = p.lerp(exit_pt, drive)
        rot(H['torso'], .22 * drive, lean_out * .45, .25 * pull - .35 * drive)
        H['root'].location = H0 + fwd(YH) * (.12 * drive)
        stand(H, YH, .14, (.05 + .1 * drive, -.08))
        hand(H, 'R', p, pole=wm(H['Rarm']).translation + right(YH) * .6 + Vector((0, 0, -.4)))
        if drive > 0: rot(H['head'], .08, 0, -.1)
    else:
        # arm through her chest; leans in beside her head to talk; head tilts with each phrase
        H['root'].location = H0 + fwd(YH) * .12
        stand(H, YH, .14, (.15, -.08))
        talk = sm(21.0, 21.8, t)
        rot(H['torso'], .22 + .1 * talk, .3 * talk, -.35 + .15 * talk)
        hand(H, 'R', exit_pt + fwd(YA) * (.04 * math.sin((t - HIT) * 2) * (1 - talk)), pole=wm(H['Rarm']).translation + right(YH) * .6 + Vector((0, 0, -.4)))
        tilt = K(t, [(HIT, .0), (21.0, 0), (21.8, .32), (23.0, .36), (23.4, .18), (24.6, .22), (25.0, .45), (25.4, .45)])
        look(H, wm(H['head']) @ Vector((0, 0, .25)) + Vector((-1.0, -.55, -.1)), limit=1.2, amount=sm(21.0, 21.8, t))
        addrot(H['head'], 0, tilt, 0)
    return vis

# ---------------------------------------------------------------- FX
def emitter_world(ob, local): return wm(ob) @ Vector(local)

def apply_fx(t, frame):
    # sky: day -> crimson eclipse -> night
    dk = darkness(t)
    red = sm(9.95, 10.4, t) * (1 - sm(11.0, 12.2, t))
    low = Vector((.95, .72, .55)).lerp(Vector((.55, .04, .02)), red).lerp(Vector((.012, .014, .03)), dk)
    high = Vector((.32, .52, .85)).lerp(Vector((.25, .0, .01)), red).lerp(Vector((.003, .004, .012)), dk)
    for c in range(3): rec_val(SKY_LOW, low[c], frame, c); rec_val(SKY_HIGH, high[c], frame, c)
    rec_val(SKY_STR, mix(1.0, 1.0, dk), frame)
    bg.inputs[1].default_value = mix(.45, .03, dk); rec(world.node_tree, 'nodes["Background"].inputs[1].default_value', [bg.inputs[1].default_value], frame)
    bg.inputs[0].default_value = (*Vector((.55, .65, .85)).lerp(Vector((.15, .17, .3)), dk), 1); rec(world.node_tree, 'nodes["Background"].inputs[0].default_value', bg.inputs[0].default_value, frame)
    cover = sm(9.85, 10.55, t)
    moon_disc.location = SUN_POS - SUN_DIR * 2 + Vector((7.5, 0, 6)) * (1 - cover) * 1.6
    rec(moon_disc, 'location', moon_disc.location, frame)
    corona_on = sm(10.2, 10.6, t) * (1 - sm(11.3, 12.0, t))
    rec_emit(MAT['corona'], 10 * corona_on, frame)
    crack_on = (sm(9.8, 9.86, t) * (1 - sm(10.1, 10.8, t))) + .6 * sm(10.9, 10.95, t) * (1 - sm(11.0, 11.3, t))
    rec_emit(MAT['crack'], 30 * crack_on, frame)
    sun.data.energy = mix(4.5, 0.0, cover) * (1 - .6 * red); rec(sun.data, 'energy', [sun.data.energy], frame)
    moon.data.energy = .55 * sm(11.0, 12.0, t) * (1 - .7 * sm(46.5, 52, t)); rec(moon.data, 'energy', [moon.data.energy], frame)
    FOG_DENS.default_value = mix(.004, .02, dk); rec_val(FOG_DENS, FOG_DENS.default_value, frame)
    for c, v in enumerate(Vector((1, .85, .7)).lerp(Vector((.4, .5, 1)), dk)): rec_val(FOG_COL, v, frame, c)

    hb_vis = 13.0 <= t < VANISH + .05
    eyes = sm(13.0, 13.15, t) if hb_vis else 0
    eye_flare = 1 + 2.5 * math.exp(-max(0, t - 13.0) * 4) + 1.5 * (sm(24.8, 25.0, t) * (1 - sm(25.2, 25.4, t)))
    rec_emit(MAT['eye'], 22 * eyes * eye_flare, frame)
    eye_light.location = wm(H['head']) @ Vector((0, -.4, .2)); eye_light.data.energy = 1.5 * eyes
    rec(eye_light, 'location', eye_light.location, frame); rec(eye_light.data, 'energy', [eye_light.data.energy], frame)
    hb_light.location = wm(H['torso']) @ Vector((0, .7, 1.4)); hb_light.data.energy = 45 * sm(13.2, 14.4, t) * (1 if hb_vis else 0) + (60 * (1 - sm(VANISH, VANISH + 1.2, t)) if t >= VANISH else 0)
    rec(hb_light, 'location', hb_light.location, frame); rec(hb_light.data, 'energy', [hb_light.data.energy], frame)
    for g in grin:
        on = 1 if 21.75 <= t < VANISH else 0
        g.scale = (1, 1, 1) if on else (.0001,) * 3; rec(g, 'scale', g.scale, frame)

    # wounds / blood visibility
    def show(ob, on): ob.scale = (1, 1, 1) if on else (.0001,) * 3; rec(ob, 'scale', ob.scale, frame)
    show(a_wound_front, t >= HIT); show(a_wound_back, t >= HIT)
    stain = sm(HIT, 30.0, t); a_stain.scale = (.3 + .7 * stain, 1, .2 + .8 * stain) if t >= HIT else (.0001,) * 3; rec(a_stain, 'scale', a_stain.scale, frame)
    show(a_mouth, t >= 19.0)
    for ob in hb_blood: show(ob, t >= HIT)
    for ob in s_splat: show(ob, t >= HIT + .12)
    for ob in s_hands_blood: show(ob, t >= 28.5)
    show(sword, 44.0 <= t)
    for ob in s_brows:
        on = t >= 38.0
        ob.scale = (1, 1, 1) if on else (.0001,) * 3; rec(ob, 'scale', ob.scale, frame)
        ob.rotation_euler = (0, .35 if ob.location.x < 0 else -.35, 0); rec(ob, 'rotation_euler', ob.rotation_euler, frame)
    blink_a = (t >= 30.5) or any(a <= t < a + .12 for a in (3.3, 8.1))
    for ob in a_lids: show(ob, blink_a)
    blink_s = any(a <= t < a + .12 for a in (2.1, 5.3, 13.7, 35.2, 37.0)) or (34.6 <= t < 37.3 and False)
    for ob in s_lids: show(ob, blink_s)

    # wheat bundle: in Alex's hand -> arc -> Steve's hands -> dropped when Alex is hit
    if t < 6.05: p = wm(A['Rwrist']) @ Vector((0, -.05, -.06)); r = (0, 0, 0)
    elif t < 6.6:
        k = (t - 6.05) / .55; a = wm_cache['wheat_start']; b = (wm(S['Rwrist']).translation + wm(S['Lwrist']).translation) / 2
        p = a.lerp(b, k); p.z += math.sin(math.pi * k) * .55; r = (k * 7, k * 2, 0)
    elif t < HIT + .1: p = (wm(S['Rwrist']).translation + wm(S['Lwrist']).translation) / 2 + Vector((0, 0, .05)); r = (0, 0, 1)
    else:
        k = clamp((t - HIT - .1) / .45); a = wm_cache.setdefault('wheat_drop', (wm(S['Rwrist']).translation + wm(S['Lwrist']).translation) / 2)
        p = a.lerp(Vector((a.x + .1, a.y - .1, .05)), k); p.z = mix(a.z, .04, k * k); r = (1.4 * k, 0, 1 + k)
    if t < 6.05: wm_cache['wheat_start'] = p.copy()
    wheat_item.location = p; wheat_item.rotation_mode = 'XYZ'; wheat_item.rotation_euler = r
    rec(wheat_item, 'location', p, frame); rec(wheat_item, 'rotation_euler', r, frame)

    # chest lid
    lid.rotation_quaternion = qrot(-1.45 * back(42.45, 42.85, t, 1.0)); rec(lid, 'rotation_quaternion', lid.rotation_quaternion, frame)
    glint = math.exp(-((t - 44.85) / .12) ** 2)
    rec_emit(MAT['glint'], 40 * glint, frame); sword_glint.scale = (1 + 12 * glint, 1, 1 + 12 * glint); rec(sword_glint, 'scale', sword_glint.scale, frame)
    glint_light.location = wm(sword_glint).translation; glint_light.data.energy = 15 * glint
    rec(glint_light, 'location', glint_light.location, frame); rec(glint_light.data, 'energy', [glint_light.data.energy], frame)

    # mob eyes open one by one in the final shot
    for ob, i in mob_eyes:
        on = sm(48.0 + i * .55, 48.25 + i * .55, t)
        blink = 0 if (int((t * 3 + i) * 7) % 23 == 0) else 1
        ob.scale = (1, 1, max(.0001, on * blink)); rec(ob, 'scale', ob.scale, frame)
    rec_emit(MAT['mobeye_r'], 14 * sm(47.5, 48.5, t), frame); rec_emit(MAT['mobeye_p'], 16 * sm(47.5, 48.5, t), frame)

    # particles ------------------------------------------------------------
    rnd = random.Random(7)
    # blood burst from the exit wound (forward), slow-motion right after the hit-stop
    ts = story_time(t)
    origin = wm_cache.get('exit') or (A0 + fwd(YA) * .3 + Vector((0, 0, 1.18)))
    for i, ob in enumerate(P_blood):
        # first wave: violent burst; later waves: pulsing gush that keeps pouring from the exit wound
        wave = 0 if i < 120 else (1 if i < 190 else 2)
        d0 = HIT + (rnd.uniform(0, .12) if wave == 0 else rnd.uniform(.15, .55) if wave == 1 else rnd.uniform(.55, 1.4))
        sp = rnd.uniform(1.8, 5.0) if wave == 0 else rnd.uniform(1.0, 2.6) if wave == 1 else rnd.uniform(.5, 1.5)
        dirv = (fwd(YA) * rnd.uniform(.6, 1.1) + right(YA) * rnd.uniform(-.6, .6) + Vector((0, 0, rnd.uniform(-.2, .7)))).normalized()
        if i % 4 == 0: dirv = (-fwd(YA) * .8 + Vector((0, 0, rnd.uniform(-.1, .5))) + right(YA) * rnd.uniform(-.5, .5)).normalized(); sp *= .7
        dt = ts - story_time(d0)
        if dt < 0 or t < HIT: ob.scale = (0, 0, 0); ob.location = (0, 0, -50)
        else:
            pos = origin + dirv * sp * dt + Vector((0, 0, -4.9)) * dt * dt
            if pos.z <= .005:
                # find landing time and stick as a flat drop
                a_ = -4.9; b_ = dirv.z * sp; c_ = origin.z
                tl = (-b_ - math.sqrt(b_ * b_ - 4 * a_ * c_)) / (2 * a_)
                pos = origin + dirv * sp * tl + Vector((0, 0, -4.9)) * tl * tl; pos.z = .006
                ob.scale = (1.6, 1.6, .12)
            else:
                st = 1 + .8 * clamp(sp * dt * .6)
                ob.scale = (1, 1, st)
            ob.location = pos
            if t > 46.0: ob.scale = (0, 0, 0)
        ob.rotation_euler = (rnd.uniform(0, 1), rnd.uniform(0, 1), rnd.uniform(0, 3))
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame); rec(ob, 'rotation_euler', ob.rotation_euler, frame)
    # drips from the wound and from Herobrine's arm while held / carried
    for i, ob in enumerate(P_drip):
        period = .55 + rnd.uniform(0, .5); off = rnd.uniform(0, period)
        src = (wm(A['torso']) @ Vector((rnd.uniform(-.06, .06), -.14, .45))) if i % 3 else (wm(H['Rwrist']).translation if t < VANISH else wm(A['torso']) @ Vector((0, .14, .45)))
        active = (HIT + .3 < t < 36.0)
        tt = story_time(t)
        ph = ((tt - off) % period) / period if active else 0
        if not active: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
        else:
            fall = ph * period
            ob.location = src + Vector((0, 0, -4.9 * fall * fall)); ob.scale = (1, 1, 1.8)
            if ob.location.z < 0: ob.location.z = .004; ob.scale = (1.4, 1.4, .1)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame)
    # splats on the grass in front of Alex
    for i, ob in enumerate(splats):
        appear = HIT + .2 + i * .045
        if t < appear: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
        else:
            back_side = i % 5 == 4
            ob.location = A0 + fwd(YA) * ((-.45 - (i % 3) * .2) if back_side else (.35 + (i % 10) * .16 + (i % 3) * .08)) + right(YA) * (((i * 7) % 6) * .14 - .35) + Vector((0, 0, .003 + i * .0004))
            g = sm(appear, appear + .2, t); ob.scale = (g * (.8 + (i % 3) * .35), g * (.8 + (i % 2) * .5), 1); ob.rotation_euler = (0, 0, i * 1.3)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame); rec(ob, 'rotation_euler', ob.rotation_euler, frame)
    # growing pool under Alex once she lies in Steve's lap
    if t >= 28.0:
        c = wm(A['torso']) @ Vector((0, 0, .4)); blood_pool.location = (c.x, c.y, .003)
        g = sm(28.0, 40.0, t); blood_pool.scale = (.3 + .9 * g, .3 + .7 * g, 1)
    else: blood_pool.location = (0, 0, -50); blood_pool.scale = (0, 0, 0)
    rec(blood_pool, 'location', blood_pool.location, frame); rec(blood_pool, 'scale', blood_pool.scale, frame)
    # aura: dark cubes rising and swirling around Herobrine + embers
    hb_c = wm(H['hips']).translation
    for i, ob in enumerate(P_smoke):
        life = 1.6 + rnd.uniform(0, 1.0); off = rnd.uniform(0, life); ang0 = rnd.uniform(0, math.tau); rad = rnd.uniform(.25, .55)
        tt = story_time(t)
        if not hb_vis or t < 13.2: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
        else:
            ph = ((tt + off) % life) / life; a = ang0 + ph * 2.2
            ob.location = hb_c + Vector((math.cos(a) * rad * (1 + ph * .6), math.sin(a) * rad * (1 + ph * .6), -.7 + ph * 2.4))
            sz = math.sin(math.pi * ph) * (.6 + rnd.uniform(0, .9)) * sm(13.2, 14.2, t)
            ob.scale = (sz, sz, sz); ob.rotation_euler = (ph * 3 + i, ph * 2, i)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame); rec(ob, 'rotation_euler', ob.rotation_euler, frame)
    for i, ob in enumerate(P_ember):
        life = 1.0 + rnd.uniform(0, 1.2); off = rnd.uniform(0, life); ang0 = rnd.uniform(0, math.tau); rad = rnd.uniform(.2, .7)
        tt = story_time(t)
        if not hb_vis or t < 13.5: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
        else:
            ph = ((tt + off) % life) / life; a = ang0 + ph * 3
            ob.location = hb_c + Vector((math.cos(a) * rad, math.sin(a) * rad, -.6 + ph * 2.6)); s_ = math.sin(math.pi * ph) * sm(13.5, 14.5, t); ob.scale = (s_, s_, s_)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame)
    # vanish: Herobrine bursts into black cubes that scatter away and drift up
    for i, ob in enumerate(P_dust):
        part = rnd.choice(['head', 'torso', 'Rarm', 'Larm', 'Rleg', 'Lleg', 'head', 'torso'])
        local = Vector((rnd.uniform(-.25, .25), rnd.uniform(-.13, .13), rnd.uniform(0, .5) if part in ('head', 'torso') else rnd.uniform(-.35, 0)))
        vel = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(.2, 1.4))) * rnd.uniform(.8, 2.2)
        dt = t - VANISH
        if dt < 0 or dt > 2.2: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
        else:
            if 'v' + str(i) not in wm_cache: wm_cache['v' + str(i)] = wm(H[part]) @ local
            p0 = wm_cache['v' + str(i)]
            drag = (1 - math.exp(-dt * 3)) / 3
            ob.location = p0 + vel * drag + Vector((0, 0, .5 * dt * dt))
            s_ = (1 - sm(.2, 2.2, dt)) * (1.2 + (i % 3) * .3); ob.scale = (s_, s_, s_); ob.rotation_euler = (dt * 4 + i, dt * 3, i)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame); rec(ob, 'rotation_euler', ob.rotation_euler, frame)
    # ash falling in the grief shots
    for i, ob in enumerate(P_ash):
        x0 = rnd.uniform(-4, 4); y0 = rnd.uniform(-3, 4); sp = rnd.uniform(.25, .5); off = rnd.uniform(0, 12)
        if t < 26.0: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
        else:
            z = 4.5 - ((t + off) * sp) % 4.5
            ob.location = (x0 + math.sin(t * .7 + i) * .3, y0, z); s_ = 1.0; ob.scale = (s_, s_, s_); ob.rotation_euler = (t + i, t * .5, i)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame); rec(ob, 'rotation_euler', ob.rotation_euler, frame)

def rec_val(sock, v, frame, idx=None):
    node = sock.node; nt = node.id_data; sidx = list(node.inputs).index(sock)
    path = 'nodes["%s"].inputs[%d].default_value' % (node.name, sidx)
    key = (nt, path, idx if idx is not None else 0)
    REC.setdefault(key, []).append((frame, float(v)))

def rec_emit(mat, v, frame):
    bs = mat.node_tree.nodes['Principled BSDF']; rec_val(bs.inputs['Emission Strength'], v, frame)

def _rate(x):
    if FREEZE[0] <= x < FREEZE[1]: return 0.0
    if FREEZE[1] <= x < 18.2: return mix(.22, 1.0, sm(17.4, 18.2, x))
    if STOP0 <= x < STOP1: return .025
    return 1.0
ST_TABLE = [0.0]
for _k in range(int(60 * 96)): ST_TABLE.append(ST_TABLE[-1] + _rate(_k / 96) / 96)
def story_time(t):
    """Time for physics FX: hit-stop, slow motion after the hit, near-stop during the invitation."""
    x = max(0.0, t) * 96; k = int(x); f = x - k
    return ST_TABLE[k] + (ST_TABLE[k + 1] - ST_TABLE[k]) * f
def char_time(t):
    """Actors: hold during the hit-stop, slow-motion reaction that catches up by 18.4 s."""
    if t < FREEZE[0] or t >= 18.4: return t
    if t < FREEZE[1]: return FREEZE[0]
    x = (t - FREEZE[1]) / (18.4 - FREEZE[1]); g = x * x * (2 - x)
    return FREEZE[0] + (18.4 - FREEZE[0]) * g

# ---------------------------------------------------------------- cameras
CAMS = {}
for name, a, b, lens in SHOTS:
    d = bpy.data.cameras.new('CAM_CH1v2_' + name); d.lens = lens; d.sensor_width = 36; d.clip_start = .05; d.clip_end = 260
    d.dof.use_dof = True; d.dof.aperture_fstop = 2.8
    cam = link(bpy.data.objects.new(d.name, d), 'Cameras'); CAMS[name] = cam
    m = sc.timeline_markers.new(name, frame=round(a * FPS) + 1); m.camera = cam
sc.camera = CAMS['Garden']

def shake(t, events):
    """Deterministic decaying shake: list of (time, amp_rad, dur, freq)."""
    rx = ry = rz = 0.0
    for t0, amp, dur, fq in events:
        dt = t - t0
        if 0 <= dt <= dur:
            env = math.sin(math.pi * min(1, dt / (dur * .15))) if dt < dur * .15 else (1 - (dt - dur * .15) / (dur * .85)) ** 2
            rx += amp * env * math.sin(dt * fq * math.tau + 1.3); ry += amp * .5 * env * math.sin(dt * fq * 1.37 * math.tau)
            rz += amp * .7 * env * math.sin(dt * fq * .83 * math.tau + .4)
    return rx, ry, rz

def place_cam(cam, pos, target, roll=0.0, extra=(0, 0, 0), focus=None, fstop=2.8, lens=None):
    cam.location = Vector(pos)
    q = (Vector(target) - Vector(pos)).to_track_quat('-Z', 'Y')
    q = q @ Quaternion((0, 0, 1), roll) @ Quaternion((1, 0, 0), extra[0]) @ Quaternion((0, 1, 0), extra[1])
    cam.rotation_mode = 'XYZ'; cam.rotation_euler = q.to_euler('XYZ', cam.rotation_euler)
    cam.data.dof.focus_distance = max(.2, ((Vector(focus) if focus is not None else Vector(target)) - Vector(pos)).length)
    cam.data.dof.aperture_fstop = fstop
    if lens: cam.data.lens = lens

def camera(t, frame):
    name, a, b, lens = shot_at(t)
    cam = CAMS[name]; k = (t - a) / (b - a)
    sh = shake(t, [(9.82, .045, 1.4, 9), (10.95, .02, .6, 12), (HIT, .05, .45, 14), (VANISH, .025, .6, 10), (27.6, .006, .3, 8)])
    hand_held = (math.sin(t * 1.1) * .003, math.sin(t * .83 + 1) * .002)
    hc = lambda n: wm(n['head']) @ Vector((0, 0, .25))
    A_head = hc(A); S_head = hc(S); H_head = hc(H)
    def orbit(c, az, el, d):
        az = math.radians(az); el = math.radians(el)
        return Vector(c) + Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * d
    def shoot(c, az, el, d, lens, focus=None, fstop=2.8, roll=0.0, extra=(0, 0, 0)):
        place_cam(cam, orbit(c, az, el, d), c, roll=roll, extra=extra, focus=focus if focus is not None else c, fstop=fstop, lens=lens)
    u = sm(a, b, t)
    if name == 'Garden':
        pos = lerp((-1.0, -9.5, 4.6), (-.6, -6.2, 2.1), sm(a, b + 1, t)); tgt = lerp((-.6, 2.0, 1.2), (-.7, .6, .9), u)
        place_cam(cam, pos, tgt, focus=(-.8, .3, .9), fstop=5.6, lens=28)
    elif name == 'Together':
        c = Vector((-.82, .3, 1.3)) + (wheat_item.location - Vector((-.82, .3, 1.3))) * (.2 if 6.0 < t < 6.8 else 0)
        shoot(c, -8 + 6 * u, 4, mix(3.9, 3.3, u), 40, focus=(A_head if t < 6.2 else S_head), fstop=2.4, extra=hand_held)
    elif name == 'Shudder':
        whip = back(9.8, 10.15, t, .6)
        pos = Vector((-.9, -1.9, .55))
        tgt = lerp((-.75, .3, 1.5), SUN_POS * .2, whip)
        place_cam(cam, pos, tgt, roll=-.08 * whip, extra=sh, focus=SUN_POS if whip > .5 else (-.6, .3, 1.4), fstop=4, lens=24)
    elif name == 'Dark':
        shoot(A_head + Vector((0, -.05, -.1)), mix(-48, -42, u), 2, mix(1.75, 1.55, u), 45, focus=A_head if t < 13.0 else H_head, fstop=2.0, extra=hand_held)
    elif name == 'Reveal':
        shoot((A_head + H_head) / 2 + Vector((0, 0, -.35)), mix(-46, -40, u), -10, mix(2.5, 2.1, u), 35, focus=H_head, fstop=2.0, roll=.05, extra=hand_held)
    elif name == 'Pierce':
        zoom = sm(HIT, HIT + .05, t) * (1 - sm(17.5, 18.3, t) * .6)
        c = A0 + fwd(YA) * .1 + Vector((0, 0, 1.3))
        shoot(c, mix(-52, -47, u), -4, mix(2.9, 2.6, u), 30 + 14 * zoom, focus=c, fstop=3.2, roll=-.05, extra=sh)
    elif name == 'SteveFace':
        shoot(S_head + Vector((0, 0, -.06)), 68, 0, mix(1.35, 1.15, u), 50, focus=S_head, fstop=1.8, roll=.02, extra=hand_held)
    elif name == 'Charge':
        ch = wm(S['torso']).translation
        pos = Vector((ch.x + 1.7, ch.y - 1.0, .45)); place_cam(cam, pos, ch + Vector((0, 0, .45)), roll=-.06, extra=(hand_held[0] * 3, hand_held[1] * 3), focus=ch, fstop=2.8, lens=26)
    elif name == 'Invitation':
        c = H_head * .6 + A_head * .4
        shoot(c, mix(-66, -60, u), -2, mix(1.55, 1.35, u), 36, focus=H_head, fstop=2.2, roll=.04)
    elif name == 'Vanish':
        # one continuous shot: the vanish, the collapse and the slow sink to the ground together
        # orbit from behind Alex round to the side so both faces read while they sink; settles into the old Catch framing
        g = sm(26.0, 29.6, t); late = sm(29.6, 32.0, t)
        c = Vector((.0, .25, 1.15)).lerp(wm(S['torso']).translation + Vector((.3, 0, .05)), g)
        shoot(c, mix(-25, 104, g) - 8 * late, mix(6, 22, g), mix(3.1, 2.9, g) - .3 * late, mix(32, 35, g), focus=c, fstop=mix(3.5, 2.5, g), extra=(sh[0] + hand_held[0] * g, sh[1] + hand_held[1] * g, sh[2]))
    elif name == 'Catch':
        c = wm(S['torso']).translation + Vector((.3, 0, .05))
        shoot(c, mix(104, 96, u), 22, mix(3.0, 2.6, u), 35, focus=c, fstop=2.5, extra=hand_held)
    elif name == 'Loss':
        c = (wm(A['torso']) @ Vector((0, 0, .5))) * .5 + S_head * .5
        shoot(c, mix(78, 68, u), mix(48, 42, u), mix(2.3, 2.0, u), 40, focus=A_head, fstop=2.0, extra=hand_held)
    elif name == 'Rage':
        c = S_head + Vector((0, 0, -.35 + .2 * sm(39.5, 41, t)))
        shoot(c, 68, -24, mix(1.7, 1.5, u), 24, focus=S_head, fstop=2.0, roll=-.07, extra=hand_held)
    elif name == 'Sword':
        if t < 44.3:
            shoot(CHEST + Vector((0, 0, .6)), 95, 22, 2.1, 35, focus=CHEST + Vector((0, 0, .6)), fstop=2.8)
        else:
            c = S_head + Vector((0, 0, -.1))
            shoot(c, 150, -16, 2.2, 30, focus=wm(sword).translation, fstop=2.2, roll=.05)
    else:
        pos = lerp((-2.9, -2.6, 1.7), (-2.4, -1.7, 1.6), u)
        tgt = lerp((-1.6, 4.0, 1.2), (-.9, 8.0, 1.0), u)
        place_cam(cam, pos, tgt, focus=wm(S['torso']).translation, fstop=4, lens=30)
    rec(cam, 'rotation_euler', cam.rotation_euler, frame)
    rec(cam, 'location', cam.location, frame); rec(cam.data, 'dof.focus_distance', [cam.data.dof.focus_distance], frame)
    rec(cam.data, 'lens', [cam.data.lens], frame); rec(cam.data, 'dof.aperture_fstop', [cam.data.dof.aperture_fstop], frame)
    # per-shot key/rim lighting placed relative to the camera
    dk = darkness(t)
    key.location = cam.location + (cam.matrix_world.to_3x3() @ Vector((1.5, 1.0, .5)) if False else Vector((1.2, -1.0, 1.4)))
    tgt_key = Vector((0, .3, 1.1))
    key.rotation_euler = (tgt_key - key.location).to_track_quat('-Z', 'Y').to_euler()
    key.data.energy = mix(0, 35, dk) * (1 if name not in ('Shudder',) else .3)
    key.data.color = (.55, .65, 1.0)
    if name == 'IntoDark':  # Steve must not read as a pure silhouette walking away
        key.location = cam.location + Vector((.6, -.3, 1.2)); key.rotation_euler = (wm(S['torso']).translation - key.location).to_track_quat('-Z', 'Y').to_euler()
        key.data.energy = 70
    rim.location = Vector((1.0, 3.5, 2.6)); rim.rotation_euler = (Vector((0, .3, 1.1)) - rim.location).to_track_quat('-Z', 'Y').to_euler()
    rim.data.energy = 220 * dk
    if name == 'Rage': rim.data.color = (1, .15, .05); rim.data.energy = 320; rim.location = wm(S['root']).translation + Vector((-.5, 2.0, 1.8))
    elif name in ('Sword', 'IntoDark'): rim.data.color = (.5, .65, 1); rim.data.energy = 260 if name == 'Sword' else 120; rim.location = (SWORD_STAND + Vector((-1.5, 2.5, 2.5))) if name == 'Sword' else Vector((-1, 6, 3))
    else: rim.data.color = (.5, .65, 1)
    rim.rotation_euler = (wm(S['torso']).translation - rim.location).to_track_quat('-Z', 'Y').to_euler() if name in ('Rage', 'Sword', 'IntoDark') else rim.rotation_euler
    for ob in (key, rim):
        rec(ob, 'location', ob.location, frame); rec(ob, 'rotation_euler', ob.rotation_euler, frame)
        rec(ob.data, 'energy', [ob.data.energy], frame); rec(ob.data, 'color', ob.data.color, frame)

# ---------------------------------------------------------------- bake
wm_cache = {}
for f in range(1, FRAMES + 1):
    t = (f - 1) / FPS
    tc = char_time(t)
    pose_alex(tc)
    pose_herobrine(tc)
    pose_steve(tc)
    pose_herobrine(tc)   # reposition after Steve (independent), keeps arm aligned to Alex
    if HIT - .01 <= t and 'exit' not in wm_cache: wm_cache['exit'] = wm(H['Rwrist']).translation.copy()
    for n in (S, A, H):
        for ob in n.values():
            rec(ob, 'location', ob.location, f); rec(ob, 'rotation_quaternion', ob.rotation_quaternion, f)
        rec(n['root'], 'scale', n['root'].scale, f)
    apply_fx(t, f)
    camera(t, f)
    # hit-stop: hold every transform of the freeze frames (characters); FX already use story time
flush()
# rotation_euler on cameras recorded once per frame via rec(); make cameras quaternion-free
# Compositor: bloom for the eyes/embers, slight vignette done in ffmpeg.
try:
    sc.use_nodes = True
except Exception: pass
try:
    ng = bpy.data.node_groups.new('CH1v2_Comp', 'CompositorNodeTree'); sc.compositing_node_group = ng
    rl = ng.nodes.new('CompositorNodeRLayers'); gl = ng.nodes.new('CompositorNodeGlare')
    for cand in ('Bloom', 'BLOOM'):
        try: gl.inputs['Type'].default_value = cand; break
        except Exception as e: print('glare', cand, e)
    print('glare type', gl.inputs['Type'].default_value)
    for nm, val in [('Threshold', 1.0), ('Size', .5), ('Strength', .35)]:
        if nm in gl.inputs: gl.inputs[nm].default_value = val
    out = ng.nodes.new('NodeGroupOutput'); ng.interface.new_socket('Image', in_out='OUTPUT', socket_type='NodeSocketColor')
    ng.links.new(rl.outputs['Image'], gl.inputs['Image']); ng.links.new(gl.outputs['Image'], out.inputs[0])
    print('compositor ok')
except Exception as e:
    print('compositor skipped', e)
sc['story_ru'] = 'Грядка → затмение → глаза в темноте → сквозной удар → остановка времени и приглашение → исчезновение → смерть Алекс → ярость → меч → во тьму'
sc.frame_set(1)
SRC.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SRC / 'ch1_intro_v2.blend'), compress=True)
print('CH1V2_READY', len(sc.objects), FRAMES)
