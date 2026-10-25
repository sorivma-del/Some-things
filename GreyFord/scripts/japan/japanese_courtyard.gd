class_name JapaneseCourtyard
extends Node3D
## Изолированная пробная локация: осмотр света и тренировка без записи сохранений.

const RAID: RaidConfig = preload("res://resources/raid/raid_config.tres")
const RAIDER: PackedScene = preload("res://scenes/raid/raider.tscn")
const SPAWN := Vector3(0, 0.2, -10)
var enemies: Array[RaidEnemy] = []
var training: bool = false
var evening: bool = false
var _old_taa: bool = false
var _uses_taa: bool = false
var _env: Environment
var _hint: Label
var _status: Label
var _training_button: Button

@onready var _hero: PlayerCombat = $Player/Combat


func _ready() -> void:
	_old_taa = get_viewport().use_taa
	_uses_taa = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	if _uses_taa:
		get_viewport().use_taa = true
	add_to_group(&"village_raid")
	$Player/Model.rotation.y = PI
	var terrain := Terrain.new()
	terrain.size = 80
	terrain.village_radius = 27.0
	terrain.hill_height = 3.0
	terrain.flat_spots = [Vector3(0, 3, 23)]
	add_child(terrain)
	terrain.build()
	JapaneseProps.build(self)
	var wind := AudioStreamPlayer.new()
	wind.stream = ProceduralSound.wind()
	wind.volume_db = -20.0
	add_child(wind)
	ProceduralSound.play_soon(wind)
	_env = ($WorldEnvironment as WorldEnvironment).environment.duplicate(true) as Environment
	($WorldEnvironment as WorldEnvironment).environment = _env
	_build_ui()
	GameControls.scheme_changed.connect(_on_control_scheme)
	_on_control_scheme(GameControls.using_gamepad)
	set_evening(false)
	_hero.died.connect(_on_hero_died)
	_setup_hud.call_deferred()
	Transition.fade_in(0.5)


func _setup_hud() -> void:
	get_tree().call_group(&"hud", &"set_day_status_visible", false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_menu()
		get_viewport().set_input_as_handled()


func set_evening(value: bool) -> void:
	evening = value
	var sky := _env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = Color(0.10, 0.17, 0.23) if value else Color(0.28, 0.41, 0.48)
	sky.sky_horizon_color = Color(0.38, 0.45, 0.45) if value else Color(0.67, 0.72, 0.66)
	_env.ambient_light_energy = 0.38 if value else 0.65
	_env.ambient_light_color = Color(0.55, 0.64, 0.72)
	_env.fog_density = 0.013 if value else 0.008
	_env.fog_light_color = Color(0.33, 0.42, 0.44) if value else Color(0.58, 0.66, 0.64)
	var sun := $Sun as DirectionalLight3D
	sun.light_energy = 0.6 if value else 1.2
	sun.light_color = Color(0.68, 0.77, 0.85) if value else Color(1.0, 0.94, 0.82)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.position = Vector2(28, 20)
	title.text = "Двор у святилища"
	UiStyle.apply_label(title, 30, 600)
	layer.add_child(title)
	_status = Label.new()
	_status.position = Vector2(28, 60)
	_status.text = "Осмотр двора"
	UiStyle.apply_label(_status, 19, 500, true)
	layer.add_child(_status)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -235
	panel.offset_top = -242
	panel.offset_right = -24
	panel.offset_bottom = -52
	panel.add_theme_constant_override(&"separation", 6)
	layer.add_child(panel)
	panel.add_child(_button("Утро", func() -> void: set_evening(false)))
	panel.add_child(_button("Сумерки", func() -> void: set_evening(true)))
	_training_button = _button("Начать тренировку", _start_training)
	panel.add_child(_training_button)
	panel.add_child(_button("В главное меню", _menu))
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -38
	_hint.offset_left = -550
	_hint.offset_right = 550
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = "WASD — движение · ПКМ — камера · ЛКМ — удар · K — тяжёлый · Shift — блок · пробел — перекат · Q — цель"
	UiStyle.apply_label(_hint, 18, 500, true)
	layer.add_child(_hint)


func _button(text: String, action: Callable) -> Button:
	var button := UiStyle.button(text, func() -> void:
		GameControls.consume_menu_action()
		action.call(), 22)
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.focus_mode = Control.FOCUS_NONE
	return button


func _start_training() -> void:
	if training:
		return
	for enemy: RaidEnemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	_hero.call(&"_set_target", null)
	_hero.call(&"_set_state", PlayerCombat.State.NORMAL)
	_hero.restore()
	_hero.set(&"_knockback", Vector3.ZERO)
	_hero.set(&"_move_velocity", Vector3.ZERO)
	$Player.call(&"teleport", SPAWN)
	training = true
	_training_button.disabled = true
	_status.text = "Тренировка: налётчик, щитоносец и рубака"
	for i: int in 3:
		var enemy := RAIDER.instantiate() as RaidEnemy
		enemy.role = i as RaidEnemy.Role
		enemy.data = enemy.data.duplicate(true) as EnemyData
		enemy.data.max_health = RAID.raider_health
		enemy.data.sight_radius = RAID.sight_radius
		enemy.data.leash_distance = RAID.leash_distance
		enemy.data.loot = null
		enemy.parley = null
		enemy.enemy_id = "courtyard_training_%d" % i
		enemy.position = Vector3(-4 + i * 4, 0.2, 2 + i)
		add_child(enemy)
		enemies.append(enemy)
		enemy.died.connect(_on_enemy_died)
		enemy.join_hunt(SPAWN)


func may_attack(candidate: Enemy) -> bool:
	var attackers: int = 0
	for enemy: RaidEnemy in enemies:
		if is_instance_valid(enemy) and enemy != candidate and not enemy.dead and enemy.state == Enemy.State.ATTACK:
			attackers += 1
	return training and attackers < RAID.max_attackers


func _on_enemy_died(_enemy: Enemy) -> void:
	for enemy: RaidEnemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			return
	training = false
	_status.text = "Тренировка завершена"
	_training_button.text = "Повторить тренировку"
	_training_button.disabled = false


func _on_hero_died() -> void:
	training = false
	for enemy: RaidEnemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)
	_status.text = "Поражение. Попробуй парирование и тяжёлый удар"
	_training_button.text = "Повторить тренировку"
	_training_button.disabled = false


func _menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _exit_tree() -> void:
	if _uses_taa:
		get_viewport().use_taa = _old_taa


func _on_control_scheme(gamepad: bool) -> void:
	_hint.text = "ЛС — движение · ПС — камера · □ — удар · △ — тяжёлый · L1 — блок · ○ — перекат · R3 — цель · Options — меню" if gamepad else "WASD — движение · ПКМ — камера · " + GameControls.combat_hint()
