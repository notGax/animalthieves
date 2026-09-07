extends Node3D
## Art-directed first-person mitten rig. Spring motion, grip, reach and recoil.
const Visual = preload("res://scripts/heist/slime_visual.gd")
const Materials = preload("res://scripts/visuals/character_materials.gd")
const Palette = preload("res://scripts/visuals/palette.gd")
var character: CharacterBody3D
var camera: Camera3D
var hands: Array[Node3D]=[]
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
# Mitten performance state: everything springs, nothing snaps.
var sway_lag := Vector2.ZERO
var anticipation := 0.0
var punch := 0.0
var yank_pending := false
var throw_kick := 0.0
var had_held: Node3D = null

func _paint(instance: MeshInstance3D, lighten := 0.0) -> void:
	painted.append([instance,lighten])
	instance.material_override=Materials.part(skin.lightened(lighten))
	# Viewmodel parts never cast shadows: part-on-part shadowing at this range
	# is pure acne (the banded thumbs over the manhole grate), and the world
	# shadowmap is tuned for metres, not centimetres. Receiving is kept, so
	# light through the grate still plays over the mitts.
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func apply_skin(skin_index: int) -> void:
	## Repaint every hand part from the shared palette (build + skin change).
	skin=Palette.color(Palette.skin(skin_index).body)
	for entry in painted:
		entry[0].material_override=Materials.part(skin.lightened(entry[1]))

func _ready() -> void:
	camera=get_parent()
	character=camera.get_node("../../..")
	skin=Palette.color(Palette.skin(character.skin_color).body)
	# Stubby floating slime mitts: one fat palm, a knuckle pad, three chunky
	# finger nubs and a thumb. No wrists, no forearms - the slime has no arms,
	# so the mitts simply drift in from the bottom corners like the third-person
	# mitten nubs do. Grip is a pitch of the whole mitten, never jointed fingers.
	for side in [-1,1]:
		var hand := Node3D.new()
		hand.position=Vector3(side*.33,-.32,-.52)
		add_child(hand)
		hands.append(hand)
		_paint(Visual.sphere(hand,Vector3.ZERO,Vector3(.27,.21,.28),skin))
		_paint(Visual.sphere(hand,Vector3(0,.055,.07),Vector3(.22,.14,.17),skin.lightened(.04)),.04)
		for n in range(3):
			var nub := Visual.sphere(hand,Vector3((n-1)*.095,-.02,-.2),Vector3(.085,.095,.13),skin)
			nub.rotation.x=-.3
			_paint(nub)
		var thumb := Visual.sphere(hand,Vector3(side*-.17,-.06,-.06),Vector3(.1,.13,.13),skin.lightened(.02))
		thumb.rotation.z=side*-.35
		_paint(thumb,.02)
	tool_root=Node3D.new()
	hands[1].add_child(tool_root)
	tool_root.position=Vector3(0,.04,-.15)

func _input(event: InputEvent) -> void:
	if not character or not character.is_multiplayer_authority() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
		return
	var level := get_tree().current_scene
	if level.is_camera_input_blocked(): return
	if event is InputEventMouseMotion:
		sway+=event.relative*.001
		sway=sway.limit_length(.1)
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		anticipation=1.0
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
	# Delayed sway: the mitts trail the camera drag, and the difference between
	# the two feeds a small rotational inertia.
	sway_lag=sway_lag.lerp(sway,minf(1,delta*4.5))
	# Wind-up, then release: the strike is shaped per tool once the pull-back
	# finishes. Water recoils soft, the grapple snaps out and yanks back,
	# slaps give a plain recoil, the crystal just squeezes.
	var was_winding := anticipation>0
	anticipation=move_toward(anticipation,0,delta*8)
	if was_winding and anticipation==0:
		if tool=="water":
			pulse=.5
		elif tool=="grapple":
			punch=1.0
			yank_pending=true
		elif tool!="crystal":
			pulse=1.0
	pulse=move_toward(pulse,0,delta*4)
	punch=move_toward(punch,0,delta*8)
	if yank_pending and punch<.35:
		pulse=1.1
		yank_pending=false
	reach=move_toward(reach,0,delta*3)
	# Throw follow-through: the release kicks both mitts forward, then springs.
	if held==null and had_held:
		throw_kick=1.0
	had_held=held
	throw_kick=move_toward(throw_kick,0,delta*3.5)
	if character.is_on_floor() and last_fall < -3:
		landing=minf(.15,absf(last_fall)*.01)
	last_fall=character.velocity.y
	landing=move_toward(landing,0,delta*.6)
	for i in range(2):
		var side := -1 if i==0 else 1
		var target := Vector3(side*.33,-.32,-.52)
		var curl := .25
		if speed>.5:
			target.y+=sin(phase+i*PI)*.024
			target.z+=cos(phase+i*PI)*.03
		else:
			target.y+=sin(clock*2.2)*.009
		if not character.is_on_floor():
			target+=Vector3(side*.09+cos(clock*13+i*PI)*.05,.09+sin(clock*13+i*PI)*.06,-.04)
			curl=0.0
		# Carried goods have weight: heavier cargo droops lower and makes the
		# mitts lazier to move.
		var mass := 1.0
		if held and held is RigidBody3D:
			mass=clampf(held.mass*.5,.7,1.7)
		if held:
			target=camera.to_local(held.global_position)+Vector3(side*.24,-.04,.16)
			target.z=clampf(target.z,-1.65,-.45)
			target.y=clampf(target.y,-.6,.2)-(mass-1.0)*.05
			curl=1.05
		elif i==1 and tool in ["grapple","water"]:
			target=Vector3(.27,-.24,-.62)
			curl=1.0
		elif tool=="crystal" and float(state.get("gesture_time",0))>0:
			# Reviving with the crystal: both mitts cradle it, gently bobbing.
			target=Vector3(side*.13,-.27+sin(clock*3.1)*.012,-.47)
			curl=.75
		target.z-=reach*.22
		target.z-=punch*.2
		if i==1:
			target.z+=pulse*.17
			target.y+=pulse*.04
		if throw_kick>0:
			target.z-=throw_kick*.24
			if i==1: target.y+=throw_kick*.05
		target.y-=landing
		target.x-=sway_lag.x
		target.y+=sway_lag.y
		if anticipation>0:
			target.z+=anticipation*.09
			target.y+=anticipation*.03
		if float(state.get("hp",100))<=0:
			target.y=-.65
		var step := minf(delta,.04)
		speeds[i]+=(target-hands[i].position)*150/mass*step
		speeds[i]*=exp(-18*step)
		hands[i].position+=speeds[i]*step
		# Grip curls the whole mitten; clicks and landings squish it like rubber.
		hands[i].rotation=Vector3(
			-.14-curl*.38-pulse*.12-punch*.3-throw_kick*.35+anticipation*.3,
			side*-.22+(sway.x-sway_lag.x)*2.2,
			side*.15+(sway.y-sway_lag.y)*-1.6)
		var squish := pulse*.14+landing*1.2+sin(clock*2.3+i)*.012+(mass-1.0)*.1
		if tool=="crystal" and float(state.get("gesture_time",0))>0:
			squish+=.06+sin(clock*3.1)*.02
		hands[i].scale=Vector3(1.0+squish,1.0-squish*.7,1.0+squish)

func part(pos: Vector3,size: Vector3,color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size=size
	mesh.mesh=box
	mesh.position=pos
	mesh.material_override=Materials.part(color)
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tool_root.add_child(mesh)

func make_tool(tool: String) -> void:
	for child in tool_root.get_children(): child.queue_free()
	match tool:
		"grapple","water":
			part(Vector3(0,.06,-.06),Vector3(.16,.13,.33),Color("3fa8a0"))
			part(Vector3(0,-.03,.015),Vector3(.08,.19,.08),Color("b4763f"))
			part(Vector3(0,.055,-.26),Vector3(.1,.09,.1),Color("ffd27a"))
			if tool=="water":
				var blob := Visual.sphere(tool_root,Vector3(0,.16,-.08),Vector3(.19,.12,.28),Color("7acde8"))
				blob.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				part(Vector3(-.065,.12,-.3),Vector3(.035,.17,.035),Color("9aa3ab"))
				part(Vector3(-.035,.2,-.3),Vector3(.09,.035,.035),Color("9aa3ab"))
		"crystal":
			var crystal := Visual.sphere(tool_root,Vector3(0,.12,-.04),Vector3(.19,.35,.18),Color("b6a3da"))
			crystal.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var mesh := crystal.mesh as SphereMesh
			mesh.radial_segments=6
			mesh.rings=3
