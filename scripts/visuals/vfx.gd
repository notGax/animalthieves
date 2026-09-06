class_name Vfx
extends RefCounted
## Small local-only cosmetic bursts: dust, sparkles, transform bursts.
## Purely visual - derived from already-synced state, no RPCs, no saved data.
## Positions are parent-local offsets.

static func _chunk(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emissive: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 5
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .9
	if emissive > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emissive
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	instance.material_override = mat
	parent.add_child(instance)
	return instance


static func _fly(instance: MeshInstance3D, velocity: Vector3, life: float, grow := 1.0) -> void:
	if not instance.is_inside_tree():
		instance.queue_free()
		return
	var tween := instance.create_tween()
	tween.set_parallel(true)
	tween.tween_property(instance, "position", instance.position + velocity, life).set_ease(Tween.EASE_OUT)
	tween.tween_property(instance, "scale", instance.scale * grow, life)
	tween.tween_property(instance.material_override, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(instance.queue_free)


## Puff of pale dust when a slime lands hard.
static func dust(parent: Node3D, point: Vector3, scale := 1.0) -> void:
	if parent == null:
		return
	var color := Color("e8e2d0")
	for i in range(6):
		var dir := Vector3(randf_range(-1, 1), randf_range(.3, .9), randf_range(-1, 1)).normalized()
		var chunk := _chunk(parent, point + dir * .25, Vector3.ONE * randf_range(.12, .2) * scale, color, 0.0)
		_fly(chunk, dir * randf_range(1.5, 3.0) + Vector3.UP * .6, .45, 2.2)


## Warm star-glitter for pickups and payments.
static func sparkle(parent: Node3D, point: Vector3, color := Color("fff3c4")) -> void:
	if parent == null:
		return
	for i in range(7):
		var dir := Vector3(randf_range(-1, 1), randf_range(.4, 1.2), randf_range(-1, 1)).normalized()
		var chunk := _chunk(parent, point, Vector3.ONE * randf_range(.05, .1), color, 1.8)
		_fly(chunk, dir * randf_range(2.0, 4.0), .5, .4)


## Teal ring-burst when a transformation kicks in.
static func transform_burst(parent: Node3D, point: Vector3) -> void:
	if parent == null:
		return
	var color := Color("9ef0e4")
	for i in range(10):
		var angle := TAU * i / 10.0
		var dir := Vector3(cos(angle), randf_range(.2, .6), sin(angle))
		var chunk := _chunk(parent, point, Vector3.ONE * randf_range(.08, .14), color, 1.6)
		_fly(chunk, dir * 3.5, .5, 1.6)