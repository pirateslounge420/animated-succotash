extends SceneTree
## Run (full planet, no STAMP): SEED=<n> godot --headless --path . --fixed-fps 60 --script tools/road_reach_check.gd
## Do the overgrown roads reach the places they are meant to connect? On a
## full planet with the play rules (a seed and a rolled first camp, not the
## dev stamp), from the camp you wake at: how far the nearest road is, the
## road nodes and links within REACH_M, which ruins (and the inhabited ones,
## the camps) a road actually reaches, how much bare tread shows (a clear
## stretch's centre and edge, a lost stretch, 30 m off), the lost-and-found
## share and its tells, and the opening road to its people's camp. Prints
## numbers; FAILs are the design's promises (§BC, §BX, §BY, §CB): the kind
## rolled, a road beside the spawn, ruins and camps on the network, the
## tread legible on the road and gone off it and in a lost stretch.
var main
var world
var fails := 0
## How far round the spawn to look (REACH_KM overrides, default 15 km).
static var REACH_M := float(OS.get_environment("REACH_KM")) * 1000.0 if OS.get_environment("REACH_KM") != "" else 15000.0


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
	# The tread (§BC, §BY): the bare share at a clear stretch's centre, at
	# its edge, in a vanished stretch, and 30 m off; the lost-and-found
	# stretches against vanish_share, each with its tell.
	if not near.is_empty() and spawn_road_m < INF:
		var lf: Dictionary = Tuning.section("roads", "lost_and_found")
		var on_c := []
		var on_e := []
		var lost := []
		var off := []
		var vanished_m := 0.0
		var road_m := 0.0
		var stretches := 0
		var told := 0
		for l in near:
			var pts: PackedVector3Array = l.pts
			var cum: PackedFloat32Array = l.get("cum", PackedFloat32Array())
			var van: Array = l.get("vanish", [])
			road_m += float(l.len_m)
			for v in van:
				vanished_m += float(v[1]) - float(v[0])
				stretches += 1
				var resume := RoadNetwork.point_at(pts, float(v[1]))
				for w in l.waymarks:
					if (w as Array).size() > 3 and CubeSphere.surface_distance_m(w[0], resume) <= float(lf.get("tell_within_m", 12.0)) + 1.0:
						told += 1
						break
			# Sample the middle of the link every 50 m.
			var m := 100.0
			while m < float(l.len_m) - 100.0 and on_c.size() < 4000:
				var p := RoadNetwork.point_at(pts, m)
				var q := RoadNetwork.point_at(pts, m + 2.0)
				var right := (q - p).cross(p).normalized()
				var segs := RoadNetwork.segments_in([l], p, 60.0)
				var hw := float(l.width_m) * 0.5
				var in_vanish := RoadNetwork.vanish_overgrown(van, m) > 0.9
				var c := RoadNetwork.tread_at(segs, p)
				if in_vanish:
					lost.append(c)
				else:
					on_c.append(c)
					on_e.append(RoadNetwork.tread_at(segs, (p + right * hw * 0.9 / PlanetConst.RADIUS_M).normalized()))
				off.append(RoadNetwork.tread_at(RoadNetwork.segments_in(near, p, 80.0), (p + right * 30.0 / PlanetConst.RADIUS_M).normalized()))
				m += 50.0
		var mean := func(a: Array) -> float:
			var t := 0.0
			for x in a:
				t += float(x)
			return t / maxf(1.0, a.size())
		var off_max := 0.0
		var off_n := 0
		for x in off:
			off_max = maxf(off_max, float(x))
			if float(x) > 0.05:
				off_n += 1
		print("[reach] the tread (bare share): clear stretch centre %.2f, edge %.2f; vanished stretch %.2f; 30 m off, worst %.2f (%d samples)" % [mean.call(on_c), mean.call(on_e), mean.call(lost), off_max, on_c.size() + lost.size()])
		print("[reach] lost and found: %.0f %% of %.0f km vanished (vanish_share %.2f) in %d stretches, %d with a tell where the trail resumes" % [vanished_m / maxf(road_m, 1.0) * 100.0, road_m / 1000.0, float(lf.get("vanish_share", 0.3)), stretches, told])
		ok(mean.call(on_c) >= 0.4, "the tread reads down a clear stretch's centre (%.2f)" % mean.call(on_c))
		ok(lost.is_empty() or mean.call(lost) < 0.2, "the tread all but vanishes in a lost stretch (%.2f)" % mean.call(lost))
		# 30 m off one road can be on another (a fork, a junction).
		ok(off_n * 50 <= off.size(), "no tread 30 m off a road, bar junctions (%d of %d samples)" % [off_n, off.size()])
		ok(stretches == told, "every lost stretch has a tell where the trail resumes (%d of %d)" % [told, stretches])
	# The opening road (§BX): the forced link from the opening camp to its
	# people's camp, its length against opening_road.length_km_hint.
	var hint_km := float(Tuning.section("roads", "opening_road").get("length_km_hint", 7.2))
	var opening_m := -1.0
	for l in near:
		if bool(l.get("opening", false)):
			opening_m = float(l.len_m)
	print("[reach] the opening road: %s (hint %.1f km)" % ["%.1f km to its people's camp" % (opening_m / 1000.0) if opening_m >= 0.0 else "none", hint_km])
	ok(opening_m >= 0.0, "an opening road leads from the camp to a people's camp")
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
