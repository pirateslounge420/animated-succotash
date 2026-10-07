extends SceneTree
## Cleared by light (design 6 Oct §FF.2; queue 59): the tomb's skeletons
## kept to the dark, biting from its pockets, and gone for good when the
## last light catches (Residents, Resident, on queue 49's graph;
## residents.json rules, crawler.json cleared), headless:
##   SEEDS=1,7,42 godot --headless --path . --fixed-fps 60 --script tools/cleared_check.gd
## For each seed (1, 7 and 42 unless SEEDS says), the snake held still
## (Boss.auto false) until the last light. The skeletons move only while
## you can't see them (Mike's 7 Oct note; Resident.holds_still), so where a
## test wants one to come to you, your back is turned:
##  1. the light's edge: a skeleton hunting you, its strike not landed,
##     comes to the edge of its dark while you stand in the lit hearth room,
##     your back to it, never a step into the light and no strike at you
##     there; you turn round and it stands frozen at the edge, watching
##     you, and gives you up all the same edge_watch_s after it got there
##     ("light"), and keeps to the dark;
##  2. the chase into the light (§FD): one that has hit you follows you
##     into the lit hearth room, your back to it; given up there (you far
##     off), it is back in the dark within back_to_dark_s;
##  3. a dark pocket's bite (it moves in plain view: you got right up on
##     it): one hanging back in a dark pocket lets you be, still, at
##     pocket_counterattack_m + 1 m; a scripted walk in to 2 m, looking at
##     it, draws a strike with its wind-up (its tell from the wind-up's
##     first frame), lunging in as it winds up, and the hit lands at the end
##     of its committed strike; the same walk again, your lit torch's swing
##     at half its wind-up staggers it and no hit lands;
##  3b. cut off where you can see it (below): it stands where it is while
##     you watch it, and the moment you look away it is into the stone; it
##     comes up below_s later in the dark, out of your sight;
##  4. a scripted run relighting every holder (the layout's order, the
##     heart's own lights last, so it is the last dark), you by each with
##     your torch lit and then a while,
##     the skeletons free (nothing takes you on this run): no resident
##     stands in a lit room or stretch unless it is chasing you, but on its
##     way out of one (climbing out of a relit place, leaving) and for no
##     longer than rise_s + back_to_dark_s of the time it could move (not
##     held still in your view, nor stopped short of it); skeletons resting
##     in relit rooms fall back into the dark pockets; and none beyond its
##     reach, outside its strike and the last light's going, moves, turns
##     or changes its pose on a frame you could see it in;
##  5. the last light: the floor is cleared and the log has its line once,
##     after the count of lights; every resident has gone within
##     cleared.retreat_seen_s (the ones in view seen going back into the
##     stone, the rest at once), none left on the roll or in the scene; over
##     5 minutes more none returns (no resident, no strike of theirs in
##     play, nothing pursuing you, no hit); the snake's release still plays
##     (it goes home, its log line).

var fails := 0
var main: CrawlerMain
var player: CrawlerPlayer
var res: Residents
var _floor: StaticBody3D
const DT := 1.0 / 60.0
## The test floor: far under and away from the tomb, off its floor grid
## (somewhere to stand far from everything, for a chase to end).
const TEST_Y := -300.0
const TEST_XZ := Vector2(1000.0, 1000.0)


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
	var seeds: Array = [1, 7, 42]
	if OS.get_environment("SEEDS") != "":
		seeds = []
		for s in OS.get_environment("SEEDS").split(","):
			seeds.append(int(s))
	for s in seeds:
		print("== seed %d" % s)
		await _seed(int(s))
	Residents.stay_asleep = false
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _seed(s: int) -> void:
	Residents.stay_asleep = true
	OS.set_environment("SEED", str(s))
	main = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked:
		await process_frame
	player = main.player
	res = main.residents
	main.boss.auto = false
	_test_floor()
	ok(res.ground != null and res.all.size() >= 1 and not res.cleared, "the residents keep the tomb's light (%d nodes, %d dark) and %d skeletons rest in it" % [res.ground.nodes.size() if res.ground else 0, res.ground.ground_count() if res.ground else 0, res.all.size()])
	Residents.stay_asleep = false
	await _edge()
	await _settle()
	await _into_light()
	await _settle()
	await _pocket()
	await _settle()
	await _cut_off()
	await _settle()
	await _relight_run()
	Residents.stay_asleep = true
	main.queue_free()
	await process_frame
	await process_frame


func _rule(k: String, dflt: float) -> float:
	return Residents.rule(k, dflt)


func _test_floor() -> void:
	_floor = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 2.0, 400.0)
	cs.shape = box
	_floor.add_child(cs)
	_floor.position = Vector3(TEST_XZ.x, TEST_Y - 1.0, TEST_XZ.y)
	main.add_child(_floor)


## Everyone back at rest, nothing after you, unhurt, standing at the mat.
func _settle() -> void:
	Input.action_release("crouch")
	for r in res.all:
		r._disarm()
		r.pursuit.give_up()
		r.state = Resident.REST
		r.t = 0.0
		r.global_position = r.place.pos
		r.yaw = float(r.place.yaw)
		r.sensed_by = ""
		r.hidden = false
		r.gave_up_why = ""
		r.last_known = Vector3.INF
		r._lie_from = Vector3.INF
		r._falling_back = false
		r.lunging = false
		r._edge_t = 0.0
		r.pocket = Vector3.INF
		r.pocket_node = -1
		r._for_good = true
		r.seen_going = false
		r.came_up = 0
		r.armed = false
		r.still = false
		r._told = false
		r._rphase = ""
		r.set_physics_process(true)
		if r.sprite != null:
			r.sprite.visible = true
		r._show_pose()
	main.harm.reset()
	main.harm._last_hit = -INF
	player._invulnerable = 0.0
	if player.dead:
		player.revive()
		player._invulnerable = 0.0
	var w: Array = main.lay.wake
	player.spawn_flat(w[0], float(w[1]), -0.32)
	await _frames(12)


## A torch in your hand (from the pack), lit or not.
func _torch(lit: bool) -> void:
	if not player.inventory.has_kind("torch"):
		player.inventory.add(Inventory.make("torch"))
	player.weapon = "torch"
	if lit and not player.torch.lit():
		player.torch.light()
	elif not lit and player.torch.lit():
		player.torch.put_out("stowed")


## `r` up and hunting you at `at` (on the floor there), facing `face`, its
## strike ready.
func _hunt_at(r: Resident, at: Vector3, face: Vector3) -> void:
	var fy := res.nav.floor_at(at)
	r.global_position = Vector3(at.x, fy if not is_nan(fy) else at.y, at.z)
	r._arm()
	r.strike.cancel()
	r.state = Resident.HUNT
	r.t = 0.0
	r.sensed_by = ""
	r.hidden = false
	r.last_known = r.global_position
	r.path = PackedVector3Array()
	r._path_to = Vector3.INF
	r.yaw = TombKit.yaw_facing(Vector2(face.x - at.x, face.z - at.z))
	r.pursuit.notice(player.torch.lit())


func _place_facing(at: Vector3, target: Vector3) -> void:
	var flat := Vector3(target.x - at.x, 0.0, target.z - at.z)
	player.spawn_flat(at, atan2(-flat.x, -flat.z), -0.1)


## Look at `r` (its middle) from where you stand.
func _look_at(r: Resident) -> void:
	var pts := r.view_points()
	var mid: Vector3 = pts[1] if pts.size() > 1 else r.global_position + Vector3(0.0, 0.8, 0.0)
	var d := mid - player.camera().global_position
	player.set_view(atan2(d.y, Vector2(d.x, d.z).length()), atan2(-d.x, -d.z))


## A doorway out of the hearth room: {"door", "out" (Vector3, flat, from
## the hearth room into the corridor), "mid" (the door's middle on its
## floor), "cor" (the corridor piece)}.
func _hearth_door() -> Dictionary:
	var lay := main.lay
	for di in lay.pieces[0].doors:
		var d: Dictionary = lay.doors[di]
		var other := int(d.b) if int(d.a) == 0 else int(d.a)
		var cor: Dictionary = lay.pieces[other]
		if str(cor.kind) != "corridor" or float(cor.len) < 4.5:
			continue
		var n: Vector2 = (d.n as Vector2) * (1.0 if int(d.a) == 0 else -1.0)
		return {"door": d, "out": Vector3(n.x, 0.0, n.y), "mid": Vector3((d.p as Vector2).x, float(d.y), (d.p as Vector2).y), "cor": cor}
	return {}


## The point `m` metres from the door's middle (out into the corridor if
## positive, into the hearth room if negative), on the floor there.
func _from_door(hd: Dictionary, m: float) -> Vector3:
	var p: Vector3 = (hd.mid as Vector3) + (hd.out as Vector3) * m
	var fy := res.nav.floor_at(p)
	return Vector3(p.x, fy if not is_nan(fy) else p.y, p.z)


## The skeleton the tests use: the first on the roll.
func _one() -> Resident:
	return res.all[0] if not res.all.is_empty() else null


# --- 1. The light's edge -----------------------------------------------------------

func _edge() -> void:
	var hd := _hearth_door()
	var r := _one()
	if hd.is_empty() or r == null:
		ok(false, "a corridor out of the hearth room and a skeleton for the light's edge")
		return
	# You farther in than its reach from the doorway, so at the edge it is
	# still a step beyond reach (it holds still while you look at it).
	var you := _from_door(hd, -2.6)
	var it := _from_door(hd, 3.5)
	ok(not res.dark_at(you) and res.dark_at(it), "you in the lit hearth room 2.6 m in from a doorway, a skeleton 3.5 m out in the dark corridor beyond it")
	_torch(true)
	# Your back to it.
	_place_facing(you, you + (you - it))
	_hunt_at(r, it, you)
	var w0 := r.strike.wind_ups
	var hits0 := main.harm.landed
	var in_light := 0
	var closest := INF
	var held_at := -1.0
	var gave := -1.0
	var at_edge := Vector3.INF
	var drift := 0.0
	var t := 0.0
	var watch := _rule("edge_watch_s", 6.0)
	while t < watch + 8.0:
		await physics_frame
		t += DT
		if r.gave_up_why == "" and not res.dark_at(r.global_position):
			in_light += 1
		closest = minf(closest, Vector2(r.global_position.x - hd.mid.x, r.global_position.z - hd.mid.z).length())
		if held_at < 0.0 and r._edge_t > 0.0:
			held_at = t
			# You turn round to it: it stands there, watching you.
			_look_at(r)
			at_edge = r.global_position
		if at_edge != Vector3.INF:
			drift = maxf(drift, r.global_position.distance_to(at_edge))
		if gave < 0.0 and r.gave_up_why != "":
			gave = t
			break
	ok(in_light == 0 and r.strike.wind_ups == w0 and main.harm.landed == hits0, "hunting you, its strike not landed, it never steps into the light (%d frames) and no strike comes at you there (%d wind-ups, %d hits)" % [in_light, r.strike.wind_ups - w0, main.harm.landed - hits0])
	ok(closest <= 1.0, "your back to it, it comes to the edge of its dark: %.2f m from the doorway's middle at its closest" % closest)
	ok(gave > 0.0 and held_at > 0.0 and r.gave_up_why == "light" and absf(gave - held_at - watch) <= 0.25 and drift == 0.0, "you turn round as it reaches the edge: it stands frozen there (moved %.4f m) watching you for edge_watch_s %.0f s, then gives you up (held at %.2f s, gave you up at %.2f s, %s)" % [drift, watch, held_at, gave, r.gave_up_why])
	await _frames(int(2.0 / DT))
	ok(not r.pursuit.on and res.dark_at(r.global_position) and r.state in [Resident.LURK, Resident.RETURN, Resident.LYING, Resident.REST], "given up, it is no one's pursuer and keeps to the dark (%s)" % r.state_name())


# --- 2. The chase into the light --------------------------------------------------

func _into_light() -> void:
	var hd := _hearth_door()
	var r := _one()
	if hd.is_empty() or r == null:
		ok(false, "a corridor out of the hearth room and a skeleton for the chase into the light")
		return
	_torch(true)
	var you := _from_door(hd, 1.2)
	var it := _from_door(hd, 2.4)
	_place_facing(you, it)
	_hunt_at(r, it, you)
	var hits0 := main.harm.landed
	var t := 0.0
	while main.harm.landed == hits0 and t < 4.0:
		await physics_frame
		t += DT
	ok(main.harm.landed == hits0 + 1 and r.chasing(), "in the dark its strike lands (%.2f s): its chase has its teeth in you" % t)
	# Nothing more lands on this test.
	player._invulnerable = 1.0e9
	var inside := _from_door(hd, -3.0)
	# Into the lit hearth room, your back to it.
	_place_facing(inside, inside + (inside - it))
	var followed := false
	t = 0.0
	while t < 4.0 and not followed:
		await physics_frame
		t += DT
		if r.chasing() and not res.dark_at(r.global_position):
			followed = true
	ok(followed, "you step into the lit hearth room, your back to it, and it follows you in (%.2f s; §FD, chase_enters_light)" % t)
	# You far off: it gives you up there, in the light.
	player.spawn_flat(Vector3(TEST_XZ.x, TEST_Y, TEST_XZ.y), 0.0, 0.0)
	var gave := -1.0
	var back := -1.0
	t = 0.0
	while t < 10.0 and back < 0.0:
		await physics_frame
		t += DT
		if gave < 0.0 and r.gave_up_why != "":
			gave = t
		if gave >= 0.0 and res.dark_at(r.global_position):
			back = t - gave
	var b2d := _rule("back_to_dark_s", 4.0)
	ok(gave >= 0.0 and back >= 0.0 and back <= b2d + 0.1, "given up in the light (%s), it is back in the dark %.2f s later (back_to_dark_s %.0f; it went at %.1f m/s)" % [r.gave_up_why, back, b2d, r._leave_mps])
	player._invulnerable = 0.0


# --- 3. A dark pocket's bite ----------------------------------------------------------

## A dark room's line to walk in on a resident hanging back there: {"node",
## "spot" (where it stands), "from" (you, pocket_counterattack_m + 1 m off)}
## with every quarter metre between on open floor in the dark.
func _pocket_line() -> Dictionary:
	var lay := main.lay
	var far := _rule("pocket_counterattack_m", 3.0) + 1.0
	for pc in lay.pieces:
		if str(pc.kind) != "room" or str(pc.get("room_kind", "")) == "hearth" or float(pc.len) < far + 1.6:
			continue
		var id := int((res.ground.by_piece[int(pc.id)] as Array)[0])
		for across: float in [1.0, -1.0, 1.6, -1.6, 0.4]:
			if absf(across) > float(pc.half) - 0.6:
				continue
			for ends: Array in [[0.8, 0.8 + far], [float(pc.len) - 0.8, float(pc.len) - 0.8 - far]]:
				var spot := BossGround.point(pc, float(ends[0]), across)
				var from := BossGround.point(pc, float(ends[1]), across)
				var good := true
				for k in int(far / 0.25) + 1:
					var q := spot.lerp(from, minf(k * 0.25 / far, 1.0))
					if not res.nav.is_open(res.nav.cell_of(q)) or not res.dark_at(q):
						good = false
						break
				if good:
					return {"node": id, "spot": spot, "from": from, "piece": int(pc.id)}
	return {}


## `r` hanging back at `spot` in node `id`.
func _lurk_at(r: Resident, id: int, spot: Vector3) -> void:
	r.pursuit.give_up()
	r.global_position = spot
	r._start_lurk(id)
	r.pocket = spot
	if r.strike != null:
		r.strike.cancel()
		r.strike.cooldown_left = 0.0


## Walk you in on `spot` from where you stand at 2.5 m/s until you are
## `stop` m off; `each` (a Callable) is asked after every frame and the walk
## ends early when it returns true.
func _walk_in(spot: Vector3, stop: float, each: Callable) -> void:
	var step := 2.5 * DT
	for i in 600:
		var p := player.global_position
		var to := Vector2(spot.x - p.x, spot.z - p.z)
		if to.length() > stop:
			var nxt := p + Vector3(to.x, 0.0, to.y).normalized() * minf(step, to.length() - stop)
			var fy := res.nav.floor_at(nxt)
			_place_facing(Vector3(nxt.x, fy if not is_nan(fy) else nxt.y, nxt.z), spot)
		await physics_frame
		if bool(each.call()):
			return
		if to.length() <= stop:
			return


func _pocket() -> void:
	var line := _pocket_line()
	var r := _one()
	if line.is_empty() or r == null:
		ok(false, "a dark room with a straight walk in on a pocket")
		return
	_torch(true)
	var spot: Vector3 = line.spot
	var from: Vector3 = line.from
	var cm := _rule("pocket_counterattack_m", 3.0)
	_place_facing(from, spot)
	_lurk_at(r, int(line.node), spot)
	await _frames(int(2.0 / DT))
	var w0 := r.strike.wind_ups
	ok(r.state == Resident.LURK and r.strike.wind_ups == w0 and r.global_position.distance_to(spot) < 0.35 and not r.pursuit.on, "hanging back in a dark pocket (piece %d), it lets you be at %.1f m, pocket_counterattack_m + 1 m (%s, no one's pursuer)" % [int(line.piece), Vector2(from.x - spot.x, from.z - spot.z).length(), r.state_name()])
	# Walk in to 2 m (what the walk sees, in a dictionary: a lambda keeps
	# its own copies of plain locals).
	var seen := {"began_at": -1.0, "lunging": false}
	var hits0 := main.harm.landed
	await _walk_in(spot, 2.0, func() -> bool:
		if float(seen.began_at) < 0.0 and r.strike.wind_ups > w0:
			seen.began_at = Vector2(player.global_position.x - r.global_position.x, player.global_position.z - r.global_position.z).length()
			seen.lunging = r.lunging
		return false)
	var began_at := float(seen.began_at)
	var cs := r.strike
	# Then stand: the rest of its wind-up and its strike.
	var start := Engine.get_physics_frames()
	var closest := INF
	var landed_frame := -1
	while landed_frame < 0 and Engine.get_physics_frames() - start < 120:
		await physics_frame
		closest = minf(closest, Vector2(player.global_position.x - r.global_position.x, player.global_position.z - r.global_position.z).length())
		if main.harm.landed != hits0:
			landed_frame = Engine.get_physics_frames()
	ok(began_at > 0.0 and began_at <= cm + 0.05 and bool(seen.lunging) and cs.tell_frame == cs.wind_up_frame, "a scripted walk in draws its strike with its wind-up: it began with you %.2f m off (pocket_counterattack_m %.1f), its tell (%s) from the wind-up's first frame (frame %d, the wind-up's %d)" % [began_at, cm, cs.sound, cs.tell_frame, cs.wind_up_frame])
	ok(closest < 2.0 - 0.3 and closest <= cs.reach_m, "it lunges in as it winds up: you stopped 2 m off and it came to %.2f m (reach_m %.1f)" % [closest, cs.reach_m])
	var landed_s := float(landed_frame - cs.wind_up_frame) * DT
	var want := cs.wind_up_s + cs.strike_s
	ok(landed_frame > 0 and main.harm.landed == hits0 + 1 and absf(landed_s - want) <= 2.5 * DT, "the hit lands at the end of its committed strike: %.2f s after the wind-up began (wind_up_s %.2f, strike_s %.2f)" % [landed_s, cs.wind_up_s, cs.strike_s])
	# Again, and your lit torch's swing at half its wind-up.
	main.harm.reset()
	main.harm._last_hit = -INF
	player._invulnerable = 0.0
	_place_facing(from, spot)
	_lurk_at(r, int(line.node), spot)
	await _frames(int(1.0 / DT))
	hits0 = main.harm.landed
	var swing := {"did": ""}
	await _walk_in(spot, 2.0, func() -> bool:
		if r.strike != null and r.strike.winding_up() and r.strike.t >= r.strike.wind_up_s * 0.5 and str(swing.did) == "":
			swing.did = player.torch.swing_top()
			return true
		return false)
	var t := 0.0
	while str(swing.did) == "" and t < 2.0:
		await physics_frame
		t += DT
		if r.strike != null and r.strike.winding_up() and r.strike.t >= r.strike.wind_up_s * 0.5:
			swing.did = player.torch.swing_top()
	await _frames(int(1.5 / DT))
	ok(str(swing.did) == "staggered" and main.harm.landed == hits0 and r.strike.staggers >= 1, "the same walk again: your lit torch's swing at half its wind-up staggers it (%s, met at %.2f of it), and no hit lands (%d)" % [swing.did, r.strike.met_at_share, main.harm.landed - hits0])


# --- 3b. Cut off: into the stone, seen, and up in the dark elsewhere --------------

func _cut_off() -> void:
	# One standing before its own niche (or grave), you watching it from 1 m
	# farther off than its counterattack, in its dark room.
	var r: Resident = null
	var spot := Vector3.INF
	var you := Vector3.INF
	var far := _rule("pocket_counterattack_m", 3.0) + 1.0
	for q in res.all:
		var out: Vector3 = q.place.out
		var inward := Vector3(out.x - (q.place.pos as Vector3).x, 0.0, out.z - (q.place.pos as Vector3).z).normalized()
		for m: float in [far, far - 0.4, far + 0.5]:
			var at := out + inward * m
			var fy := res.nav.floor_at(at)
			if is_nan(fy) or not res.nav.is_open(res.nav.cell_of(at)) or not res.dark_at(at):
				continue
			r = q
			spot = out
			you = Vector3(at.x, fy, at.z)
			break
		if r != null:
			break
	if r == null:
		ok(false, "a skeleton with room before its place to watch it go into the stone from")
		return
	_torch(false)
	_place_facing(you, spot)
	_lurk_at(r, res.node_of(spot), spot)
	await _frames(int(1.0 / DT))
	_look_at(r)
	await _frames(2)
	var seen0 := res.watched(r)
	var pos0 := r.global_position
	# Cut off where you can see it (Mike's 7 Oct note: it goes only unseen):
	# it stands where it is while you watch it.
	r.retreat(false)
	var held := r.state == Resident.RETREAT and r._rphase == "held"
	var drift := 0.0
	var t := 0.0
	var watch := 3.0
	while t < watch:
		await physics_frame
		t += DT
		drift = maxf(drift, r.global_position.distance_to(pos0))
		if r.state != Resident.RETREAT or r._rphase != "held":
			held = false
	ok(seen0 and held and drift == 0.0 and r.sprite.visible and not r.seen_going and not r.pursuit.on and res.all.has(r), "cut off where you can see it, it stands where it is all %.0f s you watch it (moved %.4f m; %s, %s), no one's pursuer: nothing of its going is seen (it was, before Mike's 7 Oct note)" % [watch, drift, r.state_name(), r._rphase])
	# You look away: into the stone at once.
	var away := r.global_position - player.global_position
	player.set_view(-0.1, atan2(away.x, away.z))
	var went_below := -1.0
	t = 0.0
	while t < 1.0 and went_below < 0.0:
		await physics_frame
		t += DT
		if r.state == Resident.BELOW:
			went_below = t
	ok(went_below > 0.0 and went_below <= 2.5 * DT and r.global_position.distance_to(pos0) < 0.001, "you look away and it is into the stone at once, where it stood (%.2f s)" % went_below)
	ok(r.state == Resident.BELOW and (r.sprite == null or not r.sprite.visible) and r.strike == null and not r.pursuit.on and res.all.has(r), "in the stone it is out of sight, nothing to swing at, no one's pursuer, and still on the roll (below, not gone for good)")
	# You walk off (out of the room); it comes up in the dark nearest it, out
	# of your sight, below_s later.
	var w: Array = main.lay.wake
	player.spawn_flat(w[0], float(w[1]), -0.32)
	var b: Array = Residents.RULES.get("below_s", [6.0, 12.0])
	var up := -1.0
	t = 0.0
	while t < float(b[1]) + 3.0 and up < 0.0:
		await physics_frame
		t += DT
		if r.state != Resident.BELOW:
			up = t
	var d_you := Vector2(r.global_position.x - player.global_position.x, r.global_position.z - player.global_position.z).length()
	ok(up >= float(b[0]) - DT and up <= float(b[1]) + 2.5 and r.state == Resident.LURK and r.came_up == 1 and res.dark_at(r.global_position) and r.sprite.visible and not res.seen_at(r.global_position, r.creep()) and d_you >= _rule("pocket_counterattack_m", 3.0) * 2.0 - 0.05, "and comes up %.2f s later (below_s %s) in the dark (node %d), out of your sight (its creep's test), %.1f m from you, to hang back there (%s)" % [up, str(b), res.node_of(r.global_position), d_you, r.state_name()])


# --- 4 and 5. Every holder relit, then the last -------------------------------------

## Where to stand to light holder `h`: a step out from a sconce's wall, a
## step back toward the room's way in from a hearth ring.
func _stand_by(h: Node3D) -> Vector3:
	var at := h.global_position
	var piece: Dictionary = main.lay.pieces[int(h.get_meta("piece"))]
	if str(h.get_meta("fire_holder")) == "sconce":
		return Vector3(at.x, at.y - float(CrawlerFires.HOLD.get("sconce_h_m", 1.7)), at.z) + h.global_basis.z * 0.8
	var d: Vector2 = piece.dir
	return Vector3(at.x - d.x, float(piece.y0), at.z - d.y)


func _light_holder(h: Node3D) -> void:
	FireStore.swing_light(h, float(main.world.get("days")))
	for i in 600:
		FireStore.tick(self, 1.0 / 60.0, h.global_position)
		if FireStore.is_lit(h):
			return


## What the run saw (_track).
var _t_light := {}
var _worst := 0.0
var _bad := 0
var _bad_seen := {}
var _fell_back := {}
var _lurked := {}
var _bites := 0
var _bite_was := {}
var _chased_in := 0
var _held_light := 0
var _short := {}
## The rule (Mike's 7 Oct note): each one as the last frame ended (by
## instance id: place, turn, pose, view points, state, going at the last
## light), and the tally.
var _was := {}
var _boo := {}


## One frame of the run: no resident in a lit room or stretch unless it is
## chasing you, or on its way out (climbing out of a relit place, leaving,
## going for good) and not for long (counting only the frames it could
## move: not held still in your view, nor stopped short of it); and none
## seen moving (_boo_track).
func _track() -> void:
	_boo_track()
	for r in res.all:
		# In the stone (cut off, below) it stands nowhere.
		if not is_instance_valid(r) or r.state == Resident.BELOW:
			continue
		var nm := str(r.name)
		var short := int(_short.get(nm, r.stopped_short)) != r.stopped_short
		_short[nm] = r.stopped_short
		if r._falling_back or r.state == Resident.LEAVE:
			_fell_back[nm] = true
		if r.state == Resident.LURK:
			_lurked[nm] = true
		if r.strike != null and r.lunging and r.strike.wind_ups != int(_bite_was.get(nm, -1)):
			_bite_was[nm] = r.strike.wind_ups
			_bites += 1
		var lit := not res.dark_at(r.global_position)
		if lit and r.chasing():
			_chased_in += 1
		if not lit or r.chasing():
			_t_light[nm] = 0.0
			continue
		var going := r.state == Resident.LEAVE or (r.state == Resident.RISING and r._falling_back) or r.state == Resident.RETREAT
		if r.still or short:
			# Held in your view (or just short of it): it goes once you look
			# away, so this frame isn't counted against it.
			_held_light += 1
		else:
			_t_light[nm] = float(_t_light.get(nm, 0.0)) + DT
		if r.state != Resident.RETREAT:
			_worst = maxf(_worst, float(_t_light[nm]))
		if not going:
			_bad += 1
			if not _bad_seen.has(nm):
				_bad_seen[nm] = true
				print("  %s in the light outside a chase: %s at %s (node %d)" % [nm, r.state_name(), str(r.global_position), res.node_of(r.global_position)])


## The rule over the run (Mike's 7 Oct note; residents_check's log, in
## short): for the frame just stepped (the camera still as it stood for that
## step), a skeleton that changed its place, turn or pose must not have
## been where you could see it (Residents.points_watched) as the frame began
## or as it ended; let off in its strike, within its strike's reach and
## going at the last light.
func _boo_track() -> void:
	var you := player.global_position
	for r in res.all:
		if not is_instance_valid(r):
			continue
		var id := r.get_instance_id()
		var now := {"pos": r.global_position, "yaw": r.yaw, "pose": r.sprite.pose if r.sprite != null else -1, "pts": r.view_points(), "state": r.state, "last": r.state == Resident.RETREAT and r._for_good}
		var was: Dictionary = _was.get(id, {})
		_was[id] = now
		if was.is_empty():
			continue
		_boo.logged += 1
		var moved := (now.pos as Vector3).distance_to(was.pos) > 1e-5 or absf(wrapf(float(now.yaw) - float(was.yaw), -PI, PI)) > 1e-5 or int(now.pose) != int(was.pose)
		var seen := res.points_watched(was.pts, r.creep()) or res.points_watched(now.pts, r.creep())
		var reach := r.strike.reach_m if r.strike != null else float(r.strike_def().get("reach_m", 1.6))
		var near := false
		for at: Vector3 in [was.pos, now.pos]:
			if Vector2(at.x - you.x, at.z - you.z).length() <= reach and absf(you.y - at.y) < 1.2:
				near = true
		var let_off := int(was.state) == Resident.STRIKING or int(now.state) == Resident.STRIKING or bool(was.last) or bool(now.last) or near
		if not moved:
			if seen and not let_off and int(now.state) != Resident.REST:
				_boo.held += 1
			continue
		_boo.moved += 1
		if let_off:
			_boo.let_off += 1
		elif seen:
			_boo.bad += 1
			if _boo.bad <= 5:
				print("  SEEN MOVING: %s %s -> %s, %s to %s" % [r.name, Resident.STATE_NAMES[int(was.state)], Resident.STATE_NAMES[int(now.state)], str(was.pos), str(now.pos)])


func _relight_run() -> void:
	_t_light = {}
	_worst = 0.0
	_bad = 0
	_bad_seen = {}
	_fell_back = {}
	_lurked = {}
	_bites = 0
	_bite_was = {}
	_chased_in = 0
	_held_light = 0
	_short = {}
	_was = {}
	_boo = {"logged": 0, "moved": 0, "held": 0, "let_off": 0, "bad": 0}
	var fires := main.fires
	var heart := int(main.lay.get("heart", -1))
	var order: Array = []
	var last: Array = []
	for h in fires.holders:
		if int(h.get_meta("piece")) == heart:
			last.append(h)
		else:
			order.append(h)
	order.append_array(last)
	var n0 := res.all.size()
	_torch(true)
	# Nothing takes you on this run: their strikes still reach you (so their
	# chases may follow you into the light), Harm counts none.
	player._invulnerable = 1.0e9
	var log0 := GameLog.entries.size()
	var rise := float(res.creature("skeleton").get("rise_s", 1.6))
	var b2d := _rule("back_to_dark_s", 4.0)
	for k in order.size():
		var h: Node3D = order[k]
		if k == order.size() - 1:
			break
		_place_facing(_stand_by(h), h.global_position)
		_light_holder(h)
		for i in int(6.0 / DT):
			await physics_frame
			_track()
	# The walk to the last light: long enough for any the light cut off to
	# come up in the last of the dark (below_s), as walking there would be.
	var walk := 0.0
	while walk < 20.0 and res.all.any(func(q) -> bool: return is_instance_valid(q) and (q as Resident).state == Resident.BELOW):
		await physics_frame
		walk += DT
		_track()
	var ups := 0
	for r in res.all:
		ups += r.came_up
	print("  %d skeletons; before the last light: %d fell back out of a relit place or the light, %d hung back in a dark pocket, %d pocket strikes, %d frames of a chase in the light; cut off by the light, into the stone and up in the dark elsewhere %d times" % [n0, _fell_back.size(), _lurked.size(), _bites, _chased_in, ups])
	ok(_bad == 0 and _worst <= rise + b2d + 0.5, "over the run no resident stood in the light outside a chase but on its way out, and none for longer than %.1f s of the time it could move (rise_s + back_to_dark_s; %.2f s at worst; %d frames held still in your view or just short of it, not counted)" % [rise + b2d + 0.5, _worst, _held_light])
	ok(not _fell_back.is_empty(), "skeletons resting or standing in relit rooms fell back into the dark (%d)" % _fell_back.size())
	ok(not res.cleared and res.gone.is_empty() and res.all.size() == n0, "the floor is not cleared while a light is still cold, and none has gone for good (%d of %d still on the roll)" % [res.all.size(), n0])
	# The last light: the heart's own, with what is left there in view.
	main.boss.auto = true
	var h_last: Node3D = order[-1]
	var stand := _stand_by(h_last)
	# You look at the nearest of them up and about, if one is near and in
	# your line (as you would): its going in view.
	var look: Vector3 = h_last.global_position
	var nearest := 12.0
	for q in res.all:
		if is_instance_valid(q) and q.state in [Resident.LURK, Resident.HUNT, Resident.RETURN, Resident.LEAVE]:
			var d := q.global_position.distance_to(stand)
			if d < nearest and res.clear_line(stand + Vector3(0.0, 1.6, 0.0), q.global_position + Vector3(0.0, 1.0, 0.0)):
				nearest = d
				look = q.global_position
	_place_facing(stand, look)
	var left := res.all.size()
	_say_states()
	_light_holder(h_last)
	var seen_s := float(Residents.CLEARED.get("retreat_seen_s", 6.0))
	var t := 0.0
	var gone_by := -1.0
	while t < seen_s + 1.0:
		await physics_frame
		t += DT
		_track()
		if gone_by < 0.0 and res.cleared and res.all.is_empty():
			gone_by = t
	ok(res.cleared and fires.lit_count() == fires.holders.size(), "the last light caught (%d of %d): the floor is cleared" % [fires.lit_count(), fires.holders.size()])
	var seen := 0
	for g in res.gone:
		if bool(g.seen):
			seen += 1
		print("  %s gone %.2f s after the last light (%s)" % [g.name, float(g.at) - res.cleared_at, "seen going" if bool(g.seen) else "out of sight"])
	ok(gone_by >= 0.0 and gone_by <= seen_s + 2.0 * DT, "every resident has gone within %.2f s of it (retreat_seen_s %.0f): %d left at the last light, %d of all %d seen going back into the stone, the rest gone at once out of sight" % [gone_by, seen_s, left, seen, res.gone.size()])
	ok(_residents_in_scene() == 0, "none is left in the scene (%d)" % _residents_in_scene())
	ok(_boo.bad == 0 and int(_boo.logged) > 0, "and over the run, the last light included, none beyond its reach, outside its strike and the last light's going, moved, turned or changed its pose on a frame you could see it in (%d did; %d skeleton-frames logged: %d moved, %d held still in your view, %d let off)" % [_boo.bad, _boo.logged, _boo.moved, _boo.held, _boo.let_off])
	var line := str(Residents.CLEARED.get("log_line", ""))
	var at_line := -1
	var at_count := -1
	var lines := 0
	for i in range(log0, GameLog.entries.size()):
		var e: Dictionary = GameLog.entries[i]
		if str(e.get("kind", "")) == "cleared":
			lines += 1
			at_line = i
		if str(e.get("text", "")) == "%d of %d lights burn again." % [fires.holders.size(), fires.holders.size()]:
			at_count = i
	ok(lines == 1 and line != "" and str(GameLog.entries[at_line].text) == line and at_count >= 0 and at_count < at_line, "the log's one line, after the count of lights: \"%s\"" % line)
	# The snake's release (queue 49) still plays.
	var b := main.boss
	var cry := float(Boss.RELEASE.get("cry_s", 5.0))
	await _frames(int(maxf(cry + 1.0 - t, 0.0) / DT))
	var boss_line := str(Boss.RELEASE.get("log_line", "")).format({"boss": b.name_text})
	var logged := false
	for e in GameLog.entries:
		if str(e.text).begins_with(boss_line):
			logged = true
	ok(b.released and b.state in ["lair", "gone"] and logged, "the snake's release still plays: it went home (%s) and the log says \"%s.\"" % [b.state, boss_line])
	# Five minutes on: none comes back.
	player._invulnerable = 0.0
	main.harm.reset()
	var hits0 := main.harm.landed
	var back := 0
	var strikes := 0
	var chased := false
	for s in 300:
		await _frames(60)
		back = maxi(back, res.all.size() + _residents_in_scene())
		for cs in CreatureStrike.all:
			if is_instance_valid(cs) and (cs as Node).get_parent() is Resident:
				strikes += 1
		if main.harm.chased():
			chased = true
	ok(back == 0 and strikes == 0 and not chased and main.harm.landed == hits0, "over 5 minutes more none returns: no resident (%d), no strike of theirs in play (%d), nothing pursuing you (%s), no hit (%d)" % [back, strikes, str(chased), main.harm.landed - hits0])


## Residents still in the scene (not freed).
func _residents_in_scene() -> int:
	var n := 0
	for c in res.get_children():
		if c is Resident and is_instance_valid(c) and not (c as Resident).is_queued_for_deletion():
			n += 1
	return n


## Where each resident is as the last light is about to catch, and whether
## you can see it.
func _say_states() -> void:
	var parts: Array = []
	for r in res.all:
		if is_instance_valid(r):
			parts.append("%s %s %.1f m off%s" % [r.name, r.state_name(), r.global_position.distance_to(player.global_position), " (in view)" if r.in_view() else ""])
	print("  at the last light: %s" % ", ".join(parts))
