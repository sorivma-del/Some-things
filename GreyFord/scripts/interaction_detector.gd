class_name InteractionDetector
extends Area3D
## Lives on the player. Tracks Interactables within reach, focuses the nearest one,
## reports its prompt for the HUD and triggers it on the "interact" action.

## Prompt of the focused Interactable, or "" when nothing is in reach.
signal focus_changed(prompt: String)

const GROUP := &"interaction_detector"

@export var reach: float = 1.8

var _focused: Interactable


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = Interactable.LAYER
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = reach
	shape.shape = sphere
	add_child(shape)
	GameState.controls_locked_changed.connect(func(_locked: bool) -> void: _refresh())


func _physics_process(_delta: float) -> void:
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and _focused and not GameState.controls_locked:
		get_viewport().set_input_as_handled()
		_focused.interact()


func _refresh() -> void:
	var best: Interactable = null
	if not GameState.controls_locked:
		var best_distance := INF
		for area: Area3D in get_overlapping_areas():
			var candidate := area as Interactable
			if candidate == null or not candidate.enabled:
				continue
			var distance := global_position.distance_squared_to(candidate.global_position)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	if best != _focused:
		_focused = best
		focus_changed.emit(best.prompt if best else "")
