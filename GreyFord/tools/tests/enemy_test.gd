extends SceneTree
## Headless check of the enemies on the combat arena:
## godot --headless --path GreyFord -s res://tools/tests/enemy_test.gd
## Class names that need the autoloads are avoided (a -s script compiles first), so
## states are mirrored as numbers.

const PATROL := 0
const SUSPICIOUS := 1
const CHASE := 2
const ATTACK := 4
const STAGGER := 5
const RETREAT := 6
const PARLEY := 7
const CALM := 8
const DEAD := 9
const HIT_INFO := preload("res://scripts/combat/hit_info.gd")

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


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)


## Watches an enemy for up to `limit` seconds; returns every state it passed through.
func _watch(enemy: Node, limit: float, until_state: int = -1) -> Dictionary:
	var seen := {}
	var t := 0.0
	while t < limit and is_instance_valid(enemy):
		seen[int(enemy.get(&"state"))] = true
		if until_state >= 0 and int(enemy.get(&"state")) == until_state:
			break
		await physics_frame
		t += 1.0 / 60.0
	return seen


func _strike(enemy: Node, damage: float) -> void:
	var to: Vector3 = enemy.get(&"global_position") - player.global_position
	to.y = 0.0
	var info: RefCounted = HIT_INFO.new(damage, 3.0, player, to.normalized())
	(enemy.get(&"_hurtbox") as Node).call(&"receive", info)


func _place(enemy: Node3D, distance: float) -> void:
	enemy.global_position = player.global_position + Vector3(0, 0.1, -distance)
	enemy.set(&"_home", enemy.global_position)
	enemy.call(&"face_point", player.global_position)


func _spawn(kind: String) -> Array:
	return arena.call(&"spawn", kind)


## Answers the bandit's parley: picks response `pick` (1-based) at the first choice.
func _answer_parley(pick: int) -> void:
	var picked := false
	for step: int in 60:
		var balloon: Node = null
		for child: Node in root.get_children():
			if child.get(&"_responses") != null:
				balloon = child
		if balloon == null:
			return
		var label := balloon.get(&"_text") as Node
		if label.get(&"is_typing"):
			await _wait(0.3)
			continue
		var box := balloon.get(&"_responses_box") as Node
		if not picked and box.get_child_count() > 0:
			_key([KEY_1, KEY_2, KEY_3][pick - 1])
			picked = true
		else:
			_key(KEY_E)
		await _wait(0.35)


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
	player.call(&"teleport", Vector3(0, 0, 8), Vector3(0, 0, -1))
	await _wait(0.5)
	var regions: int = NavigationServer3D.map_get_regions(player.get_world_3d().navigation_map).size()
	_check("arena has a navigation mesh", regions > 0)

	# --- Wolves: the pack gives chase together, bites with a telegraph, hops back.
	combat.set(&"invulnerable", true)
	var wolves := _spawn("wolf")
	_check("wolf pack of 3", wolves.size() == 3)
	var seen := await _watch(wolves[1], 6.0, ATTACK)
	var chasing := wolves.filter(func(w: Node) -> bool: return int(w.get(&"state")) in [CHASE, ATTACK, RETREAT])
	_check("whole pack chases", chasing.size() == 3, "%d of 3" % chasing.size())
	seen.merge(await _watch(wolves[1], 4.0, RETREAT))
	_check("wolf bites (telegraph window) and hops back", seen.has(ATTACK) and seen.has(RETREAT), str(seen.keys()))
	combat.set(&"invulnerable", false)
	combat.call(&"restore")
	var hp: float = combat.get(&"health")
	await _watch(wolves[0], 5.0)
	_check("wolves hurt Mara", float(combat.get(&"health")) < hp, "%.0f -> %.0f" % [hp, combat.get(&"health")])
	combat.set(&"invulnerable", true)
	for wolf: Node in wolves:
		_strike(wolf, 100.0)
	await _wait(0.3)
	_check("wolves die", wolves.all(func(w: Node) -> bool: return not is_instance_valid(w) or int(w.get(&"state")) == DEAD))
	arena.call(&"clear_enemies")
	for drop: Node in arena.find_children("*", "Area3D", true, false):
		if drop.get(&"contents") != null:
			drop.queue_free()
	await _wait(0.3)

	# --- Bandit: stops Mara to talk; persuasion or a bribe make him stand aside.
	player.call(&"teleport", Vector3(0, 0, 8), Vector3(0, 0, -1))
	gs.set("coins", 40)
	var bandit: Node3D = _spawn("bandit")[0]
	_place(bandit, 7.0)
	seen = await _watch(bandit, 8.0, PARLEY)
	var t := 0.0
	while not root.get_node("DialogueRunner").get(&"is_active") and t < 8.0:
		await _wait(0.1)
		t += 0.1
	_check("bandit stops Mara to talk", root.get_node("DialogueRunner").get(&"is_active"), str(seen.keys()))
	await _answer_parley(1)
	await _wait(0.3)
	_check("bribe: bandit stands aside", int(bandit.get(&"state")) == CALM, "state %d" % bandit.get(&"state"))
	_check("bribe costs coins and sets a flag", gs.get("coins") == 25 and gs.call(&"has_flag", "%s_bribe" % bandit.get(&"enemy_id")), "coins %d" % gs.get("coins"))
	await _wait(1.0)
	_check("bribed bandit stays calm", int(bandit.get(&"state")) == CALM)
	_strike(bandit, 10.0)
	await _wait(0.6)
	_check("striking a calm bandit makes him fight", int(bandit.get(&"state")) in [CHASE, ATTACK, STAGGER], "state %d" % bandit.get(&"state"))

	# Fight: windup telegraph 0.4-0.6 s, alternating blow and pause; loot on death.
	var attack: Resource = bandit.get(&"attack")
	_check("bandit windup 0.4-0.6 s", float(attack.get(&"windup")) >= 0.4 and float(attack.get(&"windup")) <= 0.6, "%.2f" % attack.get(&"windup"))
	combat.set(&"invulnerable", true)
	seen = await _watch(bandit, 6.0)
	_check("bandit attacks", seen.has(ATTACK), str(seen.keys()))
	var coins: int = gs.get("coins")
	player.call(&"teleport", bandit.global_position + Vector3(0, 0, 6))
	await _wait(0.3)
	coins = gs.get("coins")
	_strike(bandit, 200.0)
	await _wait(0.3)
	var drops := arena.find_children("*", "Area3D", true, false).filter(func(n: Node) -> bool: return n.get(&"contents") != null)
	_check("bandit drops loot", drops.size() == 1)
	if drops.size() == 1:
		player.call(&"teleport", (drops[0] as Node3D).global_position)
		await _wait(0.4)
	_check("loot picked up", int(gs.get("coins")) >= coins + 6, "%d -> %d" % [coins, gs.get("coins")])
	_check("kill flag", gs.call(&"has_flag", "%s_killed" % bandit.get(&"enemy_id")))
	arena.call(&"clear_enemies")
	await _wait(0.3)

	# Persuasion with a guaranteed roll: Mara talks the next bandit down.
	player.call(&"teleport", Vector3(0, 0, 8), Vector3(0, 0, -1))
	gs.set("coins", 0)
	bandit = _spawn("bandit")[0]
	_place(bandit, 6.0)
	bandit.get(&"data").set(&"persuade_difficulty", 1)
	t = 0.0
	while not root.get_node("DialogueRunner").get(&"is_active") and t < 8.0:
		await _wait(0.1)
		t += 0.1
	await _answer_parley(1)  # The bribe line is hidden without coins: 1 = persuade.
	await _wait(0.3)
	_check("persuaded bandit stands aside", int(bandit.get(&"state")) == CALM and gs.call(&"has_flag", "%s_persuade" % bandit.get(&"enemy_id")), "state %d" % bandit.get(&"state"))
	bandit.get(&"data").set(&"persuade_difficulty", 13)
	arena.call(&"clear_enemies")
	await _wait(0.3)

	# --- Infected: slow, tough, long telegraph; bolder at night.
	player.call(&"teleport", Vector3(0, 0, 8), Vector3(0, 0, -1))
	var infected: Node3D = _spawn("infected")[0]
	_place(infected, 5.0)
	attack = infected.get(&"attack")
	_check("infected long telegraph", float(attack.get(&"windup")) >= 0.8, "%.2f s" % attack.get(&"windup"))
	_strike(infected, 20.0)
	await _wait(0.1)
	_check("infected shrugs off a light blow (poise)", int(infected.get(&"state")) != STAGGER)
	var day_speed: float = infected.call(&"_speed_multiplier")
	arena.call(&"toggle_night")
	var night_speed: float = infected.call(&"_speed_multiplier")
	_check("infected faster at night", night_speed > day_speed, "%.2f -> %.2f" % [day_speed, night_speed])
	arena.call(&"toggle_night")
	seen = await _watch(infected, 8.0, ATTACK)
	_check("infected attacks", seen.has(ATTACK), str(seen.keys()))
	arena.call(&"clear_enemies")
	await _wait(0.3)

	# --- Bandit chief: second phase below half health brings a new, faster attack.
	player.call(&"teleport", Vector3(0, 0, 8), Vector3(0, 0, -1))
	var chief: Node3D = _spawn("chief")[0]
	_place(chief, 4.0)
	await _wait(0.5)
	_check("chief starts in phase one", not chief.get(&"phase_two"))
	_strike(chief, 120.0)
	await _wait(0.2)
	_check("chief enters phase two", chief.get(&"phase_two"))
	var dash_seen := false
	for i: int in 400:
		await _wait(0.05)
		if (chief.get(&"attack") as Resource).get(&"animation") == &"Sword_Dash" and int(chief.get(&"state")) == ATTACK:
			dash_seen = true
			break
	_check("phase-two dash attack used", dash_seen)

	print("enemy test: %d failure(s)" % failures)
	arena.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
