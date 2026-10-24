class_name VillageRaid
extends Node3D
## Самостоятельный эпизод: тревога, две волны, победа или поражение с повтором.

signal phase_changed(phase: Phase)
enum Phase { WARNING, FIRST_WAVE, BREATHER, FINAL_WAVE, VICTORY, DEFEAT }

const CONFIG: RaidConfig = preload("res://resources/raid/raid_config.tres")
const LOOK: WorldConfig = preload("res://resources/world/world_config.tres")
const BANDIT: PackedScene = preload("res://scenes/raid/raider.tscn")
const CHIEF: PackedScene = preload("res://scenes/raid/raid_chief.tscn")
const CIVILIAN: PackedScene = preload("res://scenes/raid/villager.tscn")

var phase: Phase = Phase.WARNING
var sheltered: int = 0
var enemies: Array[Enemy] = []
var _villagers: Array[RaidCivilian] = []
var _pending_raiders: int = 0
var _chief_pending: bool = false
var _refill_scheduled: bool = false
var _serial: int = 0
var _owns_lock: bool = false
var _intro_camera := Camera3D.new()
var _caption := Label.new()
var _results := VBoxContainer.new()
var _fires := RaidAtmosphere.new()

@onready var _hero: PlayerCombat = $Player/Combat


func _ready() -> void:
	add_to_group(&"village_raid")
	GameState.world_mode = false
	_build_overlay()
	_build_damage()
	if CONFIG.street_upgrade:
		GateStreetLook.apply($Village)
	_disable_story_interactions()
	_hero.died.connect(_on_hero_died)
	$Environment.call(&"set_world_look", LOOK)
	$Environment.call(&"_apply", "evening", 0.0)
	_begin.call_deferred()


func _exit_tree() -> void:
	_unlock()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_menu()
		get_viewport().set_input_as_handled()


func _begin() -> void:
	var serial := _serial
	_lock()
	get_tree().call_group(&"hud", &"set_day_status_visible", false)
	_objective("НАБЕГ НА СЕРЫЙ БРОД", "Томаш: Чужие у ворот! Все в церковь!")
	add_child(_intro_camera)
	_intro_camera.global_position = Vector3(9, 6, 8)
	_intro_camera.look_at(Vector3(0, 1.0, -5))
	_intro_camera.make_current()
	var shot := create_tween()
	shot.tween_property(_intro_camera, ^"position", Vector3(5, 4.5, 6), CONFIG.warning_seconds * 0.5)
	_evacuate()
	_spawn_wave(CONFIG.first_wave_count, false, false)
	$Gate.call(&"open")
	Transition.fade_in(0.7)
	await get_tree().create_timer(CONFIG.warning_seconds * 0.5).timeout
	if serial != _serial or phase != Phase.WARNING:
		return
	_intro_camera.position = Vector3(7, 4, 17)
	_intro_camera.look_at(Vector3(0, 1.5, 24))
	var approach := create_tween()
	approach.tween_property(_intro_camera, ^"position", Vector3(4, 3, 18), CONFIG.warning_seconds * 0.5)
	await get_tree().create_timer(CONFIG.warning_seconds * 0.5).timeout
	if serial == _serial and phase == Phase.WARNING:
		start_attack()


func start_attack() -> void:
	if phase != Phase.WARNING:
		return
	_serial += 1
	if is_instance_valid(_intro_camera) and _intro_camera.is_inside_tree():
		_intro_camera.queue_free()
	$CameraRig.call(&"make_current")
	_unlock()
	_set_phase(Phase.FIRST_WAVE)
	_objective("Удержите улицу у ворот", "ЛКМ / J — комбо · Shift перед ударом — парирование · пробел — перекат · Q — цель · H — перевязка")
	if alive_count() == 0:
		_spawn_wave(CONFIG.first_wave_count, false)
	else:
		for enemy: Enemy in enemies:
			enemy.set_physics_process(true)
			enemy.join_hunt($Player.global_position)
	_refresh_wave_goal()
	_fires.ignite_cart()


func alive_count() -> int:
	var count: int = 0
	for enemy: Variant in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			count += 1
	return count


func _spawn_wave(count: int, chief: bool, engage: bool = true) -> void:
	_pending_raiders = count
	_chief_pending = chief
	_fill_slots(engage)


func _fill_slots(engage: bool = true) -> void:
	while alive_count() < CONFIG.max_active_enemies and (_pending_raiders > 0 or _chief_pending):
		var chief := _chief_pending
		if chief:
			_chief_pending = false
		else:
			_pending_raiders -= 1
		var lane := enemies.size() % CONFIG.max_active_enemies
		var spot := Vector3(-1.8 + lane * 1.2, 0.2, 24.0 + (enemies.size() % 2) * 1.2)
		_spawn_enemy(CHIEF if chief else BANDIT, spot, chief, engage)
	_refresh_wave_goal()


func _refresh_wave_goal() -> void:
	if phase == Phase.FIRST_WAVE:
		get_tree().call_group(&"hud", &"set_objective", "Первая волна · противников осталось: %d" % (alive_count() + pending_count()))
	elif phase == Phase.FINAL_WAVE:
		get_tree().call_group(&"hud", &"set_objective", "Атаман Ржа и его отряд · осталось: %d" % (alive_count() + pending_count()))


func pending_count() -> int:
	return _pending_raiders + (1 if _chief_pending else 0)


func may_attack(candidate: Enemy) -> bool:
	var attackers: int = 0
	for enemy: Variant in enemies:
		if is_instance_valid(enemy) and enemy != candidate and not enemy.dead and enemy.state == Enemy.State.ATTACK:
			attackers += 1
	return attackers < CONFIG.max_attackers


func _spawn_enemy(scene: PackedScene, spot: Vector3, chief: bool, engage: bool) -> void:
	var enemy := scene.instantiate() as Enemy
	enemy.data = enemy.data.duplicate() as EnemyData
	enemy.data.max_health = CONFIG.chief_health if chief else CONFIG.raider_health
	enemy.data.sight_radius = CONFIG.sight_radius
	enemy.data.leash_distance = CONFIG.leash_distance
	enemy.set(&"role", 3 if chief else enemies.size() % 3)
	if not chief and enemies.size() % 3 == 2:
		enemy.weapon_scene = preload("res://resources/models/props/Axe_Bronze.gltf")
		enemy.weapon_offset = GameState.item("woodsman_axe").hold_offset
	enemy.parley = null
	enemy.enemy_id = "raid_%d" % enemies.size()
	enemy.pack_id = "raid"
	var ground := get_tree().get_first_node_in_group(&"terrain") as Terrain
	if ground:
		spot.y = ground.height_at(spot.x, spot.z) + 0.05
	enemy.position = spot
	add_child(enemy)
	enemies.append(enemy)
	enemy.died.connect(_enemy_died)
	if engage:
		enemy.join_hunt($Player.global_position)
	else:
		enemy.set_physics_process(false)


func _enemy_died(_enemy: Enemy) -> void:
	if phase not in [Phase.FIRST_WAVE, Phase.FINAL_WAVE] or _refill_scheduled:
		return
	_refill_scheduled = true
	_replenish.call_deferred()


func _replenish() -> void:
	_refill_scheduled = false
	if phase not in [Phase.FIRST_WAVE, Phase.FINAL_WAVE]:
		return
	_fill_slots()
	if alive_count() > 0 or pending_count() > 0:
		return
	if phase == Phase.FIRST_WAVE:
		_between_waves()
	elif phase == Phase.FINAL_WAVE:
		_finish(true)


func _between_waves() -> void:
	_set_phase(Phase.BREATHER)
	var serial := _serial
	_hero.health = minf(_hero.data.max_health, _hero.health + CONFIG.breather_heal)
	_hero.health_changed.emit(_hero.health, _hero.data.max_health)
	_objective("Первая атака отбита", "У ворот слышен новый голос. Приготовьтесь к бою с главарём.")
	await get_tree().create_timer(CONFIG.breather_seconds).timeout
	if serial != _serial or phase != Phase.BREATHER:
		return
	_set_phase(Phase.FINAL_WAVE)
	_objective("Одолейте атамана Ржу", "Не принимайте тяжёлые удары на месте. Отступайте и берегите выносливость.")
	_spawn_wave(CONFIG.escort_count, true)


func _on_hero_died() -> void:
	_finish(false)


func _finish(won: bool) -> void:
	if phase in [Phase.VICTORY, Phase.DEFEAT]:
		return
	_serial += 1
	_pending_raiders = 0
	_chief_pending = false
	_set_phase(Phase.VICTORY if won else Phase.DEFEAT)
	_lock()
	for enemy: Variant in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.start_calm()
	_objective("Деревня выстояла" if won else "Оборона сломлена", "Набег отбит. Люди начинают выходить из укрытий." if won else "Мара пала. Попробуйте снова: блокируйте и разделяйте противников.")
	_results.show()
	_results.get_child(0).grab_focus()
	if won:
		for i: int in _villagers.size():
			var lane := -3.0 if i == 0 else 3.0 + i * 0.5
			_villagers[i].evacuate(PackedVector3Array([Vector3(lane, 0, -5), Vector3(lane, 0, 3), Vector3(-4 + i * 4, 0, 4)]), false)
		var tween := create_tween()
		tween.tween_property(_fires, ^"scale", Vector3.ONE * 0.75, 2.5)


func _evacuate() -> void:
	for i: int in 3:
		var person := CIVILIAN.instantiate() as RaidCivilian
		person.position = Vector3(-4 + i * 4.0, 0.2, 4 + i * 2.0)
		add_child(person)
		_villagers.append(person)
		person.sheltered.connect(func() -> void: sheltered += 1)
		var lane := -3.0 if i == 0 else 3.0 + i * 0.5
		person.evacuate(PackedVector3Array([Vector3(lane, 0, 3), Vector3(lane, 0, -6), Vector3(-1 + i, 0, -11.5)]))


func _disable_story_interactions() -> void:
	for node: Node in $Village.find_children("*", "Area3D", true, false):
		if node is Interactable:
			(node as Interactable).enabled = false


func _build_damage() -> void:
	add_child(_fires)
	_fires.style_flame($Campfire.get(&"_flames") as CPUParticles3D)
	var terrain := get_tree().get_first_node_in_group(&"terrain") as Terrain
	if terrain:
		for node: Node in terrain.get_children():
			if node is MeshInstance3D:
				var material := (node as MeshInstance3D).material_override as ShaderMaterial
				if material:
					material.set_shader_parameter("normal_strength", LOOK.ground_normal_strength)


func _build_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 12
	add_child(overlay)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.offset_left = -540
	_caption.offset_right = 540
	_caption.offset_top = -85
	_caption.offset_bottom = -50
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.apply_label(_caption, 21, 500, true, UiStyle.COLOR_TEXT)
	overlay.add_child(_caption)
	_results.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_results.offset_top = 110
	_results.offset_left = -160
	_results.offset_right = 160
	_results.add_child(UiStyle.button("Повторить набег", _retry, 28))
	_results.add_child(UiStyle.button("Главное меню", _menu, 28))
	overlay.add_child(_results)
	_results.hide()


func _objective(title: String, caption: String) -> void:
	get_tree().call_group(&"hud", &"set_objective", title)
	_caption.text = caption


func _set_phase(value: Phase) -> void:
	phase = value
	phase_changed.emit(phase)


func _lock() -> void:
	if not _owns_lock:
		GameState.lock_controls()
		_owns_lock = true


func _unlock() -> void:
	if _owns_lock:
		GameState.unlock_controls()
		_owns_lock = false


func _retry() -> void:
	_unlock()
	GameState.new_game()
	get_tree().change_scene_to_file("res://scenes/raid/village_raid.tscn")


func _menu() -> void:
	_unlock()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
