"""Render rig previews. Pass -- full for both complete animation sequences."""
import bpy, sys, json
from pathlib import Path
P=Path(__file__).resolve().parent/'rigged'
bpy.ops.wm.open_mainfile(filepath=str(P/'rat_rigged.blend'))
s=bpy.context.scene; rig=bpy.data.objects['RIG-Rat']
s.render.resolution_x=640; s.render.resolution_y=640
s.render.resolution_percentage=100
s.cycles.samples=12; s.cycles.use_denoising=True
s.render.use_persistent_data=True
s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGB'
s.camera=bpy.data.objects['CAM-Hero']
full='full' in sys.argv
for clip,length in [('Sneak_Walk',48),('Alert_Idle',72)]:
    rig.animation_data.action=bpy.data.actions[clip]
    directory=P/'frames'/clip; directory.mkdir(parents=True,exist_ok=True)
    for frame in (range(1,length+1) if full else [1,13,25,37]):
        s.frame_set(frame); s.render.filepath=str(directory/f'{frame:04}.png')
        if full and Path(s.render.filepath).exists(): continue
        bpy.ops.render.render(write_still=True)
        print('FRAME_DONE',clip,frame,flush=True)
    if not full:
        s.camera=bpy.data.objects['CAM-Side']; s.frame_set(13)
        s.render.filepath=str(P/f'{clip}_side.png'); bpy.ops.render.render(write_still=True)
        s.camera=bpy.data.objects['CAM-Hero']
