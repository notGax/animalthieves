"""Reproducible Blender build. Run blender --background --python build_slime.py."""
import bpy, bmesh, math, random, json
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
REF = OUT.parent.parent / 'selected-concepts' / 'slime.png'
random.seed(19)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
asset = bpy.data.collections.new('SLIME | export geometry')
scene.collection.children.link(asset)
studio = bpy.data.collections.new('STUDIO | preview only')
scene.collection.children.link(studio)
refs = bpy.data.collections.new('REFERENCE | finalized concept')
scene.collection.children.link(refs)

def move(obj, collection):
    for c in list(obj.users_collection): c.objects.unlink(obj)
    collection.objects.link(obj)

def material(name, color, roughness):
    m = bpy.data.materials.new(name); m.use_nodes = True
    m.diffuse_color = (*color, 1)
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = 0
    return m

blue = material('MAT-Slime | change Base Color for player color', (0.001, 0.40, 0.85), .33)
blue.node_tree.nodes['Principled BSDF'].inputs['Specular IOR Level'].default_value=.25
black = material('MAT-Face | charcoal', (.003, .006, .007), .55)
black.node_tree.nodes['Principled BSDF'].inputs['Specular IOR Level'].default_value=.05
ground = material('MAT-Studio | warm grey', (.65,.63,.61), .85)

# Staggered contour rings: a rounded foot, spreading shoulders, and a low crown.
# A single connected shell, with flat shading and intentionally irregular triangles.
N = 28
profile = [(0.015,.70),(.045,.89),(.115,.98),(.235,1.0),(.405,.90),(.595,.77),(.765,.60),(.90,.38),(.945,.16)]
verts=[]
for j,(z,r) in enumerate(profile):
    for i in range(N):
        a = 2*math.pi*(i + .40*(j%2) + random.uniform(-.18,.18))/N
        wiggle = 1 + .017*math.sin(3*a+.8)+.008*math.cos(5*a)
        dz = random.uniform(-.023,.023) if 2 < j < 8 else 0
        verts.append((.9*r*math.cos(a)*wiggle-.022*(z/.96)**2,
                      .70*r*math.sin(a)*wiggle+.025*(z/.96)**2,
                      z+dz))
faces=[]
for j in range(len(profile)-1):
    for i in range(N):
        a=j*N+i; b=j*N+(i+1)%N; c=(j+1)*N+(i+1)%N; d=(j+1)*N+i
        if (i+j)%2: faces.extend([(a,b,d),(b,c,d)])
        else: faces.extend([(a,b,c),(a,c,d)])
bottom=len(verts); verts.append((0,0,.015))
top=len(verts); verts.append((-.025,.025,.961))
for i in range(N):
    faces.append((bottom,(i+1)%N,i))
    faces.append(((len(profile)-1)*N+i,(len(profile)-1)*N+(i+1)%N,top))
mesh=bpy.data.meshes.new('SlimeBody-faceted-topology')
mesh.from_pydata(verts,[],faces); mesh.update()
body=bpy.data.objects.new('GEO-Slime_Body',mesh); asset.objects.link(body)
body.data.materials.append(blue)
bm=bmesh.new(); bm.from_mesh(mesh); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(mesh); bm.free()
bpy.context.view_layer.update()

def front(x,z):
    hit,loc,n,idx=body.ray_cast(Vector((x,-3,z)),Vector((0,1,0)))
    if not hit: raise RuntimeError(f'Face projection missed body: {x}, {z}')
    return loc

for name,x in [('Left',-.20),('Right',.20)]:
    pos=front(x,.515); pos.y-=.006
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=pos)
    obj=bpy.context.object; obj.name='GEO-Slime_Eye_'+name
    obj.scale=(.033,.017,.034)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(black)
    for p in obj.data.polygons:p.use_smooth=True
    move(obj,asset)

# A flattened capsule ribbon follows the actual triangulated face surface.
vs=[]; fs=[]; steps=48
for i in range(steps+1):
    t=i/steps; x=-.485+1.10*t
    z=.300+.008*(2*t-1)**2
    for k in range(8):
        a=2*math.pi*k/8
        zz=z+.021*math.cos(a)
        pos=front(x,zz); pos.y-=.006+.006*math.sin(a)
        vs.append(tuple(pos))
for i in range(steps):
    for k in range(8): fs.append((i*8+k,i*8+(k+1)%8,(i+1)*8+(k+1)%8,(i+1)*8+k))
fs.extend([tuple(reversed(range(8))),tuple(steps*8+k for k in range(8))])
m=bpy.data.meshes.new('Mouth-surface-ribbon');m.from_pydata(vs,[],fs);m.update()
mouth=bpy.data.objects.new('GEO-Slime_Mouth',m);asset.objects.link(mouth);m.materials.append(black)
for p in m.polygons:p.use_smooth=True
# Rounded end caps joined into the editable mouth object.
for x in [-.485,.615]:
    p=front(x,.308);p.y-=.006
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=p)
    o=bpy.context.object;o.scale=(.021,.008,.021);o.data.materials.append(black)
    for poly in o.data.polygons:poly.use_smooth=True
    move(o,asset)
bpy.ops.object.select_all(action='DESELECT')
mouth.select_set(True)
for o in list(asset.objects):
    if o.name.startswith('Sphere'):o.select_set(True)
bpy.context.view_layer.objects.active=mouth;bpy.ops.object.join()

for obj in asset.objects:
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    obj['source_reference']='selected-concepts/slime.png'
body['design']='Limbless low faceted mound. Exactly two tiny dark bead eyes.'

img=bpy.data.images.load(str(REF));img.pack()
ref=bpy.data.objects.new('REF-Finalized_slime_sheet',None);refs.objects.link(ref)
ref.empty_display_type='IMAGE';ref.data=img;ref.empty_display_size=2.5
ref.location=(3,1,1.2);ref.rotation_euler=(math.pi/2,0,0);ref.hide_render=True
ref.hide_set(True)

bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,0))
floor=bpy.context.object;floor.name='STUDIO-Ground';floor.data.materials.append(ground);move(floor,studio)
world=bpy.data.worlds.new('WORLD-Soft_studio');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.8,.8,.8,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.65

def aim(obj,target):obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,power,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    o=bpy.data.objects.new(name,data);studio.objects.link(o);o.location=loc;aim(o,(0,0,.4))
area('LIGHT-Key',( -3,-4,6),180,4)
area('LIGHT-Highlight',(3,-1,4),80,2)
area('LIGHT-Fill',(0,3,4),70,4)

scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1000;scene.render.resolution_y=760;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.view_settings.exposure=0
def cam(name,loc,target,scale):
    data=bpy.data.cameras.new(name);data.type='ORTHO';data.ortho_scale=scale
    o=bpy.data.objects.new(name,data);studio.objects.link(o);o.location=loc;aim(o,target);return o
cameras={
 'front':cam('CAM-Front',(0,-6,1.05),(0,0,.46),2.35),
 'hero':cam('CAM-Hero',(1.8,-6,1.7),(0,0,.44),2.4),
 'side':cam('CAM-Side',(6,0,.95),(0,0,.45),2.35),
 'back':cam('CAM-Back',(0,6,1.05),(0,0,.46),2.35),
 'top':cam('CAM-Top',(0,0,6),(0,0,0),2.35)}
scene.camera=cameras['hero']
# Opening the file shows the asset in material view, with the studio hidden only in viewport.
for o in studio.objects:
    if o.type!='CAMERA':o.hide_set(True)
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_distance=3.2
            a.spaces.active.region_3d.view_location=(0,0,.45)
            a.spaces.active.region_3d.view_rotation=cameras['hero'].rotation_euler.to_quaternion()
            a.spaces.active.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'slime.blend'))
stats={}
for o in asset.objects:
    bm=bmesh.new();bm.from_mesh(o.data)
    stats[o.name]={'vertices':len(bm.verts),'triangles':sum(len(f.verts)-2 for f in bm.faces),'non_manifold_edges':sum(not e.is_manifold for e in bm.edges)}
    bm.free()
(OUT/'mesh_validation.json').write_text(json.dumps(stats,indent=2))
for name,camera in cameras.items():
    scene.camera=camera;scene.render.filepath=str(OUT/f'{name}_preview.png');bpy.ops.render.render(write_still=True)
scene.camera=cameras['front'];floor.hide_render=True;scene.render.film_transparent=True
scene.render.filepath=str(OUT/'front_mask.png');bpy.ops.render.render(write_still=True)
print('BUILD_COMPLETE',json.dumps(stats))
