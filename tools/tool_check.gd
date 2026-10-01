extends SceneTree
## Waking, the tools and bare hands (Mike, 29 Sept 2026; design §M, §N,
## §T): you wake empty-handed, the folk's gifts (the bow and the spear)
## lying by you; right click takes each (the first into your empty hand);
## Q brings them to hand in turn, and bare hands; with nothing in hand,
## left click jabs and a held click winds up a haymaker; a timed roll takes
## a high fall with no damage; after a death you wake empty-handed again
## with a new set of gifts by you, and right click by your body takes the
## rest back (its tools you have again are left with it).
##
##   godot --headless --path . --fixed-fps 60 --script tools/tool_check.gd

var main
var world
var player: PlanetPlayer
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func act(a: String) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = true
	player._unhandled_input(e)


func interact() -> void:
	var e := InputEventAction.new()
	e.action = "interact"
	e.pressed = true
	main._unhandled_input(e)


## Hold the charge button `seconds`, then let go.
func hold_shoot(seconds: float) -> void:
	Input.action_press("shoot")
	await frames(maxi(1, roundi(seconds * 60.0)))
	Input.action_release("shoot")
	await frames(1)


func alt() -> float:
	return world.radius_of(player.global_position) - PlanetConst.RADIUS_M - main.chunks.ground_height(player.surface_dir)


func _initialize() -> void:
	world = get_root().get_node("World")
	world.pin(42, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(120)
	var inv := player.inventory
	ok(not player.wears("ranged", "bow") and not player.wears("melee", "spear") and player.in_hand() == "hands", "you wake empty-handed")
	var gifts: Array = []
	for w in WorldItem.lying:
		if is_instance_valid(w) and w.gift and w.global_position.distance_to(player.global_position) < 3.0:
			gifts.append(w)
	var kinds := []
	for g in gifts:
		kinds.append(str(g.item.kind))
	kinds.sort()
	print("      by you: %s" % str(kinds))
	ok(kinds == ["bow", "spear"], "a bow and a spear lie by you, the folk's gifts")
	# Take them: stand among them and right click, once for each (each
	# press takes the nearest).
	var mid := Vector3.ZERO
	for g in gifts:
		mid += (g as WorldItem).global_position / gifts.size()
	player.global_position = mid + player.up * 0.05
	player.velocity = Vector3.ZERO
	await frames(10)
	var first := ""
	for k in 2:
		var before := player.weapon
		interact()
		await frames(3)
		if first == "" and before == "hands" and player.weapon != "hands":
			first = player.weapon
	ok(player.wears("ranged", "bow") and player.wears("melee", "spear") and inv.count() == 0, "right click takes each one up, worn in its slot")
	ok(player.in_hand() != "hands", "the first taken goes into your empty hand (%s: %s)" % [first, player.weapon])
	player.weapon = "bow"
	var order := [player.weapon]
	for i in 3:
		act("weapon_swap")
		order.append(player.weapon)
	print("      Q: %s" % " -> ".join(order))
	ok(order == ["bow", "spear", "hands", "bow"], "Q cycles bow, spear, bare hands, and round again")

	# --- Bare hands ----------------------------------------------------------
	player.weapon = "hands"
	await frames(5)
	var fists := player.fists
	var b0 := fists.blows
	await hold_shoot(0.08)
	await frames(20)
	ok(fists.blows == b0 + 1 and not fists.winding, "bare hands: a tap jabs")
	Input.action_press("shoot")
	await frames(40)
	var pw := fists.power()
	var wound := fists.winding and pw > 0.5
	Input.action_release("shoot")
	await frames(2)
	ok(wound and fists.blows == b0 + 2, "a held click winds up a haymaker and throws it (power %.2f)" % pw)
	main.hud.update_status(player)
	ok(main.hud._status.weapon == "Bare hands", "the HUD says \"%s\"" % main.hud._status.weapon)

	# --- A high fall, rolled -----------------------------------------------
	var rolled := []
	for timed in [false, true]:
		player.hp = PlanetPlayer.MAX_HP
		player._invulnerable = 0.0
		var d: Vector3 = player.surface_dir
		player.global_position = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d) + 13.0)
		player._move = CubeSphere.north(d) * 5.5
		player.velocity = player._move
		player._jumped = true
		player._was_on_floor = false
		player._fall_top = -INF
		var r0 := player.rolls
		var n := 0
		while alt() > 1.0 and n < 300:
			await frames(1)
			n += 1
		if timed:
			Input.action_press("crouch")
			await frames(1)
			Input.action_release("crouch")
		var n2 := 0
		while not player.is_on_floor() and n2 < 60:
			await frames(1)
			n2 += 1
		await frames(20)
		rolled.append([player.rolls - r0, PlanetPlayer.MAX_HP - player.hp])
		print("      13 m fall, Shift %s: rolled %d, lost %.0f health" % ["just before landing" if timed else "never", player.rolls - r0, PlanetPlayer.MAX_HP - player.hp])
		await frames(30)
	ok(rolled[0][0] == 0 and rolled[0][1] > 30.0, "a 13 m fall without the roll hurts (%.0f)" % rolled[0][1])
	ok(rolled[1][0] == 1 and rolled[1][1] < 0.5, "Shift timed as you land rolls it off: no damage")
	player.hp = PlanetPlayer.MAX_HP

	# --- Death: empty-handed, new gifts ----------------------------------
	player.weapon = "spear"
	inv.add(Inventory.make("fish"))
	player._invulnerable = 0.0
	player._damage(500.0)
	var nd := 0
	while (player.dead or player._wake_t > 0.0) and nd < 1500:
		await frames(1)
		nd += 1
	await frames(30)
	var corpse: PlayerCorpse = PlayerCorpse.lying[0] if not PlayerCorpse.lying.is_empty() else null
	print("      woke: bow %s, spear %s, in hand %s, carrying %d" % [player.wears("ranged", "bow"), player.wears("melee", "spear"), player.in_hand(), inv.count()])
	ok(not player.wears("ranged", "bow") and not player.wears("melee", "spear") and inv.count() == 0 and player.in_hand() == "hands", "after a death you wake empty-handed")
	var new_gifts := 0
	for w in WorldItem.lying:
		if is_instance_valid(w) and w.gift and w.global_position.distance_to(player.global_position) < 3.0:
			new_gifts += 1
	ok(new_gifts == 2, "and the folk have left the two tools by you again")
	ok(corpse != null and corpse.worn["melee"][0] != null and corpse.carried.any(func(x) -> bool: return x != null), "your tools and what you carried wait on your body")
	main.take_gifts()
	if corpse != null:
		var cd: Vector3 = world.dir_of(corpse.global_position)
		var offset: Vector3 = world.to_scene(cd, PlanetConst.RADIUS_M + world.surface_elevation(cd))
		world.rebase(offset)
		player.global_position -= offset
		main.chunks.load_blocking(cd)
		player.spawn_at(cd)
		await frames(120)
		player.global_position = corpse.global_position + CubeSphere.north(cd) * 0.8
		await frames(5)
		interact()
		await frames(3)
		ok(inv.count() == 1 and player.wears("melee", "spear") and player.wears("ranged", "bow"), "right click by the body takes the fish back")
		ok(PlayerCorpse.lying.is_empty(), "and the body is gone (its tools you had again stay with it: two tools, never more)")
	print("RESULT fails: %d" % fails)
	quit()
