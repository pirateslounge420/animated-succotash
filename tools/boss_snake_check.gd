extends SceneTree
## The snake's pool (design 9 Oct §FM.2, Mike's four; queue 66; BossStalk,
## scripts/crawler/boss_states/, Boss; data/boss_pool.json pools.desert and
## camouflage), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/boss_snake_check.gd
## SNAKE_SEEDS="7,1" (the default: the parts run on the first, the loose run
## on each); SNAKE_ONLY="pool,draws,freeze,doorway,observe,ambush,loose"
## runs some parts only. Asserts:
##  1. the pool: boss_pool.json's desert pool is 'rounds' and the four, each
##     found by its file (none skipped), the freeze the one that may cut in;
##     every other boss still 'rounds' alone; hunt_mps is still 4.6;
##  2. 300 draws, each from the same place (the snake laid in its dark again
##     before each, you about 14 m off looking at it, your torch lit): all
##     four new states and 'rounds' are entered, never the same one twice
##     running;
##  3. freeze_watched: it never starts with you inside from_m[0], with none
##     of it inside look_deg of your view, unlit, or in a room you have lit;
##     looking at it from about 14 m in your torch's light it stops dead (it
##     cuts in), and when it starts its head (or a length of its body) is
##     inside look_deg and all of it beyond from_m[0]; frozen, it doesn't
##     move and is silent; its sprites' blend (sampled off their material
##     every tick) eases to its blend and never past camouflage.max_blend,
##     even asked for 0.9 and 0.95, never transparent (their alpha and
##     transparency untouched; the tint sampled on its paint is never the
##     stone's), and eases back after; it holds while you come up to just
##     outside close_m of any of it and ends on the tick you come inside,
##     ends when you have looked away look_away_s, and when its dwell runs
##     out, with no tell (no hiss, no wind-up); weighed against the state in
##     charge (2 against 2), it cuts in about half the times you first catch
##     sight of it;
##  4. doorway_watch: the nearest doorway of an unlit room on its rounds
##     that you are not in (none onto the way out, out of the tomb, into the
##     hearth room, off its floor or through a seal: never the stair down's,
##     §FM.6); it gets there by its dark, never into the light, and lies
##     still with its head as drawn in the gap, in that unlit room; light the
##     room and it is over on that tick and it leaves for the dark (back in
##     it within 12 s); come into the room and the watch is over; a room
##     lit across its way there, it goes round by another dark way or the
##     watch is over, never on into the light;
##  5. observe_then_behind: you walk away along a dark way, your torch lit:
##     while it observes, its distance from you stays inside observe_m and
##     outside your torch's circle; then it goes round behind you and
##     strikes from behind (more than 90 degrees from where you look) with
##     the strike as built: its wind-up with its tell from the first frame,
##     wind_up_s before the lunge, then its recovery; its time observing out
##     of your light was your flame's delay (no hold first); a hit is one
##     hit; and you in a side way its dark reaches only through one of its
##     tunnels, it follows you through the tunnel;
##  6. coil_ambush: it goes round into a coil lies_coiled_behind_m behind
##     you (behind where you look); its tell sounds as you move on and it is
##     silent while you stand; your torch out, a view turn toward it starts
##     its wind-up on that very tick, with its tell, and the hit that
##     follows counts as one hit (one, never more); your torch lit, the same
##     once it has stalked you torch_delay.hang_s; your torch lit and turned
##     on it sooner, your flame holds it first (the hold as built), then it
##     strikes; keep walking and it lets you go when its dwell ends (no
##     strike, its rounds don't take you up for let_go_s, and neither it nor
##     observe_then_behind may come back for you till let_go_s is over);
##  7. loose, for each seed: the snake with its whole pool from the file
##     for LOOSE_S, you walking up and down its dark, your torch lit and
##     then out by turns (nothing reaches you), two rooms relit on the way:
##     it never walks into a lit room or stretch of its own accord, nothing
##     teleports (no step past its top speed, its body never through the
##     stone), no draw in the rule's moments, no step of the new states
##     faster than hunt_mps, and every freeze began watched.

var fails := 0
var DT := 1.0 / 30.0
## The loose run (s).
const LOOSE_S := 200.0
## Back in the dark within this, leaving the light (s): the boss check's.
const LEAVE_MOST_S := 12.0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


## Does nothing: it lies as it is (the state in charge while a test runs).
class IdleState extends BossState:
	pass


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	WorldSave.read_only = true
	# The tomb's skeletons sleep through this check (design §FE; queue 58).
	Residents.stay_asleep = true
	Bow.need_capture = false
	# Pictures and pools, not a burn test: the torch never burns out (§FJ.4).
	Torch.burn_down = false
	BossPool.register("test_idle", IdleState)
	var seeds: Array = [7, 1]
	var env := OS.get_environment("SNAKE_SEEDS")
	if env != "":
		seeds = []
		for s in env.split(","):
			if s.strip_edges().is_valid_int():
				seeds.append(int(s))
	var only := OS.get_environment("SNAKE_ONLY").split(",", false)
	var want := func(part: String) -> bool: return only.is_empty() or only.has(part)
	if want.call("pool"):
		_pool_data()
	var sv0: int = seeds[0] if not seeds.is_empty() else 7
	for part in ["draws", "freeze", "doorway", "observe", "ambush"]:
		if not want.call(part):
			continue
		print("== seed %d: %s" % [sv0, part])
		_mo = {}
		var main := await _boot(sv0)
		match part:
			"draws":
				_draws(main)
			"freeze":
				_freeze(main)
			"doorway":
				_doorway(main)
			"observe":
				_observe(main)
			"ambush":
				await _ambush(main)
		await _done(main)
	if want.call("loose"):
		for sv in seeds:
			print("== seed %d: loose" % sv)
			_mo = {}
			var main := await _boot(sv)
			_loose(main)
			await _done(main)
	BossPool.unregister("test_idle")
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


# --- Helpers ----------------------------------------------------------------------

## Its entry in boss_pool.json pools.desert (a copy).
func _entry(id: String) -> Dictionary:
	return ((BossPool.DATA.get("pools", {}) as Dictionary).get("desert", {}) as Dictionary).get(id, {}).duplicate(true)


## A pool of the desert's own states, each its entry from the file with
## `spec[id]`'s numbers over it (a state not in the file, as given), under
## the file's rule.
func _pool(spec: Dictionary, label := "snake_test") -> BossPool:
	var states := {}
	for id in spec:
		var e := _entry(str(id))
		var over: Dictionary = spec[id]
		for k in over:
			e[k] = over[k]
		states[id] = e
	return BossPool.from_dict(states, BossPool.RULE, label)


## Step the snake (and Harm) `secs` s, or until `stop` says (its motion
## tracked, _tick).
func _sim(main: CrawlerMain, secs: float, stop: Callable = Callable()) -> float:
	var t := 0.0
	while t < secs:
		_tick(main)
		t += DT
		if stop.is_valid() and bool(stop.call()):
			break
	return t


## You at `at`, looking at `target` (yaw and pitch, from your eye).
func _stand_look(p: CrawlerPlayer, at: Vector3, target: Vector3) -> void:
	p.spawn_flat(at, 0.0, 0.0)
	_look_at(p, target)


func _look_at(p: CrawlerPlayer, target: Vector3) -> void:
	var e := p.camera().global_position
	var v := target - e
	var flat := Vector2(v.x, v.z).length()
	p.set_view(atan2(v.y, maxf(flat, 0.01)), atan2(-v.x, -v.z))


## You looking along flat direction `fwd` (level).
func _look_along(p: CrawlerPlayer, fwd: Vector3) -> void:
	p.set_view(0.0, atan2(-fwd.x, -fwd.z))


## You with your back to the snake (level), wherever you stand.
func _look_away_from(p: CrawlerPlayer, b: Boss) -> void:
	var v := p.global_position - b.head
	v.y = 0.0
	_look_along(p, v.normalized() if v.length() > 0.01 else Vector3.FORWARD)


func _torch_on(p: CrawlerPlayer) -> void:
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	if not p.torch.lit():
		p.torch.light()


func _torch_off(p: CrawlerPlayer) -> void:
	if p.torch.lit():
		p.torch.put_out("check")
	p.weapon = "hands"


## Light holder `h` (as the boss check does).
func _light_holder(main: CrawlerMain, h: Node3D) -> void:
	FireStore.swing_light(h, float(main.world.get("days")))
	for i in 600:
		FireStore.tick(self, 1.0 / 60.0, h.global_position)
		if FireStore.is_lit(h):
			return


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
	_mo_rebase(b)


## The snake laid coiled in its far dead end again.
func _relay(main: CrawlerMain) -> void:
	var b := main.boss
	b._let_go("check")
	b._calm()
	b._start_far()
	b._pose()
	_mo_rebase(b)


## Where you can watch the snake from (freeze_watched's needs): a node to
## lay it in and a spot on open floor `lo`-`hi` m off it (flat) from which,
## your torch lit, it is watched (BossStalk.watched). Tries its dark nodes
## farthest from the hearth first. {"node", "spot"} or {}.
func _watch_setup(main: CrawlerMain, lo: float, hi: float) -> Dictionary:
	var b := main.boss
	var p := main.player
	var def := _entry("freeze_watched")
	_torch_on(p)
	var dist := b._all_dist(b._hearth_node())
	var ids: Array = []
	for id in dist:
		if b.ground.is_ground(int(id)):
			ids.append(int(id))
	ids.sort_custom(func(x, y): return float(dist[x]) > float(dist[y]))
	for id in ids:
		_lie_in(main, id)
		if b.on_way_out(b.base):
			continue
		var hp := BossStalk.head_point(b)
		for k in 36:
			var a := TAU * k / 36.0
			for r: float in [lerpf(lo, hi, 0.5), lo + 0.3, hi - 0.3]:
				var q := hp + Vector3(cos(a), 0.0, sin(a)) * r
				var c := b.nav.nearest_open(b.nav.cell_of(q), 2)
				if c.x < 0:
					continue
				q = b.nav.point_of(c)
				var dq := BossStalk.flat_d(q, hp)
				if dq < lo or dq > hi or absf(q.y - hp.y) > 1.2:
					continue
				var qn := b.ground.node_at(q)
				if qn < 0 or not b.ground.is_ground(qn):
					continue
				_stand_look(p, q, hp)
				if BossStalk.watched(b, def):
					return {"node": id, "spot": q}
	return {}


## The way from the snake toward the hearth along the floor (TombNav), cut
## where it first leaves its dark: [] if too short.
func _walk_from_snake(main: CrawlerMain) -> PackedVector3Array:
	var b := main.boss
	var w: Array = main.lay.wake
	var pts := b.nav.path(b.base, w[0], true)
	var out := PackedVector3Array()
	for q in pts:
		var id := b.ground.node_at(q)
		if id < 0 or not b.ground.is_ground(id):
			break
		out.append(q)
	return out


## The point `s` m along polyline `pts`, and the way it goes there (flat).
func _along(pts: PackedVector3Array, s: float) -> Array:
	var left := s
	for k in range(1, pts.size()):
		var l := pts[k - 1].distance_to(pts[k])
		if l >= left:
			var dv := pts[k] - pts[k - 1]
			dv.y = 0.0
			return [pts[k - 1].lerp(pts[k], left / maxf(l, 1e-4)), dv.normalized()]
		left -= l
	var n := pts.size()
	var last := pts[n - 1] - pts[maxi(n - 2, 0)]
	last.y = 0.0
	return [pts[n - 1], last.normalized() if last.length() > 1e-4 else Vector3.FORWARD]


## How far along `pts` (m) it first is `d` m (flat) from `p`, or -1.
func _first_at(pts: PackedVector3Array, p: Vector3, d: float) -> float:
	var length := TombNav.length_of(pts)
	var s := 0.0
	while s <= length:
		var q: Vector3 = _along(pts, s)[0]
		if BossStalk.flat_d(q, p) >= d:
			return s
		s += 0.25
	return -1.0


# --- Nothing teleports (the boss check's tracker) --------------------------------

var _mo := {}


func _mo_reset(b: Boss) -> void:
	_mo = {"frames": 0, "worst": 0.0, "over": 0, "vanished": 0, "stone": 0, "base": b.base,
		"new_worst": 0.0, "new_over": 0}


## A harness's placing (it was laid somewhere): the tracker goes on from
## there, its tallies kept.
func _mo_rebase(b: Boss) -> void:
	if not _mo.is_empty():
		_mo.base = b.base


## Is any of its body as drawn in the stone (boss_check's _in_stone)?
func _in_stone(b: Boss) -> bool:
	var lay := b.lay
	var holes: Array = (lay.get("tunnels", {}) as Dictionary).get("holes", [])
	for q: Vector3 in b._body_pts(0.5):
		if q.y < b._floor_y(q) - 0.3 or TombKit.piece_at(lay, q) >= 0:
			continue
		var ok_here := false
		for d in lay.doors:
			var dn := Vector2((d.n as Vector2).x, (d.n as Vector2).y) if d.n is Vector2 else Vector2((d.n as Vector3).x, (d.n as Vector3).z)
			var dp := Vector2((d.p as Vector2).x, (d.p as Vector2).y) if d.p is Vector2 else Vector2((d.p as Vector3).x, (d.p as Vector3).z)
			var r := Vector2(q.x, q.z) - dp
			if absf(r.dot(dn)) <= Delves.WALL * 0.5 + 0.15 and absf(r.dot(Vector2(-dn.y, dn.x))) <= float(d.half) + 0.1:
				ok_here = true
				break
		if not ok_here:
			for h in holes:
				var r3 := q - (h.pos as Vector3)
				var into := -r3.dot(h.n as Vector3)
				if absf(r3.dot(h.u as Vector3)) <= float(h.w) * 0.5 + 0.05 and into >= -0.1 and into <= float(h.depth) + 0.15:
					ok_here = true
					break
		if not ok_here:
			return true
	return false


## One frame's motion: its head's line no further than its top speed
## allows; the new states' steps no faster than hunt_mps; drawn whenever any
## of it is above the floor; its body never through the stone.
func _mo_step(b: Boss, dt: float, was_new: bool) -> void:
	_mo.frames = int(_mo.frames) + 1
	var d := (b.base as Vector3).distance_to(_mo.base)
	_mo.worst = maxf(float(_mo.worst), d / dt)
	if d > b.max_mps() * dt + 0.02:
		_mo.over = int(_mo.over) + 1
		if int(_mo.over) <= 3:
			print("  a step too far (%s): %.3f m in %.3f s" % [b.state, d, dt])
	if was_new and b.behaviour in ["freeze_watched", "doorway_watch", "observe_then_behind", "coil_ambush"]:
		_mo.new_worst = maxf(float(_mo.new_worst), d / dt)
		if d > b.num("hunt_mps", 4.6) * dt * 1.02 + 0.005:
			_mo.new_over = int(_mo.new_over) + 1
			if int(_mo.new_over) <= 3:
				print("  a new state's step past hunt_mps (%s / %s): %.3f m" % [b.behaviour, b.state, d])
	if not b.body.visible and b.body.baked and not b._all_below():
		_mo.vanished = int(_mo.vanished) + 1
	if int(_mo.frames) % 6 == 0 and b.body.visible and _in_stone(b):
		_mo.stone = int(_mo.stone) + 1
		if int(_mo.stone) <= 3:
			print("  its body in the stone (%s) at %s" % [b.state, str(b.base)])
	_mo.base = b.base


func _mo_ok(how: String) -> void:
	ok(int(_mo.over) == 0 and int(_mo.vanished) == 0 and int(_mo.stone) == 0 and int(_mo.frames) > 0, "%s: nothing teleports: over %d frames its fastest step %.2f m/s, %d too far, %d frames hidden above the floor, %d looks with its body through the stone" % [how, int(_mo.frames), float(_mo.worst), int(_mo.over), int(_mo.vanished), int(_mo.stone)])


## Step the snake and Harm one DT, tracking its motion (once a part has
## started its tracker, _mo_reset).
func _tick(main: CrawlerMain) -> void:
	var b := main.boss
	var was_new := b.behaviour in ["freeze_watched", "doorway_watch", "observe_then_behind", "coil_ambush"]
	b.tick(DT)
	main.harm.tick(DT)
	if not _mo.is_empty():
		_mo_step(b, DT, was_new)


# --- 1. The pool --------------------------------------------------------------------

func _pool_data() -> void:
	var p := BossPool.for_boss("desert")
	var want := ["rounds", "freeze_watched", "doorway_watch", "observe_then_behind", "coil_ambush"]
	var files_ok := true
	for id in want:
		if BossPool._script_for(id) == null:
			files_ok = false
	ok(p.ids.size() == 5 and p.skipped.is_empty() and files_ok and p.cut_ins == ["freeze_watched"], "the desert pool from boss_pool.json: %s, each found by its file in %s (skipped %s), the freeze the one that may cut in (%s)" % [str(p.ids), BossPool.STATES_DIR, str(p.skipped), str(p.cut_ins)])
	var others_ok := true
	for bid in (BossPool.DATA.get("pools", {}) as Dictionary):
		if str(bid) != "desert" and not BossPool.for_boss(str(bid)).only_rounds():
			others_ok = false
	ok(others_ok, "every other boss is still 'rounds' alone (the snake only)")
	var hunt := float(((Boss.B.get("bosses", {}) as Dictionary).get("desert", {}) as Dictionary).get("hunt_mps", 0.0))
	ok(absf(hunt - 4.6) < 1e-6, "hunt_mps is still 4.6 (bosses.json bosses.desert: %.2f; walk %.1f, sprint %.1f)" % [hunt, CrawlerPlayer.WALK_SPEED, CrawlerPlayer.SPRINT_SPEED])


# --- 2. 300 draws ----------------------------------------------------------------------

func _draws(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var setup := _watch_setup(main, 13.0, 15.5)
	ok(not setup.is_empty(), "a place to watch it from: laid in node %d, you %.1f m off" % [int(setup.get("node", -1)), BossStalk.flat_d(setup.get("spot", Vector3.ZERO), b.head) if not setup.is_empty() else -1.0])
	if setup.is_empty():
		return
	ok(b.pool != null and b.pool.ids.size() == 5, "its own pool from the file: %s" % str(b.pool.ids if b.pool != null else []))
	var pool := b.pool
	# (Laid again before every draw, so its rounds taking you up after one
	# carry nothing to the next.)
	var seq: Array = []
	# Every state that took charge, in order: the draws, and the freeze
	# cutting in between them.
	var charge: Array = []
	var states: Dictionary = {}
	var cut_ins := 0
	for i in 300:
		b._end_unit("swap")
		_lie_in(main, int(setup.node))
		_stand_look(p, setup.spot, BossStalk.head_point(b))
		b._draw_next()
		seq.append(b.behaviour)
		charge.append(b.behaviour)
		var t := 0.0
		while t < 0.25:
			_sim(main, DT)
			t += DT
			if b.behaviour != "" and b.behaviour != charge[-1]:
				charge.append(b.behaviour)
				cut_ins += 1
		states["%s/%s" % [seq[-1], b.state]] = true
	var counts := {}
	for id in seq:
		counts[id] = int(counts.get(id, 0)) + 1
	var repeats := 0
	for i in range(1, charge.size()):
		if charge[i] == charge[i - 1]:
			repeats += 1
	var all := true
	for id in ["rounds", "freeze_watched", "doorway_watch", "observe_then_behind", "coil_ambush"]:
		if int(counts.get(id, 0)) == 0:
			all = false
	ok(all and seq.size() == 300 and not counts.has(""), "over 300 draws all four new states and 'rounds' are entered: %s" % str(counts))
	ok(repeats == 0, "never the same state twice running, over the %d that took charge (the draws, and %d times the freeze cut in between them; %d repeats)" % [charge.size(), cut_ins, repeats])
	print("  entered as: %s" % ", ".join(PackedStringArray(states.keys())))
	b.set_pool(pool)


# --- 3. freeze_watched --------------------------------------------------------------

## The max blend on any of its sprites now (off their material), and
## whether every one keeps its alpha (no transparency).
func _blend_now(b: Boss) -> Array:
	var most := 0.0
	var opaque := true
	for s: FigureSprite in b.body.all_sprites():
		most = maxf(most, s.blend_now())
		if s.transparency > 0.0:
			opaque = false
	return [most, opaque]


func _freeze(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var def := _entry("freeze_watched")
	var fr: Array = def.get("from_m", [12.0, 60.0])
	var lo := float(fr[0])
	var look := float(def.get("look_deg", 25.0))
	var close_m := float(def.get("close_m", 7.0))
	var away_s := float(def.get("look_away_s", 3.0))
	var camo: Dictionary = BossPool.DATA.get("camouflage", {})
	var most := float(camo.get("max_blend", 0.5))
	var setup := _watch_setup(main, lo + 1.5, lo + 3.5)
	ok(not setup.is_empty(), "a place to watch it from (laid in node %d)" % int(setup.get("node", -1)))
	if setup.is_empty():
		return
	var node := int(setup.node)
	var spot: Vector3 = setup.spot
	# The freeze, and a state that does nothing in charge, its weight a
	# thousandth: the freeze cuts in whenever it may.
	var pool := _pool({"freeze_watched": {}, "test_idle": {"weight": 0.001, "dwell_s": [999.0, 999.0]}}, "freeze_test")
	var u: BossState = pool.unit("freeze_watched")
	var reset := func() -> void:
		_lie_in(main, node)
		b.set_pool(pool)
		# Your back to it until the test turns you (so nothing begins early).
		_look_away_from(p, b)
	# Never: you too close, none of it in your view, unlit.
	reset.call()
	var hp := BossStalk.head_point(b)
	var line := Vector3(spot.x - hp.x, 0.0, spot.z - hp.z).normalized()
	var near := hp + line * (lo - 2.0)
	var nc := b.nav.nearest_open(b.nav.cell_of(near), 2)
	near = b.nav.point_of(nc) if nc.x >= 0 else near
	var never := []
	for case in ["close", "aside", "unlit"]:
		reset.call()
		_torch_on(p)
		match case:
			"close":
				_stand_look(p, near, hp)
			"aside":
				_stand_look(p, spot, hp)
				# Turned away until none of it is inside look_deg.
				for k in range(3, 18):
					p.set_view(0.0, p._yaw + deg_to_rad(10.0))
					if BossStalk.watched_point(b, def) == null:
						break
			"unlit":
				_torch_off(p)
				_stand_look(p, spot, hp)
		var could := u.can_enter(b)
		_sim(main, 1.0)
		never.append("%s %s" % [case, "froze" if b.behaviour == "freeze_watched" else "no"])
		ok(not could and b.behaviour != "freeze_watched", "it doesn't freeze %s (%s; you %.1f m off)" % [{"close": "with you inside from_m[0] (%.1f m)" % lo, "aside": "with none of it inside look_deg (%.0f) of your view" % look, "unlit": "unseen: your torch out, no fire on it, past your half-dark sight"}[case], "it could" if could else "it may not", BossStalk.to_you(b)])
	# Looking at it from the spot, your torch lit: it freezes.
	reset.call()
	_torch_on(p)
	_sim(main, 0.3)
	var held0 := b.base
	_stand_look(p, spot, BossStalk.head_point(b))
	var t_in := _sim(main, 1.0, func() -> bool: return b.behaviour == "freeze_watched")
	var seen: Variant = u.get("seen_by")
	var ang := 999.0
	var head_d := BossStalk.flat_d(BossStalk.head_point(b), BossStalk.eye(b))
	var head_ang := rad_to_deg(BossStalk.axis(b).angle_to(BossStalk.head_point(b) - BossStalk.eye(b)))
	var nearest := BossStalk.nearest_part_m(b)
	if seen is Vector3:
		ang = rad_to_deg(BossStalk.axis(b).angle_to((seen as Vector3) - BossStalk.eye(b)))
	ok(b.behaviour == "freeze_watched" and b.state == "freeze" and t_in <= 0.3, "looking at it from %.1f m, your torch lit: it freezes %.2f s after (it cuts in)" % [BossStalk.to_you(b), t_in])
	ok(ang <= look and head_ang <= look and head_d >= lo and nearest >= lo, "when it froze its head was inside look_deg (%.1f degrees off your view axis; look_deg %.0f) and beyond from_m[0] (%.1f m; %.0f), all of it at least %.1f m off" % [head_ang, look, head_d, lo, nearest])
	# Frozen: still, silent, camouflaged within its bounds, never gone.
	var at := b.base
	var moved := 0.0
	var worst_blend := 0.0
	var all_opaque := true
	var hissed := false
	var wind0 := b.strike.wind_ups
	var tell_quiet := true
	var t := 0.0
	while t < 2.0:
		_sim(main, DT)
		t += DT
		moved = maxf(moved, b.base.distance_to(at))
		var bl := _blend_now(b)
		worst_blend = maxf(worst_blend, float(bl[0]))
		all_opaque = all_opaque and bool(bl[1])
		hissed = hissed or b._hiss.playing
		tell_quiet = tell_quiet and b.tell_want == -INF
	var k_now := float(_blend_now(b)[0])
	var want_k := clampf(float(def.get("blend", camo.get("blend", 0.3))), 0.0, most)
	ok(b.behaviour == "freeze_watched" and moved < 1e-4 and b.speed == 0.0 and tell_quiet and b.body.visible, "frozen it stops dead and lies still (moved %.4f m in 2 s), silent, never hidden (%s)" % [moved, "drawn" if b.body.visible else "HIDDEN"])
	var stone := RuinStyle.tint(str(main.lay.get("theme", "")))
	var paint := BossBody.BACK
	var mixed := paint.lerp(stone, worst_blend)
	var gap0 := Vector3(paint.r - stone.r, paint.g - stone.g, paint.b - stone.b).length()
	var gap := Vector3(mixed.r - stone.r, mixed.g - stone.g, mixed.b - stone.b).length()
	ok(worst_blend <= most + 1e-6 and k_now >= want_k * 0.95 and all_opaque, "its sprites' blend toward the stone eased to %.3f (its blend %.2f), never past camouflage.max_blend %.2f (the most sampled %.3f), every sprite opaque (alpha and transparency untouched)" % [k_now, want_k, most, worst_blend])
	ok(gap >= gap0 * (1.0 - most) - 1e-4 and gap > 0.01, "the tint sampled on its paint (%s) toward the stone (%s): %.3f of the way's %.3f left, never the stone's own" % [paint.to_html(false), stone.to_html(false), gap, gap0])
	# It ends when you close inside close_m (of any of it): not while you are
	# still outside it, and on the very tick you come inside, with no tell.
	var dv := spot - b.head
	dv.y = 0.0
	dv = dv.normalized()
	var e_out := b.head + dv * (close_m + 1.5)
	var oc := b.nav.nearest_open(b.nav.cell_of(e_out), 2)
	e_out = b.nav.point_of(oc) if oc.x >= 0 else e_out
	_stand_look(p, e_out, BossStalk.head_point(b))
	var near_out := BossStalk.nearest_part_m(b)
	_sim(main, 0.5)
	var held_out := b.behaviour == "freeze_watched" and not bool(u.get("done"))
	var e := b.head + dv * (close_m - 0.6)
	var ec := b.nav.nearest_open(b.nav.cell_of(e), 2)
	e = b.nav.point_of(ec) if ec.x >= 0 else e
	var done0 := int(b.states_ended.done)
	_stand_look(p, e, BossStalk.head_point(b))
	var near_in := BossStalk.nearest_part_m(b)
	_sim(main, DT)
	var ended_then := str(u.get("ended_by")) == "close" and bool(u.get("done"))
	_sim(main, DT)
	ok(held_out and near_out >= close_m and ended_then and b.behaviour != "freeze_watched" and int(b.states_ended.done) == done0 + 1, "frozen while you come up to %.1f m of it (the nearest of it; close_m %.0f), it ends on the tick you come inside, %.1f m, and the pool draws the next on the one after (%s)" % [near_out, close_m, near_in, b.behaviour])
	_sim(main, 0.2)
	ok(not hissed and not b._hiss.playing and b.strike.wind_ups == wind0, "with no tell: no hiss and no wind-up through the freeze and its end")
	_sim(main, 1.2)
	ok(float(_blend_now(b)[0]) < 1e-4, "its camouflage eased back off after (%.3f)" % float(_blend_now(b)[0]))
	# It ends when you look away look_away_s.
	reset.call()
	_torch_on(p)
	_sim(main, 0.3)
	_stand_look(p, spot, BossStalk.head_point(b))
	_sim(main, 1.0, func() -> bool: return b.behaviour == "freeze_watched")
	var froze2 := b.behaviour == "freeze_watched"
	# Watched a while, level (frozen all the while), then you turn your back.
	_look_along(p, Vector3(b.head.x - spot.x, 0.0, b.head.z - spot.z).normalized())
	_sim(main, 1.0)
	froze2 = froze2 and b.behaviour == "freeze_watched"
	_look_along(p, Vector3(spot.x - b.head.x, 0.0, spot.z - b.head.z).normalized())
	var away := _sim(main, away_s + 1.0, func() -> bool: return bool(u.get("done")))
	ok(froze2 and absf(away - away_s) <= DT * 1.5 and str(u.get("ended_by")) == "look_away", "you look away: it ends after %.2f s (look_away_s %.1f)" % [away, away_s])
	# It ends when its dwell runs out, you watching it all the while.
	reset.call()
	_torch_on(p)
	_sim(main, 0.3)
	_stand_look(p, spot, BossStalk.head_point(b))
	_sim(main, 1.0, func() -> bool: return b.behaviour == "freeze_watched")
	var froze3 := b.behaviour == "freeze_watched"
	var dwell := b._dwell_left
	var dw: Array = def.get("dwell_s", [6.0, 14.0])
	var dwell0 := int(b.states_ended.dwell)
	var lasted := _sim(main, float(dw[1]) + 2.0, func() -> bool: return b.behaviour != "freeze_watched")
	ok(froze3 and absf(lasted - dwell) <= DT * 1.5 and int(b.states_ended.dwell) == dwell0 + 1 and dwell >= float(dw[0]) - 1e-3 and dwell <= float(dw[1]) + 1e-3, "watched all the while, it ends when its dwell runs out: %.2f s (its dwell %.2f, dwell_s %s)" % [lasted, dwell, str(dw)])
	# Never past max_blend, whatever it is asked: the freeze's own blend set
	# to 0.9 in a test pool, then the boss asked for 0.95 by hand.
	var over := _pool({"freeze_watched": {"blend": 0.9}, "test_idle": {"weight": 0.001, "dwell_s": [999.0, 999.0]}}, "freeze_over")
	_lie_in(main, node)
	b.set_pool(over)
	_look_away_from(p, b)
	_torch_on(p)
	_sim(main, 0.3)
	_stand_look(p, spot, BossStalk.head_point(b))
	_sim(main, 1.0, func() -> bool: return b.behaviour == "freeze_watched")
	var froze_over := b.behaviour == "freeze_watched"
	var peak := 0.0
	var opaque_over := true
	for k in 60:
		_sim(main, DT)
		var bo := _blend_now(b)
		peak = maxf(peak, float(bo[0]))
		opaque_over = opaque_over and bool(bo[1])
	var asked := float(_blend_now(b)[0])
	b.camo_want = 0.95
	for k in 60:
		_sim(main, DT)
		var bo2 := _blend_now(b)
		peak = maxf(peak, float(bo2[0]))
		opaque_over = opaque_over and bool(bo2[1])
	ok(froze_over and b.behaviour == "freeze_watched" and peak <= most + 1e-6 and asked >= most - 1e-3 and b.camo <= most + 1e-6 and opaque_over, "asked for more (the freeze's blend 0.9, then 0.95 by hand): its sprites' blend stops at camouflage.max_blend %.2f (the most sampled %.3f), never transparent" % [most, peak])
	b._end_unit("swap")
	_sim(main, 1.2)
	# Never in a room you have lit: laid in a dark room with torches, you
	# watching, the room relit round it.
	var room := -1
	for id in range(b.ground.nodes.size()):
		var n: Dictionary = b.ground.nodes[id]
		if str(n.kind) == "room" and b.ground.is_ground(id) and not (n.holders as Array).is_empty():
			room = id
			break
	if room >= 0:
		_lie_in(main, room)
		b.set_pool(_pool({"test_idle": {"weight": 1.0, "dwell_s": [999.0, 999.0]}, "freeze_watched": {}}, "freeze_lit"))
		_sim(main, 0.1)
		for h in b.ground.nodes[room].holders:
			_light_holder(main, main.fires.holders[int(h)])
		b._refresh(false)
		var could := pool.unit("freeze_watched").can_enter(b)
		var froze_lit := false
		var tl := 0.0
		while tl < LEAVE_MOST_S and not (b.node >= 0 and b.ground.is_ground(b.node) and not b._in_tunnel() and b.state != "leave"):
			_sim(main, DT)
			tl += DT
			froze_lit = froze_lit or b.behaviour == "freeze_watched"
		ok(not could and not froze_lit, "it never freezes in a room you have lit (node %d relit round it: it may not, and it left for the dark in %.1f s)" % [room, tl])
	# Weighed against the state in charge: about half the times you first
	# catch sight of it, by the weights 2 against 2.
	reset.call()
	var even := _pool({"test_idle": {"weight": 2.0, "dwell_s": [999.0, 999.0]}, "freeze_watched": {}}, "freeze_even")
	var froze_n := 0
	var trials := 40
	for i in trials:
		_lie_in(main, node)
		b.set_pool(even)
		_torch_on(p)
		_stand_look(p, spot, BossStalk.head_point(b))
		_look_along(p, Vector3(-(spot.x - b.head.x), 0.0, -(spot.z - b.head.z)).normalized())
		_sim(main, 0.45)
		_look_at(p, BossStalk.head_point(b))
		_sim(main, 0.45)
		if b.behaviour == "freeze_watched":
			froze_n += 1
	ok(froze_n >= 8 and froze_n <= 32, "the moment you first catch sight of it, it cuts in by its weight against the state in charge (2 against 2): %d of %d times" % [froze_n, trials])


# --- 4. doorway_watch -------------------------------------------------------------------

func _doorway(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var def := _entry("doorway_watch")
	var w: Array = main.lay.wake
	_relay(main)
	p.spawn_flat(w[0], float(w[1]), 0.0)
	var pool := _pool({"doorway_watch": {"dwell_s": [999.0, 999.0]}}, "doorway_test")
	var u: BossState = pool.unit("doorway_watch")
	# The nearest doorway by its way, as the check works it out.
	var reach := b.ground.reach(b.node)
	var yours := b.ground.node_at(p.global_position)
	var best_door := -1
	var best_c := INF
	var bad_doors := 0
	for id in reach:
		var n: Dictionary = b.ground.nodes[int(id)]
		if str(n.kind) != "room" or bool(n.hearth) or int(id) == yours:
			continue
		for di in (main.lay.pieces[int(n.piece)] as Dictionary).doors:
			var d: Dictionary = main.lay.doors[int(di)]
			var spot := BossStalk.door_spot(b, d, int(id), def)
			if spot.is_empty():
				continue
			var other := int(d.b) if int(d.a) == int(n.piece) else int(d.a)
			if other < 0 or bool((main.lay.pieces[other] as Dictionary).get("exit", false)) or str((main.lay.pieces[other] as Dictionary).get("room_kind", "")) == "hearth":
				bad_doors += 1
			# Nor a doorway off its own floor (the stair down, §FM.6) or shut by
			# a gate (the fork's seal): its head would lie in the seal's stone.
			if TombFloors.floor_of(main.lay, other) != TombFloors.BOSS_FLOOR or b.ground.shut.has(int(d.id)):
				bad_doors += 1
			var c := float(reach[id]) + BossStalk.flat_d(n.center, spot.stand)
			if c < best_c:
				best_c = c
				best_door = int(d.id)
	# The stair down's doorway (§FM.6: to floor two, its seal standing in the
	# mouth until floor one is lit): never one to watch from, from either
	# side, whoever is where.
	var dsc: Dictionary = main.lay.get("descent", {})
	var seal_spots := 0
	if not dsc.is_empty():
		var sd: Dictionary = main.lay.doors[int(dsc.door)]
		for side: int in [int(sd.a), int(sd.b)]:
			var ids: Array = b.ground.by_piece.get(side, [])
			for nid in ids:
				if not BossStalk.door_spot(b, sd, int(nid), def).is_empty():
					seal_spots += 1
	if dsc.is_empty():
		print("  (seed %d has one floor: no stair down to keep it out of)" % int(main.lay.seed))
	else:
		ok(seal_spots == 0 and b.ground.shut.has(int(dsc.door)), "never the stair down's doorway (sealed, to floor two; door %d, shut on its ground): %d spots there" % [int(dsc.door), seal_spots])
	b.set_pool(pool)
	_mo_reset(b)
	_tick(main)
	var sp: Dictionary = u.get("spot")
	ok(b.behaviour == "doorway_watch" and not sp.is_empty() and int(sp.door) == best_door and bad_doors == 0, "it picks the nearest doorway of an unlit room on its rounds that you are not in: door %d of node %d (the check's own nearest: door %d; none onto the way out, out of the tomb, into the hearth room, off its floor or through a seal)" % [int(sp.get("door", -1)), int(sp.get("node", -1)), best_door])
	if sp.is_empty():
		return
	var room := int(sp.node)
	var t := 0.0
	var lit_in0 := b.lit_entries
	while t < 90.0 and not bool(u.get("arrived")):
		_tick(main)
		t += DT
	_mo_ok("going to its doorway")
	var settled := bool(u.get("arrived"))
	# A breath to settle its head into the gap.
	_sim(main, 1.0)
	var hp: Vector3 = u.call("head_point", b)
	var out: Vector3 = sp.out
	var rel := hp - (sp.mid as Vector3)
	var along := rel.x * out.x + rel.z * out.z
	var across := absf(rel.x * -out.z + rel.z * out.x)
	ok(settled and bool(u.call("in_doorway", b)) and b.ground.node_at(b.base) == room and b.ground.is_ground(room) and room != b.ground.node_at(p.global_position) and b.lit_entries == lit_in0, "after %.1f s by its dark (never into the light) it lies in the doorway of unlit room %d, its head as drawn in the gap: %.2f m through the wall's middle (the wall %.1f thick), %.2f m from the opening's middle (half %.2f)" % [t, room, along, Delves.WALL, across, float(sp.half)])
	var at := b.base
	_sim(main, 3.0)
	ok(b.behaviour == "doorway_watch" and b.base.distance_to(at) < 1e-4 and b.speed == 0.0, "still, it watches (moved %.4f m in 3 s)" % b.base.distance_to(at))
	# Light the room: it is over that tick, and it leaves for the dark.
	var light0 := int(b.states_ended.light)
	for h in b.ground.nodes[room].holders:
		_light_holder(main, main.fires.holders[int(h)])
	var was_lit := not b.ground.is_ground(room)
	_tick(main)
	var over := b.behaviour == "" and int(b.states_ended.light) == light0 + 1 and b.state == "leave"
	var state_then := b.state
	var tl := 0.0
	while tl < LEAVE_MOST_S and not (b.node >= 0 and b.ground.is_ground(b.node) and not b._in_tunnel()):
		_tick(main)
		tl += DT
	var room_lit := not b.ground.is_ground(room)
	ok(not was_lit and room_lit and over and tl < LEAVE_MOST_S, "its room relit, the watch is over on that tick and it leaves (%s), back in the dark %.1f s later" % [state_then, tl])
	_mo_ok("leaving its doorway")
	# You come into its room: the watch is over.
	var w2 := _pool({"doorway_watch": {"dwell_s": [999.0, 999.0]}}, "doorway_test2")
	var u2: BossState = w2.unit("doorway_watch")
	_relay(main)
	p.spawn_flat(w[0], float(w[1]), 0.0)
	b.set_pool(w2)
	_sim(main, 90.0, func() -> bool: return bool(u2.get("arrived")))
	var sp2: Dictionary = u2.get("spot")
	if not sp2.is_empty() and bool(u2.get("arrived")):
		var inside: Vector3 = b._coil_spot(int(sp2.node))
		p.spawn_flat(inside, 0.0, 0.0)
		var done0 := int(b.states_ended.done)
		_sim(main, DT * 2.0)
		ok(int(b.states_ended.done) == done0 + 1 and b.behaviour != "doorway_watch" or b.behaviour == "doorway_watch" and int(b.states_ended.done) > done0, "you come into its room: the watch is over (%s next)" % b.behaviour)
	else:
		ok(false, "a second watch to walk in on (%s)" % str(sp2))
	# A light that catches across its way there: it goes round by another
	# dark way, or the watch is over and it holds where it is; never on into
	# the light. (Its way laid by hand through a dark room with torches,
	# then that room lit.)
	var w3 := _pool({"doorway_watch": {"dwell_s": [999.0, 999.0]}}, "doorway_test3")
	var u3: BossState = w3.unit("doorway_watch")
	_relay(main)
	p.spawn_flat(w[0], float(w[1]), 0.0)
	b.set_pool(w3)
	_tick(main)
	var sp3: Dictionary = u3.get("spot")
	var via := -1
	if not sp3.is_empty():
		for id in range(b.ground.nodes.size()):
			var n: Dictionary = b.ground.nodes[id]
			if id == b.node or id == int(sp3.node) or str(n.kind) != "room" or bool(n.hearth) or not b.ground.is_ground(id) or (n.holders as Array).is_empty():
				continue
			var p1 := b.ground.path(b.node, id, true)
			var p2 := b.ground.path(id, int(sp3.node), true)
			if p1.is_empty() or p2.is_empty():
				continue
			via = id
			b._set_planned(b._plan_from(), p1 + p2.slice(1), sp3.deep)
			var pts := b.route
			var hid := b.route_hidden
			b._floor_leg(pts, hid, sp3.deep, sp3.inner)
			b._floor_leg(pts, hid, sp3.inner, sp3.stand)
			b._set_route(pts, hid)
			break
	if via < 0:
		ok(false, "a dark room with torches on a way to its doorway to light (doorway %s)" % str(sp3.get("door", -1)))
		return
	var through := false
	for i in range(b.route_i, b.route.size()):
		if b.ground.node_at(b.route[i]) == via:
			through = true
	var lit3 := b.lit_entries
	var lightlog := []
	for h in b.ground.nodes[via].holders:
		_light_holder(main, main.fires.holders[int(h)])
	_mo_reset(b)
	_tick(main)
	var rerouted := b.behaviour == "doorway_watch" and not bool(u3.get("done")) and BossStalk.route_dark(b)
	var ended := bool(u3.get("done")) or b.behaviour != "doorway_watch"
	var t3 := 0.0
	while t3 < 90.0 and b.behaviour == "doorway_watch" and not bool(u3.get("arrived")):
		_tick(main)
		t3 += DT
		if b.lit_entries != lit3:
			lightlog.append(b.state)
	ok(through and not b.ground.is_ground(via) and (rerouted or ended) and b.lit_entries == lit3, "its way laid through room %d, that room lit as it goes: %s, and it never walks into the light (%d times; %s)" % [via, "it finds another dark way there (there %.1f s later)" % t3 if rerouted else "the watch is over and it holds", b.lit_entries - lit3, str(lightlog)])
	_mo_ok("going round the light to its doorway")


# --- 5. observe_then_behind ------------------------------------------------------------

func _observe(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var def := _entry("observe_then_behind")
	var bm: Array = def.get("observe_m", [10.0, 18.0])
	_relay(main)
	var walk := _walk_from_snake(main)
	var length := TombNav.length_of(walk)
	var s0 := _first_at(walk, b.head, float(bm[0]) + 3.0)
	ok(s0 >= 0.0 and length - s0 > 12.0, "a dark way from it toward the hearth to walk along (%.1f m, you start %.1f m along it)" % [length, s0])
	if s0 < 0.0:
		return
	var obs_s := 6.0
	var pool := _pool({"observe_then_behind": {"dwell_s": [999.0, 999.0], "observe_s": [obs_s, obs_s]}}, "observe_test")
	var u: BossState = pool.unit("observe_then_behind")
	_torch_on(p)
	var s := s0
	var here: Array = _along(walk, s)
	p.spawn_flat(here[0], 0.0, 0.0)
	_look_along(p, here[1])
	b.set_pool(pool)
	_mo_reset(b)
	var circle := BossStalk.torch_circle_m()
	var lo := maxf(float(bm[0]), circle + 0.5)
	var hi := maxf(float(bm[1]), lo + 2.0)
	var d_min := INF
	var d_max := -INF
	var inside_circle := 0
	var observing := 0.0
	var t := 0.0
	# You walk on along the way at an easy walk while it studies you.
	while t < 40.0 and str(u.get("phase")) != "behind" and s < length - 0.5:
		s += 2.6 * DT
		here = _along(walk, s)
		p.global_position = here[0]
		_look_along(p, here[1])
		_tick(main)
		t += DT
		if str(u.get("phase")) == "observe" and b.behaviour == "observe_then_behind":
			observing += DT
			var d := BossStalk.to_you(b)
			d_min = minf(d_min, d)
			d_max = maxf(d_max, d)
			if d < circle:
				inside_circle += 1
	ok(observing >= obs_s - 0.2 and d_min >= lo - 0.5 and d_max <= hi + 0.5 and inside_circle == 0, "observing %.1f s (observe_s %.0f) as you walk on, its distance stays inside observe_m [%.0f, %.0f]: %.1f to %.1f m, never inside your torch's circle (%.1f m)" % [observing, obs_s, lo, hi, d_min, d_max, circle])
	# Then it goes round behind you and strikes from behind: you walk on
	# slowly, your back to it.
	var wind0 := b.strike.wind_ups
	var landed0 := main.harm.landed
	main.harm.reset()
	landed0 = main.harm.landed
	p._invulnerable = 0.0
	var began_at := -1.0
	var committed_at := -1.0
	var recovered := false
	var tell_ok := false
	var t2 := 0.0
	var state_at := ""
	while t2 < 25.0 and not recovered:
		if began_at < 0.0:
			s = minf(s + 0.8 * DT, length - 0.2)
			here = _along(walk, s)
			p.global_position = here[0]
			_look_along(p, here[1])
		_tick(main)
		t2 += DT
		if began_at < 0.0 and b.strike.wind_ups > wind0:
			began_at = t2
			state_at = b.state
			tell_ok = b.strike.sound != "" and b.strike.tell_frame == b.strike.wind_up_frame and b.strike.state == "wind_up"
		if began_at >= 0.0 and committed_at < 0.0 and b.strike.state == "strike":
			committed_at = t2
		if committed_at >= 0.0 and b.strike.state == "recover":
			recovered = true
	var ang := float(u.get("strike_angle"))
	var hits := main.harm.landed - landed0
	ok(began_at >= 0.0 and ang > BossStalk.BEHIND_DEG and state_at == "strike" and tell_ok, "then it goes round behind you and strikes from behind: %.0f degrees from where you look, its wind-up with its tell (%s) from the first frame, %.1f s on" % [ang, b.strike.sound, began_at])
	ok(committed_at - began_at >= b.strike.wind_up_s - DT * 1.5 and recovered and hits <= 1, "the strike as built: %.2f s of wind-up before the lunge (wind_up_s %.2f), then its recovery; %d hit (one at most)" % [committed_at - began_at, b.strike.wind_up_s, hits])
	ok(float(u.get("held")) >= float(b.sub("torch_delay").get("hang_s", 4.0)), "its time observing out of your light (%.1f s) was your flame's delay: no hold first (torch_delay.hang_s %.1f)" % [float(u.get("held")), float(b.sub("torch_delay").get("hang_s", 4.0))])
	_mo_ok("observing you and coming round behind you")
	main.harm.reset()
	# Through its tunnels: you in a side way it can reach from where it lies
	# only through one of them (the floor's way crosses the hearth room's
	# light): it follows you through the tunnel.
	var tun: Dictionary = main.lay.get("tunnels", {})
	var holes: Array = tun.get("holes", [])
	var through := false
	var tried := false
	for tk: Dictionary in tun.get("links", []):
		var na := b.ground.node_at((holes[int(tk.a)] as Dictionary).out)
		var nb := b.ground.node_at((holes[int(tk.b)] as Dictionary).out)
		if na < 0 or nb < 0 or na == nb or not b.ground.is_ground(na) or not b.ground.is_ground(nb):
			continue
		_lie_in(main, na)
		var you_at: Vector3 = b.ground.nodes[nb].center
		if BossStalk.all_dark(b, b.nav.path(b.base, you_at, true, TombNav.DIM)):
			continue
		tried = true
		var pool2 := _pool({"observe_then_behind": {"dwell_s": [999.0, 999.0], "observe_s": [999.0, 999.0]}}, "observe_tunnel")
		p.spawn_flat(you_at, 0.0, 0.0)
		_torch_on(p)
		b.set_pool(pool2)
		var tr0 := b.transits
		_mo_reset(b)
		_sim(main, 45.0, func() -> bool: return b.transits > tr0)
		through = b.transits > tr0
		print("  you in node %d, it in node %d: the floor's way between crosses the light; %d tunnel transits" % [nb, na, b.transits - tr0])
		_mo_ok("following you through its tunnel")
		break
	ok(tried and through, "it follows you through its tunnels where its dark way to you goes through one (in at one hole, out of the other)")


# --- 6. coil_ambush ---------------------------------------------------------------------

## The ambush laid on: the snake in its far dead end, you `start` m off
## along the dark way home, your back to it, torch as given; the pool
## `spec`. Returns [walk, s] (the way, how far along it you stand).
func _ambush_setup(main: CrawlerMain, spec: Dictionary, lit: bool, start := 12.0) -> Array:
	var b := main.boss
	var p := main.player
	_relay(main)
	main.harm.reset()
	p._invulnerable = 0.0
	var walk := _walk_from_snake(main)
	var s := _first_at(walk, b.head, start)
	if s < 0.0:
		return [walk, -1.0]
	if lit:
		_torch_on(p)
	else:
		_torch_off(p)
	var here: Array = _along(walk, s)
	p.spawn_flat(here[0], 0.0, 0.0)
	_look_along(p, here[1])
	b.set_pool(_pool(spec, "ambush_test"))
	return [walk, s]


## Step until it lies behind you (or `most` s).
func _until_lying(main: CrawlerMain, u: BossState, most := 20.0) -> float:
	var t := 0.0
	while t < most and str(u.get("phase")) != "lie":
		_tick(main)
		t += DT
	return t


func _ambush(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var def := _entry("coil_ambush")
	var lies: Array = def.get("lies_coiled_behind_m", [5.0, 9.0])
	var hang_s := float(b.sub("torch_delay").get("hang_s", 4.0))
	# It goes round into a coil lies_coiled_behind_m behind you.
	var setup := _ambush_setup(main, {"coil_ambush": {"dwell_s": [999.0, 999.0]}}, false, float(lies[1]) + 5.0)
	if float(setup[1]) < 0.0:
		ok(false, "a dark way home from its dead end to stand on")
		return
	var u: BossState = b.pool.unit("coil_ambush")
	_mo_reset(b)
	var t := _until_lying(main, u)
	var lie_m := float(u.get("lie_m"))
	var lay_d := float(u.get("lay_d"))
	ok(str(u.get("phase")) == "lie" and lie_m >= float(lies[0]) - 1e-3 and lie_m <= float(lies[1]) + 1e-3 and absf(lay_d - lie_m) <= 1.3 and float(u.get("lay_angle")) > BossStalk.BEHIND_DEG, "it goes round into a coil lies_coiled_behind_m behind you: %.1f s, lying %.1f m off (its %.1f of %s), %.0f degrees from where you look" % [t, lay_d, lie_m, str(lies), float(u.get("lay_angle"))])
	# Its tell sounds as you move on, and not while you stand.
	var walk: PackedVector3Array = setup[0]
	var s := float(setup[1])
	_sim(main, 3.0, func() -> bool: return not bool(u.get("curling")))
	var moving_db := -INF
	var tt := 0.0
	while tt < 1.0:
		s += 1.2 * DT
		var here: Array = _along(walk, s)
		p.global_position = here[0]
		_look_along(p, here[1])
		_tick(main)
		tt += DT
		moving_db = maxf(moving_db, b.tell_want)
	_sim(main, 3.5, func() -> bool: return not bool(u.get("curling")) and b.speed < 0.05)
	_sim(main, 0.6)
	var still_db := b.tell_want
	ok(moving_db >= -6.0 and still_db == -INF and not b._tell.playing, "its tell sounds as you move on (%.0f dB) and it is silent while you stand (%s)" % [moving_db, "silent" if still_db == -INF else "%.0f dB" % still_db])
	_mo_ok("going round behind you")
	# Your torch out: turn toward it and its wind-up begins on that tick.
	setup = _ambush_setup(main, {"coil_ambush": {"dwell_s": [999.0, 999.0], "lies_coiled_behind_m": [5.0, 5.2]}}, false, 11.0)
	u = b.pool.unit("coil_ambush")
	_until_lying(main, u)
	_sim(main, 0.5)
	await _turn_strikes(main, u, "your torch out", true)
	# Your torch lit, after it has stalked you hang_s: the same.
	setup = _ambush_setup(main, {"coil_ambush": {"dwell_s": [999.0, 999.0], "lies_coiled_behind_m": [5.0, 5.2]}}, true, 11.0)
	u = b.pool.unit("coil_ambush")
	_until_lying(main, u)
	_sim(main, hang_s + 1.0, func() -> bool: return float(u.get("held")) >= hang_s + 0.2)
	await _turn_strikes(main, u, "your torch lit, it having stalked you %.1f s" % float(u.get("held")), true)
	# Your torch lit, turned on it sooner: your flame holds it first.
	setup = _ambush_setup(main, {"coil_ambush": {"dwell_s": [999.0, 999.0], "lies_coiled_behind_m": [5.0, 5.2]}}, true, 8.0)
	u = b.pool.unit("coil_ambush")
	_until_lying(main, u)
	var held_then := float(u.get("held"))
	var wind0 := b.strike.wind_ups
	_look_at(p, BossStalk.head_point(b))
	_tick(main)
	var no_wind := b.strike.wind_ups == wind0 and b.state in ["hunt", "hang"]
	var t_hold := 0.0
	var hung := false
	while t_hold < hang_s + 4.0 and b.strike.wind_ups == wind0:
		_look_at(p, BossStalk.head_point(b))
		_tick(main)
		t_hold += DT
		hung = hung or b.state == "hang"
	ok(held_then < hang_s and no_wind and hung and b.strike.wind_ups > wind0 and held_then + t_hold >= hang_s - 0.15, "your torch lit, turned on it after %.1f s of stalking (hang_s %.1f): your flame holds it first (the hold as built), its wind-up %.1f s later" % [held_then, hang_s, t_hold])
	main.harm.reset()
	# Keep walking: it lets you go when its dwell ends.
	# (Its rounds next, a weight so slight the ambush comes first.)
	setup = _ambush_setup(main, {"coil_ambush": {"dwell_s": [3.0, 3.0]}, "rounds": {"weight": 0.0001}}, true, 12.0)
	u = b.pool.unit("coil_ambush")
	walk = setup[0]
	s = float(setup[1])
	var length := TombNav.length_of(walk)
	_until_lying(main, u)
	var lying := str(u.get("phase")) == "lie"
	wind0 = b.strike.wind_ups
	var t3 := 0.0
	while t3 < 8.0 and b.behaviour == "coil_ambush":
		s = minf(s + 1.3 * DT, length - 0.2)
		var here: Array = _along(walk, s)
		p.global_position = here[0]
		_look_along(p, here[1])
		_tick(main)
		t3 += DT
	var let_go := str(u.get("ended_by")) == "let_go" and b.let_go_t > 0.0
	# Let go, nothing of it that goes after you may come straight back.
	var ou := BossPool.make_unit("observe_then_behind")
	var stalk_blocked := let_go and not BossStalk.may_stalk(b) and not u.can_enter(b) and ou != null and not ou.can_enter(b)
	var taken_up := false
	var t4 := 0.0
	var lg := float(def.get("let_go_s", 8.0))
	while t4 < lg - 0.5:
		_tick(main)
		t4 += DT
		taken_up = taken_up or b.noticed or b.state in ["hunt", "hang", "strike", "watch"]
	ok(lying and let_go and b.strike.wind_ups == wind0 and not taken_up, "you keep walking: it lets you go when its dwell ends (%.1f s; no wind-up), and its rounds don't take you up for let_go_s (%.0f s, your torch lit %.1f m off)" % [t3, lg, BossStalk.to_you(b)])
	ok(stalk_blocked, "let go, neither the ambush nor observe_then_behind may come straight back for you while let_go_s lasts")
	_sim(main, 1.0)
	ok(b.let_go_t <= 0.0 and BossStalk.may_stalk(b) and u.can_enter(b), "once let_go_s is over they may come again (you on its floor)")
	main.harm.reset()


## You turn toward it in one tick (from your back to it): its wind-up begins
## on that tick with its tell, and the hit that follows is one hit.
func _turn_strikes(main: CrawlerMain, u: BossState, how: String, want_hit: bool) -> void:
	var b := main.boss
	var p := main.player
	var lying := str(u.get("phase")) == "lie"
	var back := BossStalk.angle_from_look(b, b.head)
	main.harm.reset()
	p._invulnerable = 0.0
	var landed0 := main.harm.landed
	var hits0 := b.hits_landed
	var wind0 := b.strike.wind_ups
	_look_at(p, BossStalk.head_point(b))
	var clock0 := b.clock
	_tick(main)
	var on_tick := b.strike.wind_ups == wind0 + 1 and b.strike.state == "wind_up" and is_equal_approx(float(u.get("turned_at")), b.clock) and b.state == "strike"
	var tell := b.strike.sound != "" and b.strike.tell_frame == b.strike.wind_up_frame
	var d := BossStalk.to_you(b)
	_sim(main, b.strike.wind_up_s + b.strike.strike_s + b.strike.recover_s + 0.3)
	var hits := main.harm.landed - landed0
	ok(lying and back > BossStalk.BEHIND_DEG and on_tick and tell and bool(u.get("struck_on_turn")), "%s, lying behind you (%.0f degrees), you turn toward it: its wind-up begins on that tick (clock %.3f), its tell (%s) with it, %.1f m off" % [how, back, clock0 + DT, b.strike.sound, d])
	if want_hit:
		ok(hits == 1 and b.hits_landed - hits0 == 1 and not main.harm.taking, "the hit that follows counts as one hit (%d of three; Harm.landed %d), never more" % [hits, main.harm.landed])
	main.harm.reset()
	await process_frame


# --- 7. Loose ------------------------------------------------------------------------------

func _loose(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var def := _entry("freeze_watched")
	ok(b.pool != null and b.pool.ids.size() == 5, "its whole pool from the file: %s" % str(b.pool.ids if b.pool != null else []))
	# You: up and down the dark way home from its dead end, your torch lit,
	# nothing reaching you (the rule's own checks are the boss check's).
	_relay(main)
	var walk := _walk_from_snake(main)
	var length := TombNav.length_of(walk)
	_torch_on(p)
	p._invulnerable = 1.0e6
	var s := clampf(length * 0.6, 0.0, length)
	var dir := -1.0
	var here: Array = _along(walk, s)
	p.spawn_flat(here[0], 0.0, 0.0)
	_mo_reset(b)
	var lit0 := b.lit_entries
	var n0 := b.draw_log.size()
	var entered := {}
	var freezes_ok := true
	var freezes := 0
	var relit := 0
	var t := 0.0
	var frozen_was := false
	var i := 0
	while t < LOOSE_S:
		# Your torch lit, then out (sneaking in the dark), 40 s each, so its
		# own states get their turns between the chases.
		if int(t / 40.0) % 2 == 0:
			_torch_on(p)
		else:
			_torch_off(p)
		# Walk a while, stand a while, turn now and then.
		if i % 600 < 420:
			s += dir * 1.6 * DT
			if s <= 0.5 or s >= length - 0.5:
				dir = -dir
				s = clampf(s, 0.5, length - 0.5)
		here = _along(walk, s)
		p.global_position = here[0]
		var fwd: Vector3 = here[1] * dir
		if i % 300 > 240:
			fwd = -fwd
		_look_along(p, fwd)
		if i == int(60.0 / DT) or i == int(130.0 / DT):
			relit += _light_room_near(main, p.global_position)
		_tick(main)
		t += DT
		i += 1
		if b.behaviour != "":
			entered[b.behaviour] = int(entered.get(b.behaviour, 0)) + 1
		var frozen := b.behaviour == "freeze_watched"
		if frozen and not frozen_was:
			freezes += 1
			var u: BossState = b.pool.unit("freeze_watched")
			var seen: Variant = u.get("seen_by")
			if not seen is Vector3:
				freezes_ok = false
			else:
				var e := BossStalk.eye(b)
				if rad_to_deg(BossStalk.axis(b).angle_to((seen as Vector3) - e)) > float(def.get("look_deg", 25.0)) + 0.5 or BossStalk.nearest_part_m(b) < float((def.get("from_m", [12.0]) as Array)[0]) - 0.05:
					freezes_ok = false
		frozen_was = frozen
	var bad := 0
	for k in range(mini(n0, b.draw_log.size()), b.draw_log.size()):
		var e2: Dictionary = b.draw_log[k]
		if str(e2.state) in Boss.RULE_MOMENTS or str(e2.strike) != "ready" or bool(e2.tunnel):
			bad += 1
	var shares: Array = []
	for k in entered:
		shares.append("%s %.0f s" % [k, float(entered[k]) * DT])
	print("  loose %.0f s: in charge %s; %d draws, %d freezes, %d rooms relit, %d chases' hits" % [LOOSE_S, ", ".join(PackedStringArray(shares)), b.pool.draws, freezes, relit, b.strike.wind_ups])
	ok(b.lit_entries == lit0, "it never walks into a lit room or stretch of its own accord (%d times), %d rooms relit round its dark" % [b.lit_entries - lit0, relit])
	_mo_ok("loose with its whole pool")
	ok(int(_mo.new_over) == 0, "the new states never step faster than hunt_mps (their fastest %.2f m/s)" % float(_mo.new_worst))
	ok(bad == 0, "no draw in the rule's moments (%d of %d draws and cut-ins)" % [bad, b.draw_log.size() - n0])
	ok(freezes_ok, "every freeze began watched (%d)" % freezes)
	p._invulnerable = 0.0


## The holders of the dark room nearest `at` (by its centre), lit: how many
## rooms (0 or 1).
func _light_room_near(main: CrawlerMain, at: Vector3) -> int:
	var b := main.boss
	var best := -1
	var best_d := INF
	for id in range(b.ground.nodes.size()):
		var n: Dictionary = b.ground.nodes[id]
		if str(n.kind) != "room" or not b.ground.is_ground(id) or (n.holders as Array).is_empty():
			continue
		var d := BossStalk.flat_d(n.center, at)
		if d < best_d:
			best_d = d
			best = id
	if best < 0:
		return 0
	for h in b.ground.nodes[best].holders:
		_light_holder(main, main.fires.holders[int(h)])
	return 1
