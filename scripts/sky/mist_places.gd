class_name MistPlaces
## Where low mist lies (Mike, 5 Oct: "mist should only be in certain
## places, not around the whole world always"). Mist (look.json "mist",
## SkySystem) is scaled by this 0-1 share of the place you stand in:
## water close by (a river, a lake, the sea's edge), wet country (marsh,
## bog, swamp, mangrove, rain and cloud forest), a valley floor (the spot
## well below the 250 m ring round it), the place's own fog likelihood
## (planet fog), and a ruin that keeps its mist (the pillar shrines'
## valley, §DY); all held down where the air is dry (the cell's moisture).
## Open, dry ground and hilltops get almost none.

## Each source's weight at full strength.
const WATER := 0.9
const WET_BIOME := 0.8
const VALLEY := 0.7
const VALLEY_DEPTH_M := 6.0
const WATER_REACH_M := 300.0
## The least mist anywhere (a trace), and how much dry air holds it down.
const FLOOR := 0.05
const DRY_KEEP := 0.35
const WET_BIOMES := ["FRESHWATER_MARSH", "SALT_MARSH", "BOG", "SWAMP", "MANGROVE", "CLOUD_FOREST", "TEMPERATE_RAINFOREST", "TROPICAL_RAINFOREST", "JUNGLE", "FLOODPLAIN_FOREST", "ESTUARY", "LAGOON"]


## The share at surface direction `d`; `ground` the spot's height and
## `ring_mean` the 250 m ring's (main), `rivers` the network (or null).
static func share(map: PlanetData, rivers: RiverNetwork, d: Vector3, ground: float, ring_mean: float) -> float:
	if map == null or map.biome.is_empty():
		return 1.0
	var c := map.cell_at(d)
	var s := 0.0
	# Water.
	var water := 0.0
	for k in 9:
		var n := c if k == 8 else map.neighbors[c * 8 + k]
		if n >= 0 and map.water[n] != PlanetData.Water.NONE and CubeSphere.surface_distance_m(map.dir[n], d) < WATER_REACH_M + map.cell_m() * 0.5:
			water = 1.0
	if water < 1.0 and rivers != null:
		for sg in rivers.segments_near(map, c):
			var m := rivers.closest_dt(sg, d).x - rivers.width[sg] * 0.5
			water = maxf(water, 1.0 - smoothstep(20.0, WATER_REACH_M, m))
	s = maxf(s, water * WATER)
	# Wet country.
	var key: String = BiomeTemplates.KEYS[map.biome[c]] if map.biome[c] >= 0 and map.biome[c] < BiomeTemplates.KEYS.size() else ""
	if WET_BIOMES.has(key):
		s = maxf(s, WET_BIOME)
	# A valley floor.
	if ring_mean != INF:
		s = maxf(s, smoothstep(0.0, VALLEY_DEPTH_M, ring_mean - ground) * VALLEY)
	# The place's own fog likelihood.
	s = maxf(s, map.sample(map.fog, d))
	# A ruin that keeps its mist (the pillar shrines' valley).
	for r in Ruins.near(map, d, 600.0):
		if int(r.get("kind", -1)) == Ruins.Kind.PILLAR_SHRINES and CubeSphere.surface_distance_m(r.dir, d) < float(r.get("footprint_m", 200.0)) + 150.0:
			s = 1.0
	var wet := map.sample(map.moisture, d)
	s *= lerpf(DRY_KEEP, 1.0, smoothstep(0.15, 0.55, wet))
	return clampf(maxf(s, FLOOR), 0.0, 1.0)
