extends SceneTree
## Переходы катсцены, клинок без щита, повтор и сохранение основной игры.
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
	var gs := root.get_node(^"GameState")
	var controls := root.get_node(^"GameControls")
	var save_path := "user://greyford_save.json"
	var before := FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	var bandit := load("res://resources/combat/bandit.tres") as Resource
	var original_health: float = bandit.get(&"max_health")
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	var entry: Button
	for node: Node in menu.find_children("*", "Button", true, false):
		if (node as Button).text == "Тропа к святилищу":
			entry = node as Button
	_check("В меню есть новый эпизод", entry != null)
	if entry == null:
		quit(1)
		return
	entry.pressed.emit()
	await create_timer(1.0).timeout
	var scene := current_scene as Node3D
	_check("Открывается отдельная сцена эпизода", scene != null and scene.name == &"ShrineEpisode")
	if scene == null or scene.name != &"ShrineEpisode":
		quit(1)
		return
	var hero := scene.get_node(^"Player/Combat")
	var player := scene.get_node(^"Player") as Node3D
	var guard: Node = scene.get(&"enemies")[0]
	_check("Вступление блокирует бой и включает постановочную камеру", gs.get(&"controls_locked") and root.get_camera_3d().name == &"EpisodeCamera")
	_check("Один страж ждёт окончания сцены", scene.get(&"enemies").size() == 1 and not guard.is_physics_processing())
	var held: Dictionary = hero.get(&"_held")
	_check("Катана в руке, щит не добавляется", held.size() == 1 and held.has("weapon") and held["weapon"].name == &"Katana")
	_check("Исходная модель героини сохранена", String(scene.get_node(^"Player/Model").get(&"base_scene").resource_path).ends_with("Superhero_Female_FullBody.gltf"))
	var start := player.position
	await create_timer(0.6).timeout
	_check("Во вступлении героиня действительно идёт", player.position.distance_to(start) > 0.2)
	controls.set(&"ignore_unfocused", false)
	var skip := InputEventJoypadButton.new()
	skip.device = 42
	skip.button_index = JOY_BUTTON_A
	skip.pressed = true
	Input.parse_input_event(skip)
	await process_frame
	skip.pressed = false
	Input.parse_input_event(skip)
	await physics_frame
	_check("Крестик DualSense пропускает вступление", int(scene.get(&"phase")) == 1 and not gs.get(&"controls_locked"))
	_check("После пропуска активны игровая камера и противник", root.get_camera_3d().name != &"EpisodeCamera" and guard.is_physics_processing() and hero.get(&"target") == guard)
	scene.call(&"_finish_intro")
	_check("Повторный пропуск не создаёт второго врага", scene.get(&"enemies").size() == 1)
	guard.set_physics_process(false)
	await create_timer(0.15).timeout
	hero.call(&"_face", Vector3.BACK, 0.0, true)
	Input.action_press(&"block")
	await physics_frame
	await physics_frame
	_check("Блок клинком работает без щита", hero.get(&"blocking") and not held.has("shield"))
	var hit := HIT.new(16.0, 0.0, guard, Vector3.FORWARD)
	hero.call(&"_on_hit", hit)
	_check("Своевременный блок парирует клинок", int(hit.result) == 2 and guard.call(&"is_exposed"))
	Input.action_release(&"block")
	guard.position = player.position + Vector3.BACK * 1.5
	hero.call(&"_start_attack", 0)
	_check("После парирования доступна контратака катаной", int(hero.get(&"_swing")) == 2 and hero.call(&"attack_damage") > 24.0)
	await create_timer(0.8).timeout
	hero.get(&"_hurtbox").receive(HIT.new(1000.0, 0.0, guard, Vector3.ZERO))
	_check("Поражение открывает повтор без блокировки управления", int(scene.get(&"phase")) == 4 and not gs.get(&"controls_locked") and scene.get(&"_result").visible)
	scene.call(&"_start_training")
	await process_frame
	await physics_frame
	_check("Повтор не накапливает врагов и восстанавливает здоровье", get_nodes_in_group(&"enemies").size() == 1 and float(hero.get(&"health")) > 0.0)
	# Полный повтор проходит все три кадра самостоятельно.
	await create_timer(11.7).timeout
	_check("Вступление само возвращает управление после трёх кадров", int(scene.get(&"phase")) == 1 and not gs.get(&"controls_locked") and not player.get(&"_walking_to"))
	guard = scene.get(&"enemies")[0]
	guard.set_physics_process(false)
	guard.get(&"_hurtbox").receive(HIT.new(1000.0, 0.0, player, Vector3.ZERO))
	_check("Победа запускает финальный кадр", int(scene.get(&"phase")) == 2 and gs.get(&"controls_locked"))
	await create_timer(3.7).timeout
	_check("После финала можно осмотреть двор и повторить", int(scene.get(&"phase")) == 3 and not gs.get(&"controls_locked") and scene.get(&"_result").visible)
	_check("Параметры обычного разбойника не изменились", is_equal_approx(float(bandit.get(&"max_health")), original_health))
	scene.call(&"_start_training")
	await process_frame
	scene.call(&"_menu")
	await process_frame
	await process_frame
	_check("Выход во время вступления освобождает управление", current_scene is Control and not gs.get(&"controls_locked"))
	var after := FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	_check("Эпизод не перезаписывает сохранение", before == after)
	var cleanup := current_scene
	current_scene = null
	cleanup.free()
	print("shrine_episode test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
