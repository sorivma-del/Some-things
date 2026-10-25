class_name ShrineAftermath
extends Node3D
## Выживший и сигнальная жаровня: локальные объекты задания, без флагов основной игры.

signal conversation_requested
signal beacon_requested
const EPISODE: ShrineEpisodeConfig = preload("res://resources/japan/episode.tres")
var survivor: StaticBody3D
var survivor_model: CharacterModel
var survivor_area: Interactable
var beacon_area: Interactable
var burning: bool = false
var _fire: Node3D
var _light: OmniLight3D
var _sound: AudioStreamPlayer3D
var _survivor_marker: Label3D
var _beacon_marker: Label3D


func _ready() -> void:
	set_process(false)
	_survivor()
	_beacon()
	_supplies()
	reset()


func _survivor() -> void:
	survivor = StaticBody3D.new()
	survivor.name = "Survivor"
	survivor.position = EPISODE.survivor_position
	survivor.collision_layer = 2
	add_child(survivor)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	var shape := CollisionShape3D.new()
	shape.name = "Body"
	shape.shape = capsule
	shape.position.y = 0.8
	survivor.add_child(shape)
	survivor_model = CharacterModel.new()
	survivor_model.base_scene = preload("res://resources/models/characters/base/Superhero_Female_FullBody.gltf")
	survivor_model.parts = [preload("res://resources/models/characters/outfits/Female_Peasant.gltf"), preload("res://resources/models/characters/hair/Hair_Buns.gltf")]
	survivor_model.head_only_parts = PackedStringArray(["Superhero_Female"])
	survivor_model.tint = Color(0.65, 0.7, 0.67)
	survivor_model.default_animation = &"Idle_FoldArms"
	survivor.add_child(survivor_model)
	for node: Node in survivor_model.find_children("*", "MeshInstance3D", true, false):
		if not String(node.name).contains("Hair"):
			continue
		var mesh := node as MeshInstance3D
		for index: int in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(index) as StandardMaterial3D
			if original:
				var hair := original.duplicate() as StandardMaterial3D
				hair.albedo_color = Color(0.14, 0.11, 0.085)
				mesh.set_surface_override_material(index, hair)
	survivor_area = _interaction(survivor, "Поговорить с выжившей", Vector3(0, 0.8, 0))
	survivor_area.interacted.connect(func() -> void: conversation_requested.emit())
	_survivor_marker = _marker(survivor, "АКИ · ВЫЖИВШАЯ", Vector3(0, 2.15, 0))


func _beacon() -> void:
	var beacon := Node3D.new()
	beacon.name = "SignalBrazier"
	beacon.position = EPISODE.beacon_position
	add_child(beacon)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.12, 0.14, 0.15)
	iron.metallic = 0.72
	iron.roughness = 0.55
	var wood := Build.bark_material(Color(0.32, 0.22, 0.13))
	for i: int in 3:
		var angle := float(i) * TAU / 3.0
		Build.cylinder(beacon, 0.045, 1.0, Vector3(cos(angle) * 0.28, 0.5, sin(angle) * 0.28), iron, 8)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.6
	bowl.bottom_radius = 0.29
	bowl.height = 0.3
	bowl.radial_segments = 20
	Build.mesh(beacon, bowl, iron, Vector3(0, 1.05, 0))
	for i: int in 4:
		Build.cylinder(beacon, 0.055, 0.8, Vector3(0, 1.23 + i * 0.025, 0), wood, 7, Vector3(90, i * 45, 0))
	Build.static_box(beacon, Vector3(1.05, 1.35, 1.05), Vector3(0, 0.65, 0))
	beacon_area = _interaction(beacon, "Зажечь сигнальный огонь", Vector3(0, 0.8, 0))
	beacon_area.interacted.connect(func() -> void: beacon_requested.emit())
	_beacon_marker = _marker(beacon, "СИГНАЛЬНЫЙ ОГОНЬ", Vector3(0, 2.3, 0))
	_fire = Node3D.new()
	beacon.add_child(_fire)
	Effects.flames(_fire, Vector3(0, 1.3, 0)).amount = 28
	Effects.sparks(_fire, Vector3(0, 1.4, 0)).amount = 10
	Effects.smoke(_fire, Vector3(0, 1.7, 0), 8, 0.6)
	_light = OmniLight3D.new()
	_light.position.y = 1.8
	_light.light_color = Color(1, 0.49, 0.18)
	_light.omni_range = 8
	_fire.add_child(_light)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = ProceduralSound.fire_crackle()
	_sound.volume_db = -17
	_sound.position.y = 1.3
	beacon.add_child(_sound)


func _supplies() -> void:
	var wood := Build.bark_material(Color(0.5, 0.36, 0.2))
	var cloth := Build.material(Color(0.32, 0.34, 0.26))
	for i: int in 3:
		var pos := Vector3(-8.8 + i * 0.7, 0.35, 3.9 + (i % 2) * 0.6)
		Build.box(self, Vector3(0.6, 0.55, 0.6), pos, cloth, Vector3(0, i * 17, 0))
		for side: float in [-0.22, 0.22]:
			Build.box(self, Vector3(0.05, 0.59, 0.64), pos + Vector3(side, 0, 0), wood)
		Build.static_box(self, Vector3(0.65, 0.6, 0.65), pos)
	for i: int in 5:
		Build.box(self, Vector3(0.14, 0.04, 0.8), Vector3(-8.8 + i * 0.2, 0.09, 2.8 + i * 0.13), wood, Vector3(0, i * 23, 0))


func _interaction(parent: Node3D, text: String, pos: Vector3) -> Interactable:
	var area := Interactable.new()
	area.prompt = text
	area.radius = 0.65
	area.position = pos
	parent.add_child(area)
	return area


func _marker(parent: Node3D, text: String, pos: Vector3) -> Label3D:
	var marker := Label3D.new()
	marker.text = text
	marker.font = UiStyle.font(600)
	marker.font_size = 48
	marker.pixel_size = 0.003
	marker.position = pos
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.modulate = Color(1, 0.82, 0.52)
	parent.add_child(marker)
	return marker


func reset() -> void:
	set_survivor_active(false)
	beacon_area.enabled = false
	_beacon_marker.hide()
	burning = false
	_fire.hide()
	for node: Node in _fire.get_children():
		if node is CPUParticles3D:
			(node as CPUParticles3D).emitting = false
	_sound.stop()
	set_process(false)


func set_survivor_active(value: bool) -> void:
	survivor.visible = value
	(survivor.get_node(^"Body") as CollisionShape3D).set_deferred(&"disabled", not value)
	survivor_area.enabled = value
	_survivor_marker.visible = value


func enable_beacon() -> void:
	survivor_area.enabled = false
	_survivor_marker.hide()
	beacon_area.enabled = true
	_beacon_marker.show()


func set_conversation_open(value: bool) -> void:
	survivor_area.enabled = not value
	_survivor_marker.visible = not value


func ignite() -> void:
	if burning:
		return
	burning = true
	beacon_area.enabled = false
	_beacon_marker.hide()
	_fire.show()
	for node: Node in _fire.get_children():
		if node is CPUParticles3D:
			(node as CPUParticles3D).restart()
			(node as CPUParticles3D).emitting = true
	_sound.play()
	set_process(true)


func _process(_delta: float) -> void:
	var time := float(Time.get_ticks_msec()) * 0.001
	_light.light_energy = 2.1 + sin(time * 7.3) * 0.17 + sin(time * 11.7) * 0.1
