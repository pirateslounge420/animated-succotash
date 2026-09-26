class_name Ruins
## Where ruins stand, the set pieces a wanderer is drawn toward (DESIGN.md
## night references: overgrown ruins). What stands there depends on the
## country:
##   * most land: crumbling stone towers, lone castles on hills and ivy-
##     choked aqueducts, on the most prominent rise in the cell so the
##     silhouette carries;
##   * snow country (ice, tundra, anything below -3 C): a cluster of
##     abandoned igloos, some fallen in, with a windbreak and a drying rack;
##   * jungle (tropical and cloud forest): a treehouse village, platforms
##     high on giant trees joined by sagging rope bridges, reached by a
##     ramp spiralling up one trunk;
##   * marsh (wetlands, mangroves): an old boardwalk on stilts wandering out
##     to a stilt cabin, planks missing and the roof fallen in.
## The last three want flat ground rather than a rise.
##
## Now and then, in any country, a pyramid stands instead (PYRAMID_CHANCE,
## likeliest in the deserts), built to suit the land (pyramid_style()):
##   * desert: a vast sandstone pyramid, its casing weathered into rough
##     courses and its capstone gone, sand drifted round the foot, a small
##     queen's pyramid beside it, and a gabled entrance up one face;
##   * jungle: a steep stepped temple, a stair climbing one face to a
##     shrine with a roof comb, all of it mossy and hung with ivy;
##   * snow: a grey stepped pyramid with snow lying on every ledge, a
##     broken obelisk on top;
##   * marsh: a stepped pyramid half sunk in the bog, its shrine fallen;
##   * elsewhere: a broad grey ziggurat with a stair and an obelisk.
## Pyramids want level ground, like the dwellings.
##
## A planet-wide grid with at most one ruin per CELL_M cell. Pure functions
## of the planet data (thread-safe), so every visit finds the same ruin and
## vegetation can keep the footprint clear.

enum Kind { TOWER, CASTLE, AQUEDUCT, IGLOO, TREEHOUSE, BOARDWALK, PYRAMID }

const CELL_M := 3200.0
const CHANCE := 0.5
const SALT := 555
const KIND_NAMES := ["Ruined tower", "Ruined castle", "Ruined aqueduct",
	"Abandoned igloos", "Abandoned treehouses", "Old boardwalk", "Ancient pyramid"]
const SNOWY := [BiomeTemplates.ICE_SHEET, BiomeTemplates.TUNDRA, BiomeTemplates.ALPINE_TUNDRA, BiomeTemplates.GLACIER]
const JUNGLY := [BiomeTemplates.TROPICAL_RAINFOREST, BiomeTemplates.JUNGLE, BiomeTemplates.CLOUD_FOREST]
const SNOW_C := -3.0
## Share of ruins that are pyramids, by pyramid_style().
const PYRAMID_CHANCE := {"desert": 0.35, "jungle": 0.2, "stone": 0.1, "snow": 0.08, "marsh": 0.1}
const DESERTY := [BiomeTemplates.HOT_DESERT, BiomeTemplates.COLD_DESERT, BiomeTemplates.DUNES,
	BiomeTemplates.BADLANDS, BiomeTemplates.CANYON, BiomeTemplates.SALT_FLAT]
const PYRAMID_NAMES := {"desert": "Desert pyramid", "jungle": "Temple pyramid", "stone": "Step pyramid",
	"snow": "Frozen pyramid", "marsh": "Sunken pyramid"}
## A stair on a stepped pyramid climbs at this angle (under the player's
## steepest walkable slope, 50 degrees).
const STAIR_DEG := 44.0

static func cells_per_face() -> int:
	return CreatureSpawner._cells_per_face(CELL_M)


## What sort of country a point is, for its ruin: "snow", "jungle",
## "marsh" or "" (stone ruins).
static func country(map: PlanetData, p: Vector3) -> String:
	var cell := map.cell_at(p)
	var b := map.biome[cell]
	if b in TerrainChunk.WETLANDS or b == BiomeTemplates.MANGROVE:
		return "marsh"
	if b in SNOWY or map.temp_c[cell] < SNOW_C:
		return "snow"
	if b in JUNGLY:
		return "jungle"
	return ""


## How a pyramid at `p` (in `land`, from country()) is built: "desert",
## "jungle", "snow", "marsh" or "stone".
static func pyramid_style(map: PlanetData, p: Vector3, land: String) -> String:
	if land != "":
		return land
	return "desert" if map.biome[map.cell_at(p)] in DESERTY else "stone"


## A ruin's name (the glowing site's label).
static func site_name(site: Dictionary) -> String:
	if int(site.kind) == Kind.PYRAMID:
		return PYRAMID_NAMES[site.style]
	return KIND_NAMES[site.kind]


## The ruin in grid cell `c`, or {}:
## {"dir", "kind", "seed", "heading" (radians), "footprint_m",
##  "length_m" (aqueducts, boardwalks), "clear": [[dir, radius_m], ...]}.
static func find(map: PlanetData, c: Vector3i) -> Dictionary:
	var key := Vector4i(-2, c.x, c.y, c.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	if rng.randf() > CHANCE:
		return {}
	var center := CreatureSpawner._cell_point(c, cells_per_face(), SALT)
	var land := country(map, center)
	# A pyramid in its place now and then: its own roll (and its own
	# numbers after), so the other ruins stay just where they were.
	var prng := RandomNumberGenerator.new()
	prng.seed = hash([key, "pyramid"])
	var style := pyramid_style(map, center, land)
	if prng.randf() >= PYRAMID_CHANCE[style]:
		style = ""
	var level := land != "" or style != ""
	var best := {}
	var best_score := -INF
	for i in 18:
		var p := CreatureSpawner._offset(center, rng.randf() * TAU, sqrt(rng.randf()) * CELL_M * 0.35)
		var e := map.terrain.elevation(p, true, false)
		var cell := map.cell_at(p)
		if e < (1.0 if land == "marsh" else 6.0) or map.water[cell] != PlanetData.Water.NONE:
			continue
		if country(map, p) != land:
			continue
		# Prominence: height above the ground 200 m around.
		var ring := 0.0
		for k in 6:
			ring += map.terrain.elevation(CreatureSpawner._offset(p, k * TAU / 6.0, 200.0), true, false)
		var prominence := e - ring / 6.0
		# Too steep to build on?
		var slope := absf(map.terrain.elevation(CreatureSpawner._offset(p, 0.0, 15.0), true, false) - map.terrain.elevation(CreatureSpawner._offset(p, PI, 15.0), true, false)) / 30.0
		if slope > (0.1 if style != "" else (0.15 if land != "" else 0.4)):
			continue
		# Stone ruins on the most prominent rise; the rest on the flattest.
		var score := (-slope * 40.0 if level else prominence) + rng.randf() * 4.0
		if score > best_score:
			best_score = score
			best = {"dir": p, "prominence": prominence}
	if best.is_empty():
		return {}
	var kind := Kind.TOWER
	match land:
		"snow":
			kind = Kind.IGLOO
		"jungle":
			kind = Kind.TREEHOUSE
		"marsh":
			kind = Kind.BOARDWALK
		_:
			if best.prominence > 8.0 and rng.randf() < 0.6:
				kind = Kind.CASTLE
			elif rng.randf() < 0.4:
				kind = Kind.AQUEDUCT
	if style != "":
		kind = Kind.PYRAMID
	var heading := rng.randf() * TAU
	var site := {"dir": best.dir, "kind": kind, "seed": hash(key), "heading": heading}
	match kind:
		Kind.PYRAMID:
			_pyramid_site(site, style, prng)
		Kind.CASTLE:
			site.footprint_m = 28.0
			site.clear = [[best.dir, 30.0]]
		Kind.TOWER:
			site.footprint_m = 10.0
			site.clear = [[best.dir, 11.0]]
		Kind.IGLOO:
			site.footprint_m = 12.0
			site.clear = [[best.dir, 13.0]]
		Kind.TREEHOUSE:
			site.footprint_m = 18.0
			site.clear = [[best.dir, 19.0]]
		Kind.BOARDWALK, Kind.AQUEDUCT:
			var length := rng.randf_range(70.0, 130.0) if kind == Kind.AQUEDUCT else rng.randf_range(40.0, 65.0)
			site.length_m = length
			site.footprint_m = length * 0.5
			var clear: Array = []
			var n := int(length / 10.0)
			for i in n + 1:
				var x := -length * 0.5 + i * length / n
				clear.append([CreatureSpawner._offset(best.dir, heading + PI * 0.5, x), 5.0 if kind == Kind.AQUEDUCT else 4.0])
			if kind == Kind.BOARDWALK:
				# The cabin at the far end, the camp before the start.
				clear.append([CreatureSpawner._offset(best.dir, heading + PI * 0.5, length * 0.5 + 3.0), 7.0])
				clear.append([CreatureSpawner._offset(best.dir, heading + PI * 0.5, -length * 0.5 - 4.0), 5.0])
			site.clear = clear
	return site


## A pyramid's measurements (RuinBuilder builds to them) and the ground it
## keeps clear: {"style", "base_m" (side), "height_m"} and, stepped,
## {"tiers", "tier_m", "top_hs" (half the top platform), "stair_out"
## (how far the stair's foot reaches past the base)}, or, in the desert,
## {"queen_hs"} for the small pyramid beside it. The camp (if any) is at
## the foot on the +x side, a queen's pyramid on the -x side.
static func _pyramid_site(site: Dictionary, style: String, prng: RandomNumberGenerator) -> void:
	site.style = style
	var base := 0.0
	var reach := 0.0 # furthest the pyramid reaches from its center
	match style:
		"desert":
			base = prng.randf_range(56.0, 84.0)
			site.height_m = base * 0.62
			site.queen_hs = base * prng.randf_range(0.16, 0.22)
		_:
			var dims: Array = {"jungle": [34.0, 44.0, 7, 9, 2.6, 3.0, 5.5],
				"marsh": [30.0, 40.0, 6, 7, 2.5, 2.8, 5.0],
				"stone": [38.0, 52.0, 4, 6, 3.2, 3.8, 7.0],
				"snow": [38.0, 52.0, 4, 6, 3.2, 3.8, 7.0]}[style]
			base = prng.randf_range(dims[0], dims[1])
			site.tiers = prng.randi_range(dims[2], dims[3])
			site.tier_m = prng.randf_range(dims[4], dims[5])
			site.top_hs = dims[6]
			site.height_m = site.tiers * site.tier_m
			# The stair climbs from past the base to the top platform's edge;
			# a little spare for ground that rises or falls under it.
			var rise: float = site.height_m + site.tier_m
			site.stair_out = maxf(0.0, rise / tan(deg_to_rad(STAIR_DEG)) - (base * 0.5 - site.top_hs)) + 1.5
			reach = base * 0.5 + site.stair_out + 2.0
	site.base_m = base
	var hs := base * 0.5
	reach = maxf(reach, hs * 1.42)
	site.footprint_m = reach + 3.0
	var side := func(x: float) -> Vector3:
		return CreatureSpawner._offset(site.dir, site.heading + PI * 0.5, x)
	var clear: Array = [[site.dir, reach + 3.0]]
	# The camp at the foot, and the queen's pyramid.
	clear.append([side.call(hs + 6.0), 7.0])
	if site.has("queen_hs"):
		var q: float = site.queen_hs
		clear.append([side.call(-(hs + q + 8.0)), q * 1.42 + 3.0])
		site.footprint_m = maxf(site.footprint_m, hs + 2.0 * q + 12.0)
	site.clear = clear


## Share of ruins with a living camp: a fire burning and folk round it
## (Camps). The rest stand empty.
const INHABITED := 0.55


static func inhabited(site: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site.seed, "living"])
	return rng.randf() < INHABITED


## Who sits at an inhabited ruin's fire: at stone ruins "dead" (skeletons
## and a hooded one, 45%), "goblin" (20%) or "tribal"; "north" at igloos,
## "tribal" under treehouses, "marsh" by boardwalks. At pyramids, the
## country's own folk ("dead" or "tribal" in the desert, "north" in snow,
## the stone ruins' roll on grey ziggurats).
static func camp_folk(site: Dictionary) -> String:
	match int(site.kind):
		Kind.IGLOO:
			return "north"
		Kind.TREEHOUSE:
			return "tribal"
		Kind.BOARDWALK:
			return "marsh"
		Kind.PYRAMID:
			match site.style:
				"jungle":
					return "tribal"
				"snow":
					return "north"
				"marsh":
					return "marsh"
				"desert":
					var drng := RandomNumberGenerator.new()
					drng.seed = hash([site.seed, "folk"])
					return "dead" if drng.randf() < 0.5 else "tribal"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site.seed, "folk"])
	var roll := rng.randf()
	return "dead" if roll < 0.45 else ("goblin" if roll < 0.65 else "tribal")


## Ruins whose footprint comes within `radius` m of `d`.
static func near(map: PlanetData, d: Vector3, radius: float) -> Array:
	var out: Array = []
	for c in CreatureSpawner._cells_around(d, radius, CELL_M):
		var r := find(map, c)
		if not r.is_empty() and CubeSphere.surface_distance_m(r.dir, d) < radius + r.footprint_m:
			out.append(r)
	return out


## [dir, radius_m] circles that plants must keep out of near `d`.
static func clearings_near(map: PlanetData, d: Vector3, radius: float) -> Array:
	var out: Array = []
	for r in near(map, d, radius):
		out.append_array(r.clear)
	return out
