class_name AimArc
extends MeshInstance3D
## Where the shot will go: while the bow is drawn or the spear raised,
## the arc is worked out every frame (tests read it) but only drawn when
## combat "arc" show_aim_arc is on. It's off: players learn the drop by
## eye. Drawn, it's a faint dotted arc in the R1a blue-white
## from the weapon along its real launch (Bow.launch(), Spear.launch():
## the same start, speed and gravity toward the planet's center as the
## arrow or spear will have), updating with aim and draw every frame, and
## ending where it would first hit something (the world, trees, creatures'
## and people's parts). Soft: small dots, fading along the arc; drawn
## unlit over nothing (depth-tested, so it goes behind a trunk).
##
## Also Trail: the streak an arrow or spear leaves behind it in flight
## (a ribbon turned to the camera, so it reads at any distance).

const COLOR := Color("#C8D8F0")
static var STEP_S := Tuning.num("combat", "arc", "step_s")
static var MAX_S := Tuning.num("combat", "arc", "max_s")
## A dot every so many steps, the first few skipped (too close to the eye).
static var DOT_EVERY := int(Tuning.num("combat", "arc", "dot_every"))
static var SKIP := int(Tuning.num("combat", "arc", "skip"))
static var SHOW := bool(Tuning.num("combat", "arc", "show_aim_arc"))

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
	visible = SHOW


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
		var nd: Vector3 = player.world.dir_of(nxt)
		# The ground beyond its collision, or water (where the arrow stops
		# too).
		var gh := maxf(player.chunks.ground_height(nd), player.chunks.water_level_at(nd))
		if player.world.radius_of(nxt) < PlanetConst.RADIUS_M + gh:
			dots.append(player.world.to_scene(nd, PlanetConst.RADIUS_M + gh))
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


## The streak a projectile leaves behind it in flight: its last LENGTH_S
## of positions as a ribbon WIDTH_M wide (wider far off, MIN_W per metre
## from the camera, so it stays a visible line) turned to the camera, bright at
## the head and fading and narrowing toward the tail; gone soon after it
## lands.
class Trail:
	extends MeshInstance3D
	static var LENGTH_S := Tuning.num("combat", "arc", "trail_s")
	static var WIDTH_M := Tuning.num("combat", "arc", "trail_width_m")
	static var ALPHA := Tuning.num("combat", "arc", "trail_alpha")
	static var MIN_W := Tuning.num("combat", "arc", "trail_min_width_per_m")
	static var _ribbon_mat: StandardMaterial3D
	var _pts: Array = [] # [position, age]
	var _im := ImmediateMesh.new()
	## This streak's length (seconds of flight) and color (a super shot's
	## is red, combat "overcharge" tracer_color / tracer_s).
	var length_s := LENGTH_S
	var color := AimArc.COLOR.lightened(0.4)

	static func ribbon_material() -> StandardMaterial3D:
		if _ribbon_mat == null:
			_ribbon_mat = StandardMaterial3D.new()
			_ribbon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_ribbon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_ribbon_mat.vertex_color_use_as_albedo = true
			_ribbon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		return _ribbon_mat

	func _ready() -> void:
		top_level = true
		mesh = _im
		material_override = ribbon_material()
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	## Add where the projectile is now (or pass `flying` false to let the
	## tail catch up and vanish).
	func track(pos: Vector3, delta: float, flying := true) -> void:
		for p in _pts:
			p[1] += delta
		if flying:
			_pts.append([pos, 0.0])
		_pts = _pts.filter(func(p): return p[1] <= length_s)
		global_transform = Transform3D.IDENTITY
		_im.clear_surfaces()
		if _pts.size() < 2:
			return
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		var eye: Vector3 = cam.global_position if cam != null else pos + Vector3.UP * 10.0
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var n := _pts.size()
		for i in n:
			var p0: Vector3 = _pts[maxi(i - 1, 0)][0]
			var p1: Vector3 = _pts[mini(i + 1, n - 1)][0]
			var here: Vector3 = _pts[i][0]
			var along := p1 - p0
			var side := along.cross(eye - here)
			side = side.normalized() if side.length() > 1e-6 else Vector3.ZERO
			var k := 1.0 - float(_pts[i][1]) / length_s
			# Never thinner on screen than MIN_W per metre away (a far shot
			# still shows as a line).
			var half := maxf(WIDTH_M, here.distance_to(eye) * MIN_W) * 0.5 * (0.3 + 0.7 * k)
			var col := Color(color, ALPHA * k)
			_im.surface_set_color(col)
			_im.surface_add_vertex(here - side * half)
			_im.surface_set_color(col)
			_im.surface_add_vertex(here + side * half)
		_im.surface_end()
