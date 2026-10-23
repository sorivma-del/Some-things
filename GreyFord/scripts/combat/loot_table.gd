class_name LootTable
extends Resource
## What a fallen enemy drops: some coins and up to `max_items` rolls on the entries.
## Entry ids are herb ids (wormwood, elecampane, burnet) or item ids.

@export var coins_min: int = 0
@export var coins_max: int = 0
@export var max_items: int = 2
## Parallel arrays: id, chance 0..1 that it drops, how many.
@export var item_ids: PackedStringArray = []
@export var item_chances: PackedFloat32Array = []
@export var item_counts: PackedInt32Array = []


## id -> count, plus "coins".
func roll(rng: RandomNumberGenerator) -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	var coins := rng.randi_range(coins_min, coins_max)
	if coins > 0:
		result["coins"] = coins
	var dropped := 0
	for i: int in item_ids.size():
		if dropped >= max_items:
			break
		if rng.randf() < item_chances[i]:
			result[item_ids[i]] = result.get(item_ids[i], 0) + (item_counts[i] if i < item_counts.size() else 1)
			dropped += 1
	return result
