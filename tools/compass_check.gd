extends SceneTree
## The HUD compass strip (design 12 Oct §FW; queue 101; Compass; data/hud.json
## compass), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/compass_check.gd
## Asserts:
##  1. one north: a camera facing -z reads 0 (north), +x 90 (east), +z 180,
##     -x 270 (Compass.heading_of);
##  2. facing north, east, south and west puts that point's glyph on the
##     frame's middle column to the pixel, at 480 and 270 lines;
##  3. turning 360 degrees a degree at a time walks every point across the
##     strip once, left to right never (it slides the other way as you
##     turn right), and only while it is within span_deg / 2 of your facing;
##  4. every pixel is a whole-pixel rect inside the frame and the strip's
##     box (glyphs and ticks) or just under it (notches), and none is warm
##     (blue at least red, in the marks and the edge);
##  5. labels north_only draws N alone; shrine notches draw under the strip
##     at their bearings, and none come from ruin_compass.json yet (no
##     neighbour is built, §FV.2 is queue 100);
##  6. in the crawler: one Compass in the UI layer, showing; with
##     compass.on false or the Settings switch Compass off it draws
##     nothing; a panel open hides it;
##  7. phase two's blackout (§FO.5, not built: your torch put out) leaves it
##     showing; under a brew (the vision running) it is drawn above the
##     vision, unmodulated, its colour unchanged;
##  8. up on the surface: still showing, north still -z, one notch: the
##     tunnel's shrine toward the other ruin (queue 100, RuinTunnel.bearings).

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	WorldSave.read_only = true
	Bow.need_capture = false
	Residents.stay_asleep = true
	_pure()
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	while not main.baked:
		await process_frame
	if main.boss != null:
		main.boss.auto = false
	await _ticks(10)
	await _scene(main)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _pure() -> void:
	var h := [Compass.heading_of(Basis.looking_at(Vector3.FORWARD)), Compass.heading_of(Basis.looking_at(Vector3.RIGHT)), Compass.heading_of(Basis.looking_at(Vector3.BACK)), Compass.heading_of(Basis.looking_at(Vector3.LEFT))]
	ok(absf(h[0]) < 0.01 or absf(h[0] - 360.0) < 0.01, "facing -z reads north (%.2f)" % h[0])
	ok(absf(h[1] - 90.0) < 0.01 and absf(h[2] - 180.0) < 0.01 and absf(h[3] - 270.0) < 0.01, "+x east, +z south, -x west (%.2f, %.2f, %.2f)" % [h[1], h[2], h[3]])
	for frame: Vector2i in [Vector2i(854, 480), Vector2i(480, 270)]:
		var k: float = (frame as Vector2i).y / 480.0
		var centred := true
		for p: String in Compass.POINTS:
			var cl := Compass.cells(frame, float(Compass.POINTS[p]), [], k)
			if int((cl.points as Dictionary).get(p, -999)) != frame.x / 2 or int(cl.mid) != frame.x / 2:
				centred = false
			# The glyph's own pixels balanced on that column.
			var xs: Array = []
			for r: Rect2i in cl.marks:
				if r.position.y >= (cl.strip as Rect2i).position.y and absi(r.position.x - frame.x / 2) <= 3 * maxi(roundi(k), 1):
					for x in range(r.position.x, r.end.x):
						xs.append(x)
			if xs.is_empty() or xs.min() + xs.max() != 2 * (frame.x / 2):
				centred = false
		ok(centred, "%dx%d: facing N, E, S and W puts that point's glyph on the middle column (%d) to the pixel" % [frame.x, frame.y, frame.x / 2])
		# Turning: each point crosses once, and only within span / 2.
		var span := float(Compass.C.get("span_deg", 120.0))
		var walk_ok := true
		var crossings := {}
		var last := {}
		var in_ok := true
		var grid_ok := true
		var warm := false
		for d in 361:
			var cl := Compass.cells(frame, float(d), [], k)
			for p: String in Compass.POINTS:
				var vis: bool = (cl.points as Dictionary).has(p)
				var off := absf(fposmod(float(Compass.POINTS[p]) - d + 180.0, 360.0) - 180.0)
				if vis and off > span * 0.5 + 0.5:
					in_ok = false
				if vis:
					var x := int(cl.points[p])
					if last.has(p) and int(last[p]) >= 0 and x > int(last[p]):
						walk_ok = false
					if not last.has(p) or int(last[p]) < 0:
						crossings[p] = int(crossings.get(p, 0)) + 1
					last[p] = x
				else:
					last[p] = -1
			var box: Rect2i = (cl.strip as Rect2i).grow(1)
			for r: Rect2i in cl.marks + cl.edge:
				if r.position.x < 0 or r.position.y < 0 or r.end.x > frame.x or r.end.y > frame.y or r.position.x < box.position.x or r.end.x > box.end.x:
					grid_ok = false
		var col := Compass.color()
		warm = col.r > col.b or Compass.EDGE.r > Compass.EDGE.b
		# A point that starts in view (N at 0) enters once more at the end
		# of the turn's wrap only if it left; each counted entry is one.
		var once := true
		for p: String in Compass.POINTS:
			var n := int(crossings.get(p, 0))
			if n < 1 or n > 2:
				once = false
		ok(walk_ok and once and in_ok, "%dx%d: turning 360 degrees walks every point across once, right to left as you turn right, shown only within %.0f degrees of your facing (entries %s)" % [frame.x, frame.y, span * 0.5, str(crossings)])
		ok(grid_ok and not warm, "%dx%d: every pixel a whole-pixel rect inside the frame and the strip; the marks #%s and the edge never warm" % [frame.x, frame.y, Compass.color().to_html(false)])
	# north_only and the notches.
	var keep := str(Compass.C.get("labels", "cardinal"))
	Compass.C["labels"] = "north_only"
	var no := Compass.cells(Vector2i(854, 480), 0.0, [], 1.0)
	Compass.C["labels"] = keep
	ok((no.points as Dictionary).keys() == ["N"], "labels north_only draws N alone (%s)" % str((no.points as Dictionary).keys()))
	var nt := Compass.cells(Vector2i(854, 480), 0.0, [0.0, 50.0, 180.0], 1.0)
	var strip: Rect2i = nt.strip
	var under := true
	for x in nt.notch_x:
		var found := false
		for r: Rect2i in nt.marks:
			if r.position.y > strip.end.y - 1 and x >= r.position.x and x < r.end.x:
				found = true
		under = under and found
	ok((nt.notch_x as Array).size() == 2 and under and int(nt.notch_x[0]) == 427, "shrine notches under the strip at their bearings in view (N at the middle, 50 degrees right of it; S out of view): %s" % str(nt.notch_x))
	ok(Compass.open_exits("aztec").is_empty(), "no notches from ruin_compass.json yet: the Aztec ruin's exits lead to neighbours not built (shrine mouths are queue 100)")


func _scene(main: CrawlerMain) -> void:
	for i in 600:
		if not main._fade.visible:
			break
		await process_frame
	var cs: Array = main.find_children("*", "Compass", true, false)
	var c: Compass = main.compass
	ok(c != null and cs.size() == 1 and c.get_parent() == main.ui, "one compass, in the crawler's UI layer (%d)" % cs.size())
	if c == null:
		return
	var had: Variant = Settings.get_value("hud.compass") if Settings.has("hud.compass") else null
	Settings.set_bool("hud.compass", true)
	await _ticks(2)
	ok(c.showing(), "showing in play, the Settings switch Compass on by default")
	# Facing: the camera's heading is the strip's.
	var cam := main.player.camera()
	ok(cam != null and absf(c.heading_deg - Compass.heading_of(cam.global_basis)) < 0.01, "its heading is the camera's (%.1f degrees)" % c.heading_deg)
	Settings.set_bool("hud.compass", false)
	await _ticks(2)
	var off_switch := not c.showing()
	Settings.set_bool("hud.compass", true)
	Compass.C["on"] = false
	await _ticks(2)
	var off_data := not c.showing()
	Compass.C["on"] = true
	main.settings_panel.visible = true
	await _ticks(2)
	var off_panel := not c.showing()
	main.settings_panel.visible = false
	await _ticks(2)
	ok(off_switch and off_data and off_panel and c.showing(), "the switch off, compass.on false or a panel open: nothing drawn; back on, it shows")
	# The blackout (§FO.5 not built): your torch out, it stays.
	if main.player.torch != null and main.player.torch.lit():
		main.player.torch.put_out("compass check")
	await _ticks(2)
	ok(c.showing(), "with your torch out (phase two's blackout, §FO.5, not built yet) it still shows")
	# Under a brew: drawn above the vision, unmodulated.
	var col0 := Compass.color()
	if main.brew != null and main.brew.vision != null:
		main.brew.vision.start("ololiuhqui", (SacredVine.plant_data("ololiuhqui")).get("vision", {}))
		await _ticks(5)
		var v := main.brew.vision
		ok(v.visible and v.get_index() < c.get_index() and v.get_parent() == c.get_parent() and c.modulate == Color.WHITE and c.self_modulate == Color.WHITE and Compass.color() == col0 and c.showing(), "under a brew it is drawn above the vision (index %d over %d), untinted, #%s" % [c.get_index(), v.get_index(), col0.to_html(false)])
	else:
		ok(false, "the brew's vision is there to test under")
	# Up on the surface.
	await main.go_up()
	for i in 300:
		if main.on_surface and not main.leaving:
			break
		await process_frame
	await _ticks(3)
	ok(main.on_surface and c.showing() and c.notches == RuinTunnel.bearings(str(main.lay.get("theme", ""))) and c.notches.size() == 1 and absf(c.heading_deg - Compass.heading_of(main.player.camera().global_basis)) < 0.01, "up on the surface it shows, north still -z (facing %.0f degrees), one notch: the tunnel's shrine (queue 100) at %s" % [c.heading_deg, str(c.notches)])
	if had == null:
		Settings.erase("hud.compass")
	else:
		Settings.set_value("hud.compass", had)
