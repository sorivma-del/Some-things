class_name StreetCottage
extends Node3D
## Дом у ворот: объёмная кровля, утопленные рамы и настоящие материалы поверхности.

const WINDOW: Shader = preload("res://resources/street/window.gdshader")
const TEX := "res://resources/textures/gate_street/"
static var _materials: Dictionary[String, StandardMaterial3D] = {}
var depth: float = 4.0
var lit: bool = true


static func surface(id: String, tint: Color, scale_uv: float = 0.5) -> StandardMaterial3D:
	var key := "%s:%s:%s" % [id, tint, scale_uv]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TEX + id + "_diff.jpg") as Texture2D
	mat.normal_enabled = true
	mat.normal_texture = load(TEX + id + "_normal.jpg") as Texture2D
	mat.normal_scale = 0.65
	mat.roughness_texture = load(TEX + id + "_rough.jpg") as Texture2D
	mat.albedo_color = tint
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale_uv
	_materials[key] = mat
	return mat


func _ready() -> void:
	name = "WeatheredCottage"
	var plaster := surface("rough_plaster_03", Color(0.72, 0.69, 0.61), 0.45)
	var wood := surface("rough_wood", Color(0.45, 0.36, 0.27), 0.65)
	var slate := surface("roof_slates_02", Color(0.56, 0.58, 0.58), 0.55)
	var dark := Build.material(Color(0.055, 0.045, 0.035))
	# Стены остаются в прежнем габарите и используют прежнюю коллизию дома.
	Build.box(self, Vector3(0.25, 3.1, depth * 2), Vector3(-2.9, 1.55, 0), plaster)
	Build.box(self, Vector3(0.25, 3.1, depth * 2), Vector3(2.9, 1.55, 0), plaster)
	for side: float in [-1.0, 1.0]:
		Build.box(self, Vector3(6, 3.1, 0.2), Vector3(0, 1.55, side * depth), plaster)
		_gable(side, plaster)
		Build.box(self, Vector3(0.16, 3.6, 0.22), Vector3(0, 4.9, side * (depth + 0.04)), wood)
		for brace: float in [-1.0, 1.0]:
			var timber := Build.box(self, Vector3(3.2, 0.12, 0.2), Vector3(brace * 1.05, 4.3, side * (depth + 0.04)), wood)
			timber.rotation.z = -brace * atan2(2.4, 2.1)
		for x: float in [-2.9, -1.0, 1.0, 2.9]:
			Build.box(self, Vector3(0.17, 3.2, 0.22), Vector3(x, 1.6, side * (depth + 0.04)), wood)
		for y: float in [0.35, 2.75, 3.1]:
			Build.box(self, Vector3(6.15, 0.16, 0.24), Vector3(0, y, side * (depth + 0.04)), wood)
		for x: float in [-1.0, 1.0]:
			var beam := Build.box(self, Vector3(4.92, 0.16, 0.18), Vector3(x * 1.66, 4.9, side * (depth + 0.08)), wood)
			beam.rotation.z = -x * atan2(3.6, 3.35)
	var stone := surface("rough_plaster_03", Color(0.32, 0.33, 0.31), 1.3)
	for side: float in [-1.0, 1.0]:
		for row: int in 2:
			for block: int in 10:
				var x := -2.7 + block * 0.6 + (0.15 if row == 1 else 0.0)
				if absf(x) > 0.8:
					Build.box(self, Vector3(0.56, 0.23, 0.25), Vector3(x, 0.13 + row * 0.25, side * (depth + 0.07)), stone)
	_roof(slate)
	Build.box(self, Vector3(0.65, 1.8, 0.65), Vector3(1.6, 5.8, -depth + 1.5), plaster)
	Build.box(self, Vector3(0.82, 0.13, 0.82), Vector3(1.6, 6.75, -depth + 1.5), dark)
	for x: float in [-2.0, 2.0]:
		_window(Vector3(x, 1.75, depth + 0.14), wood, dark)
	Build.box(self, Vector3(1.3, 2.42, 0.1), Vector3(0, 1.21, depth + 0.12), dark)
	for i: int in 8:
		Build.box(self, Vector3(0.14, 2.3, 0.09), Vector3(-0.53 + i * 0.15, 1.15, depth + 0.18), wood)
	if not lit:
		var mark := Build.material(Color(0.55, 0.37, 0.23))
		for angle: float in [-32.0, 32.0]:
			Build.box(self, Vector3(0.09, 1.1, 0.03), Vector3(0, 1.2, depth + 0.27), mark, Vector3(0, 0, angle))
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.12, 0.13, 0.13)
	iron.metallic = 0.7
	iron.roughness = 0.6
	var ring := TorusMesh.new()
	ring.inner_radius = 0.045
	ring.outer_radius = 0.065
	ring.rings = 12
	ring.ring_segments = 8
	Build.mesh(self, ring, iron, Vector3(0.4, 1.2, depth + 0.28), Vector3(90, 0, 0))
	for y: float in [0.45, 1.9]:
		Build.box(self, Vector3(1.1, 0.065, 0.035), Vector3(0, y, depth + 0.25), iron)
	for x: float in [-2.8, 2.8]:
		Build.box(self, Vector3(0.2, 0.2, depth * 2 + 0.2), Vector3(x, 0.28, 0), wood)

	_batch_details()


func _gable(side: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [Vector3(-3, 3.1, side * depth), Vector3(0, 6.7, side * depth), Vector3(3, 3.1, side * depth)]
	if side < 0:
		points.reverse()
	for p: Vector3 in points:
		st.set_uv(Vector2(p.x, p.y) * 0.5)
		st.add_vertex(p)
	st.generate_normals()
	st.generate_tangents()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = mat
	add_child(mesh)


func _roof(mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var tile := BoxMesh.new()
	tile.size = Vector3(0.72, 0.045, 0.66)
	mm.mesh = tile
	var rows := ceili((depth * 2 + 1) / 0.6)
	mm.instance_count = rows * 8 * 2
	var index: int = 0
	for side: float in [-1.0, 1.0]:
		for row: int in rows:
			for col: int in 8:
				var x := side * (col + 0.5) * 3.35 / 8.0
				var y := 3.1 + 3.6 * (1.0 - absf(x) / 3.35) + sin(row * 13 + col * 7) * 0.014
				var z := -depth - 0.5 + (row + 0.5) * 0.6
				mm.set_instance_transform(index, Transform3D(Basis(Vector3.FORWARD, side * atan2(3.6, 3.35)), Vector3(x, y, z)))
				index += 1
	var roof := MultiMeshInstance3D.new()
	roof.multimesh = mm
	roof.material_override = mat
	add_child(roof)


func _window(pos: Vector3, wood: Material, dark: Material) -> void:
	Build.box(self, Vector3(1.28, 1.55, 0.13), pos, dark)
	var glass := ShaderMaterial.new()
	glass.shader = WINDOW
	glass.set_shader_parameter(&"candle", 1.0 if lit else 0.0)
	Build.box(self, Vector3(1.02, 1.28, 0.025), pos + Vector3(0, 0, 0.08), glass)
	for x: float in [-0.61, 0, 0.61]:
		Build.box(self, Vector3(0.07, 1.6, 0.16), pos + Vector3(x, 0, 0.13), wood)
	for y: float in [-0.73, 0, 0.73]:
		Build.box(self, Vector3(1.32, 0.07, 0.16), pos + Vector3(0, y, 0.13), wood)


func _batch_details() -> void:
	# Неподвижные детали с одинаковым материалом отправляются одним мешем.
	var batches: Dictionary[Material, SurfaceTool] = {}
	var originals: Array[MeshInstance3D] = []
	for child: Node in get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or not (mesh.mesh is PrimitiveMesh):
			continue
		var material := mesh.material_override if mesh.material_override else mesh.mesh.surface_get_material(0)
		if not batches.has(material):
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			batches[material] = builder
		batches[material].append_from(mesh.mesh, 0, mesh.transform)
		originals.append(mesh)
	for material: Material in batches:
		var combined := MeshInstance3D.new()
		combined.mesh = batches[material].commit()
		combined.material_override = material
		add_child(combined)
	for mesh: MeshInstance3D in originals:
		mesh.free()
