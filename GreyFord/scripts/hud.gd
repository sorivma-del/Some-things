extends CanvasLayer
## On-screen HUD: the interaction prompt (from the player's InteractionDetector, found by
## group), skill-check results (DialogueRunner.check_rolled), the day and remaining action
## slots, herbs and medicine in hand, and short notifications (GameState.notified).

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
var _time_label: Label
var _slots_label: Label
var _objective_label: Label
var _inventory_label: Label
var _toasts: VBoxContainer


func _ready() -> void:
	add_to_group(&"hud")
	UiStyle.apply_label(_prompt, 24, 600, true, UiStyle.COLOR_TEXT)
	_prompt.modulate.a = 0.0
	var detector := get_tree().get_first_node_in_group(InteractionDetector.GROUP) as InteractionDetector
	if detector:
		detector.focus_changed.connect(_on_focus_changed)
	else:
		push_warning("HUD: no InteractionDetector in the scene")
	_build_roll_display()
	_build_status()
	DialogueRunner.check_rolled.connect(_on_check_rolled)
	GameState.time_changed.connect(_refresh_status)
	GameState.inventory_changed.connect(_refresh_status)
	GameState.notified.connect(_toast)
	_refresh_status()


## Text under the day line, e.g. the night's goal. Empty hides it.
func set_objective(text: String) -> void:
	_objective_label.text = text


func _refresh_status() -> void:
	if GameState.phase == GameState.Phase.NIGHT:
		_time_label.text = "НОЧЬ %d" % GameState.day
		_slots_label.text = ""
	else:
		_time_label.text = "ДЕНЬ %d  ·  %s" % [GameState.day, GameState.slot_name.to_upper()]
		_slots_label.text = "●  ".repeat(GameState.slots_left) + "○  ".repeat(GameState.slots_used)
	var parts: PackedStringArray = []
	for id: String in GameState.config.herb_ids:
		parts.append("%s %d" % [GameState.herb_name(id), GameState.herbs.get(id, 0)])
	parts.append("Лекарство %d" % GameState.medicine)
	_inventory_label.text = "   ·   ".join(parts)


func _toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.apply_label(label, 22, 600, true, UiStyle.COLOR_TEXT)
	_toasts.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, ^"modulate:a", 1.0, 0.25).from(0.0)
	tween.tween_interval(2.4)
	tween.tween_property(label, ^"modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func _build_status() -> void:
	var top := VBoxContainer.new()
	top.position = Vector2(28, 20)
	top.add_theme_constant_override(&"separation", -4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_time_label = Label.new()
	UiStyle.apply_label(_time_label, 19, 700, false, UiStyle.COLOR_ACCENT, 4)
	top.add_child(_time_label)
	_slots_label = Label.new()
	UiStyle.apply_label(_slots_label, 22, 600, false, UiStyle.COLOR_TEXT)
	top.add_child(_slots_label)
	_objective_label = Label.new()
	UiStyle.apply_label(_objective_label, 21, 500, true, UiStyle.COLOR_TEXT)
	top.add_child(_objective_label)

	_inventory_label = Label.new()
	_inventory_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_inventory_label.position = Vector2(28, 0)
	_inventory_label.offset_top = -46.0
	_inventory_label.offset_bottom = -18.0
	UiStyle.apply_label(_inventory_label, 20, 500, true, UiStyle.COLOR_DIM)
	add_child(_inventory_label)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toasts.offset_left = -520.0
	_toasts.offset_right = -28.0
	_toasts.offset_top = 22.0
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)


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
