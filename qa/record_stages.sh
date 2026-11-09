#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
engine=./.tools/Godot_v4.7.2-stable_linux.x86_64
mkdir -p qa/recordings
for stage in foundation progression combat evolution; do
    frames=300
    if [ "$stage" = foundation ]; then frames=780; fi
    "$engine" --path . --display-driver wayland --rendering-method gl_compatibility --resolution 640x360 --write-movie "qa/recordings/$stage.avi" --fixed-fps 30 --quit-after "$frames" -- --record-stage="$stage" > "qa/recordings/$stage.log" 2>&1
    ffmpeg -y -loglevel error -i "qa/recordings/$stage.avi" -vf 'scale=1280:720:flags=neighbor' -c:v libx264 -crf 24 -pix_fmt yuv420p -c:a aac "qa/recordings/$stage.mp4"
    rm "qa/recordings/$stage.avi"
done
