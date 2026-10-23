extends SceneTree
## A simple bot plays Mara against each enemy type on the arena with the real controls:
## lock on, attack while there is stamina, roll away when a blow is being telegraphed,
## bandage when low. Prints who won, how long it took and what it cost.
## godot --headless --path GreyFord -s res://tools/tests/fight_test.gd

const ATTACK := 4
const DEAD := 9
const HERO_DEAD := 5
const WINDUP := 0
## The bot reacts this long before a telegraphed blow lands (a decent human reaction).
const DODGE_LEAD := 0.22
const LIMIT := 60.0

var gs: Node
var arena: Node3D
var player: CharacterBody3D
var combat: Node
var failures: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["OK  " if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


## Fights until every enemy in `enemies` is down, Mara falls, or time runs out.
func _fight(label: String, enemies: Array) -> Dictionary:
	combat.call(&"restore")
	gs.set("items", {"bandage": 3})
	var start_time := Time.get_ticks_msec()
	var game_time := 0.0
	var dodges := 0
	var bandages := 0
	var swings := 0
	var damage_taken := 0.0
	var last_health: float = combat.get(&"health")
	while game_time < LIMIT:
		var alive := enemies.filter(func(e: Node) -> bool: return is_instance_valid(e) and int(e.get(&"state")) != DEAD)
		if alive.is_empty() or int(combat.get(&"state")) == HERO_DEAD:
			break
		var health: float = combat.get(&"health")
		if health < last_health:
			damage_taken += last_health - health
		last_health = health
		if combat.get(&"target") == null:
			# Face the nearest enemy, then lock on.
			var nearest: Node3D = alive[0]
			for e: Node3D in alive:
				if e.global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position):
					nearest = e
			player.call(&"face_point", nearest.global_position)
			get_first_node_in_group(&"camera_rig").set(&"yaw_degrees", rad_to_deg((player.get_node("Model") as Node3D).rotation.y))
			await _tap(&"lock_on")
		var threat := false
		for e: Node3D in alive:
			if int(e.get(&"state")) == ATTACK and int(e.get(&"_attack_phase")) == WINDUP:
				var attack: Resource = e.get(&"attack")
				var left: float = float(attack.get(&"windup")) - float(e.get(&"_state_time"))
				if left < DODGE_LEAD and e.global_position.distance_to(player.global_position) < float(attack.get(&"attack_range")) + 1.5:
					threat = true
		var stamina: float = combat.get(&"stamina")
		var data: Resource = combat.get(&"data")
		if threat and stamina >= float(data.get(&"roll_cost")):
			# Roll away from the blow (sideways-back relative to the camera).
			Input.action_press(&"move_back")
			Input.action_press(&"move_left")
			await _tap(&"roll")
			Input.action_release(&"move_back")
			Input.action_release(&"move_left")
			dodges += 1
		elif health < 45.0 and gs.call(&"count", "bandage") > 0:
			await _tap(&"heal")
			bandages += 1
		elif stamina >= float(data.get(&"attack_cost")) + float(data.get(&"roll_cost")) * 0.5:
			var target := combat.get(&"target") as Node3D
			if target and target.global_position.distance_to(player.global_position) > 2.0:
				Input.action_press(&"move_forward")
				await _wait(0.1)
				Input.action_release(&"move_forward")
			else:
				await _tap(&"attack")
				swings += 1
		await physics_frame
		game_time = (Time.get_ticks_msec() - start_time) / 1000.0
	var won := enemies.all(func(e: Node) -> bool: return not is_instance_valid(e) or int(e.get(&"state")) == DEAD)
	var result := {"won": won, "time": game_time, "hp": combat.get(&"health"), "taken": damage_taken,
			"dodges": dodges, "swings": swings, "bandages": bandages}
	print("  %s: %s in %.1f s, hp left %.0f, damage taken %.0f, %d swings, %d rolls, %d bandages" % [
			label, "WON" if won else "LOST", game_time, result["hp"], damage_taken, swings, dodges, bandages])
	return result


func _spawn(kind: String, distance: float) -> Array:
	player.call(&"teleport", Vector3(0, 0, 8), Vector3(0, 0, -1))
	get_first_node_in_group(&"camera_rig").call(&"snap_behind_target")
	await _wait(0.2)
	var spawned: Array = arena.call(&"spawn", kind)
	for e: Node3D in spawned:
		e.global_position.z = 8.0 - distance
		e.set(&"_home", e.global_position)
		e.call(&"face_point", player.global_position)
		e.set(&"noticed", true)
		e.call(&"join_hunt", player.global_position)
	return spawned


func _initialize() -> void:
	gs = root.get_node("GameState")
	await process_frame
	arena = (load("res://scenes/test/combat_arena.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	await physics_frame
	player = arena.get_node("Player") as CharacterBody3D
	combat = player.get_node("Combat")
	for name: String in ["DummyLeft", "DummyRight", "Swordsman"]:
		arena.get_node(name).queue_free()
	await _wait(0.5)

	var wolves := await _fight("wolf pack (3)", await _spawn("wolf", 7.0))
	_check("Mara can beat a wolf pack", wolves["won"])
	arena.call(&"clear_enemies")
	await _wait(0.5)

	var bandit_list := await _spawn("bandit", 4.0)
	gs.call(&"set_flag", "%s_parley" % bandit_list[0].get(&"enemy_id"))  # Straight to the fight.
	var bandit := await _fight("bandit", bandit_list)
	_check("Mara can beat a bandit", bandit["won"])
	arena.call(&"clear_enemies")
	await _wait(0.5)

	var infected := await _fight("infected", await _spawn("infected", 4.0))
	_check("Mara can beat an infected", infected["won"])
	arena.call(&"clear_enemies")
	await _wait(0.5)

	gs.call(&"give", "steel_sword")
	gs.call(&"equip", "steel_sword")
	gs.call(&"give", "leather_armor")
	gs.call(&"equip", "leather_armor")
	var chief := await _fight("bandit chief (steel sword, leather armor)", await _spawn("chief", 5.0))
	_check("the chief is beatable with good gear", chief["won"])
	_check("the chief is a real fight", float(chief["taken"]) > 0.0 or int(chief["dodges"]) > 2, "taken %.0f" % chief["taken"])

	print("fight test: %d failure(s)" % failures)
	arena.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
