extends SceneTree
## Run: STAMP=1 STALL_LOG=1 godot --headless --path . --fixed-fps 60 --script tools/fire_wall_check.gd
## Mike, 1 Oct, bug 2 (an invisible wall near the camp fire): walk at the
## fire from four sides at the opening camp and at a ruin camp, holding
## W, and see how close you get. With STALL_LOG=1 the player's unstick
## rule prints what blocked you (node path, shape size). PASS when every
## approach ends within reach of the fire's stones.

var main
var world
var player: PlanetPlayer
var fails := 0
## The fire's ring stones reach 0.76 m; the body's capsule adds its own.
const CLOSE_M := 1.9


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	world = get_root().get_node("World")
	world.spawn_choice = 0
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(90)
	main.take_gifts()
	# --- The opening camp ---
	var fire: Node3D = main.camp._fire
	await _four_sides(fire, "the opening camp")
	# --- A ruin camp: the nearest inhabited ruin, walked to ---
	var pd: Vector3 = world.dir_of(player.global_position)
	var best := {}
	var best_m := INF
	for r in Ruins.near(world.planet, pd, 12000.0):
		if not Ruins.inhabited(r):
			continue
		var dm := CubeSphere.surface_distance_m(r.dir, pd)
		if dm < best_m:
			best_m = dm
			best = r
	if best.is_empty():
		print("[fire] no inhabited ruin within 12 km of the camp: the ruin half is skipped")
	else:
		print("[fire] the nearest inhabited ruin lies %.0f m off (%s)" % [best_m, best.get("kind", "?")])
		_put(best.dir, 0.0, 70.0)
		var camp: Node3D = null
		for i in 300:
			await frames(30)
			if i % 10 == 9:
				# The chunks have streamed in by now: stand on the ground.
				_put(best.dir, 0.0, 70.0)
				print("[fire] waiting: %d chunks, %d ruins built, %d camps" % [main.chunks.chunks.size(), main.landmarks.built_ruins().size(), main.camps._camps.size()])
			var nearest_m := INF
			for key in main.camps._camps:
				var cn: Node3D = main.camps._camps[key]
				var dm := cn.global_position.distance_to(player.global_position)
				if dm < nearest_m:
					nearest_m = dm
					camp = cn
			if camp != null and nearest_m < 150.0:
				break
		ok(camp != null, "a camp was built at the ruin")
		if camp != null:
			await _four_sides(camp.get_meta("fire"), "the ruin camp (%s)" % str(camp.get_meta("people", "?")))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Stand 8 m out on each of four bearings and hold W toward the fire for
## four seconds; the closest you got is the measure.
func _four_sides(fire: Node3D, where: String) -> void:
	var fd: Vector3 = world.dir_of(fire.global_position)
	for k in 4:
		var a := k * TAU / 4.0 + 0.3
		_put(fd, a, 8.0)
		await frames(5)
		var to: Vector3 = fire.global_position - player.global_position
		to = (to - player.up * to.dot(player.up)).normalized()
		player._heading = to
		player._yaw = 0.0
		player._pitch = 0.0
		var closest := INF
		Input.action_press("move_forward")
		for i in 240:
			await physics_frame
			closest = minf(closest, player.global_position.distance_to(fire.global_position))
		Input.action_release("move_forward")
		await frames(10)
		ok(closest <= CLOSE_M, "%s, bearing %d: walked to within %.2f m of the fire" % [where, k, closest])


func _put(d: Vector3, bearing: float, out_m: float) -> void:
	var at: Vector3 = CreatureSpawner._offset(d, bearing, out_m)
	player.global_position = world.to_scene(at, PlanetConst.RADIUS_M + main.chunks.ground_height(at)) + at * 0.6
	player.velocity = Vector3.ZERO
	player._move = Vector3.ZERO
