extends SceneTree
## Harvest and brew (design 9 Oct §FM.7, queue 72; Brew, SacredVine,
## FolkMotion, BrewVision; data/brew.json), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/brew_check.gd
## Asserts:
##  1. the data: brew.json's blocks, each with its _help line; the world's
##     plant ololiuhqui (world.plant, the Aztec world's: ruin_compass.json),
##     its entry in data/sacred read (its flags name nothing the engine
##     can't draw: a liana), built from its entry and never loaded (the
##     catalogue's count and lookups unchanged, no index, no data/sacred
##     species in it), drawn by the engine's own liana (PlantMeshes LIANA);
##  2. up on the surface (SEED): one vine, hung from one of the surface's
##     trees (with a trunk and branches, host_h_m tall, ahead of where you
##     come up) at attach_share of its height, out toward you, its strands
##     near the ground, in the foliage material as every plant up there, no
##     collision, no light; the shaman by it, the same figure as the one at
##     the hearth (his height, cloak, head and ladle), standing;
##  3. the lesson, seen once: not from far off, not with your back to him;
##     near and looking, he crouches, reaches with his left hand and takes
##     one length, the plant left standing; shows it, puts it away; wordless;
##     kept in this game's save;
##  4. your harvest: in reach, the button takes a cutting (one carried thing
##     in your pack: a plant sample, part cutting, of the entry's species);
##     the plant stands (never below keep_share, its top where it hung);
##     a second refused (carry.max, keep_share); out of reach, nothing;
##  5. it regrows on the game clock (World.days): half a take in half of
##     regrow_game_h, a whole take in regrow_game_h, never past its length;
##  6. down: the shaman gone from the surface; up again, not there (seen
##     once), the vine as the clock has it;
##  7. over twenty hearth rooms (1, 7, 42 and more; env BREW_SEEDS), built as
##     the game builds them in a world of their own: from the usual spot he
##     always has a way round the hearth to you (Brew.plan_way), ending
##     beside you on the kerb, clear of the stone, the bundle, the tripod's
##     feet and you; then in the game,
##     from the usual spot (your body walked from the mat at the fire stops
##     at the guard): with no cutting the button is the bundle's (a torch);
##     with one it hands it over: he rises, walks round the hearth to stand
##     beside you (his way clear of the stone, the bundle, the tripod's feet
##     and you), takes it (out of your pack into his left hand), turns to the
##     cauldron, drops it in (the brew there), stirs with his ladle (its bowl
##     in the pot), lifts a ladleful and holds it out in front of your eyes;
##     the rig's own animations (up off his stone, walking by velocity, back
##     on it), nothing new in the rig but the ladleful; wordless;
##  8. the drink: the button drinks it; the vision starts at once (above 0
##     the next frame), full after fade_in_s, still full at last_s, fading,
##     gone at last_s + fade_s (its time); he lowers the ladle, walks back and
##     sits on his stone as he sat; the cauldron empty again;
##  9. nothing changes while it runs (§FM.3): every data table, the light
##     field on the residents' grid, the environment, the grade, the look's
##     shared values, the camera, harm, the save (§FM.4: nothing of the brew
##     in it), the floors, the fork and the layout, no light or node added
##     outside the HUD; your walk covers the same ground in the same time,
##     your torch burns the same minutes, the clock and the residents' clock
##     run at the same pace.

var fails := 0
const DT := 1.0 / 60.0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	WorldSave.read_only = true
	Residents.stay_asleep = true
	_data()
	await _offline_ways(_seeds())
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	var count_before := SpeciesDB.all().size()
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	while not main.baked:
		await process_frame
	await _frames(10)
	var boss: Variant = main.get("boss")
	if boss is Boss:
		(boss as Boss).auto = false
	ok(main.brew != null and main.brew.vision != null and main.brew.vision.get_parent() == main.ui and main.brew.vision.get_index() == 0, "Brew is there from the first moment, its vision on the HUD under everything else (queue 72)")
	# The baseline (before any brew): your walk, your torch, the clocks.
	var base := await _pace(main, true)
	await _up(main, count_before)
	if not main.on_surface:
		print("RESULT fails: %d" % fails)
		quit(1)
		return
	var vine := main.surface.vine
	if vine == null:
		ok(false, "the vine is there to harvest")
		print("RESULT fails: %d" % fails)
		quit(1)
		return
	await _lesson(main, vine)
	await _harvest(main, vine)
	_regrow(main, vine)
	await _down_and_up(main, vine)
	await _rite(main, base)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


# --- 1. The data --------------------------------------------------------------------

func _data() -> void:
	var D := Brew.data()
	var help: Dictionary = D.get("_help", {})
	var keys := ["world", "vine", "teach", "carry", "rite", "plants"]
	var missing: Array = []
	for k in keys:
		if not D.has(k) or str(help.get(k, "")) == "" or str(help.get(k, "")).begins_with("[NOT WIRED"):
			missing.append(k)
	ok(missing.is_empty() and str(help.get("about", "")).contains("§FM.7") and str(help.get("about", "")).contains("§FM.3") and str(help.get("about", "")).contains("§FM.4"), "brew.json: world, vine, teach, carry, rite and plants, each with its _help line, wired; its about cites §FM.7, §FM.3 and §FM.4%s" % ("" if missing.is_empty() else " (missing: %s)" % str(missing)))
	var id := SacredVine.plant_id()
	var compass = JSON.parse_string(FileAccess.get_file_as_string("res://data/ruin_compass.json"))
	var aztec: Dictionary = ((compass as Dictionary).get("ruins", {}) as Dictionary).get("aztec", {}) if compass is Dictionary else {}
	ok(id == "ololiuhqui" and str((D.get("world", {}) as Dictionary).get("ruin", "")) == "aztec" and str(aztec.get("status", "")).begins_with("built_as_the_tomb") and str(aztec.get("plant", "")).contains("ololiuhqui"), "the tomb's world is the Aztec world (ruin_compass.json), its plant ololiuhqui (world.plant)")
	var doc = JSON.parse_string(FileAccess.get_file_as_string(SpeciesDB.SACRED_PATH))
	var entry := {}
	for tier in ((doc as Dictionary).get("plants", {}) as Dictionary):
		for e in (doc as Dictionary).plants[tier]:
			if e is Dictionary and str(e.get("id", "")) == id:
				entry = e
	var flags: Array = ((doc as Dictionary).get("flags", {}) as Dictionary).get(id, [])
	var blocking := false
	for f in flags:
		var fl := str(f).to_lower()
		if fl.contains("no mushroom shape") or fl.contains("engine has no") or fl.contains("can't draw") or fl.contains("cannot draw"):
			blocking = true
	ok(not entry.is_empty() and str(entry.get("shape", "")) == "liana" and flags.size() > 0 and not blocking, "its entry in data/sacred: a liana; its %d flags read, none says the engine can't draw it" % flags.size())
	var sp := SacredVine.species_of(id)
	ok(sp != null and sp.shape == PlantSpecies.Shape.LIANA and SpeciesDB.index_of(sp) == -1 and SpeciesDB.find(str(entry.get("name", ""))) == null, "built from its entry as the catalogue builds one, never loaded: no index, the catalogue doesn't find %s" % str(entry.get("name", "")))
	ok(SacredVine.drawable(sp), "the engine draws it: its own liana (PlantMeshes LIANA strands, %d triangles)" % ((PlantMeshes.arrays_for(sp, PlantMeshes.LOD_NEAR)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3 if sp != null else 0))
	var P := SacredVine.plant_data(id)
	var V: Dictionary = P.get("vision", {})
	ok(absf(float(V.get("last_s", 0.0)) - 120.0) < 1e-6 and V.has("tint") and V.has("pulse_hz") and float(P.get("regrow_game_h", 0.0)) > 0.0 and float(P.get("keep_share", 0.0)) > 0.0, "its plant block: a vision (tint and pulse, a first guess of 120 seconds), the share a harvest takes and keeps, and its regrow time on the game clock")


## Seeds for the hearth rooms: 1, 7, 42 and more from a fixed draw (env
## BREW_SEEDS sets how many in all).
func _seeds() -> Array:
	var n := 20
	if OS.get_environment("BREW_SEEDS").is_valid_int():
		n = maxi(int(OS.get_environment("BREW_SEEDS")), 1)
	var out: Array = [1, 7, 42]
	var rng := RandomNumberGenerator.new()
	rng.seed = 72
	while out.size() < n:
		var s := rng.randi_range(1, 999999)
		if not out.has(s):
			out.append(s)
	return out.slice(0, n)


## Over the seeds' hearth rooms (their stone, his seat, the cauldron, built
## as the game builds them, in a world of their own): from the usual spot
## (at the guard on the line from your mat to the fire) he always has a way
## round to you (Brew.plan_way), beside you on the kerb, clear of the stone,
## the bundle, the tripod's feet and you.
func _offline_ways(seeds: Array) -> void:
	var found := 0
	var clear_ok := true
	var beside_ok := true
	var longest := 0.0
	var shortest := INF
	var t0 := Time.get_ticks_msec()
	var pt := TombBuild.pit()
	var guard_m := float(pt.r) + float(pt.kerb_w) if not pt.is_empty() else 0.86
	for s in seeds:
		var lay := TombKit.layout(int(s))
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.size = Vector2i(4, 4)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		get_root().add_child(vp)
		var root := Node3D.new()
		vp.add_child(root)
		root.add_child(CrawlerMain.collision_body(TombBuild.build(lay, true)))
		var c := HearthCauldron.make(root, lay, null)
		c.process_mode = Node.PROCESS_MODE_DISABLED
		await physics_frame
		await physics_frame
		var space := vp.find_world_3d().direct_space_state
		var H: Vector3 = lay.hearth
		var wk: Vector3 = (lay.wake as Array)[0]
		var to := Vector3(wk.x - H.x, 0.0, wk.z - H.z).normalized()
		var spot := H + to * (guard_m + CrawlerPlayer.RADIUS_M)
		var pl := Brew.plan_way(lay, c, space, spot, [])
		if pl.is_empty():
			print("  seed %d: no way round the hearth to you" % s)
		else:
			found += 1
			var way: PackedVector3Array = pl.way
			var st: Vector3 = pl.stand
			var d_you := _flat(st, spot)
			if d_you < 0.8 or d_you > 1.5:
				beside_ok = false
				print("  seed %d: he stands %.2f m from you" % [s, d_you])
			var length := TombNav.length_of(way)
			longest = maxf(longest, length)
			shortest = minf(shortest, length)
			for k in range(1, way.size()):
				var n := maxi(int(ceil(way[k - 1].distance_to(way[k]) / 0.1)), 1)
				for i in n + 1:
					var q := way[k - 1].lerp(way[k], float(i) / n)
					var bad := ""
					if not _clear_at(space, q, null):
						bad = "the stone"
					elif _flat(q, lay.bundle) < 0.45 - 1e-3:
						bad = "the bundle"
					elif _flat(q, spot) < 0.6 - 1e-3:
						bad = "you"
					else:
						for ft in c.feet:
							if _flat(q, c.to_global(ft)) < 0.3 - 1e-3:
								bad = "a tripod foot"
					if bad != "":
						clear_ok = false
						print("  seed %d: his way meets %s at %s" % [s, bad, str(q.snapped(Vector3.ONE * 0.01))])
						break
		NodeRelease.free_later(vp)
	var n := seeds.size()
	ok(found == n, "%d hearth rooms: from the usual spot he always has a way round the hearth to you (%d of %d; %.1f-%.1f m)" % [n, found, n, shortest if shortest < INF else 0.0, longest])
	ok(clear_ok, "every way clear of the stone (walls, pillars, his own seat), 0.45 m off the bundle, 0.3 m off the tripod's feet, 0.6 m off you")
	ok(beside_ok, "and it ends beside you on the kerb, within reach (%d s for them all)" % ((Time.get_ticks_msec() - t0) / 1000))


## His body (rite.clear_m round, shins to shoulders) at `q`: in none of the
## stone?
func _clear_at(space: PhysicsDirectSpaceState3D, q: Vector3, p: CrawlerPlayer) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = float(Brew.R().get("clear_m", 0.24)) - 0.01
	shape.height = 1.4
	var qp := PhysicsShapeQueryParameters3D.new()
	qp.shape = shape
	qp.collision_mask = PropCollision.WORLD_LAYER
	if p != null:
		qp.exclude = [p.get_rid()]
	qp.transform = Transform3D(Basis.IDENTITY, Vector3(q.x, q.y + 0.85, q.z))
	return space.intersect_shape(qp, 1).is_empty()


# --- 2. Up on the surface -------------------------------------------------------------

func _up(main: CrawlerMain, count_before: int) -> void:
	main.go_up()
	for i in 9000:
		await process_frame
		if main.on_surface and not main.leaving:
			break
	ok(main.on_surface, "up the stair onto the surface (%d ms to build)" % (int(main.surface.ms.get("all", 0)) if main.surface != null else -1))
	if not main.on_surface:
		return
	await _frames(4)
	var s := main.surface
	var vine := s.vine
	ok(vine != null and vine.is_inside_tree() and vine.get_parent() == s, "one vine of the world's plant grows up there (SacredVine)")
	if vine == null:
		return
	var vines := s.find_children("*", "SacredVine", true, false)
	ok(vines.size() == 1, "one, and one only (%d)" % vines.size())
	ok(SpeciesDB.all().size() == count_before and SpeciesDB.index_of(vine.sp) == -1, "the catalogue untouched: %d species before and after (data/sacred not loaded into it)" % count_before)
	var from_sacred := 0
	for x in SpeciesDB.all():
		if (x as PlantSpecies).files.has("sacred_plants.json"):
			from_sacred += 1
	ok(from_sacred == 0, "no species in the catalogue from data/sacred (%d)" % from_sacred)
	# Its tree: one the surface grew, a tree with a trunk and branches.
	var h := vine.host
	var found := false
	for t in s.plants.trees_placed:
		if (t[0] as Vector2).distance_to(h.q) < 0.01 and absf(float(t[1]) - float(h.h)) < 1e-4:
			found = true
	var hr: Array = (Brew.data().get("vine", {}) as Dictionary).get("host_h_m", [3.0, 8.0])
	var arrive: Vector2 = s.stair.arrive
	var d := (h.q as Vector2).distance_to(arrive)
	var ang := rad_to_deg(absf((s.stair.n as Vector2).angle_to((h.q as Vector2) - arrive)))
	ok(found and float(h.h) >= float(hr[0]) and float(h.h) <= float(hr[1]) and PlantMeshes.climbable(SpeciesDB.find(str(h.species)).shape), "hung from one of the surface's trees: a %s %.1f m tall, %.0f m from where you come up, %.0f° off the way you face there" % [str(h.species), float(h.h), d, ang])
	var V: Dictionary = Brew.data().get("vine", {})
	var foot_y := s.land.height_at((h.q as Vector2).x, (h.q as Vector2).y) - 0.04 * float(h.h)
	var up_share := (vine.attach.y - foot_y) / float(h.h)
	var out := Vector2(vine.attach.x, vine.attach.z).distance_to(h.q) / float(h.h)
	var toward := Vector2(vine.out_dir.x, vine.out_dir.z).dot((arrive - (h.q as Vector2)).normalized())
	ok(absf(up_share - float(V.get("attach_share", 0.8))) < 0.01 and absf(out - float(V.get("out_share", 0.22))) < 0.01 and toward > 0.99, "as the open world hangs a liana: %.2f of the tree's height up it, %.2f of it out from the trunk, toward you" % [up_share, out])
	var tip := vine.tip()
	var ground := s.land.height_at(tip.x, tip.z)
	ok(tip.y - ground > 0.0 and tip.y - ground < 1.0 and vine.share_now() > 0.999, "its strands %.1f m long, down to %.2f m off the ground" % [vine.length_m, tip.y - ground])
	var mm := vine.mmi.multimesh
	var xf := vine.drawn
	ok(mm.mesh == PlantMeshes.mesh_for(vine.sp, PlantMeshes.LOD_NEAR) and vine.mmi.material_override == PlantMeshes.material_for(vine.sp) and xf.origin.distance_to(vine.attach) < 1e-4 and absf(xf.basis.y.length() - vine.length_m) < 1e-3, "drawn as every plant up there: the entry's own mesh in a one-plant MultiMesh, in the foliage material")
	ok(vine.find_children("*", "CollisionObject3D", true, false).filter(func(b): return not (b.get_parent() is PlayerBody)).is_empty() and vine.find_children("*", "Light3D", true, false).is_empty(), "no collision and no light of its own")
	# The shaman by it: the same figure as the one at the hearth.
	await _frames(2)
	var te := vine.teacher
	var r := main.rescuer
	ok(te != null and is_instance_valid(te) and te.is_inside_tree() and te.get_parent() == vine and not te.body.seated, "the shaman stands by it, the first time you come up")
	if te == null or r == null:
		return
	ok(te.beast == r.beast and te.palette == r.palette and absf(te.height - r.height) < 1e-6 and te.ladle != null, "the same figure as the one at the hearth: his head (%s), his cloak, his height, his ladle" % (te.beast if te.beast != "" else "the empty hood"))
	var stand := Vector2(te.global_position.x, te.global_position.z).distance_to(Vector2(vine.attach.x, vine.attach.z))
	ok(absf(stand - float((Brew.data().get("teach", {}) as Dictionary).get("stand_m", 0.7))) < 0.02 and absf(te.global_position.y - s.land.height_at(te.global_position.x, te.global_position.z)) < 0.02, "beside it (%.2f m out), on the ground" % stand)


# --- 3. The lesson ----------------------------------------------------------------------

func _lesson(main: CrawlerMain, vine: SacredVine) -> void:
	var p := main.player
	var te := vine.teacher
	if te == null:
		ok(false, "the lesson: no shaman")
		return
	var head := te.global_position + Vector3.UP * 1.5
	var log_before := GameLog.entries.size()
	# Off to his side (out of the ruin's yard, which lies toward the stair).
	var side := vine.out_dir.cross(Vector3.UP).normalized()
	# Far off, looking at him: nothing yet.
	await _stand_facing(main, te.global_position + side * 16.0, head)
	await _frames(30)
	ok(vine.lesson == "wait", "from 16 m off he waits")
	# Near, your back to him: nothing yet.
	var near := te.global_position + side * 7.0
	await _stand_facing(main, near, near + (near - head))
	await _frames(30)
	ok(vine.lesson == "wait", "near, your back to him, he waits")
	var share0 := vine.share_now()
	await _stand_facing(main, near, head)
	var began := false
	var crouched := false
	var reached := 0.0
	var prop_seen := false
	for i in 600:
		await physics_frame
		if vine.lesson == "reach":
			began = true
			crouched = crouched or te.body._crouch_target > 0.3
			reached = maxf(reached, vine.motion.reached(0) if vine.motion != null else 0.0)
		if vine._prop != null and is_instance_valid(vine._prop):
			prop_seen = true
		if vine.lesson == "done":
			break
	ok(began and crouched and reached > 0.9, "near and looking at him: he crouches and reaches with his left hand to the vine's foot")
	ok(vine.lesson_takes == 1 and absf(vine.share_now() - (share0 - vine.take_share())) < 0.002 and prop_seen, "he takes one length (%.2f of it), the plant left standing (now %.2f of its length), and holds it" % [vine.take_share(), vine.share_now()])
	ok(vine.lesson == "done" and vine.taught and (vine._prop == null or not is_instance_valid(vine._prop)), "he shows it and puts it away: the lesson done, once")
	ok(GameLog.entries.size() == log_before, "wordless: nothing in the log from him")
	ok(bool(CrawlerSave.kept_value(CrawlerSave.place, "harvest_taught", false)), "the lesson kept in this game's save (harvest_taught)")
	ok(vine.is_inside_tree() and vine.mmi.visible and vine.share_now() >= vine.keep_share() and vine.drawn.origin.distance_to(vine.attach) < 1e-4, "the plant still stands where it hung")


# --- 4. Your harvest ------------------------------------------------------------------------

func _harvest(main: CrawlerMain, vine: SacredVine) -> void:
	var p := main.player
	var brew := main.brew
	var te := vine.teacher
	var side := vine.out_dir.cross(Vector3.UP).normalized()
	var spot := Vector3(vine.attach.x, 0.0, vine.attach.z) + side * 1.0
	await _stand_facing(main, spot, vine.tip())
	await _frames(20)
	ok(vine.in_reach(p.eye_position()), "beside it, its foot in reach (%.2f m from your eyes)" % p.eye_position().distance_to(vine.tip()))
	var share0 := vine.share_now()
	var log_before := GameLog.entries.size()
	var carried0 := p.inventory.count()
	_press(main)
	await _frames(2)
	var it := brew.carrying()
	ok(not it.is_empty() and str(it.get("kind", "")) == "plant_sample" and str(it.get("part", "")) == "cutting" and str(it.get("sacred", "")) == vine.plant and str(it.get("binomial", "")) == vine.sp.binomial() and p.inventory.count() == carried0 + 1, "the button takes a cutting: one carried thing in your pack (a %s %s, %s)" % [str(it.get("part", "")), str(it.get("kind", "")), str(it.get("binomial", ""))])
	ok(absf(vine.share_now() - (share0 - vine.take_share())) < 0.002 and vine.share_now() >= vine.keep_share() - 1e-4 and vine.is_inside_tree(), "the plant stands: %.2f of its length left (never below %.2f), its top where it hung" % [vine.share_now(), vine.keep_share()])
	ok(GameLog.entries.size() == log_before + 1 and str(GameLog.entries[-1].get("text", "")) == str(Brew.C().get("log_take", "")), "the log's line: \"%s\"" % str(GameLog.entries[-1].get("text", "")))
	var refusals := vine.refusals
	_press(main)
	await _frames(2)
	ok(p.inventory.count() == carried0 + 1 and vine.refusals == refusals + 1 and absf(vine.share_now() - (share0 - vine.take_share())) < 0.002, "a second: refused (one carried at a time, and never below %.2f of its length)" % vine.keep_share())
	# Out of reach, nothing (and the button answers nothing else up here).
	await _stand_facing(main, spot + side * 8.0, vine.tip())
	await _frames(10)
	var r2 := vine.refusals
	_press(main)
	await _frames(2)
	ok(not vine.in_reach(p.eye_position()) and p.inventory.count() == carried0 + 1 and vine.refusals == r2, "out of reach the button does nothing")
	ok(te != null and is_instance_valid(te) and te.is_inside_tree() and vine.lesson == "done", "the shaman stands by it while you're up here, watching")


# --- 5. Regrowth on the game clock --------------------------------------------------------

func _regrow(main: CrawlerMain, vine: SacredVine) -> void:
	var w: Node = main.world
	var d0 := float(w.get("days"))
	var s0 := vine.share_now(d0)
	var gh := vine.regrow_h() / 24.0
	var half := vine.share_now(d0 + gh * 0.5)
	var whole := vine.share_now(d0 + gh)
	var long := vine.share_now(d0 + gh * 10.0)
	ok(absf(half - (s0 + vine.take_share() * 0.5)) < 1e-3 and absf(whole - (s0 + vine.take_share())) < 1e-3 and absf(long - 1.0) < 1e-6, "it regrows on the game clock: %.3f now, %.3f after %.1f game hours, %.3f after %.1f (one take back), its whole length at most (%.3f)" % [s0, half, vine.regrow_h() * 0.5, whole, vine.regrow_h(), long])
	ok(not vine.can_take(d0) and vine.can_take(d0 + gh), "a length to take again once one has grown back, not before")
	# The game's own clock moves it: on by the regrow time, the strands as long.
	w.days = d0 + gh
	vine._process(0.0)
	var xf := vine.drawn
	ok(absf(xf.basis.y.length() - vine.length_m * whole) < 1e-3, "World.days moved on %.1f game hours: the strands drawn %.2f m long again (%.2f of %.2f m)" % [vine.regrow_h(), xf.basis.y.length(), whole, vine.length_m])


# --- 6. Down, and up again ----------------------------------------------------------------

func _down_and_up(main: CrawlerMain, vine: SacredVine) -> void:
	var te := vine.teacher
	main.go_down()
	for i in 3000:
		await process_frame
		if not main.on_surface and not main.leaving:
			break
	await _frames(4)
	ok(not main.on_surface and (te == null or not is_instance_valid(te) or not te.is_inside_tree()) and vine.teacher == null, "down the stair: the shaman is not up there any more (seen once)")
	ok(main.rescuer != null and main.rescuer.is_inside_tree() and main.rescuer.body.seated, "and the one at the hearth sits on his stone as ever")
	main.go_up()
	for i in 3000:
		await process_frame
		if main.on_surface and not main.leaving:
			break
	await _frames(6)
	ok(main.on_surface and main.surface.vine == vine and vine.teacher == null and vine.taught, "up again: the same vine, and no shaman by it")
	main.go_down()
	for i in 3000:
		await process_frame
		if not main.on_surface and not main.leaving:
			break
	await _frames(4)


# --- 7, 8, 9. The hand-over, the brew, the drink, nothing changed ----------------------------

## Your walk, your torch's burn and the clocks over a second, from the
## mat toward the fire; `light` lights a torch from the bundle first (the
## button with no cutting: the bundle's).
func _pace(main: CrawlerMain, light: bool) -> Dictionary:
	var p := main.player
	var w: Array = main.lay.wake
	if light:
		await _to_guard(main)
		var before := p.inventory.count()
		ok(main.brew.carrying().is_empty() and not main.brew.interact(), "with no cutting the button isn't the brew's")
		_press(main)
		await _frames(2)
		var how := p.torch.pass_flame()
		ok(p.inventory.count() == before + 1 and p.torch.lit(), "it is the bundle's, as built: a torch from it, lit at the hearth (%s)" % how)
	p.spawn_flat(w[0], float(w[1]), -0.32)
	await _frames(20)
	var a := p.global_position
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	var walked := Vector2(p.global_position.x - a.x, p.global_position.z - a.z).length()
	await _frames(30)
	var it := p.torch.item()
	var b0 := float(it.get("burn_left_min", 0.0))
	var d0 := float(main.world.get("days"))
	var r0: float = main.residents.clock
	await _frames(60)
	var it2 := p.torch.item()
	return {"walk": walked, "burn": b0 - float(it2.get("burn_left_min", 0.0)), "days": float(main.world.get("days")) - d0, "res": main.residents.clock - r0}


func _rite(main: CrawlerMain, base: Dictionary) -> void:
	var p := main.player
	var brew := main.brew
	var f := main.rescuer
	var H: Vector3 = main.lay.hearth
	await _to_guard(main)
	var d := _flat(p.global_position, H)
	var pt := TombBuild.pit()
	var guard_m := float(pt.r) + float(pt.kerb_w) if not pt.is_empty() else 0.86
	ok(d >= guard_m + CrawlerPlayer.RADIUS_M - 0.06 and d <= float(Brew.R().get("hand_reach_m", 1.75)), "the usual spot: walked from the mat at the fire you stop at the guard, %.2f m from its middle" % d)
	ok(not brew.carrying().is_empty(), "the cutting still in your pack, carried down")
	var snap0 := _snapshot(main)
	var seat_pos := f.global_position
	var seat_rot := f.rotation.y
	var rig_before := _rig_nodes(f)
	var log_before := GameLog.entries.size()
	_press(main)
	await _frames(1)
	ok(brew.rite == "rise" and not f.body.seated and not brew.carrying().is_empty(), "the button there: he rises from his stone (the cutting still yours till he takes it)")
	# His way round, before he walks it.
	var way := brew.way
	var bundle: Vector3 = main.lay.bundle
	var worst := {"stone": 0, "bundle": INF, "feet": INF, "you": INF}
	var space := p.get_world_3d().direct_space_state
	for k in range(1, way.size()):
		var n := maxi(int(ceil(way[k - 1].distance_to(way[k]) / 0.1)), 1)
		for i in n + 1:
			var q := way[k - 1].lerp(way[k], float(i) / n)
			if not _body_clear(space, q, p):
				worst.stone += 1
			worst.bundle = minf(worst.bundle, _flat(q, bundle))
			for ft in main.cauldron.feet:
				worst.feet = minf(worst.feet, _flat(q, main.cauldron.to_global(ft)))
			worst.you = minf(worst.you, _flat(q, p.global_position))
	ok(way.size() >= 3 and int(worst.stone) == 0 and float(worst.bundle) >= 0.45 - 1e-3 and float(worst.feet) >= 0.3 - 1e-3 and float(worst.you) >= 0.6 - 1e-3, "his way round the hearth (%.1f m) clear of the stone (walls, pillars, his seat), %.2f m off the bundle at least, %.2f m off the tripod's feet, %.2f m off you" % [TombNav.length_of(way), float(worst.bundle), float(worst.feet), float(worst.you)])
	var seen := {}
	var walked_far := 0.0
	var took_at := ""
	var stirred_in := 0
	var stir_frames := 0
	var brew_in_pot := false
	var min_you := INF
	var offered := false
	for i in 4800:
		await physics_frame
		seen[brew.rite] = true
		if brew.rite in ["go", "home"]:
			walked_far = maxf(walked_far, _flat(f.global_position, seat_pos))
		if brew.rite != "" and brew.rite != "rise":
			min_you = minf(min_you, _flat(f.global_position, p.global_position))
		if took_at == "" and brew.carrying().is_empty():
			took_at = brew.rite
		if main.cauldron.find_children("Brew", "", true, false).size() > 0:
			brew_in_pot = true
		if brew.rite == "stir" and brew._rt > 1.0:
			stir_frames += 1
			var bowl := f.ladle.global_transform * brew._bowl_local()
			var m := main.cauldron.mouth()
			if Vector2(bowl.x - m.x, bowl.z - m.z).length() < main.cauldron.mouth_r() and bowl.y < m.y + 0.05:
				stirred_in += 1
		if brew.rite == "offer" and brew._rt > 0.8:
			offered = true
			break
	ok(seen.has("go") and walked_far > 1.0 and not f.body.seated, "he walks round the hearth to you (%.1f m from his stone at the furthest), standing" % walked_far)
	ok(min_you >= 0.7, "never through you: %.2f m off you at the nearest" % min_you)
	ok(took_at == "take" and handed_ok(brew), "he takes it from you: out of your pack as he reaches (%s), into his left hand" % took_at)
	ok(brew_in_pot and seen.has("drop") and seen.has("stir"), "he drops it in the cauldron: the brew in the pot")
	ok(stir_frames > 0 and float(stirred_in) / maxf(stir_frames, 1) > 0.9, "he stirs it with his ladle, its bowl in the pot (%d of %d frames)" % [stirred_in, stir_frames])
	ok(offered and brew.fill != null and is_instance_valid(brew.fill) and main.cauldron.find_children("Brew", "", true, false).is_empty(), "he lifts a ladleful and holds it out (the pot served out)")
	if offered:
		var bowl2 := f.ladle.global_transform * brew._bowl_local()
		var eye := p.eye_position()
		var fwd := -p.camera().global_basis.z
		ok(eye.distance_to(bowl2) < 0.9 and absf(bowl2.y - eye.y) < 0.45, "in front of your eyes (%.2f m off them)" % eye.distance_to(bowl2))
	var rig_now := _rig_nodes(f)
	var added: Array = rig_now.filter(func(n): return not rig_before.has(n))
	var names := added.map(func(n): return str(n.name))
	ok(added.size() <= 1 and (added.is_empty() or str(added[0].name) == "BrewFill"), "the rig's own: nothing new in it but the ladleful %s" % str(names))
	ok(GameLog.entries.size() == log_before, "wordless: nothing in the log through it all")
	# The drink.
	var added_nodes: Array = []
	var watcher := func(n: Node) -> void: added_nodes.append(n)
	node_added.connect(watcher)
	var lights0 := main.find_children("*", "Light3D", true, false).size()
	_press(main)
	await _frames(1)
	var vis := brew.vision
	ok(brew.drinks == 1 and vis.active and vis.level() > 0.0 and (brew.fill == null or not is_instance_valid(brew.fill)), "the button drinks it: the vision starts at once (%.5f the next frame)" % vis.level())
	ok(str(GameLog.entries[-1].get("text", "")) == str(Brew.R().get("log_drink", "")), "the log's line: \"%s\"" % str(GameLog.entries[-1].get("text", "")))
	var V: Dictionary = vis.v
	var fin := float(V.get("fade_in_s", 4.0))
	var last := float(V.get("last_s", 120.0))
	var fade := float(V.get("fade_s", 10.0))
	# He goes back and sits.
	for i in 3600:
		await physics_frame
		if brew.rite == "":
			break
	ok(brew.rite == "" and f.body.seated and f.global_position.distance_to(seat_pos) < 0.02 and absf(wrapf(f.rotation.y - seat_rot, -PI, PI)) < deg_to_rad(1.0), "he lowers the ladle, walks back and sits on his stone as he sat (%.3f m off)" % f.global_position.distance_to(seat_pos))
	ok(f.ladle != null and f.ladle.transform.is_equal_approx(brew._ladle_rest) and f.body.arms[0].rotation.distance_to(Vector3(PlayerBody.ARM_REST.x, 0.0, -PlayerBody.ARM_REST.z)) < 1e-3 and f.body.arms[1].rotation.distance_to(PlayerBody.ARM_REST) < 1e-3, "his arms at rest, his ladle back in his hand as it was")
	ok(main.cauldron.find_children("Brew*", "", true, false).is_empty(), "the cauldron empty again")
	await _frames(maxi(int((fin - vis.t) * 60.0) + 2, 0))
	ok(vis.active and absf(vis.envelope() - 1.0) < 1e-3, "after %.0f s it is full" % fin)
	# 9. Nothing changes while it runs.
	var snap1 := _snapshot(main)
	var diff := _diff(snap0, snap1)
	ok(diff.is_empty(), "while it runs nothing else has changed: data tables, light field, environment, grade, look, camera, harm, save, floors, fork, layout%s" % ("" if diff.is_empty() else " (changed: %s)" % str(diff)))
	var during := await _pace(main, false)
	ok(absf(float(during.walk) - float(base.walk)) < 1e-3, "your walk covers the same ground in the same time: %.3f m against %.3f m before" % [float(during.walk), float(base.walk)])
	ok(absf(float(during.burn) - float(base.burn)) < 1e-6 and float(base.burn) > 0.0, "your torch burns the same: %.5f minutes in a second against %.5f before (no torch drain)" % [float(during.burn), float(base.burn)])
	ok(absf(float(during.days) - float(base.days)) < 1e-9 and absf(float(during.res) - float(base.res)) < 1e-6, "the clock and the residents' clock run at the same pace (no timer on anything else)")
	ok(vis.active, "still running (%.0f s in)" % vis.t)
	await _frames(maxi(int((last - 0.5 - vis.t) * 60.0), 0))
	ok(vis.active and absf(vis.envelope() - 1.0) < 1e-3, "still full at %.1f s (its last_s, %.0f)" % [vis.t, last])
	await _frames(int((0.5 + fade * 0.5) * 60.0))
	var mid := vis.envelope()
	ok(vis.active and mid > 0.05 and mid < 0.95, "then it fades (%.2f at %.1f s)" % [mid, vis.t])
	await _frames(int((fade * 0.5) * 60.0) + 3)
	ok(not vis.active and vis.level() == 0.0 and not vis.visible, "gone at %.0f s: its time (last_s %.0f + fade_s %.0f)" % [last + fade, last, fade])
	node_added.disconnect(watcher)
	var outside: Array = added_nodes.filter(func(n): return is_instance_valid(n) and not main.ui.is_ancestor_of(n))
	ok(outside.is_empty() and main.find_children("*", "Light3D", true, false).size() == lights0, "nothing added to the world while it ran: no light, no thing seen (no hallucinations; %d nodes added)" % outside.size())
	var snap2 := _snapshot(main)
	var diff2 := _diff(snap0, snap2)
	ok(diff2.is_empty(), "and nothing changed after it either%s" % ("" if diff2.is_empty() else " (changed: %s)" % str(diff2)))
	var save_text := JSON.stringify(CrawlerSave.data).to_lower()
	ok(not save_text.contains("brew") and not save_text.contains("vision") and not save_text.contains("secret") and not save_text.contains("drink"), "nothing of the brew in the save: nothing reaches a secret layer (§FM.4)")


func handed_ok(brew: Brew) -> bool:
	return brew.handed == 1


## Every node under the rig (the figure's own: arms, sleeves, the ladle).
func _rig_nodes(f: HearthFolk) -> Array:
	var out: Array = []
	_collect(f.body, func(_n): return true, out)
	return out


func _collect(n: Node, test: Callable, out: Array) -> void:
	if test.call(n):
		out.append(n)
	for c in n.get_children():
		_collect(c, test, out)


## The game's numbers that a brew must leave alone.
func _snapshot(main: CrawlerMain) -> Dictionary:
	var s := {}
	var tables := {}
	for k in Tuning._tables:
		tables[k] = JSON.stringify(Tuning._tables[k])
	s["tables"] = tables
	s["brew_data"] = JSON.stringify(Brew.data())
	s["light_field"] = main.residents.light.level.duplicate() if main.residents.light != null else PackedFloat32Array()
	var e := main.environment
	s["environment"] = [e.background_color, e.ambient_light_color, e.ambient_light_energy, e.fog_enabled, e.fog_density, e.fog_light_color, e.tonemap_mode, e.tonemap_exposure, e.glow_enabled, e.adjustment_enabled]
	var pm := (main.post as PostGrade)._rect.material as ShaderMaterial
	var post := {}
	for u in pm.shader.get_shader_uniform_list():
		post[str(u.name)] = pm.get_shader_parameter(str(u.name))
	s["grade"] = post
	s["look"] = Look._params.duplicate()
	var cam := main.player.camera()
	s["camera"] = [cam.fov, cam.near, cam.far, cam.cull_mask, cam.attributes]
	var h := main.harm
	s["harm"] = [h.hits.size(), h.stage, h.vignette, h.desaturate, h.muffle_db, h.heart, h.black, h.ring, h.taking]
	s["save"] = JSON.stringify(CrawlerSave.data)
	s["floors"] = TombFloors.floors_of(main.lay)
	s["fork"] = main.fork.get("opened") if main.fork != null else null
	s["lay"] = [(main.lay.pieces as Array).size(), (main.lay.holders as Array).size(), (main.lay.doors as Array).size(), main.lay.hearth, main.lay.wake, main.lay.rescuer]
	s["walls"] = main.walls.size()
	return s


func _diff(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for k in a:
		if k == "tables" or k == "grade" or k == "look":
			var da: Dictionary = a[k]
			var db: Dictionary = b.get(k, {})
			for kk in da:
				if not db.has(kk) or str(da[kk]) != str(db[kk]):
					out.append("%s.%s" % [k, kk])
			for kk in db:
				if not da.has(kk):
					out.append("%s.%s (new)" % [k, kk])
		elif str(a[k]) != str(b.get(k)):
			out.append(k)
	return out


## Your capsule's worth of the shaman (rite.clear_m round, shins to
## shoulders) at `q`: in none of the stone?
func _body_clear(space: PhysicsDirectSpaceState3D, q: Vector3, p: CrawlerPlayer) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = float(Brew.R().get("clear_m", 0.24)) - 0.01
	shape.height = 1.4
	var qp := PhysicsShapeQueryParameters3D.new()
	qp.shape = shape
	qp.collision_mask = PropCollision.WORLD_LAYER
	qp.exclude = [p.get_rid()]
	qp.transform = Transform3D(Basis.IDENTITY, Vector3(q.x, q.y + 0.85, q.z))
	return space.intersect_shape(qp, 1).is_empty()


# --- Helpers ---------------------------------------------------------------------------------

func _press(main: CrawlerMain) -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	main._unhandled_input(ev)


## You standing at `at` (its ground) looking at `look_at`.
func _stand_facing(main: CrawlerMain, at: Vector3, look_at: Vector3) -> void:
	var p := main.player
	var g := at
	if main.on_surface and main.surface != null:
		g.y = main.surface.land.height_at(at.x, at.z)
	var dir := look_at - (g + Vector3.UP * p.eye_height())
	var flat := Vector3(dir.x, 0.0, dir.z)
	var yaw := atan2(-flat.x, -flat.z)
	var pitch := atan2(dir.y, maxf(flat.length(), 1e-3))
	p.spawn_flat(g + Vector3.UP * 0.1, yaw, pitch)
	await _frames(12)
	p.set_view(pitch, yaw)
	await _frames(2)


## Your body from the mat straight at the fire until it stops (at the
## pit's guard): the usual spot.
func _to_guard(main: CrawlerMain) -> void:
	var p := main.player
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), -0.32)
	await physics_frame
	Input.action_press("move_forward")
	var last := p.global_position
	var still := 0
	for i in 360:
		await physics_frame
		if p.global_position.distance_to(last) < 0.002:
			still += 1
			if still > 20:
				break
		else:
			still = 0
		last = p.global_position
	Input.action_release("move_forward")
	await _frames(4)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
