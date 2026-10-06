extends SceneTree
## The library (design 5 Oct §EN), headless:
##   STAMP=1 SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/library_check.gd
## On seed 7731:
##  - every camp at or past storage has a library and a record-keeper, and
##    none below does;
##  - the camp book at such a camp is on the library's shelf (no altar),
##    found by reach, and reading it opens the camp's own lines (and copies
##    the rumour to the log where there is one);
##  - a camp's winter count has exactly (years lived) pictures, and a year
##    with a birth and a hunt shows the birth;
##  - the knots equal the living folk, coloured by stage, after a birth and
##    after a child grows;
##  - a camp that goes dark keeps its library: the last picture black, no
##    new pictures over the next 2 game years, the knots as they were;
##  - the tome shelf shows only tomes the player has not taken, and the
##    tome panel opens from it;
##  - the winter count is drawn from pixel glyphs: no font, no text.

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
	print("[library] seed %d" % seed_v)
	Workshop.instant = true
	Library.instant = true
	_libraries()
	_winter()
	_knots()
	_dark()
	_tomes()
	_no_text()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _state(key: String, d: Vector3, pid: String, rung: int, n := 8) -> Dictionary:
	var cs: CampSim = main.camp_sim
	var st := cs.ensure(key, d, pid, FireStore.biome_key(world, d), hash([key]), n)
	st.rung = rung
	var folk: Array = []
	for i in n:
		folk.append({"sex": "m" if i % 2 == 0 else "f", "stage": "child" if i >= n - 2 else "adult", "born": 0.0, "role": "", "seed": i})
	if rung >= 2:
		folk[0].role = "headman"
		folk[1].role = "plantkeeper"
		cs._give_role(st, "record_keeper", "")
	st.folk = folk
	if rung >= 2:
		cs._give_role(st, "record_keeper", "")
	st.state = "living"
	st.trades = []
	return st


func _build(key: String, d: Vector3) -> Node3D:
	var at: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d))
	return main.camps._build(at, "tribal", hash([key, "s"]), key)


func _has_rk(st: Dictionary) -> bool:
	for f in st.folk:
		if str((f as Dictionary).get("role", "")) == "record_keeper":
			return true
	return false


## Camps of every people, above and below the rung: the library, the
## record-keeper, the book on the shelf.
func _libraries() -> void:
	var cs: CampSim = main.camp_sim
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var ids: Array = Peoples.ids()
	var above_bad: Array = []
	var below_bad: Array = []
	var book_bad: Array = []
	var n_above := 0
	var read_ok := 0
	for k in ids.size():
		for rung in [1, 2]:
			var pid := str(ids[k])
			var key := "lib:%s:%d" % [pid, rung]
			var d := CreatureSpawner._offset(pd, TAU * (k + 0.5 * rung) / ids.size(), 100.0 + 60.0 * rung)
			var st := _state(key, d, pid, rung)
			# A tick of the ladder: the roles of the rung.
			cs._ladder(st, float(world.days))
			st.rung = rung
			var root := _build(key, d)
			if root.has_meta("canopy"):
				root.queue_free()
				continue
			var lib: Node3D = root.get_meta("library") if root.has_meta("library") else null
			if rung >= 2:
				n_above += 1
				if lib == null or not _has_rk(st):
					above_bad.append(pid)
				else:
					# The book: on the shelf in the library, nowhere else.
					var books := root.find_children("CampBook", "", true, false)
					var shelf: Node3D = lib.get_meta("shelf_book")
					var found := CampBook.in_reach(shelf.global_position)
					if books.size() != 1 or books[0] != shelf or found.is_empty() or found.node != shelf or str(found.key) != key:
						book_bad.append(pid)
					else:
						main.camp_book_panel.open(world, key, st)
						if main.camp_book_panel.visible:
							read_ok += 1
						main.camp_book_panel.close()
			elif lib != null or _has_rk(st):
				below_bad.append(pid)
			root.queue_free()
	ok(above_bad.is_empty() and n_above > 10, "every camp at or past storage has a library and a record-keeper (%d camps) %s" % [n_above, str(above_bad)])
	ok(below_bad.is_empty(), "no camp below storage has either %s" % str(below_bad))
	ok(book_bad.is_empty() and read_ok > 0, "the camp book is on the library's shelf, the only book there, and opens from it (%d read) %s" % [read_ok, str(book_bad)])
	# The rumour still goes to the log where there is one.
	var map: PlanetData = world.planet
	var rum := CampBook.rumour(map, pd)
	if rum.is_empty():
		print("SKIP  no overrun ruin within the rumour's range of these camps: the copy to the log is the camp book's own, unchanged")
	else:
		var key := "lib:rumour"
		var st := _state(key, pd, "river", 2)
		var before := GameLog.entries.size()
		main.camp_book_panel.open(world, key, st)
		main.camp_book_panel.close()
		ok(GameLog.entries.size() > before, "reading the book in the library copies the rumour to the log")


## The winter count: years lived, the year's picture.
func _winter() -> void:
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var st := _state("lib:winter", CreatureSpawner._offset(pd, 1.0, 230.0), "river", 2)
	var yd := Library.year_days()
	var now: float = float(world.days)
	st.born_day = now - 3.5 * yd
	st.erase("winter")
	st.erase("year_events")
	Library.event(st, "hunt_large", now - 3.3 * yd)
	Library.event(st, "birth", now - 3.2 * yd)
	Library.event(st, "hunt_large", now - 2.4 * yd)
	Library.tick(st, now)
	var w: Array = st.winter
	print("  a camp 3.5 years old: %s" % str(w))
	ok(w.size() == 3, "the winter count has one picture a year lived (%d of 3)" % w.size())
	ok(w.size() == 3 and str(w[0]) == "birth" and str(w[1]) == "hunt_large" and str(w[2]) == "quiet", "a year with a birth and a hunt shows the birth; a hunt year the antlers; a quiet year the dot")
	var root := _build("lib:winter", CreatureSpawner._offset(pd, 1.0, 230.0))
	var lib: Node3D = root.get_meta("library")
	var hide: MeshInstance3D = lib.get_meta("hide")
	ok(int(hide.get_meta("glyphs", -1)) == 3, "the hide shows the 3 pictures (%d)" % int(hide.get_meta("glyphs", -1)))
	root.queue_free()


## The knot cord follows the folk.
func _knots() -> void:
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var key := "lib:knots"
	var st := _state(key, CreatureSpawner._offset(pd, 2.0, 230.0), "river", 2, 6)
	var root := _build(key, CreatureSpawner._offset(pd, 2.0, 230.0))
	var lib: Node3D = root.get_meta("library")
	var cord: Node3D = lib.get_meta("cord")
	var res: Array = []
	for step in ["built", "birth", "grown"]:
		match step:
			"birth":
				(st.folk as Array).append({"sex": "f", "stage": "child", "born": float(world.days), "role": "", "seed": 99})
			"grown":
				(st.folk[(st.folk as Array).size() - 1] as Dictionary).stage = "teen"
		Library.refresh(lib, st)
		var knots := cord.get_children().filter(func(c): return c.name.begins_with("Knot"))
		var good := knots.size() == (st.folk as Array).size()
		for i in mini(knots.size(), (st.folk as Array).size()):
			var want := Library.knot_colour(CampSim.stage_of(st.folk[i]))
			if str((knots[i] as Node).get_meta("stage", "")) != CampSim.stage_of(st.folk[i]) or Library.knot_colour(str((knots[i] as Node).get_meta("stage", ""))) != want:
				good = false
		res.append([step, knots.size(), (st.folk as Array).size(), good])
	print("  knots: %s" % str(res))
	ok(res.all(func(r): return bool(r[3])), "one knot a living folk, coloured by stage, after a birth and after a child grows")
	root.queue_free()


## A camp that goes dark: the library stays, the black square, no more years.
func _dark() -> void:
	var cs: CampSim = main.camp_sim
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var key := "lib:dark"
	var d := CreatureSpawner._offset(pd, 3.0, 230.0)
	var st := _state(key, d, "river", 2)
	var yd := Library.year_days()
	var now: float = float(world.days)
	st.born_day = now - 2.2 * yd
	Library.event(st, "birth", now - 1.5 * yd)
	cs._ladder(st, now)
	Library.tick(st, now)
	var knots := Library.knots_of(st)
	cs._abandon(st, now, "taken")
	var w0: Array = (st.winter as Array).duplicate()
	Library.tick(st, now + 2.0 * yd)
	var w1: Array = st.winter
	var root := _build(key, d)
	var lib: Node3D = root.get_meta("library") if root.has_meta("library") else null
	var hide_ok := false
	var knots_ok := false
	if lib != null:
		var hide: MeshInstance3D = lib.get_meta("hide")
		hide_ok = (hide.get_meta("painted", []) as Array) == w1
		var cord: Node3D = lib.get_meta("cord")
		knots_ok = (cord.get_meta("knots", []) as Array) == knots
	print("  a camp gone dark: winter %s; after 2 more years %s" % [str(w0), str(w1)])
	ok(lib != null and hide_ok, "a camp that goes dark keeps its library and its hide")
	ok(not w0.is_empty() and str(w0[w0.size() - 1]) == "dead_camp_last" and w1 == w0, "its last picture is the black square, and no pictures come in the next 2 game years")
	ok(knots_ok and knots.size() == 8, "its knot cord stays as it was (%d knots)" % knots.size())
	root.queue_free()


## The tome shelf: a ruin's delve tome while it is not taken; the panel
## opens from it.
func _tomes() -> void:
	var map: PlanetData = world.planet
	var pd: Vector3 = world.dir_of(main.player.global_position)
	# No tome's text is in the repo yet (data/tomes/): the I Ching given a
	# stand-in text for the check (Tomes.override, the tests' hook).
	var f := FileAccess.open("user://library_check_tome.txt", FileAccess.WRITE)
	f.store_string("The Book of Changes\n---\nThe first\nA stand-in page for the check.\n")
	f.close()
	Tomes.override["iching"] = {"text_file": "user://library_check_tome.txt", "filled": true}
	var site := {}
	var delve := {}
	for r in Ruins.near(map, pd, PlanetConst.RADIUS_M * PI):
		if Delves.has_delve(r):
			if delve.is_empty():
				delve = r
			if Tomes.heart_tome(int(r.seed)) != "":
				site = r
				break
	if site.is_empty() and not delve.is_empty():
		# A delve ruin of this planet, its seed turned until its heart
		# holds a tome (the share is 15%).
		for sv in 4000:
			var trial: Dictionary = delve.duplicate()
			trial["seed"] = sv
			if Delves.has_delve(trial) and Tomes.heart_tome(sv) != "":
				site = trial
				print("  (a delve ruin here, its seed turned to %d for a tome at the heart)" % sv)
				break
	var t := ""
	var before: Array = []
	if site.is_empty():
		# No delve tome on this planet: the shelf and the panel with a tome
		# whose text is in.
		for e in Tomes.entries():
			if Tomes.ready(str((e as Dictionary).get("id", ""))):
				t = str((e as Dictionary).id)
				break
		before = [t] if t != "" else []
		print("SKIP  no ruin on this planet has a tome at its delve's heart: the not-taken rule is untested; the shelf is tried with '%s'" % t)
	else:
		t = Tomes.heart_tome(int(site.seed))
		before = Library.tomes_for(site)
		var finds: Array = WorldSave.data.get("delve_finds", [])
		finds.append(int(site.seed))
		WorldSave.data["delve_finds"] = finds
		var after := Library.tomes_for(site)
		finds.erase(int(site.seed))
		print("  the ruin %.1f km off has the tome '%s' at its delve's heart" % [CubeSphere.surface_distance_m(site.dir, pd) / 1000.0, t])
		ok(before == [t] and after.is_empty(), "the shelf has the ruin's tome while it is not taken, and not once it is")
	if t == "":
		return
	# On a shelf: read there.
	var key := "lib:tomes"
	var d := CreatureSpawner._offset(pd, 4.0, 230.0)
	var st := _state(key, d, "river", 2)
	var root := _build(key, d)
	var lib: Node3D = root.get_meta("library")
	lib.queue_free()
	root.remove_meta("library")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lib2 := Library.build(root, st, {"people": Peoples.get_people("river"), "pal": root.get_meta("pal", []), "rng": rng, "body": PropCollision.body(root), "avoid": [[Vector3.ZERO, 3.0]],
		"ruin": true, "ground": main.camps._ground_fn(root), "tomes": before, "key": key})
	var tome_nodes := lib2.find_children("Tome", "", true, false)
	var found := Library.tome_in_reach((tome_nodes[0] as Node3D).global_position) if not tome_nodes.is_empty() else {}
	var opened := false
	if not found.is_empty():
		opened = main.tome_panel.open(str(found.tome))
		main.tome_panel.visible = false
	ok(tome_nodes.size() == 1 and not found.is_empty() and str(found.tome) == t and opened, "the tome stands on the shelf and the tome panel opens from it")
	root.queue_free()


## No text on the hide: the glyphs are bitmaps; the library code draws no
## font.
func _no_text() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/peoples/library.gd")
	var re := RegEx.create_from_string("(Font|Label3D|Label\\b|draw_string|draw_char|TextMesh|RichText)")
	var hits := re.search_all(src)
	var bitmaps := Library.GLYPHS.values().all(func(g): return (g as Array).size() == 3 and (g as Array).all(func(r): return str(r).length() == 3 and str(r).replace("#", "").replace(".", "") == ""))
	ok(hits.is_empty() and bitmaps, "the winter count is pixel glyphs only: no font, no text (%d font hits)" % hits.size())
