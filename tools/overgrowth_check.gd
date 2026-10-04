extends SceneTree
## A ruin wears its place (design 3 Oct §DI.2, data/ruins.json overgrowth,
## Overgrowth, RuinBuilder), headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/overgrowth_check.gd
## One castle (the same seed and plan each time) built in three places,
## a real ruin of this world where one stands in that biome, else the same
## castle set down on the place's most typical cell:
##  - in cloud forest (the wettest cell, moisture about 1.0): moss
##    coverage >= 0.6 and ferns > 0;
##  - in hot desert: vine <= 0.05 and no moss;
##  - in tundra (a year's mean under 0 °C): lichen and moss only (no
##    ferns, vines or wall-top plants);
##  - in a temperate wood with a vine species (Ivy): what the vines cost;
##  - everywhere: the shade side's moss more than the sun side's; every
##    placed species passes the place's gate (biome §CA, community §CS,
##    realm, climate); the dressing (ferns, wall-top plants, vines) adds
##    under 20 % to the ruin's triangles and nothing that collides.
## Prints AT= for the walkabout (one wet ruin, one dry).

var fails := 0
var world


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.generate_now(seed_v)
	var map: PlanetData = world.planet
	Delves.setup_world(map)
	RealmMap.warm(seed_v)
	Communities.load_all()
	Communities.warm(map)
	# The table at a few moistures.
	for m: float in [0.0, 0.3, 0.55, 0.8, 1.0]:
		var a := Overgrowth.amounts(m, 15.0)
		print("   moisture %.2f: moss %.2f fern %.2f vine %.2f wall_top %.2f lichen %.2f" % [m, a.moss, a.fern, a.vine, a.wall_top, a.lichen])
	# The real ruins of this world, by biome.
	var real := {}
	var n := Ruins.cells_per_face()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 6000:
		var c := Vector3i(rng.randi() % 6, rng.randi() % n, rng.randi() % n)
		var f := Ruins.find(map, c)
		if f.is_empty() or not int(f.kind) in [Ruins.Kind.CASTLE, Ruins.Kind.TOWER, Ruins.Kind.AQUEDUCT]:
			continue
		var key: String = BiomeTemplates.KEYS[map.biome[map.cell_at(f.dir)]]
		if not real.has(key) or int(f.kind) == Ruins.Kind.CASTLE:
			real[key] = f
	var places := [
		["cloud forest", "CLOUD_FOREST", "wet"],
		["hot desert", "HOT_DESERT", "dry"],
		["tundra", "TUNDRA", "cold"],
		["temperate wood", "TEMPERATE_DECIDUOUS", "vine"],
	]
	var results := {}
	for pl in places:
		var site := _site_for(map, real, str(pl[1]), str(pl[2]))
		if site.is_empty():
			ok(false, "%s: a cell to build on" % pl[0])
			continue
		results[pl[2]] = _measure(map, site, str(pl[0]))
	var wet: Dictionary = results.get("wet", {})
	var dry: Dictionary = results.get("dry", {})
	var cold: Dictionary = results.get("cold", {})
	if not wet.is_empty():
		ok(float(wet.moss_cov) >= 0.6 and int(wet.ferns) > 0, "cloud forest (moisture %.2f): moss coverage %.2f (>= 0.6), %d ferns" % [float(wet.og.moisture), float(wet.moss_cov), int(wet.ferns)])
	if not dry.is_empty():
		ok(float(dry.vine) <= 0.05 and float(dry.moss_cov) < 0.01, "hot desert (moisture %.2f): vine %.3f (hung at %d of %d places), moss coverage %.3f" % [float(dry.og.moisture), float(dry.vine), int(dry.ivy_kept), int(dry.ivy_places), float(dry.moss_cov)])
	if not cold.is_empty():
		ok(bool(cold.og.cold) and int(cold.ferns) == 0 and int(cold.tops) == 0 and float(cold.vine) == 0.0 and int(cold.ivy_kept) == 0 and float(cold.lichen_cov) > 0.0,
			"tundra (mean %.1f °C): lichen %.2f and moss %.2f only (ferns %d, wall-top plants %d, vine %.2f, hung %d)" % [float(cold.og.mean_c), float(cold.lichen_cov), float(cold.moss_cov), int(cold.ferns), int(cold.tops), float(cold.vine), int(cold.ivy_kept)])
	for k in results:
		var r: Dictionary = results[k]
		if float(r.og.moss) > 0.0:
			ok(float(r.shade_moss) > float(r.sun_moss), "%s: the shade side's moss %.3f over the sun side's %.3f" % [r.name, float(r.shade_moss), float(r.sun_moss)])
		ok(bool(r.gate_ok), "%s: every placed species passes the place's gate (%s)" % [r.name, ", ".join(r.species) if not (r.species as Array).is_empty() else "none placed"])
		ok(float(r.growth) < 0.2 and not bool(r.collides), "%s: the dressing adds %d triangles to the ruin's %d (%.1f %%: plants %d, vines %d), none of it collides" % [r.name, int(r.added), int(r.base), float(r.growth) * 100.0, int(r.plant_tris), int(r.vine_tris)])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## A ruin site in biome `key`: this world's own (a castle where there is
## one) when it stands there, else the castle of seed 7 set on the cell of
## that biome that best fits `want` (wet: the wettest; dry: the driest and
## hottest; cold: the coldest).
func _site_for(map: PlanetData, real: Dictionary, key: String, want: String) -> Dictionary:
	var id := BiomeTemplates.id_of_key(key)
	var best := -1
	var score := -INF
	for c in map.cell_count:
		if map.biome[c] != id or map.water[c] != PlanetData.Water.NONE:
			continue
		var s := 0.0
		match want:
			"wet":
				# The wettest warm one (a cold summit is the cold rule's)
				# where a fern grows (some stretches' communities have no
				# fern that fits them).
				s = map.moisture[c] if map.temp_c[c] >= 10.0 and map.moisture[c] > score else -INF
				if s > score and Overgrowth.species(map, map.dir[c], "fern", 1, 7).is_empty():
					s = -INF
			"dry":
				s = -map.moisture[c] + map.temp_c[c] * 0.01
			"cold":
				s = -map.temp_c[c]
			"vine":
				# The wettest one where a vine species grows (its cost).
				s = map.moisture[c] if map.temp_c[c] >= 5.0 and map.moisture[c] > score else -INF
				if s > score and VineCover.species_at(map.dir[c], id, map.temp_c[c], map.moisture[c], map.terrain.elevation(map.dir[c], true), map.soil_at(map.dir[c])) == null:
					s = -INF
		if s > score:
			score = s
			best = c
	if real.has(key) and want == "cold" and map.sample(map.temp_c, (real[key] as Dictionary).dir) < 0.0:
		var f: Dictionary = real[key]
		print("   %s: this world's own %s at AT=%.3f,%.3f" % [key, Ruins.site_name(f), rad_to_deg(CubeSphere.latitude(f.dir)), rad_to_deg(CubeSphere.longitude(f.dir))])
		return f
	if real.has(key):
		var f: Dictionary = real[key]
		var og := Overgrowth.for_site(map, f)
		print("   %s: this world's own %s at AT=%.3f,%.3f: moisture %.2f, moss %.3f vine %.3f fern %.3f (the extreme cell is measured below)" % [key, Ruins.site_name(f), rad_to_deg(CubeSphere.latitude(f.dir)), rad_to_deg(CubeSphere.longitude(f.dir)), float(og.moisture), float(og.moss), float(og.vine), float(og.fern)])
	if best < 0:
		return {}
	var d: Vector3 = map.dir[best]
	print("   %s: the castle set down at AT=%.3f,%.3f" % [key, rad_to_deg(CubeSphere.latitude(d)), rad_to_deg(CubeSphere.longitude(d))])
	return {"dir": d, "kind": Ruins.Kind.CASTLE, "seed": 7, "heading": 0.6, "footprint_m": 28.0, "clear": [[d, 30.0]]}


func _measure(map: PlanetData, site: Dictionary, name: String) -> Dictionary:
	var data := RuinBuilder.compute(map, site)
	var og: Dictionary = data.og
	var shade: Vector3 = data.og_shade
	var v: PackedVector3Array = data.v
	var nn: PackedVector3Array = data.n
	var cc: PackedColorArray = data.c
	var mm: PackedVector2Array = data.m
	# Only stone above the ground is seen (footings and the mound's buried
	# faces aren't): the ground under each triangle, cached by metre.
	var gcache := {}
	var up: Vector3 = data.up
	var ex: Vector3 = data.ex
	var ez: Vector3 = data.ez
	var be := float(data.base_e)
	var d0 := int(data.get("delve_from", -1))
	var d1 := int(data.get("delve_to", -1))
	var area := 0.0
	var moss := 0.0
	var lich := 0.0
	var stone_a := 0.0
	var sh_a := 0.0
	var sh_m := 0.0
	var su_a := 0.0
	var su_m := 0.0
	for k in range(0, v.size(), 3):
		if d0 >= 0 and k >= d0 and k < d1:
			continue
		var kind := int(round(mm[k].x))
		if kind != RuinBuilder.STONE_M and kind != RuinBuilder.WOOD_M:
			continue
		var nrm := nn[k]
		if nrm.y < -0.3:
			continue
		var ctr := (v[k] + v[k + 1] + v[k + 2]) / 3.0
		var gk := Vector2i(floori(ctr.x), floori(ctr.z))
		if not gcache.has(gk):
			var gd := (up + (ex * (gk.x + 0.5) + ez * (gk.y + 0.5)) / PlanetConst.RADIUS_M).normalized()
			gcache[gk] = map.terrain.elevation(gd, true) - be
		if ctr.y < float(gcache[gk]) + 0.05:
			continue
		var a := (v[k + 1] - v[k]).cross(v[k + 2] - v[k]).length() * 0.5
		var al := (cc[k].a + cc[k + 1].a + cc[k + 2].a) / 3.0
		area += a
		moss += a * al
		if kind == RuinBuilder.STONE_M:
			stone_a += a
			lich += a * mm[k].y
		if absf(nrm.y) < 0.3:
			var dt := Vector2(nrm.x, nrm.z).normalized().dot(Vector2(shade.x, shade.z))
			if dt > 0.5:
				sh_a += a
				sh_m += a * al
			elif dt < -0.5:
				su_a += a
				su_m += a * al
	var plants: Array = data.og_plants
	var ferns := 0
	var tops := 0
	var species: Array = []
	var gate_ok := true
	var all := SpeciesDB.all()
	for p in plants:
		if str(p[4]) == "fern":
			ferns += 1
		else:
			tops += 1
		var sp: PlantSpecies = all[int(p[0])]
		if not species.has(sp.name):
			species.append(sp.name)
			if not Overgrowth.gate(map, site.dir, sp) or not sp.biomes.has(map.biome[map.cell_at(site.dir)]):
				gate_ok = false
	# The node with its dressing: the triangles it adds.
	var node := RuinBuilder.make_node(data, world)
	get_root().add_child(node)
	var kept := Overgrowth.dress(node, data)
	var vd: Vector3 = site.dir
	var vsp := VineCover.species_at(vd, map.biome[map.cell_at(vd)], map.sample(map.temp_c, vd), map.sample(map.moisture, vd), map.terrain.elevation(vd, true), map.soil_at(vd))
	print("   %s: the place's vine: %s%s" % [name, vsp.name if vsp != null else "none", (" (its biome lists it and it fits: VineCover's rule)" if vsp.biomes.has(map.biome[map.cell_at(vd)]) and vsp.suitability(map.sample(map.temp_c, vd), map.sample(map.moisture, vd), map.terrain.elevation(vd, true), map.soil_at(vd)) > 0.0 else " (FAILS its biome's rule)") if vsp != null else ""])
	Overgrowth.dress_vines(map, node, data, 40.0, 0)
	var plant_tris := 0
	var vine_tris := 0
	var collides := false
	for ch in node.get_children():
		var mmi := ch as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		var t := mmi.multimesh.instance_count * Overgrowth._tris(mmi.multimesh.mesh)
		if mmi.has_meta("overgrowth"):
			plant_tris += t
		else:
			vine_tris += t
		for g in mmi.get_children():
			if g is CollisionObject3D or g is CollisionShape3D:
				collides = true
	var base := v.size() / 3
	node.queue_free()
	var r := {
		"name": name, "og": og,
		"moss_cov": moss / maxf(area, 1e-6),
		"lichen_cov": lich / maxf(stone_a, 1e-6),
		"shade_moss": sh_m / maxf(sh_a, 1e-6), "sun_moss": su_m / maxf(su_a, 1e-6),
		"ferns": ferns, "tops": tops, "kept": kept, "species": species, "gate_ok": gate_ok,
		"vine": float(data.ivy_kept) / maxf(float(data.ivy_places), 1.0), "ivy_places": int(data.ivy_places), "ivy_kept": int(data.ivy_kept),
		"plant_tris": plant_tris, "vine_tris": vine_tris, "added": plant_tris + vine_tris, "base": base,
		"growth": float(plant_tris + vine_tris) / maxf(base, 1.0), "collides": collides,
	}
	print("   %s (%s, %s, moisture %.2f, mean %.1f °C): moss %.2f fern %.2f vine %.2f wall_top %.2f lichen %.2f; stone moss coverage %.2f (shade %.2f, sun %.2f), lichen %.2f; %d ferns and %d wall-top plants planned, %d kept; ivy at %d of %d places" % [
		name, Ruins.site_name(site), BiomeTemplates.KEYS[map.biome[map.cell_at(site.dir)]], float(og.moisture), float(og.mean_c),
		float(og.moss), float(og.fern), float(og.vine), float(og.wall_top), float(og.lichen),
		float(r.moss_cov), float(r.shade_moss), float(r.sun_moss), float(r.lichen_cov), ferns, tops, kept, int(r.ivy_kept), int(r.ivy_places)])
	return r
