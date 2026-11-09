"""Native Steve UVs on a shared articulated rig: sit, rise, command and kneel.

The old combined throne and legacy co-op assets are left unchanged.
"""
import hashlib,json,math
from pathlib import Path
from PIL import Image,ImageDraw
from import_minecraft_assets import ROOT,Importer,find_client,bake
from bake_minecraft_characters import part,transform,block

SKIN='entity/player/wide/steve'

def smooth(t):return t*t*(3-2*t)

def rig(imp, standing=0.0, command=0.0, kneeling=0.0, herobrine=True, breath=0.0):
 tex=imp.tex(SKIN).copy()
 if herobrine:
  d=ImageDraw.Draw(tex);d.rectangle((9,12,10,12),fill='white');d.rectangle((13,12,14,12),fill='white')
 hip=(15+standing) if herobrine else 12-5*kneeling
 lean=math.sin(standing*math.pi)*.15 if herobrine else kneeling*.38
 mesh=part(tex,(-4,hip,-2),(8,12,4),(16,16))
 mesh+=part(tex,(-4,hip,-2),(8,12,4),(16,32),inflate=.2)
 mesh+=part(tex,(-4,hip+12,-4),(8,8,8),(0,0),pivot=(0,hip+12,0),angles=(command*.09+kneeling*.12,0,0))
 mesh+=part(tex,(-4,hip+12,-4),(8,8,8),(32,0),pivot=(0,hip+12,0),angles=(command*.09+kneeling*.12,0,0),inflate=.2)
 mesh=transform(mesh,(lean,0,0),pivot=(0,hip,0))
 for sign in [-1,1]:
  upper=1.27*(1-standing) if herobrine else kneeling*.25
  lower=-1.25*(1-standing) if herobrine else -kneeling*1.75
  yaw=sign*.2*(1-standing) if herobrine else 0
  roll=-sign*.13*(1-standing) if herobrine else 0
  uv=(0,16) if sign<0 else (16,48)
  overlay=(0,32) if sign<0 else (0,48)
  leg=part(tex,(-2,-6,-2),(4,6,4),uv)+part(tex,(-2,-6,-2),(4,6,4),overlay,inflate=.15)
  shin=part(tex,(-2,-6,-2),(4,6,4),(uv[0],uv[1]+6))+part(tex,(-2,-6,-2),(4,6,4),(overlay[0],overlay[1]+6),inflate=.15)
  leg+=transform(shin,(lower,0,0),offset=(0,-6,0))
  mesh+=transform(leg,(upper,yaw,roll),offset=(sign*2,hip,0))
  upper_arm=.12*(1-standing) if herobrine else kneeling*.3
  forearm=1.35*(1-standing) if herobrine else kneeling*.1
  arm_roll=sign*.35*(1-standing) if herobrine else sign*.04
  if herobrine and command>0 and sign<0:upper_arm+=command*1.45;forearm*=1-command
  uv=(40,16) if sign<0 else (32,48)
  overlay=(40,32) if sign<0 else (48,48)
  arm=part(tex,(-2,-6,-2),(4,6,4),uv)+part(tex,(-2,-6,-2),(4,6,4),overlay,inflate=.2)
  hand=part(tex,(-2,-6,-2),(4,6,4),(uv[0],uv[1]+6))+part(tex,(-2,-6,-2),(4,6,4),(overlay[0],overlay[1]+6),inflate=.2)
  arm+=transform(hand,(forearm,0,0),offset=(0,-6,0))
  mesh+=transform(arm,(upper_arm,0,arm_roll),offset=(sign*5.7,hip+10,0))
 return transform(mesh,offset=(0,breath,0))

def sounds(version):
 prism=Path.home()/'.local/share/PrismLauncher'
 meta=json.loads((prism/f'meta/net.minecraft/{version}.json').read_text());index=json.loads((prism/f"assets/indexes/{meta['assetIndex']['id']}.json").read_text())['objects']
 def raw(name):
  digest=index['minecraft/'+name]['hash'];data=(prism/f'assets/objects/{digest[:2]}/{digest}').read_bytes();assert hashlib.sha1(data).hexdigest()==digest;return data
 events=json.loads(raw('sounds.json'));mapping={};manifest={}
 for ident,event in [('herobrine_warp','entity.enderman.teleport'),('blood_rift','entity.warden.sonic_boom')]:
  variants=[]
  for spec in events[event]['sounds']:
   spec={'name':spec} if isinstance(spec,str) else spec
   name=spec['name'].replace('minecraft:','');data=raw('sounds/'+name+'.ogg');filename=name.replace('/','_')+'.ogg'
   (ROOT/'assets/audio/minecraft'/filename).write_bytes(data)
   variants.append(dict(path='res://assets/audio/minecraft/'+filename,volume=spec.get('volume',1),pitch=spec.get('pitch',1)))
   manifest[filename]=dict(source='minecraft/sounds/'+name+'.ogg',sha256=hashlib.sha256(data).hexdigest())
  mapping[ident]=dict(minecraft_event=event,gain=.55 if ident=='blood_rift' else .65,variants=variants)
 (ROOT/'data/duel_audio.json').write_text(json.dumps(mapping,indent=2)+'\n');return manifest

def generate():
 version,jar,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(jar)
 mesh=block(imp,'stone_bricks',(-24,0,-17),(48,4,36))
 mesh+=block(imp,'stone_bricks',(-16,4,-10),(32,10,23))
 mesh+=block(imp,'polished_blackstone_bricks',(-16,14,8),(32,36,7))
 mesh+=block(imp,'stone_bricks',(-18,14,-11),(6,10,26))+block(imp,'stone_bricks',(12,14,-11),(6,10,26))
 mesh+=block(imp,'stone_bricks',(-19,48,7),(38,5,10))
 skin=imp.tex(SKIN)
 for x,y,z in [(-15,24,-7),(15,24,-7),(-13,53,8),(13,53,8)]:mesh+=part(skin,(x-4,y,z-4),(8,8,8),(0,0))
 for sign in [-1,1]:
  mesh+=block(imp,'netherrack',(sign*41-5,4,-2),(10,43,10))+block(imp,'nether_bricks',(sign*41-7,0,-4),(14,4,14))
 imp.save(bake(mesh,(192,176),1.55,(96,150),yaw=0,elevation=23),'duel_throne',[SKIN,'block/stone_bricks','block/polished_blackstone_bricks','block/netherrack','block/nether_bricks'])
 previews=[]
 for name,count,duration in [('duel_seated',6,.13),('duel_rise',20,.13),('duel_stand',6,.13),('duel_command',12,.1),('duel_kneel',18,.06)]:
  player=name=='duel_kneel';w,h=(40,48) if player else (80,112)
  strip=Image.new('RGBA',(w*count,h))
  for i in range(count):
   t=smooth(i/max(1,count-1))
   standing=t if name=='duel_rise' else 0 if name=='duel_seated' else 1
   command=t if name=='duel_command' else 0
   frame=bake(rig(imp,standing,command,t if player else 0,not player,0), (w,h),.85 if player else 1.9,(20.5,43.75) if player else (40,104),yaw=180-t*35 if player else 0,elevation=23)
   strip.paste(frame,(i*w,0))
  imp.save(strip,name,[SKIN],origin=f'Minecraft Java {version}; original Steve UV, articulated cuboid hierarchy. Custom seated/rising/command/kneeling pose; Herobrine has approved white eyes.')
  imp.clips[name]=dict(frame_size=[w,h],frames=list(range(count)),durations=[duration]*count)
  previews.append((name,strip,w,h,count))
 sheet=Image.new('RGBA',(960,480),(26,26,26,255));d=ImageDraw.Draw(sheet)
 for row,(name,strip,w,h,count) in enumerate(previews):
  for col,index in enumerate([0,count//3,2*count//3,count-1]):
   frame=strip.crop((index*w,0,(index+1)*w,h));scale=2 if h<60 else 1
   sheet.alpha_composite(frame.resize((w*scale,h*scale),Image.Resampling.NEAREST),(col*240+80,row*96-10 if h>96 else row*96))
   d.text((col*240+4,row*96+78),name+' '+str(index),fill='white')
 sheet.save(ROOT/'qa/herobrine_duel_poses.png')
 (ROOT/'data/duel_assets.json').write_text(json.dumps(dict(clips=imp.clips,sprites=list(imp.derived)),indent=2)+'\n')
 manifest=dict(version=version,client_jar=str(jar),raw_files=imp.files,derived=imp.derived,sound_files=sounds(version),notes='Original Minecraft resources with custom articulated poses; legacy co-op throne is unchanged.')
 (ROOT/'docs/MINECRAFT_DUEL_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 from bake_herobrine_remains import generate as generate_remains
 generate_remains()
 print('DUEL_BAKE',len(imp.derived),'sprites; animated seated torso, rise and kneeling',flush=True)
if __name__=='__main__':generate()
