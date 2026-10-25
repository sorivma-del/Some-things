class_name CombatSounds
extends Resource
## Разные записи для замаха, попадания, ранения и столкновения клинков.

@export var swing: Array[AudioStream] = []
@export var hit: Array[AudioStream] = []
@export var hurt: Array[AudioStream] = []
@export var block: Array[AudioStream] = []
@export var parry: Array[AudioStream] = []
@export var swing_db: float
@export var hit_db: float
@export var hurt_db: float
@export var block_db: float
@export var parry_db: float
@export var unit_size: float
@export var max_distance: float
@export var random_pitch: float
@export var impact_interval_ms: int


func bank() -> Dictionary[StringName, AudioStream]:
	var result: Dictionary[StringName, AudioStream] = {}
	for cue: StringName in [&"swing", &"hit", &"hurt", &"block", &"parry"]:
		var clips: Array[AudioStream] = get(String(cue))
		var pool := AudioStreamRandomizer.new()
		pool.resource_name = "Combat_%s" % cue
		pool.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		pool.random_pitch = random_pitch
		for clip: AudioStream in clips:
			pool.add_stream(-1, clip)
		result[cue] = pool
	return result


func volume(cue: StringName) -> float:
	return float(get(String(cue) + "_db"))
