"""Large vanilla Ghast and UV-preserving shell fragments, using the existing baker."""
import hashlib,json,math
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from import_minecraft_assets import ROOT,Importer,find_client,bake,box
from bake_minecraft_characters import part,transform

LENGTHS=[11,8,13,9,14,10,12,7,11]
SKIN='entity/ghast/ghast'
CHARGED='entity/ghast/ghast_shooting'

def native_uv(mesh,tex):
 # Java 1.21.11 supplies a 128x64 atlas for the classic 64x32 layout.
 factor=tex.width/64
 return [(v,t,tuple(value*factor for value in r),s) for v,t,r,s in mesh]

def ghast(imp,phase,charged=False):
 tex=imp.tex(CHARGED if charged else SKIN)
 mesh=part(tex,(-8,14,-8),(16,16,16),(0,0))
 for i,length in enumerate(LENGTHS):
  x=(i%3-1)*5;z=(i//3-1)*5
  mesh+=part(tex,(x-1,14-length,z-1),(2,length,2),(0,0),pivot=(x,14,z),angles=(math.sin(phase+i*.7)*.14,0,math.cos(phase+i)*.06))
 return native_uv(mesh,tex)

def shell_piece(imp,ix,iy,iz):
 tex=imp.tex(CHARGED);inside=imp.tex('block/bone_block_side')
 full={name:(v,t,r,s) for name,(v,t,r,s) in zip(['north','south','east','west','up','down'],box(tex,(-8,14,-8),(16,16,16)))}
 piece=box(tex,(-8+ix*8,14+iy*8,-8+iz*8),(8,8,8))
 mesh=[]
 for name,(v,_,_,shade) in zip(['north','south','east','west','up','down'],piece):
  exterior={'north':iz==0,'south':iz==1,'east':ix==1,'west':ix==0,'up':iy==1,'down':iy==0}[name]
  if exterior:
   fv,_,rect,_=full[name];u,vv,w,h=rect
   dx=fv[1]-fv[0];dy=fv[3]-fv[0];p=v[0]-fv[0]
   rx=float(p@dx/(dx@dx));ry=float(p@dy/(dy@dy))
   factor=tex.width/64
   mesh.append((v,tex,(round((u+rx*w)*factor),round((vv+ry*h)*factor),8*factor,8*factor),shade))
  else:mesh.append((v,inside,(0,0,16,16),shade*.8))
 center=np.array([-4+ix*8,18+iy*8,-4+iz*8])
 return transform(mesh,offset=-center)

def sounds(version):
 prism=Path.home()/'.local/share/PrismLauncher'
 meta=json.loads((prism/f'meta/net.minecraft/{version}.json').read_text())
 index=json.loads((prism/f"assets/indexes/{meta['assetIndex']['id']}.json").read_text())['objects']
 def raw(name):
  digest=index['minecraft/'+name]['hash'];data=(prism/f'assets/objects/{digest[:2]}/{digest}').read_bytes()
  assert hashlib.sha1(data).hexdigest()==digest
  return data
 events=json.loads(raw('sounds.json'));mapping={};manifest={}
 for ident,event,gain in [('ghast_intro_cry','entity.ghast.ambient',.7),('ghast_intro_charge','entity.ghast.warn',.65),('ghast_intro_death','entity.ghast.death',.65),('ghast_intro_burst','entity.generic.explode',.6)]:
  variants=[]
  for spec in events[event]['sounds']:
   spec={'name':spec} if isinstance(spec,str) else spec
   name=spec['name'].replace('minecraft:','');data=raw('sounds/'+name+'.ogg');filename=name.replace('/','_')+'.ogg'
   (ROOT/'assets/audio/minecraft'/filename).write_bytes(data)
   variants.append(dict(path='res://assets/audio/minecraft/'+filename,volume=spec.get('volume',1),pitch=spec.get('pitch',1)))
   manifest[filename]=dict(source='minecraft/sounds/'+name+'.ogg',sha256=hashlib.sha256(data).hexdigest())
  mapping[ident]=dict(minecraft_event=event,gain=gain,variants=variants)
 (ROOT/'data/ghast_intro_audio.json').write_text(json.dumps(mapping,indent=2)+'\n')
 return manifest

def generate():
 version,jar,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(jar)
 for name,charging in [('ghast_hover',False),('ghast_charge',True)]:
  strip=Image.new('RGBA',(192*8,216))
  for i in range(8):
   image=bake(ghast(imp,i*math.tau/8,charging),(192,216),6,(96,196),yaw=0,elevation=20)
   strip.paste(image,(i*192,0))
  imp.save(strip,name,[CHARGED if charging else SKIN])
  imp.clips[name]=dict(frame_size=[192,216],frames=list(range(8)),durations=[.14]*8)
 pieces=[]
 for index in range(8):
  ix=index%2;iy=(index//2)%2;iz=index//4
  mesh=shell_piece(imp,ix,iy,iz);strip=Image.new('RGBA',(80*8,80))
  for frame in range(8):
   angle=frame*math.tau/8
   rotated=transform(mesh,(math.sin(angle)*.35,angle,math.cos(angle)*.25))
   strip.paste(bake(rotated,(80,80),6,(40,40),yaw=0,elevation=20),(frame*80,0))
  name='ghast_piece_'+str(index);imp.save(strip,name,[CHARGED,'block/bone_block_side'])
  imp.clips[name]=dict(frame_size=[80,80],frames=list(range(8)),durations=[.09]*8)
  pieces.append(dict(sprite=name,center=[-4+ix*8,18+iy*8,-4+iz*8],size=[80,80]))
 for i,length in enumerate(LENGTHS):
  mesh=native_uv(part(imp.tex(SKIN),(-1,-length/2,-1),(2,length,2),(0,0)),imp.tex(SKIN))
  name='ghast_leg_'+str(i);imp.save(bake(mesh,(32,104),6,(16,52),yaw=0,elevation=20),name,[SKIN])
  pieces.append(dict(sprite=name,center=[(i%3-1)*5,14-length/2,(i//3-1)*5],size=[32,104]))
 assets=dict(clips=imp.clips,sprites=list(imp.derived),pieces=pieces)
 (ROOT/'data/ghast_intro_assets.json').write_text(json.dumps(assets,indent=2)+'\n')
 manifest=dict(version=version,client_jar=str(jar),raw_files=imp.files,derived=imp.derived,sound_files=sounds(version),notes='Original Ghast textures and cuboid UVs; large animated projection and matching physical fragments. Existing Minecraft importer/rasterizer. No imagegen.')
 (ROOT/'docs/MINECRAFT_GHAST_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 preview=Image.new('RGBA',(576,432),(24,24,24,255))
 for i,name in enumerate(['ghast_hover','ghast_charge']):
  im=Image.open(ROOT/'assets/sprites'/(name+'.png')).crop((0,0,192,216));preview.alpha_composite(im,(i*192,0))
 for i in range(8):
  im=Image.open(ROOT/'assets/sprites'/f'ghast_piece_{i}.png').crop((0,0,80,80));preview.alpha_composite(im,((i%4)*120,(i//4)*100+224))
 preview.save(ROOT/'qa/ghast_intro_assets.png')
 print('GHAST_BAKE',len(imp.derived),'sprites; 17 separate UV-preserving fragments',flush=True)

if __name__=='__main__':generate()
