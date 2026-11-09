#!/bin/sh
# User requested that heavy I–III/coop regressions wait until the full IV finale.
set -eu
cd "$(dirname "$0")/.."
engine=${SURVIVORS_GODOT_BIN:-./.tools/Godot_v4.7.2-stable_linux.x86_64}
"$engine" --headless --single-threaded-scene --path . --editor --import --quit > qa/chapter_four_b_import.log 2>&1
"$engine" --headless --path . -s qa/test_chapter_four.gd
"$engine" --headless --path . -s qa/test_chapter_four_enemies.gd
python scripts/check_chapter_four_assets.py
python scripts/check_chapter_four_mobs.py
if [ "${1:-}" = "--visual" ]; then
 "$engine" --path . --display-driver wayland --audio-driver Dummy -s qa/test_chapter_four_enemies_visual.gd
fi
