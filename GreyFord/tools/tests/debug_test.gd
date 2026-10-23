extends SceneTree
## Headless check of the F3 debug panel in the village:
## godot --headless --path GreyFord -s res://tools/tests/debug_test.gd -- --skip-intro

var gs: Node
var debug: Node
var main: Node3D
var player: Node3D
var failures: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["OK  " if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _wait_unlocked(limit: float = 30.0) -> void:
	var t := 0.0
	while gs.get("controls_locked") and t < limit:
		await _wait(0.2)
		t += 0.2


## A real key press: down, then up.
func _f3() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F3
		event.pressed = pressed
		root.push_input(event)


func _press(prefix: String) -> void:
	for button: Node in debug.find_children("*", "Button", true, false):
		if (button as Button).text.begins_with(prefix):
			(button as Button).pressed.emit()
			return
	_check("button %s exists" % prefix, false)


func _initialize() -> void:
	gs = root.get_node("GameState")
	debug = root.get_node("DebugMenu")
	await process_frame
	gs.call(&"new_game")
	gs.set("play_intro", false)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(main)
	player = main.get_node("Player") as Node3D
	await _wait(0.6)
	await _wait_unlocked()

	_f3()
	await _wait(0.4)
	var panel := debug.get(&"_panel") as Control
	_check("F3 opens the panel", panel.visible)
	var text := str((debug.get(&"_info") as RichTextLabel).text)
	_check("panel lists enemies with state and health", text.contains("forest_wolf_1") and text.contains("PATROL") and text.contains("45/45"))
	_check("panel lists watchmen", text.contains("Дозорные"))

	var coins: int = gs.get("coins")
	_press("+100")
	_check("+100 coins", gs.get("coins") == coins + 100)
	_press("Неуязвимость")
	_check("invulnerability on", player.get_node("Combat").get(&"invulnerable"))
	var before := get_nodes_in_group(&"enemies").size()
	_press("Волк")
	_press("Разбойник")
	await _wait(0.2)
	_check("spawn wolf and bandit", get_nodes_in_group(&"enemies").size() == before + 2)
	for enemy: Node in get_nodes_in_group(&"enemies"):
		if str(enemy.get(&"enemy_id")).begins_with("debug_"):
			enemy.queue_free()  # Or the bandit would stop Mara for a talk.
	_press("К торговцу")
	await _wait(0.2)
	var near := get_nodes_in_group(&"merchants").any(func(m: Node3D) -> bool: return m.global_position.distance_to(player.global_position) < 2.0)
	_check("teleport to a merchant", near)

	gs.call(&"set_flag", "debug_seen")
	await _wait(0.4)
	_check("panel shows flags", str((debug.get(&"_info") as RichTextLabel).text).contains("debug_seen"))

	_press("Пропустить")
	await _wait(0.5)
	await _wait_unlocked()
	_check("skip: day -> night", gs.get("phase") == 1 and gs.get("day") == 1)
	_press("Пропустить")
	await _wait(0.5)
	await _wait_unlocked()
	_check("skip: night -> day 2", gs.get("phase") == 0 and gs.get("day") == 2)

	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_I
		key.pressed = pressed
		root.push_input(key)
	await _wait(0.2)
	var bag := get_first_node_in_group(&"inventory_window")
	_check("I still opens the bag after a night", bag.get(&"is_open"))
	bag.call(&"close_window")
	_f3()
	await _wait(0.2)
	_check("F3 closes the panel", not panel.visible)
	print("debug test: %d failure(s)" % failures)
	main.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
