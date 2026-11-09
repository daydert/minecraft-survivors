"""Articulated dragon: render the complete connected 3D hierarchy through one z-buffer.

Vanilla 256x256 UV atlas; jaw, five neck and twelve tail joints, two articulated
wing pairs and four articulated legs. No independent screen-space bone sprites.
"""
from __future__ import annotations
import json,math
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from import_minecraft_assets import ROOT,Importer,find_client,bake
from bake_minecraft_characters import part,transform

SIZE=(320,256);ANCHOR=(160,152);DIRECTIONS=16
STATES={'flight':(0,12),'perch':(12,8),'roar':(20,4)}

def wing_angles(state,phase):
 # Keep Mojang's counter-moving joints and phase offset, with a smaller
 # amplitude for the game's elevated 2D view. A full 3D upstroke projected
 # edge-on made the whole silhouette collapse into the body.
 if state=='perch':return (.09,0,.12),-.12
 return (.09-math.cos(phase)*.1,0,.1+math.sin(phase)*.5),-(math.sin(phase+2)+.5)*.32

def membrane(tex,origin,uv):
 # This rasterizer's +Z maps to increasing V on an upper face, opposite
 # the native zero-height wing. V must run backwards: the full opaque edge
 # attaches to the leading bone, rather than leaving a gray bar in space.
 faces=part(tex,origin,(56,0,56),uv)
 expected=(0,uv[1],56,56)
 return [(v,t,(0,uv[1]+56,56,-56),shade) for v,t,rect,shade in faces if rect==expected]

def wing_mesh(tex,state,phase):
 # Build the native negative-X wing before mirroring the whole hierarchy.
 # In this orientation UV u=0 belongs at the elbow, u=56 at the shoulder.
 # Using a positive-X plane without mirroring its UV detached the ribs.
 inner=part(tex,(-56,-4,-4),(56,8,8),(112,88))
 inner+=membrane(tex,(-56,0,2),(-56,88))
 outer=part(tex,(-56,-2,-2),(56,4,4),(112,136))
 outer+=membrane(tex,(-56,0,2),(-56,144))
 root_angles,elbow_angle=wing_angles(state,phase)
 outer=transform(outer,(0,0,elbow_angle),offset=(-56,0,0))
 return transform(inner+outer,root_angles)

def skeleton(imp,state,phase):
 tex=imp.tex('entity/enderdragon/dragon').copy();tex.alpha_composite(imp.tex('entity/enderdragon/dragon_eyes'))
 flap=math.sin(phase);perch=state=='perch';roar=state=='roar'
 lean=.05*math.sin(phase) if not perch else 0
 m=part(tex,(-12,25,-16),(24,24,64),(0,0))
 for z in [0,20,40]:m+=part(tex,(-1,49,z),(2,6,12),(220,53))
 # Segments join end-to-end; no gaps open as the chain bends.
 neck_root=np.array([0.,44.,-16.]);yaw=0
 for j in range(5):
  yaw=math.sin(phase*.6-j*.3)*(.035 if perch else .06)
  pitch=(-.08 if not perch else .12)+math.sin(phase-j*.4)*.025
  segment=part(tex,(-5,-5,-10),(10,10,10),(192,104))+part(tex,(-1,5,-7),(2,4,6),(48,0))
  m+=transform(segment,(pitch,yaw,0),offset=neck_root)
  neck_root+=np.array([-math.sin(yaw)*10,math.sin(pitch)*10,-math.cos(yaw)*10])
 head=part(tex,(-8,-1,-15),(16,16,16),(112,30))
 head+=part(tex,(-6,-1,-29),(12,5,16),(176,44))
 for sign in [-1,1]:
  head+=part(tex,(sign*5-1,15,-2),(2,4,6),(0,0))
  head+=part(tex,(sign*5-1,4,-28),(2,2,4),(112,0))
 jaw=part(tex,(-6,-4,-24),(12,4,16),(176,65))
 jaw=transform(jaw,(-(.16+max(0,flap)*.35 if perch or roar else .035),0,0),pivot=(0,0,-9))
 head+=jaw
 m+=transform(head,(.1 if perch else -.02,yaw*1.5,0),offset=neck_root)
 # The tail's shrinking links follow a continuous curve instead of rotating PNGs.
 tail_root=np.array([0.,36.,48.])
 for j in range(12):
  width=max(3,10-j*.5);length=10
  yaw=math.sin(phase*.7-j*.36)*(.1+j*.012)
  pitch=.035+math.sin(phase-j*.3)*.025
  seg=part(tex,(-width/2,-width/2,0),(width,width,length),(192,104))
  seg+=part(tex,(-1,width/2,2),(2,3,5),(48,0))
  m+=transform(seg,(pitch,yaw,0),offset=tail_root)
  tail_root+=np.array([math.sin(yaw)*length,-math.sin(pitch)*length,math.cos(yaw)*length])
 for sign in [-1,1]:
  wing=transform(wing_mesh(tex,state,phase),scale=(-sign,1,1),offset=(sign*12,45,-8))
  m+=wing
  for rear in [False,True]:
   z=30 if rear else -5;y=29 if rear else 37;x=sign*(11 if rear else 10)
   upper=part(tex,(-4,-18,-4),(8,18,8),(0,0) if rear else (112,104))
   lower=part(tex,(-3,-16,-3),(6,16,6),(0,32) if rear else (144,104))
   lower+=part(tex,(-4,-17,-9),(8,4,12),(112,0))
   bend=.55 if not perch else -.15
   leg=upper+transform(lower,(-bend,0,0),offset=(0,-16,0))
   m+=transform(leg,(.4 if not perch else -.1,0,sign*.12),offset=(x,y,z))
 return transform(m,(lean,0,0),pivot=(0,38,12),offset=(0,math.sin(phase)*1.5 if not perch else 0,0))

def generate():
 version,jar,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(jar)
 atlas=Image.new('RGBA',(SIZE[0]*24,SIZE[1]*DIRECTIONS))
 for row in range(DIRECTIONS):
  yaw=row*360/DIRECTIONS
  for state,(start,count) in STATES.items():
   for i in range(count):
    mesh=skeleton(imp,state,i/count*math.tau)
    pic=bake(mesh,SIZE,.9,ANCHOR,yaw=yaw,elevation=27)
    atlas.paste(pic,((start+i)*SIZE[0],row*SIZE[1]))
  print('Dragon direction',row+1,'/',DIRECTIONS,flush=True)
 imp.save(atlas,'end_dragon_atlas',['entity/enderdragon/dragon','entity/enderdragon/dragon_eyes'],origin='Local vanilla dragon UVs; complete articulated 3D mesh rendered through shared depth buffer, 16 directions and original game animation.')
 spec=dict(frame_size=SIZE,anchor=ANCHOR,directions=DIRECTIONS,columns=24,states={k:dict(start=s,count=c,fps=12 if k=='flight' else 8) for k,(s,c) in STATES.items()},joints=dict(neck=5,tail=12,wings=4,jaw=1,legs=8),projection_elevation=27,source_texture='entity/enderdragon/dragon',wing_reference='docs/references/end/sources.json')
 (ROOT/'data/end_dragon.json').write_text(json.dumps(spec,indent=2)+'\n')
 manifest_path=ROOT/'docs/MINECRAFT_END_MANIFEST.json';manifest=json.loads(manifest_path.read_text())
 for key in list(manifest['derived']):
  if key.startswith('dragon_') and key!='dragon_fireball':manifest['derived'].pop(key)
 manifest['derived'].update(imp.derived);manifest['raw_files'].update(imp.files);manifest['dragon']=spec
 manifest['model_references']=json.loads((ROOT/'docs/references/end/sources.json').read_text())
 manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 assets_path=ROOT/'data/end_assets.json';assets=json.loads(assets_path.read_text());assets['sprites']=list(dict.fromkeys([k for k in assets['sprites'] if not (k.startswith('dragon_') and k!='dragon_fireball')]+list(imp.derived)))
 assets_path.write_text(json.dumps(assets,indent=2)+'\n')
 preview=Image.new('RGBA',(960,768),(22,19,25,255));draw=ImageDraw.Draw(preview)
 for n,(row,frame) in enumerate([(0,1),(2,3),(4,7),(6,10),(10,14),(14,17),(0,21),(4,22),(8,5)]):
  pic=atlas.crop((frame*320,row*256,(frame+1)*320,(row+1)*256));preview.alpha_composite(pic,(n%3*320,n//3*256));draw.text((n%3*320+8,n//3*256+236),f'yaw {row*22.5} frame {frame}',fill='white')
 preview.save(ROOT/'qa/end_dragon_poses.png')
 print('Connected dragon ready',atlas.size,flush=True)

if __name__=='__main__':generate()
