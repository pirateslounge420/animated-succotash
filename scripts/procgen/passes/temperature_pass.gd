extends RefCounted
class_name TemperaturePass
## Pass 3: temperature from height (higher = colder) and latitude
## (distance from the map's equator row = colder), like real-world
## climate bands.
##
## Reads map.height (pass 1). Writes map.temperature, normalized so 0.0
## is coldest and 1.0 is hottest.

const HEIGHT_COOLING := 0.012 # temperature lost per unit of height above sea level


static func generate(map: WorldMapData) -> void:
	var equator_y := map.resolution * 0.5
	for y in range(map.resolution):
		# 0 at the equator row, 1 at either pole (top/bottom edge).
		var latitude := absf(y - equator_y) / equator_y
		var base_temp := 1.0 - latitude
		for x in range(map.resolution):
			var idx := map.index(x, y)
			var above_sea := maxf(map.height[idx] - map.sea_level, 0.0)
			map.temperature[idx] = clampf(base_temp - above_sea * HEIGHT_COOLING, 0.0, 1.0)
