class_name WorldConfig
extends Resource
## Numbers for the open world "Земли за Бродом". Values live in resources/world/world_config.tres.

@export_group("Time")
## Real seconds per game hour (50 s -> a 20-minute day).
@export var seconds_per_hour: float = 50.0
@export var start_hour: float = 8.0
@export var morning_hour: float = 6.0
@export var day_hour: float = 10.0
@export var evening_hour: float = 18.0
@export var night_hour: float = 21.0
## Resting at a campfire sleeps until this hour.
@export var wake_hour: float = 7.0

@export_group("Travel")
## Game hours a fast-travel trip takes per 100 m.
@export var fast_travel_hours_per_100m: float = 0.5
## Fast travel (and resting) is refused while an enemy is closer than this.
@export var fast_travel_safe_distance: float = 25.0

@export_group("Enemies")
## Days before a cleared group of enemies comes back (wolves, bandits); 0 = never.
@export var respawn_days: int = 2
## Wolves per pack, bandits at the camp and the tower, infected at the farm and graveyard.
@export var wolves_per_pack: int = 3
@export var bandits_at_camp: int = 2
@export var bandits_at_tower: int = 2
@export var infected_at_graveyard: int = 3
@export var infected_at_farm: int = 2
@export var deer_herds: int = 3
@export var deer_per_herd: int = 3

@export_group("Look")
## Multiplier on fog density in the open world (the village keeps its own).
@export var fog_scale: float = 0.55
## Trees and rocks further than this are not drawn (fog hides the edge).
@export var draw_distance: float = 170.0
