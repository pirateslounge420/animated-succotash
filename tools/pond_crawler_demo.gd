extends SceneTree
## Pond Crawler demo (Phase 1: its movement rig, ripple calls, hitboxes and
## sound; nothing spawns it in play until Phase 7). Starts the game
## (scenes/main.tscn, data/dev.json: the 40 km postage stamp, seed 42),
## finds swamp or bog water it can wade (the nearest wadeable pool in its
## biome_lock, else the nearest other wetland pool), sets the local clock
## to 23:00 and places a crawler there (PondCrawler.debug_spawn). Then:
##   default   a scripted shot for the recording (11.5 s): it waits in the
##             water (4 s), the player is moved to 5-11 m from it (where
##             the water as drawn is shallow enough to show them: see
##             _spot_near()), it lurches at them arm over arm and strikes,
##             quit
##   --stills  the same, saving a still every couple of seconds instead
##   --look    close stills from four sides and a top view (for judging
##             the model against spec R1a), quit
##   --play    no script: you're put on the bank near it and play
##
## Every ripple call the crawler makes goes through Ripples as in play. If
## the ripple simulation is attached, it draws the rings and the demo
## leaves it alone. If nothing is attached yet (before the ripple system
## merges; the calls are no-ops and no rings show), the demo attaches a
## stand-in that counts the calls reaching Ripples and answers readers
## like an empty simulation. Either way it prints each splash (time, where
## relative to the crawler, mass, speed), the wake calls per second and a
## summary from the crawler's own record of its calls, and writes them to
## $OUT_DIR/pond_crawler_ripples.csv.
##
## Run from the project folder:
##   recording (then convert, below):
##     xvfb-run -a -s "-screen 0 960x540x24" ~/bin/godot --rendering-method forward_plus --resolution 960x540 --write-movie /tmp/shots/pond_crawler.avi --fixed-fps 30 -s tools/pond_crawler_demo.gd
##   the script prints "[crawler] demo starts at movie second S"; cut from
##   there and pull stills:
##     FF=/usr/local/lib/python3.11/dist-packages/imageio_ffmpeg/binaries/ffmpeg-linux-x86_64-v7.0.2
##     $FF -y -ss S -i /tmp/shots/pond_crawler.avi -c:v libx264 -pix_fmt yuv420p -crf 18 /tmp/shots/pond_crawler.mp4
##     $FF -y -ss T -i /tmp/shots/pond_crawler.mp4 -frames:v 1 /tmp/shots/pond_crawler_still_1.png
##   stills or model views only:
##     xvfb-run -a -s "-screen 0 960x540x24" ~/bin/godot --rendering-method forward_plus --resolution 960x540 -s tools/pond_crawler_demo.gd -- --stills
##     (or -- --look; -- --play to walk around it yourself, with a display)
## Writes to $OUT_DIR (default /tmp/shots).

const IDLE_S := 4.0
const LURCH_S := 7.5
const PLAYER_M := 11.0
## Never left running by a script error: it quits after this long (wall
## clock, not game time: a headless run with --fixed-fps races through
## game time while the planet generates; a recording on a software
## renderer takes a good while).
const WATCHDOG_S := 3600.0

var out_dir := "/tmp/shots"
var main
var world
var cam: Camera3D
var crawler: PondCrawler
var args: PackedStringArray
## Attached only while no ripple simulation is (null once one is).
var stand_in: RippleStandIn
var pool := Vector3.ZERO
var t_demo := 0.0
## The recording: where the player is put (surface direction) and the
## camera (scene position), planned before the crawler is placed.
var target := Vector3.ZERO
var cam_pos := Vector3.ZERO
var _started_ms := 0
# The crawler's ripple calls as they happen: [t, pos, kg, mps] and
# [t, key, pos, kg, mps].
var splashes: Array = []
var wakes: Array = []
var _seen := {"splash": 0, "wake": 0}


## Stands in for the ripple simulation until it's merged: counts the calls
## that reach Ripples (checked against the crawler's own count), and
## answers readers like an empty simulation (no ripples, nothing near), so
## anything else that talks to Ripples carries on.
class RippleStandIn:
	var splashes := 0
	var wakes := 0

	func add_splash(_pos: Vector3, _kg: float, _mps: float) -> void:
		splashes += 1

	func add_wake(_key: int, _pos: Vector3, _kg: float, _mps: float) -> void:
		wakes += 1

	func height_at(_pos: Vector3) -> float:
		return 0.0

	func disturbance_at(_pos: Vector3) -> float:
		return 0.0

	func near(_pos: Vector3) -> bool:
		return false


func frames(n: int) -> void:
	for i in n:
		await process_frame


func set_time(local_h: float, d: Vector3) -> void:
	world.days = Astro.days_at_solar_hour(world.days, local_h, CubeSphere.longitude(d))


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
		if k > 30 and main.chunks._pending.is_empty() and main.landmarks._pending.is_empty():
			break
	get_root().disable_3d = false


func shot(file: String) -> void:
	await frames(2)
	var path := out_dir.path_join(file)
	get_root().get_texture().get_image().save_png(path)
	print("[crawler] saved ", path)


func _initialize() -> void:
	var env_out := OS.get_environment("OUT_DIR")
	if env_out != "":
		out_dir = env_out
	DirAccess.make_dir_recursive_absolute(out_dir)
	args = OS.get_cmdline_user_args()
	world = get_root().get_node("World")
	world.spawn_choice = 0
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	_started_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if not "--play" in args and Time.get_ticks_msec() - _started_ms > WATCHDOG_S * 1000.0:
		push_error("[crawler] watchdog: still running after %d s, quitting" % int(WATCHDOG_S))
		quit(2)
	return false


func _run() -> void:
	while not main._playing:
		await process_frame
	var boot_frame := Engine.get_frames_drawn()
	# Clear, still weather; no HUD.
	main._weather_timer = 1e9
	main._local_weather = {"wind": Vector3(0.5, 0, 0.3), "rain_mm_h": 0.0, "snow": false, "temp_c": 18.0, "storm": 0.0, "clear": 1.0, "cloud": 0.15}
	main.hud.visible = false
	cam = Camera3D.new()
	cam.far = 30000.0
	cam.near = 0.05
	cam.fov = 60.0
	get_root().add_child(cam)
	var sp := CreatureSpecies.find("Pond Crawler")
	var wade := Vector2(0.08, 1.3)
	var rw: Array = sp.data.get("rig", {}).get("wade_m", [0.08, 1.3])
	wade = Vector2(float(rw[0]), float(rw[1]))
	# Wadeable water: the biome lock first (swamp, bog), else any wetland.
	var map: PlanetData = world.planet
	var start: Vector3 = main.player.surface_dir
	var lock := true
	var candidates := PondCrawler.wetland_cells(map, start, 50000.0, sp.biome_lock)
	var others := PondCrawler.wetland_cells(map, start, 50000.0, PackedInt32Array([BiomeTemplates.FEN, BiomeTemplates.FRESHWATER_MARSH, BiomeTemplates.WET_MEADOW]))
	# Glow ponds (MagicSites) shine teal at night: the eye should be the one
	# accent, so plain pools come first.
	candidates.sort_custom(func(x, y): return int(MagicSites.is_glow_pond(map, x[0])) * 1e6 + x[1] < int(MagicSites.is_glow_pond(map, y[0])) * 1e6 + y[1])
	var tried := 0
	for list in [candidates, others]:
		for c in list:
			if tried >= 8:
				break
			tried += 1
			var cd: Vector3 = map.dir[c[0]]
			# Just the chunks there (nothing drawn): enough to look for water.
			main.chunks.load_blocking(cd)
			var p := PondCrawler.find_pool(main.chunks, cd, 110.0, wade)
			print("[crawler] %s cell %d (%.1f km away, glow pond %s): %s" % [BiomeTemplates.name_of(map.biome[c[0]]), c[0], c[1] / 1000.0,
				MagicSites.is_glow_pond(map, c[0]), "pool found" if p != Vector3.ZERO else "no wadeable pool"])
			if p != Vector3.ZERO:
				pool = p
				lock = list == candidates
				break
		if pool != Vector3.ZERO:
			break
	if pool == Vector3.ZERO:
		push_error("[crawler] no wadeable swamp or bog water found")
		quit(1)
		return
	await goto(pool)
	set_time(23.0, pool)
	# The ripple simulation draws the rings; until it's merged, a stand-in
	# counts the calls.
	if Ripples._sim == null:
		stand_in = RippleStandIn.new()
		Ripples.attach(stand_in)
	var depth: float = main.chunks.water_level_at(pool) - main.chunks.ground_height(pool)
	print("[crawler] pool at %s, water %.2f m deep, biome %s, lock %s" % [pool, depth, BiomeTemplates.name_of(map.biome[map.cell_at(pool)]), lock])
	# It waits facing the recording's camera.
	_plan_shot()
	var pool_g: Vector3 = world.to_scene(pool, PlanetConst.RADIUS_M + main.chunks.water_level_at(pool))
	crawler = PondCrawler.debug_spawn(main.creatures, pool, 7, lock, cam_pos - pool_g)
	# One slow re-plant early in the wait, so the shot shows one.
	crawler._replant_t = 0.9
	var st := PondCrawlerBody.stats()
	print("[crawler] body: %d triangles near, %d far (past %d m), %d bones, built in %d ms" % [st.tris, st.far_tris, int(PondCrawlerBody.FAR_M), st.bones, st.ms])
	# The player out of its way to start with (well beyond notice).
	var away := _spot_near(pool, 45.0, false)
	main.player.spawn_at(away, pool)
	main.player.visible = "--play" in args
	await frames(3)
	if "--play" in args:
		cam.queue_free()
		main.player.spawn_at(_spot_near(pool, 16.0, false), pool)
		main.player.visible = true
		main.hud.visible = true
		return
	if "--look" in args:
		await _look()
		quit()
		return
	await _demo(boot_frame)
	quit()


## Model views: four sides and above, close, at night. LOOK_COLORS (a
## comma list of body colors, e.g. "#1c2a8c,#6a70a8") repeats them in
## each color, for tuning the data's `color` (files end _c<n>).
func _look() -> void:
	crawler.rig.notice_m = 0.0
	await frames(20)
	var up: Vector3 = world.dir_of(crawler.global_position)
	var fwd := -crawler.global_basis.z
	var side := fwd.cross(up).normalized()
	var views := {"front": [fwd, 3.6, 0.7], "side": [side, 4.2, 0.8], "back": [-fwd, 4.0, 1.4], "front3q": [(fwd + side).normalized(), 3.2, 0.5],
		"top": [(fwd * 0.4 - side * 0.3).normalized(), 3.0, 3.6], "far": [(fwd - side * 0.5).normalized(), 14.0, 1.2]}
	var colors: Array = [""]
	if OS.get_environment("LOOK_COLORS") != "":
		colors = Array(OS.get_environment("LOOK_COLORS").split(","))
	for ci in colors.size():
		var suffix := ""
		if colors[ci] != "":
			var mat := PondCrawlerBody.material(crawler.species)
			var c := Color.from_string(colors[ci], Color.MAGENTA)
			var cl := c.srgb_to_linear()
			var pale := c.lerp(crawler.species.accent, 0.18).lightened(0.12).srgb_to_linear()
			mat.set_shader_parameter("body_color", Vector3(cl.r, cl.g, cl.b))
			mat.set_shader_parameter("pale_color", Vector3(pale.r, pale.g, pale.b))
			suffix = "_c%d" % ci
			print("[crawler] look colors %s: %s" % [suffix, colors[ci]])
		for v in views:
			var d: Array = views[v]
			var at: Vector3 = crawler.global_position + up * 0.25
			var from: Vector3 = at + (d[0] as Vector3) * float(d[1]) + up * float(d[2])
			cam.global_transform = Transform3D(Basis.looking_at((at - from).normalized(), up), from)
			cam.current = true
			await frames(4)
			await shot("pond_crawler_look_%s%s.png" % [v, suffix])


## Plans the recording: the player's spot (`target`, PLAYER_M off with
## wadeable water all the way) and the camera (`cam_pos`): off to the side
## of the line from the crawler to the player, about half way along it,
## 2.4 m over the water (looking down on it, where the rings spread), with
## no trunk or bank between it and the crawler's path.
func _plan_shot() -> void:
	target = _spot_near(pool, PLAYER_M, true)
	var up: Vector3 = pool
	var c: Vector3 = world.to_scene(pool, PlanetConst.RADIUS_M + main.chunks.water_level_at(pool))
	var t: Vector3 = world.to_scene(target, PlanetConst.RADIUS_M + main.chunks.ground_height(target))
	var line := t - c
	line -= up * line.dot(up)
	var along := line.normalized()
	var space := get_root().get_world_3d().direct_space_state
	# The player still stands at the pool (goto()): not in the way.
	var skip: Array[RID] = [main.player.get_rid()]
	var best := Vector3.ZERO
	var best_score := -INF
	for sd: float in [1.0, -1.0]:
		for off: Array in [[5.0, 5.5], [4.0, 6.0], [6.0, 5.0], [5.0, 7.0], [3.5, 4.5], [5.0, 4.0]]:
			var p := c + along * float(off[0]) + along.cross(up) * sd * float(off[1])
			var pd: Vector3 = world.dir_of(p)
			var h := maxf(main.chunks.water_level_at(pd), main.chunks.ground_height(pd))
			p = world.to_scene(pd, PlanetConst.RADIUS_M + h + 2.4)
			var score := -absf(float(off[0]) - 5.0) - absf(float(off[1]) - 5.5)
			# Trunks, rocks or the bank between it and the lurch's start,
			# middle and end.
			for end in [c + up * 0.4, t + up * 1.0, c.lerp(t, 0.5) + up * 0.5]:
				var ray := PhysicsRayQueryParameters3D.create(p, end, 0xFFFF & ~Hitboxes.LAYER)
				ray.exclude = skip
				if not space.intersect_ray(ray).is_empty():
					score -= 10.0
			var room := PhysicsShapeQueryParameters3D.new()
			room.shape = SphereShape3D.new()
			(room.shape as SphereShape3D).radius = 0.6
			room.transform = Transform3D(Basis.IDENTITY, p)
			if not space.intersect_shape(room, 1).is_empty():
				score -= 20.0
			if score > best_score:
				best_score = score
				best = p
	cam_pos = best
	print("[crawler] shot: player %.1f m off, camera %.1f m from the crawler (score %.1f)" % [c.distance_to(t), c.distance_to(cam_pos), best_score])


## The scripted shot: waiting, then the lurch at the player.
func _demo(boot_frame: int) -> void:
	var stills := "--stills" in args
	var up: Vector3 = world.dir_of(crawler.global_position)
	cam.fov = 45.0
	var look_at := crawler.global_position + up * 0.3
	var frame0 := Engine.get_frames_drawn()
	print("[crawler] demo starts at movie second %.2f (frame %d since boot %d)" % [float(frame0 - 1) / 30.0, frame0, boot_frame])
	var total := IDLE_S + LURCH_S
	var moved := false
	var next_still := 1.0
	var n_still := 0
	var last_wakes := 0
	var dt := 1.0 / 30.0
	while t_demo < total:
		if not moved and t_demo >= IDLE_S:
			moved = true
			var pd: Vector3 = target
			main.player.spawn_at(pd, world.dir_of(crawler.global_position))
			main.player.visible = true
			print("[crawler] %6.2f s  player moved %.1f m from the crawler" % [t_demo, main.player.global_position.distance_to(crawler.global_position)])
		# The camera pans with the crawler (and toward the player once
		# they're in).
		var want := crawler.global_position + up * 0.3
		if moved:
			want = want.lerp(main.player.global_position + up * 0.6, 0.25)
		look_at = look_at.lerp(want, clampf(dt * 2.0, 0.0, 1.0))
		cam.global_transform = Transform3D(Basis.looking_at((look_at - cam_pos).normalized(), up), cam_pos)
		cam.current = true
		await process_frame
		t_demo += dt
		_log_ripples()
		if int(t_demo) != int(t_demo - dt):
			var n := wakes.size() - last_wakes
			last_wakes = wakes.size()
			var w: Array = wakes.back() if not wakes.is_empty() else [0, 0, Vector3.ZERO, 0.0, 0.0]
			print("[ripples] %6.2f s  wake    %d calls in the last second (key %d, %.0f kg, now %.2f m/s); mode %s, %.1f m from the player, hp %.0f" % [
				t_demo, n, w[1], w[3], w[4], crawler.mode, crawler.global_position.distance_to(main.player.global_position), main.player.hp])
		if stills and t_demo >= next_still:
			next_still += 2.0
			n_still += 1
			await shot("pond_crawler_frame_%d.png" % n_still)
	_summary()


## The crawler's ripple calls since last frame (its own record of them,
## PondCrawler.ripple_stats, last_splashes and last_wake), printed and
## kept for the summary.
func _log_ripples() -> void:
	var st: Dictionary = crawler.ripple_stats
	var fresh: int = st.splash - _seen.splash
	var recent: Array = crawler.last_splashes
	for i in range(maxi(recent.size() - fresh, 0), recent.size()):
		var s: Array = recent[i]
		var pos: Vector3 = s[1]
		splashes.append([t_demo, pos, s[2], s[3]])
		print("[ripples] %6.2f s  splash  %.1f kg at %.2f m/s, %.1f m from the crawler's body" % [t_demo, s[2], s[3], (pos - crawler.global_position).length()])
	if st.wake > _seen.wake and not crawler.last_wake.is_empty():
		var w: Array = crawler.last_wake
		wakes.append([t_demo, w[1], w[2], w[3], w[4]])
	_seen.splash = st.splash
	_seen.wake = st.wake


## A spot to stand about `radius` m from `center` (ground, or water
## shallow enough to stand in: not swimming); `reachable`: with wadeable
## water for the crawler all the way to it (else the nearest miss), and
## where the water as drawn agrees with the water the crawler wades by
## (_drawn_water()): the player stands visibly in shallow water, not in a
## dip beside a raised sheet of water that hides them, and the crawler
## doesn't sink into the drawn surface on the way.
func _spot_near(center: Vector3, radius: float, reachable: bool) -> Vector3:
	var north := CubeSphere.north(center)
	var best := Vector3.ZERO
	var best_score := -INF
	# Shorter runs too, as a last resort for where the drawn water allows.
	for r: float in [radius, radius * 0.8, radius * 1.2, radius * 0.65, radius * 1.4, radius * 0.5, radius * 0.42]:
		for k in 36:
			var bearing := north.rotated(center, k * TAU / 36.0)
			var p := (center + bearing * r / PlanetConst.RADIUS_M).normalized()
			var ground: float = main.chunks.ground_height(p)
			var depth: float = main.chunks.water_level_at(p) - ground
			# Ankle- to knee-deep water is best (the crawler can reach you
			# there); dry ground next; too deep to stand is out.
			var score := -absf(depth - 0.3) * 4.0 - absf(r - radius) * 0.5
			if depth > 0.8:
				score -= 30.0
			if reachable:
				var run := 0
				for s in range(1, int(r)):
					var q := (center + bearing * s / PlanetConst.RADIUS_M).normalized()
					var dq: float = main.chunks.water_level_at(q) - main.chunks.ground_height(q)
					if dq < 0.12 or dq > 1.3:
						break
					run = s
				score -= (int(r) - 1 - run) * 2.0
				# The drawn water: over the player no more than knee deep,
				# and along the way within a hand of the level it wades by.
				var drawn := _drawn_water(p)
				var shown := 2.0 if is_nan(drawn) else drawn - ground
				score -= maxf(shown - 0.6, 0.0) * 20.0
				var gap := 0.0
				for s in range(0, int(r) + 1):
					var q := (center + bearing * s / PlanetConst.RADIUS_M).normalized()
					var dw := _drawn_water(q)
					gap = maxf(gap, 2.0 if is_nan(dw) else absf(dw - main.chunks.water_level_at(q)))
				score -= maxf(gap - 0.15, 0.0) * 10.0
			if score > best_score:
				best_score = score
				best = p
	return best


## The height (m over the planet's radius) of the water surface as drawn
## over surface direction `d`, NAN where none is. The chunk's water quads,
## split as TerrainChunk._build_water() splits them (corners 0-2-1,
## 0-3-2). Not always ChunkManager.water_level_at(): a quad whose corners'
## levels jump keeps one flat level, over ground that level_at puts
## shallower (see the planning in _spot_near()).
func _drawn_water(d: Vector3) -> float:
	var c: TerrainChunk = main.chunks.chunk_at(d)
	if c == null or c.data.is_empty():
		return NAN
	for q: Array in c.data.water:
		var radii: PackedFloat32Array = q[4]
		for tri: Array in [[0, 2, 1], [0, 3, 2]]:
			var a: Vector3 = q[tri[0]]
			var b: Vector3 = q[tri[1]]
			var e: Vector3 = q[tri[2]]
			var n := (b - a).cross(e - a)
			if n.length_squared() < 1e-24:
				continue
			# Barycentric weights of d projected onto the triangle's plane.
			var p := d - n.normalized() * (d - a).dot(n.normalized())
			var wa := (b - p).cross(e - p).dot(n) / n.length_squared()
			var wb := (e - p).cross(a - p).dot(n) / n.length_squared()
			var we := 1.0 - wa - wb
			if wa >= -1e-4 and wb >= -1e-4 and we >= -1e-4:
				return radii[tri[0]] * wa + radii[tri[1]] * wb + radii[tri[2]] * we - PlanetConst.RADIUS_M
	return NAN


func _summary() -> void:
	var f := FileAccess.open(out_dir.path_join("pond_crawler_ripples.csv"), FileAccess.WRITE)
	f.store_line("t_s,kind,key,x,y,z,mass_kg,speed_mps")
	for s in splashes:
		var p: Vector3 = s[1]
		f.store_line("%.3f,splash,,%.3f,%.3f,%.3f,%.2f,%.3f" % [s[0], p.x, p.y, p.z, s[2], s[3]])
	for w in wakes:
		var p: Vector3 = w[2]
		f.store_line("%.3f,wake,%d,%.3f,%.3f,%.3f,%.2f,%.3f" % [w[0], w[1], p.x, p.y, p.z, w[3], w[4]])
	f.close()
	var st := crawler.ripple_stats
	var idle := 0
	for s in splashes:
		if s[0] < IDLE_S:
			idle += 1
	print("[ripples] summary: %d splashes (%d while waiting, %d lurching), %.1f-%.1f kg at %.2f-%.2f m/s; %d wake calls (one a frame in the water), %.0f kg at %.2f-%.2f m/s" % [
		st.splash, idle, st.splash - idle, st.splash_kg.x, st.splash_kg.y, st.splash_mps.x, st.splash_mps.y,
		st.wake, st.wake_kg.y, st.wake_mps.x, st.wake_mps.y])
	if stand_in:
		print("[ripples] no ripple simulation attached (no rings drawn): the stand-in got %d splashes and %d wakes through Ripples, the crawler counts %d and %d" % [
			stand_in.splashes, stand_in.wakes, st.splash, st.wake])
	else:
		print("[ripples] ripple simulation attached: it draws the rings")
	print("[crawler] player hp %.0f, crawler mode %s" % [main.player.hp, crawler.mode])
