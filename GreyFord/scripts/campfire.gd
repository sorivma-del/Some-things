extends Node3D
## Campfire in the village centre: a ring of stones, burning logs, particle flames,
## sparks and smoke, a flickering warm light, and logs to sit on.

const ROCK := "res://resources/models/nature/Rock_Medium_%d.gltf"
const COL_EMBERS := Color(1.0, 0.42, 0.12)

@export var base_energy: float = 6.0
@export var flicker_strength: float = 0.35
@export var flicker_speed: float = 9.0

var _light: OmniLight3D
var _flames: CPUParticles3D
var _noise := FastNoiseLite.new()
var _time: float = 0.0


func _ready() -> void:
	_noise.frequency = 0.8
	_noise.seed = 91

	for i: int in 9:
		var a := TAU * float(i) / 9.0
		var stone := KitBuilder.instance_of(ROCK % (i % 3 + 1))
		stone.position = Vector3(cos(a) * 0.9, -0.05, sin(a) * 0.9)
		stone.rotation = Vector3(0.0, a * 3.0, 0.0)
		stone.scale = Vector3.ONE * 0.17
		add_child(stone)
	var bark := Build.bark_material(Color(0.42, 0.34, 0.28))
	var charred := Build.bark_material(Color(0.16, 0.12, 0.1))
	for i: int in 3:
		Build.cylinder(self, 0.09, 1.3, Vector3(0.0, 0.25, 0.0), charred, 6, Vector3(75.0, 60.0 * i, 0.0))
	Build.cylinder(self, 0.55, 0.06, Vector3(0.0, 0.05, 0.0), Build.material(Color(0.1, 0.05, 0.03), COL_EMBERS, 2.0), 9)

	_flames = Effects.flames(self, Vector3(0.0, 0.3, 0.0))
	Effects.sparks(self, Vector3(0.0, 0.6, 0.0))
	Effects.smoke(self, Vector3(0.0, 1.6, 0.0), 10, 1.0)

	# Logs to sit on, lying across the direction to the fire.
	Build.cylinder(self, 0.2, 2.2, Vector3(-2.3, 0.2, -0.6), bark, 8, Vector3(90.0, -15.0, 0.0))
	Build.cylinder(self, 0.2, 2.0, Vector3(1.6, 0.2, -2.0), bark, 8, Vector3(90.0, 51.0, 0.0))
	Build.static_cylinder(self, 0.9, 1.0, Vector3(0.0, 0.5, 0.0))

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.26)
	_light.light_energy = base_energy
	_light.omni_range = 18.0
	_light.omni_attenuation = 1.3
	_light.shadow_enabled = true
	_light.position = Vector3(0.0, 1.3, 0.0)
	add_child(_light)

	var crackle := AudioStreamPlayer3D.new()
	crackle.stream = ProceduralSound.fire_crackle()
	crackle.volume_db = -6.0
	crackle.unit_size = 4.0
	crackle.max_distance = 30.0
	crackle.position = Vector3(0.0, 0.5, 0.0)
	add_child(crackle)
	ProceduralSound.play_soon(crackle)


func _process(delta: float) -> void:
	_time += delta
	var t := _time * flicker_speed
	var n := _noise.get_noise_1d(t)
	_light.light_energy = base_energy * (1.0 + n * flicker_strength)
	_light.position = Vector3(_noise.get_noise_2d(t, 13.0) * 0.08, 1.3 + n * 0.05, _noise.get_noise_2d(t, 47.0) * 0.08)
	# Gusts make the flames lean and swell together with the light.
	_flames.gravity = Vector3(_noise.get_noise_2d(t * 0.3, 5.0) * 0.6, 1.6 + n * 0.5, 0.0)
