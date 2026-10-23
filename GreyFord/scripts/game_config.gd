class_name GameConfig
extends Resource
## Balance numbers for the three-day game. Values live in resources/game_config.tres.

@export_group("Days")
@export var days: int = 3
@export var slots_per_day: int = 3
@export var slot_names: PackedStringArray = ["Утро", "День", "Вечер"]

@export_group("Herbs")
## Herb ids; one of each brews one dose of medicine.
@export var herb_ids: PackedStringArray = ["wormwood", "elecampane", "burnet"]
@export var herb_names: PackedStringArray = ["Полынь", "Девясил", "Кровохлёбка"]

@export_group("Sick")
## Patient id -> starting health. 0 = dead, max_health = out of danger.
@export var sick_start_health: Dictionary[String, int] = {"anka": 2, "yan": 2}
@export var max_health: int = 3

@export_group("Guards")
## Forest watchmen on day 1, 2, 3.
@export var forest_guards_per_day: PackedInt32Array = [1, 2, 3]
## Village hunters on the night after day 1, day 2.
@export var night_hunters_per_night: PackedInt32Array = [0, 2]
## Herbs lost when caught (all of them if negative).
@export var herbs_lost_when_caught: int = -1
