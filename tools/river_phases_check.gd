extends SceneTree
## Reading the river (design 4 Oct §ED.2, data/water/phases.json):
##   STAMP=1 SEED=42 godot --headless --path . --fixed-fps 60 --script tools/river_phases_check.gd
## Asserts: the seven phases load in order; the rivers within 15 km are
## classified sample by sample, every waterfall sample a fall, and more
## than one phase shows; a chunk's river water carries its phase (vertex
## colour); fish hold only in a pool or a glide; a spear thrown into a run
## or stronger is carried off and lost (its slot empties), and one landing
## in a pool floats where it fell; the river sounds louder the stronger
## the phase.

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
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 42
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	var names := []
	for i in RiverPhases.count():
		names.append(RiverPhases.name_of(i))
	ok(names == ["pool", "glide", "riffle", "run", "rapid", "cascade", "fall"], "the seven phases, calm to fall: %s" % ", ".join(names))
	ok(RiverPhases.of_slope(0.001) == 0 and RiverPhases.of_slope(0.01) == 2 and RiverPhases.of_slope(0.05) == 4, "slopes classify by slope_max")
	var rivers: RiverNetwork = main.chunks.rivers
	var map: PlanetData = world.planet
	var pd: Vector3 = player.surface_dir
	var counts := PackedInt32Array()
	counts.resize(RiverPhases.count())
	var falls_ok := 0
	var falls_n := 0
	var segs := 0
	var where := {}
	for s in rivers.a.size():
		if CubeSphere.surface_distance_m(rivers.a[s], pd) > 15000.0:
			continue
		segs += 1
		var ph := RiverPhases.of_segment(rivers, s)
		var prof := rivers.profile(s)
		for i in ph.size():
			counts[ph[i]] += 1
			if not where.has(ph[i]):
				where[ph[i]] = [s, float(i) / maxf(ph.size() - 1, 1)]
			if i > 0 and prof[i - 1] - prof[i] >= RiverNetwork.FALL_MIN_M:
				falls_n += 1
				if ph[i] == RiverPhases.count() - 1:
					falls_ok += 1
	var line := []
	for i in counts.size():
		line.append("%s %d" % [names[i], counts[i]])
	print("[phases] %d segments within 15 km: %s" % [segs, ", ".join(line)])
	var shown := 0
	for c in counts:
		if c > 0:
			shown += 1
	ok(segs > 0 and shown >= 2, "the rivers read in more than one phase (%d)" % shown)
	ok(falls_n == falls_ok, "every waterfall sample is a fall (%d/%d)" % [falls_ok, falls_n])
	# The water carries its phase.
	var coloured := false
	for key in main.chunks.chunks:
		var c: TerrainChunk = main.chunks.chunks[key]
		var fw := c.get_node_or_null("FreshWater") as MeshInstance3D
		if fw != null and fw.mesh != null:
			var arr := (fw.mesh as ArrayMesh).surface_get_arrays(0)
			if arr[Mesh.ARRAY_COLOR] != null and (arr[Mesh.ARRAY_COLOR] as PackedColorArray).size() > 0:
				coloured = true
				break
	ok(coloured, "a chunk's river water carries its phase (vertex colour)")
	# Fish and spears by phase.
	var fish_ok := true
	var spear_ok := true
	for i in RiverPhases.count():
		var r := RiverPhases.row(i)
		fish_ok = fish_ok and bool(r.fish) == (i <= 1)
		spear_ok = spear_ok and (str(r.spear) == "lost") == (i >= 3)
	ok(fish_ok, "fish hold only in a pool or a glide")
	ok(spear_ok, "a spear is lost in a run or anything stronger")
	ok(RiverPhases.loudness(4) > RiverPhases.loudness(2) and RiverPhases.loudness(2) > RiverPhases.loudness(0), "louder the stronger the phase (pool %.2f, riffle %.2f, rapid %.2f)" % [RiverPhases.loudness(0), RiverPhases.loudness(2), RiverPhases.loudness(4)])
	# A spear thrown into a run is carried off; into a pool it floats.
	var strong := -1
	for i in range(3, RiverPhases.count()):
		if where.has(i):
			strong = i
			break
	if strong >= 0:
		player.inventory.wear(Inventory.make("spear"))
		var s: int = where[strong][0]
		var t: float = where[strong][1]
		var d := rivers.a[s].slerp(rivers.b[s], t)
		var lvl := rivers.level_at(s, t)
		var ts := ThrownSpear.new()
		ts.world = world
		ts.chunks = main.chunks
		ts.from_spear = player.spear
		world.world_root.add_child(ts)
		ts.launch(world.to_scene(d, PlanetConst.RADIUS_M + lvl + 2.0), Vector3.ZERO)
		player.spear.thrown = ts
		ts._float(d, lvl)
		for k in 300:
			await physics_frame
		ok(not is_instance_valid(ts) or ts.lost, "a spear landing in a %s is carried off" % RiverPhases.name_of(strong))
		ok(not player.wears("melee", "spear"), "and it is lost: the spear slot is empty")
	else:
		print("[phases] no run or stronger water within 15 km to throw into")
	if where.has(0) or where.has(1):
		var calm: int = 0 if where.has(0) else 1
		var s2: int = where[calm][0]
		var t2: float = where[calm][1]
		var d2 := rivers.a[s2].slerp(rivers.b[s2], t2)
		var ts2 := ThrownSpear.new()
		ts2.world = world
		ts2.chunks = main.chunks
		world.world_root.add_child(ts2)
		ts2.launch(world.to_scene(d2, PlanetConst.RADIUS_M + rivers.level_at(s2, t2) + 2.0), Vector3.ZERO)
		ts2._float(d2, rivers.level_at(s2, t2))
		ok(ts2.afloat and ts2.landed and not ts2.lost, "a spear landing in a %s floats where it fell" % RiverPhases.name_of(calm))
		ok(RiverPhases.fish_hold(rivers, map, d2), "and fish hold there")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
