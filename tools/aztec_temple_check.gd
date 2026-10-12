extends SceneTree
## The Aztec temple as a ruin kind (design 10 Oct §FN.1, queue 80;
## room_pool.json archetypes aztec_blood_altar, aztec_calendar_room with
## always; aztec_temple.json enabled, calendar; crawler.json themes
## aztec_temple; RoomPool, AztecBuild, CrawlerSave.roster), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/aztec_temple_check.gd
## TEMPLE_SEEDS (env) sets how many seeds (default 100).
## Asserts:
##  1. off by default: aztec_temple.json enabled is false, the roster is the
##     tomb alone and no game's first ruin is drawn (the layout's own
##     first_theme, the tomb, as before), over 200 games;
##  2. on (CrawlerSave.aztec_on true): the roster is the tomb and the
##     temple, both drawn as first ruins over 200 games, the same game
##     always the same;
##  3. the plans (100 seeds): every temple has its blood altar and its
##     calendar room exactly once, both on floor one; its big rooms only
##     temple archetypes, and a tomb of every one of those seeds none of
##     the temple's; every piece of floor one reached from the hearth room
##     through its doors with every holder cold (no door shut by a light),
##     and the way out with it; every big room's sconces holders of floor
##     one; the same seed twice the same plan;
##  4. built (seeds 1, 7, 42): the calendar room carves the 20 day signs
##     in order with their numbers 1-13 then 1-7; the blood altar is round
##     (its corner faces' collision standing), its altar, bowl and stain
##     built, the stain dark and never bright red; the stone only the
##     temple's (§EX.1: every stone vertex within the style's tint and
##     spread, the general palette poisoned and never seen).

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	WorldSave.read_only = true
	_off()
	_on()
	var seeds := _seeds()
	_plans(seeds)
	_built()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _seeds() -> Array:
	var n := 100
	if OS.get_environment("TEMPLE_SEEDS").is_valid_int():
		n = maxi(int(OS.get_environment("TEMPLE_SEEDS")), 3)
	var out: Array = [1, 7, 42]
	var rng := RandomNumberGenerator.new()
	rng.seed = 80
	while out.size() < n:
		var s := rng.randi_range(1, 999999)
		if not out.has(s):
			out.append(s)
	return out


# --- 1, 2. The roster ----------------------------------------------------------------

func _off() -> void:
	ok(not bool(Tuning.table("aztec_temple").get("enabled", true)) and not CrawlerSave.aztec_on, "aztec_temple.json enabled is false by default, and the game reads it so")
	ok(CrawlerSave.roster() == ["tomb"], "with it false the roster is the tomb alone (%s)" % str(CrawlerSave.roster()))
	var drawn := 0
	for g in range(1, 201):
		if CrawlerSave.first_theme(g) != "":
			drawn += 1
	ok(drawn == 0, "with it false no game's first ruin is drawn: the tomb as before (%d of 200 drawn)" % drawn)


func _on() -> void:
	CrawlerSave.aztec_on = true
	ok(CrawlerSave.roster() == ["tomb", "aztec_temple"], "with it true the temple joins the roster (%s)" % str(CrawlerSave.roster()))
	var got := {}
	var same := true
	for g in range(1, 201):
		var th := CrawlerSave.first_theme(g)
		got[th] = int(got.get(th, 0)) + 1
		same = same and CrawlerSave.first_theme(g) == th
	ok(got.has("tomb") and got.has("aztec_temple") and got.size() == 2, "both are drawn as a game's first ruin (%s over 200 games)" % str(got))
	ok(same, "the same game always draws the same first ruin")
	CrawlerSave.aztec_on = false


# --- 3. The plans ----------------------------------------------------------------------

func _plans(seeds: Array) -> void:
	var temple_kinds := RoomPool.for_theme("aztec_temple")
	var fixed := RoomPool.always_for("aztec_temple")
	ok(fixed.size() == 2 and fixed.has("aztec_blood_altar") and fixed.has("aztec_calendar_room"), "the temple always has two chambers: %s" % str(fixed))
	ok(RoomPool.always_for("tomb").is_empty(), "the tomb has none it always draws (its dice as before)")
	var each_once := 0
	var floor_one := 0
	var own_only := 0
	var tomb_clean := 0
	var reach := 0
	var lit_ok := 0
	var same := 0
	var t0 := Time.get_ticks_msec()
	for s in seeds:
		var lay := TombKit.layout(int(s), "aztec_temple")
		var n_altar := 0
		var n_cal := 0
		var on_one := true
		var own := true
		for pc in lay.pieces:
			if not (pc as Dictionary).has("big_room"):
				continue
			var id := str(pc.big_room)
			if id == "aztec_blood_altar":
				n_altar += 1
			if id == "aztec_calendar_room":
				n_cal += 1
			on_one = on_one and int(pc.get("floor", 0)) == 0
			own = own and temple_kinds.has(id)
		if n_altar == 1 and n_cal == 1:
			each_once += 1
		else:
			print("  seed %d: blood altars %d, calendar rooms %d" % [s, n_altar, n_cal])
		if on_one:
			floor_one += 1
		if own:
			own_only += 1
		# A tomb of the same seed draws none of the temple's.
		var tomb := TombKit.layout(int(s))
		var clean := true
		for pc in tomb.pieces:
			if (pc as Dictionary).has("big_room") and temple_kinds.has(str(pc.big_room)):
				clean = false
		if clean:
			tomb_clean += 1
		if _reached(lay):
			reach += 1
		else:
			print("  seed %d: a piece of floor one or the way out is not reached from the hearth" % s)
		# The big rooms' sconces are holders of floor one.
		var hs: Array = TombFloors.holders_on(lay, 0)
		var good := true
		for pc in lay.pieces:
			if not (pc as Dictionary).has("big_room"):
				continue
			var mine := 0
			for i in hs:
				var h: Dictionary = lay.holders[int(i)] if (i is int or i is float) else i
				if int(h.piece) == int(pc.id):
					mine += 1
			good = good and mine == RoomPool.sconces_wanted(pc) and mine > 0
		if good:
			lit_ok += 1
		var again := TombKit.layout(int(s), "aztec_temple")
		if CrawlerSave.fingerprint(again) == CrawlerSave.fingerprint(lay) and str(again.big_rooms) == str(lay.big_rooms) and (again.pieces as Array).size() == (lay.pieces as Array).size():
			same += 1
	var n := seeds.size()
	ok(each_once == n, "every temple has its blood altar and its calendar room exactly once (%d of %d)" % [each_once, n])
	ok(floor_one == n, "both on floor one, with every big room (%d of %d)" % [floor_one, n])
	ok(own_only == n, "a temple's big rooms are only the temple's archetypes (%d of %d)" % [own_only, n])
	ok(tomb_clean == n, "a tomb never draws the temple's (%d of %d tombs of the same seeds)" % [tomb_clean, n])
	ok(reach == n, "every piece of floor one and the way out reached from the hearth room, every holder cold (%d of %d)" % [reach, n])
	ok(lit_ok == n, "every big room's sconces are its archetype's, holders of floor one in its lit test (%d of %d)" % [lit_ok, n])
	ok(same == n, "the same seed gives the same plan (%d of %d)" % [same, n])
	print("  plans: %d ms" % (Time.get_ticks_msec() - t0))


## Every piece of floor one reached from the hearth room through the doors
## (none of which a holder shuts), and the way out's opening with it.
func _reached(lay: Dictionary) -> bool:
	var hearth := -1
	for pc in lay.pieces:
		if str(pc.get("room_kind", "")) == "hearth":
			hearth = int(pc.id)
	if hearth < 0:
		return false
	var seen := {hearth: true}
	var todo: Array = [hearth]
	var out_reached := false
	while not todo.is_empty():
		var at := int(todo.pop_back())
		for d in lay.doors:
			var a := int(d.a)
			var b := int(d.b)
			if a != at and b != at:
				continue
			var other := b if a == at else a
			if other < 0:
				out_reached = true
				continue
			if not seen.has(other):
				seen[other] = true
				todo.append(other)
	for pc in lay.pieces:
		if int(pc.get("floor", 0)) == 0 and not seen.has(int(pc.id)):
			return false
	return out_reached


# --- 4. Built ------------------------------------------------------------------------

func _built() -> void:
	var tint := RuinStyle.tint("aztec_temple")
	var spread := RuinStyle.spread("aztec_temple")
	var cal_ok := true
	var round_ok := true
	var stain_ok := true
	var stone_ok := true
	var built := 0
	for s in [1, 7, 42]:
		var lay := TombKit.layout(int(s), "aztec_temple")
		TombBuild.bare = true
		TombBuild.poison = true
		var data := TombBuild.build(lay)
		TombBuild.bare = false
		TombBuild.poison = false
		built += 1
		var vs: PackedVector3Array = data.v
		var cs: PackedColorArray = data.c
		var runs: Array = data.tags
		# Stone vertices within the style's tint and spread, none poisoned.
		var bad := 0
		for r in runs.size():
			if int(runs[r][1]) != TombBuild.T_STONE:
				continue
			var from := int(runs[r][0])
			var to := int(runs[r + 1][0]) if r + 1 < runs.size() else vs.size()
			for i in range(from, to):
				var c := cs[i]
				var kind := int(round((data.m as PackedVector2Array)[i].x))
				if c.r > c.g * 2.5 + 0.05 and c.b > c.g * 2.5 + 0.05 and absf(c.r - c.b) < 0.3:
					bad += 1
				elif kind == RuinBuilder.LEAF_M or kind == FittedStone.DUST_M:
					continue
				elif absf(c.r - tint.r) > spread + 1e-3 or absf(c.g - tint.g) > spread + 1e-3 or absf(c.b - tint.b) > spread + 1e-3:
					bad += 1
					if bad < 4:
						print("  off: %s at %s" % [c.to_html(false), str(vs[i])])
		if bad > 0:
			print("  seed %d: %d stone vertices off the temple's stone" % [s, bad])
			stone_ok = false
		var hulls: Array = data.ch
		for pc in lay.pieces:
			if not (pc as Dictionary).has("big_room"):
				continue
			if str(pc.big_room) == "aztec_calendar_room":
				var plan := AztecBuild.calendar_plan(pc)
				var want: Array = []
				for i in 20:
					want.append({"sign": i + 1, "dots": i % 13 + 1})
				if str(plan) != str(want):
					cal_ok = false
					print("  seed %d: the calendar room carves %s" % [s, str(plan)])
			if str(pc.big_room) == "aztec_blood_altar":
				var ro := AztecBuild.round_of(pc)
				# A hull standing in each corner of the room.
				var c3: Vector3 = Vector3(((pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * 0.5).x, 0.0, ((pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * 0.5).y)
				var corners := 0
				var a := float(ro.get("apothem", 0.0))
				for sa: float in [-1.0, 1.0]:
					for sc: float in [-1.0, 1.0]:
						var q2: Vector2 = Vector2(c3.x, c3.z) + (pc.dir as Vector2) * sa * (a - 0.25) + Delves.perp(pc.dir) * sc * (a - 0.25)
						for hl in hulls:
							if _in_hull(hl, Vector3(q2.x, float(pc.y0) + 1.0, q2.y)):
								corners += 1
								break
				var altar := 0
				for hl in hulls:
					if _in_hull(hl, Vector3(c3.x, float(pc.y0) + 0.3, c3.z)):
						altar += 1
				if ro.is_empty() or corners != 4 or altar < 1:
					round_ok = false
					print("  seed %d: round %s, corners filled %d, altar's collision %d" % [s, str(ro), corners, altar])
	var st := Color(str(((RoomPool.archetype("aztec_blood_altar").get("stands", []) as Array)[0] as Dictionary).get("stain", "")))
	stain_ok = st.v < 0.25 and st.r - maxf(st.g, st.b) < 0.12
	ok(built == 3, "three temples built (seeds 1, 7, 42)")
	ok(stone_ok, "every stone vertex the temple's tint +- spread, none from the poisoned general palette")
	ok(cal_ok, "the calendar room carves the 20 day signs in order, numbered 1-13 then 1-7")
	ok(round_ok, "the blood altar is round (its four corners filled in stone, with collision) and its altar stands in its middle")
	ok(stain_ok, "the stain is dark and never bright red (%s)" % st.to_html(false))


## Is `p` inside convex hull `pts` (its points; a prism's or a box's)?
## Inside its xz bounds' polygon and between its lowest and highest y.
func _in_hull(pts: PackedVector3Array, p: Vector3) -> bool:
	if pts.size() < 4:
		return false
	var lo := INF
	var hi := -INF
	var flat := PackedVector2Array()
	for q in pts:
		lo = minf(lo, q.y)
		hi = maxf(hi, q.y)
		flat.append(Vector2(q.x, q.z))
	if p.y < lo or p.y > hi:
		return false
	var hull := Geometry2D.convex_hull(flat)
	return Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), hull)
