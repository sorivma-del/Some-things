class_name HorseData
extends Resource
## Riding numbers. Values live in resources/world/horse.tres.

@export_group("Speed")
@export var walk_speed: float = 2.2
## Plain riding (W).
@export var trot_speed: float = 6.5
## Holding Shift.
@export var gallop_speed: float = 11.5
@export var acceleration: float = 5.0
@export var braking: float = 9.0
## Degrees per second the horse can turn at a trot (slower at a gallop).
@export var turn_rate: float = 140.0
@export var gallop_turn_rate: float = 85.0

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var gallop_drain: float = 12.0
@export var stamina_regen: float = 9.0
@export var regen_delay: float = 1.0

@export_group("Calling")
## A whistle reaches this far; beyond it nothing happens.
@export var call_range: float = 450.0
## Further than this, the horse appears this far behind Mara instead of running the whole way.
@export var call_teleport_distance: float = 70.0
@export var arrive_distance: float = 3.5

@export_group("Look")
@export var model_scale: float = 0.55
## Mara's feet relative to the horse's origin when riding.
@export var seat: Vector3 = Vector3(0.0, 1.25, -0.12)
@export var camera_distance: float = 8.0
@export var camera_height: float = 2.9
