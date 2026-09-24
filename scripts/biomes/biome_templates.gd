class_name BiomeTemplates
## The biome template list from DESIGN.md "Biome Templates": the real-world
## biome list with only near-identical biomes merged (e.g. Taiga +
## Coniferous, Swamp + Bayou). 51 slots: 49 surface biomes, a fresh-water
## label for rivers and lakes, and Karst/caves, which is reserved for the
## separate underground system (not placed by BiomePass; GeologyPass's
## karst rock marks where caves would be densest).
##
## Each slot has a matching plant data file in data/biomes/ (see the README
## there), keyed by the names in KEYS.
##
## Per the spec, biomes are *labels* (map and hover readout). Plants don't
## read them: vegetation reads climate directly, so borders blend. The
## `size` field is the spec's Biome Sizing class, used to check the
## generated planet against expectations:
##   VAST  - 5.5 to 9 hours to walk across
##   MID   - roughly 3 to 4 hours
##   SMALL - specialty pockets, under 40 minutes

enum Size { VAST, MID, SMALL }

enum {
	ICE_SHEET, TUNDRA, ALPINE_TUNDRA, KRUMMHOLZ,
	TAIGA, TEMPERATE_DECIDUOUS, TEMPERATE_RAINFOREST, CLOUD_FOREST,
	TALLGRASS_PRAIRIE, SHORTGRASS_PRAIRIE, STEPPE, SAGEBRUSH, MEDITERRANEAN_SCRUB, THORN_SCRUB,
	PARAMO, PUNA, ALPINE_MEADOW,
	COLD_DESERT, HOT_DESERT,
	TROPICAL_RAINFOREST, JUNGLE, TROPICAL_DRY_FOREST, SAVANNA,
	SWAMP, FLOODPLAIN_FOREST, FRESHWATER_MARSH, WET_MEADOW, SALT_MARSH, BOG, FEN,
	BEACH, DUNES, ROCKY_SHORE, MARITIME_FOREST, MANGROVE, ESTUARY, LAGOON,
	FRESHWATER, OASIS,
	SHELF_SEA, CORAL_REEF, KELP_FOREST, DEEP_OCEAN, SEA_ICE,
	VOLCANIC_FIELD, BADLANDS, CANYON, SALT_FLAT, HOT_SPRING,
	GLACIER,
	CAVES,
	COUNT,
}

## Enum names as strings, in enum order (data files use these as `key`).
const KEYS: Array[String] = [
	"ICE_SHEET", "TUNDRA", "ALPINE_TUNDRA", "KRUMMHOLZ",
	"TAIGA", "TEMPERATE_DECIDUOUS", "TEMPERATE_RAINFOREST", "CLOUD_FOREST",
	"TALLGRASS_PRAIRIE", "SHORTGRASS_PRAIRIE", "STEPPE", "SAGEBRUSH", "MEDITERRANEAN_SCRUB", "THORN_SCRUB",
	"PARAMO", "PUNA", "ALPINE_MEADOW",
	"COLD_DESERT", "HOT_DESERT",
	"TROPICAL_RAINFOREST", "JUNGLE", "TROPICAL_DRY_FOREST", "SAVANNA",
	"SWAMP", "FLOODPLAIN_FOREST", "FRESHWATER_MARSH", "WET_MEADOW", "SALT_MARSH", "BOG", "FEN",
	"BEACH", "DUNES", "ROCKY_SHORE", "MARITIME_FOREST", "MANGROVE", "ESTUARY", "LAGOON",
	"FRESHWATER", "OASIS",
	"SHELF_SEA", "CORAL_REEF", "KELP_FOREST", "DEEP_OCEAN", "SEA_ICE",
	"VOLCANIC_FIELD", "BADLANDS", "CANYON", "SALT_FLAT", "HOT_SPRING",
	"GLACIER", "CAVES",
]

## id -> [name, group, map color, size]
const INFO := [
	["Ice sheet / polar desert", "Polar/cold", Color(0.93, 0.95, 0.98), Size.MID],
	["Tundra", "Polar/cold", Color(0.62, 0.66, 0.55), Size.VAST],
	["Alpine tundra", "Polar/cold", Color(0.7, 0.7, 0.62), Size.SMALL],
	["Forest-tundra / krummholz", "Polar/cold", Color(0.45, 0.52, 0.42), Size.SMALL],
	["Taiga / coniferous forest", "Forest", Color(0.16, 0.36, 0.3), Size.VAST],
	["Temperate deciduous / mixed forest", "Forest", Color(0.3, 0.52, 0.2), Size.MID],
	["Temperate rainforest", "Forest", Color(0.12, 0.42, 0.27), Size.SMALL],
	["Montane / cloud forest", "Forest", Color(0.25, 0.5, 0.45), Size.SMALL],
	["Tallgrass prairie", "Grass & scrub", Color(0.62, 0.7, 0.3), Size.MID],
	["Shortgrass prairie", "Grass & scrub", Color(0.7, 0.72, 0.42), Size.MID],
	["Steppe", "Grass & scrub", Color(0.72, 0.68, 0.45), Size.MID],
	["Sagebrush shrubland", "Grass & scrub", Color(0.62, 0.64, 0.52), Size.SMALL],
	["Mediterranean scrub", "Grass & scrub", Color(0.55, 0.58, 0.35), Size.SMALL],
	["Thorn scrub", "Grass & scrub", Color(0.68, 0.6, 0.35), Size.SMALL],
	["Páramo", "High-altitude", Color(0.6, 0.68, 0.55), Size.SMALL],
	["Puna", "High-altitude", Color(0.72, 0.66, 0.5), Size.SMALL],
	["Alpine meadow", "High-altitude", Color(0.55, 0.7, 0.42), Size.SMALL],
	["Cold desert", "Desert", Color(0.72, 0.68, 0.58), Size.MID],
	["Hot desert", "Desert", Color(0.9, 0.76, 0.48), Size.VAST],
	["Tropical rainforest", "Tropical", Color(0.05, 0.4, 0.15), Size.VAST],
	["Jungle", "Tropical", Color(0.1, 0.48, 0.12), Size.MID],
	["Tropical dry forest", "Tropical", Color(0.45, 0.5, 0.22), Size.MID],
	["Savanna", "Tropical", Color(0.78, 0.7, 0.35), Size.VAST],
	["Swamp / bayou", "Wetlands", Color(0.28, 0.36, 0.22), Size.SMALL],
	["Floodplain forest", "Wetlands", Color(0.28, 0.46, 0.25), Size.SMALL],
	["Freshwater marsh", "Wetlands", Color(0.4, 0.55, 0.38), Size.SMALL],
	["Wet meadow", "Wetlands", Color(0.48, 0.62, 0.36), Size.SMALL],
	["Salt marsh", "Wetlands", Color(0.52, 0.56, 0.4), Size.SMALL],
	["Bog", "Wetlands", Color(0.45, 0.42, 0.32), Size.SMALL],
	["Fen", "Wetlands", Color(0.42, 0.5, 0.35), Size.SMALL],
	["Beach", "Coastal", Color(0.93, 0.87, 0.68), Size.SMALL],
	["Dunes", "Coastal", Color(0.88, 0.8, 0.58), Size.SMALL],
	["Rocky shore", "Coastal", Color(0.5, 0.5, 0.5), Size.SMALL],
	["Maritime forest", "Coastal", Color(0.22, 0.44, 0.3), Size.SMALL],
	["Mangrove", "Coastal", Color(0.2, 0.4, 0.28), Size.SMALL],
	["Estuary / delta", "Coastal", Color(0.35, 0.55, 0.55), Size.SMALL],
	["Lagoon", "Coastal", Color(0.3, 0.65, 0.7), Size.SMALL],
	["Fresh water (river, lake)", "Freshwater", Color(0.25, 0.5, 0.75), Size.SMALL],
	["Oasis", "Freshwater", Color(0.2, 0.62, 0.45), Size.SMALL],
	["Shelf sea", "Ocean", Color(0.2, 0.45, 0.65), Size.VAST],
	["Coral reef", "Ocean", Color(0.25, 0.7, 0.72), Size.SMALL],
	["Kelp forest", "Ocean", Color(0.15, 0.38, 0.4), Size.SMALL],
	["Open / deep ocean", "Ocean", Color(0.08, 0.2, 0.42), Size.VAST],
	["Sea ice", "Ocean", Color(0.85, 0.9, 0.95), Size.MID],
	["Volcanic field", "Special", Color(0.25, 0.22, 0.22), Size.SMALL],
	["Badlands", "Special", Color(0.72, 0.45, 0.35), Size.SMALL],
	["Canyon", "Special", Color(0.65, 0.4, 0.3), Size.SMALL],
	["Salt flat", "Special", Color(0.95, 0.94, 0.9), Size.SMALL],
	["Hot spring", "Special", Color(0.7, 0.62, 0.35), Size.SMALL],
	["Glacier", "Glaciers", Color(0.8, 0.88, 0.96), Size.SMALL],
	["Karst / caves", "Caves", Color(0.4, 0.36, 0.34), Size.SMALL],
]


# INFO is a nested constant array, and Godot 4.3 can corrupt such arrays
# when several threads read them at once (chunks are built on worker
# threads). Lookups go through these flat packed copies instead, built once
# when the class loads.
static var _names := _column_strings(0)
static var _groups := _column_strings(1)
static var _colors := _column_colors()
static var _sizes := _column_sizes()


static func _column_strings(col: int) -> PackedStringArray:
	var out := PackedStringArray()
	for row in INFO:
		out.append(row[col])
	return out


static func _column_colors() -> PackedColorArray:
	var out := PackedColorArray()
	for row in INFO:
		out.append(row[2])
	return out


static func _column_sizes() -> PackedInt32Array:
	var out := PackedInt32Array()
	for row in INFO:
		out.append(row[3])
	return out


static func name_of(id: int) -> String:
	return _names[id]


static func group_of(id: int) -> String:
	return _groups[id]


static func color_of(id: int) -> Color:
	return _colors[id]


static func size_of(id: int) -> int:
	return _sizes[id]


static func id_of_key(key: String) -> int:
	return KEYS.find(key)


static func is_ocean(id: int) -> bool:
	return id == SHELF_SEA or id == CORAL_REEF or id == KELP_FOREST or id == DEEP_OCEAN or id == SEA_ICE
