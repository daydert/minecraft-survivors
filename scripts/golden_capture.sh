#!/bin/sh
# Renders every --capture mode into qa/<dir>/ for pixel comparison (default: qa/golden_new).
set -u
cd "$(dirname "$0")/.."
engine=${SURVIVORS_GODOT_BIN:-./.tools/Godot_v4.7.2-stable_linux.x86_64}
out=${1:-qa/golden_new}
mkdir -p "$out"; keep=$(mktemp -d)
modes="menu level pause result chest stats achievements achievement_toast boss_lab finale portal fall chapter_end herobrine_loss herobrine_seated herobrine_rise herobrine_kneel herobrine_rift herobrine_wipe nether_boss nether_end nether_inventory nether_portal_camera nether_ghast nether_ghast_charge nether_ghast_burst nether_ghast_reveal end_arrival end_choices end_inventory end_recipes end_scale end_flight end_crystals end_dragon end_dragon_rage end_dragon_death end_betrayal end_last_duel end_rekindle end_jump end_steve_death end_victory end_overworld end_shulker battle dawn nether_battle low_hp"
for m in $modes; do
  [ -f "qa/$m.png" ] && mv "qa/$m.png" "$keep/$m.png"
  timeout 60 "$engine" --path . --display-driver wayland --audio-driver Dummy -- --capture=$m >/dev/null 2>&1
  if [ -f "qa/$m.png" ]; then mv "qa/$m.png" "$out/$m.png"; [ -f "$keep/$m.png" ] && mv "$keep/$m.png" "qa/$m.png"; else echo "MISSING $m"; fi
done
echo "CAPTURED $(ls "$out" | wc -l)"
