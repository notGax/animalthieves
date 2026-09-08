"""Export just the fish, consolidate meshes for Godot, then verify a clean re-import."""
import bpy,json
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent
check=json.loads((P/'front_mask_validation.json').read_text())
assert check['pass'], 'Reference validation must pass before export.'
bpy.ops.wm.open_mainfile(filepath=str(P/'fish.blend'))
objs=list(bpy.data.collections['FISH | character geometry'].objects)
def bounds(objects):
    vs=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
    return [[min(v[k] for v in vs) for k in range(3)],[max(v[k] for v in vs) for k in range(3)]]
before=bounds(objs)
bpy.ops.object.select_all(action='DESELECT')
for o in objs:o.hide_set(False);o.select_set(True)
bpy.context.view_layer.objects.active=objs[0]
bpy.ops.object.join();fish=bpy.context.object;fish.name='GEO-Fish'
expected_tris=sum(len(p.vertices)-2 for p in fish.data.polygons)
bpy.ops.export_scene.gltf(filepath=str(P/'fish.glb'),export_format='GLB',use_selection=True,
    export_apply=True,export_animations=False,export_materials='EXPORT',export_yup=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(P/'fish.glb'))
imported=[o for o in bpy.context.scene.objects if o.type=='MESH']
after=bounds(imported);error=max(abs(before[j][k]-after[j][k]) for j in range(2) for k in range(3))
actual_tris=sum(len(p.vertices)-2 for o in imported for p in o.data.polygons)
materials=sorted({m.name for o in imported for m in o.data.materials})
assert len(imported)==1 and len(materials)==5 and error<.0001 and actual_tris==expected_tris
assert not any(o.type in {'LIGHT','CAMERA','ARMATURE'} for o in bpy.context.scene.objects)
report={'roundtrip_pass':True,'mesh_count':len(imported),'materials':materials,'triangles':actual_tris,
    'bounds_error_metres':error,'bounds_metres':after,'bytes':(P/'fish.glb').stat().st_size,
    'note':'Export has one character mesh with five material slots. Editable Blender source keeps 8 named parts. No rig or animations.'}
(P/'export_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
