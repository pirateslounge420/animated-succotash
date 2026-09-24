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
