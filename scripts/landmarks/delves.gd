class_name Delves
extends Node
## Delves (design 1 Oct §CJ: "every ruin is a delve"; the first built is
## the barrow's). A barrow in stone or snow country (Ruins.Kind.BARROW,
## not the desert's mastaba nor a marsh barrow) leads down into one,
## assembled from the site's seed out of a kit of pieces, each a straight
## lane of the barrow's own frame (RuinBuilder's x across, z along):
##
##   passage     the portal's slab passage, one pair of side cells
##   chamber     the end chamber, the stairhead: the dead's lamps
##               (lit while the barrow's hearth burns), a stair going down
##   stair       down at 32 degrees under the mound and on, well below the
##               ground (COVER_M of earth over every ceiling)
##   room        the first room: an old hearth to rekindle (the delve's one
##               safe room, OldHearths) and one feature (bone niches, or a
##               fallen slab)
##   stair       down again, to one side
##   heart       the deepest room: the dead laid out, ochre on the
##               ceiling, a moss glow, and the find (a spear or a bow,
##               §AW) lying by them, taken once
##   exit        a stair up at 30 degrees, away from the heart, to
##   cairn       a small long cairn beyond the barrow: its chamber, and a
##               slab door that opens only from inside (Skyrim's loop: you
##               never walk the whole thing back), saved per world
##
## The ground is a heightfield drawn in 4 m quads (TerrainChunk), so the
## delve goes down through holes cut in it only where something built
## hides them: under the barrow's chamber and under the cairn (holes_near;
## the barrow and the cairn are turned to the ground's grid, so a hole
## opens at most QUAD_PAD past its rectangle). Every floor is paved stone
## with collision; under the open ground the delve lies deep enough that
## the ground never reaches it.
##
## Inside it is full dark: underground (0-1, eased) turns off the sun and
## the moon (SkySystem), the bed's outdoor sounds give way to a low drone
## and drips (SoundBed), and the dark closes in as at night (Dread), with
## your torch holding it back. The danger is the dark, never a fight.
## No puzzle doors or traps (Mike, 2 Oct: perhaps later).

const SLOPE := 0.625 # tan 32 degrees: the stairs down
const EXIT_SLOPE := 0.577 # tan 30 degrees: the way out
const COVER_M := 1.6
## The way out's earth over its ceiling, at least, short of the cairn.
const EXIT_COVER_M := 0.6
const WALL := 0.6
const SLAB := 0.5
const H_STAIR := 2.4
const H_ROOM := 3.0
const H_HEART := 3.6
## How far past a hole's rectangle the ground's quads may open (one ~4.1 m
## quad, the frame turned to the grid; a little more for the grid's skew).
const QUAD_PAD := 4.6

static var _map: PlanetData
static var _rivers: RiverNetwork
static var _mutex := Mutex.new()
static var _layouts := {}
static var _sites := {}

## 0-1, eased: how far underground the player is (SkySystem, SoundBed,
## Dread). `inside`: in a delve's pieces right now (the player's ground
## and water rules stand aside).
static var underground := 0.0
static var inside := false
## The delve the player is in: its ruin node and layout ({} outside).
static var current_ruin: Node3D = null
static var current: Dictionary = {}
static var instance: Delves = null


static func setup_world(map: PlanetData, rivers: RiverNetwork = null) -> void:
	_mutex.lock()
	_map = map
	_rivers = rivers
	_layouts.clear()
	_sites.clear()
	_mutex.unlock()


static func has_delve(site: Dictionary) -> bool:
	if site.is_empty() or site.get("kind") is String:
		return false
	# The crag fortress's delve climbs (design 3 Oct §DO).
	if int(site.kind) == Ruins.Kind.CRAG_FORTRESS:
		return true
	# The temple city walks inward to its sanctum (§DR.3: the barrow kit).
	if int(site.kind) == Ruins.Kind.TEMPLE_CITY:
		return true
	# The long wall's gate tower: down into its vaults (§DS.1: the barrow
	# kit, its way out a postern on the far side).
	if int(site.kind) == Ruins.Kind.LONG_WALL and not site.has("piece"):
		return true
	# The carved cliffs' rock-cut tombs (§DS.2: in through the middle
	# facade's door, the deepest tomb the heart, a shaft up to the rim).
	if int(site.kind) == Ruins.Kind.CARVED_CLIFFS:
		return true
	# The cliff dwelling: down from the great kiva to the stores cut into
	# the alcove's back, a way up to its rim (§DS.4).
	if int(site.kind) == Ruins.Kind.CLIFF_DWELLING:
		return true
	# The brick city: the vaulted stores under the palace mound (§DS.6).
	if int(site.kind) == Ruins.Kind.BRICK_CITY:
		return true
	# The stone circle: a souterrain where its seed gives one (§DS.7: the
	# one kind allowed none).
	if int(site.kind) == Ruins.Kind.STONE_CIRCLE:
		return bool(site.get("souterrain", false))
	# The stone heads: the quarry's cave in the hill behind (§DS.3).
	if int(site.kind) == Ruins.Kind.STONE_HEADS:
		return true
	# The terraced pueblo: down from the great kiva to the stores (§DS.5).
	if int(site.kind) == Ruins.Kind.TERRACED_PUEBLO:
		return true
	# The hewn temple's halls in its court's wall (§DZ); the hanging
	# gardens' galleries under their terraces (§DT).
	if int(site.kind) in [Ruins.Kind.HEWN_TEMPLE, Ruins.Kind.HANGING_GARDENS]:
		return true
	# The abbey's crypt and undercroft under its east end (§DU).
	if int(site.kind) == Ruins.Kind.ABBEY:
		return true
	# The northern styles (§DS): the tower house's undercroft and pit
	# prison under its keep, a postern out; the broch's souterrain.
	if int(site.kind) == Ruins.Kind.CASTLE and str(site.get("style", "")) == "tower_house":
		return true
	if int(site.kind) == Ruins.Kind.TOWER and str(site.get("style", "")) == "broch":
		return true
	return int(site.kind) == Ruins.Kind.BARROW and str(site.get("style", "")) in ["stone", "snow"]


# --- The frame ----------------------------------------------------------------

## The site's frame as RuinBuilder.compute makes it, base_e without stamps.
static func frame(map: PlanetData, site: Dictionary) -> Dictionary:
	var up: Vector3 = site.dir
	var a: float = site.heading + PI * 0.5
	var ex := CubeSphere.north(up) * cos(a) + CubeSphere.east(up) * sin(a)
	var ez := ex.cross(up).normalized()
	return {"up": up, "ex": ex, "ez": ez, "base_e": map.terrain.elevation(up, true, true, false)}


static func to_dir(fr: Dictionary, x: float, z: float) -> Vector3:
	return ((fr.up as Vector3) + ((fr.ex as Vector3) * x + (fr.ez as Vector3) * z) / PlanetConst.RADIUS_M).normalized()


static func to_local(fr: Dictionary, d: Vector3) -> Vector2:
	var upv: Vector3 = fr.up
	var rel: Vector3 = d / maxf(d.dot(upv), 1e-6) - upv
	return Vector2(rel.dot(fr.ex as Vector3), rel.dot(fr.ez as Vector3)) * PlanetConst.RADIUS_M


static func _g0(map: PlanetData, fr: Dictionary, x: float, z: float) -> float:
	return map.terrain.elevation(to_dir(fr, x, z), true, true, false) - float(fr.base_e)


## A barrow's heading turned to the nearest of the ground grid's four
## directions (so a hole opens at most one quad past its rectangle).
static func grid_heading(d: Vector3, heading: float) -> float:
	var f := CubeSphere.face_of(d)
	var uv := CubeSphere.face_uv(f, d)
	var du := CubeSphere.to_dir(f, uv.x + 1e-4, uv.y) - CubeSphere.to_dir(f, uv.x, uv.y)
	var bearing := atan2(du.dot(CubeSphere.east(d)), du.dot(CubeSphere.north(d)))
	# ex's bearing is heading + PI/2; snap it to bearing + k * PI/2.
	var want := heading + PI * 0.5
	var k := roundf((want - bearing) / (PI * 0.5))
	return bearing + k * PI * 0.5 - PI * 0.5


# --- Pieces -----------------------------------------------------------------------

## A piece: a straight lane from `c` (the middle of its start edge, local
## x/z) along `dir` (a unit axis) for `len`, `half` wide each side, the
## floor from y0 at the start to y1 at the end (local y, base_e at 0; NAN:
## on the ground), `h` to the ceiling's underside.
static func piece(kind: String, c: Vector2, dir: Vector2, length: float, half: float, y0: float, y1: float, h: float) -> Dictionary:
	return {"kind": kind, "c": c, "dir": dir, "len": length, "half": half, "y0": y0, "y1": y1, "h": h}


static func perp(dir: Vector2) -> Vector2:
	return Vector2(dir.y, -dir.x)


## Where `p` (local x/z) is along and across a piece.
static func along_across(pc: Dictionary, p: Vector2) -> Vector2:
	var r: Vector2 = p - (pc.c as Vector2)
	return Vector2(r.dot(pc.dir), r.dot(perp(pc.dir as Vector2)))


static func floor_of(pc: Dictionary, along: float) -> float:
	return lerpf(float(pc.y0), float(pc.y1), clampf(along / maxf(float(pc.len), 0.01), 0.0, 1.0))


## The piece's rectangle (local x0, x1, z0, z1), grown by `grow`.
static func rect_of(pc: Dictionary, grow := 0.0, from := 0.0, to := -1.0) -> Rect2:
	var t1 := float(pc.len) if to < 0.0 else to
	var a: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * from
	var b: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * t1
	var s: Vector2 = perp(pc.dir as Vector2) * float(pc.half)
	var r: Rect2 = Rect2(a + s, Vector2.ZERO).expand(a - s).expand(b + s).expand(b - s)
	return r.grow(grow)


# --- The layout -------------------------------------------------------------------

## The delve under a barrow site (Delves.has_delve), worked out once per
## site and cached: {"ok", "base_e", "pieces": [...], "holes": [Rect2...],
## "hearth" (local Vector3), "find" (local Vector3), "find_kind",
## "feature", "exit" (the exit piece or {}), "cairn" ({} with no exit):
## {"o" (the door's middle at the facade), "dir", "back", "half", "h"},
## "door" (local Vector3, the slab's middle), "lamps"}. Pure: the planet
## and the site.
static func layout(map: PlanetData, site: Dictionary) -> Dictionary:
	var key := int(site.seed)
	_mutex.lock()
	var hit = _layouts.get(key)
	_mutex.unlock()
	if hit != null:
		return hit
	var lay := {}
	if int(site.kind) == Ruins.Kind.CRAG_FORTRESS:
		lay = CragFortress.layout(map, site)
	elif int(site.kind) == Ruins.Kind.HEWN_TEMPLE:
		# Its halls as they stand (design 3 Oct §DZ).
		lay = HewnTemple.layout(map, site)
	elif int(site.kind) == Ruins.Kind.HANGING_GARDENS:
		# The vaulted galleries under the terraces (§DT).
		lay = HangingGardens.layout(map, site)
	else:
		lay = _make_layout(map, site)
	# A kind whose delve has no fire-holders (delves.json fire_holders
	# by_ruin "none": the stone circle's souterrain, §DS.7).
	var holders: Dictionary = (Tuning.table("delves").get("fire_holders", {}) as Dictionary).get("by_ruin", {})
	if not (site.kind is String) and str(holders.get(Ruins.data_key(site, holders), "")) == "none":
		lay.no_fire = true
	_mutex.lock()
	_layouts[key] = lay
	_mutex.unlock()
	return lay


static func _make_layout(map: PlanetData, site: Dictionary) -> Dictionary:
	var fr := frame(map, site)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site.seed, "delve"])
	var l: float = site.half_l
	var zc := -l + 5.2 # the end chamber's front
	var z_s1 := zc + 0.5 # the stair's top
	var y_t := _g0(map, fr, 0.0, z_s1) + 0.05
	var s2 := -1.0 if rng.randf() < 0.5 else 1.0
	var len_a := rng.randf_range(5.0, 6.2)
	var len_h := rng.randf_range(6.0, 7.2)
	var depth := 8.5
	var pieces: Array = []
	var stair1 := {}
	for attempt in 8:
		var y_a := y_t - depth
		var run1 := depth / SLOPE
		stair1 = piece("stair", Vector2(0.0, z_s1), Vector2(0.0, 1.0), run1, 0.85, y_t, y_a, H_STAIR)
		var z_a0 := z_s1 + run1
		var room := piece("room", Vector2(0.0, z_a0), Vector2(0.0, 1.0), len_a, 2.6, y_a, y_a, H_ROOM)
		var stair2 := piece("stair", Vector2(s2 * 1.2, z_a0 + len_a), Vector2(0.0, 1.0), 3.0 / SLOPE, 0.85, y_a, y_a - 3.0, H_STAIR)
		var z_h0 := z_a0 + len_a + 3.0 / SLOPE
		var heart := piece("heart", Vector2(0.0, z_h0), Vector2(0.0, 1.0), len_h, 3.0, y_a - 3.0, y_a - 3.0, H_HEART)
		pieces = [stair1, room, stair2, heart]
		# The rooms and the second stair deep enough under the open ground
		# (the first stair goes down from the barrow's hole, which runs as
		# far as it needs to: _hole1_len).
		var deficit := 0.0
		for k in range(1, pieces.size()):
			var pc: Dictionary = pieces[k]
			deficit = maxf(deficit, _short_of_cover(map, fr, pc, 0.0, float(pc.len)))
		if deficit <= 0.0:
			break
		depth += deficit + 0.5
	var heart: Dictionary = pieces[3]
	var y_h := float(heart.y0)
	var lay := {"ok": true, "base_e": fr.base_e, "zc": zc, "z_s1": z_s1, "y_t": y_t}
	var h1 := _hole1_len(map, fr, stair1)
	var holes: Array = [rect_of(stair1, 0.0, -0.4, h1 + 0.5)]
	# The way out: back, then to either side.
	var exits: Array = [[Vector2(-s2 * 1.2, float(heart.c.y) + len_h), Vector2(0.0, 1.0)]]
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	for sx: float in [side, -side]:
		exits.append([Vector2(sx * 3.0, float(heart.c.y) + len_h * 0.5), Vector2(sx, 0.0)])
	var exit := {}
	var cairn := {}
	for e in exits:
		var got := _try_exit(map, fr, e[0], e[1], y_h)
		if not got.is_empty():
			exit = got.exit
			cairn = got.cairn
			holes.append_array(got.holes)
			pieces.append_array(got.pieces)
			pieces.append(got.chamber)
			break
	lay.pieces = pieces
	lay.holes = holes
	lay.exit = exit
	lay.cairn = cairn
	# The first room's hearth, across from the way on; its feature.
	var room: Dictionary = pieces[1]
	lay.hearth = Vector3(-s2 * 1.3, float(room.y0), float(room.c.y) + float(room.len) * 0.45)
	lay.feature = "niches" if rng.randf() < 0.6 else "fallen"
	# The find (§AW: a spear, a bow, rarer things later) by the dead.
	lay.find_kind = "spear" if rng.randf() < 0.6 else "bow"
	lay.find = Vector3(1.5, y_h, float(heart.c.y) + len_h * 0.62 - 1.0)
	# The heart's fire-holder (design 2 Oct §CN, delves.json fire_holders:
	# the ash of the last fire, a hearth ring): by the way in, across from
	# where the stair lands, clear of the grave goods.
	lay.heart_hearth = Vector3(-s2 * 1.8, y_h, float(heart.c.y) + 1.0)
	lay.s2 = s2
	return lay


## How far down stair `pc` the barrow's hole has to run: to where its
## ceiling (and its slab) lies under the ground with a little to spare.
static func _hole1_len(map: PlanetData, fr: Dictionary, pc: Dictionary) -> float:
	var t := 0.0
	while t < float(pc.len):
		var top := floor_of(pc, t) + float(pc.h) + SLAB + 0.4
		if top <= _ground_min(map, fr, pc, t):
			# Stays under from here on?
			var ok := true
			var u := t
			while u < float(pc.len):
				if floor_of(pc, u) + float(pc.h) + SLAB + 0.4 > _ground_min(map, fr, pc, u):
					ok = false
					break
				u += 0.5
			if ok:
				return t
		t += 0.5
	return float(pc.len)


## The lowest ground across a piece at `along` (centre and both walls).
static func _ground_min(map: PlanetData, fr: Dictionary, pc: Dictionary, along: float) -> float:
	var p: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * along
	var s: Vector2 = perp(pc.dir as Vector2) * (float(pc.half) + WALL)
	return minf(_g0(map, fr, p.x, p.y), minf(_g0(map, fr, p.x + s.x, p.y + s.y), _g0(map, fr, p.x - s.x, p.y - s.y)))


## How many metres a piece's ceiling comes short of COVER_M under the
## ground between `from` and `to` along it (0: deep enough).
static func _short_of_cover(map: PlanetData, fr: Dictionary, pc: Dictionary, from: float, to: float, cover: float = COVER_M) -> float:
	var worst := 0.0
	var t := from
	while t <= to + 0.01:
		var top := floor_of(pc, t) + float(pc.h) + SLAB + cover
		worst = maxf(worst, top - _ground_min(map, fr, pc, t))
		t += 1.0
	return worst


## The way out from the heart's wall at `c` along `dir`: a stair up to a
## small long cairn on dry, even ground, or {} when the ground there
## won't do (water, a steep slope, a valley the stair would break into).
static func _try_exit(map: PlanetData, fr: Dictionary, c: Vector2, dir: Vector2, y_h: float) -> Dictionary:
	# A level run first if the ground dips on the way (it stays deep), then
	# the stair up.
	for flat in [0.0, 4.0, 8.0, 12.0, 16.0]:
		var got := _try_exit_from(map, fr, c, dir, y_h, flat)
		if not got.is_empty():
			return got
	return {}


static func _try_exit_from(map: PlanetData, fr: Dictionary, c0: Vector2, dir: Vector2, y_h: float, flat: float) -> Dictionary:
	var c: Vector2 = c0 + dir * flat
	# Where it comes up: walk out until the ground is in reach.
	var run := 0.0
	var y_c := 0.0
	for i in 200:
		run += 0.5
		var p := c + dir * run
		y_c = _g0(map, fr, p.x, p.y) + 0.05
		if y_h + run * EXIT_SLOPE >= y_c:
			break
	if run < 6.0 or run > 60.0:
		_why("run %.1f" % run)
		return {}
	var level := piece("exit", c0, dir, flat, 0.8, y_h, y_h, H_STAIR) if flat > 0.0 else {}
	var exit := piece("exit", c, dir, run, 0.8, y_h, y_c, H_STAIR)
	var hole_from := maxf(0.0, run - (H_STAIR + SLAB + 0.6) / EXIT_SLOPE - 0.5)
	# Under the ground until the cairn's hole begins (deep where it is
	# deep; near the top, like the first stair, with a little to spare).
	if not level.is_empty() and _short_of_cover(map, fr, level, 0.0, flat, EXIT_COVER_M) > 0.0:
		_why("level cover short")
		return {}
	if _short_of_cover(map, fr, exit, 0.0, hole_from, EXIT_COVER_M) > 0.0:
		_why("cover short %.2f (flat %.0f)" % [_short_of_cover(map, fr, exit, 0.0, hole_from, EXIT_COVER_M), flat])
		return {}
	var top: Vector2 = c + dir * run
	var chamber := piece("cairn", top, dir, 3.6, 1.8, y_c, y_c, 2.6)
	var holes: Array = [rect_of(exit, 0.0, hole_from, run + 0.2), rect_of(chamber, 0.0)]
	# The cairn: from the facade (the chamber's far wall) back over the
	# holes and QUAD_PAD past them, on dry, fairly even ground above the sea.
	var door_o: Vector2 = top + dir * (3.6 + WALL * 0.5)
	var back := (run - hole_from) + 3.6 + WALL + QUAD_PAD + 1.2
	var half := 1.8 + WALL + QUAD_PAD + 1.6
	var lo := INF
	var hi := -INF
	for u in range(0, int(back) + 1, 2):
		for v in [-half, 0.0, half]:
			var p: Vector2 = door_o - dir * u + perp(dir) * v
			var g := _g0(map, fr, p.x, p.y)
			lo = minf(lo, g)
			hi = maxf(hi, g)
			var d := to_dir(fr, p.x, p.y)
			var abs_e := float(fr.base_e) + g
			if _water_at(map, d) > abs_e - 0.3:
				_why("standing water %.1f vs %.1f" % [_water_at(map, d), abs_e])
				return {}
			if _near_river(map, d, 6.0):
				_why("river")
				return {}
	if hi - lo > 5.0:
		_why("uneven %.1f" % (hi - lo))
		return {}
	var out_pieces: Array = []
	if not level.is_empty():
		out_pieces.append(level)
	out_pieces.append(exit)
	return {"exit": exit, "pieces": out_pieces, "chamber": chamber, "holes": holes,
		"cairn": {"o": door_o, "dir": dir, "back": back, "half": half, "h": 3.4, "floor": y_c}}


## Standing water at `d` as TerrainChunk._standing_water has it, without
## the nests' pools (asking Nests here would ask Ruins, which asks for this
## very layout).
static func _water_at(map: PlanetData, d: Vector3) -> float:
	var cell := map.cell_at(d)
	var lake := TerrainChunk._lake_level_near(map, cell)
	if not is_nan(lake):
		return lake
	var b := map.biome[cell]
	if b == BiomeTemplates.MANGROVE or b == BiomeTemplates.SALT_MARSH:
		return PlanetConst.SEA_LEVEL_M + 0.4
	if b in TerrainChunk.WETLANDS:
		return map.terrain.elevation(d, false) + 0.35
	return PlanetConst.SEA_LEVEL_M


static func _why(t: String) -> void:
	if OS.get_environment("DELVE_DEBUG") == "1":
		print("[delve-exit] ", t)


static func _near_river(map: PlanetData, d: Vector3, margin: float) -> bool:
	if _rivers == null:
		return false
	for s in _rivers.segments_near(map, map.cell_at(d)):
		var dt := _rivers.closest_dt(s, d)
		if dt.x < _rivers.width[s] * 0.5 + margin:
			return true
	return false


## What a delve barrow's site carries (Ruins.find): its footprint and the
## plants' clearing over the cairn.
static func decorate(map: PlanetData, site: Dictionary) -> void:
	var lay := layout(map, site)
	var cairn: Dictionary = lay.get("cairn", {})
	if cairn.is_empty():
		return
	var fr := frame(map, site)
	var mid: Vector2 = (cairn.o as Vector2) - (cairn.dir as Vector2) * (float(cairn.back) * 0.5 - 2.0)
	var reach := mid.length() + float(cairn.back) * 0.5 + 6.0
	site.footprint_m = maxf(float(site.footprint_m), reach)
	(site.clear as Array).append([to_dir(fr, mid.x, mid.y), maxf(float(cairn.back) * 0.5, float(cairn.half)) + 5.0])


# --- The ground's holes (TerrainChunk) -----------------------------------------------

## The delves whose holes may open in the ground near `d` (a chunk's
## middle) within `radius`: [{"fr", "holes": [Rect2]}].
static func holes_near(map: PlanetData, d: Vector3, radius: float) -> Array:
	var out: Array = []
	if map == null:
		return out
	for c in CreatureSpawner._cells_around(d, radius + 120.0, Ruins.CELL_M):
		_mutex.lock()
		var site = _sites.get(c)
		_mutex.unlock()
		if site == null:
			site = Ruins.find(map, c)
			_mutex.lock()
			_sites[c] = site
			_mutex.unlock()
		if not has_delve(site):
			continue
		if CubeSphere.surface_distance_m(site.dir, d) > radius + float(site.footprint_m) + 20.0:
			continue
		var lay := layout(map, site)
		out.append({"fr": frame(map, site), "holes": lay.holes})
	return out


## For a chunk: 1 per fine quad the ground leaves open (a hole), or empty.
static func chunk_holes(map: PlanetData, center: Vector3, fine_d: PackedVector3Array, nf: int) -> PackedByteArray:
	var near := holes_near(map, center, TerrainChunk.CHUNK_M * 0.75)
	# The shrines' ways down (design 3 Oct §DK, Shrines).
	near.append_array(Shrines.holes_near(map, center, TerrainChunk.CHUNK_M * 0.75))
	var out := PackedByteArray()
	if near.is_empty():
		return out
	var q := nf - 1
	out.resize(q * q)
	var any := false
	for dv in near:
		var fr: Dictionary = dv.fr
		var loc := PackedVector2Array()
		loc.resize(nf * nf)
		for i in nf * nf:
			loc[i] = to_local(fr, fine_d[i])
		for r: Rect2 in dv.holes:
			var rc := r.get_center()
			var reach := r.size.length() * 0.5 + 6.5
			for jj in q:
				for ii in q:
					var i00 := jj * nf + ii
					if loc[i00].distance_squared_to(rc) > reach * reach:
						continue
					var bb := Rect2(loc[i00], Vector2.ZERO).expand(loc[i00 + 1]).expand(loc[i00 + nf]).expand(loc[i00 + nf + 1])
					if bb.intersects(r):
						out[jj * q + ii] = 1
						any = true
	if not any:
		out.clear()
	return out


# --- In play ------------------------------------------------------------------------

var world: Node
var chunks: ChunkManager
var player: Node3D
var landmarks: Landmarks
var _doors := {} # ruin node instance id -> [door node, layout, seed]
var _finds := {}
var _timer := 0.0
var _drone: AudioStreamPlayer


func setup(p_world: Node, p_chunks: ChunkManager, p_player: Node3D, p_landmarks: Landmarks) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	landmarks = p_landmarks
	instance = self
	underground = 0.0
	inside = false
	for k in ["delve_doors", "delve_finds"]:
		if not WorldSave.data.get(k, null) is Array:
			WorldSave.data[k] = []


func _exit_tree() -> void:
	if instance == self:
		instance = null
		underground = 0.0
		inside = false


## The delve barrows built now: ruin node -> layout.
func built() -> Dictionary:
	var out := {}
	if landmarks == null:
		return out
	var ruins := landmarks.built_ruins()
	for c in ruins:
		var node: Node3D = ruins[c]
		if is_instance_valid(node) and node.has_meta("delve"):
			out[node] = node.get_meta("delve")
	return out


## Where scene position `pos` is in a delve: {"ruin", "lay", "piece",
## "local" (Vector3 in the barrow's frame, y from base_e)}, or {}.
func locate(pos: Vector3) -> Dictionary:
	var nodes: Array = built().keys()
	# The shrines' halls (§DK) are delves too, for the dark.
	if Shrines.instance != null:
		for k in Shrines.instance.built:
			var sn = Shrines.instance.built[k].node
			if is_instance_valid(sn):
				nodes.append(sn)
	for node: Node3D in nodes:
		var lay: Dictionary = node.get_meta("delve")
		var off := float(node.get_meta("delve_off", 0.0))
		var lp: Vector3 = node.global_transform.affine_inverse() * pos
		lp.y += off
		var p := Vector2(lp.x, lp.z)
		for pc in lay.pieces:
			var aa := along_across(pc, p)
			if aa.x < -0.3 or aa.x > float(pc.len) + 0.3 or absf(aa.y) > float(pc.half) + 0.3:
				continue
			var fy := floor_of(pc, aa.x)
			if lp.y > fy - 1.0 and lp.y < fy + float(pc.h) + 0.3:
				return {"ruin": node, "lay": lay, "piece": pc, "local": lp}
	return {}


func _process(delta: float) -> void:
	if world == null or player == null:
		return
	var at := locate(player.global_position)
	inside = not at.is_empty()
	var want := 0.0
	if inside:
		var lp: Vector3 = at.local
		# How far below the ground over this spot (the chamber and the cairn
		# are at the ground: their roofs keep the sky out, not the day).
		var site: Dictionary = (at.ruin as Node3D).get_meta("site")
		if bool((at.lay as Dictionary).get("climbs", false)):
			# Inside the rock (§DO): dark past the first steps of the way in,
			# light again at the way out's door.
			var pk: Dictionary = at.piece
			var aa := along_across(pk, Vector2(lp.x, lp.z))
			match str(pk.kind):
				"passage":
					want = smoothstep(1.0, 4.0, aa.x)
				"exit":
					want = 1.0 - smoothstep(0.3, float(pk.len), aa.x)
				_:
					want = 1.0
		else:
			var g := 0.0
			if _map != null:
				g = _g0(_map, frame(_map, site), lp.x, lp.z)
			want = smoothstep(1.0, 3.5, g - lp.y)
		current_ruin = at.ruin
		current = at.lay
		var pc: Dictionary = at.piece
		var seed_v := int(site.seed)
		var climbs := bool((at.lay as Dictionary).get("climbs", false))
		if bool(site.get("shrine", false)):
			if str(pc.kind) == "stair" and want > 0.5:
				GameLog.add_once("shrine_down:%d" % seed_v, "A long hall goes down into the hill. Torches burn along its walls.", "delve")
			elif str(pc.kind) == "heart":
				GameLog.add_once("shrine_heart:%d" % seed_v, "Below the altar, a room no one has stood in for a long time.", "delve")
		elif str(pc.kind) == "stair" and want > 0.5:
			if climbs:
				GameLog.add_once("delve_up:%d" % seed_v, "A stair climbs into the dark inside the rock.", "delve")
			else:
				GameLog.add_once("delve_down:%d" % seed_v, "A stair goes down into the dark under the barrow.", "delve")
		elif str(pc.kind) == "heart":
			if climbs:
				GameLog.add_once("delve_heart:%d" % seed_v, "The topmost room, the chapel under the finial.", "delve")
			else:
				GameLog.add_once("delve_heart:%d" % seed_v, "The deepest room. The dead lie here with what they were given.", "delve")
	else:
		current_ruin = null
		current = {}
	underground = move_toward(underground, want, delta / 1.5)
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_refresh()


## Doors and finds for the delves built now.
func _refresh() -> void:
	var seen := {}
	for node: Node3D in built():
		var id := node.get_instance_id()
		seen[id] = true
		if _doors.has(id):
			continue
		var lay: Dictionary = node.get_meta("delve")
		var site: Dictionary = node.get_meta("site")
		var seed_v := int(site.seed)
		var door: Node3D = null
		if not (lay.cairn as Dictionary).is_empty():
			door = _make_door(node, lay, seed_v)
		var find: WorldItem = null
		if not (WorldSave.data["delve_finds"] as Array).has(seed_v):
			find = _lay_find(node, lay, seed_v)
		_doors[id] = [door, lay, seed_v, node]
		_finds[id] = find
	for id in _doors.keys():
		if not seen.has(id):
			var f = _finds.get(id)
			if f != null and is_instance_valid(f):
				(f as WorldItem).pick_up()
			_finds.erase(id)
			_doors.erase(id)


## The cairn's door: a slab in its doorway (open: slid aside).
func _make_door(node: Node3D, lay: Dictionary, seed_v: int) -> Node3D:
	var cairn: Dictionary = lay.cairn
	var off := float(node.get_meta("delve_off", 0.0))
	var o: Vector2 = cairn.o
	var dir: Vector2 = cairn.dir
	var y := float(cairn.floor) - off
	var slab := StaticBody3D.new()
	slab.name = "DelveDoor"
	slab.collision_layer = PropCollision.WORLD_LAYER
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.9, 2.3, 0.35)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.36, 0.37)
	mi.material_override = mat
	slab.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bm.size
	cs.shape = shape
	slab.add_child(cs)
	node.add_child(slab)
	var basis := Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP)
	slab.transform = Transform3D(basis, Vector3(o.x, y + 1.15, o.y))
	slab.set_meta("closed_at", slab.position)
	slab.set_meta("seed", seed_v)
	slab.set_meta("lay", lay)
	if (WorldSave.data["delve_doors"] as Array).has(seed_v):
		_slide_open(slab, true)
	return slab


func _slide_open(slab: Node3D, at_once := false) -> void:
	var lay: Dictionary = slab.get_meta("lay")
	var dir: Vector2 = lay.cairn.dir
	var side := perp(dir) * 1.9
	var to: Vector3 = (slab.get_meta("closed_at") as Vector3) + Vector3(side.x, 0.0, side.y)
	slab.set_meta("open", true)
	if at_once:
		slab.position = to
	else:
		var tw := slab.create_tween()
		tw.tween_property(slab, "position", to, 2.2).set_trans(Tween.TRANS_SINE)


## The cairn door in reach of `pos` (within 2.5 m), or null.
func door_in_reach(pos: Vector3) -> Node3D:
	for id in _doors:
		var door = _doors[id][0]
		if door != null and is_instance_valid(door) and not bool((door as Node3D).get_meta("open", false)):
			if (door as Node3D).global_position.distance_to(pos) < 2.6:
				return door
	return null


## Is `pos` on the inside of `door` (in the cairn's chamber)?
func inside_of(door: Node3D, pos: Vector3) -> bool:
	var lay: Dictionary = door.get_meta("lay")
	var dir: Vector2 = lay.cairn.dir
	var rel: Vector3 = (door.get_parent() as Node3D).global_transform.affine_inverse() * pos - (door.get_meta("closed_at") as Vector3)
	return Vector2(rel.x, rel.z).dot(dir) < 0.0


## Push the door: it opens only from inside (§CJ: "a door that opens only
## from inside"). Returns what to say.
func push(door: Node3D, pos: Vector3) -> String:
	if not inside_of(door, pos):
		return "The slab won't move from this side."
	_slide_open(door)
	var seed_v := int(door.get_meta("seed"))
	(WorldSave.data["delve_doors"] as Array).append(seed_v)
	WorldSave.mark_dirty()
	GameLog.add("The slab grinds aside. Daylight, or the night air.", "delve")
	return "You push the slab aside."


## The find lying by the dead: a WorldItem kept under the ruin.
func _lay_find(node: Node3D, lay: Dictionary, seed_v: int) -> WorldItem:
	var off := float(node.get_meta("delve_off", 0.0))
	var lp: Vector3 = lay.find
	var pos: Vector3 = node.global_transform * Vector3(lp.x, lp.y - off + 0.12, lp.z)
	var d: Vector3 = world.dir_of(pos)
	# A tome where someone left it, at some hearts (design 3 Oct §DL), in
	# place of the spear or the bow; never one whose text isn't in.
	var tome := Tomes.heart_tome(seed_v)
	var made := Tomes.item(tome) if tome != "" else Inventory.make(str(lay.find_kind))
	var it := WorldItem.drop(made, world, d, world.radius_of(pos) - PlanetConst.RADIUS_M - 0.06)
	it.set_meta("delve_find", seed_v)
	return it


## A find was taken (Main): kept so it is never laid again.
static func took(item: Node) -> void:
	if item != null and item.has_meta("delve_find"):
		var seed_v := int(item.get_meta("delve_find"))
		var list: Array = WorldSave.data.get("delve_finds", [])
		if not list.has(seed_v):
			list.append(seed_v)
			WorldSave.data["delve_finds"] = list
			WorldSave.mark_dirty()
			var it = item.get("item")
			var what := Inventory.title(it).to_lower() if it is Dictionary else "find"
			GameLog.add("Took the %s from beside the dead." % what, "delve")


## A floor point for something of the dark's in the delve near scene
## position `want` (Dread places its shape there, not on the ground over
## the delve), or Vector3.INF outside one.
func floor_near(want: Vector3) -> Vector3:
	if current_ruin == null or not is_instance_valid(current_ruin) or current.is_empty():
		return Vector3.INF
	var node := current_ruin
	var off := float(node.get_meta("delve_off", 0.0))
	var lw: Vector3 = node.global_transform.affine_inverse() * want
	var best := Vector3.INF
	var best_d := INF
	for pc in current.pieces:
		var aa := along_across(pc, Vector2(lw.x, lw.z))
		var a := clampf(aa.x, 0.3, float(pc.len) - 0.3)
		var b := clampf(aa.y, -float(pc.half) + 0.3, float(pc.half) - 0.3)
		var p2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * a + perp(pc.dir as Vector2) * b
		var p3 := Vector3(p2.x, floor_of(pc, a) - off, p2.y)
		var dd := p3.distance_to(lw)
		if dd < best_d:
			best_d = dd
			best = p3
	return node.global_transform * best if best != Vector3.INF else best
