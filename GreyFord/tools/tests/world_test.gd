extends SceneTree
## Headless check that combat, enemies and trade live in the real village:
## godot --headless --path GreyFord -s res://tools/tests/world_test.gd -- --skip-intro

const HIT_INFO := preload("res://scripts/combat/hit_info.gd")
const CALM := 8
const DEAD_STATE := 9

var gs: Node
var main: Node3D
var player: CharacterBody3D
var combat: Node
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


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)


func _strike(target: Node, damage: float) -> void:
	var info: RefCounted = HIT_INFO.new(damage, 0.0, player, Vector3.FORWARD)
	(target.get(&"_hurtbox") as Node).call(&"receive", info)


func _load_main() -> void:
	if main:
		main.queue_free()
		await process_frame
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(main)
	player = main.get_node("Player") as CharacterBody3D
	combat = player.get_node("Combat")
	await process_frame
	await _wait(0.5)
	await _wait_unlocked()


func _encounters() -> Node:
	return main.get_node("Encounters")


func _initialize() -> void:
	gs = root.get_node("GameState")
	await process_frame
	gs.call(&"new_game")
	gs.set("play_intro", false)
	await _load_main()

	# --- Day 1: who is where.
	var forest: Array = _encounters().call(&"forest_enemies")
	var ids := forest.map(func(e: Node) -> String: return e.get(&"enemy_id"))
	_check("forest has 3 wolves and a bandit", ids.size() == 4 and ids.has("forest_wolf_1") and ids.has("forest_bandit_1"), str(ids))
	var in_area := forest.all(func(e: Node3D) -> bool: return ForestZoneArea.has(e.global_position))
	_check("forest enemies stand inside the forest", in_area)
	_check("no infected by day", (_encounters().call(&"night_enemies") as Array).is_empty())
	_check("Mara can fight in the village", combat != null and combat.get(&"health") > 0)

	# --- Merchants on the square: reachable, talkable, trade window opens.
	var merchants := get_nodes_in_group(&"merchants")
	_check("three merchants on the square", merchants.size() == 3)
	var talked := 0
	for merchant: Node3D in merchants:
		var front: Vector3 = merchant.global_position + merchant.global_basis * Vector3(0, 0, -1.3)
		player.call(&"teleport", front, merchant.global_position - front)
		await _wait(0.4)
		var detector := player.get_node("InteractionDetector")
		var focus: Node = detector.get(&"_focused")
		if focus and focus.get_parent() == merchant:
			talked += 1
	_check("every merchant can be talked to", talked == 3, "%d of 3" % talked)
	var herbwife: Node3D = merchants.filter(func(m: Node) -> bool: return m.name == "Herbwife")[0]
	player.call(&"teleport", herbwife.global_position + herbwife.global_basis * Vector3(0, 0, -1.3), Vector3.ZERO)
	await _wait(0.3)
	_key(KEY_E)
	await _wait(0.3)
	for step: int in 30:
		var balloon: Node = null
		for child: Node in root.get_children():
			if child.get(&"_responses") != null:
				balloon = child
		if balloon == null:
			break
		if (balloon.get(&"_text") as Node).get(&"is_typing"):
			await _wait(0.25)
			continue
		_key(KEY_1 if (balloon.get(&"_responses_box") as Node).get_child_count() > 0 else KEY_E)
		await _wait(0.3)
	var window := get_first_node_in_group(&"trade_window")
	_check("herb-seller trades in the village", window.get(&"is_open") and window.get(&"merchant_id") == "herbwife")
	window.call(&"close_window")
	await _wait(0.2)

	# --- The forest: slip in and out unseen -> flags.
	main.get_node("ForestZone").call(&"_on_enter")
	await _wait_unlocked()
	_check("in the forest", gs.get("in_forest"))
	main.get_node("ForestZone").call(&"_on_leave")
	await _wait_unlocked()
	await _wait(0.2)
	_check("unnoticed enemies write slipped-past flags", gs.call(&"has_flag", "forest_wolf_1_slipped_past") and gs.call(&"has_flag", "forest_bandit_1_slipped_past"))

	# --- A wolf killed today stays dead tomorrow; a bribed bandit stays calm.
	var wolf: Node = (_encounters().call(&"forest_enemies") as Array).filter(func(e: Node) -> bool: return e.get(&"enemy_id") == "forest_wolf_2")[0]
	_strike(wolf, 500.0)
	_check("wolf killed flag", gs.call(&"has_flag", "forest_wolf_2_killed"))
	gs.call(&"set_flag", "forest_bandit_1_bribe")
	gs.call(&"begin_night")
	gs.call(&"begin_day")
	await _wait(0.3)
	forest = _encounters().call(&"forest_enemies")
	ids = forest.map(func(e: Node) -> String: return e.get(&"enemy_id"))
	_check("dead wolf not back on day 2", not ids.has("forest_wolf_2") and ids.has("forest_wolf_1"), str(ids))
	var bandit: Node = forest.filter(func(e: Node) -> bool: return e.get(&"enemy_id") == "forest_bandit_1")[0]
	_check("bribed bandit stays calm", int(bandit.get(&"state")) == CALM)

	# --- Night 2: infected in the streets, traders gone; they walk their loops.
	gs.call(&"begin_night")
	await _wait(0.3)
	var infected: Array = _encounters().call(&"night_enemies")
	_check("two infected on night 2", infected.size() == 2)
	_check("traders gone at night", merchants.all(func(m: Node3D) -> bool: return not m.visible))
	_check("infected bolder at night", float(infected[0].call(&"_speed_multiplier")) > 1.0)
	player.call(&"teleport", Vector3(-20, 0, -25))  # Far away, behind the church.
	var visited := [{}, {}]
	for t: int in 50:
		await _wait(0.5)
		for i: int in infected.size():
			(visited[i] as Dictionary)[infected[i].get(&"_route_index")] = true
	_check("infected walk their routes", (visited[0] as Dictionary).size() >= 3 and (visited[1] as Dictionary).size() >= 3,
			"%d/4, %d/4 waypoints" % [(visited[0] as Dictionary).size(), (visited[1] as Dictionary).size()])
	gs.call(&"begin_day")
	await _wait(0.3)
	_check("infected gone in the morning", (_encounters().call(&"night_enemies") as Array).is_empty())
	_check("traders back in the morning", merchants.all(func(m: Node3D) -> bool: return m.visible))

	# --- Falling in the forest: wake by the village fire, out of the forest.
	main.get_node("ForestZone").call(&"_on_enter")
	await _wait_unlocked()
	var coins_before: int = gs.get("coins")
	var info: RefCounted = HIT_INFO.new(1000.0, 0.0, player, Vector3.FORWARD)
	(combat.get(&"_hurtbox") as Node).call(&"receive", info)
	await _wait(0.5)
	await _wait_unlocked()
	await _wait(0.3)
	_check("respawn by the village fire", not gs.get("in_forest") and player.global_position.distance_to(Vector3.ZERO) < 6.0,
			"%.1f m from the fire" % player.global_position.distance_to(Vector3.ZERO))
	_check("death costs coins", int(gs.get("coins")) <= coins_before)

	# --- Save and load: coins, bag, gear, health, the dead.
	gs.set("coins", 77)
	gs.call(&"give", "wolf_pelt", 2)
	gs.call(&"give", "leather_armor")
	gs.call(&"equip", "leather_armor")
	combat.set(&"health", 64.0)
	combat.emit_signal(&"health_changed", 64.0, 100.0)
	gs.call(&"save_game")
	gs.call(&"new_game")
	_check("new game resets purse", gs.get("coins") != 77)
	_check("load", gs.call(&"load_game"))
	_check("coins saved", gs.get("coins") == 77)
	_check("bag saved", gs.call(&"count", "wolf_pelt") == 2 and gs.call(&"count", "leather_armor") == 1)
	_check("gear saved", gs.get("equipment")["armor"] == "leather_armor")
	_check("health saved", is_equal_approx(float(gs.get("hero_health")), 64.0))
	await _load_main()
	_check("health restored in the scene", is_equal_approx(float(combat.get(&"health")), 64.0), "%.0f" % combat.get(&"health"))
	ids = (_encounters().call(&"forest_enemies") as Array).map(func(e: Node) -> String: return e.get(&"enemy_id"))
	_check("dead wolf stays dead after loading", not ids.has("forest_wolf_2"), str(ids))

	print("world test: %d failure(s)" % failures)
	main.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)


class ForestZoneArea:
	static func has(p: Vector3) -> bool:
		return Rect2(-26.0, -66.0, 52.0, 29.0).has_point(Vector2(p.x, p.z))
