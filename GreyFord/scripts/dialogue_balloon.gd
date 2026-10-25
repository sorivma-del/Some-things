class_name DialogueBalloon
extends CanvasLayer
## Subtitle-style dialogue at the bottom of the screen, built in code, no backing panel.
## Types out each line with Dialogue Manager's DialogueLabel; E / Space / click advances
## or skips typing; responses are picked with 1-4 or the mouse. Emits `finished` at the end.

signal finished

const HERO_NAME := "Мара"
const RESPONSE_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
## Ignore input for a moment so the key that opened the dialogue does not skip line one.
const INPUT_GRACE_MSEC := 200
const TEXT_SIZE := 30
const RESPONSE_SIZE := 26

var _resource: DialogueResource
var _states: Array = []
var _line: DialogueLine
var _responses: Array[DialogueResponse] = []
var _waiting_for_input: bool = false
var _opened_at_msec: int = 0

var _speaker: Label
var _text: DialogueLabel
var _responses_box: VBoxContainer
var _hint: Label


func _ready() -> void:
	layer = 10
	_build_ui()
	GameControls.scheme_changed.connect(_on_control_scheme)
	_on_control_scheme(GameControls.using_gamepad)


func start(resource: DialogueResource, cue: String, extra_game_states: Array = []) -> void:
	_resource = resource
	_states = extra_game_states
	_opened_at_msec = Time.get_ticks_msec()
	_show_line(await _resource.get_next_dialogue_line(cue, _states))


func _show_line(line: DialogueLine) -> void:
	_line = line
	_waiting_for_input = false
	_clear_responses()
	if _line == null:
		finished.emit()
		queue_free()
		return

	# Spoken lines: speaker name above, upright text. Narration: italic, dimmer, no name.
	var narration := _line.character.is_empty()
	_speaker.visible = not narration
	_speaker.text = _line.character.to_upper()
	_speaker.add_theme_color_override(&"font_color", UiStyle.COLOR_HERO if _line.character == HERO_NAME else UiStyle.COLOR_ACCENT)
	UiStyle.apply_label(_text, TEXT_SIZE, 500, narration, UiStyle.COLOR_DIM if narration else UiStyle.COLOR_TEXT)
	_hint.modulate.a = 0.0

	_text.dialogue_line = _line
	if not _line.text.is_empty():
		_text.type_out()
		await _text.finished_typing

	_responses.clear()
	for response: DialogueResponse in _line.responses:
		if response.is_allowed:
			_responses.append(response)
	if _responses.is_empty():
		_waiting_for_input = true
		create_tween().tween_property(_hint, ^"modulate:a", 1.0, 0.6)
	else:
		_show_responses()


func _next(next_id: String) -> void:
	_clear_responses()
	_responses.clear()
	_waiting_for_input = false
	_show_line(await _resource.get_next_dialogue_line(next_id, _states))


func _unhandled_input(event: InputEvent) -> void:
	if _line == null:
		return
	# The balloon owns input while it is open.
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() - _opened_at_msec < INPUT_GRACE_MSEC:
		return

	var key := event as InputEventKey
	if key and key.pressed and not key.echo and not _responses.is_empty():
		var index := RESPONSE_KEYS.find(key.physical_keycode)
		if index >= 0 and index < _responses.size():
			_next(_responses[index].next_id)
		return

	var mouse := event as InputEventMouseButton
	var advance := event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") \
			or (mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT)
	if not advance:
		return
	if _text.is_typing:
		_text.skip_typing()
	elif _waiting_for_input:
		_next(_line.next_id)


func _show_responses() -> void:
	for i: int in _responses.size():
		var button := Button.new()
		button.text = "%d   %s" % [i + 1, _responses[i].text]
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_override(&"font", UiStyle.font(500, true))
		button.add_theme_font_size_override(&"font_size", RESPONSE_SIZE)
		button.add_theme_color_override(&"font_color", UiStyle.COLOR_TEXT.darkened(0.12))
		button.add_theme_color_override(&"font_hover_color", UiStyle.COLOR_ACCENT)
		button.add_theme_color_override(&"font_pressed_color", UiStyle.COLOR_ACCENT)
		button.add_theme_color_override(&"font_outline_color", UiStyle.COLOR_OUTLINE)
		button.add_theme_constant_override(&"outline_size", 5)
		button.pressed.connect(_next.bind(_responses[i].next_id))
		button.modulate.a = 0.0
		_responses_box.add_child(button)
		create_tween().tween_property(button, ^"modulate:a", 1.0, 0.35).set_delay(0.08 * i)
	_responses_box.show()
	_on_control_scheme(GameControls.using_gamepad)


func _clear_responses() -> void:
	for child: Node in _responses_box.get_children():
		child.queue_free()
	_responses_box.hide()


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_theme_constant_override(&"margin_left", 200)
	root.add_theme_constant_override(&"margin_right", 200)
	root.add_theme_constant_override(&"margin_bottom", 40)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override(&"separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	_speaker = Label.new()
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.apply_label(_speaker, 17, 700, false, UiStyle.COLOR_ACCENT, 4)
	column.add_child(_speaker)

	_text = DialogueLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.seconds_per_step = 0.025
	_text.skip_action = &""
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text)

	_responses_box = VBoxContainer.new()
	_responses_box.add_theme_constant_override(&"separation", -6)
	column.add_child(_responses_box)

	_hint = Label.new()
	_hint.text = GameControls.interact_button()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.apply_label(_hint, 16, 600, false, UiStyle.COLOR_DIM, 2)
	column.add_child(_hint)


func _on_control_scheme(gamepad: bool) -> void:
	_hint.text = GameControls.interact_button()
	if gamepad and _responses_box.visible and not _responses.is_empty():
		for node: Node in _responses_box.get_children():
			if node is Button and not node.is_queued_for_deletion():
				(node as Button).grab_focus()
				break
