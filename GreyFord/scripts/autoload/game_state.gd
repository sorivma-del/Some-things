extends Node
## Global game state: time (day, slot, night), herbs and medicine, the sick, story flags,
## hero stats, control lock, and saving/loading it all as JSON.
## Dialogue files read and write these directly (GameState.talked_helga, GameState.give_medicine("anka")).

signal flag_changed(flag: StringName, value: bool)
signal controls_locked_changed(locked: bool)
## Day, slot or phase changed.
signal time_changed
signal inventory_changed
signal sick_changed
## Mara was caught by a watchman or hunter. `herbs_lost` is how many herbs were taken.
signal caught(herbs_lost: int)
## Short on-screen message (HUD shows it as a toast).
signal notified(text: String)
signal trust_changed(npc: String, value: int, delta: int)
signal coins_changed(coins: int)
## A bandit's parley ended: outcome is "bribe", "persuade" or "fight".
signal parley_resolved(enemy_id: String, outcome: String)
signal equipment_changed
## A merchant's dialogue asked for the trade window.
signal trade_requested(merchant_id: String)
## A place in the open world was found for the first time.
signal place_discovered(id: String, display_name: String)

enum Phase { DAY, NIGHT }

const HERO_STATS: CharacterStats = preload("res://resources/mara_stats.tres")
const CONFIG: GameConfig = preload("res://resources/game_config.tres")
const ITEMS: ItemCatalog = preload("res://resources/items/catalog.tres")
const WORLD: WorldConfig = preload("res://resources/world/world_config.tres")
const MERCHANTS: Dictionary[String, MerchantData] = {
	"smith": preload("res://resources/merchants/smith.tres"),
	"herbwife": preload("res://resources/merchants/herbwife.tres"),
	"peddler": preload("res://resources/merchants/peddler.tres"),
}
const EQUIPMENT_SLOTS: PackedStringArray = ["weapon", "shield", "armor"]
const SAVE_PATH := "user://greyford_save.json"
const SAVE_VERSION := 3

var stats: CharacterStats = HERO_STATS
var config: GameConfig = CONFIG

var day: int = 1
var slots_used: int = 0
var phase: Phase = Phase.DAY
var herbs: Dictionary[String, int] = {}
var medicine: int = 0
var sick_health: Dictionary[String, int] = {}
var treated_today: Dictionary[String, bool] = {}
var caught_count: int = 0
## Villager id -> trust in Mara, 0..100.
var trust: Dictionary[String, int] = {}
## Herb spots already picked today (spot ids).
var picked_spots: PackedStringArray = []
var coins: int = 0:
	set(value):
		coins = maxi(value, 0)
		coins_changed.emit(coins)
## Where Mara comes back after falling in a fight (the last campfire she rested at).
var respawn_point: Vector3 = Vector3.ZERO
var has_respawn_point: bool = false
## In the open world ("Земли за Бродом") rather than the village.
var world_mode: bool = false
## Open-world places found so far: id -> true.
var discovered: Dictionary[String, bool] = {}
## Where Mara and her horse were in the open world when it was saved.
var world_position: Vector3 = Vector3.ZERO
var has_world_position: bool = false
var horse_position: Vector3 = Vector3.ZERO
var has_horse_position: bool = false
## Open-world clock: day number and hour (0..24).
var world_day: int = 1
var world_hour: float = 8.0
## Enemy group -> world day it was wiped out (it returns WorldConfig.respawn_days later).
var world_cleared: Dictionary[String, int] = {}
## Mara's health between scenes and in saves (PlayerCombat keeps it in step); <0 = full.
var hero_health: float = -1.0
## Mara's bag apart from herbs and the remedy (item id -> count). See count()/give()/take().
var items: Dictionary[String, int] = {}
## Slot ("weapon", "shield", "armor") -> item id ("" = empty). Worn items stay in `items`.
var equipment: Dictionary[String, String] = {}
## Merchant id -> {item id: count left}; refilled from MerchantData every morning.
var merchant_stock: Dictionary[String, Dictionary] = {}
## The enemy Mara is talking down right now, and its price and difficulty (for the dialogue).
var parley_enemy: String = ""
var parley_bribe: int = 0
var parley_difficulty: int = 0
## Free-form story flags for dialogues beyond the named ones below.
var flags: Dictionary[String, bool] = {}
## True while a new game should open with the intro cutscene.
var play_intro: bool = true
## Mara is in the forest behind the church (not saved: saves happen at dawn).
var in_forest: bool = false

var talked_helga: bool = false:
	set(value):
		if talked_helga != value:
			talked_helga = value
			flag_changed.emit(&"talked_helga", value)

var gate_open: bool = false:
	set(value):
		if gate_open != value:
			gate_open = value
			flag_changed.emit(&"gate_open", value)

## Tomash turned down Mara's plea; persuasion cannot be tried again.
var tomash_refused: bool = false:
	set(value):
		if tomash_refused != value:
			tomash_refused = value
			flag_changed.emit(&"tomash_refused", value)

var controls_locked: bool:
	get:
		return _lock_count > 0

var slots_left: int:
	get:
		return config.slots_per_day - slots_used

var slot_name: String:
	get:
		return config.slot_names[mini(slots_used, config.slot_names.size() - 1)]

var _lock_count: int = 0


func _ready() -> void:
	_setup_input()
	new_game()


#region Time

func spend_slot() -> void:
	slots_used = mini(slots_used + 1, config.slots_per_day)
	time_changed.emit()


## Evening is over: the sick get better or worse. Returns what happened, for the night title.
func begin_night() -> PackedStringArray:
	phase = Phase.NIGHT
	var report: PackedStringArray = []
	for patient: String in sick_health:
		var health := sick_health[patient]
		if health <= 0:
			continue
		health += 1 if treated_today.get(patient, false) else -1
		sick_health[patient] = clampi(health, 0, config.max_health)
		report.append(_night_line(patient, sick_health[patient], treated_today.get(patient, false)))
	treated_today.clear()
	sick_changed.emit()
	time_changed.emit()
	return report


func begin_day() -> void:
	day += 1
	slots_used = 0
	phase = Phase.DAY
	picked_spots.clear()
	merchant_stock.clear()  # Traders restock overnight.
	if hero_health >= 0.0:
		hero_health += config.sleep_heal  # PlayerCombat clamps to the maximum.
	time_changed.emit()
	save_game()


func _night_line(patient: String, health: int, treated: bool) -> String:
	var who := patient_name(patient)
	if health <= 0:
		return "%s не дожил до утра." % who
	if treated:
		return "%s спит спокойнее." % who if health >= config.max_health else "%s легче дышит." % who
	return "%s всю ночь горел в жару." % who

#endregion


#region Herbs and medicine

func herb_name(id: String) -> String:
	var i := config.herb_ids.find(id)
	return config.herb_names[i] if i >= 0 else id


func add_herb(id: String, spot_id: String) -> void:
	herbs[id] = herbs.get(id, 0) + 1
	picked_spots.append(spot_id)
	inventory_changed.emit()
	notified.emit("+1  %s" % herb_name(id))


## Loot from a fallen enemy or a found cache: coins or items. Returns a line for the HUD.
func add_loot(id: String, amount: int) -> String:
	if id == "coins":
		coins += amount
		return "+%d  монет" % amount
	give(id, amount)
	return "+%d  %s" % [amount, item_name(id)]

## Doses that can be brewed from the herbs in hand (one of each herb per dose).
func brewable_doses() -> int:
	var doses := 1 << 30
	for id: String in config.herb_ids:
		doses = mini(doses, herbs.get(id, 0))
	return doses


## Brews everything possible; returns the number of doses made.
func brew() -> int:
	var doses := brewable_doses()
	if doses <= 0:
		return 0
	for id: String in config.herb_ids:
		herbs[id] -= doses
	medicine += doses
	inventory_changed.emit()
	notified.emit("+%d  лекарство" % doses)
	return doses


func can_give(patient: String) -> bool:
	return medicine > 0 and is_alive(patient) and not treated_today.get(patient, false)


## Called from dialogue: one dose to a patient.
func give_medicine(patient: String) -> void:
	if not can_give(patient):
		return
	medicine -= 1
	treated_today[patient] = true
	inventory_changed.emit()
	notified.emit("Лекарство: %s" % patient_name(patient))

#endregion


#region The sick

func patient_name(patient: String) -> String:
	return {"anka": "Анка", "yan": "Ян"}.get(patient, patient)


func health(patient: String) -> int:
	return sick_health.get(patient, 0)


func is_alive(patient: String) -> bool:
	return health(patient) > 0

#endregion


#region Trust

const NPC_NAMES: Dictionary[String, String] = {
	"helga": "Хельга", "tomash": "Томаш", "anka": "Анка", "yan": "Ян", "olbrecht": "Ольбрехт",
	"smith": "Кузнец", "herbwife": "Травница", "peddler": "Сава",
}


func get_trust(npc: String) -> int:
	return trust.get(npc, 0)


## Called from dialogue and game events. Shows a short notification.
func change_trust(npc: String, delta: int) -> void:
	if delta == 0 or not trust.has(npc):
		return
	var before := trust[npc]
	trust[npc] = clampi(before + delta, 0, 100)
	var actual := trust[npc] - before
	if actual != 0:
		trust_changed.emit(npc, trust[npc], actual)
		notified.emit("%s  %s%d доверия" % [NPC_NAMES.get(npc, npc), "+" if actual > 0 else "−", absi(actual)])

#endregion


#region Flags and capture

func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value
	flag_changed.emit(StringName(flag), value)


func register_caught() -> void:
	caught_count += 1
	var lost := 0
	for id: String in herbs:
		var take := herbs[id] if config.herbs_lost_when_caught < 0 else mini(herbs[id], config.herbs_lost_when_caught)
		herbs[id] -= take
		lost += take
	set_flag("caught_%d" % caught_count)
	inventory_changed.emit()
	for npc: String in ["helga", "tomash", "yan"]:
		change_trust(npc, -config.trust_lost_when_caught)
	caught.emit(lost)

#endregion


#region Items, equipment and trade

func item(id: String) -> Item:
	return ITEMS.find(id)


func item_name(id: String) -> String:
	var found := item(id)
	return found.display_name if found else id


## How many Mara carries. Herbs and the remedy live in their own counters (brewing,
## healing the sick); everything else in `items`.
func count(id: String) -> int:
	if config.herb_ids.has(id):
		return herbs.get(id, 0)
	if id == "medicine":
		return medicine
	return items.get(id, 0)


func give(id: String, amount: int = 1) -> void:
	if config.herb_ids.has(id):
		herbs[id] = herbs.get(id, 0) + amount
	elif id == "medicine":
		medicine += amount
	else:
		items[id] = items.get(id, 0) + amount
	inventory_changed.emit()


func take(id: String, amount: int = 1) -> bool:
	if count(id) < amount:
		return false
	if config.herb_ids.has(id):
		herbs[id] -= amount
	elif id == "medicine":
		medicine -= amount
	else:
		items[id] -= amount
		if items[id] <= 0:
			items.erase(id)
	inventory_changed.emit()
	return true


## Everything in the bag, herbs and remedy included (id -> count, no zeros).
func bag() -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	for id: String in config.herb_ids:
		if count(id) > 0:
			result[id] = count(id)
	if medicine > 0:
		result["medicine"] = medicine
	for id: String in items:
		result[id] = items[id]
	return result


func equipped(slot: String) -> Item:
	return item(equipment.get(slot, ""))


func is_equipped(id: String) -> bool:
	return equipment.values().has(id)


## Copies of `id` that are not being worn (what can be sold).
func spare(id: String) -> int:
	return count(id) - (1 if is_equipped(id) else 0)


func equip(id: String) -> void:
	var found := item(id)
	if found == null or found.slot().is_empty() or count(id) <= 0:
		return
	equipment[found.slot()] = id
	equipment_changed.emit()


func unequip(slot: String) -> void:
	equipment[slot] = ""
	equipment_changed.emit()


## Called from a merchant's dialogue ("Торговать").
func open_trade(merchant_id: String) -> void:
	trade_requested.emit(merchant_id)


func stock(merchant_id: String) -> Dictionary:
	if not merchant_stock.has(merchant_id):
		restock(merchant_id)
	return merchant_stock[merchant_id]


func restock(merchant_id: String) -> void:
	var data := MERCHANTS[merchant_id]
	var goods := {}
	for i: int in data.stock_ids.size():
		goods[data.stock_ids[i]] = data.stock_counts[i] if i < data.stock_counts.size() else 1
	merchant_stock[merchant_id] = goods


func buy_price(merchant_id: String, id: String) -> int:
	return MERCHANTS[merchant_id].buy_price(item(id), get_trust(merchant_id))


func sell_price(merchant_id: String, id: String) -> int:
	return MERCHANTS[merchant_id].sell_price(item(id), get_trust(merchant_id))


func buy(merchant_id: String, id: String) -> bool:
	var goods := stock(merchant_id)
	var price := buy_price(merchant_id, id)
	if int(goods.get(id, 0)) <= 0 or coins < price:
		return false
	goods[id] = int(goods[id]) - 1
	coins -= price
	give(id)
	notified.emit("Куплено: %s  −%d" % [item_name(id), price])
	return true


func sell(merchant_id: String, id: String) -> bool:
	var found := item(id)
	if found == null or not MERCHANTS[merchant_id].buys(found) or spare(id) <= 0:
		return false
	var price := sell_price(merchant_id, id)
	take(id)
	var goods := stock(merchant_id)
	goods[id] = int(goods.get(id, 0)) + 1
	coins += price
	notified.emit("Продано: %s  +%d" % [found.display_name, price])
	return true

#endregion


#region Open world

## "morning", "day", "evening" or "night" by the open-world clock.
func world_period() -> String:
	if world_hour >= WORLD.night_hour or world_hour < WORLD.morning_hour:
		return "night"
	if world_hour >= WORLD.evening_hour:
		return "evening"
	if world_hour >= WORLD.day_hour:
		return "day"
	return "morning"


func world_clock_text() -> String:
	var minutes := int(world_hour * 60.0) % (24 * 60)
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func discover(id: String, display_name: String) -> void:
	if discovered.has(id):
		return
	discovered[id] = true
	set_flag("found_%s" % id)
	place_discovered.emit(id, display_name)
	notified.emit("Найдено место: %s" % display_name)

#endregion


#region Parley

## Dialogue helpers for a bandit that stopped Mara (see dialogues/bandit.dialogue).
func can_bribe() -> bool:
	return parley_bribe > 0 and coins >= parley_bribe


func resolve_parley(outcome: String) -> void:
	if outcome == "bribe":
		coins -= parley_bribe
	if not parley_enemy.is_empty():
		set_flag("%s_%s" % [parley_enemy, outcome])
	parley_resolved.emit(parley_enemy, outcome)

#endregion


#region Control lock

## Lock/unlock are counted so a cutscene and a dialogue can overlap safely.
func lock_controls() -> void:
	_lock_count += 1
	if _lock_count == 1:
		controls_locked_changed.emit(true)


func unlock_controls() -> void:
	if _lock_count == 0:
		return
	_lock_count -= 1
	if _lock_count == 0:
		controls_locked_changed.emit(false)


func reset_controls() -> void:
	_lock_count = 0
	controls_locked_changed.emit(false)

#endregion


#region New game, save and load

func new_game() -> void:
	day = 1
	slots_used = 0
	phase = Phase.DAY
	herbs.clear()
	for id: String in config.herb_ids:
		herbs[id] = 0
	medicine = 0
	sick_health = config.sick_start_health.duplicate()
	treated_today.clear()
	caught_count = 0
	trust = config.trust_start.duplicate()
	picked_spots.clear()
	flags.clear()
	talked_helga = false
	gate_open = false
	tomash_refused = false
	play_intro = true
	in_forest = false
	coins = config.start_coins
	has_respawn_point = false
	hero_health = -1.0
	world_mode = false
	discovered.clear()
	world_day = 1
	world_hour = WORLD.start_hour
	world_cleared.clear()
	has_world_position = false
	has_horse_position = false
	items.clear()
	for id: String in config.start_items:
		items[id] = config.start_items[id]
	equipment.clear()
	for slot: String in EQUIPMENT_SLOTS:
		var id: String = config.start_equipment.get(slot, "")
		equipment[slot] = id
		if not id.is_empty():
			items[id] = items.get(id, 0) + 1
	merchant_stock.clear()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## The scene a loaded save resumes in.
func saved_scene_path() -> String:
	return "res://scenes/world/open_world.tscn" if world_mode else "res://scenes/main.tscn"


func save_game() -> void:
	# Scene nodes (the open world, the horse) write their state into GameState first.
	if is_inside_tree():
		get_tree().call_group(&"save_hooks", &"before_save")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot write save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(to_dict(), "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	var version := int((data as Dictionary).get("version", 0)) if data is Dictionary else 0
	if version < 1 or version > SAVE_VERSION:
		push_warning("Save file is missing or from an unknown version")
		return false
	from_dict(data)
	return true


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"day": day,
		"herbs": herbs,
		"medicine": medicine,
		"sick_health": sick_health,
		"caught_count": caught_count,
		"trust": trust,
		"flags": flags,
		"talked_helga": talked_helga,
		"tomash_refused": tomash_refused,
		"coins": coins,
		"items": items,
		"equipment": equipment,
		"hero_health": hero_health,
		"scene": "world" if world_mode else "village",
		"world_day": world_day,
		"world_hour": world_hour,
		"discovered": discovered.keys(),
		"world_cleared": world_cleared,
		"world_position": [world_position.x, world_position.y, world_position.z] if has_world_position else [],
		"horse_position": [horse_position.x, horse_position.y, horse_position.z] if has_horse_position else [],
	}


## Saves are written at the start of a day, so a load always resumes a fresh morning.
func from_dict(data: Dictionary) -> void:
	new_game()
	day = int(data.get("day", 1))
	for id: String in (data.get("herbs", {}) as Dictionary):
		herbs[id] = int(data["herbs"][id])
	medicine = int(data.get("medicine", 0))
	for patient: String in (data.get("sick_health", {}) as Dictionary):
		sick_health[patient] = int(data["sick_health"][patient])
	caught_count = int(data.get("caught_count", 0))
	for npc: String in (data.get("trust", {}) as Dictionary):
		trust[npc] = int(data["trust"][npc])
	for flag: String in (data.get("flags", {}) as Dictionary):
		flags[flag] = bool(data["flags"][flag])
	talked_helga = bool(data.get("talked_helga", false))
	tomash_refused = bool(data.get("tomash_refused", false))
	# Version 1 saves have no purse or gear: they keep the new-game ones.
	if data.has("coins"):
		coins = int(data["coins"])
		items.clear()
		for id: String in (data.get("items", {}) as Dictionary):
			items[id] = int(data["items"][id])
		for slot: String in (data.get("equipment", {}) as Dictionary):
			equipment[slot] = str(data["equipment"][slot])
		hero_health = float(data.get("hero_health", -1.0))
	# Version 3: the open world.
	world_mode = str(data.get("scene", "village")) == "world"
	world_day = int(data.get("world_day", 1))
	world_hour = float(data.get("world_hour", WORLD.start_hour))
	for id: Variant in (data.get("discovered", []) as Array):
		discovered[str(id)] = true
	for group: String in (data.get("world_cleared", {}) as Dictionary):
		world_cleared[group] = int(data["world_cleared"][group])
	var spot: Array = data.get("world_position", [])
	has_world_position = spot.size() == 3
	if has_world_position:
		world_position = Vector3(spot[0], spot[1], spot[2])
	var horse: Array = data.get("horse_position", [])
	has_horse_position = horse.size() == 3
	if has_horse_position:
		horse_position = Vector3(horse[0], horse[1], horse[2])
	play_intro = false

#endregion


func _setup_input() -> void:
	# Physical keycodes so WASD/E work on any keyboard layout (including Russian).
	var bindings: Dictionary[StringName, Key] = {
		&"move_forward": KEY_W,
		&"move_back": KEY_S,
		&"move_left": KEY_A,
		&"move_right": KEY_D,
		&"interact": KEY_E,
		&"attack": KEY_J,
		&"heavy_attack": KEY_K,
		&"block": KEY_SHIFT,
		&"roll": KEY_SPACE,
		&"lock_on": KEY_Q,
		&"switch_target": KEY_TAB,
		&"heal": KEY_H,
		&"inventory": KEY_I,
		&"sprint": KEY_SHIFT,
		&"call_horse": KEY_X,
		&"map": KEY_M,
	}
	for action: StringName in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)
	# Right mouse button stays the camera orbit.
	var mouse: Dictionary[StringName, MouseButton] = {&"attack": MOUSE_BUTTON_LEFT, &"lock_on": MOUSE_BUTTON_MIDDLE}
	for action: StringName in mouse:
		var click := InputEventMouseButton.new()
		click.button_index = mouse[action]
		InputMap.action_add_event(action, click)
