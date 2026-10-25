extends "res://scripts/raid/raid_combat.gd"
## Локальная катана: не меняет инвентарь и экипировку основной игры.

const EPISODE: ShrineEpisodeConfig = preload("res://resources/japan/episode.tres")
const KATANA: PackedScene = preload("res://resources/japan/katana/katana.tscn")
var peaceful: bool = false
var _interaction_left: float = 0
var _torch: Node3D


func set_peaceful(value: bool) -> void:
	peaceful = value
	if not value:
		_interaction_left = 0
		if is_instance_valid(_torch):
			_torch.hide()
	if _held.has("weapon"):
		_held["weapon"].visible = not value


func play_lighting() -> void:
	if not is_instance_valid(_torch):
		_torch = Node3D.new()
		_torch.name = "LightingTaper"
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.18, 0.13, 0.07)
		Build.cylinder(_torch, 0.012, 0.36, Vector3(0, 0.15, 0), wood, 8)
		ShrineCraft.fire(_torch, 0.14).position.y = 0.32
		_model.attach_to_bone(_torch, &"hand_r", GameState.item("bronze_sword").hold_offset)
	_torch.show()
	_interaction_left = EPISODE.lighting_animation_seconds
	_model.play_once(&"Interact", _interaction_left)


func drive(direction: Vector3, delta: float) -> void:
	if _interaction_left > 0:
		_interaction_left = maxf(0, _interaction_left - delta)
		if is_instance_valid(_torch):
			var toward := EPISODE.beacon_position + Vector3(0, 1.23, 0) - _torch.global_position
			if toward.length_squared() > 0.0001:
				_torch.global_basis = Basis(Quaternion(Vector3.UP, toward.normalized()))
		if _interaction_left == 0 and is_instance_valid(_torch):
			_torch.hide()
	super(direction, delta)


func _read_input(direction: Vector3) -> void:
	if GameControls.actions_suppressed():
		return
	if peaceful and (Input.is_action_just_pressed(&"attack") or Input.is_action_just_pressed(&"heavy_attack") or Input.is_action_pressed(&"block")):
		set_peaceful(false)
	super(direction)


func _arm() -> void:
	for slot: String in _held:
		_held[slot].get_parent().queue_free()
	_held.clear()
	var weapon := KATANA.instantiate() as Node3D
	_model.attach_to_bone(weapon, &"hand_r", GameState.item("bronze_sword").hold_offset)
	_held["weapon"] = weapon
	weapon.visible = not peaceful


func _has_shield() -> bool:
	# Здесь L1 поднимает клинок: щит в этом эпизоде не требуется.
	return true


func _block_cost_factor() -> float:
	return EPISODE.block_cost_factor


func attack_damage() -> float:
	var damage := EPISODE.katana_damage
	if state == State.ATTACK:
		if _swing == Swing.HEAVY:
			damage *= RAID.heavy_damage
		elif _swing == Swing.COUNTER:
			damage *= RAID.counter_damage
		else:
			damage *= RAID.combo_damage[_attack_index % CLIPS.size()]
	return damage


func _play_locomotion(moving: bool) -> void:
	if _interaction_left > 0:
		return
	if peaceful:
		_model.play(&"Jog_Fwd" if moving else &"Idle")
	elif blocking:
		_model.play(&"Sword_Block")
	elif moving:
		_model.play(&"Jog_Fwd")
	else:
		_model.play(&"Sword_Idle")
