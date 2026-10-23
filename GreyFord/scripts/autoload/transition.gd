extends CanvasLayer
## Screen transitions shared by the whole game: fade to and from black, and title cards
## (a few centred lines on black) for days, nights, capture and endings.

const CARD_LINE_PAUSE := 1.1

var is_black: bool:
	get:
		return _black.modulate.a > 0.99

var _black := ColorRect.new()
var _lines := VBoxContainer.new()


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	add_child(_black)
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.alignment = BoxContainer.ALIGNMENT_CENTER
	_lines.add_theme_constant_override(&"separation", 10)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)


## Cuts to black immediately (before a scene shows anything).
func black() -> void:
	_black.modulate.a = 1.0


## Returns the fade's `finished` signal: `await Transition.fade_out()` waits, a bare call
## does not leave a suspended coroutine behind.
func fade_out(duration: float = 0.8) -> Signal:
	return _fade(1.0, duration)


func fade_in(duration: float = 0.8) -> Signal:
	return _fade(0.0, duration)


## Fades to black, shows `lines` one by one, holds, and clears them (stays black).
## The first line is a heading; the rest are quieter.
func card(lines: PackedStringArray, hold: float = 2.0) -> void:
	if not is_black:
		await fade_out(0.8)
	_clear_lines()
	for i: int in lines.size():
		var label := Label.new()
		label.text = lines[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(900, 0)
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if i == 0:
			UiStyle.apply_label(label, 46, 500, false, UiStyle.COLOR_TEXT, 6)
		else:
			UiStyle.apply_label(label, 28, 500, true, UiStyle.COLOR_DIM)
		label.modulate.a = 0.0
		_lines.add_child(label)
		var tween := create_tween()
		tween.tween_property(label, ^"modulate:a", 1.0, 0.7)
		await get_tree().create_timer(CARD_LINE_PAUSE if i > 0 else 0.9, true, false, true).timeout
	await get_tree().create_timer(hold, true, false, true).timeout
	var out := create_tween()
	out.tween_property(_lines, ^"modulate:a", 0.0, 0.6)
	await out.finished
	_clear_lines()


func _fade(alpha: float, duration: float) -> Signal:
	var tween := create_tween()
	tween.tween_property(_black, ^"modulate:a", alpha, maxf(duration, 0.01))
	return tween.finished


func _clear_lines() -> void:
	for child: Node in _lines.get_children():
		child.queue_free()
	_lines.modulate.a = 1.0
