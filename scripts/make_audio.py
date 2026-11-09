"""Compatibility entry point: import original audio instead of synthesizing it."""
from pathlib import Path

from import_minecraft_presentation import import_presentation
from import_game_music import prepare

if __name__ == "__main__":
    import_presentation(Path.home()/".local/share/PrismLauncher",
                        Path.home()/"Downloads/Telegram Desktop/MusicForGame.mp3",
                        Path.home()/"Downloads/audio_2026-10-27_17-30-49.ogg")

    prepare()
