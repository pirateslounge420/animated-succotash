extends SceneTree
## Pictures of the aroids' lives (AroidGarden, docs/design/AROID_LIFE.md):
## finds Amorphophallus near a tropical spot on the dev planet, then frames
## one plant at points of its life by day: a shoot spike, the leaf, a bloom,
## the berries; and, as a demonstration, three plants given colour sports
## (variegated, golden, dark) side by side.
##
##   STAMP=1 xvfb-run -a -s "-screen 0 1280x720x24" ~/bin/godot --path . \
##     --rendering-method forward_plus --resolution 1280x720 -s tools/aroid_view.gd
##
## OUT_DIR (default /tmp/shots). Writes aroid_<what>.png (the internal
## frame) and prints what each shows.
## SPECIES="Amorphophallus titanum": that species instead of the commonest
## (TRIES spots looked at, default 25); its bloom also gets a wide shot
## from standing height (aroid_wild.png) and a close one of the
## inflorescence (aroid_inflorescence.png).

var out_dir := "/tmp/shots"
var main
var world


func _initialize() -> void:
	if OS.get_environment("OUT_DIR") != "":
		out_dir = OS.get_environment("OUT_DIR")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func goto(d: Vector3) -> void:
	var offset: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d) + 2.0)
	world.rebase(offset)
	main.player.global_position -= offset
	main.chunks.load_blocking(d)
	main.player.spawn_at(d)
	for k in 500:
		await process_frame
		if k > 90 and main.chunks._pending.is_empty():
			break


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = get_root().get_node("World")
	world.spawn_choice = 0
	seed(42)
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var clear := {"wind": Vector3(1, 0, 0.5).normalized() * 0.8, "rain_mm_h": 0.0, "snow": false, "temp_c": 26.0, "storm": 0.0, "clear": 1.0, "cloud": 0.1}
	main._weather_timer = 1e9
	main._local_weather = clear
	main._weather_eased = clear.duplicate()
	main.hud.visible = false
	var garden: AroidGarden = main.aroid_garden
	var map: PlanetData = world.planet
	var want := [BiomeTemplates.TROPICAL_RAINFOREST, BiomeTemplates.JUNGLE, BiomeTemplates.TROPICAL_DRY_FOREST, BiomeTemplates.SAVANNA]
	var cands: Array = []
	for c in map.biome.size():
		if map.biome[c] in want:
			cands.append(c)
	seed(7)
	cands.shuffle()
	# A species asked for: only spots in a province whose realms it's
	# native to (RealmMap: one world in nine for most), rainforest or not.
	var want_name := OS.get_environment("SPECIES")
	if want_name != "":
		var wsp := SpeciesDB.find(want_name)
		if wsp != null and not wsp.realms.is_empty():
			const WORLD_OF := {"andes": 0, "neotropic": 0, "nearctic": 0, "madagascar": 1, "afrotropic": 1,
				"mediterranean": 1, "palearctic": 1, "west_asia": 1, "himalaya": 2, "indomalaya": 2,
				"sino_subtropical": 2, "central_asia": 2, "east_asia_temperate": 2, "malesia": 3,
				"australasia": 3, "oceania": 4}
			var worlds := {}
			for r in wsp.realms:
				if WORLD_OF.has(r):
					worlds[WORLD_OF[r]] = true
			RealmMap.warm(world.world_seed)
			cands = cands.filter(func(c): return worlds.has(RealmMap.world_at(map.dir[c])))
			print("[aroid_view] %s: realms %s, %d spots in its provinces" % [want_name, wsp.realms, cands.size()])
	var entry := {}
	var want_sp := OS.get_environment("SPECIES")
	var tries_n := int(OS.get_environment("TRIES")) if OS.get_environment("TRIES") != "" else 25
	# AT="x,y,z": straight to that spot (a direction FIND=1 printed).
	if OS.get_environment("AT") != "":
		cands = [-1]
		tries_n = 1
	for tries in mini(cands.size(), tries_n):
		var here: Vector3 = map.dir[cands[tries]] if cands[tries] >= 0 else Vector3(float(OS.get_environment("AT").split(",")[0]), float(OS.get_environment("AT").split(",")[1]), float(OS.get_environment("AT").split(",")[2])).normalized()
		await goto(here)
		garden._scan()
		# The species with the most plants here that bloom (or the one asked).
		var best_n := 0
		for id in garden._entries:
			var e: Dictionary = garden._entries[id]
			if want_sp != "" and e.sp.name != want_sp:
				continue
			if int(e.n) > best_n and e.sp.height_m.y >= 0.6:
				best_n = int(e.n)
				entry = e
		if not entry.is_empty():
			# FIND=1 (run headless: seconds a spot, not minutes): print
			# where, and stop; AT= that, drawn, takes the pictures.
			if OS.get_environment("FIND") == "1":
				print("[aroid_view] found %s: %d plants at AT=%.6f,%.6f,%.6f (spot %d)" % [entry.sp.name, int(entry.n), here.x, here.y, here.z, tries])
				quit()
				return
			break
		elif OS.get_environment("FIND") == "1":
			print("[aroid_view] spot %d: none" % tries)
	if entry.is_empty():
		print("[aroid_view] no aroids found")
		quit()
		return
	var player: PlanetPlayer = main.player
	player.set_physics_process(false)
	player.visible = false
	var sp: PlantSpecies = entry.sp
	print("[aroid_view] %s (%d plants here)" % [sp.name, int(entry.n)])
	var start: float = world.days
	# One plant that blooms within ten years, and its days.
	var pi := -1
	var o_day := 0.0
	var st_b := {}
	for i in int(entry.n):
		for dd in range(0, 3650, 1):
			var st := AroidLife.state(sp, entry.keys[i], entry.lat[i], entry.lon[i], start + dd)
			if st.flower == "bloom":
				pi = i
				o_day = float(st.open_day)
				st_b = st
				break
		if pi >= 0:
			break
	if pi < 0:
		print("[aroid_view] nothing blooms in ten years")
		quit()
		return
	var key: int = entry.keys[pi]
	var lat: float = entry.lat[pi]
	var lon: float = entry.lon[pi]
	# Its days: the bud, the bloom's first full day, the berries, the shoot
	# and the leaf, each at local midday.
	var shots := {}
	var fr_days: float = float(sp.cycle.fruit.ripen_days[0])
	shots["bloom"] = _noon(o_day + 1.0, lon)
	shots["bud"] = _noon(o_day - float(sp.cycle.bud.bud_days[0]) * 0.5, lon)
	shots["fruit"] = _noon(o_day + float(sp.cycle.bloom.open_days[1]) + fr_days * 0.9, lon)
	for dd in range(0, 3650, 1):
		var st := AroidLife.state(sp, key, lat, lon, start + dd)
		if st.leaf == "shoot" and float(st.leaf_t) > 0.6 and not shots.has("shoot"):
			shots["shoot"] = _noon(start + dd, lon)
		if st.leaf == "leaf" and st.flower == "" and not shots.has("leaf"):
			shots["leaf"] = _noon(start + dd, lon)
		if shots.has("shoot") and shots.has("leaf"):
			break
	# A real cross for the fruit shot (so it fruits for sure).
	garden._donors[key] = {int(st_b.event): true}
	var xf: Transform3D = entry.mmi.global_transform
	var base: PackedFloat32Array = entry.base
	var p: Vector3 = xf * Vector3(base[pi * 20 + 3], base[pi * 20 + 7], base[pi * 20 + 11])
	var up: Vector3 = world.dir_of(p)
	var h := Vector3(base[pi * 20 + 1], base[pi * 20 + 5], base[pi * 20 + 9]).length()
	var side := CubeSphere.north(up)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.05
	cam.far = 20000.0
	get_root().add_child(cam)
	for what in ["shoot", "leaf", "bud", "bloom", "fruit"]:
		if not shots.has(what):
			continue
		world.days = shots[what]
		garden.update_now()
		await _frames(20)
		var st: Dictionary = entry.states[pi]
		var look_h := h * (0.45 if what != "bloom" and what != "fruit" else 0.55)
		var dist := clampf(h * 2.2, 1.6, 9.0)
		var eye := p + up * (look_h + h * 0.25) + side.rotated(up, 0.6) * dist
		cam.global_transform = Transform3D(Basis.looking_at((p + up * look_h - eye).normalized(), up), eye)
		cam.current = true
		await _frames(12)
		var path := "%s/aroid_%s.png" % [out_dir, what]
		get_root().get_texture().get_image().save_png(path)
		print("[aroid_view] %s: leaf %s, flower %s (%s) -> %s" % [what, st.leaf, st.flower, AroidGarden.describe(entry.mmi.get_instance_id(), pi), path])
		if what == "bloom" and want_sp != "":
			# In the wild: from standing height, well back, the forest round it.
			var bh := clampf(h * 0.5, 1.0, 3.0)
			var wild := p + up * 1.6 + side.rotated(up, 1.2) * clampf(h * 3.5, 6.0, 16.0)
			cam.fov = 70.0
			cam.global_transform = Transform3D(Basis.looking_at((p + up * bh - wild).normalized(), up), wild)
			await _frames(12)
			get_root().get_texture().get_image().save_png("%s/aroid_wild.png" % out_dir)
			# The inflorescence itself, close: spathe and appendix.
			var near := p + up * (bh * 1.1) + side.rotated(up, 0.3) * clampf(h * 0.8, 1.2, 3.5)
			cam.fov = 50.0
			cam.global_transform = Transform3D(Basis.looking_at((p + up * bh * 0.8 - near).normalized(), up), near)
			await _frames(12)
			get_root().get_texture().get_image().save_png("%s/aroid_inflorescence.png" % out_dir)
			cam.fov = 55.0
			print("[aroid_view] wild and inflorescence shots -> %s/aroid_wild.png, aroid_inflorescence.png" % out_dir)
	# The sports, as a demonstration: three plants in leaf given colour
	# sports (variegated, golden, dark) in their instance data.
	world.days = shots.get("leaf", start)
	garden.update_now()
	var demo := []
	for i in int(entry.n):
		if str(entry.states[i].leaf) == "leaf":
			demo.append(i)
		if demo.size() == 3:
			break
	var codes := [PlantGenetics.code_of("variegated"), PlantGenetics.code_of("aurea"), PlantGenetics.code_of("melanic")]
	for k in demo.size():
		var j: int = int(demo[k]) * 20
		entry.base[j + 16] = PlantGenetics.encode_moss(entry.base[j + 16] - 2.0 * PlantGenetics.decode_sport(entry.base[j + 16]), codes[k])
	garden.update_now()
	await _frames(10)
	for k in demo.size():
		var q: Vector3 = xf * Vector3(base[int(demo[k]) * 20 + 3], base[int(demo[k]) * 20 + 7], base[int(demo[k]) * 20 + 11])
		var qh := Vector3(base[int(demo[k]) * 20 + 1], base[int(demo[k]) * 20 + 5], base[int(demo[k]) * 20 + 9]).length()
		var qu: Vector3 = world.dir_of(q)
		var eye2 := q + qu * (qh * 1.3) + CubeSphere.north(qu).rotated(qu, 0.6) * clampf(qh * 1.8, 1.4, 7.0)
		cam.global_transform = Transform3D(Basis.looking_at((q + qu * qh * 0.55 - eye2).normalized(), qu), eye2)
		await _frames(12)
		var path2 := "%s/aroid_sport_%s.png" % [out_dir, PlantGenetics.kind_of(codes[k])]
		get_root().get_texture().get_image().save_png(path2)
		print("[aroid_view] sport demo %s -> %s" % [PlantGenetics.kind_of(codes[k]), path2])
	quit()


## Local midday on the local day `d` falls in (world days).
func _noon(d: float, lon: float) -> float:
	return floor(d + lon / TAU) + 0.5 - lon / TAU
