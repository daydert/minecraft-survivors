#!/usr/bin/env python3
"""Chapter IV impact sprites: the vanilla bat as one connected hierarchy.

Rows: facing the camera, facing away, side view. Six wing phases per row.
Uses the shared Importer / box / bake helpers and the native 32x32 bat UV.
"""
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

from import_minecraft_assets import ROOT, Importer, bake, box, find_client

FRAME = (28, 24)
PHASES = 6


def turn(mesh, angle, pivot):
    """Rotate a part around the vertical axis through `pivot`."""
    c, s = math.cos(angle), math.sin(angle)
    matrix = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    pivot = np.array(pivot, dtype=float)
    return [((verts - pivot) @ matrix.T + pivot, tex, rect, shade) for verts, tex, rect, shade in mesh]


def flat(tex, origin, size, uv):
    x, y, z = origin
    w, h = size
    return box(tex, (x, y, z), (w, h, 0.02), uv, faces={
        "north": (tex, (uv[0], uv[1], w, h)),
        "south": (tex, (uv[0] + w, uv[1], w, h)),
    })


def bat(tex, phase):
    flap = math.sin(phase * math.tau)
    mesh = box(tex, (-1.5, 0, -1), (3, 5, 2), (0, 0))
    mesh += box(tex, (-2, 5, -1), (4, 3, 2), (0, 7))
    mesh += flat(tex, (-2.5, 7, 0), (3, 5), (1, 15))
    mesh += flat(tex, (-0.5, 7, 0), (3, 5), (8, 15))
    mesh += flat(tex, (-1.5, -2, 0), (3, 2), (16, 16))
    for sign, wing_uv, tip_uv in [(-1, (12, 0), (16, 0)), (1, (12, 7), (16, 8))]:
        root = (sign * 1.5, 0, 0)
        inner_x = -3.5 if sign < 0 else 1.5
        tip_x = -9.5 if sign < 0 else 3.5
        tip = flat(tex, (tip_x, -1.5, 0), (6, 8), tip_uv)
        tip = turn(tip, sign * flap * 0.55, (sign * 3.5, 0, 0))
        wing = flat(tex, (inner_x, -1, 0), (2, 7), wing_uv) + tip
        mesh += turn(wing, sign * (0.25 + flap * 0.7), root)
    return mesh


def generate():
    version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    tex = imp.tex("entity/bat")
    sheet = Image.new("RGBA", (FRAME[0] * PHASES, FRAME[1] * 3))
    for row, yaw in enumerate([18, 198, 105]):
        for col in range(PHASES):
            frame = bake(bat(tex, col / PHASES), FRAME, 1.15, (14, 16), yaw=yaw, elevation=24)
            sheet.paste(frame, (col * FRAME[0], row * FRAME[1]))
    imp.save(sheet, "ch4_fx_bat", ["entity/bat"],
             f"Origin: Minecraft Java {version}, local client {client}; vanilla entity/bat on its native UV.")
    data = {"sprites": ["ch4_fx_bat"], "bat": {"frame": list(FRAME), "phases": PHASES}}
    (ROOT / "data/chapter_four_fx.json").write_text(json.dumps(data, indent=2) + "\n")
    manifest = {"version": version, "client_jar": str(client), "raw_files": imp.files, "derived": imp.derived}
    (ROOT / "docs/CHAPTER_FOUR_FX_MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("BAKED ch4_fx_bat", sheet.size)


if __name__ == "__main__":
    generate()
