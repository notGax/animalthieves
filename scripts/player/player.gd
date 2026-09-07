class_name Character
extends CharacterBody3D

enum SkinColor { BLUE, YELLOW, GREEN, RED }

# Locomotion tuning. Planar velocity is split into a controlled locomotion
# channel and a decaying, capped external channel (grapple pulls, knockback,
# jetpack); only their sum ever reaches move_and_slide(), so external pushes
# can never accumulate into the locomotion state.
const WALK_SPEED = 6.0
const SPRINT_SPEED = 9.2
const GROUND_ACCELERATION = 26.0
const GROUND_DECELERATION = 30.0
const AIR_ACCELERATION = 9.0
const AIR_MAX_SPEED = 10.0
const AIR_DRAG = 1.5
const JUMP_VELOCITY = 7.5
const COYOTE_TIME = 0.1
const JUMP_BUFFER_TIME = 0.12
const ASCENT_GRAVITY_MULTIPLIER = 1.0
const RELEASE_GRAVITY_MULTIPLIER = 2.0
const FALL_GRAVITY_MULTIPLIER = 1.45
const MAX_EXTERNAL_PLANAR_SPEED = 16.0
const EXTERNAL_PLANAR_DECELERATION = 22.0
const MAX_COMBINED_PLANAR_SPEED = 20.0
const MAX_IMPULSE_VERTICAL_SPEED = 18.0
const HARD_LANDING_SPEED = 14.0
const LANDING_SOFTNESS_TIME = 0.3
const BASE_NICKNAME_HEIGHT := 2.0
const SERVER_ANIMATION_REQUESTS_PER_SECOND := 10.0
const SERVER_ANIMATION_REQUEST_BURST := 6.0
const PICKUP_ANIMATION_DELAY_MSEC := 1000
const PICKUP_ANIMATION_WINDOW_MSEC := 2500
const PICKUP_REQUEST_COOLDOWN_MSEC := 1000
const ALLOWED_ANIMATION_STATES := {
	&"Idle": true,
	&"Run": true,
	&"Sprint": true,
	&"Jump": true,
	&"Fall": true,
	&"Attack1": true,
	&"Emote2": true
}
const HAT_NODES_BY_ITEM := {
	"fedora": "Fedora",
	"headphones": "Headphones",
	"pirate_hat": "PirateHat",
	"sheriff_hat": "SheriffHat",
	"sombrero": "Sombrero",
	"wizard_hat": "WizardHat"
}
const WEAPON_NODES_BY_ITEM := {"sword": "Sword", "sword_big": "SwordBig", "axe": "Axe"}
const BACKPACK_NODES_BY_ITEM := {"backpack": "Backpack"}
const HEAD_EQUIPMENT_PATH := "GodotRobot3D/RobotArmature/Skeleton3D/HeadAttach/"
const HAND_EQUIPMENT_PATH := "GodotRobot3D/RobotArmature/Skeleton3D/LeftHandAttach/"
const BACK_EQUIPMENT_PATH := "GodotRobot3D/RobotArmature/Skeleton3D/BackAttach/"
const FIRST_PERSON_HIDDEN_BONES: Array[StringName] = [&"Head", &"HeadTop"]

@export var skin_color: SkinColor = SkinColor.BLUE

@export_category("Nickname")
@export_range(0.0, 1.0, 0.01) var nickname_clearance: float = 0.2

@export_category("Objects")
@export var _body: Node3D = null
@export var _spring_arm_offset: SpringArmCharacter = null

@export_category("Skin Colors")
@export var blue_texture: CompressedTexture2D
@export var yellow_texture: CompressedTexture2D
@export var green_texture: CompressedTexture2D
@export var red_texture: CompressedTexture2D

var player_inventory: PlayerInventory
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_attacking := false
var is_collecting := false
var external_velocity := Vector3.ZERO
var _locomotion := Vector2.ZERO
var _coyote_clock := 0.0
var _jump_buffer_clock := 0.0
var _landing_softness := 0.0

var _spawn_point = Vector3(0, 5, 0)
var _animation_sequence := 0
var _last_applied_animation_sequence := 0
var _last_requested_animation: StringName = &""
var _appearance_sync_requesters: Dictionary = {}
var _server_animation_request_tokens := SERVER_ANIMATION_REQUEST_BURST
var _last_server_animation_token_update_msec := 0
var _server_pickup_animation_started_msec := -1
var _last_server_pickup_request_msec := -PICKUP_REQUEST_COOLDOWN_MSEC
var _pickup_area_camera_yaw_offset := 0.0
var _equipped_hat_visual_id := ""

@onready var nickname: Label3D = $PlayerNick/Nickname

@onready var _bottom_mesh: MeshInstance3D = get_node("GodotRobot3D/RobotArmature/Skeleton3D/Bottom")
@onready var _chest_mesh: MeshInstance3D = get_node("GodotRobot3D/RobotArmature/Skeleton3D/Chest")
@onready var _face_mesh: MeshInstance3D = get_node("GodotRobot3D/RobotArmature/Skeleton3D/Face")
@onready var _limbs_head_mesh: MeshInstance3D = get_node("GodotRobot3D/RobotArmature/Skeleton3D/LimbsAndHead")
@onready var _skeleton: Skeleton3D = get_node("GodotRobot3D/RobotArmature/Skeleton3D")
@onready var _pickup_area: Area3D = $GodotRobot3D/InfrontArea3D
@onready var _first_person_hud: CanvasLayer = $FirstPersonHUD


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	$SpringArmOffset/SpringArm3D/Camera3D.current = is_multiplayer_authority()


func _ready():
	var slime := preload("res://scripts/heist/slime_visual.gd").new()
	slime.name = "SlimeVisual"
	add_child(slime)
	var hands := preload("res://scripts/heist/first_person_hands.gd").new()
	hands.name = "FirstPersonHands"
	$SpringArmOffset/SpringArm3D/Camera3D.add_child(hands)
	collision_mask = 31
	if multiplayer.is_server():
		player_inventory = PlayerInventory.new()
		_add_starting_items()
		call_deferred("_sync_equipment_appearance")
		if not is_multiplayer_authority():
			call_deferred("_sync_inventory_to_owner")

	set_player_skin(skin_color)
	var animation_player := get_node_or_null("GodotRobot3D/AnimationPlayer") as AnimationPlayer
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
	_body.play_animation_state(&"Idle")
	nickname.visible = true
	_set_nickname_height(BASE_NICKNAME_HEIGHT)
	call_deferred("_update_nickname_height")
	if not multiplayer.is_server():
		call_deferred("_request_equipment_appearance")
	if is_multiplayer_authority() and _spring_arm_offset:
		_pickup_area_camera_yaw_offset = wrapf(
			_pickup_area.global_rotation.y - _spring_arm_offset.global_rotation.y, -PI, PI
		)
		_spring_arm_offset.perspective_changed.connect(_on_camera_perspective_changed)
		_on_camera_perspective_changed(_spring_arm_offset.is_first_person)


func _on_camera_perspective_changed(first_person: bool) -> void:
	if not is_multiplayer_authority():
		return
	_body.visible = true
	_bottom_mesh.visible = not first_person
	_chest_mesh.visible = not first_person
	_face_mesh.visible = not first_person
	_limbs_head_mesh.visible = true
	nickname.visible = not first_person
	_first_person_hud.visible = first_person
	for bone_name in FIRST_PERSON_HIDDEN_BONES:
		var bone_index := _skeleton.find_bone(bone_name)
		if bone_index >= 0:
			_skeleton.set_bone_pose_scale(bone_index, Vector3.ZERO if first_person else Vector3.ONE)
	if first_person:
		_align_pickup_area_with_camera()
	else:
		_pickup_area.rotation = Vector3.ZERO
		call_deferred("_refresh_nickname_height_after_perspective_change")


func _refresh_nickname_height_after_perspective_change() -> void:
	if not is_multiplayer_authority() or _is_local_first_person():
		return
	var height := _calculate_nickname_height(_equipped_hat_visual_id)
	_set_nickname_height(height)
	nickname.visible = true
	if multiplayer.is_server():
		_broadcast_nickname_height(height)


func _align_pickup_area_with_camera() -> void:
	var pickup_rotation := _pickup_area.global_rotation
	pickup_rotation.y = wrapf(_spring_arm_offset.global_rotation.y + _pickup_area_camera_yaw_offset, -PI, PI)
	_pickup_area.global_rotation = pickup_rotation


func _physics_process(delta):
	if not multiplayer.has_multiplayer_peer() or not is_multiplayer_authority():
		return

	var world := get_node_or_null("/root/Level/Environment/HeistWorld")
	if world:
		var state: Dictionary = world.player_state.get(str(name), {})
		if float(state.get("hp", 100)) <= 0 or state.get("vehicle", "") != "":
			_locomotion = Vector2.ZERO
			external_velocity = Vector3.ZERO
			velocity = Vector3.ZERO
			return
	var current_scene = get_tree().get_current_scene()
	var should_freeze = false
	if current_scene:
		if current_scene.has_method("is_gameplay_input_blocked") and current_scene.is_gameplay_input_blocked():
			should_freeze = true
		elif current_scene.has_method("is_chat_visible") and current_scene.is_chat_visible():
			should_freeze = true
		elif current_scene.has_method("is_inventory_visible") and current_scene.is_inventory_visible():
			should_freeze = true

	if is_attacking or is_collecting:
		_locomotion = Vector2.ZERO
		_apply_gravity(delta, true)
		velocity.x = external_velocity.x
		velocity.z = external_velocity.z
		move_and_slide()
		_decay_external(delta)
		return

	if should_freeze:
		_freeze()
		_apply_gravity(delta, true)
		move_and_slide()
		_request_animation(_body.get_movement_animation(velocity))
		return

	if Input.is_action_just_pressed("pickup") and is_on_floor() and _has_collectible_item_in_front():
		is_collecting = true
		_request_animation(&"Emote2", true)
		return

	if Input.is_action_just_pressed("attack") and is_on_floor():
		_start_attack()
		return

	_movement_step(delta, Input.get_vector("move_left", "move_right", "move_forward", "move_backward"),
		Input.is_action_just_pressed("jump"), Input.is_action_pressed("jump"))
	if get_slide_collision_count() > 0:
		_push_collided_items()

	_request_animation(_body.get_movement_animation(velocity))


## One physics step of the normal movement loop, with inputs passed in so the
## whole model stays testable without synthesizing engine input events.
func _movement_step(delta: float, input_direction: Vector2, jump_buffered: bool, jump_held: bool) -> void:
	_coyote_clock = COYOTE_TIME if is_on_floor() else maxf(0.0, _coyote_clock - delta)
	_jump_buffer_clock = JUMP_BUFFER_TIME if jump_buffered else maxf(0.0, _jump_buffer_clock - delta)
	_landing_softness = maxf(0.0, _landing_softness - delta)
	_apply_gravity(delta, jump_held)
	# Exactly one jump impulse: consumed buffer, coyote-gated, never in midair.
	if _jump_buffer_clock > 0.0 and _coyote_clock > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_clock = 0.0
		_coyote_clock = 0.0
		_request_animation(&"Jump", true)
	_apply_locomotion(delta, input_direction, jump_held)
	var fall_speed := maxf(0.0, -velocity.y) if not is_on_floor() else 0.0
	velocity.x = _locomotion.x + external_velocity.x
	velocity.z = _locomotion.y + external_velocity.z
	var combined := Vector2(velocity.x, velocity.z)
	if combined.length() > MAX_COMBINED_PLANAR_SPEED:
		combined = combined.normalized() * MAX_COMBINED_PLANAR_SPEED
		velocity.x = combined.x
		velocity.z = combined.y
	move_and_slide()
	_decay_external(delta)
	# Severe landings briefly soften acceleration - a breath, never a lock.
	if is_on_floor() and fall_speed > HARD_LANDING_SPEED:
		_landing_softness = LANDING_SOFTNESS_TIME


func _apply_locomotion(delta: float, input_direction: Vector2, jump_held: bool) -> void:
	var speed := _target_speed()
	var direction: Vector3 = transform.basis * Vector3(input_direction.x, 0, input_direction.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	direction = direction.rotated(Vector3.UP, _spring_arm_offset.rotation.y)
	var world := get_node_or_null("/root/Level/Environment/HeistWorld")
	if world and world.player_state.get(str(name), {}).get("form", "") == "bird" \
			and not is_on_floor() and jump_held:
		velocity.y = maxf(velocity.y, -1.5)
	var target := Vector2(direction.x, direction.z) * speed
	var softness := 0.45 if _landing_softness > 0.0 else 1.0
	if is_on_floor():
		var rate: float = (GROUND_ACCELERATION if target != Vector2.ZERO else GROUND_DECELERATION) * softness
		_locomotion = _locomotion.move_toward(target, rate * delta)
	elif target != Vector2.ZERO:
		# Air control steers without granting speed: momentum above the cap is
		# preserved, and the ceiling never exceeds what the ground granted.
		_locomotion = _locomotion.move_toward(target, AIR_ACCELERATION * delta)
		var ceiling := maxf(AIR_MAX_SPEED, Vector2(_locomotion.x, _locomotion.y).length())
		if _locomotion.length() > ceiling:
			_locomotion = _locomotion.normalized() * ceiling
	else:
		_locomotion = _locomotion.move_toward(Vector2.ZERO, AIR_DRAG * delta)
	if target != Vector2.ZERO:
		_body.apply_rotation(Vector3(_locomotion.x, 0, _locomotion.y))


func _target_speed() -> float:
	var speed: float = SPRINT_SPEED if Input.is_action_pressed("shift") else WALK_SPEED
	var world := get_node_or_null("/root/Level/Environment/HeistWorld")
	if world:
		var state: Dictionary = world.player_state.get(str(name), {})
		if float(state.get("speed_buff", 0)) > 0:
			speed *= 1.45
		if state.get("form", "") == "rat":
			speed *= 1.15
	return speed


## One-shot external push: grapple pull, knockback, jetpack. The planar part
## feeds the capped, decaying external channel so repeated impulses can never
## compound into runaway speed; the vertical part applies exactly once.
func apply_external_impulse(impulse: Vector3) -> void:
	if not impulse.is_finite():
		return
	var blended := (Vector2(external_velocity.x, external_velocity.z)
		+ Vector2(impulse.x, impulse.z).limit_length(MAX_EXTERNAL_PLANAR_SPEED))
	if blended.length() > MAX_EXTERNAL_PLANAR_SPEED:
		blended = blended.normalized() * MAX_EXTERNAL_PLANAR_SPEED
	external_velocity.x = blended.x
	external_velocity.z = blended.y
	external_velocity.y = clampf(maxf(external_velocity.y, impulse.y), 0.0, MAX_IMPULSE_VERTICAL_SPEED)
	velocity.y = clampf(velocity.y + impulse.y, -50.0, MAX_IMPULSE_VERTICAL_SPEED)


func _decay_external(delta: float) -> void:
	# Planar and vertical decay separately: the vertical channel only exists
	# for camera feedback and must never eat the planar decay budget.
	var planar := Vector2(external_velocity.x, external_velocity.z).move_toward(
		Vector2.ZERO, EXTERNAL_PLANAR_DECELERATION * delta)
	external_velocity.x = planar.x
	external_velocity.z = planar.y
	external_velocity.y = move_toward(external_velocity.y, 0.0, EXTERNAL_PLANAR_DECELERATION * 1.5 * delta)


func _apply_gravity(delta: float, jump_held: bool = true) -> void:
	if is_on_floor():
		return
	var gravity_multiplier := FALL_GRAVITY_MULTIPLIER
	if velocity.y > 0.0:
		gravity_multiplier = ASCENT_GRAVITY_MULTIPLIER if jump_held else RELEASE_GRAVITY_MULTIPLIER
	velocity.y -= gravity * gravity_multiplier * delta


func _start_attack() -> void:
	if is_attacking or is_collecting or not is_on_floor():
		return
	is_attacking = true
	_locomotion = Vector2.ZERO
	_request_animation(&"Attack1", true)


func _on_animation_finished(animation_name: StringName) -> void:
	match animation_name:
		&"Attack1":
			is_attacking = false
		&"Emote2":
			is_collecting = false


func _request_animation(state: StringName, restart: bool = false) -> void:
	if not ALLOWED_ANIMATION_STATES.has(state):
		return
	if not restart and _last_requested_animation == state:
		return
	_last_requested_animation = state
	_body.play_animation_state(state, restart)
	if multiplayer.is_server():
		request_animation_state(state)
	else:
		request_animation_state.rpc_id(1, state)


@rpc("any_peer", "call_local", "reliable")
func request_animation_state(state: StringName) -> void:
	if not multiplayer.is_server() or not _is_owner_request():
		return
	if not ALLOWED_ANIMATION_STATES.has(state):
		return
	if not _server_consume_animation_request_token():
		return
	if state == &"Emote2":
		if not _is_grounded_on_server() or not _has_collectible_item_in_front():
			return
		_server_pickup_animation_started_msec = Time.get_ticks_msec()
	else:
		_server_pickup_animation_started_msec = -1
	_server_publish_animation(state)


func _server_consume_animation_request_token() -> bool:
	var now := Time.get_ticks_msec()
	if _last_server_animation_token_update_msec == 0:
		_last_server_animation_token_update_msec = now
	else:
		var elapsed_seconds := (now - _last_server_animation_token_update_msec) / 1000.0
		_server_animation_request_tokens = minf(
			SERVER_ANIMATION_REQUEST_BURST,
			_server_animation_request_tokens + elapsed_seconds * SERVER_ANIMATION_REQUESTS_PER_SECOND
		)
		_last_server_animation_token_update_msec = now

	if _server_animation_request_tokens < 1.0:
		return false
	_server_animation_request_tokens -= 1.0
	return true


func _server_publish_animation(state: StringName) -> void:
	if not multiplayer.is_server():
		return
	_animation_sequence += 1
	sync_animation_state.rpc(state, _animation_sequence)
	sync_animation_state(state, _animation_sequence)


@rpc("any_peer", "call_local", "reliable")
func sync_animation_state(state: StringName, sequence: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != 1 and not (sender_id == 0 and multiplayer.is_server()):
		return
	if sequence <= _last_applied_animation_sequence:
		return
	_last_applied_animation_sequence = sequence

	if not ALLOWED_ANIMATION_STATES.has(state):
		return

	# The owner already played the input-driven state immediately.
	if is_multiplayer_authority():
		return
	_body.play_animation_state(state, true)


func _push_collided_items() -> void:
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			apply_force_to_server_object.rpc_id(1, c.get_collider().name, -c.get_normal())


func _process(_delta):
	if not multiplayer.has_multiplayer_peer():
		return
	if not is_multiplayer_authority():
		return
	var first_person := _spring_arm_offset != null and _spring_arm_offset.is_first_person
	if first_person:
		_align_pickup_area_with_camera()
	var camera_input_blocked := false
	var current_scene := get_tree().get_current_scene()
	if current_scene and current_scene.has_method("is_camera_input_blocked"):
		camera_input_blocked = current_scene.is_camera_input_blocked()
	_first_person_hud.visible = (
		first_person and not camera_input_blocked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)
	_check_out_of_bounds()


func _freeze():
	_locomotion = Vector2.ZERO
	external_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	_request_animation(&"Idle")


func _is_running() -> bool:
	return Input.is_action_pressed("shift")


func _check_out_of_bounds():
	if global_transform.origin.y < -15.0:
		_reset_position_after_fall()


func _reset_position_after_fall():
	global_transform.origin = _spawn_point
	velocity = Vector3.ZERO


func _get_texture_from_name(color: SkinColor) -> CompressedTexture2D:
	match color:
		SkinColor.BLUE:
			return blue_texture
		SkinColor.GREEN:
			return green_texture
		SkinColor.RED:
			return red_texture
		SkinColor.YELLOW:
			return yellow_texture
		_:
			return blue_texture


func set_player_skin(skin_name: SkinColor) -> void:
	skin_color = skin_name
	var texture = _get_texture_from_name(skin_name)

	_set_mesh_texture(_bottom_mesh, texture)
	_set_mesh_texture(_chest_mesh, texture)
	_set_mesh_texture(_face_mesh, texture)
	_set_mesh_texture(_limbs_head_mesh, texture)

	# Repaint the procedural avatars if they are already built.
	for visual in [get_node_or_null("SlimeVisual"), get_node_or_null("SpringArmOffset/SpringArm3D/Camera3D/FirstPersonHands")]:
		if visual and visual.has_method("apply_skin"):
			visual.apply_skin(skin_name)


func _set_mesh_texture(mesh_instance: MeshInstance3D, texture: CompressedTexture2D) -> void:
	if mesh_instance:
		var new_material := StandardMaterial3D.new()
		new_material.albedo_texture = texture
		mesh_instance.set_surface_override_material(0, new_material)


@rpc("any_peer", "call_local", "reliable")
func sync_inventory_to_owner(inventory_data: Dictionary):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != 1 and not (sender_id == 0 and multiplayer.is_server()):
		return

	if not is_multiplayer_authority():
		return

	if not player_inventory:
		player_inventory = PlayerInventory.new()
	player_inventory.from_dict(inventory_data)

	var level_scene = get_tree().get_current_scene()
	if (
		level_scene
		and get_multiplayer_authority() == multiplayer.get_unique_id()
		and level_scene.has_method("update_local_inventory_display")
	):
		level_scene.update_local_inventory_display()


@rpc("any_peer", "call_local", "reliable")
func request_move_item(from_slot: int, to_slot: int, quantity: int = -1):
	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if not _is_owner_request():
		push_warning(
			(
				"Client "
				+ str(requesting_client)
				+ " tried to modify inventory for player "
				+ str(get_multiplayer_authority())
			)
		)
		return

	if not player_inventory:
		return

	if not player_inventory.is_slot_active(from_slot) or not player_inventory.is_slot_active(to_slot):
		push_warning("Invalid slot indices: from=" + str(from_slot) + " to=" + str(to_slot))
		return

	if quantity != -1 and quantity <= 0:
		push_warning("Invalid move quantity: " + str(quantity))
		return

	var success = false
	if quantity == -1:
		success = player_inventory.move_item(from_slot, to_slot)
		if not success:
			success = player_inventory.swap_items(from_slot, to_slot)
	else:
		success = player_inventory.move_item(from_slot, to_slot, quantity)

	if success:
		_sync_inventory_to_owner()


@rpc("any_peer", "call_local", "reliable")
func request_add_item(item_id: String, quantity: int = 1):
	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	var is_local_server_call = requesting_client == 0 and multiplayer.get_unique_id() == 1
	if requesting_client != 1 and not is_local_server_call:
		push_warning(
			"Client " + str(requesting_client) + " tried to add items to player " + str(get_multiplayer_authority())
		)
		return

	if not player_inventory:
		return

	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return

	var item = ItemDatabase.get_item(item_id)
	if not item:
		push_warning("Item not found: " + item_id)
		return

	var remaining = player_inventory.add_item(item, quantity)
	var added = quantity - remaining

	if added > 0:
		_sync_inventory_to_owner()


func request_add_single_item(item_id: String) -> bool:
	if not multiplayer.is_server():
		return false

	if player_inventory == null:
		return false

	var item = ItemDatabase.get_item(item_id)
	if not item:
		push_warning("Item not found: " + item_id)
		return false

	var remaining = player_inventory.add_item(item, 1)

	if remaining == 0:
		_sync_inventory_to_owner()
		return true
	return false


@rpc("any_peer", "call_local", "reliable")
func request_remove_item(item_id: String, quantity: int = 1):
	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if not _is_owner_request():
		push_warning(
			(
				"Client "
				+ str(requesting_client)
				+ " tried to remove items from player "
				+ str(get_multiplayer_authority())
			)
		)
		return

	if not player_inventory:
		return

	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return

	var removed = player_inventory.remove_item(item_id, quantity)

	if removed > 0:
		_sync_inventory_to_owner()


@rpc("authority", "call_local", "reliable")
func add_world_item(scene_path: String, player_position: Vector3) -> void:
	var item_container = get_node_or_null("/root/Level/Environment/ItemContainer")
	if not item_container:
		push_warning("ItemContainer not found at /root/Level/Environment/ItemContainer")
		return
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("Cannot add world item: invalid scene path '" + scene_path + "'")
		return
	var packed_scene = load(scene_path) as PackedScene
	if not packed_scene:
		push_warning("Cannot add world item: scene path is not a PackedScene '" + scene_path + "'")
		return
	var instance_item := packed_scene.instantiate() as Node3D
	if not instance_item:
		push_warning("Cannot add world item: scene root is not a Node3D '" + scene_path + "'")
		return
	item_container.add_child(instance_item, true)
	instance_item.global_position = player_position


func get_inventory() -> PlayerInventory:
	return player_inventory


func _sync_inventory_to_owner() -> void:
	if not multiplayer.is_server() or not player_inventory:
		return
	var owner_id = get_multiplayer_authority()
	if owner_id == 1:
		sync_inventory_to_owner(player_inventory.to_dict())
	else:
		sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())


@rpc("any_peer", "call_local", "reliable")
func request_equip_item(from_slot: int, item_type: Item.ItemType) -> void:
	if not multiplayer.is_server() or not _is_owner_request():
		return
	if not player_inventory or not player_inventory.is_slot_active(from_slot):
		return
	if item_type != Item.ItemType.WEAPON and item_type != Item.ItemType.HAT and item_type != Item.ItemType.BACKPACK:
		return
	if player_inventory.equip_from_slot(from_slot, item_type):
		_sync_inventory_to_owner()
		_sync_equipment_appearance()


@rpc("any_peer", "call_local", "reliable")
func request_unequip_item(item_type: Item.ItemType, destination_slot: int = -1) -> void:
	if not multiplayer.is_server() or not _is_owner_request():
		return
	if not player_inventory:
		return
	if item_type != Item.ItemType.WEAPON and item_type != Item.ItemType.HAT and item_type != Item.ItemType.BACKPACK:
		return
	if destination_slot < -1 or destination_slot >= PlayerInventory.MAX_INVENTORY_SIZE:
		return
	if destination_slot >= 0 and not player_inventory.is_slot_active(destination_slot):
		return
	if player_inventory.unequip_to_slot(item_type, destination_slot):
		_sync_inventory_to_owner()
		_sync_equipment_appearance()


func _is_owner_request() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	return sender == get_multiplayer_authority() or (sender == 0 and multiplayer.is_server())


func _sync_equipment_appearance() -> void:
	if not multiplayer.is_server() or not player_inventory:
		return
	var weapon_id := player_inventory.equipped_weapon.item_id
	var hat_id := player_inventory.equipped_hat.item_id
	var backpack_id := player_inventory.equipped_backpack.item_id
	var nickname_height := _calculate_nickname_height(hat_id)
	_broadcast_nickname_height(nickname_height)
	sync_equipment_appearance.rpc(weapon_id, hat_id, backpack_id)
	sync_equipment_appearance(weapon_id, hat_id, backpack_id)


func _request_equipment_appearance() -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		return
	request_equipment_appearance.rpc_id(1)


@rpc("any_peer", "reliable")
func request_equipment_appearance() -> void:
	if not multiplayer.is_server() or not player_inventory:
		return
	var requester_id := multiplayer.get_remote_sender_id()
	if requester_id <= 0:
		return
	if _appearance_sync_requesters.has(requester_id):
		return
	_appearance_sync_requesters[requester_id] = true
	_sync_equipment_appearance_to_peer(requester_id)


func _sync_equipment_appearance_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server() or not player_inventory or peer_id <= 0:
		return
	var weapon_id := player_inventory.equipped_weapon.item_id
	var hat_id := player_inventory.equipped_hat.item_id
	var backpack_id := player_inventory.equipped_backpack.item_id
	sync_equipment_appearance.rpc_id(peer_id, weapon_id, hat_id, backpack_id)


@rpc("any_peer", "reliable")
func sync_equipment_appearance(weapon_id: String, hat_id: String, backpack_id: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1 and not (sender == 0 and multiplayer.is_server()):
		return
	_set_equipment_visibility(weapon_id, hat_id, backpack_id)


func _set_equipment_visibility(weapon_id: String, hat_id: String, backpack_id: String) -> void:
	_equipped_hat_visual_id = hat_id
	_set_equipment_nodes_visibility(HEAD_EQUIPMENT_PATH, HAT_NODES_BY_ITEM, hat_id)
	_set_equipment_nodes_visibility(HAND_EQUIPMENT_PATH, WEAPON_NODES_BY_ITEM, weapon_id)
	_set_equipment_nodes_visibility(BACK_EQUIPMENT_PATH, BACKPACK_NODES_BY_ITEM, backpack_id)


func _broadcast_nickname_height(height: float) -> void:
	if not multiplayer.is_server():
		return
	var level_scene := get_tree().get_current_scene()
	if level_scene and level_scene.has_method("register_player_nickname_height"):
		level_scene.register_player_nickname_height(get_multiplayer_authority(), height)


func _set_equipment_nodes_visibility(parent_path: String, nodes_by_item: Dictionary, equipped_item_id: String) -> void:
	for item_id in nodes_by_item:
		var equipment := get_node_or_null(parent_path + str(nodes_by_item[item_id])) as Node3D
		if equipment:
			equipment.visible = item_id == equipped_item_id


func _update_nickname_height(hat_id: String = "") -> void:
	if not nickname:
		return
	nickname.visible = not _is_local_first_person()
	_set_nickname_height(_calculate_nickname_height(hat_id))


func _calculate_nickname_height(hat_id: String) -> float:
	var target_height := BASE_NICKNAME_HEIGHT
	var equipped_hat := _get_hat_node(hat_id)
	if equipped_hat:
		var hat_top := _get_visual_top(equipped_hat)
		if hat_top > -INF and hat_top < INF:
			target_height = max(BASE_NICKNAME_HEIGHT, hat_top + nickname_clearance)
	return target_height


func _set_nickname_height(height: float) -> void:
	var nickname_position := nickname.position
	nickname_position.y = height
	nickname.position = nickname_position


func apply_synced_nickname_height(height: float) -> void:
	if not nickname:
		return
	nickname.visible = not _is_local_first_person()
	if height > -INF and height < INF:
		_set_nickname_height(maxf(BASE_NICKNAME_HEIGHT, height))
	else:
		_set_nickname_height(BASE_NICKNAME_HEIGHT)


func _is_local_first_person() -> bool:
	return is_multiplayer_authority() and _spring_arm_offset != null and _spring_arm_offset.is_first_person


func get_current_nickname_height() -> float:
	return nickname.position.y if nickname else BASE_NICKNAME_HEIGHT


func _get_hat_node(hat_id: String) -> Node3D:
	if HAT_NODES_BY_ITEM.has(hat_id):
		var requested_hat_path := HEAD_EQUIPMENT_PATH + str(HAT_NODES_BY_ITEM[hat_id])
		var requested_hat := get_node_or_null(requested_hat_path) as Node3D
		if requested_hat:
			return requested_hat
	return null


func _get_visual_top(root: Node3D) -> float:
	var visual_top := -INF
	if root is MeshInstance3D:
		visual_top = _get_mesh_top(root as MeshInstance3D)

	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance:
			visual_top = max(visual_top, _get_mesh_top(mesh_instance))
	return visual_top


func _get_mesh_top(mesh_instance: MeshInstance3D) -> float:
	var visual_top := -INF
	var mesh_bounds := mesh_instance.get_aabb()
	for endpoint_index in range(8):
		var endpoint_global := mesh_instance.to_global(mesh_bounds.get_endpoint(endpoint_index))
		visual_top = max(visual_top, to_local(endpoint_global).y)
	return visual_top


func _add_starting_items():
	if not player_inventory:
		return

	var backpack := ItemDatabase.get_item("backpack")
	if backpack:
		player_inventory.add_item(backpack, 1)

	var starting_item_ids: Array[String] = ["rotten_cheese", "canned_food"]

	for item_id in starting_item_ids:
		var item = ItemDatabase.get_item(item_id)
		if item:
			player_inventory.add_item(item, 1)


func pickup() -> void:
	if multiplayer.is_server():
		request_pickup()
	else:
		request_pickup.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func request_pickup() -> void:
	if not multiplayer.is_server() or not _is_owner_request():
		return
	var now := Time.get_ticks_msec()
	if now - _last_server_pickup_request_msec < PICKUP_REQUEST_COOLDOWN_MSEC:
		return
	_last_server_pickup_request_msec = now

	var animation_elapsed := now - _server_pickup_animation_started_msec
	if (
		_server_pickup_animation_started_msec < 0
		or animation_elapsed < PICKUP_ANIMATION_DELAY_MSEC
		or animation_elapsed > PICKUP_ANIMATION_WINDOW_MSEC
	):
		return
	if not _is_grounded_on_server():
		return
	if not _has_collectible_item_in_front():
		return
	_server_pickup_animation_started_msec = -1
	_server_pickup()


func _server_pickup() -> void:
	for item in _get_collectible_items_in_front():
		var result := request_add_single_item(item.item_id)
		if result and item.is_inside_tree():
			item.queue_free()


func _has_collectible_item_in_front() -> bool:
	return not _get_collectible_items_in_front().is_empty()


func _get_collectible_items_in_front() -> Array[ItemRigidBody3D]:
	var collectible_items: Array[ItemRigidBody3D] = []
	var pickup_area := get_node_or_null("GodotRobot3D/InfrontArea3D") as Area3D
	if not pickup_area:
		return collectible_items

	var world := get_node_or_null("/root/Level/Environment/HeistWorld")
	var candidates: Array = pickup_area.get_overlapping_bodies()
	var forward := -global_basis.z
	if world:
		candidates = world.get_node("../ItemContainer").get_children()
		forward = world.player_state.get(str(name), {}).get("carry_direction", forward)
		if is_multiplayer_authority():
			forward = -$SpringArmOffset/SpringArm3D/Camera3D.global_basis.z
	for body in candidates:
		var item := body as ItemRigidBody3D
		if not item or item.carried_by != 0 or item.item_id.is_empty() or not ItemDatabase.get_item(item.item_id):
			continue
		var offset := item.global_position - global_position
		if offset.length() <= 3.5 and offset.normalized().dot(forward) > .15:
			if not world or world.clear_line(global_position + Vector3.UP, item.global_position + Vector3.UP * .2):
				collectible_items.append(item)

	return collectible_items


@rpc("any_peer", "call_local", "reliable")
func apply_force_to_server_object(object_name: String, normal: Vector3) -> void:
	if not multiplayer.is_server() or not _is_owner_request() or not normal.is_finite() or normal.length() > 1.1:
		return
	var object_node = get_node_or_null("/root/Level/Environment/ItemContainer")
	if object_node:
		for n in object_node.get_children():
			if n.name == object_name and n is RigidBody3D and n.global_position.distance_to(global_position) < 4.0:
				n.apply_force(normal * 100)


func _is_grounded_on_server() -> bool:
	if not multiplayer.is_server() or not is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters3D.new()
	query.from = global_position + Vector3.UP * 0.15
	query.to = global_position + Vector3.DOWN * 0.3
	query.collision_mask = 2
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
