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
## The tools never write a save or the last-world pointer (World).
static var read_only := false
## The last world played (design 1 Oct §CB): Continue boots into it.
const LAST_PATH := "user://worlds/last.json"


static func open(seed_value: int) -> void:
	var want := "user://worlds/%d.json" % seed_value
	if path == want:
		return
	path = want
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


## The seed of the last world played (0: none).
static func last_seed() -> int:
	if not FileAccess.file_exists(LAST_PATH):
		return 0
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAST_PATH))
	return int(parsed.get("seed", 0)) if parsed is Dictionary else 0


## Point "last" at `seed_value`.
static func set_last(seed_value: int) -> void:
	if read_only:
		return
	DirAccess.make_dir_recursive_absolute("user://worlds")
	var f := FileAccess.open(LAST_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"seed": seed_value}))


## Does a save for this world exist?
static func exists(seed_value: int) -> bool:
	return FileAccess.file_exists("user://worlds/%d.json" % seed_value)


## Write if anything changed and `delta` seconds have added up to a few.
static func flush(delta: float, now := false) -> void:
	if not _dirty or path == "" or read_only:
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
