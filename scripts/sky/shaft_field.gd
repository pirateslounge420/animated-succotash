class_name ShaftField
extends Node3D
## Shafts of sunlight, only when the air would really show them (design 3
## Oct §DC, data/look.json shafts). Every half second, round the player
## (within about 60 m), three real things must meet (gate()):
##  1. direct sun on the place: the sun above 2°, §CX's cover under
##     max_cloud, and no cloud shadow over you (Wind III's field);
##  2. something in the air (air_of()): the largest of the place's fog
##     likelihood, the damp (relative humidity past haze_rh_from), the low
##     mist where you stand, a lit hearth's smoke within smoke_m, and dust
##     in a ruin's hall;
##  3. a broken roof, which picks the kind: CANOPY under broken crowns (sky
##     visibility within gap_visibility at a spot the sun reaches through
##     the leaves, FoliageCover); RUIN, sunbeams into a dark hall where the
##     sun reaches the floor through a broken vault or a window, with dust
##     drifting in them; CREPUSCULAR, rays fanning from the sun across the
##     open sky when the cover is broken (broken_cloud).
## Drawn the era's way: long, flat, see-through quads along the sun's
## direction, turned about their own axis to face you, hard-edged, one flat
## colour (the sky's light, #DDF2FF, cool: R7), at most alpha_max x air x
## the low sun's scale x how much you face the sun, so a shaft is never
## brighter than the colour it is (lit air never blooms, R8) and is graded
## and dithered with everything. At most max_per_view. They waver as the
## gust field moves the crowns over them. Motes: single-pixel specks
## drifting slowly inside each shaft. Everything is freed when the gate
## fails, as NightAccents frees its props by day.

static var S: Dictionary = Tuning.section("look", "shafts")
const RANGE_M := 60.0
const REFRESH_S := 0.5

var main: Node
## The last gate (tools): {"ok", "why", "air", "kind", "sun_elev", ...}.
var gate_state := {}
## The shafts drawn now: [{"node", "kind", "foot" (this node's frame),
## "axis", "len", "width", "phase", "motes", "alpha"}].
var shafts: Array = []
## Tools: keys here replace gather()'s readings (rh, fog, mist, cover,
## cloud_here, smoke, dust).
var override := {}
var _t := 0.0
var _clock := 0.0
var _mat: StandardMaterial3D
var _mote_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func setup(p_main: Node) -> void:
	main = p_main
	_rng.seed = 11
	var col := color()
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = Color(col.r, col.g, col.b, 0.0)
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.disable_receive_shadows = true
	_mote_mat = _mat.duplicate()
	_mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED


static func color() -> Color:
	return Color.from_string(str(S.get("color", "#DDF2FF")), Color(0.87, 0.95, 1.0))


## The low sun's scale at `elev_deg` (low_sun: [elevation, scale] rows,
## linear between them; strongest and longest with the sun low).
static func low_sun(elev_deg: float) -> float:
	var rows: Array = S.get("low_sun", [[2.0, 1.0], [60.0, 0.2]])
	if rows.is_empty():
		return 1.0
	if elev_deg <= float(rows[0][0]):
		return float(rows[0][1])
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		if elev_deg <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (elev_deg - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.01))
	return float(rows[rows.size() - 1][1])


## Something in the air (0-1): the largest of the fog likelihood, the damp
## (rh past haze_rh_from), the mist above the day's own (in units of the
## fog's mist, look.json mist.fog_density), a hearth's smoke (1 at the
## fire, 0 at smoke_m) and dust (1 in a ruin's hall).
static func air_of(fog: float, rh: float, mist: float, smoke: float, dust: float) -> float:
	var M: Dictionary = Tuning.section("look", "mist")
	var mist_air := clampf((mist - float(M.get("day_density", 0.0006))) / maxf(float(M.get("fog_density", 0.006)), 1e-5), 0.0, 1.0)
	var damp := smoothstep(float(S.get("haze_rh_from", 0.8)), 1.0, rh)
	return clampf(maxf(maxf(fog, damp), maxf(mist_air, maxf(smoke, dust))), 0.0, 1.0)


## The readings at the player: the sun, the cover, the cloud shadow, the
## air's sources and whether you stand in a ruin's hall.
func gather() -> Dictionary:
	var sky: SkySystem = main.sky
	var player: Node3D = main.player
	var world: Node = main.world
	var d: Vector3 = player.surface_dir
	var pos := player.global_position
	var w: Dictionary = main.get("_local_weather") if main.get("_local_weather") is Dictionary else {}
	var r := {
		"sun_dir": sky.sun_dir,
		"sun_elev": sky.sun_elevation_deg,
		"cover": Wind.cover,
		"cloud_here": Wind.cloud_shade(pos),
		"fog": world.planet.sample(world.planet.fog, d) if world.planet != null else 0.0,
		"rh": float(w.get("rh", 0.5)),
		"mist": sky.mist_density,
		"smoke": _smoke_near(pos),
		"hall": _in_hall(pos),
		"sky_here": sky.sky_visibility,
		"under": Delves.underground > 0.5,
	}
	r["dust"] = 1.0 if bool(r.hall) else 0.0
	for k in override:
		r[k] = override[k]
	return r


## A lit hearth's smoke where you stand: 1 at the fire, 0 at smoke_m
## (§CV's column is built: every lit campfire smokes).
func _smoke_near(pos: Vector3) -> float:
	var r := float(S.get("smoke_m", 40.0))
	var best := 0.0
	for f in get_tree().get_nodes_in_group(Campfire.GROUP):
		var fire := f as Node3D
		if fire == null or not fire.is_inside_tree() or not bool(fire.get_meta("lit", true)):
			continue
		best = maxf(best, 1.0 - fire.global_position.distance_to(pos) / r)
	return clampf(best, 0.0, 1.0)


## Inside a ruin's hall: under a roof (SkySystem's enclosure) within a
## built ruin's footprint.
func _in_hall(pos: Vector3) -> bool:
	var sky: SkySystem = main.sky
	if sky._enclosed < 0.5 or main.landmarks == null:
		return false
	var d: Vector3 = main.world.dir_of(pos)
	for r in main.landmarks.ruins_near(d, 60.0):
		if CubeSphere.surface_distance_m(r.dir, d) <= float(r.get("footprint_m", 20.0)) + 2.0:
			return true
	return false


## The gate (§DC's three things): {"ok", "why", "air", "kinds": [...]}.
## `r` is gather()'s readings.
static func gate(r: Dictionary) -> Dictionary:
	var out := {"ok": false, "why": "", "air": 0.0, "kinds": []}
	if bool(r.get("under", false)):
		out.why = "underground"
		return out
	if float(r.sun_elev) <= 2.0:
		out.why = "no sun"
		return out
	if float(r.cover) >= float(S.get("max_cloud", 0.75)) or float(r.cloud_here) > 0.0:
		out.why = "cloud"
		return out
	var air := air_of(float(r.fog), float(r.rh), float(r.mist), float(r.smoke), float(r.dust))
	out.air = air
	if air <= 0.02:
		out.why = "clear air"
		return out
	var kinds: Array = []
	if bool(r.get("hall", false)):
		kinds.append("ruin")
	else:
		kinds.append("canopy")
		var bc: Array = S.get("broken_cloud", [0.3, 0.7])
		if float(r.cover) >= float(bc[0]) and float(r.cover) <= float(bc[1]) and float(r.get("sky_here", 1.0)) > 0.7:
			kinds.append("crepuscular")
	out.kinds = kinds
	out.ok = true
	return out


func _process(delta: float) -> void:
	if main == null or main.player == null:
		return
	_clock += delta
	_t -= delta
	if _t <= 0.0:
		_t = REFRESH_S
		refresh(gather())
	_draw(delta)


## Re-place the shafts from the readings `r` (or free them all).
func refresh(r: Dictionary) -> void:
	gate_state = gate(r)
	gate_state["sun_elev"] = float(r.sun_elev)
	if not bool(gate_state.ok):
		clear()
		return
	var want: Array = []
	for k in gate_state.kinds:
		match str(k):
			"canopy":
				want.append_array(_canopy_spots(r))
			"ruin":
				want.append_array(_ruin_spots(r))
			"crepuscular":
				want.append_array(_crepuscular_spots(r))
	want = want.slice(0, int(S.get("max_per_view", 6)))
	# Feet in this node's frame (it rides the floating origin under the
	# world root).
	for w in want:
		w.foot = to_local(w.foot)
	# Keep shafts whose foot is still wanted (no popping); make the rest.
	var keep: Array = []
	for s in shafts:
		var hit := -1
		for i in want.size():
			if (want[i].foot as Vector3).distance_to(s.foot) < 0.75 and str(want[i].kind) == str(s.kind):
				hit = i
				break
		if hit >= 0:
			s.axis = want[hit].axis
			s.len = want[hit].len
			keep.append(s)
			want.remove_at(hit)
		else:
			_free(s)
	shafts = keep
	for w in want:
		shafts.append(_make(w))
	gate_state["count"] = shafts.size()


func clear() -> void:
	for s in shafts:
		_free(s)
	shafts.clear()


func _free(s: Dictionary) -> void:
	if is_instance_valid(s.node):
		NodeRelease.free_later(s.node)


## Spots under broken crowns: points round you where the sky visibility
## is inside gap_visibility and the line toward the sun passes the leaves
## (a gap in the crown). The shaft rises from the ground toward the sun.
func _canopy_spots(r: Dictionary) -> Array:
	var out: Array = []
	var chunks: ChunkManager = main.chunks
	var player: Node3D = main.player
	var space := player.get_world_3d().direct_space_state
	var up: Vector3 = player.global_basis.y.normalized()
	var sun: Vector3 = r.sun_dir
	var gv: Array = S.get("gap_visibility", [0.15, 0.7])
	var lr: Array = S.get("length_m", [6.0, 30.0])
	var wr: Array = S.get("width_m", [0.4, 2.5])
	var ls := low_sun(float(r.sun_elev))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Vector3i(player.global_position.round() / 4.0), "shafts"])
	var e := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	var n := up.cross(e).normalized()
	for i in 48:
		if out.size() >= int(S.get("max_per_view", 6)):
			break
		var a := rng.randf() * TAU
		var dist := 4.0 + sqrt(rng.randf()) * 36.0
		var p: Vector3 = player.global_position + (e * cos(a) + n * sin(a)) * dist
		var dd: Vector3 = main.world.dir_of(p)
		var g: Vector3 = main.world.to_scene(dd, PlanetConst.RADIUS_M + chunks.ground_height(dd))
		var sv := chunks.sky_visibility_at(g)
		if sv < float(gv[0]) or sv > float(gv[1]):
			continue
		var top := g + sun * 40.0
		if FoliageCover.see_through(g + up * 0.5, top, FoliageCover.clusters_round(space, g)) < 0.5:
			continue
		# How far up the crowns are: the shaft runs from the ground to them.
		var length := lerpf(float(lr[0]), float(lr[1]), clampf(ls * (0.4 + 0.6 * rng.randf()), 0.0, 1.0))
		out.append({"kind": "canopy", "foot": g, "axis": sun, "len": length, "width": rng.randf_range(float(wr[0]), float(wr[1]))})
	return out


## Sunbeams in a ruin's hall: floor points round you the sun reaches (no
## wall or vault on the line toward it) under a roof nearby (a ray up
## meets stone within 15 m), so the light comes in through an opening.
func _ruin_spots(r: Dictionary) -> Array:
	var out: Array = []
	var player: Node3D = main.player
	var space := player.get_world_3d().direct_space_state
	var up: Vector3 = player.global_basis.y.normalized()
	var sun: Vector3 = r.sun_dir
	var lr: Array = S.get("length_m", [6.0, 30.0])
	var wr: Array = S.get("width_m", [0.4, 2.5])
	var e := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	var n := up.cross(e).normalized()
	var excl: Array = [(player as CollisionObject3D).get_rid()] if player is CollisionObject3D else []
	var base: Vector3 = player.global_position
	for gx in range(-8, 9):
		for gz in range(-8, 9):
			if out.size() >= int(S.get("max_per_view", 6)):
				return out
			var p: Vector3 = base + e * gx * 1.5 + n * gz * 1.5 + up * 1.0
			# The floor under it.
			var q := PhysicsRayQueryParameters3D.create(p, p - up * 4.0)
			q.exclude = excl
			var fl := space.intersect_ray(q)
			if fl.is_empty():
				continue
			var f: Vector3 = (fl.position as Vector3) + up * 0.05
			var qs := PhysicsRayQueryParameters3D.create(f + up * 0.2, f + up * 0.2 + sun * 40.0)
			qs.exclude = excl
			if not space.intersect_ray(qs).is_empty():
				continue
			var qu := PhysicsRayQueryParameters3D.create(f + up * 0.2, f + up * 15.0)
			qu.exclude = excl
			var roof := space.intersect_ray(qu)
			if roof.is_empty():
				continue
			# Not a neighbour of one taken (one beam per opening, roughly).
			var near := false
			for o in out:
				if (o.foot as Vector3).distance_to(f) < 2.5:
					near = true
			if near:
				continue
			var h := (roof.position as Vector3).distance_to(f)
			var length := clampf(h / maxf(sun.dot(up), 0.1), float(lr[0]), float(lr[1]))
			out.append({"kind": "ruin", "foot": f, "axis": sun, "len": length, "width": clampf(1.2, float(wr[0]), float(wr[1])), "motes": true})
	return out


## Crepuscular rays: long beams far out toward the sun, parallel to its
## light (perspective fans them from the sun), across the open sky.
func _crepuscular_spots(r: Dictionary) -> Array:
	var out: Array = []
	var player: Node3D = main.player
	var up: Vector3 = player.global_basis.y.normalized()
	var sun: Vector3 = r.sun_dir
	var flat := (sun - up * sun.dot(up)).normalized()
	var side := flat.cross(up).normalized()
	var lr: Array = S.get("length_m", [6.0, 30.0])
	var wr: Array = S.get("width_m", [0.4, 2.5])
	var scale := float(S.get("crepuscular_length_scale", 3.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(main.world.days * 24.0), "crepuscular"])
	for i in 3:
		var foot: Vector3 = player.global_position + flat * rng.randf_range(70.0, 110.0) + side * rng.randf_range(-45.0, 45.0)
		out.append({"kind": "crepuscular", "foot": foot, "axis": sun, "len": float(lr[1]) * scale, "width": float(wr[1]) * 2.0})
	return out


func _make(w: Dictionary) -> Dictionary:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(float(w.width), float(w.len))
	mi.mesh = qm
	mi.material_override = _mat.duplicate()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var s := {"node": mi, "kind": str(w.kind), "foot": w.foot, "axis": w.axis, "len": float(w.len), "width": float(w.width), "phase": _rng.randf() * TAU, "motes": null, "mote_pos": []}
	if bool(w.get("motes", false)) or str(w.kind) == "canopy":
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var dot := QuadMesh.new()
		dot.size = Vector2(0.025, 0.025)
		mm.mesh = dot
		var count := int((S.get("motes", {}) as Dictionary).get("count_per_shaft", 12))
		mm.instance_count = count
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mote_mat.duplicate()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(mmi)
		var pts: Array = []
		for i in count:
			pts.append(Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.3, 0.3)))
		s.motes = mmi
		s.mote_pos = pts
	return s


## Each frame: face the camera about the shaft's axis, set the alpha, waver
## with the gusts, drift the motes.
func _draw(delta: float) -> void:
	if shafts.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	var fwd := -cam.global_basis.z
	var air := float(gate_state.get("air", 0.0))
	var ls := low_sun(float(gate_state.get("sun_elev", 30.0)))
	var a_max := float(S.get("alpha_max", 0.22))
	var drift := float((S.get("motes", {}) as Dictionary).get("drift_mps", 0.05))
	for s in shafts:
		var mi: MeshInstance3D = s.node
		if not is_instance_valid(mi):
			continue
		var axis: Vector3 = (s.axis as Vector3).normalized()
		var mid: Vector3 = to_global(s.foot as Vector3) + axis * float(s.len) * 0.5
		# The crowns above move it: the gust field's factor sways it a
		# little sideways and breathes its strength.
		var g := Wind.gust_at(mid, Wind.clock).x
		var sway := sin(_clock * 0.7 + float(s.phase)) * 0.12 + (g - 1.0) * 0.3
		var to_eye := eye - mid
		var z := (to_eye - axis * to_eye.dot(axis))
		if z.length() < 0.01:
			continue
		z = z.normalized()
		var x := axis.cross(z).normalized()
		mi.global_transform = Transform3D(Basis(x, axis, z), mid + x * sway)
		var facing := facing_scale(fwd, axis)
		var waver := 0.85 + 0.15 * sin(_clock * 1.3 + float(s.phase)) * clampf(g, 0.5, 1.5)
		var alpha := clampf(a_max * air * ls * facing * waver, 0.0, a_max)
		if str(s.kind) == "crepuscular":
			alpha *= 0.6
		s["alpha"] = alpha
		var m := mi.material_override as StandardMaterial3D
		m.albedo_color.a = alpha
		if s.motes != null and is_instance_valid(s.motes):
			var mm: MultiMesh = (s.motes as MultiMeshInstance3D).multimesh
			var pts: Array = s.mote_pos
			for i in pts.size():
				var pp: Vector3 = pts[i]
				pp.y = fposmod(pp.y + 0.5 + drift * delta / maxf(float(s.len), 0.1) * (1.0 if i % 2 == 0 else -1.0), 1.0) - 0.5
				pp.x += sin(_clock * 0.4 + i) * drift * delta / maxf(float(s.width), 0.1)
				pp.x = clampf(pp.x, -0.5, 0.5)
				pts[i] = pp
				mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(pp.x * float(s.width), pp.y * float(s.len), pp.z * float(s.width))))
			((s.motes as MultiMeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = minf(alpha * 2.5, 0.5)


## How much the shaft shows by where you look (0.15-1): brightest looking
## toward the sun (the forward scatter real ones show), faint with it
## behind you.
static func facing_scale(view_fwd: Vector3, sun_dir: Vector3) -> float:
	var d := view_fwd.normalized().dot(sun_dir.normalized())
	return 0.15 + 0.85 * pow(clampf((d + 0.3) / 1.3, 0.0, 1.0), 2.0)
