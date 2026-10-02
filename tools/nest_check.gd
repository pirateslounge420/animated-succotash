extends SceneTree
## The nests in play (design 1 Oct §CK, §CM), headless, full planet:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/nest_check.gd
## Boots the game on the seed, finds the nearest nest of each tier-1 kind
## to the opening camp (within 40 km, else 150, else 600 km), stands there the way
## the walkabout does, waits for Landmarks and Camps to build it, and
## asserts:
##  - the set piece is built (cave mouth, grotto, cenote lip, escarpment
##    overhang or cairns, slot canyon logs) with collision, and a cave
##    mouth's or overhang's hearth is under its roof (Landmarks.sheltered_at);
##  - a living nest has its camp (Camps, key nest:<kind>:<cell>) whose
##    people is the nest's; a nest holding remains has its signatures laid
##    (the node's Marks);
##  - the cenote's ground: its pool is standing water at the water table
##    over a floor below it, the shaft's wall stands above it, the rim's
##    hearth on the rim;
##  - the slot canyon: 8 m deep or more and its floor a few metres wide;
##  - a grotto's, waterfall's or slot's own plants grow at their spot
##    (§CM; when the climate lets any of them);
##  - F3's overlay names the nest.
## A kind with no nest within 600 km is SKIP, not FAIL. NEST_KINDS=grotto,
## bioluminescent_bay narrows the kinds.

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
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	player.set_physics_process(false)
	var camp: Vector3 = main.camp.site
	print("[nest] seed %d · camp %s" % [seed_v, str(camp)])
	var only := OS.get_environment("NEST_KINDS").split(",", false)
	for kind in Nests.KINDS:
		if not only.is_empty() and not only.has(kind):
			continue
		var n := _nearest(kind, camp)
		if n.is_empty():
			print("SKIP  %s: none within 600 km of the camp" % kind)
			continue
		await _check(n, camp)
	# A living camp at a nest, whatever its kind: the nearest.
	var lived := {}
	var ld := INF
	for n in Nests.near(camp, 150000.0, ["cave_mouth", "escarpment", "cenote", "waterfall", "ravine"]):
		if str(n.state) == "lived" and CubeSphere.surface_distance_m(n.dir, camp) < ld:
			ld = CubeSphere.surface_distance_m(n.dir, camp)
			lived = n
	if lived.is_empty():
		print("SKIP  no living camp at a nest within 150 km")
	else:
		await _check(lived, camp)
	await _fig_check()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _nearest(kind: String, camp: Vector3) -> Dictionary:
	for r in [40000.0, 150000.0, 600000.0]:
		var best := {}
		var bd := INF
		for n in Nests.near(camp, r, [kind]):
			var dd := CubeSphere.surface_distance_m(n.dir, camp)
			if dd < bd:
				bd = dd
				best = n
		if not best.is_empty():
			return best
	return {}


func _go(d: Vector3, look: Vector3) -> void:
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	player.global_position -= off
	main.chunks.load_blocking(d)
	player.spawn_at(d, look)
	for i in 20:
		await process_frame


func _check(n: Dictionary, camp: Vector3) -> void:
	var label := "%s%s %s (%.1f km from the camp, %s%s)" % [n.kind, ("/" + str(n.variant)) if str(n.variant) != "" else "", str(n.cell), CubeSphere.surface_distance_m(n.dir, camp) / 1000.0, n.state, (", " + str(n.people)) if n.has("people") else ""]
	var stand: Vector3 = n.hearth if (n.hearth as Vector3) != Vector3.ZERO else n.dir
	await _go(stand, n.dir)
	var lm: Landmarks = main.landmarks
	var t0 := Time.get_ticks_msec()
	while not lm.built_nests().has(n.key) and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var node: Node3D = lm.built_nests().get(n.key, null)
	var meshy := str(n.kind) in ["cave_mouth", "grotto", "escarpment", "slot_canyon"] or (str(n.kind) == "cenote" and str(n.variant) == "")
	if meshy:
		var verts := 0
		if node != null:
			for c in node.get_children():
				if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and c.name != "FarLOD":
					verts += (c as MeshInstance3D).mesh.get_faces().size()
		ok(node != null and verts > 0, "%s: its set piece is built (%d triangles)" % [label, verts / 3])
		if node != null:
			for i in 400:
				if not RuinBuilder.wants_collision(node):
					break
				await process_frame
			var shapes := node.get_node("Collision").get_child_count() if node.has_node("Collision") else 0
			if str(n.kind) != "slot_canyon":
				ok(shapes > 0, "%s: it collides (%d shapes)" % [label, shapes])
	if str(n.kind) in ["cave_mouth", "escarpment"] and n.has("overhang_m"):
		var hp: Vector3 = world.to_scene(n.hearth, PlanetConst.RADIUS_M + main.chunks.ground_height(n.hearth) + 1.0)
		ok(lm.sheltered_at(hp), "%s: the hearth is under the roof, a pace or two in from the drip line" % label)
	if str(n.state) == "lived":
		main.camps.refresh_now()
		for i in 30:
			await process_frame
		var cnode: Node3D = main.camps._camps.get(n.key, null)
		ok(cnode != null and str(cnode.get_meta("people", "")) == str(n.people), "%s: its camp is there, the %s (%s)" % [label, n.people, str(cnode.get_meta("people", "")) if cnode != null else "no camp"])
	elif str(n.state) == "remains":
		var marks := node != null and node.has_node("Marks") and node.get_node("Marks").get_child_count() > 0
		ok(marks, "%s: an old camp's remains at the hearth (%s)" % [label, ", ".join(Nests.remains_signatures(n).map(func(s): return str(s.get("id", ""))))])
	var chunks: ChunkManager = main.chunks
	if str(n.kind) == "cenote" and str(n.variant) == "":
		var c: Vector3 = n.dir
		var floor_h := chunks.ground_height(c)
		var water := chunks.water_level_at(c)
		var wall := chunks.ground_height(CreatureSpawner._offset(c, float(n.ramp) + PI, float(n.radius_m) + 3.0))
		ok(absf(water - float(n.pool_m)) < 0.3 and floor_h < float(n.pool_m) - 1.5, "%s: its pool is standing water at %.1f m over a floor at %.1f m (water read %.1f)" % [label, float(n.pool_m), floor_h, water])
		ok(wall - water > 4.0, "%s: the shaft's wall stands %.1f m over the pool (radius %.0f m, depth %.0f m)" % [label, wall - water, float(n.radius_m), float(n.depth_m)])
		ok(absf(chunks.ground_height(n.hearth) - float(n.rim_m)) < 2.5, "%s: the hearth is on the rim (%.1f m vs rim %.1f m)" % [label, chunks.ground_height(n.hearth), float(n.rim_m)])
	if str(n.kind) == "slot_canyon":
		var d: Vector3 = n.dir
		var across := float(n.facing)
		var floor_e := chunks.ground_height(d)
		var rim := maxf(chunks.ground_height(CreatureSpawner._offset(d, across, 12.0)), chunks.ground_height(CreatureSpawner._offset(d, across + PI, 12.0)))
		var width := 0.0
		for k in range(-24, 25):
			var p := CreatureSpawner._offset(d, across, k * 0.5)
			if chunks.ground_height(p) < floor_e + 1.5:
				width += 0.5
		ok(rim - floor_e >= 8.0 and width <= 9.0, "%s: a slot %.1f m deep, its floor %.1f m wide" % [label, rim - floor_e, width])
	var spots := Nests.plant_spots(n)
	if not spots.is_empty():
		await _go(spots[0][0], n.dir)
		var ck: Vector3i = TerrainChunk.key_at(spots[0][0])
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 90000:
			var ch: TerrainChunk = chunks.chunks.get(ck, null)
			if ch != null and ch.detail_node != null:
				break
			await process_frame
		var want := {}
		for b in (Nests.entry(str(n.kind)).get("plants", {}) as Dictionary).get("add", []):
			var sp := Nests.species_of(str(b))
			if sp != null:
				want[SpeciesDB.index_of(sp)] = sp.binomial()
		var found := _placed_at(chunks, spots, want)
		var fits := _fits(n, spots, want)
		if fits:
			ok(found > 0, "%s: its own plants grow at its spot (%d: %s)" % [label, found, ", ".join(want.values())])
		else:
			print("SKIP  %s: none of %s fits this climate (their own bands)" % [label, ", ".join(want.values())])
	var f3 := Nests.overlay_text(n.dir)
	ok(f3.contains(Nests.name_of(n).to_lower()), "%s: F3 names it (%s)" % [label, f3.strip_edges()])


## Nest plants the placer grows round `spots` (VegetationPlacer.compute_
## detail on the loaded chunks' own data, as ChunkManager runs it).
func _placed_at(chunks: ChunkManager, spots: Array, want: Dictionary) -> int:
	var n := 0
	var done := {}
	for s in spots:
		var ck: Vector3i = TerrainChunk.key_at(s[0])
		if done.has(ck):
			continue
		done[ck] = true
		var ch: TerrainChunk = chunks.chunks.get(ck, null)
		if ch == null:
			continue
		var det := VegetationPlacer.compute_detail(ck, world.planet, ch.data, ch.hosts)
		for idx in want:
			var arr: PackedFloat32Array = det.get(idx, PackedFloat32Array())
			for o in range(0, arr.size(), VegetationPlacer.STRIDE):
				var d := Vector3(arr[o], arr[o + 1], arr[o + 2])
				for sp in spots:
					if CubeSphere.surface_distance_m(d, sp[0]) < float(sp[1]) + 1.0:
						n += 1
						break
	return n


## Nest plant instances in the chunks round `spots`.
func _count_at(chunks: ChunkManager, spots: Array, want: Dictionary) -> int:
	var n := 0
	for key in chunks.chunks:
		var ch: TerrainChunk = chunks.chunks[key]
		if ch.detail_node == null:
			continue
		for mmi in ch.detail_node.get_children():
			if not mmi is MultiMeshInstance3D or not mmi.has_meta("species"):
				continue
			if not want.has(int(mmi.get_meta("species"))):
				continue
			var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				var p: Vector3 = (mmi as MultiMeshInstance3D).global_transform * mm.get_instance_transform(i).origin
				for s in spots:
					var sp_pos: Vector3 = world.to_scene(s[0], PlanetConst.RADIUS_M + chunks.ground_height(s[0]))
					if p.distance_to(sp_pos) < float(s[1]) + 2.0:
						n += 1
						break
	return n


## Does any of the nest's plants fit its spot's temperature and soil?
func _fits(n: Dictionary, spots: Array, want: Dictionary) -> bool:
	var map: PlanetData = world.planet
	for s in spots:
		var d: Vector3 = s[0]
		var t: float = map.sample(map.temp_c, d) + (map.sample(map.elevation, d) - main.chunks.ground_height(d)) * PlanetConst.LAPSE_RATE_C_PER_M
		for idx in want:
			var sp: PlantSpecies = SpeciesDB.all()[idx]
			if sp.suitability(t, float(s[3]), main.chunks.ground_height(d), map.soil_at(d)) > 0.0:
				return true
	return false


## The sacred fig (design 1 Oct §CL): one per world; its tree past the
## band, the figure seated beneath it facing east, the log's one line.
func _fig_check() -> void:
	var f := Uniques.sacred_fig(world.planet)
	if f.is_empty():
		print("SKIP  the sacred fig: none of its biomes on this world")
		return
	print("[nest] the sacred fig in %s, %.0f km from the camp" % [f.biome, CubeSphere.surface_distance_m(f.dir, main.camp.site) / 1000.0])
	await _go(f.figure, CreatureSpawner._offset(f.figure, PI * 0.5, 20.0))
	for i in 60:
		await process_frame
	var ck: Vector3i = TerrainChunk.key_at(f.dir)
	var ch: TerrainChunk = main.chunks.chunks.get(ck, null)
	var tall := 0.0
	var fig_sp := Uniques.fig_tree(world.planet, ck)
	if ch != null and not fig_sp.is_empty():
		for i in ch.trees.size():
			var t: Array = ch.trees[i]
			if int(t[2]) == int(fig_sp[0]) and CubeSphere.surface_distance_m(world.dir_of(ch.tree_base(i)), f.dir) < 3.0:
				tall = maxf(tall, float(t[1]))
	var sp: PlantSpecies = SpeciesDB.all()[int(fig_sp[0])] if not fig_sp.is_empty() else null
	ok(sp != null and tall > sp.height_m.y, "the sacred fig stands there, %.0f m tall, past its species' band (to %.0f m; %s)" % [tall, sp.height_m.y if sp else 0.0, sp.binomial() if sp else "no species"])
	var node: Node3D = main.landmarks.fig_node()
	var body: PlayerBody = node.get_node("Seated/Figure") if node != null and node.has_node("Seated/Figure") else null
	ok(body != null and body.pose == "meditate", "the figure sits beneath it in meditation")
	var logged := false
	for e in GameLog.entries:
		if str(e.get("text", "")).begins_with("Someone sits beneath the old fig"):
			logged = true
	ok(logged, "the log's one line, no name")
