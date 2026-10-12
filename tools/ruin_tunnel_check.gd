extends SceneTree
## The shrine mouths and the tunnel between two ruins (design 11 Oct §FV.2,
## §FV.5; queue 100 amended by Mike 12 Oct: the second built culture is the
## Aztec temple; RuinTunnel, Surface, CrawlerMain, CrawlerSave;
## data/ruin_compass.json tunnel), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/ruin_tunnel_check.gd
## Asserts:
##  1. the pairs: the tomb's one shrine is north to the temple, the temple's
##     south to the tomb (tunnel.built_pair); with the temple out of the
##     game (aztec_on false) neither has one; the compass's other exits
##     (the aztec row's north and east, toward unbuilt ruins) have none;
##     over 200 games the place across the tunnel is always the other ruin
##     (the first drawn at random, §FJ.1) and its seed comes from the
##     game's seed, never the game's own;
##  2. a fresh game, nothing done: up the stair, the surface has exactly
##     the one shrine, on its compass line, on the walkable land, short of
##     the edge; in through its doorway: the tunnel, open (nothing gates
##     it), no boss and no resident in it;
##  3. its stone: the first stretch only this ruin's style, the last only
##     the next's, the mixed both, in that order (and the other way round
##     coming back);
##  4. through: the next ruin built from the game's seed (place 1, the other
##     theme), you up on its surface at its shrine on the opposite edge
##     (go south, arrive at the north edge), its stair down into it working;
##  5. lit stays lit both ways: two torches lit there, back through to the
##     first ruin (its stretches the other way round), three lit there, then
##     walking back from the near end of a tunnel brings you up the shrine
##     you went down; on again: the two still burn;
##  6. save and Continue: the game reopened lands in the ruin you were in,
##     its theme and its lights as left, the other ruin's lights kept too.
## Walkabout once (tools/crawler_frames.gd SHOT=tunnel): see there.

var fails := 0
const DT := 1.0 / 60.0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


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


func _light(main: CrawlerMain, h: Node3D) -> void:
	FireStore.swing_light(h, float(main.world.get("days")))
	for i in 600:
		FireStore.tick(self, DT, h.global_position)
		if FireStore.is_lit(h):
			return


func _wait(main: CrawlerMain, cond: Callable, max_s := 30.0) -> bool:
	var t := 0.0
	while not cond.call() and t < max_s:
		await physics_frame
		t += DT
	await _frames(2)
	return cond.call()


func _run() -> void:
	WorldSave.read_only = true
	Bow.need_capture = false
	Residents.stay_asleep = true
	Torch.burn_down = false
	_pairs()
	await _walk()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


# --- 1. The pairs -----------------------------------------------------------------------

func _pairs() -> void:
	ok(CrawlerSave.aztec_on, "the temple is in the game (aztec_temple.json enabled, 12 Oct)")
	var t := RuinTunnel.exits_of("tomb")
	var a := RuinTunnel.exits_of("aztec_temple")
	ok(t.size() == 1 and str(t[0].dir) == "north" and str(t[0].to) == "aztec_temple", "the tomb: one shrine, north, to the temple (%s)" % str(t))
	ok(a.size() == 1 and str(a[0].dir) == "south" and str(a[0].to) == "tomb", "the temple: one shrine, south, to the tomb (%s)" % str(a))
	ok(RuinTunnel.exits_of("") == t, "the layout's own theme (\"\") is the tomb's")
	CrawlerSave.aztec_on = false
	ok(RuinTunnel.exits_of("tomb").is_empty() and RuinTunnel.exits_of("aztec_temple").is_empty(), "with the temple out of the game neither ruin has a shrine: its edges closed by the land")
	CrawlerSave.aztec_on = true
	var rows: Dictionary = (RuinTunnel.RC.get("ruins", {}) as Dictionary).get("aztec", {}).get("exits", {})
	var unbuilt := 0
	for d in rows:
		var to := str(rows[d])
		if not str(((RuinTunnel.RC.ruins as Dictionary).get(to, {}) as Dictionary).get("status", "")).begins_with("built"):
			unbuilt += 1
			ok(not RuinTunnel.bearings("aztec_temple").has(float({"north": 0.0, "east": 90.0, "south": 180.0, "west": 270.0}[d])) or d == "south",
				"the compass's %s exit toward %s (not built): no shrine of its own" % [d, to])
	ok(unbuilt == rows.size(), "every exit on the aztec row points at an unbuilt ruin (%d): no shrine opens toward any of them" % unbuilt)
	var bad := 0
	var both := {}
	for g in range(1, 201):
		CrawlerSave.game_seed = g
		CrawlerSave.data = {"dungeons": {}}
		var t0 := RuinTunnel.norm(CrawlerSave.theme_at(0))
		var t1 := RuinTunnel.norm(CrawlerSave.theme_at(1))
		both[t0] = true
		if t1 == t0 or RuinTunnel.neighbour(t0) != t1 or CrawlerSave.seed_at(1) == g or CrawlerSave.seed_at(1) != CrawlerSave.dungeon_seed(g, 1):
			bad += 1
	ok(bad == 0 and both.size() == 2, "over 200 games the ruin across the tunnel is the other one, its seed from the game's (%d wrong; first ruins drawn %s)" % [bad, str(both.keys())])
	CrawlerSave.game_seed = 0
	CrawlerSave.data = {}


# --- 2 to 6. The walk -------------------------------------------------------------------

func _in_shrine(main: CrawlerMain, sp: Dictionary) -> void:
	var n: Vector2 = sp.n
	var p: Vector3 = sp.pos
	main.player.spawn_flat(p - Vector3(n.x, 0.0, n.y) * 1.8, atan2(n.x, n.y), 0.0)


func _stone_order(main: CrawlerMain, from: String, to: String, what: String) -> void:
	var tn := main.tunnel
	var tr: Array = tn.tris
	ok(tn.from_theme == from and tn.to_theme == to, "%s: the tunnel runs from the %s to the %s" % [what, from, to])
	ok(int(tr[0][0]) > 0 and int(tr[0][1]) == 0 and int(tr[2][0]) == 0 and int(tr[2][1]) > 0 and int(tr[1][0]) > 0 and int(tr[1][1]) > 0,
		"%s: its stone in three stretches in order: the first all %s (%d tris), the mixed both (%d and %d), the last all %s (%d) %s" % [what, RuinStyle.style_name(from), tr[0][0], tr[1][0], tr[1][1], RuinStyle.style_name(to), tr[2][1], str(tn.bands)])
	ok(main.boss.get_parent() == null and main.residents.get_parent() == null and tn.find_children("*", "Boss", true, false).is_empty() and tn.find_children("*", "Resident", true, false).is_empty(),
		"%s: no boss and no resident in it (the ruin's kept out of the tree)" % what)


func _through(main: CrawlerMain, what: String) -> bool:
	var tn := main.tunnel
	var far := tn.start + Vector3(tn.along.x, 0.0, tn.along.y) * (tn.length - 0.4)
	main.player.spawn_flat(far, 0.0, 0.0)
	var n0 := main.tunnels_through
	var done := await _wait(main, func(): return main.tunnels_through > n0 and not main.leaving, 60.0)
	ok(done and main.on_surface and not main.in_tunnel, "%s: through the far end and up on the next surface" % what)
	return done


func _walk() -> void:
	OS.set_environment("SEED", "7")
	var main := await _open_scene()
	var a := RuinTunnel.norm(str(main.lay.get("theme", "")))
	var b := RuinTunnel.neighbour(a)
	print("== game %d: the first ruin the %s, across the tunnel the %s" % [CrawlerSave.game_seed, a, b])
	ok(b != "" and b != a, "a fresh game's first ruin has a neighbour across the tunnel")
	# 2. Fresh, nothing done: up, and in.
	ok(main.fires.lit_count() == 0, "nothing done: no torch lit")
	await main.go_up()
	await _frames(3)
	var sh: Array = main.surface.shrines
	var d := str(RuinTunnel.exits_of(a)[0].dir)
	ok(sh.size() == 1 and str(sh[0].dir) == d and main.surface.find_child("Shrine_" + d, false, false) != null, "up top: exactly one shrine, toward %s (%d)" % [d, sh.size()])
	var sp: Dictionary = sh[0]
	var land := main.surface.land
	var p: Vector3 = sp.pos
	var rel := Vector2(p.x, p.z) - land.center
	var v: Vector2 = RuinTunnel.DIRS[d]
	ok(rel.normalized().dot(v) > 0.999 and land.inside(Vector2(p.x, p.z), 2.0),
		"the shrine on the compass line %s of the stairhead, %.0f m out, on the walkable land short of the edge (%.0f m to the cliff's foot)" % [d, rel.length(), land.edge_r(atan2(v.y, v.x)) - rel.length()])
	var arr := RuinTunnel.arrival(sp)
	ok(absf(main.surface.land.height_at(arr.pos.x, arr.pos.z) - (arr.pos as Vector3).y) < 1.0, "where you come up out of it is on the ground (%.2f m off)" % absf(main.surface.land.height_at(arr.pos.x, arr.pos.z) - (arr.pos as Vector3).y))
	_in_shrine(main, sp)
	var inn := await _wait(main, func(): return main.in_tunnel and not main.leaving)
	ok(inn and main.tunnel != null and not main.on_surface, "in through its doorway: the tunnel, open on a fresh game with nothing lit and the boss never home (nothing gates it)")
	if not inn:
		await _close(main)
		return
	_stone_order(main, a, b, "going")
	# 4. Through.
	if not await _through(main, "the first way"):
		await _close(main)
		return
	var th1 := RuinTunnel.norm(str(main.lay.get("theme", "")))
	ok(CrawlerSave.place == 1 and th1 == b and int(main.lay.seed) == CrawlerSave.dungeon_seed(CrawlerSave.game_seed, 1), "the next ruin: place 1, the %s, seed %d from the game's seed" % [th1, int(main.lay.seed)])
	var sp2: Dictionary = main.surface.shrine_toward(str(RuinTunnel.OPPOSITE[d]))
	ok(not sp2.is_empty() and main.player.global_position.distance_to(RuinTunnel.arrival(sp2).pos) < 1.5, "up at its shrine on the opposite edge (%s, going %s)" % [str(RuinTunnel.OPPOSITE[d]), d])
	# Its own way in: the stair.
	await main.go_down()
	await _frames(3)
	ok(not main.on_surface and main.tomb.is_inside_tree(), "down its own stair into the %s" % b)
	# 5. Lit stays lit.
	for i in 2:
		_light(main, main.fires.holders[i])
	await _frames(3)
	ok((CrawlerSave.dungeon(1).get("relit", []) as Array).size() == 2, "two torches lit in the %s, kept" % b)
	await main.go_up()
	_in_shrine(main, main.surface.shrine_toward(str(RuinTunnel.OPPOSITE[d])))
	await _wait(main, func(): return main.in_tunnel and not main.leaving)
	_stone_order(main, b, a, "coming back")
	await _through(main, "back")
	ok(CrawlerSave.place == 0 and RuinTunnel.norm(str(main.lay.get("theme", ""))) == a, "back in the first ruin (place 0, the %s)" % a)
	await main.go_down()
	for i in 3:
		_light(main, main.fires.holders[i])
	await _frames(3)
	ok((CrawlerSave.dungeon(0).get("relit", []) as Array).size() == 3, "three lit in the %s, kept" % a)
	await main.go_up()
	_in_shrine(main, main.surface.shrine_toward(d))
	await _wait(main, func(): return main.in_tunnel and not main.leaving)
	main.player.spawn_flat(main.tunnel.start + Vector3(main.tunnel.along.x, 0.0, main.tunnel.along.y) * 0.2, 0.0, 0.0)
	var nb := main.tunnels_back
	var back := await _wait(main, func(): return main.tunnels_back > nb and not main.leaving)
	ok(back and main.on_surface and CrawlerSave.place == 0 and main.player.global_position.distance_to(RuinTunnel.arrival(main.surface.shrine_toward(d)).pos) < 1.5,
		"walking back to the near end: up the shrine you went down, the same surface")
	_in_shrine(main, main.surface.shrine_toward(d))
	await _wait(main, func(): return main.in_tunnel and not main.leaving)
	await _through(main, "on again")
	await main.go_down()
	await _frames(3)
	ok(CrawlerSave.place == 1 and main.fires.lit_count() == 2, "on again in the %s: its two torches still burn (%d)" % [b, main.fires.lit_count()])
	await _close(main)
	# 6. Save and Continue.
	OS.set_environment("SEED", "")
	main = await _open_scene()
	ok(CrawlerSave.continued and CrawlerSave.place == 1 and RuinTunnel.norm(str(main.lay.get("theme", ""))) == b and main.fires.lit_count() == 2,
		"Continue: back in the %s by its hearth, its two torches burning (%d)" % [b, main.fires.lit_count()])
	ok((CrawlerSave.dungeon(0).get("relit", []) as Array).size() == 3 and str(CrawlerSave.dungeon(0).get("theme", "")) in [a, ""], "and the %s's three kept in the save" % a)
	await _close(main)
