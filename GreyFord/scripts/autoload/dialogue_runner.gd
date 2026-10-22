extends Node
## Starts dialogues: locks controls, opens a DialogueBalloon, unlocks when it closes.
## Only one dialogue runs at a time.

## `speaker` is the node Mara talks to (null for inspections); the camera frames it.
signal dialogue_started(resource: DialogueResource, speaker: Node3D)
signal dialogue_finished(resource: DialogueResource)
## A skill check was rolled: d20 + stat bonus against difficulty.
signal check_rolled(stat: StringName, roll: int, bonus: int, difficulty: int, passed: bool)

## How long a dialogue pauses on a roll so the result can be read.
const CHECK_PAUSE := 2.6

var is_active: bool = false
## Result of the latest roll_check(); dialogue branches on it.
var last_check_passed: bool = false

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func start_dialogue(resource: DialogueResource, cue: String = "start", speaker: Node3D = null,
		extra_game_states: Array = []) -> void:
	if is_active or resource == null:
		return
	is_active = true
	GameState.lock_controls()
	var balloon := DialogueBalloon.new()
	get_tree().root.add_child(balloon)
	balloon.finished.connect(_on_balloon_finished.bind(resource), CONNECT_ONE_SHOT)
	dialogue_started.emit(resource, speaker)
	balloon.start(resource, cue, extra_game_states)


func _on_balloon_finished(resource: DialogueResource) -> void:
	is_active = false
	GameState.unlock_controls()
	dialogue_finished.emit(resource)


## Rolls d20 + the hero's stat against `difficulty`. Called from dialogue as a mutation;
## Dialogue Manager waits for it, so the roll stays on screen before the story continues.
func roll_check(stat: String, difficulty: int) -> void:
	var stat_name := StringName(stat)
	var roll := _rng.randi_range(1, 20)
	var bonus := GameState.stats.get_stat(stat_name)
	last_check_passed = roll + bonus >= difficulty
	check_rolled.emit(stat_name, roll, bonus, difficulty, last_check_passed)
	await get_tree().create_timer(CHECK_PAUSE).timeout
