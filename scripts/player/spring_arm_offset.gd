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
var _shake := 0.0
var _dip := 0.0
var _dip_velocity := 0.0
var _was_on_floor := true
var _fall_speed := 0.0

@onready var _camera: Camera3D = _spring_arm.get_node_or_null("Camera3D") as Camera3D


func _ready() -> void:
	_yaw = rotation.y
	_pitch = _spring_arm.rotation.x if _spring_arm else 0.0
	_fov = first_person_fov if is_first_person else third_person_fov
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

	# Shake: hurt/grapple/jetpack impulses and boss charges, capped offset+roll.
	var impulse := clampf(ext.length() * .05, 0.0, 1.0)
	_shake = maxf(_shake * exp(-delta * 5.0), impulse)
	if world:
		for enemy in world.enemies:
			if enemy.boss and enemy.hp > 0.0 and enemy.state == "CHARGE" \
					and enemy.global_position.distance_to(player.global_position) < 20.0:
				_shake = maxf(_shake, .5)
	var clock := Time.get_ticks_msec() * .001
	var noise := Vector3(
		sin(clock * 47.3) + sin(clock * 23.7) * .5,
		sin(clock * 53.1) + sin(clock * 37.9) * .5,
		sin(clock * 43.7))
	_camera.position = Vector3(noise.x, noise.y, 0.0) * (_shake * .12) + Vector3(0.0, _dip, 0.0)
	_camera.rotation.z = noise.z * _shake * .02

	# Landing dip: spring the camera down on hard landings, then rebound.
	var grounded := player.is_on_floor()
	if grounded and not _was_on_floor and _fall_speed > 4.0:
		_dip_velocity -= clampf(_fall_speed * .035, .2, .9)
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
	_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSIBILITY, -PI / 4.0, PI / 24.0)
	_apply_axis_lock()


func _apply_axis_lock() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	if _spring_arm:
		_spring_arm.rotation = Vector3(_pitch, 0.0, 0.0)
	if _camera:
		_camera.rotation = Vector3.ZERO


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
