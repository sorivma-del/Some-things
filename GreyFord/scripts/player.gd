extends CharacterBody3D
## Mara: third-person movement relative to the active camera. Ignores input while
## GameState.controls_locked is set (dialogue, cutscenes); cutscenes move her with walk_to().

## Emitted when a walk_to() target is reached.
signal arrived

@export var walk_speed: float = 2.6
@export var acceleration: float = 14.0
@export var turn_speed: float = 10.0
@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"Walk"

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _walk_target: Vector3
var _walking_to: bool = false

@onready var _model: CharacterModel = $Model


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
	_model.play(walk_animation if horizontal.length() > 0.4 else idle_animation)

	if direction.length_squared() > 0.001:
		var target_yaw := atan2(-direction.x, -direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))


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
