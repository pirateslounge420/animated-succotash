class_name SculptRig
extends Node
## Drives a sculpted body's skeleton (SculptedBodies) from plain pivot
## nodes at its joints: whatever rotates a pivot (Creature's leg, arm and
## tail swings, a camp sitter's pose) bends the skinned mesh there.

var skeleton: Skeleton3D
var pivots: Array[Node3D] = []
var bones: Array[int] = []


func _process(_delta: float) -> void:
	if not skeleton.is_visible_in_tree():
		return
	for i in pivots.size():
		skeleton.set_bone_pose_rotation(bones[i], pivots[i].quaternion)
