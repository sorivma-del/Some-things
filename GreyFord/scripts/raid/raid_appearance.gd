class_name RaidAppearance
extends RefCounted
## Собственные материалы и дополнительные детали на существующем скелете.

const GARMENT: Shader = preload("res://resources/raid/garment.gdshader")
static var _materials: Dictionary[String, Material] = {}


static func apply(model: CharacterModel, variant: int, hero: bool = false) -> void:
	var cloth: Color = Color(0.21, 0.24, 0.18) if hero else [Color(0.24, 0.20, 0.16), Color(0.15, 0.18, 0.19), Color(0.25, 0.23, 0.19)][variant % 3]
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var label := String(mesh.name)
		if not label.contains("Ranger") and not label.contains("Peasant"):
			continue
		var metal := label.contains("Pauldron")
		var leather := label.contains("Belt") or label.contains("Boots") or label.contains("Bracer")
		var color: Color = Color(0.32, 0.34, 0.35) if metal else Color(0.19, 0.135, 0.09) if leather else cloth
		for i: int in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(i) as StandardMaterial3D
			mesh.set_surface_override_material(i, _material(original, color, metal, leather))
		if not hero and variant > 0 and label.contains("Head_Hood"):
			mesh.hide()
	var skeleton := model.get(&"_skeleton") as Skeleton3D
	if not hero and variant > 0:
		_add_helmet(model, skeleton)
	_add_mantle(model, skeleton, cloth)


static func _material(original: StandardMaterial3D, color: Color, metal: bool, leather: bool) -> Material:
	var key := "%s:%s:%s:%s" % [original.get_instance_id() if original else 0, color, metal, leather]
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = GARMENT
	mat.set_shader_parameter("fabric_color", color)
	mat.set_shader_parameter("surface_metallic", 0.7 if metal else 0.0)
	mat.set_shader_parameter("surface_roughness", 0.5 if metal else 0.73 if leather else 0.94)
	if original:
		mat.set_shader_parameter("base_texture", original.albedo_texture)
		mat.set_shader_parameter("use_normal", original.normal_enabled and original.normal_texture != null)
		if original.normal_texture:
			mat.set_shader_parameter("normal_texture", original.normal_texture)
	_materials[key] = mat
	return mat


static func _attach(model: CharacterModel, skeleton: Skeleton3D, node: Node3D, bone: StringName, offset: Vector3) -> void:
	var index := skeleton.find_bone(bone)
	if index < 0:
		node.free()
		return
	var rest := skeleton.get_bone_global_rest(index)
	model.attach_to_bone(node, bone, rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin + offset))


static func _add_helmet(model: CharacterModel, skeleton: Skeleton3D) -> void:
	var helmet := Node3D.new()
	helmet.name = "IronHelmet"
	var steel := _material(null, Color(0.31, 0.33, 0.35), true, false)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in 6:
		for col: int in 16:
			var a := float(col) / 16.0 * TAU
			var b := float(col + 1) / 16.0 * TAU
			var low := float(row) / 6.0 * PI * 0.5
			var high := float(row + 1) / 6.0 * PI * 0.5
			var p0 := Vector3(sin(a) * cos(low) * 0.175, sin(low) * 0.22, cos(a) * cos(low) * 0.19)
			var p1 := Vector3(sin(b) * cos(low) * 0.175, sin(low) * 0.22, cos(b) * cos(low) * 0.19)
			var p2 := Vector3(sin(a) * cos(high) * 0.175, sin(high) * 0.22, cos(a) * cos(high) * 0.19)
			var p3 := Vector3(sin(b) * cos(high) * 0.175, sin(high) * 0.22, cos(b) * cos(high) * 0.19)
			for p: Vector3 in [p0, p2, p1, p1, p2, p3]:
				st.add_vertex(p)
	st.generate_normals()
	var shell := MeshInstance3D.new()
	shell.mesh = st.commit()
	shell.material_override = steel
	helmet.add_child(shell)
	Build.box(helmet, Vector3(0.035, 0.14, 0.025), Vector3(0, -0.05, 0.183), steel)
	_attach(model, skeleton, helmet, &"Head", Vector3(0, 0.09, 0))


static func _add_mantle(model: CharacterModel, skeleton: Skeleton3D, color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 20:
		var a := 0.6 + float(i) / 20.0 * (TAU - 1.2)
		var b := 0.6 + float(i + 1) / 20.0 * (TAU - 1.2)
		var p0 := Vector3(sin(a) * 0.15, 0.14, cos(a) * 0.12)
		var p1 := Vector3(sin(b) * 0.15, 0.14, cos(b) * 0.12)
		var p2 := Vector3(sin(a) * 0.29, -0.32 + sin(a * 7) * 0.018, cos(a) * 0.21)
		var p3 := Vector3(sin(b) * 0.29, -0.32 + sin(b * 7) * 0.018, cos(b) * 0.21)
		for p: Vector3 in [p0, p2, p1, p1, p2, p3]:
			st.add_vertex(p)
	st.generate_normals()
	var mantle := MeshInstance3D.new()
	mantle.name = "WornMantle"
	mantle.mesh = st.commit()
	mantle.material_override = _material(null, color * Color(0.8, 0.8, 0.8), false, false)
	_attach(model, skeleton, mantle, &"spine_03", Vector3(0, 0.03, 0))
