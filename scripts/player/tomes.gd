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
##
## Collected pages (design 9 Oct §FM.5, queue 73; tomes.json
## tomes[].fragments): a tome may be split into fragments, each a run of
## its pages and its own pickup. In Torchfire 1's crawler they lie at the
## hearts of a dungeon's base layer by find's own rule (layer_fragments;
## TomePages lays them), before the text is in too: a split tome whose text
## isn't in opens at its title page only (TomePanel.open_held), which says
## how much of it you hold (held_line: "pages 1 to 5 of 12"). A tome with
## no fragments list is found whole, as above, and only in the open world.

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


# --- Collected pages (design 9 Oct §FM.5, queue 73) ------------------------------

## Tome `id`'s fragments (tomes.json tomes[].fragments): [{"id", "pages":
## [first, last], "tome"}...], its pages counted from 1 (the first page
## after the title page, data/tomes/README.md); [] for a tome found whole.
## An entry without an id or a page range is skipped.
static func fragments_of(id: String) -> Array:
	var out: Array = []
	var fr: Variant = entry(id).get("fragments", [])
	if not fr is Array:
		return out
	for f in fr:
		if not f is Dictionary or str((f as Dictionary).get("id", "")) == "":
			continue
		var pr: Variant = (f as Dictionary).get("pages", [])
		if not pr is Array or (pr as Array).size() < 2:
			continue
		var a := maxi(int(pr[0]), 1)
		out.append({"id": str(f.id), "pages": [a, maxi(int(pr[1]), a)], "tome": id})
	return out


## Is tome `id` split into fragments (found as pages, never whole)?
static func split(id: String) -> bool:
	return not fragments_of(id).is_empty()


## Fragment `fid` of any tome ({"id", "pages", "tome"}), or {}.
static func fragment(fid: String) -> Dictionary:
	for t in entries():
		for f in fragments_of(str(t.get("id", ""))):
			if str(f.id) == fid:
				return f
	return {}


## How many pages tome `id` has: its text's once the text is in, else the
## furthest page its fragments name (0 for a whole tome without its text).
static func total_pages(id: String) -> int:
	var b := book(id)
	if not b.is_empty():
		return (b.get("pages", []) as Array).size()
	var n := 0
	for f in fragments_of(id):
		n = maxi(n, int(f.pages[1]))
	return n


## The pages of tome `id` that the fragments `fragment_ids` hold (ids of
## any tome; the others are passed over): its page numbers, sorted, each
## once, none past total_pages.
static func pages_held(id: String, fragment_ids: Array) -> Array:
	var total := total_pages(id)
	var seen := {}
	for f in fragments_of(id):
		if not fragment_ids.has(str(f.id)):
			continue
		for p in range(int(f.pages[0]), mini(int(f.pages[1]), total) + 1):
			seen[p] = true
	var out: Array = seen.keys()
	out.sort()
	return out


## Runs of consecutive page numbers in `pages` (sorted): [[first, last]...].
static func runs_of(pages: Array) -> Array:
	var out: Array = []
	for p in pages:
		var k := int(p)
		if not out.is_empty() and int(out[-1][1]) == k - 1:
			out[-1][1] = k
		else:
			out.append([k, k])
	return out


## What tome `id`'s title page says you hold of it, the fragments
## `fragment_ids` in hand (design §FM.5, queue 73): "pages 1 to 5 of 12";
## "pages 1 to 5 and 9 to 12 of 12"; "page 7 of 12"; "pages 1 to 12 of 12"
## with all of it; "none of its 12 pages" with none.
static func held_line(id: String, fragment_ids: Array) -> String:
	var total := total_pages(id)
	var runs := runs_of(pages_held(id, fragment_ids))
	if runs.is_empty():
		return "none of its %d pages" % total
	var parts: Array = []
	for r in runs:
		parts.append(str(r[0]) if int(r[0]) == int(r[1]) else "%d to %d" % [int(r[0]), int(r[1])])
	var said := str(parts[0])
	if parts.size() > 1:
		said = ", ".join(parts.slice(0, parts.size() - 1)) + " and " + str(parts[-1])
	var one := runs.size() == 1 and int(runs[0][0]) == int(runs[0][1])
	return "%s %s of %d" % ["page" if one else "pages", said, total]


## The pages lying at the hearts of a dungeon's base layer (design §FM.5,
## queue 73; Torchfire 1's crawler, TomePages), by find's own rule as at
## the delves' hearts (heart_tome): find.at delve_heart, the base layer's
## hearts (the room at the far end of each of its ways) standing for the
## delves'; of them find.share_of_hearts hold a fragment, each heart seeded
## on its own (`seed_v` the dungeon's, k its heart's), never in a chest.
## The pool: every split tome's fragments (its text in or not: one whose
## text isn't in opens at its title page only), but a tome's with a
## found_at of its own; none twice in one dungeon. [fragment id or "" per
## heart], `hearts` long. A whole tome never lies here.
static func layer_fragments(seed_v: int, hearts: int) -> Array:
	var out: Array = []
	var find: Dictionary = D.get("find", {})
	var on := str(find.get("at", "delve_heart")) == "delve_heart"
	var share := float(find.get("share_of_hearts", 0.15))
	var pool: Array = []
	for t in entries():
		var id := str(t.get("id", ""))
		if str(entry(id).get("found_at", "delve_heart")) != "delve_heart":
			continue
		for f in fragments_of(id):
			pool.append(str(f.id))
	for k in hearts:
		var got := ""
		if on and not pool.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([seed_v, "tome", k])
			if rng.randf() < share:
				got = str(pool[rng.randi() % pool.size()])
				pool.erase(got)
		out.append(got)
	return out
