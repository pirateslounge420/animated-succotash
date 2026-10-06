extends SceneTree
## The fire circle (design 3 Oct §CY.2–CY.3, camps.json → sim.fire_circle,
## FireCircle), headless, full planet:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/circle_check.gd
## At the opening camp (dawn, where you wake) and at the opening road's
## people's camp, asserts:
##  - the folk sit in a ring round the fire, one seat each and a spare,
##    ring_m out, the seats at least min_gap_m apart, all facing the fire;
##  - the seats are kinds the place supplies (by_biome; at_site's on top at
##    a ruin camp; at most kinds_per_circle), wooden ones the stand's bark;
##  - over ten minutes the loops played are the built ones the phase's
##    weights allow (no pipe yet), each sitter on its own clock;
##  - inside watch_m the hood, and only the hood, turns to the player, no
##    further than head_max_deg; the body keeps facing the fire;
##  - the pipe (§CY.4): only adults smoke, one at a fire at a time, lit with
##    the brand (shown only while lighting), 3-6 draws, each breath out a
##    few puffs of the hearth smoke's colour.

var main
var world
var player: PlanetPlayer
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, -1)
	Bow.need_capture = false
	WorldSave.read_only = true
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	player.set_physics_process(false)
	var enc: Encampment = main.camp
	var fire: Node3D = enc.fire()
	var dress: Node3D = enc.get_node("Dressing")
	print("[circle] the opening camp: %s, %s; the clock %s (%s)" % [enc.people_id, FireStore.biome_key(world, enc.site), world.clock_text(enc.site), FireCircle.phase_name(world.local_clock(enc.site).y, CubeSphere.latitude(enc.site), world.days)])
	await _circle("the opening camp", dress, enc._npcs, fire, FireStore.biome_key(world, enc.site), enc.people_id, "", func(t: float, d: float) -> void: enc.update_camp(d, player.global_position))
	# The opening road's people's camp.
	var ruin: Vector3 = world.opening.get("ruin", Vector3.ZERO)
	if ruin == Vector3.ZERO:
		print("SKIP  no people's camp on the opening road")
	else:
		var stand := CreatureSpawner._offset(ruin, 0.7, 20.0)
		var off: Vector3 = world.to_scene(stand, PlanetConst.RADIUS_M + world.surface_elevation(stand))
		world.rebase(off)
		player.global_position -= off
		main.chunks.load_blocking(stand)
		player.spawn_at(stand, ruin)
		main.landmarks.build_ruin_at(ruin)
		var camp: Node3D = null
		var t0 := Time.get_ticks_msec()
		while camp == null and Time.get_ticks_msec() - t0 < 60000:
			main.camps.refresh_now()
			for k in main.camps._camps:
				var c: Node3D = main.camps._camps[k]
				if is_instance_valid(c) and c.global_position.distance_to(player.global_position) < 80.0:
					camp = c
			await process_frame
		if camp == null:
			ok(false, "the road's people's camp builds")
		else:
			var key := str(camp.get_meta("key", ""))
			var cloaked: Array = []
			for s in camp.get_meta("sitters", []):
				if (s as Node3D).has_meta("stage"):
					cloaked.append(s)
			print("[circle] the road's camp %s: %s, %s, %d folk sitting" % [key, camp.get_meta("people"), camp.get_meta("biome"), cloaked.size()])
			if cloaked.is_empty():
				print("SKIP  the road's camp has no cloaked folk sitting (%s)" % camp.get_meta("folk"))
			else:
				await _circle("the road's camp", camp, cloaked, camp.get_meta("fire"), str(camp.get_meta("biome")), str(camp.get_meta("people")),
					"ruin" if key.begins_with("ruin") else "", func(t: float, d: float) -> void:
					main.camps._time += d
					main.camps._animate(camp, d, player.global_position))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _circle(label: String, root: Node3D, sitters: Array, fire: Node3D, biome: String, people: String, site: String, step: Callable) -> void:
	var S: Dictionary = FireCircle.SEATS
	var ring: Array = S.get("ring_m", [1.6, 2.4])
	var gap := float(S.get("min_gap_m", 0.9))
	# The seats: every seat mesh under the root.
	var seats: Array = []
	for c in root.get_children():
		if (c as Node).has_meta("seat"):
			seats.append(c)
	var kinds := {}
	var seat_slots := 0
	for c in seats:
		var k := str((c as Node).get_meta("seat"))
		kinds[k] = true
		seat_slots += int(((S.get("kinds", {}) as Dictionary).get(k, {}) as Dictionary).get("seats", 1))
	var allowed := FireCircle.kinds_for(biome, people, site)
	var bad_kind := 0
	for k in kinds:
		if not allowed.has(k):
			bad_kind += 1
	ok(not seats.is_empty() and bad_kind == 0 and kinds.size() <= int(S.get("kinds_per_circle", 2)), "%s: its seats are %s, kinds the place supplies (%s)" % [label, ", ".join(kinds.keys()), ", ".join(allowed)])
	ok(seat_slots >= sitters.size() + int(S.get("spare_seats", 1)), "%s: a seat for each of the %d and a spare (%d places)" % [label, sitters.size(), seat_slots])
	# The sitters: on the ring, apart, facing the fire.
	var fpos := root.to_local(fire.global_position)
	var off_ring := 0
	var near_pair := 99.0
	var facing_off := 0.0
	for i in sitters.size():
		var s: Node3D = sitters[i]
		var p := root.to_local(s.global_position) - fpos
		var r := Vector2(p.x, p.z).length()
		if r < float(ring[0]) - 0.3 or r > float(ring[1]) + 1.1:
			off_ring += 1
		var fwd := -(root.global_basis.inverse() * s.global_basis.z)
		facing_off = maxf(facing_off, rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(-p.x, -p.z))))
		for j in range(i + 1, sitters.size()):
			near_pair = minf(near_pair, s.global_position.distance_to((sitters[j] as Node3D).global_position))
	ok(off_ring == 0, "%s: every sitter is on the ring round the fire" % label)
	ok(near_pair >= gap * 0.75, "%s: the sitters are apart (nearest %.2f m; seats at least %.1f m)" % [label, near_pair, gap])
	ok(facing_off < 25.0, "%s: every sitter faces the fire (worst %.0f° off)" % [label, facing_off])
	var wood := 0
	var wood_ok := 0
	var bark := FireCircle.stand_bark(main.chunks, fire.global_position)
	for c in seats:
		if FireCircle.WOOD.has(str((c as Node).get_meta("seat"))):
			wood += 1
			var mi := (c as MeshInstance3D) if c is MeshInstance3D else null
			var col: Color = (mi.material_override as StandardMaterial3D).albedo_color if mi != null and mi.material_override is StandardMaterial3D else bark
			if Vector3(col.r - bark.r, col.g - bark.g, col.b - bark.b).length() < 0.12:
				wood_ok += 1
	if wood > 0:
		ok(wood_ok == wood, "%s: its wooden seats are the stand's bark (%d of %d)" % [label, wood_ok, wood])
	# Ten minutes of the circle, the player away.
	var away := fire.global_position + fire.global_basis.x * 40.0
	player.global_position = away
	var played := {}
	var switches := 0
	var last := {}
	var yaw0: Array[float] = []
	for s in sitters:
		yaw0.append((s as Node3D).global_rotation.y)
	var dt := 1.0 / 10.0
	var most_pipes := 0
	var young_pipes := 0
	var puffs := 0
	var brand_bad := 0
	var draws_seen: Array[int] = []
	for k in 6000:
		step.call(k * dt, dt)
		var pipes := 0
		for s in sitters:
			var idle := str((s as Node3D).get_meta("idle", ""))
			played[idle] = int(played.get(idle, 0)) + 1
			if last.get(s, "") != idle:
				switches += 1
				last[s] = idle
				if idle == "pipe":
					draws_seen.append(((s as Node3D).get_meta("pipe_plan", {}) as Dictionary).get("draws", []).size())
			if idle == "pipe":
				pipes += 1
				if str((s as Node3D).get_meta("stage", "adult")) != "adult":
					young_pipes += 1
				var plan: Dictionary = (s as Node3D).get_meta("pipe_plan", {})
				var t := float((s as Node3D).get_meta("idle_t", 0.0))
				var brand = (s as Node3D).get_meta("brand") if (s as Node3D).has_meta("brand") else null
				var lighting := t >= float(plan.get("pack", 4.0)) + 0.1 and t < float(plan.get("pack", 4.0)) + float(plan.get("light", 3.0)) - 0.1
				var outside := t < float(plan.get("pack", 4.0)) - 0.1 or t > float(plan.get("pack", 4.0)) + float(plan.get("light", 3.0)) + 0.1
				if brand != null and is_instance_valid(brand) and ((lighting and not (brand as Node3D).visible) or (outside and (brand as Node3D).visible)):
					brand_bad += 1
			if (s as Node3D).has_meta("puff_list"):
				puffs = maxi(puffs, ((s as Node3D).get_meta("puff_list") as Array).size())
		most_pipes = maxi(most_pipes, pipes)
		if k % 600 == 0:
			await process_frame
	var bad: Array[String] = []
	for n in played:
		if not FireCircle.BUILT.has(n):
			bad.append(n)
	print("[circle] %s: ten minutes, loops played (sitter-frames): %s; %d changes" % [label, str(played), switches])
	ok(bad.is_empty() and played.size() >= 2 and switches > sitters.size() * 3, "%s: the folk pass the time in the built loops, each on its own clock (%d kinds, %d changes)" % [label, played.size(), switches])
	if draws_seen.is_empty():
		print("SKIP  %s: nobody took out a pipe in ten minutes" % label)
	else:
		var draws_ok := true
		for n in draws_seen:
			if n < 3 or n > 6:
				draws_ok = false
		ok(most_pipes <= 1 and young_pipes == 0, "%s: one pipe at a time (most %d), adults only" % [label, most_pipes])
		ok(draws_ok and brand_bad == 0, "%s: each pipe lit with the brand, %s draws" % [label, str(draws_seen)])
		ok(puffs > 0, "%s: each breath out leaves puffs (up to %d in the air)" % [label, puffs])
	# The player steps up to the first sitter, awake (watching the fire).
	var s0: Node3D = sitters[0]
	# Nobody telling for this (§EJ.3: a listener looks at the teller, not
	# the fire): the others held at watching the fire.
	for s in sitters:
		(s as Node3D).set_meta("idle", "watch_fire")
		(s as Node3D).set_meta("idle_until", 1e9)
	s0.set_meta("idle", "watch_fire")
	s0.set_meta("idle_until", 1e9)
	s0.set_meta("look_end", -1000.0)
	var side := s0.global_basis.x.normalized()
	player.global_position = s0.global_position + side * 3.0 + s0.global_basis.y * 1.4
	var t0 := 6000 * dt
	for k in 30:
		step.call(t0 + k * dt, dt)
	var head: Node3D = s0.get_meta("head")
	var turned := rad_to_deg(absf(head.rotation.y))
	var body_turn := rad_to_deg(absf(angle_difference(s0.global_rotation.y, yaw0[sitters.find(s0)])))
	ok(turned > 30.0 and turned <= float(FireCircle.NOTICE.get("head_max_deg", 70.0)) + 0.5 and body_turn < 1.0, "%s: the hood turns to you inside %.0f m (%.0f°, at most %.0f°), the body doesn't (%.1f°)" % [label, float(FireCircle.NOTICE.get("watch_m", 7.0)), turned, float(FireCircle.NOTICE.get("head_max_deg", 70.0)), body_turn])
	player.global_position = away
	for k in 80:
		step.call(t0 + 3.0 + k * dt, dt)
	ok(rad_to_deg(absf(head.rotation.y)) < 10.0, "%s: and goes back to the fire when you leave (%.0f°)" % [label, rad_to_deg(absf(head.rotation.y))])
