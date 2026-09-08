# Front pixel rows with explicit front/back Y-depth for the curved fish profile.
rows=[(52,2,-.25,-.21),(72,18,-.33,-.14),(93,38,-.43,-.06),
 (125,48,-.57,.055),(160,60,-.67,.17),(190,64,-.75,.25),
 (215,65,-.82,.30),(235,67,-.87,.34),(248,67,-.82,.37),(258,67,-.60,.39),
 (280,60,-.34,.44),(312,50,-.21,.47),(350,40,-.10,.48),
 (390,29,.015,.44),(430,20,.055,.36),(466,15,.075,.25),(500,10,.07,.17)]
n=16;vs=[];fs=[];mi=[]
for j,(py,w,front,back) in enumerate(rows):
    for k in range(n):
        a=2*math.pi*k/n
        depth=(front+back)/2+(back-front)/2*math.sin(a)
        if math.sin(a)<0 and 160<=py<=258:
            power={160:1.3,190:1.8,215:3,235:4,248:3,258:2}[py]
            depth=(front+back)/2-(back-front)/2*(-math.sin(a))**power
        px=1094+w*math.cos(a)
        vs.append(tuple(xyz(px,py,depth)))
for j in range(len(rows)-1):
    for k in range(n):
        a=j*n+k;b=j*n+(k+1)%n;c=(j+1)*n+(k+1)%n;d=(j+1)*n+k
        # Irregular diagonal facets support a jagged mackerel flank boundary.
        tris=[(a,b,c),(a,c,d)] if (j+k)%2 else [(a,b,d),(b,c,d)]
        for t,face in enumerate(tris):
            fs.append(face)
            front_sector=k in [9,10,11,12,13,14]
            py=(rows[j][0]+rows[j+1][0])/2
            if front_sector and (py>240 or k in [9,14] and py>132 or k in [10,13] and py>185):idx=1
            elif k in [0,1,2,3,4,5,6,7,8,15]:
                idx=2 if (j+t+(k//2))%4 in [0,1,2] else 0
            else:idx=0
            mi.append(idx)
fs.extend([tuple(reversed(range(n))),tuple((len(rows)-1)*n+k for k in range(n))]);mi.extend([0,0])
body=mesh('Body',vs,fs,coat);body.data.materials.append(silver);body.data.materials.append(dark)
for f,i in zip(body.data.polygons,mi):f.material_index=i

def panel(name,outline,center,material,thickness=.035):
    # Closed faceted plate with a crown and a separate back surface.
    n=len(outline);vs=[tuple(xyz(*p)) for p in outline]
    vs.append(tuple(xyz(*center)))
    vs+=[tuple(xyz(x,y,d+thickness)) for x,y,d in outline]
    vs.append(tuple(xyz(center[0],center[1],center[2]+thickness*2)))
    fs=[]
    for k in range(n):
        q=(k+1)%n;fs.extend([(k,q,n),(n+1+k,2*n+1,n+1+q),(k,n+1+k,n+1+q,q)])
    return mesh(name,vs,fs,material)

# Small pectoral fins are the only forelimbs. Forward-set fans retain true fin anatomy.
for s,label in [(-1,'Left'),(1,'Right')]:
    def p(x,y,d):return (1094+s*x,y,d)
    panel('PectoralFin_'+label,[p(59,260,-.035),p(83,267,-.055),p(106,336,-.37),
        p(92,350,-.385),p(78,352,-.40),p(28,327,-.53),p(55,285,-.23)],
        p(65,310,-.48),finmat,.05)

# A compact dark mouth opening in front of the body, with a separately editable lip.
panel('Mouth',[(1072,237,-.745),(1093,239,-.884),(1114,237,-.755),
 (1119,252,-.69),(1106,251,-.82),(1093,247,-.861),
 (1080,251,-.82),(1067,252,-.69)],(1093,244,-.865),black,.013)
loft('LowerJaw',[(1093,266,13,-.705,.04),(1093,261,23,-.767,.06),
 (1093,253,26,-.813,.045),(1093,250,16,-.83,.04)],10,silver)

bpy.context.view_layer.update()
for label,px in [('Left',1050),('Right',1132)]:
    hit,p,_,_=body.ray_cast(xyz(px,182,-3),Vector((0,1,0)))
    if not hit:raise RuntimeError('Eye projection missed')
    p.y-=.015
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=p)
    o=bpy.context.object;o.name='GEO-Fish_Eye_'+label;o.scale=(.025,.019,.032)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);move(o);o.data.materials.append(black)
    for f in o.data.polygons:f.use_smooth=True

# One closed forked caudal fin with shared ridge vertices across both lobes.
outline=[(1094,480),(1108,496),(1138,536),(1164,560),(1185,578),
 (1144,575),(1112,562),(1094,542),(1075,562),(1040,575),
 (1002,578),(1032,557),(1053,537),(1080,496)]
points=outline+[(1069,547),(1119,547),(1094,522)]
vs=[]
for back in [False,True]:
    for i,(x,y) in enumerate(points):
        depth=.09-(y-480)*.0017
        if i>=14:depth-=.058
        if back:depth+=.085*(1-(y-480)/160)+(.08 if i>=14 else 0)
        vs.append(tuple(xyz(x,y,depth)))
frontfaces=[(0,1,16),(1,2,15,16),(2,3,15),(3,4,5,15),(5,6,15),
 (6,7,16,15),(7,8,14,16),(8,9,14),(9,10,11,14),(11,12,14),
 (12,13,16,14),(13,0,16)]
fs=frontfaces+[tuple(17+i for i in reversed(f)) for f in frontfaces]
for k in range(14):q=(k+1)%14;fs.append((k,q,17+q,17+k))
tail=mesh('CaudalFin',vs,fs,coat)
