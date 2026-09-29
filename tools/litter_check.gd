extends SceneTree
## Leaf fall and litter (design §AI; data/litter.json), checked headless on
## the numbers, not the pictures (tools/species_row.gd shows those):
##   - the deciduous crown through the year (LeafSeason.crown_at): green
##     and full in summer, turning over the autumn transition, shedding
##     from fall.start_at, bare after fall.deciduous_days, green again
##     after the spring transition;
##   - the rotting rate (LitterField.climate_rate): Q10 per 10 °C, the
##     freeze floor below 0 °C, the moisture curve;
##   - species multipliers (needles slower, glossy slower, matte 1);
##   - stages pass their litter on first-order, humus leaves into the soil
##     ledger (flora.litter), mass is kept until then;
##   - litter fungi fruit on wet-dark litter a few days after rain, in
##     their season;
##   - how long litter lasts: tropical broadleaf vs temperate broadleaf vs
##     boreal needles (the §AI 4 ordering: weeks-months, about a year,
##     years).
##
##   ~/bin/godot --headless --path . --script tools/litter_check.gd

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# --- The crown through the year ----------------------------------------
	var h := Seasons.half_transition()
	var quarter := DayCycle.year_days() / 4.0
	var summer := LeafSeason.crown_at(1.0, h)
	ok(summer.autumn == 0.0 and summer.leaf == 1.0, "summer: green and full (autumn %.2f, leaf %.2f)" % [summer.autumn, summer.leaf])
	var start := 1.5 - h + float(LeafSeason.FALL.start_at) * 2.0 * h
	var early := LeafSeason.crown_at(start - 0.001, h)
	ok(early.autumn > 0.0 and early.leaf == 1.0, "turning before the fall starts: autumn %.2f, leaf still %.2f" % [early.autumn, early.leaf])
	var d5 := LeafSeason.crown_at(start + 5.0 / quarter, h)
	var expect5 := pow(1.0 - float(LeafSeason.FALL.per_day_share), 5.0)
	ok(absf(d5.leaf - expect5) < 0.02, "5 days into the fall: leaf %.3f (per_day_share gives %.3f)" % [d5.leaf, expect5])
	var bare := LeafSeason.crown_at(start + float(LeafSeason.FALL.deciduous_days) / quarter + 0.001, h)
	ok(bare.leaf < 0.01 and bare.autumn == 1.0, "bare after deciduous_days (leaf %.3f)" % bare.leaf)
	var winter := LeafSeason.crown_at(3.0, h)
	ok(winter.leaf < 0.01, "winter: bare (leaf %.3f)" % winter.leaf)
	var spring_mid := LeafSeason.crown_at(3.5, h)
	ok(spring_mid.leaf > 0.3 and spring_mid.leaf < 0.7 and spring_mid.autumn == 0.0, "spring transition: leafing out green (leaf %.2f)" % spring_mid.leaf)
	var spring := LeafSeason.crown_at(0.2, h)
	ok(spring.leaf == 1.0 and spring.autumn == 0.0, "spring: full and green again")

	# --- Rate ----------------------------------------------------------------
	var r15 := LitterField.climate_rate(15.0, 0.6)
	var r25 := LitterField.climate_rate(25.0, 0.6)
	ok(absf(r15 - 1.0) < 1e-3, "reference (15 °C, moisture 0.6) rate 1 (%.3f)" % r15)
	ok(absf(r25 / r15 - float(LitterField.TIMING.q10)) < 1e-3, "Q10: +10 °C is %.2fx" % (r25 / r15))
	ok(absf(LitterField.climate_rate(-5.0, 0.6) - float(LitterField.TIMING.freeze_rate)) < 1e-3, "frozen: freeze_rate (%.3f)" % LitterField.climate_rate(-5.0, 0.6))
	ok(LitterField.climate_rate(15.0, 0.0) < 0.15 and LitterField.climate_rate(15.0, 1.0) > 1.5, "dry litter barely rots, wet fast (%.2f / %.2f)" % [LitterField.climate_rate(15.0, 0.0), LitterField.climate_rate(15.0, 1.0)])

	# --- Species -------------------------------------------------------------
	var pine := SpeciesDB.find("Scots pine")
	var oak := SpeciesDB.find("Oak")
	var palm := SpeciesDB.find("Coconut palm")
	print("[litter] multipliers: Scots pine %.2f (%s), Oak %.2f (%s/%s), Coconut palm %.2f (%s/%s, %.0f cm)" % [LitterField.rot_multiplier(pine), pine.leaf_type, LitterField.rot_multiplier(oak), oak.leaf_type, oak.leaf_texture, LitterField.rot_multiplier(palm), palm.leaf_type, palm.leaf_texture, palm.leaf_m * 100.0])
	ok(LitterField.rot_multiplier(pine) < LitterField.rot_multiplier(oak), "needles rot slower than oak leaves")

	# --- Stages ---------------------------------------------------------------
	var lf := LitterField.new()
	var c := LitterField.Cell.new()
	c.dominant = SpeciesDB.index_of(oak)
	c.m[0] = 1.0
	lf.cells[Vector3i(0, 0, 0)] = c
	var dry := {"temp_c": 15.0, "rain_mm_h": 0.0}
	lf.age(10.0, dry)
	var moved := c.m[1]
	ok(absf(moved - (1.0 - exp(-1.0))) < 0.05, "10 days at the reference moves %.2f of fresh to dry (first-order: %.2f)" % [moved, 1.0 - exp(-1.0)])
	ok(absf(c.mass() + c.humus - 1.0) < 1e-4, "mass kept (%.4f)" % (c.mass() + c.humus))
	# Dry stays dry without rain; rain sends it wet-dark.
	var before := c.m[2]
	lf.age(5.0, dry)
	var dry_gain := c.m[2] - before
	before = c.m[2]
	lf.age(5.0, {"temp_c": 15.0, "rain_mm_h": 2.0})
	var wet_gain := c.m[2] - before
	ok(wet_gain > dry_gain * 1.5, "rain turns dry litter wet-dark faster (%.3f vs %.3f in 5 days)" % [wet_gain, dry_gain])
	for i in 400:
		lf.age(2.0, dry if i % 5 else {"temp_c": 15.0, "rain_mm_h": 2.0})
	ok(c.humus > 0.8 and lf.flora_litter_kg > 0.0, "after ~2 years the oak litter is mostly humus in the soil (%.2f kg/m2; flora.litter %.1f kg)" % [c.humus, lf.flora_litter_kg])
	# Litter fungi: in autumn, 3 days after rain, on wet-dark litter.
	var fungi := lf._litter_fungi("autumn", 12.0)
	var names: Array = fungi.map(func(i): return SpeciesDB.all()[i].name)
	ok(not fungi.is_empty(), "litter fungi that fruit in autumn at 12 °C: %s" % ", ".join(names))
	ok(lf._litter_fungi("spring", 12.0).size() < fungi.size() or fungi.is_empty(), "fewer fruit out of season")
	lf._dry_days = 3.0
	var fruited := 0
	for i in 30:
		var fc := LitterField.Cell.new()
		fc.m[2] = 0.1
		lf._fruit(fc, Vector3i(0, i, 7), fungi)
		fruited += 0 if fc.fruit.is_empty() else 1
	ok(fruited > 3 and fruited < 20, "about a third of wet-dark cells fruit after rain (%d of 30)" % fruited)
	var bare_cell := LitterField.Cell.new()
	bare_cell.m[0] = 0.5
	lf._fruit(bare_cell, Vector3i(0, 1, 7), fungi)
	ok(bare_cell.fruit.is_empty(), "fresh litter doesn't fruit")
	lf.free()

	# --- How long it lasts ------------------------------------------------------
	var trop := _lasts(oak, 27.0, 0.9)
	var temp := _lasts(oak, 12.0, 0.6)
	var boreal := _lasts(pine, 2.0, 0.5)
	print("[litter] leaf shape gone (90%% at humus) / 90%% into the soil: tropical broadleaf %d / %d days, temperate broadleaf %d / %d days, boreal needles %d / %d days" % [trop.x, trop.y, temp.x, temp.y, boreal.x, boreal.y])
	ok(trop.y < temp.y and temp.y < boreal.y, "tropical < temperate < boreal")
	ok(temp.y > 200 and temp.y < 1100, "temperate broadleaf gone in about a year or two (%d days)" % temp.y)
	ok(boreal.y > 1000, "boreal needles take years (%d days)" % boreal.y)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Days until 90 % of a fresh layer of `sp` litter has reached humus, and
## until 90 % has left into the soil, at `temp_c` and `moisture`, with a
## rain every 5 days.
func _lasts(sp: PlantSpecies, temp_c: float, moisture: float) -> Vector2i:
	var lf := LitterField.new()
	var c := LitterField.Cell.new()
	c.dominant = SpeciesDB.index_of(sp)
	c.m[0] = 1.0
	lf.cells[Vector3i(0, 0, 0)] = c
	var shape := -1
	var day := 0
	lf._wet = 0.0
	while day < 20000:
		day += 1
		var w := {"temp_c": temp_c, "rain_mm_h": 2.0 if day % 5 == 0 else 0.0}
		# (The place's moisture: LitterField reads the planet when it has
		# one; here it is set through the soak.)
		lf._wet = maxf(lf._wet, moisture) if day % 5 != 0 else 1.0
		lf.age(1.0, w)
		if shape < 0 and c.m[4] + c.humus >= 0.9:
			shape = day
		if c.humus >= 0.9:
			break
	lf.free()
	return Vector2i(shape, day)
