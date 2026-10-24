class_name RaidRole
extends Resource
## Числа и анимация одной боевой роли.
@export var health_factor: float = 1.0
@export var chase_speed: float = 3.2
@export var attack_interval: float = 1.4
@export var flank_degrees: float = 30.0
@export var poise: float = 25.0
@export var attack_clip: StringName = &"Sword_Regular_B"
@export var windup: float = 0.5
@export var damage: float = 16.0

@export var display_name: String = "Налётчик"

@export var max_posture: float
@export var unblockable: bool = false
