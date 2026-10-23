class_name EnemyAttack
extends Resource
## One attack an enemy can make. Every attack telegraphs: the clip winds up and the
## weapon (or the body, for beasts) glows in `telegraph_color` before the blow lands.

@export var display_name: String = "Удар"
@export var animation: StringName = &"Sword_Attack"
## Share of the clip's length where the blow lands; the clip is timed so that this
## moment falls at the end of the windup.
@export_range(0.05, 0.95) var strike_moment: float = 0.45
@export var damage: float = 15.0
@export var knockback: float = 4.0
## Starts the attack when Mara is this close.
@export var attack_range: float = 1.9
@export var windup: float = 0.5
@export var active: float = 0.15
@export var recovery: float = 0.6
## Forward speed during the active window (a lunge or a bite).
@export var lunge_speed: float = 0.0
## Hitbox in front of the enemy: width, height, reach.
@export var hitbox_size: Vector3 = Vector3(1.3, 1.4, 1.5)
@export var telegraph_color: Color = Color(1.0, 0.55, 0.15)
## After the blow, jump back this long (wolves).
@export var hop_back_time: float = 0.0
@export var hop_back_speed: float = 0.0
## Relative chance among the attacks in range.
@export var weight: float = 1.0
