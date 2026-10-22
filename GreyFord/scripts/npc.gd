extends StaticBody3D
## A villager Mara can talk to. Uses the child Interactable to start its dialogue and
## switches to a talking animation while that dialogue is open.

@export var dialogue: DialogueResource
@export var cue: String = "start"
@export var idle_animation: StringName = &"Idle"
@export var talk_animation: StringName = &"Idle_Talking"
## Turn to face Mara when spoken to (off for NPCs that sit in place).
@export var face_player: bool = true

@onready var _model: CharacterModel = $Model
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_model.play(idle_animation)
	_interactable.interacted.connect(_on_interacted)
	DialogueRunner.dialogue_started.connect(_on_dialogue_started)
	DialogueRunner.dialogue_finished.connect(_on_dialogue_finished)


func _on_interacted() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player:
		if face_player:
			var to := player.global_position - global_position
			_model.rotation.y = atan2(-to.x, -to.z) - rotation.y
		if player.has_method(&"face_point"):
			player.call(&"face_point", global_position)
	DialogueRunner.start_dialogue(dialogue, cue, self)


func _on_dialogue_started(resource: DialogueResource, _speaker: Node3D) -> void:
	if resource == dialogue:
		_model.play(talk_animation)


func _on_dialogue_finished(resource: DialogueResource) -> void:
	if resource == dialogue:
		_model.play(idle_animation)
