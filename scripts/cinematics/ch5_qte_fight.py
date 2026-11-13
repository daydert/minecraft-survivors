"""Chapter V close-combat QTE, choreography v3 (Godot space, Y up, actors face local +Z).
Contract with scripts/chapter_five_qte.gd and chapter_five_cinema_view.qte():
  every exchange lasts 2.4 s and starts/ends on the same neutral guard;
  contact at 1.0 s (dodge/block/hit/hurt), counter contact at 1.4 s for parry/guard;
  finisher: KO punch at .65 s, Notch's face on the table (.75, .96, 1.18) at 1.12 s.
Steve stands at x=-.62 facing +X, Notch at x=+.62 facing -X: out of arm's reach,
so every blow is a step in, never arms through bodies.
"""
import math
from mathutils import Vector
import ch5_motion as M
from ch5_portal_fight import K, fist, legs, stance, guard, head_center, to_world, sm, eo, ei, clamp, mix

PI = math.pi
SX, NX, Z = -.62, .62, .25
HIT, COUNTER = 1.0, 1.4


def shake(c, t, at, amount=.05, length=.35):
    """Camera kick at contact: a decaying jolt, deterministic."""
    if not (at <= t < at + length): return c
    k = (1 - (t - at) / length) ** 2
    c['p'] = [c['p'][0] + math.sin(t * 91) * amount * k, c['p'][1] + math.cos(t * 77) * amount * k, c['p'][2] + math.sin(t * 63) * amount * .5 * k]
    c['to'] = [c['to'][0] + math.sin(t * 83) * amount * .6 * k, c['to'][1] + math.cos(t * 97) * amount * .6 * k, c['to'][2]]
    return c


def cut(keys, t):
    """Edited coverage: (start, camera-function) shots, hard cuts between them."""
    shot = keys[0]
    for k in keys:
        if t >= k[0]: shot = k
    nxt = [k[0] for k in keys if k[0] > shot[0]]
    end = nxt[0] if nxt else 2.4
    return shot[1](clamp((t - shot[0]) / max(.001, end - shot[0])))


def cam(p, to, fov): return M.camera(list(p), list(to), fov)


def body(a, x, facing, t, hip, front_dx=0.0, back_dx=0.0, lean=.1, twist=0.0, roll=0.0, z=Z, dz=0.0):
    stance(a, x, z + dz, facing, hip=hip, bounce=.012 * math.sin(t * 8.5 + facing))
    fwd = Vector((math.sin(facing), 0, math.cos(facing)))
    # Feet plant in the neutral spot unless a step moves them on purpose.
    base = SX if facing > 0 else NX
    f0, b0 = stance({'root': {'p': [0, 0, 0], 'r': [0, 0, 0]}, 'hips': {'p': [0, .75, 0]}}, base, z, facing, hip=hip)
    legs(a, f0 + fwd * front_dx + Vector((0, 0, dz * .6)), b0 + fwd * back_dx + Vector((0, 0, dz * .3)))
    M.r(a, 'torso', lean, twist, roll)


def neutral_guard(a, w=1.0): guard(a, w)


def strike(a, side, chamber, target, t, at=HIT, wind=.55, back=1.55, through=.1):
    """Fist from a chamber (actor-local) to a world target: load, accelerate, sink in, retract."""
    load = sm(at - wind, at - .18, t); rest = sm(at + .12, back, t)
    ch = to_world(a, chamber); tgt = Vector(target)
    path = ch.lerp(tgt, ei(at - .18, at, t))
    if t > at: path = tgt + (tgt - ch).normalized() * through * eo(at, at + .08, t)
    path = path.lerp(to_world(a, (.11, 1.46, .42) if side == 'l' else (-.08, 1.48, .3)), rest)
    fist(a, path, side, max(load, 1 - rest) if t > at - wind else 0)


def recoil(a, t, at, power=1.0, up=0.0, side=1.0):
    """Jaw snap, then shoulders and hips follow; returns how far the body is knocked."""
    j = sm(at, at + .06, t) * (1 - sm(at + .25, at + .9, t))
    b = sm(at + .03, at + .18, t) * (1 - sm(at + .4, at + 1.1, t))
    M.r(a, 'head', (-.45 - up) * j * power, side * .6 * j * power * (1 - up), side * .2 * j * power)
    tor = a['torso'].get('r', [0, 0, 0])
    M.r(a, 'torso', tor[0] - (.25 + up * .3) * b * power, tor[1] + side * .2 * b * power, tor[2] + side * .08 * b * power)
    return b


def flail(a, t, at, power=1.0):
    """Guard knocked open by the blow."""
    k = sm(at, at + .08, t) * (1 - sm(at + .35, at + .9, t)) * power
    if k <= 0: return
    M.r(a, 'la', -.5 - .4 * k, 0, .5 + .7 * k); M.r(a, 'le', -.4); M.r(a, 'ra', -.3 - .3 * k, 0, -.6 - .5 * k); M.r(a, 're', -.5)
    guard(a, 1 - k)


def actors():
    return M.actor((SX, 0, Z), PI / 2), M.actor((NX, 0, Z), -PI / 2)


# ------------------------------------------------------------------ Steve attacks

OFFENCE = {
    #          side chamber          target offset       step  hip-dip  cam
    'jab':      ('l', (.14, 1.48, .25), (0, 0, 0), .26, .02),
    'cross':    ('r', (-.2, 1.4, -.05), (0, -.02, .02), .36, .05),
    'hook':     ('l', (.42, 1.45, .05), (0, 0, -.06), .3, .04),
    'uppercut': ('r', (-.08, 1.0, .12), (0, -.22, 0), .32, .16),
}


def offence(kind, t):
    s, n = actors()
    side, chamber, off, step, dip = OFFENCE[kind]
    # Steve: weight back while Notch opens up, then the step and the blow.
    sx = K(t, [(0, SX), (.4, SX - .04), (.82, SX - .06), (HIT, SX + step), (1.3, SX + step - .05), (2.05, SX)])
    hip = .66 - dip * sm(.55, .85, t) * (1 - sm(.92, 1.05, t)) + (.06 * sm(.9, 1.0, t) * (1 - sm(1.1, 1.5, t)) if kind == 'uppercut' else 0)
    coil = {'jab': -.15, 'cross': .45, 'hook': .5, 'uppercut': .3}[kind]
    unload = {'jab': -.3, 'cross': -.65, 'hook': -.85, 'uppercut': -.4}[kind]
    twist = K(t, [(0, -.1), (.55, -.1), (.85, coil), (HIT, unload), (1.35, unload * .6), (2.1, -.1)])
    lean = K(t, [(0, .1), (.8, .05), (HIT, .26 if kind != 'uppercut' else .02), (1.4, .16), (2.1, .1)])
    body(s, sx, PI / 2, t, hip, front_dx=K(t, [(0, 0), (.85, 0), (HIT, step * .9), (1.4, step * .9), (2.05, 0)]), back_dx=K(t, [(0, 0), (1.05, 0), (1.35, step * .6), (2.1, 0)]), lean=lean, twist=twist)
    neutral_guard(s)
    # Notch: the opening. He laughs, drops his hands, then eats it.
    knock = {'jab': .14, 'cross': .32, 'hook': .22, 'uppercut': .26}[kind]
    nx = K(t, [(0, NX), (.6, NX - .03), (HIT, NX - .02), (HIT + .2, NX + knock), (1.5, NX + knock * .8), (2.2, NX)])
    nhip = .67 + (.07 * sm(HIT, HIT + .1, t) * (1 - sm(1.3, 1.8, t)) if kind == 'uppercut' else -.04 * sm(HIT + .1, 1.3, t) * (1 - sm(1.4, 2.0, t)))
    body(n, nx, -PI / 2, t, nhip, front_dx=K(t, [(0, 0), (1.1, 0), (1.35, -knock * .7), (2.1, 0)]), back_dx=K(t, [(0, 0), (1.05, -knock * .8), (1.6, -knock * .6), (2.2, 0)]), lean=K(t, [(0, .1), (.6, -.08), (.95, -.06), (1.6, .05), (2.2, .1)]), twist=K(t, [(0, .1), (.6, .25), (1.2, .2), (2.2, .1)]))
    open_up = sm(.3, .7, t) * (1 - sm(1.5, 2.1, t))
    neutral_guard(n, 1 - open_up * .85)
    if open_up > .01:
        M.r(n, 'la', -.25 * open_up, 0, .35 * open_up); M.r(n, 'ra', -.25 * open_up, 0, -.35 * open_up); M.r(n, 'le', -.6 * open_up); M.r(n, 're', -.6 * open_up)
        neutral_guard(n, 1 - open_up * .85)
    target = Vector((NX - .02 - .12, 1.76, Z)) + Vector(off)
    if kind == 'hook': target += Vector((0, 0, -.12))
    strike(s, side, chamber, target, t)
    if kind == 'hook':
        M.r(n, 'root', 0, -PI / 2 + .45 * sm(HIT, HIT + .12, t) * (1 - sm(1.4, 2.1, t)), 0)
    sidek = {'jab': 0, 'cross': .3, 'hook': 1.0, 'uppercut': 0}[kind]
    recoil(n, t, HIT, {'jab': .7, 'cross': 1.1, 'hook': 1.2, 'uppercut': 1.0}[kind], up=.6 if kind == 'uppercut' else 0, side=sidek if sidek else .25)
    flail(n, t, HIT, {'jab': .4, 'cross': .9, 'hook': .8, 'uppercut': 1.0}[kind])
    M.aim_head(s, head_center(n), .8)
    return {'steve': s, 'notch': n, 'cam': offence_cam(kind, t, s, n)}


def wide(k, x0=-.15, x1=.1, d0=3.9, d1=3.5, fov=34):
    return cam((mix(x0, x1, k), 1.6, Z + mix(d0, d1, k)), (0, 1.45, Z), fov)


def ots_steve(k, look, fov=26):
    """Over Steve's right shoulder (camera side), Notch in the frame."""
    return cam((mix(-2.3, -2.15, k), 1.95, Z + mix(2.7, 2.5, k)), (look.x - .15, look.y - .1, look.z), fov)


def ots_notch(k, look, fov=26):
    return cam((mix(2.3, 2.15, k), 1.95, Z + mix(2.7, 2.5, k)), (look.x + .15, look.y - .1, look.z), fov)


def profile(k, look, fov=22, dist=2.5, dx=0.0):
    return cam((look.x + dx, look.y + .05, Z + mix(dist, dist - .25, eo(0, 1, k))), (look.x, look.y, look.z), mix(fov, fov + 4, k))


def offence_cam(kind, t, s, n):
    hn = head_center(n); hs = head_center(s)
    if kind == 'jab':
        c = cut([(0, lambda k: ots_steve(k, hn)), (.97, lambda k: profile(k, hn, 22, 2.5, -.3)), (1.75, wide)], t)
    elif kind == 'cross':
        c = cut([(0, lambda k: ots_notch(k, hs, 28)), (.97, lambda k: profile(k, hn, 20, 2.7, .25)), (1.8, wide)], t)
    elif kind == 'hook':
        def orbit(k):
            a = mix(.35, -.25, sm(0, 1, k)); r = 3.6
            return cam((math.sin(a) * r, 1.6, Z + math.cos(a) * r), (0, 1.5, Z), 30)
        c = cut([(0, orbit), (.97, lambda k: cam((hn.x + 1.3, hn.y + .1, Z + 2.2), (hn.x, hn.y, hn.z), 24)), (1.8, wide)], t)
    else:
        c = cut([(0, lambda k: cam((mix(-.25, -.1, k), .6, Z + mix(3.2, 2.9, k)), (0, 1.35, Z), 40)),
                 (.97, lambda k: cam((NX - .2, .35, Z + 2.3), (hn.x, hn.y + .1 * k, hn.z), mix(32, 38, k))), (1.85, wide)], t)
    return shake(c, t, HIT, .05 if kind in ('cross', 'uppercut') else .035)


# ------------------------------------------------------------------ Notch attacks, Steve defends

def defence(kind, t):
    s, n = actors()
    # Notch: winds up through the prompt window, throws at 1.0.
    lunge = {'slip': .3, 'parry': .26, 'guard': .28, 'roll': .3, 'miss': .32}[kind]
    nx = K(t, [(0, NX), (.5, NX + .06), (.85, NX + .03), (HIT, NX - lunge), (1.3, NX - lunge + .05), (2.1, NX)])
    if kind in ('parry', 'guard'):
        nx = K(t, [(0, NX), (.5, NX + .06), (.85, NX + .03), (HIT, NX - lunge), (1.25, NX - lunge + .04), (COUNTER, NX - lunge + .04), (1.65, NX + .2), (2.2, NX)])
    wind = {'slip': .45, 'parry': .6, 'guard': .7, 'roll': .65, 'miss': .45}[kind]
    tw = K(t, [(0, .1), (.5, .1), (HIT - .2, wind), (HIT, -.55), (1.35, -.3), (2.1, .1)])
    body(n, nx, -PI / 2, t, .66 - .04 * sm(.5, .85, t) * (1 - sm(1.0, 1.4, t)), front_dx=K(t, [(0, 0), (.85, 0), (HIT, -lunge * .9), (1.5, -lunge * .9), (2.1, 0)]), lean=K(t, [(0, .1), (.85, -.02), (HIT, .3), (1.4, .18), (2.1, .1)]), twist=tw)
    neutral_guard(n)
    hs0 = Vector((SX + .12, 1.76, Z))
    if kind == 'slip':
        strike(n, 'r', (-.2, 1.42, -.1), hs0 + Vector((-.05, .02, 0)), t, wind=.6, through=.25)
    elif kind == 'parry':
        hook_t = hs0 + Vector((.05, 0, -.22 + .2 * sm(.8, HIT, t)))
        strike(n, 'l', (.5, 1.5, .0), hook_t, t, wind=.6, through=.05)
    elif kind == 'guard':
        over = hs0 + Vector((.05, .2 - .25 * sm(.8, HIT, t), 0))
        strike(n, 'r', (-.25, 2.1, -.15), over, t, wind=.75, through=.02)
    elif kind == 'roll':
        swing = hs0 + Vector((0, .0, .35 - .7 * sm(.82, 1.12, t)))
        strike(n, 'l', (.6, 1.6, -.1), swing, t, wind=.6, through=.2)
    else:
        strike(n, 'r', (-.2, 1.42, -.1), hs0, t, wind=.55, through=.12)
    # Steve: the answer.
    sx = SX; hip = .66; dz = 0.0; lean = .1; twist = -.1
    if kind == 'slip':
        dz = .2 * sm(.8, .97, t) * (1 - sm(1.25, 1.75, t)); hip = .66 - .05 * sm(.8, .97, t) * (1 - sm(1.25, 1.75, t))
        lean = .18 * sm(.8, .97, t) * (1 - sm(1.25, 1.75, t)) + .1
        roll = .28 * sm(.8, .97, t) * (1 - sm(1.25, 1.75, t))
    elif kind == 'roll':
        duck = sm(.78, .96, t) * (1 - sm(1.2, 1.6, t))
        hip = .66 - .26 * duck; lean = .1 + .55 * duck; dz = .12 * math.sin(PI * clamp((t - .8) / .7)); roll = 0
    elif kind == 'guard':
        hip = .66 - .07 * sm(HIT, HIT + .08, t) * (1 - sm(1.15, 1.35, t)); roll = 0
        sx = K(t, [(0, SX), (HIT, SX), (HIT + .1, SX - .06), (1.25, SX - .06), (COUNTER, SX + .26), (1.7, SX + .2), (2.2, SX)])
    elif kind == 'parry':
        roll = 0; sx = K(t, [(0, SX), (1.2, SX), (COUNTER, SX + .3), (1.7, SX + .22), (2.2, SX)])
    else:
        roll = 0; sx = K(t, [(0, SX), (HIT, SX), (HIT + .15, SX - .22), (1.6, SX - .18), (2.2, SX)])
    counter = kind in ('parry', 'guard')
    twist = K(t, [(0, -.1), (1.2, -.1), (1.3, .35), (COUNTER, -.6), (1.7, -.35), (2.2, -.1)]) if counter else -.1
    body(s, sx, PI / 2, t, hip, front_dx=K(t, [(0, 0), (1.2, 0), (COUNTER, .27), (1.8, .27), (2.2, 0)]) if counter else 0.0, back_dx=K(t, [(0, 0), (HIT + .1, -.08), (1.6, -.08), (2.2, 0)]) if kind == 'miss' else 0.0, lean=lean, twist=twist, roll=roll if kind == 'slip' else 0.0, dz=dz)
    neutral_guard(s)
    if kind == 'parry':
        # Lead forearm up to the temple, the hook bounces off it.
        up = sm(.75, .95, t) * (1 - sm(1.15, 1.35, t))
        fist(s, to_world(s, (.16, 1.88, .12)), 'l', up)
    if kind == 'guard':
        up = sm(.7, .92, t) * (1 - sm(1.2, 1.35, t))
        fist(s, to_world(s, (.1, 2.02, .22)), 'l', up); fist(s, to_world(s, (-.1, 2.0, .2)), 'r', up)
    if counter:
        strike(s, 'r', (-.2, 1.4, -.05), Vector((NX - lunge + .04 - .14, 1.74, Z)), t, at=COUNTER, wind=.3, back=1.95)
        recoil(n, t, COUNTER, 1.1, side=.4); flail(n, t, COUNTER, .9)
    if kind == 'miss':
        recoil(s, t, HIT, 1.2, side=-.4); flail(s, t, HIT, 1.0)
    if kind in ('slip', 'roll'):
        # Overextended: Notch stumbles past.
        M.r(n, 'head', -.1 * sm(HIT, 1.2, t), 0, 0)
    M.aim_head(s, head_center(n), .7 * (1 - sm(.95, 1.0, t) * (1 - sm(1.3, 1.6, t))) if kind != 'miss' else .3)
    return {'steve': s, 'notch': n, 'cam': defence_cam(kind, t, s, n)}


def defence_cam(kind, t, s, n):
    hs = head_center(s); hn = head_center(n)
    if kind == 'slip':
        # Over Steve's shoulder: the fist comes at us and passes his ear.
        c = cut([(0, lambda k: ots_steve(k, hn, mix(28, 24, k))), (.99, lambda k: profile(k, Vector((-.12, 1.72, Z)), 24, 2.9, 0)), (1.6, wide)], t)
    elif kind == 'parry':
        c = cut([(0, lambda k: wide(k, .2, 0, 3.6, 3.0, 32)), (COUNTER - .03, lambda k: profile(k, hn, 20, 2.6, -.25)), (1.95, wide)], t)
    elif kind == 'guard':
        c = cut([(0, lambda k: cam((mix(.9, .7, k), 3.0, Z + mix(2.7, 2.4, k)), (SX + .1, 1.5, Z), 32)),
                 (COUNTER - .03, lambda k: cam((NX - .3, .5, Z + 2.4), (hn.x, hn.y, hn.z), mix(30, 36, k))), (1.95, wide)], t)
    elif kind == 'roll':
        c = cut([(0, lambda k: cam((mix(-2.6, -2.4, k), .7, Z + mix(2.0, 1.8, k)), (NX - .2, 1.4, Z), 32)), (1.15, wide)], t)
    else:
        c = cut([(0, lambda k: ots_notch(k, hs)), (.98, lambda k: profile(k, Vector((hs.x + .25, hs.y, Z)), 22, 2.6, 0)), (1.7, wide)], t)
    at = COUNTER if kind in ('parry', 'guard') else HIT
    c = shake(c, t, HIT, .025 if kind in ('parry', 'guard') else (.06 if kind == 'miss' else .0))
    if kind in ('parry', 'guard'): c = shake(c, t, at, .05)
    return c


def qte_jab(t): return offence('jab', t)
def qte_cross(t): return offence('cross', t)
def qte_hook(t): return offence('hook', t)
def qte_uppercut(t): return offence('uppercut', t)
def qte_slip(t): return defence('slip', t)
def qte_parry(t): return defence('parry', t)
def qte_guard(t): return defence('guard', t)
def qte_roll(t): return defence('roll', t)
def qte_miss(t): return defence('miss', t)


# ------------------------------------------------------------------ finisher

TABLE_JAW = Vector((.75, .96, 1.18))


def finisher(t):
    s, n = actors()
    KO, TABLE = .65, 1.12
    # Steve: grabs the collar, pulls him in, the big right, stands over him.
    sx = K(t, [(0, SX), (.3, SX + .18), (KO, SX + .34), (1.0, SX + .3), (1.6, SX + .22), (3.6, SX + .12)])
    hip = .66 - .05 * sm(.35, .6, t) * (1 - sm(.7, 1.0, t))
    twist = K(t, [(0, -.1), (.3, -.05), (.55, .55), (KO, -.75), (1.0, -.5), (1.8, -.2), (3.6, -.15)])
    body(s, sx, PI / 2, t, hip, front_dx=K(t, [(0, 0), (.3, .2), (KO, .32), (3.6, .26)]), back_dx=K(t, [(0, 0), (.6, 0), (.9, .14), (3.6, .1)]), lean=K(t, [(0, .1), (KO, .32), (1.2, .2), (2.2, .12), (3.6, .18)]), twist=twist)
    neutral_guard(s, 1 - sm(1.4, 2.4, t))
    lower = sm(1.4, 2.4, t)
    if lower > 0:
        M.r(s, 'la', -.15, 0, .12); M.r(s, 'le', -.25); M.r(s, 'ra', -.1, 0, -.12); M.r(s, 're', -.35)
        neutral_guard(s, 1 - lower)
    # Breathing.
    if t > 1.6:
        br = math.sin(t * 5.5) * .03
        tor = s['torso']['r']; M.r(s, 'torso', tor[0] + br, tor[1], tor[2])
    collar = Vector((NX - .12, 1.38, Z))
    fist(s, collar if t < KO else head_center(n) + Vector((-.15, -.35, 0)), 'l', sm(.1, .3, t) * (1 - sm(KO, KO + .1, t)))
    strike(s, 'r', (-.25, 1.62, -.2), Vector((NX - .16, 1.74, Z)), t, at=KO, wind=.4, back=1.6, through=.16)
    # Notch: pulled in, then the knockout spins him onto the table.
    fall = sm(.78, TABLE, t); down = sm(TABLE, 1.3, t)
    pull = sm(.1, .4, t) * (1 - sm(KO, .8, t))
    n['root']['p'] = [mix(NX - .12 * pull, .75, fall), 0, mix(Z, .45, fall)]
    n['root']['r'] = [0, mix(-PI / 2, 0, fall), 0]
    n['hips']['p'][1] = mix(.66, .70, fall)
    M.r(n, 'torso', .15 * pull, 0, 0); M.r(n, 'head', 0, 0, 0)
    recoil(n, t, KO, 1.4, side=.6)
    # the knockout recoil hands over to the fall: once he is down the jaw rests on the tabletop
    tr = n['torso']['r']; hr = n['head']['r']
    M.r(n, 'torso', mix(tr[0], .89, fall), mix(tr[1], 0, fall), mix(tr[2], -.10 * down, fall))
    M.r(n, 'head', mix(hr[0], .10, fall), mix(hr[1], 0, fall), mix(hr[2], .08 * down, fall))
    neutral_guard(n, 1 - sm(.6, .8, t))
    M.r(n, 'ra', .6 * fall + (-.6 * pull), 0, -.2 - .4 * pull); M.r(n, 'la', .45 * fall + (-.5 * pull), 0, .3 + .4 * pull); M.r(n, 're', -.25); M.r(n, 'le', -.35)
    if t < .8: neutral_guard(n, (1 - sm(.6, .8, t)) * (1 - pull))
    from ch5_fight_polish import plant
    plant(n, .75 * fall + (NX - .12 * pull) * (1 - fall), hip=n['hips']['p'][1])
    hn = head_center(n)
    c = cut([(0, lambda k: wide(k, -.3, .05, 3.6, 3.1, 30)),
             (.62, lambda k: profile(k, Vector((NX - .2, 1.7, Z)), 26, 2.9, 0)),
             (TABLE - .02, lambda k: cam((mix(2.6, 2.9, k), mix(1.4, 1.6, k), mix(3.1, 3.4, k)), (.55, mix(1.05, 1.15, k), mix(1.0, .8, k)), mix(32, 38, k)))], t)
    c = shake(shake(c, t, KO, .08), t, TABLE, .06, .4)
    return {'steve': s, 'notch': n, 'cam': c}
