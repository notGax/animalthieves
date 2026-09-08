from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
P=Path(__file__).resolve().parent
sheet=Image.new('RGB',(1800,1260),'#ece9e3');d=ImageDraw.Draw(sheet)
fonts=Path('C:/Windows/Fonts')
title=ImageFont.truetype(str(fonts/'bahnschrift.ttf'),34)
label=ImageFont.truetype(str(fonts/'bahnschrift.ttf'),19)
small=ImageFont.truetype(str(fonts/'segoeui.ttf'),19)
d.text((42,26),'RAT FORM / LANKY SEWER RAT',font=title,fill='#292c2a')
d.text((43,76),'Animal Thieves  ·  Selected concept translated to a faceted 3D model',font=small,fill='#656862')
hero=Image.open(P/'hero_preview.png').convert('RGB').resize((1100,1100),Image.Resampling.LANCZOS)
sheet.paste(hero,(20,122))
for name,y in [('front',122),('side',489),('back',856)]:
    im=Image.open(P/f'{name}_preview.png').convert('RGB').resize((360,360),Image.Resampling.LANCZOS)
    sheet.paste(im,(1210,y))
    d.text((1586,y+160),name.upper(),font=label,fill='#444940')
d.text((42,1225),'2,426 triangles  /  4 materials  /  Static posed model',font=small,fill='#656862')
sheet.save(P/'rat_contact_sheet.jpg',quality=94)
