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
@export_group("Dialogue framing")
@export var dialogue_distance: float = 3.4
@export var dialogue_pitch_degrees: float = -12.0
## Camera swings this far off the Mara-to-speaker line, looking over her shoulder.
@export var dialogue_side_degrees: float = 40.0
@export var framing_speed: float = 3.0

var _speaker: Node3D
var _saved_yaw: float
var _saved_pitch: float

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	_arm.spring_length = distance
	if target is CollisionObject3D:
		_arm.add_excluded_object((target as CollisionObject3D).get_rid())
	snap_to_target()
	DialogueRunner.dialogue_started.connect(_on_dialogue_started)
	DialogueRunner.dialogue_finished.connect(_on_dialogue_finished)


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and (motion.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0 and not GameState.controls_locked:
		yaw_degrees -= motion.relative.x * mouse_sensitivity
		pitch_degrees = clampf(pitch_degrees - motion.relative.y * mouse_sensitivity, pitch_limits.x, pitch_limits.y)


func _process(delta: float) -> void:
	if target == null:
		return
	var goal := target.global_position + Vector3.UP * height
	var length := distance
	if _speaker:
		goal = (target.global_position + _speaker.global_position) * 0.5 + Vector3.UP * (height - 0.2)
		length = dialogue_distance
	global_position = global_position.lerp(goal, clampf(follow_speed * delta, 0.0, 1.0))
	var weight := clampf(framing_speed * delta, 0.0, 1.0)
	rotation.x = lerp_angle(rotation.x, deg_to_rad(pitch_degrees), weight)
	rotation.y = lerp_angle(rotation.y, deg_to_rad(yaw_degrees), weight)
	_arm.spring_length = lerpf(_arm.spring_length, length, weight)


func snap_to_target() -> void:
	if target:
		global_position = target.global_position + Vector3.UP * height
	rotation_degrees = Vector3(pitch_degrees, yaw_degrees, 0.0)


func make_current() -> void:
	_camera.make_current()


func get_camera() -> Camera3D:
	return _camera


func _on_dialogue_started(_resource: DialogueResource, speaker: Node3D) -> void:
	if speaker == null or target == null:
		return
	_speaker = speaker
	_saved_yaw = yaw_degrees
	_saved_pitch = pitch_degrees
	var to_speaker := speaker.global_position - target.global_position
	yaw_degrees = rad_to_deg(atan2(-to_speaker.x, -to_speaker.z)) + dialogue_side_degrees
	pitch_degrees = dialogue_pitch_degrees


func _on_dialogue_finished(_resource: DialogueResource) -> void:
	if _speaker == null:
		return
	_speaker = null
	yaw_degrees = _saved_yaw
	pitch_degrees = _saved_pitch
