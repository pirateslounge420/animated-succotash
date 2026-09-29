class_name PlantGenetics
## Plants' genes, sports and crosses (design 29 Sept 2026; data/sports.json,
## docs/design/AROID_LIFE.md §4-5).
##
## Sports. Any plant can, very rarely, be a sport: a genetic abnormality a
## collector would travel to see (a variegated or golden form, a copper
## beech, a crested cactus, a tetraploid giant, a twin-flowered aroid). Each
## plant is rolled once, from where it grows, so the same plant is the same
## sport on every visit and nothing is stored. Clonal species (offsets,
## stolons, bulbils, suckers: PlantSpecies.clonal) roll per clump, so the
## whole clump is the sport, as in nature. The chance is its shape's rate
## (by_shape); the kind is weighted toward what is documented in its genus
## (by_genus, researched) and, for the Amorphophallus, its species
## (cycle.sports). VegetationPlacer packs the sport into the plant's
## instance data with its moss (moss + 2 x code: encode_moss()), so the
## foliage shader can colour it and LookTarget can name it.
##
## Genomes. An Amorphophallus plant's genes (its species' `genes` ranges:
## size, pattern, scent, allocation; plus vigour and ploidy) come from the
## cross of two notional parents from its local population (a deme: a
## slow noise field over the planet per species and gene), so neighbours
## look related and blends show across a population. A clump shares one
## genome. cross() makes real seedlings from two real plants (AroidGarden,
## when a bloom is pollinated): each gene the parents' mean plus segregation
## noise, rare mutation, sports passed by their inheritance rule, and
## ploidy by the rules in sports.json (2x x 2x -> 2x with the rare
## unreduced gamete giving a 3x or 4x seedling; 2x x 4x -> 3x, nearly
## sterile; an apomictic mother's seed is her clone).
##
## Thread-safe after setup() (VegetationPlacer calls sport_at() on chunk
## workers): setup() runs on the main thread when SpeciesDB loads.

const FILE := "res://data/sports.json"
## Grid cells (m, on the sphere) a plant's key is taken from: one plant,
## or one clump of a clonal species.
const PLANT_CELL_M := 0.3
const CLUMP_CELL_M := 4.0
## A deme's size (m): the scale over which a population's gene means
## drift.
const DEME_M := 20000.0

static var _data := {}
## code -> kind name, and kind name -> its sports.json entry.
static var _by_code := {}
static var _kinds := {}


static func data() -> Dictionary:
	if _data.is_empty():
		if FileAccess.file_exists(FILE):
			var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
			if d is Dictionary:
				_data = d
		if _data.is_empty():
			push_warning("PlantGenetics: %s missing or invalid" % FILE)
			_data = {"kinds": {}, "by_shape": {}, "by_genus": {}}
		_kinds = _data.get("kinds", {})
		for k in _kinds:
			_by_code[int(_kinds[k].get("code", 0))] = k
	return _data


## Each species' sport chance and weighted kinds (main thread, SpeciesDB).
static func setup(all: Array[PlantSpecies]) -> void:
	var d := data()
	var by_shape: Dictionary = d.get("by_shape", {})
	var by_genus: Dictionary = d.get("by_genus", {})
	var w: Dictionary = d.get("weights", {})
	var w_shape := float(w.get("shape", 1.0))
	var w_genus := float(w.get("genus", 6.0))
	var w_species := float(w.get("species", 12.0))
	for sp in all:
		var shape_key := "aroid" if not sp.cycle.is_empty() else String(PlantSpecies.Shape.keys()[sp.shape]).to_lower()
		var entry: Dictionary = by_shape.get(shape_key, {})
		sp.sport_rate = float(entry.get("rate", 0.0))
		var weights := {}
		for k in entry.get("kinds", []):
			weights[k] = w_shape
		for s in by_genus.get(sp.genus, []):
			var k := str(s.get("kind", ""))
			if _kinds.has(k):
				weights[k] = maxf(float(weights.get(k, 0.0)), w_genus)
		for s in sp.cycle.get("sports", []):
			var k := str(s.get("kind", ""))
			if _kinds.has(k):
				weights[k] = maxf(float(weights.get(k, 0.0)), w_species)
		# A documented sport lets a plant sport even if its shape class
		# doesn't (a sport-free shape stays sport-free otherwise).
		if sp.sport_rate <= 0.0 and not weights.is_empty() and shape_key in ["grass", "tussock", "reed"]:
			sp.sport_rate = 1.0 / 8000.0
		var codes := PackedInt32Array()
		var cum := PackedFloat32Array()
		var total := 0.0
		for k in weights:
			total += float(weights[k])
			codes.append(int(_kinds[k].get("code", 0)))
			cum.append(total)
		sp.sport_codes = codes
		sp.sport_cum = cum
		if codes.is_empty():
			sp.sport_rate = 0.0


## A plant's key from its surface direction: its own cell, or its clump's.
static func key_of(sp_name: String, d: Vector3, clonal: bool) -> int:
	var cell_m := CLUMP_CELL_M if clonal else PLANT_CELL_M
	var c := Vector3i((d * (PlanetConst.RADIUS_M / cell_m)).floor())
	return hash([sp_name, c])


## A 0-1 draw from a key and a stream number.
static func unit(key: int, stream: int) -> float:
	return float(hash([key, stream]) & 0xFFFFFF) / 16777216.0


## The sport code of the plant of `sp` growing at `d` (0: none).
## Worker-safe.
static func sport_at(sp: PlantSpecies, d: Vector3) -> int:
	if sp.sport_rate <= 0.0:
		return 0
	var key := key_of(sp.name, d, sp.clonal)
	if unit(key, 101) >= sp.sport_rate:
		return 0
	var pick := unit(key, 102) * sp.sport_cum[sp.sport_cum.size() - 1]
	for i in sp.sport_cum.size():
		if pick <= sp.sport_cum[i]:
			return sp.sport_codes[i]
	return sp.sport_codes[sp.sport_codes.size() - 1]


## The sport's height multiplier (1 for none).
static func size_of(code: int) -> float:
	if code <= 0:
		return 1.0
	data()
	return float(_kinds.get(_by_code.get(code, ""), {}).get("size", 1.0))


## The sport's kind name ("variegated"), or "".
static func kind_of(code: int) -> String:
	if code <= 0:
		return ""
	data()
	return str(_by_code.get(code, ""))


static func code_of(kind: String) -> int:
	data()
	return int(_kinds.get(kind, {}).get("code", 0))


## What the HUD calls it ("variegated", "tetraploid", "crested"), or "".
static func label(code: int) -> String:
	var k := kind_of(code)
	return str(_kinds.get(k, {}).get("label", k)) if k != "" else ""


## The moss value with a sport packed in (the instance data's red
## channel: moss 0-1 + 2 x code), and back.
static func encode_moss(moss: float, code: int) -> float:
	return clampf(moss, 0.0, 1.0) + 2.0 * float(code)


static func decode_sport(r: float) -> int:
	return int(floor(r / 2.0 + 1e-4))


# --- Genomes (the Amorphophallus) ---------------------------------------------

## The genes every aroid genome carries besides its species' own.
const BASE_GENES := ["size", "pattern", "scent", "allocation", "vigour"]


## A value-noise field over the sphere (0-1), per species and gene: the
## deme's mean.
static func _deme(d: Vector3, seed_v: int) -> float:
	var p := d * (PlanetConst.RADIUS_M / DEME_M)
	var c := p.floor()
	var f := p - c
	f = f * f * (Vector3.ONE * 3.0 - 2.0 * f)
	var v := 0.0
	for i in 8:
		var o := Vector3i(i & 1, (i >> 1) & 1, (i >> 2) & 1)
		var h := unit(hash([seed_v, Vector3i(c) + o]), 7)
		var wgt := (f.x if o.x == 1 else 1.0 - f.x) * (f.y if o.y == 1 else 1.0 - f.y) * (f.z if o.z == 1 else 1.0 - f.z)
		v += h * wgt
	return v


## A gene's species range ([lo, hi] from `genes`, else the whole 0-1).
static func _range_of(sp: PlantSpecies, gene: String) -> Vector2:
	var r = sp.gene_ranges.get(gene, null)
	if r is Array and r.size() == 2:
		return Vector2(float(r[0]), float(r[1]))
	return Vector2(0.2, 0.8)


## The species' usual ploidy from its chromosome count (x = 13: 2n 39 is
## a triploid, like A. muelleri's porang; 52 a tetraploid), else 2.
static func base_ploidy(sp: PlantSpecies) -> int:
	var pl = sp.cycle.get("ploidy", {})
	var n2 = pl.get("2n", null) if pl is Dictionary else null
	if n2 is float or n2 is int:
		var n := int(n2)
		if n >= 50:
			return 4
		if n >= 36:
			return 3
	return 2


## The other cytotypes recorded for the species (e.g. konjac's rare
## triploids): ploidies a wild plant can also have.
static func other_ploidies(sp: PlantSpecies) -> PackedInt32Array:
	var out := PackedInt32Array()
	var base := base_ploidy(sp)
	var pl = sp.cycle.get("ploidy", {})
	for c in (pl.get("cytotypes", []) if pl is Dictionary else []):
		var p := int(str(c).trim_suffix("x")) if str(c).ends_with("x") else 0
		if p >= 2 and p != base:
			out.append(p)
	return out


## The genome of the wild plant (or clump) `key` of `sp` at `d`: each gene
## the mean of two notional parents drawn round its deme, plus a little
## segregation noise; its sport and ploidy. {"genes": {name: 0-1},
## "ploidy": 2/3/4, "sport": code, "key": key}.
static func wild_genome(sp: PlantSpecies, key: int, d: Vector3, sport: int) -> Dictionary:
	var genes := {}
	var names: Array = BASE_GENES.duplicate()
	for g in sp.gene_ranges:
		if not names.has(g):
			names.append(g)
	for gi in names.size():
		var g: String = names[gi]
		var r := _range_of(sp, g)
		var mean := lerpf(r.x, r.y, _deme(d, hash([sp.name, g])))
		var spread := (r.y - r.x) * 0.25
		var p1 := mean + (unit(key, 200 + gi * 3) - 0.5) * 2.0 * spread
		var p2 := mean + (unit(key, 201 + gi * 3) - 0.5) * 2.0 * spread
		var seg := (unit(key, 202 + gi * 3) - 0.5) * 0.08
		genes[g] = clampf((p1 + p2) * 0.5 + seg, 0.0, 1.0)
	var ploidy := base_ploidy(sp)
	# A mixed species (konjac, muelleri): now and then a wild plant of its
	# other recorded cytotype.
	var others := other_ploidies(sp)
	if not others.is_empty() and unit(key, 300) < 0.08:
		ploidy = others[int(unit(key, 301) * others.size()) % others.size()]
	if sport == code_of("polyploid"):
		ploidy = 4 if ploidy == 2 else ploidy + 1
	return {"genes": genes, "ploidy": ploidy, "sport": sport, "key": key}


## Seed set when these two are the parents (0-1 share of normal).
static func fertility(a: Dictionary, b: Dictionary) -> float:
	var pl: Dictionary = data().get("ploidy", {})
	var f := 1.0
	for g in [a, b]:
		var k := kind_of(int(g.get("sport", 0)))
		f *= float(_kinds.get(k, {}).get("fertility", 1.0)) if k != "polyploid" else 1.0
		if int(g.get("ploidy", 2)) == 3:
			f *= float(pl.get("triploid_fertility", 0.05))
	var pa := int(a.get("ploidy", 2))
	var pb := int(b.get("ploidy", 2))
	if pa != pb and pa + pb == 6:
		f *= float(pl.get("triploid_fertility", 0.05))
	elif pa == 4 and pb == 4:
		f *= float(pl.get("tetraploid_fertility", 0.5))
	return clampf(f, 0.0, 1.0)


## One seedling of mother `a` x father `b` (genomes), drawn with `rng`:
## genes the parents' mean plus segregation noise and a rare mutation;
## ploidy by the rules; each parent's sport passed by its inheritance
## rule; `apomictic` mothers give their own clone.
static func cross(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator, apomictic := false) -> Dictionary:
	if apomictic:
		var c := a.duplicate(true)
		c["parents"] = "apomictic clone"
		return c
	var ga: Dictionary = a.get("genes", {})
	var gb: Dictionary = b.get("genes", {})
	var genes := {}
	for g in ga:
		var v := (float(ga[g]) + float(gb.get(g, ga[g]))) * 0.5 + rng.randfn(0.0, 0.07)
		if rng.randf() < 0.01:
			v = rng.randf()
		genes[g] = clampf(v, 0.0, 1.0)
	var pl: Dictionary = data().get("ploidy", {})
	var pa := int(a.get("ploidy", 2))
	var pb := int(b.get("ploidy", 2))
	var ploidy := 2
	if pa == 4 and pb == 4:
		ploidy = 4
	elif (pa == 4 and pb == 2) or (pa == 2 and pb == 4):
		ploidy = 3
	elif pa == 3 or pb == 3:
		ploidy = 2 + (1 if rng.randf() < 0.3 else 0)
	else:
		var u := rng.randf()
		var unreduced := float(pl.get("unreduced", 0.005))
		ploidy = 4 if u < unreduced * 0.25 else (3 if u < unreduced else 2)
	var sport := 0
	for parent in [a, b]:
		var code := int(parent.get("sport", 0))
		var k := kind_of(code)
		if k == "" or k == "polyploid":
			continue
		var e: Dictionary = _kinds.get(k, {})
		var share := float(e.get("seed_share", 0.5))
		if str(e.get("inherit", "seed")) == "recessive" and int(a.get("sport", 0)) == code and int(b.get("sport", 0)) == code:
			share = 1.0
		if rng.randf() < share:
			sport = code
	if ploidy == 4:
		sport = code_of("polyploid") if sport == 0 else sport
	return {"genes": genes, "ploidy": ploidy, "sport": sport, "key": rng.randi(),
		"parents": "%s x %s" % [describe(a), describe(b)]}


## A genome in a few words: "tetraploid variegated", "diploid".
static func describe(g: Dictionary) -> String:
	var words := PackedStringArray()
	match int(g.get("ploidy", 2)):
		3:
			words.append("triploid")
		4:
			words.append("tetraploid")
		_:
			words.append("diploid")
	var s := int(g.get("sport", 0))
	if s > 0 and kind_of(s) != "polyploid":
		words.append(label(s))
	return " ".join(words)
