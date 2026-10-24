extends SceneTree
## Проверка отсечения земли, пробуждения дальних актёров и расписания мельника.

class TestTerrain extends WorldTerrain:
	func _make_material() -> ShaderMaterial:
		return ShaderMaterial.new()

const CONFIG: WorldConfig = preload("res://resources/world/world_config.tres")

var gs: Node
var failures: int = 0


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["OK  " if ok else "FAIL", label])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	gs = root.get_node(^"GameState")
	_test_terrain()
	_test_resident()
	_test_freed_encounter()
	await _test_activity()
	print("world_performance test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _test_terrain() -> void:
	var terrain := TestTerrain.new()
	root.add_child(terrain)
	terrain.build()
	var chunks := terrain.get_node(^"TerrainChunks")
	var cells := maxi(1, CONFIG.terrain_chunk_cells)
	var side := ceili(WorldTerrain.DEPTH / WorldTerrain.STEP / cells)
	_check("Земля разделена на участки, включая неполный край", chunks.get_child_count() == side * side)
	var triangle_count: int = 0
	var material: Material = (chunks.get_child(0) as MeshInstance3D).material_override
	var shared_material: bool = true
	var edges: Dictionary[Vector2, Vector3] = {}
	var seamless: bool = true
	var duplicates: int = 0
	for node: Node in chunks.get_children():
		var instance := node as MeshInstance3D
		shared_material = shared_material and instance.material_override == material
		var arrays := instance.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		triangle_count += int(indices.size() / 3)
		for i: int in vertices.size():
			var key := Vector2(vertices[i].x, vertices[i].z)
			if edges.has(key):
				duplicates += 1
				seamless = seamless and normals[i].is_equal_approx(edges[key])
			else:
				edges[key] = normals[i]
	_check("Сетка покрывает всю карту без потери треугольников", triangle_count == int(WorldTerrain.HALF_WIDTH * 2.0 / WorldTerrain.STEP) * int(WorldTerrain.DEPTH / WorldTerrain.STEP) * 2)
	_check("Участки используют один материал", shared_material)
	_check("Нормали на стыках совпадают", seamless and duplicates > 0)
	terrain.free()


func _test_resident() -> void:
	var hour: float = gs.get("world_hour")
	var resident: Node = (load("res://scripts/world/world_resident.gd") as GDScript).new()
	var data := load("res://resources/world/miller.tres") as WorldResidentData
	resident.set(&"data", data)
	gs.set(&"world_hour", CONFIG.day_hour)
	_check("Днём мельник обходит двор", resident.call(&"destination") == data.route[0])
	gs.set(&"world_hour", CONFIG.evening_hour)
	_check("Вечером мельник идёт к костру", resident.call(&"destination") == data.evening_spot)
	gs.set(&"world_hour", CONFIG.night_hour)
	_check("Ночью мельник возвращается домой", resident.call(&"destination") == data.home)
	gs.set(&"world_hour", hour)
	resident.free()


func _test_activity() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := Node3D.new()
	world.add_child(player)
	player.add_to_group(&"player")
	var actor := Node3D.new()
	world.add_child(actor)
	actor.add_to_group(&"wildlife")
	actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	actor.position.x = CONFIG.actor_sleep_distance + 1.0
	var activity: Node = (load("res://scripts/world/world_activity.gd") as GDScript).new()
	world.add_child(activity)
	activity.call(&"refresh")
	_check("Дальний актёр приостановлен", actor.process_mode == Node.PROCESS_MODE_DISABLED and int(activity.call(&"sleeping_count")) == 1)
	actor.position.x = (CONFIG.actor_wake_distance + CONFIG.actor_sleep_distance) * 0.5
	activity.call(&"refresh")
	_check("Пороговая зона не вызывает частых переключений", actor.process_mode == Node.PROCESS_MODE_DISABLED)
	player.position = actor.position
	activity.call(&"refresh")
	_check("Телепорт рядом пробуждает актёра и восстанавливает режим", actor.process_mode == Node.PROCESS_MODE_PAUSABLE)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector3.ZERO
	activity.call(&"refresh")
	_check("Чужое отключение обработки не перехватывается", int(activity.call(&"sleeping_count")) == 0)
	actor.process_mode = Node.PROCESS_MODE_INHERIT
	actor.position.x = CONFIG.actor_sleep_distance + 1.0
	activity.call(&"refresh")
	actor.queue_free()
	await process_frame
	activity.call(&"refresh")
	_check("Удаление спящего актёра безопасно", int(activity.call(&"sleeping_count")) == 0)
	var falling := CharacterBody3D.new()
	world.add_child(falling)
	falling.add_to_group(&"wildlife")
	falling.position.x = CONFIG.actor_sleep_distance + 1.0
	activity.call(&"refresh")
	_check("Падение не замирает вдали", falling.process_mode != Node.PROCESS_MODE_DISABLED)
	world.free()


func _test_freed_encounter() -> void:
	var encounters: Node = (load("res://scripts/world/world_encounters.gd") as GDScript).new()
	var enemy := Node3D.new()
	var groups: Dictionary[String, Array] = {"old": [enemy]}
	encounters.set(&"_groups", groups)
	enemy.free()
	_check("Удалённый враг не ломает список живых", (encounters.call(&"_alive", "old") as Array).is_empty())
	encounters.free()
