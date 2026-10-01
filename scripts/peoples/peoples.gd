class_name Peoples
## Peoples (design 30 Sept §BO, data/peoples/): a people is a way of
## life, not a nation. Seventeen lives, one file each; biome_map.json
## says which life a site lives (site_rules tried in order, then by
## biome); the biome dresses it (each file's dressing.by_biome). This is
## the loader and the picker; CampProps dresses, CampSim runs the camp.

const DIR := "res://data/peoples/"
static var _files := {}
static var _map := {}
static var _kinds := {}

## Words the palettes are written in, to colours (the first word of a
## palette entry that matches wins; unmatched words are mid grey).
const WORDS := {
	"grey": Color(0.5, 0.5, 0.52), "gray": Color(0.5, 0.5, 0.52), "slate": Color(0.36, 0.4, 0.46),
	"green": Color(0.3, 0.5, 0.28), "kelp": Color(0.25, 0.42, 0.28), "moss": Color(0.36, 0.5, 0.26),
	"white": Color(0.9, 0.9, 0.86), "gull": Color(0.92, 0.92, 0.9), "snow": Color(0.92, 0.94, 0.98), "salt": Color(0.9, 0.88, 0.84),
	"sand": Color(0.82, 0.74, 0.55), "buff": Color(0.78, 0.68, 0.5), "straw": Color(0.8, 0.7, 0.4), "thatch": Color(0.72, 0.6, 0.34),
	"gold": Color(0.78, 0.62, 0.25), "honey": Color(0.85, 0.65, 0.25), "reed": Color(0.7, 0.6, 0.32), "hazel": Color(0.7, 0.58, 0.3),
	"red": Color(0.6, 0.25, 0.18), "ochre": Color(0.7, 0.42, 0.2), "ember": Color(0.9, 0.35, 0.1), "orange": Color(0.9, 0.5, 0.15), "annatto": Color(0.75, 0.3, 0.15), "terra": Color(0.6, 0.3, 0.2),
	"brown": Color(0.42, 0.3, 0.2), "bark": Color(0.4, 0.32, 0.24), "rattan": Color(0.55, 0.4, 0.22), "silt": Color(0.5, 0.42, 0.3), "driftwood": Color(0.6, 0.56, 0.5), "dun": Color(0.55, 0.45, 0.32), "hide": Color(0.5, 0.4, 0.28), "root": Color(0.5, 0.28, 0.2),
	"black": Color(0.12, 0.11, 0.1), "charcoal": Color(0.15, 0.14, 0.14), "soot": Color(0.1, 0.1, 0.1), "peat": Color(0.2, 0.15, 0.1), "obsidian": Color(0.08, 0.08, 0.1), "seal": Color(0.15, 0.15, 0.17),
	"blue": Color(0.3, 0.45, 0.7), "sky": Color(0.55, 0.7, 0.9), "turquoise": Color(0.2, 0.6, 0.6), "water": Color(0.35, 0.45, 0.5),
	"clay": Color(0.7, 0.45, 0.3), "fired": Color(0.7, 0.4, 0.28), "limestone": Color(0.72, 0.7, 0.62), "lime": Color(0.86, 0.86, 0.8), "whitewash": Color(0.9, 0.9, 0.86), "stone": Color(0.5, 0.5, 0.48), "ivory": Color(0.88, 0.84, 0.7), "whalebone": Color(0.85, 0.82, 0.7),
	"birch": Color(0.88, 0.86, 0.8), "spruce": Color(0.18, 0.3, 0.22), "larch": Color(0.75, 0.6, 0.25), "oak": Color(0.4, 0.45, 0.25), "fig": Color(0.3, 0.5, 0.25), "willow": Color(0.55, 0.6, 0.4), "acacia": Color(0.45, 0.55, 0.3), "mesquite": Color(0.4, 0.5, 0.3), "meadow": Color(0.45, 0.6, 0.3), "nipa": Color(0.35, 0.5, 0.3), "sphagnum": Color(0.6, 0.35, 0.3), "lichen": Color(0.65, 0.68, 0.55), "wet": Color(0.3, 0.45, 0.3),
	"smoke": Color(0.55, 0.55, 0.55), "ash": Color(0.6, 0.6, 0.58), "iron": Color(0.5, 0.3, 0.2), "tannin": Color(0.4, 0.3, 0.18), "oyster": Color(0.6, 0.6, 0.58), "lamp": Color(0.9, 0.75, 0.4), "tola": Color(0.5, 0.55, 0.45), "woven": Color(0.55, 0.35, 0.25),
}


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func map_data() -> Dictionary:
	if _map.is_empty():
		_map = _load_json(DIR + "biome_map.json")
	return _map


static func kinds() -> Dictionary:
	if _kinds.is_empty():
		_kinds = _load_json(DIR + "folk_kinds.json").get("kinds", {})
	return _kinds


static func ids() -> Array:
	return map_data().get("lives", [])


## A people file by id ({} if none).
static func get_people(id: String) -> Dictionary:
	if id == "":
		return {}
	if not _files.has(id):
		_files[id] = _load_json(DIR + id + ".json")
	return _files[id]


## The way of life a site lives (biome_map.json site_rules, in order,
## then by_biome). `site_kind`: "cliff" for a rock-shelter camp, "ruin",
## "opening", "" otherwise.
static func pick(map: PlanetData, rivers: RiverNetwork, d: Vector3, site_kind := "") -> String:
	if map == null or map.biome.is_empty():
		return "old_growth"
	var cell := map.cell_at(d)
	var biome: int = map.biome[cell]
	var key: String = BiomeTemplates.KEYS[biome] if biome >= 0 and biome < BiomeTemplates.KEYS.size() else ""
	var md := map_data()
	for rule in md.get("site_rules", []):
		var id := str(rule.get("id", ""))
		var ok := false
		match id:
			"rock_shelter":
				ok = site_kind == "cliff" or key == "CAVES"
			"karst":
				ok = int(map.rock[cell]) == PlanetData.Rock.LIMESTONE_KARST and _unit(d, "karst") < 0.5
			"canopy":
				ok = key in ["TEMPERATE_RAINFOREST", "TROPICAL_RAINFOREST", "JUNGLE", "CLOUD_FOREST", "TEMPERATE_DECIDUOUS"] and _unit(d, "canopy") < 1.0 / 6.0
			"mangrove":
				ok = key == "MANGROVE"
			"coast":
				ok = map.coast_dist_km[cell] <= 0.3 and key != "MANGROVE"
			"lake":
				ok = key == "LAGOON" or _lake_near(map, cell)
			"marsh":
				ok = key in ["SWAMP", "BOG", "FEN", "FRESHWATER_MARSH", "WET_MEADOW"]
			"river":
				ok = rivers != null and _river_near(map, rivers, d, cell)
			"by_biome":
				ok = true
		if not ok:
			continue
		var people := str(rule.get("people", ""))
		if people == "by_biome":
			var by = (md.get("by_biome", {}) as Dictionary).get(key, null)
			if by == null:
				return _fallback(key)
			return str(by)
		return people
	return "old_growth"


static func _unit(d: Vector3, salt: String) -> float:
	return float(posmod(hash([Vector3i((d * 1.0e5).round()), salt]), 100000)) / 100000.0


static func _lake_near(map: PlanetData, cell: int) -> bool:
	if map.water[cell] == PlanetData.Water.LAKE:
		return true
	for k in 8:
		var n := map.neighbors[cell * 8 + k]
		if n >= 0 and map.water[n] == PlanetData.Water.LAKE and map.water_dist_km[cell] * 1000.0 <= 200.0 * PlanetConst.GEO_SCALE:
			return true
	return false


static func _river_near(map: PlanetData, rivers: RiverNetwork, d: Vector3, cell: int) -> bool:
	for s in rivers.segments_near(map, cell):
		var dt := rivers.closest_dt(s, d)
		if dt.x <= 200.0 and rivers.width[s] >= 10.0:
			return true
	return false


## Where the table says nobody lives (ice, the open sea): the nearest
## sensible life for a ruin that is there anyway.
static func _fallback(key: String) -> String:
	if key in ["ICE_SHEET", "GLACIER", "SEA_ICE"]:
		return "tundra"
	return "coast"


## The people's dressing for this biome ({} when the file has none).
static func dressing(people: Dictionary, biome_key: String) -> Dictionary:
	var by: Dictionary = (people.get("dressing", {}) as Dictionary).get("by_biome", {})
	return by.get(biome_key, {})


## The palette as colours: the dressing's palette line if it has one,
## else the file's palette list.
static func palette(people: Dictionary, biome_key: String) -> Array:
	var words: Array = []
	var dr := dressing(people, biome_key)
	if dr.has("palette"):
		for w in str(dr.palette).split(","):
			words.append(w.strip_edges())
	else:
		words = (people.get("aesthetic", {}) as Dictionary).get("palette", [])
	var out: Array = []
	for w in words:
		out.append(color_of(str(w)))
	if out.is_empty():
		out = [Color(0.5, 0.45, 0.35), Color(0.4, 0.4, 0.4)]
	return out


## A colour from a palette phrase ("kelp green", "driftwood grey").
static func color_of(phrase: String) -> Color:
	var best := Color(0.5, 0.5, 0.5)
	var found := false
	for w in phrase.to_lower().replace("-", " ").split(" "):
		if WORDS.has(w):
			if not found:
				best = WORDS[w]
				found = true
			else:
				best = best.lerp(WORDS[w], 0.4)
	return best


## The folk kind a camp of this people wears (its file's first kind, the
## seed picking another now and then), and the rig's scale for it
## (folk_kinds.json silhouette "folk_scale 0.75").
static func folk_kind(people: Dictionary, seed_value: int) -> String:
	var ks: Array = people.get("folk_kinds", ["human"])
	if ks.is_empty():
		return "human"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "kind"])
	return str(ks[0]) if ks.size() == 1 or rng.randf() < 0.6 else str(ks[rng.randi_range(1, ks.size() - 1)])


static func folk_scale(kind: String) -> float:
	var row: Dictionary = kinds().get(kind, {})
	var sil := str(row.get("silhouette", ""))
	var i := sil.find("folk_scale")
	if i >= 0:
		var rest := sil.substr(i + 10).strip_edges()
		var num := ""
		for ch in rest:
			if ch == "." or (ch >= "0" and ch <= "9"):
				num += ch
			else:
				break
		if num.is_valid_float():
			return float(num)
	return 1.0


## The people's fuel kinds (fuel.json kinds it gathers).
static func fuel_kinds(people: Dictionary) -> Array:
	return (people.get("fuel", {}) as Dictionary).get("kinds", ["branch"])


static func name_of(people: Dictionary) -> String:
	return str(people.get("name", "Folk"))
