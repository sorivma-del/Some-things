class_name AnimalModel
extends AnimatedModel
## A Quaternius animal (one glTF with its own skeleton and clips), scaled to size.

@export var scene: PackedScene
@export var model_scale: float = 1.0


func _ready() -> void:
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * model_scale
	# glTF animals face +Z; the rest of the game treats -Z as forward.
	model.rotation.y = PI
	add_child(model)
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	play(default_animation)
