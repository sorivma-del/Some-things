class_name TradeWindow
extends GameWindow
## Buying from and selling to a merchant. Opens when a merchant's dialogue calls
## GameState.open_trade(id) (after the dialogue closes). Prices: MerchantData + trust.

var merchant_id: String = ""


func _ready() -> void:
	super()
	add_to_group(&"trade_window")
	GameState.trade_requested.connect(_on_trade_requested)


func open_for(id: String) -> void:
	merchant_id = id
	open_window()


func _on_trade_requested(id: String) -> void:
	if DialogueRunner.is_active:
		await DialogueRunner.dialogue_finished
	open_for(id)


func _refresh() -> void:
	_clear()
	var data: MerchantData = GameState.MERCHANTS[merchant_id]
	_title.text = data.display_name
	_subtitle.text = "Монеты: %d   ·   доверие %d   ·   продаёт дешевле тем, кому верит" % [GameState.coins, GameState.get_trust(merchant_id)]

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 24)
	_content.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)

	_column_heading(left, "КУПИТЬ")
	var goods := GameState.stock(merchant_id)
	for id: String in goods:
		var item := GameState.item(id)
		var left_count := int(goods[id])
		if item == null or left_count <= 0:
			continue
		var price := GameState.buy_price(merchant_id, id)
		_row(left, "%s  ×%d" % [item.display_name, left_count], item.stat_line(), str(price),
				"Купить", _buy.bind(id), GameState.coins >= price)

	_column_heading(right, "ПРОДАТЬ")
	var any := false
	for id: String in GameState.bag():
		var item := GameState.item(id)
		if item == null or not data.buys(item) or GameState.spare(id) <= 0:
			continue
		any = true
		_row(right, "%s  ×%d" % [item.display_name, GameState.spare(id)], item.stat_line(),
				str(GameState.sell_price(merchant_id, id)), "Продать", _sell.bind(id))
	if not any:
		var nothing := Label.new()
		nothing.text = "Нечего предложить."
		UiStyle.apply_label(nothing, 20, 500, true, UiStyle.COLOR_DIM)
		right.add_child(nothing)


func _column_heading(parent: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	UiStyle.apply_label(label, 18, 700, false, UiStyle.COLOR_ACCENT, 4)
	parent.add_child(label)


func _buy(id: String) -> void:
	GameState.buy(merchant_id, id)
	_refresh()


func _sell(id: String) -> void:
	GameState.sell(merchant_id, id)
	_refresh()
