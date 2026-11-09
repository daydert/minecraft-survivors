"""Verify Chapter II's source bytes, every animation frame and runtime art paths."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parent.parent
manifest=json.loads((ROOT/'docs/MINECRAFT_NETHER_MANIFEST.json').read_text());checks=0
for name,entry in manifest['raw_files'].items():
 assert hashlib.sha256((ROOT/'assets/minecraft'/name).read_bytes()).hexdigest()==entry['sha256'],name
 checks+=1
for name,entry in manifest['derived'].items():
 path=ROOT/'assets/sprites'/(name+'.png')
 assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'],name
 assert list(Image.open(path).size)==entry['size'],name
 if entry.get('byte_identical'):
  assert path.read_bytes()==(ROOT/'assets/minecraft/textures'/(entry['sources'][0]+'.png')).read_bytes(),name
 checks+=1
for name,entry in manifest['sound_files'].items():
 assert hashlib.sha256((ROOT/'assets/audio/minecraft'/name).read_bytes()).hexdigest()==entry['sha256'],name
 checks+=1
animations=json.loads((ROOT/'data/nether_animations.json').read_text())
for name,spec in animations['actors'].items():
 im=Image.open(ROOT/'assets/sprites'/(name+'_atlas.png')).convert('RGBA');w,h=spec['frame_size']
 assert im.size==(w*spec["columns"],h*3),name
 assert spec['side_facing']=='right'
 for row in range(3):
  frames=[]
  for state,clip in spec['states'].items():
   for index in range(len(clip['durations'])):
    x=(clip['start']+index)*w;frame=im.crop((x,row*h,x+w,(row+1)*h))
    assert frame.getbbox(),(name,row,state,index)
    if state=='walk':frames.append(frame.tobytes())
    checks+=1
  assert len(set(frames))>=4,(name,'walk poses')
 assert im.crop((0,0,w,h)).tobytes()!=im.crop((0,h,w,2*h)).tobytes(),name+' front/back'
 checks+=3
assets=json.loads((ROOT/'data/nether_assets.json').read_text())
for name,spec in assets['clips'].items():
 im=Image.open(ROOT/'assets/sprites'/(name+'.png'))
 assert im.width>=max(spec['frames'])*spec['frame_size'][0]
 checks+=1
print(f'NETHER_ASSETS_RESULT {checks} checks passed; {len(animations["actors"])} actors, original local Minecraft {manifest["version"]}')
(ROOT/'qa/nether_asset_results.json').write_text(json.dumps(dict(checks=checks,failures=[]),indent=2)+'\n')
