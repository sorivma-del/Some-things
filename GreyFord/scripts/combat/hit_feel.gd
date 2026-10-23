class_name HitFeel
extends RefCounted
## Hitstop (a brief near-freeze of game time when a blow lands) and camera shake.

const FROZEN_TIME_SCALE := 0.03

## Hitstops still running; time resumes when the last one ends.
static var _running: int = 0


static func hitstop(tree: SceneTree, milliseconds: float) -> void:
	_running += 1
	Engine.time_scale = FROZEN_TIME_SCALE
	# The timer ignores time scale, otherwise the freeze would stretch itself out.
	await tree.create_timer(milliseconds / 1000.0, true, false, true).timeout
	_running -= 1
	if _running <= 0:
		_running = 0
		Engine.time_scale = 1.0


static func shake(tree: SceneTree, strength: float, duration: float) -> void:
	tree.call_group(&"camera_rig", &"shake", strength, duration)
