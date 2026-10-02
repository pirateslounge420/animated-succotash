extends SceneTree
## The nests on one world (design 1 Oct §CK, Nests), headless, full planet:
##   SEED=7731 godot --headless --path . --script tools/nest_report.gd
## (tools/nest_report.sh runs four seeds.) Generates the planet only (no
## scene), then runs the sites pass over WINDOWS windows of WINDOW_KM
## radius on land, spread over the planet by the seed, and prints: nests by
## kind (and variant); the camp loop's stages (untouched, lived, remains);
## the living camps by people (shelter folk and karst folk must be above
## 0); the remains and their signatures; the share of nests that give roof
## or water holding a living camp (start_budget: about one in four).
## Fails on a lived nest with no hearth or no people, a hearth inside a
## cenote's shaft or a slot's bed, shelter or karst folk at 0, or a kind
## with no nest at all on the four seeds' worth of windows (reported per
## seed; the gate is the sum, in nest_report.sh).

const WINDOWS := 28
const WINDOW_KM := 22.0
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	var world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	world._load_dev_settings()
	world.generate_now(seed_v)
	var map: PlanetData = world.planet
	var rivers := Encampment.rivers_for(map)
	var t0 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 31 + 5
	var windows: Array = []
	var guard := 0
	while windows.size() < WINDOWS and guard < 20000:
		guard += 1
		var z := rng.randf_range(-1.0, 1.0)
		var a := rng.randf() * TAU
		var d := Vector3(sqrt(1.0 - z * z) * cos(a), z, sqrt(1.0 - z * z) * sin(a))
		var c := map.cell_at(d)
		if map.water[c] != PlanetData.Water.NONE and BiomeTemplates.KEYS[map.biome[c]] != "LAGOON":
			continue
		windows.append(d)
	var seen := {}
	var nests: Array = []
	for w in windows:
		for kind in Nests.KINDS:
			for c in CreatureSpawner._cells_around(w, WINDOW_KM * 1000.0, Nests.cell_m(kind)):
				var key := [kind, c]
				if seen.has(key):
					continue
				seen[key] = true
				var n := Nests.find(kind, c)
				if not n.is_empty():
					nests.append(n)
	var ms := Time.get_ticks_msec() - t0
	print("[nests] seed %d · %d windows of %.0f km · %d nests in %.1f s (%.1f ms a cell tried)" % [seed_v, windows.size(), WINDOW_KM, nests.size(), ms / 1000.0, float(ms) / maxf(seen.size(), 1)])
	var by_kind := {}
	var stages := {"untouched": 0, "lived": 0, "remains": 0}
	var by_people := {}
	var remains_people := {}
	var sig_count := 0
	var rw_total := 0
	var rw_lived := 0
	var bad_lived := 0
	var bad_hearth := 0
	for n in nests:
		var label: String = n.kind + ("/" + str(n.variant) if str(n.variant) != "" else "")
		by_kind[label] = int(by_kind.get(label, 0)) + 1
		stages[n.state] = int(stages[n.state]) + 1
		var gives: Array = n.gives
		if gives.has("roof") or gives.has("water"):
			rw_total += 1
			if n.state == "lived":
				rw_lived += 1
		if n.state == "lived":
			var pid := str(n.get("people", ""))
			by_people[pid] = int(by_people.get(pid, 0)) + 1
			if (n.hearth as Vector3) == Vector3.ZERO or pid == "":
				bad_lived += 1
		elif n.state == "remains":
			var rp := str(n.get("people", ""))
			remains_people[rp] = int(remains_people.get(rp, 0)) + 1
			sig_count += Nests.remains_signatures(n).size()
		# The hearth is never in the hazard (camp_loop.never_inside).
		var h: Vector3 = n.hearth
		if h != Vector3.ZERO:
			if n.kind == "cenote" and str(n.variant) == "" and CubeSphere.surface_distance_m(h, n.dir) < float(n.radius_m) + 1.0:
				bad_hearth += 1
			if n.kind == "slot_canyon" and CubeSphere.surface_distance_m(h, n.dir) < float(n.floor_half_m) + 3.0:
				bad_hearth += 1
	var keys := by_kind.keys()
	keys.sort()
	for k in keys:
		print("[nests]   %-30s %d" % [k, by_kind[k]])
	print("[nests] stages: untouched %d · lived %d · remains %d" % [stages.untouched, stages.lived, stages.remains])
	var pk := by_people.keys()
	pk.sort()
	var parts: Array = []
	for k in pk:
		parts.append("%s %d" % [k, by_people[k]])
	print("[nests] camps by people: %s" % ", ".join(parts))
	var rk := remains_people.keys()
	rk.sort()
	var rparts: Array = []
	for k in rk:
		rparts.append("%s %d" % [k, remains_people[k]])
	print("[nests] remains: %d nests, %d signatures laid · by people: %s" % [stages.remains, sig_count, ", ".join(rparts)])
	print("[nests] nests giving roof or water: %d, living camps %d (%.0f%%; start_budget ~25%%)" % [rw_total, rw_lived, 100.0 * rw_lived / maxf(rw_total, 1)])
	print("[nests] COUNTS seed=%d shelter=%d karst=%d lived=%d remains=%d %s" % [seed_v, int(by_people.get("rock_shelter", 0)), int(by_people.get("karst", 0)), stages.lived, stages.remains, " ".join(keys.map(func(k): return "%s=%d" % [k, by_kind[k]]))])
	ok(bad_lived == 0, "every living camp has a hearth and a people (%d without)" % bad_lived)
	ok(bad_hearth == 0, "no hearth in a cenote's shaft or a slot's bed (%d)" % bad_hearth)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
