extends SceneTree
## Night Rider demo (data/creatures/README.md, "Night rider"): the game on
## the dev postage stamp (data/dev.json), in the boreal forest (taiga) at
## 23:00 local time. The biome cue plays (distant hoofbeats, 3D, off in the
## forest), then a Night Rider pair walks past the camera through a gap in
## the trees for 11.5 s, and it quits. Made to be recorded; the pair is
## spawned through Mythics.spawn_night_riders(), the same path as the dev
## F7 spawn, but walking a set line and passive (the camera is not a
## player).
##
## Run from the project folder:
##   recording (the movie includes the loading; see DEMO_FRAMES below):
##     xvfb-run -a -s "-screen 0 960x540x24" ~/bin/godot --path . --rendering-method forward_plus --resolution 960x540 --write-movie /tmp/shots/night_rider.avi --fixed-fps 30 -s tools/night_rider_demo.gd
##   stills only (no movie): add STILLS=/tmp/shots/night_rider_live in the
##   environment; frames at 2, 5, 8 and 11 s are saved as <prefix>_<n>.png.
## It prints "DEMO_FRAMES <first> <last>": the frames drawn when the demo
## starts and ends (30 fps). The movie holds one frame more than were
## drawn, so the demo starts at movie frame first + 1; cut the loading, e.g.
##   ffmpeg -ss <(first+1)/30> -i night_rider.avi -t <(last-first)/30> -c:v libx264 -pix_fmt yuv420p -c:a aac night_rider.mp4
## CLOSE=1 frames the pair tighter (a closer camera).

const SECONDS := 11.5
## The corridor they walk: this far before the point nearest the camera
## when the demo starts, and the camera this far to the side.
const START_BEFORE_M := 5.5
const CAMERA_SIDE_M := 8.0
const EYE_M := 1.4
## The corridor search: how far from the deepest taiga spot it looks (m),
## the clearance from bark to their bodies along the line (m), and the
## cell size of the trunk map (m).
const SEARCH_M := 150
const CLEAR_M := 1.3
const CELL_M := 5.0

var main
var world
var cam: Camera3D
## Set by _setup(): where the camera stands, and the line they walk (its
## middle is the point nearest the camera).
var cam_d := Vector3.UP
var mid := Vector3.UP
var along := Vector3.FORWARD
## Set by _spawn().
var pair: NightRiderPair
var _look_at := Vector3.ZERO


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	await _setup()
	_spawn()
	var first := Engine.get_frames_drawn()
	var stills := OS.get_environment("STILLS")
	var at := [60, 150, 240, 330]
	var n := int(SECONDS * 30.0)
	for f in n:
		_aim(f == 0)
		if f == 0:
			var cue = main.mythics.cue_position()
			if cue != null:
				print("[demo] cue source %.0f m away" % [(cue as Vector3).distance_to(cam.global_position)])
		if stills != "" and f in at:
			await frames(1)
			get_root().get_texture().get_image().save_png("%s_%d.png" % [stills, at.find(f) + 1])
		await process_frame
		if f % 60 == 0:
			var lead: NightRider = pair.riders[0]
			var tail: NightRider = pair.riders[pair.riders.size() - 1]
			print("[demo] t=%.0f s  leader %.2f m/s, gap %.2f m, gait phases %.2f / %.2f" % [f / 30.0, lead.speed,
				CubeSphere.surface_distance_m(lead.dir, tail.dir), lead.phase, tail.phase])
	print("DEMO_FRAMES %d %d" % [first, Engine.get_frames_drawn()])
	quit()


## Boot the game, find the forest line and the camera's spot, go there and
## set the clock to 23:00 local.
func _setup() -> void:
	world = get_root().get_node("World")
	world.spawn_choice = 0
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	main._weather_timer = 1e9
	main.hud.visible = false
	cam = Camera3D.new()
	cam.far = 30000.0
	cam.near = 0.1
	cam.fov = 58.0
	get_root().add_child(cam)
	var map: PlanetData = world.planet
	var forest := _deepest_taiga(map)
	print("[demo] taiga at ", CubeSphere.surface_distance_m(main.player.surface_dir, forest), " m from the first camp")
	await _goto(forest)
	var line := _corridor(forest)
	if line.is_empty():
		print("[demo] no clear line through the trees; using the forest spot")
		line = {"mid": forest, "along": CubeSphere.east(forest), "side": CubeSphere.north(forest)}
	mid = line.mid
	along = line.along
	var side: Vector3 = line.side
	var r := PlanetConst.RADIUS_M
	cam_d = (mid + side * (CAMERA_SIDE_M * (0.72 if OS.get_environment("CLOSE") == "1" else 1.0)) / r).normalized()
	# The player (hidden) stands at the camera: the biome under it is what
	# the cue reads, and the clock is set for its longitude.
	await _goto(cam_d)
	main.player.visible = false
	world.days = Astro.days_at_solar_hour(world.days, 23.0, CubeSphere.longitude(cam_d), CubeSphere.latitude(cam_d))
	main._local_weather = {"wind": along * 1.0, "rain_mm_h": 0.0, "snow": false, "temp_c": 2.0, "storm": 0.0, "clear": 1.0, "cloud": 0.15}
	await frames(40)
	print("[demo] local %.1f h, daylight %.2f, moon %.2f lit, biome %s" % [Astro.local_hours(world.days, CubeSphere.longitude(cam_d)), main.sky.daylight,
		Astro.moon_illumination(world.days), BiomeTemplates.name_of(map.biome[map.cell_at(cam_d)])])


## The pair, already walking, START_BEFORE_M before the line's middle,
## passive, on a route along the line; and the biome cue, as on walking
## in (the automatic one is held back so it plays now, with the demo).
func _spawn() -> void:
	var r := PlanetConst.RADIUS_M
	var sp := CreatureSpecies.find("Night rider")
	NightRiderBody.wait_ready(sp)
	var start := (mid - along * START_BEFORE_M / r).normalized()
	var end := (mid + along * 60.0 / r).normalized()
	pair = main.mythics.spawn_night_riders(start, along, [end], sp.speed_mps, false)
	pair.appear_now()
	for c in main.mythics._cues:
		c.inside = true
		c.next_ok = 1e9
	main.mythics.play_cue(sp)


## Aim the camera (at eye height on its spot) between the two riders,
## easing after the first frame.
func _aim(first: bool) -> void:
	var r := PlanetConst.RADIUS_M
	var lead: NightRider = pair.riders[0]
	var tail: NightRider = pair.riders[pair.riders.size() - 1]
	var up: Vector3 = world.dir_of(lead.global_position)
	var target: Vector3 = (lead.global_position + tail.global_position) * 0.5 + up * 1.35
	_look_at = target if first else _look_at.lerp(target, 0.06)
	var eye: Vector3 = world.to_scene(cam_d, r + main.chunks.ground_height(cam_d) + EYE_M)
	cam.global_transform = Transform3D(Basis.looking_at((_look_at - eye).normalized(), world.dir_of(eye)), eye)
	cam.current = true


## Teleport the player (and so the loaded world) to `d`, and let the
## chunks and landmarks there load.
func _goto(d: Vector3) -> void:
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
		if k > 50 and main.chunks._pending.is_empty() and main.landmarks._pending.is_empty():
			break
	get_root().disable_3d = false


## The taiga cell with the most taiga round it (two rings of cells).
func _deepest_taiga(map: PlanetData) -> Vector3:
	var best := -1
	var best_d := Vector3.UP
	for c in map.cell_count:
		if map.biome[c] != BiomeTemplates.TAIGA or map.water[c] != PlanetData.Water.NONE:
			continue
		var score := 0
		for k in 8:
			var nb: int = map.neighbors[c * 8 + k]
			if nb >= 0 and map.biome[nb] == BiomeTemplates.TAIGA:
				score += 2
				for k2 in 8:
					var nb2: int = map.neighbors[nb * 8 + k2]
					if nb2 >= 0 and map.biome[nb2] == BiomeTemplates.TAIGA:
						score += 1
		if score > best:
			best = score
			best_d = map.dir[c]
	return best_d


## A straight line through the forest near `center` for the pair to walk,
## and a spot beside it for the camera: dry and fairly level; no trunk
## within CLEAR_M of the line where they walk (bark to body) or on it
## farther ahead (they'd steer round it), none across the camera's view of
## them; and as many trees as possible in the shot behind them and round
## about, so it's the forest and not a clearing. {"mid", "along", "side"}
## or {}.
func _corridor(center: Vector3) -> Dictionary:
	var r := PlanetConst.RADIUS_M
	var e := CubeSphere.east(center)
	var n := CubeSphere.north(center)
	var grid := _trunk_map(center, SEARCH_M + 60.0)
	var to_dir := func(q: Vector2) -> Vector3:
		return (center + (e * q.x + n * q.y) / r).normalized()
	var chunks: ChunkManager = main.chunks
	var best := {}
	var best_score := -INF
	var tried := 0
	for mx in range(-SEARCH_M, SEARCH_M + 1, 6):
		for my in range(-SEARCH_M, SEARCH_M + 1, 6):
			var m2 := Vector2(mx, my)
			if m2.length() > SEARCH_M:
				continue
			var m: Vector3 = to_dir.call(m2)
			if world.planet.biome[world.planet.cell_at(m)] != BiomeTemplates.TAIGA:
				continue
			var h0: float = chunks.ground_height(m)
			for a in 12:
				var al := Vector2(sin(a * PI / 12.0), cos(a * PI / 12.0))
				# Where they walk (the follower 5 m behind the leader), then
				# the leader's way on (its trunk rays look 11 m ahead).
				if _trunks_near(grid, m2 - al * 14.0, m2 + al * 10.0, CLEAR_M) > 0:
					continue
				if _trunks_near(grid, m2 + al * 10.0, m2 + al * 22.0, 0.4) > 0:
					continue
				var ok := true
				for k in range(-14, 11, 2):
					var p: Vector3 = to_dir.call(m2 + al * float(k))
					var g: float = chunks.ground_height(p)
					if chunks.water_level_at(p) > g + 0.05 or absf(g - h0) > 1.5:
						ok = false
						break
				if not ok:
					continue
				for sgn: float in [-1.0, 1.0]:
					var sd := Vector2(al.y, -al.x) * sgn
					var c2 := m2 + sd * CAMERA_SIDE_M
					var c: Vector3 = to_dir.call(c2)
					var gc: float = chunks.ground_height(c)
					if chunks.water_level_at(c) > gc + 0.05 or absf(gc - h0) > 1.2:
						continue
					if _trunks_near(grid, c2, c2, 0.8) > 0:
						continue
					# The view of them, from start to end.
					var clear := true
					for k in [-12, -8, -4, 0, 4, 8]:
						if _trunks_near(grid, c2, m2 + al * float(k), 0.45) > 0:
							clear = false
							break
					if not clear:
						continue
					tried += 1
					# The forest in the shot: trees behind them (2 to 34 m past
					# the line) and round about.
					var behind := _trunks_near(grid, m2 - sd * 18.0, m2 - sd * 18.0, 16.0)
					var around := _trunks_near(grid, m2, m2, 22.0)
					var score := float(behind) + 0.5 * float(around) - 4.0 * absf(gc - h0)
					if score > best_score:
						best_score = score
						var along := e * al.x + n * al.y
						var side := e * sd.x + n * sd.y
						best = {"mid": m, "along": (along - m * along.dot(m)).normalized(), "side": (side - m * side.dot(m)).normalized()}
	print("[demo] %d views that fit; the best has %.1f (trees behind them, and half of those round about)" % [tried, best_score])
	return best


## Tree trunks round `center` on a flat map (meters east, north), in
## CELL_M cells: {Vector2i: [Vector3(east, north, trunk radius)]}. Radii
## as TerrainChunk's trunk colliders.
func _trunk_map(center: Vector3, reach: float) -> Dictionary:
	var r := PlanetConst.RADIUS_M
	var e := CubeSphere.east(center)
	var n := CubeSphere.north(center)
	var grid := {}
	var count := 0
	for chunk in main.chunks.chunks.values():
		var tc := chunk as TerrainChunk
		for i in tc.trees.size():
			var d: Vector3 = world.dir_of(tc.tree_base(i))
			var q := Vector2((d - center).dot(e), (d - center).dot(n)) * r
			if q.length() > reach:
				continue
			var rad := clampf(PlantMeshes.tree_dims(tc.tree_species(i).shape).x * float(tc.trees[i][1]) * 0.85, 0.1, 1.6)
			var key := Vector2i(floori(q.x / CELL_M), floori(q.y / CELL_M))
			if not grid.has(key):
				grid[key] = []
			(grid[key] as Array).append(Vector3(q.x, q.y, rad))
			count += 1
	print("[demo] %d trees within %.0f m of the forest spot" % [count, reach])
	return grid


## How many trunks' bark comes within `margin` of the segment a..b (flat
## map; a == b: of a point).
func _trunks_near(grid: Dictionary, a: Vector2, b: Vector2, margin: float) -> int:
	var reach := margin + 1.6
	var lo := Vector2i(floori((minf(a.x, b.x) - reach) / CELL_M), floori((minf(a.y, b.y) - reach) / CELL_M))
	var hi := Vector2i(floori((maxf(a.x, b.x) + reach) / CELL_M), floori((maxf(a.y, b.y) + reach) / CELL_M))
	var ab := b - a
	var l2 := maxf(ab.length_squared(), 1e-6)
	var hits := 0
	for gx in range(lo.x, hi.x + 1):
		for gy in range(lo.y, hi.y + 1):
			for t: Vector3 in grid.get(Vector2i(gx, gy), []):
				var p := Vector2(t.x, t.y)
				var f := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
				if p.distance_to(a + ab * f) - t.z < margin:
					hits += 1
	return hits
