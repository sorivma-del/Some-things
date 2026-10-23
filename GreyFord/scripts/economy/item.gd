class_name Item
extends Resource
## Something Mara can carry, wear, sell or use. All items are listed in
## resources/items/catalog.tres; herbs and the brewed remedy are items too.

enum Type { WEAPON, SHIELD, ARMOR, HERB, BREW, CONSUMABLE, TROPHY }

const TYPE_NAMES: Dictionary[Type, String] = {
	Type.WEAPON: "оружие", Type.SHIELD: "щит", Type.ARMOR: "броня", Type.HERB: "трава",
	Type.BREW: "отвар", Type.CONSUMABLE: "расходник", Type.TROPHY: "добыча",
}

@export var id: String = ""
@export var display_name: String = ""
@export var type: Type = Type.TROPHY
## Base price in coins; merchants buy and sell around it.
@export var price: int = 1
@export_multiline var description: String = ""

@export_group("Stats")
## Weapon: damage of a light attack.
@export var damage: float = 0.0
## Armor: share of incoming damage absorbed (0..1).
@export var defense: float = 0.0
## Shield: multiplier on the stamina a blocked blow costs (lower is better).
@export var block_cost_factor: float = 1.0
## Consumable: health restored.
@export var heal: float = 0.0

@export_group("Look")
## Model held in the hand (weapons, shields).
@export var model: PackedScene
## Position and rotation in the hand bone.
@export var hold_offset: Transform3D = Transform3D.IDENTITY


## Equipment slot this item goes into ("" if it cannot be worn).
func slot() -> String:
	match type:
		Type.WEAPON:
			return "weapon"
		Type.SHIELD:
			return "shield"
		Type.ARMOR:
			return "armor"
	return ""


## Short stat line for lists, e.g. "урон 26".
func stat_line() -> String:
	match type:
		Type.WEAPON:
			return "урон %d" % roundi(damage)
		Type.SHIELD:
			return "блок −%d%% выносливости" % roundi((1.0 - block_cost_factor) * 100.0) if block_cost_factor < 1.0 else "простой щит"
		Type.ARMOR:
			return "защита %d%%" % roundi(defense * 100.0)
		Type.CONSUMABLE:
			return "+%d здоровья" % roundi(heal)
	return TYPE_NAMES[type]
