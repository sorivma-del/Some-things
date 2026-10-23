class_name Encounters
extends Node3D
## Who is out there: a wolf pack and bandits in the forest by day, infected walking the
## village at night (from the second night). Counts come from GameConfig; the dead stay
## dead (flag `<id>_killed`), bought-off bandits stay calm (`<id>_bribe` / `_persuade`).
## When Mara leaves the forest, every enemy that never noticed her writes `<id>_slipped_past`.

const WOLF: PackedScene = preload("res://scenes/enemies/wolf.tscn")
const BANDIT: PackedScene = preload("res://scenes/enemies/bandit.tscn")
const INFECTED: PackedScene = preload("res://scenes/enemies/infected.tscn")

## The wolves' den in the east of the forest and the loop they prowl around it.
const WOLF_DEN := Vector3(18.0, 0.0, -59.0)
static var WOLF_ROUTE := PackedVector3Array([Vector3(15, 0, -57), Vector3(21, 0, -63), Vector3(23, 0, -52), Vector3(17, 0, -50)])
## Bandit paths: the west trail and the south edge.
static var BANDIT_ROUTES: Array[PackedVector3Array] = [
	PackedVector3Array([Vector3(-20, 0, -41), Vector3(-21, 0, -52), Vector3(-12, 0, -56), Vector3(-14, 0, -44)]),
	PackedVector3Array([Vector3(-8, 0, -64), Vector3(9, 0, -64), Vector3(4, 0, -57)]),
]
## Night walks of the infected through the village, clear of the barrels Mara hides in.
static var INFECTED_ROUTES: Array[PackedVector3Array] = [
	PackedVector3Array([Vector3(5, 0, -12), Vector3(9, 0, -2), Vector3(4, 0, 3), Vector3(4, 0, 10)]),
	PackedVector3Array([Vector3(-4, 0, 15), Vector3(-3.5, 0, 3), Vector3(-16, 0, 0.5), Vector3(-5, 0, 4)]),
]

var _forest: Array[Enemy] = []
var _night: Array[Enemy] = []
var _forest_day: int = 0
var _night_day: int = 0
var _was_in_forest: bool = false


func _ready() -> void:
	_spawn_forest.call_deferred()
	GameState.time_changed.connect(_on_time_changed)


func _process(_delta: float) -> void:
	if _was_in_forest and not GameState.in_forest:
		for enemy: Enemy in _forest:
			if is_instance_valid(enemy) and not enemy.dead and not enemy.noticed:
				GameState.set_flag("%s_slipped_past" % enemy.enemy_id)
	_was_in_forest = GameState.in_forest


func forest_enemies() -> Array[Enemy]:
	return _forest.filter(func(e: Enemy) -> bool: return is_instance_valid(e))


func night_enemies() -> Array[Enemy]:
	return _night.filter(func(e: Enemy) -> bool: return is_instance_valid(e))


func _on_time_changed() -> void:
	if GameState.day != _forest_day:
		_spawn_forest()
	if GameState.phase == GameState.Phase.NIGHT and _night_day != GameState.day:
		_spawn_night()
	elif GameState.phase == GameState.Phase.DAY:
		_clear(_night)


func _spawn_forest() -> void:
	_clear(_forest)
	_forest_day = GameState.day
	var wolves := _for_today(GameState.config.forest_wolves_per_day)
	for i: int in wolves:
		var route := PackedVector3Array()
		var offset := Vector3(i * 1.6 - 1.6, 0.0, (i % 2) * 1.2)
		for point: Vector3 in WOLF_ROUTE:
			route.append(point + offset)
		_spawn(WOLF, "forest_wolf_%d" % (i + 1), WOLF_DEN + offset, route, "forest_wolves", _forest)
	var bandits := _for_today(GameState.config.forest_bandits_per_day)
	for i: int in mini(bandits, BANDIT_ROUTES.size()):
		_spawn(BANDIT, "forest_bandit_%d" % (i + 1), BANDIT_ROUTES[i][0], BANDIT_ROUTES[i], "", _forest)


func _spawn_night() -> void:
	_clear(_night)
	_night_day = GameState.day
	var per_night := GameState.config.night_infected_per_night
	var count := per_night[clampi(GameState.day - 1, 0, per_night.size() - 1)]
	for i: int in mini(count, INFECTED_ROUTES.size()):
		var route := INFECTED_ROUTES[i]
		_spawn(INFECTED, "night%d_infected_%d" % [GameState.day, i + 1], route[0], route, "", _night)


func _spawn(scene: PackedScene, id: String, point: Vector3, route: PackedVector3Array, pack: String,
		into: Array[Enemy]) -> void:
	if GameState.has_flag("%s_killed" % id):
		return
	var enemy := scene.instantiate() as Enemy
	enemy.enemy_id = id
	enemy.pack_id = pack
	var grounded := PackedVector3Array()
	for p: Vector3 in route:
		grounded.append(_on_ground(p))
	enemy.route = grounded
	enemy.position = _on_ground(point) + Vector3.UP * 0.1
	add_child(enemy)
	if GameState.has_flag("%s_bribe" % id) or GameState.has_flag("%s_persuade" % id):
		enemy.start_calm()
	into.append(enemy)


func _clear(list: Array[Enemy]) -> void:
	for enemy: Enemy in list:
		if is_instance_valid(enemy):
			enemy.queue_free()
	list.clear()


func _for_today(per_day: PackedInt32Array) -> int:
	return per_day[clampi(GameState.day - 1, 0, per_day.size() - 1)] if per_day.size() > 0 else 0


func _on_ground(p: Vector3) -> Vector3:
	var terrain := get_tree().get_first_node_in_group(&"terrain") as Terrain
	return Vector3(p.x, terrain.height_at(p.x, p.z) if terrain else 0.0, p.z)
