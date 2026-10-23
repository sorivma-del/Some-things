class_name LootDrop
extends Area3D
## A small pile left by a fallen enemy; walking over it picks everything up.

const MODEL := preload("res://resources/models/props/Pouch_Large.gltf")
const GLINT := Color(1.0, 0.8, 0.45)

var contents: Dictionary[String, int] = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	shape.position.y = 0.4
	add_child(shape)
	add_child(MODEL.instantiate())
	var light := OmniLight3D.new()
	light.light_color = GLINT
	light.light_energy = 0.8
	light.omni_range = 1.6
	light.position.y = 0.5
	add_child(light)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	var lines: PackedStringArray = []
	for id: String in contents:
		lines.append(GameState.add_loot(id, contents[id]))
	if not lines.is_empty():
		GameState.notified.emit("   ".join(lines))
	queue_free()
