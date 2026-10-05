class_name Techniques
## Techniques (design 30 Sept §BP, data/techniques.json): verbs learned
## from peoples, permanent and weightless. The headman bestows the site's
## one on contact (CampSim, main): a flag kept per world (WorldSave) and
## a line in the log. Five are built as verbs (fishing_line, coppice,
## resin_torch, ember_carrier, fat_lamp: main, FishingLine, Coppice,
## Torch, PlayerFires); the rest are flags for now. Fire is never made,
## only carried: no fire drill exists anywhere.

static var _rows := {}


static func rows() -> Dictionary:
	if _rows.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/techniques.json"))
		if parsed is Dictionary:
			for r in parsed.get("techniques", []):
				if r is Dictionary:
					_rows[str(r.get("id", ""))] = r
	return _rows


static func row(id: String) -> Dictionary:
	return rows().get(id, {})


static func params(id: String) -> Dictionary:
	return row(id).get("params", {})


static func name_of(id: String) -> String:
	return str(row(id).get("name", id.replace("_", " ")))


static func known() -> Dictionary:
	var k = WorldSave.data.get("techniques", null)
	if not k is Dictionary:
		k = {}
		WorldSave.data["techniques"] = k
	return k


static func knows(id: String) -> bool:
	return not retired(id) and bool(known().get(id, false))


## A retired row: no metal (§EH), bog_iron. Kept so old references resolve,
## never taught, never listed, never logged.
static func retired(id: String) -> bool:
	return row(id).has("retired")


## The techniques the player knows that are still in the game (the lists).
static func listed() -> Array:
	var out: Array = []
	for id in known():
		if knows(str(id)):
			out.append(str(id))
	return out


## Learn `id` from `people` (its name for the log line). True the first
## time.
static func learn(id: String, people: Dictionary) -> bool:
	if id == "" or knows(id) or retired(id):
		return false
	known()[id] = true
	WorldSave.mark_dirty()
	GameLog.add("The %s showed you %s." % [Peoples.name_of(people).to_lower(), name_of(id).to_lower()], "technique")
	return true


## Does the headman of the camp `key` at `d` (people `people_id`) teach the
## fire arrow (design 4 Oct §ED.7, techniques.json fire_arrow camp)? The
## row's camp names a people id or a camp key; while it is OPEN, the
## people's camp at the end of the opening road teaches it (a placeholder
## until the designer picks).
static func teaches_fire_arrow(key: String, people_id: String, d: Vector3) -> bool:
	var camp := str(row("fire_arrow").get("camp", "OPEN"))
	if not camp.begins_with("OPEN"):
		return camp == key or camp == people_id
	var ruin: Vector3 = RoadNetwork.opening.get("ruin", Vector3.ZERO)
	return ruin != Vector3.ZERO and CubeSphere.surface_distance_m(ruin, d) < 120.0

