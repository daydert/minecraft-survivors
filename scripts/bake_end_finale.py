"""Additional End finale poses and ruined Overworld, from local vanilla resources.
Does not replace any chapter I/II atlas. Randomness is confined to this baker.
"""
import json,math,random,re
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageEnhance
from import_minecraft_assets import ROOT,Importer,find_client,bake,box
from bake_minecraft_characters import part,transform,DIRECTIONS,block
from bake_herobrine_duel import rig as kneel
from end_character_mesh import rig,corruption

def smooth(t):
 t=max(0,min(1,t));return t*t*(3-2*t)

class Skin:
 def __init__(self,skin):self.skin=skin
 def tex(self,_):return self.skin.copy()

def title():
 folder=ROOT/'assets/fonts/minecraft';pages={};glyphs={}
 for line in (folder/'minecraft_bold.fnt').read_text().splitlines():
  if line.startswith('page '):
   ident=int(re.search(r'id=(\d+)',line)[1]);name=re.search(r'file="([^"]+)"',line)[1];pages[ident]=Image.open(folder/name).convert('RGBA')
  elif line.startswith('char '):
   d={k:int(v) for k,v in re.findall(r'(\w+)=(-?\d+)',line)};glyphs[d['id']]=d
 value='«Обычный мир»';width=sum(glyphs[ord(c)]['xadvance'] for c in value);out=Image.new('RGBA',(width,10));x=0
 for c in value:
  d=glyphs[ord(c)];im=pages[d['page']].crop((d['x'],d['y'],d['x']+d['width'],d['y']+d['height']))
  out.alpha_composite(im,(x+d['xoffset'],d['yoffset']));x+=d['xadvance']
 return out.resize((width*3,30),Image.Resampling.NEAREST)

def generate():
 version,jar,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(jar)
 # Plain columns, without crossbeams or overhanging caps.
 for variant in range(3):
  mesh=block(imp,'purpur_pillar',(-6,0,-6),(12,38+variant*12,12),'purpur_pillar_top')
  imp.save(bake(mesh,(56,88),1,(28,80),yaw=25),'end_ruin_'+str(variant),['block/purpur_pillar','block/purpur_pillar_top'])
 terrain=json.loads((ROOT/'data/end_terrain.json').read_text());island=Image.new('RGBA',(2048,2048));end=imp.tex('block/end_stone')
 for cell in terrain['solid_cells']:island.paste(end,(cell%128*16,cell//128*16))
 imp.save(island,'end_island',['block/end_stone'])
 # Native stepped dragon egg block model, including its original face UVs.
 model=json.loads(imp.jar.read('assets/minecraft/models/block/dragon_egg.json'));mesh=[];tex=imp.tex('block/dragon_egg')
 for e in model['elements']:
  lo=np.array(e['from']);hi=np.array(e['to']);faces={k:(tex,tuple(v['uv'])) for k,v in e['faces'].items()}
  mesh+=box(tex,tuple(lo-np.array([8,0,8])),tuple(hi-lo),faces=faces)
 imp.save(bake(mesh,(28,32),1,(14,28),yaw=25),'end_egg_model',['block/dragon_egg'])
 # Connected knees, reaching hand and a held-object takeoff; body scale remains .86.
 hero=imp.tex('entity/player/wide/steve');boss=corruption(imp,True)
 for name,skin in [('end_player_pickup',hero),('end_player_jump',hero),('end_duel_leap',boss)]:
  atlas=Image.new('RGBA',(64*16,64*3))
  for row_i,row in enumerate(DIRECTIONS):
   for i in range(16):
    t=i/15
    if name=='end_player_pickup':mesh=kneel(Skin(skin),kneeling=math.sin(t*math.pi)*.9,herobrine=False)
    else:
     mesh=rig(imp,skin,'hand' if name=='end_player_jump' else 'sword',t,'windup' if t<.4 else 'attack',math.sin(t*math.pi)*.45,final=name=='end_duel_leap')
     mesh=transform(mesh,(-.12+math.sin(t*math.pi)*.3,0,0),pivot=(0,12,0))
    atlas.paste(bake(mesh,(64,64),.86,(32,57),yaw=DIRECTIONS[row],elevation=20),(i*64,row_i*64))
  imp.save(atlas,name,['entity/player/wide/steve','block/obsidian'],origin='Complete connected vanilla-skin articulated rig, scale .86, three directions.')
 # Defeat: collapse to knees, corrupt skin cracks, rises and loses pixel fragments.
 atlas=Image.new('RGBA',(128*48,128*3))
 for row_i,row in enumerate(DIRECTIONS):
  for i in range(48):
   t=i/47;skin=boss.copy();crack=smooth((t-.23)/.35);dissolve=smooth((t-.58)/.3)
   for y in range(64):
    for x in range(64):
     r,g,b,a=skin.getpixel((x,y));noise=((x*73+y*157+x*y*11)%997)/997
     if noise<dissolve:skin.putpixel((x,y),(0,0,0,0))
     elif a and (x*3+y*5)%17<crack*5:skin.putpixel((x,y),(210,140,255,a))
   mesh=kneel(Skin(skin),kneeling=smooth(t/.2)*(1-smooth((t-.32)/.26))*.95,herobrine=False)
   mesh=transform(mesh,(0,0,math.sin(t*20)*.045*(1-t)),pivot=(0,12,0),offset=(0,math.sin(smooth((t-.35)/.4)*math.pi)*10,0))
   # Pixel cubes carry pieces of the corrupted skin out of the silhouette.
   for j in range(45):
    start=.58+(j%7)*.018
    if t<=start or t>.94:continue
    f=(t-start)/.35;angle=j*2.39996
    origin=(math.cos(angle)*(5+f*32),8+j%23+f*(8+j%9),math.sin(angle)*(4+f*18))
    mesh+=part(boss,origin,(1,1,1),(40+j%8,18+j%10))
   atlas.paste(bake(mesh,(128,128),.86,(64,100),yaw=DIRECTIONS[row],elevation=20),(i*128,row_i*128))
  print('Defeat direction',row,flush=True)
 imp.save(atlas,'end_finale_death',['entity/player/wide/steve','block/obsidian'],origin='Original collapse, kneel, levitation, cracking skin and pixel disintegration, 48 frames in three directions.')
 # An opaque ground, not a transparent scorched overlay.
 r=random.Random(724);ground=Image.new('RGBA',(640,360),(10,7,11,255));grass=imp.tex('block/grass_block_top');blood=imp.tex('block/nether_wart_block');soil=imp.tex('block/netherrack');crimson=imp.tex('block/crimson_nylium')
 for y in range(150,360):
  for x in range(640):
   depth=(y-150)/210;u=int((x-320)/(max(.16,depth)*2)+320);v=int(150+80*math.log(.16+depth))
   pool=math.sin(u*.035+math.sin(v*.13)*2)+math.cos(v*.055)+math.sin(u*.082+v*.061)*.4
   texture=blood if pool>.15 else soil if pool>-.9 else crimson
   a,b,c,_=texture.getpixel((u%16,v%16));fog=.3+.38*depth
   ground.putpixel((x,y),(int(a*fog*.95),int(b*fog*.58),int(c*fog*.65),255))
 d=ImageDraw.Draw(ground)
 # Ruined walls and scattered masonry with a clear horizon.
 for j in range(33):
  x=j*23+r.randint(-15,10);base=166+r.randrange(12);height=r.randrange(8,45)
  d.rectangle((x,base-height,x+r.randrange(6,15),base),fill=(18,12,16,255))
 imp.save(ground,'end_teaser_ground',['block/nether_wart_block','block/netherrack','block/crimson_nylium'])
 imp.save(title(),'end_chapter_title',['Minecraft bitmap font, Cyrillic and accented glyphs'],origin='Existing Minecraft bold bitmap glyphs, nearest-neighbour at 24px; readable base for occasional sliced glitch.')
 path=ROOT/'docs/MINECRAFT_END_MANIFEST.json';data=json.loads(path.read_text());[data['derived'].pop(prefix+str(i),None) for prefix in ['end_flesh_','end_rubble_'] for i in range(3)];data['derived'].update(imp.derived);data['raw_files'].update(imp.files);path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 path=ROOT/'data/end_assets.json';data=json.loads(path.read_text());data['sprites']=list(dict.fromkeys([n for n in data['sprites'] if not n.startswith(('end_flesh_','end_rubble_'))]+list(imp.derived)));path.write_text(json.dumps(data,indent=2)+'\n')
 print('END_FINALE_BAKE',len(imp.derived),flush=True)
if __name__=='__main__':generate()
