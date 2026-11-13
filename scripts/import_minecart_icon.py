#!/usr/bin/env python3
"""Restore the inventory minecart from the installed vanilla Minecraft client.

The game displays item icons on a 16-pixel grid. Keeping Minecraft's original
sprite preserves its silhouette, shading and palette alongside the other items.
No generated painting, smoothing, resource pack or network access is involved.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import zipfile

from PIL import Image

from import_minecraft_assets import ROOT, find_client


SOURCE = "assets/minecraft/textures/item/minecart.png"
TARGET = ROOT / "assets/sprites/icon_minecart.png"
QA = ROOT / "qa/minecart_icon"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jar", type=Path, help="Use this installed Minecraft client JAR.")
    args = parser.parse_args()
    if args.jar:
        client = args.jar.expanduser().resolve()
        version = client.parent.name
    else:
        version, client, _ = find_client(Path.home() / ".local/share/PrismLauncher")
    with zipfile.ZipFile(client) as jar:
        raw = jar.read(SOURCE)
    icon = Image.open(io.BytesIO(raw)).convert("RGBA")
    if icon.size != (16, 16):
        raise ValueError(f"Expected the vanilla 16x16 item, got {icon.size}")
    if set(icon.getchannel("A").get_flattened_data()) != {0, 255}:
        raise ValueError("Expected the vanilla item's crisp transparent/opaque alpha")
    QA.mkdir(parents=True, exist_ok=True)
    backup = QA / "icon_minecart_before.png"
    if TARGET.exists() and not backup.exists():
        backup.write_bytes(TARGET.read_bytes())
    TARGET.write_bytes(raw)
    # A preview of the actual delivered sprite, enlarged only with nearest.
    preview = Image.new("RGB", (256, 128), (24, 24, 24))
    preview.paste((112, 112, 112), (128, 0, 256, 128))
    enlarged = icon.resize((96, 96), Image.Resampling.NEAREST)
    preview.paste(enlarged, (16, 16), enlarged)
    preview.paste(enlarged, (144, 16), enlarged)
    preview.save(QA / "preview.png")
    manifest = {
        "minecraft_version": version,
        "source": SOURCE,
        "output": str(TARGET.relative_to(ROOT)),
        "size": list(icon.size),
        "sha256": sha(raw),
        "byte_identical_to_vanilla": TARGET.read_bytes() == raw,
        "alpha_values": [0, 255],
        "filter": "nearest",
        "backup": str(backup.relative_to(ROOT)) if backup.exists() else None,
        "backup_sha256": sha(backup.read_bytes()) if backup.exists() else None,
        "preview": "qa/minecart_icon/preview.png",
    }
    (ROOT / "docs/MINECART_ICON_MANIFEST.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    )
    print(f"Vanilla Minecraft {version}: {TARGET.relative_to(ROOT)}, {sha(raw)}")


if __name__ == "__main__":
    main()
