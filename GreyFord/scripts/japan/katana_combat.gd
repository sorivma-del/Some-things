extends "res://scripts/raid/raid_combat.gd"
## Локальная катана: не меняет инвентарь и экипировку основной игры.

const EPISODE: ShrineEpisodeConfig = preload("res://resources/japan/episode.tres")
const KATANA: PackedScene = preload("res://resources/japan/katana/katana.tscn")


func _arm() -> void:
	for slot: String in _held:
		_held[slot].get_parent().queue_free()
	_held.clear()
	var weapon := KATANA.instantiate() as Node3D
	_model.attach_to_bone(weapon, &"hand_r", GameState.item("bronze_sword").hold_offset)
	_held["weapon"] = weapon


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
	if blocking:
		_model.play(&"Sword_Block")
	elif moving:
		_model.play(&"Jog_Fwd")
	else:
		_model.play(&"Sword_Idle")
