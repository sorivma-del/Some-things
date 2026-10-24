extends PlayerCombat
## Три удара, окно парирования и отдельное поражение в эпизоде.

signal parried(enemy: Node3D)
const RAID: RaidConfig = preload("res://resources/raid/raid_config.tres")
const CLIPS: Array[StringName] = [&"Sword_Regular_A", &"Sword_Regular_B", &"Sword_Regular_C"]
var _base_cost: float = 0.0
var _parry_left: float = 0.0
var _block_was_down: bool = false


func _ready() -> void:
	data = data.duplicate() as HeroCombatData
	_base_cost = data.attack_cost
	super()
	RaidAppearance.apply(_model, 0, true)


func drive(direction: Vector3, delta: float) -> void:
	_parry_left = maxf(0.0, _parry_left - delta)
	var block_down := Input.is_action_pressed(&"block")
	super(direction, delta)
	if blocking and block_down and not _block_was_down:
		_parry_left = RAID.parry_window
	_block_was_down = block_down


func _start_attack(index: int) -> void:
	var step := index % CLIPS.size()
	data.windup = RAID.combo_windups[step]
	data.active = RAID.combo_active[step]
	data.recovery = RAID.combo_recovery[step]
	data.attack_cost = _base_cost * RAID.combo_cost[step]
	if stamina < data.attack_cost:
		return
	super(index)
	_model.play_once(CLIPS[step], data.windup / RAID.combo_strike_fraction)


func attack_damage() -> float:
	return super() * (RAID.combo_damage[_attack_index % CLIPS.size()] if state == State.ATTACK else 1.0)


func _update_attack() -> void:
	if _attack_phase == AttackPhase.WINDUP and _state_time >= data.windup:
		_attack_phase = AttackPhase.ACTIVE
		_hitbox.begin_swing(attack_damage(), data.knockback)
		_play_sound(&"swing")
	if _attack_phase == AttackPhase.ACTIVE and _state_time >= data.windup + data.active:
		_attack_phase = AttackPhase.RECOVERY
		_hitbox.end_swing()
		var clip := &"Sword_Regular_A_Rec" if _attack_index % CLIPS.size() == 0 else &"Sword_Regular_B_Rec"
		_model.play_once(clip, data.recovery)
	if _attack_phase == AttackPhase.RECOVERY and _attack_time_left() <= 0.0:
		var next_cost := _base_cost * RAID.combo_cost[(_attack_index + 1) % CLIPS.size()]
		if _attack_queued and stamina >= next_cost:
			_start_attack(_attack_index + 1)
		else:
			_set_state(State.NORMAL)


func _on_hit(info: HitInfo) -> void:
	if state == State.NORMAL and blocking and _parry_left > 0.0 and stamina >= RAID.parry_cost \
			and _forward().dot(-info.direction) >= cos(deg_to_rad(data.block_angle_degrees)) and info.source is RaidEnemy:
		_parry_left = 0.0
		_spend(RAID.parry_cost)
		info.result = HitInfo.Result.BLOCKED
		(info.source as RaidEnemy).stagger_from_parry()
		_play_sound(&"block")
		HitFeel.hitstop(get_tree(), data.hitstop_hurt_ms)
		GameState.notified.emit("Парирование — противник открыт")
		parried.emit(info.source)
		return
	super(info)


func _die() -> void:
	_set_state(State.DEAD)
	_model.play_once(&"Death01")
	died.emit()
