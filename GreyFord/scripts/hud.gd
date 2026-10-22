extends CanvasLayer
## On-screen HUD: the interaction prompt (from the player's InteractionDetector, found by
## group) and skill-check results (from DialogueRunner.check_rolled).

const ROLL_SPIN_TIME := 0.9
const ROLL_HOLD_TIME := 1.5
const COLOR_SUCCESS := Color(0.68, 0.8, 0.56)
const COLOR_FAILURE := Color(0.86, 0.38, 0.3)

@onready var _prompt: Label = %PromptLabel

var _roll_box: VBoxContainer
var _roll_stat: Label
var _roll_die: Label
var _roll_sum: Label
var _roll_verdict: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	UiStyle.apply_label(_prompt, 24, 600, true, UiStyle.COLOR_TEXT)
	_prompt.modulate.a = 0.0
	var detector := get_tree().get_first_node_in_group(InteractionDetector.GROUP) as InteractionDetector
	if detector:
		detector.focus_changed.connect(_on_focus_changed)
	else:
		push_warning("HUD: no InteractionDetector in the scene")
	_build_roll_display()
	DialogueRunner.check_rolled.connect(_on_check_rolled)


func _on_focus_changed(prompt: String) -> void:
	if not prompt.is_empty():
		_prompt.text = "E   %s" % prompt
	create_tween().tween_property(_prompt, ^"modulate:a", 0.0 if prompt.is_empty() else 1.0, 0.2)


func _on_check_rolled(stat: StringName, roll: int, bonus: int, difficulty: int, passed: bool) -> void:
	_roll_stat.text = "ПРОВЕРКА:  %s" % CharacterStats.display_name(stat).to_upper()
	_roll_sum.text = ""
	_roll_verdict.text = ""
	_roll_die.add_theme_color_override(&"font_color", UiStyle.COLOR_TEXT)
	_roll_box.modulate.a = 0.0
	create_tween().tween_property(_roll_box, ^"modulate:a", 1.0, 0.2)

	# The die tumbles through random faces before settling.
	var elapsed := 0.0
	while elapsed < ROLL_SPIN_TIME:
		_roll_die.text = str(_rng.randi_range(1, 20))
		await get_tree().create_timer(0.06).timeout
		elapsed += 0.06
	_roll_die.text = str(roll)
	_roll_sum.text = "d20 %d  +  %d  =  %d      сложность %d" % [roll, bonus, roll + bonus, difficulty]
	_roll_verdict.text = "УСПЕХ" if passed else "НЕУДАЧА"
	var verdict_color := COLOR_SUCCESS if passed else COLOR_FAILURE
	_roll_verdict.add_theme_color_override(&"font_color", verdict_color)
	_roll_die.add_theme_color_override(&"font_color", verdict_color)

	await get_tree().create_timer(ROLL_HOLD_TIME).timeout
	create_tween().tween_property(_roll_box, ^"modulate:a", 0.0, 0.6)


func _build_roll_display() -> void:
	_roll_box = VBoxContainer.new()
	_roll_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_roll_box.offset_top = 90.0
	_roll_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_roll_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_roll_box.add_theme_constant_override(&"separation", -4)
	_roll_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll_box.modulate.a = 0.0
	add_child(_roll_box)

	_roll_stat = _roll_label(17, 700, false, UiStyle.COLOR_ACCENT, 4)
	_roll_die = _roll_label(72, 600, false, UiStyle.COLOR_TEXT, 0)
	_roll_sum = _roll_label(22, 500, true, UiStyle.COLOR_DIM, 0)
	_roll_verdict = _roll_label(22, 700, false, COLOR_SUCCESS, 6)


func _roll_label(size: int, weight: int, italic: bool, color: Color, spacing: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(600, 0)
	UiStyle.apply_label(label, size, weight, italic, color, spacing)
	_roll_box.add_child(label)
	return label
