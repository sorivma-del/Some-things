class_name RaidConfig
extends Resource
## Баланс отдельного эпизода, не меняющий врагов основной истории.

@export var warning_seconds: float = 6.0
@export var breather_seconds: float = 4.0
@export var first_wave_count: int = 6
@export var escort_count: int = 5
@export var raider_health: float = 60.0
@export var chief_health: float = 150.0
@export var sight_radius: float = 40.0
@export var leash_distance: float = 75.0
@export var breather_heal: float = 35.0
@export var civilian_speed: float = 2.8

@export var ignition_flight_seconds: float = 1.1
@export var fire_energy: float = 3.0

@export var max_active_enemies: int = 4
@export var max_attackers: int = 2
@export var attack_turn_delay: float = 0.35
@export var parry_window: float = 0.2
@export var parry_cost: float = 8.0
@export var parry_stagger: float = 1.1
@export var guard_hits: int = 2
@export var guard_break_damage: float = 28.0
@export var combo_windups: PackedFloat32Array = PackedFloat32Array([0.2, 0.23, 0.34])
@export var combo_active: PackedFloat32Array = PackedFloat32Array([0.14, 0.15, 0.18])
@export var combo_recovery: PackedFloat32Array = PackedFloat32Array([0.28, 0.32, 0.46])
@export var combo_damage: PackedFloat32Array = PackedFloat32Array([1.0, 1.1, 1.6])
@export var combo_cost: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.5])

@export var role_profiles: Array[RaidRole] = []
@export var guard_front_dot: float = 0.3
@export var combo_strike_fraction: float = 0.45

@export var street_upgrade: bool = true
