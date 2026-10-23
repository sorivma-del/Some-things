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

@export_group("Trust")
## Starting trust (0-100) per villager.
@export var trust_start: Dictionary[String, int] = {"helga": 55, "tomash": 30, "anka": 60, "yan": 20, "olbrecht": 15}
## Trust lost with every villager when Mara is caught.
@export var trust_lost_when_caught: int = 8

@export_group("Economy")
@export var start_coins: int = 20
## Slot -> item id Mara starts with.
@export var start_equipment: Dictionary[String, String] = {"weapon": "bronze_sword", "shield": "wooden_shield", "armor": ""}
## Item id -> count in Mara's bag at the start.
@export var start_items: Dictionary[String, int] = {"bandage": 2}
