extends SceneTree
## Run: STAMP=1 SEEDS=7,8,9 godot --headless --path . --script tools/first_camp_check.gd
##      STAMP=1 SEEDS=7 KINDS=forest,savanna,cold_shore godot --headless ...
## Design 1 Oct §CB, second half (the first camp's kind rolls too): boots a
## world per seed (the seed pinned, the first camp rolled by kind from the
## seed) and prints its kind, biome, people, fuel kind and spawn cell; with
## KINDS, forces each kind in turn (FIRST_CAMP) on the first seed. PASS
## when every world's camp sits in a biome its kind lists, with fuel, and
## the roll is the same twice for one seed. Lists any kind with no
## candidates on each planet.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _boot(world: Node, sd: int) -> Node:
	world.pin(sd, -1)
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	for i in 5:
		await process_frame
	return main


func _describe(main: Node, world: Node, label: String) -> Dictionary:
	var d: Vector3 = main.camp.site
	var cell: int = world.planet.cell_at(d)
	var biome: String = BiomeTemplates.KEYS[world.planet.biome[cell]]
	var out := {"seed": world.world_seed, "cell": cell, "biome": biome, "kind": world.first_camp_kind, "people": main.camp.people_id, "fuel": FireStore.best_kind(world, d), "lat": rad_to_deg(world.planet.lat[cell])}
	var first := GameLog.world_line()
	print("[camp] %s: seed %d · kind '%s' · %s · people %s · fuel %s · cell %d (lat %.0f) · log: %s" % [label, out.seed, out.kind, biome, out.people, out.fuel, cell, out.lat, first])
	var empty := []
	for k in Encampment.FC.get("kinds", {}):
		if (Encampment.candidates_by_kind(world.planet).get(k, PackedVector3Array()) as PackedVector3Array).is_empty():
			empty.append(k)
	print("[camp] kinds with no candidates on this planet: %s" % (str(empty) if not empty.is_empty() else "none"))
	if out.kind != "":
		var listed: Array = (Encampment.FC.kinds[out.kind] as Dictionary).get("biomes", [])
		ok(listed.has(biome), "%s: the camp's biome %s is one its kind (%s) lists" % [label, biome, out.kind])
		ok(out.fuel != "", "%s: the biome offers fuel (%s)" % [label, out.fuel])
	return out


func _run() -> void:
	var world = get_root().get_node("World")
	Bow.need_capture = false
	var seeds: Array = Array(OS.get_environment("SEEDS").split(",")) if OS.get_environment("SEEDS") != "" else ["7", "8", "9"]
	var kinds: Array = Array(OS.get_environment("KINDS").split(",")) if OS.get_environment("KINDS") != "" else []
	var seen := {}
	for s in seeds:
		var main = await _boot(world, int(s))
		var a := _describe(main, world, "seed %s" % s)
		seen[a.kind] = seen.get(a.kind, 0) + 1
		# The same seed again: the same camp.
		main.queue_free()
		await process_frame
		await process_frame
		main = await _boot(world, int(s))
		var b := _describe(main, world, "seed %s again" % s)
		ok(a.cell == b.cell and a.kind == b.kind, "seed %s rolls the same first camp twice" % s)
		main.queue_free()
		await process_frame
		await process_frame
	for k in kinds:
		OS.set_environment("FIRST_CAMP", k)
		var main = await _boot(world, int(seeds[0]))
		var c := _describe(main, world, "forced %s" % k)
		ok(c.kind == k or c.kind == "", "FIRST_CAMP=%s gives that kind when it has candidates (got '%s')" % [k, c.kind])
		main.queue_free()
		await process_frame
		await process_frame
	OS.set_environment("FIRST_CAMP", "")
	print("[camp] kinds seen across the seeds: %s" % str(seen))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
