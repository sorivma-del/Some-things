class_name MillDressing
extends Node3D
## Двор мельницы: свободные тропы, куртины растений и следы повседневной работы.

const CONFIG: WorldConfig = preload("res://resources/world/world_config.tres")
const WIND: Shader = preload("res://resources/foliage_wind.gdshader")
const NATURE := "res://resources/models/nature/"
const PROPS := "res://resources/models/props/"

var terrain: WorldTerrain
var _rng := RandomNumberGenerator.new()
var _placements: Dictionary[String, Array] = {}


func _ready() -> void:
	name = "MillDressing"
	add_to_group(&"mill_dressing")
	_rng.seed = 2047
	_scatter()
	_frame_trees()
	_build_batches()
	_workyard()
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _scatter() -> void:
	var patch := FastNoiseLite.new()
	patch.seed = 4091
	patch.frequency = 0.22
	var spacing := maxf(0.5, CONFIG.foliage_spacing)
	var radius := CONFIG.yard_radius
	var z := -radius
	while z < radius:
		var x := -radius
		while x < radius:
			var p := Vector2(x, z) + Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))
			x += spacing
			if p.length() > radius or not is_planting_spot(p):
				continue
			var density := CONFIG.foliage_density * smoothstep(-0.03, 0.2, patch.get_noise_2d(p.x, p.y))
			if _rng.randf() > density:
				continue
			var roll := _rng.randf()
			var model := "Grass_Common_Short" if roll < 0.55 else "Grass_Wispy_Short"
			var size := _rng.randf_range(0.24, 0.42)
			if roll > 0.86:
				model = "Fern_1"
				size = _rng.randf_range(0.3, 0.55)
			_put(model, p, Vector3.ONE * size, _rng.randf() * TAU)
		z += spacing


## В координатах двора: трава не занимает дом, костёр, торговое место и подход к двери.
func is_planting_spot(p: Vector2) -> bool:
	var world := CONFIG.yard_center + p
	if p.length() < 5.0 or terrain.road_distance(world.x, world.y) < 3.2:
		return false
	if Rect2(-14, -15, 15, 16).has_point(p) or p.distance_to(Vector2(6, -4)) < 3.0:
		return false
	var nearest := Geometry2D.get_closest_point_to_segment(p, CONFIG.yard_door - CONFIG.yard_center, Vector2(7, 7))
	return p.distance_to(nearest) > 2.0


func _frame_trees() -> void:
	for p: Vector2 in [Vector2(-18, -15), Vector2(-12, -22), Vector2(-3, -23), Vector2(8, -21), Vector2(20, -13), Vector2(-24, 3)]:
		_put("Pine_%d" % _rng.randi_range(1, 3), p, Vector3.ONE * _rng.randf_range(1.1, 1.5), _rng.randf() * TAU)
		var local := _on_ground(p)
		Build.static_cylinder(self, 0.4, 3.0, local + Vector3(0, 1.5, 0))


func _put(model: String, p: Vector2, size: Vector3, angle: float) -> void:
	if not _placements.has(model):
		_placements[model] = []
	(_placements[model] as Array).append(Transform3D(Basis(Vector3.UP, angle).scaled(size), _on_ground(p)))


func _on_ground(p: Vector2) -> Vector3:
	var world := CONFIG.yard_center + p
	return Vector3(p.x, terrain.height_at(world.x, world.y) - position.y, p.y)


func _build_batches() -> void:
	for model: String in _placements:
		var tree := model.begins_with("Pine")
		var scene := KitBuilder.instance_of(NATURE + model + ".gltf")
		var source := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var mesh := source.mesh.duplicate() as ArrayMesh
		if not tree:
			for surface: int in mesh.get_surface_count():
				var original := mesh.surface_get_material(surface) as StandardMaterial3D
				var material := ShaderMaterial.new()
				material.shader = WIND
				material.set_shader_parameter("albedo_texture", original.albedo_texture)
				material.set_shader_parameter("tint", CONFIG.foliage_tint)
				material.set_shader_parameter("color_saturation", CONFIG.foliage_saturation)
				material.set_shader_parameter("wind_strength", CONFIG.wind_strength)
				material.set_shader_parameter("wind_speed", CONFIG.wind_speed)
				mesh.surface_set_material(surface, material)
		scene.free()
		var transforms: Array = _placements[model]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = transforms.size()
		for i: int in transforms.size():
			mm.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = model
		instance.multimesh = mm
		instance.visibility_range_end = CONFIG.draw_distance if tree else CONFIG.foliage_draw_distance
		instance.extra_cull_margin = CONFIG.wind_strength
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tree else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	_placements.clear()


func _workyard() -> void:
	var wood := Build.bark_material(Color(0.3, 0.24, 0.17))
	for row: int in 3:
		for col: int in 4 - row:
			var p := Vector2(-11.5 + col * 0.32 + row * 0.16, -1.5)
			Build.cylinder(self, 0.15, 1.65, _on_ground(p) + Vector3(0, 0.16 + row * 0.26, 0), wood, 7, Vector3(90, 15, 0))
	for i: int in 4:
		_prop("Bag", Vector2(-7.5 + (i % 2) * 0.7, -0.5 + (i / 2) * 0.6), i * 43.0)
	_prop("Barrel", Vector2(-12, -4), 10.0)
	_prop("Crate_Wooden", Vector2(-10.5, -4.5), -12.0)
	_prop("Anvil_Log", Vector2(-10, 3), 25.0)
	for i: int in 4:
		var p := Vector2(-17.0, 1.0 + i * 2.15)
		var fence := KitBuilder.piece(self, "Prop_WoodenFence_Single", _on_ground(p), 90.0)
		if i == 2:
			fence.rotation.z = -0.18



func _prop(model: String, p: Vector2, angle: float) -> void:
	var prop := KitBuilder.instance_of(PROPS + model + ".gltf")
	prop.position = _on_ground(p)
	prop.rotation_degrees.y = angle
	add_child(prop)
