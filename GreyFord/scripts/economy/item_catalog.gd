class_name ItemCatalog
extends Resource
## Every item in the game (resources/items/catalog.tres).

@export var items: Array[Item] = []

var _by_id: Dictionary[String, Item] = {}


func find(id: String) -> Item:
	if _by_id.is_empty():
		for item: Item in items:
			_by_id[item.id] = item
	return _by_id.get(id)
