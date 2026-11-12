"""Chapter V bad ending, film v2. Run with Blender (--background --python, or MCP execute_blender_code).
Steve's last lunge -> Notch catches the blade and breaks it -> knee -> face slammed into the table ->
"Пора бы завязать с тестированием" -> snap, Steve deleted from the feet up -> Notch leaves through the door.
Shared rig/recorder helpers come from _ch5bad_base.py (sliced from the chapter I prologue builder)."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix
_base = Path('/home/daydert/MinecraftSurvivors2/scripts/cinematics/_ch5bad_base.py')
exec(compile(_base.read_text(), str(_base), 'exec'))

R = random.Random(5)
LINE = (3.4, 6.6)          # subtitle window (drawn by the encoder)
CATCH, BREAK, KNEE, SLAM, SNAP = 1.55, 1.95, 2.2, 2.85, 5.45
ERASE0, ERASE1 = 5.6, 8.6
DOOR_OPEN, DOOR_SHUT = 11.35, 13.1

# ---------------------------------------------------------------- set: the terminal room
B = Batch()
for x in range(-5, 6):
    for y in range(-5, 5):
        B.box((x, y, -.5), (1, 1, 1), 'ch5q_polished_deepslate')
for x in range(-5, 6):
    for z in range(0, 5):
        if not (x == 3 and z < 2): B.box((x, 4.5, z + .5), (1, 1, 1), 'ch5q_deepslate_tiles' if (x + z) % 5 else 'ch5q_cracked_deepslate_tiles')
for y in range(-5, 5):
    for z in range(0, 5):
        B.box((-5.5, y, z + .5), (1, 1, 1), 'ch5q_deepslate_tiles' if (y + z) % 4 else 'ch5q_polished_blackstone_bricks')
        B.box((5.5, y, z + .5), (1, 1, 1), 'ch5q_deepslate_tiles' if (y * 3 + z) % 4 else 'ch5q_polished_blackstone_bricks')
for x in range(-5, 6):
    for y in range(-5, 5): B.box((x, y, 5.5), (1, 1, 1), 'ch5q_deepslate_tiles')
# Table (top at .85), right of centre.
TABLE = Vector((1.25, .55, .85))
B.box((TABLE.x, TABLE.y, .8), (1.5, .95, .1), 'ch5q_dark_oak_planks')
for dx in (-.65, .65):
    for dy in (-.38, .38): B.box((TABLE.x + dx, TABLE.y + dy, .375), (.1, .1, .75), 'ch5q_dark_oak_planks')
B.build('room')
# Terminal screen on the back wall: rows of green code.
rows = []
for r in range(36):
    line = ''.join(('g' if R.random() < .55 else 'h') if (c < 4 + (r * 7) % 40 and c > (r % 3) * 2) else '.' for c in range(64))
    rows.append(line)
code_im = pixel_texture('code', rows, {'g': (.1, .9, .4, 1), 'h': (.05, .45, .2, 1), '.': (.0, .03, .01, 1)})
MAT['code'] = image_material('code', code_im, emit=2.2, rough=.6)
screen = plain_box('Terminal', (-1.2, 3.98, 2.3), (4.2, .02, 2.36), MAT['code'], None, 'Set')
# Iron door in the back wall at x=3: hinge on its left edge, white light behind.
door_hinge = empty('Door_hinge', (2.5, 4.02, 0), col='Set')
door = skin_box('Door', (.5, 0, 1.0), (1.0, .12, 2.0), MAT['ch5q_iron_block'], door_hinge, (0, 0, 16, 16, 0), col='Set')
door.data.uv_layers[0].data.foreach_set('uv', [c for i in range(len(door.data.loops)) for c in ((i % 4 in (1, 2)) * 1.0, (i % 4 in (2, 3)) * 1.0)])
door.scale = (1, 1, 1)
light_plane = plain_box('DoorLight', (3, 4.6, 1.0), (1.0, .02, 2.0), material('door_light', color=(1, 1, 1, 1), emit=30), None, 'Set')
# Blood on the table (appears at the slam) and the Steve already bloodied by the fight.
table_blood = [plain_box('TableBlood', (TABLE.x - .25 + i * .18, TABLE.y - .12 + (i % 2) * .15, .857 + i * .0003), (.34 + i * .05, .3, .002), MAT['blood'], None, 'FX') for i in range(4)]
for ob in table_blood: ob.rotation_mode = 'XYZ'; ob.rotation_euler.z = R.uniform(0, 3)

S = rig('Steve', MAT['ch5_skin_steve']); N = rig('Notch', MAT['ch5_skin_notch'])
steve_blood = [plain_box('S_blood', (x, -.2565, z), (w, .004, h), MAT['blood'], S['head'], 'FX') for x, z, w, h in [(-.1, .2, .14, .16), (.12, .08, .1, .12)]]
steve_blood += [plain_box('S_blood_body', (.05, -.1335, .4), (.3, .004, .35), MAT['blood'], S['torso'], 'FX')]
notch_cut = plain_box('N_palm_blood', (0, 0, -.33), (.27, .27, .08), MAT['blood_hand'], N['Lelbow'], 'FX')
sword = voxel_item('Sword', 'iron_sword.png', S['Rwrist'], (3, 13), .046)
sword.rotation_quaternion = qrot(math.pi / 2)

def pool(name, count, mat, size):
    return [plain_box(name, (0, 0, -50), (size, size, size), MAT[mat] if isinstance(mat, str) else mat, None, 'FX') for _ in range(count)]
P_shard = pool('blade_shard', 22, material('blade', color=(.78, .8, .84, 1), rough=.2, spec=.8), .05)
P_spark = pool('spark', 18, material('spark', color=(1, .85, .5, 1), emit=12), .02)
P_blood = pool('blood', 60, 'blood_solid', .04)
PIX_MATS = [material('pix_shirt', color=(.0, .55, .62, 1), emit=1.2), material('pix_skin', color=(.62, .42, .30, 1), emit=1.0),
            material('pix_pants', color=(.16, .17, .55, 1), emit=1.2), material('pix_glitch', color=(.3, 1, .7, 1), emit=6)]
P_pix = [plain_box('erase_px', (0, 0, -50), (.05, .05, .05), PIX_MATS[i % 4], None, 'FX') for i in range(160)]
for ob in P_shard + P_spark + P_blood + P_pix: ob.rotation_mode = 'XYZ'

# ---------------------------------------------------------------- lights
def light(name, typ, energy, color, at=(0, 0, 5), size=1.0):
    d = bpy.data.lights.new('LGT_CH5B_' + name, typ); d.energy = energy; d.color = color
    if typ == 'AREA': d.shape = 'DISK'; d.size = size
    if typ in ('POINT', 'SPOT'): d.shadow_soft_size = size
    ob = link(bpy.data.objects.new(d.name, d), 'Lights'); ob.location = at; return ob
lamp = light('Lamp', 'SPOT', 520, (1, .86, .66), (TABLE.x - .2, TABLE.y - .3, 3.6), .2)
lamp.data.spot_size = 1.1; lamp.data.spot_blend = .6; lamp.rotation_euler = (0, 0, 0)
terminal_glow = light('Terminal', 'AREA', 260, (.25, 1, .5), (-1.2, 3.6, 2.3), 4)
terminal_glow.rotation_euler = (Vector((-1.2, 0, 1)) - Vector((-1.2, 3.6, 2.3))).to_track_quat('-Z', 'Y').to_euler()
fill = light('Fill', 'AREA', 220, (.5, .6, 1), (-3, -4, 3), 4)
fill.rotation_euler = (Vector((0, 0, 1)) - Vector((-3, -4, 3))).to_track_quat('-Z', 'Y').to_euler()
sconce = light('Sconce', 'POINT', 60, (1, .8, .55), (3.9, 3.7, 2.6), .2)
back_fill = light('BackFill', 'AREA', 160, (.55, .7, 1), (0, 1.5, 4.6), 5)
door_glow = light('Door', 'AREA', 0, (1, 1, 1), (3, 3.7, 1.2), 1.2)
door_glow.rotation_euler = (Vector((2, 0, 1)) - Vector((3, 3.7, 1.2))).to_track_quat('-Z', 'Y').to_euler()
bg.inputs[0].default_value = (.01, .01, .015, 1); bg.inputs[1].default_value = .2
FOG_DENS = None

# ---------------------------------------------------------------- acting
N0 = V(.35, .55); S0 = V(-1.9, -1.35)
YN = yaw_to(N0, S0); YS = yaw_to(S0, N0)
SLAM_SPOT = TABLE + Vector((-.15, -.05, 0))  # where his face meets the wood

def loc_of(base, yaw, q): return Vector(base) + fwd(yaw) * q[0] + right(yaw) * q[1] + Vector((0, 0, q[2]))

def pose_notch(t):
    reset(N, N0, YN, .75)
    if t < KNEE:
        stand(N, YN, .13, (.02, -.05))
        breathe(N, t, .01, 1.2)
        look(N, wm(S['head']).translation + Vector((0, 0, .2)), amount=.9)
        addrot(N['head'], 0, .12 * (1 - sm(1.2, 1.5, t)), 0)  # a bored tilt until the lunge
        hand(N, 'R', loc_of(N0, YN, (.05, .3, .62)))
        if t < CATCH - .25:
            hand(N, 'L', loc_of(N0, YN, (.05, -.3, .62)))
        else:
            # Catches the blade in his bare hand, squeezes; it breaks in his fist.
            tip = wm(sword) @ Vector((0, 0, .62)) if t < BREAK else loc_of(N0, YN, (.42, -.12, 1.15))
            grab = loc_of(N0, YN, (.4, -.12, 1.15))
            hand(N, 'L', loc_of(N0, YN, (.05, -.3, .62)).lerp(grab, eo(CATCH - .25, CATCH, t)))
            rot(N['torso'], 0, 0, .08 * sm(CATCH, BREAK, t))
        return
    # Knee to the gut, then the hand on the back of his head drives him into the table.
    k = sm(KNEE - .18, KNEE, t) * (1 - sm(KNEE + .15, KNEE + .45, t))
    move = sm(2.35, SLAM, t)
    base = N0.lerp(TABLE + Vector((-.2, -.95, -TABLE.z)), move)
    reset(N, base, mix(YN, yaw_to(base, TABLE), move), .75)
    stand(N, N['root'].rotation_quaternion.to_euler().z, .14, (.05, -.08))
    yaw = N['root'].rotation_quaternion.to_euler().z
    if k > 0:
        rot(N['Rleg'], -1.5 * k); rot(N['Rknee'], 1.6 * k)
    rot(N['torso'], .1 + .35 * move * (1 - sm(8.8, 9.4, t)) + .1 * k, 0, 0)
    if t < 9.0:
        hand(N, 'L', loc_of(base, yaw, (.35, -.2, 1.3)) if t < 2.3 else wm(S['head']) @ Vector((0, .1, .5)))
        hand(N, 'R', loc_of(base, yaw, (.15, .3, .7)) if t < SNAP - .3 else loc_of(base, yaw, (.25, .35, 1.25)).lerp(loc_of(base, yaw, (.3, .3, 1.05)), sm(SNAP, SNAP + .1, t)))
        look(N, wm(S['head']).translation if t < ERASE1 else TABLE, amount=1)
        if LINE[0] < t < LINE[1]: addrot(N['head'], .02 * math.sin(t * 9), .1, 0)
        return
    # Straightens up, flicks the blood off his hand, walks to the door, opens it and goes.
    stand_up = sm(8.8, 9.4, t)
    walk_base = TABLE + Vector((-.2, -.95, -TABLE.z))
    door_spot = Vector((3.0, 3.3, 0))
    if t < 9.6:
        reset(N, walk_base, yaw_to(walk_base, TABLE), .75); stand(N, yaw_to(walk_base, TABLE), .14)
        rot(N['torso'], .45 * (1 - stand_up))
        flick = sm(9.3, 9.45, t) * (1 - sm(9.5, 9.7, t))
        hand(N, 'L', loc_of(walk_base, yaw_to(walk_base, TABLE), (.3 - .1 * flick, -.35 - .3 * flick, 1.0 - .25 * flick)))
        hand(N, 'R', loc_of(walk_base, yaw_to(walk_base, TABLE), (.05, .3, .62)))
        look(N, TABLE, amount=.7)
        return
    # Around the table, never through it: along its near side, then up to the door.
    corner = Vector((2.45, -.45, 0))
    if t < 10.35:
        locomote(N, t, 9.6, 10.35, walk_base, corner, yaw_to(walk_base, corner), stride=.55, ease_in=True, ease_out=False)
        rot(N['Larm'], .1, 0, -.05); rot(N['Rarm'], -.1, 0, .05)
        return
    if t < DOOR_OPEN - .3:
        locomote(N, t, 10.35, DOOR_OPEN - .3, corner, door_spot, yaw_to(corner, door_spot), stride=.55, ease_in=False, ease_out=True)
        rot(N['Larm'], .1, 0, -.05); rot(N['Rarm'], -.1, 0, .05)
        return
    # At the door: pushes it open with the right hand, steps through.
    inside = Vector((3.0, 4.9, 0))
    k = sm(DOOR_OPEN + .3, DOOR_SHUT - .2, t)
    reset(N, door_spot.lerp(inside, k), math.pi, .75)
    stand(N, math.pi, .13)
    hand(N, 'R', Vector((2.6, 4.0, 1.1)).lerp(Vector((2.7, 3.7, 1.1)), sm(DOOR_OPEN - .3, DOOR_OPEN, t)) if t < DOOR_OPEN + .4 else loc_of(N['root'].location, math.pi, (.05, .3, .62)))
    if k >= .98: N['root'].scale = (.0001,) * 3

def pose_steve(t):
    reset(S, S0, YS, .72)
    if t < CATCH:
        if t < 1.0:
            stand(S, YS, .16, (.1, -.15))
            rot(S['torso'], .28 + .04 * math.sin(t * 7), 0, .05)
            breathe(S, t, .04, 7)
            look(S, wm(N['head']).translation, amount=1)
            hand(S, 'R', loc_of(S0, YS, (.25, .3, .55)))
            hand(S, 'L', loc_of(S0, YS, (.15, -.32, .78)))
            rot(S['Rwrist'], 1.2, 0, 0)
            return
        end = N0 + fwd(YN) * .95
        u = locomote(S, t, 1.0, CATCH, S0, end, YS, stride=.8, run=True, ease_in=True, ease_out=False)
        look(S, wm(N['head']).translation)
        target = wm(N['torso']) @ Vector((0, -.1, .45))
        hand(S, 'R', loc_of(S['root'].location, YS, (.2, .28, .9)).lerp(target + fwd(YS) * -.55, sm(1.15, CATCH, t)))
        rot(S['Rwrist'], mix(1.2, 0.0, sm(1.1, 1.4, t)), 0, 0)
        return
    end = N0 + fwd(YN) * .95
    if t < KNEE + .05:
        reset(S, end, YS, .7); stand(S, YS, .18, (.35, -.35))
        rot(S['torso'], .3, 0, 0)
        hand(S, 'R', wm(N['torso']) @ Vector((0, -.1, .45)) + fwd(YS) * -.55)
        hand(S, 'L', loc_of(end, YS, (.1, -.3, .9)))
        look(S, wm(N['head']).translation)
        if t > BREAK: rot(S['torso'], .3 + .15 * sm(BREAK, KNEE, t)); S['root'].location += fwd(YS) * .06 * sm(BREAK, KNEE, t)
        return
    # Folded by the knee, dragged by the head, slammed face-first into the table, pinned.
    fold = sm(KNEE, KNEE + .12, t)
    drag = sm(2.35, SLAM, t)
    spot = SLAM_SPOT + Vector((-.7, 0, -TABLE.z))
    base = end.lerp(spot, drag)
    yaw = mix(YS, yaw_to(spot, SLAM_SPOT), drag)
    reset(S, base, yaw, mix(.62, .8, drag))
    stand(S, yaw, .17, (-.05 * drag + .15 * (1 - drag), -.2 * (1 - drag) - .05 * drag))
    bend = 1.25 * fold * (1 - drag) + 1.24 * drag
    rot(S['torso'], bend, 0, .08 * math.sin(t * 3) * (1 - drag))
    rot(S['head'], -.15 * drag, .5 * drag, 0)
    slam_kick = (1 - sm(SLAM, SLAM + .2, t)) * sm(SLAM - .05, SLAM, t)
    addrot(S['torso'], .08 * slam_kick)
    # The free hand: clutching the gut, then on the table, clawing during deletion.
    if t < SLAM:
        hand(S, 'L', loc_of(base, yaw, (.25, -.1, .8))); hand(S, 'R', loc_of(base, yaw, (.25, .15, .8)))
    else:
        # Arms stretched out along the tabletop past his head, forearms flat on the wood;
        # during the deletion the left one claws forward.
        claw = sm(ERASE0 + .2, ERASE0 + .6, t)
        scrape = .12 * math.sin(t * 14) * claw
        rot(S['Larm'], -2.95 - .1 * claw + scrape, 0, .32)
        rot(S['Lelbow'], -.15 - .35 * claw - scrape)
        rot(S['Rarm'], -3.0, 0, -.38); rot(S['Relbow'], -.12)
    breathe(S, t, .03 * (t < ERASE0), 9)

# ---------------------------------------------------------------- FX
erase_order = []
for key, part in [('Rknee', 0), ('Lknee', 0), ('Rleg', .12), ('Lleg', .12), ('hips', .25), ('torso', .45), ('Rarm', .55), ('Relbow', .6), ('Larm', .72), ('Lelbow', .82), ('head', .9)]:
    erase_order.append((key, ERASE0 + part * (ERASE1 - ERASE0 - .4)))
cache = {}

def mesh_children(ob): return [c for c in ob.children if c.type == 'MESH']

def apply_fx(t, frame):
    # Blade: whole until it breaks in Notch's fist, then shards.
    sword.scale = (1, 1, 1) if t < BREAK else (.0001,) * 3; rec(sword, 'scale', sword.scale, frame)
    notch_cut.scale = (1, 1, 1) if t >= BREAK else (.0001,) * 3; rec(notch_cut, 'scale', notch_cut.scale, frame)
    for ob in table_blood:
        on = t >= SLAM; ob.scale = (sm(SLAM, SLAM + .25, t),) * 2 + (1,) if on else (.0001,) * 3; rec(ob, 'scale', ob.scale, frame)
    rnd = random.Random(11)
    fist = cache.setdefault('fist', None)
    if t >= BREAK and 'fist' not in cache or cache.get('fist') is None:
        if t >= BREAK: cache['fist'] = wm(N['Lwrist']).translation.copy()
    for i, ob in enumerate(P_shard):
        v = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(.2, 1.2))) * rnd.uniform(1.5, 3.5)
        dt = t - BREAK
        if dt < 0 or dt > 1.4: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
        else:
            p = cache['fist'] + v * dt + Vector((0, 0, -4.9 * dt * dt))
            if p.z < .02: p.z = .02
            ob.location = p; ob.scale = (1, 1, 2.2); ob.rotation_euler = (dt * 9 + i, dt * 5, i)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame); rec(ob, 'rotation_euler', ob.rotation_euler, frame)
    for i, ob in enumerate(P_spark):
        v = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(0, 1))).normalized() * rnd.uniform(2, 5)
        dt = t - CATCH
        if dt < 0 or dt > .35: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
        else:
            if 'catch' not in cache: cache['catch'] = wm(N['Lwrist']).translation.copy()
            ob.location = cache['catch'] + v * dt; ob.scale = (1, 1, 1 - dt / .35)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame)
    # Blood: Notch's cut palm drips; the slam bursts from the face.
    for i, ob in enumerate(P_blood):
        if i < 36:
            v = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(.3, 1.4))) * rnd.uniform(1, 2.6)
            dt = t - SLAM
            if dt < 0 or dt > 1.2: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
            else:
                if 'face' not in cache: cache['face'] = wm(S['head']) @ Vector((0, -.2, .2))
                p = cache['face'] + v * dt + Vector((0, 0, -4.9 * dt * dt))
                if p.z < .86 and abs(p.x - TABLE.x) < .75 and abs(p.y - TABLE.y) < .47: p.z = .862; ob.scale = (1.6, 1.6, .1)
                elif p.z < .01: p.z = .01; ob.scale = (1.6, 1.6, .1)
                else: ob.scale = (1, 1, 1.6)
                ob.location = p
        else:
            period = .5 + (i % 5) * .13; ph = ((t - BREAK) % period) / period
            if t < BREAK + .2 or t > 9.2: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
            else:
                src = wm(N['Lwrist']).translation + Vector((rnd.uniform(-.04, .04), rnd.uniform(-.04, .04), -.08))
                ob.location = src + Vector((0, 0, -4.9 * (ph * period) ** 2)); ob.scale = (1, 1, 1.8)
                if ob.location.z < 0: ob.location.z = .005; ob.scale = (1.4, 1.4, .1)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame)
    # Deletion: body parts vanish from the feet up; each sheds a burst of pixels that rise and die.
    for key, at in erase_order:
        on = t < at
        for m in mesh_children(S[key]):
            m.scale = (1, 1, 1) if on else (.0001,) * 3
            # flicker just before a part goes
            if at - .25 < t < at and int(t * 30) % 3 == 0: m.scale = (1.03, 1.03, 1.03)
            rec(m, 'scale', m.scale, frame)
    for ob in steve_blood:
        ob.scale = (1, 1, 1) if t < erase_order[-1][1] else (.0001,) * 3; rec(ob, 'scale', ob.scale, frame)
    for i, ob in enumerate(P_pix):
        key, at = erase_order[i % len(erase_order)]
        dt = t - at + rnd.uniform(0, .25)
        if dt < 0 or dt > 1.6: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
        else:
            ck = 'px%d' % i
            if ck not in cache: cache[ck] = wm(S[key]) @ Vector((rnd.uniform(-.15, .15), rnd.uniform(-.13, .13), rnd.uniform(-.35, .1)))
            drift = Vector((rnd.uniform(-.4, .4), rnd.uniform(-.4, .4), rnd.uniform(.4, 1.2)))
            ob.location = cache[ck] + drift * dt; s = (1 - dt / 1.6) * (1.3 if i % 4 == 3 else 1)
            ob.scale = (s, s, s); ob.rotation_euler = (dt * 5 + i, dt * 3, i)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame); rec(ob, 'rotation_euler', ob.rotation_euler, frame)
    # Door, its light and the hanging lamp swinging after the slam.
    open_k = sm(DOOR_OPEN - .15, DOOR_OPEN + .35, t) * (1 - sm(DOOR_SHUT - .15, DOOR_SHUT, t))
    door_hinge.rotation_quaternion = qrot(z=-1.6 * open_k); rec(door_hinge, 'rotation_quaternion', door_hinge.rotation_quaternion, frame)
    door_glow.data.energy = 900 * open_k; rec(door_glow.data, 'energy', [door_glow.data.energy], frame)
    swing = .18 * math.sin((t - SLAM) * 5) * math.exp(-max(0, t - SLAM) * .8) if t > SLAM else 0
    lamp.rotation_euler = (swing, swing * .4, 0); rec(lamp, 'rotation_euler', lamp.rotation_euler, frame)
    rec_emit(MAT['code'], 2.2 * (1 if int(t * 12) % 17 else .4) * (1 + 2 * (ERASE0 < t < ERASE1) * (int(t * 20) % 2)), frame)

def rec_val(sock, v, frame, idx=None):
    node = sock.node; nt = node.id_data; sidx = list(node.inputs).index(sock)
    REC.setdefault((nt, 'nodes["%s"].inputs[%d].default_value' % (node.name, sidx), idx or 0), []).append((frame, float(v)))
def rec_emit(mat, v, frame): rec_val(mat.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'], v, frame)

# ---------------------------------------------------------------- cameras
SHOTS = [('Wide', 0, 1.5, 30), ('Catch', 1.5, 2.05, 45), ('Slam', 2.05, 3.25, 32), ('Pinned', 3.25, 5.4, 40),
         ('Erase', 5.4, 8.9, 34), ('Leave', 8.9, 14.5, 28)]
CAMS = {}
for name, a, b, lens in SHOTS:
    d = bpy.data.cameras.new('CAM_CH5B_' + name); d.lens = lens; d.sensor_width = 36; d.clip_start = .05; d.clip_end = 80
    d.dof.use_dof = True; d.dof.aperture_fstop = 2.8
    cam = link(bpy.data.objects.new(d.name, d), 'Cameras'); CAMS[name] = cam
    sc.timeline_markers.new(name, frame=round(a * FPS) + 1).camera = cam
sc.camera = CAMS['Wide']

def shake(t, events):
    rx = ry = 0.0
    for t0, amp, dur, fq in events:
        dt = t - t0
        if 0 <= dt <= dur:
            env = (1 - dt / dur) ** 2
            rx += amp * env * math.sin(dt * fq * math.tau + 1.3); ry += amp * .6 * env * math.sin(dt * fq * 1.37 * math.tau)
    return rx, ry

def place(cam, pos, tgt, lens, focus, fstop=2.8, roll=0.0, extra=(0, 0)):
    cam.location = Vector(pos)
    q = (Vector(tgt) - Vector(pos)).to_track_quat('-Z', 'Y') @ Quaternion((0, 0, 1), roll) @ Quaternion((1, 0, 0), extra[0]) @ Quaternion((0, 1, 0), extra[1])
    cam.rotation_mode = 'XYZ'; cam.rotation_euler = q.to_euler('XYZ', cam.rotation_euler)
    cam.data.lens = lens; cam.data.dof.focus_distance = max(.2, (Vector(focus) - Vector(pos)).length); cam.data.dof.aperture_fstop = fstop

def orbit(c, az, el, d):
    az = math.radians(az); el = math.radians(el)
    return Vector(c) + Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * d

def camera(t, frame):
    for name, a, b, lens in SHOTS:
        if a <= t < b or (name == 'Leave' and t >= a): break
    cam = CAMS[name]; u = sm(a, b, t)
    sh = shake(t, [(CATCH, .02, .3, 13), (BREAK, .02, .3, 15), (KNEE, .03, .35, 12), (SLAM, .06, .6, 11), (SNAP, .01, .2, 18), (DOOR_SHUT, .03, .4, 10)])
    hh = (math.sin(t * 1.1) * .003, math.sin(t * .8 + 1) * .002)
    hn = wm(N['head']) @ Vector((0, 0, .25)); hs = wm(S['head']) @ Vector((0, 0, .25))
    if name == 'Wide':
        c = (hn + hs) / 2 + Vector((0, 0, -.45))
        place(cam, orbit(c, mix(-28, -22, u), 6, mix(5.0, 4.4, u)), c, lens, c, 4, extra=hh)
    elif name == 'Catch':
        c = (wm(N['Lwrist']).translation + wm(S['Rwrist']).translation) / 2 + Vector((0, 0, .15))
        place(cam, c + right(YS) * 2.3 - fwd(YS) * .35 + Vector((0, 0, .2)), c, lens, c, 3.2, roll=.05, extra=sh)
    elif name == 'Slam':
        c = (wm(S['torso']).translation + TABLE) / 2 + Vector((0, 0, .35))
        place(cam, orbit(c, mix(-118, -110, u), 6, 3.0), c, lens, c, 3.2, roll=-.03, extra=sh)
    elif name == 'Pinned':
        c = hs * .55 + hn * .45
        place(cam, orbit(c, mix(-138, -130, u), 6, mix(2.6, 2.25, u)), c, lens, hs, 2.4, roll=.04, extra=(hh[0] + sh[0], hh[1] + sh[1]))
    elif name == 'Erase':
        c = TABLE + Vector((-.55, -.2, .15))
        place(cam, orbit(c, mix(-145, -135, u), 14, mix(2.7, 2.3, u)), c, lens, c, 2.8, extra=(hh[0] + sh[0], hh[1] + sh[1]))
    else:
        c = Vector((1.6, 1.9, 1.15))
        place(cam, orbit(c, mix(-18, -10, u), 8, mix(5.2, 4.6, u)), c, lens, hn, 5, extra=sh)
    rec(cam, 'location', cam.location, frame); rec(cam, 'rotation_euler', cam.rotation_euler, frame)
    rec(cam.data, 'lens', [cam.data.lens], frame); rec(cam.data, 'dof.focus_distance', [cam.data.dof.focus_distance], frame)

def hitstop(t):
    """Actors freeze for a few frames on the catch, the knee and the slam."""
    for at, hold in [(CATCH, .1), (KNEE, .08), (SLAM, .12)]:
        if at <= t < at + hold: return at
    return t

for f in range(1, FRAMES + 1):
    t = (f - 1) / FPS; ta = hitstop(t)
    pose_steve(ta); pose_notch(ta); pose_steve(ta)
    for n in (S, N):
        for ob in n.values(): rec(ob, 'location', ob.location, f); rec(ob, 'rotation_quaternion', ob.rotation_quaternion, f)
        rec(n['root'], 'scale', n['root'].scale, f)
    apply_fx(t, f)
    camera(t, f)
flush()
try:
    ng = bpy.data.node_groups.new('CH5B_Comp', 'CompositorNodeTree'); sc.compositing_node_group = ng
    rl = ng.nodes.new('CompositorNodeRLayers'); gl = ng.nodes.new('CompositorNodeGlare'); gl.inputs['Type'].default_value = 'Bloom'
    for nm, val in [('Threshold', 1.0), ('Size', .5), ('Strength', .3)]: gl.inputs[nm].default_value = val
    out = ng.nodes.new('NodeGroupOutput'); ng.interface.new_socket('Image', in_out='OUTPUT', socket_type='NodeSocketColor')
    ng.links.new(rl.outputs['Image'], gl.inputs['Image']); ng.links.new(gl.outputs['Image'], out.inputs[0])
except Exception as e: print('compositor skipped', e)
sc.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(SRC / 'ch5_bad_end_v2.blend'), compress=True)
print('CH5BAD_READY', len(sc.objects), FRAMES)
