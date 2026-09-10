"""Bake IK to a compact game skeleton; export and verify animated GLB poses."""
import bpy, json, struct
from pathlib import Path
from mathutils.kdtree import KDTree
P=Path(__file__).resolve().parent/'rigged'
bpy.ops.wm.open_mainfile(filepath=str(P/'rat_rigged.blend'))
s=bpy.context.scene; rig=bpy.data.objects['RIG-Rat']
objects=list(bpy.data.collections['RAT | character geometry'].objects)
names=[b.name for b in rig.data.bones if b.use_deform or b.name=='CTRL-root']
clips={'Sneak_Walk':49,'Alert_Idle':73}
samples={}; reference={}
for name,end in clips.items():
    rig.animation_data.action=bpy.data.actions[name]
    samples[name]={}; reference[name]={}
    for f in range(1,end+1):
        s.frame_set(f)
        samples[name][f]={n:rig.pose.bones[n].matrix.copy() for n in names}
        if f in [1,13,25,37,end]:
            dg=bpy.context.evaluated_depsgraph_get()
            reference[name][f]=[o.matrix_world@v.co for o in objects for v in o.evaluated_get(dg).data.vertices]

# Bake sampled visual transforms on a copy of the source skeleton in memory.
# Saved Blender source retains editable IK controls and original actions.
rig.animation_data_clear()
for action in list(bpy.data.actions): bpy.data.actions.remove(action)
for pb in rig.pose.bones:
    for c in list(pb.constraints): pb.constraints.remove(c)
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
bpy.context.view_layer.objects.active=rig; bpy.ops.object.mode_set(mode='EDIT')
for b in list(rig.data.edit_bones):
    if b.name not in names: rig.data.edit_bones.remove(b)
bpy.ops.object.mode_set(mode='OBJECT')
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
for clip,end in clips.items():
    rig.animation_data_create(); rig.animation_data.action=None
    for f,matrices in samples[clip].items():
        # convert_local_to_pose accounts for each bone's rest matrix and parent.
        for n in names:
            pb=rig.pose.bones[n]; b=pb.bone
            kwargs={}
            if b.parent:
                kwargs={'parent_matrix':matrices[b.parent.name], 'parent_matrix_local':b.parent.matrix_local}
            pb.matrix_basis=b.convert_local_to_pose(matrices[n],b.matrix_local,invert=True,**kwargs)
            for ch in ['location','rotation_quaternion','scale']: pb.keyframe_insert(ch,frame=f,group=n)
    act=rig.animation_data.action; act.name=clip; act.use_fake_user=True

# One skinned mesh with the same four character materials.
bpy.ops.object.select_all(action='DESELECT')
for o in objects: o.hide_set(False); o.select_set(True)
bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join()
mesh=bpy.context.object; mesh.name='GEO-Rat-Skinned'
triangles=sum(len(p.vertices)-2 for p in mesh.data.polygons)
rig.select_set(True)
rig.animation_data.action=bpy.data.actions['Sneak_Walk']; s.frame_set(1)
bpy.ops.export_scene.gltf(filepath=str(P/'rat_rigged.glb'),export_format='GLB',use_selection=True,
    export_apply=False,export_animations=True,export_skins=True,export_animation_mode='ACTIONS',
    export_force_sampling=True,export_frame_range=False,export_def_bones=False,
    export_anim_slide_to_zero=True,export_yup=True,export_materials='EXPORT')
raw=(P/'rat_rigged.glb').read_bytes()
gltf=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
assert len(gltf['skins'])==1 and len(gltf['meshes'])==1 and len(gltf['animations'])==2

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(P/'rat_rigged.glb'))
s=bpy.context.scene; s.render.fps=24
armatures=[o for o in s.objects if o.type=='ARMATURE']
meshes=[o for o in s.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
assert len(armatures)==1 and len(meshes)==1
assert not any(o.type in {'CAMERA','LIGHT'} for o in s.objects)
rig=armatures[0]
if rig.animation_data:
    for t in rig.animation_data.nla_tracks: t.mute=True
report={'mesh_count':len(meshes),'bone_count':len(rig.data.bones),'triangles':triangles,
        'materials':len(meshes[0].data.materials),'clips':{},'bytes':(P/'rat_rigged.glb').stat().st_size}
for clip in clips:
    action=bpy.data.actions.get(clip)
    assert action is not None, [a.name for a in bpy.data.actions]
    rig.animation_data_create(); rig.animation_data.action=action
    if action.slots: rig.animation_data.action_slot=action.slots[0]
    worst=0
    # GLB starts each clip at t=0, which Blender imports as frame 0.
    for source_frame,points in reference[clip].items():
        s.frame_set(source_frame-1); dg=bpy.context.evaluated_depsgraph_get()
        actual=[o.matrix_world@v.co for o in meshes for v in o.evaluated_get(dg).data.vertices]
        tree=KDTree(len(points))
        for i,p in enumerate(points): tree.insert(p,i)
        tree.balance()
        worst=max(worst,max(tree.find(p)[2] for p in actual))
        reverse=KDTree(len(actual))
        for i,p in enumerate(actual): reverse.insert(p,i)
        reverse.balance()
        worst=max(worst,max(reverse.find(p)[2] for p in points))
    report['clips'][clip]={'sampled_pose_error_m':worst,'duration_seconds':(clips[clip]-1)/24}
    assert worst<.001, report
assert report['bone_count']==44 and report['materials']==4
assert sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons)==triangles
report['pass']=True
(P/'export_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
