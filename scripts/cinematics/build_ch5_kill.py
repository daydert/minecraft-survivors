"""Chapter V good ending, the kill (film v3). Covers chair age 30-54 s. Opens on the game's last framing
(KILL_FILM_AT): Steve walks in with the sword while Notch shouts his two lines, a silent beat on Steve,
the overhead two-handed stab, the twist, the pull, Notch dies, a long look at Steve, he drops the blade and leaves.
Lines are drawn by the game (chapter_five_finale.CHAIR at 30.65 and 33.3); the flight after 54 s stays in game."""
import bpy, math, random
import numpy as np
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix
_base = Path('/home/daydert/MinecraftSurvivors2/scripts/cinematics/_ch5bad_base.py')
_src = _base.read_text().replace("NAME = 'CH5_BadEnd_v2'; FPS = 24; LENGTH = 14.5", "NAME = 'CH5_Kill_v2'; FPS = 24; LENGTH = 24.0")
exec(compile(_src, str(_base), 'exec'))

R = random.Random(9)
SHOUT1, SHOUT2 = .65, 3.3          # ЭЙ, УБЕРИ ЭТО / МСТИТЬ — ЭТО ДЕЛО СЛАБЫХ (subtitles drawn by the game)
WALK_IN = (.3, 2.6)
RAISE, STAB, TWIST, PULL, DROP = 5.9, 7.4, 8.8, 10.2, 15.2
TURN, WALK_OUT = (15.5, 16.6), (16.6, 23.8)

# ---------------------------------------------------------------- set
B = Batch()
for x in range(-5, 6):
    for y in range(-5, 5): B.box((x, y, -.5), (1, 1, 1), 'ch5q_polished_deepslate')
for x in range(-5, 6):
    for z in range(0, 6): B.box((x, 3.5, z + .5), (1, 1, 1), 'ch5q_deepslate_tiles' if (x + z) % 5 else 'ch5q_cracked_deepslate_tiles')
for y in range(-5, 4):
    for z in range(0, 6):
        B.box((-5.5, y, z + .5), (1, 1, 1), 'ch5q_deepslate_tiles'); B.box((5.5, y, z + .5), (1, 1, 1), 'ch5q_polished_blackstone_bricks')
B.box((2.3, 1.2, .55), (1.4, .3, 1.1), 'ch5q_polished_blackstone_bricks')   # console
B.build('room')
chair = empty('Chair', (0, 0, 0), col='Set')
CB = []
def cbox(at, size, mat='ch5q_dark_oak_planks'):
    ob = plain_box('chair_part', at, size, MAT[mat], chair, 'Set'); CB.append(ob); return ob
for dx in (-.35, .35):
    for dy in (-.35, .35): cbox((dx, dy, .25), (.12, .12, .5))
cbox((0, 0, .55), (.9, .9, .1)); cbox((0, .42, 1.15), (.9, .1, 1.1))
for sx in (-.48, .48): cbox((sx, 0, .71), (.12, .65, .08))
rope = material('rope', color=(.62, .45, .26, 1))
for z in (.95, 1.2):
    bpy.ops.mesh.primitive_torus_add(major_radius=.36, minor_radius=.025, major_segments=24, minor_segments=6, location=(0, .04, z))
    ob = bpy.context.active_object
    for c in ob.users_collection: c.objects.unlink(ob)
    link(ob, 'Set'); ob.data.materials.append(rope); ob.scale = (1, .55, 1); ob.parent = chair
screen = plain_box('Console_screen', (2.3, 1.04, .82), (1.1, .02, .5), material('scan_screen', color=(.15, 1, .45, 1), emit=4), None, 'Set')
pool_ob = plain_box('BloodPool', (0, -.15, .004), (1.6, 1.6, .004), MAT['blood'], None, 'FX')

# Blood soaks into the skins with the exact pixel pattern of the game's cinema shader (ch5_cinema_skin.gdshader),
# so the film hands over to the in-game door scene with the same bloody Steve.
def bloody_image(file, amount):
    src = image(file); W, H = src.size
    px = np.array(src.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1].copy()   # top-down like Godot UVs
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    ux = np.floor(xs / W * 64).astype(np.float32); uy = np.floor(ys / H * 64).astype(np.float32)
    frac = lambda v: v - np.floor(v)
    grain = frac(np.sin(ux * np.float32(12.9898) + uy * np.float32(78.233)) * np.float32(43758.5453))
    cluster = frac(np.sin(np.floor(ux / 3) * np.float32(31.17) + np.floor(uy / 3) * np.float32(43.71)) * np.float32(15437.71))
    stain = (cluster * .65 + grain * .35) < amount * .62
    lin = np.stack([.12 + grain * .07, np.full_like(grain, .012), np.full_like(grain, .018)], -1)
    enc = np.where(lin <= .0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - .055)
    px[..., :3] = np.where(stain[..., None], enc, px[..., :3])
    im = bpy.data.images.new(src.name + '_blood%d' % int(amount * 100), W, H, alpha=True)
    im.pixels = px[::-1].ravel(); im.pack(); return im

MIXES = []
def bleed(mat_key, file, before, after):
    """Material shows the skin at `before` blood; a keyed mix switches to `after` at the stab."""
    m = MAT[mat_key]; nt = m.node_tree; bs = nt.nodes['Principled BSDF']
    t0 = nt.nodes.new('ShaderNodeTexImage'); t0.image = bloody_image(file, before); t0.interpolation = 'Closest'
    t1 = nt.nodes.new('ShaderNodeTexImage'); t1.image = bloody_image(file, after); t1.interpolation = 'Closest'
    mx = nt.nodes.new('ShaderNodeMix'); mx.data_type = 'RGBA'
    nt.links.new(t0.outputs['Color'], mx.inputs[6]); nt.links.new(t1.outputs['Color'], mx.inputs[7]); nt.links.new(mx.outputs[2], bs.inputs['Base Color'])
    MIXES.append(mx.inputs[0])
bleed('ch5_skin_steve', 'ch5_skin_steve.png', .18, .72)
bleed('ch5_skin_notch', 'ch5_skin_notch.png', .30, .70)

S = rig('Steve', MAT['ch5_skin_steve']); N = rig('Notch', MAT['ch5_skin_notch'])
sword = voxel_item('Sword', 'iron_sword.png', S['Rwrist'], (3, 13), .05)
sword.rotation_quaternion = qrot(math.pi / 2)
n_wound = [plain_box('N_wound', (0, -.1335, .5), (.22, .004, .22), MAT['wound'], N['torso'], 'FX'),
           plain_box('N_mouth', (0, -.2565, .06), (.08, .004, .16), MAT['blood_solid'], N['head'], 'FX')]
blade_blood = plain_box('BladeBlood', (0, 0, .35), (.08, .08, .45), MAT['blood_hand'], sword, 'FX')
s_hands = [plain_box('S_blood_h', (0, 0, -.33), (.27, .27, .1), MAT['blood_hand'], S[k], 'FX') for k in ('Relbow', 'Lelbow')]
def pool(name, count, mat, size): return [plain_box(name, (0, 0, -50), (size, size, size), MAT[mat], None, 'FX') for _ in range(count)]
P_blood = pool('blood', 230, 'blood_solid', .03)
for ob in P_blood: ob.rotation_mode = 'XYZ'
MAT['blood_solid'].node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .35
MAT['blood'].node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .4

# ---------------------------------------------------------------- lights (brighter: same exposure as the game's chair and door scenes)
def light(name, typ, energy, color, at=(0, 0, 5), size=1.0):
    d = bpy.data.lights.new('LGT_CH5K_' + name, typ); d.energy = energy; d.color = color
    if typ == 'AREA': d.shape = 'DISK'; d.size = size
    if typ in ('POINT', 'SPOT'): d.shadow_soft_size = size
    ob = link(bpy.data.objects.new(d.name, d), 'Lights'); ob.location = at; return ob
def aim(ob, at): ob.rotation_euler = (Vector(at) - ob.location).to_track_quat('-Z', 'Y').to_euler()
lamp = light('Lamp', 'SPOT', 950, (1, .92, .8), (0, -.2, 3.4), .15); lamp.data.spot_size = 1.15; lamp.data.spot_blend = .5
bulb = plain_box('Bulb', (0, -.2, 3.45), (.16, .16, .16), material('bulb', color=(1, .9, .7, 1), emit=12), None, 'Set')
fill = light('Fill', 'AREA', 300, (.62, .7, 1), (-2.5, -3.5, 2.6), 4); aim(fill, (0, 0, 1))
fill2 = light('Fill2', 'AREA', 200, (.85, .9, 1), (2.4, -3.2, 2.5), 4); aim(fill2, (0, 0, 1))
glow = light('Console', 'POINT', 60, (.3, 1, .6), (2.0, .7, 1.2), .3)
rim = light('Rim', 'AREA', 260, (.6, .7, 1), (1.5, 2.8, 2.6), 3); aim(rim, (0, 0, 1))
face_key = light('FaceKey', 'AREA', 0, (1, .93, .85), (0, -2, 1.8), .8)
bg.inputs[0].default_value = (.02, .022, .03, 1); bg.inputs[1].default_value = .35

# ---------------------------------------------------------------- acting
S0 = V(-1.7, -1.65); STAB_SPOT = V(-.3, -.78)     # S0 = Steve's place in the game's last chair frame
YS = yaw_to(S0, V(0, 0)); YF = yaw_to(STAB_SPOT, V(0, 0))
CHEST = Vector((0, -.08, 1.05))
BACK_SPOT = STAB_SPOT + (STAB_SPOT - V(0, 0)).normalized() * .55
EXIT = V(3.9, -2.2)
OUT_PATH = Path2([BACK_SPOT, V(1.2, -1.75), EXIT])

def aim_blade(n, d):
    parent = wm(n['Relbow']).to_quaternion()
    n['Rwrist'].rotation_quaternion = parent.inverted() @ Vector((0, -1, 0)).rotation_difference(Vector(d).normalized())

def pose_notch(t):
    reset(N, (0, .05, 0), 0, .63)
    rot(N['Rleg'], -1.5, 0, .05); rot(N['Lleg'], -1.5, 0, -.05); rot(N['Rknee'], 1.45); rot(N['Lknee'], 1.45)
    struggle = sm(.5, .65, t) * (1 - sm(2.6, 3.0, t)) + .9 * sm(3.2, 3.35, t) * (1 - sm(6.0, 6.5, t)) + .25 * sm(3.0, 3.2, t) * (1 - sm(3.2, 3.35, t))
    jerk = math.sin(t * 17) * struggle
    alive = 1 - sm(STAB + .2, PULL + 1.3, t)
    conv = math.sin(t * 23) * sm(STAB, STAB + .05, t) * (1 - sm(STAB + .2, PULL - .2, t)) * alive
    lean = .25 * sm(3.2, 3.5, t) * (1 - sm(5.8, 6.6, t)) + .1 * sm(.5, .8, t) * (1 - sm(2.6, 3.0, t))
    dread = sm(6.3, 7.0, t) * (1 - sm(STAB, STAB + .05, t))           # stares up at the raised blade
    hit = sm(STAB, STAB + .06, t) * (1 - sm(STAB + .3, STAB + 1.0, t))
    twist = sm(TWIST, TWIST + .1, t) * (1 - sm(TWIST + .4, TWIST + 1.0, t))
    dead = sm(PULL + .3, PULL + 1.5, t)
    rot(N['torso'], lean - .25 * hit - .12 * twist + .35 * dead, .05 * jerk, .12 * jerk + .06 * conv)
    rot(N['head'], -.3 * struggle - .45 * dread - .5 * hit - .3 * twist + .25 * conv + .7 * dead, .25 * jerk, .2 * dead)
    for side, sx in (('R', -1), ('L', 1)):
        p = Vector((sx * .46, -.22 + .05 * math.sin(t * 19 + sx) * struggle, .8 + .03 * abs(jerk)))
        hand(N, side, p, pole=wm(N[side + 'arm']).translation + Vector((sx * .6, .2, -.4)))
    chair.rotation_mode = 'XYZ'; chair.rotation_euler = (.02 * jerk, 0, .015 * jerk)

def pose_steve(t):
    if t < WALK_IN[1]:
        # Walks in from where the game left him, sword hanging point-down in the right hand.
        y = locomote(S, t, WALK_IN[0], WALK_IN[1], S0, STAB_SPOT, YS, stride=.55, ease_in=True, ease_out=True)
        yaw = mix(YS, YF, sm(WALK_IN[1] - .6, WALK_IN[1], t)); S['root'].rotation_quaternion = qrot(z=yaw)
        base = S['root'].location.copy()
        hand(S, 'R', base + fwd(yaw) * .12 + right(yaw) * .34 + Vector((0, 0, .72)))
        aim_blade(S, fwd(yaw) * .5 + Vector((0, 0, -1)))
        look(S, wm(N['head']).translation, amount=1)
        return
    if t < DROP:
        back_k = sm(PULL + .2, PULL + 1.4, t)
        base = STAB_SPOT + (STAB_SPOT - V(0, 0)).normalized() * .55 * back_k
        reset(S, base, YF, .74)
        k = 1.0
        stand(S, YF, .17, (.12 + .1 * k, -.18))
        yaw = YF
        loc = lambda q: base + fwd(yaw) * q[0] + right(yaw) * q[1] + Vector((0, 0, q[2]))
        grip_low = loc((.3, .2, .78)); overhead = loc((.15, .05, 2.05)); impact = CHEST + Vector((0, -.32, .32))
        g = grip_low.lerp(overhead, sm(RAISE, RAISE + .7, t)) if t < STAB - .1 else overhead.lerp(impact, ei(STAB - .1, STAB, t))
        if t >= STAB:
            g = impact + Vector((0, .04 * sm(STAB, TWIST, t), -.05 * sm(TWIST, TWIST + .3, t)))
            if t >= PULL: g = g.lerp(loc((.35, .1, 1.05)), eo(PULL, PULL + .35, t)).lerp(loc((.3, .25, .7)), sm(PULL + .9, PULL + 2.2, t))
        hand(S, 'R', g)
        two = sm(RAISE - .3, RAISE, t) * (1 - sm(PULL + .5, PULL + 1.0, t))
        hand(S, 'L', (base + fwd(yaw) * .12 - right(yaw) * .34 + Vector((0, 0, .72))).lerp(g + right(yaw) * -.08 + Vector((0, 0, -.06)), two))
        if t < RAISE: aim_blade(S, fwd(yaw) * .6 + Vector((0, 0, -1)))
        elif t < PULL + .35: aim_blade(S, (CHEST - g) * 1.0 + Vector((0, 0, -.25)))
        else: aim_blade(S, Vector((0, 0, -1)) + fwd(yaw) * .15)
        if TWIST <= t < PULL:
            S['Rwrist'].rotation_quaternion = S['Rwrist'].rotation_quaternion @ qrot(0, 0, .9 * sm(TWIST, TWIST + .25, t))
        lean = .25 * sm(STAB - .1, STAB, t) * (1 - sm(PULL, PULL + .6, t)) + .1 * sm(PULL + 1.0, PULL + 2.2, t)
        rot(S['torso'], lean + .08 * sm(RAISE, RAISE + .6, t) * (1 - sm(STAB - .3, STAB, t)), 0, 0)
        breathe(S, t, .02 + .025 * sm(PULL + 1, PULL + 2, t), 3.2)
        look(S, wm(N['head']).translation, amount=1)
        if t > PULL + 2.5: addrot(S['head'], .12 * sm(PULL + 2.5, PULL + 3.5, t), 0, 0)
        return
    # Lets the blade fall, turns away and walks out of the room past the console.
    turn = sm(*TURN, t)
    y0 = YF; y1 = math.atan2(*(lambda d: (d.x, -d.y))(OUT_PATH.dir(0)))
    if t < WALK_OUT[0]:
        yaw = y0 + ((y1 - y0 + math.pi) % math.tau - math.pi) * turn
        reset(S, BACK_SPOT, yaw, .74); stand(S, yaw, .15)
        hand(S, 'R', BACK_SPOT + fwd(yaw) * .1 + right(yaw) * .34 + Vector((0, 0, .72)))
        hand(S, 'L', BACK_SPOT + fwd(yaw) * .1 - right(yaw) * .34 + Vector((0, 0, .72)))
        look(S, wm(N['head']).translation, amount=1 - turn)
        addrot(S['head'], .1 * (1 - turn), 0, 0)
    else:
        locomote_path(S, t, WALK_OUT[0], WALK_OUT[1], OUT_PATH, stride=.58, start_yaw=y1)

# ---------------------------------------------------------------- FX
cache = {}
def rec_val(sock, v, frame, idx=None):
    node = sock.node; nt = node.id_data; sidx = list(node.inputs).index(sock)
    REC.setdefault((nt, 'nodes["%s"].inputs[%d].default_value' % (node.name, sidx), idx or 0), []).append((frame, float(v)))

def apply_fx(t, frame):
    on = lambda ob, v: (setattr(ob, 'scale', (1, 1, 1) if v else (.0001,) * 3), rec(ob, 'scale', ob.scale, frame))
    for sock in MIXES: rec_val(sock, 1.0 if t >= STAB + .04 else 0.0, frame)
    for ob in s_hands: on(ob, t >= STAB + .04)
    for ob in n_wound: on(ob, t >= STAB)
    on(blade_blood, t >= STAB)
    if t >= DROP:
        if 'drop' not in cache: cache['drop'] = (wm(sword).translation.copy(), wm(sword).to_quaternion())
        p0, q0 = cache['drop']; k = clamp((t - DROP) / .35)
        loc = p0.lerp(Vector((p0.x, p0.y, .03)), k * k)
        world = Matrix.Translation(loc) @ q0.slerp(Quaternion((1, 0, 0), math.pi / 2) @ qrot(0, 0, .8), k).to_matrix().to_4x4()
        local = wm(S['Rwrist']).inverted() @ world
        sword.location = local.to_translation(); sword.rotation_quaternion = local.to_quaternion()
    else:
        sword.location = (0, 0, 0); sword.rotation_quaternion = qrot(math.pi / 2)
    rec(sword, 'location', sword.location, frame); rec(sword, 'rotation_quaternion', sword.rotation_quaternion, frame)
    # Blood: fine droplets in streams. Stab: a burst back along the blade into Steve; twist: a spurt;
    # pull: a pulsing jet for a second; then drips from the blade, the chest and the chair.
    rnd = random.Random(4)
    toward_steve = (Vector((STAB_SPOT.x, STAB_SPOT.y, 1.25)) - CHEST).normalized()
    for i, ob in enumerate(P_blood):
        if i < 170:
            if i < 80: at = STAB + rnd.uniform(0, .08)
            elif i < 105: at = TWIST + rnd.uniform(0, .1)
            else: at = PULL + rnd.uniform(0, 1.1) * (1 if i >= 125 else .05)
            dt = t - at
            if dt < 0 or dt > 1.6: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
            else:
                key = 'b%d' % i
                if key not in cache: cache[key] = CHEST + Vector((rnd.uniform(-.06, .06), -.15, rnd.uniform(-.04, .08)))
                if i < 80:      # back along the blade, into Steve and the floor between them
                    v = (toward_steve + Vector((rnd.uniform(-.45, .45), rnd.uniform(-.3, .3), rnd.uniform(-.1, .5)))) * rnd.uniform(1.2, 3.2)
                elif i >= 125:  # pulsing jet after the pull: tight cone, speed beats with the heart
                    pulse = .6 + .4 * abs(math.sin((at - PULL) * 7.5))
                    v = (Vector((0, -1, .35)) + Vector((rnd.uniform(-.12, .12), 0, rnd.uniform(-.08, .1)))) * 2.2 * pulse
                else:
                    v = Vector((rnd.uniform(-1, 1), rnd.uniform(-2.0, -.6), rnd.uniform(.2, 1.4))) * rnd.uniform(.7, 2.0)
                p = cache[key] + v * dt + Vector((0, 0, -4.9 * dt * dt))
                if p.z < .01: p.z = .006; ob.scale = (2.2, 2.2, .12)
                else:
                    sp = (v + Vector((0, 0, -9.8 * dt))).length; ob.scale = (1, 1, 1 + min(2.5, sp * .5))
                    ob.rotation_euler = (Vector((0, 0, 1)).rotation_difference((v + Vector((0, 0, -9.8 * dt))).normalized())).to_euler()
                ob.location = p
        else:
            period = .42 + (i % 6) * .11; ph = ((t - STAB) % period) / period
            if t < STAB + .4: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
            else:
                src = (wm(sword) @ Vector((0, 0, .62))) if (i % 2 and t < DROP) else (CHEST + Vector((rnd.uniform(-.1, .1), -.14, -.35)))
                ob.location = src + Vector((0, 0, -4.9 * (ph * period) ** 2)); ob.scale = (1, 1, 2.0)
                if ob.location.z < .005: ob.location.z = .005; ob.scale = (1.8, 1.8, .1)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame); rec(ob, 'rotation_euler', ob.rotation_euler, frame)
    g = sm(STAB + .5, 20.0, t); pool_ob.scale = (.15 + .95 * g, .15 + .9 * g, 1) if t > STAB + .4 else (.0001,) * 3; rec(pool_ob, 'scale', pool_ob.scale, frame)
    swing = .2 * math.sin((t - STAB) * 4.5) * math.exp(-max(0, t - STAB) * .5) if t > STAB else 0
    lamp.rotation_mode = 'XYZ'; lamp.rotation_euler = (swing, swing * .5, 0); rec(lamp, 'rotation_euler', lamp.rotation_euler, frame)
    flick = .3 if (STAB < t < STAB + 1.2 and int(t * 24) % 3 == 0) else 1.0
    lamp.data.energy = 950 * flick; rec(lamp.data, 'energy', [lamp.data.energy], frame)
    bulb.location = lamp.location + Vector((0, 0, .05)); rec(bulb, 'location', bulb.location, frame)
    red = 1.0 if STAB < t < STAB + 2 and int(t * 10) % 2 == 0 else 0.0
    glow.data.color = (.3 + .7 * red, 1 - .9 * red, .6 - .5 * red); rec(glow.data, 'color', glow.data.color, frame)

# ---------------------------------------------------------------- cameras
SHOTS = [('Open', 0, 2.7, 27), ('Scream', 2.7, 5.2, 40), ('SteveFace', 5.2, 6.35, 45), ('Raise', 6.35, STAB - .05, 24),
         ('Stab', STAB - .05, 8.6, 32), ('Twist', 8.6, 10.9, 40), ('Face', 10.9, DROP - .2, 40), ('Away', DROP - .2, 30, 28)]
CAMS = {}
for name, a, b, lens in SHOTS:
    d = bpy.data.cameras.new('CAM_CH5K_' + name); d.lens = lens; d.sensor_width = 36; d.clip_start = .05; d.clip_end = 80
    d.dof.use_dof = True
    cam = link(bpy.data.objects.new(d.name, d), 'Cameras'); CAMS[name] = cam
    sc.timeline_markers.new(name, frame=round(a * FPS) + 1).camera = cam
sc.camera = CAMS['Open']

def place(cam, pos, tgt, lens, focus, fstop=2.8, roll=0.0, extra=(0, 0)):
    cam.location = Vector(pos)
    q = (Vector(tgt) - Vector(pos)).to_track_quat('-Z', 'Y') @ Quaternion((0, 0, 1), roll) @ Quaternion((1, 0, 0), extra[0]) @ Quaternion((0, 1, 0), extra[1])
    cam.rotation_mode = 'XYZ'; cam.rotation_euler = q.to_euler('XYZ', cam.rotation_euler)
    cam.data.lens = lens; cam.data.dof.focus_distance = max(.2, (Vector(focus) - Vector(pos)).length); cam.data.dof.aperture_fstop = fstop
def orbit(c, az, el, d):
    az = math.radians(az); el = math.radians(el)
    return Vector(c) + Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * d
def shake(t):
    rx = ry = 0.0
    for t0, amp, dur, fq in [(STAB, .07, .7, 11), (TWIST, .02, .35, 15), (PULL, .035, .45, 12), (DROP + .35, .012, .3, 14)]:
        dt = t - t0
        if 0 <= dt <= dur: env = (1 - dt / dur) ** 2; rx += amp * env * math.sin(dt * fq * math.tau + 1.3); ry += amp * .6 * env * math.sin(dt * fq * 1.37 * math.tau)
    return rx, ry

def clear_orbit(c, azs, el, dist, avoid, need=.42):
    best = None; best_gap = -1
    for az in azs:
        pos = orbit(c, az, el, dist); seg = Vector(c) - pos; L = seg.length; gap = 9.0
        for a in avoid:
            k = max(0.0, min(1.0, (Vector(a) - pos).dot(seg) / (L * L)))
            gap = min(gap, (pos + seg * k - Vector(a)).length)
        if gap > need: return pos
        if gap > best_gap: best_gap = gap; best = pos
    return best

def camera(t, frame):
    for name, a, b, lens in SHOTS:
        if a <= t < b: break
    cam = CAMS[name]; u = sm(a, b, t); sh = shake(t); hh = (math.sin(t * 1.1) * .003 + sh[0], math.sin(t * .8 + 1) * .002 + sh[1])
    hs = wm(S['head']) @ Vector((0, 0, .25)); hn = wm(N['head']) @ Vector((0, 0, .25))
    face_key.data.energy = 0
    if name == 'Open':
        # starts exactly on the game's last chair framing (cinema track 'chair' at 29.6 s), then creeps in
        k = sm(0, 2.7, t)
        place(cam, Vector((3.2, -3.5, 1.65)).lerp(Vector((2.55, -2.95, 1.55)), k), Vector((-.55, -.7, 1.1)).lerp(Vector((-.45, -.5, 1.15)), k), 27.1, hn, 5.0, extra=hh)
    elif name == 'Scream':
        av = [hs, wm(S['torso']) @ Vector((0, 0, .4))]
        place(cam, clear_orbit(hn, [42, 55, 32, 68], -4, mix(1.75, 1.5, u), av), hn + Vector((0, 0, -.12)), lens, hn, 2.4, roll=.03, extra=hh)
    elif name == 'SteveFace':
        yawd = math.degrees(YF)
        av = [hn, wm(N['torso']) @ Vector((0, 0, .4)), Vector((0, .42, 1.15))]
        c = hs.lerp(hn, .3) + Vector((0, 0, -.08))
        place(cam, orbit(c, yawd - 92, -4, mix(1.9, 1.7, u)), c, lens, hs, 2.6, extra=hh)
        face_key.location = orbit(hs, yawd - 25, 15, 1.4); aim(face_key, hs); face_key.data.energy = 35
    elif name == 'Raise':
        c = (hs + hn) / 2 + Vector((0, 0, .2))
        place(cam, clear_orbit(c, [62, 75, 50, 90], 2, 3.3, [Vector((0, .42, 1.15))]), c, lens, hs, 4.0, roll=-.04, extra=hh)
    elif name == 'Stab':
        c = CHEST + Vector((-.15, -.3, .15)); place(cam, orbit(c, 70, 4, 2.5), c, lens, c, 3.5, extra=hh)
    elif name == 'Twist':
        c = (hs + hn) / 2 + Vector((0, 0, -.1))
        place(cam, clear_orbit(c, [70, 82, 58, 95], 2, mix(2.6, 2.2, u), [Vector((0, .42, 1.15))]), c, lens, hs, 3.2, roll=.04, extra=hh)
    elif name == 'Face':
        # a long look at Steve: medium close, lit from the lamp side so his face and the blood read
        yawd = math.degrees(S['root'].rotation_quaternion.to_euler().z)
        av = [hn, wm(N['torso']) @ Vector((0, 0, .4)), Vector((0, .42, 1.15))]
        c = hs.lerp(hn, .18) + Vector((0, 0, -.15))
        place(cam, orbit(c, yawd - 70, -4, mix(2.1, 1.8, u)), c, lens, hs, 2.8, extra=hh)
        face_key.location = orbit(hs, yawd - 25, 20, 1.3); aim(face_key, hs); face_key.data.energy = 40
    else:
        c = Vector((.8, -.6, 1.0)); place(cam, orbit(c, mix(-12, -4, u), 10, mix(5.0, 4.5, u)), c, lens, Vector((0, 0, 1.0)), 5.0, extra=hh)
    rec(face_key, 'location', face_key.location, frame); rec(face_key, 'rotation_euler', face_key.rotation_euler, frame); rec(face_key.data, 'energy', [face_key.data.energy], frame)
    rec(cam, 'location', cam.location, frame); rec(cam, 'rotation_euler', cam.rotation_euler, frame)
    rec(cam.data, 'lens', [cam.data.lens], frame); rec(cam.data, 'dof.focus_distance', [cam.data.dof.focus_distance], frame)

def hitstop(t):
    if STAB <= t < STAB + .14: return STAB
    if PULL <= t < PULL + .06: return PULL
    return t

for f in range(1, FRAMES + 1):
    t = (f - 1) / FPS; ta = hitstop(t)
    pose_notch(ta); pose_steve(ta); pose_notch(ta)
    for n in (S, N):
        for ob in n.values(): rec(ob, 'location', ob.location, f); rec(ob, 'rotation_quaternion', ob.rotation_quaternion, f)
        rec(n['root'], 'scale', n['root'].scale, f)
    rec(chair, 'rotation_euler', chair.rotation_euler, f)
    apply_fx(t, f)
    camera(t, f)
flush()
try:
    ng = bpy.data.node_groups.new('CH5K_Comp', 'CompositorNodeTree'); sc.compositing_node_group = ng
    rl = ng.nodes.new('CompositorNodeRLayers'); gl = ng.nodes.new('CompositorNodeGlare'); gl.inputs['Type'].default_value = 'Bloom'
    for nm, val in [('Threshold', 1.0), ('Size', .5), ('Strength', .3)]: gl.inputs[nm].default_value = val
    out = ng.nodes.new('NodeGroupOutput'); ng.interface.new_socket('Image', in_out='OUTPUT', socket_type='NodeSocketColor')
    ng.links.new(rl.outputs['Image'], gl.inputs['Image']); ng.links.new(gl.outputs['Image'], out.inputs[0])
except Exception as e: print('compositor skipped', e)
sc.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(SRC / 'ch5_kill_v2.blend'), compress=True)
print('CH5KILL_READY', len(sc.objects), FRAMES)
