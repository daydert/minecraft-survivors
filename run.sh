#!/bin/sh
cd "$(dirname "$0")" || exit 1
if [ -n "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    set -- --display-driver wayland "$@"
fi
if [ -x builds/linux/MinecraftSurvivors.x86_64 ]; then
    exec builds/linux/MinecraftSurvivors.x86_64 "$@"
elif [ -x .tools/Godot_v4.7.2-stable_linux.x86_64 ]; then
    exec .tools/Godot_v4.7.2-stable_linux.x86_64 --path . "$@"
elif command -v godot >/dev/null 2>&1; then
    exec godot --path . "$@"
else
    printf '%s\n' 'Откройте project.godot в Godot 4.7.2 или распакуйте готовую Linux-сборку.'
    exit 1
fi
