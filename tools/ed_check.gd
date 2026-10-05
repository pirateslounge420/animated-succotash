extends SceneTree
## Design 4 Oct §ED.3, §ED.5, §ED.6, §ED.7 (the camp book, creature rungs,
## guardians, the only two weapons), headless on the dev stamp:
##   STAMP=1 SEED=42 godot --headless --path . --fixed-fps 60 --script tools/ed_check.gd
## (The river camp, §ED.1, is tools/river_camp_check.gd on the full planet;
## the river's phases, §ED.2, tools/river_phases_check.gd.)

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


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 42
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	for i in 20:
		await physics_frame
	_book()
	await _rungs()
	await _guardians()
	_dark()
	await _fire_arrow()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


# --- §ED.3 the camp book ---------------------------------------------------------

func _book() -> void:
	ok(not CampBook.books.is_empty(), "a camp book stands by the opening hearth (%d in the world)" % CampBook.books.size())
	var st: Dictionary = main.camp_sim.state_of("opening")
	ok(not st.is_empty(), "the opening camp has a sim state")
	if st.is_empty():
		return
	var n0 := (st.get("book", []) as Array).size()
	main.camp_sim._note(st, "A child was born at the fire.", world.days - 40.0, "birth")
	main.camp_sim._note(st, "The camp keeps a store now.", world.days, "store_change")
	main.camp_sim._note(st, "One of them has come of age.", world.days, "")
	var book: Array = st.get("book", [])
	ok(book.size() == n0 + 2, "the sim's listed events are written (2 of 3 lines; coming of age is not a book event)")
	var lines := CampBook.lines_of(world, st)
	var old: Dictionary = lines[lines.size() - 2 - (1 if bool(lines[lines.size() - 1].get("rumour", false)) else 0)]
	var fresh := CampBook.ink(0.0)
	var aged := CampBook.ink(40.0)
	ok(fresh.get_luminance() < aged.get_luminance() and aged.r > aged.b, "fresh ink dark, a month-old line browned (%s / %s)" % [fresh.to_html(false), aged.to_html(false)])
	ok(str(old.get("stamp", "")) != "", "each line stamped in game time (%s)" % str(old.get("stamp", "")))
	# The rumour: an overrun ruin within range, worded from its smoke.
	var r := CampBook.rumour(world.planet, world.dir_of(main.camp.fire().global_position))
	print("[book] rumour here: %s" % (str(r.get("text", "none"))))
	main.camp_book_panel.open(world, "opening", st)
	ok(main.camp_book_panel.visible and main.camp_book_panel.page == main.camp_book_panel.page_count() - 1, "the book opens at its newest page")
	if not r.is_empty():
		var copied := false
		for e in GameLog.entries:
			if str(e.get("text", "")) == str(r.text):
				copied = true
		ok(copied, "reading it copies the rumour into the log")
	main.camp_book_panel.close()


# --- §ED.5 rungs -------------------------------------------------------------------

func _rungs() -> void:
	var hare := CreatureSpecies.find("Hare")
	var wolf := Guardians._base_species("Wolf")
	ok(hare != null and wolf != null, "the hare and a wolf to roll (%s)" % (wolf.name if wolf else "none"))
	if hare == null or wolf == null:
		return
	# Over many seeds the chances come out near rungs.json's.
	var rare := 0
	var myth := 0
	for i in 20000:
		var r := Rungs.roll(hare, i)
		if r == "rare":
			rare += 1
		elif r == "mythic":
			myth += 1
	print("[rungs] hare over 20000: %d rare, %d mythic" % [rare, myth])
	ok(rare > 200 and rare < 650 and myth > 10 and myth < 90, "rare about 2%%, mythic about 0.2%% (%d, %d)" % [rare, myth])
	var rv := Rungs.variant(hare, "rare")
	ok(rv.color.to_html(false) == "f2efe6" and rv.size_m == hare.size_m, "a rare hare: the same, only white")
	var jack := Rungs.variant(hare, "mythic")
	ok(jack.name == "Jackalope" and jack.sound == "hare_scream" and absf(jack.speed_mps - hare.speed_mps * 1.3) < 0.01 and absf(jack.shy_m - hare.shy_m * 1.5) < 0.01, "the jackalope: its own name and voice, faster and warier")
	var dire := Rungs.variant(wolf, "mythic")
	ok(dire.name == "Dire wolf" and dire.sound == "dire_howl" and float(dire.pack.get("notice_m", 0)) > float(wolf.pack.get("notice_m", 0)), "the dire wolf: its voice, its notice range raised")
	ok(Rungs.voice_range(dire) > Rungs.sight_m(dire), "a mythic's voice carries past its sight (%.0f m against %.0f m)" % [Rungs.voice_range(dire), Rungs.sight_m(dire)])
	# A real one, built: the antlers on the jackalope.
	Rungs.force = "mythic"
	var cr := Creature.new()
	main.creatures.adopt(cr)
	cr.setup(hare, world, main.chunks, main.creatures, player.surface_dir, 7)
	Rungs.force = ""
	ok(cr.rung == "mythic" and cr.species.name == "Jackalope", "a hare can come up a jackalope (%s)" % cr.species.name)
	var cones := 0
	for n in cr.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).mesh is CylinderMesh:
			cones += 1
	ok(cones >= 6, "with pronged antlers on its head (%d cones)" % cones)
	ok(cr.voice != null and cr.voice.max_distance >= Rungs.voice_range(cr.species) - 1.0, "and a voice heard %.0f m off" % (cr.voice.max_distance if cr.voice else 0.0))
	cr.leave()


# --- §ED.6 guardians ---------------------------------------------------------------

func _guardians() -> void:
	var g: Guardians = main.guardians
	ok(g != null, "Guardians runs")
	var bound := 0
	var sp: CreatureSpecies = null
	for i in 200:
		var s := Guardians.species_for(str(i))
		if s != null:
			bound += 1
			sp = s
	print("[guardians] %d of 200 overrun ruins bound a guardian (share %.2f)" % [bound, float(Guardians.G.get("share", 0.5))])
	ok(bound > 60 and bound < 140 and sp != null and sp.name == "Dire wolf", "about half bind a guardian, the dire wolf")
	if sp == null:
		return
	var ground := CreatureSpawner._offset(player.surface_dir, 0.0, 30.0)
	var cr := g._spawn("test", sp, ground)
	g.standing["test"] = cr
	for i in 30:
		await physics_frame
	ok(cr.rung == "mythic" and not cr.guard.is_empty(), "a guardian holds its ground")
	# A walker: it closes; a runner: it spooks.
	cr.guard["player_speed"] = 1.2
	cr.guard["state"] = "hold"
	var before := cr.distance_to(player.surface_dir)
	for i in 120:
		cr.guard["player_speed"] = 1.2
		await physics_frame
	ok(str(cr.guard.state) == "close" and cr.distance_to(player.surface_dir) < before, "it closes on a slow walker (%.0f m -> %.0f m)" % [before, cr.distance_to(player.surface_dir)])
	for i in 10:
		cr.guard["player_speed"] = 6.0
		await physics_frame
	ok(str(cr.guard.state) == "spooked", "and spooks at a runner (%s)" % str(cr.guard.state))
	# It ignores light: nothing in _guardian looks at fires; the torch lit
	# beside it changes nothing.
	cr.guard["state"] = "hold"
	cr.hurt(30.0, player.global_position)
	ok(not cr.dead and str(cr.guard.state) == "driven", "a spear or an arrow drives it off, never kills it")
	cr.leave()
	g.standing.erase("test")
	# Dusk until dawn it is out hunting; a restored hearth sends it off
	# for good.
	var d0: float = world.days
	var phases := {}
	for h in 24:
		world.days = floor(d0) + h / 24.0
		phases[h] = g.present("x", player.surface_dir)
	world.days = d0
	var day_n := 0
	for h in phases:
		if phases[h]:
			day_n += 1
	ok(day_n > 6 and day_n < 20, "on its ground by day, out from dusk until dawn (%d of 24 hours)" % day_n)
	g._gone("y")
	ok(not g.present("y", player.surface_dir), "gone for good once the hearth is restored")


# --- §ED.7 the only two weapons ------------------------------------------------------

func _dark() -> void:
	var ww := CreatureSpecies.find("Werewolf")
	ok(ww != null and Rungs.of_the_dark(ww), "the werewolf lurks in the dark")
	if ww == null:
		return
	var cr := Creature.new()
	main.creatures.adopt(cr)
	cr.setup(ww, world, main.chunks, main.creatures, player.surface_dir, 3)
	var hp0 := cr.hp
	cr.hurt(500.0, player.global_position)
	ok(cr.hp == hp0 and not cr.dead, "edges never touch it: spear and arrow do nothing (hp %.0f)" % cr.hp)
	cr.leave()
	ok(not Rungs.of_the_dark(Rungs.variant(Guardians._base_species("Wolf"), "mythic")), "a guardian is flesh and blood")
	ok(not player.wears("ranged", "bow") and not player.wears("melee", "spear"), "you start with neither spear nor bow")


func _fire_arrow() -> void:
	ok(not Techniques.knows("fire_arrow"), "the fire arrow is not known at first (the bow hunts only)")
	ok(Techniques.row("fire_arrow").get("name", "") == "Fire arrow", "techniques.json fire_arrow")
	Techniques.learn("fire_arrow", {})
	ok(Techniques.knows("fire_arrow"), "learned from a headman, kept")
	# A fire put out; an arrow landing by it lights it.
	var fire: Node3D = main.camp.fire()
	var st := FireStore.store_of(fire)
	st.state = "embers"
	fire.set_meta("lit", false)
	var how := Arrow.light_at(self, fire.global_position + Vector3(0.6, 0.2, 0.0), world.days)
	ok(how.begins_with("fire:") and FireStore.is_lit(fire), "a fire arrow landing by a cold fire lights it (%s)" % how)
	ok(Arrow.light_at(self, fire.global_position + Vector3(9.0, 0.0, 0.0), world.days) == "", "and nothing far from it")
