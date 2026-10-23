class_name Hitbox
extends Area3D
## A weapon's striking area. Strikes only between begin_swing() and end_swing(),
## and each Hurtbox at most once per swing.

signal landed(hurtbox: Hurtbox, info: HitInfo)

## The fighter swinging (its own hurtbox is skipped).
@export var body: Node3D

var _active: bool = false
var _damage: float
var _knockback: float
var _struck: Array[Hurtbox] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = Hurtbox.LAYER
	monitorable = false
	monitoring = true


func set_size(size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


func begin_swing(damage: float, knockback: float) -> void:
	_active = true
	_damage = damage
	_knockback = knockback
	_struck.clear()


func end_swing() -> void:
	_active = false


func is_active() -> bool:
	return _active


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	for area: Area3D in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null or hurtbox.body == body or _struck.has(hurtbox):
			continue
		_struck.append(hurtbox)
		var to := hurtbox.global_position - body.global_position
		to.y = 0.0
		var info := HitInfo.new(_damage, _knockback, body, to.normalized())
		hurtbox.receive(info)
		if info.result != HitInfo.Result.IGNORED:
			landed.emit(hurtbox, info)
