"""Review projections only: original atlas pixels enlarged with nearest sampling."""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parent.parent
m=json.loads((ROOT/'data/chapter_four_equipment.json').read_text())
font=ImageFont.truetype(str(ROOT/'assets/fonts/DejaVuSans.ttf'),13)
labels=[('bedrock_w3_a1',['Бедрок','Крылья и железная дева']),('shotgun_w0_a0',['Дробовик']),('bone_saw_w2_a0',['Костяная пила']),('bell_w0_a0',['Колокол']),('sky_tnt_w0_a0',['Небесный подрыв']),('potion_w0_a0',['Зелья'])]
out=Image.new('RGBA',(1200,365),(27,24,26));draw=ImageDraw.Draw(out)
for column,(key,lines) in enumerate(labels):
 name='ch4_held_'+key;meta=m['held'][name];im=Image.open(ROOT/'assets/sprites'/(name+'.png'));w,h=meta['frame_size'];anchor=meta['anchor']
 for row in range(3):
  frame=im.crop((8*w,row*h,9*w,(row+1)*h)).resize((w*3,h*3),Image.Resampling.NEAREST)
  out.alpha_composite(frame,(column*200+100-anchor[0]*3,row*100+100-anchor[1]*3))
 for index,line in enumerate(lines):draw.text((column*200+7,325+index*18),line,font=font,fill=(215,207,203))
out.convert('RGB').save(ROOT/'qa/chapter_four_c/held_models.png')
