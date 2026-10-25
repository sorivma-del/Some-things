extends JapaneseCourtyard
## Первое прибытие и дуэль. Все переходы принадлежат сцене, сохранение не записывается.

enum Phase { INTRO, DUEL, ENDING, VICTORY, DEFEAT, TALK, SIGNAL, SIGNAL_ENDING, COMPLETE }
const EPISODE: ShrineEpisodeConfig = preload("res://resources/japan/episode.tres")
const GUARD: PackedScene = preload("res://scenes/japan/shrine_guard.tscn")
var phase: Phase = Phase.INTRO
var shot: int = 0
var _elapsed: float = 0.0
var _owns_lock: bool = false
var _guard: RaidEnemy
var _cinema: Camera3D
var _look: Vector3
var _dolly: Tween
var _movie_ui: CanvasLayer
var _subtitle: Label
var _skip: Button
var _result: HBoxContainer
var _retry: Button
var _aftermath: ShrineAftermath
var _choices: VBoxContainer
var _polish: ShrinePolish
var _signal_ignited: bool = false


func _ready() -> void:
	super()
	_cinema = Camera3D.new()
	_cinema.name = "EpisodeCamera"
	_cinema.fov = 48
	_cinema.near = 0.08
	add_child(_cinema)
	_aftermath = ShrineAftermath.new()
	_aftermath.name = "Aftermath"
	add_child(_aftermath)
	_aftermath.conversation_requested.connect(_begin_conversation)
	_aftermath.beacon_requested.connect(_light_signal)
	_polish = ShrinePolish.new()
	add_child(_polish)
	_start_training.call_deferred()


func set_evening(value: bool) -> void:
	super(value)
	if value:
		_env.fog_density = 0.0085
		_env.fog_light_color = Color(0.2, 0.27, 0.3)
		_env.ambient_light_energy = 0.4
	if is_instance_valid(_polish):
		_polish.apply_lighting(value)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var title := Label.new()
	title.position = Vector2(30, 18)
	title.text = "ТРОПА К СВЯТИЛИЩУ"
	UiStyle.apply_label(title, 27, 600)
	layer.add_child(title)
	_status = Label.new()
	_status.position = Vector2(30, 53)
	UiStyle.apply_label(_status, 21, 500, true)
	layer.add_child(_status)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -620
	_hint.offset_right = 620
	_hint.offset_top = -35
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.apply_label(_hint, 18, 500, true)
	layer.add_child(_hint)
	_result = HBoxContainer.new()
	_result.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_result.offset_top = -108
	_result.offset_left = -270
	_result.offset_right = 270
	_result.add_theme_constant_override(&"separation", 28)
	layer.add_child(_result)
	_retry = UiStyle.button("Повторить эпизод", func() -> void:
		GameControls.consume_menu_action()
		_start_training(), 26)
	_result.add_child(_retry)
	_result.add_child(UiStyle.button("Главное меню", _menu, 26))
	_result.hide()
	_movie_ui = CanvasLayer.new()
	_movie_ui.layer = 5
	add_child(_movie_ui)
	for bottom: bool in [false, true]:
		var bar := ColorRect.new()
		bar.color = Color(0.015, 0.02, 0.025, 0.92)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		if bottom:
			bar.offset_top = -118
		else:
			bar.offset_bottom = 88
		_movie_ui.add_child(bar)
	_subtitle = Label.new()
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle.offset_left = 70
	_subtitle.offset_right = -70
	_subtitle.offset_top = -105
	_subtitle.offset_bottom = -48
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.apply_label(_subtitle, 28, 500)
	_movie_ui.add_child(_subtitle)
	_skip = UiStyle.button("Пропустить", _finish_intro, 20)
	_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.offset_left = -230
	_skip.offset_right = -30
	_skip.offset_top = -46
	_skip.offset_bottom = -12
	_skip.focus_mode = Control.FOCUS_NONE
	_movie_ui.add_child(_skip)
	_choices = VBoxContainer.new()
	_choices.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_choices.offset_left = 90
	_choices.offset_right = -90
	_choices.offset_top = -242
	_choices.offset_bottom = -128
	_choices.add_theme_constant_override(&"separation", 10)
	_movie_ui.add_child(_choices)
	_choices.hide()


func _start_training() -> void:
	# Один и тот же вход для повтора с экрана результата и из меню паузы.
	if is_instance_valid(_dolly):
		_dolly.kill()
	for enemy: RaidEnemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	if is_instance_valid(_aftermath):
		_aftermath.reset()
	if is_instance_valid(_polish):
		_polish.set_conversation(false)
	_signal_ignited = false
	_choices.hide()
	_hero.call(&"_set_target", null)
	_hero.call(&"_set_state", PlayerCombat.State.NORMAL)
	_hero.restore()
	_hero.call(&"set_peaceful", false)
	_hero.set(&"_knockback", Vector3.ZERO)
	_hero.set(&"_move_velocity", Vector3.ZERO)
	$Player.teleport(EPISODE.player_start, Vector3.FORWARD * -1)
	phase = Phase.INTRO
	training = true
	_result.hide()
	_hint.hide()
	_skip.show()
	_movie_ui.show()
	$HUD.hide()
	_lock()
	_guard = GUARD.instantiate() as RaidEnemy
	_guard.data = _guard.data.duplicate(true) as EnemyData
	_guard.data.max_health = EPISODE.opponent_health
	_guard.data.loot = null
	_guard.parley = null
	_guard.enemy_id = "shrine_episode_guard"
	_guard.position = EPISODE.opponent_start
	add_child(_guard)
	_guard.lock_name = "Страж святилища"
	_guard.set_physics_process(false)
	_guard.get_node(^"Model").rotation.y = 0
	_guard.died.connect(_on_enemy_died)
	enemies.append(_guard)
	$Player.walk_to(EPISODE.duel_start)
	_intro_shot(0)
	_on_control_scheme(GameControls.using_gamepad)


func _intro_shot(index: int) -> void:
	shot = index
	_elapsed = 0.0
	match shot:
		0:
			_status.text = "Поздний вечер · у старых тории"
			_subtitle.text = "Мара: Здесь должен был гореть сигнальный огонь…"
			_camera_shot(Vector3(7.5, 3.0, -10.5), Vector3(5.1, 2.6, -7.8), Vector3(0, 2.1, 4), EPISODE.arrival_seconds)
		1:
			$Player.teleport(EPISODE.duel_start, Vector3.BACK)
			_guard.get_node(^"Model").call(&"play", &"Sword_Idle")
			_subtitle.text = "Страж: Ни шагу дальше. Святилище теперь наше."
			_camera_shot(Vector3(-1.7, 1.85, -5.3), Vector3(-1.25, 1.75, -4.6), Vector3(0.3, 1.15, -0.7), EPISODE.challenge_seconds)
		2:
			_guard.get_node(^"Model").call(&"play", &"Sword_Idle")
			_subtitle.text = "Мара: Тогда начнём с тебя."
			_camera_shot(Vector3(1.8, 1.45, -3.6), Vector3(1.3, 1.4, -3.9), Vector3(0, 1.1, -5.8), EPISODE.answer_seconds)


func _camera_shot(from: Vector3, to: Vector3, look: Vector3, seconds: float) -> void:
	if is_instance_valid(_dolly):
		_dolly.kill()
	_cinema.position = from
	_look = look
	_cinema.look_at(_look)
	_cinema.make_current()
	_dolly = create_tween()
	_dolly.tween_property(_cinema, ^"position", to, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	if phase == Phase.TALK:
		_cinema.look_at(_look)
		return
	if phase not in [Phase.INTRO, Phase.ENDING, Phase.SIGNAL_ENDING]:
		return
	# Загрузка шейдеров не должна съедать реплики одним долгим кадром.
	_elapsed += minf(delta, 0.1)
	if is_instance_valid(_cinema):
		_cinema.look_at(_look)
	if phase == Phase.SIGNAL_ENDING:
		if not _signal_ignited and _elapsed >= EPISODE.ignition_delay:
			_signal_ignited = true
			_aftermath.ignite()
		if _elapsed >= EPISODE.beacon_ending_seconds:
			_show_result(true)
		return
	if phase == Phase.ENDING:
		if _elapsed >= EPISODE.ending_seconds:
			_show_result(true)
		return
	_skip.disabled = shot == 0 and _elapsed < EPISODE.skip_grace
	var duration: float = [EPISODE.arrival_seconds, EPISODE.challenge_seconds, EPISODE.answer_seconds][shot]
	if _elapsed >= duration:
		if shot < 2:
			_intro_shot(shot + 1)
		else:
			_finish_intro()


func _finish_intro() -> void:
	if phase != Phase.INTRO or (shot == 0 and _elapsed < EPISODE.skip_grace):
		return
	if is_instance_valid(_dolly):
		_dolly.kill()
	GameControls.consume_menu_action()
	$Player.teleport(EPISODE.duel_start, Vector3.BACK)
	_movie_ui.hide()
	_hint.show()
	$HUD.show()
	_unlock()
	phase = Phase.DUEL
	_status.text = "Победи стража · парируй клинком и отвечай ударом"
	_guard.set_physics_process(true)
	_guard.join_hunt(EPISODE.duel_start)
	_hero.call(&"_set_target", _guard)
	_restore_camera()


func _on_enemy_died(_enemy: Enemy) -> void:
	if phase != Phase.DUEL:
		return
	phase = Phase.ENDING
	training = false
	_elapsed = 0.0
	_lock()
	_hero.call(&"_set_target", null)
	_hint.hide()
	$HUD.hide()
	_movie_ui.show()
	_skip.hide()
	_status.text = "Святилище освобождено"
	_subtitle.text = "Мара: Теперь нужно узнать, что случилось с остальными."
	_camera_shot(Vector3(6, 3.2, -5), Vector3(5, 3.7, -3), Vector3(0, 2.5, 7), EPISODE.ending_seconds)


func _on_hero_died() -> void:
	if phase != Phase.DUEL:
		return
	_guard.set_physics_process(false)
	_show_result(false)


func _show_result(won: bool) -> void:
	var complete: bool = phase == Phase.SIGNAL_ENDING
	_hero.call(&"set_peaceful", won)
	phase = Phase.COMPLETE if complete else (Phase.VICTORY if won else Phase.DEFEAT)
	training = false
	if is_instance_valid(_dolly):
		_dolly.kill()
	_unlock()
	_restore_camera()
	_movie_ui.hide()
	$HUD.show()
	_hint.show()
	_result.visible = not won or complete
	if complete:
		_status.text = "Сигнал зажжён · Аки спасена · эпизод завершён"
	elif won:
		_aftermath.set_survivor_active(true)
		_status.text = "Из святилища кто-то вышел · поговори с выжившей у фонаря"
	else:
		_status.text = "Поражение · подними клинок перед ударом, затем контратакуй"
	if GameControls.using_gamepad and _result.visible:
		_retry.grab_focus()


func _restore_camera() -> void:
	$CameraRig.call(&"snap_to_target")
	($CameraRig/SpringArm3D/Camera3D as Camera3D).make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	var escape: bool = event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE
	if phase == Phase.TALK and (escape or event.is_action_pressed(&"ui_cancel")):
		_close_conversation(false)
		get_viewport().set_input_as_handled()
	elif phase == Phase.INTRO and (escape or event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
		_finish_intro()
		get_viewport().set_input_as_handled()
	elif escape and not GameState.controls_locked:
		GameControls.open_pause()
		get_viewport().set_input_as_handled()


func _on_control_scheme(gamepad: bool) -> void:
	if is_instance_valid(_skip):
		_skip.text = "✕ — пропустить" if gamepad else "E / Esc — пропустить"
	if is_instance_valid(_hint):
		_hint.text = "□ — удар · △ — тяжёлый · L1 — клинок / парирование · ○ — перекат · R3 — цель · Options — меню" if gamepad else "ЛКМ — удар · K — тяжёлый · Shift — клинок / парирование · пробел — перекат · Q — цель · Esc — меню"
	if phase == Phase.TALK and gamepad and get_viewport().gui_get_focus_owner() == null:
		_focus_choice()


func _begin_conversation() -> void:
	if phase != Phase.VICTORY:
		return
	phase = Phase.TALK
	_polish.set_conversation(true)
	_aftermath.set_conversation_open(true)
	_lock()
	GameControls.consume_menu_action()
	$Player.teleport(EPISODE.survivor_position + Vector3(1.2, 0, -0.65))
	$Player.face_point(EPISODE.survivor_position)
	var direction: Vector3 = $Player.position - EPISODE.survivor_position
	_aftermath.survivor_model.rotation.y = atan2(-direction.x, -direction.z)
	_aftermath.survivor_model.play(&"Idle_Talking")
	_status.text = "Аки · выжившая из деревни"
	_subtitle.text = "Аки: Я спряталась за святилищем. Людей увели к переправе. Зажги огонь — остальные увидят, что здесь безопасно."
	_hint.hide()
	$HUD.hide()
	_movie_ui.show()
	_skip.hide()
	_camera_shot(Vector3(-3.8, 1.65, 0.4), Vector3(-3.7, 1.65, 0.8), Vector3(-2.55, 1.12, 3.0), EPISODE.challenge_seconds)
	_set_choices(false)


func _set_choices(asked: bool) -> void:
	for node: Node in _choices.get_children():
		_choices.remove_child(node)
		node.queue_free()
	_choices.show()
	var accept := UiStyle.button("Зажжём огонь. Покажи жаровню.", _close_conversation.bind(true), 26)
	_choices.add_child(accept)
	if not asked:
		_choices.add_child(UiStyle.button("Кто напал на деревню?", func() -> void:
			_subtitle.text = "Аки: Люди в тёмных доспехах. Искали лодочника. Их старший ждёт у переправы."
			_set_choices(true), 26))
	if GameControls.using_gamepad:
		_focus_choice()


func _focus_choice() -> void:
	if is_instance_valid(_choices) and _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()


func _close_conversation(accept: bool) -> void:
	if phase != Phase.TALK:
		return
	GameControls.consume_menu_action()
	_choices.hide()
	_polish.set_conversation(false)
	_movie_ui.hide()
	$HUD.show()
	_hint.show()
	_aftermath.survivor_model.play(&"Idle")
	_aftermath.set_conversation_open(false)
	_unlock()
	_restore_camera()
	phase = Phase.SIGNAL if accept else Phase.VICTORY
	if accept:
		_aftermath.enable_beacon()
		_status.text = "Зажги сигнальную жаровню слева от святилища"
	else:
		_status.text = "Поговори с Аки, чтобы узнать о пропавших жителях"


func _light_signal() -> void:
	if phase != Phase.SIGNAL:
		return
	phase = Phase.SIGNAL_ENDING
	_aftermath.begin_lighting()
	_signal_ignited = false
	_elapsed = 0
	_lock()
	GameControls.consume_menu_action()
	$Player.teleport(EPISODE.beacon_position + Vector3(0.8, 0.01, -0.8))
	$Player.face_point(EPISODE.beacon_position)
	_hero.call(&"play_lighting")
	_hint.hide()
	$HUD.hide()
	_movie_ui.show()
	_skip.hide()
	_status.text = "Огонь надежды"
	_subtitle.text = "Аки: Они увидят дым. А я покажу тебе тропу к переправе."
	_camera_shot(Vector3(-10, 3.2, 1.4), Vector3(-9.3, 3.6, 2.4), EPISODE.beacon_position + Vector3(0.5, 1.5, 0), EPISODE.beacon_ending_seconds)


func pause_restart_label() -> String:
	return "Повторить эпизод"


func _lock() -> void:
	if not _owns_lock:
		GameState.lock_controls()
		_owns_lock = true


func _unlock() -> void:
	if _owns_lock:
		GameState.unlock_controls()
		_owns_lock = false


func _exit_tree() -> void:
	_unlock()
	super()
