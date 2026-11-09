#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
engine=${SURVIVORS_GODOT_BIN:-./.tools/Godot_v4.7.2-stable_linux.x86_64}
"$engine" --headless --single-threaded-scene --path . --editor --import --quit > qa/import.log 2>&1
"$engine" --headless --path . -s qa/test_world.gd
"$engine" --headless --path . -s qa/ui_flow.gd
"$engine" --headless --path . -s qa/test_screen_router.gd
"$engine" --headless --path . -s qa/test_determinism.gd
"$engine" --headless --path . -s qa/test_animation.gd
"$engine" --headless --path . -s qa/test_chapter.gd
"$engine" --headless --path . -s qa/test_coop.gd
"$engine" --headless --path . -s qa/test_coop_four.gd
"$engine" --headless --path . -s qa/test_coop_logging.gd
"$engine" --headless --path . -s qa/test_nether.gd
"$engine" --headless --path . -s qa/test_music_rotation.gd
python scripts/check_game_music.py
"$engine" --headless --path . -s qa/test_boss_update.gd
"$engine" --headless --path . -s qa/test_boss_polish.gd
"$engine" --headless --path . -s qa/test_ghast_update.gd
"$engine" --headless --path . -s qa/test_end.gd
"$engine" --headless --path . -s qa/test_end_revision.gd
"$engine" --headless --path . -s qa/test_achievements.gd
"$engine" --headless --path . -s qa/test_v2_content.gd
python scripts/check_achievement_assets.py
python scripts/check_end_assets.py
python scripts/check_ghast_assets.py
python scripts/check_duel_assets.py
python scripts/check_nether_assets.py
python scripts/check_atlases.py
python scripts/check_minecraft_assets.py
python scripts/check_presentation_assets.py
python scripts/check_minecraft_characters.py
if [ "${1:-}" = "--full" ]; then
    "$engine" --headless --path . -s qa/compare_combat.gd
    "$engine" --headless --path . -s qa/full_runs.gd
fi
if [ "${1:-}" = "--network-four" ]; then
    python qa/test_network.py --players 2 --latency 45 --jitter 20 --loss .05 --label four_compat
    python qa/test_network.py --players 3 --latency 45 --jitter 20 --loss .05 --label three
    python qa/test_network.py --players 4 --latency 45 --jitter 20 --loss .05 --label four
    python qa/test_network.py --players 4 --latency 45 --jitter 20 --loss .05 --scenario disconnect --label four
    python qa/test_network.py --players 4 --latency 45 --jitter 20 --loss .05 --scenario host_dead --label four
    python qa/test_network.py --players 4 --latency 45 --jitter 20 --loss .05 --scenario restart --label four
    python qa/test_network.py --players 4 --latency 45 --jitter 20 --loss .05 --slow-seat 3 --slow-extra 200 --label four_slow
    python qa/test_network.py --players 4 --latency 45 --jitter 20 --loss .05 --blackout 1 --blackout-seat 1 --label four_recovery
    python qa/test_network.py --players 4 --scenario host_leave --label four
fi
if [ "${1:-}" = "--visual" ]; then
    "$engine" --path . --display-driver wayland -s qa/test_end_visual.gd
    "$engine" --path . --display-driver wayland -s qa/test_end_polish_visual.gd
    "$engine" --path . --display-driver wayland -s qa/test_end_revision_visual.gd
    "$engine" --path . --display-driver wayland -s qa/test_achievements_visual.gd
    "$engine" --path . --display-driver wayland -s qa/test_ghast_visual.gd
    "$engine" --path . --display-driver wayland -s qa/test_boss_polish_visual.gd
    "$engine" --path . --display-driver wayland -s qa/test_herobrine_visual.gd
    "$engine" --path . --display-driver wayland -s qa/test_nether_visual.gd
    "$engine" --path . --display-driver wayland -s qa/test_character_facing.gd
    "$engine" --path . --display-driver wayland -s qa/test_visual_animation.gd
    "$engine" --path . --display-driver wayland -s qa/test_minecraft_render.gd
    "$engine" --path . --display-driver wayland -s qa/test_presentation.gd
    "$engine" --path . --display-driver wayland -s qa/test_chapter_visual.gd
    "$engine" --path . --display-driver wayland -s qa/test_coop_visual.gd
    "$engine" --path . --display-driver wayland -s qa/test_coop_four_visual.gd
fi
if [ "${1:-}" = "--network" ]; then
    python qa/test_network.py --label local
    python qa/test_network.py --latency 45 --jitter 20 --loss .05 --label final
    python qa/test_network.py --latency 45 --jitter 20 --loss .05 --scenario stress --label final
    python qa/test_network.py --latency 45 --jitter 20 --loss .05 --scenario host_dead --label final
    python qa/test_network.py --latency 45 --jitter 20 --loss .05 --scenario restart --label final
    python qa/test_network.py --latency 45 --jitter 20 --loss .05 --blackout 1 --label recovery
    python qa/test_network.py --scenario disconnect --label local
    python qa/test_network.py --scenario host_leave --label local
fi
