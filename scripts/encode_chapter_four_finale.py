"""Encode the diagnostic finale film: frames, phase music and simulation sound cues."""
from pathlib import Path
import argparse
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "qa/recordings"
TRACKS = {"ch4": ("ancestry.ogg", 0.5), "pyramid": ("pyramid_5.ogg", 0.5), "boss_one": ("boss_one.ogg", 0.55), "boss_two": ("boss_two.ogg", 0.55), "boss_fade": ("boss_two.ogg", 0.18), "coords": ("relic.ogg", 0.5)}


def encode(clean=False, name="finale"):
    data = json.loads((OUT / f"chapter_four_{name}_timeline.json").read_text())
    fps = data["fps"]
    seconds = data["frames"] / fps
    frames = OUT / f"chapter_four_{name}_frames"
    args = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", str(fps), "-i", str(frames / "%05d.png")]
    graph = "[0:v]scale=1280:720:flags=neighbor[v];"
    labels = []
    n = 1
    music = data["music"] + [{"track": "", "time": seconds}]
    for i in range(len(music) - 1):
        track, start, end = music[i]["track"], music[i]["time"], music[i + 1]["time"]
        if track not in TRACKS or end - start < 0.3:
            continue
        file, gain = TRACKS[track]
        args += ["-stream_loop", "-1", "-i", str(ROOT / "assets/audio/chapter_four" / file)]
        length = end - start
        delay = round(start * 1000)
        graph += f"[{n}:a]atrim=0:{length:.3f},asetpts=PTS-STARTPTS,volume={gain},afade=t=in:d=0.8,afade=t=out:st={max(0, length - 1.2):.3f}:d=1.2,adelay={delay}|{delay}[m{n}];"
        labels.append(f"[m{n}]")
        n += 1
    events = {}
    for manifest in ["minecraft_audio", "nether_audio", "end_audio", "v2_audio", "chapter_one_audio", "end_external_audio", "chapter_four_audio", "chapter_four_external_audio"]:
        path = ROOT / f"data/{manifest}.json"
        if path.exists():
            events.update(json.loads(path.read_text()))
    last = {}
    cues = []
    for cue in data["sound_events"]:
        if cue["id"] not in events or cue["time"] - last.get(cue["id"], -1) < 0.12:
            continue
        last[cue["id"]] = cue["time"]
        cues.append(cue)
    for cue in cues[:420]:
        spec = events[cue["id"]]
        variant = spec["variants"][0]
        args += ["-i", str(ROOT / variant["path"].removeprefix("res://"))]
        delay = round(cue["time"] * 1000)
        graph += f'[{n}:a]volume={spec.get("gain", .5) * .7 * variant.get("volume", 1)},adelay={delay}|{delay}[c{n}];'
        labels.append(f"[c{n}]")
        n += 1
    graph += "".join(labels) + f"amix=inputs={len(labels)}:normalize=0,alimiter=limit=0.95,atrim=0:{seconds:.3f},apad=whole_dur={seconds:.3f}[a]"
    target = OUT / f"chapter_four_{name}.mp4"
    args += ["-filter_complex_threads", "1", "-filter_complex", graph, "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-threads", "4", "-preset", "medium", "-crf", "18",
             "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-t", f"{seconds:.3f}", "-movflags", "+faststart", str(target)]
    subprocess.run(args, check=True)
    print(target, round(seconds, 1), "seconds;", len(cues), "sound cues;", data["diagnostic"])
    if clean:
        shutil.rmtree(frames)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--clean", action="store_true")
    parser.add_argument("--name", default="finale")
    args = parser.parse_args()
    encode(args.clean, args.name)
