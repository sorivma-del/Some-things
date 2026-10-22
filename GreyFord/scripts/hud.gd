extends CanvasLayer
## On-screen HUD: interaction prompt. Finds the player's InteractionDetector by group.

@onready var _prompt_panel: PanelContainer = %PromptPanel
@onready var _prompt_label: Label = %PromptLabel


func _ready() -> void:
	_prompt_panel.hide()
	var detector := get_tree().get_first_node_in_group(InteractionDetector.GROUP) as InteractionDetector
	if detector:
		detector.focus_changed.connect(_on_focus_changed)
	else:
		push_warning("HUD: no InteractionDetector in the scene")


func _on_focus_changed(prompt: String) -> void:
	_prompt_panel.visible = not prompt.is_empty()
	_prompt_label.text = "[E]  %s" % prompt
