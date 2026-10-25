extends PlayerCombat
## Лёгкое комбо, тяжёлый удар и ответ после парирования в отдельном эпизоде.

signal parried(enemy: Node3D)
enum Swing { LIGHT, HEAVY, COUNTER }
const RAID: RaidConfig = preload("res://resources/raid/raid_config.tres")
const CLIPS: Array[StringName] = [&"Sword_Regular_A", &"Sword_Regular_B", &"Sword_Regular_C"]
var _base_cost: float = 0.0
var _parry_left: float = 0.0
var _block_was_down: bool = false
var _heavy_requested: bool = false
var _swing: Swing = Swing.LIGHT
var _counter_target: RaidEnemy
var _counter_left: float = 0.0
var _riposte_target: RaidEnemy


func _ready() -> void:
	data = data.duplicate() as HeroCombatData
	_base_cost = data.attack_cost
	super()
	RaidAppearance.apply(_model, 0, true)


func drive(direction: Vector3, delta: float) -> void:
	_parry_left = maxf(0.0, _parry_left - delta)
	_counter_left = maxf(0.0, _counter_left - delta)
	var block_down := Input.is_action_pressed(&"block")
	super(direction, delta)
	if blocking and block_down and not _block_was_down:
		_parry_left = RAID.parry_window
	_block_was_down = block_down


func _read_input(direction: Vector3) -> void:
	if GameControls.actions_suppressed():
		return
	if state == State.NORMAL and Input.is_action_just_pressed(&"heavy_attack"):
		_start_heavy()
		return
	super(direction)


func _start_heavy() -> void:
	_heavy_requested = true
	_start_attack(0)
	_heavy_requested = false


func _can_counter() -> bool:
	return _counter_left > 0.0 and is_instance_valid(_counter_target) and _counter_target.is_exposed() \
		and _counter_target.global_position.distance_to(_body.global_position) <= RAID.counter_range


func _start_attack(index: int) -> void:
	var next_swing := Swing.HEAVY if _heavy_requested else (Swing.COUNTER if state == State.NORMAL and _can_counter() else Swing.LIGHT)
	var step := index % CLIPS.size()
	var cost := _base_cost * (RAID.heavy_cost if next_swing == Swing.HEAVY else (RAID.counter_cost if next_swing == Swing.COUNTER else RAID.combo_cost[step]))
	if stamina < cost:
		return
	_swing = next_swing
	data.attack_cost = cost
	var clip: StringName = CLIPS[step]
	match _swing:
		Swing.HEAVY:
			data.windup = RAID.heavy_windup
			data.active = RAID.heavy_active
			data.recovery = RAID.heavy_recovery
			clip = &"Sword_Regular_C"
		Swing.COUNTER:
			data.windup = RAID.counter_windup
			data.active = RAID.counter_active
			data.recovery = RAID.counter_recovery
			_riposte_target = _counter_target
			_counter_left = 0.0
			_set_target(_riposte_target)
			clip = &"Sword_Regular_B"
		Swing.LIGHT:
			data.windup = RAID.combo_windups[step]
			data.active = RAID.combo_active[step]
			data.recovery = RAID.combo_recovery[step]
	super(index)
	_parry_left = 0.0
	_model.play_once(clip, data.windup / RAID.combo_strike_fraction)


func attack_damage() -> float:
	if state != State.ATTACK:
		return super()
	var factor := RAID.combo_damage[_attack_index % CLIPS.size()]
	if _swing == Swing.HEAVY:
		factor = RAID.heavy_damage
	elif _swing == Swing.COUNTER:
		factor = RAID.counter_damage
	return super() * factor


func _update_attack() -> void:
	if _attack_phase == AttackPhase.WINDUP and _state_time >= data.windup:
		_attack_phase = AttackPhase.ACTIVE
		var guard_damage := RAID.heavy_posture if _swing == Swing.HEAVY else RAID.light_posture
		_hitbox.begin_swing(attack_damage(), data.knockback, guard_damage, _swing == Swing.HEAVY, _swing == Swing.COUNTER)
		if _swing == Swing.COUNTER:
			if not is_instance_valid(_riposte_target) or _riposte_target.dead:
				_hitbox.end_swing()
			else:
				_hitbox.only_target = _riposte_target
		_play_sound(&"swing")
	if _attack_phase == AttackPhase.ACTIVE and _state_time >= data.windup + data.active:
		_attack_phase = AttackPhase.RECOVERY
		_hitbox.end_swing()
		var clip := &"Sword_Regular_A_Rec" if _swing == Swing.LIGHT and _attack_index % CLIPS.size() == 0 else &"Sword_Regular_B_Rec"
		_model.play_once(clip, data.recovery)
	if _attack_phase == AttackPhase.RECOVERY and _attack_time_left() <= 0.0:
		var next_cost := _base_cost * RAID.combo_cost[(_attack_index + 1) % CLIPS.size()]
		if _swing == Swing.LIGHT and _attack_queued and stamina >= next_cost:
			_start_attack(_attack_index + 1)
		else:
			_set_state(State.NORMAL)


func _on_hit(info: HitInfo) -> void:
	if not info.unblockable and not is_invulnerable() and state == State.NORMAL and blocking and _parry_left > 0.0 and stamina >= RAID.parry_cost \
			and _forward().dot(-info.direction) >= cos(deg_to_rad(data.block_angle_degrees)) and info.source is RaidEnemy:
		_parry_left = 0.0
		_spend(RAID.parry_cost)
		info.result = HitInfo.Result.BLOCKED
		_counter_target = info.source as RaidEnemy
		_counter_target.stagger_from_parry()
		_set_target(_counter_target)
		_counter_left = RAID.counter_window
		_play_sound(&"block")
		HitFeel.hitstop(get_tree(), data.hitstop_hurt_ms)
		GameState.notified.emit("Парирование! %s — контратака" % GameControls.attack_button())
		parried.emit(info.source)
		return
	super(info)
	if info.result == HitInfo.Result.HIT or info.result == HitInfo.Result.KILLED:
		_counter_left = 0.0


func _on_landed(hurtbox: Hurtbox, info: HitInfo) -> void:
	super(hurtbox, info)
	if info.is_counter and info.result in [HitInfo.Result.HIT, HitInfo.Result.KILLED]:
		GameState.notified.emit("Контратака!")


func _die() -> void:
	_counter_left = 0.0
	_set_state(State.DEAD)
	_model.play_once(&"Death01")
	died.emit()
