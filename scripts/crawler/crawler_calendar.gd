class_name CrawlerCalendar
## The crawler's calendar (design §GE, §GK.1.2; queue 114; data/crawler.json
## calendar): the open world's 144-minute day and 365-day year, one for the
## hub and every realm (§FK.3: the same date, season, hour and day length
## everywhere). No latitude anywhere (§GK.1.2, superseding §GE.5's): every
## sky, daylight and season value is read at one fixed reference,
## calendar.reference_deg (35, never shown as a latitude), so a summer day
## is ~74 / 18 / 34 / 18 real minutes, an equinox ~60 / 18 / 48 / 18, a
## winter day ~51 / 18 / 57 / 18, in the hub and in every realm alike
## (DayCycle's warp at the reference and the day's declination, Astro).
##
##   underground  nothing seasonal (calendar.underground_seasons false): the
##                shafts' daylight follows the one shared sky (§FG, Vents)
##
## What a winter does on a surface, by biome (§GE.5.4, which §GK.1.2 keeps):
## calendar.winter_by_biome (snow and frost only where cold; leaf drop or a
## dry season elsewhere); the hub's is calendar.hub_area's. The plants run
## the open world's leaf clock (LeafSeason's globals): deciduous crowns
## colour, fall and bud again only where that winter drops leaves.

static var C: Dictionary = Tuning.table("crawler").get("calendar", {})
## The place being read now: "hub", or a realm's kind (winter_by_biome's);
## it picks the winter, never the sky.
static var place := "hub"


static func seasons_on() -> bool:
	return bool(C.get("seasons_on", true))


## The one reference (degrees) every sky, daylight and season is read at
## (§GK.1.2): the same for the hub and every realm.
static func reference_deg() -> float:
	return float(C.get("reference_deg", 35.0))


## The realm kind of a surface world (worlds.json worlds.<name>): its own
## name when winter_by_biome has it, else calendar.area_of_world's.
static func kind_of_world(world_name: String) -> String:
	if (C.get("winter_by_biome", {}) as Dictionary).has(world_name):
		return world_name
	return str((C.get("area_of_world", {}) as Dictionary).get(world_name, "temperate"))


## Stand on `kind` from now on (the surface you came up onto): its winter
## changes; the sky, the day and the season are the one shared ones.
static func set_place(kind: String) -> void:
	place = kind
	SkySystem.one_clock_lat = lat()
	SkySystem.one_clock_year = seasons_on()
	SkySystem.one_clock_warp = CrawlerCalendar.warp


## The reference in radians (the one sky's; the same everywhere).
static func lat() -> float:
	return deg_to_rad(reference_deg())


## The sun's declination on day `days` (0 with the seasons off).
static func decl(days: float) -> float:
	return Astro.declination(days) if seasons_on() else 0.0


## The winter of `kind`: winter_by_biome's word (the hub: hub_area's).
static func winter_of(kind: String) -> String:
	var k := str(C.get("hub_area", "tropical")) if kind == "hub" else kind
	return str((C.get("winter_by_biome", {}) as Dictionary).get(k, "leaf_drop_light_frost"))


## Do deciduous plants at `kind` drop their leaves in winter?
static func drops_leaves(kind: String) -> bool:
	return seasons_on() and not winter_of(kind).begins_with("dry_season")


## The season on day `days`: one for every place (Seasons.at at the
## reference). `kind` is kept for callers and changes nothing.
static func season(days: float, _kind := "") -> Dictionary:
	return Seasons.at(days, lat())


# --- The stylised clock (design §F2, §GE.1.4; tools/reference/daylight_reference.py) ---
# The open world's DayCycle eases the sky's speed by the sun's height, which
# holds the 18-minute dawn and dusk only at the equator on an equinox (at
# the reference's 35° it gives 21-24 minutes). §GE asks for the reference's rule: every
# dawn and dusk 18 real minutes (never shorter than its natural length),
# the rest split between day and night in the geometric ratio, biased so
# the equator's equinox is exactly 60/18/48/18. The crawler's sky runs on
# this (SkySystem.one_clock_warp); the open world keeps DayCycle.

const SUNRISE_DEG := -3.6
const TWILIGHT_MIN := 18.0
static var _bias := -1.0


## The hour angles (fractions of a day, 0-0.5) at which the sun is at the
## sunrise line and at the bottom of the twilight band, at `la` and `de`
## (radians): Vector2(rise, twilight_bottom); -1 where it never gets there
## (rise: midnight sun when > 0.5, polar night when < 0).
static func _hours(la: float, de: float) -> Vector2:
	var out := Vector2.ZERO
	var i := 0
	for el in [SUNRISE_DEG, SUNRISE_DEG - DayCycle.twilight_deg()]:
		var c := (sin(deg_to_rad(el)) - sin(la) * sin(de)) / maxf(cos(la) * cos(de), 1e-6)
		out[i] = 0.5 + 0.01 if c < -1.0 else (-0.01 if c > 1.0 else acos(c) / TAU)
		i += 1
	return out


static func _day_bias() -> float:
	if _bias < 0.0:
		var hh := _hours(0.0, 0.0)
		var d := 2.0 * hh.x
		var n := 1.0 - 2.0 * hh.y
		var w := 60.0 / 108.0
		_bias = (w * n) / ((1.0 - w) * d)
	return _bias


## The stylised day at `la`, `de`: real minutes of each phase and the
## solar hour angles they span. {"day", "dusk", "night", "dawn" (minutes),
## "rise", "twi" (fractions), "ok" (false where the sun neither rises nor
## sets: DayCycle's own then)}.
static func stylised(la: float, de: float) -> Dictionary:
	var hh := _hours(la, de)
	if hh.x <= 0.0 or hh.x >= 0.5:
		return {"ok": false}
	var twi_h := (minf(hh.y, 0.5) if hh.y > 0.0 else 0.5) - hh.x
	if hh.y < 0.0 or hh.y > 0.5:
		twi_h = 0.5 - hh.x
	var total := DayCycle.day_length_min()
	var twi := clampf(maxf(TWILIGHT_MIN, twi_h * total), 0.0, total * 0.5)
	var rest := total - 2.0 * twi
	var d := 2.0 * hh.x
	var n := maxf(1.0 - d - 2.0 * twi_h, 0.0)
	var w := (_day_bias() * d) / maxf(_day_bias() * d + n, 1e-9)
	return {"ok": true, "day": rest * w, "dusk": twi, "night": rest * (1.0 - w), "dawn": twi,
		"rise": hh.x, "twi": hh.x + twi_h}


## Where the sky has turned (solar fraction, noon 0.5) at clock fraction
## `clock` at `la`, `de` (radians): each phase's real minutes laid over its
## stretch of the sun's path, noon at noon.
static func warp(clock: float, la: float, de: float) -> float:
	var st := stylised(la, de)
	if not bool(st.get("ok", false)):
		return DayCycle.warp(clock, la, de)
	var total := DayCycle.day_length_min()
	var x := fposmod(clock - 0.5, 1.0) # 0 at noon
	var dh := float(st.day) * 0.5 / total
	var tw := float(st.dusk) / total
	var nt := float(st.night) / total
	# From noon: half the day, dusk, the night, dawn, half the day.
	var knots_c := [0.0, dh, dh + tw, dh + tw + nt, dh + 2.0 * tw + nt, 1.0]
	var r := float(st.rise)
	var t := float(st.twi)
	var knots_s := [0.0, r, t, 1.0 - t, 1.0 - r, 1.0]
	for i in 5:
		if x <= float(knots_c[i + 1]) or i == 4:
			var span: float = knots_c[i + 1] - knots_c[i]
			var f: float = (x - float(knots_c[i])) / span if span > 1e-9 else 0.0
			return fposmod(lerpf(float(knots_s[i]), float(knots_s[i + 1]), f) + 0.5, 1.0)
	return clock


## The phase at clock fraction `clock` at `la`, `de`: "dawn", "day",
## "dusk" or "night".
static func phase_at(clock: float, la: float, de: float) -> String:
	var st := stylised(la, de)
	if not bool(st.get("ok", false)):
		return str(DayCycle.phase_at(clock, la, de).name)
	var total := DayCycle.day_length_min()
	var x := fposmod(clock - 0.5, 1.0)
	var dh := float(st.day) * 0.5 / total
	var tw := float(st.dusk) / total
	var nt := float(st.night) / total
	if x < dh or x >= dh + 2.0 * tw + nt:
		return "day"
	if x < dh + tw:
		return "dusk"
	if x < dh + tw + nt:
		return "night"
	return "dawn"


## Minutes of dawn, day, dusk and night on day `days`: the same at every
## place (`kind` changes nothing, §GK.1.2).
static func phase_minutes(days: float, _kind := "") -> Dictionary:
	var la := lat()
	var st := stylised(la, decl(days))
	if not bool(st.get("ok", false)):
		return DayCycle.phase_minutes_at(la, decl(days))
	return {"day": st.day, "dusk": st.dusk, "night": st.night, "dawn": st.dawn}


## A new game's first moment: the spring equinox's day (start_year_day),
## before dusk; CrawlerMain.set_dusk carries it on to dusk.
static func start_days() -> float:
	var yd := float(C.get("start_year_day", 0.0))
	return fposmod(yd - DayCycle.year_start_day(), DayCycle.year_days())


## The season's leaf clock for the plants at `kind` (LeafSeason's globals:
## leaf_clock, the staged autumn table), so the foliage shader colours,
## sheds and buds the deciduous crowns.
static func apply_leaves(days: float, kind := "") -> void:
	var k := kind if kind != "" else place
	var p := Seasons.year_position(days, lat())
	var quarter := DayCycle.year_days() / 4.0
	var q := fposmod(p - (3.5 - Seasons.half_transition()), 4.0)
	RenderingServer.global_shader_parameter_set("leaf_clock", Vector2(q * quarter, (q - 2.0) * quarter))
	LeafSeason._set_stage_globals()
	LeafSeason.leaf_now = float(LeafSeason.crown_at(p, Seasons.half_transition()).leaf) if drops_leaves(k) else 1.0


## The log's stamp: "Spring day 3 · 18:20" (the season and its day, the hour).
static func stamp(days: float) -> String:
	var s := season(days)
	var h := fposmod(days, 1.0) * 24.0
	var m := int(floor(h * 60.0))
	return "%s day %d · %02d:%02d" % [str(s.name).capitalize(), int(floor(float(s.day_of_season))) + 1, (m / 60) % 24, m % 60]
