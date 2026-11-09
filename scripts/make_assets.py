"""Compatibility entry point: prepare the original local Minecraft item art.

For a different Prism path or an explicit JAR, use import_minecraft_assets.py.
Character animation atlases are still built separately by assemble_sprites.py.
"""
from pathlib import Path

from import_minecraft_assets import import_assets

if __name__ == "__main__":
    import_assets(Path.home() / ".local/share/PrismLauncher")
