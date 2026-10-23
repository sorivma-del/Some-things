class_name Horse
extends CharacterBody3D
## Mara's horse. E next to it to mount, E again to get off. Riding: W/A/S/D like on foot
## (the horse turns towards the direction, it does not strafe), Shift to gallop while it
## has breath. X whistles: an owned horse comes running, or appears behind Mara if far.
## The first ride makes it hers (flag horse_owned).

signal mounted_changed(ridden: bool)
signal stamina_changed(value: float, max_value: float)

enum State { IDLE, RIDDEN, CALLED }

const GROUP := &"horse"

@export var data: HorseData = preload("res://resources/world/horse.tres")

var state: State = State.IDLE
var stamina: float
var speed: float = 0.0

var _rider: CharacterBody3D
var _model: AnimatedModel
var _mount: Interactable
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _since_gallop: float = 100.0
var _idle_time: float = 0.0
var _stuck_time: float = 0.0
var _last_position: Vector3
var _gait_time: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 1 << 1
	collision_mask = 1
	floor_max_angle = deg_to_rad(50.0)
	stamina = data.max_stamina
	_model = get_node(^"Model") as AnimatedModel
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 2.7
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.rotation.x = PI * 0.5
	shape.position.y = 1.2
	add_child(shape)
	_mount = Interactable.new()
	_mount.prompt = "Сесть верхом"
	_mount.radius = 1.6
	_mount.position = Vector3(0, 1.0, 0)
	add_child(_mount)
	_mount.interacted.connect(mount)
	_add_tack()


## Saddle and blanket from simple shapes, sitting where Mara rides.
func _add_tack() -> void:
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.16, 0.09, 0.05)
	leather.roughness = 0.7
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.32, 0.08, 0.06)
	cloth.roughness = 1.0
	var seat := data.seat
	Build.box(self, Vector3(0.62, 0.04, 0.95), seat + Vector3(0, 0.4, 0.02), cloth)
	Build.box(self, Vector3(0.5, 0.1, 0.6), seat + Vector3(0, 0.45, 0.02), leather)
	Build.box(self, Vector3(0.36, 0.14, 0.08), seat + Vector3(0, 0.55, -0.28), leather)
	Build.box(self, Vector3(0.4, 0.1, 0.07), seat + Vector3(0, 0.53, 0.3), leather)
	for side: float in [-1.0, 1.0]:
		Build.box(self, Vector3(0.03, 0.5, 0.05), seat + Vector3(side * 0.27, 0.2, 0.0), leather)
		Build.box(self, Vector3(0.1, 0.03, 0.1), seat + Vector3(side * 0.3, -0.06, 0.0), leather)


## Rider's bounce and forward lean for the current gait (used by Player while mounted).
func rider_motion() -> Vector2:
	var gallop := clampf((speed - data.trot_speed) / (data.gallop_speed - data.trot_speed), 0.0, 1.0)
	var trot := clampf(speed / data.trot_speed, 0.0, 1.0)
	var bounce := sin(_gait_time * TAU) * (0.025 * trot + 0.05 * gallop)
	return Vector2(bounce, 0.08 * trot + 0.22 * gallop)


func is_owned() -> bool:
	return GameState.has_flag("horse_owned")


func is_ridden() -> bool:
	return state == State.RIDDEN


func mount() -> void:
	if state == State.RIDDEN:
		return
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if player == null:
		return
	if not is_owned():
		GameState.set_flag("horse_owned")
		GameState.notified.emit("Лошадь признала Мару. X — позвать её")
	_rider = player
	state = State.RIDDEN
	_mount.enabled = false
	_mount.monitorable = false
	player.call(&"mount_on", self)
	get_tree().call_group(&"camera_rig", &"set_follow_view", data.camera_distance, data.camera_height)
	var combat := player.get_node_or_null(^"Combat") as PlayerCombat
	if combat and not combat.died.is_connected(dismount):
		combat.died.connect(dismount)
	mounted_changed.emit(true)


func dismount() -> void:
	if state != State.RIDDEN:
		return
	state = State.IDLE
	speed = 0.0
	var side := global_basis.x.normalized() * -1.4
	var spot := global_position + side
	_rider.call(&"dismount_at", spot, -global_basis.z)
	_rider = null
	_mount.enabled = true
	_mount.monitorable = true
	get_tree().call_group(&"camera_rig", &"set_follow_view", -1.0, -1.0)
	mounted_changed.emit(false)


## Whistle: run to Mara, or appear behind her if she is far away.
func call_to(player: Node3D) -> void:
	if not is_owned() or state == State.RIDDEN:
		return
	var distance := global_position.distance_to(player.global_position)
	if distance > data.call_range:
		GameState.notified.emit("Лошадь не слышит — слишком далеко")
		return
	if distance > data.call_teleport_distance:
		var back := player.global_transform.basis.z
		var model := player.get_node_or_null(^"Model") as Node3D
		if model:
			back = model.global_basis.z
		back.y = 0.0
		var spot := player.global_position + back.normalized() * 25.0
		var terrain := get_tree().get_first_node_in_group(&"terrain")
		if terrain:
			spot.y = float(terrain.call(&"height_at", spot.x, spot.z)) + 0.3
		global_position = spot
		velocity = Vector3.ZERO
	state = State.CALLED
	_stuck_time = 0.0
	GameState.notified.emit("Мара свистнула")


func _unhandled_input(event: InputEvent) -> void:
	if state == State.RIDDEN and event.is_action_pressed(&"interact") and not GameState.controls_locked:
		get_viewport().set_input_as_handled()
		dismount()
	elif event.is_action_pressed(&"call_horse") and not GameState.controls_locked:
		var player := get_tree().get_first_node_in_group(&"player") as Node3D
		if player and player.get(&"mount") == null:
			call_to(player)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var goal_speed := 0.0
	var goal_direction := Vector3.ZERO
	var galloping := false
	match state:
		State.RIDDEN:
			if not GameState.controls_locked:
				goal_direction = _input_direction()
				if goal_direction != Vector3.ZERO:
					galloping = Input.is_action_pressed(&"sprint") and stamina > 1.0
					goal_speed = data.gallop_speed if galloping else data.trot_speed
		State.CALLED:
			var player := get_tree().get_first_node_in_group(&"player") as Node3D
			var to := player.global_position - global_position
			to.y = 0.0
			if to.length() < data.arrive_distance:
				state = State.IDLE
			else:
				goal_direction = to.normalized()
				goal_speed = data.gallop_speed if to.length() > 12.0 else data.trot_speed
				_check_stuck(delta)

	if galloping:
		stamina = maxf(stamina - data.gallop_drain * delta, 0.0)
		_since_gallop = 0.0
	else:
		_since_gallop += delta
		if _since_gallop > data.regen_delay:
			stamina = minf(stamina + data.stamina_regen * delta, data.max_stamina)
	stamina_changed.emit(stamina, data.max_stamina)

	# Turn towards where the rider wants to go, then move along the horse's own heading.
	if goal_direction != Vector3.ZERO:
		var rate := deg_to_rad(data.gallop_turn_rate if galloping else data.turn_rate)
		var want := atan2(-goal_direction.x, -goal_direction.z)
		var diff := wrapf(want - rotation.y, -PI, PI)
		rotation.y += clampf(diff, -rate * delta, rate * delta)
		# A sharp turn slows the horse down.
		goal_speed *= clampf(1.0 - absf(diff) / PI, 0.35, 1.0)
	var rate_change := data.acceleration if goal_speed > speed else data.braking
	speed = move_toward(speed, goal_speed, rate_change * delta)
	var forward := -global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	move_and_slide()
	if state == State.RIDDEN and get_slide_collision_count() > 0 and get_real_velocity().length() < speed * 0.3:
		speed *= 0.5  # Ran into a tree: stop rather than grind against it.
	_animate(delta)


func _input_direction() -> Vector3:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var camera := get_viewport().get_camera_3d()
	if input == Vector2.ZERO or camera == null:
		return Vector3.ZERO
	var forward := -camera.global_basis.z
	forward.y = 0.0
	var right := camera.global_basis.x
	right.y = 0.0
	return (right.normalized() * input.x - forward.normalized() * input.y).normalized()


func _check_stuck(delta: float) -> void:
	var moved := global_position.distance_to(_last_position)
	_last_position = global_position
	_stuck_time = _stuck_time + delta if moved < speed * delta * 0.25 else 0.0
	if _stuck_time > 3.0:
		var player := get_tree().get_first_node_in_group(&"player") as Node3D
		state = State.IDLE
		call_to(player)
		if global_position.distance_to(player.global_position) > data.arrive_distance * 2.0:
			global_position = player.global_position + Vector3(3.0, 0.5, 3.0)


func _animate(delta: float) -> void:
	# Legs keep pace with the ground: clip speed follows real speed for each gait.
	var gait_speed := data.gallop_speed if speed > data.trot_speed + 1.0 else data.trot_speed if speed > data.walk_speed + 0.5 else data.walk_speed
	_model.set_speed_scale(clampf(speed / gait_speed, 0.6, 1.4) if speed > 0.3 else 1.0)
	_gait_time += delta * (1.9 if speed > data.trot_speed + 1.0 else 2.6) * clampf(speed / gait_speed, 0.0, 1.4)
	if speed > data.trot_speed + 1.0:
		_model.play(&"Gallop")
	elif speed > data.walk_speed:
		_model.play(&"Gallop" if speed > data.trot_speed * 0.8 else &"Walk")
	elif speed > 0.3:
		_model.play(&"Walk")
	else:
		_idle_time += delta
		# Every so often a riderless horse lowers its head to graze.
		_model.play(&"Eating" if state == State.IDLE and fmod(_idle_time, 14.0) > 9.0 else &"Idle")
