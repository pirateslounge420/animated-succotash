extends SceneTree
## The hub camp's check (design §GC.1-2, §FZ.1, queue 112; HubCamp,
## crawler.json hub), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/hub_check.gd
## HUB_SEEDS= how many game seeds for the layout part (30 by default).
## Asserts, from the layout alone (HubCamp.plan) over seeds 1..HUB_SEEDS:
##   three seeds give three different camps; the same seed the same camp
##   twice; each start kind (stone, ruins, vines) across the seeds; the
##   spawn on the walkable floor, flat, out of the river, by the fire; no
##   river between the spawn and the way down (the straight walk crosses
##   no water); every one of the five keepers placed, each on walkable
##   ground, apart from the others, the fisher-weaver's by the river and
##   the rest out of it.
## Then in the game (SEED=7): it starts on the camp, you by its fire, the
## sun at dusk and sinking, the cook-shaman, the cauldron's glow, the five
## keepers and the river there; down the steps behind the fire into the
## ruin (on its landing, the dungeon in the tree); back up its way out into
## the same camp, by the fire; and a Continue (the scene again, no SEED)
## opens the same camp, by the fire, at dusk.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _sig(pl: Dictionary) -> String:
	var parts := [str(pl.kind), str((pl.camp.pos as Vector3).snapped(Vector3.ONE * 0.01)), str(snappedf(float(pl.P.across_m), 0.01))]
	for s in pl.sites:
		parts.append("%s@%s" % [s.keeper, str((s.at as Vector3).snapped(Vector3.ONE * 0.01))])
	return "|".join(parts)


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	Controls.path = "user://controls_hub.cfg"
	ok(HubCamp.on(), "crawler.json hub.on")
	var n_seeds := int(OS.get_environment("HUB_SEEDS")) if OS.get_environment("HUB_SEEDS").is_valid_int() else 30
	var kinds := {}
	var sigs := {}
	var bad_spawn := []
	var bad_path := []
	var bad_sites := []
	var keepers_n: int = ((HubCamp.H.get("keepers", {}) as Dictionary).get("list", {}) as Dictionary).size()
	var apart := float((HubCamp.H.get("keepers", {}) as Dictionary).get("apart_m", 9.0))
	for g in range(1, n_seeds + 1):
		var lay := TombKit.layout(hash([g, "check"]) % 100000 + 1, "tomb")
		var pl := HubCamp.plan(lay, g)
		kinds[pl.kind] = int(kinds.get(pl.kind, 0)) + 1
		sigs[g] = _sig(pl)
		var land: SurfaceGround = pl.land
		var sp: Vector3 = pl.camp.spawn
		var s2 := Vector2(sp.x, sp.z)
		var fp: Vector3 = pl.camp.pos
		if not land.inside(s2, 20.0) or land.slope_at(sp.x, sp.z) > 0.3 or land.in_wash(s2) > 0.0 or s2.distance_to(Vector2(fp.x, fp.z)) > 4.0:
			bad_spawn.append(g)
		# The walk from the spawn round the fire to the stair's mouth: no water.
		# (To a step short of the stair's own cut, which is the way down.)
		var mouth: Vector2 = (pl.stair.mouth as Vector2) + (pl.stair.n as Vector2) * (land.cell + 1.0)
		var wet := false
		var last_h := land.height_at(s2.x, s2.y)
		var step_m := s2.distance_to(mouth) / 40.0
		for i in 41:
			var q := s2.lerp(mouth, i / 40.0)
			var h := land.height_at(q.x, q.y)
			# Water, or a rise steeper than a walkable slope along the walk.
			if land.in_wash(q) > 0.0 or (i > 0 and absf(h - last_h) > maxf(step_m, 0.01) * 0.6):
				wet = true
			last_h = h
		if wet:
			bad_path.append(g)
		var sites: Array = pl.sites
		var bad := sites.size() != keepers_n
		for i in sites.size():
			var a: Vector3 = sites[i].at
			var a2 := Vector2(a.x, a.z)
			if not land.inside(a2, 20.0):
				bad = true
			if str(sites[i].keeper) == "fisher_weaver":
				var w := land.wash_at(a2)
				if land.in_wash(a2) > 0.05 or w.x > float((land.G.get("wash", {}) as Dictionary).get("width_m", 9.0)) + 4.0:
					bad = true
			elif land.zone_at(a2, 0.0) == "wash":
				bad = true
			for j in range(i + 1, sites.size()):
				if a.distance_to(sites[j].at) < apart - 0.01:
					bad = true
		if bad:
			bad_sites.append(g)
	print("  kinds over %d seeds: %s" % [n_seeds, str(kinds)])
	ok(sigs[1] != sigs[2] and sigs[2] != sigs[3] and sigs[1] != sigs[3], "three seeds, three different camps")
	var again := HubCamp.plan(TombKit.layout(hash([2, "check"]) % 100000 + 1, "tomb"), 2)
	ok(_sig(again) == sigs[2], "the same seed gives the same camp twice")
	ok(kinds.has("stone") and kinds.has("ruins") and kinds.has("vines"), "each start kind across %d seeds" % n_seeds)
	ok(bad_spawn.is_empty(), "the spawn by the fire, on flat walkable ground out of the river, every seed (bad: %s)" % str(bad_spawn))
	ok(bad_path.is_empty(), "no river or cliff between the spawn and the way down, every seed (bad: %s)" % str(bad_path))
	ok(bad_sites.is_empty(), "all %d keepers' sites placed, apart, on walkable ground, the fisher-weaver by the river, every seed (bad: %s)" % [keepers_n, str(bad_sites)])
	# In the game.
	OS.set_environment("SEED", "7")
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	var w := 0
	while not main.on_surface and w < 3000:
		await process_frame
		w += 1
	await _frames(10)
	var hub := main.surface as HubCamp
	ok(main.on_surface and hub != null, "a new game starts on the hub camp")
	if hub == null:
		_finish()
		return
	var fp: Vector3 = hub.camp.pos
	var pp := main.player.global_position
	ok(Vector2(pp.x, pp.z).distance_to(Vector2(fp.x, fp.z)) < 4.0, "you start by its fire (%.1f m)" % Vector2(pp.x, pp.z).distance_to(Vector2(fp.x, fp.z)))
	var days := float(main.world.get("days"))
	var sun := Surface.sun_deg_at(days)
	ok(sun > -2.0 and sun < 6.0 and Surface.sun_deg_at(days + 0.01) < sun, "at dusk: the sun %.1f deg and sinking" % sun)
	ok(hub.shaman != null and hub.get_node_or_null("Cauldron/BrewGlow") != null, "the hooded cook-shaman at the cauldron, its brew glowing")
	ok(hub.keeper_folk.size() == hub.sites.size() and hub.sites.size() == keepers_n, "the five keepers at their sites (%s)" % ", ".join(hub.sites.map(func(x): return str(x.keeper))))
	ok(hub.get_node_or_null("River") != null, "the river")
	ok(hub.fire != null and bool(hub.fire.get_meta("lit", false)), "the campfire burning")
	var first_sig := _sig({"kind": hub.kind, "camp": hub.camp, "P": hub.P, "sites": hub.sites})
	# Down the steps behind the fire.
	await main.go_down()
	await _frames(10)
	ok(not main.on_surface and main.tomb != null and main.tomb.is_inside_tree(), "down the steps behind the fire into the ruin")
	var ex: Dictionary = main.lay.exits[0]
	ok(main.player.global_position.distance_to(ex.p) < 4.0, "on the ruin's landing by its way out")
	# Back up its way out.
	await main.go_up()
	await _frames(10)
	ok(main.on_surface and main.surface == hub, "up the ruin's way out into the same camp")
	pp = main.player.global_position
	ok(Vector2(pp.x, pp.z).distance_to(Vector2(fp.x, fp.z)) < 4.0, "back by the fire")
	# Continue: the scene again, no SEED: the last game (the save in memory).
	main.queue_free()
	await _frames(5)
	OS.set_environment("SEED", "")
	var main2: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main2)
	w = 0
	while not main2.on_surface and w < 3000:
		await process_frame
		w += 1
	await _frames(10)
	var hub2 := main2.surface as HubCamp
	ok(CrawlerSave.continued and hub2 != null, "Continue reopens the camp")
	if hub2 != null:
		ok(_sig({"kind": hub2.kind, "camp": hub2.camp, "P": hub2.P, "sites": hub2.sites}) == first_sig, "the same camp as before")
		pp = main2.player.global_position
		var fp2: Vector3 = hub2.camp.pos
		ok(Vector2(pp.x, pp.z).distance_to(Vector2(fp2.x, fp2.z)) < 4.0 and Surface.sun_deg_at(float(main2.world.get("days"))) < 6.0, "by its fire at dusk again")
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(Controls.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Controls.path))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
