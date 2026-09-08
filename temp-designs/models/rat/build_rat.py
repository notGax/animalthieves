"""Build the selected lanky rat in Blender. No external Python packages required.
blender --background --python models/rat/build_rat.py [-- draft]
Front dimensions are measured from selected-concepts/rat.png, in image pixels.
"""
import bpy, bmesh, math, json, sys, random
from mathutils import Vector
from pathlib import Path

OUT=Path(__file__).resolve().parent
REF=OUT.parent.parent/'selected-concepts'/'rat.png'
DRAFT='draft' in sys.argv
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene; scene.unit_settings.system='METRIC'
def collection(name):
    c=bpy.data.collections.new(name);scene.collection.children.link(c);return c
asset=collection('RAT | character geometry')
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
coat=mat('MAT-Rat | charcoal coat',(.165,.158,.15))
cream=mat('MAT-Rat | coral skin',(.72,.12,.115))
black=mat('MAT-Rat | bead eyes and smile',(.004,.006,.005),.38)
ivory=mat('MAT-Rat | incisors',(.78,.75,.60))
ground=mat('MAT-Studio | warm grey',(.62,.60,.575),.9)
def xyz(px,py,depth):return Vector(((px-1100)/200,depth,(537-py)/200))
def mesh(name,vs,fs,material=coat):
    me=bpy.data.meshes.new(name+'-Mesh');me.from_pydata(vs,[],fs);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    o=bpy.data.objects.new('GEO-Rat_'+name,me);asset.objects.link(o);me.materials.append(material)
    o['reference']='selected-concepts/rat.png';return o

def loft(name,rings,n=12,material=coat):
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

def tube(name,points,radii,material=coat,n=8,depth_ratio=1.0):
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


exec(compile((OUT/'geometry.py').read_text(),str(OUT/'geometry.py'),'exec'))

# Reference packed into the project for continued modeling.
im=bpy.data.images.load(str(REF));im.pack()
r=bpy.data.objects.new('REF-Selected_rat_sheet',None);refs.objects.link(r)
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
 'hero':cam('CAM-Hero',(4,-7,2.9),(.20,.05,1.22),3.40),
 'front':cam('CAM-Front',(.1625,-7,1.2225),(.1625,0,1.2225),2.575),
 'side':cam('CAM-Side',(7,.36,1.65),(0,.36,1.20),3.65),
 'back':cam('CAM-Back',(.15,7,1.7),(.15,0,1.28),3.1),
 'top':cam('CAM-Top',(0,.36,7),(0,.36,0),3.65)}
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
 'tail':['Tail'],'nose':['Nose']}
present={key:all('GEO-Rat_'+n in stats for n in names) for key,names in groups.items()}
audit={'primary_groups':present,'primary_count':sum(present.values()),
 'eye_count':len([n for n in stats if n.startswith('GEO-Rat_Eye_')]),
 'mesh_count':len(stats),'triangle_count':sum(s['triangles'] for s in stats.values()),
 'geometry_pass':all(s['non_manifold_edges']==0 and s['degenerate_faces']==0 for s in stats.values())}
(OUT/'scene_validation.json').write_text(json.dumps(audit,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rat.blend'))
for name in (['hero','front','side'] if DRAFT else list(cams)):
    scene.camera=cams[name];scene.render.filepath=str(OUT/f'{name}_preview.png');bpy.ops.render.render(write_still=True)
scene.camera=cams['front'];floor.hide_render=True;scene.render.film_transparent=True
scene.render.resolution_x=690;scene.render.resolution_y=1030;scene.render.resolution_percentage=100
scene.render.filepath=str(OUT/'front_mask.png');bpy.ops.render.render(write_still=True)
print('BUILD_COMPLETE',sum(s['triangles'] for s in stats.values()),'triangles')
