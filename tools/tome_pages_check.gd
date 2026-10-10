extends SceneTree
## Tomes as collected pages (design 9 Oct §FM.5; queue 73; Tomes,
## TomePages, TomePanel.open_held; data/tomes.json fragments and find,
## data/descent.json floors.base_layer), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/tome_pages_check.gd
## PAGE_SEEDS (env) sets how many layouts the hearts are checked over
## (default 60, drawn from a fixed seed with 1, 7 and 42 first).
## Asserts:
##  1. the data: the I Ching split into fragments (ids unique, each a page
##     range in order, together its 64 pages once each), the Tao with none;
##  2. the draw (2,000 dungeons of three hearts, by find's own rule): about
##     find.share_of_hearts of the hearts hold a fragment; every one a
##     fragment of a split tome, never a whole tome; never two of the same in
##     one dungeon; the same dungeon, the same pages; all four fragments
##     somewhere, different ones in different dungeons;
##  3. the layouts (PAGE_SEEDS seeds): the hearts on the last floor (floor
##     two) and never floor one, one per way of it, each its way's deepest
##     room; with floors.count 1, on floor one, the last, the heart among
##     them;
##  4. the title page's count (TomePanel.open_held), with zero, some and
##     all fragments: as the data stands (no text in), the title page only
##     ("pages 1 to 15 of 64"); with a 12-page test text split as the prompt's
##     example (1-5, 6-9, 10-12): "none of its 12 pages", "pages 1 to 5 of
##     12" and its five pages and no others, "pages 1 to 5 and 10 to 12 of
##     12" (page 5 then 10), "pages 1 to 12 of 12" (all twelve); with a
##     64-page test text the I Ching's own four; ids of other tomes passed
##     over; up / down between two books held;
##  5. a tome with no fragments list behaves as before: the Tao not split
##     and never laid in the crawler; Tomes.heart_tome as before (none as the
##     data stands, the whole I Ching at about 15 % of 200 delve hearts with
##     its text in, the Tao never: its found_at); the panel's open() as
##     before (the title page "3 pages", turned three pages and no more) and
##     open_held refusing it;
##  6. in the game (SEED, every heart holding pages: share_of_hearts 1 for
##     the scene): the pages due lie at the base layer's hearts, one in each
##     heart room, on floor two's floor, none on floor one, none twice; a
##     scroll in the tomb's matte material, no light, no collision; R with
##     none held opens nothing; out of reach the button takes nothing; in
##     reach it takes them: held, in the save (and its written copy), gone
##     from the floor, the log's line, the bundle not asked; R reads them
##     (the title page only, its count right; you don't walk while it's open;
##     Esc closes);
##  7. up the stair to the surface (out of the dungeon) R reads them; back
##     down, the pages taken don't lie again, the rest still do;
##  8. the scene closed and Continue: the same dungeon, the pages taken not
##     lying again, held, R reads them;
##  9. walked out (the stand-in, worlds.json surface.on off) into the
##     game's next dungeon: none of what lies there is held, it lies on its
##     own last floor, R still reads what you hold, and taking more adds to
##     the count ("pages 1 to 15 and 31 to 47 of 64").

var fails := 0
const TEST_12 := "user://tome_pages_test_12.txt"
const TEST_64 := "user://tome_pages_test_64.txt"
const TEST_3 := "user://tome_pages_test_3.txt"
## Layouts beyond 1, 7 and 42 (env PAGE_SEEDS overrides the total).
const LAYOUTS := 60


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	WorldSave.read_only = true
	Bow.need_capture = false
	Residents.stay_asleep = true
	Tomes.override = {}
	_data()
	_draw()
	_layouts()
	await _title_page()
	_as_before()
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	await _game(seed_v)
	Tomes.override = {}
	for f in [TEST_12, TEST_64, TEST_3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


# --- 1. The data ------------------------------------------------------------------

func _data() -> void:
	var fr := Tomes.fragments_of("iching")
	var ids := {}
	var pages := {}
	var in_order := true
	for f in fr:
		ids[str(f.id)] = true
		if int(f.pages[0]) > int(f.pages[1]) or int(f.pages[0]) < 1:
			in_order = false
		for p in range(int(f.pages[0]), int(f.pages[1]) + 1):
			pages[p] = int(pages.get(p, 0)) + 1
	var once := pages.size() == 64
	for p in range(1, 65):
		if int(pages.get(p, 0)) != 1:
			once = false
	print("   iching: %s" % str(fr.map(func(f): return "%s %d-%d" % [f.id, f.pages[0], f.pages[1]])))
	ok(Tomes.split("iching") and fr.size() == 4 and ids.size() == fr.size() and in_order, "the I Ching is split into fragments (tomes.json fragments): %d, each an id and a page range in order, ids unique" % fr.size())
	ok(once and Tomes.total_pages("iching") == 64, "together its 64 pages, each once (one hexagram a page); with no text in, 'of %d' from the fragments" % Tomes.total_pages("iching"))
	ok(not Tomes.split("tao") and Tomes.fragments_of("tao").is_empty(), "the Tao has no fragments list (found whole, as before)")
	var all_ok := true
	for t in Tomes.entries():
		for f in Tomes.fragments_of(str(t.id)):
			if Tomes.fragment(str(f.id)).get("tome", "") != str(t.id):
				all_ok = false
	ok(all_ok, "every fragment is found by its id, with its tome (Tomes.fragment)")


# --- 2. The draw --------------------------------------------------------------------

func _draw() -> void:
	var share := float((Tomes.D.get("find", {}) as Dictionary).get("share_of_hearts", 0.15))
	var hearts := 0
	var holding := 0
	var twice := 0
	var whole := 0
	var unstable := 0
	var where := {}
	var known := {}
	for t in Tomes.entries():
		for f in Tomes.fragments_of(str(t.id)):
			known[str(f.id)] = true
	for s in 2000:
		var d := Tomes.layer_fragments(s + 1, 3)
		var seen := {}
		for fid in d:
			hearts += 1
			if str(fid) == "":
				continue
			holding += 1
			if seen.has(fid):
				twice += 1
			seen[fid] = true
			if not known.has(str(fid)):
				whole += 1
			where[fid] = int(where.get(fid, 0)) + 1
		if Tomes.layer_fragments(s + 1, 3) != d:
			unstable += 1
	var got := float(holding) / float(hearts)
	print("   %d of %d hearts hold pages (%.1f %%); by fragment: %s" % [holding, hearts, got * 100.0, str(where)])
	ok(absf(got - share) <= 0.03, "by find's own rule: %.1f %% of 6,000 base-layer hearts hold pages (find.share_of_hearts %.0f %%)" % [got * 100.0, share * 100.0])
	ok(whole == 0, "every one a fragment of a split tome, never a whole tome (%d not)" % whole)
	ok(twice == 0, "never the same fragment twice in one dungeon (%d)" % twice)
	ok(unstable == 0, "seeded on the dungeon and the heart: the same dungeon, the same pages (%d differ)" % unstable)
	ok(where.size() == known.size(), "all %d fragments lie somewhere, different ones in different dungeons (%d seen)" % [known.size(), where.size()])
	# find.at is the rule's switch, as at the delves.
	var find: Dictionary = Tomes.D.get("find", {})
	var was := str(find.get("at", "delve_heart"))
	find["at"] = "nowhere"
	var none := true
	for s in 200:
		for fid in Tomes.layer_fragments(s + 1, 3):
			if str(fid) != "":
				none = false
	find["at"] = was
	ok(none, "with find.at anything but delve_heart no pages lie (the rule's own switch)")


# --- 3. The layouts -----------------------------------------------------------------

func _seeds() -> Array:
	var n := LAYOUTS
	if OS.get_environment("PAGE_SEEDS").is_valid_int():
		n = maxi(int(OS.get_environment("PAGE_SEEDS")), 3)
	var out: Array = [1, 7, 42]
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	while out.size() < n:
		var s := rng.randi_range(1, 999999)
		if not out.has(s):
			out.append(s)
	return out


func _layouts() -> void:
	var t0 := Time.get_ticks_msec()
	var seeds := _seeds()
	var last_ok := true
	var per_way := true
	var deepest := true
	var counts := {}
	var one_floor_ok := true
	var with_pages := 0
	var pages_laid := 0
	for s in seeds:
		var lay := TombKit.layout(int(s))
		var due := TomePages.plan(lay, [])
		if not due.is_empty():
			with_pages += 1
		pages_laid += due.size()
		if int(s) == 7 or int(s) == 1 or int(s) == 42:
			print("   tomb %d: hearts %s, pages due (as the data stands) %s" % [s, str(TomePages.hearts_of(lay)), str(due)])
		var base := TomePages.base_floor(lay)
		var hearts := TomePages.hearts_of(lay)
		var fl: Array = lay.get("floors", [])
		var ways: Array = (fl[fl.size() - 1] as Dictionary).get("branches", []) if fl.size() > 1 else lay.branches
		counts[hearts.size()] = int(counts.get(hearts.size(), 0)) + 1
		if base != fl.size() - 1 or base != 1:
			last_ok = false
		for h in hearts:
			var pc: Dictionary = lay.pieces[int(h)]
			if int(pc.get("floor", 0)) != base or str(pc.kind) != "room":
				last_ok = false
		if hearts.size() != ways.size() or hearts.is_empty():
			per_way = false
		for w in ways:
			var dmax := -1
			for id in w:
				var pc: Dictionary = lay.pieces[int(id)]
				if str(pc.kind) == "room":
					dmax = maxi(dmax, int(pc.get("depth", 0)))
			var found := false
			for h in hearts:
				if (w as Array).has(int(h)) and int((lay.pieces[int(h)] as Dictionary).get("depth", 0)) == dmax:
					found = true
			if not found:
				deepest = false
		for d in TomePages.plan(lay, []):
			if TombFloors.floor_of(lay, int(d.room)) != 1:
				last_ok = false
	ok(last_ok, "over %d layouts every heart is a room on the last floor (floor two, descent.json floors.base_layer last_floor), never floor one" % seeds.size())
	ok(per_way, "one heart for each of floor two's ways (hearts a tomb: %s)" % str(counts))
	ok(deepest, "each the deepest room of its way (the room at its far end, as a delve's heart)")
	ok(with_pages > 0 and with_pages < seeds.size(), "as the data stands (share_of_hearts %.2f) %d of %d tombs have pages on floor two (%d in all): rare finds, never everywhere" % [float((Tomes.D.get("find", {}) as Dictionary).get("share_of_hearts", 0.15)), with_pages, seeds.size(), pages_laid])
	# A dungeon of one floor: its last floor is floor one.
	var was: Variant = TombFloors.FLOORS.get("count", 2)
	TombFloors.FLOORS["count"] = 1
	for s in seeds.slice(0, 10):
		var lay := TombKit.layout(int(s))
		var hearts := TomePages.hearts_of(lay)
		if TomePages.base_floor(lay) != 0 or hearts.is_empty() or not hearts.has(int(lay.heart)):
			one_floor_ok = false
		for h in hearts:
			if int((lay.pieces[int(h)] as Dictionary).get("floor", 0)) != 0:
				one_floor_ok = false
	TombFloors.FLOORS["count"] = was
	ok(one_floor_ok, "with floors.count 1 the last floor is floor one: the hearts there, the tomb's heart among them (10 layouts)")
	print("   (layouts in %d ms)" % (Time.get_ticks_msec() - t0))


# --- 4. The title page's count ------------------------------------------------------

func _write(path: String, title: String, n: int) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	var s := title + "\n"
	for i in n:
		s += "---\n%d. Page %d\nThe text of page %d.\n" % [i + 1, i + 1, i + 1]
	f.store_string(s)
	f.close()


func _title_page() -> void:
	var panel := TomePanel.new()
	get_root().add_child(panel)
	await process_frame
	# As the data stands: no text in.
	Tomes.override = {}
	ok(not Tomes.ready("iching"), "as the data stands the I Ching's text isn't in (filled false)")
	var opened := panel.open_held("iching", ["iching_1"])
	var s := panel.shown()
	ok(opened and panel.held_mode and str(s[0]) == "The Book of Changes" and str(s[1]) == "pages 1 to 15 of 64", "a fragment of a tome whose text isn't in opens at its title page: \"%s\" / \"%s\"" % [s[0], s[1]])
	panel.turn(1)
	ok(panel.page == 0 and panel.page_count() == 0, "and its title page only: no page to turn to (%d)" % panel.page_count())
	ok(panel.open_held("iching", ["iching_1", "iching_2", "iching_3", "iching_4"]) and str(panel.shown()[1]) == "pages 1 to 64 of 64" and panel.page_count() == 0, "all four held, no text: \"%s\", still the title page only" % str(panel.shown()[1]))
	# The prompt's own example: a 12-page book in three fragments.
	_write(TEST_12, "The Test Book", 12)
	Tomes.override = {"iching": {"text_file": TEST_12, "filled": true, "fragments": [{"id": "a", "pages": [1, 5]}, {"id": "b", "pages": [6, 9]}, {"id": "c", "pages": [10, 12]}]}}
	ok(panel.open_held("iching", [], true) and str(panel.shown()[1]) == "none of its 12 pages" and panel.page_count() == 0, "zero fragments: \"%s\", nothing to turn to" % str(panel.shown()[1]))
	ok(not panel.open_held("iching", []), "(and R never opens a book you hold none of)")
	ok(panel.open_held("iching", ["a"]) and str(panel.shown()[0]) == "The Test Book" and str(panel.shown()[1]) == "pages 1 to 5 of 12", "some: fragment 1-5 held, the title page says \"%s\"" % str(panel.shown()[1]))
	var heads: Array = []
	for i in 6:
		panel.turn(1)
		heads.append(str(panel.shown()[0]))
	ok(panel.page_count() == 5 and heads == ["1. Page 1", "2. Page 2", "3. Page 3", "4. Page 4", "5. Page 5", "5. Page 5"] and panel.foot().contains("page 5 of 12"), "its five pages and no others, in order (%s; foot \"%s\")" % [str(heads), panel.foot()])
	ok(panel.open_held("iching", ["a", "c"]) and str(panel.shown()[1]) == "pages 1 to 5 and 10 to 12 of 12" and panel.page_count() == 8, "two apart: \"%s\", %d pages" % [str(panel.shown()[1]), panel.page_count()])
	for i in 6:
		panel.turn(1)
	ok(str(panel.shown()[0]) == "10. Page 10" and panel.book_page() == 10, "after page 5 comes page 10 (\"%s\")" % str(panel.shown()[0]))
	ok(panel.open_held("iching", ["a", "b"]) and str(panel.shown()[1]) == "pages 1 to 9 of 12", "two that meet: \"%s\"" % str(panel.shown()[1]))
	ok(panel.open_held("iching", ["c", "a", "b"]) and str(panel.shown()[1]) == "pages 1 to 12 of 12" and panel.page_count() == 12, "all: \"%s\", all %d pages" % [str(panel.shown()[1]), panel.page_count()])
	ok(Tomes.held_line("iching", ["a", "iching_3", "tao"]) == "pages 1 to 5 of 12", "ids of other tomes (or none) are passed over")
	Tomes.override = {"iching": {"text_file": TEST_12, "filled": true, "fragments": [{"id": "p7", "pages": [7, 7]}]}}
	ok(Tomes.held_line("iching", ["p7"]) == "page 7 of 12", "one page: \"%s\"" % Tomes.held_line("iching", ["p7"]))
	# The I Ching's own four, with a 64-page text.
	_write(TEST_64, "The Book of Changes", 64)
	Tomes.override = {"iching": {"text_file": TEST_64, "filled": true}}
	var lines: Array = []
	for held in [[], ["iching_1"], ["iching_1", "iching_3"], ["iching_1", "iching_2", "iching_3", "iching_4"]]:
		panel.open_held("iching", held, true)
		lines.append("%s (%d)" % [str(panel.shown()[1]), panel.page_count()])
	print("   the I Ching, its text in: %s" % str(lines))
	ok(lines == ["none of its 64 pages (0)", "pages 1 to 15 of 64 (15)", "pages 1 to 15 and 31 to 47 of 64 (32)", "pages 1 to 64 of 64 (64)"], "the I Ching with its text in: zero, one, two and all four fragments counted right, and only their pages to read")
	# Two books held: up / down between them.
	_write(TEST_3, "The Book of the Way", 3)
	Tomes.override = {"iching": {"text_file": TEST_64, "filled": true}, "tao": {"text_file": TEST_3, "filled": true, "fragments": [{"id": "tao_1", "pages": [1, 2]}]}}
	panel.open_held("iching", ["iching_2", "tao_1"])
	var first := str(panel.shown()[0])
	panel.next_book(1)
	var second := "%s / %s" % [str(panel.shown()[0]), str(panel.shown()[1])]
	panel.next_book(1)
	ok(first == "The Book of Changes" and second == "The Book of the Way / pages 1 to 2 of 3" and str(panel.shown()[0]) == "The Book of Changes" and panel.foot().contains("↑ ↓"), "two books held: down goes to the other's title page (\"%s\") and round again" % second)
	Tomes.override = {}
	panel.queue_free()
	await process_frame


# --- 5. A tome with no fragments list -------------------------------------------------

func _as_before() -> void:
	Tomes.override = {}
	var none := 0
	for s in 200:
		if Tomes.heart_tome(hash([s, "delve"])) != "":
			none += 1
	ok(none == 0, "as the data stands no tome lies at any of 200 delve hearts, as before (%d)" % none)
	Tomes.override = {"iching": {"text_file": TEST_64, "filled": true}, "tao": {"text_file": TEST_3, "filled": true}}
	var iching := 0
	var tao := 0
	for s in 200:
		var t := Tomes.heart_tome(hash([s, "delve"]))
		if t == "iching":
			iching += 1
		elif t == "tao":
			tao += 1
	ok(absf(iching / 200.0 - 0.15) <= 0.05 and tao == 0, "with the texts in, the open world deals the whole I Ching at %d of 200 delve hearts and the Tao at none (its found_at), as before" % iching)
	var lays := 0
	for s in 500:
		for fid in Tomes.layer_fragments(s + 1, 3):
			if str(Tomes.fragment(str(fid)).get("tome", "")) == "tao" or str(fid) == "tao":
				lays += 1
	ok(lays == 0, "the Tao never lies in the crawler (no fragments list), its text in or not")
	var panel := TomePanel.new()
	get_root().add_child(panel)
	var opened := panel.open("tao")
	var t0 := panel.shown()
	var heads: Array = []
	for k in 4:
		panel.turn(1)
		heads.append(str(panel.shown()[0]))
	ok(opened and not panel.held_mode and str(t0[0]) == "The Book of the Way" and str(t0[1]) == "3 pages" and heads == ["1. Page 1", "2. Page 2", "3. Page 3", "3. Page 3"] and panel.foot().begins_with("The Book of the Way · 3 / 3"), "the panel opens a whole tome as before: \"%s\" / \"%s\", three pages and no more (%s)" % [t0[0], t0[1], panel.foot()])
	ok(not panel.open_held("tao", ["iching_1", "tao"], true), "and open_held refuses a tome found whole")
	panel.free()
	Tomes.override = {}


# --- 6-9. In the game -----------------------------------------------------------------

func _wait_scene(main: CrawlerMain) -> void:
	for i in 10:
		await physics_frame
	while not main.baked:
		await process_frame
	while main.tome_pages == null or not main.tome_pages.placed:
		await physics_frame
	await _frames(2)


func _right_click() -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_RIGHT
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(1)


func _tap(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


## The yaw that faces from `a` to `b` (spawn_flat's: 0 looks down -z).
static func _yaw_to(a: Vector3, b: Vector3) -> float:
	return atan2(-(b.x - a.x), -(b.z - a.z))


## The point on room `pc`'s middle line (its aisle) farthest from `q`, on
## its floor.
static func _far_point(pc: Dictionary, q: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_d := -1.0
	for along: float in [0.8, float(pc.len) * 0.5, float(pc.len) - 0.8]:
		var c2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * along
		var p := Vector3(c2.x, Delves.floor_of(pc, along), c2.y)
		if p.distance_to(q) > best_d:
			best_d = p.distance_to(q)
			best = p
	return best


## Fragment ids of what lies in `main`'s dungeon now.
func _lying(main: CrawlerMain) -> Array:
	var out: Array = []
	for d in main.tome_pages.lying:
		if is_instance_valid(d.node):
			out.append(str(d.fragment))
	out.sort()
	return out


func _game(seed_v: int) -> void:
	var find: Dictionary = Tomes.D.get("find", {})
	var share_was: Variant = find.get("share_of_hearts", 0.15)
	find["share_of_hearts"] = 1.0
	OS.set_environment("SEED", str(seed_v))
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	await _wait_scene(main)
	var lay := main.lay
	var tp := main.tome_pages
	var p := main.player
	p._invulnerable = 1.0e9
	main.boss.auto = false
	var plan := TomePages.plan(lay, [])
	var hearts := TomePages.hearts_of(lay)
	print("== the game: seed %d, hearts %s, pages due %s" % [seed_v, str(hearts), str(plan)])
	ok(TomePages.held().is_empty() and CrawlerSave.place == 0, "a new game holds no pages")
	# 6. What lies, and where.
	var rooms_ok := true
	var floor_ok := true
	var on_floor := true
	var look_ok := true
	var rooms := {}
	var space := p.get_world_3d().direct_space_state
	for d in tp.lying:
		var n: Node3D = d.node
		var q := n.global_position
		if TombKit.piece_at(lay, q + Vector3.UP * 0.1) != int(d.room) or not hearts.has(int(d.room)):
			rooms_ok = false
		rooms[int(d.room)] = true
		if TombFloors.floor_at(lay, q + Vector3.UP * 0.1) != 1:
			floor_ok = false
		var ray := PhysicsRayQueryParameters3D.create(q + Vector3.UP * 0.5, q - Vector3.UP * 0.5)
		ray.collision_mask = PropCollision.WORLD_LAYER
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or absf((hit.position as Vector3).y - q.y) > 0.07:
			on_floor = false
		var mi := n.get_node_or_null("Scroll") as MeshInstance3D
		if mi == null or mi.mesh != TomePages.scroll_mesh() or mi.material_override != RuinBuilder.material_lit() or not n.find_children("*", "Light3D", true, false).is_empty() or not n.find_children("*", "CollisionObject3D", true, false).is_empty():
			look_ok = false
	var due: Array = plan.map(func(d): return str(d.fragment))
	due.sort()
	ok(plan.size() >= 2 and _lying(main) == due and rooms.size() == plan.size(), "the pages due lie at the base layer's hearts, one in each heart room (%s in %d rooms)" % [str(_lying(main)), rooms.size()])
	ok(rooms_ok and floor_ok and on_floor, "each in its heart room on floor two, on its floor (none on floor one)")
	ok(look_ok, "each a scroll in the tomb's matte material, no light and no collision (§FG: nothing points to it)")
	# R with none held: nothing.
	await _tap(KEY_R)
	ok(not main.tome_panel.visible, "R with no pages held opens nothing")
	# Out of reach, then in reach.
	var one: Dictionary = tp.lying[0]
	var fid := str(one.fragment)
	var pc: Dictionary = lay.pieces[int(one.room)]
	var at: Vector3 = one.pos
	var far_at := _far_point(pc, at)
	p.spawn_flat(far_at, _yaw_to(far_at, at), 0.0)
	await _frames(6)
	var torches := p.inventory.count()
	await _right_click()
	var far_d := p.global_position.distance_to(at)
	ok(far_d > TomePages.reach_m() and TomePages.held().is_empty() and _lying(main) == due, "out of reach (%.1f m off, reach %.1f m) the button takes nothing" % [far_d, TomePages.reach_m()])
	var mid2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * 0.5
	var to_mid := Vector3(mid2.x - at.x, 0.0, mid2.y - at.z)
	var near_at := at + to_mid.normalized() * 0.9
	p.spawn_flat(near_at, _yaw_to(near_at, at), -0.6)
	await _frames(6)
	var log0 := GameLog.entries.size()
	await _right_click()
	await _frames(2)
	var saved_text := str(CrawlerSave.memory.get(CrawlerSave.path_of(CrawlerSave.game_seed), ""))
	var saved: Variant = JSON.parse_string(saved_text) if saved_text != "" else null
	var in_file := saved is Dictionary and ((saved as Dictionary).get("tome_pages", []) as Array).has(fid)
	var last: Dictionary = GameLog.entries[-1] if GameLog.entries.size() > log0 else {}
	ok(TomePages.held() == [fid] and in_file, "in reach the button takes them: %s held, kept in the game's save and its written copy" % fid)
	ok(not _lying(main).has(fid) and not is_instance_valid(one.node) and _lying(main).size() == due.size() - 1, "gone from the floor, the rest still lying (%s)" % str(_lying(main)))
	ok(str(last.get("text", "")) == TomePages.log_line(fid) and str(last.get("kind", "")) == "tome", "the log says \"%s\"" % str(last.get("text", "")))
	ok(p.inventory.count() == torches and tp.taken == 1, "nothing else answered the button (the pack as it was, the bundle not asked)")
	# R reads them.
	await _tap(KEY_R)
	var tpn := main.tome_panel
	var sh := tpn.shown()
	ok(tpn.visible and tpn.held_mode and str(sh[0]) == "The Book of Changes" and str(sh[1]) == Tomes.held_line("iching", [fid]) and tpn.page_count() == 0, "R reads what you hold: \"%s\" / \"%s\", the title page only (no text in yet)" % [sh[0], sh[1]])
	await _frames(3)
	ok(p.typing and p.ui_open and (main.reticle == null or not main.reticle.shown), "while it's open you don't walk and the crosshair hides")
	await _tap(KEY_ESCAPE)
	ok(not tpn.visible, "Esc closes it")
	# 7. Up to the surface and back down.
	await main.walk_out()
	await _frames(5)
	var up := main.on_surface
	await _tap(KEY_R)
	ok(up and tpn.visible and str(tpn.shown()[1]) == Tomes.held_line("iching", [fid]), "up on the surface, out of the dungeon, R reads them (\"%s\")" % str(tpn.shown()[1]))
	await _tap(KEY_R)
	await main.go_down()
	await _frames(5)
	var expect := due.duplicate()
	expect.erase(fid)
	ok(not main.on_surface and main.tome_pages == tp and _lying(main) == expect, "back down the same dungeon: the pages taken don't lie again, the rest still do (%s)" % str(_lying(main)))
	# 8. Closed, then Continue.
	main.queue_free()
	await process_frame
	await process_frame
	OS.set_environment("SEED", "")
	main = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	await _wait_scene(main)
	main.player._invulnerable = 1.0e9
	main.boss.auto = false
	ok(CrawlerSave.continued and CrawlerSave.place == 0 and main.seed_value == seed_v and TomePages.held() == [fid], "Continue: the same game and dungeon (tomb %d), %s still held" % [main.seed_value, fid])
	ok(_lying(main) == expect, "the pages taken don't lie again; the rest are where they were (%s)" % str(_lying(main)))
	await _tap(KEY_R)
	ok(main.tome_panel.visible and str(main.tome_panel.shown()[1]) == Tomes.held_line("iching", [fid]), "and R reads them (\"%s\")" % str(main.tome_panel.shown()[1]))
	await _tap(KEY_ESCAPE)
	# 9. Walked out into the game's next dungeon (the stand-in).
	Surface.S["on"] = false
	await main.walk_out()
	while main.leaving:
		await process_frame
	while main.tome_pages == null or not main.tome_pages.placed:
		await physics_frame
	await _frames(3)
	var lay2 := main.lay
	var next_ok := true
	for d in main.tome_pages.lying:
		if TombFloors.floor_at(lay2, (d.pos as Vector3) + Vector3.UP * 0.1) != TomePages.base_floor(lay2) or TomePages.held().has(str(d.fragment)):
			next_ok = false
	var plan2 := TomePages.plan(lay2, [])
	var held_there := plan2.any(func(d): return str(d.fragment) == fid)
	print("   place 1 (tomb %d): due %s, lying %s" % [main.seed_value, str(plan2), str(_lying(main))])
	ok(CrawlerSave.place == 1 and next_ok and not _lying(main).has(fid), "the next dungeon (tomb %d): what lies there lies on its last floor, and none of it is held (%s%s)" % [main.seed_value, str(_lying(main)), ", the one you hold due there and not laid" if held_there else ""])
	await _tap(KEY_R)
	ok(main.tome_panel.visible and str(main.tome_panel.shown()[1]) == Tomes.held_line("iching", [fid]), "R still reads what you hold (\"%s\")" % str(main.tome_panel.shown()[1]))
	await _tap(KEY_ESCAPE)
	if not main.tome_pages.lying.is_empty():
		var two: Dictionary = main.tome_pages.lying[0]
		var fid2 := str(two.fragment)
		var pc2: Dictionary = lay2.pieces[int(two.room)]
		var m2: Vector2 = (pc2.c as Vector2) + (pc2.dir as Vector2) * float(pc2.len) * 0.5
		var a2: Vector3 = two.pos
		var tm2 := Vector3(m2.x - a2.x, 0.0, m2.y - a2.z).normalized()
		main.player.spawn_flat(a2 + tm2 * 0.9, _yaw_to(a2 + tm2 * 0.9, a2), -0.6)
		await _frames(6)
		await _right_click()
		await _frames(2)
		var both := [fid, fid2]
		await _tap(KEY_R)
		var line := str(main.tome_panel.shown()[1])
		ok(TomePages.held().size() == 2 and TomePages.held().has(fid2) and line == Tomes.held_line("iching", both) and line != Tomes.held_line("iching", [fid]), "taking more there adds to the count: \"%s\"" % line)
		await _tap(KEY_ESCAPE)
	else:
		ok(false, "pages lie in the next dungeon too (every heart holding pages for the scene)")
	Surface.S["on"] = true
	find["share_of_hearts"] = share_was
	main.queue_free()
	await process_frame
	await process_frame
