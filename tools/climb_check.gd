extends SceneTree
## Climbing a tree grown from its skeleton, as a player would (from play:
## "climbing up and down and around trees still feels awkward and doesn't
## always work"; "Shift should perch or duck in trees"):
##   1. walk up to the nearest branchy tree to the camp, take hold (E);
##   2. hold W: up the trunk, into the crown (how high, where it stalls);
##   3. Shift on the trunk: duck in against it; hands free (the bow draws);
##      the stick takes hold again;
##   4. look out along the nearest limb above you and push W: out onto it;
##      Shift there: sit on top of it;
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
	ok(top > g.height_m * 0.35, "climbs up into the crown (%.1f m of %.1f)" % [top, g.height_m])
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
	# 4. Out along a limb: look at the nearest limb handhold above you and
	# push toward it.
	if player.climbing:
		var c := player.trees.climb
		var me := player.global_position
		var best := -1
		var best_d := INF
		for i in g.size():
			if g.limb[i] == 0 or g.radius[i] < TreeClimb.STRADDLE_R_M:
				continue
			var d := g.pos(i).distance_to(me)
			if d < best_d and d > 0.6:
				best_d = d
				best = i
		if best >= 0:
			var to := g.pos(best) - me
			var flat := (to - player.up * to.dot(player.up)).normalized()
			face(flat, clampf(to.normalized().dot(player.up), -0.8, 0.8))
			await press("move_forward")
			var on_limb := false
			for s in 24:
				await frames(15)
				var i: int = c.hold[c.lead] if player.climbing else -1
				if i >= 0 and g.limb[i] != 0:
					on_limb = true
				if on_limb and s > 8:
					break
			await release("move_forward")
			await frames(15)
			print("[climb] toward limb hold %s (%.1f m off): %s" % [c.describe(best), best_d, _describe()])
			ok(on_limb, "pushing toward a thick limb takes you out onto it")
			if on_limb:
				await press("crouch")
				await frames(3)
				await release("crouch")
				await frames(20)
				ok(player.perched and player._perch_local == Vector3.INF, "Shift on the limb sits you on top of it")
				await press("move_forward")
				await frames(20)
				await release("move_forward")
				await frames(10)
		else:
			ok(false, "a limb thick enough to straddle within reach")
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
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
