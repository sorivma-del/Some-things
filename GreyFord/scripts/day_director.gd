extends Node
## Runs the three days. When the day's slots are spent and Mara is back in the village
## and free, the evening ends: a night passes (the sick change), then a new morning with
## an autosave. The third evening ends the game.

const HOME_DOOR := Vector3(-8.6, 0.0, -4.3)  ## Helga's house, where Mara sleeps.
const MORNING_SPOT := Vector3(-7.4, 0.0, -3.4)

var _busy: bool = false


func _ready() -> void:
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
	await Transition.card(PackedStringArray(["Ночь"]) + report, 2.2)
	GameState.begin_day()
	_player().call(&"teleport", _on_ground(MORNING_SPOT), Vector3(1.0, 0.0, 0.6))
	_snap_camera()
	await Transition.card(_morning_card(), 1.4)
	await Transition.fade_in(1.2)
	GameState.unlock_controls()
	_busy = false


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


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _snap_camera() -> void:
	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig:
		rig.call(&"snap_behind_target")


func _on_ground(p: Vector3) -> Vector3:
	var terrain := get_tree().get_first_node_in_group(&"terrain") as Terrain
	return Vector3(p.x, terrain.height_at(p.x, p.z) if terrain else 0.0, p.z)
