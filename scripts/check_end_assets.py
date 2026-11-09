"""Independent checks of final PNGs, vanilla hashes and unchanged cooperative rules."""
import hashlib,json,re,sys
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parent.parent
m=json.loads((ROOT/'docs/MINECRAFT_END_MANIFEST.json').read_text());checks=0

def check(value,label):
 global checks
 assert value,label
 checks+=1
for name,spec in m['derived'].items():
 p=ROOT/'assets/sprites'/f'{name}.png';im=Image.open(p)
 check(list(im.size)==spec['size'],name+' dimensions')
 check(hashlib.sha256(p.read_bytes()).hexdigest()==spec['sha256'],name+' hash')
 check(im.getbbox() is not None,name+' nonempty final pixels')
 if name.endswith('_atlas') and name!='end_dragon_atlas':
  a=json.loads((ROOT/'data/end_animations.json').read_text())['actors'][name[:-6]];w,h=a['frame_size']
  for y in range(3):
   for x in range(a["columns"]):check(im.crop((x*w,y*h,(x+1)*w,(y+1)*h)).getbbox() is not None,f'{name} actual frame {x}/{y}')
for name,spec in m['raw_files'].items():check(hashlib.sha256((ROOT/'assets/minecraft'/name).read_bytes()).hexdigest()==spec['sha256'],name+' original vanilla bytes')
for name,spec in m['sound_files'].items():check(hashlib.sha256((ROOT/'assets/audio/minecraft'/name).read_bytes()).hexdigest()==spec['sha256'],name+' original OGG bytes')
for name,sha in json.loads((ROOT/'qa/end_frozen_files.json').read_text()).items():check(hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==sha,name+' remains unchanged')
terrain=json.loads((ROOT/'data/end_terrain.json').read_text());land=set(terrain['solid_cells']);todo=[64*128+64];seen=set(todo)
while todo:
 v=todo.pop()
 for n in [v-1,v+1,v-128,v+128]:
  if n in land and n not in seen:seen.add(n);todo.append(n)
check(len(seen)==len(land),'Every island landing connects to the starting plateau')
bullet=Image.open(ROOT/'assets/sprites/shulker_bullet.png').convert('RGBA')
check(bullet.size==(12,12),'Shulker bullet is a baked model sprite, not the raw 64x32 UV layout')
check(bullet.getbbox() is not None and bullet.getchannel('A').getextrema()==(0,255),'Shulker bullet has an isolated opaque projectile silhouette')
atlas_names={'experience_orb','end_dragon_atlas'}
for data_file in ['minecraft_assets','nether_assets','ghast_intro_assets','duel_assets','end_assets']:
 atlas_names.update(json.loads((ROOT/f'data/{data_file}.json').read_text()).get('clips',{}))
for data_file in ['animations','nether_animations','end_animations']:
 atlas_names.update(name+'_atlas' for name in json.loads((ROOT/f'data/{data_file}.json').read_text()).get('actors',{}))
direct_sprites=set(re.findall(r'\bg\.sprite\("([A-Za-z_0-9]+)"',(ROOT/'scripts/end_renderer.gd').read_text()))
check(not direct_sprites.intersection(atlas_names),'End renderer never shrinks a complete animation atlas through the plain sprite helper')
# The chapter IV ground must be opaque; a transparent scorch overlay looked like void.
teaser=Image.open(ROOT/'assets/sprites/end_teaser_ground.png').convert('RGBA')
check(teaser.size==(640,360) and teaser.getchannel('A').getextrema()==(255,255),'Chapter IV has an opaque floor beneath the entire scene')
check(sum(1 for r,g,b,a in teaser.crop((0,170,640,360)).get_flattened_data() if r>g*1.5 and r>b*1.2)>60000,'The teaser floor has visible blood-red terrain, not empty sky')
# Content checks use the resulting colors, not only declared meshes.
image=Image.open(ROOT/'assets/sprites/endersteve_atlas.png').convert('RGBA')
check(sum(1 for r,g,b,a in image.get_flattened_data() if a and b>r*.9 and b>g*1.4)>200,'Corruption is visible in the final EnderSteve frames')
dragon=json.loads((ROOT/'data/end_dragon.json').read_text());atlas=Image.open(ROOT/'assets/sprites/end_dragon_atlas.png')
for row in range(dragon['directions']):
 for col in range(dragon['columns']):
  w,h=dragon['frame_size'];im=atlas.crop((col*w,row*h,(col+1)*w,(row+1)*h));bbox=im.getbbox()
  check(bbox is not None and bbox[0]>0 and bbox[2]<w and bbox[1]>0 and bbox[3]<h,'Whole connected dragon is not clipped in any baked pose')
check(sum(dragon['joints'].values())>=30,'Dragon uses a complete articulated 3D hierarchy')
# Inspect the final alpha silhouette: detached long legs must not pass merely
# because every frame contains some opaque pixels.
def components(image):
 alpha=image.getchannel('A');w,h=image.size
 todo={(x,y) for y in range(h) for x in range(w) if alpha.getpixel((x,y))}
 sizes=[]
 while todo:
  work=[todo.pop()];size=0
  while work:
   x,y=work.pop();size+=1
   for dx,dy in [(-1,-1),(0,-1),(1,-1),(-1,0),(1,0),(-1,1),(0,1),(1,1)]:
    q=(x+dx,y+dy)
    if q in todo:todo.remove(q);work.append(q)
  sizes.append(size)
 return sorted(sizes,reverse=True)
for name in ['enderman','dispenser_enderman']:
 image=Image.open(ROOT/'assets/sprites'/f'{name}_atlas.png').convert('RGBA')
 for row in range(3):
  for frame in range(22):
   im=image.crop((frame*48,row*64,(frame+1)*48,(row+1)*64))
   check(len([n for n in components(im) if n>3])==1,f'{name} legs join the torso in final frame {row}/{frame}')
   box=im.getbbox();alpha=im.getchannel('A')
   check(all(any(alpha.getpixel((x,y)) for x in range(48)) for y in range(box[1],box[3])),f'{name} has no transparent gap between hips and feet {row}/{frame}')
# Compare the actual membrane UV and endpoint movement against the independent
# pinned Mojang reference, including the full elbow seam across the membrane.
import math,numpy as np
from bake_end_dragon import wing_mesh,wing_angles
from bake_minecraft_characters import rotation
from import_minecraft_assets import Importer,find_client
_,jar,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(jar)
reference=json.loads((ROOT/'docs/references/end/ender_dragon.geo.json').read_text())['minecraft:geometry'][0]['bones']
native={b['name']:b for b in reference}
check(native['wing']['cubes'][1]['uv']==[-56,88] and native['wingtip']['cubes'][1]['uv']==[-56,144],'Wing membranes match native negative-X UV orientation')
for i in range(24):
 phase=i/24*math.tau;angles,elbow=wing_angles('flight',phase);matrix=rotation(*angles)
 model=wing_mesh(imp.tex('entity/enderdragon/dragon'),'flight',phase)
 membranes=[(v,rect) for v,tex,rect,shade in model if rect in [(0,144,56,-56),(0,200,56,-56)]]
 check(len(membranes)==2,'Each wing has one correctly sampled inner and outer membrane')
 for verts,rect in membranes:
  tex=imp.tex('entity/enderdragon/dragon')
  check(all(tex.getpixel((x,int(rect[1]-1)))[3]>0 for x in range(56)),'The opaque membrane edge attaches along the entire leading wing bone')
 spread=56*(math.cos(angles[2])+math.cos(angles[2]+elbow))
 check(spread>112*.74,'The elevated game view retains the dragon wingspan on every upstroke')
 seam_inner=np.array([[-56,0,2],[-56,0,58]])@matrix.T
 # Points at outer local x=0 lie exactly on the elbow axis in every flap.
 seam_outer=(np.array([[0,0,2],[0,0,58]])@rotation(0,0,elbow).T+np.array([-56,0,0]))@matrix.T
 check(np.allclose(seam_inner,seam_outer),'The elbow seam stays closed throughout the wing beat')
 check(all(np.any(np.all(np.isclose(v,point),axis=1)) for point in seam_inner for v,rect in membranes),'Both final membrane meshes meet at the actual elbow endpoints')
for name,spec in m.get('model_references',{}).items():check(hashlib.sha256((ROOT/'docs/references/end'/name).read_bytes()).hexdigest()==spec['sha256'],'Pinned Mojang model reference '+name)
steve=Image.open(ROOT/'assets/sprites/steve_atlas.png').convert('RGBA')
for name in ['endersteve','endersteve_final']:
 actor=Image.open(ROOT/'assets/sprites'/f'{name}_atlas.png').convert('RGBA')
 meta=json.loads((ROOT/'data/end_animations.json').read_text())['actors'][name]
 check(meta['shadow_size']==[8,3],'EnderSteve shadow matches the player instead of the padded atlas dimensions')
 for row in range(3):
  a=steve.crop((0,row*32,32,(row+1)*32)).getbbox()
  b=actor.crop((0,row*96,96,(row+1)*96)).getbbox()
  check(abs((b[3]-b[1])-(a[3]-a[1]))<=2,'EnderSteve keeps the player body height in native pixels in every direction')
for name in m['derived']:
 if not name.startswith('end_held_'):continue
 image=Image.open(ROOT/'assets/sprites'/f'{name}.png')
 for row in range(3):
  for frame in range(24):
   bbox=image.crop((frame*64,row*64,(frame+1)*64,(row+1)*64)).getbbox()
   check(bbox is not None and min(bbox[:2])>0 and max(bbox[2:])<64,'Palm-bound Steve and full tool remain inside every frame')
(ROOT/'qa/end_asset_results.json').write_text(json.dumps({'checks':checks,'failures':[]},indent=2)+'\n')
print('END_ASSETS_RESULT',checks,'checks passed; native textures, articulated dragon and frozen coop files')
