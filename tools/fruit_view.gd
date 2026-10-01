extends SceneTree
## Pictures of a tree's year (design §AS, FruitCrop): the nearest fruiting
## tree to the first camp, close up at noon on the days of its buds, its
## flowers with their pollinators at work, its fruit green and ripe, and
## its fallen fruit rotting under it. Writes <OUT_DIR>/fruit_<stage>.png.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --audio-driver Dummy --resolution 854x480 -s tools/fruit_view.gd
##
## SPECIES="common name": that species' nearest tree instead (it must grow
## round the camp). RENDER_CHUNKS=1 keeps it small.

var out_dir := "/tmp/shots"
var main
var world
var player: PlanetPlayer


func _initialize() -> void:
	if OS.get_environment("OUT_DIR") != "":
		out_dir = OS.get_environment("OUT_DIR")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _noon(day: float, d: Vector3) -> float:
	return Astro.days_at_solar_hour(floor(day), 12.0, CubeSphere.longitude(d), CubeSphere.latitude(d))


func _shot(name: String) -> void:
	await _frames(3)
	var img := get_root().get_texture().get_image()
	var path := out_dir.path_join("fruit_%s.png" % name)
	img.save_png(path)
	print("[fruit_view] %s" % path)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = get_root().get_node("World")
	world.pin(42, 0)
	seed(42)
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var clear := {"wind": Vector3(1, 0, 0.5), "rain_mm_h": 0.0, "snow": false, "temp_c": 20.0, "storm": 0.0, "clear": 1.0, "cloud": 0.1}
	main._weather_timer = 1e9
	main._local_weather = clear
	main._weather_eased = clear.duplicate()
	main.hud.visible = false
	player = main.player
	main.take_gifts()
	await _frames(60)
	var fc: FruitCrop = main.fruit_crop
	fc.update_now()
	var want := OS.get_environment("SPECIES")
	var pick = null
	var best := INF
	for key in fc._entries:
		var e = fc._entries[key]
		if e.tree < 0:
			continue
		if want != "" and e.crop.sp.name != want:
			continue
		var score: float = e.dist + (0.0 if not e.crop.guilds.is_empty() else 30.0)
		if score < best:
			best = score
			pick = e
	if pick == null:
		print("[fruit_view] no fruiting tree near the camp")
		quit()
		return
	var c = pick.crop
	print("[fruit_view] %s (%s): %d flowers, %s, fruit %s %s, %s" % [c.sp.name, c.sp.binomial(), c.flowers, str(c.guilds), c.kind, c.shape, c.drop])
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.05
	get_root().add_child(cam)
	cam.current = true
	var year := DayCycle.year_days()
	var yr := floori((world.days - pick.g0) / year)
	var d0: float = pick.g0 + yr * year + pick.t_off * maxf(c.win - c.tree_win, 0.0)
	var stages := [
		["buds", d0 - c.bud_d * 0.4],
		["flowers", d0 + c.tree_win * 0.5],
		["green", d0 + c.tree_win + c.open_d * 1.3 + (c.ripen.x + c.ripen.y) * 0.25],
		["ripe", d0 + c.tree_win + c.open_d * 1.3 + c.ripen.y + c.hang.x * 0.3],
		["fallen", d0 + c.tree_win + c.open_d * 1.3 + c.ripen.y + c.hang.y + c.rot.x * 0.4],
	]
	var up: Vector3 = pick.up
	for st in stages:
		world.days = _noon(float(st[1]), up)
		fc.daylight = 1.0
		fc.update_now()
		# Where the crop is: the middle of the drawn parts nearest a person
		# standing under the tree.
		var pts: Array = []
		var ground := str(st[0]) == "fallen"
		for s in pick.sites.size():
			pts.append(pick.chunk.to_global(pick.ground[s] if ground else pick.sites[s]))
		var base: Vector3 = pick.chunk.to_global(pick.xf.origin)
		var side: Vector3 = CubeSphere.north(up)
		# The lowest third of the sites (nearest the eye), their middle.
		pts.sort_custom(func(a, b) -> bool: return (a - base).dot(up) < (b - base).dot(up))
		var mid := Vector3.ZERO
		var k := maxi(1, pts.size() / 3)
		for i in k:
			mid += pts[i] / k
		var from: Vector3 = mid + side * (2.2 if not ground else 1.6) + up * (0.4 if not ground else 1.3)
		cam.global_transform = Transform3D(Basis.looking_at((mid - from).normalized(), up), from)
		player.global_position = base + side * 4.0 + up * 0.1
		# The flowers get a while for their visitors to come.
		var n := 900 if str(st[0]) == "flowers" else 30
		for i in n:
			world.days = _noon(float(st[1]), up)
			await process_frame
		print("[fruit_view] %s: day %.1f, %s, %d visitors, %d visits" % [st[0], world.days, str(pick.summary), fc._agents.size(), fc.visits_done])
		await _shot(str(st[0]))
		# A closer look at a visitor at work.
		if str(st[0]) == "flowers" and not fc._agents.is_empty():
			for a in fc._agents:
				if a.state == 1:
					var at: Vector3 = fc._agent_node.to_global(a.pos)
					var f2: Vector3 = at + side * 0.35 + up * 0.12
					cam.global_transform = Transform3D(Basis.looking_at((at - f2).normalized(), up), f2)
					await _shot("visitor")
					break
	quit()
