extends Node
## Plays the two cutscenes with its own camera and overlay:
## - intro: fade in, camera glides from the church to the campfire and settles behind Mara
##   while three subtitle lines appear; then control passes to the player (E / Esc skips);
## - finale: when GameState.gate_open is set, the gate swings open, Mara walks out,
##   the screen fades to black and "Конец первой главы" appears.
## Pass "--skip-intro" after "--" on the command line to start straight in gameplay.

const INTRO_LINES: PackedStringArray = [
	"Серый Брод. Третий день мора.",
	"Утром Мара нашла у себя на запястье тёмное пятно.",
	"Отшельник за рекой — день пути. На закате ворота заложат до утра.",
]
const INTRO_START := Transform3D(Basis(), Vector3(3.0, 7.5, -11.5))
const INTRO_LOOK_AT := Vector3(0.0, 1.0, 1.5)
const FINALE_CAMERA := Vector3(-3.6, 2.3, 15.0)
const FINALE_LOOK_AT := Vector3(0.0, 1.6, 22.0)
const FINALE_WAYPOINTS: Array[Vector3] = [Vector3(0.0, 0.0, 19.0), Vector3(0.0, 0.0, 29.0)]

@export var intro_duration: float = 11.0
@export var line_duration: float = 3.1

var _camera := Camera3D.new()
var _overlay := CanvasLayer.new()
var _fade := ColorRect.new()
var _subtitle := Label.new()
var _title := Label.new()
var _intro_tween: Tween
var _gameplay_camera: Camera3D
var _intro_running: bool = false


func _ready() -> void:
	_camera.fov = 55.0
	_camera.far = 200.0
	add_child(_camera)
	_build_overlay()
	GameState.flag_changed.connect(_on_flag_changed)
	if OS.get_cmdline_user_args().has("--skip-intro"):
		_fade.modulate.a = 0.0
	else:
		_play_intro.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _intro_running and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"interact")):
		get_viewport().set_input_as_handled()
		_end_intro()


func _play_intro() -> void:
	GameState.lock_controls()
	_intro_running = true
	# Let the follow camera settle behind Mara: that is where the glide ends.
	await get_tree().process_frame
	_gameplay_camera = get_viewport().get_camera_3d()
	var start := INTRO_START.looking_at(INTRO_LOOK_AT)
	_camera.global_transform = start
	_camera.make_current()

	_intro_tween = create_tween()
	_intro_tween.tween_property(_fade, ^"modulate:a", 0.0, 2.0)
	_intro_tween.parallel().tween_method(func(t: float) -> void:
		_camera.global_transform = start.interpolate_with(_gameplay_camera.global_transform, t),
		0.0, 1.0, intro_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i: int in INTRO_LINES.size():
		_intro_tween.parallel().tween_callback(_show_subtitle.bind(INTRO_LINES[i])).set_delay(1.2 + i * (line_duration + 0.4))
	_intro_tween.finished.connect(_end_intro)


func _end_intro() -> void:
	if not _intro_running:
		return
	_intro_running = false
	if _intro_tween:
		_intro_tween.kill()
	_fade.modulate.a = 0.0
	create_tween().tween_property(_subtitle, ^"modulate:a", 0.0, 0.4)
	if _gameplay_camera:
		_gameplay_camera.make_current()
	GameState.unlock_controls()


func _show_subtitle(text: String) -> void:
	_subtitle.text = text
	var tween := create_tween()
	tween.tween_property(_subtitle, ^"modulate:a", 1.0, 0.6)
	tween.tween_interval(line_duration - 1.2)
	tween.tween_property(_subtitle, ^"modulate:a", 0.0, 0.6)


func _on_flag_changed(flag: StringName, value: bool) -> void:
	if flag == &"gate_open" and value:
		_play_finale()


func _play_finale() -> void:
	_end_intro()
	GameState.lock_controls()
	if DialogueRunner.is_active:
		await DialogueRunner.dialogue_finished
	_camera.global_transform = Transform3D(Basis(), FINALE_CAMERA).looking_at(FINALE_LOOK_AT)
	_camera.make_current()
	# Slow push toward the opening gate.
	create_tween().tween_property(_camera, ^"position", FINALE_CAMERA + Vector3(0.8, 0.0, 2.0), 9.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(2.0).timeout

	var player := get_tree().get_first_node_in_group(&"player")
	if player and player.has_method(&"walk_to"):
		for point: Vector3 in FINALE_WAYPOINTS:
			player.call(&"walk_to", point)
			# Safety timeout in case something blocks the path.
			await _first_of(player, &"arrived", 6.0)
	await get_tree().create_timer(0.3).timeout
	var fade := create_tween()
	fade.tween_property(_fade, ^"modulate:a", 1.0, 2.5)
	fade.tween_interval(0.6)
	fade.tween_property(_title, ^"modulate:a", 1.0, 2.0)


## Waits for `signal_name` on `source`, or `timeout` seconds, whichever comes first.
func _first_of(source: Object, signal_name: StringName, timeout: float) -> void:
	var done := [false]
	var finish := func() -> void: done[0] = true
	source.connect(signal_name, finish, CONNECT_ONE_SHOT)
	var timer := get_tree().create_timer(timeout)
	timer.timeout.connect(finish)
	while not done[0]:
		await get_tree().process_frame
	if source.is_connected(signal_name, finish):
		source.disconnect(signal_name, finish)


func _build_overlay() -> void:
	_overlay.layer = 20
	add_child(_overlay)

	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_fade)

	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle.offset_top = -150.0
	_subtitle.offset_bottom = -70.0
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.modulate.a = 0.0
	UiStyle.apply_label(_subtitle, 32, 500, true, UiStyle.COLOR_TEXT)
	_overlay.add_child(_subtitle)

	_title.text = "Конец первой главы"
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.modulate.a = 0.0
	UiStyle.apply_label(_title, 54, 500, false, UiStyle.COLOR_TEXT, 6)
	_overlay.add_child(_title)
