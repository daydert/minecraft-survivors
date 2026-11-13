#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
engine=${SURVIVORS_GODOT_BIN:-./.tools/Godot_v4.7.2-stable_linux.x86_64}
case $("$engine" --version) in 4.7.2.stable*) ;; *) printf '%s\n' 'Use Godot 4.7.2 stable with matching export templates'; exit 1 ;; esac
mkdir -p builds/linux builds/windows
"$engine" --headless --path . --export-release 'Linux' builds/linux/MinecraftSurvivors.x86_64
"$engine" --headless --path . --export-release 'Windows Desktop' builds/windows/MinecraftSurvivors.exe
