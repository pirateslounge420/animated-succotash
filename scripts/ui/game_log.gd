class_name GameLog
## The log (design 30 Sept §AZ): every line stamped in game time from the
## clock, newest last; the panel (LogPanel, Enter) shows it. Anything can
## add a line: deaths with their cause, the torch lit / guttering / out, a
## fire's states, the hearth set, a camp found, a biome first entered,
## dawn and dusk, the player's own notes. `now_text` is set by main each
## frame ("Day 15 · 03:40"). Persists per world (LogPanel saves it).

static var entries: Array[Dictionary] = []
static var now_text := ""
## Set by the panel to hear new lines.
static var listeners: Array[Callable] = []
const MAX_LINES := 400


static func add(text: String, kind := "") -> void:
	var e := {"t": now_text, "text": text, "kind": kind}
	entries.append(e)
	if entries.size() > MAX_LINES:
		entries = entries.slice(entries.size() - MAX_LINES)
	for l in listeners:
		if l.is_valid():
			l.call(e)
	_save()


## Kept per world (hud.json log.persist, WorldSave): main calls
## load_saved() once the world's save is open.
static func load_saved() -> void:
	entries.clear()
	_once.clear()
	if not bool(Tuning.section("hud", "log").get("persist", true)):
		return
	var saved = WorldSave.data.get("log", null)
	if saved is Array:
		for e in saved:
			if e is Dictionary:
				entries.append(e)
				if str(e.get("kind", "")) in ["biome_entered", "camp_found"]:
					_once[str(e.get("key", ""))] = true


static func _save() -> void:
	if not bool(Tuning.section("hud", "log").get("persist", true)):
		return
	WorldSave.data["log"] = entries
	WorldSave.mark_dirty()


## A line once: the same text again (a biome re-entered) is skipped.
static var _once := {}
static func add_once(key: String, text: String, kind := "") -> void:
	if _once.has(key):
		return
	_once[key] = true
	add(text, kind)
	if not entries.is_empty():
		entries[entries.size() - 1]["key"] = key


static func clear() -> void:
	entries.clear()
	_once.clear()
