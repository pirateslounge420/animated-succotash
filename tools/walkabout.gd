extends SceneTree
## The walkabout (design 1 Oct §CA, data/habitat.json walkabout): the end
## of every visual pass, in place of the dev frame. One seed per run:
##
##   SEED=101 xvfb-run -a -s "-screen 0 1280x720x24" ~/bin/godot --path . \
##     --rendering-method forward_plus --resolution 1280x720 -s tools/walkabout.gd
##
## First person at the player's eye (eye_m), at the play preset. The sites
## per seed (sites_per_seed): the opening camp at the spawn hour, a point
## 1 km down the first road, and three random sites in three different
## biomes (BIOMES=SAVANNA,TAIGA,BOG picks them; else a savanna, a forest
## and a wetland rotate in across seeds). At each site: `facings` ways
## round, at each of `hours` (solar hour and weather). Frames go to
## tools/reference/walkabout/<seed>/<site>_<HH>h_f<k>.png and the report
## lines to tools/reference/walkabout/walkabout.txt (RESET=1 starts it
## over): per site the biome, the soil, every species within list_within_m
## with its files, and PASS/FAIL. A species standing in a biome that does
## not list it FAILS the site (unlisted_species_allowed). The opening
## camp's first frame must be afternoon (the sun above the dusk band).
## SITES=opening_camp,random_biome keeps a subset; QUICK=1 one facing and
## the first hour (a smoke run).

const OUT_DIR := "res://tools/reference/walkabout"
var W: Dictionary = Tuning.table("habitat").get("walkabout", {})
var fails := 0
var lines: Array[String] = []
var main
var world
var player: PlanetPlayer
var sd := 101


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func ok(cond: bool, what: String) -> void:
	var line := ("PASS  " if cond else "FAIL  ") + what
	print(line)
	lines.append(line)
	if not cond:
		fails += 1


func _run() -> void:
	world = get_root().get_node("World")
	sd = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 101
	world.pin(sd, -1)
	seed(sd)
	Bow.need_capture = false
	PlanetPlayer.EYE_Y = float(W.get("eye_m", 1.6))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR.path_join(str(sd))))
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	main.hud.visible = false
	player.set_physics_process(false)
	player.first_person = true
	player._apply_view()
	player.camera().current = true
	lines.append("== World %d (%s) — first camp: %s camp, %s" % [sd, "postage stamp" if world.postage_stamp else "full planet", world.first_camp_kind if world.first_camp_kind != "" else "old list", BiomeTemplates.KEYS[world.planet.biome[world.planet.cell_at(main.camp.site)]]])
	var quick := OS.get_environment("QUICK") == "1"
	var only: Array = Array(OS.get_environment("SITES").split(",")) if OS.get_environment("SITES") != "" else []
	var hours: Array = W.get("hours", [{"solar_h": 14.0, "weather": "overcast"}, {"solar_h": 17.5, "weather": "clear"}, {"solar_h": 22.0, "weather": "clear"}])
	if quick:
		hours = [hours[0]]
	var facings := 1 if quick else int(W.get("facings", 4))
	# The sites.
	var sites: Array = []
	var spawn_days: float = world.days
	var camp_d: Vector3 = main.camp.site
	var wanted: Array = Array(OS.get_environment("BIOMES").split(",")) if OS.get_environment("BIOMES") != "" else _wanted_biomes()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sd, "walkabout"])
	var random_i := 0
	for kind in W.get("sites_per_seed", ["opening_camp", "first_road_1km", "random_biome", "random_biome", "random_biome"]):
		if not only.is_empty() and not only.has(kind):
			continue
		match str(kind):
			"opening_camp":
				sites.append({"name": "opening_camp", "dir": camp_d, "spawn_hour": true})
			"first_road_1km":
				var rd := _down_the_road(camp_d, 1000.0)
				sites.append({"name": "first_road_1km", "dir": rd.dir, "note": rd.note})
			"random_biome":
				var key: String = wanted[random_i % wanted.size()] if not wanted.is_empty() else ""
				random_i += 1
				var pick := _random_cell_of(key, rng)
				if pick.dir == Vector3.ZERO:
					lines.append("-- random_biome %s: no land cell of that biome on this planet; skipped" % key)
					continue
				sites.append({"name": "random_%s" % pick.key.to_lower(), "dir": pick.dir})
	# Walk them.
	# walkabout.txt grows a site at a time, so a run cut short keeps
	# what it saw.
	if OS.get_environment("RESET") == "1":
		var f0 := FileAccess.open(ProjectSettings.globalize_path(OUT_DIR.path_join("walkabout.txt")), FileAccess.WRITE)
		f0 = null
	_flush()
	for site in sites:
		await _visit(site, hours, facings, spawn_days)
		_flush()
	lines.append("RESULT seed %d fails: %d" % [sd, fails])
	_flush()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Append the lines gathered so far to walkabout.txt and clear them.
func _flush() -> void:
	var path := ProjectSettings.globalize_path(OUT_DIR.path_join("walkabout.txt"))
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f:
		f.seek_end()
		for l in lines:
			f.store_line(l)
	lines.clear()


## A savanna, a forest and a wetland, rotated by seed so every run has
## all three somewhere; any missing on this planet is swapped for another
## land biome present.
func _wanted_biomes() -> Array:
	var forests := ["TEMPERATE_DECIDUOUS", "TROPICAL_RAINFOREST", "TAIGA", "JUNGLE", "TEMPERATE_RAINFOREST", "CLOUD_FOREST", "TROPICAL_DRY_FOREST"]
	var wetlands := ["SWAMP", "FRESHWATER_MARSH", "BOG", "FEN", "WET_MEADOW", "FLOODPLAIN_FOREST"]
	var present := {}
	var map: PlanetData = world.planet
	for c in map.cell_count:
		if map.water[c] == PlanetData.Water.NONE:
			present[BiomeTemplates.KEYS[map.biome[c]]] = true
	var out: Array = []
	for group in [["SAVANNA", "TROPICAL_DRY_FOREST", "THORN_SCRUB"], forests, wetlands]:
		var pick := ""
		for i in group.size():
			var k: String = group[(i + sd) % group.size()]
			if present.has(k):
				pick = k
				break
		if pick == "":
			var keys := present.keys()
			pick = str(keys[sd % keys.size()])
		out.append(pick)
	return out


## A random land cell of biome `key` (direction), or ZERO.
func _random_cell_of(key: String, rng: RandomNumberGenerator) -> Dictionary:
	var map: PlanetData = world.planet
	var bid := BiomeTemplates.id_of_key(key)
	var cells := PackedInt32Array()
	for c in map.cell_count:
		if map.water[c] == PlanetData.Water.NONE and (bid < 0 or map.biome[c] == bid):
			cells.append(c)
	if cells.is_empty():
		return {"dir": Vector3.ZERO, "key": key}
	var c := cells[rng.randi() % cells.size()]
	return {"dir": map.dir[c], "key": BiomeTemplates.KEYS[map.biome[c]]}


## A point `m` metres down the nearest road from `d` (the first road), or
## 1 km north with a note when no road lies within 3 km.
func _down_the_road(d: Vector3, m: float) -> Dictionary:
	var roads: RoadNetwork = main.chunks.roads
	var near: Array = roads.links_near(d, 3000.0)
	var hit := RoadNetwork.nearest_in(near, d, 3000.0)
	if hit.is_empty():
		return {"dir": CreatureSpawner._offset(d, 0.0, m), "note": "no road within 3 km of the camp: 1 km north instead"}
	var pts: PackedVector3Array = hit.link.pts
	var at := 0.0
	for i in int(hit.seg):
		at += CubeSphere.surface_distance_m(pts[i], pts[i + 1])
	at += CubeSphere.surface_distance_m(pts[int(hit.seg)], pts[int(hit.seg) + 1]) * float(hit.t)
	var total := RoadNetwork.length_m(pts)
	var target := at + m if at + m <= total else maxf(at - m, 0.0)
	var note := "the road %.0f m from the camp, %.0f m along it" % [float(hit.dist_m), target]
	if total < m:
		note += " (a short link, %.0f m long: its end)" % total
		target = total if at < total * 0.5 else 0.0
	# A road can run to a shore or a ford: a frame under water shows no
	# plants, so step back along the road toward the camp, 50 m at a time,
	# to the first dry ground.
	var p := RoadNetwork.point_at(pts, target)
	var back := 0
	while not _dry(p) and absf(target - at) > 50.0:
		target += -50.0 if target > at else 50.0
		back += 1
		p = RoadNetwork.point_at(pts, target)
	if back > 0:
		note += " (water there: %d m back toward the camp)" % (back * 50)
	return {"dir": p, "note": note}


## Dry land: a cell with no water on it and ground above the sea.
func _dry(d: Vector3) -> bool:
	var map: PlanetData = world.planet
	return map.water[map.cell_at(d)] == PlanetData.Water.NONE and world.surface_elevation(d) > PlanetConst.SEA_LEVEL_M + 0.5


func _visit(site: Dictionary, hours: Array, facings: int, spawn_days: float) -> void:
	var d: Vector3 = site.dir
	var map: PlanetData = world.planet
	var cell := map.cell_at(d)
	var biome_key: String = BiomeTemplates.KEYS[map.biome[cell]]
	var soil := PlanetData.soil_name(map.soil_at(d)).replace("_", "/")
	# Stand there (as dev_view's AT= does): rebase, load, spawn.
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	player.global_position -= off
	main.chunks.load_blocking(d)
	player.spawn_at(d, CreatureSpawner._offset(d, 0.0, 30.0))
	await _frames(20)
	# Wait for the chunk's near plants (the leaf cards, not the far
	# pictures), as play has them within seconds on a GPU.
	# Bounded by the clock, not frames: the software renderer draws about
	# a frame a second, so a frame count would wait an hour.
	var ck: Vector3i = TerrainChunk.key_at(d)
	var t0 := Time.get_ticks_msec()
	var detail := false
	while Time.get_ticks_msec() - t0 < int(W.get("detail_wait_s", 240.0) * 1000.0):
		var c: TerrainChunk = main.chunks.chunks.get(ck, null)
		if c != null and c.plant_lod(c) != PlantMeshes.LOD_FAR and c.detail_node != null:
			detail = true
			break
		await process_frame
	if not detail:
		site["note"] = (str(site.note) + " · " if site.has("note") else "") + "near plants not in after %d s" % ((Time.get_ticks_msec() - t0) / 1000)
	await _frames(10)
	lines.append("-- %s: %s · %s soil · %.2f°%s %.2f°%s%s" % [site.name, biome_key, soil, absf(rad_to_deg(map.lat[cell])), "N" if map.lat[cell] >= 0.0 else "S", absf(rad_to_deg(CubeSphere.longitude(d))), "E" if CubeSphere.longitude(d) >= 0.0 else "W", (" · " + str(site.note)) if site.has("note") else ""])
	# The species within reach, and the gate's verdict on each.
	var within := float(W.get("list_within_m", 30.0))
	var found := _species_within(player.global_position, within)
	var unlisted := 0
	var names: Array = found.keys()
	names.sort()
	for n in names:
		var sp: PlantSpecies = found[n][0]
		var count: int = found[n][1]
		var listed := sp.biomes.has(map.biome[cell])
		if not listed:
			unlisted += 1
		lines.append("   %s%s x%d [%s, %s]" % ["" if listed else "UNLISTED HERE: ", n, count, PlantSpecies.Tier.keys()[sp.tier].to_lower(), ", ".join(sp.files)])
	ok(unlisted <= int(W.get("unlisted_species_allowed", 0)), "%s (%s): %d species within %.0f m, %d in a biome that does not list them" % [site.name, biome_key, names.size(), within, unlisted])
	# The hours and facings.
	var lon := CubeSphere.longitude(d)
	var lat := CubeSphere.latitude(d)
	var base: float = floor(spawn_days) + 1.0
	var first := true
	for h in hours:
		var hour := float(h.get("solar_h", 14.0))
		var overcast := str(h.get("weather", "clear")) == "overcast"
		var wx := {"wind": Vector3(1, 0, 0.5), "rain_mm_h": 0.0, "snow": false, "temp_c": 18.0, "storm": 0.0, "clear": 0.0 if overcast else 1.0, "cloud": 0.95 if overcast else 0.12}
		main._weather_timer = 1e9
		main._local_weather = wx
		main._weather_eased = wx.duplicate()
		if site.get("spawn_hour", false) and first:
			# The spawn hour itself: the clock as the world opened.
			world.days = spawn_days
		else:
			world.days = Astro.days_at_solar_hour(base, hour, lon, lat)
		for k in facings:
			var yaw := TAU * k / facings
			for i in (12 if k == 0 else 6):
				player.set_view(0.0, yaw)
				main.hud._readout_timer = 0.0
				await process_frame
			var img := get_root().get_texture().get_image()
			var solar := fposmod(Astro.time_of_day(world.days) + lon / TAU, 1.0) * 24.0
			var fname := "%s_%02dh_f%d.png" % [site.name, int(round(solar)), k]
			img.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join(str(sd)).path_join(fname)))
			if site.get("spawn_hour", false) and first and k == 0:
				var dusk := DayCycle.phase_start_hour("dusk", lat, Astro.declination(world.days))
				ok(solar >= 12.0 and solar < dusk and main.sky.sun_elevation_deg > 0.0, "the opening camp's first frame is afternoon (solar %.1f h, dusk begins %.1f h, sun %.1f°)" % [solar, dusk, main.sky.sun_elevation_deg])
		first = false


## Every species within `r` m of `center` (scene): the trees of the loaded
## chunks and their understory MultiMeshes (meta "species"), name ->
## [species, count].
func _species_within(center: Vector3, r: float) -> Dictionary:
	var out := {}
	var all := SpeciesDB.all()
	for key in main.chunks.chunks:
		var chunk: TerrainChunk = main.chunks.chunks[key]
		if chunk.global_position.distance_to(center) > r + 400.0:
			continue
		for i in chunk.trees.size():
			if chunk.tree_base(i).distance_to(center) <= r:
				_count(out, all[int(chunk.trees[i][2])])
		if chunk.detail_node == null:
			continue
		for n in chunk.detail_node.get_children():
			var mmi := n as MultiMeshInstance3D
			if mmi == null or not mmi.has_meta("species") or mmi.multimesh == null:
				continue
			var sp: PlantSpecies = all[int(mmi.get_meta("species"))]
			var buf := mmi.multimesh.buffer
			var count := mmi.multimesh.instance_count if mmi.multimesh.visible_instance_count < 0 else mmi.multimesh.visible_instance_count
			for k in count:
				var j := k * 20
				if j + 11 >= buf.size():
					break
				var base := mmi.global_transform * Vector3(buf[j + 3], buf[j + 7], buf[j + 11])
				if base.distance_to(center) <= r:
					_count(out, sp)


	return out


func _count(out: Dictionary, sp: PlantSpecies) -> void:
	if not out.has(sp.name):
		out[sp.name] = [sp, 0]
	out[sp.name][1] += 1
