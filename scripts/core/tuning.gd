class_name Tuning
## The movement and combat tables (spec A2: every tunable number lives in
## data/, the designer edits the tables): data/movement.json and
## data/combat.json, loaded once. `Tuning.num("movement", "air", "gravity_mps2")`
## reads one number; a key missing from the file is warned about once and
## reads as 0, so a typo shows up at once instead of hiding.

const FILES := {"movement": "res://data/movement.json", "combat": "res://data/combat.json", "look": "res://data/look.json", "hud": "res://data/hud.json", "litter": "res://data/litter.json", "stand": "res://data/stand.json"}

static var _tables := {}
static var _warned := {}


static func table(name: String) -> Dictionary:
	if not _tables.has(name):
		var parsed = null
		if FileAccess.file_exists(FILES[name]):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(FILES[name]))
		if not parsed is Dictionary:
			push_warning("Tuning: %s is missing or not valid JSON" % FILES[name])
			parsed = {}
		_tables[name] = parsed
	return _tables[name]


## A number from a table: section, then key.
static func num(name: String, section: String, key: String) -> float:
	var s = table(name).get(section, {})
	if s is Dictionary and (s as Dictionary).has(key):
		return float(s[key])
	var id := "%s.%s.%s" % [name, section, key]
	if not _warned.has(id):
		_warned[id] = true
		push_warning("Tuning: no %s in %s" % [id, FILES[name]])
	return 0.0


## A whole section (for per-material lists like traction).
static func section(name: String, section_name: String) -> Dictionary:
	var s = table(name).get(section_name, {})
	return s if s is Dictionary else {}
