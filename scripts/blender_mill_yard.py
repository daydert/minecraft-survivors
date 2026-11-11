"""The world past the door: an original painterly mill yard laid out as a
symmetrical two-base arena (a team-shooter staple), not a copy of any map.

Layout (Godot units, x across, z along the arena):
- a concrete canal along x through the middle, water below, a walk-in
  culvert pipe in each canal wall right under the bridge;
- a covered bridge exactly in the centre, spanning the canal and running
  straight into each base's second floor;
- each base: a balcony above the bridge door, two ground doors to the yard,
  a tall tower with a lookout balcony, a conveyor, sheds and silos behind;
- sand yards, rails, chain-link with wire, poles, lamps, poplars, hills.
Run: blender --background --python scripts/blender_mill_yard.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_lib import ROOT, beam_between, box, cylinder, export, gable, mat, quad, reset, sphere

reset()
sand = mat("sand", "ch5w_tf2_ground")
cobble = mat("cobble", "ch5w_tf2_cobble")
conc = mat("concrete", "ch5w_tf2_concrete")
roof = mat("roof", "ch5w_tf2_roof", rough=.7)
grey = mat("bridge_wood", "ch5w_tf2_bridge")
water = mat("water", "ch5w_tf2_water", rough=.08)
steel = mat("steel", None, (.42, .41, .39, 1), rough=.5, metal=.6)
dark = mat("dark", None, (.05, .04, .035, 1), rough=1)
tunnel = mat("tunnel", None, (.16, .15, .13, 1), rough=1)
cream = mat("silo", None, (.93, .89, .78, 1), rough=.7)
white = mat("white_metal", "ch5w_tf2_white_metal", rough=.5, metal=.15)
window = mat("window", "ch5w_tf2_window")
fence = mat("fence", "ch5w_tf2_fence", alpha=True, rough=.5, metal=.5)
sign = lambda n: mat("sign_" + n, "ch5w_tf2_" + n, alpha=n in ("happy", "two"))
crate = mat("crate", "ch5w_eu4_wood")
poplar_w = mat("poplar_white", None, (.9, .9, .86, 1), rough=1)
poplar_g = mat("poplar_green", None, (.5, .6, .38, 1), rough=1)
hill = mat("hill", None, (.78, .64, .42, 1), rough=1)
mountain = mat("mountain", None, (.56, .62, .76, 1), rough=1)
TEAMS = {
    -1: {"wall": mat("red_siding", "ch5w_tf2_red_siding"), "wood": mat("red_wood", "ch5w_tf2_red_wood"), "cap": mat("cap_w", None, (.55, .25, .18, 1), rough=.6), "sign": "sign_red"},
    1: {"wall": mat("blu_concrete", "ch5w_tf2_blu_concrete"), "wood": mat("blu_wood", "ch5w_tf2_blu_wood"), "cap": mat("cap_e", None, (.35, .52, .52, 1), rough=.5), "sign": "sign_blu"},
}
CANAL = 3.6      # half width of the canal
WATER_Y = -3.0
BASE_Z = 15.0    # distance from the centre to each base front
BRIDGE_Y = 3.2   # bridge deck, level with the bases' second floor

def facade(name, s, zf, x0, x1, y0, y1, holes, material):
    """A front wall with real openings: holes are (cx, width, bottom, top)."""
    cuts = sorted(holes)
    xs = sorted({x0, x1} | {h[0] - h[1] / 2 for h in cuts} | {h[0] + h[1] / 2 for h in cuts})
    for i in range(len(xs) - 1):
        a, b = xs[i], xs[i + 1]
        cx = (a + b) / 2
        spans = [(y0, y1)]
        for h in cuts:
            if h[0] - h[1] / 2 <= cx <= h[0] + h[1] / 2:
                new = []
                for lo, hi in spans:
                    if h[3] <= lo or h[2] >= hi:new.append((lo, hi));continue
                    if h[2] > lo:new.append((lo, h[2]))
                    if h[3] < hi:new.append((h[3], hi))
                spans = new
        for lo, hi in spans:
            if hi - lo > .01 and b - a > .01:
                box(name, (cx, (lo + hi) / 2, zf + s * .25), (b - a, hi - lo, .5), material, 4)


# ------------------------------------------------------------------ ground, canal, culverts
for s in (-1, 1):
    facade("canal_wall%d" % s, s, s * CANAL - s * .25, -120, 120, -5.2, 0, [(0, 2.6, WATER_Y + .1, WATER_Y + 2.7)], conc)
    box("yard_top%d" % s, (0, -.3, s * (CANAL + 60)), (240, .6, 120), sand, 6)
    for x0, x1 in ((-120, -1.6), (1.6, 120)):
        box("yard_fill%d" % s, ((x0 + x1) / 2, -2.9, s * (CANAL + 60)), (x1 - x0, 4.6, 120), sand, 6)
    box("lip%d" % s, (0, .08, s * (CANAL + .5)), (240, .18, 1.0), conc, 4)
    box("cobbles%d" % s, (0, .01, s * (CANAL + 5.5)), (14, .03, 8), cobble, 7)
    # A walk-in culvert right under the bridge, leading into the base.
    z = s * (CANAL + .3)
    cylinder("culvert_ring%d" % s, (0, WATER_Y + 1.4, z), 1.55, 1.55, .7, conc, 2, rot=(math.pi / 2, 0, 0))
    cylinder("culvert_tube%d" % s, (0, WATER_Y + 1.4, s * (CANAL + 4.5)), 1.3, 1.3, 9, tunnel, 2, rot=(math.pi / 2, 0, 0), caps=False, sides=20)
    cylinder("culvert_end%d" % s, (0, WATER_Y + 1.4, s * (CANAL + 9)), 1.3, 1.3, .1, dark, 2, rot=(math.pi / 2, 0, 0))
    box("culvert_lamp%d" % s, (0, WATER_Y + 2.55, s * (CANAL + 5)), (.4, .08, .4), mat("lamp_glow", None, (1, .85, .6, 1), emit=4.0))
    box("culvert_floor%d" % s, (0, WATER_Y + .25, s * (CANAL + 4.5)), (2.0, .2, 9.4), conc, 2)
    for x in (-9.0, 9.0):
        cylinder("outlet%d" % s, (x, WATER_Y + 1.6, z), .6, .6, .7, conc, 2, rot=(math.pi / 2, 0, 0))
        cylinder("outlet_hole%d" % s, (x, WATER_Y + 1.6, z + s * .05), .45, .45, .75, dark, 2, rot=(math.pi / 2, 0, 0))
box("canal_floor", (0, WATER_Y - .8, 0), (240, .4, CANAL * 2), conc, 4)
box("water", (0, WATER_Y, 0), (240, .06, CANAL * 2), water, 6)

# ------------------------------------------------------------------ the bridge, dead centre, at yard level
half = CANAL + 1.8
box("deck", (0, .25, 0), (4.0, .3, half * 2), grey, 2.5)
for k in range(6):
    z = -half + .3 + k * (half * 2 - .6) / 5
    for x in (-1.9, 1.9):
        box("post", (x, 1.75, z), (.26, 3.0, .26), grey, 2)
        if abs(z) < CANAL:
            box("leg", (x, (WATER_Y - 1.0) / 2 + .1, z), (.32, abs(WATER_Y) + 1.2, .32), grey, 2)
for x in (-1.95, 1.95):
    side = 1 if x > 0 else -1
    box("rail_low", (x, .75, 0), (.14, .9, half * 2), grey, 2)
    box("rail_top", (x, 1.3, 0), (.2, .12, half * 2), grey, 2)
    box("beam_top", (x, 3.3, 0), (.24, .3, half * 2), grey, 2)
    box("bridge_roof", (side * 1.2, 3.9, 0), (2.7, .08, half * 2 + .6), roof, 3, rot=(0, 0, -side * .5))
for z in (-half - .1, half + .1):
    gable("bridge_gable", (0, 3.45, z), 4.0, 1.0, .12, grey, 2)
    box("bridge_tie", (0, 3.4, z), (4.2, .22, .2), grey, 2)
for z in (-CANAL + .4, CANAL - .4):
    beam_between("brace", (-1.9, WATER_Y, z), (-1.9, -.1, z * .4), .18, grey)
    beam_between("brace", (1.9, WATER_Y, z), (1.9, -.1, z * .4), .18, grey)
quad("mind", (0, 3.85, half + .2), (1.8, .45), sign("watch"))
quad("mind", (0, 3.85, -half - .2), (1.8, .45), sign("watch"), rot=(0, math.pi, 0))


# ------------------------------------------------------------------ a base
def base(s):
    t = TEAMS[s]
    zf = s * BASE_Z           # front face
    zc = s * (BASE_Z + 8)     # centre of the main block
    face = 0 if s > 0 else math.pi  # signs face the canal
    ry = (0, face, 0)
    out = lambda d: zf - s * d  # a point d in front of the face (towards the canal)
    box("found%d" % s, (0, .3, zc), (30.4, .6, 16.4), conc, 4)
    box("main%d" % s, (0, 6.2, s * (BASE_Z + 10)), (30, 10.4, 12), t["wall"], 4, bevel=.05)
    gable("roof%d" % s, (0, 11.4, zc), 16.6, 3.0, 30.8, roof, 3, rot=(0, math.pi / 2, 0), overhang=.4)
    # The front wall has real openings into a two-storey hall.
    holes = [(-9.5, 3.2, .6, 4.0), (9.5, 3.2, .6, 4.0), (0, 10, 6.6, 9.2)]
    facade("facade%d" % s, s, zf, -15, 15, .6, 11.4, holes, t["wall"])
    inner = mat("hall", "ch5w_tf2_red_wood" if s < 0 else "ch5w_tf2_blu_wood", (.62, .58, .55, 1))
    hz = s * (BASE_Z + 2.25)
    box("hall_floor%d" % s, (0, .65, hz), (29.6, .1, 3.5), conc, 3)
    box("hall_slab%d" % s, (0, 6.5, hz), (29.6, .3, 3.5), grey, 2.5)
    box("hall_ceiling%d" % s, (0, 11.2, hz), (29.6, .3, 3.5), inner, 3)
    for x in (-14.8, 14.8):box("hall_side%d" % s, (x, 6, hz), (.3, 11, 3.5), inner, 3)
    for x in (-4.5, 4.5):box("hall_wall%d" % s, (x, 3.5, hz), (.3, 5.8, 3.5), inner, 3)
    box("stairs%d" % s, (-12, 3.5, hz), (2.2, .3, 3.2), grey, 2, rot=(0, 0, .9))
    for x in (-9.5, 9.5):
        box("corridor%d" % s, (x, 2.3, s * (BASE_Z + 6.5)), (3.0, 3.4, 5), tunnel, 3)
        box("lamp_in%d" % s, (x, 3.9, hz), (.6, .1, .6), mat("lamp_glow", None, (1, .85, .6, 1), emit=4.0))
    box("lamp_in_up%d" % s, (0, 10.8, hz), (1.0, .1, .6), mat("lamp_glow", None, (1, .85, .6, 1), emit=4.0))
    for k in range(3):box("hall_crate%d" % s, (5.5 + k * 1.1, 1.15, hz - s * .6), (1, 1, 1), crate, 1, rot=(0, k * .3, 0))
    box("balcony_floor%d" % s, (0, 6.55, out(.8)), (10.4, .25, 1.6), grey, 2)
    for k in range(11):
        box("balcony_post%d" % s, (-5 + k, 7.15, out(1.55)), (.12, 1.1, .12), grey, 2)
    box("balcony_rail%d" % s, (0, 7.7, out(1.55)), (10.4, .12, .14), grey, 2)
    box("balcony_awning%d" % s, (0, 9.9, out(.9)), (11, .1, 1.8), roof, 2, rot=(-s * .3, 0, 0))
    for x in (-9.5, 9.5):
        box("ground_frame%d" % s, (x, 4.15, out(.2)), (3.8, .3, .5), grey, 2)
        box("ground_awning%d" % s, (x, 4.8, out(.8)), (4.2, .1, 1.6), roof, 2, rot=(-s * .3, 0, 0))
        box("ramp%d" % s, (x, .3, out(1.0)), (3.4, .2, 2.0), conc, 2, rot=(s * .25, 0, 0))
    quad("team_sign%d" % s, (-6.5, 5.6, out(.03)), (4.6, 1.7), mat(t["sign"], "ch5w_tf2_" + t["sign"]), rot=ry)
    for k in range(10):
        if 3 < k < 7:continue
        quad("win%d" % s, (-13.5 + k * 3, 6.2, out(.03)), (.9, .9), window, rot=ry)
    for x in (-12.5, 12.5):
        box("lamp_arm%d" % s, (x, 5.0, out(.5)), (.08, .08, 1.0), steel)
        cylinder("lamp_shade%d" % s, (x, 4.85, out(1.0)), .06, .38, .3, steel, 2)
    # The tower with a lookout balcony.
    tx, tz = 9.0, s * (BASE_Z + 3)
    box("tower%d" % s, (tx, 11, tz), (5, 22, 5), t["wood"], 3, bevel=.05)
    gable("tower_roof%d" % s, (tx, 22, tz), 5.0, 2.4, 5.0, roof, 2, overhang=.45)
    box("lookout_floor%d" % s, (tx, 15.0, tz - s * 3.2), (5.6, .25, 1.6), grey, 2)
    for k in range(6):
        box("lookout_post%d" % s, (tx - 2.6 + k * 1.04, 15.6, tz - s * 3.95), (.12, 1.1, .12), grey, 2)
    box("lookout_rail%d" % s, (tx, 16.15, tz - s * 3.95), (5.6, .12, .14), grey, 2)
    box("lookout_door%d" % s, (tx, 16.2, tz - s * 2.52), (1.6, 2.2, .06), dark)
    for k in range(2):
        beam_between("lookout_strut%d" % s, (tx - 2.4 + k * 4.8, 13.4, tz - s * 2.5), (tx - 2.4 + k * 4.8, 14.9, tz - s * 3.9), .16, grey)
    quad("tower_sign%d" % s, (tx, 11.5, tz - s * 2.53), (2.6, 2.6), sign("happy"), rot=ry)
    quad("tower_num%d" % s, (tx, 8.0, tz - s * 2.53), (1.0, 1.0), sign("two"), rot=ry)
    for y in (5.5, 19.5):
        box("slot%d" % s, (tx, y, tz - s * 2.51), (2.4, .28, .06), dark)
    beam_between("conveyor%d" % s, (tx + 2.2, 19.5, tz), (tx + 13, 9.5, tz + s * 4), 1.1, roof)
    beam_between("conveyor_b%d" % s, (tx + 2.2, 18.0, tz), (tx + 12, 8.5, tz + s * 4), .3, steel)
    box("conveyor_house%d" % s, (tx + 14, 4.8, tz + s * 4.5), (6, 9.6, 6), t["wood"], 3, bevel=.04)
    gable("conveyor_house_roof%d" % s, (tx + 14, 9.6, tz + s * 4.5), 6.4, 1.8, 6.6, roof, 2, overhang=.3)
    # Annex, silos, and a white shed on the far flank.
    box("annex%d" % s, (-20, 3.4, s * (BASE_Z + 5)), (9, 6.8, 10), t["wall"], 4, bevel=.04)
    box("annex_roof%d" % s, (-20, 7.2, s * (BASE_Z + 5)), (9.6, .2, 11), roof, 3, rot=(-s * .22, 0, 0))
    box("annex_door%d" % s, (-20, 1.5, out(-.02)), (2.6, 3, .1), dark)
    for k in range(4):
        sx = -12 + k * 4.6
        cylinder("silo%d" % s, (sx, 8, s * (BASE_Z + 21)), 2.2, 2.2, 16, cream, 4, sides=24)
        sphere("silo_cap%d" % s, (sx, 16, s * (BASE_Z + 21)), 2.2, t["cap"], squash=(1, .38, 1))
    box("grain%d" % s, (12, 9, s * (BASE_Z + 22)), (12, 18, 8), t["wood"], 3, bevel=.05)
    quad("grain_sign%d" % s, (12, 16, s * (BASE_Z + 18) - s * .02), (6, 1.5), sign("coldwell"), rot=ry)
    box("shed%d" % s, (-22, 3, s * (CANAL + 5)), (8, 6, 7), white, 3, bevel=.04)
    gable("shed_roof%d" % s, (-22, 6, s * (CANAL + 5)), 8.4, 1.6, 7.6, white, 3, overhang=.3)


base(-1)
base(1)

# ------------------------------------------------------------------ yard furniture (both sides)
for s in (-1, 1):
    zf = s * BASE_Z
    quad("fence%d" % s, (17, 1.6, s * 8.5), (10, 3.2), fence, rot=(0, math.pi / 2, 0), uv_repeat=(7, 2.2))
    for k in range(5):
        z = s * (CANAL + 1.5 + k * 2.4)
        cylinder("fence_post%d" % s, (17, 1.9, z), .07, .07, 3.8, steel, 1, sides=8)
        for c in range(3):
            cylinder("barb%d" % s, (17, 3.9, z + c * .7), .3, .3, .05, steel, 1, rot=(0, 0, math.pi / 2), sides=10, caps=False)
    for k, (x, z, size) in enumerate([(-6, 7, 1.0), (-5.8, 8.1, 1.0), (-6, 7.5, 1.0), (5, 6, .8)]):
        box("crate%d_%d" % (s, k), (x, size / 2 + (1.0 if k == 2 else 0.0), s * z), (size, size, size), crate, 1.0, rot=(0, k * .4, 0))
    for k in range(3):
        cylinder("barrel%d_%d" % (s, k), (-11 + k * .9, .55, s * 10.5), .4, .4, 1.1, mat("barrel", None, (.62, .2, .12, 1) if s < 0 else (.25, .35, .5, 1), rough=.6), 1)
    for lp in ((6.0, s * 6.0), (-14.0, s * 6.5)):
        cylinder("lamp_pole%d" % s, (lp[0], 2.6, lp[1]), .07, .09, 5.2, steel, 1, sides=8)
        beam_between("lamp_arm%d" % s, (lp[0], 5.15, lp[1]), (lp[0] - 1.1, 5.0, lp[1]), .07, steel)
        cylinder("lamp_head%d" % s, (lp[0] - 1.15, 4.9, lp[1]), .05, .34, .28, steel, 1)
# Rails running along the yard across the canal on their own trestle.
for z in range(-40, 41):
    if abs(z) <= CANAL + .5:continue
    box("sleeper", (22, .06, z), (2.0, .1, .26), grey, 2)
for x in (21.35, 22.65):
    box("rail", (x, .16, 0), (.1, .12, 80), steel)
box("trestle", (22, -.4, 0), (2.6, .5, CANAL * 2 + 1), grey, 2)
for z in (-2, 0, 2):cylinder("trestle_leg", (22, (WATER_Y - .6) / 2 - .4, z), .25, .25, abs(WATER_Y) + .2, grey, 2)
poles = [(-16, -24), (-15, -10), (-14, 6), (-13, 20), (16, 22), (17, 6), (18, -10), (19, -24)]
for k, (px, pz) in enumerate(poles):
    cylinder("pole%d" % k, (px, 5, pz), .14, .2, 10, grey, 2, sides=10)
    box("cross%d" % k, (px, 9.3, pz), (2.4, .16, .16), grey, 2)
for a, b in ((0, 1), (1, 2), (2, 3), (4, 5), (5, 6), (6, 7)):
    for side in (-1.0, 1.0):
        beam_between("wire", (poles[a][0] + side, 9.4, poles[a][1]), (poles[b][0] + side, 9.4, poles[b][1]), .035, dark)

# ------------------------------------------------------------------ horizon
for k in range(22):
    px = -80 + k * 8 + (k * 3.3) % 4
    pz = (-1 if k % 2 else 1) * (48 + (k * 7.1) % 18) if k % 3 else -55 - (k * 5.3) % 10
    tall = 5 + (k * 2.3) % 5
    sphere("poplar%d" % k, (px, tall + 1.5, pz), 1.3, poplar_w if k % 3 == 0 else poplar_g, squash=(1, tall / 1.3 * .55, 1))
for k in range(10):
    sphere("hill%d" % k, (-110 + k * 26, -7, (-1 if k % 2 else 1) * (95 + (k % 3) * 15)), 22, hill, squash=(1.7, .5, 1))
for k in range(8):
    sphere("mount%d" % k, (-160 + k * 48, -12, (-1 if k % 2 else 1) * 190), 40, mountain, squash=(1.5, .55, 1))

export(ROOT / "assets/models/ch5_mill_yard.glb")
