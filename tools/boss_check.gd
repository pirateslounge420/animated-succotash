extends SceneTree
## The dungeon's boss (design 6 Oct §EY.1, §EY.2; queue 49; Boss,
## BossGround, bosses.json), headless, over seeds 1, 7 and 42 (BOSS_SEEDS=
## "1,7,42" to change):
##   godot --headless --path . --fixed-fps 60 --script tools/boss_check.gd
## Asserts, for each seed:
##  1. its ground (BossGround): the dark node count never rises as the
##     holders are relit (in the layout's order, outward from the hearth,
##     and shuffled) and reaches nothing at the last holder, never before;
##     the hearth room is never its ground;
##  2. the lair: placed, in a room off the main way (BossGround.main_path:
##     the spine, or hearth room to heart), clear of that room's doors and
##     of the line between them; and over 30 more layouts;
##  3. contact: you standing still in the dark beside it with your torch
##     lit: it holds at the torch's edge (torch_delay), then strikes; the
##     hits land no closer together than harm.json's invuln_s; the third is
##     "Good night", and you wake on the mat by the hearth with the holders
##     you lit still lit, your hands empty; it goes back to its rounds; then
##     with your torch out it comes straight in (no hold);
##  4. a scripted run relighting every holder in the layout's order, the
##     snake free between relights (you in the hearth room): it never walks
##     into a lit node, it leaves one lit round it at once, and after the
##     last light it is in its lair, breathing (heard within
##     lair.breathing_heard_m), the log has release.log_line and the tomb's
##     small sounds come back;
##  5. its tell plays as it prowls, quieter while it lies coiled.

var fails := 0
var DT := 1.0 / 30.0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	WorldSave.read_only = true
	Bow.need_capture = false
	var seeds: Array = [1, 7, 42]
	var env := OS.get_environment("BOSS_SEEDS")
	if env != "":
		seeds = []
		for s in env.split(","):
			if s.strip_edges().is_valid_int():
				seeds.append(int(s))
	_lairs()
	for sv in seeds:
		print("== seed %d" % sv)
		_ground(TombKit.layout(sv))
		var main := await _boot(sv)
		_lair_of(main)
		await _contact(main)
		main.queue_free()
		await process_frame
		main = await _boot(sv)
		await _relight_run(main)
		main.queue_free()
		await process_frame
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _boot(sv: int) -> CrawlerMain:
	OS.set_environment("SEED", str(sv))
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked or not main.boss.started:
		await process_frame
	main.boss.auto = false
	return main


# --- 1. The ground -------------------------------------------------------------

func _ground(lay: Dictionary) -> void:
	var g := BossGround.build(lay)
	var n := (lay.holders as Array).size()
	var hearth_ok := true
	for nd in g.nodes:
		if bool(nd.hearth) and g.is_ground(int(nd.id)):
			hearth_ok = false
	ok(hearth_ok and g.ground_count() > 0, "its ground at the start: %d of %d nodes dark (%d rooms, the rest corridor stretches), the hearth room not among them" % [g.ground_count(), g.nodes.size(), _rooms(g)])
	# Three orders: the layout's, outward from the hearth room, shuffled.
	var orders := {"layout": range(n), "outward": _outward(lay, g), "shuffled": _shuffled(n, int(lay.seed))}
	for name in orders:
		var order: Array = orders[name]
		var lit: Array = []
		lit.resize(n)
		lit.fill(false)
		g.update(lit)
		var counts: Array = [g.ground_count()]
		var rises := 0
		var early := -1
		for k in order.size():
			lit[order[k]] = true
			g.update(lit)
			var c := g.ground_count()
			if c > int(counts[-1]):
				rises += 1
			if c == 0 and k < order.size() - 1 and early < 0:
				early = k
			counts.append(c)
		ok(rises == 0 and early < 0 and int(counts[-1]) == 0, "relit %s: the dark never grows and is gone only at the last of %d holders (%s)" % [name, n, _short(counts)])


func _rooms(g: BossGround) -> int:
	var k := 0
	for nd in g.nodes:
		if str(nd.kind) == "room":
			k += 1
	return k


func _short(a: Array) -> String:
	var parts: Array = []
	for v in a:
		parts.append(str(v))
	return " ".join(parts)


## The holders by their distance from the hearth room.
func _outward(lay: Dictionary, g: BossGround) -> Array:
	var dist: Dictionary = g._dijkstra(0, false, 0.0).dist
	var hs: Array = []
	for i in (lay.holders as Array).size():
		var h: Dictionary = lay.holders[i]
		var id := g.node_at(h.pos)
		hs.append([float(dist.get(id, 999.0)), i])
	hs.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var out: Array = []
	for x in hs:
		out.append(int(x[1]))
	return out


func _shuffled(n: int, s: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = s * 31 + 5
	var a: Array = range(n)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a


# --- 2. The lair ----------------------------------------------------------------

func _lair_ok(lay: Dictionary) -> String:
	var l: Dictionary = lay.get("lair", {})
	if l.is_empty():
		return "no lair"
	var pc: Dictionary = lay.pieces[int(l.piece)]
	if str(pc.kind) != "room" or str(pc.get("room_kind", "")) in ["hearth", "heart"]:
		return "in a %s %s" % [pc.get("room_kind", ""), pc.kind]
	if int(l.piece) in BossGround.main_path(lay):
		return "on the main way"
	var c := Vector2((l.pos as Vector3).x, (l.pos as Vector3).z)
	for di in pc.doors:
		var d: Dictionary = lay.doors[di]
		if c.distance_to(d.p) < float(l.r) + 1.9:
			return "%.2f m from a door" % c.distance_to(d.p)
	for i in (pc.doors as Array).size():
		for j in range(i + 1, (pc.doors as Array).size()):
			var a: Vector2 = lay.doors[pc.doors[i]].p
			var b: Vector2 = lay.doors[pc.doors[j]].p
			if c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)) < float(l.r) + 1.1:
				return "in the way between its doors"
	return ""


func _lairs() -> void:
	var bad := 0
	var dead_ends := 0
	for s in 30:
		var lay := TombKit.layout(5000 + s * 7919)
		var why := _lair_ok(lay)
		if why != "":
			bad += 1
			print("  seed %d: lair %s" % [lay.seed, why])
		elif (lay.pieces[int(lay.lair.piece)].doors as Array).size() == 1:
			dead_ends += 1
	ok(bad == 0, "30 layouts: a lair in a side room off the main way every time, clear of its doors (%d in dead ends)" % dead_ends)


func _lair_of(main: CrawlerMain) -> void:
	var why := _lair_ok(main.lay)
	var l: Dictionary = main.lay.get("lair", {})
	ok(why == "", "the lair: room %s (%s), off the main way %s, the hole %.1f m across %s" % [l.get("piece", "-"), main.lay.pieces[int(l.get("piece", 0))].get("room_kind", ""), str(BossGround.main_path(main.lay)), float(l.get("r", 0.0)) * 2.0, why])
	# Not a way down: the ring keeps you at its edge.
	if not l.is_empty():
		var c: Vector3 = l.pos
		var q := PhysicsRayQueryParameters3D.create(c + Vector3(float(l.r) + 1.0, 0.8, 0.0), c + Vector3(0.0, 0.8, 0.0))
		q.exclude = [main.player.get_rid()]
		var hit := get_root().get_world_3d().direct_space_state.intersect_ray(q)
		ok(not hit.is_empty() and (hit.position as Vector3).distance_to(c) > float(l.r) - 0.05, "you can stand at the hole's edge but not step in (enterable false)")


# --- 3. Contact ------------------------------------------------------------------

## Step the boss and the harm together `secs` seconds (the player stands
## as placed: no physics runs).
func _sim(main: CrawlerMain, secs: float, stop: Callable = Callable()) -> float:
	var t := 0.0
	while t < secs:
		main.boss.tick(DT)
		main.harm.tick(DT)
		t += DT
		if stop.is_valid() and bool(stop.call()):
			break
	return t


func _place(p: CrawlerPlayer, at: Vector3, look: Vector3) -> void:
	var flat := Vector3(look.x - at.x, 0.0, look.z - at.z)
	p.spawn_flat(at, atan2(-flat.x, -flat.z), 0.0)


func _light_holder(main: CrawlerMain, h: Node3D) -> void:
	FireStore.swing_light(h, float(main.world.get("days")))
	for i in 600:
		FireStore.tick(self, 1.0 / 60.0, h.global_position)
		if FireStore.is_lit(h):
			return


func _contact(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var t := p.torch
	var fires := main.fires
	# Two holders lit first (they must still be lit when you wake): the
	# hearth room's own corridor sconces, if any, else the first two.
	var lit_first: Array = []
	for i in mini(2, fires.holders.size()):
		_light_holder(main, fires.holders[i])
		lit_first.append(i)
	b._refresh(false)
	# Beside it in the dark: 3 m in front of its head, in its own node.
	var spot := _beside(b, 3.0)
	ok(spot != Vector3.INF, "a spot in its dark 3 m from it (it lies coiled in node %d, a %s)" % [b.node, b.ground.nodes[b.node].kind])
	if spot == Vector3.INF:
		return
	p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	t.light()
	_place(p, spot, b.head)
	await physics_frame
	var hits_at: Array = []
	var landed0 := main.harm.landed
	var noticed_at := -1.0
	var hold_from := -1.0
	var hold_until := -1.0
	var clock := 0.0
	var invuln := float(Harm.D.get("invuln_s", 0.6))
	while clock < 40.0 and not main.harm.taking:
		_sim(main, DT)
		clock += DT
		if b.noticed and noticed_at < 0.0:
			noticed_at = clock
		if b.state == "hang" and hold_from < 0.0:
			hold_from = clock
		if hold_from >= 0.0 and hold_until < 0.0 and b.state in ["hunt", "strike"]:
			hold_until = clock
		if main.harm.landed > landed0 + hits_at.size():
			hits_at.append(clock)
	# One more beat: it sees you are taken.
	_sim(main, DT)
	var gaps: Array = []
	for k in range(1, hits_at.size()):
		gaps.append(float(hits_at[k]) - float(hits_at[k - 1]))
	var min_gap: float = gaps.min() if not gaps.is_empty() else 0.0
	var delay := b.sub("torch_delay")
	print("  noticed at %.2f s, held %.2f..%.2f s, hits at %s" % [noticed_at, hold_from, hold_until, str(hits_at)])
	ok(noticed_at >= 0.0 and noticed_at < 1.0, "your lit torch in its sight: it notices you (%.2f s)" % noticed_at)
	ok(hold_from >= 0.0 and hold_until - hold_from >= float(delay.get("hang_s", 4.0)) - 0.1, "your torch is a delay: it holds at the torch's edge %.1f s before it closes (torch_delay.hang_s %.1f)" % [hold_until - hold_from, float(delay.get("hang_s", 4.0))])
	ok(hits_at.size() == 3 and min_gap >= invuln - 0.01, "standing still in the dark beside it: three hits (%d), never closer than invuln_s %.2f (closest %.2f s apart)" % [hits_at.size(), invuln, min_gap])
	ok(main.harm.taking and b.state == "held", "the third hit takes you: \"Good night\" (Harm), and it holds off")
	# The taken sequence plays out; you wake at the hearth.
	_sim(main, Harm.taken_s() + 0.5, func(): return not main.harm.taking)
	await process_frame
	var w: Array = main.lay.wake
	var at_hearth := p.global_position.distance_to(w[0]) < 0.3
	var still_lit := true
	for i in lit_first:
		if not FireStore.is_lit(fires.holders[i]):
			still_lit = false
	ok(at_hearth and not p.dead and not main.harm.taking and main.harm.hits.is_empty(), "you wake on the mat by the hearth (%.2f m from it), whole" % p.global_position.distance_to(w[0]))
	ok(still_lit and fires.lit_count() == lit_first.size(), "every light you lit is still lit (%d of %d)" % [fires.lit_count(), lit_first.size()])
	ok(p.weapon == "hands" and not t.lit() and p.inventory.has_kind("torch"), "your torch went out as you fell; it is in your pack, your hands empty")
	ok(b.state in ["coil", "prowl"] and not b.noticed and b.ground.is_ground(b.node), "it is back on its rounds (%s, node %d)" % [b.state, b.node])
	ok(GameLog.entries.size() > 0 and str(GameLog.entries[-1].text).contains("wake by the hearth"), "the log: \"%s\"" % str(GameLog.entries[-1].text))
	# Torch out: it comes straight in (once the breath after waking,
	# PlanetPlayer.revive's few seconds, has run out).
	for i in 200:
		await physics_frame
	_sim(main, 3.0)
	var spot2 := _beside(b, 1.2)
	if spot2 != Vector3.INF:
		p.weapon = "hands"
		_place(p, spot2, b.head)
		await physics_frame
		var landed1 := main.harm.landed
		var first := -1.0
		var held := false
		var c2 := 0.0
		while c2 < 8.0 and first < 0.0:
			_sim(main, DT)
			c2 += DT
			if b.state == "hang":
				held = true
			if main.harm.landed > landed1:
				first = c2
		ok(first > 0.0 and first < 2.5 and not held, "your torch out, it comes straight in: no hold, the first strike lands at %.2f s" % first)
	# Let Harm settle (its hitstop and its clock run on real frames).
	main.harm.reset()
	for i in 4:
		await process_frame


## A spot in the snake's own dark `d` m in front of its head (Vector3.INF if
## none): in the node it lies in, on its floor.
func _beside(b: Boss, d: float) -> Vector3:
	for k in 16:
		var a := TAU * k / 16.0
		var q := b.head + Vector3(cos(a), 0.0, sin(a)) * d
		q.y = b._floor_y(q)
		var id := b.ground.node_at(q)
		if id >= 0 and b.ground.is_ground(id) and (id == b.node or not b.ground.link(id, b.node).is_empty()) and not b._blocked(b.head + Vector3(0, 0.6, 0), q + Vector3(0, 0.6, 0), false):
			var pc: Dictionary = b.lay.pieces[int(b.ground.nodes[id].piece)]
			var aa := Delves.along_across(pc, Vector2(q.x, q.z))
			if aa.x > 0.4 and aa.x < float(pc.len) - 0.4 and absf(aa.y) < float(pc.half) - 0.45:
				return q
	return Vector3.INF


# --- 4. The relight run ------------------------------------------------------

func _relight_run(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var fires := main.fires
	# You in the hearth room, out of its way.
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), 0.0)
	await physics_frame
	# Its tell while it goes its rounds, and coiled.
	var db_move := -INF
	var db_coil := INF
	var played := false
	var seen_states := {}
	for i in int(60.0 / DT):
		b.tick(DT)
		seen_states[b.state] = true
		if b._tell.playing:
			played = true
		if b.state in ["prowl"] and b.speed > 0.5:
			db_move = maxf(db_move, b._tell.volume_db)
		if b.state == "coil" and not b.coiling and b.coil_left > 0.0:
			db_coil = minf(db_coil, b._tell.volume_db)
	ok(played and db_move > db_coil + 8.0, "its tell, scales on stone: %.0f dB on the move, %.0f dB coiled (states %s)" % [db_move, db_coil, str(seen_states.keys())])
	var hush_db := float(Boss.RELEASE.get("bed_hush_db", -18.0))
	ok(main.drips != null and absf(main.drips.volume_db - (b.bed_db + hush_db)) < 0.5, "the tomb's small sounds hushed while it prowls (drips %.0f dB, their own %.0f)" % [main.drips.volume_db if main.drips else 0.0, b.bed_db])
	# Every holder in the layout's order, a while of the snake between.
	var n := fires.holders.size()
	var counts: Array = [b.ground.ground_count()]
	var in_light := 0.0
	var worst_leave := 0.0
	var lit_entries0 := b.lit_entries
	var left_lit := 0
	var went_below := 0
	var hearth_visits := 0
	for k in n:
		_light_holder(main, fires.holders[k])
		var left := 0.0
		var was_lit := false
		var steps := int((14.0 if k < n - 1 else 1.0) / DT)
		for i in steps:
			var before := b.state
			b.tick(DT)
			if b.state in ["lair", "gone", "release"]:
				break
			if b.body.visible and b.node >= 0 and bool(b.ground.nodes[b.node].hearth):
				hearth_visits += 1
			if b.state == "below":
				if before != "below":
					went_below += 1
				continue
			var dark := b.ground.is_ground(b.node)
			if not dark:
				if b.state == "leave":
					was_lit = true
					left += DT
				else:
					in_light += DT
		if was_lit:
			left_lit += 1
			worst_leave = maxf(worst_leave, left)
		counts.append(b.ground.ground_count())
	print("  dark nodes as each holder caught: %s" % _short(counts))
	ok(b.lit_entries == lit_entries0 and in_light < 0.05, "over the whole run it never went into the light of its own accord (%d entries, %.2f s in light outside leaving)" % [b.lit_entries - lit_entries0, in_light])
	ok(worst_leave < 6.0, "lit round it, it slid out of the light %d times, within %.1f s at worst; cut off deeper, it went down into the dark below %d times" % [left_lit, worst_leave, went_below])
	ok(hearth_visits == 0, "it never set foot in the hearth room")
	# The release.
	var rel_state := b.state
	_sim_boss(b, float(Boss.RELEASE.get("cry_s", 5.0)) + 1.0)
	var line := str(Boss.RELEASE.get("log_line", "")).format({"boss": b.name_text})
	var logged := false
	for e in GameLog.entries:
		if str(e.text).begins_with(line):
			logged = true
	ok(rel_state in ["release", "lair"] and b.released, "the last light: it goes home (%s)" % rel_state)
	ok(b.state == "lair" and b.base.distance_to(main.lay.lair.pos) < 0.05 and not b.body.visible, "after the last light it is in its lair, out of sight")
	ok(logged, "the log: \"%s.\"" % line)
	var heard := float(Boss.LAIR.get("breathing_heard_m", 12.0))
	ok(b._breath.playing and is_equal_approx(b._breath.max_distance, heard) and b._breath.global_position.y < float(main.lay.lair.pos.y) - 0.5, "its breathing from below the hole, heard within %.0f m" % heard)
	_sim_boss(b, float(Boss.RELEASE.get("bed_return_s", 4.0)) + 0.5)
	ok(absf(main.drips.volume_db - b.bed_db) < 0.5 and not b._tell.playing, "the tomb's small sounds come back (drips %.0f dB), and the scales are gone" % main.drips.volume_db)


func _sim_boss(b: Boss, secs: float) -> void:
	var t := 0.0
	while t < secs:
		b.tick(DT)
		t += DT
