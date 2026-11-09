"""Validate the shipped badge pixels, native source bytes and Russian glyphs."""
import hashlib,json,re
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parent.parent
m=json.loads((ROOT/'docs/MINECRAFT_ACHIEVEMENTS_MANIFEST.json').read_text());catalog=json.loads((ROOT/'data/achievements.json').read_text());checks=0

def check(ok,label):
 global checks
 assert ok,label
 checks+=1
check(len(catalog)==18 and len({e['id'] for e in catalog})==18,'Exactly eighteen unique achievements (12 + 6 from version 2)')
font=(ROOT/'assets/fonts/minecraft/minecraft_regular.fnt').read_text();glyphs={int(i) for i in re.findall(r'^char id=(\d+)',font,re.M)}
for e in catalog:
 check(bool(e['name']) and bool(e['description']),'A readable Russian name and condition: '+e['id'])
 check(all(ord(c) in glyphs for c in e['name']+e['description']),'All Russian text has native glyphs: '+e['id'])
 check('achievement_'+e['icon'] in m['derived'],'Dedicated native badge: '+e['id'])
check([e['name'] for e in catalog if e.get('secret')]==['Победа?'],'Requested secret name and hidden flag')
for name,spec in m['derived'].items():
 p=ROOT/'assets/sprites'/f'{name}.png';im=Image.open(p).convert('RGBA')
 check(im.size==(32,32),name+' is a crisp 32px badge')
 check(hashlib.sha256(p.read_bytes()).hexdigest()==spec['sha256'],name+' shipped hash')
 check(len(set(im.get_flattened_data()))>8,name+' has real native textured content')
 check(all(im.getpixel((x,0))[:3]==(24,24,24) for x in range(32)),name+' shares the quiet gray frame')
for name,spec in m['raw_files'].items():check(hashlib.sha256((ROOT/'assets/minecraft'/name).read_bytes()).hexdigest()==spec['sha256'],name+' native texture bytes')
for name,spec in m['sound_files'].items():check(hashlib.sha256((ROOT/'assets/audio/minecraft'/name).read_bytes()).hexdigest()==spec['sha256'],name+' native toast bytes')
print('ACHIEVEMENT_ASSETS_RESULT',checks,'checks passed; native badges, audio and Cyrillic glyphs')
