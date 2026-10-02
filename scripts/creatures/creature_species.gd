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
## Where it lives on Earth, short, for the HUD: `origin`, else the first
## clause of `source`.
var origin := ""
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
## Mythical: weight when a territory picks among the species that fit
## (1 = as common as any; unicorns and werewolves are rarer).
var rarity := 1.0
## Hit points (the data's "hp", else from size and role: hp_max()).
var hp := 0.0
## Damage a bite or blow does to the player, 0 = never attacks. Pack
## hunters and hostile mythicals default to one by size ("bite").
var bite := 0.0
## Unprovoked: it comes for you within this many metres (0 = only when
## hurt or, for packs and mythicals, by their own rules). Crocodiles,
## hippos and buffalo: the territorial charge (D4 "aggression range").
## Scaled by how loud you are (a still, crouched player gets closer).
var charge_m := 0.0

# Spec D4 fields (docs/WORLD_SYSTEMS_SPEC.md D4; data/creatures/README.md).
# Read by the systems that need them; nothing else changes behavior yet.
## Place in the food web: insect, herbivore, small_pred, apex, scavenger,
## fish, or mythic.
var trophic := ""
## D4's name for when it's out: day, night or dusk (sets `active` when the
## entry has no `active` of its own).
var activity := ""
## How it reacts to light (a torch, a campfire); "none" ignores it.
var light_response := ""
## Mythic only: the biomes it's bound to (BiomeTemplates ids, from biome
## keys like "TAIGA"); empty = not bound.
var biome_lock := PackedInt32Array()
## Lives in the water and never leaves it (D4 water_bound).
var water_bound := false
## Group size (D4 herd_min / herd_max); a pair is [2, 2].
var herd := Vector2i(1, 1)
## The entry as written, for a species' own extra fields (a rig's tuning,
## a cue).
var data := {}
## Where a hit lands and what it does (hit_table()), built on first use.
var _hits := {}

## 0-1 how full the moon is right now (CreatureSpawner sets it), for
## `active: full_moon`.
static var moon_full := 0.0

static var _all: Array[CreatureSpecies] = []
## The file's species-level "hit_parts" block, which every species starts
## from (hit_table()); HIT_FALLBACK if the file has none.
static var _hit_defaults := {}
const HIT_FALLBACK := {"body": 1.0, "head": 2.0, "eye": 4.0, "limb": 1.0, "limb_slow": 0.5, "limb_slow_floor": 0.25, "eye_blinds": true}


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
	if parsed.get("hit_parts") is Dictionary:
		_hit_defaults = parsed.hit_parts
	for e in parsed.creatures:
		if e is Dictionary and e.has("name"):
			_all.append(_from(e))


static func _from(e: Dictionary) -> CreatureSpecies:
	var sp := CreatureSpecies.new()
	sp.name = e.name
	sp.origin = str(e.get("origin", ""))
	if sp.origin == "":
		sp.origin = PlantSpecies.origin_from_source(str(e.get("source", "")), str(e.get("genus", "")), str(e.get("species", "")))
	sp.role = e.get("role", sp.role)
	sp.body = e.get("body", sp.body)
	sp.spawn = e.get("spawn", sp.spawn)
	sp.temp_c = _range(e.get("temp_c"), sp.temp_c)
	sp.moisture = _range(e.get("moisture"), sp.moisture)
	# Real-world meters in the data; scaled to this world's heights.
	sp.altitude_m = _range(e.get("altitude_m"), sp.altitude_m) * PlanetConst.HEIGHT_SCALE
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
	sp.rarity = float(e.get("rarity", 1.0))
	sp.hp = float(e.get("hp", 0.0))
	var hunter := sp.role == "pack" or sp.temperament in ["hostile", "aggressive"]
	sp.bite = float(e.get("bite", (6.0 + 5.0 * sp.size_m) if hunter else 0.0))
	sp.charge_m = float(e.get("charge_m", 0.0))
	# Spec D4 fields.
	sp.data = e
	sp.trophic = str(e.get("trophic", ""))
	sp.activity = str(e.get("activity", ""))
	if sp.activity != "" and not e.has("active"):
		sp.active = sp.activity
	sp.light_response = str(e.get("light_response", ""))
	sp.water_bound = bool(e.get("water_bound", false))
	var lock = e.get("biome_lock", [])
	for k in ([lock] if lock is String else lock):
		var id := BiomeTemplates.id_of_key(str(k).to_upper())
		if id >= 0:
			sp.biome_lock.append(id)
		else:
			push_warning("CreatureSpecies: %s: unknown biome_lock \"%s\"" % [sp.name, k])
	sp.herd = Vector2i(int(e.get("herd_min", 1)), int(e.get("herd_max", e.get("herd_min", 1))))
	return sp


static func _range(v, fallback: Vector2) -> Vector2:
	if v is Array and v.size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback


## Hit points: the data's, else small game dies to one good arrow, big
## animals take two or three, mythical creatures several.
func hp_max() -> float:
	if hp > 0.0:
		return hp
	if role == "mythical":
		return 30.0 + 30.0 * size_m
	return maxf(6.0, 26.0 * size_m)


## Where a hit lands and what it does (data "hit_parts"; Hits): the
## damage multiplier for each part kind (body, head, eye, limb),
## limb_slow (the share of its speed an animal keeps after each limb
## hit), limb_slow_floor (never slower than this share) and eye_blinds.
## The file's species-level block with this entry's own over it; folk
## made in code (Camps, Encampment) take the file's block.
func hit_table() -> Dictionary:
	if _hits.is_empty():
		if _all.is_empty():
			_load()
		_hits = HIT_FALLBACK.duplicate()
		_hits.merge(_hit_defaults, true)
		var own = data.get("hit_parts")
		if own is Dictionary:
			_hits.merge(own, true)
	return _hits


## False for species held back from normal play (`"spawn": "disabled"`:
## the Night Rider and the Pond Crawler until Phase 7): no spawner or
## territory picks them, and they don't change the odds for the others.
## Only a debug spawn shows them.
func spawns() -> bool:
	return spawn != "disabled"


## Is this biome (a BiomeTemplates id) one it may live in?
func biome_ok(biome_id: int) -> bool:
	return biome_lock.is_empty() or biome_lock.has(biome_id)


## Climate filter: temperature (°C at the exact spot), moisture 0-1 and
## elevation must all fall inside the species' ranges.
func climate_ok(t_c: float, m: float, elevation_m: float) -> bool:
	return t_c >= temp_c.x and t_c <= temp_c.y \
		and m >= moisture.x and m <= moisture.y \
		and elevation_m >= altitude_m.x and elevation_m <= altitude_m.y


## Is this species out and about at this light level (0 night .. 1 day)?
## "dusk" (crepuscular, design 1 Oct §CH): out in the twilight, dawn and
## dusk, between DUSK_BAND of daylight; asleep in full day and deep night.
const DUSK_BAND := Vector2(0.04, 0.6)


func active_now(daylight: float) -> bool:
	match active:
		"day":
			return daylight > 0.3
		"night":
			return daylight < 0.3
		"dusk":
			return daylight > DUSK_BAND.x and daylight < DUSK_BAND.y
		"full_moon":
			# Only on the nights round the full moon.
			return daylight < 0.3 and moon_full > 0.85
	return true


## "Genus species" from the table (spec D4), or "".
## The HUD line under the crosshair: binomial, then common name and origin.
func hud_name() -> String:
	var b := binomial()
	if b == "":
		return ""
	var second := PackedStringArray()
	if name != "" and name.to_lower() != b.to_lower():
		second.append(name)
	if origin != "":
		second.append(origin)
	return b if second.is_empty() else "%s\n%s" % [b, " · ".join(second)]


func binomial() -> String:
	return ("%s %s" % [str(data.get("genus", "")), str(data.get("species", ""))]).strip_edges()
