class_name WorldActivity
extends Node
## Дальний мир сохраняет персонажей и флаги, но не тратит кадры на спокойных актёров.

var _timer: float = 0.0
var _sleeping: Dictionary[int, int] = {}


func _ready() -> void:
	add_to_group(&"world_activity")


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = GameState.WORLD.activity_interval
	refresh()


func refresh() -> void:
	for key: int in _sleeping.keys():
		if not is_instance_id_valid(key):
			_sleeping.erase(key)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		for key: int in _sleeping.keys():
			_wake(instance_from_id(key) as Node3D)
		return
	for group: StringName in [&"enemies", &"wildlife", &"world_residents"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var actor := node as Node3D
			if actor == null or not get_parent().is_ancestor_of(actor):
				continue
			var id := actor.get_instance_id()
			var distance := actor.global_position.distance_squared_to(player.global_position)
			if _sleeping.has(id):
				if distance <= pow(GameState.WORLD.actor_wake_distance, 2) or _must_stay_awake(actor):
					_wake(actor)
			elif distance > pow(GameState.WORLD.actor_sleep_distance, 2) and not _must_stay_awake(actor):
				if actor.process_mode != Node.PROCESS_MODE_DISABLED:
					_sleeping[id] = actor.process_mode
					actor.process_mode = Node.PROCESS_MODE_DISABLED


func sleeping_count() -> int:
	return _sleeping.size()


func _must_stay_awake(actor: Node3D) -> bool:
	var body := actor as CharacterBody3D
	if body and not body.is_on_floor():
		return true
	var enemy := actor as Enemy
	if enemy:
		return enemy.state not in [Enemy.State.PATROL, Enemy.State.CALM] \
				or enemy.sense.alertness > 0.0 or enemy.health < enemy.data.max_health
	return false


func _wake(actor: Node3D) -> void:
	var id := actor.get_instance_id()
	actor.process_mode = _sleeping[id]
	_sleeping.erase(id)
