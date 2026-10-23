extends Node
## Runs the three days. When the day's slots are spent and Mara is back in the village
## and free, the evening ends: a title card says how the sick are, then the night is
## played — dark village, Mara must reach Helga's door and sleep (from night 2 the
## elder's hunters walk the streets). Sleeping starts a new morning with an autosave.
## The third evening ends the game.

const HOME_DOOR := Vector3(-8.6, 0.0, -4.3)  ## Helga's house, where Mara sleeps.
const MORNING_SPOT := Vector3(-7.4, 0.0, -3.4)
const NIGHT_START := Vector3(2.4, 0.0, 3.0)
const NIGHT_NAMES: PackedStringArray = ["Первая ночь", "Вторая ночь"]
const GUARD_SCENE: PackedScene = preload("res://scenes/guard.tscn")
const HUNTER_VIEW_DISTANCE := 9.0  ## Shorter than in the forest: it is dark.
## Night patrols through the village streets, around the square and Helga's door.
static var HUNTER_ROUTES: Array[PackedVector3Array] = [
	PackedVector3Array([Vector3(-3, 0, -10), Vector3(-15, 0, -11), Vector3(-18, 0, -1), Vector3(-7, 0, 3)]),
	PackedVector3Array([Vector3(4, 0, 16), Vector3(9, 0, 4), Vector3(4, 0, -7), Vector3(-1, 0, 6)]),
]

var _busy: bool = false
var _bed: Interactable
var _hunters: Array[Guard] = []


func _ready_bed() -> void:
	_bed = Interactable.new()
	_bed.prompt = "Лечь спать"
	_bed.radius = 1.2
	_bed.enabled = false
	_bed.position = _on_ground(HOME_DOOR) + Vector3(0.0, 1.0, 0.0)
	get_parent().add_child.call_deferred(_bed)
	_bed.interacted.connect(_sleep)


func _ready() -> void:
	_ready_bed()
	if GameState.play_intro:
		GameState.save_game()  # Day 1 dawn; the intro cutscene starts the day.
	else:
		_start_loaded_day.call_deferred()


func _process(_delta: float) -> void:
	if _busy or GameState.phase != GameState.Phase.DAY or GameState.slots_left > 0:
		return
	if GameState.controls_locked or GameState.in_forest or DialogueRunner.is_active:
		return
	_end_day()


func _start_loaded_day() -> void:
	GameState.lock_controls()
	Transition.black()
	_player().call(&"teleport", _on_ground(MORNING_SPOT), Vector3(1.0, 0.0, 0.6))
	_snap_camera()
	await Transition.card(_morning_card(), 1.4)
	await Transition.fade_in(1.2)
	GameState.unlock_controls()


func _end_day() -> void:
	_busy = true
	GameState.lock_controls()
	if GameState.day >= GameState.config.days:
		await Transition.card(PackedStringArray(["Третий вечер", "Копыта на дороге. Люди барона будут к рассвету."]), 2.0)
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	var report := GameState.begin_night()
	var night := NIGHT_NAMES[clampi(GameState.day - 1, 0, NIGHT_NAMES.size() - 1)]
	await Transition.card(PackedStringArray([night]) + _night_lines(report), 2.2)
	_player().call(&"teleport", _on_ground(NIGHT_START), Vector3(-1.0, 0.0, -0.4))
	_snap_camera()
	_bed.enabled = true
	_spawn_hunters()
	_set_objective("Дойти до дома Хельги и лечь спать" + ("  ·  берегись фонарей" if not _hunters.is_empty() else ""))
	await Transition.fade_in(1.4)
	GameState.unlock_controls()
	_busy = false


func _sleep() -> void:
	if GameState.phase != GameState.Phase.NIGHT or _busy:
		return
	_busy = true
	_bed.enabled = false
	GameState.lock_controls()
	await Transition.fade_out(1.2)
	await _start_morning()


## Caught by a hunter: led to Helga's door, herbs taken, trust lost; the night is over.
func _on_hunter_caught() -> void:
	if GameState.phase != GameState.Phase.NIGHT or _busy:
		return
	_busy = true
	_bed.enabled = false
	GameState.lock_controls()
	GameState.register_caught()
	await Transition.card(PackedStringArray(["Поймали",
			"Люди старосты довели Мару до порога Хельги. Травы забрали.",
			"Утром об этом будет знать вся деревня."]), 1.6)
	await _start_morning()


func _start_morning() -> void:
	_set_objective("")
	_clear_hunters()
	GameState.begin_day()
	_player().call(&"teleport", _on_ground(MORNING_SPOT), Vector3(1.0, 0.0, 0.6))
	_snap_camera()
	await Transition.card(_morning_card(), 1.4)
	await Transition.fade_in(1.2)
	GameState.unlock_controls()
	_busy = false


## Two or three lines for the night card: how the sick are, and the quiet of the village.
func _night_lines(report: PackedStringArray) -> PackedStringArray:
	var lines := report.duplicate()
	if lines.size() < 2:
		lines.append("Где-то за церковью воет собака.")
	if GameState.day >= 2:
		lines.append("По улицам ходят люди старосты с фонарями.")
	return lines.slice(0, 3)


func _morning_card() -> PackedStringArray:
	var lines := PackedStringArray(["День %d" % GameState.day])
	match GameState.day:
		1:
			lines.append("Три действия до темноты: лес, котёл, больные.")
		2:
			lines.append("По деревне шепчутся, что мор принесла чужачка.")
		3:
			lines.append("Последний день. К рассвету приедут люди барона.")
	return lines


func _spawn_hunters() -> void:
	var per_night := GameState.config.night_hunters_per_night
	var count := per_night[clampi(GameState.day - 1, 0, per_night.size() - 1)]
	for i: int in mini(count, HUNTER_ROUTES.size()):
		var hunter := GUARD_SCENE.instantiate() as Guard
		var route := PackedVector3Array()
		for point: Vector3 in HUNTER_ROUTES[i]:
			route.append(_on_ground(point))
		hunter.route = route
		hunter.view_distance = HUNTER_VIEW_DISTANCE
		hunter.position = route[0]
		get_parent().add_child(hunter)
		hunter.caught_player.connect(_on_hunter_caught)
		_hunters.append(hunter)


func _clear_hunters() -> void:
	for hunter: Guard in _hunters:
		hunter.queue_free()
	_hunters.clear()


func _set_objective(text: String) -> void:
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud:
		hud.call(&"set_objective", text)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _snap_camera() -> void:
	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig:
		rig.call(&"snap_behind_target")


func _on_ground(p: Vector3) -> Vector3:
	var terrain := get_tree().get_first_node_in_group(&"terrain") as Terrain
	return Vector3(p.x, terrain.height_at(p.x, p.z) if terrain else 0.0, p.z)
