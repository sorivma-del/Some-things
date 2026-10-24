class_name RaidEnemy
extends Enemy
## Участники набега: дуэлянт, щитоносец, рубака и главарь.

enum Role { DUELIST, SHIELD, BRUTE, CHIEF }
const RAID: RaidConfig = preload("res://resources/raid/raid_config.tres")
const SHIELD_SCENE: PackedScene = preload("res://resources/models/props/Shield_Wooden.gltf")
@export var role: Role = Role.DUELIST
var posture: float = 0.0
var max_posture: float
var _since_pressure: float = 0.0
var _exposed_left: float = 0.0
var _long_stagger: bool = false
var _normal_stagger: float = 0.0


func _ready() -> void:
	var profile: Resource = RAID.role_profiles[mini(int(role), RAID.role_profiles.size() - 1)]
	max_posture = float(profile.get(&"max_posture"))
	data.display_name = profile.get(&"display_name")
	data.max_health *= float(profile.get(&"health_factor"))
	data.chase_speed = float(profile.get(&"chase_speed"))
	data.attack_interval = float(profile.get(&"attack_interval"))
	data.flank_degrees = float(profile.get(&"flank_degrees"))
	data.poise = float(profile.get(&"poise"))
	data.attacks = data.attacks.duplicate()
	if role != Role.CHIEF:
		var move := data.attacks[0].duplicate() as EnemyAttack
		move.animation = profile.get(&"attack_clip")
		move.windup = float(profile.get(&"windup"))
		if role == Role.BRUTE:
			move.strike_moment = RAID.combo_strike_fraction
		move.unblockable = bool(profile.get(&"unblockable"))
		move.damage = float(profile.get(&"damage"))
		data.attacks = [move]
	super()
	_normal_stagger = data.stagger_time
	state_changed.connect(_state_updated)
	RaidAppearance.apply(_model as CharacterModel, int(role))
	if role == Role.SHIELD:
		_model.attach_to_bone(SHIELD_SCENE.instantiate() as Node3D, &"hand_l", GameState.item("wooden_shield").hold_offset)


func _start_attack() -> void:
	var raid := get_tree().get_first_node_in_group(&"village_raid")
	if raid and not raid.call(&"may_attack", self):
		_cooldown = RAID.attack_turn_delay
		return
	super()


func _telegraph(charge: float) -> void:
	super(charge)
	if attack and attack.unblockable:
		_show_marker("УКЛОНИСЬ" if charge > 0.0 else "!", attack.telegraph_color)


func _physics_process(delta: float) -> void:
	_since_pressure += delta
	if _exposed_left > 0.0:
		_exposed_left = maxf(0.0, _exposed_left - delta)
		if _exposed_left <= 0.0:
			posture = 0.0
	elif _since_pressure >= RAID.posture_delay and state != State.ATTACK:
		posture = maxf(0.0, posture - RAID.posture_regen * delta)
	super(delta)


func posture_ratio() -> float:
	return clampf(posture / max_posture, 0.0, 1.0) if max_posture > 0.0 else 0.0


func is_exposed() -> bool:
	return not dead and _exposed_left > 0.0


func combat_hint() -> String:
	if is_exposed():
		return "ЗАЩИТА СЛОМАНА"
	if state == State.ATTACK and attack.unblockable:
		return "ТЯЖЁЛЫЙ ЗАМАХ — УКЛОНИСЬ"
	if role == Role.SHIELD:
		return "ЩИТ — ТЯЖЁЛЫЙ УДАР ИЛИ ОБХОД"
	return "СТОЙКОСТЬ"


func _on_hit(info: HitInfo) -> void:
	if dead:
		super(info)
		return
	var exposed := is_exposed()
	var guarded := not exposed and role == Role.SHIELD and state == State.CHASE \
		and not info.breaks_guard and info.damage < RAID.guard_break_damage \
		and _forward().dot(-info.direction) > RAID.guard_front_dot
	_since_pressure = 0.0
	if not exposed:
		posture = minf(max_posture, posture + (info.guard_damage if info.guard_damage >= 0.0 else RAID.light_posture))
	if guarded:
		info.result = HitInfo.Result.BLOCKED
		_model.play_once(&"Sword_Block", RAID.attack_turn_delay)
	else:
		super(info)
	if dead:
		return
	if info.is_counter and exposed:
		_exposed_left = 0.0
		posture = 0.0
	elif posture >= max_posture and not exposed:
		stagger_from_parry()


func stagger_from_parry() -> void:
	if dead:
		return
	posture = max_posture
	_exposed_left = RAID.exposed_seconds
	_since_pressure = 0.0
	_long_stagger = true
	data.stagger_time = RAID.parry_stagger
	_set_state(State.STAGGER)
	_model.play_once(&"Idle_Shield_Break" if role == Role.SHIELD else &"Hit_Knockback", RAID.parry_stagger)


func _state_updated(value: State) -> void:
	if _long_stagger and value != State.STAGGER:
		data.stagger_time = _normal_stagger
		_long_stagger = false
