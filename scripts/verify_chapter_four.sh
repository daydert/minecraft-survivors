#!/bin/sh
# User requested that heavy I–III/coop regressions wait until the full IV finale.
set -eu
cd "$(dirname "$0")/.."
engine=${SURVIVORS_GODOT_BIN:-./.tools/Godot_v4.7.2-stable_linux.x86_64}
"$engine" --headless --single-threaded-scene --path . --editor --import --quit > qa/chapter_four_c_import.log 2>&1
"$engine" --headless --path . -s qa/test_chapter_four.gd
"$engine" --headless --path . -s qa/test_chapter_four_enemies.gd
"$engine" --headless --path . -s qa/test_chapter_four_arsenal.gd
"$engine" --headless --path . -s qa/test_chapter_four_encounters.gd
"$engine" --headless --path . -s qa/test_chapter_four_finale.gd
python scripts/check_chapter_four_assets.py
python scripts/check_chapter_four_mobs.py
python scripts/check_chapter_four_equipment.py
if [ "${1:-}" = "--visual" ]; then
 "$engine" --path . --display-driver wayland --audio-driver Dummy -s qa/test_chapter_four_arsenal_visual.gd > qa/chapter_four_c_visual.log 2>&1
 cat qa/chapter_four_c_visual.log
 if rg 'SCRIPT ERROR|^ERROR:' qa/chapter_four_c_visual.log | rg -v '^ERROR: [0-9]+ resources still in use at exit'; then exit 1; fi
fi
