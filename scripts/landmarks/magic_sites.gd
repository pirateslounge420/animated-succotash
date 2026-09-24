class_name MagicSites
## The places that glow at night: the third palette, bioluminescence, for
## magical and special locations, distinct from ordinary moonlit night.
##
##   ruins        every ruin (moss on the stones, plants around it)
##   mythical     every mythical creature's territory
##   glow ponds   about a third of fresh lakes and wetland cells: the water
##                itself shines teal/cobalt and lights the banks
##
## Pure functions of the planet data. Each site: {"dir", "radius_m",
## "kind" (1 = ruins/mythical: ground, moss and plants glow; POND_KIND =
## mostly the water), "type"}.

const POND_KIND := 0.4
const POND_SHARE := 35 # percent of eligible cells
const POND_RADIUS_M := 900.0
const RUIN_MARGIN_M := 45.0
const MYTHIC_RADIUS_M := 90.0
const POND_BIOMES := [
	BiomeTemplates.BOG, BiomeTemplates.FEN, BiomeTemplates.FRESHWATER_MARSH, BiomeTemplates.SWAMP,
]


## `ruins`: Ruins.near(map, d, radius) if the caller has it cached.
static func near(map: PlanetData, d: Vector3, radius: float, ruins = null) -> Array:
	var out: Array = []
	for r in (ruins if ruins != null else Ruins.near(map, d, radius)):
		out.append({"dir": r.dir, "radius_m": r.footprint_m + RUIN_MARGIN_M, "kind": 1.0, "type": "ruin"})
	for c in CreatureSpawner._cells_around(d, radius, Territories.CELL_M):
		var t := Territories.find(map, c)
		if not t.is_empty() and CubeSphere.surface_distance_m(t.dir, d) < radius + MYTHIC_RADIUS_M:
			out.append({"dir": t.dir, "radius_m": MYTHIC_RADIUS_M, "kind": 1.0, "type": "mythical"})
	for c in _cells_within(map, d, radius + POND_RADIUS_M):
		if is_glow_pond(map, c):
			out.append({"dir": map.dir[c], "radius_m": POND_RADIUS_M, "kind": POND_KIND, "type": "pond"})
	return out


static func is_glow_pond(map: PlanetData, c: int) -> bool:
	var eligible := (map.water[c] == PlanetData.Water.LAKE and map.salinity[c] != PlanetData.Salinity.SALT) \
		or map.biome[c] in POND_BIOMES
	return eligible and posmod(hash(c * 7919 + map.terrain.world_seed), 100) < POND_SHARE


## Blueprint cells whose centers lie within `radius` m of `d`.
static func _cells_within(map: PlanetData, d: Vector3, radius: float) -> Array:
	var start := map.cell_at(d)
	var out: Array = []
	var seen := {start: true}
	var frontier := [start]
	var rings := int(ceil(radius / (map.cell_km() * 1000.0))) + 1
	for r in rings:
		var next: Array = []
		for c in frontier:
			if CubeSphere.surface_distance_m(map.dir[c], d) < radius:
				out.append(c)
			for k in 8:
				var nb := map.neighbors[c * 8 + k]
				if nb >= 0 and not seen.has(nb):
					seen[nb] = true
					next.append(nb)
		frontier = next
	return out
