"""Chapter V ending: textures for the other games' dioramas and for 2Fort.

Everything here is painted procedurally (noise, brush strokes, pixel tiles)
so the worlds past the door read in their own styles instead of as bare
shapes: a hand-painted, warm TF2 palette for 2Fort, glass towers at sunset
for Los Santos, RPG Maker screens for Black Souls and Fear & Hunger, and so on.
Run: python3 scripts/bake_chapter_five_worlds.py
"""
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites"
NAMES = []


def save(im, name):
    im.save(OUT / (name + ".png"))
    NAMES.append(name)


def noise(w, h, cell, seed, octaves=3):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        c = max(1, cell >> o)
        grid = rng.random((h // c + 2, w // c + 2))
        im = Image.fromarray((grid * 255).astype(np.uint8)).resize(((w // c + 2) * c, (h // c + 2) * c), Image.BICUBIC)
        out += np.asarray(im, dtype=float)[:h, :w] / 255 * amp
        total += amp
        amp *= .5
    return out / total


def tint(n, dark, light):
    d, l = np.array(dark, float), np.array(light, float)
    return d + (l - d) * n[..., None]


def to_img(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")


def strokes(im, count, palette, length, width, seed, vertical=None, alpha=70):
    rng = random.Random(seed)
    layer = Image.new("RGBA", im.size)
    d = ImageDraw.Draw(layer)
    w, h = im.size
    for _ in range(count):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        ang = (math.pi / 2 if vertical else 0.0) + rng.uniform(-.35, .35) if vertical is not None else rng.uniform(0, math.pi)
        ln = rng.uniform(length * .5, length)
        c = rng.choice(palette)
        d.line([(x, y), (x + math.cos(ang) * ln, y + math.sin(ang) * ln)], fill=c + (rng.randint(alpha // 2, alpha),), width=rng.randint(max(1, width // 2), width))
    layer = layer.filter(ImageFilter.GaussianBlur(.6))
    base = im.convert("RGBA")
    base.alpha_composite(layer)
    return base.convert("RGB")


def font(size):
    for path in ["/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size=size)


# ------------------------------------------------------------------ TF2 2Fort

def planks(base, seed, w=128, h=128, n=6):
    rng = random.Random(seed)
    a = np.zeros((h, w, 3))
    pw = w // n
    for i in range(n):
        shade = rng.uniform(.82, 1.12)
        grain = noise(pw, h, 16, seed + i, 3)
        streak = np.asarray(Image.fromarray((noise(pw, h * 4, 4, seed + 50 + i, 2) * 255).astype(np.uint8)).resize((pw, h)), float) / 255
        col = tint(grain * .6 + streak * .4, [c * .62 * shade for c in base], [min(255, c * 1.18 * shade) for c in base])
        a[:, i * pw:(i + 1) * pw] = col
        a[:, i * pw] *= .45
        a[:, i * pw + 1] *= .8
    grad = np.linspace(1.08, .78, h)[:, None, None]
    im = to_img(a * grad)
    im = strokes(im, 220, [tuple(min(255, int(c * 1.25)) for c in base), tuple(int(c * .6) for c in base)], 30, 3, seed + 9, vertical=True, alpha=60)
    d = ImageDraw.Draw(im)
    for i in range(n):
        for y in [10, h - 14]:
            d.ellipse([i * pw + pw // 2 - 2, y - 2, i * pw + pw // 2 + 2, y + 2], fill=(40, 30, 25))
    return im


def tf2():
    save(planks((158, 60, 44), 1), "ch5w_tf2_red_wood")
    save(planks((82, 104, 128), 2), "ch5w_tf2_blu_wood")
    n = noise(128, 128, 32, 3)
    im = to_img(tint(n, (138, 126, 104), (192, 180, 152)))
    im = strokes(im, 260, [(206, 194, 168), (120, 108, 90), (176, 160, 130)], 26, 4, 4, alpha=50)
    d = ImageDraw.Draw(im)
    for y in [0, 64]:
        d.line([(0, y), (128, y)], fill=(100, 90, 74), width=2)
    for x in [0, 64]:
        d.line([(x, 0), (x, 128)], fill=(112, 100, 84), width=1)
    save(im, "ch5w_tf2_concrete")
    x = np.arange(128)
    wave = (np.sin(x / 128 * math.pi * 16) * .5 + .5)[None, :]
    rust = noise(128, 128, 24, 5)
    a = tint(wave * .7 + rust * .3, (108, 62, 40), (196, 124, 82))
    a = a * (1 - rust[..., None] * .25) + np.array([60, 25, 5]) * rust[..., None] * .35
    im = strokes(to_img(a), 90, [(170, 100, 60), (60, 50, 45)], 18, 3, 6, vertical=True, alpha=60)
    save(im, "ch5w_tf2_roof")
    n = noise(128, 128, 32, 7)
    im = to_img(tint(n, (150, 118, 78), (196, 164, 116)))
    im = strokes(im, 320, [(210, 180, 130), (130, 100, 64), (176, 140, 92)], 14, 3, 8, alpha=55)
    d = ImageDraw.Draw(im)
    rng = random.Random(9)
    for _ in range(40):
        px, py = rng.randint(0, 127), rng.randint(0, 127)
        d.ellipse([px, py, px + rng.randint(2, 4), py + rng.randint(1, 3)], fill=(120, 100, 76))
    save(im, "ch5w_tf2_ground")
    y = np.arange(128)[:, None]
    bands = (np.sin(y / 128 * math.pi * 7 + noise(128, 128, 32, 10) * 4) * .5 + .5)
    a = tint(bands * .6 + noise(128, 128, 16, 11) * .4, (112, 84, 60), (184, 150, 112))
    im = strokes(to_img(a), 260, [(200, 170, 130), (96, 72, 52)], 34, 4, 12, vertical=False, alpha=55)
    save(im, "ch5w_tf2_rock")
    n = noise(128, 128, 16, 13)
    ripple = (np.sin(np.arange(128)[:, None] / 5.0 + n * 6) * .5 + .5)
    im = to_img(tint(ripple * .5 + n * .5, (34, 82, 80), (92, 150, 138)))
    im = strokes(im, 140, [(150, 200, 190), (40, 90, 88)], 20, 2, 14, vertical=False, alpha=70)
    save(im, "ch5w_tf2_water")
    w, h = 512, 256
    t = np.linspace(0, 1, h)[:, None]
    tt = np.clip(t * 2.0, 0, 1)
    sky = np.array([60, 132, 210]) * (1 - tt[..., None]) + np.array([150, 196, 230]) * tt[..., None]
    sky = np.repeat(sky, w, axis=1)
    cloud = noise(w, h, 64, 15, 4)
    cloud = np.clip((cloud - .55) * 3.2, 0, 1) * (1 - t) ** .5
    sky = sky * (1 - cloud[..., None] * .7) + np.array([248, 240, 222]) * cloud[..., None] * .7
    im = strokes(to_img(sky), 500, [(250, 244, 230), (180, 200, 214)], 60, 6, 16, vertical=False, alpha=30)
    save(im, "ch5w_tf2_sky")
    for team, col, dark in [("red", (180, 52, 40), (110, 30, 24)), ("blu", (70, 104, 140), (40, 60, 84))]:
        im = Image.new("RGB", (256, 96), col)
        im = strokes(im, 200, [tuple(min(255, int(c * 1.2)) for c in col), dark], 40, 5, 17 if team == "red" else 18, vertical=False, alpha=50)
        d = ImageDraw.Draw(im)
        d.rectangle([4, 4, 251, 91], outline=(236, 226, 200), width=4)
        f = font(56)
        label = {"red": "WEST", "blu": "EAST"}[team]
        bw = d.textlength(label, font=f)
        d.text(((256 - bw) / 2 + 3, 15), label, font=f, fill=dark)
        d.text(((256 - bw) / 2, 12), label, font=f, fill=(240, 232, 210))
        save(im, "ch5w_tf2_sign_" + team)
    save(planks((138, 118, 96), 19, n=5), "ch5w_tf2_bridge")
    save(planks((176, 92, 62), 21, n=8), "ch5w_tf2_red_siding")
    fence = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fence)
    for k in range(-64, 128, 12):
        fd.line([(k, 0), (k + 64, 64)], fill=(150, 154, 156, 255), width=1)
        fd.line([(k + 64, 0), (k, 64)], fill=(130, 134, 136, 255), width=1)
    fence.save(OUT / "ch5w_tf2_fence.png");NAMES.append("ch5w_tf2_fence")
    n = noise(128, 128, 8, 22)
    im = to_img(tint(n, (150, 120, 84), (200, 170, 124)))
    d = ImageDraw.Draw(im)
    rng = random.Random(23)
    for y in range(0, 128, 9):
        for x in range((y // 9) % 2 * 5, 128, 10):
            c = rng.randint(130, 175)
            d.polygon([(x + 1, y + 2), (x + 8, y + 1), (x + 9, y + 7), (x + 2, y + 8)], fill=(c, int(c * .82), int(c * .58)), outline=(110, 88, 60))
    save(strokes(im, 200, [(210, 180, 136), (120, 96, 66)], 18, 4, 24, alpha=40), "ch5w_tf2_cobble")
    im = Image.new("RGB", (64, 64), (52, 44, 40))
    d = ImageDraw.Draw(im)
    d.rectangle([6, 6, 57, 57], fill=(36, 52, 58))
    d.line([(32, 6), (32, 57)], fill=(80, 64, 52), width=4)
    d.line([(6, 32), (57, 32)], fill=(80, 64, 52), width=4)
    d.polygon([(10, 10), (26, 10), (10, 26)], fill=(90, 120, 126))
    save(im, "ch5w_tf2_window")


def tf2_signs():
    im = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([8, 8, 248, 248], fill=(238, 228, 204), outline=(120, 50, 36), width=10)
    d.ellipse([30, 30, 226, 226], outline=(150, 64, 44), width=4)
    f = font(34)
    for txt, y in [("SUNNY", 70), ("ACRES", 150)]:
        w = d.textlength(txt, font=f);d.text(((256 - w) / 2, y), txt, font=f, fill=(150, 56, 40))
    d.polygon([(128, 112), (150, 140), (106, 140)], fill=(96, 130, 60))
    im.save(OUT / "ch5w_tf2_happy.png");NAMES.append("ch5w_tf2_happy")
    for name, txt, bg, fg, size in [("watch", "MIND THE GAP", (226, 190, 60), (60, 40, 20), (256, 64)), ("coldwell", "GRAIN CO.", (176, 70, 50), (240, 230, 210), (256, 64)),
                                   ("loading", "LOADING DELIVERIES", (190, 60, 46), (240, 230, 210), (256, 64)), ("two", "5", (0, 0, 0), (236, 226, 200), (64, 64))]:
        im = Image.new("RGBA", size, bg + (255,) if name != "two" else (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        f = font(26 if size[0] > 64 else 54)
        w = d.textlength(txt, font=f)
        if name != "two":d.rectangle([2, 2, size[0] - 3, size[1] - 3], outline=fg, width=3)
        d.text(((size[0] - w) / 2, (size[1] - (30 if size[0] > 64 else 60)) / 2), txt, font=f, fill=fg)
        im.save(OUT / ("ch5w_tf2_" + name + ".png"));NAMES.append("ch5w_tf2_" + name)
    x = np.arange(128)
    wave = (np.sin(x / 128 * math.pi * 12) * .5 + .5)[None, :]
    a = tint(wave * .6 + noise(128, 128, 24, 25) * .4, (186, 186, 180), (240, 238, 230))
    save(strokes(to_img(a), 120, [(250, 250, 244), (150, 146, 136)], 20, 3, 26, vertical=True, alpha=50), "ch5w_tf2_white_metal")
    a = to_img(tint(noise(128, 128, 32, 27), (70, 96, 104), (110, 140, 146)))
    a = strokes(a, 220, [(130, 160, 166), (56, 80, 88)], 30, 4, 28, alpha=50)
    d = ImageDraw.Draw(a)
    for y in range(0, 128, 32):d.line([(0, y), (128, y)], fill=(60, 82, 90), width=2)
    save(a, "ch5w_tf2_blu_concrete")
    im = Image.new("RGB", (128, 128), (232, 230, 220))
    d = ImageDraw.Draw(im)
    d.rectangle([8, 8, 119, 119], outline=(40, 60, 90), width=6)
    f = font(84);w = d.textlength("E", font=f);d.text(((128 - w) / 2, 8), "E", font=f, fill=(40, 70, 110))
    save(im, "ch5w_tf2_blu_logo")


# ------------------------------------------------------------------ GTA V

def gta():
    w, h = 128, 256
    t = np.linspace(0, 1, h)[:, None, None]
    refl = np.array([255, 150, 90]) * (1 - t) + np.array([60, 90, 140]) * t
    a = np.repeat(refl, w, axis=1) * (.7 + noise(w, h, 32, 20)[..., None] * .4)
    for x in range(0, w, 8):
        a[:, x] *= .35
    for y in range(0, h, 10):
        a[y] *= .4
    save(to_img(a), "ch5w_gta_glass")
    a = np.zeros((128, 128, 3)) + np.array([196, 186, 168])
    a *= (.85 + noise(128, 128, 16, 21)[..., None] * .2)
    rng = random.Random(22)
    for y in range(6, 128, 14):
        for x in range(4, 128, 12):
            lit = rng.random() < .35
            a[y:y + 8, x:x + 8] = (255, 214, 140) if lit else (60, 80, 100)
    save(to_img(a), "ch5w_gta_office")
    a = to_img(tint(noise(128, 128, 8, 23), (44, 44, 48), (78, 78, 84)))
    d = ImageDraw.Draw(a)
    for y in range(0, 128, 32):
        d.rectangle([60, y, 67, y + 18], fill=(230, 196, 60))
    d.rectangle([0, 0, 4, 128], fill=(220, 220, 220))
    d.rectangle([123, 0, 127, 128], fill=(220, 220, 220))
    save(a, "ch5w_gta_road")
    im = Image.new("RGBA", (64, 128))
    d = ImageDraw.Draw(im)
    for k in range(10):
        d.line([(31 + math.sin(k) * 1, 127 - k * 10), (32 + math.sin(k + 1), 117 - k * 10)], fill=(110, 84, 56, 255), width=5)
    for k in range(9):
        ang = k / 9 * math.pi * 2
        for s in range(22):
            px = 32 + math.cos(ang) * s * 1.3
            py = 26 + math.sin(ang) * s * .45 + (s / 22) ** 2 * 18
            d.ellipse([px - 3, py - 2, px + 3, py + 2], fill=(46 + s * 2, 110 + s * 2, 50, 255))
    save(im, "ch5w_gta_palm")
    w, h = 256, 128
    t = np.linspace(0, 1, h)[:, None, None]
    sky = np.array([70, 50, 120]) * (1 - t) ** 1.4 + np.array([255, 140, 70]) * (1 - (1 - t) ** 1.4)
    save(to_img(np.repeat(sky, w, axis=1)), "ch5w_gta_sky")


# ------------------------------------------------------------------ Spore

def spore():
    n = noise(128, 128, 24, 30)
    im = to_img(tint(n, (120, 50, 140), (210, 120, 200)))
    d = ImageDraw.Draw(im)
    rng = random.Random(31)
    for _ in range(60):
        x, y, r = rng.randint(0, 127), rng.randint(0, 127), rng.randint(1, 4)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(250, 200, 240))
    save(im, "ch5w_spore_ground")
    n = noise(64, 64, 16, 32)
    im = to_img(tint(n, (230, 120, 30), (255, 190, 80)))
    d = ImageDraw.Draw(im)
    for _ in range(18):
        x, y, r = rng.randint(0, 63), rng.randint(0, 63), rng.randint(2, 6)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(130, 50, 140))
    save(im, "ch5w_spore_skin")


# ------------------------------------------------------------------ Dota 2

def dota():
    im = to_img(tint(noise(128, 128, 24, 40), (52, 96, 40), (120, 160, 70)))
    save(strokes(im, 300, [(150, 190, 90), (40, 80, 30)], 12, 3, 41, alpha=60), "ch5w_dota_grass")
    n = noise(128, 128, 24, 42)
    im = to_img(tint(n, (54, 30, 28), (110, 60, 46)))
    d = ImageDraw.Draw(im)
    rng = random.Random(43)
    for _ in range(14):
        x, y = rng.randint(0, 127), rng.randint(0, 127)
        pts = [(x, y)]
        for k in range(5):
            x += rng.randint(-14, 14);y += rng.randint(-14, 14);pts.append((x, y))
        d.line(pts, fill=(255, 120, 30), width=2)
    save(im.filter(ImageFilter.SMOOTH), "ch5w_dota_dire")
    n = noise(128, 128, 16, 44)
    im = to_img(tint(np.sin(np.arange(128)[None, :] / 6 + n * 5) * .25 + .5 + n * .25, (30, 70, 120), (90, 160, 200)))
    save(im, "ch5w_dota_river")
    a = to_img(tint(noise(64, 64, 16, 45), (110, 110, 104), (170, 168, 158)))
    d = ImageDraw.Draw(a)
    for y in range(0, 64, 16):
        d.line([(0, y), (64, y)], fill=(80, 80, 76), width=2)
        for x in range((y // 16) % 2 * 16, 64, 32):
            d.line([(x, y), (x, y + 16)], fill=(80, 80, 76), width=2)
    save(a, "ch5w_dota_stone")


# ------------------------------------------------------------------ RPG Maker screens

def chibi(d, x, y, hair, cloth, skin=(250, 214, 180)):
    d.rectangle([x + 4, y + 1, x + 11, y + 7], fill=skin)
    d.rectangle([x + 3, y, x + 12, y + 3], fill=hair)
    d.rectangle([x + 3, y + 3, x + 4, y + 8], fill=hair)
    d.point([(x + 6, y + 5), (x + 9, y + 5)], fill=(20, 10, 10))
    d.rectangle([x + 4, y + 8, x + 11, y + 13], fill=cloth)
    d.rectangle([x + 5, y + 14, x + 6, y + 15], fill=(40, 30, 30))
    d.rectangle([x + 9, y + 14, x + 10, y + 15], fill=(40, 30, 30))


def window(d, rect, lines, f):
    x0, y0, x1, y1 = rect
    d.rectangle(rect, fill=(16, 20, 44))
    d.rectangle(rect, outline=(230, 230, 240), width=1)
    d.rectangle([x0 + 2, y0 + 2, x1 - 2, y1 - 2], outline=(110, 110, 150), width=1)
    for i, l in enumerate(lines):
        d.text((x0 + 6, y0 + 4 + i * 10), l, font=f, fill=(240, 240, 240))


def rpg_black():
    w, h = 160, 120
    im = Image.new("RGB", (w, h), (20, 12, 26))
    d = ImageDraw.Draw(im)
    rng = random.Random(50)
    for ty in range(0, h, 8):
        for tx in range(0, w, 8):
            c = rng.choice([(30, 22, 40), (34, 26, 46), (26, 18, 36)])
            d.rectangle([tx, ty, tx + 7, ty + 7], fill=c)
            if rng.random() < .15:d.point((tx + rng.randint(1, 6), ty + rng.randint(1, 6)), fill=(70, 50, 90))
    for tx in range(40, 120, 8):
        for ty in range(0, 84, 8):
            d.rectangle([tx + 1, ty, tx + 6, ty + 7], fill=(64, 56, 60))
    d.ellipse([124, 6, 146, 28], fill=(190, 30, 40))
    d.ellipse([128, 8, 148, 26], fill=(20, 12, 26))
    for k in range(7):
        x = 6 + k * 22 + (k % 2) * 6
        if 36 < x < 120:continue
        y = 14 + (k % 3) * 18
        d.rectangle([x + 6, y + 10, x + 8, y + 34], fill=(18, 10, 14))
        for b in range(4):
            d.line([(x + 7, y + 12 + b * 5), (x + 7 + (b % 2 * 2 - 1) * 8, y + 6 + b * 5)], fill=(18, 10, 14), width=1)
    chibi(d, 72, 44, (240, 220, 140), (70, 110, 200))
    chibi(d, 96, 30, (20, 20, 20), (30, 30, 30), (230, 230, 240))
    d.rectangle([104, 30, 106, 44], fill=(200, 30, 40))
    f = font(8)
    window(d, (4, 86, 156, 116), ["???: ...Alice. Why do you", "keep coming back here?"], f)
    save(im, "ch5w_rpg_black")


def rpg_fear():
    w, h = 160, 120
    im = Image.new("RGB", (w, h), (10, 8, 6))
    d = ImageDraw.Draw(im)
    rng = random.Random(60)
    for ty in range(0, 84, 8):
        for tx in range(0, w, 8):
            wall = ty < 24 or tx < 16 or tx > 136
            if wall:
                c = rng.choice([(70, 60, 50), (62, 52, 44), (78, 66, 54)])
                d.rectangle([tx, ty, tx + 7, ty + 7], fill=c)
                d.line([(tx, ty + 3), (tx + 7, ty + 3)], fill=(40, 34, 28))
                d.line([(tx + (ty // 8 % 2) * 4, ty), (tx + (ty // 8 % 2) * 4, ty + 3)], fill=(40, 34, 28))
            else:
                c = rng.choice([(46, 40, 34), (52, 46, 38), (42, 36, 30)])
                d.rectangle([tx, ty, tx + 7, ty + 7], fill=c)
                d.rectangle([tx, ty, tx + 7, ty + 7], outline=(36, 30, 26))
    for x in [24, 128]:
        d.rectangle([x, 10, x + 3, 18], fill=(90, 60, 30))
        d.ellipse([x - 3, 2, x + 6, 11], fill=(255, 170, 40))
        d.ellipse([x - 1, 4, x + 4, 9], fill=(255, 240, 160))
    for k in range(6):
        x, y = rng.randint(30, 120), rng.randint(30, 78)
        d.ellipse([x, y, x + rng.randint(4, 9), y + rng.randint(2, 5)], fill=(110, 10, 10))
    d.rectangle([92, 50, 108, 58], fill=(150, 120, 100))
    d.line([(92, 54), (108, 54)], fill=(110, 10, 10))
    for i, (hair, cloth) in enumerate([((60, 40, 30), (90, 90, 100)), ((200, 190, 160), (120, 40, 40)), ((30, 30, 30), (60, 80, 60)), ((150, 80, 40), (90, 70, 120))]):
        chibi(d, 44 + i * 12, 56 + (i % 2) * 2, hair, cloth)
    light = Image.new("L", (w, h), 0)
    ld = ImageDraw.Draw(light)
    for x in [26, 130]:
        for r in range(60, 0, -6):
            ld.ellipse([x - r, 8 - r, x + r, 8 + r], fill=min(255, 255 - r * 3))
    ld.ellipse([20, 20, 140, 100], fill=170)
    light = light.filter(ImageFilter.GaussianBlur(10))
    dark = Image.new("RGB", (w, h), (0, 0, 0))
    im = Image.composite(im, dark, light)
    d = ImageDraw.Draw(im)
    f = font(8)
    window(d, (4, 86, 156, 116), ["HP              MIND", "A ghoul blocks the way..."], f)
    d.rectangle([24, 92, 64, 96], fill=(60, 10, 10));d.rectangle([24, 92, 50, 96], fill=(200, 30, 30))
    d.rectangle([110, 92, 150, 96], fill=(20, 20, 60));d.rectangle([110, 92, 122, 96], fill=(90, 90, 230))
    save(im, "ch5w_rpg_fear")


# ------------------------------------------------------------------ The Sims

def sims():
    im = Image.new("RGB", (64, 64), (226, 214, 176))
    d = ImageDraw.Draw(im)
    for x in range(0, 64, 16):
        d.rectangle([x, 0, x + 5, 63], fill=(150, 186, 140))
    for y in range(4, 64, 16):
        for x in range(10, 64, 16):
            d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(200, 120, 120))
    save(im, "ch5w_sims_wall")
    im = to_img(tint(noise(64, 64, 8, 70), (150, 100, 60), (196, 144, 92)))
    d = ImageDraw.Draw(im)
    for y in range(0, 64, 8):
        d.line([(0, y), (64, y)], fill=(110, 70, 40))
        for x in range((y // 8) % 2 * 16, 64, 32):
            d.line([(x, y), (x, y + 8)], fill=(110, 70, 40))
    save(im, "ch5w_sims_floor")
    im = Image.new("RGB", (64, 64), (80, 90, 110))
    d = ImageDraw.Draw(im)
    for y in range(0, 64, 8):
        for x in range((y // 8) % 2 * 4, 64, 8):
            d.rectangle([x, y, x + 7, y + 7], fill=(70 + (x * 7 + y) % 20, 82, 104), outline=(50, 56, 72))
    save(im, "ch5w_sims_roof")
    save(strokes(to_img(tint(noise(128, 128, 16, 71), (70, 150, 60), (120, 200, 90))), 200, [(150, 220, 110), (60, 130, 50)], 6, 2, 72, vertical=True, alpha=80), "ch5w_sims_grass")


# ------------------------------------------------------------------ LEGO Batman 2

def lego():
    a = np.zeros((128, 128, 3)) + np.array([52, 54, 64])
    rng = random.Random(80)
    for y in range(6, 128, 12):
        for x in range(6, 128, 10):
            a[y:y + 7, x:x + 6] = (255, 210, 90) if rng.random() < .4 else (28, 30, 40)
    for x in range(0, 128, 32):
        a[:, x:x + 2] = (40, 42, 50)
    save(to_img(a), "ch5w_lego_windows")


# ------------------------------------------------------------------ Zuma

def zuma():
    n = noise(128, 128, 16, 90)
    im = to_img(tint(n, (100, 104, 82), (170, 170, 136)))
    d = ImageDraw.Draw(im)
    for y in range(0, 128, 32):
        d.line([(0, y), (128, y)], fill=(70, 72, 56), width=3)
        for x in range(0, 128, 32):
            cx, cy = x + 16, y + 16
            d.rectangle([cx - 10, cy - 10, cx + 10, cy + 10], outline=(80, 82, 64), width=2)
            d.rectangle([cx - 4, cy - 4, cx + 4, cy + 4], outline=(80, 82, 64), width=2)
            d.line([(cx - 10, cy), (cx - 4, cy)], fill=(80, 82, 64), width=2)
            d.line([(cx + 4, cy), (cx + 10, cy)], fill=(80, 82, 64), width=2)
    save(im, "ch5w_zuma_stone")
    n = noise(64, 64, 8, 91)
    im = to_img(tint(n, (60, 130, 60), (130, 190, 90)))
    d = ImageDraw.Draw(im)
    for y in range(4, 64, 12):
        for x in range((y // 12) % 2 * 6, 64, 12):
            d.ellipse([x, y, x + 6, y + 6], outline=(220, 200, 80))
    save(im, "ch5w_zuma_frog")


# ------------------------------------------------------------------ Half-Life 2

def hl2():
    a = np.zeros((128, 128, 3)) + np.array([150, 146, 136])
    a *= (.8 + noise(128, 128, 16, 100)[..., None] * .3)
    rng = random.Random(101)
    for y in range(0, 128, 32):
        a[y:y + 2] = (110, 106, 98)
        for x in range(8, 128, 30):
            lit = rng.random() < .25
            a[y + 10:y + 24, x:x + 14] = (230, 210, 150) if lit else (40, 52, 60)
            a[y + 10:y + 24, x + 6:x + 8] = (120, 116, 108)
    for x in range(0, 128, 64):
        a[:, x:x + 2] = (110, 106, 98)
    streak = noise(128, 128, 4, 102, 2)
    a *= (1 - np.clip(streak - .6, 0, 1)[..., None] * .8)
    save(to_img(a), "ch5w_hl2_panel")
    a = np.zeros((256, 64, 3)) + np.array([60, 66, 78])
    a *= (.8 + noise(64, 256, 8, 103)[..., None] * .4)
    for x in range(0, 64, 6):
        a[:, x] = (36, 40, 50)
    for y in range(0, 256, 18):
        a[y] = (40, 44, 54)
    for k in range(10):
        y, x = rng.randint(0, 250), rng.randint(0, 60)
        a[y:y + 3, x:x + 3] = (120, 200, 255)
    save(to_img(a), "ch5w_hl2_citadel")
    n = noise(128, 128, 8, 104)
    im = to_img(tint(n, (54, 58, 60), (100, 104, 104)))
    d = ImageDraw.Draw(im)
    for y in range(0, 128, 10):
        for x in range((y // 10) % 2 * 6, 128, 12):
            d.rounded_rectangle([x + 1, y + 1, x + 10, y + 9], radius=2, outline=(40, 42, 44))
    save(im, "ch5w_hl2_ground")


# ------------------------------------------------------------------ C&C Generals, EU4

def cnc():
    n = noise(128, 128, 32, 110)
    ripple = np.sin(np.arange(128)[:, None] / 7 + n * 5) * .5 + .5
    im = to_img(tint(ripple * .4 + n * .6, (176, 140, 90), (226, 196, 140)))
    save(strokes(im, 200, [(236, 210, 160), (160, 126, 80)], 16, 3, 111, vertical=False, alpha=50), "ch5w_cnc_sand")
    n = noise(64, 64, 16, 112)
    camo = np.where(n > .55, 1.0, 0.0)[..., None]
    a = np.array([96, 104, 64]) * (1 - camo) + np.array([60, 66, 40]) * camo
    a *= (.85 + noise(64, 64, 4, 113)[..., None] * .3)
    save(to_img(a), "ch5w_cnc_camo")
    a = np.zeros((64, 64, 3)) + np.array([150, 150, 140])
    a *= (.85 + noise(64, 64, 8, 114)[..., None] * .25)
    for y in range(0, 64, 16):a[y:y + 2] = (90, 90, 84)
    for x in range(0, 64, 32):a[:, x:x + 2] = (90, 90, 84)
    save(to_img(a), "ch5w_cnc_concrete")


def eu4():
    w, h = 512, 256
    rng = np.random.default_rng(120)
    land = noise(w, h, 64, 121, 4)
    land = land + (np.linspace(-.12, .12, w)[None, :] * 0)
    is_land = land > .5
    pts = rng.random((90, 2)) * [w, h]
    yy, xx = np.mgrid[0:h, 0:w]
    best = np.full((h, w), 1e9);idx = np.zeros((h, w), int)
    for i, (px, py) in enumerate(pts):
        d = (xx - px) ** 2 + (yy - py) ** 2
        m = d < best;best[m] = d[m];idx[m] = i
    nations = rng.integers(0, 9, 90)
    for i in range(90):
        if rng.random() < .55 and i > 0:nations[i] = nations[int(np.argmin(((pts[:i] - pts[i]) ** 2).sum(1)))]
    pal = np.array([[200, 60, 50], [60, 90, 170], [230, 200, 80], [90, 150, 70], [150, 90, 170], [220, 130, 60], [120, 120, 120], [200, 200, 210], [140, 70, 60]])
    a = pal[nations[idx]].astype(float)
    paper = noise(w, h, 16, 122)[..., None]
    a = a * (.8 + paper * .3)
    sea = np.array([70, 110, 150]) * (.85 + paper * .25)
    a = np.where(is_land[..., None], a, sea)
    border = np.zeros((h, w), bool)
    border[:, 1:] |= idx[:, 1:] != idx[:, :-1];border[1:] |= idx[1:] != idx[:-1]
    nb = nations[idx]
    nborder = np.zeros((h, w), bool)
    nborder[:, 1:] |= nb[:, 1:] != nb[:, :-1];nborder[1:] |= nb[1:] != nb[:-1]
    a[border & is_land] *= .75
    a[nborder & is_land] = (40, 30, 25)
    coast = np.zeros((h, w), bool)
    coast[:, 1:] |= is_land[:, 1:] != is_land[:, :-1];coast[1:] |= is_land[1:] != is_land[:-1]
    a[coast] = (50, 40, 30)
    save(to_img(a), "ch5w_eu4_map")
    save(planks((120, 76, 44), 123, n=4), "ch5w_eu4_wood")


if __name__ == "__main__":
    cnc();eu4();tf2();tf2_signs();gta();spore();dota();rpg_black();rpg_fear();sims();lego();zuma();hl2()
    (ROOT / "data/chapter_five_worlds.json").write_text(json.dumps({"textures": NAMES}, indent=1) + "\n")
    print("CH5_WORLDS", len(NAMES))
