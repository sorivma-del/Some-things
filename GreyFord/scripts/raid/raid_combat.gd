extends PlayerCombat
## В эпизоде поражение завершает бой; возвращение к костру заменено кнопкой повтора.

func _die() -> void:
	_set_state(State.DEAD)
	_model.play_once(&"Death01")
	died.emit()
