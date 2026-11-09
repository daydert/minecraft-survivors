"""End-only complete Steve poses with tools attached to the palm, vanilla UVs."""
import json,math
from pathlib import Path
from PIL import Image,ImageDraw
from import_minecraft_assets import ROOT,Importer,find_client,bake
from bake_minecraft_characters import DIRECTIONS,STEVE_PIXEL_PHASE
from end_character_mesh import rig

GEAR=['idle','spear_iron','spear_diamond','spear_netherite','mace','knockback_stick','end_crystal','dragon_breath','elytra','rocket','hand']
def generate():
 version,jar,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(jar);skin=imp.tex('entity/player/wide/steve');names=[]
 for gear in GEAR:
  for guard in [False,True]:
   name='end_held_'+gear+('_guard' if guard else '');atlas=Image.new('RGBA',(64*24,64*3))
   for row_i,row in enumerate(DIRECTIONS):
    for i in range(24):
     walking=i>=12;frame=i%12
     phase=['windup','attack','recover'][frame//4] if gear!='idle' else 'idle'
     progress=(frame%4)/3 if gear not in ['elytra','rocket'] else frame/12
     gait=math.sin(frame/12*math.tau) if walking else 0
     mesh=rig(imp,skin,gear,progress,phase,gait,guard)
     pic=bake(mesh,(64,64),.86,(32,57),yaw=DIRECTIONS[row],elevation=20)
     atlas.paste(pic,(i*64,row_i*64))
   sources=[k.removeprefix('textures/').removesuffix('.png') for k in imp.files if k.endswith('.png')]
   imp.save(atlas,name,sources,origin='Original Steve skin, complete shoulder/palm-bound tool rig; existing shared 3D rasterizer. End chapter only.')
   names.append(name)
  print('Palm-bound Steve',gear,flush=True)
 manifest_path=ROOT/'docs/MINECRAFT_END_MANIFEST.json';manifest=json.loads(manifest_path.read_text());manifest['derived'].update(imp.derived);manifest['raw_files'].update(imp.files)
 manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 assets_path=ROOT/'data/end_assets.json';assets=json.loads(assets_path.read_text());assets['sprites']=list(dict.fromkeys(assets['sprites']+names));assets_path.write_text(json.dumps(assets,indent=2)+'\n')
 (ROOT/'data/end_equipment.json').write_text(json.dumps(dict(frame_size=[64,64],anchor=[32,57],columns=24,walking_offset=12,gear=GEAR),indent=2)+'\n')
 preview=Image.new('RGBA',(768,384),(30,26,33,255));draw=ImageDraw.Draw(preview)
 for n,name in enumerate(['spear_netherite','mace','knockback_stick','end_crystal','dragon_breath','elytra','rocket','hand']):
  atlas=Image.open(ROOT/'assets/sprites'/('end_held_'+name+'_guard.png'))
  for row in range(3):
   im=atlas.crop((4*64,row*64,5*64,(row+1)*64)).resize((128,128),Image.Resampling.NEAREST);preview.alpha_composite(im,(n%4*192+row*32,n//4*192))
  draw.text((n%4*192+3,n//4*192+166),name,fill='white')
 preview.save(ROOT/'qa/end_equipment_poses.png')
if __name__=='__main__':generate()
