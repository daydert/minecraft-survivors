"""All directions and useful action poses at native resolution and nearest 4x."""
from pathlib import Path
from PIL import Image, ImageDraw
import json
data=json.loads(Path('data/animations.json').read_text())['actors']
states=['idle','walk','windup','attack','recover','hurt']
im=Image.new('RGBA',(6*80,8*3*76),'#40563a');d=ImageDraw.Draw(im)
for i,(name,spec) in enumerate(data.items()):
 a=Image.open(f'assets/sprites/{name}_atlas.png');w,h=spec['frame_size']
 for direction in range(3):
  y=(i*3+direction)*76
  for j,state in enumerate(states):
   d.text((j*80+2,y+2),f'{name[:5]} {state[:4]}',fill='#e7e6c7')
   clip=spec['states'][state];f=clip['start']+(2 if state in ['walk','windup'] else 0)
   tile=a.crop((f*w,direction*h,(f+1)*w,(direction+1)*h))
   im.alpha_composite(tile,(j*80+(80-w)//2,y+12))
im.save('qa/animation_all_poses_native.png')
im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST).save('qa/animation_all_poses_4x.png')
print('All states/directions proof written')
