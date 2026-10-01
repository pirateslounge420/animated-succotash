extends Node
## Autoload "World": the one planet, its clock, its live weather, and the
## scene's floating origin.
##
## Generation runs on a background thread (it takes several seconds), with
## generation_progress for a loading screen. After that:
##
## * Clock: `days` advances at `day_length_s` real seconds per in-game
##   day (120 minutes, data/sky/day_cycle.json), always in real time.
## * Dev settings: data/dev.json (spec A4). When its "dev_mode" is true,
##   its "day_length_min" (144, the real cycle) replaces the game's, and
##   its "seed" (42) and "spawn_choice" (0: the same first camp) are the
##   DEV TOOLS' pins (design 1 Oct §CB): a tool pins itself (pin()), and
##   they hold in play only with dev.json "pin_in_play" true or DEV_PIN=1
##   in the environment (DEV_PIN=0 forces play's rule even in a tool).
##   Otherwise every new world rolls its own seed and first camp, and the
##   game boots into the last world played (WorldSave.last_seed).
##   A missing file, or dev_mode false, means the game's own settings.
## * Dev postage stamp (spec A4): in dev mode, "postage_stamp": true builds
##   a small scale model of the planet instead of the full 4,000 km one:
##   the same seed and passes, with the geography shrunk to
##   "stamp"."circumference_km" around on a coarser "grid_res" blueprint,
##   so every climate band is a short walk apart and it generates in a
##   few seconds (PlanetConst explains the scale model). Missing, or false:
##   the full planet. Settings are read before the first generation, even
##   when a tool generates before this node's _ready.
## * Weather: the same WeatherSim that produced the long-term averages
##   keeps running live, one step per in-game quarter hour.
## * Floating origin: the planet is ~64 km in radius (~6 km for the dev
##   postage stamp), so the scene keeps the player near (0,0,0) and moves
##   the planet instead. The planet's
##   center in scene coordinates is held in double precision (GDScript
##   floats are 64-bit; Vector3 is only 32-bit), and rebase() shifts
##   everything registered under `world_root` when the player strays too
##   far from the origin.

signal generation_progress(step: String, fraction: float)
signal generation_finished
signal origin_shifted(offset: Vector3)

const WEATHER_STEP_H := 0.25
const REBASE_DISTANCE_M := 1500.0
const DEV_PATH := "res://data/dev.json"

@export var world_seed := 42

## Real seconds per in-game day (the dev clock may shorten it).
var day_length_s := 7200.0
## True when data/dev.json turned dev mode on; `dev` holds its fields.
var dev_mode := false
var dev := {}
## True while the dev postage stamp is the planet being built.
var postage_stamp := false
## Blueprint cells per cube-face edge for the next generation.
var planet_res := PlanetGenerator.DEFAULT_RES
var _dev_loaded := false

var planet: PlanetData
var weather: WeatherSim
var ready_to_play := false
## The water ripple simulation (owner: the ripple system, RippleSim; see
## Ripples): the ripple height buffer of the water near the camera (on the
## GPU) and the recent disturbances, for anything that wants to read them
## (Ripples.height_at, disturbance_at). Null until the game scene sets it
## up.
var ripples: Object = null

## In-game days since the start; fraction is time of day (0.5 = noon at
## longitude 0). Starts near full moon; main.gd then sets the clock to late
## afternoon at the spawn so a first session opens on sunset, then the
## night the spec treats as the showpiece.
var days := START_DAYS
## The clock a fresh world starts at (near full moon); generate() resets it.
const START_DAYS := 13.62
## A tool pinned the seed and spawn itself (pin()).
var _pinned := false
## Set by "New world" (settings panel, the dev key): the next startup_seed
## rolls a fresh world instead of continuing the last one.
var new_world_requested := false
## The kind of first camp this world rolled (camps.json first_camp; "" for
## the old single list), for the log's first line.
var first_camp_kind := ""

## Scene node whose direct children get shifted on rebase (terrain chunks,
## creatures, the far planet shell, ...). Set by the playable scene.
var world_root: Node3D

# Planet center in scene coordinates, double precision.
var _cx := 0.0
var _cy := 0.0
var _cz := 0.0
var _thread: Thread
var _weather_accum_h := 0.0


func _ready() -> void:
	_load_dev_settings()


func _load_dev_settings() -> void:
	if _dev_loaded:
		return
	_dev_loaded = true
	day_length_s = DayCycle.day_length_min() * 60.0
	if not FileAccess.file_exists(DEV_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DEV_PATH))
	if not parsed is Dictionary:
		push_warning("World: %s is not valid JSON, ignored" % DEV_PATH)
		return
	dev = parsed
	dev_mode = bool(dev.get("dev_mode", false))
	if not dev_mode:
		return
	if dev.has("day_length_min"):
		day_length_s = maxf(float(dev.day_length_min), 0.1) * 60.0
	# The seed and spawn pins (design 1 Oct §CB): the tools', not play's.
	if pins_apply() and not _pinned:
		if dev.has("seed"):
			world_seed = int(dev.seed)
		if dev.has("spawn_choice"):
			spawn_choice = int(dev.spawn_choice)
	# A tool never writes a world's save or the last-world pointer (unless
	# DEV_PIN=0 asks for play's rule: new_world_check).
	if _script_run() and OS.get_environment("DEV_PIN") != "0":
		WorldSave.read_only = true
	# STAMP=1 / STAMP=0 in the environment overrides dev.json (the dev
	# checks run on the stamp, where every biome is within reach).
	var stamp_env := OS.get_environment("STAMP")
	use_postage_stamp(stamp_env == "1" if stamp_env != "" else bool(dev.get("postage_stamp", false)))
	print("[World] dev mode (data/dev.json): %.0f-minute day, seed %d, spawn %d, %s" % [day_length_s / 60.0, world_seed, spawn_choice,
		"postage stamp %.0f km around, %d cells per face edge" % [PlanetConst.CIRCUMFERENCE_M / 1000.0, planet_res] if postage_stamp else "full planet"])


## Build the dev postage stamp (true) or the full planet (false) from the
## next generation on; data/dev.json's "stamp" gives the stamp's size.
## Resizes the planet constants (PlanetConst.set_circumference).
func use_postage_stamp(on: bool) -> void:
	postage_stamp = on
	var stamp: Dictionary = dev.get("stamp", {})
	if on:
		PlanetConst.set_circumference(float(stamp.get("circumference_km", 40.0)) * 1000.0)
		planet_res = int(stamp.get("grid_res", 48))
	else:
		PlanetConst.set_circumference(PlanetConst.FULL_CIRCUMFERENCE_M)
		planet_res = PlanetGenerator.DEFAULT_RES


## A tool pins its own seed and first camp (dev_view, the checks: seed 42,
## spawn 0, or their SEED / SPAWN env), instead of relying on dev.json.
func pin(p_seed: int, p_spawn: int) -> void:
	_load_dev_settings()
	_pinned = true
	world_seed = p_seed
	spawn_choice = p_spawn


## Do the dev pins (seed, spawn_choice) apply: a tool that pinned itself,
## a --script / -s run (a tool that forgot: never a new world from a
## tool), DEV_PIN=1, or dev.json pin_in_play. DEV_PIN=0 says no, even in
## a tool (new_world_check).
func pins_apply() -> bool:
	var env := OS.get_environment("DEV_PIN")
	if env == "0":
		return false
	if env == "1" or _pinned:
		return true
	if bool(dev.get("pin_in_play", false)):
		return true
	return _script_run()


static func _script_run() -> bool:
	var args := OS.get_cmdline_args()
	return args.has("--script") or args.has("-s")


## The seed a game uses (design 1 Oct §CB): the pinned one for the tools;
## else Continue (the last world played, when its save exists), or a fresh
## random seed for a new world, written as the last-world pointer. The
## seed is the world's name ("World 7731").
func startup_seed(default_seed: int) -> int:
	_load_dev_settings()
	if pins_apply():
		return world_seed if _pinned or (dev_mode and dev.has("seed")) else default_seed
	var last := WorldSave.last_seed()
	if last > 0 and WorldSave.exists(last) and not new_world_requested:
		return last
	new_world_requested = false
	var fresh := roll_seed()
	WorldSave.set_last(fresh)
	return fresh


## A fresh positive seed.
static func roll_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return int(rng.randi() % 2147483646) + 1


## Forget the last world's state held in static tables before a new (or
## the next) world builds: everything per world comes from its save.
func reset_world_state() -> void:
	FireStore.stores.clear()
	FireStore._logged.clear()
	Encampment.clearings.clear()
	Torch.bundles.clear()
	SoilMarks.marks.clear()
	Coppice.stools.clear()
	Hearth.dir = Vector3.ZERO
	Hearth.key = ""
	GameLog.entries.clear()
	GameLog._once.clear()
	ready_to_play = false


func generate(p_seed: int) -> void:
	_load_dev_settings()
	world_seed = p_seed
	days = START_DAYS
	ready_to_play = false
	_thread = Thread.new()
	_thread.start(_generate_threaded.bind(p_seed, planet_res))


func _generate_threaded(p_seed: int, res: int) -> void:
	var gen := PlanetGenerator.new()
	gen.progress.connect(func(step: String, f: float) -> void:
		call_deferred("_emit_progress", step, f))
	gen.generate(p_seed, res)
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
	_load_dev_settings()
	world_seed = p_seed
	days = START_DAYS
	var gen := PlanetGenerator.new()
	gen.generate(p_seed, planet_res)
	planet = gen.planet
	weather = gen.weather
	ready_to_play = true


func _process(delta: float) -> void:
	if not ready_to_play:
		return
	var game_hours := delta / day_length_s * 24.0
	days += game_hours / 24.0
	_weather_accum_h += game_hours
	if _weather_accum_h >= WEATHER_STEP_H:
		weather.season_days = days
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


## Where a new game starts: one of the planet's few best first-camp spots
## (Encampment.candidates: low coastal land, mild and green), picked at
## rolled from the seed each world, or the `spawn_choice`-th one if that's
## set (>= 0; the tools' pin, data/dev.json).
var spawn_choice := -1


func pick_spawn_dir() -> Vector3:
	var pool := Encampment.candidates(planet)
	if pool.is_empty():
		return Vector3.UP
	first_camp_kind = ""
	if spawn_choice >= 0:
		return pool[mini(spawn_choice, pool.size() - 1)]
	# This world's own first camp, rolled from its seed (design 1 Oct §CB),
	# so a world always wakes at the same fire: a KIND by weight among the
	# kinds with candidates on this planet (camps.json first_camp; the
	# FIRST_CAMP env forces one), then a random cell of that kind.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, "first_camp"])
	if bool(Encampment.FC.get("roll_kind", false)):
		var by_kind := Encampment.candidates_by_kind(planet)
		var kinds: Dictionary = Encampment.FC.get("kinds", {})
		var names: Array[String] = []
		var weights: Array[float] = []
		for k in kinds:
			if (by_kind.get(k, PackedVector3Array()) as PackedVector3Array).size() > 0:
				names.append(str(k))
				weights.append(float((kinds[k] as Dictionary).get("weight", 1)))
		var forced := OS.get_environment("FIRST_CAMP")
		var kind := ""
		if forced != "" and names.has(forced):
			kind = forced
		elif not names.is_empty():
			var total := 0.0
			for w in weights:
				total += w
			var r := rng.randf() * total
			kind = names[names.size() - 1]
			for j in names.size():
				r -= weights[j]
				if r <= 0.0:
					kind = names[j]
					break
		if kind != "":
			var cells: PackedVector3Array = by_kind[kind]
			first_camp_kind = kind
			return cells[rng.randi() % cells.size()]
		push_warning("World: no first-camp kind has candidates on seed %d; the old list" % world_seed)
	return pool[rng.randi() % pool.size()]
