class_name MerchantData
extends Resource
## A trader's goods and prices (resources/merchants/*.tres). Prices move with the
## trader's trust in Mara (GameState.trust[id]): at 0 trust the "low" factors apply,
## at 100 the "high" ones, in between they blend. Selling always pays less than buying.

@export var id: String = ""
@export var display_name: String = ""
## Goods on offer and how many of each (restocked every morning).
@export var stock_ids: PackedStringArray = []
@export var stock_counts: PackedInt32Array = []
## Item types this trader buys from Mara (Item.Type values).
@export var buys_types: Array[Item.Type] = []

@export_group("Prices")
## Buying from the trader: price × factor.
@export var buy_factor_low_trust: float = 1.3
@export var buy_factor_high_trust: float = 0.95
## Selling to the trader: price × factor.
@export var sell_factor_low_trust: float = 0.35
@export var sell_factor_high_trust: float = 0.6


func buy_price(item: Item, trust: int) -> int:
	var factor := lerpf(buy_factor_low_trust, buy_factor_high_trust, clampf(trust / 100.0, 0.0, 1.0))
	return maxi(1, roundi(item.price * factor))


func sell_price(item: Item, trust: int) -> int:
	var factor := lerpf(sell_factor_low_trust, sell_factor_high_trust, clampf(trust / 100.0, 0.0, 1.0))
	return clampi(roundi(item.price * factor), 1, maxi(1, buy_price(item, trust) - 1))


func buys(item: Item) -> bool:
	return buys_types.has(item.type)
