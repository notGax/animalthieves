extends Node3D
## Art-directed first-person mitten rig. Spring motion, grip, reach and recoil.
const Visual = preload("res://scripts/heist/slime_visual.gd")
const Materials = preload("res://scripts/visuals/character_materials.gd")
const Palette = preload("res://scripts/visuals/palette.gd")
var character: CharacterBody3D
var camera: Camera3D
var hands: Array[Node3D]=[]
var arms: Array[MeshInstance3D]=[]
var fingers: Array=[]
var speeds := [Vector3.ZERO,Vector3.ZERO]
var tool_root: Node3D
var last_tool := ""
var sway := Vector2.ZERO
var pulse := 0.0
var reach := 0.0
var phase := 0.0
var clock := 0.0
var last_fall := 0.0
var landing := 0.0
var skin: Color
var painted: Array = []

func _paint(instance: MeshInstance3D, lighten := 0.0) -> void:
	painted.append([instance,lighten])
	instance.material_override=Materials.part(skin.lightened(lighten))

func apply_skin(skin_index: int) -> void:
	## Repaint every hand part from the shared palette (build + skin change).
	skin=Palette.color(Palette.skin(skin_index).body)
	for entry in painted:
		entry[0].material_override=Materials.part(skin.lightened(entry[1]))

func _ready() -> void:
	camera=get_parent()
	character=camera.get_node("../../..")
	skin=Palette.color(Palette.skin(character.skin_color).body)
	for side in [-1,1]:
		var hand := Node3D.new()
		hand.position=Vector3(side*.3,-.3,-.55)
		add_child(hand)
		hands.append(hand)
		_paint(Visual.sphere(hand,Vector3.ZERO,Vector3(.24,.14,.25),skin))
		_paint(Visual.sphere(hand,Vector3(side*-.105,-.015,-.035),Vector3(.08,.095,.14),skin.lightened(.04)),.04)
		_paint(Visual.sphere(hand,Vector3(side*-.12,.02,-.1),Vector3(.06,.09,.13),skin.lightened(.02)),.02)
		var digits: Array=[]
		for i in range(4):
			var finger := Node3D.new()
			finger.position=Vector3(-.081+i*.054,0,-.09)
			hand.add_child(finger)
			_paint(Visual.sphere(finger,Vector3(0,0,-.055),Vector3(.055,.08,.15),skin))
			var tip := Node3D.new()
			tip.position.z=-.11
			finger.add_child(tip)
			_paint(Visual.sphere(tip,Vector3(0,0,-.035),Vector3(.052,.072,.095),skin.lightened(.025)),.025)
			digits.append([finger,tip])
		fingers.append(digits)
		var arm := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius=.065
		cylinder.bottom_radius=.085
		cylinder.radial_segments=8
		cylinder.height=1
		arm.mesh=cylinder
		_paint(arm,-.04)
		add_child(arm)
		arms.append(arm)
	tool_root=Node3D.new()
	hands[1].add_child(tool_root)
	tool_root.position=Vector3(0,.045,-.13)

func _input(event: InputEvent) -> void:
	if not character or not character.is_multiplayer_authority() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
		return
	var level := get_tree().current_scene
	if level.is_camera_input_blocked(): return
	if event is InputEventMouseMotion:
		sway+=event.relative*.001
		sway=sway.limit_length(.1)
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		pulse=1.0
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_G,KEY_E,KEY_F]:
		reach=1.0

func _process(delta: float) -> void:
	visible=character.is_multiplayer_authority() and character._spring_arm_offset.is_first_person and camera.current
	if not visible: return
	var world := get_node_or_null("/root/Level/Environment/HeistWorld")
	var state: Dictionary=world.player_state.get(str(character.name),{}) if world else {}
	var tool: String=state.get("tool","grapple")
	if last_tool!=tool:
		make_tool(tool)
		last_tool=tool
	var held: Node3D=null
	if state.get("held", "")!="" and world:
		held=world.get_node("../ItemContainer").get_node_or_null(NodePath(str(state.held)))
	tool_root.visible=held==null and float(state.get("hp",100))>0
	var speed := Vector2(character.velocity.x,character.velocity.z).length()
	phase+=delta*(8+speed*.65)
	clock+=delta
	sway=sway.lerp(Vector2.ZERO,minf(1,delta*8))
	pulse=move_toward(pulse,0,delta*4)
	reach=move_toward(reach,0,delta*3)
	if character.is_on_floor() and last_fall < -3:
		landing=minf(.15,absf(last_fall)*.01)
	last_fall=character.velocity.y
	landing=move_toward(landing,0,delta*.6)
	for i in range(2):
		var side := -1 if i==0 else 1
		var target := Vector3(side*.31,-.3,-.53)
		var curl := .25
		if speed>.5:
			target.y+=sin(phase+i*PI)*.018
			target.z+=cos(phase+i*PI)*.025
		else:
			target.y+=sin(clock*2.2)*.009
		if not character.is_on_floor():
			target+=Vector3(side*.09+cos(clock*13+i*PI)*.05,.09+sin(clock*13+i*PI)*.06,-.04)
			curl=0.0
		if held:
			target=camera.to_local(held.global_position)+Vector3(side*.24,-.04,.16)
			target.z=clampf(target.z,-1.65,-.45)
			target.y=clampf(target.y,-.6,.2)
			curl=1.15
		elif i==1 and tool in ["grapple","water","crystal"]:
			target=Vector3(.27,-.24,-.62)
			curl=1.0
		target.z-=reach*.22
		if i==1:
			target.z+=pulse*.17
			target.y+=pulse*.04
		target.y-=landing
		target.x-=sway.x
		target.y+=sway.y
		if float(state.get("hp",100))<=0:
			target.y=-.65
		var step := minf(delta,.04)
		speeds[i]+=(target-hands[i].position)*150*step
		speeds[i]*=exp(-18*step)
		hands[i].position+=speeds[i]*step
		hands[i].rotation=Vector3(-.15-pulse*.15,side*-.15,side*.12)
		for digit in fingers[i]:
			digit[0].rotation.x=lerp_angle(digit[0].rotation.x,curl,minf(1,delta*16))
			digit[1].rotation.x=curl*.55
		var shoulder := Vector3(side*.43,-.5,.12)
		var end := hands[i].position+Vector3(0,0,.1)
		arms[i].position=(shoulder+end)*.5
		arms[i].scale.y=shoulder.distance_to(end)
		arms[i].look_at_from_position(to_global(arms[i].position),to_global(end))
		arms[i].rotate_object_local(Vector3.RIGHT,PI*.5)

func part(pos: Vector3,size: Vector3,color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size=size
	mesh.mesh=box
	mesh.position=pos
	mesh.material_override=Materials.part(color)
	tool_root.add_child(mesh)

func make_tool(tool: String) -> void:
	for child in tool_root.get_children(): child.queue_free()
	match tool:
		"grapple","water":
			part(Vector3(0,.06,-.06),Vector3(.16,.13,.33),Color("3fa8a0"))
			part(Vector3(0,-.03,.015),Vector3(.08,.19,.08),Color("b4763f"))
			part(Vector3(0,.055,-.26),Vector3(.1,.09,.1),Color("ffd27a"))
			if tool=="water":
				Visual.sphere(tool_root,Vector3(0,.16,-.08),Vector3(.19,.12,.28),Color("7acde8"))
			else:
				part(Vector3(-.065,.12,-.3),Vector3(.035,.17,.035),Color("9aa3ab"))
				part(Vector3(-.035,.2,-.3),Vector3(.09,.035,.035),Color("9aa3ab"))
		"crystal":
			var crystal := Visual.sphere(tool_root,Vector3(0,.12,-.04),Vector3(.19,.35,.18),Color("b6a3da"))
			var mesh := crystal.mesh as SphereMesh
			mesh.radial_segments=6
			mesh.rings=3
