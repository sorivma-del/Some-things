extends Node3D
## Builds Grey Ford: terrain, houses and church from the Medieval Village MegaKit, a
## palisade, the forest and undergrowth from the Stylized Nature MegaKit, and invisible
## bounds. The campfire and the gate are separate scenes.

const NATURE := "res://resources/models/nature/"
const INSPECT_DIALOGUE: DialogueResource = preload("res://dialogues/inspect.dialogue")

const SEED := 1347
const CLEARING := Rect2(-22.0, -31.0, 44.0, 51.0)  # x, z, width, depth: no trees inside
const BOUNDS := Rect2(-28.0, -33.0, 56.0, 56.0)
const PALISADE_Z := 22.0
const GATE_HALF_WIDTH := 2.9
const CHURCH_POS := Vector2(0.0, -19.0)
const DRY_GRASS := Color(0.5, 0.48, 0.34)
const GRASS_SHADER: Shader = preload("res://resources/grass_wind.gdshader")

# Position (x, z), modules deep, lit windows. Dark houses are plague houses.
const HOUSES: Array[Dictionary] = [
	{"pos": Vector2(-12.0, -6.0), "depth": 3, "lit": true},
	{"pos": Vector2(12.5, -5.0), "depth": 4, "lit": false},
	{"pos": Vector2(-13.0, 8.5), "depth": 3, "lit": false},
	{"pos": Vector2(13.0, 9.0), "depth": 4, "lit": true},
	{"pos": Vector2(-10.5, -17.5), "depth": 3, "lit": true},
]

var _terrain: Terrain
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = SEED
	_build_terrain()
	for house: Dictionary in HOUSES:
		_build_house(house["pos"], house["depth"], house["lit"])
	_build_church()
	_build_props()
	_build_palisade()
	_build_forest()
	_scatter_undergrowth()
	_build_bounds()
	_build_atmosphere()


func _build_terrain() -> void:
	_terrain = Terrain.new()
	_terrain.flat_spots.append(Vector3(0.0, 0.0, 5.0))  # Campfire.
	_terrain.flat_spots.append(Vector3(CHURCH_POS.x, CHURCH_POS.y - 2.0, 11.0))
	_terrain.flat_spots.append(Vector3(0.0, PALISADE_Z, 5.0))
	_terrain.paths.append([Vector2(0.0, 3.0), Vector2(0.0, PALISADE_Z + 40.0), 1.8])
	_terrain.paths.append([Vector2(0.0, -3.0), Vector2(CHURCH_POS.x, CHURCH_POS.y + 6.5), 1.5])
	for house: Dictionary in HOUSES:
		var p: Vector2 = house["pos"]
		_terrain.flat_spots.append(Vector3(p.x, p.y, 5.0 + house["depth"]))
		_terrain.paths.append([p.move_toward(Vector2.ZERO, 3.0), p.move_toward(Vector2.ZERO, p.length() - 4.0), 1.0])
	add_child(_terrain)
	_terrain.build()


func _build_house(pos: Vector2, depth: int, lit: bool) -> void:
	var house := KitBuilder.house(self, depth, lit)
	house.position = Vector3(pos.x, 0.0, pos.y)
	# Front door faces the campfire in the village centre.
	house.rotation.y = atan2(-pos.x, -pos.y)
	var front := depth * KitBuilder.MODULE * 0.5
	if lit:
		Effects.smoke(house, Vector3(1.6, 7.7, -front + 1.5))
		var glow := OmniLight3D.new()
		glow.light_color = KitBuilder.WINDOW_GLOW
		glow.light_energy = 1.2
		glow.omni_range = 5.5
		glow.position = Vector3(0.0, 1.8, front + 1.2)
		house.add_child(glow)
	else:
		_add_inspectable(house, Vector3(0.0, 1.0, front + 0.5), "Осмотреть дверь", "plague_house")


func _build_church() -> void:
	var church := KitBuilder.church(self)
	church.position = Vector3(CHURCH_POS.x, 0.0, CHURCH_POS.y)
	_add_inspectable(church, Vector3(0.0, 1.0, 6.6), "Осмотреть дверь церкви", "church")
	var candle := OmniLight3D.new()
	candle.light_color = KitBuilder.CANDLE_GLOW
	candle.light_energy = 0.8
	candle.omni_range = 5.0
	candle.position = Vector3(0.0, 2.0, 7.2)
	church.add_child(candle)


func _build_props() -> void:
	# A cart left by the lit house on the right, crates and a broken fence at a plague house.
	var cart := KitBuilder.piece(self, "Prop_Wagon", Vector3(8.6, 0.0, 13.2), 200.0)
	Build.static_box(cart, Vector3(1.9, 1.5, 4.0), Vector3(0.0, 0.75, -1.15))
	for p: Vector3 in [Vector3(16.6, 0.0, 4.4), Vector3(17.4, 0.0, 5.3), Vector3(16.9, 1.06, 4.8)]:
		var crate := KitBuilder.piece(self, "Prop_Crate", p, _rng.randf_range(0.0, 90.0))
		if p.y == 0.0:
			Build.static_box(crate, Vector3(1.08, 1.06, 1.08), Vector3(0.0, 0.53, 0.0))
	for i: int in 3:
		KitBuilder.piece(self, "Prop_WoodenFence_Single", Vector3(-17.5 + i * 2.05, 0.0, 13.6), 8.0 * i)


func _build_palisade() -> void:
	var wood := Build.bark_material(Color(0.55, 0.48, 0.42))
	var x := BOUNDS.position.x
	while x <= BOUNDS.end.x:
		if absf(x) > GATE_HALF_WIDTH:
			var h := _rng.randf_range(3.2, 3.9)
			var y := _terrain.height_at(x, PALISADE_Z) - 0.3
			var stake := Build.cylinder(self, 0.24, h, Vector3(x, y + h * 0.5, PALISADE_Z), wood, 7)
			stake.rotation_degrees = Vector3(_rng.randf_range(-3.0, 3.0), _rng.randf() * 360.0, _rng.randf_range(-3.0, 3.0))
			Build.cone(self, 0.24, 0.5, Vector3(x, y + h + 0.25, PALISADE_Z), wood, 7)
		x += 0.5
	var half := BOUNDS.size.x * 0.5
	var side_len := half - GATE_HALF_WIDTH
	var side_centre := GATE_HALF_WIDTH + side_len * 0.5
	Build.static_box(self, Vector3(side_len, 6.0, 0.6), Vector3(-side_centre, 2.0, PALISADE_Z))
	Build.static_box(self, Vector3(side_len, 6.0, 0.6), Vector3(side_centre, 2.0, PALISADE_Z))


func _build_forest() -> void:
	var placed := 0
	var attempts := 0
	while placed < 170 and attempts < 5000:
		attempts += 1
		var p := Vector2(_rng.randf_range(-60.0, 60.0), _rng.randf_range(-62.0, 62.0))
		if CLEARING.has_point(p):
			continue
		if absf(p.x) < 4.5 and p.y > PALISADE_Z - 2.0:
			continue  # Road out of the gate.
		if absf(p.y - PALISADE_Z) < 2.0 and absf(p.x) < BOUNDS.end.x + 1.0:
			continue  # Keep trees out of the palisade.
		var dead := _rng.randf() < 0.22
		var model := "DeadTree_%d" % _rng.randi_range(1, 5) if dead else "Pine_%d" % _rng.randi_range(1, 5)
		var tree := _nature(model, p, _rng.randf_range(0.75, 1.25) * (0.8 if dead else 1.0))
		if BOUNDS.grow(2.0).has_point(p):
			Build.static_cylinder(tree, 0.35, 3.0, Vector3(0.0, 1.5, 0.0))
		elif not BOUNDS.grow(12.0).has_point(p):
			_set_shadows(tree, false)  # Deep forest: hidden in fog, skip shadow cost.
		placed += 1


## Grass, ferns, bushes, rocks and mushrooms. Grass is drawn with MultiMesh.
func _scatter_undergrowth() -> void:
	var grass_meshes: Array[Mesh] = [
		_nature_mesh("Grass_Common_Short"), _nature_mesh("Grass_Common_Tall"),
		_nature_mesh("Grass_Wispy_Short"), _nature_mesh("Grass_Wispy_Tall"),
	]
	# Index 0, 2: short kinds for the trampled village; 1, 3: tall kinds toward the forest.
	var grass: Array[Array] = [[], [], [], []]
	for i: int in 9000:
		var p := Vector2(_rng.randf_range(-45.0, 45.0), _rng.randf_range(-45.0, 45.0))
		var wild := _terrain.forest_weight(p.x, p.y)
		if _rng.randf() > _terrain.grass_weight(p.x, p.y) * lerpf(0.3, 1.0, wild) or _blocked(p):
			continue
		var kind: int = _rng.randi_range(0, 3) if wild > 0.5 else _rng.randi_range(0, 1) * 2
		var size := _rng.randf_range(0.3, 0.55) if wild < 0.5 else _rng.randf_range(0.45, 0.85)
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size),
				Vector3(p.x, _terrain.height_at(p.x, p.y), p.y))
		grass[kind].append(t)
	for k: int in grass_meshes.size():
		_multimesh(grass_meshes[k], grass[k])

	for i: int in 160:
		var p := Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-40.0, 40.0))
		if _blocked(p) or _terrain.forest_weight(p.x, p.y) < 0.35:
			continue
		var roll := _rng.randf()
		if roll < 0.35:
			_nature("Fern_1", p, _rng.randf_range(0.25, 0.4))
		elif roll < 0.65:
			_nature("Bush_Common", p, _rng.randf_range(0.7, 1.2))
		elif roll < 0.8:
			_nature("Rock_Medium_%d" % _rng.randi_range(1, 3), p, _rng.randf_range(0.4, 0.9))
		else:
			_nature("Mushroom_Common", p, _rng.randf_range(0.8, 1.4))
	for i: int in 40:
		var p := Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-24.0, 20.0))
		if not _blocked(p):
			_nature("Pebble_Round_%d" % _rng.randi_range(1, 3), p, _rng.randf_range(0.8, 1.6))


func _build_bounds() -> void:
	var b := BOUNDS
	var centre := b.get_center()
	Build.static_box(self, Vector3(1.0, 12.0, b.size.y), Vector3(b.position.x, 3.0, centre.y))
	Build.static_box(self, Vector3(1.0, 12.0, b.size.y), Vector3(b.end.x, 3.0, centre.y))
	Build.static_box(self, Vector3(b.size.x, 12.0, 1.0), Vector3(centre.x, 3.0, b.position.y))


## Wind ambience and low mist drifting in from the forest edge.
func _build_atmosphere() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = ProceduralSound.wind()
	wind.volume_db = -16.0
	add_child(wind)
	ProceduralSound.play_soon(wind)
	Effects.ground_mist(self, Vector3(0.0, 0.8, -2.0), Vector3(24.0, 0.4, 24.0), 45)
	Effects.ground_mist(self, Vector3(0.0, 1.5, 34.0), Vector3(30.0, 0.6, 8.0), 25)


func _set_shadows(node: Node, enabled: bool) -> void:
	var geometry := node as GeometryInstance3D
	if geometry:
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_set_shadows(child, enabled)


## True where undergrowth must not grow: buildings, the fire, the road, the palisade.
func _blocked(p: Vector2) -> bool:
	if p.length() < 4.0 or absf(p.y - PALISADE_Z) < 1.0:
		return true
	if absf(p.x) < 4.0 and absf(p.y - CHURCH_POS.y + 3.0) < 11.0:
		return true
	for house: Dictionary in HOUSES:
		if p.distance_to(house["pos"]) < 3.5 + house["depth"]:
			return true
	return false


func _nature(model: String, p: Vector2, scale_factor: float) -> Node3D:
	var node := KitBuilder.instance_of(NATURE + model + ".gltf")
	node.position = Vector3(p.x, _terrain.height_at(p.x, p.y) - 0.1, p.y)
	node.rotation.y = _rng.randf() * TAU
	node.scale = Vector3.ONE * scale_factor
	add_child(node)
	return node


func _nature_mesh(model: String) -> Mesh:
	var scene := KitBuilder.instance_of(NATURE + model + ".gltf")
	var mesh := (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	scene.free()
	# Late-autumn grass: dry and yellowed rather than the kit's fresh green.
	var mat := mesh.surface_get_material(0) as StandardMaterial3D
	if mat:
		mat.albedo_color = DRY_GRASS
	return mesh


func _multimesh(mesh: Mesh, transforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i: int in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Swap the kit material for one that sways in the wind, keeping its texture.
	var source := mesh.surface_get_material(0) as StandardMaterial3D
	if source:
		var sway := ShaderMaterial.new()
		sway.shader = GRASS_SHADER
		sway.set_shader_parameter(&"albedo_texture", source.albedo_texture)
		sway.set_shader_parameter(&"albedo", DRY_GRASS)
		instance.material_override = sway
	add_child(instance)


func _add_inspectable(parent: Node3D, pos: Vector3, prompt: String, cue: String) -> void:
	var inspectable := Inspectable.new()
	inspectable.prompt = prompt
	inspectable.dialogue = INSPECT_DIALOGUE
	inspectable.cue = cue
	inspectable.position = pos
	parent.add_child(inspectable)
