extends Node3D
## Procedural expressive avatars share the template's movement and replication.
## The wobble language follows PEAK's tumbling scouts and R.E.P.O.'s flappy
## semibots: springy squash and stretch, lean into acceleration, head lag on
## turns, frantic eye darts near danger and flailing mittens in the air.
var blob: Node3D
var eyes: Array[MeshInstance3D] = []
var whites: Array[MeshInstance3D] = []
var brows: Array[MeshInstance3D] = []
var mittens: Array[MeshInstance3D] = []
var gaze := Vector2.ZERO
var mouth: MeshInstance3D
var ears: Node3D
var material: StandardMaterial3D
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

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 7
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .9
	instance.material_override = mat
	parent.add_child(instance)
	return instance

func _ready() -> void:
	character = get_parent()
	clock=float(int(str(character.name))%97)*.071
	blob = Node3D.new()
	add_child(blob)
	var colors := [Color("83bdd2"),Color("e8c57b"),Color("acd094"),Color("d98f83")]
	var body := sphere(blob, Vector3(0,.7,0), Vector3(1.45,1.4,1.25), colors[character.skin_color])
	material = body.material_override
	material.roughness = .85
	material.metallic = 0.0
	for x in [-.24,.24]:
		whites.append(sphere(blob, Vector3(x,1.02,-.5),Vector3(.42,.5,.2),Color("fffae9")))
		brows.append(sphere(blob,Vector3(x,1.34,-.48),Vector3(.3,.035,.04),Color("32444a")))
		eyes.append(sphere(blob,Vector3(x,1.02,-.62),Vector3(.17,.26,.09),Color("152c36")))
	mouth = sphere(blob,Vector3(0,.72,-.625),Vector3(.27,.09,.06),Color("25424b"))
	sphere(blob,Vector3(-.52,.72,-.42),Vector3(.21,.08,.04),Color("dd9999"))
	sphere(blob,Vector3(.52,.72,-.42),Vector3(.21,.08,.04),Color("dd9999"))
	for x in [-.78,.78]:
		mittens.append(sphere(blob,Vector3(x,.67,-.15),Vector3(.34,.23,.35),colors[character.skin_color]))
	ears = Node3D.new()
	blob.add_child(ears)
	for x in [-.5,.5]:
		sphere(ears,Vector3(x,1.5,.05),Vector3(.65,.7,.22),Color("bcaaa0"))
		sphere(ears,Vector3(x,1.5,-.08),Vector3(.43,.48,.12),Color("e6a6ac"))
	sphere(ears,Vector3(0,.28,.72),Vector3(.2,.18,1.3),Color("daa4aa"))

func _process(delta: float) -> void:
	clock += delta
	var step := maxf(delta,.001)
	var world := get_node_or_null("/root/Level/Environment/HeistWorld")
	var data: Dictionary = world.player_state.get(str(character.name), {}) if world else {}
	var form: String = data.get("form", "slime")
	ears.visible = form != "slime"
	var down: bool = float(data.get("hp",100)) <= 0
	var first: bool = character.is_multiplayer_authority() and character._spring_arm_offset.is_first_person
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
	# Squash and stretch: landings squash hard, falls and rises stretch tall.
	if character.is_on_floor() and not was_on_floor:
		squash_speed-=minf(absf(last_vertical),12)*.11
		lean_speed.y-=minf(absf(last_vertical),12)*.012
	was_on_floor=character.is_on_floor()
	last_vertical=character.velocity.y
	squash_speed+=(-150*squash-11*squash_speed)*step
	squash=clampf(squash+squash_speed*step,-.45,.45)
	var stretch := 0.0 if was_on_floor else clampf(absf(character.velocity.y)*.02,-.05,.28)
	var moving := velocity.length()
	var bounce := sin(clock * (12 if moving > .3 else 3)) * (.06 if moving > .3 else .025)
	var waddle := sin(clock*6)*.08 if moving>.3 else 0.0
	var tall := bounce+squash+stretch
	blob.scale = Vector3(1.0-tall*.55,1.0+tall,1.0-tall*.55)
	blob.rotation = Vector3(clampf(lean.y*.55,-.35,.35),clampf(turn_lag,-.45,.45),clampf(-lean.x*.55,-.35,.35)+waddle)
	if down:
		blob.scale = Vector3(1.3,.25,1.3)
	elif form == "rat":
		blob.scale *= .7
	elif form == "boar":
		blob.scale *= 1.22
	elif form == "bird":
		ears.scale = Vector3(2.0,.5,1)
	else:
		ears.scale = Vector3.ONE
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
				hand_target=Vector3(side*.5,.95,-.85)
			elif not character.is_on_floor():
				hand_target=Vector3(side*.6+cos(clock*14+i*PI)*.2,.75+sin(clock*14+i*PI)*.2,-.45)
			elif moving>.3:
				hand_target=Vector3(side*.72,.6,-.15+sin(clock*12+i*PI)*.18)
			else:
				hand_target.y+=sin(clock*9+i)*.05
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
	var bulge := 1+panic*.35
	var wide := character.velocity.y < -4
	for i in range(2):
		var eye := eyes[i]
		eye.position.x=(-.24 if i==0 else .24)+gaze.x
		eye.position.y=1.02+gaze.y
		eye.scale=Vector3(.17*bulge,.02 if blink or down else (.3 if wide else .24),.09)
		whites[i].scale=Vector3(.42*bulge,.06 if blink else .5*(1+panic*.1),.2)
		brows[i].position.y=1.34+panic*.05+(.03 if wide else 0)
		brows[i].rotation.z=(-1 if i==0 else 1)*(.3 if wide else (-.08-panic*.2))
	mouth.scale.y=.3 if character.velocity.y<-3 else (.2 if float(data.get("gesture_time",0))>0 else .08+panic*.14)
	if down:
		mouth.scale.y=.035