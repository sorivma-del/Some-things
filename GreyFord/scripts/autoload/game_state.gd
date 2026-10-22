extends Node
## Global game state: story flags, hero stats, control lock.
## Dialogue files read and write the flag properties directly (GameState.talked_helga).

signal flag_changed(flag: StringName, value: bool)
signal controls_locked_changed(locked: bool)

const HERO_STATS: CharacterStats = preload("res://resources/mara_stats.tres")

var stats: CharacterStats = HERO_STATS

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

var _lock_count: int = 0


func _ready() -> void:
	_setup_input()


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
