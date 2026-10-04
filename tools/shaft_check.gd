extends SceneTree
## Shafts of sunlight (design 3 Oct §DC, look.json shafts, ShaftField),
## headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/shaft_check.gd
##  - a jungle spot at 07:00, relative humidity 0.95, cover 0.2: between 1
##    and 6 shafts (spots tried until one stands under broken crowns);
##  - the same spot at 13:00, rh 0.5, no fog, no mist, no hearth: none;
##  - cover 0.9: none;
##  - a ruin's hall by day: at least one sunbeam, with motes (a stone hall
##    built round you with a gap in its vault, as RuinBuilder's broken
##    vaults are; the hall gate itself is SkySystem's enclosure in a built
##    ruin's footprint);
##  - the colour is cool (blue above red), no shaft is past alpha_max, and
##    none can push a pixel past the bloom threshold (an unshaded, alpha-
##    blended colour no channel of which is past it).

var fails := 0
var main: Node
var world: Node


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
	for i in 10:
		await process_frame
	var field: ShaftField = main.shafts
	var S := ShaftField.S
	var still := {"cloud_here": 0.0, "fog": 0.0, "smoke": 0.0, "hall": false, "dust": 0.0, "under": false}

	# --- A jungle spot at 07:00, damp, a part-clear sky. ---
	var spots := _jungle_cells(8)
	ok(not spots.is_empty(), "jungle cells on this planet (%d tried)" % spots.size())
	var found := -1
	var spot := Vector3.ZERO
	for d in spots:
		await _stand_at(d)
		await _hour(d, 7.0)
		field.override = still.duplicate()
		field.override.merge({"rh": 0.95, "cover": 0.2}, true)
		field.refresh(field.gather())
		print("   spot %.2f°, %.2f°: sun %.1f°, %s, %d shafts" % [rad_to_deg(CubeSphere.latitude(d)), rad_to_deg(CubeSphere.longitude(d)), float(field.gate_state.get("sun_elev", 0.0)), str(field.gate_state.get("why", "")) if not bool(field.gate_state.ok) else "air %.2f" % float(field.gate_state.air), field.shafts.size()])
		if field.shafts.size() > 0:
			found = field.shafts.size()
			spot = d
			break
	ok(found >= 1 and found <= int(S.get("max_per_view", 6)), "a jungle spot at 07:00, rh 0.95, cover 0.2: %d shafts (1 to %d)" % [found, int(S.get("max_per_view", 6))])
	if found >= 1:
		var kinds := {}
		for s in field.shafts:
			kinds[s.kind] = true
		print("   kinds: %s; air %.2f; low sun scale %.2f" % [str(kinds.keys()), float(field.gate_state.air), ShaftField.low_sun(float(field.gate_state.sun_elev))])
		# Drawn: a few frames for the alphas.
		for i in 3:
			await process_frame
		var a_max := 0.0
		for s in field.shafts:
			a_max = maxf(a_max, float(s.get("alpha", 0.0)))
		ok(a_max > 0.0 and a_max <= float(S.get("alpha_max", 0.22)) + 1e-6, "drawn, the strongest at alpha %.3f (at most alpha_max %.2f)" % [a_max, float(S.get("alpha_max", 0.22))])
		# The same spot at 13:00, dry, no fog, no mist, no hearth.
		await _hour(spot, 13.0)
		field.override = still.duplicate()
		field.override.merge({"rh": 0.5, "cover": 0.2, "mist": float(Tuning.section("look", "mist").get("day_density", 0.0006))}, true)
		field.refresh(field.gather())
		ok(field.shafts.is_empty(), "the same spot at 13:00, rh 0.5, no fog, mist or hearth: %d shafts (%s)" % [field.shafts.size(), field.gate_state.why])
		# Overcast.
		await _hour(spot, 7.0)
		field.override = still.duplicate()
		field.override.merge({"rh": 0.95, "cover": 0.9}, true)
		field.refresh(field.gather())
		ok(field.shafts.is_empty(), "cover 0.9: %d shafts (%s)" % [field.shafts.size(), field.gate_state.why])

	# --- A ruin's hall by day. ---
	var d0: Vector3 = main.player.surface_dir
	await _hour(d0, 9.5)
	var hall := _build_hall()
	await physics_frame
	await physics_frame
	field.override = still.duplicate()
	field.override.merge({"rh": 0.5, "cover": 0.1, "hall": true, "dust": 1.0, "mist": 0.0}, true)
	field.refresh(field.gather())
	var with_motes := 0
	for s in field.shafts:
		if s.kind == "ruin" and s.motes != null:
			with_motes += 1
	ok(with_motes >= 1, "a ruin's hall by day: %d sunbeams with motes (sun %.1f°, %s)" % [with_motes, float(field.gate_state.get("sun_elev", 0.0)), field.gate_state.get("why", "")])
	hall.queue_free()

	# --- The colour. ---
	var c := ShaftField.color()
	var thr := float((Tuning.section("look", "retro").get("bloom", {}) as Dictionary).get("hdr_threshold", 1.0))
	ok(c.b > c.r, "the shaft colour is cool, blue above red (%s)" % c.to_html(false))
	ok(maxf(c.r, maxf(c.g, c.b)) <= thr and field._mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and field._mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and field._mat.emission_enabled == false,
		"no channel past the bloom threshold %.2f (brightest %.3f), unshaded, alpha-blended, no emission: lit air never blooms" % [thr, maxf(c.r, maxf(c.g, c.b))])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Up to `n` land cells of the tropical rainforest, nearest the camp first.
func _jungle_cells(n: int) -> Array:
	var map: PlanetData = world.planet
	var bid := BiomeTemplates.id_of_key("TROPICAL_RAINFOREST")
	var camp: Vector3 = main.camp.site
	var all: Array = []
	for c in map.cell_count:
		if map.water[c] == PlanetData.Water.NONE and map.biome[c] == bid:
			all.append(map.dir[c])
	all.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.dot(camp) > b.dot(camp))
	return all.slice(0, n)


func _stand_at(d: Vector3) -> void:
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	main.player.global_position -= off
	main.chunks.load_blocking(d)
	main.player.spawn_at(d, CreatureSpawner._offset(d, 0.0, 10.0))
	for i in 20:
		await process_frame


## The local solar hour `h` at `d`, and the sky caught up.
func _hour(d: Vector3, h: float) -> void:
	world.days = Astro.days_at_solar_hour(world.days, h, CubeSphere.longitude(d), CubeSphere.latitude(d))
	for i in 4:
		await process_frame


## A stone hall round the player: a floor, four walls 4 m high, and a vault
## of slabs with one missing on the sun's side, so the sun reaches the
## floor through the gap.
func _build_hall() -> Node3D:
	var player: Node3D = main.player
	var up: Vector3 = player.global_basis.y.normalized()
	var sun: Vector3 = main.sky.sun_dir
	var flat := (sun - up * sun.dot(up)).normalized()
	var side := flat.cross(up).normalized()
	var root := Node3D.new()
	main.world.world_root.add_child(root)
	root.global_transform = Transform3D(Basis(side, up, -flat), player.global_position - up * 0.9)
	var add := func(center: Vector3, size: Vector3) -> void:
		var b := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		b.add_child(cs)
		root.add_child(b)
		b.position = center
	add.call(Vector3(0, -0.25, 0), Vector3(16, 0.5, 16))
	add.call(Vector3(8.25, 2.0, 0), Vector3(0.5, 4.5, 16))
	add.call(Vector3(-8.25, 2.0, 0), Vector3(0.5, 4.5, 16))
	add.call(Vector3(0, 2.0, 8.25), Vector3(16, 4.5, 0.5))
	add.call(Vector3(0, 2.0, -8.25), Vector3(16, 4.5, 0.5))
	# The vault, in 2 m strips across; the one over the sun's side gone.
	for k in 8:
		var z := -7.0 + k * 2.0
		if k == 1:
			continue
		add.call(Vector3(0, 4.5, z), Vector3(16.5, 0.4, 2.0))
	return root
