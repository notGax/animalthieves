# Slime model

Source: `selected-concepts/slime.png`, the finalized sheet. The lower-left near-front view controls the silhouette and face; the hero and side views inform depth and surface treatment. The unseen back and underside are inferred.

- `slime.blend`: editable body, two eyes, mouth, packed reference sheet, studio, and five cameras.
- `slime.glb`: character meshes and materials only, exported Y-up for Godot. Static; no rig or animations.
- `slime_contact_sheet.jpg`: hero, front, side, and back renders.
- `front_overlay_reference.png`: aligned near-front comparison.
- `front_mask_validation.json`, `mesh_validation.json`, `export_validation.json`: silhouette, topology, and export checks.

The body uses a single Principled material named `MAT-Slime | change Base Color for player color`. Change its Base Color to customize the slime. The four meshes are in `SLIME | export geometry`. Studio objects are hidden in the editing viewport, but enabled for renders. The packed reference is in its own hidden collection.

The body is approximately 1.8m wide and 0.96m tall in working units; final gameplay scale remains adjustable. Flat triangular shading preserves the selected low-poly style. No image textures or external assets are needed by the GLB. The mouth is retained from the finalized reference.

Rebuild with Blender's `--background --python build_slime.py`, run `validate_reference.py` using Python with Pillow/numpy, then run `export_slime.py` through Blender. Validation uses uniform-scale alignment of the source's near-front view; it does not claim exact 3D reconstruction from a perspective concept sheet.

Workflow guidance: RobLe3/cc-blender-skill (`blender-modeling`, `reference-to-3d`, `blender-materials`, `blender-rendering`, `blender-export`). Run via local Blender Python; no MCP connector needed. The scripts use the installed Blender 5.2 API rather than copying incompatible example settings.
