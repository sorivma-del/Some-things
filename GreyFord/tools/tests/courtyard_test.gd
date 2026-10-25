extends SceneTree
## Вход из меню, коллизии, смена света и повтор тренировки без записи сохранений.
const HIT := preload("res://scripts/combat/hit_info.gd")
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["OK  " if ok else "FAIL", label])
	if not ok:
		failures += 1


func _run() -> void:
	await process_frame
	var original_taa := root.use_taa
	var gs := root.get_node(^"GameState")
	var save_path := "user://greyford_save.json"
	var before := FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	var bandit := load("res://resources/combat/bandit.tres") as Resource
	var original_health: float = bandit.get(&"max_health")
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	var entry: Button
	for node: Node in menu.find_children("*", "Button", true, false):
		if (node as Button).text == "Двор у святилища":
			entry = node as Button
	_check("В меню есть японский двор", entry != null)
	if entry == null:
		quit(1)
		return
	entry.pressed.emit()
	await create_timer(0.9).timeout
	var courtyard := current_scene as Node3D
	_check("Кнопка открывает отдельную японскую сцену", courtyard != null and courtyard.name == &"JapaneseCourtyard")
	if courtyard == null:
		quit(1)
		return
	await physics_frame
	await physics_frame
	var space := courtyard.get_world_3d().direct_space_state
	var path := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1.1, -10), Vector3(0, 1.1, 5), 1))
	_check("Центральная дорожка свободна для прохода", path.is_empty())
	var boundary := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1.1, -11), Vector3(0, 1.1, -17), 1))
	_check("Ограда не даёт уйти за пределы пробной сцены", not boundary.is_empty())
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1.1, 5), Vector3(0, 1.1, 11), 1))
	_check("Стена святилища не пропускает игрока", not wall.is_empty() and wall["collider"].name == &"SanctuaryWalls")
	var gate := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.7, 2, -6), Vector3(2.7, 2, 0), 1))
	_check("У столбов тории есть коллизия", not gate.is_empty())
	courtyard.call(&"set_evening", true)
	var env: Environment = courtyard.get_node(^"WorldEnvironment").get(&"environment")
	var evening_density := env.fog_density
	courtyard.call(&"set_evening", false)
	_check("Утро и сумерки действительно меняют освещение", env.fog_density < evening_density and not courtyard.get(&"evening"))
	courtyard.call(&"_start_training")
	await process_frame
	var enemies: Array = courtyard.get(&"enemies")
	_check("Тренировка создаёт три разные роли", enemies.size() == 3 and int(enemies[0].get(&"role")) == 0 and int(enemies[1].get(&"role")) == 1 and int(enemies[2].get(&"role")) == 2)
	_check("Профили тренировки не меняют обычных разбойников", is_equal_approx(float(bandit.get(&"max_health")), original_health))
	for i: int in 2:
		enemies[i].call(&"_set_state", 4)
	_check("Тренировка ограничивает одновременные атаки", not courtyard.call(&"may_attack", enemies[2]))
	var hero := courtyard.get_node(^"Player/Combat")
	hero.get(&"_hurtbox").receive(HIT.new(1000.0, 0.0, enemies[0], Vector3.FORWARD))
	_check("После поражения доступен повтор", not courtyard.get(&"training") and not courtyard.get(&"_training_button").disabled)
	courtyard.call(&"_start_training")
	await process_frame
	await physics_frame
	_check("Повтор восстанавливает героя и не накапливает врагов", int(hero.get(&"state")) == 0 and float(hero.get(&"health")) > 0 and get_nodes_in_group(&"enemies").size() == 3)
	for enemy: Node in courtyard.get(&"enemies"):
		enemy.set_physics_process(false)
		enemy.get(&"_hurtbox").receive(HIT.new(1000.0, 0.0, hero.get_parent(), Vector3.ZERO))
	_check("Победа завершает тренировку", not courtyard.get(&"training") and not courtyard.get(&"_training_button").disabled)
	courtyard.call(&"_menu")
	await process_frame
	await process_frame
	_check("Выход возвращает меню без блокировки управления", current_scene is Control and not gs.get(&"controls_locked"))
	_check("Выход восстанавливает настройки сглаживания", root.use_taa == original_taa)
	var after := FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	_check("Двор и тренировка не перезаписывают сохранение", before == after)
	var cleanup := current_scene
	current_scene = null
	cleanup.free()
	print("courtyard test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
