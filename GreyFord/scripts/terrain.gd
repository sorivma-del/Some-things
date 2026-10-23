class_name Terrain
extends Node3D
## Procedural ground: a flat village floor that rolls up into hills toward the forest,
## a sunken road to the gate, mud around the fire, buildings and paths. Builds a mesh,
## a HeightMapShape3D collider, and exposes height_at() and grass_weight() for scattering.

const SHADER: Shader = preload("res://resources/terrain.gdshader")
const TEX := "res://resources/textures/ground/"

@export var size: int = 140  ## Metres per side; one vertex per metre.
@export var village_radius: float = 21.0  ## Fully flat inside this.
@export var hill_height: float = 5.0
@export var noise_seed: int = 4021

## Spots kept flat and trampled: Vector3(x, z, radius).
var flat_spots: Array[Vector3] = []
## Muddy paths as segments: [from: Vector2, to: Vector2, half_width: float].
var paths: Array[Array] = []

var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()


func _init() -> void:
	_hills.seed = noise_seed
	_hills.frequency = 0.035
	_detail.seed = noise_seed + 7
	_detail.frequency = 0.25


## Call after flat_spots and paths are filled.
func build() -> void:
	add_to_group(&"terrain")
	var n := size + 1
	var half := size * 0.5
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi: int in n:
		for xi: int in n:
			var x := xi - half
			var z := zi - half
			var h := height_at(x, z)
			heights[zi * n + xi] = h
			st.set_color(Color(mud_weight(x, z), forest_weight(x, z), 0.0))
			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, h, z))
	for zi: int in size:
		for xi: int in size:
			var i := zi * n + xi
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + n)
			st.add_index(i + 1)
			st.add_index(i + n + 1)
			st.add_index(i + n)
	st.generate_normals()
	st.generate_tangents()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = _make_material()
	add_child(mesh_instance)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var heightmap := HeightMapShape3D.new()
	heightmap.map_width = n
	heightmap.map_depth = n
	heightmap.map_data = heights
	shape.shape = heightmap
	body.add_child(shape)
	add_child(body)


func height_at(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var rise := smoothstep(village_radius, village_radius + 18.0, d)
	var h := (_hills.get_noise_2d(x, z) * 0.5 + 0.6) * hill_height * rise
	# Small bumps everywhere, kept off flat spots and paths.
	h += _detail.get_noise_2d(x, z) * 0.12 * (1.0 - _flatness(x, z))
	# The road and trampled spots sink a little into the mud.
	h -= 0.06 * mud_weight(x, z)
	return h


func mud_weight(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var w := 0.0
	for spot: Vector3 in flat_spots:
		w = maxf(w, 1.0 - smoothstep(spot.z * 0.6, spot.z, p.distance_to(Vector2(spot.x, spot.y))))
	for path: Array in paths:
		var closest := Geometry2D.get_closest_point_to_segment(p, path[0], path[1])
		var half_width: float = path[2]
		w = maxf(w, 1.0 - smoothstep(half_width * 0.5, half_width, p.distance_to(closest)))
	# Ragged edges.
	return clampf(w + _detail.get_noise_2d(x * 2.0, z * 2.0) * 0.35 * w, 0.0, 1.0)


func forest_weight(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	return clampf(smoothstep(village_radius - 2.0, village_radius + 8.0, d) + _hills.get_noise_2d(z, x) * 0.3, 0.0, 1.0)


## How suitable a spot is for grass and weeds (0..1).
func grass_weight(x: float, z: float) -> float:
	return (1.0 - mud_weight(x, z)) * (1.0 - forest_weight(x, z) * 0.6)


func _flatness(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var f := 0.0
	for spot: Vector3 in flat_spots:
		f = maxf(f, 1.0 - smoothstep(spot.z, spot.z + 2.0, p.distance_to(Vector2(spot.x, spot.y))))
	return f


func _make_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	for layer: String in ["mud", "grass", "forest"]:
		var file: String = {"mud": "brown_mud_03", "grass": "sparse_grass", "forest": "mud_forest"}[layer]
		mat.set_shader_parameter(layer + "_albedo", load(TEX + file + "_diff.jpg"))
		mat.set_shader_parameter(layer + "_normal", load(TEX + file + "_nor_gl.jpg"))
		mat.set_shader_parameter(layer + "_rough", load(TEX + file + "_rough.jpg"))
	return mat
