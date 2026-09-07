extends CharacterBody3D
## Server-driven patrol, pursuit, wind-up, charge, stun and boss phases.
const Visual = preload("res://scripts/heist/slime_visual.gd")
const Materials = preload("res://scripts/visuals/character_materials.gd")
const Palette = preload("res://scripts/visuals/palette.gd")
const Vfx = preload("res://scripts/visuals/vfx.gd")
var world: Node3D
var home := Vector3.ZERO
var patrol: Array[Vector3] = []
var patrol_index := 0
var hp := 70.0
var max_hp := 70.0
var boss := false
var tier := 0
var state := "PATROL"
var timer := 0.0
var attack_timer := 0.0
var bribe_time := 0.0
var path_timer := 0.0
var path: PackedVector3Array = []
var charge_dir := Vector3.ZERO
var model: Node3D
var title: Label3D
var tell: MeshInstance3D
var aura: MeshInstance3D
var hat: Node3D
var target_position := Vector3.ZERO
# Animatable part references captured during the build functions, so _process
# can pose the character from local state only (nothing here is networked).
var torso: MeshInstance3D
var belly: MeshInstance3D
var head: Node3D
var head_base := Vector3.ZERO
var eye_l: MeshInstance3D
var eye_r: MeshInstance3D
var pupil_l: MeshInstance3D
var pupil_r: MeshInstance3D
var pupil_base_l := Vector3.ZERO
var pupil_base_r := Vector3.ZERO
var ear_l: Node3D
var ear_r: Node3D
var tail: Array[MeshInstance3D] = []
var ladle: Node3D
var ladle_base := Vector3.ZERO
var torch: Node3D
var torch_base := Vector3.ZERO
var mouth: Node3D
var arm_l: MeshInstance3D
var arm_r: MeshInstance3D
var stars: Node3D
var bribe_ring: MeshInstance3D
var bribe_base := 0.0
var aura_mat: StandardMaterial3D
var tell_mat: StandardMaterial3D
var base_scale := Vector3.ONE
# Performance springs and clocks, all local.
var anim_time := 0.0
var step_phase := 0.0
var squash := Vector3.ONE
var squash_vel := Vector3.ZERO
var lean := 0.0
var roll := 0.0
var hat_pose := Vector2.ZERO
var hat_pop := 0.0
var eye_open := 1.0
var anger_amt := 0.0
var wind_amt := 0.0
var low_hp_amt := 0.0
var spin := 0.0
var glance := 0.0
var glance_target := 0.0
var glance_timer := 0.0
var last_state := "PATROL"
var last_hp := 0.0
var last_vis_pos := Vector3.ZERO
var vis_speed := 0.0
var dust_clock := 0.0
var aura_glow := 1.0

func setup(owner_world: Node3D, origin: Vector3, is_boss: bool, species: int) -> void:
	world = owner_world
	home = origin
	position = origin
	boss = is_boss
	tier = species
	max_hp = (380.0 + tier*150) if boss else (60.0+tier*20)
	hp = max_hp
	last_hp = hp
	patrol = [origin, origin+Vector3(0,0,5),origin+Vector3(0,0,-3)]
	collision_layer = 8
	collision_mask = 2
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.0 if boss else .45
	capsule.height = 3.0 if boss else 1.8
	collision.shape = capsule
	collision.position.y = capsule.height*.5
	add_child(collision)
	model = Node3D.new()
	add_child(model)
	if tier == 3:
		build_dragon()
	elif boss and tier == 0:
		build_chef()
	else:
		build_guard(species, 1.5 if boss else 1.0)
	base_scale = model.scale
	last_vis_pos = origin
	# Stun stars orbit overhead only while STUNNED; the mold-green halo marks
	# a bribed guard. Both are cosmetic siblings of the tell ring.
	stars = Node3D.new()
	stars.position.y = 5.0 if (boss and tier == 0) else (4.2 if boss else 3.0)
	add_child(stars)
	var star_mat := Materials.lit(Color("ffd24a"),1.4)
	for i in range(3):
		var star := MeshInstance3D.new()
		var star_mesh := SphereMesh.new()
		star_mesh.radius = .14
		star_mesh.height = .28
		star_mesh.radial_segments = 8
		star_mesh.rings = 5
		star.mesh = star_mesh
		star.material_override = star_mat
		stars.add_child(star)
	stars.visible = false
	bribe_ring = MeshInstance3D.new()
	var halo := CylinderMesh.new()
	halo.top_radius = .9 if boss else .55
	halo.bottom_radius = halo.top_radius
	halo.height = .04
	bribe_ring.mesh = halo
	bribe_base = 4.6 if (boss and tier == 0) else (3.9 if boss else 2.95)
	bribe_ring.position.y = bribe_base
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(.498,.682,.239,.55)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(.498,.682,.239)
	halo_mat.emission_energy_multiplier = 1.2
	bribe_ring.material_override = halo_mat
	add_child(bribe_ring)
	bribe_ring.visible = false
	title = Label3D.new()
	title.position.y = 4.5 if boss else 2.6
	title.font_size = 20
	title.pixel_size = .008
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.outline_size = 6
	add_child(title)
	if boss:
		# Pulsing aggro aura: a sibling ring of tell, never replacing it.
		var aura_ring := CylinderMesh.new()
		aura_ring.top_radius = 2.85
		aura_ring.bottom_radius = 2.85
		aura_ring.height = .02
		aura = MeshInstance3D.new()
		aura.mesh = aura_ring
		aura.position.y = .05
		aura_mat = StandardMaterial3D.new()
		aura_mat.albedo_color = Color(1,.37,.66,.25)
		aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		aura_mat.emission_enabled = true
		aura_mat.emission = Color(1,.37,.66)
		aura_mat.emission_energy_multiplier = 1.1
		aura.material_override = aura_mat
		add_child(aura)
	var ring := CylinderMesh.new()
	ring.top_radius = 2.6 if boss else 1.2
	ring.bottom_radius = ring.top_radius
	ring.height = .025
	tell = MeshInstance3D.new()
	tell.mesh = ring
	tell.position.y = .03
	tell_mat = StandardMaterial3D.new()
	tell_mat.albedo_color = Color(1,.25,.08,.38)
	tell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tell_mat.emission_enabled = true
	tell_mat.emission = Color(1,.12,.015)
	tell.material_override = tell_mat
	add_child(tell)

func build_guard(tier: int, scale_factor: float) -> void:
	## Species-dressed chunky guard: shared sphere base plus a kit per species,
	## colored from the shared guard palette. The face is a head rig so glances
	## carry eyes, muzzle and species face parts together.
	model.scale = Vector3.ONE*scale_factor
	var skin: Dictionary = Palette.GUARD[tier]
	var body: Color = Palette.color(skin.body)
	var cream := Palette.color("fdf3d0")
	torso = Visual.sphere(model,Vector3(0,.8,0),Vector3(1.25,1.55,.95),body)
	head = Node3D.new()
	head_base = Vector3(0,1.72,.08)
	head.position = head_base
	model.add_child(head)
	Visual.sphere(head,Vector3.ZERO,Vector3(1.05,.9,.9),body)
	Visual.sphere(head,Vector3(0,-.27,-.53),Vector3(.58,.34,.62),Palette.color(skin.belly))
	for x in [-.264,.264]:
		var white := Visual.sphere(head,Vector3(x,.1,-.54),Vector3(.26,.28,.13),cream)
		var pupil := Visual.sphere(head,Vector3(x,.1,-.62),Vector3(.12,.17,.08),Palette.color(skin.pupil))
		if x < 0.0:
			eye_l = white
			pupil_l = pupil
			pupil_base_l = pupil.position
		else:
			eye_r = white
			pupil_r = pupil
			pupil_base_r = pupil.position
	for x in [-.616,.616]:
		var arm := Visual.sphere(model,Vector3(x,.9,0),Vector3(.26,.72,.3),body.darkened(.12))
		if x < 0.0:
			arm_l = arm
		else:
			arm_r = arm
	Visual.sphere(model,Vector3(-.279,.14,-.1),Vector3(.42,.28,.66),body.darkened(.24))
	Visual.sphere(model,Vector3(.279,.14,-.1),Vector3(.42,.28,.66),body.darkened(.24))
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

func build_chef() -> void:
	## THE BIG CHEESE: fat, flour-dusted, mustachioed. Fat-and-short proportions
	## that stay inside the boss capsule's 2.0 width. Face parts hang off a head
	## rig so glances and expressions pose the whole face at once.
	model.scale = Vector3(1.3,1.1,1.3)
	var skin: Dictionary = Palette.BOSS
	var body: Color = Palette.color(skin.body)
	var cream := Palette.color("fdf3d0")
	torso = Visual.sphere(model,Vector3(0,.62,0),Vector3(1.5,1.35,1.2),body)
	belly = Visual.sphere(model,Vector3(0,1.5,0),Vector3(1.15,.8,.95),Palette.color(skin.belly))
	head = Node3D.new()
	head_base = Vector3(0,2.0,.06)
	head.position = head_base
	model.add_child(head)
	Visual.sphere(head,Vector3.ZERO,Vector3(.95,.8,.85),body)
	Visual.sphere(head,Vector3(0,-.1,-.56),Vector3(.5,.3,.55),Palette.color(skin.snout))
	for x in [-.4,.4]:
		var white := Visual.sphere(head,Vector3(x*.55,.12,-.56),Vector3(.24,.26,.12),cream)
		var pupil := Visual.sphere(head,Vector3(x*.55,.12,-.64),Vector3(.11,.16,.07),Palette.color("1b2b33"))
		if x < 0.0:
			eye_l = white
			pupil_l = pupil
			pupil_base_l = pupil.position
		else:
			eye_r = white
			pupil_r = pupil
			pupil_base_r = pupil.position
		var arm := Visual.sphere(model,Vector3(x*1.35,.85,0),Vector3(.3,.75,.32),body.darkened(.12))
		if x < 0.0:
			arm_l = arm
		else:
			arm_r = arm
		Visual.sphere(model,Vector3(x*.62,.12,-.05),Vector3(.45,.22,.62),body.darkened(.24))
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
	# where the old white sphere stack just read as a lump.
	hat = Node3D.new()
	model.add_child(hat)
	var toque := MeshInstance3D.new()
	var toque_mesh := CylinderMesh.new()
	toque_mesh.top_radius=.4
	toque_mesh.bottom_radius=.32
	toque_mesh.height=1.2
	toque_mesh.radial_segments=12
	toque.mesh=toque_mesh
	toque.position=Vector3(0,3.32,0)
	toque.material_override=Materials.part(Palette.color(skin.hat))
	hat.add_child(toque)
	Visual.sphere(hat,Vector3(0,3.98,0),Vector3(.9,.42,.84),Palette.color(skin.hat))
	Visual.sphere(hat,Vector3(0,2.74,0),Vector3(.88,.22,.82),Palette.color(skin.hat_band))
	Visual.sphere(model,Vector3(0,.9,-.6),Vector3(1.05,1.05,.12),Palette.color(skin.apron))
	Visual.sphere(model,Vector3(-.35,.9,-.68),Vector3(.05,1.0,.05),Palette.color(skin.strap))
	Visual.sphere(model,Vector3(.35,.9,-.68),Vector3(.05,1.0,.05),Palette.color(skin.strap))
	# Mustache rides its own node so inertia and chewing can move it as a unit.
	mouth = Node3D.new()
	mouth.position = Vector3(0,1.74,-.62)
	head.add_child(mouth)
	Visual.sphere(mouth,Vector3.ZERO,Vector3(.52,.16,.14),Palette.color(skin.mustache))
	# Winged mustache tips curl out to the sides for a stronger face profile.
	Visual.sphere(mouth,Vector3(-.42,.04,.02),Vector3(.2,.11,.12),Palette.color(skin.mustache))
	Visual.sphere(mouth,Vector3(.42,.04,.02),Vector3(.2,.11,.12),Palette.color(skin.mustache))
	Visual.sphere(mouth,Vector3(0,-.18,.06),Vector3(.4,.12,.1),Palette.color(skin.mustache).darkened(.12))
	Visual.sphere(model,Vector3(0,1.38,-.46),Vector3(.32,.12,.1),Palette.color(skin.hat_band))
	# Ladle is a group (handle + scoop) so states can raise, drag and flail it.
	ladle = Node3D.new()
	ladle_base = Vector3(1.35,1.7,-.2)
	ladle.position = ladle_base
	model.add_child(ladle)
	metal_box(Vector3.ZERO,Vector3(.07,.6,.07),Palette.color(skin.ladle),ladle)
	Visual.sphere(ladle,Vector3(0,-.36,0),Vector3(.16,.22,.16),Palette.color(skin.ladle))

func _process(delta: float) -> void:
	visible = hp > 0
	if not visible:
		return
	anim_time += delta
	var names := ["THE BIG CHEESE","FOREMAN TUSK","MADAM MAGPIE","MECHA DRAGON"]
	# Boss names live in the HUD boss bar; floating text on any guard stays
	# name-and-hp only so the field never grows debug readouts.
	title.visible = not boss
	title.text = (names[tier] if boss else ["Rat security","Boar security","Magpie security","Lizard security"][tier]) + "  %d/%d" % [ceili(hp),int(max_hp)]
	title.modulate = Color("ffbb81") if boss else Color("d8dda9")
	tell.visible = state in ["WIND UP","CHARGE","FIRE BREATH"]
	# State-transition beats: instant, readable reactions.
	if state != last_state:
		if state == "STUNNED":
			squash_vel += Vector3(5.0,-8.0,5.0)
			hat_pop = 1.0
			spin = 8.0
		elif state == "HUNT" and last_state == "PATROL":
			squash_vel.y += 2.4  # startle hop when the guard spots you
		elif state == "WIND UP":
			squash_vel.y -= 2.0
		last_state = state
	if hp < last_hp - .5:
		squash_vel += Vector3(2.4,-2.8,2.4)  # hit flinch
	if hp != last_hp:
		last_hp = hp
	# Motion is read from real displacement, so remote clients animate exactly
	# like the host (their physics velocity is always zero).
	var vel := (global_position - last_vis_pos)/maxf(delta,.0001)
	vel.y = 0.0
	last_vis_pos = global_position
	vis_speed = lerpf(vis_speed,vel.length(),1.0-exp(-10.0*delta))
	var yaw := model.rotation.y
	var forward := Vector3(-sin(yaw),0,-cos(yaw))
	var right := Vector3(cos(yaw),0,-sin(yaw))
	var fwd_speed: float = vel.dot(forward)
	var side_speed: float = vel.dot(right)
	var moving := clampf(vis_speed/2.5,0.0,1.0)
	var weight := 1.0
	if boss and tier == 0:
		weight = 1.35
	elif tier == 3:
		weight = 1.4
	elif boss:
		weight = 1.2
	else:
		weight = [0.8,1.2,0.55,0.9][tier]
	# --- Body: step-locked squash and state lean (the de-slide).
	step_phase += delta*(3.2+vis_speed*1.9)/maxf(.75,weight)
	if state == "BRIBED":
		step_phase += delta*6.0
	var step := maxf(0.0,sin(step_phase))
	var y_amt := 1.0 - step*.075*weight*moving
	var xz_amt := 1.0 + step*.045*weight*moving
	var hp_ratio := hp/max_hp
	low_hp_amt = lerpf(low_hp_amt,1.0 if hp_ratio < .35 and state != "BRIBED" else 0.0,1.0-exp(-3.0*delta))
	y_amt += sin(anim_time*(2.2+3.5*low_hp_amt))*(.008+.02*low_hp_amt)
	wind_amt = lerpf(wind_amt,1.0 if state == "WIND UP" else 0.0,1.0-exp(-12.0*delta))
	match state:
		"WIND UP":
			y_amt = .84
			xz_amt = 1.09
		"CHARGE":
			y_amt = .9
			xz_amt = 1.1
	squash_vel += ((Vector3(xz_amt,y_amt,xz_amt)-squash)*110.0 - squash_vel*10.5)*delta
	squash += squash_vel*delta
	model.scale = base_scale*squash
	# --- Lean, roll and lunge derived from observed velocity and state.
	var lean_target := clampf(fwd_speed*.018,-.12,.12)
	match state:
		"HUNT":
			lean_target = maxf(lean_target,.1)+clampf(fwd_speed*.01,0.0,.06)
		"WIND UP":
			lean_target = -.17
		"CHARGE", "FIRE BREATH":
			lean_target = .3 if state == "CHARGE" else .12
	lean = lerpf(lean,lean_target,1.0-exp(-7.0*delta))
	var roll_target := clampf(-side_speed*.03,-.09,.09)
	if state == "STUNNED":
		roll_target = sin(anim_time*5.2)*.09
	roll = lerpf(roll,roll_target,1.0-exp(-6.0*delta))
	model.rotation.x = -lean
	model.rotation.z = roll
	# --- Bob, breathing, state offsets.
	var bob := absf(sin(step_phase))*.07*weight*moving
	var pos := Vector3(0.0,sin(anim_time*(2.2+3.5*low_hp_amt))*.012*(1.0-moving),0.0)
	if state != "STUNNED":
		pos.y += absf(sin(step_phase))*.07*weight*moving
	if state == "WIND UP":
		pos.y -= .12*wind_amt
		pos.z += .1*wind_amt
		pos += Vector3(sin(anim_time*43.0),0.0,cos(anim_time*37.0))*.012*wind_amt  # quiver
	elif state == "CHARGE":
		pos.z = -.16
		pos.y = bob*.4
	elif state == "BRIBED":
		pos.y += absf(sin(anim_time*5.0))*.05
	model.position = pos
	# --- Face rig: glances while patrolling, focus while hunting.
	glance_timer -= delta
	if glance_timer <= 0.0:
		glance_timer = randf_range(1.8,3.4)
		glance_target = randf_range(-.5,.5)
	glance = lerpf(glance,glance_target,1.0-exp(-5.0*delta))
	if head:
		head.position.y = head_base.y
		if state == "PATROL":
			head.rotation.y = glance
			head.rotation.x = sin(anim_time*.9)*.04
		elif state == "HUNT":
			head.rotation.y = glance*.25
			head.rotation.x = .1
		elif state == "WIND UP":
			head.rotation = Vector3(-.08,glance*.1,0)
		elif state == "BRIBED":
			head.position.y = head_base.y + absf(sin(anim_time*9.0))*.045  # chewing
			head.rotation = Vector3.ZERO
		else:
			head.rotation = Vector3.ZERO
	# --- Expressions: eye openness plus anger, crossed spinning eyes when stunned.
	var open_target := 1.0
	var anger := 0.0
	match state:
		"HUNT":
			open_target = 1.18
		"WIND UP":
			open_target = .42
			anger = .7
		"CHARGE":
			open_target = 1.25
			anger = .4
		"STUNNED":
			open_target = .35
		"BRIBED":
			open_target = .5
	eye_open = lerpf(eye_open,open_target,1.0-exp(-10.0*delta))
	anger_amt = lerpf(anger_amt,anger,1.0-exp(-8.0*delta))
	spin = maxf(0.0,spin-delta*3.2)
	var cross := clampf(spin*.12,0.0,1.0)
	if eye_l and eye_r:
		eye_l.scale.y = eye_open
		eye_r.scale.y = eye_open
		eye_l.rotation.z = -anger_amt*.22 - spin*.5
		eye_r.rotation.z = anger_amt*.22 + spin*.5
	if pupil_l and pupil_r:
		pupil_l.position.x = pupil_base_l.x*(1.0-cross*.8)
		pupil_r.position.x = pupil_base_r.x*(1.0-cross*.8)
		pupil_l.scale = Vector3.ONE*(1.0+anger_amt*.3)
		pupil_r.scale = Vector3.ONE*(1.0+anger_amt*.3)
	# --- Secondary motion: hat inertia, ear lag, tail sway, tool business.
	hat_pose = hat_pose.lerp(Vector2(-lean*1.4,roll*1.5),1.0-exp(-5.0*delta))
	if hat:
		hat_pop = maxf(0.0,hat_pop-delta*2.4)
		var hat_tilt := .22 if state == "CHARGE" else (-.2 if state == "WIND UP" else 0.0)
		hat.rotation = Vector3(
			cos(anim_time*1.9)*.04+hat_pose.x+hat_tilt+.2*low_hp_amt*.5,
			0.0,
			sin(anim_time*2.3)*.055+hat_pose.y+.15*low_hp_amt+spin*.3)
		hat.position.y = hat_pop*.5
	if ear_l and ear_r:
		var lag := clampf(side_speed*.15,-.25,.25)
		ear_l.rotation = Vector3(.25*wind_amt,0.0,lag+sin(anim_time*3.1)*.03)
		ear_r.rotation = Vector3(.25*wind_amt,0.0,-lag-sin(anim_time*3.1+1.0)*.03)
	for i in tail.size():
		tail[i].rotation.y = sin(anim_time*(9.0 if state == "BRIBED" else 2.4)-i*.9)*(.4 if state == "BRIBED" else .12)
		tail[i].rotation.x = sin(anim_time*1.7-i*.6)*.06
	if ladle:
		var lrot := .5+sin(anim_time*1.7)*.06
		var llift := 0.0
		match state:
			"HUNT":
				lrot = -.6
				llift = .18
			"WIND UP":
				lrot = .9
				llift = .05
			"CHARGE":
				lrot = -1.1+sin(step_phase*2.0)*.25
				llift = .1
		ladle.rotation.x = lerpf(ladle.rotation.x,lrot,1.0-exp(-8.0*delta))
		ladle.position.y = lerpf(ladle.position.y,ladle_base.y+llift,1.0-exp(-8.0*delta))
	if mouth:
		mouth.rotation.x = hat_pose.x*.8+spin*.4
	if torch:
		torch.rotation.z = sin(step_phase*.5)*.1*moving+sin(anim_time*2.6)*.04
		torch.position.y = lerpf(torch.position.y,torch_base.y+(.12 if state == "HUNT" else 0.0),1.0-exp(-6.0*delta))
	if arm_l and arm_r:
		var swing := sin(step_phase)*.45*moving
		arm_l.rotation.x = swing
		arm_r.rotation.x = -swing
	# --- Aura and tell ring heat up through the attack telegraph.
	var aggro := 1.0
	if state == "WIND UP":
		aggro = 1.9
	elif state == "CHARGE":
		aggro = 2.3
	aura_glow = lerpf(aura_glow,aggro,1.0-exp(-8.0*delta))
	if aura:
		aura.scale = Vector3.ONE*(1.0+sin(anim_time*(9.0 if aggro > 1.2 else 3.0))*(.03+.05*aura_glow))
		aura_mat.emission_energy_multiplier = .9*aura_glow+sin(anim_time*(6.0 if aggro > 1.2 else 3.0))*.15
	if tell:
		tell.scale = Vector3.ONE*(1.0+sin(anim_time*(10.0 if aggro > 1.2 else 0.0))*(.02+.06*(aura_glow-1.0)))
	stars.visible = state == "STUNNED"
	if stars.visible:
		for i in range(stars.get_child_count()):
			var star_node := stars.get_child(i) as MeshInstance3D
			var a := anim_time*6.5+i*2.09
			star_node.position = Vector3(cos(a)*.55,sin(a*1.7)*.1,sin(a)*.35)
	bribe_ring.visible = state == "BRIBED"
	if bribe_ring.visible:
		bribe_ring.position.y = bribe_base+sin(anim_time*3.0)*.08
		bribe_ring.rotation.y = anim_time*3.0
	# Charging enemies kick up dust behind them.
	if state == "CHARGE" and vis_speed > 4.0:
		dust_clock -= delta
		if dust_clock <= 0.0:
			dust_clock = .11
			Vfx.dust(self,global_position+Vector3.UP*.15,1.1 if boss else .7)
	if not multiplayer.is_server():
		position = position.lerp(target_position, minf(1,delta*15))

func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or hp<=0:
		return
	if not world.session_active:
		return
	attack_timer -= delta
	bribe_time -= delta
	timer -= delta
	path_timer -= delta
	velocity.y -= 20*delta
	var target: Node3D = world.find_target(global_position, 24 if boss else 13,tier,boss)
	if state == "STUNNED":
		velocity.x = 0
		velocity.z = 0
		if timer<=0:
			state="HUNT"
	elif bribe_time>0:
		state="BRIBED"
		velocity.x=0
		velocity.z=0
	elif state=="WIND UP":
		velocity.x=0
		velocity.z=0
		if timer<=0:
			state="CHARGE"
			timer=1.1
	elif state=="CHARGE":
		velocity.x=charge_dir.x*(19 if boss else 10)
		velocity.z=charge_dir.z*(19 if boss else 10)
		for player in world.live_players():
			if player.global_position.distance_to(global_position)<(3 if boss else 1.8):
				world.hurt_player(int(str(player.name)),28+tier*5,charge_dir*10)
		if timer<=0 or is_on_wall():
			state="STUNNED"
			timer=2.2
			if is_on_wall():
				world.fx.rpc(global_position+Vector3.UP*(2.0 if boss else 1.1),Color("f2d98b"),2.6 if boss else 1.3)
				if boss:
					take_damage(15)
	elif target:
		state="HUNT"
		var offset: Vector3 = target.global_position-global_position
		offset.y=0
		if boss and attack_timer<=0 and offset.length()<17:
			charge_dir=offset.normalized()
			model.rotation.y=atan2(-charge_dir.x,-charge_dir.z)
			state="WIND UP"
			timer=1.15 if hp>max_hp*.45 else .7
			attack_timer=4.8 if hp>max_hp*.45 else 3.2
			if tier==3 and randf()<.5:
				world.fire_breath(global_position,charge_dir,str(name))
		elif offset.length()<1.7 and attack_timer<=0:
			world.hurt_player(int(str(target.name)),10+tier*3,offset.normalized()*3)
			attack_timer=1.3
		elif path_timer<=0:
			path=world.route(global_position,target.global_position)
			path_timer=.6
		steer(delta,offset,3.6+tier*.35+(1.3 if world.alarm>65 else 0))
	else:
		state="PATROL"
		var destination: Vector3 = patrol[patrol_index]
		var bait: Vector3 = world.nearby_bait(global_position)
		if bait != Vector3.INF:
			destination=bait
		var offset := destination-global_position
		offset.y=0
		if offset.length()<.6:
			patrol_index=(patrol_index+1)%patrol.size()
			if bait!=Vector3.INF:
				bribe_time=6
		steer(delta,offset,1.6)
	move_and_slide()
	if Vector2(velocity.x,velocity.z).length()>.2:
		model.rotation.y=lerp_angle(model.rotation.y,atan2(-velocity.x,-velocity.z),delta*8)
	if global_position.y < -20:
		global_position=home

func steer(_delta: float, direction: Vector3, speed: float) -> void:
	if path.size()>0 and state=="HUNT":
		while path.size()>0 and global_position.distance_to(path[0])<1.1:
			path.remove_at(0)
		if path.size()>0:
			direction=path[0]-global_position
	direction.y=0
	direction=direction.normalized()
	velocity.x=direction.x*speed
	velocity.z=direction.z*speed

func take_damage(amount: float) -> void:
	if hp<=0:
		return
	hp=maxf(0,hp-amount)
	world.alarm=minf(100,world.alarm+8)
	if hp<=0:
		world.enemy_defeated(self)

func metal_box(pos: Vector3,size: Vector3,color: Color,parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	part.mesh=mesh
	part.position=pos
	part.material_override=Materials.metal(color)
	(parent if parent else model).add_child(part)
	return part

func horn(parent: Node3D,pos: Vector3,height: float,radius: float) -> void:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius=0
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=8
	part.mesh=mesh
	part.position=pos
	part.material_override=Materials.metal(Color("ffd24a"))
	parent.add_child(part)

func build_dragon() -> void:
	var steel := Color("1f6b68")
	var dark := Color("1d1526")
	var brass := Color("ffd24a")
	metal_box(Vector3(0,1.1,0),Vector3(1.5,1.6,1.0),steel)
	metal_box(Vector3(0,1.4,-.56),Vector3(1.1,1.0,.12),brass)
	metal_box(Vector3(0,1.4,-.65),Vector3(.88,.76,.1),Color("9ef0e4"))
	# The little lizard is visible through the chest cockpit.
	Visual.sphere(model,Vector3(0,1.45,-.77),Vector3(.5,.55,.2),Color("8bb86d"))
	for x in [-.12,.12]:
		Visual.sphere(model,Vector3(x,1.52,-.89),Vector3(.11,.11,.08),Color("f4e3a6"))
		Visual.sphere(model,Vector3(x,1.52,-.93),Vector3(.04,.07,.03),dark)
	metal_box(Vector3(0,2.0,-.3),Vector3(.7,.7,.7),dark)
	metal_box(Vector3(0,2.3,-.7),Vector3(1.05,.55,1.45),steel)
	metal_box(Vector3(0,1.94,-.94),Vector3(.92,.17,.93),brass)
	metal_box(Vector3(0,2.13,-1.38),Vector3(.83,.16,.06),Color("ffd27a"))
	for x in [-.39,.39]:
		Visual.sphere(model,Vector3(x,2.43,-1.27),Vector3(.2,.15,.09),Color("ffd27a"))
		horn(model,Vector3(x,2.97,-.28),.85,.14)
		metal_box(Vector3(x*1.9,.6,.08),Vector3(.45,1.1,.48),steel)
		metal_box(Vector3(x*1.9,.12,-.2),Vector3(.65,.25,.85),dark)
		metal_box(Vector3(x*2.4,1.25,-.16),Vector3(.3,.95,.4),brass)
		for z in [-.48,-.18]:
			metal_box(Vector3(x*1.9,.14,z),Vector3(.12,.14,.36),brass)
	for i in range(5):
		metal_box(Vector3(0,.72-i*.09,.7+i*.35),Vector3(.48-i*.06,.4-i*.05,.5),steel)
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
		var spar := metal_box(Vector3(side*1.6,2.35,.45),Vector3(2.4,.12,.12),brass)
		spar.rotation.z=side*.38