"""Chapter IV pillar hunt (13.11): empty pillars after a villager is taken down
or tears himself loose, and the body laid at the foot of the pillar.

Same rasterizer and vanilla textures as bake_chapter_four_assets.py; appends
its sprites to data/chapter_four_assets.json without rebaking the terrain.
"""
import json
import numpy as np
from pathlib import Path

from import_minecraft_assets import ROOT, Importer, bake, find_client
from bake_minecraft_characters import transform
from bake_chapter_four_assets import block, villager_tpose

WOOD = (80, 62, 56)


def pillar(imp, variant, torn):
    mesh = block(imp, "oak_log", (-2.5, 0, 2), (5, 52, 5), "oak_log_top", rgb=WOOD)
    if torn:
        # The crossbeam went with him: splinters and a bloody socket remain.
        for x, h in [(-6, 3), (2.5, 4)]:
            mesh += block(imp, "stripped_oak_log", (x, 38, 2), (3.5, h, 4), "stripped_oak_log", rgb=(110, 84, 70))
        mesh += block(imp, "red_concrete_powder", (-3, 36, 1.6), (6, 7, 1), rgb=(120, 20, 22))
        mesh += block(imp, "red_concrete_powder", (-8, 0, -6), (16, 1, 12), rgb=(120, 18, 20))
    else:
        mesh += block(imp, "oak_log", (-16, 38, 2), (32, 4, 4), "oak_log_top", rgb=WOOD)
        # Cut ropes hang from both ends of the crossbeam.
        for sign in [-1, 1]:
            mesh += block(imp, "brown_wool", (sign * 12 - .6, 31 + variant * 2, 1.4), (1.2, 7 - variant * 2, 1.2), rgb=(150, 120, 90))
        mesh += block(imp, "red_concrete_powder", (-5, 0, -4), (10, 1, 8), rgb=(140, 30, 30))
    return mesh


def laid(imp):
    body = villager_tpose(imp, 0.2)
    body = transform(body, (1.5708, 0, 0), pivot=(0, 0, 0))
    v = np.concatenate([q[0] for q in body])
    low, high = v.min(0), v.max(0)
    body = transform(body, offset=(-(low[0] + high[0]) / 2, -low[1], -(low[2] + high[2]) / 2))
    # A sheet pulled over the chest and legs; the head stays uncovered.
    span = high[2] - low[2]
    body += block(imp, "white_wool", (-9, high[1] - low[1] - 3, -span / 2 + 9), (18, 2, span - 8), rgb=(190, 180, 170))
    body += block(imp, "red_concrete_powder", (-5, high[1] - low[1] - .9, -2), (7, .4, 8), rgb=(130, 24, 24))
    return body


def generate():
    _, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    imp = Importer(client)
    bakes = [("ch4_crucifix_empty_0", pillar(imp, 0, False), (64, 96), 1.2, (32, 88), 8),
             ("ch4_crucifix_empty_1", pillar(imp, 1, False), (64, 96), 1.2, (32, 88), -10),
             ("ch4_crucifix_torn", pillar(imp, 0, True), (64, 96), 1.2, (32, 88), 8),
             ("ch4_laid_villager", laid(imp), (56, 40), 1.0, (28, 26), 70)]
    path = ROOT / "data/chapter_four_assets.json"
    data = json.loads(path.read_text())
    for name, mesh, size, scale, center, yaw in bakes:
        imp.save(bake(mesh, size, scale, center, yaw=yaw, elevation=22), name, ["vanilla block/entity textures"])
        if name not in data["sprites"]:
            data["sprites"].append(name)
        print("BAKED", name)
    path.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    generate()
