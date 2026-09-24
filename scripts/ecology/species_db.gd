class_name SpeciesDB
## All plant species, loaded from the biome data files in data/biomes/
## (one per biome template; see the README there). Each plant entry needs
## only a name; any field it leaves out comes from its biome's `climate`
## block or from defaults for its tier. A plant listed in several biome
## files gets the union of those biomes' climates.
##
## Temperatures are °C (mean annual; the planet has no seasons). Moisture
## is ClimatePass's 0-1 effective moisture.
##
## Call all() once on the main thread before worker threads use it.

const DATA_DIR := "res://data/biomes"

const TIER_NAMES := {"emergent": 0, "canopy": 1, "shrub": 2, "ground": 3, "epiphyte": 4}
const SOILS := {
	"rich": {PlanetData.Rock.BASALT_VOLCANIC: 1.0, PlanetData.Rock.ALLUVIAL: 1.0, PlanetData.Rock.GRANITE: 0.8,
		PlanetData.Rock.GLACIAL_TILL: 0.75, PlanetData.Rock.LIMESTONE_KARST: 0.55, PlanetData.Rock.SANDSTONE: 0.5,
		PlanetData.Rock.COASTAL_SAND: 0.25, PlanetData.Rock.CLAY_PEAT: 0.35},
	"thin": {PlanetData.Rock.LIMESTONE_KARST: 1.0, PlanetData.Rock.SANDSTONE: 0.9, PlanetData.Rock.GRANITE: 0.8,
		PlanetData.Rock.COASTAL_SAND: 0.5, PlanetData.Rock.BASALT_VOLCANIC: 0.7, PlanetData.Rock.ALLUVIAL: 0.5,
		PlanetData.Rock.CLAY_PEAT: 0.1, PlanetData.Rock.GLACIAL_TILL: 0.6},
	"peat": {PlanetData.Rock.CLAY_PEAT: 1.0, PlanetData.Rock.GLACIAL_TILL: 0.6, PlanetData.Rock.ALLUVIAL: 0.5,
		PlanetData.Rock.GRANITE: 0.25, PlanetData.Rock.BASALT_VOLCANIC: 0.25, PlanetData.Rock.LIMESTONE_KARST: 0.2,
		PlanetData.Rock.SANDSTONE: 0.1, PlanetData.Rock.COASTAL_SAND: 0.1},
	"sand": {PlanetData.Rock.COASTAL_SAND: 1.0, PlanetData.Rock.SANDSTONE: 0.3, PlanetData.Rock.ALLUVIAL: 0.2},
	"wet": {PlanetData.Rock.ALLUVIAL: 1.0, PlanetData.Rock.CLAY_PEAT: 0.9, PlanetData.Rock.COASTAL_SAND: 0.6,
		PlanetData.Rock.BASALT_VOLCANIC: 0.7, PlanetData.Rock.GRANITE: 0.5, PlanetData.Rock.GLACIAL_TILL: 0.6,
		PlanetData.Rock.LIMESTONE_KARST: 0.4, PlanetData.Rock.SANDSTONE: 0.4},
	"volcanic": {PlanetData.Rock.BASALT_VOLCANIC: 1.0},
}
## Soil factor for rocks a preset doesn't mention.
const SOIL_DEFAULTS := {"rich": 0.6, "thin": 0.6, "peat": 0.2, "sand": 0.0, "wet": 0.5, "volcanic": 0.05}
const NEEDS := {
	"standing_water": PlantSpecies.Needs.STANDING_WATER,
	"river_bank": PlantSpecies.Needs.RIVER_BANK,
	"salt_water": PlantSpecies.Needs.SALT_WATER,
	"hot_ground": PlantSpecies.Needs.HOT_GROUND,
	"dry_ground": PlantSpecies.Needs.DRY_GROUND,
}
const TIER_DEFAULTS := {
	0: {"shape": PlantSpecies.Shape.EMERGENT, "height": Vector2(35, 50), "color": Color(0.12, 0.42, 0.18)},
	1: {"shape": PlantSpecies.Shape.BROADLEAF, "height": Vector2(10, 22), "color": Color(0.2, 0.45, 0.2)},
	2: {"shape": PlantSpecies.Shape.SHRUB, "height": Vector2(1, 3), "color": Color(0.28, 0.48, 0.22)},
	3: {"shape": PlantSpecies.Shape.GRASS, "height": Vector2(0.2, 0.6), "color": Color(0.45, 0.6, 0.3)},
	4: {"shape": PlantSpecies.Shape.EPIPHYTE_CLUMP, "height": Vector2(0.3, 0.8), "color": Color(0.3, 0.5, 0.25)},
}

static var _all: Array[PlantSpecies] = []
static var _by_tier := {}
static var _index := {}
## Per biome key: file status and plant count, for tools and the HUD.
static var biome_status := {}


static func all() -> Array[PlantSpecies]:
	if _all.is_empty():
		_load()
	return _all


static func by_tier(tier: int) -> Array[PlantSpecies]:
	all()
	return _by_tier.get(tier, [] as Array[PlantSpecies])


static func index_of(sp: PlantSpecies) -> int:
	return _index.get(sp, -1)


static func find(p_name: String) -> PlantSpecies:
	for sp in all():
		if sp.name == p_name:
			return sp
	return null


static func _load() -> void:
	var by_name := {}
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_error("SpeciesDB: can't open %s" % DATA_DIR)
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if f.ends_with(".json"):
			_load_file(DATA_DIR + "/" + f, by_name)
	for i in _all.size():
		_index[_all[i]] = i
		var t := _all[i].tier
		if not _by_tier.has(t):
			_by_tier[t] = [] as Array[PlantSpecies]
		_by_tier[t].append(_all[i])


static func _load_file(path: String, by_name: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(path)
	var doc = JSON.parse_string(text)
	if typeof(doc) != TYPE_DICTIONARY:
		push_warning("SpeciesDB: %s is not valid JSON, skipped" % path)
		return
	var key: String = doc.get("key", "")
	if BiomeTemplates.id_of_key(key) < 0:
		push_warning("SpeciesDB: %s has unknown biome key '%s'" % [path, key])
	var climate: Dictionary = doc.get("climate", {})
	var plants: Dictionary = doc.get("plants", {})
	var count := 0
	for tier_name in plants:
		if not TIER_NAMES.has(tier_name):
			push_warning("SpeciesDB: %s: unknown tier '%s' (use emergent, canopy, shrub, ground, epiphyte)" % [path, tier_name])
			continue
		for entry in plants[tier_name]:
			if typeof(entry) == TYPE_STRING:
				entry = {"name": entry}
			if typeof(entry) != TYPE_DICTIONARY or not entry.has("name"):
				push_warning("SpeciesDB: %s: a %s entry has no name, skipped" % [path, tier_name])
				continue
			_add_entry(entry, TIER_NAMES[tier_name], climate, path, by_name)
			count += 1
	biome_status[key] = {"status": doc.get("status", ""), "plants": count, "file": path}


static func _add_entry(e: Dictionary, tier: int, climate: Dictionary, path: String, by_name: Dictionary) -> void:
	var p_name: String = e.name
	var t := _range(e.get("temp_c", climate.get("temp_c")), Vector2(-50, 50))
	var m := _range(e.get("moisture", climate.get("moisture")), Vector2(0, 1))
	var alt := _range(e.get("altitude_m", climate.get("altitude_m")), Vector2(-INF, INF))
	# Hard limits of the scales are inclusive: widen them slightly so the
	# band's zero edge sits just outside them.
	if m.x <= 0.0:
		m.x = -0.05
	if m.y >= 1.0:
		m.y = 1.05

	if by_name.has(p_name):
		# Seen in another biome file: widen its range to cover this one too.
		var sp: PlantSpecies = by_name[p_name]
		sp.temp_c = Vector2(minf(sp.temp_c.x, t.x), maxf(sp.temp_c.y, t.y))
		sp.moisture = Vector2(minf(sp.moisture.x, m.x), maxf(sp.moisture.y, m.y))
		sp.altitude_m = Vector2(minf(sp.altitude_m.x, alt.x), maxf(sp.altitude_m.y, alt.y))
		return

	var d: Dictionary = TIER_DEFAULTS[tier]
	var sp := PlantSpecies.new()
	sp.name = p_name
	sp.tier = tier
	sp.temp_c = t
	sp.moisture = m
	sp.altitude_m = alt
	var shape_name: String = e.get("shape", "")
	sp.shape = d.shape
	if shape_name != "":
		var s := PlantSpecies.Shape.keys().find(shape_name.to_upper())
		if s < 0:
			push_warning("SpeciesDB: %s: '%s' has unknown shape '%s', using default" % [path, p_name, shape_name])
		else:
			sp.shape = s
	sp.height_m = _range(e.get("height_m"), d.height)
	sp.density = float(e.get("density", 1.0))
	var soil: String = e.get("soil", "rich")
	if not SOILS.has(soil):
		push_warning("SpeciesDB: %s: '%s' has unknown soil '%s', using rich" % [path, p_name, soil])
		soil = "rich"
	sp.soils = (SOILS[soil] as Dictionary).duplicate(true) # own copy: see BiomeTemplates._names
	sp.soil_default = SOIL_DEFAULTS[soil]
	for need in e.get("needs", []):
		if NEEDS.has(need):
			sp.needs.append(NEEDS[need])
		else:
			push_warning("SpeciesDB: %s: '%s' has unknown need '%s'" % [path, p_name, need])
	sp.water_depth_m = _range(e.get("water_depth_m"), Vector2(0.05, 1.5))
	sp.color = Color.from_string(e.get("color", ""), d.color)
	sp.accent = Color.from_string(e.get("accent", ""), Color(0.36, 0.26, 0.18))
	sp.source = e.get("source", "")
	by_name[p_name] = sp
	_all.append(sp)


static func _range(v, fallback: Vector2) -> Vector2:
	if typeof(v) == TYPE_ARRAY and v.size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback
