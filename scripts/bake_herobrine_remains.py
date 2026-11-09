"""Collapsed, distorted Steve pose using the existing native-UV cuboid baker."""
import hashlib,json,math
from pathlib import Path
from PIL import Image
from import_minecraft_assets import ROOT,Importer,find_client,bake
from bake_minecraft_characters import part,transform

SKIN='entity/player/wide/steve'
def remains(imp,settle):
 tex=imp.tex(SKIN)
 torso=part(tex,(-4,12,-2),(8,10,4),(16,16))
 torso+=part(tex,(-4,12,-2),(8,10,4),(16,32),inflate=.2)
 mesh=transform(torso,(.15,.28,-.14),pivot=(0,12,0),scale=(.83,.92,1.12))
 head=part(tex,(-4,22,-4),(8,8,8),(0,0))+part(tex,(-4,22,-4),(8,8,8),(32,0),inflate=.2)
 mesh+=transform(head,(-.3,.35,-.48),pivot=(0,22,0),offset=(-.5,-1,0))
 for sign in [-1,1]:
  uv=(0,16) if sign<0 else (16,48)
  leg=part(tex,(-2,-6,-2),(4,6,4),uv)
  shin=part(tex,(-2,-6,-2),(4,6,4),(uv[0],uv[1]+6))
  leg+=transform(shin,(1.85 if sign<0 else -.95,0,sign*.18),offset=(0,-6,0))
  mesh+=transform(leg,(.7 if sign<0 else -.3,sign*.12,sign*(.5+.1*settle)),offset=(sign*2,12,0))
  uv=(40,16) if sign<0 else (32,48)
  arm=part(tex,(-2,-6,-2),(4,6,4),uv)
  hand=part(tex,(-2,-6,-2),(4,6,4),(uv[0],uv[1]+6))
  arm+=transform(hand,(1.7 if sign<0 else -1.3,0,sign*.2),offset=(0,-6,0))
  mesh+=transform(arm,(.55 if sign<0 else -.9,sign*.25,sign*(.8+.16*settle)),offset=(sign*5.3,20,0))
 return transform(mesh,(math.pi/2+.05*settle,1.35,-.12+.06*settle),pivot=(0,12,0),offset=(0,-12,0))

def generate():
 version,jar,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(jar)
 strip=Image.new('RGBA',(48*12,48))
 for i in range(12):
  t=i/11;t=t*t*(3-2*t)
  strip.paste(bake(remains(imp,t),(48,48),1.05,(24,20),yaw=0,elevation=25),(48*i,0))
 imp.save(strip,'herobrine_remains',[SKIN],origin='Original Steve UV on an asymmetrically collapsed cuboid rig; custom distorted limbs and torso. Existing Minecraft baker.')
 manifest=dict(version=version,client_jar=str(jar),raw_files=imp.files,derived=imp.derived,frames=12,frame_size=[48,48],notes='Secret chapter-I ending only. No gameplay, legacy finale or other chapters changed.')
 (ROOT/'docs/MINECRAFT_REMAINS_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 strip.crop((48*11,0,48*12,48)).resize((384,384),Image.Resampling.NEAREST).save(ROOT/'qa/herobrine_remains_pose.png')
 print('REMAINS_BAKE 12 collapsed poses; original Minecraft Steve texture',flush=True)

if __name__=='__main__':generate()
