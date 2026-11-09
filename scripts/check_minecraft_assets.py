"""Validate source integrity, native animation order and complete game coverage."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
manifest = json.loads((ROOT / "docs/MINECRAFT_ASSET_MANIFEST.json").read_text())
# V2 deliberately replaces the old tinted bottle with the native potion item.
v2 = json.loads((ROOT / "docs/V2_ASSET_MANIFEST.json").read_text())
manifest["derived"]["icon_potion"] = v2["derived"]["icon_potion"]
spec = json.loads((ROOT / "data/minecraft_assets.json").read_text())
balance = json.loads((ROOT / "data/balance.json").read_text())
checks = 0


def check(condition, label):
    global checks
    assert condition, label
    checks += 1


for name, info in manifest["raw_files"].items():
    source = ROOT / "assets/minecraft" / name
    check(hashlib.sha256(source.read_bytes()).hexdigest() == info["sha256"], "Original bytes: " + name)
for name, info in manifest["derived"].items():
    path = ROOT / "assets/sprites" / (name + ".png")
    check(hashlib.sha256(path.read_bytes()).hexdigest() == info["sha256"], "Game sprite integrity: " + name)
    if info.get("byte_identical"):
        source = ROOT / "assets/minecraft/textures" / (info["sources"][0] + ".png")
        check(path.read_bytes() == source.read_bytes(), "Unmodified vanilla item: " + name)

ids = list(balance["weapons"]) + list(balance["passives"]) + ["apple", "emerald", "chest"]
ids += [recipe["icon"] for recipe in balance["recipes"].values()]
for item in ids:
    path = ROOT / "assets/sprites" / ("icon_" + item + ".png")
    im = Image.open(path).convert("RGBA")
    check(im.size == (16, 16) and im.getbbox() is not None, "Game item available: " + item)
    check("icon_" + item in manifest["derived"], "Item has vanilla provenance: " + item)

for name, clip in spec["clips"].items():
    atlas = Image.open(ROOT / "assets/sprites" / (name + ".png")).convert("RGBA")
    w, h = clip["frame_size"]
    check(atlas.height == h and atlas.width % w == 0, "Valid animation atlas: " + name)
    check(len(clip["frames"]) == len(clip["durations"]) and min(clip["durations"]) > 0,
          "Valid animation timing: " + name)
    frames = [atlas.crop((frame*w, 0, (frame+1)*w, h)).tobytes() for frame in clip["frames"]]
    check(all(0 <= frame < atlas.width // w for frame in clip["frames"]), "In-bounds frames: " + name)
    check(len(set(frames)) >= (4 if name == "fangs_animation" else min(6, len(frames))),
          "Distinct animated images: " + name)

fire = Image.open(ROOT / "assets/minecraft/textures/block/fire_0.png").convert("RGBA")
fire_meta = json.loads((ROOT / "assets/minecraft/textures/block/fire_0.png.mcmeta").read_text())["animation"]
fire_clip = spec["clips"]["fire_animation"]
check(fire_clip["frames"] == fire_meta["frames"], "Original fire frame order, including the 16-frame offset")
check(set(fire_clip["durations"]) == {0.05}, "Original Minecraft 20 Hz fire timing")
atlas = Image.open(ROOT / "assets/sprites/fire_animation.png").convert("RGBA")
for frame in range(32):
    check(atlas.crop((frame*16,0,(frame+1)*16,16)).tobytes() ==
          fire.crop((0,frame*16,16,(frame+1)*16)).tobytes(), "Unmodified fire frame " + str(frame))
for frame in range(3):
    original = (ROOT / f"assets/minecraft/textures/item/bow_pulling_{frame}.png").read_bytes()
    check(original == (ROOT / f"assets/sprites/bow_pulling_{frame}.png").read_bytes(),
          "Unmodified bow draw stage " + str(frame))

result = {"version": manifest["version"], "checks": checks, "failures": [],
          "covered_game_items": ids, "original_resources": len(manifest["raw_files"])}
(ROOT / "qa/minecraft_asset_results.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n")
print(f"MINECRAFT_ASSETS_RESULT {checks} checks passed; {len(ids)} game items, Minecraft {manifest['version']}")
