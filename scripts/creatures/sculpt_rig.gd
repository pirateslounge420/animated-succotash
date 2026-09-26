class_name SculptRig
extends Node
## Drives a sculpted body's skeleton (SculptedBodies) from plain pivot
## nodes at its joints: whatever rotates a pivot (Creature's leg, arm and
## tail swings, a camp sitter's pose) bends the skinned mesh there.

var skeleton: Skeleton3D
var pivots: Array[Node3D] = []
var bones: Array[int] = []
## What each bone was last set to: a joint at rest isn't set again (each
## set re-skins the mesh).
var _last: Array[Quaternion] = []


func _process(_delta: float) -> void:
	if not skeleton.is_visible_in_tree():
		return
	if _last.size() != pivots.size():
		_last.resize(pivots.size())
		_last.fill(Quaternion(0, 0, 0, 0))
	for i in pivots.size():
		var q := pivots[i].quaternion
		if q != _last[i]:
			_last[i] = q
			skeleton.set_bone_pose_rotation(bones[i], q)
