extends SceneTree
## The room pool (design 9 Oct §FM.6, Phantasy Star Online style; queue 70;
## RoomPool, RoomPoolBuild, TombKit; data/room_pool.json), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/room_pool_check.gd
## ROOM_SEEDS (env) sets how many seeds the plans and the walks run over
## (default 100: 1, 7, 42 and more drawn from a fixed seed).
## Asserts:
##  1. the plans (100 seeds): every dungeon has its spine from the hearth
##     room through the heart (its last room) door to door, and a way out
##     past the heart at the spine's end; one hearth room, every other fire
##     a wall sconce, one shaft of daylight (the hearth's); big rooms inside
##     big_rooms.per_dungeon, never an archetype twice in a dungeon, all
##     three archetypes somewhere, and some on the spine and some on side
##     ways; each big room on floor one, on the spine short of the room
##     before the heart or on a side way, never the hearth room, the heart,
##     the room before it or the way out; its floor its archetype's whole
##     modules, its way in centred in its start wall and its other doors
##     centred in the walls its archetype opens; its sconces its archetype's,
##     every one a holder of floor one counted in that floor's lit test
##     (TombFloors.holders_on); its ceiling's spans inside max_span_m on its
##     pillars, its headroom over its highest floor the style's room height;
##     never the room the stair down leaves, never the snake's lair or a hole
##     of its tunnels, and every dungeon still has its lair, in a room its
##     tunnels start from; the generic rooms still the kit's kinds; no two
##     pieces overlapping unless a door joins them;
##  2. the walks (the same seeds, the player's own body in each tomb's real
##     collision, every holder cold, the fork's seal standing in the stair
##     down's mouth): from the wake spot to the way out every time; and in
##     every big room, from inside its way in across it to each other door
##     (or to its far end), up and down its steps and flights;
##  3. same seed, same dungeon: every seed's plan laid twice is the same
##     plan; one tomb built twice is the same stone, vertex for vertex;
##  4. the tomb's stone (§EX.1): two tombs of each archetype built bare
##     with the general palette poisoned: every stone vertex inside their
##     big rooms within the style's tint +- spread, none poisoned, none
##     untold; and every big room inside queue 48's 45,000 triangles,
##     counted as crawler_check counts a room's;
##  5. in the game (one tomb of each archetype): every big room's sconce
##     within your reach from where your body fits on its floor; lit with
##     the game's own swing of a lit torch; with every other torch of floor
##     one lit, the floor not lit until the big room's last one catches, and
##     then lit (§FF.2: the fork opens).

var fails := 0
const DT := 1.0 / 60.0
## Seeds walked (env ROOM_SEEDS overrides).
const MORE_SEEDS := 97
## The walk's grid (m a cell), and how far over its floor your capsule is
## tried.
const CELL_M := 0.25
const LIFT_M := 0.1
## A room's triangles at most (queue 48's budget; crawler_check's).
const TRIS_BUDGET := 45000


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	WorldSave.read_only = true
	# The snake on its built rounds, held still in the game here (its pool's
	# own states, design §FM.2, queue 66, are tools/boss_snake_check.gd's).
	Boss.pool_off = true
	Bow.need_capture = false
	Residents.stay_asleep = true
	var seeds := _seeds()
	var firsts := _plans(seeds)
	_same(seeds, firsts)
	_stone(seeds)
	await _walks(seeds)
	await _in_game(firsts)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _seeds() -> Array:
	var n := MORE_SEEDS
	if OS.get_environment("ROOM_SEEDS").is_valid_int():
		n = maxi(int(OS.get_environment("ROOM_SEEDS")) - 3, 0)
	var out: Array = [1, 7, 42]
	var rng := RandomNumberGenerator.new()
	rng.seed = 70
	while out.size() < 3 + n:
		var s := rng.randi_range(1, 999999)
		if not out.has(s):
			out.append(s)
	return out


# --- 1. The plans ---------------------------------------------------------------

## The plans over `seeds`; the first seed found with each archetype
## ({id: seed}).
func _plans(seeds: Array) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var sp := RoomPool.span()
	var firsts := {}
	var counts := {}
	var arch := {}
	var where := {"spine": 0, "side way": 0}
	var spine_ok := true
	var exit_ok := true
	var hearth_ok := true
	var count_ok := true
	var repeat_ok := true
	var place_ok := true
	var shape_ok := true
	var doors_ok := true
	var sconce_ok := true
	var lit_ok := true
	var span_ok := true
	var head_ok := true
	var host_ok := true
	var boss_ok := true
	var lair_ok := true
	var kinds_ok := true
	var overlap_ok := true
	var kit_kinds: Dictionary = TombKit.K.get("kinds", {})
	var max_span := RuinStyle.num("max_span_m", 6.0, "tomb")
	var room_h := TombKit.height_of("tomb", "room", 3.2)
	var worst_span := 0.0
	for s in seeds:
		var lay := TombKit.layout(int(s))
		var pieces: Array = lay.pieces
		var mod := float(lay.module)
		# The spine through the heart to the way out (§EX.2, §EX.5).
		var spine: Array = lay.spine
		var spine_rooms: Array = []
		for id in spine:
			if str(pieces[id].kind) == "room":
				spine_rooms.append(int(id))
		var prev := 0
		var joined_all := true
		for id in spine:
			var j := false
			for di in pieces[prev].doors:
				var d: Dictionary = lay.doors[di]
				if (int(d.a) == prev and int(d.b) == int(id)) or (int(d.b) == prev and int(d.a) == int(id)):
					j = true
			joined_all = joined_all and j
			prev = int(id)
		if not lay.has("heart") or spine_rooms.is_empty() or int(spine_rooms[-1]) != int(lay.heart) or not joined_all or str(pieces[int(lay.heart)].get("room_kind", "")) != "heart":
			spine_ok = false
			print("  seed %d: the spine %s, the heart %s" % [s, str(spine), str(lay.get("heart"))])
		var exits: Array = lay.exits
		if exits.is_empty() or int(exits[0].heart) != int(lay.get("heart", -2)) or int(lay.doors[int(exits[0].door)].a) != int(spine[-1]) or int(lay.doors[int(exits[0].door)].b) != -1:
			exit_ok = false
			print("  seed %d: no way out past the heart at the spine's end" % s)
		# One hearth (§EX.4): one hearth room, every holder a sconce, one shaft.
		var hearths := 0
		for pc in pieces:
			if str(pc.kind) == "room" and str(pc.get("room_kind", "")) == "hearth":
				hearths += 1
		var shafts := 0
		for v in lay.vents:
			if str(v.type) == "shaft":
				shafts += 1
		var not_sconce := 0
		for h in lay.holders:
			if str(h.kind) != "sconce":
				not_sconce += 1
		if hearths != 1 or shafts != 1 or not_sconce > 0 or str(pieces[0].get("room_kind", "")) != "hearth":
			hearth_ok = false
			print("  seed %d: %d hearth rooms, %d shafts, %d fires not sconces" % [s, hearths, shafts, not_sconce])
		# The big rooms.
		var br: Array = lay.get("big_rooms", [])
		counts[br.size()] = int(counts.get(br.size(), 0)) + 1
		if br.size() < sp.x or br.size() > sp.y:
			count_ok = false
			print("  seed %d: %d big rooms" % [s, br.size()])
		var seen := {}
		var before_heart := int(spine_rooms[-2]) if spine_rooms.size() >= 2 else -1
		var dsc: Dictionary = lay.get("descent", {})
		var lair: Dictionary = lay.get("lair", {})
		var on0 := TombFloors.holders_on(lay, 0)
		# The boss keeps its lair (§EY.1), in a room its tunnels start from.
		if not RoomPool.keeps_lair(lay):
			lair_ok = false
			print("  seed %d: no lair, or none with its tunnel's hole in its room" % s)
		for id in br:
			var pc: Dictionary = pieces[int(id)]
			var k := str(pc.get("big_room", ""))
			var a := RoomPool.archetype(k)
			if not firsts.has(k):
				firsts[k] = int(s)
			arch[k] = int(arch.get(k, 0)) + 1
			if seen.has(k):
				repeat_ok = false
				print("  seed %d: %s twice" % [s, k])
			seen[k] = true
			# Where (placed_on; never the exit's last stretch, the heart or the
			# hearth room; floor one).
			var on_spine := bool(pc.get("spine", false))
			where["spine" if on_spine else "side way"] = int(where["spine" if on_spine else "side way"]) + 1
			if a.is_empty() or str(pc.kind) != "room" or int(pc.get("floor", 0)) != 0 or str(pc.get("room_kind", "")) != k or int(id) == int(lay.get("heart", -1)) \
					or int(id) == before_heart or int(id) == 0 or bool(pc.get("exit", false)) or int(pc.get("branch", -1)) < 0 or int(pc.get("branch", -1)) >= TombFloors.BRANCH_BASE \
					or (on_spine and spine_rooms.find(int(id)) > spine_rooms.size() - 3):
				place_ok = false
				print("  seed %d: big room %d (%s) at branch %d, spine %s, floor %d" % [s, id, k, int(pc.get("branch", -1)), str(on_spine), int(pc.get("floor", 0))])
			# Its floor in whole modules, its archetype's.
			if absf(float(pc.len) - float(a.get("length_modules", 0)) * mod) > 1e-3 or absf(2.0 * float(pc.half) - float(a.get("width_modules", 0)) * mod) > 1e-3:
				shape_ok = false
				print("  seed %d: %s %d is %.1f x %.1f m" % [s, k, id, float(pc.len), 2.0 * float(pc.half)])
			# Its doors: the way in centred in its start wall, the rest centred
			# in walls its archetype opens.
			var ins := 0
			for di in pc.doors:
				var ds: Array = TombKit.door_side(pc, lay.doors[di])
				if absf(float(ds[1])) > 0.01:
					doors_ok = false
				if str(ds[0]) == "start":
					ins += 1
				elif not str(ds[0]) in RoomPool.ways_on(k):
					doors_ok = false
					print("  seed %d: %s %d has a door in its %s wall" % [s, k, id, ds[0]])
			if ins != 1:
				doors_ok = false
				print("  seed %d: %s %d has %d doors in its start wall" % [s, k, id, ins])
			# Its sconces: its archetype's, floor one's, in its lit test.
			var mine := 0
			for i in (lay.holders as Array).size():
				if int(lay.holders[i].piece) == int(id):
					mine += 1
					if not on0.has(i):
						lit_ok = false
			if mine != RoomPool.sconces_wanted(pc) or mine == 0:
				sconce_ok = false
				print("  seed %d: %s %d has %d sconces, its archetype %d" % [s, k, id, mine, RoomPool.sconces_wanted(pc)])
			# Its ceiling on its pillars, its headroom.
			var plan := RoomPool.room_plan(lay, pc, 0.3, 0.36)
			var spn: Dictionary = plan.spans
			worst_span = maxf(worst_span, maxf(float(spn.get("slab", 0.0)), float(spn.get("beam", 0.0))))
			if float(spn.get("slab", 99.0)) > max_span + 1e-3 or float(spn.get("beam", 99.0)) > max_span + 1e-3:
				span_ok = false
			if absf(float(pc.y0) + float(pc.h) - RoomPool.highest(pc) - room_h) > 1e-3:
				head_ok = false
				print("  seed %d: %s %d has %.2f m over its highest floor" % [s, k, id, float(pc.y0) + float(pc.h) - RoomPool.highest(pc)])
			# Not the stair down's room, the lair's or a tunnel's.
			if not dsc.is_empty() and int(dsc.host) == int(id):
				host_ok = false
			if not lair.is_empty() and int(lair.piece) == int(id):
				boss_ok = false
			for hd in (lay.get("tunnels", {}) as Dictionary).get("holes", []):
				if int(hd.piece) == int(id):
					boss_ok = false
		# The generic rooms: the kit's kinds.
		for pc in pieces:
			if str(pc.kind) != "room" or pc.has("big_room"):
				continue
			var rk := str(pc.get("room_kind", ""))
			if not (rk in ["hearth", "heart"] or kit_kinds.has(rk)):
				kinds_ok = false
				print("  seed %d: room %d is a %s" % [s, pc.id, rk])
		# No overlaps but through a door.
		for i in pieces.size():
			for j in range(i + 1, pieces.size()):
				var joined := false
				for di in pieces[i].doors:
					var d: Dictionary = lay.doors[di]
					if int(d.a) == j or int(d.b) == j:
						joined = true
				if not joined and TombKit.outer(pieces[i]).grow(-0.02).intersects(TombKit.outer(pieces[j]).grow(-0.02)):
					overlap_ok = false
					print("  seed %d: pieces %d and %d overlap" % [s, i, j])
	var n_s := seeds.size()
	ok(spine_ok, "%d seeds: every dungeon's spine runs from the hearth room through every one of its rooms door to door, the heart its last" % n_s)
	ok(exit_ok, "every dungeon has its way out past the heart at the spine's end")
	ok(hearth_ok, "one hearth per dungeon: one hearth room, every other fire a wall sconce, one shaft of daylight (§EX.4)")
	ok(count_ok, "big rooms per dungeon inside big_rooms.per_dungeon %s (%s)" % [str([sp.x, sp.y]), str(counts)])
	ok(repeat_ok, "no archetype twice in a dungeon")
	ok(arch.size() == RoomPool.for_theme("tomb").size() and arch.size() == 3, "all three archetypes appear somewhere (%s)" % str(arch))
	ok(int(where["spine"]) > 0 and int(where["side way"]) > 0, "big rooms on the spine and on side ways (%s)" % str(where))
	ok(place_ok, "every big room on floor one, on the spine short of the room before the heart or on a side way: never the hearth room, the heart, the room before it or the way out")
	ok(shape_ok, "every big room's floor its archetype's whole modules (%.0f m)" % TombKit.module_of("tomb"))
	ok(doors_ok, "every big room's way in centred in its start wall, its other doors centred in the walls its archetype opens")
	ok(sconce_ok, "every big room has its archetype's sconces")
	ok(lit_ok, "and every one a holder of floor one, counted in that floor's lit test (TombFloors.holders_on, §FF.2)")
	ok(span_ok, "no big room's ceiling spans past max_span_m (%.1f m) on its pillars (the widest span %.2f m)" % [max_span, worst_span])
	ok(head_ok, "every big room's ceiling level, the style's room height (%.1f m) over its highest floor" % room_h)
	ok(host_ok, "the stair down never leaves a big room")
	ok(boss_ok, "the snake's lair and its tunnels' holes never in a big room")
	ok(lair_ok, "and every dungeon keeps its lair (§EY.1), in a room its tunnels start from (a tomb whose big rooms left it none is laid again: RoomPool.keeps_lair)")
	ok(kinds_ok, "the generic rooms are the kit's (%s)" % str(kit_kinds.keys()))
	ok(overlap_ok, "no two pieces overlap except through a door")
	print("  plans: %d ms; first seeds with each archetype %s" % [Time.get_ticks_msec() - t0, str(firsts)])
	return firsts


# --- 3. Same seed, same dungeon ----------------------------------------------------

func _same(seeds: Array, firsts: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	var differ: Array = []
	for s in seeds:
		var a := TombKit.layout(int(s))
		var b := TombKit.layout(int(s))
		if a != b or str(a) != str(b):
			differ.append(s)
	ok(differ.is_empty(), "same seed, same dungeon: each of %d seeds' plans laid twice is the same plan%s" % [seeds.size(), "" if differ.is_empty() else ": not %s" % str(differ)])
	# And its stone, vertex for vertex.
	var s0 := int(firsts.values()[0]) if not firsts.is_empty() else 1
	var one := TombBuild.build(TombKit.layout(s0))
	var two := TombBuild.build(TombKit.layout(s0))
	var same := (one.v as PackedVector3Array) == (two.v as PackedVector3Array) and (one.c as PackedColorArray) == (two.c as PackedColorArray) and (one.cv as PackedVector3Array) == (two.cv as PackedVector3Array)
	ok(same, "seed %d's tomb built twice: the same stone, vertex for vertex, colour for colour, and the same collision (%d triangles)" % [s0, (one.v as PackedVector3Array).size() / 3])
	print("  same: %d ms" % (Time.get_ticks_msec() - t0))


# --- 4. The tomb's stone -----------------------------------------------------------

func _stone(seeds: Array) -> void:
	var t0 := Time.get_ticks_msec()
	var tint := RuinStyle.tint("tomb")
	var spread := RuinStyle.spread("tomb")
	var outside := 0
	var poisoned := 0
	var untold := 0
	var stone_v := 0
	var by_kind := {}
	var built := {}
	var tris_most := {}
	var tris_over: Array = []
	TombBuild.bare = true
	TombBuild.poison = true
	# The first two tombs of each archetype among the seeds.
	var kinds := RoomPool.for_theme("tomb")
	for s in seeds:
		var done := true
		for k in kinds:
			if int(built.get(k, 0)) < 2:
				done = false
		if done:
			break
		var lay := TombKit.layout(int(s))
		var want := false
		for id in lay.big_rooms:
			if int(built.get(str(lay.pieces[int(id)].big_room), 0)) < 2:
				want = true
		if not want:
			continue
		var data := TombBuild.build(lay)
		var v: PackedVector3Array = data.v
		var c: PackedColorArray = data.c
		var m: PackedVector2Array = data.m
		var runs: Array = data.tags
		var rooms: Array = []
		for id in lay.big_rooms:
			rooms.append(lay.pieces[int(id)])
			var k := str(lay.pieces[int(id)].big_room)
			built[k] = int(built.get(k, 0)) + 1
			# Its triangles, as crawler_check counts a room's (the tomb mesh
			# inside its walls): inside queue 48's 45,000.
			var pc: Dictionary = lay.pieces[int(id)]
			var n := 0
			for i in range(0, v.size(), 3):
				var c3 := (v[i] + v[i + 1] + v[i + 2]) / 3.0
				var aa := Delves.along_across(pc, Vector2(c3.x, c3.z))
				if aa.x > -0.7 and aa.x < float(pc.len) + 0.7 and absf(aa.y) < float(pc.half) + 0.7 and c3.y > float(pc.y0) - 0.5 and c3.y < float(pc.y0) + float(pc.h) + 0.5:
					n += 1
			tris_most[k] = maxi(int(tris_most.get(k, 0)), n)
			if n > TRIS_BUDGET:
				tris_over.append("%s seed %d: %d" % [k, s, n])
		var ri := 0
		var tag := TombBuild.T_NONE
		for i in v.size():
			while ri < runs.size() and int(runs[ri][0]) <= i:
				tag = int(runs[ri][1])
				ri += 1
			var inside := false
			for pc in rooms:
				var aa := Delves.along_across(pc, Vector2(v[i].x, v[i].z))
				if aa.x > 0.05 and aa.x < float(pc.len) - 0.05 and absf(aa.y) < float(pc.half) - 0.05 and v[i].y > RoomPool.lowest(pc) - 0.3 and v[i].y < float(pc.y0) + float(pc.h) + 0.6:
					inside = true
					by_kind[str(pc.big_room)] = int(by_kind.get(str(pc.big_room), 0)) + 1
					break
			if not inside:
				continue
			var col := c[i]
			if col.is_equal_approx(TombBuild.POISON) or (col.r > 0.9 and col.g < 0.1 and col.b > 0.9):
				poisoned += 1
			var kind := int(round(m[i].x))
			if kind == RuinBuilder.LEAF_M or kind == FittedStone.DUST_M:
				continue
			if tag == TombBuild.T_NONE:
				untold += 1
			elif tag == TombBuild.T_STONE:
				stone_v += 1
				if absf(col.r - tint.r) > spread + 1e-3 or absf(col.g - tint.g) > spread + 1e-3 or absf(col.b - tint.b) > spread + 1e-3:
					outside += 1
	TombBuild.bare = false
	TombBuild.poison = false
	ok(by_kind.size() == kinds.size() and stone_v > 10000 and outside == 0, "the big rooms in the tomb's one stone (§EX.1): every stone vertex inside each archetype within the style's tint #%s +- %.2f before its shade (%d of %d off; vertices by archetype %s; %s tombs built)" % [tint.to_html(false), spread, outside, stone_v, str(by_kind), str(built)])
	ok(poisoned == 0 and untold == 0, "none from the general palette (poisoned: %d) and none untold (%d)" % [poisoned, untold])
	ok(tris_over.is_empty() and tris_most.size() == kinds.size(), "every big room inside queue 48's %d triangles, counted as crawler_check counts a room's (the most: %s)%s" % [TRIS_BUDGET, str(tris_most), "" if tris_over.is_empty() else ": over in " + ", ".join(tris_over)])
	print("  stone: %d ms" % (Time.get_ticks_msec() - t0))


# --- 2. The walks ------------------------------------------------------------------

func _walks(seeds: Array) -> void:
	var world_node := get_root().get_node("World")
	var t0 := Time.get_ticks_msec()
	var out_fail: Array = []
	var walked: Array = []
	var room_legs := 0
	var room_fail: Array = []
	var by_kind := {}
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
		var fires := CrawlerFires.new()
		fires.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(fires)
		fires.build(world_node, lay)
		var seat: Array = lay.rescuer
		var rr := RandomNumberGenerator.new()
		rr.seed = hash([int(lay.seed), "rescuer"])
		var pal := CloakedFigure.roll_palette(rr, CloakedFigure.tribe_family(int(lay.seed)))
		HearthFolk.make(root, "Rescuer", seat[0], float(seat[1]), float(CrawlerMain.RES.get("height_m", 1.62)), pal, "")
		# The fork's seal standing in the stair down's mouth, as in the game
		# with floor one cold (nothing lit, so it never opens).
		var fork := Fork.new()
		root.add_child(fork)
		fork.build(lay, fires)
		await physics_frame
		await physics_frame
		var space := vp.find_world_3d().direct_space_state
		var grid := _grid(lay, space)
		var ex: Dictionary = lay.exits[0]
		var wk: Vector3 = (lay.wake as Array)[0]
		var p_out := _path(grid, wk, func(q: Vector3) -> bool: return WayOut.in_opening(ex, q), (ex.p as Vector3))
		if p_out.is_empty():
			out_fail.append("%d: no route" % s)
		else:
			var w := await _walk_body(lay, root, p_out, func(q: Vector3) -> bool: return WayOut.in_opening(ex, q))
			if bool(w.ok):
				walked.append(float(w.m))
			else:
				out_fail.append("%d: %s" % [s, w.why])
		# Through every big room: from inside its way in to each other door,
		# or to its far end.
		for id in lay.big_rooms:
			var pc: Dictionary = lay.pieces[int(id)]
			var ins: Array = []
			var outs: Array = []
			for di in pc.doors:
				var d: Dictionary = lay.doors[di]
				var into: Vector2 = (d.n as Vector2) * (1.0 if int(d.b) == int(pc.id) else -1.0)
				var q: Vector2 = (d.p as Vector2) + into * (Delves.WALL * 0.5 + 0.7)
				var at := Vector3(q.x, Delves.floor_of(pc, Delves.along_across(pc, q).x), q.y)
				if str(TombKit.door_side(pc, d)[0]) == "start":
					ins.append(at)
				else:
					outs.append(at)
			if outs.is_empty():
				var far := RuinBuilder._pp(pc, float(pc.len) - 1.0, float(pc.half) * 0.5)
				outs.append(Vector3(far.x, Delves.floor_of(pc, float(pc.len) - 1.0), far.y))
			for a in ins:
				for b in outs:
					for leg in [[a, b], [b, a]]:
						var to: Vector3 = leg[1]
						var pts := _path(grid, leg[0], func(q: Vector3) -> bool: return Vector2(q.x - to.x, q.z - to.z).length() < 0.5 and absf(q.y - to.y) < 0.45, to)
						room_legs += 1
						by_kind[str(pc.big_room)] = int(by_kind.get(str(pc.big_room), 0)) + 1
						if pts.is_empty():
							room_fail.append("%d %s %d: no route" % [s, pc.big_room, id])
							continue
						var w2 := await _walk_body(lay, root, pts, func(q: Vector3) -> bool: return Vector2(q.x - to.x, q.z - to.z).length() < 0.5 and absf(q.y - to.y) < 0.45)
						if not bool(w2.ok):
							room_fail.append("%d %s %d: %s" % [s, pc.big_room, id, w2.why])
		NodeRelease.free_later(vp)
	walked.sort()
	var med := float(walked[walked.size() / 2]) if not walked.is_empty() else 0.0
	ok(out_fail.is_empty(), "%d seeds: with every holder cold (and the stair down's seal standing), your body walks from the wake spot to the way out every time (median %.0f m)%s" % [seeds.size(), med, "" if out_fail.is_empty() else ": " + ", ".join(out_fail)])
	ok(room_legs > 0 and room_fail.is_empty(), "and across every big room, from its way in to each other door or its far end and back, up and down its steps (%d walks: %s)%s" % [room_legs, str(by_kind), "" if room_fail.is_empty() else ": " + ", ".join(room_fail)])
	print("  the walks: %d s for %d tombs" % [(Time.get_ticks_msec() - t0) / 1000, seeds.size()])


## The walk grid (crawler_check's way: open where your capsule stands clear
## on the floor; a big room's floor from its profile, its flights' slopes
## found by a ray): {"astar", "fy" (each cell's floor), "w", "h", "o"}.
func _grid(lay: Dictionary, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var g := CELL_M
	var bounds := Delves.rect_of(lay.pieces[0], 2.0)
	for pc in lay.pieces:
		bounds = bounds.merge(Delves.rect_of(pc, 2.0))
	bounds = bounds.grow(TombBuild.OUTSIDE_M + 1.0)
	var w := ceili(bounds.size.x / g) + 1
	var h := ceili(bounds.size.y / g) + 1
	var fy := PackedFloat32Array()
	fy.resize(w * h)
	fy.fill(NAN)
	var by_ray := PackedByteArray()
	by_ray.resize(w * h)
	for pc in lay.pieces:
		var rr := Delves.rect_of(pc, 0.0)
		var c0 := _cell(bounds, rr.position.x, rr.position.y)
		var c1 := _cell(bounds, rr.end.x, rr.end.y)
		for j in range(c0.y, c1.y + 1):
			for i in range(c0.x, c1.x + 1):
				var q := bounds.position + Vector2(i, j) * g
				var aa := Delves.along_across(pc, q)
				if aa.x < 0.0 or aa.x > float(pc.len) or absf(aa.y) > float(pc.half):
					continue
				fy[j * w + i] = Delves.floor_of(pc, aa.x)
				by_ray[j * w + i] = 1 if str(pc.kind) == "stair" or pc.has("profile") else 0
	for d in lay.doors:
		var dp: Vector2 = d.p
		var dn: Vector2 = d.n
		var reach := Vector2(Delves.WALL * 0.5 + 0.05, Delves.WALL * 0.5 + (TombBuild.OUTSIDE_M if int(d.b) < 0 else 0.05))
		var ext := float(d.half) + 0.1
		var rr := Rect2(dp - dn * reach.x - Delves.perp(dn) * ext, Vector2.ZERO).expand(dp + dn * reach.y + Delves.perp(dn) * ext)
		var c0 := _cell(bounds, rr.position.x, rr.position.y)
		var c1 := _cell(bounds, rr.end.x, rr.end.y)
		for j in range(c0.y, c1.y + 1):
			for i in range(c0.x, c1.x + 1):
				var q := bounds.position + Vector2(i, j) * g
				var rel := q - dp
				var along := rel.dot(dn)
				if along < -reach.x or along > reach.y or absf(rel.dot(Delves.perp(dn))) > float(d.half):
					continue
				if is_nan(fy[j * w + i]):
					fy[j * w + i] = float(d.y)
					by_ray[j * w + i] = 1
	var qs := PhysicsShapeQueryParameters3D.new()
	qs.shape = CrawlerPlayer.body_shape()
	qs.collision_mask = 1
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(g, g)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	astar.fill_solid_region(astar.region, true)
	var floor_at := PackedFloat32Array()
	floor_at.resize(w * h)
	floor_at.fill(NAN)
	for k in w * h:
		if is_nan(fy[k]):
			continue
		var c := Vector2i(k % w, k / w)
		var q := bounds.position + Vector2(c) * g
		var y := fy[k]
		if by_ray[k] == 1:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, y + 1.0, q.y), Vector3(q.x, y - 0.8, q.y)))
			if hit.is_empty():
				continue
			y = (hit.position as Vector3).y
		floor_at[k] = y
		qs.transform = Transform3D(Basis.IDENTITY, Vector3(q.x, y + LIFT_M + CrawlerPlayer.STAND_HEIGHT * 0.5, q.y))
		if space.intersect_shape(qs, 1).is_empty():
			astar.set_point_solid(c, false)
	return {"astar": astar, "fy": floor_at, "w": w, "h": h, "o": bounds.position}


static func _cell(bounds: Rect2, x: float, z: float) -> Vector2i:
	return Vector2i(roundi((x - bounds.position.x) / CELL_M), roundi((z - bounds.position.y) / CELL_M))


## A route on `grid` from the open cell nearest `from` to the open cell
## nearest `near` that `goal` holds for: [Vector3...] (cell middles on
## their floors), [] if your capsule has none.
func _path(grid: Dictionary, from: Vector3, goal: Callable, near: Vector3) -> Array:
	var astar: AStarGrid2D = grid.astar
	var w := int(grid.w)
	var h := int(grid.h)
	var o: Vector2 = grid.o
	var fy: PackedFloat32Array = grid.fy
	var start := Vector2i(-1, -1)
	var sc := Vector2i(roundi((from.x - o.x) / CELL_M), roundi((from.z - o.y) / CELL_M))
	var sd := INF
	for j in range(maxi(sc.y - 3, 0), mini(sc.y + 3, h - 1) + 1):
		for i in range(maxi(sc.x - 3, 0), mini(sc.x + 3, w - 1) + 1):
			if not astar.is_point_solid(Vector2i(i, j)) and not is_nan(fy[j * w + i]) and absf(fy[j * w + i] - from.y) < 0.6:
				var dd := Vector2(i, j).distance_to(Vector2(sc))
				if dd < sd:
					sd = dd
					start = Vector2i(i, j)
	if start.x < 0:
		return []
	var best := Vector2i(-1, -1)
	var best_d := INF
	var r := 12
	var nc := Vector2i(roundi((near.x - o.x) / CELL_M), roundi((near.z - o.y) / CELL_M))
	for j in range(maxi(nc.y - r, 0), mini(nc.y + r, h - 1) + 1):
		for i in range(maxi(nc.x - r, 0), mini(nc.x + r, w - 1) + 1):
			var c := Vector2i(i, j)
			if astar.is_point_solid(c) or is_nan(fy[j * w + i]):
				continue
			var q := Vector3(o.x + i * CELL_M, fy[j * w + i], o.y + j * CELL_M)
			if not goal.call(q):
				continue
			var dd := q.distance_to(near)
			if dd < best_d:
				best_d = dd
				best = c
	if best.x < 0:
		return []
	var ids := astar.get_id_path(start, best, false)
	if ids.is_empty():
		return []
	var out: Array = []
	for c in ids:
		out.append(Vector3(o.x + c.x * CELL_M, fy[c.y * w + c.x], o.y + c.y * CELL_M))
	return out


## Your body along `path` until `arrived` holds where it stands (crawler
## _check's walk: CrawlerPlayer.step_body at a walk, its floor rules):
## {"ok", "m", "why"}.
func _walk_body(lay: Dictionary, root: Node3D, path: Array, arrived: Callable) -> Dictionary:
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	var cs := CollisionShape3D.new()
	cs.shape = CrawlerPlayer.body_shape()
	cs.position = Vector3(0.0, CrawlerPlayer.STAND_HEIGHT * 0.5, 0.0)
	body.add_child(cs)
	CrawlerPlayer.floor_rules(body)
	root.add_child(body)
	body.global_position = (path[0] as Vector3) + Vector3(0.0, 0.05, 0.0)
	await physics_frame
	var k := 0
	var walked := 0.0
	var best := INF
	var stall := 0
	var left := 0.0
	for i in range(1, path.size()):
		left += (path[i] as Vector3).distance_to(path[i - 1])
	var steps := int(left / maxf(CrawlerPlayer.WALK_SPEED, 0.5) * 60.0 * 2.0) + 600
	var result := {"ok": false, "m": 0.0, "why": "ran out of time near %s" % _where(lay, body.global_position)}
	for i in steps:
		var pos := body.global_position
		while k < path.size() - 1 and Vector2(pos.x - (path[k] as Vector3).x, pos.z - (path[k] as Vector3).z).length() < 0.35:
			k += 1
		var to: Vector3 = (path[k] as Vector3) - pos
		to.y = 0.0
		var wish := to.normalized() if to.length() > 0.02 else Vector3.ZERO
		CrawlerPlayer.step_body(body, wish, CrawlerPlayer.WALK_SPEED, DT)
		walked += body.global_position.distance_to(pos)
		if arrived.call(body.global_position):
			result = {"ok": true, "m": walked, "why": ""}
			break
		var togo := float(path.size() - k) * CELL_M + to.length()
		if togo < best - 0.05:
			best = togo
			stall = 0
		else:
			stall += 1
			if stall > 120:
				result = {"ok": false, "m": walked, "why": "your body stuck in %s at %s" % [_where(lay, body.global_position), str(body.global_position.snapped(Vector3.ONE * 0.01))]}
				break
		if body.global_position.y < -40.0:
			result = {"ok": false, "m": walked, "why": "your body fell out of the tomb near %s" % _where(lay, pos)}
			break
		await physics_frame
	body.queue_free()
	return result


func _where(lay: Dictionary, p: Vector3) -> String:
	var id := TombKit.piece_at(lay, p)
	if id < 0:
		return "a doorway or outside every piece (%s)" % str(p.snapped(Vector3.ONE * 0.01))
	var pc: Dictionary = lay.pieces[id]
	return "piece %d (%s %s)" % [id, pc.kind, str(pc.get("room_kind", ""))]


# --- 5. In the game -------------------------------------------------------------

func _in_game(firsts: Dictionary) -> void:
	var reach_ok := true
	var swing_ok := true
	var count_ok := true
	var n_sconces := 0
	var far := 0.0
	var tested: Array = []
	# One tomb for each archetype, a fresh game each, its big room of that
	# archetype tested.
	for k in firsts:
		var s := int(firsts[k])
		tested.append("%s %d" % [k, s])
		OS.set_environment("SEED", str(s))
		var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
		get_root().add_child(main)
		for i in 10:
			await physics_frame
		while not main.baked:
			await process_frame
		var boss: Variant = main.get("boss")
		if boss is Boss:
			(boss as Boss).auto = false
		var lay := main.lay
		var p := main.player
		p.set_physics_process(false)
		var t := p.torch
		var fires := main.fires
		# A torch from the bundle, lit at the hearth.
		p.spawn_flat(fires.bundle.global_position + Vector3(1.0, 0.0, 0.0), 0.0)
		main.take_torch()
		var hp := fires.hearth.global_position
		p.spawn_flat(hp + Vector3(0.0, 0.0, 1.0), 0.0)
		t.pass_flame()
		for id in lay.big_rooms:
			var pc: Dictionary = lay.pieces[int(id)]
			if str(pc.big_room) != str(k):
				continue
			# Every other torch of floor one lit, straight to flames.
			var others: Array = []
			var mine: Array = []
			for i in TombFloors.holders_on(lay, 0):
				if int(lay.holders[i].piece) == int(id):
					mine.append(i)
				elif not FireStore.is_lit(fires.holders[i]):
					others.append(i)
			CrawlerSave.relight(fires, others)
			for i in 3:
				await physics_frame
			var before := TombFloors.floor_lit(fires, lay, 0)
			var lit_early := false
			var opened_early := main.fork != null and main.fork.opened
			for j in mine.size():
				var h: Node3D = fires.holders[int(mine[j])]
				n_sconces += 1
				# Where you'd stand: in front of it on its floor, your body
				# clear there, the swing's point within the torch's reach.
				var stand := _swing_spot(main, h, pc)
				if stand == Vector3.INF:
					reach_ok = false
					print("  seed %d %s %d: nowhere to stand and swing at sconce %d" % [s, pc.big_room, id, int(mine[j])])
					continue
				far = maxf(far, Vector2(stand.x - h.global_position.x, stand.z - h.global_position.z).length())
				var at := h.global_position
				var flat := Vector3(at.x - stand.x, 0.0, at.z - stand.z)
				p.spawn_flat(stand, atan2(-flat.x, -flat.z))
				if not t.lit():
					t.light()
				var how := t.pass_flame()
				if not how.begins_with("fire:"):
					swing_ok = false
					print("  seed %d %s %d: the swing at sconce %d passed '%s'" % [s, pc.big_room, id, int(mine[j]), how])
				for i in 240:
					FireStore.tick(self, 1.0 / 60.0, p.global_position)
				if not FireStore.is_lit(h):
					swing_ok = false
				if j < mine.size() - 1:
					await physics_frame
					if TombFloors.floor_lit(fires, lay, 0):
						lit_early = true
			await physics_frame
			await physics_frame
			var after := TombFloors.floor_lit(fires, lay, 0)
			var opened := main.fork == null or main.fork.opened
			if before or lit_early or opened_early or not after or not opened:
				count_ok = false
				print("  seed %d %s %d: floor one lit before its last sconce %s (early %s), after %s, the fork %s" % [s, pc.big_room, id, str(before), str(lit_early), str(after), str(opened)])
			print("  seed %d: %s %d, its %d sconces lit by the swing; floor one lit before %s, after %s; the fork open %s" % [s, pc.big_room, id, mine.size(), str(before), str(after), str(opened)])
			break
		main.queue_free()
		await process_frame
		await process_frame
	ok(n_sconces > 0 and reach_ok, "in the game (a tomb of each archetype: %s): every big room's sconce in your reach from where your body fits on its floor (%d; the farthest you need stand %.2f m from it)" % [str(tested), n_sconces, far])
	ok(swing_ok, "each lit by the game's own swing of a lit torch")
	ok(count_ok, "with every other torch of floor one lit, the floor isn't lit until a big room's last sconce catches, and is once it has: the fork opens (its torches count toward the floor's lit test, §FF.2)")


## Where you'd stand to swing at sconce `h` in big room `pc`: in front of
## its face on the room's floor, up to 2.5 m out and 1.8 m to the side,
## nearest first, your body's capsule clear there and the swing's point
## (0.9 m up, 0.4 m on toward it) within the torch's reach of it and nearer
## it than any other fire. Vector3.INF if nowhere.
func _swing_spot(main: CrawlerMain, h: Node3D, pc: Dictionary) -> Vector3:
	var cup := h.global_position
	var nrm := h.global_basis.z
	nrm.y = 0.0
	nrm = nrm.normalized()
	var tan := nrm.cross(Vector3.UP)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = PlanetPlayer.STAND_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.exclude = [main.player.get_rid()]
	var space := get_root().get_world_3d().direct_space_state
	var fires := main.get_tree().get_nodes_in_group(Campfire.GROUP)
	var reach := Torch.reach_m()
	for oi in 10:
		var o := 0.3 + 0.25 * oi
		for si in 13:
			var sv := 0.3 * ceili(si * 0.5) * (1.0 if si % 2 == 1 else -1.0)
			var at := cup + nrm * o + tan * sv
			var aa := Delves.along_across(pc, Vector2(at.x, at.z))
			if aa.x < 0.35 or aa.x > float(pc.len) - 0.35 or absf(aa.y) > float(pc.half) - 0.35:
				continue
			at.y = Delves.floor_of(pc, aa.x)
			var to := Vector3(cup.x - at.x, 0.0, cup.z - at.z).normalized()
			var swing := at + Vector3(0.0, 0.9, 0.0) + to * 0.4
			var dd := swing.distance_to(cup)
			if dd > reach:
				continue
			var nearest := true
			for f in fires:
				if f != h and (f as Node3D).global_position.distance_to(swing) < dd:
					nearest = false
			if not nearest:
				continue
			q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0.0, cap.height * 0.5 + 0.12, 0.0))
			if space.intersect_shape(q, 1).is_empty():
				return at
	return Vector3.INF
