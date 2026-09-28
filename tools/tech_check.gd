extends SceneTree
## Run: godot --headless --path . --fixed-fps 60 --script tools/tech_check.gd
## Headless checks for the design reconciliation's Phase 1 moves: the
## right-click tech (wall-jump tap, cling, chain gain, the frame window),
## the landing roll, impact damage, catch-and-swing on branches, bamboo
## and vines (break, flex, snapback, unlimited hang), dead wood, death
## (the corpse, waking at a fire, getting your things back) and the fire
## safe zone.
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

## As a real key press arrives (after the process frame).
func press(a: String) -> void:
	await process_frame
	Input.action_press(a)

func release(a: String) -> void:
	await process_frame
	Input.action_release(a)

func release_all() -> void:
	await process_frame
	for a in ["move_forward", "move_back", "jump", "crouch", "shoot", "wall_jump"]:
		Input.action_release(a)

func alt() -> float:
	return world.radius_of(player.global_position) - PlanetConst.RADIUS_M - main.chunks.ground_height(player.surface_dir)

func settle(d: Vector3) -> void:
	await release_all()
	player.global_position = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d) + 0.05)
	player.velocity = Vector3.ZERO
	player._move = Vector3.ZERO
	player.hp = PlanetPlayer.MAX_HP
	await frames(30)

## Travel there (far): the floating origin moves and chunks load.
func goto(d: Vector3) -> void:
	var offset: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(offset)
	player.global_position -= offset
	main.chunks.load_blocking(d)
	player.spawn_at(d)
	await frames(240)

## The nearest trunk graph with a low handhold near `here`.
func trunk_near(here: Vector3) -> BranchGraph:
	var g: BranchGraph = null
	for gg: BranchGraph in BranchGraphs.all():
		if gg.valid() and gg.base().distance_to(here) < 120.0 and (g == null or gg.base().distance_to(here) < g.base().distance_to(here)):
			for i in gg.size():
				if gg.limb[i] == 0 and gg.radius[i] >= 0.25 and gg.local[i].y < 1.5:
					g = gg
					break
	return g

## Put the player in the air beside a trunk, moving into it at `speed`.
func fly_at_trunk(g: BranchGraph, speed: float, height: float) -> Vector3:
	var base := g.base()
	var gd: Vector3 = world.dir_of(base)
	var out := CubeSphere.north(gd)
	var r0: float = g.radius[g.nearest(base + gd * 1.0)]
	var pd: Vector3 = world.dir_of(base + out * (r0 + 0.9))
	player.global_position = world.to_scene(pd, PlanetConst.RADIUS_M + main.chunks.ground_height(pd) + height)
	player._heading = -out
	player._yaw = 0.0
	player._move = -out * speed
	player._takeoff = player._move
	player._jumped = true
	player._was_on_floor = false
	player.velocity = player._move + player.up * 1.0
	player._wall_f = 9999
	return out

func wait_contact() -> int:
	var n := 0
	while player._wall_f > 0 and n < 60:
		await frames(1)
		n += 1
	return n

func _initialize() -> void:
	world = get_root().get_node("World")
	world.spawn_choice = 0
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(90)
	var camp_d: Vector3 = player.surface_dir
	if OS.get_environment("ONLY") == "rain":
		await rain(camp_d)
		print("RESULT fails: %d" % fails)
		quit()
		return
	ok(Engine.physics_ticks_per_second == 60 and Engine.max_fps == 60, "locked at 60 fps, physics 60 Hz (max_fps %d)" % Engine.max_fps)

	# --- Wall jump: tap, chain gain -------------------------------------
	var g := trunk_near(player.global_position)
	if g == null:
		ok(false, "a trunk near the camp")
		print("RESULT fails: %d" % fails)
		quit()
		return
	var out := fly_at_trunk(g, 6.0, 1.3)
	await wait_contact()
	await press("wall_jump")
	await frames(2)
	await release("wall_jump")
	await frames(2)
	var v1 := player.velocity
	var up1 := v1.dot(player.up)
	var away1 := (v1 - player.up * up1).dot(out)
	var wj1 := player.wall_jumps
	# Chained: back at the trunk before landing (no ground between), tap again.
	var chain := player._wj_chain
	fly_at_trunk(g, 6.0, 1.3)
	player._wj_chain = chain
	await wait_contact()
	await press("wall_jump")
	await frames(2)
	await release("wall_jump")
	await frames(2)
	var up2 := player.velocity.dot(player.up)
	print("tap wall jump: away %.1f m/s, up %.1f m/s; chained: up %.1f m/s (x%.2f)" % [away1, up1, up2, up2 / maxf(up1, 0.01)])
	ok(wj1 >= 1 and away1 > 2.0 and up1 > 4.0, "a tap on the trunk kicks off it")
	ok(player.wall_jumps == wj1 + 1 and up2 >= up1 * 0.99, "a chained wall jump keeps or builds speed (gain %.2f)" % PlanetPlayer.WJ_GAIN)
	await settle(camp_d)

	# --- Frame window: too late, nothing ---------------------------------
	g = trunk_near(player.global_position)
	fly_at_trunk(g, 6.0, 1.3)
	await wait_contact()
	await frames(PlanetPlayer.WJ_WINDOW_F + 3)
	var c0 := player.clings
	var w0 := player.wall_jumps
	await press("wall_jump")
	await frames(2)
	await release("wall_jump")
	await frames(2)
	ok(player.clings == c0 and player.wall_jumps == w0, "pressed %d frames after touching: too late, no wall jump (window %d frames)" % [PlanetPlayer.WJ_WINDOW_F + 3, PlanetPlayer.WJ_WINDOW_F])
	await settle(camp_d)

	# --- Cling: hold; letting go springs you off (weaker than a perfect
	# tap, and the chain starts over) -------------------------------------
	g = trunk_near(player.global_position)
	fly_at_trunk(g, 6.0, 3.0)
	await wait_contact()
	await press("wall_jump")
	await frames(3)
	var p0 := player.global_position
	await frames(60)
	var held_m := player.global_position.distance_to(p0)
	var clung := player.clinging
	print("cling: held 1 s, moved %.2f m" % held_m)
	ok(clung and held_m < 0.8, "holding right click on the trunk clings")
	await release("wall_jump")
	await frames(2)
	var vj := player.velocity.length()
	print("let go of a cling: %.1f m/s (a tap kick is %.1f m/s)" % [vj, PlanetPlayer.WJ_SPEED])
	ok(not player.clinging and vj > PlanetPlayer.WJ_SPEED * 0.7 and vj < PlanetPlayer.WJ_SPEED * 0.99 and player._wj_chain == 0, "letting go of a cling springs you off (a bit less than a tap) and starts the chain over")
	await settle(camp_d)
	g = trunk_near(player.global_position)
	fly_at_trunk(g, 6.0, 3.0)
	await wait_contact()
	await press("wall_jump")
	var t_cling := 0
	await frames(3)
	while player.clinging and t_cling < 400:
		await frames(1)
		t_cling += 1
	await release("wall_jump")
	print("cling lasted %.2f s before sliding off (cling_hold_s %.1f)" % [t_cling / 60.0, PlanetPlayer.CLING_S])
	ok(absf(t_cling / 60.0 - PlanetPlayer.CLING_S) < 0.3 or t_cling < 400, "the cling wears out and you slide off")
	await settle(camp_d)

	# --- Landing roll ------------------------------------------------------
	var rolls := []
	for mode in ["none", "early", "late"]:
		await settle(camp_d)
		var hp0 := player.hp
		var d: Vector3 = player.surface_dir
		player.global_position = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d) + 10.0)
		player._move = CubeSphere.north(d) * 5.5
		player.velocity = player._move
		player._jumped = true
		player._was_on_floor = false
		player._fall_top = -INF
		var r0 := player.rolls
		var n := 0
		while alt() > 0.6 and n < 200:
			await frames(1)
			n += 1
		if mode == "early":
			await press("crouch")
			await frames(1)
			await release("crouch")
		var n2 := 0
		while not player.is_on_floor() and n2 < 60:
			await frames(1)
			n2 += 1
		if mode == "late":
			await frames(1)
			await press("crouch")
			await frames(1)
			await release("crouch")
		var hspeed := 0.0
		for q in 8:
			await frames(1)
			hspeed = maxf(hspeed, (player._move - player.up * player._move.dot(player.up)).length())
		rolls.append([mode, player.rolls - r0, hp0 - player.hp, hspeed])
		print("10 m drop, crouch %s: rolled %d, lost %.0f health, going %.1f m/s after" % [mode, player.rolls - r0, hp0 - player.hp, hspeed])
		await frames(40)
	ok(rolls[0][1] == 0 and rolls[0][2] > 20.0, "no roll: the squat and full fall damage")
	ok(rolls[1][1] == 1 and rolls[1][2] < 0.5 and rolls[1][3] > 12.0, "crouch just before touchdown rolls: no damage, the fall turned into speed")
	ok(rolls[2][1] == 1 and rolls[2][2] < 0.5, "crouch just after touchdown rolls too")

	# --- Impact ------------------------------------------------------------
	for tech in [false, true]:
		await settle(camp_d)
		g = trunk_near(player.global_position)
		var hp0 := player.hp
		fly_at_trunk(g, 22.0, 1.5)
		await wait_contact()
		if tech:
			await press("wall_jump")
			await frames(2)
			await release("wall_jump")
		await frames(20)
		print("into a trunk at 22 m/s, %s: lost %.0f health" % ["tapped" if tech else "no tech", hp0 - player.hp])
		if tech:
			ok(hp0 - player.hp < 0.5, "a tech on contact saves you")
		else:
			ok(hp0 - player.hp > 30.0, "hitting a trunk at speed without a tech hurts")

	# --- Fire safe zone ----------------------------------------------------
	await settle(camp_d)
	var fire: Vector3 = main.camp.global_position if main.camp is Node3D else player.global_position
	var near_fire: bool = Campfire.lit_near(self, player.global_position, Tuning.num("combat", "death", "fire_safe_m"))
	var hp_f := player.hp
	player._invulnerable = 0.0
	main.creatures.player_hit(20.0, player.global_position + Vector3(1, 0, 0))
	await frames(2)
	print("at the camp: by a lit fire %s, a bite did %.0f" % [near_fire, hp_f - player.hp])
	ok(not near_fire or hp_f - player.hp < 0.5, "by a lit fire nothing hostile hurts you")

	await rain(camp_d)

	# --- Death: the corpse, waking at a fire, taking your things back -----
	await settle(player.surface_dir)
	player.inventory.add(Inventory.make("fish"))
	var death_pos := player.global_position
	player._invulnerable = 0.0
	player._damage(500.0)
	var n3 := 0
	while (player.dead or player._wake_t > 0.0) and n3 < 1200:
		await frames(1)
		n3 += 1
	await frames(30)
	var corpse: PlayerCorpse = PlayerCorpse.lying[0] if not PlayerCorpse.lying.is_empty() else null
	var woke_d := CubeSphere.surface_distance_m(world.dir_of(player.global_position), world.dir_of(corpse.global_position)) if corpse else -1.0
	var by_fire: bool = Campfire.lit_near(self, player.global_position, 12.0)
	print("died; woke %.0f m from the body, by a lit fire: %s; health %.0f; carrying %d, bow worn %s" % [woke_d, by_fire, player.hp, player.inventory.count(), player.wears("ranged", "bow")])
	ok(corpse != null and corpse.carried.any(func(x) -> bool: return x != null) and corpse.worn["ranged"][0] != null, "the body stays where you fell with your gear")
	ok(player.hp == PlanetPlayer.MAX_HP and player.inventory.count() == 0 and not player.wears("ranged", "bow"), "you wake with full health and nothing")
	ok(by_fire, "you wake by a camp fire")
	if corpse != null:
		# Walk back (teleport) and take it all.
		var cd: Vector3 = world.dir_of(corpse.global_position)
		await goto(cd)
		player.global_position = corpse.global_position + CubeSphere.north(cd) * 0.8
		await frames(5)
		var e := InputEventAction.new()
		e.action = "interact"
		e.pressed = true
		main._unhandled_input(e)
		await frames(3)
		ok(player.wears("ranged", "bow") and player.wears("melee", "spear") and player.inventory.count() == 1 and PlayerCorpse.lying.is_empty(), "E by the body takes your things back, and it's gone")
	print("RESULT fails: %d" % fails)
	quit()


## The rainforest: vines, catching a branch or vine and hanging on it,
## dead wood and bamboo as handholds.
func rain(camp_d: Vector3) -> void:
	var spot := find_rainforest(camp_d)
	if spot == Vector3.ZERO:
		ok(false, "a rainforest on the stamp")
	else:
		await goto(spot)
		await frames(120)
		var vines := 0
		var vine_graphs := 0
		var bamboo := 0
		var dead := 0
		var total := 0
		for gg: BranchGraph in BranchGraphs.all():
			if not gg.valid():
				continue
			total += 1
			var has := false
			for i in gg.size():
				if gg.is_vine(i):
					vines += 1
					has = true
			if has:
				vine_graphs += 1
			if SpeciesDB.all()[gg.species].shape == PlantSpecies.Shape.BAMBOO:
				bamboo += 1
			if gg.dead:
				dead += 1
		print("rainforest: %d trees with graphs, %d hung with vines (%d vine handholds), %d bamboo, %d dead" % [total, vine_graphs, vines, bamboo, dead])
		ok(vine_graphs > 0, "vines hang in the rainforest")
		# Catch a limb or vine: place the player below-behind it, flying.
		# The first candidate whose starting spot is clear (nothing else in
		# the way of the approach: which trees stand where depends on the
		# climate and soil).
		var target := []
		for gg: BranchGraph in BranchGraphs.all():
			if not gg.valid():
				continue
			for i in gg.size():
				var off_axis := Vector2(gg.local[i].x, gg.local[i].z).length()
				if (gg.is_vine(i) or (gg.limb[i] > 0 and gg.radius[i] < 0.2 and gg.radius[i] > 0.05)) and gg.local[i].y > 4.0 and gg.local[i].y < 12.0 and off_axis > 1.8:
					var hp0 := gg.pos(i)
					var hd0: Vector3 = world.dir_of(hp0)
					var fw0 := hp0 - gg.base()
					fw0 = (fw0 - hd0 * fw0.dot(hd0)).normalized()
					var at := Transform3D(player.global_basis, hp0 - hd0 * 1.9 - fw0 * 0.6)
					if player.test_move(at, fw0 * 0.3) or player.test_move(at, hd0 * 0.3):
						continue
					target = [gg, i]
					break
			if not target.is_empty():
				break
		if target.is_empty():
			ok(false, "a branch or vine to catch")
		else:
			var tg: BranchGraph = target[0]
			var hp := tg.pos(target[1])
			var hd: Vector3 = world.dir_of(hp)
			# Fly outward from the trunk, under it.
			var axis_d: Vector3 = world.dir_of(tg.base())
			var fwd := (hp - tg.base())
			fwd = (fwd - hd * fwd.dot(hd)).normalized()
			player.global_position = hp - hd * 1.9 - fwd * 0.6
			player._heading = fwd
			player._yaw = 0.0
			player.velocity = fwd * 7.0
			player._move = fwd * 7.0
			player._jumped = true
			player._was_on_floor = false
			player._wall_f = 9999
			await frames(1)
			var s0 := player.swings
			var sn0 := player.snaps
			print("   before the catch: on floor %s, wall_f %d, speed %.1f, hands %.2f m from it, graph dead %s" % [player.is_on_floor(), player._wall_f, player.velocity.length(), (player.global_position + player.up * 1.6).distance_to(tg.pos(target[1])), tg.dead])
			await press("wall_jump")
			await frames(3)
			var caught := player.swinging
			print("   clings %d" % player.clings)
			print("catch: swinging %s (%s, snapped %d)" % [caught, "a vine" if tg.is_vine(target[1]) else "a limb %.2f m thick" % (tg.radius[target[1]] * 2.0), player.snaps - sn0])
			ok(player.swings > s0 or player.snaps > sn0, "right click by a branch or vine catches it (or it snaps)")
			if caught:
				await frames(300)
				ok(player.swinging, "hang as long as you like: still holding after 5 s")
				await release("wall_jump")
				await frames(2)
				ok(not player.swinging, "let go: you fly on")
		# A dead branch at speed: snaps.
		var dg: BranchGraph = null
		for gg: BranchGraph in BranchGraphs.all():
			if gg.valid() and gg.size() > 3:
				dg = gg
				break
		if dg != null:
			var was := dg.dead
			dg.dead = true
			var k := dg.size() - 1
			var pr := Handholds.props(dg, k)
			var live := Handholds.props(dg, k) if false else {}
			dg.dead = was
			var pr_live := Handholds.props(dg, k)
			print("the same limb alive: breaks at %.1f m/s, flex %.2f, snapback %.2f; dead: %.1f m/s, flex %.2f, snapback %.2f" % [pr_live.break_speed_mps, pr_live.flex, pr_live.snapback, pr.break_speed_mps, pr.flex, pr.snapback])
			ok(pr.break_speed_mps < pr_live.break_speed_mps and pr.snapback <= 0.01, "dead wood is brittle and springs nothing")
		var bam := {}
		for sp: PlantSpecies in SpeciesDB.all():
			if sp.shape == PlantSpecies.Shape.BAMBOO:
				var bgr := BranchGraph.new()
				bgr.species = SpeciesDB.index_of(sp)
				bgr.height_m = 20.0
				bgr.local.append(Vector3.ZERO)
				bgr.radius.append(0.1)
				bgr.limb.append(0)
				bgr.tangent.append(Vector3.UP)
				bgr.links.append(PackedInt32Array())
				bam = Handholds.props(bgr, 0)
				break
		if not bam.is_empty():
			print("green bamboo: breaks at %.0f m/s, flex %.2f, snapback %.2f" % [bam.break_speed_mps, bam.flex, bam.snapback])
			ok(bam.break_speed_mps >= 40.0 and bam.snapback >= 0.8, "green bamboo is a launch: near unbreakable, springy")



func find_rainforest(pd: Vector3) -> Vector3:
	var m: PlanetData = world.planet
	var ids := [BiomeTemplates.id_of_key("TROPICAL_RAINFOREST"), BiomeTemplates.id_of_key("JUNGLE")]
	for r in range(300, 20000, 300):
		for i in 36:
			var q := CreatureSpawner._offset(pd, i * TAU / 36.0, float(r))
			var c: int = m.cell_at(q)
			if m.biome[c] in ids and m.water[c] == PlanetData.Water.NONE and world.surface_elevation(q) > 2.0:
				return q
	return Vector3.ZERO
