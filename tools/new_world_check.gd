extends SceneTree
## Run: DEV_PIN=0 godot --headless --path . --script tools/new_world_check.gd
##      DEV_PIN=1 godot --headless --path . --script tools/new_world_check.gd
## Design 1 Oct §CB (every new world is a new world). With DEV_PIN=0 (play's
## rule even in a tool): no last-world pointer, boot a world, note its seed
## and first camp, then "New world" (Main.start_new_world) and boot the
## next; the two seeds and spawn cells must differ, the pointer must name
## the second, and the first world's save must still exist. With DEV_PIN=1:
## the dev pins (seed 42, spawn 0). Cleans up the worlds it made.

var fails := 0
var made: Array[int] = []


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _boot() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	for i in 10:
		await process_frame
	return main


func _describe(main: Node, world: Node) -> Dictionary:
	var d: Vector3 = main.camp.site
	var cell: int = world.planet.cell_at(d)
	var biome: String = BiomeTemplates.KEYS[world.planet.biome[cell]]
	var first := ""
	if not GameLog.entries.is_empty():
		first = str(GameLog.entries[0].get("text", ""))
	var out := {"seed": world.world_seed, "cell": cell, "biome": biome, "kind": world.first_camp_kind, "people": main.camp.people_id, "log": first, "spawn_choice": world.spawn_choice, "now": main._now_text(main.player.surface_dir), "first_day": WorldSave.data.get("first_local_day", null)}
	print("[world] seed %d · cell %d · %s · kind '%s' · people %s · %s · log: %s" % [out.seed, out.cell, out.biome, out.kind, out.people, out.now, out.log])
	return out


func _run() -> void:
	var world = get_root().get_node("World")
	Bow.need_capture = false
	var pinned := OS.get_environment("DEV_PIN") == "1"
	if pinned:
		var main = await _boot()
		var a := _describe(main, world)
		var want_seed := int(world.dev.get("seed", 42))
		var want_spawn := int(world.dev.get("spawn_choice", 0))
		ok(a.seed == want_seed and a.spawn_choice == want_spawn, "DEV_PIN=1: dev.json's pins, seed %d, spawn_choice %d (got %d / %d; the tools pin spawn 0 themselves)" % [want_seed, want_spawn, a.seed, a.spawn_choice])
		ok(WorldSave.read_only, "a tool never writes a save")
		print("RESULT fails: %d" % fails)
		quit(1 if fails > 0 else 0)
		return
	# Play's rule: start with no pointer.
	var had_pointer := FileAccess.file_exists(WorldSave.LAST_PATH)
	var old_pointer := FileAccess.get_file_as_string(WorldSave.LAST_PATH) if had_pointer else ""
	if had_pointer:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WorldSave.LAST_PATH))
	var main = await _boot()
	var a := _describe(main, world)
	made.append(a.seed)
	ok(a.seed > 0 and a.seed != 42, "a fresh world rolled its own seed (%d)" % a.seed)
	ok(WorldSave.last_seed() == a.seed, "the last-world pointer names it")
	ok(a.log.begins_with("World %d" % a.seed), "the log opens with the world's name (%s)" % a.log)
	ok(str(a.now).begins_with("Day 1 ") and a.log.contains("— day 1"), "a world opens on Day 1 (%s; design 1 Oct §CG)" % a.now)
	ok(a.first_day != null, "its save keeps its first local day (%s)" % str(a.first_day))
	WorldSave.flush(0.0, true)
	ok(WorldSave.exists(a.seed), "its save exists after the flush")
	# "New world": the scene asks the tool to rebuild it.
	main.start_new_world()
	await process_frame
	await process_frame
	main = await _boot()
	var b := _describe(main, world)
	made.append(b.seed)
	ok(b.seed != a.seed, "New world rolled another seed (%d vs %d)" % [b.seed, a.seed])
	ok(b.cell != a.cell, "and another first camp cell (%d vs %d)" % [b.cell, a.cell])
	ok(WorldSave.last_seed() == b.seed, "the pointer moved to the new world")
	ok(WorldSave.exists(a.seed), "the old world's save stays")
	ok(not GameLog.entries.is_empty() and str(GameLog.entries[0].get("text", "")).begins_with("World %d" % b.seed), "the new world's log is its own (first line: %s)" % b.log)
	# Continue: booting again lands in the last world.
	main.queue_free()
	await process_frame
	await process_frame
	main = await _boot()
	var c := _describe(main, world)
	ok(c.seed == b.seed and c.cell == b.cell, "Continue boots into the last world at the same camp")
	ok(b.first_day != null and c.first_day == b.first_day, "Continue keeps the world's first local day (%s; %s)" % [str(c.first_day), c.now])
	# A world keeps its camp (1 Oct, Mike's Mac): change what a seed would
	# pick (the first-camp weights: this kind out), Continue from the file,
	# and the camp is where it was.
	var site_c: Vector3 = main.camp.site
	WorldSave.flush(0.0, true)
	ok(WorldSave.data.has("opening_site"), "the save keeps the opening camp's site (opening_site)")
	var kinds: Dictionary = Encampment.FC.get("kinds", {})
	var old_w := {}
	for k in kinds:
		old_w[k] = (kinds[k] as Dictionary).get("weight", 1)
		(kinds[k] as Dictionary)["weight"] = 0.0 if str(k) == c.kind else 5.0
	main.queue_free()
	await process_frame
	await process_frame
	WorldSave.path = ""
	main = await _boot()
	var dm := CubeSphere.surface_distance_m(main.camp.site, site_c)
	ok(world.world_seed == c.seed and dm < 1.0, "with the weights changed, Continue rebuilds the camp where it was (%.1f m off; kind '%s')" % [dm, world.first_camp_kind])
	for k in kinds:
		(kinds[k] as Dictionary)["weight"] = old_w[k]
	# A save from before the camp was kept (pre-d690997): no opening_site,
	# a hearth that is no ruin camp's fire. That hearth was the opening camp.
	var old_site := site_c
	for k in 24:
		var q := CreatureSpawner._offset(site_c, k * TAU / 24.0, 2600.0)
		if world.planet.water[world.planet.cell_at(q)] == PlanetData.Water.NONE and world.planet.terrain.elevation(q, true) > 2.0 and not main._at_ruin_camp(q):
			old_site = q
			break
	WorldSave.data.erase("opening_site")
	WorldSave.data.erase("first_camp_kind")
	WorldSave.data["hearth"] = [old_site.x, old_site.y, old_site.z]
	WorldSave.mark_dirty()
	WorldSave.flush(0.0, true)
	main.queue_free()
	await process_frame
	await process_frame
	WorldSave.path = ""
	main = await _boot()
	dm = CubeSphere.surface_distance_m(main.camp.site, old_site)
	ok(dm < 1.0, "an older save: the camp is rebuilt at its hearth (%.1f m off)" % dm)
	var op: Dictionary = RoadNetwork.opening
	var node: Vector3 = op.get("node", Vector3.ZERO)
	var road_on := false
	for l in main.chunks.roads.links_near(node, 400.0, true):
		if bool(l.get("opening", false)):
			road_on = true
	ok(node != Vector3.ZERO and CubeSphere.surface_distance_m(node, old_site) < 40.0 and road_on, "and its opening road starts there (node %.0f m from the fire, road %s to a people's camp %.1f km off)" % [CubeSphere.surface_distance_m(node, old_site), "routed" if road_on else "missing", float(op.get("camp_m", INF)) / 1000.0])
	ok(WorldSave.data.has("opening_site"), "the migrated site is kept from now on")
	# Never wake at no fire: a hearth where no fire stands wakes you at the
	# opening camp, with a line in the log.
	if Tuning.profile() == "ambient":
		var nowhere := CreatureSpawner._offset(main.camp.site, 2.0, 3300.0)
		Hearth.dir = nowhere
		Hearth.key = FireStore.key_of(nowhere)
		main._on_player_died()
		for i in 600:
			await process_frame
		var woke := CubeSphere.surface_distance_m(main.player.surface_dir, main.camp.site)
		var said := false
		for e in GameLog.entries:
			if str(e.get("text", "")) == "Your hearth was gone; you woke at the camp.":
				said = true
		ok(woke < 30.0 and said and CubeSphere.surface_distance_m(Hearth.dir, main.camp.site) < 1.0, "a hearth with no fire: you wake at the camp (%.0f m from it), the log says so (%s), and the camp is your hearth again" % [woke, said])
	# Clean up what this check made; the player's own pointer is put back.
	for sd in made:
		var path := ProjectSettings.globalize_path("user://worlds/%d.json" % sd)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if had_pointer:
		var f := FileAccess.open(WorldSave.LAST_PATH, FileAccess.WRITE)
		if f:
			f.store_string(old_pointer)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WorldSave.LAST_PATH))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
