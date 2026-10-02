extends SceneTree
## Folk come back to a cleared ruin (design 2 Oct §CN part 4), headless,
## full planet:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/settle_check.gd
## Boots the game, takes two overrun barrows near the opening camp, gives
## the country a living camp near its ceiling within 40 km, and asserts,
## through the sim's own catch-up (CampSim._process, the clock moved on):
##  - a cleared ruin whose surface hearth burns gets no one before
##    arrive_after_game_h, then 2-4 folk from that camp (which has them no
##    more); it is a living camp with its people, built by Camps when you
##    come, its fire a hearth you can take (§AY);
##  - an overrun ruin, never cleared, its hearth lit all the same, never
##    gets anyone;
##  - a ruin that fell lately gets its survivors back from the camp they
##    fled to;
##  - a settled camp the dark takes again is overrun again.

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
	var cs: CampSim = CampSim.instance
	# Two overrun barrows, the nearer first.
	var found: Array = []
	for s in Ruins.near(map, camp, 150000.0):
		if Overrun.worldgen(s) and bool(Delves.layout(map, s).get("ok", false)):
			found.append(s)
	found.sort_custom(func(a, b): return CubeSphere.surface_distance_m(a.dir, camp) < CubeSphere.surface_distance_m(b.dir, camp))
	if found.size() < 3:
		print("SKIP  fewer than three overrun barrows within 150 km")
		_done()
		return
	var target: Dictionary = found[0]
	var control: Dictionary = found[1]
	var third: Dictionary = found[2]
	# A living camp near its ceiling within 40 km of the target.
	var src_d := CreatureSpawner._offset(target.dir, 1.0, 6000.0)
	var src := cs.settle("check_src", src_d, "tribal", FireStore.biome_key(world, src_d), 4242, _folk(7, 1), world.days)
	FireStore.stores[str(src.fire_key)] = {"units": [["branch", 6.0]], "embers_min": 0.0, "state": "flames", "tended": true}
	var src_n0: int = cs.folk_count(src)
	print("[settle] the source camp: %d folk, cap %d" % [src_n0, cs.cap(src)])
	# The target cleared, its hearth burning; the control lit but not cleared.
	Overrun.clear(target, world.days)
	_light_hearth(map, target)
	_light_hearth(map, control)
	var key := Overrun.camp_key(map, target)
	ok(key != "", "the ruin's camp key: %s" % key)
	var days0: float = world.days
	await _sim_to(days0 + 0.01)
	await _sim_to(days0 + 6.0 / 24.0)
	ok(Overrun.state_of(target) == "cleared" and not cs.states.has(key), "six game hours on: nobody yet")
	await _sim_to(days0 + 13.0 / 24.0)
	ok(Overrun.state_of(target) == "settled", "thirteen game hours on: folk have come (%s)" % Overrun.state_of(target))
	var st: Dictionary = cs.states.get(key, {})
	var n := (st.get("folk", []) as Array).size()
	ok(str(st.get("state", "")) == "living" and n >= 2 and n <= 4, "a living camp of %d (2-4), the %s" % [n, str(st.get("people", ""))])
	ok(cs.folk_count(src) == src_n0 - n, "they walked over from the camp near its ceiling (%d -> %d)" % [src_n0, cs.folk_count(src)])
	ok(Overrun.state_of(control) == "overrun" and not cs.states.has(Overrun.camp_key(map, control)), "an overrun ruin never cleared gets nobody, its hearth lit or not")
	# Survivors: a ruin that fell lately.
	var id3 := Overrun.id_of(third)
	var src_n1: int = cs.folk_count(src)
	Overrun.saved()[id3] = {"state": "overrun", "fell": world.days - 5.0, "day": world.days - 5.0, "dir": [third.dir.x, third.dir.y, third.dir.z], "people": "north", "went_to": "check_src", "survivors": 2}
	Overrun.clear(third, world.days)
	_light_hearth(map, third)
	var d1: float = world.days
	await _sim_to(d1 + 0.01)
	await _sim_to(d1 + 13.0 / 24.0)
	var st3: Dictionary = cs.states.get(Overrun.camp_key(map, third), {})
	ok(Overrun.state_of(third) == "settled" and (st3.get("folk", []) as Array).size() == 2 and str(st3.get("people", "")) == "north" and cs.folk_count(src) == src_n1 - 2, "a ruin that fell lately gets its 2 survivors back, its own people")
	# Built when you come: a camp with folk at the fire, a hearth to take.
	await _go(map, target)
	var node: Node3D = null
	for i in 600:
		await process_frame
		if main.camps._camps.has(key):
			node = main.camps._camps[key]
			break
	ok(node != null and (node.get_meta("sitters", []) as Array).size() > 0, "Camps builds it: %d at the fire" % ((node.get_meta("sitters", []) as Array).size() if node != null else 0))
	if node != null:
		var fire: Node3D = node.get_meta("fire")
		ok(FireStore.is_lit(fire) and Hearth.can_set(fire), "its fire burns, a hearth you can take")
		ok(main.old_hearths.nearest(fire.global_position, 6.0) == null, "the old hearth gave way to the camp's fire")
	# Dark again.
	st.state = "abandoned"
	st.why = "taken"
	st.blood = true
	st.folk = []
	st.abandoned_day = world.days - 61.0
	cs._tick_empty(st, world.days)
	ok(Overrun.state_of(target) == "overrun", "taken again, it is overrun again")
	_done()


func _done() -> void:
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _folk(n: int, s: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({"sex": "m" if i % 2 == 0 else "f", "stage": "adult", "born": 0.0, "role": "", "seed": s * 100 + i})
	return out


## Light the ruin's surface hearth (its old hearth, as you would) and keep
## it burning.
func _light_hearth(map: PlanetData, site: Dictionary) -> void:
	var fd := Camps.ruin_fire_dir(map, site)
	var st := OldHearths.store_at(world, fd)
	st.units = []
	for i in 10:
		(st.units as Array).append(["hardwood_log", FireStore.burn_min("hardwood_log")])
	st.state = "flames"
	st.tended = true
	(WorldSave.data["old_hearths"] as Dictionary)[FireStore.key_of(fd)] = st


## Move the clock and let the sim catch up as it does (CampSim._process).
func _sim_to(days: float) -> void:
	world.days = days
	# Keep the hearths fed: a check of the settlers, not of the burn.
	for k in (WorldSave.data["old_hearths"] as Dictionary):
		var st: Dictionary = WorldSave.data["old_hearths"][k]
		st["seen"] = days
	for i in 70:
		await process_frame


func _go(map: PlanetData, site: Dictionary) -> void:
	var fd := Camps.ruin_fire_dir(map, site)
	var d := CreatureSpawner._offset(fd, 0.5, 8.0)
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	player.global_position -= off
	main.chunks.load_blocking(d)
	player.spawn_at(d, fd)
	for i in 20:
		main.landmarks.build_ruin_at(fd)
		await process_frame
	main.camps.refresh_now()
