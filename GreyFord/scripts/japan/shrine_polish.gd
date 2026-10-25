class_name ShrinePolish
extends Node3D
## Материалы после дождя, предметы сада и ограниченный бюджет света эпизода.

const WEATHER: Shader = preload("res://resources/japan/weathered.gdshader")
const BUCKET: PackedScene = preload("res://resources/japan/detail_assets/wooden_bucket_01/wooden_bucket_01.gltf")
const EPISODE: ShrineEpisodeConfig = preload("res://resources/japan/episode.tres")
var _materials: Dictionary[int, ShaderMaterial] = {}
var _old_fps: int = 0
var _owns_fps: bool = false
var _talk_light: OmniLight3D
var _porch_shadow: SpotLight3D


func _ready() -> void:
	name = "ShrinePolish"
	if DisplayServer.get_name() != "headless":
		_old_fps = Engine.max_fps
		Engine.max_fps = EPISODE.target_fps
		_owns_fps = true
	_wash_basin()
	_buckets_and_bench()
	_leaf_litter()
	_drifting_leaves()
	JapaneseProps._batch(self)
	for label: String in ["CourtyardArchitecture", "ShrineDetail", "ShrinePolish"]:
		_weather_surfaces(get_parent().get_node(NodePath(label)))
	_talk_light = OmniLight3D.new()
	_talk_light.name = "LanternBounce"
	_talk_light.position = Vector3(-1.5, 2.0, 1.9)
	_talk_light.light_color = Color(1, 0.83, 0.64)
	_talk_light.light_energy = 0.6
	_talk_light.omni_range = 3.8
	_talk_light.visible = false
	add_child(_talk_light)
	_porch_shadow = SpotLight3D.new()
	_porch_shadow.name = "PorchLanternShadows"
	_porch_shadow.position = Vector3(0, 3.0, 5.9)
	_porch_shadow.rotation_degrees.x = -72
	_porch_shadow.light_color = Color(1, 0.83, 0.6)
	_porch_shadow.spot_range = 7
	_porch_shadow.spot_angle = 65
	_porch_shadow.shadow_enabled = true
	_porch_shadow.shadow_blur = 2
	add_child(_porch_shadow)
	apply_lighting(bool(get_parent().get(&"evening")))


func apply_lighting(evening: bool) -> void:
	var env: Environment = get_parent().get_node(^"WorldEnvironment").get(&"environment")
	env.glow_intensity = 0.12
	env.glow_hdr_threshold = 1.6
	env.ssao_radius = 0.45
	env.ssao_intensity = 1.15
	env.ssao_light_affect = 0.15
	env.adjustment_saturation = 0.91
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.3
	_porch_shadow.light_energy = 1.3 if evening else 0
	if evening:
		env.ambient_light_energy = 0.5
		env.ambient_light_color = Color(0.62, 0.69, 0.76)
		env.fog_density = 0.006
		env.fog_light_color = Color(0.16, 0.22, 0.27)
	var sun := get_parent().get_node(^"Sun") as DirectionalLight3D
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 42
	sun.shadow_blur = 1.25
	sun.light_energy = 0.65 if evening else 1.1
	sun.light_color = Color(0.68, 0.77, 0.9) if evening else Color(1, 0.94, 0.84)
	for root: Node in [get_parent().get_node(^"CourtyardArchitecture"), get_parent().get_node(^"ShrineDetail")]:
		for node: Node in root.get_children():
			if node is OmniLight3D:
				var light := node as OmniLight3D
				light.light_color = Color(1, 0.74, 0.43)
				if light.name == &"PorchWarmLight":
					light.light_energy = 0.25
				if light.position.z < 2:
					light.light_energy = 1.35 if evening else 0.15
					light.omni_range = 6.3


func set_conversation(value: bool) -> void:
	_talk_light.visible = value


func _weather_surfaces(root: Node) -> void:
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		var source := geometry.material_override as StandardMaterial3D
		if source == null or source.albedo_texture == null:
			continue
		var path := source.albedo_texture.resource_path
		if not path.contains("gate_street") and not path.contains("rock_01_"):
			continue
		var id := source.get_instance_id()
		if not _materials.has(id):
			var mat := ShaderMaterial.new()
			mat.shader = WEATHER
			mat.set_shader_parameter(&"color_map", source.albedo_texture)
			if source.normal_texture:
				mat.set_shader_parameter(&"bump_map", source.normal_texture)
			if source.roughness_texture:
				mat.set_shader_parameter(&"rough_map", source.roughness_texture)
			mat.set_shader_parameter(&"texture_scale", source.uv1_scale.x)
			mat.set_shader_parameter(&"tint", source.albedo_color.lerp(Color(0.58, 0.56, 0.5), 0.12))
			mat.set_shader_parameter(&"bump_strength", 0.28)
			_materials[id] = mat
		geometry.material_override = _materials[id]


func _wash_basin() -> void:
	var stone := JapaneseProps._stone()
	var center := Vector3(-9.3, 0.08, 8.1)
	var basin := MeshInstance3D.new()
	basin.name = "CarvedWashBasin"
	basin.mesh = ShrineCraft.lathe(PackedVector2Array([Vector2(0.55, 0), Vector2(0.68, 0.18), Vector2(0.64, 0.65), Vector2(0.56, 0.72), Vector2(0.45, 0.65), Vector2(0.39, 0.4), Vector2(0, 0.39)]))
	basin.material_override = stone
	basin.position = center
	add_child(basin)
	Build.static_box(self, Vector3(1.3, 0.8, 1.3), center + Vector3(0, 0.35, 0))
	var water := ShaderMaterial.new()
	water.resource_name = "CourtyardWater"
	water.shader = preload("res://resources/japan/water.gdshader")
	Build.cylinder(self, 0.47, 0.01, center + Vector3(0, 0.57, 0), water, 32)
	var bamboo := StreetCottage.surface("rough_wood", Color(0.4, 0.43, 0.25), 2.0)
	for side: float in [-0.27, 0.27]:
		Build.cylinder(self, 0.027, 1.45, center + Vector3(side, 0.75, 0), bamboo, 8, Vector3(90, 0, 0))
	Build.cylinder(self, 0.018, 0.85, center + Vector3(0.14, 0.79, 0), bamboo, 8, Vector3(0, 0, 90))
	var cup := MeshInstance3D.new()
	cup.mesh = ShrineCraft.lathe(PackedVector2Array([Vector2(0.1, 0), Vector2(0.1, 0.13), Vector2(0.075, 0.13), Vector2(0.075, 0.025), Vector2(0, 0.025)]), 20)
	cup.material_override = bamboo
	cup.position = center + Vector3(-0.3, 0.78, 0)
	add_child(cup)


func _buckets_and_bench() -> void:
	var wood := StreetCottage.surface("rough_wood", Color(0.42, 0.37, 0.29), 1)
	for i: int in 3:
		var bucket := BUCKET.instantiate() as Node3D
		bucket.position = [Vector3(-8.3, 0.08, 8.1), Vector3(-7.9, 0.08, 3.1), Vector3(3.1, 0.77, 6.3)][i]
		bucket.rotation.y = i * 1.9
		bucket.name = "WeatheredBucket"
		# Импортированная модель содержит несколько поверхностей — её не склеиваем.
		bucket.set_meta(&"skip_batch", true)
		add_child(bucket)
		Build.static_box(self, Vector3(0.35, 0.35, 0.35), bucket.position + Vector3(0, 0.17, 0))
		for node: Node in bucket.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).lod_bias = 0.5
			(node as MeshInstance3D).visibility_range_end = 22
	var pos := Vector3(-8.8, 0.1, 11.0)
	for x: float in [-0.65, 0.65]:
		Build.box(self, Vector3(0.16, 0.5, 0.5), pos + Vector3(x, 0.25, 0), wood)
	for i: int in 3:
		Build.box(self, Vector3(1.7, 0.07, 0.16), pos + Vector3(0, 0.53, -0.18 + i * 0.18), wood)
	Build.static_box(self, Vector3(1.7, 0.6, 0.6), pos + Vector3(0, 0.3, 0))


func _leaf_mesh() -> ArrayMesh:
	var outline := PackedVector2Array([Vector2(0, -0.17), Vector2(0.03, -0.07), Vector2(0.11, -0.1), Vector2(0.07, 0), Vector2(0.13, 0.04), Vector2(0.04, 0.06), Vector2(0, 0.12), Vector2(-0.04, 0.06), Vector2(-0.13, 0.04), Vector2(-0.07, 0), Vector2(-0.11, -0.1), Vector2(-0.03, -0.07)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in outline.size():
		for p: Vector2 in [Vector2.ZERO, outline[i], outline[(i + 1) % outline.size()]]:
			st.add_vertex(Vector3(p.x, 0, p.y))
	st.generate_normals()
	st.index()
	return st.commit()


func _leaf_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.13, 0.035)
	mat.roughness = 0.87
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _leaf_litter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8701
	var transforms: Array[Transform3D] = []
	for i: int in 450:
		var x := rng.randf_range(-12, 12)
		var z := rng.randf_range(-11, 17)
		# Листья собираются у деревьев, а не равномерно покрывают двор.
		if absf(x) < 1.5 or (absf(x) < 5 and z > 4.2) or (x > 5.5 and x < 10.5 and z > -2.5 and z < 5):
			continue
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.3, 0.65)), Vector3(x, 0.057, z)))
	ShrineDetail._instances(self, _leaf_mesh(), _leaf_material(), transforms, "FallenMapleLeaves")


func _drifting_leaves() -> void:
	var particles := CPUParticles3D.new()
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(11, 1, 12)
	particles.direction = Vector3(0.7, -0.4, 0.3)
	particles.gravity = Vector3(0.06, -0.05, 0.025)
	particles.initial_velocity_min = 0.08
	particles.initial_velocity_max = 0.2
	particles.angular_velocity_min = -60
	particles.angular_velocity_max = 60
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.6
	particles.name = "DriftingMapleLeaves"
	particles.position.y = 5.0
	particles.amount = 28
	particles.lifetime = 12
	particles.preprocess = 6
	particles.mesh = _leaf_mesh()
	(particles.mesh as ArrayMesh).surface_set_material(0, _leaf_material())
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)


func _exit_tree() -> void:
	if _owns_fps and Engine.max_fps == EPISODE.target_fps:
		Engine.max_fps = _old_fps
