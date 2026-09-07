class_name SpringArmCharacter
extends Node3D

signal perspective_changed(first_person: bool)

const MOUSE_SENSIBILITY: float = 0.005

@export_category("Objects")
@export var _spring_arm: SpringArm3D = null
@export var _first_person_anchor: Node3D = null

@export_category("Camera Perspective")
@export_range(0.0, 10.0, 0.05) var third_person_distance := 5.0
@export_range(0.0, 1.0, 0.05) var first_person_distance := 0.0
@export_range(0.0, 3.0, 0.05) var third_person_height := 2.0
@export_range(1.0, 179.0, 1.0) var third_person_fov := 75.0
@export_range(1.0, 179.0, 1.0) var first_person_fov := 90.0

var is_first_person := true
var _yaw := 0.0
var _pitch := 0.0

# Local-only camera feedback. Everything is derived from state the owning
# player already has (velocity, external_velocity, synced player_state), so no
# new data ever crosses the network. All channels are exp-decayed or sprung,
# never constant, and capped: dip .25 m, offset .12 m, roll .02 rad.
var _fov := 0.0
var _fov_kick := 0.0
var _dip := 0.0
var _dip_velocity := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
# Trauma shake: events pour into one 0..1 channel, the offset runs as its
# square, and a cached noise field drives the motion. Boss charges steer the
# noise toward a slow rumble; slaps and landings give short sharp kicks.
var _trauma := 0.0
var _rumble := 0.0
var _bias := 0.0
var _noise_time := 0.0
var _last_gesture := 0.0
var _boss_states: Dictionary = {}
var _camera_base_pos := Vector3.ZERO
var _camera_base_rot := Vector3.ZERO
var _noise: FastNoiseLite

@onready var _camera: Camera3D = _spring_arm.get_node_or_null("Camera3D") as Camera3D


func _ready() -> void:
	_yaw = rotation.y
	_pitch = _spring_arm.rotation.x if _spring_arm else 0.0
	_fov = first_person_fov if is_first_person else third_person_fov
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = 7
	if _camera:
		# The shake channels write the camera transform absolutely every
		# frame from this captured base, so feedback can never drift.
		_camera_base_pos = _camera.position
		_camera_base_rot = _camera.rotation
	_apply_axis_lock()
	_apply_perspective()


func _process(delta: float) -> void:
	_apply_axis_lock()
	if is_first_person and _spring_arm and _first_person_anchor:
		_spring_arm.global_position = _first_person_anchor.global_position
	_apply_feedback(delta)


## FOV kicks, shake and landing dips for the local camera only.
func _apply_feedback(delta: float) -> void:
	if _camera == null or not is_multiplayer_authority():
		return
	var player := get_parent() as CharacterBody3D
	if player == null:
		return
	var blend := 1.0 - exp(-delta * 8.0)
	var planar := Vector2(player.velocity.x, player.velocity.z).length()

	# FOV stretch: sprint ramp, vehicle rush, launch kick from impulses.
	var boost := 0.0
	var state: Dictionary = {}
	var world := get_node_or_null("/root/Level/Environment/HeistWorld")
	if world:
		state = world.player_state.get(str(player.name), {})
	if state.get("vehicle", "") != "":
		boost = minf(8.0, planar * .5)
	elif Input.is_action_pressed("shift") and planar > 6.0:
		boost = clampf((planar - 6.0) * 1.5, 0.0, 6.0)
	var ext: Vector3 = player.external_velocity
	_fov_kick = maxf(_fov_kick * exp(-delta * 6.0), clampf((ext.y - 8.0) * .7, 0.0, 10.0))
	_fov = lerpf(_fov, (first_person_fov if is_first_person else third_person_fov) + boost + _fov_kick, blend)
	_camera.fov = _fov

	# Trauma shake. Impulses (grapple yank, jetpack, knockback) feed the
	# channel fast; a slap gesture kicks it lightly; hard landings add a
	# thump on top of the dip spring. Boss charges hold a slow rumble while
	# they close in, and a charge that ends stunned - the wall impact - is
	# the strongest kick the camera can give.
	var impact := clampf(ext.length() * .05, 0.0, 1.0)
	if impact > 0.0:
		_trauma = minf(1.0, _trauma + impact * delta * 12.0)
	var gesture_now: float = float(state.get("gesture_time", 0.0))
	if gesture_now > 0.0 and _last_gesture <= 0.0 and str(state.get("gesture", "")) == "attack":
		_trauma = minf(1.0, _trauma + .16)
	_last_gesture = gesture_now
	_bias = maxf(_bias * exp(-delta * 6.0), clampf(ext.y * .03, 0.0, .35))
	var rumble := 0.0
	if world:
		for enemy in world.enemies:
			var distance: float = enemy.global_position.distance_to(player.global_position)
			if enemy.boss:
				if enemy.hp > 0.0 and enemy.state == "CHARGE" and distance < 20.0:
					rumble = maxf(rumble, 1.0 - distance / 20.0)
				var prev: String = _boss_states.get(str(enemy.name), "")
				if prev == "CHARGE" and enemy.state == "STUNNED" and distance < 25.0:
					_trauma = minf(1.0, _trauma + .85)
					_dip_velocity -= .5
				_boss_states[str(enemy.name)] = enemy.state
	_rumble = lerpf(_rumble, rumble, 1.0 - exp(-delta * 6.0))
	_trauma = maxf(_trauma * exp(-delta * 2.6), _rumble * .75)
	_noise_time += delta * lerpf(26.0, 9.0, clampf(_rumble, 0.0, 1.0))
	var amp := _trauma * _trauma
	var nx := _noise.get_noise_2d(_noise_time, 0.0)
	var ny := _noise.get_noise_2d(_noise_time, 31.7)
	var nroll := _noise.get_noise_2d(_noise_time, 71.3)
	_camera.position = _camera_base_pos \
		+ Vector3(nx * .12, ny * .12 + _bias * .05, 0.0) * amp \
		+ Vector3(0.0, _dip, 0.0)
	_camera.rotation = _camera_base_rot + Vector3(0.0, 0.0, nroll * amp * .025)

	# Landing dip: spring the camera down on hard landings, then rebound.
	var grounded := player.is_on_floor()
	if grounded and not _was_on_floor and _fall_speed > 4.0:
		_dip_velocity -= clampf(_fall_speed * .035, .2, .9)
		_trauma = minf(1.0, _trauma + clampf(_fall_speed * .025, .05, .3))
	_dip_velocity += (-_dip * 140.0 - _dip_velocity * 11.0) * delta
	_dip = clampf(_dip + _dip_velocity * delta, -.25, 0.0)
	if not grounded:
		_fall_speed = maxf(0.0, -player.velocity.y)
	_was_on_floor = grounded


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	var current_scene := get_tree().get_current_scene()
	if current_scene and current_scene.has_method("is_camera_input_blocked"):
		if current_scene.is_camera_input_blocked():
			return

	if event.is_action_pressed("toggle_camera"):
		is_first_person = not is_first_person
		_apply_perspective()
		perspective_changed.emit(is_first_person)
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseMotion):
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	_yaw = wrapf(_yaw - event.relative.x * MOUSE_SENSIBILITY, -PI, PI)
	# A generous symmetric pitch range: look almost straight up or down, but
	# never past vertical where the rig would flip.
	_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSIBILITY, deg_to_rad(-70.0), deg_to_rad(70.0))
	_apply_axis_lock()


func _apply_axis_lock() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	if _spring_arm:
		_spring_arm.rotation = Vector3(_pitch, 0.0, 0.0)
	if _camera:
		_camera.rotation = _camera_base_rot


func _apply_perspective() -> void:
	if not _spring_arm:
		return
	if is_first_person:
		_spring_arm.spring_length = first_person_distance
		if _first_person_anchor:
			_spring_arm.global_position = _first_person_anchor.global_position
		if _camera:
			_camera.fov = first_person_fov
	else:
		_spring_arm.spring_length = third_person_distance
		_spring_arm.position = Vector3(0.0, third_person_height, 0.0)
		if _camera:
			_camera.fov = third_person_fov
