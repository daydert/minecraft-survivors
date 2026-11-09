"""IV special encounters: connected native-textured meshes and depth-composed
body masks, with independently destructible parts and complete action poses.
"""
import json,math,argparse
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor
import numpy as np
from PIL import Image
from import_minecraft_assets import ROOT,Importer,bake,box,find_client,tinted
from bake_minecraft_characters import part,transform,DIRECTIONS
from bake_v2_assets import block
from bake_chapter_four_mobs import flesh,tissue,bone,beam,open_ribs,split_head
from chapter_four_mesh_layers import bake_depth
from end_character_mesh import held_item

STATES={}
start=0
for name,n,duration,loop in [('idle',2,.4,True),('walk',4,.15,True),('intro',6,.2,False),('windup',4,.25,False),('haul',4,.12,False),('fan',4,.18,True),('sweep',5,.1,False),('recover',3,.3,False),('hurt',2,.07,False),('release',7,.45,False),('death',7,.6,False)]:
 STATES[name]=dict(start=start,durations=[duration]*n,loop=loop);start+=n
COLUMNS=start
# A complete shared hierarchy is rasterized into five component depth layers.
# Every mask is recomposed with that depth, so removing a head reveals the
# tissue behind it rather than leaving a transparent cut in the whole body.
def mass(imp,state,k):
 tex=imp.tex('entity/villager/villager');zombie=imp.tex('entity/zombie/zombie')
 breath=math.sin(k*math.tau)*.6 if state in ['idle','walk','fan'] else 0
 core=tissue(imp,(-16,4,-13),(32,13,29))+flesh(imp,(-12,8,-15),(24,8,7))
 # Uneven fused torsos, a broken spine and a buried third face keep the mass
 # anatomical rather than a symmetric crab with a smiling horizontal mouth.
 for j in range(3):
  hump=tissue(imp,(-6,0,-7),(12,11+j*2,14));core+=transform(hump,(.08*j,.2*(j-1),-.18+j*.17),offset=(-10+j*10,12,3))
  core+=bone(imp,(-11+j*10,23+j*1.5,4),(2,4,3))
 core+=block(imp,'coal_block',(-10,8,-17),(20,9,2))
 core+=flesh(imp,(-8,8,-18),(16,7,3))
 buried=split_head(imp,zombie,0,8);core+=transform(buried,(.45,-.3,1.1),pivot=(0,4,0),offset=(10,12,9))
 for sign in [-1,1]:
  for j in range(3):
   rib=[(sign*3,9+j*3.5,-18),(sign*(11+j*.6),13+j*3.5,-21),(sign*16,14+j*3.5,-10)]
   core+=beam(imp,rib[0],rib[1],1.5)+beam(imp,rib[1],rib[2],1.4)
  flap=part(zombie,(-4,10,-3),(8,12,2),(16,16))
  core+=transform(flap,(.35,sign*.8,sign*.25),pivot=(0,20,0),offset=(sign*15,-2,-7))
 for j in range(4):
  points=[(-10+j*6,11,-18),(-12+j*6,5,-21),(-8+j*6,2,-16),(-6+j*6,9,-16)]
  for a,b in zip(points,points[1:]):core+=beam(imp,a,b,2.1,True)
 core+=tissue(imp,(-7,16,2),(14,7,14))
 groups={0:core}
 for index,sign in enumerate([-1,1]):
  head=split_head(imp,tex,25,10)
  head+=tissue(imp,(-3,18,-1),(6,10,7));head+=flesh(imp,(-2,18,-2),(4,7,2))
  for j in range(3):head+=bone(imp,(-3.8,20+j*2,4),(7.6,.9,2))
  angle=(.22*sign+.25*math.sin(k*math.tau+index)) if state=='fan' else -.15*sign
  head=transform(head,(.12+(.45*math.sin(k*math.pi) if state=='fan' else 0),angle,-.48 if sign<0 else .25),pivot=(0,21,0),offset=(sign*14,-2,-2))
  groups[index+1]=head
 arms=[]
 for sign in [-1,1]:
  reach=11+14*(k if state=='windup' else 1-k if state=='haul' else .5 if state=='sweep' else .2)
  if state=='sweep':reach=24;angle=-1.2+k*2.4
  else:angle=sign*.28
  shoulder=np.array((sign*15,15,-2));elbow=np.array((sign*26,6,-8));hand=np.array((sign*(27+reach*.4),2,-reach))
  if state=='sweep':hand=np.array((sign*24+math.sin(angle)*22,3,-18-math.cos(angle)*12))
  arms+=beam(imp,shoulder,elbow,4,True)+beam(imp,elbow,hand,3.3,True)
  arms+=bone(imp,tuple(elbow-np.array([1,1,1])),(2,2,2))
  arms+=part(zombie,tuple(hand-np.array([3,0,2])),(6,3,5),(40,25))
  for finger in range(3):arms+=beam(imp,hand+(finger-1,0,-1),hand+(finger*2-2,-1,-7),1.3,True)
 groups[3]=arms
 legs=[]
 for sign in [-1,1]:
  for j in range(2):
   hip=(sign*(8+j*5),10,8);knee=(sign*(15+j*5),5,16);foot=(sign*(14+j*6),1,24+(math.sin(k*math.tau)*3 if state=='walk' else 0))
   legs+=beam(imp,hip,knee,3.5,True)+beam(imp,knee,foot,2.8,True)
   legs+=part(tex,(foot[0]-2,0,foot[2]-2),(4,3,5),(0,22))
 groups[4]=legs
 pitch=.15*math.sin(k*math.pi) if state in ['haul','sweep'] else 0
 rise=(1-k)*-15 if state=='intro' else -k*10 if state=='death' else breath
 for key in groups:
  groups[key]=transform(groups[key],(pitch,0,math.sin(k*8)*.04 if state=='hurt' else k*.24 if state=='death' else 0),pivot=(0,10,0),offset=(0,rise,0))
 return groups

def golem(imp,state,k,saved=False):
 tex=imp.tex('entity/iron_golem/iron_golem')
 mesh=part(tex,(-4,34,-5.5),(8,10,8),(0,0))+part(tex,(-1,35,-7.5),(2,4,2),(24,0))
 torso=part(tex,(-9,22,-6),(18,12,11),(0,40))
 mesh+=torso if saved else torso[1:]
 mesh+=part(tex,(-4.5,16,-3),(9,6,6),(0,70))
 if not saved:
  mesh+=open_ribs(imp,23,-6,13,10)
  for sign in [-1,1]:
   plate=part(tex,(-2.5,22,-1),(5,10,2),(11,51));mesh+=transform(plate,(0,sign*.8,sign*.2),pivot=(0,32,0),offset=(sign*9,0,-5))
 for sign in [-1,1]:
  gait=math.sin(k*math.tau)*.45 if state=='walk' else 0
  mesh+=part(tex,(sign*4.5-3,0,-2),(6,16,5),(37,0) if sign<0 else (60,0),pivot=(sign*4.5,16,0),angles=(gait*sign,0,0))
  arm=part(tex,(sign*11-2,6,-3),(4,30,6),(60,21) if sign<0 else (60,58))
  angle=-gait*sign
  if state=='windup':angle=k*2.25
  elif state in ['haul','sweep']:angle=(1-k)*2.25
  elif state=='recover':angle=-.2*math.sin(k*math.pi)
  elif state=='intro':angle=.3+math.sin(k*math.pi)*.8
  elif state=='release':angle=.7*(1-k)
  if not saved:
   arm+=beam(imp,(sign*11,21,-3),(sign*13,8,-5),1.5,True)
   arm+=flesh(imp,(sign*11-2.5,14,-4),(5,6,2))
  elif sign>0 and state in ['idle','release']:
   arm+=[(np.array([[sign*11-6,20,-4],[sign*11+6,20,-4],[sign*11+6,8,-4],[sign*11-6,8,-4]],float),imp.tex('block/poppy'),(0,0,16,16),1)]
  mesh+=transform(arm,(angle,0,-sign*.07),pivot=(sign*11,34,0))
 tilt=.25*(1-k) if state=='release' else .14*math.sin(k*math.pi) if state=='intro' else .18*k if state=='windup' else 0
 return {0:transform(mesh,(tilt,0,.1*math.sin(k*12) if state=='hurt' else 0),pivot=(0,18,0),offset=(0,-5*math.sin(k*math.pi) if state=='release' else 0,0))}

def guardian(imp,state,k):
 mesh=block(imp,'polished_blackstone',(-7,1,-5),(14,31,10))
 for sign in [-1,1]:
  mesh+=block(imp,'chiseled_polished_blackstone',(sign*8-3,2,-5),(6,16,10))
  mesh+=block(imp,'polished_basalt_side',(sign*5-3,0,-5),(6,5,11))
 mask=block(imp,'calcite',(-5,32,-5),(10,11,8))
 mask+=block(imp,'polished_blackstone',(-4,35,-5.8),(8,3,1))
 for sign in [-1,1]:mask+=block(imp,'quartz_block_side',(sign*2-1,36,-6),(2,1.2,1.2))
 mesh+=transform(mask,(.09*math.sin(k*math.tau),0,0),pivot=(0,32,0))
 for sign in [-1,1]:
  shoulder=(sign*10,29,0)
  arm=block(imp,'polished_basalt_side',(sign*10-2,16,-2),(4,13,4))
  arm+=block(imp,'calcite',(sign*10-3,12,-3),(6,5,6))
  angle=.6+k*1.1 if state=='windup' else 1.7-k*1.6 if state in ['haul','sweep'] else .9+math.sin(k*math.tau)*.1 if state=='fan' else 0
  mesh+=transform(arm,(angle,0,sign*.18),pivot=shoulder)
 for y in [7,17,27]:mesh+=block(imp,'chiseled_stone_bricks',(-8,y,-5.8),(16,2,2))
 if state=='death':
  # Seams open into distinct, depth-sorted blocks; the head finally drops.
  chunks=[]
  for j,face in enumerate(mesh):chunks+=transform([face],(0,0,math.sin(j)*k*.25),offset=(math.sin(j*2.4)*k*7,-k*k*(j%3)*5,math.cos(j*2.4)*k*5))
  mesh=chunks
 return {0:transform(mesh,(0,0,0),offset=(0,-(1-k)*35 if state=='intro' else 0,0))}

def bake_actor(job):
 name,jar=job;imp=Importer(jar)
 size=(144,128);anchor=(72,91);scale=1.0
 entries=[];bounds=[];mask_count=16 if name=='mass' else 1
 for row,(direction,yaw) in enumerate(DIRECTIONS.items()):
  for state,clip in STATES.items():
   for i in range(len(clip['durations'])):
    k=i/max(1,len(clip['durations'])-1)
    groups=mass(imp,state,k) if name=='mass' else golem(imp,state,k,name=='golem_saved') if name.startswith('golem') else guardian(imp,state,k)
    layers={key:bake_depth(mesh,size,scale,anchor,yaw,20) for key,mesh in groups.items()}
    for mask in range(mask_count):
     canvas=np.zeros((size[1],size[0],4),np.uint8);depth=np.full((size[1],size[0]),-np.inf)
     for key,(im,z) in layers.items():
      if key and not mask&(1<<(key-1)):continue
      visible=z>depth;canvas[visible]=np.asarray(im)[visible];depth[visible]=z[visible]
     frame=Image.fromarray(canvas);bounds.append(frame.getbbox());entries.append((mask,row,clip['start']+i,frame))
 crop=(min(b[0] for b in bounds)-2,min(b[1] for b in bounds)-2,max(b[2] for b in bounds)+2,max(b[3] for b in bounds)+2)
 w,h=crop[2]-crop[0],crop[3]-crop[1];meta={};derived={}
 for mask in range(mask_count):
  actor='ch4d_'+name+('_'+str(mask) if name=='mass' else '')
  atlas=Image.new('RGBA',(w*COLUMNS,h*3))
  for candidate,row,col,frame in entries:
   if candidate==mask:atlas.paste(frame.crop(crop),(col*w,row*h))
  imp.save(atlas,actor+'_atlas',['native textures; connected action hierarchy; component depth composition'])
  meta[actor]=dict(frame_size=[w,h],anchor=[anchor[0]-crop[0],anchor[1]-crop[1]],columns=COLUMNS,states=STATES,shadow_size=[29,7] if name=='mass' else [13,4])
 # Detached body groups are independently projected onto the ground, not cropped
 # from a full atlas with a hidden hole behind the remaining anatomy.
 if name=='mass':
  for component in range(1,5):
   actor='ch4d_loose_'+str(component);frames=[];bs=[]
   for row,(direction,yaw) in enumerate(DIRECTIONS.items()):
    for i in range(6):
     mesh=mass(imp,'idle',0)[component]
     # Translate the component's anatomical pivot to its own ground origin.
     pivot=(-14,20,-2) if component==1 else (14,20,-2) if component==2 else (0,3,-15) if component==3 else (0,2,17)
     mesh=transform(mesh,(0,0,math.sin(i*math.tau/6)*.08),pivot=pivot,offset=tuple(-np.array(pivot)))
     f=bake(mesh,size,1,anchor,yaw,20);frames.append(f);bs.append(f.getbbox())
   c=(min(b[0] for b in bs)-2,min(b[1] for b in bs)-2,max(b[2] for b in bs)+2,max(b[3] for b in bs)+2);fw,fh=c[2]-c[0],c[3]-c[1];atlas=Image.new('RGBA',(fw*6,fh*3))
   for j,f in enumerate(frames):atlas.paste(f.crop(c),((j%6)*fw,(j//6)*fh))
   imp.save(atlas,actor+'_atlas',['detached native textured anatomy'])
   meta[actor]=dict(frame_size=[fw,fh],anchor=[anchor[0]-c[0],anchor[1]-c[1]],columns=6,states={s:dict(start=0,durations=[.1]*6,loop=True) for s in ['idle','walk','windup','attack','recover','hurt','death']},shadow_size=[8,3])
 print('BAKED ENCOUNTER',name,flush=True)
 return meta,imp.files,imp.derived

def generate(only=None,jobs=2):
 version,jar,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(jar)
 data_path=ROOT/'data/chapter_four_encounter_assets.json';manifest_path=ROOT/'docs/CHAPTER_FOUR_ENCOUNTER_MANIFEST.json'
 data=json.loads(data_path.read_text()) if only and data_path.exists() else dict(actors={},sprites=[])
 manifest=json.loads(manifest_path.read_text()) if only and manifest_path.exists() else dict(raw_files={},derived={})
 names=only or ['mass','golem','golem_saved','guardian']
 # Validate every native source before expensive rasterization.
 for name in names:
  mass(imp,'idle',0) if name=='mass' else golem(imp,'idle',0,name=='golem_saved') if name.startswith('golem') else guardian(imp,'idle',0)
 with ProcessPoolExecutor(max_workers=jobs) as pool:
  for actors,raw,derived in pool.map(bake_actor,[(name,jar) for name in names]):
   data['actors'].update(actors);manifest['raw_files'].update(raw);manifest['derived'].update(derived)
   data_path.write_text(json.dumps(data,indent=2)+'\n');manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
 for name,mat in [('ch4d_block','polished_blackstone'),('ch4d_shard','chiseled_stone_bricks'),('ch4d_iron_piece','iron_block')]:
  imp.save(bake(block(imp,mat,(-16,0,-16),(32,24,32)),(48,48),1,(24,32),25,20),name,['native block geometry']);data['sprites'].append(name)
 growth=tissue(imp,(-6,0,-6),(12,11,12))+flesh(imp,(-4,3,-7),(8,6,2))
 for j in range(3):growth+=bone(imp,(-7,j*3,-7),(14,1.3,2))
 imp.save(bake(growth,(32,32),1,(16,23),0,20),'ch4d_node',['native flesh, exposed bone']);data['sprites'].append('ch4d_node')
 data['sprites']=list(dict.fromkeys(data['sprites']));manifest['raw_files'].update(imp.files);manifest['derived'].update(imp.derived);manifest.update(version=version,client_jar=str(jar))
 data_path.write_text(json.dumps(data,indent=2)+'\n');manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--only',nargs='+',choices=['mass','golem','golem_saved','guardian']);p.add_argument('--jobs',type=int,default=2);a=p.parse_args();generate(a.only,a.jobs)
