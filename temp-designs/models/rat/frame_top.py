import bpy
from pathlib import Path
from mathutils import Vector
p=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(p/'rat.blend'))
s=bpy.context.scene;c=bpy.data.objects['CAM-Top'];c.location=(0,.36,7)
c.rotation_euler=(Vector((0,.36,0))-c.location).to_track_quat('-Z','Y').to_euler();c.data.ortho_scale=3.65
bpy.ops.wm.save_as_mainfile(filepath=str(p/'rat.blend'))
s.camera=c;s.render.filepath=str(p/'top_preview.png');bpy.ops.render.render(write_still=True)
