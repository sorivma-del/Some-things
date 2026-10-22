extends CanvasLayer
## On-screen HUD: interaction prompt. Finds the player's InteractionDetector by group.

@onready var _prompt: Label = %PromptLabel


func _ready() -> void:
	UiStyle.apply_label(_prompt, 24, 600, true, UiStyle.COLOR_TEXT)
	_prompt.modulate.a = 0.0
	var detector := get_tree().get_first_node_in_group(InteractionDetector.GROUP) as InteractionDetector
	if detector:
		detector.focus_changed.connect(_on_focus_changed)
	else:
		push_warning("HUD: no InteractionDetector in the scene")


func _on_focus_changed(prompt: String) -> void:
	if not prompt.is_empty():
		_prompt.text = "E   %s" % prompt
	create_tween().tween_property(_prompt, ^"modulate:a", 0.0 if prompt.is_empty() else 1.0, 0.2)
