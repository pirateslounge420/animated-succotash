extends SceneTree
## Food passed round, the night stories, the gift (design 5 Oct §EJ),
## headless:
##   STAMP=1 SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/sharing_check.gd
## On seed 7731:
##  - at a camp with a full food store, over game days, the store's shown
##    pieces fall by piece_off_store_per_meal at each meal and by nothing at
##    other times; the built store's pieces follow (one more until the
##    carrier takes it off, then one fewer);
##  - the food units match the sim before and after (the meal eats nothing:
##    a night tick with the meal falls by exactly a tick's eating);
##  - the folk who hunted that day never carries the meal;
##  - the player standing in the circle at the meal gets a bowl, and the
##    log line once per camp;
##  - night_stories never plays by day, never at a low fire, never with two
##    tellers; every listener looks at the teller;
##  - gift_back fires exactly once per camp after after_player_brings_units
##    and never before;
##  - CampSim has no per-folk food or wood field.

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
	print("[sharing] seed %d" % seed_v)
	Workshop.instant = true
	Sharing.instant = true
	_meals()
	_scene_meal()
	_stories()
	_gift()
	_no_private()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _state(key: String, d: Vector3, pid: String, rung: int) -> Dictionary:
	var cs: CampSim = main.camp_sim
	var st := cs.ensure(key, d, pid, FireStore.biome_key(world, d), hash([key]), 8)
	st.rung = rung
	var folk: Array = []
	for i in 8:
		folk.append({"sex": "m" if i % 2 == 0 else "f", "stage": "child" if i >= 6 else "adult", "born": 0.0, "role": "", "seed": i})
	folk[0].role = "headman"
	folk[1].role = "plantkeeper"
	st.folk = folk
	st.state = "living"
	st.trades = []
	return st


## The game day at which camp `st`'s local clock reads hour `h`, on or
## after `from`.
func _at_hour(st: Dictionary, from: float, h: float) -> float:
	var lon: float = CubeSphere.longitude(main.camp_sim._dir(st)) / TAU
	var base: float = floor(from + lon) - lon
	var t: float = base + h / 24.0
	if t < from:
		t += 1.0
	return t


## Game days at a storage camp with a full store: the pieces, the meals,
## the food, the carriers.
func _meals() -> void:
	var cs: CampSim = main.camp_sim
	var d: Vector3 = CreatureSpawner._offset(main.camp.site, 2.5, 320.0)
	var st := _state("share:meals", d, "river", 2)
	var store: Dictionary = CampSim.SIM.get("store", {})
	st.food = float(store.get("food_days_target", 7.0)) * float(store.get("food_units_per_folk_day", 1.0)) * cs.folk_count(st) * 1.2
	st.erase("meal")
	var th := CampSim.tick_days()
	var days := _at_hour(st, float(world.days) + 2.0, 0.0)
	st.last_tick = days
	var off := int(Sharing.S.get("piece_off_store_per_meal", 1))
	var meal_falls: Array = []
	var other_falls: Array = []
	var food_bad: Array = []
	var carrier_bad: Array = []
	var meals := 0
	var prev := -1
	for k in int(14.0 / th):
		st.wood = 30.0
		var n0 := int((st.get("meal", {}) as Dictionary).get("n", 0))
		var food0 := float(st.food)
		var h := cs.clock_h(st, days)
		var night := h < 6.0 or h >= 19.0
		var eat := cs.eat_per_day(st) * th
		var hunts0 := int(st.get("hunts", 0))
		cs._tick(st, days)
		var p := Sharing.pieces(st)
		var n1 := int((st.get("meal", {}) as Dictionary).get("n", 0))
		if prev >= 0:
			if n1 > n0:
				meals += 1
				if prev - p != off and prev > 0:
					meal_falls.append([snappedf(h, 0.1), prev, p])
				# A night tick: the store falls by a tick's eating, the meal
				# eats nothing more.
				var m: Dictionary = st.meal
				# (Not a tick a hunt's meat came in on.)
				if night and absf((food0 - float(st.food)) - minf(eat, food0)) > 1e-4 and int(st.get("hunts", 0)) == hunts0:
					food_bad.append([snappedf(h, 0.1), snappedf(food0 - float(st.food), 0.001), snappedf(eat, 0.001)])
				var hunter := int(m.get("hunter", -1))
				if int(m.get("carrier", -1)) == hunter and hunter >= 0:
					carrier_bad.append(int(m.day))
				if int(m.get("carrier", -1)) >= 0 and not CampSim.is_adult(st.folk[int(m.carrier)]):
					carrier_bad.append("child %d" % int(m.day))
			elif p < prev:
				other_falls.append([snappedf(h, 0.1), prev, p])
		prev = p
		days += th
	print("  %d meals over 14 game days at a full store (%d hunts); pieces now %d" % [meals, int(st.get("hunt_count", 0)), Sharing.pieces(st)])
	ok(meals >= 13 and meal_falls.is_empty(), "the store's pieces fall by piece_off_store_per_meal (%d) at each meal %s" % [off, str(meal_falls.slice(0, 4))])
	ok(other_falls.is_empty(), "and by nothing at other times %s" % str(other_falls.slice(0, 4)))
	# The meal tick itself: Sharing.tick never touches the food.
	var probe := st.duplicate(true)
	probe.meal.day = -999
	var f0 := float(probe.food)
	Sharing.tick(cs, probe, _at_hour(probe, days, Sharing.meal_h() + 0.2), Sharing.meal_h() + 0.2)
	ok(food_bad.is_empty() and absf(float(probe.food) - f0) < 1e-9, "the food units match the sim before and after each meal: no double eating %s" % str(food_bad.slice(0, 3)))
	# The hunter of the day: forced to be the one whose turn it was.
	var day := int(floor(days + CubeSphere.longitude(cs._dir(st)) / TAU))
	var would := Sharing.carrier_of(st, day)
	st.hunt = {"day": day, "state": "out", "hunter": would}
	var now := Sharing.carrier_of(st, day)
	var hunted_ok := true
	for e in st.get("meal_log", []):
		if int(e.carrier) == int(e.hunter) and int(e.hunter) >= 0:
			hunted_ok = false
	ok(carrier_bad.is_empty() and hunted_ok and now != would and now >= 0, "the folk who hunted that day never carries the meal (forced: %d hunted, %d carries) %s" % [would, now, str(carrier_bad)])


## A built camp at its meal: the carrier walks the piece off, the store
## shows one fewer, the bowls go round, the player in the circle gets one.
func _scene_meal() -> void:
	var cs: CampSim = main.camp_sim
	var camps: Camps = main.camps
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var d := CreatureSpawner._offset(pd, 0.7, 90.0)
	var key := "share:scene"
	var st := _state(key, d, "river", 1)
	st.food = 20.0
	st.erase("meal")
	var at: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d))
	var root: Node3D = camps._build(at, "tribal", hash([key, "s"]), key)
	var fs: Node3D = root.get_meta("food_store")
	var holders: Array = []
	for s in root.get_meta("sitters"):
		if (s as Node3D).has_meta("stage"):
			holders.append(s)
	var days := _at_hour(st, float(world.days) + 1.0, Sharing.meal_h() - 1.2)
	st.last_tick = days
	cs._tick(st, days)
	var pp: Vector3 = root.global_position + root.global_basis.x * 1.5
	var time := 100.0
	Sharing.live(root, st, holders, fs, days, cs.clock_h(st, days), time, 0.1, pp, null)
	CampProps.show_food_pieces(fs, Sharing.shown(root, st))
	var before := fs.get_node("Stock").get_child_count()
	var lines0 := _lines("They shared their food with you.")
	var results: Array = []
	for meal_k in 2:
		days = _at_hour(st, days + 0.1, Sharing.meal_h() + 0.3)
		st.last_tick = days - CampSim.tick_days()
		cs._tick(st, days)
		var b0 := fs.get_node("Stock").get_child_count()
		var carrier_seen := false
		var counts: Array = []
		for f in 8:
			time += 0.5
			var circle := Sharing.live(root, st, holders, fs, days, cs.clock_h(st, days), time, 0.5, pp, null)
			if circle.size() < holders.size():
				carrier_seen = true
			var want := Sharing.shown(root, st)
			if int(fs.get_meta("pieces", -1)) != want:
				CampProps.show_food_pieces(fs, want)
			counts.append(fs.get_node("Stock").get_child_count())
		var eating := 0
		for h in holders:
			if str((h as Node3D).get_meta("idle", "")) == "eat_bowl":
				eating += 1
		results.append({"b0": b0, "after": counts[counts.size() - 1], "carrier": carrier_seen, "eating": eating, "bowl": float(root.get_meta("player_bowl_until", -1.0)) > time})
	print("  built store at the meals: %s" % str(results))
	var r0: Dictionary = results[0]
	ok(before == r0.b0 and int(r0.b0) - int(r0.after) == int(Sharing.S.get("piece_off_store_per_meal", 1)) and bool(r0.carrier), "the built store shows one piece fewer once the carrier has taken it off (%d -> %d), a carrier walked it" % [int(r0.b0), int(r0.after)])
	ok(int(r0.eating) == holders.size(), "every seated folk eats from a bowl after the meal (%d of %d)" % [int(r0.eating), holders.size()])
	ok(bool(r0.bowl) and bool((results[1] as Dictionary).bowl) and _lines("They shared their food with you.") - lines0 == 1, "the player in the circle gets a bowl at each meal, and the log line once (%d lines)" % (_lines("They shared their food with you.") - lines0))
	root.queue_free()


func _lines(txt: String) -> int:
	var n := 0
	for e in GameLog.entries:
		if str((e as Dictionary).get("text", "")).find(txt) >= 0:
			n += 1
	return n


## The circle's loops through long days and nights: the telling.
func _stories() -> void:
	var camps: Camps = main.camps
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var d := CreatureSpawner._offset(pd, 2.2, 90.0)
	var key := "share:stories"
	var st := _state(key, d, "river", 1)
	var at: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d))
	var root: Node3D = camps._build(at, "tribal", hash([key, "s"]), key)
	var holders: Array = []
	for s in root.get_meta("sitters"):
		if (s as Node3D).has_meta("stage"):
			holders.append(s)
	var fire: Node3D = root.get_meta("fire")
	var far: Vector3 = root.global_position + root.global_basis.x * 200.0
	var by_day := 0
	var at_low := 0
	var two := 0
	var told := 0
	var look_bad := 0
	var looks := 0
	var time := 1000.0
	for phase in ["day", "night_low", "night"]:
		for h in holders:
			(h as Node3D).set_meta("idle", "")
		for k in 3000:
			time += 0.5
			var ctx := {"food_ok": true, "fire_low": phase == "night_low", "fire_out": false}
			FireCircle.animate(holders, fire, time, 0.5, far, "day" if phase == "day" else "night", ctx)
			var tellers: Array = holders.filter(func(s): return str((s as Node3D).get_meta("idle", "")) == "night_stories")
			if tellers.size() > 1:
				two += 1
			if tellers.is_empty():
				continue
			# (A teller who began this very frame: the ones before it in the
			# ring look next frame.)
			var fresh := float((tellers[0] as Node3D).get_meta("idle_from", 0.0)) >= time
			match phase:
				"day":
					by_day += 1
				"night_low":
					at_low += 1
				"night":
					told += 1
					if fresh:
						continue
					var t: Node3D = tellers[0]
					for s in holders:
						var n: Node3D = s
						if n == t or str(n.get_meta("idle", "")) == "doze":
							continue
						looks += 1
						if str(n.get_meta("look_target", "")) != str(t.name):
							look_bad += 1
	print("  telling: %d frames by night (fed), %d by day, %d at a low fire, %d with two tellers; %d listener looks, %d not at the teller" % [told, by_day, at_low, two, looks, look_bad])
	ok(told > 0 and by_day == 0 and at_low == 0 and two == 0, "night_stories plays at night by a fed fire, never by day, never at a low fire, never two tellers")
	ok(looks > 0 and look_bad == 0, "every listener looks at the teller for the hold")
	root.queue_free()


## The gift: after after_player_brings_units, once.
func _gift() -> void:
	var cs: CampSim = main.camp_sim
	var camps: Camps = main.camps
	var g: Dictionary = Sharing.S.get("gift_back", {})
	var need := float(g.get("after_player_brings_units", 6))
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var given: Array = []
	var early: Array = []
	var k := 0
	for pid in ["river", "coast", "steppe"]:
		var d := CreatureSpawner._offset(pd, 3.5 + k, 95.0)
		k += 1
		var key := "share:gift:%s" % pid
		var st := _state(key, d, pid, 2)
		st.food = 30.0
		var at: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d))
		var root: Node3D = camps._build(at, "tribal", hash([key, "s"]), key)
		var fs: Node3D = root.get_meta("food_store")
		var holders: Array = []
		for s in root.get_meta("sitters"):
			if (s as Node3D).has_meta("stage"):
				holders.append(s)
		var inv := Inventory.new()
		inv.carried.resize(10)
		var pp: Vector3 = root.global_position + root.global_basis.x * 6.0
		var days := _at_hour(st, float(world.days) + 1.0, Sharing.gather_end() + 0.4)
		var time := 50.0
		# Brought in ones: before the line, a whole dusk with you near gives
		# nothing.
		var brought := 0.0
		while brought + 1.0 < need:
			cs.add_food(st, 1.0)
			brought += 1.0
		for f in 40:
			time += 0.5
			Sharing.live(root, st, holders, fs, days, cs.clock_h(st, days), time, 0.5, pp, inv)
		if int(st.get("gift_count", 0)) > 0 or _count(inv) > 0 or Sharing.give(st, inv):
			early.append(pid)
		cs.add_wood(st, 1.0)
		for night in 3:
			for f in 40:
				time += 0.5
				Sharing.live(root, st, holders, fs, days, cs.clock_h(st, days), time, 0.5, pp, inv)
			cs.add_food(st, 2.0)
			days += 1.0
		given.append([pid, int(st.get("gift_count", 0)), _count(inv), str(st.get("gift_kind", ""))])
		root.queue_free()
	print("  gifts: %s" % str(given))
	ok(early.is_empty(), "no gift before after_player_brings_units (%.0f) %s" % [need, str(early)])
	var once := given.all(func(e): return int(e[1]) == 1 and int(e[2]) == 1)
	ok(once, "the gift comes exactly once per camp after it, into the pack")
	ok(_lines("gave you a") >= given.size(), "the log says it (%d lines)" % _lines("gave you a"))


func _count(inv: Inventory) -> int:
	var n := 0
	for it in inv.carried:
		if it != null:
			n += 1
	return n


## One store per camp: no folk record holds food or wood, and the sim's
## code never gives a folk one.
func _no_private() -> void:
	var bad: Array = []
	for key in main.camp_sim.states:
		if not Sharing.one_store(main.camp_sim.states[key]):
			bad.append(key)
	var src := FileAccess.get_file_as_string("res://scripts/peoples/camp_sim.gd")
	var re := RegEx.create_from_string("(\\bf|\\bfolk\\[[^\\]]*\\]|\\bfo)\\s*(\\.|\\[\")\\s*(food|wood)\\b")
	var hits := re.search_all(src)
	ok(bad.is_empty() and hits.is_empty(), "no per-folk food or wood: %d states checked, %d code hits %s" % [main.camp_sim.states.size(), hits.size(), str(bad.slice(0, 3))])
