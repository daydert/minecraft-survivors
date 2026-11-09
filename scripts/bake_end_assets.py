"""Chapter III: local Java 1.21.11 UV textures, existing cuboid rasterizer.
EnderSteve is an original corruption of the vanilla Steve skin, no mod assets.
Dragon animation uses a connected, articulated 3D hierarchy and a shared depth buffer.
"""
from __future__ import annotations
import hashlib,json,math,random
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from import_minecraft_assets import ROOT,Importer,find_client,bake,box
from bake_minecraft_characters import part,transform,humanoid,action_pose,DIRECTIONS,block

SOURCES={'endermite':'entity/endermite','endermite_brood':'entity/endermite','enderman':'entity/enderman/enderman','dispenser_enderman':'entity/enderman/enderman','shulker':'entity/shulker/shulker','endersteve':'entity/player/wide/steve','endersteve_final':'entity/player/wide/steve'}

def corrupted_skin(imp):
 from end_character_mesh import corruption
 skin=corruption(imp)
 imp.save(skin,'endersteve_skin',['entity/player/wide/steve','block/obsidian'],origin='Original coherent End corruption over vanilla Steve UVs.')
 imp.save(corruption(imp,True),'endersteve_final_skin',['entity/player/wide/steve','block/obsidian'])
 return skin

def bake_shulker_bullet(imp):
 # spark.png is a 64x32 cuboid UV layout, not a billboard particle.
 # Bake the native three intersecting cuboids into a single drawable sprite.
 tex=imp.tex('entity/shulker/spark')
 mesh=part(tex,(-4,-4,-1),(8,8,2),(0,0))
 mesh+=part(tex,(-1,-4,-4),(2,8,8),(0,10))
 mesh+=part(tex,(-4,-1,-4),(8,2,8),(20,0))
 imp.save(bake(mesh,(12,12),.9,(6,6),yaw=30,elevation=25),'shulker_bullet',['entity/shulker/spark'],origin='Original local Minecraft shulker spark UVs on the native three-cuboid bullet model; shared orthographic rasterizer.')

def actor_mesh(imp,name,state,i,n,skin):
 tex=imp.tex(SOURCES[name]);gait,lift,action,hurt,breath=action_pose(state,i,n)
 if name in ['endersteve','endersteve_final']:
  from end_character_mesh import rig,corruption
  final=name=='endersteve_final';phase={'slash':'attack','cast':'windup','roar':'windup'}.get(state,state)
  progress=i/max(1,n-1)
  if state in ['cast','roar']:progress=(.7 if state=='cast' else .9)+.08*math.sin(i/max(1,n)*math.tau)
  mesh=rig(imp,corruption(imp,final),'sword',progress,phase,gait,False,True)
  if state=='teleport':mesh=transform(mesh,(-.2,0,0),pivot=(0,12,0),scale=(1-progress*.35,1,1-progress*.35))
  if state=='death':mesh=transform(mesh,(-progress*1.45,0,progress*.12),pivot=(0,3,0),offset=(0,-progress*2,0))
  return mesh
 if name=='shulker':
  opening=.5+.5*math.sin(i/max(1,n)*math.tau) if state in ['idle','walk'] else 1
  mesh=part(tex,(-8,0,-8),(16,8,16),(0,28))
  mesh+=part(tex,(-8,8+opening*10,-8),(16,8,16),(0,0),angles=(0,opening*.3,0),pivot=(0,8,0))
  mesh+=part(tex,(-3,9,-3),(6,6,6),(0,52))
  return mesh
 if name in ['endermite','endermite_brood']:
  mesh=[]
  for j,(w,h,d) in enumerate([(4,3,2),(6,4,5),(4,3,1),(1,2,1)]):
   mesh+=part(tex,(-w/2,0,(-5,-3,2,3)[j]),(w,h,d),(0,(0,5,14,18)[j]),angles=(0,math.sin(i*.7+j)*.22,0),pivot=(0,0,0))
  return transform(mesh,offset=(0,lift*.3,0),scale=(2,2,2) if name.endswith('brood') else (1,1,1))
 tex=tex.copy();tex.alpha_composite(imp.tex('entity/enderman/enderman_eyes'))
 head_y=42
 mesh=part(tex,(-4,head_y,-4),(8,8,8),(0,0))+part(tex,(-4,30,-2),(8,12,4),(32,16))
 carrying=name=='dispenser_enderman'
 for sign in [-1,1]:
  # The 30px legs share the opaque 56,0 limb strip with the arms. The
  # humanoid 0,16 unwrap enters transparent pixels in this 64x32 skin.
  mesh+=part(tex,(sign*2-1,0,-1),(2,30,2),(56,0),angles=(sign*gait*.32,0,0),pivot=(sign*2,30,0))
  arm_angle=.72 if carrying else -sign*gait*.22
  mesh+=part(tex,(sign*5-1,12,-1),(2,30,2),(56,0),angles=(arm_angle,0,sign*.025),pivot=(sign*5,42,0))
 if carrying:
  side=imp.tex('block/furnace_side');front=imp.tex('block/dispenser_front');top=imp.tex('block/furnace_top')
  cube=box(side,(-7,13,-27),(14,14,14),faces={f:(front if f=='north' else top if f=='up' else side,(0,0,16,16)) for f in ['north','south','east','west','up','down']})
  mesh+=cube
 return transform(mesh,offset=(0,breath+lift*.4,0))

def sound_import(version):
 prism=Path.home()/'.local/share/PrismLauncher';meta=json.loads((prism/f'meta/net.minecraft/{version}.json').read_text());index=json.loads((prism/f"assets/indexes/{meta['assetIndex']['id']}.json").read_text())['objects']
 def raw(s):
  sha=index['minecraft/'+s]['hash'];return (prism/f'assets/objects/{sha[:2]}/{sha}').read_bytes()
 events=json.loads(raw('sounds.json'));mapping={};manifest={}
 names={'hurt_enderman':'entity.enderman.hurt','hurt_dispenser_enderman':'entity.enderman.hurt','hurt_endermite':'entity.endermite.hurt','hurt_endermite_brood':'entity.endermite.hurt','hurt_shulker':'entity.shulker.hurt','hurt_endersteve':'entity.player.hurt','hurt_endersteve_final':'entity.player.hurt','hurt_end_dragon':'entity.ender_dragon.hurt','end_teleport':'entity.enderman.teleport','shulker_shoot':'entity.shulker.shoot','dragon_growl':'entity.ender_dragon.growl','dragon_flap':'entity.ender_dragon.flap','dragon_death':'entity.ender_dragon.death','shield_block':'item.shield.block','shield_break':'item.shield.break','mace_smash':'item.mace.smash_ground','wind_burst':'entity.wind_charge.wind_burst','pearl_throw':'entity.ender_pearl.throw','chorus_eat':'item.chorus_fruit.teleport','rocket_launch':'entity.firework_rocket.launch'}
 for ident,event in names.items():
  variants=[]
  for entry in events[event]['sounds']:
   v={'name':entry} if isinstance(entry,str) else entry
   if v.get('type')=='event':continue
   name=v['name'].replace('minecraft:','');data=raw('sounds/'+name+'.ogg');fn=name.replace('/','_')+'.ogg'
   (ROOT/'assets/audio/minecraft'/fn).write_bytes(data)
   variants.append(dict(path='res://assets/audio/minecraft/'+fn,volume=v.get('volume',1),pitch=v.get('pitch',1)))
   manifest[fn]=dict(source='minecraft/sounds/'+name+'.ogg',sha256=hashlib.sha256(data).hexdigest())
  if variants:mapping[ident]=dict(minecraft_event=event,gain=.5,variants=variants)
 (ROOT/'data/end_audio.json').write_text(json.dumps(mapping,indent=2)+'\n')
 return manifest

def generate_characters(imp,version):
 skin=corrupted_skin(imp)
 base=json.loads((ROOT/'data/animations.json').read_text());actors={}
 for name in SOURCES:
  spec=json.loads(json.dumps(base['actors']['zombie']));w,h=(48,64) if 'enderman' in name else (96,96) if 'steve' in name or name.endswith('brood') else (32,32)
  spec.update(frame_size=[w,h],source_texture=SOURCES[name],projection_yaw=DIRECTIONS,side_facing='right');spec.pop('generated_anchor',None)
  spec['shadow_size']={'endermite':[4,2],'endermite_brood':[9,3],'enderman':[7,2],'dispenser_enderman':[9,3],'shulker':[8,3],'endersteve':[8,3],'endersteve_final':[8,3]}[name]
  if 'steve' in name:
   spec['anchor']=[w/2,h-24]
   spec['columns']=70
   for ident,start,durations in [('cast',22,[.1]*8),('teleport',30,[.075]*8),('slash',38,[.065]*8),('stagger',46,[.1]*6),('death',52,[.15]*12),('roar',64,[.15]*6)]:
    spec['states'][ident]=dict(start=start,durations=durations,loop=ident in ['cast','roar'])
  atlas=Image.new('RGBA',(w*spec['columns'],h*3))
  for row_i,row in enumerate(DIRECTIONS):
   for state,clip in spec['states'].items():
    for i in range(len(clip['durations'])):
     pic=bake(actor_mesh(imp,name,state,i,len(clip['durations']),skin),(w,h),.86 if 'steve' in name else .88 if 'enderman' in name else .92,tuple(spec.get('anchor',[w/2,h-4])),yaw=DIRECTIONS[row],elevation=20 if 'steve' in name else 22)
     atlas.paste(pic,((clip['start']+i)*w,row_i*h))
  imp.save(atlas,name+'_atlas',[SOURCES[name]],origin=f'Local Minecraft {version} textures, original game poses; EnderSteve skin corruption derived from vanilla.')
  actors[name]=spec;print('Baked End',name,flush=True)
 return actors

def generate():
 version,jar,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(jar)
 actors=generate_characters(imp,version);skin=corrupted_skin(imp)
 items={'spear':'iron_spear','spear_iron':'iron_spear','spear_diamond':'diamond_spear','spear_netherite':'netherite_spear','mace':'mace','knockback_stick':'stick','dragon_breath':'dragon_breath','elytra':'elytra','ender_pearl':'ender_pearl','rabbit_foot':'rabbit_foot','end_eye':'ender_eye','shulker_shell':'shulker_shell','chorus_fruit':'chorus_fruit','wind_charge':'wind_charge'}
 for k,v in items.items():imp.copy_item(k,v)
 imp.save(bake(part(skin,(-2,0,-2),(4,12,4),(40,16)),(16,16),1,(8,14),yaw=25),'icon_end_hand',['entity/player/wide/steve'])
 # Shield is a native entity model, not a flat item texture in the Java client.
 t=imp.tex('entity/shield_base_nopattern');shield=part(t,(-6,0,-1),(12,22,1),(0,0))+part(t,(-1,7,0),(2,7,5),(26,0))
 imp.save(bake(shield,(16,16),.62,(8,14),yaw=20),'icon_shield',['entity/shield_base_nopattern'])
 # Crystal's two nested rotating glass shells and core retain native atlas UV.
 t=imp.tex('entity/end_crystal/end_crystal')
 def crystal_part(origin,size,uv,angles=(0,0,0)):
  mesh=part(t,origin,size,uv,angles=angles,pivot=(0,13,0))
  return [(v,tex,tuple(c*2 for c in rect),shade) for v,tex,rect,shade in mesh]
 m=crystal_part((-4,9,-4),(8,8,8),(32,0))
 for angles in [(.4,.6,.2),(-.4,-.6,.5)]:
  shell=crystal_part((-4,9,-4),(8,8,8),(0,0),angles)
  m+=transform(shell,pivot=(0,13,0),scale=(1.5,1.5,1.5))
 crystal=bake(m,(40,48),1.25,(20,38),yaw=25)
 imp.save(crystal,'end_crystal_ground',['entity/end_crystal/end_crystal'])
 imp.save(bake(m,(16,16),.45,(8,14),yaw=25),'icon_end_crystal',['entity/end_crystal/end_crystal'])
 for k,v in [('end_stone_tile','end_stone'),('end_bricks','end_stone_bricks'),('end_purpur','purpur_block'),('end_obsidian','obsidian'),('end_bedrock','bedrock'),('end_egg','dragon_egg'),('end_rod','end_rod')]:imp.save(imp.tex('block/'+v),k,['block/'+v])
 bake_shulker_bullet(imp)
 imp.save(imp.tex('entity/enderdragon/dragon_fireball'),'dragon_fireball',['entity/enderdragon/dragon_fireball'])
 for variant in range(3):
  m=block(imp,'chorus_plant',(-3,0,-3),(6,26+variant*7,6))
  for s in [-1,1]:
   m+=block(imp,'chorus_plant',(min(0,s*11),17+variant*3,-3),(12,6,6))
   m+=block(imp,'chorus_plant',(s*10-3,19+variant*3,-3),(6,14,6))
   m+=block(imp,'chorus_flower',(s*10-5,31+variant*3,-5),(10,10,10))
  m+=block(imp,'chorus_flower',(-5,26+variant*7,-5),(10,10,10))
  imp.save(bake(m,(56,64),1,(28,58),yaw=20+variant*5),'chorus_'+str(variant),['block/chorus_plant','block/chorus_flower'])
 # Hollow End-city ruins, ribs and pillars add vertical landmarks.
 for variant in range(3):
  m=block(imp,'purpur_pillar',(-6,0,-6),(12,38+variant*12,12),'purpur_pillar_top')
  m+=block(imp,'purpur_block',(-10,38+variant*12,-10),(20,5,20))
  imp.save(bake(m,(56,88),1,(28,80),yaw=25),'end_ruin_'+str(variant),['block/purpur_pillar','block/purpur_block'])
 # Finite island silhouette with jagged tile edges, inner holes and connected paths.
 r=random.Random(724);cells=[];holes=[];image=Image.new('RGBA',(2048,2048))
 end=imp.tex('block/end_stone');brick=imp.tex('block/end_stone_bricks')
 for j in range(32):
  a=j*2.39996;dist=230+(j%6)*100;holes.append((64+math.cos(a)*dist/16,64+math.sin(a)*dist/16,2.1+j%4*.65))
 for y in range(128):
  for x in range(128):
   dx=x-64;dy=y-64;a=math.atan2(dy,dx);edge=58+2*math.sin(a*9)+math.sin(a*17)
   solid=math.hypot(dx,dy)<edge
   if abs(dx)<3 or abs(dy)<3:cut=False
   else:cut=any((x-hx)**2+(y-hy)**2<(hr*(1+.15*math.sin(x*2+y)))**2 for hx,hy,hr in holes)
   solid=solid and not cut
   if solid:
    cells.append(y*128+x);tile=brick if (abs(dx)<2 or abs(dy)<2) and (x+y)%9<4 else end
    image.paste(tile,(x*16,y*16))
 imp.save(image,'end_island',['block/end_stone','block/end_stone_bricks'])
 (ROOT/'data/end_terrain.json').write_text(json.dumps(dict(tile_size=16,width=128,solid_cells=cells),indent=2)+'\n')
 timings={k:dict(windup=.3,attack=.2,recover=.3) for k in ['spear','mace','end_crystal','knockback_stick','dragon_breath','shield']}
 (ROOT/'data/end_animations.json').write_text(json.dumps(dict(actors=actors,weapons=timings),indent=2)+'\n')
 (ROOT/'data/end_assets.json').write_text(json.dumps(dict(clips=imp.clips,sprites=list(imp.derived)),indent=2)+'\n')
 (ROOT/'docs/MINECRAFT_END_MANIFEST.json').write_text(json.dumps(dict(version=version,client_jar=str(jar),raw_files=imp.files,derived=imp.derived,sound_files=sound_import(version),notes='Local vanilla textures. Original EnderSteve corruption, 2D poses, island layout and articulated dragon adaptation. No downloaded mod or imagegen resources.'),ensure_ascii=False,indent=2)+'\n')
 print('End assets ready',len(imp.derived),flush=True)
 from bake_end_dragon import generate as generate_dragon
 generate_dragon()
 from bake_end_equipment import generate as generate_equipment
 generate_equipment()
 from bake_end_finale import generate as generate_finale
 generate_finale()
 from bake_achievement_assets import generate as generate_achievements
 generate_achievements()

if __name__=='__main__':
 import sys
 if '--characters-only' in sys.argv:
  version,jar,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(jar);actors=generate_characters(imp,version)
  path=ROOT/'data/end_animations.json';data=json.loads(path.read_text());data['actors']=actors;path.write_text(json.dumps(data,indent=2)+'\n')
  path=ROOT/'data/end_assets.json';data=json.loads(path.read_text());data['sprites']=list(dict.fromkeys(data['sprites']+list(imp.derived)));path.write_text(json.dumps(data,indent=2)+'\n')
  path=ROOT/'docs/MINECRAFT_END_MANIFEST.json';data=json.loads(path.read_text());data['derived'].update(imp.derived);data['raw_files'].update(imp.files);path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 else:generate()
