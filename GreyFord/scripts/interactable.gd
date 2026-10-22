class_name Interactable
extends Area3D
## Something Mara can use with E: an NPC, a door. Sits on the "interact" physics layer;
## the player's InteractionDetector finds it and calls interact().

signal interacted

const LAYER := 1 << 3  # Physics layer 4, "interact".

@export var prompt: String = "Осмотреть"
@export var radius: float = 0.9
@export var enabled: bool = true


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	if find_children("*", "CollisionShape3D", false, false).is_empty():
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		shape.shape = sphere
		add_child(shape)


func interact() -> void:
	if enabled:
		interacted.emit()
