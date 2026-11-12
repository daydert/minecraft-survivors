"""Extra local vanilla textures for the reworked chapter-I film; no network."""
import sys, json, shutil
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from import_minecraft_assets import find_client, Importer
version,client,_=find_client(Path.home()/'.local/share/PrismLauncher')
imp=Importer(client)
old=ROOT/'assets/art_source/ch1_intro';out=ROOT/'assets/art_source/ch1_intro_v2';out.mkdir(parents=True,exist_ok=True)
(out/'.gdignore').write_text('\n')
for f in old.glob('*.png'):shutil.copyfile(f,out/f.name)
names=['item/wheat','block/short_grass','block/poppy','block/dandelion','block/hay_block_side','block/hay_block_top','entity/spider/spider_eyes','entity/enderman/enderman_eyes','block/spruce_log','block/dark_oak_leaves','block/composter_side','block/stone','block/coarse_dirt','block/podzol_top']
got=[]
for name in names:
 try:im=imp.tex(name)
 except Exception as e:print('skip',name,e);continue
 if im.height>im.width and name.startswith('block/'):im=im.crop((0,0,im.width,im.width))
 if name in ['block/short_grass','block/dark_oak_leaves']:
  tint=(.46,.66,.23) if 'grass' in name else (.30,.48,.15)
  px=im.load()
  for y in range(im.height):
   for x in range(im.width):
    r,g,b,a=px[x,y];px[x,y]=(int(r*tint[0]),int(g*tint[1]),int(b*tint[2]),a)
 im.save(out/(name.rsplit('/',1)[-1]+'.png'));got.append(name)
(out/'sources.json').write_text(json.dumps({'version':version,'local_client':str(client),'raw':imp.files,'extra':got},indent=2)+'\n')
print(got)
