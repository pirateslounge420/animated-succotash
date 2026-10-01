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
	return bool(known().get(id, false))


## Learn `id` from `people` (its name for the log line). True the first
## time.
static func learn(id: String, people: Dictionary) -> bool:
	if id == "" or knows(id):
		return false
	known()[id] = true
	WorldSave.mark_dirty()
	GameLog.add("The %s showed you %s." % [Peoples.name_of(people).to_lower(), name_of(id).to_lower()], "technique")
	return true
