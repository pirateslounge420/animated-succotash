extends SceneTree
## One world per new game, kept for good (design 7 Oct §FK.2 and §FK.3;
## queue 63; CrawlerSave, CrawlerMain, BootMenu; crawler.json persistence,
## worlds.json generation and clock), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/crawler_save_check.gd
## SEED picks the first game (7 if unset); the second game is SEED + 8.
## Asserts:
##  1. the game's seed (persistence.dungeon_seeds): the first dungeon's
##     seed is the game's own, each later place's drawn from the game's seed
##     and the place, never the game's own, the first five places all
##     different and in range over 300 game seeds; the same game seed builds
##     the same first tomb and the same next tomb twice over (pieces,
##     holders, exits); two different game seeds build different first
##     tombs and different next ones;
##  2. in the scene: SEED= is that game, fresh, at place 0 with every holder
##     cold, its tomb that first tomb; walking out builds the game's next
##     tomb (place 1); and from a second fresh start of the same game the
##     same two tombs again;
##  3. the save: three holders relit (the swing's way), kept as they catch;
##     the scene gone (the game closing) and a fresh one opened by Continue
##     (no SEED): the same game and place, you on the mat by its hearth, the
##     same three lit and no others, the log's Continue line, its first line
##     counting only the cold ones; walked out of and two lit in the next,
##     then Continue again: place 1 with its two lit, place 0's three kept;
##  4. New game after that: a different seed, place 0, every holder cold,
##     the last-game pointer at the new game and the old game's save still
##     kept; Settings' line reads New game in the crawler; persistence
##     .continue other than last_world: no Continue. The boot (the project's
##     main scene, booted for real): the first launch, nothing kept, shows
##     no choice and opens a new game; with a game kept it shows the plain
##     choice (BootMenu) with its Continue line: Continue opens that game,
##     New game asks again and only then starts a new one, every holder
##     cold;
##  5. kept all relit: every holder of a game's first tomb relit, then
##     Continue: every one lit, the floor cleared already with no log line
##     again (cleared.log_line), every resident bones in its niche or grave
##     and drawn there, none up 5 s on, the snake down its hole and unseen
##     (no release line again);
##  6. a kept dungeon built differently (its holders' fingerprint changed):
##     Continue starts it cold, and the save keeps the layout as built now;
##  7. a check run writes no save: CrawlerSave.read_only() in a --script run
##     even with WorldSave.read_only off; every write of this run went to
##     memory, none to disk; nothing under user://crawler changed;
##  8. one clock (§FK.3, worlds.json clock): the crawler's day is 144
##     minutes (World.day_length_s); dawn, day, dusk and night start at the
##     same clock times in every game and tomb the run opened (the sun's
##     height the crawler reads, Vents.sun_deg, crossing day_cycle.json's
##     twilight lines), as DayCycle's reference day has them at no latitude
##     and no tilt, lasting 18, 60, 18 and 48 minutes, the same on a day half
##     a year on; the scene's shafts and way out read that clock; worlds.json
##     says one shared clock, no latitude.

var fails := 0
var main: CrawlerMain
var game_a := 7
var game_b := 15
## Each opened game and tomb's phase starts (clock fractions), by name.
var phase_seen := {}
## The tombs' signatures, by "<game>/<place>".
var sigs := {}


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	WorldSave.read_only = true
	Bow.need_capture = false
	Residents.stay_asleep = true
	Torch.burn_down = false
	if OS.get_environment("SEED").is_valid_int() and int(OS.get_environment("SEED")) > 0:
		game_a = int(OS.get_environment("SEED"))
	game_b = game_a + 8
	var disk_before := _disk()
	_seeds()
	await _boot_first()
	await _in_scene()
	await _round_trip()
	await _new_game()
	await _all_relit()
	await _changed_layout()
	_no_save(disk_before)
	_clock()
	Residents.stay_asleep = false
	Torch.burn_down = true
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers --------------------------------------------------------------------

## The crawler's scene, opened as the game would be (CrawlerMain._ready:
## CrawlerSave.begin with SEED= as it is set now), once its hearth room is
## ready.
func _open() -> CrawlerMain:
	var m: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(m)
	for i in 10:
		await physics_frame
	var guard := 0
	while not m.baked and guard < 6000:
		await process_frame
		guard += 1
	_phases_here(m)
	return m


## The scene gone, as when the game closes (its _exit_tree keeps the save).
func _close(m: CrawlerMain) -> void:
	if m != null and is_instance_valid(m):
		m.queue_free()
	await process_frame
	await process_frame


## The game as it boots (scenes/boot.tscn, the project's main scene): the
## boot's plain choice if it shows one, `picks` picked on it in turn, then
## the crawler it changes to, once its hearth room is ready. [the choice
## shown, its Continue line, the crawler (null if none came), the boot
## (still up, its choice waiting, when none came)].
func _boot(picks: Array, boot: Node = null) -> Array:
	if boot == null:
		boot = load("res://scenes/boot.tscn").instantiate()
		get_root().add_child(boot)
		await process_frame
	var menu := boot.get_node_or_null("UI/BootMenu") as BootMenu
	var shown := menu != null and menu.is_inside_tree() and menu.visible
	var note := menu.note if menu != null else ""
	if menu != null:
		for id in picks:
			menu.pick(str(id))
	var guard := 0
	while not (current_scene is CrawlerMain) and guard < 120:
		await process_frame
		guard += 1
	var m := current_scene as CrawlerMain
	if m == null:
		return [shown, note, null, boot]
	boot.queue_free()
	for i in 10:
		await physics_frame
	guard = 0
	while not m.baked and guard < 6000:
		await process_frame
		guard += 1
	_phases_here(m)
	return [shown, note, m, null]


## Out through the way out (the stand-in), until the next tomb's hearth room
## is ready.
func _walk_out(m: CrawlerMain) -> void:
	m.walk_out()
	var guard := 0
	while (m.leaving or not m.baked) and guard < 6000:
		await process_frame
		guard += 1
	_phases_here(m)


## Light holder `h` the swing's way (FireStore.swing_light), the flame let
## take, then a physics step or two for the scene to count it.
func _light(h: Node3D) -> void:
	FireStore.swing_light(h, float(main.world.get("days")))
	for i in 600:
		FireStore.tick(self, 1.0 / 60.0, h.global_position)
		if FireStore.is_lit(h):
			return


## A tomb's pieces, holders and exits, as text (the same text, the same
## tomb).
static func _sig(lay: Dictionary) -> String:
	return var_to_str([lay.get("pieces", []), lay.get("holders", []), lay.get("exits", [])])


static func _counts(lay: Dictionary) -> String:
	return "%d pieces, %d holders, %d exits" % [(lay.pieces as Array).size(), (lay.holders as Array).size(), (lay.exits as Array).size()]


## The relit holders kept for place `at` now.
static func _kept_relit(at: int) -> Array:
	var out: Array = []
	for i in CrawlerSave.dungeon(at).get("relit", []):
		out.append(int(i))
	return out


## Three holders spread through the tomb's list.
static func _three(n: int) -> Array:
	return [0, int(n * 0.5), n - 1]


## Every resident in the scene lying as bones in its place, drawn.
func _bones(m: CrawlerMain) -> int:
	var n := 0
	for c in m.residents.get_children():
		var q := c as Resident
		if q != null and is_instance_valid(q) and not q.is_queued_for_deletion() and q.state == Resident.BONES and q.sprite != null and q.sprite.visible and not q.hole.is_empty() and q.global_position.distance_to(q.hole.pos) < 0.01:
			n += 1
	return n


func _residents_in(m: CrawlerMain) -> int:
	var n := 0
	for c in m.residents.get_children():
		if c is Resident:
			n += 1
	return n


func _awake(m: CrawlerMain) -> int:
	var n := 0
	for c in m.residents.get_children():
		var q := c as Resident
		if q != null and q.state != Resident.BONES:
			n += 1
	return n


## Log lines of `kind`, and whether `text` is among them.
static func _log_kind(kind: String) -> int:
	var n := 0
	for e in GameLog.entries:
		if str(e.get("kind", "")) == kind:
			n += 1
	return n


static func _logged(text: String) -> bool:
	for e in GameLog.entries:
		if str(e.get("text", "")) == text:
			return true
	return false


static func _log_begins(text: String) -> bool:
	for e in GameLog.entries:
		if str(e.get("text", "")).begins_with(text):
			return true
	return false


## What is under user://crawler on disk: {file: modified time}.
static func _disk() -> Dictionary:
	var out := {}
	if not DirAccess.dir_exists_absolute(CrawlerSave.DIR):
		return out
	for f in DirAccess.get_files_at(CrawlerSave.DIR):
		out[f] = FileAccess.get_modified_time(CrawlerSave.DIR + "/" + f)
	return out


# --- 1. the game's seed -----------------------------------------------------------

func _seeds() -> void:
	ok(CrawlerSave.dungeon_seed(game_a, 0) == game_a and CrawlerSave.dungeon_seed(game_b, 0) == game_b, "the first dungeon's seed is the game's own (game %d: tomb %d), so SEED= pins the tombs the checks know" % [game_a, CrawlerSave.dungeon_seed(game_a, 0)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 6301
	var clash := 0
	var own := 0
	var out := 0
	var again := 0
	for i in 300:
		var g := rng.randi_range(1, CrawlerSave.SEED_MAX)
		var seen := {}
		for at in 5:
			var s := CrawlerSave.dungeon_seed(g, at)
			if s < 1 or s > CrawlerSave.SEED_MAX:
				out += 1
			if at > 0 and s == g:
				own += 1
			if seen.has(s):
				clash += 1
			seen[s] = true
			if CrawlerSave.dungeon_seed(g, at) != s:
				again += 1
	ok(clash == 0 and own == 0 and out == 0 and again == 0, "over 300 game seeds each later place's seed is drawn from the game's seed and the place: the first five places all different (%d clashes), none the game's own past the first (%d), all in 1-%d (%d out), the same when drawn again (%d not)" % [clash, own, CrawlerSave.SEED_MAX, out, again])
	var a0 := TombKit.layout(CrawlerSave.dungeon_seed(game_a, 0))
	var a1 := TombKit.layout(CrawlerSave.dungeon_seed(game_a, 1))
	var a0b := TombKit.layout(CrawlerSave.dungeon_seed(game_a, 0))
	var a1b := TombKit.layout(CrawlerSave.dungeon_seed(game_a, 1))
	sigs["%d/0" % game_a] = _sig(a0)
	sigs["%d/1" % game_a] = _sig(a1)
	ok(_sig(a0) == _sig(a0b) and _sig(a1) == _sig(a1b) and _sig(a0) != _sig(a1), "game %d builds the same first tomb (seed %d: %s) and the same next tomb (seed %d: %s) twice over: the same pieces, holders and exits" % [game_a, int(a0.seed), _counts(a0), int(a1.seed), _counts(a1)])
	var b0 := TombKit.layout(CrawlerSave.dungeon_seed(game_b, 0))
	var b1 := TombKit.layout(CrawlerSave.dungeon_seed(game_b, 1))
	sigs["%d/0" % game_b] = _sig(b0)
	sigs["%d/1" % game_b] = _sig(b1)
	ok(_sig(a0) != _sig(b0) and _sig(a1) != _sig(b1), "two different game seeds build different first tombs (game %d: %s; game %d: %s) and different next ones" % [game_a, _counts(a0), game_b, _counts(b0)])


# --- 2. in the scene ----------------------------------------------------------------

## The very first launch (no game kept, no SEED): the boot shows no choice
## and opens straight onto a new game.
func _boot_first() -> void:
	OS.set_environment("SEED", "")
	var b := await _boot([])
	var m: CrawlerMain = b[2]
	ok(not bool(b[0]) and m != null and not CrawlerSave.continued and CrawlerSave.game_seed > 0 and CrawlerSave.place == 0 and m.seed_value == CrawlerSave.game_seed and m.fires.lit_count() == 0, "the first launch, nothing kept: the boot shows no choice and opens a new game (game %d, every holder cold)" % CrawlerSave.game_seed)
	await _close(m)


func _in_scene() -> void:
	OS.set_environment("SEED", str(game_a))
	var walks: Array = []
	for run in 2:
		main = await _open()
		var first_ok: bool = CrawlerSave.game_seed == game_a and CrawlerSave.place == 0 and not CrawlerSave.continued and main.seed_value == game_a and main.fires.lit_count() == 0 and _sig(main.lay) == str(sigs["%d/0" % game_a])
		await _walk_out(main)
		var next_ok: bool = CrawlerSave.place == 1 and main.seed_value == CrawlerSave.dungeon_seed(game_a, 1) and main.fires.lit_count() == 0 and _sig(main.lay) == str(sigs["%d/1" % game_a])
		walks.append([first_ok, next_ok, main.seed_value])
		await _close(main)
	ok(bool(walks[0][0]) and bool(walks[1][0]), "SEED=%d is game %d, fresh at its first dungeon both times: place 0, tomb %d, every holder cold, the first tomb's pieces, holders and exits" % [game_a, game_a, game_a])
	ok(bool(walks[0][1]) and bool(walks[1][1]) and int(walks[0][2]) == int(walks[1][2]), "walking out builds the game's next tomb both times: place 1, tomb %d, its holders cold, the same pieces, holders and exits" % int(walks[0][2]))


# --- 3. the save ------------------------------------------------------------------------

func _round_trip() -> void:
	OS.set_environment("SEED", str(game_a))
	main = await _open()
	var n := main.fires.holders.size()
	var pick := _three(n)
	for i in pick:
		_light(main.fires.holders[int(i)])
	await _frames(3)
	var writes0 := CrawlerSave.writes
	ok(_kept_relit(0) == pick and main.fires.lit_count() == 3, "three holders relit (%s of %d) are kept as they catch (%s)" % [str(pick), n, str(_kept_relit(0))])
	await _close(main)
	ok(CrawlerSave.writes > writes0, "the scene gone (the game closing): the save written again (%d writes)" % (CrawlerSave.writes - writes0))
	OS.set_environment("SEED", "")
	main = await _open()
	var lit_now := CrawlerSave.relit_now(main.fires)
	var p := main.player
	var at_mat := (p.global_position - (main.lay.wake[0] as Vector3)).length()
	ok(CrawlerSave.continued and CrawlerSave.game_seed == game_a and CrawlerSave.place == 0 and main.seed_value == game_a and _sig(main.lay) == str(sigs["%d/0" % game_a]), "Continue (no SEED) opens the last game where it was left: game %d, place 0, tomb %d, the same tomb" % [CrawlerSave.game_seed, main.seed_value])
	ok(lit_now == pick and main.fires.lit_count() == 3, "reloaded into a fresh scene, the same three are lit and no others (%s, %d of %d)" % [str(lit_now), main.fires.lit_count(), n])
	ok(at_mat < 0.6 and TombKit.piece_at(main.lay, p.global_position) == 0, "you wake on the mat by its hearth (%.2f m from it)" % at_mat)
	var first := str(GameLog.entries[0].get("text", "")) if not GameLog.entries.is_empty() else ""
	var cont := str(CrawlerSave.P.get("log_continue", ""))
	ok(cont != "" and _logged(cont) and first.contains("%d cold lights below" % (n - 3)) and not _log_begins("%d of %d lights burn again" % [3, n]), "the log: \"%s\" and \"%s\" (the cold ones only; no count of lights for the kept ones)" % [first, cont])
	# On into the next tomb, two lit there, and Continue again.
	await _walk_out(main)
	var n1 := main.fires.holders.size()
	var pick1 := [1, n1 - 2]
	for i in pick1:
		_light(main.fires.holders[int(i)])
	await _frames(3)
	await _close(main)
	main = await _open()
	ok(CrawlerSave.continued and CrawlerSave.place == 1 and main.seed_value == CrawlerSave.dungeon_seed(game_a, 1) and CrawlerSave.relit_now(main.fires) == pick1, "walked out, two lit in the next tomb and Continue: you are in place 1 (tomb %d) with its two lit (%s) and no others" % [main.seed_value, str(CrawlerSave.relit_now(main.fires))])
	ok(_kept_relit(0) == pick and int(CrawlerSave.dungeon(0).get("seed", 0)) == game_a, "and the first tomb's three are still kept (%s)" % str(_kept_relit(0)))


# --- 4. New game ----------------------------------------------------------------------

func _new_game() -> void:
	var old := CrawlerSave.game_seed
	# Settings' line in the crawler (the open scene is the crawler).
	var sp := SettingsPanel.new()
	var item: Array = ["world.new", "New world", "action"]
	var line: String = sp._shown(item)
	sp._armed = "world.new"
	var armed: String = sp._shown(item)
	sp.free()
	ok(GameMode.crawler_running and line == "> New game" and armed.begins_with("Start a new game?"), "Settings' New world line reads \"%s\" in the crawler, and asks first: \"%s\"" % [line, armed])
	main.start_new_world()
	await process_frame
	await process_frame
	ok(CrawlerSave.new_game_requested, "New game asks the next start for a new seed")
	main = await _open()
	var cold := main.fires.lit_count() == 0
	ok(CrawlerSave.game_seed != old and not CrawlerSave.continued and CrawlerSave.place == 0 and main.seed_value == CrawlerSave.game_seed and cold, "New game after that rolls a different seed (game %d after %d), at its first dungeon, every holder cold (%d lit)" % [CrawlerSave.game_seed, old, main.fires.lit_count()])
	ok(CrawlerSave.last_seed() == CrawlerSave.game_seed and not CrawlerSave.kept(old).is_empty() and CrawlerSave.can_continue(), "the last-game pointer names the new game (%d); game %d's save is still kept" % [CrawlerSave.last_seed(), old])
	# The boot's choice.
	var menu := BootMenu.new()
	var got: Array = []
	menu.picked.connect(func(which: String) -> void: got.append(which))
	var first_new := menu.pick("new")
	var second_new := menu.pick("new")
	var menu2 := BootMenu.new()
	menu2.picked.connect(func(which: String) -> void: got.append(which))
	var cont := menu2.pick("continue")
	menu.free()
	menu2.free()
	ok(not first_new and second_new and cont and got == ["new", "continue"], "the boot's choice: Continue goes at once; New game asks first and goes on its second pick (%s)" % str(got))
	ok(CrawlerSave.summary().begins_with("Tomb %d" % CrawlerSave.game_seed), "its Continue line says which: \"%s\"" % CrawlerSave.summary())
	var was = CrawlerSave.P.get("continue", "last_world")
	CrawlerSave.P["continue"] = "never"
	var off := not CrawlerSave.can_continue()
	CrawlerSave.P["continue"] = was
	ok(off and CrawlerSave.can_continue(), "persistence.continue other than last_world: no Continue")
	var fresh := CrawlerSave.game_seed
	await _close(main)
	# The game booting with that game kept: the plain choice, then each way.
	OS.set_environment("SEED", "")
	var summary := CrawlerSave.summary()
	var b := await _boot(["continue"])
	var m: CrawlerMain = b[2]
	ok(bool(b[0]) and str(b[1]) == summary and m != null and CrawlerSave.continued and CrawlerSave.game_seed == fresh and m.seed_value == fresh, "booting with a game kept shows the plain choice (\"%s\"); Continue there opens that game (%d)" % [str(b[1]), CrawlerSave.game_seed])
	await _close(m)
	b = await _boot(["new"])
	m = b[2]
	var held: Node = b[3]
	ok(bool(b[0]) and m == null and held != null and CrawlerSave.game_seed == fresh, "New game picked once there asks again, and nothing starts")
	if held != null:
		b = await _boot(["new"], held)
		m = b[2]
	ok(m != null and not CrawlerSave.continued and CrawlerSave.game_seed != fresh and m.fires.lit_count() == 0, "picked again, it starts a new game (game %d after %d), every holder cold" % [CrawlerSave.game_seed, fresh])
	await _close(m)


# --- 5. kept all relit -------------------------------------------------------------

func _all_relit() -> void:
	OS.set_environment("SEED", str(game_b))
	main = await _open()
	ok(_sig(main.lay) == str(sigs["%d/0" % game_b]) and main.seed_value == game_b, "SEED=%d: game %d's own first tomb" % [game_b, game_b])
	main.boss.auto = false
	var n := main.fires.holders.size()
	for h in main.fires.holders:
		_light(h)
	await _frames(3)
	ok(_kept_relit(0).size() == n, "every holder of game %d's first tomb relit and kept (%d of %d)" % [game_b, _kept_relit(0).size(), n])
	await _close(main)
	OS.set_environment("SEED", "")
	Residents.stay_asleep = false
	main = await _open()
	var b := main.boss
	await _frames(5)
	var res := main.residents
	var everyone := _residents_in(main)
	var cleared_line := str(Residents.CLEARED.get("log_line", ""))
	var boss_line := str(Boss.RELEASE.get("log_line", "")).format({"boss": b.name_text})
	ok(CrawlerSave.continued and CrawlerSave.game_seed == game_b and main.fires.lit_count() == n, "Continue into it: every one of its %d lights burns" % n)
	ok(res.cleared and res.all.is_empty() and everyone > 0 and _bones(main) == everyone and _log_kind("cleared") == 0, "the floor cleared already, with no log line again: all %d residents lie as bones in their niches and graves, drawn there (%d)" % [everyone, _bones(main)])
	var lair_ok: bool = b.released and b.state == ("gone" if b.lair.is_empty() else "lair") and not b.body.visible
	ok(lair_ok and not _log_begins(boss_line), "the snake is down its hole as the last light left it (%s, unseen), no \"%s\" again" % [b.state, boss_line])
	# 5 s on: nothing has woken, nothing has come up.
	for i in 300:
		await physics_frame
	ok(_awake(main) == 0 and res.all.is_empty() and b.state in ["lair", "gone"] and not b.body.visible and main.harm.hits.is_empty() and cleared_line != "" and _log_kind("cleared") == 0, "5 s on none is up (%d), the snake still below, no hit" % _awake(main))
	Residents.stay_asleep = true
	await _close(main)


# --- 6. a kept dungeon built differently -------------------------------------------

func _changed_layout() -> void:
	var path := CrawlerSave.path_of(game_b)
	var kept = JSON.parse_string(str(CrawlerSave.memory.get(path, "")))
	var real := 0
	if kept is Dictionary:
		real = int(kept.dungeons["0"].layout)
		kept.dungeons["0"]["layout"] = real + 1
		CrawlerSave.memory[path] = JSON.stringify(kept)
	main = await _open()
	var d := CrawlerSave.dungeon(0)
	ok(kept is Dictionary and CrawlerSave.continued and CrawlerSave.game_seed == game_b and main.fires.lit_count() == 0 and int(d.get("layout", 0)) == real and (d.get("relit", []) as Array).is_empty(), "a kept tomb whose holders no longer match their fingerprint starts cold (%d lit), and the save keeps the layout as built now" % main.fires.lit_count())
	await _close(main)


# --- 7. no save on disk ---------------------------------------------------------------

func _no_save(before: Dictionary) -> void:
	var was := WorldSave.read_only
	WorldSave.read_only = false
	var guard := CrawlerSave.read_only()
	WorldSave.read_only = was
	ok(guard, "a --script run keeps the save off the disk even with WorldSave.read_only off")
	var after := _disk()
	ok(CrawlerSave.disk_writes == 0 and CrawlerSave.writes > 0 and after == before and not CrawlerSave.memory.is_empty(), "a check run writes no save: all %d writes in memory (%d saves held there), none to disk, user://crawler unchanged (%d files before, %d after)" % [CrawlerSave.writes, CrawlerSave.memory.size(), before.size(), after.size()])


# --- 8. one clock --------------------------------------------------------------------

## The phase starts (clock fractions) the crawler's sun gives on the day the
## scene is in, kept under its game and place (and its shafts' and way out's
## daylight checked against the clock).
func _phases_here(m: CrawlerMain) -> void:
	var day := floorf(float(m.world.get("days")))
	phase_seen["game %d place %d" % [CrawlerSave.game_seed, CrawlerSave.place]] = _crossings(day)
	if not phase_seen.has("half a year on"):
		phase_seen["half a year on"] = _crossings(day + 182.0)
	var t := float(m.world.get("days"))
	var shaft_ok := m.vents == null or absf(m.vents.daylight - Vents.daylight_at(t)) < 0.02
	var out_ok := m.way_out == null or absf(m.way_out.daylight - Vents.daylight_at(t)) < 0.02
	if not (shaft_ok and out_ok):
		_scene_clock_bad += 1


var _scene_clock_bad := 0


## Where the crawler's sun (Vents.sun_deg) crosses the twilight lines on day
## `day`: [dawn, day, dusk, night] starts as clock fractions (-1 if not).
static func _crossings(day: float) -> Array:
	var tw := DayCycle.twilight_deg()
	var out: Array = [-1.0, -1.0, -1.0, -1.0]
	var steps := 14400
	var prev := Vents.sun_deg(day)
	for i in range(1, steps + 1):
		var f := float(i) / steps
		var s := Vents.sun_deg(day + f)
		for lv: float in [-tw, tw]:
			if (prev < lv) != (s < lv):
				var k := (lv - prev) / (s - prev)
				var at := (float(i - 1) + k) / steps
				var rising := s > prev
				var idx := (0 if rising else 3) if lv < 0.0 else (1 if rising else 2)
				out[idx] = at
		prev = s
	return out


func _clock() -> void:
	var day_s := float(get_root().get_node("World").get("day_length_s"))
	ok(absf(day_s - DayCycle.day_length_min() * 60.0) < 0.01 and absf(DayCycle.day_length_min() - 144.0) < 0.01, "the crawler's day is 144 minutes (World.day_length_s %.0f s)" % day_s)
	var ref := DayCycle.phase_starts(0.0, 0.0)
	var names := ["dawn", "day", "dusk", "night"]
	var same := true
	var tol := 2.0 / 14400.0
	for k in phase_seen:
		var c: Array = phase_seen[k]
		for i in 4:
			if absf(float(c[i]) - float(ref[i])) > tol:
				same = false
	var starts: Array = []
	for i in 4:
		starts.append("%s %.4f" % [names[i], float(ref[i])])
	ok(same and phase_seen.size() >= 4, "dawn, day, dusk and night start at the same clock times in every game and tomb this run opened, and half a year on (%s: %s)" % [", ".join(phase_seen.keys()), ", ".join(starts)])
	var day_min := DayCycle.day_length_min()
	var mins := [
		fposmod(float(ref[1]) - float(ref[0]), 1.0) * day_min,
		fposmod(float(ref[2]) - float(ref[1]), 1.0) * day_min,
		fposmod(float(ref[3]) - float(ref[2]), 1.0) * day_min,
		fposmod(float(ref[0]) - float(ref[3]), 1.0) * day_min]
	var want: Dictionary = DayCycle.phase_minutes()
	var split_ok := absf(mins[0] - float(want.dawn)) < 0.05 and absf(mins[1] - float(want.day)) < 0.05 and absf(mins[2] - float(want.dusk)) < 0.05 and absf(mins[3] - float(want.night)) < 0.05
	ok(split_ok and absf(float(want.day) - 60.0) < 0.01 and absf(float(want.dusk) - 18.0) < 0.01 and absf(float(want.night) - 48.0) < 0.01 and absf(float(want.dawn) - 18.0) < 0.01, "the fixed split of sky/day_cycle.json: dawn %.2f, day %.2f, dusk %.2f, night %.2f minutes (18, 60, 18, 48), no latitude, tilt or day of year" % mins)
	ok(_scene_clock_bad == 0, "in every scene the shafts' and the way out's daylight follow that clock")
	var w = JSON.parse_string(FileAccess.get_file_as_string("res://data/worlds.json"))
	var clock: Dictionary = w.get("clock", {}) if w is Dictionary else {}
	ok(bool(clock.get("shared", false)) and not bool(clock.get("day_length_from_latitude", true)) and str(clock.get("latitude", "")) == "none" and str(clock.get("day", "")) == "sky/day_cycle.json", "worlds.json clock: one shared clock from sky/day_cycle.json, no latitude")
