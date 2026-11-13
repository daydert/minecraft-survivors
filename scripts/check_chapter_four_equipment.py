"""IV arsenal resources: native model sources, generated icons and bounded atlases."""
import argparse,hashlib,json
from pathlib import Path
from PIL import Image,ImageFilter
ROOT=Path(__file__).resolve().parent.parent
m=json.loads((ROOT/'data/chapter_four_equipment.json').read_text())
a=json.loads((ROOT/'docs/CHAPTER_FOUR_EQUIPMENT_MANIFEST.json').read_text())
checks=0
parser=argparse.ArgumentParser()
parser.add_argument('--icons-only',action='store_true',help='Validate inventory sprites without repeating unchanged mesh-frame checks.')
args=parser.parse_args()

def check(ok,label):
 global checks
 assert ok,label
 checks+=1

for name,spec in a['raw_files'].items():
 check(hashlib.sha256((ROOT/'assets/minecraft'/name).read_bytes()).hexdigest()==spec['sha256'],name+' native bytes')
for name in list(m['held'])+m['sprites']:
 if args.icons_only and name in m['held']:continue
 p=ROOT/'assets/sprites'/(name+'.png');im=Image.open(p).convert('RGBA');spec=a['derived'][name]
 check(list(im.size)==spec['size'] and hashlib.sha256(p.read_bytes()).hexdigest()==spec['sha256'],name+' manifest')
 if name not in m['held']:continue
 meta=m['held'][name];w,h=meta['frame_size']
 check(im.size==(w*16,h*3) and w<=96 and h<=96,name+' bounded atlas')
 for row in range(3):
  for f in range(16):
   frame=im.crop((f*w,row*h,(f+1)*w,(row+1)*h));b=frame.getbbox()
   check(b and b[0]>=2 and b[1]>=2 and b[2]<=w-2 and b[3]<=h-2,f'{name} {row}/{f}: no clipped limbs, tool or wings')
   # Weapon and back wings must share the Steve silhouette. One-pixel joints
   # are permitted by the native rasterizer, large detached tools are not.
   alpha=frame.getchannel('A').filter(ImageFilter.MaxFilter(3))
   points={(x,y) for y in range(h) for x in range(w) if alpha.getpixel((x,y))>0}
   total=len(points);largest=0
   while points:
    queue=[points.pop()];size=0
    while queue:
     x,y=queue.pop();size+=1
     for dx,dy in [(0,1),(0,-1),(1,0),(-1,0),(-1,-1),(-1,1),(1,-1),(1,1)]:
      q=x+dx,y+dy
      if q in points:points.remove(q);queue.append(q)
    largest=max(largest,size)
   check(largest/total>.96,f'{name} {row}/{f}: connected grip and body')
check(len(m['held'])==192,'all 24 held tools × four wing stages × two armour states')
check(all('ch4_pet_'+str(s) in m['sprites'] for s in range(1,5)),'four native pet growth models')
print('CHAPTER_FOUR_EQUIPMENT_ASSETS_RESULT',checks,'checks passed')
