class_name Astro
## Sun and moon positions in the planet-fixed frame (DESIGN.md "Lighting &
## Day-Night Cycle"). Time is measured in in-game days as a float: the
## integer part counts days, the fraction is time of day (0.5 = noon at
## longitude 0). The planet spins about +Y (north) and is tilted
## DayCycle.axial_tilt() (23.5 degrees) to its orbit: over a year of
## DayCycle.year_days() the sun's declination swings between the tropics,
## so day length depends on latitude and the day of the year (DayCycle),
## with midnight sun and polar night past the polar circles. Day of the
## year 0 is the northern spring equinox. Sunrise and sunset: see
## PlanetConst.SUNRISE_ELEVATION_DEG.
##
## MoonMode:
##   ORBITAL         - (default) Earth-like. The moon trails the sun by its
##                     phase angle: a thin crescent hangs near the sun at
##                     dusk, the full moon rises opposite the sunset, the
##                     moon rises ~49 minutes of in-game time later each
##                     day (a 29.5-day cycle, DayCycle.moon_cycle_days),
##                     and its path is tilted ~5 degrees like Earth's
##                     moon's, so it rides a little north or south of the
##                     ecliptic. It follows the same tilt as the sun: its
##                     declination is the ecliptic's at its own place,
##                     so winter full moons ride high and summer ones
##                     low.
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


## The sky as seen at `longitude`: `days` shifted so the sun, moon and
## stars stand where the phase timing puts them for that place (the
## planet's apparent turning is warped per viewer; the weather keeps the
## uniform clock; DayCycle.warp sets how fast the sky turns through each
## phase, easing between speeds so it never jumps). Pass the result to
## anything that draws or lights the sky, or tells the time.
static func apparent_days(days: float, longitude: float, latitude := 0.0) -> float:
	var clock := fposmod(time_of_day(days) + longitude / TAU, 1.0)
	return days + DayCycle.warp(clock, latitude, declination(days)) - clock


## The (uniform) days value at which a place (`longitude`, `latitude`)
## sees solar time `local_h` (0-24, 12 = sun highest) on the day of
## `base_days`.
static func days_at_solar_hour(base_days: float, local_h: float, longitude: float, latitude := 0.0) -> float:
	var out := floorf(base_days) + 0.5
	# Twice: the declination (and so the warp) is the answer's own.
	for i in 2:
		var clock := DayCycle.unwarp(local_h / 24.0, latitude, declination(out))
		out = floorf(base_days) + fposmod(clock - longitude / TAU, 1.0)
	return out


## Day of the year, 0 to DayCycle.year_days() (0 = the northern spring
## equinox; about 91 the June solstice, 182 the autumn equinox, 274 the
## December solstice).
static func year_day(days: float) -> float:
	return fposmod(days + DayCycle.year_start_day(), DayCycle.year_days())


## The sun's place along the ecliptic (radians, 0 at the spring equinox).
static func sun_ecliptic_longitude(days: float) -> float:
	return TAU * year_day(days) / DayCycle.year_days()


## The sun's declination (radians): +tilt at the June solstice, -tilt at
## the December one.
static func declination(days: float) -> float:
	return asin(sin(DayCycle.axial_tilt()) * sin(sun_ecliptic_longitude(days)))


## Local clock at a longitude, as hours 0-24 (noon = 12 when the sun is
## highest there).
## A place's local day and time on the sky's clock (design 1 Oct §CG): x
## the local day index (it turns at local midnight at `longitude`), y the
## hours 0-24 where noon is when the sun peaks (DayCycle.warp keeps
## midnight and noon, so the day turns as the clock face passes 00:00).
## The HUD line, the clock face and the log's stamps all read this.
static func local_clock(days: float, longitude: float, latitude: float) -> Vector2:
	var u := days + longitude / TAU
	var day := floorf(u)
	return Vector2(day, DayCycle.warp(u - day, latitude, declination(days)) * 24.0)


static func local_hours(days: float, longitude: float) -> float:
	return fposmod((time_of_day(days) + longitude / TAU) * 24.0, 24.0)


## Longitude directly under the sun. Moves west as the planet turns east.
static func subsolar_longitude(days: float) -> float:
	return PI - TAU * time_of_day(days)


## `tilted` false: the equinox sun, whatever the date (the weather's
## spin-up builds annual means with it).
static func sun_dir(days: float, tilted := true) -> Vector3:
	var lon := subsolar_longitude(days)
	var d := declination(days) if tilted else 0.0
	return Vector3(cos(d) * sin(lon), sin(d), cos(d) * cos(lon))


## Moon's angular distance east of the sun: 0 = new, PI = full.
static func moon_elongation(days: float) -> float:
	return TAU * fposmod(days / DayCycle.moon_cycle_days(), 1.0)


## Days since the last new moon.
static func moon_age_days(days: float) -> float:
	return fposmod(days, DayCycle.moon_cycle_days())


static func moon_dir(days: float, mode := MoonMode.ORBITAL) -> Vector3:
	if mode == MoonMode.LOCKED_OPPOSITE:
		return -sun_dir(days)
	var e := moon_elongation(days)
	var lon := subsolar_longitude(days) + e
	# On the ecliptic at its own place (the sun's plus its elongation),
	# tipped a little off it by its orbit's inclination.
	var lat := asin(sin(DayCycle.axial_tilt()) * sin(sun_ecliptic_longitude(days) + e)) + MOON_INCLINATION * sin(e + 0.7)
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))


## Lit fraction of the moon's disc (0 new, 1 full).
static func moon_illumination(days: float) -> float:
	return (1.0 - cos(moon_elongation(days))) * 0.5


static func phase_name(days: float) -> String:
	return PHASE_NAMES[int(round(moon_elongation(days) / TAU * 8.0)) % 8]


## The mansion the moon stands in. The stars turn with the sun here (no
## separate sidereal day), so the moon's place among them is its
## elongation: it walks through all 28 mansions once per phase cycle,
## about one a day (29.5 / 28 = 1.05 days each), starting with Jiao at new
## moon. (With the old 28-day cycle this was exactly one per day.)
static func mansion_index(days: float) -> int:
	return clampi(int(floor(moon_elongation(days) / TAU * 28.0)), 0, 27)


static func beast_index(mansion: int) -> int:
	return mansion / 7


## Mean sunshine over a whole day at a latitude with the sun at
## declination `decl` (the day-averaged cosine of the sun's height,
## counting night as 0): cos(lat) / PI on an equinox; 0 in polar night.
static func daily_insolation(lat: float, decl: float) -> float:
	var x := -tan(lat) * tan(decl)
	var h0 := 0.0 if x >= 1.0 else (PI if x <= -1.0 else acos(x))
	return (h0 * sin(lat) * sin(decl) + cos(lat) * cos(decl) * sin(h0)) / PI


## Angle of a body above the local horizon at a surface direction, radians.
static func elevation(body_dir: Vector3, surface_up: Vector3) -> float:
	return asin(clampf(body_dir.dot(surface_up), -1.0, 1.0))


## True while the sun counts as up at a surface direction.
static func is_daytime(days: float, surface_up: Vector3) -> bool:
	return rad_to_deg(elevation(sun_dir(days), surface_up)) > PlanetConst.SUNRISE_ELEVATION_DEG
