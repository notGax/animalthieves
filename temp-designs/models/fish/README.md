# Fish Form

Static low-poly model based on `selected-concepts/fish.png` and the Fish Form definition in `CONTEXT.md`.

- `fish.blend`: editable source with eight named closed mesh components, five character materials, five cameras, studio lighting, and the packed selected reference.
- `fish.glb`: consolidated character mesh with five material slots for Godot and other glTF-compatible tools.
- `fish_contact_sheet.jpg`: hero, front, side, and back renders. A separate top preview is also included.
- `front_overlay_reference.png`: registered front comparison; pink is reference-only and cyan is model-only.

The fish has a continuous skinny hunched body, a blue crown, silver belly, angular dark mackerel markings, exactly two tiny bead eyes, a compact open mouth, and two small pectoral fins for handling equipment. Its single intact forked caudal fin forms the entire standing base. There are no human limbs or separate feet. The approximately 2.43 m working height matches the Rat Form.

The selected front panel controls silhouette and face positions; hero and side panels guide depth. The generated views differ in fin pose and proportions, so this is an interpreted three-dimensional model. The body, jaw, fins, mouth, and eyes remain separate editable closed components with overlaps at joins. This is a static posed asset without a rig, animations, or UV textures. Production animation needs a deformation topology and rigging pass. The markings are assigned mesh-face materials and are retained in the GLB.

## Rebuild

Run from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python models/fish/build_fish.py
python models/fish/validate_reference.py
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python models/fish/export_fish.py
python models/fish/make_contact_sheet.py
```

Add `-- draft` to the build command for quicker hero/front/side previews. `geometry.py` contains the measured character shape; `build_fish.py` supplies mesh helpers, materials, scene setup, and rendering. Adjacent JSON files record the source manifest, mesh checks, silhouette/eye comparison, and export verification. The export script requires passing reference checks and verifies triangle count, materials, bounds, and exclusion of studio objects through a fresh GLB import.
