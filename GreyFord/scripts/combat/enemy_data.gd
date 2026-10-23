class_name EnemyData
extends Resource
## Numbers for one kind of enemy. Values live in resources/combat/*.tres.

@export var display_name: String = "Противник"
@export var max_health: float = 60.0
@export var move_speed: float = 2.2
## How far away it can see Mara (the stealth vision cone's length).
@export var sight_radius: float = 12.0
## How long a blow pushes this enemy back (multiplier).
@export var knockback_taken: float = 1.0
@export var stagger_time: float = 0.4
## Seconds before a training target stands up again (0 = stays down).
@export var revive_time: float = 3.0

@export_group("Single attack (training targets)")
@export var damage: float = 15.0
## Starts an attack when Mara is this close.
@export var attack_range: float = 1.8
## Telegraph before the blow lands; the weapon glows during it.
@export var windup: float = 0.55
@export var active: float = 0.15
@export var recovery: float = 0.6
@export var knockback: float = 4.0
## Pause between attacks.
@export var attack_interval: float = 1.4

@export_group("Enemy")
@export var attacks: Array[EnemyAttack] = []
@export var chase_speed: float = 3.0
@export var view_angle_degrees: float = 60.0
@export var notice_rate: float = 1.2
@export var forget_rate: float = 0.35
@export var suspicious_threshold: float = 0.3
@export var search_time: float = 6.0
@export var lose_sight_time: float = 3.0
## Gives up the chase this far from where it started.
@export var leash_distance: float = 30.0
## Damage it shrugs off before staggering (0 = every blow staggers).
@export var poise: float = 0.0
## Poise damage that wears off per second.
@export var poise_regen: float = 10.0
## After a stagger it cannot be staggered again for this long (no endless juggling).
@export var stagger_cooldown: float = 1.5
## Pack hunters approach from an angle up to this far off the straight line.
@export var flank_degrees: float = 0.0
## Allies of the same pack within this distance join the chase.
@export var pack_call_radius: float = 15.0
@export var loot: LootTable
## Seconds the body lies before it is removed.
@export var corpse_time: float = 6.0

@export_group("Night")
## Multipliers applied at night (the infected grow bolder).
@export var night_speed_multiplier: float = 1.0
@export var night_sight_multiplier: float = 1.0
@export var night_interval_multiplier: float = 1.0

@export_group("Second phase")
## Below this share of health the second phase starts (only with phase-two attacks).
@export var phase_two_health: float = 0.5
@export var phase_two_attacks: Array[EnemyAttack] = []
@export var phase_two_speed_multiplier: float = 1.0
@export var phase_two_interval_multiplier: float = 1.0

@export_group("Parley")
## Coins that buy this enemy off (0 = cannot be bribed).
@export var bribe_cost: int = 0
## Persuasion check difficulty to talk it down (0 = cannot be persuaded).
@export var persuade_difficulty: int = 0
