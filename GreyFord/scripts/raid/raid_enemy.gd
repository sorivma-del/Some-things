class_name RaidEnemy
extends Enemy
## Участники набега: дуэлянт, щитоносец, рубака и главарь.

enum Role { DUELIST, SHIELD, BRUTE, CHIEF }
const RAID: RaidConfig = preload("res://resources/raid/raid_config.tres")
const SHIELD_SCENE: PackedScene = preload("res://resources/models/props/Shield_Wooden.gltf")
@export var role: Role = Role.DUELIST
var _guard_remaining: int = 0
var _long_stagger: bool = false
var _normal_stagger: float = 0.0


func _ready() -> void:
	var profile: Resource = RAID.role_profiles[mini(int(role), RAID.role_profiles.size() - 1)]
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
		move.damage = float(profile.get(&"damage"))
		data.attacks = [move]
	super()
	_normal_stagger = data.stagger_time
	_guard_remaining = RAID.guard_hits
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


func _on_hit(info: HitInfo) -> void:
	if not dead and role == Role.SHIELD and state == State.CHASE and _guard_remaining > 0 \
			and info.damage < RAID.guard_break_damage and _forward().dot(-info.direction) > RAID.guard_front_dot:
		_guard_remaining -= 1
		info.result = HitInfo.Result.BLOCKED
		_model.play_once(&"Sword_Block", RAID.attack_turn_delay)
		if _guard_remaining == 0:
			stagger_from_parry()
		return
	super(info)


func stagger_from_parry() -> void:
	if dead:
		return
	_long_stagger = true
	data.stagger_time = RAID.parry_stagger
	_set_state(State.STAGGER)
	_model.play_once(&"Hit_Knockback", RAID.parry_stagger)


func _state_updated(value: State) -> void:
	if _long_stagger and value != State.STAGGER:
		data.stagger_time = _normal_stagger
		_long_stagger = false
	if value == State.ATTACK:
		_guard_remaining = RAID.guard_hits
