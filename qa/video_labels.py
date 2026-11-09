from PIL import Image, ImageDraw, ImageFont
im=Image.new('RGB',(1280,48),'#172722');d=ImageDraw.Draw(im)
font=ImageFont.truetype('assets/fonts/DejaVuSans-Bold.ttf',18)
small=ImageFont.truetype('assets/fonts/DejaVuSans.ttf',11)
for x,title in [(12,'ДО · исходная версия'),(652,'ПОСЛЕ · позы, подготовка, контакт')]:
 d.text((x,2),title,font=font,fill='#e7e6c7')
 d.text((x,28),'seed 724 · тот же ввод · 5 с: шесть оружий · 10 с: эволюции · 13 с: пауза',font=small,fill='#b3ce80')
im.save('qa/recordings/comparison_labels.png')
