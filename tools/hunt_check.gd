extends SceneTree
## The whole animal (design 5 Oct §EK), headless:
##   STAMP=1 SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/hunt_check.gd
## At a storage-rung camp with game in reach, over 14 game days:
##  - hunts land between 2 and 6 (hunts_per_game_week 1-3);
##  - every hunt's carrier is an adult who is not the keeper;
##  - after process_game_h the camp's pieces rise by the class's
##    things_shown and the food store by food_units[class];
##  - the hearth lamp is fed (lit at night) after the hunt and not before;
##  - the log line comes once per species, with the player near;
## and:
##  - no hunt where every class in reach is at its floor (GameCounts),
##    and the counts come back after respawn_game_days;
##  - a marine_mammal hunt only ever at a tundra or coast camp;
##  - the carcass goes in at the workshop's back door, out of sight from
##    every place round the fire (physics rays from eye height), at every
##    people's workshop.

var fails := 0
var world
var main


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := DirAccess.open("user://worlds")
	if dir:
		for f in dir.get_files():
			dir.remove(f)
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	for i in 120:
		await physics_frame
	print("[hunt] seed %d" % seed_v)
	Workshop.instant = true
	_fortnight()
	_floor()
	_marine()
	await _out_of_sight()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _state(key: String, d: Vector3, pid: String) -> Dictionary:
	var cs: CampSim = main.camp_sim
	var st := cs.ensure(key, d, pid, FireStore.biome_key(world, d), hash([key]), 8)
	st.rung = 2
	var folk: Array = []
	for i in 8:
		folk.append({"sex": "m" if i % 2 == 0 else "f", "stage": "child" if i >= 6 else "adult", "born": 0.0, "role": "", "seed": i})
	folk[0].role = "headman"
	folk[1].role = "plantkeeper"
	st.folk = folk
	st.state = "living"
	st.trades = []
	return st


func _fortnight() -> void:
	var cs: CampSim = main.camp_sim
	var d: Vector3 = CreatureSpawner._offset(main.camp.site, 2.0, 300.0)
	var st := _state("hunt:check", d, "river")
	var classes := GameCounts.classes_at(world.planet, CreatureSpawner._offset(d, 0.0, 600.0))
	print("  game in reach: %s" % str(classes.keys()))
	var lon := CubeSphere.longitude(d) / TAU
	# Start at the top of a local week, at midnight.
	var days: float = floor(float(world.days) + lon) - lon + 7.0
	days += float(7 - posmod(int(floor(days + lon)), 7))
	st.last_tick = days
	cs.player_dir = d
	var th := CampSim.tick_days()
	var fed_before_any := false
	var first_done := -1.0
	var food_jumps: Array = []
	var pieces_ok := true
	var keeper := Workshop.keeper_of(st)
	var log_before := GameLog.entries.size()
	var prev_state := ""
	for k in int(14.0 / th):
		st.wood = 30.0
		var food0 := float(st.food)
		var pieces0 := (st.get("hunt_pieces", []) as Array).size()
		cs._tick(st, days)
		var hs: Dictionary = st.get("hunt", {})
		if str(hs.get("state", "")) == "done" and prev_state == "processing":
			var cls := str(hs["class"])
			var want_food := float((Hunt.H.food_units as Dictionary).get(cls, 0.0))
			var got := float(st.food) - food0
			food_jumps.append([cls, snappedf(got, 0.01), want_food])
			var added := (st.get("hunt_pieces", []) as Array).size() - pieces0
			if added != Hunt.parts_shown(cls).size() and pieces0 < 12:
				pieces_ok = false
			if first_done < 0.0:
				first_done = days
		if first_done < 0.0 and Hunt.lamp_fed(st, days):
			fed_before_any = true
		prev_state = str(hs.get("state", ""))
		days += th
	var n := int(st.get("hunt_count", 0))
	ok(n >= 2 and n <= 6, "hunts at a storage camp over 14 game days: %d (2-6)" % n)
	var bad_hunter: Array = []
	for e in st.get("hunt_log", []):
		var i := int(e.hunter)
		if i == keeper or not CampSim.is_adult(st.folk[i]):
			bad_hunter.append(i)
	ok(bad_hunter.is_empty() and n > 0, "every hunter is an adult who is not the keeper (keeper %d) %s" % [keeper, str(bad_hunter)])
	var food_bad := food_jumps.filter(func(j): return float(j[1]) + 0.3 < float(j[2]))
	ok(not food_jumps.is_empty() and food_bad.is_empty() and pieces_ok, "after each hunt's processing the pieces rise by things_shown and the store by food_units %s" % str(food_jumps.slice(0, 4)))
	ok(not fed_before_any and first_done > 0.0 and Hunt.lamp_fed(st, first_done), "the hearth lamp has no fat before the first hunt is processed, and has it after")
	var lines := 0
	var species := {}
	for i in range(log_before, GameLog.entries.size()):
		var t := str(GameLog.entries[i].get("text", ""))
		if t.find("The hunters brought back") >= 0:
			lines += 1
			species[t] = int(species.get(t, 0)) + 1
	var kinds := {}
	for e in st.get("hunt_log", []):
		kinds[str(e.species)] = true
	ok(lines == kinds.size() and species.values().all(func(c): return int(c) == 1), "the log line comes once per species (%d lines, %d species hunted)" % [lines, kinds.size()])


## Every class in reach at its floor: no hunt; after respawn_game_days the
## counts are back.
func _floor() -> void:
	var map: PlanetData = world.planet
	var d: Vector3 = CreatureSpawner._offset(main.camp.site, 4.0, 900.0)
	var st := _state("hunt:floor", d, "river")
	var days: float = float(world.days)
	var cells := {}
	var r := 300.0
	while r <= 950.0:
		for k in 96:
			var p := CreatureSpawner._offset(d, TAU * k / 96.0, r)
			cells[map.cell_at(p)] = GameCounts.classes_at(map, p)
		r += 25.0
	var fl := GameCounts.floor_n()
	for c in cells:
		for cls in cells[c]:
			GameCounts.set_count(int(c), str(cls), fl, days)
	var started := Hunt.start(st, days, 1, map, d)
	ok(not started, "no hunt where every class in reach is at its floor (%d regions)" % cells.size())
	var later := days + float(GameCounts.G.get("respawn_game_days", 4)) + 0.1
	var back := true
	for c in cells:
		for cls in cells[c]:
			if GameCounts.count(int(c), str(cls), later) != GameCounts.capacity(str(cls)):
				back = false
	ok(back and Hunt.start(st, later, 2, map, d), "after respawn_game_days the counts are back at capacity and the camp hunts again")


## marine_mammal only for tundra and coast camps, at every camp site near.
func _marine() -> void:
	var map: PlanetData = world.planet
	var bad: Array = []
	var marine := 0
	var tried := 0
	var sites: Array = [main.camp.site]
	for r in Ruins.near(map, main.camp.site, 15000.0):
		sites.append(r.dir)
	for si in sites.size():
		for pid in Peoples.ids():
			var st := _state("hm:%d:%s" % [si, pid], sites[si], str(pid))
			for k in 6:
				if Hunt.start(st, float(world.days) + k, 100 + k, map, sites[si]):
					tried += 1
					if str(st.hunt["class"]) == "marine_mammal":
						marine += 1
						if not str(pid) in ["tundra", "coast"]:
							bad.append(str(pid))
	ok(bad.is_empty(), "marine mammals are hunted only by tundra and coast camps (%d of %d hunts were marine) %s" % [marine, tried, str(bad)])


## The carcass goes in at the back door: from every place round the fire at
## eye height the door is hidden (a physics ray hits the hut first).
func _out_of_sight() -> void:
	var camps: Camps = main.camps
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var built: Array = []
	var k := 0
	for pid in Peoples.ids():
		var key := "hv:%s" % pid
		var d := CreatureSpawner._offset(pd, TAU * k / Peoples.ids().size(), 120.0)
		k += 1
		var st := _state(key, d, str(pid))
		var at: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d))
		built.append([str(pid), camps._build(at, "tribal", hash([key, "s"]), key)])
	for i in 6:
		await physics_frame
	var space: PhysicsDirectSpaceState3D = main.get_viewport().world_3d.direct_space_state
	var seen: Array = []
	for b in built:
		var root: Node3D = b[1]
		if root.has_meta("canopy") or not root.has_meta("workshop"):
			continue
		var ws: Node3D = root.get_meta("workshop")
		var bd: Node3D = ws.get_node_or_null("BackDoor")
		if bd == null:
			seen.append("%s: no back door" % b[0])
			continue
		var target: Vector3 = bd.global_position + root.global_basis.y * 0.8
		var visible := 0
		for a in 12:
			var ang := TAU * a / 12.0
			var eye: Vector3 = root.to_global(Vector3(cos(ang) * 2.6, 1.5, sin(ang) * 2.6))
			var q := PhysicsRayQueryParameters3D.create(eye, target)
			var hit := space.intersect_ray(q)
			if hit.is_empty() or (hit.position as Vector3).distance_to(target) < 0.3:
				visible += 1
		if visible > 0:
			seen.append("%s: seen from %d of 12" % [b[0], visible])
	ok(seen.is_empty(), "the back door, where the carcass goes in, is out of sight from all round the fire at every people's workshop %s" % str(seen))
	for b in built:
		(b[1] as Node).queue_free()
	await process_frame
