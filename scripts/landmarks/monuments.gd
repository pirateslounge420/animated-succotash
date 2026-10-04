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
##   flat_lowland      (never) flat and low, as above.
## Pure functions of the planet once warmed; thread-safe after it.

const KINDS := {"temple_city": Ruins.Kind.TEMPLE_CITY, "long_wall": Ruins.Kind.LONG_WALL}
const FLAT_MAX := 0.06
const LOWLAND_M := 60.0
const WATER_M := 2500.0
const CRAG_MIN_M := 6.0
const RIDGE_M := 120.0
const RIDGE_RISE_M := 5.0
const WET := 0.62
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
static func gate(map: PlanetData, p: Vector3, kind_key: String) -> String:
	var cell := map.cell_at(p)
	if map.water[cell] != PlanetData.Water.NONE:
		return "water"
	var sp: Dictionary = entry(kind_key).get("spawn", {})
	var bkey: String = BiomeTemplates.KEYS[map.biome[cell]]
	if not (sp.get("biomes", []) as Array).is_empty() and not (sp.get("biomes", []) as Array).has(bkey):
		return "biome"
	var e := map.terrain.elevation(p, true, false, false)
	if e < 1.0:
		return "water"
	var realms: Array = sp.get("realm", [])
	if not realms.is_empty():
		var realm := RealmMap.realm(RealmMap.world_at(p), p, map.temp_c[cell], map.moisture[cell], e / PlanetConst.HEIGHT_SCALE)
		if not realms.has(realm):
			return "realm"
	var needs: Array = sp.get("needs", [])
	var never: Array = sp.get("never", [])
	if needs.has("flat_lowland") or never.has("slope"):
		if slope(map, p, 60.0) > FLAT_MAX:
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
	return ""


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
	var n := Ruins.cells_per_face()
	for kind_key in KINDS:
		var E := entry(kind_key)
		var rep := {"cells": 0, "passed": 0, "rolled": 0, "kept": 0, "why": {}}
		report[kind_key] = rep
		if E.is_empty():
			continue
		var biomes: Array = (E.get("spawn", {}) as Dictionary).get("biomes", [])
		var chance := float(E.get("chance", 0.3))
		var cap := int(E.get("per_world_max", 2))
		var cand: Array = []
		for f in 6:
			for i in n:
				for j in n:
					var c := Vector3i(f, i, j)
					if _sites.has(c) or not CragFortress.site_in(map, c).is_empty():
						continue
					rep.cells += 1
					var center := CreatureSpawner._cell_point(c, n, Ruins.SALT)
					if not biomes.is_empty() and not biomes.has(BiomeTemplates.KEYS[map.biome[map.cell_at(center)]]):
						continue
					var rng := RandomNumberGenerator.new()
					rng.seed = hash([Vector4i(-2, c.x, c.y, c.z), kind_key])
					var best := {}
					var best_s := INF
					var why := ""
					for t in 12:
						var p := CreatureSpawner._offset(center, rng.randf() * TAU, sqrt(rng.randf()) * Ruins.CELL_M * 0.35)
						var g := gate(map, p, kind_key)
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
		cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var kept := 0
		for k in cand.size():
			if kept >= cap or (kept >= 1 and float(cand[k][0]) >= 10.0):
				break
			var c: Vector3i = cand[k][1]
			var best: Dictionary = cand[k][2]
			var site := make_site(map, kind_key, c, best.dir, int(cand[k][3]))
			if site.is_empty():
				rep.why["short"] = int(rep.why.get("short", 0)) + 1
				continue
			if Delves.has_delve(site):
				Delves.decorate(map, site)
			_sites[c] = site
			kept += 1
		rep.kept = kept


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
