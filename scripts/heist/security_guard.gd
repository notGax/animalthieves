extends CharacterBody3D
## Server-driven patrol, pursuit, wind-up, charge, stun and boss phases.
## The body build itself (species kits, chef, dragon, body-level cosmetics)
## lives in guard_visuals.gd; this script only animates and drives it.
const GuardVisuals = preload("res://scripts/heist/guard_visuals.gd")
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
var title_clock := 0.0
var tell: MeshInstance3D
var aura: MeshInstance3D
var hat: Node3D
var hat_base := Vector3.ZERO
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
var eye_base_l := Vector3.ONE
var eye_base_r := Vector3.ONE
var pupil_scale_l := Vector3.ONE
var pupil_scale_r := Vector3.ONE
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
	# Everything purely visual - species kits, the chef, the dragon and the
	# body-level cosmetics - is built by the visual module. This script keeps
	# only the AI (_physics_process) and the animation driver (_process),
	# which poses the hook nodes the module hands back.
	var rig: Dictionary = GuardVisuals.build(self, model, boss, tier)
	base_scale = rig["base_scale"]
	torso = rig["torso"]
	belly = rig["belly"]
	head = rig["head"]
	head_base = rig["head_base"]
	eye_l = rig["eye_l"]
	eye_r = rig["eye_r"]
	pupil_l = rig["pupil_l"]
	pupil_r = rig["pupil_r"]
	pupil_base_l = rig["pupil_base_l"]
	pupil_base_r = rig["pupil_base_r"]
	eye_base_l = rig["eye_base_l"]
	eye_base_r = rig["eye_base_r"]
	pupil_scale_l = rig["pupil_scale_l"]
	pupil_scale_r = rig["pupil_scale_r"]
	ear_l = rig["ear_l"]
	ear_r = rig["ear_r"]
	# assign() converts element-wise, so the hooks dictionary may hand back
	# the tail as any Array of MeshInstance3D.
	tail.assign(rig["tail"])
	hat = rig["hat"]
	hat_base = rig["hat_base"]
	torch = rig["torch"]
	torch_base = rig["torch_base"]
	mouth = rig["mouth"]
	ladle = rig["ladle"]
	ladle_base = rig["ladle_base"]
	arm_l = rig["arm_l"]
	arm_r = rig["arm_r"]
	stars = rig["stars"]
	bribe_ring = rig["bribe_ring"]
	bribe_base = rig["bribe_base"]
	title = rig["title"]
	aura = rig["aura"]
	aura_mat = rig["aura_mat"]
	tell = rig["tell"]
	tell_mat = rig["tell_mat"]
	last_vis_pos = origin

func _process(delta: float) -> void:
	visible = hp > 0
	if not visible:
		return
	anim_time += delta
	var names := ["THE BIG CHEESE","FOREMAN TUSK","MADAM MAGPIE","MECHA DRAGON"]
	# Boss names live in the HUD boss bar. Regular guards carry no permanent
	# floating readout: the label only pops up for a few seconds after the
	# guard takes damage, and only while the camera is close enough to read.
	title_clock = maxf(0.0,title_clock-delta)
	var cam := get_viewport().get_camera_3d()
	title.visible = not boss and title_clock > 0.0 and (cam == null or global_position.distance_to(cam.global_position) < 14.0)
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
		title_clock = 2.5
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
		# Openness multiplies the built eye scale; never replace it outright.
		eye_l.scale = Vector3(eye_base_l.x,eye_base_l.y*eye_open,eye_base_l.z)
		eye_r.scale = Vector3(eye_base_r.x,eye_base_r.y*eye_open,eye_base_r.z)
		eye_l.rotation.z = -anger_amt*.22 - spin*.5
		eye_r.rotation.z = anger_amt*.22 + spin*.5
	if pupil_l and pupil_r:
		pupil_l.position.x = pupil_base_l.x*(1.0-cross*.8)
		pupil_r.position.x = pupil_base_r.x*(1.0-cross*.8)
		pupil_l.scale = pupil_scale_l*(1.0+anger_amt*.3)
		pupil_r.scale = pupil_scale_r*(1.0+anger_amt*.3)
	# --- Secondary motion: hat inertia, ear lag, tail sway, tool business.
	hat_pose = hat_pose.lerp(Vector2(-lean*1.4,roll*1.5),1.0-exp(-5.0*delta))
	if hat:
		hat_pop = maxf(0.0,hat_pop-delta*2.4)
		var hat_tilt := .22 if state == "CHARGE" else (-.2 if state == "WIND UP" else 0.0)
		hat.rotation = Vector3(
			cos(anim_time*1.9)*.04+hat_pose.x+hat_tilt+.2*low_hp_amt*.5,
			0.0,
			sin(anim_time*2.3)*.055+hat_pose.y+.15*low_hp_amt+spin*.3)
		hat.position = hat_base+Vector3.UP*hat_pop*.5
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
	# Charging enemies kick up dust behind them. Vfx offsets are parent-local,
	# so this stays a small local offset rather than a world position.
	if state == "CHARGE" and vis_speed > 4.0:
		dust_clock -= delta
		if dust_clock <= 0.0:
			dust_clock = .11
			Vfx.dust(self,Vector3(0,.15,0),1.1 if boss else .7)
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
			world.play_sound.rpc("charge",global_position+Vector3.UP*1.5)
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
				world.play_sound.rpc("stun",global_position+Vector3.UP*1.5)
				if boss:
					take_damage(15)
	elif target:
		# A patrolling guard that acquires a target gives a sharp whistle:
		# the steal moment players read instantly.
		if state=="PATROL":
			world.play_sound.rpc("alert",global_position+Vector3.UP*1.5)
		state="HUNT"
		var offset: Vector3 = target.global_position-global_position
		offset.y=0
		if boss and attack_timer<=0 and offset.length()<17:
			charge_dir=offset.normalized()
			model.rotation.y=atan2(-charge_dir.x,-charge_dir.z)
			state="WIND UP"
			timer=1.15 if hp>max_hp*.45 else .7
			attack_timer=4.8 if hp>max_hp*.45 else 3.2
			world.play_sound.rpc("windup",global_position+Vector3.UP*1.5)
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
