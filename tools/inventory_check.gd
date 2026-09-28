extends SceneTree
## Run: godot --headless --path . --fixed-fps 60 --script tools/inventory_check.gd (OUT=shot.png with a display for a screenshot)
## Inventory (item 11): E on a plant takes a sample carrying its binomial;
## the screen opens on I without pausing; G sets a thing down, E takes it
## back; overburden past six slows, slows climbing and is louder.
## With OUT set (and a display), saves a screenshot of the open screen.
var main
var world
var player: PlanetPlayer
var fails := 0

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1

func act(a: String) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = true
	main._unhandled_input(e)

func _initialize() -> void:
	world = get_root().get_node("World")
	world.spawn_choice = 0
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(120)
	var inv := player.inventory
	ok(inv.worn_in("ranged") != null and inv.worn_in("ranged").kind == "bow" and inv.worn_in("melee").kind == "spear", "starts wearing the bow (ranged) and the spear (melee)")
	ok(inv.carried.size() == 10 and inv.count() == 0, "ten empty carry slots")

	# E on plants: walk about near the camp looking down at the ground ahead
	# and to the sides; whenever the crosshair names a plant within reach,
	# press E.
	var look := player.look
	var taken := 0
	var names := []
	var seen := {}
	var here: Vector3 = player.surface_dir
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 40:
		if taken >= 6:
			break
		var n := CubeSphere.north(here)
		var e2 := n.cross(here).normalized()
		var ang := rng.randf() * TAU
		var pd: Vector3 = (here * PlanetConst.RADIUS_M + (n * cos(ang) + e2 * sin(ang)) * rng.randf_range(5.0, 60.0)).normalized()
		player.global_position = world.to_scene(pd, PlanetConst.RADIUS_M + main.chunks.ground_height(pd) + 0.05)
		player.velocity = Vector3.ZERO
		player._move = Vector3.ZERO
		for turn in 8:
			player._heading = CubeSphere.north(pd).rotated(world.dir_of(player.global_position), TAU * turn / 8.0)
			player._yaw = 0.0
			player.set_view(-0.75, 0.0)
			await frames(12)
			var idx: int = main._sample_in_reach()
			if idx < 0 or seen.has(idx):
				continue
			var n0 := inv.count()
			act("interact")
			await frames(2)
			if inv.count() == n0 + 1:
				seen[idx] = true
				taken += 1
				var last = null
				for it in inv.carried:
					if it != null:
						last = it
				names.append("%s: %s (%s), looking at %s" % [Inventory.title(last), last.binomial, last.shape, look.text])
			break
	print("samples taken with E:")
	for n in names:
		print("   " + n)
	ok(taken >= 3, "E on a plant took a sample (%d plants)" % taken)
	var s0 = inv.carried[0]
	ok(s0 != null and str(s0.get("binomial", "")) != "" and s0.has("color") and s0.has("species"), "a sample carries its species' binomial and look")

	# Overburden: past six carried things, slower, slower climbing, louder.
	while inv.count() < 6:
		inv.add(Inventory.make("mushroom"))
	var sp6 := player.burden_speed()
	var cl6 := player.burden_climb()
	var no6 := player.burden_noise()
	while inv.count() < 9:
		inv.add(Inventory.make("fish"))
	var sp9 := player.burden_speed()
	var cl9 := player.burden_climb()
	var no9 := player.burden_noise()
	print("carrying 6: speed x%.2f, climbing x%.2f, noise x%.2f; carrying 9: speed x%.2f, climbing x%.2f, noise x%.2f" % [sp6, cl6, no6, sp9, cl9, no9])
	ok(sp6 == 1.0 and cl6 == 1.0 and no6 == 1.0, "six things carried: no burden")
	ok(sp9 < 1.0 and cl9 < 1.0 and no9 > 1.0, "nine things: slower, climbs slower, louder")
	# Walk speed laden, on the ground.
	var fwd := CubeSphere.north(player.surface_dir)
	player._heading = fwd
	player.set_view(0.0, 0.0)
	Input.action_press("move_forward")
	await frames(60)
	var laden := player._move.length()
	print("   (on the floor: %s)" % player.is_on_floor())
	Input.action_release("move_forward")
	await frames(30)
	print("walking laden with 9: %.2f m/s (5.5 unladen)" % laden)
	ok(absf(laden - 5.5 * sp9) < 0.2, "the walk is slower laden")

	# The screen: I opens it, the world goes on.
	act("inventory")
	await frames(2)
	ok(main.inventory_screen.visible and player.ui_open, "I opens the inventory")
	ok(not paused, "the world isn't paused")
	var t0: float = world.days
	await frames(30)
	ok(world.days > t0, "time goes on while it's open")
	# Choose a carried thing, set it down (G), take it back (E).
	main.inventory_screen.chosen = ["carried", 0]
	var n_before := inv.count()
	act("inventory_drop")
	await frames(2)
	ok(inv.count() == n_before - 1 and WorldItem.lying.size() == 1, "G set the chosen thing down on the ground")
	var lying: WorldItem = WorldItem.lying[0]
	# Screenshot while open (with a display).
	main.inventory_screen.chosen = ["carried", 1]
	await frames(10)
	if OS.get_environment("OUT") != "":
		await process_frame
		await process_frame
		get_root().get_texture().get_image().save_png(OS.get_environment("OUT"))
		print("saved " + OS.get_environment("OUT"))
	act("inventory")
	await frames(2)
	ok(not main.inventory_screen.visible and not player.ui_open, "I closes it")
	player.velocity = Vector3.ZERO
	var lp := lying.global_position
	var ld: Vector3 = world.dir_of(lp)
	player.global_position = world.to_scene(ld, PlanetConst.RADIUS_M + main.chunks.ground_height(ld) + 0.05) + CubeSphere.north(ld) * 0.6
	await frames(3)
	act("interact")
	await frames(2)
	ok(inv.count() == n_before and WorldItem.lying.is_empty(), "E took it back")
	# Full hands.
	while inv.add(Inventory.make("mushroom")):
		pass
	ok(inv.count() == 10 and not inv.add(Inventory.make("fish")), "ten things and your hands are full")
	print("RESULT fails: %d" % fails)
	quit()
