class_name AroidLife
## One Amorphophallus plant's life, read off the world clock (design 29 Sept
## 2026, docs/design/AROID_LIFE.md; the species' researched `cycle` block
## in data/plants/amorphophallus.json).
##
## Nothing is stored: a plant's life is a pure function of its key (where it
## grows: PlantGenetics.key_of()), its species' cycle, the place's seasons
## (latitude) and the world day, so the same plant is at the same point of
## its life on every visit. Two channels run side by side:
##   leaf     dormant (the bare tuber: nothing above ground) -> shoot (the
##            cataphyll-wrapped spike breaks the soil and rises over
##            shoot.rise_days) -> unfurl (the three-way blade spreads over
##            shoot.unfurl_days) -> leaf -> senesce (the leaf collapses) ->
##            dormant.
##   flower   "" -> bud (the inflorescence bud rises over bud.bud_days) ->
##            bloom (the spathe opens at bloom.opens, local time; protogynous:
##            female for bloom.female_hours, pollen from
##            bloom.male_after_hours; open bloom.open_days) -> wilt, or fruit
##            (pollinated or apomictic: the berries ripen over
##            fruit.ripen_days, unripe to ripe colour) -> "".
## Seasonal species (life.dormancy dry or cold) flush once a year at their
## season: dry-season species as the rains come, cold-dormant ones as it
## warms (Seasons: the hemisphere's own year). The leaf lives life.leaf_days
## and the tuber rests the rest of the year. Everwet species ("cycle", A.
## titanum) run on their own clock: a leaf for leaf_days, a rest for
## rest_days, again and again, out of step with every other plant.
## "evergreen" ones (A. coaetaneus) keep a leaf all the time.
## Blooming is a tuber-maturity gate (design §E): a plant first blooms at
## tuber.first_bloom_years old and then every tuber.bloom_every_years, the
## bloom coming before the leaf, with it, after it or instead of it
## (bloom.when), and then either a leaf in the same season or a rest
## (bloom.then). Old growth: most plants are mature; JUVENILE of them are
## young tubers that only leaf.
## Pollination: the female phase comes first, so a bloom needs another
## plant's pollen. Whether it set fruit is rolled per bloom (pollen_chance():
## synchronous seasonal bloomers find each other more often than titanum's
## lone blooms); AroidGarden overrides it with a real cross when it sees
## two plants in bloom near each other. Apomictic species (A. muelleri, A.
## kiusianus) always fruit.

## Local opening hour by bloom.opens.
const OPEN_HOUR := {"evening": 18.0, "night": 21.0, "morning": 7.0, "afternoon": 14.0}
## Where in the local year (a fraction: 0 is spring's middle, 0.25 summer's)
## the leaf flush starts.
const FLUSH := {"dry": 0.125, "cold": 0.07, "evergreen": 0.125, "cycle": 0.0}
const JUVENILE := 0.15
const MAX_AGE_Y := 35.0
## Days a spent spathe takes to collapse; the gap between a bloom and the
## leaf that follows it (bloom.then "leaf").
const WILT_DAYS := Vector2(2.0, 4.0)
const GAP_DAYS := Vector2(7.0, 28.0)
## Per plant key: its fixed draws, its bloom years for the year asked last,
## and where an everwet plant's walk got to (so the next ask carries on
## from there). Main thread only (AroidGarden); dropped when it grows big.
static var _cache := {}
const CACHE_MAX := 60000


static func _slot(key: int) -> Dictionary:
	var c = _cache.get(key)
	if c == null:
		if _cache.size() > CACHE_MAX:
			_cache.clear()
		c = {}
		_cache[key] = c
	return c


## A 0-1 draw for this plant, stream `a`, item `b`.
static func _u(key: int, a: int, b := 0) -> float:
	return PlantGenetics.unit(hash([key, b]), a)


## Somewhere in a [min, max] data range, or the fallback.
static func _pick(r, u: float, fallback: Vector2) -> float:
	if r is Array and r.size() == 2:
		return lerpf(float(r[0]), float(r[1]), u)
	return lerpf(fallback.x, fallback.y, u)


static func _cy(sp: PlantSpecies, block: String) -> Dictionary:
	var b = sp.cycle.get(block, {})
	return b if b is Dictionary else {}


## The share of blooms of this species that set fruit when no real donor
## is seen (see the class notes).
static func pollen_chance(sp: PlantSpecies) -> float:
	var bl := _cy(sp, "bloom")
	if bl.get("apomixis", false) == true:
		return 1.0
	var dorm := str(_cy(sp, "life").get("dormancy", "dry"))
	var p := 0.12 if dorm == "cycle" else (0.3 if dorm == "evergreen" else 0.45)
	if bl.get("self_compatible", false) == true:
		p += 0.25
	if (bl.get("pollinators", []) as Array).size() >= 3:
		p *= 1.1
	return clampf(p, 0.0, 0.95)


## The plant's fixed draws: age (years at world day 0), first bloom age.
static func _plant(sp: PlantSpecies, key: int) -> Dictionary:
	var slot := _slot(key)
	if slot.has("plant"):
		return slot.plant
	slot.plant = _plant_draw(sp, key)
	return slot.plant


static func _plant_draw(sp: PlantSpecies, key: int) -> Dictionary:
	var tub := _cy(sp, "tuber")
	var first := _pick(tub.get("first_bloom_years"), _u(key, 1), Vector2(3, 6))
	var age: float
	if _u(key, 2) < JUVENILE:
		age = _u(key, 3) * first
	else:
		age = first + _u(key, 3) * (MAX_AGE_Y - first)
	return {"first": first, "age": age}


## The state of plant `key` of `sp` at world day `days`, at latitude `lat`
## and longitude `lon` (radians). `overrides` forces blooms' outcomes
## (event -> true/false: AroidGarden's real crosses); `fert` scales the
## roll (a sterile sport sets less). Returns {"leaf", "leaf_t", "flower", "flower_t",
## "open_h", "female", "male", "pollinated", "event", "open_day", "mature",
## "age_y"}.
static func state(sp: PlantSpecies, key: int, lat: float, lon: float, days: float, overrides := {}, fert := 1.0) -> Dictionary:
	var out := {"leaf": "dormant", "leaf_t": 0.0, "flower": "", "flower_t": 0.0, "open_h": 0.0,
		"female": false, "male": false, "pollinated": false, "event": -1, "open_day": 0.0,
		"mature": false, "age_y": 0.0}
	if sp.cycle.is_empty():
		out.leaf = "leaf"
		return out
	var dorm := str(_cy(sp, "life").get("dormancy", "dry"))
	if dorm == "cycle":
		_walk_cycles(sp, key, lat, lon, days, overrides, fert, out)
	else:
		_seasonal(sp, key, lat, lon, days, dorm, overrides, fert, out)
	return out


## A bloom's opening instant (world days): the local opening hour on the
## day `d` falls in.
static func _open_at(sp: PlantSpecies, d: float, lon: float) -> float:
	var h := float(OPEN_HOUR.get(str(_cy(sp, "bloom").get("opens", "evening")), 18.0))
	var local := d + lon / TAU
	return floor(local) + h / 24.0 - lon / TAU


## Did bloom `ev` of this plant set fruit: a real cross seen (overrides),
## else the roll.
static func _sets_fruit(sp: PlantSpecies, key: int, ev: int, overrides: Dictionary, fert: float) -> bool:
	if overrides.has(ev):
		# true/false, or the donor's genome (AroidGarden): pollinated.
		var v = overrides[ev]
		return v is Dictionary or (v is bool and v)
	return _u(key, 25, ev) < pollen_chance(sp) * fert


## Fill the flower channel for a bloom opening at `o` (world days) if
## `days` falls in it; true if it does.
static func _flower(sp: PlantSpecies, key: int, ev: int, o: float, days: float, overrides: Dictionary, fert: float, out: Dictionary) -> bool:
	var bud := _cy(sp, "bud")
	var bl := _cy(sp, "bloom")
	var fr := _cy(sp, "fruit")
	var bud_d := _pick(bud.get("bud_days"), _u(key, 20, ev), Vector2(14, 30))
	var open_d := _pick(bl.get("open_days"), _u(key, 21, ev), Vector2(1, 3))
	var fem_h := _pick(bl.get("female_hours"), _u(key, 22, ev), Vector2(12, 24))
	var male_h := _pick(bl.get("male_after_hours"), _u(key, 23, ev), Vector2(18, 30))
	var ripen := _pick(fr.get("ripen_days"), _u(key, 24, ev), Vector2(60, 120))
	var set := _sets_fruit(sp, key, ev, overrides, fert)
	if days < o - bud_d:
		return false
	var wilt := lerpf(WILT_DAYS.x, WILT_DAYS.y, _u(key, 26, ev))
	var end := o + open_d + (ripen if set else wilt)
	if days >= end:
		return false
	out.event = ev
	out.open_day = o
	out.pollinated = set
	if days < o:
		out.flower = "bud"
		out.flower_t = clampf((days - (o - bud_d)) / bud_d, 0.0, 1.0)
		return true
	var h := (days - o) * 24.0
	out.open_h = h
	if days < o + open_d:
		out.flower = "bloom"
		out.flower_t = (days - o) / open_d
		out.female = h < fem_h
		out.male = h >= male_h
		return true
	if set:
		out.flower = "fruit"
		out.flower_t = clampf((days - o - open_d) / ripen, 0.0, 1.0)
	else:
		out.flower = "wilt"
		out.flower_t = clampf((days - o - open_d) / wilt, 0.0, 1.0)
	return true


## Fill the leaf channel for a leaf coming up at `e` (world days) and
## living `life_d` days; true if `days` falls in it.
static func _leaf(sp: PlantSpecies, key: int, n: int, e: float, life_d: float, days: float, out: Dictionary) -> bool:
	if days < e or days >= e + life_d:
		return false
	var sh := _cy(sp, "shoot")
	var rise := _pick(sh.get("rise_days"), _u(key, 30, n), Vector2(10, 25))
	var unf := _pick(sh.get("unfurl_days"), _u(key, 31, n), Vector2(5, 12))
	var sen := minf(12.0, life_d * 0.1)
	var t := days - e
	if t < rise:
		out.leaf = "shoot"
		out.leaf_t = t / rise
	elif t < rise + unf:
		out.leaf = "unfurl"
		out.leaf_t = (t - rise) / unf
	elif t < life_d - sen:
		out.leaf = "leaf"
		out.leaf_t = (t - rise - unf) / maxf(life_d - sen - rise - unf, 1.0)
	else:
		out.leaf = "senesce"
		out.leaf_t = (t - (life_d - sen)) / sen
	return true


## Seasonal species (dry, cold, evergreen): one flush a year.
static func _seasonal(sp: PlantSpecies, key: int, lat: float, lon: float, days: float, dorm: String, overrides: Dictionary, fert: float, out: Dictionary) -> void:
	var yl := DayCycle.year_days()
	var shift := fposmod(Seasons.year_position(days, lat) / 4.0 - days / yl, 1.0)
	var u := days / yl + shift
	var pl := _plant(sp, key)
	var life := _cy(sp, "life")
	var bl := _cy(sp, "bloom")
	var tub := _cy(sp, "tuber")
	var when := str(bl.get("when", "before_leaf"))
	var then := str(bl.get("then", "leaf"))
	var cur_y := int(floor(u))
	# Which years bloom: the first at first_bloom_years old, then every
	# bloom_every_years (drawn per bloom).
	var birth_y := int(floor(shift - float(pl.age)))
	var slot := _slot(key)
	var bloom_years: Dictionary
	if slot.get("by_year", -99999) == cur_y:
		bloom_years = slot.by
	else:
		bloom_years = {}
		var next := float(birth_y) + float(pl.first)
		var k := 0
		while next <= float(cur_y) + 1.0 and k < 60:
			bloom_years[int(round(next))] = true
			next += maxf(_pick(tub.get("bloom_every_years"), _u(key, 40, k), Vector2(1, 3)), 1.0)
			k += 1
		slot.by_year = cur_y
		slot.by = bloom_years
	out.age_y = u - float(birth_y)
	out.mature = out.age_y >= float(pl.first)
	var sen_leaf := false
	for yy in 3:
		var y: int = cur_y - 1 + yy
		var e_u := float(y) + float(FLUSH.get(dorm, 0.125)) + (_u(key, 5) - 0.5) * 0.04 + (_u(key, 6, y) - 0.5) * 0.02
		var e := (e_u - shift) * yl
		var life_d := _pick(life.get("leaf_days"), _u(key, 7, y), Vector2(150, 210))
		var blooms := bloom_years.has(y) and y >= birth_y
		var leaf_this_year := true
		var leaf_e := e
		if blooms:
			var ev := y
			var bud := _cy(sp, "bud")
			var bud_d := _pick(bud.get("bud_days"), _u(key, 20, ev), Vector2(14, 30))
			var open_d := _pick(bl.get("open_days"), _u(key, 21, ev), Vector2(1, 3))
			var o: float
			match when:
				"with_leaf":
					var rise := _pick(_cy(sp, "shoot").get("rise_days"), _u(key, 30, y), Vector2(10, 25))
					o = e + rise + bud_d
				"after_leaf":
					o = e + life_d
				_:
					if then == "leaf" and when == "before_leaf":
						o = e - open_d - lerpf(GAP_DAYS.x, GAP_DAYS.y, _u(key, 41, y))
					else:
						o = e
			o = _open_at(sp, o, lon)
			if out.flower == "":
				_flower(sp, key, ev, o, days, overrides, fert, out)
			if when == "instead_of_leaf":
				if then == "leaf":
					# The leaf follows the bloom from the same tuber.
					leaf_e = o + open_d + lerpf(GAP_DAYS.x, GAP_DAYS.y, _u(key, 41, y))
				else:
					leaf_this_year = false
			elif then == "rest" and when == "before_leaf":
				leaf_this_year = false
		if dorm == "evergreen":
			# Always in leaf: one leaf replaced by the next.
			out.leaf = "leaf"
			out.leaf_t = fposmod(u, 1.0)
			sen_leaf = true
			continue
		if leaf_this_year and not sen_leaf:
			if _leaf(sp, key, y, leaf_e, life_d, days, out):
				sen_leaf = true


## Everwet species ("cycle": A. titanum): leaf, rest, leaf... on the plant's
## own clock, walked from its birth; blooms in place of (or before) a leaf
## when the tuber is mature.
static func _walk_cycles(sp: PlantSpecies, key: int, _lat: float, lon: float, days: float, overrides: Dictionary, fert: float, out: Dictionary) -> void:
	var yl := DayCycle.year_days()
	var pl := _plant(sp, key)
	var life := _cy(sp, "life")
	var bl := _cy(sp, "bloom")
	var tub := _cy(sp, "tuber")
	var then := str(bl.get("then", "rest"))
	var birth := -float(pl.age) * yl
	var t := birth + _u(key, 8) * 200.0
	var last_bloom := -INF
	var interval := 0.0
	out.age_y = (days - birth) / yl
	out.mature = out.age_y >= float(pl.first)
	var i := 0
	# Carry on from where the last ask got to, if that's not in the future.
	var slot := _slot(key)
	var resume = slot.get("walk")
	if resume is Array and float(resume[0]) <= days:
		t = float(resume[0])
		i = int(resume[1])
		last_bloom = float(resume[2])
		interval = float(resume[3])
	while i < 100000:
		if t <= days:
			slot.walk = [t, i, last_bloom, interval]
		var age_y := (t - birth) / yl
		var blooms := age_y >= float(pl.first) and (t - last_bloom) / yl >= interval
		if blooms:
			var bud_d := _pick(_cy(sp, "bud").get("bud_days"), _u(key, 20, i), Vector2(14, 30))
			var open_d := _pick(bl.get("open_days"), _u(key, 21, i), Vector2(1, 3))
			var o := _open_at(sp, t + bud_d, lon)
			var set := _sets_fruit(sp, key, i, overrides, fert)
			var ripen := _pick(_cy(sp, "fruit").get("ripen_days"), _u(key, 24, i), Vector2(60, 120))
			var wilt := lerpf(WILT_DAYS.x, WILT_DAYS.y, _u(key, 26, i))
			var end := o + open_d + (ripen if set else wilt)
			if days < end:
				_flower(sp, key, i, o, days, overrides, fert, out)
				return
			last_bloom = t
			interval = maxf(_pick(tub.get("bloom_every_years"), _u(key, 40, i), Vector2(2, 6)), 1.0)
			t = end + (lerpf(GAP_DAYS.x, GAP_DAYS.y, _u(key, 41, i)) if then == "leaf" else _pick(life.get("rest_days"), _u(key, 42, i), Vector2(60, 180)))
			if then == "leaf":
				var life_d0 := _pick(life.get("leaf_days"), _u(key, 7, i), Vector2(300, 500))
				if _leaf(sp, key, i, t, life_d0, days, out):
					return
				if days < t:
					return
				t += life_d0 + _pick(life.get("rest_days"), _u(key, 43, i), Vector2(60, 180))
		else:
			var life_d := _pick(life.get("leaf_days"), _u(key, 7, i), Vector2(300, 500))
			if _leaf(sp, key, i, t, life_d, days, out):
				return
			if days < t:
				return
			t += life_d + _pick(life.get("rest_days"), _u(key, 43, i), Vector2(60, 180))
		if t > days:
			return
		i += 1
