class_name PlayerCombat
extends Node
## Mara's melee: a light sword attack, a shield held up with the block key, a roll with
## invulnerability frames, stamina, lock-on, getting hit and falling. Sits as a "Combat"
## child of the Player, which hands it movement every physics frame (drive()).
## Numbers come from HeroCombatData (resources/combat/hero_combat.tres).

signal health_changed(value: float, max_value: float)
signal stamina_changed(value: float, max_value: float)
## Locked-on target changed; null when the lock is released.
signal target_changed(target: Node3D)
signal died
signal respawned

enum State { NORMAL, ATTACK, ROLL, HURT, GUARD_BROKEN, DEAD }
enum AttackPhase { WINDUP, ACTIVE, RECOVERY }

const GROUP := &"player_combat"
## Nodes Mara can lock onto. They provide `lock_name`, `can_be_locked()` and `health_ratio()`.
const TARGET_GROUP := &"lock_target"
const ATTACK_CLIPS: Array[StringName] = [&"Sword_Regular_A", &"Sword_Regular_B"]
## Which hand holds each equipment slot's model.
const HOLD_BONES: Dictionary[String, StringName] = {"weapon": &"hand_r", "shield": &"hand_l"}
const ACCELERATION := 16.0
const TURN_SPEED := 12.0

@export var data: HeroCombatData = preload("res://resources/combat/hero_combat.tres")

var state: State = State.NORMAL
var health: float
var stamina: float
var blocking: bool = false
## Debug: blows do nothing.
var invulnerable: bool = false
var target: Node3D

var _body: CharacterBody3D
var _model: CharacterModel
var _hitbox: Hitbox
var _hurtbox: Hurtbox
var _state_time: float = 0.0
var _attack_phase: AttackPhase = AttackPhase.WINDUP
var _attack_index: int = 0
var _attack_queued: bool = false
var _roll_direction: Vector3
var _knockback: Vector3
var _move_velocity: Vector3
var _since_spend: float = 100.0
var _spawn_point: Vector3
var _sfx := AudioStreamPlayer3D.new()
var _sounds: Dictionary[StringName, AudioStreamWAV] = {}
## Slot -> the model currently held for it.
var _held: Dictionary[String, Node3D] = {}


func _ready() -> void:
	add_to_group(GROUP)
	_body = get_parent() as CharacterBody3D
	_model = _body.get_node(^"Model") as CharacterModel
	stamina = data.max_stamina
	_spawn_point = _body.global_position
	# Health carries over between scenes and saves through GameState.hero_health.
	_sync_health()
	health_changed.connect(func(value: float, _max_value: float) -> void: GameState.hero_health = value)
	GameState.time_changed.connect(_sync_health)
	# Bump into enemies (physics layer 2) instead of walking through them.
	_body.set_collision_mask_value(2, true)

	_hurtbox = Hurtbox.new()
	_hurtbox.body = _body
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	_hurtbox.add_child(shape)
	_hurtbox.position = Vector3(0, 0.9, 0)
	_body.add_child.call_deferred(_hurtbox)
	_hurtbox.hit.connect(_on_hit)

	_hitbox = Hitbox.new()
	_hitbox.body = _body
	_hitbox.set_size(data.reach)
	_hitbox.position = Vector3(0, 1.0, -data.reach.z * 0.5 - 0.15)
	_model.add_child.call_deferred(_hitbox)
	_hitbox.landed.connect(_on_landed)

	_sfx.volume_db = -4.0
	_sfx.position = Vector3(0, 1.2, 0)
	_body.add_child.call_deferred(_sfx)
	_sounds = {&"swing": ProceduralSound.swing(), &"hit": ProceduralSound.hit(), &"block": ProceduralSound.block()}
	_arm.call_deferred()
	GameState.equipment_changed.connect(_arm)


## Puts the equipped weapon in the right hand and the shield on the left forearm.
func _arm() -> void:
	for slot: String in HOLD_BONES:
		if _held.has(slot):
			_held[slot].get_parent().queue_free()  # The BoneAttachment3D holding it.
			_held.erase(slot)
		var item := GameState.equipped(slot)
		if item and item.model:
			var node := item.model.instantiate() as Node3D
			_model.attach_to_bone(node, HOLD_BONES[slot], item.hold_offset)
			_held[slot] = node


## Light-attack damage: the weapon's, or bare hands from HeroCombatData.
func attack_damage() -> float:
	var weapon := GameState.equipped("weapon")
	return weapon.damage if weapon else data.damage


func _defense() -> float:
	var armor := GameState.equipped("armor")
	return armor.defense if armor else 0.0


func _block_cost_factor() -> float:
	var shield := GameState.equipped("shield")
	return shield.block_cost_factor if shield else 1.0


func _has_shield() -> bool:
	return GameState.equipped("shield") != null


## Uses the strongest healing item in the bag (bandage, bread).
func _use_heal() -> void:
	if health >= data.max_health:
		return
	var best: Item = null
	for id: String in GameState.bag():
		var found := GameState.item(id)
		if found and found.type == Item.Type.CONSUMABLE and found.heal > 0.0 and (best == null or found.heal > best.heal):
			best = found
	if best == null:
		GameState.notified.emit("Нечем перевязаться")
		return
	use_item(best.id)


## Eats or applies a consumable from the bag.
func use_item(id: String) -> void:
	var found := GameState.item(id)
	if found == null or found.heal <= 0.0 or state == State.DEAD or not GameState.take(id):
		return
	health = minf(health + found.heal, data.max_health)
	health_changed.emit(health, data.max_health)
	GameState.notified.emit("%s  +%d здоровья" % [found.display_name, roundi(found.heal)])


## Movement, facing and animation for this physics frame. `direction` is the input
## direction relative to the camera (zero while controls are locked).
func drive(direction: Vector3, delta: float) -> void:
	_state_time += delta
	_since_spend += delta
	_update_target()
	if _can_act():
		_read_input(direction)

	var goal := Vector3.ZERO
	match state:
		State.NORMAL:
			blocking = _can_act() and _has_shield() and Input.is_action_pressed(&"block") and stamina > 0.0
			if blocking:
				_spend(data.block_hold_cost * delta)
			goal = direction * data.move_speed * (data.block_move_factor if blocking else 1.0)
			if is_instance_valid(target):
				_face(target.global_position - _body.global_position, delta)
			elif direction.length_squared() > 0.001:
				_face(direction, delta)
			_play_locomotion(direction.length() > 0.1)
		State.ATTACK:
			_update_attack()
			if _attack_phase == AttackPhase.WINDUP:
				goal = _forward() * data.lunge_speed
		State.ROLL:
			var t := _state_time / data.roll_time
			goal = _roll_direction * data.roll_speed * (1.0 - t * t * 0.6)
			if _state_time >= data.roll_time:
				_set_state(State.NORMAL)
		State.HURT:
			if _state_time >= data.hurt_time:
				_set_state(State.NORMAL)
		State.GUARD_BROKEN:
			if _state_time >= data.guard_break_time:
				_set_state(State.NORMAL)

	if not blocking and _since_spend >= data.stamina_regen_delay and stamina < data.max_stamina:
		stamina = minf(stamina + data.stamina_regen * delta, data.max_stamina)
		stamina_changed.emit(stamina, data.max_stamina)

	_knockback = _knockback.move_toward(Vector3.ZERO, data.knockback_decay * delta)
	# Own movement and knockback are kept apart, so a push is applied once, not every frame.
	if state == State.NORMAL:
		_move_velocity = _move_velocity.move_toward(goal, ACCELERATION * delta)
	else:
		_move_velocity = goal
	_body.velocity.x = _move_velocity.x + _knockback.x
	_body.velocity.z = _move_velocity.z + _knockback.z


func plays_footsteps() -> bool:
	return state == State.NORMAL


func is_invulnerable() -> bool:
	if invulnerable:
		return true
	return state == State.ROLL and _state_time >= data.iframes_start and _state_time <= data.iframes_end


func _sync_health() -> void:
	var stored := GameState.hero_health
	health = data.max_health if stored < 0.0 else clampf(stored, 1.0, data.max_health)
	GameState.hero_health = health
	health_changed.emit(health, data.max_health)


## Back at full strength (also used by debug tools).
func restore() -> void:
	health = data.max_health
	stamina = data.max_stamina
	health_changed.emit(health, data.max_health)
	stamina_changed.emit(stamina, data.max_stamina)


#region Input and actions

func _read_input(direction: Vector3) -> void:
	if Input.is_action_just_pressed(&"heal") and state == State.NORMAL:
		_use_heal()
	if Input.is_action_just_pressed(&"lock_on"):
		_set_target(null if is_instance_valid(target) else _find_target())
	if Input.is_action_just_pressed(&"switch_target") and is_instance_valid(target):
		_switch_target()
	if Input.is_action_just_pressed(&"roll"):
		var can_cancel := state == State.ATTACK and _attack_phase == AttackPhase.RECOVERY
		if state == State.NORMAL or can_cancel:
			_start_roll(direction)
	if Input.is_action_just_pressed(&"attack"):
		if state == State.NORMAL:
			_start_attack(0)
		elif state == State.ATTACK and _attack_time_left() <= data.input_buffer:
			_attack_queued = true


func _start_attack(index: int) -> void:
	if stamina < data.attack_cost:
		return
	_spend(data.attack_cost)
	_set_state(State.ATTACK)
	_attack_phase = AttackPhase.WINDUP
	_attack_index = index
	_attack_queued = false
	if is_instance_valid(target):
		_face(target.global_position - _body.global_position, 1.0, true)
	else:
		var input := _camera_relative_input()
		if input != Vector3.ZERO:
			_face(input, 1.0, true)
	_model.play_once(ATTACK_CLIPS[index % ATTACK_CLIPS.size()], data.windup + data.active)


func _update_attack() -> void:
	if _attack_phase == AttackPhase.WINDUP and _state_time >= data.windup:
		_attack_phase = AttackPhase.ACTIVE
		_hitbox.begin_swing(attack_damage(), data.knockback)
		_play_sound(&"swing")
	if _attack_phase == AttackPhase.ACTIVE and _state_time >= data.windup + data.active:
		_attack_phase = AttackPhase.RECOVERY
		_hitbox.end_swing()
		var clip := ATTACK_CLIPS[_attack_index % ATTACK_CLIPS.size()]
		_model.play_once(StringName(String(clip) + "_Rec"), data.recovery * 1.6)
	if _attack_phase == AttackPhase.RECOVERY and _attack_time_left() <= 0.0:
		if _attack_queued and stamina >= data.attack_cost:
			_start_attack(_attack_index + 1)
		else:
			_set_state(State.NORMAL)


func _attack_time_left() -> float:
	return data.windup + data.active + data.recovery - _state_time


func _start_roll(direction: Vector3) -> void:
	if stamina < data.roll_cost:
		return
	_spend(data.roll_cost)
	_set_state(State.ROLL)
	_roll_direction = direction.normalized() if direction.length_squared() > 0.01 else _forward()
	_face(_roll_direction, 1.0, true)
	_model.play_once(&"Roll", data.roll_time)


func _set_state(new_state: State) -> void:
	if state == State.ATTACK and new_state != State.ATTACK:
		_hitbox.end_swing()
		_attack_queued = false
	state = new_state
	_state_time = 0.0
	if new_state != State.NORMAL:
		blocking = false


func _spend(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_since_spend = 0.0
	stamina_changed.emit(stamina, data.max_stamina)

#endregion


#region Being hit

func _on_hit(info: HitInfo) -> void:
	if state == State.DEAD or is_invulnerable():
		info.result = HitInfo.Result.IGNORED
		return
	if blocking and state == State.NORMAL and _forward().dot(-info.direction) >= cos(deg_to_rad(data.block_angle_degrees)):
		var cost := data.block_hit_cost * info.damage / 10.0 * _block_cost_factor()
		if stamina >= cost:
			_spend(cost)
			_take_damage(info.damage * data.block_damage_factor)
			_knockback = info.direction * info.knockback * data.hurt_knockback_scale * 0.35
			info.result = HitInfo.Result.BLOCKED
			_play_sound(&"block")
			_model.play_once(&"Sword_Block", 0.5)
			HitFeel.shake(get_tree(), data.shake_hit, data.shake_time)
			HitFeel.hitstop(get_tree(), data.hitstop_ms)
			return
		# Not enough stamina to hold the blow: the guard breaks.
		_spend(stamina)
		_set_state(State.GUARD_BROKEN)
		_model.play_once(&"Idle_Shield_Break", data.guard_break_time)

	_take_damage(info.damage * (1.0 - _defense()))
	_knockback = info.direction * info.knockback * data.hurt_knockback_scale
	info.result = HitInfo.Result.HIT
	_play_sound(&"hit")
	HitFeel.shake(get_tree(), data.shake_hurt, data.shake_time)
	HitFeel.hitstop(get_tree(), data.hitstop_hurt_ms)
	if health <= 0.0:
		info.result = HitInfo.Result.KILLED
		_die()
	elif state != State.GUARD_BROKEN:
		_set_state(State.HURT)
		_model.play_once(&"Hit_Chest", data.hurt_time)


func _take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, data.max_health)


func _on_landed(_hurtbox: Hurtbox, info: HitInfo) -> void:
	_play_sound(&"block" if info.result == HitInfo.Result.BLOCKED else &"hit")
	HitFeel.shake(get_tree(), data.shake_hit, data.shake_time)
	HitFeel.hitstop(get_tree(), data.hitstop_ms)


## Falls, then wakes at the last campfire with fewer coins. Story flags are untouched.
func _die() -> void:
	_set_state(State.DEAD)
	_set_target(null)
	_model.play_once(&"Death01")
	GameState.lock_controls()
	died.emit()
	await get_tree().create_timer(data.death_fade_delay).timeout
	await Transition.fade_out(0.8)
	var point := GameState.respawn_point if GameState.has_respawn_point else _spawn_point
	_body.call(&"teleport", point)
	GameState.in_forest = false  # Wakes in the village even if she fell in the forest.
	var lost := ceili(GameState.coins * data.death_coin_loss)
	GameState.coins -= lost
	restore()
	_knockback = Vector3.ZERO
	_set_state(State.NORMAL)
	_model.play(&"Idle")
	get_tree().call_group(&"camera_rig", &"snap_behind_target")
	await Transition.fade_in(0.8)
	GameState.unlock_controls()
	GameState.notified.emit("Мара очнулась у костра" + (". Потеряно монет: %d" % lost if lost > 0 else ""))
	respawned.emit()

#endregion


#region Lock-on

func _set_target(node: Node3D) -> void:
	if node == target:
		return
	target = node
	get_tree().call_group(&"camera_rig", &"set_lock_target", node)
	target_changed.emit(node)


func _update_target() -> void:
	if target == null:
		return
	if not is_instance_valid(target) or not target.call(&"can_be_locked") \
			or target.global_position.distance_to(_body.global_position) > data.lock_break_distance:
		_set_target(null)


## Lockable targets in range and in sight, with their angle off the camera's forward.
func _candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var camera := get_viewport().get_camera_3d()
	var forward := -camera.global_basis.z if camera else _forward()
	forward.y = 0.0
	forward = forward.normalized()
	for node: Node in get_tree().get_nodes_in_group(TARGET_GROUP):
		var candidate := node as Node3D
		if candidate == null or not candidate.call(&"can_be_locked"):
			continue
		var to := candidate.global_position - _body.global_position
		to.y = 0.0
		if to.length() > data.lock_range or not _in_sight(candidate):
			continue
		result.append({"node": candidate, "angle": rad_to_deg(forward.signed_angle_to(to.normalized(), Vector3.UP)), "distance": to.length()})
	return result


func _find_target() -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for c: Dictionary in _candidates():
		var angle: float = absf(c["angle"])
		if angle > data.lock_cone_degrees:
			continue
		var score: float = angle + float(c["distance"]) * 3.0
		if score < best_score:
			best_score = score
			best = c["node"]
	return best


## Next target to the right of the current one (wrapping round).
func _switch_target() -> void:
	var list := _candidates()
	if list.size() < 2:
		return
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["angle"]) > float(b["angle"]))
	for i: int in list.size():
		if list[i]["node"] == target:
			_set_target(list[(i + 1) % list.size()]["node"])
			return


func _in_sight(node: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(_body.global_position + Vector3.UP * 1.3, node.global_position + Vector3.UP * 1.0, 1)
	query.exclude = [_body.get_rid()]
	var hit := _body.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == node

#endregion


#region Helpers

## Not in a dialogue or cutscene, not hiding behind a door, not down.
func _can_act() -> bool:
	return not GameState.controls_locked and state != State.DEAD and not _body.get(&"frozen")


func _forward() -> Vector3:
	var forward := -_model.global_basis.z
	forward.y = 0.0
	return forward.normalized()


func _face(direction: Vector3, delta: float, instant: bool = false) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	var yaw := atan2(-direction.x, -direction.z)
	_model.rotation.y = yaw if instant else lerp_angle(_model.rotation.y, yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


func _play_locomotion(moving: bool) -> void:
	if blocking:
		_model.play(&"Idle_Shield")
	elif moving:
		_model.play(&"Jog_Fwd")
	else:
		_model.play(&"Sword_Idle" if is_instance_valid(target) else &"Idle")


func _camera_relative_input() -> Vector3:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var camera := get_viewport().get_camera_3d()
	if input == Vector2.ZERO or camera == null:
		return Vector3.ZERO
	var forward := -camera.global_basis.z
	forward.y = 0.0
	var right := camera.global_basis.x
	right.y = 0.0
	return (right.normalized() * input.x - forward.normalized() * input.y).normalized()


func _play_sound(sound: StringName) -> void:
	_sfx.stream = _sounds[sound]
	_sfx.pitch_scale = randf_range(0.9, 1.1)
	_sfx.play()

#endregion
