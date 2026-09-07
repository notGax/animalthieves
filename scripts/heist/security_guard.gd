extends CharacterBody3D
## Server-driven patrol, pursuit, wind-up, charge, stun and boss phases.
const Visual = preload("res://scripts/heist/slime_visual.gd")
const Materials = preload("res://scripts/visuals/character_materials.gd")
const Palette = preload("res://scripts/visuals/palette.gd")
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

func setup(owner_world: Node3D, origin: Vector3, is_boss: bool, species: int) -> void:
	world = owner_world
	home = origin
	position = origin
	boss = is_boss
	tier = species
	max_hp = (380.0 + tier*150) if boss else (60.0+tier*20)
	hp = max_hp
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
		var aura_mat := StandardMaterial3D.new()
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1,.25,.08,.38)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1,.12,.015)
	tell.material_override = mat
	add_child(tell)

func build_guard(tier: int, scale_factor: float) -> void:
	## Species-dressed chunky guard: shared sphere base plus a kit per species,
	## colored from the shared guard palette.
	model.scale = Vector3.ONE*scale_factor
	var skin: Dictionary = Palette.GUARD[tier]
	var body: Color = Palette.color(skin.body)
	var cream := Palette.color("fdf3d0")
	Visual.sphere(model,Vector3(0,.8,0),Vector3(1.25,1.55,.95),body)
	Visual.sphere(model,Vector3(0,1.72,.08),Vector3(1.05,.9,.9),body)
	Visual.sphere(model,Vector3(0,1.45,-.45),Vector3(.58,.34,.62),Palette.color(skin.belly))
	for x in [-.44,.44]:
		Visual.sphere(model,Vector3(x*.6,1.82,-.46),Vector3(.26,.28,.13),cream)
		Visual.sphere(model,Vector3(x*.6,1.82,-.54),Vector3(.12,.17,.08),Palette.color(skin.pupil))
		Visual.sphere(model,Vector3(x*1.4,.9,0),Vector3(.26,.72,.3),body.darkened(.12))
		Visual.sphere(model,Vector3(x*.62,.14,-.1),Vector3(.42,.28,.66),body.darkened(.24))
	match tier:
		0:  # Rat: turquoise vest, plum cap with badge, big ears, banded tail, torch.
			Visual.sphere(model,Vector3(0,1.0,-.48),Vector3(1.02,.82,.5),Palette.color(skin.vest))
			Visual.sphere(model,Vector3(0,2.3,.02),Vector3(.92,.42,.88),Palette.color(skin.cap))
			Visual.sphere(model,Vector3(0,2.24,-.44),Vector3(.5,.07,.26),Palette.color(skin.cap).darkened(.1))
			Visual.sphere(model,Vector3(.4,2.34,.02),Vector3(.1,.06,.1),Palette.color(skin.badge))
			for x in [-.66,.66]:
				Visual.sphere(model,Vector3(x,2.62,.04),Vector3(.46,.52,.18),Palette.color(skin.ear))
				Visual.sphere(model,Vector3(x,2.62,-.05),Vector3(.3,.36,.12),Palette.color(skin.snout))
			Visual.sphere(model,Vector3(.3,.2,.72),Vector3(.18,.2,1.25),Palette.color(skin.snout))
			Visual.sphere(model,Vector3(.3,.2,1.0),Vector3(.21,.23,.16),Palette.color(skin.vest).darkened(.2))
			Visual.sphere(model,Vector3(-.75,1.1,-.35),Vector3(.12,.12,.42),Palette.color(skin.cap))
			Visual.sphere(model,Vector3(-.75,1.1,-.6),Vector3(.09,.09,.06),Palette.color(skin.badge))
		1:  # Boar: hard hat, shoulder pads, tusks, hi-vis vest stripe.
			Visual.sphere(model,Vector3(0,2.32,0),Vector3(.85,.4,.8),Palette.color(skin.cap))
			Visual.sphere(model,Vector3(0,2.44,0),Vector3(.88,.28,.84),Palette.color(skin.cap).darkened(.15))
			Visual.sphere(model,Vector3(0,2.3,-.4),Vector3(.55,.06,.3),Palette.color(skin.cap).darkened(.15))
			for x in [-.78,.78]:
				Visual.sphere(model,Vector3(x,1.9,.05),Vector3(.42,.3,.5),Palette.color(skin.snout).darkened(.1))
			Visual.sphere(model,Vector3(0,1.0,-.48),Vector3(1.0,.8,.48),Palette.color(skin.vest))
			Visual.sphere(model,Vector3(0,1.0,-.72),Vector3(.88,.18,.1),cream)
			Visual.sphere(model,Vector3(-.28,1.5,-.78),Vector3(.09,.09,.3),Palette.color(skin.tusk))
			Visual.sphere(model,Vector3(.28,1.5,-.78),Vector3(.09,.09,.3),Palette.color(skin.tusk))
		2:  # Magpie: glossy wings, conical beak, tail fan, swept crest.
			for x in [-1.05,1.05]:
				Visual.sphere(model,Vector3(x,1.15,.12),Vector3(.5,.68,.8),Palette.color(skin.wing))
				Visual.sphere(model,Vector3(x*1.1,.62,.72),Vector3(.26,.09,.45),Palette.color(skin.wing))
			Visual.sphere(model,Vector3(0,1.55,-.88),Vector3(.3,.26,.28),Palette.color(skin.beak))
			Visual.sphere(model,Vector3(0,1.5,-1.08),Vector3(.1,.1,.3),Palette.color(skin.beak).darkened(.15))
			for i in range(3):
				Visual.sphere(model,Vector3(-.2+i*.2,2.42-i*.04,.3),Vector3(.1,.3,.1),Palette.color(skin.wing))
			for i in range(3):
				var side: float = -1.0+i
				Visual.sphere(model,Vector3(side*.3,.45,.55),Vector3(.2,.08,.6),Palette.color(skin.wing))
		3:  # Lizard: belly plates, emissive visor, dorsal spikes, claws.
			var visor := Visual.sphere(model,Vector3(0,1.88,-.68),Vector3(.78,.22,.16),Palette.color(skin.visor))
			visor.material_override = Materials.lit(Palette.color(skin.visor),1.2)
			for i in range(3):
				Visual.sphere(model,Vector3(0,1.28-i*.36,-.5),Vector3(.5-i*.08,.12,.3),Palette.color(skin.belly))
			for i in range(4):
				horn(Vector3(0,2.1-i*.13,.28-i*.3),.42-i*.06,.12)
			for x in [-.62,.62]:
				Visual.sphere(model,Vector3(x,.14,-.32),Vector3(.1,.08,.2),cream)

func build_chef() -> void:
	## THE BIG CHEESE: fat, flour-dusted, mustachioed. Fat-and-short proportions
	## that stay inside the boss capsule's 2.0 width.
	model.scale = Vector3(1.3,1.1,1.3)
	var skin: Dictionary = Palette.BOSS
	var body: Color = Palette.color(skin.body)
	var cream := Palette.color("fdf3d0")
	Visual.sphere(model,Vector3(0,.62,0),Vector3(1.5,1.35,1.2),body)
	Visual.sphere(model,Vector3(0,1.5,0),Vector3(1.15,.8,.95),Palette.color(skin.belly))
	Visual.sphere(model,Vector3(0,2.0,.06),Vector3(.95,.8,.85),body)
	Visual.sphere(model,Vector3(0,1.9,-.5),Vector3(.5,.3,.55),Palette.color(skin.snout))
	for x in [-.4,.4]:
		Visual.sphere(model,Vector3(x*.55,2.12,-.5),Vector3(.24,.26,.12),cream)
		Visual.sphere(model,Vector3(x*.55,2.12,-.58),Vector3(.11,.16,.07),Palette.color("1b2b33"))
		Visual.sphere(model,Vector3(x*1.35,.85,0),Vector3(.3,.75,.32),body.darkened(.12))
		Visual.sphere(model,Vector3(x*.62,.12,-.05),Vector3(.45,.22,.62),body.darkened(.24))
	for x in [-.7,.7]:
		Visual.sphere(model,Vector3(x,2.55,.02),Vector3(.4,.45,.16),Palette.color(skin.ear))
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
	Visual.sphere(model,Vector3(0,1.74,-.62),Vector3(.52,.16,.14),Palette.color(skin.mustache))
	# Winged mustache tips curl out to the sides for a stronger face profile.
	Visual.sphere(model,Vector3(-.42,1.78,-.6),Vector3(.2,.11,.12),Palette.color(skin.mustache))
	Visual.sphere(model,Vector3(.42,1.78,-.6),Vector3(.2,.11,.12),Palette.color(skin.mustache))
	Visual.sphere(model,Vector3(0,1.56,-.56),Vector3(.4,.12,.1),Palette.color(skin.mustache).darkened(.12))
	Visual.sphere(model,Vector3(0,1.38,-.46),Vector3(.32,.12,.1),Palette.color(skin.hat_band))
	metal_box(Vector3(1.35,1.7,-.2),Vector3(.07,.6,.07),Palette.color(skin.ladle))
	Visual.sphere(model,Vector3(1.35,1.34,-.2),Vector3(.16,.22,.16),Palette.color(skin.ladle))

func _process(delta: float) -> void:
	visible = hp > 0
	if not visible:
		return
	var names := ["THE BIG CHEESE","FOREMAN TUSK","MADAM MAGPIE","MECHA DRAGON"]
	# Boss names live in the HUD boss bar; floating text on any guard stays
	# name-and-hp only so the field never grows debug readouts.
	title.visible = not boss
	title.text = (names[tier] if boss else ["Rat security","Boar security","Magpie security","Lizard security"][tier]) + "  %d/%d" % [ceili(hp),int(max_hp)]
	title.modulate = Color("ffbb81") if boss else Color("d8dda9")
	tell.visible = state in ["WIND UP","CHARGE","FIRE BREATH"]
	model.position.y = sin(Time.get_ticks_msec()*.009)*.035 if state!="STUNNED" else 0
	if aura:
		aura.scale = Vector3.ONE*(1.0+sin(Time.get_ticks_msec()*.004)*.07)
	if hat:
		hat.rotation = Vector3(cos(Time.get_ticks_msec()*.0031)*.05,0,sin(Time.get_ticks_msec()*.0037)*.07)
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
			if is_on_wall() and boss:
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

func metal_box(pos: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	part.mesh=mesh
	part.position=pos
	part.material_override=Materials.metal(color)
	model.add_child(part)
	return part

func horn(pos: Vector3,height: float,radius: float) -> void:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius=0
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=8
	part.mesh=mesh
	part.position=pos
	part.material_override=Materials.metal(Color("ffd24a"))
	model.add_child(part)

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
		horn(Vector3(x,2.97,-.28),.85,.14)
		metal_box(Vector3(x*1.9,.6,.08),Vector3(.45,1.1,.48),steel)
		metal_box(Vector3(x*1.9,.12,-.2),Vector3(.65,.25,.85),dark)
		metal_box(Vector3(x*2.4,1.25,-.16),Vector3(.3,.95,.4),brass)
		for z in [-.48,-.18]:
			metal_box(Vector3(x*1.9,.14,z),Vector3(.12,.14,.36),brass)
	for i in range(5):
		metal_box(Vector3(0,.72-i*.09,.7+i*.35),Vector3(.48-i*.06,.4-i*.05,.5),steel)
		horn(Vector3(0,1.1-i*.07,.75+i*.35),.34,.13)
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
