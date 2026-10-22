class_name CharacterModel
extends Node3D
## Wraps an imported KayKit character: hides unwanted parts (weapons, hats), mutes
## the bright pack colours to fit the dusk, and cross-fades looping animations.

@export var model_scene: PackedScene
@export var model_scale: float = 0.72
## Names of MeshInstance3D nodes inside the model to hide.
@export var hidden_parts: PackedStringArray = []
## Multiplied into the albedo of the model's materials (shared by all instances of the model).
@export var tint: Color = Color(0.8, 0.78, 0.76)
@export var default_animation: StringName = &"Idle"
@export var blend_time: float = 0.2

var _player: AnimationPlayer


func _ready() -> void:
	var model := model_scene.instantiate() as Node3D
	model.scale = Vector3.ONE * model_scale
	# KayKit models face +Z; the rest of the game treats -Z as forward.
	model.rotation.y = PI
	add_child(model)
	_prepare(model)
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	play(default_animation)


func play(animation: StringName) -> void:
	if _player == null or not _player.has_animation(animation):
		push_warning("Missing animation: %s" % animation)
		return
	if _player.current_animation == animation:
		return
	var anim := _player.get_animation(animation)
	anim.loop_mode = Animation.LOOP_LINEAR
	_player.play(animation, blend_time)


func _prepare(node: Node) -> void:
	var mesh := node as MeshInstance3D
	if mesh:
		if hidden_parts.has(String(mesh.name)):
			mesh.visible = false
		else:
			_tint_materials(mesh)
	for child: Node in node.get_children():
		_prepare(child)


## Tints the model's own (shared) materials once. Overriding with duplicated materials
## would be cleaner, but errors in the headless renderer used for checks.
func _tint_materials(mesh: MeshInstance3D) -> void:
	for i: int in mesh.get_surface_override_material_count():
		var mat := mesh.get_active_material(i) as StandardMaterial3D
		if mat == null or mat.has_meta(&"tinted"):
			continue
		mat.set_meta(&"tinted", true)
		mat.albedo_color *= tint
		mat.roughness = 1.0
		mat.metallic = 0.0
