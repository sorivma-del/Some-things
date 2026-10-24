extends CanvasLayer
## On-screen HUD: the interaction prompt (from the player's InteractionDetector, found by
## group), skill-check results (DialogueRunner.check_rolled), the day and remaining action
## slots, herbs and medicine in hand, and short notifications (GameState.notified).
## When Mara can fight (a PlayerCombat in the scene): health and stamina bars, coins,
## and the locked-on target's name and health.

const ROLL_SPIN_TIME := 0.9
const ROLL_HOLD_TIME := 1.5
const COLOR_SUCCESS := Color(0.68, 0.8, 0.56)
const COLOR_FAILURE := Color(0.86, 0.38, 0.3)
const COLOR_HEALTH := Color(0.62, 0.16, 0.12)
const COLOR_STAMINA := Color(0.72, 0.6, 0.3)

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
var _combat_box: VBoxContainer
var _health_bar: ProgressBar
var _stamina_bar: ProgressBar
var _coins_label: Label
var _target_box: VBoxContainer
var _target_name: Label
var _target_posture: ProgressBar
var _target_hint: Label
var _target_bar: ProgressBar
var _target: Node3D


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
	GameState.coins_changed.connect(func(_coins: int) -> void: _refresh_status())
	_refresh_status()
	_build_combat()
	_connect_combat.call_deferred()
	add_child(InventoryWindow.new())
	add_child(TradeWindow.new())
	_setup_world.call_deferred()


func _process(_delta: float) -> void:
	if GameState.world_mode and Engine.get_process_frames() % 30 == 0:
		_refresh_status()  # The clock runs.
	# On horseback the stamina bar shows the horse's breath.
	var horse := get_tree().get_first_node_in_group(&"horse")
	if horse and horse.call(&"is_ridden"):
		_stamina_bar.value = float(horse.get(&"stamina")) / float((horse.get(&"data") as Resource).get(&"max_stamina")) * 100.0
	if is_instance_valid(_target):
		_target_bar.value = float(_target.call(&"health_ratio")) * 100.0
		if _target.has_method(&"posture_ratio"):
			_target_posture.value = float(_target.call(&"posture_ratio")) * 100.0
			_target_hint.text = str(_target.call(&"combat_hint"))


## Text under the day line, e.g. the night's goal. Empty hides it.
func set_objective(text: String) -> void:
	_objective_label.text = text


## Hides the day, slots and herb lines (the combat arena has no days); the objective stays.
func set_day_status_visible(value: bool) -> void:
	_time_label.visible = value
	_slots_label.visible = value
	_inventory_label.visible = value


func _refresh_status() -> void:
	if GameState.world_mode:
		var period: String = {"morning": "УТРО", "day": "ДЕНЬ", "evening": "ВЕЧЕР", "night": "НОЧЬ"}[GameState.world_period()]
		_time_label.text = "ДЕНЬ %d  ·  %s  %s" % [GameState.world_day, period, GameState.world_clock_text()]
		_slots_label.text = ""
	elif GameState.phase == GameState.Phase.NIGHT:
		_time_label.text = "НОЧЬ %d" % GameState.day
		_slots_label.text = ""
	else:
		_time_label.text = "ДЕНЬ %d  ·  %s" % [GameState.day, GameState.slot_name.to_upper()]
		_slots_label.text = "●  ".repeat(GameState.slots_left) + "○  ".repeat(GameState.slots_used)
	var parts: PackedStringArray = []
	for id: String in GameState.config.herb_ids:
		parts.append("%s %d" % [GameState.herb_name(id), GameState.herbs.get(id, 0)])
	parts.append("Лекарство %d" % GameState.medicine)
	parts.append("Монеты %d" % GameState.coins)
	_inventory_label.text = "   ·   ".join(parts) + "      I — сумка" + ("   M — карта   X — лошадь" if GameState.world_mode else "")


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


func _build_combat() -> void:
	_combat_box = VBoxContainer.new()
	_combat_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_combat_box.offset_left = 28.0
	_combat_box.offset_top = -132.0
	_combat_box.offset_bottom = -52.0
	_combat_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_combat_box.add_theme_constant_override(&"separation", 6)
	_combat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_box.visible = false
	add_child(_combat_box)
	_health_bar = _bar(COLOR_HEALTH, Vector2(300, 12))
	_combat_box.add_child(_health_bar)
	_stamina_bar = _bar(COLOR_STAMINA, Vector2(240, 7))
	_combat_box.add_child(_stamina_bar)
	_coins_label = Label.new()
	UiStyle.apply_label(_coins_label, 20, 600, true, UiStyle.COLOR_ACCENT)
	_combat_box.add_child(_coins_label)

	_target_box = VBoxContainer.new()
	_target_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_target_box.offset_top = 24.0
	_target_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_target_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_box.modulate.a = 0.0
	add_child(_target_box)
	_target_name = Label.new()
	_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.apply_label(_target_name, 22, 700, false, UiStyle.COLOR_TEXT, 3)
	_target_box.add_child(_target_name)
	_target_bar = _bar(COLOR_HEALTH, Vector2(320, 6))
	_target_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_target_box.add_child(_target_bar)
	_target_posture = _bar(COLOR_STAMINA, Vector2(260, 5))
	_target_posture.name = "PostureBar"
	_target_posture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_target_posture.visible = false
	_target_box.add_child(_target_posture)
	_target_hint = Label.new()
	_target_hint.name = "CombatHint"
	_target_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.apply_label(_target_hint, 14, 600, false, UiStyle.COLOR_ACCENT, 2)
	_target_hint.visible = false
	_target_box.add_child(_target_hint)


## In the open world: a compass at the top and the map on M.
func _setup_world() -> void:
	if get_tree().get_first_node_in_group(&"open_world") == null:
		return
	add_child(Compass.new())
	var map := MapWindow.new()
	add_child(map)
	move_child(map, get_child_count() - 1)


func _connect_combat() -> void:
	var combat := get_tree().get_first_node_in_group(PlayerCombat.GROUP) as PlayerCombat
	if combat == null:
		return
	_combat_box.visible = true
	combat.health_changed.connect(func(value: float, max_value: float) -> void: _health_bar.value = value / max_value * 100.0)
	combat.stamina_changed.connect(func(value: float, max_value: float) -> void: _stamina_bar.value = value / max_value * 100.0)
	combat.target_changed.connect(_on_target_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	_health_bar.value = combat.health / combat.data.max_health * 100.0
	_stamina_bar.value = combat.stamina / combat.data.max_stamina * 100.0
	_on_coins_changed(GameState.coins)


func _on_coins_changed(coins: int) -> void:
	_coins_label.text = "Монеты  %d" % coins


func _on_target_changed(node: Node3D) -> void:
	_target = node
	var has_posture := node != null and node.has_method(&"posture_ratio")
	_target_posture.visible = has_posture
	_target_hint.visible = has_posture
	if node:
		_target_name.text = str(node.get(&"lock_name")).to_upper()
		_target_bar.value = float(node.call(&"health_ratio")) * 100.0
	create_tween().tween_property(_target_box, ^"modulate:a", 1.0 if node else 0.0, 0.2)


func _bar(color: Color, bar_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = bar_size
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.show_percentage = false
	bar.value = 100.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.04, 0.04, 0.6)
	back.border_color = Color(UiStyle.COLOR_DIM, 0.5)
	back.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override(&"background", back)
	bar.add_theme_stylebox_override(&"fill", fill)
	return bar


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
