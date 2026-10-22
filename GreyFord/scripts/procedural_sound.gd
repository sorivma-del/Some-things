class_name ProceduralSound
extends RefCounted
## Placeholder sounds synthesised in code (no audio files): fire crackle and wind loops,
## footsteps, the gate's creak. Swap for recorded sounds later. Nothing is cached here:
## a static cache would outlive the audio server at exit; callers keep what they reuse.

const RATE := 22050
const START_DELAY := 0.25


## Starts an ambience loop shortly after the scene loads. Autoplay on the very first frame
## leaves the playback queued in the audio server if the game exits right away (as the
## headless check does), which Godot reports as a leak.
static func play_soon(player: Node) -> void:
	player.get_tree().create_timer(START_DELAY).timeout.connect(player.call.bind(&"play"))


## Low roar with random pops; seamless 4 s loop.
static func fire_crackle() -> AudioStreamWAV:
	var rng := _rng(11)
	var samples := PackedFloat32Array()
	samples.resize(RATE * 4)
	var low := 0.0
	var pop := 0.0
	for i: int in samples.size():
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.02
		if rng.randf() < 7.0 / RATE:
			pop = rng.randf_range(0.4, 1.0)
		pop *= 0.992
		samples[i] = low * 0.9 + rng.randf_range(-1.0, 1.0) * pop * 0.6
	return _loop(samples, RATE / 4)


## Soft wind with slow gusts; seamless 8 s loop.
static func wind() -> AudioStreamWAV:
	var rng := _rng(23)
	var samples := PackedFloat32Array()
	samples.resize(RATE * 8)
	var a := 0.0
	var b := 0.0
	for i: int in samples.size():
		a += (rng.randf_range(-1.0, 1.0) - a) * 0.01
		b += (a - b) * 0.05
		var t := float(i) / samples.size()
		var gust := 0.55 + 0.45 * sin(TAU * t) * sin(TAU * t * 3.0 + 1.0)
		samples[i] = b * 6.0 * gust
	return _loop(samples, RATE)


## A muffled step on mud; `variant` picks one of a few takes.
static func footstep(variant: int) -> AudioStreamWAV:
	var rng := _rng(100 + variant)
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * 0.16))
	var low := 0.0
	for i: int in samples.size():
		var t := float(i) / samples.size()
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.12
		samples[i] = low * pow(1.0 - t, 3.0) * 1.6
	return _to_wav(samples, false)


## Old hinges groaning as the gate swings open.
static func gate_creak() -> AudioStreamWAV:
	var rng := _rng(7)
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * 2.2))
	var phase := 0.0
	for i: int in samples.size():
		var t := float(i) / samples.size()
		var freq := 70.0 + 50.0 * t + 12.0 * sin(t * 40.0) + rng.randf_range(-6.0, 6.0)
		phase = fmod(phase + freq / RATE, 1.0)
		var saw := phase * 2.0 - 1.0
		var envelope := sin(PI * t) * (0.7 + 0.3 * sin(t * 23.0))
		samples[i] = (saw * 0.5 + rng.randf_range(-1.0, 1.0) * 0.15) * envelope
	return _to_wav(samples, false)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Crossfades the last `fade` samples into the start so the loop has no click.
static func _loop(samples: PackedFloat32Array, fade: int) -> AudioStreamWAV:
	var length := samples.size() - fade
	for i: int in fade:
		var w := float(i) / fade
		samples[i] = samples[i] * w + samples[length + i] * (1.0 - w)
	samples.resize(length)
	return _to_wav(samples, true)


static func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav
