extends SceneTree
## Phase 1 (iii) check: the gibbon brachiating through a synthetic canopy
## (GibbonCanopyFixture: eight trees with branch graphs) on the dev
## postage-stamp planet, in its tropical rainforest, spawned the way the
## dev key will spawn it (Gibbon.debug_spawn()). The fixture stands where
## the rainforest is flattest; the planet's own canopy trees inside its
## footprint are hidden so the two canopies don't tangle (they have no
## branch graphs yet).
##
## MODE=stills (default) writes, to $OUT_DIR (default /tmp/shots):
##   gibbon_day.png, gibbon_day_side.png   the body hanging, by day
##   gibbon_sit_day.png                    sitting up on a thick limb
##   gibbon_night.png                      the body hanging at night
##   gibbon_debug.png                      the gibbon's last few leaps in
##                                         late-afternoon light with the
##                                         debug lines (route ahead,
##                                         handholds weighed and caught,
##                                         flight arcs, the planned throw)
## MODE=record: a dusk traversal of the canopy with the camera following
## (also gibbon_dusk.png, a frame of it). MODE=all: the stills, then the
## traversal. Run a traversal with --write-movie; it prints the frame the
## take starts at, to trim the boot off.
##
## Run from the project folder, e.g.:
##   xvfb-run -a -s "-screen 0 960x540x24" ~/bin/godot --path . \
##     --rendering-method forward_plus --resolution 960x540 -s tools/gibbon_demo.gd
##   MODE=record xvfb-run ... --write-movie /tmp/shots/gibbon_raw.avi \
##     --fixed-fps 30 -s tools/gibbon_demo.gd

var main
var world
var cam: Camera3D
var fixture: Node3D
var place: Transform3D
var up := Vector3.UP
var spot := Vector3.UP
var gib: Gibbon
var out_dir := "/tmp/shots/"
var hour := 18.3


## Step `n` frames holding the time of day; `draw` off skips drawing the
## 3D view meanwhile (the gibbon and the sky still run), which keeps runs
## short on a busy machine.
func frames(n: int, draw := true) -> void:
	get_root().disable_3d = not draw
	for i in n:
		_hold_time()
		await process_frame


func _hold_time() -> void:
	world.days = Astro.days_at_solar_hour(world.days, hour, CubeSphere.longitude(spot))


func shot(name: String) -> void:
	get_root().disable_3d = false
	await frames(3)
	get_root().get_texture().get_image().save_png(out_dir + name + ".png")
	print("saved ", name)


func goto(d: Vector3) -> void:
	get_root().disable_3d = true
	var offset: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d) + 2.0)
	world.rebase(offset)
	main.player.global_position -= offset
	main.chunks.load_blocking(d)
	main.player.spawn_at(d)
	for k in 240:
		if k % 5 == 0:
			main.landmarks._timer = 0.0
		await process_frame
		if k > 60 and main.chunks._pending.is_empty() and main.landmarks._pending.is_empty():
			break


## Rainforest land (no water) near the first camp, the flattest of a few.
func find_spot(pd: Vector3) -> Vector3:
	var m: PlanetData = world.planet
	var rain := BiomeTemplates.id_of_key("TROPICAL_RAINFOREST")
	var best := Vector3.ZERO
	var best_range := INF
	var found := 0
	for r in range(300, 20000, 300):
		for i in 36:
			var q := CreatureSpawner._offset(pd, i * TAU / 36.0, float(r))
			var c: int = m.cell_at(q)
			if m.biome[c] != rain or m.water[c] != PlanetData.Water.NONE:
				continue
			# Flatness over the fixture's footprint (about 30 m across).
			var lo := INF
			var hi := -INF
			for k in 8:
				var p := CreatureSpawner._offset(q, k * TAU / 8.0, 18.0)
				var e: float = world.surface_elevation(p)
				lo = minf(lo, e)
				hi = maxf(hi, e)
			var e0: float = world.surface_elevation(q)
			if e0 < 2.0:
				continue
			found += 1
			if hi - lo < best_range:
				best_range = hi - lo
				best = q
		if found >= 12:
			break
	print("rainforest spot: %d candidates, flattest rises %.1f m over the footprint" % [found, best_range])
	return best


func ground_local(xz: Vector2) -> float:
	var p: Vector3 = place * Vector3(xz.x, 0.0, xz.y)
	var d: Vector3 = world.dir_of(p)
	var g: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d))
	return (place.affine_inverse() * g).y


## Hide the planet's canopy trees standing inside the fixture's footprint.
func clear_footprint() -> void:
	var inv := place.affine_inverse()
	var hidden := 0
	for c in main.chunks.chunks.values():
		var chunk := c as TerrainChunk
		for i in chunk.trees.size():
			var l: Vector3 = inv * chunk.tree_base(i)
			if l.x < -16.0 or l.x > 40.0 or l.z < -18.0 or l.z > 24.0:
				continue
			var t: Array = chunk.trees[i]
			for ch in chunk.get_children():
				if ch is MultiMeshInstance3D and ch.has_meta("species") and int(ch.get_meta("species")) == int(t[2]):
					var mm: MultiMesh = (ch as MultiMeshInstance3D).multimesh
					if int(t[3]) < mm.instance_count:
						mm.set_instance_transform(int(t[3]), Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -500, 0)))
						hidden += 1
	print("hid %d planet trees in the fixture's footprint" % hidden)


func look_at_from(from: Vector3, to: Vector3, fov := 55.0) -> void:
	cam.fov = fov
	cam.global_transform = Transform3D(Basis.looking_at((to - from).normalized(), up), from)
	cam.current = true


func _initialize() -> void:
	if OS.get_environment("OUT_DIR") != "":
		out_dir = OS.get_environment("OUT_DIR").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var mode := OS.get_environment("MODE") if OS.get_environment("MODE") != "" else "stills"
	world = get_root().get_node("World")
	world.spawn_choice = 0
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	main._weather_timer = 1e9
	main._local_weather = {"wind": Vector3(1, 0, 0.5), "rain_mm_h": 0.0, "snow": false, "temp_c": 26.0, "storm": 0.0, "clear": 1.0, "cloud": 0.25}
	main.hud.visible = false
	cam = Camera3D.new()
	cam.far = 30000
	cam.near = 0.05
	get_root().add_child(cam)
	GibbonBody.prewarm()
	spot = find_spot(main.player.surface_dir)
	if spot == Vector3.ZERO:
		push_error("no rainforest on this planet")
		quit(1)
		return
	await goto(spot)
	main.player.visible = false
	up = spot
	# The fixture: rows along X, the camera's side at -Z looking toward the
	# sunset (+Z west), trunks on the ground.
	var west := -CubeSphere.east(spot)
	var x_axis := up.cross(west).normalized()
	var ground_p: Vector3 = world.to_scene(spot, PlanetConst.RADIUS_M + main.chunks.ground_height(spot))
	place = Transform3D(Basis(x_axis, up, west), ground_p)
	fixture = GibbonCanopyFixture.build(world.world_root, 7, 8, true, place, ground_local)
	clear_footprint()
	GibbonBody.wait_ready()
	var graphs: Array = fixture.get_meta("graphs")
	var g0: BranchGraph = graphs[0]
	# Spawned the dev key's way: near the first tree's crown.
	gib = Gibbon.debug_spawn(world.world_root, g0.pos(g0.size() - 1))
	gib._rng.seed = 11
	print("gibbon on handhold %d of tree %d; mesh %s triangles" % [gib._i, graphs.find(gib._g), GibbonBody.triangles()])
	if mode != "record":
		await stills(graphs)
	if mode != "stills":
		await record(graphs)
	quit()


## A goal along the rows it can reach and get back from, whose route
## crosses from tree to tree most often (leaps, not reaches along a limb),
## ties going to the one furthest along.
func far_goal(graphs: Array) -> Array:
	var s := GibbonPlanner.search(gib._g, gib._i, gib._up, Gibbon.HANG_M, 60.0)
	var back := GibbonPlanner.search(gib._g, gib._i, gib._up, Gibbon.HANG_M, 60.0, null, -1, true)
	var inv := place.affine_inverse()
	var best := []
	var best_score := -INF
	for n in s.node_g.size():
		if not s.reached(n):
			continue
		var g: BranchGraph = s.graphs[s.node_g[n]]
		if not back.reached(back.node_of(g, s.node_i[n])):
			continue
		var path := s.path_to(n)
		var hops := 0
		for k in range(1, path.size()):
			if path[k][0] != path[k - 1][0]:
				hops += 1
		var score := hops + (inv * s.node_p[n]).x * 0.05
		if score > best_score:
			best_score = score
			best = [g, s.node_i[n]]
	return best


func stills(graphs: Array) -> void:
	get_root().disable_3d = false
	# Body stills: hanging still under its first handhold.
	gib.hang_on(gib._g, gib._i)
	gib._pause_t = 30.0
	gib._hoot_t = 1e9
	for h in [10.5, 23.2]:
		hour = h
		await frames(40, false)
		var c := gib.center_of_mass()
		var f: Vector3 = gib._fwd
		var side := f.cross(up)
		var tag := "day" if h < 18.0 else "night"
		look_at_from(c + f * 1.9 + side * 0.7 + up * 0.25, c + up * 0.12)
		await shot("gibbon_" + tag)
		if tag == "day":
			look_at_from(c + side * 2.1 + f * 0.3 + up * 0.1, c + up * 0.1)
			await shot("gibbon_day_side")
	# Sitting up on thick wood: on a handhold it can sit on, near a trunk.
	hour = 10.5
	var sit := []
	for g: BranchGraph in graphs:
		for i in g.size():
			if GibbonPlanner.sittable(g, i, up) and GibbonPlanner.hangable(g, i, up) and g.limb[i] > 0:
				sit = [g, i]
				break
		if not sit.is_empty():
			break
	if not sit.is_empty():
		gib.hang_on(sit[0], sit[1])
		gib._pause_t = 0.0
		gib._sit_next = true
		gib._end_pause()
		await frames(75, false)
		gib._sit_t = 60.0
		var c := gib.center_of_mass()
		var f: Vector3 = gib._sit_f
		var side := f.cross(up)
		# From a little below the wood: the leafy lobes sit above it.
		look_at_from(c + f * 1.6 + side * 0.8 - up * 0.3, c + up * 0.05)
		await shot("gibbon_sit_day")
	# Debug view: after a few leaps along the rows, with a throw planned,
	# framed on its last flights; late afternoon so the lines read.
	hour = 16.5
	gib.hang_on(graphs[0], _hangable_tip(graphs[0]))
	gib.debug = true
	gib._hoot_t = 1e9
	await frames(2, false)
	var goal := far_goal(graphs)
	gib.go_to(goal[0], goal[1])
	var leaps0: int = gib.stats.leaps
	var t := 0
	while t < 30 * 40 and (gib.stats.leaps - leaps0 < 3 or gib.mode != "hang" or gib._plan.is_empty() or gib._plan.contact):
		await frames(1, false)
		t += 1
	var inv := place.affine_inverse()
	var box := AABB(inv * gib.center_of_mass(), Vector3.ZERO)
	for arc in gib._dbg_arcs.slice(-3):
		for p in arc:
			box = box.expand(inv * p)
	for p in gib._dbg_pred:
		box = box.expand(inv * p)
	var mid := box.get_center()
	var reach := maxf(box.size.x, box.size.y) * 0.9 + 4.0
	look_at_from(place * Vector3(mid.x - 1.0, mid.y - reach * 0.35, mid.z - reach), place * mid, 60.0)
	await shot("gibbon_debug")
	gib.debug = false
	print("debug still: stats ", gib.stats, " box ", box)


func _hangable_tip(g: BranchGraph) -> int:
	var best := -1
	for i in g.size():
		if GibbonPlanner.hangable(g, i, up) and g.limb[i] == 1:
			best = i
	return best


## A dusk traversal, filmed from 5-10 m beside the gibbon. The camera
## keeps its spot while its line to the gibbon misses every leafy lobe
## of the fixture, else eases to the nearest spot (of a few heights and
## distances either side) that sees it clearly. When
## the gibbon reaches a goal it pauses and hoots a moment, then gets a
## new one, so the take stays on the move.
func record(graphs: Array) -> void:
	hour = 18.1
	get_root().disable_3d = false
	gib.debug = false
	gib.hang_on(graphs[0], _hangable_tip(graphs[0]))
	gib._hoot_t = 2.5
	await frames(2)
	var goal := far_goal(graphs)
	gib.go_to(goal[0], goal[1])
	var inv := place.affine_inverse()
	var lobes: Array = fixture.get_meta("lobes")
	var spots: Array[Vector2] = [] # (height, across the rows) from the gibbon
	for z: float in [-5.0, -6.5, 5.0, 6.5, -8.0, 8.0, -10.0, 10.0]:
		for dy: float in [-0.8, 0.6, -2.0, 1.8, -3.5]:
			spots.append(Vector2(dy, z))
	var spot_i := 0
	var follow := inv * gib.center_of_mass()
	var eye := Vector3.ZERO
	var secs := float(OS.get_environment("SECONDS")) if OS.get_environment("SECONDS") != "" else 14.5
	print("RECORD_START_FRAME ", Engine.get_frames_drawn())
	var n := int(secs * 30.0)
	var goals: int = gib.stats.goals
	var resting := 0
	var blocked := 0
	for k in n:
		if gib.stats.goals != goals or (gib._route.is_empty() and gib.mode == "hang"):
			resting += 1
			if resting > 36 and gib.mode == "hang":
				gib._sit_next = false
				var g2 := far_goal(graphs)
				if not g2.is_empty() and gib.go_to(g2[0], g2[1]):
					goals = gib.stats.goals
					resting = 0
		var lc := inv * gib.center_of_mass()
		follow = follow.lerp(lc, 0.08 if k > 0 else 1.0)
		var want := _spot_eye(spots[spot_i], follow)
		blocked = blocked + 1 if not _clear(want, lc, lobes) else 0
		if k == 0 or blocked > 2:
			var bd := INF
			for j in spots.size():
				var e := _spot_eye(spots[j], follow)
				if _clear(e, lc, lobes):
					var dd := e.distance_to(eye) if k > 0 else float(j)
					if dd < bd:
						bd = dd
						spot_i = j
			blocked = 0
			want = _spot_eye(spots[spot_i], follow)
		eye = want if k == 0 else eye.lerp(want, 0.2)
		look_at_from(place * eye, place * (follow + Vector3(0.4, 0.1, 0.0)), 50.0)
		await frames(1)
		if k == 150:
			get_root().get_texture().get_image().save_png(out_dir + "gibbon_dusk.png")
	print("RECORD_END_FRAME ", Engine.get_frames_drawn())
	print("recording: stats ", gib.stats)


func _spot_eye(sp: Vector2, at: Vector3) -> Vector3:
	return Vector3(at.x - 2.0, at.y + sp.x, at.z + sp.y)


## Does the line from `a` to `b` (fixture frame) miss every lobe?
func _clear(a: Vector3, b: Vector3, lobes: Array) -> bool:
	for lb in lobes:
		var c: Vector3 = lb[0]
		var r: Vector3 = (lb[1] as Vector3) * 1.1
		var p := (a - c) / r
		var q := (b - c) / r
		var d := q - p
		var t := clampf(-p.dot(d) / maxf(d.length_squared(), 1e-6), 0.0, 1.0)
		if (p + d * t).length() < 1.0:
			return false
	return true
