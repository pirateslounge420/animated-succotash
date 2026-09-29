class_name SpeciesDB
## All plant species, loaded from the biome data files in data/biomes/
## (one per biome template; see the README there) and, directly, from the
## genus catalogues in data/plants/ (design §AA). Each biome plant entry
## needs only a name; any field it leaves out comes from its biome's
## `climate` block or from defaults for its tier. A plant listed in several
## files gets the union of those climates. Catalogue entries carry their
## own bands, and their `realm` (a name or a list): the realm gate
## (RealmMap) lets them grow only where the place's realm is theirs and the
## place's biome has an association for that realm; an entry with no realm
## yet doesn't grow (UNASSIGNED) until it's tagged. A catalogue entry whose
## name is already a biome plant (an old copy) only tags that plant with its
## realm; the copy's bands and needs stand.
##
## Each biome file's associations carry a `realm` (or a list, or "any"):
## realms_of_biome() is which realms that biome hosts.
##
## Temperatures are °C (mean annual; the planet has no seasons). Moisture
## is ClimatePass's 0-1 effective moisture.
##
## Call all() once on the main thread before worker threads use it.

const DATA_DIR := "res://data/biomes"
const CATALOGUE_DIR := "res://data/plants"
## The per-species tiles' index (design §AH).
const ATLAS_PATH := "res://assets/textures/plants/species/atlas_species.json"
## The realm of a catalogue entry that has none yet: no place has it.
const UNASSIGNED := "unassigned"

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
static var _presets := {}


## data/soil.json "presets": soil preset name -> allowed class names.
static func _soil_presets() -> Dictionary:
	if _presets.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/soil.json")) if FileAccess.file_exists("res://data/soil.json") else null
		_presets = parsed.get("presets", {}) if parsed is Dictionary else {}
		if _presets.is_empty():
			push_warning("SpeciesDB: data/soil.json has no presets; every soil allowed")
			_presets = {"_": []}
	return _presets


## Class names -> bits (1 << PlanetData.Rock); unknown names warn.
static func _soil_mask(names, path: String, p_name: String) -> int:
	var mask := 0
	for n in names:
		var r := PlanetData.SOIL_NAMES.find(str(n))
		if r < 0:
			push_warning("SpeciesDB: %s: '%s' has unknown soil class '%s'" % [path, p_name, n])
		else:
			mask |= 1 << r
	return mask if mask != 0 else 0xFF


const NEEDS := {
	"standing_water": PlantSpecies.Needs.STANDING_WATER,
	"river_bank": PlantSpecies.Needs.RIVER_BANK,
	"salt_water": PlantSpecies.Needs.SALT_WATER,
	"hot_ground": PlantSpecies.Needs.HOT_GROUND,
	"dry_ground": PlantSpecies.Needs.DRY_GROUND,
	"forest_floor": PlantSpecies.Needs.FOREST_FLOOR,
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
## BiomeTemplates id -> the realms its associations are tagged with
## (PackedStringArray; "any" among them admits every realm).
static var _biome_realms := {}


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
	# NO_CATALOGUES=1 (dev, measuring): the biome files only.
	var cat := DirAccess.open(CATALOGUE_DIR) if OS.get_environment("NO_CATALOGUES") != "1" else null
	if cat != null:
		var cfiles := cat.get_files()
		cfiles.sort()
		for f in cfiles:
			if f.ends_with(".json"):
				_load_catalogue(CATALOGUE_DIR + "/" + f, by_name)
	_load_atlas(by_name)
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
	var realms := PackedStringArray()
	for a in doc.get("associations", []):
		if a is Dictionary:
			for r in _realm_list(a.get("realm", "")):
				if not realms.has(r):
					realms.append(r)
	var id := BiomeTemplates.id_of_key(key)
	if id >= 0:
		_biome_realms[id] = realms


## A genus catalogue (data/plants/): entries by tier with their own bands,
## realm and needs (no biome climate to fall back on).
static func _load_catalogue(path: String, by_name: Dictionary) -> void:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(doc) != TYPE_DICTIONARY:
		push_warning("SpeciesDB: %s is not valid JSON, skipped" % path)
		return
	var plants: Dictionary = doc.get("plants", {})
	# Needs every entry of the catalogue shares (family_defaults.needs).
	var fd = doc.get("family_defaults", {})
	var shared_needs: Array = fd.get("needs", []) if fd is Dictionary else []
	for tier_name in plants:
		if not TIER_NAMES.has(tier_name):
			push_warning("SpeciesDB: %s: unknown tier '%s'" % [path, tier_name])
			continue
		for entry in plants[tier_name]:
			if typeof(entry) != TYPE_DICTIONARY or not entry.has("name"):
				continue
			var had: bool = by_name.has(entry.name)
			if not had:
				_add_entry(entry, TIER_NAMES[tier_name], {}, path, by_name)
			# An old biome copy of this entry keeps its biome bands and needs
			# (the copies stay authoritative until the designer removes
			# them, design §AA 1); it only takes the catalogue's realm.
			var sp: PlantSpecies = by_name[entry.name]
			sp.from_catalogue = sp.from_catalogue or not had
			var realms := _realm_list(entry.get("realm", ""))
			for r in realms:
				if r != "any" and not sp.realms.has(r):
					sp.realms.append(r)
			if realms.is_empty() and not had:
				# No realm yet: the gate can't pass (design §AA), so it
				# waits for its tag (an old biome copy keeps growing as
				# its biome file says).
				sp.realms.append(UNASSIGNED)
			# The catalogue's shared needs (its own came with _add_entry).
			for need in (shared_needs if not had else []):
				if NEEDS.has(need) and not sp.needs.has(NEEDS[need]):
					sp.needs.append(NEEDS[need])
				elif not NEEDS.has(need):
					push_warning("SpeciesDB: %s: unknown need '%s'" % [path, need])


## The per-species tiles (design §AH): each species named in the atlas
## records its files; the rest keep the class textures.
static func _load_atlas(by_name: Dictionary) -> void:
	if not FileAccess.file_exists(ATLAS_PATH):
		return
	var doc = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_PATH))
	if typeof(doc) != TYPE_DICTIONARY:
		push_warning("SpeciesDB: %s is not valid JSON, skipped" % ATLAS_PATH)
		return
	var dir := ATLAS_PATH.get_base_dir()
	var species: Dictionary = doc.get("species", {})
	for p_name in species:
		var sp: PlantSpecies = by_name.get(p_name)
		var e = species[p_name]
		if sp == null or not e is Dictionary:
			continue
		for kind in ["leaf", "leaf_autumn", "leaves", "litter", "bark", "petiole"]:
			if e.get(kind) is String:
				sp.tiles[kind] = dir + "/" + str(e[kind])
		sp.leaf_color = Color.from_string(str(e.get("leaf_color", "")), sp.leaf_color)
		sp.bark_tile_m = float(e.get("bark_tile_m", 0.4))
		if sp.leaf_type == "":
			sp.leaf_type = str(e.get("leaf_type", ""))


## "x", ["x", "y"] or nothing -> the realm names.
static func _realm_list(v) -> PackedStringArray:
	var out := PackedStringArray()
	if v is String:
		if v != "":
			out.append(v)
	elif v is Array:
		for r in v:
			out.append(str(r))
	return out


## The realms biome `id`'s associations are tagged with ("any" among them
## admits every realm); empty if it has none.
static func realms_of_biome(id: int) -> PackedStringArray:
	all()
	return _biome_realms.get(id, PackedStringArray())


## Does biome `id` host realm `realm` (an association tagged with it, or
## with "any")?
static func biome_hosts(id: int, realm: String) -> bool:
	var rs := realms_of_biome(id)
	return rs.has(realm) or rs.has("any")


static func _add_entry(e: Dictionary, tier: int, climate: Dictionary, path: String, by_name: Dictionary) -> void:
	var p_name: String = e.name
	var t := _range(e.get("temp_c", climate.get("temp_c")), Vector2(-50, 50))
	var m := _range(e.get("moisture", climate.get("moisture")), Vector2(0, 1))
	# Altitude bands are real-world meters in the data; scale to this world.
	var alt := _range(e.get("altitude_m", climate.get("altitude_m")), Vector2(-INF, INF)) * PlanetConst.HEIGHT_SCALE
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
	# Soil: a preset name (the older data: its preference weights, and the
	# classes data/soil.json allows it) or the schema's block {"classes":
	# [...]} (those classes, equally). Either way the classes are a hard
	# gate (PlantSpecies.soil_mask).
	var soil_v = e.get("soil", "rich")
	if soil_v is Dictionary and (soil_v as Dictionary).has("classes"):
		sp.soils = {}
		sp.soil_default = 0.0
		sp.soil_mask = _soil_mask(soil_v.classes, path, p_name)
		for r in PlanetData.SOIL_NAMES.size():
			if (sp.soil_mask >> r) & 1:
				sp.soils[r] = 1.0
	else:
		var soil := str(soil_v)
		if not SOILS.has(soil):
			push_warning("SpeciesDB: %s: '%s' has unknown soil '%s', using rich" % [path, p_name, soil])
			soil = "rich"
		sp.soils = (SOILS[soil] as Dictionary).duplicate(true) # own copy: see BiomeTemplates._names
		sp.soil_default = SOIL_DEFAULTS[soil]
		sp.soil_mask = _soil_mask(_soil_presets().get(soil, PlanetData.SOIL_NAMES), path, p_name)
	for need in e.get("needs", []):
		if NEEDS.has(need):
			sp.needs.append(NEEDS[need])
		else:
			push_warning("SpeciesDB: %s: '%s' has unknown need '%s'" % [path, p_name, need])
	sp.water_depth_m = _range(e.get("water_depth_m"), Vector2(0.05, 1.5))
	sp.color = Color.from_string(e.get("color", ""), d.color)
	sp.accent = Color.from_string(e.get("accent", ""), Color(0.36, 0.26, 0.18))
	sp.source = e.get("source", "")
	sp.genus = str(e.get("genus", ""))
	sp.species = str(e.get("species", ""))
	sp.leaf_density = clampf(float(e.get("leaf_density", -1.0)), -1.0, 1.0)
	var lf = e.get("leaf", {})
	if lf is Dictionary:
		var size = lf.get("size_cm", [])
		if size is Array and size.size() == 2:
			sp.leaf_m = (float(size[0]) + float(size[1])) * 0.005
		sp.leaf_type = str(lf.get("type", ""))
		sp.leaf_texture = str(lf.get("texture", ""))
	var tint = e.get("tint", {})
	if tint is Dictionary:
		sp.deciduous = bool(tint.get("drop", false))
		sp.autumn_color = Color.from_string(str(tint.get("autumn", "")), sp.autumn_color)
	var hh = e.get("handhold", {})
	sp.handhold = hh if hh is Dictionary else {}
	by_name[p_name] = sp
	_all.append(sp)


static func _range(v, fallback: Vector2) -> Vector2:
	if typeof(v) == TYPE_ARRAY and v.size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback
