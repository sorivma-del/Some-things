extends SceneTree
## Headless check of the open world's clock, places, enemies and resting:
## godot --headless --path GreyFord -s res://tools/tests/open_world_test.gd

const HIT_INFO := preload("res://scripts/combat/hit_info.gd")

var gs: Node
var world: Node3D
var player: CharacterBody3D
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


func _groups() -> Dictionary:
	return world.get_node("Encounters").call(&"groups")


func _clock() -> Node:
	return get_first_node_in_group(&"world_clock")


func _initialize() -> void:
	gs = root.get_node("GameState")
	await process_frame
	gs.call(&"new_game")
	var t0 := Time.get_ticks_msec()
	world = (load("res://scenes/world/open_world.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(world)
	player = world.get_node("Player") as CharacterBody3D
	print("  world built in %d ms" % (Time.get_ticks_msec() - t0))
	await _wait(0.6)
	await _wait_unlocked()

	# --- Arrival and places.
	_check("world mode", gs.get("world_mode"))
	_check("Mara starts outside the gate", player.global_position.distance_to(Vector3(0, player.global_position.y, 9)) < 2.0)
	_check("the gate is found at once", (gs.get("discovered") as Dictionary).has("gate"))
	var mill: Vector3 = world.call(&"place_position", "mill")
	player.call(&"teleport", mill)
	await _wait(1.0)
	_check("walking somewhere new discovers it", gs.call(&"has_flag", "found_mill"))

	# --- Enemies by place.
	var groups := _groups()
	_check("wolf packs, camp with chief, tower, farm", groups.has("wolf_woods") and groups.has("dark_woods") and groups.has("camp_chief") and groups.has("tower") and groups.has("farm"), str(groups.keys()))
	_check("no graveyard dead by day", not groups.has("graveyard"))
	_check("deer graze", get_nodes_in_group(&"wildlife").size() >= 6)

	# --- The clock: evening light, night brings the graveyard dead and bolder infected.
	var hour: float = gs.get("world_hour")
	await _wait(2.0)
	_check("time passes", float(gs.get("world_hour")) > hour, "%.3f -> %.3f" % [hour, gs.get("world_hour")])
	_clock().call(&"advance", 22.0 - float(gs.get("world_hour")))
	await _wait(0.3)
	_check("night by the clock", gs.call(&"world_period") == "night" and gs.get("phase") == 1)
	_check("graveyard dead rise at night", _groups().has("graveyard") and (_groups()["graveyard"] as Array).size() == 3)
	var infected: Node = (_groups()["farm"] as Array)[0]
	_check("infected bolder at night", float(infected.call(&"_speed_multiplier")) > 1.0)

	# --- Wipe out the tower bandits: they come back two days later.
	for bandit: Node in _groups()["tower"]:
		(bandit.get(&"_hurtbox") as Node).call(&"receive", HIT_INFO.new(500.0, 0.0, player, Vector3.FORWARD))
	await _wait(0.2)
	_check("tower cleared", (gs.get("world_cleared") as Dictionary).has("tower") and gs.call(&"has_flag", "world_tower_cleared"))

	# --- Rest at the mill fire: morning, healed, a day later.
	var combat := player.get_node("Combat")
	combat.set(&"health", 40.0)
	combat.emit_signal(&"health_changed", 40.0, 100.0)
	player.call(&"teleport", mill + Vector3(2, 0, 2))
	await _wait(0.5)
	var day: int = gs.get("world_day")
	_clock().call(&"rest", "mill")
	await _wait(0.5)
	await _wait_unlocked()
	_check("resting sleeps till morning", int(gs.get("world_day")) == day + 1 and absf(float(gs.get("world_hour")) - 7.0) < 0.2, "day %d, %s" % [gs.get("world_day"), gs.call(&"world_clock_text")])
	_check("resting heals", float(combat.get(&"health")) >= 80.0, "%.0f" % combat.get(&"health"))
	_check("graveyard dead gone by morning", not _groups().has("graveyard"))
	_check("tower still empty a day later", (_groups().get("tower", []) as Array).filter(func(e: Node) -> bool: return is_instance_valid(e)).is_empty())
	_clock().call(&"advance", 24.0)
	gs.emit_signal(&"time_changed")
	await _wait(0.3)
	var tower: Array = (_groups().get("tower", []) as Array).filter(func(e: Node) -> bool: return is_instance_valid(e) and not e.get(&"dead"))
	_check("tower bandits back after two days", tower.size() == 2, "%d" % tower.size())

	# --- Can't rest with enemies around.
	var wolf: Node3D = (_groups()["wolf_woods"] as Array)[0]
	player.call(&"teleport", wolf.global_position + Vector3(4, 0, 0))
	var before: float = gs.get("world_hour")
	_clock().call(&"rest", "crossroads")
	await _wait(0.3)
	_check("no rest with enemies near", absf(float(gs.get("world_hour")) - before) < 0.1 and not gs.get("controls_locked"))

	# --- Map and fast travel: only to found campfires, time passes, the horse comes along.
	player.call(&"teleport", world.call(&"place_position", "crossroads") + Vector3(3, 0, 3))
	await _wait(0.6)
	var horse := get_first_node_in_group(&"horse") as Node3D
	horse.call(&"mount")
	horse.call(&"dismount")
	var destinations: PackedStringArray = world.call(&"travel_destinations")
	_check("only found campfires are destinations", destinations.has("mill") and destinations.has("crossroads") and not destinations.has("hermit"), str(destinations))
	gs.call(&"discover", "hermit", "Хижина отшельника")
	var map := get_first_node_in_group(&"map_window")
	_check("map window exists in the world", map != null)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_M
	key.pressed = true
	root.push_input(key)
	await _wait(0.3)
	_check("M opens the map", map.get(&"is_open"))
	var depart: float = gs.get("world_hour")
	var hours: float = world.call(&"travel_hours", "hermit")
	map.call(&"_travel", "hermit")
	await _wait(0.4)
	await _wait_unlocked()
	var hermit: Vector3 = world.call(&"place_position", "hermit")
	_check("fast travel to the hermit", player.global_position.distance_to(hermit) < 6.0, "%.1f m away" % player.global_position.distance_to(hermit))
	_check("the trip takes time", absf(fposmod(float(gs.get("world_hour")) - depart, 24.0) - hours) < 0.2, "%.1f h planned" % hours)
	_check("the horse comes along", horse.global_position.distance_to(player.global_position) < 8.0)
	_check("map closed, controls free", not map.get(&"is_open") and not gs.get("controls_locked"))
	_check("compass on screen", world.find_children("*", "Control", true, false).any(func(c: Node) -> bool: return c.get_script() and str((c.get_script() as Script).get_global_name()) == "Compass"))

	# --- Save in the world, load: back in the world where she stood, horse and clock too.
	var save_spot := world.call(&"place_position", "rest") as Vector3 + Vector3(6, 0.3, 0)
	player.call(&"teleport", save_spot)
	horse.global_position = save_spot + Vector3(3, 0.5, 0)
	await _wait(0.3)
	var saved_day: int = gs.get("world_day")
	var saved_hour: float = gs.get("world_hour")
	var saved_found := (gs.get("discovered") as Dictionary).size()
	gs.call(&"save_game")
	gs.call(&"new_game")
	_check("load", gs.call(&"load_game"))
	_check("save remembers the world", gs.get("world_mode") and gs.call(&"saved_scene_path") == "res://scenes/world/open_world.tscn")
	_check("clock saved", int(gs.get("world_day")) == saved_day and absf(float(gs.get("world_hour")) - saved_hour) < 0.05)
	_check("found places saved", (gs.get("discovered") as Dictionary).size() == saved_found)
	_check("horse ownership saved", gs.call(&"has_flag", "horse_owned"))
	world.queue_free()
	await process_frame
	world = (load("res://scenes/world/open_world.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(world)
	player = world.get_node("Player") as CharacterBody3D
	await _wait(0.6)
	await _wait_unlocked()
	_check("loaded where she stood", player.global_position.distance_to(save_spot) < 2.0, "%.1f m off" % player.global_position.distance_to(save_spot))
	var loaded_horse := get_first_node_in_group(&"horse") as Node3D
	_check("horse where it was left", loaded_horse.global_position.distance_to(save_spot + Vector3(3, 0, 0)) < 2.5)
	var tower_back: Array = (_groups().get("tower", []) as Array).filter(func(e: Node) -> bool: return is_instance_valid(e))
	_check("enemy groups restored", tower_back.size() == 2 and _groups().has("camp_chief"))

	print("open_world test: %d failure(s)" % failures)
	world.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
