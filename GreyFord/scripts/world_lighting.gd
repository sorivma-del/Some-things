extends Node3D
## Time-of-day look: morning, day and evening stay in the grey plague dusk but differ in
## light and fog; night is dark and blue so the lit windows and lanterns stand out.
## Follows GameState.time_changed.

const BLEND_TIME := 2.5
## Moon energy, moon colour, rim energy, ambient energy, fog density, fog colour.
const PRESETS: Dictionary[String, Array] = {
	"morning": [0.62, Color(0.72, 0.74, 0.82), 0.3, 0.42, 0.032, Color(0.36, 0.36, 0.4)],
	"day": [0.7, Color(0.76, 0.76, 0.8), 0.3, 0.46, 0.027, Color(0.4, 0.4, 0.43)],
	"evening": [0.45, Color(0.56, 0.66, 0.88), 0.28, 0.3, 0.04, Color(0.27, 0.27, 0.31)],
	"night": [0.16, Color(0.45, 0.55, 0.85), 0.1, 0.13, 0.045, Color(0.11, 0.12, 0.16)],
}

## Multiplier on fog density (the open world is less closed in than the village).
var fog_scale: float = 1.0

@onready var _env: Environment = ($WorldEnvironment as WorldEnvironment).environment
@onready var _moon: DirectionalLight3D = $Moonlight
@onready var _rim: DirectionalLight3D = $RimLight


func _ready() -> void:
	add_to_group(&"world_lighting")
	_apply(_preset_name(), 0.0)
	GameState.time_changed.connect(func() -> void: _apply(_preset_name(), BLEND_TIME))


func set_fog_scale(value: float) -> void:
	fog_scale = value
	_apply(_preset_name(), 0.0)


func _preset_name() -> String:
	if GameState.world_mode:
		return GameState.world_period()
	if GameState.phase == GameState.Phase.NIGHT:
		return "night"
	return ["morning", "day", "evening"][clampi(GameState.slots_used, 0, 2)]


func _apply(preset: String, duration: float) -> void:
	var p: Array = PRESETS[preset]
	if duration <= 0.0:
		_moon.light_energy = p[0]
		_moon.light_color = p[1]
		_rim.light_energy = p[2]
		_env.ambient_light_energy = p[3]
		_env.fog_density = p[4] * fog_scale
		_env.fog_light_color = p[5]
		return
	var tween := create_tween().set_parallel()
	tween.tween_property(_moon, ^"light_energy", p[0], duration)
	tween.tween_property(_moon, ^"light_color", p[1], duration)
	tween.tween_property(_rim, ^"light_energy", p[2], duration)
	tween.tween_property(_env, ^"ambient_light_energy", p[3], duration)
	tween.tween_property(_env, ^"fog_density", p[4] * fog_scale, duration)
	tween.tween_property(_env, ^"fog_light_color", p[5], duration)
