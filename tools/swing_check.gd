extends "res://tools/strike_check.gd"
## The swing passes the flame (design 2 Oct §CN), headless, full planet:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/swing_check.gd
## Boots the game at the opening camp, the player live (left click is
## pressed and released as a real click is), and asserts:
##  - an unlit torch swung through the lit camp fire catches, and the fire
##    is no less lit for it;
##  - right click on the fire no longer lights the torch;
##  - a lit torch swung through a laid cold fire lights it, and costs the
##    torch no burn time (only the swing's own fraction of a second);
##  - right click with a lit torch on a laid cold fire doesn't light it;
##  - the swing lights nothing on open ground or in grass, away from any
##    fire (no fire, no torch lying, no wildfire scar), and does nothing
##    to a creature in reach (its health and its place unchanged).


func _initialize() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	WorldSave.read_only = true
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(60)
	var fire := FireStore.nearest(self, player.global_position, 40.0)
	ok(fire != null and FireStore.is_lit(fire), "the opening camp's fire is lit")
	if fire == null:
		_done()
		return
	print("[swing] seed %d · biome %s" % [seed_v, FireStore.biome_key(world, player.surface_dir)])
	# --- An unlit torch at the lit fire ---------------------------------
	player.inventory.add(Inventory.make("torch"))
	player.weapon = "torch"
	await _face_fire(fire)
	await _right_click()
	ok(not player.torch.lit(), "right click on a lit fire no longer lights the torch")
	await _swing()
	ok(player.torch.lit() and player.torch.last_pass == "torch", "an unlit torch swung through the fire catches (%s)" % player.torch.last_pass)
	ok(FireStore.is_lit(fire), "the fire is no less lit for it")
	# --- A lit torch at a laid cold fire ----------------------------------
	_lay_cold(fire)
	await _right_click()
	ok(not FireStore.is_lit(fire), "right click with a lit torch on a laid cold fire doesn't light it (%s)" % FireStore.state_of(fire))
	if not player.torch.in_hand():
		# (The right click planted it, as plain interact does: take it back.)
		await _right_click()
	ok(player.torch.lit(), "the torch back in hand, lit")
	var before := float(player.torch.item().get("burn_left_min", 0.0))
	await _swing()
	var after := float(player.torch.item().get("burn_left_min", 0.0))
	ok(FireStore.is_lit(fire) and player.torch.last_pass.begins_with("fire:ok"), "a lit torch swung through a laid fire lights it (%s, %s)" % [player.torch.last_pass, FireStore.state_of(fire)])
	ok(before - after < 0.02, "sharing the flame costs the torch nothing (%.4f min, the swing's own time)" % (before - after))
	# --- Nothing else -----------------------------------------------------
	var away := CreatureSpawner._offset(player.surface_dir, 1.9, 90.0)
	await goto(away)
	await settle(away)
	ok(FireStore.nearest(self, player.global_position, 10.0) == null, "away from any fire (%s)" % FireStore.biome_key(world, away))
	if not player.torch.lit():
		player.torch.light()
	var n_fires := get_nodes_in_group(Campfire.GROUP).size()
	var n_planted := PlantedTorch.all.size()
	var n_scars := (main.camp_sim.scars as Array).size() if main.camp_sim != null else 0
	await aim_at(player.global_position - player.up * 0.2 - player.global_basis.z * 1.2)
	await _swing()
	ok(player.torch.last_pass == "" and get_nodes_in_group(Campfire.GROUP).size() == n_fires and PlantedTorch.all.size() == n_planted, "a swing at the ground lights nothing (%d fires, %d planted)" % [get_nodes_in_group(Campfire.GROUP).size(), PlantedTorch.all.size()])
	ok(((main.camp_sim.scars as Array).size() if main.camp_sim != null else 0) == n_scars and player.torch.lit(), "no wildfire, and the torch still in hand, lit")
	# A creature in reach.
	var h := -player.global_basis.z
	var deer := await deer_at(h, 1.2)
	var hp0 := deer.hp
	var at0 := deer.global_position
	await aim_at(deer.global_position + player.up * 0.6)
	await _swing()
	ok(deer.hp == hp0 and player.torch.last_pass == "", "a swing at a creature does nothing to it (hp %.2f -> %.2f)" % [hp0, deer.hp])
	ok(deer.global_position.distance_to(at0) < 0.05, "and doesn't knock it back (moved %.3f m)" % deer.global_position.distance_to(at0))
	deer.queue_free()
	_done()


func _done() -> void:
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Stand 1.3 m from the fire, facing it.
func _face_fire(fire: Node3D) -> void:
	var fd: Vector3 = world.dir_of(fire.global_position)
	var stand := CreatureSpawner._offset(fd, 0.4, 1.3)
	await settle(stand)
	await aim_at(fire.global_position + player.up * 0.3)


## A left click, as one arrives: pressed, held a few frames, released,
## then the arc runs out.
func _swing() -> void:
	await press("shoot")
	await frames(4)
	await release("shoot")
	await frames(int(ceil(Fists.STRIKE_S * 60.0)) + 6)


func _right_click() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	main._unhandled_input(ev)
	await frames(2)


## Make the fire a laid cold fire: out, with fuel on it (§CN part 2 adds
## the kindling it needs).
func _lay_cold(fire: Node3D) -> void:
	var st := FireStore.store_of(fire)
	st.units = [["branch", FireStore.burn_min("branch")]]
	st.state = "out"
	FireStore.apply(fire)
