extends SceneTree
## The barrow's delve (design 1 Oct §CJ; Delves), headless, full planet:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/delve_check.gd
## Boots the game, finds the nearest barrow with a delve (within 40, 150
## or 400 km of the opening camp), prints its layout and asserts:
##  - the pieces chain: each starts where the one before ends (or on its
##    wall); stairs no steeper than 35 degrees; every ceiling under the open
##    ground has Delves.COVER_M of earth over it;
##  - every quad the ground leaves open is roofed: a ray from the sky over
##    it meets the barrow, the cairn or a flagstone, never nothing;
##  - you can walk it: along every piece a floor under you (within 0.35 m
##    of the layout's) and headroom of 2 m or more over it;
##  - at noon, in the heart: inside a delve, underground, no sun or moon,
##    the dread counts it night, and the ground's safety net leaves you
##    there;
##  - the first room's old hearth is there, cold, and catches from a torch;
##  - the find lies by the dead and, taken, is kept as taken;
##  - the cairn's slab won't move from outside and opens from inside.
## A world with no delve barrow in reach is SKIP.

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
	world.pin(seed_v, 0)
	Bow.need_capture = false
	WorldSave.read_only = true
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	var camp: Vector3 = main.camp.site
	var map: PlanetData = world.planet
	var site := {}
	for r in [40000.0, 150000.0, 400000.0]:
		var bd := INF
		for s in Ruins.near(map, camp, r):
			if not Delves.has_delve(s):
				continue
			var dd := CubeSphere.surface_distance_m(s.dir, camp)
			if dd < bd:
				bd = dd
				site = s
		if not site.is_empty():
			break
	if site.is_empty():
		print("SKIP  no barrow with a delve within 400 km")
		print("RESULT fails: %d" % fails)
		quit(0)
		return
	var lay := Delves.layout(map, site)
	var label := "barrow %s (%.1f km)" % [str(site.get("style", "")), CubeSphere.surface_distance_m(site.dir, camp) / 1000.0]
	print("[delve] seed %d · %s · half %.1f x %.1f m" % [seed_v, label, float(site.half_w), float(site.half_l)])
	for pc in lay.pieces:
		print("[delve]   %-6s c=(%.1f, %.1f) dir=(%d,%d) len %.1f half %.1f floor %.1f -> %.1f h %.1f" % [pc.kind, pc.c.x, pc.c.y, int(pc.dir.x), int(pc.dir.y), pc.len, pc.half, pc.y0, pc.y1, pc.h])
	print("[delve]   holes %d · exit %s · feature %s · find %s" % [(lay.holes as Array).size(), "none" if (lay.exit as Dictionary).is_empty() else "yes", lay.feature, lay.find_kind])
	_static_checks(map, site, lay)
	await _go(Delves.to_dir(Delves.frame(map, site), 0.0, -float(site.half_l) - 8.0), site.dir)
	var node := await _built(site)
	ok(node != null and node.has_meta("delve"), "%s: built, with its delve" % label)
	if node == null:
		print("RESULT fails: %d" % fails)
		quit(1)
		return
	# Collision for the ruin, all of it.
	for i in 400:
		if not RuinBuilder.wants_collision(node):
			break
		RuinBuilder.build_collision_part(node)
	await _roof_check(map, site, lay, node, label)
	await _walk_check(lay, node, label)
	await _dark_check(lay, node, label)
	await _hearth_check(lay, node, label)
	await _find_check(lay, node, label, int(site.seed))
	await _door_check(lay, node, label)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _go(d: Vector3, look: Vector3) -> void:
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	player.global_position -= off
	main.chunks.load_blocking(d)
	player.spawn_at(d, look)
	main.landmarks.build_ruin_at(d)
	for i in 30:
		await process_frame


func _built(site: Dictionary) -> Node3D:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		var ruins: Dictionary = main.landmarks.built_ruins()
		for c in ruins:
			var n: Node3D = ruins[c]
			if is_instance_valid(n) and int((n.get_meta("site", {}) as Dictionary).get("seed", 0)) == int(site.seed):
				return n
		await process_frame
	return null


func _static_checks(map: PlanetData, site: Dictionary, lay: Dictionary) -> void:
	var pieces: Array = lay.pieces
	var chained := true
	for i in range(1, pieces.size()):
		var prev: Dictionary = pieces[i - 1]
		var pc: Dictionary = pieces[i]
		var aa := Delves.along_across(prev, pc.c)
		var on_end := absf(aa.x - float(prev.len)) < 0.3 and absf(aa.y) <= float(prev.half) + 0.05
		var on_wall := aa.x >= -0.1 and aa.x <= float(prev.len) + 0.1 and absf(absf(aa.y) - float(prev.half)) < 0.35
		# Or the one before ends on this one's start edge (a stair landing
		# to one side of a room's middle).
		var pend: Vector2 = (prev.c as Vector2) + (prev.dir as Vector2) * float(prev.len)
		var bb := Delves.along_across(pc, pend)
		var lands := absf(bb.x) < 0.3 and absf(bb.y) <= float(pc.half) + 0.05
		var y_meet := absf(Delves.floor_of(prev, clampf(aa.x, 0.0, float(prev.len))) - float(pc.y0)) < 0.05 or (lands and absf(float(prev.y1) - float(pc.y0)) < 0.05)
		if not ((on_end or on_wall or lands) and y_meet):
			chained = false
			print("        %s does not meet %s (along %.2f across %.2f)" % [pc.kind, prev.kind, aa.x, aa.y])
	ok(chained, "the pieces chain, floor to floor")
	var steep := 0.0
	for pc in pieces:
		steep = maxf(steep, rad_to_deg(atan(absf(float(pc.y1) - float(pc.y0)) / maxf(float(pc.len), 0.01))))
	ok(steep <= 35.0, "no stair steeper than 35 degrees (%.1f)" % steep)
	var fr := Delves.frame(map, site)
	var worst := 0.0
	for pc in pieces:
		if str(pc.kind) in ["room", "heart"]:
			worst = maxf(worst, Delves._short_of_cover(map, fr, pc, 0.0, float(pc.len)))
	ok(worst <= 0.01, "the rooms lie %.1f m or more under the ground (short by %.2f)" % [Delves.COVER_M, worst])
	var heart: Dictionary = pieces[3]
	print("[delve]   the heart is %.1f m below the stairhead" % (float(lay.y_t) - float(heart.y0)))


## Every open quad near the delve is roofed (a ray from the sky meets the
## ruin's collision, not nothing).
func _roof_check(map: PlanetData, site: Dictionary, lay: Dictionary, node: Node3D, label: String) -> void:
	var fr := Delves.frame(map, site)
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var open := 0
	var bare := 0
	var keys := {}
	for r: Rect2 in lay.holes:
		for c in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), r.get_center()]:
			keys[TerrainChunk.key_at(Delves.to_dir(fr, c.x, c.y))] = true
	for key in keys:
		var data := TerrainChunk.compute(key, map, main.chunks.rivers)
		var holes: PackedByteArray = data.get("holes", PackedByteArray())
		if holes.is_empty():
			continue
		var fd: PackedVector3Array = data.fine_dirs
		var nf := TerrainChunk.FINE + 1
		var q := TerrainChunk.FINE
		for jj in q:
			for ii in q:
				if holes[jj * q + ii] == 0:
					continue
				open += 1
				# The quad's middle and four points near its corners.
				var i00 := jj * nf + ii
				var corners := [fd[i00], fd[i00 + 1], fd[i00 + nf], fd[i00 + nf + 1]]
				var mid: Vector3 = (corners[0] + corners[1] + corners[2] + corners[3]).normalized()
				var pts: Array = [mid]
				for cc in corners:
					pts.append(((cc as Vector3) * 0.85 + mid * 0.15).normalized())
				for p in pts:
					var top: Vector3 = world.to_scene(p, PlanetConst.RADIUS_M + float(fr.base_e) + 40.0)
					var bottom: Vector3 = world.to_scene(p, PlanetConst.RADIUS_M + float(fr.base_e) - 40.0)
					# (Not the trees' limbs overhead: past them.)
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, bottom))
					var guard := 0
					while not hit.is_empty() and hit.collider is Node and str((hit.collider as Node).name) == "Trunks" and guard < 8:
						guard += 1
						var rq := PhysicsRayQueryParameters3D.create(top, bottom)
						rq.exclude = [(hit.collider as CollisionObject3D).get_rid()]
						hit = space.intersect_ray(rq)
					if hit.is_empty() or not (hit.collider is Node and (node.is_ancestor_of(hit.collider as Node))):
						bare += 1
						if bare <= 4:
							var lp := Delves.to_local(fr, p)
							print("        bare at local (%.1f, %.1f): %s" % [lp.x, lp.y, "nothing" if hit.is_empty() else str(hit.collider.name)])
						break
	ok(open > 0, "%s: the ground opens over the stairhead and the cairn (%d quads)" % [label, open])
	ok(bare == 0, "%s: every open quad is roofed by stone or turf (%d bare)" % [label, bare])


## Along every piece: a floor under you, headroom over you.
func _walk_check(lay: Dictionary, node: Node3D, label: String) -> void:
	var off := float(node.get_meta("delve_off", 0.0))
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var xf := node.global_transform
	var upv := xf.basis.y.normalized()
	var bad_floor := 0
	var low := 0
	var n := 0
	var worst := ""
	for pc in lay.pieces:
		var a := 0.4
		while a < float(pc.len) - 0.3:
			var p2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * a
			var fy := Delves.floor_of(pc, a) - off
			var at: Vector3 = xf * Vector3(p2.x, fy + 1.0, p2.y)
			n += 1
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at - upv * 2.0))
			# (Something standing on the floor, the sarcophagus, is not a hole.)
			if down.is_empty() or (down.position as Vector3).distance_to(at) - 1.0 > 0.35:
				bad_floor += 1
				if worst == "":
					worst = "%s at %.1f: %s" % [pc.kind, a, "nothing" if down.is_empty() else "%.2f m" % ((down.position as Vector3).distance_to(at) - 1.0)]
			var upr := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + upv * 4.0))
			if not upr.is_empty() and (upr.position as Vector3).distance_to(at) + 1.0 < 2.0:
				low += 1
			a += 1.0
	ok(bad_floor == 0, "%s: a floor under every step of it (%d of %d missing; %s)" % [label, bad_floor, n, worst])
	ok(low == 0, "%s: 2 m of headroom all along (%d low)" % [label, low])


func _stand(node: Node3D, lay: Dictionary, pc: Dictionary, along: float) -> void:
	var off := float(node.get_meta("delve_off", 0.0))
	var p2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * along
	var at: Vector3 = node.global_transform * Vector3(p2.x, Delves.floor_of(pc, along) - off + 1.0, p2.y)
	player.velocity = Vector3.ZERO
	player.global_position = at
	for i in 10:
		await physics_frame


func _dark_check(lay: Dictionary, node: Node3D, label: String) -> void:
	# Noon.
	world.days = floor(world.days) + 0.5
	var heart: Dictionary = lay.pieces[3]
	await _stand(node, lay, heart, float(heart.len) * 0.3)
	for i in 240:
		await process_frame
	var ground: float = main.chunks.ground_height(world.dir_of(player.global_position))
	var depth: float = PlanetConst.RADIUS_M + ground - world.radius_of(player.global_position)
	ok(Delves.inside, "%s: in the heart, the player is inside the delve" % label)
	ok(depth > 4.0, "%s: and stays there, %.1f m under the ground (the safety net stands aside)" % [label, depth])
	ok(Delves.underground > 0.9, "%s: full dark underground (%.2f)" % [label, Delves.underground])
	ok(main.sky.sun.light_energy < 0.001 and main.sky.moon.light_energy < 0.001, "%s: no sun or moon reaches (sun %.3f)" % [label, main.sky.sun.light_energy])
	ok(main.dread.is_night(), "%s: the dread counts it night at noon" % label)
	ok(not player.swimming, "%s: not swimming below the sea's level" % label)


func _hearth_check(lay: Dictionary, node: Node3D, label: String) -> void:
	var room: Dictionary = lay.pieces[1]
	await _stand(node, lay, room, float(room.len) * 0.2)
	var oh: OldHearths = main.old_hearths
	oh.refresh_now()
	var off := float(node.get_meta("delve_off", 0.0))
	var hl: Vector3 = lay.hearth
	var want: Vector3 = node.global_transform * (hl - Vector3(0.0, off, 0.0))
	var fire := oh.nearest(want, 1.5)
	ok(fire != null and not FireStore.is_lit(fire), "%s: the first room's old hearth, cold" % label)
	if fire != null:
		ok(FireStore.relight(fire) == "ok" and main.dread.fire_near(14.0), "%s: rekindled, the one safe room" % label)


func _find_check(lay: Dictionary, node: Node3D, label: String, seed_v: int) -> void:
	var heart: Dictionary = lay.pieces[3]
	await _stand(node, lay, heart, float(heart.len) * 0.5)
	for i in 40:
		await process_frame
	var off := float(node.get_meta("delve_off", 0.0))
	var fl: Vector3 = lay.find
	var at: Vector3 = node.global_transform * (fl - Vector3(0.0, off, 0.0))
	var it := WorldItem.in_reach(at, 1.5)
	ok(it != null and str(it.item.get("kind", "")) == str(lay.find_kind), "%s: the %s lies by the dead" % [label, lay.find_kind])
	if it != null:
		main._take_lying(it, false)
		ok((WorldSave.data.get("delve_finds", []) as Array).has(seed_v), "%s: taken, it is kept as taken" % label)


func _door_check(lay: Dictionary, node: Node3D, label: String) -> void:
	if (lay.cairn as Dictionary).is_empty():
		print("SKIP  %s: no way out found for this one (water or broken ground)" % label)
		return
	var dv: Delves = main.delves
	var cham: Dictionary = lay.pieces[lay.pieces.size() - 1]
	await _stand(node, lay, cham, float(cham.len) - 0.9)
	for i in 40:
		await process_frame
	var door := dv.door_in_reach(player.global_position)
	ok(door != null, "%s: the cairn's slab is in reach from its chamber" % label)
	if door == null:
		return
	# From outside first.
	var outside: Vector3 = door.global_position + (door.global_basis.z).normalized() * -1.4
	var msg := dv.push(door, outside)
	ok(not bool(door.get_meta("open", false)), "%s: from outside it won't move (\"%s\")" % [label, msg])
	msg = dv.push(door, player.global_position)
	ok(bool(door.get_meta("open", false)), "%s: from inside it opens (\"%s\")" % [label, msg])
