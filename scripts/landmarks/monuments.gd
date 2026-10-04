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
## Pure functions of the planet once warmed; thread-safe after it.

const KINDS := {"temple_city": Ruins.Kind.TEMPLE_CITY}
const FLAT_MAX := 0.06
const LOWLAND_M := 60.0
const WATER_M := 2500.0
const CRAG_MIN_M := 6.0

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
	return ""


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
	return site
