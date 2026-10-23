class_name AnimatedModel
extends Node3D
## A rigged model with clips: play() loops, play_once() runs a clip once over a set time,
## attach_to_bone() holds props. CharacterModel (Quaternius humans) and AnimalModel build on it.

@export var default_animation: StringName = &"Idle"
@export var blend_time: float = 0.25

var _player: AnimationPlayer
var _skeleton: Skeleton3D


func play(animation: StringName, loop: bool = true) -> void:
	if not _player.has_animation(animation):
		push_warning("Missing animation: %s" % animation)
		return
	if _player.current_animation == animation:
		return
	_player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_player.play(animation, blend_time)


## Plays a clip once from the start, sped up or slowed so it lasts `duration` seconds
## (its natural length if 0). Restarts even if the clip is already playing.
func play_once(animation: StringName, duration: float = 0.0, blend: float = 0.08) -> void:
	if not _player.has_animation(animation):
		push_warning("Missing animation: %s" % animation)
		return
	var clip := _player.get_animation(animation)
	clip.loop_mode = Animation.LOOP_NONE
	var speed := clip.length / duration if duration > 0.0 else 1.0
	_player.play(animation, blend, speed)
	_player.seek(0.0, true)


## Holds `node` in a bone (e.g. a sword in "hand_r"), offset by `offset` in bone space.
func attach_to_bone(node: Node3D, bone: StringName, offset: Transform3D) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	_skeleton.add_child(attachment)
	node.transform = offset
	attachment.add_child(node)
