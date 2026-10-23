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

enum Phase { DAY, NIGHT }

const HERO_STATS: CharacterStats = preload("res://resources/mara_stats.tres")
const CONFIG: GameConfig = preload("res://resources/game_config.tres")
const SAVE_PATH := "user://greyford_save.json"
const SAVE_VERSION := 1

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


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot write save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(to_dict(), "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or (data as Dictionary).get("version", 0) != SAVE_VERSION:
		push_warning("Save file is missing or from another version")
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
	}
	for action: StringName in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)
