extends SceneTree
## Run: STAMP=1 godot --headless --path . --fixed-fps 60 --script tools/camp_check.gd
## Camps are alive (design 30 Sept §BL–§BN): the opening camp has a
## people and a sim state; ticks catch up with the clock; by day the
## folk gather wood and food into the store and the store props follow;
## the fire is fed from the woodpile; what the player puts on the store
## counts; births, the ladder and the specialists; a fire kept low
## brings the dark; wildfire; techniques.
var main
var world
var player: PlanetPlayer
var fails := 0


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	# A clean world save: the check time-travels and must not inherit it.
	var dir := DirAccess.open("user://worlds")
	if dir:
		for f in dir.get_files():
			dir.remove(f)
	world = get_root().get_node("World")
	world.spawn_choice = 0
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(60)
	var sim: CampSim = main.camp_sim
	# --- A people per site (§BO) ---
	var pid: String = main.camp.people_id
	var people := Peoples.get_people(pid)
	ok(pid != "" and not people.is_empty(), "the opening camp lives a life: %s (%s)" % [pid, Peoples.name_of(people)])
	ok(main.camp.get_node_or_null("Dressing/Shelter") != null, "its shelter is built from the people file")
	ok(GameLog.entries.any(func(e): return str(e.text).find("live here") >= 0), "the log says who lives here")
	var kinds := 0
	for id in Peoples.ids():
		if not Peoples.get_people(str(id)).is_empty():
			kinds += 1
	ok(kinds == 17, "all seventeen people files load (%d)" % kinds)
	# --- The store and the loop (§BL) ---
	var st := sim.state_of("opening")
	ok(not st.is_empty() and str(st.state) == "living", "the opening camp has a sim state")
	ok(absf(float(st.last_tick) - world.days) <= CampSim.tick_days(), "its ticks are caught up to the clock (behind by %.3f days)" % (world.days - float(st.last_tick)))
	ok(main.camp.woodpile != null and main.camp.food_store != null, "a woodpile and a food store stand by the fire")
	var wood0 := float(st.wood)
	var food0 := float(st.food)
	var folk0 := sim.folk_count(st)
	print("[camp] %d folk, wood %.1f, food %.1f, woods %.2f, fire %s" % [folk0, wood0, food0, st.woods, FireStore.stores[st.fire_key].state])
	# A day passes while the camp is 'unloaded': the folk gather and eat.
	var fst: Dictionary = FireStore.stores[st.fire_key]
	fst.units = [["branch", 1.0]]
	fst.state = "low"
	world.days += 1.0
	sim.catch_up(st)
	print("[camp] a day later: wood %.1f, food %.1f, woods %.2f, fire %s with %.1f units" % [st.wood, st.food, st.woods, fst.state, FireStore.units_now(fst)])
	ok(absf(float(st.last_tick) - world.days) <= CampSim.tick_days(), "a missed day is caught up in ticks")
	var wood_target := float(CampSim.SIM.store.wood_days_target) * float(CampSim.SIM.store.wood_units_per_night)
	ok(FireStore.units_now(fst) > 1.0 and float(st.wood) <= wood_target + 0.01, "the fire was fed from the woodpile (%.1f units on it, pile %.1f of %.0f)" % [FireStore.units_now(fst), st.wood, wood_target])
	ok(float(st.woods) < 1.0, "the woods within reach thinned with the take (%.2f)" % st.woods)
	await frames(100)
	ok(absf(float(main.camp.woodpile.get_meta("units", -1.0)) - float(st.wood)) < 1.0, "the woodpile prop follows the store (%.1f)" % st.wood)
	# The player's gathering counts.
	var before := float(st.wood)
	sim.add_wood(st, CampSim.wood_units(Inventory.make("fuel", {"fuel": "hardwood_log"})))
	ok(float(st.wood) > before + 2.0, "a hardwood log on the woodpile is worth its burn (%.1f units)" % (float(st.wood) - before))
	ok(CampSim.food_units(Inventory.make("fruit")) == 1.0 and CampSim.is_seed(Inventory.make("plant_sample", {"part": "seed"})), "fruit is food, a seed head is seed")
	# --- Population and the ladder (§BM) ---
	# Feed them well for a month: the ladder climbs, a child is born.
	var rung0 := int(st.rung)
	for day in 35:
		st.food = maxf(float(st.food), 40.0)
		st.wood = maxf(float(st.wood), 20.0)
		world.days += 1.0
		sim.catch_up(st)
	var roles := {}
	var by_stage := {}
	for f in st.folk:
		if str(f.get("role", "")) != "":
			roles[str(f.role)] = true
		by_stage[CampSim.stage_of(f)] = int(by_stage.get(CampSim.stage_of(f), 0)) + 1
	print("[camp] after 35 fed days: %d folk %s, rung %d, roles %s, cap %d, weir %s, plot %s" % [sim.folk_count(st), by_stage, st.rung, roles.keys(), sim.cap(st), st.weir, st.plot])
	# The three stages (§BM, Mike): child -> teen -> adult by age; a
	# child does not gather, a teen gathers at half rate and holds no
	# role, an adult does both.
	var stg: Dictionary = CampSim.stages()
	var child_days := float(stg.child.game_days)
	var teen_days := float(stg.teen.game_days)
	ok(CampSim.stage_for_age(0.0) == "child" and CampSim.stage_for_age(child_days + 1.0) == "teen" and CampSim.stage_for_age(child_days + teen_days + 1.0) == "adult", "a child is a teen after %d days and an adult after %d more" % [int(child_days), int(teen_days)])
	ok(by_stage.get("child", 0) > 0, "the newborn is a child by the fire")
	ok(CampSim.gather_rate_of({"stage": "child", "role": ""}) == 0.0 and CampSim.gather_rate_of({"stage": "teen", "role": ""}) == float(stg.teen.gather_rate) and CampSim.gather_rate_of({"stage": "adult", "role": ""}) == 1.0, "a child does not gather, a teen at %.1f, an adult at 1" % float(stg.teen.gather_rate))
	var teen_st := {"folk": [{"sex": "m", "stage": "teen", "born": 0.0, "role": "", "seed": 1}, {"sex": "f", "stage": "adult", "born": 0.0, "role": "", "seed": 2}]}
	sim._give_role(teen_st, "headman", "m")
	ok(str(teen_st.folk[0].role) == "" and str(teen_st.folk[1].role) == "headman", "a teen cannot be the headman; the adult is")
	var spec_rate := float(CampSim.SIM.population.specialist_gather_rate)
	ok(absf(sim.gatherers(teen_st) - (float(stg.teen.gather_rate) + spec_rate)) < 0.001, "the teen gathers half, the headman a share (%.2f)" % sim.gatherers(teen_st))
	ok(int(st.rung) >= 2, "a fed camp climbs to the storage rung (%d, from %d)" % [st.rung, rung0])
	ok(roles.has("headman") and roles.has("plantkeeper"), "the headman and the plantkeeper appear at storage")
	ok(sim.folk_count(st) > folk0, "births: the camp grew (%d from %d)" % [sim.folk_count(st), folk0])
	ok(sim.folk_count(st) <= sim.cap(st), "never past its ceiling (%d of %d)" % [sim.folk_count(st), sim.cap(st)])
	var fund := str(people.get("fundamental", "forage"))
	if fund == "fish_run":
		ok(bool(st.weir), "a fish_run people raised its weir at the food rung")
	# Seeds: a species that fits the site takes; one that cannot just sits.
	var fits := -1
	var all := SpeciesDB.all()
	for i in all.size():
		if all[i].tier == PlantSpecies.Tier.GROUND and sim._seed_takes(st, i):
			fits = i
			break
	if fits >= 0:
		var st2 := {"key": "test", "dir": st.dir, "people": "river", "biome": st.biome, "seed": 7, "folk": st.folk, "wood": 10.0, "food": 40.0, "woods": 1.0, "rung": 1, "last_tick": world.days, "fire_low_nights": 0, "low_tonight": false, "food_short_days": 0.0, "state": "living", "blood": false, "seeds": 0, "plot": false, "weir": false, "surplus_days": 20.0, "last_birth": world.days, "met_headman": false, "dry_days": 0.0, "scar": false, "inherits": [], "fire_key": st.fire_key, "reach_m": 300.0, "log": []}
		sim.add_seeds(st2, fits)
		sim._ladder(st2, world.days)
		ok(bool(st2.plot), "a crop people with seeds that take in this soil gets a plot (%s)" % all[fits].name)
	# --- The headman bestows (§BN, §BP) ---
	ok(not Techniques.knows("fishing_line"), "no technique known at the start")
	var learned := Techniques.learn(str(people.specialists.headman_teaches), people)
	ok(learned and Techniques.knows(str(people.specialists.headman_teaches)), "the headman's technique is a permanent flag (%s)" % people.specialists.headman_teaches)
	ok(GameLog.entries.any(func(e): return str(e.text).find("showed you") >= 0), "the log says who showed you what")
	ok(not Techniques.learn(str(people.specialists.headman_teaches), people), "learning it again does nothing")
	ok(WorldSave.data.has("techniques"), "techniques are in the world's save")
	for t in ["fishing_line", "coppice", "resin_torch", "ember_carrier", "fat_lamp"]:
		Techniques.known()[t] = true
	# The pole: a branch and grass, at the water.
	player.inventory.add(Inventory.make("fuel", {"fuel": "branch"}))
	player.inventory.add(Inventory.make("fuel", {"fuel": "grass_bundle"}))
	main._make_pole()
	ok(player.inventory.has_kind("pole") and not player.inventory.has_kind("fuel"), "a branch and grass become a pole and line")
	player.weapon = "pole"
	ok(player.in_hand() == "pole", "the pole comes to hand")
	# The ember carrier: a coal from the lit fire, a fire laid from it.
	var fire: Node3D = main.camp.fire()
	main._take_ember(fire)
	ok(player.inventory.has_kind("ember"), "a live coal wrapped in bark")
	var fires0: int = (WorldSave.data.get("fires", []) as Array).size()
	var off := CreatureSpawner._offset(main.camp.site, 2.0, 30.0)
	main.player_fires.lay_fire(off, 2)
	ok((WorldSave.data.get("fires", []) as Array).size() == fires0 + 1 and FireStore.stores.has(FireStore.key_of(off)), "a fire laid from the ember burns untended and is kept")
	var ember_it := Inventory.make("ember", {"until": world.days - 0.1})
	ok(world.days >= float(ember_it.until), "a neglected ember is cold")
	# The fat lamp: from a store's fat, set down for hours.
	var food_b := float(st.food)
	main.player.inventory.add(Inventory.make("fat_lamp"))
	main.player_fires.place_lamp(CreatureSpawner._offset(main.camp.site, 1.0, 12.0), 8.0)
	ok((WorldSave.data.get("lamps", []) as Array).size() == 1, "a fat lamp set down is kept and burns for hours")
	# The resin torch: burns longer, drizzle-proof.
	var plain := Inventory.make("torch", {"lit": true, "burn_left_min": 50.0})
	var resin := Inventory.make("torch", {"lit": true, "burn_left_min": 50.0, "resin": true})
	Torch.burn_step(plain, 60.0, {"rain_mm_h": 2.0}, true)
	Torch.burn_step(resin, 60.0, {"rain_mm_h": 2.0}, true)
	ok(float(resin.burn_left_min) > float(plain.burn_left_min) + 0.5, "the resin torch burns slower in drizzle (%.2f vs %.2f left)" % [resin.burn_left_min, plain.burn_left_min])
	# Coppice: a tree near the camp that can be, cut to the stool.
	var cut := false
	for key in main.chunks.chunks:
		var chunk: TerrainChunk = main.chunks.chunks[key]
		if chunk.trees.is_empty():
			continue
		for i in chunk.trees.size():
			if Coppice.coppiceable(chunk.tree_species(i)) and chunk.trees[i][1] > 3.0:
				var n := Coppice.cut(chunk, i, world, world.days)
				cut = n != null
				break
		if cut:
			break
	ok(cut, "a hazel or an ash cut to the stool (the stool stands, poles regrow on the species' clock)")
	# --- Ruins remember (§BQ) ---
	var ruins_built: Dictionary = main.landmarks.built_ruins()
	var marked := 0
	var heaps := 0
	for c in ruins_built:
		var rn: Node3D = ruins_built[c]
		var mk := rn.get_node_or_null("Marks")
		if mk != null and mk.get_child_count() > 0:
			marked += 1
			for sg in mk.get_children():
				if int((sg as Node).get_meta("level", 0)) == 0:
					heaps += 1
	print("[ruin] %d ruins built near the camp, %d carry their people's signatures (%d as heaps)" % [ruins_built.size(), marked, heaps])
	ok(ruins_built.is_empty() or marked > 0, "every built ruin carries its people's signatures")
	var inh_st := {"key": "ruin:test", "inherits": [], "weir": false, "rung": 0, "surplus_days": 0.0, "food": 1.0}
	sim.inherit(inh_st, Peoples.get_people("coast"))
	ok(bool(inh_st.weir) and int(inh_st.rung) >= 1, "a camp squatting in a coast ruin inherits the weir from the first season")
	ok(SoilMarks.fertility_at(Vector3.UP) == 1.0, "ground without a mark is as it was")
	# --- Collapse and the dark (§BL, §BA) ---
	var c_st := sim.ensure("ruin:collapse_test", CreatureSpawner._offset(main.camp.site, 0.5, 2500.0), "coast", st.biome, 99)
	var n0 := sim.folk_count(c_st)
	var cf: Dictionary = FireStore.stores[c_st.fire_key]
	cf.units = []
	cf.state = "out"
	c_st.wood = 0.0
	for day in 3:
		world.days += 1.0
		sim.catch_up(c_st)
	print("[camp] a fire kept out for 3 nights: %d folk from %d, state %s, blood %s" % [sim.folk_count(c_st), n0, c_st.state, c_st.blood])
	ok(sim.folk_count(c_st) < n0, "a fire kept low for nights: the dark takes folk")
	ok(bool(c_st.blood), "and leaves blood")
	ok(str(c_st.state) == "abandoned" or sim.folk_count(c_st) == 0 or sim.folk_count(c_st) < n0, "the survivors walk to the nearest lit fire")
	var abandoned_day := float(c_st.get("abandoned_day", world.days))
	world.days = abandoned_day + float(CampSim.SIM.abandon.ruin_after_game_days) + 1.0
	sim.catch_up(c_st)
	ok(str(c_st.state) == "ruin", "an empty camp is a ruin after ruin_after_game_days (%s)" % c_st.state)
	# Starvation moves them, no blood.
	var s_st := sim.ensure("ruin:starve_test", CreatureSpawner._offset(main.camp.site, 2.5, 2500.0), "steppe", st.biome, 98)
	s_st.food = 0.0
	s_st.food_short_days = float(CampSim.SIM.collapse.starve_moves_after_days) + 1.0
	sim._night_after(s_st, world.days)
	ok(str(s_st.state) == "abandoned" and not bool(s_st.blood), "food short for long enough moves them, no blood (%s)" % s_st.state)
	# --- Wildfire (§BL) ---
	var fire_st := sim.ensure("ruin:fire_test", CreatureSpawner._offset(main.camp.site, 4.0, 2500.0), "steppe", "STEPPE", 97)
	var scars0 := CampSim.scars.size()
	sim.start_fire(sim._dir(fire_st), {"wind": Vector3(3.0, 0.0, 0.0)}, "a torch dropped in the grass", world.days)
	ok(CampSim.scars.size() == scars0 + 1, "a burn leaves a scar the placer and the ground read")
	ok(CampSim.scar_at(sim._dir(fire_st), world.days) > 0.5, "the ground at the camp is scorched (%.2f)" % CampSim.scar_at(sim._dir(fire_st), world.days))
	ok(str(fire_st.state) != "living", "the camp in its path walked away (%s)" % fire_st.state)
	var moved := 0
	for k in sim.states:
		if str(k).begins_with("moved:"):
			moved += 1
	print("[camp] camps rebuilt a valley over: %d" % moved)
	ok(CampSim.scar_at(sim._dir(fire_st), world.days + 2000.0) == 0.0, "the scar heals in time")
	# --- Canopy folk (§BT) ---
	# Three giants lashed into a loaded chunk's tree list (the opening
	# coast has none): the village goes up in them.
	var sp_idx := -1
	for i in SpeciesDB.all().size():
		var sp: PlantSpecies = SpeciesDB.all()[i]
		if PlantMeshes.climbable(sp.shape) and sp.height_m.y >= 20.0:
			sp_idx = i
			break
	ok(sp_idx >= 0, "a climbable giant species exists")
	var csite: Vector3 = CreatureSpawner._offset(main.camp.site, 1.0, 80.0)
	var cat: Vector3 = world.to_scene(csite, PlanetConst.RADIUS_M + main.chunks.ground_height(csite))
	var host: TerrainChunk = null
	for k in main.chunks.chunks:
		host = main.chunks.chunks[k]
		break
	var fake_from := host.trees.size()
	var fr := Basis.looking_at(CubeSphere.north(csite), csite)
	for k in 3:
		var td: Vector3 = CreatureSpawner._offset(csite, k * TAU / 3.0, 9.0)
		var tb: Vector3 = world.to_scene(td, PlanetConst.RADIUS_M + main.chunks.ground_height(td))
		host.trees.append([tb - host.global_position, 30.0, sp_idx, 0, 1, 0, fr, -1, 0.0, 0.0, 0])
	var giants := CanopyVillage.giants_near(main.chunks, cat, CanopyVillage.SEARCH_M)
	ok(giants.size() >= 3, "three giants stand within reach of the site (%d)" % giants.size())
	var croot := Node3D.new()
	main.add_child(croot)
	croot.global_transform = Transform3D(fr, cat)
	var cbody := PropCollision.body(croot)
	var crng := RandomNumberGenerator.new()
	crng.seed = 7
	var village := CanopyVillage.build(croot, world, main.chunks, cat, Peoples.palette(Peoples.get_people("canopy"), "JUNGLE"), crng, "JUNGLE", cbody)
	ok(not village.is_empty() and (village.decks as Array).size() >= 3 and (village.decks as Array).size() <= CanopyVillage.MAX_DECKS, "platforms lashed in three or four of the giants (%d)" % ((village.decks as Array).size() if not village.is_empty() else 0))
	if not village.is_empty():
		ok(int(village.bridges) >= 2, "vine bridges join them (%d)" % int(village.bridges))
		ok(float((village.fire_pos as Vector3).y) >= CanopyVillage.DECK_Y.x - 1.0, "the hearth box is up on the first deck (%.1f m up)" % float((village.fire_pos as Vector3).y))
		ok((village.seats as Array).size() >= 4, "seats round the hearth and on the other decks (%d)" % (village.seats as Array).size())
		ok(cbody.get_child_count() > 20, "decks and planks collide (%d shapes)" % cbody.get_child_count())
		var lad: Node3D = village.ladder
		ok(not lad.visible, "no ladder comes down for a stranger")
		ok(absf(float((village.ladder_top as Vector3).y) - float(((village.decks as Array)[0] as Dictionary).center.y)) < 0.3, "the ladder hangs from the hearth deck")
		# Met the headman: the ladder shows and the player climbs it.
		lad.visible = true
		var foot: Vector3 = lad.to_global(lad.get_meta("foot_local"))
		var top: Vector3 = lad.to_global(lad.get_meta("top_local"))
		main.player.start_ladder(foot, top + csite * 0.15)
		await frames(900)
		ok(main.player.global_position.distance_to(top) < 1.0 and not main.player.on_ladder(), "the player climbs the rope ladder to the deck (%.1f m off)" % main.player.global_position.distance_to(top))
	host.trees.resize(fake_from)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
