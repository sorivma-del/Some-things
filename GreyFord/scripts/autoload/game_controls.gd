extends Node
## Общая раскладка контроллера, переключение подсказок и пауза с навигацией кнопками.

signal scheme_changed(gamepad: bool)
const CONFIG: ControllerConfig = preload("res://resources/input/controller.tres")
const BUTTONS: Dictionary[StringName, JoyButton] = {
	&"attack": JOY_BUTTON_X,
	&"heavy_attack": JOY_BUTTON_Y,
	&"roll": JOY_BUTTON_B,
	&"interact": JOY_BUTTON_A,
	&"block": JOY_BUTTON_LEFT_SHOULDER,
	&"lock_on": JOY_BUTTON_RIGHT_STICK,
	&"switch_target": JOY_BUTTON_RIGHT_SHOULDER,
	&"heal": JOY_BUTTON_DPAD_UP,
	&"inventory": JOY_BUTTON_DPAD_LEFT,
	&"map": JOY_BUTTON_BACK,
	&"call_horse": JOY_BUTTON_DPAD_DOWN,
	&"sprint": JOY_BUTTON_LEFT_STICK,
	&"pause": JOY_BUTTON_START,
	&"ui_accept": JOY_BUTTON_A,
	&"ui_cancel": JOY_BUTTON_B,
	&"ui_up": JOY_BUTTON_DPAD_UP,
	&"ui_down": JOY_BUTTON_DPAD_DOWN,
	&"ui_left": JOY_BUTTON_DPAD_LEFT,
	&"ui_right": JOY_BUTTON_DPAD_RIGHT,
}
var ignore_unfocused: bool = true
var using_gamepad: bool = false
var active_device: int = -1
var pause_open: bool = false
var _suppress_until: int = 0
var _pause_layer: CanvasLayer
var _previous_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bindings()
	Input.joy_connection_changed.connect(_connection_changed)
	get_window().focus_exited.connect(_release_controls)
	var devices := Input.get_connected_joypads()
	if not devices.is_empty():
		_set_scheme(true, devices[0])


func _setup_bindings() -> void:
	for action: StringName in BUTTONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = BUTTONS[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
	var axes: Dictionary[StringName, Vector2i] = {
		&"move_left": Vector2i(JOY_AXIS_LEFT_X, -1),
		&"move_right": Vector2i(JOY_AXIS_LEFT_X, 1),
		&"move_forward": Vector2i(JOY_AXIS_LEFT_Y, -1),
		&"move_back": Vector2i(JOY_AXIS_LEFT_Y, 1),
		&"look_left": Vector2i(JOY_AXIS_RIGHT_X, -1),
		&"look_right": Vector2i(JOY_AXIS_RIGHT_X, 1),
		&"look_up": Vector2i(JOY_AXIS_RIGHT_Y, -1),
		&"look_down": Vector2i(JOY_AXIS_RIGHT_Y, 1),
	}
	for action: StringName in axes:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_set_deadzone(action, CONFIG.deadzone)
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = axes[action].x as JoyAxis
		event.axis_value = axes[action].y
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _input(event: InputEvent) -> void:
	if ignore_unfocused and (event is InputEventJoypadButton or event is InputEventJoypadMotion) and not get_window().has_focus():
		_release_controls()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed:
		_set_scheme(true, event.device)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > CONFIG.deadzone:
		_set_scheme(true, event.device)
	elif event is InputEventKey and event.pressed:
		_set_scheme(false)
	elif event is InputEventMouseButton and event.pressed:
		_set_scheme(false)
	elif event is InputEventMouseMotion and event.relative.length_squared() > 4.0:
		_set_scheme(false)
	if event.is_action_pressed(&"pause") or (pause_open and event.is_action_pressed(&"ui_cancel")):
		if pause_open:
			close_pause()
		elif get_tree().current_scene is Node3D and not GameState.controls_locked:
			open_pause()
		else:
			return
		get_viewport().set_input_as_handled()


func _set_scheme(gamepad: bool, device: int = -1) -> void:
	if gamepad:
		active_device = device
	if using_gamepad != gamepad:
		using_gamepad = gamepad
		scheme_changed.emit(gamepad)


func _connection_changed(device: int, connected: bool) -> void:
	if connected:
		_set_scheme(true, device)
	elif device == active_device:
		_release_controls()
		active_device = -1
		_set_scheme(false)


func _release_controls() -> void:
	for action: StringName in BUTTONS:
		Input.action_release(action)
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"look_left", &"look_right", &"look_up", &"look_down"]:
		Input.action_release(action)


func combat_hint() -> String:
	if using_gamepad:
		return "□ — удар · △ — тяжёлый · L1 — парирование · ○ — перекат · R3 — цель · Options — пауза"
	return "ЛКМ / J — удар · K — тяжёлый · Shift — блок / парирование · пробел — перекат · Q — цель"


func attack_button() -> String:
	return "□" if using_gamepad else "ЛКМ"


func interact_button() -> String:
	return "✕" if using_gamepad else "E"


func open_pause() -> void:
	if pause_open or get_tree().paused:
		return
	pause_open = true
	_previous_focus = get_viewport().gui_get_focus_owner()
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 100
	add_child(_pause_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.025, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	center.add_child(column)
	var title := Label.new()
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.apply_label(title, 40)
	column.add_child(title)
	var resume := UiStyle.button("Продолжить", close_pause, 28)
	column.add_child(resume)
	var scene := get_tree().current_scene
	if scene.has_method(&"_start_training"):
		var restart_label: String = scene.call(&"pause_restart_label") if scene.has_method(&"pause_restart_label") else "Начать тренировку"
		var practice := UiStyle.button(restart_label, _start_training, 28)
		practice.disabled = bool(scene.get(&"training"))
		column.add_child(practice)
	if scene.has_method(&"set_evening"):
		column.add_child(UiStyle.button("Свет: утро", _set_light.bind(false), 26))
		column.add_child(UiStyle.button("Свет: сумерки", _set_light.bind(true), 26))
	column.add_child(UiStyle.button("В главное меню", _main_menu, 28))
	var hint := Label.new()
	hint.text = "Крестовина — выбрать · ✕ — подтвердить · ○ / Options — назад"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.apply_label(hint, 18)
	column.add_child(hint)
	get_tree().paused = true
	resume.grab_focus()


func close_pause() -> void:
	if not pause_open:
		return
	pause_open = false
	_pause_layer.queue_free()
	_pause_layer = null
	get_tree().paused = false
	consume_menu_action()
	if is_instance_valid(_previous_focus):
		_previous_focus.grab_focus()
	_previous_focus = null


func _start_training() -> void:
	close_pause()
	var scene := get_tree().current_scene
	if scene and scene.has_method(&"_start_training"):
		scene.call(&"_start_training")


func _set_light(evening: bool) -> void:
	close_pause()
	var scene := get_tree().current_scene
	if scene and scene.has_method(&"set_evening"):
		scene.call(&"set_evening", evening)


func _main_menu() -> void:
	close_pause()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func consume_menu_action() -> void:
	_suppress_until = Time.get_ticks_msec() + int(CONFIG.menu_input_grace * 1000.0)
	for action: StringName in [&"attack", &"heavy_attack", &"roll", &"interact"]:
		Input.action_release(action)


func actions_suppressed() -> bool:
	return Time.get_ticks_msec() < _suppress_until
