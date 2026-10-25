extends SceneTree
## Синтетические события стиков и кнопок: камера, бой, пауза и навигация без мыши.
const DEVICE: int = 42
var failures: int = 0
var controls: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["OK  " if ok else "FAIL", label])
	if not ok:
		failures += 1


func _button(index: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _axis(index: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _tap(index: JoyButton) -> void:
	await _button(index, true)
	await _button(index, false)


func _run() -> void:
	await process_frame
	controls = root.get_node(^"GameControls")
	controls.set(&"ignore_unfocused", false)
	root.get_node(^"GameState").call(&"new_game")
	await _axis(JOY_AXIS_LEFT_X, 0.1)
	_check("Дрейф стика внутри мёртвой зоны не двигает героя", Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back") == Vector2.ZERO)
	await _axis(JOY_AXIS_LEFT_X, 0.6)
	var partial := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	_check("Наклон стика сохраняет аналоговую силу движения", partial.x > 0.1 and partial.x < 0.9)
	await _axis(JOY_AXIS_LEFT_X, 1.0)
	await _axis(JOY_AXIS_LEFT_Y, 1.0)
	_check("Диагональ не ускоряет движение", Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back").length() <= 1.001)
	await _axis(JOY_AXIS_LEFT_X, 0.0)
	await _axis(JOY_AXIS_LEFT_Y, 0.0)
	var scene := (load("res://scenes/japan/courtyard.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.15).timeout
	var hero := scene.get_node(^"Player/Combat")
	var body := hero.get_parent() as Node3D
	var camera := scene.get_node(^"CameraRig")
	var before := body.global_position
	await _axis(JOY_AXIS_LEFT_Y, -0.8)
	await create_timer(0.15).timeout
	await _axis(JOY_AXIS_LEFT_Y, 0.0)
	_check("Левый стик действительно перемещает героя", body.global_position.distance_to(before) > 0.1)
	var yaw: float = camera.get(&"yaw_degrees")
	await _axis(JOY_AXIS_RIGHT_X, 0.8)
	await create_timer(0.15).timeout
	await _axis(JOY_AXIS_RIGHT_X, 0.0)
	_check("Правый стик поворачивает камеру", absf(float(camera.get(&"yaw_degrees")) - yaw) > 0.1)
	await _button(JOY_BUTTON_X, true)
	await create_timer(0.04).timeout
	_check("Квадрат запускает обычный удар", int(hero.get(&"state")) == 1)
	await _button(JOY_BUTTON_X, false)
	hero.call(&"_set_state", 0)
	hero.call(&"restore")
	await _button(JOY_BUTTON_Y, true)
	await create_timer(0.04).timeout
	_check("Треугольник запускает тяжёлый удар", int(hero.get(&"state")) == 1 and float(hero.call(&"attack_damage")) > 30.0)
	await _button(JOY_BUTTON_Y, false)
	hero.call(&"_set_state", 0)
	hero.call(&"restore")
	await _button(JOY_BUTTON_LEFT_SHOULDER, true)
	await create_timer(0.04).timeout
	_check("L1 поднимает защиту", bool(hero.get(&"blocking")))
	await _button(JOY_BUTTON_LEFT_SHOULDER, false)
	await _button(JOY_BUTTON_B, true)
	await create_timer(0.04).timeout
	_check("Круг запускает перекат", int(hero.get(&"state")) == 2)
	await _button(JOY_BUTTON_B, false)
	hero.call(&"_set_state", 0)
	await _tap(JOY_BUTTON_START)
	_check("Options ставит игру на паузу", paused and controls.get(&"pause_open"))
	var focused := root.gui_get_focus_owner() as Button
	_check("Меню сразу получает фокус геймпада", focused != null and focused.text == "Продолжить")
	await _tap(JOY_BUTTON_DPAD_DOWN)
	focused = root.gui_get_focus_owner() as Button
	_check("Крестовина выбирает тренировку", focused != null and focused.text == "Начать тренировку")
	await _tap(JOY_BUTTON_A)
	_check("Крестик запускает тренировку из паузы", not paused and scene.get(&"training") and (scene.get(&"enemies") as Array).size() == 3)
	for enemy: Node in scene.get(&"enemies"):
		enemy.set_physics_process(false)
	await _tap(JOY_BUTTON_START)
	await _tap(JOY_BUTTON_B)
	await create_timer(0.04).timeout
	_check("Закрытие паузы кругом не вызывает перекат", not paused and int(hero.get(&"state")) == 0)
	await _tap(JOY_BUTTON_DPAD_LEFT)
	var inventory := get_first_node_in_group(&"inventory_window")
	_check("Крестовина открывает сумку с фокусом на кнопке", inventory.get(&"is_open") and root.gui_get_focus_owner() != null)
	await _tap(JOY_BUTTON_B)
	await create_timer(0.04).timeout
	_check("Круг закрывает сумку без случайного переката", not inventory.get(&"is_open") and int(hero.get(&"state")) == 0)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_W
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	_check("Клавиатура переключает подсказки обратно", not controls.get(&"using_gamepad"))
	event.pressed = false
	Input.parse_input_event(event)
	controls.call(&"_release_controls")
	controls.set(&"ignore_unfocused", true)
	current_scene = null
	scene.free()
	await process_frame
	print("controller test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
