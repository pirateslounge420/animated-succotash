class_name ModelAnimator
extends Node
## Plays an imported model's animation clips (ModelLibrary) by game
## state: "idle", "walk", "sprint", "crouch", "crouch_walk", "air",
## "swim", "climb", "sit" (PlanetPlayer.anim_state, a creature's pace,
## a camp sitter). Crossfades between clips; walk and sprint play faster
## with speed.

const BLEND_S := 0.2

var player: AnimationPlayer
## State -> clip name, from the model's sidecar (the rest by name).
var clips := {}
var state := ""


## Switch to `new_state` (no-op if already there); `speed` scales the
## clip's rate.
func set_state(new_state: String, speed := 1.0) -> void:
	if player == null:
		return
	player.speed_scale = speed
	if new_state == state:
		return
	state = new_state
	var clip := clip_for(new_state)
	if clip != "":
		player.play(clip, BLEND_S)


## The clip for a state, "" if the model has none.
func clip_for(s: String) -> String:
	var list := player.get_animation_list()
	if list.is_empty():
		return ""
	if clips.has(s) and player.has_animation(clips[s]):
		return clips[s]
	# By name: "walk" matches "Walk", "walking", "Armature|Walk".
	for c in list:
		var low := String(c).to_lower()
		if low == s or low.ends_with("|" + s) or low.begins_with(s):
			return c
	match s:
		"sprint":
			return clip_for("run") if s != "run" else clip_for("walk")
		"run":
			return clip_for("walk")
		"crouch_walk":
			return clip_for("crouch")
	return clip_for("idle") if s != "idle" else String(list[0])
