extends SceneTree
## The tomb's residents (design 6 Oct §FE, §FC.2; queue 58), headless:
##   SEEDS=1,7,42 godot --headless --path . --fixed-fps 60 --script tools/residents_check.gd
## For each seed (1, 7 and 42 unless SEEDS says):
##  1. the resting places (TombKit residents): per_dungeon of them where
##     there are places enough, the heart's coffin holding one, none in the
##     hearth room, apart_m apart, every one off_line_m off the way through
##     the rooms (TombKit.walk_lines) and off the line your body walks from
##     the wake spot to the heart (TombNav at your size: the spine's line
##     until queue 46 builds the spine);
##  2. the walk-to-exit check until queue 46 builds the exit: your own body,
##     walking by the keys, gets from the wake spot to the heart (the
##     spine's far end) with every holder cold and every skeleton at rest;
##  3. passing arms it (Mike's 7 Oct note, the Boos; creep): with your head
##     just beyond arms_m of its head, looking at it, it is not armed; within
##     arms_m, looking at it, it is armed but lies still for seconds, nothing
##     moving and nothing heard; at rest it is no swing's target (no strike
##     in play); turn your back and it climbs out within a moment, its near
##     tell (bone grinding) behind you, your pursuer from then (Pursuit,
##     Harm, §FD); turn back mid-climb and it freezes half out (place, turn,
##     pose and clock unchanged over 2 s of your watching); look away and it
##     climbs on from where it froze and hunts you;
##  3b. the creep: your back to it, it comes for you at creep_mps (measured
##     on a straight run of dark floor), its bone steps heard; face it and it
##     stops within one physics frame, and stays stopped while you stare at
##     it longer than out_of_sight_s, still your pursuer (it senses you: you
##     heal only once it gives you up, §FD); your back to it again, it comes
##     right up on you, and within its reach it winds up in plain view while
##     you look straight at it: your lit torch's swing at half its wind-up
##     staggers it, and no hit lands (§FA.1);
##  3c. a fire pot's fire reaching one at rest while you watch it (§FA.3;
##     FirePots' socket, fire_hit): it wakes, its chase on, but lies there
##     still until you look away; then it climbs out;
##  4. hiding (§FC.2): crouched behind a lidded coffin with your torch
##     doused, it never senses you (you are hidden from it by the coffin
##     alone), gives you up after out_of_sight_s and walks back to lie in
##     its own place (queue 59, §FF.2: if a way through the dark leads
##     there; with the lit hearth room between, it hangs back in the dark
##     instead); the same with the torch lit and your back to it, it sees
##     the light round the coffin and comes for you;
##  5. the strike (queue 57's CreatureStrike, §FA.1-2), you looking straight
##     at it (within its reach it moves in plain view): in reach it winds
##     up, the jaw open on its sprite and its tell (the jaw's creak) sounding
##     from the wind-up's first frame; one hit lands at the end of its
##     committed strike (wind_up_s, then strike_s), none before and no
##     second in the recovery; your torch's own swing (Torch.swing_top),
##     lit, landing at half the wind-up staggers it (it reels back reel_m,
##     the swing as loud as a sprint) and no hit lands; unlit it staggers
##     nothing; a second stagger inside cooldown_s fails; a swing once the
##     strike is committed does nothing, and the hit lands;
##  6. the chase and healing (§FD): hit, you don't heal while it still
##     hunts you, however long; once it gives you up you heal step_s later;
##  7. "Good night": a third hit closes the frame with the words, and you
##     wake on the mat by the hearth, unhurt, its chase given up;
##  8. the rule itself, over a scripted session of a few minutes (the
##     skeletons free, nothing able to take you): you walk by the keys past
##     every skeleton and back past them again, then home to the hearth,
##     looking at each as you pass, then walk on with your back to it, look
##     back, wait with your back turned, look again, and look just past it
##     to either side (its middle 4 and 9 degrees beyond
##     the frame's edge and margin, so coming on, its arm nears your sight);
##     stop to relight sconces with your back to the room; and look back
##     now and then as you walk. Every physics frame is logged, and no
##     skeleton farther than its strike's reach, outside its strike (the
##     wind-up, strike, recovery and reel run in plain view, Mike's
##     "unless they get right up on you") and not going at the floor's last
##     light, may change its place, turn or pose on a frame where you could
##     see it, by Residents.points_watched's test, at the frame's start (as
##     it decided) or at its end (as it was drawn). The log reports how many
##     frames it checked and the nearest call;
##  9. the one exception (§FF.2's reveal): one up and about 4.5 m before
##     you, held still while you watch it; the floor's last light catches
##     (Residents.clear_floor) and it hurries back into the stone in plain
##     view, seen going, gone for good within retreat_seen_s, every other
##     one gone too.

var fails := 0
var main: CrawlerMain
var player: CrawlerPlayer
var res: Residents
var _floor: StaticBody3D
const DT := 1.0 / 60.0
## The test floor: far under and away from the tomb, off its floor grid.
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
	_layout(s)
	OS.set_environment("SEED", str(s))
	main = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked:
		await process_frame
	player = main.player
	res = main.residents
	# The snake held still (queue 49): these are the skeletons' tests.
	var boss: Variant = main.get("boss")
	if boss is Boss:
		(boss as Boss).auto = false
	_test_floor()
	ok(res.nav != null and res.nav.open_count > 0, "the residents' floor grid is built (%d open squares)" % (res.nav.open_count if res.nav != null else 0))
	await _walk()
	Residents.stay_asleep = false
	await _arm_rise()
	await _settle()
	await _creep()
	await _settle()
	await _burning()
	await _settle()
	await _hide(false)
	await _settle()
	await _hide(true)
	await _settle()
	await _strike()
	await _settle()
	await _stagger()
	await _settle()
	await _heal()
	await _settle()
	await _good_night()
	await _settle()
	# Last: it lights sconces, and the light stays; then the floor's last
	# light sends every skeleton away for good.
	await _session()
	await _settle()
	await _last_light()
	Residents.stay_asleep = true
	main.queue_free()
	await process_frame
	await process_frame


func _skel() -> Dictionary:
	return Residents.D.get("creatures", {}).get("skeleton", {})


## 1. The resting places, from the layout alone.
func _layout(s: int) -> void:
	var lay := TombKit.layout(s)
	var cr := _skel()
	var span: Array = cr.get("per_dungeon", [3, 6])
	var off := float(cr.get("off_line_m", 1.0))
	var apart := float(cr.get("apart_m", 2.0))
	var lines := TombKit.walk_lines(lay)
	var n: int = (lay.residents as Array).size()
	var heart_one := false
	var in_hearth := false
	var apart_ok := true
	var off_ok := true
	var worst := INF
	for r in lay.residents:
		if int(r.piece) == 0:
			in_hearth = true
		if int(r.spot) < 0:
			heart_one = true
		# (The heart's coffin aside: the way through the heart runs past it
		# to the way out, §EX.5, and it always holds one.)
		var d := TombKit.line_distance(lines, Vector2((r.pos as Vector3).x, (r.pos as Vector3).z)) if int(r.spot) >= 0 else INF
		worst = minf(worst, d)
		if d < off - 1e-3:
			off_ok = false
		for q in lay.residents:
			if q != r and (q.pos as Vector3).distance_to(r.pos) < apart - 1e-3:
				apart_ok = false
	# Places it could have used, kept apart: how many it could lay.
	var places := 0
	for pc in lay.pieces:
		if str(pc.kind) != "room":
			continue
		match str(pc.get("room_kind", "")):
			"crypt":
				places += TombKit.coffin_spots(lay, pc).size()
			"catacomb":
				places += ceili(TombKit.niche_spots(lay, pc).size() * 0.5)
	var floor_n := mini(int(span[0]), places + 1)
	var kinds := {}
	for r in lay.residents:
		kinds[r.rests_in] = int(kinds.get(r.rests_in, 0)) + 1
	ok(n >= floor_n and n <= int(span[1]), "seed %d: %d skeletons laid (%s; per_dungeon %s, %d places to lay them)" % [s, n, str(kinds), str(span), places + 1])
	ok(heart_one, "the heart's coffin holds one (Mike's frame 9)")
	ok(not in_hearth, "none rests in the hearth room")
	ok(apart_ok, "none rests within %.1f m of another" % apart)
	ok(off_ok, "every one but the heart's rests %.1f m or more off the way through the rooms (nearest %.2f m)" % [off, worst])


## The distance from `p` (x/z) to the polyline `pts`.
func _poly_distance(pts: PackedVector3Array, p: Vector3) -> float:
	var lines: Array = []
	for k in range(1, pts.size()):
		lines.append([Vector2(pts[k - 1].x, pts[k - 1].z), Vector2(pts[k].x, pts[k].z)])
	return TombKit.line_distance(lines, Vector2(p.x, p.z))


## 2. Your own body walks from the wake spot to the heart.
func _walk() -> void:
	var lay := main.lay
	# Your capsule's size; the walk below is the proof.
	var nav := TombNav.build(lay, main.get_viewport().world_3d.direct_space_state, 0.36, [player.get_rid()])
	var heart: Dictionary = lay.pieces[int(lay.heart)]
	var hc: Vector2 = (heart.c as Vector2) + (heart.dir as Vector2) * float(heart.len) * 0.5
	var mid := Vector3(hc.x, Delves.floor_of(heart, float(heart.len) * 0.5), hc.y)
	var w: Vector3 = lay.wake[0]
	# Into the heart: as near its middle as the floor goes (its dead's goods
	# lie about the middle).
	var path := nav.path(w, mid, true)
	var in_heart := not path.is_empty() and TombKit.piece_at(lay, path[-1]) == int(lay.heart)
	ok(path.size() >= 2 and in_heart, "a way for your body from the wake spot into the heart (%.1f m, %d bends)" % [TombNav.length_of(path), maxi(path.size() - 2, 0)])
	if path.size() < 2 or not in_heart:
		return
	var goal: Vector3 = path[-1]
	var off := float(_skel().get("off_line_m", 1.0))
	var worst := INF
	for r in res.all:
		# (Not the heart's: the way runs up to its coffin, §EX.5.)
		if int(r.place.spot) >= 0:
			worst = minf(worst, _poly_distance(path, r.place.pos))
	ok(worst >= off, "every skeleton but the heart's rests %.1f m or more off that walkable line (nearest %.2f m)" % [off, worst])
	# Walk it by the keys, every holder cold, every skeleton at rest.
	var first := path[1] - path[0]
	player.spawn_flat(path[0], atan2(-first.x, -first.z), -0.2)
	await _frames(4)
	var limit := TombNav.length_of(path) / PlanetPlayer.WALK_SPEED * 2.0 + 20.0
	var t := 0.0
	var i := 1
	var last_moved := 0.0
	var mark := player.global_position
	Input.action_press("move_forward")
	while i < path.size() and t < limit:
		var p := path[i]
		var to := Vector3(p.x - player.global_position.x, 0.0, p.z - player.global_position.z)
		if to.length() < 0.4:
			i += 1
			continue
		player._yaw = atan2(-to.x, -to.z)
		await physics_frame
		t += DT
		if player.global_position.distance_to(mark) > 0.3:
			mark = player.global_position
			last_moved = t
		elif t - last_moved > 3.0:
			print("  stuck at %s heading for %s (point %d of %d)" % [str(player.global_position), str(p), i, path.size()])
			break
	Input.action_release("move_forward")
	await _frames(20)
	var flat := Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length()
	ok(flat < 1.0 and TombKit.piece_at(lay, player.global_position) == int(lay.heart), "your body walks from the wake spot into the heart in %.1f s, every holder cold, every skeleton at rest (queue 46's walk check until the exit is built; %.2f m from the way's end)" % [t, flat])
	ok(main.fires.lit_count() == 0, "no holder was lit on the way")


## A floor far under the tomb for the strikes.
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
	Input.action_release("move_forward")
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
		r.armed = false
		r.still = false
		r._told = false
		r.last_sound = ""
		r.lunging = false
		r._edge_t = 0.0
		r.pocket = Vector3.INF
		r.pocket_node = -1
		r._for_good = true
		r._rphase = ""
		r.seen_going = false
		r.set_physics_process(true)
		if r.sprite != null:
			r.sprite.visible = true
		if not r.is_in_group(FirePots.TARGET_GROUP):
			r.add_to_group(FirePots.TARGET_GROUP)
		r.def = res.creature(r.kind)
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


func _pick(kinds: Array) -> Resident:
	for k in kinds:
		for r in res.all:
			if str(r.place.rests_in) == k and int(r.place.spot) >= 0:
				return r
	return res.all[0] if not res.all.is_empty() else null


## As _pick, but one whose arming test spot (_arm_rise: just beyond its
## arms_m, in front of it) is out of every other skeleton's arms_m, so
## only it is tested there (two in one catacomb can rest close, design
## §EX.4 setting the niches round the sconces), and where your body fits
## at both of _arm_rise's spots (in an 8 m crypt, just beyond arms_m in
## front of a coffin is the far row's coffins, design §EX.2); else _pick's.
func _pick_alone(kinds: Array) -> Resident:
	for k in kinds:
		for r in res.all:
			if str(r.place.rests_in) != k or int(r.place.spot) < 0:
				continue
			var e: Vector3 = r.place.eye
			var out: Vector3 = r.place.out
			var inward := Vector3(out.x - (r.place.pos as Vector3).x, 0.0, out.z - (r.place.pos as Vector3).z).normalized()
			var d := r.waking_m() + 0.4
			var dy := out.y + PlanetPlayer.EYE_Y - e.y
			var eye := Vector3(e.x, out.y, e.z) + inward * sqrt(maxf(d * d - dy * dy, 0.0)) + Vector3(0.0, PlanetPlayer.EYE_Y, 0.0)
			var alone := true
			for q in res.all:
				if q != r and (q.place.eye as Vector3).distance_to(eye) <= q.waking_m() + 0.3:
					alone = false
			for dd: float in [d, d - 0.7]:
				if not _fits(Vector3(e.x, out.y, e.z) + inward * sqrt(maxf(dd * dd - dy * dy, 0.0))):
					alone = false
			if alone:
				return r
	return _pick(kinds)


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


## Look at `r` (its middle) from where you stand.
func _look_at(r: Resident) -> void:
	var pts := r.view_points()
	var mid: Vector3 = pts[1] if pts.size() > 1 else r.global_position + Vector3(0.0, 0.8, 0.0)
	var d := mid - player.camera().global_position
	player.set_view(atan2(d.y, Vector2(d.x, d.z).length()), atan2(-d.x, -d.z))


## Your back to `r`, looking level.
func _look_away(r: Resident) -> void:
	var d := r.global_position - player.global_position
	player.set_view(-0.1, atan2(d.x, d.z))


## `a` and `b` (x/z) apart.
func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## 3. Passing arms it; it climbs out only while you can't see it, and
## freezes half out when you turn back (Mike's 7 Oct note).
func _arm_rise() -> void:
	var r := _pick_alone(["wall_niche", "grave"])
	if r == null:
		ok(false, "a skeleton to arm")
		return
	var e: Vector3 = r.place.eye
	var out: Vector3 = r.place.out
	var inward := Vector3(out.x - (r.place.pos as Vector3).x, 0.0, out.z - (r.place.pos as Vector3).z).normalized()
	var arms := r.waking_m()
	# Your head `d` m from its head, in front of it, looking at it.
	var stand := func(d: float) -> void:
		var dy := out.y + PlanetPlayer.EYE_Y - e.y
		var h := sqrt(maxf(d * d - dy * dy, 0.0))
		var at := Vector3(e.x, out.y, e.z) + inward * h
		player.spawn_flat(at, atan2(inward.x, inward.z), -0.2)
		_look_at(r)
	stand.call(arms + 0.4)
	await _frames(30)
	ok(r.state == Resident.REST and not r.armed, "%s (%s) stays at rest, not armed, with your head %.1f m from its head, just beyond arms_m %.1f, looking at it (%s)" % [r.name, r.place.rests_in, e.distance_to(player.eye_position()), arms, r.state_name()])
	var resting := 0
	for q in res.all:
		if q.strike != null or CreatureStrike.all.any(func(cs) -> bool: return is_instance_valid(cs) and (cs as Node).get_parent() == q):
			resting += 1
	ok(resting == 0, "at rest they are set dressing: no swing meets one (no strike of theirs in play; %d)" % resting)
	stand.call(arms - 0.3)
	var armed_s := -1.0
	for i in 20:
		await physics_frame
		if r.armed:
			armed_s = (i + 1) * DT
			break
	ok(r.armed and r.state == Resident.REST and res.watched(r), "with your head %.1f m from it, inside arms_m, looking at it, your passing arms it (%.2f s) and it stays at rest (%s)" % [e.distance_to(player.eye_position()), armed_s, r.state_name()])
	# Watched, nothing of it stirs.
	var pos0 := r.global_position
	var pose0: int = r.sprite.pose
	var stirred := 0
	var hold := 4.0
	var t := 0.0
	while t < hold:
		await physics_frame
		t += DT
		if r.state != Resident.REST or r.global_position != pos0 or r.sprite.pose != pose0 or r.last_sound != "":
			stirred += 1
	ok(stirred == 0 and r.armed and not r.pursuit.on, "armed, it lies still all %.0f s you watch it: not a bone moves, nothing heard, no one's pursuer yet (%d frames stirred)" % [hold, stirred])
	# Your back to it.
	_look_away(r)
	var rose := -1.0
	t = 0.0
	while t < 0.5:
		await physics_frame
		t += DT
		if r.state == Resident.RISING and r.last_sound == "near":
			rose = t
			break
	ok(rose > 0.0 and rose <= 0.1 and r.voice.stream != null, "turn your back and it climbs out within a moment (%.2f s), its near tell heard behind you: bone grinding on stone (%s)" % [rose, r.last_sound])
	ok(r.pursuit.on and main.harm.chased() and r.strike != null and CreatureStrike.all.has(r.strike), "climbing out, it is your pursuer (Pursuit, Harm, §FD), and its strike is in play")
	# Turn back to it halfway out: it freezes there, from the frame you turn.
	var rise := float(r.def.get("rise_s", 1.6))
	while r.state == Resident.RISING and r.t < rise * 0.5:
		await physics_frame
	_look_at(r)
	var half_t := r.t
	var half_pos := r.global_position
	var half_yaw := r.yaw
	var half_pose: int = r.sprite.pose
	var drift := 0.0
	var same := true
	t = 0.0
	while t < 2.0:
		await physics_frame
		t += DT
		drift = maxf(drift, r.global_position.distance_to(half_pos))
		same = same and r.state == Resident.RISING and r.t == half_t and r.yaw == half_yaw and r.sprite.pose == half_pose
	var pname := str(SkeletonRig.POSES[half_pose])
	ok(drift == 0.0 and same and pname in ["rise_a", "rise_b", "rise_c"] and res.watched(r), "turn back to it mid-climb and it freezes half out (%s, %.0f%% of its climb): over 2 s of your watching its place, turn, pose and clock never change (moved %.4f m)" % [pname, half_t / rise * 100.0, drift])
	# Look away: it climbs on from where it froze.
	_look_away(r)
	t = 0.0
	while r.state == Resident.RISING and t < rise + 1.0:
		await physics_frame
		t += DT
	var flat := _flat(r.global_position, out)
	ok(r.state != Resident.RISING and r.state != Resident.REST and absf(t - (rise - half_t)) <= 2.5 * DT and flat < 0.6, "look away and it climbs on from where it froze: out on the floor %.2f s later (the %.2f s of its climb it had left; %.2f m from its way out), hunting you (%s)" % [t, rise - half_t, flat, r.state_name()])


## A straight run `len_m` long on open floor in the dark, in a room that is
## not the hearth room, no other skeleton resting within its arms_m of
## either end: {"a", "b", "piece"} or {}.
func _open_line(len_m: float) -> Dictionary:
	var lay := main.lay
	for pc in lay.pieces:
		if str(pc.kind) != "room" or str(pc.get("room_kind", "")) == "hearth" or float(pc.len) < len_m + 1.6:
			continue
		for across: float in [0.0, 1.0, -1.0, 1.6, -1.6, 0.4, -0.4]:
			if absf(across) > float(pc.half) - 0.6:
				continue
			var a := BossGround.point(pc, 0.8, across)
			var b := BossGround.point(pc, 0.8 + len_m, across)
			var good := true
			for k in int(len_m / 0.25) + 1:
				var q := a.lerp(b, minf(k * 0.25 / len_m, 1.0))
				if not res.nav.is_open(res.nav.cell_of(q)) or not res.dark_at(q):
					good = false
					break
			if not good:
				continue
			for q in res.all:
				for end: Vector3 in [a, b]:
					if (q.place.eye as Vector3).distance_to(end + Vector3(0.0, PlanetPlayer.EYE_Y, 0.0)) <= q.waking_m() + 1.0:
						good = false
			if good:
				return {"a": a, "b": b, "piece": int(pc.id)}
	return {}


## 3b. The creep: it comes only while your back is turned, at creep_mps;
## face it and it stops; within its reach it strikes in plain view.
func _creep() -> void:
	var len_m := 6.5
	var line := _open_line(len_m)
	var r: Resident = res.all[0] if not res.all.is_empty() else null
	if line.is_empty() or r == null:
		ok(false, "a straight run of %.1f m of dark open floor to watch one creep on" % len_m)
		return
	var cmps := float(r.creep().get("creep_mps", 1.4))
	var a: Vector3 = line.a
	var b: Vector3 = line.b
	_torch(true)
	# You at one end, your back to it at the other.
	player.spawn_flat(b, atan2(a.x - b.x, a.z - b.z), -0.1)
	_hunt_at(r, a, b)
	var pts: Array = []
	var steps := 0
	var stream: AudioStream = r.feet.stream
	var t := 0.0
	while t < 2.0:
		await physics_frame
		t += DT
		pts.append(r.global_position)
		if r.feet.stream != stream:
			steps += 1
			stream = r.feet.stream
	var k0 := int(0.5 / DT)
	var mps := _flat(pts[k0], pts[-1]) / ((pts.size() - 1 - k0) * DT)
	ok(absf(mps - cmps) <= 0.03 and steps >= 2 and r.state == Resident.HUNT, "your back to it on a straight run of dark floor (piece %d), it creeps toward you at %.2f m/s (creep_mps %.1f; your walk is %.1f), its bone steps heard (%d)" % [int(line.piece), mps, cmps, PlanetPlayer.WALK_SPEED, steps])
	# Face it: it stops within the frame you turn.
	var at := r.global_position
	_look_at(r)
	var after := 0.0
	var kept := true
	var stare := float(r.gives_up().get("out_of_sight_s", 8.0)) + 2.0
	t = 0.0
	while t < stare:
		await physics_frame
		t += DT
		after = maxf(after, r.global_position.distance_to(at))
		if not (r.hunting() and r.pursuit.on and main.harm.chased()):
			kept = false
	ok(after <= cmps * DT + 1e-4, "face it and it stops within one physics frame: %.4f m after you turned (one frame's creep is %.4f m)" % [after, cmps * DT])
	ok(after == 0.0 and kept and r.sensed_by != "", "and holds dead still all %.0f s you stare at it, %.1f m off, longer than out_of_sight_s: it keeps sensing you (%s), still your pursuer, so you don't heal (§FD)" % [stare, _flat(r.global_position, player.global_position), r.sensed_by])
	# Your back to it again: it comes right up on you; within its reach you
	# face it, and it winds up in plain view.
	_look_away(r)
	var reach: float = r.strike.reach_m
	t = 0.0
	while t < 8.0 and _flat(r.global_position, player.global_position) > reach - 0.08:
		await physics_frame
		t += DT
	var came := _flat(r.global_position, player.global_position)
	_look_at(r)
	var hits0 := main.harm.landed
	var w0: int = r.strike.wind_ups
	t = 0.0
	while t < 2.0 and not r.winding_up():
		await physics_frame
		t += DT
	var seen_wind := res.watched(r) and r.winding_up() and r.strike.wind_ups == w0 + 1
	while r.winding_up() and r.strike.t < r.strike.wind_up_s * 0.5:
		await physics_frame
	var did := player.torch.swing_top()
	await _frames(int((CreatureStrike.reel_s() + 0.3) / DT))
	ok(came <= reach and seen_wind and did == "staggered" and main.harm.landed == hits0, "your back to it, it comes right up on you (%.2f m, within reach_m %.1f); you face it and it winds up in plain view, the jaw's creak its tell, and your lit torch's swing at half its wind-up staggers it (%s): no hit (%d)" % [came, reach, did, main.harm.landed - hits0])


## 3c. A fire pot's fire on one at rest while you watch it (FirePots'
## socket, fire_hit; §FA.3): it wakes burning, but lies still until you look
## away.
func _burning() -> void:
	var r := _pick_alone(["wall_niche", "grave"])
	if r == null:
		ok(false, "a skeleton to burn")
		return
	var e: Vector3 = r.place.eye
	var out: Vector3 = r.place.out
	var inward := Vector3(out.x - (r.place.pos as Vector3).x, 0.0, out.z - (r.place.pos as Vector3).z).normalized()
	# Just beyond where it arms (_pick_alone's spot): only the fire wakes it.
	var d := r.waking_m() + 0.4
	var dy := out.y + PlanetPlayer.EYE_Y - e.y
	player.spawn_flat(Vector3(e.x, out.y, e.z) + inward * sqrt(maxf(d * d - dy * dy, 0.0)), atan2(inward.x, inward.z), -0.2)
	_look_at(r)
	await _frames(6)
	r.fire_hit(1.0, r.fire_center())
	var pos0 := r.global_position
	var pose0: int = r.sprite.pose
	var lay_still := true
	var t := 0.0
	while t < 1.5:
		await physics_frame
		t += DT
		if r.global_position != pos0 or r.sprite.pose != pose0 or r.last_sound != "":
			lay_still = false
	ok(r.state == Resident.RISING and r.pursuit.on and lay_still, "a fire pot's fire reaching one at rest while you watch it (FirePots' socket, fire_hit): it wakes (%s), its chase on, but lies there still until you look away" % r.state_name())
	_look_away(r)
	await _frames(int(0.5 / DT))
	ok(r.state == Resident.RISING and r.global_position != pos0 and r.last_sound == "near", "you look away and it climbs out, its near tell heard (%s)" % r.state_name())


## A lidded coffin to hide behind, and where a skeleton stands seeing it:
## {"hide", "watch", "piece"} or {}. One the coffin alone hides you behind
## (standing there it would see you) is taken first: a crypt's pillars
## (queue 48) can stand across the line too.
func _cover() -> Dictionary:
	var lay := main.lay
	var first := {}
	for pc in lay.pieces:
		if str(pc.get("room_kind", "")) != "crypt":
			continue
		var half := float(pc.half)
		var pv := Delves.perp(pc.dir)
		var d3 := Vector3((pc.dir as Vector2).x, 0.0, (pc.dir as Vector2).y)
		for s in TombKit.coffin_spots(lay, pc):
			if not TombKit.resting_at(lay, int(pc.id), int(s.i)).is_empty():
				continue
			var a := float(s.along)
			var sd := float(s.sd)
			var fy := Delves.floor_of(pc, a)
			for side: float in [1.0, -1.0]:
				var c2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * a + pv * sd * (half - TombKit.COFFIN_IN)
				var hide := Vector3(c2.x, fy, c2.y) + d3 * side * (TombKit.COFFIN_SIZE.x * 0.5 + 0.55)
				var w2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * (a - side * 3.0) + pv * sd * (half - TombKit.COFFIN_IN - TombKit.COFFIN_SIZE.z * 0.5 - 0.8)
				var watch := Vector3(w2.x, fy, w2.y)
				if not _fits(hide) or not res.nav.is_open(res.nav.cell_of(watch)):
					continue
				# The line from its eyes to your crouched head crosses the coffin.
				var eye := watch + Vector3(0.0, float(_skel().get("eye_m", 1.5)), 0.0)
				var head := hide + Vector3(0.0, PlanetPlayer.CROUCH_EYE_Y, 0.0)
				var stand_head := hide + Vector3(0.0, PlanetPlayer.EYE_Y, 0.0)
				if res.clear_line(eye, head) or eye.distance_to(head) > float(_skel().get("notice", {}).get("sees_you_m", 6.0)):
					continue
				var cov := {"hide": hide, "watch": watch, "piece": int(pc.id), "stand_seen": res.clear_line(eye, stand_head)}
				if bool(cov.stand_seen):
					return cov
				if first.is_empty():
					first = cov
	return first


## Does your body fit crouched at `at` (on the floor), touching nothing?
func _fits(at: Vector3) -> bool:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = PlanetPlayer.CROUCH_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0.0, PlanetPlayer.CROUCH_HEIGHT * 0.5 + 0.03, 0.0))
	q.collision_mask = PropCollision.WORLD_LAYER
	q.exclude = [player.get_rid()]
	return main.get_viewport().world_3d.direct_space_state.intersect_shape(q, 1).is_empty()


## 4. Hiding behind a coffin, the torch doused (`lit` false) or lit.
func _hide(lit: bool) -> void:
	var cov := _cover()
	if cov.is_empty():
		ok(false, "a lidded coffin to hide behind with a skeleton's line to you crossing it")
		return
	# The skeleton whose home is nearest.
	var r: Resident = null
	for q in res.all:
		if r == null or (q.place.out as Vector3).distance_to(cov.watch) < (r.place.out as Vector3).distance_to(cov.watch):
			r = q
	var hide: Vector3 = cov.hide
	var watch: Vector3 = cov.watch
	# Doused, looking its way; lit, your back to it, so it can come (it
	# moves only while you can't see it, Mike's 7 Oct note).
	var face := atan2(-(watch.x - hide.x), -(watch.z - hide.z))
	player.spawn_flat(hide, face + (PI if lit else 0.0), 0.0)
	_torch(lit)
	Input.action_press("crouch")
	await _frames(12)
	if not lit:
		ok(player.crouching and not player.torch.lit(), "crouched behind a lidded coffin in piece %d, the torch in hand doused (your eyes %.2f m up; standing they'd be %s)" % [int(cov.piece), PlanetPlayer.CROUCH_EYE_Y, "seen" if bool(cov.stand_seen) else "hidden too"])
	_hunt_at(r, watch, hide)
	var gave := -1.0
	var sensed := ""
	var t := 0.0
	var oos := float(r.gives_up().get("out_of_sight_s", 8.0))
	var came := false
	var why := ""
	var hid := false
	while t < oos + 2.0:
		await physics_frame
		t += DT
		# Given up (home, or with queue 59 hanging back in the dark when no
		# way through the dark leads home).
		if r.gave_up_why != "" and gave < 0.0:
			gave = t
			why = r.gave_up_why
		if gave < 0.0 and r.sensed_by != "" and sensed == "":
			sensed = r.sensed_by
		if gave < 0.0 and r.hidden:
			hid = true
		if r.winding_up() or (r.strike != null and r.strike.landed > 0):
			came = true
		if gave > 0.0 or (lit and came):
			break
	if not lit:
		ok(sensed == "", "behind the coffin, low, the torch out, it never senses you (%s)" % (sensed if sensed != "" else "nothing"))
		if bool(cov.stand_seen):
			ok(hid, "and it is the coffin alone that hides you: standing there it would see you (Residents.hidden_from, Pursuit's hide)")
		ok(gave > 0.0 and absf(gave - oos) < 0.5 and why == "out_of_sight", "it gives you up after out_of_sight_s %.0f s (%.2f s, %s)" % [oos, gave, why])
		ok(not r.pursuit.on and not main.harm.chased(), "given up, it is no longer your pursuer")
		# You slip away (off the tomb, out of its senses); it goes home by a
		# way through the dark, or (queue 59, §FF.2) with the lit hearth
		# room between, it hangs back in the dark where it is.
		player.spawn_flat(_at(0.0), 0.0, 0.0)
		var home_dark := res.can_go_home(r)
		var back := 0.0
		while r.state != (Resident.REST if home_dark else Resident.LURK) and back < 90.0:
			await physics_frame
			back += DT
		if home_dark:
			ok(r.state == Resident.REST and r.global_position.distance_to(r.place.pos) < 0.05, "and walks back to lie in its own %s (at rest %.1f s later)" % [r.place.rests_in, back])
		else:
			ok(r.state == Resident.LURK and res.dark_at(r.global_position), "its own %s lies past the lit hearth room, so it hangs back in the dark where it is (%s, %.1f s later; §FF.2: home only through the dark)" % [r.place.rests_in, r.state_name(), back])
	else:
		ok(sensed in ["flame", "glow"], "the same with the torch lit and your back to it: it sees your light round the coffin (%s)" % sensed)
		ok(gave < 0.0 and came, "and it doesn't give you up: it comes for you and winds up to strike (%s)" % r.state_name())
	Input.action_release("crouch")


## A skeleton up and hunting you 1.2 m in front of you on the test floor.
func _face_off(torch_lit: bool) -> Resident:
	var r: Resident = res.all[0]
	player.spawn_flat(_at(0.0), 0.0, 0.0)
	_torch(torch_lit)
	_hunt_at(r, _at(-1.2), _at(0.0))
	return r


## A point on the test floor `z` m along its -z/+z line.
func _at(z: float) -> Vector3:
	return Vector3(TEST_XZ.x, TEST_Y, TEST_XZ.y + z)


## 5a. A strike lands as one hit at the end of its committed strike.
func _strike() -> void:
	var r := _face_off(false)
	await _frames(2)
	var t := 0.0
	while not r.winding_up() and t < 1.0:
		await physics_frame
		t += DT
	var cs := r.strike
	ok(r.winding_up() and res.watched(r) and cs.sound == "jaw_creak" and cs.tell_frame == cs.wind_up_frame and SkeletonRig.POSES[r.sprite.pose if r.sprite != null else SkeletonRig.POSES.find("wind_up")] == "wind_up", "in reach and seeing you, you looking straight at it, it winds up, the jaw open, its tell (the jaw's creak, %s) sounding from the wind-up's first frame (frame %d, the wind-up's %d)" % [cs.sound, cs.tell_frame, cs.wind_up_frame])
	var before := main.harm.landed
	var start := Engine.get_physics_frames()
	var at_frame := -1
	while at_frame < 0 and Engine.get_physics_frames() - start < 120:
		await physics_frame
		if main.harm.landed != before:
			at_frame = Engine.get_physics_frames()
	# The wind-up began a frame before `start`'s count.
	var landed_s := float(at_frame - cs.wind_up_frame) * DT
	var want := cs.wind_up_s + cs.strike_s
	ok(at_frame > 0 and main.harm.landed == before + 1 and absf(landed_s - want) <= 2.5 * DT and cs.landed == 1, "one hit lands at the end of its strike: %.2f s after the wind-up began (wind_up_s %.2f, then the committed strike_s %.2f), none before" % [landed_s, cs.wind_up_s, cs.strike_s])
	var after := 0.0
	var rec := cs.recover_s - 0.1
	while after < rec:
		await physics_frame
		after += DT
	ok(main.harm.landed == before + 1, "no second hit in its recovery (%.1f s)" % rec)


## `r` winding up now; at `share` of its wind-up your torch's swing meets
## it (the top of the swing, Torch.swing_top). Returns what the swing did:
## "staggered", "landed" or "".
func _swing_at(r: Resident, share: float) -> String:
	r.strike.cancel()
	r.strike.begin()
	r._enter(Resident.STRIKING)
	while r.strike.winding_up() and r.strike.t < r.strike.wind_up_s * share:
		await physics_frame
	return player.torch.swing_top()


## Back in its place 1.2 m in front of you, its stagger's cooldown spent,
## your last hit long ago.
func _again(r: Resident, torch_lit: bool) -> void:
	player.spawn_flat(_at(0.0), 0.0, 0.0)
	_torch(torch_lit)
	_hunt_at(r, _at(-1.2), _at(0.0))
	r.strike.cooldown_left = 0.0
	main.harm.reset()
	main.harm._last_hit = -INF
	player._invulnerable = 0.0
	await _frames(1)


## 5b. The stagger (§FA.1).
func _stagger() -> void:
	var r := _face_off(true)
	await _frames(1)
	var cs := r.strike
	var before := main.harm.landed
	var pos0 := r.global_position
	var did: String = await _swing_at(r, 0.5)
	ok(did == "staggered" and res.watched(r) and cs.reeling() and r.state_name() == "reel" and absf(cs.met_at_share - 0.5) < 0.05 and player.noise_level >= 0.99, "your lit torch's swing meeting it at half its wind-up (%.2f), you looking straight at it, staggers it: it reels, its strike broken, and the swing is loud as a sprint (noise %.2f)" % [cs.met_at_share, player.noise_level])
	ok(r.last_sound == "staggered", "you hear the crack of it as it reels")
	var t := 0.0
	var reeled := 0.0
	while t < CreatureStrike.reel_s() + 0.6:
		await physics_frame
		t += DT
		reeled = maxf(reeled, Vector2(r.global_position.x - pos0.x, r.global_position.z - pos0.z).length())
	ok(main.harm.landed == before and absf(reeled - cs.reel_m) < 0.1, "no hit lands (%d), and it reeled %.2f m back (reel_m %.2f)" % [main.harm.landed - before, reeled, cs.reel_m])
	# An unlit torch.
	await _again(r, false)
	before = main.harm.landed
	did = await _swing_at(r, 0.5)
	var w := 0
	while cs.state in ["wind_up", "strike"] and w < 120:
		await physics_frame
		w += 1
	ok(did == "landed" and cs.staggers == 1 and main.harm.landed == before + 1, "the same swing with the torch unlit meets it and staggers nothing (%s), and the hit lands" % did)
	# Twice inside cooldown_s.
	await _again(r, true)
	var first: String = await _swing_at(r, 0.5)
	await _frames(int((CreatureStrike.reel_s() + 0.1) / DT))
	_hunt_at(r, _at(-1.2), _at(0.0))
	before = main.harm.landed
	var second: String = await _swing_at(r, 0.5)
	w = 0
	while cs.state in ["wind_up", "strike"] and w < 120:
		await physics_frame
		w += 1
	var cool := float(CreatureStrike.D.get("cooldown_s", 3.0))
	ok(first == "staggered" and second == "landed" and main.harm.landed == before + 1, "a second stagger %.1f s after the first, inside cooldown_s %.0f s, fails (%s), and that strike lands" % [CreatureStrike.reel_s() + 0.1 + cs.wind_up_s * 0.5, cool, second])
	# A swing once the strike is committed.
	await _again(r, true)
	cs.begin()
	r._enter(Resident.STRIKING)
	before = main.harm.landed
	while cs.winding_up():
		await physics_frame
	var was := cs.staggers
	did = player.torch.swing_top()
	w = 0
	while cs.state == "strike" and w < 60:
		await physics_frame
		w += 1
	ok(cs.staggers == was and did == "landed" and not cs.reeling() and main.harm.landed == before + 1, "a swing once its strike is committed does nothing to it (%s), and the hit lands" % did)


## 6. You heal only once it gives you up (§FD).
func _heal() -> void:
	var r := _face_off(false)
	var t := 0.0
	while main.harm.hits.is_empty() and t < 3.0:
		await physics_frame
		t += DT
	ok(main.harm.hits.size() == 1, "it lands a hit")
	# It keeps after you, seeing you, but can't come on (rooted for the
	# test, and you look at it) and you step out of its reach.
	r.def = r.def.duplicate(true)
	r.def["walk_mps"] = 0.0
	(r.def["creep"] as Dictionary)["creep_mps"] = 0.0
	player.spawn_flat(_at(2.5), 0.0, 0.0)
	var step := float(Harm.D.get("recover", {}).get("step_s", 5.0))
	t = 0.0
	while t < step * 3.0:
		await physics_frame
		t += DT
	ok(main.harm.hits.size() == 1 and r.hunting() and main.harm.chased(), "while it still hunts you, %.0f s on, the hit doesn't heal (§FD: light doesn't heal, losing it does)" % (step * 3.0))
	# It loses you: you are far off, where it can't sense you.
	player.spawn_flat(_at(40.0), 0.0, 0.0)
	r.give_up("out_of_sight")
	t = 0.0
	while not main.harm.hits.is_empty() and t < step + 2.0:
		await physics_frame
		t += DT
	ok(main.harm.hits.is_empty() and absf(t - step) < 0.2, "once it gives you up, the hit heals step_s later (%.2f s; step_s %.0f)" % [t, step])


## 7. Three hits: "Good night", and you wake at the hearth.
func _good_night() -> void:
	var r := _face_off(false)
	var landed0 := main.harm.landed
	var t := 0.0
	var words := ""
	var limit := 20.0
	while not main.harm.taking and t < limit:
		await physics_frame
		t += DT
	ok(main.harm.taking and main.harm.landed - landed0 == 3, "three hits and it takes you (%.1f s, %d hits)" % [t, main.harm.landed - landed0])
	t = 0.0
	var woke := false
	while t < Harm.taken_s() + 1.0:
		await physics_frame
		t += DT
		if main.harm_view.taken_text() != "":
			words = main.harm_view.taken_text()
		if not main.harm.taking:
			woke = true
			break
	ok(words == str(Harm.D.get("taken", {}).get("text", "Good night")), "the frame closes and the words show: \"%s\"" % words)
	await _frames(3)
	var w: Vector3 = main.lay.wake[0]
	var flat := Vector2(player.global_position.x - w.x, player.global_position.z - w.z).length()
	var line := str(GameLog.entries[-1].get("text", "")) if not GameLog.entries.is_empty() else ""
	ok(woke and flat < 0.6 and not player.dead and main.harm.hits.is_empty(), "you wake on the mat by the hearth, unhurt (%.2f m from it)" % flat)
	ok(not r.hunting() and r.gave_up_why == "taken" and not r.pursuit.on and not main.harm.chased(), "what took you has given you up and goes home (%s)" % r.state_name())
	ok(line.contains("hearth") and not line.to_lower().contains("skeleton"), "the log's one line names nothing: \"%s\"" % line)


# --- 8. The rule itself: never seen moving (Mike's 7 Oct note) ----------------------

## The session's length at most (s of play), and how often you look back as
## you walk (s).
const SESSION_S := 300.0
const LOOK_EVERY_S := 5.0
## Seconds into the session.
var _s_t := 0.0
## What the log keeps of each skeleton (by instance id) as the last frame
## ended: its place, turn and pose, its view points, its state, and whether
## it was going at the floor's last light.
var _was := {}
## The tally (_boo_log).
var _bt := {}


func _boo_reset() -> void:
	_s_t = 0.0
	_was = {}
	_bt = {"frames": 0, "logged": 0, "moved": 0, "held": 0, "strike": 0, "reach": 0, "last_light": 0, "bad": 0, "near_share": INF, "near_deg": INF, "behind_stone": 0, "closest_m": INF, "fastest": 0.0, "rose": 0, "struck": 0, "below": 0}


## One physics frame of the session, then its log.
func _tick() -> void:
	await physics_frame
	_s_t += DT
	_boo_log()


## Within `reach` of you (flat, and not a storey off).
func _within(at: Vector3, you: Vector3, reach: float) -> bool:
	return _flat(at, you) <= reach and absf(you.y - at.y) < 1.2


## The frame just stepped, logged while the camera still stands as it did
## for that step: for each skeleton, did it change its place, its turn or
## its pose, and could you see it (Residents.points_watched, its creep
## block) as it began the frame (its view points then: what it went by) or
## as it ended it (what was drawn)? Let off: in its strike, within its
## strike's reach, going at the floor's last light.
func _boo_log() -> void:
	_bt.frames += 1
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
		_bt.logged += 1
		var st := int(now.state)
		var st0 := int(was.state)
		if st0 == Resident.REST and st == Resident.RISING:
			_bt.rose += 1
		if st0 != Resident.STRIKING and st == Resident.STRIKING:
			_bt.struck += 1
		if st0 != Resident.BELOW and st == Resident.BELOW:
			_bt.below += 1
		var moved := (now.pos as Vector3).distance_to(was.pos) > 1e-5 or absf(wrapf(float(now.yaw) - float(was.yaw), -PI, PI)) > 1e-5 or int(now.pose) != int(was.pose)
		var cr := r.creep()
		var seen := res.points_watched(was.pts, cr) or res.points_watched(now.pts, cr)
		var reach := r.strike.reach_m if r.strike != null else float(r.strike_def().get("reach_m", 1.6))
		var why := ""
		if st0 == Resident.STRIKING or st == Resident.STRIKING:
			why = "strike"
		elif bool(was.last) or bool(now.last):
			why = "last_light"
		elif _within(was.pos, you, reach) or _within(now.pos, you, reach):
			why = "reach"
		if not moved:
			if seen and why == "" and st != Resident.REST:
				_bt.held += 1
			continue
		_bt.moved += 1
		if why != "":
			_bt[why] += 1
			continue
		if st0 == Resident.HUNT and st == Resident.HUNT:
			_bt.fastest = maxf(_bt.fastest, _flat(now.pos, was.pos) / DT)
		_bt.closest_m = minf(_bt.closest_m, _flat(now.pos, you))
		if seen:
			_bt.bad += 1
			if _bt.bad <= 5:
				print("  SEEN MOVING at %.2f s: %s %s -> %s, %s to %s, %.2f m from you" % [_s_t, r.name, Resident.STATE_NAMES[st0], Resident.STATE_NAMES[st], str(was.pos), str(now.pos), _flat(now.pos, you)])
			continue
		var call := _nearest_call((was.pts as Array), cr)
		var call2 := _nearest_call((now.pts as Array), cr)
		_bt.near_share = minf(_bt.near_share, minf(float(call.share), float(call2.share)))
		_bt.near_deg = minf(_bt.near_deg, minf(float(call.deg), float(call2.deg)))
		if bool(call.stone) or bool(call2.stone):
			_bt.behind_stone += 1


## How near a body's view points `pts` (and its middle's two sides, as
## Residents.points_watched takes them) came to being seen: the least share
## of the frame, and the fewest degrees, any of them with a clear line lay
## outside the frame's edge ({"share", "deg"}, INF for none), and whether
## any lay inside the frame with stone between ("stone").
func _nearest_call(pts: Array, cr: Dictionary) -> Dictionary:
	var out := {"share": INF, "deg": INF, "stone": false}
	if pts.is_empty():
		return out
	var cam := player.camera()
	var c := cam.global_position
	var all_pts := pts.duplicate()
	var side := float(cr.get("side_m", 0.0))
	var across := ((pts[1] as Vector3) - c).cross(Vector3.UP)
	across.y = 0.0
	if side > 0.0 and across.length() > 0.001:
		across = across.normalized() * side
		all_pts.append((pts[1] as Vector3) + across)
		all_pts.append((pts[1] as Vector3) - across)
	var size := cam.get_viewport().get_visible_rect().size
	var half_v := deg_to_rad(cam.fov) * 0.5
	var half_h := atan(tan(half_v) * size.x / maxf(size.y, 1.0))
	for q: Vector3 in all_pts:
		if c.distance_to(q) > float(cr.get("seen_m", Resident.SEEN_M)):
			continue
		var share := Residents.off_frame(cam, q)
		if not res.clear_line(c, q):
			if share <= 0.0:
				out.stone = true
			continue
		var lp := cam.global_transform.affine_inverse() * q
		var deg := rad_to_deg(maxf(atan2(absf(lp.x), -lp.z) - half_h, atan2(absf(lp.y), -lp.z) - half_v))
		out.share = minf(float(out.share), share)
		out.deg = minf(float(out.deg), deg)
	return out


## Where to stand by holder `h` to light it (cleared_check's): a step out
## from a sconce's wall, a step back toward the room's way in from a ring.
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


## Where you pass `r`: on the floor before its place, your head inside its
## arms_m (TombNav at your size, `nav`).
func _pass_point(r: Resident, nav: TombNav) -> Vector3:
	var out: Vector3 = r.place.out
	var inward := Vector3(out.x - (r.place.pos as Vector3).x, 0.0, out.z - (r.place.pos as Vector3).z).normalized()
	for m: float in [0.8, 0.5, 0.2, 1.1]:
		var c := nav.cell_of(out + inward * m)
		if nav.is_open(c):
			var q := nav.point_of(c)
			if (r.place.eye as Vector3).distance_to(q + Vector3(0.0, PlanetPlayer.EYE_Y, 0.0)) < r.waking_m() - 0.2:
				return q
	return out


## The nearest cold holder within `within` m of `at` that your body can walk
## to, or null.
func _cold_holder_near(nav: TombNav, at: Vector3, within: float) -> Node3D:
	var best: Node3D = null
	var best_d := within
	for h in main.fires.holders:
		if FireStore.is_lit(h):
			continue
		var d := (h as Node3D).global_position.distance_to(at)
		if d < best_d and nav.path(at, _stand_by(h), false).size() >= 1:
			best_d = d
			best = h
	return best


## Walk by the keys to `goal` along your body's way (`nav`), or for `for_s`
## seconds of it, looking back over your shoulder every LOOK_EVERY_S.
func _walk_keys(nav: TombNav, goal: Vector3, for_s := -1.0) -> void:
	var path := nav.path(player.global_position, goal, true)
	if path.size() < 2:
		return
	var i := 1
	var t := 0.0
	var since_look := 0.0
	var mark := player.global_position
	var last_moved := 0.0
	Input.action_press("move_forward")
	while i < path.size() and _s_t < SESSION_S and (for_s < 0.0 or t < for_s):
		var q := path[i]
		var to := Vector3(q.x - player.global_position.x, 0.0, q.z - player.global_position.z)
		if to.length() < 0.4:
			i += 1
			continue
		player.set_view(-0.1, atan2(-to.x, -to.z))
		await _tick()
		t += DT
		since_look += DT
		if player.global_position.distance_to(mark) > 0.3:
			mark = player.global_position
			last_moved = t
		elif t - last_moved > 2.5:
			# Caught on something: on to where you were going.
			player.spawn_flat(goal, player._yaw, -0.1)
			break
		if since_look >= LOOK_EVERY_S:
			since_look = 0.0
			Input.action_release("move_forward")
			await _look_back(1.2)
			Input.action_press("move_forward")
	Input.action_release("move_forward")


## A look back over your shoulder for `s` seconds.
func _look_back(s: float) -> void:
	player.set_view(-0.1, player._yaw + PI)
	var t := 0.0
	while t < s:
		await _tick()
		t += DT


## Looking at `r` for `s` seconds.
func _look_for(r: Resident, s: float) -> void:
	var t := 0.0
	while t < s:
		if is_instance_valid(r):
			_look_at(r)
		await _tick()
		t += DT


## Looking just past `r`, `side` (1 or -1) of it: its middle `extra_deg`
## beyond where the frame's edge and its margin (creep.view_margin) lie,
## for `s` seconds, standing. Coming on, its near arm (creep.side_m) nears
## the edge of your sight.
func _side_eye(r: Resident, extra_deg: float, side: float, s: float) -> void:
	if is_instance_valid(r):
		var pts := r.view_points()
		var mid: Vector3 = pts[1] if pts.size() > 1 else r.global_position + Vector3(0.0, 0.8, 0.0)
		var cam := player.camera()
		var d := mid - cam.global_position
		var size := cam.get_viewport().get_visible_rect().size
		var th := tan(deg_to_rad(cam.fov) * 0.5) * size.x / maxf(size.y, 1.0)
		var edge := atan(th * (1.0 + 2.0 * float(r.creep().get("view_margin", 0.0))))
		player.set_view(atan2(d.y, Vector2(d.x, d.z).length()), atan2(-d.x, -d.z) + side * (edge + deg_to_rad(extra_deg)))
	var t := 0.0
	while t < s:
		await _tick()
		t += DT


## Your back to `r` for `s` seconds, standing.
func _back_to(r: Resident, s: float) -> void:
	if is_instance_valid(r):
		_look_away(r)
	var t := 0.0
	while t < s:
		await _tick()
		t += DT


## Relight holder `h` (walk to it, face it: your back to the room), stand
## there a while, then turn round to the room.
func _relight(nav: TombNav, h: Node3D) -> void:
	await _walk_keys(nav, _stand_by(h))
	var d := h.global_position - player.camera().global_position
	player.set_view(atan2(d.y, Vector2(d.x, d.z).length()), atan2(-d.x, -d.z))
	_light_holder(h)
	var t := 0.0
	while t < 4.0:
		await _tick()
		t += DT
	player.set_view(-0.1, player._yaw + PI)
	t = 0.0
	while t < 2.0:
		await _tick()
		t += DT


## 8. A few minutes in the tomb with the skeletons free (nothing can take
## you: their strikes still land on you, and Harm counts none), every frame
## logged (_boo_log): past each skeleton, nearest first, and back past them
## in reverse, then home to the hearth, looking at each as you pass; on
## with your back to it, a look back, a wait with your back turned, another
## look, a look just past it to either side; a sconce near by relit with
## your back to the room; a look back over your shoulder every LOOK_EVERY_S
## as you walk.
func _session() -> void:
	_boo_reset()
	_torch(true)
	player._invulnerable = 1.0e9
	var nav := TombNav.build(main.lay, main.get_viewport().world_3d.direct_space_state, 0.36, [player.get_rid()])
	var order: Array = []
	var left: Array = res.all.duplicate()
	var from := player.global_position
	while not left.is_empty():
		var best: Resident = null
		for q in left:
			if best == null or from.distance_to(q.place.out) < from.distance_to(best.place.out):
				best = q
		left.erase(best)
		order.append(best)
		from = best.place.out
	# Out past them all and back again (by then each is up, hunting you or
	# hanging back, or home at rest to be armed again).
	var route: Array = order.duplicate()
	var back: Array = order.duplicate()
	back.reverse()
	back.pop_front()
	route.append_array(back)
	var lit0 := main.fires.lit_count()
	var short0 := 0
	for q in res.all:
		short0 += q.stopped_short
	for i in route.size():
		var r: Resident = route[i]
		if _s_t >= SESSION_S:
			break
		if not is_instance_valid(r) or r.state == Resident.GONE:
			continue
		await _walk_keys(nav, _pass_point(r, nav))
		await _look_for(r, 1.0)
		var nxt: Vector3 = main.lay.wake[0]
		if i + 1 < route.size() and is_instance_valid(route[i + 1]):
			nxt = _pass_point(route[i + 1], nav)
		await _walk_keys(nav, nxt, 1.2)
		await _look_for(r, 1.5)
		await _back_to(r, 2.0)
		await _look_for(r, 1.5)
		# Looking just past it, one side and then the other.
		await _side_eye(r, 4.0, 1.0 if i % 2 == 0 else -1.0, 2.0)
		await _side_eye(r, 9.0, -1.0 if i % 2 == 0 else 1.0, 2.0)
		await _look_for(r, 1.0)
		var h := _cold_holder_near(nav, player.global_position, 16.0)
		if h != null:
			await _relight(nav, h)
	# And home to the hearth.
	if _s_t < SESSION_S:
		await _walk_keys(nav, main.lay.wake[0])
	Input.action_release("move_forward")
	player._invulnerable = 0.0
	var short := -short0
	for q in res.all:
		if is_instance_valid(q):
			short += q.stopped_short
	var near := "none came within %.0f m with a clear line" % Resident.SEEN_M
	if _bt.near_share < INF:
		near = "a moving one %.1f%% of the frame (%.1f°) outside its edge" % [float(_bt.near_share) * 100.0, float(_bt.near_deg)]
	print("  the session: %.1f s, %d frames (%d skeleton-frames logged), %d sconces relit; %d rose behind you, %d strikes, %d into the stone; %d skeleton-frames moved where you couldn't see them (hunting, at most %.2f m/s), %d held still in your view, %d steps undone just short of your sight; let off: %d in its strike, %d within its reach, %d at the last light" % [_s_t, _bt.frames, _bt.logged, main.fires.lit_count() - lit0, _bt.rose, _bt.struck, _bt.below, _bt.moved - _bt.strike - _bt.reach - _bt.last_light, _bt.fastest, _bt.held, short, _bt.strike, _bt.reach, _bt.last_light])
	ok(_bt.bad == 0 and _bt.frames > 0, "THE rule, over %d frames (%d skeleton-frames): no skeleton beyond its reach, outside its strike and the last light's going, changed its place, turn or pose on a frame you could see it in (%d did)" % [_bt.frames, _bt.logged, _bt.bad])
	ok(_bt.rose > 0 and _bt.moved > _bt.strike + _bt.reach + _bt.last_light and _bt.held > 0, "the session put it to the test (%d rose, %d moving frames unseen, %d held in view); the nearest call: %s, the nearest %.2f m from you; %d moving frames had part of it inside the frame with stone between" % [_bt.rose, _bt.moved - _bt.strike - _bt.reach - _bt.last_light, _bt.held, near, float(_bt.closest_m), _bt.behind_stone])


## 9. The one exception (§FF.2's reveal, left as built by Mike's 7 Oct
## note): at the floor's last light the ones you can see hurry back into
## the stone in plain view.
func _last_light() -> void:
	var line := _open_line(4.5)
	var r: Resident = res.all[0] if not res.all.is_empty() else null
	if line.is_empty() or r == null:
		ok(false, "a straight run of dark floor to watch the last light from")
		return
	var a: Vector3 = line.a
	var b: Vector3 = line.b
	_torch(true)
	player.spawn_flat(b, atan2(b.x - a.x, b.z - a.z), -0.1)
	_hunt_at(r, a, b)
	_look_at(r)
	await _frames(30)
	var held := r.state == Resident.HUNT and r.still and _flat(r.global_position, a) < 0.05
	ok(held, "one up and about, %.1f m before you, holds still while you watch it (%s)" % [_flat(r.global_position, player.global_position), r.state_name()])
	var n0 := res.all.size()
	var who := str(r.name)
	res.clear_floor()
	var phases := {}
	var moved_seen := 0
	var gone_at := -1.0
	var was := r.global_position
	var seen_s := float(Residents.CLEARED.get("retreat_seen_s", 6.0))
	var t := 0.0
	while t < seen_s + 1.0:
		await physics_frame
		t += DT
		if not is_instance_valid(r) or r.state == Resident.GONE:
			gone_at = t
			break
		if r.state == Resident.RETREAT:
			phases[r._rphase] = true
		if r.global_position.distance_to(was) > 1e-5 and res.watched(r):
			moved_seen += 1
		was = r.global_position
	var seen := false
	for g in res.gone:
		if str(g.name) == who:
			seen = bool(g.seen)
	ok(seen and moved_seen > 0 and gone_at > 0.0 and gone_at <= seen_s + 2.0 * DT, "the floor's last light catches and it hurries back into the stone in plain view, the one exception: seen going (%s), moving on %d frames you watched, gone for good %.2f s on (retreat_seen_s %.0f)" % [", ".join(phases.keys()), moved_seen, gone_at, seen_s])
	await _frames(int(seen_s / DT))
	ok(res.cleared and res.all.is_empty() and res.gone.size() >= n0, "and every one of them is gone for good (%d of %d)" % [res.gone.size(), n0])
