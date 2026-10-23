extends SceneTree
## Headless check of the combat prototype on the arena:
## godot --headless --path GreyFord -s res://tools/tests/combat_test.gd

var gs: Node
var arena: Node3D
var player: CharacterBody3D
var combat: Node
var failures: int = 0
# Class names (PlayerCombat, SparringPartner) need the autoloads, which a -s script
# compiles before, so states are mirrored here.
const HERO_DEAD := 5
const PARTNER_WINDUP := 2
const PARTNER_RECOVERY := 4


func _check(label: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["OK  " if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _initialize() -> void:
	gs = root.get_node("GameState")
	await process_frame
	arena = (load("res://scenes/test/combat_arena.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	await physics_frame
	player = arena.get_node("Player") as CharacterBody3D
	combat = player.get_node("Combat")
	var dummy: Node3D = arena.get_node("DummyLeft")
	var partner: Node3D = arena.get_node("Swordsman")
	partner.process_mode = Node.PROCESS_MODE_DISABLED  # Keep him out of the first checks.
	await _wait(0.5)

	# 1. One swing = one hit, stamina spent, then regenerates after the delay.
	player.call(&"teleport", dummy.global_position + Vector3(0, 0, 1.4), Vector3(0, 0, -1))
	await _wait(0.3)
	var hp: float = dummy.get(&"health")
	await _tap(&"attack")
	await _wait(0.9)
	_check("attack hits once", is_equal_approx(hp - dummy.get(&"health"), float(combat.get(&"data").get(&"damage"))), "dummy %.0f -> %.0f" % [hp, dummy.get(&"health")])
	_check("attack spends stamina", combat.get(&"stamina") < float(combat.get(&"data").get(&"max_stamina")), "stamina %.0f" % combat.get(&"stamina"))
	await _wait(float(combat.get(&"data").get(&"stamina_regen_delay")) + 1.5)
	_check("stamina regenerates", is_equal_approx(combat.get(&"stamina"), float(combat.get(&"data").get(&"max_stamina"))), "stamina %.0f" % combat.get(&"stamina"))

	# 2. Lock-on picks the dummy in front, switch moves to the other one, release by key.
	await _tap(&"lock_on")
	_check("lock-on target", combat.get(&"target") != null, str((combat.get(&"target") as Node).name if combat.get(&"target") else "none"))
	var first: Node = combat.get(&"target")
	await _tap(&"switch_target")
	_check("switch target", combat.get(&"target") != null and combat.get(&"target") != first, str((combat.get(&"target") as Node).name if combat.get(&"target") else "none"))
	await _tap(&"lock_on")
	_check("release lock", combat.get(&"target") == null)

	# 3. Fell the dummy: queued attacks chain, it topples and stands up again.
	for i: int in 8:
		await _tap(&"attack")
		await _wait(0.35)
		if dummy.get(&"dead"):
			break
	_check("dummy falls", dummy.get(&"dead"), "hp %.0f" % dummy.get(&"health"))
	await _wait(float(dummy.get(&"data").get(&"revive_time")) + 0.3)
	_check("dummy stands up", not dummy.get(&"dead") and is_equal_approx(dummy.get(&"health"), float(dummy.get(&"data").get(&"max_health"))))

	# 4. Partner attacks: blocked with the shield (no damage), then rolled through, then hits.
	partner.process_mode = Node.PROCESS_MODE_INHERIT
	partner.global_position = Vector3(0, 0, -2)
	player.call(&"teleport", Vector3(0, 0, -0.4), Vector3(0, 0, -1))
	combat.call(&"restore")
	Input.action_press(&"block")
	var waited := 0.0
	while partner.get(&"state") != PARTNER_RECOVERY and waited < 6.0:
		await physics_frame
		waited += 1.0 / 60.0
	Input.action_release(&"block")
	_check("block stops damage", is_equal_approx(combat.get(&"health"), float(combat.get(&"data").get(&"max_health"))), "hp %.0f, stamina %.0f" % [combat.get(&"health"), combat.get(&"stamina")])
	_check("block costs stamina", combat.get(&"stamina") < float(combat.get(&"data").get(&"max_stamina")))

	combat.call(&"restore")
	while partner.get(&"state") != PARTNER_WINDUP:
		await physics_frame
	await _wait(float(partner.get(&"data").get(&"windup")) - 0.08)
	await _tap(&"roll")
	await _wait(0.6)
	_check("roll i-frames dodge", is_equal_approx(combat.get(&"health"), float(combat.get(&"data").get(&"max_health"))), "hp %.0f" % combat.get(&"health"))

	player.call(&"teleport", partner.global_position + Vector3(0, 0, 1.5), Vector3(0, 0, -1))
	combat.call(&"restore")
	while partner.get(&"state") != PARTNER_WINDUP:
		await physics_frame
	while partner.get(&"state") != PARTNER_RECOVERY:
		await physics_frame
	_check("unguarded hit hurts", combat.get(&"health") < float(combat.get(&"data").get(&"max_health")), "hp %.0f" % combat.get(&"health"))

	# 5. Death: respawn at the last campfire, a quarter of the coins gone, flags kept.
	gs.call(&"set_flag", "test_flag")
	var coins: int = gs.get("coins")
	var fire := arena.get_node("CampfireNorth") as Node3D
	player.call(&"teleport", fire.global_position + Vector3(0, 0, 2))
	await _wait(0.3)
	player.call(&"teleport", partner.global_position + Vector3(0, 0, 1.5), Vector3(0, 0, -1))
	combat.set(&"health", 1.0)
	waited = 0.0
	while combat.get(&"state") != HERO_DEAD and waited < 8.0:
		await _wait(0.1)
		waited += 0.1
	_check("hero dies", combat.get(&"state") == HERO_DEAD)
	while gs.get("controls_locked"):
		await _wait(0.2)
	await _wait(0.2)
	var at_fire := player.global_position.distance_to(fire.global_position) < 3.5
	_check("respawn at last campfire", at_fire, "%.1f m from it" % player.global_position.distance_to(fire.global_position))
	_check("coins lost", gs.get("coins") == coins - ceili(coins * float(combat.get(&"data").get(&"death_coin_loss"))), "%d -> %d" % [coins, gs.get("coins")])
	_check("flags kept", gs.call(&"has_flag", "test_flag"))
	_check("health restored", is_equal_approx(combat.get(&"health"), float(combat.get(&"data").get(&"max_health"))))

	print("combat test: %d failure(s)" % failures)
	arena.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
