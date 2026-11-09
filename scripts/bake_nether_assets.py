"""Chapter II assets using the existing vanilla importer and cuboid rasterizer.

All texture samples come from the installed Java client. Custom orthographic
poses and sizes match this game's 2D projection, not Mojang's animation code.
"""
from __future__ import annotations
import hashlib,json,math,random
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from import_minecraft_assets import ROOT,OUT,Importer,find_client,bake,box
from bake_minecraft_characters import part,transform,humanoid,action_pose,DIRECTIONS,block

SOURCES={'zombified_piglin':'entity/piglin/zombified_piglin','piglin_sword':'entity/piglin/piglin',
 'piglin_crossbow':'entity/piglin/piglin','brute':'entity/piglin/piglin_brute',
 'wither_skeleton':'entity/skeleton/wither_skeleton','blaze_nether':'entity/blaze',
 'hoglin':'entity/hoglin/hoglin','zoglin':'entity/hoglin/zoglin','wither':'entity/wither/wither'}
SIZES={k:((128,112) if k=='wither' else (48,48) if k in ['hoglin','zoglin'] else (32,32)) for k in SOURCES}

def mesh(imp,name,state,index,count):
 tex=imp.tex(SOURCES[name]);gait,lift,action,hurt,breath=action_pose(state,index,count)
 if name=='wither_skeleton':
  class Skin:
   def tex(self,source):return tex if source=='entity/skeleton/skeleton' else imp.tex(source)
  return humanoid(Skin(),'skeleton',state,index,count)
 if name in ['piglin_sword','piglin_crossbow','brute','zombified_piglin']:
  m=part(tex,(-5,24,-4),(10,8,8),(0,0),angles=(hurt,0,0),pivot=(0,24,0))
  m+=part(tex,(-2,24,-5),(4,4,1),(31,1))
  for sign in [-1,1]:
   m+=part(tex,(sign*5-1,27,-1),(2,5,1),(51,6),angles=(0,0,sign*.4),pivot=(sign*5,30,0))
   m+=part(tex,(sign*2-1,24,-6),(1,2,1),(2,4))
  m+=part(tex,(-4,12,-2),(8,12,4),(16,16))
  for sign in [-1,1]:
   m+=part(tex,(sign*2-2,0,-2),(4,12,4),(0,16),angles=(gait*.65*sign,0,0),pivot=(sign*2,12,0))
   angles=(1.1+action*.5 if name=='piglin_crossbow' else -gait*.55+action*1.7,0,-sign*.08)
   arm=part(tex,(sign*6-2,12,-2),(4,12,4),(40,16),angles=angles,pivot=(sign*5,22,0))
   if sign<0:
    weapon='crossbow_standby' if name=='piglin_crossbow' else 'golden_axe' if name=='brute' else 'golden_sword'
    item=imp.tex('item/'+weapon)
    import numpy as np
    # Place the actual handle pixels in the palm, then transform the weapon
    # with the same shoulder pivot as the complete arm.
    grip=np.array([-6,13,-2.6],float)
    anchor=(8,10) if name=='piglin_crossbow' else (4.5,12)
    angle=0 if name=='piglin_crossbow' else math.pi
    c,ss=math.cos(angle),math.sin(angle)
    vertices=[]
    for u,v in [(0,0),(16,0),(16,16),(0,16)]:
     xx=(u-anchor[0])*.8;yy=(anchor[1]-v)*.8
     vertices.append(grip+np.array([xx*c-yy*ss,xx*ss+yy*c,0]))
    quad=np.array(vertices,float)
    arm+=transform([(quad,item,(0,0,16,16),1)],angles,(-5,22,0))
   m+=arm
  return transform(m,(hurt*.4,0,hurt*.3),pivot=(0,12,0),offset=(0,lift+breath,0))
 if name=='blaze_nether':
  m=part(tex,(-4,18,-4),(8,8,8),(0,0),angles=(hurt,0,0),pivot=(0,18,0))
  for ring in range(3):
   for rod in range(4):
    angle=rod*math.tau/4+index*.22*(1 if ring%2 else -1)+ring
    radius=7-ring*.7
    m+=part(tex,(math.cos(angle)*radius-1,5+ring*4+math.sin(angle)*1.4,-1+math.sin(angle)*radius),(2,8,2),(0,16))
  return transform(m,offset=(0,breath+lift+action,0))
 if name in ['hoglin','zoglin']:
  m=part(tex,(-8,10,-9),(16,14,26),(1,1))
  m+=part(tex,(-8,10,-19),(16,14,14),(61,1),angles=(action*.35+hurt,0,0),pivot=(0,17,-10))
  for sign in [-1,1]:
   m+=part(tex,(sign*6-1,8,-21),(2,10,2),(61,21))
   m+=part(tex,(sign*8-1,23,-14),(6,1,4),(1,1),angles=(0,0,sign*.2))
   for z in [-8,12]:m+=part(tex,(sign*5-3,0,z-3),(6,10,6),(41,1),angles=(gait*.65*sign*(1 if z<0 else -1),0,0),pivot=(sign*5,10,z))
  return transform(m,(hurt*.2,0,0),offset=(0,lift*.5+breath,0))
 if name=='wither':
  t=index/max(1,count-1);phase=index/max(1,count)*math.tau
  cast=math.sin(t*math.pi)*1.0 if state=='cast' else 0
  roar=math.sin(phase)*.7 if state=='roar' else 0
  dash=1 if state=='dash' else 0
  death=t if state=='death' else 0
  m=part(tex,(-10,10,-2),(20,3,3),(0,16))
  m+=part(tex,(-1.5,0,-1.5),(3,10,3),(0,22),angles=(.2+breath*.05+cast*.2,0,0),pivot=(0,10,0))
  for rib,y in enumerate([3,6,9]):
   ribmesh=part(tex,(-6,y,-1),(12,1,2),(0,22))
   m+=transform(ribmesh,(0,cast*.18+roar*.12,death*(rib-1)*.7),offset=(death*(rib-1)*4,-death*rib*2,0))
  for head,(x,y,scale) in enumerate([(0,14,1),(-11,11,.75),(11,11,.75)]):
   sign=0 if head==0 else -1 if head==1 else 1
   yaw=sign*(cast*.5+roar*.3)+math.sin(phase+head)*(.11 if state in ['idle','walk'] else .05)
   h=part(tex,(-4,0,-4),(8,8,8),(0,0),angles=(hurt+cast*.3-dash*.28,yaw,sign*death*.8))
   m+=transform(h,scale=(scale,scale,scale),offset=(x+sign*(cast*1.5+death*9),y+cast*2+abs(roar)+death*(4+head*2),-2-dash*2))
  pitch=-.42 if state=='dash' else cast*.09+roar*.06
  return transform(m,(pitch,0,math.sin(phase)*(.05 if state in ['walk','dash'] else .025)),pivot=(0,12,0),offset=(math.sin(phase)*.8,5+breath+lift*.7,0))
 raise ValueError(name)

def import_sounds(version):
 prism=Path.home()/'.local/share/PrismLauncher'
 meta=json.loads((prism/f'meta/net.minecraft/{version}.json').read_text())
 index=json.loads((prism/f"assets/indexes/{meta['assetIndex']['id']}.json").read_text())['objects']
 def raw(name):
  sha=index['minecraft/'+name]['hash'];data=(prism/f'assets/objects/{sha[:2]}/{sha}').read_bytes()
  assert hashlib.sha1(data).hexdigest()==sha
  return data
 sounds=json.loads(raw('sounds.json'));mapping={};manifest={}
 events={**{'hurt_'+k:'entity.'+k+'.hurt' for k in ['piglin','piglin_brute','zombified_piglin','hoglin','zoglin','wither','wither_skeleton','blaze']},'pot_break':'block.decorated_pot.break','wither_shoot':'entity.wither.shoot','wither_charge':'entity.wither.ambient','wither_death':'entity.wither.death','portal_ignite':'block.end_portal_frame.fill'}
 for ident,event in events.items():
  variants=[]
  for v in sounds[event]['sounds']:
   v={'name':v} if isinstance(v,str) else v
   name=v['name'].replace('minecraft:','');data=raw('sounds/'+name+'.ogg');filename=name.replace('/','_')+'.ogg'
   (ROOT/'assets/audio/minecraft'/filename).write_bytes(data)
   variants.append(dict(path='res://assets/audio/minecraft/'+filename,volume=v.get('volume',1),pitch=v.get('pitch',1)))
   manifest[filename]=dict(source='minecraft/sounds/'+name+'.ogg',sha256=hashlib.sha256(data).hexdigest())
  mapping[ident]=dict(minecraft_event=event,gain=.45,variants=variants)
 (ROOT/'data/nether_audio.json').write_text(json.dumps(mapping,indent=2)+'\n')
 return manifest

def generate():
 version,jar,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(jar)
 base=json.loads((ROOT/'data/animations.json').read_text())
 actors={}
 sheet=Image.new('RGBA',(720,280),(24,24,24,255));d=ImageDraw.Draw(sheet)
 for n,name in enumerate(SOURCES):
  spec=json.loads(json.dumps(base['actors']['zombie']));w,h=SIZES[name]
  spec.update(frame_size=[w,h],source_texture='assets/minecraft/textures/'+SOURCES[name]+'.png',source_model='Vanilla-textured cuboids; game orthographic poses',side_facing='right',projection_yaw=DIRECTIONS,alpha_mode='binary')
  spec.pop('generated_anchor',None)
  if name=='wither':
   spec['columns']=46
   for ident,start,durations,loop in [('cast',22,[.1]*6,False),('dash',28,[.1]*4,True),('roar',32,[.12]*6,True),('death',38,[.2]*8,False)]:
    spec['states'][ident]=dict(start=start,durations=durations,loop=loop)
  atlas=Image.new('RGBA',(w*spec['columns'],h*3))
  for row_i,row in enumerate(DIRECTIONS):
   for state,clip in spec['states'].items():
    for i in range(len(clip['durations'])):
     scale=2.65 if name=='wither' else .94 if name in ['hoglin','zoglin'] else .85
     im=bake(mesh(imp,name,state,i,len(clip['durations'])),(w,h),scale,(w/2,h-5),yaw=DIRECTIONS[row],elevation=20)
     atlas.paste(im,((clip['start']+i)*w,row_i*h))
  used=[SOURCES[name]]
  if name in ['piglin_sword','piglin_crossbow','brute','zombified_piglin']:used+=['item/'+('crossbow_standby' if name=='piglin_crossbow' else 'golden_axe' if name=='brute' else 'golden_sword')]
  imp.save(atlas,name+'_atlas',used,origin=f'Minecraft Java {version}, local vanilla UV textures {used}; existing cuboid rasterizer, custom game projection and animation; no imagegen.')
  actors[name]=spec
  preview=atlas.crop((0,0,w,h)).resize((w*2,h*2),Image.Resampling.NEAREST)
  x=n%5*144;y=n//5*140;sheet.alpha_composite(preview,(x+16,y+8));d.text((x+4,y+112),name,fill='white')
  if name=='wither':
   poses=Image.new('RGBA',(1024,448),(28,28,28,255));pd=ImageDraw.Draw(poses)
   for j,(pose,index) in enumerate([('idle',0),('cast',3),('dash',2),('roar',2),('death',2),('death',5),('walk',2),('hurt',1)]):
    x=(spec['states'][pose]['start']+index)*w
    pic=atlas.crop((x,0,x+w,h)).resize((w*2,h*2),Image.Resampling.NEAREST)
    poses.alpha_composite(pic,(j%4*256,j//4*224));pd.text((j%4*256+8,j//4*224+205),pose+' '+str(index),fill='white')
   poses.save(ROOT/'qa/wither_poses.png')
  print('Baked Nether',name,atlas.size,flush=True)
 items={'axe':'iron_axe','hoe':'iron_hoe','crossbow':'crossbow_standby','fishing':'fishing_rod','gold_boots':'golden_boots','fire_resist':'magma_cream','feather':'feather','ghast_tear':'ghast_tear','golden_carrot':'golden_carrot','ender_eye':'ender_eye','firework':'firework_rocket','hook':'fishing_rod','experience':'experience_bottle'}
 for ident,source in items.items():imp.copy_item(ident,source)
 for ident,source in [('heart_wither','withered_full'),('heart_wither_half','withered_half'),('heart_wither_blink','withered_full_blinking'),('heart_wither_half_blink','withered_half_blinking')]:
  imp.save(imp.tex('gui/sprites/hud/heart/'+source),ident,['gui/sprites/hud/heart/'+source])
 for ident,vanilla in [('sword','sword'),('axe','axe'),('hoe','hoe'),('armor','chestplate')]:
  for tier in ['iron','diamond','netherite']:imp.copy_item(ident+'_'+tier,tier+'_'+vanilla)
 glint=imp.tex('misc/enchanted_glint_item')
 for ident,source in [('sword_netherite','netherite_sword'),('axe_netherite','netherite_axe'),('hoe_netherite','netherite_hoe')]:
  base=imp.tex('item/'+source);frames=Image.new('RGBA',(16*32,16))
  for frame in range(32):
   image=base.copy()
   for y in range(16):
    for x in range(16):
     rr,gg,bb,aa=image.getpixel((x,y))
     if aa:
      value=glint.getpixel(((x*3+y+frame*4)%128,(y*3-x+frame*2)%128))[0]/255
      image.putpixel((x,y),(min(255,rr+int(value*105)),min(255,gg+int(value*45)),min(255,bb+int(value*165)),aa))
   frames.paste(image,(16*frame,0))
  imp.save(frames,ident+'_enchanted',['item/'+source,'misc/enchanted_glint_item'])
  imp.clips[ident+'_enchanted']=dict(frame_size=[16,16],frames=list(range(32)),durations=[.06]*32)
 # Terrain is a deterministic arrangement of untouched vanilla tiles.
 ground=Image.new('RGB',(2048,2048));r=random.Random(724);soul_cells=[]
 tiles=[imp.tex('block/'+s) for s in ['netherrack','soul_sand','blackstone','cracked_nether_bricks']]
 for y in range(128):
  for x in range(128):
   path=abs(y-64-int(math.sin(x*.08)*4))<2 or abs(x-64-int(math.cos(y*.11)*5))<2
   kind=3 if path else (1 if math.sin(x*.13)+math.cos(y*.12)>1.25 else (2 if r.random()<.055 else 0))
   ground.paste(tiles[kind],(x*16,y*16))
   if kind==1:soul_cells.append(y*128+x)
 (ROOT/'data/nether_terrain.json').write_text(json.dumps(dict(tile_size=16,width=128,soul_sand_cells=soul_cells),indent=2)+'\n')
 imp.save(ground,'nether_ground',['block/netherrack','block/soul_sand','block/blackstone','block/cracked_nether_bricks'])
 for name,source in [('arena_tile','polished_blackstone'),('nether_wall','nether_bricks'),('foot_block','cobblestone'),('end_ground','end_stone'),('portal_rim','end_portal_frame_top'),('portal_rim_eye','end_portal_frame_eye')]:imp.save(imp.tex('block/'+source),name,['block/'+source])
 imp.save(imp.tex('entity/end_portal'),'end_portal',['entity/end_portal'])
 imp.native_strip('magma_animation','block/magma')
 imp.native_strip('soul_fire_animation','block/soul_fire_0')
 for i in range(3):
  m=block(imp,'basalt_side',(-4,0,-4),(8,30+i*7,8),'basalt_top')
  imp.save(bake(m,(64,72),1.28,(32,65),yaw=25+i*5,elevation=22),'nether_pillar_'+str(i),['block/basalt_side','block/basalt_top'])
 imp.save(bake(block(imp,'blackstone',(-8,0,-8),(16,16,16)),(32,32),1.2,(16,27)),'nether_rock',['block/blackstone'])
 pot=imp.tex('entity/decorated_pot/decorated_pot_side');basepot=imp.tex('entity/decorated_pot/decorated_pot_base')
 m=box(pot,(-7,0,-7),(14,16,14),faces={f:(pot,(0,0,16,16)) for f in ['north','south','east','west','up','down']})
 m+=part(basepot,(-3,16,-3),(6,3,6),(0,0))
 imp.save(bake(m,(24,28),1,(12,24),yaw=25),'nether_pot',['entity/decorated_pot/decorated_pot_side','entity/decorated_pot/decorated_pot_base'])
 bed=imp.tex('entity/bed/red')
 # The original atlas unfolds a 16x16x6 vertical ModelPart. Rotate its
 # geometry into a mattress; changing dimensions before unwrapping breaks UVs.
 m=[]
 for z,uv in [(0,(0,0)),(16,(0,22))]:
  half=part(bed,(-8,-16,0),(16,16,6),uv)
  m+=transform(half,(math.pi/2,0,0),offset=(0,9,z))
 for x in [-6,6]:
  for z in [-13,13]:m+=part(bed,(x-1,0,z-1),(3,3,3),(50,0))
 image=bake(m,(40,32),1,(20,23),yaw=25)
 imp.save(image,'bed_ground',['entity/bed/red'])
 imp.save(bake(m,(16,16),.43,(8,12),yaw=25,elevation=30),'icon_bed',['entity/bed/red'])
 tnt=imp.tex('block/tnt_side');top=imp.tex('block/tnt_top')
 m=box(tnt,(-8,0,-8),(16,16,16),faces={f:(top if f=='up' else tnt,(0,0,16,16)) for f in ['north','south','east','west','up','down']})
 image=bake(m,(24,28),1,(12,24),yaw=25)
 imp.save(image,'tnt_ground',['block/tnt_side','block/tnt_top']);imp.save(image.resize((16,16),Image.Resampling.NEAREST),'icon_tnt',['block/tnt_side','block/tnt_top'])
 skull=bake(part(imp.tex(SOURCES['wither']),(-4,0,-4),(8,8,8),(0,0)),(16,16),1.4,(8,13),yaw=20)
 imp.save(skull,'wither_skull',['entity/wither/wither'])
 hotbar=Image.open(OUT/'hud_hotbar.png').convert('RGBA')
 # Use the same end caps / middle as the existing six-slot adaptation.
 slots=Image.new('RGBA',(162,22));slots.paste(hotbar.crop((0,0,161,22)),(0,0));slots.paste(hotbar.crop((181,0,182,22)),(161,0))
 imp.save(slots,'hud_eight_slots',['gui/sprites/hud/hotbar'])
 weapon_timings={k:dict(windup=.28,attack=.14,recover=.28) for k in ['axe','hoe','bed','tnt','crossbow','fishing']}
 (ROOT/'data/nether_animations.json').write_text(json.dumps(dict(actors=actors,weapons=weapon_timings),ensure_ascii=False,indent=2)+'\n')
 (ROOT/'data/nether_assets.json').write_text(json.dumps(dict(clips=imp.clips,sprites=list(imp.derived)),indent=2)+'\n')
 (ROOT/'docs/MINECRAFT_NETHER_MANIFEST.json').write_text(json.dumps(dict(version=version,client_jar=str(jar),sound_files=import_sounds(version),raw_files=imp.files,derived=imp.derived,notes='Original local Minecraft textures. Custom 2D cuboid projections and poses using existing importer/rasterizer. Separate solo chapter assets.'),ensure_ascii=False,indent=2)+'\n')
 sheet.save(ROOT/'qa/nether_characters.png')
 print('Nether assets ready',len(imp.derived),flush=True)
 from bake_ghast_intro import generate as generate_ghast
 generate_ghast()
 from bake_end_assets import generate as generate_end
 generate_end()

if __name__=='__main__':generate()
