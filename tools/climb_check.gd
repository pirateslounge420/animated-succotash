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
	player.set_view(0.0, pitch)


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
		# (Round the wood you hold, not the tree's foot: a leaning trunk.)
		var cc := player.trees.climb
		var rel0 := player.global_position - g.pos(cc.hold[cc.lead])
		rel0 -= player.up * rel0.dot(player.up)
		var a0 := alt()
		await press("move_forward")
		await press("move_right")
		await frames(180)
		await release("move_forward")
		await release("move_right")
		await frames(10)
		var rel1 := player.global_position - g.pos(cc.hold[cc.lead])
		rel1 -= player.up * rel1.dot(player.up)
		var turned := rel0.angle_to(rel1)
		print("[climb] W+D for 3 s: %.1f m higher, %.0f deg round the trunk, %s" % [alt() - a0, rad_to_deg(turned), _describe()])
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
		# (On your side of the trunk: out along the way you face out.)
		var frame := g.frame()
		var out_l := frame.basis.inverse() * (player.global_position - g.base())
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
			for s2 in 60:
				await frames(10)
				if absf(alt() + 1.0 - best_y) < 0.6 or not player.climbing:
					break
			await release("move_forward")
			await release("move_back")
			await frames(10)
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
				# Round the limb: D for a while, then A back: the pose goes
				# from on top to its side to under it and back.
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
				ok(poses.size() >= 2 and player.climbing, "A/D go round the limb (%s)" % ", ".join(poses.keys()))
				await press("crouch")
				await frames(3)
				await release("crouch")
				await frames(20)
				ok(player.perched, "Shift on the limb perches there (%s)" % ("on top" if player._perch_local == Vector3.INF else "tucked in against its side"))
				await press("move_forward")
				await frames(20)
				await release("move_forward")
				await frames(10)
		else:
			ok(false, "a limb thick enough to straddle, off the trunk")
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
		await frames(60)
		await release("move_forward")
		var a2 := alt()
		print("[climb] crawling up the trunk for 1 s: %.1f -> %.1f m" % [a1, a2])
		ok(a2 - a1 > 0.8, "W crawls up the face while clinging (%.1f m)" % (a2 - a1))
		face(out, 0.6)
		var p0 := player.global_position
		await release("wall_jump")
		await frames(12)
		var dv := player.global_position - p0
		print("[climb] let go looking up and out: %.2f m up, %.2f m out in 0.2 s" % [dv.dot(player.up), dv.dot(out)])
		ok(dv.dot(player.up) > 0.2 and dv.dot(out) > 0.2, "letting go leaps up and out, toward the look")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
