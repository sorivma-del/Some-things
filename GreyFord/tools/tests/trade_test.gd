extends SceneTree
## Headless check of the economy on the combat arena (merchants stand by the east wall):
## godot --headless --path GreyFord -s res://tools/tests/trade_test.gd

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


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


## Talks to a merchant and picks the first answer ("Торговать").
func _talk_and_trade(merchant: Node3D) -> void:
	player.call(&"teleport", merchant.global_position + (merchant.global_basis * Vector3(0, 0, -1.2)), Vector3.ZERO)
	await _wait(0.3)
	_key(KEY_E)
	await _wait(0.3)
	var picked := false
	for step: int in 40:
		var balloon: Node = null
		for child: Node in root.get_children():
			if child.get(&"_responses") != null:
				balloon = child
		if balloon == null:
			return
		if (balloon.get(&"_text") as Node).get(&"is_typing"):
			await _wait(0.25)
			continue
		if not picked and (balloon.get(&"_responses_box") as Node).get_child_count() > 0:
			_key(KEY_1)
			picked = true
		else:
			_key(KEY_E)
		await _wait(0.3)


func _trade_window() -> Node:
	return get_first_node_in_group(&"trade_window")


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
	await _wait(0.4)

	# Start: sword and shield worn, two bandages.
	_check("starts with sword and shield", gs.get("equipment")["weapon"] == "bronze_sword" and gs.get("equipment")["shield"] == "wooden_shield")
	_check("starts with bandages", gs.call(&"count", "bandage") == 2)

	# Prices: selling always pays less than buying; trust lowers prices.
	var cheaper_ok := true
	for merchant: String in ["smith", "herbwife", "peddler"]:
		for trust: int in [0, 50, 100]:
			(gs.get("trust") as Dictionary)[merchant] = trust
			for item: Resource in (gs.get("ITEMS") as Resource).get(&"items"):
				var id: String = item.get(&"id")
				if gs.call(&"sell_price", merchant, id) >= gs.call(&"buy_price", merchant, id):
					cheaper_ok = false
					print("  ", merchant, " ", id, " trust ", trust)
	_check("sell price below buy price everywhere", cheaper_ok)
	(gs.get("trust") as Dictionary)["smith"] = 20
	var low: int = gs.call(&"buy_price", "smith", "leather_armor")
	(gs.get("trust") as Dictionary)["smith"] = 80
	var high: int = gs.call(&"buy_price", "smith", "leather_armor")
	_check("trust lowers prices", high < low, "trust 20: %d, trust 80: %d" % [low, high])
	(gs.get("trust") as Dictionary)["smith"] = 40

	# The smith's dialogue opens the trade window; buy leather armor.
	gs.set("coins", 300)
	await _talk_and_trade(arena.get_node("Smith"))
	await _wait(0.3)
	var window := _trade_window()
	_check("dialogue opens trade window", window.get(&"is_open") and window.get(&"merchant_id") == "smith")
	var price: int = gs.call(&"buy_price", "smith", "leather_armor")
	window.call(&"_buy", "leather_armor")
	_check("buy armor", gs.call(&"count", "leather_armor") == 1 and gs.get("coins") == 300 - price, "price %d, coins %d" % [price, gs.get("coins")])
	_check("stock goes down", int(gs.call(&"stock", "smith")["leather_armor"]) == 0)
	window.call(&"_buy", "woodsman_axe")
	_check("buy axe", gs.call(&"count", "woodsman_axe") == 1)
	_check("cannot sell the only worn sword", not gs.call(&"sell", "smith", "bronze_sword"))
	_check("smith does not buy herbs", not gs.call(&"sell", "smith", "wormwood"))
	window.call(&"close_window")
	await _wait(0.1)
	_check("closing unlocks controls", not gs.get("controls_locked"))

	# Equipment changes damage and defense.
	gs.call(&"equip", "woodsman_axe")
	gs.call(&"equip", "leather_armor")
	await _wait(0.1)
	_check("axe damage", is_equal_approx(float(combat.call(&"attack_damage")), 26.0), "%.0f" % combat.call(&"attack_damage"))
	combat.call(&"restore")
	var info: RefCounted = HIT_INFO.new(20.0, 0.0, player, Vector3.FORWARD)
	(combat.get(&"_hurtbox") as Node).call(&"receive", info)
	_check("armor absorbs damage", is_equal_approx(float(combat.get(&"health")), 100.0 - 20.0 * 0.78), "health %.1f" % combat.get(&"health"))
	_check("old sword now sellable", gs.call(&"sell", "smith", "bronze_sword"))

	# Herbs and the remedy sell to the herb-seller.
	await _wait(1.0)
	gs.call(&"give", "wormwood", 3)
	gs.set("medicine", 1)
	var coins: int = gs.get("coins")
	_check("sell herb", gs.call(&"sell", "herbwife", "wormwood") and gs.call(&"count", "wormwood") == 2)
	_check("sell remedy", gs.call(&"sell", "herbwife", "medicine") and gs.get("medicine") == 0)
	_check("selling pays coins", int(gs.get("coins")) > coins, "%d -> %d" % [coins, gs.get("coins")])
	_check("buy herb back", gs.call(&"buy", "herbwife", "burnet") and gs.call(&"count", "burnet") == 1)

	# Bandage with H.
	combat.set(&"health", 50.0)
	await _tap(&"heal")
	await _wait(0.1)
	_check("bandage heals", is_equal_approx(float(combat.get(&"health")), 75.0) and gs.call(&"count", "bandage") == 1, "health %.0f" % combat.get(&"health"))

	# Inventory window toggles with I and lists the bag.
	_key(KEY_I)
	await _wait(0.2)
	var inventory := get_first_node_in_group(&"inventory_window")
	_check("inventory opens with I", inventory.get(&"is_open") and gs.get("controls_locked"))
	_key(KEY_I)
	await _wait(0.2)
	_check("inventory closes with I", not inventory.get(&"is_open") and not gs.get("controls_locked"))

	# Loot names come from the catalog; merchants restock at dawn.
	_check("loot uses item names", str(gs.call(&"add_loot", "wolf_pelt", 1)).contains("Волчья шкура"))
	gs.call(&"begin_day")
	_check("restock at dawn", int(gs.call(&"stock", "smith")["leather_armor"]) == 1)

	print("trade test: %d failure(s)" % failures)
	arena.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
