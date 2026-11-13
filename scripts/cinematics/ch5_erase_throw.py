"""The throw into the terminal, v2 (tester pack 13.11: «детская» -> a real beat).
0-.42 Steve, half-deleted, rises and coils; .42-.56 the whip; .56-1.0 the blade's
flight (the camera rides behind it); 1.0 impact (hitstop, the screen bursts, Notch
is blown out of his seat); 1.3-2.7 aftermath; 2.7-4.4 a low hero shot of Steve."""
import math
from ch5_motion import actor, r, ease, mix, pulse, camera, sample_camera, aim_head, aim_blade, clamp
PI = math.pi
TARGET = (.3, 2.5, -2.7)
IMPACT = 1.0
LENGTH = 4.4

def erase_throw(t):
    s = actor((-1.6, 0, 1.2), PI * .75); n = actor((1.3, 0, -1.4), -.6)
    rise = ease(0, .3, t); coil = ease(.08, .42, t); whip = ease(.42, .56, t); thru = ease(.56, .85, t)
    settle = ease(1.2, 2.4, t); hero = ease(2.6, 3.4, t)
    # weight: low and coiled, then driven onto the front foot, then upright and still
    s['hips']['p'][1] = mix(.6, .7, rise) - .09 * whip * (1 - settle) + .03 * hero
    s['root']['p'][2] += -.22 * whip * (1 - .4 * settle)
    s['root']['p'][0] += .16 * whip * (1 - .4 * settle)
    r(s, 'torso', mix(.35, -.18, coil) + .55 * whip - .3 * settle - .08 * hero, .75 * coil - 1.35 * whip + .55 * settle, -.12 * coil + .1 * whip)
    r(s, 'ra', mix(-.5, -3.05, coil) + 1.75 * whip + .55 * thru - .7 * settle * (1 - hero) + .25 * hero, .15, mix(-.12, -.35, coil) + .2 * whip)
    r(s, 're', mix(-.3, -1.5, coil) + 1.45 * whip - .3 * settle)
    r(s, 'la', mix(-.3, -1.5, coil) + 1.1 * whip + .3 * settle, 0, mix(.12, .45, coil) - .3 * whip)
    r(s, 'le', mix(-.2, -.9, coil) + .6 * whip)
    r(s, 'll', -.45 * whip + .35 * settle, 0, 0); r(s, 'lk', .55 * whip - .45 * settle)
    r(s, 'rl', .35 * whip - .3 * settle + .1 * coil, 0, 0); r(s, 'rk', .25 * coil + .1 * whip - .3 * settle)
    breath = math.sin(t * 7) * .04 * settle
    if t > 1.2: r(s, 'torso', s['torso']['r'][0] + breath, s['torso']['r'][1], s['torso']['r'][2])
    aim_head(s, TARGET if t < 2.6 else (1.6, 1.2, -1.0))
    # blade cocked back behind the head while coiling, snapping forward through the whip
    if t < .42: aim_blade(s, (-1.6 - .71 * 3.0, 3.2, 1.2 + .71 * 3.0))
    elif t < .56: aim_blade(s, TARGET)
    # Notch: typing, looks up too late, blown out of the chair by the blast, props himself up
    blown = ease(IMPACT, IMPACT + .35, t); up = ease(2.3, 3.6, t)
    look = ease(.6, .9, t)
    n['root']['p'][0] += .9 * blown - .2 * up; n['root']['p'][2] += .5 * blown
    n['hips']['p'][1] = .75 - .45 * blown + .3 * up
    r(n, 'torso', -.2 * look - .7 * blown + .55 * up, .3 * blown, .2 * blown)
    r(n, 'ra', mix(-1.2 + math.sin(t * 18) * .15 * (1 - look), -.2, look) - .9 * pulse(t, IMPACT, .5), 0, -.4 - 1.0 * blown + .6 * up)
    r(n, 'la', mix(-1.2 - math.sin(t * 18) * .15 * (1 - look), -.2, look) - .9 * pulse(t, IMPACT, .5), 0, .5 + 1.0 * blown - .6 * up)
    r(n, 'rl', -.9 * blown + .7 * up); r(n, 'll', -.6 * blown + .5 * up); r(n, 'rk', 1.2 * blown - .9 * up); r(n, 'lk', .8 * blown - .6 * up)
    if t < IMPACT: aim_head(n, TARGET if t < .6 else (-1.6, 1.4, 1.2), 1)
    else: r(n, 'head', -.5 * blown + .4 * up, -.4 * blown, 0)
    c = sample_camera([
        (0, camera([.75, 1.05, -1.05], [-1.45, 1.35, 1.1], 40)), (.41, camera([.5, 1.1, -.8], [-1.45, 1.45, 1.1], 37)),
        (.42, camera([-2.35, 2.05, 2.55], [.2, 2.35, -2.6], 38)), (.99, camera([-1.7, 2.15, 1.3], [.3, 2.45, -2.7], 34)),
        (1.0, camera([1.1, 2.25, -.7], [.3, 2.45, -2.75], 46)), (1.29, camera([1.0, 2.2, -.85], [.3, 2.45, -2.75], 50)),
        (1.3, camera([3.6, 1.6, 1.3], [.8, 1.1, -1.5], 50)), (2.59, camera([3.3, 1.7, 1.0], [.8, 1.0, -1.5], 50)),
        (2.6, camera([-2.9, .45, 3.6], [-1.35, 1.65, .85], 40)), (4.4, camera([-2.55, .5, 3.2], [-1.35, 1.7, .85], 38))], t)
    return {'steve': s, 'notch': n, 'cam': c}
