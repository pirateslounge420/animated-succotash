class_name CragFortress
## The crag fortress (design 3 Oct §DO, data/ruins.json styles.crag_fortress):
## its own kind of ruin (Ruins.Kind.CRAG_FORTRESS, "Crag fortress" in
## play), a fortress-monastery climbing a rock rise in tiers, in high, cold,
## dry country. This is its sites pass: once per world, every ruin cell of
## the planet (Ruins.CELL_M) is tried against the entry's spawn gate, and
## those that pass and win their seeded `chance` roll are kept, the
## best-placed first, never more than per_world_max. Ruins.find() returns
## the kept one in its cell in place of whatever ruin would stand there.
##
## The gate (gate()), at the most prominent dry point of the cell:
##   biome   one of spawn.biomes (puna, cold desert, steppe, alpine meadow,
##           krummholz);
##   realm   one of spawn.realm (RealmMap.realm: central_asia,
##           east_asia_temperate, andes, palearctic);
##   needs   "crag": a rise, prominence over CRAG_MIN_M above the ground
##           200 m round (the builder raises its own rock on it: §DO lets
##           it); "altitude": at least ALT_MIN_REAL_M real metres up
##           (RealmMap's andes line), i.e. a tenth of that here;
##   never   "flat" (the crag rule again), "wet" (moisture over WET_MAX),
##           "warm" (a mean year over WARM_MAX_C);
##   and never on water. The nests §DO names (kopje, volcanic neck, mesa)
##   aren't built yet (only the escarpment is), so the builder's own rise
##   is how every one stands for now.
## Pure functions of the planet once warmed; thread-safe after it.

const CRAG_MIN_M := 6.0
const ALT_MIN_REAL_M := 1500.0
const WET_MAX := 0.55
const WARM_MAX_C := 14.0

static var E: Dictionary = (Tuning.table("ruins").get("styles", {}) as Dictionary).get("crag_fortress", {})
static var _mutex := Mutex.new()
static var _for_seed := -1
static var _for_map: PlanetData = null
## Ruin cell (Vector3i) -> the site dictionary (Ruins.find's shape).
static var _sites := {}
## Tools: every cell that passed the gate before the roll and the cap,
## and how many were turned away by each reason.
static var report := {}


static func spawn() -> Dictionary:
	return E.get("spawn", {})


## Why point `p` can't hold a crag fortress ("" if it can).
static func gate(map: PlanetData, p: Vector3) -> String:
	var cell := map.cell_at(p)
	if map.water[cell] != PlanetData.Water.NONE:
		return "water"
	var sp := spawn()
	var bkey: String = BiomeTemplates.KEYS[map.biome[cell]]
	if not (sp.get("biomes", []) as Array).has(bkey):
		return "biome"
	var never: Array = sp.get("never", [])
	if never.has("wet") and map.moisture[cell] > WET_MAX:
		return "wet"
	if never.has("warm") and map.temp_c[cell] > WARM_MAX_C:
		return "warm"
	var e := map.terrain.elevation(p, true, false, false)
	var needs: Array = sp.get("needs", [])
	if needs.has("altitude") and e < ALT_MIN_REAL_M * PlanetConst.HEIGHT_SCALE:
		return "altitude"
	var realm := RealmMap.realm(RealmMap.world_at(p), p, map.temp_c[cell], map.moisture[cell], e / PlanetConst.HEIGHT_SCALE)
	if not (sp.get("realm", []) as Array).has(realm):
		return "realm"
	if needs.has("crag") or never.has("flat"):
		if prominence(map, p) < CRAG_MIN_M:
			return "flat"
	return ""


## Height above the ground 200 m round.
static func prominence(map: PlanetData, p: Vector3) -> float:
	var e := map.terrain.elevation(p, true, false, false)
	var ring := 0.0
	for k in 6:
		ring += map.terrain.elevation(CreatureSpawner._offset(p, k * TAU / 6.0, 200.0), true, false, false)
	return e - ring / 6.0


## The kept site in ruin cell `c`, or {}.
static func site_in(map: PlanetData, c: Vector3i) -> Dictionary:
	_ensure(map)
	_mutex.lock()
	var s: Dictionary = _sites.get(c, {})
	_mutex.unlock()
	return s


## Every kept site this world: [site...].
static func all_sites(map: PlanetData) -> Array:
	_ensure(map)
	_mutex.lock()
	var out: Array = _sites.values()
	_mutex.unlock()
	return out


static func _ensure(map: PlanetData) -> void:
	if map == null or map.terrain == null:
		return
	var sd := int(map.terrain.world_seed)
	_mutex.lock()
	var fresh := _for_seed == sd and _for_map == map
	_mutex.unlock()
	if fresh:
		return
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
	report = {"cells": 0, "passed": 0, "rolled": 0, "kept": 0, "why": {}}
	if E.is_empty():
		return
	RealmMap.warm(int(map.terrain.world_seed))
	var n := Ruins.cells_per_face()
	var sp := spawn()
	var biomes: Array = sp.get("biomes", [])
	var chance := float(E.get("chance", 0.3))
	var cap := int(E.get("per_world_max", 4))
	var cand: Array = []
	for f in 6:
		for i in n:
			for j in n:
				var c := Vector3i(f, i, j)
				report.cells += 1
				var center := CreatureSpawner._cell_point(c, n, Ruins.SALT)
				# A cheap first look: the cell's middle must be in one of the
				# biomes (a crag fortress's land is wide country).
				var bkey: String = BiomeTemplates.KEYS[map.biome[map.cell_at(center)]]
				if not biomes.has(bkey):
					continue
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([Vector4i(-2, c.x, c.y, c.z), "crag"])
				var best := {}
				var best_p := -INF
				var why := ""
				for t in 14:
					var p := CreatureSpawner._offset(center, rng.randf() * TAU, sqrt(rng.randf()) * Ruins.CELL_M * 0.35)
					var g := gate(map, p)
					if g != "":
						why = g
						continue
					var pr := prominence(map, p)
					if pr > best_p:
						best_p = pr
						best = {"dir": p, "prominence": pr}
				if best.is_empty():
					report.why[why] = int(report.why.get(why, 0)) + 1
					continue
				report.passed += 1
				var roll := rng.randf()
				if roll >= chance:
					continue
				report.rolled += 1
				cand.append([roll - best_p * 0.001, c, best, rng.randi()])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for k in mini(cand.size(), cap):
		var c: Vector3i = cand[k][1]
		var best: Dictionary = cand[k][2]
		var site := make_site(map, c, best.dir, int(cand[k][3]))
		# Its delve's ground (design 1 Oct §CJ).
		if Delves.has_delve(site):
			Delves.decorate(map, site)
		_sites[c] = site
	report.kept = _sites.size()


## The site's measurements, from its seed: the rise and tiers (ruins.json
## rise_m, tiers), its footprint and the ground it keeps clear (the rock
## and the lesser buildings at its foot, out toward the approach).
static func make_site(map: PlanetData, c: Vector3i, d: Vector3, s: int) -> Dictionary:
	var key := Vector4i(-2, c.x, c.y, c.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, "crag_site", s])
	var rr: Array = E.get("rise_m", [40, 100])
	var tr: Array = E.get("tiers", [3, 6])
	var rise := rng.randf_range(float(rr[0]), float(rr[1]))
	var tiers := clampi(int(round(lerpf(float(tr[0]), float(tr[1]), (rise - float(rr[0])) / maxf(float(rr[1]) - float(rr[0]), 1.0)))) + rng.randi_range(-1, 0), int(tr[0]), int(tr[1]))
	var hs := clampf(rise * 0.42 + 8.0, 22.0, 50.0)
	# It faces the sun (the equator's side), as such houses on a crag do,
	# a little either way: its climb and its windows in the light, its
	# shaded side (lichen) behind.
	var sunward := -CubeSphere.north(d) if CubeSphere.latitude(d) >= 0.0 else CubeSphere.north(d)
	var heading := 0.0
	var best_dot := -2.0
	for i in 36:
		var hd := TAU * i / 36.0
		var a := hd + PI * 0.5
		var exv := CubeSphere.north(d) * cos(a) + CubeSphere.east(d) * sin(a)
		var front := -exv.cross(d).normalized()
		if front.dot(sunward) > best_dot:
			best_dot = front.dot(sunward)
			heading = hd
	heading += rng.randf_range(-0.35, 0.35)
	var site := {"dir": d, "kind": Ruins.Kind.CRAG_FORTRESS, "seed": hash(key), "heading": heading,
		"style": "crag_fortress", "rise_m": rise, "tiers": tiers, "base_hs": hs}
	# The rock and the foot's buildings out on the -z side (the approach).
	var foot_out := hs + 14.0
	site.footprint_m = foot_out + 10.0
	site.clear = [[d, hs + 4.0], [Ruins.local_dir(site, 0.0, -foot_out + 4.0), 16.0]]
	return site


# --- The plan: the rock's tiers and the delve's shaft ---------------------------------

## Half the shaft's width (x) the delve climbs in, and the rock kept round
## it on every tier.
const SHAFT_HX := 4.4
const RING_M := 2.6
const TOP_HS := 11.0
## The landings' depth at each end of the shaft, the stairs' lanes.
const LANDING_M := 3.0
const LANE_X := 1.45
## The steepest the stairs inside may climb (tan 38 degrees).
const MAX_SLOPE := 0.78


## The rock and the shaft in the site's frame (Delves.frame: x across, z
## along, y from base_e): {"g_f" (the ground at the front foot), "top_y",
## "y_b" (the rock's buried bottom), "tiers": [{"y0", "y1", "sx", "sz",
## "zc"}], "zs0", "zs1" (the shaft's ends), "front_z" (the front foot)}.
## Pure: the planet and the site.
static func plan(map: PlanetData, site: Dictionary) -> Dictionary:
	var fr := Delves.frame(map, site)
	var rise := float(site.get("rise_m", 60.0))
	var n := int(site.get("tiers", 4))
	var hs := float(site.get("base_hs", 30.0))
	var g_f := Delves._g0(map, fr, 0.0, -hs)
	var g_min := INF
	for i in range(-2, 3):
		for j in range(-2, 3):
			g_min = minf(g_min, Delves._g0(map, fr, hs * i * 0.5, hs * j * 0.5))
	var top_y := g_f + rise
	var tiers: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site.seed, "crag_plan"])
	for k in n:
		var t := float(k) / maxf(n - 1, 1)
		# Each tier its own proportions and a little to one side (a crag,
		# not a stepped pyramid), the shaft always inside it.
		var sx := lerpf(hs, TOP_HS, t) * (rng.randf_range(0.82, 1.12) if k < n - 1 else 1.0)
		var sz := lerpf(hs, TOP_HS, t) * (rng.randf_range(0.85, 1.05) if k < n - 1 else 1.0)
		sx = maxf(sx, TOP_HS)
		sz = maxf(sz, TOP_HS)
		var xc := 0.0
		if k < n - 1:
			xc = rng.randf_range(-1.0, 1.0) * maxf(sx - SHAFT_HX - RING_M - 2.0, 0.0) * 0.45
		# The front steps back faster than the back: the crag's sheer side
		# is behind, the climb in front.
		var zc := (hs - sz) * 0.55
		var y0 := g_min - 3.0 if k == 0 else g_f + rise * k / n
		tiers.append({"y0": y0, "y1": g_f + rise * (k + 1) / n, "sx": sx, "sz": sz, "zc": zc, "xc": xc})
	var top: Dictionary = tiers[n - 1]
	var zs0 := float(top.zc) - float(top.sz) + RING_M
	var zs1 := float(top.zc) + float(top.sz) - RING_M
	return {"g_f": g_f, "top_y": top_y, "y_b": g_min - 3.0, "tiers": tiers, "zs0": zs0, "zs1": zs1,
		"front_z": float((tiers[0] as Dictionary).zc) - float((tiers[0] as Dictionary).sz), "base_e": fr.base_e}


## The delve that climbs (design 3 Oct §DO.3, ruins.json delve: up): in at
## the foot, a passage into the rock to the shaft; flights of stairs
## turning at landings at each end of it, up through the tiers; some
## landings are stores and one a cistern cut into the rock, each with a
## brazier (delves.json fire_holders.by_ruin: brazier); the heart is the
## top chapel over the shaft, the last flight coming up through its floor;
## the way out (§CJ.4) is its door onto the terrace at the top of the
## outside stair. Delves.layout's shape, with "climbs" true.
static func layout(map: PlanetData, site: Dictionary) -> Dictionary:
	var p := plan(map, site)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site.seed, "crag_delve"])
	var g_f := float(p.g_f)
	var top_y := float(p.top_y)
	var zs0 := float(p.zs0)
	var zs1 := float(p.zs1)
	var run := (zs1 - zs0) - 2.0 * LANDING_M
	var rise := top_y - g_f
	var flights := maxi(2, int(ceil(rise / (run * MAX_SLOPE))))
	if flights % 2 == 1:
		flights += 1
	var per := rise / flights
	var pieces: Array = []
	var y := g_f + 0.05
	# 0: the passage in from the front foot to the shaft's front landing.
	var front_z := float(p.front_z)
	var passage := Delves.piece("passage", Vector2(0.0, front_z - 0.6), Vector2(0.0, 1.0), zs0 - front_z + 0.6, 0.95, y, y, Delves.H_STAIR)
	pieces.append(passage)
	# 1: the first landing (the stores: its old hearth is the delve's one
	# safe room, §CJ).
	var landings: Array = []
	var front := true
	var land := _landing(zs0, front, y)
	land.feature = "stores"
	pieces.append(land)
	landings.append(land)
	var cistern_at := rng.randi_range(1, maxi(1, flights - 2))
	for f in flights:
		var lane := LANE_X if front else -LANE_X
		var z0 := zs0 + LANDING_M if front else zs1 - LANDING_M
		var dir := Vector2(0.0, 1.0) if front else Vector2(0.0, -1.0)
		var y1 := y + per
		pieces.append(Delves.piece("stair", Vector2(lane, z0), dir, run, 0.85, y, y1, Delves.H_STAIR))
		y = y1
		front = not front
		if f < flights - 1:
			land = _landing(zs0 if front else zs1, front, y)
			land.feature = "cistern" if f + 1 == cistern_at else ("stores" if rng.randf() < 0.45 else "landing")
			pieces.append(land)
			landings.append(land)
	# The heart: the top chapel over the whole shaft; the last flight comes
	# up through a stairwell in its floor.
	var heart := Delves.piece("heart", Vector2(0.0, zs0 - 0.3), Vector2(0.0, 1.0), zs1 - zs0 + 0.6, SHAFT_HX - 0.3, top_y, top_y, Delves.H_HEART)
	var heart_i := pieces.size()
	pieces.append(heart)
	var last: Dictionary = pieces[heart_i - 1]
	var well_len := (Delves.H_HEART + Delves.SLAB + 0.6) / (per / run)
	# The way out: through the chapel's front wall onto the terrace.
	var exit := Delves.piece("exit", Vector2(0.0, zs0 - 0.3), Vector2(0.0, -1.0), RING_M - 0.2, 0.9, top_y, top_y, Delves.H_STAIR)
	pieces.append(exit)
	var lay := {"ok": true, "climbs": true, "base_e": p.base_e, "pieces": pieces, "holes": [], "exit": exit, "cairn": {},
		"room_i": 1, "heart_i": heart_i, "plan": p, "landings": landings,
		"well": {"lane": float((last.c as Vector2).x), "from": float(last.len) - well_len, "piece": heart_i - 1},
		"door_out": Vector3(0.0, g_f, front_z - 1.2), "top_door": Vector3(0.0, top_y, zs0 - RING_M - 0.4)}
	# The first landing's old hearth, against its far side from the stair.
	var first: Dictionary = pieces[1]
	lay.hearth = Vector3(-LANE_X - 1.3, float(first.y0), float((first.c as Vector2).y))
	# A brazier on every other landing (the fire-holders, §CN).
	var braziers: Array = []
	for i in range(1, landings.size()):
		var l: Dictionary = landings[i]
		var sx := -1.0 if i % 2 == 0 else 1.0
		braziers.append(Vector3(sx * (SHAFT_HX - 1.0), float(l.y0) + 0.9, float((l.c as Vector2).y)))
	lay.braziers = braziers
	# The heart's fire-holder and the find (§AW) at the altar's foot.
	lay.heart_hearth = Vector3(-2.2, top_y, zs1 - 3.2)
	lay.find_kind = "spear" if rng.randf() < 0.5 else "bow"
	lay.find = Vector3(2.0, top_y, zs1 - 1.6)
	lay.feature = "stores"
	return lay


## A landing across the shaft at its front (z from zs0) or back (to zs1)
## end, floor at `y`.
static func _landing(z_end: float, front: bool, y: float) -> Dictionary:
	var zc := z_end + LANDING_M * 0.5 if front else z_end - LANDING_M * 0.5
	return Delves.piece("room", Vector2(-SHAFT_HX + 0.3, zc), Vector2(1.0, 0.0), 2.0 * SHAFT_HX - 0.6, LANDING_M * 0.5 - 0.05, y, y, Delves.H_ROOM)
