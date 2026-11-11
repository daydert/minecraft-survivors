"""Chapter V ending: eleven small worlds Steve flies past, one per game the
player named. Each is an original scene that only evokes its genre and mood
(no characters or symbols are copied); the real logos float above them.
Groups named anim_<kind>_s<speed> are animated in Godot.
Run: blender --background --python scripts/blender_dioramas.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import blender_lib as L
from blender_lib import ROOT, beam_between, box, cylinder, gable, group, mat, quad, sphere

TAU = math.tau


def C(r, g, b, rough=.6, metal=0.0, emit=0.0):
    return mat("c%.2f_%.2f_%.2f_%.1f_%.1f_%.1f" % (r, g, b, rough, metal, emit), None, (r, g, b, 1), rough=rough, metal=metal, emit=emit)


def T(name, tint=(1, 1, 1, 1), rough=.85, emit=0.0):
    return mat(name + str(tint) + str(emit), name, tint, rough=rough, emit=emit)


def wheels(parent, xs, zs, y, r, w=.18):
    for x in xs:
        for z in zs:
            cylinder("wheel", (x, y, z), r, r, w, C(.06, .06, .06, .9), 1, rot=(0, 0, math.pi / 2), parent=parent)
            cylinder("hub", (x + (w / 2 + .01) * (1 if x > 0 else -1), y, z), r * .5, r * .5, .02, C(.7, .7, .72, .3, .8), 1, rot=(0, 0, math.pi / 2), parent=parent)


def palm(at, h=3.4):
    g = group("palm", at)
    for k in range(7):
        cylinder("trunk", (math.sin(k * .3) * .06 * k, k * h / 7 + h / 14, 0), .1 - k * .006, .12 - k * .006, h / 7, C(.45, .33, .22, .9), 1, sides=8, parent=g)
    top = (math.sin(2.1) * .4, h, 0)
    for k in range(9):
        a = k / 9 * TAU
        tip = (top[0] + math.cos(a) * 1.5, h - .6, math.sin(a) * 1.5)
        mid = (top[0] + math.cos(a) * .8, h + .15, math.sin(a) * .8)
        beam_between("frond", top, mid, .14, C(.22, .55, .22, .8), parent=g)
        beam_between("frond", mid, tip, .1, C(.25, .6, .25, .8), parent=g)
    return g


def tree(at, h=2.4, col=(.25, .5, .2)):
    cylinder("trunk", (at[0], h * .25, at[2]), .1, .14, h * .5, C(.35, .25, .17, .9), 1, sides=8)
    sphere("crown", (at[0], h * .7, at[2]), h * .32, C(*col, rough=.9), squash=(1, 1.25, 1), segments=10, rings=7)


# ------------------------------------------------------------------ 0 sunset city with a sports car
def city():
    box("slab", (0, -.3, 0), (16, .6, 16), T("ch5w_tf2_concrete", (.8, .78, .74, 1)), 3)
    box("road", (0, .02, 0), (4.4, .06, 16), T("ch5w_gta_road"), 4.4)
    for z in range(-6, 7, 2):
        box("crosswalk", (0, .06, 6.8 + 0 * z), (4.2, .02, .3), C(.92, .92, .9), 1) if z == 0 else None
    for k in range(7):
        box("stripe", (-1.6 + k * .55, .06, 6.6), (.3, .02, 1.0), C(.92, .92, .9), 1)
    for side in (-1, 1):
        box("curb", (side * 2.4, .1, 0), (.3, .2, 16), C(.75, .74, .7), 2)
    heights = [9.0, 6.0, 13.0, 7.5, 11.0, 5.5, 15.0, 8.0]
    for k, hh in enumerate(heights):
        side = -1 if k % 2 == 0 else 1
        z = -6 + (k // 2) * 3.4
        x = side * (4.6 + (k % 3) * .4)
        glass = k % 3 != 1
        box("tower", (x, hh / 2, z), (2.6, hh, 2.6), T("ch5w_gta_glass" if glass else "ch5w_gta_office", rough=.25 if glass else .8), 3, bevel=.04)
        box("crown", (x, hh + .2, z), (2.8, .4, 2.8), C(.8, .78, .72), 2)
        box("ac", (x + .5, hh + .6, z - .4), (.7, .4, .5), C(.6, .62, .6, .5, .4), 1)
        if k % 2 == 0:cylinder("antenna", (x - .6, hh + 1.6, z + .6), .03, .05, 2.4, C(.6, .6, .6, .3, .8), 1)
    for k in range(6):
        palm((-2.9 if k % 2 else 2.9, 0, -6.5 + k * 2.3), 3.0 + (k % 3) * .4)
    for z in (-3.0, 3.0):
        for side in (-1, 1):
            cylinder("lamp", (side * 2.7, 1.6, z), .05, .06, 3.2, C(.3, .3, .32, .4, .7), 1)
            beam_between("lamp_arm", (side * 2.7, 3.15, z), (side * 1.9, 3.15, z), .06, C(.3, .3, .32, .4, .7))
            box("lamp_head", (side * 1.85, 3.1, z), (.35, .1, .2), C(1, .9, .7, emit=3.0))
    car = group("anim_drive_s10", (1.0, .32, 1.5))
    body = C(.95, .42, .05, .15, .3)
    box("body", (0, .15, 0), (1.15, .32, 2.6), body, 2, bevel=.06, parent=car)
    box("hood", (0, .32, .75), (1.05, .1, .9), body, 2, rot=(-.12, 0, 0), parent=car)
    box("cabin", (0, .45, -.25), (.95, .3, 1.1), C(.05, .07, .1, .05, .5), 2, bevel=.05, parent=car)
    box("spoiler", (0, .55, -1.25), (1.1, .05, .25), body, 1, parent=car)
    for x in (-.4, .4):
        box("headlight", (x, .2, 1.31), (.25, .08, .03), C(1, .95, .8, emit=4), 1, parent=car)
        box("taillight", (x, .22, -1.31), (.3, .07, .03), C(1, .1, .05, emit=3), 1, parent=car)
    wheels(car, (-.6, .6), (-.85, .85), -.02, .22)
    for k in range(4):
        sphere("hill", (-9 + k * 6, -1.5, -10), 4.5, C(.62, .5, .32, 1), squash=(1.4, .55, 1), segments=12, rings=8)
    quad("sky", (0, 6, -11.5), (26, 13), T("ch5w_gta_sky", emit=1.0))


# ------------------------------------------------------------------ 1 a pastel alien world and its creature
def alien():
    rock = T("ch5w_spore_ground", rough=.9)
    cylinder("island", (0, -1.2, 0), 7.2, 4.0, 2.4, rock, 3, sides=32)
    cylinder("island_tip", (0, -3.4, 0), 4.0, .8, 2.0, rock, 3, sides=24)
    for k in range(6):
        a = k / 6 * TAU
        sphere("boulder", (math.cos(a) * 5.6, .2, math.sin(a) * 5.6), .5 + (k % 3) * .25, C(.55, .3, .6, .9), squash=(1, .7, 1), segments=10, rings=6)
    cr = group("anim_bob_s20", (0, 1.25, .8))
    skin = T("ch5w_spore_skin", rough=.6)
    sphere("body", (0, 0, 0), 1.0, skin, squash=(1.35, .85, 1.0), parent=cr)
    sphere("belly", (0, -.2, .45), .7, C(1, .85, .55, .7), squash=(1.1, .7, .7), parent=cr)
    sphere("head", (0, .55, 1.0), .62, skin, parent=cr)
    for k in range(4):
        x, z = (-.8, .8)[k % 2], (-.45, .45)[k // 2]
        cylinder("leg", (x, -.75, z), .1, .18, 1.0, skin, 1, sides=10, parent=cr)
        sphere("foot", (x, -1.25, z + .1), .2, C(.5, .2, .55, .7), squash=(1, .5, 1.4), parent=cr)
    for k in (-1, 1):
        cylinder("stalk", (k * .25, 1.15, 1.05), .05, .05, .7, skin, 1, sides=8, parent=cr)
        sphere("eye", (k * .25, 1.55, 1.1), .22, C(1, 1, 1, .15), parent=cr)
        sphere("pupil", (k * .25, 1.57, 1.3), .1, C(.03, .03, .06, .1), parent=cr)
    sphere("mouth", (0, .35, 1.55), .22, C(.4, .05, .12, .8), squash=(1.6, .5, .5), parent=cr)
    for k in range(5):
        cylinder("crest", (0, .85 + k * .02, -.5 + k * .25), 0, .14, .5, C(.4, .85, 1, .4), 1, sides=6, rot=(-.3, 0, 0), parent=cr)
    cylinder("tail", (0, .1, -1.3), .05, .25, 1.0, skin, 1, rot=(1.2, 0, 0), sides=10, parent=cr)
    for k in range(9):
        a = k * 2.39996
        x, z = math.cos(a) * (3 + k % 3), math.sin(a) * (2.5 + k % 3) - 1
        h = 1.6 + (k % 3) * .8
        cylinder("stem", (x, h / 2, z), .08, .14, h, C(.35, .85, .55, .6), 1, sides=8)
        col = [(1, .5, .8), (.5, .9, 1), (1, .9, .3)][k % 3]
        sphere("pod", (x, h + .35, z), .45 + (k % 2) * .2, C(*col, rough=.35, emit=.5), squash=(1, 1.2, 1))
        if k % 3 == 0:
            for j in range(4):sphere("spore", (x + math.cos(j * 1.6) * .5, h + .9 + j * .15, z + math.sin(j * 1.6) * .5), .07, C(1, 1, .8, emit=3))
    hut = group("hut", (-3.5, 0, -3))
    sphere("hut_dome", (0, .3, 0), 1.3, C(.75, .55, .3, .9), squash=(1, .8, 1), parent=hut)
    box("hut_door", (0, .45, 1.15), (.6, .8, .2), C(.15, .08, .05, 1), 1, parent=hut)
    ufo = group("anim_hover_s10", (3.0, 6.0, -2.0))
    sphere("saucer", (0, 0, 0), 1.7, C(.78, .8, .88, .15, .7), squash=(1, .22, 1), segments=24, parent=ufo)
    sphere("dome", (0, .3, 0), .75, C(.45, 1, .85, .05, emit=1.2), squash=(1, .75, 1), parent=ufo)
    ring = group("anim_spin_s30", (0, -.15, 0), parent=ufo)
    for k in range(8):
        a = k / 8 * TAU
        sphere("ufo_light", (math.cos(a) * 1.45, 0, math.sin(a) * 1.45), .12, C(1, .85, .3, emit=5), parent=ring)
    cylinder("beam", (3.0, 2.8, -2.0), 1.2, .4, 5.4, mat("ufo_beam", None, (.6, 1, .9, .25), emit=1.5, alpha=False), 1, caps=False)


# ------------------------------------------------------------------ 2 a three-lane arena with two ancients
def arena():
    box("ground", (0, -.4, 0), (16, .8, 16), T("ch5w_dota_grass"), 5)
    dire = T("ch5w_dota_dire")
    # Dark half: a triangle of scorched ground.
    for k in range(8):
        box("dire", (3.5 + k * .55, -.37, 3.5 + k * .55), (16 - k * 1.9 - 7, .8, 1.2), dire, 4, rot=(0, math.pi / 4, 0)) if False else None
    box("dire_half", (4, -.36, 4), (8, .8, 8), dire, 4)
    box("river", (0, -.33, 0), (2.6, .8, 21), T("ch5w_dota_river", rough=.15, emit=.3), 4, rot=(0, math.pi / 4, 0))
    path = T("ch5w_tf2_ground", (.75, .65, .5, 1))
    for (a, b) in (((-6, -6), (-6, 6)), ((-6, 6), (6, 6)), ((-6, -6), (6, -6)), ((6, -6), (6, 6)), ((-6, -6), (6, 6))):
        ax, az = a;bx, bz = b
        beam_between("lane", (ax, .02, az), (bx, .02, bz), .1, path) if False else None
        L_ = math.hypot(bx - ax, bz - az)
        box("lane", ((ax + bx) / 2, .03, (az + bz) / 2), (1.3, .06, L_), path, 3, rot=(0, math.atan2(bx - ax, bz - az), 0))
    stone = T("ch5w_dota_stone")
    for corner, col, s in (((-6, -6), (.45, 1, .6), -1), ((6, 6), (1, .25, .15), 1)):
        cx, cz = corner
        cylinder("base_ring", (cx, .4, cz), 2.0, 2.4, .8, stone, 2, sides=10)
        cylinder("base_ring2", (cx, 1.0, cz), 1.5, 1.7, .5, stone, 2, sides=10)
        anc = group("anim_spin_s06", (cx, 3.0, cz))
        if s < 0:
            cylinder("crystal", (0, 0, 0), 0, .8, 2.6, C(*col, rough=.1, emit=1.8), 1, sides=5, parent=anc)
            cylinder("crystal_b", (0, -1.1, 0), .8, 0, .6, C(*col, rough=.1, emit=1.8), 1, sides=5, parent=anc)
            for k in range(3):cylinder("shard", (math.cos(k * 2.1) * .9, -.4, math.sin(k * 2.1) * .9), 0, .25, 1.2, C(*col, rough=.1, emit=1.5), 1, sides=5, rot=(.3, k * 2.1, 0), parent=anc)
        else:
            sphere("core", (0, 0, 0), .7, C(*col, rough=.3, emit=2.5), parent=anc)
            for k in range(6):cylinder("spike", (math.cos(k * 1.05) * .6, .2, math.sin(k * 1.05) * .6), 0, .2, 1.8, C(.15, .05, .05, .5), 1, sides=6, rot=(math.cos(k * 1.05) * .7, 0, -math.sin(k * 1.05) * .7), parent=anc)
    for (x, z), col in (((-6, -1), (.45, 1, .6)), ((-6, 3), (.45, 1, .6)), ((-1.5, -1.5), (.45, 1, .6)), ((-1, -6), (.45, 1, .6)), ((3, -6), (.45, 1, .6)),
                        ((6, 1), (1, .3, .2)), ((6, -3), (1, .3, .2)), ((1.5, 1.5), (1, .3, .2)), ((1, 6), (1, .3, .2)), ((-3, 6), (1, .3, .2))):
        cylinder("tower", (x, 1.1, z), .35, .55, 2.2, stone, 1.5, sides=8)
        cylinder("tower_top", (x, 2.35, z), .6, .45, .3, stone, 1, sides=8)
        sphere("tower_gem", (x, 2.8, z), .3, C(*col, rough=.1, emit=3))
    for k in range(18):
        a = k * 2.39996
        x, z = math.cos(a) * (2.5 + (k % 4)), math.sin(a) * (2.5 + (k % 4))
        if abs(x - z) < 1.8 or abs(abs(x) - 6) < 1 or abs(abs(z) - 6) < 1:continue
        dark = x + z > 0
        cylinder("pine", (x, 1.0, z), 0, .6, 2.0, C(.2, .15, .12) if dark else C(.15, .42, .2), 1, sides=8)
        cylinder("pine_trunk", (x, .15, z), .1, .1, .3, C(.3, .2, .15), 1, sides=6)
    for k in range(4):
        for team, (x, z) in ((0, (-3 + k * .5, -3 + k * .5)), (1, (3 - k * .5, 3 - k * .5))):
            box("creep", (x, .3, z + .4), (.3, .5, .3), C(.3, .8, .35) if team == 0 else C(.8, .2, .15), 1, bevel=.03)
            sphere("creep_head", (x, .65, z + .4), .15, C(.9, .8, .6))


# ------------------------------------------------------------------ 3/4 framed pixel-RPG screens with a 3D foreground
def rpg(kind):
    dark = kind == 3
    wood = T("ch5q_dark_oak_planks") if dark else C(.28, .22, .17, .9)
    screen = mat("screen_" + str(kind), "ch5w_rpg_black" if dark else "ch5w_rpg_fear", emit=.8, nearest=True)
    box("frame_back", (0, 5.0, -.35), (17.2, 13.2, .3), wood, 2)
    for x in (-8.3, 8.3):box("frame_side", (x, 5.0, -.1), (.8, 13.6, .6), wood, 2, bevel=.08)
    for y in (-1.6, 11.6):box("frame_top", (0, y, -.1), (17.4, .8, .6), wood, 2, bevel=.08)
    for x in (-8.3, 8.3):
        for y in (-1.6, 11.6):sphere("frame_knob", (x, y, .25), .5, C(.75, .6, .25, .3, .7) if dark else C(.4, .35, .3, .7), segments=10, rings=6)
    quad("screen", (0, 5.0, .05), (15.6, 11.7), screen)
    box("floor", (0, -2.2, 3), (18, .4, 6), T("ch5w_tf2_rock", (.45, .4, .45, 1) if dark else (.4, .35, .3, 1)), 3)
    if dark:
        for k in range(4):
            x = (-6.5, -3.5, 3.8, 6.5)[k]
            cylinder("dead_trunk", (x, -.6, 3 + (k % 2)), .12, .25, 3.0, C(.12, .08, .1, 1), 1, sides=7)
            for j in range(3):beam_between("branch", (x, .2 + j * .4, 3 + (k % 2)), (x + (1 if j % 2 else -1) * 1.2, 1.0 + j * .5, 3.3 + (k % 2)), .08, C(.12, .08, .1, 1))
        for k in range(5):
            box("grave", (-4 + k * 2, -1.5, 4.5), (.7, 1.0, .2), C(.4, .4, .45, .9), 1, bevel=.08, rot=(0, 0, (k % 3 - 1) * .1))
        for k in range(12):
            g = group("anim_fall_s%02d" % (5 + k % 5), (-7 + k * 1.3, 6 + math.sin(k) * 4, 1.5))
            box("petal", (0, 0, 0), (.3, .14, .05), C(.85, .05, .1, .5, emit=.6), 1, parent=g)
        cylinder("lantern_post", (5.5, -.8, 5), .05, .05, 2.6, C(.15, .15, .15, .5, .6), 1)
        box("lantern", (5.5, .65, 5), (.35, .45, .35), C(1, .3, .2, emit=3), 1)
    else:
        for x in (-6.0, 6.0):
            box("pillar", (x, 1.0, 3.5), (1.1, 6.0, 1.1), T("ch5w_dota_stone", (.6, .55, .5, 1)), 1.5)
            cylinder("candle", (x, 4.3, 3.6), .15, .15, .6, C(.9, .85, .7), 1)
            f = group("anim_flicker_s10", (x, 4.8, 3.6))
            sphere("flame", (0, 0, 0), .14, C(1, .6, .15, emit=6), squash=(1, 1.7, 1), parent=f)
        box("arch", (0, 4.3, 3.5), (13.1, .8, 1.0), T("ch5w_dota_stone", (.6, .55, .5, 1)), 1.5)
        for k in range(6):
            beam_between("chain", (-4 + k * 1.6, 4.0, 3.5), (-4 + k * 1.6, 2.6 - (k % 2) * .6, 3.5), .05, C(.35, .33, .3, .4, .8))
        for k in range(5):
            sphere("bone", (-3 + k * 1.4, -1.85, 4.6 + (k % 2) * .4), .18, C(.9, .86, .78, .8), squash=(2.2, .6, .6))
        sphere("skull", (1.5, -1.75, 5.0), .32, C(.9, .86, .78, .8))


# ------------------------------------------------------------------ 5 a suburban house in cutaway with a floating gem
def suburb():
    box("lawn", (0, -.3, 0), (16, .6, 16), T("ch5w_sims_grass"), 5)
    box("path", (1.5, .02, 4.8), (1.4, .05, 6), T("ch5w_tf2_concrete"), 2)
    box("floor", (0, .12, -1.5), (10, .24, 8), T("ch5w_sims_floor"), 2)
    wall = T("ch5w_sims_wall")
    box("wall_back", (0, 1.5, -5.4), (10, 2.8, .25), wall, 2.5)
    box("wall_left", (-5, 1.5, -1.5), (.25, 2.8, 8), wall, 2.5)
    box("wall_mid", (1.0, 1.5, -2.8), (.25, 2.8, 5.2), wall, 2.5)
    for x in (-5.0, 5.0):box("wall_low", (x, .55, 2.4), (.25, .8, .2) if x < 0 else (.25, .8, 8), wall, 2.5) if x > 0 else None
    box("wall_right_low", (5, .6, -1.5), (.25, .9, 8), wall, 2.5)
    # Living room.
    box("sofa", (-2.5, .55, -4.6), (3.0, .6, 1.0), C(.3, .45, .8, .8), 1, bevel=.08)
    box("sofa_back", (-2.5, 1.0, -5.05), (3.0, .7, .3), C(.3, .45, .8, .8), 1, bevel=.08)
    box("rug", (-2.5, .26, -2.8), (3.2, .02, 2.2), C(.85, .4, .35, .9), 1)
    box("table", (-2.5, .55, -2.8), (1.4, .1, .8), C(.5, .32, .2, .5), 1)
    box("tv", (-2.5, 1.0, -.6), (1.6, .9, .1), C(.05, .05, .07, .2, emit=.0), 1)
    box("tv_screen", (-2.5, 1.0, -.66), (1.4, .75, .02), C(.4, .7, 1, emit=1.5), 1)
    # Kitchen.
    box("counter", (3.0, .7, -5.0), (3.4, 1.0, .8), C(.92, .9, .86, .3), 1, bevel=.03)
    box("fridge", (4.4, 1.2, -4.2), (.9, 2.0, .8), C(.95, .95, .95, .2), 1, bevel=.05)
    box("stove", (2.2, .75, -4.95), (.8, .1, .7), C(.15, .15, .15, .3), 1)
    for k in range(2):box("chair", (2.6 + k * 1.2, .55, -2.2), (.5, .6, .5), C(.6, .4, .25, .6), 1)
    box("kitchen_table", (3.2, .8, -2.2), (2.0, .1, 1.0), C(.6, .4, .25, .5), 1)
    # A resident with a floating gem.
    p = group("resident", (0, .24, -.5))
    box("legs", (0, .45, 0), (.35, .9, .25), C(.2, .25, .45, .8), 1, parent=p)
    box("torso", (0, 1.15, 0), (.5, .6, .3), C(.95, .55, .2, .8), 1, bevel=.04, parent=p)
    sphere("head", (0, 1.7, 0), .25, C(.95, .78, .62, .7), parent=p)
    sphere("hair", (0, 1.85, -.03), .26, C(.3, .18, .1, .9), squash=(1, .6, 1), parent=p)
    gem = group("anim_spin_s20", (0, 2.6, -.5))
    cylinder("gem_top", (0, .25, 0), 0, .25, .5, C(.2, 1, .3, .1, emit=2.5), 1, sides=4, parent=gem)
    cylinder("gem_bottom", (0, -.25, 0), .25, 0, .5, C(.2, 1, .3, .1, emit=2.5), 1, sides=4, parent=gem)
    # Garden: picket fence, pool, mailbox, trees.
    for k in range(15):
        box("picket", (-7.5 + k * 1.07, .5, 7.6), (.12, 1.0, .08), C(.96, .96, .94, .6), 1)
    box("fence_rail", (0, .7, 7.62), (15.6, .08, .06), C(.96, .96, .94, .6), 1)
    box("pool_rim", (-4.5, .1, 4.5), (4.4, .2, 3.0), C(.9, .88, .84, .5), 1)
    box("pool", (-4.5, .16, 4.5), (4.0, .12, 2.6), C(.3, .7, .95, .05, emit=.4), 1)
    cylinder("mail_post", (4.5, .5, 6.8), .05, .05, 1.0, C(.4, .3, .2), 1)
    box("mailbox", (4.5, 1.05, 6.8), (.35, .3, .55), C(.2, .4, .8, .4, .5), 1, bevel=.05)
    for x, z in ((6.5, -6.5), (6.8, 3.5), (-6.8, -6.8)):tree((x, 0, z), 3.0)
    gable("roof", (0, 6.8, -1.5), 11, 2.6, 9, T("ch5w_sims_roof"), 2, rot=(0, math.pi / 2, 0)) if False else None


# ------------------------------------------------------------------ 6 a toy-brick city at night with a black car
def bricks():
    plate = C(.35, .37, .4, .35)

    def studs(x0, z0, nx, nz, y, m, parent=None, step=.8):
        for i in range(nx):
            for j in range(nz):
                cylinder("stud", (x0 + i * step, y + .08, z0 + j * step), .24, .24, .16, m, 1, sides=12, parent=parent)
    box("plate", (0, -.2, 0), (16, .4, 16), plate, 4)
    studs(-7.6, -7.6, 20, 20, 0, plate)
    cols = [(.8, .1, .1), (.95, .8, .1), (.2, .3, .7), (.15, .15, .17), (.9, .9, .88)]
    for k in range(5):
        h = 3.2 + k * 1.6
        x, z = -6 + k * 3, -5.5
        m = T("ch5w_lego_windows", (.95, .95, 1, 1), rough=.3)
        box("building", (x, h / 2, z), (2.4, h, 2.4), m, 2.4)
        for lvl in range(int(h / 1.6)):
            box("ledge", (x, (lvl + 1) * 1.6, z + 1.25), (2.5, .16, .12), C(*cols[k % 5], rough=.3), 1)
        studs(x - .8, z - .8, 3, 3, h, C(*cols[(k + 1) % 5], rough=.3))
        box("cap", (x, h + .01, z), (2.4, .02, 2.4), C(*cols[(k + 1) % 5], rough=.3), 1)
    car = group("anim_drive_s08", (0, .5, 2.5))
    black = C(.05, .05, .07, .25)
    box("chassis", (0, 0, 0), (1.6, .4, 3.6), black, 2, bevel=.03, parent=car)
    box("cockpit", (0, .4, -.4), (1.0, .4, 1.3), C(.1, .2, .3, .05), 1, parent=car)
    for x in (-.75, .75):
        box("fin", (x, .5, -1.5), (.12, .7, .7), black, 1, parent=car)
        box("nose", (x * .7, .1, 1.7), (.5, .25, .4), black, 1, parent=car)
    studs(-.4, -1.2, 2, 4, .2, black, parent=car)
    box("jet", (0, .1, -1.85), (.6, .3, .1), C(1, .5, .1, emit=5), 1, parent=car)
    wheels(car, (-.9, .9), (-1.1, 1.1), -.15, .35, .3)
    cylinder("searchlight_base", (5.5, .4, 4.5), .5, .6, .8, plate, 1)
    cylinder("searchlight", (5.5, 1.0, 4.5), .45, .45, .7, C(.3, .3, .32, .3, .7), 1, rot=(-.6, 0, 0))
    cylinder("beam", (6.5, 7.0, -1.0), 2.0, .3, 13.0, mat("search_beam", None, (1, .95, .6, 1), emit=.6), 1, rot=(-.42, 0, -.12), caps=False)
    for k in range(4):
        cylinder("lamp", (-6 + k * 4, 1.2, 1.0), .12, .12, 2.4, plate, 1)
        box("lamp_head", (-6 + k * 4, 2.5, 1.0), (.5, .3, .5), C(1, .9, .5, emit=3), 1)


# ------------------------------------------------------------------ 7 a jungle temple, a stone frog, a spiral of balls
def temple():
    stone = T("ch5w_zuma_stone")
    for k, (w, h) in enumerate(((16, .8), (13.5, .8), (11, .6))):
        cylinder("tier", (0, -.4 + k * .8 + h / 2 - .4, 0), w / 2 * .98, w / 2, h, stone, 3, sides=8)
    chain = group("anim_spin_s-01", (0, 1.25, 0))
    cols = [(.95, .15, .1), (1, .85, .1), (.15, .8, .25), (.15, .45, 1), (.75, .2, .9)]
    for k in range(52):
        t = k / 52
        a = t * math.pi * 3.6
        r = 5.0 - t * 3.3
        sphere("ball", (math.cos(a) * r, 0, math.sin(a) * r), .34, C(*cols[(k * 5 // 3) % 5], rough=.12), segments=12, rings=8, parent=chain)
    for k in range(60):
        t = k / 60
        a = t * math.pi * 3.6
        r = 5.0 - t * 3.3
        box("groove", (math.cos(a) * r, .82, math.sin(a) * r), (.75, .06, .6), C(.3, .3, .26, .9), 1, rot=(0, -a, 0))
    sphere("skull_pit", (math.cos(math.pi * 3.6) * 1.7, 1.0, math.sin(math.pi * 3.6) * 1.7), .6, C(1, .8, .2, .2, .8, emit=.6))
    frog = group("anim_spin_s03", (0, 1.0, 0))
    fm = T("ch5w_zuma_frog", rough=.4)
    sphere("frog_body", (0, .6, 0), 1.1, fm, squash=(1.0, .7, 1.2), parent=frog)
    for k in (-1, 1):
        sphere("frog_leg", (k * .9, .2, -.4), .45, fm, squash=(1, .6, 1.4), parent=frog)
        sphere("frog_eye", (k * .45, 1.25, .55), .3, C(1, .9, .3, .2), parent=frog)
        sphere("frog_pupil", (k * .45, 1.3, .8), .12, C(.05, .05, .05, .1), parent=frog)
    sphere("frog_ball", (0, .7, 1.35), .36, C(*cols[1], rough=.12), parent=frog)
    for k in range(8):
        a = k / 8 * TAU
        x, z = math.cos(a) * 7.2, math.sin(a) * 7.2
        box("idol", (x, 1.3, z), (.9, 2.4, .9), stone, 1.5, rot=(0, -a, 0))
        sphere("idol_head", (x, 2.8, z), .5, stone)
        if k % 2 == 0:
            f = group("anim_flicker_s10", (x, 3.4, z))
            sphere("torch", (0, 0, 0), .2, C(1, .6, .15, emit=6), squash=(1, 1.6, 1), parent=f)
    for k in range(10):
        a = k * .63 + .3
        tree((math.cos(a) * 8.6, -.2, math.sin(a) * 8.6), 2.6 + (k % 3) * .6, (.15, .45, .15))


# ------------------------------------------------------------------ 8 a grey occupied city, a tower, a tripod walker
def occupied():
    box("street", (0, -.3, 0), (16, .6, 16), T("ch5w_hl2_ground"), 2)
    panel = T("ch5w_hl2_panel")
    for k in range(6):
        side = -1 if k % 2 == 0 else 1
        z = -6 + (k // 2) * 4.2
        h = 6 + (k % 3) * 1.6
        box("block", (side * 5.6, h / 2, z), (4.2, h, 3.6), panel, 4, bevel=.04)
        box("roof_edge", (side * 5.6, h + .1, z), (4.4, .2, 3.8), C(.4, .4, .38, .8), 2)
        for j in range(3):box("balcony", (side * (5.6 - 2.15), 1.6 + j * 1.6, z - 1 + j * .8), (.3, .1, 1.0), C(.35, .35, .33, .8), 1)
    tower = T("ch5w_hl2_citadel", rough=.35)
    cylinder("tower", (0, 14, -10), 1.2, 3.0, 28, tower, 4, rot=(0, 0, .03), sides=6)
    cylinder("tower_top", (.4, 28.5, -10), 0, 1.2, 2.0, tower, 2, sides=6)
    for k in range(10):sphere("tower_light", (math.cos(k) * (2.6 - k * .14), 2 + k * 2.6, -10 + math.sin(k) * (2.6 - k * .14)), .14, C(.4, .8, 1, emit=6), segments=8, rings=5)
    walker = group("anim_stride_s07", (1.0, 0, -2))
    grey = C(.55, .58, .6, .5, .5)
    sphere("pod", (0, 6.2, 0), 1.0, grey, squash=(1.5, .6, 1.0), parent=walker)
    sphere("eye", (0, 6.1, .95), .2, C(.4, .8, 1, emit=4), parent=walker)
    cylinder("cannon", (0, 5.6, .9), .08, .1, 1.3, grey, 1, rot=(math.pi / 2, 0, 0), parent=walker)
    for k in range(3):
        a = k * TAU / 3 + .5
        knee = (math.cos(a) * 1.8, 6.8, math.sin(a) * 1.8)
        foot = (math.cos(a) * 3.0, 0, math.sin(a) * 3.0)
        beam_between("thigh", (0, 6.2, 0), knee, .16, grey, parent=walker)
        beam_between("shin", knee, foot, .12, grey, parent=walker)
    car = group("wreck", (-1.5, .35, 3.5))
    box("wreck_body", (0, .2, 0), (1.4, .6, 3.0), C(.45, .5, .45, .9), 2, rot=(0, .3, .15), parent=car)
    box("wreck_cabin", (0, .65, -.2), (1.2, .45, 1.4), C(.2, .22, .2, .6), 1, rot=(0, .3, .15), parent=car)
    for k in range(4):box("barricade", (2.0 + k * .9, .45, 6.0 - k * .3), (.8, .9, .25), C(.3, .32, .3, .7, .5), 1, rot=(0, .2 * k, 0))
    cylinder("lamp", (2.5, 2.2, -3), .06, .08, 4.4, C(.3, .3, .3, .5, .6), 1)
    box("lamp_head", (2.1, 4.35, -3), (.8, .12, .3), C(.6, .8, 1, emit=2), 1)


# ------------------------------------------------------------------ 9 a desert war base
def desert():
    sand = T("ch5w_cnc_sand")
    box("sand", (0, -.3, 0), (16, .6, 16), sand, 5)
    for k in range(5):sphere("dune", (-7 + k * 3.8, -.9, -6.8 + (k % 2) * 1.5), 2.6, sand, squash=(1.5, .5, 1))
    conc = T("ch5w_cnc_concrete")
    hq = group("hq", (-3.5, 0, -3.5))
    box("hq_base", (0, 1.3, 0), (5, 2.6, 3.8), conc, 2, bevel=.06, parent=hq)
    box("hq_top", (0, 3.0, 0), (3.2, 1.0, 2.6), conc, 2, bevel=.05, parent=hq)
    box("hq_door", (0, .9, 1.92), (1.8, 1.6, .06), C(.12, .12, .1), 1, parent=hq)
    box("hq_stripe", (0, 2.3, 1.92), (5.0, .2, .04), C(.85, .7, .1, .5), 1, parent=hq)
    dish = group("anim_spin_s05", (-1.2, 3.8, 0), parent=hq)
    sphere("dish", (0, .2, 0), .8, C(.82, .82, .8, .4, .3), squash=(1, .35, 1), parent=dish)
    cylinder("dish_mast", (0, -.2, 0), .06, .06, .6, C(.5, .5, .5, .4, .6), 1, parent=dish)
    cylinder("radio_mast", (1.3, 5.0, .5), .04, .06, 3.0, C(.5, .5, .5, .4, .6), 1, parent=hq)
    camo = T("ch5w_cnc_camo", rough=.7)
    for k in range(3):
        tank = group("tank", (1.0 + k * 2.4, .35, 1.0 + (k % 2) * 2.0))
        box("hull", (0, .05, 0), (1.4, .45, 2.2), camo, 1, bevel=.06, parent=tank)
        for x in (-.75, .75):box("track", (x, -.1, 0), (.35, .45, 2.3), C(.12, .12, .1, .9), 1, bevel=.08, parent=tank)
        turret = group("turret", (0, .45, -.1), parent=tank)
        sphere("turret_dome", (0, 0, 0), .5, camo, squash=(1, .55, 1.2), parent=turret)
        cylinder("barrel", (0, .05, 1.0), .07, .08, 1.5, camo, 1, rot=(math.pi / 2, 0, 0), parent=turret)
    heli = group("anim_hover_s07", (2.0, 5.0, -2.5))
    hm = C(.25, .28, .22, .5, .2)
    sphere("heli_body", (0, 0, 0), .7, hm, squash=(.75, .7, 1.6), parent=heli)
    sphere("heli_glass", (0, .15, .7), .45, C(.1, .2, .25, .05, .5), squash=(.9, .7, 1.0), parent=heli)
    cylinder("heli_tail", (0, .15, -1.7), .08, .2, 2.0, hm, 1, rot=(math.pi / 2, 0, 0), parent=heli)
    for x in (-.5, .5):box("skid", (x, -.7, 0), (.06, .06, 1.6), C(.2, .2, .2, .5, .5), 1, parent=heli)
    rotor = group("anim_spin_s220", (0, .7, 0), parent=heli)
    box("blade_a", (0, 0, 0), (4.2, .03, .18), C(.1, .1, .1, .6), 1, parent=rotor)
    box("blade_b", (0, 0, 0), (.18, .03, 4.2), C(.1, .1, .1, .6), 1, parent=rotor)
    lau = group("launcher", (5.0, 0, -5.0))
    box("truck", (0, .6, 0), (1.5, .9, 3.6), camo, 1, bevel=.05, parent=lau)
    wheels(lau, (-.8, .8), (-1.2, 0, 1.2), .3, .32)
    cylinder("missile", (0, 1.8, -.2), .25, .3, 3.0, C(.85, .85, .8, .4), 2, rot=(-1.0, 0, 0), parent=lau)
    cylinder("warhead", (0, 2.65, -1.4), 0, .25, .6, C(.8, .15, .1, .4), 1, rot=(-1.0, 0, 0), parent=lau)
    for k in range(10):
        a = k * .5
        box("sandbag", (-6.5 + math.cos(a) * 1.4, .25 + (k // 5) * .3, 4.5 + math.sin(a) * 1.4), (.7, .3, .4), C(.7, .6, .42, .9), 1, bevel=.1, rot=(0, -a, 0))
    cylinder("flag_pole", (-6.5, 2.2, 4.5), .04, .04, 4.4, C(.7, .7, .7, .3, .8), 1)
    box("flag", (-5.8, 4.0, 4.5), (1.4, .8, .03), C(.15, .3, .7, .7), 1)


# ------------------------------------------------------------------ 10 a grand-strategy map table
def strategy():
    wood = T("ch5w_eu4_wood")
    box("table_top", (0, 0, 0), (16, .6, 9.5), wood, 3, bevel=.1)
    box("table_rim", (0, .35, 0), (16.4, .1, 9.9), C(.35, .22, .12, .5), 2, bevel=.04)
    for x in (-7.3, 7.3):
        for z in (-4.0, 4.0):cylinder("leg", (x, -2.8, z), .35, .28, 5.0, wood, 2, sides=10)
    quad("map", (0, .32, 0), (15, 8.6), mat("map", "ch5w_eu4_map", rough=.9), rot=(-math.pi / 2, 0, 0))
    cols = [(.8, .2, .18), (.22, .35, .75), (.9, .78, .3), (.35, .6, .28), (.6, .3, .7)]
    for k in range(10):
        pc = group("piece", (-6 + (k * 4.3) % 12, .32, -3 + (k * 2.7) % 6))
        c = cols[k % 5]
        cylinder("piece_base", (0, .08, 0), .35, .4, .16, C(.75, .6, .28, .3, .8), 1, parent=pc)
        box("piece_body", (0, .45, 0), (.26, .6, .2), C(*c, rough=.5), 1, bevel=.03, parent=pc)
        sphere("piece_head", (0, .85, 0), .14, C(.95, .8, .65, .6), parent=pc)
        cylinder("pole", (.15, .9, 0), .02, .02, 1.1, C(.4, .3, .2, .7), 1, parent=pc)
        box("banner", (.4, 1.25, 0), (.5, .32, .02), C(*c, rough=.6), 1, parent=pc)
    for k in range(3):
        sh = group("anim_bob_s08", (-2 + k * 3.5, .4, 2.8 - k * 1.3))
        box("hull", (0, .05, 0), (.4, .25, 1.1), C(.45, .3, .18, .7), 1, bevel=.06, parent=sh)
        cylinder("mast", (0, .55, 0), .03, .03, 1.0, C(.4, .3, .2, .7), 1, parent=sh)
        box("sail", (0, .6, .05), (.03, .55, .6), C(.95, .93, .85, .8), 1, parent=sh)
    for x in (-7.2, 7.2):
        cylinder("candle", (x, .7, -4.2), .15, .15, .8, C(.95, .9, .8, .7), 1)
        f = group("anim_flicker_s10", (x, 1.25, -4.2))
        sphere("flame", (0, 0, 0), .12, C(1, .7, .2, emit=6), squash=(1, 1.7, 1), parent=f)
    cylinder("compass", (5.8, .38, 3.5), .6, .6, .08, C(.75, .6, .28, .25, .9), 1, sides=24)
    box("needle", (5.8, .44, 3.5), (.06, .02, .9), C(.8, .15, .1, .4), 1, rot=(0, .6, 0))
    cylinder("scroll", (-6.0, .5, 3.6), .25, .25, 2.2, C(.9, .82, .62, .9), 1, rot=(0, 0, math.pi / 2))
    globe = group("anim_spin_s04", (6.6, 1.6, -3.4))
    sphere("globe", (0, 0, 0), .7, mat("globe", "ch5w_eu4_map", rough=.6), parent=globe)
    cylinder("globe_stand", (6.6, .7, -3.4), .3, .4, 1.0, wood, 1)


SCENES = [city, alien, arena, lambda: rpg(3), lambda: rpg(4), suburb, bricks, temple, occupied, desert, strategy]
only = [int(a) for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else range(len(SCENES))
L.reset()
for i in only:
    L.clear_scene()
    SCENES[i]()
    L.export(ROOT / ("assets/models/ch5_game_%d.glb" % i))
