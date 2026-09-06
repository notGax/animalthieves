class_name ItemRigidBody3D
extends RigidBody3D

@export var item_id: String = ""
@export var carried_by := 0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_impact)
	# The host simulates merchandise; clients render replicated transforms.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		freeze = true


func _physics_process(_delta: float) -> void:
	collision_layer = 0 if carried_by > 0 else 4
	if multiplayer.is_server():
		freeze = carried_by > 0

func _on_impact(body: Node) -> void:
	if multiplayer.is_server() and body.has_method("take_damage") and linear_velocity.length() > 4:
		body.take_damage(clampf(linear_velocity.length() * 5, 15, 65))
