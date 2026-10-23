class_name WorldClock
extends Node
## Time passing in the open world: GameState.world_hour runs on (WorldConfig.seconds_per_hour
## real seconds per hour), the light follows the time of day (time_changed when the period
## changes), GameState.phase turns to NIGHT after dark so the infected grow bolder.
## Resting at a campfire sleeps until morning.

signal new_day(day: int)

var _period: String = ""


func _ready() -> void:
	add_to_group(&"world_clock")
	_sync_period(true)


func _process(delta: float) -> void:
	if GameState.controls_locked and DialogueRunner.is_active:
		return  # Time stands still while talking.
	advance(delta / GameState.WORLD.seconds_per_hour)


## Moves the clock on by `hours` (rolling over midnight into the next day).
func advance(hours: float) -> void:
	GameState.world_hour += hours
	while GameState.world_hour >= 24.0:
		GameState.world_hour -= 24.0
		GameState.world_day += 1
		new_day.emit(GameState.world_day)
	_sync_period(false)


## Sleeps by the campfire `place_id` until WorldConfig.wake_hour.
func rest(place_id: String) -> void:
	if GameState.controls_locked:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if not enemy.dead and enemy.state != Enemy.State.CALM \
				and enemy.global_position.distance_to(player.global_position) < GameState.WORLD.fast_travel_safe_distance:
			GameState.notified.emit("Не уснуть — враги рядом")
			return
	GameState.lock_controls()
	await Transition.fade_out(1.0)
	var hours := fposmod(GameState.WORLD.wake_hour - GameState.world_hour, 24.0)
	if hours < 1.0:
		hours += 24.0
	advance(hours)
	GameState.hero_health = maxf(GameState.hero_health, 0.0) + GameState.config.sleep_heal
	GameState.time_changed.emit()  # PlayerCombat picks up the healed health.
	GameState.save_game()
	await Transition.card(PackedStringArray(["День %d" % GameState.world_day, "Мара проснулась у костра. Угли ещё тёплые."]), 1.2)
	await Transition.fade_in(1.0)
	GameState.unlock_controls()


func _sync_period(force: bool) -> void:
	var period := GameState.world_period()
	if period == _period and not force:
		return
	_period = period
	GameState.phase = GameState.Phase.NIGHT if period == "night" else GameState.Phase.DAY
	GameState.time_changed.emit()
