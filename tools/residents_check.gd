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
##  3. waking: a skeleton stays at rest with your head just beyond wakes_m
##     of its head, and wakes within it, its near tell (bone grinding)
##     sounding as it starts to climb out; at rest it is no swing's target
##     (no strike in play), awake it is your pursuer (Pursuit, Harm, §FD);
##     once out it hunts you;
##  4. hiding (§FC.2): crouched behind a lidded coffin with your torch
##     doused, it never senses you (you are hidden from it by the coffin
##     alone), gives you up after out_of_sight_s and walks back to lie in
##     its own place (queue 59, §FF.2: if a way through the dark leads
##     there; with the lit hearth room between, it hangs back in the dark
##     instead); the same with the torch lit, it sees the light round the
##     coffin and comes for you;
##  5. the strike (queue 57's CreatureStrike, §FA.1-2): in reach it winds
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
##     wake on the mat by the hearth, unhurt, its chase given up.

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
	await _wake()
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
		r.def = res.creature(r.kind)
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


## As _pick, but one whose waking test spot (_wake: just beyond its
## wakes_m, in front of it) is out of every other skeleton's wakes_m, so
## only it is tested there (two in one catacomb can rest close, design
## §EX.4 setting the niches round the sconces), and where your body fits
## at both of _wake's spots (in an 8 m crypt, just beyond wakes_m in front
## of a coffin is the far row's coffins, design §EX.2); else _pick's.
func _pick_alone(kinds: Array) -> Resident:
	for k in kinds:
		for r in res.all:
			if str(r.place.rests_in) != k or int(r.place.spot) < 0:
				continue
			var e: Vector3 = r.place.eye
			var out: Vector3 = r.place.out
			var inward := Vector3(out.x - (r.place.pos as Vector3).x, 0.0, out.z - (r.place.pos as Vector3).z).normalized()
			var d := float(r.def.get("wakes_m", 3.0)) + 0.4
			var dy := out.y + PlanetPlayer.EYE_Y - e.y
			var eye := Vector3(e.x, out.y, e.z) + inward * sqrt(maxf(d * d - dy * dy, 0.0)) + Vector3(0.0, PlanetPlayer.EYE_Y, 0.0)
			var alone := true
			for q in res.all:
				if q != r and (q.place.eye as Vector3).distance_to(eye) <= float(q.def.get("wakes_m", 3.0)) + 0.3:
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


## 3. Waking at wakes_m.
func _wake() -> void:
	var r := _pick_alone(["wall_niche", "grave"])
	if r == null:
		ok(false, "a skeleton to wake")
		return
	var e: Vector3 = r.place.eye
	var out: Vector3 = r.place.out
	var inward := Vector3(out.x - (r.place.pos as Vector3).x, 0.0, out.z - (r.place.pos as Vector3).z).normalized()
	var wakes := float(r.def.get("wakes_m", 3.0))
	var stand := func(d: float) -> void:
		var dy := out.y + PlanetPlayer.EYE_Y - e.y
		var h := sqrt(maxf(d * d - dy * dy, 0.0))
		var at := Vector3(e.x, out.y, e.z) + inward * h
		player.spawn_flat(at, atan2(inward.x, inward.z), -0.2)
	stand.call(wakes + 0.4)
	await _frames(30)
	ok(r.state == Resident.REST, "%s (%s) stays at rest with your head %.1f m from its head, just beyond wakes_m %.1f (%s)" % [r.name, r.place.rests_in, e.distance_to(player.eye_position()), wakes, r.state_name()])
	var resting := 0
	for q in res.all:
		if q.strike != null or CreatureStrike.all.any(func(cs) -> bool: return is_instance_valid(cs) and (cs as Node).get_parent() == q):
			resting += 1
	ok(resting == 0, "at rest they are set dressing: no swing meets one (no strike of theirs in play; %d)" % resting)
	stand.call(wakes - 0.3)
	var woke := -1.0
	for i in 20:
		await physics_frame
		if r.state != Resident.REST:
			woke = i * DT
			break
	ok(r.state == Resident.RISING, "with your head %.1f m from it, inside wakes_m, it wakes and climbs out (%s after %.2f s)" % [e.distance_to(player.eye_position()), r.state_name(), woke])
	ok(r.last_sound == "near" and r.voice.stream != null, "its near tell sounds as it starts to move: bone grinding on stone (%s)" % r.last_sound)
	ok(r.pursuit.on and main.harm.chased() and r.strike != null and CreatureStrike.all.has(r.strike), "awake, it is your pursuer (Pursuit, Harm, §FD), and its strike is in play")
	var rise := float(r.def.get("rise_s", 1.6))
	var t := 0.0
	while r.state == Resident.RISING and t < rise + 1.0:
		await physics_frame
		t += DT
	var flat := Vector2(r.global_position.x - out.x, r.global_position.z - out.z).length()
	ok(r.state != Resident.RISING and r.state != Resident.REST and absf(t - rise) < 0.2 and flat < 0.6, "it is out on the floor before its place after rise_s %.1f (%.2f s, %.2f m from its way out) and hunts you (%s)" % [rise, t, flat, r.state_name()])


## A lidded coffin to hide behind, and where a skeleton stands seeing it:
## {"hide", "watch", "piece"} or {}.
func _cover() -> Dictionary:
	var lay := main.lay
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
				return {"hide": hide, "watch": watch, "piece": int(pc.id), "stand_seen": res.clear_line(eye, stand_head)}
	return {}


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
	player.spawn_flat(hide, atan2(-(watch.x - hide.x), -(watch.z - hide.z)), 0.0)
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
		ok(sensed in ["flame", "glow"], "the same with the torch lit: it sees your light round the coffin (%s)" % sensed)
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
	ok(r.winding_up() and cs.sound == "jaw_creak" and cs.tell_frame == cs.wind_up_frame and SkeletonRig.POSES[r.sprite.pose if r.sprite != null else SkeletonRig.POSES.find("wind_up")] == "wind_up", "in reach and seeing you it winds up, the jaw open, its tell (the jaw's creak, %s) sounding from the wind-up's first frame (frame %d, the wind-up's %d)" % [cs.sound, cs.tell_frame, cs.wind_up_frame])
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
	ok(did == "staggered" and cs.reeling() and r.state_name() == "reel" and absf(cs.met_at_share - 0.5) < 0.05 and player.noise_level >= 0.99, "your lit torch's swing meeting it at half its wind-up (%.2f) staggers it: it reels, its strike broken, and the swing is loud as a sprint (noise %.2f)" % [cs.met_at_share, player.noise_level])
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
	# test) and you step out of its reach.
	r.def = r.def.duplicate(true)
	r.def["walk_mps"] = 0.0
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
