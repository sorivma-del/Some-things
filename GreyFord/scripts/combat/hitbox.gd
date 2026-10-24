class_name Hitbox
extends Area3D
## A weapon's striking area. Strikes only between begin_swing() and end_swing(),
## and each Hurtbox at most once per swing.

signal landed(hurtbox: Hurtbox, info: HitInfo)

## The fighter swinging (its own hurtbox is skipped).
@export var body: Node3D
## If set, strikes only fighters in this group (enemies hit Mara, not each other).
@export var only_group: StringName = &""

## Контратака выбирает одного противника, обычный взмах может задеть нескольких.
var only_target: Node3D
var _guard_damage: float = -1.0
var _breaks_guard: bool = false
var _counter: bool = false
var _unblockable: bool = false
var _active: bool = false
var _damage: float
var _knockback: float
var _struck: Array[Hurtbox] = []
var _shape: BoxShape3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Hurtbox.LAYER
	monitorable = false
	monitoring = true


func set_size(size: Vector3) -> void:
	if _shape == null:
		_shape = BoxShape3D.new()
		var collision := CollisionShape3D.new()
		collision.shape = _shape
		add_child(collision)
	_shape.size = size


func begin_swing(damage: float, knockback: float, guard_damage: float = -1.0, breaks_guard: bool = false, counter: bool = false, unblockable: bool = false) -> void:
	only_target = null
	_guard_damage = guard_damage
	_breaks_guard = breaks_guard
	_counter = counter
	_unblockable = unblockable
	_active = true
	_damage = damage
	_knockback = knockback
	_struck.clear()


func end_swing() -> void:
	_active = false
	only_target = null


func is_active() -> bool:
	return _active


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	for area: Area3D in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null or hurtbox.body == body or _struck.has(hurtbox):
			continue
		if _counter and (not is_instance_valid(only_target) or hurtbox.body != only_target):
			continue
		if only_group != &"" and not hurtbox.body.is_in_group(only_group):
			continue
		_struck.append(hurtbox)
		var to := hurtbox.global_position - body.global_position
		to.y = 0.0
		var info := HitInfo.new(_damage, _knockback, body, to.normalized())
		info.guard_damage = _guard_damage
		info.breaks_guard = _breaks_guard
		info.is_counter = _counter
		info.unblockable = _unblockable
		hurtbox.receive(info)
		if info.result != HitInfo.Result.IGNORED:
			landed.emit(hurtbox, info)
