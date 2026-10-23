extends Node3D
## Helga's cauldron by the fire: turns one of each herb into a dose of medicine.
## Brewing costs a time slot and uses every full set of herbs in hand.

func _ready() -> void:
	var iron := Build.material(Color(0.12, 0.12, 0.13))
	Build.cylinder(self, 0.36, 0.42, Vector3(0.0, 0.36, 0.0), iron, 10)
	Build.cylinder(self, 0.4, 0.06, Vector3(0.0, 0.58, 0.0), iron, 10)
	Build.cylinder(self, 0.3, 0.02, Vector3(0.0, 0.6, 0.0), Build.material(Color(0.18, 0.22, 0.12)), 10)
	for i: int in 3:
		var a := TAU * i / 3.0
		Build.cylinder(self, 0.03, 0.4, Vector3(cos(a) * 0.3, 0.15, sin(a) * 0.3), iron, 5, Vector3(0.0, 0.0, 12.0))
	Effects.smoke(self, Vector3(0.0, 0.8, 0.0), 6, 0.45)
	Build.static_cylinder(self, 0.4, 0.7, Vector3(0.0, 0.35, 0.0))
	var use := Interactable.new()
	use.prompt = "Варить отвар  ·  1 действие"
	use.position = Vector3(0.0, 0.7, 0.0)
	use.radius = 1.0
	add_child(use)
	use.interacted.connect(_on_use)


func _on_use() -> void:
	if GameState.phase != GameState.Phase.DAY or GameState.slots_left <= 0:
		GameState.notified.emit("Сегодня уже не успеть")
		return
	if GameState.brewable_doses() <= 0:
		GameState.notified.emit("Нужно по одной: полынь, девясил, кровохлёбка")
		return
	GameState.lock_controls()
	GameState.spend_slot()
	await Transition.fade_out(0.6)
	GameState.brew()
	await get_tree().create_timer(0.8).timeout
	await Transition.fade_in(0.6)
	GameState.unlock_controls()
