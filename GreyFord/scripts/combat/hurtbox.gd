class_name Hurtbox
extends Area3D
## The part of a fighter that can be struck. Lives on physics layer 5 ("hurtbox");
## the owner handles `hit` and sets HitInfo.result.

signal hit(info: HitInfo)

const LAYER := 1 << 4

## The body this hurtbox belongs to (so a fighter never hits itself).
@export var body: Node3D


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	if body == null:
		body = get_parent() as Node3D


func receive(info: HitInfo) -> HitInfo.Result:
	hit.emit(info)
	return info.result
