extends Node3D
## Builds the village of Grey Ford out of primitives: ground, houses, church,
## palisade, forest and invisible bounds. The campfire and gate are separate scenes.

const COL_GROUND := Color(0.15, 0.14, 0.11)
const COL_ROAD := Color(0.23, 0.2, 0.16)
const COL_WALL := Color(0.36, 0.32, 0.27)
const COL_WALL_DARK := Color(0.27, 0.25, 0.23)
const COL_ROOF := Color(0.24, 0.18, 0.13)
const COL_THATCH := Color(0.33, 0.28, 0.18)
const COL_WOOD := Color(0.22, 0.15, 0.1)
const COL_STONE := Color(0.33, 0.33, 0.34)
const COL_PLAGUE_MARK := Color(0.42, 0.08, 0.06)
const COL_WINDOW_DARK := Color(0.05, 0.05, 0.06)
const COL_WINDOW_LIT := Color(1.0, 0.58, 0.24)
const COL_TRUNK := Color(0.18, 0.13, 0.1)
const COL_PINE := Color(0.12, 0.19, 0.14)

const FOREST_SEED := 1347
const CLEARING := Rect2(-22.0, -27.0, 44.0, 47.0)  # x, z, width, depth: no trees inside
const BOUNDS := Rect2(-28.0, -31.0, 56.0, 54.0)
const PALISADE_Z := 22.0
const GATE_HALF_WIDTH := 2.9

const INSPECT_DIALOGUE: DialogueResource = preload("res://dialogues/inspect.dialogue")

# Position (x, z), whether the windows are lit. Dark houses are marked with a plague cross.
const HOUSES: Array[Dictionary] = [
	{"pos": Vector2(-12.0, -6.0), "lit": true},
	{"pos": Vector2(12.5, -5.0), "lit": false},
	{"pos": Vector2(-13.0, 8.5), "lit": false},
	{"pos": Vector2(13.0, 9.0), "lit": true},
	{"pos": Vector2(-9.5, -16.0), "lit": true},
]


func _ready() -> void:
	_build_ground()
	for house: Dictionary in HOUSES:
		_build_house(house["pos"], house["lit"])
	_build_church(Vector3(0.0, 0.0, -20.0))
	_build_palisade()
	_build_forest()
	_build_bounds()


func _build_ground() -> void:
	Build.box(self, Vector3(300.0, 0.2, 300.0), Vector3(0.0, -0.1, 0.0), Build.material(COL_GROUND))
	Build.static_box(self, Vector3(300.0, 0.2, 300.0), Vector3(0.0, -0.1, 0.0))
	# Trampled earth: around the fire and the road to the gate.
	Build.cylinder(self, 4.5, 0.02, Vector3(0.0, 0.01, 0.0), Build.material(COL_ROAD), 9)
	Build.box(self, Vector3(3.2, 0.02, 20.0), Vector3(0.0, 0.012, 13.0), Build.material(COL_ROAD))
	Build.box(self, Vector3(3.0, 0.02, 12.0), Vector3(0.0, 0.012, -9.0), Build.material(COL_ROAD))


func _build_house(pos: Vector2, lit: bool) -> void:
	var house := Node3D.new()
	house.name = "House"
	house.position = Vector3(pos.x, 0.0, pos.y)
	# Front door faces the campfire in the village centre.
	house.rotation.y = atan2(-pos.x, -pos.y)
	add_child(house)

	var w := 5.0
	var h := 3.0
	var d := 4.0
	var wall := Build.material(COL_WALL if lit else COL_WALL_DARK)
	Build.box(house, Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0), wall)
	Build.prism(house, Vector3(w + 0.7, 1.9, d + 0.7), Vector3(0.0, h + 0.95, 0.0), Build.material(COL_THATCH))
	Build.box(house, Vector3(0.6, 1.4, 0.6), Vector3(1.4, h + 1.4, -0.6), Build.material(COL_STONE))
	Build.box(house, Vector3(1.0, 1.9, 0.1), Vector3(0.9, 0.95, d * 0.5 + 0.04), Build.material(COL_WOOD))
	Build.static_box(house, Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0))

	var window_mat := Build.material(COL_WINDOW_LIT, COL_WINDOW_LIT, 3.0) if lit else Build.material(COL_WINDOW_DARK)
	Build.box(house, Vector3(0.8, 0.7, 0.08), Vector3(-1.2, 1.7, d * 0.5 + 0.03), window_mat)
	Build.box(house, Vector3(0.08, 0.7, 0.8), Vector3(w * 0.5 + 0.03, 1.7, 0.0), window_mat)
	Build.box(house, Vector3(0.08, 0.7, 0.8), Vector3(-w * 0.5 - 0.03, 1.7, 0.0), window_mat)

	if lit:
		var glow := OmniLight3D.new()
		glow.light_color = COL_WINDOW_LIT
		glow.light_energy = 0.9
		glow.omni_range = 4.5
		glow.position = Vector3(-1.2, 1.7, d * 0.5 + 0.7)
		house.add_child(glow)
	else:
		# Boarded window and a painted cross on the door: plague house.
		var boards := Build.material(COL_WOOD)
		Build.box(house, Vector3(1.0, 0.12, 0.06), Vector3(-1.2, 1.85, d * 0.5 + 0.09), boards, Vector3(0.0, 0.0, 12.0))
		Build.box(house, Vector3(1.0, 0.12, 0.06), Vector3(-1.2, 1.55, d * 0.5 + 0.09), boards, Vector3(0.0, 0.0, -9.0))
		var mark := Build.material(COL_PLAGUE_MARK)
		Build.box(house, Vector3(0.12, 1.2, 0.03), Vector3(0.9, 1.1, d * 0.5 + 0.1), mark, Vector3(0.0, 0.0, 30.0))
		Build.box(house, Vector3(0.12, 1.2, 0.03), Vector3(0.9, 1.1, d * 0.5 + 0.1), mark, Vector3(0.0, 0.0, -30.0))
		_add_inspectable(house, Vector3(0.9, 1.0, d * 0.5 + 0.4), "Осмотреть дверь", "plague_house")


func _build_church(pos: Vector3) -> void:
	var church := Node3D.new()
	church.name = "Church"
	church.position = pos
	add_child(church)
	var stone := Build.material(COL_STONE)

	# Nave.
	Build.box(church, Vector3(7.0, 6.0, 12.0), Vector3(0.0, 3.0, 0.0), stone)
	Build.prism(church, Vector3(7.8, 3.4, 12.6), Vector3(0.0, 7.7, 0.0), Build.material(COL_ROOF))
	Build.static_box(church, Vector3(7.0, 6.0, 12.0), Vector3(0.0, 3.0, 0.0))
	# Bell tower in front, with a four-sided spire and a cross.
	Build.box(church, Vector3(3.2, 10.0, 3.2), Vector3(0.0, 5.0, 7.4), stone)
	Build.static_box(church, Vector3(3.2, 10.0, 3.2), Vector3(0.0, 5.0, 7.4))
	Build.cone(church, 2.4, 5.0, Vector3(0.0, 12.5, 7.4), Build.material(COL_ROOF), 4, Vector3(0.0, 45.0, 0.0))
	var wood := Build.material(COL_WOOD)
	Build.box(church, Vector3(0.12, 1.2, 0.12), Vector3(0.0, 15.5, 7.4), wood)
	Build.box(church, Vector3(0.7, 0.12, 0.12), Vector3(0.0, 15.7, 7.4), wood)
	Build.box(church, Vector3(1.0, 1.1, 0.1), Vector3(0.0, 8.4, 9.04), Build.material(COL_WINDOW_DARK))
	Build.box(church, Vector3(1.5, 2.6, 0.1), Vector3(0.0, 1.3, 9.04), wood)
	_add_inspectable(church, Vector3(0.0, 1.0, 9.5), "Осмотреть дверь церкви", "church")
	# Tall windows with faint candle light.
	var candle := Color(0.95, 0.62, 0.32)
	var window_mat := Build.material(candle, candle, 1.4)
	for z: float in [-3.5, 0.0, 3.5]:
		Build.box(church, Vector3(0.08, 2.0, 0.7), Vector3(3.53, 3.2, z), window_mat)
		Build.box(church, Vector3(0.08, 2.0, 0.7), Vector3(-3.53, 3.2, z), window_mat)


func _build_palisade() -> void:
	var stake := Build.material(COL_WOOD)
	var rng := RandomNumberGenerator.new()
	rng.seed = FOREST_SEED + 1
	var x := -BOUNDS.size.x * 0.5
	while x <= BOUNDS.size.x * 0.5:
		if absf(x) > GATE_HALF_WIDTH:
			var h := rng.randf_range(3.2, 3.9)
			Build.cylinder(self, 0.24, h, Vector3(x, h * 0.5, PALISADE_Z), stake, 6)
			Build.cone(self, 0.24, 0.5, Vector3(x, h + 0.25, PALISADE_Z), stake, 6)
		x += 0.5
	var half := BOUNDS.size.x * 0.5
	var side_len := half - GATE_HALF_WIDTH
	var side_centre := GATE_HALF_WIDTH + side_len * 0.5
	Build.static_box(self, Vector3(side_len, 4.0, 0.6), Vector3(-side_centre, 2.0, PALISADE_Z))
	Build.static_box(self, Vector3(side_len, 4.0, 0.6), Vector3(side_centre, 2.0, PALISADE_Z))


func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FOREST_SEED
	var placed := 0
	var attempts := 0
	while placed < 230 and attempts < 4000:
		attempts += 1
		var p := Vector2(rng.randf_range(-48.0, 48.0), rng.randf_range(-50.0, 48.0))
		if CLEARING.has_point(p):
			continue
		if absf(p.x) < 4.0 and p.y > PALISADE_Z - 2.0:
			continue  # Road out of the gate.
		if absf(p.y - PALISADE_Z) < 1.2:
			continue  # Keep trees out of the palisade.
		_build_tree(Vector3(p.x, 0.0, p.y), rng.randf_range(0.8, 1.5), rng.randf())
		placed += 1


func _build_tree(pos: Vector3, s: float, shade: float) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.rotation.y = shade * TAU
	tree.scale = Vector3.ONE * s
	add_child(tree)
	Build.cylinder(tree, 0.22, 1.8, Vector3(0.0, 0.9, 0.0), Build.material(COL_TRUNK), 5)
	var needles := Build.material(COL_PINE.lerp(Color(0.16, 0.18, 0.13), shade))
	Build.cone(tree, 1.7, 2.2, Vector3(0.0, 2.0, 0.0), needles, 6)
	Build.cone(tree, 1.3, 2.0, Vector3(0.0, 3.1, 0.0), needles, 6)
	Build.cone(tree, 0.9, 1.8, Vector3(0.0, 4.1, 0.0), needles, 6)
	if BOUNDS.grow(1.0).has_point(Vector2(pos.x, pos.z)):
		Build.static_cylinder(tree, 0.3, 2.0, Vector3(0.0, 1.0, 0.0))


func _build_bounds() -> void:
	var b := BOUNDS
	var centre := b.get_center()
	Build.static_box(self, Vector3(1.0, 6.0, b.size.y), Vector3(b.position.x, 3.0, centre.y))
	Build.static_box(self, Vector3(1.0, 6.0, b.size.y), Vector3(b.end.x, 3.0, centre.y))
	Build.static_box(self, Vector3(b.size.x, 6.0, 1.0), Vector3(centre.x, 3.0, b.position.y))


func _add_inspectable(parent: Node3D, pos: Vector3, prompt: String, cue: String) -> void:
	var inspectable := Inspectable.new()
	inspectable.prompt = prompt
	inspectable.dialogue = INSPECT_DIALOGUE
	inspectable.cue = cue
	inspectable.position = pos
	parent.add_child(inspectable)
