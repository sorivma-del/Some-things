extends Node3D
## Third-person follow camera. Smoothly trails the target; hold the right mouse
## button to orbit. A SpringArm3D keeps the camera out of walls.

@export var target: Node3D
@export var follow_speed: float = 6.0
@export var height: float = 1.5
@export var distance: float = 4.5
@export var pitch_degrees: float = -18.0
@export var yaw_degrees: float = 35.0
@export var mouse_sensitivity: float = 0.25
@export var pitch_limits: Vector2 = Vector2(-55.0, -5.0)

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	_arm.spring_length = distance
	if target is CollisionObject3D:
		_arm.add_excluded_object((target as CollisionObject3D).get_rid())
	snap_to_target()


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and (motion.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0 and not GameState.controls_locked:
		yaw_degrees -= motion.relative.x * mouse_sensitivity
		pitch_degrees = clampf(pitch_degrees - motion.relative.y * mouse_sensitivity, pitch_limits.x, pitch_limits.y)


func _process(delta: float) -> void:
	if target == null:
		return
	var goal := target.global_position + Vector3.UP * height
	global_position = global_position.lerp(goal, clampf(follow_speed * delta, 0.0, 1.0))
	rotation_degrees = Vector3(pitch_degrees, yaw_degrees, 0.0)


func snap_to_target() -> void:
	if target:
		global_position = target.global_position + Vector3.UP * height
	rotation_degrees = Vector3(pitch_degrees, yaw_degrees, 0.0)


func make_current() -> void:
	_camera.make_current()


func get_camera() -> Camera3D:
	return _camera
