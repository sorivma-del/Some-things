class_name FlickerLight
extends OmniLight3D
## A small open flame's light: energy and position wobble on smooth noise.

@export var base_energy: float = 1.6
@export var strength: float = 0.3
@export var speed: float = 11.0
@export var jitter: float = 0.04

var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _origin: Vector3


func _ready() -> void:
	_noise.frequency = 0.9
	_noise.seed = randi()
	_origin = position


func _process(delta: float) -> void:
	_time += delta * speed
	var n := _noise.get_noise_1d(_time)
	light_energy = base_energy * (1.0 + n * strength)
	position = _origin + Vector3(_noise.get_noise_2d(_time, 7.0), n, _noise.get_noise_2d(_time, 19.0)) * jitter
