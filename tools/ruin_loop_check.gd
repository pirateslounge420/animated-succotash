extends SceneTree
## The ruin's loop (design 10 Oct §FO; data/ruin_loop.json), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/ruin_loop_check.gd
## LOOP_SEEDS (env) sets how many layouts beyond 1, 7 and 42 are laid
## (default 97: a hundred in all, drawn from a fixed seed).
## Asserts (queue 85, §FO.2 and §FO.3's exit):
##  1. the layouts (a hundred seeds): one floor, no stair down (no
##     lay.descent, no stair piece below floor one), no floor-two fog
##     anywhere (FloorFog.share_at 0 at every piece);
##  2. the scene (SEED, as shipped, exit.sealed_until_home true): the way
##     out's flight sealed at its foot, its doorway blocked, the floor grid
##     finding no way from the wake spot to the way out; every torch but one
##     lit: still sealed; the last: the boss released, and once it is down
##     its lair the seal grinds (stone_seal, heard as far as it is now) and
##     is gone, the floor grid running from the wake spot to the way out;
##     kept in the save (exit_open);
##  3. Continue: the same ruin, its way up open at once and quiet;
##  4. exit.sealed_until_home false: no seal, the way out open from the start.

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
	OS.set_environment("SEED", str(seed_v))
	await _exit_scene()
	await _exit_kept()
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
	ok(Fork.gate_surface() and fork != null and fork.surface != null and fork.down == null and sd >= 0, "as shipped the way up is sealed until home (ruin_loop.json exit.sealed_until_home true), and no seal on a way down (one floor)")
	if fork == null or fork.surface == null:
		await _close(main)
		return
	var sdd: Dictionary = lay.doors[sd]
	var wk: Vector3 = (lay.wake as Array)[0]
	var ex: Dictionary = lay.exits[0]
	var exp_: Vector3 = ex.p
	ok(_blocked(main, sdd) and main.residents.nav.door_shut(sdd) and not _reaches(main, wk, exp_), "every torch cold: the way out's flight sealed at its foot (its doorway blocked, shut on the floor grid, no way from the wake spot to the way out)")
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
	await _close(main)


func _exit_kept() -> void:
	OS.set_environment("SEED", "")
	var main := await _open_scene()
	var fork := main.fork
	var sd := Fork.surface_door(main.lay)
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


# --- Helpers ---------------------------------------------------------------------

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
