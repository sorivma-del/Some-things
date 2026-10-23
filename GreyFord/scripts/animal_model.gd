class_name AnimalModel
extends AnimatedModel
## A Quaternius animal (one glTF with its own skeleton and clips), scaled to size.

@export var scene: PackedScene
@export var model_scale: float = 1.0
## Material name -> multiplier on its colour (shared by every instance of this model file).
@export var material_tints: Dictionary[String, Color] = {}


func _ready() -> void:
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * model_scale
	# glTF animals face +Z; the rest of the game treats -Z as forward.
	model.rotation.y = PI
	add_child(model)
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_tint(model)
	play(default_animation)


## Clip playback speed, e.g. to match legs to how fast the animal really moves.
func set_speed_scale(value: float) -> void:
	_player.speed_scale = value


func _tint(model: Node) -> void:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as StandardMaterial3D
			if mat and material_tints.has(mat.resource_name) and not mat.has_meta(&"tinted"):
				mat.set_meta(&"tinted", true)
				mat.albedo_color *= material_tints[mat.resource_name]
