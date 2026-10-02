extends SceneTree
## Run (full planet, no STAMP; PLANT_GROUPS=acacia,vines and BIOME=SAVANNA narrow it): SEED=<n> godot --headless --path . --fixed-fps 60 --script tools/plant_presence_check.gd
## Are the plants the designer named actually IN the game (Mike, 1 Oct:
## Musa, Amorphophallus, Cannabis, Trichocereus, Acacia, bamboo, vines)?
## Not "in the data": for each group, find sites on the planet whose biome
## lists the group (and whose realm is the group's, for the realm-tagged
## catalogues), load the chunks there the way play does, and count every
## plant instance of the group in the loaded chunks. A group passes when at
## least one of its sites grows it. Prints the species found per site.
var main
var world
var player: PlanetPlayer
var fails := 0
const SITES_PER_GROUP := 3


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


## Group membership by genus or shape (the whole group, not one name).
static func in_group(g: String, sp: PlantSpecies) -> bool:
	match g:
		"musa":
			return sp.genus == "Musa"
		"amorphophallus":
			return sp.genus == "Amorphophallus"
		"cannabis":
			return sp.genus == "Cannabis"
		"trichocereus":
			return sp.genus == "Trichocereus" or sp.genus == "Echinopsis"
		"acacia":
			return sp.genus in ["Acacia", "Vachellia", "Senegalia"]
		"bamboo":
			return sp.shape == PlantSpecies.Shape.BAMBOO or "bamboo" in sp.name.to_lower() or sp.genus in ["Bambusa", "Phyllostachys", "Dendrocalamus", "Guadua", "Chusquea", "Arundinaria", "Sasa", "Oxytenanthera"]
		"vines":
			return sp.shape == PlantSpecies.Shape.LIANA or sp.genus in ["Vitis", "Parthenocissus", "Hedera", "Passiflora", "Calamus", "Lygodium", "Epipremnum", "Monstera", "Philodendron", "Ipomoea", "Gloriosa"]
	return false


func _initialize() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 101
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(20)
	var map: PlanetData = world.planet
	var chunks: ChunkManager = main.chunks
	var all := SpeciesDB.all()
	var groups := ["musa", "amorphophallus", "cannabis", "trichocereus", "acacia", "bamboo", "vines"]
	if OS.get_environment("PLANT_GROUPS") != "":
		groups = Array(OS.get_environment("PLANT_GROUPS").split(","))
	# Per group: the biomes and realms its members are allowed (the gate's
	# own sets: SpeciesDB's biome listing + tags, the species' realms).
	for g in groups:
		var members: Array[PlantSpecies] = []
		for sp in all:
			if in_group(g, sp):
				members.append(sp)
		var biome_ids := {}
		var realms := {}
		var any_realm_free := false
		var soils := 0
		for sp in members:
			soils |= sp.soil_mask
			for b in sp.biomes:
				if b >= 0:
					biome_ids[b] = true
			if sp.realms.is_empty():
				any_realm_free = true
			for r in sp.realms:
				realms[r] = true
		print("[presence] %s: %d species in the catalogue, allowed in %d biomes%s" % [g, members.size(), biome_ids.size(), "" if any_realm_free else ", realms %s" % str(realms.keys())])
		if members.is_empty():
			ok(false, "%s has species" % g)
			continue
		# Candidate cells: dry land where at least one member's biome, realm,
		# soil and climate fit (the placer's own gates, at the cell).
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_v, g])
		var cells: Array = []
		for c in map.cell_count:
			if map.water[c] != PlanetData.Water.NONE or not biome_ids.has(map.biome[c]):
				continue
			# And a soil one of them takes (Amorphophallus wants alluvium,
			# clay-peat, basalt or karst: a rainforest on granite has none).
			if (soils >> map.rock[c]) & 1 == 0:
				continue
			if OS.get_environment("BIOME") != "" and BiomeTemplates.KEYS[map.biome[c]] != OS.get_environment("BIOME"):
				continue
			var d: Vector3 = map.dir[c]
			var r := RealmMap.realm(RealmMap.world_at(d), d, map.temp_c[c], map.moisture[c], map.elevation[c] / PlanetConst.HEIGHT_SCALE)
			if not any_realm_free and (not realms.has(r) or not SpeciesDB.biome_hosts(map.biome[c], r)):
				continue
			# A member whose own biome, realm, soil and climate all fit
			# the cell: a site that has the group's habitat.
			var fits := false
			for sp in members:
				if not sp.biomes.has(map.biome[c]) or (not sp.realms.is_empty() and not sp.realms.has(r)):
					continue
				if sp.suitability(map.temp_c[c], map.moisture[c], map.elevation[c], map.rock[c]) > 0.0:
					fits = true
					break
			if fits:
				cells.append(c)
		if cells.is_empty():
			# No site for it (in BIOME, when asked): nothing to grow, not a
			# failure (every group passes where it has a site).
			print("SKIP  %s: no site on this planet%s where a member's biome, realm, soil and climate fit" % [g, " in " + OS.get_environment("BIOME") if OS.get_environment("BIOME") != "" else ""])
			continue
		var best := 0
		var found := {}
		for k in mini(SITES_PER_GROUP, cells.size()):
			var c: int = cells[rng.randi() % cells.size()]
			var d: Vector3 = map.dir[c]
			var off_v: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
			world.rebase(off_v)
			player.global_position -= off_v
			chunks.load_blocking(d)
			player.spawn_at(d)
			await frames(240)
			var count := 0
			var names := {}
			for n in _plants(get_root()):
				var idx := int(n.get_meta("species"))
				if idx < 0 or idx >= all.size() or not in_group(g, all[idx]):
					continue
				var inst: int = (n as MultiMeshInstance3D).multimesh.instance_count if n is MultiMeshInstance3D else 1
				count += inst
				names[all[idx].name] = int(names.get(all[idx].name, 0)) + inst
			print("[presence]   site %d: %s, %s — %d plants %s" % [k + 1, BiomeTemplates.name_of(map.biome[c]), str(d), count, str(names)])
			best = maxi(best, count)
			found.merge(names)
		ok(best > 0, "%s grows in the game (%d species seen: %s)" % [g, found.size(), str(found.keys().slice(0, 8))])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _plants(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_meta("species") and (n is MultiMeshInstance3D or n is MeshInstance3D):
			out.append(n)
		for ch in n.get_children():
			stack.append(ch)
	return out
