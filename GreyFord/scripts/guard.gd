class_name Guard
extends CharacterBody3D
## A watchman with a lantern: walks a patrol route and looks for Mara with a cone of
## vision and a line-of-sight ray. Seeing her fills an alertness meter:
## PATROL -> SUSPICIOUS (stops, stares) -> CHASE (runs at her) -> SEARCH (checks where
## she was last seen) -> back to PATROL. Reaching her during a chase emits `caught_player`.
## Cover reduces how fast he notices her (Player.concealment); hiding makes her invisible.

signal caught_player
signal state_changed(state: State)

enum State { PATROL, SUSPICIOUS, CHASE, SEARCH }

const EYE_HEIGHT := 1.6
const TARGET_HEIGHT := 1.0
const CATCH_DISTANCE := 1.3

@export var route: PackedVector3Array = []
@export var walk_speed: float = 1.4
@export var chase_speed: float = 2.45  ## Slightly slower than Mara: she can break away.
@export var view_distance: float = 13.0
@export var view_angle_degrees: float = 55.0  ## Half-angle of the vision cone.
## Alertness gained per second when Mara is fully visible at close range.
@export var notice_rate: float = 1.1
@export var forget_rate: float = 0.35
@export var suspicious_threshold: float = 0.3
@export var search_time: float = 7.0
@export var lose_sight_time: float = 2.5

var state: State = State.PATROL
var alertness: float = 0.0

var _route_index: int = 0
var _last_seen: Vector3
var _timer: float = 0.0
var _unseen_time: float = 0.0
var _search_turn: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _player: Node3D
var _marker := Label3D.new()

@onready var _model: CharacterModel = $Model


func _ready() -> void:
	add_to_group(&"guards")
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.font = UiStyle.font(700)
	_marker.font_size = 96
	_marker.outline_size = 18
	_marker.pixel_size = 0.004
	_marker.position = Vector3(0.0, 2.25, 0.0)
	add_child(_marker)
	_set_state(State.PATROL)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	var sees := _can_see_player()
	_update_alertness(sees, delta)

	var target := global_position
	var speed := 0.0
	match state:
		State.PATROL:
			if route.size() > 0:
				target = route[_route_index]
				speed = walk_speed
				if _flat_distance(target) < 0.4:
					_route_index = (_route_index + 1) % route.size()
		State.SUSPICIOUS:
			_face(_last_seen, delta)
			if alertness <= 0.05:
				_set_state(State.PATROL)
		State.CHASE:
			target = _last_seen
			speed = chase_speed
			_unseen_time = 0.0 if sees else _unseen_time + delta
			if _unseen_time > lose_sight_time:
				_set_state(State.SEARCH)
			elif sees and _flat_distance(_player.global_position) < CATCH_DISTANCE:
				_set_state(State.SEARCH)
				alertness = 0.0
				caught_player.emit()
		State.SEARCH:
			_timer -= delta
			if _flat_distance(_last_seen) > 0.6:
				target = _last_seen
				speed = walk_speed * 1.3
			else:
				# Look around where she vanished.
				_search_turn += delta
				_model.rotation.y += sin(_search_turn * 1.7) * delta * 1.6
			if _timer <= 0.0:
				alertness = 0.0
				_set_state(State.PATROL)

	var to := target - global_position
	to.y = 0.0
	if speed > 0.0 and to.length() > 0.2:
		var dir := to.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_face(target, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	move_and_slide()
	_animate(Vector2(velocity.x, velocity.z).length())


func _update_alertness(sees: bool, delta: float) -> void:
	if sees:
		_last_seen = _player.global_position
		var distance := global_position.distance_to(_player.global_position)
		var closeness := clampf(1.0 - distance / view_distance, 0.15, 1.0)
		var visibility := 1.0 - (_player.get(&"concealment") as float)
		alertness = minf(alertness + notice_rate * closeness * visibility * delta * 1.6, 1.0)
	elif state != State.CHASE:
		alertness = maxf(alertness - forget_rate * delta, 0.0)

	if state == State.PATROL and alertness >= suspicious_threshold:
		_set_state(State.SUSPICIOUS)
	elif state == State.SUSPICIOUS and alertness >= 1.0:
		_set_state(State.CHASE)
	elif state == State.SEARCH and sees and alertness >= 0.6:
		_set_state(State.CHASE)


func _can_see_player() -> bool:
	if _player == null or (_player.get(&"hidden") as bool):
		return false
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var target := _player.global_position + Vector3.UP * TARGET_HEIGHT
	var to := target - eye
	if to.length() > view_distance:
		return false
	var forward := -_model.global_basis.z
	forward.y = 0.0
	var flat := Vector3(to.x, 0.0, to.z)
	# Within arm's reach he hears her even outside the cone.
	if flat.length() > 1.6 and rad_to_deg(forward.angle_to(flat)) > view_angle_degrees:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, 1)
	query.exclude = [get_rid(), (_player as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _set_state(new_state: State) -> void:
	state = new_state
	match state:
		State.SUSPICIOUS:
			_show_marker("?", Color(0.95, 0.8, 0.4))
		State.CHASE:
			_unseen_time = 0.0
			_show_marker("!", Color(0.95, 0.35, 0.25))
		State.SEARCH:
			_timer = search_time
			_search_turn = 0.0
			_show_marker("?", Color(0.85, 0.6, 0.35))
		State.PATROL:
			_marker.visible = false
			_route_index = _nearest_waypoint()
	state_changed.emit(state)


func _show_marker(text: String, color: Color) -> void:
	_marker.text = text
	_marker.modulate = color
	_marker.visible = true


func _animate(speed: float) -> void:
	if speed > walk_speed * 1.2:
		_model.play(&"Jog_Fwd")
	elif speed > 0.2:
		_model.play(&"Walk")
	elif state == State.SUSPICIOUS or state == State.SEARCH:
		_model.play(&"Idle")
	else:
		_model.play(&"Idle_Lantern")


func _face(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() > 0.01:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-to.x, -to.z), clampf(6.0 * delta, 0.0, 1.0))


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _nearest_waypoint() -> int:
	var best := 0
	for i: int in route.size():
		if _flat_distance(route[i]) < _flat_distance(route[best]):
			best = i
	return best
