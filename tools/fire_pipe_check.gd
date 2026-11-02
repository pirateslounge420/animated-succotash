extends SceneTree
## Sitting by the fire: the pipe, the ember, smoking herbs (design §GO.7,
## queue 124; FirePipe, data/herbs.json), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/fire_pipe_check.gd
## Asserts:
##  1. by a log bench at the hub fire the button sits you on it (no song);
##     with no herb carried it packs nothing (no pipe, no effect);
##  2. each herb: carried, the button packs the pipe, the ember comes, a
##     first puff, then it smoulders in its smoke colour; its effect rises
##     over onset_s, holds, falls over fade_s to nothing; at its peak only
##     its own effects show (tint, filter, time); after it, nothing left;
##  3. standing up mid-smoke fades it out to nothing within stand_fade_s;
##  4. nothing else changes: what you carry, the songs you know, the bank,
##     time's pace and the sound buses as they were;
##  5. the desert grows damiana on its floor; a pinch, the plant stays.

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


func _run() -> void:
	WorldSave.read_only = true
	OS.set_environment("SEED", "7")
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	var w := 0
	while (not main.on_surface or main.leaving) and w < 3000:
		await process_frame
		w += 1
	await _frames(5)
	var hub := main.surface as HubCamp
	var pipe := main.fire_pipe
	pipe.set_process(false)
	main.player.set_physics_process(false)
	ok(hub != null and pipe != null and hub.benches.size() == 4, "the hub, its four log benches, the pipe")
	var inv := main.player.inventory
	var before_inv := JSON.stringify(inv.carried)
	var before_songs := JSON.stringify(CrawlerAreas.known())
	var before_bank := JSON.stringify(CrawlerSave.data.get("bank", {}))
	var amb := AudioServer.get_bus_index(AudioMix.bus("ambience"))
	var fx0 := AudioServer.get_bus_effect_count(amb)

	# 1. Sit on a log; no herb, no pipe.
	var b: Vector3 = hub.benches[0].at
	# Behind the log, out of the fire's and the shaman's reach.
	var bi := 0
	var stand_at := Vector3.ZERO
	for i in hub.benches.size():
		var bb: Vector3 = hub.benches[i].at
		var out := Vector2(bb.x - hub.camp.pos.x, bb.z - hub.camp.pos.z).normalized()
		var q := Vector2(bb.x, bb.z) + out * 0.6
		var cand := Vector3(q.x, hub.land.height_at(q.x, q.y), q.y)
		if cand.distance_to(hub.shaman.global_position) > 3.1:
			bi = i
			stand_at = cand
			break
	b = hub.benches[bi].at
	main.player.global_position = stand_at
	ok(main.areas.interact() and pipe.seated and not main.areas.sitting and not main.areas.song_playing(), "by a bench the button sits you on the log, no song")
	ok(main.areas.interact() and pipe.state == "" and pipe.level == 0.0 and str(GameLog.entries[-1].text).contains("nothing to smoke"), "no herb carried: no pipe packed, nothing changes")

	# 2. Each herb, lit and burnt out.
	var P: Dictionary = FirePipe.seat_data().get("pose", {})
	var light_s := float(P.get("pack_s", 1.6)) + float(P.get("ember_s", 2.2)) + float(P.get("puff_s", 1.4))
	for id in FirePipe.herbs():
		var h := FirePipe.herb_data(id)
		inv.add(FirePipe.pinch(id))
		while pipe.herb != id:
			pipe.pick(1)
		main.areas.interact()
		var seen: Array = [pipe.state]
		var t := 0.0
		while t < light_s + 0.2:
			pipe.tick(0.05)
			t += 0.05
			if seen[-1] != pipe.state:
				seen.append(pipe.state)
		var smoke_col := (pipe._smoke.color_ramp as Gradient).get_color(0)
		var want := Color(str(h.smoke))
		ok(seen == ["pack", "ember", "puff", "smoke"] and Vector3(smoke_col.r, smoke_col.g, smoke_col.b).distance_to(Vector3(want.r, want.g, want.b)) < 0.01, "%s: packed, the ember from the hearth, a puff, then its %s smoke (%s)" % [id, str(h.smoke), str(seen)])
		var on := float(h.onset_s)
		var pk := float(h.peak_s)
		var fd := float(h.fade_s)
		var rising := true
		var last := -1.0
		var peak := 0.0
		var at_peak := {}
		var falling := true
		var s := pipe.lit_t
		while s < on + pk + fd + 1.0:
			pipe.tick(0.1)
			s = pipe.lit_t
			if pipe.state != "smoke":
				break
			if s < on - 0.1:
				rising = rising and pipe.level > last
			elif s > on + 0.2 and s < on + pk - 0.2:
				peak = maxf(peak, pipe.level)
				if at_peak.is_empty():
					at_peak = pipe.effect()
					at_peak["tint_shown"] = pipe._tint != null and pipe._tint.visible
					at_peak["filter"] = AudioServer.get_bus_effect_count(amb) > fx0
					at_peak["ts"] = Engine.time_scale
			elif s > on + pk + 0.2 and s < on + pk + fd - 0.3:
				falling = falling and pipe.level < last
			last = pipe.level
		var E: Dictionary = h.effects
		var fx_ok := (bool(at_peak.tint_shown) == E.has("sky_tint")) and (bool(at_peak.filter) == E.has("music_filter")) and ((float(at_peak.ts) < 0.999) == E.has("time_slow"))
		ok(rising and absf(peak - 1.0) < 1e-4 and falling, "%s: rises over %.0f s, holds at its peak, falls over %.0f s" % [id, on, fd])
		ok(fx_ok, "%s: at its peak only its own effects (%s; tint %s, filter %s, time %.2f)" % [id, ", ".join(E.keys()), at_peak.tint_shown, at_peak.filter, float(at_peak.ts)])
		ok(pipe.state == "out" and pipe.clear(), "%s: burnt out, nothing left of it (time %.2f)" % [id, Engine.time_scale])

	# 3. Standing up mid-smoke.
	var id2: String = FirePipe.herbs().keys()[0]
	while pipe.herb != id2:
		pipe.pick(1)
	main.areas.interact()
	var t2 := 0.0
	while t2 < light_s + float(FirePipe.herb_data(id2).onset_s) + 2.0:
		pipe.tick(0.1)
		t2 += 0.1
	var mid := pipe.level
	pipe.stand()
	var fade := float(FirePipe.seat_data().get("stand_fade_s", 2.0))
	var t3 := 0.0
	var dropping := true
	var lastl := mid
	while t3 < fade + 0.3:
		pipe.tick(0.1)
		t3 += 0.1
		dropping = dropping and pipe.level <= lastl
		lastl = pipe.level
	ok(mid > 0.9 and dropping and pipe.clear() and not pipe.seated and main.player.is_physics_processing(), "standing mid-smoke: it fades out within %.1f s to nothing, you free to walk (from %.2f)" % [fade, mid])

	# 4. Nothing else changes.
	var now_inv: Array = inv.carried.filter(func(x): return not (x is Dictionary and str(x.get("kind", "")) == "smoking_herb"))
	var was: Array = JSON.parse_string(before_inv)
	ok(JSON.stringify(now_inv.filter(func(x): return x != null)) == JSON.stringify(was.filter(func(x): return x != null)) and inv.carried.filter(func(x): return x is Dictionary and str(x.get("kind", "")) == "smoking_herb").size() == FirePipe.herbs().size(), "what you carry is as it was, the herbs not used up")
	ok(JSON.stringify(CrawlerAreas.known()) == before_songs and JSON.stringify(CrawlerSave.data.get("bank", {})) == before_bank and is_equal_approx(Engine.time_scale, 1.0) and AudioServer.get_bus_effect_count(amb) == fx0, "the songs, the bank, time's pace and the sound as they were")

	# 5. Damiana in the desert.
	SongWeb.learn("cactus")
	main.areas.to_area("first")
	w = 0
	await _frames(5)
	while (main.leaving or main.surface == hub) and w < 3000:
		await process_frame
		w += 1
	await _frames(10)
	pipe.tick(0.1)
	var pl := pipe.plants()
	ok(pl.size() == int((FirePipe.D.get("plants", {}) as Dictionary).get("per_realm", 3)) and pl.all(func(p): return str(p.herb) == "damiana"), "the desert grows damiana on its floor (%d plants)" % pl.size())
	if not pl.is_empty():
		for i in inv.carried.size():
			if inv.carried[i] is Dictionary and str(inv.carried[i].get("herb", "")) == "damiana":
				inv.take(i)
		var plant: Node3D = pl[0].node
		main.player.global_position = plant.global_position + Vector3(0.8, 0.0, 0.0)
		ok(main.areas.interact() and pipe.carried().has("damiana") and is_instance_valid(plant) and plant.is_inside_tree(), "a pinch of damiana, the plant still growing")
	print("fire_pipe_check: %d fails" % fails)
	quit(1 if fails > 0 else 0)
