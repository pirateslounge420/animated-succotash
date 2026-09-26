class_name DayCycle
## The day's four phases, the moon's cycle and the sky's transition
## timings, read from data/sky/day_cycle.json (the defaults below if the
## file or a field is missing). See data/sky/README.md for each field.
##
## The warp: the clock runs uniformly (the weather uses it as is), but the
## sky the viewer sees turns at a varying speed so each phase lasts its
## set time: slowly through dawn and dusk (the sun within twilight_deg of
## the horizon), faster through the day and faster still through the
## night. The speed never jumps: within a phase it is constant, and
## between phases it eases from one speed to the next over
## rate_blend_min, centered on the boundary (a smoothstep). The four
## speeds are solved so that each phase still takes exactly its minutes.
## warp() maps the clock to where the sky has turned; unwarp() is its
## exact inverse (bisection to ~1e-12 of a day).
##
## Clock and solar fractions run 0-1 from midnight; solar 0.5 is noon (sun
## highest). Midnight sits in the middle of the night phase.

const DATA_PATH := "res://data/sky/day_cycle.json"
## Phase order through the day, from the end of the night.
const PHASES: Array[String] = ["dawn", "day", "dusk", "night"]
const DEFAULTS := {
	"day_length_min": 120.0,
	"phase_min": {"day": 45.0, "dusk": 20.0, "night": 35.0, "dawn": 20.0},
	"twilight_deg": 10.0,
	"rate_blend_min": 12.0,
	"moon_cycle_days": 29.5,
	"weather_smoothing_s": 5.0,
	"cloud_light_band_deg": [-10.0, 4.0],
	"glyph_fade_s": 2.5,
}

static var _data := {}
static var _loaded := false
## Clock fractions where dawn, day, dusk and night begin.
static var _starts: Array[float] = []
## Solar fractions at those moments.
static var _solar: Array[float] = []
## Sky turning speed (solar per clock) held through each phase.
static var _levels: Array[float] = []
## Width of each speed change, as a fraction of the day.
static var _blend := 0.1


static func data() -> Dictionary:
	_ensure()
	return _data


static func day_length_min() -> float:
	return float(data().day_length_min)


static func twilight_deg() -> float:
	return float(data().twilight_deg)


static func moon_cycle_days() -> float:
	return maxf(float(data().moon_cycle_days), 1.0)


static func weather_smoothing_s() -> float:
	return float(data().weather_smoothing_s)


static func cloud_light_band() -> Vector2:
	var b: Array = data().cloud_light_band_deg
	return Vector2(float(b[0]), float(b[1]))


static func glyph_fade_s() -> float:
	return maxf(float(data().glyph_fade_s), 0.01)


## Minutes of each phase in a day_length_min day, e.g. {"dawn": 20.0, ...}.
static func phase_minutes() -> Dictionary:
	return data().phase_min


## Where the sky has turned (solar fraction) at a clock fraction.
static func warp(clock: float) -> float:
	_ensure()
	var x := fposmod(clock, 1.0)
	return _solar[0] + _integral(x) - _integral(_starts[0])


## The clock fraction at which the sky reaches a solar fraction (the exact
## inverse of warp).
static func unwarp(solar: float) -> float:
	_ensure()
	var s := fposmod(solar, 1.0)
	# The warped sky never strays half a day from the clock, so the answer
	# lies within half a day of s. warp() extended past midnight is
	# monotonic: bisect.
	var lo := s - 0.5
	var hi := s + 0.5
	for i in 60:
		var mid := (lo + hi) * 0.5
		if warp(mid) + floorf(mid) < s:
			lo = mid
		else:
			hi = mid
	return fposmod((lo + hi) * 0.5, 1.0)


## How fast the sky turns at a clock fraction, relative to a uniform day
## (1 = uniform; below 1 slower, as through dawn and dusk).
static func turn_rate(clock: float) -> float:
	_ensure()
	var x := fposmod(clock, 1.0)
	var r := _levels[3]
	for j in 4:
		r += (_levels[j] - _levels[(j + 3) % 4]) * _smooth((x - _starts[j]) / _blend + 0.5)
	return r


## The phase at a clock fraction: {"name", "index", "into", "length"},
## "into" and "length" as fractions of a day.
static func phase_at(clock: float) -> Dictionary:
	_ensure()
	var x := fposmod(clock, 1.0)
	var k := 3
	for j in 3:
		if x >= _starts[j] and x < _starts[j + 1]:
			k = j
	var start := _starts[k]
	var end := _starts[k + 1] if k < 3 else _starts[0] + 1.0
	if k == 3 and x < _starts[0]:
		x += 1.0
	return {"name": PHASES[k], "index": k, "into": x - start, "length": end - start}


## The clock fractions where dawn, day, dusk and night begin.
static func phase_starts() -> Array[float]:
	_ensure()
	return _starts.duplicate()


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
	_build()
	_loaded = true


static func _build() -> void:
	var pm: Dictionary = _data.phase_min
	var minutes: Array[float] = []
	for name in PHASES:
		minutes.append(maxf(float(pm.get(name, DEFAULTS.phase_min[name])), 0.01))
	var total := minutes[0] + minutes[1] + minutes[2] + minutes[3]
	var tw := clampf(float(_data.twilight_deg), 0.0, 89.0)
	var edge := (90.0 + tw) / 360.0 # hour angle where the night ends
	var lit := (90.0 - tw) / 360.0 # where full day begins
	_starts = [minutes[3] * 0.5 / total]
	for k in 3:
		_starts.append(_starts[k] + minutes[k] / total)
	_solar = [0.5 - edge, 0.5 - lit, 0.5 + lit, 0.5 + edge]
	var spans: Array[float] = [_solar[1] - _solar[0], _solar[2] - _solar[1], _solar[3] - _solar[2], 1.0 - (_solar[3] - _solar[0])]
	var shortest := minf(minf(minutes[0], minutes[1]), minf(minutes[2], minutes[3])) / total
	_blend = clampf(float(_data.rate_blend_min) / total, 1e-4, shortest)
	# Solve the four speeds so each phase covers its span. The phase
	# integrals are linear in the speeds: build the 4x4 system from unit
	# speeds. If a blend is so wide a speed would go negative (the sky
	# turning back), narrow it and solve again.
	for attempt in 8:
		var m := []
		for k in 4:
			var row := []
			for j in 4:
				var unit: Array[float] = [0.0, 0.0, 0.0, 0.0]
				unit[j] = 1.0
				_levels = unit
				row.append(_phase_integral(k))
			row.append(spans[k])
			m.append(row)
		_levels = _solve4(m)
		if _levels.min() > 0.0:
			return
		_blend *= 0.5
	push_warning("DayCycle: phase minutes and twilight_deg give no smooth solution; check day_cycle.json")


## Antiderivative of the speed from midnight: sum of smoothed steps.
static func _integral(x: float) -> float:
	var p := _levels[3] * x
	for j in 4:
		p += (_levels[j] - _levels[(j + 3) % 4]) * _blend * _smooth_integral((x - _starts[j]) / _blend + 0.5)
	return p


static func _phase_integral(k: int) -> float:
	if k < 3:
		return _integral(_starts[k + 1]) - _integral(_starts[k])
	return _integral(1.0) - _integral(_starts[3]) + _integral(_starts[0]) - _integral(0.0)


static func _smooth(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Integral of _smooth from -inf to t.
static func _smooth_integral(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 0.5 + (t - 1.0)
	return t * t * t - 0.5 * t * t * t * t


static func _solve4(m: Array) -> Array[float]:
	var n := 4
	for i in n:
		var p := i
		for r in range(i + 1, n):
			if absf(m[r][i]) > absf(m[p][i]):
				p = r
		var tmp = m[i]
		m[i] = m[p]
		m[p] = tmp
		for r in n:
			if r != i:
				var f: float = m[r][i] / m[i][i]
				for c in range(i, n + 1):
					m[r][c] -= f * m[i][c]
	var out: Array[float] = []
	for i in n:
		out.append(m[i][n] / m[i][i])
	return out
