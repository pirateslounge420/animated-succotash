extends SceneTree
## Climbing a tree grown from its skeleton, as a player would (from play:
## "climbing up and down and around trees still feels awkward and doesn't
## always work"; "Shift should perch or duck in trees"):
##   1. walk up to the nearest branchy tree to the camp, take hold (E);
##   2. hold W: up the trunk, into the crown (how high, where it stalls);
##      then W and D together: up and round at once;
##   3. Shift on the trunk: duck in against it; hands free (the bow draws);
##      the stick takes hold again;
##   4. look out along a thick limb on your side and push W: out onto it;
##      A/D round it (on top, its side, under it); Shift: perch on it;
##   5. back on, hold S: down again (to near the ground, or you let go).
## Prints the climb step by step (height, pose, handhold) so a stall shows.
##
##   ~/bin/godot --headless --path . --fixed-fps 60 --script tools/climb_check.gd
## SPECIES="Cerrado pequi": the nearest tree of that species instead (the
## nearest tree changes from run to run with what loads first).

var main
var world
var player: PlanetPlayer
var fails := 0


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func alt() -> float:
	return world.radius_of(player.global_position) - PlanetConst.RADIUS_M - main.chunks.ground_height(player.surface_dir)


func press(a: String) -> void:
	await process_frame
	Input.action_press(a)


func release(a: String) -> void:
	await process_frame
	Input.action_release(a)


func release_all() -> void:
	await process_frame
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "shoot", "wall_jump", "sprint", "interact"]:
		Input.action_release(a)


func face(h: Vector3, pitch := 0.0) -> void:
	player._heading = h
	player._yaw = 0.0
	player.set_view(pitch, 0.0)


## Your chest's offset from the nearest trunk handhold of `g` (scene), and
## the trunk's way there: [offset, axis].
func _trunk_offset(g: BranchGraph) -> Array:
	var chest: Vector3 = player.global_position + player.up * 1.0
	var best := -1
	var best_d := INF
	for i in g.size():
		if g.limb[i] != 0:
			continue
		var d := g.pos(i).distance_to(chest)
		if d < best_d:
			best_d = d
			best = i
	return [chest - g.pos(best), g.dir(best)]


## Your offset from the wood you lead with (tree frame), and the wood's way
## there: [offset, tangent].
func _round_offset(cc: TreeClimb) -> Array:
	var i: int = cc.hold[cc.lead]
	var off: Vector3 = cc.g.frame().basis.inverse() * (player.global_position - cc.g.pos(i))
	return [off, cc.g.tangent[i]]


## How much of you an animal's eye sees through the leaves (0-1, as
## Creature._shy_m() has it: FoliageCover, only in or under a crown), on
## average over 16 points on the ground 15 m round you, 0.8 m up.
func _seen_from_ground() -> float:
	if not player.trees.under_canopy:
		return 1.0
	var eye: Vector3 = player.eye_position()
	var space := player.get_world_3d().direct_space_state
	var cover := FoliageCover.clusters_round(space, eye)
	var n: Vector3 = CubeSphere.north(player.up)
	var sum := 0.0
	for k in 16:
		var h: Vector3 = n.rotated(player.up, TAU * k / 16.0)
		var d: Vector3 = world.dir_of(player.global_position + h * 15.0)
		var from: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d) + 0.8)
		sum += FoliageCover.see_through(from, eye, cover)
	return sum / 16.0


func _describe() -> String:
	var c := player.trees.climb
	if not player.climbing or c.g == null:
		return "not climbing (perched %s)" % player.perched
	var i: int = c.hold[c.lead]
	return "%s, hold %s" % [c.pose, c.describe(i) if i >= 0 else "-"]


func _initialize() -> void:
	world = get_root().get_node("World")
	world.spawn_choice = 0
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	main._weather_timer = 1.0e9
	await frames(120)
	# The nearest tree grown from its architecture with a graph and wood to
	# hold low on its trunk.
	var here := player.global_position
	var g: BranchGraph = null
	for k in 20:
		for gg: BranchGraph in BranchGraphs.all():
			if not gg.valid() or gg.base().distance_to(here) > 120.0:
				continue
			if not TreeArch.grows(SpeciesDB.all()[gg.species]):
				continue
			if OS.get_environment("SPECIES") != "" and SpeciesDB.all()[gg.species].name != OS.get_environment("SPECIES"):
				continue
			var low := false
			for i in gg.size():
				if gg.limb[i] == 0 and gg.local[i].y < 1.6:
					low = true
			if low and (g == null or gg.base().distance_to(here) < g.base().distance_to(here)):
				g = gg
		if g != null:
			break
		await frames(30)
	if g == null:
		ok(false, "a branchy tree near the camp")
		print("RESULT fails: %d" % fails)
		quit(1)
		return
	var sp: PlantSpecies = SpeciesDB.all()[g.species]
	print("[climb] %s, %.1f m tall, %d handholds, %.0f m from the camp" % [sp.name, g.height_m, g.size(), g.base().distance_to(here)])
	# 1. Up to it and take hold.
	var base := g.base()
	var gd: Vector3 = world.dir_of(base)
	var out := CubeSphere.north(gd)
	var r0: float = g.radius[g.nearest(base + player.up * 1.0)]
	var pd: Vector3 = world.dir_of(base + out * (r0 + 0.45))
	player.global_position = world.to_scene(pd, PlanetConst.RADIUS_M + main.chunks.ground_height(pd) + 0.05)
	player.velocity = Vector3.ZERO
	await frames(30)
	face(-out)
	player.try_climb()
	await frames(10)
	if not player.climbing:
		# Why not: what the reach ray meets, how far the trunk is.
		var from := player.global_position + player.up * 1.1
		var fwd := player._camera_forward()
		var q := PhysicsRayQueryParameters3D.create(from, from + fwd * PlanetPlayer.CLIMB_REACH_M * 3.0)
		q.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		var rel := base - player.global_position
		print("[climb] no hold: reach %.2f m; the foot %.2f m off (%.2f m along the look); the ray meets %s at %.2f m; ground here %.2f, alt %.2f" % [
			PlanetPlayer.CLIMB_REACH_M, (rel - player.up * rel.dot(player.up)).length(), rel.dot(fwd), (hit.collider as Node).name if not hit.is_empty() else "nothing",
			from.distance_to(hit.position) if not hit.is_empty() else -1.0, main.chunks.ground_height(player.surface_dir), alt()])
	ok(player.climbing, "takes hold of the trunk (%s)" % _describe())
	# 2. Up.
	await press("move_forward")
	var top := 0.0
	var last := alt()
	var still := 0
	for s in 30:
		await frames(30)
		var a := alt()
		top = maxf(top, a)
		if s % 4 == 3:
			print("   %4.1f s: %.1f m up, %s" % [(s + 1) * 0.5, a, _describe()])
		still = still + 1 if absf(a - last) < 0.05 else 0
		last = a
		if still >= 6:
			break
	await release("move_forward")
	await frames(10)
	print("[climb] up the trunk: %.1f m (of %.1f), stopped: %s" % [top, g.height_m, _describe()])
	if player.climbing and top < g.height_m * 0.7:
		# Why it stopped: the wood in reach of the higher hand, how steeply
		# each goes up from it and how thick it is.
		var c0 := player.trees.climb
		var hi: int = c0.hold[0] if g.local[c0.hold[0]].y >= g.local[c0.hold[1]].y else c0.hold[1]
		var seen := 0
		for j in c0._reachable(hi, true):
			var dd: Vector3 = g.local[j] - g.local[hi]
			if dd.length() < 0.05 or seen >= 12:
				continue
			seen += 1
			print("    in reach: %d (limb %d, r %.2f m, %.1f m up), %.2f m away, %.2f of the way up%s" % [j, g.limb[j], g.radius[j], g.local[j].y, dd.length(), dd.normalized().y, "" if g.radius[j] >= TreeClimb.GRIP_R_M else " (too thin)"])
	ok(top > g.height_m * 0.35, "climbs up into the crown (%.1f m of %.1f)" % [top, g.height_m])
	# 2b. Diagonal: W and D together from partway up: higher and round.
	if player.climbing:
		await press("move_back")
		for s4 in 40:
			await frames(15)
			if alt() < top * 0.5:
				break
		await release("move_back")
		await frames(10)
		print("[climb] down to %.1f m for the diagonal: %s" % [alt(), _describe()])
		var cc := player.trees.climb
		var a0 := alt()
		var ang0 := cc._body_angle()
		# (Added up as it goes, round the trunk's own axis: a whole spiral
		# read as nothing, start to end.)
		var turned := 0.0
		var o0 := _round_offset(cc)
		await press("move_forward")
		await press("move_right")
		for k6 in 18:
			await frames(10)
			var o1 := _round_offset(cc)
			var tt: Vector3 = (o0[1] + o1[1]).normalized()
			var p0: Vector3 = o0[0] - tt * (o0[0] as Vector3).dot(tt)
			var p1: Vector3 = o1[0] - tt * (o1[0] as Vector3).dot(tt)
			turned += p0.signed_angle_to(p1, tt)
			o0 = o1
		turned = absf(turned)
		await release("move_forward")
		await release("move_right")
		await frames(10)
		print("[climb] W+D for 3 s: %.1f m higher, %.0f deg round the trunk, %s" % [alt() - a0, rad_to_deg(turned), _describe()])
		if not (alt() - a0 > 0.3 and turned > deg_to_rad(15.0)):
			print("    reaches: %s; body angle round the wood %.2f -> %.2f rad; camera %s" % [cc.holds_log.slice(-10), ang0, cc._body_angle(), player._camera_forward().snapped(Vector3.ONE * 0.01)])
		ok(alt() - a0 > 0.3 and turned > deg_to_rad(15.0), "W and D together climb up and round at once")
	# 3. Shift: duck in against the trunk; the bow draws; the stick resumes.
	await press("crouch")
	await frames(3)
	await release("crouch")
	await frames(20)
	ok(player.perched, "Shift on the trunk ducks in against it (perched %s)" % player.perched)
	if player.perched:
		var a0 := alt()
		await press("shoot")
		await frames(40)
		ok(player.bow.drawing or player.aiming(), "the bow draws from the perch")
		await release("shoot")
		await frames(40)
		ok(absf(alt() - a0) < 0.3, "the perch holds you where you ducked (%.2f m moved)" % absf(alt() - a0))
		await press("move_forward")
		await frames(20)
		await release("move_forward")
		ok(player.climbing, "the stick takes hold again")
	# 4. Out along a limb: the lowest thick limb that leaves the trunk on
	# your side; climb to its foot, look out along it and push W.
	if player.climbing:
		var c := player.trees.climb
		var up_l := Vector3.UP
		var me_y := alt()
		var best := -1
		var best_y := INF
		# (On your side of the trunk: out along the way you face out. From
		# the trunk where you hold it, not its foot: a leaning trunk isn't
		# over its foot up here.)
		var frame := g.frame()
		var out_l := frame.basis.inverse() * (player.global_position - g.pos(c.hold[c.lead]))
		out_l.y = 0.0
		out_l = out_l.normalized()
		for i in g.size():
			if g.limb[i] == 0 or g.radius[i] < TreeClimb.STRADDLE_R_M:
				continue
			# A limb's first handhold: linked to the trunk.
			var from_trunk := false
			for j in g.links[i]:
				if g.limb[j] == 0:
					from_trunk = true
			var t := g.tangent[i]
			var th := Vector3(t.x, 0.0, t.z)
			if th.length() < 0.3 or th.normalized().dot(out_l) < 0.5:
				continue
			var y: float = g.local[i].y
			if from_trunk and y > 1.5 and y < best_y:
				best_y = y
				best = i
		if best >= 0:
			# Back onto the trunk first (the diagonal may have left you on a
			# limb): down until a hand is on the trunk.
			for s3 in 40:
				var hi: int = c.hold[c.lead] if player.climbing else -1
				if hi < 0 or g.limb[hi] == 0:
					break
				await press("move_back")
				await frames(15)
			await release("move_back")
			me_y = alt()
			# Down or up the trunk to its height.
			await press("move_forward" if best_y > me_y else "move_back")
			for s2 in 240:
				await frames(10)
				if absf(alt() + 1.0 - best_y) < 0.6 or not player.climbing:
					break
			await release("move_forward")
			await release("move_back")
			await frames(10)
			print("[climb] to the limb's height (%.1f m): at %.1f m, %s" % [best_y, alt(), _describe()])
			# Look out along the limb (the way it grows).
			var along := g.frame().basis * g.tangent[best]
			var flat := (along - player.up * along.dot(player.up)).normalized()
			face(flat, 0.1)
			await press("move_forward")
			var on_limb := false
			for s in 24:
				await frames(15)
				var i: int = c.hold[c.lead] if player.climbing else -1
				if i >= 0 and g.limb[i] != 0 and not c._cling(i):
					on_limb = true
				if on_limb and s > 8:
					break
			await release("move_forward")
			await frames(15)
			print("[climb] out along the limb at %s: %s" % [c.describe(best), _describe()])
			ok(on_limb, "looking out along a thick limb and pushing W takes you out onto it")
			if on_limb:
				# Round the limb: D for a while, then A back: leaning round it,
				# always astride (from play: no hanging).
				var poses := {}
				await press("move_right")
				for s5 in 16:
					await frames(10)
					poses[c.pose] = true
				await release("move_right")
				await press("move_left")
				for s5 in 16:
					await frames(10)
					poses[c.pose] = true
				await release("move_left")
				await frames(20)
				print("[climb] round the limb: poses %s, now %s" % [poses.keys(), _describe()])
				ok(poses.keys() == ["straddle"] and player.climbing, "A/D lean you round the limb, always astride (%s)" % ", ".join(poses.keys()))
				await press("crouch")
				await frames(3)
				await release("crouch")
				await frames(20)
				ok(player.perched, "Shift on the limb perches there (%s)" % ("on top" if player._perch_local == Vector3.INF else "tucked in against its side"))
				await press("move_forward")
				await frames(20)
				await release("move_forward")
				await frames(10)
				# Out to its end, crouched there in the leaves (from play: a
				# hiding place, "for a hide and seek situation"): how much of
				# you do animals on the ground round the tree see?
				var hid0 := _seen_from_ground()
				await press("move_forward")
				var last_hold := -1
				var stalled := 0
				for s6 in 160:
					await frames(15)
					var hh: int = c.hold[c.lead] if player.climbing else -1
					stalled = stalled + 1 if hh == last_hold else 0
					last_hold = hh
					if stalled >= 12 or not player.climbing:
						break
				await release("move_forward")
				await frames(15)
				var out_m: float = (g.local[c.hold[c.lead]] - g.local[best]).length() if player.climbing else 0.0
				await press("crouch")
				await frames(3)
				await release("crouch")
				await frames(30)
				var hid := _seen_from_ground()
				print("[climb] out to the end: %.1f m out along it, %s, perched %s, under the crown %s; seen from the ground round the tree: %.0f %% (%.0f %% where you perched nearer the trunk)" % [
					out_m, _describe(), player.perched, player.trees.under_canopy, hid * 100.0, hid0 * 100.0])
				# (A measurement, not a pass/fail: how hidden depends on the
				# leaves at that end; a Miombo's umbrella ends are sparse.)
				ok(player.perched, "perched out at the end of the limb")
				await press("move_forward")
				await frames(20)
				await release("move_forward")
				await frames(10)
		else:
			# (Small trees have none; tools/climb_lab.gd goes out along and
			# round limbs on every sample species.)
			print("SKIP  no limb thick enough to straddle on this tree")
	# 5. Down.
	if not player.climbing:
		player.stop_perch(false, true)
		await frames(10)
	await press("move_back")
	var low := alt()
	for s in 60:
		await frames(30)
		low = minf(low, alt())
		if not player.climbing or low < 1.2:
			break
	await release("move_back")
	await frames(30)
	print("[climb] down: lowest %.1f m, %s" % [low, _describe()])
	ok(low < 2.0 or not player.climbing, "climbs back down (lowest %.1f m)" % low)
	# 6. Cling (right click): from the ground at the trunk, crawl up with
	# W, look up and let go: a leap up and off, toward the look.
	await release_all()
	if player.climbing:
		player.stop_climb()
	await frames(60)
	var cd: Vector3 = world.dir_of(base + out * (r0 + 0.6))
	player.global_position = world.to_scene(cd, PlanetConst.RADIUS_M + main.chunks.ground_height(cd) + 0.05)
	player.velocity = Vector3.ZERO
	await frames(30)
	face(-out)
	await press("wall_jump")
	await frames(4)
	if not player.clinging:
		# Why not: on the floor? what each ray of the fan meets.
		var fwd := player._camera_forward()
		fwd = (fwd - player.up * fwd.dot(player.up)).normalized()
		print("[climb] no cling: on floor %s, bounce wait %d, climbing %s, trunk %.2f m off" % [player.is_on_floor(), player._bounce_wait_f, player.climbing, (player.global_position - base).length()])
		for y in [1.0, 0.6, 1.4]:
			var from: Vector3 = player.global_position + player.up * y
			var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 0.9)
			q.exclude = [player.get_rid()]
			var h := player.get_world_3d().direct_space_state.intersect_ray(q)
			print("    ray at %.1f m: %s" % [y, "nothing" if h.is_empty() else "%s at %.2f m, normal.up %.2f" % [h.collider, (h.position - from).length(), (h.normal as Vector3).dot(player.up)]])
	ok(player.clinging, "right click at a trunk clings to it")
	if player.clinging:
		var a1 := alt()
		await press("move_forward")
		for k in 6:
			await frames(10)
			print("    crawl %d: alt %.2f, clinging %s, floor %s, climbing %s, crouching %s, cling_f %d, v.up %.2f" % [k, alt(), player.clinging, player.is_on_floor(), player.climbing, player.crouching, player._cling_f, player.velocity.dot(player.up)])
		await release("move_forward")
		var a2 := alt()
		print("[climb] crawling up the trunk for 1 s: %.1f -> %.1f m" % [a1, a2])
		ok(a2 - a1 > 0.8, "W crawls up the face while clinging (%.1f m)" % (a2 - a1))
		# D alone, the camera still: round the trunk and on round it, however
		# it leans (from play), added up round the trunk's own axis.
		var round_total := 0.0
		var prev_off := _trunk_offset(g)
		await press("move_right")
		for k in 36:
			await frames(10)
			if not player.clinging:
				break
			var now_off := _trunk_offset(g)
			var ax: Vector3 = now_off[1]
			var pa: Vector3 = prev_off[0] - ax * (prev_off[0] as Vector3).dot(ax)
			var pb: Vector3 = now_off[0] - ax * (now_off[0] as Vector3).dot(ax)
			round_total += pa.signed_angle_to(pb, ax)
			prev_off = now_off
			if OS.get_environment("CLINGDBG") == "1":
				print("      round %d: total %.0f deg, v %s, wall_n %s, side %.0f, off %s" % [k, rad_to_deg(round_total), player.velocity.snapped(Vector3.ONE * 0.01), player._wall_n.snapped(Vector3.ONE * 0.01), player._cling_side, pb.snapped(Vector3.ONE * 0.01)])
		await release("move_right")
		await frames(10)
		print("[climb] D clinging for 6 s: %.0f deg round the trunk, clinging %s, %.1f m up" % [rad_to_deg(absf(round_total)), player.clinging, alt()])
		ok(player.clinging and absf(round_total) > TAU, "D clinging goes all the way round the trunk (%.0f deg)" % rad_to_deg(absf(round_total)))
		# Out from the trunk where you are now (round the other side, the
		# first "out" looked into the trunk).
		var now_out: Vector3 = _trunk_offset(g)[0]
		now_out -= player.up * now_out.dot(player.up)
		if now_out.length() > 0.05:
			out = now_out.normalized()
		face(out, 0.6)
		# (A moment to look up: the look is read with the camera.)
		await frames(3)
		var p0 := player.global_position
		await release("wall_jump")
		await frames(12)
		var dv := player.global_position - p0
		print("[climb] let go looking up and out: %.2f m up, %.2f m out in 0.2 s" % [dv.dot(player.up), dv.dot(out)])
		ok(dv.dot(player.up) > 0.2 and dv.dot(out) > 0.2, "letting go leaps up and out, toward the look")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
