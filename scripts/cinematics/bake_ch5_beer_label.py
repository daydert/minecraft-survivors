"""Original pixel label for the unbranded finale prop; no third-party branding."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
im=Image.new('RGB',(256,128),'#d2b56b');d=ImageDraw.Draw(im)
for x in range(256):
 shade=int(8*((x%17)/17-.5));d.line((x,0,x,127),fill=(210+shade,181+shade,107+shade))
for y,col in [(0,'#c4c9cb'),(5,'#667174'),(14,'#304638'),(111,'#304638'),(121,'#a4abad')]:d.rectangle((0,y,255,y+4),fill=col)
font=ImageFont.truetype(str(ROOT/'assets/fonts/DejaVuSans-Bold.ttf'),21)
small=ImageFont.truetype(str(ROOT/'assets/fonts/DejaVuSans.ttf'),9)
for x in [0,128]:
 d.rectangle((x+12,31,x+116,96),fill='#e9d9ad',outline='#5f512c',width=2)
 d.text((x+20,39),'ПИВО',font=font,fill='#283e30',stroke_width=0)
 d.line((x+26,67,x+102,67),fill='#7a6539',width=2)
 d.text((x+30,75),'СВЕТЛОЕ',font=small,fill='#3e4b34')
 d.text((x+52,98),'0,5',font=small,fill='#344335')
im.save(ROOT/'assets/art_source/ch5_finale/beer_label.png')
print('Original beer label saved')
