extends Node3D
## Practice arena for the combat prototype: a walled yard of trodden mud with a few
## pillars (to check the camera keeps out of walls), two campfires to rest at, two straw
## dummies and a sparring swordsman. Runs without the rest of the game.

const SIZE := 30.0
const WALL_HEIGHT := 3.0
const PILLARS: Array[Vector3] = [Vector3(-6, 0, -4), Vector3(7, 0, -6), Vector3(-3, 0, 7), Vector3(9, 0, 6)]

## Coins in Mara's purse when the arena opens (to see the death penalty).
@export var start_coins: int = 40
@export var hint: String = "J / ЛКМ — удар · Shift — блок · Пробел — перекат · Q / СКМ — захват цели · Tab — сменить цель"


func _ready() -> void:
	GameState.play_intro = false
	GameState.coins = start_coins
	_build_yard()
	get_tree().call_group(&"hud", &"set_day_status_visible", false)
	get_tree().call_group(&"hud", &"set_objective", hint)


func _build_yard() -> void:
	var mud := StandardMaterial3D.new()
	mud.albedo_texture = load("res://resources/textures/ground/brown_mud_03_diff.jpg") as Texture2D
	mud.normal_enabled = true
	mud.normal_texture = load("res://resources/textures/ground/brown_mud_03_nor_gl.jpg") as Texture2D
	mud.roughness = 0.95
	mud.uv1_scale = Vector3(SIZE / 3.0, SIZE / 3.0, 1.0)
	mud.albedo_color = Color(0.75, 0.7, 0.65)
	_box(Vector3(SIZE, 0.2, SIZE), Vector3(0, -0.1, 0), mud)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.22, 0.16)
	wood.roughness = 0.9
	var half := SIZE * 0.5
	for side: Vector3 in [Vector3(0, 0, -half), Vector3(0, 0, half)]:
		_box(Vector3(SIZE, WALL_HEIGHT, 0.4), side + Vector3.UP * WALL_HEIGHT * 0.5, wood)
	for side: Vector3 in [Vector3(-half, 0, 0), Vector3(half, 0, 0)]:
		_box(Vector3(0.4, WALL_HEIGHT, SIZE), side + Vector3.UP * WALL_HEIGHT * 0.5, wood)

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.41, 0.4)
	stone.roughness = 1.0
	for point: Vector3 in PILLARS:
		_box(Vector3(1.0, 3.2, 1.0), point + Vector3.UP * 1.6, stone)


func _box(size: Vector3, center: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	body.add_child(visual)
	add_child(body)
