class_name Build
extends RefCounted
## Helpers for assembling placeholder geometry out of primitives in code.

const FLAT_SHADER: Shader = preload("res://resources/flat.gdshader")

static var _material_cache: Dictionary[String, ShaderMaterial] = {}


## Flat-shaded material, cached per color/emission combination.
static func material(color: Color, glow: Color = Color.BLACK, glow_energy: float = 0.0) -> ShaderMaterial:
	var key := "%s|%s|%.2f" % [color.to_html(), glow.to_html(), glow_energy]
	if _material_cache.has(key):
		return _material_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = FLAT_SHADER
	mat.set_shader_parameter(&"albedo", color)
	mat.set_shader_parameter(&"emission", glow)
	mat.set_shader_parameter(&"emission_energy", glow_energy)
	_material_cache[key] = mat
	return mat


static func mesh(parent: Node3D, primitive: PrimitiveMesh, mat: Material, pos: Vector3,
		rot_deg: Vector3 = Vector3.ZERO, shadows: bool = true) -> MeshInstance3D:
	primitive.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = primitive
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return mesh(parent, m, mat, pos, rot_deg)


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material,
		segments: int = 7, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = segments
	m.rings = 0
	return mesh(parent, m, mat, pos, rot_deg)


static func cone(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material,
		segments: int = 6, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = segments
	m.rings = 0
	return mesh(parent, m, mat, pos, rot_deg)


## Gable roof: a triangular prism lying along the local Z axis.
static func prism(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = size
	return mesh(parent, m, mat, pos, rot_deg)


static func static_box(parent: Node3D, size: Vector3, pos: Vector3,
		rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)
	return body


static func static_cylinder(parent: Node3D, radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	parent.add_child(body)
	return body
