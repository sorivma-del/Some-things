class_name Effects
extends RefCounted
## Particle effects built in code: fire, sparks, smoke, ground mist. CPU particles so
## they behave the same in the Forward+ and Compatibility renderers.

static var _soft_texture: GradientTexture2D


## Licking flames: additive soft blobs rising and shrinking, yellow to deep red.
static func flames(parent: Node3D, pos: Vector3) -> CPUParticles3D:
	var p := _particles(parent, pos, 48, 0.75, 0.55, BaseMaterial3D.BLEND_MODE_ADD)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.22
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.0, 1.6, 0.0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.7
	p.scale_amount_curve = _curve([Vector2(0.0, 0.7), Vector2(0.25, 1.0), Vector2(1.0, 0.0)])
	p.color_ramp = _gradient([
		[0.0, Color(1.0, 0.85, 0.45, 0.0)], [0.12, Color(1.0, 0.75, 0.35, 0.9)],
		[0.5, Color(1.0, 0.42, 0.12, 0.6)], [1.0, Color(0.6, 0.1, 0.02, 0.0)]])
	return p


## Sparks that drift up and wink out.
static func sparks(parent: Node3D, pos: Vector3) -> CPUParticles3D:
	var p := _particles(parent, pos, 22, 2.6, 0.05, BaseMaterial3D.BLEND_MODE_ADD)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0.0, 0.6, 0.0)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0
	p.damping_min = 0.4
	p.damping_max = 0.9
	p.tangential_accel_min = -0.6
	p.tangential_accel_max = 0.6
	p.color_ramp = _gradient([[0.0, Color(1.0, 0.8, 0.4, 1.0)], [0.7, Color(1.0, 0.45, 0.1, 0.9)], [1.0, Color(0.8, 0.2, 0.05, 0.0)]])
	return p


## Slow grey smoke column (campfire, chimneys).
static func smoke(parent: Node3D, pos: Vector3, amount: int = 14, size: float = 0.9) -> CPUParticles3D:
	var p := _particles(parent, pos, amount, 6.0, size, BaseMaterial3D.BLEND_MODE_MIX)
	p.direction = Vector3.UP
	p.spread = 8.0
	p.gravity = Vector3(0.25, 0.35, 0.05)  # A light wind leans the smoke.
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.7
	p.angular_velocity_min = -15.0
	p.angular_velocity_max = 15.0
	p.scale_amount_curve = _curve([Vector2(0.0, 0.4), Vector2(1.0, 2.2)])
	p.color_ramp = _gradient([[0.0, Color(0.3, 0.3, 0.32, 0.0)], [0.15, Color(0.3, 0.3, 0.32, 0.35)], [1.0, Color(0.35, 0.35, 0.38, 0.0)]])
	return p


## Low drifting mist over an area: large, very faint billboards.
static func ground_mist(parent: Node3D, centre: Vector3, extents: Vector3, amount: int = 40) -> CPUParticles3D:
	var p := _particles(parent, centre, amount, 30.0, 7.0, BaseMaterial3D.BLEND_MODE_MIX)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3(1.0, 0.0, 0.3)
	p.spread = 30.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	p.color_ramp = _gradient([[0.0, Color(0.6, 0.62, 0.68, 0.0)], [0.3, Color(0.6, 0.62, 0.68, 0.12)], [0.7, Color(0.6, 0.62, 0.68, 0.12)], [1.0, Color(0.6, 0.62, 0.68, 0.0)]])
	var mat := p.mesh.surface_get_material(0) as StandardMaterial3D
	# Fade where the sprite cuts into the ground instead of showing a hard edge.
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 1.5
	return p


static func _particles(parent: Node3D, pos: Vector3, amount: int, lifetime: float, size: float,
		blend: BaseMaterial3D.BlendMode) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = lifetime
	# Start fully developed: not-yet-born particles otherwise show as dark discs at the
	# emitter in the Compatibility renderer, and smoke would grow visibly after load.
	p.preprocess = lifetime
	p.randomness = 0.4
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = blend
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft()
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


static func _soft() -> GradientTexture2D:
	if _soft_texture == null:
		_soft_texture = GradientTexture2D.new()
		_soft_texture.fill = GradientTexture2D.FILL_RADIAL
		_soft_texture.fill_from = Vector2(0.5, 0.5)
		_soft_texture.fill_to = Vector2(0.5, 0.0)
		_soft_texture.gradient = _gradient([[0.0, Color(1, 1, 1, 1)], [0.5, Color(1, 1, 1, 0.45)], [1.0, Color(1, 1, 1, 0)]])
	return _soft_texture


static func _gradient(stops: Array) -> Gradient:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop: Array in stops:
		offsets.append(stop[0])
		colors.append(stop[1])
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	return g


static func _curve(points: Array[Vector2]) -> Curve:
	var c := Curve.new()
	for point: Vector2 in points:
		c.add_point(point)
	return c
