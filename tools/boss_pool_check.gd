extends SceneTree
## The boss behaviour pool (design 9 Oct §FM.1; queue 65; BossPool,
## BossState, Boss; data/boss_pool.json), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/boss_pool_check.gd
## POOL_SEEDS="1,7,42" for the route runs (the default); the other parts
## run on the first of them. POOL_ONLY="draws,unknown,routes,strike,pot,
## release,light,exit" runs some parts only. Asserts:
##  1. the draw (BossPool, no tomb): a test pool of three states, weights
##     1, 2 and 3, over 200 draws: not a fixed sequence (no period of 20
##     draws or fewer, and a second pool's 200 are not the same: its dice
##     are live, not seeded), no state twice running, every state drawn,
##     and each one's share within 0.1 of what its weight gives under that
##     rule (w(W - w) over the sum of them); over 20,000 more, within 0.02;
##     every dwell inside its state's dwell_s [min, max], and not all the
##     same; a pool of one state draws it every time; a state that can't
##     come now is never drawn, and with none that can the draw is "";
##     rule.live_rng false: the same game seed draws the same, another
##     seed not;
##  2. unknown ids: a pool naming a state no code registers warns once (not
##     again when loaded again), skips it and never draws it, no crash; an
##     entry that is not one is skipped; a pool of nothing registered is
##     its built rounds; boss_pool.json: 'rounds' is found by its file
##     (scripts/crawler/boss_states/rounds.gd), every id in the pools that
##     no code registers yet is skipped with one warning, and every boss's
##     live pool is listed, those with only 'rounds' drawing nothing else;
##  3. the same route: for each seed, the snake 150 s loose from its start,
##     you by the hearth, two relights round it and a fire pot on the way:
##     its place and state every third frame are the same with no pool at
##     all (the boss as built before queue 65, Boss.pool_off), with its
##     pool from boss_pool.json while that is 'rounds' alone (after queue 66
##     it isn't, and that run is reported, not compared), and with a pool
##     of 'rounds' alone asked every fraction of a second (hundreds of
##     draws);
##  4. never mid-strike: with a pool that changes state every tenth of a
##     second (rounds, and a state that does nothing), the snake beside
##     you, your torch lit: it holds at your flame, strikes three times,
##     takes you and lets you go when you wake, and no draw comes while it
##     hunts you, holds, strikes (the wind-up, the lunge, the draw back),
##     watches or holds you taken (rule.never_breaks); a state that strikes
##     (Boss.begin_strike), your torch out: the strike's wind-up with its
##     tell first, wind_up_s before the lunge, the state over as it begins
##     and no draw until it is done; your torch lit: your flame holds it
##     first (torch_delay.hang_s), then the strike;
##  5. the pot: driven off, no draw while it is stunned, flees, lies down
##     its hole or rises, and the pool asked again once it is back on its
##     rounds;
##  6. the last light: no draw from the moment it goes home, nor once it is
##     in its hole;
##  7. the light: a light catching elsewhere, the state in charge hears of
##     it (BossState.lights_changed) and goes on; a state that lies still in
##     a room relit round it is over on that tick and it leaves for the dark
##     as built, the state drawn again once it is there; a state that walks
##     it into the light (the hearth room) is over on the tick it goes in,
##     and it leaves;
##  8. a state's own end, and the way out: a state that ends itself (its
##     dwell 999 s) has the next drawn at once; 'rounds' after a state that
##     left it in one of its own takes it back on its rounds; with no state
##     that may come, its built rounds go on and the pool is asked again
##     every Boss.POOL_RETRY_S; a state that keeps it still on the way out
##     (the flight up to the daylight) is over after Boss.EXIT_WAIT_S, and it
##     goes on its rounds off the way out before a state is drawn again.

var fails := 0
var DT := 1.0 / 30.0
## Seconds it runs loose in each route run.
const ROUTE_S := 150.0
## Off the light for good within this (s): the boss check's bound.
const LEAVE_MOST_S := 12.0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


# --- The check's own states --------------------------------------------------

## Does nothing: it lies as it is (test_idle, test_gate; and the draw's
## test states).
class IdleState extends BossState:
	pass


## Can never come (its needs never hold).
class NeverState extends BossState:
	func can_enter(_boss: Boss) -> bool:
		return false


## Lies still, and counts the lights that caught elsewhere while it was in
## charge (BossState.lights_changed).
class StayState extends BossState:
	var lights := 0
	func lights_changed(_boss: Boss) -> void:
		lights += 1


## Leaves it in a state of its own ("stare") and ends itself after 0.3 s.
class DoneState extends BossState:
	var t := 0.0
	var entered := 0
	func enter(boss: Boss, _from: String) -> void:
		entered += 1
		t = 0.0
		boss.state = "stare"
	func tick(boss: Boss, delta: float) -> void:
		t += delta
		if t >= 0.3:
			boss.end_state()


## Strikes at once, by the strike as built, and ends itself.
class StrikeState extends BossState:
	var calls := 0
	var began := false
	var called_at := -1.0
	func enter(boss: Boss, _from: String) -> void:
		calls += 1
		if called_at < 0.0:
			called_at = boss.clock
		began = boss.begin_strike()
		boss.end_state()


## Walks it into node `goal` (lit) by any way, the hearth room and all.
class TrespassState extends BossState:
	var goal := -1
	func enter(boss: Boss, _from: String) -> void:
		var from := boss._plan_from()
		var path := boss.ground.path(int(from.node), goal, false, 0.0, 0.0)
		boss._set_planned(from, path, boss.ground.nodes[goal].center)
		boss.state = "prowl"
	func tick(boss: Boss, delta: float) -> void:
		boss._advance(boss.num("speed_mps", 2.0), delta)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	WorldSave.read_only = true
	# The tomb's skeletons sleep through this check (design §FE; queue 58).
	Residents.stay_asleep = true
	Bow.need_capture = false
	BossPool.register("test_a", IdleState)
	BossPool.register("test_b", func() -> BossState: return IdleState.new())
	BossPool.register("test_c", IdleState)
	BossPool.register("test_idle", IdleState)
	BossPool.register("test_gate", IdleState)
	BossPool.register("test_never", NeverState)
	var seeds: Array = [1, 7, 42]
	var env := OS.get_environment("POOL_SEEDS")
	if env != "":
		seeds = []
		for s in env.split(","):
			if s.strip_edges().is_valid_int():
				seeds.append(int(s))
	var only := OS.get_environment("POOL_ONLY").split(",", false)
	var want := func(part: String) -> bool: return only.is_empty() or only.has(part)
	if want.call("draws"):
		_draws()
	if want.call("unknown"):
		_unknown()
	if want.call("routes"):
		for sv in seeds:
			print("== seed %d: the same route" % sv)
			await _routes(sv)
	var sv0: int = seeds[0] if not seeds.is_empty() else 7
	if want.call("strike") or want.call("pot") or want.call("release"):
		print("== seed %d: the rule's moments" % sv0)
		var main := await _boot(sv0)
		if want.call("strike"):
			await _strike(main)
		if want.call("pot"):
			_pot(main)
		if want.call("release"):
			_release(main)
		await _done(main)
	if want.call("light"):
		print("== seed %d: the light" % sv0)
		var main := await _boot(sv0)
		_stay_lit(main)
		await _done(main)
		main = await _boot(sv0)
		_trespass(main)
		await _done(main)
	if want.call("exit"):
		print("== seed %d: a state's own end, and the way out" % sv0)
		var main := await _boot(sv0)
		_ends_itself(main)
		_gate(main)
		await _done(main)
	for id in ["test_a", "test_b", "test_c", "test_idle", "test_stay", "test_gate", "test_never", "test_strike", "test_trespass", "test_done"]:
		BossPool.unregister(id)
	Boss.pool_off = false
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


func _done(main: CrawlerMain) -> void:
	main.queue_free()
	await process_frame


## A test pool from {id: [weight, dwell min, dwell max]} under the data's rule.
func _test_pool(spec: Dictionary, label := "test") -> BossPool:
	var states := {}
	for id in spec:
		var v: Array = spec[id]
		states[id] = {"weight": v[0], "dwell_s": [v[1], v[2]]}
	return BossPool.from_dict(states, BossPool.RULE, label)


# --- 1. The draw ------------------------------------------------------------------

func _draws() -> void:
	var w := {"test_a": 1.0, "test_b": 2.0, "test_c": 3.0}
	var dw := {"test_a": [1.0, 2.0], "test_b": [3.0, 5.0], "test_c": [6.0, 9.0]}
	var spec := {}
	for id in w:
		spec[id] = [w[id], dw[id][0], dw[id][1]]
	var pool := _test_pool(spec)
	ok(pool.ids.size() == 3 and pool.skipped.is_empty() and int(BossPool.RULE.get("repeat_gap", 1)) == pool.repeat_gap, "a test pool of three registered states (%s; one a Script, one a Callable), repeat_gap %d from the rule" % [str(pool.ids), pool.repeat_gap])
	var seq: Array = []
	var dwells_ok := true
	var dwells := {}
	for i in 200:
		var id := pool.draw()
		seq.append(id)
		var d := pool.dwell(id)
		dwells[snappedf(d, 0.001)] = true
		if d < float(dw[id][0]) - 1e-6 or d > float(dw[id][1]) + 1e-6:
			dwells_ok = false
	var repeats := 0
	for i in range(1, seq.size()):
		if seq[i] == seq[i - 1]:
			repeats += 1
	var period := -1
	for p in range(1, 21):
		var same := true
		for i in range(seq.size() - p):
			if seq[i] != seq[i + p]:
				same = false
				break
		if same:
			period = p
			break
	var pool2 := _test_pool(spec)
	var seq2: Array = []
	for i in 200:
		seq2.append(pool2.draw())
	ok(period < 0 and seq2 != seq, "200 draws are no fixed sequence: no period of 20 draws or fewer, and a second pool's 200 differ (live dice, not the game seed) (%s...)" % _short_seq(seq, 24))
	ok(repeats == 0, "no state twice running over 200 draws (%d repeats)" % repeats)
	var counts := _counts(seq)
	ok(counts.size() == 3, "every state drawn: %s" % str(counts))
	var expect := _expected(w)
	var worst := 0.0
	for id in w:
		worst = maxf(worst, absf(float(counts.get(id, 0)) / 200.0 - float(expect[id])))
	ok(worst <= 0.1, "the draws follow the weights 1:2:3 within 0.1 over 200 (shares %s against %s under no-repeat, w(W-w); worst off %.3f)" % [_shares(counts, 200), _fmt_shares(expect), worst])
	var big: Array = []
	for i in 20000:
		big.append(pool.draw())
	var bc := _counts(big)
	var worst_big := 0.0
	for id in w:
		worst_big = maxf(worst_big, absf(float(bc.get(id, 0)) / 20000.0 - float(expect[id])))
	ok(worst_big <= 0.02, "over 20,000 draws within 0.02 (shares %s; worst off %.4f)" % [_shares(bc, 20000), worst_big])
	ok(dwells_ok and dwells.size() > 100, "each dwell inside its state's dwell_s [min, max] (%d different over 200)" % dwells.size())
	var one := _test_pool({"test_a": [1.0, 2.0, 3.0]})
	var all_a := true
	for i in 50:
		if one.draw() != "test_a":
			all_a = false
	ok(all_a, "a pool of one state draws it every time (the only one may come twice running)")
	var never_c := true
	for i in 300:
		if pool.draw(func(id: String) -> bool: return id != "test_c") == "test_c":
			never_c = false
	var none := pool.draw(func(_id: String) -> bool: return false)
	var with_never := _test_pool({"test_a": [1.0, 1.0, 2.0], "test_never": [100.0, 1.0, 2.0]})
	var never_drawn := 0
	for i in 200:
		var id := with_never.draw(func(i_d: String) -> bool: return with_never.unit(i_d).can_enter(null))
		if id == "test_never":
			never_drawn += 1
	ok(never_c and none == "" and never_drawn == 0, "a state that can't come now is never drawn (300 draws without test_c; a state whose needs never hold, weight 100, %d of 200), and with none that can the draw is \"%s\"" % [never_drawn, none])
	var fixed := BossPool.RULE.duplicate(true)
	fixed["live_rng"] = false
	var states := {}
	for id in spec:
		states[id] = {"weight": spec[id][0], "dwell_s": [spec[id][1], spec[id][2]]}
	var s1 := BossPool.from_dict(states, fixed, "desert", 7)
	var s2 := BossPool.from_dict(states, fixed, "desert", 7)
	var s3 := BossPool.from_dict(states, fixed, "desert", 8)
	var q1: Array = []
	var q2: Array = []
	var q3: Array = []
	for i in 100:
		q1.append(s1.draw())
		q2.append(s2.draw())
		q3.append(s3.draw())
	ok(bool(BossPool.RULE.get("live_rng", true)) and q1 == q2 and q1 != q3, "rule.live_rng is %s (as played: live dice); set false, the same game seed draws the same 100, another seed not" % str(BossPool.RULE.get("live_rng", true)))


func _counts(seq: Array) -> Dictionary:
	var c := {}
	for id in seq:
		c[id] = int(c.get(id, 0)) + 1
	return c


## Each state's share of the draws under "never twice running": w(W - w)
## over the sum of them.
func _expected(w: Dictionary) -> Dictionary:
	var total := 0.0
	for id in w:
		total += float(w[id])
	var raw := {}
	var s := 0.0
	for id in w:
		raw[id] = float(w[id]) * (total - float(w[id]))
		s += float(raw[id])
	var out := {}
	for id in w:
		out[id] = float(raw[id]) / s
	return out


func _shares(c: Dictionary, n: int) -> String:
	var parts: Array = []
	for id in ["test_a", "test_b", "test_c"]:
		parts.append("%s %.3f" % [str(id).trim_prefix("test_"), float(c.get(id, 0)) / n])
	return ", ".join(parts)


func _fmt_shares(e: Dictionary) -> String:
	var parts: Array = []
	for id in ["test_a", "test_b", "test_c"]:
		parts.append("%s %.3f" % [str(id).trim_prefix("test_"), float(e[id])])
	return ", ".join(parts)


func _short_seq(seq: Array, n: int) -> String:
	var parts: Array = []
	for i in mini(n, seq.size()):
		parts.append(str(seq[i]).trim_prefix("test_"))
	return "".join(parts)


# --- 2. Unknown ids -----------------------------------------------------------------

func _unknown() -> void:
	var bad := "no_such_state_q65"
	var before := BossPool.warned.has(bad)
	var states := {"rounds": {"weight": 1, "dwell_s": [20, 50]}, bad: {"weight": 5, "dwell_s": [1, 2]}, "test_a": "not an entry"}
	var p1 := BossPool.from_dict(states, BossPool.RULE, "unknown_test")
	var once := int(BossPool.warned.get(bad, 0))
	var p2 := BossPool.from_dict(states, BossPool.RULE, "unknown_test")
	var twice := int(BossPool.warned.get(bad, 0))
	var drawn_bad := 0
	for i in 300:
		if p1.draw() == bad or p2.draw() == bad:
			drawn_bad += 1
	ok(not before and once == 1 and twice == 1 and p1.skipped.size() == 1 and p1.skipped[0] == bad and p1.ids.size() == 1 and p1.ids[0] == "rounds" and drawn_bad == 0, "a state no code registers ('%s'): one warning (%d after one load, %d after two), skipped (live %s, skipped %s), never drawn in 600 draws, no crash" % [bad, once, twice, str(p1.ids), str(p1.skipped)])
	ok(not p1.has_state("test_a") and BossPool.warned.has("test_a"), "an entry that is not one ('test_a': a string) is skipped with a warning")
	var lone := BossPool.from_dict({bad: {"weight": 1, "dwell_s": [1, 2]}}, BossPool.RULE, "lone_test")
	ok(lone.only_rounds(), "a pool of nothing registered is its built behaviour: %s" % str(lone.ids))
	ok(BossPool.is_registered("rounds") and BossPool._script_for("rounds") != null and BossPool.make_unit("rounds").built(), "'rounds' is found by its file, %srounds.gd (the built behaviour)" % BossPool.STATES_DIR)
	var pools: Dictionary = BossPool.DATA.get("pools", {})
	var bosses: Dictionary = Boss.B.get("bosses", {})
	var rows: Array = []
	var all_ok := true
	var only_rounds: Array = []
	var not_wired: Array = []
	for bid in pools:
		var p := BossPool.for_boss(str(bid))
		var listed: Dictionary = pools[bid]
		for id in listed:
			if not BossPool.is_registered(str(id)):
				not_wired.append("%s.%s" % [bid, id])
				if not (str(id) in p.skipped) or int(BossPool.warned.get(str(id), 0)) != 1:
					all_ok = false
		if not bosses.has(bid):
			all_ok = false
		rows.append("%s %s" % [bid, str(p.ids)])
		if p.only_rounds():
			var just := true
			for i in 50:
				var id := p.draw()
				var d := p.dwell(id)
				if id != "rounds" or d < 20.0 - 1e-6 or d > 50.0 + 1e-6:
					just = false
			if not just:
				all_ok = false
			only_rounds.append(str(bid))
	print("  live pools: %s" % "; ".join(rows))
	ok(all_ok and pools.size() == bosses.size(), "boss_pool.json: a pool for each of the %d bosses in bosses.json; the ids no code registers yet skipped with one warning each (%s); with only 'rounds' (%s) nothing else is drawn, each for 20-50 s" % [bosses.size(), ", ".join(not_wired) if not not_wired.is_empty() else "none", ", ".join(only_rounds)])


# --- 3. The same route ------------------------------------------------------------

## Light holder `h` (as the boss check does).
func _light_holder(main: CrawlerMain, h: Node3D) -> void:
	FireStore.swing_light(h, float(main.world.get("days")))
	for i in 600:
		FireStore.tick(self, 1.0 / 60.0, h.global_position)
		if FireStore.is_lit(h):
			return


## The holders of the node it is in (a room's torches, a stretch's sconces),
## lit; with none there, the first three cold ones.
func _light_round(main: CrawlerMain) -> int:
	var b := main.boss
	var fires := main.fires
	var idx: Array = []
	if b.node >= 0:
		var n: Dictionary = b.ground.nodes[b.node]
		for h in n.holders:
			idx.append(int(h))
		for e in n.ends:
			if str(e.type) == "sconce":
				idx.append(int(e.holder))
	if idx.is_empty():
		for k in fires.holders.size():
			if not FireStore.is_lit(fires.holders[k]):
				idx.append(k)
				if idx.size() >= 3:
					break
	for k in idx:
		_light_holder(main, fires.holders[k])
	return idx.size()


## The snake loose ROUTE_S from where the boot left it, you at the wake spot:
## at 40 s and 80 s the holders round it relit, at 110 s a fire pot drives
## it off for 15 s. Its place (base) and its state every third frame.
func _route(main: CrawlerMain) -> Dictionary:
	var b := main.boss
	var p := main.player
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), 0.0)
	await physics_frame
	var pts := PackedVector3Array()
	var states := PackedStringArray()
	var seen := {}
	var t := 0.0
	var i := 0
	var lit := 0
	var potted := false
	while t < ROUTE_S:
		if (i == int(40.0 / DT) or i == int(80.0 / DT)):
			lit += _light_round(main)
		if i == int(110.0 / DT) and not potted:
			potted = true
			b.drive_off(15.0, b.head)
		b.tick(DT)
		main.harm.tick(DT)
		t += DT
		i += 1
		seen[b.state] = true
		if i % 3 == 0:
			pts.append(b.base)
			states.append(b.state)
	return {"pts": pts, "states": states, "seen": seen.keys(), "lit": lit, "draws": b.pool.draws if b.pool != null else 0, "transits": b.transits, "driven": b.driven}


## Where two routes part: {"first": the first frame they differ (-1: never), "worst": the farthest apart (m)}.
func _compare(a: Dictionary, b: Dictionary) -> Dictionary:
	var pa: PackedVector3Array = a.pts
	var pb: PackedVector3Array = b.pts
	var sa: PackedStringArray = a.states
	var sb: PackedStringArray = b.states
	var first := -1
	var worst := 0.0
	if pa.size() != pb.size():
		first = mini(pa.size(), pb.size())
	for k in mini(pa.size(), pb.size()):
		var d := pa[k].distance_to(pb[k])
		worst = maxf(worst, d)
		if first < 0 and (d > 1e-6 or sa[k] != sb[k]):
			first = k
	if first >= 0 and first < mini(pa.size(), pb.size()):
		print("  the routes part at frame %d (%.1f s): %s at %s against %s at %s" % [first, (first + 1) * 3 * DT, sa[first], str(pa[first]), sb[first], str(pb[first])])
	return {"first": first, "worst": worst}


func _routes(sv: int) -> void:
	Boss.pool_off = true
	var main := await _boot(sv)
	ok(main.boss.pool == null, "no pool at all (Boss.pool_off): the boss as built before queue 65")
	var off := await _route(main)
	await _done(main)
	Boss.pool_off = false
	print("  with no pool: %d frames kept, states %s, %d holders relit, %d tunnel transits, driven off %d" % [(off.pts as PackedVector3Array).size(), str(off.seen), int(off.lit), int(off.transits), int(off.driven)])
	ok((off.seen as Array).has("prowl") and (off.seen as Array).has("coil") and int(off.driven) == 1, "the run takes it through its rounds, the light and a pot (states %s)" % str(off.seen))
	main = await _boot(sv)
	var data_pool := main.boss.pool
	var boss_key := main.boss.key
	var rounds_only := data_pool != null and data_pool.only_rounds()
	var data_run := await _route(main)
	await _done(main)
	var c1 := _compare(off, data_run)
	if rounds_only:
		ok(int(c1.first) < 0, "its pool from boss_pool.json (%s, live %s): the same route, every one of %d frames (the farthest apart %.6f m; %d draws)" % [boss_key, str(data_pool.ids), (off.pts as PackedVector3Array).size(), float(c1.worst), int(data_run.draws)])
	else:
		print("  its pool from boss_pool.json has more than 'rounds' (%s): its route is its own by design (parts at frame %d); compared with 'rounds' alone below" % [str(data_pool.ids if data_pool != null else []), int(c1.first)])
	main = await _boot(sv)
	main.boss.set_pool(_test_pool({"rounds": [1.0, 0.1, 0.4]}, "rounds_fast"))
	var fast := await _route(main)
	await _done(main)
	var c2 := _compare(off, fast)
	ok(int(c2.first) < 0 and int(fast.draws) > 200, "a pool of 'rounds' alone asked every 0.1-0.4 s (%d draws): the same route, every one of %d frames (the farthest apart %.6f m)" % [int(fast.draws), (off.pts as PackedVector3Array).size(), float(c2.worst)])


# --- 4. Never mid-strike ------------------------------------------------------------

## Step the snake (and Harm) `secs` s, or until `stop` says.
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


## A spot in the snake's own dark `d` m from its head (the boss check's
## _beside): in its node or the next, on open floor, nothing between.
func _beside(b: Boss, d: float) -> Vector3:
	for k in 16:
		var a := TAU * k / 16.0
		var q := b.head + Vector3(cos(a), 0.0, sin(a)) * d
		q.y = b._floor_y(q)
		var l: Dictionary = b.lay.get("lair", {})
		if not l.is_empty() and Vector2(q.x - (l.pos as Vector3).x, q.z - (l.pos as Vector3).z).length() < float(l.r) + 0.6:
			continue
		if b._blocked(b._eye(), q + Vector3(0, 1.3, 0), false):
			continue
		var id := b.ground.node_at(q)
		if id >= 0 and b.ground.is_ground(id) and (id == b.node or not b.ground.link(id, b.node).is_empty()) and not b._blocked(b.head + Vector3(0, 0.6, 0), q + Vector3(0, 0.6, 0), false):
			var pc: Dictionary = b.lay.pieces[int(b.ground.nodes[id].piece)]
			var aa := Delves.along_across(pc, Vector2(q.x, q.z))
			if aa.x > 0.4 and aa.x < float(pc.len) - 0.4 and absf(aa.y) < float(pc.half) - 0.45:
				return q
	return Vector3.INF


## The snake laid coiled in its far dead end again (a harness's placing).
func _relay(main: CrawlerMain) -> void:
	var b := main.boss
	b._let_go("check")
	b._calm()
	b._start_far()


## The draws logged since the log was `n0` long (Boss.draw_log, its last
## Boss.DRAW_LOG kept), and those that came in one of the rule's moments,
## its strike under way or in its tunnels: [draws, [bad...]].
func _draws_since(b: Boss, n0: int) -> Array:
	var bad: Array = []
	for i in range(mini(n0, b.draw_log.size()), b.draw_log.size()):
		var e: Dictionary = b.draw_log[i]
		if str(e.state) in Boss.RULE_MOMENTS or str(e.strike) != "ready" or bool(e.tunnel):
			bad.append("%s/%s" % [e.state, e.strike])
	return [b.draw_log.size() - n0, bad]


func _strike(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var t := p.torch
	_relay(main)
	b.set_pool(_test_pool({"rounds": [1.0, 0.05, 0.1], "test_idle": [1.0, 0.05, 0.1]}, "busy"))
	var pre0 := b.draw_log.size()
	_sim(main, 0.5)
	var pre := b.draw_log.size() - pre0
	var spot := _beside(b, 3.0)
	ok(spot != Vector3.INF, "a spot in its dark 3 m from it (coiled in node %d)" % b.node)
	if spot == Vector3.INF:
		return
	p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	t.light()
	_place(p, spot, b.head)
	await physics_frame
	var d0 := b.draw_log.size()
	var during_rule := 0
	var states_seen := {}
	var hold_from := -1.0
	var hold_until := -1.0
	var clock := 0.0
	var landed0 := main.harm.landed
	var wind0 := b.strike.wind_ups
	var busy_draws := 0
	while clock < 40.0 and not main.harm.taking:
		var n_before := b.pool.draws
		var moment := b.rule_moment()
		var strike_busy := b.strike.busy()
		_sim(main, DT)
		clock += DT
		states_seen[b.state] = true
		if b.state == "hang" and hold_from < 0.0:
			hold_from = clock
		if hold_from >= 0.0 and hold_until < 0.0 and b.state in ["hunt", "strike"]:
			hold_until = clock
		# A draw this tick, with it in one of the rule's moments as the tick began.
		if b.pool.draws > n_before and (moment or strike_busy):
			during_rule += 1
		if strike_busy and b.pool.draws > n_before:
			busy_draws += 1
	_sim(main, DT)
	var r := _draws_since(b, d0)
	var whole_log := b.draw_log.size() < Boss.DRAW_LOG
	var delay := b.sub("torch_delay")
	var hits := main.harm.landed - landed0
	ok(hold_from >= 0.0 and hold_until - hold_from >= float(delay.get("hang_s", 4.0)) - 0.1 and hits == 3 and b.strike.wind_ups - wind0 >= 3 and main.harm.taking and b.state == "held", "your torch lit beside it, its pool changing state every tenth of a second: it holds at your flame %.1f s (hang_s %.1f), winds up %d times, three hits, and you are taken (%s)" % [hold_until - hold_from, float(delay.get("hang_s", 4.0)), b.strike.wind_ups - wind0, b.state])
	ok(whole_log and pre > 0 and (r[1] as Array).is_empty() and during_rule == 0 and busy_draws == 0, "no draw in the rule's moments: %d draws in the half second it lay coiled alone and %d more before it found you, none while it hunted you, held at your flame, struck (wind-up, lunge, draw back) or held you taken (%d in a moment, %d with its strike under way; states %s)" % [pre, int(r[0]), during_rule, busy_draws, str(states_seen.keys())])
	# You wake; it goes on its rounds, and the pool with it.
	_sim(main, Harm.taken_s() + 0.5, func(): return not main.harm.taking)
	await process_frame
	var d1 := b.pool.draws
	_sim(main, 2.0)
	ok(not main.harm.taking and b.pool.draws > d1 and int(b.states_ended.rule) > 0, "you wake by the hearth and the pool goes on (%d draws in 2 s; states ended by the rule's moments %d)" % [b.pool.draws - d1, int(b.states_ended.rule)])
	# A state that strikes: your torch out (the breath after waking first).
	for i in 200:
		await physics_frame
	main.harm.reset()
	_relay(main)
	var strike_state := StrikeState.new()
	BossPool.register("test_strike", func() -> BossState: return strike_state)
	b.set_pool(_test_pool({"test_strike": [1.0, 0.05, 0.1], "test_idle": [1.0, 0.05, 0.1]}, "striker"))
	var spot2 := _beside(b, 1.5)
	if spot2 == Vector3.INF:
		ok(false, "a spot 1.5 m from it for a state's strike")
		return
	p.weapon = "hands"
	if t.lit():
		t.put_out("check")
	p._invulnerable = 0.0
	_place(p, spot2, b.head)
	await physics_frame
	var w0 := b.strike.wind_ups
	var rule0 := int(b.states_ended.rule)
	var began_at := -1.0
	var committed_at := -1.0
	var recover_seen := false
	var ready_at := -1.0
	var tell_ok := false
	var draws_in := 0
	var c3 := 0.0
	while c3 < 6.0 and ready_at < 0.0:
		var n_before := b.pool.draws
		var was_busy := b.strike.busy()
		_sim(main, DT)
		c3 += DT
		if began_at < 0.0 and b.strike.wind_ups > w0:
			began_at = c3
			tell_ok = b.strike.sound != "" and b.strike.tell_frame == b.strike.wind_up_frame and b.strike.state == "wind_up"
		if began_at >= 0.0 and committed_at < 0.0 and b.strike.state == "strike":
			committed_at = c3
		if committed_at >= 0.0 and b.strike.state == "recover":
			recover_seen = true
		# Done drawing back (ready, or straight into its next wind-up).
		if recover_seen and ready_at < 0.0 and b.strike.state != "recover":
			ready_at = c3
		# A draw on a tick that began with its strike under way.
		if was_busy and b.pool.draws > n_before:
			draws_in += 1
	var wind := committed_at - began_at
	ok(strike_state.calls > 0 and strike_state.began and began_at >= 0.0 and tell_ok and wind >= b.strike.wind_up_s - DT * 1.5, "a state that strikes (Boss.begin_strike), your torch out: the strike as built, its wind-up with its tell (%s) from its first frame, %.2f s before the lunge (wind_up_s %.2f)" % [b.strike.sound, wind, b.strike.wind_up_s])
	ok(int(b.states_ended.rule) > rule0 and draws_in == 0 and ready_at > committed_at, "the state was over as its strike began, and no draw came till the strike was done (wind-up, lunge, %.2f s drawing back; %d draws in it)" % [ready_at - committed_at, draws_in])
	# Your torch lit: your flame holds it first.
	main.harm.reset()
	_relay(main)
	var held_state := StrikeState.new()
	BossPool.register("test_strike", func() -> BossState: return held_state)
	b.set_pool(_test_pool({"test_strike": [1.0, 0.05, 0.1], "test_idle": [1.0, 0.05, 0.1]}, "striker_lit"))
	var spot3 := _beside(b, 3.0)
	if spot3 == Vector3.INF:
		ok(false, "a spot 3 m from it for a state's strike at your flame")
		return
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	t.light()
	p._invulnerable = 0.0
	_place(p, spot3, b.head)
	await physics_frame
	var w1 := b.strike.wind_ups
	var first_wind := -1.0
	var hung := false
	var c4 := 0.0
	while c4 < 12.0 and first_wind < 0.0:
		_sim(main, DT)
		c4 += DT
		if b.state == "hang":
			hung = true
		if b.strike.wind_ups > w1:
			first_wind = b.clock
	var hang_s := float(delay.get("hang_s", 4.0))
	ok(t.lit() and held_state.calls > 0 and not held_state.began and hung and first_wind - held_state.called_at >= hang_s - 0.1, "a state that strikes, your torch lit: your flame holds it first (the hold as built), its wind-up %.1f s after the state asked (hang_s %.1f)" % [first_wind - held_state.called_at, hang_s])
	main.harm.reset()
	if t.lit():
		t.put_out("check")
	p.weapon = "hands"
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), 0.0)
	await physics_frame
	_relay(main)


# --- 5. The pot ------------------------------------------------------------------

func _pot(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), 0.0)
	main.harm.reset()
	_relay(main)
	b.set_pool(_test_pool({"rounds": [1.0, 0.05, 0.1], "test_idle": [1.0, 0.05, 0.1]}, "busy_pot"))
	_sim(main, 1.0)
	var rule0 := int(b.states_ended.rule)
	var had := b.behaviour
	b.drive_off(8.0, b.head)
	var away := ["stunned", "flee", "den", "rise"]
	var seen := {}
	var bad := 0
	var t := 0.0
	while t < 150.0 and (b.state in away or t == 0.0):
		var n_before := b.pool.draws
		var was := b.state
		_sim(main, DT)
		t += DT
		seen[was] = true
		if b.pool.draws > n_before and (was in away or b.state in away):
			bad += 1
	var back := b.state
	var d1 := b.pool.draws
	_sim(main, 2.0)
	ok(had != "" and int(b.states_ended.rule) > rule0 and seen.has("stunned") and seen.has("flee") and seen.has("den") and seen.has("rise") and bad == 0, "a fire pot: the state in charge (%s) over at once, and no draw while it lay stunned, fled to its hole, lay down it and rose (%s, %.1f s; %d draws in it)" % [had, str(seen.keys()), t, bad])
	ok(not back in away and b.pool.draws > d1, "back on its rounds (%s), the pool is asked again (%d draws in 2 s)" % [back, b.pool.draws - d1])


# --- 6. The last light ------------------------------------------------------------

func _release(main: CrawlerMain) -> void:
	var b := main.boss
	var fires := main.fires
	b.set_pool(_test_pool({"rounds": [1.0, 0.05, 0.1], "test_idle": [1.0, 0.05, 0.1]}, "busy_release"))
	_sim(main, 1.0)
	for h in fires.holders:
		if not FireStore.is_lit(h):
			_light_holder(main, h)
	var d0 := b.pool.draws
	var seen := {}
	var t := 0.0
	while t < 200.0 and b.state != "lair" and b.state != "gone":
		_sim(main, DT)
		t += DT
		seen[b.state] = true
	var d_home := b.pool.draws
	_sim(main, 3.0)
	ok(b.released and b.state in ["lair", "gone"] and b.pool.draws == d0 and d_home == d0 and b.behaviour == "", "the last light: it went home (%s, %.1f s; %s) and no draw came from the moment it went, nor in its hole (%d draws)" % [b.state, t, str(seen.keys()), b.pool.draws - d0])


# --- 7. The light ------------------------------------------------------------------

## A dark room with torches of its own, the farthest from the hearth room
## (its node), else -1.
func _dark_room_with_torches(b: Boss) -> int:
	var best := -1
	var best_d := -INF
	var dist := b._all_dist(b._hearth_node())
	for id in dist:
		var n: Dictionary = b.ground.nodes[int(id)]
		if str(n.kind) != "room" or not b.ground.is_ground(int(id)) or (n.holders as Array).is_empty():
			continue
		if float(dist[id]) > best_d:
			best_d = float(dist[id])
			best = int(id)
	return best


## The snake laid in node `id` (a harness's placing): coiled in a room,
## along a corridor's stretch.
func _lie_in(main: CrawlerMain, id: int) -> void:
	var b := main.boss
	b._let_go("check")
	b._calm()
	if str(b.ground.nodes[id].kind) == "room":
		b._lie_coiled(id)
	else:
		b._lie_along(id)
	b.coil_left = 999.0
	b._pose()


func _stay_lit(main: CrawlerMain) -> void:
	var b := main.boss
	var room := _dark_room_with_torches(b)
	ok(room >= 0, "a dark room with torches of its own for it to lie in (node %d)" % room)
	if room < 0:
		return
	_lie_in(main, room)
	var stay := StayState.new()
	BossPool.register("test_stay", func() -> BossState: return stay)
	b.set_pool(_test_pool({"test_stay": [1.0, 999.0, 999.0]}, "stay"))
	_sim(main, 0.5)
	# A light catching elsewhere: the state hears of it and goes on.
	var far := -1
	for k in main.fires.holders.size():
		var h: Dictionary = main.lay.holders[k]
		if int(h.piece) != int(b.ground.nodes[room].piece) and not FireStore.is_lit(main.fires.holders[k]) and Vector2((h.pos as Vector3).x - b.base.x, (h.pos as Vector3).z - b.base.z).length() > 15.0:
			far = k
			break
	if far >= 0:
		_light_holder(main, main.fires.holders[far])
	_sim(main, 0.2)
	ok(far >= 0 and stay.lights == 1 and b.behaviour == "test_stay" and b.state == "coil", "a light catching elsewhere (holder %d): the state in charge hears of it (%d) and goes on (%s)" % [far, stay.lights, b.behaviour])
	var was := b.behaviour
	var light0 := int(b.states_ended.light)
	for h in b.ground.nodes[room].holders:
		_light_holder(main, main.fires.holders[int(h)])
	_sim(main, DT)
	var ended := b.behaviour == "" and int(b.states_ended.light) == light0 + 1 and b.state == "leave"
	var state_then := b.state
	var t := 0.0
	while t < LEAVE_MOST_S and not (b.node >= 0 and b.ground.is_ground(b.node) and not b._in_tunnel()):
		_sim(main, DT)
		t += DT
	var out_at := t
	# Its leaving done (it goes on to its way's end in the dark), the pool
	# draws again.
	_sim(main, 15.0, func() -> bool: return b.behaviour != "")
	ok(was == "test_stay" and ended, "a state that lies still in a room relit round it (%s) is over on the next tick, and it leaves for the dark as built (%s)" % [was, state_then])
	ok(out_at < LEAVE_MOST_S and b.behaviour == "test_stay" and b.ground.is_ground(b.node), "it is back in the dark %.1f s later (%.0f s at most), and the state is drawn again there (%s, node %d dark)" % [out_at, LEAVE_MOST_S, b.behaviour, b.node])


func _trespass(main: CrawlerMain) -> void:
	var b := main.boss
	var hearth := b._hearth_node()
	var next := -1
	for l in b.ground.nodes[hearth].links:
		if b.ground.is_ground(int(l.to)) and not l.has("tunnel"):
			next = int(l.to)
			break
	ok(next >= 0, "a dark node next to the hearth room for it to lie in (node %d)" % next)
	if next < 0:
		return
	_lie_in(main, next)
	var tres := TrespassState.new()
	tres.goal = hearth
	BossPool.register("test_trespass", func() -> BossState: return tres)
	b.set_pool(_test_pool({"test_trespass": [1.0, 999.0, 999.0]}, "trespass"))
	var e0 := b.lit_entries
	var l0 := int(b.states_ended.light)
	var entered_at := -1
	var ended_at := -1
	var state_then := ""
	var k := 0
	while k < int(30.0 / DT) and ended_at < 0:
		b.tick(DT)
		main.harm.tick(DT)
		k += 1
		if entered_at < 0 and b.lit_entries > e0:
			entered_at = k
		if int(b.states_ended.light) > l0:
			ended_at = k
			state_then = b.state
	var t := 0.0
	while t < LEAVE_MOST_S and not (b.node >= 0 and b.ground.is_ground(b.node)):
		_sim(main, DT)
		t += DT
	ok(entered_at > 0 and ended_at == entered_at and state_then == "leave", "a state that walks it into the light (the hearth room) is over on the tick it goes in (in at tick %d, over at %d), and it leaves (%s)" % [entered_at, ended_at, state_then])
	ok(t < LEAVE_MOST_S, "back in the dark %.1f s later (%.0f s at most)" % [t, LEAVE_MOST_S])


# --- 8. A state's own end, and the way out ------------------------------------------

## A state that ends itself (BossState.done, Boss.end_state) long before its
## dwell: the next is drawn on the next free tick; 'rounds' coming in after
## a state that left it in one of its own takes it back on its rounds
## (Boss.resume_rounds); with no state that may come, its built behaviour
## and the pool asked again every Boss.POOL_RETRY_S.
func _ends_itself(main: CrawlerMain) -> void:
	var b := main.boss
	_relay(main)
	var done_state := DoneState.new()
	BossPool.register("test_done", func() -> BossState: return done_state)
	var p := _test_pool({"test_done": [1.0, 999.0, 999.0], "rounds": [1.0, 999.0, 999.0]}, "ends_itself")
	b.set_pool(p)
	# Its first draw test_done (as though rounds had just been).
	p.recent.append("rounds")
	var done0 := int(b.states_ended.done)
	_sim(main, 0.1)
	var first := b.behaviour
	var stare := b.state
	var t := _sim(main, 3.0, func() -> bool: return b.behaviour == "rounds")
	var at := b.base
	_sim(main, 3.0)
	ok(first == "test_done" and stare == "stare" and b.behaviour == "rounds" and int(b.states_ended.done) == done0 + 1 and t < 0.6, "a state that ends itself (after 0.3 s, its dwell 999 s): the next drawn at once, %.2f s in ('%s' after '%s')" % [t + 0.1, b.behaviour, first])
	ok(b.state in ["prowl", "coil"] and (b.state == "coil" or b.base.distance_to(at) > 1.0), "'rounds' after a state that left it in one of its own ('stare'): back on its rounds (%s, %.1f m on in 3 s)" % [b.state, b.base.distance_to(at)])
	# Coiled in its far dead end again (out of its tunnels: the pool waits
	# while it is in one), then a pool of nothing that may come.
	_relay(main)
	b.set_pool(_test_pool({"test_never": [1.0, 1.0, 2.0]}, "none_may_come"))
	var n0 := b.draw_log.size()
	var left0 := b.coil_left
	_sim(main, 3.5)
	var empties := 0
	for i in range(n0, b.draw_log.size()):
		if str(b.draw_log[i].id) == "":
			empties += 1
	ok(empties >= 3 and empties <= 5 and b.draw_log.size() - n0 == empties and b.behaviour == "" and b.state == "coil" and b.coil_left < left0 - 3.0, "with no state that may come: its built rounds meanwhile (%s, its coil %.1f s on), the pool asked again every %.0f s (%d times in 3.5 s)" % [b.state, left0 - b.coil_left, Boss.POOL_RETRY_S, empties])
	_relay(main)


func _gate(main: CrawlerMain) -> void:
	var b := main.boss
	var exits: Array = main.lay.get("exits", [])
	var stair := -1
	if not exits.is_empty():
		var ids: Array = b.ground.by_piece.get(int(exits[0].stair), [])
		if not ids.is_empty():
			stair = int(ids[0])
	ok(stair >= 0 and b.ground.is_ground(stair), "the way out's flight up, dark (node %d)" % stair)
	if stair < 0:
		return
	_lie_in(main, stair)
	ok(b.on_way_out(b.base), "laid along the flight up: on the way out")
	b.set_pool(_test_pool({"test_gate": [1.0, 999.0, 999.0]}, "gate"))
	var e0 := int(b.states_ended.exit)
	var drawn_at := -1.0
	var tripped_at := -1.0
	var still_on := 0.0
	var redrawn_on := 0
	var t := 0.0
	var off_at := -1.0
	while t < 40.0:
		var n_before := b.pool.draws
		_sim(main, DT)
		t += DT
		if drawn_at < 0.0 and b.behaviour == "test_gate":
			drawn_at = t
		if tripped_at < 0.0 and int(b.states_ended.exit) > e0:
			tripped_at = t
		if b.behaviour == "test_gate" and b.on_way_out(b.base):
			still_on += DT
		if tripped_at >= 0.0 and b.pool.draws > n_before and b.on_way_out(b.base):
			redrawn_on += 1
		if tripped_at >= 0.0 and off_at < 0.0 and not b.on_way_out(b.base):
			off_at = t
		if off_at >= 0.0 and b.behaviour == "test_gate" and t > off_at + 1.0:
			break
	var waited := tripped_at - drawn_at
	ok(drawn_at >= 0.0 and tripped_at > 0.0 and waited >= Boss.EXIT_WAIT_S - DT * 1.5 and waited <= Boss.EXIT_WAIT_S + DT * 2.5 and int(b.states_ended.exit) == e0 + 1, "a state that keeps it still on the way out is over after %.2f s (Boss.EXIT_WAIT_S %.1f), once" % [waited, Boss.EXIT_WAIT_S])
	ok(off_at > 0.0 and redrawn_on == 0 and b.behaviour == "test_gate" and not b.on_way_out(b.base) and still_on <= Boss.EXIT_WAIT_S + DT * 2.5, "it goes on its rounds off the way out (off %.1f s after), and the state is drawn again only off it (%d draws on it; %.2f s in all a state kept it there)" % [off_at - tripped_at, redrawn_on, still_on])
