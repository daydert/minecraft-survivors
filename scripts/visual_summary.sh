#!/bin/sh
# Runs every visual test and prints PASS / ERROR counts per test (for before/after comparison).
cd "$(dirname "$0")/.."
engine=${SURVIVORS_GODOT_BIN:-./.tools/Godot_v4.7.2-stable_linux.x86_64}
for t in $(grep -oE "qa/test_[a-z_]+\.gd" scripts/verify.sh | sort -u); do
  case "$t" in *visual*|*character_facing*|*minecraft_render*|*presentation*) ;; *) continue;; esac
  out=$(timeout 300 "$engine" --path . --display-driver wayland --audio-driver Dummy -s "$t" 2>&1)
  echo "$t pass=$(echo "$out" | grep -ac '^PASS') errors=$(echo "$out" | grep -acE '^(ERROR|SCRIPT ERROR)') $(echo "$out" | grep -aoE '[A-Z_]+RESULT.*' | tail -1)"
done
