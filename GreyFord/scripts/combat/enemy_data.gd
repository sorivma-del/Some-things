class_name EnemyData
extends Resource
## Numbers for one kind of enemy. Values live in resources/combat/*.tres.

@export var display_name: String = "Противник"
@export var max_health: float = 60.0
@export var damage: float = 15.0
@export var move_speed: float = 2.2
@export var sight_radius: float = 12.0
## Starts an attack when Mara is this close.
@export var attack_range: float = 1.8
## Telegraph before the blow lands; the weapon glows during it.
@export var windup: float = 0.55
@export var active: float = 0.15
@export var recovery: float = 0.6
## Pause between attacks.
@export var attack_interval: float = 1.4
@export var knockback: float = 4.0
## How far a blow pushes this enemy back (multiplier).
@export var knockback_taken: float = 1.0
@export var stagger_time: float = 0.4
## Seconds before a training target stands up again (0 = stays down).
@export var revive_time: float = 3.0
