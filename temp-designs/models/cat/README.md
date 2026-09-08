# Cat Form — selected lanky prowler

Built from `selected-concepts/cat.png`, with the upper-right front view setting proportions and the lower-right side view guiding depth and the forward hunch.

- `cat.blend`: editable source, 34 named character meshes, packed concept image, five cameras, and a studio lighting setup.
- `cat.glb`: static character export, consolidated into one mesh with three material slots. Studio and reference objects are excluded.
- `cat_contact_sheet.jpg`: hero, front, side, and back renders.
- `hero_preview.png`, `front_preview.png`, `side_preview.png`, `back_preview.png`, `top_preview.png`: full-resolution renders.

The cat has a narrow hunched torso, long limbs, two gripping hands with three fingers and an opposed thumb each, broad three-toed feet, two angular ears, exactly two dark bead eyes, a compact cream muzzle, and a continuous question-mark tail. The model uses 2,534 triangles. Orange coat, cream details, and black facial features use simple editable Principled materials with no texture dependencies.

The asset faces Blender -Y with Z up, with its feet near ground level. Its working height is approximately 2.53 metres; final game scale remains adjustable. The GLB uses the standard glTF axis conversion.

This is a static posed model. It does not include a skeleton, skin weights, locomotion, or transformation animations. Separate closed components overlap at anatomical joins; animation production would require a deformation/retopology pass. The generated concept views are not calibrated orthographic drawings, so depth and unseen back surfaces are interpretations.

## Editing

Open `cat.blend`. Character parts are in `CAT | character geometry`; materials begin with `MAT-Cat`. The selected concept is packed in the hidden `REFERENCE | selected concept` collection. Studio objects are hidden in the editing viewport but enabled for rendering. Cameras provide hero, front, side, back, and top views.

## Rebuild and validation

Run from the project root, using Blender's executable for the first and third commands:

```text
blender --background --python models/cat/build_cat.py
python models/cat/validate_reference.py
blender --background --python models/cat/export_cat.py
python models/cat/make_contact_sheet.py
```

`build_cat.py -- draft` renders a faster hero/front/side check. Rebuilding replaces the files in this folder, so save manual edits under a new name first.

Validation artifacts:

- `reference_manifest.json`: measured source registration and design constraints.
- `front_overlay_reference.png`: pink indicates reference-only silhouette; cyan indicates model-only silhouette.
- `front_mask_validation.json`: fixed-registration silhouette IoU, centroid and face feature checks. A 90% IoU threshold is required before export.
- `mesh_validation.json` and `scene_validation.json`: manifold edge, degenerate face, geometry count, semantic part, and eye count checks.
- `export_validation.json`: clean GLB re-import verifies triangle count, material count, bounds, and exclusion of studio objects.

The silhouette score measures one projected outline; it does not assert a perfect 3D reconstruction of the concept.
