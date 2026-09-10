"""Audit actual evaluated deformation, controls, weights and seamless loops."""
import bpy, json, math
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent/'rigged'
bpy.ops.wm.open_mainfile(filepath=str(P/'rat_rigged.blend'))
s=bpy.context.scene; rig=bpy.data.objects['RIG-Rat']
objs=list(bpy.data.collections['RAT | character geometry'].objects)
report={'bones':len(rig.data.bones),'deform_bones':sum(b.use_deform for b in rig.data.bones),'meshes':len(objs)}
bad=[]; max_inf=0; max_sumerr=0
for o in objs:
    for v in o.data.vertices:
        weights=[g.weight for g in v.groups if rig.data.bones[o.vertex_groups[g.group].name].use_deform]
        max_inf=max(max_inf,len(weights)); max_sumerr=max(max_sumerr,abs(sum(weights)-1))
        if not weights or abs(sum(weights)-1)>1e-5: bad.append([o.name,v.index])
report.update(unweighted_or_bad_vertices=bad,max_influences=max_inf,max_weight_sum_error=max_sumerr)
assert not bad and max_inf<=4
def evaluated():
    dg=bpy.context.evaluated_depsgraph_get()
    return {o.name:[o.matrix_world@v.co for v in o.evaluated_get(dg).data.vertices] for o in objs}
rig.animation_data.action=None
for pb in rig.pose.bones:
    pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.scale=(1,1,1)
bpy.context.view_layer.update()
bind=evaluated()
bind_error=max((p-(o.matrix_world@v.co)).length for o in objs for p,v in zip(bind[o.name],o.data.vertices))
report['unposed_IK_bind_shape_error_m']=bind_error
assert bind_error<.003, bind_error
report['clips']={}
for name,length in [('Sneak_Walk',48),('Alert_Idle',72)]:
    rig.animation_data.action=bpy.data.actions[name]
    s.frame_set(1); first=evaluated()
    s.frame_set(length+1); last=evaluated()
    looperr=max((p-q).length for n in first for p,q in zip(first[n],last[n]))
    floors=[]; ikerrors=[]; motion=0; maxratio=0
    for f in range(1,length+1):
        s.frame_set(f); ev=evaluated()
        floors.append(min(p.z for n,vs in ev.items() if '_Foot_' in n or '_Toe_' in n for p in vs))
        motion=max(motion,max((p-q).length for n in first for p,q in zip(first[n],ev[n])))
        for suf in ['L','R']:
            for lower,ctrl in [('shin','foot'),('forearm','hand')]:
                ikerrors.append((rig.pose.bones[lower+'.'+suf].tail-rig.pose.bones['CTRL-'+ctrl+'.'+suf].head).length)
        for o in objs:
            if '_Arm_' not in o.name and '_Leg_' not in o.name: continue
            for e in o.data.edges:
                a,b=e.vertices; rest=(o.data.vertices[a].co-o.data.vertices[b].co).length
                if rest>1e-6: maxratio=max(maxratio,(ev[o.name][a]-ev[o.name][b]).length/rest)
        assert all(math.isfinite(v) for vs in ev.values() for p in vs for v in p)
    report['clips'][name]={'loop_vertex_error_m':looperr,'min_foot_height_m':min(floors),
        'max_IK_endpoint_error_m':max(ikerrors),'max_vertex_motion_m':motion,'max_limb_edge_stretch_ratio':maxratio}
    assert looperr<1e-4 and min(floors)>-.015 and max(ikerrors)<.025 and motion>.03, report['clips'][name]
report['pass']=True
(P/'rig_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
