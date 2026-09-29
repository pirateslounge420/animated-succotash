class_name Seasons
## The four seasons (design reconciliation Session 2 section F; numbers in
## data/seasons.json). Winter, spring, summer and autumn over the year
## (DayCycle.year_days()), each centred lag_days after its solstice or
## equinox (spring on the March equinox, summer on the June solstice in
## the north), with a transition of transition_days straddling each
## boundary and the rest settled. The southern hemisphere runs half a year
## behind.
##
## What the climate reads:
##   * warmth(): -1 in a settled winter, 0 in spring and autumn, +1 in a
##     settled summer, ramping (smoothly) through the transitions; so the
##     seasons read as plateaus with generous changes between, not a
##     sine.
##   * temp_offset_c(): warmth times the swing at that latitude (small at
##     the equator, large at the poles, damped over open water): the
##     weather adds it to every cell's temperature.
##   * moisture_mult(): how wet the season is there (tropics: the wet
##     season is summer; temperate: a little wetter in winter; polar:
##     wetter in summer), a multiplier on evaporation.
##   * at(): the season's name, the next one and how far into the change
##     (for the HUD, and later the plants).
##
## Latitudes in radians; `days` the world clock (Astro.year_day()).

const NAMES: Array[String] = ["spring", "summer", "autumn", "winter"]
const DATA_PATH := "res://data/seasons.json"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = parsed if parsed is Dictionary else {}
		if _data.is_empty():
			push_warning("Seasons: %s is missing or not valid JSON" % DATA_PATH)
	return _data


static func _num(section: String, key: String, fallback: float) -> float:
	var s = data().get(section, {})
	return float(s.get(key, fallback)) if s is Dictionary else fallback


## Where in the seasonal year a place is: 0-4, spring's middle at 0,
## summer's at 1, autumn's at 2, winter's at 3 (the hemisphere's own).
static func _position(days: float, lat: float) -> float:
	var year := DayCycle.year_days()
	var yd := Astro.year_day(days) - _num("calendar", "lag_days", 20.0)
	if lat < 0.0:
		yd += year * 0.5
	return fposmod(yd / year * 4.0, 4.0)


## Where in the seasonal year a place is (0-4: spring's middle at 0,
## summer's at 1, autumn's at 2, winter's at 3), and half a transition in
## those units: the plants' clock (LeafSeason).
static func year_position(days: float, lat: float) -> float:
	return _position(days, lat)


static func half_transition() -> float:
	return _num("calendar", "transition_days", 20.0) * 0.5 / DayCycle.year_days() * 4.0


## The season now and the change under way: {"name", "next", "t" (0 while
## settled, 0-1 through the transition into "next"), "settled",
## "day_of_season" (days since this season began)}.
static func at(days: float, lat: float) -> Dictionary:
	var p := _position(days, lat)
	var half_tr := _num("calendar", "transition_days", 20.0) * 0.5 / DayCycle.year_days() * 4.0
	# Each season spans [k - 0.5, k + 0.5); boundaries at k + 0.5.
	var k := int(floor(p + 0.5)) % 4
	var into := fposmod(p + 0.5, 1.0) # 0 at the season's start, 1 at its end
	var name := NAMES[k]
	var nxt := NAMES[(k + 1) % 4]
	var t := 0.0
	# In the transition: the last half_tr of this season or the first of
	# the next.
	var to_end := 1.0 - into
	if to_end < half_tr:
		t = 0.5 - to_end / half_tr * 0.5
	elif into < half_tr:
		nxt = name
		name = NAMES[(k + 3) % 4]
		t = 0.5 + into / half_tr * 0.5
	return {"name": name, "next": nxt, "t": t, "settled": t == 0.0,
		"day_of_season": into * DayCycle.year_days() / 4.0}


## -1 settled winter, 0 spring/autumn, +1 settled summer, eased through
## the transitions.
static func warmth(days: float, lat: float) -> float:
	var s := at(days, lat)
	var a := _warmth_of(s.name)
	if s.settled:
		return a
	var t := float(s.t)
	return lerpf(a, _warmth_of(s.next), t * t * (3.0 - 2.0 * t))


static func _warmth_of(name: String) -> float:
	match name:
		"summer":
			return 1.0
		"winter":
			return -1.0
	return 0.0


## The seasonal swing's size at a latitude (degrees C), damped over open
## water by `water_frac`.
static func amplitude_c(lat: float, water_frac := 0.0) -> float:
	var eq := _num("temperature", "amplitude_c_equator", 1.5)
	var pole := _num("temperature", "amplitude_c_pole", 22.0)
	var a := lerpf(eq, pole, pow(absf(sin(lat)), _num("temperature", "curve", 1.3)))
	return a * lerpf(1.0, _num("temperature", "ocean_damping", 0.45), clampf(water_frac, 0.0, 1.0))


## The season's temperature offset (degrees C) at a latitude.
static func temp_offset_c(days: float, lat: float, water_frac := 0.0) -> float:
	return warmth(days, lat) * amplitude_c(lat, water_frac)


## How wet the season is at a latitude (a multiplier; 1 = the annual
## mean).
static func moisture_mult(days: float, lat: float) -> float:
	var m: Dictionary = data().get("moisture", {})
	if m.is_empty():
		return 1.0
	var s := at(days, lat)
	var a := _band_value(m, s.name, lat)
	if s.settled:
		return a
	var t := float(s.t)
	return lerpf(a, _band_value(m, s.next, lat), t * t * (3.0 - 2.0 * t))


## One season's moisture at a latitude: the bands blended by latitude.
static func _band_value(m: Dictionary, season: String, lat: float) -> float:
	var deg := absf(rad_to_deg(lat))
	var trop := float(m.get("tropical", {}).get(season, 1.0))
	var temp := float(m.get("temperate", {}).get(season, 1.0))
	var polar := float(m.get("polar", {}).get(season, 1.0))
	var t1 := smoothstep(float(m.get("tropical_deg", 20.0)), float(m.get("temperate_deg", 35.0)), deg)
	var t2 := smoothstep(float(m.get("temperate_deg", 35.0)) + 20.0, float(m.get("polar_deg", 62.0)), deg)
	return lerpf(lerpf(trop, temp, t1), polar, t2)


## "Spring", or "Spring → Summer 40%" during a change.
static func label(days: float, lat: float) -> String:
	var s := at(days, lat)
	if s.settled:
		return String(s.name).capitalize()
	return "%s → %s %d%%" % [String(s.name).capitalize(), String(s.next).capitalize(), int(round(float(s.t) * 100.0))]
