class_name VehicleRig
extends Node3D

## Authored visual rig for a vehicle. This node is a child of the gameplay
## root (the server-authoritative RigidBody3D in heist_world.gd) and handles
## everything purely presentational:
##   - the authored chunky body build (per-kind, from VehicleMaterials)
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
	match kind:
		"cart": _build_cart()
		"truck": _build_truck()
		"racecar": _build_racecar()
	driver_marker = Marker3D.new()
	driver_marker.name = "DriverMarker"
	chassis.add_child(driver_marker)
	match kind:
		"cart": driver_marker.position = Vector3(0.0, 0.62, 1.55)
		"truck": driver_marker.position = Vector3(0.0, 1.15, -1.0)
		"racecar": driver_marker.position = Vector3(0.0, 0.95, 0.1)
	engine_audio = AudioStreamPlayer3D.new()
	engine_audio.name = "EngineAudio"
	engine_audio.unit_size = 7.0
	engine_audio.max_db = -4.0
	engine_audio.volume_db = -8.0
	# Seamless one-second engine loop per profile kind; the per-frame update
	# bends pitch and volume from the body's real speed.
	engine_audio.stream = GameAudio.engine_stream(kind)
	engine_audio.autoplay = true
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


## Engine presentation: pitch and volume breathe with the body's real
## forward speed; the loop pauses while the vehicle is not in the fleet.
func _update_engine_audio(delta: float) -> void:
	var body := get_parent() as Node3D
	if body == null or engine_audio.stream == null:
		return
	engine_audio.stream_paused = not body.visible
	if engine_audio.stream_paused:
		return
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


# --- authored builds -------------------------------------------------------

func _box(parent: Node3D, size: Vector3, position: Vector3, material: Material,
		rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = position
	mesh.rotation = rotation
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh


func _cylinder(parent: Node3D, radius: float, height: float, position: Vector3, material: Material,
		axis: Vector3 = Vector3(0, 1, 0), rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	mesh.mesh = cylinder
	mesh.position = position
	mesh.rotation = rotation
	# CylinderMesh is born along Y; tilt it to the requested axis.
	if absf(axis.x) > 0.5:
		mesh.rotation.z = PI * 0.5
	elif absf(axis.z) > 0.5:
		mesh.rotation.x = PI * 0.5
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh


func _sphere(parent: Node3D, radius: float, position: Vector3, material: Material,
		scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	mesh.position = position
	mesh.scale = scale
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh


## One wheel: steering pivot + spin pivot + tire + hubcap.
func _wheel(parent: Node3D, position: Vector3, radius: float, width: float, front: bool) -> void:
	var pivot := Node3D.new()
	pivot.name = "WheelFL" if front and position.x < 0 else ("WheelFR" if front else ("WheelRL" if position.x < 0 else "WheelRR"))
	pivot.position = position
	parent.add_child(pivot)
	if front:
		pivot.set_meta("steers", true)
	var spin := Node3D.new()
	spin.name = "Spin"
	pivot.add_child(spin)
	var tire := _cylinder(spin, radius, width, Vector3.ZERO, VehicleMaterials.rubber(), Vector3(1, 0, 0))
	tire.rotation.z = PI * 0.5
	_hub(spin, radius, width)
	_wheels.append(pivot)


func _hub(spin: Node3D, radius: float, width: float) -> void:
	_cylinder(spin, radius * 0.45, width * 1.04, Vector3.ZERO, VehicleMaterials.hub(), Vector3(1, 0, 0))


# --- cart: wire basket, handle, tiny rattling wheels -----------------------

func _build_cart() -> void:
	var paint := VehicleMaterials.paint("cart")
	var worn := VehicleMaterials.paint_worn("cart")
	# chassis plate + skid rails
	_box(chassis, Vector3(1.4, 0.1, 2.1), Vector3(0, -0.16, 0), VehicleMaterials.metal())
	_box(chassis, Vector3(0.08, 0.08, 2.0), Vector3(0.62, -0.28, 0), VehicleMaterials.dark())
	_box(chassis, Vector3(0.08, 0.08, 2.0), Vector3(-0.62, -0.28, 0), VehicleMaterials.dark())
	# basket walls, slightly flared outward for the shopping-cart read
	var wall := Vector3(0.07, 0.62, 2.2)
	_box(chassis, wall, Vector3(0.76, 0.24, 0), paint, Vector3(0, 0, -0.06))
	_box(chassis, wall, Vector3(-0.76, 0.24, 0), paint, Vector3(0, 0, 0.06))
	_box(chassis, Vector3(1.5, 0.62, 0.07), Vector3(0, 0.24, -1.1), worn, Vector3(0.06, 0, 0))
	_box(chassis, Vector3(1.5, 0.62, 0.07), Vector3(0, 0.24, 1.1), worn, Vector3(-0.06, 0, 0))
	# basket floor + grime
	_box(chassis, Vector3(1.45, 0.06, 2.15), Vector3(0, -0.04, 0), VehicleMaterials.grime())
	# corner posts
	for x in [-0.78, 0.78]:
		for z in [-1.12, 1.12]:
			_cylinder(chassis, 0.045, 0.72, Vector3(x, 0.22, z), VehicleMaterials.brass())
	# handle: tubes rising rearward + crossbar + grips
	_cylinder(chassis, 0.04, 0.9, Vector3(0.55, 0.62, 1.28), VehicleMaterials.metal(), Vector3(0, 1, 0), Vector3(0.5, 0, 0))
	_cylinder(chassis, 0.04, 0.9, Vector3(-0.55, 0.62, 1.28), VehicleMaterials.metal(), Vector3(0, 1, 0), Vector3(0.5, 0, 0))
	_cylinder(chassis, 0.05, 1.16, Vector3(0, 1.02, 1.5), VehicleMaterials.metal(), Vector3(1, 0, 0))
	_cylinder(chassis, 0.06, 0.22, Vector3(0.5, 1.02, 1.5), VehicleMaterials.dark(), Vector3(1, 0, 0))
	_cylinder(chassis, 0.06, 0.22, Vector3(-0.5, 1.02, 1.5), VehicleMaterials.dark(), Vector3(1, 0, 0))
	# bell
	_sphere(chassis, 0.07, Vector3(0.3, 1.08, 1.34), VehicleMaterials.brass())
	# headlamp on the basket front
	_sphere(chassis, 0.09, Vector3(0, 0.5, -1.14), VehicleMaterials.lens(), Vector3(1, 0.8, 0.8))
	var wheel_positions: Array[Vector3] = [
		Vector3(-0.72, -0.24, -0.72), Vector3(0.72, -0.24, -0.72),
		Vector3(-0.72, -0.24, 0.72), Vector3(0.72, -0.24, 0.72),
	]
	for i in wheel_positions.size():
		_wheel(chassis, wheel_positions[i], float(profile.get("visual_wheel_radius", 0.22)), 0.12, i < 2)


# --- truck: cab, flatbed, fenders, big wheels ------------------------------

func _build_truck() -> void:
	var paint := VehicleMaterials.paint("truck")
	var worn := VehicleMaterials.paint_worn("truck")
	# flatbed chassis
	_box(chassis, Vector3(2.3, 0.18, 3.9), Vector3(0, -0.42, 0.1), worn)
	# cab block + windshield + roof
	_box(chassis, Vector3(2.35, 1.0, 1.35), Vector3(0, 0.28, -1.25), paint)
	_box(chassis, Vector3(2.1, 0.55, 0.1), Vector3(0, 0.42, -1.9), VehicleMaterials.glass(), Vector3(-0.16, 0, 0))
	_box(chassis, Vector3(2.4, 0.12, 1.4), Vector3(0, 0.84, -1.25), VehicleMaterials.cream())
	# side windows
	_box(chassis, Vector3(0.06, 0.4, 0.7), Vector3(1.19, 0.5, -1.2), VehicleMaterials.glass())
	_box(chassis, Vector3(0.06, 0.4, 0.7), Vector3(-1.19, 0.5, -1.2), VehicleMaterials.glass())
	# front bumper with hazard strip, grille, headlights
	_box(chassis, Vector3(2.5, 0.34, 0.24), Vector3(0, -0.32, -2.06), VehicleMaterials.metal())
	_box(chassis, Vector3(2.1, 0.1, 0.05), Vector3(0, -0.2, -2.2), VehicleMaterials.hazard())
	_box(chassis, Vector3(1.2, 0.4, 0.08), Vector3(0, 0.3, -1.96), VehicleMaterials.dark())
	_sphere(chassis, 0.14, Vector3(0.85, 0.05, -2.02), VehicleMaterials.lens(), Vector3(1, 0.9, 0.7))
	_sphere(chassis, 0.14, Vector3(-0.85, 0.05, -2.02), VehicleMaterials.lens(), Vector3(1, 0.9, 0.7))
	# flatbed side rails + rear gate (visual twins of the gameplay collision rails)
	_box(chassis, Vector3(0.1, 0.62, 2.4), Vector3(1.2, 0.06, 1.2), paint)
	_box(chassis, Vector3(0.1, 0.62, 2.4), Vector3(-1.2, 0.06, 1.2), paint)
	_box(chassis, Vector3(2.3, 0.62, 0.1), Vector3(0, 0.06, 2.35), worn)
	_box(chassis, Vector3(2.3, 0.05, 2.4), Vector3(0, -0.28, 1.2), VehicleMaterials.grime())
	# fenders over the rear wheels
	_box(chassis, Vector3(0.14, 0.1, 1.5), Vector3(1.22, -0.16, 1.15), VehicleMaterials.dark())
	_box(chassis, Vector3(0.14, 0.1, 1.5), Vector3(-1.22, -0.16, 1.15), VehicleMaterials.dark())
	# exhaust stack + tip, mirrors
	_cylinder(chassis, 0.08, 1.5, Vector3(1.05, 0.75, -0.45), VehicleMaterials.metal(), Vector3(0, 1, 0))
	_cylinder(chassis, 0.1, 0.16, Vector3(1.05, 1.55, -0.45), VehicleMaterials.dark(), Vector3(0, 1, 0))
	_box(chassis, Vector3(0.3, 0.24, 0.04), Vector3(1.32, 0.66, -1.8), VehicleMaterials.glass())
	_box(chassis, Vector3(0.3, 0.24, 0.04), Vector3(-1.32, 0.66, -1.8), VehicleMaterials.glass())
	var wheel_positions: Array[Vector3] = [
		Vector3(-1.14, -0.46, -1.45), Vector3(1.14, -0.46, -1.45),
		Vector3(-1.14, -0.46, 1.35), Vector3(1.14, -0.46, 1.35),
	]
	for i in wheel_positions.size():
		_wheel(chassis, wheel_positions[i], float(profile.get("visual_wheel_radius", 0.42)), 0.3, i < 2)


# --- racecar: wedge nose, halo cockpit, wing, exposed wheels ---------------

func _build_racecar() -> void:
	var paint := VehicleMaterials.paint("racecar")
	var worn := VehicleMaterials.paint_worn("racecar")
	# main tub + tapered nose (stacked boxes stepping down toward the front)
	_box(chassis, Vector3(1.3, 0.34, 2.3), Vector3(0, 0.02, 0.1), paint)
	_box(chassis, Vector3(1.0, 0.24, 0.7), Vector3(0, -0.04, -1.25), worn)
	_box(chassis, Vector3(0.6, 0.18, 0.5), Vector3(0, -0.08, -1.75), worn)
	# side pods
	_box(chassis, Vector3(0.34, 0.26, 1.1), Vector3(0.78, -0.06, 0.15), VehicleMaterials.dark())
	_box(chassis, Vector3(0.34, 0.26, 1.1), Vector3(-0.78, -0.06, 0.15), VehicleMaterials.dark())
	# engine cover + cockpit halo + canopy
	_box(chassis, Vector3(0.7, 0.3, 1.0), Vector3(0, 0.3, 0.75), worn)
	_sphere(chassis, 0.42, Vector3(0, 0.34, 0.12), VehicleMaterials.glass(), Vector3(0.8, 0.55, 0.9))
	var halo := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.42
	halo.mesh = torus
	halo.position = Vector3(0, 0.52, 0.12)
	halo.material_override = VehicleMaterials.dark()
	chassis.add_child(halo)
	# rear wing on struts
	_box(chassis, Vector3(1.5, 0.07, 0.42), Vector3(0, 0.62, 1.2), VehicleMaterials.dark(), Vector3(-0.14, 0, 0))
	_box(chassis, Vector3(0.08, 0.3, 0.3), Vector3(0.5, 0.44, 1.2), VehicleMaterials.metal())
	_box(chassis, Vector3(0.08, 0.3, 0.3), Vector3(-0.5, 0.44, 1.2), VehicleMaterials.metal())
	# twin exhausts
	_cylinder(chassis, 0.07, 0.3, Vector3(0.26, 0.12, 1.42), VehicleMaterials.metal(), Vector3(0, 0, -1))
	_cylinder(chassis, 0.07, 0.3, Vector3(-0.26, 0.12, 1.42), VehicleMaterials.metal(), Vector3(0, 0, -1))
	# nose roundel + front splitter
	_cylinder(chassis, 0.16, 0.04, Vector3(0, 0.14, -1.2), VehicleMaterials.cream(), Vector3(0, 1, 0))
	_box(chassis, Vector3(1.1, 0.06, 0.3), Vector3(0, -0.18, -1.95), VehicleMaterials.dark())
	var wheel_positions: Array[Vector3] = [
		Vector3(-0.86, -0.22, -0.85), Vector3(0.86, -0.22, -0.85),
		Vector3(-0.86, -0.22, 0.95), Vector3(0.86, -0.22, 0.95),
	]
	for i in wheel_positions.size():
		_wheel(chassis, wheel_positions[i], float(profile.get("visual_wheel_radius", 0.4)), 0.26, i < 2)