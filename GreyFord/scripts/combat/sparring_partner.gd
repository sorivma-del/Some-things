class_name SparringPartner
extends CombatBody
## A swordsman for the practice arena: walks up to Mara, raises his sword (it glows during
## the windup, so the blow can be read and blocked or rolled under), strikes, pauses.
## Blows stagger him; felled, he gets up again. Step 2 replaces him with real enemies.

enum State { IDLE, APPROACH, WINDUP, ACTIVE, RECOVERY, STAGGER, DEAD }

const BODY := preload("res://resources/models/characters/base/Superhero_Male_FullBody.gltf")
const OUTFIT := preload("res://resources/models/characters/outfits/Male_Ranger.gltf")
const HAIR := preload("res://resources/models/characters/hair/Hair_Buzzed.gltf")
const SWORD := preload("res://resources/models/props/Sword_Bronze.gltf")
const TELEGRAPH_COLOR := Color(1.0, 0.55, 0.15)
## Point in Sword_Attack (share of its length) where the blade comes down.
const STRIKE_MOMENT := 0.42

var state: State = State.IDLE

var _model := CharacterModel.new()
var _hitbox := Hitbox.new()
var _glow := StandardMaterial3D.new()
var _glow_light := OmniLight3D.new()
var _state_time: float = 0.0
var _cooldown: float = 0.0


func _ready() -> void:
	_model.base_scene = BODY
	_model.parts = [OUTFIT, HAIR]
	_model.head_only_parts = ["Superhero_Male"]
	_model.tint = Color(0.75, 0.72, 0.7)
	_model.default_animation = &"Sword_Idle"
	add_child(_model)
	super()
	set_flash_meshes(_model)

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.88
	add_child(shape)

	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.albedo_color = Color(TELEGRAPH_COLOR, 0.0)
	var sword := SWORD.instantiate() as Node3D
	_model.attach_to_bone(sword, &"hand_r", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.07, 0.02)))
	for node: Node in sword.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = _glow
	_glow_light.light_color = TELEGRAPH_COLOR
	_glow_light.light_energy = 0.0
	_glow_light.visible = false
	_glow_light.omni_range = 2.5
	_glow_light.position = Vector3(0, 0.6, 0)
	sword.add_child(_glow_light)

	_hitbox.body = self
	_hitbox.only_group = &"player"
	_hitbox.set_size(Vector3(1.3, 1.4, 1.5))
	_hitbox.position = Vector3(0, 1.0, -0.9)
	_model.add_child(_hitbox)


func _physics_process(delta: float) -> void:
	super(delta)
	_state_time += delta
	_cooldown -= delta
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var to := Vector3.ZERO
	if player:
		to = player.global_position - global_position
		to.y = 0.0
	var distance := to.length()
	var hero := get_tree().get_first_node_in_group(PlayerCombat.GROUP) as PlayerCombat
	var hero_down := hero != null and hero.state == PlayerCombat.State.DEAD

	var move := Vector3.ZERO
	match state:
		State.IDLE:
			_model.play(&"Sword_Idle")
			if player and not hero_down and distance < data.sight_radius:
				_set_state(State.APPROACH)
		State.APPROACH:
			_face(to, delta, 6.0)
			if hero_down or distance > data.sight_radius * 1.3:
				_set_state(State.IDLE)
			elif distance > data.attack_range:
				move = to.normalized() * data.move_speed
				_model.play(&"Walk")
			elif _cooldown <= 0.0:
				_start_windup()
			else:
				_model.play(&"Sword_Idle")
		State.WINDUP:
			# Tracks Mara during the first half of the windup only, so a late roll works.
			if _state_time < data.windup * 0.5:
				_face(to, delta, 8.0)
			var charge := clampf(_state_time / data.windup, 0.0, 1.0)
			_glow.albedo_color.a = 0.15 + 0.6 * charge
			_glow_light.light_energy = 2.5 * charge
			_glow_light.visible = true
			if _state_time >= data.windup:
				_set_state(State.ACTIVE)
				_hitbox.begin_swing(data.damage, data.knockback)
		State.ACTIVE:
			if _state_time >= data.active:
				_set_state(State.RECOVERY)
		State.RECOVERY:
			if _state_time >= data.recovery:
				_cooldown = data.attack_interval
				_set_state(State.APPROACH)
		State.STAGGER:
			if _state_time >= data.stagger_time:
				_set_state(State.APPROACH)

	velocity.x = move.x + _knockback.x
	velocity.z = move.z + _knockback.z
	move_and_slide()


func _start_windup() -> void:
	_set_state(State.WINDUP)
	var duration := data.windup / STRIKE_MOMENT
	_model.play_once(&"Sword_Attack", duration)


func _set_state(new_state: State) -> void:
	if state == State.ACTIVE or new_state == State.STAGGER or new_state == State.DEAD:
		_hitbox.end_swing()
	if new_state != State.WINDUP:
		_glow.albedo_color.a = 0.0
		_glow_light.light_energy = 0.0
		_glow_light.visible = false
	state = new_state
	_state_time = 0.0


func _struck(_info: HitInfo) -> void:
	if state == State.ACTIVE:
		return
	_set_state(State.STAGGER)
	_model.play_once(&"Hit_Chest", data.stagger_time)


func _fell() -> void:
	_set_state(State.DEAD)
	_model.play_once(&"Death01")


func _stood_up() -> void:
	_set_state(State.IDLE)
	_model.play(&"Sword_Idle")


func _face(direction: Vector3, delta: float, speed: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var yaw := atan2(-direction.x, -direction.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, yaw, clampf(speed * delta, 0.0, 1.0))
