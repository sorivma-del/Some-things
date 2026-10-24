class_name OpenWorld
extends Node3D
## "Земли за Бродом": the land outside the village gate. Builds the terrain, the river
## with its bridge and ford, forests (in chunks that stop drawing beyond the fog), the
## places Mara can find, campfires to rest at, and the barred gate behind her. Tracks
## which places have been discovered. Numbers: resources/world/world_config.tres.

const CONFIG: WorldConfig = preload("res://resources/world/world_config.tres")
const NATURE := "res://resources/models/nature/"
const CAMPFIRE: PackedScene = preload("res://scenes/campfire.tscn")
const PEDDLER: PackedScene = preload("res://scenes/merchants/peddler.tscn")
const HERMIT: PackedScene = preload("res://scenes/world/hermit.tscn")
const MILLER: PackedScene = preload("res://scenes/world/miller.tscn")
const HORSE: PackedScene = preload("res://scenes/world/horse.tscn")
## Where the horse waits, tied at the crossroads, until Mara first rides it.
const HORSE_START := Vector2(6.0, 86.0)
const CHUNK := 75.0
const START := Vector3(0.0, 0.0, 9.0)

## id -> name, position (x, z), discovery radius, clearing radius (0 = none), campfire.
const PLACES: Dictionary[String, Dictionary] = {
	"gate": {"name": "Ворота Серого Брода", "pos": Vector2(0, 6), "radius": 18.0, "flat": 14.0, "fire": false},
	"crossroads": {"name": "Перекрёсток", "pos": Vector2(0, 90), "radius": 16.0, "flat": 12.0, "fire": true},
	"farm": {"name": "Заброшенная ферма", "pos": Vector2(-110, 72), "radius": 24.0, "flat": 18.0, "fire": false},
	"graveyard": {"name": "Старое кладбище", "pos": Vector2(-80, 145), "radius": 22.0, "flat": 16.0, "fire": false},
	"camp": {"name": "Лагерь разбойников", "pos": Vector2(125, 135), "radius": 24.0, "flat": 18.0, "fire": false},
	"mill": {"name": "Старая мельница", "pos": Vector2(-55, 196), "radius": 20.0, "flat": 14.0, "fire": true},
	"bridge": {"name": "Старый мост", "pos": Vector2(40, 235), "radius": 18.0, "flat": 0.0, "fire": false},
	"ford": {"name": "Брод", "pos": Vector2(-100, 218), "radius": 16.0, "flat": 0.0, "fire": false},
	"rest": {"name": "Привал за мостом", "pos": Vector2(50, 266), "radius": 12.0, "flat": 9.0, "fire": true},
	"tower": {"name": "Сторожевая башня", "pos": Vector2(-150, 412), "radius": 22.0, "flat": 16.0, "fire": false},
	"hermit": {"name": "Хижина отшельника", "pos": Vector2(70, 330), "radius": 20.0, "flat": 16.0, "fire": true},
	"wolf_woods": {"name": "Волчий лог", "pos": Vector2(170, 60), "radius": 35.0, "flat": 0.0, "fire": false},
	"dark_woods": {"name": "Тёмный ельник", "pos": Vector2(-190, 330), "radius": 35.0, "flat": 0.0, "fire": false},
}

var terrain: WorldTerrain
var _map_texture: ImageTexture
## Mara's lantern: lit after dark, out in the open there is no other light.
var _lantern := OmniLight3D.new()
var _rng := RandomNumberGenerator.new()
var _discover_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"open_world")
	add_to_group(&"save_hooks")
	_rng.seed = 5150
	GameState.world_mode = true
	add_child(WorldClock.new())
	_build_terrain()
	_build_gate()
	_build_bridge()
	_build_river_banks()
	_build_bounds()
	_build_places()
	_build_forests()
	_place_horse()
	var encounters := WorldEncounters.new()
	encounters.name = "Encounters"
	add_child(encounters)
	add_child(WorldActivity.new())
	get_tree().call_group(&"world_lighting", &"set_fog_scale", CONFIG.fog_scale)
	_arrive.call_deferred()
	_hang_lantern.call_deferred()


func _process(delta: float) -> void:
	_discover_timer -= delta
	if _discover_timer > 0.0:
		return
	_discover_timer = 0.5
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var p := Vector2(player.global_position.x, player.global_position.z)
	for id: String in PLACES:
		var place: Dictionary = PLACES[id]
		if not GameState.discovered.has(id) and p.distance_to(place["pos"]) < float(place["radius"]):
			GameState.discover(id, place["name"])


## Mara steps out of the gate (or wakes where the save left her) and the title shows.
func _arrive() -> void:
	GameState.lock_controls()
	Transition.black()
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var first_time := not GameState.has_world_position
	var spot := GameState.world_position if not first_time else ground(START.x, START.z)
	player.call(&"teleport", spot + Vector3.UP * 0.2, Vector3(0, 0, 1))
	get_tree().call_group(&"camera_rig", &"snap_behind_target")
	if first_time:
		await Transition.card(PackedStringArray(["Глава вторая", "Земли за Бродом", "Ворота закрылись за спиной. Отшельник живёт за рекой."]), 2.0)
	else:
		await Transition.card(PackedStringArray(["День %d" % GameState.world_day, "Земли за Бродом"]), 1.0)
	await Transition.fade_in(1.2)
	GameState.unlock_controls()
	if first_time:
		GameState.save_game()


func _hang_lantern() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	_lantern.light_color = Color(1.0, 0.7, 0.4)
	_lantern.light_energy = 1.4
	_lantern.omni_range = 9.0
	_lantern.shadow_enabled = false
	_lantern.position = Vector3(0.4, 1.3, 0.3)
	player.add_child(_lantern)
	GameState.time_changed.connect(_update_lantern)
	_update_lantern()


func _update_lantern() -> void:
	_lantern.visible = GameState.world_period() == "night"


## Called by GameState.save_game(): where Mara and the horse are.
func before_save() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player:
		var anchor: Node3D = player.get(&"mount") if player.get(&"mount") else player
		GameState.world_position = anchor.global_position
		GameState.has_world_position = true
	var horse := get_tree().get_first_node_in_group(Horse.GROUP) as Node3D
	if horse:
		GameState.horse_position = horse.global_position
		GameState.has_horse_position = true


## A point on the ground at (x, z).
func ground(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.height_at(x, z), z)


func place_position(id: String) -> Vector3:
	var p: Vector2 = PLACES[id]["pos"]
	return ground(p.x, p.y)


## Where Mara stands when she arrives at a campfire (fast travel, waking up).
func campfire_spot(id: String) -> Vector3:
	var p: Vector2 = PLACES[id]["pos"]
	return ground(p.x + 2.5, p.y + 2.5)


## The parchment map, drawn from the terrain the first time it is needed.
func map_texture() -> ImageTexture:
	if _map_texture == null:
		_map_texture = ImageTexture.create_from_image(terrain.make_map_image())
	return _map_texture


## Discovered places with a campfire (fast-travel destinations).
func travel_destinations() -> PackedStringArray:
	var result: PackedStringArray = []
	for id: String in PLACES:
		if PLACES[id]["fire"] and GameState.discovered.has(id):
			result.append(id)
	return result


## Game hours a trip from where Mara stands to `id` takes.
func travel_hours(id: String) -> float:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var distance := player.global_position.distance_to(place_position(id))
	return snappedf(distance / 100.0 * CONFIG.fast_travel_hours_per_100m, 0.1)


## Why Mara cannot travel right now ("" if she can).
func travel_blocker() -> String:
	if GameState.controls_locked and not get_tree().get_nodes_in_group(&"map_window").any(func(w: Node) -> bool: return w.get(&"is_open")):
		return "Сейчас не время"
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if not enemy.dead and enemy.state != Enemy.State.CALM \
				and enemy.global_position.distance_to(player.global_position) < CONFIG.fast_travel_safe_distance:
			return "Рядом враги"
	return ""


## Fast travel to a discovered campfire: time passes by distance; the horse comes along.
func fast_travel(id: String) -> void:
	if not travel_blocker().is_empty() or not travel_destinations().has(id):
		return
	var hours := travel_hours(id)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var horse := get_tree().get_first_node_in_group(Horse.GROUP) as Horse
	if horse and horse.is_ridden():
		horse.dismount()
	GameState.lock_controls()
	await Transition.fade_out(0.6)
	get_tree().call_group(&"world_clock", &"advance", hours)
	var spot := campfire_spot(id)
	player.call(&"teleport", spot + Vector3.UP * 0.3, Vector3(0, 0, 1))
	if horse and horse.is_owned():
		horse.global_position = spot + Vector3(3.5, 0.5, -2.0)
		horse.velocity = Vector3.ZERO
	get_tree().call_group(&"camera_rig", &"snap_behind_target")
	await Transition.card(PackedStringArray([PLACES[id]["name"], "Дорога заняла %s" % _hours_text(hours)]), 1.0)
	await Transition.fade_in(0.6)
	GameState.unlock_controls()


static func _hours_text(hours: float) -> String:
	if hours < 1.0:
		return "меньше часа"
	var h := roundi(hours)
	return "%d %s" % [h, "час" if h % 10 == 1 and h % 100 != 11 else "часа" if h % 10 in [2, 3, 4] and not h % 100 in [12, 13, 14] else "часов"]


#region Ground, river, edges

func _build_terrain() -> void:
	terrain = WorldTerrain.new()
	for id: String in PLACES:
		var place: Dictionary = PLACES[id]
		if float(place["flat"]) > 0.0:
			var p: Vector2 = place["pos"]
			terrain.flat_spots.append(Vector3(p.x, p.y, place["flat"]))
	add_child(terrain)
	terrain.build()


func _build_bridge() -> void:
	var x := WorldTerrain.BRIDGE_X
	var centre := WorldTerrain.river_z(x)
	var length := (WorldTerrain.RIVER_HALF_WIDTH + 9.0) * 2.0
	var deck := Build.bark_material(Color(0.42, 0.34, 0.27))
	var z0 := centre - length * 0.5
	var z1 := centre + length * 0.5
	var y0 := terrain.height_at(x, z0)
	var y1 := terrain.height_at(x, z1)
	var deck_y := maxf(maxf(y0, y1), WorldTerrain.WATER_LEVEL + 0.6) + 0.15
	var body := Build.static_box(self, Vector3(4.2, 0.3, length), Vector3(x, deck_y, centre))
	Build.box(body, Vector3(4.2, 0.3, length), Vector3.ZERO, deck)
	for side: float in [-2.0, 2.0]:
		var rail := Build.static_box(self, Vector3(0.2, 1.0, length), Vector3(x + side, deck_y + 0.6, centre))
		Build.box(rail, Vector3(0.2, 0.15, length), Vector3(0, 0.4, 0), deck)
		var z := z0 + 2.0
		while z < z1:
			Build.cylinder(self, 0.12, 4.0, Vector3(x + side, deck_y - 1.4, z), deck)
			z += 4.0
	# Ramps from the banks up to the deck.
	for end: Vector2 in [Vector2(z0, -1.0), Vector2(z1, 1.0)]:
		var ground_y := terrain.height_at(x, end.x + end.y * 3.0)
		var rise := deck_y - ground_y
		if rise > 0.05:
			var ramp := Build.static_box(self, Vector3(4.2, 0.3, 6.5), Vector3(x, ground_y + rise * 0.5, end.x + end.y * 3.0))
			ramp.rotation.x = -atan2(rise, 6.0) * end.y
			Build.box(ramp, Vector3(4.2, 0.3, 6.5), Vector3.ZERO, deck)


## Invisible banks keep Mara out of deep water, except at the ford and the bridge.
func _build_river_banks() -> void:
	var x := -WorldTerrain.HALF_WIDTH
	while x < WorldTerrain.HALF_WIDTH:
		var mid := x + 3.0
		var near_bridge := absf(mid - WorldTerrain.BRIDGE_X) < 4.0
		var near_ford := absf(mid - WorldTerrain.FORD_X) < 9.0
		if not near_bridge and not near_ford:
			for side: float in [-1.0, 1.0]:
				var z := WorldTerrain.river_z(mid) + side * (WorldTerrain.RIVER_HALF_WIDTH - 1.5)
				var wall := Build.static_box(self, Vector3(6.4, 4.0, 0.6), Vector3(mid, WorldTerrain.WATER_LEVEL + 1.0, z))
				wall.rotation.y = -atan(cos(mid / 55.0) * 10.0 / 55.0)
		x += 6.0


func _build_bounds() -> void:
	var w := WorldTerrain.HALF_WIDTH - 22.0
	var z0 := WorldTerrain.Z_MIN + 18.0
	var z1 := WorldTerrain.Z_MIN + WorldTerrain.DEPTH - 22.0
	var mid := (z0 + z1) * 0.5
	Build.static_box(self, Vector3(1.0, 80.0, z1 - z0), Vector3(-w, 20.0, mid))
	Build.static_box(self, Vector3(1.0, 80.0, z1 - z0), Vector3(w, 20.0, mid))
	Build.static_box(self, Vector3(w * 2.0, 80.0, 1.0), Vector3(0.0, 20.0, z1))
	Build.static_box(self, Vector3(w * 2.0, 80.0, 1.0), Vector3(0.0, 20.0, z0))

#endregion


#region Places

func _build_places() -> void:
	for id: String in PLACES:
		if PLACES[id]["fire"]:
			_build_campfire(id)
	_build_farm()
	_build_graveyard()
	_build_camp()
	_build_mill()
	_build_tower()
	_build_hermit()


## The village palisade with the barred gate: there is no way back.
func _build_gate() -> void:
	var z := -1.5
	var x := -70.0
	while x <= 70.0:
		if absf(x) > 2.8:
			var post := Build.cylinder(self, 0.28, 4.6, ground(x, z) + Vector3(0, 2.0, 0), Build.bark_material(Color(0.5, 0.42, 0.35), Vector3(x, 0, 0)))
			post.rotation.z = _rng.randf_range(-0.03, 0.03)
		x += 0.6
	Build.static_box(self, Vector3(140.0, 6.0, 0.8), Vector3(0.0, 2.0, z))
	var doors := Build.bark_material(Color(0.4, 0.33, 0.27))
	for side: float in [-1.0, 1.0]:
		Build.box(self, Vector3(2.7, 3.8, 0.25), ground(side * 1.4, z) + Vector3(0, 1.9, 0), doors)
	Build.box(self, Vector3(5.8, 0.25, 0.3), ground(0, z + 0.2) + Vector3(0, 2.4, 0), doors)
	var knock := Interactable.new()
	knock.prompt = "Постучать в ворота"
	knock.position = ground(0.0, z + 1.0) + Vector3(0, 1.0, 0)
	add_child(knock)
	knock.interacted.connect(func() -> void: GameState.notified.emit("Ворота заложены изнутри. Назад дороги нет."))


func _build_campfire(id: String) -> void:
	var fire := CAMPFIRE.instantiate() as Node3D
	fire.position = place_position(id)
	add_child(fire)
	var respawn := RespawnPoint.new()
	respawn.radius = 4.0
	respawn.message = ""
	fire.add_child(respawn)
	var rest := Interactable.new()
	rest.prompt = "Отдохнуть у костра"
	rest.radius = 1.6
	rest.position = Vector3(0, 0.8, 0)
	fire.add_child(rest)
	rest.interacted.connect(_rest_at.bind(id))
	fire.add_to_group(&"world_campfires")
	fire.set_meta(&"place", id)


func _rest_at(id: String) -> void:
	get_tree().call_group(&"world_clock", &"rest", id)


func _house(id: String, offset: Vector2, depth: int, lit: bool, face: Vector2) -> Node3D:
	var p: Vector2 = PLACES[id]["pos"] + offset
	var house := KitBuilder.house(self, depth, lit)
	house.position = ground(p.x, p.y) - Vector3(0, 0.1, 0)
	house.rotation.y = atan2(face.x - p.x, face.y - p.y)
	if lit:
		Effects.smoke(house, Vector3(1.6, 7.7, -depth + 1.5))
	return house


func _prop(piece: String, at: Vector2, rotation_deg: float = 0.0) -> Node3D:
	return KitBuilder.piece(self, piece, ground(at.x, at.y), rotation_deg)


func _build_farm() -> void:
	var c: Vector2 = PLACES["farm"]["pos"]
	_house("farm", Vector2(-6, -4), 3, false, c + Vector2(10, 6))
	_prop("Prop_Wagon", c + Vector2(6, 4), 30.0)
	_prop("Prop_Crate", c + Vector2(3, -6), 10.0)
	_prop("Prop_Crate", c + Vector2(4, -5), 40.0)
	for i: int in 9:
		_prop("Prop_WoodenFence_Single", c + Vector2(-12 + i * 2.05, 11), 0.0)


func _build_graveyard() -> void:
	var c: Vector2 = PLACES["graveyard"]["pos"]
	for row: int in 4:
		for col: int in 5:
			if _rng.randf() < 0.2:
				continue
			var stone := KitBuilder.instance_of(NATURE + "Rock_Medium_%d.gltf" % _rng.randi_range(1, 3))
			stone.position = ground(c.x - 8 + col * 4.0, c.y - 6 + row * 4.0)
			stone.scale = Vector3(0.35, _rng.randf_range(0.7, 1.0), 0.18)
			stone.rotation.y = _rng.randf_range(-0.2, 0.2)
			add_child(stone)
	for i: int in 5:
		var tree := KitBuilder.instance_of(NATURE + "DeadTree_%d.gltf" % _rng.randi_range(1, 5))
		var a := TAU * i / 5.0
		tree.position = ground(c.x + cos(a) * 14.0, c.y + sin(a) * 14.0)
		add_child(tree)
		Build.static_cylinder(tree, 0.35, 3.0, Vector3(0, 1.5, 0))


func _build_camp() -> void:
	var c: Vector2 = PLACES["camp"]["pos"]
	var fire := CAMPFIRE.instantiate() as Node3D
	fire.position = ground(c.x, c.y)
	add_child(fire)
	_prop("Prop_Wagon", c + Vector2(-7, -3), 70.0)
	for i: int in 4:
		_prop("Prop_Crate", c + Vector2(5 + (i % 2) * 1.2, -5 + i * 0.9), i * 25.0)
	for i: int in 12:
		var a := deg_to_rad(200.0 + i * 12.0)
		_prop("Prop_WoodenFence_Single", c + Vector2(cos(a), sin(a)) * 13.0, -rad_to_deg(a) + 90.0)


func _build_mill() -> void:
	var c: Vector2 = PLACES["mill"]["pos"]
	_house("mill", Vector2(-7, -6), 4, true, c)
	var sava := PEDDLER.instantiate() as Node3D
	sava.position = ground(c.x + 6, c.y - 4)
	sava.rotation.y = atan2(-6.0, 4.0)
	add_child(sava)
	var miller := MILLER.instantiate() as WorldResident
	miller.position = ground(miller.data.home.x, miller.data.home.y) + Vector3.UP * 0.2
	add_child(miller)


## A ruined square watchtower, 2 x 2 modules: three storeys of bare brick, no roof.
func _build_tower() -> void:
	var c: Vector2 = PLACES["tower"]["pos"]
	var tower := Node3D.new()
	tower.position = ground(c.x - 6, c.y - 6)
	add_child(tower)
	var half := KitBuilder.MODULE
	for level: int in 3:
		var y := level * KitBuilder.WALL_HEIGHT
		for side: int in 4:
			var angle := side * 90.0
			var centre := Vector3(0, y, half).rotated(Vector3.UP, deg_to_rad(angle))
			var pieces: PackedStringArray = ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Window_Thin_Round"]
			if level == 0 and side == 0:
				pieces = ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Door_Round"]
			KitBuilder._side(tower, pieces, centre, angle, false, Color.BLACK)
		for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			KitBuilder.piece(tower, "Corner_Exterior_Brick", Vector3(corner.x * half, y, corner.y * half))
	Build.static_box(tower, Vector3(half * 2.0, KitBuilder.WALL_HEIGHT * 3.0, half * 2.0), Vector3(0, KitBuilder.WALL_HEIGHT * 1.5, 0))


func _build_hermit() -> void:
	var c: Vector2 = PLACES["hermit"]["pos"]
	_house("hermit", Vector2(-2, -9), 3, true, c + Vector2(-2, 0))
	var hermit := HERMIT.instantiate() as Node3D
	hermit.position = ground(c.x - 3.5, c.y - 1.0)
	add_child(hermit)

#endregion


func _place_horse() -> void:
	var horse := HORSE.instantiate() as Node3D
	horse.position = GameState.horse_position if GameState.has_horse_position else ground(HORSE_START.x, HORSE_START.y) + Vector3.UP * 0.3
	horse.rotation.y = PI * 0.5
	add_child(horse)


#region Forests

## Trees and rocks where the forest noise is thick, off roads, water and places,
## grouped in chunks so far-away chunks are not drawn at all.
func _build_forests() -> void:
	var chunks: Dictionary[Vector2i, Dictionary] = {}
	var spacing := 6.5
	var z := WorldTerrain.Z_MIN + 20.0
	while z < WorldTerrain.Z_MIN + WorldTerrain.DEPTH - 20.0:
		var x := -WorldTerrain.HALF_WIDTH + 20.0
		while x < WorldTerrain.HALF_WIDTH - 20.0:
			var p := Vector2(x + _rng.randf_range(-2.5, 2.5), z + _rng.randf_range(-2.5, 2.5))
			x += spacing
			var model := _tree_at(p)
			if model.is_empty():
				continue
			var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
			if not chunks.has(key):
				chunks[key] = {}
			var per_model: Dictionary = chunks[key]
			if not per_model.has(model):
				per_model[model] = []
			var size := _rng.randf_range(0.8, 1.3)
			(per_model[model] as Array).append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size), ground(p.x, p.y) - Vector3(0, 0.1, 0)))
		z += spacing
	var meshes: Dictionary[String, Mesh] = {}
	for key: Vector2i in chunks:
		var centre := Vector3((key.x + 0.5) * CHUNK, 0.0, (key.y + 0.5) * CHUNK)
		var chunk := Node3D.new()
		chunk.position = centre
		add_child(chunk)
		var body := StaticBody3D.new()
		chunk.add_child(body)
		var per_model: Dictionary = chunks[key]
		for model: String in per_model:
			if not meshes.has(model):
				meshes[model] = _nature_mesh(model)
			var transforms: Array = per_model[model]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = meshes[model]
			mm.instance_count = transforms.size()
			for i: int in transforms.size():
				var t: Transform3D = transforms[i]
				t.origin -= centre
				mm.set_instance_transform(i, t)
				if not model.begins_with("Rock") or t.basis.get_scale().x > 1.0:
					var trunk := CollisionShape3D.new()
					var cylinder := CylinderShape3D.new()
					cylinder.radius = 0.4 if model.begins_with("Rock") else 0.3
					cylinder.height = 3.0
					trunk.shape = cylinder
					trunk.position = t.origin + Vector3(0, 1.5, 0)
					body.add_child(trunk)
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = mm
			instance.visibility_range_end = CONFIG.draw_distance
			instance.visibility_range_end_margin = 10.0
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if model.begins_with("Pine") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk.add_child(instance)


## Which model grows at `p`, or "" for open ground.
func _tree_at(p: Vector2) -> String:
	if not terrain.is_inside(p.x, p.y, 25.0) or p.y < 12.0:
		return ""
	if terrain.road_distance(p.x, p.y) < 5.0 or terrain.is_in_river(p.x, p.y, 6.0):
		return ""
	for id: String in PLACES:
		if float(PLACES[id]["flat"]) > 0.0 and p.distance_to(PLACES[id]["pos"]) < float(PLACES[id]["flat"]) + 4.0:
			return ""
	var forest := terrain.forest_weight(p.x, p.y)
	var roll := _rng.randf()
	if forest > 0.5 and roll < 0.9 or forest > 0.35 and roll < 0.35:
		return ("DeadTree_%d" if roll < 0.08 else "Pine_%d") % _rng.randi_range(1, 5)
	if roll < 0.025:
		return "Rock_Medium_%d" % _rng.randi_range(1, 3)
	if roll < 0.04:
		return "DeadTree_%d" % _rng.randi_range(1, 5)
	return ""


func _nature_mesh(model: String) -> Mesh:
	var scene := KitBuilder.instance_of(NATURE + model + ".gltf")
	var mesh := (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	scene.free()
	return mesh

#endregion
