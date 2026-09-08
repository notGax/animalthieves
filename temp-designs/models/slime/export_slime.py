"""Export only the validated character; round-trip the GLB to check content."""
import bpy,json
from pathlib import Path
P=Path(__file__).resolve().parent
validation=json.loads((P/'front_mask_validation.json').read_text())
if not validation['pass']:raise RuntimeError('Reference silhouette check failed')
bpy.ops.wm.open_mainfile(filepath=str(P/'slime.blend'))
bpy.ops.object.select_all(action='DESELECT')
objects=list(bpy.data.collections['SLIME | export geometry'].objects)
assert len(objects)==4
for o in objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(P/'slime.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_materials='EXPORT')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(P/'slime.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(meshes)==4
assert all(o.data.materials for o in meshes)
report={'mesh_count':len(meshes),'names':[o.name for o in meshes],'materials':[m.name for m in bpy.data.materials], 'bytes':(P/'slime.glb').stat().st_size,'roundtrip_pass':True}
(P/'export_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
