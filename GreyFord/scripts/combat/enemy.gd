class_name Enemy
extends CombatBody
## A hostile creature or person. Notices Mara with the watchmen's StealthSense
## (PATROL -> SUSPICIOUS -> CHASE -> SEARCH), then fights: ATTACK (windup with a glowing
## telegraph, a live hitbox window, recovery), STAGGER when its poise breaks, DEAD with
## loot. Wolves hop back after a bite (RETREAT); bandits may stop to talk first (PARLEY)
## and, bribed or persuaded, stand aside (CALM). Paths go through a NavigationAgent3D.
## All numbers are in EnemyData (resources/combat/*.tres).

signal state_changed(state: State)
signal died(enemy: Enemy)

enum State { PATROL, SUSPICIOUS, CHASE, SEARCH, ATTACK, STAGGER, RETREAT, PARLEY, CALM, DEAD }
enum AttackPhase { WINDUP, ACTIVE, RECOVERY }

const LOOT_SCRIPT := preload("res://scripts/combat/loot_drop.gd")
## Keeps tracking Mara for this share of the windup, then commits to the blow.
const TRACK_SHARE := 0.6
const PARLEY_DISTANCE := 2.4
## Barely moving for this long while trying to walk = stuck on a tree or a barrel.
const STUCK_TIME := 0.8
const DETOUR_TIME := 0.8
const DETOUR_ANGLE := 1.2

static var _spawned: int = 0

## Unique id for flags and saves (killed, bribed). Generated when empty.
@export var enemy_id: String = ""
@export var route: PackedVector3Array = []
## Enemies with the same pack id hunt together.
@export var pack_id: String = ""
@export var eye_height: float = 1.6
@export var body_radius: float = 0.35
@export var body_height: float = 1.75
## Beasts: length of a body capsule lying along the spine (0 = upright capsule).
@export var body_length: float = 0.0
@export_group("Weapon")
@export var weapon_scene: PackedScene
@export var weapon_bone: StringName = &"hand_r"
@export var weapon_offset: Transform3D = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.07, 0.02))
## Where the telegraph light sits when there is no weapon (model space).
@export var telegraph_point: Vector3 = Vector3(0, 1.2, -0.5)
@export_group("Animations")
@export var anim_idle: StringName = &"Idle"
@export var anim_walk: StringName = &"Walk"
@export var anim_run: StringName = &"Jog_Fwd"
@export var anim_hit: StringName = &"Hit_Chest"
@export var anim_death: StringName = &"Death01"
@export_group("Parley")
## Dialogue offered the first time it spots Mara (bandits). Empty = attacks at once.
@export var parley: DialogueResource

var state: State = State.PATROL
var attack: EnemyAttack
## Spotted (or was struck by) Mara at least once since it appeared.
var noticed: bool = false
var phase_two: bool = false
var sense := StealthSense.new()

var _model: AnimatedModel
var _agent := NavigationAgent3D.new()
var _hitbox := Hitbox.new()
var _glow := StandardMaterial3D.new()
var _glow_light := OmniLight3D.new()
var _weapon_glows: bool = false
var _marker := Label3D.new()
var _attack_phase: AttackPhase = AttackPhase.WINDUP
var _state_time: float = 0.0
var _cooldown: float = 0.0
var _unseen_time: float = 0.0
var _search_turn: float = 0.0
var _poise_damage: float = 0.0
var _route_index: int = 0
var _home: Vector3
var _flank: float = 0.0
var _nav_target: Vector3 = Vector3.INF
var _retreat_time: float = 0.0
var _last_position: Vector3
var _stuck_time: float = 0.0
var _stuck_count: int = 0
var _detour_time: float = 0.0
var _detour_angle: float = DETOUR_ANGLE
var _retreat_speed: float = 0.0
var _player: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_spawned += 1
	if enemy_id.is_empty():
		enemy_id = "enemy_%d" % _spawned
	_rng.randomize()
	_model = get_node(^"Model") as AnimatedModel
	super()
	add_to_group(&"enemies")
	set_flash_meshes(_model)
	_home = global_position
	_flank = deg_to_rad(_rng.randf_range(-data.flank_degrees, data.flank_degrees))

	var capsule := CapsuleShape3D.new()
	capsule.radius = body_radius
	capsule.height = maxf(body_height, body_radius * 2.0)
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = body_height * 0.5
	if body_length > 0.0:
		capsule.height = body_length
		shape.rotation.x = PI * 0.5
		shape.position.y = body_height * 0.5
	add_child(shape)

	sense.view_distance = data.sight_radius
	sense.view_angle_degrees = data.view_angle_degrees
	sense.notice_rate = data.notice_rate
	sense.forget_rate = data.forget_rate
	sense.eye_height = eye_height

	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.6
	add_child(_agent)

	_hitbox.body = self
	_hitbox.only_group = &"player"
	_model.add_child(_hitbox)

	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.albedo_color = Color(1, 1, 1, 0)
	_glow_light.light_energy = 0.0
	_glow_light.omni_range = 2.6
	if weapon_scene:
		var weapon := weapon_scene.instantiate() as Node3D
		_model.attach_to_bone(weapon, weapon_bone, weapon_offset)
		for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_overlay = _glow
		_glow_light.position = Vector3(0, 0.6, 0)
		weapon.add_child(_glow_light)
		_weapon_glows = true
	else:
		_glow_light.position = telegraph_point
		_model.add_child(_glow_light)

	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.font = UiStyle.font(700)
	_marker.font_size = 96
	_marker.outline_size = 18
	_marker.pixel_size = 0.004
	_marker.position = Vector3(0.0, maxf(body_height, eye_height) + 0.5, 0.0)
	_marker.visible = false
	add_child(_marker)

	_choose_attack()
	GameState.parley_resolved.connect(_on_parley_resolved)
	_model.play(anim_idle)


func _physics_process(delta: float) -> void:
	super(delta)
	if dead:
		velocity.x = _knockback.x
		velocity.z = _knockback.z
		move_and_slide()
		return
	_state_time += delta
	_cooldown -= delta
	_poise_damage = maxf(_poise_damage - data.poise_regen * delta, 0.0)
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	sense.view_distance = data.sight_radius * (data.night_sight_multiplier if _is_night() else 1.0)

	var hero := get_tree().get_first_node_in_group(PlayerCombat.GROUP) as PlayerCombat
	var hero_down := hero != null and hero.state == PlayerCombat.State.DEAD
	if hero_down and _is_fighting():
		sense.alertness = 0.0
		_set_state(State.PATROL)

	var sees := false
	if state != State.CALM and state != State.PARLEY and not hero_down:
		sees = sense.can_see(self, _forward(), _player)
		sense.update(sees, self, _player, delta, _is_fighting())
	_update_awareness(sees)

	var move := Vector3.ZERO
	match state:
		State.PATROL:
			move = _patrol()
		State.SUSPICIOUS:
			_face(sense.last_seen, delta, 5.0)
			if sense.alertness <= 0.05:
				_set_state(State.PATROL)
		State.CHASE:
			move = _chase(sees, delta)
		State.SEARCH:
			move = _search(delta)
		State.ATTACK:
			move = _update_attack(delta)
		State.STAGGER:
			if _state_time >= data.stagger_time:
				_set_state(State.CHASE)
		State.RETREAT:
			var away := global_position - _player.global_position
			away.y = 0.0
			move = away.normalized() * _retreat_speed
			_face(_player.global_position, delta, 8.0)
			if _state_time >= _retreat_time:
				_set_state(State.CHASE)
		State.PARLEY:
			_face(_player.global_position, delta, 6.0)
			if _flat_distance(_player.global_position) > PARLEY_DISTANCE:
				move = _steer(_player.global_position) * data.move_speed
			elif not DialogueRunner.is_active and not GameState.controls_locked:
				_start_parley()
		State.CALM:
			pass

	velocity.x = move.x + _knockback.x
	velocity.z = move.z + _knockback.z
	move_and_slide()
	_check_stuck(move, delta)
	_animate(Vector2(move.x, move.z).length())


#region Senses and movement

func _update_awareness(sees: bool) -> void:
	match state:
		State.PATROL:
			if sense.alertness >= data.suspicious_threshold:
				_set_state(State.SUSPICIOUS)
		State.SUSPICIOUS:
			if sense.alertness >= 1.0:
				_notice()
		State.SEARCH:
			if sees and sense.alertness >= 0.6:
				_notice()


## Spotted Mara: talk first (bandits, once) or fight, and call the pack.
func _notice() -> void:
	noticed = true
	if parley and not GameState.has_flag("%s_parley" % enemy_id) and (data.bribe_cost > 0 or data.persuade_difficulty > 0):
		GameState.set_flag("%s_parley" % enemy_id)
		_set_state(State.PARLEY)
		return
	_set_state(State.CHASE)
	if not pack_id.is_empty():
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			var ally := node as Enemy
			if ally != self and ally.pack_id == pack_id and not ally.dead \
					and ally.global_position.distance_to(global_position) <= data.pack_call_radius:
				ally.join_hunt(sense.last_seen)


## Already bought off or talked down (e.g. after a reload): stands aside from the start.
func start_calm() -> void:
	GameState.set_flag("%s_parley" % enemy_id)
	_set_state(State.CALM)


## Turns to look at a point (spawning, cutscenes).
func face_point(point: Vector3) -> void:
	_face(point, 1.0, 1000.0)


## A packmate spotted Mara.
func join_hunt(point: Vector3) -> void:
	if _is_fighting() or state == State.CALM or dead:
		return
	noticed = true
	sense.alertness = 1.0
	sense.last_seen = point
	_set_state(State.CHASE)


func _patrol() -> Vector3:
	if route.size() > 0:
		var target := route[_route_index]
		if _flat_distance(target) < 0.5:
			_route_index = (_route_index + 1) % route.size()
		return _steer(target) * data.move_speed * _speed_multiplier()
	if _flat_distance(_home) > 1.0:
		return _steer(_home) * data.move_speed
	return Vector3.ZERO


func _chase(sees: bool, delta: float) -> Vector3:
	_unseen_time = 0.0 if sees else _unseen_time + delta
	if _unseen_time > data.lose_sight_time or _flat_distance(_home) > data.leash_distance:
		_set_state(State.SEARCH)
		return Vector3.ZERO
	var target := _player.global_position if sees else sense.last_seen
	var distance := _flat_distance(target)
	_face(target, delta, 8.0)
	if sees and distance <= attack.attack_range and _cooldown <= 0.0:
		_start_attack()
		return Vector3.ZERO
	if distance > attack.attack_range * 0.85:
		# Pack hunters come in at an angle rather than all in a line.
		var approach := target
		if _flank != 0.0 and distance > 3.0:
			var from := (global_position - target).normalized().rotated(Vector3.UP, _flank)
			approach = target + from * minf(distance * 0.5, 3.0)
		return _steer(approach) * data.chase_speed * _speed_multiplier()
	return Vector3.ZERO


func _search(delta: float) -> Vector3:
	if _state_time > data.search_time:
		sense.alertness = 0.0
		_set_state(State.PATROL)
		return Vector3.ZERO
	if _flat_distance(sense.last_seen) > 0.8 and _flat_distance(_home) < data.leash_distance:
		return _steer(sense.last_seen) * data.move_speed * 1.2
	_search_turn += delta
	_model.rotation.y += sin(_search_turn * 1.7) * delta * 1.6
	return Vector3.ZERO


## Without a navigation mesh enemies walk straight and can catch on trees: when they
## barely move, they sidestep at an angle for a moment; on patrol a waypoint they cannot
## reach is skipped.
func _check_stuck(move: Vector3, delta: float) -> void:
	var wanted := Vector2(move.x, move.z).length()
	var moved := Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length()
	_last_position = global_position
	_detour_time = maxf(_detour_time - delta, 0.0)
	if wanted < 0.3 or _detour_time > 0.0:
		_stuck_time = 0.0
		return
	if moved < wanted * delta * 0.25:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
		_stuck_count = 0
	if _stuck_time > STUCK_TIME:
		_stuck_time = 0.0
		_stuck_count += 1
		_detour_time = DETOUR_TIME
		_detour_angle = -_detour_angle
		if state == State.PATROL and _stuck_count >= 2 and route.size() > 0:
			_route_index = (_route_index + 1) % route.size()
			_stuck_count = 0


## Direction to walk towards `target`, along the navigation mesh when there is one.
func _steer(target: Vector3) -> Vector3:
	if _nav_target.distance_to(target) > 0.5:
		_nav_target = target
		_agent.target_position = target
	var next := target
	if not _agent.is_navigation_finished():
		var path_point := _agent.get_next_path_position()
		if Vector2(path_point.x - global_position.x, path_point.z - global_position.z).length() > 0.05:
			next = path_point
	var to := next - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return Vector3.ZERO
	var direction := to.normalized()
	if _detour_time > 0.0:
		direction = direction.rotated(Vector3.UP, _detour_angle)
	_face(global_position + direction, get_physics_process_delta_time(), 8.0)
	return direction

#endregion


#region Attacks

func _choose_attack() -> void:
	var pool: Array[EnemyAttack] = data.attacks.duplicate()
	if phase_two:
		pool.append_array(data.phase_two_attacks)
	var total := 0.0
	for a: EnemyAttack in pool:
		total += a.weight
	var pick := _rng.randf() * total
	for a: EnemyAttack in pool:
		pick -= a.weight
		if pick <= 0.0:
			attack = a
			return
	attack = pool.back()


func _start_attack() -> void:
	_set_state(State.ATTACK)
	_attack_phase = AttackPhase.WINDUP
	_hitbox.set_size(attack.hitbox_size)
	_hitbox.position = Vector3(0, attack.hitbox_size.y * 0.5 + 0.2, -attack.hitbox_size.z * 0.5 - body_radius * 0.5)
	_model.play_once(attack.animation, attack.windup / attack.strike_moment)
	_glow.albedo_color = Color(attack.telegraph_color, 0.0)
	_glow_light.light_color = attack.telegraph_color


func _update_attack(delta: float) -> Vector3:
	match _attack_phase:
		AttackPhase.WINDUP:
			if _state_time < attack.windup * TRACK_SHARE:
				_face(_player.global_position, delta, 10.0)
			_telegraph(clampf(_state_time / attack.windup, 0.0, 1.0))
			if _state_time >= attack.windup:
				_telegraph(0.0)
				_attack_phase = AttackPhase.ACTIVE
				_state_time = 0.0
				_hitbox.begin_swing(attack.damage, attack.knockback)
		AttackPhase.ACTIVE:
			if _state_time >= attack.active:
				_hitbox.end_swing()
				_attack_phase = AttackPhase.RECOVERY
				_state_time = 0.0
			return _forward() * attack.lunge_speed
		AttackPhase.RECOVERY:
			if _state_time >= attack.recovery:
				_cooldown = data.attack_interval * _interval_multiplier()
				_retreat_time = attack.hop_back_time
				_retreat_speed = attack.hop_back_speed
				_choose_attack()
				if _retreat_time > 0.0:
					_set_state(State.RETREAT)
					_model.play(anim_run)
				else:
					_set_state(State.CHASE)
	return Vector3.ZERO


## 0..1 over the windup: the weapon (or the beast itself) glows brighter.
func _telegraph(charge: float) -> void:
	_glow_light.light_energy = 2.5 * charge
	if _weapon_glows:
		_glow.albedo_color.a = 0.0 if charge <= 0.0 else 0.15 + 0.6 * charge
	else:
		_flash.albedo_color = overlay_base.lerp(Color(attack.telegraph_color, 0.45), charge)

#endregion


#region Being hit

func _struck(info: HitInfo) -> void:
	if state == State.CALM or state == State.PARLEY:
		GameState.set_flag("%s_attacked" % enemy_id)
	noticed = true
	sense.alertness = 1.0
	if info.source:
		sense.last_seen = info.source.global_position
	if not phase_two and not data.phase_two_attacks.is_empty() and health_ratio() <= data.phase_two_health:
		_enter_phase_two()
	_poise_damage += info.damage
	if _poise_damage >= data.poise and not (state == State.ATTACK and _attack_phase == AttackPhase.ACTIVE):
		_poise_damage = 0.0
		_set_state(State.STAGGER)
		_model.play_once(anim_hit, data.stagger_time)
	elif not _is_fighting():
		_set_state(State.CHASE)


func _enter_phase_two() -> void:
	phase_two = true
	overlay_base = Color(1.0, 0.2, 0.1, 0.18)
	_flash.albedo_color = overlay_base
	GameState.notified.emit("%s в ярости" % lock_name)
	_choose_attack()


func _fell() -> void:
	_set_state(State.DEAD)
	_model.play_once(anim_death)
	collision_layer = 0
	GameState.set_flag("%s_killed" % enemy_id)
	if data.loot:
		var drop := LOOT_SCRIPT.new() as LootDrop
		drop.contents = data.loot.roll(_rng)
		if not drop.contents.is_empty():
			get_parent().add_child(drop)
			drop.global_position = global_position + _forward() * 0.6
	died.emit(self)
	if data.corpse_time > 0.0:
		get_tree().create_timer(data.corpse_time).timeout.connect(queue_free)

#endregion


#region Parley

func _start_parley() -> void:
	GameState.parley_enemy = enemy_id
	GameState.parley_bribe = data.bribe_cost
	GameState.parley_difficulty = data.persuade_difficulty
	DialogueRunner.dialogue_finished.connect(_on_parley_finished, CONNECT_ONE_SHOT)
	DialogueRunner.start_dialogue(parley, "start", self)


func _on_parley_resolved(id: String, outcome: String) -> void:
	if id != enemy_id or dead:
		return
	if outcome == "bribe" or outcome == "persuade":
		sense.alertness = 0.0
		_set_state(State.CALM)
	else:
		_cooldown = 0.6
		_set_state(State.CHASE)


func _on_parley_finished(_resource: DialogueResource) -> void:
	if state == State.PARLEY:
		_set_state(State.CHASE)

#endregion


#region Helpers

func _set_state(new_state: State) -> void:
	if state == State.ATTACK and new_state != State.ATTACK:
		_hitbox.end_swing()
		_telegraph(0.0)
	state = new_state
	_state_time = 0.0
	match state:
		State.SUSPICIOUS, State.SEARCH:
			_show_marker("?", Color(0.95, 0.8, 0.4))
		State.CHASE, State.PARLEY:
			_unseen_time = 0.0
			_show_marker("!", Color(0.95, 0.35, 0.25))
		State.PATROL:
			_marker.visible = false
			_route_index = _nearest_waypoint()
		State.CALM, State.DEAD:
			_marker.visible = false
	state_changed.emit(state)


func _is_fighting() -> bool:
	return state in [State.CHASE, State.ATTACK, State.STAGGER, State.RETREAT]


func _is_night() -> bool:
	return GameState.phase == GameState.Phase.NIGHT


func _speed_multiplier() -> float:
	var multiplier := data.night_speed_multiplier if _is_night() else 1.0
	if phase_two:
		multiplier *= data.phase_two_speed_multiplier
	return multiplier


func _interval_multiplier() -> float:
	var multiplier := data.night_interval_multiplier if _is_night() else 1.0
	if phase_two:
		multiplier *= data.phase_two_interval_multiplier
	return multiplier


func _animate(speed: float) -> void:
	if state in [State.ATTACK, State.STAGGER, State.DEAD]:
		return
	if speed > data.move_speed * 1.25:
		_model.play(anim_run)
	elif speed > 0.2:
		_model.play(anim_walk)
	else:
		_model.play(anim_idle)


func _show_marker(text: String, color: Color) -> void:
	_marker.text = text
	_marker.modulate = color
	_marker.visible = true


func _forward() -> Vector3:
	var forward := -_model.global_basis.z
	forward.y = 0.0
	return forward.normalized()


func _face(point: Vector3, delta: float, speed: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() > 0.01:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-to.x, -to.z), clampf(speed * delta, 0.0, 1.0))


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _nearest_waypoint() -> int:
	var best := 0
	for i: int in route.size():
		if _flat_distance(route[i]) < _flat_distance(route[best]):
			best = i
	return best

#endregion
