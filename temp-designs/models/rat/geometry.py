# Measured front contours; Y-depth interpreted from the side/hero reference.
body=loft('Torso',[(1101,380,8,.16,.06),(1101,371,23,.17,.13),
 (1101,352,43,.18,.19),(1101,337,46,.16,.20),(1100,305,36,.08,.16),
 (1100,275,38,-.005,.175),(1100,248,42,-.10,.19),
 (1100,222,46,-.18,.20),(1100,205,48,-.20,.16),(1100,195,32,-.22,.12)],12)
loft('Neck',[(1100,230,30,-.25,.15),(1100,205,32,-.33,.15),(1100,170,25,-.38,.13)],10)
# Long wedge skull; its nose points forward and slightly down.
head=loft('Head',[(1082,251,6,-1.12,.035),(1085,241,18,-1.07,.095),
 (1090,223,29,-.87,.22),(1098,198,46,-.66,.31),(1100,168,49,-.45,.31),
 (1100,144,44,-.34,.28),(1100,121,31,-.26,.21),(1101,104,9,-.24,.06)],12)

def ear(label,outline):
    cx=sum(x for x,y in outline)/len(outline);cy=sum(y for x,y in outline)/len(outline)
    n=len(outline);vs=[tuple(xyz(x,y,-.30)) for x,y in outline]
    vs+=[tuple(xyz(cx+(x-cx)*.91,cy+(y-cy)*.94,-.16)) for x,y in outline]
    vs.append(tuple(xyz(cx,cy,-.35)));front=2*n
    vs.append(tuple(xyz(cx,cy,-.10)));back=2*n+1
    fs=[]
    for k in range(n):
        q=(k+1)%n;fs.extend([(k,q,front),(k,n+k,n+q,q),(n+k,back,n+q)])
    mesh('Ear_'+label,vs,fs)
    vs=[tuple(xyz(cx+(x-cx)*.80,cy+(y-cy)*.86,-.322)) for x,y in outline]
    vs.append(tuple(xyz(cx-3,cy+3,-.365)))
    o=mesh('InnerEar_'+label,vs,[(k,(k+1)%n,n) for k in range(n)],cream)
    mod=o.modifiers.new('Ear inset thickness','SOLIDIFY');mod.thickness=.006
    bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.modifier_apply(modifier=mod.name);o.select_set(False)
ear('Left',[(1032,51),(1060,70),(1077,121),(1061,159),(1026,151),(1000,110),(1004,73)])
ear('Right',[(1174,51),(1201,72),(1205,110),(1178,151),(1138,161),(1127,129),(1145,70)])

bpy.context.view_layer.update()
def rayfront(o,px,py):
    hit,p,_,_=o.ray_cast(xyz(px,py,-3),Vector((0,1,0)))
    if not hit:raise RuntimeError('Feature missed '+o.name+str((px,py)))
    return p
for label,px in [('Left',1080),('Right',1105)]:
    p=rayfront(head,px,163);p.y-=.009
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=p)
    o=bpy.context.object;o.name='GEO-Rat_Eye_'+label;o.scale=(.018,.014,.021)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);move(o);o.data.materials.append(black)
    for f in o.data.polygons:f.use_smooth=True
nose=loft('Nose',[(1081,260,1,-1.18,.012),(1081,252,12,-1.185,.058),
 (1082,239,15,-1.18,.068),(1084,230,7,-1.16,.04)],6,cream)
# A restrained mouth along the underside of the snout, two close small incisors.
tube('Mouth',[(1070,249,-1.10),(1078,258,-1.15),(1086,258,-1.15),(1096,245,-1.07)],
 [1.2]*4,black,6,.6)
for label,x in [('Left',1077),('Right',1085)]:
    loft('Incisor_'+label,[(x,264,2.3,-1.16,.014),(x,260,3.0,-1.175,.022),
        (x,251,3.0,-1.17,.021)],4,ivory)

for s,label in [(-1,'Left'),(1,'Right')]:
    def pp(x,y,d):return (1100+s*x,y,d)
    tube('Arm_'+label,[pp(46,209,-.13),pp(55,235,-.115),pp(91,291,-.04),
        pp(95,308,-.05),pp(100,338,-.23),pp(104,360,-.35),pp(109,375,-.38)],
        [13,11,8.8,9.2,7.0,7,9],depth_ratio=1.1)
    loft('Palm_'+label,[(1100+s*104,352,6,-.33,.036),(1100+s*103,368,11,-.40,.045),
        (1100+s*107,383,12,-.445,.052),(1100+s*108,390,10,-.46,.042)],8)
    # Equipment-capable hands: three bent fingers and an opposed thumb.
    for k,(off,dep) in enumerate([(-5,-.020),(2,0),(7,.025)]):
        x=107+off
        tube('Finger_'+label+'_'+str(k+1),[pp(x,384,-.47+dep),pp(x+1,401,-.50+dep),
            pp(x-3,416+k*2,-.54+dep),pp(x-10,422+k*3,-.55+dep)],
            [4.3,4.2,4.0,3.2],cream,6,.9)
    tube('Thumb_'+label,[pp(92,372,-.445),pp(82,383,-.49),pp(79,399,-.52)],
        [5.1,5,4.3],cream,7)
    x=1058 if s<0 else 1144
    tube('Leg_'+label,[(1100+s*29,350,.16),(1100+s*33,377,.10),
        (x,425,-.18),(x,440,-.19),(x,478,-.04),(x,500,.03),(x,509,.02)],
        [17,17,11.7,10.8,7.5,8,8],depth_ratio=1.05)
    loft('Foot_'+label,[(x+s*8,529,22,-.10,.14),(x+s*6,520,20,-.085,.17),
        (x,508,9,.015,.085),(x,498,6,.03,.04)],8)
    for k,off in enumerate([-21,0,21]):
        tx=x+s*(off+23)
        loft('Toe_'+label+'_'+str(k+1),[(tx+s*3,536,8,-.305,.048),
            (tx+s*2,532,10,-.285,.087),(tx,525,8,-.23,.075),(tx,521,4,-.19,.035)],6,cream)

# A single tapering angular tail, low to the ground with the reference's hard bends.
tube('Tail',[(1108,359,.32),(1122,399,.57),(1145,435,.83),(1188,473,1.20),
 (1227,491,1.55),(1260,499,1.81),(1285,502,1.97)],
 [10,10.5,10,8.1,5.6,2.8,.28],cream,7)

random.seed(62)
for o in [body,head,bpy.data.objects['GEO-Rat_Neck']]:
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm,faces=[f for f in bm.faces if len(f.verts)==4 and random.random()<.7],quad_method='BEAUTY')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()

for v in body.data.vertices:
    v.co.x=v.co.x*1.015+.0075
