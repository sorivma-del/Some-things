class_name RespawnPoint
extends Area3D
## A campfire Mara rests at: walking up to it makes it the place she wakes after falling.

@export var radius: float = 3.0
## Shown once when this point becomes the respawn point (empty = silent).
@export var message: String = "Привал у костра"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	var point := global_position + Vector3(0, 0, radius * 0.5)
	if GameState.has_respawn_point and GameState.respawn_point.is_equal_approx(point):
		return
	GameState.respawn_point = point
	GameState.has_respawn_point = true
	if not message.is_empty():
		GameState.notified.emit(message)
