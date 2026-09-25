class_name TerrainField
extends RefCounted
## Continuous planet elevation (meters above sea level) at any unit
## direction. Seamless everywhere on the sphere because it samples 3D noise
## at the surface point, not per-face 2D noise.
##
## Both the coarse planet blueprint (PlanetGenerator, ~1 km cells) and the
## walkable terrain chunks (TerrainChunk, a few meters per cell) call this
## same function, so they always agree about where land, coast and
## mountains are. Chunks add a fine detail layer on top (detail = true).
##
## Layers:
##   continent  - big low-frequency shapes; its value decides land vs sea.
##                The land/sea threshold is calibrated at construction so
##                the planet ends up with exactly `ocean_fraction` ocean.
##   belts      - where mountain ranges are allowed (long linear belts).
##   ridges     - ridged noise inside the belts: the actual mountain crests.
##   hills      - rolling relief over all land.
##   hotspots   - a few seeded volcanic cones with craters (volcanic
##                fields, hot springs).
##   detail     - meter-scale roughness for walking; blueprint skips it.
##   roll       - gentle ~60 m swells (a couple of meters) so slopes roll
##                at walking scale; fades out near sea level so coastlines
##                keep their shape. Blueprint skips it too.

const MAX_MOUNTAIN_M := 4200.0
const MAX_PLATEAU_M := 700.0
const HILLS_M := 170.0
const MAX_DEPTH_M := 3800.0
const SHELF_DEPTH_M := 140.0
const DETAIL_M := 14.0
const ROLL_M := 2.0

const HOTSPOT_COUNT := 9
const HOTSPOT_HEIGHT_M := Vector2(700.0, 2000.0)
const HOTSPOT_RADIUS_M := Vector2(3500.0, 7000.0)

var world_seed: int
var ocean_fraction: float
var sea_threshold := 0.0

## Hotspot directions and parameters, public so GeologyPass can mark
## volcanic rock around them.
var hotspot_dirs: Array[Vector3] = []
var hotspot_heights: PackedFloat32Array = PackedFloat32Array()
var hotspot_radii: PackedFloat32Array = PackedFloat32Array()

var _continent := FastNoiseLite.new()
var _belts := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _shore := FastNoiseLite.new()
var _roll := FastNoiseLite.new()


func _init(p_seed: int, p_ocean_fraction := 0.62) -> void:
	world_seed = p_seed
	ocean_fraction = p_ocean_fraction

	_setup(_continent, 0, 1.0 / 70000.0, 5)
	_setup(_belts, 1, 1.0 / 45000.0, 2)
	_setup(_ridges, 2, 1.0 / 30000.0, 3)
	_setup(_hills, 3, 1.0 / 8000.0, 3)
	_setup(_detail, 4, 1.0 / 180.0, 3)
	_setup(_shore, 5, 1.0 / 900.0, 2)
	_setup(_roll, 6, 1.0 / 60.0, 2)

	_calibrate_sea_threshold()
	_place_hotspots()


func _setup(noise: FastNoiseLite, seed_offset: int, frequency: float, octaves: int) -> void:
	noise.seed = world_seed * 7919 + seed_offset
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves


## Samples the continent layer at many seeded random points and picks the
## value below which `ocean_fraction` of the planet lies.
func _calibrate_sea_threshold() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 11
	var samples := PackedFloat32Array()
	for i in 6000:
		samples.append(_continent_value(_random_dir(rng)))
	samples.sort()
	sea_threshold = samples[int(ocean_fraction * (samples.size() - 1))]


func _place_hotspots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 23
	for i in HOTSPOT_COUNT:
		hotspot_dirs.append(_random_dir(rng))
		hotspot_heights.append(rng.randf_range(HOTSPOT_HEIGHT_M.x, HOTSPOT_HEIGHT_M.y))
		hotspot_radii.append(rng.randf_range(HOTSPOT_RADIUS_M.x, HOTSPOT_RADIUS_M.y))


static func _random_dir(rng: RandomNumberGenerator) -> Vector3:
	# Uniform on the sphere.
	var z := rng.randf_range(-1.0, 1.0)
	var t := rng.randf_range(0.0, TAU)
	var r := sqrt(1.0 - z * z)
	return Vector3(r * cos(t), z, r * sin(t))


func _continent_value(dir: Vector3) -> float:
	var p := dir * PlanetConst.RADIUS_M
	return _continent.get_noise_3dv(p)


## How far inland a point is, in continent-noise units (> 0 is land).
func landness(dir: Vector3) -> float:
	return _continent_value(dir) - sea_threshold


## `roll` false leaves out the walking-scale roll layer (Ruins uses that to
## pick sites, so ruins don't move with 2 m of noise).
func elevation(dir: Vector3, detail := false, roll := true) -> float:
	var p := dir * PlanetConst.RADIUS_M
	var x := _continent.get_noise_3dv(p) - sea_threshold
	var e: float
	if x > 0.0:
		var inland := smoothstep(0.0, 0.35, x)
		var plateau := MAX_PLATEAU_M * pow(inland, 1.5) + 2.0
		var belt := smoothstep(0.05, 0.4, _belts.get_noise_3dv(p))
		# Soft absolute value rounds the ridge crest instead of a knife edge.
		var rn := _ridges.get_noise_3dv(p)
		var ridge := 1.0 - sqrt(rn * rn + 0.004)
		var mountains := MAX_MOUNTAIN_M * smoothstep(0.35, 1.0, ridge) * belt * smoothstep(0.02, 0.16, x)
		var hills := _hills.get_noise_3dv(p) * HILLS_M * (0.25 + inland) * smoothstep(0.0, 0.05, x)
		e = plateau + mountains + hills
	else:
		# Shallow continental shelf near the coast, then the drop to the deep.
		var shelf := SHELF_DEPTH_M * smoothstep(0.0, 0.06, -x)
		var deep := (MAX_DEPTH_M - SHELF_DEPTH_M) * pow(smoothstep(0.05, 0.4, -x), 1.2)
		e = -2.0 - shelf - deep
	e += _hotspot_height(dir)
	if detail:
		# Shore noise is small but wiggles the coastline at walking scale.
		e += _detail.get_noise_3dv(p) * DETAIL_M + _shore.get_noise_3dv(p) * 6.0
		if roll:
			e += _roll.get_noise_3dv(p) * ROLL_M * smoothstep(1.5, 6.0, absf(e))
	return e


func _hotspot_height(dir: Vector3) -> float:
	var total := 0.0
	for i in hotspot_dirs.size():
		var cos_angle := dir.dot(hotspot_dirs[i])
		# Cheap reject: only points within ~0.12 rad can be inside a cone.
		if cos_angle < 0.99:
			continue
		var dist := CubeSphere.surface_distance_m(dir, hotspot_dirs[i])
		var r := hotspot_radii[i]
		if dist >= r:
			continue
		var t := 1.0 - dist / r
		var cone := hotspot_heights[i] * pow(t, 1.6)
		# Crater: a bowl in the top 10% of the radius.
		var crater_r := r * 0.1
		if dist < crater_r:
			cone -= hotspot_heights[i] * 0.12 * (1.0 - dist / crater_r)
		total += cone
	return total


## Unit direction of the nearest hotspot and its distance in meters.
func nearest_hotspot(dir: Vector3) -> Dictionary:
	var best := -1
	var best_dot := -2.0
	for i in hotspot_dirs.size():
		var d := dir.dot(hotspot_dirs[i])
		if d > best_dot:
			best_dot = d
			best = i
	return {
		"index": best,
		"distance_m": CubeSphere.surface_distance_m(dir, hotspot_dirs[best]),
		"radius_m": hotspot_radii[best],
	}
