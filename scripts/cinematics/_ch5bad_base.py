"""Chapter V bad ending v2 (film): blade caught, table slam, deletion, Notch leaves.
Runs inside Blender (MCP execute_blender_code or --background --python). Saves the .blend; never renders."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix

ROOT = Path('/home/daydert/MinecraftSurvivors2'); SRC = ROOT / 'assets/art_source/ch5_bad_v2'
NAME = 'CH5_BadEnd_v2'; FPS = 24; LENGTH = 14.5; FRAMES = int(LENGTH * FPS)
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

TEX = ['ch5_skin_steve', 'ch5_skin_notch', 'ch5q_polished_deepslate', 'ch5q_deepslate_tiles', 'ch5q_iron_block', 'ch5q_dark_oak_planks', 'ch5q_cracked_deepslate_tiles', 'ch5q_polished_blackstone_bricks', 'iron_sword']
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
MAT['blood'] = image_material('blood_splat', blood_im, rough=.18)
MAT['wound'] = image_material('wound', wound_im, rough=.2)
MAT['blood_solid'] = material('blood_drop', color=(.30, .0, .01, 1), rough=.15, spec=.6)
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

def breathe(n, t, amp=.012, rate=1.6, phase=0.0):
    addrot(n['torso'], amp * math.sin(t * rate + phase), 0, 0)


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

