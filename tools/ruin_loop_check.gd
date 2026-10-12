extends SceneTree
## The ruin's loop (design 10 Oct §FO; data/ruin_loop.json), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/ruin_loop_check.gd
## LOOP_SEEDS (env) sets how many layouts beyond 1, 7 and 42 are laid
## (default 97: a hundred in all, drawn from a fixed seed).
## Asserts (queue 85, §FO.2 and §FO.3's exit):
##  1. the layouts (a hundred seeds): one floor, no stair down (no
##     lay.descent, no stair piece below floor one), no floor-two fog
##     anywhere (FloorFog.share_at 0 at every piece);
##  2. the scene (SEED, exit.sealed_until_home set true; shipped false since 12 Oct): the way
##     out's flight sealed at its foot, its doorway blocked, the floor grid
##     finding no way from the wake spot to the way out; every torch but one
##     lit: still sealed; the last: the boss released, and once it is down
##     its lair the seal grinds (stone_seal, heard as far as it is now) and
##     is gone, the floor grid running from the wake spot to the way out;
##     kept in the save (exit_open);
##  3. Continue: the same ruin, its way up open at once and quiet;
##  4. exit.sealed_until_home false (as shipped): no seal, the way out open from the start.
## And (queue 86, §FO.4, SecretWing):
##  5. the layouts (the same hundred): exactly one secret wing, its pieces
##     joined to the floor by one door only, that door not the way out's nor
##     a spine door, opening off a room on a route (the spine, the heart or a
##     side way), seen from that room's middle line past its pillars; no
##     holder, airway or resident in the wing; the same seed the same plan;
##     the floor's holders (its lit test) the same as with no wing;
##  6. in the scene: the wing sealed before the boss is home (its doorway
##     blocked, the floor grid finding no way to the scroll), open after
##     (the grinding, the floor grid reaching the scroll); the scroll taken
##     once (a second try takes nothing), kept in the save and the game's
##     collection; Continue: the seal gone quiet and no scroll lying there.
## And (queue 87, §FO.5, §FO.6, Blackout):
##  7. taking the scroll: every flame out (no holder, no hearth, no torch in
##     hand, the lit-holder count zero, no flame anywhere), and nothing can
##     be lit (the swing at a sconce and at the hearth, a torch at the cold
##     hearth, a fire pot's wick); the boss comes up out of its lair after
##     phase_two.boss.emerge_after_s, its hunt its own times speed_mult and
##     still under your sprint, every room its ground (none closed to it, the
##     hearth's too); the way up open and reached on foot from the hearth with
##     no flame; three hits and Good night, and you wake by the cold hearth in
##     the dark; kept in the save, so Continue loads the dark with the boss
##     angry.

var fails := 0
const DT := 1.0 / 60.0
const MORE_SEEDS := 97


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
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	_layouts(_seeds())
	_wings(_seeds())
	OS.set_environment("SEED", str(seed_v))
	# As shipped since 12 Oct (Mike: "the door open can be open even before
	# lighting up all options"): sealed_until_home false, the way out open
	# from the start (4). The sealed path (2, 3) stays built and is checked
	# with the flag set true here.
	ok(not Fork.gate_surface(), "as shipped (12 Oct, Mike): ruin_loop.json exit.sealed_until_home false, the way out open from the start")
	var was: Variant = Fork.EXIT.get("sealed_until_home", false)
	Fork.EXIT["sealed_until_home"] = true
	await _exit_scene()
	await _exit_kept()
	Fork.EXIT["sealed_until_home"] = was
	OS.set_environment("SEED", str(seed_v))
	await _exit_unsealed()
	OS.set_environment("SEED", str(seed_v))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _seeds() -> Array:
	var n := MORE_SEEDS
	if OS.get_environment("LOOP_SEEDS").is_valid_int():
		n = maxi(int(OS.get_environment("LOOP_SEEDS")), 0)
	var out: Array = [1, 7, 42]
	var rng := RandomNumberGenerator.new()
	rng.seed = 85
	while out.size() < 3 + n:
		var s := rng.randi_range(1, 999999)
		if not out.has(s):
			out.append(s)
	return out


# --- 1. One floor ----------------------------------------------------------------

func _layouts(seeds: Array) -> void:
	var t0 := Time.get_ticks_msec()
	var one := 0
	var bad: Array = []
	for s in seeds:
		var lay := TombKit.layout(int(s))
		var good := (lay.get("floors", []) as Array).size() == 1 and not lay.has("descent") and TombFloors.count() == 1
		for pc in lay.pieces:
			if int((pc as Dictionary).get("floor", 0)) != 0:
				good = false
			var c: Vector2 = pc.c
			if FloorFog.share_at(lay, Vector3(c.x, float(pc.y0) + 1.4, c.y), 1.0) != 0.0:
				good = false
		if good:
			one += 1
		else:
			bad.append(s)
	ok(one == seeds.size(), "%d seeds: every dungeon one floor (ruin_loop.json floors.count %d), no stair down, no floor-two fog anywhere%s" % [seeds.size(), int(TombFloors.LOOP_FLOORS.get("count", 0)), "" if bad.is_empty() else " (not: %s)" % str(bad)])
	print("   (layouts in %d ms)" % (Time.get_ticks_msec() - t0))


# --- 5. The secret wing, laid out --------------------------------------------------

func _wings(seeds: Array) -> void:
	var t0 := Time.get_ticks_msec()
	var one := 0
	var joined := 0
	var not_out := 0
	var seen := 0
	var empty := 0
	var same := 0
	var lit_same := 0
	var rooms := {}
	var hosts := {}
	var off_mid := 0
	var bad: Array = []
	for s in seeds:
		var lay := TombKit.layout(int(s))
		var sec: Dictionary = lay.get("secret", {})
		if sec.is_empty():
			bad.append(s)
			continue
		one += 1
		var wing := {}
		for id in sec.pieces:
			wing[int(id)] = true
		var nr := 0
		for id in sec.pieces:
			if str(lay.pieces[int(id)].kind) == "room":
				nr += 1
		rooms[nr] = int(rooms.get(nr, 0)) + 1
		# Joined by one door.
		var links: Array = []
		for d in lay.doors:
			var a := wing.has(int(d.a))
			var b := int(d.b) >= 0 and wing.has(int(d.b))
			if a != b:
				links.append(int(d.id))
		if links.size() == 1 and int(links[0]) == int(sec.door):
			joined += 1
		var dd: Dictionary = lay.doors[int(sec.door)]
		var host: Dictionary = lay.pieces[int(sec.host)]
		var on_out := bool(dd.get("spine", false)) or dd.has("exit") or bool(host.get("exit", false))
		for ex in lay.exits:
			if int(ex.door) == int(dd.id) or int(ex.stair) == int(dd.b):
				on_out = true
		if not on_out:
			not_out += 1
		var key := "spine" if bool(host.get("spine", false)) and str(host.get("room_kind", "")) != "heart" else ("heart" if str(host.get("room_kind", "")) == "heart" else "side way")
		hosts[key] = int(hosts.get(key, 0)) + 1
		if _seen_from_route(lay, host, dd):
			seen += 1
		if absf(float(TombKit.door_side(host, dd)[1])) > 0.01:
			off_mid += 1
		var nothing := true
		for h in lay.holders:
			if wing.has(int(h.piece)):
				nothing = false
		for a in lay.airways:
			if wing.has(int(a.piece)):
				nothing = false
		for r in lay.get("residents", []):
			if wing.has(TombKit.piece_at(lay, r.pos)):
				nothing = false
		if nothing:
			empty += 1
		if str(TombKit.layout(int(s)).get("secret", {})) == str(sec):
			same += 1
		SecretWing.S["on"] = false
		var bare := TombKit.layout(int(s))
		SecretWing.S["on"] = true
		if str(bare.holders) == str(lay.holders) and not bare.has("secret"):
			lit_same += 1
	var n := seeds.size()
	ok(one == n, "%d seeds: every ruin has exactly one secret wing (%s rooms in it: %s)%s" % [n, "1 or 2", str(rooms), "" if bad.is_empty() else " (none: %s)" % str(bad)])
	ok(joined == one, "joined to the floor by one opening only (%d of %d)" % [joined, one])
	ok(not_out == one, "never on the way out (§EX.5): not the way out's door, not a spine door (%d of %d)" % [not_out, one])
	ok(seen == one, "the opening opens off a room on a route (%s) and is seen from that room's middle line past its pillars (%d of %d; %d a module or two off its wall's middle, where no centred one fits)" % [str(hosts), seen, one, off_mid])
	ok(empty == one, "no sconce, airway or resident in the wing: you carry your torch in (%d of %d)" % [empty, one])
	ok(same == one, "the same seed gives the same plan (%d of %d)" % [same, one])
	ok(lit_same == one, "the floor's holders, and so its lit test (§FF.2), the same as with no wing (%d of %d)" % [lit_same, one])
	print("   (wings in %d ms)" % (Time.get_ticks_msec() - t0))


## Is the opening `dd` in room `host`'s side wall seen from the room's
## middle line (the route through it), at some point along it, past its
## pillars' bases?
func _seen_from_route(lay: Dictionary, host: Dictionary, dd: Dictionary) -> bool:
	var pillars := TombKit._pillars_aa(lay, host)
	var target := Delves.along_across(host, dd.p)
	target.y = signf(target.y) * (absf(target.y) - 0.35)
	var along := 0.6
	while along < float(host.len) - 0.5:
		var from := Vector2(along, 0.0)
		var clear := true
		for r: Rect2 in pillars:
			if _seg_hits(from, target, r):
				clear = false
				break
		if clear:
			return true
		along += 0.5
	return false


func _seg_hits(a: Vector2, b: Vector2, r: Rect2) -> bool:
	for i in 41:
		if r.has_point(a.lerp(b, float(i) / 40.0)):
			return true
	return false


# --- 2. The way up, sealed until the boss is home --------------------------------

func _open_scene() -> CrawlerMain:
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked:
		await process_frame
	await _frames(3)
	main.player._invulnerable = 1.0e9
	return main


func _close(main: CrawlerMain) -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _exit_scene() -> void:
	print("== the scene, exit.sealed_until_home %s" % str(Fork.gate_surface()))
	var main := await _open_scene()
	var lay := main.lay
	var fork := main.fork
	var sd := Fork.surface_door(lay)
	ok(Fork.gate_surface() and fork != null and fork.surface != null and fork.down == null and sd >= 0, "with exit.sealed_until_home set true the way up is sealed until home, and no seal on a way down (one floor)")
	if fork == null or fork.surface == null:
		await _close(main)
		return
	var sdd: Dictionary = lay.doors[sd]
	var wk: Vector3 = (lay.wake as Array)[0]
	var ex: Dictionary = lay.exits[0]
	var exp_: Vector3 = ex.p
	ok(_blocked(main, sdd) and main.residents.nav.door_shut(sdd) and not _reaches(main, wk, exp_), "every torch cold: the way out's flight sealed at its foot (its doorway blocked, shut on the floor grid, no way from the wake spot to the way out)")
	var sec: Dictionary = lay.get("secret", {})
	var art: Vector3 = sec.get("artifact", Vector3.ZERO)
	var wd: Dictionary = lay.doors[int(sec.get("door", 0))]
	ok(fork.secret != null and _blocked(main, wd) and main.residents.nav.door_shut(wd) and not _reaches(main, wk, art) and main.secret_wing.scroll != null,
		"the secret opening sealed from the start (a stone seal across it, shut on the floor grid, no way from the wake spot to the scroll lying at the wing's end)")
	var hs := TombFloors.holders_on(lay, 0)
	var last := int(hs[-1])
	for i in hs:
		if int(i) != last:
			_light(main, main.fires.holders[int(i)])
	await _frames(4)
	ok(not fork.exit_opened and _blocked(main, sdd) and not main.boss.released, "every torch but one lit (%d of %d): still sealed, the boss still out" % [hs.size() - 1, hs.size()])
	_light(main, main.fires.holders[last])
	await _frames(3)
	ok(main.boss.released and not fork.exit_opened, "the last light: the boss released, fleeing home; the way up not open until it is down")
	var t := 0.0
	while not fork.exit_opened and t < 90.0:
		await physics_frame
		t += DT
	ok(fork.exit_opened and main.boss.state in ["lair", "gone"] and fork.surface.sounded == 1 and fork.surface.voice.playing, "the boss gone down its lair (%.1f s after the last light): the seal grinds open (stone_seal, heard %.0f m)" % [t, fork.surface.voice.max_distance])
	var tg := 0.0
	while not fork.surface.is_gone and tg < 10.0:
		await physics_frame
		tg += DT
	await _frames(3)
	ok(fork.surface.is_gone and not _blocked(main, sdd) and not main.residents.nav.door_shut(sdd) and _reaches(main, wk, exp_), "gone in %.1f s: the doorway clear and the floor grid runs from the wake spot to the way out" % tg)
	ok(bool(CrawlerSave.kept_value(CrawlerSave.place, "exit_open", false)), "kept in the game's save (exit_open: first time only, and kept)")
	if fork.secret != null:
		ok(fork.secret.opened and fork.secret.sounded == 1, "the boss home: the secret opening grinds open too (stone_seal)")
		var ts := 0.0
		while not fork.secret.is_gone and ts < 10.0:
			await physics_frame
			ts += DT
		await _frames(3)
		ok(fork.secret.is_gone and not _blocked(main, wd) and _reaches(main, wk, art), "gone: the floor grid runs from the wake spot through the opening to the scroll, the same floor, the same scene (no loading screen)")
		var p := main.player
		var ed: Vector2 = main.lay.pieces[int(sec.end)].dir
		p.spawn_flat(art - Vector3(ed.x, 0.0, ed.y) * 1.0, 0.0, 0.0)
		await _frames(3)
		var log0 := GameLog.entries.size()
		var first := main.secret_wing.take()
		var second := main.secret_wing.take()
		ok(first and not second and main.secret_wing.taken_count == 1 and main.secret_wing.scroll == null and _count(str(SecretWing.S.get("log_line", "")), log0) == 1,
			"the scroll taken with the usual interact, once (a second try takes nothing), the log's plain line once")
		ok(bool(CrawlerSave.kept_value(CrawlerSave.place, "secret_taken", false)) and SecretWing.collected().has(str(CrawlerSave.place)) and bool(CrawlerSave.kept_value(CrawlerSave.place, "secret_open", false)),
			"kept in the save (secret_open, secret_taken) and in the game's collection (ruin_scrolls)")
		await _phase_two(main, fork.surface.door)
	await _close(main)


func _exit_kept() -> void:
	OS.set_environment("SEED", "")
	var main := await _open_scene()
	var fork := main.fork
	var sd := Fork.surface_door(main.lay)
	ok(fork != null and fork.secret != null and fork.secret.is_gone and fork.secret.sounded == 0 and main.secret_wing.scroll == null and main.secret_wing.taken,
		"Continue: the secret opening open, quiet, and no scroll lying there (taken for good)")
	ok(main.blackout != null and main.blackout.active and FireStore.blackout and main.fires.lit_count() == 0 and not FireStore.is_lit(main.fires.hearth) and main.boss.angry,
		"Continue mid-blackout (phase_two.save %s): the dark loaded, no holder or hearth lit, nothing lights (%d relit kept in the save as they were), the boss angry" % [str(Blackout.kept()), (CrawlerSave.dungeon(CrawlerSave.place).get("relit", []) as Array).size()])
	ok(CrawlerSave.continued and fork != null and fork.exit_opened and fork.exit_open() and fork.surface.sounded == 0 and not _blocked(main, main.lay.doors[sd]), "Continue: the same ruin, its way up open at once and quiet (no grinding)")
	await _close(main)


func _exit_unsealed() -> void:
	var was: Variant = Fork.EXIT.get("sealed_until_home", true)
	Fork.EXIT["sealed_until_home"] = false
	var main := await _open_scene()
	var sd := Fork.surface_door(main.lay)
	var wk: Vector3 = (main.lay.wake as Array)[0]
	ok(main.fork.surface == null and not _blocked(main, main.lay.doors[sd]) and _reaches(main, wk, main.lay.exits[0].p), "exit.sealed_until_home false: no seal, the way out open from the start as built before (§EX.5)")
	Fork.EXIT["sealed_until_home"] = was
	await _close(main)


# --- 7. Phase two ------------------------------------------------------------------

func _phase_two(main: CrawlerMain, exit_door: Dictionary) -> void:
	var fires := main.fires
	var boss := main.boss
	var bo := main.blackout
	var t_fell := 0.0
	ok(bo != null and bo.active and bo.put_out > 0, "the scroll taken: the blackout comes down (%d flames put out)" % (bo.put_out if bo != null else 0))
	await _frames(2)
	var any_lit := FireStore.is_lit(fires.hearth)
	for h in fires.holders:
		if FireStore.is_lit(h):
			any_lit = true
	ok(not any_lit and fires.lit_count() == 0 and fires.flame_points().is_empty() and not main.player.torch.lit(), "every flame out: no holder, not the hearth, not the torch in hand; the lit-holder count %d, flames anywhere %d" % [fires.lit_count(), fires.flame_points().size()])
	# Nothing can be lit.
	var h0: Node3D = fires.holders[0]
	var how := FireStore.swing_light(h0, 0.0)
	var how_h := FireStore.swing_light(fires.hearth, 0.0)
	var t := main.player.torch
	if t.item().is_empty():
		main.player.inventory.add(Inventory.make("torch"))
	main.player.weapon = "torch"
	t.light()
	var torch_caught := t.lit()
	var pot := {}
	if FirePots.instance != null:
		FirePots.instance._catch(pot)
	await _frames(3)
	ok(how == "no_fuel" and how_h == "no_fuel" and not FireStore.is_lit(h0) and not FireStore.is_lit(fires.hearth) and not torch_caught and not bool(pot.get("lit", false)) and fires.lit_count() == 0,
		"nothing can be lit: a sconce (%s), the hearth (%s), a torch (%s), a fire pot's wick (%s)" % [how, how_h, "caught" if torch_caught else "stays cold", "lit" if bool(pot.get("lit", false)) else "stays cold"])
	# The boss: out again, angry.
	var after := float(Blackout.boss_def().get("emerge_after_s", 3.0))
	var mult := float(Blackout.boss_def().get("speed_mult", 1.2))
	var tw := 0.0
	while boss.emerged == 0 and tw < after + 5.0:
		await physics_frame
		tw += DT
	ok(boss.emerged == 1 and absf(tw - after) <= 0.2, "the %s comes up out of its lair %.2f s after the blackout (phase_two.boss.emerge_after_s %.1f), its cry rising from the hole" % [boss.name_text, tw, after])
	var base_hunt := float(boss.def.get("hunt_mps", 4.6))
	var sprint := Tuning.num("movement", "speed", "sprint_mps")
	ok(boss.angry and absf(boss.num("hunt_mps", 0.0) - base_hunt * mult) < 1e-4 and boss.num("hunt_mps", 0.0) < sprint and absf(boss.num("speed_mps", 0.0) - float(boss.def.get("speed_mps", 2.0)) * mult) < 1e-4,
		"angry: its hunt %.2f m/s (its own %.1f times %.1f), still under your %.1f m/s sprint; its rounds %.2f m/s" % [boss.num("hunt_mps", 0.0), base_hunt, mult, sprint, boss.num("speed_mps", 0.0)])
	var rooms := 0
	var closed := 0
	for n in boss.ground.nodes:
		if str(n.kind) == "room":
			rooms += 1
			if bool(n.lit):
				closed += 1
	ok(closed == 0 and rooms > 0, "no room closed to it: all %d rooms its ground, the hearth's too" % rooms)
	var tr := 0.0
	while boss.state == "rise" and tr < 20.0:
		await physics_frame
		tr += DT
	ok(not (boss.state in ["lair", "gone", "rise", "release"]) and boss.body.visible, "out on the floor, on its rounds (%s)" % boss.state)
	# The way up: open, and reached on foot from the hearth with no flame.
	var wk: Vector3 = (main.lay.wake as Array)[0]
	ok(main.fork.exit_open() and not _blocked(main, exit_door) and _reaches(main, wk, main.lay.exits[0].p), "the way up still open, reached on foot from the hearth in the dark")
	# Three hits and Good night: you wake by the cold hearth.
	main.player._invulnerable = 0.0
	var harm := main.harm
	harm.reset()
	var log0 := GameLog.entries.size()
	var landed := 0
	for i in 3:
		if harm.hit("creature:" + boss.name_text) or not harm.hits.is_empty():
			landed = harm.hits.size()
		# Past the hit's own grace (harm.json invuln_s) before the next.
		for k in 45:
			await physics_frame
	var tt := 0.0
	while _count(str(Blackout.P2.get("wake_line", "")), log0) == 0 and tt < 30.0:
		await physics_frame
		tt += DT
	await _frames(3)
	var at_wake := Vector2(main.player.global_position.x - wk.x, main.player.global_position.z - wk.z).length()
	ok(_count(str(Blackout.P2.get("wake_line", "")), log0) == 1 and at_wake < 1.5 and not FireStore.is_lit(main.fires.hearth) and main.fires.lit_count() == 0,
		"three hits and Good night: you wake by the hearth (%.1f m from the mat), cold and dark (\"%s\")" % [at_wake, str(Blackout.P2.get("wake_line", ""))])
	main.player._invulnerable = 1.0e9
	ok(bool(CrawlerSave.kept_value(CrawlerSave.place, "blackout", false)) == Blackout.kept(), "kept in the save (blackout; phase_two.save %s)" % str(Blackout.kept()))


# --- Helpers ---------------------------------------------------------------------

func _count(text: String, from: int) -> int:
	var n := 0
	for k in range(from, GameLog.entries.size()):
		if str((GameLog.entries[k] as Dictionary).get("text", "")) == text:
			n += 1
	return n


func _reaches(main: CrawlerMain, from: Vector3, to: Vector3) -> bool:
	var path := main.residents.nav.path(from, to, false)
	return TombNav.reaches(path, to, 1.5)


func _blocked(main: CrawlerMain, d: Dictionary) -> bool:
	var p2: Vector2 = d.p
	var n2: Vector2 = d.n
	var y := float(d.y) + 1.1
	var a := Vector3(p2.x - n2.x * 0.7, y, p2.y - n2.y * 0.7)
	var b := Vector3(p2.x + n2.x * 0.7, y, p2.y + n2.y * 0.7)
	var q := PhysicsRayQueryParameters3D.create(a, b, PropCollision.WORLD_LAYER)
	q.exclude = [main.player.get_rid()]
	q.hit_from_inside = true
	return not main.player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _light(main: CrawlerMain, h: Node3D) -> void:
	FireStore.swing_light(h, float(main.world.get("days")))
	for i in 600:
		FireStore.tick(self, DT, h.global_position)
		if FireStore.is_lit(h):
			return
