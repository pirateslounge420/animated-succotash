class_name Villages
## Villages (design 5 Oct §EE): forgotten stone-and-timber towns, relit
## hearth by hearth. One archetype is built first (§EE.5,
## data/villages.json prototype): the stream-gutter town, stone channels
## along its streets fed from a stream on a gentle slope. This is its
## sites pass (§EE.3): once per world, the planet's streams are read for
## the spots a village would choose, and the best are kept.
##
## Siting is feng-shui logic as a score (villages.json siting.weights) over
## ground the planet already computes. Each stream's bends (where one river
## segment turns into the next) and reaches (a segment's middle) offer a
## spot front_m back from the water on either bank; each spot faces the
## water and is scored on:
##   ridge_behind        the ground rising behind it, away from the water
##   flanking_ridges     arms of higher ground either side behind
##   open_front_low_ground  a gentle, even fall in front, down to the water
##   water_in_front      the stream 25-90 m in front
##   inside_of_river_bend   the bank the stream turns toward (stable silt)
##   sun_facing_slope    its ground falls toward the equator
##   shelter_from_prevailing_wind  higher ground upwind (wind_avg)
##   outer_eroding_bank  (against) the bank the stream turns away from
##   fast_straight_water (against) a steep, straight reach
##   flood_level         (against) ground barely above the water
## Gates first (prototype): the archetype's biomes, a mild mean year, damp
## enough, a stream (not a great river), a gentle slope over the village's
## ground, no ruin within keep_off_m. A site missing its ridge may build a
## raised mound behind; one missing water in front, a dug pond (§EE.3,
## siting.may_build_missing_piece): the plan reads site.builds.
##
## Kept sites are the best-scoring, at least min_score, min_spacing_m
## apart, at most per_world_max. Pure functions of the planet once warmed;
## thread-safe after it. The plan (VillagePlan) and the build
## (VillageBuilder) follow from a site alone, so nothing is saved but the
## hearths' fires (OldHearths, FireStore).

static var V: Dictionary = Tuning.table("villages")
static var P: Dictionary = V.get("prototype", {})
static var _mutex := Mutex.new()
static var _for_seed := -1
static var _for_map: PlanetData = null
static var _sites: Array = []
## id -> VillagePlan (made on first use; plans are pure and cached).
static var _plans := {}
## Tools: candidates tried, turned away by reason, kept.
static var report := {}


## The specialties a village may take (§EE.5): villages.json specialties
## less the retired rows (no metal, §EH: glass and mining are never
## rolled).
static func specialties() -> Array:
	var out: Array = []
	for s in V.get("specialties", []):
		if s is Dictionary and not (s as Dictionary).has("retired"):
			out.append(s)
	return out


## Every kept village site this world: [site...], best first.
static func all_sites(map: PlanetData) -> Array:
	_ensure(map)
	_mutex.lock()
	var out := _sites.duplicate()
	_mutex.unlock()
	return out


## The village sites within `radius` m (plus their own reach) of `d`.
static func near(map: PlanetData, d: Vector3, radius: float) -> Array:
	var out: Array = []
	var reach := float((V.get("plan", {}) as Dictionary).get("radius_m", 78.0))
	for s in all_sites(map):
		if CubeSphere.surface_distance_m(s.dir, d) < radius + reach:
			out.append(s)
	return out


## The plan of a site (VillagePlan), made once.
static func plan_of(map: PlanetData, site: Dictionary) -> VillagePlan:
	_mutex.lock()
	var p: VillagePlan = _plans.get(site.id, null)
	_mutex.unlock()
	if p != null:
		return p
	p = VillagePlan.make(map, site)
	_mutex.lock()
	if _plans.has(site.id):
		p = _plans[site.id]
	else:
		_plans[site.id] = p
	_mutex.unlock()
	return p


## Plants kept off a village near `d` (VegetationPlacer's clearings): its
## lanes, squares, houses and void, from its plan; the wild stops at its
## edge (the forest line, one of Lynch's edges, §EG.1).
static func clearings_near(map: PlanetData, d: Vector3, radius: float) -> Array:
	var out: Array = []
	for s in near(map, d, radius):
		var p := plan_of(map, s)
		for c in p.clearings:
			if CubeSphere.surface_distance_m(c[0], d) < radius + float(c[1]):
				out.append(c)
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
	_plans.clear()
	_mutex.unlock()


## The sites pass (under the mutex).
static func _pass(map: PlanetData) -> void:
	_sites.clear()
	report = {"candidates": 0, "scored": 0, "kept": 0, "why": {}, "best": []}
	if P.is_empty():
		return
	var rivers := Encampment.rivers_for(map)
	if rivers == null:
		return
	var biomes := PackedInt32Array()
	for key in P.get("biomes", []):
		var b := BiomeTemplates.id_of_key(str(key))
		if b >= 0:
			biomes.append(b)
	var trange: Array = P.get("temp_c", [0.0, 21.0])
	var wmin := float((P.get("stream_width_m", [7.0, 24.0]) as Array)[0])
	var wmax := float((P.get("stream_width_m", [7.0, 24.0]) as Array)[1])
	var front_m := float(P.get("front_m", 48.0))
	# A stream, not a great river: the narrower half of the world's.
	if bool(P.get("stream_narrower_half", true)):
		var ws: Array = []
		for s in rivers.a.size():
			if rivers.salty[s] == 0:
				ws.append(float(rivers.width[s]))
		if not ws.is_empty():
			ws.sort()
			wmax = minf(wmax, float(ws[ws.size() / 2]))
	var cands: Array = []
	for s in rivers.a.size():
		var w := float(rivers.width[s])
		if w < wmin - 0.01 or w > wmax or rivers.salty[s] == 1:
			_why("stream")
			continue
		var mid := (rivers.a[s] + rivers.b[s]).normalized()
		var cell := map.cell_at(mid)
		if not biomes.has(map.biome[cell]):
			_why("biome")
			continue
		if map.temp_c[cell] < float(trange[0]) or map.temp_c[cell] > float(trange[1]):
			_why("climate")
			continue
		if map.moisture[cell] < float(P.get("moisture_min", 0.25)):
			_why("dry")
			continue
		# Its reach: either bank of the segment's middle.
		var t1 := _tangent(rivers.a[s], rivers.b[s], mid)
		var side := mid.cross(t1).normalized()
		for sg: float in [1.0, -1.0]:
			cands.append([s, mid, side * sg, 0.0, false])
		# Its bend into the next segment, both banks.
		var k := int(rivers.down_seg[s])
		if k >= 0:
			var j := rivers.b[s]
			var u1 := _tangent(rivers.a[s], rivers.b[s], j)
			var u2 := _tangent(rivers.a[k], rivers.b[k], j)
			var turn := rad_to_deg(acos(clampf(u1.dot(u2), -1.0, 1.0)))
			if turn > 4.0:
				var inn := (u2 - u1)
				inn = (inn - j * inn.dot(j)).normalized()
				cands.append([s, j, inn, turn, true])
				cands.append([s, j, -inn, turn, false])
	report.candidates = cands.size()
	var scored: Array = []
	for c in cands:
		var s: int = c[0]
		var half := float(rivers.width[s]) * 0.5
		var off: Vector3 = c[2]
		var site_d: Vector3 = (c[1] + off * (half + front_m) / PlanetConst.RADIUS_M).normalized()
		var why := gate(map, site_d)
		if why == "" and not _roomy(map, rivers, site_d):
			why = "cramped"
		if why != "":
			_why(why)
			continue
		var sc := score(map, rivers, site_d, -off, s, float(c[3]), bool(c[4]))
		report.scored += 1
		scored.append([float(sc.total), site_d, -off, s, sc])
	scored.sort_custom(func(x, y): return x[0] > y[0])
	var scale := PlanetConst.CIRCUMFERENCE_M / 400000.0
	var spacing := maxf(float(P.get("min_spacing_m", 6000.0)) * scale, float(P.get("min_spacing_floor_m", 1500.0)))
	var cap := int(P.get("per_world_max", 12))
	var min_score := float(P.get("min_score", 1.6))
	for e in scored:
		if report.best.size() < 8:
			report.best.append(snappedf(float(e[0]), 0.01))
		if _sites.size() >= cap or float(e[0]) < min_score:
			break
		var dd: Vector3 = e[1]
		var close := false
		for k in _sites:
			if CubeSphere.surface_distance_m(k.dir, dd) < spacing:
				close = true
				break
		if close:
			continue
		var sc: Dictionary = e[4]
		var id := "v%d" % posmod(hash([map.terrain.world_seed, dd.snapped(Vector3.ONE * 1e-6)]), 100000000)
		_sites.append({"id": id, "dir": dd, "front": e[2], "seg": e[3], "score": e[0], "terms": sc.terms,
			"builds": sc.builds, "seed": hash([id, "village"]), "archetype": str(P.get("archetype", "stream_gutter_town")),
			"river": sc.river})
	report.kept = _sites.size()


static func _why(r: String) -> void:
	report.why[r] = int(report.why.get(r, 0)) + 1


## The unit tangent at `at` along a -> b.
static func _tangent(a: Vector3, b: Vector3, at: Vector3) -> Vector3:
	var t := b - a
	return (t - at * t.dot(at)).normalized()


## Why `d` can't hold a village ("" if it can): water, too steep or too
## flat for gutters to run, a ruin too near.
static func gate(map: PlanetData, d: Vector3) -> String:
	var cell := map.cell_at(d)
	if map.water[cell] == PlanetData.Water.OCEAN or map.water[cell] == PlanetData.Water.LAKE:
		return "water"
	# The village's ground: its grade from the middle out 50 m, eight ways.
	var e0 := map.terrain.elevation(d, true)
	var g := 0.0
	var gmax := 0.0
	for k in 8:
		var q := CreatureSpawner._offset(d, k * TAU / 8.0, 50.0)
		var gr := absf(map.terrain.elevation(q, true) - e0) / 50.0
		g += gr
		gmax = maxf(gmax, gr)
	g /= 8.0
	var gr_range: Array = P.get("grade_range", [0.012, 0.16])
	if g < float(gr_range[0]):
		return "flat"
	if g > float(gr_range[1]) or gmax > float(gr_range[1]) * 2.2:
		return "steep"
	if not Ruins.near(map, d, float(P.get("keep_off_m", 350.0))).is_empty():
		return "ruin"
	return ""


## Room to grow (§EE.3): of 32 spots on rings 15-60 m round `d`, at least
## three in five on dry ground off the stream's bank and not steep.
static func _roomy(map: PlanetData, rivers: RiverNetwork, d: Vector3) -> bool:
	var keep := float((V.get("plan", {}) as Dictionary).get("bank_keep_m", 14.0))
	var segs := rivers.segments_near(map, map.cell_at(d))
	var good := 0
	for ring in [15.0, 30.0, 45.0, 60.0]:
		for k in 8:
			var q := CreatureSpawner._offset(d, k * TAU / 8.0 + ring * 0.01, ring)
			var wet := false
			for s in segs:
				if rivers.closest_dt(s, q).x < float(rivers.width[s]) * 0.5 + keep:
					wet = true
					break
			if wet or map.water[map.cell_at(q)] == PlanetData.Water.OCEAN or map.water[map.cell_at(q)] == PlanetData.Water.LAKE:
				continue
			var e := map.terrain.elevation(q, true)
			var q2 := CreatureSpawner._offset(q, k * TAU / 8.0, 6.0)
			if absf(map.terrain.elevation(q2, true) - e) / 6.0 < 0.3:
				good += 1
	return good >= 20


## The siting score of a village at `d` facing `front` (unit tangent, to
## the water) by river segment `seg`, at a bend of `bend_deg` (inside of
## it or not): {"total", "terms": {name: 0-1}, "builds": [...],
## "river": {"dir", "width", "level"}}.
static func score(map: PlanetData, rivers: RiverNetwork, d: Vector3, front: Vector3, seg: int, bend_deg: float, inside: bool) -> Dictionary:
	var W: Dictionary = (V.get("siting", {}) as Dictionary).get("weights", {})
	var e0 := map.terrain.elevation(d, true)
	var back := -front
	var t := {}
	# Ridge behind: the highest ground 80-200 m back.
	var rise := -INF
	for r: float in [80.0, 140.0, 200.0]:
		rise = maxf(rise, _h(map, d, back, r) - e0)
	t["ridge_behind"] = clampf(rise / 14.0, 0.0, 1.0)
	# Arms either side behind.
	var lft := _h(map, d, back.rotated(d, deg_to_rad(55.0)), 120.0) - e0
	var rgt := _h(map, d, back.rotated(d, deg_to_rad(-55.0)), 120.0) - e0
	t["flanking_ridges"] = clampf(minf(lft, rgt) / 8.0, 0.0, 1.0)
	# Open low ground in front: a gentle, even fall toward the water.
	var f15 := _h(map, d, front, 15.0)
	var f30 := _h(map, d, front, 30.0)
	var grade := (e0 - f30) / 30.0
	var rough := absf(f15 - (e0 + f30) * 0.5)
	t["open_front_low_ground"] = clampf(1.0 - absf(grade - 0.05) / 0.07, 0.0, 1.0) * clampf(1.0 - (rough - 0.4) / 1.2, 0.0, 1.0)
	# The stream in front.
	var dt := rivers.closest_dt(seg, d)
	var wd := dt.x - float(rivers.width[seg]) * 0.5
	t["water_in_front"] = clampf(1.0 - maxf(0.0, maxf(25.0 - wd, wd - 90.0)) / 40.0, 0.0, 1.0)
	var bend := clampf(bend_deg / 35.0, 0.0, 1.0)
	t["inside_of_river_bend"] = bend if inside else 0.0
	t["outer_eroding_bank"] = bend if not inside and bend_deg > 4.0 else 0.0
	# Sun-facing: the ground falls toward the equator.
	var east := CubeSphere.east(d)
	var north := CubeSphere.north(d)
	var gx := (_h(map, d, east, 20.0) - _h(map, d, -east, 20.0)) / 40.0
	var gz := (_h(map, d, north, 20.0) - _h(map, d, -north, 20.0)) / 40.0
	var downhill := -(east * gx + north * gz)
	var slope := downhill.length()
	var lat := asin(clampf(d.y, -1.0, 1.0))
	var sunward := -north * signf(lat) if absf(lat) > 0.02 else Vector3.ZERO
	t["sun_facing_slope"] = maxf(0.0, (downhill / maxf(slope, 1e-6)).dot(sunward)) * clampf(slope / 0.04, 0.0, 1.0)
	# Out of the wind: higher ground upwind.
	var wind: Vector3 = map.wind_avg[map.cell_at(d)]
	wind = wind - d * wind.dot(d)
	if wind.length() > 0.8:
		var upwind := -wind.normalized()
		var up_rise := maxf(_h(map, d, upwind, 120.0), _h(map, d, upwind, 200.0)) - e0
		t["shelter_from_prevailing_wind"] = clampf(up_rise / 8.0, 0.0, 1.0)
	else:
		t["shelter_from_prevailing_wind"] = 0.5
	# Fast, straight water: a steep reach that doesn't bend.
	var seg_len := CubeSphere.surface_distance_m(rivers.a[seg], rivers.b[seg])
	var drop := float(rivers.level_a[seg]) - float(rivers.level_b[seg])
	var fast := clampf((drop / maxf(seg_len, 1.0)) / 0.02, 0.0, 1.0)
	if not rivers.falls(seg).is_empty():
		fast = 1.0
	t["fast_straight_water"] = fast * (1.0 - bend)
	# Above the flood: ground well over the water.
	var lvl := rivers.level_at(seg, dt.y)
	t["flood_level"] = clampf(1.0 - (e0 - lvl - 1.5) / 3.0, 0.0, 1.0)
	var total := 0.0
	for k in t:
		total += float(W.get(k, 0.0)) * float(t[k])
	var builds: Array = []
	if float(t.ridge_behind) < 0.25:
		builds.append("raised_mound_behind")
	if float(t.water_in_front) < 0.5:
		builds.append("dug_pond_in_front")
	var rp: Vector3 = (rivers.a[seg] + (rivers.b[seg] - rivers.a[seg]) * dt.y).normalized()
	return {"total": total, "terms": t, "builds": builds, "river": {"dir": rp, "width": float(rivers.width[seg]), "level": lvl, "seg": seg}}


## The ground `m` metres from `d` toward tangent `dir`.
static func _h(map: PlanetData, d: Vector3, dir: Vector3, m: float) -> float:
	return map.terrain.elevation((d + dir * m / PlanetConst.RADIUS_M).normalized(), true)
