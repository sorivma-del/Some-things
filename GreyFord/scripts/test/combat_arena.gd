extends Node3D
## Practice arena for the combat prototype: a walled yard of trodden mud with a few
## pillars (to check the camera keeps out of walls), two campfires to rest at, two straw
## dummies and a sparring swordsman. Runs without the rest of the game.
## Keys 1–4 bring in enemies (wolf pack, bandit, infected, bandit chief) in front of Mara,
## 5 switches day and night, 0 clears them. The yard has a navigation mesh baked at start.

const SIZE := 30.0
const WALL_HEIGHT := 3.0
const PILLARS: Array[Vector3] = [Vector3(-6, 0, -4), Vector3(7, 0, -6), Vector3(-3, 0, 7), Vector3(9, 0, 6)]
const ENEMIES: Dictionary[String, PackedScene] = {
	"wolf": preload("res://scenes/enemies/wolf.tscn"),
	"bandit": preload("res://scenes/enemies/bandit.tscn"),
	"infected": preload("res://scenes/enemies/infected.tscn"),
	"chief": preload("res://scenes/enemies/bandit_chief.tscn"),
}
const SPAWN_KEYS: Dictionary[Key, String] = {KEY_1: "wolf", KEY_2: "bandit", KEY_3: "infected", KEY_4: "chief"}

## Coins in Mara's purse when the arena opens (to see the death penalty).
@export var start_coins: int = 40
@export var hint: String = "J / ЛКМ — удар · Shift — блок · Пробел — перекат · Q / СКМ — захват цели · Tab — сменить цель\n1 волки · 2 разбойник · 3 заражённый · 4 атаман · 5 день/ночь · 0 убрать врагов"
## Wolves come as a pack of this many.
@export var wolf_pack_size: int = 3

var _navigation := NavigationRegion3D.new()


func _ready() -> void:
	GameState.play_intro = false
	GameState.coins = start_coins
	add_child(_navigation)
	_build_yard()
	_bake_navigation()
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


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or GameState.controls_locked:
		return
	if SPAWN_KEYS.has(key.physical_keycode):
		spawn(SPAWN_KEYS[key.physical_keycode])
	elif key.physical_keycode == KEY_5:
		toggle_night()
	elif key.physical_keycode == KEY_0:
		clear_enemies()


## Brings in an enemy (a pack, for wolves) 9 m in front of Mara.
func spawn(kind: String) -> Array[Enemy]:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var model := player.get_node(^"Model") as Node3D
	var forward := -model.global_basis.z
	forward.y = 0.0
	var origin := player.global_position + forward.normalized() * 9.0
	origin.x = clampf(origin.x, -SIZE * 0.4, SIZE * 0.4)
	origin.z = clampf(origin.z, -SIZE * 0.4, SIZE * 0.4)
	var spawned: Array[Enemy] = []
	var count := wolf_pack_size if kind == "wolf" else 1
	var pack := "arena_pack_%d" % Time.get_ticks_msec()
	for i: int in count:
		var enemy := ENEMIES[kind].instantiate() as Enemy
		if kind == "wolf":
			enemy.pack_id = pack
		enemy.position = origin + Vector3(i * 1.4 - (count - 1) * 0.7, 0.2, 0)
		add_child(enemy)
		enemy.call(&"face_point", player.global_position)
		spawned.append(enemy)
	return spawned


func toggle_night() -> void:
	var night := GameState.phase == GameState.Phase.NIGHT
	GameState.phase = GameState.Phase.DAY if night else GameState.Phase.NIGHT
	GameState.time_changed.emit()
	GameState.notified.emit("День" if night else "Ночь: заражённые злее")


func clear_enemies() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.queue_free()


func _bake_navigation() -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	_navigation.navigation_mesh = mesh
	_navigation.bake_navigation_mesh(false)


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
	_navigation.add_child(body)
