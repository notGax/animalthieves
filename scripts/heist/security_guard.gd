extends CharacterBody3D
## Server-driven patrol, pursuit, wind-up, charge, stun and boss phases.
const Visual = preload("res://scripts/heist/slime_visual.gd")
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
	var skin: Color = [Color("817d70"),Color("a2826c"),Color("bcc5a4"),Color("72987a")][tier]
	var scale_factor := 1.7 if boss else 1.0
	model.scale = Vector3.ONE*scale_factor
	Visual.sphere(model,Vector3(0,.8,0),Vector3(1.25,1.55,.95),skin)
	Visual.sphere(model,Vector3(0,1.7,.1),Vector3(1.1,.9,.9),skin)
	Visual.sphere(model,Vector3(0,1.5,-.48),Vector3(.65,.4,.75),skin.lightened(.15))
	Visual.sphere(model,Vector3(0,1.53,-.83),Vector3(.27,.2,.16),Color("cf9997"))
	for x in [-.44,.44]:
		Visual.sphere(model,Vector3(x,2.05,.03),Vector3(.56,.6,.22) if tier==0 else Vector3(.4,.3,.24),Color("d3a7a3") if tier==0 else skin)
		Visual.sphere(model,Vector3(x*.6,1.8,-.39),Vector3(.27,.29,.14),Color("fff1c8"))
		Visual.sphere(model,Vector3(x*.6,1.8,-.47),Vector3(.12,.17,.08),Color("302b25"))
		Visual.sphere(model,Vector3(x*1.4,.95,0),Vector3(.25,.75,.3),skin)
		Visual.sphere(model,Vector3(x*.6,.15,-.12),Vector3(.43,.3,.65),skin.darkened(.2))
	if tier==0:
		Visual.sphere(model,Vector3(.3,.25,.65),Vector3(.18,.2,1.3),Color("c4948b"))
	if tier==1:
		for x in [-.3,.3]:
			Visual.sphere(model,Vector3(x,1.4,-.8),Vector3(.14,.5,.15),Color("f4e5bc"))
	if tier>=2:
		for x in [-.9,.9]:
			Visual.sphere(model,Vector3(x,1.1,.1),Vector3(1.5,.24,1.1),skin.darkened(.15))
	if boss and tier==0:
		Visual.sphere(model,Vector3(0,2.35,0),Vector3(1.2,.75,1.0),Color("ece3c5"))
		Visual.sphere(model,Vector3(0,1,-.45),Vector3(.85,1.0,.15),Color("e3dcc5"))
	if tier==3:
		for child in model.get_children():
			child.queue_free()
		build_dragon()
	title = Label3D.new()
	title.position.y = 4.5 if boss else 2.6
	title.font_size = 28
	title.pixel_size = .008
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title)
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

func _process(delta: float) -> void:
	visible = hp > 0
	if not visible:
		return
	var names := ["THE BIG CHEESE","FOREMAN TUSK","MADAM MAGPIE","MECHA DRAGON"]
	title.text = (names[tier] if boss else ["Rat security","Boar security","Magpie security","Lizard security"][tier]) + "  %d/%d\n%s" % [ceili(hp),int(max_hp),state]
	title.modulate = Color("ffbb81") if boss else Color("d8dda9")
	tell.visible = state in ["WIND UP","CHARGE","FIRE BREATH"]
	model.position.y = sin(Time.get_ticks_msec()*.009)*.035 if state!="STUNNED" else 0
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color
	mat.metallic=.65
	mat.roughness=.35
	part.material_override=mat
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color("d6b779")
	mat.metallic=.65
	part.material_override=mat
	model.add_child(part)

func build_dragon() -> void:
	var steel := Color("476671")
	var dark := Color("263f4a")
	var brass := Color("bf9758")
	metal_box(Vector3(0,1.1,0),Vector3(1.5,1.6,1.0),steel)
	metal_box(Vector3(0,1.4,-.56),Vector3(1.1,1.0,.12),brass)
	metal_box(Vector3(0,1.4,-.65),Vector3(.88,.76,.1),Color("9ecec6"))
	# The little lizard is visible through the chest cockpit.
	Visual.sphere(model,Vector3(0,1.45,-.77),Vector3(.5,.55,.2),Color("8bb86d"))
	for x in [-.12,.12]:
		Visual.sphere(model,Vector3(x,1.52,-.89),Vector3(.11,.11,.08),Color("f4e3a6"))
		Visual.sphere(model,Vector3(x,1.52,-.93),Vector3(.04,.07,.03),dark)
	metal_box(Vector3(0,2.0,-.3),Vector3(.7,.7,.7),dark)
	metal_box(Vector3(0,2.3,-.7),Vector3(1.05,.55,1.45),steel)
	metal_box(Vector3(0,1.94,-.94),Vector3(.92,.17,.93),brass)
	metal_box(Vector3(0,2.13,-1.38),Vector3(.83,.16,.06),Color("f1b56b"))
	for x in [-.39,.39]:
		Visual.sphere(model,Vector3(x,2.43,-1.27),Vector3(.2,.15,.09),Color("f3a652"))
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
		mat.albedo_color=Color("7e7860")
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
