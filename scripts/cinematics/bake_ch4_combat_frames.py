"""Rasterize Blender evaluated, connected UV geometry in the native IV style."""
from pathlib import Path
import sys,json,math
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[2];sys.path.insert(0,str(R/'scripts'))
from import_minecraft_assets import bake
j=json.loads((R/'qa/ch4_combat_polish/blender/evaluated_meshes.json').read_text());cache={};meta={'sprites':[],'poses':{}}
for kind,spec in j.items():
 name='ch4_spiral_spike' if kind=='spike' else 'ch4p_'+kind
 frame=(32,40) if kind=='spike' else (48,56);anchor=(16,38) if kind=='spike' else (24,50)
 yaws=[-35] if kind=='spike' else [0,180,-55]
 atlas=Image.new('RGBA',(frame[0]*len(spec['frames']),frame[1]*len(yaws)))
 for i,raw in enumerate(spec['frames']):
  mesh=[]
  for face in raw:
   p=Path(face['texture'])
   if p not in cache:cache[p]=Image.open(p).convert('RGBA')
   mesh.append((np.array(face['verts']),cache[p],face['uv'],face['shade']))
  for row,yaw in enumerate(yaws):atlas.paste(bake(mesh,frame,.86,anchor,yaw,20),(i*frame[0],row*frame[1]))
 if kind=='spike':
  bbox=atlas.getbbox();atlas=atlas.crop((bbox[0],bbox[1],bbox[2],39))
 atlas.save(R/'assets/sprites'/(name+'.png'))
 meta['sprites'].append(name)
 if kind!='spike':meta['poses'][kind]={'texture':name,'frame':frame,'anchor':anchor,'fps':12,'count':len(spec['frames']),'length':spec['length']}
 print(name,atlas.size,flush=True)
(R/'data/chapter_four_combat_animations.json').write_text(json.dumps(meta,indent=2)+'\n')
