extends CharacterBody3D
## Mara: third-person movement relative to the active camera. Ignores input while
## GameState.controls_locked is set (dialogue, cutscenes); cutscenes move her with walk_to().

## Emitted when a walk_to() target is reached.
signal arrived
## Hidden state changed (inside a house).
signal hidden_changed(hidden: bool)

@export var walk_speed: float = 2.6
@export var acceleration: float = 14.0
@export var turn_speed: float = 10.0
@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"Walk"
@export var step_interval: float = 0.42

## 0 = in the open, 1 = fully covered. Highest cover among overlapping HideZones.
var concealment: float:
	get:
		var best := 0.0
		for zone: HideZone in _cover:
			best = maxf(best, zone.concealment)
		return best
## Inside a house: watchmen cannot see her at all.
var hidden: bool = false:
	set(value):
		hidden = value
		_model.visible = not value
		hidden_changed.emit(value)

var _cover: Array[HideZone] = []
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _walk_target: Vector3
var _walking_to: bool = false
var _step_time: float = 0.0
var _steps := AudioStreamPlayer3D.new()
var _step_sounds: Array[AudioStreamWAV] = []

@onready var _model: CharacterModel = $Model


func _ready() -> void:
	_steps.volume_db = -10.0
	add_child(_steps)
	for variant: int in 3:
		_step_sounds.append(ProceduralSound.footstep(variant))


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var direction := Vector3.ZERO
	if _walking_to:
		var to := _walk_target - global_position
		to.y = 0.0
		if to.length() < 0.25:
			_walking_to = false
			arrived.emit()
		else:
			direction = to.normalized()
	elif not GameState.controls_locked:
		var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		direction = _camera_relative(input)

	var target := direction * walk_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	var moving := horizontal.length() > 0.4
	_model.play(walk_animation if moving else idle_animation)
	_step_time = _step_time + delta if moving else step_interval * 0.6
	if _step_time >= step_interval:
		_step_time = 0.0
		_steps.stream = _step_sounds.pick_random()
		_steps.pitch_scale = randf_range(0.85, 1.1)
		_steps.play()

	if direction.length_squared() > 0.001:
		var target_yaw := atan2(-direction.x, -direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))


func enter_cover(zone: HideZone) -> void:
	if not _cover.has(zone):
		_cover.append(zone)


func leave_cover(zone: HideZone) -> void:
	_cover.erase(zone)


## Moves Mara instantly (scene changes between village, forest and bed).
func teleport(point: Vector3, facing: Vector3 = Vector3.ZERO) -> void:
	global_position = point
	velocity = Vector3.ZERO
	_walking_to = false
	if facing != Vector3.ZERO:
		face_point(point + facing)


## Walk to a point on the ground regardless of player input (for cutscenes).
func walk_to(point: Vector3) -> void:
	_walk_target = point
	_walking_to = true


## Rotate the model to look at a point on the ground plane (used by dialogues/cutscenes).
func face_point(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() > 0.0001:
		_model.rotation.y = atan2(-to.x, -to.z)


func _camera_relative(input: Vector2) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input.x, 0.0, input.y).normalized()
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	return (right * input.x - forward * input.y).normalized() * minf(input.length(), 1.0)
