extends RefCounted

## World FX presentation: the elastic pop (glowing core, expanding flat ring,
## five debris sparks) and the grapple beam (additive shaft, white-hot core,
## impact tip). Shared geometry and base materials are cached once per class
## and never mutated; only the two fading materials are duplicated per burst.
## Callers own the live-burst array so the cap bookkeeping is shared by both
## effects and spammy RPCs can never flood the scene graph.

const CAP := 40

static var _sphere: SphereMesh
static var _torus: TorusMesh
static var _shaft: CylinderMesh
static var _core: CylinderMesh
static var _mats: Dictionary = {}
static var _white: StandardMaterial3D


static func unit_sphere() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 1.0
		_sphere.height = 2.0
		_sphere.radial_segments = 12
		_sphere.rings = 7
	return _sphere


static func unit_torus() -> TorusMesh:
	if _torus == null:
		_torus = TorusMesh.new()
		_torus.inner_radius = .88
		_torus.outer_radius = 1.1
		_torus.rings = 32
		_torus.ring_segments = 8
	return _torus


static func beam_mesh() -> CylinderMesh:
	if _shaft == null:
		_shaft = CylinderMesh.new()
		_shaft.top_radius = .075
		_shaft.bottom_radius = .075
		_shaft.height = 1.0
		_shaft.radial_segments = 6
		_shaft.rings = 0
	return _shaft


static func beam_core_mesh() -> CylinderMesh:
	if _core == null:
		_core = CylinderMesh.new()
		_core.top_radius = .028
		_core.bottom_radius = .028
		_core.height = 1.0
		_core.radial_segments = 6
		_core.rings = 0
	return _core


static func base_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = .8
		_mats[key] = mat
	return _mats[key]


static func beam_core_material() -> StandardMaterial3D:
	if _white == null:
		_white = StandardMaterial3D.new()
		_white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_white.albedo_color = Color(1,1,.85,.9)
		_white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_white.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return _white


static func _prune(live: Array) -> void:
	while live.size() >= CAP:
		var stale: Node = live.pop_front()
		if is_instance_valid(stale):
			stale.queue_free()


## Elastic pop: glowing core, expanding flat ring, five debris sparks.
static func pop(host: Node3D, live: Array, point: Vector3, color: Color, size: float) -> void:
	_prune(live)
	var root := Node3D.new()
	root.position = point
	host.add_child(root)
	live.append(root)
	var burst_mat: StandardMaterial3D = base_material(color).duplicate()
	burst_mat.emission_enabled = true
	burst_mat.emission = color
	burst_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var core := MeshInstance3D.new()
	core.mesh = unit_sphere()
	core.scale = Vector3.ONE * size
	core.material_override = burst_mat
	root.add_child(core)
	var ring := MeshInstance3D.new()
	ring.mesh = unit_torus()
	ring.rotation.x = PI * .5
	ring.scale = Vector3.ONE * size * .15
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(color.r, color.g, color.b, .9)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_mat
	root.add_child(ring)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, "scale", Vector3.ONE * size * 1.9, .34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst_mat, "albedo_color:a", 0.0, .32)
	tween.tween_property(ring, "scale", Vector3.ONE * size * 2.3, .4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, .4)
	for i in range(5):
		var spark := MeshInstance3D.new()
		spark.mesh = unit_sphere()
		spark.scale = Vector3.ONE * size * .16
		spark.material_override = burst_mat
		root.add_child(spark)
		var angle := TAU * i / 5.0
		var drift := Vector3(cos(angle), .7, sin(angle)).normalized() * (size * 1.6)
		tween.tween_property(spark, "position", drift, .4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "scale", Vector3.ONE * size * .05, .4)
	tween.chain().tween_callback(func():
		live.erase(root)
		root.queue_free())


## Oriented additive shaft with a white-hot core and an impact tip. Both
## shafts are shared unit cylinders stretched along their length.
static func beam(host: Node3D, live: Array, from: Vector3, to: Vector3, color: Color) -> void:
	var offset := to - from
	if offset.length() < .01:
		return
	_prune(live)
	var root := Node3D.new()
	root.position = from
	host.add_child(root)
	live.append(root)
	var dir := offset.normalized()
	var length := offset.length()
	var body := MeshInstance3D.new()
	body.mesh = beam_mesh()
	body.position = offset * .5
	body.scale = Vector3(1, length, 1)
	body.quaternion = Quaternion(Vector3.UP, dir)
	var middle := MeshInstance3D.new()
	middle.mesh = beam_core_mesh()
	middle.position = body.position
	middle.quaternion = body.quaternion
	middle.scale = body.scale
	var glow_mat: StandardMaterial3D = base_material(color).duplicate()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(color.r, color.g, color.b, .85)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	body.material_override = glow_mat
	var core_mat: StandardMaterial3D = beam_core_material().duplicate()
	middle.material_override = core_mat
	root.add_child(body)
	root.add_child(middle)
	var tip := MeshInstance3D.new()
	tip.mesh = unit_sphere()
	tip.position = offset
	tip.scale = Vector3.ONE * .3
	tip.material_override = glow_mat
	root.add_child(tip)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(glow_mat, "albedo_color:a", 0.0, .22)
	tween.tween_property(core_mat, "albedo_color:a", 0.0, .16)
	tween.tween_property(body, "scale", Vector3(1.8, length, 1.8), .22)
	tween.tween_property(middle, "scale", Vector3(1.2, length, 1.2), .22)
	tween.tween_property(tip, "scale", Vector3.ONE * .9, .22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func():
		live.erase(root)
		root.queue_free())
