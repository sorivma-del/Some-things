class_name Inspectable
extends Interactable
## An object that plays a short dialogue (description) when used.

@export var dialogue: DialogueResource
@export var cue: String = "start"


func _ready() -> void:
	super()
	interacted.connect(func() -> void: DialogueRunner.start_dialogue(dialogue, cue))
