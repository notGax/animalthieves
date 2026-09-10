"""Create the editable rat rig and original animation clips from rat.blend.
Run with Blender --background --python models/rat/rig_rat.py.
The static source remains intact. No downloads or third-party animation assets.
"""
import bpy, bmesh, math, json
from pathlib import Path
from mathutils import Vector, Quaternion

P = Path(__file__).resolve().parent
OUT = P / 'rigged'
OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(P / 'rat.blend'))
scene = bpy.context.scene
asset = bpy.data.collections['RAT | character geometry']
objects = list(asset.objects)
def xyz(px, py, y): return Vector(((px-1100)/200, y, (537-py)/200))
def part(n): return bpy.data.objects['GEO-Rat_'+n]
def smooth(t):
    t = max(0., min(1., t))
    return t*t*(3-2*t)

# Add interpolated cross-sections to the limbs: shape is unchanged at rest.
# The original 8-sided tubes have 7 rings; four intervals surround each joint.
support = {}
for label in ['Left', 'Right']:
    for kind in ['Arm', 'Leg']:
        obj = part(kind+'_'+label)
        old = [v.co.copy() for v in obj.data.vertices]
        rings = [old[i:i+8] for i in range(0, len(old), 8)]
        new = []
        for i in range(len(rings)-1):
            new.append(rings[i])
            for t in ([.33, .67] if i in [1, 2, 3, 4] else [.5]):
                new.append([a.lerp(b, t) for a,b in zip(rings[i], rings[i+1])])
        new.append(rings[-1])
        vs = [tuple(v) for r in new for v in r]
        fs = [(j*8+k, j*8+(k+1)%8, (j+1)*8+(k+1)%8, (j+1)*8+k)
              for j in range(len(new)-1) for k in range(8)]
        fs += [tuple(reversed(range(8))), tuple((len(new)-1)*8+k for k in range(8))]
        materials = list(obj.data.materials)
        me = bpy.data.meshes.new(obj.name+'-DeformationTopology')
        me.from_pydata(vs, [], fs); me.update()
        for m in materials: me.materials.append(m)
        obj.data = me
        bm=bmesh.new(); bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.to_mesh(me); bm.free()
        support[obj.name] = {'old_vertices':len(old), 'new_vertices':len(vs)}

rigcol = bpy.data.collections.new('RIG | Rat controls')
scene.collection.children.link(rigcol)
ad = bpy.data.armatures.new('Rat-Skeleton')
rig = bpy.data.objects.new('RIG-Rat', ad); rigcol.objects.link(rig)
rig.show_in_front = True; ad.display_type = 'OCTAHEDRAL'
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
spec = {}
def bone(name, head, tail, parent=None, deform=True):
    b=ad.edit_bones.new(name); b.head=head; b.tail=tail
    if parent: b.parent=ad.edit_bones[parent]
    b.use_deform=deform
    # Deterministic roll also gives useful local axes for animation controls.
    b.align_roll(Vector((0, 1, 0)))
    spec[name]={'head':list(head), 'tail':list(tail), 'parent':parent, 'deform':deform}
    return b
bone('CTRL-root',(0,0,0),(0,0,.3),deform=False)
bone('pelvis',(0,.16,.90),(0,.10,1.13),'CTRL-root')
bone('spine',(0,.10,1.13),(0,-.07,1.40),'pelvis')
bone('chest',(0,-.07,1.40),(0,-.22,1.65),'spine')
bone('neck',(0,-.22,1.65),(0,-.38,1.80),'chest')
bone('head',(0,-.38,1.80),(0,-.69,2.02),'neck')
for s,label,suf in [(-1,'Left','L'),(1,'Right','R')]:
    def pp(x,y,d): return xyz(1100+s*x,y,d)
    shoulder=pp(46,209,-.13); elbow=pp(93,301,-.045); wrist=pp(104,360,-.35)
    bone('upper_arm.'+suf,shoulder,elbow,'chest')
    bone('forearm.'+suf,elbow,wrist,'upper_arm.'+suf)
    bone('hand.'+suf,wrist,pp(108,390,-.46),'forearm.'+suf)
    bone('CTRL-hand.'+suf,wrist,pp(108,390,-.46),'CTRL-root',False)
    bone('CTRL-elbow.'+suf,elbow+Vector((s*.35,.5,0)),elbow+Vector((s*.35,.5,.15)),'CTRL-root',False)
    x=1058 if s<0 else 1144
    hip=pp(29,350,.16); knee=xyz(x,433,-.19); ankle=xyz(x,503,.025)
    bone('thigh.'+suf,hip,knee,'pelvis')
    bone('shin.'+suf,knee,ankle,'thigh.'+suf)
    bone('foot.'+suf,ankle,xyz(x+s*6,526,-.22),'shin.'+suf)
    bone('toes.'+suf,xyz(x+s*6,526,-.22),xyz(x+s*6,536,-.35),'foot.'+suf)
    bone('CTRL-foot.'+suf,ankle,xyz(x+s*6,526,-.22),'CTRL-root',False)
    bone('CTRL-knee.'+suf,knee+Vector((0,-.7,0)),knee+Vector((0,-.7,.15)),'CTRL-root',False)
    for k,(off,dep) in enumerate([(-5,-.020),(2,0),(7,.025)],1):
        x=107+off
        bone(f'finger{k}_01.{suf}',pp(x,384,-.47+dep),pp(x+1,402,-.50+dep),'hand.'+suf)
        bone(f'finger{k}_02.{suf}',pp(x+1,402,-.50+dep),pp(x-10,422+(k-1)*3,-.55+dep),f'finger{k}_01.{suf}')
    bone('thumb01.'+suf,pp(92,372,-.445),pp(82,383,-.49),'hand.'+suf)
    bone('thumb02.'+suf,pp(82,383,-.49),pp(79,399,-.52),'thumb01.'+suf)
    bone('ear.'+suf,pp(35,142,-.23),pp(65,72,-.23),'head')
tail=[xyz(*p) for p in [(1108,359,.32),(1122,399,.57),(1145,435,.83),
     (1188,473,1.20),(1227,491,1.55),(1260,499,1.81),(1285,502,1.97)]]
for i in range(6): bone(f'tail{i+1:02}',tail[i],tail[i+1],'pelvis' if i==0 else f'tail{i:02}')
bpy.ops.object.mode_set(mode='OBJECT')
controls=ad.collections.new('Controls - move hands and feet')
deform=ad.collections.new('Deform - spine fingers ears tail')
for b in ad.bones:
    (deform if b.use_deform else controls).assign(b)
    b.color.palette='THEME04' if not b.use_deform else 'THEME03'
    rig.pose.bones[b.name].rotation_mode='QUATERNION'

# IK poles are calibrated to reproduce the measured rest bend, not guessed rolls.
for suf in ['L','R']:
    for lower,ctrl,pole in [('shin','foot','knee'),('forearm','hand','elbow')]:
        pb=rig.pose.bones[lower+'.'+suf]
        con=pb.constraints.new('IK'); con.name='Two bone '+lower+' IK'
        con.target=rig; con.subtarget='CTRL-'+ctrl+'.'+suf
        con.pole_target=rig; con.pole_subtarget='CTRL-'+pole+'.'+suf
        con.chain_count=2; con.use_stretch=False
        upper=pb.parent; rest=Vector(spec[lower+'.'+suf]['head'])
        best=(1e9,0)
        for j in range(360):
            con.pole_angle=math.radians(j-180)
            bpy.context.view_layer.update()
            err=(pb.head-rest).length
            if err<best[0]: best=(err,con.pole_angle)
        con.pole_angle=best[1]
        for name in [lower+'.'+suf,upper.name]: rig.pose.bones[name].ik_stretch=0
        end=rig.pose.bones[ctrl+'.'+suf]
        cr=end.constraints.new('COPY_ROTATION'); cr.name='Follow '+ctrl+' control'
        cr.target=rig; cr.subtarget='CTRL-'+ctrl+'.'+suf
        cr.target_space='WORLD'; cr.owner_space='WORLD'
bpy.context.view_layer.update()

# Explicit anatomical weights: never let heat weights bind fingers to thighs.
def blend(a,b,t):
    t=smooth(t)
    return {a:1-t,b:t}
def segment_chain_weights(p, names, points, width=.22):
    distances=[]
    for i,(a,b) in enumerate(zip(points,points[1:])):
        v=b-a; t=max(0,min(1,(p-a).dot(v)/v.length_squared))
        distances.append(((p-(a+t*v)).length_squared,i,t))
    _,i,t=min(distances)
    if t<width and i>0: return blend(names[i-1],names[i],.5+t/(2*width))
    if t>1-width and i<len(names)-1: return blend(names[i],names[i+1],(t-(1-width))/(2*width))
    return {names[i]:1.}
for obj in objects:
    name=obj.name.removeprefix('GEO-Rat_')
    label='Left' if 'Left' in name else 'Right'; suf='L' if label=='Left' else 'R'
    for v in obj.data.vertices:
        p=obj.matrix_world@v.co; z=p.z
        if name=='Torso':
            if z<1.17: w=blend('pelvis','spine',(z-1.00)/.23)
            else: w=blend('spine','chest',(z-1.23)/.30)
        elif name=='Neck': w=blend('chest','neck',(z-1.54)/.24)
        elif name.startswith(('Ear_','InnerEar_')): w={'ear.'+suf:1}
        elif name.startswith('Arm_'):
            w=blend('forearm.'+suf,'upper_arm.'+suf,(z-1.11)/.14)
            if z<.94: w=blend('hand.'+suf,'forearm.'+suf,(z-.82)/.12)
        elif name.startswith('Palm_'): w={'hand.'+suf:1}
        elif name.startswith('Finger_'):
            k=name[-1]; w=blend(f'finger{k}_02.{suf}',f'finger{k}_01.{suf}',(z-.63)/.09)
        elif name.startswith('Thumb_'): w=blend('thumb02.'+suf,'thumb01.'+suf,(z-.74)/.07)
        elif name.startswith('Leg_'):
            w=blend('shin.'+suf,'thigh.'+suf,(z-.47)/.12)
            if z<.23: w=blend('foot.'+suf,'shin.'+suf,(z-.13)/.10)
        elif name.startswith('Foot_'): w={'foot.'+suf:1}
        elif name.startswith('Toe_'): w={'toes.'+suf:1}
        elif name=='Tail': w=segment_chain_weights(p,[f'tail{i+1:02}' for i in range(6)],tail)
        else: w={'head':1}
        for bn,weight in w.items():
            if weight<1e-7: continue
            vg=obj.vertex_groups.get(bn) or obj.vertex_groups.new(name=bn)
            vg.add([v.index],weight,'REPLACE')
    obj.parent=rig
    mod=obj.modifiers.new('Rat skeletal deformation','ARMATURE'); mod.object=rig
    mod.use_deform_preserve_volume=False

def world_offset(name,delta):
    pb=rig.pose.bones[name]
    pb.location=ad.bones[name].matrix_local.to_3x3().inverted()@Vector(delta)
def turn(name,axis,angle):
    local=ad.bones[name].matrix_local.to_3x3().inverted()@Vector(axis)
    rig.pose.bones[name].rotation_quaternion=Quaternion(local,angle)
def reset():
    for pb in rig.pose.bones: pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.scale=(1,1,1)
def key_all(f):
    for pb in rig.pose.bones:
        for channel in ['location','rotation_quaternion']: pb.keyframe_insert(channel,frame=f,group=pb.name)
actions=[]
for title,length in [('Sneak_Walk',48),('Alert_Idle',72)]:
    rig.animation_data_create(); rig.animation_data.action=None
    reset()
    for f in range(1,length+2):
        t=(f-1)/length; phase=2*math.pi*t
        reset()
        if title=='Sneak_Walk':
            world_offset('pelvis',(.022*math.sin(phase),0,-.025+.018*math.cos(2*phase)))
            turn('spine',(0,0,1),.045*math.sin(phase))
            turn('chest',(1,0,0),.035*math.cos(2*phase))
            turn('head',(0,0,1),-.055*math.sin(phase))
            for s,suf in [(1,'L'),(-1,'R')]:
                q=(t+(0 if s==1 else .5))%1
                # Linear planted half-cycle; eased lifted return half-cycle.
                if q<.5: y=-.16+.64*q; lift=0
                else:
                    u=(q-.5)*2; y=.16-.32*smooth(u); lift=.13*math.sin(math.pi*u)**2
                world_offset('CTRL-foot.'+suf,(0,y,lift))
                world_offset('CTRL-hand.'+suf,(s*.012,-.04-s*.115*math.cos(phase),.045+.025*math.sin(phase)))
                turn('ear.'+suf,(0,1,0),s*.035*math.sin(phase+.5))
        else:
            world_offset('pelvis',(0,0,.012*math.sin(phase)))
            turn('chest',(1,0,0),.018*math.sin(phase))
            turn('head',(0,0,1),.18*math.sin(phase))
            turn('neck',(1,0,0),.045*math.sin(2*phase))
            for s,suf in [(1,'L'),(-1,'R')]:
                world_offset('CTRL-hand.'+suf,(0,-.04-.025*math.sin(phase+s),.025*math.sin(phase)))
                turn('ear.'+suf,(0,1,0),s*.07*math.sin(2*phase+s))
        for i in range(6): turn(f'tail{i+1:02}',(0,0,1),(.045+i*.006)*math.sin(phase-i*.65))
        for s,suf in [(1,'L'),(-1,'R')]:
            for k in range(1,4):
                turn(f'finger{k}_01.{suf}',(1,0,0),-.10-.08*math.sin(phase+k*.3))
                turn(f'finger{k}_02.{suf}',(1,0,0),-.15-.12*math.sin(phase+k*.3))
        key_all(f)
    action=rig.animation_data.action; action.name=title; action.use_fake_user=True
    actions.append(action)
rig.animation_data.action=actions[0]
scene.frame_start=1; scene.frame_end=48; scene.render.fps=24
scene.frame_set(1)
rig['Instructions']='Pose Mode: move CTRL-foot/hand; poles steer knees/elbows. Rotate spine/head/fingers/ears/tail. CTRL-root moves all. Actions: Sneak_Walk (1-49), Alert_Idle (1-73).'
rig['Animation provenance']='Original procedural keyframe animation authored for this rat; no external motion assets.'
# Readable wire widgets for the animator's hand, foot and pole controls.
widgets=bpy.data.collections.new('WIDGETS | hidden control shapes')
scene.collection.children.link(widgets)
def widget(name,vs,edges):
    me=bpy.data.meshes.new(name); me.from_pydata(vs,edges,[]); me.update()
    obj=bpy.data.objects.new(name,me); widgets.objects.link(obj)
    obj.hide_render=True; obj.hide_set(True)
    return obj
cube=widget('WGT-ControlBox',[(x,y,z) for x in [-1,1] for y in [-1,1] for z in [-1,1]],
            [(i,j) for i in range(8) for j in range(i+1,8) if bin(i^j).count('1')==1])
ring=widget('WGT-RootRing',[(math.cos(i*2*math.pi/32),0,math.sin(i*2*math.pi/32)) for i in range(32)],
            [(i,(i+1)%32) for i in range(32)])
for pb in rig.pose.bones:
    if not pb.name.startswith('CTRL-'): continue
    pb.custom_shape=ring if pb.name=='CTRL-root' else cube
    pb.use_custom_shape_bone_size=False
    scale=(.42,.42,.42) if pb.name=='CTRL-root' else (.075,.075,.075)
    if pb.name.startswith('CTRL-foot'): scale=(.115,.14,.045)
    if pb.name.startswith(('CTRL-knee','CTRL-elbow')): scale=(.035,.035,.035)
    pb.custom_shape_scale_xyz=scale
helptext=bpy.data.texts.new('START HERE - Rat rig')
helptext.write('Press Spacebar to play Sneak_Walk (frames 1-48).\n'
    'The Action Editor also contains Alert_Idle (frames 1-72).\n'
    'Pose Mode: move CTRL-hand / CTRL-foot boxes. Small boxes steer elbows/knees.\n'
    'Rotate spine, head, ear, finger and tail bones for secondary posing.\n'
    'The ground ring moves the whole character. Duplicate actions before editing.\n'
    'Full documentation: models/rat/rigged/README.md\n')
for name,frame in [('CONTACT L',1),('PASS L',13),('CONTACT R',25),('PASS R',37)]:
    scene.timeline_markers.new(name,frame=frame)
scene.camera=bpy.data.objects['CAM-Hero']
scene.camera.location=(5,-7,3.1)
scene.camera.rotation_euler=(Vector((.1,.22,1.20))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.ortho_scale=3.7
scene.render.resolution_x=800; scene.render.resolution_y=800; scene.render.resolution_percentage=100
scene.cycles.samples=16; scene.cycles.use_denoising=True
scene.render.image_settings.color_mode='RGB'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=4.8
            area.spaces.active.region_3d.view_location=(.1,.2,1.2)
            area.spaces.active.region_3d.view_rotation=scene.camera.rotation_euler.to_quaternion()
            area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rat_rigged.blend'))
(OUT/'rig_manifest.json').write_text(json.dumps({'bones':spec,'support_rings':support,
    'actions':{'Sneak_Walk':{'frames':[1,49],'fps':24,'loop_seconds':2},
               'Alert_Idle':{'frames':[1,73],'fps':24,'loop_seconds':3}},
    'note':'Original animations. Loop endpoint repeats first pose; preview excludes endpoint. Separate closed mesh components retain overlap at shoulders/hips; not welded production retopology.'},indent=2))
print('RIG_COMPLETE',len(ad.bones),'bones',len(actions),'actions')

