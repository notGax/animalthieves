"""Package Blender-rendered frames into a shareable MP4, looping GIF and pose sheet."""
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont

P=Path(__file__).resolve().parent/'rigged'
def font(size): return ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',size)
clips=[('Sneak_Walk',48,'SNEAK WALK','Alternating steps / arm swing / trailing tail'),
       ('Alert_Idle',72,'ALERT IDLE','Head turns / breathing / ear and finger motion')]
for name,length,_,_ in clips:
    assert all((P/'frames'/name/f'{f:04}.png').exists() for f in range(1,length+1)),name

args=['ffmpeg','-hide_banner','-loglevel','error','-y','-f','rawvideo','-vcodec','rawvideo',
      '-pix_fmt','rgb24','-s','800x800','-r','24','-i','-','-an','-c:v','libx264',
      '-preset','medium','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(P/'rat_movement_demo.mp4')]
proc=subprocess.Popen(args,stdin=subprocess.PIPE)
for name,length,title,desc in clips:
    for repeat in range(2):
        for f in range(1,length+1):
            im=Image.new('RGB',(800,800),(237,234,227)); d=ImageDraw.Draw(im)
            d.text((32,15),'RAT FORM / MOVEMENT STUDY',font=font(27),fill=(42,46,43))
            d.text((32,53),'Animal Thieves',font=font(17),fill=(94,97,90))
            im.paste(Image.open(P/'frames'/name/f'{f:04}.png').convert('RGB'),(80,87))
            d.text((32,727),title,font=font(23),fill=(42,46,43))
            d.text((32,759),desc,font=font(16),fill=(94,97,90))
            d.line((520,750,768,750),fill=(187,186,178),width=3)
            d.line((520,750,520+int(248*(f-1)/(length-1)),750),fill=(188,75,70),width=4)
            proc.stdin.write(im.tobytes())
proc.stdin.close()
assert proc.wait()==0

frames=[Image.open(P/'frames'/'Sneak_Walk'/f'{f:04}.png').convert('RGB').resize((480,480),Image.Resampling.LANCZOS) for f in range(1,49)]
palette=frames[0].quantize(colors=192)
gif=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in frames]
gif[0].save(P/'sneak_walk.gif',save_all=True,append_images=gif[1:],loop=0,
            duration=[40,40,40,40,40,50]*8,disposal=2,optimize=False)

sheet=Image.new('RGB',(1600,1030),(237,234,227));d=ImageDraw.Draw(sheet)
d.text((26,15),'RAT FORM / RIG + MOTION',font=font(31),fill=(42,46,43))
d.text((26,58),'Original animation / editable Blender rig / skeletal GLB',font=font(19),fill=(94,97,90))
for row,(name,_,title,_) in enumerate(clips):
    d.text((26,100+row*440),title,font=font(21),fill=(42,46,43))
    for col,f in enumerate([1,13,25,37]):
        tile=Image.open(P/'frames'/name/f'{f:04}.png').resize((388,388),Image.Resampling.LANCZOS)
        sheet.paste(tile,(12+col*397,132+row*440))
        d.text((24+col*397,522+row*440),f'Frame {f:02}',font=font(17),fill=(94,97,90))
d.text((26,994),'Foot and hand IK / individual digits / articulated ears / six-bone tail',font=font(18),fill=(94,97,90))
sheet.save(P/'movement_contact_sheet.jpg',quality=93)
print('PACKAGED',[(n,(P/n).stat().st_size) for n in ['rat_movement_demo.mp4','sneak_walk.gif','movement_contact_sheet.jpg']])
