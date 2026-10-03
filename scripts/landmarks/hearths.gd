class_name Hearths
## A few hearths in every biome, no two alike (design 3 Oct §CU,
## data/camps.json hearths). Hearths are the living camps and the old
## hearths of ruins together: an inhabited ruin's camp, an empty ruin's cold
## hearth (OldHearths), a nest's camp or its remains (Nests, §CK).
##
## The sites pass (warm(), once per world, kept in its save as "hearths"):
##   - every ruin on the planet (Ruins) and every nest holding a camp or
##     remains (Nests) is a candidate, with its biome, its land (RealmMap
##     province), the plant community there (Communities, §CS), its people
##     (a living camp's; none for an old hearth), its nest kind and its
##     ruin kind;
##   - each land biome keeps max(per_land_biome_min, its km2 /
##     km2_per_hearth) of its candidates, dealt round its lands in turn so
##     they spread, in a seeded order, never two with the same people,
##     nest, ruin kind and community (never_repeat);
##   - the opening camp's people's camp (its road's end, §BX) is always
##     kept.
## The rest stand without a hearth: a ruin no one lives at and with no
## cold fire (Ruins.inhabited() is false for it, OldHearths builds none), a
## nest with no camp and no remains. Every ruin still leads down into its
## delve (§CJ).
##
## Before warm() (and with hearths off) every candidate counts, as before.

static var CFG: Dictionary = Tuning.table("camps").get("hearths", {})
## The kept candidates' keys ("ruin:<seed>", a nest's key).
static var keep := {}
static var active := false
## Bumped each warm (Nests re-reads its cached states against it).
static var version := 0
## After a fresh pass, what it found (the check reads it): per biome
## {"target", "kept", "candidates", "short"}; and the total before/after.
static var report := {}
static var _seed := -1


## Run the sites pass for this world (or take it from the save). `forced`:
## ruin directions that must stay hearths (the opening road's camp).
static func warm(world: Node, forced: Array = []) -> void:
	var map: PlanetData = world.planet
	if active and _seed == map.terrain.world_seed:
		return
	if not bool(CFG.get("on", true)) or OS.get_environment("HEARTHS") == "0":
		return
	_seed = map.terrain.world_seed
	var saved = WorldSave.data.get("hearths", null)
	if saved is Dictionary and int((saved as Dictionary).get("seed", -1)) == _seed and (saved as Dictionary).get("keys", null) is Array:
		keep.clear()
		for k in saved.keys:
			keep[str(k)] = true
		for d in forced:
			keep[ruin_key_at(map, d)] = true
		active = true
		version += 1
		return
	_pass(map, forced)
	WorldSave.data["hearths"] = {"seed": _seed, "keys": keep.keys()}


static func _pass(map: PlanetData, forced: Array) -> void:
	active = false
	keep.clear()
	report.clear()
	Communities.warm(map)
	var rivers := Encampment.rivers_for(map)
	var cand: Array = []
	# Ruins.
	var cpf := Ruins.cells_per_face()
	for f in 6:
		for i in cpf:
			for j in cpf:
				var s := Ruins.find(map, Vector3i(f, i, j))
				if s.is_empty():
					continue
				var d: Vector3 = s.dir
				var b := map.biome[map.cell_at(d)]
				var lived := Ruins.rolls_inhabited(s)
				cand.append({"key": "ruin:%d" % int(s.seed), "dir": d, "biome": b, "land": RealmMap.province_at(d),
					"people": Peoples.pick(map, rivers, d, "ruin") if lived else "", "nest": "", "ruin": Ruins.site_name(s),
					"community": Communities.at(d, b), "lived": lived})
	# Nests with a camp or remains.
	if Nests.terrain == map.terrain:
		for kind in Nests.KINDS:
			var cp := CreatureSpawner._cells_per_face(Nests.cell_m(kind))
			for f in 6:
				for i in cp:
					for j in cp:
						var n := Nests.find(kind, Vector3i(f, i, j))
						if n.is_empty() or not str(n.get("raw_state", n.state)) in ["lived", "remains"]:
							continue
						var h: Vector3 = n.hearth
						var b := map.biome[map.cell_at(h)]
						var lived := str(n.get("raw_state", n.state)) == "lived"
						cand.append({"key": str(n.key), "dir": h, "biome": b, "land": RealmMap.province_at(h),
							"people": str(n.get("people", "")) if lived else "", "nest": str(kind), "ruin": "",
							"community": Communities.at(h, b), "lived": lived})
	# The biomes' ground.
	var km2 := pow(map.cell_m() / 1000.0, 2.0)
	var area := {}
	for c in map.cell_count:
		if map.water[c] == PlanetData.Water.OCEAN or map.water[c] == PlanetData.Water.LAKE:
			continue
		area[map.biome[c]] = float(area.get(map.biome[c], 0.0)) + km2
	var mn := int(CFG.get("per_land_biome_min", 2))
	var per := float(CFG.get("km2_per_hearth", 150.0))
	var fields: Array = CFG.get("never_repeat", ["people", "nest", "ruin_kind", "community"])
	var used := {}
	# The forced ones first.
	var forced_keys := {}
	for d in forced:
		forced_keys[ruin_key_at(map, d)] = true
	var by_biome := {}
	for c in cand:
		if forced_keys.has(c.key):
			keep[c.key] = true
			used[_combo(c, fields)] = true
		by_biome.get_or_add(int(c.biome), []).append(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map.terrain.world_seed, "hearths"])
	var total_before := cand.size()
	var bs := by_biome.keys()
	bs.sort()
	for b in bs:
		var list: Array = by_biome[b]
		var target := maxi(mn, roundi(float(area.get(b, 0.0)) / per))
		# A seeded order, then round the lands in turn.
		for c in list:
			c["r"] = rng.randf()
		list.sort_custom(func(x, y): return float(x.r) < float(y.r))
		var by_land := {}
		for c in list:
			by_land.get_or_add(int(c.land), []).append(c)
		var lands := by_land.keys()
		lands.sort()
		var kept := 0
		for c in list:
			if keep.has(c.key):
				kept += 1
		var progress := true
		while kept < target and progress:
			progress = false
			for l in lands:
				if kept >= target:
					break
				var q: Array = by_land[l]
				while not q.is_empty():
					var c: Dictionary = q.pop_front()
					if keep.has(c.key):
						continue
					var combo := _combo(c, fields)
					if used.has(combo):
						continue
					used[combo] = true
					keep[c.key] = true
					kept += 1
					progress = true
					break
		# "exhausted": every candidate was taken or would repeat a hearth
		# already kept (never_repeat), so the biome is short for want of
		# distinct sites, not by the pass.
		report[int(b)] = {"target": target, "kept": kept, "candidates": list.size(), "area_km2": float(area.get(b, 0.0)), "short": maxi(target - kept, 0), "exhausted": kept < target}
	# Land biomes with no candidates at all.
	for b in area:
		if not report.has(int(b)) and not BiomeTemplates.is_ocean(int(b)):
			report[int(b)] = {"target": maxi(mn, roundi(float(area[b]) / per)), "kept": 0, "candidates": 0, "area_km2": float(area[b]), "short": maxi(mn, roundi(float(area[b]) / per))}
	report["_total"] = {"before": total_before, "after": keep.size()}
	active = true
	version += 1


static func _combo(c: Dictionary, fields: Array) -> String:
	var parts: PackedStringArray = []
	for f in fields:
		match str(f):
			"people":
				parts.append(str(c.people))
			"nest":
				parts.append(str(c.nest))
			"ruin_kind":
				parts.append(str(c.ruin))
			"community":
				parts.append(str(c.community))
	return "|".join(parts)


## The key of the ruin standing at (or within 60 m of) direction `d`.
static func ruin_key_at(map: PlanetData, d: Vector3) -> String:
	for s in Ruins.near(map, d, 60.0):
		return "ruin:%d" % int(s.seed)
	return ""


## Does ruin `site` keep its hearth (before warm(): every ruin does)?
static func ruin_kept(site: Dictionary) -> bool:
	return not active or keep.has("ruin:%d" % int(site.get("seed", 0)))


## Does the nest with this key keep its camp or remains?
static func nest_kept(key: String) -> bool:
	return not active or keep.has(key)
