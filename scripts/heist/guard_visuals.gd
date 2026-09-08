extends RefCounted
## Body builders for the heist guards and bosses. Everything purely visual
## lives here so security_guard.gd keeps only AI, combat and the animation
## driver. Each builder parents its meshes to the given model rig and returns
## the "animation hooks" - node refs and base transforms that the guard's
## _process poses every frame (glances, squash, hat inertia, ear lag, tail
## sway, ladle swings). Keys mirror the identically-named members on the guard
## script, so setup() copies them straight across.
## The body-level cosmetics (stun stars, bribe halo, title, aura, tell ring)
## are built here too but parented to the guard BODY, not the model, so they
## never inherit the model's squash, lean or yaw.
const Visual = preload("res://scripts/heist/slime_visual.gd")
const Materials = preload("res://scripts/visuals/character_materials.gd")
const Palette = preload("res://scripts/visuals/palette.gd")


static func build(body: Node3D, model: Node3D, boss: bool, tier: int) -> Dictionary:
	## Pick the body build for this tier, then dress the shared cosmetics
	## around it. Returns every hook _process needs.
	var rig: Dictionary
	if tier == 3:
		rig = _dragon(model)
	elif boss and tier == 0:
		rig = _chef(model)
	else:
		rig = _guard(model, tier, 1.5 if boss else 1.0)
	rig["base_scale"] = model.scale
	# Stun stars orbit overhead only while STUNNED; the mold-green halo marks
	# a bribed guard. Both are cosmetic siblings of the tell ring.
	var stars := Node3D.new()
	stars.position.y = 5.0 if (boss and tier == 0) else (4.2 if boss else 3.0)
	body.add_child(stars)
	var star_mat := Materials.lit(Color("ffd24a"),1.4)
	for i in range(3):
		var star := MeshInstance3D.new()
		star.mesh = Materials.sphere_mesh(8, 5, .14, .28)
		star.material_override = star_mat
		stars.add_child(star)
	stars.visible = false
	rig["stars"] = stars
	bribe_ring(body,rig,boss,tier)
	title(body,rig,boss)
	if boss:
		# Pulsing aggro aura: a sibling ring of tell, never replacing it.
		var aura := MeshInstance3D.new()
		aura.mesh = Materials.cyl_mesh(2.85, 2.85, .02)
		aura.position.y = .05
		var aura_mat := StandardMaterial3D.new()
		aura_mat.albedo_color = Color(1,.37,.66,.25)
		aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		aura_mat.emission_enabled = true
		aura_mat.emission = Color(1,.37,.66)
		aura_mat.emission_energy_multiplier = 1.1
		aura.material_override = aura_mat
		body.add_child(aura)
		rig["aura"] = aura
		rig["aura_mat"] = aura_mat
	else:
		rig["aura"] = null
		rig["aura_mat"] = null
	var tell_radius := 2.6 if boss else 1.2
	var tell := MeshInstance3D.new()
	tell.mesh = Materials.cyl_mesh(tell_radius, tell_radius, .025)
	tell.position.y = .03
	var tell_mat := StandardMaterial3D.new()
	tell_mat.albedo_color = Color(1,.25,.08,.38)
	tell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tell_mat.emission_enabled = true
	tell_mat.emission = Color(1,.12,.015)
	tell.material_override = tell_mat
	body.add_child(tell)
	rig["tell"] = tell
	rig["tell_mat"] = tell_mat
	return rig


static func bribe_ring(body: Node3D, rig: Dictionary, boss: bool, tier: int) -> void:
	var ring := MeshInstance3D.new()
	var halo_radius := .9 if boss else .55
	ring.mesh = Materials.cyl_mesh(halo_radius, halo_radius, .04)
	var bribe_base := 4.6 if (boss and tier == 0) else (3.9 if boss else 2.95)
	ring.position.y = bribe_base
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(.498,.682,.239,.55)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(.498,.682,.239)
	halo_mat.emission_energy_multiplier = 1.2
	ring.material_override = halo_mat
	body.add_child(ring)
	ring.visible = false
	rig["bribe_ring"] = ring
	rig["bribe_base"] = bribe_base


static func title(body: Node3D, rig: Dictionary, boss: bool) -> void:
	var label := Label3D.new()
	label.position.y = 4.5 if boss else 2.6
	label.font_size = 20
	label.pixel_size = .008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	body.add_child(label)
	rig["title"] = label


static func metal_box(model: Node3D,pos: Vector3,size: Vector3,color: Color,parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh=Materials.box_mesh(size)
	part.position=pos
	part.material_override=Materials.metal(color)
	(parent if parent else model).add_child(part)
	return part


static func horn(parent: Node3D,pos: Vector3,height: float,radius: float) -> void:
	var part := MeshInstance3D.new()
	part.mesh=Materials.cyl_mesh(0.0,radius,height,8)
	part.position=pos
	part.material_override=Materials.metal(Color("ffd24a"))
	parent.add_child(part)


static func _guard(model: Node3D, tier: int, scale_factor: float) -> Dictionary:
	## Species-dressed chunky guard: shared sphere base plus a kit per species,
	## colored from the shared guard palette. The face is a head rig so glances
	## carry eyes, muzzle and species face parts together.
	model.scale = Vector3.ONE*scale_factor
	var skin: Dictionary = Palette.GUARD[tier]
	var body: Color = Palette.color(skin.body)
	var cream := Palette.color("fdf3d0")
	var tail: Array[MeshInstance3D] = []
	var torso := Visual.sphere(model,Vector3(0,.8,0),Vector3(1.25,1.55,.95),body)
	var head := Node3D.new()
	var head_base := Vector3(0,1.72,.08)
	head.position = head_base
	model.add_child(head)
	Visual.sphere(head,Vector3.ZERO,Vector3(1.05,.9,.9),body)
	Visual.sphere(head,Vector3(0,-.27,-.53),Vector3(.58,.34,.62),Palette.color(skin.belly))
	var eye_l: MeshInstance3D = null
	var eye_r: MeshInstance3D = null
	var pupil_l: MeshInstance3D = null
	var pupil_r: MeshInstance3D = null
	var pupil_base_l := Vector3.ZERO
	var pupil_base_r := Vector3.ZERO
	var eye_base_l := Vector3.ONE
	var eye_base_r := Vector3.ONE
	var pupil_scale_l := Vector3.ONE
	var pupil_scale_r := Vector3.ONE
	for x in [-.264,.264]:
		var white := Visual.sphere(head,Vector3(x,.1,-.54),Vector3(.26,.28,.13),cream)
		var pupil := Visual.sphere(head,Vector3(x,.1,-.62),Vector3(.12,.17,.08),Palette.color(skin.pupil))
		# Dark pupils ride the raised-light-floor face material so the eyes
		# keep their dot even when the guard stands in a shadow pool.
		pupil.material_override = Materials.toon_face(Palette.color(skin.pupil))
		if x < 0.0:
			eye_l = white
			eye_base_l = white.scale
			pupil_l = pupil
			pupil_base_l = pupil.position
			pupil_scale_l = pupil.scale
		else:
			eye_r = white
			eye_base_r = white.scale
			pupil_r = pupil
			pupil_base_r = pupil.position
			pupil_scale_r = pupil.scale
	var arm_l: MeshInstance3D = null
	var arm_r: MeshInstance3D = null
	for x in [-.616,.616]:
		var arm := Visual.sphere(model,Vector3(x,.9,0),Vector3(.26,.72,.3),body.darkened(.12))
		if x < 0.0:
			arm_l = arm
		else:
			arm_r = arm
	Visual.sphere(model,Vector3(-.279,.14,-.1),Vector3(.42,.28,.66),body.darkened(.24))
	Visual.sphere(model,Vector3(.279,.14,-.1),Vector3(.42,.28,.66),body.darkened(.24))
	var hat: Node3D = null
	var ear_l: Node3D = null
	var ear_r: Node3D = null
	var torch: Node3D = null
	var torch_base := Vector3.ZERO
	match tier:
		0:  # Rat: turquoise vest, plum cap with badge, big ears, banded tail, torch.
			Visual.sphere(model,Vector3(0,1.0,-.48),Vector3(1.02,.82,.5),Palette.color(skin.vest))
			hat = Node3D.new()
			hat.position = Vector3(0,2.3,.02)
			model.add_child(hat)
			Visual.sphere(hat,Vector3.ZERO,Vector3(.92,.42,.88),Palette.color(skin.cap))
			Visual.sphere(hat,Vector3(0,-.06,-.46),Vector3(.5,.07,.26),Palette.color(skin.cap).darkened(.1))
			Visual.sphere(hat,Vector3(.4,.04,0),Vector3(.1,.06,.1),Palette.color(skin.badge))
			for x in [-.66,.66]:
				var ear := Node3D.new()
				ear.position = Vector3(x,.9,-.04)
				head.add_child(ear)
				Visual.sphere(ear,Vector3.ZERO,Vector3(.46,.52,.18),Palette.color(skin.ear))
				Visual.sphere(ear,Vector3(0,0,-.09),Vector3(.3,.36,.12),Palette.color(skin.snout))
				if x < 0.0:
					ear_l = ear
				else:
					ear_r = ear
			tail.append(Visual.sphere(model,Vector3(.3,.2,.72),Vector3(.18,.2,1.25),Palette.color(skin.snout)))
			tail.append(Visual.sphere(model,Vector3(.3,.2,1.0),Vector3(.21,.23,.16),Palette.color(skin.vest).darkened(.2)))
			torch = Node3D.new()
			torch_base = Vector3(-.75,1.1,-.35)
			torch.position = torch_base
			model.add_child(torch)
			Visual.sphere(torch,Vector3.ZERO,Vector3(.12,.12,.42),Palette.color(skin.cap))
			Visual.sphere(torch,Vector3(0,0,-.25),Vector3(.09,.09,.06),Palette.color(skin.badge))
		1:  # Boar: hard hat, shoulder pads, tusks, hi-vis vest stripe.
			hat = Node3D.new()
			hat.position = Vector3(0,2.32,0)
			model.add_child(hat)
			Visual.sphere(hat,Vector3.ZERO,Vector3(.85,.4,.8),Palette.color(skin.cap))
			Visual.sphere(hat,Vector3(0,.12,0),Vector3(.88,.28,.84),Palette.color(skin.cap).darkened(.15))
			Visual.sphere(hat,Vector3(0,-.02,-.4),Vector3(.55,.06,.3),Palette.color(skin.cap).darkened(.15))
			for x in [-.78,.78]:
				Visual.sphere(model,Vector3(x,1.9,.05),Vector3(.42,.3,.5),Palette.color(skin.snout).darkened(.1))
			Visual.sphere(model,Vector3(0,1.0,-.48),Vector3(1.0,.8,.48),Palette.color(skin.vest))
			Visual.sphere(model,Vector3(0,1.0,-.72),Vector3(.88,.18,.1),cream)
			Visual.sphere(head,Vector3(-.28,-.22,-.86),Vector3(.09,.09,.3),Palette.color(skin.tusk))
			Visual.sphere(head,Vector3(.28,-.22,-.86),Vector3(.09,.09,.3),Palette.color(skin.tusk))
		2:  # Magpie: glossy wings, conical beak, tail fan, swept crest.
			for x in [-1.05,1.05]:
				Visual.sphere(model,Vector3(x,1.15,.12),Vector3(.5,.68,.8),Palette.color(skin.wing))
				Visual.sphere(model,Vector3(x*1.1,.62,.72),Vector3(.26,.09,.45),Palette.color(skin.wing))
			Visual.sphere(head,Vector3(0,-.17,-.96),Vector3(.3,.26,.28),Palette.color(skin.beak))
			Visual.sphere(head,Vector3(0,-.22,-1.16),Vector3(.1,.1,.3),Palette.color(skin.beak).darkened(.15))
			hat = Node3D.new()
			hat.position = Vector3(0,2.42,.3)
			model.add_child(hat)
			for i in range(3):
				Visual.sphere(hat,Vector3(-.2+i*.2,-i*.04,0),Vector3(.1,.3,.1),Palette.color(skin.wing))
			for i in range(3):
				var side: float = -1.0+i
				Visual.sphere(model,Vector3(side*.3,.45,.55),Vector3(.2,.08,.6),Palette.color(skin.wing))
		3:  # Lizard: belly plates, emissive visor, dorsal spikes, claws.
			var visor := Visual.sphere(head,Vector3(0,.16,-.76),Vector3(.78,.22,.16),Palette.color(skin.visor))
			visor.material_override = Materials.lit(Palette.color(skin.visor),1.2)
			for i in range(3):
				Visual.sphere(model,Vector3(0,1.28-i*.36,-.5),Vector3(.5-i*.08,.12,.3),Palette.color(skin.belly))
			hat = Node3D.new()
			hat.position = Vector3(0,2.1,.28)
			model.add_child(hat)
			for i in range(4):
				horn(hat,Vector3(0,-i*.13,-i*.3),.42-i*.06,.12)
			Visual.sphere(model,Vector3(-.62,.14,-.32),Vector3(.1,.08,.2),cream)
			Visual.sphere(model,Vector3(.62,.14,-.32),Vector3(.1,.08,.2),cream)
	return {
		"torso": torso, "belly": null, "head": head, "head_base": head_base,
		"eye_l": eye_l, "eye_r": eye_r, "pupil_l": pupil_l, "pupil_r": pupil_r,
		"pupil_base_l": pupil_base_l, "pupil_base_r": pupil_base_r,
		"eye_base_l": eye_base_l, "eye_base_r": eye_base_r,
		"pupil_scale_l": pupil_scale_l, "pupil_scale_r": pupil_scale_r,
		"ear_l": ear_l, "ear_r": ear_r, "tail": tail,
		"hat": hat, "hat_base": hat.position if hat else Vector3.ZERO,
		"torch": torch, "torch_base": torch_base,
		"mouth": null, "ladle": null, "ladle_base": Vector3.ZERO,
		"arm_l": arm_l, "arm_r": arm_r,
	}


static func _chef(model: Node3D) -> Dictionary:
	## THE BIG CHEESE: fat, flour-dusted, mustachioed. Fat-and-short proportions
	## that stay inside the boss capsule's 2.0 width. Face parts hang off a head
	## rig so glances and expressions pose the whole face at once. The BACK is
	## dressed as deliberately as the face - haunches, hunched shoulders, apron
	## strings knotted across the rear and a fat rat tail - so the silhouette
	## reads "waddling chef rat" from any angle, not just head-on.
	model.scale = Vector3(1.3,1.1,1.3)
	var skin: Dictionary = Palette.BOSS
	var body: Color = Palette.color(skin.body)
	var cream := Palette.color("fdf3d0")
	var tail: Array[MeshInstance3D] = []
	var torso := Visual.sphere(model,Vector3(0,.62,0),Vector3(1.5,1.35,1.2),body)
	var belly := Visual.sphere(model,Vector3(0,1.5,0),Vector3(1.15,.8,.95),Palette.color(skin.belly))
	# Rear haunches break the single-sphere back view into a fat, waddling
	# two-lobed read without widening the front past the boss capsule.
	Visual.sphere(model,Vector3(-.44,.32,.44),Vector3(.56,.62,.6),body.darkened(.06))
	Visual.sphere(model,Vector3(.44,.32,.44),Vector3(.56,.62,.6),body.darkened(.06))
	# Hunched shoulders widen the top of the back view under the head.
	Visual.sphere(model,Vector3(-.66,1.62,.02),Vector3(.5,.3,.5),body.darkened(.04))
	Visual.sphere(model,Vector3(.66,1.62,.02),Vector3(.5,.3,.5),body.darkened(.04))
	var head := Node3D.new()
	var head_base := Vector3(0,2.0,.06)
	head.position = head_base
	model.add_child(head)
	Visual.sphere(head,Vector3.ZERO,Vector3(.95,.8,.85),body)
	Visual.sphere(head,Vector3(0,-.1,-.56),Vector3(.5,.3,.55),Palette.color(skin.snout))
	var eye_l: MeshInstance3D = null
	var eye_r: MeshInstance3D = null
	var pupil_l: MeshInstance3D = null
	var pupil_r: MeshInstance3D = null
	var pupil_base_l := Vector3.ZERO
	var pupil_base_r := Vector3.ZERO
	var eye_base_l := Vector3.ONE
	var eye_base_r := Vector3.ONE
	var pupil_scale_l := Vector3.ONE
	var pupil_scale_r := Vector3.ONE
	var arm_l: MeshInstance3D = null
	var arm_r: MeshInstance3D = null
	for x in [-.4,.4]:
		var white := Visual.sphere(head,Vector3(x*.55,.12,-.56),Vector3(.24,.26,.12),cream)
		var pupil := Visual.sphere(head,Vector3(x*.55,.12,-.64),Vector3(.11,.16,.07),Palette.color("1b2b33"))
		pupil.material_override = Materials.toon_face(Palette.color("1b2b33"))
		var arm := Visual.sphere(model,Vector3(x*1.35,.85,0),Vector3(.3,.75,.32),body.darkened(.12))
		if x < 0.0:
			eye_l = white
			eye_base_l = white.scale
			pupil_l = pupil
			pupil_base_l = pupil.position
			pupil_scale_l = pupil.scale
			arm_l = arm
		else:
			eye_r = white
			eye_base_r = white.scale
			pupil_r = pupil
			pupil_base_r = pupil.position
			pupil_scale_r = pupil.scale
			arm_r = arm
		Visual.sphere(model,Vector3(x*.62,.12,-.05),Vector3(.45,.22,.62),body.darkened(.24))
	var ear_l: Node3D = null
	var ear_r: Node3D = null
	for x in [-.7,.7]:
		var ear := Node3D.new()
		ear.position = Vector3(x,.55,-.04)
		head.add_child(ear)
		Visual.sphere(ear,Vector3.ZERO,Vector3(.4,.45,.16),Palette.color(skin.ear))
		if x < 0.0:
			ear_l = ear
		else:
			ear_r = ear
	# Wobbly tall toque on its own node so _process can sway it: straight
	# cylinder column under a puffed crown reads as "chef" across the arena,
	# where the old white sphere stack just read as a lump. The column leans a
	# touch off vertical so even the hat's back view has a crooked, authored
	# line (the hat node itself is driven by _process, so the lean lives here).
	var hat := Node3D.new()
	model.add_child(hat)
	var toque := MeshInstance3D.new()
	toque.mesh=Materials.cyl_mesh(.4,.32,1.2,12)
	toque.position=Vector3(0,3.12,0)
	toque.rotation=Vector3(0,0,.09)
	toque.material_override=Materials.toon_part(Palette.color(skin.hat))
	hat.add_child(toque)
	Visual.sphere(hat,Vector3(0,3.78,0),Vector3(.9,.42,.84),Palette.color(skin.hat))
	Visual.sphere(hat,Vector3(0,2.66,0),Vector3(.88,.22,.82),Palette.color(skin.hat_band))
	Visual.sphere(model,Vector3(0,.9,-.6),Vector3(1.05,1.05,.12),Palette.color(skin.apron))
	Visual.sphere(model,Vector3(-.35,.9,-.68),Vector3(.05,1.0,.05),Palette.color(skin.strap))
	Visual.sphere(model,Vector3(.35,.9,-.68),Vector3(.05,1.0,.05),Palette.color(skin.strap))
	# Apron strings tie at the BACK: two straps crossing into the knot plus
	# two trailing ends, so the rear view reads as dressed rather than a bare
	# sphere.
	var knot_strap := Palette.color(skin.strap)
	var strap_l := Visual.sphere(model,Vector3(-.24,1.06,.58),Vector3(.08,.62,.07),knot_strap)
	strap_l.rotation.z = .45
	var strap_r := Visual.sphere(model,Vector3(.24,1.06,.58),Vector3(.08,.62,.07),knot_strap)
	strap_r.rotation.z = -.45
	Visual.sphere(model,Vector3(0,.9,.62),Vector3(.15,.12,.11),knot_strap)
	Visual.sphere(model,Vector3(-.14,.66,.58),Vector3(.06,.26,.06),knot_strap)
	Visual.sphere(model,Vector3(.14,.66,.58),Vector3(.06,.26,.06),knot_strap)
	# A fat rat tail curls UP over the haunches behind the boss: the strongest
	# "rat, not lump" cue from behind, and it inherits the existing tail-sway
	# animation for free. Tilted so the back view sees a rising tail instead of
	# a ball seen end-on.
	var tail_root := Visual.sphere(model,Vector3(0,.42,.62),Vector3(.28,.3,.66),Palette.color(skin.snout))
	tail_root.rotation.x = -.5
	tail.append(tail_root)
	tail.append(Visual.sphere(model,Vector3(0,.72,1.0),Vector3(.2,.22,.26),Palette.color(skin.snout).darkened(.1)))
	# Mustache rides its own node so inertia and chewing can move it as a unit.
	# Head-local coordinates: the old model-space spot (0,1.74,-.62) minus
	# head_base (0,2.0,.06), since this node is parented to the head rig.
	var mouth := Node3D.new()
	mouth.position = Vector3(0,-.26,-.68)
	head.add_child(mouth)
	Visual.sphere(mouth,Vector3.ZERO,Vector3(.52,.16,.14),Palette.color(skin.mustache))
	# Winged mustache tips curl out to the sides for a stronger face profile.
	Visual.sphere(mouth,Vector3(-.42,.04,.02),Vector3(.2,.11,.12),Palette.color(skin.mustache))
	Visual.sphere(mouth,Vector3(.42,.04,.02),Vector3(.2,.11,.12),Palette.color(skin.mustache))
	Visual.sphere(mouth,Vector3(0,-.18,.06),Vector3(.4,.12,.1),Palette.color(skin.mustache).darkened(.12))
	Visual.sphere(model,Vector3(0,1.38,-.46),Vector3(.32,.12,.1),Palette.color(skin.hat_band))
	# Ladle is a group (handle + scoop) so states can raise, drag and flail it.
	var ladle := Node3D.new()
	var ladle_base := Vector3(1.35,1.7,-.2)
	ladle.position = ladle_base
	model.add_child(ladle)
	metal_box(model,Vector3.ZERO,Vector3(.07,.6,.07),Palette.color(skin.ladle),ladle)
	Visual.sphere(ladle,Vector3(0,-.36,0),Vector3(.16,.22,.16),Palette.color(skin.ladle))
	return {
		"torso": torso, "belly": belly, "head": head, "head_base": head_base,
		"eye_l": eye_l, "eye_r": eye_r, "pupil_l": pupil_l, "pupil_r": pupil_r,
		"pupil_base_l": pupil_base_l, "pupil_base_r": pupil_base_r,
		"eye_base_l": eye_base_l, "eye_base_r": eye_base_r,
		"pupil_scale_l": pupil_scale_l, "pupil_scale_r": pupil_scale_r,
		"ear_l": ear_l, "ear_r": ear_r, "tail": tail,
		"hat": hat, "hat_base": hat.position,
		"torch": null, "torch_base": Vector3.ZERO,
		"mouth": mouth, "ladle": ladle, "ladle_base": ladle_base,
		"arm_l": arm_l, "arm_r": arm_r,
	}


static func _dragon(model: Node3D) -> Dictionary:
	## MECHA DRAGON: all plating and ImmediateMesh wings, no head rig - the
	## lizard pilot rides in the chest cockpit and the body yaws as a whole.
	var tail: Array[MeshInstance3D] = []
	var steel := Color("1f6b68")
	var dark := Color("1d1526")
	var brass := Color("ffd24a")
	metal_box(model,Vector3(0,1.1,0),Vector3(1.5,1.6,1.0),steel)
	metal_box(model,Vector3(0,1.4,-.56),Vector3(1.1,1.0,.12),brass)
	metal_box(model,Vector3(0,1.4,-.65),Vector3(.88,.76,.1),Color("9ef0e4"))
	# The little lizard is visible through the chest cockpit.
	Visual.sphere(model,Vector3(0,1.45,-.77),Vector3(.5,.55,.2),Color("8bb86d"))
	for x in [-.12,.12]:
		Visual.sphere(model,Vector3(x,1.52,-.89),Vector3(.11,.11,.08),Color("f4e3a6"))
		Visual.sphere(model,Vector3(x,1.52,-.93),Vector3(.04,.07,.03),dark)
	metal_box(model,Vector3(0,2.0,-.3),Vector3(.7,.7,.7),dark)
	metal_box(model,Vector3(0,2.3,-.7),Vector3(1.05,.55,1.45),steel)
	metal_box(model,Vector3(0,1.94,-.94),Vector3(.92,.17,.93),brass)
	metal_box(model,Vector3(0,2.13,-1.38),Vector3(.83,.16,.06),Color("ffd27a"))
	for x in [-.39,.39]:
		Visual.sphere(model,Vector3(x,2.43,-1.27),Vector3(.2,.15,.09),Color("ffd27a"))
		horn(model,Vector3(x,2.97,-.28),.85,.14)
		metal_box(model,Vector3(x*1.9,.6,.08),Vector3(.45,1.1,.48),steel)
		metal_box(model,Vector3(x*1.9,.12,-.2),Vector3(.65,.25,.85),dark)
		metal_box(model,Vector3(x*2.4,1.25,-.16),Vector3(.3,.95,.4),brass)
		for z in [-.48,-.18]:
			metal_box(model,Vector3(x*1.9,.14,z),Vector3(.12,.14,.36),brass)
	for i in range(5):
		metal_box(model,Vector3(0,.72-i*.09,.7+i*.35),Vector3(.48-i*.06,.4-i*.05,.5),steel)
		horn(model,Vector3(0,1.1-i*.07,.75+i*.35),.34,.13)
	for side in [-1,1]:
		var vertices := [Vector3(side*.6,1.9,.35),Vector3(side*2.7,2.8,.5),Vector3(side*2.1,1.4,1.8),Vector3(side*.6,1.9,.35),Vector3(side*2.1,1.4,1.8),Vector3(side*.85,1.25,1.1)]
		var mesh := ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.albedo_color=Color("1f6b68")
		mat.metallic=.4
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,mat)
		for i in range(0,6,3):
			var normal: Vector3=(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).normalized()
			for j in range(3):
				mesh.surface_set_normal(normal)
				mesh.surface_add_vertex(vertices[i+j])
		mesh.surface_end()
		var wing := MeshInstance3D.new()
		wing.mesh=mesh
		model.add_child(wing)
		var spar := metal_box(model,Vector3(side*1.6,2.35,.45),Vector3(2.4,.12,.12),brass)
		spar.rotation.z=side*.38
	return {
		"torso": null, "belly": null, "head": null, "head_base": Vector3.ZERO,
		"eye_l": null, "eye_r": null, "pupil_l": null, "pupil_r": null,
		"pupil_base_l": Vector3.ZERO, "pupil_base_r": Vector3.ZERO,
		"eye_base_l": Vector3.ONE, "eye_base_r": Vector3.ONE,
		"pupil_scale_l": Vector3.ONE, "pupil_scale_r": Vector3.ONE,
		"ear_l": null, "ear_r": null, "tail": tail,
		"hat": null, "hat_base": Vector3.ZERO,
		"torch": null, "torch_base": Vector3.ZERO,
		"mouth": null, "ladle": null, "ladle_base": Vector3.ZERO,
		"arm_l": null, "arm_r": null,
	}