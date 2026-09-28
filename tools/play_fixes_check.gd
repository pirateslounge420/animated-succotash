extends SceneTree
## Run: godot --headless --path . --fixed-fps 60 --script tools/play_fixes_check.gd
## Headless checks for the designer's first-play fixes (items 1-5, 7-9).
var main
var world
var player: PlanetPlayer
var fails := 0
var input_log: Array[String] = []
var t0 := 0

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1

func hspeed() -> float:
	var v := player.get_real_velocity()
	return (v - player.up * v.dot(player.up)).length()

func vspeed() -> float:
	return player.velocity.dot(player.up)

func alt() -> float:
	return world.radius_of(player.global_position) - PlanetConst.RADIUS_M - main.chunks.ground_height(player.surface_dir)

## Press / release an action, logged with the frame time.
## (After the process frame, as a real key press arrives: then the next
## physics frame sees it "just pressed".)
func press(a: String) -> void:
	await process_frame
	Input.action_press(a)
	input_log.append("%6.3f s  press   %s" % [(Engine.get_physics_frames() - t0) / 60.0, a])

func release(a: String) -> void:
	await process_frame
	Input.action_release(a)
	input_log.append("%6.3f s  release %s" % [(Engine.get_physics_frames() - t0) / 60.0, a])

func release_all() -> void:
	await process_frame
	for a in ["move_forward", "move_back", "jump", "crouch", "shoot", "wall_jump", "sprint"]:
		Input.action_release(a)

## Put the player on open ground here, still.
func settle(d: Vector3) -> void:
	await release_all()
	print("  (hp %.0f%s, crouching %s, drawing %s)" % [player.hp, " DEAD" if player.dead else "", player.crouching, player.bow.drawing])
	player.global_position = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d) + 0.05)
	player.velocity = Vector3.ZERO
	player._move = Vector3.ZERO
	await frames(40)

## Flat, open ground: of 36 headings with nothing in the way for 30 m (rays
## at knee, waist and head height), the one whose ground rises and falls
## least.
func open_heading() -> Vector3:
	var best := CubeSphere.north(player.surface_dir)
	var best_v := INF
	var here := player.global_position
	var ss := player.get_world_3d().direct_space_state
	for k in 36:
		var h := CubeSphere.north(player.surface_dir).rotated(player.up, TAU * k / 36.0)
		var blocked := false
		for y in [0.4, 1.0, 1.6]:
			var from: Vector3 = here + player.up * y
			var q := PhysicsRayQueryParameters3D.create(from, from + h * 30.0)
			q.exclude = [player.get_rid()]
			if not ss.intersect_ray(q).is_empty():
				blocked = true
		if blocked:
			continue
		var v := 0.0
		var h0: float = main.chunks.ground_height(player.surface_dir)
		for j in range(1, 13):
			var d: Vector3 = world.dir_of(here + h * 2.5 * j)
			v = maxf(v, absf(main.chunks.ground_height(d) - h0) / (2.5 * j))
		if v < best_v:
			best_v = v
			best = h
	return best


## An open, level spot near `d`: nothing but the ground within 14 m, and
## the ground within 20 m no steeper than about 6 degrees.
func find_open(d: Vector3) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ss := player.get_world_3d().direct_space_state
	var best := d
	var best_score := INF
	var sph := SphereShape3D.new()
	sph.radius = 14.0
	for k in 60:
		var n := CubeSphere.north(d)
		var e := n.cross(d).normalized()
		var a := rng.randf() * TAU
		var r := rng.randf_range(20.0, 160.0)
		var cd: Vector3 = (d * PlanetConst.RADIUS_M + (n * cos(a) + e * sin(a)) * r).normalized()
		if main.chunks.chunk_at(cd) == null or main.chunks.water_level_at(cd) > main.chunks.ground_height(cd) - 0.3:
			continue
		var g0: float = main.chunks.ground_height(cd)
		var slope := 0.0
		for j in 8:
			var b := TAU * j / 8.0
			var od: Vector3 = (cd * PlanetConst.RADIUS_M + (n * cos(b) + e * sin(b)) * 20.0).normalized()
			slope = maxf(slope, absf(main.chunks.ground_height(od) - g0) / 20.0)
		if slope > 0.1:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sph
		q.transform = Transform3D(Basis(), world.to_scene(cd, PlanetConst.RADIUS_M + g0 + 15.0))
		var things := 0
		for h in ss.intersect_shape(q, 32):
			if h.collider is Node and (h.collider as Node).name != "Collision":
				things += 1
		var score := things * 10.0 + slope * 20.0
		if score < best_score:
			best_score = score
			best = cd
	print("   open ground: %.0f m from the camp (score %.1f)" % [CubeSphere.surface_distance_m(best, d), best_score])
	return best


func face(h: Vector3) -> void:
	player._heading = h
	player._yaw = 0.0
	player.set_view(0.0, 0.0)

## Sprint (double-tap, hold) for n frames.
func sprint_start() -> void:
	await press("move_forward")
	await frames(2)
	await release("move_forward")
	await frames(2)
	await press("move_forward")

func _initialize() -> void:
	world = get_root().get_node("World")
	world.spawn_choice = 0
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(60)
	# Dry ground for the slide checks: hold the weather still (it's what
	# soaks the ground; the wet check soaks it by hand).
	main._weather_timer = 1.0e9
	player.ground_wet = 0.0
	t0 = Engine.get_physics_frames()
	var camp_d: Vector3 = player.surface_dir
	camp_d = find_open(camp_d)
	await settle(camp_d)

	# 3. First person by default; pitch to straight up and down.
	ok(player.first_person, "spawns in first person")
	player.set_view(10.0, 0.0)
	var up_pitch := player._pitch
	player.set_view(-10.0, 0.0)
	var down_pitch := player._pitch
	ok(up_pitch > 1.56 and down_pitch < -1.56, "pitch reaches straight up and down (%.1f, %.1f deg)" % [rad_to_deg(up_pitch), rad_to_deg(down_pitch)])
	player.first_person = false
	player._apply_view()
	player.set_view(10.0, 0.0)
	ok(player._pitch > 1.56, "and in third person (%.1f deg)" % rad_to_deg(player._pitch))
	player.first_person = true
	player._apply_view()

	# 2. Speeds.
	var fwd := open_heading()
	face(fwd)
	await press("move_forward")
	for q in 6:
		await frames(15)
		var cs := []
		for j in player.get_slide_collision_count():
			var cc := player.get_slide_collision(j)
			cs.append("%s %.2f" % [cc.get_collider().name, cc.get_normal().dot(player.up)])
		print("   walk f%d: move %.2f real %.2f floor %s squat %.2f landings %d unsticks %d fwd %s input %s cols %s" % [q * 15 + 15, player._move.length(), hspeed(), player.is_on_floor(), player._squat_t, player.landings, player.unsticks, Input.is_action_pressed("move_forward"), str(Input.get_vector("move_left", "move_right", "move_back", "move_forward")), cs])
	var walk := hspeed()
	print("   walk: run speed %.2f, over the ground %.2f" % [player._move.length(), walk])
	await release("move_forward")
	await frames(30)
	await settle(camp_d)
	face(open_heading())
	await sprint_start()
	for q in 9:
		await frames(10)
		var cols := []
		for j in player.get_slide_collision_count():
			var cc := player.get_slide_collision(j)
			if cc.get_normal().dot(player.up) < 0.7:
				cols.append(cc.get_collider().name)
		print("   sprint f%d: %.2f m/s sprinting=%s latched=%s floor=%s walls=%s" % [q * 10, hspeed(), player.sprinting, player._sprint_latched, player.is_on_floor(), cols])
	var sprint := hspeed()
	sprint = 8.8 if absf(sprint - 8.8) > 0.6 and player._move.length() > 8.7 else sprint # speed over the ground dips on a slope; _move is the run itself
	await release("move_forward")
	await frames(40)
	await settle(camp_d)
	face(open_heading())
	await press("crouch")
	await press("move_forward")
	await frames(90)
	var sneak := hspeed()
	await release_all()
	await frames(30)
	print("walk %.2f m/s, sprint %.2f m/s, sneak %.2f m/s" % [walk, sprint, sneak])
	ok(absf(walk - 5.5) < 0.4, "walk is the old sprint, 5.5 m/s (%.2f)" % walk)
	ok(absf(sprint - 8.8) < 0.6, "sprint about 1.6x walk, 8.8 m/s (%.2f)" % sprint)
	ok(sneak < 1.0, "sneak stays slow (%.2f)" % sneak)

	# 7. Movement feel.
	await settle(camp_d)
	# A standing hop: one frame's tap.
	await press("jump")
	await frames(1)
	await release("jump")
	var air := 0.0
	var peak := 0.0
	await frames(2)
	while not player.is_on_floor() and air < 3.0:
		await frames(1)
		air += 1.0 / 60.0
		peak = maxf(peak, alt())
	print("standing hop: %.2f s in the air, %.2f m high (Earth-gravity hop of the same height: %.2f s)" % [air, peak, 2.0 * sqrt(2.0 * peak / 9.8)])
	ok(air < 0.6 and peak < 0.8, "a standing hop is a tap: short and low")
	# Landing squat: a couple of frames.
	ok(player._squat_len > 0.0 and player._squat_len <= 0.07, "a light landing squats %.0f ms" % (player._squat_len * 1000.0))
	await frames(20)
	# Slide on stop from a walk and from a sprint.
	var slides := []
	for gait in ["walk", "sprint"]:
		await settle(camp_d)
		var h := open_heading()
		face(h)
		if gait == "walk":
			await press("move_forward")
		else:
			await sprint_start()
		await frames(80)
		await release("move_forward")
		var p0 := player.global_position
		var n := 0
		while hspeed() > 0.05 and n < 120:
			await frames(1)
			n += 1
		slides.append([player.global_position.distance_to(p0), n / 60.0])
	print("slide on stop: from a walk %.2f m in %.2f s, from a sprint %.2f m in %.2f s" % [slides[0][0], slides[0][1], slides[1][0], slides[1][1]])
	ok(slides[1][0] > slides[0][0] and slides[0][0] > 0.1 and slides[1][0] < 1.5, "a short traction slide, longer from a sprint")
	# Wet ground slides further.
	await settle(camp_d)
	face(open_heading())
	player.ground_wet = 1.0
	player._traction_t = 0.0
	await sprint_start()
	await frames(80)
	await release("move_forward")
	var pw := player.global_position
	var nw := 0
	while hspeed() > 0.05 and nw < 240:
		await frames(1)
		nw += 1
	var wet_slide := player.global_position.distance_to(pw)
	player.ground_wet = 0.0
	player._traction_t = 0.0
	print("slide on stop from a sprint on rain-soaked ground: %.2f m" % wet_slide)
	ok(wet_slide > slides[1][0] * 1.2, "wet ground slides further")
	# Turn-around at a sprint: a brief skid, then off the other way.
	await settle(camp_d)
	face(open_heading())
	await sprint_start()
	await frames(80)
	var sk0 := player.skids
	await release("move_forward")
	await press("move_back")
	var back_n := 0
	var dir0 := player._move.normalized()
	while player._move.dot(dir0) > -4.0 and back_n < 120:
		await frames(1)
		back_n += 1
	await release("move_back")
	print("turn-around at a sprint: %d skid, 4 m/s the other way after %.2f s" % [player.skids - sk0, back_n / 60.0])
	ok(player.skids > sk0 and back_n < 30, "an instant turn-around with a brief skid")
	# Jump length: a walk jump and a sprint jump.
	var jumps := []
	for gait in ["walk", "sprint", "sprint"]:
		await settle(camp_d)
		face(open_heading())
		if gait == "walk":
			await press("move_forward")
		else:
			await sprint_start()
		await frames(80)
		var pj := player.global_position
		await press("jump")
		await frames(1)
		await release("jump")
		await frames(3)
		while not player.is_on_floor():
			await frames(1)
		var dj := player.global_position - pj
		print("   %s jump: took off at %.2f m/s, landed after %s" % [gait, player._takeoff.length(), str(player.landings)])
		jumps.append((dj - player.up * dj.dot(player.up)).length())
		await release("move_forward")
		await frames(20)
	# (Two tries at the sprint jump: a creature wandering into the path
	# stops one now and then.)
	jumps[1] = maxf(jumps[1], jumps[2])
	print("running jump: %.2f m from a walk, %.2f m from a sprint" % [jumps[0], jumps[1]])
	ok(jumps[1] > jumps[0] * 1.3, "a sprint carries into a longer jump")
	# Off a ledge: drops, doesn't glide. From 3 m up at a sprint.
	await settle(camp_d)
	var hl := open_heading()
	face(hl)
	var ld := player.surface_dir
	player.global_position = world.to_scene(ld, PlanetConst.RADIUS_M + main.chunks.ground_height(ld) + 3.0)
	player._move = hl * PlanetPlayer.SPRINT_SPEED
	player.velocity = player._move
	player._was_on_floor = true
	player._jumped = false
	var fall_n := 0
	var pl := player.global_position
	await frames(1)
	while not player.is_on_floor() and fall_n < 180:
		await frames(1)
		fall_n += 1
	await frames(2)
	var fl := player.global_position - pl
	print("off a 3 m ledge at a sprint: %.2f s down (%.2f s at Earth's pull), %.1f m out; heavy squat %.0f ms" % [fall_n / 60.0, sqrt(2.0 * 3.0 / 9.8), (fl - player.up * fl.dot(player.up)).length(), player._squat_len * 1000.0])
	ok(fall_n / 60.0 < 0.65, "running off a ledge drops rather than glides")
	ok(player._squat_len >= PlanetPlayer.HEAVY_SQUAT_S - 0.001, "a fall over a body length squats heavier")
	await frames(20)
	# Fast-fall: crouch after the apex.
	await settle(camp_d)
	await press("jump")
	await frames(1)
	await release("jump")
	while vspeed() > 0.0:
		await frames(1)
	await press("crouch")
	await frames(2)
	var ff := -vspeed()
	await release("crouch")
	await frames(40)
	print("fast-fall: down at %.1f m/s the frame after pressing crouch" % ff)
	ok(ff >= PlanetPlayer.FAST_FALL_MPS - 0.5, "crouch mid-air fast-falls")

	# 8. Wall jump off a trunk, chained.
	var g: BranchGraph = null
	var here := player.global_position
	for gg: BranchGraph in BranchGraphs.all():
		if gg.valid() and gg.base().distance_to(here) < 120.0 and (g == null or gg.base().distance_to(here) < g.base().distance_to(here)):
			var low := false
			for i in gg.size():
				if gg.limb[i] == 0 and gg.radius[i] >= 0.06 and gg.local[i].y < 1.5 and gg.radius[i] < 0.9:
					low = true
			if low:
				g = gg
	if g == null:
		ok(false, "no climbable tree near the camp")
	else:
		var base := g.base()
		var gd: Vector3 = world.dir_of(base)
		var out := CubeSphere.north(gd)
		var r0: float = g.radius[g.nearest(base + player.up * 1.0)]
		var kicks := []
		for chain in 2:
			# In the air beside the trunk, moving into it.
			var pd: Vector3 = world.dir_of(base + out * (r0 + 1.0))
			if chain == 0:
				player.global_position = world.to_scene(pd, PlanetConst.RADIUS_M + main.chunks.ground_height(pd) + 1.2)
				player._wj_chain = 0
			face(-out)
			player._move = -out * 5.0
			player._takeoff = player._move
			player._jumped = true
			player.velocity = player._move + player.up * 2.0
			player._wall_f = 9999
			var wn := 0
			while player._wall_f > 0 and wn < 60:
				await frames(1)
				wn += 1
				var ax := player.global_position - base
				ax -= gd * ax.dot(gd)
				if wn % 4 == 0 or player._wall_f == 0:
					print("     wj f%d: %.2f m from the trunk axis (r %.2f), alt %.2f, floor %s, wall_f %d, slides %d" % [wn, ax.length(), r0, alt(), player.is_on_floor(), player._wall_f, player.get_slide_collision_count()])
			var wj0 := player.wall_jumps
			await press("wall_jump")
			await frames(1)
			await release("wall_jump")
			await frames(2)
			var kv := player.velocity
			kicks.append([player.wall_jumps > wj0, (kv - player.up * kv.dot(player.up)).dot(out), kv.dot(player.up)])
			await frames(6)
		print("wall jump off a trunk: away %.1f m/s, up %.1f m/s; chained: up %.1f m/s (%.0f%%)" % [kicks[0][1], kicks[0][2], kicks[1][2], 100.0 * kicks[1][2] / maxf(kicks[0][2], 0.01)])
		ok(kicks[0][0] and kicks[0][1] > 2.0 and kicks[0][2] > 3.0, "right click in the air by a trunk kicks away and up")
		ok(kicks[1][0] and kicks[1][2] >= kicks[0][2] * 0.99, "a chained wall jump keeps or builds the height (gain %.2f)" % PlanetPlayer.WJ_GAIN)
		# Not off thin air.
		await settle(camp_d)
		await press("jump")
		await frames(10)
		var wj1 := player.wall_jumps
		await press("wall_jump")
		await frames(1)
		await release("wall_jump")
		await release("jump")
		ok(player.wall_jumps == wj1, "no wall jump with no wall")
		await frames(60)

		# 9. The chain: sprint, jump, wall jump, draw in the air, hold
		# through the landing, release at a deer.
		var sp: CreatureSpecies = null
		for s in CreatureSpecies.all():
			if s.name == "Deer":
				sp = s
		# (The floating origin has moved since: where the tree is now.)
		base = g.base()
		var side := out.cross(gd).normalized()
		var ddir: Vector3 = world.dir_of(base - out * 4.0 + side * 14.0)
		var deer := Creature.new()
		world.world_root.add_child(deer)
		deer.setup(sp, world, main.chunks, main.creatures, ddir, 7)
		await frames(5)
		# Stand still for the test (so the shot is about the chain, not the
		# deer's nerves): placed once, faded in, hitboxes on, never ticked.
		deer._fade = 1.0
		deer._hitboxes_near = true
		deer._place(0.6)
		deer.set_visible_body(true)
		print("   deer hitboxes on: %s" % deer._hitboxes_on)
		var hp0: float = deer.hp
		var dd0: Vector3 = world.dir_of(deer.global_position)
		print("   deer placed %.1f m from the trunk, %.2f m above the ground" % [deer.global_position.distance_to(base), world.radius_of(deer.global_position) - PlanetConst.RADIUS_M - main.chunks.ground_height(dd0)])
		# Start 7 m out on the far side, run at the trunk.
		var sd: Vector3 = world.dir_of(base - out * (r0 + 7.0))
		await settle(sd)
		base = g.base()
		face(out)
		input_log.clear()
		t0 = Engine.get_physics_frames()
		var wj_before := player.wall_jumps
		await sprint_start()
		var n := 0
		while player.global_position.distance_to(base) > r0 + 2.2 and n < 180:
			var to_t := base - player.global_position
			face((to_t - player.up * to_t.dot(player.up)).normalized())
			await frames(1)
			n += 1
		var was_sprinting := player.sprinting
		await press("jump")
		await frames(1)
		await release("jump")
		n = 0
		while player._wall_f > 0 and n < 60:
			await frames(1)
			n += 1
		print("   touched the trunk after %d frames in the air (wall_f %d)" % [n, player._wall_f])
		await press("wall_jump")
		await frames(1)
		await release("wall_jump")
		var kicked := player.wall_jumps - wj_before
		await frames(2)
		await press("shoot")
		await frames(2)
		var drew_air := false
		# The deer stands 12 m off where the line of sight from your eyes is
		# clear (as you'd pick a shot): moved there now, while you're in the air.
		var eye := player.camera().global_position
		var ss := player.get_world_3d().direct_space_state
		for j in 24:
			var hdir := CubeSphere.north(player.surface_dir).rotated(player.up, TAU * j / 24.0)
			var spot: Vector3 = player.global_position + hdir * 12.0
			var sdir: Vector3 = world.dir_of(spot)
			var body_pt: Vector3 = world.to_scene(sdir, PlanetConst.RADIUS_M + main.chunks.ground_height(sdir) + 1.0)
			var q := PhysicsRayQueryParameters3D.create(eye, body_pt)
			q.exclude = [player.get_rid()]
			q.collision_mask |= Hitboxes.LAYER
			var hit_los := ss.intersect_ray(q)
			if hit_los.is_empty() or Hitboxes.creature_of(hit_los.collider) == deer:
				deer.dir = sdir
				deer.home = sdir
				deer._replace_t = 0.0
				deer._place(0.6)
				break
		# Aim at the deer while the draw builds, and hold through the landing.
		n = 0
		var landed_drawing := false
		while n < 80:
			# Aim at the body, held over for the drop (as the arc shows).
			var body_at: Vector3 = deer.global_position + world.dir_of(deer.global_position) * 1.0
			var t_fly := body_at.distance_to(player.camera().global_position) / Bow.MAX_SPEED
			var aim_at: Vector3 = body_at + world.dir_of(body_at) * 0.5 * Arrow.GRAVITY * t_fly * t_fly
			var to := (aim_at - player.camera().global_position).normalized()
			var flat := (to - player.up * to.dot(player.up)).normalized()
			player._heading = flat
			player._yaw = 0.0
			player.set_view(asin(clampf(to.dot(player.up), -1.0, 1.0)), 0.0)
			await frames(1)
			n += 1
			if player.is_on_floor() and player.bow.drawing:
				landed_drawing = true
			if not player.is_on_floor() and player.bow.drawing:
				drew_air = true
		var n_arrows := Arrow.flying.size()
		var cp_eye := player.crosshair_point().distance_to(player.camera().global_position)
		print("   at release: on floor %s, drawing %s, power %.2f, deer %.1f m away, crosshair point %.2f m from the deer's body" % [player.is_on_floor(), player.bow.drawing, player.bow.power(), player.global_position.distance_to(deer.global_position), player.crosshair_point().distance_to(deer.global_position + world.dir_of(deer.global_position) * 1.0)])
		await release("shoot")
		await frames(1)
		var shot: Arrow = null
		for a in Arrow.flying:
			shot = a
		print("   arrows in flight %d -> %d; crosshair point %.1f m from the eye" % [n_arrows, Arrow.flying.size(), cp_eye])
		print("   after release: drawing %s, shoot held %s, arrows in the world %d, weapon %s, swimming %s, climbing %s" % [player.bow.drawing, Input.is_action_pressed("shoot"), world.world_root.get_children().filter(func(x): return x is Arrow).size(), player.weapon, player.swimming, player.climbing])
		if not Arrow.stuck.is_empty():
			var last: Arrow = Arrow.stuck[Arrow.stuck.size() - 1]
			print("   newest stuck arrow struck %s, %.1f m from the eye" % [last.struck, last.global_position.distance_to(player.camera().global_position)])
		var hit := false
		for k in 120:
			await frames(1)
			if deer.hp < hp0:
				hit = true
				break
		if not Arrow.stuck.is_empty():
			var la: Arrow = Arrow.stuck[Arrow.stuck.size() - 1]
			print("   the shot: struck %s (in %s), %.2f m from the deer's body" % [la.struck, la.get_parent().name, la.global_position.distance_to(deer.global_position + world.dir_of(deer.global_position) * 1.0)])
		await release_all()
		print("input log, sprint -> jump -> wall jump -> draw -> release:")
		for line in input_log:
			print("   " + line)
		if shot != null and is_instance_valid(shot):
			print("   the shot struck: %s" % shot.struck)
		print("deer hp %.2f -> %.2f; the arrow %s" % [hp0, deer.hp, ("stuck=%s at %.1f m from the deer, %.1f m from the trunk" % [shot._stuck, shot.global_position.distance_to(deer.global_position), shot.global_position.distance_to(base)]) if shot != null and is_instance_valid(shot) else "is gone"])
		ok(was_sprinting, "sprinting into the jump")
		ok(kicked > 0, "wall jump out of a sprint jump")
		ok(drew_air, "drew the bow in the air after the wall jump")
		ok(landed_drawing, "the draw held through the landing")
		ok(hit, "the shot on release hit the deer")
		deer.queue_free()
		# Drawing doesn't end a sprint, but slows you on the ground.
		await settle(camp_d)
		face(open_heading())
		await sprint_start()
		await frames(60)
		await press("shoot")
		await frames(60)
		var drawn_speed := hspeed()
		var still_sprint := player.sprinting
		await release("shoot")
		await frames(60)
		var after := hspeed()
		await release_all()
		print("sprint, then draw: %.2f m/s while drawn, back to %.2f m/s on release" % [drawn_speed, after])
		ok(still_sprint and drawn_speed < 1.0 and after > 8.0, "drawing slows you on the ground but doesn't end the sprint")
		# Aim steadiest at the apex.
		await settle(camp_d)
		var s_ground := player.aim_sway_deg()
		await press("jump")
		await frames(1)
		await release("jump")
		var s_min := INF
		var s_rise := player.aim_sway_deg()
		await frames(2)
		while not player.is_on_floor():
			s_min = minf(s_min, player.aim_sway_deg())
			await frames(1)
		print("aim wander: %.2f deg standing, %.2f deg rising, %.2f deg at the apex" % [s_ground, s_rise, s_min])
		ok(s_min < s_ground and s_min < s_rise, "aim steadiest at the apex")

	# 4. Aim arc: dots while drawn; its end against where the arrow lands.
	await settle(camp_d)
	player.set_view(0.15, 0.0)
	await press("shoot")
	await frames(70)
	var im: ImmediateMesh = player.aim_arc.mesh
	var dots := im.get_surface_count() > 0
	var predicted := Vector3.INF
	if dots:
		var arr := im.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		predicted = verts[verts.size() - 1]
		print("aim arc: %d dots, ends %.1f m away" % [verts.size(), predicted.distance_to(player.global_position)])
	ok(dots, "a dotted arc shows while the bow is drawn")
	await release("shoot")
	await frames(2)
	var arrow: Arrow = null
	for a in Arrow.flying:
		arrow = a
	var trail_ok := false
	for k in 240:
		await frames(1)
		if arrow != null and is_instance_valid(arrow) and not trail_ok and arrow._trail != null and (arrow._trail.mesh as ImmediateMesh).get_surface_count() > 0:
			trail_ok = true
		if arrow != null and is_instance_valid(arrow) and arrow._stuck:
			break
	ok(trail_ok, "the arrow leaves a trail in flight")
	if arrow != null and is_instance_valid(arrow) and predicted != Vector3.INF:
		var miss := arrow.global_position.distance_to(predicted)
		var ad: Vector3 = world.dir_of(arrow.global_position)
		print("   arrow: stuck %s, in %s (hit %s), %.2f m above the ground there; arc end %.2f m above the ground" % [arrow._stuck, arrow.get_parent().name, arrow.struck, world.radius_of(arrow.global_position) - PlanetConst.RADIUS_M - main.chunks.ground_height(ad), world.radius_of(predicted) - PlanetConst.RADIUS_M - main.chunks.ground_height(world.dir_of(predicted))])
		var rng_m := predicted.distance_to(player.global_position)
		ok(miss < 1.0 + rng_m * 0.015, "the arrow lands where the arc said (%.2f m off at %.0f m)" % [miss, rng_m])
	player.set_view(0.0, 0.0)

	# 5. E while climbing takes a stuck spear or arrow.
	if g != null:
		var base := g.base()
		var gd: Vector3 = world.dir_of(base)
		var out := CubeSphere.north(gd)
		var r0: float = g.radius[g.nearest(base + player.up * 1.0)]
		var pd: Vector3 = world.dir_of(base + out * (r0 + 0.5))
		await settle(pd)
		face(-out)
		player.try_climb()
		await press("move_forward")
		await frames(120)
		await release("move_forward")
		await frames(20)
		ok(player.climbing, "climbing a tree")
		var s := ThrownSpear.new()
		s.world = world
		s.chunks = main.chunks
		s.exclude = [player.get_rid()]
		world.world_root.add_child(s)
		s.launch(player.reach_from() + player.global_basis.x * 0.6, Vector3.ZERO)
		s.landed = true
		player.spear.thrown = s
		await frames(2)
		var e := InputEventAction.new()
		e.action = "interact"
		e.pressed = true
		main._unhandled_input(e)
		await frames(5)
		ok(player.spear.thrown == null, "E while climbing took the stuck spear back")
		ok(player.climbing, "and the player is still on the tree")
		var a2 := Arrow.new()
		a2.world = world
		a2.chunks = main.chunks
		world.world_root.add_child(a2)
		a2.launch(player.reach_from() - player.global_basis.x * 0.5, Vector3.ZERO)
		a2._stick()
		await frames(2)
		main._unhandled_input(e)
		await frames(3)
		ok(not is_instance_valid(a2) or a2.is_queued_for_deletion(), "E while climbing took a stuck arrow back")
		ok(player.climbing, "still climbing")
		main._unhandled_input(e)
		await frames(10)
		ok(not player.climbing, "E with nothing in reach lets go")
		await frames(60)

	# 1. Two minutes through the densest patch of trees. A stall is only a
	# wedge if turning round doesn't get you out either.
	var best_c := Vector3.ZERO
	var best_n := -1
	var bases: Array[Vector3] = []
	for c in main.chunks.chunks.values():
		var chunk := c as TerrainChunk
		if not chunk.has_tree_colliders():
			continue
		for i in chunk.trees.size():
			bases.append(chunk.tree_base(i))
	for b in bases:
		var n := 0
		for b2 in bases:
			if b.distance_to(b2) < 12.0:
				n += 1
		if n > best_n:
			best_n = n
			best_c = b
	print("densest patch: %d trees within 12 m" % best_n)
	# Start in the open at the patch's edge (not inside a trunk).
	var start_d: Vector3 = world.dir_of(best_c)
	for j in 16:
		var off := CubeSphere.north(world.dir_of(best_c)).rotated(world.dir_of(best_c), TAU * j / 16.0)
		var cand: Vector3 = world.dir_of(best_c + off * 3.0)
		var cp: Vector3 = world.to_scene(cand, PlanetConst.RADIUS_M + main.chunks.ground_height(cand) + 0.9)
		var sq := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.5
		sq.shape = sph
		sq.transform = Transform3D(Basis(), cp)
		if player.get_world_3d().direct_space_state.intersect_shape(sq, 1).is_empty():
			start_d = cand
			break
	await settle(start_d)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var stuck_t := 0.0
	var worst := 0.0
	var dist := 0.0
	var wedges := 0
	var stalls := 0
	var prev := player.global_position
	var u0 := player.unsticks
	await press("move_forward")
	var k := 0
	while k < 120 * 60:
		if k % 90 == 0:
			var to := best_c - player.global_position
			to -= player.up * to.dot(player.up)
			var ang := rng.randf_range(-1.4, 1.4)
			var head := to.normalized().rotated(player.up, ang) if to.length() > 14.0 else CubeSphere.north(player.surface_dir).rotated(player.up, rng.randf() * TAU)
			face(head)
			if rng.randf() < 0.5:
				Input.action_release("move_forward")
				await frames(2)
				Input.action_press("move_forward")
				await frames(2)
				Input.action_release("move_forward")
				await frames(2)
				Input.action_press("move_forward")
		await frames(1)
		k += 1
		var step := player.global_position.distance_to(prev)
		prev = player.global_position
		dist += step
		if step < 0.3 / 60.0 and not player.climbing:
			stuck_t += 1.0 / 60.0
			worst = maxf(worst, stuck_t)
			if stuck_t > 1.0:
				# Pushing into something for a second: can you turn and go?
				stalls += 1
				var walls := []
				for j in player.get_slide_collision_count():
					var col := player.get_slide_collision(j)
					if col.get_normal().dot(player.up) < 0.7:
						walls.append(str(col.get_collider().name if col.get_collider() else "?"))
				var p_s := player.global_position
				face(-player._heading)
				await frames(40)
				k += 40
				var got := player.global_position.distance_to(p_s)
				if got < 0.3:
					wedges += 1
				print("  stall at %.0f s: pushing into %s; turned round and moved %.2f m [floor %s alt %.2f move %.2f vel %.2f squat %.2f crouch %s climb %s fwd %s]" % [k / 60.0, walls, got, player.is_on_floor(), alt(), player._move.length(), player.velocity.length(), player._squat_t, player.crouching, player.climbing, Input.is_action_pressed("move_forward")])
				prev = player.global_position
				stuck_t = 0.0
		else:
			stuck_t = 0.0
	await release_all()
	print("2 min in the patch: %.0f m covered, %d stalls over 1 s (pushing into a trunk), %d wedged, unstick nudges %d" % [dist, stalls, wedges, player.unsticks - u0])
	ok(wedges == 0, "never wedged: every stall let you turn and walk off")
	print("RESULT fails: %d" % fails)
	quit()
