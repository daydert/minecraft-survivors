"""EnderSteve's mechanical clock (chapter III finale, 2026-11-14): a gold rim with gear
teeth, violet enamel, open windows onto the inner gears. Own shapes; the colour and
grain are sampled from vanilla gold and amethyst blocks. The hands are drawn at runtime.
Writes assets/sprites/ch3_clock_face.png (96x96) and ch3_clock_gear.png (40x40)."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image

from import_minecraft_assets import ROOT, Importer, find_client

SIZE = 96


def grain(tex, x, y):
    r, g, b, _ = tex.getpixel((x % 16, y % 16))
    return (r + g + b) / 765


def ramp(stops, t):
    t = max(0.0, min(1.0, t))
    for i in range(len(stops) - 1):
        a, b = stops[i], stops[i + 1]
        if t <= b[0]:
            k = (t - a[0]) / max(1e-6, b[0] - a[0])
            return tuple(int(a[1][j] + (b[1][j] - a[1][j]) * k) for j in range(3))
    return stops[-1][1]


GOLD = [(0.0, (92, 54, 14)), (0.35, (186, 120, 30)), (0.7, (245, 196, 70)), (1.0, (255, 246, 170))]
VIOLET = [(0.0, (34, 12, 58)), (0.5, (86, 38, 140)), (1.0, (170, 110, 230))]


def gear(size, teeth, inner, gold, light):
    img = Image.new("RGBA", (size, size))
    c = (size - 1) / 2
    outer = size / 2 - 0.5
    for y in range(size):
        for x in range(size):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            tooth = (math.cos(a * teeth) > 0.2)
            edge = outer if tooth else outer - 3
            if r > edge or r < inner:
                continue
            spoke = any(abs(math.sin(a - k * math.pi / 3)) * r < 1.6 for k in range(3))
            if r > inner + 3 and r < edge - 4 and not spoke:
                continue
            shade = 0.45 + 0.4 * grain(gold, x, y) + 0.25 * light(dx, dy, r, outer)
            img.putpixel((x, y), ramp(GOLD, shade) + (255,))
    return img


def generate():
    _, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    gold, amethyst = imp.tex("block/gold_block"), imp.tex("block/amethyst_block")
    light = lambda dx, dy, r, outer: (-dx - dy) / (2 * outer)
    face = Image.new("RGBA", (SIZE, SIZE))
    c = (SIZE - 1) / 2
    inner_gear = gear(30, 9, 4, gold, light)
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            if r > 47.5:
                continue
            if r > 41.5:
                # Outer rim with twenty-four teeth, lit from the top left.
                if r > 45.5 and math.cos(a * 24) < -0.1:
                    continue
                shade = 0.5 + 0.35 * grain(gold, x, y) + 0.3 * light(dx, dy, r, 47) - (0.18 if r > 45.5 else 0)
                face.putpixel((x, y), ramp(GOLD, shade) + (255,))
            elif r > 39.5:
                face.putpixel((x, y), ramp(GOLD, 0.18) + (255,))
            else:
                # Violet enamel, darker toward the centre, with an amethyst grain.
                t = 0.25 + 0.45 * (r / 40) + 0.3 * grain(amethyst, x, y) - 0.15 * light(dx, dy, r, 40)
                face.putpixel((x, y), ramp(VIOLET, t) + (255,))
    # Twelve gold marks; the four quarters are long bars.
    for j in range(12):
        a = j * math.tau / 12 - math.pi / 2
        length = 8 if j % 3 == 0 else 4
        for k in range(length):
            rr = 37 - k
            for w in ([-1, 0, 1] if j % 3 == 0 else [0]):
                x = int(math.floor(c + 0.5 + math.cos(a) * rr - math.sin(a) * w))
                y = int(math.floor(c + 0.5 + math.sin(a) * rr + math.cos(a) * w))
                face.putpixel((x, y), ramp(GOLD, 0.62 + 0.3 * (k == 0)) + (255,))
    # Two windows onto the works, each with a gear inside.
    for wx, wy in [(-15, 17), (15, 17)]:
        for y in range(SIZE):
            for x in range(SIZE):
                if math.hypot(x - c - wx, y - c - wy) < 8:
                    face.putpixel((x, y), (16, 6, 26, 255))
                elif math.hypot(x - c - wx, y - c - wy) < 9.5:
                    face.putpixel((x, y), ramp(GOLD, 0.55 + 0.3 * grain(gold, x, y)) + (255,))
        small = gear(15, 7, 2, gold, light)
        face.alpha_composite(small, (int(c + wx - 7), int(c + wy - 7)))
    # Centre boss.
    for y in range(SIZE):
        for x in range(SIZE):
            r = math.hypot(x - c, y - c)
            if r < 4.5:
                face.putpixel((x, y), ramp(GOLD, 0.9 - r / 9) + (255,))
    face.save(ROOT / "assets/sprites/ch3_clock_face.png")
    gear(40, 12, 6, gold, light).save(ROOT / "assets/sprites/ch3_clock_gear.png")
    preview = Image.new("RGBA", (SIZE * 4 + 40 * 4, SIZE * 4), (30, 26, 34, 255))
    preview.alpha_composite(face.resize((SIZE * 4, SIZE * 4), Image.NEAREST), (0, 0))
    preview.alpha_composite(Image.open(ROOT / "assets/sprites/ch3_clock_gear.png").resize((160, 160), Image.NEAREST), (SIZE * 4, 0))
    preview.save(ROOT / "qa/ch3_clock_preview.png")
    print("CH3_CLOCK ok")


if __name__ == "__main__":
    generate()
