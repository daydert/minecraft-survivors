"""Chapter V portal passages, choreography v2 (Godot space, Y up, actors face local +Z).
Replaces the layered fixed-angle shove. Contract kept for the game:
  first contact .89 s on the pusher's head near (-.18, 1.75, .5),
  counter contact 1.80 s on the victim's head near (.5, 1.75, .4),
  victim through the rift by 2.82 s, pusher by 3.65 s.
The pusher is Notch on gates 0/2/4 and Steve on 1/3 (see chapter_five_view3d.sync_portal).
"""
import math
from mathutils import Vector, Quaternion
import ch5_motion as M

PI = math.pi
GATE = Vector((3.6, 1.9, -.6))
INSIDE = GATE + Vector((.75, -1.3, -.45))
HIT1, HIT2 = .89, 1.80


def clamp(x, a=0.0, b=1.0): return max(a, min(b, x))
def sm(a, b, t): x = clamp((t - a) / (b - a)); return x * x * (3 - 2 * x)
def eo(a, b, t): x = clamp((t - a) / (b - a)); return 1 - (1 - x) ** 3
def ei(a, b, t): x = clamp((t - a) / (b - a)); return x ** 3


def K(t, keys):
    """Auto-clamped cubic through (time, value) keys: no stop at every key, no overshoot."""
    vec = isinstance(keys[0][1], (tuple, list))
    if t <= keys[0][0]: return Vector(keys[0][1]) if vec else keys[0][1]
    if t >= keys[-1][0]: return Vector(keys[-1][1]) if vec else keys[-1][1]
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


def fist(a, target, side='r', weight=1.0):
    """Arm IK to a world point; blends from whatever rotation the arm already has."""
    if weight <= 0: return
    upper = side + 'a'; lower = side + 'e'; world = M.matrices(a)
    parent = world['torso']; shoulder = parent @ Vector(M.REST[upper]); delta = parent.to_3x3().inverted() @ (Vector(target) - shoulder)
    length = max(.05, min(.619, delta.length)); direction = delta.normalized()
    # Elbows hang down and a little out, as in a real guard; never flare up behind the back.
    pole = Vector((.55 if side == 'l' else -.55, -1, -.1)); pole = (pole - direction * pole.dot(direction)).normalized()
    along = (.25 ** 2 - .375 ** 2 + length ** 2) / (2 * length); mid = direction * along + pole * math.sqrt(max(0, .25 ** 2 - along ** 2))
    top = Vector((0, -1, 0)).rotation_difference(mid.normalized()); bottom = Vector((0, -1, 0)).rotation_difference((delta - mid).normalized())
    for key, q in [(upper, top), (lower, top.inverted() @ bottom)]:
        d = a[key]; cur = Quaternion((d['q'][3], *d['q'][:3])) if 'q' in d else M.rotation(d.get('r', [0, 0, 0])).to_quaternion()
        q = cur.slerp(q, clamp(weight)); d.pop('r', None); d['q'] = [q.x, q.y, q.z, q.w]


def to_world(a, local):
    return Vector(a['root']['p']) + M.rotation(a['root']['r']) @ Vector(local)


def legs(a, front, back, knee_pole=1.0):
    """Two-bone leg IK to world foot points (lead = left leg)."""
    R = M.rotation(a['root']['r']); root = Vector(a['root']['p']); hip = a['hips']['p'][1]
    hips_rot = M.rotation(a['hips'].get('r', [0, 0, 0]))
    for leg, knee, x, foot in [('ll', 'lk', .11875, front), ('rl', 'rk', -.11875, back)]:
        local = hips_rot.inverted() @ (R.inverted() @ (Vector(foot) - root) - Vector((0, hip, 0))) - Vector((x, 0, 0))
        length = min(.748, local.length); d = local.normalized()
        pole = Vector((0, 0, knee_pole)); pole = (pole - d * pole.dot(d)).normalized()
        mid = d * (length / 2) + pole * math.sqrt(max(0, .375 ** 2 - (length / 2) ** 2))
        top = Vector((0, -1, 0)).rotation_difference(mid.normalized())
        bottom = Vector((0, -1, 0)).rotation_difference((local - mid).normalized())
        for key, q in [(leg, top), (knee, top.inverted() @ bottom)]: a[key]['q'] = [q.x, q.y, q.z, q.w]
        a[leg].pop('r', None); a[knee].pop('r', None)


def stance(a, x, z, facing, hip=.66, spread=.2, bounce=0.0):
    """Fighting stance on the ground: lead foot forward, rear foot back, knees soft."""
    a['root']['p'] = [x, 0, z]; a['root']['r'] = [0, facing, 0]
    a['hips']['p'][1] = hip - bounce
    fwd = Vector((math.sin(facing), 0, math.cos(facing))); side = Vector((math.cos(facing), 0, -math.sin(facing)))
    root = Vector((x, 0, z))
    return root + fwd * spread + side * .13, root - fwd * spread * 1.1 - side * .13


def guard(a, w=1.0, lead=(.11, 1.46, .42), rear=(-.08, 1.48, .3)):
    fist(a, to_world(a, lead), 'l', w); fist(a, to_world(a, rear), 'r', w)


def head_center(a): return M.matrices(a)['head'] @ Vector((0, .25, 0))


def blank(p, yaw): return M.actor(p, yaw)


# ------------------------------------------------------------------ attacks
# Each counter: (crouch depth, coil yaw, chamber local point, strike offset at the target, body drive)
COUNTERS = {
    0: ('uppercut', .14, -.55, (-.12, 1.0, .1), (0, -.18, -.02), .38),
    1: ('shoulder', .08, -.25, (-.05, 1.3, .0), (0, -.05, .05), .55),
    2: ('hook', .06, -.85, (-.35, 1.45, -.05), (0, -.02, .08), .32),
    3: ('overhand', .1, -.75, (-.2, 1.85, -.1), (0, .12, 0), .42),
    4: ('grab', .1, -.3, (.0, 1.35, .25), (0, -.25, 0), .5),
}


def portal(index, t):
    kind, crouch, coil, chamber, strike_off, drive = COUNTERS[index]
    p = blank((-1.6, 0, .5), PI / 2)   # pusher, faces +X
    v = blank((.55, 0, .4), -PI / 2)   # victim, faces -X
    # --- pusher: advance, eat the first blow, recover, counter, follow through, dive
    px = K(t, [(0, -1.6), (.35, -1.15), (.7, -.4), (.89, -.33), (1.15, -.6), (1.4, -.55), (1.62, -.5), (1.8, -.22), (2.1, -.12), (2.75, -.2)])
    bounce = .02 * math.sin(t * 9) * (1 - sm(.6, .8, t))
    if t < 2.75:
        f, b = stance(p, px, .5, PI / 2, hip=.66 - crouch * sm(1.3, 1.6, t) * (1 - sm(1.8, 2.2, t)) - .04 * sm(.92, 1.05, t) * (1 - sm(1.2, 1.45, t)), bounce=bounce)
        # Feet: lead foot steps on the advance, rear foot drags back on the stagger.
        f = f + Vector((K(t, [(0, 0), (.3, .0), (.45, .15), (.89, .12), (1.1, -.05), (1.62, -.05), (1.75, .18), (2.2, .1)]), 0, 0))
        b = b + Vector((K(t, [(0, 0), (.5, .1), (.89, .05), (1.1, -.12), (1.5, -.1), (1.8, .05), (2.2, 0)]), 0, 0))
        legs(p, f, b)
        # torso: lean in, snap back from the hit, coil, unload.
        lean = K(t, [(0, .1), (.7, .16), (.89, .18), (.95, -.18), (1.25, .02), (1.5, .2), (1.8, .3), (2.1, .18), (2.7, .1)])
        twist = K(t, [(0, -.2), (.89, -.2), (.95, .45), (1.2, .1), (1.45, coil), (1.62, coil), (1.8, -coil * .7), (2.2, -.1), (2.7, -.05)])
        M.r(p, 'torso', lean, twist, K(t, [(0, 0), (.89, 0), (.97, .15), (1.3, 0)]))
        # head: snapped sideways by the first blow, then eyes locked on the victim.
        snap = K(t, [(0, 0), (.89, 0), (.93, 1), (1.15, .45), (1.4, 0)])
        M.r(p, 'head', -.35 * snap, .75 * snap, -.2 * snap)
        if snap < .2: M.aim_head(p, head_center(v), .8)
        # arms: guard, flung by the hit, chamber, strike, follow-through.
        g = 1 - sm(.89, .93, t) * (1 - sm(1.15, 1.35, t))
        guard(p, g)
        if g < 1:
            M.r(p, 'la', -.4, 0, .9 * (1 - g)); M.r(p, 'le', -.2); M.r(p, 'ra', .3 * (1 - g), 0, -.6 * (1 - g)); M.r(p, 're', -.3)
            guard(p, g)
        if t >= 1.35:
            target = head_center(v) + Vector(strike_off)
            load = sm(1.35, 1.62, t); hit = ei(1.62, HIT2, t); rest = sm(2.0, 2.6, t)
            ch = to_world(p, chamber)
            fist_at = ch.lerp(target, hit)
            if t > HIT2: fist_at = target + (target - ch).normalized() * .25 * eo(HIT2, 2.0, t)
            fist_at = fist_at.lerp(to_world(p, (-.08, 1.48, .3)), rest)
            fist(p, fist_at, 'r', max(load, 1 - rest * .8))
            if kind in ('shoulder', 'grab'):
                fist(p, (head_center(v) + Vector((0, -.35, -.05))).lerp(to_world(p, (.11, 1.46, .42)), rest), 'l', max(load, 1 - rest))
    else:
        # Two strides and a dive into the rift.
        k = clamp((t - 2.8) / .85)
        start = Vector((-.2, 0, .5)); end = INSIDE + Vector((-.1, 0, .1))
        pos = start.lerp(end, ei(0, 1, k) * .4 + k * .6); pos.y += math.sin(k * PI) * .6
        p['root']['p'] = list(pos)
        yaw = math.atan2(end.x - start.x, end.z - start.z)
        p['root']['r'] = [.6 * sm(.4, .9, k), yaw, 0]
        run = math.sin(k * PI * 3)
        M.r(p, 'rl', .7 * run - .4 * sm(.5, 1, k)); M.r(p, 'll', -.7 * run - .4 * sm(.5, 1, k)); M.r(p, 'rk', .9 * sm(.4, .8, k) + max(0, run) * .6); M.r(p, 'lk', .9 * sm(.4, .8, k) + max(0, -run) * .6)
        M.r(p, 'ra', -2.6 * sm(.35, .8, k) - .3, 0, -.1); M.r(p, 'la', -2.6 * sm(.35, .8, k) - .3, 0, .1); M.r(p, 're', -.15); M.r(p, 'le', -.15)
        M.r(p, 'torso', .3 + .3 * sm(.3, .8, k)); M.r(p, 'head', -.25)
    # --- victim: waits, steps in with the first strike, eats the counter, flies through the rift
    if t < HIT2:
        vx = K(t, [(0, .55), (.55, .55), (.72, .5), (.89, .38), (1.1, .48), (1.6, .52), (HIT2, .5)])
        f, b = stance(v, vx, .4, -PI / 2, hip=.67 - .05 * sm(.6, .75, t) * (1 - sm(.95, 1.2, t)), bounce=.015 * math.sin(t * 8 + 1))
        legs(v, f + Vector((-K(t, [(0, 0), (.62, 0), (.8, .18), (1.1, .1), (1.5, .05)]), 0, 0)), b)
        M.r(v, 'torso', K(t, [(0, .1), (.62, .08), (.86, .28), (1.0, .14), (1.6, .12)]), K(t, [(0, .2), (.62, .35), (.89, -.45), (1.05, -.2), (1.5, .2)]), 0)
        M.aim_head(v, head_center(p), .9)
        guard(v)
        # first strike: rear-hand cross (even gates) or lead hook (odd gates) into the pusher's jaw.
        side = 'r' if index % 2 == 0 else 'l'
        target = Vector((-.18, 1.75, .5)) + Vector((0, -.1, 0))
        load = sm(.6, .75, t); hit = ei(.75, HIT1, t); back = sm(.98, 1.3, t)
        chamber_v = to_world(v, (-.12, 1.35, .05) if side == 'r' else (.3, 1.45, .05))
        fist_at = chamber_v.lerp(target, hit).lerp(to_world(v, (-.08, 1.48, .3) if side == 'r' else (.11, 1.46, .42)), back)
        fist(v, fist_at, side, max(load * (1 - back), 1 - back) if t > .6 else 0)
        if t > 1.62:  # braces too late
            M.r(v, 'head', -.15 * sm(1.62, 1.78, t), 0, 0)
    else:
        k = clamp((t - HIT2) / (2.82 - HIT2))
        start = Vector((.5, 0, .4))
        u = eo(0, 1, k) * .7 + k * .3
        pos = start.lerp(INSIDE, u); pos.y += math.sin(k * PI) * (.95 if kind in ('uppercut', 'overhand') else .55)
        v['root']['p'] = list(pos)
        tumble = (2.6 if kind == 'uppercut' else 1.6) * eo(0, 1, k)
        v['root']['r'] = [-tumble * (1 if kind != 'hook' else .4), -PI / 2 + (1.4 * k if kind == 'hook' else .3 * k), (.9 if kind == 'hook' else .2) * math.sin(k * PI)]
        v['hips']['p'][1] = .75
        # Head whips back first, the limbs trail the body.
        lag = eo(0, .35, k)
        M.r(v, 'head', -.9 * (1 - lag * .5), .3, .2)
        M.r(v, 'torso', -.4 * (1 - lag) - .2, .2, 0)
        M.r(v, 'ra', -2.4 + .6 * math.sin(k * 9), 0, -.6); M.r(v, 're', -.5); M.r(v, 'la', -2.1 + .5 * math.cos(k * 8), 0, .7); M.r(v, 'le', -.35)
        M.r(v, 'rl', -.3 - .4 * lag); M.r(v, 'll', .25); M.r(v, 'rk', .9 * lag); M.r(v, 'lk', .4)
    s, n = (v, p) if index in (0, 2, 4) else (p, v)
    return {'steve': s, 'notch': n, 'cam': portal_camera(index, t, p, v)}


def portal_camera(index, t, p, v):
    """Edited coverage: wide → reaction close-up → low side on the counter → follow to the rift."""
    if t < .8:
        k = sm(0, .8, t)
        return M.camera([mix(-.6, -.3, k), 1.25, mix(4.9, 4.4, k)], [.1, 1.25, .4], 46)
    if t < 1.38:
        h = head_center(p)
        k = sm(.8, 1.38, t)
        return M.camera([2.0, 1.55, mix(3.0, 2.75, k)], [h.x + .25, h.y - .15, h.z], 40)
    if t < 2.25:
        k = sm(1.38, 2.25, t)
        return M.camera([mix(-.35, -.15, k), .5, 3.0], [mix(.3, 1.4, sm(1.8, 2.25, t)), mix(1.25, 1.45, sm(1.8, 2.25, t)), .25], 52)
    k = sm(2.25, 4.4, t)
    return M.camera([mix(-1.9, -1.1, k), 1.85, mix(4.4, 3.6, k)], [mix(1.6, 3.2, k), 1.35, mix(.1, -.5, k)], 46)


def mix(a, b, k): return a + (b - a) * k
