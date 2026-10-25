class_name JapaneseProps
extends RefCounted
## Отдельный двор: собственная геометрия и проверенные фотоматериалы проекта.

const LEAF: Shader = preload("res://resources/japan/bamboo.gdshader")
static var _scanned_rocks: Array[ArrayMesh] = []


static func build(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "CourtyardArchitecture"
	parent.add_child(root)
	var wood := StreetCottage.surface("rough_wood", Color(0.62, 0.46, 0.32), 0.7)
	var red := StreetCottage.surface("rough_wood", Color(0.85, 0.25, 0.12), 0.7)
	var stone := _stone()
	var plaster := StreetCottage.surface("rough_plaster_03", Color(0.86, 0.82, 0.68), 0.7)
	var roof := StreetCottage.surface("roof_slates_02", Color(0.28, 0.32, 0.31), 0.7)
	var sand := ShaderMaterial.new()
	sand.shader = load("res://resources/japan/gravel.gdshader") as Shader
	sand.set_shader_parameter(&"grain", load("res://resources/textures/gate_street/rough_plaster_03_diff.jpg"))
	sand.set_shader_parameter(&"gravel_color", load("res://resources/japan/detail_assets/gravelly_sand/diff.jpg"))
	sand.set_shader_parameter(&"gravel_normal", load("res://resources/japan/detail_assets/gravelly_sand/normal.jpg"))
	sand.set_shader_parameter(&"mud_color", load("res://resources/textures/ground/brown_mud_03_diff.jpg"))
	wood.normal_scale = 0.15
	red.normal_scale = 0.15
	wood.metallic_specular = 0.15
	red.metallic_specular = 0.15
	Build.box(root, Vector3(28, 0.1, 34), Vector3(0, 0, 3), sand)
	Build.static_box(root, Vector3(28, 0.1, 34), Vector3(0, 0, 3))
	for side: float in [-1.0, 1.0]:
		Build.box(root, Vector3(0.35, 1.15, 34), Vector3(side * 14, 0.57, 3), plaster)
		Build.box(root, Vector3(0.55, 0.17, 34.3), Vector3(side * 14, 1.2, 3), roof)
		Build.static_box(root, Vector3(0.5, 1.4, 34), Vector3(side * 14, 0.7, 3))
	Build.box(root, Vector3(28, 1.15, 0.35), Vector3(0, 0.57, 20), plaster)
	Build.box(root, Vector3(28.3, 0.17, 0.55), Vector3(0, 1.2, 20), roof)
	Build.static_box(root, Vector3(28, 1.4, 0.5), Vector3(0, 0.7, 20))
	Build.box(root, Vector3(28, 1.15, 0.35), Vector3(0, 0.57, -14), plaster)
	Build.box(root, Vector3(28.3, 0.17, 0.55), Vector3(0, 1.2, -14), roof)
	Build.static_box(root, Vector3(28, 1.4, 0.5), Vector3(0, 0.7, -14))
	for i: int in 24:
		var z := -11.0 + i * 0.72
		var slab := MeshInstance3D.new()
		slab.mesh = ShrineCraft.paver(2.6 + sin(i * 13) * 0.15, 0.61, i + 73)
		slab.material_override = stone
		slab.position = Vector3(sin(i * 7) * 0.08, 0.06, z)
		root.add_child(slab)
		slab.rotation.y = sin(i * 5) * 0.025
	_torii(root, red, roof, stone)
	_sanctuary(root, wood, plaster, roof, stone)
	for x: float in [-4.2, 4.2]:
		for z: float in [-6.0, 1.5, 6.0]:
			_lantern(root, Vector3(x, 0.05, z), stone, roof)
	_pond(root, stone)
	_rock_gardens(root, stone)
	_bamboo(root)
	_batch(root)


static func _torii(root: Node3D, red: Material, cap: Material, stone: Material) -> void:
	var gate := Node3D.new()
	gate.name = "Torii"
	gate.position.z = -3.0
	root.add_child(gate)
	for side: float in [-1.0, 1.0]:
		Build.cylinder(gate, 0.34, 0.25, Vector3(side * 2.8, 0.17, 0), stone, 16)
		Build.cylinder(gate, 0.23, 4.0, Vector3(side * 2.7, 2.1, 0), red, 16, Vector3(0, 0, -side * 1.8))
		Build.static_box(gate, Vector3(0.55, 4.4, 0.6), Vector3(side * 2.7, 2.2, 0))
	Build.box(gate, Vector3(7.1, 0.29, 0.38), Vector3(0, 3.35, 0), red)
	Build.box(gate, Vector3(0.24, 0.75, 0.3), Vector3(0, 3.8, 0), red)
	_curve_beam(gate, 4.0, 4.13, 0.32, 0.7, 0.0, 0.3, red)
	_curve_beam(gate, 4.15, 4.42, 0.13, 0.84, 0.0, 0.3, cap)


static func _sanctuary(root: Node3D, wood: Material, plaster: Material, roof: Material, stone: Material) -> void:
	var hall := Node3D.new()
	hall.name = "Sanctuary"
	hall.position.z = 10.0
	root.add_child(hall)
	Build.box(hall, Vector3(9.1, 0.5, 8.2), Vector3(0, 0.3, 0), stone)
	Build.box(hall, Vector3(9.3, 0.18, 8.4), Vector3(0, 0.64, 0), wood)
	Build.static_box(hall, Vector3(9.3, 0.73, 8.4), Vector3(0, 0.365, 0))
	for step: int in 3:
		Build.box(hall, Vector3(5.5, 0.2, 0.55), Vector3(0, 0.13 + step * 0.2, -5.5 + step * 0.5), stone)
	Build.static_box(hall, Vector3(5.6, 0.12, 1.8), Vector3(0, 0.34, -4.9), Vector3(-22, 0, 0))
	Build.box(hall, Vector3(7.5, 2.7, 4.9), Vector3(0, 2.05, 0.8), plaster)
	var wall := Build.static_box(hall, Vector3(7.5, 2.7, 4.9), Vector3(0, 2.05, 0.8))
	wall.name = "SanctuaryWalls"
	for x: float in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		Build.box(hall, Vector3(0.17, 2.8, 0.2), Vector3(x, 2.08, -3.5), wood)
		Build.box(hall, Vector3(0.22, 0.19, 7.4), Vector3(x, 3.35, 0), wood)
	Build.box(hall, Vector3(8.5, 0.25, 0.3), Vector3(0, 3.42, -3.55), wood)
	var paper := ShaderMaterial.new()
	paper.shader = load("res://resources/japan/paper.gdshader") as Shader
	root.set_meta(&"paper", paper)
	for panel: int in 6:
		var x := -3.15 + panel * 1.26
		Build.box(hall, Vector3(1.18, 2.25, 0.08), Vector3(x, 1.93, -1.69), paper)
		for row: int in 7:
			Build.box(hall, Vector3(1.2, 0.025, 0.06), Vector3(x, 0.85 + row * 0.36, -1.76), wood)
		for col: int in 4:
			Build.box(hall, Vector3(0.025, 2.3, 0.06), Vector3(x - 0.59 + col * 0.39, 1.94, -1.76), wood)
	for z: float in [-4.25, 4.25]:
		_curve_beam(hall, 5.05, 3.3, 0.16, 0.22, z, -0.3, wood)
	for side: float in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in 24:
			var x0 := -5.05 + i * 10.1 / 24.0
			var x1 := -5.05 + (i + 1) * 10.1 / 24.0
			var y0 := _roof_y(absf(x0) / 5.05) - 0.1
			var y1 := _roof_y(absf(x1) / 5.05) - 0.1
			_quad(st, [Vector3(x0, 3.35, side * 4.22), Vector3(x1, 3.35, side * 4.22), Vector3(x1, y1, side * 4.22), Vector3(x0, y0, side * 4.22)], side > 0)
		st.generate_normals()
		st.generate_tangents()
		st.index()
		var gable := MeshInstance3D.new()
		gable.mesh = st.commit()
		gable.material_override = wood
		hall.add_child(gable)
	_roof(hall, roof, wood)
	for side: float in [-1.0, 1.0]:
		Build.box(hall, Vector3(0.12, 0.1, 7.9), Vector3(side * 4.4, 1.5, 0.1), wood)
		for z: float in [-3.6, -1.8, 0, 1.8, 3.6]:
			Build.box(hall, Vector3(0.1, 0.8, 0.1), Vector3(side * 4.4, 1.1, z), wood)


static func _roof(hall: Node3D, mat: Material, underside: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := SurfaceTool.new()
	inner.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		for col: int in 20:
			var t0 := col / 20.0
			var t1 := (col + 1) / 20.0
			var x0 := side * t0 * 5.05
			var x1 := side * t1 * 5.05
			var y0 := _roof_y(t0)
			var y1 := _roof_y(t1)
			var points: Array[Vector3] = [Vector3(x0, y0, -4.35), Vector3(x0, y0, 4.35), Vector3(x1, y1, 4.35), Vector3(x1, y1, -4.35)]
			_quad(st, points, side > 0.0)
			_quad(inner, points, side < 0.0)
	st.generate_normals()
	st.generate_tangents()
	st.index()
	var surface := MeshInstance3D.new()
	surface.mesh = st.commit()
	surface.material_override = mat
	hall.add_child(surface)
	inner.generate_normals()
	inner.generate_tangents()
	inner.index()
	var ceiling := MeshInstance3D.new()
	ceiling.mesh = inner.commit()
	ceiling.material_override = underside
	hall.add_child(ceiling)
	for i: int in 25:
		var x := -5.0 + i * 10.0 / 24.0
		Build.cylinder(hall, 0.055, 8.85, Vector3(x, _roof_y(absf(x) / 5.05) + 0.025, 0), mat, 8, Vector3(90, 0, 0))
	Build.cylinder(hall, 0.16, 9.4, Vector3(0, 6.44, 0), mat, 12, Vector3(90, 0, 0))


static func _roof_y(t: float) -> float:
	return 3.3 + 3.1 * (1.0 - t) + 0.8 * pow(t, 5.0)


static func _curve_beam(parent: Node3D, half: float, y: float, height: float, depth: float, z: float, curve: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 24:
		var x0 := -half + i * half / 12.0
		var x1 := -half + (i + 1) * half / 12.0
		var y0 := y + curve * pow(absf(x0) / half, 3.0)
		var y1 := y + curve * pow(absf(x1) / half, 3.0)
		if curve < 0.0:
			y0 = _roof_y(absf(x0) / half) - height
			y1 = _roof_y(absf(x1) / half) - height
		for side: float in [-1.0, 1.0]:
			_quad(st, [Vector3(x0, y0, z + side * depth * 0.5), Vector3(x1, y1, z + side * depth * 0.5), Vector3(x1, y1 + height, z + side * depth * 0.5), Vector3(x0, y0 + height, z + side * depth * 0.5)], side > 0)
		_quad(st, [Vector3(x0, y0 + height, z - depth * 0.5), Vector3(x1, y1 + height, z - depth * 0.5), Vector3(x1, y1 + height, z + depth * 0.5), Vector3(x0, y0 + height, z + depth * 0.5)], false)
	for side: float in [-1.0, 1.0]:
		var x := side * half
		var end_y := y + curve
		if curve < 0.0:
			end_y = _roof_y(1.0) - height
		_quad(st, [Vector3(x, end_y, z - depth * 0.5), Vector3(x, end_y, z + depth * 0.5), Vector3(x, end_y + height, z + depth * 0.5), Vector3(x, end_y + height, z - depth * 0.5)], side < 0)
	st.generate_normals()
	st.generate_tangents()
	st.index()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = mat
	parent.add_child(mesh)


static func _quad(st: SurfaceTool, points: Array[Vector3], reverse: bool) -> void:
	var order := PackedInt32Array([0, 1, 2, 0, 2, 3])
	if reverse:
		order = PackedInt32Array([0, 2, 1, 0, 3, 2])
	for i: int in order:
		var p := points[i]
		st.set_uv(Vector2(p.x + p.z, p.y + p.z) * 0.5)
		st.add_vertex(p)


static func _lantern(root: Node3D, pos: Vector3, stone: Material, roof: Material) -> void:
	Build.box(root, Vector3(0.8, 0.15, 0.8), pos + Vector3(0, 0.07, 0), stone)
	Build.cylinder(root, 0.17, 0.6, pos + Vector3(0, 0.45, 0), stone, 8)
	Build.box(root, Vector3(0.58, 0.12, 0.58), pos + Vector3(0, 0.8, 0), stone)
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(0.3, 0.17, 0.06)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.53, 0.16)
	flame.emission_energy_multiplier = 0.8
	Build.box(root, Vector3(0.33, 0.3, 0.33), pos + Vector3(0, 1.02, 0), flame)
	for x: float in [-0.23, 0.23]:
		for z: float in [-0.23, 0.23]:
			Build.box(root, Vector3(0.085, 0.35, 0.085), pos + Vector3(x, 1.02, z), stone)
	Build.prism(root, Vector3(0.9, 0.23, 0.9), pos + Vector3(0, 1.31, 0), roof)
	Build.cylinder(root, 0.09, 0.12, pos + Vector3(0, 1.48, 0), stone, 8)
	Build.static_box(root, Vector3(0.75, 1.4, 0.75), pos + Vector3(0, 0.7, 0))
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 1.1, 0)
	light.light_color = Color(1.0, 0.59, 0.27)
	light.light_energy = 0.65
	light.omni_range = 3.0
	light.shadow_enabled = false
	root.add_child(light)


static func _pond(root: Node3D, stone: Material) -> void:
	Build.box(root, Vector3(4.5, 0.14, 6.5), Vector3(8, 0.12, 1.2), stone)
	var water := ShaderMaterial.new()
	water.resource_name = "CourtyardWater"
	water.shader = load("res://resources/japan/water.gdshader") as Shader
	var surface := Build.box(root, Vector3(4, 0.02, 6), Vector3(8, 0.2, 1.2), water)
	surface.name = "ReflectingPool"
	root.set_meta(&"water", surface)
	for side: float in [-1.0, 1.0]:
		Build.box(root, Vector3(0.25, 0.25, 6.5), Vector3(8 + side * 2.2, 0.22, 1.2), stone)
		Build.box(root, Vector3(4.5, 0.25, 0.25), Vector3(8, 0.22, 1.2 + side * 3.2), stone)
	Build.static_box(root, Vector3(4.6, 0.45, 6.6), Vector3(8, 0.2, 1.2))


static func _bamboo(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7241
	var stalk := StreetCottage.surface("rough_wood", Color(0.33, 0.47, 0.20), 1.0)
	stalk.normal_scale = 0.15
	stalk.metallic_specular = 0.15
	var nodes := StandardMaterial3D.new()
	nodes.albedo_color = Color(0.23, 0.3, 0.12)
	nodes.roughness = 1.0
	var leaf := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, [Vector3.ZERO, Vector3(0.45, 0.05, -0.13), Vector3(1.1, 0.1, 0), Vector3(0.45, 0.05, 0.13)], false)
	st.generate_normals()
	leaf = st.commit()
	var leaves := MultiMesh.new()
	leaves.transform_format = MultiMesh.TRANSFORM_3D
	leaves.mesh = leaf
	leaves.instance_count = 10800
	var index: int = 0
	for side: float in [-1.0, 1.0]:
		for i: int in 60:
			var x := side * rng.randf_range(14.8, 23.0)
			var z := rng.randf_range(-14, 24)
			if i < 20:
				x = rng.randf_range(-14, 14)
				z = rng.randf_range(20.8, 25)
			var height := rng.randf_range(5.0, 8.0)
			Build.cylinder(root, rng.randf_range(0.055, 0.09), height, Vector3(x, height * 0.5, z), stalk, 7)
			for ring: int in 5:
				Build.cylinder(root, 0.095, 0.035, Vector3(x, height * (0.15 + ring * 0.15), z), nodes, 7)
			for j: int in 6:
				var pos := Vector3(x, height * (0.5 + j * 0.075), z)
				var angle := rng.randf_range(0, TAU)
				for leaflet: int in 15:
					var offset := Vector3(leaflet * 0.14, leaflet * 0.035, 0).rotated(Vector3.UP, angle)
					var basis := (Basis(Vector3.UP, angle + (-0.65 if leaflet % 2 == 0 else 0.65)) * Basis(Vector3.RIGHT, rng.randf_range(-0.8, 0.8)) * Basis(Vector3.FORWARD, rng.randf_range(-0.5, 0.5))).scaled(Vector3.ONE * rng.randf_range(0.55, 0.9))
					leaves.set_instance_transform(index, Transform3D(basis, pos + offset))
					index += 1
	var foliage := MultiMeshInstance3D.new()
	foliage.multimesh = leaves
	var material := ShaderMaterial.new()
	material.shader = LEAF
	foliage.material_override = material
	foliage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(foliage)


static func _batch(root: Node3D) -> void:
	var batches: Dictionary[Material, SurfaceTool] = {}
	var rocks: Dictionary[Mesh, Array] = {}
	var originals: Array[MeshInstance3D] = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var ancestor: Node = mesh.get_parent()
		var skip: bool = false
		while ancestor != root and ancestor != null:
			if ancestor.has_meta(&"skip_batch"):
				skip = true
				break
			ancestor = ancestor.get_parent()
		if skip or mesh.mesh.get_surface_count() != 1:
			continue
		if mesh.mesh.has_meta(&"scanned_rock"):
			if not rocks.has(mesh.mesh):
				rocks[mesh.mesh] = []
			rocks[mesh.mesh].append(_relative_transform(mesh, root))
			originals.append(mesh)
			continue
		var arrays := mesh.mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			continue
		var material := mesh.material_override if mesh.material_override else mesh.mesh.surface_get_material(0)
		if material.resource_name == "CourtyardWater":
			continue
		if not batches.has(material):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			batches[material] = st
		batches[material].append_from(mesh.mesh, 0, _relative_transform(mesh, root))
		originals.append(mesh)
	for material: Material in batches:
		var combined := MeshInstance3D.new()
		combined.mesh = batches[material].commit()
		combined.material_override = material
		root.add_child(combined)
	for template: Mesh in rocks:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = template
		mm.instance_count = rocks[template].size()
		for i: int in mm.instance_count:
			mm.set_instance_transform(i, rocks[template][i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "ScannedMossRocks"
		instance.multimesh = mm
		instance.lod_bias = 0.35
		instance.visibility_range_end = 65
		root.add_child(instance)
	for mesh: MeshInstance3D in originals:
		mesh.free()


static func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var result := node.transform
	var parent: Node = node.get_parent()
	while parent != root and parent != null:
		if parent is Node3D:
			result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result


static func _stone() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://resources/japan/rock_01_diff.jpg") as Texture2D
	mat.normal_enabled = true
	mat.normal_texture = load("res://resources/japan/rock_01_normal.jpg") as Texture2D
	mat.normal_scale = 0.25
	mat.roughness_texture = load("res://resources/japan/rock_01_rough.jpg") as Texture2D
	mat.roughness = 0.95
	mat.metallic_specular = 0.12
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.7
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


static func _rock_gardens(root: Node3D, stone: Material) -> void:
	var moss := StandardMaterial3D.new()
	moss.albedo_texture = load("res://resources/textures/ground/sparse_grass_diff.jpg") as Texture2D
	moss.albedo_color = Color(0.5, 0.58, 0.32)
	moss.roughness = 1.0
	moss.metallic_specular = 0.1
	moss.uv1_triplanar = true
	moss.uv1_world_triplanar = true
	for center: Vector3 in [Vector3(-8, 0, -0.5), Vector3(-8.5, 0, 7), Vector3(8.5, 0, 10.5)]:
		Build.cylinder(root, 1.9, 0.025, center + Vector3(0, 0.06, 0), moss, 18)
		for i: int in 3:
			var rock := boulder_mesh(i + int(center.x) * 13)
			var pos := center + Vector3(-0.9 + i * 0.8, 0.18, sin(i * 5) * 0.5)
			var mesh := MeshInstance3D.new()
			mesh.mesh = rock
			mesh.position = pos
			root.add_child(mesh)
			mesh.scale = Vector3(1.3, 0.6 + i * 0.35, 1.0)
			mesh.rotation.y = i * 1.4
			Build.static_box(root, Vector3(1.0, 0.7, 0.85), pos + Vector3(0, 0.1, 0))


static func boulder_mesh(seed_value: int) -> ArrayMesh:
	if _scanned_rocks.is_empty():
		var packed := load("res://resources/japan/detail_assets/rock_moss_set_01/garden_rocks.gltf") as PackedScene
		var source := packed.instantiate() as Node3D
		for node: Node in source.find_children("*", "MeshInstance3D", true, false):
			var mesh := (node as MeshInstance3D).mesh as ArrayMesh
			mesh.set_meta(&"scanned_rock", true)
			_scanned_rocks.append(mesh)
		source.free()
	return _scanned_rocks[posmod(seed_value, _scanned_rocks.size())]
