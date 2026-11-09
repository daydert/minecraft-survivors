"""Twelve original badge compositions using the game's local vanilla resources.
No generated illustrations: nearest pixels, the shared cuboid baker and native UVs.
"""
import hashlib,json,re
from pathlib import Path
from PIL import Image,ImageDraw,ImageEnhance
from import_minecraft_assets import ROOT,Importer,find_client,bake,box
from bake_minecraft_characters import part,block


def badge(imp,block_name='obsidian'):
 im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
 tile=ImageEnhance.Brightness(imp.tex('block/'+block_name)).enhance(.36)
 for y in [1,17]:
  for x in [1,17]:im.alpha_composite(tile,(x,y))
 d.rectangle((0,0,31,31),outline=(24,24,24,255));d.rectangle((1,1,30,30),outline=(117,117,117,255));d.line((2,2,29,2),fill=(176,176,176,255));d.line((2,29,29,29),fill=(57,57,57,255))
 return im

def item(imp,im,name,xy,size=16,rotate=0):
 tex=imp.tex('item/'+name).crop((0,0,16,16))
 if rotate:tex=tex.rotate(rotate,resample=Image.Resampling.NEAREST)
 if size!=16:tex=tex.resize((size,size),Image.Resampling.NEAREST)
 im.alpha_composite(tex,xy)

def cube(imp,name,origin=(0,0,0),size=(16,12,16),top=None):
 return bake(block(imp,name,origin,size,top),(30,27),.9,(15,24),yaw=25,elevation=25)

def question():
 folder=ROOT/'assets/fonts/minecraft';lines=(folder/'minecraft_bold.fnt').read_text().splitlines();pages={}
 for line in lines:
  if line.startswith('page '):pages[int(re.search(r'id=(\d+)',line)[1])]=re.search(r'file="([^"]+)"',line)[1]
  if line.startswith('char id=63 '):data={k:int(v) for k,v in re.findall(r'(\w+)=(-?\d+)',line)}
 tex=Image.open(folder/pages[data['page']]).convert('RGBA');im=tex.crop((data['x'],data['y'],data['x']+data['width'],data['y']+data['height']))
 return im.resize((im.width*3,im.height*3),Image.Resampling.NEAREST)

def audio(imp,version):
 prism=Path.home()/'.local/share/PrismLauncher';meta=json.loads((prism/f'meta/net.minecraft/{version}.json').read_text());index=json.loads((prism/f"assets/indexes/{meta['assetIndex']['id']}.json").read_text())['objects']
 def raw(name):
  digest=index['minecraft/'+name]['hash'];content=(prism/f'assets/objects/{digest[:2]}/{digest}').read_bytes();assert hashlib.sha1(content).hexdigest()==digest;return content
 event=json.loads(raw('sounds.json'))['ui.toast.in'];variants=[];manifest={}
 for spec in event['sounds']:
  spec={'name':spec} if isinstance(spec,str) else spec
  name=spec['name'].removeprefix('minecraft:');content=raw('sounds/'+name+'.ogg');filename='achievement_'+name.replace('/','_')+'.ogg';target=ROOT/'assets/audio/minecraft'/filename;target.write_bytes(content)
  manifest[filename]={'source':'minecraft/sounds/'+name+'.ogg','sha256':hashlib.sha256(content).hexdigest()}
  variants.append({'path':'res://assets/audio/minecraft/'+filename,'volume':spec.get('volume',1),'pitch':spec.get('pitch',1)})
 (ROOT/'data/achievement_audio.json').write_text(json.dumps({'achievement':{'minecraft_event':'ui.toast.in','gain':.45,'variants':variants}},indent=2)+'\n')
 return manifest

def generate():
 version,jar,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(jar);images={}
 im=badge(imp,'netherrack');im.alpha_composite(cube(imp,'grass_block_side',(-8,0,-8),(13,9,13),'grass_block_top'),(-4,6));im.alpha_composite(cube(imp,'netherrack',(-8,0,-8),(12,10,12)),(8,4));item(imp,im,'flint_and_steel',(9,5));images['chapter_one']=im
 im=badge(imp);item(imp,im,'amethyst_shard',(2,12));item(imp,im,'netherite_sword',(10,3));d=ImageDraw.Draw(im);d.line((7,5,7,11),fill='#e0c0ff');d.line((4,8,10,8),fill='#e0c0ff');images['first_evolution']=im
 im=badge(imp,'oak_planks');tex=imp.tex('entity/chest/normal')
 chest=part(tex,(-7,0,-7),(14,10,14),(0,19))+part(tex,(-7,10,-7),(14,5,14),(0,0))+part(tex,(-1,7,-8),(2,4,1),(0,0))
 im.alpha_composite(bake(chest,(30,29),1.35,(15,26),yaw=-25,elevation=22),(1,1));images['full_inventory']=im
 im=badge(imp,'stone_bricks');item(imp,im,'iron_sword',(4,4),24);images['sword_only']=im
 im=badge(imp,'polished_blackstone_bricks');item(imp,im,'netherite_axe',(1,8),20,90);item(imp,im,'netherite_sword',(12,4),18);images['two_weapons']=im
 im=badge(imp,'oak_planks');item(imp,im,'book',(10,10),18);item(imp,im,'iron_sword',(2,3),20);images['no_evolutions']=im
 im=badge(imp,'polished_blackstone_bricks');d=ImageDraw.Draw(im);d.rectangle((6,7,25,25),fill='#080810',outline='#776d86');item(imp,im,'ender_eye',(6,5),20);images['chapter_two']=im
 im=badge(imp,'end_stone');tex=imp.tex('block/dragon_egg');model=json.loads(imp.jar.read('assets/minecraft/models/block/dragon_egg.json'));mesh=[]
 for e in model['elements']:
  lo=e['from'];hi=e['to'];mesh+=box(tex,(lo[0]-8,lo[1],lo[2]-8),tuple(b-a for a,b in zip(lo,hi)),faces={k:(tex,tuple(v['uv'])) for k,v in e['faces'].items()})
 im.alpha_composite(bake(mesh,(26,28),1.15,(13,25),yaw=25),(3,1));images['chapter_three']=im
 im=badge(imp,'oak_planks');item(imp,im,'arrow',(3,12),17,90);item(imp,im,'bow_pulling_2',(7,4),22);images['bow_only']=im
 im=badge(imp,'diamond_block');item(imp,im,'iron_chestplate',(6,6),20);heart=Image.open(ROOT/'assets/sprites/heart.png').convert('RGBA');heart=heart.resize((18,18),Image.Resampling.NEAREST);im.alpha_composite(heart,(7,9));images['untouched']=im
 im=badge(imp,'stone_bricks');item(imp,im,'apple',(6,5),21);d=ImageDraw.Draw(im);d.line((5,26,26,5),fill='#161616',width=5);d.line((5,26,26,5),fill='#b9b9b9',width=3);images['no_healing']=im
 im=badge(imp);skin=imp.tex('entity/player/wide/steve').copy();d=ImageDraw.Draw(skin)
 for x in [9,13]:d.rectangle((x,12,x+1,12),fill='white')
 mesh=part(skin,(-4,0,-4),(8,8,8),(0,0))+part(skin,(-4,0,-4),(8,8,8),(32,0),inflate=.25)
 im.alpha_composite(bake(mesh,(28,27),2,(14,24),yaw=20,elevation=15),(2,2));d=ImageDraw.Draw(im);d.line((4,8,9,8),fill='#6a376f');d.line((24,22,28,22),fill='#9a647f');images['herobrine']=im
 im=badge(imp);q=question();im.alpha_composite(q,((32-q.width)//2,(32-q.height)//2));images['unknown']=im
 sources=[k.removeprefix('textures/').removesuffix('.png') for k in imp.files if k.endswith('.png')]
 for name,im in images.items():imp.save(im,'achievement_'+name,sources,origin='Original badge composition from the same local vanilla items, block cubes and Steve UVs as the game; 32px nearest pixels, gray frame.')
 (ROOT/'data/achievement_assets.json').write_text(json.dumps({'sprites':list(imp.derived)},indent=2)+'\n')
 manifest={'version':version,'client_jar':str(jar),'raw_files':imp.files,'derived':imp.derived,'sound_files':audio(imp,version),'font':'Existing Minecraft bold bitmap font; same glyphs as the game interface.','notes':'Original compositions of local Minecraft resources; no imagegen or external icons.'}
 (ROOT/'docs/MINECRAFT_ACHIEVEMENTS_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 preview=Image.new('RGBA',(32*7,32*2),(22,22,22,255))
 for i,im in enumerate(images.values()):preview.alpha_composite(im,(i%7*32,i//7*32))
 preview.resize((896,256),Image.Resampling.NEAREST).save(ROOT/'qa/achievement_badges.png')
 print('ACHIEVEMENT_BAKE',len(images),'badges',flush=True)
if __name__=='__main__':generate()
