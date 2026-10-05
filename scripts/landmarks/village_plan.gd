class_name VillagePlan
extends RefCounted
## A village's plan (design 5 Oct §EF, §EG; data/villages.json plan), as
## pure data in the village's own flat frame: x across, z toward the
## water (the front), metres from the site. Grown, not placed (§EF.1):
##   1. the reason: the core square at the flattest ground near the site,
##      its hearth and well;
##   2. desire lines: the paths people would walk from it to the spring
##      up the slope behind, the landing at the water, the fields either
##      side (and the ford upstream), found on the ground (A*, slope costs)
##      in that order, each later one reusing the earlier where it can, so
##      they merge into trunks; smoothed and bent gently (§EF.5);
##   3. the other squares where paths branch or a street has run long
##      (compress, then release: §EF.3), one of them, or a still pool or
##      an unplanted bank, kept empty: the ma (§EG.3);
##   4. the landmark tower on a square's uphill rim (§EF.10);
##   5. houses wrapping each square (§EF.4), then packed along the paths,
##      fronts to the path, sharing walls in terraces of five and three
##      near the core, threes and ones further out, singles at the edge
##      (tight core, loose edge; §EF.1, §EG.2 odd numbers);
##   6. three districts by what they face (the high quarter, the hearth
##      quarter, the water quarter), thresholds where a lane crosses
##      between them (§EF.9), and the edges: the stream in front, a
##      dry-stone wall round the rest (§EG.1);
##   7. the gutter down the main street from the spring to the landing
##      (§EF.8);
##   8. the vista pass (§EF.2): every long view down a lane must end on a
##      building, a focal or borrowed scenery (the tower, a hill beyond);
##      where it doesn't, a focal goes in, off the axis on a third (§EG.2):
##      a cold hearth, an old tree or a shrine;
##   9. hearths: one in every house, one in every square but the void, and
##      the vista hearths: the composition leads to the next fire (§EF).
## rules() measures each rule and returns a pass/fail line for it
## (tools/village_check.gd).

static var PL: Dictionary = Tuning.section("villages", "plan")
static var BLD: Dictionary = Tuning.section("villages", "build")

const OCC_M := 0.5
const FREE := 0
const PATH := 1
const SQUARE := 2
const HOUSE := 3
const TOWER := 4
const WATER := 5
const FOCAL := 6
const VOID := 7
const BANK := 8

var map: PlanetData
var site: Dictionary
var rng := RandomNumberGenerator.new()
var up: Vector3
var ex: Vector3
var ez: Vector3
var base_e := 0.0
var E := 90.0 # half extent of the plan (m)
var NA := 0 # A* / height grid cells per edge (cell_m)
var cell := 2.0
var H := PackedFloat32Array() # ground at the A* grid's nodes, relative to base_e
var wet := PackedByteArray() # per A* cell: 0 dry, 1 bank (no building), 2 water
var NO := 0 # occupancy cells per edge (OCC_M)
var occ := PackedByteArray()
var top := PackedFloat32Array() # per occupancy cell: the top of what stands there (m, relative)
var owner := PackedInt32Array() # per occupancy cell: the house / focal index there

var core := Vector2.ZERO
var spring := Vector2.ZERO
var landing := Vector2.ZERO
var river_local := Vector2.ZERO
var river_half := 4.0
## [{pts: PackedVector2Array, half, kind ("main", "lane", "edge"), to}]
var paths: Array = []
## [{c, r, kind ("core", "square", "void"), hearth (Vector2 or null), well}]
var squares: Array = []
## [{c, u, v, w, d, group, district, focal, ring, door, hearth, square (-1 or its square), path}]
var houses: Array = []
var groups: Array = [] # [[house index...]]
var tower := {}
## [{p, kind ("hearth", "tree", "shrine"), vista}]
var focals: Array = []
## [{from, dir, len, end ("house", "tower", "focal", "hill", "placed", "none"), hit}]
var vistas: Array = []
var districts: Array = []
var thresholds: Array = []
var wall: Array = [] # [[a, b]...]
var gutter := PackedVector2Array()
var void_area := {} # {kind, c, r}
## [{p, kind ("house", "square", "vista"), of}]
var hearths: Array = []
## Square refuge (§EG.4): [{p, facing, square, house}]; brambles cover
## them while the square's hearth is cold: [{a, b, square}].
var refuge: Array = []
var brambles: Array = []
var edges: Array = [] # lingering edges (§EF.6): [{p, facing}]
## Dry-stone walls on a square's rim where no house front will do to sit
## against: [{a, b, square}].
var rim_walls: Array = []
## Garden walls closing a square's rim where no house fits: [{a, b, square}].
var garden_walls: Array = []
var materials := {}
var builds: Array = []
var trees: Array = [] # feature trees (vista focals): Vector2 each
var clearings: Array = [] # unused (VegetationPlacer asks clear_at)
var landmark_seen := 0.0
var notes: Array = []
var axis := Vector2(0, 1) # spring to landing
var cut := Vector2(-15.0, 15.0) # the districts' cuts along it


static func make(p_map: PlanetData, p_site: Dictionary) -> VillagePlan:
	var p := VillagePlan.new()
	p.map = p_map
	p.site = p_site
	p.rng.seed = int(p_site.seed)
	p._grow()
	return p


# --- Frame ---------------------------------------------------------------------

func dir_at(q: Vector2) -> Vector3:
	return (up + (ex * q.x + ez * q.y) / PlanetConst.RADIUS_M).normalized()


func local_of(d: Vector3) -> Vector2:
	var t := d / maxf(d.dot(up), 1e-6) - up
	return Vector2(t.dot(ex), t.dot(ez)) * PlanetConst.RADIUS_M


## Ground at local `q`, relative to the site (bilinear on the plan's grid).
func ground(q: Vector2) -> float:
	var fx := clampf((q.x + E) / cell, 0.0, NA - 0.001)
	var fz := clampf((q.y + E) / cell, 0.0, NA - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var n := NA + 1
	return lerpf(lerpf(H[j * n + i], H[j * n + i + 1], tx), lerpf(H[(j + 1) * n + i], H[(j + 1) * n + i + 1], tx), tz)


## The true ground at local `q` (the planet's, as the chunks draw it).
func true_ground(q: Vector2) -> float:
	return map.terrain.elevation(dir_at(q), true) - base_e


func _acell(q: Vector2) -> Vector2i:
	return Vector2i(clampi(int((q.x + E) / cell), 0, NA - 1), clampi(int((q.y + E) / cell), 0, NA - 1))


func _apos(c: Vector2i) -> Vector2:
	return Vector2(-E + (c.x + 0.5) * cell, -E + (c.y + 0.5) * cell)


func wet_at(q: Vector2) -> int:
	var c := _acell(q)
	return wet[c.y * NA + c.x]


func _oi(q: Vector2) -> int:
	var i := int((q.x + E) / OCC_M)
	var j := int((q.y + E) / OCC_M)
	if i < 0 or j < 0 or i >= NO or j >= NO:
		return -1
	return j * NO + i


func occ_at(q: Vector2) -> int:
	var k := _oi(q)
	return occ[k] if k >= 0 else WATER


# --- Growth --------------------------------------------------------------------

func _grow() -> void:
	up = (site.dir as Vector3).normalized()
	ez = (site.front as Vector3)
	ez = (ez - up * ez.dot(up)).normalized()
	ex = up.cross(ez).normalized()
	base_e = map.terrain.elevation(up, true)
	builds = (site.get("builds", []) as Array).duplicate()
	cell = float(PL.get("cell_m", 2.0))
	E = float(PL.get("radius_m", 78.0)) + 14.0
	NA = int(ceil(2.0 * E / cell))
	E = NA * cell * 0.5
	NO = int(round(2.0 * E / OCC_M))
	_sample_ground()
	_choose_materials()
	_reason()
	_desire_lines()
	_squares()
	_choose_void()
	_raster_ground()
	_place_tower()
	_wrap_squares()
	_rows()
	_districts()
	_edges_and_wall()
	_gutter()
	_size_tower()
	for si in squares.size():
		_close_rim(si)
	_vistas()
	_hierarchy_pass()
	_frame_pass()
	_regrow_tower()
	_hearths_and_refuge()
	_lingering_edges()


func _sample_ground() -> void:
	var n := NA + 1
	H.resize(n * n)
	for j in n:
		for i in n:
			var q := Vector2(-E + i * cell, -E + j * cell)
			H[j * n + i] = map.terrain.elevation(dir_at(q), true) - base_e
	# The stream: water and its bank (no building within bank_keep_m of
	# the line: the chunks carve the bank there).
	var rv: Dictionary = site.get("river", {})
	river_half = float(rv.get("width", 8.0)) * 0.5
	river_local = local_of(rv.get("dir", up))
	var rivers := Encampment.rivers_for(map)
	var segs := rivers.segments_near(map, map.cell_at(up))
	var keep := float(PL.get("bank_keep_m", 14.0))
	wet.resize(NA * NA)
	for j in NA:
		for i in NA:
			var q := _apos(Vector2i(i, j))
			var dq := dir_at(q)
			var w := 0
			for s in segs:
				var dt := rivers.closest_dt(s, dq)
				var half := float(rivers.width[s]) * 0.5
				if dt.x < half + 1.0:
					w = 2
					break
				if dt.x < half + keep:
					w = 1
			if w == 0 and map.water[map.cell_at(dq)] != PlanetData.Water.NONE and map.water[map.cell_at(dq)] != PlanetData.Water.RIVER:
				w = 2
			wet[j * NA + i] = w


## One stone, one timber, one roof per village (§EG.3), from the land:
## the stone from the rock under it, the timber from its trees, the roof
## from rock and weather.
func _choose_materials() -> void:
	var cl := map.cell_at(up)
	var rock_name: String = PlanetData.SOIL_NAMES[map.rock[cl]]
	var bkey: String = BiomeTemplates.KEYS[map.biome[cl]]
	var timber := "default"
	if bkey in ["TAIGA", "KRUMMHOLZ", "ALPINE_MEADOW"]:
		timber = "larch" if map.temp_c[cl] < 4.0 else "pine"
	elif bkey in ["TEMPERATE_DECIDUOUS", "FLOODPLAIN_FOREST", "WET_MEADOW", "TALLGRASS_PRAIRIE"]:
		timber = "oak"
	elif bkey in ["MEDITERRANEAN_SCRUB", "MARITIME_FOREST"]:
		timber = "chestnut"
	elif bkey in ["TEMPERATE_RAINFOREST", "CLOUD_FOREST"]:
		timber = "beech"
	var t := float(map.temp_c[cl])
	var m := float(map.moisture[cl])
	var roof := "thatch"
	if rock_name in ["granite", "basalt", "till"] and (t < 9.0 or m > 0.6):
		roof = "slate"
	elif rock_name in ["sandstone", "karst"]:
		roof = "stone_flags"
	elif t > 13.0 and m < 0.55:
		roof = "clay_tile"
	materials = {"stone": rock_name, "timber": timber, "roof": roof}


## The reason the village is here (§EF.1): its hearth and well, on the
## flattest dry ground within 16 m of the site.
func _reason() -> void:
	var best := Vector2.ZERO
	var best_s := INF
	for k in 40:
		var q := Vector2.ZERO if k == 0 else Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 16.0)
		if wet_at(q) != 0:
			continue
		var s := 0.0
		for a in 6:
			s += absf(ground(q + Vector2.from_angle(a * TAU / 6.0) * 7.0) - ground(q))
		# Its rim, 11 m out: dry and in reach, to be wrapped (§EF.4).
		for a in 12:
			var rq := q + Vector2.from_angle(a * TAU / 12.0) * 11.0
			if wet_at(rq) != 0:
				s += 1.5
		if s < best_s:
			best_s = s
			best = q
	core = best


func _desire_lines() -> void:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, NA, NA)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	var n := NA + 1
	for j in NA:
		for i in NA:
			var gx := (H[j * n + i + 1] - H[j * n + i] + H[(j + 1) * n + i + 1] - H[(j + 1) * n + i]) / (2.0 * cell)
			var gz := (H[(j + 1) * n + i] - H[j * n + i] + H[(j + 1) * n + i + 1] - H[j * n + i + 1]) / (2.0 * cell)
			var sl := sqrt(gx * gx + gz * gz)
			var c := Vector2i(i, j)
			if wet[j * NA + i] == 2 or sl > 0.45:
				astar.set_point_solid(c, true)
			else:
				astar.set_point_weight_scale(c, 1.0 + 30.0 * sl * sl + (0.6 if wet[j * NA + i] == 1 else 0.0))
	var R := float(PL.get("radius_m", 78.0))
	# The spring: the highest ground behind, 55-72 m back.
	var best_h := -INF
	for k in 30:
		var a := deg_to_rad(-90.0 + rng.randf_range(-50.0, 50.0))
		var q := core + Vector2.from_angle(a) * rng.randf_range(R * 0.68, R * 0.9)
		if wet_at(q) != 0 or absf(q.x) > E - 4.0 or absf(q.y) > E - 4.0:
			continue
		if ground(q) > best_h:
			best_h = ground(q)
			spring = q
	if best_h == -INF:
		spring = core + Vector2(0, -R * 0.75)
	# The landing: the water's edge nearest the core.
	var to_core := (core - river_local)
	landing = river_local + to_core.normalized() * (river_half + 3.0) if to_core.length() > 0.1 else core + Vector2(0, 40)
	var targets: Array = [[spring, "main", "spring"], [landing, "main", "landing"]]
	# The fields either side, on the gentler ground (behind either side
	# where the side is the stream's).
	for sg: float in [-1.0, 1.0, -0.5, 0.5]:
		if absf(sg) < 1.0 and targets.size() >= 4:
			break
		var bq := Vector2.ZERO
		var bs := INF
		for k in 24:
			var base_a := (0.0 if sg > 0.0 else PI) if absf(sg) == 1.0 else (-PI * 0.25 if sg > 0.0 else -PI * 0.75)
			var a := base_a + deg_to_rad(rng.randf_range(-40.0, 40.0))
			var q := core + Vector2.from_angle(a) * rng.randf_range(R * 0.55, R * 0.88)
			if wet_at(q) != 0 or absf(q.x) > E - 4.0 or absf(q.y) > E - 4.0:
				continue
			var s := absf(ground(q) - ground(core)) / q.distance_to(core)
			if s < bs:
				bs = s
				bq = q
		if bs < INF:
			targets.append([bq, "lane", "fields"])
	# The ford upstream, on this bank (when the stream is near).
	if river_local.distance_to(core) < R:
		var rv := Encampment.rivers_for(map)
		var seg := int((site.get("river", {}) as Dictionary).get("seg", -1))
		if seg >= 0:
			var ua := local_of(rv.a[seg])
			var along := (ua - river_local).normalized()
			var q := river_local + along * R * 0.6
			q += (core - q).normalized() * (river_half + 2.0)
			if absf(q.x) < E - 4.0 and absf(q.y) < E - 4.0:
				targets.append([q, "edge", "ford"])
	var on_path := {}
	for t in targets:
		var to: Vector2 = t[0]
		var a := _acell(core)
		var b := _open_cell(astar, _acell(to))
		if astar.is_point_solid(a) or b.x < 0:
			continue
		var ids := astar.get_id_path(a, b)
		if ids.size() < 4:
			continue
		# Where it leaves the paths already there: it begins there.
		var start := 0
		for k in ids.size():
			if on_path.has(ids[k]):
				start = k
		var pts := PackedVector2Array()
		var junction := -1
		if start > 0:
			junction = 1
			pts.append(_nearest_on_paths(_apos(ids[start])))
		else:
			pts.append(core)
		for k in range(start + 1, ids.size()):
			pts.append(_apos(ids[k]))
		pts[pts.size() - 1] = to
		if pts.size() < 3:
			continue
		pts = _chaikin(_chaikin(pts))
		pts = _meander(pts)
		pts = _resample(pts, 1.0)
		var half := float(PL.get("main_half_m", 1.9)) if t[1] == "main" else (float(PL.get("lane_half_m", 1.4)) if t[1] == "lane" else float(PL.get("edge_half_m", 1.2)))
		paths.append({"pts": pts, "half": half, "kind": t[1], "to": t[2], "junction": junction})
		for c in ids:
			on_path[c] = true
			var w := astar.get_point_weight_scale(c)
			astar.set_point_weight_scale(c, maxf(0.3, w * 0.35))


## The nearest cell to `c` A* may walk (spiralling out 6 cells), or (-1, -1).
func _open_cell(astar: AStarGrid2D, c: Vector2i) -> Vector2i:
	for r in 7:
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if maxi(absi(di), absi(dj)) != r:
					continue
				var q := c + Vector2i(di, dj)
				if q.x >= 0 and q.y >= 0 and q.x < NA and q.y < NA and not astar.is_point_solid(q):
					return q
	return Vector2i(-1, -1)


func _nearest_on_paths(q: Vector2) -> Vector2:
	var best := q
	var bd := INF
	for p in paths:
		for v in (p.pts as PackedVector2Array):
			var dd := v.distance_squared_to(q)
			if dd < bd:
				bd = dd
				best = v
	return best


static func _chaikin(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		out.append(pts[i].lerp(pts[i + 1], 0.25))
		out.append(pts[i].lerp(pts[i + 1], 0.75))
	out.append(pts[pts.size() - 1])
	return out


static func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	var carry := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var l := a.distance_to(b)
		var s := step - carry
		while s <= l:
			out.append(a.lerp(b, s / l))
			s += step
		carry = l - (s - step)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > 0.2:
		out.append(pts[pts.size() - 1])
	return out


## The streets bend slightly (§EF.5): a slow sway across the line, still
## at both ends.
func _meander(pts: PackedVector2Array) -> PackedVector2Array:
	var am: Array = PL.get("meander_m", [0.9, 1.6])
	var wv: Array = PL.get("meander_wave_m", [34.0, 56.0])
	var amp := rng.randf_range(float(am[0]), float(am[1]))
	var lam := rng.randf_range(float(wv[0]), float(wv[1]))
	var ph := rng.randf() * TAU
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var out := PackedVector2Array()
	var s := 0.0
	for i in pts.size():
		if i > 0:
			s += pts[i - 1].distance_to(pts[i])
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-t.y, t.x)
		var off := amp * sin(TAU * s / lam + ph) * sin(PI * s / maxf(total, 1.0))
		var q := pts[i] + nrm * off
		out.append(q if wet_at(q) == wet_at(pts[i]) else pts[i])
	return out


## The squares: the core, then where paths branch or a street has run long
## (a release after the lane's compression, §EF.3), spread apart.
func _squares() -> void:
	squares.append({"c": core, "r": float(PL.get("core_square_r_m", 7.5)), "kind": "core"})
	var rr: Array = PL.get("squares_r_m", [5.5, 6.5])
	var want := int(PL.get("squares", 3))
	var cands: Array = []
	for p in paths:
		var pts: PackedVector2Array = p.pts
		if int(p.junction) > 0:
			cands.append([pts[0], 2.0])
		var s := 0.0
		for i in range(1, pts.size()):
			s += 1.0
			if s >= 28.0 and s <= 52.0 and i % 3 == 0:
				cands.append([pts[i], 1.0 if p.kind == "main" else 0.6])
	# Shuffled by the village's own seed (the plan is the same every time).
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	cands.sort_custom(func(x, y): return x[1] > y[1])
	for pass_i in 3:
		_try_squares(cands, want, rr, [17, 13, 10][pass_i], [20.0, 14.0, 10.0][pass_i])
	# Odd numbers (§EG.2): two squares are one square and a junction.
	if squares.size() == 2:
		squares.resize(1)


func _try_squares(cands: Array, want: int, rr: Array, rim_min: int, apart: float) -> void:
	for c in cands:
		if squares.size() >= want:
			break
		var q: Vector2 = c[0]
		var r := rng.randf_range(float(rr[0]), float(rr[1]))
		var ok := wet_at(q) == 0 and q.distance_to(core) > 24.0
		for s in squares:
			if q.distance_to(s.c) < float(s.r) + r + apart:
				ok = false
		if not ok:
			continue
		# A rim that can be built on, to wrap it (§EF.4).
		var good := 0
		var reach := float(PL.get("radius_m", 78.0)) - 3.0
		for a in 24:
			var dv := Vector2.from_angle(a * TAU / 24.0)
			var rq := q + dv * (r + 3.2)
			var other := false
			for s in squares:
				if rq.distance_to(s.c) < float(s.r) + 3.5:
					other = true
			if not other and wet_at(rq) == 0 and rq.distance_to(core) < reach and absf(ground(rq + dv * 3.0) - ground(rq - dv * 3.0)) < 2.4:
				good += 1
		if good < rim_min:
			continue
		# Level enough to stand in.
		var fall := 0.0
		for a in 6:
			fall = maxf(fall, absf(ground(q + Vector2.from_angle(a * TAU / 6.0) * r) - ground(q)))
		if fall > 1.8:
			continue
		squares.append({"c": q, "r": r, "kind": "square"})


## Ma (§EG.3): one quiet empty space on purpose. A dug pond in front when
## the site lacks water there (§EE.3), else by the village's own lean: an
## empty square, a still pool, an unplanted bank by the landing.
func _choose_void() -> void:
	var kinds: Array = (PL.get("void_kinds", ["empty_square", "still_pool", "unplanted_bank"]) as Array).duplicate()
	var first := str(kinds[rng.randi() % kinds.size()])
	if builds.has("dug_pond_in_front"):
		first = "still_pool"
	kinds.erase(first)
	kinds.push_front(first)
	for k in kinds:
		if k == "empty_square" and squares.size() >= 3:
			# The secondary square furthest from the core.
			var bi := 1
			for i in range(1, squares.size()):
				if squares[i].c.distance_to(core) > squares[bi].c.distance_to(core):
					bi = i
			squares[bi].kind = "void"
			void_area = {"kind": "empty_square", "c": squares[bi].c, "r": float(squares[bi].r)}
			return
		if k == "still_pool" or k == "unplanted_bank":
			# In front, between the village and the water, off the paths.
			var r := 4.5 if k == "still_pool" else 7.0
			for tries in 160:
				var spread := 60.0 if tries < 60 else (110.0 if tries < 110 else 180.0)
				var a := deg_to_rad(90.0 + rng.randf_range(-spread, spread))
				var dist := rng.randf_range(14.0, 52.0) if k == "still_pool" else (core.distance_to(river_local) - river_half - float(PL.get("bank_keep_m", 14.0)) * rng.randf_range(0.2, 0.7))
				var q := core + Vector2.from_angle(a) * dist
				if k == "still_pool" and wet_at(q) != 0:
					continue
				if k == "unplanted_bank" and wet_at(q) == 2:
					continue
				if _near_path(q, r + 2.0) or _near_square(q, r + 3.0):
					continue
				var fall := 0.0
				for b in 6:
					fall = maxf(fall, absf(ground(q + Vector2.from_angle(b * TAU / 6.0) * r) - ground(q)))
				if fall > ((1.2 if tries < 110 else 2.0) if k == "still_pool" else 2.8):
					continue
				void_area = {"kind": k, "c": q, "r": r}
				return


func _near_path(q: Vector2, m: float) -> bool:
	for p in paths:
		var lim := m + float(p.half)
		for v in (p.pts as PackedVector2Array):
			if v.distance_squared_to(q) < lim * lim:
				return true
	return false


func _near_square(q: Vector2, m: float) -> bool:
	for s in squares:
		if q.distance_to(s.c) < float(s.r) + m:
			return true
	return false


## Water, the bank, the lanes, the squares and the void into the grid.
func _raster_ground() -> void:
	occ.resize(NO * NO)
	top.resize(NO * NO)
	owner.resize(NO * NO)
	owner.fill(-1)
	for j in NO:
		for i in NO:
			var q := Vector2(-E + (i + 0.5) * OCC_M, -E + (j + 0.5) * OCC_M)
			var w := wet_at(q)
			occ[j * NO + i] = WATER if w == 2 else (BANK if w == 1 else FREE)
			top[j * NO + i] = ground(q)
	for s in squares:
		_disc(s.c, float(s.r), SQUARE)
	for p in paths:
		var half := float(p.half)
		for v in (p.pts as PackedVector2Array):
			_disc(v, half, PATH)
	if not void_area.is_empty():
		_disc(void_area.c, float(void_area.r), VOID)


func _disc(c: Vector2, r: float, v: int) -> void:
	var i0 := int((c.x - r + E) / OCC_M)
	var i1 := int((c.x + r + E) / OCC_M)
	var j0 := int((c.y - r + E) / OCC_M)
	var j1 := int((c.y + r + E) / OCC_M)
	for j in range(maxi(j0, 0), mini(j1 + 1, NO)):
		for i in range(maxi(i0, 0), mini(i1 + 1, NO)):
			var q := Vector2(-E + (i + 0.5) * OCC_M, -E + (j + 0.5) * OCC_M)
			if q.distance_squared_to(c) <= r * r:
				var k := j * NO + i
				# Paths over the bank stay paths (the landing); squares and the
				# void don't override water.
				if occ[k] == WATER and v != PATH:
					continue
				if v == PATH and occ[k] in [SQUARE, VOID]:
					continue
				occ[k] = v


## Cells under a rotated rect (centre c, axes u, v, half sizes hw, hd).
func _rect_cells(c: Vector2, u: Vector2, v: Vector2, hw: float, hd: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var ext := absf(u.x) * hw + absf(v.x) * hd
	var exz := absf(u.y) * hw + absf(v.y) * hd
	var i0 := int((c.x - ext + E) / OCC_M)
	var i1 := int((c.x + ext + E) / OCC_M)
	var j0 := int((c.y - exz + E) / OCC_M)
	var j1 := int((c.y + exz + E) / OCC_M)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			if i < 0 or j < 0 or i >= NO or j >= NO:
				out.append(-1)
				continue
			var q := Vector2(-E + (i + 0.5) * OCC_M, -E + (j + 0.5) * OCC_M) - c
			if absf(q.dot(u)) <= hw and absf(q.dot(v)) <= hd:
				out.append(j * NO + i)
	return out


## May a building stand on rect (c, u, v, w, d)? Clear of water, bank,
## lanes, squares, the void and other buildings (shrunk by `slack`),
## within the village, its ground falling no more than max_fall_m.
func _fits(c: Vector2, u: Vector2, v: Vector2, w: float, d: float, slack := 0.25, group_rects: Array = []) -> bool:
	if c.distance_to(core) > float(PL.get("radius_m", 78.0)) - 3.0:
		return false
	for k in _rect_cells(c, u, v, w * 0.5 - slack, d * 0.5 - slack):
		if k < 0 or occ[k] != FREE:
			return false
	for r in group_rects:
		if _rects_overlap(c, u, v, w * 0.5 - 0.3, d * 0.5 - 0.3, r[0], r[1], r[2], float(r[3]) * 0.5 - 0.3, float(r[4]) * 0.5 - 0.3):
			return false
	var lo := INF
	var hi := -INF
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			var g := ground(c + u * w * sx + v * d * sz)
			lo = minf(lo, g)
			hi = maxf(hi, g)
	return hi - lo <= float(PL.get("max_fall_m", 3.2))


static func _rects_overlap(c1: Vector2, u1: Vector2, v1: Vector2, w1: float, d1: float, c2: Vector2, u2: Vector2, v2: Vector2, w2: float, d2: float) -> bool:
	var t := c2 - c1
	for ax: Vector2 in [u1, v1, u2, v2]:
		var r1 := w1 * absf(u1.dot(ax)) + d1 * absf(v1.dot(ax))
		var r2 := w2 * absf(u2.dot(ax)) + d2 * absf(v2.dot(ax))
		if absf(t.dot(ax)) > r1 + r2:
			return false
	return true


## The landmark (§EF.10): a tower on the uphill rim of a square (not the
## void), so it stands up the slope; sized after the vistas (_size_tower).
func _place_tower() -> void:
	var order: Array = []
	for i in squares.size():
		if squares[i].kind != "void":
			order.append(i)
	# The square most in the middle of the lanes and highest (seen from
	# the most of them), a secondary one before the core.
	var mid := Vector2.ZERO
	var n := 0
	for p in paths:
		for v in (p.pts as PackedVector2Array):
			mid += v
			n += 1
	mid /= maxf(1.0, n)
	var sc := {}
	for i in order:
		sc[i] = ground(squares[i].c) - 0.12 * (squares[i].c as Vector2).distance_to(mid) - (3.0 if squares[i].kind == "core" else 0.0)
	order.sort_custom(func(a, b): return float(sc[a]) > float(sc[b]))
	var size := 4.4
	for si in order:
		var s: Dictionary = squares[si]
		var best := {}
		var bh := -INF
		for k in 36:
			var a := k * TAU / 36.0
			var dirv := Vector2.from_angle(a)
			var c: Vector2 = s.c + dirv * (float(s.r) + size * 0.5 + 0.4)
			var u := Vector2(-dirv.y, dirv.x)
			if not _fits(c, u, dirv, size, size, 0.1):
				continue
			if ground(c) > bh:
				bh = ground(c)
				best = {"c": c, "u": u, "v": dirv, "size": size, "square": si, "h": 17.0}
		if not best.is_empty():
			tower = best
			_mark_rect(tower.c, tower.u, tower.v, size, size, TOWER, -2, ground(tower.c) + 17.0)
			return


func _mark_rect(c: Vector2, u: Vector2, v: Vector2, w: float, d: float, val: int, idx: int, h: float) -> void:
	for k in _rect_cells(c, u, v, w * 0.5, d * 0.5):
		if k >= 0:
			occ[k] = val
			owner[k] = idx
			top[k] = h


func _ring(q: Vector2) -> String:
	var dd := q.distance_to(core)
	if dd < float(PL.get("core_ring_m", 26.0)):
		return "core"
	return "edge" if dd > float(PL.get("edge_ring_m", 52.0)) else "mid"


func _group_size(ring: String) -> int:
	var key := "core_groups" if ring == "core" else ("edge_groups" if ring == "edge" else "mid_groups")
	var arr: Array = PL.get(key, [3])
	return int(arr[rng.randi() % arr.size()])


func _house_dims(ring: String) -> Vector2:
	var fr: Array = PL.get("frontage_m", [4.6, 6.4])
	var dp: Array = PL.get("depth_m", [5.0, 6.6])
	var w := rng.randf_range(float(fr[0]), float(fr[1]))
	var d := rng.randf_range(float(dp[0]), float(dp[1]))
	if ring == "edge":
		w *= 0.92
	return Vector2(w, d)


## Close a terrace: trim it to an allowed size (1, 3 or 5: odd numbers,
## §EG.2) and fix its houses in the grid.
func _close_group(cur: Array) -> void:
	var n := cur.size()
	var keep := 5 if n >= 5 else (3 if n >= 3 else (1 if n >= 1 else 0))
	cur.resize(keep)
	if keep == 0:
		return
	var gi := groups.size()
	var g: Array = []
	for h in cur:
		h["group"] = gi
		var idx := houses.size()
		houses.append(h)
		g.append(idx)
		_mark_rect(h.c, h.u, h.v, float(h.w), float(h.d), HOUSE, idx, ground(h.c) + 4.6)
	groups.append(g)


## Houses wrap the squares (§EF.4): fronts on the rim facing in, sharing
## walls, a gap where a lane comes in.
func _wrap_squares() -> void:
	for si in squares.size():
		var s: Dictionary = squares[si]
		var r := float(s.r)
		var ring := "core" if s.kind == "core" else "mid"
		var a := rng.randf() * TAU
		var end := a + TAU - 0.1
		var cur: Array = []
		var target := _group_size(ring) if s.kind == "core" else 3
		while a < end:
			var dim := _house_dims(ring)
			var dirv := Vector2.from_angle(a + dim.x * 0.5 / r)
			var c: Vector2 = s.c + dirv * (r + dim.y * 0.5 + 0.05)
			var u := Vector2(-dirv.y, dirv.x)
			var rects: Array = []
			for h in cur:
				rects.append([h.c, h.u, h.v, h.w, h.d])
			if _fits(c, u, dirv, dim.x, dim.y, 0.25, rects):
				cur.append(_house(c, u, dirv, dim, ring, si, -1))
				a += dim.x / r
				if cur.size() >= target:
					_close_group(cur)
					cur = []
					target = _group_size(ring) if s.kind == "core" else 3
					a += rng.randf_range(1.6, 3.0) / r
			else:
				if not cur.is_empty():
					_close_group(cur)
					cur = []
					target = _group_size(ring) if s.kind == "core" else 3
				a += 0.5 / r
		_close_group(cur)
		# Still open on too much of its rim: small houses in the gaps, then
		# garden walls (a wall closes a room too).
		if _wrap_share(s) < 0.6:
			var b := rng.randf() * TAU
			var b_end := b + TAU
			while b < b_end and _wrap_share(s) < 0.6:
				var dim := Vector2(rng.randf_range(3.6, 4.4), rng.randf_range(4.2, 5.2))
				var dirv := Vector2.from_angle(b + dim.x * 0.5 / r)
				var c: Vector2 = s.c + dirv * (r + dim.y * 0.5 + 0.05)
				var u := Vector2(-dirv.y, dirv.x)
				if _fits(c, u, dirv, dim.x, dim.y, 0.25):
					_close_group([_house(c, u, dirv, dim, ring, si, -1)])
					b += dim.x / r
				else:
					b += 0.5 / r
		_close_rim(si)


## Garden walls on square `si`'s rim, in its open gaps (not across a
## lane), until it is held (§EF.4: a wall closes a room too).
func _close_rim(si: int) -> void:
	var s: Dictionary = squares[si]
	var r := float(s.r)
	if s.kind == "void" or _wrap_share(s) >= 0.58:
		return
	for k in 72:
		if _wrap_share(s) >= 0.58:
			break
		var dirv := Vector2.from_angle(k * TAU / 72.0)
		var q: Vector2 = (s.c as Vector2) + dirv * (r + 0.6)
		var tang := Vector2(-dirv.y, dirv.x)
		var clear := true
		for e: float in [-1.6, 0.0, 1.6]:
			if occ_at(q + tang * e) != FREE or wet_at(q + tang * e) != 0:
				clear = false
		if clear and not _near_path(q, 0.6):
			garden_walls.append({"a": q - tang * 1.7, "b": q + tang * 1.7, "square": si})
			_mark_rect(q, tang, dirv, 3.4, 0.6, HOUSE, -3, ground(q) + 1.7)


func _house(c: Vector2, u: Vector2, v: Vector2, dim: Vector2, ring: String, square: int, path: int) -> Dictionary:
	return {"c": c, "u": u, "v": v, "w": dim.x, "d": dim.y, "ring": ring, "square": square, "path": path,
		"focal": false, "door": c - v * dim.y * 0.5, "seed": rng.randi(), "group": -1, "district": -1}


## Then houses packed along the paths, fronts to the path, sharing walls:
## tight terraces near the core, looser out to the edge (§EF.1).
func _rows() -> void:
	var order: Array = []
	for i in paths.size():
		order.append(i)
	for pi in order:
		var p: Dictionary = paths[pi]
		var pts: PackedVector2Array = p.pts
		var half := float(p.half)
		# Never mirrored (§EG.2): one side of the lane keeps its line, the
		# other sets each terrace back by its own amount (front yards).
		var yard_side := 1.0 if rng.randf() < 0.5 else -1.0
		for side: float in [1.0, -1.0]:
			var s := 2.0
			var L := float(pts.size() - 1)
			var cur: Array = []
			var target := 0
			var back := 0.0
			while s < L - 2.0:
				var at := pts[int(s)]
				var ring := _ring(at)
				if target == 0:
					target = _group_size(ring)
					back = rng.randf_range(0.6, 2.6) if side == yard_side else rng.randf_range(0.0, 0.3)
				var dim := _house_dims(ring)
				var i0 := clampi(int(s), 0, pts.size() - 1)
				var i1 := clampi(int(s + dim.x), 0, pts.size() - 1)
				if i1 <= i0:
					break
				var t := (pts[i1] - pts[i0]).normalized()
				var nrm: Vector2 = Vector2(-t.y, t.x) * side
				var mid := (pts[i0] + pts[i1]) * 0.5
				var c: Vector2 = mid + nrm * (half + dim.y * 0.5 + 0.1 + back)
				var rects: Array = []
				for h in cur:
					rects.append([h.c, h.u, h.v, h.w, h.d])
				if _fits(c, t, nrm, dim.x, dim.y, 0.25, rects):
					cur.append(_house(c, t, nrm, dim, ring, -1, pi))
					s += dim.x
					if cur.size() >= target:
						_close_group(cur)
						cur = []
						target = 0
						var gap: Array = PL.get("edge_gap_m" if ring == "edge" else "core_gap_m", [1.5, 3.0])
						if ring == "mid":
							gap = [float((PL.get("core_gap_m", [1.4, 2.6]) as Array)[1]), float((PL.get("edge_gap_m", [4.0, 8.0]) as Array)[0])]
						s += rng.randf_range(float(gap[0]), float(gap[1]))
				else:
					if not cur.is_empty():
						_close_group(cur)
						cur = []
						target = 0
					s += 1.0
			_close_group(cur)


## Three districts you could name (§EG.1), by what they face: the high
## quarter toward the spring, the hearth quarter round the core, the water
## quarter toward the landing. Thresholds where a lane crosses between two
## (§EF.9): an arch where houses close in on both sides, else a band of
## kerb stones across (a change of paving).
func _districts() -> void:
	axis = (landing - spring).normalized()
	var alongs: Array = []
	for h in houses:
		alongs.append(((h.c as Vector2) - core).dot(axis))
	alongs.sort()
	if alongs.size() >= 3:
		cut = Vector2(alongs[alongs.size() / 3], alongs[alongs.size() * 2 / 3])
	districts = [
		{"name": "the high quarter", "character": "stepped houses on dry-stone terraces below the spring", "houses": []},
		{"name": "the hearth quarter", "character": "tight rows wrapping the hearth and the well", "houses": []},
		{"name": "the water quarter", "character": "houses on posts and long steps down to the landing", "houses": []},
	]
	for i in houses.size():
		var di := _district_of(houses[i].c)
		houses[i].district = di
		districts[di].houses.append(i)
	for p in paths:
		var pts: PackedVector2Array = p.pts
		var last := _district_of(pts[0])
		for i in range(1, pts.size()):
			var di := _district_of(pts[i])
			if di != last:
				var t := (pts[mini(i + 1, pts.size() - 1)] - pts[i - 1]).normalized()
				var nrm := Vector2(-t.y, t.x)
				var reach := float(p.half) + 2.5
				var both := occ_at(pts[i] + nrm * reach) == HOUSE and occ_at(pts[i] - nrm * reach) == HOUSE
				var close := false
				for th in thresholds:
					if (th.p as Vector2).distance_to(pts[i]) < 8.0:
						close = true
				if not close:
					thresholds.append({"p": pts[i], "t": t, "kind": "arch" if both else "paving", "half": float(p.half), "between": [last, di]})
				last = di


## Which third of the village `q` lies in, along the spring-to-landing
## axis (the cuts at the houses' thirds).
func _district_of(q: Vector2) -> int:
	var a := (q - core).dot(axis)
	return 0 if a < cut.x else (1 if a < cut.y else 2)


## Edges (§EG.1): the stream in front; round the rest a dry-stone wall a
## few metres beyond the houses, open where the lanes leave and fallen
## in places.
func _edges_and_wall() -> void:
	var pts := PackedVector2Array()
	for h in houses:
		for sx: float in [-0.5, 0.5]:
			for sz: float in [-0.5, 0.5]:
				pts.append(h.c + h.u * float(h.w) * sx + h.v * float(h.d) * sz)
	if pts.size() < 3:
		return
	var hull := Geometry2D.convex_hull(pts)
	# Out 6 m, then along each side in 2.5 m pieces.
	var cen := Vector2.ZERO
	for q in hull:
		cen += q
	cen /= hull.size()
	var out := PackedVector2Array()
	for q in hull:
		out.append(q + (q - cen).normalized() * 6.0)
	for i in out.size() - 1:
		var a := out[i]
		var b := out[i + 1]
		var n := maxi(1, int(a.distance_to(b) / 2.5))
		for k in n:
			var p0 := a.lerp(b, float(k) / n)
			var p1 := a.lerp(b, float(k + 1) / n)
			var m := (p0 + p1) * 0.5
			var o := occ_at(m)
			if o in [WATER, BANK, PATH, SQUARE, VOID, HOUSE, TOWER]:
				continue
			# Fallen here and there.
			if rng.randf() < 0.12:
				continue
			wall.append([p0, p1])


## The gutter (§EF.8): down the main street from the spring to the
## landing, along one side of it. Dry while the village is dead.
func _gutter() -> void:
	var up_p := PackedVector2Array()
	var down_p := PackedVector2Array()
	for p in paths:
		if p.kind == "main" and p.to == "spring":
			up_p = p.pts
		elif p.kind == "main" and p.to == "landing":
			down_p = p.pts
	var main := PackedVector2Array()
	for i in range(up_p.size() - 1, -1, -1):
		main.append(up_p[i])
	for i in range(1, down_p.size()):
		main.append(down_p[i])
	if main.size() < 4:
		return
	var half := float(PL.get("main_half_m", 1.9))
	for i in main.size():
		var t := (main[mini(i + 1, main.size() - 1)] - main[maxi(i - 1, 0)]).normalized()
		var q := main[i] + Vector2(-t.y, t.x) * (half - 0.35)
		if occ_at(q) == WATER:
			break
		gutter.append(q)


# --- Vistas (§EF.2) ------------------------------------------------------------

## A sightline from `from` along `dir` at eye height: how far until a
## building, focal or the village's edge: {len, end ("house", "tower",
## "focal", "out"), hit (index)}.
func sightline(from: Vector2, dir: Vector2, max_m := 140.0) -> Dictionary:
	var R := float(PL.get("radius_m", 78.0)) + 8.0
	var side := Vector2(-dir.y, dir.x) * 0.5
	var s := 0.0
	while s < max_m:
		s += OCC_M
		var q := from + dir * s
		var k := _oi(q)
		if k < 0 or q.distance_to(core) > R:
			return {"len": s, "end": "out", "hit": -1}
		# The view has a body: half a metre either side (no vista through
		# a crack between two corners).
		for o_q in [q, q + side, q - side]:
			var kk := _oi(o_q)
			if kk < 0:
				continue
			var o := occ[kk]
			if o == HOUSE and owner[kk] >= 0:
				return {"len": s, "end": "house", "hit": owner[kk]}
			if o == HOUSE or o == TOWER:
				return {"len": s, "end": "tower" if o == TOWER else "wall", "hit": -2}
			if o == FOCAL:
				return {"len": s, "end": "focal", "hit": owner[kk]}
	return {"len": max_m, "end": "out", "hit": -1}


## Does a focal stand in the far part of the view (cone `half_deg` about
## `dir`, from `lo` m to `hi` m out)? Its index, or -1.
func focal_in_cone(from: Vector2, dir: Vector2, lo: float, hi: float, half_deg := 22.0) -> int:
	for i in focals.size():
		var v: Vector2 = (focals[i].p as Vector2) - from
		var l := v.length()
		if l < lo or l > hi:
			continue
		if rad_to_deg(absf(dir.angle_to(v))) <= half_deg:
			return i
	return -1


## Does the land beyond rise into the view (borrowed scenery, shakkei)?
## March 500 m past the village along `dir` on the real ground: a hill
## standing 1.2 degrees or more over the eye line counts.
func far_hill(from: Vector2, dir: Vector2) -> bool:
	var eye := ground(from) + 1.6
	var s := 40.0
	while s <= 500.0:
		var q := from + dir * s
		var g := map.terrain.elevation(dir_at(q), true) - base_e
		if rad_to_deg(atan2(g - eye, s)) >= 1.2:
			return true
		s += 20.0
	return false


## Can the eye at `from` see the tower's top part? (2.5D over the grid.)
func sees_tower(from: Vector2) -> bool:
	if tower.is_empty():
		return false
	var eye := ground(from) + 1.6
	var tc: Vector2 = tower.c
	var tb := ground(tc)
	for frac: float in [1.0, 0.85, 0.7]:
		var th: float = tb + float(tower.h) * frac
		var dv := tc - from
		var l := dv.length()
		if l < 1.0:
			return true
		var dn := dv / l
		var blocked := false
		var s := 1.0
		while s < l - float(tower.size) * 0.6:
			var q := from + dn * s
			var k := _oi(q)
			if k >= 0:
				var line := lerpf(eye, th, s / l)
				var o := occ[k]
				var tp := top[k] if o in [HOUSE, FOCAL] else ground(q)
				if tp > line:
					blocked = true
					break
			s += OCC_M
		if not blocked:
			return true
	return false


## The vista pass: from every 3 m of every lane, both ways along it, find
## the long views; each must end on a building, a focal or borrowed
## scenery; where one runs on into nothing a focal goes in, off the axis
## on a third (focal_angle_deg), at the far end (§EF.2, §EG.2).
func _vistas() -> void:
	var long_m := float(PL.get("long_vista_m", 24.0))
	var kinds := ["tree", "hearth", "tree", "shrine", "tree", "hearth"]
	var ang := deg_to_rad(float(PL.get("focal_angle_deg", 15.0)))
	for pi in paths.size():
		var pts: PackedVector2Array = paths[pi].pts
		var i := 2
		while i < pts.size() - 2:
			for sg: float in [1.0, -1.0]:
				var t: Vector2 = (pts[mini(i + 2, pts.size() - 1)] - pts[maxi(i - 2, 0)]).normalized() * sg
				var from := pts[i]
				var sl := sightline(from, t)
				if float(sl.len) < long_m:
					continue
				var v := {"from": from, "dir": t, "len": float(sl.len), "end": str(sl.end), "hit": int(sl.hit), "path": pi}
				if sl.end == "house":
					houses[int(sl.hit)].focal = true
				elif sl.end == "out":
					var far := float(sl.len)
					if focal_in_cone(from, t, far * 0.45, far + 14.0) >= 0:
						v.end = "focal"
					elif _tower_in_cone(from, t) and sees_tower(from):
						v.end = "tower"
					elif far_hill(from, t):
						v.end = "hill"
					else:
						var placed := _place_focal(from, t, far, ang, str(kinds[focals.size() % kinds.size()]), vistas.size())
						v.end = "placed" if placed else "none"
				vistas.append(v)
			i += 3


func _tower_in_cone(from: Vector2, dir: Vector2) -> bool:
	if tower.is_empty():
		return false
	return rad_to_deg(absf(dir.angle_to((tower.c as Vector2) - from))) <= 22.0


func _place_focal(from: Vector2, t: Vector2, far: float, ang: float, kind: String, vista: int) -> bool:
	var perp := Vector2(-t.y, t.x)
	var tries: Array = []
	# On a third where the view is open enough; else in the slot a lane
	# leaves open, still off its axis (never dead centre).
	for a in [ang, ang * 0.7, ang * 1.35, ang * 0.55, ang * 1.45, deg_to_rad(6.0), deg_to_rad(4.5), deg_to_rad(3.2)]:
		for df in [minf(far - 3.0, 32.0), minf(far - 3.0, 26.0), 20.0, 38.0, 16.0, 44.0, 13.0, 10.0, 50.0, far + 4.0, far + 10.0]:
			tries.append([df, a])
	for tr in tries:
		var df: float = tr[0]
		if df < 9.5:
			continue
		for sd in ([1.0, -1.0] if rng.randf() < 0.5 else [-1.0, 1.0]):
			var q: Vector2 = from + t * df + perp * sd * tan(float(tr[1])) * df
			var ok := true
			for k in _rect_cells(q, Vector2.RIGHT, Vector2.UP, 1.4, 1.4):
				if k < 0 or not occ[k] in [FREE, BANK]:
					ok = false
					break
			if not ok or wet_at(q) == 2 or not _clear_line(from, q):
				continue
			var idx := focals.size()
			focals.append({"p": q, "kind": kind, "vista": vista})
			var h := 2.2 if kind != "tree" else 9.0
			_mark_rect(q, Vector2.RIGHT, Vector2.UP, 1.6 if kind != "tree" else 1.2, 1.6 if kind != "tree" else 1.2, FOCAL, idx, ground(q) + h)
			if kind == "tree":
				trees.append(q)
			return true
	return false


## The tower's height: the shortest of tower_h_m seen from
## landmark_seen_min of the lanes (sampled every 4 m). Where even the
## tallest isn't, the tower moves to the free spot by a lane, on the higher
## ground, that is seen from the most of them (§EF.10).
func _size_tower() -> void:
	if tower.is_empty():
		return
	var need := float(PL.get("landmark_seen_min", 0.55))
	var hs: Array = PL.get("tower_h_m", [14.0, 17.0, 20.0, 23.0])
	tower.h = float(hs[-1])
	landmark_seen = landmark_share()
	if landmark_seen < need:
		_relocate_tower()
	for h in hs:
		tower.h = float(h)
		landmark_seen = landmark_share()
		if landmark_seen >= need:
			break
	_mark_rect(tower.c, tower.u, tower.v, float(tower.size), float(tower.size), TOWER, -2, ground(tower.c) + float(tower.h))


## Share of lane spots (every 4 m) the tower's top is seen from.
func landmark_share() -> float:
	if tower.is_empty():
		return 0.0
	var seen := 0
	var n := 0
	for p in paths:
		var pts: PackedVector2Array = p.pts
		for i in range(0, pts.size(), 4):
			n += 1
			if sees_tower(pts[i]):
				seen += 1
	return float(seen) / maxf(1.0, n)


func _relocate_tower() -> void:
	var size := float(tower.size)
	var old := tower.duplicate()
	for k in _rect_cells(tower.c, tower.u, tower.v, size * 0.5, size * 0.5):
		if k >= 0:
			occ[k] = FREE
			owner[k] = -1
			top[k] = ground(Vector2(-E + (k % NO + 0.5) * OCC_M, -E + (k / NO + 0.5) * OCC_M))
	var cands: Array = []
	for p in paths:
		var pts: PackedVector2Array = p.pts
		for i in range(3, pts.size() - 3, 5):
			var t := (pts[i + 2] - pts[i - 2]).normalized()
			for sd: float in [1.0, -1.0]:
				var nrm := Vector2(-t.y, t.x) * sd
				var c := pts[i] + nrm * (float(p.half) + size * 0.5 + 0.3)
				if c.distance_to(core) < 12.0 or not _fits(c, t, nrm, size, size, 0.1):
					continue
				cands.append([ground(c), c, t, nrm])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var best := {}
	var best_s := landmark_share_at(old)
	for c in cands.slice(0, 40):
		var cand := {"c": c[1], "u": c[2], "v": c[3], "size": size, "square": -1, "h": float(tower.h)}
		var s := landmark_share_at(cand)
		if s > best_s:
			best_s = s
			best = cand
	if not best.is_empty():
		tower = best
	_mark_rect(tower.c, tower.u, tower.v, size, size, TOWER, -2, ground(tower.c) + float(tower.h))


## The frame pass (§EF.7): a key view with nothing near it at the side
## gets an old tree beside the lane a few metres ahead, its trunk and
## branches the near frame (a "branch", in the design's words).
func _frame_pass() -> void:
	for v in key_views():
		if _layered_one(v):
			continue
		var from: Vector2 = v.from
		var dir: Vector2 = v.dir
		var nrm := Vector2(-dir.y, dir.x)
		var done := false
		for ahead: float in [3.0, 4.5, 2.0]:
			for lat: float in [3.2, 4.2, 5.2]:
				for sd: float in [1.0, -1.0]:
					if done:
						break
					var q := from + dir * ahead + nrm * sd * lat
					var ok := true
					for k in _rect_cells(q, Vector2.RIGHT, Vector2.UP, 0.8, 0.8):
						if k < 0 or occ[k] != FREE:
							ok = false
							break
					if not ok or wet_at(q) != 0:
						continue
					var idx := focals.size()
					focals.append({"p": q, "kind": "tree", "vista": -1, "frame": true})
					trees.append(q)
					_mark_rect(q, Vector2.RIGHT, Vector2.UP, 1.0, 1.0, FOCAL, idx, ground(q) + 9.0)
					done = true


## Upper storeys from the hierarchy pass can hide the tower: it grows
## through tower_h_m until it is seen again (a taller tower is only more
## seen, so the views that end on it still do).
func _regrow_tower() -> void:
	if tower.is_empty():
		return
	var need := float(PL.get("landmark_seen_min", 0.55))
	for h in PL.get("tower_h_m", [14.0, 17.0, 20.0, 23.0]):
		if float(h) < float(tower.h):
			continue
		tower.h = float(h)
		landmark_seen = landmark_share()
		if landmark_seen >= need:
			break
	_mark_rect(tower.c, tower.u, tower.v, float(tower.size), float(tower.size), TOWER, -2, ground(tower.c) + float(tower.h))


func landmark_share_at(t: Dictionary) -> float:
	var keep := tower
	tower = t
	var s := landmark_share()
	tower = keep
	return s


## Hearths: one in every house, at the back wall under its chimney; one in
## every square but the void, off its middle (the well across from it in
## the core); the vista hearths. Refuge in the squares (§EG.4): a bench
## against a rim house's front by its door, facing in; while the square's
## hearth is cold, brambles cover those fronts.
func _hearths_and_refuge() -> void:
	for i in houses.size():
		var h: Dictionary = houses[i]
		h["hearth"] = h.c + h.v * (float(h.d) * 0.5 - 1.25)
		hearths.append({"p": h.hearth, "kind": "house", "of": i})
	for si in squares.size():
		var s: Dictionary = squares[si]
		if s.kind == "void":
			s["hearth"] = null
			continue
		var a := rng.randf() * TAU
		s["hearth"] = s.c + Vector2.from_angle(a) * float(s.r) * 0.38
		if s.kind == "core":
			s["well"] = s.c - Vector2.from_angle(a + 0.4) * float(s.r) * 0.45
		hearths.append({"p": s.hearth, "kind": "square", "of": si})
	for fi in focals.size():
		if focals[fi].kind == "hearth":
			hearths.append({"p": focals[fi].p, "kind": "vista", "of": fi})
	var bm := float(BLD.get("bramble_m", 1.4))
	for i in houses.size():
		var h: Dictionary = houses[i]
		var si := int(h.square)
		if si < 0 or squares[si].kind == "void":
			continue
		var door: Vector2 = h.door
		var u: Vector2 = h.u
		var w := float(h.w)
		var side := 1.0 if (h.seed % 2) == 0 else -1.0
		var hi := -INF
		for sx: float in [-0.5, 0.0, 0.5]:
			for sz: float in [-0.5, 0.0, 0.5]:
				hi = maxf(hi, ground((h.c as Vector2) + u * w * sx + (h.v as Vector2) * float(h.d) * sz))
		var bench_q: Vector2 = door + u * side * w * 0.3 - (h.v as Vector2) * 0.45
		# A bench needs the wall at its back: not under a raised floor.
		if hi + 0.15 - ground(bench_q) <= 0.5:
			refuge.append({"p": bench_q, "facing": -h.v, "square": si, "house": i})
		# Brambles along the front either side of the door (the door kept).
		brambles.append({"a": door - u * w * 0.5, "b": door - u * 0.75, "out": -(h.v as Vector2), "m": bm, "square": si})
		brambles.append({"a": door + u * 0.75, "b": door + u * w * 0.5, "out": -(h.v as Vector2), "m": bm, "square": si})
	for si in squares.size():
		if squares[si].kind == "void" or _square_refuge(si) > 0:
			continue
		var s: Dictionary = squares[si]
		var r := float(s.r)
		for k in 108:
			var dirv := Vector2.from_angle((k % 36) * TAU / 36.0)
			var q: Vector2 = (s.c as Vector2) + dirv * (r - 0.4 - 0.8 * float(k / 36))
			var tang := Vector2(-dirv.y, dirv.x)
			var clear := true
			for e: float in [-1.6, 0.0, 1.6]:
				if not occ_at(q + tang * e) in [FREE, SQUARE] or wet_at(q + tang * e) != 0:
					clear = false
			# Not across a lane coming in.
			if clear and _near_path(q, 0.4):
				clear = false
			if not clear:
				continue
			rim_walls.append({"a": q - tang * 1.7, "b": q + tang * 1.7, "square": si})
			_mark_rect(q, tang, dirv, 3.4, 0.6, HOUSE, -3, ground(q) + 1.2)
			refuge.append({"p": q - dirv * 0.75, "facing": -dirv, "square": si, "house": -1})
			brambles.append({"a": q - tang * 1.7 - dirv * 0.3, "b": q + tang * 1.7 - dirv * 0.3, "out": -dirv, "m": bm, "square": si})
			break


## Edges to linger on (§EF.6): a low wall and a bench where the view is
## good, on the village's front rim looking over the water.
func _lingering_edges() -> void:
	var cands: Array = []
	for k in 120:
		var a := rng.randf() * TAU
		var q := core + Vector2.from_angle(a) * rng.randf_range(16.0, float(PL.get("radius_m", 78.0)) - 4.0)
		if not occ_at(q) in [FREE, BANK] or wet_at(q) == 2 or not _near_path(q, 10.0):
			continue
		if not void_area.is_empty() and q.distance_to(void_area.c) < float(void_area.r) + 2.0:
			continue
		# The prospect: how far the ground falls away toward the water.
		var tw := (river_local - q).normalized()
		var fall := ground(q) - ground(q + tw * 20.0)
		var free := 0
		for s in [3.0, 6.0, 9.0, 12.0]:
			if not occ_at(q + tw * s) in [HOUSE, TOWER]:
				free += 1
		cands.append([fall + free * 0.5, q])
	cands.sort_custom(func(x, y): return x[0] > y[0])
	for c in cands:
		if edges.size() >= 2:
			break
		var q: Vector2 = c[1]
		var far := true
		for e in edges:
			if (e.p as Vector2).distance_to(q) < 18.0:
				far = false
		if far:
			edges.append({"p": q, "facing": (river_local - q).normalized()})


# --- For the plants (VegetationPlacer) -----------------------------------------

## Should plants keep off `d`? The lanes, squares, houses, the tower, the
## void and the built focals with a margin; yards and gaps grow wild.
func clear_at(d: Vector3) -> bool:
	var q := local_of(d)
	if q.distance_to(core) > float(PL.get("radius_m", 78.0)) + 10.0:
		return false
	for o in [Vector2.ZERO, Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5)]:
		var k := _oi(q + o)
		if k >= 0 and occ[k] in [PATH, SQUARE, HOUSE, TOWER, VOID]:
			return true
		if k >= 0 and occ[k] == FOCAL and str(focals[owner[k]].kind) != "tree":
			return true
	return false


## The feature trees' directions (VegetationPlacer plants them old).
func tree_dirs() -> PackedVector3Array:
	var out := PackedVector3Array()
	for t in trees:
		out.append(dir_at(t))
	return out


# --- The rules, measured (tools/village_check.gd) ------------------------------

## [[rule id, pass, detail]...] for this village.
func rules() -> Array:
	var out: Array = []
	var R := float(PL.get("radius_m", 78.0))
	# §EE.3 siting.
	out.append(["siting", float(site.score) >= float(Villages.P.get("min_score", 1.6)), "score %.2f (%s)" % [float(site.score), _terms_str()]])
	# §EF.1 grown from the reason: paths from the core, houses on them,
	# tighter at the core than the edge.
	var dens := _density()
	out.append(["grow_from_reason", paths.size() >= 3 and houses.size() >= 12 and dens.x > dens.y * 1.5,
		"%d desire lines, %d houses; ground built on: %.0f%% in the core, %.0f%% at the edge" % [paths.size(), houses.size(), dens.x * 100.0, dens.y * 100.0]])
	# §EE.3 with the land: never a flattened pad (checked on the build).
	# §EF.2 every long sightline terminated.
	var long_n := 0
	var bad := 0
	var by := {}
	for v in vistas:
		long_n += 1
		by[v.end] = int(by.get(v.end, 0)) + 1
		if v.end == "none":
			bad += 1
	out.append(["terminate_vistas", bad == 0 and long_n > 0, "%d long views, unterminated %d; ends %s" % [long_n, bad, str(by)]])
	# §EF.3 compress, then release.
	var cr := _compress_release()
	out.append(["compress_release", cr.x >= 2, "%d narrow-to-open releases along the lanes (main street %d)" % [cr.x, cr.y]])
	# §EF.4 buildings wrap the squares.
	var wraps: Array = []
	var wrap_ok := true
	for s in squares:
		var cov := _wrap_share(s)
		wraps.append(snappedf(cov, 0.01))
		if s.kind != "void" and cov < 0.5:
			wrap_ok = false
	out.append(["wrap_outdoor_rooms", wrap_ok, "rim covered %s" % str(wraps)])
	# §EF.5 streets bend.
	var bend := _bends()
	out.append(["gentle_curves", bend.x <= 32.0 and bend.y >= 6.0, "longest straight run %.0f m; least bend in a lane %.0f deg" % [bend.x, bend.y]])
	out.append(["lingering_edges", edges.size() >= 1, "%d edge seats over the water" % edges.size()])
	var ld := _layered()
	out.append(["layered_depth", ld >= 0.6, "%.0f%% of the %d key views have a near frame, a middle and a far end" % [ld * 100.0, key_views().size()]])
	out.append(["water_you_follow", gutter.size() >= 40, "gutter %d m down the main street (dry while dead)" % gutter.size()])
	var arches := 0
	for t in thresholds:
		if t.kind == "arch":
			arches += 1
	out.append(["thresholds", thresholds.size() >= 2, "%d thresholds (%d arches)" % [thresholds.size(), arches]])
	landmark_seen = landmark_share()
	out.append(["one_landmark", not tower.is_empty() and landmark_seen >= float(PL.get("landmark_seen_min", 0.55)) - 0.001, "tower %.0f m seen from %.0f%% of the lanes" % [float(tower.get("h", 0.0)), landmark_seen * 100.0]])
	# §EG.1 the bones.
	var dn: Array = []
	for d in districts:
		dn.append((d.houses as Array).size())
	var nodes := 0
	for s in squares:
		if s.kind != "void":
			nodes += 1
	var bones: bool = paths.size() >= 3 and wall.size() * 2.5 >= 40.0 and dn.size() == 3 and dn.min() >= 3 and nodes + _junctions() >= 2 and not tower.is_empty()
	out.append(["bones", bones, "paths %d, edge wall %.0f m + the stream, districts %s, nodes %d squares + %d junctions, landmark %s" % [paths.size(), wall.size() * 2.5, str(dn), nodes, _junctions(), "tower" if not tower.is_empty() else "none"]])
	# §EG.2 per view: one dominant; focal points off-centre.
	var hi := _hierarchy()
	out.append(["one_dominant", hi.x >= 0.7 - 1e-4, "%.0f%% of the %d key views have one clear dominant (secondaries <= 3)" % [hi.x * 100.0, key_views().size()]])
	var off_ok := true
	var thirds := 0
	var slot := 0
	for f in focals:
		if int(f.vista) < 0:
			continue
		var v: Dictionary = vistas[int(f.vista)]
		var a := rad_to_deg(absf((v.dir as Vector2).angle_to((f.p as Vector2) - (v.from as Vector2))))
		if a >= 7.5:
			thirds += 1
		else:
			slot += 1
		if a < 2.8 or a > 26.0:
			off_ok = false
	out.append(["focal_off_centre", off_ok, "%d focals on a third (8-22 deg off the axis), %d in a lane's open slot (3-7 deg off), none dead centre" % [thirds, slot]])
	# Balance by weight, not mirroring.
	var sym := symmetry()
	var bal := balance()
	out.append(["no_mirror", sym < 0.4, "best mirror overlap %.2f" % sym])
	out.append(["weight_balance", bal <= 0.35, "weight centre %.2f of the radius off the footprint's centre" % bal])
	# Threes and fives.
	var sizes := {}
	var odd := true
	for g in groups:
		sizes[g.size()] = int(sizes.get(g.size(), 0)) + 1
		if not g.size() in [1, 3, 5]:
			odd = false
	out.append(["threes_and_fives", odd and squares.size() in [1, 3, 5] and districts.size() == 3, "terraces by size %s, squares %d, districts %d" % [str(sizes), squares.size(), districts.size()]])
	# Ma.
	var vok := not void_area.is_empty() and _void_empty()
	out.append(["ma_void", vok, "%s r %.1f m, empty" % [str(void_area.get("kind", "none")), float(void_area.get("r", 0.0))] if vok else "no void"])
	# Materials: counted on the build (VillageBuilder.used); the plan has one of each.
	out.append(["one_material_each", materials.size() == 3, "stone %s, timber %s, roof %s" % [materials.get("stone"), materials.get("timber"), materials.get("roof")]])
	# Hearths lead: one per house; in every square but the void; at vista ends.
	var hh := 0
	var sq := 0
	var vh := 0
	for h in hearths:
		match str(h.kind):
			"house": hh += 1
			"square": sq += 1
			"vista": vh += 1
	out.append(["hearths_lead", hh == houses.size() and sq == nodes and (vh >= 1 or _focal_houses() >= 2), "%d house hearths, %d in squares, %d at vista ends, %d focal houses at vista ends" % [hh, sq, vh, _focal_houses()]])
	# §EG.4 the dead squares lose their refuge.
	var rs := 0
	for si in squares.size():
		if squares[si].kind != "void" and _square_refuge(si) > 0:
			rs += 1
	out.append(["refuge_flip", rs == nodes, "%d of %d squares have a bench to put your back to once lit; brambles cover them while dead (%d strips)" % [rs, nodes, brambles.size()]])
	return out


func _terms_str() -> String:
	var parts: Array = []
	var t: Dictionary = site.get("terms", {})
	for k in t:
		if float(t[k]) > 0.05:
			parts.append("%s %.2f" % [k, float(t[k])])
	return ", ".join(parts)


## Built share of the dry ground inside core_ring_m, and beyond
## edge_ring_m (to the village's reach): tight core, loose edge.
func _density() -> Vector2:
	var R := float(PL.get("radius_m", 78.0))
	var cr := float(PL.get("core_ring_m", 26.0))
	var er := float(PL.get("edge_ring_m", 52.0))
	var built := Vector2.ZERO
	var land := Vector2.ZERO
	for j in range(0, NO, 2):
		for i in range(0, NO, 2):
			var q := Vector2(-E + (i + 0.5) * OCC_M, -E + (j + 0.5) * OCC_M)
			var o := occ[j * NO + i]
			if o == WATER or o == BANK:
				continue
			var dd := q.distance_to(core)
			var b := 1.0 if o == HOUSE or o == TOWER else 0.0
			if dd < cr:
				land.x += 1.0
				built.x += b
			elif dd > er and dd < R:
				land.y += 1.0
				built.y += b
	return Vector2(built.x / maxf(land.x, 1.0), built.y / maxf(land.y, 1.0))


func _junctions() -> int:
	var n := 0
	for p in paths:
		if int(p.junction) > 0:
			n += 1
	return n


## Open width along the lanes (to the nearest building either side, capped
## at 12 m a side): narrow under 7 m, open at 12 m and over; a release is a
## narrow stretch of 4 m or more followed by an open one. (total, main)
func _compress_release() -> Vector2i:
	var total := 0
	var main := 0
	for p in paths:
		var pts: PackedVector2Array = p.pts
		var state := 0 # 0 none, 1 narrow seen
		var run := 0
		var n := 0
		for i in range(1, pts.size() - 1):
			var t := (pts[i + 1] - pts[i - 1]).normalized()
			var nrm := Vector2(-t.y, t.x)
			var w := _side(pts[i], nrm) + _side(pts[i], -nrm)
			if w < 7.0:
				run = run + 1 if state == 1 or run > 0 else 1
				if run >= 4:
					state = 1
			elif w >= 12.0:
				if state == 1:
					n += 1
					state = 0
				run = 0
			else:
				run = 0 if state == 0 else run
		total += n
		if p.kind == "main":
			main += n
	return Vector2i(total, main)


func _side(q: Vector2, nrm: Vector2, trees_too := false) -> float:
	var s := 0.0
	while s < 12.0:
		s += OCC_M
		var o := occ_at(q + nrm * s)
		if o in [HOUSE, TOWER] or (trees_too and o == FOCAL):
			return s
	return 12.0


## Share of a square's rim (rays every 5 degrees) that meets a building
## within 2.5 m beyond it.
func _wrap_share(s: Dictionary) -> float:
	var hit := 0
	for k in 72:
		var d := Vector2.from_angle(k * TAU / 72.0)
		var r := float(s.r)
		var x := r
		while x < r + 2.5:
			x += OCC_M
			if occ_at((s.c as Vector2) + d * x) in [HOUSE, TOWER]:
				hit += 1
				break
	return hit / 72.0


## (longest straight run in any lane, m; least total bend of a lane, deg)
func _bends() -> Vector2:
	var longest := 0.0
	var least := INF
	for p in paths:
		var pts: PackedVector2Array = p.pts
		if pts.size() < 12:
			continue
		var run := 0.0
		var total := 0.0
		var prev := (pts[4] - pts[0]).normalized()
		for i in range(4, pts.size() - 4, 4):
			var t := (pts[i + 4] - pts[i]).normalized()
			var a := rad_to_deg(absf(prev.angle_to(t)))
			total += a
			if a < 2.0:
				run += 4.0
				longest = maxf(longest, run)
			else:
				run = 0.0
			prev = t
		least = minf(least, total)
	return Vector2(longest, least if least < INF else 0.0)


## Share of long views with a near frame (a building within 7 m, off to a
## side), a middle (something 8 m out to most of the way) and a far end.
func _layered() -> float:
	var keys := key_views()
	if keys.is_empty():
		return 0.0
	var ok := 0
	for v in keys:
		if _layered_one(v):
			ok += 1
	return float(ok) / keys.size()


## A near frame (a building within 7 m to a side in the first 5 m), a
## middle (something 8 m out to most of the way) and a far end.
func _layered_one(v: Dictionary) -> bool:
	if true:
		var from: Vector2 = v.from
		var dir: Vector2 = v.dir
		var nrm := Vector2(-dir.y, dir.x)
		var near := false
		for a in [1.0, 3.0, 5.0]:
			if minf(_side(from + dir * a, nrm, true), _side(from + dir * a, -nrm, true)) < 7.0:
				near = true
		var mid := false
		var s := 8.0
		while s < float(v.len) * 0.8:
			var q := from + dir * s
			if minf(_side(q, nrm), _side(q, -nrm)) < 6.0:
				mid = true
				break
			s += 2.0
		var far := str(v.end) != "none"
		return near and mid and far
	return false


## Per long view, what stands ahead as a subject (8 m and more out,
## within 25 degrees, not hidden behind something nearer): houses facing
## the view (a facade turned along the lane is its frame, not a subject:
## §EF.7), the tower, the focals; each weighed by its size seen from here
## and its brightness (a focal or the tower stands out, a focal house a
## little). One dominant when the heaviest is 1.4 times the next and no
## more than three others weigh half as much (§EG.2). (share of views)
func _hierarchy() -> Vector2:
	var keys := key_views()
	if keys.is_empty():
		return Vector2.ZERO
	var ok := 0
	for v in keys:
		if bool(view_dominance(v).ok):
			ok += 1
	return Vector2(float(ok) / keys.size(), 0.0)


## One view's subjects weighed (§EG.2): {ok, w (heaviest first), kinds
## ([weight, "group"/"tower"/"focal", index] heaviest first)}. What stands
## ahead (8 m and more out, within 25 degrees, not hidden behind something
## nearer, and the view's own end always): each terrace as one mass (its
## houses read together: proximity and likeness, gestalt), by its
## silhouette's width times its height over the distance squared; the
## tower and the focals the same, a little brighter. Houses lining the lane
## side-on are its frame (§EF.7), not subjects. Weight falls toward the
## cone's edge (position, Arnheim). One dominant when the heaviest is 1.4
## times the next and no more than three others weigh half as much.
func view_dominance(v: Dictionary) -> Dictionary:
	var from: Vector2 = v.from
	var dir: Vector2 = v.dir
	var perp := Vector2(-dir.y, dir.x)
	var by := {}
	for i in houses.size():
		var h: Dictionary = houses[i]
		var dv: Vector2 = (h.c as Vector2) - from
		var l := dv.length()
		var is_end: bool = str(v.end) == "house" and int(v.hit) == i
		if not is_end:
			if l < 8.0 or rad_to_deg(absf(dir.angle_to(dv))) > 25.0:
				continue
			if absf((h.v as Vector2).dot(dir)) < 0.5 and absf(dv.dot(perp)) < 6.5:
				continue
			if not _visible_obj(from, h.c, HOUSE, i):
				continue
		var sil := float(h.w) * absf((h.u as Vector2).dot(perp)) + float(h.d) * absf((h.v as Vector2).dot(perp))
		var w := sil * house_height(h) / (l * l) * (1.25 if h.focal else 1.0) * _pos_w(dir, dv)
		var g := int(h.group)
		by[g] = float(by.get(g, 0.0)) + w
	var kinds: Array = []
	for g in by:
		kinds.append([float(by[g]), "group", int(g)])
	if not tower.is_empty():
		var dv: Vector2 = (tower.c as Vector2) - from
		var l := dv.length()
		if l >= 8.0 and (rad_to_deg(absf(dir.angle_to(dv))) <= 25.0 or v.end == "tower") and sees_tower(from):
			kinds.append([float(tower.size) * float(tower.h) / (l * l) * 1.4 * _pos_w(dir, dv), "tower", -2])
	for fi in focals.size():
		var f: Dictionary = focals[fi]
		var dv: Vector2 = (f.p as Vector2) - from
		var l := dv.length()
		if l >= 8.0 and rad_to_deg(absf(dir.angle_to(dv))) <= 25.0 and _visible_obj(from, f.p, FOCAL, fi):
			var sz := 1.4 * 2.2 if f.kind != "tree" else 7.0 * 9.0
			kinds.append([sz / (l * l) * 1.5 * _pos_w(dir, dv), "focal", fi])
	kinds.sort_custom(func(x, y): return x[0] > y[0])
	var ws: Array = kinds.map(func(x): return x[0])
	if ws.is_empty():
		return {"ok": false, "w": ws, "kinds": kinds}
	var dom: float = ws[0]
	var second: float = ws[1] if ws.size() > 1 else 0.0
	var others := 0
	for k in range(1, ws.size()):
		if ws[k] >= dom * 0.5:
			others += 1
	return {"ok": dom >= second * 1.4 and others <= 3, "w": ws, "kinds": kinds}


## A house's height to the middle of its roof, about (eave, a focal
## house's raise, an upper storey, half the roof's rise).
func house_height(h: Dictionary) -> float:
	return 2.85 + (0.9 if h.focal else 0.0) + (2.4 if int(h.get("storeys", 1)) == 2 else 0.0) - (0.35 if bool(h.get("quiet", false)) else 0.0) + float(h.d) * 0.375


## The hierarchy pass (§EG.2, iwagumi's main stone): where a key view ends
## on a house that doesn't lead it, that house gains an upper storey, so
## the view has one dominant element.
func _hierarchy_pass() -> void:
	for round_i in 3:
		for v in key_views():
			if bool(view_dominance(v).ok):
				continue
			if str(v.end) == "house":
				var h: Dictionary = houses[int(v.hit)]
				if int(h.get("storeys", 1)) == 1:
					h["storeys"] = 2
					_mark_rect(h.c, h.u, h.v, float(h.w), float(h.d), HOUSE, int(v.hit), ground(h.c) + 7.0)
				elif round_i >= 1:
					# The rest quiet: the strongest rival, a plain house, lies
					# lower (its eave dropped), so the end of the view leads.
					var ks: Array = view_dominance(v).kinds
					var own := int(h.group)
					for k in ks:
						if str(k[1]) == "group" and int(k[2]) != own:
							for hi in groups[int(k[2])]:
								var r: Dictionary = houses[hi]
								if int(r.get("storeys", 1)) == 1 and not bool(r.focal):
									r["quiet"] = true
							break
			elif str(v.end) in ["placed", "focal"]:
				var fi := focal_in_cone(v.from, v.dir, 8.0, float(v.len) + 14.0)
				if fi >= 0 and str(focals[fi].kind) == "shrine":
					focals[fi].kind = "tree"
					trees.append(focals[fi].p)
					_mark_rect(focals[fi].p, Vector2.RIGHT, Vector2.UP, 1.2, 1.2, FOCAL, fi, ground(focals[fi].p) + 9.0)


## Weight by position in the view (Arnheim, villages.json composition
## weight_from): full on the axis, 40% at the cone's edge.
static func _pos_w(dir: Vector2, dv: Vector2) -> float:
	return 1.0 - 0.6 * clampf(rad_to_deg(absf(dir.angle_to(dv))) / 25.0, 0.0, 1.0)


## The key views (§EF.7, §EG.2): the long views that end on something in
## the village (a house, the tower, a focal); views out to borrowed
## scenery are the land's composition, not the village's.
func key_views() -> Array:
	var groups_by := {}
	for v in vistas:
		if not str(v.end) in ["house", "tower", "focal", "placed"]:
			continue
		var key := str(v.end) + ":" + str(v.hit)
		if v.end in ["focal", "placed"]:
			key = "focal:%d" % focal_in_cone(v.from, v.dir, 8.0, float(v.len) + 14.0)
		elif v.end == "tower":
			key = "tower"
		if not groups_by.has(key):
			groups_by[key] = []
		groups_by[key].append(v)
	var out: Array = []
	for k in groups_by:
		# Where you'd stand for it: framed and layered if anywhere is, then
		# the longest look.
		var best: Dictionary = {}
		var best_s := -INF
		for v in groups_by[k]:
			var s := float(v.len) + (100.0 if _layered_one(v) else 0.0)
			if s > best_s:
				best_s = s
				best = v
		out.append(best)
	return out


## Nothing solid between `from` and `to` (to within a metre of it).
func _clear_line(from: Vector2, to: Vector2) -> bool:
	var dv := to - from
	var l := dv.length()
	var dn := dv / maxf(l, 0.001)
	var s := 1.0
	while s < l - 1.0:
		var k := _oi(from + dn * s)
		if k >= 0 and occ[k] in [HOUSE, TOWER, FOCAL]:
			return false
		s += OCC_M
	return true


## Is the object (`kind`, index `idx`) at `to` seen from `from`, nothing
## solid of anything else's in between?
func _visible_obj(from: Vector2, to: Vector2, kind: int, idx: int) -> bool:
	var dv := to - from
	var l := dv.length()
	var dn := dv / maxf(l, 0.001)
	var s := 1.0
	while s < l - 1.0:
		var k := _oi(from + dn * s)
		if k >= 0:
			var o := occ[k]
			if o == HOUSE or o == TOWER or o == FOCAL:
				return o == kind and owner[k] == idx
		s += OCC_M
	return true


## The best overlap of the buildings with their own mirror image, over
## twelve axes through their centre (1 = perfectly mirrored).
func symmetry() -> float:
	var cells := {}
	var cen := Vector2.ZERO
	var n := 0
	for j in range(0, NO, 2):
		for i in range(0, NO, 2):
			var o := occ[j * NO + i]
			if o == HOUSE or o == TOWER:
				var q := Vector2i(i / 2, j / 2)
				cells[q] = true
				cen += Vector2(q)
				n += 1
	if n == 0:
		return 0.0
	cen /= n
	var best := 0.0
	for k in 12:
		var a := k * PI / 12.0
		var ax := Vector2.from_angle(a)
		var inter := 0
		for q in cells:
			var p := Vector2(q) - cen
			var m := ax * p.dot(ax) * 2.0 - p + cen
			if cells.has(Vector2i(roundi(m.x), roundi(m.y))):
				inter += 1
		best = maxf(best, float(inter) / (2.0 * n - inter))
	return best


## How far the buildings' weight centre (footprint x height, the tower
## counted by its height) sits from their footprint's centre, over the
## village radius: small means balanced even though nothing is mirrored.
func balance() -> float:
	var ca := Vector2.ZERO
	var a := 0.0
	var cw := Vector2.ZERO
	var w := 0.0
	for h in houses:
		var ar := float(h.w) * float(h.d)
		ca += (h.c as Vector2) * ar
		a += ar
		var wt := ar * (3.0 + (1.0 if h.focal else 0.0))
		cw += (h.c as Vector2) * wt
		w += wt
	if not tower.is_empty():
		var ar := float(tower.size) * float(tower.size)
		ca += (tower.c as Vector2) * ar
		a += ar
		cw += (tower.c as Vector2) * ar * float(tower.h)
		w += ar * float(tower.h)
	if a == 0.0:
		return 1.0
	return ((cw / w) - (ca / a)).length() / float(PL.get("radius_m", 78.0))


func _void_empty() -> bool:
	if void_area.is_empty():
		return false
	var c: Vector2 = void_area.c
	var r := float(void_area.r)
	for h in hearths:
		if (h.p as Vector2).distance_to(c) < r:
			return false
	for f in focals:
		if (f.p as Vector2).distance_to(c) < r:
			return false
	for e in edges:
		if (e.p as Vector2).distance_to(c) < r:
			return false
	for k in _rect_cells(c, Vector2.RIGHT, Vector2.UP, r * 0.7, r * 0.7):
		if k >= 0 and occ[k] in [HOUSE, TOWER, FOCAL]:
			return false
	return true


func _focal_houses() -> int:
	var n := 0
	for h in houses:
		if h.focal:
			n += 1
	return n


## A square's refuge spots (lit): a bench with a wall at its back and an
## open view of 6 m or more ahead.
func _square_refuge(si: int) -> int:
	var n := 0
	for r in refuge:
		if int(r.square) != si:
			continue
		var p: Vector2 = r.p
		var f: Vector2 = r.facing
		var back := occ_at(p - f * 0.9) in [HOUSE, TOWER]
		var open := true
		for s: float in [2.0, 4.0, 6.0]:
			if occ_at(p + f * s) in [HOUSE, TOWER]:
				open = false
		if back and open:
			n += 1
	return n
