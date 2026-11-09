"""Check unmodified vanilla audio/GUI/font sources and full presentation coverage."""
import hashlib
import json
import re
from pathlib import Path

from import_minecraft_assets import ROOT

manifest=json.loads((ROOT/"docs/MINECRAFT_PRESENTATION_MANIFEST.json").read_text())
events=json.loads((ROOT/"data/minecraft_audio.json").read_text())
checks=0


def check(ok,label):
    global checks
    assert ok,label
    checks+=1


for filename,source in manifest["sound_files"].items():
    data=(ROOT/"assets/audio/minecraft"/filename).read_bytes()
    check(hashlib.sha1(data).hexdigest()==source["sha1"],"Original sound bytes: "+filename)
    check(data[:4]==b"OggS","Real Ogg container: "+filename)
for name,source in manifest["gui_sources"].items():
    check(hashlib.sha256((ROOT/f"assets/sprites/{name}.png").read_bytes()).hexdigest()==source["sha256"],
          "Original GUI sprite: "+name)
for name,checksum in manifest["font_sources"].items():
    check(hashlib.sha256((ROOT/"assets/fonts/minecraft"/Path(name).name).read_bytes()).hexdigest()==checksum,
          "Original glyph bitmap: "+name)
music=ROOT/manifest["music"]["output"]
check(hashlib.sha256(music.read_bytes()).hexdigest()==manifest["music"]["sha256"],"User music integrity")
if "boss_music" in manifest:
    boss=ROOT/manifest["boss_music"]["output"]
    check(hashlib.sha256(boss.read_bytes()).hexdigest()==manifest["boss_music"]["sha256"],"Herobrine battle music integrity")
check(not list((ROOT/"assets/audio").rglob("*.wav")),"All generated WAV resources removed")
for code in re.findall(r'sound\("([a-z_]+)"', (ROOT/"scripts/world.gd").read_text()):
    if code=="hurt_":continue
    check(code in events,"Mapped gameplay sound event: "+code)
check("select" in events,"Minecraft click event is mapped")
for name in ["regular","bold"]:
    text=(ROOT/f"assets/fonts/minecraft/minecraft_{name}.fnt").read_text()
    chars=set(map(int,re.findall(r'^char id=(\d+)',text,re.M)))
    for char in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя":
        check(ord(char) in chars,"Minecraft glyph: "+name+" "+char)
    check('smooth=0 aa=1' in text,"Unsmoothed bitmap font: "+name)

result={"checks":checks,"failures":[],"original_sound_files":len(manifest["sound_files"]),
        "events":len(events),"glyphs":manifest["glyphs"],"minecraft_version":manifest["version"]}
(ROOT/"qa/presentation_asset_results.json").write_text(json.dumps(result,indent=2)+"\n")
print(f"PRESENTATION_ASSETS_RESULT {checks} checks passed; {len(events)} vanilla sound events, Minecraft bitmap font")
