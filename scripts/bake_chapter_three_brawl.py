"""Bake the last exchange of chapter III: Steve and Ender Steve with swords,
the clash that breaks both, the fall onto the back, lying there, and getting
up again. Same posed player model as the chapter IV finale (rig, scale,
projection), seen in clean profile; the iron sword is the vanilla item texture
on a plane in the hand. Writes assets/sprites/ch3_brawl_*.png and
data/chapter_three_brawl.json.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

from import_minecraft_assets import ROOT, Importer, bake, box, find_client
from bake_minecraft_characters import transform
from end_character_mesh import corruption
import bake_chapter_four_finale as four

FRAME = (56, 56)
CENTER = (28, 50)
YAW = -80


# Steve's weapon in the last exchange: whatever he used most (end_world.top_held_weapon).
WEAPONS = {"sword": "item/iron_sword", "axe": "item/iron_axe", "hoe": "item/iron_hoe", "spear": "item/iron_spear",
           "mace": "item/mace", "knockback_stick": "item/stick", "bow": "item/bow", "crossbow": "item/crossbow_standby",
           "fishing": "item/fishing_rod", "shield": "shield"}


def item_texture(imp, source):
    if source == "ender_blade":
        # His blade: the netherite sword re-inked violet so it reads against his dark body.
        base = imp.tex("item/netherite_sword").copy()
        for y in range(16):
            for x in range(16):
                r, g, b, a = base.getpixel((x, y))
                if not a:
                    continue
                v = (r + g + b) / 765
                base.putpixel((x, y), (int(70 + 175 * v ** 1.1), int(30 + 140 * v ** 1.3), int(110 + 145 * v), a))
        return base
    if source != "shield":
        return imp.tex(source)
    # The shield has no item sprite: its front face from the entity texture, on the same 16 px plane.
    face = imp.tex("entity/shield_base_nopattern").crop((1, 1, 13, 23)).resize((8, 14), Image.NEAREST)
    out = Image.new("RGBA", (16, 16))
    out.paste(face, (4, 1))
    return out


def sword_plane(imp, broken=False, source="item/iron_sword"):
    """A vanilla item in the right hand, in the arm's own space: the
    blade leaves the fist forward and up, as a held item does in the game."""
    tex = item_texture(imp, source)
    s = 0.85
    keep = 16 if not broken else 8
    quads = []
    # Texture handle corner (0,16) sits in the fist, the tip (16,0) points away.
    verts = []
    for (u, v) in [(0, 0), (keep, 0), (keep, keep), (0, keep)]:
        tu, tv = u, 16 - keep + v
        z = -(tu - 3) * s
        y = -10 + (16 - tv - 3) * s
        verts.append([-1.0, y, z])
    quads.append((np.array(verts, dtype=float), tex, (0, 16 - keep, keep, keep), 1))
    return quads


def figure(tex, pose, sword=None):
    """chapter IV's figure() with an item plane bound to the right arm."""
    p = lambda k: pose.get(k, (0, 0, 0))
    upper = []
    # The face looks where the arms reach (the head box alone was baked facing backwards).
    hx, hy, hz = p("head")
    head = (-hx, hy + math.pi, -hz)
    # Lying on the back (the whole body tipped over): the face looks up at the sky.
    if p("whole")[0] > 1.0:
        head = (hx, hy, hz)
    upper += four.jbox(tex, (-4, -8, -4), (8, 8, 8), (0, 0), (0, 0, 0), head)
    upper += four.jbox(tex, (-4, -8, -4), (8, 8, 8), (32, 0), (0, 0, 0), head, 0.5)
    upper += four.jbox(tex, (-4, 0, -2), (8, 12, 4), (16, 16), (0, 0, 0))
    upper += four.jbox(tex, (-4, 0, -2), (8, 12, 4), (16, 32), (0, 0, 0), inflate=0.25)
    upper += four.jbox(tex, (-3, -2, -2), (4, 12, 4), (40, 16), (-5, 2, 0), p("ra"))
    upper += four.jbox(tex, (-3, -2, -2), (4, 12, 4), (40, 32), (-5, 2, 0), p("ra"), 0.25)
    if sword:
        rx, ry, rz = p("ra")
        upper += transform(sword, (-rx, ry, -rz), offset=(-5, 24 - 2, 0))
    upper += four.jbox(tex, (-1, -2, -2), (4, 12, 4), (32, 48), (5, 2, 0), p("la"))
    upper += four.jbox(tex, (-1, -2, -2), (4, 12, 4), (48, 48), (5, 2, 0), p("la"), 0.25)
    upper = transform(upper, p("lean"), pivot=(0, 12, 0))
    lower = []
    lower += four.jbox(tex, (-2, 0, -2), (4, 12, 4), (0, 16), (-1.9, 12, 0), p("rl"))
    lower += four.jbox(tex, (-2, 0, -2), (4, 12, 4), (0, 32), (-1.9, 12, 0), p("rl"), 0.25)
    lower += four.jbox(tex, (-2, 0, -2), (4, 12, 4), (16, 48), (1.9, 12, 0), p("ll"))
    lower += four.jbox(tex, (-2, 0, -2), (4, 12, 4), (0, 48), (1.9, 12, 0), p("ll"), 0.25)
    return transform(upper + lower, p("whole"), pivot=pose.get("whole_pivot", (0, 0, 0)), offset=pose.get("root", (0, 0, 0)))


LYING = {"whole": (1.52, 0, 0), "root": (0, 0, -13), "ra": (0.2, 0, 0.7), "la": (0.2, 0, -0.7), "head": (-0.1, 0, 0), "rl": (0, 0, 0.1), "ll": (0, 0, -0.1)}
POSES = {
    "guard": [{"ra": (-0.9, 0, 0.05), "la": (-0.5, 0, -0.1), "lean": (-0.08, 0, 0), "rl": (-0.35, 0, 0), "ll": (0.3, 0, 0), "head": (0.05, 0, 0)},
              {"ra": (-0.95, 0, 0.05), "la": (-0.5, 0, -0.1), "lean": (-0.1, 0, 0), "rl": (-0.35, 0, 0), "ll": (0.3, 0, 0), "head": (0.05, 0, 0), "root": (0, -0.5, 0)}],
    "windup": [{"ra": (-1.6, 0, 0.1), "la": (-0.6, 0, -0.1), "lean": (0.02, 0, 0), "rl": (-0.3, 0, 0), "ll": (0.3, 0, 0)},
               {"ra": (-2.9, 0, 0.15), "la": (-0.3, 0, -0.2), "lean": (0.12, 0.15, 0), "rl": (-0.2, 0, 0), "ll": (0.35, 0, 0), "head": (-0.12, 0, 0)}],
    "strike": [{"ra": (-1.9, 0, 0.05), "la": (0.1, 0, -0.3), "lean": (-0.2, -0.1, 0), "rl": (-0.6, 0, 0), "ll": (0.5, 0, 0), "root": (0, -0.8, 0)},
               {"ra": (-1.25, 0, 0.0), "la": (0.35, 0, -0.35), "lean": (-0.35, -0.2, 0), "rl": (-0.75, 0, 0), "ll": (0.6, 0, 0), "root": (0, -1.4, 0), "head": (0.1, 0, 0)}],
    "clang": [{"ra": (-1.45, 0, 0.0), "la": (-0.9, 0, -0.1), "lean": (-0.28, 0, 0), "rl": (-0.7, 0, 0), "ll": (0.55, 0, 0), "root": (0, -1.2, 0), "head": (0.1, 0, 0)},
              {"ra": (-1.5, 0, 0.02), "la": (-0.95, 0, -0.1), "lean": (-0.32, 0, 0.02), "rl": (-0.75, 0, 0), "ll": (0.6, 0, 0), "root": (0, -1.5, 0), "head": (0.12, 0, 0)}],
    "thrown": [{"lean": (0.35, 0, 0), "ra": (-0.4, 0, 0.9), "la": (-0.3, 0, -0.9), "head": (-0.4, 0, 0), "rl": (-0.4, 0, 0), "ll": (0.25, 0, 0), "root": (0, 0.5, 0)},
               {"lean": (0.55, 0, 0), "ra": (-0.2, 0, 1.2), "la": (-0.1, 0, -1.2), "head": (-0.55, 0, 0), "rl": (-0.7, 0, 0), "ll": (-0.2, 0, 0), "root": (0, 2.5, 0)}],
    "fall": [{"whole": (0.45, 0, 0), "ra": (-0.8, 0, 1.1), "la": (-0.8, 0, -1.1), "head": (-0.5, 0, 0), "rl": (-0.6, 0, 0), "ll": (-0.3, 0, 0), "root": (0, 3, -3)},
             {"whole": (1.05, 0, 0), "ra": (-0.9, 0, 1.0), "la": (-0.9, 0, -1.0), "head": (-0.35, 0, 0), "rl": (-0.7, 0, 0), "ll": (-0.5, 0, 0), "root": (0, 1, -8)},
             {"whole": (1.6, 0, 0), "root": (0, 0, -13), "ra": (0.1, 0, 0.9), "la": (0.1, 0, -0.9), "head": (0.15, 0, 0), "rl": (-0.25, 0, 0.1), "ll": (-0.1, 0, -0.1)},
             dict(LYING)],
    "lying": [dict(LYING), dict(LYING, ra=(0.25, 0, 0.75), la=(0.15, 0, -0.65), head=(-0.15, 0, 0), root=(0, 0.3, -13))],
    "lying_talk": [dict(LYING, head=(-0.1, 0.45, 0)), dict(LYING, head=(-0.15, 0.5, 0), ra=(0.25, 0, 0.75), root=(0, 0.3, -13))],
    "getup": [dict(LYING),
              {"whole": (1.15, 0, 0), "root": (0, -1, -11), "ra": (0.9, 0, 0.35), "la": (0.9, 0, -0.35), "head": (-0.25, 0, 0), "rl": (0, 0, 0.1), "ll": (0, 0, -0.1)},
              {"whole": (0.55, 0, 0), "root": (0, -6, -6), "ra": (0.7, 0, 0.3), "la": (0.7, 0, -0.3), "head": (0.05, 0, 0), "rl": (-0.9, 0, 0.1), "ll": (-0.9, 0, -0.1)},
              {"root": (0, -10, 0), "rl": (-1.5, 0, 0.1), "ll": (-1.5, 0, -0.1), "lean": (0.25, 0, 0), "ra": (0.4, 0, 0.25), "la": (0.4, 0, -0.25), "head": (0.35, 0, 0)},
              {"root": (0, -8, 0), "rl": (-1.55, 0, 0), "ll": (0.4, 0, 0), "lean": (0.45, 0, 0), "ra": (-0.2, 0, 0.2), "la": (0.2, 0, -0.2), "head": (0.4, 0, 0)},
              {"root": (0, -6, 0), "rl": (-1.45, 0, 0), "ll": (0.95, 0, 0), "lean": (0.35, 0, 0), "head": (0.4, 0, 0), "ra": (0.1, 0, 0.1), "la": (-0.7, 0, -0.1)},
              {"root": (0, -2.5, 0), "rl": (-0.6, 0, 0), "ll": (0.4, 0, 0), "lean": (0.3, 0, 0), "head": (0.3, 0, 0), "ra": (0.1, 0, 0.1), "la": (-0.5, 0, -0.1)},
              {"lean": (0.35, 0, 0), "head": (0.45, 0, 0), "ra": (0.2, 0, 0.12), "la": (0.25, 0, -0.12), "rl": (-0.15, 0, 0.05), "ll": (0.15, 0, -0.05), "root": (0, -1, 0)}],
    "spent": [{"lean": (0.35, 0, 0), "head": (0.45, 0, 0), "ra": (0.2, 0, 0.12), "la": (0.25, 0, -0.12), "rl": (-0.15, 0, 0.05), "ll": (0.15, 0, -0.05), "root": (0, -1, 0)},
              {"lean": (0.42, 0, 0.02), "head": (0.5, 0, 0), "ra": (0.22, 0, 0.1), "la": (0.28, 0, -0.1), "rl": (-0.15, 0, 0.05), "ll": (0.15, 0, -0.05), "root": (0, -1.4, 0)}],
}
# The finale after the clash (2026-11-14): breathing stance, the race for the last
# iron sword, kneeling, lying in wait, the raised sword that is lowered, the bad end.
STAND = {"ra": (-0.2, 0, 0.1), "la": (-0.1, 0, -0.1)}
KNEEL = {"root": (0, -7, 0), "rl": (-1.35, 0, 0.05), "ll": (1.15, 0, -0.05), "lean": (0.3, 0, 0), "head": (0.45, 0, 0), "ra": (0.15, 0, 0.15), "la": (0.15, 0, -0.15)}
POSES.update({
    "stance": [{"ra": (-0.75, 0, 0.1), "la": (-0.35, 0, -0.15), "lean": (0.12, 0, 0), "rl": (-0.4, 0, 0), "ll": (0.35, 0, 0), "head": (0.1, 0, 0), "root": (0, -1, 0)},
               {"ra": (-0.7, 0, 0.1), "la": (-0.3, 0, -0.15), "lean": (0.18, 0, 0), "rl": (-0.4, 0, 0), "ll": (0.35, 0, 0), "head": (0.16, 0, 0), "root": (0, -1.6, 0)}],
    "run": [{"lean": (0.32, 0, 0), "ra": (0.9, 0, 0.1), "la": (-1.1, 0, -0.1), "rl": (-1.0, 0, 0), "ll": (0.8, 0, 0), "head": (-0.15, 0, 0), "root": (0, -1, 0)},
            {"lean": (0.32, 0, 0), "ra": (0.1, 0, 0.1), "la": (-0.2, 0, -0.1), "rl": (-0.1, 0, 0), "ll": (0.1, 0, 0), "head": (-0.15, 0, 0), "root": (0, 0.5, 0)},
            {"lean": (0.32, 0, 0), "ra": (-1.1, 0, 0.1), "la": (0.9, 0, -0.1), "rl": (0.8, 0, 0), "ll": (-1.0, 0, 0), "head": (-0.15, 0, 0), "root": (0, -1, 0)},
            {"lean": (0.32, 0, 0), "ra": (-0.2, 0, 0.1), "la": (0.1, 0, -0.1), "rl": (0.1, 0, 0), "ll": (-0.1, 0, 0), "head": (-0.15, 0, 0), "root": (0, 0.5, 0)},
            {"lean": (0.32, 0, 0), "ra": (0.9, 0, 0.1), "la": (-1.1, 0, -0.1), "rl": (-1.0, 0, 0), "ll": (0.8, 0, 0), "head": (-0.15, 0, 0), "root": (0, -1, 0)}],
    "grab": [{"lean": (0.35, 0, 0), "ra": (-0.5, 0, 0.1), "la": (-0.3, 0, -0.1), "rl": (-0.7, 0, 0), "ll": (0.5, 0, 0), "root": (0, -2, 0), "head": (0.25, 0, 0)},
             {"lean": (0.55, 0, 0), "ra": (-0.4, 0, 0.05), "la": (0.2, 0, -0.2), "rl": (-1.1, 0, 0), "ll": (0.6, 0, 0), "root": (0, -4, 0), "head": (0.4, 0, 0)},
             {"lean": (0.6, 0, 0), "ra": (-0.2, 0, 0.05), "la": (0.3, 0, -0.2), "rl": (-1.2, 0, 0), "ll": (0.65, 0, 0), "root": (0, -4.5, 0), "head": (0.45, 0, 0)}],
    "hold": [{"ra": (-1.2, 0, 0.1), "la": (-0.4, 0, -0.15), "lean": (0.05, 0, 0), "rl": (-0.3, 0, 0), "ll": (0.3, 0, 0), "head": (0.05, 0, 0)},
             {"ra": (-1.25, 0, 0.1), "la": (-0.4, 0, -0.15), "lean": (0.08, 0, 0), "rl": (-0.3, 0, 0), "ll": (0.3, 0, 0), "head": (0.08, 0, 0), "root": (0, -0.5, 0)}],
    "kneel": [dict(KNEEL), dict(KNEEL, head=(0.55, 0, 0), root=(0, -7.4, 0))],
    "lie_wait": [dict(LYING, ra=(0.1, 0, 1.3), la=(0.1, 0, -1.3), head=(0.05, 0, 0)), dict(LYING, ra=(0.1, 0, 1.35), la=(0.1, 0, -1.35), head=(0.0, 0, 0), root=(0, 0.3, -13))],
    "raise_over": [{"ra": (-2.9, 0, 0.1), "la": (-2.8, 0, -0.1), "lean": (-0.12, 0, 0), "rl": (-0.35, 0, 0), "ll": (0.35, 0, 0), "head": (0.25, 0, 0)},
                   {"ra": (-3.0, 0, 0.1), "la": (-2.9, 0, -0.1), "lean": (-0.16, 0, 0), "rl": (-0.35, 0, 0), "ll": (0.35, 0, 0), "head": (0.3, 0, 0), "root": (0, -0.4, 0)}],
    "lower": [{"ra": (-2.9, 0, 0.1), "la": (-2.8, 0, -0.1), "lean": (-0.12, 0, 0), "rl": (-0.35, 0, 0), "ll": (0.35, 0, 0), "head": (0.25, 0, 0)},
              {"ra": (-1.3, 0, 0.15), "la": (-0.8, 0, -0.1), "lean": (0.1, 0, 0), "rl": (-0.2, 0, 0), "ll": (0.2, 0, 0), "head": (0.4, 0, 0)},
              {"ra": (-0.15, 0, 0.12), "la": (0.0, 0, -0.1), "lean": (0.15, 0, 0), "rl": (-0.05, 0, 0), "ll": (0.05, 0, 0), "head": (0.45, 0, 0)}],
    "bad_strike": [{"ra": (-2.9, 0, 0.1), "la": (-2.8, 0, -0.1), "lean": (-0.15, 0, 0), "rl": (-0.4, 0, 0), "ll": (0.4, 0, 0), "head": (0.3, 0, 0)},
                   {"ra": (-3.1, 0, 0.1), "la": (-3.0, 0, -0.1), "lean": (-0.25, 0, 0), "rl": (-0.4, 0, 0), "ll": (0.4, 0, 0), "head": (0.35, 0, 0)},
                   {"ra": (-0.9, 0, 0.05), "la": (-0.7, 0, -0.1), "lean": (0.55, 0, 0), "rl": (-0.7, 0, 0), "ll": (0.6, 0, 0), "head": (0.5, 0, 0), "root": (0, -2, 0)},
                   {"ra": (-0.6, 0, 0.05), "la": (-0.5, 0, -0.1), "lean": (0.6, 0, 0), "rl": (-0.75, 0, 0), "ll": (0.6, 0, 0), "head": (0.55, 0, 0), "root": (0, -2.4, 0)}],
    # The talk by the portal: standing at ease, a speaker's gesture, his hands at his head
    # when his maker starts erasing him.
    "idle": [{"ra": (-0.08, 0, 0.08), "la": (0.06, 0, -0.08), "head": (0.05, 0, 0)},
             {"ra": (-0.1, 0, 0.09), "la": (0.08, 0, -0.09), "head": (0.08, 0, 0), "root": (0, -0.4, 0)}],
    "gesture": [{"ra": (-0.75, 0.2, 0.2), "la": (0.05, 0, -0.08), "head": (-0.05, 0, 0), "lean": (0.05, 0, 0)},
                {"ra": (-0.95, 0.25, 0.25), "la": (0.05, 0, -0.08), "head": (-0.08, 0, 0), "lean": (0.08, 0, 0), "root": (0, -0.3, 0)}],
    "clutch": [{"ra": (-2.5, 0, 0.55), "la": (-2.5, 0, -0.55), "head": (0.35, 0, 0), "lean": (0.3, 0, 0), "rl": (-0.2, 0, 0), "ll": (0.25, 0, 0), "root": (0, -1, 0)},
               {"ra": (-2.6, 0, 0.6), "la": (-2.4, 0, -0.5), "head": (0.45, 0.1, 0), "lean": (0.38, 0, 0.05), "rl": (-0.25, 0, 0), "ll": (0.3, 0, 0), "root": (0, -1.6, 0)}],
})
COUNTS = {"guard": 2, "windup": 3, "strike": 3, "clang": 2, "thrown": 3, "fall": 6, "lying": 2, "lying_talk": 2, "getup": 16, "spent": 2,
          "stance": 2, "run": 8, "grab": 4, "hold": 2, "kneel": 2, "lie_wait": 2, "raise_over": 2, "lower": 6, "bad_strike": 4, "idle": 2, "gesture": 2, "clutch": 2}
# The clash weapon (his blade, Steve's own) and, after it, the last iron sword.
ARMED = ["guard", "windup", "strike", "clang", "stance"]
IRON = ["hold", "raise_over", "lower", "bad_strike"]


def frames(name):
    keys = POSES[name]
    n = COUNTS[name]
    if n <= len(keys):
        return keys[:n]
    out = []
    for i in range(n):
        t = i / (n - 1) * (len(keys) - 1)
        a = int(min(len(keys) - 2, t))
        out.append(four.mix(keys[a], keys[a + 1], four.ease(t - a)))
    return out


def atlas(imp, tex, blade="item/iron_sword"):
    columns, layout = [], {}
    for name in POSES:
        layout[name] = {"start": len(columns), "count": COUNTS[name]}
        columns += [(name, f) for f in frames(name)]
    w, h = FRAME
    weapon = sword_plane(imp, source=blade)
    iron = sword_plane(imp)
    out = Image.new("RGBA", (w * len(columns), h))
    for col, (name, pose) in enumerate(columns):
        mesh = figure(tex, pose, weapon if name in ARMED else iron if name in IRON else None)
        out.paste(bake(mesh, FRAME, four.SCALE, CENTER, yaw=YAW, elevation=20), (col * w, 0))
    return out, layout


def generate():
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    skin = imp.tex("entity/player/wide/steve")
    steve, layout = atlas(imp, skin)
    imp.save(steve, "ch3_brawl_steve", ["entity/player/wide/steve", "item/iron_sword"])
    sprites, weapons = ["ch3_brawl_steve", "ch3_brawl_ender"], {}
    for weapon, source in WEAPONS.items():
        name = "ch3_brawl_steve_" + weapon
        image, _ = atlas(imp, skin, source)
        imp.save(image, name, ["entity/player/wide/steve", "entity/shield_base_nopattern" if source == "shield" else source, "item/iron_sword"])
        sprites.append(name)
        weapons[weapon] = name
    # His own dark blade for the duel, not an iron sword.
    ender, _ = atlas(imp, corruption(imp, True), "ender_blade")
    imp.save(ender, "ch3_brawl_ender", ["entity/player/wide/steve", "block/obsidian", "item/netherite_sword", "item/iron_sword"])
    data = {"sprites": sprites, "weapons": weapons, "frame": list(FRAME), "anchor": list(CENTER), "poses": layout}
    (ROOT / "data/chapter_three_brawl.json").write_text(json.dumps(data, indent=2) + "\n")
    picks = [("guard", 0), ("stance", 0), ("strike", 2), ("clang", 0), ("thrown", 2), ("lying", 0), ("run", 0), ("run", 2),
             ("grab", 3), ("hold", 0), ("kneel", 0), ("lie_wait", 0), ("raise_over", 0), ("lower", 3), ("lower", 5), ("bad_strike", 3)]
    mace = Image.open(ROOT / "assets/sprites/ch3_brawl_steve_mace.png")
    sheet = Image.new("RGBA", (FRAME[0] * 3 * 8, FRAME[1] * 3 * 6), (40, 40, 40, 255))
    for i, (name, k) in enumerate(picks):
        c = layout[name]["start"] + k
        for r, im in enumerate([steve, ender, mace]):
            x, y = (i % 8) * FRAME[0] * 3, (r + 3 * (i // 8)) * FRAME[1] * 3
            sheet.alpha_composite(im.crop((c * FRAME[0], 0, (c + 1) * FRAME[0], FRAME[1])).resize((FRAME[0] * 3, FRAME[1] * 3), Image.NEAREST), (x, y))
    sheet.save(ROOT / "qa/chapter_three_brawl_poses.png")
    print("CH3_BRAWL", sum(v["count"] for v in layout.values()), "frames")


if __name__ == "__main__":
    generate()
