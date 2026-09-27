class_name AimArc
extends MeshInstance3D
## Where the shot will go (the designer's first play): while the bow is
## drawn or the spear raised, a faint dotted arc in the R1a blue-white
## from the weapon along its real launch (Bow.launch(), Spear.launch():
## the same start, speed and gravity toward the planet's center as the
## arrow or spear will have), updating with aim and draw every frame, and
## ending where it would first hit something (the world, trees, creatures'
## and people's parts). Soft: small dots, fading along the arc; drawn
## unlit over nothing (depth-tested, so it goes behind a trunk).
##
## Also Trail: the brief line an arrow or spear leaves behind it in flight.

const COLOR := Color("#C8D8F0")
const STEP_S := 1.0 / 30.0
const MAX_S := 3.0
## A dot every so many steps, the first few skipped (too close to the eye).
const DOT_EVERY := 2
const SKIP := 2

static var _mat: StandardMaterial3D

var player: PlanetPlayer
var _im := ImmediateMesh.new()


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.vertex_color_use_as_albedo = true
		_mat.use_point_size = true
		_mat.point_size = 4.0
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.no_depth_test = false
	return _mat


func _ready() -> void:
	top_level = true
	mesh = _im
	material_override = material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Per frame, from the player: the arc for the bow or spear in hand, or none.
func update_arc() -> void:
	_im.clear_surfaces()
	var launch := []
	var g := 0.0
	if player.bow.drawing:
		launch = player.bow.launch()
		g = Arrow.GRAVITY
	elif player.spear.raising:
		launch = player.spear.launch()
		g = ThrownSpear.GRAVITY
	if launch.is_empty():
		return
	global_transform = Transform3D.IDENTITY
	var pos: Vector3 = launch[0]
	var vel: Vector3 = launch[1]
	var space := player.get_world_3d().direct_space_state
	var dots := PackedVector3Array()
	var steps := int(MAX_S / STEP_S)
	for k in steps:
		var up: Vector3 = player.world.dir_of(pos)
		vel -= up * g * STEP_S
		var nxt := pos + vel * STEP_S
		var q := PhysicsRayQueryParameters3D.create(pos, nxt)
		q.exclude = [player.get_rid()]
		q.collision_mask |= Hitboxes.LAYER
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			dots.append(hit.position)
			break
		pos = nxt
		if k >= SKIP and k % DOT_EVERY == 0:
			dots.append(pos)
	if dots.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_POINTS)
	for i in dots.size():
		var fade := 1.0 - float(i) / dots.size()
		_im.surface_set_color(Color(COLOR, 0.15 + 0.4 * fade))
		_im.surface_add_vertex(dots[i])
	_im.surface_end()


## The brief line a projectile leaves behind it in flight: its last
## LENGTH_S of positions, fading toward the tail; gone soon after it lands.
class Trail:
	extends MeshInstance3D
	const LENGTH_S := 0.25
	var _pts: Array = [] # [position, age]
	var _im := ImmediateMesh.new()

	func _ready() -> void:
		top_level = true
		mesh = _im
		material_override = AimArc.material()
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	## Add where the projectile is now (or pass `flying` false to let the
	## tail catch up and vanish).
	func track(pos: Vector3, delta: float, flying := true) -> void:
		for p in _pts:
			p[1] += delta
		if flying:
			_pts.append([pos, 0.0])
		_pts = _pts.filter(func(p): return p[1] <= LENGTH_S)
		global_transform = Transform3D.IDENTITY
		_im.clear_surfaces()
		if _pts.size() < 2:
			return
		_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in _pts:
			_im.surface_set_color(Color(AimArc.COLOR, 0.5 * (1.0 - p[1] / LENGTH_S)))
			_im.surface_add_vertex(p[0])
		_im.surface_end()
