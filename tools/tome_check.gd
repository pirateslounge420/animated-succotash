extends SceneTree
## Tomes: the I Ching first (design 3 Oct §DL, data/tomes.json, Tomes,
## TomePanel), headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/tome_check.gd
##  - as the data stands (no text yet): no tome lies at any of 200 delve
##    hearts, and the dev overlay says "tome text missing: iching";
##  - with a three-page test file in the format (data/tomes/README.md): the
##    panel opens on the title, turns three pages and no more, and back;
##  - about 15 % (±5) of 200 seeded delve hearts hold a tome;
##  - taking one writes "You found a tome: The Book of Changes";
##  - the clock runs while the panel is open.

const TEST_FILE := "user://tome_test.txt"

var fails := 0
var main: Node
var world: Node


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	# --- As the data stands: no text, no tomes. ---
	Tomes.override = {}
	var none := 0
	for s in 200:
		if Tomes.heart_tome(hash([s, "delve"])) != "":
			none += 1
	var overlay: String = Hud.tome_text()
	print("   missing: %s; overlay:%s" % [str(Tomes.missing()), overlay.replace("\n", " | ")])
	ok(none == 0, "no text in: no tome at any of 200 hearts (%d)" % none)
	ok(overlay.contains("tome text missing: iching"), "the overlay says the I Ching's text is missing")
	# --- A three-page test file. ---
	var f := FileAccess.open(TEST_FILE, FileAccess.WRITE)
	f.store_string("The Book of Changes\n---\n1. The First\nHeaven moves on.\n---\n2. The Second\nThe earth receives.\n\nIt bears all things.\n---\n3. The Third\nDifficulty at the start.\n")
	f.close()
	Tomes.override = {"iching": {"text_file": TEST_FILE, "filled": true}}
	var book := Tomes.book("iching")
	ok(str(book.get("title", "")) == "The Book of Changes" and (book.get("pages", []) as Array).size() == 3, "the test file reads as a title and %d pages" % (book.get("pages", []) as Array).size())
	var panel: TomePanel = main.tome_panel
	ok(panel.open("iching") and panel.page == 0 and str(panel.shown()[0]) == "The Book of Changes", "the panel opens on the title page (\"%s\")" % str(panel.shown()[0]))
	var heads: Array = []
	for k in 4:
		panel.turn(1)
		heads.append(str(panel.shown()[0]))
	print("   turned: %s" % str(heads))
	ok(heads == ["1. The First", "2. The Second", "3. The Third", "3. The Third"] and panel.page == 3, "it turns three pages and no more")
	var second_body := ""
	panel.turn(-1)
	second_body = str(panel.shown()[1])
	ok(panel.page == 2 and second_body.contains("It bears all things."), "and back a page (\"%s\")" % second_body.replace("\n", " / "))
	# The clock runs while it's open.
	var d0: float = world.days
	for i in 120:
		await process_frame
	ok(panel.visible and world.days > d0, "the clock runs with the panel open (%.5f -> %.5f days)" % [d0, world.days])
	panel.close()
	# --- The share at the hearts. ---
	var got := 0
	for s in 200:
		if Tomes.heart_tome(hash([s, "delve"])) == "iching":
			got += 1
	var share := got / 200.0
	ok(absf(share - 0.15) <= 0.05, "with the text in: %d of 200 hearts hold the tome (%.0f %%)" % [got, share * 100.0])
	ok(Tomes.heart_tome(hash([7, "delve"])) == Tomes.heart_tome(hash([7, "delve"])), "seeded per delve (the same heart, the same answer)")
	# --- Taking one. ---
	var pd: Vector3 = main.player.surface_dir
	var it := WorldItem.drop(Tomes.item("iching"), world, pd, world.radius_of(main.player.global_position) - PlanetConst.RADIUS_M)
	await process_frame
	main._take_lying(it, false)
	var last: String = GameLog.entries[GameLog.entries.size() - 1].text if not GameLog.entries.is_empty() else ""
	ok(main.player.inventory.slot_of("tome") >= 0 and last == "You found a tome: The Book of Changes", "taken: in the pack, and the log says \"%s\"" % last)
	Tomes.override = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
