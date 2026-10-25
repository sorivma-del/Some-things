class_name ShrineCraft
extends RefCounted
## Небольшие объёмные детали: скруглённые плиты, полые чаши и прозрачное пламя.


static func lathe(profile: PackedVector2Array, segments: int = 32) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in profile.size() - 1:
		for i: int in segments:
			var a := float(i) * TAU / segments
			var b := float(i + 1) * TAU / segments
			var low := profile[row]
			var high := profile[row + 1]
			var points: Array[Vector3] = [Vector3(cos(a) * low.x, low.y, sin(a) * low.x), Vector3(cos(b) * low.x, low.y, sin(b) * low.x), Vector3(cos(a) * high.x, high.y, sin(a) * high.x), Vector3(cos(b) * high.x, high.y, sin(b) * high.x)]
			for index: int in [0, 1, 2, 1, 3, 2]:
				st.set_uv(Vector2(float(i) / segments, float(row) / profile.size()))
				st.add_vertex(points[index])
	st.generate_normals()
	st.generate_tangents()
	st.index()
	return st.commit()


static func paver(width: float, depth: float, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var outline := PackedVector2Array()
	var bevel := 0.055
	for point: Vector2 in [Vector2(-width / 2 + bevel, -depth / 2), Vector2(width / 2 - bevel, -depth / 2), Vector2(width / 2, -depth / 2 + bevel), Vector2(width / 2, depth / 2 - bevel), Vector2(width / 2 - bevel, depth / 2), Vector2(-width / 2 + bevel, depth / 2), Vector2(-width / 2, depth / 2 - bevel), Vector2(-width / 2, -depth / 2 + bevel)]:
		outline.append(point + Vector2(rng.randf_range(-0.015, 0.015), rng.randf_range(-0.012, 0.012)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var low_a := Vector3(a.x, -0.025, a.y)
		var low_b := Vector3(b.x, -0.025, b.y)
		var high_a := Vector3(a.x * 0.985, 0.025, a.y * 0.94)
		var high_b := Vector3(b.x * 0.985, 0.025, b.y * 0.94)
		for p: Vector3 in [Vector3(0, 0.025, 0), high_a, high_b, low_a, low_b, high_a, low_b, high_b, high_a]:
			st.set_uv(Vector2(p.x, p.z))
			st.add_vertex(p)
	st.generate_normals()
	st.generate_tangents()
	st.index()
	return st.commit()


static func fire(parent: Node3D, height: float = 0.9) -> Node3D:
	var root := Node3D.new()
	root.name = "LayeredFlame"
	parent.add_child(root)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://resources/japan/flame.gdshader")
	for i: int in 3:
		var quad := QuadMesh.new()
		quad.size = Vector2(height * 0.72, height)
		var plane := MeshInstance3D.new()
		plane.mesh = quad
		plane.position.y = height * 0.5
		plane.rotation.y = i * PI / 3.0
		plane.material_override = mat
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(plane)
	return root
