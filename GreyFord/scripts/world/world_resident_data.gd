class_name WorldResidentData
extends Resource
## Распорядок и движение жителя; точки маршрута заданы в координатах мира (x, z).

@export var home: Vector2
@export var evening_spot: Vector2
@export var route: PackedVector2Array = []
@export var walk_speed: float = 1.1
@export var stop_seconds: float = 5.0
@export var arrival_distance: float = 0.6
@export var turn_speed: float = 5.0
