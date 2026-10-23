class_name TrainingDummy
extends CombatBody
## A straw-and-wood practice dummy: rocks back when struck, topples when its straw is
## spent and stands up again a few seconds later.

const MODEL := preload("res://resources/models/props/Dummy.gltf")

var _pivot := Node3D.new()


func _ready() -> void:
	super()
	add_child(_pivot)
	var model := MODEL.instantiate() as Node3D
	_pivot.add_child(model)
	set_flash_meshes(model)
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 1.8, 0.5)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position.y = 0.9
	add_child(shape)


func _struck(info: HitInfo) -> void:
	# Tip away from the blow and wobble back.
	var axis := Vector3.UP.cross(info.direction).normalized()
	var tween := create_tween()
	tween.tween_property(_pivot, ^"basis", Basis(axis, 0.35), 0.06)
	tween.tween_property(_pivot, ^"basis", Basis(axis, -0.12), 0.18)
	tween.tween_property(_pivot, ^"basis", Basis.IDENTITY, 0.25)


func _fell() -> void:
	var tween := create_tween()
	tween.tween_property(_pivot, ^"basis", Basis(Vector3.RIGHT, -PI * 0.47), 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _stood_up() -> void:
	create_tween().tween_property(_pivot, ^"basis", Basis.IDENTITY, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
