extends SceneTree
## Run (full planet, no STAMP): SEED=<n> godot --headless --path . --fixed-fps 60 --script tools/road_reach_check.gd
## Do the overgrown roads reach the places they are meant to connect? On a
## full planet with the play rules (a seed and a rolled first camp, not the
## dev stamp), from the camp you wake at: how far the nearest road is, the
## road nodes and links within REACH_M, which ruins (and the inhabited ones,
## the camps) a road actually reaches, how faint the tread is, and what the
## first road from the camp leads to. Prints numbers; FAILs are the design's
## promises (§BC, §BX): a road near the spawn, ruins and camps on the network.
var main
var world
var fails := 0
const REACH_M := 15000.0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 101
	world.pin(seed_v, -1)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	for i in 20:
		await physics_frame
	var chunks: ChunkManager = main.chunks
	var roads: RoadNetwork = chunks.roads
	var map: PlanetData = world.planet
	var spawn: Vector3 = main.player.surface_dir
	var biome_name := BiomeTemplates.name_of(map.biome[map.cell_at(spawn)])
	var fire_dir: Vector3 = Encampment.clearings[0][0] if not Encampment.clearings.is_empty() else spawn
	var fire_key: String = BiomeTemplates.KEYS[map.biome[map.cell_at(fire_dir)]]
	print("[reach] seed %d, planet %.0f km round, first camp kind '%s'; the fire's cell %s, where you wake %s" % [seed_v, PlanetConst.CIRCUMFERENCE_M / 1000.0, world.first_camp_kind, BiomeTemplates.name_of(map.biome[map.cell_at(fire_dir)]), biome_name])
	# §CB: the first camp's kind rolls on the full planet too (it fell back
	# to the old list on every full-planet seed on 1 Oct), and the fire
	# stands in one of that kind's biomes, never in first_camp.never.
	var fc: Dictionary = Tuning.section("camps", "first_camp")
	var kind_biomes: Array = ((fc.get("kinds", {}) as Dictionary).get(world.first_camp_kind, {}) as Dictionary).get("biomes", [])
	ok(world.first_camp_kind != "", "the first camp's kind rolled (§CB), not the old list: '%s'" % world.first_camp_kind)
	ok(kind_biomes.has(fire_key) and not (fc.get("never", []) as Array).has(fire_key), "the fire stands in one of its kind's biomes (%s)" % fire_key)
	var t0 := Time.get_ticks_msec()
	var near := roads.links_near(spawn, REACH_M)
	print("[reach] built the roads within %.0f km in %.1f s" % [REACH_M / 1000.0, (Time.get_ticks_msec() - t0) / 1000.0])
	# Nodes within reach, by kind, and which of them a link ends at.
	var ends: Array = []
	var total_m := 0.0
	for l in near:
		var pts: PackedVector3Array = l.pts
		ends.append(pts[0])
		ends.append(pts[pts.size() - 1])
		total_m += float(l.len_m)
	var by_kind := {}
	var linked := {}
	for n in roads.nodes:
		if CubeSphere.surface_distance_m(n.dir, spawn) > REACH_M:
			continue
		by_kind[n.kind] = int(by_kind.get(n.kind, 0)) + 1
		for e in ends:
			if CubeSphere.surface_distance_m(n.dir, e) < 400.0:
				linked[n.kind] = int(linked.get(n.kind, 0)) + 1
				break
	print("[reach] %d links, %.1f km of road; nodes by kind %s, linked %s" % [near.size(), total_m / 1000.0, by_kind, linked])
	# The camp you wake at.
	var nearest := RoadNetwork.nearest_in(near, spawn, REACH_M)
	var spawn_road_m := float(nearest.get("dist_m", INF))
	print("[reach] the nearest road to the opening camp: %s" % ("%.0f m" % spawn_road_m if spawn_road_m < INF else "none within %.0f km" % (REACH_M / 1000.0)))
	ok(spawn_road_m < 150.0, "the opening camp sits on or beside a road (§BX: spawn beside the road): %s" % ("%.0f m" % spawn_road_m if spawn_road_m < INF else "none"))
	var is_node := false
	for n in roads.nodes:
		if CubeSphere.surface_distance_m(n.dir, spawn) < 400.0:
			is_node = true
	ok(is_node, "the opening camp is a road node")
	# Ruins within reach: on the network or not, inhabited (a camp) or not.
	var ruins := 0
	var ruins_on := 0
	var camps := 0
	var camps_on := 0
	var far_ruin_m := 0.0
	for c in CreatureSpawner._cells_around(spawn, REACH_M, Ruins.CELL_M):
		var site := Ruins.find(map, c)
		if site.is_empty() or CubeSphere.surface_distance_m(site.dir, spawn) > REACH_M:
			continue
		ruins += 1
		var lived := Ruins.inhabited(site)
		if lived:
			camps += 1
		var r := RoadNetwork.nearest_in(near, site.dir, REACH_M)
		var dm := float(r.get("dist_m", INF))
		if dm < 400.0:
			ruins_on += 1
			if lived:
				camps_on += 1
		else:
			far_ruin_m = maxf(far_ruin_m, dm)
	print("[reach] ruins within %.0f km: %d, a road within 400 m of %d; inhabited (camps) %d, on a road %d; the worst-served ruin is %s from a road" % [REACH_M / 1000.0, ruins, ruins_on, camps, camps_on, "%.0f m" % far_ruin_m if far_ruin_m < INF else "out of reach"])
	ok(ruins == 0 or ruins_on * 10 >= ruins * 8, "at least 80 %% of ruins are on the network (%d of %d)" % [ruins_on, ruins])
	ok(camps == 0 or camps_on == camps, "every inhabited ruin (camp) is on the network (%d of %d)" % [camps_on, camps])
	# The tread: how strongly the path colour shows at a road's centre.
	if not near.is_empty() and spawn_road_m < INF:
		var segs := RoadNetwork.segments_in(near, nearest.pt, 300.0)
		var tread := RoadNetwork.tread_at(segs, nearest.pt)
		print("[reach] the tread at the nearest road's centre: %.2f (0 bare, 1 full path colour; trail.wear x (1 - 0.6 x trail.overgrown))" % tread)
	# Where the nearest road goes: its two ends' kinds and lengths.
	if spawn_road_m < INF:
		var link: Dictionary = nearest.link
		var pts: PackedVector3Array = link.pts
		var kinds := []
		for e in [pts[0], pts[pts.size() - 1]]:
			var k := "?"
			for n in roads.nodes:
				if CubeSphere.surface_distance_m(n.dir, e) < 400.0:
					k = str(n.kind)
			kinds.append(k)
		print("[reach] that road runs %.1f km between a %s and a %s; %d waymarks, %d crossings" % [float(link.len_m) / 1000.0, kinds[0], kinds[1], (link.waymarks as Array).size(), (link.crossings as Array).size()])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
