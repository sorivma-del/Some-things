class_name WorldEncounters
extends Node3D
## Enemies of the open world, by place: wolf packs in the two woods, bandits and their
## chief at the camp, a pair at the watchtower, infected at the farm and (after dark) at
## the graveyard. Ids are fixed (`world_<group>_<n>`) so kills persist through flags;
## a wiped-out group returns WorldConfig.respawn_days later. Deer roam the meadows.

const WOLF: PackedScene = preload("res://scenes/enemies/wolf.tscn")
const BANDIT: PackedScene = preload("res://scenes/enemies/bandit.tscn")
const CHIEF: PackedScene = preload("res://scenes/enemies/bandit_chief.tscn")
const INFECTED: PackedScene = preload("res://scenes/enemies/infected.tscn")
const DEER: PackedScene = preload("res://scenes/world/deer.tscn")

## Deer meadows: open ground near roads.
const MEADOWS: Array[Vector2] = [Vector2(-40, 40), Vector2(70, 60), Vector2(-20, 280)]

var _groups: Dictionary[String, Array] = {}
var _world: OpenWorld


func _ready() -> void:
	_world = get_parent() as OpenWorld
	GameState.time_changed.connect(_refresh)
	_refresh.call_deferred()
	_spawn_deer.call_deferred()


## Group id -> its enemies alive in the scene.
func groups() -> Dictionary[String, Array]:
	return _groups


func _definitions() -> Array[Dictionary]:
	var cfg := GameState.WORLD
	var night := GameState.world_period() == "night"
	var list: Array[Dictionary] = [
		{"id": "wolf_woods", "scene": WOLF, "count": cfg.wolves_per_pack, "place": "wolf_woods", "ring": 14.0, "pack": true},
		{"id": "dark_woods", "scene": WOLF, "count": cfg.wolves_per_pack, "place": "dark_woods", "ring": 14.0, "pack": true},
		{"id": "camp", "scene": BANDIT, "count": cfg.bandits_at_camp, "place": "camp", "ring": 9.0, "pack": true},
		{"id": "camp_chief", "scene": CHIEF, "count": 1, "place": "camp", "ring": 3.0, "pack": false},
		{"id": "tower", "scene": BANDIT, "count": cfg.bandits_at_tower, "place": "tower", "ring": 8.0, "pack": true},
		{"id": "farm", "scene": INFECTED, "count": cfg.infected_at_farm, "place": "farm", "ring": 8.0, "pack": false},
	]
	if night:
		list.append({"id": "graveyard", "scene": INFECTED, "count": cfg.infected_at_graveyard, "place": "graveyard", "ring": 7.0, "pack": false})
	return list


## Spawns groups that should be out and are not, removes the graveyard dead by day,
## and lets wiped-out groups return after enough days.
func _refresh() -> void:
	var wanted: Dictionary[String, bool] = {}
	for def: Dictionary in _definitions():
		var id: String = def["id"]
		wanted[id] = true
		_maybe_respawn(id, def["count"])
		if not _groups.has(id) or _alive(id).is_empty() and not GameState.world_cleared.has(id):
			_spawn_group(def)
	for id: String in _groups.keys():
		if not wanted.has(id):
			for enemy: Node in _groups[id]:
				if is_instance_valid(enemy):
					enemy.queue_free()
			_groups.erase(id)


func _maybe_respawn(id: String, count: int) -> void:
	if not GameState.world_cleared.has(id) or GameState.WORLD.respawn_days <= 0:
		return
	if GameState.world_day - GameState.world_cleared[id] < GameState.WORLD.respawn_days:
		return
	GameState.world_cleared.erase(id)
	for n: int in count:
		GameState.flags.erase("world_%s_%d_killed" % [id, n + 1])
	_groups.erase(id)


func _spawn_group(def: Dictionary) -> void:
	var id: String = def["id"]
	var count: int = def["count"]
	var centre := _world.place_position(def["place"])
	var ring: float = def["ring"]
	var list: Array = []
	for n: int in count:
		var enemy_id := "world_%s_%d" % [id, n + 1]
		if GameState.has_flag("%s_killed" % enemy_id):
			continue
		var enemy := (def["scene"] as PackedScene).instantiate() as Enemy
		enemy.enemy_id = enemy_id
		if def["pack"]:
			enemy.pack_id = "world_%s" % id
		var angle := TAU * n / maxf(count, 1.0) + 0.4
		var spot := centre + Vector3(cos(angle), 0.0, sin(angle)) * ring * 0.5
		enemy.position = _world.ground(spot.x, spot.z) + Vector3.UP * 0.2
		var route := PackedVector3Array()
		for k: int in 4:
			var a := angle + TAU * k / 4.0
			route.append(_world.ground(centre.x + cos(a) * ring, centre.z + sin(a) * ring))
		enemy.route = route
		add_child(enemy)
		if GameState.has_flag("%s_bribe" % enemy_id) or GameState.has_flag("%s_persuade" % enemy_id):
			enemy.start_calm()
		enemy.died.connect(_on_died.bind(id))
		list.append(enemy)
	_groups[id] = list
	if list.is_empty():
		GameState.world_cleared[id] = GameState.world_cleared.get(id, GameState.world_day)


func _on_died(_enemy: Enemy, group: String) -> void:
	if _alive(group).is_empty():
		GameState.world_cleared[group] = GameState.world_day
		GameState.set_flag("world_%s_cleared" % group)


func _alive(group: String) -> Array:
	return (_groups.get(group, []) as Array).filter(func(e: Node) -> bool: return is_instance_valid(e) and not e.get(&"dead"))


func _spawn_deer() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for h: int in mini(GameState.WORLD.deer_herds, MEADOWS.size()):
		for d: int in GameState.WORLD.deer_per_herd:
			var deer := DEER.instantiate() as Node3D
			var p := MEADOWS[h] + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
			deer.position = _world.ground(p.x, p.y) + Vector3.UP * 0.2
			deer.rotation.y = rng.randf() * TAU
			add_child(deer)
