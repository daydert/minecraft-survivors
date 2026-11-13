"""Chapter V bad ending, film v3. Run with Blender (--background --python, or MCP execute_blender_code).
Steve gathers himself -> runs in -> two-handed overhead chop; Notch catches the blade bare-handed and breaks it ->
knee -> face slammed into the table -> "Пора бы завязать с тестированием" -> snap, Steve deleted from the feet up ->
Notch, hurt after all, straightens up holding his ribs, limps to the fridge, drinks a cold beer, limps out the door.
Shared rig/recorder helpers come from _ch5bad_base.py (sliced from the chapter I prologue builder)."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix
_base = Path('/home/daydert/MinecraftSurvivors2/scripts/cinematics/_ch5bad_base.py')
_src = _base.read_text().replace("LENGTH = 14.5", "LENGTH = 33.0")
exec(compile(_src, str(_base), 'exec'))

R = random.Random(5)
RUN0, CATCH, BREAK, KNEE, DRAG0, SLAM = 2.7, 4.05, 4.75, 5.05, 5.2, 5.75
LINE = (6.4, 10.2)         # subtitle window (drawn by the encoder)
SNAP = 9.9
ERASE0, ERASE1 = 10.05, 13.4
RISE0, RISE1, FLICK = 13.8, 15.3, 15.45
WALK1 = (15.9, 19.3)
FR_OPEN, GRAB, FR_SHUT = 19.5, 20.1, 20.8
TURN1, POP, DRINK0, DRINK1 = (20.95, 21.5), 21.75, 22.1, 24.1
WALK2 = (24.8, 28.5)
DOOR_OPEN, DOOR_SHUT = 28.85, 31.5

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

# Fridge against the right wall: iron body, hinged door (free edge toward the camera), lit inside.
FRIDGE = Vector((4.55, 1.2, 0))
fr = empty('Fridge', FRIDGE, col='Set')
for at, size in [((.38, 0, .95), (.1, .86, 1.9)), ((0, .4, .95), (.86, .06, 1.9)), ((0, -.4, .95), (.86, .06, 1.9)),
                 ((0, 0, 1.87), (.86, .86, .06)), ((0, 0, .04), (.86, .86, .08))]:
    plain_box('fridge_shell', at, size, MAT['ch5q_iron_block'], fr, 'Set')
inner = material('fridge_inner', color=(.82, .9, .95, 1), emit=.6, rough=.4)
plain_box('fridge_back', (.32, 0, .95), (.02, .74, 1.76), inner, fr, 'Set')
for z in (.55, 1.0, 1.42):
    plain_box('fridge_shelf', (0, 0, z), (.68, .74, .025), material('fridge_glass', color=(.75, .85, .9, 1), rough=.15, spec=.6), fr, 'Set')
fr_hinge = empty('Fridge_hinge', (-.43, .43, 0), fr, 'Set')  # hinge on Notch's left; the free edge (handle) on his right
plain_box('fridge_door', (-.04, -.43, .95), (.08, .86, 1.9), MAT['ch5q_iron_block'], fr_hinge, 'Set')
plain_box('fridge_seam', (-.085, -.43, 1.38), (.01, .86, .025), MAT['black'], fr_hinge, 'Set')
plain_box('fridge_handle', (-.11, -.76, 1.1), (.05, .05, .42), material('fridge_handle', color=(.15, .15, .17, 1), rough=.3, spec=.6), fr_hinge, 'Set')
cans = []
def beer_can(name, parent=None):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/models/ch5_beer_can.glb'))
    new = [o for o in bpy.data.objects if o not in before]
    root = empty(name, parent=parent, col='Set')
    pts = [o.matrix_world @ Vector(c) for o in new if o.type == 'MESH' for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))); hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    k = .2 / max(1e-6, (hi - lo).z); centre = (lo + hi) / 2
    for o in new:
        for c in o.users_collection: c.objects.unlink(o)
        COL['Set'].objects.link(o)
        if o.parent is None:
            o.matrix_world = Matrix.Scale(k, 4) @ Matrix.Translation(-centre) @ o.matrix_world; o.parent = root
    return root
for x, y in [(.05, .22), (.12, -.15), (-.05, -.24)]:
    cans.append(beer_can('Can_shelf', fr)); cans[-1].location = (x, y, 1.0 + .115)
CAN = beer_can('Can_taken')   # the one he takes; animated in world space
CAN.rotation_mode = 'QUATERNION'
CAN_HOME = FRIDGE + Vector((-.1, .05, 1.115))
fridge_light = None

S = rig('Steve', MAT['ch5_skin_steve']); N = rig('Notch', MAT['ch5_skin_notch'])
steve_blood = [plain_box('S_blood', (x, -.2565, z), (w, .004, h), MAT['blood'], S['head'], 'FX') for x, z, w, h in [(-.1, .2, .14, .16), (.12, .08, .1, .12)]]
steve_blood += [plain_box('S_blood_body', (.05, -.1335, .4), (.3, .004, .35), MAT['blood'], S['torso'], 'FX')]
notch_cut = plain_box('N_palm_blood', (0, 0, -.33), (.27, .27, .08), MAT['blood_hand'], N['Lelbow'], 'FX')
sword = voxel_item('Sword', 'iron_sword.png', S['Rwrist'], (3, 13), .046)
sword.rotation_quaternion = qrot(math.pi / 2)

def pool(name, count, mat, size):
    return [plain_box(name, (0, 0, -50), (size, size, size), MAT[mat] if isinstance(mat, str) else mat, None, 'FX') for _ in range(count)]
P_shard = pool('blade_shard', 22, material('blade', color=(.78, .8, .84, 1), rough=.2, spec=.8), .05)
P_blood = pool('blood', 90, 'blood_solid', .04)
PIX_MATS = [material('pix_shirt', color=(.0, .55, .62, 1), emit=1.2), material('pix_skin', color=(.62, .42, .30, 1), emit=1.0),
            material('pix_pants', color=(.16, .17, .55, 1), emit=1.2), material('pix_glitch', color=(.3, 1, .7, 1), emit=6)]
P_pix = [plain_box('erase_px', (0, 0, -50), (.05, .05, .05), PIX_MATS[i % 4], None, 'FX') for i in range(160)]
for ob in P_shard + P_blood + P_pix: ob.rotation_mode = 'XYZ'

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
fridge_light = light('FridgeIn', 'AREA', 0, (.75, .9, 1), (4.3, 1.2, 1.2), .7)
fridge_light.rotation_euler = (Vector((2.5, 1.2, 1.4)) - Vector((4.3, 1.2, 1.2))).to_track_quat('-Z', 'Y').to_euler()
bg.inputs[0].default_value = (.01, .01, .015, 1); bg.inputs[1].default_value = .2
FOG_DENS = None


# ---------------------------------------------------------------- acting
N0 = V(.35, .55); S0 = V(-2.4, -1.8)
YN = yaw_to(N0, S0); YS = yaw_to(S0, N0)
SLAM_SPOT = TABLE + Vector((-.15, -.05, 0))  # where his face meets the wood
END = N0 + fwd(YN) * 1.4                    # where Steve's lunge stops
WALK_BASE = TABLE + Vector((-.2, -.95, -TABLE.z))
FRIDGE_SPOT = V(3.7, 1.1); DOOR_SPOT = V(3.0, 3.3)
PATH1 = Path2([WALK_BASE, V(2.35, -.5), V(3.4, .35), FRIDGE_SPOT])
PATH2 = Path2([FRIDGE_SPOT, V(3.35, 2.3), DOOR_SPOT])
Y_FRIDGE = math.pi / 2; Y_ROOM = -math.pi / 2; Y_DOOR = math.pi
NC = {}

def loc_of(base, yaw, q): return Vector(base) + fwd(yaw) * q[0] + right(yaw) * q[1] + Vector((0, 0, q[2]))
def ribs(): return wm(N['torso']) @ Vector((.19, -.17, .42))   # he presses his left ribs: Steve did land some hits
def handle_pt(d=.76): return wm(fr_hinge) @ Vector((-.11, -d, 1.1))
def mouth(): return wm(N['head']) @ Vector((0, -.3, .12))
def can_at_mouth(y): return mouth() + fwd(y) * .07 + Vector((0, 0, .01))

def pose_notch(t):
    if t < KNEE:
        reset(N, N0, YN, .75)
        stand(N, YN, .13, (.02, -.05))
        breathe(N, t, .01, 1.2)
        look(N, wm(S['head']).translation + Vector((0, 0, .2)), amount=.9)
        addrot(N['head'], 0, .12 * (1 - sm(2.4, 2.9, t)), 0)  # a bored tilt until Steve commits
        hand(N, 'R', loc_of(N0, YN, (.05, .3, .62)))
        rest = loc_of(N0, YN, (.05, -.3, .62))
        if t < CATCH - .2: hand(N, 'L', rest); return
        if t < BREAK: NC['grip'] = wm(sword) @ Vector((0, 0, .4))
        g = rest.lerp(NC['grip'], eo(CATCH - .2, CATCH, t))
        if t >= BREAK: g = NC['grip'].lerp(loc_of(N0, YN, (.35, -.2, 1.3)), sm(BREAK, KNEE, t))
        hand(N, 'L', g)
        rot(N['torso'], 0, 0, .1 * sm(CATCH, BREAK, t))
        addrot(N['head'], .05 * sm(CATCH, CATCH + .3, t), 0, 0)
        return
    if t < RISE0:
        # Knee to the gut, then the hand on the back of his head drives him into the table and pins him.
        k = sm(KNEE - .18, KNEE, t) * (1 - sm(KNEE + .15, KNEE + .45, t))
        move = sm(DRAG0, SLAM, t)
        base = N0.lerp(WALK_BASE, move)
        yaw = mix(YN, yaw_to(WALK_BASE, TABLE), move)
        reset(N, base, yaw, .75); stand(N, yaw, .14, (.05, -.08))
        if k > 0: rot(N['Rleg'], -1.5 * k); rot(N['Rknee'], 1.6 * k)
        rot(N['torso'], .1 + .35 * move + .1 * k, 0, 0)
        if t < DRAG0: pin = loc_of(base, yaw, (.35, -.2, 1.3))
        elif t < ERASE1 - .2: pin = wm(S['head']) @ Vector((0, .1, .5)); NC['pin'] = pin.copy()
        else: pin = NC['pin']
        hand(N, 'L', pin)
        hand(N, 'R', loc_of(base, yaw, (.15, .3, .7)) if t < SNAP - .3 else loc_of(base, yaw, (.25, .35, 1.25)).lerp(loc_of(base, yaw, (.3, .3, 1.05)), sm(SNAP, SNAP + .1, t)))
        look(N, wm(S['head']).translation if t < ERASE1 else TABLE, amount=1)
        if LINE[0] < t < LINE[1]: addrot(N['head'], .02 * math.sin(t * 9), .1, 0)
        return
    yt = yaw_to(WALK_BASE, TABLE)
    if t < WALK1[0]:
        # Straightens up slowly, one hand going to his ribs; breathes hard; flicks the blood off his palm.
        up = sm(RISE0, RISE1, t)
        reset(N, WALK_BASE, yt, .75); stand(N, yt, .14, (.05, -.08))
        rot(N['torso'], mix(.45, .04, up), -.07 * up, 0)
        breathe(N, t, .035 * up, 3.2)
        flick = sm(FLICK, FLICK + .1, t) * (1 - sm(FLICK + .15, FLICK + .4, t))
        free = NC['pin'].lerp(loc_of(WALK_BASE, yt, (.12, .33, .72)), sm(RISE0 + .2, RISE0 + 1.0, t)) + right(yt) * (.2 * flick) + Vector((0, 0, -.18 * flick))
        hand(N, 'R', free)
        hand(N, 'L', loc_of(WALK_BASE, yt, (.3, -.3, 1.05)).lerp(ribs(), sm(RISE0 + .3, RISE1 - .2, t)))
        look(N, TABLE, amount=.8 * (1 - sm(RISE1, RISE1 + .6, t)))
        addrot(N['head'], .12 * sm(RISE1, RISE1 + .6, t), 0, 0)
        return
    if t < FR_OPEN - .35:
        y = locomote_path(N, t, WALK1[0], WALK1[1], PATH1, stride=.48, start_yaw=yt, end_yaw=Y_FRIDGE, limp=1.0)
        hand(N, 'L', ribs())
        hand(N, 'R', N['root'].location + fwd(y) * .06 + right(y) * .34 + Vector((0, 0, .68)))
        look(N, FRIDGE + Vector((0, 0, 1.4)), amount=.4 * sm(WALK1[0] + 1.5, WALK1[1], t))
        breathe(N, t, .02, 3.0)
        return
    if t < TURN1[0]:
        # At the fridge: right hand pulls the door open, reaches in for a can; left elbow nudges the door shut.
        reset(N, FRIDGE_SPOT, Y_FRIDGE, .75); stand(N, Y_FRIDGE, .14, (.04, -.04))
        lean = sm(GRAB - .45, GRAB - .05, t) * (1 - sm(GRAB + .1, GRAB + .45, t))
        rot(N['torso'], .06 + .32 * lean, 0, 0)
        breathe(N, t, .02, 2.6)
        side = loc_of(FRIDGE_SPOT, Y_FRIDGE, (.06, .34, .68))
        if t < FR_OPEN + .4:
            r = side.lerp(handle_pt(), sm(FR_OPEN - .35, FR_OPEN - .02, t))
        elif t < GRAB:
            r = handle_pt().lerp(CAN_HOME + Vector((-.06, 0, 0)), sm(FR_OPEN + .4, GRAB, t))
        else:
            r = (CAN_HOME + Vector((-.06, 0, 0))).lerp(loc_of(FRIDGE_SPOT, Y_FRIDGE, (.3, .22, 1.05)), sm(GRAB + .05, GRAB + .45, t))
        hand(N, 'R', r)
        push = sm(FR_SHUT - .45, FR_SHUT - .3, t) * (1 - sm(FR_SHUT + .05, FR_SHUT + .3, t))
        hand(N, 'L', ribs().lerp(handle_pt(.42), push))
        look(N, (FRIDGE + Vector((-.2, 0, 1.15))).lerp(wm(CAN).translation if t > GRAB else FRIDGE + Vector((-.2, 0, 1.15)), .6), amount=.8)
        return
    if t < WALK2[0]:
        # Turns to the room, pops the can, drinks it down with his head thrown back, exhales.
        y = mix(Y_FRIDGE, Y_ROOM + math.tau, sm(*TURN1, t)) if False else (Y_FRIDGE + (math.pi) * sm(TURN1[0], TURN1[1], t))
        reset(N, FRIDGE_SPOT, y, .75); stand(N, y, .14, (.03, -.03))
        drink = sm(DRINK0, DRINK0 + .45, t) * (1 - sm(DRINK1, DRINK1 + .4, t))
        exhale = sm(DRINK1 + .3, DRINK1 + .6, t) * (1 - sm(DRINK1 + .6, WALK2[0], t))
        rot(N['torso'], .04 - .08 * drink + .12 * exhale, 0, 0)
        hold = loc_of(FRIDGE_SPOT, y, (.3, .2, 1.08))
        hand(N, 'R', hold)
        rot(N['head'], -.5 * drink + .15 * exhale, 0, 0)
        NC['drink'] = drink; NC['yaw'] = y
        if drink > 0: hand(N, 'R', hold.lerp(can_at_mouth(y) + right(y) * .07 + Vector((0, 0, -.03)), drink))
        pop = sm(POP - .25, POP, t) * (1 - sm(POP + .15, POP + .4, t))
        hand(N, 'L', ribs().lerp(hold + Vector((0, 0, .1)), pop))
        breathe(N, t, .02 + .03 * exhale, 2.4)
        return
    if t < DOOR_OPEN - .3:
        y = locomote_path(N, t, WALK2[0], WALK2[1], PATH2, stride=.46, start_yaw=Y_FRIDGE + math.pi, end_yaw=Y_DOOR, limp=1.0)
        hand(N, 'L', ribs())
        hand(N, 'R', N['root'].location + fwd(y) * .12 + right(y) * .3 + Vector((0, 0, .8)))
        look(N, Vector((3.0, 4.0, 1.6)), amount=.5)
        return
    # At the door: pushes it open with the left hand, limps through.
    inside = Vector((3.0, 4.9, 0))
    k = sm(DOOR_OPEN + .3, DOOR_SHUT - .4, t)
    reset(N, DOOR_SPOT.lerp(inside, k), Y_DOOR, .75 - .03 * math.sin(k * math.pi * 3) ** 2)
    stand(N, Y_DOOR, .13)
    hand(N, 'R', N['root'].location + fwd(Y_DOOR) * .12 + right(Y_DOOR) * .3 + Vector((0, 0, .8)))
    hand(N, 'L', Vector((2.75, 3.95, 1.1)).lerp(Vector((2.6, 4.2, 1.1)), sm(DOOR_OPEN - .2, DOOR_OPEN + .2, t)) if t < DOOR_OPEN + .4 else ribs())
    if k >= .98: N['root'].scale = (.0001,) * 3

def pose_steve(t):
    if t < RUN0:
        # Catches his breath, straightens, grips the sword in both hands, sinks before the launch.
        reset(S, S0, YS, .72)
        gather = sm(1.4, 2.3, t)
        stand(S, YS, .16, (.1 - .05 * gather, -.15 - .08 * gather))
        S['hips'].location.z = .72 - .03 * (1 - gather) - .06 * sm(2.3, RUN0, t)
        rot(S['torso'], mix(.36, .14, gather) + .04 * math.sin(t * 6) * (1 - gather) + .1 * sm(2.3, RUN0, t), 0, .05)
        breathe(S, t, mix(.04, .02, gather), mix(6.5, 4, gather))
        look(S, wm(N['head']).translation, amount=mix(.35, 1, sm(.8, 1.6, t)))
        r = loc_of(S0, YS, (.2, .3, .7)).lerp(loc_of(S0, YS, (.08, .32, .9)), gather)
        hand(S, 'R', r)
        hand(S, 'L', loc_of(S0, YS, (.12, -.3, .72)).lerp(r - right(YS) * .1 + Vector((0, 0, .04)), sm(1.9, 2.4, t)))
        aim_blade(S, (fwd(YS) * .6 + Vector((0, 0, -1))).lerp(-fwd(YS) * .7 + right(YS) * .45 + Vector((0, 0, -.3)), gather))
        return
    if t < CATCH - .14:
        locomote(S, t, RUN0, CATCH - .14, S0, END, YS, stride=.85, run=True, ease_in=True, ease_out=False)
        base = S['root'].location.copy()
        look(S, wm(N['head']).translation)
        wind = sm(CATCH - .6, CATCH - .2, t)
        r = loc_of(base, YS, (.02, .32, .92)).lerp(loc_of(base, YS, (-.08, .12, 2.0)), wind)
        hand(S, 'R', r); hand(S, 'L', r - right(YS) * .1 + Vector((0, 0, -.06)))
        aim_blade(S, (-fwd(YS) * .8 + right(YS) * .35 + Vector((0, 0, -.25))).lerp(-fwd(YS) * .55 + Vector((0, 0, .85)), wind))
        return
    if t < KNEE + .05:
        # Two-handed overhead chop, caught; he strains against the grip, the blade snaps, he stumbles in.
        k = ei(CATCH - .14, CATCH, t)
        reset(S, END + fwd(YS) * .06 * sm(BREAK, KNEE, t), YS, .7 - .04 * k)
        stand(S, YS, .18, (.1 + .25 * k, -.1 - .25 * k))
        over = loc_of(END, YS, (-.08, .12, 2.0)); imp = loc_of(END, YS, (.4, .06, 1.72))
        r = over.lerp(imp, k)
        if t >= CATCH: r = imp + Vector((0, 0, .012 * math.sin(t * 43) * (1 - sm(BREAK, BREAK + .05, t))))
        if t >= BREAK: r = imp.lerp(loc_of(END, YS, (.55, .1, 1.15)), eo(BREAK, BREAK + .2, t))
        rot(S['torso'], .1 + .25 * k + .15 * sm(BREAK, KNEE, t), 0, 0)
        hand(S, 'R', r); hand(S, 'L', r - right(YS) * .1 + Vector((0, 0, -.06)))
        aim_blade(S, (-fwd(YS) * .55 + Vector((0, 0, .85))).lerp(fwd(YS) + Vector((0, 0, .42)), k))
        look(S, wm(N['head']).translation)
        return
    # Folded by the knee, dragged by the head, slammed face-first into the table, pinned.
    fold = sm(KNEE, KNEE + .12, t)
    drag = sm(DRAG0, SLAM, t)
    end = END + fwd(YS) * .06
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
    if t < SLAM:
        hand(S, 'L', loc_of(base, yaw, (.25, -.1, .8))); hand(S, 'R', loc_of(base, yaw, (.25, .15, .8)))
    else:
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

def rec_val(sock, v, frame, idx=None):
    node = sock.node; nt = node.id_data; sidx = list(node.inputs).index(sock)
    REC.setdefault((nt, 'nodes["%s"].inputs[%d].default_value' % (node.name, sidx), idx or 0), []).append((frame, float(v)))
def rec_emit(mat, v, frame): rec_val(mat.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'], v, frame)

def apply_fx(t, frame):
    sword.scale = (1, 1, 1) if t < BREAK else (.0001,) * 3; rec(sword, 'scale', sword.scale, frame)
    notch_cut.scale = (1, 1, 1) if t >= CATCH + .05 else (.0001,) * 3; rec(notch_cut, 'scale', notch_cut.scale, frame)
    for ob in table_blood:
        on = t >= SLAM; ob.scale = (sm(SLAM, SLAM + .25, t),) * 2 + (1,) if on else (.0001,) * 3; rec(ob, 'scale', ob.scale, frame)
    rnd = random.Random(11)
    if t >= BREAK and 'fist' not in cache: cache['fist'] = wm(N['Lwrist']).translation.copy()
    for i, ob in enumerate(P_shard):
        v = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(.2, 1.2))) * rnd.uniform(1.5, 3.5)
        dt = t - BREAK
        if dt < 0 or dt > 1.4: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
        else:
            p = cache['fist'] + v * dt + Vector((0, 0, -4.9 * dt * dt))
            if p.z < .02: p.z = .02
            ob.location = p; ob.scale = (1, 1, 2.2); ob.rotation_euler = (dt * 9 + i, dt * 5, i)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame); rec(ob, 'rotation_euler', ob.rotation_euler, frame)
    # Blood: the blade bites into the palm on the catch, the face bursts on the slam, the palm keeps dripping.
    for i, ob in enumerate(P_blood):
        if i < 18:
            v = (Vector((rnd.uniform(-.6, .6), rnd.uniform(-.6, .6), rnd.uniform(-.2, .9))) + fwd(YN) * -.4) * rnd.uniform(.8, 2.0)
            dt = t - CATCH - .02
            if dt < 0 or dt > 1.0: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
            else:
                if 'palm' not in cache: cache['palm'] = wm(N['Lwrist']) @ Vector((0, 0, -.05))
                p = cache['palm'] + v * dt * (1 if dt > .1 or t > CATCH + .16 else .2) + Vector((0, 0, -4.9 * dt * dt))
                if p.z < .01: p.z = .01; ob.scale = (1.5, 1.5, .1)
                else: ob.scale = (1, 1, 1.6)
                ob.location = p
        elif i < 54:
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
            period = .5 + (i % 5) * .13; ph = ((t - CATCH) % period) / period
            if t < CATCH + .3 or t > FLICK: ob.location = (0, 0, -50); ob.scale = (0, 0, 0)
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
            ob.location = cache[ck] + drift * dt; s_ = (1 - dt / 1.6) * (1.3 if i % 4 == 3 else 1)
            ob.scale = (s_, s_, s_); ob.rotation_euler = (dt * 5 + i, dt * 3, i)
        rec(ob, 'location', ob.location, frame); rec(ob, 'scale', ob.scale, frame); rec(ob, 'rotation_euler', ob.rotation_euler, frame)
    # Fridge door, its cold light, the can (on the shelf -> in his right hand).
    fopen = sm(FR_OPEN - .05, FR_OPEN + .5, t) * (1 - sm(FR_SHUT - .4, FR_SHUT, t))
    fr_hinge.rotation_quaternion = qrot(z=-1.75 * fopen); rec(fr_hinge, 'rotation_quaternion', fr_hinge.rotation_quaternion, frame)
    fridge_light.data.energy = 160 * fopen; rec(fridge_light.data, 'energy', [fridge_light.data.energy], frame)
    if t < GRAB: CAN.location = CAN_HOME; CAN.rotation_quaternion = Quaternion()
    else:
        w = wm(N['Rwrist']); held = w @ Vector((0, -.1, -.06)); hq = w.to_quaternion()
        d = NC.get('drink', 0) if TURN1[0] < t < WALK2[0] else 0
        if d > 0:
            y = NC['yaw']; tilt = Vector((0, 0, 1)).rotation_difference((-fwd(y) * .85 + Vector((0, 0, .5))).normalized())
            held = held.lerp(can_at_mouth(y), d); hq = hq.slerp(tilt, d)
        CAN.location = held; CAN.rotation_quaternion = hq
    rec(CAN, 'location', CAN.location, frame); rec(CAN, 'rotation_quaternion', CAN.rotation_quaternion, frame)
    # Door, its light and the hanging lamp swinging after the slam.
    open_k = sm(DOOR_OPEN - .15, DOOR_OPEN + .35, t) * (1 - sm(DOOR_SHUT - .15, DOOR_SHUT, t))
    door_hinge.rotation_quaternion = qrot(z=-1.6 * open_k); rec(door_hinge, 'rotation_quaternion', door_hinge.rotation_quaternion, frame)
    door_glow.data.energy = 900 * open_k; rec(door_glow.data, 'energy', [door_glow.data.energy], frame)
    swing = .18 * math.sin((t - SLAM) * 5) * math.exp(-max(0, t - SLAM) * .8) if t > SLAM else 0
    lamp.rotation_euler = (swing, swing * .4, 0); rec(lamp, 'rotation_euler', lamp.rotation_euler, frame)
    rec_emit(MAT['code'], 2.2 * (1 if int(t * 12) % 17 else .4) * (1 + 2 * (ERASE0 < t < ERASE1) * (int(t * 20) % 2)), frame)

# ---------------------------------------------------------------- cameras
SHOTS = [('Wide', 0, RUN0, 30), ('Run', RUN0, CATCH - .27, 26), ('Catch', CATCH - .27, 5.0, 38), ('Slam', 5.0, 6.35, 32),
         ('Pinned', 6.35, SNAP - .05, 40), ('Erase', SNAP - .05, RISE0 - .2, 34), ('Rise', RISE0 - .2, WALK1[0] + .1, 35),
         ('Limp', WALK1[0] + .1, FR_OPEN - .2, 28), ('Fridge', FR_OPEN - .2, TURN1[1] - .1, 28), ('Drink', TURN1[1] - .1, WALK2[0] + .3, 35),
         ('Leave', WALK2[0] + .3, LENGTH + 1, 28)]
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
        if a <= t < b: break
    cam = CAMS[name]; u = sm(a, b, t)
    sh = shake(t, [(CATCH, .045, .45, 13), (BREAK, .025, .35, 15), (KNEE, .035, .35, 12), (SLAM, .06, .6, 11), (SNAP, .01, .2, 18), (DOOR_SHUT, .03, .4, 10)])
    hh = (math.sin(t * 1.1) * .003, math.sin(t * .8 + 1) * .002)
    hn = wm(N['head']) @ Vector((0, 0, .25)); hs = wm(S['head']) @ Vector((0, 0, .25))
    if name == 'Wide':
        c = (hn + hs) / 2 + Vector((0, 0, -.45))
        place(cam, orbit(c, mix(-30, -22, u), 6, mix(5.4, 4.6, u)), c, lens, hs, 4, extra=hh)
    elif name == 'Run':
        # low tracking side shot, Steve crosses toward Notch
        ch = wm(S['torso']).translation
        place(cam, ch + right(YS) * -3.4 + fwd(YS) * .5 + Vector((0, 0, -.15)), ch.lerp(hn, .4) + Vector((0, 0, .15)), lens, ch, 3.5, roll=.04, extra=(hh[0] * 3 + sh[0], hh[1] * 3 + sh[1]))
    elif name == 'Catch':
        # side-on: Steve's chop, the blade and Notch's bare hand clamped on it, both faces in frame
        c = hn.lerp(NC.get('grip', hn), .4) + Vector((0, 0, -.05))
        push = sm(CATCH, BREAK, t)
        place(cam, c + right(YS) * mix(1.7, 1.45, push) - fwd(YS) * mix(1.9, 1.6, push) + Vector((0, 0, .25)), c, lens, NC.get('grip', c), 3.2, roll=.04, extra=sh)
    elif name == 'Slam':
        c = (wm(S['torso']).translation + TABLE) / 2 + Vector((0, 0, .35))
        place(cam, orbit(c, mix(-118, -110, u), 6, 3.0), c, lens, c, 3.2, roll=-.03, extra=sh)
    elif name == 'Pinned':
        c = hs * .55 + hn * .45
        place(cam, orbit(c, mix(-138, -130, u), 6, mix(2.6, 2.25, u)), c, lens, hs, 2.4, roll=.04, extra=(hh[0] + sh[0], hh[1] + sh[1]))
    elif name == 'Erase':
        c = TABLE + Vector((-.55, -.2, .15))
        place(cam, orbit(c, mix(-145, -135, u), 14, mix(2.7, 2.3, u)), c, lens, c, 2.8, extra=(hh[0] + sh[0], hh[1] + sh[1]))
    elif name == 'Rise':
        # from across the table, low: he straightens up into frame, hand to his ribs
        c = Vector((WALK_BASE.x, WALK_BASE.y, 1.25)).lerp(hn, .5)
        place(cam, Vector((1.55, 2.6, .95)), c, lens, hn, 2.6, extra=hh)
    elif name == 'Limp':
        c = wm(N['torso']).translation + Vector((0, 0, .3))
        place(cam, Vector((-.6, -3.4, 2.0)).lerp(Vector((.2, -3.2, 1.9)), u), c, lens, c, 4.0, extra=hh)
    elif name == 'Fridge':
        c = FRIDGE + Vector((-.65, .05, 1.35))
        place(cam, Vector((1.9, -1.2, 1.75)).lerp(Vector((2.05, -1.05, 1.7)), u), c, lens, hn, 3.2, extra=hh)
    elif name == 'Drink':
        c = hn + Vector((0, 0, -.2))
        place(cam, Vector((FRIDGE_SPOT.x - 1.2, FRIDGE_SPOT.y - 2.1, 1.55)).lerp(Vector((FRIDGE_SPOT.x - 1.1, FRIDGE_SPOT.y - 1.9, 1.55)), u), c, lens, hn, 2.6, extra=hh)
    else:
        c = Vector((2.4, 2.0, 1.15))
        place(cam, orbit(c, mix(-28, -18, u), 8, mix(5.0, 4.4, u)), c, lens, hn, 5, extra=sh)
    rec(cam, 'location', cam.location, frame); rec(cam, 'rotation_euler', cam.rotation_euler, frame)
    rec(cam.data, 'lens', [cam.data.lens], frame); rec(cam.data, 'dof.focus_distance', [cam.data.dof.focus_distance], frame)

def hitstop(t):
    """Actors freeze for a few frames on the catch, the knee and the slam."""
    for at, hold in [(CATCH, .16), (KNEE, .08), (SLAM, .12)]:
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
