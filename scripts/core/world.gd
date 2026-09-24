extends Node
## Autoload "World": the one planet, its clock, its live weather, and the
## scene's floating origin.
##
## Generation runs on a background thread (it takes several seconds), with
## generation_progress for a loading screen. After that:
##
## * Clock: `days` advances at 48 real minutes per in-game day
##   (PlanetConst.DAY_LENGTH_S), scaled by `time_scale`.
## * Weather: the same WeatherSim that produced the long-term averages
##   keeps running live, one step per in-game quarter hour.
## * Floating origin: the planet is ~64 km in radius, so the scene keeps
##   the player near (0,0,0) and moves the planet instead. The planet's
##   center in scene coordinates is held in double precision (GDScript
##   floats are 64-bit; Vector3 is only 32-bit), and rebase() shifts
##   everything registered under `world_root` when the player strays too
##   far from the origin.

signal generation_progress(step: String, fraction: float)
signal generation_finished
signal origin_shifted(offset: Vector3)

const WEATHER_STEP_H := 0.25
const REBASE_DISTANCE_M := 1500.0

@export var world_seed := 42
## 1.0 = the 48-minute day. Raise it to watch the cycle faster.
@export var time_scale := 1.0

var planet: PlanetData
var weather: WeatherSim
var ready_to_play := false

## In-game days since the start; fraction is time of day (0.5 = noon at
## longitude 0). Starts on a mid-afternoon near full moon so a first session
## soon sees sunset, then the night the spec treats as the showpiece.
var days := 13.62

## Scene node whose direct children get shifted on rebase (terrain chunks,
## creatures, the far planet shell, ...). Set by the playable scene.
var world_root: Node3D

# Planet center in scene coordinates, double precision.
var _cx := 0.0
var _cy := 0.0
var _cz := 0.0
var _thread: Thread
var _weather_accum_h := 0.0


func generate(p_seed: int) -> void:
	world_seed = p_seed
	ready_to_play = false
	_thread = Thread.new()
	_thread.start(_generate_threaded.bind(p_seed))


func _generate_threaded(p_seed: int) -> void:
	var gen := PlanetGenerator.new()
	gen.progress.connect(func(step: String, f: float) -> void:
		call_deferred("_emit_progress", step, f))
	gen.generate(p_seed)
	planet = gen.planet
	weather = gen.weather
	call_deferred("_finish_generation")


func _emit_progress(step: String, f: float) -> void:
	generation_progress.emit(step, f)


func _finish_generation() -> void:
	_thread.wait_to_finish()
	_thread = null
	ready_to_play = true
	generation_finished.emit()


## Generate synchronously (tests, tools).
func generate_now(p_seed: int) -> void:
	world_seed = p_seed
	var gen := PlanetGenerator.new()
	gen.generate(p_seed)
	planet = gen.planet
	weather = gen.weather
	ready_to_play = true


func _process(delta: float) -> void:
	if not ready_to_play:
		return
	var game_hours := delta / PlanetConst.DAY_LENGTH_S * 24.0 * time_scale
	days += game_hours / 24.0
	_weather_accum_h += game_hours
	if _weather_accum_h >= WEATHER_STEP_H:
		weather.step(_weather_accum_h, Astro.sun_dir(days))
		_weather_accum_h = 0.0


# --- Floating origin -------------------------------------------------------

## Place the planet so the surface point at `dir` sits at the scene origin.
func center_on(dir: Vector3, radius_m: float) -> void:
	_cx = -dir.x * radius_m
	_cy = -dir.y * radius_m
	_cz = -dir.z * radius_m


func planet_center() -> Vector3:
	return Vector3(_cx, _cy, _cz)


## Scene position of a point `radius_m` from the planet center along `dir`.
func to_scene(dir: Vector3, radius_m: float) -> Vector3:
	return Vector3(_cx + dir.x * radius_m, _cy + dir.y * radius_m, _cz + dir.z * radius_m)


## Same, relative to another scene point (keeps chunk vertices precise).
func to_scene_relative(dir: Vector3, radius_m: float, anchor: Vector3) -> Vector3:
	return Vector3(
		(_cx + dir.x * radius_m) - anchor.x,
		(_cy + dir.y * radius_m) - anchor.y,
		(_cz + dir.z * radius_m) - anchor.z)


## Unit direction from the planet center to a scene point.
func dir_of(scene_pos: Vector3) -> Vector3:
	var x := scene_pos.x - _cx
	var y := scene_pos.y - _cy
	var z := scene_pos.z - _cz
	var l := sqrt(x * x + y * y + z * z)
	return Vector3(x / l, y / l, z / l)


## Distance from the planet center to a scene point, in meters.
func radius_of(scene_pos: Vector3) -> float:
	var x := scene_pos.x - _cx
	var y := scene_pos.y - _cy
	var z := scene_pos.z - _cz
	return sqrt(x * x + y * y + z * z)


## Shift the world by -offset when the player gets too far from the origin.
## Returns true if it shifted; the caller moves the player itself.
func maybe_rebase(player_pos: Vector3) -> bool:
	if player_pos.length() < REBASE_DISTANCE_M:
		return false
	rebase(player_pos)
	return true


func rebase(offset: Vector3) -> void:
	_cx -= offset.x
	_cy -= offset.y
	_cz -= offset.z
	if world_root:
		for child in world_root.get_children():
			if child is Node3D:
				child.position -= offset
	origin_shifted.emit(offset)


# --- Convenience queries ---------------------------------------------------

func surface_elevation(dir: Vector3) -> float:
	return planet.terrain.elevation(dir, true)


## A pleasant spawn point: low coastal land in a temperate-to-tropical,
## not-desert climate. Deterministic per seed.
func pick_spawn_dir() -> Vector3:
	var best := -1
	var best_score := -INF
	for c in planet.cell_count:
		if planet.water[c] != PlanetData.Water.NONE:
			continue
		var e := planet.elevation[c]
		if e < 5.0 or e > 400.0:
			continue
		var score := -absf(planet.coast_dist_km[c] - 2.0) - absf(rad_to_deg(planet.lat[c]) - 20.0) * 0.1
		score += planet.moisture[c] * 3.0
		if planet.slope[c] > 0.15:
			score -= 5.0
		if score > best_score:
			best_score = score
			best = c
	return planet.dir[best] if best >= 0 else Vector3.UP
