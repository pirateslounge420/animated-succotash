class_name ClimatePass
## Pass 4: long-term climate per blueprint cell, downscaled from the
## weather simulation's averages (DESIGN.md "Weather System": biomes are
## classified from simulated long-term averages, Köppen-style).
##
## The weather grid is ~10 km per cell, too coarse to see individual
## ridges, so this pass adds the terrain detail back at 1 km:
##   temperature - weather average at sea level, minus the lapse rate for
##                 this cell's height.
##   precip      - weather average, raised where the mean wind climbs a
##                 slope (windward) and cut where a ridge upwind has
##                 already wrung the air out (leeward rain shadow).
##   moisture    - 0-1 effective moisture: precipitation against the
##                 evaporative demand of the heat (an aridity index).
##   fog         - simulated saturated-and-calm frequency, raised on moist
##                 windward slopes (cloud forest belts) and near coasts.
##
## Reads elevation, water, coast distance + the WeatherSim averages.
## Writes temp_c, temp_swing_c, precip_mm, moisture, fog, wind_avg.

const UPWIND_STEPS := 8
const UPWIND_STEP_M := 2500.0
const SHADOW_HEIGHT_M := 1800.0 * PlanetConst.HEIGHT_SCALE # ridge height above you that halves your rain
const MIN_SHADOW := 0.25
const WINDWARD_GAIN := 1.6 # per unit of upslope along the wind
const MAX_WINDWARD := 2.2


static func run(map: PlanetData, weather: WeatherSim) -> void:
	var n := map.cell_count
	var temp := PackedFloat32Array()
	var swing := PackedFloat32Array()
	var precip := PackedFloat32Array()
	var moist := PackedFloat32Array()
	var fog := PackedFloat32Array()
	var wind := PackedVector3Array()
	temp.resize(n)
	swing.resize(n)
	precip.resize(n)
	moist.resize(n)
	fog.resize(n)
	wind.resize(n)

	for c in n:
		var d := map.dir[c]
		var elev := map.elevation[c]
		var above_sea := maxf(elev, 0.0)
		var w := weather.sample_vec(weather.avg_wind, d)
		wind[c] = w
		temp[c] = weather.sample(weather.avg_temp, d) - above_sea * PlanetConst.LAPSE_RATE_C_PER_M
		swing[c] = weather.sample(weather.avg_swing, d)
		var p := weather.sample(weather.avg_precip_mm, d)
		var f := weather.sample(weather.avg_fog, d)

		var upslope := 0.0
		if map.water[c] != PlanetData.Water.OCEAN and w.length() > 0.3:
			var terrain := _terrain_factors(map, d, elev, w.normalized())
			upslope = terrain.y
			p *= clampf(1.0 + WINDWARD_GAIN * upslope, 0.6, MAX_WINDWARD) * terrain.x
		precip[c] = p

		var m := _moisture_index(p, temp[c])
		moist[c] = m
		var coastal := clampf(1.0 - map.coast_dist_km[c] / 6.0, 0.0, 1.0)
		# Fog needs moist air; it thickens where wind pushes that air uphill
		# (windward slopes, cloud-forest belts) and along coasts.
		fog[c] = clampf((0.5 * f + 2.5 * maxf(upslope, 0.0) + 0.3 * coastal) * m * m, 0.0, 1.0)

	map.temp_c = temp
	map.temp_swing_c = swing
	map.precip_mm = precip
	map.moisture = moist
	map.fog = fog
	map.wind_avg = wind


## x = rain-shadow factor (1 = open, down to MIN_SHADOW behind a big
## ridge), y = upslope along the wind at this cell (rise over run).
static func _terrain_factors(map: PlanetData, d: Vector3, elev: float, wind_dir: Vector3) -> Vector2:
	var step_rad := UPWIND_STEP_M / PlanetConst.RADIUS_M
	var p := d
	var barrier := 0.0
	var first_upwind := elev
	for s in UPWIND_STEPS:
		p = (p - wind_dir * step_rad).normalized()
		var e := map.sample(map.elevation, p)
		if s == 0:
			first_upwind = e
		barrier = maxf(barrier, e - elev)
	var shadow := clampf(1.0 / (1.0 + barrier / SHADOW_HEIGHT_M), MIN_SHADOW, 1.0)
	# Earth-equivalent slope, like the blueprint's.
	var upslope := (elev - first_upwind) / UPWIND_STEP_M / PlanetConst.HEIGHT_SCALE
	return Vector2(shadow, upslope)


## Aridity index (precipitation / potential evapotranspiration) squashed to
## 0-1. PET rises with temperature, so the same rainfall is "wetter" in the
## cold than in the heat. ~0.1 hyper-arid, ~0.3 semi-arid, ~0.6 humid.
static func _moisture_index(precip_mm: float, temp_c: float) -> float:
	var pet := 250.0 + 55.0 * maxf(temp_c, 0.0)
	var r := precip_mm / pet
	return clampf(r / (r + 0.6), 0.0, 1.0)
