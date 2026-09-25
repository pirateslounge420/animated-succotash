class_name GeologyPass
## Rock and soil type per cell ("the planet's rock data" in DESIGN.md
## Vegetation > Species data). Read by species soil preferences and by the
## special-terrain biomes (volcanic fields, karst, badlands, salt flats).
##
## Runs after climate and rivers because several soils are climate- or
## water-made (peat, alluvium, glacial till). First matching rule wins:
##   volcanic basalt  - around the TerrainField hotspots
##   coastal sand     - low, flat land right at the sea
##   alluvial         - rivers, lake shores and flat floodplains beside them
##   clay/peat        - flat, waterlogged, cool ground (bogs, fens)
##   glacial till     - cold ground (mean temp below freezing)
##   limestone karst  - seeded noise regions of ancient sea-floor rock
##   sandstone        - dry country
##   granite          - everything else (mountain cores, old shields)
##
## Reads elevation, slope, water, precip/moisture, temperature.
## Writes rock.

const VOLCANIC_REACH := 1.2 # multiples of the cone radius
const KARST_THRESHOLD := 0.28


static func run(map: PlanetData) -> void:
	var karst := FastNoiseLite.new()
	karst.seed = map.terrain.world_seed * 7919 + 40
	karst.frequency = 1.0 / 30000.0
	karst.fractal_octaves = 3

	var nbrs := map.neighbors
	var rock := PackedByteArray()
	rock.resize(map.cell_count)
	for c in map.cell_count:
		rock[c] = _classify(map, c, nbrs, karst)
	map.rock = rock


static func _classify(map: PlanetData, c: int, nbrs: PackedInt32Array, karst: FastNoiseLite) -> int:
	var d := map.dir[c]
	var hot := map.terrain.nearest_hotspot(d)
	if hot.distance_m < hot.radius_m * VOLCANIC_REACH:
		return PlanetData.Rock.BASALT_VOLCANIC

	var water: int = map.water[c]
	var elev := map.elevation[c]
	var slope := map.slope[c]
	if water == PlanetData.Water.OCEAN:
		return PlanetData.Rock.COASTAL_SAND if elev > -60.0 * PlanetConst.HEIGHT_SCALE else PlanetData.Rock.BASALT_VOLCANIC

	var next_to_ocean := false
	var next_to_fresh := false
	for k in 8:
		var nw: int = map.water[nbrs[c * 8 + k]]
		if nw == PlanetData.Water.OCEAN:
			next_to_ocean = true
		elif nw != PlanetData.Water.NONE:
			next_to_fresh = true

	if next_to_ocean and elev < 40.0 * PlanetConst.HEIGHT_SCALE and slope < 0.12:
		return PlanetData.Rock.COASTAL_SAND
	if water != PlanetData.Water.NONE or (next_to_fresh and slope < 0.1):
		return PlanetData.Rock.ALLUVIAL
	if slope < 0.05 and map.moisture[c] > 0.72 and map.temp_c[c] < 14.0:
		return PlanetData.Rock.CLAY_PEAT
	if map.temp_c[c] < -1.0:
		return PlanetData.Rock.GLACIAL_TILL
	if karst.get_noise_3dv(d * PlanetConst.RADIUS_M) > KARST_THRESHOLD and elev < 2500.0 * PlanetConst.HEIGHT_SCALE:
		return PlanetData.Rock.LIMESTONE_KARST
	if map.moisture[c] < 0.3:
		return PlanetData.Rock.SANDSTONE
	return PlanetData.Rock.GRANITE
