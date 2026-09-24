class_name Ruins
## Where ruins stand: crumbling towers, lone castles on hills and ivy-
## choked aqueducts, the set pieces a wanderer is drawn toward (DESIGN.md
## night references: overgrown ruins).
##
## A planet-wide grid with at most one ruin per CELL_M cell, placed on the
## most prominent rise in the cell so its silhouette carries: castles on
## real hills, towers on knolls, aqueducts striding across low ground.
## Pure functions of the planet data (thread-safe), so every visit finds
## the same ruin and vegetation can keep the footprint clear.

enum Kind { TOWER, CASTLE, AQUEDUCT }

const CELL_M := 3200.0
const CHANCE := 0.5
const SALT := 555
const KIND_NAMES := ["Ruined tower", "Ruined castle", "Ruined aqueduct"]


static func cells_per_face() -> int:
	return CreatureSpawner._cells_per_face(CELL_M)


## The ruin in grid cell `c`, or {}:
## {"dir", "kind", "seed", "heading" (radians), "footprint_m",
##  "length_m" (aqueducts), "clear": [[dir, radius_m], ...]}.
static func find(map: PlanetData, c: Vector3i) -> Dictionary:
	var key := Vector4i(-2, c.x, c.y, c.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	if rng.randf() > CHANCE:
		return {}
	var center := CreatureSpawner._cell_point(c, cells_per_face(), SALT)
	var best := {}
	var best_score := -INF
	for i in 18:
		var p := CreatureSpawner._offset(center, rng.randf() * TAU, sqrt(rng.randf()) * CELL_M * 0.35)
		var e := map.terrain.elevation(p, true)
		var cell := map.cell_at(p)
		if e < 6.0 or map.water[cell] != PlanetData.Water.NONE:
			continue
		var b := map.biome[cell]
		if b == BiomeTemplates.ICE_SHEET or b == BiomeTemplates.GLACIER or b in TerrainChunk.WETLANDS:
			continue
		# Prominence: height above the ground 200 m around.
		var ring := 0.0
		for k in 6:
			ring += map.terrain.elevation(CreatureSpawner._offset(p, k * TAU / 6.0, 200.0), true)
		var prominence := e - ring / 6.0
		# Too steep to build on?
		var slope := absf(map.terrain.elevation(CreatureSpawner._offset(p, 0.0, 15.0), true) - map.terrain.elevation(CreatureSpawner._offset(p, PI, 15.0), true)) / 30.0
		if slope > 0.4:
			continue
		var score := prominence + rng.randf() * 4.0
		if score > best_score:
			best_score = score
			best = {"dir": p, "prominence": prominence}
	if best.is_empty():
		return {}
	var kind := Kind.TOWER
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
		Kind.AQUEDUCT:
			var length := rng.randf_range(70.0, 130.0)
			site.length_m = length
			site.footprint_m = length * 0.5
			var clear: Array = []
			var n := int(length / 10.0)
			for i in n + 1:
				var x := -length * 0.5 + i * length / n
				clear.append([CreatureSpawner._offset(best.dir, heading + PI * 0.5, x), 5.0])
			site.clear = clear
	return site


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
