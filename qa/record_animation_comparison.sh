#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
engine=${SURVIVORS_GODOT_BIN:-"$PWD/.tools/Godot_v4.7.2-stable_linux.x86_64"}
baseline=${1:?Pass the preserved before project directory}
cp qa/animation_review.gd "$baseline/qa/animation_review.gd"
cp qa/animation_review_driver.gd "$baseline/qa/animation_review_driver.gd"
"$engine" --path "$baseline" --display-driver wayland --resolution 640x360 --write-movie "$PWD/qa/recordings/animations_before.avi" --fixed-fps 30 -s qa/animation_review.gd -- --report=res://qa/comparison_before.json > qa/recordings/animations_before.log 2>&1
"$engine" --path "$PWD" --display-driver wayland --resolution 640x360 --write-movie "$PWD/qa/recordings/animations_after.avi" --fixed-fps 30 -s qa/animation_review.gd > qa/recordings/animations_after.log 2>&1
python - "$baseline" <<'PY'
import json,sys,shutil
from pathlib import Path
a=Path(sys.argv[1])/'qa/comparison_before.json'
shutil.copy(a,'qa/comparison_before.json')
before=json.loads(a.read_text());after=json.loads(Path('qa/comparison_after.json').read_text())
assert before==after,'The input/seed comparison changed combat results'
print('Before/after combat snapshots match exactly')
PY
for phase in before after; do
    ffmpeg -y -loglevel error -i "qa/recordings/animations_$phase.avi" -vf 'scale=1280:720:flags=neighbor' -c:v libx264 -crf 19 -pix_fmt yuv420p -c:a aac "qa/recordings/animations_$phase.mp4"
done
python qa/video_labels.py
comparison_duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 qa/recordings/animations_after.mp4)
ffmpeg -y -loglevel error -i qa/recordings/animations_before.mp4 -i qa/recordings/animations_after.mp4 -loop 1 -i qa/recordings/comparison_labels.png -filter_complex '[0:v]scale=640:360:flags=neighbor[l];[1:v]scale=640:360:flags=neighbor[r];[l][r]hstack[pair];[2:v][pair]vstack[v]' -map '[v]' -map 1:a -t "$comparison_duration" -r 30 -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac qa/recordings/animations_before_after.mp4
rm qa/recordings/animations_before.avi qa/recordings/animations_after.avi
