class_name ForestZone
extends Node3D
## The forest behind the church: herbs to gather, cover to hide in, and the elder's
## watchmen patrolling it (more each day). Mara slips in through a gap in the fence;
## the trip costs a time slot. Getting caught sends her back without her herbs.

const AREA := Rect2(-26.0, -66.0, 52.0, 29.0)  # x, z, width, depth
const ENTRY_VILLAGE := Vector3(7.0, 0.0, -30.6)
const ENTRY_FOREST := Vector3(7.0, 0.0, -38.6)
const FENCE_Z := -32.4
const NATURE := "res://resources/models/nature/"
const GUARD_SCENE: PackedScene = preload("res://scenes/guard.tscn")
const HERB_GLOW := Color(0.75, 0.95, 0.6)

## Herb spots: position (x, z) and herb index into GameConfig.herb_ids.
const HERB_SPOTS: Array[Vector3] = [
	Vector3(-18.0, -40.5, 0), Vector3(18.5, -41.0, 1), Vector3(-8.0, -47.0, 2),
	Vector3(6.5, -46.5, 0), Vector3(-21.0, -56.0, 1), Vector3(21.0, -56.5, 2),
	Vector3(-3.0, -54.0, 0), Vector3(12.0, -62.0, 1), Vector3(-12.0, -63.5, 2),
	Vector3(0.5, -63.0, 0), Vector3(15.5, -47.5, 1), Vector3(-22.5, -47.5, 2),
]
## Patrol loops; guard N walks ROUTES[N]. Built with explicit PackedVector3Array
## constructors: a nested literal in a typed const array does not convert reliably.
static var ROUTES: Array[PackedVector3Array] = [
	PackedVector3Array([Vector3(-13, 0, -42), Vector3(13, 0, -42), Vector3(13, 0, -50), Vector3(-13, 0, -50)]),
	PackedVector3Array([Vector3(-19, 0, -53), Vector3(-5, 0, -60), Vector3(10, 0, -59), Vector3(19, 0, -51), Vector3(4, 0, -53)]),
	PackedVector3Array([Vector3(1, 0, -44), Vector3(1, 0, -62), Vector3(-17, 0, -62), Vector3(-17, 0, -45)]),
]
## Tall grass and thickets to hide in: x, z, radius.
const COVER: Array[Vector3] = [
	Vector3(-15.0, -45.0, 2.2), Vector3(10.0, -44.5, 2.0), Vector3(-2.0, -49.5, 2.4),
	Vector3(16.0, -54.0, 2.2), Vector3(-10.0, -57.0, 2.3), Vector3(6.0, -61.5, 2.0),
	Vector3(-21.0, -60.0, 2.0), Vector3(22.0, -45.0, 1.8),
]

var _terrain: Terrain
var _rng := RandomNumberGenerator.new()
var _herbs: Dictionary[String, Node3D] = {}
var _guards: Array[Guard] = []
var _guards_day: int = 0


func _ready() -> void:
	_rng.seed = 909
	_terrain = get_tree().get_first_node_in_group(&"terrain") as Terrain
	_build_fence_and_passage()
	_build_walls()
	_build_cover()
	_build_trees()
	_build_herbs()
	_spawn_guards_for_today()
	GameState.time_changed.connect(_on_time_changed)


func _on_time_changed() -> void:
	_refresh_herbs()
	if GameState.day != _guards_day:
		_spawn_guards_for_today()


## More watchmen each day (GameConfig.forest_guards_per_day).
func _spawn_guards_for_today() -> void:
	for guard: Guard in _guards:
		guard.queue_free()
	_guards.clear()
	_guards_day = GameState.day
	var per_day := GameState.config.forest_guards_per_day
	_spawn_guards(per_day[clampi(GameState.day - 1, 0, per_day.size() - 1)])


func _on_enter() -> void:
	if GameState.slots_left <= 0:
		GameState.notified.emit("День на исходе — в лес уже поздно")
		return
	GameState.spend_slot()
	GameState.in_forest = true
	await _move_player(ENTRY_FOREST, Vector3.FORWARD, PackedStringArray())
	GameState.notified.emit("Лес. Дозорных: %d" % _guards.size())


func _on_leave() -> void:
	GameState.in_forest = false
	await _move_player(ENTRY_VILLAGE, Vector3.BACK, PackedStringArray())


func _on_caught() -> void:
	if not GameState.in_forest:
		return
	GameState.register_caught()
	GameState.in_forest = false
	await _move_player(ENTRY_VILLAGE, Vector3.BACK,
			PackedStringArray(["Поймали", "Дозорный вывел Мару из леса и забрал травы."]))


func _move_player(point: Vector3, facing: Vector3, card: PackedStringArray) -> void:
	GameState.lock_controls()
	if card.is_empty():
		await Transition.fade_out(0.6)
	else:
		await Transition.card(card, 1.2)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	player.call(&"teleport", _on_ground(point), facing)
	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig:
		rig.call(&"snap_behind_target")
	await Transition.fade_in(0.6)
	GameState.unlock_controls()


func _build_fence_and_passage() -> void:
	var x := AREA.position.x
	while x < AREA.end.x:
		if absf(x - ENTRY_VILLAGE.x) > 1.6:
			KitBuilder.piece(self, "Prop_WoodenFence_Single", _on_ground(Vector3(x + 1.0, 0.0, FENCE_Z)), _rng.randf_range(-4.0, 4.0))
		x += 2.05
	var enter := _interactable("Пробраться в лес  ·  1 действие", _on_ground(ENTRY_VILLAGE + Vector3(0, 0.9, -0.8)))
	enter.interacted.connect(_on_enter)
	var leave := _interactable("Вернуться в деревню", _on_ground(ENTRY_FOREST + Vector3(0, 0.9, 0.8)))
	leave.interacted.connect(_on_leave)


func _build_walls() -> void:
	var centre := AREA.get_center()
	Build.static_box(self, Vector3(1.0, 14.0, AREA.size.y + 2.0), Vector3(AREA.position.x - 1.0, 4.0, centre.y))
	Build.static_box(self, Vector3(1.0, 14.0, AREA.size.y + 2.0), Vector3(AREA.end.x + 1.0, 4.0, centre.y))
	Build.static_box(self, Vector3(AREA.size.x + 2.0, 14.0, 1.0), Vector3(centre.x, 4.0, AREA.position.y - 1.0))


func _build_cover() -> void:
	var tall := _nature_mesh("Grass_Common_Tall")
	var wispy := _nature_mesh("Grass_Wispy_Tall")
	for c: Vector3 in COVER:
		var zone := HideZone.new()
		zone.concealment = 0.75
		zone.size = Vector3(c.z * 2.0, 1.6, c.z * 2.0)
		zone.position = _on_ground(Vector3(c.x, 0.0, c.y))
		add_child(zone)
		var blades: Array[Transform3D] = []
		for i: int in 70:
			var offset := Vector2(_rng.randf_range(-c.z, c.z), _rng.randf_range(-c.z, c.z))
			var p := Vector3(c.x + offset.x, 0.0, c.y + offset.y)
			blades.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.15)), _on_ground(p)))
		_multimesh(tall if _rng.randf() < 0.5 else wispy, blades)
		var bush := KitBuilder.instance_of(NATURE + "Bush_Common.gltf")
		bush.position = _on_ground(Vector3(c.x + c.z * 0.6, 0.0, c.y - c.z * 0.4))
		bush.scale = Vector3.ONE * 1.3
		add_child(bush)


func _build_trees() -> void:
	var placed := 0
	var attempts := 0
	while placed < 70 and attempts < 3000:
		attempts += 1
		var p := Vector2(_rng.randf_range(AREA.position.x, AREA.end.x), _rng.randf_range(AREA.position.y, AREA.end.y))
		if _near_route(p, 2.2) or _near_spot(p, 2.0) or p.distance_to(Vector2(ENTRY_FOREST.x, ENTRY_FOREST.z)) < 4.0:
			continue
		var dead := _rng.randf() < 0.3
		var model := ("DeadTree_%d" if dead else "Pine_%d") % _rng.randi_range(1, 5)
		var tree := KitBuilder.instance_of(NATURE + model + ".gltf")
		tree.position = _on_ground(Vector3(p.x, -0.1, p.y))
		tree.rotation.y = _rng.randf() * TAU
		tree.scale = Vector3.ONE * _rng.randf_range(0.75, 1.2) * (0.8 if dead else 1.0)
		add_child(tree)
		Build.static_cylinder(tree, 0.35, 3.0, Vector3(0.0, 1.5, 0.0))
		placed += 1


func _build_herbs() -> void:
	for i: int in HERB_SPOTS.size():
		var spot := HERB_SPOTS[i]
		var id := "forest_%d" % i
		var herb_id: String = GameState.config.herb_ids[int(spot.z)]
		var root := Node3D.new()
		root.position = _on_ground(Vector3(spot.x, 0.0, spot.y))
		add_child(root)
		var plant := KitBuilder.instance_of(NATURE + "Fern_1.gltf")
		plant.scale = Vector3.ONE * 0.12
		root.add_child(plant)
		var glow := OmniLight3D.new()
		glow.light_color = HERB_GLOW
		glow.light_energy = 0.6
		glow.omni_range = 2.2
		glow.position = Vector3(0.0, 0.5, 0.0)
		root.add_child(glow)
		Effects.glints(root, Vector3(0.0, 0.4, 0.0), HERB_GLOW)
		var pick := Interactable.new()
		pick.prompt = "Сорвать: %s" % GameState.herb_name(herb_id)
		pick.position = Vector3(0.0, 0.6, 0.0)
		root.add_child(pick)
		pick.interacted.connect(func() -> void:
			GameState.add_herb(herb_id, id)
			_refresh_herbs())
		_herbs[id] = root
	_refresh_herbs()


func _refresh_herbs() -> void:
	for id: String in _herbs:
		var picked := GameState.picked_spots.has(id)
		var root := _herbs[id]
		root.visible = not picked
		for child: Node in root.get_children():
			if child is Interactable:
				(child as Interactable).enabled = not picked


func _spawn_guards(count: int) -> void:
	for i: int in mini(count, ROUTES.size()):
		var guard := GUARD_SCENE.instantiate() as Guard
		var route := PackedVector3Array()
		for point: Vector3 in ROUTES[i]:
			route.append(_on_ground(point))
		guard.route = route
		guard.position = route[0]
		add_child(guard)
		guard.caught_player.connect(_on_caught)
		_guards.append(guard)


func _interactable(prompt: String, pos: Vector3) -> Interactable:
	var it := Interactable.new()
	it.prompt = prompt
	it.radius = 1.2
	it.position = pos
	add_child(it)
	return it


func _near_route(p: Vector2, distance: float) -> bool:
	for route: PackedVector3Array in ROUTES:
		for i: int in route.size():
			var a := Vector2(route[i].x, route[i].z)
			var b := Vector2(route[(i + 1) % route.size()].x, route[(i + 1) % route.size()].z)
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < distance:
				return true
	return false


func _near_spot(p: Vector2, distance: float) -> bool:
	for spot: Vector3 in HERB_SPOTS:
		if p.distance_to(Vector2(spot.x, spot.y)) < distance:
			return true
	for c: Vector3 in COVER:
		if p.distance_to(Vector2(c.x, c.y)) < c.z:
			return true
	return false


func _on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, p.y + (_terrain.height_at(p.x, p.z) if _terrain else 0.0), p.z)


func _nature_mesh(model: String) -> Mesh:
	var scene := KitBuilder.instance_of(NATURE + model + ".gltf")
	var mesh := (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	scene.free()
	return mesh


func _multimesh(mesh: Mesh, transforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i: int in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
