class_name Deer
extends CharacterBody3D
## A deer grazing in a meadow: wanders slowly, bolts away when Mara comes close.

const SPOOK_DISTANCE := 14.0
const FLEE_SPEED := 9.0
const WANDER_SPEED := 1.0
const FLEE_TIME := 5.0

var _home: Vector3
var _flee_time: float = 0.0
var _wander_target: Vector3
var _wander_wait: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _rng := RandomNumberGenerator.new()

@onready var _model: AnimatedModel = $Model


func _ready() -> void:
	add_to_group(&"wildlife")
	collision_layer = 1 << 1
	collision_mask = 1
	_rng.randomize()
	_home = global_position
	_wander_target = global_position
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.rotation.x = PI * 0.5
	shape.position.y = 0.8
	add_child(shape)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var move := Vector3.ZERO
	if player and global_position.distance_to(player.global_position) < SPOOK_DISTANCE:
		_flee_time = FLEE_TIME
	if _flee_time > 0.0 and player:
		_flee_time -= delta
		var away := global_position - player.global_position
		away.y = 0.0
		move = away.normalized() * FLEE_SPEED
	else:
		_wander_wait -= delta
		var to := _wander_target - global_position
		to.y = 0.0
		if to.length() < 0.6:
			if _wander_wait <= 0.0:
				_wander_target = _home + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8))
				_wander_wait = _rng.randf_range(4.0, 10.0)
		elif _wander_wait <= 0.0:
			move = to.normalized() * WANDER_SPEED
	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()
	if move.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-move.x, -move.z), clampf(6.0 * delta, 0.0, 1.0))
		_model.play(&"Gallop" if move.length() > 3.0 else &"Walk")
	else:
		_model.play(&"Eating" if fmod(Time.get_ticks_msec() / 1000.0 + _home.x, 12.0) > 7.0 else &"Idle")
