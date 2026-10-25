class_name ShrineWardrobe
extends RefCounted
## Локальная отделка одежды и кабуто. Геометрия и голова Мары не заменяются.


static func survivor(model: CharacterModel) -> void:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var label := String(mesh.name)
		if label.contains("Peasant"):
			var boots := label.contains("Feet")
			var color := Color(0.16, 0.21, 0.22) if not boots else Color(0.18, 0.12, 0.075)
			for surface: int in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(surface, RaidAppearance._material(mesh.get_active_material(surface) as StandardMaterial3D, color, false, boots))
	var cloth := RaidAppearance._material(null, Color(0.21, 0.25, 0.23), false, false)
	var wrap := Node3D.new()
	wrap.name = "CrossedRobeCollar"
	for side: float in [-1, 1]:
		var panel := Build.box(wrap, Vector3(0.065, 0.33, 0.02), Vector3(side * 0.055, 0.02, 0.16), cloth)
		panel.rotation.z = side * 0.37
	JapaneseProps._batch(wrap)
	RaidAppearance._attach(model, model.get(&"_skeleton") as Skeleton3D, wrap, &"spine_03", Vector3.ZERO)
	var sash := Node3D.new()
	sash.name = "WovenWaistSash"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.165
	ring.outer_radius = 0.185
	ring.rings = 28
	ring.ring_segments = 8
	var belt := Build.mesh(sash, ring, cloth, Vector3.ZERO)
	belt.scale = Vector3(1, 3.0, 0.7)
	RaidAppearance._attach(model, model.get(&"_skeleton") as Skeleton3D, sash, &"pelvis", Vector3(0, 0.08, 0))


static func guard(model: CharacterModel) -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.075, 0.095, 0.105)
	steel.metallic = 0.72
	steel.roughness = 0.48
	var copper := StandardMaterial3D.new()
	copper.albedo_color = Color(0.36, 0.26, 0.1)
	copper.metallic = 0.75
	copper.roughness = 0.42
	var helmet := Node3D.new()
	helmet.name = "Kabuto"
	var dome := MeshInstance3D.new()
	dome.mesh = ShrineCraft.lathe(PackedVector2Array([Vector2(0.23, -0.02), Vector2(0.19, 0.035), Vector2(0.165, 0.13), Vector2(0.1, 0.21), Vector2(0, 0.24)]), 28)
	dome.material_override = steel
	helmet.add_child(dome)
	for row: int in 4:
		var radius := 0.19 + row * 0.018
		for segment: int in 9:
			var angle := PI * 0.5 + (segment + 0.5) * PI / 9
			var plate := Build.box(helmet, Vector3(0.09, 0.045, 0.065), Vector3(sin(angle) * radius, -0.045 - row * 0.034, cos(angle) * radius), steel)
			plate.rotation.y = angle
	for side: float in [-1, 1]:
		var crest := Build.box(helmet, Vector3(0.018, 0.11, 0.018), Vector3(side * 0.035, 0.16, 0.185), copper)
		crest.rotation.z = -side * 0.4
	Build.cylinder(helmet, 0.018, 0.025, Vector3(0, 0.1, 0.19), copper, 10, Vector3(90, 0, 0))
	JapaneseProps._batch(helmet)
	RaidAppearance._attach(model, model.get(&"_skeleton") as Skeleton3D, helmet, &"Head", Vector3(0, 0.08, 0))
