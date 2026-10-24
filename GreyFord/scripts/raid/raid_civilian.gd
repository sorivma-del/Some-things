class_name RaidCivilian
extends CharacterBody3D
## Житель уходит по свободной центральной улице к двери церкви.

const CONFIG: RaidConfig = preload("res://resources/raid/raid_config.tres")

signal sheltered

var route: PackedVector3Array = []
var _index: int = 0
var _moving: bool = false
var _hide_at_end: bool = true
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _model: CharacterModel = $Model


func evacuate(points: PackedVector3Array, hide_on_arrival: bool = true) -> void:
	_hide_at_end = hide_on_arrival
	show()
	set_physics_process(true)
	route = points
	_index = 0
	_moving = not route.is_empty()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	velocity.x = 0.0
	velocity.z = 0.0
	if _moving:
		var to := route[_index] - global_position
		to.y = 0.0
		if to.length() < 0.5:
			_index += 1
			if _index >= route.size():
				_moving = false
				if _hide_at_end:
					hide()
					set_physics_process(false)
					sheltered.emit()
		else:
			var speed: float = CONFIG.civilian_speed
			var move := to.normalized() * speed
			velocity.x = move.x
			velocity.z = move.z
			_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-move.x, -move.z), minf(1.0, delta * 8.0))
	move_and_slide()
	_model.play(&"Jog_Fwd" if _moving else &"Idle")
