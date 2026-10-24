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
	_check("Вступление блокирует управление", gs.get(&"controls_locked"))
	raid.call(&"start_attack")
	await _wait(0.2)
	_check("Первая волна началась, управление возвращено", int(raid.get(&"phase")) == 1 and not gs.get(&"controls_locked") and int(raid.call(&"alive_count")) == CONFIG.first_wave_count)
	await _wait(10.0)
	_check("Поджог телеги запущен во время нападения", bool((raid.get(&"_fires") as Node).get(&"cart_ignited")))
	_check("Жители достигли церкви", int(raid.get(&"sheltered")) == 3)
	_clear(raid)
	_check("После первой волны есть передышка", int(raid.get(&"phase")) == 2)
	await _wait(CONFIG.breather_seconds + 0.4)
	_check("Во второй волне главарь с сопровождением", int(raid.get(&"phase")) == 3 and int(raid.call(&"alive_count")) == CONFIG.escort_count + 1)
	_clear(raid)
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
