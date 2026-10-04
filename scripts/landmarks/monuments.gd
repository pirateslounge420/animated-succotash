class_name Monuments
## The monuments with a kind of their own (design 3 Oct §DR, §DS and on:
## ruins.json styles whose kind is "own"), placed by one sites pass the
## way the crag fortress is (§DO, CragFortress): once per world every ruin
## cell is tried against each built kind's spawn gate (realm, biomes,
## needs, never), the passers win their seeded `chance` roll, and each kind
## keeps at most per_world_max, the best placed first. Ruins.find returns
## the kept one in its cell in place of whatever ruin would stand there.
## Every kind built so far is in KINDS (style key -> Ruins.Kind); a new kind
## adds its line here, its builder in RuinBuilder and its delve.
##
## The gate's plain words (spawn.needs / spawn.never), at the cell's
## best spot:
##   flat_lowland      the ground within 60 m rises no more than FLAT_MAX
##                     and it stands under LOWLAND_M (a tenth of real);
##   water_for_moat    a river, a lake or the sea within WATER_M;
##   crag / slope      (never) a rise over CRAG_MIN_M above the ground
##                     200 m round / a slope over FLAT_MAX.
##   ridgeline         a crest: the ground RIDGE_M either side of it, along
##                     some axis, at least RIDGE_RISE_M below it;
##   wet               (never) the ground's moisture over WET;
##   sandstone         the rock under it is sandstone;
##   canyon_wall       a ravine (or a slot canyon) within CANYON_M, its
##                     walls CANYON_DEEP_M deep or more (canyon_at);
##   alcove_under_overhang  a sandstone escarpment face ALCOVE_FACE_M high
##                     or more with level ground before it (alcove_at: the
##                     alcove itself is the monument's own mesh, §CK);
##   water_below       a river, a lake or the sea within WATER_BELOW_M;
##   forest            (never) a forest biome;
##   desert_river_floodplain  a river within FLOODPLAIN_M (but not in it,
##                     60 m or more from its line) or a lake or the shore
##                     within 450 m (the oasis), the ground under LOWLAND_M
##                     and dry (a river's or lake's cell is no bar here);
##   flat              the ground within 60 m rises no more than FLAT_LOOSE;
##   coast             the sea within COAST_M (sea_bearing);
##   dry               the ground's moisture under DRY;
##   open_ground       open land: no tree of the catalogue may grow there
##                     (treeless) and the ground rolls under FLAT_LOOSE;
##   near_water        a river, a lake or the shore within WATER_BELOW_M;
##   treeless          no tree of the catalogue passes its gate there or
##                     40 m round (HiddenPlaces.tree_gate): the land is
##                     already bare, nothing is cleared (§DS.3).
##   flat_lowland      (never) flat and low, as above.
##   cool_wet          the cell under COOL_C and the ground's moisture
##                     COOL_WET or more (the castle and tower styles, §DS:
##                     the tower house, the broch);
##   hot               (never) the cell over HOT_C;
##   coast_or_moor     the sea within COAST_M, or a moor (tundra or bog).
##   basalt            the rock under it is basalt (a world with none of its
##                     land on basalt loosens this to any hard rock: granite,
##                     basalt, limestone or sandstone; the site says so in
##                     "loose", the tally in "loosened");
##   escarpment        on an escarpment's plateau, its face within
##                     ESCARP_NEAR_M and ESCARP_FACE_M high or more
##                     (escarp_top);
##   dry_plateau       the ground's moisture under DRY_PLATEAU and rolling
##                     under FLAT_LOOSE over 60 m.
##   water_one_side    a river, a lake or the shore within WATER_SIDE_M
##                     (water_point; the hanging gardens, §DT: their channel
##                     runs to it; the dry realms' rivers are few, so an
##                     oasis's lake will do).
## Pure functions of the planet once warmed; thread-safe after it.

const KINDS := {"temple_city": Ruins.Kind.TEMPLE_CITY, "long_wall": Ruins.Kind.LONG_WALL, "carved_cliffs": Ruins.Kind.CARVED_CLIFFS, "cliff_dwelling": Ruins.Kind.CLIFF_DWELLING, "brick_city": Ruins.Kind.BRICK_CITY, "stone_heads": Ruins.Kind.STONE_HEADS, "terraced_pueblo": Ruins.Kind.TERRACED_PUEBLO, "stone_circle": Ruins.Kind.STONE_CIRCLE, "hewn_temple": Ruins.Kind.HEWN_TEMPLE, "hanging_gardens": Ruins.Kind.HANGING_GARDENS}
const FLAT_MAX := 0.06
const LOWLAND_M := 60.0
const WATER_M := 2500.0
const CRAG_MIN_M := 6.0
const RIDGE_M := 120.0
const RIDGE_RISE_M := 5.0
const WET := 0.62
const CANYON_M := 400.0
const CANYON_DEEP_M := 8.0
const ALCOVE_FACE_M := 9.0
const WATER_BELOW_M := 2000.0
const FLOODPLAIN_M := 1500.0
const COAST_M := 360.0
const DRY := 0.4
## "cool_wet" and (never) "hot" (the northern styles, §DS): the cell's mean
## temperature and the ground's moisture.
const COOL_C := 14.0
const COOL_WET := 0.5
const HOT_C := 22.0
## "escarpment" and "dry_plateau" (the hewn temple, §DZ).
const ESCARP_NEAR_M := 300.0
const ESCARP_FACE_M := 4.0
const DRY_PLATEAU := 0.55
## "water_one_side" (the hanging gardens, §DT).
const WATER_SIDE_M := 600.0
## The hard rocks "basalt" loosens to on a world with no basalt land.
const HARD_ROCK := [PlanetData.Rock.GRANITE, PlanetData.Rock.BASALT_VOLCANIC, PlanetData.Rock.LIMESTONE_KARST, PlanetData.Rock.SANDSTONE]
## "flat" (a city's floor, §DS.6): the walking ground's own roll is 0.07-0.2
## over 60 m in the dry country, so a little looser than flat_lowland's.
const FLAT_LOOSE := 0.1
## The long wall's line (§DS.1): steps along the crest, the turn allowed a
## step, and where it gives up (water, a drop steeper than WALL_MAX_GRADE).
const WALL_STEP_M := 40.0
const WALL_TURN := 0.21
const WALL_MAX_GRADE := 0.7
const WALL_LOST_STEPS := 5

static var STYLES: Dictionary = Tuning.table("ruins").get("styles", {})
static var _mutex := Mutex.new()
static var _for_seed := -1
static var _for_map: PlanetData = null
static var _sites := {}
## Tools: per kind {"cells", "passed", "rolled", "kept", "why": {reason: n}}.
static var report := {}


static func entry(kind_key: String) -> Dictionary:
	return STYLES.get(kind_key, {})


## The style key of a Ruins.Kind ("" if not one of these).
static func key_of(kind: int) -> String:
	for k in KINDS:
		if int(KINDS[k]) == kind:
			return k
	return ""


## Why `p` can't hold a `kind_key` monument ("" if it can).
static func gate(map: PlanetData, p: Vector3, kind_key: String, loose: Array = []) -> String:
	var cell := map.cell_at(p)
	var sp: Dictionary = entry(kind_key).get("spawn", {})
	# A floodplain city stands in a river's cell (the cells are ~10 km): only
	# its own spot must be dry.
	var by_river := (sp.get("needs", []) as Array).has("desert_river_floodplain") and (map.water[cell] == PlanetData.Water.RIVER or map.water[cell] == PlanetData.Water.LAKE)
	if map.water[cell] != PlanetData.Water.NONE and not by_river:
		return "water"
	var bkey: String = BiomeTemplates.KEYS[map.biome[cell]]
	if not (sp.get("biomes", []) as Array).is_empty() and not (sp.get("biomes", []) as Array).has(bkey):
		return "biome"
	var e := map.terrain.elevation(p, true, false, false)
	# (A floodplain lies low: a hand over the sea will do, dry.)
	if e < (0.3 if by_river or (sp.get("needs", []) as Array).has("desert_river_floodplain") else 1.0):
		return "water"
	var realms: Array = sp.get("realm", [])
	if not realms.is_empty():
		var realm := RealmMap.realm(RealmMap.world_at(p), p, map.temp_c[cell], map.moisture[cell], e / PlanetConst.HEIGHT_SCALE)
		if not realms.has(realm):
			return "realm"
	var needs: Array = sp.get("needs", [])
	var never: Array = sp.get("never", [])
	if needs.has("flat_lowland") or never.has("slope"):
		if slope(map, p, 60.0) > (FLAT_LOOSE if needs.has("open_ground") else FLAT_MAX):
			return "slope"
	if needs.has("flat_lowland") and e > LOWLAND_M:
		return "upland"
	if never.has("crag") and CragFortress.prominence(map, p) > CRAG_MIN_M:
		return "crag"
	if needs.has("water_for_moat") and HiddenPlaces.water_m(map, Encampment.rivers_for(map), p) > WATER_M:
		return "dry"
	if never.has("wet") and map.sample(map.moisture, p) > WET:
		return "wet"
	if never.has("flat_lowland") and e < LOWLAND_M and slope(map, p, 60.0) < FLAT_MAX:
		return "flat_lowland"
	if needs.has("ridgeline") and ridge_axis(map, p) < 0.0:
		return "no_ridge"
	if needs.has("sandstone") and map.rock[cell] != PlanetData.Rock.SANDSTONE:
		return "rock"
	if needs.has("canyon_wall") and canyon_at(map, p).is_empty():
		return "no_canyon"
	if never.has("forest") and bkey.contains("FOREST"):
		return "forest"
	if needs.has("alcove_under_overhang") and alcove_at(map, p).is_empty():
		return "no_alcove"
	if needs.has("water_below") and HiddenPlaces.water_m(map, Encampment.rivers_for(map), p) > WATER_BELOW_M:
		return "dry"
	if needs.has("flat") and slope(map, p, 60.0) > FLAT_LOOSE:
		return "slope"
	if needs.has("open_ground") and (slope(map, p, 60.0) > FLAT_LOOSE or not treeless(map, p)):
		return "closed"
	if needs.has("dry") and map.sample(map.moisture, p) >= DRY:
		return "wet"
	if needs.has("near_water") and HiddenPlaces.water_m(map, Encampment.rivers_for(map), p) > WATER_BELOW_M:
		return "dry"
	if needs.has("coast") and is_inf(sea_bearing(map, p)):
		return "inland"
	if needs.has("treeless") and not treeless(map, p):
		return "trees"
	if never.has("hot") and map.temp_c[cell] > HOT_C:
		return "hot"
	if needs.has("cool_wet") and (map.temp_c[cell] >= COOL_C or map.sample(map.moisture, p) < COOL_WET):
		return "not_cool_wet"
	if needs.has("coast_or_moor") and not (bkey in ["TUNDRA", "BOG"]) and is_inf(sea_bearing(map, p)):
		return "inland"
	if needs.has("basalt") and not (map.rock[cell] == PlanetData.Rock.BASALT_VOLCANIC or (loose.has("basalt") and map.rock[cell] in HARD_ROCK)):
		return "rock"
	if needs.has("dry_plateau") and (map.sample(map.moisture, p) >= DRY_PLATEAU or slope(map, p, 60.0) > FLAT_LOOSE):
		return "not_dry_plateau"
	if needs.has("escarpment") and escarp_top(map, p).is_empty():
		return "no_escarpment"
	if needs.has("water_one_side") and water_point(map, p, WATER_SIDE_M).is_empty():
		return "dry"
	if needs.has("desert_river_floodplain"):
		var rv := river_m(map, p)
		var by_water := (rv <= FLOODPLAIN_M and rv >= 60.0) or HiddenPlaces.water_m(map, Encampment.rivers_for(map), p) <= 450.0
		if e > LOWLAND_M or not by_water or TerrainChunk._standing_water(map, p).x > e - 0.3:
			return "no_floodplain"
	return ""


## The escarpment `p` stands above (§DZ): on its plateau (the + side of
## the escarpment's line), its face within ESCARP_NEAR_M and at least
## ESCARP_FACE_M high: {"face", "toward" (the bearing from the face into
## the plateau), "h"}; {} where there's none.
static func escarp_top(map: PlanetData, p: Vector3) -> Dictionary:
	if Nests.terrain != map.terrain:
		return {}
	if map.terrain.line_mask(p, "escarp") < 0.5 or map.terrain.line_noise(p, "escarp") <= 0.0:
		return {}
	var cl := Nests._cliff_at_escarp(p)
	if cl.is_empty() or float(cl.h) < ESCARP_FACE_M:
		return {}
	if CubeSphere.surface_distance_m(cl.face, p) > ESCARP_NEAR_M:
		return {}
	return {"face": cl.face, "toward": cl.toward, "h": cl.h}


## An alcove's face near `p` (§DS.4): a sandstone escarpment face (the
## escarpment layer, TerrainField) or a canyon's wall whose floor holds a
## plaza, ALCOVE_FACE_M high or more within 400 m,
## level ground for 8 m before its foot: {"foot", "face", "toward" (the
## bearing into the face), "h"}; {} where there's none.
static func alcove_at(map: PlanetData, p: Vector3) -> Dictionary:
	if Nests.terrain != map.terrain:
		return {}
	var cl := {}
	if map.terrain.line_mask(p, "escarp") >= 0.57:
		cl = Nests._cliff_at_escarp(p)
	# Or a canyon's wall (the ravine layer), its floor wide enough for a
	# plaza: the deeper wall.
	if (cl.is_empty() or float(cl.h) < ALCOVE_FACE_M) and map.terrain.line_mask(p, "ravine") >= 0.6:
		var r := Nests._snap(p, "ravine")
		if not r.is_empty():
			var g: Vector2 = r.g
			var gl := g.length()
			var floor_half := lerpf(TerrainField.RAVINE_FLOOR_N, TerrainField.SLOT_FLOOR_N, Nests.slot_at(r.dir)) / gl
			if floor_half >= 12.0:
				for s in [1.0, -1.0]:
					var into := atan2(g.x * s, g.y * s)
					var foot := CreatureSpawner._offset(r.dir, into, floor_half - 2.5)
					var h := Nests._e(CreatureSpawner._offset(r.dir, into, floor_half + 10.0)) - Nests._e(foot)
					if cl.is_empty() or h > float(cl.h):
						cl = {"foot": foot, "face": CreatureSpawner._offset(r.dir, into, floor_half), "toward": into, "h": h, "line": "ravine"}
	if cl.is_empty() or float(cl.h) < ALCOVE_FACE_M:
		return {}
	var foot: Vector3 = cl.foot
	if CubeSphere.surface_distance_m(foot, p) > 400.0 or map.rock[map.cell_at(foot)] != PlanetData.Rock.SANDSTONE:
		return {}
	if map.water[map.cell_at(foot)] != PlanetData.Water.NONE:
		return {}
	if Nests._slope(CreatureSpawner._offset(foot, float(cl.toward) + PI, 8.0), 4.0) > 0.18:
		return {}
	return cl


## The bearing from `p` to the nearest sea within COAST_M (the ground
## half a metre under the sea), INF with none.
static func sea_bearing(map: PlanetData, p: Vector3) -> float:
	for r in [60.0, 120.0, 180.0, 240.0, 300.0, COAST_M]:
		for k in 16:
			var b := k * TAU / 16.0
			if map.terrain.elevation(CreatureSpawner._offset(p, b, r), true, false, false) < PlanetConst.SEA_LEVEL_M - 0.5:
				return b
	return INF


static var _trees: Array = []


## No tree of the catalogue may grow at `p` or 40 m round it.
static func treeless(map: PlanetData, p: Vector3) -> bool:
	if _trees.is_empty():
		for sp in SpeciesDB.all():
			if (sp as PlantSpecies).tier in [PlantSpecies.Tier.EMERGENT, PlantSpecies.Tier.CANOPY]:
				_trees.append(sp)
	for k in 5:
		var q := p if k == 0 else CreatureSpawner._offset(p, k * TAU / 4.0, 40.0)
		for sp in _trees:
			if HiddenPlaces.tree_gate(map, q, sp):
				return false
	return true


## The distance from `p` to the nearest river's line (INF with none in its
## cell's reach).
static func river_m(map: PlanetData, p: Vector3) -> float:
	var rivers := Encampment.rivers_for(map)
	var best := INF
	if rivers != null:
		for s in rivers.segments_near(map, map.cell_at(p)):
			best = minf(best, rivers.closest_dt(s, p).x)
	return best


## The nearest point of a river to `p` within `within_m`, or INF-free {}:
## {"dir", "m"}.
static func river_point(map: PlanetData, p: Vector3, within_m: float) -> Dictionary:
	var rivers := Encampment.rivers_for(map)
	var best := {}
	if rivers == null:
		return best
	for sg in rivers.segments_near(map, map.cell_at(p)):
		var dt := rivers.closest_dt(sg, p)
		if dt.x < within_m and (best.is_empty() or dt.x < float(best.m)):
			var q: Vector3 = (rivers.a[sg] + (rivers.b[sg] - rivers.a[sg]) * dt.y).normalized()
			best = {"dir": q, "m": dt.x}
	return best


## The nearest water to `p` within `within_m`: a river's nearest point
## (river_point), else the first standing water (a lake, the sea) on rings
## out from it, 12 bearings a ring: {"dir", "m"}, or {}.
static func water_point(map: PlanetData, p: Vector3, within_m: float) -> Dictionary:
	var rv := river_point(map, p, within_m)
	if not rv.is_empty():
		return rv
	var e0 := map.terrain.elevation(p, true, false, false)
	if e0 < PlanetConst.SEA_LEVEL_M - 0.5 or TerrainChunk._standing_water(map, p).x > e0 + 0.1:
		return {"dir": p, "m": 0.0}
	var r := 60.0
	while r <= within_m:
		for k in 12:
			var q := CreatureSpawner._offset(p, k * TAU / 12.0, r)
			var e := map.terrain.elevation(q, true, false, false)
			if e < PlanetConst.SEA_LEVEL_M - 0.5 or TerrainChunk._standing_water(map, q).x > e + 0.1:
				return {"dir": q, "m": r}
		r += 60.0
	return {}


## The canyon at `p` (the ravine layer, a slot canyon where it pinches in
## dry sandstone; TerrainField._cliffs, Nests.slot_at): {"dir" (its middle
## line), "across" (the bearing across it), "floor_half", "rim_half" (m),
## "depth" (its walls, m), "slot" (0-1)}; {} where there's none within
## CANYON_M or it's shallower than CANYON_DEEP_M.
static func canyon_at(map: PlanetData, p: Vector3) -> Dictionary:
	if Nests.terrain != map.terrain:
		return {}
	if map.terrain.line_mask(p, "ravine") < 0.6:
		return {}
	var r := Nests._snap(p, "ravine")
	if r.is_empty():
		return {}
	var d: Vector3 = r.dir
	if CubeSphere.surface_distance_m(d, p) > CANYON_M:
		return {}
	var g: Vector2 = r.g
	var gl := g.length()
	var across := atan2(g.x, g.y)
	var slot := Nests.slot_at(d)
	var rim_half := lerpf(TerrainField.RAVINE_RIM_N, TerrainField.SLOT_RIM_N, slot) / gl
	var floor_half := lerpf(TerrainField.RAVINE_FLOOR_N, TerrainField.SLOT_FLOOR_N, slot) / gl
	var e0 := Nests._e(d)
	var depth := minf(Nests._e(CreatureSpawner._offset(d, across, rim_half + 6.0)), Nests._e(CreatureSpawner._offset(d, across + PI, rim_half + 6.0))) - e0
	if depth < CANYON_DEEP_M:
		return {}
	return {"dir": d, "across": across, "floor_half": floor_half, "rim_half": rim_half, "depth": depth, "slot": slot}


## The bearing of the crest `p` stands on (radians from north, 0..PI), or
## -1 when it is no crest: the axis whose two sides, RIDGE_M off, both lie
## RIDGE_RISE_M or more below it (the best such axis: the one the ground
## along it stays highest).
static func ridge_axis(map: PlanetData, p: Vector3) -> float:
	var e := map.terrain.elevation(p, true, false, false)
	var best := -1.0
	var best_v := -INF
	for k in 12:
		var b := k * PI / 12.0
		var s1 := map.terrain.elevation(CreatureSpawner._offset(p, b + PI * 0.5, RIDGE_M), true, false, false)
		var s2 := map.terrain.elevation(CreatureSpawner._offset(p, b - PI * 0.5, RIDGE_M), true, false, false)
		if e - s1 < RIDGE_RISE_M or e - s2 < RIDGE_RISE_M:
			continue
		var v := minf(map.terrain.elevation(CreatureSpawner._offset(p, b, RIDGE_M), true, false, false), map.terrain.elevation(CreatureSpawner._offset(p, b + PI, RIDGE_M), true, false, false))
		if v > best_v:
			best_v = v
			best = b
	return best


## The steepest rise within `r` m of `p` (rise over run, six ways).
static func slope(map: PlanetData, p: Vector3, r: float) -> float:
	var e := map.terrain.elevation(p, true, false, false)
	var s := 0.0
	for k in 6:
		s = maxf(s, absf(map.terrain.elevation(CreatureSpawner._offset(p, k * TAU / 6.0, r), true, false, false) - e) / r)
	return s


## The kept site in ruin cell `c`, or {}.
static func site_in(map: PlanetData, c: Vector3i) -> Dictionary:
	_ensure(map)
	_mutex.lock()
	var s: Dictionary = _sites.get(c, {})
	_mutex.unlock()
	return s


## Every kept site this world (of `kind_key`, or all): [site...].
static func all_sites(map: PlanetData, kind_key := "") -> Array:
	_ensure(map)
	_mutex.lock()
	var out: Array = _sites.values().filter(func(s): return kind_key == "" or str(s.style) == kind_key)
	_mutex.unlock()
	return out


static func _ensure(map: PlanetData) -> void:
	if map == null or map.terrain == null:
		return
	var sd := int(map.terrain.world_seed)
	_mutex.lock()
	if _for_seed == sd and _for_map == map:
		_mutex.unlock()
		return
	_pass(map)
	_for_seed = sd
	_for_map = map
	_mutex.unlock()


## The sites pass (under the mutex).
static func _pass(map: PlanetData) -> void:
	_sites.clear()
	report = {}
	RealmMap.warm(int(map.terrain.world_seed))
	for kind_key in KINDS:
		var E := entry(kind_key)
		var rep := {"cells": 0, "passed": 0, "rolled": 0, "kept": 0, "why": {}}
		report[kind_key] = rep
		if E.is_empty():
			continue
		var cap := int(E.get("per_world_max", 2))
		var cand := _candidates(map, kind_key, rep, [])
		# A world with no basalt land at all (§DZ): the hard rocks will do.
		var loose: Array = []
		if cand.is_empty() and ((E.get("spawn", {}) as Dictionary).get("needs", []) as Array).has("basalt"):
			loose = ["basalt"]
			rep.loosened = "basalt"
			cand = _candidates(map, kind_key, rep, loose)
		cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var kept := 0
		for k in cand.size():
			if kept >= cap or (kept >= 1 and float(cand[k][0]) >= 10.0):
				break
			var c: Vector3i = cand[k][1]
			var best: Dictionary = cand[k][2]
			var site := make_site(map, kind_key, c, best.dir, int(cand[k][3]))
			if not site.is_empty() and not loose.is_empty():
				site.loose = loose
			if site.is_empty():
				rep.why["short"] = int(rep.why.get("short", 0)) + 1
				continue
			if Delves.has_delve(site):
				Delves.decorate(map, site)
			_sites[c] = site
			kept += 1
		rep.kept = kept


## The cells that may hold `kind_key` (the sites pass): [[order, cell, best
## spot, seed]...], their tally in `rep`.
static func _candidates(map: PlanetData, kind_key: String, rep: Dictionary, loose: Array) -> Array:
	var E := entry(kind_key)
	var n := Ruins.cells_per_face()
	var biomes: Array = (E.get("spawn", {}) as Dictionary).get("biomes", [])
	var chance := float(E.get("chance", 0.3))
	var needs_river := ((E.get("spawn", {}) as Dictionary).get("needs", []) as Array).has("water_one_side")
	var rivers := Encampment.rivers_for(map)
	if rivers == null:
		needs_river = false
	var cand: Array = []
	for f in 6:
		for i in n:
			for j in n:
				var c := Vector3i(f, i, j)
				var center := CreatureSpawner._cell_point(c, n, Ruins.SALT)
				if _sites.has(c) or not CragFortress.site_in(map, c).is_empty():
					# The hanging gardens may stand by a brick city (§DT: "with
					# or without a brick city near it"): their spot sought
					# round the city's cell, the site kept in a free cell
					# beside it.
					if not (kind_key == "hanging_gardens" and str((_sites.get(c, {}) as Dictionary).get("style", "")) == "brick_city"):
						continue
					var free := Vector3i(-1, -1, -1)
					for nb in [Vector3i(f, i + 1, j), Vector3i(f, i - 1, j), Vector3i(f, i, j + 1), Vector3i(f, i, j - 1)]:
						if nb.y >= 0 and nb.y < n and nb.z >= 0 and nb.z < n and not _sites.has(nb) and CragFortress.site_in(map, nb).is_empty():
							free = nb
							break
					if free.x < 0:
						continue
					c = free
				rep.cells += 1
				if not biomes.is_empty() and not biomes.has(BiomeTemplates.KEYS[map.biome[map.cell_at(center)]]):
					continue
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([Vector4i(-2, c.x, c.y, c.z), kind_key])
				var best := {}
				var best_s := INF
				var why := ""
				# A kind that wants a river beside it (§DT) tries spots along
				# the cell's rivers, a little way off the water.
				var by_river: Array = []
				if needs_river:
					for sg in rivers.segments_near(map, map.cell_at(center)):
						if CubeSphere.surface_distance_m(rivers.a[sg], center) < Ruins.CELL_M * 0.5:
							by_river.append(sg)
				for t in 12:
					var p := CreatureSpawner._offset(center, rng.randf() * TAU, sqrt(rng.randf()) * Ruins.CELL_M * 0.35)
					if not by_river.is_empty():
						var sg: int = by_river[rng.randi() % by_river.size()]
						var on: Vector3 = (rivers.a[sg] + (rivers.b[sg] - rivers.a[sg]) * rng.randf()).normalized()
						p = CreatureSpawner._offset(on, rng.randf() * TAU, rng.randf_range(120.0, WATER_SIDE_M - 50.0))
					var g := gate(map, p, kind_key, loose)
					if g != "":
						why = g
						continue
					var sl := slope(map, p, 60.0)
					if sl < best_s:
						best_s = sl
						best = {"dir": p}
				if best.is_empty():
					rep.why[why] = int(rep.why.get(why, 0)) + 1
					continue
				rep.passed += 1
				var roll := rng.randf()
				var won := roll < chance
				if won:
					rep.rolled += 1
				# The losers wait in line: where the land exists and no
				# cell won its roll, the best of them stands (§DR.5: one
				# or two per world where the realm exists).
				cand.append([roll + best_s + (0.0 if won else 10.0), c, best, rng.randi()])
	return cand


## A kept site's measurements from its seed (Ruins.find's shape).
static func make_site(map: PlanetData, kind_key: String, c: Vector3i, d: Vector3, s: int) -> Dictionary:
	var E := entry(kind_key)
	var key := Vector4i(-2, c.x, c.y, c.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, kind_key, s])
	var site := {"dir": d, "kind": int(KINDS[kind_key]), "seed": hash([key, kind_key]), "style": kind_key}
	match kind_key:
		"temple_city":
			var ac: Array = E.get("across_m", [150, 300])
			var across := rng.randf_range(float(ac[0]), float(ac[1]))
			var en: Array = E.get("enclosures", [2, 3])
			site.across_m = across
			site.enclosures = rng.randi_range(int(en[0]), int(en[1]))
			site.towers = int(E.get("towers", 5))
			# Turned to the ground's grid (its delve's hole opens on the
			# grid's quads, Delves.grid_heading).
			site.heading = Delves.grid_heading(d, rng.randf() * TAU)
			# Its front (the causeway and the face-towered gate) toward dry
			# ground: the first of the four sides whose approach isn't water.
			for k in 4:
				var trial := site.duplicate()
				trial.heading = float(site.heading) + k * PI * 0.5
				var dry := true
				for out_m in [15.0, 35.0, 60.0]:
					var ap := Ruins.local_dir(trial, 0.0, -across * 0.5 - out_m)
					var ge := map.terrain.elevation(ap, true)
					if map.water[map.cell_at(ap)] != PlanetData.Water.NONE or ge < 2.0 or TerrainChunk._standing_water(map, ap).x > ge:
						dry = false
				if dry:
					site.heading = trial.heading
					break
			# The delve's way in lies under the central sanctum: the barrow
			# kit's passage starts half_l in front of the middle.
			site.half_l = 5.0
			site.footprint_m = across * 0.5 + 12.0
			# The ground it stands on, and its approach kept open (the
			# causeway's line out to 40 m, §DM.5).
			site.clear = [[d, across * 0.5 + 6.0]]
			for out_m in [16.0, 34.0]:
				(site.clear as Array).append([Ruins.local_dir(site, 0.0, -across * 0.5 - out_m), 12.0])
		"long_wall":
			var built := _long_wall(map, E, c, d, rng, site)
			if built.is_empty():
				return {}
		"carved_cliffs":
			var cc := _carved_cliffs(map, E, d, rng, site)
			if cc.is_empty():
				return {}
		"cliff_dwelling":
			var cd := _cliff_dwelling(map, E, d, rng, site)
			if cd.is_empty():
				return {}
		"brick_city":
			_brick_city(map, E, d, rng, site)
		"stone_heads":
			if _stone_heads(map, E, d, rng, site).is_empty():
				return {}
		"terraced_pueblo":
			if _terraced_pueblo(map, E, d, rng, site).is_empty():
				return {}
		"stone_circle":
			_stone_circle(E, d, rng, site)
		"hewn_temple":
			if _hewn_temple(map, E, d, rng, site).is_empty():
				return {}
		"hanging_gardens":
			if _hanging_gardens(map, E, d, rng, site).is_empty():
				return {}
	return site


## The long wall (§DS.1): its line along the crest from `d` both ways
## (length_km), the gate at the point of the middle stretch whose line runs
## nearest the ground grid's axes (its tower's delve opens on the grid) and
## within the cell; towers every towers_every_m out from it and at both
## ends; its height; the breaks (gaps, fallen stretches) and the collapsed
## towers. {} when the crest gives out under 3 km. Fills `site` in place.
static func _long_wall(map: PlanetData, E: Dictionary, c: Vector3i, d: Vector3, rng: RandomNumberGenerator, site: Dictionary) -> Dictionary:
	var lk: Array = E.get("length_km", [3, 12])
	var want := rng.randf_range(float(lk[0]), float(lk[1])) * 1000.0
	var axis := ridge_axis(map, d)
	if axis < 0.0:
		return {}
	var halves: Array = []
	var got: Array[float] = [0.0, 0.0]
	for side in 2:
		var pts := PackedVector3Array([d])
		var bearing := axis + side * PI
		var p := d
		var walked := 0.0
		var lost := 0
		var goal: float = want * 0.5 if side == 0 else want - got[0]
		while walked < goal:
			var best_b := bearing
			var best_e := -INF
			var best_p := Vector3.ZERO
			for j in range(-3, 4):
				var b := bearing + j * WALL_TURN / 3.0
				var q := CreatureSpawner._offset(p, b, WALL_STEP_M)
				var eq := map.terrain.elevation(q, true, false, false) - absf(j) * 0.3
				if eq > best_e:
					best_e = eq
					best_b = b
					best_p = q
			# Back onto the crest: the highest point across the way.
			var across := best_b + PI * 0.5
			var snap := best_p
			var snap_e := map.terrain.elevation(best_p, true, false, false)
			for o in [-30.0, -20.0, -10.0, 10.0, 20.0, 30.0]:
				var sq := CreatureSpawner._offset(best_p, across, o)
				var se := map.terrain.elevation(sq, true, false, false)
				if se > snap_e:
					snap_e = se
					snap = sq
			if snap != best_p:
				var tv := snap - p * snap.dot(p)
				best_b = atan2(tv.dot(CubeSphere.east(p)), tv.dot(CubeSphere.north(p)))
				best_p = CreatureSpawner._offset(p, best_b, WALL_STEP_M)
			var e0 := map.terrain.elevation(p, true, false, false)
			var e1 := map.terrain.elevation(best_p, true, false, false)
			if map.water[map.cell_at(best_p)] != PlanetData.Water.NONE or e1 < 3.0 or absf(e1 - e0) / WALL_STEP_M > WALL_MAX_GRADE:
				break
			# Never back over itself.
			var crossed := false
			for i in range(0, maxi(pts.size() - 3, 0)):
				if CubeSphere.surface_distance_m(pts[i], best_p) < WALL_STEP_M * 0.9:
					crossed = true
					break
			if crossed:
				break
			# The crest lost for longer than a saddle: the wall ends.
			lost = 0 if ridge_axis(map, best_p) >= 0.0 else lost + 1
			if lost > WALL_LOST_STEPS:
				for i in WALL_LOST_STEPS:
					pts.remove_at(pts.size() - 1)
				walked -= WALL_LOST_STEPS * WALL_STEP_M
				break
			p = best_p
			bearing = best_b
			pts.append(p)
			walked += WALL_STEP_M
		got[side] = walked
		halves.append(pts)
	if got[0] + got[1] < float(lk[0]) * 1000.0:
		return {}
	var line := PackedVector3Array()
	var h0: PackedVector3Array = halves[0]
	for i in range(h0.size() - 1, -1, -1):
		line.append(h0[i])
	var h1: PackedVector3Array = halves[1]
	for i in range(1, h1.size()):
		line.append(h1[i])
	var total := RoadNetwork.length_m(line)
	# The gate: in the middle stretch, inside the cell's reach, where the
	# line runs nearest the ground grid's axes.
	var centre := CreatureSpawner._cell_point(c, Ruins.cells_per_face(), Ruins.SALT)
	var gate_m: float = got[0]
	var best_dev := INF
	var m := total * 0.2
	while m < total * 0.8:
		var gp := RoadNetwork.point_at(line, m)
		if CubeSphere.surface_distance_m(gp, centre) < Ruins.CELL_M * 0.38:
			var tb := _bearing_at(line, m)
			var gh := Delves.grid_heading(gp, tb - PI * 0.5)
			var dev := absf(wrapf(gh + PI * 0.5 - tb, -PI * 0.25, PI * 0.25))
			if dev < best_dev:
				best_dev = dev
				gate_m = m
		m += 20.0
	var gd := RoadNetwork.point_at(line, gate_m)
	site.dir = gd
	site.line = line
	site.len_m = total
	site.gate_m = gate_m
	site.wall_h = rng.randf_range(float((E.get("height_m", [5, 8]) as Array)[0]), float((E.get("height_m", [5, 8]) as Array)[1]))
	site.thick_m = 4.6
	# Its frame on the grid, x along the wall (the delve's hole opens on
	# the grid's quads).
	site.heading = Delves.grid_heading(gd, _bearing_at(line, gate_m) - PI * 0.5)
	# The towers: every towers_every_m out from the gate both ways, and one
	# at each end.
	var te: Array = E.get("towers_every_m", [250, 500])
	var towers: Array = [gate_m]
	var tm := gate_m
	while true:
		tm += rng.randf_range(float(te[0]), float(te[1]))
		if tm > total - 60.0:
			break
		towers.append(tm)
	towers.append(total)
	tm = gate_m
	while true:
		tm -= rng.randf_range(float(te[0]), float(te[1]))
		if tm < 60.0:
			break
		towers.append(tm)
	towers.append(0.0)
	towers.sort()
	site.towers = towers
	# The breaks: in a span, now and then a gap (the wall gone, rubble at
	# its ends) or a fallen stretch (down to its core, 1-2 m); a tower
	# collapsed now and then. Never at the gate.
	var breaks: Array = []
	var fallen_towers: Array = []
	for i in towers.size() - 1:
		var a := float(towers[i])
		var b := float(towers[i + 1])
		if b - a < 80.0:
			continue
		if rng.randf() < 0.3:
			var gl := rng.randf_range(12.0, 40.0)
			var g0 := rng.randf_range(a + 20.0, b - 20.0 - gl)
			if absf(g0 - gate_m) > 40.0:
				breaks.append([g0, g0 + gl, "gap"])
		if rng.randf() < 0.35:
			var fl := minf(rng.randf_range(30.0, 120.0), b - a - 40.0)
			var f0 := rng.randf_range(a + 20.0, b - 20.0 - fl)
			if absf(f0 - gate_m) > 40.0 and absf(f0 + fl - gate_m) > 40.0:
				breaks.append([f0, f0 + fl, "fallen", rng.randf_range(1.0, 2.0)])
		if i > 0 and absf(a - gate_m) > 1.0 and rng.randf() < 0.15:
			fallen_towers.append(a)
	site.breaks = breaks
	site.fallen_towers = fallen_towers
	# The gate's own stretch (RuinBuilder._long_wall_gate): its tower, the
	# gateway on one side and the stair up on the other; the pieces
	# (LongWalls) build the rest.
	site.gate_span = [gate_m - GATE_BACK_M, gate_m + GATE_ON_M]
	site.half_l = 5.0
	site.footprint_m = GATE_ON_M + 6.0
	site.clear = [[gd, 14.0]]
	return site


## The long wall's gate stretch: GATE_BACK_M behind the gate tower's middle
## (the stair up) and GATE_ON_M on (the gateway).
const GATE_BACK_M := 22.0
const GATE_ON_M := 22.0


## The line's bearing (from north, east positive) at `m` along it.
static func _bearing_at(line: PackedVector3Array, m: float) -> float:
	var total := RoadNetwork.length_m(line)
	var a := RoadNetwork.point_at(line, clampf(m - 10.0, 0.0, total))
	var b := RoadNetwork.point_at(line, clampf(m + 10.0, 0.0, total))
	var t := b - a * b.dot(a)
	return atan2(t.dot(CubeSphere.east(a)), t.dot(CubeSphere.north(a)))


## The carved cliffs (§DS.2): a row of facades along one wall of the canyon
## at `d`, the row's middle where the wall runs nearest the ground grid's
## axes (its tombs' way in opens on the grid); each facade at the wall's
## foot (re-found along the canyon, so the row follows its bends), facing
## across it, its height facade_height_m but no more than the wall's depth
## and 8 m over it (the rock mass rising above the rim). Fills `site`.
static func _carved_cliffs(map: PlanetData, E: Dictionary, d: Vector3, rng: RandomNumberGenerator, site: Dictionary) -> Dictionary:
	var cy := canyon_at(map, d)
	if cy.is_empty():
		return {}
	# The middle: along the canyon, where its wall faces the grid.
	var along := float(cy.across) + PI * 0.5
	var best := {}
	var best_dev := INF
	for k in range(-10, 11):
		var q := CreatureSpawner._offset(cy.dir, along, k * 15.0)
		var cq := canyon_at(map, q)
		if cq.is_empty():
			continue
		for s in [1.0, -1.0]:
			var into := float(cq.across) + (0.0 if s > 0.0 else PI)
			var foot := CreatureSpawner._offset(cq.dir, into, float(cq.floor_half) + 0.5)
			var heading := into - PI
			var gh := Delves.grid_heading(foot, heading)
			var dev := absf(wrapf(gh - heading, -PI, PI))
			if dev < best_dev:
				best_dev = dev
				best = {"cy": cq, "side": s, "foot": foot, "heading": gh}
	if best.is_empty():
		return {}
	var cyc: Dictionary = best.cy
	var side := float(best.side)
	var fc := E.get("facades", [3, 9]) as Array
	var fh := E.get("facade_height_m", [8, 30]) as Array
	var n := rng.randi_range(int(fc[0]), int(fc[1]))
	var widths: Array = []
	var span := 0.0
	for i in n:
		var w := rng.randf_range(7.0, 12.0)
		widths.append(w)
		span += w + (3.0 if i > 0 else 0.0)
	var facades: Array = []
	var s0 := -span * 0.5
	var along_c := float(cyc.across) + PI * 0.5
	for i in n:
		var w := float(widths[i])
		var s := s0 + w * 0.5
		s0 += w + 3.0
		var q := CreatureSpawner._offset(cyc.dir, along_c, s)
		var cq := canyon_at(map, q) if absf(s) > 0.1 else cyc
		if cq.is_empty():
			continue
		var into := float(cq.across) + (0.0 if side > 0.0 else PI)
		# The same wall: the across bearing may have flipped along the way.
		if cos(wrapf(into - (float(cyc.across) + (0.0 if side > 0.0 else PI)), -PI, PI)) < 0.0:
			into += PI
		var foot := CreatureSpawner._offset(cq.dir, into, float(cq.floor_half) + 0.5)
		var h := clampf(rng.randf_range(float(fh[0]), float(fh[1])), 8.0, float(cq.depth) + 8.0)
		facades.append({"dir": foot, "into": into, "w": w, "h": h, "cols": 4 if w < 9.5 else 6, "upper": h > 14.0, "s": s, "creeper": rng.randf() < 0.3})
	if facades.size() < 3:
		return {}
	# The middle facade's foot is the site's (its door over the way in).
	var mid := 0
	for i in facades.size():
		if absf(float(facades[i].s)) < absf(float(facades[mid].s)):
			mid = i
	site.dir = facades[mid].dir
	site.heading = Delves.grid_heading(site.dir, float(facades[mid].into) - PI)
	site.facades = facades
	site.mid = mid
	site.slot = float(cyc.slot)
	site.depth_m = float(cyc.depth)
	site.half_l = 5.0
	site.footprint_m = span * 0.5 + 8.0
	site.clear = [[site.dir, 6.0]]
	return site


## The cliff dwelling (§DS.4): an alcove in a sandstone escarpment face
## near `d`, where the face looks nearest the ground grid's axes (the great
## kiva's way down opens on the grid); its size, and its town laid out:
## rows of rooms back to front, storeys stepping down toward the plaza
## (storeys at the back), the round towers, the ladders, the kivas in the
## plaza and the great kiva over the way down. Fills `site`.
static func _cliff_dwelling(map: PlanetData, E: Dictionary, d: Vector3, rng: RandomNumberGenerator, site: Dictionary) -> Dictionary:
	var a0 := alcove_at(map, d)
	if a0.is_empty():
		return {}
	var best := {}
	var best_dev := INF
	var along := float(a0.toward) + PI * 0.5
	for k in range(-10, 11):
		var q := CreatureSpawner._offset(a0.foot, along, k * 15.0)
		var aq := alcove_at(map, q)
		if aq.is_empty():
			continue
		# Its frame: +z out of the face, toward the plaza (the barrow kit's
		# way runs +z: in at the alcove's back, out past the plaza).
		var heading := float(aq.toward)
		var gh := Delves.grid_heading(aq.foot, heading)
		var dev := absf(wrapf(gh - heading, -PI, PI))
		if dev < best_dev:
			best_dev = dev
			best = aq
			best.heading = gh
	if best.is_empty():
		return {}
	var foot: Vector3 = best.foot
	site.dir = foot
	site.heading = float(best.heading)
	site.face_h = float(best.h)
	var stb: Array = E.get("storeys", [2, 4])
	var rmb: Array = E.get("rooms", [20, 150])
	var storeys := rng.randi_range(int(stb[0]), int(stb[1]))
	var width := rng.randf_range(36.0, 72.0)
	var rows := clampi(storeys + 1, 3, 4)
	site.alcove_w = width
	site.alcove_d = 4.5 + rows * 3.2 + rng.randf_range(2.0, 4.0)
	site.storeys = storeys
	# The rooms: [x, z (the room's middle, out from the face), storeys],
	# back row first; a room in seven fallen out, a lane left down the
	# middle (the way down opens in it, at the back).
	var rooms: Array = []
	var count := 0
	var x0 := -width * 0.5 + 3.0
	for r in rows:
		var z := 1.8 + r * 3.2
		var st := maxi(1, storeys - r)
		var x := x0
		while x < width * 0.5 - 3.0:
			if absf(x) > 1.8 and rng.randf() > 0.14:
				rooms.append([x, z, st])
				count += st
			x += 3.4
	while count > int(rmb[1]) and not rooms.is_empty():
		var last: Array = rooms.pop_back()
		count -= int(last[2])
	if count < int(rmb[0]):
		return {}
	site.rooms = rooms
	site.room_count = count
	var towers: Array = []
	for k in rng.randi_range(2, 3):
		var tx := rng.randf_range(-width * 0.4, width * 0.4)
		if absf(tx) < 4.0:
			tx = 4.0 * signf(tx if tx != 0.0 else 1.0)
		towers.append([tx, 1.8 + rng.randi_range(0, 1) * 3.2, rng.randf_range(1.6, 2.2)])
	site.towers_round = towers
	var ladders: Array = []
	for k in rng.randi_range(4, 7):
		var rm: Array = rooms[rng.randi() % rooms.size()]
		if int(rm[2]) >= 2:
			ladders.append([float(rm[0]) + rng.randf_range(-0.8, 0.8), float(rm[1]) + 1.6, int(rm[2])])
	site.ladders = ladders
	# The way down at the alcove's back (the first stair's top a metre out
	# from the face), the plaza in front of the rooms with its kivas, and
	# the great kiva over the heart (Delves.layout tells where).
	site.half_l = 4.7
	var plaza_z := 4.5 + rows * 3.2
	var kivas: Array = []
	for k in rng.randi_range(2, 4):
		var kx := rng.randf_range(-width * 0.4, width * 0.4)
		if absf(kx) < 7.0:
			kx = 7.0 * signf(kx if kx != 0.0 else 1.0) + kx * 0.3
		kivas.append([kx, plaza_z + rng.randf_range(-0.5, 2.0), rng.randf_range(2.0, 2.6)])
	site.kivas = kivas
	site.footprint_m = width * 0.5 + 14.0
	site.clear = [[Ruins.local_dir(site, 0.0, plaza_z * 0.6), width * 0.5 + 6.0]]
	return site


## The brick city (§DS.6): across_m wide round `d`; the frame's origin is
## the palace mound to one side (its vaults are the delve), the tell's
## middle (city_c, local) the city's, the processional way coming in from
## the river side to the gate on the tell's edge. Fills `site`.
static func _brick_city(map: PlanetData, E: Dictionary, d: Vector3, rng: RandomNumberGenerator, site: Dictionary) -> void:
	var ac: Array = E.get("across_m", [200, 400])
	var across := rng.randf_range(float(ac[0]), float(ac[1]))
	var r := across * 0.5
	# The palace mound beside the tell, the way in at its foot (the
	# barrow kit runs +z under it from there).
	var hd := Delves.grid_heading(d, rng.randf() * TAU)
	var tmp := {"dir": d, "heading": hd}
	var palace := Ruins.local_dir(tmp, r * 1.0 + 12.0, 0.0)
	site.dir = palace
	site.heading = hd
	site.across_m = across
	site.city_c = Vector2(-(r * 1.0 + 12.0), 0.0)
	site.palace_r = rng.randf_range(24.0, 30.0)
	site.half_l = float(site.palace_r) + 6.7
	site.maze_seed = rng.randi()
	site.footprint_m = r * 2.0 + 30.0
	site.clear = [[d, r * 0.95], [palace, float(site.palace_r) + 4.0]]


## The stone heads (§DS.3): the platform along the shore 35 m in from the
## water, the heads on it facing inland (site.inland: the row turns to it;
## the frame is turned to the ground grid, so the quarry's way down opens
## on it), the quarry QUARRY_Z up the frame's +z in the hill behind.
## Fills `site`.
const QUARRY_Z := 70.0


static func _stone_heads(map: PlanetData, E: Dictionary, d: Vector3, rng: RandomNumberGenerator, site: Dictionary) -> Dictionary:
	var sb := sea_bearing(map, d)
	if is_inf(sb):
		return {}
	# The shore along the sea's bearing, then 35 m in from it.
	var shore := d
	for i in 40:
		var q := CreatureSpawner._offset(d, sb, i * 10.0)
		if map.terrain.elevation(q, true, false, false) < PlanetConst.SEA_LEVEL_M + 0.3:
			shore = q
			break
	var inland := sb + PI
	var c := CreatureSpawner._offset(shore, inland, 35.0)
	# 35 m in from the water, if that's still the heads' ground; else where
	# the gate found it.
	if map.terrain.elevation(c, true, false, false) < 1.0 or gate(map, c, "stone_heads") != "":
		c = d
	site.dir = c
	site.inland = inland
	site.heading = Delves.grid_heading(c, inland - PI)
	var hc: Array = E.get("heads", [5, 15])
	var hh: Array = E.get("height_m", [4, 10])
	var n := rng.randi_range(int(hc[0]), int(hc[1]))
	var heads: Array = []
	for i in n:
		heads.append({"h": rng.randf_range(float(hh[0]), float(hh[1])), "fallen": rng.randf() < 0.2, "topknot": rng.randf() < 0.25, "turn": rng.randf_range(-0.08, 0.08)})
	site.heads = heads
	site.half_l = 5.7 - QUARRY_Z
	site.footprint_m = maxf(n * 4.6 * 0.5 + 8.0, QUARRY_Z * 0.6)
	site.clear = []
	return site


## The terraced pueblo (§DS.5): a stepped town on open ground round `d`,
## its frame on the ground grid (the great kiva's way down opens on it):
## rows of rooms back to front, the back rows the tallest (storeys), each
## storey set back toward the back; its plaza in front (-z) with the great
## kiva over the way down. {} where the ground isn't open. Fills `site`.
static func _terraced_pueblo(map: PlanetData, E: Dictionary, d: Vector3, rng: RandomNumberGenerator, site: Dictionary) -> Dictionary:
	if slope(map, d, 40.0) > 0.12:
		return {}
	var stb: Array = E.get("storeys", [3, 5])
	var storeys := rng.randi_range(int(stb[0]), int(stb[1]))
	var cols := rng.randi_range(7, 11)
	var rows := storeys + 1
	site.heading = Delves.grid_heading(d, rng.randf() * TAU)
	site.storeys = storeys
	site.cols = cols
	site.rows = rows
	site.room_m = 4.0
	# Each room: [col, row, standing storeys] (the top ones melted away).
	var rooms: Array = []
	for r in rows:
		var full := clampi(storeys - (rows - 1 - r), 1, storeys)
		for c in cols:
			if rng.randf() < 0.08:
				continue
			var st := full
			if rng.randf() < 0.35:
				st = maxi(1, full - rng.randi_range(1, 2))
			rooms.append([c, r, st])
	site.rooms = rooms
	site.room_count = rooms.reduce(func(a, b): return a + int(b[2]), 0)
	# The plaza in front, its small kivas, the great kiva over the way down.
	var front_z := -float(rows) * 4.0 * 0.5 - 4.0
	site.half_l = -(front_z - 7.0) + 5.7
	var kivas: Array = []
	for k in rng.randi_range(1, 2):
		kivas.append([rng.randf_range(0.25, 0.45) * cols * 4.0 * (1.0 if k == 0 else -1.0), front_z - rng.randf_range(4.0, 8.0), rng.randf_range(2.0, 2.6)])
	site.kivas = kivas
	site.great_kiva = [0.0, front_z - 7.0 + 1.0, 4.4]
	site.footprint_m = maxf(cols, rows) * 4.0 * 0.5 + 18.0
	site.clear = [[d, float(site.footprint_m)]]
	return site


## The stone circle (§DS.7): its ring of stones round `d`, the ditch and
## bank outside it with a causeway in, and (half the time) a souterrain:
## its hidden mouth at the bank, its passage under the ring to the end
## chamber, a second mouth beyond. Fills `site`.
static func _stone_circle(E: Dictionary, d: Vector3, rng: RandomNumberGenerator, site: Dictionary) -> void:
	var sc: Array = E.get("stones", [9, 30])
	var sh: Array = E.get("stone_height_m", [2, 7])
	var n := rng.randi_range(int(sc[0]), int(sc[1]))
	var r := 4.0 + n * 0.45
	site.heading = Delves.grid_heading(d, rng.randf() * TAU)
	site.ring_r = r
	var stones: Array = []
	for i in n:
		stones.append({"a": TAU * i / n + rng.randf_range(-0.04, 0.04), "h": rng.randf_range(float(sh[0]), float(sh[1])), "w": rng.randf_range(1.3, 2.1),
			"lean": rng.randf_range(-0.12, 0.12), "fallen": rng.randf() < 0.15})
	# Lintels on pairs of near-equal standing stones.
	var lintels: Array = []
	for i in n:
		var s1: Dictionary = stones[i]
		var s2: Dictionary = stones[(i + 1) % n]
		if bool(s1.fallen) or bool(s2.fallen) or float(s1.h) < 3.2 or absf(float(s1.h) - float(s2.h)) > 1.2 or rng.randf() > 0.4:
			continue
		if not lintels.is_empty() and int(lintels[-1]) == i - 1:
			continue
		lintels.append(i)
	site.stones = stones
	site.lintels = lintels
	site.souterrain = rng.randf() < 0.5
	site.half_l = r + 10.0 + 5.7
	site.footprint_m = r + 14.0
	site.clear = [[d, r + 14.0]]



## The hewn temple (§DZ): a pit pit_w by pit_l (pit_m, across the face and
## into the plateau) cut depth_m into the plateau behind the escarpment's
## face, its front wall 8 m back from the edge, its frame on the ground's
## grid with +z into the plateau (the halls in the back wall go that way,
## under the hill). floor_y is the pit's floor (from the frame's base_e,
## Delves.frame), rim_y the lowest of its rim; stair_sx the end of the
## front wall the stair down starts from. {} where the plateau is too
## broken for it or too thin over the halls. Fills `site` in place.
const HEWN_HALLS_X := 14.0
const HEWN_REAR_M := 36.0
## The pit's front wall this far back from the escarpment's face, and how
## much its rim may fall from its high side to its low.
const HEWN_BACK_M := 20.0
const HEWN_RIM_M := 12.0
static func _hewn_temple(map: PlanetData, E: Dictionary, d: Vector3, rng: RandomNumberGenerator, site: Dictionary) -> Dictionary:
	var top := escarp_top(map, d)
	if top.is_empty():
		return {}
	var pm: Array = E.get("pit_m", [60, 120])
	var across := rng.randf_range(float(pm[0]), float(pm[1]))
	var depth := rng.randf_range(18.0, 24.0)
	var pit_l := across
	var pit_w := maxf(across * rng.randf_range(0.7, 0.85), depth / HewnTemple.COURT_STAIR + 10.0)
	var c := CreatureSpawner._offset(top.face, float(top.toward), pit_l * 0.5 + HEWN_BACK_M)
	site.dir = c
	site.heading = Delves.grid_heading(c, float(top.toward) - PI)
	site.pit_w = pit_w
	site.pit_l = pit_l
	var fr := Delves.frame(map, site)
	# The rim: its lowest point and how broken it is.
	var lo := INF
	var hi := -INF
	for k in 40:
		var t := k / 40.0
		var q := Vector2.ZERO
		match k % 4:
			0:
				q = Vector2(lerpf(-pit_w, pit_w, t) * 0.5, -pit_l * 0.5)
			1:
				q = Vector2(lerpf(-pit_w, pit_w, t) * 0.5, pit_l * 0.5)
			2:
				q = Vector2(-pit_w * 0.5, lerpf(-pit_l, pit_l, t) * 0.5)
			_:
				q = Vector2(pit_w * 0.5, lerpf(-pit_l, pit_l, t) * 0.5)
		var g := Delves._g0(map, fr, q.x, q.y)
		lo = minf(lo, g)
		hi = maxf(hi, g)
		var qd := Delves.to_dir(fr, q.x, q.y)
		if map.water[map.cell_at(qd)] != PlanetData.Water.NONE:
			return {}
	# A rim that falls a little toward the edge is the hillside the pit is
	# cut into (deeper on its high side); a broken one isn't.
	if hi - lo > HEWN_RIM_M:
		return {}
	# The hill over the halls (HewnTemple.layout) thick enough: the top
	# hall's roof under the ground with cover to spare.
	var over := INF
	for xi in 7:
		for zi in 7:
			var x := lerpf(-HEWN_HALLS_X - 4.0, HEWN_HALLS_X + 4.0, xi / 6.0)
			var z := pit_l * 0.5 + lerpf(0.0, HEWN_REAR_M, zi / 6.0)
			over = minf(over, Delves._g0(map, fr, x, z))
	var need := HewnTemple.TOP_ROOF + Delves.COVER_M
	depth = maxf(depth, need - (over - lo))
	if depth > 28.0:
		return {}
	site.depth_m = depth
	site.rim_y = lo
	site.floor_y = lo - depth
	# The stair down the front wall starts at its lower end (stair_sx: the
	# -x end or the +x); the pit wide enough for its run.
	var gl := Delves._g0(map, fr, -pit_w * 0.5 + 3.0, -pit_l * 0.5 - 1.0)
	var gr := Delves._g0(map, fr, pit_w * 0.5 - 3.0, -pit_l * 0.5 - 1.0)
	site.stair_sx = -1.0 if gl <= gr else 1.0
	var run := (minf(gl, gr) - float(site.floor_y)) / HewnTemple.COURT_STAIR
	if run + 8.0 > pit_w:
		return {}
	site.temple_w = pit_w * 0.42
	site.temple_l = pit_l * 0.55
	site.towers = rng.randi_range(5, 7)
	site.footprint_m = Vector2(pit_w, pit_l).length() * 0.5 + HEWN_REAR_M
	site.clear = [[c, Vector2(pit_w, pit_l).length() * 0.5 + 5.0]]
	return site


## The hanging gardens (§DT): a stepped mound across_m wide (terraces of
## height_m / terraces each, at least HangingGardens.TIER_MIN_M) with its
## back (+z, the frame turned to the ground's grid) toward its water (a
## river, or an oasis's lake: water_point), set so its back foot stands
## about 30 m from it; the water's nearest point in the frame (riv: the
## channel runs to it); base_y the floor of
## its lowest galleries (from the frame's base_e: over the highest ground
## under it). {} where there's no river near or the ground won't hold it.
## Fills `site` in place.
static func _hanging_gardens(map: PlanetData, E: Dictionary, d: Vector3, rng: RandomNumberGenerator, site: Dictionary) -> Dictionary:
	var rv := water_point(map, d, WATER_SIDE_M)
	if rv.is_empty():
		return {}
	var ac: Array = E.get("across_m", [80, 150])
	var hm: Array = E.get("height_m", [20, 35])
	var tr: Array = E.get("terraces", [4, 7])
	var across := rng.randf_range(float(ac[0]), float(ac[1]))
	var height := rng.randf_range(float(hm[0]), float(hm[1]))
	var n := clampi(rng.randi_range(int(tr[0]), int(tr[1])), int(tr[0]), int(height / HangingGardens.TIER_MIN_M))
	var r := across * 0.5
	var rd: Vector3 = rv.dir
	var rel := rd - d * rd.dot(d)
	var bearing := atan2(rel.dot(CubeSphere.east(d)), rel.dot(CubeSphere.north(d)))
	# Its back foot 30 m from the water, or a little further where the
	# water's edge wanders under it.
	var hi := -INF
	var c := Vector3.ZERO
	var placed := false
	var tries: Array = []
	for back in [30.0, 60.0, 100.0]:
		for turn in [0.0, 0.5, -0.5, 1.0, -1.0]:
			tries.append([back, turn])
	for tr2 in tries:
		var back := float(tr2[0])
		var face := bearing + float(tr2[1])
		c = CreatureSpawner._offset(rd, face + PI, r + back)
		if map.water[map.cell_at(c)] == PlanetData.Water.OCEAN or map.terrain.elevation(c, true) < 0.3:
			continue
		# Clear of the sites already standing (a brick city beside it: its
		# walls' ring and its palace).
		var clear := true
		for other in _sites.values():
			var spots: Array = [[other.dir, float(other.get("footprint_m", 30.0))]]
			if str(other.get("style", "")) == "brick_city":
				var cc: Vector2 = other.city_c
				spots = [[Ruins.local_dir(other, cc.x, cc.y), float(other.across_m) * 0.5 + 10.0], [other.dir, float(other.palace_r) + 10.0]]
			for sp in spots:
				if CubeSphere.surface_distance_m(sp[0], c) < float(sp[1]) + r * 1.42:
					clear = false
		if not clear:
			continue
		site.dir = c
		site.heading = Delves.grid_heading(c, face - PI)
		var fr0 := Delves.frame(map, site)
		# The highest ground under it, and none of it in the water.
		hi = -INF
		var dry := true
		for i in 7:
			for j in 7:
				var x := lerpf(-r, r, i / 6.0)
				var z := lerpf(-r, r, j / 6.0)
				var q := Delves.to_dir(fr0, x, z)
				if map.water[map.cell_at(q)] == PlanetData.Water.OCEAN or TerrainChunk._standing_water(map, q).x > map.terrain.elevation(q, true) - 0.2:
					dry = false
				hi = maxf(hi, Delves._g0(map, fr0, x, z))
		if dry:
			placed = true
			break
	if not placed:
		return {}
	site.across_m = across
	site.height_m = height
	site.terraces = n
	site.tier_m = height / n
	site.top_half = maxf(14.0, across * 0.12)
	var fr := Delves.frame(map, site)
	site.base_y = hi + 0.05
	site.riv = Delves.to_local(fr, rd)
	site.footprint_m = r * 1.42 + 8.0
	site.clear = [[c, r * 1.42 + 4.0]]
	# Its channel's line to the river kept open.
	var foot := Vector2(0.0, r)
	var riv: Vector2 = site.riv
	var steps := int(foot.distance_to(riv) / 20.0)
	for k in steps:
		var q2 := foot.lerp(riv, (k + 0.5) / maxf(steps, 1))
		(site.clear as Array).append([Delves.to_dir(fr, q2.x, q2.y), 5.0])
	var lay := HangingGardens.layout(map, site)
	if not bool(lay.get("ok", false)):
		return {}
	return site
