extends SceneTree
## Third places (design 5 Oct §EM), headless:
##   STAMP=1 SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/third_places_check.gd
## On seed 7731, at camps built round the player (every people, at the
## storage rung so the porch exists) and at a hot spring:
##  - a camp has at least one third place when its people file lists one
##    and the feature is there (a tree within 60 m, a bank within 60 m, a
##    hot spring within soak.hot_spring_m, the workshop);
##  - no camp places a kind its people file does not list;
##  - every seat passes the back-and-view test (something solid within 2 m
##    behind, nothing within 1.5 m in front);
##  - the soak is placed only within hot_spring_m of a HOT_SPRING cell and
##    never holds more than its max_at_once;
##  - through a day the folk on jobs (at a bench, out, the porch by the
##    plan) are the same with third places on and off;
##  - a folk in the soak has the hood down and nobody anywhere else does;
##  - the sim's food, wood and folk are identical over 3 game days with
##    third places on and off.

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
	print("[third places] seed %d" % seed_v)
	Workshop.instant = true
	ThirdPlaces.instant = true
	_placed()
	_tree()
	_soak()
	_day()
	_sim()
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


func _build(key: String, d: Vector3, pid: String) -> Node3D:
	_state(key, d, pid)
	var at: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d))
	return main.camps._build(at, "tribal", hash([key, "s"]), key)


## Is the feature of `kind` there for camp `root` at `d`?
func _feature(kind: String, root: Node3D, d: Vector3) -> bool:
	match kind:
		"great_tree_bench":
			for t in ThirdPlaces._trees(root, {"chunks": main.chunks}):
				var p: Vector3 = t[0]
				if Vector2(p.x, p.z).length() <= ThirdPlaces.TREE_M and Vector2(p.x, p.z).length() >= 5.0:
					return true
			return false
		"water_rock":
			var ws := CampNeeds.water_spot(world, main.chunks, d)
			return str(ws.kind) != "seep" and CubeSphere.surface_distance_m(ws.dir, d) <= ThirdPlaces.WATER_M
		"soak":
			return ThirdPlaces.hot_spring_near(world.planet, d, float(ThirdPlaces.kind_row("soak").get("hot_spring_m", 400.0))) != Vector3.ZERO
		"hut_porch":
			return root.has_meta("workshop")
	return false


func _placed() -> void:
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var ids: Array = Peoples.ids()
	var listed_bad: Array = []
	var missing: Array = []
	var seat_bad: Array = []
	var tally := {}
	var camps := 0
	for ring in 2:
		for k in ids.size():
			var pid := str(ids[k])
			var d := CreatureSpawner._offset(pd, TAU * (k + 0.5 * ring) / ids.size(), 110.0 + 70.0 * ring)
			var key := "tp:%d:%s" % [ring, pid]
			var root := _build(key, d, pid)
			if root.has_meta("canopy"):
				root.queue_free()
				continue
			camps += 1
			var people := Peoples.get_people(pid)
			var listed := ThirdPlaces.listed(people)
			var places: Array = root.get_meta("third_places", [])
			if ring == 0 and k == 0:
				var all_t := 0
				for ck in main.chunks.chunks:
					all_t += (main.chunks.chunks[ck] as TerrainChunk).trees.size()
				print("  %d chunks loaded, %d trees in them" % [main.chunks.chunks.size(), all_t])
				var tr := ThirdPlaces._trees(root, {"chunks": main.chunks})
				var near := tr.filter(func(t): return Vector2((t[0] as Vector3).x, (t[0] as Vector3).z).length() <= ThirdPlaces.TREE_M)
				print("  first camp: %d trees within %.0f m (tallest %.1f m)" % [near.size(), ThirdPlaces.TREE_M, near.map(func(t): return float(t[2])).max() if not near.is_empty() else 0.0])
			var kinds: Array = []
			for p in places:
				kinds.append(str(p.kind))
				tally[str(p.kind)] = int(tally.get(str(p.kind), 0)) + 1
				if str(p.kind) != "own" and not listed.has(str(p.kind)):
					listed_bad.append("%s %s" % [pid, p.kind])
				if str(p.kind) == "soak":
					var sc: int = world.planet.cell_at(p.spring)
					if int(world.planet.biome[sc]) != BiomeTemplates.HOT_SPRING or CubeSphere.surface_distance_m(p.spring, d) > float(ThirdPlaces.kind_row("soak").get("hot_spring_m", 400.0)) + 1.0:
						listed_bad.append("%s soak away from a spring" % pid)
				for s in p.seats:
					if not ThirdPlaces.prospect_ok(s, root.get_meta("tp_solids", []), main.camps._ground_fn(root)):
						seat_bad.append("%s %s" % [pid, p.kind])
			var exists := false
			for kind in listed:
				if _feature(str(kind), root, d):
					exists = true
			if exists and places.is_empty():
				missing.append(pid)
			root.queue_free()
	print("  %d camps; places: %s" % [camps, str(tally)])
	ok(missing.is_empty() and tally.size() >= 2, "every camp whose people list a third place, with the feature there, has one %s" % str(missing))
	ok(listed_bad.is_empty(), "no camp places a kind its people file does not list %s" % str(listed_bad))
	ok(seat_bad.is_empty(), "every seat has something solid within 2 m behind and an open view in front %s" % str(seat_bad.slice(0, 5)))


## The great tree: a camp 20 m from the tallest tree loaded; its bench at
## the trunk's foot, back to the trunk.
func _tree() -> void:
	var best_h := 0.0
	var best := Vector3.ZERO
	for ck in main.chunks.chunks:
		var ch: TerrainChunk = main.chunks.chunks[ck]
		for i in ch.trees.size():
			if float(ch.trees[i][1]) > best_h:
				best_h = float(ch.trees[i][1])
				best = ch.tree_base(i)
	if best_h <= 0.0:
		print("SKIP  no tree loaded")
		return
	var td: Vector3 = world.dir_of(best)
	var d := CreatureSpawner._offset(td, 1.3, 20.0)
	var root := _build("tp:tree", d, "river")
	var bench := {}
	for p in root.get_meta("third_places", []):
		if str(p.kind) == "great_tree_bench":
			bench = p
	var ok_back := false
	if not bench.is_empty():
		var tp: Vector3 = bench.tree
		ok_back = true
		for s in bench.seats:
			var behind: Vector3 = (s.pos as Vector3) - (s.face as Vector3) * 1.0
			if Vector2(behind.x - tp.x, behind.z - tp.z).length() > 1.6:
				ok_back = false
	print("  the great tree: a %.0f m tree, the camp 20 m off it; bench %s" % [best_h, "placed, %d seats" % (bench.seats as Array).size() if not bench.is_empty() else "not placed"])
	ok(not bench.is_empty() and ok_back and absf(float(bench.tree_h) - best_h) < 0.01, "a camp beside the biggest tree has its bench at the trunk's foot, the sitters' backs to the trunk")
	root.queue_free()


## A hot spring: the nearest HOT_SPRING cell to the player; a mountain camp
## (they list the soak) 150 m from it.
func _soak() -> void:
	var map: PlanetData = world.planet
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var best := -1
	var best_m := INF
	for c in map.biome.size():
		if int(map.biome[c]) == BiomeTemplates.HOT_SPRING and int(map.water[c]) == PlanetData.Water.NONE:
			var m := CubeSphere.surface_distance_m(map.dir[c], pd)
			if m < best_m:
				best_m = m
				best = c
	if best < 0:
		print("SKIP  no hot spring on this planet")
		return
	var spring: Vector3 = map.dir[best]
	# Walk the spring's cell to its edge, then 150 m out.
	var d := CreatureSpawner._offset(spring, 0.9, 150.0)
	var hs := ThirdPlaces.hot_spring_near(map, d, float(ThirdPlaces.kind_row("soak").get("hot_spring_m", 400.0)))
	print("  hot spring cell %d, %.1f km from the player; the camp 150 m off it" % [best, best_m / 1000.0])
	# Moving the player there loads its ground.
	main.player.global_position = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d) + 2.0)
	var root := _build("tp:soak", d, "mountain")
	var places: Array = root.get_meta("third_places", [])
	var soak := {}
	for p in places:
		if str(p.kind) == "soak":
			soak = p
	var near_ok := false
	if not soak.is_empty():
		var c: int = map.cell_at(soak.spring)
		near_ok = int(map.biome[c]) == BiomeTemplates.HOT_SPRING and CubeSphere.surface_distance_m(soak.spring, d) <= float(ThirdPlaces.kind_row("soak").get("hot_spring_m", 400.0)) + 1.0
	ok(hs != Vector3.ZERO and not soak.is_empty() and near_ok, "a camp within hot_spring_m of a hot spring has the soak, placed at the spring (%d seats)" % ((soak.seats as Array).size() if not soak.is_empty() else 0))
	_soak_by_day(root)
	root.queue_free()


var _soak_most := 0
var _hood_bad := 0
var _hood_soak := 0


## Through an afternoon at the soak camp: never more than max_at_once in
## it; hoods down only there.
func _soak_by_day(root: Node3D) -> void:
	var cs: CampSim = main.camp_sim
	var st: Dictionary = cs.state_of("tp:soak")
	var holders: Array = []
	for s in root.get_meta("sitters"):
		if (s as Node3D).has_meta("stage"):
			holders.append(s)
	var keeper := Workshop.keeper_of(st)
	var mx := ThirdPlaces.max_of("soak")
	var hr := ThirdPlaces.hours_of("soak")
	var time := 0.0
	var h := hr.x - 0.5
	while h < hr.y + 0.5:
		time += 1.0
		var at_fire := Workshop.fire_sitters(holders)
		ThirdPlaces.live(root, at_fire, keeper, h, time, 1.0, main.player.global_position + Vector3(0, 0, 5000), root.get_meta("fire"), true)
		var in_soak := 0
		for hv in holders:
			var n: Node3D = hv
			var tp: Dictionary = n.get_meta("tp", {})
			var soaking := not tp.is_empty() and str(tp.kind) == "soak" and int(tp.leg) == 1
			if soaking:
				in_soak += 1
			if bool(n.get_meta("hood_down", false)) and not soaking:
				_hood_bad += 1
			if soaking and not bool(n.get_meta("hood_down", false)):
				_hood_bad += 1
			if soaking:
				_hood_soak += 1
		_soak_most = maxi(_soak_most, in_soak)
		h += 0.1
	print("  the soak through the afternoon: most in it at once %d (max %d); hood-down sitter-steps %d, wrong %d" % [_soak_most, mx, _hood_soak, _hood_bad])
	ok(_soak_most >= 1 and _soak_most <= mx, "folk walk to the soak in the afternoon, never more than max_at_once (%d of %d)" % [_soak_most, mx])
	ok(_hood_soak > 0 and _hood_bad == 0, "a folk in the soak has the hood down, and nobody anywhere else does")


## A day at a storage camp near the player: jobs the same with third
## places on and off; and the hood up everywhere but the soak.
func _day() -> void:
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var cs: CampSim = main.camp_sim
	var out: Array = []
	for on in [true, false]:
		ThirdPlaces.ON = on
		var d := CreatureSpawner._offset(pd, 0.4, 130.0)
		var root := _build("tp:day:%s" % str(on), d, "river")
		var st: Dictionary = cs.state_of("tp:day:%s" % str(on))
		st.trades = []
		var holders: Array = []
		for s in root.get_meta("sitters"):
			if (s as Node3D).has_meta("stage"):
				holders.append(s)
		var ws: Node3D = root.get_meta("workshop") if root.has_meta("workshop") else null
		var keeper := Workshop.keeper_of(st)
		var lon := CubeSphere.longitude(cs._dir(st)) / TAU
		var base: float = floor(float(world.days) + lon) + 1.0 - lon
		var jobs: Array = []
		var at_places := 0
		var hood_bad := 0
		for step in 120:
			var days: float = base + (6.5 + step * 0.1) / 24.0
			var h := cs.clock_h(st, days)
			var plan := Workshop.plan_now(st, days)
			if ws != null:
				Workshop.drive(holders, ws, plan, 1.0, step, Vector3.ZERO, true)
			var fire_s := Workshop.fire_sitters(holders)
			ThirdPlaces.live(root, fire_s, keeper, h, float(step), 1.0, Vector3.ZERO, root.get_meta("fire"), true)
			var on_jobs := 0
			for hv in holders:
				var n: Node3D = hv
				if str(n.get_meta("station", "fire")) != "fire" or str(n.get_meta("going", "")) != "":
					on_jobs += 1
				if not (n.get_meta("tp", {}) as Dictionary).is_empty():
					at_places += 1
					if bool(n.get_meta("hood_down", false)) and str((n.get_meta("tp") as Dictionary).kind) != "soak":
						hood_bad += 1
			jobs.append(on_jobs)
		out.append({"jobs": jobs, "at_places": at_places, "hood_bad": hood_bad, "places": (root.get_meta("third_places", []) as Array).map(func(p): return str(p.kind))})
		root.queue_free()
	ThirdPlaces.ON = true
	print("  a river camp's day: places %s; sitter-steps at a third place %d (on) / %d (off)" % [str(out[0].places), int(out[0].at_places), int(out[1].at_places)])
	ok(out[0].jobs == out[1].jobs, "through the day the folk on jobs are the same with third places on and off (jobs first, third places from the rest)")
	ok(int(out[0].at_places) > 0 and int(out[1].at_places) == 0 and int(out[0].hood_bad) == 0, "folk go to the third places by day (and none with them off); hoods stay up away from the soak")


## The sim: 3 game days with third places on and off, the same.
func _sim() -> void:
	var cs: CampSim = main.camp_sim
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var res: Array = []
	for on in [true, false]:
		ThirdPlaces.ON = on
		# The same camp from the same start each time (and the game counts
		# fresh: a hunt takes from them).
		WorldSave.data["game_counts"] = {}
		if cs.states.has("tp:sim"):
			FireStore.stores.erase(str((cs.states["tp:sim"] as Dictionary).get("fire_key", "")))
		cs.states.erase("tp:sim")
		var d := CreatureSpawner._offset(pd, 2.0, 400.0)
		var st := _state("tp:sim", d, "river")
		st.food = 20.0
		st.wood = 20.0
		st.seed = 99
		var days: float = floor(float(world.days)) + 3.0
		st.last_tick = days
		for k in int(3.0 / CampSim.tick_days()):
			days += CampSim.tick_days()
			cs._tick(st, days)
		res.append([snappedf(float(st.food), 0.0001), snappedf(float(st.wood), 0.0001), (st.folk as Array).size()])
	ThirdPlaces.ON = true
	ok(res[0] == res[1], "the sim's food, wood and folk are identical over 3 game days with third places on and off %s" % str(res))
