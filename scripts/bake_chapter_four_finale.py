"""Bake the chapter IV finale: Herobrine and Steve in every pose of the duel.

The vanilla player model (Steve skin) is posed by joint keyframes and projected
with the same orthographic camera as all actors. Herobrine is the Steve skin
with white eyes; four face variants (calm, smile, rage, dim) differ only in a
few mouth/eye texels so expression reads on screen. No image generation.
Writes assets/sprites/ch4_hb_*.png, ch4_fist_*.png and data/chapter_four_finale_assets.json.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from import_minecraft_assets import ROOT, Importer, bake, box, find_client
from bake_minecraft_characters import DIRECTIONS, transform

FRAME = (48, 56)
CENTER = (24, 50)
SCALE = 0.86

# ------------------------------------------------------------------ skins

def herobrine_skin(imp, face):
    tex = imp.tex("entity/player/wide/steve").copy()
    d = ImageDraw.Draw(tex)
    eye = (255, 255, 255, 255) if face != "dim" else (70, 70, 74, 255)
    d.rectangle((9, 12, 10, 12), fill=eye)
    d.rectangle((13, 12, 14, 12), fill=eye)
    mouth = (40, 6, 8, 255)
    if face == "smile":
        for x, y in [(10, 14), (11, 15), (12, 15), (13, 14)]:
            d.point((x, y), fill=mouth)
    elif face == "rage":
        for x, y in [(10, 15), (11, 14), (12, 14), (13, 15)]:
            d.point((x, y), fill=mouth)
        d.point((9, 11), fill=(60, 30, 20, 255)); d.point((14, 11), fill=(60, 30, 20, 255))
    elif face == "dim":
        d.rectangle((10, 15, 13, 15), fill=(70, 20, 22, 255))
    return tex


# ------------------------------------------------------------------ posed player model

def jbox(tex, origin, size, uv, pivot, angles=(0, 0, 0), inflate=0.0):
    x, y, z = origin
    w, h, d = size
    mesh = box(tex, (x, -y - h, z), size, uv)
    if inflate:
        center = np.array([x + w / 2, -y - h / 2, z + d / 2])
        scale = 1 + 2 * inflate / np.array(size, dtype=float)
        mesh = [(center + (v - center) * scale, t, r, s) for v, t, r, s in mesh]
    rx, ry, rz = angles
    return transform(mesh, (-rx, ry, -rz), offset=(pivot[0], 24 - pivot[1], pivot[2]))


def figure(tex, pose, headless=False, only_head=False):
    p = lambda k: pose.get(k, (0, 0, 0))
    upper = []
    if only_head:
        upper = jbox(tex, (-4, -8, -4), (8, 8, 8), (0, 0), (0, 0, 0), p("head"))
        upper = transform(upper, p("lean"), pivot=(0, 12, 0))
        return transform(upper, p("whole"), pivot=pose.get("whole_pivot", (0, 0, 0)), offset=pose.get("root", (0, 0, 0)))
    if not headless:
        upper += jbox(tex, (-4, -8, -4), (8, 8, 8), (0, 0), (0, 0, 0), p("head"))
        upper += jbox(tex, (-4, -8, -4), (8, 8, 8), (32, 0), (0, 0, 0), p("head"), 0.5)
    upper += jbox(tex, (-4, 0, -2), (8, 12, 4), (16, 16), (0, 0, 0))
    upper += jbox(tex, (-4, 0, -2), (8, 12, 4), (16, 32), (0, 0, 0), inflate=0.25)
    upper += jbox(tex, (-3, -2, -2), (4, 12, 4), (40, 16), (-5, 2, 0), p("ra"))
    upper += jbox(tex, (-3, -2, -2), (4, 12, 4), (40, 32), (-5, 2, 0), p("ra"), 0.25)
    upper += jbox(tex, (-1, -2, -2), (4, 12, 4), (32, 48), (5, 2, 0), p("la"))
    upper += jbox(tex, (-1, -2, -2), (4, 12, 4), (48, 48), (5, 2, 0), p("la"), 0.25)
    if headless:
        stump = Image.new("RGBA", (16, 16), (120, 10, 14, 255))
        faces = {f: (stump, (0, 0, 16, 16)) for f in ["north", "south", "east", "west", "up", "down"]}
        upper += box(stump, (-2.5, 24, -2.5), (5, 1.5, 5), faces=faces)
    lean = p("lean")
    upper = transform(upper, lean, pivot=(0, 12, 0))
    lower = []
    lower += jbox(tex, (-2, 0, -2), (4, 12, 4), (0, 16), (-1.9, 12, 0), p("rl"))
    lower += jbox(tex, (-2, 0, -2), (4, 12, 4), (0, 32), (-1.9, 12, 0), p("rl"), 0.25)
    lower += jbox(tex, (-2, 0, -2), (4, 12, 4), (16, 48), (1.9, 12, 0), p("ll"))
    lower += jbox(tex, (-2, 0, -2), (4, 12, 4), (0, 48), (1.9, 12, 0), p("ll"), 0.25)
    mesh = upper + lower
    return transform(mesh, p("whole"), pivot=pose.get("whole_pivot", (0, 0, 0)), offset=pose.get("root", (0, 0, 0)))


def mix(a, b, t):
    out = {}
    for key in set(a) | set(b):
        va, vb = a.get(key, (0, 0, 0)), b.get(key, (0, 0, 0))
        if key == "whole_pivot":
            out[key] = vb if t > 0.5 else va
            continue
        out[key] = tuple(x + (y - x) * t for x, y in zip(va, vb))
    return out


def ease(t):
    return t * t * (3 - 2 * t)


STAND = {}
POSES = {
    # Herobrine
    "idle": [STAND, {"head": (0.04, 0, 0), "ra": (0, 0, 0.05), "la": (0, 0, -0.05)}],
    "deflect": [{"ra": (-0.4, 0, 0.3)}, {"ra": (-1.6, 0.6, 1.2), "head": (0, -0.3, 0)}, {"ra": (-1.2, 0.9, 1.4), "lean": (0, -0.2, 0)}],
    "cast": [{"ra": (-0.6, 0, 0.3), "la": (-0.6, 0, -0.3)}, {"ra": (-2.4, 0, 0.5), "la": (-2.4, 0, -0.5), "head": (-0.25, 0, 0)}, {"ra": (-2.9, 0, 0.3), "la": (-2.9, 0, -0.3), "head": (-0.35, 0, 0)}],
    "invite": [{"ra": (0, 0, 0.9), "la": (0, 0, -0.9)}, {"ra": (-0.2, 0, 1.35), "la": (-0.2, 0, -1.35), "head": (0.1, 0, 0.18)}],
    "look_hand": [{"ra": (-1.0, 0.3, 0)}, {"ra": (-1.45, 0.5, 0.1), "head": (0.45, 0.2, 0)}],
    "kneel": [{"root": (0, -6, 0), "rl": (-1.45, 0, 0), "ll": (0.95, 0, 0), "lean": (0.25, 0, 0), "head": (0.35, 0, 0), "ra": (0.1, 0, 0.1), "la": (-0.6, 0, -0.1)},
              {"root": (0, -6, 0), "rl": (-1.45, 0, 0), "ll": (0.95, 0, 0), "lean": (0.4, 0, 0), "head": (0.55, 0, 0), "ra": (0.2, 0, 0.1), "la": (-0.8, 0, -0.1)}],
    "rise": [{"root": (0, -6, 0), "rl": (-1.45, 0, 0), "ll": (0.95, 0, 0), "lean": (0.3, 0, 0), "head": (0.4, 0, 0)}, {"root": (0, -2, 0), "rl": (-0.5, 0, 0), "ll": (0.3, 0, 0), "lean": (0.1, 0.25, 0.1), "head": (-0.1, 0.35, 0.2)}, {"lean": (0, -0.2, -0.08), "head": (-0.12, 0.25, -0.15)}],
    "float": [{"root": (0, 5, 0), "rl": (0.18, 0, 0.05), "ll": (0.12, 0, -0.05), "ra": (0, 0, 0.55), "la": (0, 0, -0.55), "head": (-0.3, 0, 0)}, {"root": (0, 7, 0), "rl": (0.25, 0, 0.05), "ll": (0.2, 0, -0.05), "ra": (-0.2, 0, 0.7), "la": (-0.2, 0, -0.7), "head": (-0.38, 0, 0)}],
    "slam": [{"ra": (-2.6, 0, 0.2), "la": (-2.6, 0, -0.2), "lean": (-0.2, 0, 0)}, {"ra": (-1.0, 0, 0.1), "la": (-1.0, 0, -0.1), "lean": (0.35, 0, 0)}, {"ra": (-0.4, 0, 0.2), "la": (-0.4, 0, -0.2), "lean": (0.45, 0, 0), "head": (0.2, 0, 0)}],
    "guard": [{"ra": (-1.35, -0.5, 0.2), "la": (-1.35, 0.5, -0.2), "head": (0.15, 0, 0), "lean": (0.1, 0, 0)}],
    "jab": [{"ra": (-0.6, 0, 0), "la": (-1.3, 0.4, 0), "lean": (0, 0.2, 0)}, {"ra": (-1.6, -0.1, 0), "la": (-1.0, 0.4, 0), "lean": (0.15, -0.25, 0)}, {"ra": (-1.1, 0, 0), "la": (-1.2, 0.4, 0), "lean": (0.05, -0.1, 0)}],
    "hook": [{"la": (-0.4, 0, -0.4), "ra": (-1.3, -0.4, 0), "lean": (0, -0.35, 0)}, {"la": (-1.5, -0.9, -0.2), "ra": (-1.0, -0.4, 0), "lean": (0.1, 0.45, 0)}, {"la": (-1.1, -0.4, -0.1), "ra": (-1.2, -0.4, 0), "lean": (0.05, 0.15, 0)}],
    "stagger": [{"lean": (-0.35, 0.2, 0.15), "ra": (-0.4, 0, 0.9), "la": (-0.2, 0, -0.6), "head": (-0.4, 0.3, 0)}, {"lean": (-0.2, -0.1, -0.1), "ra": (-0.2, 0, 0.4), "la": (-0.5, 0, -0.9), "head": (-0.15, -0.2, 0)}],
    "grab": [{"ra": (-1.3, 0, 0.3), "la": (-1.3, 0, -0.3), "lean": (0.1, 0, 0)}, {"ra": (-1.55, 0, -0.05), "la": (-1.55, 0, 0.05), "lean": (0.25, 0, 0)}],
    "resist": [{"ra": (-1.5, 0, -0.1), "la": (-1.5, 0, 0.1), "lean": (0.35, 0, 0), "rl": (0.4, 0, 0), "ll": (-0.5, 0, 0)}, {"ra": (-1.5, 0, -0.15), "la": (-1.5, 0, 0.15), "lean": (0.45, 0, 0.05), "rl": (0.5, 0, 0), "ll": (-0.6, 0, 0)}],
    "throw": [{"ra": (-1.4, 0.4, 0), "la": (-1.4, 0.4, 0), "lean": (0.2, 0.5, 0)}, {"ra": (-2.2, -0.6, 0.3), "la": (-2.0, -0.6, -0.2), "lean": (-0.1, -0.7, 0)}, {"ra": (-0.8, -0.9, 0.4), "la": (-0.6, -0.9, 0), "lean": (0.3, -0.9, 0)}],
    "dodge_l": [{"lean": (0, 0, -0.35), "root": (-2, -1, 0), "ra": (-1.2, 0, 0.2), "la": (-1.2, 0, -0.2)}, {"lean": (0.1, 0, -0.5), "root": (-4, -2, 0), "ra": (-1.3, 0, 0.3), "la": (-1.3, 0, -0.1)}],
    "dodge_r": [{"lean": (0, 0, 0.35), "root": (2, -1, 0), "ra": (-1.2, 0, 0.2), "la": (-1.2, 0, -0.2)}, {"lean": (0.1, 0, 0.5), "root": (4, -2, 0), "ra": (-1.3, 0, 0.1), "la": (-1.3, 0, -0.3)}],
    "fall": [{"lean": (-0.3, 0, 0), "ra": (-0.6, 0, 0.8), "la": (-0.6, 0, -0.8), "head": (-0.3, 0, 0)},
             {"whole": (0.8, 0, 0), "ra": (-1.0, 0, 1.0), "la": (-1.0, 0, -1.0), "head": (-0.4, 0, 0)},
             {"whole": (1.45, 0, 0), "ra": (0.3, 0, 0.9), "la": (0.3, 0, -0.9), "head": (-0.2, 0, 0)}],
    "lying": [{"whole": (1.5, 0, 0), "root": (0, 0, -13), "ra": (0.3, 0, 0.8), "la": (0.3, 0, -0.85), "head": (-0.1, 0.2, 0), "rl": (0, 0, 0.12), "ll": (0, 0, -0.1)},
              {"whole": (1.5, 0, 0), "root": (0, 0, -13), "ra": (0.25, 0, 0.75), "la": (0.35, 0, -0.9), "head": (-0.15, -0.15, 0), "rl": (0, 0, 0.12), "ll": (0, 0, -0.1)}],
    "lying_hit": [{"whole": (1.5, 0, 0), "root": (0, 0, -13), "ra": (0.4, 0, 1.0), "la": (-0.2, 0, -1.2), "head": (0, 0.7, 0.2)}, {"whole": (1.5, 0, 0), "root": (0, 0, -13), "ra": (0.2, 0, 0.6), "la": (0.5, 0, -0.7), "head": (0, -0.6, -0.2)}],
    # Steve: astride the fallen, punching downward; lowering the fist afterwards.
    "mount": [{"root": (0, -6, 0), "rl": (1.35, 0, 0.3), "ll": (1.35, 0, -0.3), "lean": (0.2, 0, 0), "ra": (-3.0, 0, 0.15), "la": (-0.9, 0, -0.3), "head": (0.35, 0, 0)},
              {"root": (0, -6, 0), "rl": (1.35, 0, 0.3), "ll": (1.35, 0, -0.3), "lean": (0.8, 0, 0), "ra": (-0.6, 0, 0.05), "la": (-0.6, 0, -0.3), "head": (0.65, 0, 0)},
              {"root": (0, -6, 0), "rl": (1.35, 0, 0.3), "ll": (1.35, 0, -0.3), "lean": (0.2, 0, 0), "la": (-3.0, 0, -0.15), "ra": (-0.9, 0, 0.3), "head": (0.35, 0, 0)},
              {"root": (0, -6, 0), "rl": (1.35, 0, 0.3), "ll": (1.35, 0, -0.3), "lean": (0.8, 0, 0), "la": (-0.6, 0, -0.05), "ra": (-0.6, 0, 0.3), "head": (0.65, 0, 0)}],
    "mount_raise": [{"root": (0, -6, 0), "rl": (1.35, 0, 0.3), "ll": (1.35, 0, -0.3), "lean": (0.3, 0, 0), "ra": (-1.2, 0, 0.1), "la": (-0.9, 0, -0.3), "head": (0.45, 0, 0)},
                    {"root": (0, -6, 0), "rl": (1.35, 0, 0.3), "ll": (1.35, 0, -0.3), "lean": (-0.15, 0, 0), "ra": (-3.1, 0, 0.1), "la": (-3.0, 0, -0.1), "head": (0.1, 0, 0)}],
    "mount_slam": [{"root": (0, -6, 0), "rl": (1.35, 0, 0.3), "ll": (1.35, 0, -0.3), "lean": (-0.15, 0, 0), "ra": (-3.1, 0, 0.1), "la": (-3.0, 0, -0.1), "head": (0.1, 0, 0)},
                   {"root": (0, -7, 0), "rl": (1.35, 0, 0.3), "ll": (1.35, 0, -0.3), "lean": (0.95, 0, 0), "ra": (-0.5, 0, 0.1), "la": (-0.5, 0, -0.1), "head": (0.75, 0, 0)}],
    "mount_still": [{"root": (0, -6, 0), "rl": (1.35, 0, 0.3), "ll": (1.35, 0, -0.3), "lean": (0.7, 0, 0), "ra": (-0.6, 0, 0.1), "la": (-0.55, 0, -0.1), "head": (0.6, 0, 0)},
                    {"root": (0, -6, 0), "rl": (1.35, 0, 0.3), "ll": (1.35, 0, -0.3), "lean": (0.66, 0, 0), "ra": (-0.6, 0, 0.1), "la": (-0.55, 0, -0.1), "head": (0.55, 0, 0)}],
    "lunge": [{"lean": (0.35, -0.3, 0), "ra": (-1.6, -0.1, 0), "la": (-0.4, 0, -0.3), "rl": (-0.5, 0, 0), "ll": (0.6, 0, 0), "root": (0, -1, 0)},
              {"lean": (0.5, -0.45, 0), "ra": (-1.7, -0.2, 0), "la": (0.2, 0, -0.4), "rl": (-0.7, 0, 0), "ll": (0.8, 0, 0), "root": (0, -2, 0)}],
    "knocked": [{"lean": (-0.55, 0.3, 0.2), "ra": (-0.3, 0, 1.2), "la": (-0.2, 0, -1.1), "head": (-0.6, 0.4, 0), "rl": (0.3, 0, 0), "ll": (-0.2, 0, 0)},
                {"lean": (-0.35, 0.1, 0.1), "ra": (-0.2, 0, 0.7), "la": (-0.4, 0, -0.8), "head": (-0.3, 0.2, 0)}],
    "aura": [{"ra": (0.1, 0, 0.35), "la": (0.1, 0, -0.35), "head": (0.28, 0, 0), "lean": (-0.05, 0, 0)},
             {"ra": (0.1, 0, 0.42), "la": (0.1, 0, -0.42), "head": (0.3, 0, 0), "lean": (-0.08, 0, 0)}],
    "exhausted": [{"lean": (0.45, 0, 0), "head": (0.5, 0, 0), "ra": (0.2, 0, 0.15), "la": (0.2, 0, -0.15), "rl": (-0.2, 0, 0.1), "ll": (0.2, 0, -0.1), "root": (0, -1, 0)},
                  {"lean": (0.55, 0, 0), "head": (0.6, 0, 0), "ra": (0.25, 0, 0.1), "la": (0.25, 0, -0.1), "rl": (-0.2, 0, 0.1), "ll": (0.2, 0, -0.1), "root": (0, -1.5, 0)}],
    "lower_arm": [{"ra": (-2.4, 0, 0.1), "head": (0.2, 0, 0)}, {"ra": (-1.6, 0, 0.1), "head": (0.3, 0, 0)}, {"ra": (-0.6, 0, 0.05), "head": (0.35, 0, 0)}, {"ra": (0, 0, 0.02), "head": (0.3, 0, 0)}],
}
# Frames per pose: keyframes are interpolated to this many frames.
COUNTS = {"idle": 4, "walk": 8, "deflect": 3, "cast": 4, "invite": 2, "look_hand": 2, "kneel": 2, "rise": 4, "float": 4,
          "slam": 3, "guard": 1, "jab": 3, "hook": 3, "stagger": 2, "grab": 2, "resist": 2, "throw": 3, "dodge_l": 2,
          "dodge_r": 2, "fall": 4, "lying": 2, "lying_hit": 2, "headless": 1, "mount": 4, "lower_arm": 4,
          "mount_raise": 3, "mount_slam": 2, "mount_still": 2, "lunge": 2, "knocked": 2, "aura": 2, "exhausted": 2}
HEROBRINE = ["idle", "walk", "deflect", "cast", "invite", "look_hand", "kneel", "rise", "float", "slam", "guard", "jab",
             "hook", "stagger", "grab", "throw", "fall", "lying", "lying_hit", "headless", "lunge", "knocked", "aura", "exhausted"]
STEVE = ["idle", "walk", "guard", "jab", "hook", "stagger", "resist", "throw", "dodge_l", "dodge_r", "grab", "mount", "lower_arm", "mount_raise", "mount_slam", "mount_still", "lunge", "knocked"]


def frames_for(name):
    n = COUNTS[name]
    if name == "walk":
        out = []
        for i in range(n):
            s = math.sin(i / n * math.tau)
            out.append({"rl": (s * 0.7, 0, 0), "ll": (-s * 0.7, 0, 0), "ra": (-s * 0.6, 0, 0.04), "la": (s * 0.6, 0, -0.04), "root": (0, abs(s) * 0.6, 0)})
        return out
    if name == "headless":
        return [dict(POSES["lying"][0], headless=True)]
    keys = POSES[name]
    if n <= len(keys):
        return keys[:n]
    out = []
    for i in range(n):
        t = i / (n - 1) * (len(keys) - 1)
        a = int(min(len(keys) - 2, t))
        out.append(mix(keys[a], keys[a + 1], ease(t - a)))
    return out


def atlas(tex, names):
    columns = []
    layout = {}
    for name in names:
        layout[name] = {"start": len(columns), "count": COUNTS[name]}
        columns += frames_for(name)
    w, h = FRAME
    out = Image.new("RGBA", (w * len(columns), h * 3))
    for row_i, row in enumerate(DIRECTIONS):
        for col, pose in enumerate(columns):
            mesh = figure(tex, pose, pose.get("headless", False))
            out.paste(bake(mesh, FRAME, SCALE, CENTER, yaw=DIRECTIONS[row], elevation=20), (col * w, row_i * h))
    return out, layout


def generate():
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    sprites = []
    layout = {}
    for face in ["calm", "smile", "rage", "dim"]:
        image, layout = atlas(herobrine_skin(imp, face), HEROBRINE)
        imp.save(image, "ch4_hb_" + face, ["entity/player/wide/steve (white eyes, " + face + " mouth texels)"])
        sprites.append("ch4_hb_" + face)
    fist, fist_layout = atlas(imp.tex("entity/player/wide/steve"), STEVE)
    imp.save(fist, "ch4_fist_steve", ["entity/player/wide/steve"])
    sprites.append("ch4_fist_steve")
    for name in ["sun", "moon/full_moon"]:
        sky = imp.tex("environment/celestial/" + name).copy()
        # The sky is drawn additively in the game: black means transparent.
        px = sky.load()
        for y in range(sky.size[1]):
            for x in range(sky.size[0]):
                r, g_, b, a_ = px[x, y]
                lum = max(r, g_, b)
                px[x, y] = (min(255, r * 255 // max(1, lum)), min(255, g_ * 255 // max(1, lum)), min(255, b * 255 // max(1, lum)), lum * a_ // 255)
        imp.save(sky, "ch4_" + name.split("/")[0], ["environment/celestial/" + name])
        sprites.append("ch4_" + name.split("/")[0])
    # Where the head sits in the side view of the lying pose (for the final blow).
    head = bake(figure(imp.tex("entity/player/wide/steve"), POSES["lying"][0], only_head=True), FRAME, SCALE, CENTER, yaw=DIRECTIONS["side"], elevation=20)
    box_ = Image.fromarray(np.array(head)).getbbox() if not isinstance(head, Image.Image) else head.getbbox()
    head_at = [(box_[0] + box_[2]) / 2 - CENTER[0], (box_[1] + box_[3]) / 2 - CENTER[1]]
    data = {"sprites": sprites, "lying_head": head_at, "frame": list(FRAME), "anchor": list(CENTER), "herobrine": layout, "steve": fist_layout,
            "directions": list(DIRECTIONS)}
    (ROOT / "data/chapter_four_finale_assets.json").write_text(json.dumps(data, indent=2) + "\n")
    (ROOT / "docs/CHAPTER_FOUR_FINALE_MANIFEST.json").write_text(json.dumps({"version": version, "client_jar": str(client), "raw_files": imp.files, "derived": imp.derived}, indent=2) + "\n")
    print("Finale baked", sprites, sum(v["count"] for v in layout.values()), "Herobrine frames")


if __name__ == "__main__":
    generate()
