extends Node
## Starts dialogues: locks controls, opens a DialogueBalloon, unlocks when it closes.
## Only one dialogue runs at a time.

## `speaker` is the node Mara talks to (null for inspections); the camera frames it.
signal dialogue_started(resource: DialogueResource, speaker: Node3D)
signal dialogue_finished(resource: DialogueResource)

var is_active: bool = false


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
