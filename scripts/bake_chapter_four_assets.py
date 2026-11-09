"""Bake chapter IV "Обычный мир" from the local vanilla client.

Scorched ground with opaque blood soil, flesh foci and readable roads; burned
houses, crucifixion pillars, red torches, Herobrine's pyramid, flesh growths,
blood pools and deformed mobs. Every surface samples an original vanilla
texture (darkened, tinted or combined); no image generation, no painted art.
Writes assets/sprites/ch4_*.png, data/chapter_four_assets.json,
data/chapter_four_terrain.json and docs/CHAPTER_FOUR_ASSET_MANIFEST.json.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageEnhance

from import_minecraft_assets import ROOT, Importer, bake, box, find_client, tinted
from bake_minecraft_characters import DIRECTIONS, action_pose, java_part, part, transform

OUT = ROOT / "assets/sprites"
SIZE = 2048
TILES = 128
BLOOD = (122, 14, 18)

# ------------------------------------------------------------------ layout
# One fixed, authored layout: spawn in the middle, a road west to the infected
# village, south-east to Herobrine's pyramid, a blood pool on each side.
SPAWN = (1024, 1024)
VILLAGE = (600, 760)
PYRAMID = (1460, 1440)
POOLS = [((1300, 640), 92), ((560, 1360), 78), ((1660, 1090), 64)]
FLESH = [(VILLAGE, 250), (POOLS[0][0], 170), (PYRAMID, 300), ((860, 1520), 120)]
ROADS = [(SPAWN, VILLAGE), (SPAWN, PYRAMID), (VILLAGE, (560, 1360))]


def field(seed, cells, scale):
    """Smooth value noise sampled per tile."""
    rng = np.random.default_rng(seed)
    coarse = rng.random((cells // scale + 2, cells // scale + 2))
    ys, xs = np.mgrid[0:cells, 0:cells] / scale
    x0, y0 = xs.astype(int), ys.astype(int)
    fx, fy = xs - x0, ys - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = coarse[y0, x0] * (1 - fx) + coarse[y0, x0 + 1] * fx
    b = coarse[y0 + 1, x0] * (1 - fx) + coarse[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def segment_distance(p, a, b):
    p, a, b = np.array(p, float), np.array(a, float), np.array(b, float)
    t = np.clip(np.dot(p - a, b - a) / np.dot(b - a, b - a), 0, 1)
    return np.linalg.norm(p - (a + t * (b - a)))


def shade(image, rgb):
    return ImageChops.multiply(image.convert("RGBA"), Image.new("RGBA", image.size, (*rgb, 255)))


def cold(image, black, white):
    """Burnt ground: the vanilla texture's own value pattern, recoloured cold."""
    from PIL import ImageOps
    grey = ImageOps.autocontrast(image.convert("L"), cutoff=2)
    return ImageOps.colorize(grey, black=black, white=white).convert("RGBA")


def ground(imp):
    # Cold charcoal and ash make every red accent (blood, flesh, torches) read
    # at a glance; the warm brown of the first pass blended everything together.
    base_names = ["coarse_dirt", "tuff", "rooted_dirt", "coarse_dirt"]
    base = [cold(imp.tex("block/" + n), (11, 9, 11), (70, 62, 64)) for n in base_names]
    ash = cold(imp.tex("block/gravel"), (30, 28, 30), (96, 92, 94))
    road = cold(imp.tex("block/dirt_path_top"), (40, 36, 36), (128, 118, 112))
    # Dried blood is dark and rusty; only small wet patches carry the bright crimson.
    blood = [cold(imp.tex("block/crimson_nylium"), (20, 3, 5), (96, 16, 20)), cold(imp.tex("block/red_concrete_powder"), (24, 3, 6), (88, 14, 18))]
    wet = cold(imp.tex("block/red_concrete_powder"), (60, 4, 10), (190, 26, 34))
    flesh = [shade(imp.tex("block/nether_wart_block"), (235, 150, 150)), shade(imp.tex("block/nether_wart_block"), (200, 110, 112))]
    vein = imp.tex("block/sculk_vein")
    tone = field(4, TILES, 9)
    rot_rng = np.random.default_rng(11)
    out = Image.new("RGBA", (SIZE, SIZE))
    kinds = np.zeros((TILES, TILES), dtype=np.uint8)  # 0 ground 1 road 2 blood 3 flesh
    blood_noise = field(7, TILES, 6)
    for ty in range(TILES):
        for tx in range(TILES):
            p = (tx * 16 + 8, ty * 16 + 8)
            kind = 0
            infection = max(0.0, max(1 - math.dist(p, c) / r for c, r in FLESH))
            if infection > 0.5 + 0.28 * blood_noise[ty, tx]:
                kind = 3 if infection > 0.74 + 0.18 * blood_noise[ty, tx] else 2
            elif blood_noise[ty, tx] > 0.93:
                kind = 2
            if any(segment_distance(p, a, b) < 22 for a, b in ROADS):
                kind = 1
            kinds[ty, tx] = kind
            if kind == 1:
                tile = road
            elif kind == 2:
                tile = wet if blood_noise[ty, tx] > 0.72 else blood[(tx * 7 + ty * 3) % 2]
            elif kind == 3:
                tile = flesh[(tx + ty) % 2]
            else:
                pick = min(len(base) - 1, int(tone[ty, tx] * 1.6 * len(base)) % len(base))
                tile = ash if rot_rng.random() < 0.05 else base[pick]
            tile = tile.rotate(90 * int(rot_rng.integers(4)))
            out.paste(tile, (tx * 16, ty * 16))
            if kind == 3 and rot_rng.random() < 0.35:
                out.alpha_composite(tinted(vein, (155, 45, 40)), (tx * 16, ty * 16))
    imp.save(out.convert("RGB"), "ch4_ground", ["block/" + n for n in base_names] + ["block/gravel", "block/dirt_path_top", "block/crimson_nylium", "block/red_concrete_powder", "block/nether_wart_block", "block/sculk_vein"])
    return kinds


# ------------------------------------------------------------------ blocks & structures

def block(imp, name, origin, size, top=None, rgb=None):
    tex = imp.tex("block/" + name)
    toptex = imp.tex("block/" + top) if top else tex
    if rgb:
        tex, toptex = shade(tex, rgb), shade(toptex, rgb)
    faces = {f: (toptex if f in ["up", "down"] else tex, (0, 0, 16, 16)) for f in ["north", "south", "east", "west", "up", "down"]}
    return box(tex, origin, size, faces=faces)


def cross_plane(tex, x, y, z, w, h, scale=1.0):
    """Vanilla cross model (torch / plant): two crossed textured planes."""
    hw = w / 2
    quads = []
    for angle in [math.pi / 4, -math.pi / 4]:
        dx, dz = math.cos(angle) * hw, math.sin(angle) * hw
        quad = np.array([[x - dx, y + h, z - dz], [x + dx, y + h, z + dz], [x + dx, y, z + dz], [x - dx, y, z - dz]], dtype=float)
        quads.append((quad, tex, (0, 0, 16, 16), 1.0))
    return quads


CHAR = (60, 52, 50)


def house(imp, variant):
    mesh = []
    walls = [[18, 14, 6, 18, 10], [10, 18, 18, 4, 14]][variant % 2]
    for i, h in enumerate(walls):
        mesh += block(imp, "oak_planks" if i % 2 else "cobblestone", (-30 + i * 12, 0, 10), (12, h, 6), rgb=CHAR if i % 2 else (90, 84, 82))
    for i, h in enumerate([16, 6, 12]):
        mesh += block(imp, "cobblestone", (-30, 0, -14 + i * 8), (6, h, 8), rgb=(90, 84, 82))
    mesh += block(imp, "oak_log", (-32, 0, 8), (5, 26, 5), "oak_log_top", rgb=CHAR)
    mesh += block(imp, "oak_log", (28, 0, 8), (5, 20 - variant * 6, 5), "oak_log_top", rgb=CHAR)
    # Collapsed roof beams.
    beam = block(imp, "oak_log", (-26, 0, -6), (46, 4, 4), "oak_log_top", rgb=CHAR)
    mesh += transform(beam, (0, 0.15, 0.22 if variant else -0.18), pivot=(0, 0, -4))
    mesh += block(imp, "oak_planks", (-14, 0, -12), (20, 2, 12), rgb=CHAR)
    return mesh


def villager_tpose(imp, slump):
    tex = imp.tex("entity/villager/villager")
    prof = imp.tex("entity/villager/type/plains")
    mesh = []
    for layer in [tex, prof]:
        head = java_part(layer, (-4, -10, -4), (8, 10, 8), (0, 0))
        head += java_part(layer, (-1, -1, -6), (2, 4, 2), (24, 0), pivot=(0, -2, 0))
        mesh += transform(head, (slump, 0, 0.25 * slump), pivot=(0, 24, 0))
        mesh += java_part(layer, (-4, 0, -3), (8, 12, 6), (16, 20))
        mesh += java_part(layer, (-4, 0, -3), (8, 18, 6), (0, 38))
        for sign in [-1, 1]:
            arm = java_part(layer, (-2, -2, -2) if sign > 0 else (-2, -2, -2), (4, 8, 4), (44, 22), pivot=(sign * 6, 2, 0), angles=(0, 0, sign * 1.5))
            mesh += arm
            mesh += java_part(layer, (-2, 0, -2), (4, 12, 4), (0, 22), pivot=(sign * 2, 12, 0), angles=(0, 0, -sign * 0.05))
        if layer is tex:
            continue
    blood_mesh = []
    for v, t, r, s in mesh:
        blood_mesh.append((v, t, r, s))
    return blood_mesh


def crucifix(imp, variant):
    mesh = block(imp, "oak_log", (-2.5, 0, 2), (5, 52, 5), "oak_log_top", rgb=(80, 62, 56))
    mesh += block(imp, "oak_log", (-16, 38, 2), (32, 4, 4), "oak_log_top", rgb=(80, 62, 56))
    body = villager_tpose(imp, 0.45 + variant * 0.25)
    mesh += transform(body, offset=(0, 18, -1.5))
    mesh += block(imp, "red_concrete_powder", (-5, 0, -4), (10, 1, 8), rgb=(140, 30, 30))
    return mesh


def red_torch(imp):
    return cross_plane(imp.tex("block/redstone_torch"), 0, 0, 0, 16, 16)


def cursed_torch(imp):
    mesh = block(imp, "polished_blackstone", (-5, 0, -5), (10, 5, 10))
    mesh += red_torch(imp)
    for x in [-5, 4]:
        mesh += block(imp, "iron_block", (x, 4, -2), (1, 13, 2), rgb=(110, 85, 90))
    return mesh


def blood_hand(imp, progress):
    """Connected palm/fingers, rising and closing through shared 3D joints."""
    def flesh(origin, size):
        return block(imp, "mushroom_stem", origin, size, rgb=(220, 140, 132))
    palm = flesh((-6, 0, -3), (12, 10, 6))
    for i, x in enumerate([-5, -1.5, 2, 5]):
        length = [9, 12, 11, 8][i]
        joint = np.array((x, 10, 0))
        tip = flesh((x - 1.2, 16, -1.2), (2.4, length - 6, 2.4))
        tip = transform(tip, (progress * 1.4, 0, 0), pivot=(x, 16, 0))
        finger = flesh((x - 1.2, 10, -1.2), (2.4, 6, 2.4)) + tip
        palm += transform(finger, (progress * .8, 0, (i - 1.5) * -.12), pivot=joint)
    thumb = flesh((-9, 3, -1), (3, 8, 3))
    palm += transform(thumb, (progress * .9, 0, -.6), pivot=(-6, 4, 0))
    palm += flesh((-4, -12, -2), (8, 12, 4))
    palm += block(imp, "nether_wart_block", (-4, -8, -2.1), (8, 3, 4.2))
    return transform(palm, (-.25, .15, .12), pivot=(0, 0, 0))


def pyramid(imp):
    mesh = []
    steps = [(96, 10, "polished_blackstone_bricks"), (76, 10, "polished_blackstone"), (56, 10, "polished_blackstone_bricks"), (36, 10, "chiseled_polished_blackstone"), (16, 8, "polished_blackstone")]
    y = 0
    for half, h, name in steps:
        mesh += block(imp, name, (-half, y, -half * 0.55), (half * 2, h, half * 1.1), "chiseled_polished_blackstone", rgb=(200, 190, 205))
        y += h
    # A strict red seam up the centre and torches at every corner.
    mesh += block(imp, "red_concrete", (-3, 0, -54), (6, 48, 2), rgb=(170, 40, 40))
    torch = imp.tex("block/redstone_torch")
    for half, h, _ in steps[:4]:
        level = sum(s[1] for s in steps[:steps.index((half, h, _)) + 1])
        for sx in [-1, 1]:
            mesh += cross_plane(torch, sx * (half - 4), level, -half * 0.55 + 4, 10, 10)
    return mesh


def growth(imp, variant, scale=1.0):
    wart = imp.tex("block/nether_wart_block")
    rng = np.random.default_rng(30 + variant)
    mesh = []
    for i in range(7 + variant * 3):
        s = (6 + rng.random() * 8) * scale
        x, z = (rng.random() - 0.5) * 18 * scale, (rng.random() - 0.5) * 12 * scale
        y = rng.random() * 8 * scale * (1 if i > 2 else 0)
        cube = box(shade(wart, (235, 150, 150) if i % 2 else (205, 115, 118)), (x - s / 2, y, z - s / 2), (s, s, s))
        mesh += transform(cube, (rng.random() * 0.6, rng.random() * 0.8, rng.random() * 0.6), pivot=(x, y + s / 2, z))
    core = box(imp.tex("block/shroomlight"), (-3 * scale, 6 * scale, -3 * scale), (6 * scale, 6 * scale, 6 * scale))
    mesh += transform(core, (0.3, 0.5, 0.2), pivot=(0, 9 * scale, 0))
    return mesh


# ------------------------------------------------------------------ generate

def generate():
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    kinds = ground(imp)
    sprites = ["ch4_ground"]
    bakes = [("ch4_house_0", house(imp, 0), (112, 80), 1.2, (56, 66), 18),
             ("ch4_house_1", house(imp, 1), (112, 80), 1.2, (56, 66), -22),
             ("ch4_crucifix_0", crucifix(imp, 0), (64, 96), 1.2, (32, 88), 8),
             ("ch4_crucifix_1", crucifix(imp, 1), (64, 96), 1.2, (32, 88), -10),
             ("ch4_red_torch", red_torch(imp), (16, 24), 1.0, (8, 21), 25),
             ("ch4_cursed_torch", cursed_torch(imp), (32, 40), 1.7, (16, 34), 25),
             ("ch4_pyramid", pyramid(imp), (288, 176), 1.25, (144, 150), 0),
             ("ch4_growth_0", growth(imp, 0), (48, 48), 1.3, (24, 40), 20),
             ("ch4_growth_1", growth(imp, 1), (48, 48), 1.3, (24, 40), -30),
             ("ch4_growth_big", growth(imp, 2, 2.4), (128, 112), 1.2, (64, 96), 10)]
    for name, mesh, size, scale, center, yaw in bakes:
        imp.save(bake(mesh, size, scale, center, yaw=yaw, elevation=22), name, ["vanilla block/entity textures"])
        sprites.append(name)
    imp.native_strip("ch4_blood_animation", "block/water_still")
    strip = Image.open(OUT / "ch4_blood_animation.png").convert("RGBA")
    strip = ImageEnhance.Contrast(strip).enhance(1.6)
    imp.save(tinted(strip, BLOOD), "ch4_blood_animation", ["block/water_still"])
    sprites.append("ch4_blood_animation")
    clips = {"ch4_blood_animation": imp.clips["ch4_blood_animation"]}
    hands = Image.new("RGBA", (64 * 10, 72))
    for i in range(10):
        frame = bake(blood_hand(imp, max(0, (i - 3) / 6)), (64, 72), 1.8, (32, 48), yaw=18, elevation=22)
        hands.alpha_composite(frame, (i * 64, 0))
    imp.save(hands, "ch4_hand", ["block/nether_wart_block", "block/mushroom_stem"])
    sprites.append("ch4_hand")
    clips["ch4_hand"] = {"frame_size": [64, 72], "frames": list(range(10)), "durations": [.08] * 10}
    imp.copy_item("ch4_note", "paper")
    sprites.append("icon_ch4_note")
    # Terrain data for the world: pools, props and landmarks in world pixels.
    pool_cells = []
    for (cx, cy), r in POOLS:
        for ty in range(TILES):
            for tx in range(TILES):
                q = (tx * 16 + 8, ty * 16 + 8)
                wobble = math.sin(tx * 1.3 + ty * 0.7) * 10
                if math.dist(q, (cx, cy)) < r + wobble:
                    pool_cells.append(ty * TILES + tx)
    rng = np.random.default_rng(91)
    props = []
    pool_set = set(pool_cells)

    def free(p, gap=40):
        cell = int(p[1] // 16) * TILES + int(p[0] // 16)
        return cell not in pool_set and all(math.dist(p, q["p"]) > gap for q in props) and math.dist(p, SPAWN) > 120 \
            and all(segment_distance(p, a, b) > 30 for a, b in ROADS) and math.dist(p, PYRAMID) > 200

    for i in range(6):
        p = (VILLAGE[0] + math.cos(i * 1.1) * (110 + i * 22), VILLAGE[1] + math.sin(i * 1.1) * (90 + i * 18))
        props.append({"type": "house", "variant": i % 2, "p": [round(p[0]), round(p[1])]})
    for i in range(3):
        p = (VILLAGE[0] - 40 + i * 44, VILLAGE[1] + 10 - abs(i - 1) * 16)
        props.append({"type": "crucifix", "variant": i % 2, "p": [round(p[0]), round(p[1])]})
    for i in range(80):
        p = (float(rng.uniform(80, 1968)), float(rng.uniform(80, 1968)))
        if free(p, 46):
            props.append({"type": "trunk", "variant": int(rng.integers(3)), "p": [round(p[0]), round(p[1])]})
    for a, b in ROADS:
        for k in range(1, 8):
            t = k / 8
            p = (a[0] + (b[0] - a[0]) * t + 34 * (1 if k % 2 else -1), a[1] + (b[1] - a[1]) * t)
            props.append({"type": "torch", "p": [round(p[0]), round(p[1])]})
    for (c, r) in FLESH:
        for k in range(4):
            p = (c[0] + math.cos(k * 1.9 + r) * r * 0.5, c[1] + math.sin(k * 1.9 + r) * r * 0.4)
            if free(p, 30):
                props.append({"type": "growth", "variant": k % 2, "p": [round(p[0]), round(p[1])]})
    props.append({"type": "growth_big", "p": [PYRAMID[0] - 170, PYRAMID[1] - 20]})
    # Hostile torches form short chains away from the safe approach roads.
    for origin in [(PYRAMID[0], PYRAMID[1] + 100), (POOLS[0][0][0] - 110, POOLS[0][0][1] + 115)]:
        for i in range(3):
            props.append({"type": "torch", "hostile": True, "p": [origin[0] + (i - 1) * 76, origin[1] + (24 if i == 1 else 0)]})
    terrain = {"size": SIZE, "tiles": TILES, "spawn": SPAWN, "village": VILLAGE, "pyramid": PYRAMID,
               "note": [VILLAGE[0] + 110, VILLAGE[1] + 24],
               "pools": [{"p": list(c), "r": r} for c, r in POOLS], "pool_cells": pool_cells,
               "flesh_cells": [int(i) for i in np.flatnonzero(kinds.ravel() == 3)],
               "props": props}
    (ROOT / "data/chapter_four_terrain.json").write_text(json.dumps(terrain) + "\n")
    data = {"sprites": sprites, "clips": clips}
    (ROOT / "data/chapter_four_assets.json").write_text(json.dumps(data, indent=2) + "\n")
    (ROOT / "docs/CHAPTER_FOUR_ASSET_MANIFEST.json").write_text(json.dumps({"version": version, "client_jar": str(client), "raw_files": imp.files, "derived": imp.derived}, indent=2) + "\n")
    print("Chapter IV assets baked", len(sprites), "props", len(props))


if __name__ == "__main__":
    generate()
