class_name KitBuilder
extends RefCounted
## Assembles buildings from the Quaternius Medieval Village MegaKit on a 2 m grid.
## Local frame of a building: front (door) faces +Z, walls stand on y = 0.

const DIR := "res://resources/models/village/"
const MODULE := 2.0
const WALL_HEIGHT := 3.12
## The kit is bright and cheerful; everything is muted toward the plague dusk.
const TINT := Color(0.6, 0.57, 0.55)
const ROOF_TINT := Color(0.62, 0.5, 0.5)
const NATURE_TINT := Color(0.72, 0.72, 0.68)
const WINDOW_GLOW := Color(1.0, 0.58, 0.26)
const CANDLE_GLOW := Color(0.95, 0.66, 0.36)
const PLAGUE_MARK := Color(0.45, 0.07, 0.05)

static var _cache: Dictionary[String, PackedScene] = {}
static var _glow_materials: Dictionary[Color, StandardMaterial3D] = {}


static func piece(parent: Node3D, piece_name: String, pos: Vector3, rot_y_deg: float = 0.0) -> Node3D:
	var node := instance_of(DIR + piece_name + ".gltf")
	node.position = pos
	node.rotation_degrees.y = rot_y_deg
	parent.add_child(node)
	return node


## Instantiates a cached glTF scene with its shared materials muted.
static func instance_of(path: String) -> Node3D:
	if not _cache.has(path):
		_cache[path] = load(path) as PackedScene
	var node := _cache[path].instantiate() as Node3D
	_mute(node, NATURE_TINT if path.contains("/nature/") else TINT)
	return node


## A plain cottage: 3 modules wide, `depth_modules` deep. Lit houses glow behind their
## windows; plague houses have closed shutters and a painted cross on the door.
static func house(parent: Node3D, depth_modules: int, lit: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "House"
	parent.add_child(root)
	var hw := MODULE * 1.5
	var hd := MODULE * depth_modules * 0.5
	var side: PackedStringArray = []
	for i: int in depth_modules:
		side.append("Wall_Plaster_Window_Thin_Round" if i % 2 == 1 else "Wall_Plaster_WoodGrid")
	_side(root, ["Wall_Plaster_Window_Wide_Flat", "Wall_Plaster_Door_Flat", "Wall_Plaster_Window_Wide_Flat"], Vector3(0, 0, hd), 0.0, lit, WINDOW_GLOW)
	_side(root, side, Vector3(hw, 0, 0), 90.0, lit, WINDOW_GLOW)
	_side(root, side, Vector3(-hw, 0, 0), -90.0, lit, WINDOW_GLOW)
	_side(root, ["Wall_Plaster_Straight", "Wall_Plaster_WoodGrid", "Wall_Plaster_Straight"], Vector3(0, 0, -hd), 180.0, lit, WINDOW_GLOW)
	for c: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		piece(root, "Corner_Exterior_Wood", Vector3(c.x * hw, 0, c.y * hd))
	piece(root, "Roof_RoundTiles_6x%d" % (depth_modules * 2), Vector3(0, WALL_HEIGHT, 0))
	piece(root, "Roof_Front_Brick6", Vector3(0, WALL_HEIGHT, hd), 0.0)
	piece(root, "Roof_Front_Brick6", Vector3(0, WALL_HEIGHT, -hd), 180.0)
	piece(root, "Door_1_Flat", Vector3(-0.5, 0, hd), 0.0)
	if lit:
		piece(root, "Prop_Chimney", Vector3(1.6, 4.4, -hd + 1.5))
	else:
		var mark := Build.material(PLAGUE_MARK)
		for angle: float in [32.0, -32.0]:
			Build.box(root, Vector3(0.12, 1.3, 0.03), Vector3(0.03, 1.15, hd + 0.1), mark, Vector3(0, 0, angle))
	Build.static_box(root, Vector3(hw * 2.0, WALL_HEIGHT, hd * 2.0), Vector3(0, WALL_HEIGHT * 0.5, 0))
	return root


## Stone church, 3x6 modules, with a bell tower behind the apse.
static func church(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Church"
	parent.add_child(root)
	var hw := MODULE * 1.5
	var hd := MODULE * 3.0
	var side: PackedStringArray = []
	for i: int in 6:
		side.append("Wall_UnevenBrick_Window_Thin_Round" if i % 2 == 1 else "Wall_UnevenBrick_Straight")
	_side(root, ["Wall_UnevenBrick_Window_Thin_Round", "Wall_UnevenBrick_Door_Round", "Wall_UnevenBrick_Window_Thin_Round"], Vector3(0, 0, hd), 0.0, true, CANDLE_GLOW)
	_side(root, side, Vector3(hw, 0, 0), 90.0, true, CANDLE_GLOW)
	_side(root, side, Vector3(-hw, 0, 0), -90.0, true, CANDLE_GLOW)
	_side(root, ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Straight"], Vector3(0, 0, -hd), 180.0, true, CANDLE_GLOW)
	_corners(root, hw, hd, 0.0)
	for z: float in [hd * 0.5, -hd * 0.5]:
		piece(root, "Roof_RoundTiles_6x6", Vector3(0, WALL_HEIGHT, z))
	piece(root, "Roof_Front_Brick6", Vector3(0, WALL_HEIGHT, hd), 0.0)
	piece(root, "Roof_Front_Brick6", Vector3(0, WALL_HEIGHT, -hd), 180.0)
	piece(root, "Door_2_Round", Vector3(-0.53, 0, hd), 0.0)
	Build.static_box(root, Vector3(hw * 2.0, WALL_HEIGHT, hd * 2.0), Vector3(0, WALL_HEIGHT * 0.5, 0))

	# Bell tower: three storeys, open belfry on top.
	var tower := Node3D.new()
	tower.position = Vector3(0, 0, -hd - MODULE)
	root.add_child(tower)
	for level: int in 3:
		var y := WALL_HEIGHT * level
		var wall_piece := "Wall_UnevenBrick_Window_Thin_Round" if level == 2 else "Wall_UnevenBrick_Straight"
		var pieces: PackedStringArray = [wall_piece, wall_piece]
		for facing: float in [0.0, 90.0, 180.0, -90.0]:
			var out := Vector3(0, 0, MODULE).rotated(Vector3.UP, deg_to_rad(facing))
			_side(tower, pieces, out + Vector3(0, y, 0), facing, false, CANDLE_GLOW)
		_corners(tower, MODULE, MODULE, y)
	piece(tower, "Roof_Tower_RoundTiles", Vector3(0, WALL_HEIGHT * 3.0, 0))
	Build.static_box(tower, Vector3(MODULE * 2.0, WALL_HEIGHT * 3.0, MODULE * 2.0), Vector3(0, WALL_HEIGHT * 1.5, 0))
	return root


static func _corners(parent: Node3D, hw: float, hd: float, y: float) -> void:
	# The brick corner piece is asymmetric: rotate it to face out of each corner.
	piece(parent, "Corner_Exterior_Brick", Vector3(hw, y, hd), 0.0)
	piece(parent, "Corner_Exterior_Brick", Vector3(hw, y, -hd), 90.0)
	piece(parent, "Corner_Exterior_Brick", Vector3(-hw, y, -hd), 180.0)
	piece(parent, "Corner_Exterior_Brick", Vector3(-hw, y, hd), -90.0)


## One side of a building: wall pieces centred on `centre`, outer face toward `facing_deg`
## (0 = +Z, 90 = +X, 180 = -Z, -90 = -X). Window openings get frames, and either a warm
## glow behind them (lit) or closed shutters.
static func _side(parent: Node3D, pieces: PackedStringArray, centre: Vector3, facing_deg: float,
		lit: bool, glow: Color) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(facing_deg))
	var start := -MODULE * (pieces.size() - 1) * 0.5
	for i: int in pieces.size():
		var pos := centre + basis * Vector3(start + MODULE * i, 0, 0)
		piece(parent, pieces[i], pos, facing_deg)
		var wide := pieces[i].contains("Window_Wide")
		if not wide and not pieces[i].contains("Window_Thin"):
			continue
		piece(parent, "Window_Wide_Flat1" if wide else "Window_Thin_Round1", pos, facing_deg)
		if lit:
			var pane := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(1.5, 1.5) if wide else Vector2(0.8, 1.55)
			pane.mesh = quad
			pane.material_override = _glow(glow)
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pane.position = pos + basis * Vector3(0, 1.75 if wide else 1.82, -0.24)
			pane.rotation_degrees.y = facing_deg
			parent.add_child(pane)
		else:
			piece(parent, "WindowShutters_Wide_Flat_Closed" if wide else "WindowShutters_Thin_Round_Closed", pos, facing_deg)


static func _glow(color: Color) -> StandardMaterial3D:
	if not _glow_materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.5
		_glow_materials[color] = mat
	return _glow_materials[color]


## Darkens the kit's shared materials once (see CharacterModel for why not per instance).
static func _mute(node: Node, tint: Color) -> void:
	var mesh := node as MeshInstance3D
	if mesh:
		for i: int in mesh.get_surface_override_material_count():
			var mat := mesh.get_active_material(i) as StandardMaterial3D
			if mat == null or mat.has_meta(&"muted"):
				continue
			mat.set_meta(&"muted", true)
			var is_roof := mat.albedo_texture != null and mat.albedo_texture.resource_path.contains("RoundTiles")
			mat.albedo_color *= ROOF_TINT if is_roof else tint
	for child: Node in node.get_children():
		_mute(child, tint)
