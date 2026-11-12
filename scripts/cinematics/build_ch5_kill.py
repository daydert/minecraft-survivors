"""Chapter V good ending, the kill (film v2). Covers chair age 30-44 s: the scream at the blade,
the two-handed stab through the chest, the twist, the pull, the dripping blade, Steve walks away.
Dialogue before 30 s stays in game (scan, memories); the flight after 44 s stays in game."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix
_base = Path('/home/daydert/MinecraftSurvivors2/scripts/cinematics/_ch5bad_base.py')
_src = _base.read_text().replace("NAME = 'CH5_BadEnd_v2'; FPS = 24; LENGTH = 14.5", "NAME = 'CH5_Kill_v2'; FPS = 24; LENGTH = 14.0")
exec(compile(_src, str(_base), 'exec'))

R = random.Random(9)
SHOUT1, SHOUT2 = .65, 1.7          # ЭЙ, УБЕРИ ЭТО / МСТИТЬ — ЭТО ДЕЛО СЛАБЫХ (subtitles drawn by the game)
RAISE, STAB, TWIST, PULL, DROP = 2.2, 3.0, 4.2, 5.45, 9.6

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

S = rig('Steve', MAT['ch5_skin_steve']); N = rig('Notch', MAT['ch5_skin_notch'])
sword = voxel_item('Sword', 'iron_sword.png', S['Rwrist'], (3, 13), .05)
sword.rotation_quaternion = qrot(math.pi / 2)
s_blood = [plain_box('S_blood', (x, -.2565, z), (w, .004, h), MAT['blood'], S['head'], 'FX') for x, z, w, h in [(-.08, .22, .2, .18), (.12, .1, .14, .16)]]
s_blood += [plain_box('S_blood_b', (0, -.1335, .45), (.42, .004, .5), MAT['blood'], S['torso'], 'FX')]
s_blood += [plain_box('S_blood_h', (0, 0, -.33), (.27, .27, .1), MAT['blood_hand'], S[k], 'FX') for k in ('Relbow', 'Lelbow')]
n_wound = [plain_box('N_wound', (0, -.1335, .5), (.22, .004, .22), MAT['wound'], N['torso'], 'FX'),
           plain_box('N_stain', (0, -.135, .32), (.46, .004, .55), MAT['blood'], N['torso'], 'FX'),
           plain_box('N_mouth', (0, -.2565, .06), (.08, .004, .16), MAT['blood_solid'], N['head'], 'FX')]
blade_blood = plain_box('BladeBlood', (0, 0, .35), (.08, .08, .45), MAT['blood_hand'], sword, 'FX')
def pool(name, count, mat, size): return [plain_box(name, (0, 0, -50), (size, size, size), MAT[mat], None, 'FX') for _ in range(count)]
P_blood = pool('blood', 120, 'blood_solid', .04)
for ob in P_blood: ob.rotation_mode = 'XYZ'

# ---------------------------------------------------------------- lights
def light(name, typ, energy, color, at=(0, 0, 5), size=1.0):
    d = bpy.data.lights.new('LGT_CH5K_' + name, typ); d.energy = energy; d.color = color
    if typ == 'AREA': d.shape = 'DISK'; d.size = size
    if typ in ('POINT', 'SPOT'): d.shadow_soft_size = size
    ob = link(bpy.data.objects.new(d.name, d), 'Lights'); ob.location = at; return ob
lamp = light('Lamp', 'SPOT', 700, (1, .9, .75), (0, -.2, 3.4), .15); lamp.data.spot_size = 1.0; lamp.data.spot_blend = .5
bulb = plain_box('Bulb', (0, -.2, 3.45), (.16, .16, .16), material('bulb', color=(1, .9, .7, 1), emit=12), None, 'Set')
fill = light('Fill', 'AREA', 140, (.5, .6, 1), (-3, -3.5, 2.6), 4)
fill.rotation_euler = (Vector((0, 0, 1)) - Vector((-3, -3.5, 2.6))).to_track_quat('-Z', 'Y').to_euler()
glow = light('Console', 'POINT', 40, (.3, 1, .6), (2.0, .7, 1.2), .3)
rim = light('Rim', 'AREA', 120, (.6, .7, 1), (1.5, 2.8, 2.6), 3)
rim.rotation_euler = (Vector((0, 0, 1)) - Vector((1.5, 2.8, 2.6))).to_track_quat('-Z', 'Y').to_euler()
bg.inputs[0].default_value = (.01, .01, .015, 1); bg.inputs[1].default_value = .15

# ---------------------------------------------------------------- acting
S0 = V(-1.15, -1.25); YS = yaw_to(S0, V(0, 0)); STAB_SPOT = V(-.3, -.78)
YF = math.degrees(yaw_to(STAB_SPOT, V(0, 0)))
CHEST = Vector((0, -.08, 1.05))

def aim_blade(n, d):
    parent = wm(n['Relbow']).to_quaternion()
    n['Rwrist'].rotation_quaternion = parent.inverted() @ Vector((0, -1, 0)).rotation_difference(Vector(d).normalized())

def pose_notch(t):
    reset(N, (0, .05, 0), 0, .63)
    rot(N['Rleg'], -1.5, 0, .05); rot(N['Lleg'], -1.5, 0, -.05); rot(N['Rknee'], 1.45); rot(N['Lknee'], 1.45)
    struggle = (sm(.55, .7, t) * (1 - sm(1.6, 1.8, t))) + .7 * sm(1.7, 1.8, t) * (1 - sm(2.7, 2.95, t))
    jerk = math.sin(t * 17) * struggle
    alive = 1 - sm(STAB + .2, 6.5, t)
    conv = math.sin(t * 23) * sm(STAB, STAB + .05, t) * (1 - sm(STAB + .2, 5.2, t)) * alive
    lean = .25 * sm(1.7, 1.9, t) * (1 - sm(2.8, STAB, t))
    hit = sm(STAB, STAB + .06, t) * (1 - sm(STAB + .3, STAB + 1.0, t))
    dead = sm(5.6, 6.6, t)
    rot(N['torso'], lean - .25 * hit + .35 * dead, .05 * jerk, .12 * jerk + .06 * conv)
    rot(N['head'], -.3 * struggle - .5 * hit + .25 * conv + .7 * dead, .25 * jerk, .2 * dead)
    for side, sx in (('R', -1), ('L', 1)):
        p = Vector((sx * .46, -.22 + .05 * math.sin(t * 19 + sx) * struggle, .8 + .03 * abs(jerk)))
        hand(N, side, p, pole=wm(N[side + 'arm']).translation + Vector((sx * .6, .2, -.4)))
    # The chair rattles with him.
    chair.rotation_mode = 'XYZ'; chair.rotation_euler = (.02 * jerk, 0, .015 * jerk)

def pose_steve(t):
    if t < 9.0:
        k = sm(1.9, 2.5, t)
        base = S0.lerp(STAB_SPOT, k)
        back_k = sm(PULL + .2, 6.6, t)
        base = base + (base - V(0, 0)).normalized() * .55 * back_k
        reset(S, base, mix(YS, yaw_to(STAB_SPOT, V(0, 0)), k), .74)
        stand(S, S['root'].rotation_quaternion.to_euler().z, .17, (.12 + .1 * k, -.18))
        yaw = S['root'].rotation_quaternion.to_euler().z
        loc = lambda q: base + fwd(yaw) * q[0] + right(yaw) * q[1] + Vector((0, 0, q[2]))
        grip_low = loc((.3, .2, .78)); overhead = loc((.15, .05, 2.05)); impact = CHEST + Vector((0, -.32, .32))
        g = grip_low.lerp(overhead, sm(RAISE, 2.6, t) if t < STAB - .08 else 1)
        if t >= STAB - .08: g = overhead.lerp(impact, ei(STAB - .08, STAB, t))
        if t >= STAB:
            g = impact + Vector((0, .04 * sm(STAB, TWIST, t), -.05 * sm(TWIST, TWIST + .3, t)))
            if t >= PULL: g = g.lerp(loc((.35, .1, 1.05)), eo(PULL, PULL + .35, t)).lerp(loc((.3, .25, .7)), sm(6.2, 7.2, t))
        hand(S, 'R', g); hand(S, 'L', g + right(yaw) * -.08 + Vector((0, 0, -.06)))
        # Blade: down along the stab line, twisted, then hanging and dripping.
        if t < RAISE: aim_blade(S, fwd(yaw) * .6 + Vector((0, 0, -1)))
        elif t < PULL + .35: aim_blade(S, (CHEST - g) * 1.0 + Vector((0, 0, -.25)))
        else: aim_blade(S, Vector((0, 0, -1)) + fwd(yaw) * .15)
        if TWIST <= t < PULL:
            S['Rwrist'].rotation_quaternion = S['Rwrist'].rotation_quaternion @ qrot(0, 0, .9 * sm(TWIST, TWIST + .25, t))
        lean = .25 * sm(STAB - .1, STAB, t) * (1 - sm(PULL, PULL + .6, t)) + .1 * sm(6.0, 7.0, t)
        rot(S['torso'], lean + .08 * sm(RAISE, 2.8, t) * (1 - sm(2.85, STAB, t)), 0, 0)
        breathe(S, t, .025 + .02 * sm(6, 7, t), 3.5)
        look(S, wm(N['head']).translation, amount=1)
        if t > 7.2: addrot(S['head'], .12 * sm(7.2, 8.0, t), 0, 0)
        return
    # Drops the blade and walks out of frame toward the door (screen right).
    door = V(3.6, -1.6)
    back_spot = STAB_SPOT + (STAB_SPOT - V(0, 0)).normalized() * .55
    reset(S, back_spot, yaw_to(back_spot, door), .74)
    turn = sm(9.0, 10.2, t)
    yaw = mix(yaw_to(back_spot, V(0, 0)), yaw_to(back_spot, door), turn)
    if t < 10.2:
        reset(S, back_spot, yaw, .74); stand(S, yaw, .15)
        hand(S, 'R', back_spot + fwd(yaw) * .25 + right(yaw) * .3 + Vector((0, 0, .7)))
        hand(S, 'L', back_spot + fwd(yaw) * .15 - right(yaw) * .3 + Vector((0, 0, .7)))
        look(S, wm(N['head']).translation, amount=1 - turn)
    else:
        locomote(S, t, 10.2, 14.5, back_spot, door, yaw_to(back_spot, door), stride=.6, ease_in=True, ease_out=False)

# ---------------------------------------------------------------- FX
cache = {}
def apply_fx(t, frame):
    on = lambda ob, v: (setattr(ob, 'scale', (1, 1, 1) if v else (.0001,) * 3), rec(ob, 'scale', ob.scale, frame))
    for ob in s_blood: on(ob, t >= STAB + .03)
    for ob in n_wound: on(ob, t >= STAB)
    on(blade_blood, t >= STAB)
    # Sword falls from his hand at DROP and lies on the floor.
    if t >= DROP:
        if 'drop' not in cache: cache['drop'] = (wm(sword).translation.copy(), wm(sword).to_quaternion())
        p0, q0 = cache['drop']; k = clamp((t - DROP) / .35)
        sword.parent = None if False else sword.parent
        loc = p0.lerp(Vector((p0.x, p0.y, .03)), k * k)
        world = Matrix.Translation(loc) @ q0.slerp(Quaternion((1, 0, 0), math.pi / 2) @ qrot(0, 0, .8), k).to_matrix().to_4x4()
        local = wm(S['Rwrist']).inverted() @ world
        sword.location = local.to_translation(); sword.rotation_quaternion = local.to_quaternion()
    else:
        sword.location = (0, 0, 0); sword.rotation_quaternion = qrot(math.pi / 2)
    rec(sword, 'location', sword.location, frame); rec(sword, 'rotation_quaternion', sword.rotation_quaternion, frame)
    # Blood: the stab burst, the twist spurt, the pull spray, then drips from the blade and the chair.
    rnd = random.Random(4)
    for i, ob in enumerate(P_blood):
        if i < 90:
            at = STAB if i < 50 else TWIST if i < 66 else PULL
            dt = t - at
            if dt < 0 or dt > 1.5: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
            else:
                key = 'b%d' % i
                if key not in cache: cache[key] = CHEST + Vector((rnd.uniform(-.08, .08), -.15, rnd.uniform(-.05, .1)))
                v = Vector((rnd.uniform(-1, 1), rnd.uniform(-2.2, -.6), rnd.uniform(.2, 1.6))) * rnd.uniform(.8, 2.4) * (1.3 if at == PULL else 1)
                p = cache[key] + v * dt + Vector((0, 0, -4.9 * dt * dt))
                if p.z < .01: p.z = .006; ob.scale = (1.6, 1.6, .1)
                else: ob.scale = (1, 1, 1.7)
                ob.location = p
        else:
            period = .45 + (i % 6) * .11; ph = ((t - STAB) % period) / period
            if t < STAB + .4: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
            else:
                src = (wm(sword) @ Vector((0, 0, .62))) if (i % 2 and t < DROP) else (CHEST + Vector((rnd.uniform(-.1, .1), -.14, -.35)))
                ob.location = src + Vector((0, 0, -4.9 * (ph * period) ** 2)); ob.scale = (1, 1, 1.8)
                if ob.location.z < .005: ob.location.z = .005; ob.scale = (1.4, 1.4, .1)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame)
    g = sm(STAB + .5, 13.0, t); pool_ob.scale = (.15 + .85 * g, .15 + .85 * g, 1) if t > STAB + .4 else (.0001,) * 3; rec(pool_ob, 'scale', pool_ob.scale, frame)
    # Lamp swings and flickers from the blow; the console stutters red.
    swing = .2 * math.sin((t - STAB) * 4.5) * math.exp(-max(0, t - STAB) * .5) if t > STAB else 0
    lamp.rotation_mode = 'XYZ'; lamp.rotation_euler = (swing, swing * .5, 0); rec(lamp, 'rotation_euler', lamp.rotation_euler, frame)
    flick = .25 if (STAB < t < STAB + 1.2 and int(t * 24) % 3 == 0) else 1.0
    lamp.data.energy = 700 * flick; rec(lamp.data, 'energy', [lamp.data.energy], frame)
    bulb.location = lamp.location + Vector((0, 0, .05)); rec(bulb, 'location', bulb.location, frame)
    red = 1.0 if STAB < t < STAB + 2 and int(t * 10) % 2 == 0 else 0.0
    glow.data.color = (.3 + .7 * red, 1 - .9 * red, .6 - .5 * red); rec(glow.data, 'color', glow.data.color, frame)

# ---------------------------------------------------------------- cameras
SHOTS = [('Blade', 0, .6, 50), ('Scream', .6, 1.9, 40), ('Raise', 1.9, 2.92, 24), ('Stab', 2.92, 4.0, 32), ('Twist', 4.0, 5.9, 45),
         ('Face', 5.9, 9.0, 55), ('Away', 9.0, 14.0, 30)]
CAMS = {}
for name, a, b, lens in SHOTS:
    d = bpy.data.cameras.new('CAM_CH5K_' + name); d.lens = lens; d.sensor_width = 36; d.clip_start = .05; d.clip_end = 80
    d.dof.use_dof = True
    cam = link(bpy.data.objects.new(d.name, d), 'Cameras'); CAMS[name] = cam
    sc.timeline_markers.new(name, frame=round(a * FPS) + 1).camera = cam
sc.camera = CAMS['Blade']

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
    for t0, amp, dur, fq in [(STAB, .07, .7, 11), (TWIST, .015, .3, 15), (PULL, .03, .4, 12), (DROP + .35, .012, .3, 14)]:
        dt = t - t0
        if 0 <= dt <= dur: env = (1 - dt / dur) ** 2; rx += amp * env * math.sin(dt * fq * math.tau + 1.3); ry += amp * .6 * env * math.sin(dt * fq * 1.37 * math.tau)
    return rx, ry

def clear_orbit(c, azs, el, dist, avoid):
    """First azimuth whose line of sight to c keeps clear of the other bodies."""
    best = None; best_gap = -1
    for az in azs:
        pos = orbit(c, az, el, dist); seg = Vector(c) - pos; L = seg.length; gap = 9.0
        for a in avoid:
            k = max(0.0, min(1.0, (Vector(a) - pos).dot(seg) / (L * L)))
            gap = min(gap, (pos + seg * k - Vector(a)).length)
        if gap > .42: return pos
        if gap > best_gap: best_gap = gap; best = pos
    return best

def camera(t, frame):
    for name, a, b, lens in SHOTS:
        if a <= t < b or (name == 'Away' and t >= a): break
    cam = CAMS[name]; u = sm(a, b, t); sh = shake(t); hh = (math.sin(t * 1.1) * .003 + sh[0], math.sin(t * .8 + 1) * .002 + sh[1])
    hs = wm(S['head']) @ Vector((0, 0, .25)); hn = wm(N['head']) @ Vector((0, 0, .25))
    if name == 'Blade':
        c = wm(sword) @ Vector((0, 0, .3)); place(cam, orbit(c, math.degrees(YS) + 80, 10, 1.3), c, lens, c, 2.2, extra=hh)
    elif name == 'Scream':
        av = [wm(S['head']) @ Vector((0, 0, .25)), wm(S['torso']) @ Vector((0, 0, .4))]
        place(cam, clear_orbit(hn, [22, 40, -20, 60], -4, mix(1.7, 1.35, u), av), hn + Vector((0, 0, -.12)), lens, hn, 2.0, roll=.03, extra=hh)
    elif name == 'Raise':
        c = (hs + hn) / 2 + Vector((0, 0, .2))
        av = [Vector((0, .42, 1.15))]
        place(cam, clear_orbit(c, [62, 75, 50, 90], 2, 3.2, av), c, lens, hs, 4.0, roll=-.04, extra=hh)
    elif name == 'Stab':
        c = CHEST + Vector((-.15, -.3, .15)); place(cam, orbit(c, 70, 4, 2.4), c, lens, c, 3.2, extra=hh)
    elif name == 'Twist':
        c = (hs + hn) / 2 + Vector((0, 0, -.1))
        av = [Vector((0, .42, 1.15))]
        place(cam, clear_orbit(c, [70, 82, 58, 95], 2, mix(2.3, 2.0, u), av), c, lens, hs, 2.8, roll=.04, extra=hh)
    elif name == 'Face':
        av = [hn, wm(N['torso']) @ Vector((0, 0, .4)), Vector((0, .42, 1.15))]
        yawf = math.degrees(S['root'].rotation_quaternion.to_euler().z)
        place(cam, clear_orbit(hs, [yawf - 40, yawf - 60, yawf + 40, yawf - 80], 0, mix(1.25, 1.05, u), av), hs, 35, hs, 1.8, extra=hh)
    else:
        c = Vector((.4, -.3, 1.0)); place(cam, orbit(c, mix(-10, -4, u), 10, mix(4.6, 4.2, u)), c, lens, hn, 4.5, extra=hh)
    rec(cam, 'location', cam.location, frame); rec(cam, 'rotation_euler', cam.rotation_euler, frame)
    rec(cam.data, 'lens', [cam.data.lens], frame); rec(cam.data, 'dof.focus_distance', [cam.data.dof.focus_distance], frame)

def hitstop(t):
    if STAB <= t < STAB + .12: return STAB
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
