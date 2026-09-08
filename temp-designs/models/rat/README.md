# Rat Form

Static low-poly model based on `selected-concepts/rat.png` and the Rat Form definition in `CONTEXT.md`.

- `rat.blend`: editable source with 36 named closed mesh components, four character materials, five cameras, studio lighting, and the packed selected reference.
- `rat.glb`: consolidated character mesh with four material slots for import into Godot or other glTF-compatible tools.
- `rat_contact_sheet.jpg`: hero, front, side, and back renders. Individual previews also include the top view.
- `front_overlay_reference.png`: pink marks reference-only pixels; cyan marks model-only pixels in the registered front view.

The model retains a hunched narrow torso, long thin limbs, three fingers and an opposed thumb on each hand, broad three-toed feet, a pointed muzzle, uneven faceted ears, and an angular tapering tail. Exactly two bead eyes follow the character docs; duplicate dark eye-like marks in the generated reference are omitted. Two small ivory incisors follow the provisional selected mouth direction.

The front panel supplies silhouette measurements; the hero and side panels guide depth and posture. Generated views have inconsistent proportions and poses, so hidden geometry is interpreted. This is a static posed asset, with overlapping closed components at anatomical joins. It has no rig, animations, or UV textures; production animation needs a deformation topology and rigging pass. Its approximate 2.43 m working height can be rescaled together with the Fish Form for their documented equal height.

## Rebuild

Run from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python models/rat/build_rat.py
python models/rat/validate_reference.py
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python models/rat/export_rat.py
python models/rat/make_contact_sheet.py
```

Add `-- draft` to the build command for faster hero/front/side previews. `geometry.py` holds the measured character geometry; `build_rat.py` supplies mesh helpers, materials, scene setup, and render/mesh audits. Reference, geometry, and export checks are recorded in the adjacent JSON files. Export requires a passing reference check and verifies triangle count, material count, bounds, and exclusion of studio objects through a fresh GLB import.
