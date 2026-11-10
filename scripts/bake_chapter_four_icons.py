#!/usr/bin/env python3
"""Chapter IV inventory icons in the vanilla item style, drawn as original art.

Each icon is an original 16x16 silhouette with four-tone shading (light from
the top left) and a darker outline of its own hue, like vanilla items. Every
material then takes the per-pixel grain of the matching vanilla texture, so the
surfaces carry the same noise as Minecraft's own items instead of flat fills.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from import_minecraft_assets import ROOT, Importer, find_client

CLEAR = (0, 0, 0, 0)


def ramp(texture, lo=0.0, hi=1.0, n=4):
    """Four tones from a vanilla texture, darkest to lightest."""
    px = [p for p in texture.convert("RGBA").get_flattened_data() if p[3] > 60]
    px.sort(key=lambda c: c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11)
    return [px[int((lo + (hi - lo) * i / (n - 1)) * (len(px) - 1))][:3] + (255,) for i in range(n)]


class Icon:
    """Draws colour and, in parallel, which vanilla texture lends its grain."""

    def __init__(self):
        self.im = Image.new("RGBA", (16, 16))
        self.mat = Image.new("L", (16, 16))
        self.d = ImageDraw.Draw(self.im)
        self.m = ImageDraw.Draw(self.mat)

    def _px(self, pts, c, mat):
        for x, y in pts:
            if 0 <= x < 16 and 0 <= y < 16:
                self.im.putpixel((x, y), c)
                self.mat.putpixel((x, y), mat)

    def px(self, pts, c, mat=0):self._px(pts, c, mat)

    def line(self, a, b, c, w=1, mat=0):
        self.d.line([a, b], fill=c, width=w);self.m.line([a, b], fill=mat, width=w)

    def rect(self, a, b, c, mat=0):
        self.d.rectangle([a, b], fill=c);self.m.rectangle([a, b], fill=mat)

    def ellipse(self, a, b, c, mat=0):
        self.d.ellipse([a, b], fill=c);self.m.ellipse([a, b], fill=mat)

    def poly(self, pts, c, mat=0):
        self.d.polygon(pts, fill=c);self.m.polygon(pts, fill=mat)

    def finish(self, grains, strength=0.28):
        a = np.asarray(self.im).astype(float)
        mat = np.asarray(self.mat)
        for index, tex in grains.items():
            g = np.asarray(tex.convert("L").resize((16, 16), Image.NEAREST)).astype(float)
            g = g / max(1.0, g[g > 0].mean() if (g > 0).any() else 1.0)
            sel = (mat == index) & (a[..., 3] > 0)
            a[sel, :3] *= (1 + (g[sel, None] - 1) * strength)
        self.im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
        src = self.im.copy()
        for y in range(16):
            for x in range(16):
                if src.getpixel((x, y))[3]:continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    qx, qy = x + dx, y + dy
                    if 0 <= qx < 16 and 0 <= qy < 16 and src.getpixel((qx, qy))[3] > 200:
                        q = src.getpixel((qx, qy))
                        self.im.putpixel((x, y), (int(q[0] * .3), int(q[1] * .3), int(q[2] * .3), 255));break
        return self.im


WOOD, IRON, BONE, GLOW, WAX, GLASS, VINE, BLOOD, FLESH = range(1, 10)


def shotgun(t, evo=False):
    i = Icon();wood, iron = t["wood"], t["gun"]
    i.poly([(1, 15), (0, 13), (4, 9), (7, 11), (3, 15)], wood[1], WOOD)
    i.line((1, 13), (4, 10), wood[2], 1, WOOD);i.line((0, 13), (3, 10), wood[3], 1, WOOD)
    i.rect((5, 8), (8, 11), iron[0], IRON);i.px([(6, 12), (7, 13), (8, 12)], iron[1], IRON)
    i.line((7, 9), (15, 1), iron[1], 2, IRON);i.line((7, 8), (14, 1), iron[2], 1, IRON)
    if evo:
        i.line((8, 10), (15, 3), iron[0], 2, IRON);i.line((9, 10), (15, 4), iron[2], 1, IRON)
        i.px([(10, 7), (11, 6), (11, 7), (12, 6)], t["gold"], IRON)
    i.line((9, 8), (11, 6), wood[1], 2, WOOD);i.px([(9, 7), (10, 6)], wood[3], WOOD)
    return i.finish({WOOD: t["wood_tex"], IRON: t["iron_tex"]})


def bone_saw(t, evo=False):
    i = Icon();bone, wood = t["bone"], t["wood"]
    i.poly([(3, 9), (13, 1), (15, 2), (15, 4), (6, 12)], bone[2], BONE)
    i.line((4, 9), (13, 2), bone[3], 1, BONE)
    for x in range(6, 16, 2):
        y = round(12 - (x - 6) * 8 / 9)
        i.px([(x, y + 1)], bone[1], BONE);i.px([(x + 1, y + 1)], CLEAR, BONE)
    i.rect((2, 9), (4, 11), bone[1], BONE)
    i.line((0, 15), (3, 12), wood[1], 2, WOOD);i.px([(1, 13), (2, 12)], wood[3], WOOD)
    if evo:
        i.px([(9, 6), (10, 6), (10, 5), (12, 4), (8, 8), (7, 9), (11, 7), (8, 10)], t["blood"][1], BLOOD)
        i.px([(9, 7), (12, 5)], t["blood"][2], BLOOD)
    return i.finish({BONE: t["bone_tex"], WOOD: t["wood_tex"], BLOOD: t["blood_tex"]})


def red_torch(t, evo=False):
    i = Icon();wood, glow = t["stick"], t["glow"]

    def torch(x, top):
        i.rect((x, top + 3), (x + 1, 15), wood[1], WOOD);i.line((x, top + 3), (x, 15), wood[2], 1, WOOD)
        i.rect((x - 1, top), (x + 2, top + 2), glow[1], GLOW);i.px([(x, top), (x + 1, top + 1)], glow[3], GLOW)

    if evo:
        torch(3, 6);torch(11, 4)
        i.px([(5, 7), (6, 6), (7, 7), (8, 5), (9, 6), (10, 5)], glow[2], GLOW)
    else:
        torch(7, 4)
    return i.finish({WOOD: t["wood_tex"], GLOW: t["glow_tex"]})


def black_candle(t):
    i = Icon();wax = t["wax"]
    i.rect((6, 7), (9, 15), wax[1], WAX);i.line((6, 7), (6, 15), wax[2], 1, WAX);i.line((9, 8), (9, 15), wax[0], 1, WAX)
    i.px([(7, 7), (8, 7)], wax[3], WAX);i.px([(10, 8), (10, 9), (5, 9), (5, 10), (5, 11)], wax[2], WAX)
    i.px([(7, 5), (7, 6)], (40, 34, 30, 255))
    i.px([(7, 3), (8, 4), (6, 4)], (232, 150, 50, 255));i.px([(7, 4)], (250, 214, 120, 255));i.px([(7, 2)], (214, 110, 40, 255))
    return i.finish({WAX: t["wax_tex"]})


def mirror_shard(t):
    i = Icon();g = t["glass"]
    i.poly([(3, 15), (2, 6), (7, 0), (9, 4), (13, 2), (12, 9), (8, 15)], g[1], GLASS)
    i.line((3, 14), (2, 6), g[3], 1, GLASS);i.line((2, 6), (7, 0), g[3], 1, GLASS)
    i.line((5, 12), (10, 5), g[3], 1, GLASS)
    i.px([(3, 9), (4, 10), (5, 10), (6, 11), (7, 11)], g[0], GLASS)
    i.px([(6, 9), (7, 9), (8, 8)], g[2], GLASS)
    i.px([(9, 6)], (150, 20, 24, 255), GLASS)
    return i.finish({GLASS: t["glass_tex"]})


def thorns(t):
    i = Icon();v, tip = t["vine"], t["tip"]
    i.ellipse((2, 2), (13, 13), v[1], VINE);i.ellipse((5, 5), (10, 10), CLEAR, VINE)
    i.d.arc((2, 2, 13, 13), 200, 320, fill=v[3]);i.d.arc((3, 3, 12, 12), 20, 140, fill=v[0])
    for (x, y) in [(7, 0), (14, 4), (15, 9), (11, 14), (4, 15), (0, 10), (1, 4)]:i.px([(x, y)], tip[0], BONE)
    for (x, y) in [(7, 1), (13, 4), (14, 9), (11, 13), (4, 14), (1, 10), (2, 4)]:i.px([(x, y)], tip[1], BONE)
    i.px([(7, 0), (15, 9)], t["blood"][1], BLOOD)
    return i.finish({VINE: t["vine_tex"], BONE: t["bone_tex"]})


def blood_pool(t, evo=False):
    i = Icon();b, bone = t["blood"], t["bone"]
    i.ellipse((0, 8), (15, 14), b[1], BLOOD);i.ellipse((2, 9), (12, 12), b[2], BLOOD);i.ellipse((4, 10), (9, 12), b[0], BLOOD)
    i.line((3, 9), (7, 9), b[3], 1, BLOOD)
    if evo:
        for x, h in [(4, 5), (8, 7), (11, 4)]:
            i.line((x, 10), (x, 10 - h), bone[2], 1, BONE);i.px([(x, 10 - h)], bone[3], BONE);i.px([(x + 1, 9)], bone[0], BONE)
    else:
        i.px([(7, 4), (7, 5), (6, 6), (7, 6), (8, 6)], b[1], BLOOD)
    return i.finish({BLOOD: t["blood_tex"], BONE: t["bone_tex"]})


def embryo(t, evo=False):
    i = Icon();f, v = t["flesh"], t["blood"]
    i.ellipse((3, 2), (11, 10), f[2], FLESH);i.ellipse((5, 7), (13, 14), f[1], FLESH);i.ellipse((7, 9), (10, 12), f[0], FLESH)
    i.px([(4, 4), (5, 3), (6, 3)], f[3], FLESH)
    i.ellipse((5, 4), (7, 6), (34, 12, 16, 255), FLESH);i.px([(5, 4)], (150, 140, 140, 255), FLESH)
    i.px([(9, 3), (10, 5), (11, 9), (12, 11)], v[1], FLESH);i.px([(3, 13), (2, 14), (1, 15), (4, 12)], v[0], FLESH)
    if evo:
        i.px([(8, 9), (9, 9), (10, 9)], (210, 204, 190, 255), FLESH);i.px([(9, 10)], (40, 6, 10, 255), FLESH)
        i.px([(12, 6), (13, 7), (2, 6)], v[1], FLESH)
    return i.finish({FLESH: t["flesh_tex"]})


def generate():
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    b = lambda n: imp.tex("block/" + n)
    tex = {"wood_tex": b("dark_oak_planks"), "iron_tex": b("iron_block"), "bone_tex": b("bone_block_side"),
           "glow_tex": b("redstone_block"), "wax_tex": b("black_wool"), "glass_tex": b("glass"),
           "vine_tex": b("dark_oak_log"), "blood_tex": b("red_concrete_powder"), "flesh_tex": b("nether_wart_block")}
    t = dict(tex)
    t.update(wood=ramp(b("dark_oak_planks")), gun=[(46, 46, 52, 255), (72, 72, 80, 255), (104, 104, 112, 255), (140, 140, 148, 255)],
             gold=(196, 160, 60, 255), bone=ramp(b("bone_block_side"), .1, .95), stick=ramp(b("oak_planks"), .1, .8),
             glow=ramp(b("redstone_block"), .2, 1.0), wax=ramp(b("black_wool")), glass=[(120, 136, 148, 255), (168, 184, 194, 255), (196, 210, 216, 255), (230, 238, 240, 255)],
             vine=ramp(b("dark_oak_log")), tip=ramp(b("bone_block_side"), .5, 1.0)[2:],
             blood=[(70, 4, 10, 255), (106, 10, 16, 255), (138, 18, 24, 255), (176, 52, 54, 255)],
             flesh=[(130, 62, 64, 255), (164, 86, 86, 255), (190, 116, 112, 255), (214, 156, 148, 255)])
    icons = {"shotgun": shotgun(t), "shotgun_evo": shotgun(t, True), "bone_saw": bone_saw(t), "bone_saw_evo": bone_saw(t, True),
             "red_torch": red_torch(t), "red_torch_evo": red_torch(t, True), "black_candle": black_candle(t),
             "mirror_shard": mirror_shard(t), "thorns": thorns(t), "blood_pool": blood_pool(t), "blood_pool_evo": blood_pool(t, True),
             "embryo": embryo(t), "embryo_evo": embryo(t, True)}
    sources = ["block/" + n for n in ["dark_oak_planks", "iron_block", "bone_block_side", "redstone_block", "black_wool", "glass",
                                      "dark_oak_log", "red_concrete_powder", "nether_wart_block", "oak_planks"]]
    for name, icon in icons.items():
        imp.save(icon, "icon_ch4_" + name, sources, "Original 16x16 icon in vanilla style; grain and palette from vanilla textures.")
    path = ROOT / "docs/CHAPTER_FOUR_FX_MANIFEST.json"
    manifest = json.loads(path.read_text()) if path.exists() else {}
    manifest.setdefault("raw_files", {}).update(imp.files);manifest.setdefault("derived", {}).update(imp.derived)
    path.write_text(json.dumps(manifest, indent=2) + "\n")
    print("ICONS", len(icons))


if __name__ == "__main__":
    generate()
