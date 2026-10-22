extends Node3D
## Village gate: two posts, a beam and two hinged doors. Opens when GameState.gate_open is set.

signal opened

const DOOR_WIDTH := 2.7
const DOOR_HEIGHT := 3.6
const OPEN_ANGLE := 105.0

@export var open_duration: float = 3.0

var _doors: Array[AnimatableBody3D] = []
var _bar: MeshInstance3D
var _is_open: bool = false


func _ready() -> void:
	var wood := Build.bark_material(Color(0.5, 0.42, 0.36))
	var dark := Build.bark_material(Color(0.26, 0.21, 0.18))
	for side: float in [-1.0, 1.0]:
		var x := side * (DOOR_WIDTH + 0.25)
		Build.box(self, Vector3(0.5, 4.8, 0.5), Vector3(x, 2.4, 0.0), wood)
		Build.static_box(self, Vector3(0.5, 4.8, 0.5), Vector3(x, 2.4, 0.0))
	Build.box(self, Vector3(DOOR_WIDTH * 2.0 + 1.4, 0.45, 0.6), Vector3(0.0, 4.6, 0.0), wood)

	for side: float in [-1.0, 1.0]:
		var door := AnimatableBody3D.new()
		door.name = "DoorLeft" if side < 0.0 else "DoorRight"
		door.position = Vector3(side * DOOR_WIDTH, 0.0, 0.0)  # Hinge at the post.
		add_child(door)
		var centre := Vector3(-side * DOOR_WIDTH * 0.5, DOOR_HEIGHT * 0.5, 0.0)
		Build.box(door, Vector3(DOOR_WIDTH, DOOR_HEIGHT, 0.22), centre, wood)
		for y: float in [0.8, 2.8]:
			Build.box(door, Vector3(DOOR_WIDTH - 0.1, 0.25, 0.1), centre + Vector3(0.0, y - DOOR_HEIGHT * 0.5, -0.15), dark)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(DOOR_WIDTH, DOOR_HEIGHT, 0.3)
		shape.shape = box
		shape.position = centre
		door.add_child(shape)
		_doors.append(door)
	# Crossbar on the village side, removed when the gate opens.
	_bar = Build.box(self, Vector3(DOOR_WIDTH * 2.0, 0.22, 0.2), Vector3(0.0, 1.8, -0.25), dark)
	_build_torch(Vector3(-(DOOR_WIDTH + 0.25), 2.6, -0.45))

	GameState.flag_changed.connect(_on_flag_changed)


func _build_torch(pos: Vector3) -> void:
	Build.cylinder(self, 0.05, 0.7, pos, Build.bark_material(Color(0.22, 0.17, 0.13)), 6, Vector3(-20.0, 0.0, 0.0))
	Effects.torch_flame(self, pos + Vector3(0.0, 0.38, -0.12))
	var light := FlickerLight.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.base_energy = 1.6
	light.omni_range = 7.0
	light.shadow_enabled = true
	light.position = pos + Vector3(0.0, 0.6, -0.4)
	add_child(light)


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_bar.queue_free()
	var creak := AudioStreamPlayer3D.new()
	creak.stream = ProceduralSound.gate_creak()
	creak.position = Vector3(0.0, 2.0, 0.0)
	creak.unit_size = 6.0
	add_child(creak)
	creak.play()
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for door: AnimatableBody3D in _doors:
		var side := signf(door.position.x)
		# Doors swing outwards, away from the village.
		tween.tween_property(door, ^"rotation_degrees:y", side * OPEN_ANGLE, open_duration)
	tween.chain().tween_callback(opened.emit)


func _on_flag_changed(flag: StringName, value: bool) -> void:
	if flag == &"gate_open" and value:
		open()
