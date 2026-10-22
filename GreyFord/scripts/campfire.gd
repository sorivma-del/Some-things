extends Node3D
## Campfire in the village centre: stones, logs, flame cones and a flickering warm light.

const COL_FIRE := Color(1.0, 0.5, 0.18)
const COL_FIRE_CORE := Color(1.0, 0.78, 0.4)

@export var base_energy: float = 6.0
@export var flicker_strength: float = 0.35
@export var flicker_speed: float = 9.0

var _light: OmniLight3D
var _flames: Array[MeshInstance3D] = []
var _noise := FastNoiseLite.new()
var _time: float = 0.0


func _ready() -> void:
	_noise.frequency = 0.8
	_noise.seed = 91

	var stone := Build.material(Color(0.3, 0.3, 0.31))
	for i: int in 9:
		var a := TAU * float(i) / 9.0
		Build.cylinder(self, 0.22, 0.25, Vector3(cos(a) * 0.85, 0.12, sin(a) * 0.85), stone, 5)
	var wood := Build.material(Color(0.2, 0.13, 0.08))
	for i: int in 3:
		var a := 60.0 * float(i)
		Build.cylinder(self, 0.09, 1.3, Vector3(0.0, 0.25, 0.0), wood, 5, Vector3(75.0, a, 0.0))
	Build.cylinder(self, 0.55, 0.06, Vector3(0.0, 0.05, 0.0), Build.material(Color(0.1, 0.05, 0.03), COL_FIRE, 1.5), 7)

	_flames.append(Build.cone(self, 0.4, 0.9, Vector3(0.0, 0.55, 0.0), Build.material(COL_FIRE, COL_FIRE, 4.0), 5))
	_flames.append(Build.cone(self, 0.25, 0.65, Vector3(0.15, 0.45, 0.1), Build.material(COL_FIRE_CORE, COL_FIRE_CORE, 5.0), 5))
	_flames.append(Build.cone(self, 0.22, 0.55, Vector3(-0.15, 0.42, -0.08), Build.material(COL_FIRE_CORE, COL_FIRE_CORE, 5.0), 5))
	for flame: MeshInstance3D in _flames:
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Logs to sit on.
	Build.cylinder(self, 0.2, 2.2, Vector3(-2.3, 0.2, -0.6), wood, 6, Vector3(90.0, 75.0, 0.0))
	Build.cylinder(self, 0.2, 2.0, Vector3(1.6, 0.2, -2.0), wood, 6, Vector3(90.0, -35.0, 0.0))
	Build.static_cylinder(self, 0.9, 1.0, Vector3(0.0, 0.5, 0.0))

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.26)
	_light.light_energy = base_energy
	_light.omni_range = 18.0
	_light.omni_attenuation = 1.3
	_light.shadow_enabled = true
	_light.position = Vector3(0.0, 1.3, 0.0)
	add_child(_light)


func _process(delta: float) -> void:
	_time += delta
	var t := _time * flicker_speed
	var n := _noise.get_noise_1d(t)
	_light.light_energy = base_energy * (1.0 + n * flicker_strength)
	_light.position = Vector3(_noise.get_noise_2d(t, 13.0) * 0.08, 1.3 + n * 0.05, _noise.get_noise_2d(t, 47.0) * 0.08)
	for i: int in _flames.size():
		var k := _noise.get_noise_2d(t * 1.4, float(i) * 31.0)
		_flames[i].scale = Vector3(1.0 - k * 0.15, 1.0 + k * 0.35, 1.0 - k * 0.15)
