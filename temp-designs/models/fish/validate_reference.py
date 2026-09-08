"""Reference comparison in a fixed camera registration, using Pillow/numpy."""
from pathlib import Path
import json
from collections import deque
import numpy as np
from PIL import Image, ImageDraw, ImageFont
P=Path(__file__).resolve().parent
ref=Image.open(P.parent.parent/'selected-concepts/fish.png').convert('RGB').crop((970,35,1220,590)).resize((500,1110))
ref.save(P/'reference_front_crop.png')
a=np.asarray(ref).astype(int)
mask=(a[:,:,2]>a[:,:,0]+7)&(a.max(axis=2)<220)
def fill_holes(mask):
    h,w=mask.shape;seen=np.zeros_like(mask);todo=deque()
    for x in range(w):
        for y in [0,h-1]:
            if not mask[y,x]:todo.append((y,x));seen[y,x]=True
    for y in range(h):
        for x in [0,w-1]:
            if not mask[y,x]:todo.append((y,x));seen[y,x]=True
    while todo:
        y,x=todo.popleft()
        for yy,xx in [(y-1,x),(y+1,x),(y,x-1),(y,x+1)]:
            if 0<=yy<h and 0<=xx<w and not seen[yy,xx] and not mask[yy,xx]:
                seen[yy,xx]=True;todo.append((yy,xx))
    # Keep intentional large gaps between limbs/tail open. Fill enclosed eye/mouth regions to compare the outer silhouette.
    holes=(~seen)&(~mask);visited=np.zeros_like(mask)
    for yy,xx in zip(*np.nonzero(holes)):
        if visited[yy,xx]:continue
        q=deque([(yy,xx)]);visited[yy,xx]=True;component=[]
        while q:
            y,x=q.popleft();component.append((y,x))
            for y2,x2 in [(y-1,x),(y+1,x),(y,x-1),(y,x+1)]:
                if 0<=y2<h and 0<=x2<w and holes[y2,x2] and not visited[y2,x2]:
                    visited[y2,x2]=True;q.append((y2,x2))
        if len(component)<5000:
            for y,x in component:mask[y,x]=True
    return mask
mask=fill_holes(mask)
render=Image.open(P/'front_mask.png').convert('RGBA')
r=np.asarray(render);rm=r[:,:,3]>127
Image.fromarray(np.uint8(mask)*255).save(P/'reference_mask.png')
Image.fromarray(np.uint8(rm)*255).save(P/'render_mask.png')
intersection=(mask&rm).sum();union=(mask|rm).sum()
cy,cx=np.nonzero(mask);ry,rx=np.nonzero(rm)
center_dist=float(np.linalg.norm([cx.mean()-rx.mean(),cy.mean()-ry.mean()]))
iou=float(intersection/union)
out=np.asarray(ref).copy()
out[mask&~rm]=(237,83,144);out[rm&~mask]=(37,190,228)
Image.fromarray(out).save(P/'front_overlay_reference.png')
audit=json.loads((P/'scene_validation.json').read_text())
# Measured eye centers in the registered reference crop.
rf=[[160,294],[324,294]]
mf=[]
for cx,cy in rf:
    roi=r[cy-12:cy+13,cx-12:cx+13,:3]
    yy,xx=np.nonzero(roi.max(axis=2)<65)
    mf.append([float(xx.mean()+cx-12),float(yy.mean()+cy-12)] if len(xx) else [1e6,1e6])
face_errors=[float(np.linalg.norm(np.array(x)-np.array(y))) for x,y in zip(rf,mf)]
face_pass=max(face_errors)<12
report={'comparison':'Fixed reference-pixel registration. Pink is reference only; cyan is model only.',
 'front_mask_iou':iou,'threshold':.90,'centroid_distance_px':center_dist,
 'expected_primary_parts':4,'actual_primary_parts':audit['primary_count'],'primary_parts_pass':audit['primary_count']==4,
 'eyes_expected':2,'eyes_actual':audit['eye_count'],'front_mask_pass':iou>=.90,'centroid_pass':center_dist<=12,
 'reference_face_centers':rf,'model_face_centers':mf,'face_center_errors_px':face_errors,'face_pass':face_pass,
 'limitations':'Front view is primary; curved depth interpreted from side and hero. Fin pose differs across generated views. Exactly two pectoral fins and a single intact forked caudal fin.'}
report['pass']=all([report['front_mask_pass'],report['centroid_pass'],report['primary_parts_pass'],face_pass,audit['eye_count']==2,audit['geometry_pass']])
(P/'front_mask_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
