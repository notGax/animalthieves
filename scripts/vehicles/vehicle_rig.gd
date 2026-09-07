class_name VehicleRig
extends Node3D

## Authored visual rig for a vehicle. This node is a child of the gameplay
## root (the server-authoritative RigidBody3D in heist_world.gd) and handles
## everything purely presentational:
##   - the authored vehicle scene per kind (scenes/vehicles/*.tscn): body,
##     wheels and materials all live in the asset, not in code
##   - wheel pivots that spin from real longitudinal speed and steer from the
##     body's actual yaw rate (both derived locally - no new network fields)
##   - visual-only suspension springs (pitch under accel/brake, roll in turns,
##     vertical bounce; the cart rattles, the truck wallows, the racecar is stiff)
##   - the DriverMarker the rider is teleported to (replaces the old +Vector3(0,1,0))
##   - a smoothed chase of remote snapshot transforms so other players' cars
##     glide instead of snapping
##   - audio hook nodes the spatial-audio pass wires streams into
##
## No collisions, no gameplay logic: the game root stays the single authority.

const SPRING_SETTINGS: Dictionary = {
	# stiffness / damping for the chassis springs (per profile kind)
	"cart": [130.0, 8.0],
	"truck": [70.0, 6.5],
	"racecar": [210.0, 11.0],
}

const GameAudio = preload("res://scripts/audio/game_audio.gd")

## The authored vehicle assets. Each scene carries the full body build plus
## four wheel pivots named WheelFL/WheelFR/WheelRL/WheelRR, each holding a
## "Spin" child the rig rotates from real velocity.
const VEHICLE_SCENES: Dictionary = {
	"cart": preload("res://scenes/vehicles/shopping_cart.tscn"),
	"truck": preload("res://scenes/vehicles/mini_truck.tscn"),
	"racecar": preload("res://scenes/vehicles/racecar.tscn"),
}
const WHEEL_ORDER: Array[String] = ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]

var kind := "cart"
var profile: Dictionary = {}
var chassis: Node3D
var driver_marker: Marker3D
var engine_audio: AudioStreamPlayer3D
var impact_audio: AudioStreamPlayer3D

var _wheels: Array[Node3D] = []          # FL, FR, RL, RR spin pivots
var _wheel_spin := 0.0
var _steer_angle := 0.0
var _pitch := 0.0
var _pitch_velocity := 0.0
var _roll := 0.0
var _roll_velocity := 0.0
var _bounce := 0.0
var _bounce_velocity := 0.0
var _last_position := Vector3.ZERO
var _last_yaw := 0.0
var _last_forward_speed := 0.0
var _pitch_target := 0.0
var _roll_target := 0.0
var _bounce_target := 0.0
var _net_position := Vector3.ZERO
var _net_yaw := 0.0
var _has_net_target := false


## Builds the rig for one vehicle kind and returns it ready to add_child().
static func create(p_kind: String) -> VehicleRig:
	var rig := VehicleRig.new()
	rig.name = "VisualRig"
	rig.kind = p_kind
	rig.profile = VehicleProfiles.profile(p_kind)
	return rig


func _ready() -> void:
	_last_position = global_position
	_last_yaw = get_parent().rotation.y if get_parent() else 0.0
	chassis = Node3D.new()
	chassis.name = "Chassis"
	add_child(chassis)
	# The authored asset provides the whole body build and the four wheel
	# pivots; the rig only animates them and adds the runtime-only nodes
	# (driver marker, audio hooks) that belong to session state.
	var visual: Node3D = VEHICLE_SCENES[kind].instantiate()
	visual.name = "Body"
	chassis.add_child(visual)
	for wheel_name in WHEEL_ORDER:
		var pivot: Node3D = visual.get_node_or_null(wheel_name) as Node3D
		if pivot == null:
			continue
		_wheels.append(pivot)
	driver_marker = Marker3D.new()
	driver_marker.name = "DriverMarker"
	chassis.add_child(driver_marker)
	match kind:
		"cart": driver_marker.position = Vector3(0.0, 0.62, 1.55)
		"truck": driver_marker.position = Vector3(0.0, 1.15, -1.0)
		"racecar": driver_marker.position = Vector3(0.0, 0.95, 0.1)
	# Only powered vehicles carry an engine loop; the cart is human-powered
	# and stays silent. The loop also waits until somebody is actually aboard
	# (handled per frame below), so a parked fleet never hums.
	if bool(profile.get("has_engine", false)):
		engine_audio = AudioStreamPlayer3D.new()
		engine_audio.name = "EngineAudio"
		engine_audio.unit_size = 7.0
		engine_audio.max_db = -4.0
		engine_audio.volume_db = -8.0
		# Seamless one-second engine loop per profile kind; the per-frame update
		# bends pitch and volume from the body's real speed.
		engine_audio.stream = GameAudio.engine_stream(kind)
		chassis.add_child(engine_audio)
	impact_audio = AudioStreamPlayer3D.new()
	impact_audio.name = "ImpactAudio"
	impact_audio.unit_size = 9.0
	impact_audio.max_db = -2.0
	impact_audio.stream = GameAudio.stream("crash")
	chassis.add_child(impact_audio)


func _physics_process(delta: float) -> void:
	var body := get_parent() as Node3D
	if body == null:
		return
	if _has_net_target:
		# Remote smoothing: glide the gameplay root toward the latest snapshot
		# transform. The server is the authority and never calls net_update(),
		# so this only ever runs on non-authority peers.
		var weight := 1.0 - exp(-delta * 13.0)
		body.global_position = body.global_position.lerp(_net_position, weight)
		body.rotation.y = lerp_angle(body.rotation.y, _net_yaw, weight)
	_track_motion(body, delta)
	_update_springs(delta)
	_update_wheels(delta)
	_update_engine_audio(delta)


## Engine presentation: the loop only runs while somebody is actually aboard
## (parked vehicles stay silent), and its pitch and volume breathe with the
## body's real forward speed.
func _update_engine_audio(delta: float) -> void:
	if engine_audio == null or engine_audio.stream == null:
		return
	var body := get_parent() as Node3D
	if body == null:
		return
	# The record's rider is authoritative on every peer: the server writes it
	# on mount/dismount and clients receive it inside the state snapshots.
	var world := body.get_parent()
	var ridden := false
	if world != null and "vehicles" in world:
		ridden = int(world.vehicles.get(kind, {}).get("rider", 0)) > 0
	if not ridden:
		if engine_audio.playing and not engine_audio.stream_paused:
			engine_audio.stream_paused = true
		return
	if engine_audio.stream_paused:
		engine_audio.stream_paused = false
	elif not engine_audio.playing:
		engine_audio.play()
	var speed01: float = clampf(absf(_last_forward_speed) / maxf(1.0, float(profile.get("max_forward_speed", 10.0))), 0.0, 1.0)
	var weight := 1.0 - exp(-delta * 6.0)
	engine_audio.pitch_scale = lerpf(engine_audio.pitch_scale, 0.9 + speed01 * 0.85, weight)
	engine_audio.volume_db = lerpf(engine_audio.volume_db, -10.0 + speed01 * 5.0, weight)


## One-shot crash through the rig's own ImpactAudio hook. The world calls
## this over RPC so every peer hears the ram from the vehicle's position.
func play_impact() -> void:
	if impact_audio.stream != null:
		impact_audio.play()


## Clear remote interpolation state (world reset).
func reset_network() -> void:
	_has_net_target = false


## Store the latest snapshot transform for remote interpolation.
func net_update(position: Vector3, yaw: float) -> void:
	if not _has_net_target:
		# First snapshot: snap instead of gliding across the map.
		var body := get_parent() as Node3D
		if body:
			body.global_position = position
			body.rotation.y = yaw
	_has_net_target = true
	_net_position = position
	_net_yaw = yaw


func _track_motion(body: Node3D, delta: float) -> void:
	if delta <= 0.0:
		return
	var velocity := (body.global_position - _last_position) / delta
	_last_position = body.global_position
	velocity.y = clampf(velocity.y, -30.0, 30.0)
	var yaw := wrapf(body.rotation.y - _last_yaw, -PI, PI)
	_last_yaw = body.rotation.y
	var forward := Vector3(-sin(body.rotation.y), 0.0, -cos(body.rotation.y))
	var forward_speed := velocity.dot(forward)
	# Wheels: spin from real longitudinal speed over the wheel radius; steer
	# pivots from the real yaw rate (the same number the server physics made).
	_wheel_spin += (forward_speed / maxf(0.05, float(profile.get("visual_wheel_radius", 0.3)))) * delta
	var yaw_rate := yaw / delta
	var steer_target: float = clampf(yaw_rate / maxf(0.5, float(profile.get("steering_rate", 3.0))), -1.0, 1.0) * 0.45
	_steer_angle = lerpf(_steer_angle, steer_target, 1.0 - exp(-delta * 10.0))
	# Suspension targets: pitch from acceleration, roll from cornering, bounce
	# from vertical velocity changes (landings, curb hops, road noise).
	var lean: float = float(profile.get("body_lean_amount", 1.0))
	var accel := (forward_speed - _last_forward_speed) / delta
	_last_forward_speed = forward_speed
	_pitch_target = clampf(-accel * 0.011 * lean, -0.16, 0.16)
	_roll_target = clampf(yaw_rate * absf(forward_speed) * 0.004 * lean, -0.13, 0.13)
	_bounce_target = clampf(-velocity.y * 0.018 * float(profile.get("suspension_visual_amount", 1.0)), -0.1, 0.1)
	# Tiny perpetual rattling scaled per profile: the cart never sits still.
	var rattle: float = float(profile.get("suspension_visual_amount", 1.0))
	_bounce += sin(Time.get_ticks_msec() * 0.02) * 0.0022 * rattle


func _update_springs(delta: float) -> void:
	var settings: Array = SPRING_SETTINGS.get(kind, SPRING_SETTINGS["cart"])
	var stiffness: float = settings[0]
	var damping: float = settings[1]
	_pitch_velocity += ((-_pitch_target - _pitch) * stiffness - _pitch_velocity * damping) * delta
	_pitch = clampf(_pitch + _pitch_velocity * delta, -0.2, 0.2)
	_roll_velocity += ((-_roll_target - _roll) * stiffness - _roll_velocity * damping) * delta
	_roll = clampf(_roll + _roll_velocity * delta, -0.18, 0.18)
	_bounce_velocity += ((-_bounce_target - _bounce) * stiffness - _bounce_velocity * damping) * delta
	_bounce = clampf(_bounce + _bounce_velocity * delta, -0.14, 0.14)
	chassis.rotation = Vector3(_pitch, 0.0, _roll)
	chassis.position.y = _bounce


func _update_wheels(delta: float) -> void:
	for i in _wheels.size():
		var pivot: Node3D = _wheels[i]
		if i < 2:
			pivot.rotation.y = _steer_angle
		var spin: Node3D = pivot.get_node_or_null("Spin") as Node3D
		if spin:
			spin.rotation.x = _wheel_spin
