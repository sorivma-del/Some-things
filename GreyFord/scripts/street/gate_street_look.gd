class_name GateStreetLook
extends RefCounted
## Новый участок у ворот: две постройки и хвойные деревья в прежних местах.

const FIR: PackedScene = preload("res://resources/models/gate_street/fir/fir_street.gltf")


static func apply(village: Node3D) -> void:
	for node: Node in village.get_children():
		var house := node as Node3D
		if house == null:
			continue
		if house.position.distance_to(Vector3(13, 0, 9)) < 0.2 or house.position.distance_to(Vector3(-13, 0, 8.5)) < 0.2:
			for mesh: Node in house.find_children("*", "MeshInstance3D", true, false):
				(mesh as MeshInstance3D).hide()
			for child: Node in house.get_children():
				if child is CPUParticles3D and (child as CPUParticles3D).position.y > 7:
					(child as CPUParticles3D).position.y = 6.05
			var cottage := StreetCottage.new()
			cottage.depth = 4.0 if house.position.x > 0 else 3.0
			cottage.lit = house.position.x > 0
			house.add_child(cottage)
	var candidates: Array[Node3D] = []
	for node: Node in village.get_children():
		var tree := node as Node3D
		if tree and tree.scene_file_path.contains("/nature/Pine") and tree.position.z > 18 and absf(tree.position.x) < 32:
			candidates.append(tree)
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.distance_squared_to(Vector3(0, 0, 23)) < b.position.distance_squared_to(Vector3(0, 0, 23)))
	for i: int in mini(4, candidates.size()):
		var tree := candidates[i]
		for mesh: Node in tree.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).hide()
		var fir := FIR.instantiate() as Node3D
		fir.name = "DetailedFir"
		fir.scale = Vector3.ONE * 1.3
		tree.add_child(fir)
		for node: Node in fir.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			# У исходной хвои сплошная геометрия и JPEG без альфа-канала.
			# Прозрачный проход исходного материала здесь только увеличивает нагрузку.
			for surface: int in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
				if material and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					var opaque := material.duplicate() as StandardMaterial3D
					opaque.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					mesh.set_surface_override_material(surface, opaque)
			mesh.lod_bias = 0.2
			mesh.visibility_range_end = 110.0
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if i == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
