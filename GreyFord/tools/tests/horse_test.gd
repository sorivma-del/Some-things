extends SceneTree
## Headless check of riding in the open world:
## godot --headless --path GreyFord -s res://tools/tests/horse_test.gd

var gs: Node
var world: Node3D
var player: CharacterBody3D
var horse: CharacterBody3D
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


func _initialize() -> void:
	gs = root.get_node("GameState")
	await process_frame
	gs.call(&"new_game")
	world = (load("res://scenes/world/open_world.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(world)
	player = world.get_node("Player") as CharacterBody3D
	await _wait(1.0)
	gs.call(&"reset_controls")
	horse = get_first_node_in_group(&"horse") as CharacterBody3D
	_check("a horse waits at the crossroads", horse != null and horse.global_position.distance_to(Vector3(6, horse.global_position.y, 86)) < 3.0)

	# Mount with E next to the horse.
	player.call(&"teleport", horse.global_position + Vector3(0, 0, 1.6))
	await _wait(0.4)
	_key(KEY_E)
	await _wait(0.3)
	_check("E mounts the horse", horse.call(&"is_ridden") and player.get(&"mount") == horse)
	_check("the horse becomes hers", gs.call(&"has_flag", "horse_owned"))

	# Ride south along the road: the camera faces the horse's heading.
	get_first_node_in_group(&"camera_rig").set(&"yaw_degrees", rad_to_deg(horse.rotation.y))
	var start := horse.global_position
	Input.action_press(&"move_forward")
	await _wait(3.0)
	var trot: float = horse.get(&"speed")
	_check("W trots", trot > 5.0, "%.1f m/s, moved %.1f m" % [trot, start.distance_to(horse.global_position)])
	_check("Mara rides along", player.global_position.distance_to(horse.global_position) < 2.0)
	Input.action_press(&"sprint")
	await _wait(3.0)
	var gallop: float = horse.get(&"speed")
	_check("Shift gallops", gallop > trot + 2.0, "%.1f m/s" % gallop)
	_check("galloping tires the horse", float(horse.get(&"stamina")) < 100.0, "stamina %.0f" % horse.get(&"stamina"))
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	await _wait(2.0)
	_check("the horse stops without input", float(horse.get(&"speed")) < 0.5)

	# Get off with E.
	_key(KEY_E)
	await _wait(0.3)
	_check("E dismounts", not horse.call(&"is_ridden") and player.get(&"mount") == null)
	_check("Mara stands beside the horse", player.global_position.distance_to(horse.global_position) < 3.0)

	# Walk far away and whistle: the horse comes.
	player.call(&"teleport", Vector3(-110, 1, 72))
	await _wait(0.5)
	_key(KEY_X)
	var t := 0.0
	while horse.global_position.distance_to(player.global_position) > 5.0 and t < 20.0:
		await _wait(0.5)
		t += 0.5
	_check("X calls the horse", horse.global_position.distance_to(player.global_position) <= 5.0, "%.1f m after %.1f s" % [horse.global_position.distance_to(player.global_position), t])

	print("horse test: %d failure(s)" % failures)
	world.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
