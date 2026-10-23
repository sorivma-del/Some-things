class_name CombatBody
extends CharacterBody3D
## Something Mara can lock onto and strike: health from EnemyData, a Hurtbox, a red flash
## and a floating number on every blow, knockback, falling and (for training targets)
## standing up again. Subclasses react in _struck() and _fell().

signal health_changed(value: float, max_value: float)
signal defeated

## Physics layer 2, shared with the watchmen: the camera's spring arm ignores it.
const BODY_LAYER := 1 << 1
const FLASH_COLOR := Color(1.0, 0.25, 0.15)

@export var data: EnemyData
## Shown on the HUD when Mara locks on (defaults to data.display_name).
@export var lock_name: String = ""
@export var hurtbox_radius: float = 0.4
@export var hurtbox_height: float = 1.6
## Resting colour of the overlay that flashes red on hits (alpha 0 = none). A faint
## tint marks e.g. the infected; telegraphs of weaponless beasts brighten it.
@export var overlay_base: Color = Color(1.0, 0.25, 0.15, 0.0)

var health: float
var dead: bool = false

var _knockback: Vector3
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _flash := StandardMaterial3D.new()
var _hurtbox := Hurtbox.new()


func _ready() -> void:
	add_to_group(PlayerCombat.TARGET_GROUP)
	collision_layer = BODY_LAYER
	collision_mask = 1 | BODY_LAYER
	health = data.max_health
	if lock_name.is_empty():
		lock_name = data.display_name

	var capsule := CapsuleShape3D.new()
	capsule.radius = hurtbox_radius
	capsule.height = hurtbox_height
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	_hurtbox.body = self
	_hurtbox.add_child(shape)
	_hurtbox.position = Vector3(0, hurtbox_height * 0.5 + 0.05, 0)
	add_child(_hurtbox)
	_hurtbox.hit.connect(_on_hit)

	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = overlay_base


func can_be_locked() -> bool:
	return not dead and is_inside_tree()


func health_ratio() -> float:
	return health / data.max_health


## The red overlay used for hit flashes goes on these meshes.
func set_flash_meshes(root: Node) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = _flash


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	_knockback = _knockback.move_toward(Vector3.ZERO, 10.0 * delta)


func _on_hit(info: HitInfo) -> void:
	if dead:
		info.result = HitInfo.Result.IGNORED
		return
	health = maxf(health - info.damage, 0.0)
	health_changed.emit(health, data.max_health)
	_knockback = info.direction * info.knockback * data.knockback_taken
	_flash_once()
	_damage_number(info.damage)
	if health <= 0.0:
		info.result = HitInfo.Result.KILLED
		dead = true
		_fell()
		defeated.emit()
		if data.revive_time > 0.0:
			get_tree().create_timer(data.revive_time).timeout.connect(_revive)
	else:
		info.result = HitInfo.Result.HIT
		_struck(info)


func _revive() -> void:
	health = data.max_health
	dead = false
	health_changed.emit(health, data.max_health)
	_stood_up()


## Called when a blow lands but does not fell it.
func _struck(_info: HitInfo) -> void:
	pass


func _fell() -> void:
	pass


func _stood_up() -> void:
	pass


func _flash_once() -> void:
	var tween := create_tween()
	tween.tween_property(_flash, ^"albedo_color", overlay_base, 0.18).from(Color(FLASH_COLOR, 0.65))


func _damage_number(amount: float) -> void:
	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 64
	label.outline_size = 12
	label.pixel_size = 0.004
	label.modulate = Color(1.0, 0.85, 0.6)
	label.position = Vector3(randf_range(-0.2, 0.2), hurtbox_height + 0.3, 0)
	add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, ^"position:y", label.position.y + 0.6, 0.7)
	tween.tween_property(label, ^"modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)
