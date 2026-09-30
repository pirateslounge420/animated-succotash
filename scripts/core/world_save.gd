class_name WorldSave
## What a world keeps between sessions (design 30 Sept §AY, §AZ): the
## hearth and the log, in user://worlds/<seed>.json. Small and plain:
## anything that marks itself dirty is written a few seconds later
## (flush(), from main) and when the game closes. Phase 12 persistence
## decides the rest (the corpse, the taken fuel, the world clock).

static var path := ""
static var data := {}
static var _dirty := false
static var _timer := 0.0


static func open(seed_value: int) -> void:
	path = "user://worlds/%d.json" % seed_value
	data = {}
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				data = parsed
	_dirty = false


static func mark_dirty() -> void:
	_dirty = true


## Write if anything changed and `delta` seconds have added up to a few.
static func flush(delta: float, now := false) -> void:
	if not _dirty or path == "":
		return
	_timer += delta
	if _timer < 4.0 and not now:
		return
	_timer = 0.0
	_dirty = false
	DirAccess.make_dir_recursive_absolute("user://worlds")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
