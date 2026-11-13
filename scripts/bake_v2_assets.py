"""Bake the version 2 content assets from the local vanilla client.

Witch and Phantom are textured cuboids in vanilla model coordinates
(java_part), projected with the same orthographic camera as every other actor.
Landmarks are block cuboids. Achievement icons are packaged from the shared
saved imagegen atlas; rebuilding never calls an image generator.
Writes assets/sprites/*.png, data/v2_assets.json and docs/V2_ASSET_MANIFEST.json.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

from import_minecraft_assets import ROOT, Importer, bake, box, find_client, tinted
from bake_minecraft_characters import DIRECTIONS, action_pose, java_part, part, transform

OUT = ROOT / "assets/sprites"
WATER = (63, 118, 228)


def witch(imp, state, index, count):
    tex = imp.tex("entity/witch")
    gait, lift, action, hurt, breath = action_pose(state, index, count)
    mesh = []
    head_tilt = (hurt * 1.2, 0, 0)
    head = java_part(tex, (-4, -10, -4), (8, 10, 8), (0, 0))
    head += java_part(tex, (-1, -1, -6), (2, 4, 2), (24, 0), pivot=(0, -2, 0))
    # Hat: four stacked boxes, each tilted a little further back (vanilla chain).
    head += java_part(tex, (0, 0, 0), (10, 2, 10), (0, 64), pivot=(-5, -10.03, -5))
    head += java_part(tex, (0, 0, 0), (7, 4, 7), (0, 76), pivot=(-3.25, -14.03, -3), angles=(-0.05, 0, 0.03))
    head += java_part(tex, (0, 0, 0), (4, 4, 4), (0, 87), pivot=(-1.5, -18.03, -1), angles=(-0.1, 0, 0.05))
    head += java_part(tex, (0, 0, 0), (1, 2, 1), (0, 95), pivot=(0.25, -20.03, 1), angles=(-0.2, 0, 0.1))
    mesh += transform(head, head_tilt, pivot=(0, 24, 0))
    mesh += java_part(tex, (-4, 0, -3), (8, 12, 6), (16, 20))
    robe = java_part(tex, (-4, 0, -3), (8, 20, 6), (0, 38))
    center = np.array([0, 14, 0])
    mesh += [(center + (v - center) * np.array([1.06, 1.02, 1.08]), t, r, s) for v, t, r, s in robe]
    # Crossed arms; a throw raises them overhead.
    arm_angle = -0.75 + action * 2.2
    arms = java_part(tex, (-8, -2, -2), (4, 8, 4), (44, 22))
    arms += java_part(tex, (4, -2, -2), (4, 8, 4), (44, 22))
    arms += java_part(tex, (-4, 2, -2), (8, 4, 4), (40, 38))
    mesh += transform(arms, (-arm_angle, 0, 0), pivot=(0, 21, -1))
    if state in ["windup", "attack"]:
        bottle = imp.tex("item/potion")
        quad = np.array([[-4, 31, -6], [4, 31, -6], [4, 23, -6], [-4, 23, -6]], dtype=float)
        mesh += transform([(quad, bottle, (0, 0, 16, 16), 1.0)], (-arm_angle * 0.7, 0, 0), pivot=(0, 21, -1))
    for sign in [-1, 1]:
        mesh += java_part(tex, (-2, 0, -2), (4, 12, 4), (0, 22), pivot=(sign * 2, 12, 0), angles=(gait * 0.6 * sign, 0, 0))
    return transform(mesh, (hurt * 0.3, 0, 0), pivot=(0, 12, 0), offset=(0, lift + breath, 0))


def phantom(imp, state, index, count):
    tex = imp.tex("entity/phantom")
    eyes = imp.tex("entity/phantom_eyes")
    t = index / max(1, count)
    if state in ["walk", "idle"]:
        flap = math.cos(t * math.tau) * 0.55
    elif state == "windup":
        flap = 0.75 - index / max(1, count - 1) * 0.3
    elif state == "attack":
        flap = -0.85
    else:
        flap = 0.2 + math.sin(t * math.pi) * 0.3
    mesh = []
    for layer in [tex, eyes]:
        mesh += java_part(layer, (-3, -2, -8), (5, 3, 9), (0, 8), pivot=(0, 1, 0), angles=(-0.1, 0, 0))
        mesh += java_part(layer, (-4, -2, -5), (7, 3, 5), (0, 0), pivot=(0, 1, -7), angles=(0.2, 0, 0))
        if layer is eyes:
            continue
        mesh += java_part(tex, (-2, 0, 0), (3, 2, 6), (3, 20), pivot=(0, -2, 1))
        mesh += java_part(tex, (-1, 0, 0), (1, 1, 6), (4, 29), pivot=(0, -1.5, 7), angles=(-0.1, 0, 0))
        for sign in [-1, 1]:
            base = java_part(tex, (0, 0, 0) if sign > 0 else (-6, 0, 0), (6, 2, 9), (23, 12), pivot=(sign * 2, -2, -8), angles=(0, 0, sign * flap))
            tip_pivot = np.array([sign * 2 + sign * 6 * math.cos(flap), 24 + 2 + sign * 0, -8])
            tip = box(tex, (0, -1, 0) if sign > 0 else (-13, -1, 0), (13, 1, 9), (16, 24))
            tip = transform(tip, (0, 0, -sign * flap * 1.6), offset=(0, 0, 0))
            tip = transform(tip, (0, 0, 0), offset=(sign * 2 + sign * 6 * math.cos(flap), 24 + 2 - sign * 6 * math.sin(flap) * -1, -8))
            mesh += base + tip
    return mesh


def actor_atlas(imp, name, builder, frame, scale, center, spec):
    w, h = frame
    atlas = Image.new("RGBA", (w * spec["columns"], h * 3))
    for row_i, row in enumerate(DIRECTIONS):
        for state, clip in spec["states"].items():
            n = len(clip["durations"])
            for i in range(n):
                im = bake(builder(imp, state, i, n), frame, scale, center, yaw=DIRECTIONS[row], elevation=20)
                atlas.paste(im, ((clip["start"] + i) * w, row_i * h))
    return atlas


def block(imp, name, origin, size, top=None, tint=None):
    tex = imp.tex("block/" + name)
    toptex = imp.tex("block/" + top) if top else tex
    if tint:
        tex = tinted(tex, tint)
        toptex = tinted(toptex, tint)
    faces = {f: (toptex if f in ["up", "down"] else tex, (0, 0, 16, 16)) for f in ["north", "south", "east", "west", "up", "down"]}
    return box(tex, origin, size, faces=faces)


def ruin(imp, variant):
    mesh = []
    # An L of broken cobblestone wall with mossy courses and an oak corner post.
    heights = [[16, 12, 8, 4, 12, 8], [12, 16, 16, 8, 4, 0]][variant % 2]
    for i, hgt in enumerate(heights):
        if hgt:
            mesh += block(imp, "mossy_cobblestone" if (i + variant) % 3 == 0 else "cobblestone", (-24 + i * 8, 0, 8), (8, hgt, 8))
    for i, hgt in enumerate([12, 8, 0, 4]):
        if hgt:
            mesh += block(imp, "cobblestone" if i % 2 else "mossy_cobblestone", (-24, 0, 0 - i * 8), (8, hgt, 8))
    mesh += block(imp, "oak_log", (-26, 0, 6), (4, 22, 4), "oak_log_top")
    mesh += block(imp, "oak_planks", (-10, 0, -14), (12, 2, 10))
    return mesh


def well(imp):
    mesh = []
    for x, z, w, d in [(-12, -12, 24, 4), (-12, 8, 24, 4), (-12, -8, 4, 16), (8, -8, 4, 16)]:
        mesh += block(imp, "cobblestone", (x, 0, z), (w, 8, d))
    mesh += block(imp, "water_still", (-8, 0, -8), (16, 6, 16), tint=WATER)
    for x, z in [(-12, -12), (8, -12), (-12, 8), (8, 8)]:
        mesh += block(imp, "oak_fence" if False else "oak_planks", (x + 1, 8, z + 1), (2, 14, 2))
    mesh += block(imp, "cobblestone", (-14, 22, -14), (28, 3, 28))
    return mesh


def mine(imp):
    mesh = []
    mesh += block(imp, "stone", (-22, 0, 4), (44, 30, 10))
    mesh += block(imp, "black_concrete", (-10, 0, 3), (20, 22, 2))
    for x in [-12, 8]:
        mesh += block(imp, "oak_log", (x, 0, 0), (4, 24, 4), "oak_log_top")
    mesh += block(imp, "oak_planks", (-14, 22, -1), (28, 4, 6))
    mesh += block(imp, "torch", (-17, 14, -1), (2, 8, 2))
    return mesh


def bastion(imp):
    mesh = []
    for i, hgt in enumerate([20, 28, 20, 12, 24, 28, 20]):
        mesh += block(imp, "polished_blackstone_bricks", (-56 + i * 16, 0, 16), (16, hgt, 12))
    for x in [-56, 40]:
        mesh += block(imp, "polished_blackstone_bricks", (x, 0, -24), (16, 24, 40))
    mesh += block(imp, "gilded_blackstone", (-8, 28, 14), (16, 6, 14))
    mesh += block(imp, "blackstone", (-24, 0, -20), (48, 3, 36))
    return mesh


def end_city(imp):
    mesh = []
    mesh += block(imp, "purpur_block", (-32, 0, -16), (64, 4, 40))
    for x in [-32, 20]:
        mesh += block(imp, "purpur_pillar", (x, 4, 12), (12, 34, 12), "purpur_pillar_top")
    for i, hgt in enumerate([24, 16, 8]):
        mesh += block(imp, "purpur_block", (-20 + i * 12, 4, 16), (12, hgt, 8))
    mesh += block(imp, "purpur_block", (-36, 38, 8), (72, 6, 20))
    for x in [-30, 28]:
        mesh += block(imp, "end_rod", (x, 44, 16), (2, 14, 2))
    return mesh


def import_sounds(version):
    import hashlib
    prism = Path.home() / ".local/share/PrismLauncher"
    meta = json.loads((prism / f"meta/net.minecraft/{version}.json").read_text())
    index = json.loads((prism / f"assets/indexes/{meta['assetIndex']['id']}.json").read_text())["objects"]

    def raw(name):
        sha = index["minecraft/" + name]["hash"]
        data = (prism / f"assets/objects/{sha[:2]}/{sha}").read_bytes()
        assert hashlib.sha1(data).hexdigest() == sha
        return data

    sounds = json.loads(raw("sounds.json"))
    events = {"hurt_witch": ("entity.witch.hurt", .45), "witch_throw": ("entity.witch.throw", .5),
              "witch_laugh": ("entity.witch.celebrate", .45), "hurt_phantom": ("entity.phantom.hurt", .45),
              "phantom_swoop": ("entity.phantom.swoop", .55), "phantom_flap": ("entity.phantom.flap", .35),
              "potion_splash": ("entity.splash_potion.break", .5), "cave": ("ambient.cave", .5),
              "chest_open": ("block.chest.open", .5), "gust": ("entity.breeze.wind_burst", .5)}
    mapping, manifest = {}, {}
    for ident, (event, gain) in events.items():
        variants = []
        for v in sounds[event]["sounds"]:
            v = {"name": v} if isinstance(v, str) else v
            if v.get("type") == "event":
                continue
            name = v["name"].replace("minecraft:", "")
            data = raw("sounds/" + name + ".ogg")
            filename = name.replace("/", "_") + ".ogg"
            (ROOT / "assets/audio/minecraft" / filename).write_bytes(data)
            variants.append(dict(path="res://assets/audio/minecraft/" + filename, volume=v.get("volume", 1), pitch=v.get("pitch", 1)))
            manifest[filename] = dict(source="minecraft/sounds/" + name + ".ogg", sha256=hashlib.sha256(data).hexdigest())
        mapping[ident] = dict(minecraft_event=event, gain=gain, variants=variants)
    (ROOT / "data/v2_audio.json").write_text(json.dumps(mapping, indent=2) + "\n")
    return manifest


def badge(imp, name, background, icon, tint=None, scale=1.5, crop=None):
    """Keep version 2 rebuilds on the same reviewed achievement atlas."""
    from bake_achievement_assets import render_badge, ORIGIN
    imp.save(render_badge(name), "achievement_" + name, ["assets/art_source/achievements_v2/atlas.png"])
    imp.derived["achievement_" + name]["origin"] = ORIGIN
    return "achievement_" + name


def spec_like(base, frame, pivot, states=None):
    spec = json.loads(json.dumps(base))
    spec["frame_size"] = list(frame)
    spec["pivot"] = list(pivot)
    spec["anchor"] = list(pivot)
    if states:
        spec["states"] = states
        spec["columns"] = max(c["start"] + len(c["durations"]) for c in states.values())
    return spec


def generate():
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    data = json.loads((ROOT / "data/animations.json").read_text())
    zombie = data["actors"]["zombie"]
    actors = {}
    witch_spec = spec_like(zombie, (32, 44), (16, 40))
    witch_spec["states"]["windup"]["durations"] = [0.12, 0.12, 0.12]
    actors["witch"] = witch_spec
    imp.save(actor_atlas(imp, "witch", witch, (32, 44), 0.8, (16, 40), witch_spec), "witch_atlas", ["entity/witch", "item/potion"])
    fly = {"idle": {"start": 0, "durations": [0.09] * 8, "loop": True},
           "walk": {"start": 0, "durations": [0.09] * 8, "loop": True},
           "windup": {"start": 8, "durations": [0.15, 0.15, 0.2], "loop": False},
           "attack": {"start": 11, "durations": [0.1, 0.1], "loop": True},
           "recover": {"start": 13, "durations": [0.1, 0.1, 0.1], "loop": False},
           "hurt": {"start": 16, "durations": [0.05, 0.07], "loop": False}}
    phantom_spec = spec_like(zombie, (64, 40), (32, 24), fly)
    phantom_spec["shadow_size"] = [10, 3]
    actors["phantom"] = phantom_spec
    imp.save(actor_atlas(imp, "phantom", phantom, (64, 40), 0.9, (32, 30), phantom_spec), "phantom_atlas", ["entity/phantom", "entity/phantom_eyes"])
    sprites = ["witch_atlas", "phantom_atlas"]
    for name, mesh, size, scale, center, yaw in [
        ("ruin_0", ruin(imp, 0), (96, 72), 1.15, (52, 60), 22),
        ("ruin_1", ruin(imp, 1), (96, 72), 1.15, (52, 60), -18),
        ("well", well(imp), (64, 64), 1.2, (32, 52), 20),
        ("mine_entrance", mine(imp), (96, 72), 1.2, (48, 60), 0),
        ("bastion", bastion(imp), (192, 128), 1.25, (96, 104), 0),
        ("end_city", end_city(imp), (128, 112), 1.25, (64, 94), 0)]:
        imp.save(bake(mesh, size, scale, center, yaw=yaw, elevation=22), name, ["block textures"])
        sprites.append(name)
    imp.save(tinted(imp.tex("block/water_still").crop((0, 0, 16, 16)), WATER), "water_tile", ["block/water_still"])
    imp.native_strip("water_animation", "block/water_still")
    water = Image.open(OUT / "water_animation.png")
    imp.save(tinted(water, WATER), "water_animation", ["block/water_still"])
    sprites += ["water_tile", "water_animation"]
    for name in ["cobblestone", "mossy_cobblestone", "oak_planks", "blackstone", "purpur_block", "end_rod"]:
        imp.save(imp.tex("block/" + name), "block_" + name, ["block/" + name])
        sprites.append("block_" + name)
    imp.copy_item("potion", "potion")
    sprites.append("icon_potion")
    sprites += [badge(imp, "blood_moon", "netherrack", "entity/zombie/zombie", (255, 120, 120), 2.0, (8, 8, 16, 16)),
                badge(imp, "witch_hunter", "dark_oak_planks", "entity/witch", None, 2.0, (8, 8, 16, 18)),
                badge(imp, "phantom_slayer", "obsidian", "item/phantom_membrane"),
                badge(imp, "bastion", "polished_blackstone_bricks", "item/gold_ingot"),
                badge(imp, "end_city", "purpur_block", "item/elytra"),
                badge(imp, "windswept", "end_stone", "item/wind_charge")]
    (ROOT / "data/v2_assets.json").write_text(json.dumps({"sprites": sprites, "clips": imp.clips, "actors": actors}, indent=2) + "\n")
    audio = import_sounds(version)
    (ROOT / "docs/V2_ASSET_MANIFEST.json").write_text(json.dumps({"version": version, "client_jar": str(client), "raw_files": imp.files, "derived": imp.derived, "audio": audio}, indent=2) + "\n")
    print("V2 assets baked", version, len(sprites))


if __name__ == "__main__":
    generate()
