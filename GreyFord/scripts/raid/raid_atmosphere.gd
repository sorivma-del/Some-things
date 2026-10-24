class_name RaidAtmosphere
extends Node3D
## Поджог телеги — видимое событие в сцене, без невидимого урона игроку.

const CONFIG: RaidConfig = preload("res://resources/raid/raid_config.tres")
const CART := Vector3(8.6, 0.0, 13.5)

var cart_ignited: bool = false


func _ready() -> void:
	_build_fire(Vector3(-5.5, 0, 21), 0.7)
	var ash := Effects.sparks(self, Vector3(0, 2.5, 13))
	ash.amount = 24
	ash.lifetime = 6.0
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(12, 1.5, 9)
	ash.gravity = Vector3(-0.08, 0.12, -0.5)
	ash.initial_velocity_min = 0.3
	ash.initial_velocity_max = 0.7


func ignite_cart() -> void:
	if cart_ignited:
		return
	cart_ignited = true
	var arrow := Node3D.new()
	arrow.position = Vector3(-3, 8, 30)
	add_child(arrow)
	var material := Build.material(Color(0.38, 0.2, 0.08), Color(1, 0.25, 0.03), 2.0)
	Build.box(arrow, Vector3(0.045, 0.045, 0.9), Vector3.ZERO, material)
	Effects.torch_flame(arrow, Vector3.ZERO)
	arrow.look_at(CART + Vector3.UP)
	var flight := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_property(arrow, ^"position", CART + Vector3.UP, CONFIG.ignition_flight_seconds)
	await flight.finished
	arrow.queue_free()
	_build_fire(CART, 1.1)
	var charred := Build.bark_material(Color(0.12, 0.09, 0.07))
	for i: int in 4:
		Build.box(self, Vector3(0.12, 0.1, 2.0), CART + Vector3(i * 0.25 - 0.4, 0.15, 0.8), charred, Vector3(0, 22 + i * 30, i * 4))


func _build_fire(spot: Vector3, size: float) -> void:
	var fire := Node3D.new()
	fire.position = spot
	fire.scale = Vector3.ONE * size
	add_child(fire)
	var flame := Effects.flames(fire, Vector3(0, 0.45, 0))
	style_flame(flame)
	Effects.sparks(fire, Vector3(0, 1, 0))
	var smoke := Effects.smoke(fire, Vector3(0, 1.2, 0), 18, 1.3)
	smoke.gravity = Vector3(-0.25, 0.5, -0.25)
	var light := FlickerLight.new()
	light.position.y = 1.8
	light.light_color = Color(1.0, 0.4, 0.13)
	light.base_energy = CONFIG.fire_energy
	light.omni_range = 10.0
	light.shadow_enabled = false
	fire.add_child(light)


func style_flame(flame: CPUParticles3D) -> void:
	flame.amount = 28
	flame.mesh = flame.mesh.duplicate() as Mesh
	var material := flame.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	(flame.mesh as QuadMesh).material = material
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0, 0.18, 0.6, 1])
	ramp.colors = PackedColorArray([Color(1, 0.5, 0.08, 0), Color(1, 0.45, 0.05, 0.95), Color(0.65, 0.14, 0.025, 0.65), Color(0.15, 0.05, 0.02, 0)])
	flame.color_ramp = ramp
	flame.emission_sphere_radius = 0.36
