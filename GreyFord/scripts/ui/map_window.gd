class_name MapWindow
extends GameWindow
## The map (M) of the land beyond the gate: the parchment drawn from the terrain, the
## places Mara has found, campfires, Mara and her horse. Campfires found so far can be
## travelled to (time passes by distance; refused with enemies nearby).

const MAP_SIZE := Vector2(560, 560)

var _overlay: Control


func _ready() -> void:
	super()
	add_to_group(&"map_window")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"map"):
		if is_open:
			close_window()
		elif not GameState.controls_locked and _world():
			open_window()
		get_viewport().set_input_as_handled()
		return
	super(event)


func _world() -> OpenWorld:
	return get_tree().get_first_node_in_group(&"open_world") as OpenWorld


func _process(_delta: float) -> void:
	if is_open and _overlay:
		_overlay.queue_redraw()


func _refresh() -> void:
	_clear()
	var world := _world()
	if world == null:
		return
	_title.text = "Земли за Бродом"
	_subtitle.text = "День %d, %s   ·   найдено мест: %d из %d" % [GameState.world_day, GameState.world_clock_text(),
			GameState.discovered.size(), OpenWorld.PLACES.size()]
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 22)
	_content.add_child(row)

	var frame := Control.new()
	frame.custom_minimum_size = MAP_SIZE
	row.add_child(frame)
	var picture := TextureRect.new()
	picture.texture = world.map_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.size = MAP_SIZE
	frame.add_child(picture)
	_overlay = Control.new()
	_overlay.size = MAP_SIZE
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_markers.bind(_overlay))
	frame.add_child(_overlay)

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override(&"separation", 4)
	row.add_child(side)
	var heading := Label.new()
	heading.text = "КОСТРЫ"
	UiStyle.apply_label(heading, 18, 700, false, UiStyle.COLOR_ACCENT, 4)
	side.add_child(heading)
	var blocker := world.travel_blocker()
	var destinations := world.travel_destinations()
	if destinations.is_empty():
		var none := Label.new()
		none.text = "Ни одного костра ещё не найдено."
		UiStyle.apply_label(none, 19, 500, true, UiStyle.COLOR_DIM)
		side.add_child(none)
	for id: String in destinations:
		var hours := world.travel_hours(id)
		var label := "%s  ·  %s" % [OpenWorld.PLACES[id]["name"], OpenWorld._hours_text(hours)]
		_row(side, label, "", "", "Идти", _travel.bind(id), blocker.is_empty() and hours > 0.05)
	if not blocker.is_empty():
		var note := Label.new()
		note.text = blocker
		UiStyle.apply_label(note, 19, 600, true, Color(0.86, 0.38, 0.3))
		side.add_child(note)
	var legend := Label.new()
	legend.text = "\n◆ место   ▲ костёр   ➤ Мара   ● лошадь\nM — закрыть карту"
	UiStyle.apply_label(legend, 17, 500, true, UiStyle.COLOR_DIM)
	side.add_child(legend)


func _travel(id: String) -> void:
	close_window()
	_world().fast_travel(id)


func _draw_markers(canvas: Control) -> void:
	var font := UiStyle.font(600)
	for id: String in OpenWorld.PLACES:
		if not GameState.discovered.has(id):
			continue
		var place: Dictionary = OpenWorld.PLACES[id]
		var p := _to_map(place["pos"])
		var fire: bool = place["fire"]
		var color := Color(0.85, 0.42, 0.15) if fire else Color(0.2, 0.14, 0.1)
		if fire:
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 5), p + Vector2(-6, 5)]), color)
		else:
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)]), color)
		canvas.draw_string_outline(font, p + Vector2(9, 5), place["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0.95, 0.9, 0.78, 0.9))
		canvas.draw_string(font, p + Vector2(9, 5), place["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.15, 0.1, 0.07))
	var horse := get_tree().get_first_node_in_group(Horse.GROUP) as Horse
	if horse and horse.is_owned():
		canvas.draw_circle(_to_map(Vector2(horse.global_position.x, horse.global_position.z)), 5.0, Color(0.45, 0.25, 0.12))
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player:
		var model := player.get_node(^"Model") as Node3D
		var forward := -model.global_basis.z
		var dir := Vector2(forward.x, forward.z).normalized()
		var p := _to_map(Vector2(player.global_position.x, player.global_position.z))
		var side := Vector2(-dir.y, dir.x)
		canvas.draw_colored_polygon(PackedVector2Array([p + dir * 10.0, p - dir * 6.0 + side * 6.0, p - dir * 3.0, p - dir * 6.0 - side * 6.0]), Color(0.75, 0.1, 0.08))


func _to_map(world_xz: Vector2) -> Vector2:
	return WorldTerrain.map_uv(world_xz.x, world_xz.y) * MAP_SIZE
