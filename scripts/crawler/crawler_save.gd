class_name CrawlerSave
## One world per new game, kept for good (design 7 Oct §FK.2; crawler.json
## persistence, worlds.json generation; queue 63).
##
## The game's seed: a new game rolls one (roll), and every dungeon's own
## seed is drawn from it and the dungeon's place in the world
## (dungeon_seed): place 0 is the first dungeon (§FJ.1's pick from the
## roster once it is wired; the tomb until then), built from the game's own
## seed, so SEED= pins the very tombs the checks have always known; each
## later place is the next dungeon the way out leads to (exit.stand_in until
## §EW.3's seam or §EW.7's surface is built: 1, 2, ...), its seed drawn from
## the game's seed and that place, never the game's own. The same game
## always makes the same first tomb and the same next one. (§FM.8's compass
## will name places when it is built; the place is a number until then.)
##
## The save (persistence.save): the game's seed, the place you are in, and
## every dungeon you have been in (its seed and theme, its holders'
## fingerprint, and the holders you relit there, by their index in the
## layout's order; gates when they exist, keep()), and the tome pages you
## hold, game-wide (data "tome_pages", design §FM.5: TomePages, queue 73), in
## user://crawler/<game seed>.json. It sits beside the open world's
## user://worlds (WorldSave, Torchfire 2's, untouched): the two games keep
## their own seeds and their own "last", so neither can open the other's
## world. Written whenever it changes (a new game, a holder catching, a
## walk out into the next dungeon) and when the game closes.
## user://crawler/last.json names the last game played: Continue opens it
## (persistence.continue last_world), in the dungeon you were in.
##
## The tools never write a save: under WorldSave.read_only, and in any
## --script run whatever it says, the save lives in `memory` only, never on
## disk, and is read back from there (the checks' round trip).

static var P: Dictionary = Tuning.table("crawler").get("persistence", {})

const VERSION := 1
const DIR := "user://crawler"
const LAST_PATH := "user://crawler/last.json"
## Game and dungeon seeds run 1..SEED_MAX (the tomb's seed's range, "Tomb
## 7731" in the log).
const SEED_MAX := 999999

## The game being played: its seed, the place you are in, and the save as
## kept ({"version", "game_seed", "place", "dungeons": {"<place>": {...}}}).
static var game_seed := 0
static var place := 0
static var data := {}
## This session opened a kept game (Continue), not a fresh one.
static var continued := false
## The next begin() starts a new game (Settings' New game; the boot's
## choice), whatever SEED= or the last game say.
static var new_game_requested := false
## The tools' save, path -> text (read_only()).
static var memory := {}
## Writes of the save and the pointer: all of them, and those to disk.
static var writes := 0
static var disk_writes := 0


## Does the save stay off the disk (the tools): WorldSave.read_only, or a
## --script run.
static func read_only() -> bool:
	if WorldSave.read_only:
		return true
	var args := OS.get_cmdline_args()
	return args.has("--script") or args.has("-s")


static func path_of(g: int) -> String:
	return "%s/%d.json" % [DIR, g]


static func _read(path: String) -> Variant:
	var text := ""
	if read_only():
		text = str(memory.get(path, ""))
	elif FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	if text == "":
		return null
	return JSON.parse_string(text)


static func _write(path: String, value: Variant) -> void:
	var text := JSON.stringify(value, " ")
	writes += 1
	if read_only():
		memory[path] = text
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("CrawlerSave: could not write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_string(text)
	disk_writes += 1


## The seed of the last game played (0: none).
static func last_seed() -> int:
	var v = _read(LAST_PATH)
	return int(v.get("game_seed", 0)) if v is Dictionary else 0


## The kept save of game `g`, or {} when there is none.
static func kept(g: int) -> Dictionary:
	if g == 0:
		return {}
	var v = _read(path_of(g))
	return v if v is Dictionary and int(v.get("game_seed", 0)) == g else {}


## Is there a game to Continue (persistence.continue last_world, and the
## last game's save is there)?
static func can_continue() -> bool:
	return str(P.get("continue", "last_world")) == "last_world" and not kept(last_seed()).is_empty()


## The game SEED= pins (the checks), or 0.
static func pinned_seed() -> int:
	var env := OS.get_environment("SEED")
	return int(env) if env.is_valid_int() and int(env) != 0 else 0


## A fresh game seed, never `avoid` (the game just played).
static func roll(avoid := 0) -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var s := rng.randi_range(1, SEED_MAX)
	while s == avoid:
		s = rng.randi_range(1, SEED_MAX)
	return s


## The start of a session (CrawlerMain._ready): which game, and where in it.
## New game asked for: a new seed. SEED= (`pinned`): that game, fresh, at
## its first dungeon. Else the last game played, as it was kept (Continue),
## in the dungeon you were in. Else a new seed. The save is written at once
## and the last-game pointer moved to this game.
static func begin(pinned := 0) -> void:
	var asked_new := new_game_requested
	new_game_requested = false
	continued = false
	data = {}
	game_seed = 0
	if not asked_new and pinned != 0:
		game_seed = pinned
	elif not asked_new and can_continue():
		data = kept(last_seed())
		game_seed = int(data.game_seed)
		continued = true
	if game_seed == 0:
		game_seed = roll(last_seed())
	if not continued:
		data = {"version": VERSION, "game_seed": game_seed, "place": 0, "dungeons": {}}
	if not data.get("dungeons") is Dictionary:
		data["dungeons"] = {}
	place = maxi(int(data.get("place", 0)), 0)
	data["place"] = place
	save()
	_write(LAST_PATH, {"game_seed": game_seed})


## The seed of dungeon `at` in game `g` (persistence.dungeon_seeds
## from_game_seed): the first (place 0) the game's own seed; each later
## place's drawn from the game's seed and the place, never the game's own.
static func dungeon_seed(g: int, at: int) -> int:
	if at <= 0:
		return g
	var s := posmod(hash([g, "dungeon", at]), SEED_MAX) + 1
	return s if s != g else posmod(s, SEED_MAX) + 1


## Dungeon `at` as kept in this game's save ({} where you have not been).
static func dungeon(at: int) -> Dictionary:
	var ds = data.get("dungeons", {})
	var d = ds.get(str(at), {}) if ds is Dictionary else {}
	return d if d is Dictionary else {}


## The seed of dungeon `at` in this game: the one kept where you have been
## (kept for good, whatever later rules would draw), else drawn now.
static func seed_at(at: int) -> int:
	var d := dungeon(at)
	return int(d.seed) if d.has("seed") else dungeon_seed(game_seed, at)


## The theme kept for dungeon `at`, or "" (the layout's own: §FJ.1's pick
## is not wired yet, so opening.first_theme).
static func theme_at(at: int) -> String:
	var th := str(dungeon(at).get("theme", ""))
	return th if (Tuning.table("crawler").get("themes", {}) as Dictionary).has(th) else ""


## You are in dungeon `at` of this game now, built as `lay`
## (CrawlerMain._load_tomb): the place you are in, and the dungeon's seed,
## theme and holders' fingerprint, kept and written. Returns the holders
## kept relit there (indices into lay.holders, persistence
## relit_stays_lit) to light again as they were left: none in a dungeon new
## to you, or in one built differently from when it was kept (the rules
## changed since: it starts cold, with a warning).
static func enter(at: int, lay: Dictionary) -> Array[int]:
	place = at
	data["place"] = at
	if not data.get("dungeons") is Dictionary:
		data["dungeons"] = {}
	var ds: Dictionary = data.dungeons
	var d := dungeon(at)
	var n := (lay.get("holders", []) as Array).size()
	var fp := fingerprint(lay)
	var out: Array[int] = []
	if not d.is_empty():
		if int(d.get("layout", 0)) == fp and int(d.get("holders", -1)) == n:
			if bool(P.get("relit_stays_lit", true)):
				for i in d.get("relit", []):
					var k := int(i)
					if k >= 0 and k < n and not out.has(k):
						out.append(k)
				out.sort()
		else:
			push_warning("CrawlerSave: dungeon %d of game %d is built differently from when it was kept (its holders: %d then, %d now, not standing where they stood); its lights start cold" % [at, game_seed, int(d.get("holders", -1)), n])
			d = {}
	d["seed"] = int(lay.get("seed", 0))
	d["theme"] = str(lay.get("theme", ""))
	d["holders"] = n
	d["layout"] = fp
	d["relit"] = out.duplicate()
	ds[str(at)] = d
	save()
	return out


## The holders relit now in dungeon `at` (indices into its layout's
## holders): kept, and written when that changed.
static func keep_relit(at: int, relit: Array) -> void:
	var d := dungeon(at)
	if d.is_empty():
		return
	var now: Array[int] = []
	for i in relit:
		now.append(int(i))
	now.sort()
	var was: Array[int] = []
	for i in d.get("relit", []):
		was.append(int(i))
	if now == was:
		return
	d["relit"] = now
	save()


## Anything else dungeon `at` keeps by name (persistence.gates_keep_state:
## a gate's state once gates exist; the fork's, §FM.6), written when it
## changes; and read back (kept_value).
static func keep(at: int, key: String, value: Variant) -> void:
	var d := dungeon(at)
	if d.is_empty() or (d.has(key) and typeof(d[key]) == typeof(value) and d[key] == value):
		return
	d[key] = value
	save()


static func kept_value(at: int, key: String, dflt: Variant = null) -> Variant:
	return dungeon(at).get(key, dflt)


## Write the save now (it changed, or the game is closing).
static func save() -> void:
	if game_seed == 0 or data.is_empty():
		return
	data["version"] = VERSION
	data["game_seed"] = game_seed
	_write(path_of(game_seed), data)


## The holders lit now, by index in the layout's order.
static func relit_now(fires: CrawlerFires) -> Array[int]:
	var out: Array[int] = []
	for i in fires.holders.size():
		if FireStore.is_lit(fires.holders[i]):
			out.append(i)
	return out


## Light the holders at `indices` again as they were left (Continue, §FK.2):
## burning at once and kept, as the swing leaves one once it has caught,
## with no catching, no sound and no log line. Returns how many burn.
static func relight(fires: CrawlerFires, indices: Array) -> int:
	var n := 0
	for i in indices:
		var k := int(i)
		if k < 0 or k >= fires.holders.size():
			continue
		var h := fires.holders[k]
		var st := FireStore.store_of(h)
		if st.is_empty():
			continue
		st.erase("kindling")
		st.erase("catch_s")
		st["state"] = "low" if FireStore.share(st) < float(FireStore.F.get("low_share", 0.25)) else "flames"
		FireStore.apply(h)
		n += 1
	return n


## A fingerprint of `lay`'s holders (where each one stands), so relit
## holders are only ever lit again in the layout they were kept for.
static func fingerprint(lay: Dictionary) -> int:
	var parts := PackedStringArray()
	for h in lay.get("holders", []):
		var p: Vector3 = h.pos
		parts.append("%.2f,%.2f,%.2f" % [p.x, p.y, p.z])
	return hash("|".join(parts))


## One line on what Continue opens (the boot's choice): "Tomb 7731, 4 of
## 34 lights burning", from the last game's save; "" with none.
static func summary() -> String:
	var k := kept(last_seed())
	if k.is_empty():
		return ""
	var ds = k.get("dungeons", {})
	var d = ds.get(str(int(k.get("place", 0))), {}) if ds is Dictionary else {}
	if not d is Dictionary or d.is_empty():
		return "Tomb %d" % int(k.game_seed)
	return "Tomb %d, %d of %d lights burning" % [int(d.get("seed", 0)), (d.get("relit", []) as Array).size(), int(d.get("holders", 0))]
