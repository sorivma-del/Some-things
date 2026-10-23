class_name HideHouse
extends Interactable
## A friendly door Mara can slip behind at night: inside she is hidden from the hunters
## (Player.hidden). E again steps back out. Closed during the day.

var _inside: bool = false


func _ready() -> void:
	super()
	_update()
	GameState.time_changed.connect(_update)
	interacted.connect(_toggle)


func _update() -> void:
	var night := GameState.phase == GameState.Phase.NIGHT
	if not night and _inside:
		_set_inside(false)
	enabled = night
	prompt = "Выйти" if _inside else "Спрятаться в доме"


func _toggle() -> void:
	_set_inside(not _inside)
	_update()


func _set_inside(inside: bool) -> void:
	_inside = inside
	var player := get_tree().get_first_node_in_group(&"player")
	if player:
		player.set(&"hidden", inside)
		player.set(&"frozen", inside)
	if inside:
		GameState.notified.emit("Мара затаилась за дверью")
