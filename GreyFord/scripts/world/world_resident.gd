class_name WorldResident
extends CharacterBody3D
## Днём житель обходит двор, вечером идёт к костру, ночью возвращается домой.

@export var data: WorldResidentData
@export var dialogue: DialogueResource

var _route_index: int = 0
var _wait: float = 0.0
var _talking: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _model: CharacterModel = $Model
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(&"world_residents")
	collision_layer = CombatBody.BODY_LAYER
	collision_mask = 1 | CombatBody.BODY_LAYER
	_interactable.interacted.connect(_talk)
	DialogueRunner.dialogue_started.connect(_dialogue_started)
	DialogueRunner.dialogue_finished.connect(_dialogue_finished)
	GameState.time_changed.connect(_schedule_changed)


func destination() -> Vector2:
	match GameState.world_period():
		"night":
			return data.home
		"evening":
			return data.evening_spot
	return data.route[_route_index] if not data.route.is_empty() else data.home


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	velocity.x = 0.0
	velocity.z = 0.0
	if not GameState.controls_locked:
		_wait = maxf(0.0, _wait - delta)
		var target := destination()
		var to := target - Vector2(global_position.x, global_position.z)
		if to.length_squared() <= data.arrival_distance * data.arrival_distance:
			if _wait <= 0.0 and GameState.world_period() in ["morning", "day"] and not data.route.is_empty():
				_route_index = (_route_index + 1) % data.route.size()
				_wait = data.stop_seconds
		elif _wait <= 0.0:
			var move := to.normalized() * minf(data.walk_speed, to.length() / delta)
			velocity.x = move.x
			velocity.z = move.y
			_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-move.x, -move.y), minf(1.0, data.turn_speed * delta))
	move_and_slide()
	if not _talking:
		_model.play(&"Walk" if Vector2(velocity.x, velocity.z).length_squared() > 0.01 else &"Idle")


func _schedule_changed() -> void:
	_wait = 0.0


func _talk() -> void:
	if DialogueRunner.is_active:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player:
		var to := player.global_position - global_position
		_model.rotation.y = atan2(-to.x, -to.z)
		if player.has_method(&"face_point"):
			player.call(&"face_point", global_position)
	DialogueRunner.start_dialogue(dialogue, GameState.world_period(), self)


func _dialogue_started(_resource: DialogueResource, speaker: Node3D) -> void:
	if speaker == self:
		_talking = true
		_model.play(&"Idle_Talking")


func _dialogue_finished(resource: DialogueResource) -> void:
	if resource == dialogue:
		_talking = false
