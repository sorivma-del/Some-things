class_name StealthSense
extends RefCounted
## Eyes shared by watchmen and enemies: a cone of vision plus a line-of-sight ray, and an
## alertness meter that fills while Mara is seen (slower in cover, faster up close) and
## drains while she is not. Hiding in a house (Player.hidden) makes her invisible.

const EYE_HEIGHT := 1.6
const TARGET_HEIGHT := 1.0
## Within this distance she is heard even outside the cone.
const HEARING_DISTANCE := 1.6

var view_distance: float = 13.0
## Half-angle of the vision cone.
var view_angle_degrees: float = 55.0
## Alertness gained per second when Mara is fully visible at close range.
var notice_rate: float = 1.1
var forget_rate: float = 0.35
var eye_height: float = EYE_HEIGHT

var alertness: float = 0.0
var last_seen: Vector3


func can_see(body: CharacterBody3D, forward: Vector3, player: Node3D) -> bool:
	if player == null or (player.get(&"hidden") as bool):
		return false
	var eye := body.global_position + Vector3.UP * eye_height
	var target := player.global_position + Vector3.UP * TARGET_HEIGHT
	var to := target - eye
	if to.length() > view_distance:
		return false
	forward.y = 0.0
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > HEARING_DISTANCE and rad_to_deg(forward.angle_to(flat)) > view_angle_degrees:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, 1)
	query.exclude = [body.get_rid(), (player as CollisionObject3D).get_rid()]
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## `keep` holds the meter (e.g. mid-chase) instead of letting it drain while unseen.
func update(sees: bool, body: Node3D, player: Node3D, delta: float, keep: bool) -> void:
	if sees:
		last_seen = player.global_position
		var distance := body.global_position.distance_to(player.global_position)
		var closeness := clampf(1.0 - distance / view_distance, 0.15, 1.0)
		var visibility := 1.0 - (player.get(&"concealment") as float)
		alertness = minf(alertness + notice_rate * closeness * visibility * delta * 1.6, 1.0)
	elif not keep:
		alertness = maxf(alertness - forget_rate * delta, 0.0)
