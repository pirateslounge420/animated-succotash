class_name NodeRelease
## Frees streamed-out nodes (chunks, ruins, creatures, props) after
## detaching their meshes. Godot's headless (dummy) renderer logs
## "Parameter "m" is null" for every MeshInstance3D freed together with
## the last reference to its mesh (about 3,500 lines per test run); with
## the meshes detached first, nothing is logged. Harmless elsewhere: the
## node is on its way out anyway.


static func free_later(n: Node) -> void:
	_detach(n)
	n.queue_free()


## Detach every mesh under `n` (everything, when the game quits).
static func detach_all(n: Node) -> void:
	_detach(n)


static func _detach(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).mesh = null
	elif n is MultiMeshInstance3D:
		(n as MultiMeshInstance3D).multimesh = null
	for c in n.get_children():
		_detach(c)
