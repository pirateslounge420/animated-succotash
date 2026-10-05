extends Node
## Autoload "World": the one planet, its clock, its live weather, and the
## scene's floating origin.
##
## Generation runs on a background thread (it takes several seconds), with
## generation_progress for a loading screen. After that:
##
## * Clock: `days` advances at `day_length_s` real seconds per in-game
##   day (144 minutes, data/sky/day_cycle.json), always in real time.
## * Dev settings: data/dev.json (spec A4). When its "dev_mode" is true,
##   its "day_length_min" (144, the real cycle) replaces the game's, and
##   its "seed" (42) and "spawn_choice" (-1: a random first camp; 0..11 that
##   candidate, which the dev frame and some checks pin) are the
##   DEV TOOLS' pins (design 1 Oct §CB): a tool pins itself (pin()), and
##   they hold in play only with dev.json "pin_in_play" true or DEV_PIN=1
##   in the environment (DEV_PIN=0 forces play's rule even in a tool).
##   Otherwise every new world rolls its own seed and first camp, and the
##   game boots into the last world played (WorldSave.last_seed).
##   A missing file, or dev_mode false, means the game's own settings.
## * Dev postage stamp (spec A4): STAMP=1 in the environment (the checks and
##   renders; play leaves it off), or in dev mode "postage_stamp": true, builds
##   a small scale model of the planet instead of the full 4,000 km one:
##   the same seed and passes, with the geography shrunk to
##   "stamp"."circumference_km" around on a coarser "grid_res" blueprint,
##   so every climate band is a short walk apart and it generates in a
##   few seconds (PlanetConst explains the scale model). Missing, or false:
##   the full planet. Settings are read before the first generation, even
##   when a tool generates before this node's _ready.
## * Weather: the same WeatherSim that produced the long-term averages
##   keeps running live, one step per in-game quarter hour.
## * Floating origin: the planet is ~637 km in radius, 4,000 km around
##   (~6.4 km for the dev postage stamp; the ~63.7 km GEO_RADIUS_M is the
##   geography's layout, not the planet built), so the scene keeps the player near (0,0,0) and moves
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
## The local day (Astro.local_clock's index, at the opening camp) the world
## began on; its save keeps it (WorldSave "first_local_day"). Day 1 is the
## count, not the calendar: the sky keeps START_DAYS (design §CG).
var first_local_day := 0.0

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
	# The hearths pass is per world (design 3 Oct §CU).
	Hearths.active = false
	Hearths.keep.clear()
	ready_to_play = false


## The day of play and the time at `d` (design 1 Oct §CG): x the day number
## (1 on the day the world began, up one at local midnight where `d` is),
## y the sky's hours 0-24. The one clock every readout uses.
func local_clock(d: Vector3) -> Vector2:
	var c := Astro.local_clock(days, CubeSphere.longitude(d), CubeSphere.latitude(d))
	return Vector2(maxf(c.x - first_local_day + 1.0, 1.0), c.y)


## The calendar at day count `count` (local_clock's x, 1 on the world's
## first day): {"day": 1..year_days, "year": 1..} (design 3 Oct §DD,
## hud.json calendar). Day 365 is the last of Year 1, day 366 Day 1 of
## Year 2.
static func calendar(count: int) -> Dictionary:
	var yd := maxi(int(round(DayCycle.year_days())), 1)
	var n := maxi(count, 1) - 1
	return {"day": n % yd + 1, "year": n / yd + 1}


## `fmt` (hud.json calendar's time_format or log_stamp) filled in for day
## count `count` at `hours` (0-24): {day}, {year}, {hh}, {mm}.
static func calendar_text(fmt: String, count: int, hours: float) -> String:
	var cal := calendar(count)
	var m := int(floor(hours * 60.0))
	return fmt.format({"day": cal.day, "year": cal.year,
		"hh": "%02d" % ((m / 60) % 24), "mm": "%02d" % (m % 60)})


static func _cal_fmt(key: String, fallback: String) -> String:
	return str((Tuning.section("hud", "calendar") as Dictionary).get(key, fallback))


## "Day 3 of Year 1 · 14:05" at `d`: the HUD's time line (hud.json
## calendar.time_format, then the hour).
func clock_text(d: Vector3) -> String:
	var c := local_clock(d)
	var m := int(floor(c.y * 60.0))
	return "%s · %02d:%02d" % [calendar_text(_cal_fmt("time_format", "Day {day} of Year {year}"), int(c.x), c.y), (m / 60) % 24, m % 60]


## "Y1 D3 14:05" at `d`: the log's stamp (hud.json calendar.log_stamp).
func stamp_text(d: Vector3) -> String:
	var c := local_clock(d)
	return calendar_text(_cal_fmt("log_stamp", "Y{year} D{day} {hh}:{mm}"), int(c.x), c.y)


## The log's stamp at `d` for game day `at_days` (a camp book's line,
## §ED.3, written when it happened).
func stamp_at(d: Vector3, at_days: float) -> String:
	var c := Astro.local_clock(at_days, CubeSphere.longitude(d), CubeSphere.latitude(d))
	return calendar_text(_cal_fmt("log_stamp", "Y{year} D{day} {hh}:{mm}"), int(maxf(c.x - first_local_day + 1.0, 1.0)), c.y)


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


## Step the weather on by `hours` of game time, as _process does, in
## WEATHER_STEP_H steps (design 3 Oct §DE: the lost days; the clock is
## moved by the caller).
func run_weather(hours: float) -> void:
	if weather == null:
		return
	var left := hours + _weather_accum_h
	var t := days - hours
	while left >= WEATHER_STEP_H:
		t += WEATHER_STEP_H / 24.0
		weather.season_days = t
		weather.step(WEATHER_STEP_H, Astro.sun_dir(t))
		left -= WEATHER_STEP_H
	_weather_accum_h = left


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


## The opening camp (design 30 Sept §BX, 1 Oct §CB and the roads pass):
## {"site": the fire, "node": the road node beside it, "ruin": the
## people's camp the first road leads to, "alts": the next ones}, or {}
## (dev spawn_choice / the old list).
var opening := {}


## Where a new game's fire goes (main.gd builds the camp there). Dev
## (spawn_choice >= 0, or roll_kind off): the old list's cell, then
## Encampment.site_near. Play: this world's own first camp, rolled from
## its seed so a world always wakes at the same fire — a KIND by weight
## among the kinds with candidates (camps.json first_camp; FIRST_CAMP
## forces one), then, among that kind's candidate cells, the fire site
## (Encampment.fire_site: inside the kind's biomes, within within_m of its
## real water) whose road to a people's camp (an inhabited ruin) comes
## nearest opening_road.dawn_start.walk_real_min of walking at the slope
## pace (design 3 Oct §CY.1; opening_walk_target()). A kind with no
## fire site anywhere is dropped and another rolled; play never falls back
## to the old list unless no kind has one at all.
func pick_spawn_site(plain := false) -> Vector3:
	# The river camp (design 4 Oct §ED.1) unless it found nothing.
	Encampment.river_off = plain
	opening = {}
	RoadNetwork.opening = {}
	first_camp_kind = ""
	var pool := Encampment.candidates(planet)
	if spawn_choice >= 0 or not bool(Encampment.FC.get("roll_kind", false)):
		if pool.is_empty():
			return Vector3.UP
		return Encampment.site_near(planet, pool[mini(maxi(spawn_choice, 0), pool.size() - 1)])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, "first_camp"])
	var by_kind := Encampment.candidates_by_kind(planet)
	var kinds: Dictionary = Encampment.FC.get("kinds", {})
	var names: Array[String] = []
	var weights: Array[float] = []
	for k in kinds:
		if (by_kind.get(k, PackedVector3Array()) as PackedVector3Array).size() > 0:
			names.append(str(k))
			weights.append(float((kinds[k] as Dictionary).get("weight", 1)))
	var forced := OS.get_environment("FIRST_CAMP")
	while not names.is_empty():
		var kind := ""
		if forced != "" and names.has(forced):
			kind = forced
		else:
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
		var pick := _first_camp_of(kind, by_kind[kind], rng)
		if not pick.is_empty():
			first_camp_kind = kind
			opening = pick
			RoadNetwork.opening = pick
			return pick.site
		push_warning("World: no %s first camp has a fire site by its water on seed %d; rolling another kind" % [kind, world_seed])
		var at := names.find(kind)
		names.remove_at(at)
		weights.remove_at(at)
		forced = ""
	if not plain and not Encampment.river_rule().is_empty():
		push_warning("World: no river camp (§ED.1) on seed %d; the plain first-camp rules" % world_seed)
		return pick_spawn_site(true)
	push_error("World: no first-camp kind has a fire site on seed %d; the old list" % world_seed)
	if pool.is_empty():
		return Vector3.UP
	return Encampment.site_near(planet, pool[rng.randi() % pool.size()])


## The first camp of `kind` among its candidate `cells`: {} when none has
## a fire site. Each cell's fire site is scored by how near its nearest
## people's camp lies to the opening road's straight-line target (the
## walk's flat length at the typical pace share, over a winding factor);
## the best few are routed and each road timed in walking minutes at the
## slope pace (RoadNetwork.walk_minutes), and the one nearest the target
## minutes wins (design 3 Oct §CY.1), else the best site with no camp to
## lead to.
## Measured 1 Oct on four full-planet seeds: the routed road runs about
## 1.05-1.1 times the straight line (it was 1.3, and the roads came out
## 5-6 km against the 7.2 km hint).
const ROAD_WINDING := 1.08
## How many routed roads a first camp weighs before it picks.
const OPENING_TRIES := 6

## The local hour the opening clock starts at (§CY.1): dawn_start.spawn's
## real minutes after dawn begins at latitude `lat` on a day of declination
## `decl`. (Where there is no dawn, polar day or night, DayCycle gives its
## equator fallback.)
static func dawn_start_hour(lat: float, decl: float, day_length_s: float) -> float:
	var rule: Dictionary = Tuning.section("roads", "opening_road").get("dawn_start", {}).get("spawn", {})
	var after_min := float(rule.get("real_min_after_dawn_begins", 1.0))
	return fposmod(DayCycle.phase_start_hour("dawn", lat, decl) + after_min / (day_length_s / 60.0) * 24.0, 24.0)


## The opening road's rule (roads.json opening_road.dawn_start, §CY.1).
static func dawn_rule() -> Dictionary:
	return Tuning.section("roads", "opening_road").get("dawn_start", {})


## The opening walk in real minutes at a place: dawn_start.walk_real_min,
## shortened where the day there is too short to leave
## slack_before_dusk_min between a straight walk's arrival and dusk (the
## clock never moves; §CY.1). Also the most the road may be (its flat
## length, m) and the straight-line target (m).
func opening_walk_target(site: Vector3) -> Dictionary:
	var r := dawn_rule()
	var want := float(r.get("walk_real_min", 40.0))
	var speed := float(r.get("walk_speed_mps", 4.3))
	var slack := float(r.get("slack_before_dusk_min", 20.0))
	var share := float(r.get("pace_share_typical", 0.82))
	var lat := CubeSphere.latitude(site)
	var decl := Astro.declination(START_DAYS)
	var wake_h := dawn_start_hour(lat, decl, day_length_s)
	var dusk_h := DayCycle.phase_start_hour("dusk", lat, decl)
	var day_min := fposmod(dusk_h - wake_h, 24.0) / 24.0 * (day_length_s / 60.0)
	var minutes := clampf(minf(want, day_min - slack), 5.0, want)
	var max_m := minutes * 60.0 * speed
	return {"minutes": minutes, "day_min": day_min, "speed": speed, "max_m": max_m, "target_m": max_m * share / ROAD_WINDING}


func _first_camp_of(kind: String, cells: PackedVector3Array, rng: RandomNumberGenerator) -> Dictionary:
	var rivers := Encampment.rivers_for(planet)
	var order := Array(cells)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var options: Array = []
	for d in order:
		var site := Encampment.fire_site(planet, rivers, d, kind)
		if site == Vector3.ZERO:
			continue
		var w := opening_walk_target(site)
		var camps := _people_camps_toward(site, w.max_m, w.target_m)
		options.append([camps[0][0] if not camps.is_empty() else INF, site, camps, w])
	if options.is_empty():
		return {}
	options.sort_custom(func(x, y): return x[0] < y[0])
	var best := {}
	var best_err := INF
	var tried := 0
	for o in options:
		if tried >= OPENING_TRIES:
			break
		var pick := _road_from(o[1], o[2], rivers, o[3])
		if pick.is_empty():
			continue
		tried += 1
		var err := absf(float(pick.walk_min) - float(o[3].minutes))
		if err < best_err:
			best_err = err
			best = pick
	if not best.is_empty():
		best["back"] = _back_target(best.site, best.ruin)
		return best
	push_warning("World: no %s first camp's people's camp could be reached by road on seed %d; the camp stands on the network alone" % [kind, world_seed])
	var lone: Vector3 = options[0][1]
	return {"site": lone, "node": lone, "ruin": Vector3.ZERO, "alts": [], "camp_m": INF, "walk_min": INF}


## The people's camps (inhabited ruins) round `site` within 1.6 x the
## opening road's hint and at least 1.5 km off, best first: [|distance -
## target|, dir, distance].
func _people_camps_toward(site: Vector3, hint_m: float, target: float) -> Array:
	var camps: Array = []
	for r in Ruins.near(planet, site, hint_m * 1.6):
		if not Ruins.inhabited(r):
			continue
		var dm := CubeSphere.surface_distance_m(site, r.dir)
		if dm < 1500.0:
			continue
		var score := absf(dm - target)
		if not Encampment.river_rule().is_empty():
			# The river camp (§ED.1): the first landmarks lie up and down the
			# river; a people's camp by it is worth a longer or shorter walk.
			score += minf(_river_m(r.dir), 3000.0) * 0.6
		camps.append([score, r.dir, dm])
	camps.sort_custom(func(x, y): return x[0] < y[0])
	return camps


## Metres from `d` to the nearest river segment round its cell (INF with
## none).
func _river_m(d: Vector3) -> float:
	var rivers := Encampment.rivers_for(planet)
	var best := INF
	for sg in rivers.segments_near(planet, planet.cell_at(d)):
		best = minf(best, rivers.closest_dt(sg, d).x)
	return best


## The river camp's second road (§ED.1 back_road): the ruin the other way
## from `ruin` (its bearing from `site` turned more than 90 degrees from
## the first road's), back_m away, nearest the river first; ZERO with none.
func _back_target(site: Vector3, ruin: Vector3) -> Vector3:
	var rc := Encampment.river_rule()
	if rc.is_empty() or not bool(rc.get("back_road", true)) or ruin == Vector3.ZERO:
		return Vector3.ZERO
	var band: Array = rc.get("back_m", [1500.0, 9000.0])
	var fwd := (ruin - site).normalized()
	var best := Vector3.ZERO
	var best_s := INF
	for r in Ruins.near(planet, site, float(band[1])):
		var dm := CubeSphere.surface_distance_m(site, r.dir)
		if dm < float(band[0]):
			continue
		if (r.dir - site).normalized().dot(fwd) > 0.0:
			continue
		var sc := dm + minf(_river_m(r.dir), 3000.0) * 2.0
		if sc < best_s:
			best_s = sc
			best = r.dir
	return best


## The opening road from `site` to the people's camp among its best
## three `camps` whose road comes nearest `walk`'s minutes ({} when none
## routes): the road node, the camp, the next ones as alternatives, and the
## road's length (m) and walking minutes (§CY.1). A road longer than
## walk.max_m (the walk on dead-flat ground) is passed over while a
## shorter one routes.
func _road_from(site: Vector3, camps: Array, rivers: RiverNetwork, walk := {}) -> Dictionary:
	if walk.is_empty():
		walk = opening_walk_target(site)
	var best := {}
	var best_err := INF
	for ci in mini(camps.size(), 3):
		var ruin: Vector3 = camps[ci][1]
		var node := _road_node_by(site, ruin)
		var pts := RoadNetwork.route_pts(planet, rivers, node, ruin)
		if pts.is_empty():
			continue
		var mins := RoadNetwork.walk_minutes(planet, pts, float(walk.speed))
		var err := absf(mins - float(walk.minutes))
		if RoadNetwork.length_m(pts) > float(walk.max_m):
			err += 1000.0
		if err < best_err:
			best_err = err
			var alts: Array = []
			for k in range(ci + 1, mini(camps.size(), ci + 4)):
				alts.append(camps[k][1])
			best = {"site": site, "node": node, "ruin": ruin, "alts": alts, "camp_m": camps[ci][2],
				"road_m": RoadNetwork.length_m(pts), "walk_min": mins}
	return best


## A kept world's opening camp (design 1 Oct, Mike's Mac: the camp moved
## when the roads pass changed what a seed picks): rebuilt exactly where
## the world first put it (WorldSave "opening_site"), its opening road
## routed from there to the best people's camp the road reaches.
## pick_spawn_site is for a brand-new world only.
func restore_spawn_site(site: Vector3, kind: String) -> Vector3:
	first_camp_kind = kind
	var w := opening_walk_target(site)
	var camps := _people_camps_toward(site, w.max_m, w.target_m)
	var rivers := Encampment.rivers_for(planet)
	var pick := _road_from(site, camps, rivers, w)
	if pick.is_empty():
		# A camp kept from an older world may stand where no people's camp
		# lies at the hint's distance: the nearest ones a road reaches, up to
		# the network's longest link.
		var near: Array = []
		var max_m := float(Tuning.section("roads", "network").get("link_max_km", 15.0)) * 1000.0
		for r in Ruins.near(planet, site, max_m):
			if Ruins.inhabited(r):
				var dm := CubeSphere.surface_distance_m(site, r.dir)
				near.append([dm, r.dir, dm])
		near.sort_custom(func(x, y): return x[0] < y[0])
		for k in mini(near.size(), 6):
			pick = _road_from(site, [near[k]], rivers, w)
			if not pick.is_empty():
				break
	if pick.is_empty():
		push_warning("World: the kept opening camp at %s has no people's camp a road reaches" % str(site))
		pick = {"site": site, "node": site, "ruin": Vector3.ZERO, "alts": [], "camp_m": INF}
	if not pick.is_empty() and pick.get("ruin", Vector3.ZERO) != Vector3.ZERO:
		pick["back"] = _back_target(site, pick.ruin)
	opening = pick
	RoadNetwork.opening = pick
	return site


## The opening camp's road node: beside its fire, ROAD_OFF_M toward the
## people's camp, so the tread passes the fire's clearing, not through it.
const ROAD_OFF_M := 18.0

func _road_node_by(site: Vector3, toward: Vector3) -> Vector3:
	var dm := CubeSphere.surface_distance_m(site, toward)
	if dm < 1.0:
		return site
	return site.slerp(toward, ROAD_OFF_M / dm).normalized()
