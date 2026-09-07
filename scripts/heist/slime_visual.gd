extends Node3D
## Procedural expressive avatars share the template's movement and replication.
## The wobble language follows PEAK's tumbling scouts and R.E.P.O.'s flappy
## semibots: springy squash and stretch, lean into acceleration, head lag on
## turns, frantic eye darts near danger and flailing mittens in the air.
const Materials = preload("res://scripts/visuals/character_materials.gd")
const Palette = preload("res://scripts/visuals/palette.gd")
const Vfx = preload("res://scripts/visuals/vfx.gd")
const FormProps = preload("res://scripts/heist/form_visuals.gd")
var blob: Node3D
var eyes: Array[MeshInstance3D] = []
var whites: Array[MeshInstance3D] = []
var brows: Array[MeshInstance3D] = []
var mittens: Array[MeshInstance3D] = []
var gaze := Vector2.ZERO
var mouth: MeshInstance3D
var ears: Node3D
var material: ShaderMaterial
var clock := 0.0
var character: CharacterBody3D
var lean := Vector2.ZERO
var lean_speed := Vector2.ZERO
var turn_lag := 0.0
var squash := 0.0
var squash_speed := 0.0
var panic := 0.0
var was_on_floor := true
var last_vertical := 0.0
var last_velocity := Vector2.ZERO
var prev_yaw := 0.0
# Expression drivers, all derived locally from synced player_state.
var skin: Dictionary = {}
var cheeks: Array[MeshInstance3D] = []
var ear_outers: Array[MeshInstance3D] = []
var ear_inners: Array[MeshInstance3D] = []
var tail: MeshInstance3D
var flash := 0.0
var last_hp := 100.0
var effort := 0.0
var excited := 0.0
var carry_sag := 0.0
var wobble := 0.0
var was_held := false
var was_form := "slime"
var form_props: Node3D
var bird_wings: Array = []
var tongue: Node3D
var nose_ref: MeshInstance3D
var boar_ears: Array = []
var boar_tail: Array = []
var lizard_tail: Array = []
# Randomized micro-timers: nervous ticks instead of constant sine motion.
var tongue_timer := 1.2
var tongue_out := 0.0
var flick_timer := 1.0
var flick_side := 1.0
var flick_amt := 0.0
# Third-person action polish: slap arc and throw follow-through.
var was_gesturing := false
var throw_punch := 0.0

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 7
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = size
	instance.material_override = Materials.part(color)
	parent.add_child(instance)
	return instance

static func sphere_hq(parent: Node3D, pos: Vector3, size: Vector3, color: Color, wobble := 0.0) -> MeshInstance3D:
	## Hero-quality body sphere: denser mesh and a per-body slime shader with
	## its own flash/wobble channels.
	var mesh := SphereMesh.new()
	mesh.radial_segments = 24
	mesh.rings = 14
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = size
	instance.material_override = Materials.unique(color, wobble)
	parent.add_child(instance)
	return instance

func _ready() -> void:
	character = get_parent()
	clock=float(int(str(character.name))%97)*.071
	blob = Node3D.new()
	add_child(blob)
	var body := sphere_hq(blob, Vector3(0,.7,0), Vector3(1.45,1.4,1.25), Color("5ec8e8"), .015)
	material = body.material_override
	for x in [-.24,.24]:
		whites.append(sphere(blob, Vector3(x,1.02,-.5),Vector3(.42,.5,.2),Color("fdf3d0")))
		brows.append(sphere(blob,Vector3(x,1.34,-.48),Vector3(.3,.035,.04),Color("23323a")))
		eyes.append(sphere(blob,Vector3(x,1.02,-.62),Vector3(.17,.26,.09),Color("1b2b33")))
	mouth = sphere(blob,Vector3(0,.72,-.625),Vector3(.27,.09,.06),Color("1b2b33"))
	for x in [-.52,.52]:
		cheeks.append(sphere(blob,Vector3(x,.72,-.42),Vector3(.21,.08,.04),Color("ff9db1")))
	for x in [-.78,.78]:
		mittens.append(sphere(blob,Vector3(x,.67,-.15),Vector3(.34,.23,.35),Color("5ec8e8")))
	ears = Node3D.new()
	blob.add_child(ears)
	for x in [-.5,.5]:
		ear_outers.append(sphere(ears,Vector3(x,1.5,.05),Vector3(.65,.7,.22),Color("2f8fb0")))
		ear_inners.append(sphere(ears,Vector3(x,1.5,-.08),Vector3(.43,.48,.12),Color("ffb0be")))
	tail = sphere(ears,Vector3(0,.28,.72),Vector3(.2,.18,1.3),Color("ffb0be"))
	apply_skin(character.skin_color)
	var built: Dictionary = FormProps.build(blob, skin)
	form_props = built.root
	bird_wings = built.wings
	tongue = built.tongue
	nose_ref = built.nose
	boar_ears = built.boar_ears
	boar_tail = built.boar_tail
	lizard_tail = built.lizard_tail

func apply_skin(skin_index: int) -> void:
	## Repaint the slime from the shared palette: build time and skin changes.
	skin = Palette.skin(skin_index)
	if material:
		material.set_shader_parameter("albedo", Palette.color(skin.body))
	var body_mat := Materials.part(Palette.color(skin.body))
	for mitten in mittens:
		mitten.material_override = body_mat
	var pupil_mat := Materials.part(Palette.color(skin.pupil))
	for eye in eyes:
		eye.material_override = pupil_mat
	if mouth:
		mouth.material_override = pupil_mat
	var brow_mat := Materials.part(Palette.color(skin.brow))
	for brow in brows:
		brow.material_override = brow_mat
	var cheek_mat := Materials.part(Palette.color(skin.cheek))
	for cheek in cheeks:
		cheek.material_override = cheek_mat
	var outer_mat := Materials.part(Palette.color(skin.deep))
	for ear in ear_outers:
		ear.material_override = outer_mat
	var inner_mat := Materials.part(Palette.color(skin.ear))
	for ear in ear_inners:
		ear.material_override = inner_mat
	if tail:
		tail.material_override = Materials.part(Palette.color(skin.ear).darkened(.08))

func _process(delta: float) -> void:
	clock += delta
	var step := maxf(delta,.001)
	var world := get_node_or_null("/root/Level/Environment/HeistWorld")
	var data: Dictionary = world.player_state.get(str(character.name), {}) if world else {}
	var form: String = data.get("form", "slime")
	# The slime's own big round ears and pink tail belong to the RAT alone;
	# boar, bird and lizard carry only their species kits.
	ears.visible = form == "rat"
	if form_props:
		for kind in ["rat","boar","bird","lizard"]:
			form_props.get_node(kind).visible = kind == form
	var down: bool = float(data.get("hp",100)) <= 0
	var held_name: String = data.get("held","")
	var first: bool = character.is_multiplayer_authority() and character._spring_arm_offset.is_first_person
	# Expression drivers, all spring-lerped from synced state only.
	var hp_now := float(data.get("hp",100))
	if hp_now < last_hp - .5 and not down:
		flash = 1.0
		material.set_shader_parameter("flash_color", Palette.color(Palette.VFX["hurt"]))
	last_hp = hp_now
	if form != was_form:
		was_form = form
		excited = 1.0
		Vfx.transform_burst(self, Vector3(0,1,0))
	var gesturing: bool = float(data.get("gesture_time",0)) > 0
	if gesturing and not was_gesturing:
		excited=maxf(excited,.4)
	was_gesturing=gesturing
	effort=lerpf(effort,1.0 if (gesturing or held_name!="") else 0.0,1-exp(-step*8))
	carry_sag=lerpf(carry_sag,1.0 if held_name!="" else 0.0,1-exp(-step*7))
	excited=move_toward(excited,0.0,delta*1.1)
	visible = not first
	character.get_node("GodotRobot3D/RobotArmature").visible = false
	var facing: Vector3=data.get("carry_direction",-character.global_basis.z)
	global_rotation.y=atan2(-facing.x,-facing.z)
	# Flappy head: the blob swings against fast turns, then springs back.
	var yaw := global_rotation.y
	turn_lag=lerpf(turn_lag,clampf(-wrapf(yaw-prev_yaw,-PI,PI)/step*.09,-.5,.5),1-exp(-step*9))
	prev_yaw=yaw
	# Lean spring: acceleration tips the blob and the low damping makes it wobble.
	var velocity := Vector2(character.velocity.x,character.velocity.z)
	var local_accel := Vector3.ZERO
	if clock>.2:
		local_accel=global_basis.inverse()*Vector3((velocity.x-last_velocity.x)/step,0,(velocity.y-last_velocity.y)/step)
	local_accel.x=clampf(local_accel.x,-9,9)
	local_accel.z=clampf(local_accel.z,-9,9)
	lean_speed+=(Vector2(clampf(local_accel.x*.05,-.55,.55),clampf(local_accel.z*.05,-.55,.55))-lean)*70*step
	lean_speed*=exp(-7.5*step)
	lean+=lean_speed*step
	# Per-form movement personality: spring stiffness, bounce cadence and
	# idle energy all read as a different creature.
	var spring_k := -150.0
	var spring_d := -11.0
	var bounce_freq := 12.0
	var bounce_amp := .06
	var idle_amp := .025
	match form:
		"rat":
			spring_k = -190.0
			spring_d = -13.0
			bounce_freq = 15.0
			bounce_amp = .045
			idle_amp = .018
		"boar":
			spring_k = -88.0
			spring_d = -8.0
			bounce_freq = 8.0
			bounce_amp = .085
			idle_amp = .01
		"bird":
			spring_k = -170.0
			spring_d = -12.5
			bounce_freq = 10.0
			bounce_amp = .04
			idle_amp = .035
		"lizard":
			spring_k = -120.0
			spring_d = -9.0
			bounce_freq = 9.0
			bounce_amp = .05
			idle_amp = .012
	# Squash and stretch: landings squash hard, falls and rises stretch tall.
	if character.is_on_floor() and not was_on_floor:
		squash_speed-=minf(absf(last_vertical),12)*(.11 if form != "boar" else .16)
		lean_speed.y-=minf(absf(last_vertical),12)*.012
		if absf(last_vertical)>4:
			Vfx.dust(self,Vector3(0,.12,0),clampf(absf(last_vertical)*.06,.7,1.6))
	was_on_floor=character.is_on_floor()
	last_vertical=character.velocity.y
	squash_speed+=(spring_k*squash+spring_d*squash_speed)*step
	squash=clampf(squash+squash_speed*step,-.45,.45)
	var stretch := 0.0 if was_on_floor else clampf(absf(character.velocity.y)*.02,-.05,.28)
	var moving := velocity.length()
	var bounce := sin(clock * bounce_freq) * (bounce_amp if moving > .3 else idle_amp)
	var waddle := sin(clock*6)*(.08 if form != "lizard" else .03) if moving>.3 else 0.0
	var tall := bounce+squash+stretch
	blob.scale = Vector3(1.0-tall*.55,1.0+tall,1.0-tall*.55)
	blob.rotation = Vector3(clampf(lean.y*.55,-.35,.35)+carry_sag*.12,clampf(turn_lag,-.45,.45),clampf(-lean.x*.55,-.35,.35)+waddle)
	# Bird rides a buoyant hover; the lizard crouches low. A throw leans the
	# whole blob into the release for a beat.
	throw_punch=move_toward(throw_punch,0.0,delta*3)
	blob.position.y=-carry_sag*.1+(sin(clock*2.4)*.05 if form == "bird" else (-.05 if form == "lizard" else 0.0))
	blob.position.z=-throw_punch*.12
	blob.rotation.x+=throw_punch*.1
	# Body wobble rides the slime shader; flash decays over the hurt/pickup pop.
	flash=move_toward(flash,0.0,delta*2.2)
	material.set_shader_parameter("flash",flash)
	wobble=lerpf(wobble,(.02 if moving>.3 else .006)+excited*.03,1-exp(-step*5))
	material.set_shader_parameter("wobble",wobble)
	if down:
		blob.scale = Vector3(1.3,.25,1.3)
	elif form == "rat":
		blob.scale *= .7
	elif form == "boar":
		blob.scale *= 1.22
	elif form == "lizard":
		blob.scale *= Vector3(1.06,.94,1.06)  # long, low silhouette
	# Wing nubs flap harder while moving; the bird's flutter answers vertical
	# speed, the lizard's tongue flicks on a randomized timer.
	if bird_wings.size() == 2:
		var flap := sin(clock*17.0)*(.55 if moving>.3 else .22)
		if form == "bird":
			flap = sin(clock*(11.0+absf(character.velocity.y)*2.5))*(.28+clampf(absf(character.velocity.y)*.06,0.0,.4)+moving*.12)
		bird_wings[0].rotation.z = flap
		bird_wings[1].rotation.z = -flap
	if tongue:
		tongue.visible = form == "lizard"
		tongue_timer -= delta
		if tongue_timer <= 0.0:
			tongue_timer = randf_range(1.4,3.8)
			tongue_out = .5
		tongue_out = maxf(0.0,tongue_out-delta)
		tongue.scale = Vector3(1,1,1+tongue_out*1.6)
	# Nervous ticks with small randomized timers: rat nose twitch and ear
	# flicks (the slime's own ears, or the boar's small pair).
	flick_timer -= delta
	if flick_timer <= 0.0:
		flick_timer = randf_range(1.1,3.0)
		flick_side = -1.0 if randf() < .5 else 1.0
		flick_amt = .5
	flick_amt = maxf(0.0,flick_amt-delta*2.2)
	var flick_rot := sin(clock*38.0)*.35*flick_amt*flick_side
	if form == "rat":
		ears.rotation.z = clampf(turn_lag*.3,-.2,.2)+flick_rot
		tail.rotation.y = sin(clock*3.1)*.12
		if nose_ref:
			nose_ref.scale = Vector3(.16,.13,.12)*(1.0+sin(clock*30.0)*.18*flick_amt)
	elif form == "boar":
		for i in range(boar_ears.size()):
			boar_ears[i].rotation.z = (.5 if i == 0 else -.5)+flick_rot*.5
		for i in range(boar_tail.size()):
			boar_tail[i].rotation.x = sin(clock*4.0+i)*.2
	elif form == "lizard":
		for i in range(lizard_tail.size()):
			lizard_tail[i].rotation.y = sin(clock*2.2-i*.7)*.08
	var target := Vector3.ZERO
	var best := 10.0
	if world:
		for other in character.get_parent().get_children():
			if other == character:
				continue
			var distance: float = other.global_position.distance_to(character.global_position)
			if distance < best:
				best = distance
				target = (other.global_position-character.global_position).normalized()
	if world:
		for enemy in world.enemies:
			var distance: float=enemy.global_position.distance_to(character.global_position)
			if enemy.hp>0 and distance<best:
				best=distance
				target=(enemy.global_position+Vector3.UP-character.global_position).normalized()
		var held: Node3D=null
		if data.get("held", "")!="":
			held=world.get_node("../ItemContainer").get_node_or_null(NodePath(str(data.held)))
		if held:
			target=(held.global_position-character.global_position-Vector3.UP).normalized()
		for i in range(2):
			var side := -1 if i==0 else 1
			var hand_target := Vector3(side*.78,.67,-.15)
			if held:
				hand_target=blob.to_local(held.global_position)+Vector3(side*.28,-.06,.12)
			elif float(data.get("gesture_time",0))>0:
				# The slap reads as an arc: pull back and up, whip through.
				var punch_phase := 1.0-float(data.get("gesture_time",0))/.45
				if punch_phase<.3:
					hand_target=Vector3(side*.62,.96,.1)
				else:
					var through := (punch_phase-.3)/.7
					hand_target=Vector3(side*(.56-through*.14),.95-through*.22,-.6-through*.5)
			elif not character.is_on_floor():
				hand_target=Vector3(side*.6+cos(clock*14+i*PI)*.2,.75+sin(clock*14+i*PI)*.2,-.45)
			elif moving>.3:
				hand_target=Vector3(side*.72,.6,-.15+sin(clock*12+i*PI)*.18)
			elif i==1:
				hand_target=Vector3(.55,.78,-.72+sin(clock*9)*.03)
			else:
				hand_target.y+=sin(clock*9+i)*.05
			# Release follow-through whips the mitts forward past the toss.
			hand_target.z-=throw_punch*(.32 if i==1 else .18)
			mittens[i].position=mittens[i].position.lerp(hand_target,minf(1,step*12))
	# Semibot eyes: dart at the nearest thing, and frantically near danger.
	var threat := 0.0
	if world and not down:
		for enemy in world.enemies:
			if enemy.hp>0:
				threat=maxf(threat,1-enemy.global_position.distance_to(character.global_position)/8)
	panic=lerpf(panic,clampf(threat,0,1),1-exp(-step*6))
	var local_target := blob.global_basis.inverse()*target
	var wanted := Vector2(clampf(local_target.x*.12,-.085,.085),clampf(local_target.y*.08,-.055,.055))
	wanted.x+=sin(clock*2.7)*.006+sin(clock*13.7)*.014*panic
	wanted.y+=cos(clock*11.3)*.01*panic
	gaze=gaze.lerp(wanted,1-exp(-step*16))
	var blink := fmod(clock,3.7)<.12
	var wink := fmod(clock,5.9)<.13 and not down and panic<.3
	# The lizard blinks eyes out of phase; everyone else blinks together.
	var blink_offset := .23 if form == "lizard" else 0.0
	var squint := effort>.5
	var bulge := 1+panic*.35
	var wide := character.velocity.y < -4
	var tilt := .08+panic*.2
	if wide:
		tilt=-.3
	elif squint:
		tilt=.34
	for i in range(2):
		var eye := eyes[i]
		var shut := fmod(clock+i*blink_offset,3.7)<.12 or (i==1 and wink)
		eye.position.x=(-.24 if i==0 else .24)+gaze.x
		eye.position.y=1.02+gaze.y
		eye.scale=Vector3(.17*bulge,.02 if shut or down else (.3 if wide else (.15 if squint else .24)),.09)
		whites[i].scale=Vector3(.42*bulge,.06 if shut else (.3 if squint else .5*(1+panic*.1)),.2)
		brows[i].position.y=1.34+panic*.05+(.03 if wide else 0)-(.05 if squint else 0)
		brows[i].rotation.z=tilt if i==0 else -tilt
	# Mouth shape table: idle, panic, waa-falling, oof (hurt), effort grimace, grin.
	var mouth_size := Vector3(.27,.09,.06)
	if down:
		mouth_size=Vector3(.3,.035,.06)
	elif character.velocity.y<-3:
		mouth_size=Vector3(.22,.3,.06)
	elif flash>.3:
		mouth_size=Vector3(.32,.2,.06)
	elif effort>.5:
		mouth_size=Vector3(.24,.18,.06)
	elif panic>.4:
		mouth_size=Vector3(.3,.14,.06)
	elif excited>.2:
		mouth_size=Vector3(.34,.12,.06)
	mouth.scale=mouth.scale.lerp(mouth_size,1-exp(-step*12))
	# Pickup sparkle: held-item transitions are synced, the glitter is local.
	if held_name!="" and not was_held:
		excited=1.0
		flash=maxf(flash,.5)
		material.set_shader_parameter("flash_color",Palette.color(Palette.VFX["pickup"]))
		Vfx.sparkle(self,Vector3(0,1.3,0))
	if held_name=="" and was_held:
		throw_punch=1.0
	was_held=held_name!=""