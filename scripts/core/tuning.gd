class_name Tuning
## The movement and combat tables (spec A2: every tunable number lives in
## data/, the designer edits the tables): data/movement.json and
## data/combat.json, loaded once. `Tuning.num("movement", "air", "gravity_mps2")`
## reads one number; a key missing from the file is warned about once and
## reads as 0, so a typo shows up at once instead of hiding.

const FILES := {"movement": "res://data/movement.json", "combat": "res://data/combat.json", "look": "res://data/look.json", "hud": "res://data/hud.json", "litter": "res://data/litter.json", "stand": "res://data/stand.json", "camps": "res://data/camps.json", "torch": "res://data/torch.json", "fuel": "res://data/fuel.json", "dread": "res://data/dread.json", "current": "res://data/water/current.json", "roads": "res://data/roads.json", "rooms": "res://data/rooms.json", "travellers": "res://data/travellers.json", "audio": "res://data/audio.json", "habitat": "res://data/habitat.json", "vines": "res://data/vines.json", "delves": "res://data/delves.json", "world_scale": "res://data/world_scale.json", "smoke": "res://data/smoke.json"}

static var _tables := {}
static var _warned := {}
static var _profile := ""


static func table(name: String) -> Dictionary:
	if not _tables.has(name):
		var parsed = null
		if FileAccess.file_exists(FILES[name]):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(FILES[name]))
		if not parsed is Dictionary:
			push_warning("Tuning: %s is missing or not valid JSON" % FILES[name])
			parsed = {}
		if name == "movement":
			_apply_profile(parsed)
		_tables[name] = parsed
	return _tables[name]


## The movement profile (design 30 Sept §AU): movement.json `profile`
## names one of `profiles`, whose blocks are deep-merged over the base
## table (the shinobi table, untouched) as it loads, so everything reads
## the merged numbers as before. MOVEMENT_PROFILE=shinobi in the
## environment overrides it (the ninja checks run so).
static func _apply_profile(t: Dictionary) -> void:
	var env := OS.get_environment("MOVEMENT_PROFILE")
	_profile = env if env != "" else str(t.get("profile", "shinobi"))
	var profiles = t.get("profiles", {})
	if not profiles is Dictionary:
		return
	var over = (profiles as Dictionary).get(_profile, null)
	if over == null:
		if _profile != "shinobi":
			push_warning("Tuning: movement.json has no profile %s" % _profile)
		return
	_deep_merge(t, over)


static func _deep_merge(base: Dictionary, over: Dictionary) -> void:
	for k in over:
		if over[k] is Dictionary and base.get(k) is Dictionary:
			_deep_merge(base[k], over[k])
		else:
			base[k] = over[k]


## The movement profile in force ("ambient", "shinobi").
static func profile() -> String:
	table("movement")
	return _profile


## Is this movement block on? A block with `enabled: false` (the ambient
## profile switches off the wall jump, the cling, the bounce, the swing,
## the redirect, the roll, the slide and the super meter) is off entirely.
static func enabled(section_name: String) -> bool:
	return bool(section("movement", section_name).get("enabled", true))


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
