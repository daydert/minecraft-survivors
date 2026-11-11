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


def sword_plane(imp, broken=False):
    """The vanilla iron sword in the right hand, in the arm's own space: the
    blade leaves the fist forward and up, as a held item does in the game."""
    tex = imp.tex("item/iron_sword")
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
    upper += four.jbox(tex, (-4, -8, -4), (8, 8, 8), (0, 0), (0, 0, 0), p("head"))
    upper += four.jbox(tex, (-4, -8, -4), (8, 8, 8), (32, 0), (0, 0, 0), p("head"), 0.5)
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
COUNTS = {"guard": 2, "windup": 3, "strike": 3, "clang": 2, "thrown": 3, "fall": 6, "lying": 2, "lying_talk": 2, "getup": 16, "spent": 2}
ARMED = ["guard", "windup", "strike", "clang"]


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


def atlas(imp, tex):
    columns, layout = [], {}
    for name in POSES:
        layout[name] = {"start": len(columns), "count": COUNTS[name]}
        columns += [(name, f) for f in frames(name)]
    w, h = FRAME
    sword = sword_plane(imp)
    out = Image.new("RGBA", (w * len(columns), h))
    for col, (name, pose) in enumerate(columns):
        mesh = figure(tex, pose, sword if name in ARMED else None)
        out.paste(bake(mesh, FRAME, four.SCALE, CENTER, yaw=YAW, elevation=20), (col * w, 0))
    return out, layout


def generate():
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    steve, layout = atlas(imp, imp.tex("entity/player/wide/steve"))
    imp.save(steve, "ch3_brawl_steve", ["entity/player/wide/steve", "item/iron_sword"])
    ender, _ = atlas(imp, corruption(imp, True))
    imp.save(ender, "ch3_brawl_ender", ["entity/player/wide/steve", "block/obsidian", "item/iron_sword"])
    data = {"sprites": ["ch3_brawl_steve", "ch3_brawl_ender"], "frame": list(FRAME), "anchor": list(CENTER), "poses": layout}
    (ROOT / "data/chapter_three_brawl.json").write_text(json.dumps(data, indent=2) + "\n")
    sheet = Image.new("RGBA", (FRAME[0] * 3 * 8, FRAME[1] * 3 * 2), (40, 40, 40, 255))
    picks = [("guard", 0), ("windup", 2), ("strike", 2), ("clang", 0), ("thrown", 2), ("fall", 3), ("lying", 0), ("getup", 6)]
    for i, (name, k) in enumerate(picks):
        c = layout[name]["start"] + k
        for r, im in enumerate([steve, ender]):
            sheet.alpha_composite(im.crop((c * FRAME[0], 0, (c + 1) * FRAME[0], FRAME[1])).resize((FRAME[0] * 3, FRAME[1] * 3), Image.NEAREST), (i * FRAME[0] * 3, r * FRAME[1] * 3))
    sheet.save(ROOT / "qa/chapter_three_brawl_poses.png")
    print("CH3_BRAWL", sum(v["count"] for v in layout.values()), "frames")


if __name__ == "__main__":
    generate()
