"""Build the selected lanky cat in Blender. No external Python packages required.
blender --background --python models/cat/build_cat.py [-- draft]
Front dimensions are measured from selected-concepts/cat.png, in image pixels.
"""
import bpy, bmesh, math, json, sys, random
from mathutils import Vector
from pathlib import Path

OUT=Path(__file__).resolve().parent
REF=OUT.parent.parent/'selected-concepts'/'cat.png'
DRAFT='draft' in sys.argv
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene; scene.unit_settings.system='METRIC'
def collection(name):
    c=bpy.data.collections.new(name);scene.collection.children.link(c);return c
asset=collection('CAT | character geometry')
studio=collection('STUDIO | cameras and lighting')
refs=collection('REFERENCE | selected concept')
def move(o,c=asset):
    for old in list(o.users_collection):old.objects.unlink(o)
    c.objects.link(o)
def mat(name,rgb,roughness=.72):
    m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True
    p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Roughness'].default_value=roughness;p.inputs['Metallic'].default_value=0
    p.inputs['Specular IOR Level'].default_value=.22
    return m
orange=mat('MAT-Cat | orange coat',(.73,.17,.006))
cream=mat('MAT-Cat | warm cream',(.78,.59,.31))
black=mat('MAT-Cat | bead eyes and smile',(.004,.006,.005),.38)
ground=mat('MAT-Studio | warm grey',(.62,.60,.575),.9)
def xyz(px,py,depth):return Vector(((px-1102)/200,depth,(555-py)/200))
def mesh(name,vs,fs,material=orange):
    me=bpy.data.meshes.new(name+'-Mesh');me.from_pydata(vs,[],fs);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    o=bpy.data.objects.new('GEO-Cat_'+name,me);asset.objects.link(o);me.materials.append(material)
    o['reference']='selected-concepts/cat.png';return o

def loft(name,rings,n=12,material=orange):
    # rings: image center x/y, half-width in pixels, Y center, half-depth in metres
    vs=[];fs=[]
    for j,(px,py,w,y,d) in enumerate(rings):
        for k in range(n):
            a=2*math.pi*k/n
            vs.append(tuple(xyz(px+w*math.cos(a),py,y+d*math.sin(a))))
    for j in range(len(rings)-1):
        for k in range(n):
            a=j*n+k;b=j*n+(k+1)%n;c=(j+1)*n+(k+1)%n;d=(j+1)*n+k
            fs.append((a,b,c,d))
    fs.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+k for k in range(n))])
    return mesh(name,vs,fs,material)

def tube(name,points,radii,material=orange,n=8,depth_ratio=1.0):
    # Cross-section width lies in image X/Z plane, so traced limb widths remain locked.
    ps=[xyz(*p) for p in points];vs=[];fs=[]
    for j,p in enumerate(ps):
        t=(ps[min(j+1,len(ps)-1)]-ps[max(j-1,0)]).normalized()
        u=Vector((t.z,0,-t.x)).normalized();v=t.cross(u).normalized()
        for k in range(n):
            a=2*math.pi*k/n
            vs.append(tuple(p+radii[j]/200*(math.cos(a)*u+math.sin(a)*v*depth_ratio)))
    for j in range(len(ps)-1):
        for k in range(n):fs.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
    fs.extend([tuple(reversed(range(n))),tuple((len(ps)-1)*n+k for k in range(n))])
    return mesh(name,vs,fs,material)

# Continuous tapered torso: a narrow pelvis, tucked belly, and forward shoulders.
body=loft('Torso',[
 (1103,327,9,.13,.07),(1103,314,25,.13,.135),(1102,290,37,.12,.16),
 (1102,266,35,.085,.165),(1102,246,38,.02,.18),(1102,223,45,-.055,.21),
 (1102,200,53,-.105,.205),(1102,185,55,-.13,.18),
 (1102,173,41,-.16,.15),(1102,163,26,-.19,.115)],12)
# Neck tucked well inside both shoulder and skull, visible mainly in side view.
loft('Neck',[(1102,188,33,-.205,.15),(1102,166,35,-.31,.16),(1102,142,27,-.36,.13)],10)
# The skull uses a purpose-built front patch: forehead planes converge towards
# the tiny eyes, while broad cheek triangles taper into the snout.
rows=[[(1078,93,-.33),(1094,90,-.35),(1110,90,-.35),(1126,93,-.33)],
 [(1037,108,-.35),(1078,108,-.50),(1126,108,-.50),(1167,108,-.35)],
 [(1040,138,-.40),(1088,145,-.65),(1116,145,-.65),(1164,138,-.40)],
 [(1049,171,-.42),(1089,170,-.68),(1113,170,-.68),(1155,171,-.42)],
 [(1064,186,-.40),(1087,193,-.54),(1115,193,-.54),(1138,186,-.40)]]
vs=[tuple(xyz(*p)) for row in rows for p in row];fs=[]
for j in range(4):
    for k in range(3):
        a=j*4+k;b=a+1;c=a+5;d=a+4
        fs.extend([(a,b,c),(a,c,d)] if k!=1 else [(a,b,c,d)])
outline=[0,1,2,3,7,11,15,19,18,17,16,12,8,4]
back=[]
for i in outline:
    v=Vector(vs[i]);v.y=-.16;back.append(len(vs));vs.append(tuple(v))
for j,i in enumerate(outline):fs.append((i,outline[(j+1)%len(outline)],back[(j+1)%len(back)],back[j]))
center=len(vs);vs.append(tuple(xyz(1102,140,-.11)))
for j in range(len(back)):fs.append((back[j],back[(j+1)%len(back)],center))
head=mesh('Head',vs,fs)

# Ears are closed angular wedges; cream interiors are shallow inset closed panels.
def ear(side):
    s=side;label='Left' if s<0 else 'Right'
    def p(x,y,d):return tuple(xyz(1102+s*x,y,d))
    vs=[p(14,94,-.43),p(63,131,-.46),p(69,112,-.44),p(68,49,-.40),
        p(14,95,-.25),p(63,132,-.29),p(69,112,-.34),p(68,49,-.39),p(45,108,-.32)]
    fs=[(0,1,2,3),(0,3,7,4),(3,2,6,7),(2,1,5,6),(1,0,4,5),(4,7,8),(7,6,8),(6,5,8),(5,4,8)]
    mesh('Ear_'+label,vs,fs)
    # Uneven triangular bowl facets reflect the reference's folded inner-ear planes.
    vs=[p(25,105,-.502),p(60,124,-.475),p(65,111,-.457),p(65,56,-.416),p(48,106,-.473)]
    fs=[(0,1,4),(1,2,4),(2,3,4),(3,0,4)]
    o=mesh('InnerEar_'+label,vs,fs,cream)
    sol=o.modifiers.new('Inset thickness','SOLIDIFY');sol.thickness=.003
    bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.modifier_apply(modifier=sol.name);o.select_set(False)
ear(-1);ear(1)

# Project muzzle volume forward into a small, flattened angular snout.
muzzle=loft('Muzzle',[(1101,199,12,-.60,.040),(1101,194,23,-.67,.075),
 (1101,183,30,-.70,.095),(1101,171,29,-.70,.09),(1101,162,19,-.67,.070),
 (1101,158,5,-.65,.028)],10,cream)
bpy.context.view_layer.update()
def rayfront(o,px,py):
    origin=xyz(px,py,-3);hit,p,_,_=o.ray_cast(origin,Vector((0,1,0)))
    if not hit:raise RuntimeError('Projection missed '+o.name+str((px,py)))
    return p
for label,px in [('Left',1092),('Right',1106)]:
    p=rayfront(head,px,152);p.y-=.010
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,location=p,radius=1)
    o=bpy.context.object;o.name='GEO-Cat_Eye_'+label;o.scale=(.0205,.015,.022)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);move(o);o.data.materials.append(black)
    for f in o.data.polygons:f.use_smooth=True
mouthpts=[]
for px,py in [(1081,184.7),(1085,186.7),(1093,187.5),(1101,187),(1109,187.2),(1117,185.8),(1121,183.5)]:
    p=rayfront(muzzle,px,py);mouthpts.append((px,py,p.y-.003))
tube('Mouth',mouthpts,[1.0]*len(mouthpts),black,8,.65)

# Bilateral long arms and legs; hands remain open enough to read as equipment grips.
for s,label in [(-1,'Left'),(1,'Right')]:
    def pp(x,y,d):return (1102+s*x+(1 if s<0 else 4),y,d)
    tube('Arm_'+label,[pp(51,192,-.10),pp(59,209,-.07),pp(80,279,-.015),
        pp(84,301,-.04),pp(94,359,-.21),pp(101,395,-.34),pp(103,410,-.36)],
        [11.5,11,10.4,10.1,11.8,12.5,12],depth_ratio=.9)
    shift=1 if s<0 else 4
    loft('Palm_'+label,[(1102+s*102+shift,389,11,-.33,.045),(1102+s*106+shift,409,17,-.365,.049),
        (1102+s*108+shift,428,18,-.395,.045),(1102+s*108+shift,438,13,-.415,.039)],8)
    # Three separate bent fingers, spreading in depth as well as across the palm.
    for k,(off,dep) in enumerate([(-8,-.023),(1,-.008),(10,.018)]):
        x=108+off
        tube('Finger_'+label+'_'+str(k+1),[pp(x,432,-.395+dep),pp(x+1,450,-.445+dep),
            pp(x-6,453+k*6,-.48+dep),pp(x-18,456+k*9,-.458+dep)],
            [5.2,5.5,5.1,4.0],cream,6,.9)
    tube('Thumb_'+label,[pp(91,414,-.379),pp(81,423,-.41),pp(75,438,-.43),pp(74,447,-.45)],
        [7,7,6.5,4.5],cream,7,.85)
    legx=[1079,1075,1064,1061,1062,1061,1062] if s<0 else [1125,1129,1144,1146,1148,1149,1149]
    tube('Leg_'+label,[(x,y,d) for x,(y,d) in zip(legx,[(307,.12),(328,.10),(395,-.16),(414,-.18),(459,-.04),(495,.065),(514,.075)])],
        [15,16,12.7,12.4,12,14,13],depth_ratio=.95)
    # Broad low foot, closed contour with a flatter sole and tapered instep.
    x=1061 if s<0 else 1149
    loft('Foot_'+label,[(x+s*13,551,29,-.085,.15),(x+s*11,542,31,-.075,.19),
        (x,526,20,-.008,.14),(x,509,12,.065,.079),(x,501,9,.07,.055)],8)
    for k,off in enumerate([-19,0,19]):
        tx=x+s*(off+(18 if s<0 else 11))
        loft('Toe_'+label+'_'+str(k+1),[(tx,554,7,-.237,.049),(tx,550,9,-.25,.065),
            (tx,538,9.1,-.236,.061),(tx,534,6,-.215,.035)],6,cream)

# One continuous angular question-mark tail, carrying its curl both sideways and behind.
tube('Tail',[(1114,315,.22),(1135,361,.43),(1158,382,.65),(1180,391,.79),(1204,385,.86),
 (1236,361,.97),(1234,286,.95),(1267,254,1.20),(1284,233,1.34),(1295,211,1.46),
 (1285,163,1.40),(1237,142,.98),(1203,171,.70),(1198,204,.66)],
 [9,9,10,10,10,9,9.8,10.3,11.5,11.5,12,11.5,9.5,8],n=8)

# Break the regular lathed bands into controlled planar facets. Silhouette extrema
# stay fixed; interior vertices gain slight irregularity, as in the selected artwork.
random.seed(43)
for o in [body,bpy.data.objects['GEO-Cat_Neck'],muzzle]:
    for v in o.data.vertices:
        if abs(v.co.x)<.23 and o!=muzzle:
            v.co.z+=random.uniform(-.012,.012)
    bm=bmesh.new();bm.from_mesh(o.data)
    faces=[f for f in bm.faces if len(f.verts)==4 and random.random()<.65]
    bmesh.ops.triangulate(bm,faces=faces,quad_method='BEAUTY')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
for v in body.data.vertices:
    v.co.x=1.025*v.co.x+.010

# Reference packed into the project for continued modeling.
im=bpy.data.images.load(str(REF));im.pack()
r=bpy.data.objects.new('REF-Selected_cat_sheet',None);refs.objects.link(r)
r.empty_display_type='IMAGE';r.data=im;r.empty_display_size=3.4;r.location=(3,1,1.4)
r.rotation_euler=(math.pi/2,0,0);r.hide_render=True;r.hide_set(True)

bpy.ops.mesh.primitive_plane_add(size=200)
floor=bpy.context.object;floor.name='STUDIO-Ground';floor.data.materials.append(ground);move(floor,studio)
world=bpy.data.worlds.new('WORLD-Soft_studio');world.use_nodes=True;scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.8,.8,.8,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.5
def aim(o,t):o.rotation_euler=(Vector(t)-o.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,power,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);studio.objects.link(o);o.location=loc;aim(o,(0,0,1.3))
area('LIGHT-Key',(-3,-4,6),220,4)
area('LIGHT-Fill',(3,-2,4),100,3)
area('LIGHT-Rim',(1,4,5),220,3)
def cam(name,loc,target,scale):
    d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=scale
    o=bpy.data.objects.new(name,d);studio.objects.link(o);o.location=loc;aim(o,target);return o
cams={
 'hero':cam('CAM-Hero',(4,-7,3.1),(.40,.20,1.31),3.20),
 'front':cam('CAM-Front',(.1775,-7,1.275),(.1775,0,1.275),2.70),
 'side':cam('CAM-Side',(7,.45,2.4),(0,.45,1.3),3.1),
 'back':cam('CAM-Back',(.15,7,1.7),(.15,0,1.28),3.1),
 'top':cam('CAM-Top',(0,0,7),(0,0,0),3.1)}
scene.render.engine='CYCLES';scene.cycles.samples=24 if DRAFT else 48
scene.cycles.use_denoising=True;scene.cycles.max_bounces=6
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=70 if DRAFT else 100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.camera=cams['hero']
for o in studio.objects:
    if o.type!='CAMERA':o.hide_set(True)
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_distance=4.6;a.spaces.active.region_3d.view_location=(.1,0,1.3)
            a.spaces.active.region_3d.view_rotation=cams['hero'].rotation_euler.to_quaternion()
            a.spaces.active.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
stats={}
for o in asset.objects:
    bm=bmesh.new();bm.from_mesh(o.data)
    stats[o.name]={'vertices':len(bm.verts),'triangles':sum(len(f.verts)-2 for f in bm.faces),
        'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'degenerate_faces':sum(f.calc_area()<1e-10 for f in bm.faces)}
    bm.free()
(OUT/'mesh_validation.json').write_text(json.dumps(stats,indent=2))
groups={'torso':['Torso','Neck'],'head':['Head'],'left ear':['Ear_Left'],'right ear':['Ear_Right'],
 'left arm and hand':['Arm_Left','Palm_Left','Thumb_Left']+['Finger_Left_'+str(i) for i in range(1,4)],
 'right arm and hand':['Arm_Right','Palm_Right','Thumb_Right']+['Finger_Right_'+str(i) for i in range(1,4)],
 'left leg and foot':['Leg_Left','Foot_Left']+['Toe_Left_'+str(i) for i in range(1,4)],
 'right leg and foot':['Leg_Right','Foot_Right']+['Toe_Right_'+str(i) for i in range(1,4)],
 'tail':['Tail'],'muzzle':['Muzzle']}
present={key:all('GEO-Cat_'+n in stats for n in names) for key,names in groups.items()}
audit={'primary_groups':present,'primary_count':sum(present.values()),
 'eye_count':len([n for n in stats if n.startswith('GEO-Cat_Eye_')]),
 'mesh_count':len(stats),'triangle_count':sum(s['triangles'] for s in stats.values()),
 'geometry_pass':all(s['non_manifold_edges']==0 and s['degenerate_faces']==0 for s in stats.values())}
(OUT/'scene_validation.json').write_text(json.dumps(audit,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cat.blend'))
for name in (['hero','front','side'] if DRAFT else list(cams)):
    scene.camera=cams[name];scene.render.filepath=str(OUT/f'{name}_preview.png');bpy.ops.render.render(write_still=True)
scene.camera=cams['front'];floor.hide_render=True;scene.render.film_transparent=True
scene.render.resolution_x=730;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
scene.render.filepath=str(OUT/'front_mask.png');bpy.ops.render.render(write_still=True)
print('BUILD_COMPLETE',sum(s['triangles'] for s in stats.values()),'triangles')
