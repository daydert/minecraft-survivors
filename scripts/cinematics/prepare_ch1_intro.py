"""Extract only local vanilla resources for the chapter-I film; no network."""
import sys, json, hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from import_minecraft_assets import find_client, Importer
version,client,_=find_client(Path.home()/'.local/share/PrismLauncher')
imp=Importer(client)
out=ROOT/'assets/art_source/ch1_intro';out.mkdir(parents=True,exist_ok=True)
(out/'.gdignore').write_text('\n')
names=['entity/player/slim/alex','entity/player/wide/steve','block/farmland_moist','block/wheat_stage7','block/oak_log','block/oak_log_top','block/oak_planks','block/cobblestone','block/grass_block_top','block/grass_block_side','block/dirt','block/dirt_path_top','block/oak_leaves','item/iron_sword','entity/chest/normal']
for name in names:
 im=imp.tex(name)
 if im.height>im.width and name.startswith('block/'):im=im.crop((0,0,im.width,im.width))
 if name in ['block/grass_block_top','block/oak_leaves']:
  tint=(.46,.66,.23) if 'grass' in name else (.36,.57,.18)
  for y in range(im.height):
   for x in range(im.width):
    r,g,b,a=im.getpixel((x,y));im.putpixel((x,y),(int(r*tint[0]),int(g*tint[1]),int(b*tint[2]),a))
 im.save(out/(name.rsplit('/',1)[-1]+'.png'))
im=Image.open(out/'steve.png').convert('RGBA')
for x in [10,11,12,13]:
 for y in [12,13]:im.putpixel((x,y),(255,255,255,255))
im.save(out/'herobrine.png')
(out/'sources.json').write_text(json.dumps({'version':version,'local_client':str(client),'raw':imp.files,'derived':['grass/leaf biome tint','Herobrine white eye pixels; otherwise Steve UV']},indent=2)+'\n')
print(out)
