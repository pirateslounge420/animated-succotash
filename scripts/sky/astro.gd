class_name Astro
## Sun and moon positions in the planet-fixed frame (DESIGN.md "Lighting &
## Day-Night Cycle"). Time is measured in in-game days as a float: the
## integer part counts days, the fraction is time of day (0.5 = noon at
## longitude 0). The planet spins about +Y with no axial tilt, so there
## are no seasons. Day and night are not quite equal: see
## PlanetConst.SUNRISE_ELEVATION_DEG.
##
## MoonMode:
##   ORBITAL         - (default) Earth-like. The moon trails the sun by its
##                     phase angle: a thin crescent hangs near the sun at
##                     dusk, the full moon rises opposite the sunset, the
##                     moon rises ~50 minutes of in-game time later each
##                     day, and its path is tilted ~5 degrees like Earth's
##                     moon's, so it rides a little north or south of the
##                     sun's path.
##   LOCKED_OPPOSITE - the moon always sits opposite the sun (the original
##                     spec wording). Phase is then only a calendar value.

enum MoonMode { ORBITAL, LOCKED_OPPOSITE }

const MOON_INCLINATION := 0.0897 # 5.14 degrees, like Earth's moon

## The 28 lunar mansions, in order, grouped into four beasts of seven.
const MANSION_NAMES: Array[String] = [
	"Jiao", "Kang", "Di", "Fang", "Xin", "Wei", "Ji",
	"Dou", "Niu", "Nu", "Xu", "Wei", "Shi", "Bi",
	"Kui", "Lou", "Wei", "Mao", "Bi", "Zi", "Shen",
	"Jing", "Gui", "Liu", "Xing", "Zhang", "Yi", "Zhen",
]
const BEAST_NAMES: Array[String] = ["Azure Dragon", "Black Tortoise", "White Tiger", "Vermilion Bird"]
const PHASE_NAMES: Array[String] = [
	"New moon", "Waxing crescent", "First quarter", "Waxing gibbous",
	"Full moon", "Waning gibbous", "Last quarter", "Waning crescent",
]


static func time_of_day(days: float) -> float:
	return fposmod(days, 1.0)


## Phase breakpoints of the day at the equator, as [clock fraction, solar
## fraction] pairs from midnight (0) to midnight (1). The clock runs
## uniformly; the solar fraction (0.5 = sun highest) is where the sky
## has turned to. Night 40 min (half each side of midnight), dawn 15, day
## 50, dusk 15: the sky turns slowly through twilight (sun within
## TWILIGHT_DEG of the horizon) and fast through the night.
static func _phase_table() -> PackedVector2Array:
	var total := PlanetConst.DAWN_MIN + PlanetConst.DAY_MIN + PlanetConst.DUSK_MIN + PlanetConst.NIGHT_MIN
	var half_night := PlanetConst.NIGHT_MIN * 0.5
	var edge := (90.0 + PlanetConst.TWILIGHT_DEG) / 360.0 # hour angle where night ends
	var lit := (90.0 - PlanetConst.TWILIGHT_DEG) / 360.0 # where full day starts
	var c1 := half_night / total
	var c2 := c1 + PlanetConst.DAWN_MIN / total
	var c3 := c2 + PlanetConst.DAY_MIN / total
	var c4 := c3 + PlanetConst.DUSK_MIN / total
	return PackedVector2Array([Vector2(0.0, 0.0), Vector2(c1, 0.5 - edge), Vector2(c2, 0.5 - lit),
		Vector2(c3, 0.5 + lit), Vector2(c4, 0.5 + edge), Vector2(1.0, 1.0)])


## Solar fraction for a clock fraction (both 0-1 from midnight).
static func _warp(clock: float, table: PackedVector2Array) -> float:
	for i in table.size() - 1:
		var a := table[i]
		var b := table[i + 1]
		if clock <= b.x:
			return lerpf(a.y, b.y, (clock - a.x) / maxf(b.x - a.x, 1e-9))
	return clock


## Clock fraction for a solar fraction (the inverse of _warp).
static func _unwarp(solar: float, table: PackedVector2Array) -> float:
	for i in table.size() - 1:
		var a := table[i]
		var b := table[i + 1]
		if solar <= b.y:
			return lerpf(a.x, b.x, (solar - a.y) / maxf(b.y - a.y, 1e-9))
	return solar


## The sky as seen at `longitude`: `days` shifted so the sun, moon and
## stars stand where the phase timing puts them for that place (the
## planet's apparent turning is warped per viewer; the weather keeps the
## uniform clock). Pass the result to anything that draws or lights the
## sky, or tells the time.
static func apparent_days(days: float, longitude: float) -> float:
	var clock := fposmod(time_of_day(days) + longitude / TAU, 1.0)
	return days + _warp(clock, _phase_table()) - clock


## The (uniform) days value at which `longitude` sees solar time
## `local_h` (0-24, 12 = sun highest) on the day of `base_days`.
static func days_at_solar_hour(base_days: float, local_h: float, longitude: float) -> float:
	var clock := _unwarp(fposmod(local_h / 24.0, 1.0), _phase_table())
	return floor(base_days) + fposmod(clock - longitude / TAU, 1.0)


## Local clock at a longitude, as hours 0-24 (noon = 12 when the sun is
## highest there).
static func local_hours(days: float, longitude: float) -> float:
	return fposmod((time_of_day(days) + longitude / TAU) * 24.0, 24.0)


## Longitude directly under the sun. Moves west as the planet turns east.
static func subsolar_longitude(days: float) -> float:
	return PI - TAU * time_of_day(days)


static func sun_dir(days: float) -> Vector3:
	var lon := subsolar_longitude(days)
	return Vector3(sin(lon), 0.0, cos(lon))


## Moon's angular distance east of the sun: 0 = new, PI = full.
static func moon_elongation(days: float) -> float:
	return TAU * fposmod(days / PlanetConst.MOON_CYCLE_DAYS, 1.0)


static func moon_dir(days: float, mode := MoonMode.ORBITAL) -> Vector3:
	if mode == MoonMode.LOCKED_OPPOSITE:
		return -sun_dir(days)
	var e := moon_elongation(days)
	var lon := subsolar_longitude(days) + e
	var lat := MOON_INCLINATION * sin(e + 0.7)
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))


## Lit fraction of the moon's disc (0 new, 1 full).
static func moon_illumination(days: float) -> float:
	return (1.0 - cos(moon_elongation(days))) * 0.5


static func phase_name(days: float) -> String:
	return PHASE_NAMES[int(round(moon_elongation(days) / TAU * 8.0)) % 8]


## One mansion per in-game day.
static func mansion_index(days: float) -> int:
	return posmod(int(floor(days)), 28)


static func beast_index(mansion: int) -> int:
	return mansion / 7


## Angle of a body above the local horizon at a surface direction, radians.
static func elevation(body_dir: Vector3, surface_up: Vector3) -> float:
	return asin(clampf(body_dir.dot(surface_up), -1.0, 1.0))


## True while the sun counts as up at a surface direction.
static func is_daytime(days: float, surface_up: Vector3) -> bool:
	return rad_to_deg(elevation(sun_dir(days), surface_up)) > PlanetConst.SUNRISE_ELEVATION_DEG
