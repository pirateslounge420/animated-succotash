extends SceneTree
## Dev postage stamp check (spec A4: "a fixed-seed mini-planet that
## contains one of every major biome band, generating in seconds").
## Generates the stamp from data/dev.json ("stamp" settings; it is built
## here even when "postage_stamp" is false there) and
##   1. prints how long it took to generate, then the blueprint cells per
##      major biome band ("stamp"."bands": Whittaker regions of spec R2,
##      plus ocean, coast, rivers and lakes) and per biome template, and
##      FAILS if any band has fewer than "min_cells_per_band" cells;
##   2. prints what the walkable world is sized to (chunk grid, ruins,
##      mythical territories, first-camp candidates, river segments);
##   3. with a display, starts the game on the stamp and saves a ground
##      screenshot at the first camp, then the planet map (spec A4
##      overlay: biome, temperature, rainfall, elevation) from four sides.
## With --full it also times the full 400 km planet for comparison.
##
## Run from the project folder:
##   numbers only (no window):
##     ~/bin/godot --headless -s tools/stamp_check.gd [-- --full]
##   numbers and pictures:
##     xvfb-run -a -s "-screen 0 960x540x24" ~/bin/godot --rendering-method forward_plus --resolution 960x540 -s tools/stamp_check.gd
## Writes to $OUT_DIR (default /tmp/shots): stamp_spawn.png,
## stamp_biome.png, stamp_temperature.png, stamp_rainfall.png,
## stamp_elevation.png. Exit code 1 if a band is missing.

## Map sheet layout: front, back (top row); north pole, south pole.
const VIEWS := [[0.0, 0.25], [PI, 0.25], [0.0, 1.35], [0.0, -1.35]] # yaw, pitch


var out_dir := "/tmp/shots"
var world: Node
var failures: Array[String] = []


func _initialize() -> void:
	var env_out := OS.get_environment("OUT_DIR")
	if env_out != "":
		out_dir = env_out
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = get_root().get_node("World")
	_run.call_deferred()


func _run() -> void:
	world._load_dev_settings()
	var seed_: int = int(world.dev.get("seed", 42))
	if "--full" in OS.get_cmdline_user_args():
		world.use_postage_stamp(false)
		var tf := Time.get_ticks_msec()
		world.generate_now(seed_)
		print("[stamp] full planet (%.0f km around, %d cells per face edge): generated in %d ms" % [PlanetConst.CIRCUMFERENCE_M / 1000.0, world.planet_res, Time.get_ticks_msec() - tf])
	world.use_postage_stamp(true)
	var t0 := Time.get_ticks_msec()
	world.generate_now(seed_)
	var gen_ms := Time.get_ticks_msec() - t0
	var map: PlanetData = world.planet
	print("[stamp] postage stamp, seed %d: %.0f km around (radius %.0f m), %d cells per face edge (%d cells, ~%.0f m each), generated in %d ms" % [
		seed_, PlanetConst.CIRCUMFERENCE_M / 1000.0, PlanetConst.RADIUS_M, map.res, map.cell_count, map.cell_m(), gen_ms])
	_count_bands(map)
	_walkable_stats(map)
	if failures.is_empty():
		print("[stamp] PASS: every major biome band is present")
	else:
		for f in failures:
			print("[stamp] FAIL: ", f)
	if DisplayServer.get_name() == "headless":
		print("[stamp] headless: skipping the pictures")
		quit(0 if failures.is_empty() else 1)
		return
	await _pictures()
	quit(0 if failures.is_empty() else 1)


# --- 1. Bands -------------------------------------------------------------------

func _count_bands(map: PlanetData) -> void:
	var stamp: Dictionary = world.dev.get("stamp", {})
	var min_cells := int(stamp.get("min_cells_per_band", 1))
	var per_biome := PackedInt32Array()
	per_biome.resize(BiomeTemplates.COUNT)
	var per_water := {}
	var land := 0
	for c in map.cell_count:
		per_biome[map.biome[c]] += 1
		per_water[map.water[c]] = per_water.get(map.water[c], 0) + 1
		if map.water[c] != PlanetData.Water.OCEAN:
			land += 1
	print("[stamp] land %.0f%% of the planet" % (100.0 * land / map.cell_count))
	var bands: Dictionary = stamp.get("bands", {})
	if bands.is_empty():
		failures.append("data/dev.json has no \"stamp\".\"bands\" to check")
	print("[stamp] cells per band (need %d each):" % min_cells)
	for band in bands:
		var total := 0
		var parts: Array[String] = []
		for key in bands[band]:
			var n := 0
			if str(key).begins_with("water:"):
				var w := PlanetData.Water.keys().find(str(key).substr(6))
				if w < 0:
					failures.append("%s: unknown water kind %s" % [band, key])
					continue
				n = per_water.get(w, 0)
			else:
				var id := BiomeTemplates.id_of_key(str(key))
				if id < 0:
					failures.append("%s: unknown biome key %s" % [band, key])
					continue
				n = per_biome[id]
			total += n
			if n > 0:
				parts.append("%s %d" % [str(key).to_lower(), n])
		print("  %-28s %5d  %s%s" % [band, total, ", ".join(parts), "" if total >= min_cells else "   <-- MISSING"])
		if total < min_cells:
			failures.append("band \"%s\" has %d cells" % [band, total])
	var rows: Array = []
	for id in BiomeTemplates.COUNT:
		if per_biome[id] > 0:
			rows.append([per_biome[id], id])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var line: Array[String] = []
	for r in rows:
		line.append("%s %d" % [BiomeTemplates.name_of(r[1]), r[0]])
	print("[stamp] %d of %d biome templates present: %s" % [rows.size(), BiomeTemplates.COUNT - 1, "; ".join(line)])


# --- 2. The walkable world ---------------------------------------------------------

func _walkable_stats(map: PlanetData) -> void:
	var rivers := RiverNetwork.new(map)
	var ruins := 0
	var n := Ruins.cells_per_face()
	for f in 6:
		for i in n:
			for j in n:
				if not Ruins.find(map, Vector3i(f, i, j)).is_empty():
					ruins += 1
	CreatureSpecies.all()
	var territories := 0
	var tn := Territories.cells_per_face()
	for f in 6:
		for i in tn:
			for j in tn:
				if not Territories.find(map, Vector3i(f, i, j)).is_empty():
					territories += 1
	var camps := Encampment.candidates(map)
	print("[stamp] walkable: chunks %.0f m (%d per face edge), %d river segments, %d ruins, %d mythical territories, %d first-camp candidates" % [
		ChunkManager.chunk_size_m(), TerrainChunk.CHUNKS_PER_FACE, rivers.a.size(), ruins, territories, camps.size()])
	if camps.is_empty():
		failures.append("no first-camp candidate on the stamp")
	else:
		var d: Vector3 = camps[mini(world.spawn_choice, camps.size() - 1)] if world.spawn_choice >= 0 else camps[0]
		var c := map.cell_at(d)
		print("[stamp] first camp: lat %.1f, %s, %.1f °C, %.0f mm/yr" % [rad_to_deg(map.lat[c]), BiomeTemplates.name_of(map.biome[c]), map.temp_c[c], map.precip_mm[c]])
	# How far apart the bands are on foot: pole to equator.
	print("[stamp] equator to pole: %.1f km (%.1f h at walking pace)" % [PlanetConst.CIRCUMFERENCE_M / 4000.0, PlanetConst.CIRCUMFERENCE_M / 4.0 / PlanetConst.WALK_SPEED_MPS / 3600.0])


# --- 3. Pictures ---------------------------------------------------------------------

func _pictures() -> void:
	# The game itself, on the stamp (World keeps the stamp setting).
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	var t0 := Time.get_ticks_msec()
	while not main._playing:
		await process_frame
		if Time.get_ticks_msec() - t0 > 120000:
			failures.append("the game did not start on the stamp within 2 minutes")
			return
	print("[stamp] game started on the stamp after %d ms" % (Time.get_ticks_msec() - t0))
	# Let the plants, creatures and sky settle (a few seconds of play).
	var t1 := Time.get_ticks_msec()
	var frames := 0
	while frames < 30 or Time.get_ticks_msec() - t1 < 4000:
		await process_frame
		frames += 1
	main.hud.visible = false
	await process_frame
	await process_frame
	_save(get_root().get_texture().get_image(), "stamp_spawn.png")

	var overlay: MapOverlay = main.map_overlay
	overlay.toggle(main.player.surface_dir)
	# Stop the game loop (it would re-aim the map's sun at the real sun, so
	# half of each view would be night) and light every view from the
	# camera instead.
	main._playing = false
	var modes := {"biome": MapOverlay.Mode.BIOME, "temperature": MapOverlay.Mode.TEMPERATURE,
		"rainfall": MapOverlay.Mode.RAINFALL, "elevation": MapOverlay.Mode.ELEVATION}
	for mode_name in modes:
		overlay.mode = modes[mode_name]
		overlay._recolor()
		var shots: Array[Image] = []
		for v in VIEWS:
			overlay._yaw = v[0]
			overlay._pitch = v[1]
			overlay.update_map(main.player.surface_dir, 0.0)
			overlay._sun.global_transform = overlay._camera.global_transform
			for i in 4:
				await process_frame
			shots.append(get_root().get_texture().get_image())
		_save(_grid(shots), "stamp_%s.png" % mode_name)
	overlay.toggle(main.player.surface_dir)
	main.queue_free()
	await process_frame
	await process_frame


## Four same-size shots as a 2x2 sheet, labeled by view.
func _grid(shots: Array[Image]) -> Image:
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var sheet := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var img := shots[i]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	return sheet


func _save(img: Image, file: String) -> void:
	var path := out_dir.path_join(file)
	img.save_png(path)
	print("[stamp] wrote ", path)
