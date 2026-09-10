# Rat rig and movement demos

Open `rat_rigged.blend` and press **Spacebar** to play the sneak walk. The timeline is set to frames 1–48 at 24 fps. The original static `../rat.blend` and `../rat.glb` are preserved.

## Deliverables

- `rat_rigged.blend`: editable 52-bone rig, 36 weighted mesh components, studio, cameras, and two original animation actions.
- `rat_rigged.glb`: one skinned mesh, four materials, 44 exported bones including the root, and both baked clips. 3,066 triangles.
- `rat_movement_demo.mp4`: sneak walk followed by alert idle, each repeated twice.
- `sneak_walk.gif`: looping movement preview.
- `movement_contact_sheet.jpg`: sample poses from both clips.
- `rig_manifest.json`, `rig_validation.json`, `export_validation.json`: bone layout, mesh edits, and checks.

## Animation clips

| Action | Blender frames | Duration | Motion |
|---|---|---|---|
| Sneak_Walk | 1–49 | 2 seconds | Alternating planted/lifted feet, crouched body bob, opposite arm swings, finger motion, ear motion, trailing tail sway |
| Alert_Idle | 1–73 | 3 seconds | Breathing, cautious head turns, ear twitches, finger motion and tail sway |

The last frame duplicates the first. Play frames 1–48 or 1–72 in Blender to avoid holding that duplicate frame. Switch actions through the Dope Sheet's **Action Editor** and adjust the timeline end accordingly. Both actions have Fake User enabled so they remain saved.

These are custom animations authored for this model; no downloaded or third-party motion assets are used. The walk is **in place**, with no travel in its root. At the current working scale, the planted foot moves 0.32 m over one second, so approximately 0.32 m/s forward character movement matches the stance portion. Adapt speed and scale for gameplay.

## Posing controls

Select `RIG-Rat`, enter **Pose Mode** (Ctrl+Tab), then select bones. Enable In Front to see them through the mesh; this is already configured.

- `CTRL-root`: move or rotate the entire character.
- `CTRL-foot.L/R`: move the foot; two-bone IK bends the thigh and shin. Rotating the control rotates the foot.
- `CTRL-knee.L/R`: steer the knee bend direction.
- `CTRL-hand.L/R`: position and rotate the hand; two-bone IK bends the arm.
- `CTRL-elbow.L/R`: steer the elbow bend direction.
- `pelvis`, `spine`, `chest`, `neck`, `head`: body and head pose.
- `finger1/2/3_01/02.L/R`, `thumb01/02.L/R`: individual gripping digits.
- `ear.L/R`, `tail01` through `tail06`, `toes.L/R`: secondary posing.

To make a new animation, create a new action before posing, or duplicate an existing one. Returning to another frame restores the active action's keyed pose. To inspect the exact bind shape, set the armature's Skeleton setting to **Rest Position**; restore Pose Position to animate.

The GLB contains baked deformation bones, not Blender IK constraints or pole controls. Use the `.blend` for editing the rig. glTF-compatible engines can play its named animation clips; configure looping in the engine's animation import/playback settings. Validation covers a Blender GLB re-import, not an in-engine integration test.

## Mesh preparation and practical limits

Ten additional cross-sections per arm/leg preserve the rest contour and provide geometry for bending. Weights are explicitly assigned by anatomical region, normalized, and limited to two influences per vertex. Eyes, nose and teeth follow the head; ears and digits have their own bones. No automatic proximity binding is used.

The selected low-poly character shape and flat shading are retained. Anatomical joins remain separate overlapping closed components; this is a useful first gameplay rig, not a welded character topology or a facial performance rig. The supplied walk and idle are visually checked. Extreme splits, arm twists, deep squats and other new animation poses may need further weight/topology adjustments.

## Validation

- Every character vertex has normalized deformation weights; maximum two influences.
- Both animation loops return to their starting evaluated geometry.
- Full-frame sweeps check finite geometry, floor clearance, and hand/foot IK target error.
- Limb edge stretch is measured; the walk's maximum is about 1.23×, the idle's about 1.05×.
- Re-imported GLB sample poses match the source to within 0.001 m (actual errors are around 0.000002 m).
- Export contains one skin, one mesh, four materials and both animation clips; the studio is excluded.

## Rebuild

From `temp-designs`, use Blender for the first four commands, then system Python and ffmpeg for encoding:

```text
blender --background --python models/rat/rig_rat.py
blender --background --python models/rat/validate_rig.py
blender --background --python models/rat/export_rig.py
blender --background --python models/rat/preview_rig.py -- full
python models/rat/package_rig_preview.py
```

Generated files in this directory are replaced when rebuilt. Save manual rig or animation edits under a different filename first. `preview_rig.py` without `-- full` renders a small selection of poses and a side view. Full rendering skips existing frames; clear the `frames` directory after changing an animation before rerendering it.
