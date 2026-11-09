"""Check only the new IV models, source bytes, framing and silhouette integrity."""
import hashlib,json
from pathlib import Path
from PIL import Image,ImageFilter
ROOT=Path(__file__).resolve().parent.parent
m=json.loads((ROOT/'data/chapter_four_mobs.json').read_text());a=json.loads((ROOT/'docs/CHAPTER_FOUR_MOBS_MANIFEST.json').read_text());checks=0

def check(ok,label):
 global checks
 assert ok,label
 checks+=1

for name in m['sprites']:
 p=ROOT/'assets/sprites'/(name+'.png');im=Image.open(p).convert('RGBA');info=a['derived'][name]
 check(list(im.size)==info['size'] and hashlib.sha256(p.read_bytes()).hexdigest()==info['sha256'],name+' reproducible artwork')
for name,s in m['actors'].items():
 im=Image.open(ROOT/'assets/sprites'/(name+'_atlas.png')).convert('RGBA');w,h=s['frame_size']
 check(im.size==(w*s['columns'],h*3),name+' atlas layout')
 for row in range(3):
  for f in range(s['columns']):
   frame=im.crop((f*w,row*h,(f+1)*w,(row+1)*h));b=frame.getbbox()
   check(b and b[0]>0 and b[1]>0 and b[2]<w and b[3]<h,f'{name} direction {row} frame {f} has full limbs and framing')
   # Allow one native pixel of rasterization at thin joints; no major limb may
   # be a detached island. Original transparent texture details can be tiny.
   alpha=frame.getchannel('A').filter(ImageFilter.MaxFilter(3));points={(x,y) for y in range(h) for x in range(w) if alpha.getpixel((x,y))>0};total=len(points);largest=0
   while points:
    queue=[points.pop()];size=0
    while queue:
     x,y=queue.pop();size+=1
     for dx,dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,1),(-1,1),(1,-1)]:
      if (x+dx,y+dy) in points:points.remove((x+dx,y+dy));queue.append((x+dx,y+dy))
    largest=max(largest,size)
   check(largest/total>.96,f'{name} direction {row} frame {f} connected silhouette')
for name,s in a['raw_files'].items():check(hashlib.sha256((ROOT/'assets/minecraft'/name).read_bytes()).hexdigest()==s['sha256'],name+' native bytes')
print('CHAPTER_FOUR_MOBS_ASSETS_RESULT',checks,'checks passed')
