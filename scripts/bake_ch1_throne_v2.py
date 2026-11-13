"""Chapter I throne v2 (13.11): the alpha-era flat throne and seated sprite replaced by
a baked block throne and a posed, seated Herobrine from the same 3D player model as IV.
Writes assets/sprites/ch1_throne_v2.png, ch1_throne_hb_{calm,smile,rage}.png and
data/ch1_throne_v2.json (frame, centre, fire sockets, eye point, clip layout)."""
from __future__ import annotations
import json, math
from pathlib import Path
import numpy as np
from PIL import Image
from import_minecraft_assets import ROOT, Importer, bake, box, find_client
from bake_chapter_four_finale import herobrine_skin, figure, mix, ease
from bake_minecraft_characters import transform

FRAME = (220, 198)
CENTER = (110, 172)
SCALE = 1.65
YAW, ELEV = 0, 22

def face_all(img):
    return {f: (img, (0, 0, img.width, img.height)) for f in ["north", "south", "east", "west", "up", "down"]}

def block(tex, x, y, z, w=16, h=16, d=16, top=None):
    """Texel-true: split into cells no bigger than a block; every face samples
    exactly its own size from the 16x16 texture, so nothing is stretched."""
    out = []
    def cuts(a, n):
        r = [];p = 0.0
        while p < n - 1e-6:r.append((a + p, min(16.0, n - p)));p += 16.0
        return r
    for cx, cw in cuts(x, w):
        for cy, ch in cuts(y, h):
            for cz, cd in cuts(z, d):
                def rect(img, a, b2):return (img, (0, 16 - b2 if img.height >= 16 else 0, a, b2))
                faces = {"north": rect(tex, cw, ch), "south": rect(tex, cw, ch), "east": rect(tex, cd, ch), "west": rect(tex, cd, ch),
                         "up": ((top or tex), (0, 0, cw, cd)), "down": (tex, (0, 0, cw, cd))}
                out += box(tex, (cx, cy, cz), (cw, ch, cd), faces=faces)
    return out

def throne(imp):
    t = lambda n: imp.tex("block/" + n).convert("RGBA").crop((0, 0, 16, 16))
    bricks, polished, black, obsidian, crying = t("polished_blackstone_bricks"), t("polished_blackstone"), t("blackstone"), t("obsidian"), t("crying_obsidian")
    gilded, nether, red, soul = t("gilded_blackstone"), t("nether_bricks"), t("red_wool"), t("soul_sand")
    m = []
    # dais: two tiers of brick, a lower front step, a red runner down the middle
    for x in range(-48, 48, 16):
        for z in range(-8, 40, 16):m += block(bricks, x, 0, z, 16, 8, 16, top=polished)
    for x in range(-32, 32, 16):m += block(bricks, x, 0, -24, 16, 4, 16, top=polished)
    for x in range(-32, 32, 16):
        for z in range(8, 40, 16):m += block(polished, x, 8, z, 16, 4, 16)
    m += block(red, -8, 8.05, -8, 16, .2, 16);m += block(red, -8, 4.05, -24, 16, .2, 16);m += block(red, -8, 12.05, 8, 16, .2, 8)
    # seat and armrests
    m += block(black, -16, 12, 12, 32, 10, 20, top=polished)
    for sx in (-26, 16):m += block(polished, sx, 12, 10, 10, 18, 24)
    # backrest: obsidian with crying obsidian heart, a gilded crown
    m += block(obsidian, -18, 22, 28, 36, 40, 8)
    m += block(crying, -8, 34, 27.5, 16, 16, .5)
    m += block(gilded, -22, 62, 26, 44, 8, 12)
    m += block(gilded, -10, 70, 28, 20, 6, 8)
    # columns with braziers
    for sx in (-60, 44):
        m += block(nether, sx, 0, 12, 16, 72, 16)
        m += block(soul, sx - 2, 72, 10, 20, 6, 20)
    return m

def steve_heads(imp):
    tex = imp.tex("entity/player/wide/steve")
    m = []
    for x, y, z in [(-26, 30, 12), (16, 30, 12), (-30, 70, 26), (20, 70, 26)]:
        head = box(tex, (x, y, z), (10, 10, 10), (0, 0))
        m += transform(head, (0, 0, 0), scale=(1, 1, 1))
    return m

GIANT = 1.7
SEATED = (0, 22 - 12 * 1.7, 20)
def sit(d):
    base = {"root": (0, 0, 0), "rl": (-1.42, 0, 0.12), "ll": (-1.42, 0, -0.12), "ra": (-0.75, 0, 0.32), "la": (-0.75, 0, -0.32), "lean": (0.1, 0, 0)}
    out = dict(base);out.update(d);return out

POSES = {
    "sit_idle": [sit({"head": (0.08, 0.1, 0.06)}), sit({"head": (0.12, 0.05, 0.08), "lean": (0.13, 0, 0)}), sit({"head": (0.08, -0.05, 0.05)})],
    "sit_cast": [sit({"ra": (-1.6, 0, 0.35), "head": (-0.05, 0, 0)}), sit({"ra": (-2.85, 0, 0.25), "head": (-0.25, 0, 0)}), sit({"ra": (-2.95, 0, 0.15), "head": (-0.3, 0, 0), "lean": (0.0, 0, 0)})],
    "sit_point": [sit({"ra": (-1.2, 0, 0.1), "head": (0.05, 0, 0)}), sit({"ra": (-1.55, -0.1, 0.0), "head": (0.0, 0, 0), "lean": (0.18, 0, 0)})],
    "sit_command": [sit({"ra": (-1.45, 0, 0.35), "la": (-1.45, 0, -0.35), "lean": (0.2, 0, 0)}), sit({"ra": (-1.7, 0, 0.1), "la": (-1.7, 0, -0.1), "lean": (0.3, 0, 0), "head": (0.1, 0, 0)}), sit({"ra": (-1.6, 0, 0.45), "la": (-1.6, 0, -0.45), "lean": (0.25, 0, 0)})],
    "sit_laugh": [sit({"lean": (-0.25, 0, 0), "head": (-0.4, 0, 0)}), sit({"lean": (-0.3, 0, 0.04), "head": (-0.5, 0.1, 0)}), sit({"lean": (-0.25, 0, -0.04), "head": (-0.42, -0.1, 0)})],
    "rise": [sit({}), {"root": (0, -1, -4), "rl": (-0.7, 0, 0.1), "ll": (-0.7, 0, -0.1), "lean": (0.35, 0, 0), "ra": (-0.4, 0, 0.3), "la": (-0.4, 0, -0.3)}, {"root": (0, -2.4, -10), "lean": (0.0, 0, 0), "ra": (0.05, 0, 0.12), "la": (0.05, 0, -0.12)}],
    "stand": [{"root": (0, -2.4, -10), "ra": (0.05, 0, 0.14), "la": (0.05, 0, -0.14), "head": (0.06, 0, 0)}, {"root": (0, -2.4, -10), "ra": (0.08, 0, 0.18), "la": (0.08, 0, -0.18), "head": (0.1, 0, 0), "lean": (0.03, 0, 0)}],
}
COUNTS = {"sit_idle": 6, "sit_cast": 4, "sit_point": 3, "sit_command": 4, "sit_laugh": 4, "rise": 8, "stand": 4}

def frames(name):
    keys = POSES[name];n = COUNTS[name];out = []
    for i in range(n):
        if name in ["sit_idle", "sit_laugh", "stand"]:
            t = i / n * len(keys);a = int(t) % len(keys);b = (a + 1) % len(keys)
        else:
            t = i / max(1, n - 1) * (len(keys) - 1);a = int(min(len(keys) - 2, t)) if len(keys) > 1 else 0;b = min(a + 1, len(keys) - 1)
        out.append(mix(keys[a], keys[b], ease(t - int(t))))
    return out

def project(p):
    yaw, el = math.radians(YAW), math.radians(ELEV)
    right = np.array([math.cos(yaw), 0, math.sin(yaw)]);up = np.array([-math.sin(yaw) * math.sin(el), math.cos(el), math.cos(yaw) * math.sin(el)])
    v = np.array(p, dtype=float);return [float(v @ right * SCALE + CENTER[0]), float(-v @ up * SCALE + CENTER[1])]

def generate():
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher");imp = Importer(client)
    stage = throne(imp) + steve_heads(imp)
    img = bake(stage, FRAME, SCALE, CENTER, yaw=YAW, elevation=ELEV)
    img = img if isinstance(img, Image.Image) else Image.fromarray(np.array(img))
    imp.save(img, "ch1_throne_v2", ["block textures (blackstone family, obsidian, crying obsidian, gilded blackstone, nether bricks, soul sand, red wool)", "entity/player/wide/steve heads"])
    layout = {};columns = []
    for name in POSES:layout[name] = {"start": len(columns), "count": COUNTS[name]};columns += frames(name)
    # the seat in front of the backrest occludes legs correctly: bake the throne with each frame, keep only figure pixels
    bg = np.array(img)
    for face in ["calm", "smile", "rage"]:
        tex = herobrine_skin(imp, face)
        sheet = Image.new("RGBA", (FRAME[0] * len(columns), FRAME[1]))
        for i, pose in enumerate(columns):
            # He is a giant on it: the model at 1.7x, hips on the seat.
            body = transform(figure(tex, pose), (0, 0, 0), scale=(GIANT, GIANT, GIANT))
            body = transform(body, offset=SEATED if pose.get("seated", True) else pose.get("place", (0, 0, -4)))
            fig = bake(body + stage, FRAME, SCALE, CENTER, yaw=YAW, elevation=ELEV)
            arr = np.array(fig if isinstance(fig, Image.Image) else Image.fromarray(np.array(fig)))
            diff = np.any(arr != bg, axis=2)
            arr[~diff] = 0
            sheet.paste(Image.fromarray(arr), (i * FRAME[0], 0))
        imp.save(sheet, "ch1_throne_hb_" + face, ["entity/player/wide/steve (white eyes, " + face + ")"])
    data = {"frame": list(FRAME), "center": list(CENTER), "clips": layout,
            "sockets": [project((-52, 80, 20)), project((52, 80, 20))], "eyes": project((0, 22 + (12 + 4.5) * GIANT, 20 - 4 * GIANT)),
            "seat": project((0, 22, 20)), "fps": {"sit_idle": 5, "sit_laugh": 9, "stand": 4}}
    (ROOT / "data/ch1_throne_v2.json").write_text(json.dumps(data, indent=1) + "\n")
    print("throne v2", img.size, len(columns), "frames")

if __name__ == "__main__":
    generate()
