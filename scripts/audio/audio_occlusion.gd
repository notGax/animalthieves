class_name AudioOcclusion
extends Node

## Seals interior spaces acoustically. Godot has no built-in audio occlusion,
## so this controller raycasts from the local camera to every playing
## AudioStreamPlayer3D and, when world geometry blocks the path, swaps the
## source onto its mix bus's low-passed "Muffled" variant and ducks it.
##
## Only the "world" physics layer (2) is tested: a guard, a crate or the
## listener's own body standing in the way must not mute a sound.
##
## Volume ownership: writers that change a 3D player's loudness while it
## plays (the vehicle engine's speed modulation) store their intended value
## in the "vol_base" meta; this controller owns the final volume_db
## (= base + occlusion offset). Everyone else gets their spawn volume
## captured on first sight.

const OCCLUSION_DB := -14.0
const TICK := 0.1
const APPROACH_DB_PER_SEC := 90.0
const MIN_TEST_DISTANCE := 1.2
const WORLD_MASK := 2  # layer 2 = "world" (project.godot)

var _tracked: Array[AudioStreamPlayer3D] = []
var _clock := 0.0


func _ready() -> void:
	# Catch everything: scene-built emitters entered the tree before this
	# node, runtime players (rig hooks, one-shots) arrive via the signals.
	_sweep(get_parent())
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)


func _on_node_added(node: Node) -> void:
	if node is AudioStreamPlayer3D:
		_tracked.append(node)


func _on_node_removed(node: Node) -> void:
	if node is AudioStreamPlayer3D:
		_tracked.erase(node)


func _sweep(root: Node) -> void:
	if root is AudioStreamPlayer3D:
		_tracked.append(root)
	for child in root.get_children():
		_sweep(child)


func _physics_process(delta: float) -> void:
	_clock += delta
	if _clock < TICK:
		return
	_clock = 0.0
	refresh()


## One occlusion pass over every tracked player. Public so tests (and any
## future listener changes) can force an immediate re-evaluation.
func refresh() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return  # headless/server: no listener, nothing to gate
	var eye := camera.global_position
	var space := get_viewport().get_world_3d().direct_space_state
	for player in _tracked:
		if not is_instance_valid(player) or player.stream == null:
			continue
		var playing := player.playing and not player.stream_paused
		if not player.has_meta("was_playing"):
			player.set_meta("was_playing", false)
		if not playing:
			player.set_meta("was_playing", false)
			continue
		if not player.has_meta("vol_base"):
			player.set_meta("vol_base", player.volume_db)
		if not player.has_meta("bus_base"):
			player.set_meta("bus_base", player.bus)
		if not player.has_meta("occ_db"):
			player.set_meta("occ_db", 0.0)
		var started := playing and not bool(player.get_meta("was_playing"))
		player.set_meta("was_playing", true)
		var blocked := false
		var source := player.global_position
		if source.distance_to(eye) > MIN_TEST_DISTANCE:
			var query := PhysicsRayQueryParameters3D.create(eye, source, WORLD_MASK)
			blocked = not space.intersect_ray(query).is_empty()
		var target := OCCLUSION_DB if blocked else 0.0
		# A sound that just started behind a wall begins muffled instantly;
		# a wall that opens while it plays fades the duck back out.
		var current: float = float(player.get_meta("occ_db"))
		if started and blocked:
			current = target
		else:
			current = move_toward(current, target, APPROACH_DB_PER_SEC * TICK)
		player.set_meta("occ_db", current)
		player.volume_db = float(player.get_meta("vol_base")) + current
		var base_bus := str(player.get_meta("bus_base"))
		player.bus = Prefs.muffled_variant(base_bus) if blocked else base_bus