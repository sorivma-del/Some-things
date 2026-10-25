class_name ShrineDetail
extends RefCounted
## Детали святилища и леса: общие материалы, группировка статики и отсечение дальних мешей.

const FIR: PackedScene = preload("res://resources/models/gate_street/fir/fir_street.gltf")
const FERN: PackedScene = preload("res://resources/japan/fern/fern.gltf")


static func build(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ShrineDetail"
	parent.add_child(root)
	var wood := StreetCottage.surface("rough_wood", Color(0.48, 0.34, 0.21), 0.8)
	wood.normal_scale = 0.2
	wood.metallic_specular = 0.15
	var roof := StreetCottage.surface("roof_slates_02", Color(0.33, 0.37, 0.36), 0.7)
	roof.normal_scale = 0.25
	var stone := JapaneseProps._stone()
	_roof_tiles(root, roof)
	_joinery(root, wood)
	_rope(root, wood)
	_garden(root, stone, wood)
	_paper_lanterns(root, wood)
	JapaneseProps._batch(root)
	_forest(root)
	_ferns(root)
	_maple(root, Vector3(-8, 0, 1.5), wood)
	_maple(root, Vector3(10.5, 0, 13), wood)
	for child: Node in parent.get_children():
		if child == root or child.name == &"CourtyardArchitecture" or child.is_in_group(&"terrain"):
			for geometry: Node in child.find_children("*", "GeometryInstance3D", true, false):
				(geometry as GeometryInstance3D).layers = 5
	var architecture := parent.get_node(^"CourtyardArchitecture")
	var water := architecture.get_meta(&"water") as MeshInstance3D
	water.layers = 1
	var probe := ReflectionProbe.new()
	probe.name = "PoolReflection"
	probe.position = Vector3(8, 2.5, 1.2)
	probe.size = Vector3(12, 7, 14)
	probe.cull_mask = 4
	probe.max_distance = 38.0
	probe.box_projection = true
	probe.enable_shadows = false
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	root.add_child(probe)


static func _roof_tiles(root: Node3D, mat: Material) -> void:
	var tile := BoxMesh.new()
	tile.size = Vector3(0.57, 0.035, 0.57)
	var transforms: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		for col: int in 12:
			var t := (col + 0.5) / 12.0
			var x := side * t * 5.05
			var angle := atan(side * (-3.1 + 4.0 * pow(t, 4.0)) / 5.05)
			for row: int in 17:
				var z := 5.65 + row * 0.52
				transforms.append(Transform3D(Basis(Vector3.BACK, angle), Vector3(x, JapaneseProps._roof_y(t) + 0.035, z)))
	_instances(root, tile, mat, transforms, "IndividualRoofTiles")
	for side: float in [-1.0, 1.0]:
		for col: int in 25:
			var x := -5.0 + col * 10.0 / 24.0
			Build.cylinder(root, 0.075, 0.08, Vector3(x, JapaneseProps._roof_y(absf(x) / 5.05) + 0.03, 10 + side * 4.47), mat, 10, Vector3(90, 0, 0))


static func _joinery(root: Node3D, wood: Material) -> void:
	for x: float in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		for level: int in 3:
			Build.box(root, Vector3(0.35 + level * 0.2, 0.11, 0.3 + level * 0.2), Vector3(x, 3.03 + level * 0.13, 6.45), wood)
	for side: float in [-1.0, 1.0]:
		var z := 10 + side * 4.24
		_beam(root, Vector3(0, 3.42, z), Vector3(0, 6.2, z), 0.15, wood)
		_beam(root, Vector3(-3.65, 3.45, z), Vector3(0, 6.3, z), 0.13, wood)
		_beam(root, Vector3(3.65, 3.45, z), Vector3(0, 6.3, z), 0.13, wood)
		Build.box(root, Vector3(7.5, 0.12, 0.16), Vector3(0, 3.55, z), wood)
	var plank := BoxMesh.new()
	plank.size = Vector3(0.43, 0.035, 8.3)
	var transforms: Array[Transform3D] = []
	for i: int in 21:
		transforms.append(Transform3D(Basis.IDENTITY, Vector3(-4.45 + i * 0.445, 0.748, 10)))
	_instances(root, plank, wood, transforms, "VerandaPlanks")
	for panel: int in 6:
		Build.box(root, Vector3(1.18, 0.35, 0.1), Vector3(-3.15 + panel * 1.26, 1.0, 8.20), wood)
	# Ящик для подношений оставляет центральный проход свободным.
	Build.box(root, Vector3(1.5, 0.55, 0.65), Vector3(2.2, 1.04, 7.15), wood)
	for i: int in 10:
		Build.box(root, Vector3(0.09, 0.06, 0.72), Vector3(1.55 + i * 0.145, 1.35, 7.15), wood)
	Build.static_box(root, Vector3(1.5, 0.65, 0.7), Vector3(2.2, 1.05, 7.15))


static func _rope(root: Node3D, wood: Material) -> void:
	var hemp := StreetCottage.surface("rough_wood", Color(0.72, 0.6, 0.35), 4.0)
	hemp.normal_scale = 0.1
	for i: int in 18:
		var x0 := -2.55 + i * 5.1 / 18.0
		var x1 := -2.55 + (i + 1) * 5.1 / 18.0
		var a := Vector3(x0, 3.25 - 0.25 * (1.0 - pow(x0 / 2.55, 2.0)), -3.15)
		var b := Vector3(x1, 3.25 - 0.25 * (1.0 - pow(x1 / 2.55, 2.0)), -3.15)
		var rope := Build.cylinder(root, 0.055, a.distance_to(b), (a + b) * 0.5, hemp, 9)
		rope.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.73, 0.7, 0.57)
	paper.roughness = 1.0
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	for x: float in [-1.8, -0.6, 0.6, 1.8]:
		for i: int in 3:
			var strip := Build.box(root, Vector3(0.12, 0.18, 0.012), Vector3(x + (0.05 if i % 2 == 0 else 0.0), 2.88 - i * 0.13, -3.18), paper)
			strip.rotation.z = 0.6 if i % 2 == 0 else -0.6


static func _garden(root: Node3D, stone: Material, wood: Material) -> void:
	var moss := StandardMaterial3D.new()
	moss.albedo_texture = load("res://resources/textures/ground/sparse_grass_diff.jpg") as Texture2D
	moss.albedo_color = Color(0.4, 0.48, 0.26)
	moss.roughness = 1.0
	moss.metallic_specular = 0.1
	moss.uv1_world_triplanar = true
	moss.uv1_triplanar = true
	for side: float in [-1.0, 1.0]:
		for i: int in 6:
			var bed := Build.cylinder(root, 1.0, 0.02, Vector3(side * 11.0, 0.065, -9.5 + i * 5.0), moss, 24)
			bed.scale = Vector3(3.0, 1.0, 4.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7913
	for side: float in [-1.0, 1.0]:
		for i: int in 13:
			var mesh := MeshInstance3D.new()
			mesh.mesh = JapaneseProps.boulder_mesh(i + int(side) * 71)
			mesh.material_override = stone
			mesh.position = Vector3(side * rng.randf_range(10.5, 13.3), rng.randf_range(-0.1, 0.1), -9 + i * 2.1)
			mesh.scale = Vector3(rng.randf_range(0.8, 2.2), rng.randf_range(0.5, 1.3), rng.randf_range(0.7, 1.7))
			mesh.rotation.y = rng.randf_range(0, TAU)
			root.add_child(mesh)
			Build.static_box(root, Vector3(0.9 * mesh.scale.x, 0.7 * mesh.scale.y, 0.9 * mesh.scale.z), mesh.position + Vector3(0, 0.15, 0))
	# Неровный край пруда скрывает прямую границу чаши.
	for i: int in 20:
		var angle := i * TAU / 20.0
		var mesh := MeshInstance3D.new()
		mesh.mesh = JapaneseProps.boulder_mesh(i + 301)
		mesh.material_override = stone
		mesh.position = Vector3(8 + cos(angle) * 2.23, 0.12, 1.2 + sin(angle) * 3.23)
		mesh.scale = Vector3(0.6, 0.35, 0.6)
		root.add_child(mesh)
	for side: float in [-1.0, 1.0]:
		for i: int in 18:
			var post := Vector3(side * (13.4 + sin(i * 7) * 0.15), 0.1, -10 + i * 1.6)
			Build.cylinder(root, 0.055, 1.5, post + Vector3(0, 0.75, 0), wood, 7)
			if i > 0:
				for y: float in [0.55, 0.95]:
					_beam(root, post + Vector3(0, y, -1.6), post + Vector3(0, y, 0), 0.055, wood)


static func _paper_lanterns(root: Node3D, wood: Material) -> void:
	var paper := ShaderMaterial.new()
	paper.shader = load("res://resources/japan/paper.gdshader") as Shader
	paper.set_shader_parameter(&"warmth", 0.18)
	for x: float in [-3.0, -1.0, 1.0, 3.0]:
		Build.cylinder(root, 0.012, 0.35, Vector3(x, 3.1, 6.0), wood, 6)
		var lantern := SphereMesh.new()
		lantern.radius = 0.23
		lantern.height = 0.55
		lantern.radial_segments = 20
		lantern.rings = 12
		Build.mesh(root, lantern, paper, Vector3(x, 2.7, 6.0))
		for y: float in [2.45, 2.96]:
			Build.cylinder(root, 0.12, 0.04, Vector3(x, y, 6.0), wood, 12)
		for i: int in 7:
			var t := i / 6.0
			var radius := 0.23 * sqrt(maxf(0, 1.0 - pow((t - 0.5) * 1.9, 2.0)))
			var hoop := TorusMesh.new()
			hoop.inner_radius = maxf(0.02, radius - 0.009)
			hoop.outer_radius = radius
			hoop.rings = 20
			hoop.ring_segments = 4
			Build.mesh(root, hoop, wood, Vector3(x, 2.45 + t * 0.5, 6.0))
		var light := OmniLight3D.new()
		light.position = Vector3(x, 2.5, 6)
		light.light_color = Color(1.0, 0.55, 0.22)
		light.light_energy = 0.35
		light.omni_range = 2.0
		root.add_child(light)
	var fill := OmniLight3D.new()
	fill.name = "PorchWarmLight"
	fill.position = Vector3(0, 2.8, 7.0)
	fill.light_color = Color(1.0, 0.62, 0.31)
	fill.light_energy = 0.85
	fill.omni_range = 4.5
	root.add_child(fill)


static func _forest(root: Node3D) -> void:
	var spots: Array[Vector3] = [Vector3(-16, 0, -4), Vector3(17, 0, -1), Vector3(-11, 0, 25), Vector3(12, 0, 26), Vector3(-2, 0, 29), Vector3(23, 0, 18)]
	for i: int in spots.size():
		var tree := FIR.instantiate() as Node3D
		tree.position = spots[i]
		tree.scale = Vector3.ONE * (1.5 + i * 0.12)
		root.add_child(tree)
		for node: Node in tree.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			mesh.lod_bias = 0.025
			mesh.visibility_range_end = 85.0
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface: int in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
				if material and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					var opaque := material.duplicate() as StandardMaterial3D
					opaque.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					mesh.set_surface_override_material(surface, opaque)


static func _ferns(root: Node3D) -> void:
	var original := FERN.instantiate() as Node3D
	var templates: Array[Mesh] = []
	for node: Node in original.find_children("*", "MeshInstance3D", true, false):
		templates.append((node as MeshInstance3D).mesh)
	original.free()
	var material := ShaderMaterial.new()
	material.shader = load("res://resources/japan/fern.gdshader") as Shader
	material.set_shader_parameter(&"diffuse_map", load("res://resources/japan/fern/textures/fern_02_diff_1k.jpg"))
	material.set_shader_parameter(&"normal_map", load("res://resources/japan/fern/textures/fern_02_nor_gl_1k.jpg"))
	material.set_shader_parameter(&"alpha_map", load("res://resources/japan/fern/textures/fern_alpha_1k.jpg"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3187
	for variant: int in templates.size():
		var transforms: Array[Transform3D] = []
		for i: int in 22:
			var x := rng.randf_range(6.0, 13.3) * (-1 if i % 2 == 0 else 1)
			var z := rng.randf_range(-10.0, 17.0)
			# Обход пруда остаётся свободным.
			if x > 5.5 and z > -2.2 and z < 4.8:
				x = rng.randf_range(11.5, 13.3)
			var scale_value := rng.randf_range(0.55, 1.15)
			transforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * scale_value), Vector3(x, 0.075, z)))
		_instances(root, templates[variant], material, transforms, "FernClumps")


static func _instances(parent: Node3D, mesh: Mesh, mat: Material, transforms: Array[Transform3D], label: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i: int in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = mm
	instance.material_override = mat
	if label == "FernClumps":
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


static func _beam(parent: Node3D, start: Vector3, end: Vector3, width: float, mat: Material) -> void:
	var direction := end - start
	var mesh := Build.box(parent, Vector3(width, direction.length(), width), (start + end) * 0.5, mat)
	mesh.quaternion = Quaternion(Vector3.UP, direction.normalized())


static func _maple(root: Node3D, center: Vector3, wood: Material) -> void:
	var trunk := Build.cylinder(root, 0.18, 3.4, center + Vector3(0, 1.7, 0), wood, 12)
	trunk.rotation.z = 0.08
	Build.static_box(root, Vector3(0.5, 3.2, 0.5), center + Vector3(0, 1.6, 0))
	var branches: Array[Vector3] = [Vector3(-1.7, 4.8, -0.3), Vector3(-0.5, 5.6, 1.0), Vector3(1.5, 5.0, 0.3), Vector3(0.6, 4.5, -1.6)]
	for point: Vector3 in branches:
		_beam(root, center + Vector3(0, 2.5, 0), center + point, 0.11, wood)
	var outline := PackedVector2Array([Vector2(0, -0.25), Vector2(0.045, -0.12), Vector2(0.16, -0.18), Vector2(0.1, -0.02), Vector2(0.19, 0.04), Vector2(0.06, 0.08), Vector2(0, 0.15), Vector2(-0.06, 0.08), Vector2(-0.19, 0.04), Vector2(-0.1, -0.02), Vector2(-0.16, -0.18), Vector2(-0.045, -0.12)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in outline.size():
		for point: Vector2 in [Vector2.ZERO, outline[i], outline[(i + 1) % outline.size()]]:
			st.set_uv(point * 2.0 + Vector2.ONE * 0.5)
			st.add_vertex(Vector3(point.x, 0, point.y))
	st.generate_normals()
	st.index()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = st.commit()
	mm.instance_count = 3200
	var rng := RandomNumberGenerator.new()
	rng.seed = 941 + int(center.x) * 37
	for i: int in mm.instance_count:
		var branch := branches[i % branches.size()]
		var offset := Vector3(rng.randf_range(-2.1, 2.1), rng.randf_range(-0.7, 0.7), rng.randf_range(-1.7, 1.7))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0, TAU), rng.randf_range(-0.7, 0.7)))
		mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.65, 1.2)), center + branch + offset))
		mm.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 1))
	var material := ShaderMaterial.new()
	material.shader = load("res://resources/japan/maple.gdshader") as Shader
	var leaves := MultiMeshInstance3D.new()
	leaves.name = "MapleCanopy"
	leaves.multimesh = mm
	leaves.material_override = material
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(leaves)
