class_name Astro
## Sun and moon positions in the planet-fixed frame (DESIGN.md "Lighting &
## Day-Night Cycle"). Time is measured in in-game days as a float: the
## integer part counts days, the fraction is time of day (0.5 = noon at
## longitude 0). The planet spins about +Y with no axial tilt, so there
## are no seasons.
##
## MoonMode:
##   LOCKED_OPPOSITE - the spec as written: the moon always sits opposite
##                     the sun, so it rises exactly as the sun sets. The
##                     28-day phase is a calendar value that drives the
##                     moon's brightness, disc shading and mansion glyph.
##   ORBITAL         - the moon lags the sun by its phase angle, like the
##                     real moon: a real crescent sits near the sun, the
##                     full moon is opposite, and sun and moon share the
##                     sky at dawn/dusk on most days.

enum MoonMode { LOCKED_OPPOSITE, ORBITAL }

## The 28 lunar mansions, in order, grouped into four beasts of seven.
const MANSION_NAMES: Array[String] = [
	"Jiao", "Kang", "Di", "Fang", "Xin", "Wei", "Ji",
	"Dou", "Niu", "Nu", "Xu", "Wei", "Shi", "Bi",
	"Kui", "Lou", "Wei", "Mao", "Bi", "Zi", "Shen",
	"Jing", "Gui", "Liu", "Xing", "Zhang", "Yi", "Zhen",
]
const BEAST_NAMES: Array[String] = ["Azure Dragon", "Black Tortoise", "White Tiger", "Vermilion Bird"]


static func time_of_day(days: float) -> float:
	return fposmod(days, 1.0)


## Longitude directly under the sun. Moves west as the planet turns east.
static func subsolar_longitude(days: float) -> float:
	return PI - TAU * time_of_day(days)


static func sun_dir(days: float) -> Vector3:
	var lon := subsolar_longitude(days)
	return Vector3(sin(lon), 0.0, cos(lon))


## Moon's angular distance east of the sun: 0 = new, PI = full.
static func moon_elongation(days: float) -> float:
	return TAU * fposmod(days / PlanetConst.MOON_CYCLE_DAYS, 1.0)


static func moon_dir(days: float, mode: MoonMode) -> Vector3:
	if mode == MoonMode.LOCKED_OPPOSITE:
		return -sun_dir(days)
	var lon := subsolar_longitude(days) + moon_elongation(days)
	return Vector3(sin(lon), 0.0, cos(lon))


## Lit fraction of the moon's disc (0 new, 1 full).
static func moon_illumination(days: float) -> float:
	return (1.0 - cos(moon_elongation(days))) * 0.5


## One mansion per in-game day.
static func mansion_index(days: float) -> int:
	return posmod(int(floor(days)), 28)


static func beast_index(mansion: int) -> int:
	return mansion / 7


## Angle of a body above the local horizon at a surface direction, radians.
static func elevation(body_dir: Vector3, surface_up: Vector3) -> float:
	return asin(clampf(body_dir.dot(surface_up), -1.0, 1.0))
