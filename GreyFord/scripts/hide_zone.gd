class_name HideZone
extends Area3D
## Cover Mara can stand in (tall grass, bushes, behind barrels): while she is inside,
## watchmen notice her more slowly. See Player.concealment and Guard.notice_rate.

@export var concealment: float = 0.7
@export var size: Vector3 = Vector3(3.0, 1.5, 3.0)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(shape)
	body_entered.connect(func(body: Node3D) -> void:
		if body.has_method(&"enter_cover"):
			body.call(&"enter_cover", self))
	body_exited.connect(func(body: Node3D) -> void:
		if body.has_method(&"leave_cover"):
			body.call(&"leave_cover", self))
