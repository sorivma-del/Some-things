class_name WorldTerrain
extends Node3D
## Ground of the open world: rolling hills that rise into mountains at the edges, a river
## winding across (shallow at the ford), muddy roads, flat clearings at the places.
## Everything is computed once on a 2 m grid: the render mesh, a heightmap collider (same
## grid, uniformly scaled) and height_at() (bilinear), so feet, wheels and hooves agree.
## In group "terrain" like the village Terrain, so the same helpers place things on it.

const CONFIG: WorldConfig = preload("res://resources/world/world_config.tres")
const SHADER: Shader = preload("res://resources/terrain.gdshader")
const TEX := "res://resources/textures/ground/"

const STEP := 2.0
const HALF_WIDTH := 300.0
const Z_MIN := -40.0
const DEPTH := 600.0
const WATER_LEVEL := -1.0
const RIVER_Z := 228.0
const RIVER_HALF_WIDTH := 9.0
const FORD_X := -100.0
const BRIDGE_X := 40.0
## Roads and clearings stop shaping the ground this far out.
const ROAD_REACH := 20.0

## Roads: polylines of (x, z).
static var ROADS: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(0, 2), Vector2(4, 40), Vector2(0, 90), Vector2(18, 150), Vector2(40, 205), Vector2(40, 262), Vector2(55, 295), Vector2(70, 322)]),
	PackedVector2Array([Vector2(0, 90), Vector2(-50, 80), Vector2(-110, 72)]),
	PackedVector2Array([Vector2(-50, 80), Vector2(-80, 140)]),
	PackedVector2Array([Vector2(0, 90), Vector2(60, 110), Vector2(122, 133)]),
	PackedVector2Array([Vector2(18, 150), Vector2(-30, 182), Vector2(-55, 198)]),
	PackedVector2Array([Vector2(-55, 198), Vector2(-100, 205), Vector2(-100, 250), Vector2(-150, 300), Vector2(-150, 412)]),
]

## Flat, trampled clearings: (x, z, radius). Fill before build().
var flat_spots: Array[Vector3] = []

var _nx: int
var _nz: int
var _heights := PackedFloat32Array()
var _road := PackedFloat32Array()
var _flat := PackedFloat32Array()
var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()


func _init() -> void:
	_hills.seed = 7714
	_hills.frequency = 0.012
	_hills.fractal_octaves = 4
	_detail.seed = 7721
	_detail.frequency = 0.2


static func river_z(x: float) -> float:
	return RIVER_Z + 10.0 * sin(x / 55.0)


func build() -> void:
	add_to_group(&"terrain")
	_nx = int(HALF_WIDTH * 2.0 / STEP) + 1
	_nz = int(DEPTH / STEP) + 1
	_stamp_roads_and_clearings()
	_heights.resize(_nx * _nz)
	for zi: int in _nz:
		for xi: int in _nx:
			var i := zi * _nx + xi
			_heights[i] = _raw_height(-HALF_WIDTH + xi * STEP, Z_MIN + zi * STEP, i)
	_build_mesh()
	_build_collider()
	_build_water()


## Ground height at any point (bilinear over the grid; matches the collider).
func height_at(x: float, z: float) -> float:
	var fx := clampf((x + HALF_WIDTH) / STEP, 0.0, _nx - 1.001)
	var fz := clampf((z - Z_MIN) / STEP, 0.0, _nz - 1.001)
	var xi := int(fx)
	var zi := int(fz)
	var tx := fx - xi
	var tz := fz - zi
	var i := zi * _nx + xi
	var top := lerpf(_heights[i], _heights[i + 1], tx)
	var bottom := lerpf(_heights[i + _nx], _heights[i + _nx + 1], tx)
	return lerpf(top, bottom, tz)


func road_distance(x: float, z: float) -> float:
	return _sample(_road, x, z)


func is_in_river(x: float, z: float, margin: float = 0.0) -> bool:
	return absf(z - river_z(x)) < RIVER_HALF_WIDTH + margin


func is_inside(x: float, z: float, margin: float = 0.0) -> bool:
	return absf(x) < HALF_WIDTH - margin and z > Z_MIN + margin and z < Z_MIN + DEPTH - margin


## A parchment-style map of the land: relief shading, woods, water, roads.
## One pixel per grid cell (2 m); north (smaller z) at the top.
func make_map_image() -> Image:
	var image := Image.create(_nx, _nz, false, Image.FORMAT_RGB8)
	var paper := Color(0.74, 0.67, 0.52)
	var wood := Color(0.42, 0.47, 0.33)
	var water := Color(0.3, 0.37, 0.4)
	var road := Color(0.47, 0.36, 0.25)
	var rock := Color(0.6, 0.58, 0.55)
	for zi: int in _nz:
		for xi: int in _nx:
			var i := zi * _nx + xi
			var x := -HALF_WIDTH + xi * STEP
			var z := Z_MIN + zi * STEP
			var h := _heights[i]
			var color := paper
			if h > 12.0:
				color = paper.lerp(rock, clampf((h - 12.0) / 14.0, 0.0, 1.0))
			if forest_weight(x, z) > 0.5 and h < 14.0:
				color = color.lerp(wood, 0.75)
			if _road[i] < 2.2:
				color = road
			if h < WATER_LEVEL - 0.3:
				color = water
			# Light from the north-west: slopes facing it are brighter.
			var east := _heights[mini(i + 1, _heights.size() - 1)] if xi < _nx - 1 else h
			var south := _heights[mini(i + _nx, _heights.size() - 1)] if zi < _nz - 1 else h
			var shade := clampf(1.0 - (east - h) * 0.12 - (south - h) * 0.12, 0.7, 1.25)
			image.set_pixel(xi, zi, color * shade)
	return image


## World (x, z) -> 0..1 on the map image.
static func map_uv(x: float, z: float) -> Vector2:
	return Vector2((x + HALF_WIDTH) / (HALF_WIDTH * 2.0), (z - Z_MIN) / DEPTH)


func forest_weight(x: float, z: float) -> float:
	return clampf(_hills.get_noise_2d(z * 1.7, x * 1.7) * 0.9 + 0.35, 0.0, 1.0)


func _raw_height(x: float, z: float, i: int) -> float:
	var road := _road[i]
	var river := absf(z - river_z(x))
	var flat := _flat[i]
	var hill_amount := smoothstep(3.0, 18.0, road) * smoothstep(12.0, 45.0, river) * (1.0 - flat)
	var h := (_hills.get_noise_2d(x, z) * 0.5 + 0.5) * 9.0 * hill_amount
	# Mountains close the world in.
	var edge := maxf(absf(x) - (HALF_WIDTH - 60.0), maxf(Z_MIN + 35.0 - z, z - (Z_MIN + DEPTH - 60.0)))
	h += smoothstep(0.0, 60.0, edge) * 28.0
	# The river bed, shallow at the ford.
	var carve := (1.0 - smoothstep(RIVER_HALF_WIDTH - 3.0, RIVER_HALF_WIDTH + 7.0, river)) * 3.2
	carve *= 1.0 - 0.6 * (1.0 - smoothstep(5.0, 12.0, absf(x - FORD_X)))
	h -= carve
	h += _detail.get_noise_2d(x, z) * 0.15 * (1.0 - flat) * smoothstep(1.5, 4.0, road)
	h -= 0.08 * _mud(x, z, i)
	return h


func _mud(x: float, z: float, i: int) -> float:
	var w := maxf(1.0 - smoothstep(1.6, 3.4, _road[i]), _flat[i] * 0.7)
	return clampf(w + _detail.get_noise_2d(x * 2.0, z * 2.0) * 0.3 * w, 0.0, 1.0)


## Distance to the nearest road and clearing strength per grid cell, written only near
## each road segment and clearing (everything else stays "far").
func _stamp_roads_and_clearings() -> void:
	_road.resize(_nx * _nz)
	_road.fill(ROAD_REACH)
	_flat.resize(_nx * _nz)
	_flat.fill(0.0)
	for road: PackedVector2Array in ROADS:
		for s: int in road.size() - 1:
			var a := road[s]
			var b := road[s + 1]
			var box := Rect2(a, Vector2.ZERO).expand(b).grow(ROAD_REACH)
			_for_cells(box, func(i: int, p: Vector2) -> void:
				_road[i] = minf(_road[i], p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))))
	for spot: Vector3 in flat_spots:
		var centre := Vector2(spot.x, spot.y)
		var reach := spot.z + 8.0
		_for_cells(Rect2(centre - Vector2(reach, reach), Vector2(reach, reach) * 2.0), func(i: int, p: Vector2) -> void:
			_flat[i] = maxf(_flat[i], 1.0 - smoothstep(spot.z, reach, p.distance_to(centre))))


func _for_cells(box: Rect2, action: Callable) -> void:
	var x0 := maxi(0, int((box.position.x + HALF_WIDTH) / STEP))
	var x1 := mini(_nx - 1, int((box.end.x + HALF_WIDTH) / STEP) + 1)
	var z0 := maxi(0, int((box.position.y - Z_MIN) / STEP))
	var z1 := mini(_nz - 1, int((box.end.y - Z_MIN) / STEP) + 1)
	for zi: int in range(z0, z1 + 1):
		for xi: int in range(x0, x1 + 1):
			action.call(zi * _nx + xi, Vector2(-HALF_WIDTH + xi * STEP, Z_MIN + zi * STEP))


func _sample(grid: PackedFloat32Array, x: float, z: float) -> float:
	var xi := clampi(roundi((x + HALF_WIDTH) / STEP), 0, _nx - 1)
	var zi := clampi(roundi((z - Z_MIN) / STEP), 0, _nz - 1)
	return grid[zi * _nx + xi]


func _build_mesh() -> void:
	var material := _make_material()
	var cells := maxi(1, CONFIG.terrain_chunk_cells)
	var chunks := Node3D.new()
	chunks.name = "TerrainChunks"
	add_child(chunks)
	for z0: int in range(0, _nz - 1, cells):
		for x0: int in range(0, _nx - 1, cells):
			_build_chunk(chunks, material, x0, z0, mini(x0 + cells, _nx - 1), mini(z0 + cells, _nz - 1))


## Общие высоты и нормали сохраняют стыки; каждый участок отсекается камерой отдельно.
func _build_chunk(parent: Node3D, material: ShaderMaterial, x0: int, z0: int, x1: int, z1: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := x1 - x0 + 1
	for zi: int in range(z0, z1 + 1):
		for xi: int in range(x0, x1 + 1):
			var i := zi * _nx + xi
			var x := -HALF_WIDTH + xi * STEP
			var z := Z_MIN + zi * STEP
			var wet := _heights[i] < WATER_LEVEL - 0.2
			st.set_color(Color(1.0 if wet else _mud(x, z, i), forest_weight(x, z), 1.0 - smoothstep(1.2, 3.5, _road[i])))
			st.set_uv(Vector2(x, z))
			st.set_normal(_normal_at(xi, zi))
			st.add_vertex(Vector3(x, _heights[i], z))
	for zi: int in range(z1 - z0):
		for xi: int in range(x1 - x0):
			var i := zi * width + xi
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + width)
			st.add_index(i + 1)
			st.add_index(i + width + 1)
			st.add_index(i + width)
	st.generate_tangents()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)


func _normal_at(xi: int, zi: int) -> Vector3:
	var left := maxi(xi - 1, 0)
	var right := mini(xi + 1, _nx - 1)
	var north := maxi(zi - 1, 0)
	var south := mini(zi + 1, _nz - 1)
	var dx := (_heights[zi * _nx + right] - _heights[zi * _nx + left]) / ((right - left) * STEP)
	var dz := (_heights[south * _nx + xi] - _heights[north * _nx + xi]) / ((south - north) * STEP)
	return Vector3(-dx, 1.0, -dz).normalized()


## Same grid as the mesh: heights halved and the shape scaled by 2 (uniform scale only).
func _build_collider() -> void:
	var scaled := PackedFloat32Array()
	scaled.resize(_heights.size())
	for i: int in _heights.size():
		scaled[i] = _heights[i] / STEP
	var heightmap := HeightMapShape3D.new()
	heightmap.map_width = _nx
	heightmap.map_depth = _nz
	heightmap.map_data = scaled
	var shape := CollisionShape3D.new()
	shape.shape = heightmap
	shape.scale = Vector3.ONE * STEP
	var body := StaticBody3D.new()
	# The heightmap is centred on its node.
	body.position = Vector3(0.0, 0.0, Z_MIN + DEPTH * 0.5)
	body.add_child(shape)
	add_child(body)


func _build_water() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.15, 0.17, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.12
	mat.metallic = 0.3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := RIVER_HALF_WIDTH + 9.0
	var x := -HALF_WIDTH
	while x < HALF_WIDTH:
		var x2 := x + 6.0
		var a := Vector3(x, WATER_LEVEL, river_z(x) - width)
		var b := Vector3(x, WATER_LEVEL, river_z(x) + width)
		var c := Vector3(x2, WATER_LEVEL, river_z(x2) - width)
		var d := Vector3(x2, WATER_LEVEL, river_z(x2) + width)
		for v: Vector3 in [a, c, b, c, d, b]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
		x = x2
	var water := MeshInstance3D.new()
	water.mesh = st.commit()
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _make_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("normal_strength", CONFIG.ground_normal_strength)
	mat.set_shader_parameter("yard_enabled", true)
	mat.set_shader_parameter("yard_center", CONFIG.yard_center)
	mat.set_shader_parameter("yard_door", CONFIG.yard_door)
	mat.set_shader_parameter("yard_radius", CONFIG.yard_radius)
	for layer: String in ["mud", "grass", "forest"]:
		var file: String = {"mud": "brown_mud_03", "grass": "sparse_grass", "forest": "mud_forest"}[layer]
		mat.set_shader_parameter(layer + "_albedo", load(TEX + file + "_diff.jpg"))
		mat.set_shader_parameter(layer + "_normal", load(TEX + file + "_nor_gl.jpg"))
		mat.set_shader_parameter(layer + "_rough", load(TEX + file + "_rough.jpg"))
	return mat
