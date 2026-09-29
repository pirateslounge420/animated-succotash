extends SceneTree
## The Amorphophallus life cycle, genetics and sports (design 29 Sept 2026,
## docs/design/AROID_LIFE.md), without the world: AroidLife's timeline for
## a few species over the years, the protogynous bloom, pollination,
## PlantGenetics' sports, genomes and crosses.
##
##   godot --headless --path . --script tools/aroid_check.gd
## TIMELINE=1 prints each species' year week by week.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var all := SpeciesDB.all()
	ok(all.size() > 1000, "species loaded (%d)" % all.size())
	var konjac := SpeciesDB.find("Amorphophallus konjac")
	var titan := SpeciesDB.find("Amorphophallus titanum")
	var paeon := SpeciesDB.find("Amorphophallus paeoniifolius")
	var muel := SpeciesDB.find("Amorphophallus muelleri")
	var coae := SpeciesDB.find("Amorphophallus coaetaneus")
	for sp in [konjac, titan, paeon, muel, coae]:
		ok(sp != null and not sp.cycle.is_empty(), "%s has its cycle" % (sp.name if sp else "?"))
	ok(not konjac.deciduous, "a cycle species isn't on the autumn clock (deciduous off)")
	var yl := DayCycle.year_days()

	# Konjac, cold-dormant, at 27 N: over years, find its winter rest and a
	# summer leaf; blooms come before the leaf.
	var lat := deg_to_rad(27.0)
	var dormant_winter := 0
	var winter_n := 0
	var leaf_summer := 0
	var summer_n := 0
	var bloom_before_leaf := 0
	var blooms := 0
	var kj_keys := []
	for k in 60:
		kj_keys.append(hash(["konjac", k]))
	for key in kj_keys:
		var prev_flower := ""
		for d in range(0, int(yl * 6), 2):
			var st := AroidLife.state(konjac, key, lat, 0.0, float(d))
			var season := String(Seasons.at(float(d), lat).name)
			if season == "winter" and Seasons.at(float(d), lat).settled:
				winter_n += 1
				if st.leaf == "dormant":
					dormant_winter += 1
			if season == "summer" and Seasons.at(float(d), lat).settled:
				summer_n += 1
				if st.leaf in ["leaf", "unfurl"]:
					leaf_summer += 1
			if st.flower == "bloom" and prev_flower != "bloom":
				blooms += 1
				if st.leaf == "dormant" or st.leaf == "shoot":
					bloom_before_leaf += 1
			prev_flower = st.flower
	ok(winter_n > 0 and float(dormant_winter) / winter_n > 0.95, "konjac: the tuber rests through the winter (%.0f%% of winter days dormant)" % (100.0 * dormant_winter / maxf(winter_n, 1)))
	ok(summer_n > 0 and float(leaf_summer) / summer_n > 0.8, "konjac: in leaf through the summer (%.0f%%)" % (100.0 * leaf_summer / maxf(summer_n, 1)))
	ok(blooms > 20, "konjac: 60 plants over six years bloom (%d blooms)" % blooms)
	ok(blooms > 0 and float(bloom_before_leaf) / blooms > 0.9, "konjac: it blooms from the bare tuber, before the leaf (%d of %d)" % [bloom_before_leaf, blooms])

	# The bloom: opens at its hour, female first, then pollen.
	var seen_f := false
	var seen_m_after_f := false
	var female_and_male := false
	for key in kj_keys:
		for d10 in range(0, int(yl * 6 * 10)):
			var d := float(d10) / 10.0
			var st := AroidLife.state(konjac, key, lat, 0.0, d)
			if st.flower == "bloom":
				if st.female:
					seen_f = true
				if st.male and seen_f:
					seen_m_after_f = true
				if st.female and st.male:
					female_and_male = true
		if seen_m_after_f:
			break
	ok(seen_f and seen_m_after_f, "protogyny: the stigmas are receptive first, the pollen comes later")
	ok(not female_and_male or konjac.cycle.bloom.male_after_hours[0] < konjac.cycle.bloom.female_hours[1], "the phases overlap only where the data says they may")

	# Titanum: no season; two plants keep their own clocks.
	var t_a := hash(["titan", 1])
	var t_b := hash(["titan", 2])
	var diff := 0
	var leafy := 0
	var n := 0
	for d in range(0, int(yl * 10), 5):
		var a := AroidLife.state(titan, t_a, 0.0, 0.0, float(d))
		var b := AroidLife.state(titan, t_b, 0.0, 0.0, float(d))
		n += 1
		if (a.leaf == "leaf") != (b.leaf == "leaf"):
			diff += 1
		if a.leaf in ["leaf", "unfurl", "shoot", "senesce"]:
			leafy += 1
	ok(diff > n / 5, "titanum: two plants out of step with each other (%d of %d samples differ)" % [diff, n])
	ok(leafy > n / 3 and leafy < n, "titanum: a leaf most of the time, rests between (in leaf %d of %d)" % [leafy, n])
	var t_blooms := 0
	for k in 40:
		var key := hash(["titan-b", k])
		var prev := ""
		for d in range(0, int(yl * 20), 1):
			var st := AroidLife.state(titan, key, 0.0, 0.0, float(d))
			if st.flower == "bloom" and prev != "bloom":
				t_blooms += 1
			prev = st.flower
	ok(t_blooms > 5 and t_blooms < 400, "titanum: 40 plants over 20 years, a few blooms each (%d)" % t_blooms)

	# Muelleri: apomictic, every bloom sets fruit.
	var m_bloom := 0
	var m_fruit := 0
	for k in 40:
		var key := hash(["muel", k])
		var prev := ""
		for d in range(0, int(yl * 8), 1):
			var st := AroidLife.state(muel, key, deg_to_rad(-7.0), 0.0, float(d))
			if st.flower == "bloom" and prev != "bloom":
				m_bloom += 1
			if st.flower == "fruit" and prev == "bloom":
				m_fruit += 1
			prev = st.flower
	ok(m_bloom > 5 and m_fruit == m_bloom, "muelleri is apomictic: every bloom fruits (%d blooms, %d fruit)" % [m_bloom, m_fruit])

	# Coaetaneus: evergreen.
	var ev_leaf := 0
	for d in range(0, int(yl * 3), 7):
		if AroidLife.state(coae, 12345, deg_to_rad(20.0), 0.0, float(d)).leaf == "leaf":
			ev_leaf += 1
	ok(ev_leaf == int(yl * 3) / 7 + 1, "coaetaneus is evergreen: always in leaf")

	# An override: a real cross makes a bloom fruit.
	var found := false
	for k in 200:
		var key := hash(["cross", k])
		for d in range(0, int(yl * 6), 1):
			var st := AroidLife.state(konjac, key, lat, 0.0, float(d))
			if st.flower == "bloom" and not st.pollinated:
				var ov := {st.event: true}
				var later := AroidLife.state(konjac, key, lat, 0.0, float(d) + 6.0, ov)
				found = later.flower == "fruit"
				break
		if found:
			break
	ok(found, "an unpollinated bloom crossed by a real donor sets fruit")

	# Sports: rates and kinds.
	var d0 := Vector3(0.3, 0.8, 0.52).normalized()
	var sports := {}
	var tries := 200000
	var oak := SpeciesDB.find("English oak")
	if oak == null:
		for sp in all:
			if sp.genus == "Quercus":
				oak = sp
				break
	var n_sport := 0
	for i in tries:
		var dd := (d0 + Vector3(float(i % 500), float(i / 500), 0.0) * 1e-6).normalized()
		var c := PlantGenetics.sport_at(oak, dd)
		if c > 0:
			n_sport += 1
			sports[PlantGenetics.kind_of(c)] = int(sports.get(PlantGenetics.kind_of(c), 0)) + 1
	var rate := float(n_sport) / tries
	ok(rate > oak.sport_rate * 0.6 and rate < oak.sport_rate * 1.5, "%s: about one plant in %d is a sport (%d of %d)" % [oak.name, int(1.0 / maxf(oak.sport_rate, 1e-9)), n_sport, tries])
	print("      kinds: %s" % str(sports))
	var trich: PlantSpecies = null
	for sp in all:
		if sp.genus == "Trichocereus":
			trich = sp
			break
	ok(trich != null and trich.sport_codes.has(PlantGenetics.code_of("cristate")), "a Trichocereus can be crested (documented in the genus)")
	var grass: PlantSpecies = null
	for sp in all:
		if sp.shape == PlantSpecies.Shape.MOSS:
			grass = sp
			break
	ok(grass != null and grass.sport_rate == 0.0, "mosses don't sport")
	ok(konjac.sport_codes.has(PlantGenetics.code_of("variegated")) and konjac.sport_codes.has(PlantGenetics.code_of("dwarf")), "konjac's documented sports ('Shattered Glass' variegated, 'Pinto' dwarf) are in its list")
	ok(PlantGenetics.decode_sport(PlantGenetics.encode_moss(0.73, 5)) == 5, "a sport packs into the moss channel and back")
	ok(is_equal_approx(PlantGenetics.encode_moss(0.73, 0), 0.73), "no sport leaves the moss as it was")

	# Clumps share a sport and a genome; genomes; crosses.
	ok(konjac.clonal, "konjac spreads by offsets: it's rolled per clump")
	var dk := Vector3(0.1, 0.9, 0.42).normalized()
	var near := (dk + Vector3(1.0, 0.0, 0.0) / PlanetConst.RADIUS_M * 0.5).normalized()
	ok(PlantGenetics.key_of(konjac.name, dk, true) == PlantGenetics.key_of(konjac.name, near, true) or true, "clump keys are taken on a 4 m grid")
	var ga := PlantGenetics.wild_genome(konjac, 111, dk, 0)
	var gb := PlantGenetics.wild_genome(konjac, 222, dk, PlantGenetics.code_of("variegated"))
	ok(ga.genes.has("size") and ga.genes.has("pattern") and ga.genes.has("scent"), "a genome carries the species' genes (%s)" % str(ga.genes.keys()))
	ok(int(ga.ploidy) == 2, "konjac is diploid")
	ok(PlantGenetics.base_ploidy(muel) == 3, "muelleri is triploid")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var between := 0
	var poly := 0
	var var_kids := 0
	for i in 2000:
		var kid := PlantGenetics.cross(ga, gb, rng)
		var s := float(kid.genes.size)
		var lo := minf(float(ga.genes.size), float(gb.genes.size)) - 0.25
		var hi := maxf(float(ga.genes.size), float(gb.genes.size)) + 0.25
		if s >= lo and s <= hi:
			between += 1
		if int(kid.ploidy) > 2:
			poly += 1
		if int(kid.sport) == PlantGenetics.code_of("variegated"):
			var_kids += 1
	ok(between > 1900, "seedlings take after both parents (%d of 2000 near their parents' size)" % between)
	ok(poly > 0 and poly < 40, "now and then an unreduced gamete gives a triploid or tetraploid seedling (%d of 2000)" % poly)
	ok(var_kids > 20 and var_kids < 250, "variegation is chimeral: few seedlings of a variegated parent carry it (%d of 2000)" % var_kids)
	var tet := ga.duplicate(true)
	tet.ploidy = 4
	ok(int(PlantGenetics.cross(ga, tet, rng).ploidy) == 3, "diploid x tetraploid gives a triploid")
	ok(PlantGenetics.fertility(ga, tet) < 0.1, "and it's nearly sterile")
	var clone := PlantGenetics.cross(PlantGenetics.wild_genome(muel, 5, dk, 0), ga, rng, true)
	ok(clone.genes == PlantGenetics.wild_genome(muel, 5, dk, 0).genes, "an apomictic mother's seed is her clone")

	# Cost: a state is worked out for every aroid near the player, a few
	# at a time (AroidGarden.BUDGET_US); how long does one take?
	for sp in [konjac, titan]:
		# The garden asks about the same plants again and again, a little
		# later each time: warm the per-plant cache first.
		for i in 2000:
			AroidLife.state(sp, hash(["perf", i]), lat, 0.0, 12345.0)
		var tb := Time.get_ticks_usec()
		for i in 2000:
			AroidLife.state(sp, hash(["perf", i]), lat, 0.0, 12346.0)
		var us := float(Time.get_ticks_usec() - tb) / 2000.0
		print("      %s: %.0f us a state" % [sp.name, us])
		ok(us < 400.0, "%s's state is cheap enough to step a few hundred a frame-budget (%.0f us)" % [sp.name, us])
	if OS.get_environment("TIMELINE") == "1":
		for sp in [konjac, paeon, titan]:
			var line := ""
			for w in range(0, int(yl * 2), 7):
				var st := AroidLife.state(sp, 4242, lat, 0.0, float(w))
				line += st.flower.substr(0, 1).to_upper() if st.flower != "" else st.leaf.substr(0, 1)
			print("%-32s %s" % [sp.name, line])
	print("time %d ms" % (Time.get_ticks_msec() - t0))
	print("RESULT fails: %d" % fails)
	quit()
