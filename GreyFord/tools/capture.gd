extends Node
## Dev tool: fixed-camera screenshots and FPS for before/after comparisons.
## Run: godot --path GreyFord res://tools/capture.tscn -- --tag=before
## Writes docs/shots/<tag>/NN_name.png and docs/shots/<tag>/fps.txt next to the project,
## then quits. Works with any renderer (--rendering-driver vulkan / opengl3).

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SETTLE_FRAMES := 45
const FPS_SECONDS := 4.0
## name, camera position, look-at point, night?, measure FPS?
const SHOTS: Array[Array] = [
	["gate", Vector3(-1.5, 2.4, 17.5), Vector3(0.0, 2.2, 22.0), false, false],
	["campfire", Vector3(3.2, 1.8, 4.0), Vector3(-0.5, 0.8, -0.5), false, true],
	["house_windows", Vector3(-4.5, 2.4, -0.5), Vector3(-12.0, 2.6, -6.0), false, false],
	["overview", Vector3(0.0, 16.0, 34.0), Vector3(0.0, 2.0, -6.0), false, true],
	["forest", Vector3(2.0, 3.5, -38.5), Vector3(0.0, 2.0, -50.0), false, true],
	["night", Vector3(5.0, 3.2, 9.0), Vector3(-2.0, 1.5, -10.0), true, false],
]

var _camera := Camera3D.new()


func _ready() -> void:
	var tag := "before"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
	var out_dir := ProjectSettings.globalize_path("res://").path_join("../docs/shots").path_join(tag).simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)

	GameState.new_game()
	GameState.play_intro = false
	var game := GAME_SCENE.instantiate()
	add_child(game)
	(game.get_node("HUD") as CanvasLayer).visible = false
	_camera.fov = 60.0
	_camera.far = 200.0
	add_child(_camera)
	await get_tree().process_frame
	Transition.fade_in(0.01)

	var report: PackedStringArray = ["# FPS, %s, %s" % [tag, RenderingServer.get_video_adapter_name()],
			"renderer: %s" % ProjectSettings.get_setting("rendering/renderer/rendering_method")]
	for i: int in SHOTS.size():
		var shot := SHOTS[i]
		if shot[3] and GameState.phase != GameState.Phase.NIGHT:
			GameState.slots_used = GameState.config.slots_per_day
			GameState.begin_night()
		_camera.look_at_from_position(shot[1], shot[2])
		_camera.make_current()
		for f: int in SETTLE_FRAMES:
			await get_tree().process_frame
		var path := out_dir.path_join("%02d_%s.png" % [i + 1, shot[0]])
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
		if shot[4]:
			report.append(await _measure(shot[0]))
	var file := FileAccess.open(out_dir.path_join("fps.txt"), FileAccess.WRITE)
	file.store_string("\n".join(report) + "\n")
	print("\n".join(report))
	get_tree().quit()


func _measure(label: String) -> String:
	var frames := 0
	var worst := 0.0
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < int(FPS_SECONDS * 1_000_000):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
	var seconds := (Time.get_ticks_usec() - start) / 1_000_000.0
	return "%s: %.1f FPS avg, %.1f ms avg, %.1f ms worst" % [label, frames / seconds, seconds * 1000.0 / frames, worst]
