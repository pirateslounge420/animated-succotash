class_name BranchGraphView
extends MeshInstance3D
## Dev view of the branch graphs (F6, dev mode only; spec Phase 1 (i)):
## every handhold of the registered graphs (BranchGraphs) near the player
## as a dot, green where the player can hold (wood at least
## PLAYER_RADIUS_M thick), yellow where only a monkey can, and the links
## between handholds as lines. Drawn over everything, so it shows through
## the leaves, and redrawn a few times a second. When off it doesn't exist.

## Wood the player can hold (radius, m); thinner is monkey-only.
const PLAYER_RADIUS_M := 0.06
## Graphs with a handhold within this of the player are drawn.
const VIEW_M := 30.0
const REDRAW_S := 0.25
const HOLD := Color(0.25, 1.0, 0.3)
const MONKEY := Color(1.0, 0.85, 0.15)
const LINK := Color(0.8, 0.9, 1.0)

static var _view: BranchGraphView

var _player: Node3D
var _mesh := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()
var _timer := 0.0


## Turn the view on (a new node under `parent`, following `player`) or
## off (the node goes).
static func toggle(parent: Node, player: Node3D) -> void:
	if is_instance_valid(_view):
		_view.queue_free()
		_view = null
		return
	_view = BranchGraphView.new()
	_view._player = player
	parent.add_child(_view)


func _ready() -> void:
	name = "BranchGraphView"
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.no_depth_test = true
	_mat.disable_fog = true
	_mat.render_priority = 10
	top_level = true
	global_transform = Transform3D.IDENTITY


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = REDRAW_S
		redraw()


## Rebuild the dots and lines from the graphs near the player now.
func redraw() -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if not is_instance_valid(_player) or cam == null:
		return
	var graphs := BranchGraphs.near(_player.global_position, VIEW_M)
	var points: Array[PackedVector3Array] = []
	var links := 0
	for g in graphs:
		var f := g.frame()
		var pts := PackedVector3Array()
		pts.resize(g.size())
		for i in g.size():
			pts[i] = f * g.local[i]
			links += g.links[i].size()
		points.append(pts)
	if links > 0:
		_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _mat)
		_mesh.surface_set_color(LINK)
		for k in graphs.size():
			var g := graphs[k]
			var pts := points[k]
			for i in pts.size():
				for j in g.links[i]:
					if j > i:
						_mesh.surface_add_vertex(pts[i])
						_mesh.surface_add_vertex(pts[j])
		_mesh.surface_end()
	# Dots: small diamonds facing the camera, about the same size on screen
	# near and far.
	var eye := cam.global_position
	var right := cam.global_basis.x
	var up := cam.global_basis.y
	var any := false
	for k in graphs.size():
		var g := graphs[k]
		var pts := points[k]
		for i in pts.size():
			if not any:
				_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
				any = true
			var p := pts[i]
			var s := clampf(eye.distance_to(p) * 0.007, 0.03, 0.6)
			var a := right * s
			var b := up * s
			_mesh.surface_set_color(HOLD if g.radius[i] >= PLAYER_RADIUS_M else MONKEY)
			_mesh.surface_add_vertex(p - a)
			_mesh.surface_add_vertex(p + b)
			_mesh.surface_add_vertex(p + a)
			_mesh.surface_add_vertex(p - a)
			_mesh.surface_add_vertex(p + a)
			_mesh.surface_add_vertex(p - b)
	if any:
		_mesh.surface_end()
