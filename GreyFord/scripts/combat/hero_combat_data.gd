class_name HeroCombatData
extends Resource
## Mara's combat numbers. Values live in resources/combat/hero_combat.tres.

@export_group("Body")
@export var max_health: float = 100.0
@export var move_speed: float = 3.6
## Movement speed multiplier while holding the shield up.
@export var block_move_factor: float = 0.45

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 38.0
## Seconds after the last spend before stamina starts to come back.
@export var stamina_regen_delay: float = 0.8
@export var attack_cost: float = 18.0
@export var roll_cost: float = 25.0
## Spent every second the shield is held up.
@export var block_hold_cost: float = 6.0
## Spent per blocked hit, multiplied by the hit's damage / 10.
@export var block_hit_cost: float = 12.0

@export_group("Light attack")
@export var damage: float = 20.0
@export var windup: float = 0.16
## The hitbox is live only in this window.
@export var active: float = 0.14
@export var recovery: float = 0.32
## An attack pressed this long before recovery ends is queued.
@export var input_buffer: float = 0.25
## Hitbox in front of Mara: width, height, reach.
@export var reach: Vector3 = Vector3(1.7, 1.4, 1.5)
@export var knockback: float = 3.2
## Mara steps forward this fast during the windup.
@export var lunge_speed: float = 1.6

@export_group("Shield")
## Hits within this angle of where Mara faces are blocked.
@export var block_angle_degrees: float = 75.0
## Share of damage that gets through a block.
@export var block_damage_factor: float = 0.0
@export var guard_break_time: float = 0.9

@export_group("Roll")
@export var roll_time: float = 0.62
@export var roll_speed: float = 6.2
## Invulnerable between these moments of the roll (seconds from its start).
@export var iframes_start: float = 0.0
@export var iframes_end: float = 0.42

@export_group("Getting hit")
@export var hurt_time: float = 0.45
## Knockback speed Mara takes, scaled by the hit's knockback.
@export var hurt_knockback_scale: float = 1.0
@export var knockback_decay: float = 9.0

@export_group("Hit feel")
@export var hitstop_ms: float = 65.0
@export var hitstop_hurt_ms: float = 80.0
@export var shake_hit: float = 0.06
@export var shake_hurt: float = 0.14
@export var shake_time: float = 0.18

@export_group("Lock-on")
@export var lock_range: float = 14.0
## Half-angle of the cone in front of the camera searched for a target.
@export var lock_cone_degrees: float = 50.0
## The lock breaks beyond this distance.
@export var lock_break_distance: float = 18.0

@export_group("Death")
## Share of coins lost on death (rounded up).
@export var death_coin_loss: float = 0.25
@export var death_fade_delay: float = 1.6
