extends SceneTree
## The shrine and the sealed scroll (design 3 Oct §DK, data/shrines.json,
## Shrines), headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/shrine_check.gd
##  - the nearest shrine (behind a burning shrine or an oak door, §DJ): 6-8
##    sconces and a pattern neither all lit nor all dark; its hall, rooms,
##    sconces, altar, scroll and wall built; its delve dark below;
##  - taking the scroll writes log.taken;
##  - shown to a folk who isn't the reader: log.shown, and you keep it;
##  - the reader: log.asked_where, then the deciphered entry whole (the
##    passage and the pattern), and the item is "Opened scroll"; the log
##    panel's rows hold the whole entry;
##  - any other arrangement of the sconces leaves the wall; the pattern
##    opens it, exactly once;
##  - the sconces draw no smoke.

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
	var map: PlanetData = world.planet
	var roads: RoadNetwork = main.chunks.roads
	var camp: Vector3 = main.camp.site
	var sh: Shrines = main.shrines
	# The nearest shrine.
	var pl := {}
	var bd := INF
	for p in HiddenPlaces.near(roads, camp, 30000.0, true):
		if not str(p.kit) in Shrines.KITS:
			continue
		var dm := CubeSphere.surface_distance_m(p.dir, camp)
		if dm < bd:
			bd = dm
			pl = p
	ok(not pl.is_empty(), "a shrine within 30 km of the camp")
	if pl.is_empty():
		_done()
		return
	var lay := Shrines.layout(map, pl)
	var n := (lay.sconces as Array).size()
	var pattern: Array = lay.pattern
	print("   the shrine behind a %s at %.3f,%.3f (%.1f km): hall %.1f m, open %.1f m, %d sconces, pattern %s -> \"%s\"" % [pl.kit, rad_to_deg(CubeSphere.latitude(pl.dir)), rad_to_deg(CubeSphere.longitude(pl.dir)), bd / 1000.0, float(lay.pieces[0].len), float(lay.open_to), n, str(pattern), Shrines.pattern_words(pattern)])
	ok(n >= 6 and n <= 8 and pattern.has(true) and pattern.has(false), "6-8 sconces (%d) and a pattern neither all lit nor all dark" % n)
	# Stand on the court, in front of the way down.
	await _stand(Delves.to_dir(lay.fr, 0.0, -3.0))
	main.hidden_places.refresh(true)
	for i in 30:
		await process_frame
	var e: Dictionary = sh.built.get(str(pl.key), {})
	ok(not e.is_empty() and is_instance_valid(e.node) and (e.sconces as Array).size() == n and e.wall != null and e.scroll != null, "built: the hall and rooms, %d sconces, the wall and the scroll on the altar" % (e.sconces as Array).size() if not e.is_empty() else "built: nothing")
	if e.is_empty():
		_done()
		return
	var holes := Shrines.holes_near(map, pl.dir, 60.0)
	ok(not holes.is_empty(), "the ground opens over the way down (%d hole sets)" % holes.size())
	# Down in the altar room: the delve's dark.
	var room: Dictionary = lay.pieces[1]
	var rc2: Vector2 = (room.c as Vector2) + Vector2(0.0, 2.0)
	var off := float(e.off)
	var deep: Vector3 = (e.node as Node3D).global_transform * Vector3(rc2.x, float(room.y0) - off + 1.0, rc2.y)
	main.player.global_position = deep
	for i in 150:
		await process_frame
	ok(Delves.inside and Delves.underground > 0.5, "in the altar room: inside a delve, underground %.2f" % Delves.underground)
	# --- The scroll. ---
	var scroll: WorldItem = e.scroll
	main._take_lying(scroll, false)
	var si: int = main.player.inventory.slot_of("scroll")
	var taken := _last_text("scroll")
	ok(si >= 0 and taken == str(Shrines.LOG.get("taken", "")), "taken: in hand, and the log says \"%s\"" % taken)
	var item: Dictionary = main.player.inventory.carried[si] if si >= 0 else {}
	# --- Shown to someone who can't read it. ---
	var rc := Shrines.reader_camp(map, pl)
	print("   the reader's camp: %s, %.1f km from the shrine" % [str(rc.get("key", "none")), float(rc.get("km", 0.0))])
	ok(not rc.is_empty(), "a reader's camp 5-60 km from the shrine")
	var other := await _folk_at_other_camp(rc)
	if other == null:
		ok(false, "a folk at another camp to show it to")
	else:
		var n_shown := _count("shown")
		var how := Shrines.show_to(map, item, other)
		ok(how == "shown" and _count("shown") == n_shown + 1 and main.player.inventory.slot_of("scroll") >= 0 and bool(item.get("sealed", false)), "shown to a folk at %s: \"%s\", still sealed and yours" % [str(other.get_parent().get_meta("key", "")), _last_text("shown")])
	# --- The reader. ---
	if not rc.is_empty():
		var reader := await _reader_at(rc, pl)
		ok(reader != null, "the reader at their camp (%s)" % ("found" if reader != null else "none"))
		if reader != null:
			var n0 := GameLog.entries.size()
			var how2 := Shrines.show_to(map, item, reader)
			var new: Array = GameLog.entries.slice(n0)
			var asked := new.size() >= 1 and str(new[0].text) == str(Shrines.LOG.get("asked_where", ""))
			var text: String = str(new[1].text) if new.size() >= 2 else ""
			var passage: Array = Shrines.SCROLL.get("passage_first_guess", [])
			var whole := text.contains(str(passage[0])) and text.contains(str(passage[passage.size() - 1])) and text.contains(Shrines.pattern_words(pattern))
			ok(how2 == "read" and asked and whole and new[1].kind == "deciphered", "the reader asks where, then the whole text (%d lines; ends \"%s\")" % [text.split("\n").size(), Shrines.pattern_words(pattern)])
			ok(Inventory.title(item) == "Opened scroll" and not bool(item.get("sealed", true)), "the item is now \"%s\"" % Inventory.title(item))
			# The panel's rows: the whole entry, wrapped, nothing cut.
			var font := ThemeDB.fallback_font
			var rows := LogPanel.rows_for([new[1]], font, 20, 400.0)
			var joined := " ".join(rows.filter(func(r): return r[2] != "day").map(func(r): return str(r[1])))
			var words_ok := true
			for w in text.replace("\n", " ").split(" "):
				if not joined.contains(w):
					words_ok = false
			var widest := 0.0
			for r in rows:
				widest = maxf(widest, font.get_string_size(str(r[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
			ok(words_ok and widest <= 400.0 and rows.size() > 3, "the log panel shows it whole: %d rows, the widest %.0f of 400 px" % [rows.size(), widest])
	# --- The pattern lock. ---
	await _stand(Delves.to_dir(lay.fr, 0.0, -3.0))
	main.hidden_places.refresh(true)
	for i in 10:
		await process_frame
	e = sh.built.get(str(pl.key), {})
	var opened0 := _count_text(str(Shrines.LOG.get("opened", "")))
	# Every other arrangement of the first few: wrong ones do nothing.
	var wrong_tried := 0
	var still_shut := true
	for mask in range(0, 1 << n):
		var arr: Array = []
		for i in n:
			arr.append((mask >> i) & 1 == 1)
		if arr == pattern:
			continue
		wrong_tried += 1
		# The whole arrangement at once (one at a time it could pass
		# through the pattern on the way, which opens it, as in play).
		var st := Shrines.state(str(pl.key), n)
		st.lit = arr.duplicate()
		sh.check(str(pl.key))
		if e.wall == null or not is_instance_valid(e.wall) or bool(Shrines.state(str(pl.key), n).opened):
			still_shut = false
			break
		if wrong_tried >= 40:
			break
	ok(still_shut and _count_text(str(Shrines.LOG.get("opened", ""))) == opened0, "%d wrong arrangements: the wall stands" % wrong_tried)
	# One sconce away from the pattern, then that one by its real action.
	var near_arr := pattern.duplicate()
	var flip := pattern.find(true)
	near_arr[flip] = false
	var st2 := Shrines.state(str(pl.key), n)
	st2.lit = near_arr.duplicate()
	for i in n:
		sh._set_lit((e.sconces as Array)[i], bool(near_arr[i]))
	sh.check(str(pl.key))
	sh.light((e.sconces as Array)[flip])
	await process_frame
	var opened1 := _count_text(str(Shrines.LOG.get("opened", "")))
	# Out and back in again: no second opening.
	sh.smother((e.sconces as Array)[pattern.find(true)])
	sh.light((e.sconces as Array)[pattern.find(true)])
	var opened2 := _count_text(str(Shrines.LOG.get("opened", "")))
	ok(opened1 == opened0 + 1 and opened2 == opened1 and (e.wall == null or not is_instance_valid(e.wall)), "the pattern opens the wall, once (log.opened %d, then %d)" % [opened1 - opened0, opened2 - opened0])
	# --- No smoke from a sconce. ---
	for i in 60:
		await process_frame
	var smoky := 0
	for sn in e.sconces:
		var fl: Node3D = (sn as Node3D).get_node("Flame")
		if fl.has_meta("smoke_col"):
			smoky += 1
	ok(smoky == 0, "the sconces draw no smoke (%d of %d do)" % [smoky, n])
	_done()


func _done() -> void:
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _set_all(sh: Shrines, e: Dictionary, arr: Array) -> void:
	for i in arr.size():
		var sn: Node3D = (e.sconces as Array)[i]
		if Shrines.is_lit(sn) != bool(arr[i]):
			if bool(arr[i]):
				sh.light(sn)
			else:
				sh.smother(sn)


func _count(kind: String) -> int:
	return GameLog.entries.filter(func(x): return x.kind == kind).size()


func _count_text(t: String) -> int:
	return GameLog.entries.filter(func(x): return x.text == t).size()


func _last_text(kind: String) -> String:
	for i in range(GameLog.entries.size() - 1, -1, -1):
		if GameLog.entries[i].kind == kind:
			return str(GameLog.entries[i].text)
	return ""


## Stand at surface direction `d`, the ground loaded.
func _stand(d: Vector3) -> void:
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	main.player.global_position -= off
	main.chunks.load_blocking(d)
	main.player.spawn_at(d)
	for i in 20:
		await process_frame


## A folk at the opening camp's road camp or any built camp that isn't
## the reader's.
func _folk_at_other_camp(rc: Dictionary) -> Node3D:
	var map: PlanetData = world.planet
	var best := {}
	var bd := INF
	for c in CreatureSpawner._cells_around(main.camp.site, 40000.0, Ruins.CELL_M):
		var s := Ruins.find(map, c)
		if s.is_empty() or not Ruins.inhabited(s) or Overrun.is_overrun(s) or "ruin:%s" % str(c) == str(rc.get("key", "")):
			continue
		var dm := CubeSphere.surface_distance_m(s.dir, main.camp.site)
		if dm < bd:
			bd = dm
			best = s
	if best.is_empty():
		return null
	return await _sitter_at(best, "")


func _reader_at(rc: Dictionary, pl: Dictionary) -> Node3D:
	var cn_folk := await _sitter_at(rc.site, str(rc.key))
	if cn_folk == null:
		return null
	var cn := cn_folk.get_parent() as Node3D
	for s in cn.get_meta("sitters", []):
		if Shrines.is_reader(world.planet, pl, s):
			return s
	return null


## Go to ruin `site`, build it and its camp; a sitter there (of camp `key`
## when given).
func _sitter_at(site: Dictionary, key: String) -> Node3D:
	var d := CreatureSpawner._offset(site.dir, 0.3, float(site.footprint_m) * 0.5 + 8.0)
	await _stand(d)
	main.landmarks.build_ruin_at(site.dir)
	for i in 10:
		await process_frame
	main.camps.refresh_now()
	for i in 10:
		await process_frame
	for k in main.camps._camps:
		if key != "" and str(k) != key:
			continue
		if not str(k).begins_with("ruin:"):
			continue
		var cn: Node3D = main.camps._camps[k]
		var ss: Array = cn.get_meta("sitters", [])
		if not ss.is_empty():
			return ss[0]
	return null
