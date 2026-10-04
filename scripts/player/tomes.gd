class_name Tomes
## Tomes: real philosophical texts you find and read (design 3 Oct §DL,
## data/tomes.json, data/tomes/README.md). The I Ching first, as "The Book
## of Changes" in Legge's public-domain translation; the text is a data
## job (data/tomes/<file>.txt), and a tome whose text isn't in (its
## text_file missing, or its entry filled false) never lies anywhere: no
## blank books. The dev overlay says "tome text missing: <id>".
##
## Where: the heart's find of find.share_of_hearts (0.15) of the delves
## (§CJ.3), seeded per delve, in place of its spear or bow (Delves). A
## tome with its own found_at (the Tao at the pass gate, §DQ) isn't dealt
## to the hearts. No systems on it (Mike): the I Ching coin cast
## (iching.gd) is a separate thing.

static var D: Dictionary = _load()
## Tests: id -> {"text_file", "filled"} in place of the data's.
static var override := {}
static var _pages := {}


static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/tomes.json"))
	return parsed if parsed is Dictionary else {}


static func entries() -> Array:
	return D.get("tomes", [])


static func entry(id: String) -> Dictionary:
	for t in entries():
		if str(t.get("id", "")) == id:
			var e: Dictionary = (t as Dictionary).duplicate()
			e.merge(override.get(id, {}), true)
			return e
	return {}


## The path a tome's text is read from ("data/..." under res://).
static func path_of(e: Dictionary) -> String:
	var f := str(e.get("text_file", ""))
	return f if f.begins_with("res://") or f.begins_with("user://") else "res://" + f


## Is the tome's text in: filled true and its file there?
static func ready(id: String) -> bool:
	var e := entry(id)
	return not e.is_empty() and bool(e.get("filled", false)) and FileAccess.file_exists(path_of(e))


## The tomes whose text isn't in (for the dev overlay).
static func missing() -> Array:
	var out: Array = []
	for t in entries():
		if not ready(str(t.get("id", ""))):
			out.append(str(t.get("id", "")))
	return out


## The tome (id) lying at the heart of the delve seeded `seed_v`, or "":
## find.share_of_hearts of the delves, among the tomes whose text is in
## and which aren't found elsewhere (found_at).
static func heart_tome(seed_v: int) -> String:
	var find: Dictionary = D.get("find", {})
	if str(find.get("at", "delve_heart")) != "delve_heart":
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_v, "tome"])
	if rng.randf() >= float(find.get("share_of_hearts", 0.15)):
		return ""
	var pool: Array = []
	for t in entries():
		var id := str(t.get("id", ""))
		var at := str(entry(id).get("found_at", "delve_heart"))
		if at == "delve_heart" and ready(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	return str(pool[rng.randi() % pool.size()])


## The item for tome `id`.
static func item(id: String) -> Dictionary:
	return Inventory.make("tome", {"tome": id, "title": str(entry(id).get("title", "A tome"))})


## A tome's text, parsed (data/tomes/README.md): {"title", "pages":
## [{"heading", "text"}]}; {} when it isn't in. The first line is the
## title; pages are separated by a line holding only ---; a page's first
## line is its heading.
static func book(id: String) -> Dictionary:
	if _pages.has(id) and override.is_empty():
		return _pages[id]
	if not ready(id):
		return {}
	var raw := FileAccess.get_file_as_string(path_of(entry(id))).replace("\r\n", "\n")
	var lines := raw.split("\n")
	var title := lines[0].strip_edges() if lines.size() > 0 else str(entry(id).get("title", ""))
	var pages: Array = []
	var cur: Array = []
	for i in range(1, lines.size()):
		if lines[i].strip_edges() == "---":
			_add_page(pages, cur)
			cur = []
		else:
			cur.append(lines[i])
	_add_page(pages, cur)
	var b := {"title": title, "pages": pages}
	if override.is_empty():
		_pages[id] = b
	return b


static func _add_page(pages: Array, cur: Array) -> void:
	# Trim blank lines round the page.
	while not cur.is_empty() and str(cur[0]).strip_edges() == "":
		cur.pop_front()
	while not cur.is_empty() and str(cur[cur.size() - 1]).strip_edges() == "":
		cur.pop_back()
	if cur.is_empty():
		return
	pages.append({"heading": str(cur[0]).strip_edges(), "text": "\n".join(cur.slice(1)).strip_edges()})
