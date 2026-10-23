class_name Compass
extends Control
## A compass strip at the top of the screen in the open world: north/east/south/west by
## the camera's heading, found places as diamonds (named when ahead), the horse as a dot.

const WIDTH := 620.0
const HEIGHT := 40.0
## Degrees of the horizon the strip shows.
const SPAN := 180.0
const LETTERS: Dictionary[String, float] = {"С": 0.0, "В": 90.0, "Ю": 180.0, "З": 270.0}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 14.0
	offset_bottom = 14.0 + HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var forward := -camera.global_basis.z
	# Bearing clockwise from north (-z).
	var heading := fposmod(rad_to_deg(atan2(forward.x, -forward.z)), 360.0)
	var font := UiStyle.font(600)
	var line_y := HEIGHT * 0.55
	draw_line(Vector2(0, line_y), Vector2(WIDTH, line_y), Color(0.9, 0.85, 0.75, 0.35), 1.0)
	for tick: int in range(0, 360, 15):
		var x := _x_for(tick, heading)
		if x < 0.0:
			continue
		var major := tick % 90 == 0
		draw_line(Vector2(x, line_y - (6.0 if major else 3.0)), Vector2(x, line_y + (6.0 if major else 3.0)), Color(0.9, 0.85, 0.75, 0.6), 1.0)
	for letter: String in LETTERS:
		var x := _x_for(LETTERS[letter], heading)
		if x >= 0.0:
			draw_string_outline(font, Vector2(x - 6, line_y - 9), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, UiStyle.COLOR_OUTLINE)
			draw_string(font, Vector2(x - 6, line_y - 9), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiStyle.COLOR_ACCENT if letter == "С" else UiStyle.COLOR_TEXT)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var from := Vector2(player.global_position.x, player.global_position.z)
	for id: String in OpenWorld.PLACES:
		if not GameState.discovered.has(id):
			continue
		var place: Dictionary = OpenWorld.PLACES[id]
		var to: Vector2 = place["pos"] - from
		if to.length() < 8.0:
			continue
		var bearing := fposmod(rad_to_deg(atan2(to.x, -to.y)), 360.0)
		var x := _x_for(bearing, heading)
		if x < 0.0:
			continue
		var color := Color(0.95, 0.55, 0.25) if place["fire"] else Color(0.92, 0.88, 0.78)
		draw_colored_polygon(PackedVector2Array([Vector2(x, line_y - 5), Vector2(x + 5, line_y), Vector2(x, line_y + 5), Vector2(x - 5, line_y)]), color)
		if absf(x - WIDTH * 0.5) < 40.0:
			var text := "%s  %d м" % [place["name"], roundi(to.length())]
			draw_string_outline(font, Vector2(x - 60, line_y + 22), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, 4, UiStyle.COLOR_OUTLINE)
			draw_string(font, Vector2(x - 60, line_y + 22), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, UiStyle.COLOR_TEXT)
	var horse := get_tree().get_first_node_in_group(Horse.GROUP) as Horse
	if horse and horse.is_owned() and not horse.is_ridden():
		var to := Vector2(horse.global_position.x, horse.global_position.z) - from
		var x := _x_for(fposmod(rad_to_deg(atan2(to.x, -to.y)), 360.0), heading)
		if x >= 0.0:
			draw_circle(Vector2(x, line_y), 4.0, Color(0.6, 0.35, 0.18))


## Screen x for a bearing, or -1 if it is outside the strip.
func _x_for(bearing: float, heading: float) -> float:
	var diff := wrapf(bearing - heading, -180.0, 180.0)
	if absf(diff) > SPAN * 0.5:
		return -1.0
	return WIDTH * 0.5 + diff / (SPAN * 0.5) * WIDTH * 0.5
