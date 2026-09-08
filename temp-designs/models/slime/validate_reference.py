"""Reference silhouette comparison using Pillow/numpy; no external image service."""
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np, json
P=Path(__file__).resolve().parent
ref=Image.open(P.parent.parent/'selected-concepts/slime.png').convert('RGB').crop((110,755,646,1063))
ref.save(P/'reference_front_crop.png')
a=np.array(ref).astype(float)
mask=(a[:,:,2]>a[:,:,0]+35)&(a[:,:,1]>a[:,:,0]+20)
# Fill horizontal gaps introduced by the black eyes and mouth.
for y in range(len(mask)):
    xs=np.where(mask[y])[0]
    if len(xs):mask[y,xs[0]:xs[-1]+1]=True
render=Image.open(P/'front_mask.png').convert('RGBA')
b=np.array(render)[:,:,3]>127
def box(m):
    yy,xx=np.where(m);return (int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1))
rb=box(mask);bb=box(b)
# Uniform scale to width and align bounding box center; no independent height warp.
scale=(rb[2]-rb[0])/(bb[2]-bb[0])
cut=render.crop(bb);cut=cut.resize((round(cut.width*scale),round(cut.height*scale)),Image.Resampling.LANCZOS)
pos=(rb[0],round((rb[1]+rb[3]-cut.height)/2))
aligned=Image.new('RGBA',ref.size);aligned.paste(cut,pos)
mb=np.array(aligned)[:,:,3]>127
iou=float((mask&mb).sum()/(mask|mb).sum())
yy,xx=np.where(mask);ya,xa=np.where(mb)
centroid=float(np.hypot(xx.mean()-xa.mean(),yy.mean()-ya.mean()))
report={'iou':iou,'centroid_distance_px':centroid,'alignment':'uniform width scale and bbox center; near-front reference is not calibrated orthographic','reference_bbox':rb,'render_original_bbox':bb,'pass':iou>=.90 and centroid<=12,'limitations':'silhouette agreement does not establish exact 3D reconstruction'}
def features(im,bodymask):
    arr=np.array(im.convert('RGB'));dark=(arr.max(axis=2)<90)&bodymask
    yy,xx=np.indices(dark.shape)
    dark &= (yy>rb[1]+.30*(rb[3]-rb[1]))&(yy<rb[1]+.84*(rb[3]-rb[1]))
    dark &= (xx>rb[0]+.12*(rb[2]-rb[0]))&(xx<rb[0]+.9*(rb[2]-rb[0]))
    seen=np.zeros_like(dark);comps=[]
    for y,x in zip(*np.where(dark)):
        if seen[y,x]:continue
        todo=[(y,x)];seen[y,x]=True;points=[]
        while todo:
            a,b=todo.pop();points.append((b,a))
            for dy,dx in [(0,1),(0,-1),(1,0),(-1,0)]:
                ny,nx=a+dy,b+dx
                if 0<=ny<dark.shape[0] and 0<=nx<dark.shape[1] and dark[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True;todo.append((ny,nx))
        if len(points)>25:comps.append({'pixels':len(points),'center':np.mean(points,axis=0).tolist()})
    comps=sorted(comps,key=lambda c:c['pixels'],reverse=True)[:3]
    return comps
fa=features(ref,mask);fb=features(aligned,mb)
report['reference_face_components']=fa;report['render_face_components']=fb
if len(fa)==len(fb)==3:
    # Largest component is the mouth; order the two bead eyes left to right.
    fa=[fa[0]]+sorted(fa[1:],key=lambda c:c['center'][0])
    fb=[fb[0]]+sorted(fb[1:],key=lambda c:c['center'][0])
    errors=[float(np.linalg.norm(np.array(x['center'])-np.array(y['center']))) for x,y in zip(fa,fb)]
    report['face_centroid_errors_px_mouth_left_right']=errors
    report['face_features_pass']=max(errors)<=12
    report['pass']=report['pass'] and report['face_features_pass']
else:
    report['face_features_pass']=False;report['pass']=False
Image.fromarray(mask.astype('uint8')*255).save(P/'reference_mask.png')
Image.fromarray(mb.astype('uint8')*255).save(P/'aligned_render_mask.png')
overlay=Image.blend(ref.convert('RGBA'),aligned,.5);overlay.save(P/'front_overlay_reference.png')
(P/'front_mask_validation.json').write_text(json.dumps(report,indent=2))
def color_stats(im,mask):
    rgb=np.array(im.convert('RGB'));hsv=np.array(im.convert('RGB').convert('HSV'))
    cyan=mask&(rgb[:,:,2].astype(float)>rgb[:,:,0]+35)
    return {'mean_rgb_0_255':rgb[cyan].mean(axis=0).tolist(),'mean_hsv_0_255':hsv[cyan].mean(axis=0).tolist()}
(P/'look_fit_report.json').write_text(json.dumps({'reference':color_stats(ref,mask),'render':color_stats(aligned,mb),'note':'Lighting response remains a 3D material interpretation; image highlights are not painted onto geometry.'},indent=2))
sheet=Image.new('RGB',(1400,1060),'#e9e6e2');draw=ImageDraw.Draw(sheet)
for name,pos in [('hero',(0,30)),('front',(700,30)),('side',(0,550)),('back',(700,550))]:
    im=Image.open(P/f'{name}_preview.png').convert('RGB');im.thumbnail((700,480))
    sheet.paste(im,pos);draw.text((pos[0]+24,pos[1]+6),name.upper(),fill='#333333')
sheet.save(P/'slime_contact_sheet.jpg',quality=95)
print(json.dumps(report,indent=2))
