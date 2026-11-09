"""IV arsenal: complete Steve poses, palm/wrist-bound equipment and back wings.

Lazy runtime cache loads only the current gear/wing/armour combination. Source
textures remain local vanilla bytes; no old chapter atlas is ever written.
"""
from pathlib import Path
import json,math,argparse
import numpy as np
from PIL import Image,ImageChops
from import_minecraft_assets import ROOT,Importer,find_client,bake,box,tinted
from bake_minecraft_characters import part,transform,DIRECTIONS
from bake_v2_assets import block
from end_character_mesh import held_item

GEARS=['idle','sword_iron','sword_diamond','sword_netherite','bedrock','axe_iron','axe_diamond','axe_netherite','hoe_iron','hoe_diamond','hoe_netherite','bow','trident','bed','tnt','fishing','shotgun','sky_tnt','blood_pool','embryo','bell','bone_saw','red_torch','potion']
STATES={'idle':dict(start=0,durations=[.6],loop=True),'walk':dict(start=1,durations=[.1]*4,loop=True),'windup':dict(start=5,durations=[.08]*3,loop=False),'attack':dict(start=8,durations=[.04]*3,loop=False),'recover':dict(start=11,durations=[.12]*3,loop=False),'hurt':dict(start=14,durations=[.06]*2,loop=False)}

def cube(imp,mat,p,size,color=None):return block(imp,mat,p,size,tint=color)

def tool(imp,gear,phase,k):
 m=[]
 if gear=='bedrock':
  m+=cube(imp,'bedrock',(-2,0,-1),(4,21,2));m+=cube(imp,'polished_blackstone',(-4,-1,-1.5),(8,2,3));m+=cube(imp,'oak_planks',(-1,-7,-1),(2,6,2))
 elif gear=='shotgun':
  m+=cube(imp,'oak_planks',(-2,-1,-1),(4,4,10));m+=cube(imp,'iron_block',(-4,1,-17),(8,3,18),(140,140,150))
  for x in [-2,2]:
   m+=cube(imp,'blackstone',(x-1.4,1,-19),(2.8,3,19));m+=cube(imp,'coal_block',(x-1.1,1.5,-19.1),(2.2,2,1))
  m+=cube(imp,'oak_planks',(-3,-1,-11),(6,2,5));
  for x in [-1,1]:
   limb=cube(imp,'oak_planks',(-1,0,-2),(9,1.4,3));m+=transform(limb,(0,x*.2,0),offset=(x*3,1,-10),scale=(x,1,1))
   m+=cube(imp,'iron_block',(x*10-.4,1,-9),(.8,.8,10),(100,100,105))
  m+=cube(imp,'iron_block',(-1,-4,1),(2,4,2))
  if phase=='recover':m=transform(m,(.28*k,0,0),pivot=(0,0,0),offset=(0,-math.sin(k*math.pi)*2,2*k))
 elif gear=='bell':
  tex=imp.tex('entity/bell/bell_body');m+=part(tex,(-3,-6,-3),(6,7,6),(0,0));m+=part(tex,(-4,-7,-4),(8,2,8),(0,13));m+=cube(imp,'oak_planks',(-1,1,-1),(2,6,2));m=transform(m,(math.sin(k*math.pi)*.5 if phase in ['attack','recover'] else -.3*k,0,0),pivot=(0,5,0),offset=(0,-4,0))
 elif gear=='bone_saw':
  reach=10+14*math.sin(k*math.pi) if phase in ['attack','recover'] else 10
  angle=-.6+1.2*k if phase=='attack' else .5*(1-k) if phase=='recover' else -.6*k
  end=np.array([math.sin(angle)*reach,-2,-math.cos(angle)*reach])
  for i in range(8):m+=cube(imp,'iron_block',end*(i/8)-np.array([.6,.6,.6]),(1.2,1.2,1.2),(140,140,150))
  blade=cube(imp,'bone_block_side',(-5,-.7,-5),(10,1.4,10))
  for i in range(8):
   a=i*math.tau/8+k*math.tau*2;p=(math.cos(a)*5,-.9,math.sin(a)*5)
   tooth=cube(imp,'bone_block_side',(-1,-1,-1),(2,2,2));blade+=transform(tooth,(0,a,0),offset=p)
  m+=transform(blade,(0,k*math.tau,0),offset=end)
 elif gear=='red_torch':
  m+=cube(imp,'oak_planks',(-1,-5,-1),(2,11,2));m+=cube(imp,'red_concrete',(-2,5,-2),(4,3,4));m+=cube(imp,'iron_block',(-1.5,3,-1.5),(3,1,3))
 elif gear in ['blood_pool','embryo']:
  m+=cube(imp,'red_concrete_powder',(-3,-2,-3),(6,6,6));m+=cube(imp,'mushroom_stem',(-2,3,-2),(4,2,4),(220,130,126))
 elif gear in ['tnt','bed']:
  m+=cube(imp,'tnt_side' if gear=='tnt' else 'red_wool',(-4,-2,-3),(8,6 if gear=='tnt' else 3,6))
 elif gear=='potion':
  m+=held_item(imp,'potion',(0,0,0),.8,(8,10))
 elif gear in ['fishing','sky_tnt']:
  m+=held_item(imp,'fishing_rod',(0,0,0),1,(4,12),.4)
 else:
  source=gear.split('_')[1]+'_'+gear.split('_')[0] if '_' in gear else gear
  m+=held_item(imp,source,(0,0,0),.85,(4.5,12),.8 if gear!='bow' else 0)
 return m

def wings(imp,stage,phase,k):
 if not stage:return []
 m=[];tex=tinted(imp.tex('block/brown_terracotta'),(95,65,65));span=8+stage*5
 for sign in [-1,1]:
  root=np.array((sign*2,22,3.2));elbow=np.array((sign*(span*.5),26,3.6));tip=np.array((sign*span,20,4.3));notch1=np.array((sign*span*.75,18.5,4.4));finger2=np.array((sign*span*.79,12,4.7));notch2=np.array((sign*span*.47,15.5,4.3));finger3=np.array((sign*span*.43,9.5,4));bottom=np.array((sign*3,14,3.4))
  panel=[(np.array(points),tex,(0,0,16,16),shade) for points,shade in [([root,elbow,tip,notch1],.9),([root,notch1,finger2,notch2],.8),([root,notch2,finger3,bottom],.85)]]
  for a,b in [(root,elbow),(elbow,tip),(root,finger2),(root,finger3),(root,bottom)]:
   d=b-a;length=np.linalg.norm(d);bone=cube(imp,'bone_block_side',(-.45,-.45,0),(.9,.9,float(length)),(130,95,90));panel+=transform(bone,(-math.asin(d[1]/length),math.atan2(d[0],d[2]),0),offset=a)
  m+=transform(panel,(0,sign*(.1+math.sin(k*math.pi)*.08),sign*.07),pivot=root)
 return m

def maiden(imp):
 m=cube(imp,'iron_block',(-4.5,12,-2.7),(9,12,5.4),(145,145,155))
 for sign in [-1,1]:
  for y in [14,18,22]:
   spike=cube(imp,'iron_block',(-.7,-.7,0),(1.4,1.4,5),(200,190,195));m+=transform(spike,(0,sign*math.pi/2,0),offset=(sign*4,y,0))
 for x in [-2,2]:m+=cube(imp,'iron_block',(x-.5,16,-6),(1,1,4))
 return m

def player(imp,gear,wing,armor,state,i,n):
 tex=imp.tex('entity/player/wide/steve');k=i/max(1,n-1);gait=math.sin(i/4*math.tau) if state=='walk' else 0
 phase=state;wind=k if state=='windup' else 1-k if state=='recover' else 1 if state=='attack' else 0
 m=part(tex,(-4,24,-4),(8,8,8),(0,0))+part(tex,(-4,24,-4),(8,8,8),(32,0),inflate=.25)
 m+=part(tex,(-4,12,-2),(8,12,4),(16,16))+part(tex,(-4,12,-2),(8,12,4),(16,32),inflate=.2)
 for sign in [-1,1]:
  uv=(0,16) if sign<0 else (16,48)
  m+=part(tex,(sign*2-2,0,-2),(4,12,4),uv,pivot=(sign*2,12,0),angles=(gait*.6*sign,0,0))
  m+=part(tex,(sign*2-2,0,-2),(4,12,4),(0,32) if sign<0 else (0,48),pivot=(sign*2,12,0),angles=(gait*.6*sign,0,0),inflate=.2)
  arm_uv=(40,16) if sign<0 else (32,48);overlay=(40,32) if sign<0 else (48,48)
  shoulder=(sign*5,22,0);angle=-gait*.45*sign
  if sign<0 and gear!='idle':
   angle=(.2+wind*2.1) if gear=='bedrock' or 'sword_' in gear or 'axe_' in gear else 1.1+wind*.3 if gear in ['shotgun','bow'] else .3+wind*1.6
   if phase=='attack' and gear=='bedrock':angle=2.3-k*2.1
   if phase=='recover' and gear=='bedrock':angle=.2-.1*math.sin(k*math.pi)
   if gear=='sky_tnt':angle=1.2+wind*1.7
  elif sign>0 and gear in ['shotgun','bow']:angle=1.0+wind*.15
  upper=part(tex,(sign*6-2,18,-2),(4,6,4),arm_uv)+part(tex,(sign*6-2,18,-2),(4,6,4),overlay,inflate=.2)
  lower=part(tex,(sign*6-2,12,-2),(4,6,4),(arm_uv[0],arm_uv[1]+6))+part(tex,(sign*6-2,12,-2),(4,6,4),(overlay[0],overlay[1]+6),inflate=.2)
  grip=np.array((sign*6,13,-2.4))
  if sign<0 and gear!='idle':
   weapon=tool(imp,gear,phase,k)
   desired=(-angle if gear in ['shotgun','bone_saw'] else -.4 if gear=='bedrock' else 0)
   lower+=transform(weapon,(desired,0,0),offset=grip)
  lower=transform(lower,(.12*wind,0,0),pivot=(sign*6,18,0))
  m+=transform(upper+lower,(angle,0,-sign*.06),pivot=shoulder)
 m+=wings(imp,wing,phase,k)
 if armor:m+=maiden(imp)
 twist=(-.2+wind*.4) if gear=='bedrock' else wind*.08
 return transform(m,(.05*wind,twist,0),pivot=(0,12,0),offset=(0,abs(gait)*.3,0))

def pet(imp,stage,k,attack=False):
 m=cube(imp,'mushroom_stem',(-3,1,-3),(6,6+stage*2,6),(225,150,145));m+=cube(imp,'red_concrete_powder',(-2,3,-3.5),(4,4,1))
 for x in [-1.7,1.7]:m+=cube(imp,'coal_block',(x-.8,6+stage,-3.8),(1.6,1.6,.8))
 if stage>=2:
  for sign in [-1,1]:
   arm=cube(imp,'mushroom_stem',(0,-.8,-.8),(5+stage*2,1.6,1.6),(225,150,145));m+=transform(arm,(0,sign*(.3+k if attack else .2),sign*.25),offset=(sign*3,4+stage,-1),scale=(sign,1,1))
 if stage>=3:
  for x in [-2,2]:m+=cube(imp,'mushroom_stem',(x-1,0,-1),(2,4,2),(210,140,135))
 if stage>=3:
  m+=cube(imp,'coal_block',(-2.6,4,-3.7),(5.2,5,1));m+=cube(imp,'red_concrete_powder',(-1.5,4,-4.1),(3,3.5,1))
  for sign in [-1,1]:
   for y in [5,7,9]:
    rib=cube(imp,'mushroom_stem',(-.4,-.45,-.6),(3,.9,1.2),(235,180,160));m+=transform(rib,(0,sign*.25,sign*.2),offset=(sign*2,y,-4.4),scale=(-sign,1,1))
 if stage==4:
  jaw=cube(imp,'red_concrete_powder',(-3,1,-5),(6,3,3));m+=transform(jaw,(-k*.9 if attack else -.15,0,0),pivot=(0,4,-2))
 return m

def bake_variant(job):
 gear,wing,armor,jar,reuse_plain=job
 imp=Importer(jar);name='ch4_held_%s_w%d_a%d'%(gear,wing,armor);size=(96,96);anchor=(48,65)
 existing=ROOT/'assets/sprites'/(name+'.png')
 if reuse_plain and wing==0 and gear!='shotgun' and existing.exists():
  # Unchanged plain geometry: recover its crop from the exact original idle
  # projection. Alpha bounds give the same origin without baking 47 more poses.
  im=Image.open(existing);w,h=im.width//16,im.height//3
  f=bake(player(imp,gear,wing,armor,'idle',0,1),size,.86,anchor,yaw=DIRECTIONS['down'],elevation=20)
  raw=f.getbbox();cropped=im.crop((0,0,w,h)).getbbox();origin=(raw[0]-cropped[0],raw[1]-cropped[1]);crop=(origin[0],origin[1],origin[0]+w,origin[1]+h)
  imp.save(im,name,['original Steve skin; native item/block textures; full shoulder/elbow/wrist hierarchy'])
 else:
  frames=[];bounds=[]
  for row,rowname in enumerate(DIRECTIONS):
   for state,clip in STATES.items():
    for i in range(len(clip['durations'])):
     f=bake(player(imp,gear,wing,armor,state,i,len(clip['durations'])),size,.86,anchor,yaw=DIRECTIONS[rowname],elevation=20)
     col=clip['start']+i;frames.append((row,col,f));bounds.append(f.getbbox())
  crop=(min(b[0] for b in bounds)-2,min(b[1] for b in bounds)-2,max(b[2] for b in bounds)+2,max(b[3] for b in bounds)+2)
  w,h=crop[2]-crop[0],crop[3]-crop[1];atlas=Image.new('RGBA',(w*16,h*3))
  for row,col,f in frames:atlas.paste(f.crop(crop),(col*w,row*h))
  imp.save(atlas,name,['original Steve skin; native item/block textures; full shoulder/elbow/wrist hierarchy'])
 meta=dict(frame_size=[w,h],anchor=[anchor[0]-crop[0],anchor[1]-crop[1]],columns=16,states=STATES)
 return name,meta,imp.files,imp.derived

def generate(only=None,wings_only=False,small_only=False,jobs=1,reuse_plain=False):
 from concurrent.futures import ProcessPoolExecutor
 version,jar,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(jar)
 old_path=ROOT/'data/chapter_four_equipment.json';data=json.loads(old_path.read_text()) if (only or wings_only or small_only) and old_path.exists() else dict(held={},sprites=[],clips={},actors={},weapons={})
 manifest_path=ROOT/'docs/CHAPTER_FOUR_EQUIPMENT_MANIFEST.json';manifest=json.loads(manifest_path.read_text()) if (only or wings_only or small_only) and manifest_path.exists() else dict(raw_files={},derived={})
 order=list(dict.fromkeys(['bedrock','shotgun','bone_saw','bell','sky_tnt','idle']+GEARS))
 tasks=[(gear,wing,armor,jar,reuse_plain) for gear in order if not small_only and (not only or gear in only) for wing in range(4) if not wings_only or wing>0 for armor in [0,1]]
 with ProcessPoolExecutor(max_workers=jobs) as pool:
  for n,(name,meta,raw,derived) in enumerate(pool.map(bake_variant,tasks)):
   data['held'][name]=meta;manifest['raw_files'].update(raw);manifest['derived'].update(derived)
   if (n+1)%8==0:
    old_path.write_text(json.dumps(data,indent=2)+'\n');manifest_path.write_text(json.dumps(manifest,indent=2)+'\n');print('BAKED HELD',tasks[n][0],flush=True)
 # Small original-textured inventory icons. Tool icons are projections of the
 # exact held geometry, while vanilla ingredients are copied byte for byte.
 icon_gears={'bedrock_sword':'bedrock','shotgun':'shotgun','shotgun_evo':'shotgun','blood_pool':'blood_pool','blood_pool_evo':'blood_pool','embryo':'embryo','embryo_evo':'embryo','bell':'bell','bell_evo':'bell','bone_saw':'bone_saw','bone_saw_evo':'bone_saw','red_torch':'red_torch','red_torch_evo':'red_torch','sky_tnt':'sky_tnt','potion':'potion','potion_evo':'potion'}
 for name,gear in icon_gears.items():
  pic=bake(tool(imp,gear,'idle',0),(48,48),1.2,(24,30),yaw=-35,elevation=20);b=pic.getbbox();pic=pic.crop(b);pic.thumbnail((16,16),Image.Resampling.NEAREST);icon=Image.new('RGBA',(16,16));icon.alpha_composite(pic,((16-pic.width)//2,(16-pic.height)//2));imp.save(icon,'icon_ch4_'+name,['native textured held tool']);data['sprites'].append('icon_ch4_'+name)
 passive_icons={'bedrock':'bedrock','gunpowder':'gunpowder'}
 for name,source in passive_icons.items():
  pic=imp.tex(('item/' if name=='gunpowder' else 'block/')+source).crop((0,0,16,16));imp.save(pic,'icon_ch4_'+name,['native block/item '+source]);data['sprites'].append('icon_ch4_'+name)
 icons={}
 icons['heart_booster']=cube(imp,'iron_block',(-6,-5,-3),(12,10,6),(105,105,110))+cube(imp,'redstone_block',(-4,-4,-4),(8,8,2))+cube(imp,'iron_block',(-2,5,-1),(4,4,2))
 icons['mirror_shard']=cube(imp,'glass',(-4,-6,-1),(8,12,2))+cube(imp,'iron_block',(-5,-6,-1.1),(1,12,2.2))+cube(imp,'iron_block',(-5,-7,-1.1),(10,1,2.2))
 icons['black_candle']=cube(imp,'black_candle',(-2,-6,-2),(4,12,4))+cube(imp,'oak_planks',(-.5,6,-.5),(1,2,1))+cube(imp,'red_concrete',(0,8,-1),(2,3,2))
 icons['empty_totem']=cube(imp,'polished_blackstone',(-2,-6,-1.5),(4,9,3))+cube(imp,'polished_blackstone',(-4,2,-2),(8,6,4))+cube(imp,'polished_blackstone',(-7,-1,-1),(14,2,2))+cube(imp,'red_concrete',(-2,4,-2.1),(1,1,.3))+cube(imp,'red_concrete',(1,4,-2.1),(1,1,.3))
 icons['iron_maiden']=maiden(imp)
 icons['thorns']=cube(imp,'iron_block',(-3,-3,-1),(6,6,2))
 for i in range(8):
  a=i*math.tau/8;tooth=cube(imp,'bone_block_side',(-.7,2,-.7),(1.4,6,1.4));icons['thorns']+=transform(tooth,(0,0,a))
 for name,mesh in icons.items():
  pic=bake(mesh,(64,64),1.8,(32,44),yaw=-20,elevation=20);b=pic.getbbox();pic=pic.crop(b);pic.thumbnail((16,16),Image.Resampling.NEAREST);icon=Image.new('RGBA',(16,16));icon.alpha_composite(pic,((16-pic.width)//2,(16-pic.height)//2));imp.save(icon,'icon_ch4_'+name,['native textured equipment geometry']);data['sprites'].append('icon_ch4_'+name)
 for name,mesh in [('bat_wings',wings(imp,3,'idle',0)),('bat_swarm',wings(imp,3,'idle',0))]:
  pic=bake(mesh,(64,48),1,(32,32),yaw=0,elevation=20);b=pic.getbbox();pic=pic.crop(b);pic.thumbnail((16,16),Image.Resampling.NEAREST);icon=Image.new('RGBA',(16,16));icon.alpha_composite(pic,((16-pic.width)//2,(16-pic.height)//2));imp.save(icon,'icon_ch4_'+name,['native wing geometry']);data['sprites'].append('icon_ch4_'+name)
 for stage in range(1,5):
  name='ch4_pet_'+str(stage);atlas=Image.new('RGBA',(64*8,64*3))
  for row,rowname in enumerate(DIRECTIONS):
   for i in range(8):atlas.paste(bake(pet(imp,stage,(i%4)/3,i>=4),(64,64),1.05,(32,49),yaw=DIRECTIONS[rowname],elevation=20),(i*64,row*64))
  imp.save(atlas,name,['mushroom stem; red concrete powder; coal']);data['sprites'].append(name)
 data['weapons']={id:dict(windup=.2,attack=.12,recover=.36) for id in ['shotgun','blood_pool','embryo','bell','bone_saw','red_torch','sky_tnt']}
 ghost=bake(tool(imp,'bell','idle',0),(96,96),5,(48,68),yaw=-15,elevation=20);imp.save(ghost,'ch4_ghost_bell',['entity/bell/bell_body']);data['sprites'].append('ch4_ghost_bell')
 tnt=bake(cube(imp,'tnt_side',(-7,0,-7),(14,14,14)),(32,32),1,(16,25),yaw=20,elevation=20);imp.save(tnt,'ch4_sky_charge',['block/tnt_side']);data['sprites'].append('ch4_sky_charge')
 data['sprites']=list(dict.fromkeys(data['sprites']));old_path.write_text(json.dumps(data,indent=2)+'\n');manifest['raw_files'].update(imp.files);manifest['derived'].update(imp.derived);manifest.update(version=version,client_jar=str(jar));manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+',choices=GEARS);parser.add_argument('--wings-only',action='store_true');parser.add_argument('--small-only',action='store_true');parser.add_argument('--jobs',type=int,default=1);parser.add_argument('--reuse-plain',action='store_true');args=parser.parse_args();generate(args.only,args.wings_only,args.small_only,args.jobs,args.reuse_plain)
