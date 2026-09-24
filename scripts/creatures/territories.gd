class_name Territories
## Where mythical creatures live (DESIGN.md "Mythical creatures"): a
## coarse planet-wide grid with at most one territory per cell, chosen
## among the mythical species whose climate fits a land spot in it.
##
## Pure functions of the planet data and the creature list, so the answer
## is the same every visit, and vegetation (on worker threads) can keep
## folk camps clear of trees and undergrowth. CreatureSpecies.all() must
## have been loaded on the main thread first (ChunkManager.setup does it).

const CELL_M := 1600.0
const CHANCE := 0.55
const CLEARING_M := 7.0
const SALT := 777


static func cells_per_face() -> int:
	return CreatureSpawner._cells_per_face(CELL_M)


## The territory in grid cell `c`, or {}: {"species", "dir", "seed"}.
static func find(map: PlanetData, c: Vector3i) -> Dictionary:
	var key := Vector4i(-1, c.x, c.y, c.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	if rng.randf() > CHANCE:
		return {}
	var center := CreatureSpawner._cell_point(c, cells_per_face(), SALT)
	for attempt in 6:
		var p := center if attempt == 0 else CreatureSpawner._offset(center, rng.randf() * TAU, rng.randf() * CELL_M * 0.4)
		var e := map.terrain.elevation(p, true)
		if e < 2.0 or map.water[map.cell_at(p)] != PlanetData.Water.NONE:
			continue
		var t := map.sample(map.temp_c, p) + (map.sample(map.elevation, p) - e) * PlanetConst.LAPSE_RATE_C_PER_M
		var m := map.sample(map.moisture, p)
		var fits: Array[CreatureSpecies] = []
		for sp in CreatureSpecies.all():
			if sp.role == "mythical" and sp.climate_ok(t, m, e):
				fits.append(sp)
		if fits.is_empty():
			return {}
		return {"species": fits[rng.randi() % fits.size()], "dir": p, "seed": hash(key)}
	return {}


## Campfire sites within `radius` m of `d` (for clearings).
static func camps_near(map: PlanetData, d: Vector3, radius: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for c in CreatureSpawner._cells_around(d, radius, CELL_M):
		var t := find(map, c)
		if not t.is_empty() and t.species.campfire and CubeSphere.surface_distance_m(t.dir, d) < radius + CLEARING_M:
			out.append(t.dir)
	return out
