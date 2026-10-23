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

	print("open world test: %d failure(s)" % failures)
	world.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
