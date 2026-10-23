extends Control
## Main menu: new game, continue from the last dawn autosave, the combat arena, quit.

const GAME_SCENE := "res://scenes/main.tscn"
const ARENA_SCENE := "res://scenes/test/combat_arena.tscn"
const BACKGROUND: Texture2D = preload("res://resources/ui/menu_background.jpg")

var _continue: Button


func _ready() -> void:
	GameState.reset_controls()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.modulate = Color(0.55, 0.55, 0.6)
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.04, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 6)
	add_child(column)

	column.add_child(_label("ГЛАВА ПЕРВАЯ", 17, 700, false, UiStyle.COLOR_ACCENT, 6))
	column.add_child(_label("Серый Брод", 92, 500, false, UiStyle.COLOR_TEXT, 4))
	column.add_child(_label("Три дня до огня.", 26, 500, true, UiStyle.COLOR_DIM, 0))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 36)
	column.add_child(gap)
	column.add_child(_button("Играть", _on_play))
	_continue = _button("Продолжить", _on_continue)
	_continue.disabled = not GameState.has_save()
	column.add_child(_continue)
	column.add_child(_button("Арена (бой)", _on_arena))
	column.add_child(_button("Выход", func() -> void: get_tree().quit()))
	Transition.fade_in(0.8)


func _on_play() -> void:
	GameState.new_game()
	await Transition.fade_out(0.8)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_arena() -> void:
	GameState.new_game()
	await Transition.fade_out(0.8)
	get_tree().change_scene_to_file(ARENA_SCENE)


func _on_continue() -> void:
	if not GameState.load_game():
		_continue.disabled = true
		return
	await Transition.fade_out(0.8)
	get_tree().change_scene_to_file(GAME_SCENE)


func _label(text: String, size: int, weight: int, italic: bool, color: Color, spacing: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.apply_label(label, size, weight, italic, color, spacing)
	return label


func _button(text: String, action: Callable) -> Button:
	return UiStyle.button(text, action)
