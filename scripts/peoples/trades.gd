class_name Trades
## The trades that follow (design 5 Oct §EI.3, camps.json → sim.trades):
## cordage and basketry, pottery, leather and hide, woodwork, textiles,
## the lighting trade, stone, in the order they really arrive. A trade is
## PRESENT at a camp (present()) when:
##   - the camp is at or past its row's rung (sim.ladder);
##   - every one of its needs holds, read from the place (reach(): the
##     plants of the biomes, the rock, the soil and the water within
##     loop.gather_reach_m; gates says how each is read);
##   - every trade it comes after is present;
##   - the people's huts.trades lists it;
##   - a generalist false trade has the camp's maker (§BN) to work it.
## At most show_max show: cordage first, then the maker's trade with what
## it comes after, then the rest in order (pick_shown, Mike 5 Oct); a
## trade once present stays while
## its rung, maker and earlier trades hold (sticky: a thin woodpile does
## not end a pottery tradition). The maker's station is the first
## non-generalist trade's bench (maker_bench()). Nothing here is a market,
## money or a chief (§EI.4; CampSim's header).

static var T: Dictionary = (Tuning.section("camps", "sim").get("trades", {}) as Dictionary)
static var G: Dictionary = (T.get("gates", {}) as Dictionary)


static func order() -> Array:
	return T.get("order", [])


static func row(id: String) -> Dictionary:
	for r in order():
		if str((r as Dictionary).get("id", "")) == id:
			return r
	return {}


static func rung_of(name: String) -> int:
	var lad: Array = CampSim.SIM.get("ladder", ["fire", "food", "storage", "specialist", "exchange"])
	return maxi(lad.find(name), 0)


## What the place gives within gather reach (cached in st.reach): fibre,
## bark, clay, timber, stone, oil, resin, coast. From the map's cells at
## the fire and gather_reach_m out round it.
static func reach(st: Dictionary, map: PlanetData, rivers: RiverNetwork = null) -> Dictionary:
	if st.get("reach_facts", null) is Dictionary and not (st.reach_facts as Dictionary).is_empty():
		return st.reach_facts
	var a: Array = st.get("dir", [0.0, 1.0, 0.0])
	var d := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
	var r := float((CampSim.SIM.get("loop", {}) as Dictionary).get("gather_reach_m", 300.0))
	var pts: Array = [d]
	for k in 8:
		pts.append(CreatureSpawner._offset(d, TAU * k / 8.0, r))
	var biomes := {}
	var rocks := {}
	var soils := {}
	var coast := false
	var fresh := false
	for p: Vector3 in pts:
		var c := map.cell_at(p)
		biomes[int(map.biome[c])] = true
		rocks[PlanetData.Rock.keys()[clampi(int(map.rock[c]), 0, PlanetData.Rock.size() - 1)]] = true
		soils[PlanetData.Rock.keys()[clampi(map.soil_at(p), 0, PlanetData.Rock.size() - 1)]] = true
		if int(map.water[c]) == PlanetData.Water.OCEAN:
			coast = true
		elif int(map.water[c]) in [PlanetData.Water.LAKE, PlanetData.Water.RIVER]:
			fresh = true
	# The rivers (§BE): a bank within clay_from_water_m.
	var cw := float(G.get("clay_from_water_m", 300.0))
	if not fresh and rivers != null:
		for seg in rivers.segments_near(map, map.cell_at(d)):
			if CubeSphere.surface_distance_m(rivers.closest(seg, d), d) <= cw:
				fresh = true
				break
	var genera := {}
	var trees := false
	for sp in SpeciesDB.all():
		for b in biomes:
			if sp.biomes.has(int(b)):
				genera[sp.genus] = true
				if sp.tier == PlantSpecies.Tier.EMERGENT or sp.tier == PlantSpecies.Tier.CANOPY:
					trees = true
				break
	var resin: Array = (G.get("resin_genera", []) as Array).duplicate()
	resin.append_array(Techniques.params("resin_torch").get("conifer_genera", []))
	var facts := {
		"fibre": _any(genera, G.get("fibre_genera", [])),
		"bark": _any(genera, G.get("bark_genera", [])),
		"oil": _any(genera, G.get("oil_genera", [])),
		"resin": _any(genera, resin),
		"timber": trees or coast,
		"clay": _any(soils, G.get("clay_soils", [])) or fresh,
		"stone": _any(rocks, G.get("fine_stone_rocks", [])),
		"coast": coast,
		"fresh": fresh,
	}
	st["reach_facts"] = facts
	return facts


static func _any(have: Dictionary, want: Array) -> bool:
	for w in want:
		if have.has(str(w)):
			return true
	return false


static func has_maker(st: Dictionary) -> bool:
	for f in st.get("folk", []):
		if str((f as Dictionary).get("role", "")) == "maker":
			return true
	return false


## Does need `n` hold at camp `st` (its place's `facts`)?
static func need(n: String, st: Dictionary, facts: Dictionary, people: Dictionary) -> bool:
	var herd := str(people.get("fundamental", "")) == "herd"
	match n:
		"fibre_or_bark_in_reach":
			return bool(facts.get("fibre", false)) or bool(facts.get("bark", false))
		"clay_in_reach":
			return bool(facts.get("clay", false))
		"fuel_surplus":
			var store: Dictionary = CampSim.SIM.get("store", {})
			return float(st.get("wood", 0.0)) >= float(G.get("fuel_surplus_nights", 3)) * float(store.get("wood_units_per_night", 4.0))
		"hunt_or_herd":
			return herd or int(st.get("hunts", 0)) > 0
		"timber_in_reach":
			return bool(facts.get("timber", false))
		"fibre_crop_or_wool_herd":
			if herd:
				return true
			var sp_i := int(st.get("plot_species", -1))
			if bool(st.get("plot", false)) and sp_i >= 0 and sp_i < SpeciesDB.all().size():
				return (G.get("fibre_crop_genera", []) as Array).has(SpeciesDB.all()[sp_i].genus)
			return false
		"fat_or_oil_or_resin":
			return int(st.get("fat_pieces", 0)) > 0 or bool(facts.get("oil", false)) or bool(facts.get("resin", false))
		"flint_obsidian_or_fine_stone_in_reach":
			return bool(facts.get("stone", false))
	return false


## The trades present at camp `st` now, in trades.order, at most show_max.
static func present(st: Dictionary, facts: Dictionary) -> Array:
	var people := Peoples.get_people(str(st.get("people", "")))
	var listed: Array = (people.get("huts", {}) as Dictionary).get("trades", [])
	var had: Array = st.get("trades_had", [])
	var maker := has_maker(st)
	var out: Array = []
	for rv in order():
		var r: Dictionary = rv
		var id := str(r.get("id", ""))
		if not listed.has(id):
			continue
		if int(st.get("rung", 0)) < rung_of(str(r.get("rung", "storage"))):
			continue
		if not bool(r.get("generalist", true)) and not maker:
			continue
		var ok := true
		for a in r.get("after", []):
			if not out.has(str(a)):
				ok = false
		if not ok:
			continue
		if not had.has(id):
			for n in r.get("needs", []):
				if not need(str(n), st, facts, people):
					ok = false
					break
		if ok:
			out.append(id)
	return pick_shown(out, int(T.get("show_max", 3)))


## Which of the eligible trades `all` (in order) a camp shows, at most
## `n` (Mike, 5 Oct: the fundamental ones first, then what makes sense):
## cordage and basketry first (half a fundamental, §EI.3); then the
## camp's maker trade (the first non-generalist) with every trade it
## comes after; then the rest in trades.order. Returned in trades.order.
static func pick_shown(all: Array, n: int) -> Array:
	var chosen: Array = []
	if all.has("cordage_basketry"):
		chosen.append("cordage_basketry")
	for id in all:
		var r := row(str(id))
		if bool(r.get("generalist", true)):
			continue
		var need: Array = _chain(str(id), all)
		var extra: Array = need.filter(func(x): return not chosen.has(x))
		if chosen.size() + extra.size() <= n:
			for x in extra:
				chosen.append(x)
		break
	for id in all:
		if chosen.size() >= n:
			break
		if not chosen.has(id):
			chosen.append(id)
	var out: Array = []
	for id in all:
		if chosen.has(id):
			out.append(id)
	return out


## Trade `id` and every trade it comes after, recursively, among `all`.
static func _chain(id: String, all: Array) -> Array:
	var out: Array = [id]
	for a in row(id).get("after", []):
		if all.has(str(a)):
			for x in _chain(str(a), all):
				if not out.has(x):
					out.append(x)
	return out


## Once a tick (CampSim): the camp's trades, remembered.
static func update(st: Dictionary, map: PlanetData, rivers: RiverNetwork = null) -> void:
	if map == null:
		return
	var now := present(st, reach(st, map, rivers))
	var had: Array = st.get("trades_had", [])
	for id in now:
		if not had.has(id):
			had.append(id)
	st["trades_had"] = had
	if not st.has("trades") or now != (st.trades as Array):
		st["trades"] = now
		WorldSave.mark_dirty()


## The maker's station: the bench of the first non-generalist trade
## present (soft, hard, hearth or kiln), else "".
static func maker_bench(st: Dictionary) -> String:
	for id in st.get("trades", []):
		var r := row(str(id))
		if not bool(r.get("generalist", true)):
			return str(r.get("bench", ""))
	return ""


## The visible props of the present trades for `bench`, in order, at most
## visible_per_trade each, as phrases ("cord_hank" -> "cord hank").
static func visible_for(st: Dictionary, bench: String) -> Array:
	var out: Array = []
	for id in st.get("trades", []):
		var r := row(str(id))
		if str(r.get("bench", "")) != bench:
			continue
		var vis: Array = r.get("visible", [])
		for i in mini(vis.size(), int(G.get("visible_per_trade", 3))):
			out.append(str(vis[i]).replace("_", " "))
	return out
