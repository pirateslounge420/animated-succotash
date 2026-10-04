extends SceneTree
## Off the road: hidden places, and the few who speak (design 3 Oct §DJ,
## data/shrines.json hidden, HiddenPlaces), headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/hidden_check.gd
##  - the hidden places on the roads within REACH_KM of the camp: every one
##    150-900 m from the nearest road; the count within ±50 % of 0.25 to a
##    kilometre of road;
##  - every oak door's tree passes the place's biome gate; every earth homes has
##    water within 500 m, and (the nearest) a lit hearth with folk;
##  - about 30 % have a speaker;
##  - at a speaker, right click puts exactly one "spoken" line in the log a
##    visit, and another after you leave and come back.

const REACH_KM := 24.0

var fails := 0
var main: Node
var world: Node


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var map: PlanetData = world.planet
	var roads: RoadNetwork = main.chunks.roads
	var camp: Vector3 = main.camp.site
	var reach := REACH_KM * 1000.0
	var t0 := Time.get_ticks_msec()
	var links := roads.links_near(camp, reach, true)
	# The road within reach (links whose middle is in it).
	var km := 0.0
	var mine: Array = []
	for l in links:
		var pts: PackedVector3Array = l.pts
		var mid := RoadNetwork.point_at(pts, RoadNetwork.length_m(pts) * 0.5)
		if CubeSphere.surface_distance_m(mid, camp) <= reach:
			km += RoadNetwork.length_m(pts) / 1000.0
			mine.append(l)
	# Their places that stand.
	var t1 := Time.get_ticks_msec()
	var places: Array = []
	var seen := {}
	var off: Array = HiddenPlaces.D.get("off_road_m", [150.0, 900.0])
	for l in mine:
		for pl in HiddenPlaces.for_link(roads, l):
			if seen.has(pl.key):
				continue
			seen[pl.key] = true
			var nr := RoadNetwork.nearest_in(roads.links_near(pl.dir, float(off[0]) + 20.0, true), pl.dir, float(off[0]))
			if nr.is_empty():
				places.append(pl)
	print("   %d km of road within %.0f km of the camp (%d links), %d hidden places (roads %.1f s, places %.1f s)" % [km, REACH_KM, mine.size(), places.size(), (t1 - t0) / 1000.0, (Time.get_ticks_msec() - t1) / 1000.0])
	var per_km := float(HiddenPlaces.D.get("per_km_of_road", 0.25))
	var expect := per_km * km
	ok(places.size() >= expect * 0.5 and places.size() <= expect * 1.5, "%d hidden places on %.0f km of road: within ±50 %% of %.1f (%.2f a km)" % [places.size(), km, expect, places.size() / maxf(km, 0.001)])
	var by_kit := {}
	var spoken_n := 0
	var bad_dist := 0
	var min_m := INF
	var max_m := 0.0
	var bad_tree := 0
	var bad_water := 0
	for pl in places:
		by_kit[pl.kit] = int(by_kit.get(pl.kit, 0)) + 1
		if bool(pl.speaker):
			spoken_n += 1
		var nr := RoadNetwork.nearest_in(roads.links_near(pl.dir, 1200.0, true), pl.dir, 1200.0)
		var dm: float = nr.get("dist_m", INF)
		min_m = minf(min_m, dm)
		max_m = maxf(max_m, dm)
		if dm < float(off[0]) or dm > float(off[1]):
			bad_dist += 1
		if str(pl.kit) == "oak_door":
			var sp: PlantSpecies = SpeciesDB.all()[int(pl.tree[0])]
			if not HiddenPlaces.tree_gate(map, pl.dir, sp):
				bad_tree += 1
		if str(pl.kit) == "earth_homes" and HiddenPlaces.water_m(map, roads.rivers, pl.dir) > HiddenPlaces.WATER_M:
			bad_water += 1
	# The dry country round this camp may hold no oak: also the roads in the
	# nearest broadleaf wood (TEMPERATE_DECIDUOUS, else any forest).
	if not by_kit.has("oak_door"):
		var wood := _nearest_biome(map, camp, ["TEMPERATE_DECIDUOUS", "TEMPERATE_RAINFOREST", "FLOODPLAIN_FOREST", "MARITIME_FOREST"])
		if wood != Vector3.ZERO:
			var wkm := 0.0
			var wn := 0
			for l in roads.links_near(wood, 12000.0, true):
				var pts2: PackedVector3Array = l.pts
				if CubeSphere.surface_distance_m(RoadNetwork.point_at(pts2, RoadNetwork.length_m(pts2) * 0.5), wood) > 12000.0:
					continue
				wkm += RoadNetwork.length_m(pts2) / 1000.0
				for pl in HiddenPlaces.for_link(roads, l):
					if seen.has(pl.key):
						continue
					seen[pl.key] = true
					var nr2 := RoadNetwork.nearest_in(roads.links_near(pl.dir, float(off[0]) + 20.0, true), pl.dir, float(off[0]))
					if nr2.is_empty():
						places.append(pl)
						wn += 1
						by_kit[pl.kit] = int(by_kit.get(pl.kit, 0)) + 1
						if bool(pl.speaker):
							spoken_n += 1
						if str(pl.kit) == "oak_door":
							var sp2: PlantSpecies = SpeciesDB.all()[int(pl.tree[0])]
							if not HiddenPlaces.tree_gate(map, pl.dir, sp2):
								bad_tree += 1
						if str(pl.kit) == "earth_homes" and HiddenPlaces.water_m(map, roads.rivers, pl.dir) > HiddenPlaces.WATER_M:
							bad_water += 1
						var nr3 := RoadNetwork.nearest_in(roads.links_near(pl.dir, 1200.0, true), pl.dir, 1200.0)
						var dm3: float = nr3.get("dist_m", INF)
						if dm3 < float(off[0]) or dm3 > float(off[1]):
							bad_dist += 1
						min_m = minf(min_m, dm3)
						max_m = maxf(max_m, dm3)
			print("   and the wood at %.3f,%.3f (%s): %.0f km of road, %d places" % [rad_to_deg(CubeSphere.latitude(wood)), rad_to_deg(CubeSphere.longitude(wood)), FireStore.biome_key(world, wood).to_lower(), wkm, wn])
	print("   by kit: %s; speakers %d" % [str(by_kit), spoken_n])
	for pl in places.slice(0, 12):
		var extra := ""
		if str(pl.kit) == "oak_door":
			extra = " (%s, %.0f m)" % [(SpeciesDB.all()[int(pl.tree[0])] as PlantSpecies).binomial(), float(pl.tree[1])]
		print("     %s at %.3f,%.3f in %s%s%s" % [pl.kit, rad_to_deg(CubeSphere.latitude(pl.dir)), rad_to_deg(CubeSphere.longitude(pl.dir)), FireStore.biome_key(world, pl.dir).to_lower(), extra, ", a speaker" if bool(pl.speaker) else ""])
	ok(bad_dist == 0, "every one 150-900 m from the nearest road (%.0f-%.0f m; %d out)" % [min_m, max_m, bad_dist])
	ok(by_kit.size() == 3, "every kit placed somewhere (%s)" % str(by_kit))
	ok(bad_tree == 0, "every oak door's tree passes the place's biome gate (%d of %d fail)" % [bad_tree, int(by_kit.get("oak_door", 0))])
	ok(bad_water == 0, "every earth homes has water within %.0f m (%d of %d fail)" % [HiddenPlaces.WATER_M, bad_water, int(by_kit.get("earth_homes", 0))])
	var share := spoken_n / maxf(places.size(), 1.0)
	ok(absf(share - float(HiddenPlaces.D.get("speakers_share", 0.3))) <= 0.15, "about 30 %% have a speaker (%d of %d, %.0f %%)" % [spoken_n, places.size(), share * 100.0])
	# --- The nearest earth homes: its hearth lit, folk at it. ---
	var homes := _nearest(places, camp, func(pl): return str(pl.kit) == "earth_homes")
	if homes.is_empty():
		ok(false, "an earth homes within reach")
	else:
		await _stand(homes.hearth, 6.0)
		main.hidden_places.refresh(true)
		main.camps.refresh_now()
		for i in 30:
			await process_frame
		var camp_node: Node3D = main.camps._camps.get(str(homes.key))
		var lit := false
		var folk := 0
		if camp_node != null:
			var fire: Node3D = camp_node.get_meta("fire", null)
			lit = fire != null and bool(fire.get_meta("lit", true)) and FireStore.is_lit(fire)
			folk = (camp_node.get_meta("sitters", []) as Array).size()
		var built: Node3D = main.hidden_places.built().get(str(homes.key))
		print("   the earth homes at %.3f,%.3f: %d doors built %s; camp %s, fire lit %s, %d folk" % [rad_to_deg(CubeSphere.latitude(homes.dir)), rad_to_deg(CubeSphere.longitude(homes.dir)), int(homes.homes), "yes" if built != null else "no", "yes" if camp_node != null else "no", str(lit), folk])
		ok(built != null and camp_node != null and lit and folk > 0, "the earth homes: built, its own camp with a lit hearth and %d folk" % folk)
	# --- A speaker: one line a visit. ---
	var sp_place := _nearest(places, camp, func(pl): return bool(pl.speaker))
	if sp_place.is_empty():
		ok(false, "a speaker within reach")
	else:
		await _stand(sp_place.dir, 8.0)
		main.hidden_places.refresh(true)
		await process_frame
		var hp: HiddenPlaces = main.hidden_places
		var sp: Dictionary = {}
		for s in hp.speakers:
			if s.key == sp_place.key:
				sp = s
		ok(not sp.is_empty(), "the speaker stands by the %s" % str(sp_place.kit))
		if not sp.is_empty():
			var sp_node: Node3D = sp.node
			# Walk up to it.
			main.player.global_position = sp_node.global_position + (main.player.global_position - sp_node.global_position).normalized() * 2.0
			await process_frame
			var n0 := _spoken()
			var near := hp.speaker_in_reach(main.player.global_position)
			var a := hp.speak(near)
			var b := hp.speak(near)
			var n1 := _spoken()
			var last: String = GameLog.entries[GameLog.entries.size() - 1].text if not GameLog.entries.is_empty() else ""
			ok(not near.is_empty() and a and not b and n1 - n0 == 1, "within 3 m, two right clicks: %d spoken line (\"%s\")" % [n1 - n0, last])
			# Leave and come back: a new visit.
			await _stand(CreatureSpawner._offset(sp_place.dir, 0.0, 150.0), 0.0)
			for i in 5:
				await process_frame
			main.player.global_position = sp_node.global_position + Vector3(0.0, 0.0, 0.0) + sp_node.global_basis.z * 1.5
			await process_frame
			var c := hp.speak(hp.speaker_in_reach(main.player.global_position))
			ok(c and _spoken() - n1 == 1, "after leaving and coming back: one more (%d)" % (_spoken() - n1))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## The centre of the nearest blueprint cell of one of `keys` to `d`.
func _nearest_biome(map: PlanetData, d: Vector3, keys: Array) -> Vector3:
	var ids := keys.map(func(k): return BiomeTemplates.id_of_key(k))
	for key_i in ids.size():
		var best := Vector3.ZERO
		var bd := INF
		for c in map.cell_count:
			if map.biome[c] != ids[key_i]:
				continue
			var dm := CubeSphere.surface_distance_m(map.dir[c], d)
			if dm < bd:
				bd = dm
				best = map.dir[c]
		if best != Vector3.ZERO:
			return best
	return Vector3.ZERO


func _spoken() -> int:
	return GameLog.entries.filter(func(e): return e.kind == "spoken").size()


func _nearest(places: Array, camp: Vector3, want: Callable) -> Dictionary:
	var best := {}
	var bd := INF
	for pl in places:
		if not want.call(pl):
			continue
		var dm := CubeSphere.surface_distance_m(pl.dir, camp)
		if dm < bd:
			bd = dm
			best = pl
	return best


## Stand `back_m` off surface direction `d`, the ground loaded.
func _stand(d: Vector3, back_m: float) -> void:
	var at := CreatureSpawner._offset(d, 1.0, back_m) if back_m > 0.0 else d
	var off: Vector3 = world.to_scene(at, PlanetConst.RADIUS_M + world.surface_elevation(at))
	world.rebase(off)
	main.player.global_position -= off
	main.chunks.load_blocking(at)
	main.player.spawn_at(at)
	for i in 20:
		await process_frame
