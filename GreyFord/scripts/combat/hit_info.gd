class_name HitInfo
extends RefCounted
## One blow passed from a Hitbox to a Hurtbox. The receiver fills in `result`
## while handling Hurtbox.hit, so the attacker knows how it went.

enum Result { IGNORED, HIT, BLOCKED, KILLED }

var damage: float
var knockback: float
var source: Node3D
## Horizontal direction from the attacker towards the target.
var direction: Vector3
var result: Result = Result.IGNORED


func _init(p_damage: float, p_knockback: float, p_source: Node3D, p_direction: Vector3) -> void:
	damage = p_damage
	knockback = p_knockback
	source = p_source
	direction = p_direction
