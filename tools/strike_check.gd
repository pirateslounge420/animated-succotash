extends "res://tools/tech_check.gd"
## Momentum in combat (design §K; combat.json "strike", overcharge.spear):
##   - a spear thrust deals more the faster you close on the target, on the
##     impact curve (nothing under safe_mps, per_mps over it);
##   - closing at kill_mps or more kills anything not a mythic;
##   - a thrust into a trunk at speed is an impact on you;
##   - a super-thrown spear kills what it meets and pins it.
##
##   ~/bin/godot --headless --path . --fixed-fps 60 --script tools/strike_check.gd


func aim_at(p: Vector3) -> void:
	for i in 3:
		var to := (p - player.camera().global_position).normalized()
		player._heading = (to - player.up * to.dot(player.up)).normalized()
		player._yaw = 0.0
		player.set_view(asin(clampf(to.dot(player.up), -1.0, 1.0)), 0.0)
		await frames(1)


## A still deer `dist` m ahead along `h` (placed, faded in, hitboxes on,
## never ticked).
func deer_at(h: Vector3, dist: float) -> Creature:
	var sp: CreatureSpecies = null
	for s in CreatureSpecies.all():
		if s.name == "Deer":
			sp = s
	var deer := Creature.new()
	world.world_root.add_child(deer)
	deer.setup(sp, world, main.chunks, main.creatures, world.dir_of(player.global_position + h * dist), 7)
	await frames(3)
	deer._fade = 1.0
	deer._hitboxes_near = true
	deer._place(0.6)
	deer.set_visible_body(true)
	await frames(2)
	return deer


## A thrust right now at `speed` m/s along the look: [amount dealt, deer
## dead].
func thrust_at(deer: Creature, speed: float) -> Array:
	await aim_at(deer.global_position + world.dir_of(deer.global_position) * deer.species.size_m * 0.45)
	Hits.clear()
	var look := -player.camera().global_basis.z
	player.velocity = (look - player.up * look.dot(player.up)).normalized() * speed
	player.spear.thrust()
	var e := Hits.last()
	return [float(e.get("amount", 0.0)), deer.dead]


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
	var camp_d: Vector3 = player.surface_dir
	var s: Dictionary = Hits.data().strike
	var safe := float(s.safe_mps)
	var kill := float(s.kill_mps)

	# --- The curve ---------------------------------------------------------
	ok(Hits.strike_bonus(safe) == 0.0 and absf(Hits.strike_bonus(safe + 10.0) - 10.0 * float(s.per_mps)) < 1e-4, "nothing under safe_mps, per_mps over it")
	var myth: CreatureSpecies = null
	for sp in CreatureSpecies.all():
		if sp.role == "mythical":
			myth = sp
			break
	var fake := Creature.new()
	fake.species = myth
	ok(myth != null and Hits.mythic(fake) and not Hits.strike_kills(kill + 10.0, fake), "a mythic is never killed by momentum alone (%s)" % (myth.name if myth else "-"))
	fake.free()

	# --- Thrusts -----------------------------------------------------------
	player.weapon = "spear"
	var h := CubeSphere.north(player.surface_dir)
	var d1 := await deer_at(h, 1.6)
	var slow: Array = await thrust_at(d1, 0.0)
	d1.hp = d1.species.hp_max()
	var fast: Array = await thrust_at(d1, safe + 8.0)
	print("[strike] standing thrust %.1f; at %.0f m/s closing %.1f (closing %.1f m/s)" % [slow[0], safe + 8.0, fast[0], player.spear.last_closing])
	ok(slow[0] > 0.0 and fast[0] > slow[0] * 1.5, "closing speed adds damage (%.1f -> %.1f)" % [slow[0], fast[0]])
	d1.queue_free()
	await frames(3)
	var d3 := await deer_at(h, 1.6)
	var lethal: Array = await thrust_at(d3, kill + 1.0)
	print("[strike] at %.0f m/s: %.1f, dead %s" % [kill + 1.0, lethal[0], lethal[1]])
	ok(lethal[1], "a thrust closing at kill_mps (%.0f) kills a deer" % kill)
	d3.queue_free()
	await frames(5)

	# --- Into a trunk: it cuts both ways -----------------------------------
	var g := trunk_near(player.global_position)
	var base := g.base()
	var gd: Vector3 = world.dir_of(base)
	var out := CubeSphere.north(gd)
	var r0: float = g.radius[g.nearest(base + gd * 1.3)]
	await settle(world.dir_of(base + out * (r0 + 0.9)))
	base = g.base()
	await aim_at(base + world.dir_of(base) * 1.3)
	var hp0 := player.hp
	var imp0 := player.impacts
	var into := safe + 6.0
	var look := -player.camera().global_basis.z
	player.velocity = (look - player.up * look.dot(player.up)).normalized() * into
	player._move = player.velocity
	player.spear.thrust()
	var want := (player.spear.last_closing - PlanetPlayer.IMPACT_SAFE) * PlanetPlayer.IMPACT_PER
	print("[strike] thrust into a trunk closing %.1f m/s: hp %.1f -> %.1f (the impact curve says -%.1f)" % [player.spear.last_closing, hp0, player.hp, want])
	ok(player.impacts == imp0 + 1 and hp0 - player.hp > 1.0 and absf((hp0 - player.hp) - want) < 0.5, "a thrust into a trunk at speed is an impact on you")
	await settle(camp_d)
	player.hp = PlanetPlayer.MAX_HP

	# --- The super throw: impact kill and pin ------------------------------
	h = CubeSphere.north(player.surface_dir)
	var d2 := await deer_at(h, 7.0)
	await aim_at(d2.global_position + world.dir_of(d2.global_position) * d2.species.size_m * 0.45)
	player.meter.value = 0.5
	var sextra := float(SuperMeter.overcharge("spear").get("extra_s", 1.0))
	await press("shoot")
	for i in int((Spear.RAISE_S + sextra + Spear.TAP_S + 0.2) * 60.0):
		await aim_at(d2.global_position + world.dir_of(d2.global_position) * d2.species.size_m * 0.45)
	await release("shoot")
	var thrown: ThrownSpear = null
	for i in 60:
		await frames(1)
		thrown = player.spear.thrown
		if thrown != null and thrown.landed:
			break
	await frames(2)
	print("[strike] super throw: deer dead %s, spear in it %s, pinning %s, pinned_t %.2f" % [d2.dead, thrown != null and thrown.host == d2, thrown.pinning if thrown else false, d2.pinned_t])
	ok(d2.dead, "a super-thrown spear kills a deer outright (impact_kill)")
	ok(thrown != null and thrown.host == d2 and thrown.pinning and d2.pinned_t > 0.0, "and the shaft pins it")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
