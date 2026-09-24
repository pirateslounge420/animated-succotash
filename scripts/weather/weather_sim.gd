class_name WeatherSim
extends RefCounted
## Coarse, causal weather simulation (DESIGN.md "Weather System").
##
## A second, much coarser cube-sphere grid (6 x RES x RES cells, 600 at
## RES = 10) sits over the terrain. Each cell holds pressure, temperature
## and humidity. The planet's own rules, applied every tick:
##
##   * Wind comes only from pressure differences (high -> low), turned by a
##     fixed latitude-scaled angle, plus a cheap prevailing bias by
##     latitude (easterly trades, mid-latitude westerlies). No Coriolis
##     simulation.
##   * Humidity, plus temperature and pressure *anomalies* (departures from
##     the latitude's norm), are carried along the wind (semi-Lagrangian:
##     each cell looks back upwind and takes what was there), so warm, wet
##     air drifts across the planet like a front. Carrying anomalies rather
##     than absolute temperature keeps the climate bands stable on a planet
##     this small; moist air that drifts somewhere colder still rains out.
##   * The sun heats the day side; land heats and cools fast, water slowly.
##     Pressure sits on latitude belts (equatorial low, subtropical highs,
##     subpolar lows, polar highs) and drops where it's warm.
##   * Water surfaces evaporate. When air is forced up over high ground it
##     cools, can't hold its moisture and rains out; what reaches the far
##     side is dry. Rain shadows are not scripted, they come out of this.
##   * Condensing moisture releases heat and lowers pressure, which pulls
##     in more moist air. That feedback makes storms. A cell is labeled
##     stormy when its pressure is low and its air nearly saturated;
##     clear skies are high pressure and dry air. Neither is scripted.
##   * Precipitation falls as snow below freezing, rain above.
##   * Weather systems travel. The coarse grid alone settles into a steady
##     state (its advection smooths anomalies away), so the sim also
##     carries a handful of synoptic systems: mid-latitude lows born in the
##     westerly belts, tropical cyclones over warm ocean, and broad highs.
##     Each is seeded, steered by the simulated wind, grows and decays over
##     a few days, and adds its pressure to the field. Everything else
##     (wind from the gradient, rising air, rain, latent-heat storms,
##     clearing under highs) responds to that pressure through the same
##     rules, so a passing low backs the wind, clouds over, rains and
##     clears again.
##   * At the player, local_weather() adds what the 10 km grid can't
##     resolve: land/sea breezes (onshore in the afternoon, offshore at
##     night) and gusts.
##
## The starting state is seeded from the world seed. Rules never change;
## the chaos comes from the starting state.
##
## Use:
##   spin_up() runs many simulated days and records long-term averages
##   (ClimatePass classifies biomes from them). After that, step() keeps
##   the same simulation running live; the sample_*() queries feed wind to
##   foliage and rain/snow to the particle effects.

const RES := 10

# Rule tuning.
const WIND_PER_GRADIENT := 9.0 # m/s per (hPa/km)
## Pressure-driven wind is turned by up to this angle (right in the north,
## left in the south), scaled by sin(latitude). A fixed rule standing in
## for Coriolis turning without simulating it: without it, air runs
## straight down the latitude belts and hauls tropical heat to the poles.
const TURN_MAX_DEG := 80.0
const MAX_WIND := 28.0
var pressure_relax_h := 60.0
var pressure_diffusion_per_h := 0.12
var thermal_pressure := 0.8 # hPa lower per degree warmer than the latitude norm
const LAND_TEMP_RELAX_H := 7.0
const WATER_TEMP_RELAX_H := 60.0
const DIURNAL_HEATING := 15.0 # °C swing scale for land in full sun
const CLOUD_SHADE := 0.7 # share of sunlight blocked by full cloud
const EVAPORATION_PER_H := 0.25
const LAND_EVAPORATION_PER_H := 0.012
const CONDENSE_TIME_H := 2.0 # e-folding time for excess moisture to rain out
var max_latent_drop_per_h := 1.5 # hPa
const MM_PER_G_KG := 2.2 # precipitable-water column per g/kg condensed
const LATENT_HEAT_C := 0.12 # °C of warming per g/kg condensed
var latent_pressure := 2.0 # hPa drop per g/kg condensed
const STORM_PRESSURE := -5.0 # hPa anomaly
const STORM_HUMIDITY := 0.88 # relative humidity
const CLEAR_PRESSURE := 4.0
const CLEAR_HUMIDITY := 0.55
const OROGRAPHIC_LIFT := 0.45 # how much of the peak height (vs mean) lifted air feels
const RISING_COOL_C_PER_HPA := 1.4
const SINKING_WARM_C_PER_HPA := 0.6
## Global rescale so mean precipitation lands near Earth's ~1000 mm/yr.
const TARGET_MEAN_PRECIP_MM := 1000.0
const SYSTEM_COUNT := 11
const SEA_BREEZE_MPS := 3.5
const GUST := 0.3 # +-30% speed, and a direction wobble

var world_seed: int
var cells: int
var dirs := PackedVector3Array()
var lats := PackedFloat32Array()
var nbr := PackedInt32Array() # 8 per cell
var nbr_tan := PackedVector3Array() # unit tangent from cell toward neighbor
var nbr_dist_km := PackedFloat32Array()
var spacing_rad := PackedFloat32Array() # distance to nearest neighbor, radians

# Terrain under each cell, aggregated from the planet blueprint.
var elev_mean := PackedFloat32Array()
var elev_max := PackedFloat32Array()
var water_frac := PackedFloat32Array()

# Live state.
var pressure := PackedFloat32Array() # hPa anomaly from 1013
var temp := PackedFloat32Array() # °C, sea-level equivalent
var humidity := PackedFloat32Array() # g/kg
var wind := PackedVector3Array() # m/s, tangent to the surface
var precip_rate := PackedFloat32Array() # mm per in-game hour, last tick
var rel_humidity := PackedFloat32Array()
var storm := PackedByteArray()
var storm_level := PackedFloat32Array() # 0-1 continuous storm intensity
var synoptic := PackedFloat32Array() # hPa from traveling weather systems
## Traveling systems: {dir, amp (hPa), radius_km, age_h, life_h, tropical}.
var systems: Array = []
var _sys_rng := RandomNumberGenerator.new()
var _sun := Vector3.UP
var toward_land := PackedVector3Array() # unit tangent from sea toward land (0 inland/offshore)
var clear := PackedByteArray()
var hours := 0.0 # simulated in-game hours since the start state

# Long-term averages (valid after spin_up()).
var avg_temp := PackedFloat32Array() # sea-level equivalent °C
var avg_swing := PackedFloat32Array() # mean daily high - low, °C
var avg_precip_mm := PackedFloat32Array() # annual equivalent
var avg_wind := PackedVector3Array()
var avg_fog := PackedFloat32Array() # share of time saturated and calm
var avg_storm := PackedFloat32Array() # share of time stormy
var precip_scale := 1.0


func _init(planet: PlanetData) -> void:
	world_seed = planet.terrain.world_seed
	cells = 6 * RES * RES
	_build_grid()
	_aggregate_terrain(planet)
	_seed_state()


static func cell_index(face: int, i: int, j: int) -> int:
	return face * RES * RES + j * RES + i


static func _uv(i: int) -> float:
	return (float(i) + 0.5) / RES * 2.0 - 1.0


func cell_at(d: Vector3) -> int:
	var f := CubeSphere.face_of(d)
	var uv := CubeSphere.face_uv(f, d)
	var i := clampi(int((uv.x + 1.0) * 0.5 * RES), 0, RES - 1)
	var j := clampi(int((uv.y + 1.0) * 0.5 * RES), 0, RES - 1)
	return cell_index(f, i, j)


func _build_grid() -> void:
	dirs.resize(cells)
	lats.resize(cells)
	for f in 6:
		for j in RES:
			for i in RES:
				var d := CubeSphere.to_dir(f, _uv(i), _uv(j))
				dirs[cell_index(f, i, j)] = d
				lats[cell_index(f, i, j)] = CubeSphere.latitude(d)
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	nbr.resize(cells * 8)
	nbr_tan.resize(cells * 8)
	nbr_dist_km.resize(cells * 8)
	for f in 6:
		for j in RES:
			for i in RES:
				var c := cell_index(f, i, j)
				for k in 8:
					var ni := i + offsets[k].x
					var nj := j + offsets[k].y
					var n: int
					if ni >= 0 and ni < RES and nj >= 0 and nj < RES:
						n = cell_index(f, ni, nj)
					else:
						n = cell_at(CubeSphere.to_dir(f, _uv(ni), _uv(nj)))
					nbr[c * 8 + k] = n
					var d := dirs[c]
					var to_n := dirs[n] - d * dirs[n].dot(d)
					nbr_tan[c * 8 + k] = to_n.normalized()
					nbr_dist_km[c * 8 + k] = CubeSphere.surface_distance_m(d, dirs[n]) / 1000.0
	spacing_rad.resize(cells)
	for c in cells:
		var m := INF
		for k in 4:
			m = minf(m, nbr_dist_km[c * 8 + k])
		spacing_rad[c] = m * 1000.0 / PlanetConst.RADIUS_M


func _aggregate_terrain(planet: PlanetData) -> void:
	elev_mean.resize(cells)
	elev_max.resize(cells)
	water_frac.resize(cells)
	elev_max.fill(-INF)
	var counts := PackedInt32Array()
	counts.resize(cells)
	for c in planet.cell_count:
		var w := cell_at(planet.dir[c])
		var e := maxf(planet.elevation[c], 0.0)
		elev_mean[w] += e
		elev_max[w] = maxf(elev_max[w], e)
		if planet.water[c] == PlanetData.Water.OCEAN or planet.water[c] == PlanetData.Water.LAKE:
			water_frac[w] += 1.0
		counts[w] += 1
	for w in cells:
		var n := maxf(counts[w], 1.0)
		elev_mean[w] /= n
		water_frac[w] /= n
	# Direction from sea toward land, for sea breezes: the gradient of land
	# share, strongest along coasts.
	toward_land.resize(cells)
	for c in cells:
		var grad := Vector3.ZERO
		for k in 8:
			var nb := nbr[c * 8 + k]
			grad += nbr_tan[c * 8 + k] * (water_frac[c] - water_frac[nb]) / nbr_dist_km[c * 8 + k]
		grad *= 0.25
		toward_land[c] = grad.normalized() * clampf(grad.length() * 8.0, 0.0, 1.0) if grad.length() > 1e-4 else Vector3.ZERO


func _seed_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * 31 + 7
	pressure.resize(cells)
	temp.resize(cells)
	humidity.resize(cells)
	wind.resize(cells)
	precip_rate.resize(cells)
	rel_humidity.resize(cells)
	storm.resize(cells)
	clear.resize(cells)
	storm_level.resize(cells)
	synoptic.resize(cells)
	_sys_rng.seed = world_seed * 97 + 3
	for c in cells:
		pressure[c] = _belt_pressure(lats[c]) + rng.randf_range(-6.0, 6.0)
		temp[c] = base_temp(lats[c]) + rng.randf_range(-3.0, 3.0)
		humidity[c] = saturation(temp[c]) * rng.randf_range(0.3, 0.8)
		var angle := rng.randf_range(0.0, TAU)
		wind[c] = (CubeSphere.east(dirs[c]) * cos(angle) + CubeSphere.north(dirs[c]) * sin(angle)) * rng.randf_range(0.0, 4.0)


## Sea-level mean temperature by latitude: ~28 °C at the equator, ~-22 °C
## at the poles.
static func base_temp(lat: float) -> float:
	return 28.0 - 50.0 * pow(absf(sin(lat)), 3.0)


## Latitude pressure belts: low at the equator and ~60°, high at ~30° and
## the poles. The rising equatorial low is the deepest (rainforest belt);
## the sinking subtropical highs dry out the deserts.
static func _belt_pressure(lat: float) -> float:
	var a := absf(lat)
	return -lerpf(12.0, 3.0, a / (PI * 0.5)) * cos(6.0 * a)


## Prevailing wind, eastward component in m/s: easterly trades near the
## equator, westerlies in the mid-latitudes.
static func _prevailing_east(lat: float) -> float:
	return -5.5 * cos(3.0 * absf(lat))


## Saturation mixing ratio in g/kg (Magnus formula at ~1000 hPa).
static func saturation(t_c: float) -> float:
	var es := 6.112 * exp(17.67 * t_c / (t_c + 243.5))
	return 622.0 * es / 1000.0


## Temperature air actually has over this cell's ground. Air crossing
## ridges is lifted partway toward the peak, not just the mean height.
func surface_temp(c: int) -> float:
	var lift := lerpf(elev_mean[c], elev_max[c], OROGRAPHIC_LIFT)
	return temp[c] - lift * PlanetConst.LAPSE_RATE_C_PER_M


## One tick of dt_h in-game hours. sun is the planet-fixed sun direction.
func step(dt_h: float, sun: Vector3) -> void:
	_sun = sun
	_update_systems(dt_h)
	_update_wind()
	_advect(dt_h)
	_apply_physics(dt_h, sun)
	_smooth_pressure(dt_h)
	hours += dt_h


## Light pressure diffusion between neighbors, plus mass conservation. Keeps the explicit latent
## heat feedback from flickering at grid scale; real lows are wider than a
## cell anyway.
func _smooth_pressure(dt_h: float) -> void:
	var k := minf(pressure_diffusion_per_h * dt_h, 0.5)
	var out := PackedFloat32Array()
	out.resize(cells)
	var mean_anomaly := 0.0
	for c in cells:
		var avg := 0.0
		for j in 4:
			avg += pressure[nbr[c * 8 + j]]
		out[c] = lerpf(pressure[c], avg * 0.25, k)
		mean_anomaly += out[c] - _belt_pressure(lats[c])
	# Conserve total air mass: a low is only low relative to the rest of
	# the planet, so the whole planet can't drift into a permanent storm.
	mean_anomaly /= cells
	for c in cells:
		out[c] -= mean_anomaly
	pressure = out


func _update_wind() -> void:
	for c in cells:
		var grad := Vector3.ZERO
		for k in 8:
			var n := nbr[c * 8 + k]
			grad += nbr_tan[c * 8 + k] * ((pressure[n] + synoptic[n]) - (pressure[c] + synoptic[c])) / nbr_dist_km[c * 8 + k]
		grad *= 0.25 # 8 neighbors ~ 2 samples per axis
		var w := -grad * WIND_PER_GRADIENT # high -> low
		var turn := deg_to_rad(TURN_MAX_DEG) * sin(lats[c])
		w = w * cos(turn) + w.cross(dirs[c]) * sin(turn)
		w += CubeSphere.east(dirs[c]) * _prevailing_east(lats[c])
		# Mountains slow the wind that has to climb them.
		w *= 1.0 / (1.0 + elev_max[c] / 2500.0)
		if w.length() > MAX_WIND:
			w = w.normalized() * MAX_WIND
		wind[c] = w


## Semi-Lagrangian advection: each cell takes the air that was upwind of it
## dt_h hours ago. Unconditionally stable at any wind speed.
func _advect(dt_h: float) -> void:
	var anom_p := PackedFloat32Array()
	var anom_t := PackedFloat32Array()
	anom_p.resize(cells)
	anom_t.resize(cells)
	for c in cells:
		anom_p[c] = pressure[c] - _belt_pressure(lats[c])
		anom_t[c] = temp[c] - base_temp(lats[c])
	var new_p := PackedFloat32Array()
	var new_t := PackedFloat32Array()
	var new_q := PackedFloat32Array()
	new_p.resize(cells)
	new_t.resize(cells)
	new_q.resize(cells)
	for c in cells:
		var w := wind[c]
		var dist_m := w.length() * 3600.0 * dt_h
		var s := Vector3(anom_p[c], anom_t[c], humidity[c])
		if dist_m >= 1.0:
			var back := (dirs[c] - w.normalized() * (dist_m / PlanetConst.RADIUS_M)).normalized()
			s = _sample_anomalies(back, anom_p, anom_t)
		new_p[c] = _belt_pressure(lats[c]) + s.x
		new_t[c] = base_temp(lats[c]) + s.y
		new_q[c] = s.z
	pressure = new_p
	temp = new_t
	humidity = new_q


## Kernel blend of (pressure anomaly, temperature anomaly, humidity).
func _sample_anomalies(d: Vector3, anom_p: PackedFloat32Array, anom_t: PackedFloat32Array) -> Vector3:
	var c := cell_at(d)
	var total := 0.0
	var acc := Vector3.ZERO
	for k in 9:
		var n := c if k == 8 else nbr[c * 8 + k]
		var wgt := _kernel(d, n, c)
		acc += Vector3(anom_p[n], anom_t[n], humidity[n]) * wgt
		total += wgt
	return acc / total


func _apply_physics(dt_h: float, sun: Vector3) -> void:
	for c in cells:
		var lat := lats[c]
		var wf := water_frac[c]

		# Radiation: relax toward the latitude norm plus today's sunshine,
		# dimmed by cloud. Shaded ground cools, raising pressure, which
		# sinks and dries the air and breaks the cloud up again; one of the
		# feedbacks that keeps the weather moving instead of settling.
		var cloud := smoothstep(0.7, 1.0, rel_humidity[c])
		var sunlight := maxf(0.0, dirs[c].dot(sun)) * (1.0 - CLOUD_SHADE * cloud)
		var insolation := sunlight - cos(lat) / PI
		var heating := DIURNAL_HEATING * insolation * lerpf(1.0, 0.18, wf)
		var target_t := base_temp(lat) + heating
		var tau := lerpf(LAND_TEMP_RELAX_H, WATER_TEMP_RELAX_H, wf)
		temp[c] += (target_t - temp[c]) * minf(dt_h / tau, 1.0)

		# Pressure: belts plus thermal lows over warm air.
		var target_p := _belt_pressure(lat) - thermal_pressure * (temp[c] - base_temp(lat))
		pressure[c] += (target_p - pressure[c]) * minf(dt_h / pressure_relax_h, 1.0)

		# Air rises in low pressure (cooling, so it can hold less water) and
		# sinks in high pressure (warming, drying). This is what makes the
		# equatorial and subpolar lows rainy and the subtropical highs desert.
		var p := pressure[c] + synoptic[c]
		var vertical := p * RISING_COOL_C_PER_HPA if p < 0.0 else p * SINKING_WARM_C_PER_HPA
		var t_surf := surface_temp(c)
		var q_sat := saturation(t_surf + vertical)

		# Evaporation from water (and a little from land) fills toward what
		# air at the warm surface can hold, which can exceed q_sat above.
		var deficit := maxf(saturation(t_surf) - humidity[c], 0.0)
		humidity[c] += deficit * (EVAPORATION_PER_H * wf + LAND_EVAPORATION_PER_H * (1.0 - wf)) * dt_h

		# Condensation and precipitation.
		var rain := 0.0
		if humidity[c] > q_sat:
			var condensed := (humidity[c] - q_sat) * (1.0 - exp(-dt_h / CONDENSE_TIME_H))
			humidity[c] -= condensed
			rain = condensed * MM_PER_G_KG
			temp[c] += condensed * LATENT_HEAT_C
			pressure[c] -= minf(condensed * latent_pressure, max_latent_drop_per_h * dt_h)
		var rh := humidity[c] / maxf(q_sat, 0.01)
		# Storms rain out extra moisture even below full saturation.
		var anomaly := pressure[c] + synoptic[c] - _belt_pressure(lat)
		var stormy := anomaly < STORM_PRESSURE and rh > STORM_HUMIDITY
		if stormy:
			var extra := humidity[c] * 0.04 * dt_h
			humidity[c] -= extra
			rain += extra * MM_PER_G_KG
			pressure[c] -= minf(extra * latent_pressure, max_latent_drop_per_h * dt_h)
		precip_rate[c] = rain / dt_h
		rel_humidity[c] = minf(rh, 1.0)
		storm[c] = 1 if stormy else 0
		# Continuous intensity for effects: ramps in as pressure falls and
		# the air saturates, so a storm builds and fades instead of switching.
		storm_level[c] = (1.0 - smoothstep(STORM_PRESSURE * 1.7, STORM_PRESSURE * 0.8, anomaly)) * smoothstep(0.82, 0.97, rh)
		clear[c] = 1 if (anomaly > CLEAR_PRESSURE and rh < CLEAR_HUMIDITY) else 0


## Runs the simulation long enough to settle, then averages. Both phases
## include the day-night cycle.
func spin_up(settle_days := 8.0, average_days := 12.0, dt_h := 1.5) -> void:
	var settle_steps := int(settle_days * 24.0 / dt_h)
	var avg_steps := int(average_days * 24.0 / dt_h)
	for s in settle_steps:
		step(dt_h, Astro.sun_dir(hours / 24.0))

	var sum_t := PackedFloat32Array()
	var sum_p := PackedFloat32Array()
	var sum_fog := PackedFloat32Array()
	var sum_storm := PackedFloat32Array()
	var sum_swing := PackedFloat32Array()
	var day_min := PackedFloat32Array()
	var day_max := PackedFloat32Array()
	var sum_w := PackedVector3Array()
	sum_t.resize(cells)
	sum_p.resize(cells)
	sum_fog.resize(cells)
	sum_storm.resize(cells)
	sum_swing.resize(cells)
	day_min.resize(cells)
	day_max.resize(cells)
	sum_w.resize(cells)
	day_min.fill(INF)
	day_max.fill(-INF)
	var days_done := 0
	var steps_per_day := int(round(24.0 / dt_h))

	for s in avg_steps:
		step(dt_h, Astro.sun_dir(hours / 24.0))
		for c in cells:
			sum_t[c] += temp[c]
			sum_p[c] += precip_rate[c] * dt_h
			sum_w[c] += wind[c]
			if rel_humidity[c] > 0.97 and wind[c].length() < 6.0:
				sum_fog[c] += 1.0
			sum_storm[c] += storm[c]
			day_min[c] = minf(day_min[c], temp[c])
			day_max[c] = maxf(day_max[c], temp[c])
		if (s + 1) % steps_per_day == 0:
			days_done += 1
			for c in cells:
				sum_swing[c] += day_max[c] - day_min[c]
			day_min.fill(INF)
			day_max.fill(-INF)

	avg_temp.resize(cells)
	avg_precip_mm.resize(cells)
	avg_wind.resize(cells)
	avg_fog.resize(cells)
	avg_storm.resize(cells)
	avg_swing.resize(cells)
	var mean_annual := 0.0
	for c in cells:
		avg_temp[c] = sum_t[c] / avg_steps
		avg_precip_mm[c] = sum_p[c] * 365.0 / average_days
		avg_wind[c] = sum_w[c] / avg_steps
		avg_fog[c] = sum_fog[c] / avg_steps
		avg_storm[c] = sum_storm[c] / avg_steps
		avg_swing[c] = sum_swing[c] / maxf(days_done, 1.0)
		mean_annual += avg_precip_mm[c]
	mean_annual /= cells
	precip_scale = TARGET_MEAN_PRECIP_MM / maxf(mean_annual, 1.0)
	for c in cells:
		avg_precip_mm[c] *= precip_scale


## Tent kernel reaching just past the nearest neighbors, so a point at a
## cell center reads that cell alone. A wide kernel here smears heat and
## moisture across the planet within days (numerical diffusion).
func _kernel(d: Vector3, n: int, center: int) -> float:
	var ang := CubeSphere.angle_between(d, dirs[n])
	var t := maxf(0.0, 1.0 - ang / (spacing_rad[center] * 1.05))
	return t * t + (1e-6 if n == center else 0.0)


## Smooth interpolation of any per-cell float field at a direction.
func sample(field: PackedFloat32Array, d: Vector3) -> float:
	var c := cell_at(d)
	var total := 0.0
	var acc := 0.0
	for k in 9:
		var n := c if k == 8 else nbr[c * 8 + k]
		var wgt := _kernel(d, n, c)
		acc += field[n] * wgt
		total += wgt
	return acc / total


func sample_vec(field: PackedVector3Array, d: Vector3) -> Vector3:
	var c := cell_at(d)
	var total := 0.0
	var acc := Vector3.ZERO
	for k in 9:
		var n := c if k == 8 else nbr[c * 8 + k]
		var wgt := _kernel(d, n, c)
		acc += field[n] * wgt
		total += wgt
	var v := acc / total
	return v - d * v.dot(d) # keep it tangent


## Live weather at a surface point, for effects and foliage.
##   wind: m/s tangent vector; rain_mm_h: precipitation rate (already
##   rescaled like the averages); snow: true below freezing at this
##   elevation; storm/cloud: 0-1.
func local_weather(d: Vector3, elevation_m: float) -> Dictionary:
	var t_air := sample(temp, d) - maxf(elevation_m, 0.0) * PlanetConst.LAPSE_RATE_C_PER_M
	var c := cell_at(d)
	var w := sample_vec(wind, d)
	# Land/sea breeze: sun-warmed land draws air in off the water by day;
	# at night the land cools faster and the breeze turns offshore.
	var sunlight := maxf(0.0, d.dot(_sun))
	w += sample_vec(toward_land, d) * SEA_BREEZE_MPS * (sunlight * 1.6 - 0.45)
	# Gusts: slow swells in speed and a wobble in direction, a few per
	# in-game hour, never quite repeating.
	var t := hours
	var swell := sin(t * 5.1 + d.x * 40.0) * 0.6 + sin(t * 13.7 + d.z * 40.0) * 0.4
	var wobble := deg_to_rad(14.0) * (sin(t * 3.3 + d.y * 50.0) * 0.7 + sin(t * 8.9) * 0.3)
	w = w.rotated(d, wobble) * (1.0 + GUST * swell)
	# Showers: the grid's rain rate is an average over ~10 km. Locally it
	# falls from drifting shower cells covering part of the area, the more
	# of it the heavier the rain (storms cover nearly everything), each
	# raining harder so the long-run total is unchanged.
	var areal := sample(precip_rate, d) * precip_scale
	var storm_now := clampf(sample(storm_level, d), 0.0, 1.0)
	var cover := clampf(areal / 2.5 + storm_now * 0.7, 0.06, 1.0)
	var shower := _shower_mask(d, w, cover)
	var cloud := smoothstep(0.55, 0.95, sample(rel_humidity, d))
	return {
		"wind": w,
		"rain_mm_h": areal / cover * shower if areal > 0.02 else 0.0,
		"shower": shower,
		"snow": t_air < 0.0,
		"temp_c": t_air,
		"storm": storm_now,
		"clear": float(clear[c]),
		"cloud": maxf(cloud, shower * minf(areal * 2.0, 1.0) * 0.95),
	}


var _shower_noise: FastNoiseLite
var _shower_quantiles := PackedFloat32Array()
var _shower_offset := Vector3.ZERO
var _shower_hours := -1.0


## 0-1: how much of a shower cell is over `d` right now, for a field where
## `cover` (0-1) of the area is under showers. The cells drift downwind.
func _shower_mask(d: Vector3, w: Vector3, cover: float) -> float:
	if _shower_noise == null:
		_shower_noise = FastNoiseLite.new()
		_shower_noise.seed = world_seed + 404
		_shower_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_shower_noise.frequency = 0.35 # per km: cells a few km across
		_shower_noise.fractal_octaves = 2
		# Calibrate: value above which a given share of the field lies.
		var vals := PackedFloat32Array()
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 4000:
			vals.append(_shower_noise.get_noise_3d(rng.randf() * 500.0, rng.randf() * 500.0, rng.randf() * 500.0))
		vals.sort()
		for q in 21:
			_shower_quantiles.append(vals[mini(int(q / 20.0 * vals.size()), vals.size() - 1)])
	if _shower_hours >= 0.0:
		_shower_offset += w * 3.6 * (hours - _shower_hours) # km
	_shower_hours = hours
	var p := d * (PlanetConst.RADIUS_M / 1000.0) - _shower_offset
	var n := _shower_noise.get_noise_3d(p.x, p.y, p.z)
	var qf := (1.0 - cover) * 20.0
	var qi := mini(int(qf), 19)
	var threshold := lerpf(_shower_quantiles[qi], _shower_quantiles[qi + 1], qf - qi)
	return smoothstep(threshold - 0.03, threshold + 0.03, n)


# --- Traveling weather systems -------------------------------------------------

func _update_systems(dt_h: float) -> void:
	var alive: Array = []
	for sys in systems:
		sys.age_h += dt_h
		if sys.age_h >= sys.life_h:
			continue
		# Steered by the surrounding flow; tropical cyclones also drift
		# poleward, like real ones recurving into the westerlies.
		var d: Vector3 = sys.dir
		var steer := sample_vec(wind, d) * 0.8
		if sys.tropical:
			steer += CubeSphere.north(d) * signf(d.y) * 2.0
		if steer.length() < 2.0:
			steer = CubeSphere.east(d) * _prevailing_east(asin(clampf(d.y, -1.0, 1.0))) + CubeSphere.north(d) * 0.5
		sys.dir = (d + steer * 3600.0 * dt_h / PlanetConst.RADIUS_M).normalized()
		alive.append(sys)
	systems = alive
	while systems.size() < SYSTEM_COUNT:
		systems.append(_spawn_system())
	synoptic.fill(0.0)
	for sys in systems:
		# Grow over the first fifth of its life, fade over the last third.
		var f: float = sys.age_h / sys.life_h
		var env := smoothstep(0.0, 0.2, f) * (1.0 - smoothstep(0.67, 1.0, f))
		var r_rad: float = sys.radius_km * 1000.0 / PlanetConst.RADIUS_M
		var min_dot := cos(r_rad * 2.5)
		var center: Vector3 = sys.dir
		var amp: float = sys.amp * env
		for c in cells:
			if dirs[c].dot(center) < min_dot:
				continue
			var ang := CubeSphere.angle_between(dirs[c], center)
			synoptic[c] += amp * exp(-(ang / r_rad) * (ang / r_rad))


func _spawn_system() -> Dictionary:
	var rng := _sys_rng
	for attempt in 200:
		var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var lat := absf(asin(clampf(d.y, -1.0, 1.0)))
		var c := cell_at(d)
		var roll := rng.randf()
		if roll < 0.3:
			# Broad high: subtropics and poles favored.
			if rng.randf() > 0.4 + 0.6 * absf(sin(2.0 * lat)):
				continue
			return {"dir": d, "amp": rng.randf_range(4.0, 7.0), "radius_km": rng.randf_range(28.0, 45.0),
				"age_h": rng.randf_range(0.0, 20.0), "life_h": rng.randf_range(72.0, 150.0), "tropical": false}
		if roll < 0.42:
			# Tropical cyclone: warm open ocean, 8-25 degrees.
			if lat < 0.14 or lat > 0.44 or water_frac[c] < 0.8 or temp[c] < 25.0:
				continue
			return {"dir": d, "amp": rng.randf_range(-12.0, -8.0), "radius_km": rng.randf_range(14.0, 22.0),
				"age_h": 0.0, "life_h": rng.randf_range(60.0, 130.0), "tropical": true}
		# Mid-latitude low: the westerly storm tracks, 35-65 degrees.
		if lat < 0.5 or lat > 1.2:
			continue
		return {"dir": d, "amp": rng.randf_range(-7.5, -4.0), "radius_km": rng.randf_range(20.0, 35.0),
			"age_h": rng.randf_range(0.0, 10.0), "life_h": rng.randf_range(48.0, 110.0), "tropical": false}
	return {"dir": Vector3.UP, "amp": 0.0, "radius_km": 20.0, "age_h": 0.0, "life_h": 24.0, "tropical": false}
