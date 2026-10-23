class_name SickHouse
extends Interactable
## The door of a plague house where a patient lies. Going in costs a time slot; inside,
## a dialogue lets Mara talk and give medicine. A dead patient's house costs nothing.

const DIALOGUE: DialogueResource = preload("res://dialogues/sick.dialogue")
## Dative case for "Войти к ...".
const TO_PATIENT: Dictionary[String, String] = {"anka": "Анке", "yan": "Яну"}

@export var patient: String = "anka"


func _ready() -> void:
	super()
	_update_prompt()
	GameState.sick_changed.connect(_update_prompt)
	GameState.time_changed.connect(_update_prompt)
	interacted.connect(_on_interacted)


func _update_prompt() -> void:
	if not GameState.is_alive(patient):
		prompt = "Дом с крестом"
	elif GameState.phase == GameState.Phase.NIGHT:
		prompt = "Дверь заперта на ночь"
	else:
		prompt = "Войти к %s  ·  1 действие" % TO_PATIENT.get(patient, patient)


func _on_interacted() -> void:
	if not GameState.is_alive(patient):
		DialogueRunner.start_dialogue(DIALOGUE, patient + "_dead")
		return
	if GameState.phase == GameState.Phase.NIGHT:
		return
	if GameState.slots_left <= 0:
		GameState.notified.emit("Сегодня уже не успеть")
		return
	GameState.spend_slot()
	DialogueRunner.start_dialogue(DIALOGUE, patient)
