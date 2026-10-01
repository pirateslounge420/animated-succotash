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
	var out := {"seed": world.world_seed, "cell": cell, "biome": biome, "kind": world.first_camp_kind, "people": main.camp.people_id, "log": first, "spawn_choice": world.spawn_choice}
	print("[world] seed %d · cell %d · %s · kind '%s' · people %s · log: %s" % [out.seed, out.cell, out.biome, out.kind, out.people, out.log])
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
