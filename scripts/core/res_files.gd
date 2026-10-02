class_name ResFiles
## Files the game reads at runtime, never needing the editor's import cache
## (design 1 Oct §CG). The cache (.godot/imported) is written only by the
## editor and git never carries it: where it lacks a file, load() fails and
## the game drew Mike's plants as grey boxes (the 23:11 play) and his HUD in
## Courier (the 15:30 play). So a file's own bytes on disk come first; the
## import is used only when it is really there (imported()); a missing import
## is one warning naming the file.

static var _warned := {}
static var _mutex := Mutex.new()


## Is the import of `path` there to load (its .import file and the imported
## data it points at)? Asked first, so a missing import never reaches load()
## and its engine errors. A resource with no .import (a .tres, a .tscn) is
## there when ResourceLoader can see it.
static func imported(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(path + ".import") != OK:
		return true
	var dest := str(cfg.get_value("remap", "path", ""))
	return dest == "" or FileAccess.file_exists(dest)


## The import of `path` isn't there: one warning naming the file (once).
static func warn_missing(path: String, what := "read from its file on disk instead") -> void:
	_mutex.lock()
	var first := not _warned.has(path)
	_warned[path] = true
	_mutex.unlock()
	if first:
		push_warning("ResFiles: %s has no import in .godot/imported; %s" % [path, what])


## An image read straight from its file on disk (png, jpg, webp, svg), or
## null if the file is missing or unreadable. No import involved.
static func disk_image(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match path.get_extension().to_lower():
		"png":
			err = img.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			err = img.load_jpg_from_buffer(bytes)
		"webp":
			err = img.load_webp_from_buffer(bytes)
		"svg":
			err = img.load_svg_from_buffer(bytes)
	return img if err == OK and not img.is_empty() else null


## The imported image of `path` (decompressed), or null when the import
## isn't there (warned once).
static func imported_image(path: String) -> Image:
	if not imported(path):
		if FileAccess.file_exists(path + ".import"):
			warn_missing(path)
		return null
	var tex := load(path) as Texture2D
	var img := tex.get_image() if tex != null else null
	if img != null and img.is_compressed():
		img.decompress()
	return img
