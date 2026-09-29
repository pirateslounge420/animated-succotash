extends SceneTree
## Species side by side (design §AH/§AI dev check): an oak, a maple, a
## Scots pine and a coconut palm (SPECIES: comma-separated names to use
## others) stood in a row on dry land 38 m from the first camp (seed 42, dev mode), the
## camera 1.7 m up south of them looking north, the weather held clear. The rest of
## the vegetation is hidden so only these stand there (KEEP_VEG=1 keeps
## it). Each tree is drawn exactly as in play: its hero mesh in a
## one-plant MultiMesh with its own material (PlantMeshes.material_for).
## Saves one frame per requested local solar hour:
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" ~/bin/godot --path . \
##     --rendering-method forward_plus --resolution 1708x960 -s tools/species_row.gd
##
## HOURS (default "14"), YEAR_DAY (day of the year, 0 = the northern spring
## equinox; default tomorrow), DAYS (comma-separated days of the year: one
## frame each at the first hour, for running the clock through a season),
## HEIGHT_M (each tree's height, default 13; "auto": 0.6 of its species'
## typical height), SPACING (m between trees, default 11), LAYOUT (its
## layout: 0-2 open-grown, 3-5 forest-grown; default its far/first),
## BARE=1 (no leaves: the skeleton alone), FRAMES (frames held before
## each shot, default 20: more lets falling leaves get down), DIST (the camera's distance
## from the row, default 22 m), WIND (m/s, default 1.1; above
## litter.json fall.gust_mps in the fall, a gust strips the crowns), NO_TILES=1 (the class
## textures, as before §AH, to compare), OUT_DIR (default /tmp/shots),
## TAG (default "species"): writes <TAG>_<hh>h.png or <TAG>_d<day>.png.
## RUN="from,to,step": run the clock through the year instead (see
## _run_clock: a temperate year's temperature, rain every 9 days); LOOK_H: where on the trees the camera aims (share of
## their height, default 0.45; 0 looks at their feet); TOP=1 looks down
## on the row from 30 m up.

var out_dir := "/tmp/shots"


func _initialize() -> void:
	if OS.get_environment("OUT_DIR") != "":
		out_dir = OS.get_environment("OUT_DIR")
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world = get_root().get_node("World")
	world.spawn_choice = 0
	seed(42)
	Encampment.fixed_side = 0.0
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var wind_mps := float(OS.get_environment("WIND")) if OS.get_environment("WIND") != "" else 1.1
	var clear := {"wind": Vector3(1, 0, 0.5).normalized() * wind_mps, "rain_mm_h": 0.0, "snow": false, "temp_c": 18.0, "storm": 0.0, "clear": 1.0, "cloud": 0.15}
	main._weather_timer = 1e9
	main._local_weather = clear
	main._weather_eased = clear.duplicate()
	main.hud.visible = false
	var player: PlanetPlayer = main.player
	player.set_physics_process(false)
	player.visible = false

	var names := (OS.get_environment("SPECIES") if OS.get_environment("SPECIES") != "" else "Oak,Maple,Scots pine,Coconut palm").split(",")
	var height_env := OS.get_environment("HEIGHT_M")
	var height := float(height_env) if height_env != "" and height_env != "auto" else 13.0
	var spacing := float(OS.get_environment("SPACING")) if OS.get_environment("SPACING") != "" else 11.0
	var layout := int(OS.get_environment("LAYOUT")) if OS.get_environment("LAYOUT") != "" else -1
	var pd: Vector3 = main.camp.site
	var n := CubeSphere.north(pd)
	# The row and the camera on dry land: the first of 16 headings from
	# the camp where every tree, the ground round them and the camera
	# stand above water.
	var dist0 := float(OS.get_environment("DIST")) if OS.get_environment("DIST") != "" else 22.0
	for k in 16:
		var hn := n.rotated(pd, TAU * k / 16.0)
		if _dry(main, pd, hn, names.size(), dist0):
			n = hn
			break
	var e := n.cross(pd).normalized()
	# The row 38 m south of the camp, 11 m apart across it (west to east
	# in the order given); the camera 26 m farther south looking back north,
	# so the midday sun (in the south, here) lights the side it sees.
	var row_d := (pd - n * 38.0 / PlanetConst.RADIUS_M).normalized()
	var cam_d := (pd - n * (38.0 + dist0) / PlanetConst.RADIUS_M).normalized()
	await _frames(10)
	if OS.get_environment("KEEP_VEG") != "1":
		_hide_vegetation(get_root())
		main.leaf_season.only_extra = true
	var trees: Array[Node3D] = []
	for i in names.size():
		var sp := SpeciesDB.find(names[i].strip_edges())
		if sp == null:
			print("[species] no species named '%s'" % names[i])
			continue
		var off := (float(i) - (names.size() - 1) * 0.5) * spacing
		var h := height
		if height_env == "auto":
			h = clampf((sp.height_m.x + sp.height_m.y) * 0.5 * 0.6, 8.0, 22.0)
		var d := (row_d + e * off / PlanetConst.RADIUS_M).normalized()
		var at: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d) - 0.1)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true
		mm.mesh = PlantMeshes.mesh_for(sp, PlantMeshes.LOD_HERO, layout)
		mm.instance_count = 1
		var b := Basis(e, d, e.cross(d)).orthonormalized().scaled(Vector3.ONE * h)
		mm.set_instance_transform(0, Transform3D(b, Vector3.ZERO))
		mm.set_instance_color(0, Color.WHITE)
		mm.set_instance_custom_data(0, Color(0, 0, 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = PlantMeshes.material() if OS.get_environment("NO_TILES") == "1" else PlantMeshes.material_for(sp)
		mmi.name = "Row_" + sp.name
		get_root().add_child(mmi)
		mmi.global_position = at
		trees.append(mmi)
		main.leaf_season.extra.append([at, h, SpeciesDB.index_of(sp)])
		if OS.get_environment("BARE") == "1":
			var bare_m := (mmi.material_override as ShaderMaterial).duplicate() as ShaderMaterial
			bare_m.set_shader_parameter("leaf_season", 0.0)
			mmi.material_override = bare_m
		print("[species] %s: %s, tiles %s" % [sp.name, sp.genus, sp.tiles.keys()])
	main.leaf_season._scan_t = 0.0 # take the row now
	var eye: Vector3 = world.to_scene(cam_d, PlanetConst.RADIUS_M + main.chunks.ground_height(cam_d) + 1.7)
	var look_h := float(OS.get_environment("LOOK_H")) if OS.get_environment("LOOK_H") != "" else 0.45
	var mid: Vector3 = world.to_scene(row_d, PlanetConst.RADIUS_M + main.chunks.ground_height(row_d) + height * look_h)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.1
	cam.far = 30000.0
	get_root().add_child(cam)
	cam.global_transform = Transform3D(Basis.looking_at((mid - eye).normalized(), cam_d), eye)
	# TOP=1: from 30 m above the row, looking down on it (the piles).
	if OS.get_environment("TOP") == "1":
		var above: Vector3 = world.to_scene((row_d - n * (6.0 if OS.get_environment("TOP_M") == "" else 3.0) / PlanetConst.RADIUS_M + e * (0.0 if OS.get_environment("TOP_M") == "" else -11.0) / PlanetConst.RADIUS_M).normalized(), PlanetConst.RADIUS_M + main.chunks.ground_height(row_d) + (float(OS.get_environment("TOP_M")) if OS.get_environment("TOP_M") != "" else 30.0))
		var ground_mid: Vector3 = world.to_scene(row_d, PlanetConst.RADIUS_M + main.chunks.ground_height(row_d))
		cam.global_transform = Transform3D(Basis.looking_at((ground_mid - above).normalized(), n), above)
	cam.current = true

	var tag := OS.get_environment("TAG") if OS.get_environment("TAG") != "" else "species"
	var hours := (OS.get_environment("HOURS") if OS.get_environment("HOURS") != "" else "14").split(",")
	var lon := CubeSphere.longitude(pd)
	var base: float = floor(world.days) + 1.0
	if OS.get_environment("YEAR_DAY") != "":
		base += fposmod(float(OS.get_environment("YEAR_DAY")) - Astro.year_day(base), DayCycle.year_days())
	var shots: Array = []
	if OS.get_environment("RUN") != "":
		await _run_clock(main, world, pd, lon, base, float(hours[0]), tag)
		quit()
		return
	if OS.get_environment("DAYS") != "":
		for dd in OS.get_environment("DAYS").split(","):
			var day0: float = base + fposmod(float(dd) - Astro.year_day(base), DayCycle.year_days())
			shots.append([day0, float(hours[0]), "%s_d%03d.png" % [tag, int(float(dd))]])
	else:
		for h in hours:
			shots.append([base, float(h), "%s_%02dh.png" % [tag, int(float(h))]])
	for s in shots:
		var days := Astro.days_at_solar_hour(s[0], s[1], lon, CubeSphere.latitude(pd))
		for k in (int(OS.get_environment("FRAMES")) if OS.get_environment("FRAMES") != "" else 20):
			world.days = days
			await process_frame
		var img := get_root().get_texture().get_image()
		var path := out_dir.path_join(s[2])
		img.save_png(path)
		var ls: LeafSeason = main.leaf_season
		print("[species] day %.1f (year day %.0f, %s) %05.2f h: autumn %.2f, leaf left %.2f, %d leaves falling (%d trees shedding %.3f/day, wind %.1f m/s) -> %s" % [days, Astro.year_day(days), Seasons.label(days, CubeSphere.latitude(pd)), s[1], ls.autumn, ls.leaf_left, ls.falling_count(), ls._trees.size(), ls.shed_per_day, WeatherFX.plant_wind.length(), path])
	quit()


## RUN="from,to,step": the clock runs from one day of the year to another
## `step` days a frame at the first hour (so the season, the fall, the
## piles and their rotting all run through), saving a frame on each day
## in DAYS it passes.
func _run_clock(main: Node, world: Node, pd: Vector3, lon: float, base: float, hour: float, tag: String) -> void:
	var r := OS.get_environment("RUN").split(",")
	var from := float(r[0])
	var to := float(r[1])
	var step := float(r[2]) if r.size() > 2 else 0.25
	var want: Array = []
	for dd in OS.get_environment("DAYS").split(","):
		if dd != "":
			want.append(float(dd))
	var day0: float = base + fposmod(from - Astro.year_day(base), DayCycle.year_days())
	var yd := from
	while yd <= to + 1e-4:
		var days := Astro.days_at_solar_hour(day0 + (yd - from), hour, lon, CubeSphere.latitude(pd))
		world.days = days
		# A temperate year: 12 °C plus the season's swing here, and a day
		# of rain every 9 days (never the day of a shot), so the litter
		# has weather to rot in.
		var wet := int(yd) % 9 == 0
		for w in want:
			if absf(yd - w) < 1.5:
				wet = false
		for wd in [main._local_weather, main._weather_eased]:
			wd["temp_c"] = 12.0 + Seasons.temp_offset_c(days, CubeSphere.latitude(pd))
			wd["rain_mm_h"] = 2.0 if wet else 0.0
		await process_frame
		for w in want.duplicate():
			if yd + 1e-4 >= w:
				want.erase(w)
				for k in 12:
					world.days = days
					await process_frame
				var path := out_dir.path_join("%s_d%03d.png" % [tag, int(w)])
				get_root().get_texture().get_image().save_png(path)
				var ls: LeafSeason = main.leaf_season
				var lf: LitterField = main.litter
				var deepest := 0.0
				var stage := 0.0
				for k2 in lf.cells:
					var c: LitterField.Cell = lf.cells[k2]
					if c.mass() > deepest:
						deepest = c.mass()
						stage = lf.stage_of(c)
				print("[species] year day %.0f (%s): autumn %.2f, leaf left %.2f, %d falling; litter %d cells, deepest %.1f cm at stage %.2f -> %s" % [w, Seasons.label(days, CubeSphere.latitude(pd)), ls.autumn, ls.leaf_left, ls.falling_count(), lf.cells.size(), deepest * float(LitterField.PILE.get("cm_per_kg_m2", 6.0)), stage, path])
		yd += step


func _frames(k: int) -> void:
	for i in k:
		await process_frame


## Is the ground dry for a row of `count` trees 38 m out along -`n` (11 m
## apart, 8 m round each) and the camera `dist` m beyond it?
func _dry(main: Node, pd: Vector3, n: Vector3, count: int, dist: float) -> bool:
	var e := n.cross(pd).normalized()
	var pts: Array[Vector3] = []
	for i in count:
		var off := (float(i) - (count - 1) * 0.5) * 11.0
		for dx in [-8.0, 0.0, 8.0]:
			for dz in [-8.0, 0.0, 8.0]:
				pts.append((pd - n * (38.0 + dz) / PlanetConst.RADIUS_M + e * (off + dx) / PlanetConst.RADIUS_M).normalized())
	pts.append((pd - n * (38.0 + dist) / PlanetConst.RADIUS_M).normalized())
	for q in pts:
		if main.chunks.water_level_at(q) > main.chunks.ground_height(q) - 0.2:
			return false
	return true


## Hides every placed plant (VegetationPlacer's nodes carry "species").
func _hide_vegetation(node: Node) -> void:
	for c in node.get_children():
		if c is MultiMeshInstance3D and c.has_meta("species"):
			(c as MultiMeshInstance3D).visible = false
		_hide_vegetation(c)
