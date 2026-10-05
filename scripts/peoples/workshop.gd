class_name Workshop
## The workshop (design 5 Oct §EL, data/camps.json → sim.workshop, each
## people file's huts block): one hut per camp at the storage rung, two
## benches under its one roof, the hearth outside.
##
## Built (build()): ONE hut 6–10 m from the fire, its open side to it (the
## door is the open front: the benches read from outside), in the people's
## huts.workshop_form (a gable hut, a round stone hut, a hide cone, a reed
## barrel, a flat mud room with its ramada, an open shed, a lean-to) and
## the shelter's own tints (CampProps.tints). Inside, along the back: the
## soft bench (a hide mat on the floor) and the hard bench (a stone slab),
## each with a seat log behind it for bench_seats folk who face out, and
## 3–5 of the people's huts.soft / huts.hard pieces on and beside it (small
## box meshes at 16 texels a metre in the ruin material, named after
## animal_use.json's pieces_vocabulary where one fits). A porch seat by the
## door (porch_seat), and huts.porch_sign beside it, big enough to read at
## 40 m (§BU). A named spot at the door ("Door") where §EK's carcass will
## go. Where huts.kiln is non-empty, a clay kiln hump 4–8 m downwind of the
## hut (the planet's mean wind, PlanetData.wind_avg), smoking thin
## (Smoke.tick_flame) while a potter is at work. huts.hearth's props (the
## stew pot on its stones, the smoke rack, the lamp, unlit by day) round
## the existing fire circle (hearth_props()).
##
## Its life (plan(), drive()): §BV's jobs are not built, so this is the
## smallest walker the workshop needs. During loop.gather_hours a camp at
## storage splits by day: the keeper (the headman, else the first adult)
## and the children stay at the fire; the maker (§BN) sits at the bench
## that works the maker's materials for maker_bench_share of the gather
## hours, in one stretch; every other adult and teen spends one stretch of
## generalist_bench_hours at a bench (seeded per folk per day), crossing to
## the other bench at most cross_bench_per_day_max times; a full bench
## sends them to the porch seat, a full porch out with the gatherers. The
## rest of the day they are out gathering (out of sight). At the end of the
## gather hours everyone walks back to their seat in the fire circle
## (dusk_form: the night heart, §CY unchanged). A folk walks between
## stations at sim.jobs.walk_mps; far from the player (sim.jobs
## near_player_m) the move is made at once. At a bench a folk plays only
## that bench's idles (soft: sew_with_awl, twist_cord, scrape_hide,
## plait_basket; hard: knap, grind_axe, bow_drill, hollow_bowl_with_coal),
## each its own motion and its own quiet loop from the bench (audio.json
## bench_kinds, SoundSynth). Nothing here changes a sim tick.

static var W: Dictionary = (Tuning.section("camps", "sim").get("workshop", {}) as Dictionary)
## The harness's switch (walkabout, workshop_check): every move at once.
static var instant := false

const STONE := 0
const WOOD := 1
const THATCH := 3
const LEAVES := 4
const HIDE := 5
## Each idle's sound (all from its own bench's sounds list).
const SOUND_OF := {"sew_with_awl": "needle_through_hide", "twist_cord": "cord_twist", "scrape_hide": "scrape", "plait_basket": "cord_twist",
	"knap": "tap_tap", "grind_axe": "grind", "bow_drill": "drill_whirr", "hollow_bowl_with_coal": "grind"}
## The bench pieces' names in animal_use.json's pieces_vocabulary (and
## camps.json store.pieces), by the shape they are drawn as.
const PIECE_OF := {"frame": "hide_on_frame", "pegged": "hide_on_frame", "hank": "sinew_hank", "row": "bone_tools_in_row",
	"rack": "meat_strips_on_rack", "fish_rack": "fish_on_rack", "pot": "rendering_pot", "lamp": "stone_lamp_burning", "bowl": "shell_bowl", "antler": "antler_haft"}
const HUT_HALF := 2.7
const SEAT_H := 0.32


# --- Data ------------------------------------------------------------------------

## The ladder rung the workshop comes at (sim.ladder's index of W.rung).
static func rung_index() -> int:
	var lad: Array = CampSim.SIM.get("ladder", ["fire", "food", "storage", "specialist", "exchange"])
	var i := lad.find(str(W.get("rung", "storage")))
	return i if i >= 0 else 2


## A living camp at or past the workshop's rung.
static func wanted(st: Dictionary) -> bool:
	return not st.is_empty() and str(st.get("state", "living")) == "living" and int(st.get("rung", 0)) >= rung_index() and not (st.get("folk", []) as Array).is_empty()


static func huts(people: Dictionary) -> Dictionary:
	return people.get("huts", {})


static func bench_idles(bench: String) -> Array:
	return (((W.get("benches", {}) as Dictionary).get(bench, {}) as Dictionary).get("idles", []) as Array)


static func bench_sounds(bench: String) -> Array:
	return (((W.get("benches", {}) as Dictionary).get(bench, {}) as Dictionary).get("sounds", []) as Array)


## The bench that works the maker's materials (maker.works and craft
## against each bench's materials and player_brings_to_bench).
static func maker_bench(people: Dictionary) -> String:
	var mk: Dictionary = (people.get("specialists", {}) as Dictionary).get("maker", {})
	var words := (str(mk.get("craft", "")) + " " + " ".join(PackedStringArray(mk.get("works", [])))).to_lower()
	var score := {"soft": 0, "hard": 0}
	var brings: Dictionary = W.get("player_brings_to_bench", {})
	for b in ["soft", "hard"]:
		var mats: Array = (((W.get("benches", {}) as Dictionary).get(b, {}) as Dictionary).get("materials", []) as Array).duplicate()
		mats.append_array(brings.get(b, []))
		for m in mats:
			for w in str(m).split("_"):
				if w.length() > 2 and words.find(w) >= 0:
					score[b] += 1
	return "soft" if int(score.soft) > int(score.hard) else "hard"


## The maker's station at camp `st` (§EI.3): the bench of the camp's
## first non-generalist trade (Trades.maker_bench: soft, hard, the hearth
## or the kiln; the kiln only where the people build one, else the soft
## bench, where the clay goes), else the bench of the maker's materials.
static func maker_station(st: Dictionary) -> String:
	var people := Peoples.get_people(str(st.get("people", "")))
	var tb := Trades.maker_bench(st)
	if tb == "kiln" and (huts(people).get("kiln", []) as Array).is_empty():
		tb = "soft"
	return tb if tb != "" else maker_bench(people)


## Is the people's maker a potter (works clay)?
static func potter(people: Dictionary) -> bool:
	var mk: Dictionary = (people.get("specialists", {}) as Dictionary).get("maker", {})
	var words := (str(mk.get("craft", "")) + " " + " ".join(PackedStringArray(mk.get("works", [])))).to_lower()
	return words.find("clay") >= 0 or words.find("pot") >= 0


## Who keeps the fire by day: the headman, else the first adult.
static func keeper_of(st: Dictionary) -> int:
	var folk: Array = st.get("folk", [])
	for i in folk.size():
		if str((folk[i] as Dictionary).get("role", "")) == "headman" and CampSim.is_adult(folk[i]):
			return i
	for i in folk.size():
		if CampSim.is_adult(folk[i]) and str((folk[i] as Dictionary).get("role", "")) != "maker":
			return i
	return -1


# --- The day: who is where --------------------------------------------------------

## Where each folk of camp `st` is at hour `h` (local, 0–24) of game day
## `day`: "fire", "soft", "hard", "kiln", "hearth" (the maker's station
## where the maker's trade is pottery or the lighting trade, §EI), "porch"
## or "out" (gathering, out of
## sight). Outside the gather hours, or below the workshop's rung, all
## "fire".
static func plan(st: Dictionary, h: float, day: int) -> Array:
	var folk: Array = st.get("folk", [])
	var out: Array = []
	out.resize(folk.size())
	out.fill("fire")
	if not wanted(st):
		return out
	var gh: Array = (CampSim.SIM.get("loop", {}) as Dictionary).get("gather_hours", [7, 17])
	if h < float(gh[0]) or h >= float(gh[1]):
		return out
	var keeper := keeper_of(st)
	var mb := maker_station(st)
	var cap := {"soft": int(W.get("bench_seats", 2)), "hard": int(W.get("bench_seats", 2)), "porch": int(W.get("porch_seats", 1)), "kiln": 1, "hearth": 1}
	var used := {"soft": 0, "hard": 0, "porch": 0, "kiln": 0, "hearth": 0}
	# The maker first: the bench is the maker's.
	var order: Array = []
	for i in folk.size():
		if str((folk[i] as Dictionary).get("role", "")) == "maker":
			order.push_front(i)
		else:
			order.append(i)
	for i in order:
		var f: Dictionary = folk[i]
		if CampSim.stage_of(f) == "child" or i == keeper:
			continue
		var want := want_of(st, i, h, day, mb)
		if want == "out":
			out[i] = "out"
		elif int(used[want]) < int(cap[want]):
			out[i] = want
			used[want] = int(used[want]) + 1
		elif int(used.porch) < int(cap.porch):
			out[i] = "porch"
			used.porch = int(used.porch) + 1
		else:
			out[i] = "out"
	return out


## The plan at game time `days` for camp `st` (its local hour and day).
static func plan_now(st: Dictionary, days: float) -> Array:
	var a: Array = st.get("dir", [0.0, 1.0, 0.0])
	var d := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
	var lon := CubeSphere.longitude(d) / TAU
	return plan(st, fposmod(days + lon, 1.0) * 24.0, int(floor(days + lon)))


## Is the potter at work now (the maker sits at the kiln by plan `p`;
## the kiln is the maker's station only where pottery is the camp's
## maker's trade, §EI)?
static func potter_working(st: Dictionary, p: Array) -> bool:
	var folk: Array = st.get("folk", [])
	for i in mini(folk.size(), p.size()):
		if str((folk[i] as Dictionary).get("role", "")) == "maker" and str(p[i]) == "kiln":
			return true
	return false


## Folk `i`'s own wish at hour `h`: its bench, or "out". The maker one
## stretch of maker_bench_share of the gather hours; the rest one stretch
## of generalist_bench_hours, the bench seeded, crossing once at the
## stretch's middle when cross_bench_per_day_max allows and the roll says.
static func want_of(st: Dictionary, i: int, h: float, day: int, mb: String) -> String:
	var gh: Array = (CampSim.SIM.get("loop", {}) as Dictionary).get("gather_hours", [7, 17])
	var g0 := float(gh[0])
	var span := float(gh[1]) - g0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(st.get("seed", 0)), i, day, "bench"])
	var f: Dictionary = (st.folk as Array)[i]
	if str(f.get("role", "")) == "maker":
		var work := clampf(float(W.get("maker_bench_share", 0.8)), 0.0, 1.0) * span
		var s0 := g0 + rng.randf() * (span - work)
		return mb if h >= s0 and h < s0 + work else "out"
	var hrs: Array = W.get("generalist_bench_hours", [3, 6])
	var dur := minf(rng.randf_range(float(hrs[0]), float(hrs[1])), span)
	var start := g0 + rng.randf() * (span - dur)
	var bench := "soft" if rng.randf() < 0.5 else "hard"
	var cross := int(W.get("cross_bench_per_day_max", 1)) >= 1 and rng.randf() < 0.5
	if h < start or h >= start + dur:
		return "out"
	if cross and h >= start + dur * 0.5:
		bench = "hard" if bench == "soft" else "soft"
	return bench


# --- Building ----------------------------------------------------------------------

## The mesh being built: the ruin material's arrays (UV.x the material:
## 0 stone, 1 wood, 3 thatch, 4 leaves, 5 hide) and the collision boxes.
class Build:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var m := PackedVector2Array()
	var boxes: Array = []

	func tri(a: Vector3, b: Vector3, d: Vector3, nrm: Vector3, col: Color, kind: int) -> void:
		v.append_array([a, b, d])
		n.append_array([nrm, nrm, nrm])
		var cc := col
		cc.a = 0.0
		c.append_array([cc, cc, cc])
		var uv := Vector2(kind, 0.0)
		m.append_array([uv, uv, uv])

	## A box at `o`, axes x, y, z (right-handed, unit), full `size`.
	func box(o: Vector3, x: Vector3, y: Vector3, z: Vector3, size: Vector3, col: Color, kind: int, collide := false) -> void:
		var h := size * 0.5
		var k: Array[Vector3] = []
		for i in 8:
			k.append(o + x * (h.x if i & 1 else -h.x) + y * (h.y if i & 2 else -h.y) + z * (h.z if i & 4 else -h.z))
		var faces := [[[1, 3, 7, 5], x], [[0, 4, 6, 2], -x], [[2, 6, 7, 3], y], [[0, 1, 5, 4], -y], [[4, 5, 7, 6], z], [[0, 2, 3, 1], -z]]
		for f in faces:
			var q: Array = f[0]
			var nrm: Vector3 = f[1]
			if nrm.y < -0.9:
				continue # no bottoms
			tri(k[q[0]], k[q[1]], k[q[2]], nrm, col, kind)
			tri(k[q[0]], k[q[2]], k[q[3]], nrm, col, kind)
		if collide:
			boxes.append([Transform3D(Basis(x, y, z), o), size])

	## An upright box turned `yaw` about up.
	func ybox(o: Vector3, size: Vector3, yaw: float, col: Color, kind: int, collide := false) -> void:
		var x := Vector3(cos(yaw), 0, -sin(yaw))
		var z := Vector3(sin(yaw), 0, cos(yaw))
		box(o, x, Vector3.UP, z, size, col, kind, collide)

	## A beam from `a` to `b`, `w` wide along `across` and `t` thick.
	func beam(a: Vector3, b: Vector3, across: Vector3, w: float, t: float, col: Color, kind: int, collide := false) -> void:
		var z := (b - a)
		var l := z.length()
		if l < 1e-4:
			return
		z /= l
		var x := (across - z * across.dot(z))
		if x.length() < 1e-4:
			x = Vector3.UP.cross(z) if absf(z.y) < 0.95 else Vector3.RIGHT
		x = x.normalized()
		var y := z.cross(x).normalized()
		box((a + b) * 0.5, x, y, z, Vector3(w, t, l), col, kind, collide)

	## A cone (or a cone's frustum, `r1` > 0 at the top) of `sides`, both
	## windings (seen from in and out), the sides whose middle is within
	## `open` radians of +Z left out.
	func cone(base: Vector3, r0: float, r1: float, h: float, sides: int, col: Color, kind: int, open := 0.0) -> void:
		for s in sides:
			var a0 := TAU * s / sides
			var a1 := TAU * (s + 1) / sides
			var mid := (a0 + a1) * 0.5
			if open > 0.0 and absf(angle_difference(mid, PI * 0.5)) < open:
				continue
			var p0 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			var p1 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
			var q0 := base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
			var q1 := base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
			var nrm := (p1 - p0).cross(q0 - p0).normalized()
			if nrm.dot(Vector3(cos(mid), 0, sin(mid))) < 0.0:
				nrm = -nrm
			tri(p0, q0, p1, nrm, col, kind)
			tri(p0, p1, q0, -nrm, col, kind)
			if r1 > 0.0:
				tri(p1, q0, q1, nrm, col, kind)
				tri(p1, q1, q0, -nrm, col, kind)

	func tris() -> int:
		return v.size() / 3

	func node(name: String) -> MeshInstance3D:
		var mi := VillageBuilder._mesh({"v": v, "n": n, "c": c, "m": m}, RuinBuilder.material())
		mi.name = name
		return mi


## The hut's look from the people's workshop_form: its style and its wall
## and roof material and colour, over the shelter's tints.
static func look(people: Dictionary, pal: Array) -> Dictionary:
	var form := str(huts(people).get("workshop_form", "")).to_lower()
	var t := CampProps.tints(people, pal)
	var style := "gable"
	if form.find("platform") >= 0:
		style = "deck"
	elif form.find("cone") >= 0:
		style = "cone"
	elif form.find("arched") >= 0:
		style = "barrel"
	elif form.find("flat-roofed") >= 0:
		style = "flat"
	elif form.find("round") >= 0 or form.find("qarmaq") >= 0 or form.find("corbelled") >= 0:
		style = "round"
	elif form.begins_with("a lean-to"):
		style = "lean"
	elif form.find("shed") >= 0:
		style = "shed"
	var wall: Color = t[0]
	var wk := WOOD
	var walls := [["whitewash", STONE, Color(0.86, 0.84, 0.78)], ["mud", STONE, Color(0.64, 0.47, 0.32)], ["adobe", STONE, Color(0.64, 0.47, 0.32)],
		["dung", STONE, Color(0.5, 0.41, 0.3)], ["daub", STONE, Color(0.56, 0.43, 0.3)], ["plastered", STONE, Color(0.56, 0.45, 0.33)],
		["stone", STONE, Color(0.46, 0.46, 0.47)], ["driftwood", WOOD, Color(0.6, 0.56, 0.48)], ["plank", WOOD, Color(0.48, 0.38, 0.26)],
		["sod", THATCH, Color(0.34, 0.42, 0.22)], ["turf", THATCH, Color(0.34, 0.42, 0.22)], ["reed", THATCH, Color(0.66, 0.58, 0.36)],
		["hide", HIDE, Color(0.56, 0.43, 0.29)], ["birch", WOOD, Color(0.8, 0.77, 0.69)]]
	for w in walls:
		if form.find(str(w[0])) >= 0:
			wk = int(w[1])
			wall = (w[2] as Color).lerp(t[0], 0.2)
			break
	if wk == WOOD and wall == t[0]:
		wall = Color(0.43, 0.32, 0.21).lerp(t[0], 0.25)
	var roof: Color = t[1]
	var rk := THATCH
	var roofs := [["thatch", THATCH, Color(0.7, 0.58, 0.32)], ["nipa", THATCH, Color(0.62, 0.55, 0.32)], ["palm", THATCH, Color(0.62, 0.55, 0.32)],
		["ichu", THATCH, Color(0.74, 0.62, 0.36)], ["leaf roof", LEAVES, Color(0.3, 0.42, 0.2)], ["grass", THATCH, Color(0.72, 0.6, 0.34)],
		["bark sheets", WOOD, Color(0.32, 0.25, 0.18)], ["turf", THATCH, Color(0.34, 0.43, 0.21)], ["sod", THATCH, Color(0.34, 0.43, 0.21)],
		["hide", HIDE, Color(0.52, 0.4, 0.27)], ["skins", HIDE, Color(0.52, 0.4, 0.27)], ["reed", THATCH, Color(0.66, 0.58, 0.36)]]
	for r in roofs:
		if form.find(str(r[0])) >= 0:
			rk = int(r[1])
			roof = (r[2] as Color).lerp(t[1], 0.15)
			break
	if style == "flat":
		rk = wk
		roof = wall.darkened(0.08)
	if style == "cone":
		wk = HIDE
		wall = Color(0.56, 0.43, 0.29).lerp(t[0], 0.2)
		rk = HIDE
		roof = wall
	if style == "deck":
		rk = LEAVES
		roof = Color(0.3, 0.42, 0.2)
		wk = WOOD
	return {"style": style, "wall": wall, "wk": wk, "roof": roof, "rk": rk, "form": form}


## Build the workshop under `parent` (a camp's root, or the opening camp's
## dressing; its frame: y up, the fire at the origin). `ctx`: avoid (Array
## of [Vector3, radius] already standing), wind (Vector3 in parent's frame,
## the mean wind), ground (Callable Vector3 -> local ground y), r (Array
## [min, max] from the fire), kiln_r_max (the kiln's farthest from the
## fire), at (Vector3: a fixed spot, e.g. a canopy deck), scale, key.
## Returns the hut node "Workshop" (metas: benches, seats, door, sign,
## kiln, lamps, people, look, tris).
static func build(parent: Node3D, people: Dictionary, pal: Array, rng: RandomNumberGenerator, ctx: Dictionary) -> Node3D:
	var hu := huts(people)
	var lk := look(people, pal)
	var wind: Vector3 = ctx.get("wind", Vector3.ZERO)
	wind.y = 0.0
	var wdir := wind.normalized() if wind.length() > 0.05 else Vector3(cos(rng.randf() * TAU), 0, sin(rng.randf() * TAU))
	# The kiln comes with the pottery trade (§EI.3, benches.kiln
	# only_with_trade), where the people build one at all.
	var st: Dictionary = ctx.get("st", {})
	var has_kiln := not (hu.get("kiln", []) as Array).is_empty() and (st.get("trades", []) as Array).has(str(((W.get("benches", {}) as Dictionary).get("kiln", {}) as Dictionary).get("only_with_trade", "pottery")))
	var rr: Array = ctx.get("r", [6.0, 10.0])
	var spot: Dictionary
	if ctx.has("at"):
		spot = {"pos": ctx.at, "kiln": (ctx.at as Vector3) + wdir * 5.0}
	else:
		spot = choose_spot(rng, ctx.get("avoid", []), wdir, float(rr[0]), float(rr[1]), has_kiln, float(ctx.get("kiln_r_max", 1.0e9)))
	var p: Vector3 = spot.pos
	var ground: Callable = ctx.get("ground", Callable())
	var ws := Node3D.new()
	ws.name = "Workshop"
	parent.add_child(ws)
	var flat := Vector3(p.x, 0, p.z)
	var face := flat.normalized() if flat.length() > 0.1 else Vector3(0, 0, -1)
	# +Z to the fire: the open front.
	ws.position = Vector3(p.x, (float(ground.call(p)) if ground.is_valid() and not ctx.has("at") else p.y) - 0.05, p.z)
	ws.basis = Basis.looking_at(face, Vector3.UP)
	if ctx.has("yaw_to"):
		var to: Vector3 = (ctx.yaw_to as Vector3) - p
		to.y = 0.0
		if to.length() > 0.1:
			ws.basis = Basis.looking_at(-to.normalized(), Vector3.UP)
	var sc := float(ctx.get("scale", 1.0))
	ws.scale = Vector3.ONE * sc
	ws.set_meta("people", str(people.get("id", "")))
	ws.set_meta("look", lk)
	var b := Build.new()
	var lay := _hut(b, lk, rng)
	# The benches, each a surface, a seat log behind it, its pieces.
	var benches := {}
	var seats := {"soft": [], "hard": [], "porch": []}
	for bench in ["soft", "hard"]:
		var bc: Vector3 = lay[bench]
		var bn := Node3D.new()
		bn.name = "SoftBench" if bench == "soft" else "HardBench"
		ws.add_child(bn)
		bn.position = bc
		bn.set_meta("bench", bench)
		bn.set_meta("materials", (((W.get("benches", {}) as Dictionary).get(bench, {}) as Dictionary).get("materials", [])))
		if bench == "soft":
			b.ybox(bc + Vector3(0, 0.02, 0), Vector3(1.3, 0.04, 0.75), 0.0, Color(0.6, 0.47, 0.33).lerp(pal[0] if not pal.is_empty() else Color.WHITE, 0.15), HIDE)
		else:
			b.ybox(bc + Vector3(0, 0.16, 0), Vector3(1.25, 0.32, 0.55), 0.0, Color(0.45, 0.45, 0.46), STONE, true)
		# The seat log behind it; the folk face out (to the door and the fire).
		var sz := bc.z - 0.62
		b.ybox(Vector3(bc.x, SEAT_H * 0.5, sz), Vector3(1.25, SEAT_H, 0.3), 0.0, Color(0.4, 0.3, 0.2), WOOD, true)
		for s in int(W.get("bench_seats", 2)):
			var sx := bc.x + (float(s) - 0.5 * (int(W.get("bench_seats", 2)) - 1)) * 0.84
			seats[bench].append({"pos": Vector3(sx, SEAT_H, sz + 0.02), "face": Vector3(0, 0, 1)})
		var picks: Array = (hu.get(bench, []) as Array).duplicate()
		var prng := RandomNumberGenerator.new()
		prng.seed = hash([rng.seed, bench])
		var count := clampi(prng.randi_range(3, 5), 0, picks.size())
		var chosen: Array = []
		for i in count:
			chosen.append(picks[i])
		bn.set_meta("props", chosen)
		bn.set_meta("trade", Trades.visible_for(st, bench))
		bn.set_meta("laid", [] as Array)
		bn.set_meta("side", -1.0 if bench == "soft" else 1.0)
		bn.set_meta("half", lay.half)
		bn.set_meta("pal", pal)
		_pieces(bn)
		benches[bench] = bn
	# The porch seat by the door, the sign on the other side.
	var porch: Vector3 = lay.porch
	b.ybox(porch + Vector3(0, SEAT_H * 0.5, 0), Vector3(0.9, SEAT_H, 0.32), 0.0, Color(0.42, 0.31, 0.2), WOOD, true)
	seats.porch.append({"pos": porch + Vector3(0, SEAT_H, 0.02), "face": Vector3(0, 0, 1)})
	var sign_phrase := str(hu.get("porch_sign", ""))
	var sign := Node3D.new()
	sign.name = "PorchSign"
	ws.add_child(sign)
	sign.position = lay.sign
	sign.set_meta("what", sign_phrase)
	var sb := Build.new()
	sign.set_meta("shape", _sign(sb, sign_phrase, pal, rng, sign))
	if sb.tris() > 0:
		sign.add_child(sb.node("Sign"))
		var scb := PropCollision.body(sign, "Body")
		for bx in sb.boxes:
			PropCollision.box(scb, bx[0], bx[1])
	sign.set_meta("tris", sb.tris())
	# The door: where the carcass will go (§EK.1 step 2).
	var door := Node3D.new()
	door.name = "Door"
	ws.add_child(door)
	door.position = lay.door
	var mi := b.node("Hut")
	ws.add_child(mi)
	var body := PropCollision.body(ws, "Body")
	for bx in b.boxes:
		PropCollision.box(body, bx[0], bx[1])
	ws.set_meta("benches", benches)
	ws.set_meta("door", door)
	ws.set_meta("sign", sign)
	ws.set_meta("hut_tris", b.tris())
	# The seats in the parent's frame (the folk are its children).
	var pseats := {}
	for k in seats:
		var arr: Array = []
		for s in seats[k]:
			var sp: Vector3 = ws.transform * (s.pos as Vector3)
			var sf: Vector3 = ws.transform.basis * (s.face as Vector3)
			sf.y = 0.0
			arr.append({"pos": sp, "face": sf.normalized()})
		pseats[k] = arr
	ws.set_meta("seats", pseats)
	# The kiln, downwind, its own node beside the hut.
	if has_kiln:
		var kp: Vector3 = spot.kiln
		var kiln := Node3D.new()
		kiln.name = "Kiln"
		parent.add_child(kiln)
		kiln.position = Vector3(kp.x, (float(ground.call(kp)) if ground.is_valid() and not ctx.has("at") else kp.y) - 0.05, kp.z)
		kiln.basis = Basis.looking_at(-wdir, Vector3.UP)
		var kb := Build.new()
		_kiln(kb, rng, Trades.visible_for(st, "kiln"))
		kiln.add_child(kb.node("Hump"))
		var kcb := PropCollision.body(kiln, "Body")
		for bx in kb.boxes:
			PropCollision.box(kcb, bx[0], bx[1])
		kiln.set_meta("tris", kb.tris())
		kiln.set_meta("what", (hu.kiln as Array)[0])
		kiln.set_meta("wind", wdir)
		ws.set_meta("kiln", kiln)
		# The potter's seat at the mouth, facing it.
		pseats["kiln"] = [{"pos": kiln.transform * Vector3(0.25, SEAT_H, 1.75), "face": (kiln.transform.basis * Vector3(0, 0, -1)).normalized()}]
	# Sound from each bench (one player each; drive() picks the loop).
	for bench in benches:
		var sp := Audio3D.make("scrape", benches[bench], "Work")
		sp.position = Vector3(0, 0.6, 0)
		(benches[bench] as Node3D).set_meta("player", sp)
	return ws


## The hut itself in `b` (hut frame: the open front to +Z, the floor at
## y 0). Returns where things go: soft, hard (bench middles), porch, sign,
## door, half (Vector2 half width, half depth).
static func _hut(b: Build, lk: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var style := str(lk.style)
	var wall: Color = lk.wall
	var roof: Color = lk.roof
	var wk := int(lk.wk)
	var rk := int(lk.rk)
	var X := Vector3.RIGHT
	var Wd := 4.4
	var Dd := 3.2
	var hw := 1.65
	var j := func(c: Color) -> Color: return c.darkened(rng.randf_range(0.0, 0.1))
	var out := {}
	match style:
		"round", "cone":
			var R := 2.4
			if style == "round":
				# The wall ring, open on the fire side; a cone cap.
				var sides := 10
				for s in sides:
					var a0 := TAU * s / sides
					var a1 := TAU * (s + 1) / sides
					var mid := (a0 + a1) * 0.5
					var off := absf(angle_difference(mid, PI * 0.5))
					if off < 0.75:
						continue
					var h := hw if off > 1.2 else hw * 0.6
					var p0 := Vector3(cos(a0) * R, 0, sin(a0) * R)
					var p1 := Vector3(cos(a1) * R, 0, sin(a1) * R)
					b.beam(p0 + Vector3(0, h * 0.5 - 0.25, 0), p1 + Vector3(0, h * 0.5 - 0.25, 0), Vector3.UP, h + 0.5, 0.3, j.call(wall), wk, true)
				b.cone(Vector3(0, hw - 0.1, 0), R + 0.35, 0.0, 1.5, 10, roof, rk)
				b.boxes.append([Transform3D(Basis(), Vector3(0, hw + 0.5, 0)), Vector3(R * 1.6, 0.6, R * 1.6)])
			else:
				# A hide cone, wider than a tent, the work side cut away.
				b.cone(Vector3(0, -0.05, 0), R + 0.2, 0.0, 3.3, 9, wall, wk, 0.85)
				for s in 6:
					var a := TAU * s / 6.0 + 0.3
					b.beam(Vector3(cos(a) * (R + 0.25), -0.1, sin(a) * (R + 0.25)), Vector3(cos(a) * -0.15, 3.6, sin(a) * -0.15), Vector3.UP, 0.07, 0.07, Color(0.55, 0.42, 0.26), WOOD)
				for s in 8:
					var a := TAU * s / 8.0
					if absf(angle_difference(a, PI * 0.5)) < 0.7:
						continue
					b.ybox(Vector3(cos(a) * (R + 0.35), 0.1, sin(a) * (R + 0.35)), Vector3(0.32, 0.22, 0.28), a, Color(0.45, 0.45, 0.46), STONE)
				for a in [PI * 0.5 + 1.2, PI * 0.5 - 1.2, -PI * 0.5]:
					var q := Vector3(cos(a), 0, sin(a)) * R * 0.9
					b.boxes.append([Transform3D(Basis.looking_at(q.normalized(), Vector3.UP), q + Vector3(0, 1.0, 0)), Vector3(2.0, 2.0, 0.3)])
			out = {"soft": Vector3(-0.85, 0, -0.45), "hard": Vector3(0.85, 0, -0.45), "porch": Vector3(-1.9, 0, R + 0.55), "sign": Vector3(1.9, 0, R + 0.5), "door": Vector3(0, 0, R + 0.3), "half": Vector2(R, R)}
		"barrel":
			# A long low reed arch, the axis across the fire's line, open low
			# on the fire side: bundle arches and mats.
			Wd = 5.0
			var R := 1.9
			var segs := 6
			var prev := Vector3.ZERO
			for s in segs + 1:
				var th := lerpf(PI, 0.65, float(s) / segs)
				var pt := Vector3(0, sin(th) * R, cos(th) * R * 1.1)
				if s > 0:
					b.beam(Vector3(0, prev.y, prev.z), Vector3(0, pt.y, pt.z), X, Wd, 0.22, j.call(roof), rk, true)
				prev = pt
			for sx in [-1.0, 1.0]:
				b.ybox(Vector3(sx * Wd * 0.5, 0.55, -0.6), Vector3(0.2, 1.1, 2.2), 0.0, roof.darkened(0.12), rk, true)
				b.ybox(Vector3(sx * Wd * 0.5, 1.35, -0.75), Vector3(0.2, 0.6, 1.3), 0.0, roof.darkened(0.12), rk)
			# The dark ridge of saw sedge.
			b.ybox(Vector3(0, R + 0.08, 0), Vector3(Wd + 0.2, 0.16, 0.36), 0.0, Color(0.22, 0.2, 0.15), THATCH)
			out = {"soft": Vector3(-1.2, 0, -0.35), "hard": Vector3(1.2, 0, -0.35), "porch": Vector3(-2.0, 0, 2.2), "sign": Vector3(2.1, 0, 2.2), "door": Vector3(0, 0, 1.9), "half": Vector2(Wd * 0.5, R)}
		_:
			# Rectangular huts: gable, lean, flat, shed (and the deck's, small).
			var back_h := hw
			var open_w := 2.6
			if style == "flat":
				hw = 2.2
				open_w = 2.2
			if style == "lean":
				hw = 1.0
			if style != "shed":
				b.ybox(Vector3(0, hw * 0.5 - 0.25, -Dd * 0.5), Vector3(Wd, hw + 0.5, 0.2), 0.0, j.call(wall), wk, true)
				for sx in [-1.0, 1.0]:
					b.ybox(Vector3(sx * Wd * 0.5, hw * 0.5 - 0.25, 0), Vector3(0.2, hw + 0.5, Dd), 0.0, j.call(wall), wk, true)
					var stub := (Wd - open_w) * 0.5
					if stub > 0.05:
						var sh := hw if style == "flat" else hw * 0.62
						b.ybox(Vector3(sx * (Wd * 0.5 - stub * 0.5), sh * 0.5 - 0.25, Dd * 0.5), Vector3(stub, sh + 0.5, 0.2), 0.0, j.call(wall), wk, true)
				if style == "flat":
					# The lintel over the wide door.
					b.ybox(Vector3(0, hw - 0.2, Dd * 0.5), Vector3(open_w + 0.1, 0.4, 0.2), 0.0, j.call(wall), wk)
			else:
				for px in [-1.0, 0.0, 1.0]:
					for pz in [-1.0, 1.0]:
						b.ybox(Vector3(px * (Wd * 0.5 - 0.1), 1.0, pz * (Dd * 0.5 - 0.1)), Vector3(0.14, 2.0, 0.14), 0.0, Color(0.38, 0.28, 0.18), WOOD, true)
			match style:
				"flat":
					b.ybox(Vector3(0, hw + 0.08, 0), Vector3(Wd + 0.3, 0.16, Dd + 0.3), 0.0, roof, rk, true)
					# The ramada: four poles and a brush roof shading the door.
					for px in [-1.0, 1.0]:
						b.ybox(Vector3(px * 1.6, 1.05, Dd * 0.5 + 1.7), Vector3(0.1, 2.1, 0.1), 0.0, Color(0.45, 0.34, 0.22), WOOD, true)
					b.ybox(Vector3(0, 2.12, Dd * 0.5 + 0.9), Vector3(3.6, 0.1, 1.8), 0.0, Color(0.5, 0.42, 0.28), THATCH)
				"lean":
					# Hide screen above the low stone, the roof falling to the back.
					b.ybox(Vector3(0, hw + 0.45, -Dd * 0.5 + 0.05), Vector3(Wd - 0.2, 0.9, 0.06), 0.0, Color(0.56, 0.43, 0.29), HIDE)
					for px in [-1.0, 1.0]:
						b.ybox(Vector3(px * (Wd * 0.5 - 0.1), 1.0, Dd * 0.5), Vector3(0.1, 2.0, 0.1), 0.0, Color(0.42, 0.31, 0.2), WOOD, true)
					b.beam(Vector3(0, 2.05, Dd * 0.5 + 0.3), Vector3(0, 1.85, -Dd * 0.5 - 0.2), X, Wd + 0.3, 0.1, roof, rk, true)
				_:
					# A gable: the ridge across the front, low eaves, the
					# shed's roof down near the ground at the back.
					var rise := 1.25
					var top := hw + rise - 0.1
					var front_e := Vector3(0, hw - 0.15, Dd * 0.5 + 0.4)
					var back_e := Vector3(0, hw - 0.15 if style != "shed" else 0.7, -Dd * 0.5 - 0.4)
					if style == "shed":
						top = 2.4
						front_e.y = 1.9
					b.beam(Vector3(0, top, 0), front_e, X, Wd + 0.5, 0.14, roof, rk, true)
					b.beam(Vector3(0, top, 0), back_e, X, Wd + 0.5, 0.14, j.call(roof), rk, true)
					# The gable ends under the roof (not the shed's).
					if style != "shed":
						for sx in [-1.0, 1.0]:
							b.beam(Vector3(sx * Wd * 0.5, hw + 0.25, -Dd * 0.25), Vector3(sx * Wd * 0.5, top - 0.25, 0), Vector3.FORWARD, Dd * 0.55, 0.18, j.call(wall), wk)
			out = {"soft": Vector3(-Wd * 0.25, 0, -Dd * 0.5 + 1.05), "hard": Vector3(Wd * 0.25, 0, -Dd * 0.5 + 1.05),
				"porch": Vector3(-Wd * 0.5 - 0.05, 0, Dd * 0.5 + 0.75), "sign": Vector3(Wd * 0.5 + 0.2, 0, Dd * 0.5 + 0.6), "door": Vector3(0, 0, Dd * 0.5 + 0.3), "half": Vector2(Wd * 0.5, Dd * 0.5)}
			if style == "flat":
				out.porch = Vector3(-1.1, 0, Dd * 0.5 + 0.9)
				out.sign = Vector3(Wd * 0.5 + 0.3, 0, Dd * 0.5 + 0.5)
	return out


## Where the hut goes: `rmin`–`rmax` m from the fire, clear of what is
## standing (`avoid`: [pos, radius]), and, with a kiln, its kiln 4–8 m
## downwind (`wdir`) of the hut, clear too and no farther than `kiln_max`
## from the fire. {pos, kiln}.
static func choose_spot(rng: RandomNumberGenerator, avoid: Array, wdir: Vector3, rmin: float, rmax: float, kiln: bool, kiln_max := 1.0e9) -> Dictionary:
	var best := {}
	var best_s := -INF
	var a0 := rng.randf() * TAU
	for ai in 36:
		var a := a0 + TAU * ai / 36.0
		var r := rmin
		while r <= rmax + 0.01:
			var p := Vector3(cos(a), 0, sin(a)) * r
			var clear := INF
			for av in avoid:
				clear = minf(clear, p.distance_to(av[0] as Vector3) - float(av[1]) - HUT_HALF)
			var s := minf(clear, 3.0) + rng.randf() * 0.2
			var kp := p + wdir * 6.0
			if kiln:
				var kbest := -INF
				for kd: float in [4.0, 5.0, 6.0, 7.0, 8.0]:
					var q := p + wdir * kd
					var kc := minf(q.length() - 4.5, q.distance_to(p) - HUT_HALF - 1.4)
					for av in avoid:
						kc = minf(kc, q.distance_to(av[0] as Vector3) - float(av[1]) - 1.4)
					if q.length() > kiln_max:
						kc -= 5.0
					if kc > kbest:
						kbest = kc
						kp = q
				s += minf(kbest, 2.0)
				if kbest < 0.0:
					s -= 4.0
			if s > best_s:
				best_s = s
				best = {"pos": p, "kiln": kp}
			r += 1.0
	return best


## The kiln: a clay hump with its dark mouth, brush stacked beside it, a
## seat stone at the mouth, and the pottery trade's `extra` pieces (pots
## drying, grain jars) in rows beside it.
static func _kiln(b: Build, rng: RandomNumberGenerator, extra: Array = []) -> void:
	var clay := Color(0.55, 0.36, 0.24)
	b.cone(Vector3(0, -0.05, 0), 1.25, 0.85, 0.6, 9, clay, STONE)
	b.cone(Vector3(0, 0.55, 0), 0.85, 0.25, 0.4, 9, clay.darkened(0.06), STONE)
	b.cone(Vector3(0, 0.95, 0), 0.25, 0.0, 0.0, 9, Color(0.12, 0.09, 0.08), STONE)
	b.ybox(Vector3(0, 0.25, 1.05), Vector3(0.5, 0.45, 0.35), 0.0, Color(0.08, 0.06, 0.05), STONE)
	b.boxes.append([Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(2.0, 0.9, 2.0)])
	for i in 4:
		b.beam(Vector3(1.6, 0.05 + i * 0.09, -0.5 + i * 0.08), Vector3(2.4, 0.1 + i * 0.09, 0.4 - i * 0.05), Vector3.UP, 0.12, 0.08, Color(0.45, 0.36, 0.22).darkened(rng.randf() * 0.15), WOOD)
	b.ybox(Vector3(0.25, SEAT_H * 0.5, 1.75), Vector3(0.5, SEAT_H, 0.4), 0.2, Color(0.44, 0.43, 0.42), STONE, true)
	var row := 0
	for ph in extra:
		var s := str(ph)
		if s.find("smoking") >= 0:
			continue
		var jar := s.find("jar") >= 0
		for k in 4:
			var h := 0.5 if jar else 0.3
			b.ybox(Vector3(-1.9 - row * 0.6, h * 0.5, -0.9 + k * 0.5), Vector3(0.34, h, 0.34), 0.3 * k, Color(0.62, 0.42, 0.28).darkened(rng.randf() * 0.12) if not jar else Color(0.56, 0.36, 0.24), STONE)
		row += 1


# --- The pieces ----------------------------------------------------------------

## The shape a phrase is drawn as.
static func shape_of(phrase: String) -> String:
	var s := phrase.to_lower()
	var table := [
		["pegged out on the ground", "pegged"], ["pegged out", "pegged"], ["laid out", "pegged"], ["stretched", "frame"], ["on a frame", "frame"], ["on its frame", "frame"], ["hide on frame", "frame"],
		["spindle", "hank"], ["cloth", "pegged"],
		["loom", "frame"], ["press", "frame"], ["net", "net"], ["drill", "drill"], ["knapping", "flakes"], ["flakes", "flakes"], ["chips", "flakes"], ["curls", "flakes"],
		["trough", "trough"], ["soaking", "trough"], ["retting", "trough"], ["hank", "hank"], ["cord", "hank"], ["rope", "hank"], ["thread", "hank"], ["sinew", "hank"], ["fibre", "hank"],
		["basket", "basket"], ["trap", "basket"], ["box", "basket"], ["boot", "basket"], ["kamik", "basket"], ["sandal", "basket"], ["bag", "basket"], ["parka", "pegged"], ["mat", "pegged"],
		["bowl", "bowl"], ["burl", "bowl"], ["cup", "bowl"], ["gourd", "bowl"], ["soapstone", "bowl"],
		["adze", "tool"], ["axe", "tool"], ["knife", "tool"], ["scraper", "tool"], ["blade", "tool"], ["edge", "tool"], ["mallet", "tool"],
		["awl", "row"], ["needle", "row"], ["hook", "row"], ["barb", "row"], ["ivory", "row"], ["antler", "row"], ["tine", "row"], ["horn", "row"], ["spoon", "row"], ["peg", "row"], ["weights", "row"], ["darts", "row"], ["shell", "row"], ["bone", "row"],
		["slab", "slab"], ["quern", "slab"], ["grinding", "slab"], ["mortar", "slab"], ["palette", "slab"], ["stone", "slab"], ["anvil", "slab"], ["lime", "slab"],
		["pole", "poles"], ["stave", "poles"], ["shaft", "poles"], ["stake", "poles"], ["paddle", "poles"], ["plank", "poles"], ["digging stick", "poles"], ["spade", "poles"], ["rib", "poles"], ["bamboo", "poles"], ["blowpipe", "poles"], ["snowshoe", "poles"], ["haft", "poles"], ["hull", "hull"], ["dugout", "hull"],
		["bark", "pegged"], ["reed", "bundle"], ["withies", "bundle"], ["husk", "bundle"], ["thatch", "bundle"]]
	for t in table:
		if s.find(str(t[0])) >= 0:
			return str(t[1])
	return "bundle"


## A phrase's colour by what it is made of.
static func colour_of(phrase: String, pal: Array) -> Color:
	var s := phrase.to_lower()
	var table := [["obsidian", Color(0.1, 0.1, 0.13)], ["black", Color(0.12, 0.12, 0.14)], ["flint", Color(0.36, 0.36, 0.4)], ["soapstone", Color(0.5, 0.53, 0.5)],
		["birch", Color(0.86, 0.83, 0.76)], ["ivory", Color(0.88, 0.85, 0.74)], ["bone", Color(0.84, 0.8, 0.68)], ["antler", Color(0.74, 0.66, 0.52)], ["horn", Color(0.3, 0.26, 0.22)],
		["shell", Color(0.86, 0.82, 0.74)], ["sinew", Color(0.8, 0.74, 0.6)], ["lime", Color(0.86, 0.85, 0.8)], ["ochre", Color(0.62, 0.26, 0.14)], ["red", Color(0.55, 0.22, 0.14)],
		["clay", Color(0.56, 0.36, 0.23)], ["hide", Color(0.62, 0.48, 0.33)], ["skin", Color(0.62, 0.48, 0.33)], ["pelt", Color(0.5, 0.38, 0.26)], ["wool", Color(0.78, 0.72, 0.6)],
		["blanket", pal[0] if not pal.is_empty() else Color(0.55, 0.3, 0.2)], ["reed", Color(0.68, 0.6, 0.38)], ["rush", Color(0.6, 0.6, 0.36)], ["withies", Color(0.5, 0.42, 0.28)],
		["grass", Color(0.7, 0.62, 0.38)], ["fibre", Color(0.66, 0.6, 0.42)], ["cord", Color(0.62, 0.55, 0.38)], ["net", Color(0.5, 0.45, 0.32)], ["bamboo", Color(0.66, 0.62, 0.36)],
		["stone", Color(0.45, 0.45, 0.47)], ["slab", Color(0.47, 0.46, 0.45)], ["bark", Color(0.4, 0.3, 0.2)], ["peat", Color(0.16, 0.13, 0.1)], ["resin", Color(0.55, 0.36, 0.12)]]
	for t in table:
		if s.find(str(t[0])) >= 0:
			return t[1]
	return Color(0.44, 0.33, 0.21)


## A bench's pieces (its props and what the player laid on it), rebuilt
## into its own mesh "Pieces" (so laying one doesn't rebuild the hut).
static func _pieces(bn: Node3D) -> void:
	var old := bn.get_node_or_null("Pieces")
	if old != null:
		bn.remove_child(old)
		old.queue_free()
	var all: Array = (bn.get_meta("props", []) as Array).duplicate()
	all.append_array(bn.get_meta("trade", []))
	all.append_array(bn.get_meta("laid", []))
	var pal: Array = bn.get_meta("pal", [])
	var side := float(bn.get_meta("side", 1.0))
	var half: Vector2 = bn.get_meta("half", Vector2(2.2, 1.6))
	var hard := str(bn.get_meta("bench", "")) == "hard"
	var top := 0.33 if hard else 0.05
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([str(bn.name), all.size()])
	var b := Build.new()
	var small_i := 0
	var big_i := 0
	var keys: Array = []
	for ph in all:
		var shape := shape_of(str(ph))
		var col := colour_of(str(ph), pal)
		var big := shape in ["frame", "net", "poles", "hull", "trough"]
		var at: Vector3
		if big:
			# Against the hut's side wall, beside the bench, or along it.
			at = Vector3(side * (half.x * 0.5 - 0.4), 0.0, 0.35 + 0.65 * big_i)
			big_i += 1
		else:
			# Three across on the bench; past six, on the floor in front.
			at = Vector3(-0.42 + 0.42 * (small_i % 3), top, 0.12 - 0.22 * int(small_i / 3)) if small_i < 6 else Vector3(-0.42 + 0.42 * (small_i % 3), 0.0, 0.62)
			small_i += 1
		_piece(b, shape, at, col, rng, side)
		keys.append(PIECE_OF.get(shape, shape))
	bn.set_meta("piece_keys", keys)
	if b.tris() > 0:
		var mi := b.node("Pieces")
		bn.add_child(mi)
	bn.set_meta("tris", b.tris())


## One piece of `shape` at `at` (bench frame) in `b`.
static func _piece(b: Build, shape: String, at: Vector3, col: Color, rng: RandomNumberGenerator, side: float) -> void:
	var wood := Color(0.45, 0.34, 0.22)
	match shape:
		"frame":
			for x in [-0.5, 0.5]:
				b.ybox(at + Vector3(x, 0.7, 0), Vector3(0.07, 1.4, 0.07), 0.0, wood, WOOD)
			b.ybox(at + Vector3(0, 1.32, 0), Vector3(1.1, 0.06, 0.06), 0.0, wood, WOOD)
			b.ybox(at + Vector3(0, 0.25, 0), Vector3(1.1, 0.06, 0.06), 0.0, wood, WOOD)
			b.ybox(at + Vector3(0, 0.78, 0.02), Vector3(0.9, 0.95, 0.03), 0.0, col, HIDE if col.r > col.g + 0.05 else THATCH)
		"net":
			for x in [-0.55, 0.55]:
				b.ybox(at + Vector3(x, 0.65, 0), Vector3(0.06, 1.3, 0.06), 0.0, wood, WOOD)
			b.ybox(at + Vector3(0, 0.75, 0.02), Vector3(1.0, 0.9, 0.02), 0.0, col.darkened(0.2), THATCH)
		"pegged":
			b.ybox(at + Vector3(0, 0.02, 0), Vector3(0.75, 0.03, 0.55), rng.randf_range(-0.3, 0.3), col, HIDE if col.r > col.g + 0.05 else THATCH)
		"hank":
			b.ybox(at + Vector3(0, 0.04, 0), Vector3(0.24, 0.07, 0.24), rng.randf() * TAU, col, THATCH)
			b.ybox(at + Vector3(0.12, 0.09, 0.02), Vector3(0.05, 0.05, 0.18), 0.4, col.darkened(0.15), THATCH)
		"basket":
			b.ybox(at + Vector3(0, 0.13, 0), Vector3(0.32, 0.26, 0.3), rng.randf() * TAU, col, THATCH)
		"trough":
			b.ybox(at + Vector3(0, 0.08, 0), Vector3(0.38, 0.06, 1.0), 0.0, Color(0.38, 0.28, 0.18), WOOD)
			for x in [-0.17, 0.17]:
				b.ybox(at + Vector3(x, 0.17, 0), Vector3(0.05, 0.2, 1.0), 0.0, Color(0.38, 0.28, 0.18), WOOD)
			for i in 3:
				b.beam(at + Vector3(-0.1 + i * 0.1, 0.25, -0.45), at + Vector3(-0.08 + i * 0.1, 0.28, 0.45), Vector3.UP, 0.035, 0.035, col, WOOD)
		"flakes":
			for i in 7:
				b.ybox(at + Vector3(rng.randf_range(-0.3, 0.3), 0.01, rng.randf_range(-0.2, 0.2)), Vector3(0.06, 0.02, 0.05), rng.randf() * TAU, col, STONE)
			b.ybox(at + Vector3(0.05, 0.06, 0), Vector3(0.16, 0.12, 0.14), 0.3, Color(0.46, 0.45, 0.43), STONE)
		"row":
			for i in 5:
				b.ybox(at + Vector3(-0.2 + i * 0.1, 0.012, 0), Vector3(0.025, 0.02, 0.18 + 0.03 * (i % 2)), 0.0, col, STONE)
		"drill":
			b.ybox(at + Vector3(0, 0.02, 0), Vector3(0.3, 0.04, 0.12), 0.0, wood, WOOD)
			b.ybox(at + Vector3(0, 0.15, 0), Vector3(0.02, 0.24, 0.02), 0.0, wood.lightened(0.2), WOOD)
			b.beam(at + Vector3(-0.22, 0.12, 0.05), at + Vector3(0.22, 0.12, 0.08), Vector3.UP, 0.025, 0.025, wood.darkened(0.1), WOOD)
		"tool":
			b.beam(at + Vector3(-0.2, 0.02, 0), at + Vector3(0.2, 0.02, 0.04), Vector3.UP, 0.035, 0.035, wood, WOOD)
			b.ybox(at + Vector3(0.22, 0.03, 0.04), Vector3(0.08, 0.05, 0.12), 0.0, col if col.r < 0.5 else Color(0.4, 0.4, 0.42), STONE)
		"bowl":
			b.ybox(at + Vector3(0, 0.06, 0), Vector3(0.28, 0.12, 0.28), 0.0, col, WOOD if col.r > 0.4 and col.g < 0.4 else STONE)
		"slab":
			b.ybox(at + Vector3(0, 0.05, 0), Vector3(0.55, 0.1, 0.38), rng.randf_range(-0.3, 0.3), col, STONE)
			b.ybox(at + Vector3(0.05, 0.14, 0), Vector3(0.16, 0.08, 0.12), 0.0, col.darkened(0.12), STONE)
		"poles":
			for i in 3:
				var base := at + Vector3(-0.25 + i * 0.22, 0, -0.2)
				b.beam(base, base + Vector3(side * 0.25, 2.0, -0.3), Vector3.RIGHT, 0.06, 0.06, col if col != Color(0.44, 0.33, 0.21) else wood, WOOD)
		"hull":
			b.ybox(at + Vector3(0, 0.25, 0), Vector3(0.5, 0.3, 1.9), 0.0, col.darkened(0.15), WOOD)
		_:
			for i in 3:
				b.beam(at + Vector3(-0.25, 0.04 + i * 0.05, -0.05 + i * 0.05), at + Vector3(0.25, 0.04 + i * 0.05, -0.02 + i * 0.05), Vector3.UP, 0.05, 0.05, col, THATCH)


## The porch sign (huts.porch_sign): one thing at the door, 1.8–2.5 m, that
## names the people from the road. Returns its shape.
static func _sign(b: Build, phrase: String, pal: Array, rng: RandomNumberGenerator, node: Node3D) -> String:
	var s := phrase.to_lower()
	var wood := Color(0.42, 0.31, 0.2)
	var shape := "pole"
	for t in [["reed-mat press", "press"], ["manioc press", "tube"], ["lamp", "lamp"], ["doorway", "doorway"], ["cheeses", "cheeses"], ["jars", "jars"], ["gourds", "gourds"],
			["rack", "rack"], ["loom", "loom"], ["dugout", "hull"], ["canoe", "hull"], ["ladder", "ladder"], ["poles", "poles"], ["frame", "frame"]]:
		if s.find(str(t[0])) >= 0:
			shape = str(t[1])
			break
	match shape:
		"press":
			# Two poles, a wet mat squeezed between their crossbars.
			for x in [-0.75, 0.75]:
				b.ybox(Vector3(x, 1.2, 0), Vector3(0.12, 2.4, 0.12), 0.0, wood, WOOD, true)
			for y in [0.4, 2.0]:
				b.ybox(Vector3(0, y, 0.06), Vector3(1.7, 0.1, 0.1), 0.0, wood, WOOD)
			b.ybox(Vector3(0, 1.2, 0), Vector3(1.4, 1.5, 0.08), 0.0, Color(0.5, 0.48, 0.3), THATCH)
		"tube":
			b.ybox(Vector3(0, 1.3, 0), Vector3(0.14, 2.6, 0.14), 0.0, wood, WOOD, true)
			b.ybox(Vector3(0, 2.5, 0.25), Vector3(0.08, 0.08, 0.6), 0.0, wood, WOOD)
			b.ybox(Vector3(0, 1.6, 0.5), Vector3(0.22, 1.6, 0.22), 0.0, Color(0.66, 0.58, 0.36), THATCH)
		"lamp":
			# A stone lamp on a standing stone in the doorway, lit day and
			# night: the stone reads by day, the flame by night.
			b.ybox(Vector3(0, 0.85, 0), Vector3(0.55, 1.7, 0.5), 0.3, Color(0.44, 0.44, 0.45), STONE, true)
			b.ybox(Vector3(0, 1.8, 0), Vector3(0.66, 0.2, 0.44), 0.0, Color(0.5, 0.53, 0.5), STONE)
			_flame(node, Vector3(0, 1.98, 0), true)
		"doorway":
			for x in [-1.25, 1.25]:
				b.ybox(Vector3(x, 1.1, 0), Vector3(0.35, 2.2, 0.3), 0.0, Color(0.88, 0.87, 0.82), STONE, true)
			b.ybox(Vector3(0, 2.3, 0), Vector3(2.85, 0.3, 0.3), 0.0, Color(0.88, 0.87, 0.82), STONE)
			b.ybox(Vector3(1.25, 1.4, 0.16), Vector3(0.2, 0.22, 0.02), 0.0, Color(0.62, 0.26, 0.14), STONE)
			for i in 5:
				b.beam(Vector3(1.7 + i * 0.05, 0, -0.1), Vector3(1.6 + i * 0.03, 1.9, -0.3), Vector3.RIGHT, 0.05, 0.05, Color(0.6, 0.56, 0.34), WOOD)
		"cheeses":
			b.ybox(Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 0.5), 0.0, Color(0.45, 0.45, 0.46), STONE, true)
			b.ybox(Vector3(0, 1.0, 0), Vector3(2.2, 0.12, 0.6), 0.0, Color(0.42, 0.42, 0.43), STONE)
			for i in 6:
				b.ybox(Vector3(-0.85 + i * 0.34, 1.15, 0), Vector3(0.26, 0.18, 0.26), 0.0, Color(0.93, 0.91, 0.84), STONE)
		"jars":
			for i in 5:
				var h := 0.6 + 0.25 * float(i % 2) + (0.35 if i == 2 else 0.0)
				b.ybox(Vector3(-1.0 + i * 0.5, h * 0.5, 0), Vector3(0.42, h, 0.42), 0.4 * i, Color(0.6, 0.38, 0.24).darkened(rng.randf() * 0.12), STONE, true)
			for i in 3:
				b.ybox(Vector3(-0.5 + i * 0.5, 1.05 + 0.2, 0), Vector3(0.38, 0.5, 0.38), 0.2 * i, Color(0.6, 0.38, 0.24).darkened(rng.randf() * 0.12), STONE)
		"gourds":
			for x in [-1.1, 1.1]:
				b.ybox(Vector3(x, 1.0, 0), Vector3(0.1, 2.0, 0.1), 0.0, wood, WOOD, true)
			b.ybox(Vector3(0, 1.9, 0), Vector3(2.4, 0.08, 0.08), 0.0, wood, WOOD)
			for i in 5:
				b.ybox(Vector3(-0.8 + i * 0.4, 1.6, 0), Vector3(0.24, 0.42, 0.24), 0.0, Color(0.5, 0.36, 0.2), WOOD)
			for i in 4:
				b.ybox(Vector3(-0.75 + i * 0.5, 0.08, 0.1), Vector3(0.36, 0.08, 0.36), 0.0, Color(0.3, 0.24, 0.16), STONE)
		"rack":
			for x in [-1.0, 1.0]:
				b.ybox(Vector3(x, 1.15, 0), Vector3(0.1, 2.3, 0.1), 0.0, wood, WOOD, true)
			b.ybox(Vector3(0, 2.15, 0), Vector3(2.3, 0.08, 0.08), 0.0, wood, WOOD)
			for i in 7:
				b.ybox(Vector3(-0.85 + i * 0.28, 1.75, 0), Vector3(0.16, 0.7, 0.03), 0.0, Color(0.72, 0.6, 0.48) if s.find("fish") >= 0 else Color(0.48, 0.2, 0.15), HIDE)
		"loom":
			b.beam(Vector3(-0.9, 0.05, -0.6), Vector3(-0.9, 1.3, 0.2), Vector3.RIGHT, 0.08, 0.08, wood, WOOD)
			b.beam(Vector3(0.9, 0.05, -0.6), Vector3(0.9, 1.3, 0.2), Vector3.RIGHT, 0.08, 0.08, wood, WOOD)
			b.beam(Vector3(0, 0.25, -0.45), Vector3(0, 1.2, 0.15), Vector3.RIGHT, 1.6, 0.04, pal[0] if not pal.is_empty() else Color(0.55, 0.28, 0.18), HIDE)
			b.ybox(Vector3(0, 1.32, 0.18), Vector3(2.0, 0.08, 0.08), 0.0, wood, WOOD)
		"hull":
			for x in [-0.9, 0.9]:
				b.ybox(Vector3(x, 0.4, 0), Vector3(0.5, 0.8, 0.12), 0.0, wood, WOOD, true)
			b.ybox(Vector3(0, 1.0, 0), Vector3(2.6, 0.45, 0.6), 0.0, Color(0.36, 0.27, 0.18) if s.find("bark") < 0 else Color(0.8, 0.76, 0.66), WOOD)
			b.ybox(Vector3(0, 1.25, 0), Vector3(2.5, 0.05, 0.08), 0.0, Color(0.08, 0.07, 0.06), WOOD)
		"ladder":
			for x in [-0.3, 0.3]:
				b.ybox(Vector3(x, 1.2, 0), Vector3(0.05, 2.4, 0.05), 0.0, Color(0.55, 0.46, 0.3), WOOD)
			for i in 7:
				b.ybox(Vector3(0, 0.3 + i * 0.32, 0), Vector3(0.62, 0.05, 0.06), 0.0, Color(0.78, 0.7, 0.52), WOOD)
		"poles":
			for i in 8:
				var base := Vector3(-0.9 + i * 0.25, 0, 0.2)
				b.beam(base, base + Vector3(0.1, 2.6, -0.45), Vector3.RIGHT, 0.08, 0.08, Color(0.5, 0.38, 0.24).darkened(rng.randf() * 0.12), WOOD, i == 0 or i == 7)
			b.ybox(Vector3(1.4, 0.25, 0.3), Vector3(0.45, 0.5, 0.45), 0.0, Color(0.12, 0.11, 0.1), THATCH)
		"frame":
			for x in [-1.0, 1.0]:
				b.ybox(Vector3(x, 1.1, 0), Vector3(0.1, 2.2, 0.1), 0.0, wood, WOOD, true)
			for y in [0.3, 2.0]:
				b.ybox(Vector3(0, y, 0), Vector3(2.1, 0.08, 0.08), 0.0, wood, WOOD)
			b.ybox(Vector3(0, 1.15, 0.02), Vector3(1.75, 1.55, 0.03), 0.0, Color(0.64, 0.5, 0.34), HIDE)
		_:
			b.ybox(Vector3(0, 1.2, 0), Vector3(0.12, 2.4, 0.12), 0.0, wood, WOOD, true)
			b.ybox(Vector3(0, 2.0, 0.1), Vector3(0.4, 0.5, 0.2), 0.0, colour_of(phrase, pal), THATCH)
	return shape


## A small flame and its warm light (a lamp: fire, the one warm light).
## `always`: lit day and night; else hidden (Workshop.tick lights it at
## dusk). The node is returned; its meta "lamp" marks it.
static func _flame(parent: Node3D, at: Vector3, always: bool) -> Node3D:
	var f := Node3D.new()
	f.name = "Flame"
	parent.add_child(f)
	f.position = at
	CreatureBodies.box(f, Vector3(0.07, 0.11, 0.07), Vector3(0, 0.05, 0), Color(1.0, 0.68, 0.22), 3.0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.38)
	l.light_energy = 0.7
	l.omni_range = 4.5
	l.shadow_enabled = false
	l.position = Vector3(0, 0.2, 0)
	f.add_child(l)
	f.set_meta("lamp", true)
	f.set_meta("always", always)
	return f


## huts.hearth's props round the fire circle (the hearth station, §EL.1):
## the stew pot on its stones, the smoke rack, the rendering pot, the lamp
## (unlit by day). Under `parent` (the fire at the origin) at `r_m` from
## the fire, clear of `avoid`. Returns the node "HearthProps".
static func hearth_props(parent: Node3D, people: Dictionary, pal: Array, rng: RandomNumberGenerator, avoid: Array, r_m := 3.2, extra: Array = []) -> Node3D:
	var n := Node3D.new()
	n.name = "HearthProps"
	parent.add_child(n)
	var b := Build.new()
	# huts.hearth's own, then the lighting trade's (§EI.3).
	var list: Array = (huts(people).get("hearth", []) as Array).slice(0, 4)
	list.append_array(extra)
	var used: Array = avoid.duplicate()
	var lamps: Array = []
	var what: Array = []
	for i in mini(list.size(), 7):
		var ph := str(list[i]).to_lower()
		# The clearest angle on the ring.
		var best := Vector3.ZERO
		var best_c := -INF
		for k in 24:
			var a := TAU * k / 24.0 + rng.randf() * 0.1
			var p := Vector3(cos(a), 0, sin(a)) * (r_m + rng.randf_range(0.0, 0.4))
			var c := INF
			for av in used:
				c = minf(c, p.distance_to(av[0] as Vector3) - float(av[1]))
			if c > best_c:
				best_c = c
				best = p
		used.append([best, 1.3])
		var yaw := atan2(best.x, best.z)
		what.append(str(list[i]))
		if i == 0:
			# The hearth worker's seat (§EI.3: the lighting maker's
			# station), a step out from the first of them, facing it.
			var out := Vector3(best.x, 0, best.z).normalized()
			var side := Vector3(-out.z, 0, out.x)
			b.ybox(best + side * 0.8 + Vector3(0, SEAT_H * 0.5, 0), Vector3(0.45, SEAT_H, 0.4), yaw, Color(0.44, 0.43, 0.42), STONE, true)
			n.set_meta("seat", {"pos": best + side * 0.8 + Vector3(0, SEAT_H, 0), "face": -side})
		if _has(ph, ["lamp", "candle", "rushlight", "torch", "candlenut", "brand"]):
			b.ybox(best + Vector3(0, 0.2, 0), Vector3(0.36, 0.4, 0.36), yaw, Color(0.44, 0.44, 0.45), STONE, true)
			b.ybox(best + Vector3(0, 0.46, 0), Vector3(0.3, 0.12, 0.24), yaw, Color(0.55, 0.36, 0.23), STONE)
			lamps.append(_flame(n, best + Vector3(0, 0.56, 0), false))
		elif _has(ph, ["rack"]):
			var x := Vector3(cos(yaw), 0, -sin(yaw))
			for sx in [-0.8, 0.8]:
				b.ybox(best + x * sx + Vector3(0, 0.85, 0), Vector3(0.08, 1.7, 0.08), yaw, Color(0.45, 0.34, 0.22), WOOD, true)
			b.ybox(best + Vector3(0, 1.6, 0), Vector3(1.75, 0.06, 0.06), yaw, Color(0.45, 0.34, 0.22), WOOD)
			for k in 5:
				b.ybox(best + x * (-0.6 + k * 0.3) + Vector3(0, 1.32, 0), Vector3(0.13, 0.5, 0.03), yaw, Color(0.72, 0.6, 0.48) if _has(ph, ["fish", "char", "eel", "oyster"]) else Color(0.48, 0.2, 0.15), HIDE)
		elif _has(ph, ["pot", "griddle", "steeping"]):
			for k in 3:
				var a := TAU * k / 3.0
				b.ybox(best + Vector3(cos(a) * 0.26, 0.09, sin(a) * 0.26), Vector3(0.2, 0.18, 0.2), a, Color(0.42, 0.42, 0.43), STONE)
			b.ybox(best + Vector3(0, 0.36, 0), Vector3(0.44, 0.36, 0.44), 0.4, Color(0.5, 0.33, 0.22) if not _has(ph, ["griddle"]) else Color(0.4, 0.4, 0.4), STONE, true)
		elif _has(ph, ["stack", "peat", "dung", "chips", "cakes"]):
			for k in 6:
				b.ybox(best + Vector3(-0.3 + (k % 3) * 0.3, 0.12 + int(k / 3) * 0.22, 0), Vector3(0.28, 0.2, 0.36), yaw, Color(0.18, 0.14, 0.11) if ph.find("peat") >= 0 else Color(0.38, 0.32, 0.22), STONE, k < 3)
		elif _has(ph, ["stones", "ash", "pit", "roasting"]):
			for k in 5:
				var a := TAU * k / 5.0
				b.ybox(best + Vector3(cos(a) * 0.35, 0.08, sin(a) * 0.35), Vector3(0.2, 0.16, 0.2), a, Color(0.36, 0.34, 0.33), STONE)
		elif _has(ph, ["gourd", "bag", "skin bag"]):
			b.ybox(best + Vector3(0, 0.2, 0), Vector3(0.32, 0.4, 0.32), yaw, Color(0.5, 0.38, 0.24), HIDE, true)
		else:
			for k in 3:
				b.beam(best + Vector3(-0.35, 0.05 + k * 0.06, k * 0.05), best + Vector3(0.35, 0.05 + k * 0.06, k * 0.06), Vector3.UP, 0.06, 0.06, colour_of(ph, pal), WOOD)
	if b.tris() > 0:
		n.add_child(b.node("Props"))
		var cb := PropCollision.body(n, "Body")
		for bx in b.boxes:
			PropCollision.box(cb, bx[0], bx[1])
	n.set_meta("lamps", lamps)
	n.set_meta("what", what)
	n.set_meta("tris", b.tris())
	return n


static func _has(s: String, words: Array) -> bool:
	for w in words:
		if s.find(str(w)) >= 0:
			return true
	return false


# --- The player brings (§EL.3) --------------------------------------------------

## What bench material a carried item is (sim.workshop.item_materials;
## an item with its own "material" field is that), or "".
static func material_of(item: Dictionary) -> String:
	if item.has("material"):
		return str(item.material)
	var im: Dictionary = W.get("item_materials", {})
	var key := "%s:%s" % [str(item.get("kind", "")), str(item.get("fuel", item.get("part", "")))]
	if im.has(key):
		return str(im[key])
	if str(item.get("kind", "")) == "plant_sample" and str(item.get("part", "")) == "bark":
		return "bark"
	return ""


## The bench that works `material` (player_brings_to_bench): "soft",
## "hard", "hearth" or "".
static func bench_for(material: String) -> String:
	var pb: Dictionary = W.get("player_brings_to_bench", {})
	for b in pb:
		if (pb[b] as Array).has(material):
			return str(b)
	return ""


## Lay what the player brought on `bn` (a bench node): it joins the
## bench's pieces (at most 4 laid shown) and the camp's state remembers it.
static func lay(bn: Node3D, material: String, st: Dictionary) -> void:
	var phrase: String = {"cordage_fibre": "a bundle of fibre for cord", "timber": "a pole of timber", "bark": "bark sheets laid out", "hide": "a hide pegged out",
		"clay": "a lump of clay in a bowl", "stone": "a knapping stone", "bone": "bones in a row", "antler": "an antler tine", "shell": "shell in a row"}.get(material, "a bundle")
	var laid: Array = bn.get_meta("laid", [])
	laid.append(phrase)
	while laid.size() > 4:
		laid.pop_front()
	bn.set_meta("laid", laid)
	_pieces(bn)
	if not st.is_empty():
		var by: Dictionary = st.get("bench_laid", {})
		var arr: Array = by.get(str(bn.get_meta("bench", "")), [])
		arr.append(phrase)
		while arr.size() > 4:
			arr.pop_front()
		by[str(bn.get_meta("bench", ""))] = arr
		st["bench_laid"] = by
		WorldSave.mark_dirty()


## A bench of a built workshop within `r` of scene `pos`, or null.
static func bench_near(ws: Node3D, pos: Vector3, r: float) -> Node3D:
	if ws == null or not is_instance_valid(ws):
		return null
	var benches: Dictionary = ws.get_meta("benches", {})
	for k in benches:
		var bn: Node3D = benches[k]
		if bn.global_position.distance_to(pos) < r:
			return bn
	return null


## Restore what the player laid before (the camp's state) on a new build.
static func restore(ws: Node3D, st: Dictionary) -> void:
	var by: Dictionary = st.get("bench_laid", {})
	var benches: Dictionary = ws.get_meta("benches", {})
	for k in by:
		if benches.has(k):
			(benches[k] as Node3D).set_meta("laid", (by[k] as Array).duplicate())
			_pieces(benches[k])


# --- The folk's day (the smallest walker, §BV not built) ---------------------

## Keep a sitter's place in the fire circle (its parent-frame transform):
## where it walks back to at dusk.
static func remember_home(holder: Node3D) -> void:
	holder.set_meta("home", holder.transform)
	holder.set_meta("station", "fire")


## One frame of the folk's day: each holder (meta folk_i) goes where
## `plan` says, walking (sim.jobs.walk_mps) or, with `snap`, at once; at a
## bench it plays that bench's idles, on the porch it rests. Holders at
## the fire are left to FireCircle (fire_sitters() lists them). The
## benches' sounds follow who is working (heard within `hear_m` of `pp`).
static func drive(holders: Array, ws: Node3D, plan: Array, delta: float, time: float, pp: Vector3, snap: bool) -> void:
	if ws == null or not is_instance_valid(ws):
		return
	var seats: Dictionary = ws.get_meta("seats", {})
	var jobs: Dictionary = CampSim.SIM.get("jobs", {})
	var speed := float(jobs.get("walk_mps", 1.3))
	snap = snap or instant
	# Who holds (or is walking to) which seat.
	var taken := {}
	for h in holders:
		if is_instance_valid(h) and str((h as Node3D).get_meta("seat_key", "")) != "":
			taken[str((h as Node3D).get_meta("seat_key"))] = h
	for hv in holders:
		var h: Node3D = hv
		if not is_instance_valid(h) or not h.has_meta("home"):
			continue
		var i := int(h.get_meta("folk_i", -1))
		var want := str(plan[i]) if i >= 0 and i < plan.size() else "fire"
		var going := str(h.get_meta("going", ""))
		var cur := str(h.get_meta("station", "fire"))
		var dest := going if going != "" else cur
		if want != dest:
			var to := Transform3D()
			var key := ""
			if want == "fire":
				to = h.get_meta("home")
			elif want == "out":
				to = _out_point(h, ws)
			else:
				var list: Array = seats.get(want, [])
				var pref := i % maxi(list.size(), 1)
				for k in list.size():
					var si := (pref + k) % list.size()
					var kk := "%s:%d" % [want, si]
					if not taken.has(kk) or taken[kk] == h:
						key = kk
						break
				if key == "":
					want = "out"
					to = _out_point(h, ws)
				else:
					var s: Dictionary = list[int(key.split(":")[1])]
					to = Transform3D(Basis.looking_at(s.face, Vector3.UP), (s.pos as Vector3) + Vector3(0, clampf(SEAT_H - FireCircle.SEAT_H, -0.14, 0.08) - SEAT_H, 0))
			var old_key := str(h.get_meta("seat_key", ""))
			if old_key != "" and taken.get(old_key) == h:
				taken.erase(old_key)
			if key != "":
				taken[key] = h
			h.set_meta("seat_key", key)
			_leave(h)
			var from: Transform3D = h.transform
			if cur == "out" and going == "":
				from = _out_point(h, ws)
				if bool((h.get_parent() as Node).get_meta("hitboxes_on", true)):
					Hitboxes.set_active(h.get_meta("hitboxes", []), true)
			h.set_meta("walk_from", from)
			h.set_meta("walk_to", to)
			h.set_meta("walk_t", 0.0)
			h.set_meta("going", want)
			going = want
			h.visible = true
			_stand(h, true)
			if snap:
				h.set_meta("walk_t", 1.0e9)
		if going != "":
			_walking(h, delta, speed)
			continue
		match cur:
			"soft", "hard", "kiln", "hearth":
				_bench_work(h, cur, time, delta)
			"porch":
				_rest(h, time, delta)
	_sounds(ws, holders, pp)


## The holders sitting at the fire now (FireCircle plays them).
static func fire_sitters(holders: Array) -> Array:
	var out: Array = []
	for h in holders:
		if not is_instance_valid(h):
			continue
		var n: Node3D = h
		if str(n.get_meta("going", "")) == "" and str(n.get_meta("station", "fire")) == "fire":
			out.append(n)
	return out


## Where a folk goes out of sight to gather: out_m from the fire, its own
## seeded way, facing out.
static func _out_point(h: Node3D, ws: Node3D) -> Transform3D:
	var om: Array = W.get("out_m", [18, 26])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([str(h.name), int(h.get_meta("folk_i", 0)), "out"])
	var a := rng.randf() * TAU
	var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(float(om[0]), float(om[1]))
	var home: Transform3D = h.get_meta("home")
	p.y = home.origin.y
	return Transform3D(Basis.looking_at(p.normalized(), Vector3.UP), p)


static func _stand(h: Node3D, up: bool) -> void:
	var body := h.get_node_or_null("Body")
	if body != null and body is PlayerBody:
		(body as PlayerBody).seated = not up


## Leaving a station: what was in hand put away, the circle's loop ended.
static func _leave(h: Node3D) -> void:
	FireCircle._props(h, "")
	h.set_meta("idle", "")
	h.set_meta("bench_idle", "")
	var bp = h.get_meta("bench_prop") if h.has_meta("bench_prop") else null
	if bp != null and is_instance_valid(bp):
		(bp as Node).queue_free()
	h.remove_meta("bench_prop")


static func _walking(h: Node3D, delta: float, speed: float) -> void:
	var from: Transform3D = h.get_meta("walk_from")
	var to: Transform3D = h.get_meta("walk_to")
	var len_m := maxf(from.origin.distance_to(to.origin), 0.01)
	var t := float(h.get_meta("walk_t", 0.0)) + delta
	h.set_meta("walk_t", t)
	var k := clampf(t * speed / len_m, 0.0, 1.0)
	var body := h.get_node_or_null("Body")
	if k >= 1.0:
		h.transform = to
		var going := str(h.get_meta("going", ""))
		h.set_meta("station", going)
		h.set_meta("going", "")
		h.set_meta("base_yaw", h.rotation.y)
		_stand(h, going == "out")
		h.visible = going != "out"
		if going == "out":
			Hitboxes.set_active(h.get_meta("hitboxes", []), false)
		return
	var p := from.origin.lerp(to.origin, k)
	var dir := (to.origin - from.origin)
	dir.y = 0.0
	h.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP) if dir.length() > 0.01 else from.basis, p)
	if body != null and body is PlayerBody:
		var par := h.get_parent() as Node3D
		var v := dir.normalized() * speed
		(body as PlayerBody).set_velocity(par.global_basis * v if par != null else v)
		(body as PlayerBody).set_motion(0.35, delta)


## At a bench: that bench's idles only, one at a time, each held
## idle_hold_s, with its own motion and the thing in hand.
static func _bench_work(h: Node3D, bench: String, time: float, delta: float) -> void:
	var idles := bench_idles(bench)
	if idles.is_empty():
		return
	var idle := str(h.get_meta("bench_idle", ""))
	if idle == "" or not idles.has(idle) or time >= float(h.get_meta("bench_until", -1.0)):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([str(h.name), int(time * 10.0), bench])
		var nxt := str(idles[rng.randi() % idles.size()])
		if nxt == idle and idles.size() > 1:
			nxt = str(idles[(idles.find(idle) + 1) % idles.size()])
		idle = nxt
		var hs: Array = W.get("idle_hold_s", [15, 40])
		h.set_meta("bench_idle", idle)
		h.set_meta("bench_from", time)
		h.set_meta("bench_until", time + rng.randf_range(float(hs[0]), float(hs[1])))
		_hand(h, idle)
	var pose := pose_of(idle, time - float(h.get_meta("bench_from", time)), float(h.get_meta("phase", 0.0)))
	_apply(h, pose, delta)


static func _rest(h: Node3D, time: float, delta: float) -> void:
	var ph := float(h.get_meta("phase", 0.0))
	_apply(h, {"l": Vector3(0.3, 0, -0.05), "r": Vector3(0.3, 0, 0.05), "hood": 0.12 + 0.05 * sin(time * 0.3 + ph), "look": 0.5 * sin(time * 0.17 + ph * 2.0)}, delta)


## The arms and hood toward `pose` (added to the seated rest, as the
## fire circle's loops are).
static func _apply(h: Node3D, pose: Dictionary, delta: float) -> void:
	var arms: Array = h.get_meta("arms", [])
	if not h.has_meta("arm_rest") and arms.size() >= 2:
		h.set_meta("arm_rest", [(arms[0] as Node3D).rotation, (arms[1] as Node3D).rotation])
	if h.has_meta("arm_rest"):
		var rest: Array = h.get_meta("arm_rest")
		for k in mini(arms.size(), 2):
			var want: Vector3 = (rest[k] as Vector3) + (pose.l if k == 0 else pose.r)
			var arm: Node3D = arms[k]
			arm.rotation = arm.rotation.lerp(want, clampf(delta * 6.0, 0.0, 1.0))
	var head: Node3D = h.get_meta("head") if h.has_meta("head") else null
	if head != null:
		head.rotation.x = lerpf(head.rotation.x, float(pose.hood), clampf(delta * 4.0, 0.0, 1.0))
		head.rotation.y = lerp_angle(head.rotation.y, float(pose.get("look", 0.0)), clampf(delta * 2.0, 0.0, 1.0))


## A bench idle's arms (left, right; added to the seated rest) and hood
## at `t` s in: each its own small motion.
static func pose_of(idle: String, t: float, ph: float) -> Dictionary:
	var l := Vector3.ZERO
	var r := Vector3.ZERO
	var hood := 0.5
	match idle:
		"sew_with_awl":
			var push := maxf(sin(t * 2.2 + ph), 0.0)
			l = Vector3(0.75, 0, -0.15)
			r = Vector3(0.7 + 0.25 * sin(t * 2.2 + ph), 0, 0.15 + 0.25 * push)
		"twist_cord":
			l = Vector3(0.6 + 0.08 * sin(t * 5.0 + ph), 0, -0.1)
			r = Vector3(0.62, 0, 0.12 + 0.2 * sin(t * 1.3 + ph))
			hood = 0.42
		"scrape_hide":
			var k := sin(t * 1.6 + ph)
			l = Vector3(0.85 + 0.25 * k, 0, -0.12)
			r = Vector3(0.85 + 0.25 * k, 0, 0.12)
			hood = 0.58
		"plait_basket":
			l = Vector3(0.65 + 0.12 * sin(t * 3.0 + ph), 0, -0.2)
			r = Vector3(0.65 + 0.12 * sin(t * 3.0 + ph + PI), 0, 0.2)
		"knap":
			var strike := pow(maxf(sin(t * 2.6 + ph), 0.0), 6.0)
			l = Vector3(0.7, 0, -0.1)
			r = Vector3(1.05 - 0.45 * strike, 0, 0.12)
			hood = 0.55
		"grind_axe":
			var k2 := sin(t * 1.2 + ph)
			l = Vector3(0.95 + 0.18 * k2, 0, -0.06)
			r = Vector3(0.95 + 0.18 * k2, 0, 0.06)
			hood = 0.62
		"bow_drill":
			l = Vector3(0.95, 0, -0.05)
			r = Vector3(0.72, 0, 0.1 + 0.35 * sin(t * 4.5 + ph))
		"hollow_bowl_with_coal":
			l = Vector3(0.7, 0, -0.15)
			r = Vector3(0.75 + 0.1 * sin(t * 0.9 + ph), 0, 0.1)
			hood = 0.65 + 0.1 * sin(t * 0.5 + ph)
		# The kiln (§EI.3, the potter): a coil pot turned in the lap, and
		# brush pushed into the mouth.
		"shape_pot":
			var turn := sin(t * 1.8 + ph)
			l = Vector3(0.7, 0, -0.2 + 0.08 * turn)
			r = Vector3(0.72, 0, 0.2 + 0.08 * turn)
			hood = 0.6
		"feed_kiln":
			var push := smoothstep(0.0, 1.0, fposmod(t * 0.4 + ph, 1.0)) * (1.0 - smoothstep(0.7, 1.0, fposmod(t * 0.4 + ph, 1.0)))
			l = Vector3(0.4, 0, -0.1)
			r = Vector3(0.6 + 0.7 * push, 0, 0.1)
			hood = 0.35 + 0.2 * push
		# The hearth (the lighting trade): stirring the rendering pot,
		# hanging strips, filling the lamp.
		"stir_pot":
			r = Vector3(0.95 + 0.15 * sin(t * 2.0 + ph), 0, 0.15 + 0.15 * cos(t * 2.0 + ph))
			l = Vector3(0.3, 0, -0.05)
			hood = 0.45
		"hang_strips":
			var up := maxf(sin(t * 0.9 + ph), 0.0)
			l = Vector3(0.6 + 1.0 * up, 0, -0.1)
			r = Vector3(0.6 + 1.0 * up, 0, 0.1)
			hood = 0.1 - 0.15 * up
		"fill_lamp":
			l = Vector3(0.8, 0, -0.1)
			r = Vector3(0.85 + 0.12 * maxf(sin(t * 1.1 + ph), 0.0), 0, 0.12)
			hood = 0.55
	return {"l": l, "r": r, "hood": hood}


## The thing in hand for a bench idle (one small piece; the coal glows).
static func _hand(h: Node3D, idle: String) -> void:
	var old = h.get_meta("bench_prop") if h.has_meta("bench_prop") else null
	if old != null and is_instance_valid(old):
		(old as Node).queue_free()
	var arms: Array = h.get_meta("arms", [])
	if arms.size() < 2:
		return
	var hand: Node3D = arms[1]
	var at := Vector3(0, -PlayerBody.ARM_M, 0.03)
	var p: Node3D = null
	match idle:
		"sew_with_awl":
			p = CreatureBodies.box(hand, Vector3(0.02, 0.02, 0.12), at, Color(0.84, 0.8, 0.68))
		"twist_cord":
			p = CreatureBodies.box(hand, Vector3(0.3, 0.02, 0.02), at, Color(0.66, 0.6, 0.42))
		"scrape_hide":
			p = CreatureBodies.box(hand, Vector3(0.1, 0.03, 0.07), at, Color(0.42, 0.42, 0.44))
		"plait_basket":
			p = CreatureBodies.box(arms[0], Vector3(0.24, 0.14, 0.22), at, Color(0.68, 0.6, 0.38))
		"knap":
			p = CreatureBodies.box(hand, Vector3(0.08, 0.07, 0.08), at, Color(0.48, 0.47, 0.45))
		"grind_axe":
			p = CreatureBodies.box(hand, Vector3(0.14, 0.04, 0.07), at, Color(0.36, 0.38, 0.38))
		"bow_drill":
			p = CreatureBodies.box(hand, Vector3(0.42, 0.02, 0.02), at, Color(0.4, 0.3, 0.2))
		"hollow_bowl_with_coal":
			p = CreatureBodies.box(arms[0], Vector3(0.22, 0.1, 0.22), at, Color(0.44, 0.32, 0.2))
			CreatureBodies.box(p, Vector3(0.04, 0.03, 0.04), Vector3(0, 0.06, 0), Color(1.0, 0.42, 0.1), 2.5)
		"shape_pot":
			p = CreatureBodies.box(arms[0], Vector3(0.2, 0.24, 0.2), at, Color(0.6, 0.42, 0.3))
		"feed_kiln":
			p = CreatureBodies.box(hand, Vector3(0.5, 0.06, 0.06), at, Color(0.45, 0.36, 0.22))
		"stir_pot":
			p = CreatureBodies.box(hand, Vector3(0.03, 0.03, 0.6), at, Color(0.4, 0.3, 0.2))
		"hang_strips":
			p = CreatureBodies.box(hand, Vector3(0.12, 0.35, 0.02), at, Color(0.48, 0.2, 0.15))
		"fill_lamp":
			p = CreatureBodies.box(arms[0], Vector3(0.16, 0.06, 0.12), at, Color(0.5, 0.52, 0.5))
	if p != null:
		p.name = "BenchProp"
		h.set_meta("bench_prop", p)


## Each bench's loop: the sound of what its first worker is doing, while
## the player is in earshot; silent when nobody works there.
static func _sounds(ws: Node3D, holders: Array, pp: Vector3) -> void:
	var benches: Dictionary = ws.get_meta("benches", {})
	for k in benches:
		var bn: Node3D = benches[k]
		var pl: AudioStreamPlayer3D = bn.get_meta("player", null)
		if pl == null or not is_instance_valid(pl):
			continue
		var idle := ""
		for h in holders:
			if is_instance_valid(h) and str((h as Node3D).get_meta("station", "")) == k and str((h as Node3D).get_meta("going", "")) == "":
				idle = str((h as Node3D).get_meta("bench_idle", ""))
				if idle != "":
					break
		var kind := str(SOUND_OF.get(idle, ""))
		var row := Audio3D.row(kind) if kind != "" else {}
		var hear := float(row.get("max_distance", 22.0)) + 4.0
		if kind == "" or bn.global_position.distance_to(pp) > hear:
			if pl.playing:
				pl.stop()
			bn.set_meta("sounding", "")
			continue
		if str(bn.get_meta("sounding", "")) != kind:
			Audio3D.apply(pl, kind)
			pl.stream = SoundSynth.stream(kind + "_loop", hash(str(ws.get_path())) % 3)
			Audio3D.play(pl)
			bn.set_meta("sounding", kind)


## The workshop's things that follow the hour: the hearth lamps lit from
## dusk (`night`), the kiln smoking thin while `potter_working`.
static func tick(ws: Node3D, hearth: Node3D, night: bool, potter_working: bool) -> void:
	if hearth != null and is_instance_valid(hearth):
		for f in hearth.get_meta("lamps", []):
			if is_instance_valid(f) and not bool((f as Node3D).get_meta("always", false)):
				(f as Node3D).visible = night
	if ws == null or not is_instance_valid(ws) or not ws.has_meta("kiln"):
		return
	var kiln: Node3D = ws.get_meta("kiln")
	if not is_instance_valid(kiln):
		return
	kiln.set_meta("smoking", potter_working)
	var up := kiln.global_basis.y.normalized()
	Smoke.tick_flame(kiln, kiln.global_position + up * 1.0, up, 0.55, "low" if potter_working else "out")


## The triangles of a workshop with all its props (hut, benches' pieces,
## sign, kiln; `hearth` its hearth props).
static func tris(ws: Node3D, hearth: Node3D = null) -> int:
	var n := int(ws.get_meta("hut_tris", 0))
	for k in (ws.get_meta("benches", {}) as Dictionary):
		n += int(((ws.get_meta("benches") as Dictionary)[k] as Node3D).get_meta("tris", 0))
	var sg: Node3D = ws.get_meta("sign", null)
	if sg != null:
		n += int(sg.get_meta("tris", 0))
	if ws.has_meta("kiln"):
		n += int((ws.get_meta("kiln") as Node3D).get_meta("tris", 0))
	if hearth != null:
		n += int(hearth.get_meta("tris", 0))
	return n
