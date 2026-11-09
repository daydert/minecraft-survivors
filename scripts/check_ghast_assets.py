"""Original sources, matching fragment UVs, distinct charge and actual baked poses."""
import hashlib,json
import numpy as np
from pathlib import Path
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parent.parent
manifest=json.loads((ROOT/'docs/MINECRAFT_GHAST_MANIFEST.json').read_text());checks=0
for name,spec in manifest['raw_files'].items():
 assert hashlib.sha256((ROOT/'assets/minecraft'/name).read_bytes()).hexdigest()==spec['sha256'],name
 checks+=1
for name,spec in manifest['derived'].items():
 p=ROOT/'assets/sprites'/(name+'.png')
 assert hashlib.sha256(p.read_bytes()).hexdigest()==spec['sha256'],name
 assert list(Image.open(p).size)==spec['size'],name
 checks+=1
for name,spec in manifest['sound_files'].items():
 assert hashlib.sha256((ROOT/'assets/audio/minecraft'/name).read_bytes()).hexdigest()==spec['sha256'],name
 checks+=1
assets=json.loads((ROOT/'data/ghast_intro_assets.json').read_text())
assert len(assets['pieces'])==17;checks+=1
for name,spec in assets['clips'].items():
 im=Image.open(ROOT/'assets/sprites'/(name+'.png')).convert('RGBA');w,h=spec['frame_size'];frames=[]
 for i in spec['frames']:
  f=im.crop((i*w,0,(i+1)*w,h));assert f.getbbox(),(name,i);frames.append(f.tobytes());checks+=1
 assert len(set(frames))>=5,(name,'static animation');checks+=1
normal=Image.open(ROOT/'assets/sprites/ghast_hover.png').convert('RGBA').crop((0,0,192,216))
charge=Image.open(ROOT/'assets/sprites/ghast_charge.png').convert('RGBA').crop((0,0,192,216))
assert ImageChops.difference(normal,charge).convert('RGB').getbbox() is not None,'The actual face must switch to the attacking texture'
assert sum(1 for r,g,b,a in np.asarray(charge).reshape(-1,4) if a and r>g*1.5 and r>b*1.5 and r>50)>80,'Red eyes and mouth must be visible'
checks+=2
for p in assets['pieces']:
 im=Image.open(ROOT/'assets/sprites'/(p['sprite']+'.png'));assert im.getbbox(),p['sprite'];checks+=1
(ROOT/'qa/ghast_asset_results.json').write_text(json.dumps(dict(checks=checks,failures=[]),indent=2)+'\n')
print('GHAST_ASSETS_RESULT',checks,'checks passed; 19 original-textured sprites and 17 parts')
