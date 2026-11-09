"""Verify the new articulated poses and unchanged original texture provenance."""
import hashlib,json
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parent.parent
m=json.loads((ROOT/'docs/MINECRAFT_DUEL_MANIFEST.json').read_text());checks=0
for name,spec in m['raw_files'].items():
 assert hashlib.sha256((ROOT/'assets/minecraft'/name).read_bytes()).hexdigest()==spec['sha256'],name
 checks+=1
for name,spec in m['derived'].items():
 p=ROOT/'assets/sprites'/(name+'.png');assert hashlib.sha256(p.read_bytes()).hexdigest()==spec['sha256'],name
 assert list(Image.open(p).size)==spec['size'],name
 checks+=1
for name,spec in m['sound_files'].items():
 assert hashlib.sha256((ROOT/'assets/audio/minecraft'/name).read_bytes()).hexdigest()==spec['sha256'],name
 checks+=1
assets=json.loads((ROOT/'data/duel_assets.json').read_text())
for name,spec in assets['clips'].items():
 im=Image.open(ROOT/'assets/sprites'/(name+'.png')).convert('RGBA');w,h=spec['frame_size'];frames=[]
 for i in spec['frames']:
  f=im.crop((i*w,0,i*w+w,h));assert f.getbbox(),(name,i);frames.append(f.tobytes());checks+=1
 if name in ['duel_rise','duel_kneel','duel_command']:assert len(set(frames))>=8,(name,'too few distinct poses')
 if name in ['duel_seated','duel_stand']:
  f=im.crop((0,0,w,h));cyan=sum(1 for r,g,b,a in np.asarray(f).reshape(-1,4) if a>0 and g>r*1.35 and b>r*1.15 and g>60)
  assert cyan>=150,(name,'torso not visible',cyan);checks+=1
terrain=json.loads((ROOT/'data/nether_terrain.json').read_text())
assert terrain['width']==128 and len(terrain['soul_sand_cells'])>0
checks+=1
print(f'DUEL_ASSETS_RESULT {checks} checks passed; articulated rise, command, kneeling and original sources')
(ROOT/'qa/duel_asset_results.json').write_text(json.dumps(dict(checks=checks,failures=[]),indent=2)+'\n')
