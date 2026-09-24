class_name PlanetGenerator
extends RefCounted
## Builds a whole planet from a seed, in the order DESIGN.md "Weather
## System > Generation order" lays out. Every value comes from the seed;
## nothing is hand-placed.
##
##   1. TerrainPass          - elevation, slope
##   2. HydrologyPass.basins - oceans, lakes, drainage, coast distance
##   3. WeatherSim.spin_up   - simulate weeks of weather, keep averages
##   4. ClimatePass          - downscale averages to 1 km cells
##   5. HydrologyPass.rivers - discharge from rainfall -> rivers, salinity
##   6. GeologyPass          - rock and soil
##   7. BiomePass            - biome labels
##
## Vegetation and creatures are placed later, locally around the player
## (VegetationPlacer, CreatureSpawner), reading this blueprint.
##
## Emits progress(step_name, fraction) so a loading screen can show it.

signal progress(step: String, fraction: float)

## Default blueprint resolution: 96 cells per face edge, ~1 km cells.
const DEFAULT_RES := 96

var planet: PlanetData
var weather: WeatherSim


func generate(world_seed: int, res := DEFAULT_RES) -> void:
	var t0 := Time.get_ticks_msec()
	progress.emit("Raising terrain", 0.0)
	planet = PlanetData.new(res, TerrainField.new(world_seed))
	TerrainPass.run(planet)
	progress.emit("Filling seas and lakes", 0.15)
	HydrologyPass.basins(planet)
	progress.emit("Simulating weather", 0.25)
	weather = WeatherSim.new(planet)
	weather.spin_up()
	progress.emit("Settling climate", 0.65)
	ClimatePass.run(planet, weather)
	progress.emit("Carving rivers", 0.8)
	HydrologyPass.rivers(planet)
	progress.emit("Laying down rock", 0.88)
	GeologyPass.run(planet)
	progress.emit("Naming biomes", 0.94)
	BiomePass.run(planet)
	progress.emit("Done", 1.0)
	print("[PlanetGenerator] seed %d generated in %d ms" % [world_seed, Time.get_ticks_msec() - t0])
