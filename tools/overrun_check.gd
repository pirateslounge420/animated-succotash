extends SceneTree
## Overrun ruins: cleared means lit (design 2 Oct §CN), headless, full
## planet:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/overrun_check.gd
## Boots the game and asserts:
##  - a seeded share of the old delve barrows near the opening camp start
##    overrun (worldgen_share; printed);
##  - a cave-mouth (or grotto) camp the dark took is overrun, and the
##    hearth at its opening, laid and lit, clears it (§CO);
##  - the camp sim marks a camp the dark took, with a delve under it,
##    overrun when it goes to ruin; one left for hunger is not; and it
##    never resettles an overrun one, its fire relit or not;
##  - at the nearest overrun barrow: holders keep its delve; lighting the
##    surface hearth doesn't clear it (a barrow's never does; §CO); at night near it the dread fills
##    1.5 times as fast, by day the sound bed goes quiet;
##  - the heart's fire-holder, laid and lit with the swing's rule, holds its
##    own radius (light_radius_m): no holder and no dread hunter comes
##    within it;
##  - lit, it clears the ruin: the log says so, the holders leave by the
##    way out, the bones at the door are gone.

var main
var world
var player: PlanetPlayer
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	WorldSave.read_only = true
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	player.set_physics_process(false)
	var map: PlanetData = world.planet
	var camp: Vector3 = main.camp.site
	# --- The share ---------------------------------------------------------
	var old := 0
	var over := 0
	var target := {}
	var spare := {}
	var bd := INF
	for s in Ruins.near(map, camp, 150000.0):
		if not Delves.has_delve(s) or Ruins.inhabited(s):
			continue
		if not bool(Delves.layout(map, s).get("ok", false)):
			continue
		old += 1
		var dd := CubeSphere.surface_distance_m(s.dir, camp)
		if Overrun.worldgen(s):
			over += 1
			if dd < bd:
				bd = dd
				target = s
		elif spare.is_empty():
			spare = s
	print("[overrun] seed %d: %d of %d old delve barrows within 150 km start overrun (%.0f %%; worldgen_share %.2f)" % [seed_v, over, old, 100.0 * over / maxf(old, 1), float(Overrun.CAMPS_SIM.get("worldgen_share", 0.3))])
	ok(old == 0 or (over > 0 and over < old), "some, not all, of the old delve barrows start overrun")
	if target.is_empty():
		print("SKIP  no overrun barrow within 150 km")
		_done()
		return
	# --- The sim ------------------------------------------------------------
	await _sim_checks(map, spare if not spare.is_empty() else target)
	await _nest_checks(camp)
	# --- The barrow ---------------------------------------------------------
	print("[overrun] the nearest overrun barrow: %.1f km, %s" % [bd / 1000.0, FireStore.biome_key(world, target.dir)])
	var node := await _go_build(map, target)
	if node == null:
		ok(false, "the barrow built")
		_done()
		return
	for i in 90:
		await process_frame
	var holders: Array = main.overrun.holders_of(node)
	var entry: Dictionary = Overrun.holder_entry(map, target.dir, Overrun.id_of(target), FireStore.biome_key(world, target.dir))
	ok(not holders.is_empty(), "something holds the delve: %d of %s (%s)" % [holders.size(), str(entry.creature) if str(entry.creature) != "" else "the dark itself", "the biome's hunter" if bool(entry.hunter) else "the night roster"])
	var props := 0
	for c in world.world_root.get_children():
		if str(c.name).contains("DenSign"):
			props += 1
	ok(props > 0, "bones and scat at the door (%d)" % props)
	# The surface hearth doesn't clear it.
	main.old_hearths.refresh_now()
	var surf: Node3D = main.old_hearths.hearth_of_ruin(null, node)
	if surf != null:
		FireStore.relight(surf)
		await frames(45)
		ok(FireStore.is_lit(surf) and Overrun.is_overrun(target), "a barrow is still not cleared by its surface hearth, lit (%s)" % Overrun.state_of(target))
	# The surface by night and day.
	var door: Vector3 = main.overrun._door_point(node)
	var u0 := Delves.underground
	Delves.underground = 0.0
	ok(absf(Overrun.dread_scale(door + world.dir_of(door) * 1.0 + (node.global_basis.x * 30.0)) - 1.5) < 0.01 and Overrun.dread_scale(door + node.global_basis.x * 400.0) == 1.0, "near it the dread fills 1.5 times as fast; far off, as ever")
	Delves.underground = u0
	# --- Below: the heart --------------------------------------------------
	var lay: Dictionary = node.get_meta("delve")
	var off := float(node.get_meta("delve_off", 0.0))
	var heart: Dictionary = lay.pieces[3]
	var hc: Vector2 = heart.c
	player.global_position = node.global_transform * Vector3(hc.x, float(heart.y0) - off + 0.02, hc.y + float(heart.len) * 0.5)
	for i in 40:
		await process_frame
	ok(Delves.inside and not Dread.den_entry.is_empty(), "down in the heart, the dread is what holds the den (%s)" % str(Dread.den_entry.get("creature", "")))
	main.old_hearths.refresh_now()
	var holder: Node3D = null
	for f in get_nodes_in_group(Campfire.GROUP):
		if (f as Node3D).has_meta("heart_of") and int((f as Node3D).get_meta("heart_of")) == int(target.seed):
			holder = f
	ok(holder != null and not FireStore.is_lit(holder), "the heart's fire-holder stands cold (the ash of the last fire)")
	if holder == null:
		_done()
		return
	var st := FireStore.store_of(holder)
	ok(FireStore.units_now(st) < 0.01 and FireStore.max_units(st) == 3.0, "it starts empty and holds %.0f units" % FireStore.max_units(st))
	# Lay it and light it, the clearing held off while we watch the radius.
	Overrun.hold_clear = true
	ok(FireStore.swing_light(holder, world.days) == "not_laid", "not laid, it won't light")
	FireStore.lay_kindling(holder, Kindling.make("dry_twigs"), world.days)
	for i in 4:
		FireStore.add_fuel(holder, Inventory.make("fuel", {"fuel": "branch"}), world.days)
	ok(FireStore.units_now(st) <= 3.0 + 0.01, "it takes no more than it holds (%.1f units)" % FireStore.units_now(st))
	FireStore.swing_light(holder, world.days)
	for i in 120:
		if FireStore.is_lit(holder):
			break
		await process_frame
	ok(FireStore.is_lit(holder), "laid and lit, it burns")
	var r := float(holder.get_meta("safe_m"))
	var hp := holder.global_position
	ok(Campfire.lit_near(self, hp + Vector3(r - 1.0, 0, 0), 14.0) and not Campfire.lit_near(self, hp + Vector3(r + 1.0, 0, 0), 14.0), "it holds its own radius, %.0f m" % r)
	# The holders and the dread's hunter, from the first room in the dark.
	var room: Dictionary = lay.pieces[1]
	var rc: Vector2 = room.c
	player.global_position = node.global_transform * Vector3(rc.x, float(room.y0) - off + 0.02, rc.y + float(room.len) * 0.3)
	main.dread.force_dark = true
	main.dread.meter = 0.86
	var vis0 := 0
	for h in main.overrun.holders_of(node):
		if is_instance_valid(h) and (h as Node3D).visible:
			vis0 += 1
	var min_h := INF
	var min_d := INF
	var seen_d := 0
	for i in 420:
		await process_frame
		main.dread.meter = maxf(main.dread.meter, 0.82)
		for h in main.overrun.holders_of(node):
			if is_instance_valid(h) and (h as Node3D).visible:
				min_h = minf(min_h, (h as Node3D).global_position.distance_to(hp))
		var dh: Node3D = main.dread._hunter
		if i > 30 and dh != null and dh.visible:
			seen_d += 1
			min_d = minf(min_d, dh.global_position.distance_to(hp))
	main.dread.force_dark = false
	main.dread.meter = 0.0
	ok(vis0 > 0 and min_h >= r, "no holder comes within its radius; %d keep to the dark room (nearest %.1f m)" % [vis0, min_h])
	ok(seen_d == 0 or min_d >= r - 0.5, "nor the dread's hunter (nearest %s over %d frames seen)" % ["%.1f m" % min_d if seen_d > 0 else "-", seen_d])
	# --- The clearing ------------------------------------------------------
	var log_n := GameLog.entries.size()
	Overrun.hold_clear = false
	for i in 30:
		await process_frame
	ok(Overrun.state_of(target) == "cleared", "lighting the heart clears it (%s)" % Overrun.state_of(target))
	var said := false
	for e in GameLog.entries.slice(log_n):
		if str(e.get("text", "")).find("Whatever held this place has gone") >= 0:
			said = true
	ok(said, "the log says so")
	for i in 600:
		await process_frame
	var left := 0
	for h in main.overrun.holders_of(node):
		if is_instance_valid(h) and (h as Node3D).visible:
			left += 1
	ok(left == 0, "the holders have gone by the way out (%d still in sight)" % left)
	var props2 := 0
	for c in world.world_root.get_children():
		if str(c.name).contains("DenSign") and not c.is_queued_for_deletion():
			props2 += 1
	ok(props2 == 0, "the bones at the door are gone (%d)" % props2)
	_done()


func _done() -> void:
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## The camp sim's part: marking, hunger, never resettling.
func _sim_checks(map: PlanetData, site: Dictionary) -> void:
	var cs: CampSim = CampSim.instance
	var d: Vector3 = Camps.ruin_fire_dir(map, site)
	var key := "ruin:check_%d" % int(site.seed)
	var st := cs.ensure(key, d, "tribal", FireStore.biome_key(world, d), int(site.seed))
	var id := Overrun.id_of(site)
	var keep: Dictionary = (Overrun.saved().get(id, {}) as Dictionary).duplicate()
	# Hunger first: no den taken.
	st.state = "abandoned"
	st.why = "left"
	st.blood = false
	st.folk = []
	st.abandoned_day = world.days - 61.0
	cs._tick_empty(st, world.days)
	ok(str(st.state) == "ruin" and not bool(st.get("overrun", false)), "a camp left for hunger goes to ruin, not overrun")
	# The dark.
	st.state = "abandoned"
	st.why = "taken"
	st.blood = true
	st.abandoned_day = world.days - 61.0
	cs._tick_empty(st, world.days)
	ok(str(st.state) == "ruin" and bool(st.get("overrun", false)) and Overrun.state_of(site) == "overrun", "a camp the dark took, a delve under it, is overrun once a ruin")
	# Never resettled, its fire relit or not.
	st.state = "abandoned"
	st.abandoned_day = world.days - 1.0
	var fst: Dictionary = FireStore.stores.get(str(st.fire_key), {})
	fst["state"] = "flames"
	fst["units"] = [["branch", 6.0]]
	FireStore.stores[str(st.fire_key)] = fst
	for i in 3:
		cs._tick_empty(st, world.days)
	ok(str(st.state) != "living" and (st.folk as Array).is_empty(), "the sim never resettles an overrun ruin, its fire lit (%s)" % str(st.state))
	cs.states.erase(key)
	if keep.is_empty():
		Overrun.saved().erase(id)
	else:
		Overrun.saved()[id] = keep


## A cave's den (§CO): a cave-mouth (or grotto) camp the dark took is
## overrun, and lighting the hearth at its opening clears it.
func _nest_checks(camp: Vector3) -> void:
	var nest := {}
	var bd := INF
	for n in Nests.near(camp, 150000.0, ["cave_mouth", "grotto"]):
		var dd := CubeSphere.surface_distance_m(n.dir, camp)
		if dd < bd:
			bd = dd
			nest = n
	if nest.is_empty():
		print("SKIP  no cave mouth or grotto within 150 km")
		return
	var cs: CampSim = CampSim.instance
	var key := str(nest.key)
	var hd: Vector3 = nest.hearth
	var made := not cs.states.has(key)
	var st := cs.ensure(key, hd, "shelter", FireStore.biome_key(world, hd), int(nest.seed))
	var keep_st: Dictionary = st.duplicate(true)
	var fst: Dictionary = FireStore.stores.get(str(st.fire_key), {})
	var keep_f: Dictionary = fst.duplicate(true)
	st.state = "abandoned"
	st.why = "taken"
	st.blood = true
	st.folk = []
	st.abandoned_day = world.days - 61.0
	fst["units"] = []
	fst["state"] = "out"
	fst.erase("kindling")
	FireStore.stores[str(st.fire_key)] = fst
	cs._tick_empty(st, world.days)
	ok(bool(st.get("overrun", false)) and str((Overrun.saved().get(key, {}) as Dictionary).get("state", "")) == "overrun", "a %s camp the dark took is overrun once a ruin (%.1f km)" % [str(nest.kind).replace("_", " "), bd / 1000.0])
	await frames(40)
	ok(str((Overrun.saved().get(key, {}) as Dictionary).get("state", "")) == "overrun", "its hearth cold, it stays overrun")
	# Laid with kindling and fuel, lit with the swing's rule.
	var probe := Node3D.new()
	probe.set_meta("fuel_key", str(st.fire_key))
	FireStore.lay_kindling(probe, Kindling.make("dry_twigs"), world.days)
	FireStore.add_fuel(probe, Inventory.make("fuel", {"fuel": "branch"}), world.days)
	var how := FireStore.swing_light(probe, world.days)
	FireStore._take(fst, 5.0)
	ok(how in ["ok", "catching"] and FireStore.is_lit(probe), "the hearth at its opening, laid and lit (%s)" % how)
	var log_n := GameLog.entries.size()
	await frames(40)
	var said := false
	for e in GameLog.entries.slice(log_n):
		if str(e.get("text", "")).find("cave's mouth") >= 0:
			said = true
	ok(str((Overrun.saved().get(key, {}) as Dictionary).get("state", "")) == "cleared" and said, "lighting it clears the den, and the log says so")
	probe.free()
	# Put things back.
	Overrun.saved().erase(key)
	if made:
		cs.states.erase(key)
	else:
		cs.states[key] = keep_st
	FireStore.stores[str(st.fire_key)] = keep_f


## Stand by the barrow and build it; returns its node.
func _go_build(map: PlanetData, site: Dictionary) -> Node3D:
	var lay := Delves.layout(map, site)
	var fr := Delves.frame(map, site)
	var d := Delves.to_dir(fr, 0.0, float(lay.zc) - 6.0)
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	player.global_position -= off
	main.chunks.load_blocking(d)
	player.spawn_at(d, site.dir)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 40000:
		main.landmarks.build_ruin_at(d)
		for c in main.landmarks.built_ruins():
			var n: Node3D = main.landmarks.built_ruins()[c]
			if is_instance_valid(n) and int((n.get_meta("site") as Dictionary).seed) == int(site.seed) and n.has_meta("delve"):
				return n
		await process_frame
	return null
