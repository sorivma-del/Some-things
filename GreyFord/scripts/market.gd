class_name Market
extends Node3D
## The traders on the village square: the smith, the herb-seller and the peddler.
## They pack up at nightfall and are back in the morning.

const STALLS: Array[Dictionary] = [
	{"scene": preload("res://scenes/merchants/smith.tscn"), "pos": Vector3(7.5, 0.0, -0.5), "face": Vector3(0.0, 0.0, 0.0)},
	{"scene": preload("res://scenes/merchants/herbwife.tscn"), "pos": Vector3(-6.8, 0.0, 4.8), "face": Vector3(0.0, 0.0, 2.0)},
	{"scene": preload("res://scenes/merchants/peddler.tscn"), "pos": Vector3(6.0, 0.0, 13.0), "face": Vector3(1.0, 0.0, 8.0)},
]

var _traders: Array[Node3D] = []


func _ready() -> void:
	var terrain := get_tree().get_first_node_in_group(&"terrain") as Terrain
	for stall: Dictionary in STALLS:
		var trader := (stall["scene"] as PackedScene).instantiate() as Node3D
		var pos: Vector3 = stall["pos"]
		trader.position = Vector3(pos.x, terrain.height_at(pos.x, pos.z) if terrain else 0.0, pos.z)
		var to: Vector3 = stall["face"] - pos
		trader.rotation.y = atan2(-to.x, -to.z)
		add_child(trader)
		_traders.append(trader)
	GameState.time_changed.connect(_on_time_changed)
	_on_time_changed()


func _on_time_changed() -> void:
	var open := GameState.phase == GameState.Phase.DAY
	for trader: Node3D in _traders:
		trader.visible = open
		trader.process_mode = Node.PROCESS_MODE_INHERIT if open else Node.PROCESS_MODE_DISABLED
		var talk := trader.get_node(^"Interactable") as Interactable
		talk.enabled = open
		talk.monitorable = open
		(trader as CollisionObject3D).collision_layer = 1 if open else 0
