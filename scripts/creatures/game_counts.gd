class_name GameCounts
## Game in a region, for the camps' hunters (design 5 Oct §EK; camps.json
## → sim.hunt.game). Mike, 5 Oct: no ecology, "it just basically
## respawns if they get too low". A region is a planet cell. Per region
## and huntable class (animal_use.json classes: small_game, bird, fish,
## small_hoofed, large_hoofed, marine_mammal, reptile) a count starts at
## game.capacity; each hunt takes one; a class at game.floor is never
## hunted; one that falls to its floor is back at capacity
## respawn_game_days later. Which classes a region has comes from the
## creature catalogue: every row with a size_class whose temp_c and
## moisture ranges hold the region's (water birds and fish where there is
## water; the fish catalogue for fish; marine_mammal on a coast colder
## than marine_max_temp_c). Counts live in the save (WorldSave
## "game_counts").

static var G: Dictionary = ((Tuning.section("camps", "sim").get("hunt", {}) as Dictionary).get("game", {}) as Dictionary)
static var _present := {}
static var _fish: Array = []


static func counts() -> Dictionary:
	if not WorldSave.data.get("game_counts", null) is Dictionary:
		WorldSave.data["game_counts"] = {}
	return WorldSave.data["game_counts"]


static func capacity(cls: String) -> int:
	return int((G.get("capacity", {}) as Dictionary).get(cls, 4))


static func floor_n() -> int:
	return int(G.get("floor", 2))


static func _fish_rows() -> Array:
	if _fish.is_empty():
		var f := FileAccess.open("res://data/creatures/catalogue_fish.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_fish = d.get("creatures", [])
	return _fish


## The huntable classes of the region at `d` (its cell, and the water
## within a short walk of it): {class: [species names]}.
static func classes_at(map: PlanetData, d: Vector3) -> Dictionary:
	var cell := map.cell_at(d)
	if _present.has(cell):
		return _present[cell]
	var temp := float(map.temp_c[cell])
	var moist := float(map.moisture[cell])
	var fresh := false
	var sea := false
	for k in 5:
		var p := d if k == 0 else CreatureSpawner._offset(d, TAU * k / 4.0, 300.0)
		var w := int(map.water[map.cell_at(p)])
		if w == PlanetData.Water.OCEAN:
			sea = true
		elif w != PlanetData.Water.NONE:
			fresh = true
	var out := {}
	for sp in CreatureSpecies.all():
		var cls := str(sp.data.get("size_class", ""))
		if cls == "" or sp.spawn == "disabled":
			continue
		if temp < sp.temp_c.x or temp > sp.temp_c.y or moist < sp.moisture.x or moist > sp.moisture.y:
			continue
		if sp.role == "water_edge" and not (fresh or sea):
			continue
		if not out.has(cls):
			out[cls] = []
		(out[cls] as Array).append(sp.name)
	for row in _fish_rows():
		var r: Dictionary = row
		var tc: Array = r.get("temp_c", [-50, 50])
		if temp < float(tc[0]) or temp > float(tc[1]):
			continue
		var salt := bool((r.get("needs", {}) as Dictionary).get("salt", false))
		if (salt and sea) or (not salt and fresh):
			if not out.has("fish"):
				out["fish"] = []
			(out.fish as Array).append(str(r.get("name", "fish")))
	if sea and temp <= float(G.get("marine_max_temp_c", 14.0)):
		var ex: Array = ((Tuning.table("animal_use").get("classes", {}) as Dictionary).get("marine_mammal", {}) as Dictionary).get("examples", ["seal"])
		out["marine_mammal"] = [str(ex[0]).capitalize()]
	_present[cell] = out
	return out


static func _entry(cell: int, cls: String) -> Dictionary:
	var c := counts()
	var k := "%d:%s" % [cell, cls]
	if not c.has(k):
		c[k] = {"n": capacity(cls), "floor_day": -1.0}
	return c[k]


## The count of `cls` in the region of cell `cell` at game time `days`
## (a class at its floor long enough is back at capacity).
static func count(cell: int, cls: String, days: float) -> int:
	var e := _entry(cell, cls)
	if int(e.n) <= floor_n() and float(e.floor_day) >= 0.0 and days - float(e.floor_day) >= float(G.get("respawn_game_days", 4)):
		e.n = capacity(cls)
		e.floor_day = -1.0
	return int(e.n)


## Take one of `cls` from the region (false at the floor: never hunted).
static func take(cell: int, cls: String, days: float) -> bool:
	if count(cell, cls, days) <= floor_n():
		return false
	var e := _entry(cell, cls)
	e.n = int(e.n) - 1
	if int(e.n) <= floor_n():
		e.floor_day = days
	WorldSave.mark_dirty()
	return true


## Set a count (the checks).
static func set_count(cell: int, cls: String, n: int, days: float) -> void:
	var e := _entry(cell, cls)
	e.n = n
	e.floor_day = days if n <= floor_n() else -1.0
