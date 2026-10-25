extends "res://scripts/raid/raid_enemy.gd"
## Страж эпизода: катана и лёгкий ламеллярный доспех на существующем скелете.


func _ready() -> void:
	super()
	data.display_name = "Страж святилища"
	var model := _model as CharacterModel
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).contains("Head_Hood") or node.name == &"WornMantle":
			(node as MeshInstance3D).hide()
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.065, 0.085, 0.1)
	iron.metallic = 0.65
	iron.roughness = 0.42
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(0.32, 0.105, 0.065)
	cord.roughness = 0.88
	var armor := Node3D.new()
	armor.name = "LamellarArmor"
	for row: int in 6:
		Build.box(armor, Vector3(0.39, 0.052, 0.035), Vector3(0, 0.08 - row * 0.057, 0.145), iron)
		for x: float in [-0.13, 0.13]:
			Build.box(armor, Vector3(0.014, 0.048, 0.042), Vector3(x, 0.08 - row * 0.057, 0.149), cord)
	for side: int in [-1, 1]:
		for row: int in 4:
			var plate := Build.box(armor, Vector3(0.19, 0.06, 0.22), Vector3(side * (0.23 + row * 0.015), 0.12 - row * 0.055, 0), iron)
			plate.rotation.z = side * 0.18
	JapaneseProps._batch(armor)
	RaidAppearance._attach(model, model.get(&"_skeleton") as Skeleton3D, armor, &"spine_03", Vector3.ZERO)
	ShrineWardrobe.guard(model)
