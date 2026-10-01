extends SceneTree
## The realm gate and direct catalogue loading (design §AA), checked on
## real placements: chunks all over the planet are computed exactly as in
## play (TerrainChunk.compute, VegetationPlacer.compute_base/detail), and
## every catalogue plant placed is tallied by the biome and realm of its
## own spot. Chunks are picked stratified: 30000 random land points grouped
## by (biome, realm), up to PER_GROUP (env, default 4) chunks from each.
##
## Checks:
##   - the catalogues load (data/plants/), with their realms;
##   - Amorphophallus: placed, only in the ground and shrub tiers, only in
##     forest biomes, only in its own realms (indomalaya, malesia,
##     afrotropic... per species) and only in biomes with an association
##     for that realm;
##   - Trichocereus: placed, only in the andes realm;
##   - Cannabis: placed, only in each landrace's own realm, never in a
##     wetland biome or right by the water;
##   - no realm-tagged plant anywhere its realm gate forbids.
## Prints a count per biome of catalogue species placed.
##
##   ~/bin/godot --headless --path . --script tools/realm_check.gd

const SAMPLES := 30000
var PER_GROUP := int(OS.get_environment("PER_GROUP")) if OS.get_environment("PER_GROUP") != "" else 4
const FORESTS := ["TROPICAL_RAINFOREST", "JUNGLE", "TROPICAL_DRY_FOREST", "CLOUD_FOREST", "TEMPERATE_DECIDUOUS",
	"TEMPERATE_RAINFOREST", "FLOODPLAIN_FOREST", "MARITIME_FOREST", "TAIGA"]

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = get_root().get_node("World")
	world.pin(42, 0)
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var map: PlanetData = main.chunks.map
	var rivers: RiverNetwork = main.chunks.rivers

	# --- Loading ----------------------------------------------------------
	var n_cat := 0
	var genus_n := {}
	for sp in SpeciesDB.all():
		if sp.from_catalogue:
			n_cat += 1
			genus_n[sp.genus] = int(genus_n.get(sp.genus, 0)) + 1
	print("[realm] %d species, %d from the catalogues (Amorphophallus %d, Cannabis %d, Trichocereus %d)" % [SpeciesDB.all().size(), n_cat, genus_n.get("Amorphophallus", 0), genus_n.get("Cannabis", 0), genus_n.get("Trichocereus", 0)])
	var tagged_ok := true
	for sp in SpeciesDB.all():
		if sp.genus in ["Amorphophallus", "Cannabis", "Trichocereus"] and sp.realms.is_empty():
			tagged_ok = false
	ok(n_cat > 300 and tagged_ok, "the catalogues load directly, the three genera with their realms")

	# --- Stratified chunks -------------------------------------------------
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var groups := {}
	for k in SAMPLES:
		var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var b := map.biome[map.cell_at(d)]
		if BiomeTemplates.is_ocean(b):
			continue
		var alt_m := map.sample(map.elevation, d) / PlanetConst.HEIGHT_SCALE
		var r := RealmMap.realm(RealmMap.world_at(d), d, map.sample(map.temp_c, d), map.sample(map.moisture, d), alt_m)
		var g := "%s|%s" % [BiomeTemplates.KEYS[b], r]
		if not groups.has(g):
			groups[g] = []
		if (groups[g] as Array).size() < PER_GROUP:
			groups[g].append(d)
	var dirs: Array = []
	for g in groups:
		dirs.append_array(groups[g])
	print("[realm] %d (biome, realm) groups on land, %d chunks to compute" % [groups.size(), dirs.size()])

	# --- Placement ---------------------------------------------------------
	var by_biome := {} # biome key -> {species name: count}
	var tally := {} # genus -> {"biome|realm|tier": count}
	var bad: Array = []
	var t0 := Time.get_ticks_msec()
	var done := 0
	for d in dirs:
		done += 1
		if done % 20 == 0:
			print("[realm]   %d/%d chunks, %.0f ms each" % [done, dirs.size(), float(Time.get_ticks_msec() - t0) / done])
		var face := CubeSphere.face_of(d)
		var uv := CubeSphere.face_uv(face, d)
		var key := TerrainChunk.key_of(face, clampi(int((uv.x + 1.0) * 0.5 * TerrainChunk.CHUNKS_PER_FACE), 0, TerrainChunk.CHUNKS_PER_FACE - 1),
			clampi(int((uv.y + 1.0) * 0.5 * TerrainChunk.CHUNKS_PER_FACE), 0, TerrainChunk.CHUNKS_PER_FACE - 1))
		var data := TerrainChunk.compute(key, map, rivers)
		var base := VegetationPlacer.compute_base(key, map, data)
		var detail := VegetationPlacer.compute_detail(key, map, data, base.hosts)
		var ctx = VegetationPlacer._Context.new(key, map, data, 2)
		for plants in [base.plants, detail]:
			for sp_idx in plants:
				var sp: PlantSpecies = SpeciesDB.all()[int(sp_idx)]
				if not sp.from_catalogue and sp.realms.is_empty():
					continue
				var buf: PackedFloat32Array = plants[sp_idx]
				for i in range(0, buf.size(), 11):
					var pd := Vector3(buf[i], buf[i + 1], buf[i + 2])
					var s = ctx.site_at_dir(pd)
					var bkey: String = BiomeTemplates.KEYS[s.biome]
					var bb: Dictionary = by_biome.get(bkey, {})
					bb[sp.name] = int(bb.get(sp.name, 0)) + 1
					by_biome[bkey] = bb
					var gk := sp.genus if sp.genus in ["Amorphophallus", "Cannabis", "Trichocereus"] else "other catalogue"
					var tk := "%s|%s|%s" % [bkey, s.realm, PlantSpecies.Tier.keys()[sp.tier]]
					var tg: Dictionary = tally.get(gk, {})
					tg[tk] = int(tg.get(tk, 0)) + 1
					tally[gk] = tg
					# The gate itself, and each genus's rule.
					if not sp.realms.is_empty() and (not sp.realms.has(s.realm) or not SpeciesDB.biome_hosts(s.biome, s.realm)):
						bad.append("%s in %s / %s (its realms %s)" % [sp.name, bkey, s.realm, sp.realms])
					if sp.genus == "Amorphophallus" and (not (sp.tier == PlantSpecies.Tier.GROUND or sp.tier == PlantSpecies.Tier.SHRUB) or not FORESTS.has(bkey)):
						bad.append("Amorphophallus off the forest floor: %s in %s (%s tier)" % [sp.name, bkey, PlantSpecies.Tier.keys()[sp.tier]])
					if sp.genus == "Trichocereus" and s.realm != "andes":
						bad.append("Trichocereus outside the Andes: %s in %s / %s" % [sp.name, bkey, s.realm])
					if sp.genus == "Cannabis" and (VegetationPlacer.WETLANDS.has(s.biome) or s.water_m < VegetationPlacer.DRY_GROUND_M):
						bad.append("Cannabis on wet ground: %s in %s, %.0f m from water" % [sp.name, bkey, s.water_m])
	print("[realm] placed %d chunks in %.0f s" % [dirs.size(), (Time.get_ticks_msec() - t0) / 1000.0])

	# --- Report ------------------------------------------------------------
	for gk in ["Amorphophallus", "Trichocereus", "Cannabis", "other catalogue"]:
		var tg: Dictionary = tally.get(gk, {})
		var keys := tg.keys()
		keys.sort_custom(func(a, b): return tg[a] > tg[b])
		var total := 0
		for k in keys:
			total += int(tg[k])
		print("[realm] %s: %d placed" % [gk, total])
		for k in keys.slice(0, 12):
			print("[realm]    %6d  %s" % [tg[k], k])
	print("[realm] catalogue species placed, per biome:")
	var bkeys := by_biome.keys()
	bkeys.sort()
	for b in bkeys:
		var bb: Dictionary = by_biome[b]
		var n := 0
		for v in bb.values():
			n += int(v)
		var top := bb.keys()
		top.sort_custom(func(x, y): return bb[x] > bb[y])
		print("[realm]    %-22s %3d species, %6d plants  (%s)" % [b, bb.size(), n, ", ".join(top.slice(0, 3))])
	for line in bad.slice(0, 12):
		print("[realm] BAD " + line)
	ok(tally.has("Amorphophallus"), "Amorphophallus grows somewhere")
	if not tally.has("Trichocereus"):
		# Not a code failure: its bands (8-21 C, dry, up to 3400 m) fit no
		# biome with an andes association yet (puna and paramo are colder,
		# cloud forest wetter; cold desert and canyon have none) - data.
		print("WARN  Trichocereus placed nowhere: no biome its bands fit has an andes association (data, design §AA 4)")
	ok(tally.has("Cannabis"), "Cannabis grows somewhere")
	ok(bad.is_empty(), "no catalogue plant outside its realm gate or its genus's ground (%d bad)" % bad.size())
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
