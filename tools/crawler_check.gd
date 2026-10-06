extends SceneTree
## Torchfire 1's first slice (design 6 Oct §ET.11), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/crawler_check.gd
## Asserts:
##  1. the switch (§ET.2): data/game.json boots the crawler (the project's
##     main scene is the boot scene, which opens GameMode.scene()), GAME
##     overrides it, the open world's scene is still there;
##  2. the tomb kit (§ET.3, §CJ.8), over SEEDS seeds: three or four exits
##     from the hearth room, every piece reachable from it through doors,
##     no two pieces overlapping unless a door joins them, a heart, a cold
##     holder in every room past the hearth room, the airways placed, the
##     mat, the bundle and the rescuer in the hearth room clear of the
##     hearth; in the scene: a floor under every piece and a ceiling over
##     it, and you standing on the floor;
##  3. relighting (§ET.4): you wake with nothing in hand, the hearth lit,
##     every holder dark (full dark: no light but the hearth's); a torch
##     from the bundle, lit at the hearth by the swing; every holder lit by
##     the swing, staying lit an hour on; a dead torch relit at a holder;
##  4. the snuff rules (§ET.7, torch.json snuff): walking and looking about
##     a minute never gutter it; a flat-out sprint gutters it at
##     gutter_after_s and puts it out at out_after_s; stopping in the
##     gutter recovers over recover_s; a strong airway warns (gutter) and
##     its gust puts out a torch in its line, not one out of its line or
##     behind cover; an ordinary airway only leans it; wading toward
##     douse_depth_m gutters it, past it douses it;
##  5. the rescuer's sprite (§ET.8): its sheet around x frames by rows,
##     the frame picked by where the camera stands (front, side, behind,
##     above, below), facing the hearth.

const SEEDS := 30

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	WorldSave.read_only = true
	Bow.need_capture = false
	_switch()
	_layouts()
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked:
		await process_frame
	await _scene(main)
	_masonry(main)
	await _vents(main)
	await _relight(main)
	await _snuff(main)
	_sprite(main)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _switch() -> void:
	ok(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/boot.tscn", "the project boots the boot scene (scenes/boot.tscn)")
	var want := OS.get_environment("GAME")
	OS.set_environment("GAME", "")
	ok(GameMode.game() == "torchfire1" and GameMode.scene() == "res://scenes/crawler.tscn", "data/game.json picks Torchfire 1, the crawler (%s)" % GameMode.scene())
	OS.set_environment("GAME", "torchfire2")
	ok(GameMode.scene() == "res://scenes/main.tscn" and ResourceLoader.exists("res://scenes/main.tscn"), "GAME=torchfire2 opens the open world, still there (scenes/main.tscn)")
	OS.set_environment("GAME", want)


func _layouts() -> void:
	var exits_ok := true
	var reach_ok := true
	var overlap_ok := true
	var heart_ok := true
	var holders_ok := true
	var spots_ok := true
	var strong := 0
	var rooms_n := 0
	var pieces_n := 0
	var stairs := 0
	var kinds := {}
	for s in SEEDS:
		var lay := TombKit.layout(1000 + s * 7919)
		var pieces: Array = lay.pieces
		pieces_n += pieces.size()
		if int(lay.exits) < 3 or int(lay.exits) > 4:
			exits_ok = false
			print("  seed %d: %d exits" % [lay.seed, lay.exits])
		# Reachable through doors from the hearth room.
		var seen := {0: true}
		var stack := [0]
		while not stack.is_empty():
			var id: int = stack.pop_back()
			for di in pieces[id].doors:
				var d: Dictionary = lay.doors[di]
				for o in [int(d.a), int(d.b)]:
					if not seen.has(o):
						seen[o] = true
						stack.append(o)
		if seen.size() != pieces.size():
			reach_ok = false
		# No overlaps but through a door.
		for i in pieces.size():
			for j in range(i + 1, pieces.size()):
				var joined := false
				for di in pieces[i].doors:
					var d: Dictionary = lay.doors[di]
					if int(d.a) == j or int(d.b) == j:
						joined = true
				if joined:
					continue
				if TombKit.outer(pieces[i]).grow(-0.02).intersects(TombKit.outer(pieces[j]).grow(-0.02)):
					overlap_ok = false
					print("  seed %d: pieces %d and %d overlap" % [lay.seed, i, j])
		if not lay.has("heart"):
			heart_ok = false
		var in_room := {}
		for h in lay.holders:
			if str(h.kind) != "sconce":
				in_room[int(h.piece)] = true
		for pc in pieces:
			if str(pc.kind) == "room":
				kinds[str(pc.room_kind)] = int(kinds.get(str(pc.room_kind), 0)) + 1
				if str(pc.room_kind) != "hearth":
					rooms_n += 1
					if not in_room.has(int(pc.id)):
						holders_ok = false
			elif str(pc.kind) == "stair":
				stairs += 1
		for a in lay.airways:
			if bool(a.strong):
				strong += 1
		var hr: Dictionary = pieces[0]
		for spot in [lay.wake[0], lay.bundle, lay.rescuer[0]]:
			var aa := Delves.along_across(hr, Vector2((spot as Vector3).x, (spot as Vector3).z))
			if aa.x < 0.5 or aa.x > float(hr.len) - 0.5 or absf(aa.y) > float(hr.half) - 0.5 or (spot as Vector3).length() < 0.8:
				spots_ok = false
	ok(exits_ok, "%d seeds: three or four ways out of the hearth room every time" % SEEDS)
	ok(reach_ok, "every piece reachable from the hearth room through doors")
	ok(overlap_ok, "no two pieces overlap except through a door")
	ok(heart_ok, "every tomb has a heart (its deepest room)")
	ok(holders_ok, "a cold fire-holder in every room past the hearth room (%d rooms)" % rooms_n)
	ok(spots_ok, "the mat, the bundle and the rescuer stand in the hearth room, clear of the hearth")
	ok(strong >= SEEDS * 0.8, "strong airway mouths placed (%d in %d tombs)" % [strong, SEEDS])
	print("  %d pieces in %d tombs (%.1f each), %d flights of stairs; rooms by kind %s" % [pieces_n, SEEDS, float(pieces_n) / SEEDS, stairs, str(kinds)])


func _ray(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = exclude
	return get_root().get_world_3d().direct_space_state.intersect_ray(q)


func _scene(main: CrawlerMain) -> void:
	var lay := main.lay
	var floors := true
	var ceilings := true
	for pc in lay.pieces:
		# A few spots across the piece (a holder's logs or a coffin may
		# stand on one): the floor must be found at its height at most.
		var found := 0
		var fy := Delves.floor_of(pc, float(pc.len) * 0.5)
		var c2 := Vector2.ZERO
		for spot in [[0.5, 0.3], [0.2, 0.0], [0.8, 0.0], [0.35, -0.5]]:
			var q: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * float(spot[0]) + Delves.perp(pc.dir) * float(spot[1])
			var y := Delves.floor_of(pc, float(pc.len) * float(spot[0]))
			var hit := _ray(Vector3(q.x, y + 1.2, q.y), Vector3(q.x, y - 1.0, q.y), [main.player.get_rid()])
			if not hit.is_empty() and absf((hit.position as Vector3).y - y) <= (0.45 if str(pc.kind) == "stair" else 0.12):
				found += 1
				c2 = q
		if found < 2:
			floors = false
			print("  piece %d (%s): the floor found at %d of 4 spots" % [pc.id, pc.kind, found])
		# A ceiling over it (any of the spots: one may sit under a flue).
		var roofed := false
		for spot2 in [[0.5, 0.3], [0.2, 0.0], [0.8, 0.0], [0.35, -0.5]]:
			var q2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * float(spot2[0]) + Delves.perp(pc.dir) * float(spot2[1])
			var y2 := Delves.floor_of(pc, float(pc.len) * float(spot2[0]))
			if not _ray(Vector3(q2.x, y2 + 1.2, q2.y), Vector3(q2.x, y2 + float(pc.h) + 3.0, q2.y), [main.player.get_rid()]).is_empty():
				roofed = true
		if not roofed:
			ceilings = false
			print("  piece %d (%s): no ceiling" % [pc.id, pc.kind])
	ok(floors, "a floor under every piece, at its height")
	ok(ceilings, "a ceiling over every piece")
	ok(main.player.is_on_floor() and absf(main.player.global_position.y) < 0.2, "you wake standing on the hearth room's floor (y %.2f)" % main.player.global_position.y)
	print("  the tomb's stone: %d triangles" % int(main.tomb.get_meta("triangles", 0)))


func _place_facing(p: CrawlerPlayer, at: Vector3, target: Vector3) -> void:
	var flat := Vector3(target.x - at.x, 0.0, target.z - at.z)
	p.spawn_flat(at, atan2(-flat.x, -flat.z))


func _lights_on(main: CrawlerMain) -> int:
	var n := 0
	for l in main.find_children("*", "OmniLight3D", true, false):
		var o := l as OmniLight3D
		if o.is_visible_in_tree() and o.light_energy > 0.01:
			n += 1
	return n


func _relight(main: CrawlerMain) -> void:
	var p := main.player
	var t := p.torch
	var fires := main.fires
	ok(p.weapon == "hands" and not t.in_hand(), "you wake with nothing in hand (§AW)")
	ok(FireStore.is_lit(fires.hearth), "the hearth is lit")
	ok(fires.lit_count() == 0, "every holder starts cold (%d holders)" % fires.holders.size())
	for i in 5:
		await process_frame
	ok(_lights_on(main) == 1, "full dark: the hearth's is the only light burning (%d)" % _lights_on(main))
	# The bundle.
	_place_facing(p, fires.bundle.global_position + Vector3(1.0, 0.0, 0.0), fires.bundle.global_position)
	var before := fires.bundle_left
	ok(main.take_torch() and t.in_hand() and not t.lit() and fires.bundle_left == before - 1, "right click by the bundle takes an unlit torch into your hand (%d left)" % fires.bundle_left)
	# Lit at the hearth.
	var hp := fires.hearth.global_position
	_place_facing(p, hp + Vector3(0.0, 0.0, 1.0), hp)
	ok(t.pass_flame() == "torch" and t.lit(), "the swing through the hearth lights the torch (§CN)")
	# Every holder.
	var all_caught := true
	for h in fires.holders:
		var at := h.global_position
		var stand := _stand_by(main, h)
		_place_facing(p, stand, at)
		var how := t.pass_flame()
		if not how.begins_with("fire:"):
			all_caught = false
			print("  holder %s at %s: the swing passed '%s'" % [h.name, str(at), how])
	ok(all_caught, "the swing reaches every holder")
	for i in 240:
		FireStore.tick(self, 1.0 / 60.0, p.global_position)
	ok(fires.lit_count() == fires.holders.size(), "every holder caught (%d of %d)" % [fires.lit_count(), fires.holders.size()])
	FireStore.tick(self, 3600.0, p.global_position)
	for i in 6:
		FireStore.tick(self, 600.0, p.global_position)
	ok(fires.lit_count() == fires.holders.size(), "relit holders stay lit an hour on (kept, §ET.4)")
	# A dead torch relit at a holder.
	t.put_out("stowed")
	var h0: Node3D = fires.holders[0]
	var st0 := _stand_by(main, h0)
	_place_facing(p, st0, h0.global_position)
	ok(not t.lit() and t.pass_flame() == "torch" and t.lit(), "a dead torch relights at a relit holder")


## The fitted-stone walls (Mike, 6 Oct; FittedStone, masonry.json).
func _masonry(main: CrawlerMain) -> void:
	var stones := int(main.tomb.get_meta("stones", 0))
	var faces := int(main.tomb.get_meta("faces", 0))
	ok(stones > 200 and faces > 20, "fitted stones on every seen wall face (%d stones on %d faces, %s)" % [stones, faces, str(FittedStone.M.get("preset", ""))])
	# The partition is tight: the cells fill the wall, no gaps, no overlaps.
	var rng := RandomNumberGenerator.new()
	var worst := 0.0
	for preset in ["megalithic", "fitted_small"]:
		var keep := str(FittedStone.M.get("preset", ""))
		FittedStone.M["preset"] = preset
		for k in 6:
			rng.seed = 900 + k
			var l := rng.randf_range(2.0, 11.0)
			var h := rng.randf_range(2.5, 3.8)
			var area := 0.0
			for c in FittedStone.cells(l, h, rng):
				area += FittedStone._area(c[1])
			worst = maxf(worst, absf(area - l * h) / (l * h))
		FittedStone.M["preset"] = keep
	ok(worst < 0.002, "the stones' cells fill each wall exactly: shared edges, no gaps (worst %.4f of the wall)" % worst)
	# The damp differs from place to place, and the overgrowth with it.
	var lo := 1.0
	var hi := 0.0
	for pc in main.lay.pieces:
		var c: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * 0.5
		var hm := FittedStone.humidity(str(main.lay.theme), int(main.lay.seed), Vector3(c.x, float(pc.y0), c.y))
		lo = minf(lo, hm)
		hi = maxf(hi, hm)
	print("  the tomb's damp runs %.2f to %.2f" % [lo, hi])
	ok(hi - lo > 0.2, "the damp differs from place to place (%.2f to %.2f)" % [lo, hi])
	ok(FittedStone.moss_of(0.2) == 0.0 and FittedStone.moss_of(0.95) > 0.9, "no moss where it's dry, full moss where it's wet")
	# One wall dressed dry and once wet: dust and bare stone, then vines.
	var out := {}
	for hum in [0.1, 0.95]:
		var tb := TombBuild.new()
		var r2 := RandomNumberGenerator.new()
		r2.seed = 77
		FittedStone.face(tb, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, 8.0, -0.1, 3.0, 0.0, hum, r2)
		var leaf := 0
		for m in tb._m:
			if int(round(m.x)) == RuinBuilder.LEAF_M:
				leaf += 1
		out[hum] = [tb._boulder_anchors.size(), leaf / 3]
	ok(int(out[0.1][0]) > 0 and int(out[0.1][1]) == 0, "a dry wall: drifted dust at its foot and corners, no vines (%d drifts)" % out[0.1][0])
	ok(int(out[0.95][0]) == 0 and int(out[0.95][1]) > 0, "a wet wall: vines from its top and cracks, no dust (%d leaf triangles)" % out[0.95][1])


## The ventilation rule (Mike, 6 Oct; TombKit vents, Vents, vents.json).
func _vents(main: CrawlerMain) -> void:
	var lay := main.lay
	var vents: Array = lay.vents
	var V: Dictionary = Tuning.table("vents")
	var surface := float(V.get("surface_y_m", 9.0))
	ok(vents.size() == (lay.holders as Array).size() + 1, "every permanent fire has a vent: the hearth and %d holders (%d vents)" % [(lay.holders as Array).size(), vents.size()])
	var reach := true
	var open := true
	var drafts := true
	for v in vents:
		var legs: Array = v.legs
		if absf(((legs[-1] as Array)[1] as Vector3).y - surface) > 0.01:
			reach = false
		# The way up the flue is open (straight flues: a ray up the middle).
		if legs.size() == 1:
			var m: Vector3 = v.mouth
			var hit := _ray(m - Vector3(0.0, 0.3, 0.0), Vector3(m.x, surface - 0.1, m.z), [main.player.get_rid()])
			if not hit.is_empty():
				open = false
				print("  vent over %s at %s: blocked at %s" % [v.kind, str(m), str(hit.position)])
		var fire: Node3D = main.fires.hearth if int(v.fire_index) < 0 else main.fires.holders[int(v.fire_index)]
		if not fire.has_meta("draft"):
			drafts = false
	ok(reach, "every flue reaches the surface (%.1f m)" % surface)
	ok(open, "every straight flue is open from its mouth to the sky")
	ok(drafts, "every vented fire feels the draft")
	# Deeper: narrower and fainter.
	var shallow: Dictionary = {}
	var deep: Dictionary = {}
	for v in vents:
		if str(v.kind) != "hearth_ring":
			continue
		if shallow.is_empty() or float(v.depth) < float(shallow.depth):
			shallow = v
		if deep.is_empty() or float(v.depth) > float(deep.depth):
			deep = v
	if not deep.is_empty() and float(deep.depth) > float(shallow.depth) + 0.5:
		ok(float(deep.d) < float(shallow.d) and float(deep.share) < float(shallow.share), "a deeper fire's flue is narrower and its daylight fainter (%.1f m: %.2f m wide, %.2f; %.1f m: %.2f m, %.2f)" % [shallow.depth, shallow.d, shallow.share, deep.depth, deep.d, deep.share])
	# A shaft for a big fire, a narrow flue for a small one; only shafts
	# let daylight down (design §EV.1-2).
	var sized := true
	var n_shaft := 0
	for v in vents:
		var wr: Array = (V.get(str(v.type), {}) as Dictionary).get("width_m", [0.0, 9.0])
		if str(v.type) != TombKit.vent_type(str(v.kind)) or float(v.d) < float(wr[0]) - 0.001 or float(v.d) > float(wr[1]) + 0.001:
			sized = false
			print("  vent over %s: %s %.2f m wide" % [v.kind, v.type, v.d])
		if str(v.type) == "shaft" and bool(v.sky):
			n_shaft += 1
		if str(v.type) == "flue" and bool(v.sky):
			sized = false
	ok(sized, "every vent is sized by its fire: shafts %s m, flues %s m" % [str((V.get("shaft", {}) as Dictionary).get("width_m")), str((V.get("flue", {}) as Dictionary).get("width_m"))])
	ok(main.vents.shafts.size() == n_shaft and n_shaft >= 1, "daylight comes down the shafts only (%d of %d vents), never a flue" % [n_shaft, vents.size()])
	ok(TombKit.daylight_share(float(V.get("max_carve_m", 16.0)) + 1.0) == 0.0, "past the deepest point on the curve no daylight comes down")
	# Day and night on the world's clock.
	ok(Vents.daylight_at(13.5) > 0.99 and Vents.daylight_at(13.0) < 0.01, "the shafts follow the clock: full day at noon, night at midnight")
	var w := main.world
	var keep_days: float = w.days
	w.days = 13.5
	await process_frame
	var e_day := 0.0
	for sh in main.vents.shafts:
		e_day += (sh.light as SpotLight3D).light_energy
	var col_day: Color = (main.vents.shafts[0].light as SpotLight3D).light_color
	w.days = 13.0
	await process_frame
	var e_night := 0.0
	for sh in main.vents.shafts:
		e_night += (sh.light as SpotLight3D).light_energy
	var col_night: Color = (main.vents.shafts[0].light as SpotLight3D).light_color
	w.days = keep_days
	ok(e_day > e_night * 3.0 and col_day.b > col_day.r and col_night.b > col_night.r, "the shafts: cool blue and strong by day (%.1f), dim moonlit blue at night (%.1f)" % [e_day, e_night])
	# Soot: the stone round every flue's mouth darkened (TombBuild._soot).
	var stained := 0
	var tb_arrays: Array = []
	for mi in main.tomb.get_children():
		if mi is MeshInstance3D:
			tb_arrays.append((mi as MeshInstance3D).mesh.surface_get_arrays(0))
	for v in vents:
		var m: Vector3 = v.mouth
		var darkest := 1.0
		for arr in tb_arrays:
			var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var cc: PackedColorArray = arr[Mesh.ARRAY_COLOR]
			for i in range(0, vv.size(), 1):
				var p: Vector3 = vv[i]
				if absf(p.y - m.y) < 0.7 and Vector2(p.x - m.x, p.z - m.z).length() < float(v.d) * 0.5 + 0.6:
					darkest = minf(darkest, cc[i].get_luminance())
		if darkest < 0.15:
			stained += 1
		else:
			print("  vent %s d %.2f at %s: darkest %.3f" % [v.kind, float(v.d), str(m), darkest])
	ok(stained == vents.size(), "soot round every flue's mouth (%d of %d)" % [stained, vents.size()])


## Where to stand to swing at holder `h`: a step out from a sconce's
## wall, a step back toward the room's way in from a hearth ring.
func _stand_by(main: CrawlerMain, h: Node3D) -> Vector3:
	var at := h.global_position
	var piece: Dictionary = main.lay.pieces[int(h.get_meta("piece"))]
	if str(h.get_meta("fire_holder")) == "sconce":
		return Vector3(at.x, at.y - float(CrawlerFires.HOLD.get("sconce_h_m", 1.7)), at.z) + h.global_basis.z * 0.8
	var d: Vector2 = piece.dir
	return Vector3(at.x - d.x, float(piece.y0), at.z - d.y)


## Frames of play: physics and process both, `n` of them.
func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _snuff(main: CrawlerMain) -> void:
	var p := main.player
	var t := p.torch
	# A floor of its own far from the tomb, to run on.
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000.0, 2.0, 4000.0)
	cs.shape = box
	ground.add_child(cs)
	ground.position = Vector3(0.0, -301.0, 0.0)
	main.add_child(ground)
	p.spawn_flat(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	await _frames(10)
	if not t.lit():
		t.light()
	var sp := TorchSnuff.sprint_rule()
	var g_after := float(sp.get("gutter_after_s", 6.0))
	var out_after := float(sp.get("out_after_s", 9.0))
	var recover := float(sp.get("recover_s", 2.0))
	# Walking and looking about a minute.
	Input.action_press("move_forward")
	var gmax := 0.0
	for i in 3600:
		p._yaw += 0.02 * sin(i * 0.01)
		p._pitch = 0.6 * sin(i * 0.013)
		await physics_frame
		gmax = maxf(gmax, t.snuff.gutter)
		if not t.lit():
			break
	ok(t.lit() and gmax == 0.0, "a minute of walking and looking about: lit, never guttering (§ET.7 walking_and_looking never)")
	# A sprint into the gutter, then stopping.
	Input.action_press("sprint")
	await _frames(int((g_after - 0.6) * 60.0))
	ok(t.lit() and t.snuff.gutter == 0.0, "%.1f s flat out: no gutter yet" % (g_after - 0.6))
	await _frames(int(1.4 * 60.0))
	ok(t.lit() and t.snuff.gutter > 0.2 and t.snuff.cause == "sprint", "past gutter_after_s (%.0f s) the coal gutters, still lit (warns first; gutter %.2f)" % [g_after, t.snuff.gutter])
	Input.action_release("sprint")
	await _frames(int((recover + 0.6) * 60.0))
	ok(t.lit() and t.snuff.gutter < 0.02 and t.snuff.sprint_s < 0.01, "stopping in the gutter, it recovers within recover_s (%.0f s)" % recover)
	# Flat out to the end.
	Input.action_press("sprint")
	var went := -1.0
	for i in int((out_after + 2.0) * 60.0):
		await physics_frame
		if not t.lit():
			went = i / 60.0
			break
	Input.action_release("sprint")
	Input.action_release("move_forward")
	ok(went > out_after - 0.5 and went < out_after + 1.0, "held flat out, it goes out at out_after_s (%.0f s): out at %.2f s" % [out_after, went])
	ok(str(GameLog.entries[-1].get("text", "")).contains("guttered"), "the log says how it went out")
	await _frames(30)
	# The airways.
	var aw := main.airways
	var strong: Dictionary = {}
	var ordinary: Dictionary = {}
	for m in aw.mouths:
		if bool(m.strong) and strong.is_empty():
			strong = m
		elif not bool(m.strong) and ordinary.is_empty():
			ordinary = m
	if not ordinary.is_empty():
		var d := aw.draft_at((ordinary.pos as Vector3) + (ordinary.normal as Vector3) * 1.0)
		ok((d.lean as Vector3).length() > 0.1 and float(d.gutter) <= float(Airways.A.get("gutter", 0.25)) + 0.001 and not bool(d.out), "an ordinary airway only leans the flame (lean %.2f m/s, gutter %.2f)" % [(d.lean as Vector3).length(), float(d.gutter)])
	ok(not strong.is_empty(), "this tomb has a strong airway mouth")
	if not strong.is_empty():
		var mp: Vector3 = strong.pos
		var nrm: Vector3 = strong.normal
		var piece: Dictionary = main.lay.pieces[int((main.lay.airways as Array)[aw.mouths.find(strong)].piece)]
		var fy := Delves.floor_of(piece, 0.0)
		# Stand so the flame is 2.5 m out on its line: the flame sits at
		# (0.3, 1.25, -0.4) in your frame, so back off along the line.
		var face := -nrm
		var at := mp + nrm * 2.5
		var stand := at - Basis(Vector3.UP, atan2(-face.x, -face.z)) * Vector3(0.3, 0.0, -0.4)
		stand.y = fy
		strong.t = 30.0
		p.spawn_flat(stand, atan2(-face.x, -face.z), 0.0)
		await _frames(5)
		t.light()
		var fp := t.flame_position()
		print("  the flame %.2f m out from the mouth, %.2f m off its line" % [(fp - mp).dot(nrm), ((fp - mp) - nrm * (fp - mp).dot(nrm)).length()])
		strong.t = 0.6
		await _frames(6)
		print("  warn: phase %s t %.2f draft %s gutter %.2f cause %s lit %s" % [strong.phase, strong.t, str(aw.draft_at(t.flame_position())), t.snuff.gutter, t.snuff.cause, t.lit()])
		ok(str(strong.phase) == "warn" and t.lit() and t.snuff.gutter > 0.2, "a strong mouth warns first: the moan, the dust, the coal guttering (gutter %.2f)" % t.snuff.gutter)
		ok((strong.dust as CPUParticles3D).emitting, "dust streams out of the mouth before the gust")
		await _frames(60)
		ok(not t.lit() and str(GameLog.entries[-1].get("text", "")).contains("draft"), "its gust puts out a torch in its line (§ET.7)")
		# Out of its line.
		strong.t = 30.0
		await _frames(2)
		p.spawn_flat(stand + nrm.cross(Vector3.UP).normalized() * 2.2, atan2(-face.x, -face.z), 0.0)
		await _frames(5)
		t.light()
		strong.t = -0.1
		await _frames(30)
		ok(t.lit(), "out of its line, the torch holds through the gust")
		# Behind cover: a stone between the mouth and the flame.
		strong.t = 30.0
		await _frames(2)
		p.spawn_flat(stand, atan2(-face.x, -face.z), 0.0)
		await _frames(5)
		t.light()
		var block := StaticBody3D.new()
		var bcs := CollisionShape3D.new()
		var bb := BoxShape3D.new()
		bb.size = Vector3(1.2, 1.2, 0.3)
		bcs.shape = bb
		block.add_child(bcs)
		main.add_child(block)
		block.global_transform = Transform3D(Basis.looking_at(nrm, Vector3.UP), mp + nrm * 1.2 + Vector3(0.0, 0.0, 0.0))
		await _frames(2)
		strong.t = -0.1
		await _frames(2)
		print("  cover: lit %s draft %s covered %s" % [t.lit(), str(aw.draft_at(t.flame_position())), aw._covered(mp + nrm * 0.35, t.flame_position())])
		await _frames(28)
		ok(t.lit(), "behind cover, the torch holds through the gust")
		block.queue_free()
		strong.t = 30.0
	# Water.
	p.spawn_flat(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	await _frames(5)
	t.light()
	var douse := float(Torch.D.get("douse_depth_m", 0.6))
	p.water_depth_m = douse - 0.08
	await _frames(30)
	ok(t.lit() and t.snuff.gutter > 0.3 and t.snuff.cause == "water", "wading toward douse_depth_m gutters it (gutter %.2f)" % t.snuff.gutter)
	p.water_depth_m = douse + 0.1
	await _frames(3)
	ok(not t.lit(), "past douse_depth_m the water puts it out (§AW)")
	p.water_depth_m = -INF


func _sprite(main: CrawlerMain) -> void:
	var r := main.rescuer
	var rows: Array = FigureSprite.SP.get("rows_deg", [-25, 0, 30])
	var around := int(FigureSprite.SP.get("around", 8))
	var n := r.frames
	var px := int(CrawlerMain.RES.get("px", 96))
	ok(r.atlas.get_width() == int(round(px * 0.75)) * around * n and r.atlas.get_height() == px * rows.size(), "the rescuer's sheet: %d around x %d heights x %d idle frames (%dx%d)" % [around, rows.size(), n, r.atlas.get_width(), r.atlas.get_height()])
	var foot := r.global_position
	var front := Vector3(-sin(r.yaw), 0.0, -cos(r.yaw))
	var left := front.cross(Vector3.UP) * -1.0
	var eye := foot + Vector3(0.0, r.eye_m, 0.0)
	var row_of := func(deg: float) -> int:
		for i in rows.size():
			if is_equal_approx(float(rows[i]), deg):
				return i
		return -1
	var row0: int = row_of.call(0.0)
	print("  frames: front %s left %s behind %s above %s below %s (yaw %.2f eye %.2f)" % [r.frame_for(eye + front * 3.0), r.frame_for(eye + left * 3.0), r.frame_for(eye - front * 3.0), r.frame_for(eye + front * 2.0 + Vector3(0.0, 2.0, 0.0)), r.frame_for(eye + front * 3.0 - Vector3(0.0, 1.6, 0.0)), r.yaw, r.eye_m])
	ok(r.frame_for(eye + front * 3.0) == Vector2i(0, row0), "in front at eye height: frame 0, the level row")
	ok(r.frame_for(eye + left * 3.0) == Vector2i(2, row0), "at its left: frame 2 of 8")
	ok(r.frame_for(eye - front * 3.0) == Vector2i(4, row0), "behind it: frame 4 of 8")
	ok(r.frame_for(eye + front * 2.0 + Vector3(0.0, 2.0, 0.0)).y == row_of.call(30.0), "from above: the row from above")
	ok(r.frame_for(eye + front * 3.0 - Vector3(0.0, 1.6, 0.0)).y == row_of.call(-25.0), "from below: the row from below")
	var to_hearth := (main.fires.hearth.global_position - foot)
	to_hearth.y = 0.0
	ok(front.dot(to_hearth.normalized()) > 0.9, "the rescuer stands facing the hearth")
	var seen := {}
	for i in 60:
		seen[r.idle_frame(i * 0.25)] = true
	ok(seen.size() == n, "its idle steps through all %d frames" % n)
