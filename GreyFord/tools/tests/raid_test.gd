extends SceneTree
## Смена волн, укрытие жителей, исходы боя и отсутствие записи сюжетного сохранения.

const HIT_INFO := preload("res://scripts/combat/hit_info.gd")
const CONFIG: RaidConfig = preload("res://resources/raid/raid_config.tres")
var failures: int = 0
var gs: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["OK  " if ok else "FAIL", label])
	if not ok:
		failures += 1


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _clear(raid: Node3D) -> void:
	var enemies: Array = raid.get(&"enemies")
	for enemy: Variant in enemies:
		if is_instance_valid(enemy) and not enemy.get(&"dead"):
			(enemy.get(&"_hurtbox") as Node).call(&"receive", HIT_INFO.new(1000.0, 0.0, raid.get_node(^"Player"), Vector3.FORWARD))


func _run() -> void:
	await process_frame
	gs = root.get_node(^"GameState")
	var save_path := "user://greyford_save.json"
	var old_save := FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	gs.call(&"new_game")
	var scene := load("res://scenes/raid/village_raid.tscn") as PackedScene
	var raid := scene.instantiate() as Node3D
	root.add_child(raid)
	var hero := raid.get_node(^"Player/Combat")
	hero.set(&"invulnerable", true)
	await _wait(0.3)
	_test_street(raid)
	_check("Вступление блокирует управление", gs.get(&"controls_locked"))
	raid.call(&"start_attack")
	await _wait(0.2)
	_check("Первая волна началась, управление возвращено", int(raid.get(&"phase")) == 1 and not gs.get(&"controls_locked") and int(raid.call(&"alive_count")) == mini(CONFIG.first_wave_count, CONFIG.max_active_enemies))
	await _test_combat(raid)
	await _wait(10.0)
	_check("Поджог телеги запущен во время нападения", bool((raid.get(&"_fires") as Node).get(&"cart_ignited")))
	_check("Жители достигли церкви", int(raid.get(&"sheltered")) == 3)
	var maximum_attackers: int = 0
	for sample: int in 100:
		var active_attackers: int = 0
		for opponent: Variant in raid.get(&"enemies"):
			if is_instance_valid(opponent) and int(opponent.get(&"state")) == 4:
				active_attackers += 1
		maximum_attackers = maxi(maximum_attackers, active_attackers)
		await physics_frame
	_check("В настоящем бою атакуют не больше двух противников", maximum_attackers > 0 and maximum_attackers <= CONFIG.max_attackers)
	await _clear_wave(raid)
	_check("Первая волна использовала все подкрепления", (raid.get(&"enemies") as Array).size() == CONFIG.first_wave_count)
	_check("После первой волны есть передышка", int(raid.get(&"phase")) == 2)
	await _wait(CONFIG.breather_seconds + 0.4)
	_check("Во второй волне главарь с сопровождением", int(raid.get(&"phase")) == 3 and int(raid.call(&"alive_count")) == mini(CONFIG.escort_count + 1, CONFIG.max_active_enemies))
	await _clear_wave(raid)
	_check("Полный набег содержит все запланированные отряды", (raid.get(&"enemies") as Array).size() == CONFIG.first_wave_count + CONFIG.escort_count + 1)
	_check("Победа завершает бой", int(raid.get(&"phase")) == 4 and gs.get(&"controls_locked"))
	await _wait(0.3)
	raid.free()
	_check("Выход освобождает управление", not gs.get(&"controls_locked"))
	gs.call(&"new_game")
	raid = scene.instantiate() as Node3D
	root.add_child(raid)
	await _wait(0.3)
	raid.call(&"start_attack")
	hero = raid.get_node(^"Player/Combat")
	(hero.get(&"_hurtbox") as Node).call(&"receive", HIT_INFO.new(1000.0, 0.0, raid, Vector3.FORWARD))
	_check("Смерть Мары даёт поражение", int(raid.get(&"phase")) == 5)
	_check("Поражение отменяет оставшиеся подкрепления", int(raid.call(&"pending_count")) == 0)
	await _wait(4.5)
	_check("После поражения нет автоматического возрождения или новой волны", int(raid.get(&"phase")) == 5 and int(hero.get(&"state")) != 0)
	raid.free()
	var new_save := FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	_check("Эпизод не перезаписывает сюжетное сохранение", old_save == new_save)
	_check("Поражение не оставляет управление заблокированным после выхода", not gs.get(&"controls_locked"))
	await process_frame
	await _test_navigation()
	print("raid test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _test_navigation() -> void:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	var entry: Button
	for node: Node in menu.find_children("*", "Button", true, false):
		if (node as Button).text == "Набег на Серый Брод":
			entry = node as Button
	_check("В меню есть вход в эпизод", entry != null)
	if entry == null:
		return
	entry.pressed.emit()
	await _wait(1.3)
	_check("Кнопка открывает сцену набега", current_scene != null and current_scene.name == &"VillageRaid")
	if current_scene == null or current_scene.name != &"VillageRaid":
		return
	var old_id := current_scene.get_instance_id()
	current_scene.call(&"_retry")
	await _wait(0.5)
	_check("Повтор создаёт новое вступление без накопления блокировок", current_scene.get_instance_id() != old_id and int(current_scene.get(&"phase")) == 0 and gs.get(&"controls_locked"))
	current_scene.call(&"_menu")
	await _wait(0.4)
	_check("Возврат в главное меню освобождает управление", current_scene is Control and not gs.get(&"controls_locked"))
	var cleanup := current_scene
	current_scene = null
	cleanup.free()


func _clear_wave(raid: Node3D) -> void:
	var old_phase: int = raid.get(&"phase")
	for attempt: int in 12:
		_clear(raid)
		await _wait(0.1)
		_check("Подкрепления не превышают лимит сцены", int(raid.call(&"alive_count")) <= CONFIG.max_active_enemies)
		if int(raid.get(&"phase")) != old_phase:
			return
	_check("Волна завершилась после всех подкреплений", false)


func _test_combat(raid: Node3D) -> void:
	var hero := raid.get_node(^"Player/Combat")
	var opponents: Array = raid.get(&"enemies")
	for enemy: Node in opponents:
		enemy.set_physics_process(false)
	hero.set(&"invulnerable", false)
	var health: float = hero.get(&"health")
	Input.action_press(&"block")
	await _wait(0.05)
	var forward: Vector3 = hero.call(&"_forward")
	var hit := HIT_INFO.new(12.0, 0.0, opponents[0], -forward)
	(hero.get(&"_hurtbox") as Node).call(&"receive", hit)
	_check("Своевременный блок парирует без потери здоровья", int(hit.result) == 2 and is_equal_approx(float(hero.get(&"health")), health))
	_check("Парирование открывает противника для ответа", int(opponents[0].get(&"state")) == 5)
	await _wait(CONFIG.parry_window + 0.2)
	var late := HIT_INFO.new(12.0, 0.0, opponents[0], -forward)
	(hero.get(&"_hurtbox") as Node).call(&"receive", late)
	_check("Удержание блока после окна не создаёт новое парирование", int(late.result) == 2 and float(hero.get(&"_parry_left")) <= 0.0)
	Input.action_release(&"block")
	await _wait(0.05)
	hero.call(&"restore")
	hero.call(&"_start_attack", 2)
	_check("Третий удар комбо сильнее обычного", float(hero.call(&"attack_damage")) > float((gs.call(&"equipped", "weapon") as Resource).get(&"damage")))
	hero.call(&"_set_state", 0)
	for i: int in CONFIG.max_attackers:
		opponents[i].call(&"_set_state", 4)
	_check("Лимит одновременных атак соблюдается", not raid.call(&"may_attack", opponents[CONFIG.max_attackers]))
	for enemy: Node in opponents:
		enemy.call(&"_set_state", 2)
	var shield: Node = opponents[1]
	var before: float = shield.get(&"health")
	var normal := HIT_INFO.new(20.0, 0.0, raid.get_node(^"Player"), -(shield.call(&"_forward") as Vector3))
	(shield.get(&"_hurtbox") as Node).call(&"receive", normal)
	_check("Щитоносец закрывается от обычного удара спереди", int(normal.result) == 2 and is_equal_approx(float(shield.get(&"health")), before))
	var heavy := HIT_INFO.new(CONFIG.guard_break_damage + 1.0, 0.0, raid.get_node(^"Player"), -(shield.call(&"_forward") as Vector3))
	(shield.get(&"_hurtbox") as Node).call(&"receive", heavy)
	_check("Тяжёлый удар пробивает прикрытие щитоносца", int(heavy.result) == 1 and float(shield.get(&"health")) < before)
	hero.set(&"invulnerable", true)
	hero.call(&"restore")
	for enemy: Node in opponents:
		enemy.set_physics_process(true)


func _test_street(raid: Node3D) -> void:
	var cottages := raid.find_children("WeatheredCottage", "", true, false)
	_check("Два дома у ворот получили новые материалы", cottages.size() == 2)
	var colliders_preserved: bool = true
	for cottage: Node in cottages:
		colliders_preserved = colliders_preserved and not cottage.get_parent().find_children("*", "CollisionShape3D", true, false).is_empty()
	_check("Новый вид домов сохраняет препятствия для игрока", colliders_preserved)
	_check("У ворот заменены четыре хвойных дерева", raid.find_children("DetailedFir", "", true, false).size() == 4)
