extends SceneTree
## The workshop (design 5 Oct §EL), headless:
##   STAMP=1 SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/workshop_check.gd
## Builds a camp for every people (Camps._build, beside the opening camp),
## some at or past the storage rung and some below, and checks:
##  - every camp at or past storage has exactly one workshop with a soft
##    and a hard bench (each with 3-5 props) and a door; none below has one;
##  - a marsh camp's porch_sign is the reed-mat press, a tundra camp's the
##    burning stone lamp (lit by day); every sign reads at 40 m (§BU);
##  - the kiln stands only where huts.kiln is non-empty, 4-8 m from the hut
##    and downwind within 30 deg of the mean wind;
##  - a folk at a bench plays only that bench's idles and sounds; no folk is
##    at two benches in a tick, no seat holds two, nobody crosses benches
##    more than cross_bench_per_day_max times a day;
##  - the maker's bench time over a game day is within 0.1 of
##    maker_bench_share;
##  - during the gather hours the fire circle holds only the keeper and the
##    children; at dusk everyone is back in the circle;
##  - the player's materials land on the bench that works them;
##  - the hearth's lamps are dark by day and lit at night;
##  - a workshop with its props has at most twice the triangles of a §CY
##    fire circle with its seats (and its fire);
##  - the opening camp has none below storage and builds one at storage.

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
	print("[workshop] seed %d" % seed_v)
	Workshop.instant = true
	_opening_below()
	await _camps()
	await _opening_at_storage()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Triangles under `n` (every MeshInstance3D below it).
func tris(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: Mesh = (n as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx != null and (idx as PackedInt32Array).size() > 0:
				t += (idx as PackedInt32Array).size() / 3
			else:
				t += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	for c in n.get_children():
		t += tris(c)
	return t


func _opening_below() -> void:
	var st: Dictionary = main.camp_sim.state_of("opening")
	ok(int(st.get("rung", 0)) < Workshop.rung_index() and main.camp.workshop == null, "the opening camp below storage (rung %d) has no workshop" % int(st.get("rung", 0)))


## A state for `key` of `people_id` at `d`, at `rung`, with `n` folk (two
## children among them), roles as the ladder gives them.
func _state(key: String, d: Vector3, people_id: String, rung: int, n: int) -> Dictionary:
	var cs: CampSim = main.camp_sim
	var st := cs.ensure(key, d, people_id, FireStore.biome_key(world, d), hash([key, "ws"]), n)
	st.rung = rung
	var folk: Array = []
	for i in n:
		folk.append({"sex": "m" if i % 2 == 0 else "f", "stage": "child" if i >= n - 2 else "adult", "born": 0.0, "role": "", "seed": i})
	st.folk = folk
	st.state = "living"
	if rung >= 2:
		folk[0].role = "headman"
		folk[1].role = "plantkeeper"
	if rung >= 3:
		folk[2].role = "maker"
	return st


func _camps() -> void:
	var camps: Camps = main.camps
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var ids: Array = Peoples.ids()
	var built := {}
	var below_with := []
	var at_storage := 0
	var bad_shape := []
	var kiln_bad := []
	var sign_bad := []
	var budget_bad := []
	var idle_bad := []
	var max_ratio := 0.0
	var k := 0
	for pid in ids:
		for rung in [1, 2, 3]:
			var key := "wscheck:%s:%d" % [pid, rung]
			var d := CreatureSpawner._offset(pd, TAU * k / (ids.size() * 3.0), 60.0 + 25.0 * (k % 4))
			k += 1
			var st := _state(key, d, str(pid), rung, 10)
			var at: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d))
			var root: Node3D = camps._build(at, "tribal", hash([key, "seed"]), key)
			built[key] = root
			var count := 0
			for c in root.get_children():
				if str(c.name).begins_with("Workshop"):
					count += 1
			if rung < Workshop.rung_index():
				if count != 0:
					below_with.append(key)
				continue
			at_storage += 1
			var ws: Node3D = root.get_meta("workshop") if root.has_meta("workshop") else null
			if count != 1 or ws == null:
				bad_shape.append("%s: %d workshops" % [key, count])
				continue
			var benches: Dictionary = ws.get_meta("benches", {})
			var props_ok := true
			for b in ["soft", "hard"]:
				if not benches.has(b):
					props_ok = false
					continue
				var np := ((benches[b] as Node3D).get_meta("props", []) as Array).size()
				var avail := (Workshop.huts(Peoples.get_people(str(pid))).get(b, []) as Array).size()
				if np < mini(3, avail) or np > 5:
					props_ok = false
			if not props_ok or ws.get_node_or_null("Door") == null or ws.get_node_or_null("SoftBench") == null or ws.get_node_or_null("HardBench") == null:
				bad_shape.append("%s: benches/door" % key)
			var fire_d: float = Vector2(ws.position.x, ws.position.z).length()
			if not root.has_meta("canopy") and (fire_d < 5.9 or fire_d > 10.1):
				bad_shape.append("%s: %.1f m from the fire" % [key, fire_d])
			# The kiln.
			var hu := Workshop.huts(Peoples.get_people(str(pid)))
			var want_kiln := not (hu.get("kiln", []) as Array).is_empty()
			var has_kiln := ws.has_meta("kiln")
			if want_kiln != has_kiln:
				kiln_bad.append("%s: kiln %s, huts.kiln %d" % [key, str(has_kiln), (hu.get("kiln", []) as Array).size()])
			elif has_kiln:
				var kiln: Node3D = ws.get_meta("kiln")
				var wind: Vector3 = root.global_basis.inverse() * world.planet.wind_avg[world.planet.cell_at(d)]
				wind.y = 0.0
				var off: Vector3 = kiln.position - ws.position
				off.y = 0.0
				var ang := rad_to_deg(off.angle_to(wind)) if wind.length() > 0.05 else 0.0
				if ang > 30.0 or off.length() < 3.9 or off.length() > 8.1:
					kiln_bad.append("%s: %.1f m, %.0f deg off the wind" % [key, off.length(), ang])
			# The porch sign reads at 40 m: its height in a 480-line frame
			# with the play camera's vertical field.
			var sign: Node3D = ws.get_meta("sign")
			var aabb := _aabb(sign)
			var tall := maxf(aabb.size.y, maxf(aabb.size.x, aabb.size.z))
			var px := tall / (2.0 * 40.0 * tan(deg_to_rad(39.0))) * 480.0
			if px < 12.0 or str(sign.get_meta("what", "")) != str(hu.get("porch_sign", "")):
				sign_bad.append("%s: %.1f m (%.0f px at 40 m)" % [key, tall, px])
			if str(pid) == "marsh":
				ok(str(sign.get_meta("shape", "")) == "press" and str(sign.get_meta("what", "")).find("reed-mat press") >= 0, "a marsh camp's porch sign is the reed-mat press (%s: %s)" % [str(sign.get_meta("shape", "")), str(sign.get_meta("what", ""))])
			if str(pid) == "tundra":
				var fl := sign.get_node_or_null("Flame")
				ok(str(sign.get_meta("shape", "")) == "lamp" and fl != null and (fl as Node3D).visible and str(sign.get_meta("what", "")).find("stone lamp burning") >= 0, "a tundra camp's porch sign is the burning stone lamp, lit by day (%s)" % str(sign.get_meta("what", "")))
			# The triangle budget against this camp's fire circle.
			var hp: Node3D = root.get_meta("hearth_props") if root.has_meta("hearth_props") else null
			var wt := tris(ws) + (tris(ws.get_meta("kiln")) if ws.has_meta("kiln") else 0) + (tris(hp) if hp != null else 0)
			var ct := _circle_tris(root, str(pid), d)
			max_ratio = maxf(max_ratio, float(wt) / maxf(ct, 1.0))
			if wt > 2 * ct:
				budget_bad.append("%s: %d vs circle %d" % [key, wt, ct])
			# The day: idles and seats.
			if rung >= 3:
				_day(root, ws, st, key, idle_bad)
	ok(below_with.is_empty(), "no camp below storage has a workshop (%d below) %s" % [ids.size(), str(below_with)])
	ok(bad_shape.is_empty(), "every camp at or past storage (%d) has exactly one workshop 6-10 m from its fire, a soft and a hard bench with 3-5 props each, and a door %s" % [at_storage, str(bad_shape.slice(0, 6))])
	ok(kiln_bad.is_empty(), "a kiln only where huts.kiln is non-empty, 4-8 m downwind of the hut within 30 deg %s" % str(kiln_bad.slice(0, 6)))
	ok(sign_bad.is_empty(), "every porch sign is its people's and reads at 40 m (12+ px tall in the 480-line frame) %s" % str(sign_bad.slice(0, 6)))
	ok(budget_bad.is_empty(), "every workshop with its props is within 2x the triangles of a fire circle with its seats (worst %.2fx) %s" % [max_ratio, str(budget_bad.slice(0, 6))])
	ok(idle_bad.is_empty(), "the day at every maker's camp: bench idles and sounds only from their own bench, one bench a folk a tick, one folk a seat, crossings within the max, the maker's share, the circle by day only the keeper and the children, everyone back at dusk %s" % str(idle_bad.slice(0, 8)))
	_player(built)
	_lamps(built)
	for key in built:
		(built[key] as Node).queue_free()
	await process_frame


func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.get_children():
		if c is MeshInstance3D:
			var a: AABB = (c as MeshInstance3D).get_aabb()
			a = (c as MeshInstance3D).transform * a
			box = a if first else box.merge(a)
			first = false
	return box


## A §CY fire circle with its seats for this camp's folk (and its fire),
## laid in a scratch node: its triangles.
func _circle_tris(root: Node3D, pid: String, d: Vector3) -> int:
	var tmp := Node3D.new()
	root.add_child(tmp)
	var body := PropCollision.body(tmp)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n := mini((root.get_meta("sitters", []) as Array).size(), 8)
	FireCircle.lay_seats(tmp, maxi(n, 3), rng, {"biome": FireStore.biome_key(world, d), "people": pid, "site": "ruin",
		"bark": Color(0.36, 0.25, 0.16), "stones": RuinBuilder.STONES, "ground": Color(0.35, 0.42, 0.22), "cloth": Color(0.45, 0.3, 0.2)}, body)
	var t := tris(tmp) + tris(root.get_meta("fire"))
	tmp.free()
	return t


## A game day at a camp with a maker: the plan at 0.02 h steps, the folk
## driven to it at once, a few frames of their work at each step.
func _day(root: Node3D, ws: Node3D, st: Dictionary, key: String, bad: Array) -> void:
	var holders: Array = []
	for s in root.get_meta("sitters", []):
		if (s as Node3D).has_meta("home"):
			holders.append(s)
	var people := Peoples.get_people(str(st.people))
	var mb := Workshop.maker_bench(people)
	var gh: Array = (CampSim.SIM.get("loop", {}) as Dictionary).get("gather_hours", [7, 17])
	var keeper := Workshop.keeper_of(st)
	var maker := -1
	for i in (st.folk as Array).size():
		if str(st.folk[i].role) == "maker":
			maker = i
	var at_bench := 0
	var samples := 0
	var last := {}
	var crosses := {}
	var day := 40
	var h := 0.0
	var t := 1000.0
	var pp: Vector3 = main.player.global_position
	while h < 24.0:
		var plan := Workshop.plan(st, h, day)
		var gather := h >= float(gh[0]) and h < float(gh[1])
		if gather and maker >= 0:
			samples += 1
			if str(plan[maker]) == mb:
				at_bench += 1
		for i in plan.size():
			var p := str(plan[i])
			if p in ["soft", "hard"]:
				if last.has(i) and str(last[i]) in ["soft", "hard"] and str(last[i]) != p:
					crosses[i] = int(crosses.get(i, 0)) + 1
				last[i] = p
		# Drive the drawn folk there and let them work a moment.
		if int(h * 50.0) % 25 == 0:
			for f in 3:
				t += 0.4
				Workshop.drive(holders, ws, plan, 0.4, t, pp, true)
			var seat_of := {}
			for hv in holders:
				var hd: Node3D = hv
				var stn := str(hd.get_meta("station", "fire"))
				var i := int(hd.get_meta("folk_i", -1))
				if stn in ["soft", "hard"]:
					var idle := str(hd.get_meta("bench_idle", ""))
					if not Workshop.bench_idles(stn).has(idle):
						bad.append("%s %s at %s plays %s" % [key, hd.name, stn, idle])
					if not Workshop.bench_sounds(stn).has(str(Workshop.SOUND_OF.get(idle, ""))):
						bad.append("%s %s: %s sounds %s" % [key, hd.name, idle, str(Workshop.SOUND_OF.get(idle, ""))])
				var sk := str(hd.get_meta("seat_key", ""))
				if stn in ["soft", "hard", "porch"]:
					if seat_of.has(sk):
						bad.append("%s seat %s held twice at %.2f h" % [key, sk, h])
					seat_of[sk] = hd
				var planned := str(plan[i]) if i >= 0 and i < plan.size() else "fire"
				if stn != planned:
					bad.append("%s %s at %s, the plan says %s (%.2f h)" % [key, hd.name, stn, planned, h])
				if gather and stn == "fire" and i != keeper and (i < 0 or CampSim.stage_of(st.folk[i]) != "child"):
					bad.append("%s %s (folk %d) at the fire in the gather hours (%.2f h)" % [key, hd.name, i, h])
				if not gather and stn != "fire":
					bad.append("%s %s not back at the fire at %.2f h" % [key, hd.name, h])
		h += 0.02
	for i in crosses:
		if int(crosses[i]) > int(Workshop.W.get("cross_bench_per_day_max", 1)):
			bad.append("%s folk %d crossed %d times" % [key, i, int(crosses[i])])
	var share := float(at_bench) / maxf(samples, 1.0)
	if absf(share - float(Workshop.W.get("maker_bench_share", 0.8))) > 0.1:
		bad.append("%s maker share %.2f" % [key, share])
	print("  %s: maker at the %s bench %.2f of the gather hours; crossings %s" % [key, mb, share, str(crosses)])


## The player's materials go to the bench that works them.
func _player(built: Dictionary) -> void:
	var ws: Node3D = null
	var st := {}
	for key in built:
		if (built[key] as Node3D).has_meta("workshop"):
			ws = (built[key] as Node3D).get_meta("workshop")
			st = main.camp_sim.state_of(str(key))
			break
	if ws == null:
		ok(false, "a workshop to bring materials to")
		return
	var reeds := Inventory.make("fuel", {"fuel": "reeds", "title": "Reeds"})
	var branch := Inventory.make("fuel", {"fuel": "branch", "title": "Branch"})
	var bone := Inventory.make("plant_sample", {"material": "bone"})
	var m_reeds := Workshop.material_of(reeds)
	var m_branch := Workshop.material_of(branch)
	ok(Workshop.bench_for(m_reeds) == "soft" and Workshop.bench_for(m_branch) == "hard" and Workshop.bench_for(Workshop.material_of(bone)) == "hard", "reeds (%s) go to the soft bench, a branch (%s) and bone to the hard bench" % [m_reeds, m_branch])
	var soft: Node3D = (ws.get_meta("benches") as Dictionary).soft
	var hard: Node3D = (ws.get_meta("benches") as Dictionary).hard
	var before := int(soft.get_meta("tris", 0))
	var hard_before := ((hard.get_meta("laid", []) as Array)).size()
	Workshop.lay(soft, m_reeds, st)
	var laid: Array = soft.get_meta("laid", [])
	ok(laid.size() == 1 and int(soft.get_meta("tris", 0)) > before and (hard.get_meta("laid", []) as Array).size() == hard_before and ((st.get("bench_laid", {}) as Dictionary).get("soft", []) as Array).size() == 1,
		"laid on the soft bench, the reeds join its pieces (%d -> %d triangles) and the camp remembers them; the hard bench is untouched" % [before, int(soft.get_meta("tris", 0))])


## The hearth's lamps: dark by day, lit at night.
func _lamps(built: Dictionary) -> void:
	var tested := 0
	var bad: Array = []
	for key in built:
		var root: Node3D = built[key]
		if not root.has_meta("hearth_props"):
			continue
		var hp: Node3D = root.get_meta("hearth_props")
		var lamps: Array = hp.get_meta("lamps", [])
		if lamps.is_empty():
			continue
		tested += 1
		Workshop.tick(root.get_meta("workshop"), hp, false, false)
		for l in lamps:
			if (l as Node3D).visible:
				bad.append(str(key) + " lit by day")
		Workshop.tick(root.get_meta("workshop"), hp, true, false)
		for l in lamps:
			if not (l as Node3D).visible:
				bad.append(str(key) + " dark at night")
	ok(tested > 0 and bad.is_empty(), "the hearth lamps are dark by day and lit at night (%d camps with a lamp) %s" % [tested, str(bad.slice(0, 4))])


func _opening_at_storage() -> void:
	var st: Dictionary = main.camp_sim.state_of("opening")
	st.rung = Workshop.rung_index()
	main.camp.ensure_workshop(true)
	var ws: Node3D = main.camp.workshop
	ok(ws != null and is_instance_valid(ws) and ws.get_node_or_null("SoftBench") != null and ws.get_node_or_null("HardBench") != null, "the opening camp at storage builds its workshop (%s, %s)" % [str(main.camp.people_id), str((ws.get_meta("look", {}) as Dictionary).get("style", "")) if ws != null else "none"])
	await process_frame
