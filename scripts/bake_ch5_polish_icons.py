"""Small native asset bake; never rebakes the Notch animation atlas."""
import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from bake_chapter_five import cube,frame0
from import_minecraft_assets import ROOT,Importer,find_client
from PIL import Image
version,client,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(client)
t=lambda n:frame0(imp.tex(n))
images={'repeating_block':cube(t('block/repeating_command_block_front'),t('block/repeating_command_block_side'),t('block/repeating_command_block_back')),'breakpoint':t('block/redstone_torch')}
base=t('item/potion');overlay=t('item/potion_overlay')
# Vanilla bottle + vanilla potion liquid tinted Minecraft healing pink.
liquid=overlay.copy()
for y in range(liquid.height):
 for x in range(liquid.width):
  r,g,b,a=liquid.getpixel((x,y));liquid.putpixel((x,y),(int(r*.95),int(g*.18),int(b*.32),a))
liquid.alpha_composite(base);images['healing_v']=liquid
for name,im in images.items():imp.save(im,'icon_'+name,['Minecraft Java '+version+' vanilla textures; healing potion tint'])
p=ROOT/'data/chapter_five_assets.json';data=json.loads(p.read_text());data['sprites']=list(dict.fromkeys(data['sprites']+['icon_'+n for n in images]));p.write_text(json.dumps(data,indent=1)+'\n')
(ROOT/'docs/CH5_POLISH_ASSETS.json').write_text(json.dumps({'version':version,'raw_files':imp.files,'derived':imp.derived},indent=1)+'\n')
