extends SceneTree
## Flowers and fruit on the trees (design §AS, FruitCrop): every fruiting
## species gets its crop; a tree near the camp flowers in its season (buds,
## then open flowers) at real places on its twigs; its pollinators come and
## work the flowers one by one (visits counted); a flower watched through
## to its close without a visit sets nothing; the set ones swell into fruit
## that turns from its unripe to its ripe colour; right click picks one
## (it's in the pack, gone from the tree); later the rest drop (a fall seen
## near) and lie rotting under the tree, and then they're gone.
##
##   godot --headless --path . --fixed-fps 60 --script tools/fruit_check.gd

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


## The day `offset` days into entry `e`'s bloom this year (its window's
## start plus its own place in it).
func bloom_day(fc: FruitCrop, e) -> float:
	var c = e.crop
	var year := DayCycle.year_days()
	var yr := floori((world.days - e.g0) / year)
	return e.g0 + yr * year + e.t_off * maxf(c.win - c.tree_win, 0.0)


func _initialize() -> void:
	world = get_root().get_node("World")
	world.pin(42, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	main.take_gifts()
	await frames(90)
	var fc: FruitCrop = main.fruit_crop
	# --- Every fruiting species, its crop -----------------------------------
	var n := 0
	var bad: Array = []
	for i in SpeciesDB.all().size():
		var sp: PlantSpecies = SpeciesDB.all()[i]
		if sp.fruiting.is_empty():
			continue
		n += 1
		var c := FruitCrop.crop_of(i)
		if c == null or c.win <= 0.0 or c.fruits < 1 or c.flowers <= c.fruits or c.fl_m <= 0.0 or c.fr_m.y < c.fr_m.x or c.p_set <= 0.0 or c.p_set > 1.0:
			bad.append(sp.name)
	ok(n > 400 and bad.is_empty(), "every fruiting species has its crop (%d; wrong: %s)" % [n, str(bad.slice(0, 6))])
	var words := {}
	for nm in ["Crab apple", "Scots pine", "Pecan", "Sycamore", "Date palm", "Saguaro"]:
		var sp2 := SpeciesDB.find(nm)
		if sp2 != null and not sp2.fruiting.is_empty():
			words[nm] = FruitCrop.word_for(sp2, str(sp2.fruiting.get("fruit_kind", "")))
	print("      what E calls them: %s" % str(words))
	# --- A fruiting tree near the camp, animal-pollinated if there is one ---
	fc.update_now()
	var pick = null
	var best := INF
	for key in fc._entries:
		var e = fc._entries[key]
		if e.tree < 0:
			continue
		var score: float = e.dist + (0.0 if not e.crop.guilds.is_empty() else 40.0) + (0.0 if e.crop.drop == "falls" else 20.0)
		if score < best:
			best = score
			pick = e
	if pick == null:
		# Walk to the nearest trees round the camp until one fruits.
		ok(false, "a fruiting tree within %d m of the camp" % int(FruitCrop.TREE_M))
		print("RESULT fails: %d" % fails)
		quit()
		return
	var c0 = pick.crop
	print("      the tree: %s (%s), %.0f m off, %d flowers drawn, pollinated by %s%s, fruit %s (%s), %s" % [c0.sp.name, c0.sp.binomial(), pick.dist, c0.flowers, str(c0.guilds), " and the wind" if c0.abiotic else "", c0.kind, c0.shape, c0.drop])
	# Stand under it.
	var base: Vector3 = pick.chunk.to_global(pick.xf.origin)
	var side := CubeSphere.north(pick.up)
	player.global_position = base + side * 2.5 + pick.up * 0.2
	await frames(30)
	fc.daylight = 1.0
	fc.rain_mm_h = 0.0
	# --- Its bloom ------------------------------------------------------------
	var d0 := bloom_day(fc, pick)
	world.days = d0 + c0.tree_win * 0.5
	fc.update_now()
	var s0: PackedInt32Array = pick.summary
	print("      mid-bloom (day %.1f): buds %d, open %d, withering %d" % [world.days, s0[FruitCrop.Ph.BUD], s0[FruitCrop.Ph.OPEN], s0[FruitCrop.Ph.WITHER]])
	ok(s0[FruitCrop.Ph.OPEN] > 0, "in its season it flowers (%d open)" % s0[FruitCrop.Ph.OPEN])
	ok(pick.sites.size() >= 4, "on %d places on its twigs" % pick.sites.size())
	var crown_ok := true
	for s in pick.sites:
		var above: float = (s - pick.xf.origin).dot(pick.up)
		if above < 0.0 or above > pick.h * 1.3 + 2.0:
			crown_ok = false
	ok(crown_ok, "all of them up in the tree, none under the ground or over the top")
	ok(FruitCrop.describe_tree(pick.chunk, pick.tree) == "in flower", "the HUD says \"%s\"" % FruitCrop.describe_tree(pick.chunk, pick.tree))
	# --- Pollinators ---------------------------------------------------------
	if not c0.guilds.is_empty():
		var v0 := fc.visits_done
		var seen_kinds := {}
		for k in 1800:
			await process_frame
			world.days = d0 + c0.tree_win * 0.5
			for a in fc._agents:
				seen_kinds[a.kind] = true
			if fc.visits_done > v0 + 3:
				break
		print("      pollinators: %s, %d visits in %.0f s" % [str(seen_kinds.keys()), fc.visits_done - v0, 30.0])
		ok(not seen_kinds.is_empty(), "its pollinators come to the open flowers (%s)" % str(seen_kinds.keys()))
		ok(fc.visits_done > v0, "and visit them one by one (%d visits)" % (fc.visits_done - v0))
	# --- Fate: a visited flower may set; one watched to its close unvisited
	# doesn't -------------------------------------------------------------------
	var year := DayCycle.year_days()
	var yr := floori((world.days - pick.g0) / year)
	var kc_visited := -1
	var kc_watched := -1
	var tw_off: float = pick.t_off * maxf(c0.win - c0.tree_win, 0.0)
	for s in pick.sites.size():
		var kc: int = pick.skey[s] + yr * 1000003
		if fc._visits.has(kc) and kc_visited < 0:
			kc_visited = kc
		elif not fc._visits.has(kc) and kc_watched < 0:
			kc_watched = kc
	if kc_watched >= 0:
		fc._open_seen[kc_watched] = 1e9 # watched right to its close
		var f_unvisited: bool = fc._fate_of(c0, kc_watched, 0.0, 1.0, 0.0)
		ok(not f_unvisited or c0.abiotic, "a flower watched to its close with no visit sets no fruit%s" % (" (the wind's share aside)" if c0.abiotic else ""))
	# --- Fruit ---------------------------------------------------------------------
	world.days = d0 + c0.tree_win + c0.open_d * 1.3 + (c0.ripen.x + c0.ripen.y) * 0.25
	fc.update_now()
	var s1: PackedInt32Array = pick.summary
	print("      ripening (day %.1f): unripe %d, ripe %d" % [world.days, s1[FruitCrop.Ph.FRUIT], s1[FruitCrop.Ph.RIPE]])
	ok(s1[FruitCrop.Ph.FRUIT] + s1[FruitCrop.Ph.RIPE] > 0, "the set flowers swell into fruit")
	world.days = d0 + c0.tree_win + c0.open_d * 1.3 + c0.ripen.y + c0.hang.x * 0.5
	fc.update_now()
	var s2: PackedInt32Array = pick.summary
	print("      ripe (day %.1f): unripe %d, ripe %d, split %d, dry %d, fallen %d" % [world.days, s2[FruitCrop.Ph.FRUIT], s2[FruitCrop.Ph.RIPE], s2[FruitCrop.Ph.SPLIT], s2[FruitCrop.Ph.DRY], s2[FruitCrop.Ph.GROUND]])
	ok(s2[FruitCrop.Ph.RIPE] + s2[FruitCrop.Ph.SPLIT] + s2[FruitCrop.Ph.DRY] > 0, "and ripen on the tree")
	# --- Picking -------------------------------------------------------------------
	var target: Array = []
	for p in fc._pickable:
		if int(p[4]) == pick.key and str(p[5]) in ["ripe", "split", "dry", "unripe"]:
			target = p
			break
	if target.is_empty():
		# Bring one within reach: a fruit anywhere on the tree.
		for p2 in fc._pickable:
			if int(p2[4]) == pick.key:
				target = p2
				break
	if target.is_empty():
		ok(false, "a fruit within reach to pick")
	else:
		var at: Vector3 = (target[0] as TerrainChunk).to_global(target[1])
		var hand: Vector3 = at - player.global_basis.z * 0.0
		var from: Vector3 = at + pick.up * 0.3 + side * 1.0
		var dir: Vector3 = (at - from).normalized()
		var info: Dictionary = fc.fruit_at(from, dir, at, FruitCrop.PICK_M)
		ok(not info.is_empty(), "a fruit on the look ray within reach is found (%s)" % FruitCrop.prompt_for(info) if not info.is_empty() else "a fruit on the look ray within reach is found")
		if not info.is_empty():
			var it := FruitCrop.item_for(info)
			var took: bool = player.inventory.add(it)
			fc.take(info)
			fc.update_now()
			var again: Dictionary = fc.fruit_at(from, dir, at, FruitCrop.PICK_M)
			ok(took and str(it.get("kind", "")) == "fruit" and Inventory.title(it) != "", "picked: \"%s\" in the pack" % Inventory.title(it))
			ok(again.is_empty() or int(again.kc) != int(info.kc), "and gone from the tree")
	# --- The drop and the rot ---------------------------------------------------------
	if c0.drop != "shatters":
		# Just before the first ones drop, then just after: seen to fall.
		world.days = d0 + c0.tree_win * 0.5 + c0.open_d + c0.ripen.x + c0.hang.x * 0.95
		fc.update_now()
		var f0 := fc._falls.size()
		var dropped := false
		for k in 60:
			world.days += c0.hang.y / 60.0
			fc.update_now()
			if fc._falls.size() > f0 or (pick.summary as PackedInt32Array)[FruitCrop.Ph.GROUND] > 0:
				dropped = true
				break
		ok(dropped, "ripe fruit comes down (%d seen falling)" % fc._falls.size())
		await frames(300)
		world.days = d0 + c0.tree_win + c0.open_d * 1.3 + c0.ripen.y + c0.hang.y + c0.rot.x * 0.5
		fc.update_now()
		var s3: PackedInt32Array = pick.summary
		print("      on the ground (day %.1f): %d lying" % [world.days, s3[FruitCrop.Ph.GROUND]])
		ok(s3[FruitCrop.Ph.GROUND] > 0, "and lies rotting under the tree")
		# (The last of this crop rots away just after the latest flower's
		# ripen, hang and rot; a year on, the next crop may already be down.)
		world.days = d0 + c0.tree_win + c0.open_d * 0.2 + c0.ripen.y + c0.hang.y + c0.rot.y + 1.0
		fc.update_now()
		var s4: PackedInt32Array = pick.summary
		print("      %.0f days on (day %.1f): %d lying, %d on the tree" % [c0.rot.y, world.days, s4[FruitCrop.Ph.GROUND], s4[FruitCrop.Ph.RIPE] + s4[FruitCrop.Ph.DRY] + s4[FruitCrop.Ph.SPLIT] + s4[FruitCrop.Ph.FRUIT]])
		if c0.ripen.y + c0.hang.y + c0.rot.y < year * 0.8:
			ok(s4[FruitCrop.Ph.GROUND] == 0, "then it's gone")
		else:
			print("      (its fruit lasts most of a year: the next crop is down before the last is gone, not checked)")
	print("RESULT fails: %d" % fails)
	quit()
