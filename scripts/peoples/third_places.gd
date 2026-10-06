class_name ThirdPlaces
## Third places: where folk just sit (design 5 Oct §EM; camps.json →
## sim.third_places). Mike: "cozy spots where people go to hang out and
## chillax." Not work, not sleep; the fire circle is the first one. At
## each camp, after its circle, the places that exist and that its people
## file lists (huts.third_places) are placed:
##   - the soak: a hot spring pool within soak.hot_spring_m (the
##     HOT_SPRING biome, 27 Sept §0): a pool with its rim stones, steam off
##     it (§CV's smoke, white and slow); folk sit IN it to the chest with
##     their hoods back (the one time a hood is down), in the afternoon;
##   - the great tree bench: a log or a flat stone at the foot of the
##     biggest tree within TREE_M, back to the trunk, facing its open side,
##     in the heat of the day;
##   - the water rock: a flat stone on the nearest bank within WATER_M,
##     its bank boulder behind, feet toward the water (the line out, when
##     the people know fishing_line), by day;
##   - the hut porch: the workshop's porch seat (§EL), by day;
##   - the people's own place (the phrase in huts.third_places): placed at
##     the spot it names where the camp has it (the weir), else skipped.
## Prospect and refuge (§EG.4): every seat has something solid within 2 m
## behind it (trunk, rim stone, boulder, hut wall, a bank) and open ground
## or water in front (prospect_ok); a spot that fails is moved round its
## feature, or skipped.
## Who goes (live): in a kind's hours, folk sitting at the fire who are
## not its keeper (the circle's one who stays) walk there, up to
## max_at_once, and sit; the hours over, they walk back. Folk at a bench,
## out gathering, carrying the meal or the gift are never taken: third
## places only fill hours a folk was already idle. Nothing here moves a
## sim number (counts_as_rest). Their idles are one set (sit, lean_back,
## look_out, the pipe; the line at the water rock), played by FireCircle,
## which also turns the hood to the player (notice).
## THIRD_PLACES=0 in the environment turns them off (A/B, the check).

static var T: Dictionary = (Tuning.section("camps", "sim").get("third_places", {}) as Dictionary)
static var ON := OS.get_environment("THIRD_PLACES") != "0"
const KINDS := ["soak", "great_tree_bench", "water_rock", "hut_porch"]
static var TREE_M := float(T.get("tree_m", 60.0))
static var WATER_M := float(T.get("water_m", 60.0))
## How far behind a seat something solid must stand, and how much of the
## view in front must be clear.
const BACK_M := 2.0
const VIEW_M := 1.5
## A sitter in the soak sits this far below the pool's rim (to the chest),
## for a grown folk (a child by its size).
const SOAK_DEPTH := 0.5
## The steam off the soak: top (m), width (m), density.
const STEAM := Vector3(3.2, 2.4, 0.45)
## The checks: walks happen at once.
static var instant := false


static func kind_row(kind: String) -> Dictionary:
	return ((T.get("kinds", {}) as Dictionary).get(kind, {}) as Dictionary)


## The kinds a people's file lists, in its order.
static func listed(people: Dictionary) -> Array:
	var out: Array = []
	for e in (people.get("huts", {}) as Dictionary).get("third_places", []):
		if KINDS.has(str(e)):
			out.append(str(e))
	return out


## The people's own place: the phrase in huts.third_places, or "".
static func own_phrase(people: Dictionary) -> String:
	for e in (people.get("huts", {}) as Dictionary).get("third_places", []):
		if not KINDS.has(str(e)):
			return str(e)
	return ""


## The local hours a kind is used: midday_heat the middle third of the
## gather hours, afternoon the last third, day (or none) all of them.
static func hours_of(kind: String) -> Vector2:
	var gh: Array = (CampSim.SIM.get("loop", {}) as Dictionary).get("gather_hours", [7, 17])
	var a := float(gh[0])
	var b := float(gh[1])
	var third := (b - a) / 3.0
	match str(kind_row(kind).get("hours", "day")):
		"midday_heat":
			return Vector2(a + third, a + 2.0 * third)
		"afternoon":
			return Vector2(a + 2.0 * third, b)
	return Vector2(a, b)


static func max_of(kind: String) -> int:
	return int(kind_row(kind).get("max_at_once", 2))


static func trunk_r(height_m: float) -> float:
	return clampf(0.12 + height_m * 0.012, 0.15, 1.2)


# --- Placing ---------------------------------------------------------------------

## Place the camp's third places under `root` (origin the fire). `ctx`:
## world, chunks, d (the fire's direction), ws (the workshop or null),
## ground (Callable: root-local point -> local ground y), body
## (StaticBody3D), rng, biome, people_id, stones, bark, cloth, weir (Node3D
## or null). Returns [{kind, seats: [{pos, face, height, water}], max,
## hours}] (root frame) and keeps it on root (meta "third_places"); the
## solids the seats lean on on meta "tp_solids" ([pos, radius]).
static func place(root: Node3D, people: Dictionary, ctx: Dictionary) -> Array:
	var out: Array = []
	var solids: Array = []
	root.set_meta("tp_solids", solids)
	if not ON:
		root.set_meta("third_places", out)
		return out
	var want := listed(people)
	var trees := _trees(root, ctx)
	for t in trees:
		solids.append([t[0], t[1]])
	if ctx.get("ws") != null and is_instance_valid(ctx.ws):
		var ws: Node3D = ctx.ws
		solids.append([Vector3(ws.position.x, 0, ws.position.z), Workshop.HUT_HALF])
	for kind in want:
		var p := {}
		match kind:
			"great_tree_bench":
				p = _tree_bench(root, ctx, trees, solids)
			"water_rock":
				p = _water_rock(root, ctx, solids, people)
			"soak":
				p = _soak(root, ctx, solids)
			"hut_porch":
				p = _porch(root, ctx, solids)
		if not p.is_empty() and not (p.seats as Array).is_empty():
			p["kind"] = kind
			p["max"] = mini(max_of(kind), (p.seats as Array).size())
			p["hours"] = hours_of(kind)
			out.append(p)
	root.set_meta("third_places", out)
	place_own(root, people, ctx)
	return out


## The people's own place (huts.third_places' phrase), where the camp has
## the spot it names: the weir (it is built when the camp has one, so this
## runs again then). Other spots are skipped.
static func place_own(root: Node3D, people: Dictionary, ctx: Dictionary) -> void:
	if not ON or bool(root.get_meta("tp_own", false)):
		return
	var own := own_phrase(people).to_lower()
	if own.find("weir") < 0 or ctx.get("weir") == null or not is_instance_valid(ctx.weir):
		return
	var out: Array = root.get_meta("third_places", [])
	var wp := _own_at(root, ctx, (ctx.weir as Node3D).position, root.get_meta("tp_solids", []))
	if wp.is_empty():
		return
	wp["kind"] = "own"
	wp["phrase"] = own
	wp["max"] = 1
	wp["hours"] = hours_of("water_rock")
	out.append(wp)
	root.set_meta("third_places", out)
	root.set_meta("tp_own", true)


## The trees round the fire (loaded chunks): [local foot, trunk radius,
## height, species index], within TREE_M + 10.
static func _trees(root: Node3D, ctx: Dictionary) -> Array:
	var out: Array = []
	var chunks: ChunkManager = ctx.get("chunks")
	if chunks == null:
		return out
	var c := root.global_position
	for key in chunks.chunks:
		var ch: TerrainChunk = chunks.chunks[key]
		if ch.global_position.distance_to(c) > 700.0:
			continue
		for i in ch.trees.size():
			var b := ch.tree_base(i)
			if b.distance_to(c) > TREE_M + 10.0:
				continue
			var lp := root.to_local(b)
			var h := float(ch.trees[i][1])
			out.append([Vector3(lp.x, lp.y, lp.z), trunk_r(h), h, int(ch.trees[i][2])])
	return out


## Prospect and refuge at a seat (root frame): something solid within
## BACK_M behind (a solid's circle, or the ground rising half a metre: a
## bank) and nothing solid within VIEW_M in front, nor the ground rising
## a metre within 3 m (a wall of earth). `ground` the local ground.
static func prospect_ok(seat: Dictionary, solids: Array, ground: Callable) -> bool:
	var p: Vector3 = seat.pos
	var f: Vector3 = (seat.face as Vector3)
	f.y = 0.0
	f = f.normalized()
	var back := false
	for s in solids:
		var c: Vector3 = s[0]
		var r := float(s[1])
		var to := Vector3(c.x - p.x, 0, c.z - p.z)
		var along := -to.dot(f)
		var side := (to + f * along).length()
		if along > 0.0 and along - r <= BACK_M and side <= r + 0.35:
			back = true
		var ahead := to.dot(f)
		if ahead > 0.0 and ahead - r < VIEW_M and (to - f * ahead).length() < r * 0.9 and not bool(seat.get("water", false)):
			return false
	var y0: float = float(ground.call(p)) if ground.is_valid() else p.y
	if not back and ground.is_valid():
		for k in [1.0, 1.5, 2.0]:
			if float(ground.call(p - f * k)) - y0 >= 0.5:
				back = true
	if ground.is_valid() and not bool(seat.get("water", false)):
		if float(ground.call(p + f * 3.0)) - y0 > 1.0:
			return false
	return back


static func _seat_ctx(ctx: Dictionary) -> Dictionary:
	return {"bark": ctx.get("bark", Color(0.36, 0.25, 0.16)), "stones": ctx.get("stones", RuinBuilder.STONES), "ground": ctx.get("ground_col", Color(0.35, 0.42, 0.22)), "cloth": ctx.get("cloth", Color(0.45, 0.3, 0.2))}


## A seat mesh of `kind` at `at` (root frame) for a sitter facing `face`.
static func _seat(root: Node3D, kind: String, at: Vector3, face: Vector3, ctx: Dictionary, span := 1) -> float:
	var a := atan2(face.z, face.x)
	var h := float((((FireCircle.SEATS.get("kinds", {}) as Dictionary).get(kind, {})) as Dictionary).get("height_m", 0.35))
	FireCircle._seat_mesh(root, kind, at, a, h, span, ctx.rng, _seat_ctx(ctx), ctx.body)
	var n := root.get_child(root.get_child_count() - 1)
	n.set_meta("third_place", true)
	return h


## The bench under the biggest tree within TREE_M: back to the trunk,
## facing the side with fewest trunks near.
static func _tree_bench(root: Node3D, ctx: Dictionary, trees: Array, solids: Array) -> Dictionary:
	var best: Array = []
	for t in trees:
		var p: Vector3 = t[0]
		var dist := Vector2(p.x, p.z).length()
		if dist > TREE_M or dist < 5.0:
			continue
		if best.is_empty() or float(t[2]) > float(best[2]):
			best = t
	if best.is_empty():
		return {}
	var tp: Vector3 = best[0]
	var r := float(best[1])
	var ground: Callable = ctx.ground
	var kinds := FireCircle.kinds_for(str(ctx.get("biome", "")), str(ctx.get("people_id", "")), "")
	var kind := "log"
	for k in kinds:
		if str(k) in ["log", "flat_stone", "stump", "rock"]:
			kind = str(k)
			break
	# The open side: the angle with the fewest trunks within 8 m ahead.
	var order: Array = []
	for i in 16:
		var a := TAU * i / 16.0
		var dir := Vector3(cos(a), 0, sin(a))
		var crowd := 0
		for t in trees:
			var to: Vector3 = (t[0] as Vector3) - tp
			to.y = 0.0
			if to.length() > 0.5 and to.length() < 8.0 and to.normalized().dot(dir) > 0.3:
				crowd += 1
		order.append([crowd, i, dir])
	order.sort_custom(func(x, y): return int(x[0]) < int(y[0]) or (int(x[0]) == int(y[0]) and int(x[1]) < int(y[1])))
	for o in order:
		var dir: Vector3 = o[2]
		var seats: Array = []
		var tan := Vector3(-dir.z, 0, dir.x)
		for k in [0.0, -0.55, 0.55]:
			var at: Vector3 = tp + dir * (r + 0.55) + tan * float(k)
			at.y = float(ground.call(at)) if ground.is_valid() else tp.y
			var seat := {"pos": at, "face": dir, "height": 0.35, "water": false}
			if prospect_ok(seat, solids, ground):
				seats.append(seat)
			if seats.size() >= max_of("great_tree_bench"):
				break
		if seats.is_empty():
			continue
		var mid: Vector3 = (seats[0] as Dictionary).pos
		var h := _seat(root, kind, mid, Vector3(-dir.z, 0, dir.x) if kind == "log" else dir, ctx, 2 if seats.size() >= 2 and kind == "log" else 1)
		for s in seats:
			(s as Dictionary).height = h
		return {"seats": seats, "tree": tp, "tree_h": float(best[2])}
	return {}


## The flat rock on the nearest bank within WATER_M (fresh water, never
## the sea), its bank boulder behind, facing the water.
static func _water_rock(root: Node3D, ctx: Dictionary, solids: Array, people: Dictionary) -> Dictionary:
	var world: Node = ctx.world
	var chunks: ChunkManager = ctx.chunks
	var d: Vector3 = ctx.d
	var ws := CampNeeds.water_spot(world, chunks, d)
	if str(ws.get("kind", "seep")) == "seep" or CubeSphere.surface_distance_m(ws.dir, d) > WATER_M:
		return {}
	var ground: Callable = ctx.ground
	var bank: Vector3 = root.to_local(world.to_scene(ws.dir, PlanetConst.RADIUS_M + chunks.ground_height(ws.dir)))
	var out_dir := Vector3(bank.x, 0, bank.z).normalized()
	for shift in [0.0, 2.0, -2.0, 4.0, -4.0, 6.0, -6.0]:
		var tan := Vector3(-out_dir.z, 0, out_dir.x)
		var at := bank + tan * float(shift)
		at.y = float(ground.call(at)) if ground.is_valid() else bank.y
		# Water in front, within a pace and a half.
		var front := root.to_global(at + out_dir * 1.5)
		var fd: Vector3 = world.dir_of(front)
		if chunks.water_level_at(fd) <= chunks.ground_height(fd) + 0.02:
			continue
		var boulder := at - out_dir * 0.85
		var trial: Array = solids.duplicate()
		trial.append([boulder, 0.45])
		var seat := {"pos": at, "face": out_dir, "height": 0.3, "water": true, "fish": _knows(people, "fishing_line")}
		if not prospect_ok(seat, trial, ground):
			continue
		solids.append([boulder, 0.45])
		var stones: Array = ctx.get("stones", RuinBuilder.STONES)
		var col: Color = stones[ctx.rng.randi() % stones.size()]
		var mi := MeshInstance3D.new()
		mi.mesh = RuinBuilder.rock_mesh(Vector3(1.0, 0.9, 0.8), ctx.rng.randi(), col, false)
		mi.material_override = RuinBuilder.material()
		mi.position = boulder + Vector3(0, 0.25, 0)
		mi.set_meta("third_place", true)
		root.add_child(mi)
		PropCollision.box(ctx.body, mi.transform, Vector3(0.8, 0.7, 0.65))
		var h := _seat(root, "flat_stone", at, out_dir, ctx)
		seat.height = h
		var seats: Array = [seat]
		var at2 := at + tan * 0.75
		at2.y = float(ground.call(at2)) if ground.is_valid() else at.y
		var seat2 := {"pos": at2, "face": out_dir, "height": h, "water": true, "fish": seat.fish}
		if max_of("water_rock") >= 2 and prospect_ok(seat2, solids, ground):
			seats.append(seat2)
		return {"seats": seats, "bank": at}
	return {}


static func _knows(people: Dictionary, technique: String) -> bool:
	for t in people.get("techniques", []):
		if t is Dictionary and str((t as Dictionary).get("id", "")) == technique:
			return true
	return false


## The nearest hot spring within soak.hot_spring_m: the spot (a direction)
## or Vector3.ZERO.
static func hot_spring_near(map: PlanetData, d: Vector3, reach_m: float) -> Vector3:
	var r := 20.0
	while r <= reach_m + 0.1:
		for k in 24:
			var p := CreatureSpawner._offset(d, TAU * k / 24.0 + r * 0.013, r)
			var c := map.cell_at(p)
			if int(map.biome[c]) == BiomeTemplates.HOT_SPRING and int(map.water[c]) == PlanetData.Water.NONE:
				return p
		r += 20.0
	return Vector3.ZERO


## The soak: a pool at the nearest hot spring, its rim stones, steam; the
## seats in the water, backs to the rim, facing the middle.
static func _soak(root: Node3D, ctx: Dictionary, solids: Array) -> Dictionary:
	var world: Node = ctx.world
	var chunks: ChunkManager = ctx.chunks
	var map: PlanetData = world.get("planet")
	var reach := float(kind_row("soak").get("hot_spring_m", 400.0))
	var hs := hot_spring_near(map, ctx.d, reach)
	if hs == Vector3.ZERO:
		return {}
	var ground: Callable = ctx.ground
	var c: Vector3 = root.to_local(world.to_scene(hs, PlanetConst.RADIUS_M + chunks.ground_height(hs)))
	c.y = float(ground.call(c)) if ground.is_valid() else c.y
	# The water level at the rim's highest ground (on a slope the pool is
	# held by its stones on the low side, never sunk on the high side).
	if ground.is_valid():
		for k in 8:
			var rp := c + Vector3(cos(TAU * k / 8.0), 0, sin(TAU * k / 8.0)) * 1.9
			c.y = maxf(c.y, float(ground.call(rp)))
	var pool := Node3D.new()
	pool.name = "Soak"
	pool.position = c
	pool.set_meta("third_place", true)
	pool.set_meta("dir", hs)
	root.add_child(pool)
	var water := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.9
	cm.bottom_radius = 1.9
	cm.height = 0.06
	cm.radial_segments = 16
	water.mesh = cm
	var wm := StandardMaterial3D.new()
	# R6: the water the brightest thing in view; warm water reads pale.
	wm.albedo_color = Color(0.62, 0.86, 0.92)
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	water.material_override = wm
	water.position = Vector3(0, 0.02, 0)
	water.name = "Water"
	pool.add_child(water)
	var stones: Array = ctx.get("stones", RuinBuilder.STONES)
	for i in 10:
		var a := TAU * i / 10.0
		var rp := Vector3(cos(a) * 2.2, 0.12, sin(a) * 2.2)
		var mi := MeshInstance3D.new()
		mi.mesh = RuinBuilder.rock_mesh(Vector3(0.7, 0.45, 0.55), ctx.rng.randi(), stones[i % stones.size()], false)
		mi.material_override = RuinBuilder.material()
		mi.position = rp
		mi.rotation.y = -a
		pool.add_child(mi)
		PropCollision.box(ctx.body, Transform3D(Basis(), c + rp), Vector3(0.6, 0.4, 0.5))
		solids.append([c + Vector3(rp.x, 0, rp.z), 0.35])
	var steam := Smoke.column(pool, "Steam", {"colour_near": "#E6ECF0", "colour_far": "#F2F5F7", "colour_shade": "#C4CCD6"})
	(steam.get_meta("mat") as ShaderMaterial).set_shader_parameter("rise_mps", 0.45)
	pool.set_meta("steam", steam)
	var seats: Array = []
	for i in max_of("soak"):
		var a := TAU * (i + 0.5) / float(max_of("soak"))
		var dir := Vector3(cos(a), 0, sin(a))
		var at := c + dir * 1.45
		at.y = c.y
		var seat := {"pos": at, "face": -dir, "height": FireCircle.SEAT_H, "water": true, "soak": true}
		if prospect_ok(seat, solids, ground):
			seats.append(seat)
	return {"seats": seats, "pool": c, "spring": hs}


## The workshop's porch seat (§EL), back to the hut's wall.
static func _porch(root: Node3D, ctx: Dictionary, solids: Array) -> Dictionary:
	if ctx.get("ws") == null or not is_instance_valid(ctx.ws):
		return {}
	var ws: Node3D = ctx.ws
	var seats: Array = []
	for s in (ws.get_meta("seats", {}) as Dictionary).get("porch", []):
		var seat := {"pos": (s as Dictionary).pos, "face": (s as Dictionary).face, "height": Workshop.SEAT_H, "water": false, "porch": true}
		if prospect_ok(seat, solids, ctx.ground):
			seats.append(seat)
	return {"seats": seats}


## The people's own place at a spot of the camp (`at`, root frame): a flat
## stone on the near side of it, a boulder behind, facing it.
static func _own_at(root: Node3D, ctx: Dictionary, at: Vector3, solids: Array) -> Dictionary:
	var ground: Callable = ctx.ground
	var dir := Vector3(at.x, 0, at.z).normalized()
	var p := at - dir * 1.2
	p.y = float(ground.call(p)) if ground.is_valid() else at.y
	var boulder := p - dir * 0.85
	solids.append([boulder, 0.45])
	var stones: Array = ctx.get("stones", RuinBuilder.STONES)
	var mi := MeshInstance3D.new()
	mi.mesh = RuinBuilder.rock_mesh(Vector3(1.0, 0.9, 0.8), ctx.rng.randi(), stones[0], false)
	mi.material_override = RuinBuilder.material()
	mi.position = boulder + Vector3(0, 0.25, 0)
	mi.set_meta("third_place", true)
	root.add_child(mi)
	PropCollision.box(ctx.body, mi.transform, Vector3(0.8, 0.7, 0.65))
	var seat := {"pos": p, "face": dir, "height": _seat(root, "flat_stone", p, dir, ctx), "water": false}
	if not prospect_ok(seat, solids, ground):
		return {}
	return {"seats": [seat]}


# --- Who goes ----------------------------------------------------------------------

## One frame at camp node `root`: in each place's hours, folk sitting at
## the fire (not its keeper, not walking for the meal or the gift) walk
## there and sit, up to its max; out of its hours they walk back. `holders`
## the camp's cloaked folk at the fire (meta folk_i, home); `keeper` the
## folk index who keeps the fire; `h` the local hour; `snap` walk at once
## (the player far). Returns the holders still at the fire; the ones at a
## third place play their idles (FireCircle) here.
static func live(root: Node3D, holders: Array, keeper: int, h: float, time: float, delta: float, pp: Vector3, fire: Node3D, snap: bool) -> Array:
	var places: Array = root.get_meta("third_places", [])
	var at_fire: Array = []
	var going: Array = []
	var gone: Array = root.get_meta("tp_folk", [])
	# Folk taken by something else (a bench, the meal) are let go.
	for hv in gone.duplicate():
		var n: Node3D = hv
		if not is_instance_valid(n) or str(n.get_meta("station", "fire")) != "fire" or str(n.get_meta("going", "")) != "" or bool(n.get_meta("sharing", false)):
			if is_instance_valid(n):
				_release(n)
			gone.erase(hv)
	if ON and not places.is_empty():
		# Back home when the place's hours are over.
		for hv in gone:
			var n: Node3D = hv
			var tp: Dictionary = n.get_meta("tp")
			var pl: Dictionary = places[int(tp.place)]
			var hr: Vector2 = pl.hours
			if (h < hr.x or h >= hr.y) and int(tp.leg) < 2:
				tp.leg = 2
				tp.t = 0.0
				tp["from"] = n.transform
				_hood(n, false)
				Workshop._stand(n, true)
		# Who goes: the idle at the fire, seeded by the day, place by place.
		var free: Array = []
		for hv in holders:
			var n: Node3D = hv
			if not is_instance_valid(n) or gone.has(n) or not n.visible:
				continue
			if int(n.get_meta("folk_i", -1)) == keeper or bool(n.get_meta("sharing", false)):
				continue
			if str(n.get_meta("station", "fire")) != "fire" or str(n.get_meta("going", "")) != "":
				continue
			free.append(n)
		free.sort_custom(func(x, y): return hash([str((x as Node).name), int(time / 600.0)]) < hash([str((y as Node).name), int(time / 600.0)]))
		for pi in places.size():
			var pl: Dictionary = places[pi]
			var hr: Vector2 = pl.hours
			if h < hr.x or h >= hr.y:
				continue
			var taken := {}
			for hv in gone:
				var tp: Dictionary = (hv as Node3D).get_meta("tp")
				if int(tp.place) == pi and int(tp.leg) < 2:
					taken[int(tp.seat)] = true
			for si in (pl.seats as Array).size():
				if taken.size() >= int(pl.max) or free.is_empty():
					break
				if taken.has(si):
					continue
				var n: Node3D = free.pop_front()
				var seat: Dictionary = pl.seats[si]
				var body := n.get_node_or_null("Body") as Node3D
				var size_k := clampf(body.scale.y if body != null else 1.0, 0.4, 1.3)
				var y := clampf(float(seat.height) - FireCircle.SEAT_H, -0.14, 0.08) - (SOAK_DEPTH * size_k if bool(seat.get("soak", false)) else 0.0)
				var to := Transform3D(Basis.looking_at(seat.face, Vector3.UP), (seat.pos as Vector3) + Vector3(0, y, 0))
				n.set_meta("tp", {"place": pi, "seat": si, "leg": 0, "t": 0.0, "from": n.transform, "to": to, "kind": str(pl.kind)})
				FireCircle._props(n, "")
				n.set_meta("idle", "")
				Workshop._stand(n, true)
				taken[si] = true
				gone.append(n)
	elif not gone.is_empty():
		for hv in gone:
			var n: Node3D = hv
			var tp: Dictionary = n.get_meta("tp")
			if int(tp.leg) < 2:
				tp.leg = 2
				tp.t = 0.0
				tp["from"] = n.transform
				_hood(n, false)
	# The walks, and the ones sitting.
	var speed := float((CampSim.SIM.get("jobs", {}) as Dictionary).get("walk_mps", 1.3))
	var sitting := {}
	for hv in gone.duplicate():
		var n: Node3D = hv
		var tp: Dictionary = n.get_meta("tp")
		tp.t = float(tp.t) + (1.0e6 if (instant or snap) else delta)
		match int(tp.leg):
			0:
				if Sharing._move(n, tp.from, tp.to, float(tp.t), speed, delta):
					n.transform = tp.to
					n.set_meta("base_yaw", n.rotation.y)
					Workshop._stand(n, false)
					tp.leg = 1
					if str(tp.kind) == "soak":
						_hood(n, true)
			1:
				var k := str(tp.kind)
				if not sitting.has(k):
					sitting[k] = []
				(sitting[k] as Array).append(n)
			2:
				var home: Transform3D = n.get_meta("home", tp.from)
				if Sharing._move(n, tp.from, home, float(tp.t), speed, delta):
					n.transform = home
					n.set_meta("base_yaw", n.rotation.y)
					Workshop._stand(n, false)
					_release(n)
					gone.erase(n)
	root.set_meta("tp_folk", gone)
	# Steam off the soak.
	for c in root.get_children():
		if c.name == "Soak" and c.has_meta("steam"):
			var pool := c as Node3D
			var steam: Node3D = pool.get_meta("steam")
			Smoke.update(steam, pool.global_position, pool.global_basis.y.normalized(), "embers", Vector3.ZERO, 0.0, 0.0, false, 1.0)
			# Steam, not smoke: low off the whole pool, white and thin.
			var sm: ShaderMaterial = steam.get_meta("mat")
			sm.set_shader_parameter("top_m", STEAM.x)
			sm.set_shader_parameter("width_m", STEAM.y)
			sm.set_shader_parameter("density", STEAM.z)
	# Their idles: one set; the line at the water rock for those who fish.
	var idles: Array = T.get("idles", ["sit", "lean_back", "look_out", "pipe"])
	for k in sitting:
		var group: Array = sitting[k]
		var only := idles.duplicate()
		if k == "water_rock":
			var fish := false
			for n in group:
				var tp: Dictionary = (n as Node3D).get_meta("tp")
				var seat: Dictionary = ((places[int(tp.place)] as Dictionary).seats as Array)[int(tp.seat)]
				fish = fish or bool(seat.get("fish", false))
			if fish:
				only = ["fish_line", "fish_line", "look_out"]
		FireCircle.animate(group, fire, time, delta, pp, "day", {"only": only, "fire_low": false, "food_ok": false})
	for hv in holders:
		if is_instance_valid(hv) and not gone.has(hv):
			at_fire.append(hv)
	return at_fire


## Let a folk go from its third place (its hood up again).
static func _release(n: Node3D) -> void:
	_hood(n, false)
	n.remove_meta("tp")
	FireCircle._props(n, "")
	n.set_meta("idle", "")


## The hood down (the soak, the one time) or up again: the hood hidden and
## the rig's plain head shown, a fold of the hood at the nape.
static func _hood(n: Node3D, down: bool) -> void:
	var head = n.get_meta("head") if n.has_meta("head") else null
	if head == null or not is_instance_valid(head):
		return
	var hood := (head as Node3D).get_node_or_null("Hood") as Node3D
	if hood != null:
		hood.visible = not down
	var plain := (head as Node3D).get_node_or_null("PlainHead") as Node3D
	if down and plain == null:
		plain = Node3D.new()
		plain.name = "PlainHead"
		(head as Node3D).add_child(plain)
		CreatureBodies.ball(plain, Vector3(0.095, 0.115, 0.1), Vector3(0, 0.1, 0), Color(0.55, 0.4, 0.3))
		var fold_col := Color(0.4, 0.3, 0.25)
		if hood != null and hood is MeshInstance3D:
			var m = (hood as MeshInstance3D).material_override
			if m is StandardMaterial3D:
				fold_col = (m as StandardMaterial3D).albedo_color
		CreatureBodies.box(plain, Vector3(0.2, 0.07, 0.1), Vector3(0, 0.0, 0.08), fold_col)
	if plain != null:
		plain.visible = down
	n.set_meta("hood_down", down)
