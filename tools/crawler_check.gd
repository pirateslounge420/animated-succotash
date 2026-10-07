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
##  4. the snuff rules (§ET.7 as amended by §EZ.1 and §EZ.5, torch.json
##     snuff): walking and looking about a minute never gutter it; it
##     glows brighter at a run; a minute of swinging it, and 120 s flat
##     out round the tomb whipping round every 4 s, leave it lit with no
##     gutter; an ordinary airway leans it and flickers it, never a
##     gutter; standing in a strong mouth's line through three gusts it
##     holds, unguttered and whipped hard (not out of the line or behind
##     cover), the moan and the dust as built; wading toward
##     douse_depth_m gutters it (redder, never bluer), past it douses it;
##  5. the one who found you (§FH): the live shared rig, not a sprite: a
##     HearthFolk holding a seated PlayerBody with its beast head, real
##     geometry (its triangles) and no FigureSprite anywhere in the tomb;
##     facing the hearth on its stone (the stone in the tomb's collision,
##     right under its hips); painted per §ES (no material on it with
##     specular above 0, roughness under 1 or a normal map; its painted
##     detail in big texels, folk_3d.texels_per_m); casting the fire's
##     shadow; breathing (its neck rises and falls); turning its hood to
##     you in front of it; something to bump into. And FigureSprite, kept
##     for creatures and bosses (§ET.8): a sheet's frame picked by where
##     the camera stands (front, side, behind, above, below), its idle
##     stepping;
##  6. the crosshair (§EX.7, Reticle): the one thing in the crawler's HUD
##     (no words, nothing else of the open world's), round the frame's
##     middle pixel and sized per hud.json reticle at the 480 and 270
##     presets, its dark edge one pixel round it, drawn over the grade
##     (no bloom); off with the Settings switch hud.reticle and under an
##     open panel (crawler_frames.gd checks its pixels on screen);
##  7. dousing your own torch (§FC.3, Torch.douse): F is the douse key;
##     pressed with a lit torch in hand it goes out and stays in your hand
##     (the same torch, a spare in the pack ahead of it), its burn
##     unchanged, one log line (stealth.json douse.log_line), not water;
##     nothing that watches for a carried flame sees it (Senses), and a
##     hunter's chase gives you up (Pursuit, torch_doused); F with
##     no flame does nothing; the cold torch relights at the hearth, a
##     relit sconce and a planted torch, as built;
##  8. the half-dark (§FC.4, HalfDark): its light navy, never warm, no
##     shadow, no shine, reaching black_m; off with the torch lit and
##     beside a lit fire in sight; on, eased in, with no flame near; a lit
##     torch behind a wall doesn't count, the same torch in sight does, and
##     so does a fire pot's tar burning on the floor;
##  9. sneaking (§FC.1, stealth.json sneak): the eye eases down and back up
##     over camera_ease_s, never a snap, and stays down under a low
##     ceiling; the crosshair closes into the dim ring and back, the ring
##     one clean pixel line round the frame's middle at 480 and 270 lines;
##     a crouched step at footstep_volume of a walking one's; the ledge
##     guard: a crouched walk at a 2 m drop stops at the lip, a diagonal
##     one slides along it, neither falls, a standing one falls, and
##     letting go of Shift steps off; and crouched through every door and
##     down every flight of the tomb, the guard never holds you.

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
	_firelight(main)
	await _relight(main)
	await _snuff(main)
	await _douse(main)
	await _half_dark(main)
	await _rescuer(main)
	_sprite_kept(main)
	await _reticle(main)
	await _sneak(main)
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


## The fitted-stone walls (design §EU; FittedStone, masonry.json).
func _masonry(main: CrawlerMain) -> void:
	var stones := int(main.tomb.get_meta("stones", 0))
	var faces := int(main.tomb.get_meta("faces", 0))
	ok(stones > 200 and faces > 20, "fitted stones on every seen wall face (%d stones on %d faces, %s for the %s)" % [stones, faces, FittedStone.preset_name(), main.lay.theme])
	# The partition is tight: the cells fill the wall, no gaps, no overlaps,
	# for both presets, after the relaxation.
	var rng := RandomNumberGenerator.new()
	var worst := 0.0
	var t0 := Time.get_ticks_msec()
	for preset in ["megalithic", "fitted_small"]:
		FittedStone.preset_override = preset
		for k in 6:
			rng.seed = 900 + k
			var l := rng.randf_range(2.0, 11.0)
			var h := rng.randf_range(2.5, 3.8)
			var area := 0.0
			for c in FittedStone.cells(l, h, rng):
				area += FittedStone._area(c[1])
			worst = maxf(worst, absf(area - l * h) / (l * h))
	FittedStone.preset_override = ""
	ok(worst < 0.002, "the stones' cells fill each wall exactly in both presets: shared edges, no gaps (worst %.4f of the wall; %d ms)" % [worst, Time.get_ticks_msec() - t0])
	# Every face its own seed: the two faces of one wall differ.
	var ra := RandomNumberGenerator.new()
	var rb := RandomNumberGenerator.new()
	ra.seed = hash([1, -1.0])
	rb.seed = hash([1, 1.0])
	var ca := FittedStone.cells(6.0, 3.0, ra)
	var cb := FittedStone.cells(6.0, 3.0, rb)
	ok((ca[0][0] as Vector2).distance_to(cb[0][0]) > 0.01, "every wall face its own stones: the two sides of a wall don't mirror")
	# A typical room's triangles (the tomb mesh inside each room's walls).
	var per_room: Array = []
	var arrs: Array = []
	for mi in main.tomb.get_children():
		if mi is MeshInstance3D:
			arrs.append((mi as MeshInstance3D).mesh.surface_get_arrays(0))
	for pc in main.lay.pieces:
		if str(pc.kind) != "room":
			continue
		var n := 0
		for arr in arrs:
			var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in range(0, vv.size(), 3):
				var c3 := (vv[i] + vv[i + 1] + vv[i + 2]) / 3.0
				var aa := Delves.along_across(pc, Vector2(c3.x, c3.z))
				if aa.x > -0.7 and aa.x < float(pc.len) + 0.7 and absf(aa.y) < float(pc.half) + 0.7 and c3.y > float(pc.y0) - 0.5 and c3.y < float(pc.y0) + float(pc.h) + 0.5:
					n += 1
		per_room.append(n)
	per_room.sort()
	if not per_room.is_empty():
		print("  triangles in a room: median %d (fewest %d, most %d, %d rooms); the whole tomb %d" % [per_room[per_room.size() / 2], per_room[0], per_room[-1], per_room.size(), int(main.tomb.get_meta("triangles", 0))])
	# The climate: the theme's world's biome through vines.json climate.
	var cl_tomb := FittedStone.climate_of("tomb")
	var cl_snow := FittedStone.climate_of("snow_ruins")
	print("  climate: tomb %s (%.2f, %.0f C), snow_ruins %s (%.2f, %.0f C)" % [cl_tomb.from, cl_tomb.moisture, cl_tomb.temp_c, cl_snow.from, cl_snow.moisture, cl_snow.temp_c])
	ok(str(cl_snow.from) == "tundra" and FittedStone.moss_of(Vector2(cl_snow.moisture, cl_snow.temp_c)) == 0.0, "the snow ruins take the tundra world's climate: too cold for moss")
	# The moisture differs from place to place, and the overgrowth with it.
	var lo := 1.0
	var hi := 0.0
	for pc in main.lay.pieces:
		var c: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * 0.5
		var cl := FittedStone.climate_at(str(main.lay.theme), int(main.lay.seed), Vector3(c.x, float(pc.y0), c.y))
		var mk := FittedStone.moss_of(cl)
		lo = minf(lo, mk)
		hi = maxf(hi, mk)
	print("  the tomb's moss runs %.2f to %.2f" % [lo, hi])
	ok(hi - lo > 0.15, "the moss differs from place to place (%.2f to %.2f)" % [lo, hi])
	ok(FittedStone.moss_of(Vector2(0.2, 14.0)) == 0.0 and FittedStone.moss_of(Vector2(0.95, 14.0)) > 0.9, "no moss where it's dry, full moss where it's wet (vines.json climate)")
	# One wall dressed in a desert and in a damp place: dust and bare stone,
	# then vines.
	var out := {}
	for wi in 2:
		var cl2: Vector2 = [Vector2(0.1, 26.0), Vector2(0.9, 14.0)][wi]
		var tb := TombBuild.new()
		var r2 := RandomNumberGenerator.new()
		r2.seed = 77
		FittedStone.face(tb, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, 8.0, -0.1, 3.0, 0.0, cl2, r2)
		var leaf := 0
		for m in tb._m:
			if int(round(m.x)) == RuinBuilder.LEAF_M:
				leaf += 1
		out[wi] = [tb._boulder_anchors.size(), leaf / 3]
	ok(int(out[0][0]) > 0 and int(out[0][1]) == 0, "a desert wall: drifted sand at its foot and corners, no vines (%d drifts)" % out[0][0])
	ok(int(out[1][0]) == 0 and int(out[1][1]) > 0, "a damp wall: vines from its top and cracks, no sand (%d leaf triangles)" % out[1][1])


## One firelight (design §EX.6): every fire light in the built tomb (the
## hearth, every holder, the torch in hand) is the hearth's amber, and
## torch.json's colour is look.json's.
func _firelight(main: CrawlerMain) -> void:
	var want := Torch.fire_color()
	var lights: Array = []
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		# (The half-dark's light at your eye is no fire: _half_dark.)
		if n is OmniLight3D and not n.has_meta("half_dark"):
			lights.append(n)
		stack.append_array(n.get_children())
	var odd := 0
	for l in lights:
		if not (l as OmniLight3D).light_color.is_equal_approx(want):
			odd += 1
			print("  light %s: #%s" % [(l as Node).get_path(), (l as OmniLight3D).light_color.to_html(false)])
	ok(lights.size() >= (main.lay.holders as Array).size() + 2 and odd == 0, "one firelight: all %d fire lights in the tomb (hearth, holders, the torch) are #%s" % [lights.size(), want.to_html(false)])
	ok(Color(str(Torch.L.get("color", ""))).is_equal_approx(want), "torch.json light.color is look.json fire.light.color (#%s)" % want.to_html(false))


## Every built-in fire's own vent (design §EV; TombKit, Vents, smoke.json
## vents).
func _vents(main: CrawlerMain) -> void:
	var lay := main.lay
	var vents: Array = lay.vents
	var V: Dictionary = TombKit.vents_table()
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
	var fade: Array = (V.get("daylight", {}) as Dictionary).get("fade_depth_m", [3.0, 25.0])
	ok(TombKit.daylight_share(float(fade[0])) == 1.0 and TombKit.daylight_share(float(fade[1]) + 0.5) == 0.0, "full daylight down a shaft %.0f m long, none past %.0f m (daylight.fade_depth_m)" % [fade[0], fade[1]])
	# Never a way in or out (passable false): every mouth out of reach
	# overhead; and each keeps what it becomes on the surface (§EV.4).
	var reachable := 0
	var outlets := true
	for v in vents:
		var pc: Dictionary = lay.pieces[int(v.piece)]
		var m: Vector3 = v.mouth
		if m.y - Delves.floor_of(pc, Delves.along_across(pc, Vector2(m.x, m.z)).x) < 2.4:
			reachable += 1
		if str(v.get("outlet", "")) == "":
			outlets = false
	ok(reachable == 0, "no vent is a way out: every mouth overhead, out of reach (%d low)" % reachable)
	ok(outlets, "every vent knows its outlet for the surface to come (a shaft's stack, a flue's slot; §EV.4 with §EW)")
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
	Input.action_release("move_forward")
	ok(t.lit() and gmax == 0.0, "a minute of walking and looking about: lit, never guttering (§ET.7 walking_and_looking never)")
	# Running feeds the coal air (§EZ.1): the light over 4 s (two of the
	# coal's breaths) standing, then 4 s flat out.
	await _frames(30)
	var e_stand := 0.0
	for i in 240:
		await physics_frame
		e_stand += t._light.light_energy / 240.0
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var e_run := 0.0
	for i in 240:
		await physics_frame
		e_run += t._light.light_energy / 240.0
	Input.action_release("sprint")
	Input.action_release("move_forward")
	ok(t.lit() and e_run > e_stand * 1.03, "the torch glows brighter at a run: mean light energy %.2f flat out, %.2f standing (x%.3f; ember.air_brighten %.2f, §EZ.1)" % [e_run, e_stand, e_run / maxf(e_stand, 1e-4), float(Torch.EMBER.get("air_brighten", 0.18))])
	await _frames(30)
	# A minute of swinging it (§CN), looking about as you swing.
	var swings0 := t.swings
	var held := false
	var lit_all := true
	gmax = 0.0
	for i in 3600:
		p._yaw += 0.03 * sin(i * 0.02)
		p._pitch = 0.5 * sin(i * 0.017)
		if held:
			Input.action_release("shoot")
			held = false
		elif t._swing <= 0.0:
			Input.action_press("shoot")
			held = true
		await physics_frame
		gmax = maxf(gmax, t.snuff.gutter)
		lit_all = lit_all and t.lit()
	Input.action_release("shoot")
	ok(lit_all and gmax == 0.0 and t.swings - swings0 >= 30, "a minute of swinging it (%d swings, §CN): lit, never guttering (§EZ.1)" % (t.swings - swings0))
	# 120 s flat out round the tomb (every door depth-first from the hearth
	# room and back, again and again), whipping round every 4 s. Beside it,
	# §ET.7's removed sprint rule is kept on paper (a sprint held 6 s
	# guttered the torch, 9 s put it out, stopping drained it in 2 s), to
	# show when it would have put the torch out.
	var pts := _tour(main.lay)
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), 0.0)
	await _frames(5)
	if not t.lit():
		t.light()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var wi := 0
	var on_point := 0
	var stalls_here := 0
	var side := 1.0
	var window := 0
	var mark_d := INF
	var follow := false
	var follow_for := 0
	var detours := 0
	var skips := 0
	var stuck_in := {}
	var spin := 0
	var whips := 0
	var got := 0
	var at_sprint := 0
	var bank := 0.0
	var old_out := -1.0
	var dist := 0.0
	var in_draft := 0
	var flick_max := 0.0
	var gust_frames := 0
	var burn_gutter := false
	var last := p.global_position
	gmax = 0.0
	lit_all = true
	for i in 7200:
		var target: Vector3 = pts[wi]
		var to := Vector3(target.x - p.global_position.x, 0.0, target.z - p.global_position.z)
		if to.length() < 0.6:
			wi = (wi + 1) % pts.size()
			got += 1
			on_point = 0
			stalls_here = 0
			side = 1.0
			window = 0
			mark_d = INF
			follow = false
			target = pts[wi]
			to = Vector3(target.x - p.global_position.x, 0.0, target.z - p.global_position.z)
		if i % 240 == 120:
			spin = 15
			whips += 1
		if spin > 0:
			# A full turn in a quarter of a second.
			p._yaw += TAU / 15.0
			spin -= 1
		elif follow:
			# Round what's in the way: the clear heading nearest the point,
			# turning to one side, until the straight line is clear again.
			follow_for += 1
			if _clear_ahead(p, to, minf(to.length(), 1.5)):
				follow = false
				p._yaw = atan2(-to.x, -to.z)
			else:
				p._yaw = _clear_heading(p, to, side)
			if follow_for == 180:
				side = -side
		elif to.length() > 0.01:
			p._yaw = atan2(-to.x, -to.z)
		p._pitch = 0.5 * sin(i * 0.05)
		await physics_frame
		var now := p.global_position
		dist += Vector2(now.x - last.x, now.z - last.z).length()
		last = now
		var flat := Vector3(p.velocity.x, 0.0, p.velocity.z).length()
		if p.sprinting and flat > PlanetPlayer.WALK_SPEED * 0.9:
			at_sprint += 1
			bank += 1.0 / 60.0
		else:
			bank = maxf(bank - 1.0 / 60.0 * 6.0 / 2.0, 0.0)
		if bank >= 9.0 and old_out < 0.0:
			old_out = (i + 1) / 60.0
		gmax = maxf(gmax, t.snuff.gutter)
		lit_all = lit_all and t.lit()
		burn_gutter = burn_gutter or Torch.guttering(t.item())
		if t.snuff.lean.length() > 0.05:
			in_draft += 1
		flick_max = maxf(flick_max, t.snuff.flicker)
		if t.snuff.gust:
			gust_frames += 1
		# No headway for a moment (the hearth, a coffin, rubble): follow round
		# it; after 6 s on one point, skip to it.
		on_point += 1
		var d_now := Vector2(target.x - now.x, target.z - now.z).length()
		if spin > 0 or follow:
			window = 0
			mark_d = INF
		else:
			window += 1
			if window >= 18:
				if d_now > mark_d - 0.25:
					stalls_here += 1
					if stalls_here > 1:
						side = -side
					follow = true
					follow_for = 0
					detours += 1
				mark_d = d_now
				window = 0
		if on_point > 360:
			skips += 1
			var where := _piece_at(main.lay, now)
			stuck_in[where] = int(stuck_in.get(where, 0)) + 1
			p.spawn_flat(target, p._yaw, p._pitch)
			last = target
			on_point = 0
			follow = false
		if not t.lit():
			break
	Input.action_release("sprint")
	Input.action_release("move_forward")
	print("  the run: %d points on the tour, %d reached; %d times round something in the way, %d points skipped to %s; %.1f s in an airway's draft (flicker up to %.2f), %.1f s in a strong gust" % [pts.size(), got, detours, skips, str(stuck_in), in_draft / 60.0, flick_max, gust_frames / 60.0])
	ok(lit_all and gmax == 0.0 and not burn_gutter, "120 s flat out round the tomb (%.0f m, %d whip turns): lit, gutter 0 throughout (§EZ.1 moving_fast never)" % [dist, whips])
	# A real sprint, not a runner stuck against a wall (the turns, the
	# whips and the odd prop cost 10-20 s of the 120).
	ok(at_sprint / 60.0 >= 90.0 and old_out > 0.0, "a real sprint: %.0f s of the 120 at a sprint by the removed rule's own measure, which would have put the torch out %.1f s in" % [at_sprint / 60.0, old_out])
	await _frames(30)
	# The airways move the flame and never put it out (§EZ.5).
	var aw := main.airways
	var strong: Dictionary = {}
	var ordinary: Dictionary = {}
	for m in aw.mouths:
		if bool(m.strong) and strong.is_empty():
			strong = m
		elif not bool(m.strong) and ordinary.is_empty():
			ordinary = m
	var most := float(Airways.A.get("flicker", 0.25))
	if not ordinary.is_empty():
		var d := aw.draft_at((ordinary.pos as Vector3) + (ordinary.normal as Vector3) * 1.0)
		ok((d.lean as Vector3).length() > 0.1 and float(d.flicker) > 0.0 and float(d.flicker) <= most + 0.001 and not d.has("out") and not d.has("gutter"), "an ordinary airway leans the flame and quickens its flicker, never a gutter (lean %.2f m/s, flicker %.2f)" % [(d.lean as Vector3).length(), float(d.flicker)])
		# Stand under it with the torch lit.
		var opc: Dictionary = main.lay.pieces[int((main.lay.airways as Array)[aw.mouths.find(ordinary)].piece)]
		var under := (ordinary.pos as Vector3) + (ordinary.normal as Vector3) * 0.9
		under.y = Delves.floor_of(opc, Delves.along_across(opc, Vector2(under.x, under.z)).x)
		var onrm: Vector3 = ordinary.normal
		p.spawn_flat(under, atan2(onrm.x, onrm.z), 0.0)
		await _frames(5)
		t.light()
		var e_lo := INF
		var e_hi := 0.0
		gmax = 0.0
		for i in 120:
			await physics_frame
			gmax = maxf(gmax, t.snuff.gutter)
			e_lo = minf(e_lo, t._light.light_energy)
			e_hi = maxf(e_hi, t._light.light_energy)
		ok(t.lit() and gmax == 0.0 and t.snuff.flicker > 0.0 and t.snuff.lean.length() > 0.1, "under it the torch leans and flickers (flicker %.2f, light %.2f-%.2f) and never gutters" % [t.snuff.flicker, e_lo, e_hi])
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
		var warn_s := float(Airways.SN.get("warn_s", 1.5))
		var gust_s := float(Airways.A.get("gust_s", 2.2))
		var voice: AudioStreamPlayer3D = strong.voice
		var lit_g := true
		var g_g := 0.0
		var lean_max := 0.0
		var whipped := 0
		var dusty := 0
		var moaned := 0
		for k in 3:
			strong.t = warn_s + 0.4
			var saw_gust := false
			var saw_dust := false
			var loud := -80.0
			for i in int((warn_s + 0.4 + gust_s + 1.0) * 60.0):
				await physics_frame
				lit_g = lit_g and t.lit()
				g_g = maxf(g_g, t.snuff.gutter)
				if str(strong.phase) == "warn":
					saw_dust = saw_dust or (strong.dust as CPUParticles3D).emitting
					loud = maxf(loud, voice.volume_db)
				if t.snuff.gust:
					saw_gust = true
					lean_max = maxf(lean_max, t.snuff.lean.length())
			whipped += 1 if saw_gust else 0
			dusty += 1 if saw_dust else 0
			moaned += 1 if loud > -12.0 else 0
		ok(lit_g and g_g == 0.0 and whipped == 3, "standing in a strong mouth's line through three gusts: lit, never guttering (§EZ.5; %d of 3 gusts reached the flame)" % whipped)
		ok(lean_max > 3.0, "each gust whips the torch hard away from the mouth (%.1f m/s at the flame: the coal's smoke streams flat)" % lean_max)
		ok(dusty == 3 and moaned == 3, "the mouth still moans and streams dust before every gust, as built (%d of 3, %d of 3)" % [moaned, dusty])
		# Out of its line, and behind cover, the gust doesn't reach it.
		strong.t = 30.0
		await _frames(2)
		p.spawn_flat(stand + nrm.cross(Vector3.UP).normalized() * 2.2, atan2(-face.x, -face.z), 0.0)
		await _frames(5)
		strong.t = -0.1
		var reached := false
		for i in 30:
			await physics_frame
			reached = reached or t.snuff.gust
		ok(t.lit() and not reached, "out of its line the gust passes the torch by")
		strong.t = 30.0
		await _frames(2)
		p.spawn_flat(stand, atan2(-face.x, -face.z), 0.0)
		await _frames(5)
		var block := StaticBody3D.new()
		var bcs := CollisionShape3D.new()
		var bb := BoxShape3D.new()
		bb.size = Vector3(1.2, 1.2, 0.3)
		bcs.shape = bb
		block.add_child(bcs)
		main.add_child(block)
		block.global_transform = Transform3D(Basis.looking_at(nrm, Vector3.UP), mp + nrm * 1.2)
		await _frames(2)
		strong.t = -0.1
		reached = false
		for i in 30:
			await physics_frame
			reached = reached or t.snuff.gust
		print("  cover: lit %s draft %s covered %s" % [t.lit(), str(aw.draft_at(t.flame_position())), aw._covered(mp + nrm * 0.35, t.flame_position())])
		ok(t.lit() and not reached, "behind cover the gust doesn't reach it (§ET.7 shelter)")
		block.queue_free()
		strong.t = 30.0
	# Water: the one thing that puts it out (§EZ.5), warning first.
	p.spawn_flat(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	await _frames(5)
	t.light()
	await _frames(5)
	var steady: Color = t._light.light_color
	var douse := float(Torch.D.get("douse_depth_m", 0.6))
	p.water_depth_m = douse - 0.08
	await _frames(30)
	ok(t.lit() and t.snuff.gutter > 0.3 and t.snuff.cause == "water", "wading toward douse_depth_m gutters it, still lit (gutter %.2f)" % t.snuff.gutter)
	# Guttering reddens, never cools (§EX.6).
	var gut: Color = t._light.light_color
	ok(gut.b / maxf(gut.r, 1e-4) <= steady.b / maxf(steady.r, 1e-4) + 1e-4 and gut.g / maxf(gut.r, 1e-4) <= steady.g / maxf(steady.r, 1e-4) + 1e-4, "a guttering torch's light is redder, never bluer (steady #%s, guttering #%s)" % [steady.to_html(false), gut.to_html(false)])
	p.water_depth_m = douse + 0.1
	await _frames(3)
	ok(not t.lit() and str(GameLog.entries[-1].get("text", "")).contains("water"), "past douse_depth_m the water puts it out (§AW; the one way out now, §EZ.5)")
	p.water_depth_m = -INF


## Can your own body move `m` metres along `toward` (flat), lifted clear
## of the floor's lips?
func _clear_ahead(p: CrawlerPlayer, toward: Vector3, m: float) -> bool:
	var dir := Vector3(toward.x, 0.0, toward.z).normalized()
	return not p.test_move(p.global_transform.translated(Vector3(0.0, 0.15, 0.0)), dir * maxf(m, 0.3))


## The clear heading (0.7 m along it) nearest `toward`, turning to `side`
## (+1 left, -1 right) in 15° steps: so a body following it slides round
## what's in the way.
func _clear_heading(p: CrawlerPlayer, toward: Vector3, side: float) -> float:
	var base := atan2(-toward.x, -toward.z)
	var from := p.global_transform.translated(Vector3(0.0, 0.15, 0.0))
	for k in range(1, 13):
		var yaw: float = base + side * deg_to_rad(15.0 * k)
		if not p.test_move(from, Vector3(-sin(yaw), 0.0, -cos(yaw)) * 0.7):
			return yaw
	return base + PI


## Which piece `pos` is in: its room's kind, or corridor / stair.
func _piece_at(lay: Dictionary, pos: Vector3) -> String:
	for pc in lay.pieces:
		var aa := Delves.along_across(pc, Vector2(pos.x, pos.z))
		if aa.x >= -0.05 and aa.x <= float(pc.len) + 0.05 and absf(aa.y) <= float(pc.half) + 0.05:
			return str(pc.get("room_kind", pc.kind))
	return "between"


## A run round the tomb: every door crossed depth-first from the hearth
## room and back, as points a step either side of it at its floor.
func _tour(lay: Dictionary) -> Array:
	var pts: Array = []
	_tour_from(lay, 0, {0: true}, pts)
	return pts


func _tour_from(lay: Dictionary, id: int, seen: Dictionary, pts: Array) -> void:
	for di in lay.pieces[id].doors:
		var d: Dictionary = lay.doors[di]
		var o := int(d.b) if int(d.a) == id else int(d.a)
		if seen.has(o):
			continue
		seen[o] = true
		var n: Vector2 = (d.n as Vector2) if int(d.a) == id else -(d.n as Vector2)
		var dp: Vector2 = d.p
		var y := float(d.y)
		var near := Vector3(dp.x - n.x * 0.9, y, dp.y - n.y * 0.9)
		var far := Vector3(dp.x + n.x * 0.9, y, dp.y + n.y * 0.9)
		pts.append(near)
		pts.append(far)
		_tour_from(lay, o, seen, pts)
		pts.append(far)
		pts.append(near)


## Press F as the player would: the key through the input, a couple of
## frames for it to land.
func _press_f() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F
		ev.keycode = KEY_F
		ev.pressed = down
		Input.parse_input_event(ev)
		for i in 2:
			await process_frame


## A lit torch stood at `at` (scene), as PlantedTorch.plant stands one (the
## crawler has no world root to hang it from).
func _planted(main: CrawlerMain, at: Vector3) -> PlantedTorch:
	var pt := PlantedTorch.new()
	pt.item = Inventory.make("torch", {"lit": true, "burn_left_min": 40.0})
	main.add_child(pt)
	pt.global_position = at
	PlantedTorch.all.append(pt)
	return pt


func _unplant(pt: PlantedTorch) -> void:
	PlantedTorch.all.erase(pt)
	pt.queue_free()


## Dousing your own torch (design 6 Oct §FC.3; Torch.douse, F).
func _douse(main: CrawlerMain) -> void:
	var p := main.player
	var t := p.torch
	var fires := main.fires
	var hands = JSON.parse_string(FileAccess.get_file_as_string("res://data/hands.json"))
	var keyed := false
	for ev in InputMap.action_get_events("douse"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_F:
			keyed = true
	ok(keyed and str((hands as Dictionary).get("douse_key", "")) == "F", "the douse action is on F (hands.json douse_key)")
	# The torch is out (the water, at the end of the snuff rules): relit at
	# the hearth.
	var hp := fires.hearth.global_position
	_place_facing(p, hp + Vector3(0.0, 0.0, 1.0), hp)
	await _frames(5)
	ok(not t.lit() and t.pass_flame() == "torch" and t.lit(), "the torch the water put out relights at the hearth")
	# A spare in the pack ahead of the torch in hand.
	var held := t.item()
	var slots: Array = p.inventory.carried
	for i in slots.size():
		if is_same(slots[i], held):
			slots[i] = null
	p.inventory.add(Inventory.make("torch"))
	p.inventory.add(held)
	ok(is_same(t.item(), held) and t.lit(), "a spare goes in the pack ahead of the lit torch in hand")
	# Watchers by night (Senses: a lurker 20 m off sees a lit torch from
	# light_sight_m; it neither sees you dark nor smells you).
	Senses.override = {"daylight": 0.0, "moonlight": 0.0}
	var eye := p.eye_position() + Vector3(20.0, 0.0, 0.0)
	var sensed_lit := Senses.can_sense("lurker", eye, p, 0.0)
	var lights_lit := Senses.lights().size()
	# F, the physics held still so the burn can't move.
	p.set_physics_process(false)
	var burn := float(held.get("burn_left_min", -1.0))
	var n_log := GameLog.entries.size()
	var line := str(Torch.DOUSE.get("log_line", ""))
	# A hunter's chase (§FD, Pursuit): one whose gives_up says
	# torch_doused loses you the moment your torch goes out.
	var chase := Pursuit.new(main, {"torch_doused": true})
	chase.notice(t.lit())
	var chased := not chase.step(0.1, true, 5.0, t.lit())
	await _press_f()
	ok(not t.lit() and t.in_hand() and p.weapon == "torch" and is_same(t.item(), held), "F smothers the lit torch: out, and still the one in your hand")
	ok(float(held.get("burn_left_min", -2.0)) == burn, "its burn is unchanged (%.4f min)" % burn)
	ok(GameLog.entries.size() == n_log + 1 and str(GameLog.entries[-1].get("text", "")) == line and line != "", "one log line: \"%s\"" % line)
	ok(t.last_out == "smothered" and not str(GameLog.entries[-1].get("text", "")).contains("water"), "smothered, not water (its reason '%s')" % t.last_out)
	ok(sensed_lit == "light" and lights_lit >= 1 and Senses.lights().is_empty() and Senses.can_sense("lurker", eye, p, 0.0) == "" and Torch.light_at(p.global_position) == 0.0, "a doused torch gives nothing away: the lurker saw its light (%s), now nothing (%s)" % [sensed_lit, Senses.can_sense("lurker", eye, p, 0.0)])
	Senses.override = {}
	var lost := chase.step(0.1, true, 5.0, t.lit())
	ok(chased and lost and chase.why == "torch_doused" and not chase.on, "a hunter's chase gives you up the moment you smother it (Pursuit, gives_up torch_doused: '%s')" % chase.why)
	await _press_f()
	ok(not t.lit() and GameLog.entries.size() == n_log + 1, "F with no flame does nothing")
	p.set_physics_process(true)
	await _frames(60)
	ok(float(held.get("burn_left_min", -2.0)) == burn, "out, it keeps its burn")
	# Relight: the hearth, a relit sconce, a planted torch (§CN, as built).
	ok(t.pass_flame() == "torch" and t.lit() and is_same(t.item(), held) and float(held.get("burn_left_min", -2.0)) == burn, "the smothered torch relights at the hearth, the same torch, its burn as it was")
	var sconce: Node3D = null
	for h in fires.holders:
		if str(h.get_meta("fire_holder")) == "sconce" and FireStore.is_lit(h):
			sconce = h
			break
	ok(sconce != null, "a relit sconce to relight at")
	if sconce != null:
		_place_facing(p, _stand_by(main, sconce), sconce.global_position)
		await _frames(5)
		ok(t.douse() and not t.lit() and t.pass_flame() == "torch" and t.lit(), "smothered by a relit sconce, it relights at the sconce")
	p.spawn_flat(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	await _frames(5)
	var pt := _planted(main, Vector3(0.0, -300.0, -1.0))
	await _frames(2)
	ok(t.douse() and not t.lit() and t.pass_flame() == "torch" and t.lit(), "smothered by a planted torch, it relights at the planted torch")
	_unplant(pt)
	await _frames(2)


## The half-dark (design 6 Oct §FC.4; HalfDark, crawler.json dark).
func _half_dark(main: CrawlerMain) -> void:
	var p := main.player
	var t := p.torch
	var hd := main.half_dark
	var l := hd.light
	var c := l.light_color
	ok(c.is_equal_approx(HalfDark.color()) and c.b > c.r * 2.0 and c.b > c.g * 2.0, "the half-dark's light is the dark's navy (#%s), never warm" % c.to_html(false))
	ok(not l.shadow_enabled and l.light_specular == 0.0 and is_equal_approx(l.omni_range, HalfDark.black_m()), "no shadow, no shine, nothing past black_m (%.0f m)" % HalfDark.black_m())
	var adjust := float(HalfDark.DARK.get("adjust_s", 1.2))
	var fade := float(HalfDark.DARK.get("fade_s", 0.4))
	# Away from every fire (the floor of its own below the tomb).
	p.spawn_flat(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	if not t.lit():
		t.light()
	await _frames(int(adjust * 60.0) + 10)
	ok(hd.strength == 0.0 and not l.visible, "your torch lit: nothing added (strength %.2f)" % hd.strength)
	t.douse()
	await _frames(int(adjust * 30.0))
	var half := hd.strength
	await _frames(int(adjust * 30.0) + 10)
	ok(half > 0.2 and half < 0.8 and hd.strength == 1.0 and l.visible and is_equal_approx(l.light_energy, HalfDark.energy()), "doused with no flame near, the dark eases readable over adjust_s (%.2f halfway, then %.2f; energy %.2f)" % [half, hd.strength, l.light_energy])
	t.light()
	await _frames(1)
	ok(hd.strength == 0.0 and not l.visible, "the torch relit: off at once")
	# A lit planted torch 3 m off: behind a wall it doesn't count, in sight
	# it does.
	t.douse()
	var pt := _planted(main, Vector3(0.0, -300.0, -3.0))
	var wall := StaticBody3D.new()
	wall.collision_layer = PropCollision.WORLD_LAYER
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(4.0, 4.0, 0.3)
	cs.shape = bx
	wall.add_child(cs)
	main.add_child(wall)
	wall.global_position = Vector3(0.0, -299.0, -1.5)
	await _frames(int(adjust * 60.0) + 10)
	ok(hd.strength == 1.0, "a lit torch 3 m off behind a wall is no flame near: the dark readable (%.2f)" % hd.strength)
	wall.queue_free()
	await _frames(int(fade * 60.0) + 10)
	ok(hd.strength == 0.0 and not l.visible, "the same torch in sight: nothing added (%.2f)" % hd.strength)
	_unplant(pt)
	# A fire pot's tar burning on the floor 3 m off (§FA.3): fire too.
	await _frames(int(adjust * 60.0) + 10)
	var back := hd.strength
	main.fire_pots.burst(Vector3(0.0, -299.75, -3.0), "tar", null, Vector3.UP)
	await _frames(int(fade * 60.0) + 10)
	ok(back == 1.0 and hd.strength == 0.0 and not l.visible, "a fire pot's tar burning 3 m off is a flame near too: nothing added (%.2f, from %.2f)" % [hd.strength, back])
	# Beside a relit sconce, doused: its light is on you.
	var sconce: Node3D = null
	for h in main.fires.holders:
		if str(h.get_meta("fire_holder")) == "sconce" and FireStore.is_lit(h):
			sconce = h
			break
	if sconce != null:
		await _frames(int(adjust * 60.0) + 10)
		_place_facing(p, _stand_by(main, sconce), sconce.global_position)
		await _frames(int(fade * 60.0) + 10)
		ok(hd.strength == 0.0, "beside a relit sconce, doused: the sconce's light, nothing added (%.2f)" % hd.strength)
	# Waking by the hearth.
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), -0.32)
	await _frames(int(fade * 60.0) + 10)
	ok(hd.strength == 0.0, "by the lit hearth: nothing added (%.2f)" % hd.strength)


## The materials on every mesh under `n`: [GeometryInstance3D, Material].
func _materials_under(n: Node) -> Array:
	var out: Array = []
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		if g.material_override != null:
			out.append([g, g.material_override])
		var mi := g as MeshInstance3D
		if mi != null and mi.mesh != null and g.material_override == null:
			for si in mi.mesh.get_surface_count():
				var m: Material = mi.get_surface_override_material(si)
				if m == null:
					m = mi.mesh.surface_get_material(si)
				if m != null:
					out.append([g, m])
	return out


## Diffuse only (§ES.2): "" if `m` has no specular above 0, no roughness
## under 1 and no normal map; else what's wrong.
func _diffuse_only(m: Material) -> String:
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		if b.specular_mode != BaseMaterial3D.SPECULAR_DISABLED and b.metallic_specular > 0.0:
			return "specular %.2f" % b.metallic_specular
		if b.roughness < 1.0:
			return "roughness %.2f" % b.roughness
		if b.normal_enabled:
			return "a normal map"
		return ""
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		if sh == null:
			return "no shader"
		var code := sh.code
		var rm := RegEx.create_from_string("render_mode([^;]*);").search(code)
		var modes := rm.get_string(1) if rm != null else ""
		if not modes.contains("specular_disabled") and not modes.contains("unshaded"):
			return "%s: specular not disabled" % sh.resource_path
		for a in RegEx.create_from_string("ROUGHNESS\\s*=\\s*([^;]+);").search_all(code):
			if a.get_string(1).strip_edges() != "1.0":
				return "%s: ROUGHNESS = %s" % [sh.resource_path, a.get_string(1)]
		for a in RegEx.create_from_string("SPECULAR\\s*=\\s*([^;]+);").search_all(code):
			if a.get_string(1).strip_edges() != "0.0":
				return "%s: SPECULAR = %s" % [sh.resource_path, a.get_string(1)]
		if code.contains("NORMAL_MAP"):
			return "%s: a normal map" % sh.resource_path
		return ""
	return "a %s" % m.get_class()


func _rescuer(main: CrawlerMain) -> void:
	var r := main.rescuer
	var p := main.player
	# Back on the mat, across the fire from it (the rig poses only near the
	# eyes, as every figure does).
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), -0.32)
	await _frames(30)
	# The live rig, not a sprite (§FH).
	var sprites := 0
	for n in main.find_children("*", "", true, false):
		if n is FigureSprite:
			sprites += 1
	var body := r.body if r != null else null
	ok(r is HearthFolk and body is PlayerBody and r.get_parent() == main and sprites == 0, "the rescuer is the live 3D rig (a HearthFolk holding the shared PlayerBody), and no FigureSprite in the tomb (%d)" % sprites)
	if body == null:
		return
	var beast_mi := body.head.get_node_or_null("Beast") as MeshInstance3D
	ok(body.seated and r.beast != "" and body.beast == r.beast and beast_mi != null and beast_mi.is_visible_in_tree(), "seated, wearing its beast's head: %s (§EO, §EQ)" % r.beast)
	var tris := body.triangles
	if beast_mi != null:
		tris += int(beast_mi.mesh.get_meta("tris", 0))
	var parts := 0
	for g in r.find_children("*", "GeometryInstance3D", true, false):
		if (g as GeometryInstance3D).is_visible_in_tree():
			parts += 1
	print("  the rescuer: %s, %d triangles in %d parts, scale %.2f, its cloth %.0f µs a step" % [r.beast, tris, parts, r.k, body.sim_usec_avg])
	# (The rig is ~4.4k against §ES.2's ~1,500, an open call for Mike since
	# the §ES pass; this only holds it there.)
	ok(tris >= 600 and tris <= 6000, "real geometry, the shared rig's own: %d triangles (§ES.2's ~1,500 is Mike's open call)" % tris)
	# Facing the hearth, on its stone.
	var to_hearth := main.fires.hearth.global_position - r.global_position
	to_hearth.y = 0.0
	ok(r.front().dot(to_hearth.normalized()) > 0.9, "it sits facing the hearth")
	var blockers: Array[RID] = [p.get_rid()]
	for b in r.find_children("Blocker", "StaticBody3D", true, false):
		blockers.append((b as StaticBody3D).get_rid())
	# Chest high, from 1 m in front of it: the blocker stops the ray at it.
	var chest := r.global_position + Vector3.UP * 0.7
	var bump := _ray(chest + r.front() * 1.0, chest - r.front() * 0.3, [p.get_rid()])
	var bump_m := (bump.position as Vector3).distance_to(chest + r.front() * 1.0) if not bump.is_empty() else INF
	ok(blockers.size() == 2 and not bump.is_empty() and Hitboxes.creature_of(bump.collider) == r and bump_m > 0.5 and bump_m < 0.9, "something to bump into, round it (the rig's blocker, %.2f m in from 1 m)" % bump_m)
	var seat := HearthFolk.seat((main.lay.rescuer as Array)[0], float((main.lay.rescuer as Array)[1]))
	var sc: Vector3 = (seat.xf as Transform3D).origin
	var hit := _ray(Vector3(sc.x, 1.5, sc.z), Vector3(sc.x, -0.5, sc.z), blockers)
	var hips := (body.get_node("Hips") as Node3D).global_position
	var under := hips.y - 0.075 * r.k
	var top := float((hit.get("position", Vector3.ZERO) as Vector3).y)
	print("  its stone: top %.3f m, under its hips %.3f m (hips %.3f)" % [top, under, hips.y])
	ok(not hit.is_empty() and absf(top - float(HearthFolk.RES.get("seat_h_m", 0.32))) < 0.04 and absf(under - top) < 0.03 and Vector2(hips.x - sc.x, hips.z - sc.z).length() < 0.15, "it sits on its stone: the stone in the tomb's collision right under its hips (%.2f m)" % top)
	# Painted per §ES: diffuse only, big texels, casting the fire's shadow.
	var mats := _materials_under(r)
	var bad: Array = []
	var texel_ok := true
	var want_texels := float(HearthFolk.F3D.get("texels_per_m", 16.0))
	var shadowless := 0
	for e in mats:
		var why := _diffuse_only(e[1])
		if why != "":
			bad.append("%s: %s" % [(e[0] as Node).name, why])
		if e[1] is ShaderMaterial and absf(float((e[1] as ShaderMaterial).get_shader_parameter("texel_m")) - want_texels) > 0.01:
			texel_ok = false
		if (e[0] as GeometryInstance3D).is_visible_in_tree() and (e[0] as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadowless += 1
	ok(mats.size() > 0 and bad.is_empty(), "no material on it has specular above 0, roughness under 1 or a normal map (§ES.2; %d checked)%s" % [mats.size(), (": " + ", ".join(bad)) if not bad.is_empty() else ""])
	ok(texel_ok, "its painted detail in big texels, %.0f a metre, the walls' grid (folk_3d.texels_per_m), its head too" % want_texels)
	ok(shadowless == 0, "every part of it casts the fire's shadow, its head too (%d without)" % shadowless)
	var shared_head := BeastHeads.material(r.beast)
	var shared_texels: Variant = shared_head.get_shader_parameter("texel_m")
	ok(beast_mi != null and beast_mi.material_override != shared_head and (shared_texels == null or absf(float(shared_texels)) < 0.001), "its head's big texels are its own: the %s heads elsewhere keep theirs" % r.beast)
	# Its idle (§FH): a slow breath, the neck rising and falling with it.
	var neck := body.head
	var lo := INF
	var hi := -INF
	var breath_s := float(HearthFolk.RES.get("breath_s", 4.5))
	for i in int(breath_s * 60.0 * 1.2):
		await physics_frame
		lo = minf(lo, neck.global_position.y)
		hi = maxf(hi, neck.global_position.y)
	ok(hi - lo > 0.008 and hi - lo < 0.06, "it breathes: its neck rises and falls %.1f cm over a breath (%.1f s)" % [(hi - lo) * 100.0, breath_s])
	# Its hood to you, in front of it and off to one side.
	var front := r.front()
	var side := front.cross(Vector3.UP)
	var at := r.global_position + (front * cos(0.6) + side * sin(0.6)) * 2.2
	_place_facing(p, Vector3(at.x, 0.0, at.z), r.global_position)
	await _frames(90)
	var cam := get_root().get_viewport().get_camera_3d().global_position
	var to_cam := cam - neck.global_position
	to_cam.y = 0.0
	var hood := -neck.global_basis.z
	hood.y = 0.0
	var a_hood := rad_to_deg(hood.angle_to(to_cam))
	var a_body := rad_to_deg(front.angle_to(to_cam))
	print("  you %.0f° off its front: its hood %.0f° from you" % [a_body, a_hood])
	ok(a_hood < a_body - 15.0, "it turns its hood to you while you're near and in front of it (%.0f° off, from %.0f°)" % [a_hood, a_body])
	p.spawn_flat(w[0], float(w[1]), -0.32)
	await _frames(10)


## FigureSprite stays for creatures and bosses (§ET.8, folk_3d.
## sprites_stay_for): a sheet (blank here: no renderer) on a test sprite,
## the frame picked by where the camera stands, its idle stepping.
func _sprite_kept(main: CrawlerMain) -> void:
	var rows: Array = FigureSprite.SP.get("rows_deg", [-25, 0, 30])
	var around := int(FigureSprite.SP.get("around", 8))
	var n := 4
	var px := 96
	var r := FigureSprite.new()
	r.name = "SpriteCheck"
	main.add_child(r)
	r.global_position = Vector3(0.0, -300.0, 40.0)
	var yaw := 0.7
	var sheet := Image.create(int(round(px * 0.75)) * around * n, px * rows.size(), false, Image.FORMAT_RGBA8)
	r.setup(sheet, 1.62, n, 1.62 * 0.93, yaw)
	ok(r.atlas.get_width() == int(round(px * 0.75)) * around * n and r.atlas.get_height() == px * rows.size(), "FigureSprite kept for creatures and bosses: a sheet %d around x %d heights x %d idle frames (%dx%d)" % [around, rows.size(), n, r.atlas.get_width(), r.atlas.get_height()])
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
	ok(r.frame_for(eye + front * 3.0) == Vector2i(0, row0), "a sprite in front at eye height: frame 0, the level row")
	ok(r.frame_for(eye + left * 3.0) == Vector2i(2, row0), "at its left: frame 2 of 8")
	ok(r.frame_for(eye - front * 3.0) == Vector2i(4, row0), "behind it: frame 4 of 8")
	ok(r.frame_for(eye + front * 2.0 + Vector3(0.0, 2.0, 0.0)).y == row_of.call(30.0), "from above: the row from above")
	ok(r.frame_for(eye + front * 3.0 - Vector3(0.0, 1.6, 0.0)).y == row_of.call(-25.0), "from below: the row from below")
	var seen := {}
	for i in 60:
		seen[r.idle_frame(i * 0.25)] = true
	ok(seen.size() == n, "its idle steps through all %d frames" % n)
	NodeRelease.free_later(r)


## Process frames (the crosshair redraws in its own _process, after the
## frame's signal).
func _ticks(n: int) -> void:
	for i in n:
		await process_frame


## The crosshair (design §EX.7; Reticle, crawler.json hud, hud.json
## reticle).
func _reticle(main: CrawlerMain) -> void:
	var R: Dictionary = Tuning.section("hud", "reticle")
	var H: Dictionary = CrawlerMain.HUD
	# Waking's dark lifted (it is drawn over the crosshair while it lasts).
	for i in 600:
		if not main._fade.visible:
			break
		await process_frame
	var ret: Reticle = main.reticle
	var n_ret := 0
	var open_world := 0
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Reticle:
			n_ret += 1
		if n is StatusHud or n is Hud:
			open_world += 1
		stack.append_array(n.get_children())
	ok(bool(H.get("reticle", false)) and ret != null and n_ret == 1 and ret.get_parent() == main.ui, "crawler.json hud.reticle: one crosshair, in the crawler's HUD (%d)" % n_ret)
	if ret == null:
		return
	ok(open_world == 0, "nothing else of the open world's HUD comes with it: no StatusHud, no Hud (%d)" % open_world)
	# The player's settings, put back at the end.
	var had_preset: Variant = Settings.get_value("display.preset") if Settings.has("display.preset") else null
	var had_switch: Variant = Settings.get_value("hud.reticle") if Settings.has("hud.reticle") else null
	Settings.set_bool("hud.reticle", true)
	await _ticks(2)
	# In play: the crosshair and nothing else, no words (§ET.3).
	var shown_now: Array = []
	var words := 0
	for c in main.ui.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		shown_now.append(str(ctl.name))
		var t: Variant = ctl.get("text")
		if t is String and str(t) != "":
			words += 1
	ok(not bool(H.get("words", true)) and shown_now == ["Reticle"] and words == 0 and ret.showing(), "in play the crawler's HUD shows the crosshair and nothing else, and no words (shown: %s)" % [shown_now])
	# Drawn over the finished frame (past the grade, the dither and the
	# 3D glow, which never takes the canvas here), in a solid, ordinary
	# colour: it gives off no light.
	var col := Reticle.color()
	ok(main.ui.layer > main.post.layer and main.environment.background_mode != Environment.BG_CANVAS and col.a == 1.0 and maxf(col.r, maxf(col.g, col.b)) <= 1.0, "it gives off no light: drawn over the graded frame (layer %d over the grade's %d), never in the 3D glow, solid #%s" % [main.ui.layer, main.post.layer, col.to_html(false)])
	# Round the frame's middle pixel and sized per hud.json at 480 and
	# 270 lines (its sizes are at the 480 reference, like the text's).
	var ref := float(Tuning.section("hud", "text").get("ref_height_px", 480))
	for lines_want in [480, 270]:
		var pname := ""
		for nm in Display.presets():
			if int(Display.presets()[nm]) == lines_want:
				pname = str(nm)
		if pname == "":
			ok(false, "a pixel-size preset of %d lines (look.json render.presets)" % lines_want)
			continue
		Settings.set_value("display.preset", pname)
		Display.apply()
		await _ticks(2)
		var f := Display.internal_size()
		var k := float(lines_want) / ref
		var arm := maxi(roundi(float(R.get("size_px", 10)) * 0.5 * k), 1)
		var gap := maxi(roundi(float(R.get("gap_px", 3)) * k), 0)
		var w := maxi(roundi(float(R.get("thickness_px", 1)) * k), 1)
		var cl := Reticle.cells(f)
		var arms: Array = cl.arms
		var bad: Array = []
		var px := {}
		var box := Rect2i()
		for i in arms.size():
			var a: Rect2i = arms[i]
			if a.size != (Vector2i(arm, w) if i < 2 else Vector2i(w, arm)):
				bad.append("arm %d is %s" % [i, a.size])
			box = a if i == 0 else box.merge(a)
			for y in range(a.position.y, a.end.y):
				for x in range(a.position.x, a.end.x):
					if px.has(Vector2i(x, y)):
						bad.append("arms overlap at %s" % Vector2i(x, y))
					px[Vector2i(x, y)] = true
		# A plus: left and right on the up arm's rows, up and down on its
		# columns, each gap clear of the band where they cross.
		var l: Rect2i = arms[0]
		var r: Rect2i = arms[1]
		var u: Rect2i = arms[2]
		var d: Rect2i = arms[3]
		if l.position.y != r.position.y or u.position.x != d.position.x or l.position.y != u.end.y + gap or r.position.y != l.position.y:
			bad.append("not a plus")
		var gaps := [u.position.x - l.end.x, r.position.x - u.end.x, l.position.y - u.end.y, d.position.y - l.end.y]
		for g in gaps:
			if int(g) != gap:
				bad.append("gaps %s" % [gaps])
				break
		# The same on every side: the arms mirror round the box's middle,
		# which is the frame's (within half a pixel: a one-pixel line sits
		# on the middle pixel, right and below the frame's centre).
		for p: Vector2i in px:
			if not px.has(Vector2i(box.position.x + box.end.x - 1 - p.x, p.y)) or not px.has(Vector2i(p.x, box.position.y + box.end.y - 1 - p.y)):
				bad.append("not symmetric")
				break
		var mid := Vector2(box.position + box.end) * 0.5
		var off := mid - Vector2(f) * 0.5
		if absf(off.x) > 0.5 or absf(off.y) > 0.5 or box.size != Vector2i.ONE * (2 * (gap + arm) + w):
			bad.append("box %s, %s off the centre" % [box, off])
		# The dark edge: every pixel next to an arm (8 ways) that isn't
		# one, each once, and nothing else.
		var edge := {}
		var twice := 0
		for e: Rect2i in cl.edge:
			for y in range(e.position.y, e.end.y):
				for x in range(e.position.x, e.end.x):
					var p := Vector2i(x, y)
					if edge.has(p) or px.has(p):
						twice += 1
					edge[p] = true
		var want_edge := {}
		for p: Vector2i in px:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var q := p + Vector2i(dx, dy)
					if not px.has(q):
						want_edge[q] = true
		var edge_ok := twice == 0 and edge.size() == want_edge.size()
		for q in want_edge:
			if not edge.has(q):
				edge_ok = false
		if not edge_ok:
			bad.append("edge %d px (want %d), %d twice" % [edge.size(), want_edge.size(), twice])
		var vp := ret.get_viewport_rect().size
		if Vector2i(vp.round()) != f:
			bad.append("drawn on a %s frame, not the internal %s" % [vp, f])
		print("  %d lines (%dx%d): middle pixel %s; arms %d px x %d, %d clear of the middle, %d px across; edge %d px" % [lines_want, f.x, f.y, str(cl.middle), arm, w, gap, box.size.x, edge.size()])
		ok(bad.is_empty(), "%d lines: the crosshair round the frame's middle pixel, four arms %d px long and %d wide, %d px clear of the middle, the same on every side, its dark edge one pixel round it (hud.json size_px %s, gap_px %s, thickness_px %s at the 480 reference)%s" % [lines_want, arm, w, gap, str(R.get("size_px")), str(R.get("gap_px")), str(R.get("thickness_px")), "" if bad.is_empty() else ": %s" % [bad]])
	# The Settings switch (Crosshair dot) hides it, and shows it again.
	Settings.set_bool("hud.reticle", false)
	await _ticks(2)
	var off_ok := not ret.showing() and not ret._key.is_empty() and not bool(ret._key[0])
	Settings.set_bool("hud.reticle", true)
	await _ticks(2)
	var on_ok := ret.showing() and bool(ret._key[0])
	ok(off_ok and on_ok, "the Settings switch hud.reticle (Crosshair dot) hides it, and brings it back")
	# Never over an open panel: the log and the settings both cover the
	# middle of the frame.
	main.log_panel.open()
	await _ticks(2)
	var under_log := ret.showing()
	main.log_panel.close()
	main.settings_panel.open()
	await _ticks(2)
	var under_settings := ret.showing()
	main.settings_panel.close()
	await _ticks(2)
	ok(not under_log and not under_settings and ret.showing(), "hidden while the log or the settings are open, back when they close")
	if had_preset == null:
		Settings.erase("display.preset")
	else:
		Settings.set_value("display.preset", had_preset)
	if had_switch == null:
		Settings.erase("hud.reticle")
	else:
		Settings.set_value("hud.reticle", had_switch)
	Display.apply()


## A box of solid ground under `parent`: `size`, centred at `at`.
func _box(parent: Node, size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	body.add_child(cs)
	body.position = at
	parent.add_child(body)
	return body


## A walk with `keys` held for `n` frames: the lowest your feet went.
func _walk(p: CrawlerPlayer, keys: Array, n: int) -> float:
	for k in keys:
		Input.action_press(k)
	var low := p.global_position.y
	for i in n:
		await process_frame
		low = minf(low, p.global_position.y)
	for k in keys:
		Input.action_release(k)
	return low


## The eye height each frame for `n` frames.
func _eye_track(p: CrawlerPlayer, n: int) -> Array:
	var out: Array = []
	for i in n:
		await process_frame
		out.append(p._spring.position.y)
	return out


## The eye track's verdict: monotonic toward `to` (falling if `down`), its
## first frame at `to` (s, -1 never) and its biggest one-frame step (m).
func _eased(track: Array, from: float, to: float, down: bool) -> Dictionary:
	var mono := true
	var prev := from
	var at := -1.0
	var big := 0.0
	for i in track.size():
		var y: float = track[i]
		if (down and y > prev + 1e-6) or (not down and y < prev - 1e-6):
			mono = false
		big = maxf(big, absf(y - prev))
		if at < 0.0 and absf(y - to) < 1e-4:
			at = (i + 1) / 60.0
		prev = y
	return {"mono": mono, "at": at, "big": big}


## The sneak's ring on a frame `f` at scale `k` (Reticle.ring_cells): what
## is wrong with it, or nothing. One clean pixel line `want_r` out from the
## arms' crossing, the same on every side, the middle clear, its dark edge
## one pixel round it inside and out.
func _ring_faults(f: Vector2i, k: float, want_r: int) -> Array:
	var rc := Reticle.ring_cells(f, k)
	var bad: Array = []
	var px := {}
	var box := Rect2i()
	var first := true
	for r: Rect2i in rc.ring:
		box = r if first else box.merge(r)
		first = false
		for x in range(r.position.x, r.end.x):
			px[Vector2i(x, r.position.y)] = true
	var w := int(rc.width)
	if int(rc.radius) != want_r or box.size != Vector2i.ONE * (2 * want_r + w):
		bad.append("radius %d, box %s (want %d, %d across)" % [rc.radius, box.size, want_r, 2 * want_r + w])
	for p: Vector2i in px:
		if not px.has(Vector2i(box.position.x + box.end.x - 1 - p.x, p.y)) or not px.has(Vector2i(p.x, box.position.y + box.end.y - 1 - p.y)) or not px.has(Vector2i(p.y - box.position.y + box.position.x, p.x - box.position.x + box.position.y)):
			bad.append("not the same on every side")
			break
	var off := Vector2(box.position + box.end) * 0.5 - Vector2(f) * 0.5
	if absf(off.x) > 0.5 or absf(off.y) > 0.5:
		bad.append("%s off the frame's centre" % off)
	var m: Vector2i = rc.middle
	if px.has(m):
		bad.append("the middle not clear")
	# One pixel line: no 2x2 block of ring pixels anywhere (w 1).
	if w == 1:
		for p: Vector2i in px:
			if px.has(p + Vector2i.RIGHT) and px.has(p + Vector2i.DOWN) and px.has(p + Vector2i.ONE):
				bad.append("a 2x2 lump at %s" % p)
				break
	var edge := {}
	for e: Rect2i in rc.edge:
		for x in range(e.position.x, e.end.x):
			var q := Vector2i(x, e.position.y)
			if px.has(q) or edge.has(q):
				bad.append("edge over the ring or twice at %s" % q)
			edge[q] = true
	var want_edge := {}
	for p: Vector2i in px:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var q := p + Vector2i(dx, dy)
				if not px.has(q):
					want_edge[q] = true
	if edge.size() != want_edge.size():
		bad.append("edge %d px, want %d" % [edge.size(), want_edge.size()])
	return bad


## Sneaking (design §FC.1, stealth.json sneak).
func _sneak(main: CrawlerMain) -> void:
	var p := main.player
	var sn: Dictionary = CrawlerPlayer.SNEAK
	var ease := float(sn.get("camera_ease_s", 0.18))
	var share := float(sn.get("footstep_volume", 0.25))
	var look: Dictionary = sn.get("reticle", {})
	var dim := float(look.get("dim", 0.75))
	for k in ["move_forward", "sprint", "crouch"]:
		Input.action_release(k)
	# A platform of its own, far below the tomb: its top at y0, its lip at
	# x = 10 over a floor 2 m down.
	var y0 := -800.0
	var lip := 10.0
	var plat := _box(main, Vector3(20.0, 2.0, 20.0), Vector3(0.0, y0 - 1.0, 0.0))
	var below := _box(main, Vector3(200.0, 2.0, 200.0), Vector3(0.0, y0 - 3.0, 0.0))
	p.spawn_flat(Vector3(-4.0, y0, -6.0), 0.0, 0.0)
	await _frames(20)
	var stand_eye := PlanetPlayer.EYE_Y
	var crouch_eye := PlanetPlayer.CROUCH_EYE_Y
	var r := main.reticle
	var shape := func() -> String: return r.shape_now() if r != null else "none"
	var alpha := func() -> float: return r.alpha_now() if r != null else 0.0
	ok(not p.crouching and absf(p._spring.position.y - stand_eye) < 1e-4 and shape.call() == "cross" and is_equal_approx(alpha.call(), 1.0), "standing: the eye at %.2f m and the crosshair whole (%s)" % [stand_eye, shape.call()])
	# Down, and the collision at once.
	Input.action_press("crouch")
	var track := await _eye_track(p, 18)
	var dn := _eased(track, stand_eye, crouch_eye, true)
	ok(dn.mono and float(dn.at) > 0.0 and float(dn.at) <= ease + 1.0 / 60.0 + 1e-6, "Shift: over the first 0.3 s the eye eases down, never back up, and is at %.2f m by %.3f s, the first tick past camera_ease_s %.2f" % [crouch_eye, dn.at, ease])
	ok(float(dn.big) < (stand_eye - crouch_eye) * 0.25, "never a snap: the biggest one-frame step %.3f m of the %.2f m" % [dn.big, stand_eye - crouch_eye])
	ok(p.crouching and is_equal_approx(p._shape.height, PlanetPlayer.CROUCH_HEIGHT), "the collision crouches at once (%.2f m tall)" % p._shape.height)
	ok(shape.call() == "ring" and is_equal_approx(alpha.call(), dim) and r._key.size() > 1 and bool(r._key[1]), "crouched, the crosshair closes into the ring, dimmed to %.2f (%s)" % [alpha.call(), shape.call()])
	# Up again.
	Input.action_release("crouch")
	track = await _eye_track(p, 18)
	var rise := _eased(track, crouch_eye, stand_eye, false)
	ok(rise.mono and float(rise.at) > 0.0 and float(rise.at) <= ease + 1.0 / 60.0 + 1e-6 and float(rise.big) < (stand_eye - crouch_eye) * 0.25, "let go: the eye eases back up, never back down, and is at %.2f m by %.3f s (biggest step %.3f m)" % [stand_eye, rise.at, rise.big])
	ok(shape.call() == "cross" and is_equal_approx(alpha.call(), 1.0), "standing again, the crosshair is whole")
	# The ring's pixels at 480 and 270 lines (ring_px at the 480 reference).
	var ref := float(Tuning.section("hud", "text").get("ref_height_px", 480))
	for lines_n in [480, 270]:
		var k := float(lines_n) / ref
		# The 16:9 frame of that many lines (Display.internal_size).
		var fw := int(round(lines_n * 16.0 / 9.0))
		var f := Vector2i(fw + (fw & 1), lines_n)
		var want_r := maxi(roundi(float(look.get("ring_px", 4)) * k), maxi(roundi(float(Tuning.section("hud", "reticle").get("thickness_px", 1)) * k), 1) + 1)
		var faults := _ring_faults(f, k, want_r)
		ok(faults.is_empty(), "%d lines: the ring is one clean pixel line %d px out from the crosshair's middle, the same on every side, the middle clear, its dark edge one pixel round it%s" % [lines_n, want_r, "" if faults.is_empty() else ": %s" % [faults]])
	# Under a low ceiling the view stays down.
	Input.action_press("crouch")
	await _frames(20)
	var lid := _box(main, Vector3(3.0, 0.2, 3.0), p.global_position + Vector3(0.0, 1.1, 0.0))
	await _frames(2)
	Input.action_release("crouch")
	await _frames(30)
	ok(p.crouching and absf(p._spring.position.y - crouch_eye) < 1e-4, "under a ceiling 1.0 m up, letting go of Shift keeps you down: the eye stays at %.2f m, under it" % p._spring.position.y)
	lid.queue_free()
	await _frames(int(ease * 60.0) + 4)
	ok(not p.crouching and absf(p._spring.position.y - stand_eye) < 1e-4, "out from under it you stand and the eye rises to %.2f m" % p._spring.position.y)
	# Quieter feet.
	var fs := p.footsteps
	_place_facing(p, Vector3(-8.0, y0, 3.0), Vector3(0.0, y0, 3.0))
	await _frames(10)
	var n0 := fs._count
	await _walk(p, ["move_forward"], 120)
	var walk_db := fs.last_db
	var n1 := fs._count
	Input.action_press("crouch")
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(170)
	var noise := p.noise_level
	Input.action_release("move_forward")
	Input.action_release("crouch")
	var sneak_db := fs.last_db
	var n2 := fs._count
	var ratio := db_to_linear(sneak_db - walk_db)
	ok(n1 - n0 >= 4 and n2 - n1 >= 3 and absf(ratio - share) < 0.001, "a crouched step plays at %.3f of a walking step's volume (%.1f dB against %.1f; footstep_volume %.2f; %d and %d steps)" % [ratio, sneak_db, walk_db, share, n1 - n0, n2 - n1])
	ok(is_equal_approx(noise, 0.1), "crouched, the noise you make stays a tenth (noise_level %.2f, as built)" % noise)
	var plain := Footsteps.new()
	ok(is_equal_approx(plain.base_db("crouch"), float(Footsteps.VOLUME_DB.crouch)), "the open world's crouched step keeps its own volume (%.0f dB)" % plain.base_db("crouch"))
	plain.free()
	await _frames(int(ease * 60.0) + 4)
	# The ledge guard: straight at the lip.
	_place_facing(p, Vector3(lip - 2.5, y0, 0.0), Vector3(lip, y0, 0.0))
	await _frames(10)
	Input.action_press("crouch")
	await _frames(20)
	var low := await _walk(p, ["move_forward"], 600)
	var short := lip - p.global_position.x
	ok(low > y0 - 0.1 and p.is_on_floor() and short >= 0.0 and short <= 0.35, "a crouched walk straight at a 2 m drop for 10 s stops %.3f m short of the lip and never falls (lowest %.2f m)" % [short, low - y0])
	Input.action_release("crouch")
	low = await _walk(p, ["move_forward"], 90)
	ok(low < y0 - 1.5, "let go of Shift and you step off (down %.1f m)" % (y0 - low))
	# Diagonally along it.
	_place_facing(p, Vector3(lip - 2.5, y0, -5.0), Vector3(lip - 1.5, y0, -4.0))
	await _frames(10)
	Input.action_press("crouch")
	await _frames(20)
	var z0 := p.global_position.z
	low = await _walk(p, ["move_forward"], 600)
	Input.action_release("crouch")
	short = lip - p.global_position.x
	ok(low > y0 - 0.1 and p.is_on_floor() and short >= 0.0 and short <= 0.35 and p.global_position.z - z0 > 4.0, "the same walk at 45 degrees slides along the lip (%.1f m along it, %.3f m short of it) and never falls" % [p.global_position.z - z0, short])
	await _frames(int(ease * 60.0) + 4)
	# Standing, you go over.
	_place_facing(p, Vector3(lip - 2.5, y0, 5.0), Vector3(lip, y0, 5.0))
	await _frames(10)
	low = await _walk(p, ["move_forward"], 120)
	ok(low < y0 - 1.5, "the same walk standing goes over the lip and falls (down %.1f m)" % (y0 - low))
	plat.queue_free()
	below.queue_free()
	# The tomb's own floor never trips it: crouched through every door,
	# and down every flight of stairs.
	var lay := main.lay
	var holds0 := p.ledge_holds
	var held: Array = []
	var gone: Array = []
	Input.action_press("crouch")
	for d in lay.doors:
		var n2d: Vector2 = d.n
		var q: Vector2 = (d.p as Vector2) - n2d * 1.3
		var hit := _ray(Vector3(q.x, float(d.y) + 1.6, q.y), Vector3(q.x, float(d.y) - 2.0, q.y), [p.get_rid()])
		if hit.is_empty():
			continue
		var from := Vector3(q.x, (hit.position as Vector3).y, q.y)
		_place_facing(p, from, from + Vector3(n2d.x, 0.0, n2d.y))
		await _frames(8)
		var h0 := p.ledge_holds
		await _walk(p, ["move_forward"], 230)
		gone.append(Vector2(p.global_position.x - from.x, p.global_position.z - from.z).dot(n2d))
		if p.ledge_holds != h0:
			held.append("door %d (pieces %d-%d)" % [d.id, d.a, d.b])
	var flights := 0
	var drops: Array = []
	for pc in lay.pieces:
		if str(pc.kind) != "stair":
			continue
		flights += 1
		var dir: Vector2 = pc.dir
		var a: Vector2 = (pc.c as Vector2) + dir * 0.5
		var top := Vector3(a.x, Delves.floor_of(pc, 0.5), a.y)
		_place_facing(p, top, top + Vector3(dir.x, 0.0, dir.y))
		await _frames(8)
		var h1 := p.ledge_holds
		var y_top := p.global_position.y
		await _walk(p, ["move_forward"], int((float(pc.len) - 1.0) / PlanetPlayer.CROUCH_SPEED * 60.0) + 30)
		drops.append([y_top - p.global_position.y, float(pc.y0) - float(pc.y1)])
		if p.ledge_holds != h1:
			held.append("stair %d" % pc.id)
	Input.action_release("crouch")
	gone.sort()
	var down_ok := true
	for dr in drops:
		if float(dr[0]) < float(dr[1]) * 0.6:
			down_ok = false
	ok(held.is_empty() and gone.size() >= (lay.doors as Array).size() - 2, "crouched through all %d doors of the tomb (median %.1f m on through), the guard never holds you%s" % [gone.size(), gone[gone.size() / 2] if not gone.is_empty() else 0.0, "" if held.is_empty() else ": held at " + ", ".join(held)])
	if flights == 0:
		print("  no flights of stairs in this tomb (seeds 1 and 42 have them)")
	else:
		var went: Array = []
		for dr in drops:
			went.append("%.2f of %.1f m" % [dr[0], dr[1]])
		ok(down_ok, "crouched down all %d flights of stairs, all the way down (%s)" % [flights, ", ".join(went)])
	print("  the ledge guard held %d ticks at the test platform's lip, %d in the tomb" % [holds0, p.ledge_holds - holds0])
	await _frames(int(ease * 60.0) + 4)
