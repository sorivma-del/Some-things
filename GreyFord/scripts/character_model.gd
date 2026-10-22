class_name CharacterModel
extends Node3D
## Assembles a Quaternius modular character: a base body supplies the skeleton, outfit and
## hair parts are skinned onto it, and animations come from the Universal Animation Library.
## All parts share the same 65-bone humanoid rig, so meshes and clips transfer by bone name.

const ANIMATION_LIBRARIES: Array[PackedScene] = [
	preload("res://resources/models/characters/anim/UAL1_Standard.glb"),
	preload("res://resources/models/characters/anim/UAL2_Standard.glb"),
]

## One clip namespace shared by every character, built once from ANIMATION_LIBRARIES.
static var _shared_library: AnimationLibrary
static var _head_mesh_cache: Dictionary[ArrayMesh, ArrayMesh] = {}

@export var base_scene: PackedScene
## Outfit, hair and other parts rigged to the same skeleton.
@export var parts: Array[PackedScene] = []
## Names of MeshInstance3D nodes to hide.
@export var hidden_parts: PackedStringArray = []
## Base-body meshes cut down to the head: the kit's full bodies clip through clothing.
@export var head_only_parts: PackedStringArray = []
@export var head_bones: PackedStringArray = ["Head", "neck_01"]
@export var model_scale: float = 1.0
## Multiplied into the albedo of the model's materials (shared by all instances of a file).
@export var tint: Color = Color(0.85, 0.83, 0.8)
@export var default_animation: StringName = &"Idle"
@export var blend_time: float = 0.25

var _player: AnimationPlayer


func _ready() -> void:
	var model := base_scene.instantiate() as Node3D
	model.scale = Vector3.ONE * model_scale
	# glTF characters face +Z; the rest of the game treats -Z as forward.
	model.rotation.y = PI
	add_child(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	for part_scene: PackedScene in parts:
		_attach_part(part_scene, skeleton)
	_prepare(model)

	_player = AnimationPlayer.new()
	model.add_child(_player)
	_player.add_animation_library(&"", _get_shared_library())
	play(default_animation)


func play(animation: StringName, loop: bool = true) -> void:
	if not _player.has_animation(animation):
		push_warning("Missing animation: %s" % animation)
		return
	if _player.current_animation == animation:
		return
	_player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_player.play(animation, blend_time)


## Moves every skinned mesh of a part onto the shared skeleton.
func _attach_part(part_scene: PackedScene, skeleton: Skeleton3D) -> void:
	var part := part_scene.instantiate()
	for node: Node in part.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.get_parent().remove_child(mesh)
		mesh.owner = null
		skeleton.add_child(mesh)
		mesh.skeleton = NodePath("..")
	part.free()


static func _get_shared_library() -> AnimationLibrary:
	if _shared_library:
		return _shared_library
	_shared_library = AnimationLibrary.new()
	for scene: PackedScene in ANIMATION_LIBRARIES:
		var source := scene.instantiate()
		var player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for anim_name: StringName in player.get_animation_list():
			if not _shared_library.has_animation(anim_name):
				_shared_library.add_animation(anim_name, player.get_animation(anim_name))
		source.free()
	return _shared_library


func _prepare(node: Node) -> void:
	var mesh := node as MeshInstance3D
	if mesh:
		if hidden_parts.has(String(mesh.name)):
			mesh.visible = false
		else:
			if head_only_parts.has(String(mesh.name)):
				_strip_to_head(mesh)
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
		mat.metallic = 0.0


## Keeps only triangles whose vertices are driven mostly by head_bones.
func _strip_to_head(mesh_instance: MeshInstance3D) -> void:
	var source := mesh_instance.mesh as ArrayMesh
	if _head_mesh_cache.has(source):
		mesh_instance.mesh = _head_mesh_cache[source]
		return
	var skin := mesh_instance.skin
	var result := ArrayMesh.new()
	for surface: int in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertex_count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per_vertex := bones.size() / vertex_count
		var keep_vertex: Array[bool] = []
		keep_vertex.resize(vertex_count)
		for v: int in vertex_count:
			var best := 0
			for k: int in per_vertex:
				if weights[v * per_vertex + k] > weights[v * per_vertex + best]:
					best = k
			keep_vertex[v] = head_bones.has(String(skin.get_bind_name(bones[v * per_vertex + best])))
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for t: int in range(0, indices.size(), 3):
			if keep_vertex[indices[t]] and keep_vertex[indices[t + 1]] and keep_vertex[indices[t + 2]]:
				kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
		arrays[Mesh.ARRAY_INDEX] = kept
		# Custom channels would need their format flags re-declared; the head does not use them.
		for channel: int in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arrays[channel] = null
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		result.surface_set_material(surface, source.surface_get_material(surface))
	_head_mesh_cache[source] = result
	mesh_instance.mesh = result
