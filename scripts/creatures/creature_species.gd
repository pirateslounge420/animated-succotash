class_name CreatureSpecies
extends RefCounted
## One creature species from data/creatures/creatures.json (DESIGN.md
## "Creature Spawning"): habitat role, spawn tier, climate filter and
## needs, plus placeholder looks and sound. Field meanings are in
## data/creatures/README.md.
##
## Like plants, creatures read habitat directly (temperature in °C at the
## exact spot, moisture, trees, ground cover, water), never biome names.

const DATA_PATH := "res://data/creatures/creatures.json"

var name := ""
var role := "ground"
var body := "quadruped"
var spawn := "ambient"
var temp_c := Vector2(-50, 50)
var moisture := Vector2(0, 1)
var altitude_m := Vector2(-100, 9000)
var active := "any"
var one_per_radius_m := 40.0
var needs := {}
var size_m := 0.5
var color := Color.GRAY
var accent := Color.BLACK
var speed_mps := 2.0
var shy_m := 10.0
var sound := "none"
var pack := {}
var temperament := "neutral"
var territory_m := 200.0
var shape := ""
var campfire := false

static var _all: Array[CreatureSpecies] = []


## Every species, loaded once.
static func all() -> Array[CreatureSpecies]:
	if _all.is_empty():
		_load()
	return _all


static func by_role(r: String) -> Array[CreatureSpecies]:
	var out: Array[CreatureSpecies] = []
	for sp in all():
		if sp.role == r:
			out.append(sp)
	return out


static func find(n: String) -> CreatureSpecies:
	for sp in all():
		if sp.name == n:
			return sp
	return null


static func _load() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_warning("CreatureSpecies: can't open %s" % DATA_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary or not parsed.has("creatures"):
		push_warning("CreatureSpecies: %s is not valid creature data" % DATA_PATH)
		return
	for e in parsed.creatures:
		if e is Dictionary and e.has("name"):
			_all.append(_from(e))


static func _from(e: Dictionary) -> CreatureSpecies:
	var sp := CreatureSpecies.new()
	sp.name = e.name
	sp.role = e.get("role", sp.role)
	sp.body = e.get("body", sp.body)
	sp.spawn = e.get("spawn", sp.spawn)
	sp.temp_c = _range(e.get("temp_c"), sp.temp_c)
	sp.moisture = _range(e.get("moisture"), sp.moisture)
	sp.altitude_m = _range(e.get("altitude_m"), sp.altitude_m)
	sp.active = e.get("active", sp.active)
	sp.one_per_radius_m = maxf(float(e.get("one_per_radius_m", sp.one_per_radius_m)), 5.0)
	sp.needs = e.get("needs", {})
	sp.size_m = float(e.get("size_m", sp.size_m))
	sp.color = Color.from_string(e.get("color", ""), sp.color)
	sp.accent = Color.from_string(e.get("accent", ""), sp.color.darkened(0.4))
	sp.speed_mps = float(e.get("speed_mps", sp.speed_mps))
	sp.shy_m = float(e.get("shy_m", sp.shy_m))
	sp.sound = e.get("sound", sp.sound)
	sp.pack = e.get("pack", {})
	sp.temperament = e.get("temperament", sp.temperament)
	sp.territory_m = float(e.get("territory_m", sp.pack.get("territory_m", sp.territory_m)))
	sp.shape = e.get("shape", "")
	sp.campfire = bool(e.get("campfire", false))
	return sp


static func _range(v, fallback: Vector2) -> Vector2:
	if v is Array and v.size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback


## Climate filter: temperature (°C at the exact spot), moisture 0-1 and
## elevation must all fall inside the species' ranges.
func climate_ok(t_c: float, m: float, elevation_m: float) -> bool:
	return t_c >= temp_c.x and t_c <= temp_c.y \
		and m >= moisture.x and m <= moisture.y \
		and elevation_m >= altitude_m.x and elevation_m <= altitude_m.y


## Is this species out and about at this light level (0 night .. 1 day)?
func active_now(daylight: float) -> bool:
	match active:
		"day":
			return daylight > 0.3
		"night":
			return daylight < 0.3
	return true
