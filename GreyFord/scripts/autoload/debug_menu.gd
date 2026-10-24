extends CanvasLayer
## Debug panel (F3) for playtesting: time, purse and health, story flags, every enemy's
## state and health, watchmen's alertness; buttons for coins, invulnerability, spawning
## a wolf or a bandit, jumping to a merchant and skipping ahead in time.
## The game keeps running underneath; controls are not locked.

const WOLF := "res://scenes/enemies/wolf.tscn"
const BANDIT := "res://scenes/enemies/bandit.tscn"
const REFRESH := 0.25

var _panel: PanelContainer
var _info: RichTextLabel
var _invulnerable: Button
var _timer: float = 0.0
var _merchant_index: int = 0
var _place_index: int = -1


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		_panel.visible = not _panel.visible
		_refresh()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		_refresh()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 90)
	_panel.custom_minimum_size = Vector2(430, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.035, 0.86)
	style.border_color = Color(0.55, 0.42, 0.26, 0.6)
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override(&"panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "ОТЛАДКА  ·  F3"
	UiStyle.apply_label(title, 16, 700, false, UiStyle.COLOR_ACCENT, 3)
	column.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 2)
	column.add_child(grid)
	grid.add_child(_button("+100 монет", func() -> void: GameState.coins += 100))
	_invulnerable = _button("Неуязвимость: нет", _toggle_invulnerable)
	grid.add_child(_invulnerable)
	grid.add_child(_button("Волк рядом", _spawn.bind(WOLF)))
	grid.add_child(_button("Разбойник рядом", _spawn.bind(BANDIT)))
	grid.add_child(_button("К торговцу", _to_merchant))
	grid.add_child(_button("Пропустить день", _skip_time))
	grid.add_child(_button("Мир: к месту", _to_next_place))
	grid.add_child(_button("Мир: все места", _discover_all))

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.custom_minimum_size = Vector2(410, 0)
	_info.add_theme_font_override(&"normal_font", UiStyle.font(500))
	_info.add_theme_font_override(&"bold_font", UiStyle.font(700))
	_info.add_theme_font_size_override(&"normal_font_size", 16)
	_info.add_theme_font_size_override(&"bold_font_size", 16)
	_info.add_theme_color_override(&"default_color", UiStyle.COLOR_TEXT)
	column.add_child(_info)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override(&"font", UiStyle.font(600))
	button.add_theme_font_size_override(&"font_size", 16)
	button.custom_minimum_size = Vector2(200, 0)
	button.pressed.connect(action)
	return button


func _refresh() -> void:
	if not _panel.visible:
		return
	var lines: PackedStringArray = []
	lines.append("Кадры %d/с · память движка %.0f МБ · отрисовки %d" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	var activity := get_tree().get_first_node_in_group(&"world_activity") as WorldActivity
	if activity:
		lines.append("Дальних персонажей на паузе: %d" % activity.sleeping_count())
	var phase := "ночь" if GameState.phase == GameState.Phase.NIGHT else "день"
	if GameState.world_mode:
		var horse := get_tree().get_first_node_in_group(&"horse")
		lines.append("[b]Мир: день %d, %s (%s)[/b], мест %d/%d%s" % [GameState.world_day, GameState.world_clock_text(), GameState.world_period(),
				GameState.discovered.size(), OpenWorld.PLACES.size(), "  ·  верхом" if horse and horse.call(&"is_ridden") else ""])
	else:
		lines.append("[b]День %d, %s[/b], действий осталось %d%s" % [GameState.day, phase, GameState.slots_left, "  ·  в лесу" if GameState.in_forest else ""])
	var combat := _combat()
	var health := "здоровье %d, выносливость %d" % [roundi(combat.health), roundi(combat.stamina)] if combat else "без боя"
	lines.append("Монеты %d  ·  %s" % [GameState.coins, health])

	lines.append("[b]Враги[/b]")
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	if enemies.is_empty():
		lines.append("  —")
	for node: Node in enemies:
		var enemy := node as Enemy
		var distance := ""
		if combat:
			distance = "  %.0f м" % enemy.global_position.distance_to(combat.get_parent().global_position)
		lines.append("  %s [%s] %s  %d/%d%s" % [enemy.lock_name, enemy.enemy_id, Enemy.State.keys()[enemy.state],
				roundi(enemy.health), roundi(enemy.data.max_health), distance])
	var guards := get_tree().get_nodes_in_group(&"guards")
	if not guards.is_empty():
		lines.append("[b]Дозорные[/b]")
		for node: Node in guards:
			var guard := node as Guard
			lines.append("  %s  тревога %d%%" % [Guard.State.keys()[guard.state], roundi(guard.alertness * 100.0)])

	lines.append("[b]Флаги[/b]")
	var flags: PackedStringArray = []
	for flag: String in GameState.flags:
		if GameState.flags[flag]:
			flags.append(flag)
	if GameState.talked_helga:
		flags.append("talked_helga")
	if GameState.gate_open:
		flags.append("gate_open")
	if GameState.tomash_refused:
		flags.append("tomash_refused")
	lines.append("  " + (", ".join(flags) if not flags.is_empty() else "—"))
	_info.text = "\n".join(lines)
	_invulnerable.text = "Неуязвимость: %s" % ("да" if combat and combat.invulnerable else "нет")


func _combat() -> PlayerCombat:
	return get_tree().get_first_node_in_group(PlayerCombat.GROUP) as PlayerCombat


func _toggle_invulnerable() -> void:
	var combat := _combat()
	if combat:
		combat.invulnerable = not combat.invulnerable
	_refresh()


## Drops an enemy 6 m in front of Mara.
func _spawn(path: String) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var model := player.get_node(^"Model") as Node3D
	var forward := -model.global_basis.z
	forward.y = 0.0
	var enemy := (load(path) as PackedScene).instantiate() as Enemy
	enemy.enemy_id = "debug_%d" % Time.get_ticks_msec()
	player.get_parent().add_child(enemy)
	enemy.global_position = player.global_position + forward.normalized() * 6.0 + Vector3.UP * 0.3
	enemy.face_point(player.global_position)


## Puts Mara in front of the next merchant on duty.
func _to_merchant() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var merchants := get_tree().get_nodes_in_group(&"merchants").filter(func(m: Node) -> bool: return (m as Node3D).is_visible_in_tree())
	if player == null or merchants.is_empty():
		GameState.notified.emit("Торговцев рядом нет")
		return
	_merchant_index = (_merchant_index + 1) % merchants.size()
	var merchant := merchants[_merchant_index] as Node3D
	var front := merchant.global_position + merchant.global_basis * Vector3(0, 0, -1.4)
	player.call(&"teleport", front, merchant.global_position - front)
	get_tree().call_group(&"camera_rig", &"snap_behind_target")


## Day: ends it (the night starts). Night: Mara sleeps (the next morning starts).
## In the open world: the clock jumps to the next morning.
func _skip_time() -> void:
	if GameState.world_mode:
		var hours := fposmod(GameState.WORLD.wake_hour - GameState.world_hour, 24.0)
		get_tree().call_group(&"world_clock", &"advance", hours if hours > 0.5 else 24.0)
		return
	if get_tree().get_first_node_in_group(&"day_director") == null:
		GameState.notified.emit("Здесь нет смены дней")
		return
	get_tree().call_group(&"day_director", &"debug_skip")


## Open world: Mara jumps to the next place in the list.
func _to_next_place() -> void:
	var world := get_tree().get_first_node_in_group(&"open_world") as OpenWorld
	if world == null:
		GameState.notified.emit("Это не открытый мир")
		return
	var ids := OpenWorld.PLACES.keys()
	_place_index = (_place_index + 1) % ids.size()
	var spot := world.place_position(ids[_place_index]) + Vector3(4.0, 0.5, 4.0)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var horse := get_tree().get_first_node_in_group(Horse.GROUP) as Horse
	if horse and horse.is_ridden():
		horse.dismount()
	player.call(&"teleport", spot)
	get_tree().call_group(&"camera_rig", &"snap_behind_target")
	GameState.notified.emit(OpenWorld.PLACES[ids[_place_index]]["name"])


func _discover_all() -> void:
	for id: String in OpenWorld.PLACES:
		GameState.discover(id, OpenWorld.PLACES[id]["name"])
