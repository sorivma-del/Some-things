extends SceneTree
## Попадание, ранение и блок имеют разные записи и не перезапускаются пачкой за кадр.
const HIT := preload("res://scripts/combat/hit_info.gd")
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["OK  " if ok else "FAIL", label])
	if not ok:
		failures += 1


func _run() -> void:
	await process_frame
	root.get_node(^"GameState").call(&"new_game")
	var arena := (load("res://scenes/test/combat_arena.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await physics_frame
	var combat := arena.get_node(^"Player/Combat")
	var bank: Dictionary = combat.get(&"_sounds")
	_check("Все пять событий используют варианты звуковых файлов", bank.size() == 5)
	for cue: StringName in bank:
		var pool := bank[cue] as AudioStreamRandomizer
		var valid: bool = pool != null and pool.streams_count >= 2
		if valid:
			for i: int in pool.streams_count:
				var clip := pool.get_stream(i)
				valid = valid and clip is AudioStreamOggVorbis and clip.get_length() > 0 and clip.get_length() < 2.0
		_check("Записи корректны: %s" % cue, valid)
	var dummy := arena.get_node(^"DummyLeft")
	var hurtbox: Node = dummy.get(&"_hurtbox")
	var hit := HIT.new(10, 0, combat.get_parent(), Vector3.FORWARD)
	hit.result = HIT.Result.HIT
	combat.call(&"_on_landed", hurtbox, hit)
	var impact := combat.get(&"_impact_sfx") as AudioStreamPlayer3D
	_check("Попадание звучит в точке цели", impact.stream == bank[&"hit"] and impact.global_position.distance_to((hurtbox as Node3D).global_position) < 0.01)
	var hit_point := impact.global_position
	combat.get_parent().position.x += 0.1
	_check("Хвост звука не перемещается вслед за героиней", impact.global_position.distance_to(hit_point) < 0.01)
	combat.get_parent().position.x -= 0.1
	var started: int = combat.get(&"_last_impact_ms")
	for i: int in 8:
		combat.call(&"_play_sound", &"hit")
	_check("Несколько целей за один кадр не перезапускают удар", int(combat.get(&"_last_impact_ms")) == started)
	combat.set(&"blocking", false)
	combat.get(&"_hurtbox").receive(HIT.new(10, 0, dummy, Vector3.FORWARD))
	_check("Получение урона имеет отдельный звук и приоритет", impact.stream == bank[&"hurt"] and impact.global_position.distance_to(combat.get_parent().global_position + Vector3.UP * 1.2) < 0.01)
	combat.call(&"_play_sound", &"hit")
	_check("Попадание по врагу не заглушает ранение", impact.stream == bank[&"hurt"])
	combat.call(&"_play_sound", &"swing")
	var swing := combat.get(&"_sfx") as AudioStreamPlayer3D
	_check("Замах тише удара и не обрывает его", swing != impact and swing.volume_db < impact.volume_db and impact.stream == bank[&"hurt"])
	await create_timer(0.12, true, false, true).timeout
	combat.call(&"_play_sound", &"block")
	_check("Блок использует металлический звук", impact.stream == bank[&"block"])
	combat.call(&"_play_sound", &"parry")
	_check("Парирование отличается от обычного блока", impact.stream == bank[&"parry"])
	var ignored := HIT.new(0, 0, dummy, Vector3.ZERO)
	combat.call(&"_on_landed", hurtbox, ignored)
	_check("Игнорируемое попадание не создаёт звук", impact.stream == bank[&"parry"])
	await create_timer(0.3, true, false, true).timeout
	current_scene = null
	arena.free()
	await create_timer(0.25, true, false, true).timeout
	print("combat_audio test: %d failure(s)" % failures)
	quit.call_deferred(1 if failures else 0)
