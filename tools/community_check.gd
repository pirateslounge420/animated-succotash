extends SceneTree
## Plants live in communities, and every community has one home (design
## 3 Oct §CS; data/habitat.json communities; Communities):
##   SEEDS="7731,42,7" godot --headless --path . --script tools/community_check.gd
## Per seed (the full planet):
##  - every community is native to at most one land (no community dealt as
##    its own to two provinces), and each stretch's community is of its
##    biome;
##  - the short biomes: each land biome, the lands it appears in, how many
##    communities it has and how many lands had to take a neighbour's
##    (spread across the border), and the biomes with none at all (they
##    keep today's placement until a fill adds them);
## Once (the data):
##  - the unattached catalogue species (no association lists them; they
##    keep their current placement until the attach fill), by catalogue;
##  - the communities that name no plant of a tier (emergent, canopy,
##    shrub, ground, epiphyte), counted, since those tiers stay empty
##    where that community lives;
## In play (the first seed, at its opening camp): every plant standing
## within LIST_M of you belongs to the community dealt to its land and
## biome, or is admitted by today's rules (an unattached catalogue species,
## or a biome with no communities).
## The lists also go to tools/reference/community_report.txt for the fill.

const LIST_M := 300.0
const REPORT := "res://tools/reference/community_report.txt"

var world
var main
var fails := 0
var lines: Array[String] = []


func _initialize() -> void:
	world = get_root().get_node("World")
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	var line := ("PASS  " if cond else "FAIL  ") + what
	print(line)
	if not cond:
		fails += 1


func say(s: String) -> void:
	print(s)
	lines.append(s)


func _run() -> void:
	world._load_dev_settings()
	world.use_postage_stamp(false)
	var seeds := (OS.get_environment("SEEDS") if OS.get_environment("SEEDS") != "" else "7731,42,7").split(",")
	Communities.load_all()
	say("[communities] %d communities in %d biomes; %d catalogue species attached to one, %d species listed by one" % [Communities.all.size(), Communities.by_biome.size(), Communities.attached.size(), Communities.listed.size()])
	_data_report()
	for s in seeds:
		if OS.get_environment("IN_PLAY_ONLY") == "1":
			break
		world.generate_now(int(s))
		var map: PlanetData = world.planet
		Communities._seed = -1
		Communities.warm(map)
		_deal_report(int(s), map)
	# In play: the first seed's opening camp.
	world.pin(int(seeds[0]), 0)
	Bow.need_capture = false
	WorldSave.read_only = true
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	# Let the land round you finish growing (the worker threads).
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await process_frame
		if main.chunks._pending.is_empty() and main.chunks._pending_detail.is_empty() and Time.get_ticks_msec() - t0 > 5000:
			break
	for i in 60:
		await process_frame
	_in_play(int(seeds[0]))
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines) + "\n")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _data_report() -> void:
	var by_cat := {}
	var n := 0
	for sp in SpeciesDB.all():
		if sp.from_catalogue and not Communities.attached.has(sp):
			n += 1
			var g := sp.genus if sp.genus != "" else "?"
			(by_cat.get_or_add(g, []) as Array).append(sp.name)
	say("[communities] unattached catalogue species (no association lists them; current placement until the fill): %d" % n)
	var gs := by_cat.keys()
	gs.sort()
	for g in gs:
		say("[communities]   %s (%d): %s" % [g, (by_cat[g] as Array).size(), ", ".join(by_cat[g])])
	var tiers := ["emergent", "canopy", "shrub", "ground", "epiphyte"]
	var missing := {}
	for c in Communities.all:
		var have := {}
		for sp in (c.members as Dictionary):
			have[(sp as PlantSpecies).tier] = true
		for t in tiers.size():
			if not have.has(t):
				missing[tiers[t]] = int(missing.get(tiers[t], 0)) + 1
	say("[communities] communities naming no plant of a tier (that tier stays empty where they live): %s" % ", ".join(tiers.map(func(t): return "%s %d" % [t, int(missing.get(t, 0))])))


func _deal_report(sd: int, map: PlanetData) -> void:
	var own_of := {}
	var bad_biome := 0
	var twice := 0
	var lands_of := {}
	var spread_of := {}
	for key in Communities.dealt:
		var e: Dictionary = Communities.dealt[key]
		var parts: PackedStringArray = str(key).split(":")
		var p := int(parts[0])
		var b := int(parts[1])
		var ci := int(e.community)
		if int(Communities.all[ci].biome) != b:
			bad_biome += 1
		(lands_of.get_or_add(b, []) as Array).append(p)
		if bool(e.own):
			if own_of.has(ci):
				twice += 1
			own_of[ci] = p
		else:
			spread_of[b] = int(spread_of.get(b, 0)) + 1
	ok(twice == 0, "seed %d: no community is native to two lands (%d dealt, %d stretches)" % [sd, own_of.size(), Communities.dealt.size()])
	ok(bad_biome == 0, "seed %d: every stretch's community is of its own biome" % sd)
	# Biomes on the land with none at all.
	var on_land := {}
	for c in map.cell_count:
		if map.water[c] != PlanetData.Water.OCEAN:
			on_land[map.biome[c]] = true
	var none: Array[String] = []
	for b in on_land:
		if not Communities.by_biome.has(b):
			none.append(BiomeTemplates.KEYS[int(b)])
	none.sort()
	say("[communities] seed %d: biomes on the land with no communities (today's placement until a fill): %s" % [sd, ", ".join(none) if not none.is_empty() else "none"])
	var short: Array[String] = []
	var ids := lands_of.keys()
	ids.sort()
	for b in ids:
		var lands: Array = lands_of[b]
		var n_comm := (Communities.by_biome.get(b, []) as Array).size()
		var line := "[communities] seed %d:   %-22s in %d lands, %d communities%s" % [sd, BiomeTemplates.KEYS[int(b)], lands.size(), n_comm,
			(", %d lands took a neighbour's (short by %d)" % [int(spread_of[b]), int(spread_of[b])]) if spread_of.has(b) else ""]
		say(line)
		if spread_of.has(b):
			short.append("%s (%d short)" % [BiomeTemplates.KEYS[int(b)], int(spread_of[b])])
	say("[communities] seed %d: short biomes: %s" % [sd, ", ".join(short) if not short.is_empty() else "none"])


func _in_play(sd: int) -> void:
	_in_play_at(sd, main.player.global_position, "the opening camp")
	# And the most wooded chunk loaded (the camp stands in its clearing).
	var best: TerrainChunk = null
	for key in main.chunks.chunks:
		var c: TerrainChunk = main.chunks.chunks[key]
		if c.detail_node != null and (best == null or c.trees.size() > best.trees.size()):
			best = c
	if best != null and not best.trees.is_empty():
		_in_play_at(sd, best.tree_base(0), "the most wooded stretch loaded")


func _in_play_at(sd: int, center: Vector3, where: String) -> void:
	var all := SpeciesDB.all()
	var seen := {}
	var outside := {}
	var n := 0
	for key in main.chunks.chunks:
		var chunk: TerrainChunk = main.chunks.chunks[key]
		if chunk.global_position.distance_to(center) > LIST_M + 400.0:
			continue
		var cdir: Vector3 = chunk.center_dir
		var spots: Array = []
		for i in chunk.trees.size():
			spots.append([all[int(chunk.trees[i][2])], chunk.tree_base(i)])
		if chunk.detail_node != null:
			for nd in chunk.detail_node.get_children():
				var mmi := nd as MultiMeshInstance3D
				if mmi == null or not mmi.has_meta("species") or mmi.multimesh == null:
					continue
				var buf := mmi.multimesh.buffer
				var count := mmi.multimesh.instance_count if mmi.multimesh.visible_instance_count < 0 else mmi.multimesh.visible_instance_count
				for k in count:
					var j := k * 20
					if j + 11 >= buf.size():
						break
					spots.append([all[int(mmi.get_meta("species"))], mmi.global_transform * Vector3(buf[j + 3], buf[j + 7], buf[j + 11])])
		for sp_at in spots:
			var sp: PlantSpecies = sp_at[0]
			var at: Vector3 = sp_at[1]
			if at.distance_to(center) > LIST_M:
				continue
			n += 1
			var b: int = world.planet.biome[world.planet.cell_at(world.dir_of(at))]
			var ci := Communities.at(cdir, b)
			seen[sp.name] = ci
			if not Communities.admits(ci, sp):
				outside[sp.name] = "%s in %s (community %s)" % [sp.name, BiomeTemplates.KEYS[b], str(Communities.all[ci].name) if ci >= 0 else "none"]
	var here: Vector3 = world.dir_of(center)
	var b0: int = world.planet.biome[world.planet.cell_at(here)]
	var c0 := Communities.at(here, b0)
	say("[communities] in play, seed %d, %s: %s, land %d, community %s; %d plants of %d species within %.0f m" % [sd, where, BiomeTemplates.KEYS[b0], RealmMap.province_at(here), ("\"%s\"" % Communities.all[c0].name) if c0 >= 0 else "none (today's placement)", n, seen.size(), LIST_M])
	var names := seen.keys()
	names.sort()
	say("[communities]   %s" % ", ".join(names))
	var tiers := {}
	for key in main.chunks.chunks:
		var chunk: TerrainChunk = main.chunks.chunks[key]
		if chunk.global_position.distance_to(center) <= LIST_M + 200.0:
			for i in chunk.trees.size():
				tiers[all[int(chunk.trees[i][2])].name] = int(tiers.get(all[int(chunk.trees[i][2])].name, 0)) + 1
	var all_trees := 0
	var with_detail := 0
	for key in main.chunks.chunks:
		all_trees += (main.chunks.chunks[key] as TerrainChunk).trees.size()
		with_detail += 1 if (main.chunks.chunks[key] as TerrainChunk).detail_node != null else 0
	say("[communities]   trees in the chunks round you: %s; %d trees in all %d loaded chunks (%d with undergrowth)" % [str(tiers), all_trees, main.chunks.chunks.size(), with_detail])
	ok(n > 0, "plants stand round %s" % where)
	ok(outside.is_empty(), "%s: every plant there" % where + " is of its community, or admitted by today's rules (%d not: %s)" % [outside.size(), "; ".join(outside.values().slice(0, 6))])
