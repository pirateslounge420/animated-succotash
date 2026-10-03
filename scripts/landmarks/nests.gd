class_name Nests
## Nests (design 1 Oct §CK, data/landforms.json): the land's own places
## where people live — this overhang, this plunge pool, this sinkhole rim —
## placed by each landform's cause (rock, water, relief, climate), never by
## a biome name. Tier 1 is built here:
##   cave_mouth          an overhang and a first chamber at a karst or
##                       sandstone cliff foot (an escarpment face or a
##                       ravine wall) with water within 1.5 km;
##   grotto              a low arched mouth in wet karst with a passage back
##                       to a chamber and its drip pool;
##   cenote              a round shaft collapsed to the water table in warm
##                       karst lowland far from rivers (its stamp, Nests.stamp);
##                       the doline in cool karst (a bowl); the blue hole, a
##                       dark round hole in reef shallows (look only);
##   slot_canyon         the ravine layer pinched to a slot in dry sandstone
##                       (TerrainField._cliffs, slot_at): a passage, its hearth
##                       on the rim;
##   waterfall           a fall on the river network with a dry bench below
##                       the pool's tail;
##   ravine              a stretch of a ravine's floor with a river through it;
##   escarpment          a stretch of the escarpment foot under an overhang
##                       with a spring along the foot; on open grass the
##                       buffalo jump (a kill site, cairn lanes to the lip);
##   bioluminescent_bay  a warm lagoon by mangrove that glows where the water
##                       is stirred (MagicSites "bay", water.gdshader).
##
## One candidate per grid cell per kind (the rarity's cell: common ~4 km,
## uncommon ~12 km, rare ~40 km), placed only where the cause holds. Pure
## functions of the planet data and the river network (thread-safe, cached),
## like Ruins, so every visit finds the same nest. A nest gives way to a
## kind before it in KINDS within SPACING_M, and to a monument's footprint.
##
## The camp loop (landforms.json camp_loop): each nest is untouched, lived
## in or holds an old camp's remains, by its own roll: start_budget's "one
## nest in four that gives roof or water holds a living camp, the best
## first, and about half of the rest hold remains" (BUDGET below; the
## shares on four seeds are in PROGRESS, 2 Oct §CK). A camp lives only where
## the nest gives roof or water, fuel is in reach (fuel.json) and the hearth
## spot is clear of the hazard.
##
## Each nest: {"kind", "variant" ("" or doline / blue_hole / buffalo_jump),
## "key" ("nest:<kind>:<cell>"), "cell", "seed", "dir" (the feature),
## "hearth" (the fire's spot, Vector3.ZERO where there is none), "facing"
## (bearing from the hearth toward the feature), "gives", "state"
## (untouched / lived / remains), "footprint_m", "clear" ([dir, radius_m]
## kept free of plants) and the kind's own measurements (cliff_h, radius_m,
## depth_m, pool_m, ...).

const KINDS := ["cenote", "grotto", "cave_mouth", "waterfall", "slot_canyon", "ravine", "escarpment", "bioluminescent_bay"]
## Grid cell per rarity (landforms.json _help.rarity: common one every
## 3-5 km where the cause holds, uncommon 10-15 km, rare 40 km or more).
const CELL_M := {"common": 4000.0, "uncommon": 12000.0, "rare": 40000.0}
## A nest gives way to a kind earlier in KINDS this close to it.
const SPACING_M := 180.0
## Points tried in a cell for a cause.
const TRIES := 40
## Start budget (camp_loop.start_budget, "the best first"): the chance a
## nest holds a living camp by what it gives (roof and water, then water,
## then roof), and of remains among the rest. Tuned so about one in four
## nests that give roof or water hold a camp (PROGRESS, 2 Oct §CK).
const BUDGET := {"roof_water": 0.36, "water": 0.2, "roof": 0.15, "remains": 0.5}
const KARST := PlanetData.Rock.LIMESTONE_KARST
const SANDSTONE := PlanetData.Rock.SANDSTONE

static var D: Dictionary = _load()
static var terrain: TerrainField = null
static var _map: PlanetData = null
static var _rivers: RiverNetwork = null
static var _cache := {}
static var _cell_stamps := {}
static var _mutex := Mutex.new()
static var _fuel: Dictionary = {}


static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/landforms.json"))
	return parsed if parsed is Dictionary else {}


## Wire the nests to a world's planet (World, after the planet and its
## rivers exist; again for every new world). Clears the caches.
static func setup(map: PlanetData, rivers: RiverNetwork) -> void:
	_mutex.lock()
	_map = map
	_rivers = rivers
	_cache.clear()
	_cell_stamps.clear()
	_fuel = Tuning.section("fuel", "biomes")
	terrain = map.terrain if map != null else null
	_mutex.unlock()


static func entry(kind: String) -> Dictionary:
	return (D.get("landforms", {}) as Dictionary).get(kind, {})


static func cell_m(kind: String) -> float:
	return float(CELL_M.get(str(entry(kind).get("rarity", "common")), 4000.0))


## The display name ("Cave mouth / rock shelter", or the variant's).
static func name_of(nest: Dictionary) -> String:
	var e := entry(str(nest.kind))
	var v := str(nest.get("variant", ""))
	if v != "":
		for vv in e.get("variants", []):
			if str(vv.get("id", "")) == v:
				return str(vv.get("name", v))
	return str(e.get("name", nest.kind))


# --- Queries -------------------------------------------------------------------

## The nest of `kind` in grid cell `c`, or {} (none, or given way to
## another). Cached; thread-safe.
static func find(kind: String, c: Vector3i) -> Dictionary:
	var key := [kind, c]
	_mutex.lock()
	var hit = _cache.get(key)
	_mutex.unlock()
	if hit != null:
		_hearth_pass(hit)
		return hit
	var nest := _find_raw(kind, c)
	if not nest.is_empty() and _gives_way(nest):
		nest = {}
	if not nest.is_empty():
		_settle(nest)
	_hearth_pass(nest)
	_mutex.lock()
	_cache[key] = nest
	_mutex.unlock()
	return nest


## The hearths pass (design 3 Oct §CU, Hearths): a nest it doesn't keep
## holds no camp and no remains ("untouched"); its own roll is kept in
## "raw_state" (and "raw_people") for the pass to read.
static func _hearth_pass(nest: Dictionary) -> void:
	if nest.is_empty() or int(nest.get("hv", 0)) == Hearths.version:
		return
	_mutex.lock()
	if not nest.has("raw_state"):
		nest["raw_state"] = str(nest.state)
		nest["raw_people"] = str(nest.get("people", ""))
	var raw := str(nest.raw_state)
	if raw != "untouched" and not Hearths.nest_kept(str(nest.key)):
		nest.state = "untouched"
		nest.erase("people")
	else:
		nest.state = raw
		if str(nest.raw_people) != "":
			nest.people = str(nest.raw_people)
	nest["hv"] = Hearths.version
	_mutex.unlock()


## Nests of `kinds` whose footprint comes within `radius` m of `d`.
static func near(d: Vector3, radius: float, kinds: Array = KINDS) -> Array:
	var out: Array = []
	if _map == null:
		return out
	for kind in kinds:
		var cm := cell_m(kind)
		for c in CreatureSpawner._cells_around(d, radius, cm):
			var n := find(kind, c)
			if not n.is_empty() and CubeSphere.surface_distance_m(n.dir, d) < radius + float(n.footprint_m):
				out.append(n)
	return out


## The nest a camp key names ("nest:<kind>:<cell>"), or {}.
static func by_key(key: String) -> Dictionary:
	if not key.begins_with("nest:"):
		return {}
	var parts := key.split(":", false, 2)
	if parts.size() < 3:
		return {}
	var nums := parts[2].replace("(", "").replace(")", "").split(",")
	if nums.size() < 3:
		return {}
	return find(parts[1], Vector3i(nums[0].strip_edges().to_int(), nums[1].strip_edges().to_int(), nums[2].strip_edges().to_int()))


## [dir, radius_m] circles plants keep out of near `d`.
static func clearings_near(d: Vector3, radius: float) -> Array:
	var out: Array = []
	for n in near(d, radius):
		out.append_array(n.get("clear", []))
	return out


# --- The ground: slot canyons and stamps ------------------------------------------

## 0-1 how much a ravine at `d` is a slot canyon (design 1 Oct §CK
## slot_canyon: the ravine layer through dry sandstone, cause moisture
## 0-0.35): sandstone cells blended over the blueprint's smooth weights, so
## a ravine narrows over a few kilometres where it runs into the sandstone.
static func slot_at(d: Vector3) -> float:
	if _map == null:
		return 0.0
	var w := _map.weights_at(d)
	var cells: PackedInt32Array = w[0]
	var k: PackedFloat32Array = w[1]
	var v := 0.0
	for i in cells.size():
		var c := cells[i]
		if _map.rock[c] == SANDSTONE:
			v += k[i] * smoothstep(0.39, 0.33, _map.moisture[c])
	return smoothstep(0.25, 0.75, v)


## The ground at `d` after the nests' stamps (TerrainField.elevation with
## detail): a cenote's shaft and its fallen-block slope, a doline's bowl.
static func stamp(d: Vector3, e: float) -> float:
	var stamps := _stamps_at(d)
	for n in stamps:
		e = _stamp_one(n, d, e)
	return e


## The standing water a stamp holds at `d` (a cenote's pool, a doline's
## pond), or NAN.
static func pool_at(d: Vector3) -> float:
	for n in _stamps_at(d):
		var pool := float(n.get("pool_m", NAN))
		if is_nan(pool):
			continue
		if CubeSphere.surface_distance_m(n.dir, d) < float(n.radius_m) + 2.0:
			return pool
	return NAN


static func _stamps_at(d: Vector3) -> Array:
	if _map == null:
		return []
	var cell := _map.cell_at(d)
	if _map.rock[cell] != KARST:
		# A stamp may reach a few metres over a cell's edge: the cell's own
		# list includes its neighbours' stamps (below), so only karst cells
		# and their neighbours are looked at.
		var any := false
		for k in 8:
			var nb := _map.neighbors[cell * 8 + k]
			if nb >= 0 and _map.rock[nb] == KARST:
				any = true
				break
		if not any:
			return []
	_mutex.lock()
	var hit = _cell_stamps.get(cell)
	_mutex.unlock()
	if hit == null:
		hit = []
		var cm := cell_m("cenote")
		for c in CreatureSpawner._cells_around(_map.dir[cell], _map.cell_m() * 0.75 + 200.0, cm):
			var n := find("cenote", c)
			if n.is_empty() or str(n.variant) == "blue_hole":
				continue
			hit.append(n)
		_mutex.lock()
		_cell_stamps[cell] = hit
		_mutex.unlock()
	var out: Array = []
	for n in hit:
		if CubeSphere.surface_distance_m(n.dir, d) < float(n.reach_m):
			out.append(n)
	return out


## One stamp's ground at `d` (`e` the ground without it).
static func _stamp_one(n: Dictionary, d: Vector3, e: float) -> float:
	var r := CubeSphere.surface_distance_m(n.dir, d)
	var big_r := float(n.radius_m)
	if str(n.variant) == "doline":
		if r >= big_r:
			return e
		var t := r / big_r
		return e - float(n.depth_m) * pow(1.0 - t * t, 2.0)
	# The cenote: a sheer round shaft to its pool, a fallen-block slope
	# down one side (cut into the rim outside the shaft, heaped inside it).
	var floor_e := float(n.pool_m) - 3.0
	var h := lerpf(floor_e, e, smoothstep(big_r - 1.5, big_r + 1.0, r))
	var off := _bearing(n.dir, d) - float(n.ramp)
	off = absf(wrapf(off, -PI, PI))
	# A talus of fallen blocks, broad (about 50 degrees of the shaft).
	var wa := smoothstep(0.62, 0.36, off) if r > 1.0 else 0.0
	if wa > 0.0:
		var start := big_r * 0.45
		var hr := float(n.pool_m) + 0.3 + (r - start) * tan(deg_to_rad(36.0))
		if r >= start and hr < e:
			h = lerpf(h, maxf(hr, floor_e), wa)
	return h


## Bearing (0 north, PI/2 east) from `a` to `b`.
static func _bearing(a: Vector3, b: Vector3) -> float:
	var t := (b - a * a.dot(b))
	return atan2(t.dot(CubeSphere.east(a)), t.dot(CubeSphere.north(a)))


# --- The sites pass -------------------------------------------------------------

static func _find_raw(kind: String, c: Vector3i) -> Dictionary:
	if _map == null or _map.biome.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([kind, c, _map.terrain.world_seed, "nest"])
	var cm := cell_m(kind)
	var n := CreatureSpawner._cells_per_face(cm)
	var center := CreatureSpawner._cell_point(c, n, 4242)
	var nest := {}
	match kind:
		"cave_mouth", "grotto":
			nest = _cliff_nest(kind, center, cm, rng)
		"escarpment":
			nest = _escarp_nest(center, cm, rng)
		"cenote":
			nest = _cenote(center, cm, rng)
		"slot_canyon", "ravine":
			nest = _ravine_nest(kind, center, cm, rng)
		"waterfall":
			nest = _waterfall(center, cm, rng)
		"bioluminescent_bay":
			nest = _bay(center, cm, rng)
	if nest.is_empty():
		return {}
	nest.kind = kind
	nest.cell = c
	nest.key = "nest:%s:%s" % [kind, str(c)]
	nest.seed = hash([kind, c, _map.terrain.world_seed])
	if not nest.has("variant"):
		nest.variant = ""
	if not nest.has("gives"):
		nest.gives = entry(kind).get("gives", [])
	if not nest.has("hearth"):
		nest.hearth = Vector3.ZERO
	if not nest.has("clear"):
		nest.clear = []
	if (nest.hearth as Vector3) != Vector3.ZERO:
		(nest.clear as Array).append([nest.hearth, 6.0])
	return nest


static func _point(center: Vector3, cm: float, rng: RandomNumberGenerator) -> Vector3:
	return CreatureSpawner._offset(center, rng.randf() * TAU, sqrt(rng.randf()) * cm * 0.5)


static func _e(p: Vector3) -> float:
	return _map.terrain.elevation(p, true, true, false)


## Rise over run across `r` m at `p` (the worse of two axes).
static func _slope(p: Vector3, r: float) -> float:
	var a := absf(_e(CreatureSpawner._offset(p, 0.0, r)) - _e(CreatureSpawner._offset(p, PI, r)))
	var b := absf(_e(CreatureSpawner._offset(p, PI * 0.5, r)) - _e(CreatureSpawner._offset(p, PI * 1.5, r)))
	return maxf(a, b) / (2.0 * r)


static func _in(v: float, range_arr) -> bool:
	if not range_arr is Array or (range_arr as Array).size() < 2:
		return true
	var lo = range_arr[0]
	var hi = range_arr[1]
	return (lo == null or v >= float(lo)) and (hi == null or v <= float(hi))


static func _biome_key(cell: int) -> String:
	var b := _map.biome[cell]
	return BiomeTemplates.KEYS[b] if b >= 0 and b < BiomeTemplates.KEYS.size() else ""


## Distance (m) from `d` to the nearest river reach (INF with none near):
## its water's edge, the reach's width taken off.
static func _river_m(d: Vector3) -> float:
	if _rivers == null:
		return INF
	var best := INF
	for s in _rivers.segments_near(_map, _map.cell_at(d)):
		var dt := _rivers.closest_dt(s, d)
		best = minf(best, dt.x - _rivers.width[s] * 0.5)
	return best


## Water within `m` metres: a river reach, a lake or the sea's edge.
static func _water_within(d: Vector3, m: float) -> bool:
	if _river_m(d) <= m:
		return true
	var cell := _map.cell_at(d)
	for k in 9:
		var c := cell if k == 8 else _map.neighbors[cell * 8 + k]
		if c >= 0 and _map.water[c] == PlanetData.Water.LAKE and CubeSphere.surface_distance_m(_map.dir[c], d) < m + _map.cell_m() * 0.5:
			return true
	return false


## The point where a line's noise crosses 0 near `d` (Newton steps on the
## walking-scale noise), and the noise's gradient there in units per metre
## along (east, north): {"dir", "g"}; {} when it doesn't settle.
static func _snap(d: Vector3, which: String) -> Dictionary:
	var t := _map.terrain
	var p := d
	var g := Vector2.ZERO
	for i in 8:
		var v := t.line_noise(p, which)
		var ve := t.line_noise(CreatureSpawner._offset(p, PI * 0.5, 1.0), which) - v
		var vn := t.line_noise(CreatureSpawner._offset(p, 0.0, 1.0), which) - v
		g = Vector2(ve, vn)
		var g2 := g.length_squared()
		if g2 < 1e-14:
			return {}
		var step := -v * g / g2
		if step.length() > 300.0:
			step = step.normalized() * 300.0
		p = (p + (CubeSphere.east(p) * step.x + CubeSphere.north(p) * step.y) / PlanetConst.RADIUS_M).normalized()
		if absf(v) < 2e-6 and step.length() < 0.2:
			break
	if absf(t.line_noise(p, which)) > 2e-5:
		return {}
	return {"dir": p, "g": g}


static func _wind_bearing(d: Vector3) -> float:
	var w := _map.wind_avg[_map.cell_at(d)]
	if w.length() < 0.01:
		return NAN
	# Where the wind blows FROM.
	return atan2(-w.dot(CubeSphere.east(d)), -w.dot(CubeSphere.north(d)))


static func _fuel_ok(cell: int) -> bool:
	var b = _fuel.get(_biome_key(cell), {})
	if not b is Dictionary:
		return false
	for k in b:
		if float(b[k]) > 0.0:
			return true
	return false


## A cliff for a cave mouth or grotto: an escarpment face, or a ravine
## wall where the floor is dry. {"foot" (on the level ground before the
## face), "face" (the face's foot line), "toward" (bearing from the foot
## into the rock), "h" (m)} or {}.
static func _cliff_at(p: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var t := _map.terrain
	var use_ravine := t.line_mask(p, "escarp") < 0.57 or rng.randf() < 0.35
	if use_ravine and t.line_mask(p, "ravine") >= 0.67:
		var r := _snap(p, "ravine")
		if r.is_empty():
			return {}
		var g: Vector2 = r.g
		var gl := g.length()
		var floor_half := lerpf(TerrainField.RAVINE_FLOOR_N, TerrainField.SLOT_FLOOR_N, slot_at(r.dir)) / gl
		if floor_half < 5.0:
			return {}
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var into := atan2(g.x * side, g.y * side)
		var foot := CreatureSpawner._offset(r.dir, into, floor_half - 2.5)
		var h := _e(CreatureSpawner._offset(r.dir, into, floor_half + 10.0)) - _e(foot)
		return {"foot": foot, "face": CreatureSpawner._offset(r.dir, into, floor_half), "toward": into, "h": h, "line": "ravine"}
	if t.line_mask(p, "escarp") < 0.57:
		return {}
	return _cliff_at_escarp(p)


## A cave mouth or a grotto (landforms.json cave_mouth, grotto).
static func _cliff_nest(kind: String, center: Vector3, cm: float, rng: RandomNumberGenerator) -> Dictionary:
	var e := entry(kind)
	var cause: Dictionary = e.get("cause", {})
	var rocks: Array = cause.get("rock", [])
	var best := {}
	var best_score := -INF
	for i in TRIES:
		var p := _point(center, cm, rng)
		var cell := _map.cell_at(p)
		if _map.water[cell] != PlanetData.Water.NONE:
			continue
		if not rocks.has(PlanetData.soil_name(_map.rock[cell])):
			continue
		if not _in(_map.temp_c[cell], cause.get("temp_c")) or not _in(_map.moisture[cell], cause.get("moisture")):
			continue
		var cl := _cliff_at(p, rng)
		if cl.is_empty() or float(cl.h) < 8.0:
			continue
		var foot: Vector3 = cl.foot
		# Level, dry ground before the face, above any river's flood.
		var out_dir := float(cl.toward) + PI
		var floor_c := CreatureSpawner._offset(foot, out_dir, 4.0)
		if _slope(floor_c, 3.0) > 0.18:
			continue
		var rm := _river_m(floor_c)
		if rm < 25.0:
			continue
		# Water within a short walk: a river or lake, or (cause.other) a
		# spring at the foot where the plateau's water comes out, on an
		# escarpment face. A ravine wall with neither gives no water.
		var wet := kind == "grotto" or _water_within(floor_c, float((cause.get("river_km", [0, 1.5]) as Array)[1]) * 1000.0)
		cl.water = "near" if wet else ("spring" if str(cl.line) == "escarp" else "")
		var score := rng.randf() + float(cl.h) * 0.05 + (0.5 if cl.water != "" else 0.0)
		var wb := _wind_bearing(foot)
		if not is_nan(wb):
			# The mouth faces away from the prevailing wind.
			score += 0.6 * cos(wrapf(out_dir - (wb + PI), -PI, PI))
		if score > best_score:
			best_score = score
			best = cl
	if best.is_empty():
		return {}
	var foot2: Vector3 = best.foot
	var toward := float(best.toward)
	var out := toward + PI
	var size: Array = e.get("size_m", [8, 30])
	var width := rng.randf_range(float(size[0]), float(size[1])) if kind == "cave_mouth" else rng.randf_range(3.5, 6.0)
	var nest := {"dir": best.face, "foot": foot2, "toward": toward, "cliff_h": float(best.h), "width_m": width}
	if kind == "cave_mouth":
		# The roof: 3-8 m up, overhanging 4-12 m; the fire 2-3 m back from
		# the drip line, under it (landforms.json hearth_spot; §CK moves the
		# old cliff-shelter fire a pace or two in from the drip line).
		var over := rng.randf_range(5.0, 9.0)
		nest.overhang_m = over
		nest.roof_m = clampf(float(best.h) * 0.45, 3.2, 6.5)
		nest.hearth = CreatureSpawner._offset(best.face, out, over - 2.5)
		nest.footprint_m = maxf(width, over) * 0.75 + 4.0
		nest.clear = [[CreatureSpawner._offset(best.face, out, over * 0.5), maxf(width * 0.5, over * 0.6)]]
	else:
		# The grotto: the mouth, a passage back 10-40 m (size_m) to the
		# chamber and its pool, built out from the cliff in raw rock (the
		# barrow passage's shape); the fire just inside the mouth.
		var depth := rng.randf_range(float(size[0]), float(size[1]))
		depth = clampf(depth, 10.0, 22.0)
		nest.passage_m = depth
		nest.footprint_m = depth + 6.0
		var mouth := CreatureSpawner._offset(best.face, out, depth)
		nest.mouth = mouth
		nest.hearth = CreatureSpawner._offset(mouth, toward, 2.5)
		nest.clear = [[CreatureSpawner._offset(best.face, out, depth * 0.5), depth * 0.5 + 4.0]]
	nest.facing = toward
	if str(best.water) == "spring":
		var along := toward + PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0)
		nest.spring = CreatureSpawner._offset(CreatureSpawner._offset(best.face, along, width * 0.5 + rng.randf_range(6.0, 14.0)), out, 2.0)
		(nest.clear as Array).append([nest.spring, 3.5])
	elif str(best.water) == "":
		var g: Array = (e.get("gives", []) as Array).duplicate()
		g.erase("water")
		nest.gives = g
	return nest


## A stretch of the escarpment foot with level ground (landforms.json
## escarpment; buffalo_jump on open grass).
static func _escarp_nest(center: Vector3, cm: float, rng: RandomNumberGenerator) -> Dictionary:
	var e := entry("escarpment")
	var best := {}
	var best_score := -INF
	for i in TRIES:
		var p := _point(center, cm, rng)
		var cell := _map.cell_at(p)
		if _map.water[cell] != PlanetData.Water.NONE or _map.terrain.line_mask(p, "escarp") < 0.57:
			continue
		var cl := _cliff_at_escarp(p)
		if cl.is_empty() or float(cl.h) < 8.0:
			continue
		var out := float(cl.toward) + PI
		var fire := CreatureSpawner._offset(cl.foot, out, 4.0)
		if _slope(fire, 3.0) > 0.15 or _river_m(fire) < 25.0:
			continue
		var score := rng.randf() + float(cl.h) * 0.05
		if score > best_score:
			best_score = score
			best = cl
	if best.is_empty():
		return {}
	var foot: Vector3 = best.foot
	var toward := float(best.toward)
	var out2 := toward + PI
	var cell2 := _map.cell_at(foot)
	var nest := {"dir": best.face, "foot": foot, "toward": toward, "cliff_h": float(best.h), "facing": toward}
	var bj := {}
	for v in e.get("variants", []):
		if str(v.get("id", "")) == "buffalo_jump":
			bj = v
	var bc: Dictionary = bj.get("cause", {})
	if not bj.is_empty() and (bj.get("biomes", []) as Array).has(_biome_key(cell2)) \
			and _in(_map.temp_c[cell2], bc.get("temp_c")) and _in(_map.moisture[cell2], bc.get("moisture")):
		# The buffalo jump: a kill site, not a shelter. The camp on the flat
		# below by the butchering ground; cairn lanes narrow to the lip.
		nest.variant = "buffalo_jump"
		nest.hearth = CreatureSpawner._offset(foot, out2, 16.0)
		nest.gives = ["water", "food", "lee", "lookout"]
		nest.footprint_m = 40.0
		nest.clear = [[CreatureSpawner._offset(foot, out2, 9.0), 8.0]]
	else:
		# Under the overhang, a pace or two back from the drip line.
		var over := rng.randf_range(5.0, 7.5)
		nest.overhang_m = over
		nest.roof_m = clampf(float(best.h) * 0.45, 3.2, 6.0)
		nest.width_m = rng.randf_range(10.0, 18.0)
		nest.hearth = CreatureSpawner._offset(best.face, out2, over - 2.0)
		nest.footprint_m = 16.0
		nest.clear = [[CreatureSpawner._offset(best.face, out2, over * 0.5), 7.0]]
	# The spring where the plateau's water comes out, along the foot.
	var along := toward + PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0)
	nest.spring = CreatureSpawner._offset(CreatureSpawner._offset(foot, along, rng.randf_range(12.0, 22.0)), out2, 2.5)
	(nest.clear as Array).append([nest.spring, 3.5])
	return nest


static func _cliff_at_escarp(p: Vector3) -> Dictionary:
	var s := _snap(p, "escarp")
	if s.is_empty():
		return {}
	var gs: Vector2 = s.g
	var into_e := atan2(gs.x, gs.y)
	var face_half := 0.0012 / gs.length()
	var face := CreatureSpawner._offset(s.dir, into_e + PI, face_half)
	var foot := CreatureSpawner._offset(face, into_e + PI, 1.0)
	var h := _e(CreatureSpawner._offset(s.dir, into_e, face_half + 4.0)) - _e(foot)
	return {"foot": foot, "face": face, "toward": into_e, "h": h, "line": "escarp"}


## A cenote (warm karst lowland, no river within 3 km), a doline (cool
## karst), or a blue hole (karst drowned in reef shallows: look only).
static func _cenote(center: Vector3, cm: float, rng: RandomNumberGenerator) -> Dictionary:
	var e := entry("cenote")
	var cause: Dictionary = e.get("cause", {})
	var variants := {}
	for v in e.get("variants", []):
		variants[str(v.get("id", ""))] = v
	for i in TRIES:
		var p := _point(center, cm, rng)
		var cell := _map.cell_at(p)
		if _map.rock[cell] != KARST:
			continue
		var t := _map.temp_c[cell]
		var ground := _e(p)
		if _map.water[cell] == PlanetData.Water.OCEAN or ground < 0.0:
			# The blue hole: karst drowned inside a reef or lagoon.
			var bh: Dictionary = variants.get("blue_hole", {})
			var depth := -ground
			var bdepth: Array = (bh.get("cause", {}) as Dictionary).get("depth_m", [2, 30])
			if bh.is_empty() or not (bh.get("biomes", []) as Array).has(_biome_key(cell)):
				continue
			if depth < float(bdepth[0]) * PlanetConst.HEIGHT_SCALE or depth > float(bdepth[1]) * PlanetConst.HEIGHT_SCALE:
				continue
			var r := rng.randf_range(20.0, 45.0)
			return {"dir": p, "variant": "blue_hole", "radius_m": r, "reach_m": 0.0, "footprint_m": r,
				"gives": ["landmark"], "facing": 0.0}
		if _map.water[cell] != PlanetData.Water.NONE:
			continue
		if _slope(p, 15.0) > 0.1:
			continue
		var size: Array = e.get("size_m", [15, 60])
		if _in(t, cause.get("temp_c")):
			if not _in(_map.moisture[cell], cause.get("moisture")):
				continue
			var em: Array = cause.get("elevation_m", [0, 400])
			if ground < float(em[0]) * PlanetConst.HEIGHT_SCALE or ground > float(em[1]) * PlanetConst.HEIGHT_SCALE:
				continue
			if _river_m(p) < 3000.0 or _water_within(p, 3000.0):
				continue
			var dm: Array = e.get("depth_m", [5, 25])
			var depth2 := rng.randf_range(float(dm[0]), float(dm[1]))
			depth2 = minf(depth2, ground - 0.5)
			if depth2 < float(dm[0]):
				continue
			var r2 := rng.randf_range(float(size[0]), float(size[1])) * 0.5
			var ramp := rng.randf() * TAU
			var lout := maxf(0.0, (depth2 + 3.0) / tan(deg_to_rad(36.0)) - (r2 - r2 * 0.45))
			# On the rim above the slope, a few metres back, upwind of the drop.
			var side := 0.5
			var wb := _wind_bearing(p)
			if not is_nan(wb) and cos(wrapf(ramp - 0.5 - wb, -PI, PI)) > cos(wrapf(ramp + 0.5 - wb, -PI, PI)):
				side = -0.5
			var hearth := CreatureSpawner._offset(p, ramp + side, r2 + 5.0)
			return {"dir": p, "radius_m": r2, "depth_m": depth2, "pool_m": ground - depth2, "rim_m": ground,
				"ramp": ramp, "ramp_out_m": lout, "reach_m": r2 + lout + 4.0, "hearth": hearth,
				"footprint_m": r2 + lout + 4.0, "clear": [[p, r2 + 2.0]], "facing": ramp + PI}
		var dl: Dictionary = variants.get("doline", {})
		if not dl.is_empty() and _in(t, (dl.get("cause", {}) as Dictionary).get("temp_c")):
			var r3 := rng.randf_range(15.0, 35.0)
			var depth3 := rng.randf_range(3.5, 7.0)
			var nest := {"dir": p, "variant": "doline", "radius_m": r3, "depth_m": depth3, "reach_m": r3 + 1.0,
				"footprint_m": r3, "facing": 0.0}
			if rng.randf() < 0.5:
				# Dry, its floor gardened; or holding a pond.
				nest.pool_m = ground - depth3 + 0.9
				nest.gives = ["water"]
			else:
				nest.gives = ["lee"]
			var a := rng.randf() * TAU
			nest.hearth = CreatureSpawner._offset(p, a, r3 + 4.0)
			nest.facing = a + PI
			return nest
	return {}


## A ravine stretch with a river through it, or a slot canyon in dry
## sandstone (landforms.json ravine, slot_canyon).
static func _ravine_nest(kind: String, center: Vector3, cm: float, rng: RandomNumberGenerator) -> Dictionary:
	var t := _map.terrain
	var e := entry(kind)
	var cause: Dictionary = e.get("cause", {})
	var rocks: Array = cause.get("rock", [])
	for i in TRIES:
		var p := _point(center, cm, rng)
		var cell := _map.cell_at(p)
		if _map.water[cell] != PlanetData.Water.NONE or not rocks.has(PlanetData.soil_name(_map.rock[cell])):
			continue
		if not _in(_map.temp_c[cell], cause.get("temp_c")) or not _in(_map.moisture[cell], cause.get("moisture")):
			continue
		if t.line_mask(p, "ravine") < 0.67:
			continue
		var slot := slot_at(p)
		if (kind == "slot_canyon") != (slot > 0.7):
			continue
		var r := _snap(p, "ravine")
		if r.is_empty():
			continue
		var d: Vector3 = r.dir
		var g: Vector2 = r.g
		var gl := g.length()
		var across := atan2(g.x, g.y)
		var rim_half := lerpf(TerrainField.RAVINE_RIM_N, TerrainField.SLOT_RIM_N, slot) / gl
		var depth := _e(CreatureSpawner._offset(d, across, rim_half + 6.0)) - _e(d)
		if depth < 8.0:
			continue
		if kind == "slot_canyon":
			# A passage: the hearth on the rim beside it, never in the bed.
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var hearth := CreatureSpawner._offset(d, across + (0.0 if side > 0.0 else PI), rim_half + 9.0)
			if _slope(hearth, 3.0) > 0.2:
				continue
			return {"dir": d, "hearth": hearth, "facing": across + (PI if side > 0.0 else 0.0), "depth_m": depth,
				"floor_half_m": TerrainField.SLOT_FLOOR_N / gl, "footprint_m": rim_half + 12.0,
				"seep": CreatureSpawner._offset(d, across + (PI if side > 0.0 else 0.0), TerrainField.SLOT_FLOOR_N / gl * 0.8)}
		# The ravine: water on the floor, a river through it (a gorge), or
		# else a spring at a widening (landforms.json ravine notes: "a
		# spring the stamp adds at a widening").
		var rm := _river_m(d)
		var floor_half := TerrainField.RAVINE_FLOOR_N / gl
		if floor_half < 6.0:
			continue
		var best_h := Vector3.ZERO
		# The wall that faces the sun (the poleward wall): the fire a few
		# metres out from its foot, a metre over the stream.
		var pole := 0.0 if CubeSphere.latitude(d) >= 0.0 else PI
		var pole_side := 1.0 if cos(wrapf(across - pole, -PI, PI)) >= 0.0 else -1.0
		for side2: float in [pole_side, -pole_side]:
			var hp := CreatureSpawner._offset(d, across if side2 > 0.0 else across + PI, floor_half * 0.6)
			if _river_m(hp) < 6.0 or _slope(hp, 2.5) > 0.2:
				continue
			best_h = hp
			break
		if best_h == Vector3.ZERO:
			continue
		var rv := {"dir": d, "hearth": best_h, "facing": across, "depth_m": depth, "footprint_m": floor_half + 14.0}
		if rm > 150.0:
			var along2 := across + PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0)
			rv.spring = CreatureSpawner._offset(d, along2, rng.randf_range(10.0, 18.0))
			rv.clear = [[rv.spring, 3.5]]
		return rv
	return {}


## A waterfall with a dry bench below its pool (landforms.json waterfall):
## the tallest fall on the reaches through this cell.
static func _waterfall(center: Vector3, cm: float, rng: RandomNumberGenerator) -> Dictionary:
	if _rivers == null:
		return {}
	var segs := {}
	for i in 9:
		var p := _point(center, cm, rng) if i > 0 else center
		for s in _rivers.segments_near(_map, _map.cell_at(p)):
			segs[s] = true
	var best := []
	var best_drop := 0.0
	for s in segs:
		for f in _rivers.falls(s):
			var fd := _rivers.a[s].slerp(_rivers.b[s], float(f[0]))
			if CubeSphere.surface_distance_m(fd, center) > cm * 0.75:
				continue
			var drop := float(f[1]) - float(f[2])
			if drop > best_drop:
				best_drop = drop
				best = [s, f, fd]
	if best.is_empty():
		return {}
	var seg: int = best[0]
	var fall: Array = best[1]
	var fdir: Vector3 = best[2]
	var down := _bearing(_rivers.a[seg], _rivers.b[seg])
	var half := _rivers.width[seg] * 0.5
	var low := float(fall[2])
	# The first dry, level bench 20-40 m below the plunge, out of the spray,
	# a metre or more over the water.
	var hearth := Vector3.ZERO
	for along: float in [30.0, 24.0, 38.0]:
		var tail := CreatureSpawner._offset(fdir, down, along)
		for side: float in [1.0, -1.0]:
			for out_m: float in [8.0, 12.0, 16.0]:
				var hp := CreatureSpawner._offset(tail, down + side * PI * 0.5, half + out_m)
				if _e(hp) < low + 1.0 or _slope(hp, 2.5) > 0.18:
					continue
				hearth = hp
				break
			if hearth != Vector3.ZERO:
				break
		if hearth != Vector3.ZERO:
			break
	var nest := {"dir": fdir, "drop_m": best_drop, "segment": seg, "footprint_m": 40.0, "facing": down + PI}
	if hearth != Vector3.ZERO:
		nest.hearth = hearth
		nest.facing = _bearing(hearth, fdir)
	# The spray: where its own plants grow (§CM), on both banks beside the
	# plunge, in the mist.
	var plunge := CreatureSpawner._offset(fdir, down, 6.0)
	nest.spray = [CreatureSpawner._offset(plunge, down + PI * 0.5, half + 4.0), CreatureSpawner._offset(plunge, down - PI * 0.5, half + 4.0)]
	return nest


## The bioluminescent bay: a warm lagoon by mangrove, salt or brackish,
## joined to the sea by a narrow mouth (few open-sea neighbours).
static func _bay(center: Vector3, cm: float, rng: RandomNumberGenerator) -> Dictionary:
	var e := entry("bioluminescent_bay")
	var cause: Dictionary = e.get("cause", {})
	var biomes: Array = e.get("biomes", [])
	var tried := {}
	for i in TRIES:
		var p := _point(center, cm, rng)
		var cell := _map.cell_at(p)
		if tried.has(cell):
			continue
		tried[cell] = true
		var key := _biome_key(cell)
		if key != "LAGOON" and key != "ESTUARY":
			continue
		if not _in(_map.temp_c[cell], cause.get("temp_c")) or not _in(_map.moisture[cell], cause.get("moisture")):
			continue
		if _map.salinity[cell] == PlanetData.Salinity.FRESH:
			continue
		var mangrove := 0
		var open_sea := 0
		for k in 8:
			var nb := _map.neighbors[cell * 8 + k]
			if nb < 0:
				continue
			var nk := _biome_key(nb)
			if nk == "MANGROVE":
				mangrove += 1
			elif _map.water[nb] == PlanetData.Water.OCEAN and not biomes.has(nk):
				open_sea += 1
		if mangrove == 0 or open_sea > 2:
			continue
		# The bay: shallow water in the cell beside firm ground; the hearth
		# on the first firm ground above the highest water.
		for j in 30:
			var q := CreatureSpawner._offset(_map.dir[cell], rng.randf() * TAU, sqrt(rng.randf()) * _map.cell_m() * 0.45)
			var qe := _e(q)
			if qe > -0.3 or qe < -4.0:
				continue
			for k in 12:
				var a := k * TAU / 12.0
				var hp := CreatureSpawner._offset(q, a, rng.randf_range(160.0, 320.0))
				var he := _e(hp)
				if he < 0.9 or he > 6.0 or _slope(hp, 2.5) > 0.15:
					continue
				var size: Array = e.get("size_m", [150, 800])
				var r := rng.randf_range(float(size[0]), float(size[1])) * 0.5
				return {"dir": q, "radius_m": r, "hearth": hp, "facing": _bearing(hp, q), "footprint_m": r}
	return {}


# --- Resolution and the camp loop ----------------------------------------------------

## A nest gives way to a kind earlier in KINDS within SPACING_M, and to a
## monument's footprint (Ruins).
static func _gives_way(nest: Dictionary) -> bool:
	var i := KINDS.find(str(nest.kind))
	var d: Vector3 = nest.dir
	for j in i:
		var k: String = KINDS[j]
		for c in CreatureSpawner._cells_around(d, SPACING_M, cell_m(k)):
			var o := find(k, c)
			if not o.is_empty() and CubeSphere.surface_distance_m(o.dir, d) < SPACING_M:
				return true
	var spot: Vector3 = nest.hearth if (nest.hearth as Vector3) != Vector3.ZERO else d
	for r in Ruins.near(_map, spot, 60.0):
		if CubeSphere.surface_distance_m(r.dir, spot) < float(r.footprint_m) + 40.0:
			return true
	return false


## The nest's stage in the camp loop (untouched / lived / remains) and,
## for a camp, its people.
static func _settle(nest: Dictionary) -> void:
	var gives: Array = nest.gives
	var roof := gives.has("roof")
	var water := gives.has("water")
	var hearth: Vector3 = nest.hearth
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([nest.seed, "camp_loop"])
	var p_live := 0.0
	if hearth != Vector3.ZERO and (roof or water) and _fuel_ok(_map.cell_at(hearth)):
		p_live = float(BUDGET.roof_water if roof and water else (BUDGET.water if water else BUDGET.roof))
	var roll := rng.randf()
	if roll < p_live:
		nest.state = "lived"
	elif hearth != Vector3.ZERO and not (entry(str(nest.kind)).get("remains", []) as Array).is_empty() and rng.randf() < float(BUDGET.remains):
		nest.state = "remains"
	else:
		nest.state = "untouched"
	if nest.state != "untouched":
		nest.people = Peoples.pick(_map, _rivers, hearth, "nest", nest)


## The nest a hearth spot belongs to (within `within_m`), or {}.
static func at_hearth(d: Vector3, within_m := 20.0) -> Dictionary:
	for n in near(d, within_m + 60.0):
		var h: Vector3 = n.hearth
		if h != Vector3.ZERO and CubeSphere.surface_distance_m(h, d) <= within_m:
			return n
	return {}


## The remains' signatures (§BQ) for a nest: the people's own that suit
## the nest (its remains list), else the list's own from any people file.
static func remains_signatures(nest: Dictionary) -> Array:
	var want: Array = entry(str(nest.kind)).get("remains", [])
	var people := Peoples.get_people(str(nest.get("people", "")))
	var out: Array = []
	for sig in (people.get("ruin", {}) as Dictionary).get("signatures", []):
		if want.has(str(sig.get("id", ""))):
			out.append(sig)
	if out.is_empty():
		for id in want:
			var sig := Peoples.signature(str(id))
			if not sig.is_empty():
				out.append(sig)
			if out.size() >= 2:
				break
	return out


## The F3 overlay's line: the nearest nests within 3 km, with their stage
## and people ("Nests: cave mouth 240 m NE · lived, karst folk | ...").
static func overlay_text(d: Vector3) -> String:
	if _map == null:
		return ""
	var list := near(d, 3000.0)
	if list.is_empty():
		return "\nNests: none within 3 km"
	list.sort_custom(func(a, b): return CubeSphere.surface_distance_m(a.dir, d) < CubeSphere.surface_distance_m(b.dir, d))
	var parts: Array = []
	for n in list.slice(0, 3):
		var m := CubeSphere.surface_distance_m(n.dir, d)
		var dist := "%.0f m" % m if m < 1000.0 else "%.1f km" % (m / 1000.0)
		var b := fposmod(rad_to_deg(_bearing(d, n.dir)) + 22.5, 360.0)
		var compass: String = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][int(b / 45.0) % 8]
		var stage := str(n.state)
		if n.has("people"):
			stage += ", " + Peoples.name_of(Peoples.get_people(str(n.people))).to_lower()
		parts.append("%s %s %s · %s" % [name_of(n).to_lower(), dist, compass, stage])
	return "\nNests: " + " | ".join(parts)


static var _by_binomial := {}


## A plant species by its binomial ("Adiantum capillus-veneris"), or null.
static func species_of(binomial: String) -> PlantSpecies:
	_mutex.lock()
	if _by_binomial.is_empty():
		for sp in SpeciesDB.all():
			var b := sp.binomial()
			if not _by_binomial.has(b):
				_by_binomial[b] = sp
	var sp2: PlantSpecies = _by_binomial.get(binomial, null)
	_mutex.unlock()
	return sp2


## Where a nest's own plants grow (§CM): [[centre, radius_m, count,
## moisture], ...] — a grotto's mouth and its drip pool, a waterfall's
## spray, a slot canyon's seep. Wadi and mesa alcoves wait for those nests.
static func plant_spots(n: Dictionary) -> Array:
	match str(n.kind):
		"grotto":
			var out := []
			if n.has("mouth"):
				out.append([n.mouth, 4.5, 16, 0.85])
			out.append([CreatureSpawner._offset(n.dir, float(n.toward) + PI, 1.8), 2.2, 6, 0.95])
			return out
		"waterfall":
			var out2 := []
			for sp in n.get("spray", []):
				out2.append([sp, 5.0, 12, 0.95])
			return out2
		"slot_canyon":
			if n.has("seep"):
				return [[n.seep, 1.6, 6, 0.9]]
	return []
