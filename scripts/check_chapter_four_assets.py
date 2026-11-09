"""Validate the shipped IV pixels and original local-client provenance."""
from pathlib import Path
import hashlib
import json
from PIL import Image
ROOT = Path(__file__).resolve().parent.parent
checks = 0

def check(ok, label):
    global checks
    assert ok, label
    checks += 1

art = json.loads((ROOT/'docs/CHAPTER_FOUR_ASSET_MANIFEST.json').read_text())
assets = json.loads((ROOT/'data/chapter_four_assets.json').read_text())
for name in assets['sprites']:
    spec = art['derived'][name]
    p = ROOT/'assets/sprites'/f'{name}.png'
    image = Image.open(p).convert('RGBA')
    check(list(image.size) == spec['size'], name+' dimensions')
    check(hashlib.sha256(p.read_bytes()).hexdigest() == spec['sha256'], name+' reproducible pixels')
    if name=='ch4_ground':
        check(image.getextrema()[3] == (255,255), 'Ground is completely opaque')
    else:
        check(image.getextrema()[3][1] > 0 and image.getbbox() is not None, name+' has visible pixels')
for name, spec in art['raw_files'].items():
    check(hashlib.sha256((ROOT/'assets/minecraft'/name).read_bytes()).hexdigest()==spec['sha256'], name+' original source bytes')
hand = Image.open(ROOT/'assets/sprites/ch4_hand.png').convert('RGBA')
for frame in range(10):
    alpha = hand.crop((frame*64,0,(frame+1)*64,72)).getchannel('A')
    pixels = {(x,y) for y in range(72) for x in range(64) if alpha.getpixel((x,y))>0}
    total = len(pixels)
    biggest = 0
    while pixels:
        seed = pixels.pop();todo=[seed];size=0
        while todo:
            x,y=todo.pop();size+=1
            for n in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                if n in pixels:pixels.remove(n);todo.append(n)
        biggest=max(biggest,size)
    check(biggest/total>.98, f'Hand frame {frame} is a connected silhouette')
audio = json.loads((ROOT/'docs/CHAPTER_FOUR_AUDIO_MANIFEST.json').read_text())
for name, spec in audio['files'].items():
    check(hashlib.sha256((ROOT/'assets/audio/chapter_four'/name).read_bytes()).hexdigest()==spec['sha256'], name+' original OGG bytes')
print('CHAPTER_FOUR_ASSETS_RESULT',checks,'checks passed')
