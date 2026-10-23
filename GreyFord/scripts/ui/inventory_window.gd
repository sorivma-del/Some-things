class_name InventoryWindow
extends GameWindow
## The bag (I): what Mara wears and carries. Weapons, shields and armor are put on and
## taken off here; bandages and bread are used.


func _ready() -> void:
	super()
	add_to_group(&"inventory_window")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory"):
		if is_open:
			close_window()
		elif not GameState.controls_locked:
			open_window()
		get_viewport().set_input_as_handled()
		return
	super(event)


func _refresh() -> void:
	_clear()
	_title.text = "Сумка"
	var combat := get_tree().get_first_node_in_group(PlayerCombat.GROUP) as PlayerCombat
	var health := "   ·   здоровье %d" % roundi(combat.health) if combat else ""
	_subtitle.text = "Монеты: %d%s" % [GameState.coins, health]

	_heading("НАДЕТО")
	var slot_names: Dictionary[String, String] = {"weapon": "Оружие", "shield": "Щит", "armor": "Броня"}
	for slot: String in GameState.EQUIPMENT_SLOTS:
		var item := GameState.equipped(slot)
		if item:
			_row(_content, "%s:  %s" % [slot_names[slot], item.display_name], item.stat_line(), "", "Снять", _unequip.bind(slot))
		else:
			_row(_content, "%s:  —" % slot_names[slot], "", "")

	_heading("В СУМКЕ")
	var bag := GameState.bag()
	if bag.is_empty():
		_row(_content, "Пусто", "", "")
	for id: String in bag:
		var item := GameState.item(id)
		if item == null:
			continue
		var label := "%s  ×%d" % [item.display_name, bag[id]]
		if not item.slot().is_empty():
			if GameState.is_equipped(id) and GameState.spare(id) <= 0:
				_row(_content, label, item.stat_line(), "надето")
			else:
				_row(_content, label, item.stat_line(), "", "Надеть", _equip.bind(id))
		elif item.type == Item.Type.CONSUMABLE:
			_row(_content, label, item.stat_line(), "", "Съесть" if id == "bread" else "Применить", _use.bind(id), combat != null)
		else:
			_row(_content, label, item.description, "")


func _equip(id: String) -> void:
	GameState.equip(id)


func _unequip(slot: String) -> void:
	GameState.unequip(slot)


func _use(id: String) -> void:
	var combat := get_tree().get_first_node_in_group(PlayerCombat.GROUP) as PlayerCombat
	if combat:
		combat.use_item(id)
	_refresh()
