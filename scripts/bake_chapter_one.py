"""Bake chapter I's opening and Herobrine duel additions.

Herobrine is the same posed player model as in the chapter IV finale (same
rig, faces and projection); this script only adds the poses chapter I needs.
Also: Steve deflecting and Steve with the hole through his chest, a villager
wrung into a legless crawler, the oak fence, the dirt path and the party sign.
Every face samples a vanilla texture; nothing is painted by hand except the
hole and a few blood texels. Writes assets/sprites/ch1_*.png,
data/chapter_one_assets.json and data/chapter_one_audio.json.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw
import numpy as np

from import_minecraft_assets import ROOT, Importer, bake, box, find_client
from bake_minecraft_characters import transform, java_part
import bake_chapter_four_finale as four

NEW_POSES = {
    "wave": [{"ra": (-0.15, 0, 2.35), "la": (0, 0, -0.06), "head": (0, 0, 0.14), "lean": (0, 0, 0.04)},
             {"ra": (-0.15, 0, 2.85), "la": (0, 0, -0.06), "head": (0, 0, 0.18), "lean": (0, 0, 0.05)},
             {"ra": (-0.15, 0, 2.35), "la": (0, 0, -0.06), "head": (0, 0, 0.14), "lean": (0, 0, 0.04)}],
    "laugh": [{"head": (-0.42, 0, 0.05), "lean": (0.16, 0, 0), "la": (-0.75, 0, -0.35), "ra": (0.05, 0, 0.35)},
              {"head": (-0.3, 0, -0.04), "lean": (0.08, 0, 0), "la": (-0.7, 0, -0.3), "ra": (0.0, 0, 0.3), "root": (0, 0.6, 0)}],
    "shrug": [{"ra": (-0.4, 0, 0.55), "la": (-0.4, 0, -0.55), "head": (0, 0, 0.2)},
              {"ra": (-0.5, 0, 0.75), "la": (-0.5, 0, -0.75), "head": (0.05, 0, 0.26), "root": (0, 0.8, 0)}],
    "sway": [{"lean": (0.35, 0, 0.1), "root": (0, -1, 0), "ra": (0, 0, 0.7), "la": (0, 0, -0.7), "rl": (-0.3, 0, 0), "ll": (0.2, 0, 0), "head": (-0.2, 0, 0)},
             {"lean": (0.75, 0, 0.12), "root": (0, -3, 0), "ra": (0.2, 0, 1.1), "la": (0.2, 0, -1.1), "rl": (-0.45, 0, 0), "ll": (0.35, 0, 0), "head": (-0.35, 0, 0)}],
    "twist": [{"ra": (-1.45, 0.35, 0.15), "la": (-1.45, -0.35, -0.15), "head": (0.1, 0, 0)},
              {"ra": (-1.65, -0.25, 0.55), "la": (-1.3, 0.3, -0.55), "head": (0.12, 0, 0.1), "lean": (0, 0.12, 0)},
              {"ra": (-1.3, 0.3, -0.25), "la": (-1.65, -0.25, 0.25), "head": (0.12, 0, -0.1), "lean": (0, -0.12, 0)}],
    "lift": [{"ra": (-2.55, 0, 0.12), "la": (0.1, 0, -0.1), "head": (-0.25, 0, 0)},
             {"ra": (-2.65, 0, 0.15), "la": (0.15, 0, -0.12), "head": (-0.3, 0, 0.05), "root": (0, 0.5, 0)}],
    "donut_wind": [{"ra": (0.5, 0, 0.25), "la": (-0.9, 0, -0.2), "lean": (0.05, 0.35, 0), "rl": (-0.25, 0, 0), "ll": (0.3, 0, 0), "head": (0.1, -0.3, 0)},
                   {"ra": (1.0, 0, 0.3), "la": (-1.2, 0, -0.25), "lean": (0.1, 0.6, 0), "rl": (-0.35, 0, 0), "ll": (0.4, 0, 0), "head": (0.15, -0.5, 0), "root": (0, -1, 0)}],
    "donut": [{"ra": (-1.57, 0, 0), "la": (0.45, 0, -0.3), "lean": (-0.3, -0.25, 0), "rl": (-0.7, 0, 0), "ll": (0.6, 0, 0), "root": (0, -1, 0), "head": (0.05, 0.2, 0)},
              {"ra": (-1.57, 0, 0.02), "la": (0.5, 0, -0.32), "lean": (-0.38, -0.3, 0), "rl": (-0.8, 0, 0), "ll": (0.7, 0, 0), "root": (0, -1.5, 0), "head": (0.1, 0.25, 0)}],
    "donut_hold": [{"ra": (-1.57, 0, 0), "la": (0.4, 0, -0.2), "lean": (-0.25, -0.2, 0), "rl": (-0.6, 0, 0), "ll": (0.55, 0, 0), "root": (0, -1, 0), "head": (-0.25, 0.1, 0)},
                   {"ra": (-1.55, 0, 0.03), "la": (0.45, 0, -0.25), "lean": (-0.22, -0.18, 0), "rl": (-0.6, 0, 0), "ll": (0.55, 0, 0), "root": (0, -0.6, 0), "head": (-0.35, 0.1, 0.05)}],
    "pull_out": [{"ra": (-1.2, 0, 0.1), "la": (0.3, 0, -0.2), "lean": (0.05, 0.1, 0), "head": (-0.15, 0, 0)},
                 {"ra": (-0.3, 0, 0.3), "la": (0.1, 0, -0.15), "lean": (0.1, 0.05, 0), "head": (-0.25, 0, 0.1)}],
    # Steve
    "pierced": [{"lean": (0.18, 0, 0), "head": (-0.5, 0, 0), "ra": (-0.5, 0, 0.55), "la": (-0.5, 0, -0.55), "rl": (-0.1, 0, 0), "ll": (0.1, 0, 0)},
                {"lean": (0.26, 0, 0.03), "head": (-0.6, 0, 0.05), "ra": (-0.35, 0, 0.75), "la": (-0.35, 0, -0.7), "rl": (-0.12, 0, 0), "ll": (0.1, 0, 0)}],
    "sag": [{"lean": (-0.25, 0, 0), "head": (0.55, 0, 0), "ra": (0.15, 0, 0.1), "la": (0.15, 0, -0.1), "root": (0, -1, 0)},
            {"lean": (-0.4, 0, 0.05), "head": (0.7, 0, 0.05), "ra": (0.2, 0, 0.05), "la": (0.2, 0, -0.05), "root": (0, -2.5, 0), "rl": (-0.4, 0, 0), "ll": (0.3, 0, 0)}],
    "parry": [{"ra": (-0.5, 0.3, 0.2), "la": (-1.0, -0.2, -0.3), "lean": (0, 0.3, 0), "rl": (-0.3, 0, 0), "ll": (0.3, 0, 0)},
              {"ra": (-2.0, -0.6, 0.9), "la": (-0.9, 0, -0.3), "lean": (0.05, -0.35, 0), "rl": (-0.4, 0, 0), "ll": (0.4, 0, 0), "head": (0, -0.25, 0)},
              {"ra": (-1.7, -0.9, 1.2), "la": (-0.7, 0, -0.3), "lean": (0.12, -0.45, 0), "rl": (-0.35, 0, 0), "ll": (0.35, 0, 0), "head": (-0.05, -0.3, 0)}],
}
COUNTS = {"wave": 6, "laugh": 2, "shrug": 2, "sway": 3, "twist": 6, "lift": 2, "donut_wind": 3, "donut": 2, "donut_hold": 2,
          "pull_out": 3, "pierced": 2, "sag": 3, "parry": 4}
HEROBRINE = ["idle", "walk", "stroll", "wave", "laugh", "shrug", "dodge_l", "dodge_r", "sway", "cast", "snap", "point",
             "invite", "knocked", "stagger", "twist", "lift", "donut_wind", "donut", "donut_hold", "pull_out", "aura"]
STEVE = ["idle", "walk", "parry", "knocked", "guard", "pierced", "sag"]


def install():
    four.POSES.update(NEW_POSES)
    four.COUNTS.update(COUNTS)


def holed_steve(imp):
    """Steve's skin with a hole through the chest: front and back faces of the
    torso and the jacket are cut out, so the background shows through."""
    tex = imp.tex("entity/player/wide/steve").copy()
    px = tex.load()
    # Torso front face (20..28, 20..32) and back face (32..40, 20..32); jacket +16 rows.
    for base_x, mirror in [(20, False), (32, True)]:
        for base_y in [20, 36]:
            for y in range(12):
                for x in range(8):
                    cx, cy = (x - 3.5), (y - 3.6)
                    d = math.hypot(cx, cy * 0.95)
                    tx = base_x + (7 - x if mirror else x)
                    if d < 2.3:
                        px[tx, base_y + y] = (0, 0, 0, 0)
                    elif d < 3.2 and px[tx, base_y + y][3]:
                        px[tx, base_y + y] = (112 - int(d * 8), 10, 14, 255)
                    elif d < 4.2 and px[tx, base_y + y][3] and (x * 3 + y) % 4 == 0:
                        px[tx, base_y + y] = (90, 8, 12, 255)
    return tex


def villager_mesh(imp, twist, raise_arms, kick, creeper_mix):
    tex = imp.tex("entity/villager/villager")
    prof = imp.tex("entity/villager/type/plains")
    creeper = imp.tex("entity/creeper/creeper")
    if creeper_mix > 0:
        # The villager's own texels drift toward creeper green as he is wrung.
        blend = Image.blend(tex, Image.new("RGBA", tex.size, (60, 130, 50, 255)), creeper_mix * 0.7)
        blend.putalpha(tex.getchannel("A"))
        tex = blend
        prof = Image.blend(prof, Image.new("RGBA", prof.size, (60, 130, 50, 0)), creeper_mix)
    layers = [tex, prof]
    mesh = []
    for layer in layers:
        parts = []
        head = java_part(layer, (-4, -10, -4), (8, 10, 8), (0, 0))
        head += java_part(layer, (-1, -1, -6), (2, 4, 2), (24, 0), pivot=(0, -2, 0))
        parts.append((head, 30))
        parts.append((java_part(layer, (-4, 0, -3), (8, 12, 6), (16, 20)), 18))
        parts.append((java_part(layer, (-4, 0, -3), (8, 18, 6), (0, 38)), 12))
        for sign in [-1, 1]:
            arm = java_part(layer, (-2, -2, -2), (4, 8, 4), (44, 22), pivot=(sign * 6, 2, 0), angles=(-raise_arms * 2.6, 0, sign * (0.3 + raise_arms * 0.5)))
            parts.append((arm, 22))
            leg = java_part(layer, (-2, 0, -2), (4, 12, 4), (0, 22), pivot=(sign * 2, 12, 0), angles=(kick * sign, 0, -sign * 0.08))
            parts.append((leg, 4))
        for part, height in parts:
            # Each part turns about the vertical axis by its height: the body is wrung like cloth.
            angle = twist * (height - 14) / 16
            squeeze = 1 - 0.18 * min(1, abs(twist) / 3)
            mesh += transform(part, (0, angle, 0), pivot=(0, height, 0), scale=(squeeze, 1, squeeze))
    return mesh


def creeper_mesh(imp, untwist):
    tex = imp.tex("entity/creeper/creeper")
    parts = [(java_part(tex, (-4, -8, -4), (8, 8, 8), (0, 0), pivot=(0, 18, 0)), 22),
             (java_part(tex, (-4, 0, -2), (8, 12, 4), (16, 16), pivot=(0, 18, 0)), 12)]
    for x in [-2, 2]:
        for z in [-4, 4]:
            parts.append((java_part(tex, (-2, 0, -2), (4, 6, 4), (0, 16), pivot=(x, 6, z)), 3))
    mesh = []
    for part, height in parts:
        mesh += transform(part, (0, untwist * (height - 10) / 12, 0), pivot=(0, height, 0))
    return mesh


TWIST_FRAMES = 18
TWIST_SIZE = (48, 56)
CRAWL_FRAMES = 8
CRAWL_SIZE = (40, 32)


def legless(imp, twist, fold, legs_drop):
    """The wrung villager: legs torn away at the hips, body folding forward
    onto its arms. Built from chapter IV's crawler parts."""
    import bake_chapter_four_mobs as mobs
    body = villager_mesh(imp, twist, 1.0 - fold, 0.0, 0.0)
    tex = imp.tex("entity/villager/villager")
    upper = [face for face in body if np.mean(face[0][:, 1]) > 11.5]
    legs = [face for face in body if np.mean(face[0][:, 1]) <= 11.5]
    mesh = transform(upper, (fold * math.pi / 2, 0, 0), pivot=(0, 12, 0), offset=(0, -fold * 6, 0))
    mesh += mobs.flesh(imp, (-3, 10 - fold * 4, -2), (6, 2, 4))
    if legs_drop < 1.5:
        mesh += transform(legs, (0, 0, legs_drop * 0.5), pivot=(0, 0, 0), offset=(legs_drop * 6, -legs_drop * 2, 2))
    return mesh


def twist_strip(imp):
    out = Image.new("RGBA", (TWIST_SIZE[0] * TWIST_FRAMES, TWIST_SIZE[1]))
    for i in range(TWIST_FRAMES):
        if i < 4:
            mesh = villager_mesh(imp, 0.0, 0.5 + 0.5 * (i % 2), 0.5 * math.sin(i * 1.7), 0.0)
        elif i < 11:
            k = (i - 4) / 6
            mesh = villager_mesh(imp, k * k * 6.0, 1.0 - k * 0.4, 0.25 * math.sin(i * 2.1) * (1 - k), 0.0)
        elif i < 14:
            k = (i - 10) / 3
            mesh = legless(imp, 6.0 * (1 - k * 0.6), 0.0, k)
        else:
            k = (i - 13) / 4
            mesh = legless(imp, 2.4 * (1 - k), k, 2.0)
        out.paste(bake(mesh, TWIST_SIZE, four.SCALE, (24, 50), yaw=0, elevation=20), (i * TWIST_SIZE[0], 0))
    return out


def crawl_strip(imp):
    import bake_chapter_four_mobs as mobs
    yaws = [0, 180, -55]
    out = Image.new("RGBA", (CRAWL_SIZE[0] * CRAWL_FRAMES, CRAWL_SIZE[1] * 3))
    for r, yaw in enumerate(yaws):
        for i in range(CRAWL_FRAMES):
            out.paste(bake(mobs.crawler(imp, "walk", i, CRAWL_FRAMES), CRAWL_SIZE, four.SCALE, (20, 27), yaw=yaw, elevation=20), (i * CRAWL_SIZE[0], r * CRAWL_SIZE[1]))
    return out


def fence(imp):
    planks = imp.tex("block/oak_planks")
    faces = lambda: None
    post = box(planks, (-2, 0, -2), (4, 16, 4), (6, 0))
    post_img = bake(post, (12, 24), four.SCALE, (6, 21), yaw=0, elevation=20)
    rail = []
    for y in [6, 12]:
        rail += box(planks, (-16, y, -1), (32, 3, 2), (0, 2))
    rail_img = bake(rail, (32, 24), four.SCALE * 1.0, (16, 21), yaw=0, elevation=20)
    return post_img, rail_img


def sign(imp):
    tex = imp.tex("entity/signs/oak")
    board = tex.crop((2, 2, 26, 14))
    out = Image.new("RGBA", (26, 14), (0, 0, 0, 0))
    edge = tex.crop((0, 2, 2, 14)).resize((1, 12))
    out.paste(board, (1, 1))
    d = ImageDraw.Draw(out)
    d.rectangle((0, 0, 25, 13), outline=(58, 40, 22, 255))
    return out


def sounds(version):
    prism = Path.home() / ".local/share/PrismLauncher"
    meta = json.loads((prism / f"meta/net.minecraft/{version}.json").read_text())
    index = json.loads((prism / f"assets/indexes/{meta['assetIndex']['id']}.json").read_text())["objects"]

    def raw(name):
        digest = index["minecraft/" + name]["hash"]
        data = (prism / f"assets/objects/{digest[:2]}/{digest}").read_bytes()
        assert hashlib.sha1(data).hexdigest() == digest
        return data

    events = json.loads(raw("sounds.json"))
    mapping, manifest = {}, {}
    for ident, event, gain in [("ch1_villager_hurt", "entity.villager.hurt", .6), ("ch1_villager_no", "entity.villager.no", .6),
                               ("ch1_wood_place", "block.wood.place", .8), ("ch1_fence_grow", "block.fence_gate.close", .7),
                               ("ch1_step", "block.grass.step", .35), ("hurt_ch1_crawler", "entity.zombie_villager.hurt", .6),
                               ("ch1_parry", "item.trident.hit_ground", .9), ("ch1_whoosh", "entity.player.attack.sweep", .7)]:
        variants = []
        for spec in events[event]["sounds"]:
            spec = {"name": spec} if isinstance(spec, str) else spec
            name = spec["name"].replace("minecraft:", "")
            data = raw("sounds/" + name + ".ogg")
            filename = name.replace("/", "_") + ".ogg"
            (ROOT / "assets/audio/minecraft" / filename).write_bytes(data)
            variants.append(dict(path="res://assets/audio/minecraft/" + filename, volume=spec.get("volume", 1), pitch=spec.get("pitch", 1)))
            manifest[filename] = dict(source="minecraft/sounds/" + name + ".ogg", sha256=hashlib.sha256(data).hexdigest())
        mapping[ident] = dict(minecraft_event=event, gain=gain, variants=variants)
    (ROOT / "data/chapter_one_audio.json").write_text(json.dumps(mapping, indent=2) + "\n")
    return manifest


def generate():
    install()
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    sprites = []
    layout = {}
    for face in ["calm", "smile", "rage"]:
        image, layout = four.atlas(four.herobrine_skin(imp, face), HEROBRINE)
        imp.save(image, "ch1_hb_" + face, ["entity/player/wide/steve (white eyes, " + face + " mouth texels)"])
        sprites.append("ch1_hb_" + face)
    steve, steve_layout = four.atlas(imp.tex("entity/player/wide/steve"), STEVE)
    imp.save(steve, "ch1_steve", ["entity/player/wide/steve"])
    holed, _ = four.atlas(holed_steve(imp), STEVE)
    imp.save(holed, "ch1_steve_holed", ["entity/player/wide/steve (chest cut through)"])
    sprites += ["ch1_steve", "ch1_steve_holed"]
    imp.save(twist_strip(imp), "ch1_villager_twist", ["entity/villager/villager", "entity/villager/type/plains"])
    imp.save(crawl_strip(imp), "ch1_crawler", ["entity/villager/villager"])
    post, rail = fence(imp)
    imp.save(post, "ch1_fence_post", ["block/oak_planks"])
    imp.save(rail, "ch1_fence_rail", ["block/oak_planks"])
    imp.save(imp.tex("block/oak_planks"), "ch1_planks", ["block/oak_planks"])
    imp.save(imp.tex("block/dirt_path_top"), "ch1_path", ["block/dirt_path_top"])
    imp.save(sign(imp), "ch1_sign", ["entity/signs/oak"])
    sprites += ["ch1_villager_twist", "ch1_crawler", "ch1_fence_post", "ch1_fence_rail", "ch1_planks", "ch1_path", "ch1_sign"]
    data = {"sprites": sprites, "frame": list(four.FRAME), "anchor": list(four.CENTER), "herobrine": layout, "steve": steve_layout,
            "twist": {"frame": list(TWIST_SIZE), "anchor": [24, 50], "count": TWIST_FRAMES},
            "crawler": {"frame": list(CRAWL_SIZE), "anchor": [20, 27], "count": CRAWL_FRAMES}}
    (ROOT / "data/chapter_one_assets.json").write_text(json.dumps(data, indent=2) + "\n")
    audio = sounds(version)
    (ROOT / "docs/CHAPTER_ONE_MANIFEST.json").write_text(json.dumps({"version": version, "client_jar": str(client), "raw_files": imp.files, "derived": imp.derived, "sound_files": audio}, indent=2) + "\n")
    sheet = Image.new("RGBA", (900, 420), (30, 30, 30, 255))
    w, h = four.FRAME
    hb = Image.open(ROOT / "assets/sprites/ch1_hb_smile.png")
    for i, name in enumerate(["wave", "laugh", "sway", "twist", "lift", "donut_wind", "donut", "dodge_l", "pull_out"]):
        c = layout[name]["start"] + layout[name]["count"] // 2
        sheet.alpha_composite(hb.crop((c * w, 0, c * w + w, h)).resize((w * 2, h * 2), Image.NEAREST), (i * 98, 0))
    st = Image.open(ROOT / "assets/sprites/ch1_steve_holed.png")
    for i, name in enumerate(["parry", "pierced", "sag"]):
        c = steve_layout[name]["start"] + 1
        sheet.alpha_composite(st.crop((c * w, 0, c * w + w, h)).resize((w * 2, h * 2), Image.NEAREST), (i * 98, 120))
    tw = Image.open(ROOT / "assets/sprites/ch1_villager_twist.png")
    for i in range(0, TWIST_FRAMES, 2):
        sheet.alpha_composite(tw.crop((i * 48, 0, i * 48 + 48, 56)).resize((96, 112), Image.NEAREST), (i // 2 * 98, 240))
    sheet.alpha_composite(post.resize((24, 48), Image.NEAREST), (320, 130))
    sheet.alpha_composite(rail.resize((64, 48), Image.NEAREST), (350, 130))
    sheet.alpha_composite(Image.open(ROOT / "assets/sprites/ch1_sign.png").resize((104, 56), Image.NEAREST), (430, 130))
    sheet.save(ROOT / "qa/chapter_one_poses.png")
    print("CH1_BAKE", sprites)


if __name__ == "__main__":
    generate()
