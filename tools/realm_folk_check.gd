extends SceneTree
## The bard and the oracle, the camp's band, the library and the I Ching
## (design §GO.10-11, queue 125; RealmFolk, OracleLibrary, HubWork's band;
## data/realm_folk.json, data/library.json), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/realm_folk_check.gd
## Asserts:
##  1. in the desert a bard sits by the ruin playing; heard at bard.hear_m,
##     louder closer, silent past it;
##  2. the bard teaches the clay ocarina (saved; kept through save-and-quit);
##     its red clay beside them goes home in your pack;
##  3. the oracle: no sound, no light; over 50 layouts never within the
##     bard's hearing, away from the hearth and off the path (doors home
##     are not built yet, §GK.5); interact: a brief vision, then the I Ching
##     in your library; the vision gone after oracle.vision_s;
##  4. at the hub: the clay set down in the store, the maker builds the
##     ocarina, and at the evening meal its player plays it (one player,
##     none before it was built, none by day);
##  5. the library opens at the hub (the I Ching's pages); on a log the
##     cast: six tosses, a hexagram and its changed hexagram; nothing in
##     the world changes;
##  6. the three-coin odds over 10 000 casts (60 000 lines) within 1 %;
##     the King Wen table whole; learning kept through death.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(main: CrawlerMain) -> void:
	var w := 0
	await _frames(3)
	while main.leaving and w < 3000:
		await process_frame
		w += 1
	await _frames(8)


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	OS.set_environment("SEED", "7")
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	var w := 0
	while (not main.on_surface or main.leaving) and w < 3000:
		await process_frame
		w += 1
	await _frames(5)
	main.player.set_physics_process(false)
	var hub := main.surface as HubCamp
	var rf := main.realm_folk
	var lib := main.library
	SongWeb.learn("cactus")
	main.areas.to_area("first")
	await _settle(main)
	rf.tick(0.1)
	var area := main.surface
	ok(area == main.area_node and rf.bard != null and rf.oracle != null and rf.clay != null, "in the desert: a bard, the red clay beside them, an oracle")
	var B: Dictionary = RealmFolk.D.get("bard", {})
	var O: Dictionary = RealmFolk.D.get("oracle", {})
	var hear := float(B.get("hear_m", 120.0))
	var mouth: Vector2 = area.stair.get("mouth", area.land.center)
	var bp := rf.bard.global_position
	ok(Vector2(bp.x, bp.z).distance_to(mouth) <= float((B.get("from_mouth_m", [12, 22]) as Array)[1]) + 0.5, "the bard sits by the ruin's mouth (%.0f m)" % Vector2(bp.x, bp.z).distance_to(mouth))

	# 1. Heard far off, louder closer.
	var dirv := Vector3(1, 0, 0)
	var vols: Array = []
	for d in [4.0, 20.0, 60.0, hear - 3.0, hear + 15.0]:
		var q: Vector3 = bp + dirv * d
		main.player.global_position = Vector3(q.x, area.land.height_at(q.x, q.z), q.z)
		rf.tick(0.05)
		vols.append([d, snappedf(rf._audio.volume_db, 0.1), rf.bard_heard()])
	var louder := float(vols[0][1]) > float(vols[1][1]) and float(vols[1][1]) > float(vols[2][1]) and float(vols[2][1]) > float(vols[3][1])
	ok(rf._audio.playing and bool(vols[3][2]) and not bool(vols[4][2]) and louder, "the bard's tune heard %.0f m off and louder closer, silent past it (%s)" % [hear, str(vols)])

	# 2. Taught, and the clay.
	main.player.global_position = bp + Vector3(1.2, 0, 0)
	ok(main.areas.interact() and RealmFolk.learned().has("clay_ocarina"), "the bard teaches you the clay ocarina")
	CrawlerSave.save()
	var kept := CrawlerSave.kept(CrawlerSave.game_seed)
	ok(((kept.get("band", {}) as Dictionary).get("learned", []) as Array).has("clay_ocarina"), "learning kept through save-and-quit")
	main.player.global_position = rf.clay.global_position + Vector3(0.5, 0, 0)
	var inv := main.player.inventory
	ok(main.areas.interact() and inv.carried.any(func(x): return x is Dictionary and str(x.get("what", "")) == "red_clay"), "a lump of red clay in your pack")

	# 3. The oracle.
	var cues := rf.oracle.find_children("*", "AudioStreamPlayer3D", true, false).size() + rf.oracle.find_children("*", "Light3D", true, false).size() + rf.oracle.find_children("*", "AudioStreamPlayer", true, false).size()
	ok(cues == 0, "the oracle makes no sound and gives no light")
	var hp := area.area_hearth.global_position
	var bad: Array = []
	for i in 50:
		var pl := RealmFolk.place(area, hash([area.seed_value, i]))
		var o: Vector3 = pl.oracle
		var b: Vector3 = pl.bard
		var db := Vector2(o.x - b.x, o.z - b.z).length()
		var dh := Vector2(o.x - hp.x, o.z - hp.z).length()
		var dp := RealmFolk._off_segment(Vector2(o.x, o.z), Vector2(hp.x, hp.z), mouth)
		if db <= hear or dh < float(O.get("from_hearth_m", 70.0)) or dp < float(O.get("off_path_m", 40.0)):
			bad.append("%d: bard %.0f hearth %.0f path %.0f" % [i, db, dh, dp])
	var op := rf.oracle.global_position
	ok(bad.is_empty() and Vector2(op.x - bp.x, op.z - bp.z).length() > hear, "over 50 layouts the oracle is never within the bard's hearing, the hearth's %.0f m or the path's %.0f m (this one %.0f m from the bard; bad %s; doors not built yet)" % [float(O.get("from_hearth_m", 70.0)), float(O.get("off_path_m", 40.0)), Vector2(op.x - bp.x, op.z - bp.z).length(), str(bad.slice(0, 3))])
	main.player.global_position = op + Vector3(1.0, 0, 0)
	ok(main.areas.interact() and OracleLibrary.has("i_ching"), "the oracle: the I Ching in your library")
	rf.tick(1.5)
	var shown := rf.vision_shown()
	var t := 0.0
	while t < float(O.get("vision_s", 6.0)) + 0.5:
		rf.tick(0.25)
		t += 0.25
	ok(shown > 0.9 and rf.vision_shown() == 0.0 and not rf._vision.visible, "a brief vision (%.2f shown at 1.5 s), gone after %.0f s" % [shown, float(O.get("vision_s", 6.0))])
	main.player.global_position = op + Vector3(1.0, 0, 0)
	main.areas.interact()
	ok(OracleLibrary.held() == ["i_ching"] and str(GameLog.entries[-1].text).contains("silence"), "asked again, the oracle sits in silence (one text)")

	# 4. Home: the clay in the store, the ocarina made, played at the meal.
	main.player.global_position = area.area_hearth.global_position + Vector3(1.5, 0, 0)
	main.areas.interact()
	await _settle(main)
	hub = main.surface as HubCamp
	ok(hub != null, "home by the hearth")
	var wv := hub.work_view
	main.player.global_position = hub.store_node.global_position + Vector3(0.6, 0, 0)
	ok(main.areas.interact() and wv.sim.count("red_clay") >= 1.0, "the red clay set down in the camp store")
	var per_day := float(main.world.get("day_length_s"))
	var played_before := false
	var made_at := -1.0
	var heard_evening := false
	var by_day := false
	for i in 2400:
		main.world.days = float(main.world.get("days")) + 6.0 / per_day
		hub.day_shift.tick(6.0)
		wv.step()
		wv.tick(0.05)
		var playing := wv.band_playing()
		if made_at < 0.0 and wv.sim.band_made.has("clay_ocarina"):
			made_at = wv.sim.t
		if made_at < 0.0 and not playing.is_empty():
			played_before = true
		if str(wv.sim.phase().part) == "day" and not playing.is_empty():
			by_day = true
		if made_at >= 0.0 and playing == ["clay_ocarina"]:
			heard_evening = true
		if heard_evening and str(wv.sim.phase().part) == "day":
			break
	ok(made_at >= 0.0 and wv.sim.count("red_clay") < 1.0 and wv.sim.log.any(func(e): return str(e.act) == "make_clay_ocarina" and str(e.k) == "knapper_potter"), "the knapper-potter builds the clay ocarina from it")
	ok(heard_evening and not played_before and not by_day and str(wv.sim.band_made.get("clay_ocarina", "")) == "fisher_weaver", "at the evening meal the fisher-weaver plays it: one more player, none before it was built, none by day")

	# 5. The library and the cast.
	ok(lib.open_key() and lib.mode == "read" and lib._label.text.contains("1  Qián"), "at the hub the read-tome key opens your library: the I Ching's pages")
	lib.close()
	var bi := 0
	for i in hub.benches.size():
		bi = i
	main.fire_pipe.sit(bi)
	ok(lib.open_key() and lib.mode == "cast", "on a log holding the I Ching: three coins set out")
	var before := JSON.stringify([inv.carried, CrawlerSave.data.get("band", {}), CrawlerSave.data.get("library", []), CrawlerSave.data.get("bank", {}), wv.sim.store])
	for i in 6:
		main.areas.interact()
	var r := OracleLibrary.read_cast(lib.lines)
	var to_ok := (int(r.to) == 0) == (r.changing as Array).is_empty()
	ok(lib.lines.size() == 6 and int(r.n) >= 1 and int(r.n) <= 64 and to_ok and lib._label.text.contains("%d  %s" % [int(r.n), OracleLibrary.hexagram(int(r.n)).name]), "six tosses: hexagram %d %s, changing %s, to %d" % [int(r.n), OracleLibrary.hexagram(int(r.n)).get("name", ""), str(r.changing), int(r.to)])
	var after := JSON.stringify([inv.carried, CrawlerSave.data.get("band", {}), CrawlerSave.data.get("library", []), CrawlerSave.data.get("bank", {}), wv.sim.store])
	ok(before == after and main.fire_pipe.state == "", "reflection only: nothing in the world changed (the pipe not lit by the tosses)")
	lib.close()
	main.fire_pipe.stand(false)

	# 6. The odds, the table, death.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var counts := {6: 0, 7: 0, 8: 0, 9: 0}
	for c in 10000:
		for l in 6:
			var v := int(OracleLibrary.toss(rng)[1])
			counts[v] = int(counts[v]) + 1
	var want := {6: 0.125, 7: 0.375, 8: 0.375, 9: 0.125}
	var odds_ok := true
	var got := {}
	for v in counts:
		got[v] = snappedf(float(counts[v]) / 60000.0, 0.0001)
		odds_ok = odds_ok and absf(float(got[v]) - float(want[v])) <= 0.01
	ok(odds_ok, "over 10 000 casts the lines' odds match the three-coin method within 1 %% (%s)" % str(got))
	var seen := {}
	for row in (OracleLibrary.iching().king_wen as Array):
		for n in row:
			seen[int(n)] = true
	var r9 := OracleLibrary.read_cast([9, 9, 9, 9, 9, 9])
	var r_tai := OracleLibrary.read_cast([7, 7, 7, 8, 8, 8])
	ok(seen.size() == 64 and int(r9.n) == 1 and int(r9.to) == 2 and int(r_tai.n) == 11 and int(r_tai.to) == 0, "the King Wen table whole: all old yang is 1 changing to 2; heaven under earth is 11")
	main.areas.die()
	await _settle(main)
	await _frames(30)
	ok(RealmFolk.learned().has("clay_ocarina") and OracleLibrary.has("i_ching"), "learning and the library kept through death")
	print("realm_folk_check: %d fails" % fails)
	quit(1 if fails > 0 else 0)
