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
## A planet-wide grid with at most one ruin per CELL_M cell. Pure functions
## of the planet data (thread-safe), so every visit finds the same ruin and
## vegetation can keep the footprint clear.

enum Kind { TOWER, CASTLE, AQUEDUCT, IGLOO, TREEHOUSE, BOARDWALK }

const CELL_M := 3200.0
const CHANCE := 0.5
const SALT := 555
const KIND_NAMES := ["Ruined tower", "Ruined castle", "Ruined aqueduct",
	"Abandoned igloos", "Abandoned treehouses", "Old boardwalk"]
const SNOWY := [BiomeTemplates.ICE_SHEET, BiomeTemplates.TUNDRA, BiomeTemplates.ALPINE_TUNDRA, BiomeTemplates.GLACIER]
const JUNGLY := [BiomeTemplates.TROPICAL_RAINFOREST, BiomeTemplates.JUNGLE, BiomeTemplates.CLOUD_FOREST]
const SNOW_C := -3.0

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
		if slope > (0.15 if land != "" else 0.4):
			continue
		# Stone ruins on the most prominent rise; the rest on the flattest.
		var score := (prominence if land == "" else -slope * 40.0) + rng.randf() * 4.0
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
	var heading := rng.randf() * TAU
	var site := {"dir": best.dir, "kind": kind, "seed": hash(key), "heading": heading}
	match kind:
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


## Share of ruins with a living camp: a fire burning and folk round it
## (Camps). The rest stand empty.
const INHABITED := 0.55


static func inhabited(site: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site.seed, "living"])
	return rng.randf() < INHABITED


## Who sits at an inhabited ruin's fire: "dead" (skeletons and a hooded
## one, at about half the stone ruins), "north", "tribal" or "marsh".
static func camp_folk(site: Dictionary) -> String:
	match int(site.kind):
		Kind.IGLOO:
			return "north"
		Kind.TREEHOUSE:
			return "tribal"
		Kind.BOARDWALK:
			return "marsh"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site.seed, "folk"])
	return "dead" if rng.randf() < 0.45 else "tribal"


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
