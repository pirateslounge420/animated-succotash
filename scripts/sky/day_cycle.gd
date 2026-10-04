class_name DayCycle
## The day's four phases, the year, the moon's cycle and the sky's
## transition timings, read from data/sky/day_cycle.json (the defaults
## below if the file or a field is missing). See data/sky/README.md.
##
## The day is always day_length_min; how it divides is astronomy (design
## reconciliation Session 2 section F). The planet is tilted
## axial_tilt_deg, so the sun's declination swings through the year and a
## place's day, night, dawn and dusk depend on its latitude and the day of
## the year: long summer days and short winter ones away from the
## equator, midnight sun and polar night past the polar circles, and
## twilight (the sun within twilight_deg of the horizon) that lasts as
## long as the sun takes to cross it: short at the equator, long and
## lingering near the poles.
##
## The warp: the clock runs uniformly (the weather uses it as is), but
## the sky turns at a speed set by where the sun stands: slow through
## twilight, faster by day, fastest by night. The three speeds are
## calibrated once so that at the equator on an equinox the phases last
## exactly phase_min (the reference: 60 / 18 / 48 / 18 of 144 minutes);
## anywhere else the same speeds apply to that place's sun, and the whole
## turn is scaled to still take one day. The speed eases between the
## three over rate_blend_deg of sun elevation (never jumps). warp() maps
## the clock to where the sky has turned; unwarp() is its exact inverse
## (both piecewise linear over one table per latitude and declination).
##
## Clock and solar fractions run 0-1 from local midnight; solar 0.5 is
## noon (sun highest). Latitudes and declinations are in radians.

const DATA_PATH := "res://data/sky/day_cycle.json"
## Phase order through the day, from the end of the night.
const PHASES: Array[String] = ["dawn", "day", "dusk", "night"]
const DEFAULTS := {
	"day_length_min": 144.0,
	"phase_min": {"day": 60.0, "dusk": 18.0, "night": 48.0, "dawn": 18.0},
	"twilight_deg": 10.0,
	"rate_blend_deg": 4.0,
	"axial_tilt_deg": 23.5,
	"year_days": 365.0,
	"year_start_day": 0.0,
	"moon_cycle_days": 29.5,
	"weather_smoothing_s": 5.0,
	"cloud_light_band_deg": [-10.0, 4.0],
	"glyph_fade_s": 2.5,
}
## Table resolution: samples of the solar day.
const N := 1440
## A new table when the latitude or declination moves more than this
## (radians; 5e-4 rad of latitude is about 3 m on the stamp).
const LAT_STEP := 5e-4
const DECL_STEP := 2e-5

static var _data := {}
static var _loaded := false
## Sky slowness (clock per degree of hour angle, before the per-place
## scaling) at night, in twilight and by day.
static var _slow := Vector3.ONE

## The table for one (latitude, declination): the clock fraction at each
## solar sample, the sun's elevation there (degrees), the phase segments
## [{name, start, length, solar}] and the sunrise/sunset clocks.
static var _key := Vector2(INF, INF)
static var _clock := PackedFloat64Array()
static var _el := PackedFloat64Array()
static var _total := 1.0
static var _segs: Array = []
static var _daylight := 0.5


static func data() -> Dictionary:
	_ensure()
	return _data


static func day_length_min() -> float:
	return float(data().day_length_min)


static func twilight_deg() -> float:
	return float(data().twilight_deg)


static func axial_tilt() -> float:
	return deg_to_rad(float(data().axial_tilt_deg))


static func year_days() -> float:
	return maxf(float(data().year_days), 1.0)


## The moon's lit share at or above which a night is a full-moon night
## (design 3 Oct §DG): the werewolf hunts only then. One number for every
## reader (CreatureSpecies.active_now, Dread's hunter and its speed).
static func full_moon_illumination() -> float:
	return float(data().get("full_moon_illumination", 0.97))


## Day of the year (0 = the northern spring equinox) at game day 0.
static func year_start_day() -> float:
	return float(data().year_start_day)


static func moon_cycle_days() -> float:
	return maxf(float(data().moon_cycle_days), 1.0)


static func weather_smoothing_s() -> float:
	return float(data().weather_smoothing_s)


static func cloud_light_band() -> Vector2:
	var b: Array = data().cloud_light_band_deg
	return Vector2(float(b[0]), float(b[1]))


static func glyph_fade_s() -> float:
	return maxf(float(data().glyph_fade_s), 0.01)


## The reference minutes of each phase (the equator on an equinox).
static func phase_minutes() -> Dictionary:
	return data().phase_min


## Where the sky has turned (solar fraction) at a clock fraction, at
## latitude `lat` with the sun at declination `decl`.
static func warp(clock: float, lat := 0.0, decl := 0.0) -> float:
	_table(lat, decl)
	var x := fposmod(clock, 1.0)
	var i := clampi(_clock.bsearch(x) - 1, 0, N - 1)
	var span := _clock[i + 1] - _clock[i]
	var f := (x - _clock[i]) / span if span > 0.0 else 0.0
	return (float(i) + f) / N


## The clock fraction at which the sky reaches a solar fraction (the exact
## inverse of warp).
static func unwarp(solar: float, lat := 0.0, decl := 0.0) -> float:
	_table(lat, decl)
	var s := fposmod(solar, 1.0) * N
	var i := clampi(int(s), 0, N - 1)
	return lerpf(_clock[i], _clock[i + 1], s - i)


## How fast the sky turns at a clock fraction, relative to a uniform day
## (1 = uniform; below 1 slower, as through dawn and dusk).
static func turn_rate(clock: float, lat := 0.0, decl := 0.0) -> float:
	var u := warp(clock, lat, decl)
	return _total / _slowness(_elev(u, lat, decl))


## The phase at a clock fraction: {"name", "index", "into", "length"},
## "into" and "length" as fractions of a day.
static func phase_at(clock: float, lat := 0.0, decl := 0.0) -> Dictionary:
	_table(lat, decl)
	var x := fposmod(clock, 1.0)
	for seg in _segs:
		var into := fposmod(x - float(seg.start), 1.0)
		if into < float(seg.length) or _segs.size() == 1:
			return {"name": seg.name, "index": PHASES.find(seg.name), "into": into, "length": seg.length}
	var last: Dictionary = _segs[_segs.size() - 1]
	return {"name": last.name, "index": PHASES.find(last.name), "into": 0.0, "length": last.length}


## The local solar hour (0-24, noon 12) at which `phase` begins (dusk:
## the sun twilight_deg above the horizon going down). Where that phase
## doesn't happen that day (midnight sun, polar night) the equator's.
static func phase_start_hour(phase: String, lat := 0.0, decl := 0.0) -> float:
	_table(lat, decl)
	for seg in _segs:
		if seg.name == phase and _segs.size() > 1:
			return float(seg.solar) * 24.0
	if lat != 0.0 or decl != 0.0:
		return phase_start_hour(phase)
	return 12.0


## Minutes of each phase today at a place: {"dawn", "day", "dusk",
## "night"} (0 for a phase that doesn't happen).
static func phase_minutes_at(lat: float, decl: float) -> Dictionary:
	_table(lat, decl)
	var out := {"dawn": 0.0, "day": 0.0, "dusk": 0.0, "night": 0.0}
	for seg in _segs:
		out[seg.name] += float(seg.length) * day_length_min()
	return out


## Hours of daylight (sun above the horizon, PlanetConst.SUNRISE_ELEVATION_DEG)
## in the game's 24-hour day at a place: 0 in polar night, 24 in the
## midnight sun. What plants' photoperiod reads.
static func daylight_hours(lat: float, decl: float) -> float:
	_table(lat, decl)
	return _daylight * 24.0


## The clock fractions where dawn, day, dusk and night begin at a place
## (-1 for a phase that doesn't happen).
static func phase_starts(lat := 0.0, decl := 0.0) -> Array[float]:
	_table(lat, decl)
	var out: Array[float] = [-1.0, -1.0, -1.0, -1.0]
	for seg in _segs:
		if _segs.size() > 1:
			out[PHASES.find(seg.name)] = seg.start
	return out


# --- Internals ---------------------------------------------------------------

static func _ensure() -> void:
	if _loaded:
		return
	_data = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(DATA_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			for key in parsed:
				if _data.has(key) and _data[key] is Dictionary and parsed[key] is Dictionary:
					(_data[key] as Dictionary).merge(parsed[key], true)
				else:
					_data[key] = parsed[key]
		else:
			push_warning("DayCycle: %s is not valid JSON, using defaults" % DATA_PATH)
	_loaded = true
	_calibrate()


## Solve the three slownesses so the equator on an equinox gives the
## reference minutes. There the sun's elevation is 90 - |hour angle|, and
## each phase's time is linear in the three slownesses (their blend
## weights integrated over the phase): a 3x3 system. Dawn and dusk share
## one twilight slowness (their mean minutes).
static func _calibrate() -> void:
	var pm: Dictionary = _data.phase_min
	var want := Vector3(float(pm.get("night", 48.0)), float(pm.get("dawn", 18.0)) + float(pm.get("dusk", 18.0)), float(pm.get("day", 60.0)))
	var tw := twilight_deg()
	var m := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	var steps := 36000
	for i in steps:
		var h := -180.0 + (i + 0.5) * 360.0 / steps
		var el := 90.0 - absf(h)
		var row := 0 if el < -tw else (2 if el > tw else 1)
		var w := _weights(el)
		for k in 3:
			m[row][k] += w[k] * 360.0 / steps
	var sol := _solve3(m, want)
	if sol.x <= 0.0 or sol.y <= 0.0 or sol.z <= 0.0:
		push_warning("DayCycle: phase_min and twilight_deg give a non-positive sky speed; check day_cycle.json")
		sol = Vector3(maxf(sol.x, 0.01), maxf(sol.y, 0.01), maxf(sol.z, 0.01))
	_slow = sol
	_key = Vector2(INF, INF)


## Blend weights (night, twilight, day) at a sun elevation (degrees).
static func _weights(el: float) -> Vector3:
	var tw := twilight_deg()
	var b := maxf(float(_data.get("rate_blend_deg", 4.0)), 0.01)
	var up := smoothstep(-tw - b, -tw + b, el)
	var day := smoothstep(tw - b, tw + b, el)
	return Vector3(1.0 - up, up - day, day)


static func _slowness(el: float) -> float:
	var w := _weights(el)
	return w.x * _slow.x + w.y * _slow.y + w.z * _slow.z


## Sun elevation (degrees) at solar fraction `u` (0 = local midnight).
static func _elev(u: float, lat: float, decl: float) -> float:
	var h := TAU * (u - 0.5)
	return rad_to_deg(asin(clampf(sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos(h), -1.0, 1.0)))


## Build (or reuse) the table for a latitude and declination.
static func _table(lat: float, decl: float) -> void:
	_ensure()
	if absf(lat - _key.x) < LAT_STEP and absf(decl - _key.y) < DECL_STEP:
		return
	_key = Vector2(lat, decl)
	_clock.resize(N + 1)
	_el.resize(N + 1)
	var slow := PackedFloat64Array()
	slow.resize(N + 1)
	for i in N + 1:
		_el[i] = _elev(float(i) / N, lat, decl)
		slow[i] = _slowness(_el[i])
	var t := 0.0
	_clock[0] = 0.0
	for i in range(1, N + 1):
		t += 0.5 * (slow[i - 1] + slow[i]) / N
		_clock[i] = t
	_total = t
	for i in N + 1:
		_clock[i] /= t
	_clock[N] = 1.0
	_build_segments()


## The phases through the table's day, split where the sun crosses
## +-twilight_deg (crossings found between samples, linearly), and the
## daylight between sunrise and sunset.
static func _build_segments() -> void:
	var tw := twilight_deg()
	var rise := PlanetConst.SUNRISE_ELEVATION_DEG
	var cuts: Array = [] # [clock, solar, phase starting there]
	var up_clock := -1.0
	var down_clock := -1.0
	for i in range(1, N + 1):
		var a := _el[i - 1]
		var b := _el[i]
		for level: float in [-tw, tw]:
			if (a < level) != (b < level):
				var f := (level - a) / (b - a)
				var solar := (i - 1 + f) / N
				var clock := lerpf(_clock[i - 1], _clock[i], f)
				var rising := b > a
				var name := ""
				if level < 0.0:
					name = "dawn" if rising else "night"
				else:
					name = "day" if rising else "dusk"
				cuts.append([clock, solar, name])
		if (a < rise) != (b < rise):
			var f2 := (rise - a) / (b - a)
			var c := lerpf(_clock[i - 1], _clock[i], f2)
			if b > a:
				up_clock = c
			else:
				down_clock = c
	if up_clock >= 0.0 and down_clock >= 0.0:
		_daylight = fposmod(down_clock - up_clock, 1.0)
	else:
		_daylight = 1.0 if _el[N / 2] > rise else 0.0
	_segs.clear()
	if cuts.is_empty():
		# One phase all day: polar night, midnight sun, or the sun in
		# twilight all day (dawn until noon, dusk after).
		var noon := _el[N / 2]
		if noon > tw and _el[0] > tw:
			_segs.append({"name": "day", "start": 0.0, "length": 1.0, "solar": 0.0})
		elif noon < -tw:
			_segs.append({"name": "night", "start": 0.0, "length": 1.0, "solar": 0.0})
		else:
			_segs.append({"name": "dawn", "start": 0.0, "length": 0.5, "solar": 0.0})
			_segs.append({"name": "dusk", "start": 0.5, "length": 0.5, "solar": 0.5})
		return
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	for k in cuts.size():
		var nxt: Array = cuts[(k + 1) % cuts.size()]
		var start: float = cuts[k][0]
		_segs.append({"name": cuts[k][2], "start": start, "length": fposmod(float(nxt[0]) - start, 1.0) if cuts.size() > 1 else 1.0, "solar": cuts[k][1]})


static func _solve3(m: Array, b: Vector3) -> Vector3:
	var a := [[m[0][0], m[0][1], m[0][2], b.x], [m[1][0], m[1][1], m[1][2], b.y], [m[2][0], m[2][1], m[2][2], b.z]]
	for i in 3:
		var p := i
		for r in range(i + 1, 3):
			if absf(a[r][i]) > absf(a[p][i]):
				p = r
		var tmp = a[i]
		a[i] = a[p]
		a[p] = tmp
		for r in 3:
			if r != i:
				var f: float = a[r][i] / a[i][i]
				for c in range(i, 4):
					a[r][c] -= f * a[i][c]
	return Vector3(a[0][3] / a[0][0], a[1][3] / a[1][1], a[2][3] / a[2][2])
