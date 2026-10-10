class_name PlantSpecies
extends RefCounted
## One plant species record (DESIGN.md "Vegetation > Species data").
## Plants read climate, not biome names: a species grows wherever the local
## temperature, moisture, altitude and soil suit it, so biomes emerge and
## blend. Density peaks in the middle of each band and fades to zero at
## its edges, so neighboring species' ranges overlap and fade.

enum Tier { EMERGENT, CANOPY, SHRUB, GROUND, EPIPHYTE }

## Placeholder silhouettes, built by PlantMeshes. Real models replace these.
## An entry's `shape` string is the name in lower case ("mushroom").
## MUSHROOM (design §FM.13, queue 75): caps on stalks, a few fruit bodies
## to a plant, drawn from the entry's appearance.cap / underside / stipe
## (MushroomMesh).
## GLOBE_CACTUS (design §FM.13, queue 76): low ribbed buttons sunk to their
## rims in the ground, a tight clump to a plant, drawn from the entry's
## appearance.stem / flower (GlobeCactusMesh); never the CACTUS column.
## BULB (design §FM.13, queue 77; "bulb"): a bare bulb half out of the
## ground and a flat upright fan of strap leaves in one plane (two ranks),
## drawn from the entry's appearance.trunk / leaf and bark blocks
## (BulbMesh).
enum Shape {
	CONIFER, BROADLEAF, GNARLED, EMERGENT, UMBRELLA, PALM, CYPRESS, MANGROVE,
	ROSETTE, SPIKE_ROSETTE, SHRUB, TUSSOCK, GRASS, REED, FERN, TREE_FERN,
	CACTUS, CUSHION, MOSS, HANGING_MOSS, EPIPHYTE_CLUMP, LIANA, KNEES, THERMOPHILE_MAT,
	BAMBOO,
	MUSHROOM,
	GLOBE_CACTUS,
	BULB,
}

## Special conditions (optional).
enum Needs {
	NONE,
	STANDING_WATER, # roots in shallow standing water (cypress, mangrove, reeds)
	RIVER_BANK, # within reach of a river or lake shore
	DRY_GROUND, # never in standing water
	SALT_WATER, # tolerates or needs brackish/salt water
	HOT_GROUND, # thermal areas near volcanic hot springs
	FOREST_FLOOR, # under or in the gaps of a forest (a forest biome)
}

var name: String
## The binomial (spec D4): real, or invented for placeholder plants.
var genus := ""
var species := ""
var tier: Tier
var shape: Shape
var temp_c := Vector2(-50.0, 50.0) # band, °C (mean annual)
var moisture := Vector2(0.0, 1.0) # band, 0-1 effective moisture
var altitude_m := Vector2(-INF, INF) # optional band, meters
var density := 1.0 # peak relative abundance
var soils := {} # PlanetData.Rock -> factor; rocks not listed use soil_default
var soil_default := 0.6
## The soil classes it grows on, as bits (1 << PlanetData.Rock): a hard
## gate (data/soil.json); outside them it never spawns.
var soil_mask := 0xFF
var needs: Array[Needs] = []
var _need_bits := -1
var height_m := Vector2(1.0, 2.0) # size range for jitter
var color := Color(0.3, 0.5, 0.25)
var accent := Color(0.35, 0.25, 0.15) # trunk/stem/flower
## Water depth range (m) this species can root in, if STANDING_WATER.
var water_depth_m := Vector2(0.05, 1.5)
var source := "" # research note / citation from DESIGN.md
## Where it comes from on Earth, short, for the HUD ("Central Asia and the
## Middle East"): the entry's `origin`, else the first clause of its
## `source` / `traits.native_range` (origin_from_source()).
var origin := ""
## A cannabis landrace's terpene evidence (its entry's
## cannabis.terpene_evidence): "none" where there is no evidence of terpene
## relevance (always_present does not lift it); "" where none is recorded.
var terpene_evidence := ""
## How leafy its crown is, 0-1 (`leaf_density` in the table; -1: the
## shape's default, leaf_density_of()): how many leaf clusters a branchy
## tree carries along its limbs (PlantMeshes).
var leaf_density := -1.0
## How its wood behaves as a handhold (catch and swing; Handholds): the
## entry's own `handhold` block, if it has one.
var handhold := {}
## The biogeographic realms it's native to (design §AA, the realm gate:
## RealmMap). Empty: not gated (every biome-file plant, and catalogue
## entries without a `realm`). Tagged, it grows only where the place's
## realm is one of these and the place's biome has an association for it.
var realms := PackedStringArray()
## The biome gate (design 1 Oct §CA, data/habitat.json): the biomes
## (BiomeTemplates ids) that list this species: a biome file's plants
## tiers, its associations' dominant / companion / ground / catalogue
## lists, and a catalogue entry's own `biomes` list, the union over files.
## It grows only in them. SpeciesDB.UNLISTED (-1) marks a catalogue entry
## with no list yet: it grows nowhere until it is tagged (like an untagged
## realm). Empty only with the gate off.
var biomes := PackedInt32Array()
## The data files that list this species (basenames; the walkabout's report).
var files := PackedStringArray()
## Loaded from a catalogue (data/plants/), not a biome file.
var from_catalogue := false
## Its own tiles (design §AH, assets/textures/plants/species/
## atlas_species.json, loaded by SpeciesDB): res:// paths by kind, "leaf"
## (48 px cutout), "leaf_autumn" (deciduous), "leaves" (32 px mass),
## "litter", "bark" (64 px, bark_tile_m square), "petiole"
## (Amorphophallus). Empty: no tiles, the class textures (Look) instead.
var tiles := {}
## The leaf colour the tiles carry, and the bark tile's size (m).
var leaf_color := Color(0.24, 0.51, 0.2)
var bark_tile_m := 0.4
## Its leaf (the entry's `leaf` block): mean length in meters (size_cm),
## type (simple, compound, needle, strap...) and surface texture (matte,
## glossy...).
var leaf_m := 0.1
var leaf_type := ""
var leaf_texture := ""
## The leaf block's shape (PLANT_SCHEMA §2): outline (ovate, sagittate,
## cordate, peltate...), base, apex, length over width (aspect) and the
## size range in meters (size_cm). The giant herbs build their blades from
## these (PlantMeshes, Mike's 3 Oct play).
var leaf_outline := ""
var leaf_base := ""
var leaf_apex := ""
var leaf_aspect := 0.0
var leaf_size_m := Vector2.ZERO
## Where one whole leaf sits in its leaf tile (atlas_species.json
## leaf_frame, tools/look/make_plant_tiles.py, the broad blades only):
## [u0, v0, u1, v1, v where the stalk meets it]; empty for the rest.
var leaf_frame := PackedFloat32Array()
## The leaf stalk's colour (appearance.petiole.base), alpha 0 when the
## entry gives none.
var petiole_color := Color(0, 0, 0, 0)
## Its wood's program (the entry's `architecture` block, PLANT_SCHEMA §8,
## TREE_ARCHITECTURE.md §5: model, habit, orders, branch angles, taper,
## sinuosity, fork, buttress, lean, live crown ratio, self-pruning, dead
## limbs, root flare, spacing) and how its crown is dressed (`canopy`:
## form, gap, layering, droop); empty when it has none. The leaf block's
## arrangement (alternate, opposite, whorled, spiral, distichous...).
var arch := {}
var canopy := {}
var leaf_arrangement := ""
## Deciduous (tint.drop): turns tint.autumn and drops its leaves in
## autumn (design §AI).
var deciduous := false
var autumn_color := Color(0.69, 0.54, 0.23)
## Its researched life cycle (the Amorphophallus: the catalogue's `cycle`
## block — dormancy, shoot and bud, bloom, fruit, tuber, ploidy, hybrids,
## sports; AroidLife reads it); empty for everything else. A plant with a
## cycle lives it plant by plant (AroidGarden) instead of taking the
## autumn clock (deciduous is off for them).
var cycle := {}
## Its `aroid` block (petiole pattern and colours, spathe colours) and the
## `appearance.flower` block (spadix colour...), for the bloom's parts.
var aroid := {}
var flower := {}
## The entry's whole `appearance` block (the modeller's targets: a
## fungus's cap, underside and stipe, its habit and notes...), for the
## builders that draw from it (MushroomMesh, design §FM.13; a globe
## cactus's stem and flower, GlobeCactusMesh; a bulb's trunk notes and
## leaf, BulbMesh); empty when the entry has none.
var appearance := {}
## The entry's `bark` block (pattern, color, color_2...): a bulb's tunics
## for BulbMesh (design §FM.13); empty when the entry has none.
var bark := {}
## A fungus's `fungus` block (substrate, fruit_season...): LitterField
## fruits the "litter" ones. Read from whichever file lists it (design
## §CC folded the fungi catalogue into the biome files).
var fungus := {}
## Its species gene ranges (the catalogue's `genes`: size, pattern,
## scent, allocation...), 0-1 each, for PlantGenetics' genomes.
var gene_ranges := {}
## Spreads by offsets, stolons, bulbils or suckers (repro.clonal): its
## sports and genomes are rolled per clump (PlantGenetics), not per plant.
var clonal := false
## Sports (PlantGenetics.setup(), data/sports.json): the chance one of
## these plants is a sport, the sport codes it can show and their
## cumulative weights.
var sport_rate := 0.0
var sport_codes := PackedInt32Array()
var sport_cum := PackedFloat32Array()
## How it grows (design §AR): the entry's researched `growth` block (life,
## germination, height by age, first seed, lifespan, how much shade its
## young stand, the young plant's form) and `fruiting` (its flowers and
## fruit); empty when it has none.
var growth := {}
var fruiting := {}
## Worked out once from `growth` (PlantGrowth.setup()): its height-by-age
## curve (the share of full height at t years is (1 - exp(-k t))^p), the
## shade its young stand (0 very intolerant .. 1 very tolerant), its young
## form ("whip", "cone", "establishment"...), its life ("perennial",
## "annual", "biennial", "monocarpic"), typical and longest life, first
## seed and the years before a trunk shows (years).
var grow_k := 0.1
var grow_p := 1.5
var shade_tol := 0.5
var juvenile := "whip"
var life := "perennial"
var lifespan_y := Vector2(100.0, 300.0)
var first_seed_y := 10.0
var trunk_y := 0.0


## Smooth band membership: 1 in the middle, easing to 0 at the edges.
static func band(x: float, range_v: Vector2) -> float:
	if range_v.x == -INF and range_v.y == INF:
		return 1.0
	if x <= range_v.x or x >= range_v.y:
		return 0.0
	var mid := (range_v.x + range_v.y) * 0.5
	var half := (range_v.y - range_v.x) * 0.5
	var t := (x - mid) / half
	return 1.0 - t * t * t * t


func soil_factor(rock: int) -> float:
	return soils.get(rock, soil_default)


func soil_allowed(rock: int) -> bool:
	return (soil_mask >> rock) & 1 == 1


func has_need(n: Needs) -> bool:
	return needs.has(n)


## The needs as bits (1 << Needs value), worked out once: placement asks
## for several of them per candidate site.
func need_bits() -> int:
	if _need_bits < 0:
		_need_bits = 0
		for n in needs:
			_need_bits |= 1 << n
	return _need_bits


## Suitability at a site, before clumping and dominance. Three co-equal
## gates first (design reconciliation Session 2 G2): temperature, moisture
## and soil class; a species outside any of them is 0. Then the weights:
## the two climate bands, the soil preference within its classes, and
## altitude.
func suitability(temp: float, moist: float, altitude: float, rock: int) -> float:
	var bt := band(temp, temp_c)
	if bt <= 0.0:
		return 0.0
	var bm := band(moist, moisture)
	if bm <= 0.0 or not soil_allowed(rock):
		return 0.0
	return density * bt * bm * maxf(soil_factor(rock), 0.05) * band(altitude, altitude_m)


## The crown's leafiness, 0-1: the table's `leaf_density`, else the shape's
## default (dense beech-like broadleaves, open umbrella crowns).
func leaf_density_of() -> float:
	if leaf_density >= 0.0:
		return leaf_density
	match shape:
		Shape.BROADLEAF:
			return 0.8
		Shape.GNARLED:
			return 0.7
		Shape.EMERGENT:
			return 0.7
		Shape.UMBRELLA:
			return 0.6
		Shape.CYPRESS:
			return 0.85
	return 0.75


## "Genus species" (the HUD shows it for the plant under the crosshair),
## or "" if the table gives none.
func binomial() -> String:
	return ("%s %s" % [genus, species]).strip_edges()


## What the HUD prints under the crosshair: the binomial, then the common
## name (when the table's `name` isn't just the binomial) and the origin.
func hud_name() -> String:
	var b := binomial()
	if b == "":
		return ""
	var second := PackedStringArray()
	if name != "" and name.to_lower() != b.to_lower() and not name.begins_with(genus + " "):
		second.append(name)
	if origin != "":
		second.append(origin)
	return b if second.is_empty() else "%s\n%s" % [b, " · ".join(second)]


## A short origin from a research note: strips the leading binomial and
## takes the first clause ("Tamarix ramosissima, Central Asian and Middle
## Eastern oasis margins, feathery shrub — Flora of China" -> "Central
## Asian and Middle Eastern oasis margins"). Data may give `origin`
## outright instead.
static func origin_from_source(src: String, gen: String, spec: String) -> String:
	var t := src.strip_edges()
	if t == "":
		return ""
	var b := ("%s %s" % [gen, spec]).strip_edges()
	if b != "" and t.to_lower().begins_with(b.to_lower()):
		t = t.substr(b.length())
	t = t.strip_edges()
	while t.length() > 0 and (t.begins_with("—") or t.begins_with("-") or t.begins_with(",") or t.begins_with(";") or t.begins_with(":")):
		t = t.substr(1).strip_edges()
	var cut := t.length()
	for sep in [" — ", ";", " (", ". "]:
		var i := t.find(sep)
		if i > 0 and i < cut:
			cut = i
	t = t.substr(0, cut).strip_edges()
	# Two comma clauses at most, and never a wall of text.
	var parts := t.split(",", false)
	if parts.size() > 2:
		t = ("%s,%s" % [parts[0], parts[1]]).strip_edges()
	if t.length() > 60:
		t = t.substr(0, 57).strip_edges() + "…"
	if t.length() > 0:
		t = t[0].to_upper() + t.substr(1)
	return t
