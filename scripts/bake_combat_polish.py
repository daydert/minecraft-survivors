"""Local Minecraft cloud mask and a coherent pixel potion puddle, no downloads."""
from pathlib import Path
import sys,math,json,hashlib
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parent))
from import_minecraft_assets import ROOT,Importer,find_client
version,client,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(client)
cloud=imp.tex('environment/clouds').convert('RGBA')
mask=cloud.copy();p=mask.load()
for y in range(mask.height):
 for x in range(mask.width):p[x,y]=(0,0,0,round(p[x,y][3]*.10))
mask.save(ROOT/'assets/sprites/cloud_shadow.png')
stone=imp.tex('block/purple_concrete').convert('RGB');im=Image.new('RGBA',(64,32));p=im.load()
for y in range(32):
 for x in range(64):
  nx=(x-31.5)/29;ny=(y-15.5)/13;a=math.atan2(ny,nx)
  edge=1+.045*math.sin(a*5+.4)+.035*math.cos(a*9-.6)
  d=math.hypot(nx,ny)
  if d>edge:continue
  v=stone.getpixel((x%stone.width,y%stone.height));grain=(v[0]+v[2])//18
  if d>edge-.09:c=(38+grain,15+grain//2,47+grain,205)
  elif d>edge-.17:c=(92+grain,39+grain//2,108+grain,220)
  else:c=(66+grain,27+grain//2,83+grain,210)
  if ((x*13+y*17)%53==0 and d<.8):c=(142,83,157,205)
  p[x,y]=c
im.save(ROOT/'assets/sprites/witch_puddle.png')
from bake_chapter_four_finale import herobrine_skin
source=ROOT/'assets/art_source/ch4_combat';source.mkdir(parents=True,exist_ok=True)
herobrine_skin(imp,'calm').save(source/'hb_skin.png')
imp.tex('block/polished_andesite').save(source/'stone.png')
assets=[]
for name,source in [('cloud_shadow.png','Minecraft '+version+' textures/environment/clouds.png; original alpha × 0.10'),('witch_puddle.png','Original connected pixel mask; native textures/block/purple_concrete.png colour grain')]:
 f=ROOT/'assets/sprites'/name;assets.append({'path':str(f.relative_to(ROOT)),'source':source,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
(ROOT/'docs/COMBAT_POLISH_ASSETS.json').write_text(json.dumps({'local_client':str(client),'assets':assets,'terms':'Existing local Minecraft assets, same provenance and user-authorized project use as licenses/PROJECT_NOTICE.md; no downloads.'},ensure_ascii=False,indent=2)+'\n')
print(version,mask.size,'cloud; connected pixel puddle',im.size)
