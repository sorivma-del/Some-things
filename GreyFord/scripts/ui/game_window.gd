class_name GameWindow
extends Control
## A centred panel over a dimmed screen (trade, inventory). Opening locks Mara's controls,
## Esc or the close button shuts it. Subclasses fill `_content` in _refresh().

const PANEL_COLOR := Color(0.06, 0.055, 0.05, 0.94)
const BORDER_COLOR := Color(0.55, 0.42, 0.26, 0.6)
const ROW_COLOR := Color(1, 1, 1, 0.04)
const PANEL_SIZE := Vector2(1040, 620)

var is_open: bool = false

var _title: Label
var _subtitle: Label
var _content: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	# Fixed size around the screen centre; long lists scroll inside.
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_content_margin_all(26)
	panel.add_theme_stylebox_override(&"panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	panel.add_child(column)
	_title = Label.new()
	UiStyle.apply_label(_title, 34, 600, false, UiStyle.COLOR_TEXT, 2)
	column.add_child(_title)
	_subtitle = Label.new()
	UiStyle.apply_label(_subtitle, 20, 500, true, UiStyle.COLOR_DIM)
	column.add_child(_subtitle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override(&"separation", 4)
	scroll.add_child(_content)
	var close := UiStyle.button("Закрыть  (Esc)", close_window, 24)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(close)
	GameState.inventory_changed.connect(_refresh_if_open)
	GameState.coins_changed.connect(func(_coins: int) -> void: _refresh_if_open())
	GameState.equipment_changed.connect(_refresh_if_open)


func open_window() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	GameState.lock_controls()
	_refresh()


func close_window() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	GameState.unlock_controls()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"ui_cancel"):
		close_window()
		get_viewport().set_input_as_handled()


func _refresh_if_open() -> void:
	if is_open:
		_refresh()


func _refresh() -> void:
	pass


func _clear() -> void:
	for child: Node in _content.get_children():
		child.queue_free()


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	UiStyle.apply_label(label, 18, 700, false, UiStyle.COLOR_ACCENT, 4)
	_content.add_child(label)


## One line: name, details, price or note, and an optional action button.
func _row(parent: Container, name: String, details: String, note: String, action_text: String = "",
		action: Callable = Callable(), enabled: bool = true) -> void:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_COLOR
	style.set_content_margin_all(4)
	style.content_margin_left = 10
	row.add_theme_stylebox_override(&"panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)
	row.add_child(line)
	var name_label := Label.new()
	name_label.text = name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.apply_label(name_label, 22, 600, false, UiStyle.COLOR_TEXT)
	line.add_child(name_label)
	var details_label := Label.new()
	details_label.text = details
	UiStyle.apply_label(details_label, 18, 500, true, UiStyle.COLOR_DIM)
	line.add_child(details_label)
	var note_label := Label.new()
	note_label.text = note
	note_label.custom_minimum_size = Vector2(70, 0)
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.apply_label(note_label, 22, 600, false, UiStyle.COLOR_ACCENT)
	line.add_child(note_label)
	if not action_text.is_empty():
		var button := UiStyle.button(action_text, action, 22)
		button.custom_minimum_size = Vector2(120, 0)
		button.disabled = not enabled
		line.add_child(button)
	parent.add_child(row)
