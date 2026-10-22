class_name CharacterStats
extends Resource
## Character attributes. Values live in .tres files, never in code.

@export var character_name: String = ""
@export_range(0, 10) var observation: int = 0  ## Наблюдательность
@export_range(0, 10) var persuasion: int = 0  ## Убеждение
@export_range(0, 10) var strength: int = 0  ## Сила
@export_range(0, 10) var medicine: int = 0  ## Лекарское дело


func get_stat(stat: StringName) -> int:
	match stat:
		&"observation":
			return observation
		&"persuasion":
			return persuasion
		&"strength":
			return strength
		&"medicine":
			return medicine
	push_error("Unknown stat: %s" % stat)
	return 0


static func display_name(stat: StringName) -> String:
	match stat:
		&"observation":
			return "Наблюдательность"
		&"persuasion":
			return "Убеждение"
		&"strength":
			return "Сила"
		&"medicine":
			return "Лекарское дело"
	return String(stat)
