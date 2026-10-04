class_name OxRider
extends Node
## The old man on his ox: the first road regular (design 3 Oct §DQ,
## uniques.json road_regulars.ox_rider; §DM.7's cast, its first entry).
## One per world: a §BF traveller in every rule (mute, never stops for
## you, the hood turns and holds a beat, the dark ignores him: Dread hunts
## only you), who rides, and keeps to the mountains.
##
## His road: one great range (§CR.4, seeded), its highest pass that a road
## will cross (the highest dip in the crest that routes both ways under
## §DM.1's grade cap), a road from the range's east foot up to the pass
## and down to its west foot, westward. It is a road of its own, routed
## by the network's A* and put on the network (RoadNetwork.own_road,
## publish), so its tread shows like any road's.
##
## He moves as a number (a pure function of the clock, like the wandering
## fire): by day (ride_hours, local) he rides at the ox's pace, under the
## walk; at dusk he stops where he is, the ox grazes, no fire; at dawn he
## rides on. A crossing takes whole days, ending at a dusk at the west
## foot; the next dawn he is on the east foot again: on a planet you can
## walk around he never arrives, always on his way out (the wrap happens
## overnight, out of sight of the road's two ends' 4-7 km apart).
##
## The gate (first guess, §DQ.3; `GATE` off strikes it): a gatehouse
## astride the road at the pass, the keeper's camp beside it (Camps builds
## it like any: its hearth, one or two folk), and the second tome lying at
## the keeper's door once its text is in (tomes.json tao, found_at
## pass_gate; Tomes.ready).

const GATE := true
const BUILD_M := 350.0
const DROP_M := 450.0
const NEAR_M := 25.0
const GATE_BUILD_M := 320.0
const FOOT_M := Vector2(1600.0, 3500.0)
const CREST_SAMPLES := 180
const PASS_RELIEF_M := 8.0
const PASSES_TRIED := 80
const GATE_KEY := "gate:ox"

static var E: Dictionary = _load()
static var _mutex := Mutex.new()
static var _plan := {}
static var _plan_seed := -1
static var _road := {}
static var _road_seed := -1
static var _routing := -1
static var instance: OxRider = null
## Tools: {"passes": n, "tried": [[elev, ok]...], "s": seconds}.
static var report := {}

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var _root: Node3D
var _task := -1
var _rider: Node3D = null
var _ox: Dictionary = {}
var _fig: PlayerBody = null
var _anim := 0.0
var _hold := 0.0
var _seen := false
var _gate: Node3D = null
var _tome: WorldItem = null
var _ox_sp: CreatureSpecies = null


static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/uniques.json"))
	return (parsed.get("road_regulars", {}) as Dictionary).get("ox_rider", {}) if parsed is Dictionary else {}


static func speed_mps() -> float:
	return float((E.get("mount", {}) as Dictionary).get("speed_mps", 0.9))


static func ride_hours() -> Vector2:
	var h: Array = E.get("ride_hours", [7.0, 17.5])
	return Vector2(float(h[0]), float(h[1]))


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	instance = self
	_root = Node3D.new()
	_root.name = "OxRider"
	world.world_root.add_child(_root)
	# His road, routed once on a worker (a few seconds of A* in the
	# mountains), long before you could reach it.
	var map: PlanetData = world.planet
	var rivers: RiverNetwork = chunks.rivers
	var net: RoadNetwork = chunks.roads
	_task = WorkerThreadPool.add_task(func() -> void: road(map, rivers, net))
	_ox_sp = ox_species()
	SculptedBodies.ready(_ox_sp)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if instance == self:
		instance = null


## The ox's body: a creature species of its own (§0: beasts keep creature
## bodies), never in the wild (it is not in creatures.json).
static func ox_species() -> CreatureSpecies:
	var m: Dictionary = E.get("mount", {})
	var sp := CreatureSpecies.new()
	sp.name = "Ox"
	sp.body = "ox"
	sp.role = "ground"
	sp.size_m = float(m.get("length_m", 2.4))
	sp.color = Color(str(m.get("colour", "#2A2220")))
	sp.speed_mps = speed_mps()
	return sp


# --- His road (pure, once per world) -------------------------------------------------

## The great ranges' crossings, the seeded range first (then the others,
## should none of its crossings route): {"ranges": [_range_plan()...]};
## {} on a world with no great range (the dev stamp).
static func plan(map: PlanetData) -> Dictionary:
	_mutex.lock()
	var sd := int(map.terrain.world_seed)
	if _plan_seed != sd:
		_plan = _make_plan(map)
		_plan_seed = sd
	var out := _plan
	_mutex.unlock()
	return out


static func _make_plan(map: PlanetData) -> Dictionary:
	var ranges: Array = map.terrain.great_ranges
	if ranges.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map.terrain.world_seed, "ox_rider"])
	var first := rng.randi() % ranges.size()
	var out: Array = []
	for k in ranges.size():
		out.append(_range_plan(map, (first + k) % ranges.size()))
	return {"ranges": out}


## One range's crossings: {"range", "passes": [[elev, dir, dip?]...],
## "side" (the unit tangent across it)}.
static func _range_plan(map: PlanetData, gi: int) -> Dictionary:
	var g: Dictionary = map.terrain.great_ranges[gi]
	var c: Vector3 = g.center
	var axis: Vector3 = g.axis
	var hl := float(g.half_len_m)
	var es := PackedFloat32Array()
	var ps := PackedVector3Array()
	for i in CREST_SAMPLES:
		var t := lerpf(-0.99, 0.99, float(i) / float(CREST_SAMPLES - 1))
		var p := (c + axis * t * hl / PlanetConst.GEO_RADIUS_M).normalized()
		ps.append(p)
		es.append(map.terrain.elevation(p, false))
	# The crossings, highest first: the dips in the crest (the lowest
	# within two samples either way, the crest rising PASS_RELIEF_M above
	# it on both sides) and, after them, every fifth crest point (a great
	# range's crest is mostly too sheer for a road, §DM.1's cap: road()
	# takes the highest that routes both ways).
	var passes: Array = []
	var dips := {}
	for i in range(2, CREST_SAMPLES - 2):
		var low := true
		for j in range(i - 2, i + 3):
			if es[j] < es[i]:
				low = false
				break
		if not low:
			continue
		var lmax := 0.0
		var rmax := 0.0
		for j in i:
			lmax = maxf(lmax, es[j])
		for j in range(i + 1, CREST_SAMPLES):
			rmax = maxf(rmax, es[j])
		if minf(lmax, rmax) - es[i] >= PASS_RELIEF_M and es[i] > PlanetConst.SEA_LEVEL_M + 40.0:
			passes.append([float(es[i]), ps[i], true])
			dips[i] = true
	var rest: Array = []
	for i in range(0, CREST_SAMPLES, 5):
		if not dips.has(i) and es[i] > PlanetConst.SEA_LEVEL_M + 15.0:
			rest.append([float(es[i]), ps[i], false])
	passes.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	rest.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	passes.append_array(rest)
	return {"range": gi, "passes": passes, "side": g.side}


## His road: {"pass", "east", "west" (dirs), "legs": [up, down] (links),
## "len": [m, m], "total", "range", "pass_m" (the pass's elevation),
## "phase" (the day of a crossing the world starts on)}, routed (blocking)
## and, with `net`, put on the network. {} with no range or no pass that
## routes.
static func road(map: PlanetData, rivers: RiverNetwork, net: RoadNetwork = null) -> Dictionary:
	var sd := int(map.terrain.world_seed)
	# Routed once: a second caller waits for the first.
	while true:
		_mutex.lock()
		if _road_seed == sd:
			var have := _road
			_mutex.unlock()
			return have
		if _routing != sd:
			_routing = sd
			_mutex.unlock()
			break
		_mutex.unlock()
		OS.delay_msec(20)
	var t0 := Time.get_ticks_msec()
	var pls: Array = plan(map).get("ranges", [])
	var out := {}
	var tried: Array = []
	var n_pass := 0
	for pl in pls:
		n_pass += (pl.passes as Array).size()
		for k in mini((pl.passes as Array).size(), PASSES_TRIED):
			var pe := float(pl.passes[k][0])
			var pd: Vector3 = pl.passes[k][1]
			var side: Vector3 = pl.side
			var west_t := -CubeSphere.east(pd)
			var sgn := 1.0 if side.dot(west_t) >= 0.0 else -1.0
			var half_w := pe / tan(deg_to_rad(TerrainField.FLANK_DEG))
			var foot := clampf(half_w * 1.15 + 600.0, FOOT_M.x, FOOT_M.y)
			var ends: Array = []
			for s in [-sgn, sgn]:
				var f := foot
				var d: Vector3 = (pd + side * s * f / PlanetConst.RADIUS_M).normalized()
				while f > 800.0 and (map.water[map.cell_at(d)] != PlanetData.Water.NONE or map.terrain.elevation(d, true) < 2.0):
					f -= 200.0
					d = (pd + side * s * f / PlanetConst.RADIUS_M).normalized()
				ends.append(d)
			var key := "ox:%d:%d" % [int(pl.range), k]
			var up := RoadNetwork.own_road(map, rivers, ends[0], pd, key + ":up")
			var down := {} if up.is_empty() else RoadNetwork.own_road(map, rivers, pd, ends[1], key + ":down")
			tried.append([int(pl.range), snappedf(pe, 1.0), not up.is_empty() and not down.is_empty(), bool(pl.passes[k][2])])
			if up.is_empty() or down.is_empty():
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([sd, "ox_phase"])
			out = {"pass": pd, "east": ends[0], "west": ends[1], "legs": [up, down], "len": [float(up.len_m), float(down.len_m)],
				"total": float(up.len_m) + float(down.len_m), "range": int(pl.range), "pass_m": pe, "dip": bool(pl.passes[k][2]), "phase": rng.randi()}
			if net != null:
				net.publish(up)
				net.publish(down)
			break
		if not out.is_empty():
			break
	_mutex.lock()
	_road = out
	_road_seed = sd
	report = {"passes": n_pass, "tried": tried, "s": (Time.get_ticks_msec() - t0) / 1000.0}
	_mutex.unlock()
	return out


## His road if it's routed yet ({} until then).
static func road_now(map: PlanetData) -> Dictionary:
	_mutex.lock()
	var out := _road if _road_seed == int(map.terrain.world_seed) else {}
	_mutex.unlock()
	return out


## The point `m` metres along his road from the east foot.
static func point(r: Dictionary, m: float) -> Vector3:
	var l1 := float(r.len[0])
	if m <= l1:
		return RoadNetwork.point_at(r.legs[0].pts, maxf(m, 0.0))
	return RoadNetwork.point_at(r.legs[1].pts, minf(m - l1, float(r.len[1])))


## World days at local solar hour `h` of local day `day` at (lon, lat).
static func _at(day: int, h: float, lon: float, lat: float) -> float:
	var base := float(day) - lon / TAU
	return base + DayCycle.unwarp(h / 24.0, lat, Astro.declination(base + 0.5))


## Where he is at `days`: {"state" ("ride" or "stop"), "m" (metres from
## the east foot), "dir", "ahead" (a point 3 m on), "crossing", "day"
## (of the crossing), "days_per_crossing", "mps" (his pace)}; {} until
## his road is routed.
static func where(world_node: Node, days: float) -> Dictionary:
	var map: PlanetData = world_node.planet
	var r := road_now(map)
	if r.is_empty():
		return {}
	var pd: Vector3 = r.pass
	var lon := CubeSphere.longitude(pd)
	var lat := CubeSphere.latitude(pd)
	var lc := Astro.local_clock(days, lon, lat)
	var day := int(lc.x)
	var day0 := int(floorf(float(world_node.START_DAYS) + lon / TAU))
	var hrs := ride_hours()
	var t_from := _at(day, hrs.x, lon, lat)
	var t_to := _at(day, hrs.y, lon, lat)
	var ride_s := (t_to - t_from) * float(world_node.day_length_s)
	var total := float(r.total)
	var per_day := speed_mps() * ride_s
	var p := maxi(1, ceili(total / maxf(per_day, 1.0)))
	var k := maxi(day - day0, 0) + int(r.phase) % p
	var j := k % p
	var frac := 0.0 if day < day0 else clampf((days - t_from) / maxf(t_to - t_from, 1e-6), 0.0, 1.0)
	var m := (float(j) + frac) * total / float(p)
	return {"state": "ride" if frac > 0.0 and frac < 1.0 else "stop", "m": m, "dir": point(r, m), "ahead": point(r, minf(m + 3.0, total)),
		"behind": point(r, maxf(m - 3.0, 0.0)), "crossing": k / p, "day": j, "days_per_crossing": p, "mps": total / float(p) / maxf(ride_s, 1.0)}


## The gate's place (§DQ.3): {"dir" (the pass, on the road), "fwd" (the
## road's way west there), "hearth" (the keeper's fire, beside the road),
## "door" (the keeper's hut's door), "seed"}; {} without his road.
static func gate_site(map: PlanetData) -> Dictionary:
	if not GATE:
		return {}
	var r := road_now(map)
	if r.is_empty():
		return {}
	var pd: Vector3 = r.pass
	var l1 := float(r.len[0])
	var fwd := point(r, l1 + 6.0) - point(r, l1 - 6.0)
	fwd = (fwd - pd * fwd.dot(pd)).normalized()
	var right := fwd.cross(pd).normalized()
	# The keeper's side: the flatter of the two.
	var e0 := map.terrain.elevation(pd, true)
	var side := 1.0
	var best := INF
	for s in [1.0, -1.0]:
		var q: Vector3 = (pd + right * s * 12.0 / PlanetConst.RADIUS_M).normalized()
		var dz := absf(map.terrain.elevation(q, true) - e0)
		if dz < best:
			best = dz
			side = s
	var hearth := (pd + (right * side * 11.0 + fwd * 4.0) / PlanetConst.RADIUS_M).normalized()
	var door := (pd + (right * side * 17.0 + fwd * 4.0) / PlanetConst.RADIUS_M).normalized()
	return {"dir": pd, "fwd": fwd, "right": right * side, "hearth": hearth, "door": door, "seed": hash([map.terrain.world_seed, "gate"])}


## The gate's camp for Camps (a hearth like any, one or two folk): [] or
## [{"key", "hearth", "seed"}] within `radius` of `d`.
static func camps_near(map: PlanetData, d: Vector3, radius: float) -> Array:
	var g := gate_site(map)
	if g.is_empty() or CubeSphere.surface_distance_m(g.hearth, d) > radius:
		return []
	return [{"key": GATE_KEY, "hearth": g.hearth, "seed": int(g.seed)}]


# --- In play -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if world == null or player == null or world.planet == null:
		return
	var map: PlanetData = world.planet
	var w := where(world, world.days)
	if w.is_empty():
		return
	var pd: Vector3 = player.surface_dir
	var dist := CubeSphere.surface_distance_m(w.dir, pd)
	if _rider == null and dist < BUILD_M:
		_build_rider()
	elif _rider != null and dist > DROP_M:
		NodeRelease.free_later(_rider)
		_rider = null
		_fig = null
		_ox = {}
	if _rider != null:
		_place(w, delta)
		if _rider.global_position.distance_to(player.global_position) < NEAR_M:
			GameLog.add_once("ox_rider", str(E.get("log", "An old man rides an ox up the pass road, slowly.")), "found")
	_update_gate(map, pd)


func rider_node() -> Node3D:
	return _rider


func figure() -> PlayerBody:
	return _fig


func ox_parts() -> Dictionary:
	return _ox


func gate_node() -> Node3D:
	return _gate


func tome_node() -> WorldItem:
	return _tome if _tome != null and is_instance_valid(_tome) else null


func _ground(d: Vector3) -> Vector3:
	return world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))


func _build_rider() -> void:
	SculptedBodies.wait_ready(_ox_sp)
	_rider = Node3D.new()
	_rider.name = "OldManOnHisOx"
	_root.add_child(_rider)
	_ox = CreatureBodies.build(_ox_sp)
	var ox_root: Node3D = _ox.root
	ox_root.name = "Ox"
	_rider.add_child(ox_root)
	if not _ox.has("sculpted"):
		ox_root.scale = Vector3.ONE * _ox_sp.size_m
	BlobShadow.make(_rider, 0.7, 2.2)
	var robe: Dictionary = E.get("robe", {})
	var cb := CloakedFigure.build(1.66, Color(str(robe.get("colour", "#34302E"))), Color(str(robe.get("edge", "#262220"))))
	_fig = cb.root
	_fig.name = "OldMan"
	_fig.pose = "ride"
	_rider.add_child(_fig)
	# On the ox's back: his hips on its withers' line, a little behind
	# them (the ox's back stands ~0.64 of its length).
	var k := _fig.scale.y
	_fig.position = Vector3(0.0, 0.645 * _ox_sp.size_m - PlayerBody.HIP_Y * k + 0.05, 0.02 * _ox_sp.size_m)


## The rider on the road at `w`: facing along it, the ox's legs at its
## steps (diagonal pairs) while he rides, its head down to graze when he
## stops; the hood tracks you as a traveller's does (travellers.json
## head_look) and the body never breaks stride.
func _place(w: Dictionary, delta: float) -> void:
	var d: Vector3 = w.dir
	var fwd: Vector3 = (w.ahead as Vector3) - (w.behind as Vector3)
	fwd = fwd - d * fwd.dot(d)
	if fwd.length() < 1e-9:
		fwd = CubeSphere.north(d)
	_rider.global_transform = Transform3D(Basis.looking_at(fwd.normalized(), d), _ground(d))
	var riding := str(w.state) == "ride"
	var mps := float(w.mps) if riding else 0.0
	_anim = wrapf(_anim + delta * mps / 0.9 * PI, 0.0, TAU * 4.0)
	var legs: Array = _ox.get("legs", [])
	for i in legs.size():
		var leg: Node3D = legs[i]
		var sgn := 1.0 if i == 0 or i == 3 else -1.0
		var target := sin(_anim) * 0.32 * sgn if riding else 0.0
		leg.rotation.x = lerpf(leg.rotation.x, target, clampf(delta * 8.0, 0.0, 1.0))
	var head: Node3D = (_ox.root as Node3D).get_node_or_null("Head")
	if head != null:
		var graze := -0.75 + 0.06 * sin(_anim * 0.15 + world.days * 900.0) if not riding else 0.04 * sin(_anim * 2.0)
		head.rotation.x = lerpf(head.rotation.x, graze, clampf(delta * 2.0, 0.0, 1.0))
	var tail: Node3D = _ox.get("tail")
	if tail != null:
		tail.rotation.z = 0.12 * sin(world.days * 2400.0)
	if _fig == null:
		return
	_fig.ride_sway = sin(_anim) if riding else 0.0
	_fig.set_motion(0.0, delta)
	var hl: Dictionary = Travellers.D.get("head_look", {})
	var to := player.global_position - _fig.global_position
	var dist := to.length()
	var local := _rider.global_basis.orthonormalized().inverse() * to.normalized()
	var yaw := atan2(-local.x, -local.z)
	var head_max := deg_to_rad(minf(float(hl.get("head_max_deg", 70.0)), float(PlayerBody.HEAD_LOOK.get("head_max_deg", 45.0))))
	if dist < float(hl.get("watch_m", 18.0)) and absf(yaw) < deg_to_rad(110.0):
		_hold = float(hl.get("hold_s", 1.5))
		_seen = true
	elif _seen:
		_hold -= delta
		if _hold <= 0.0:
			_seen = false
	if _seen:
		_fig.set_look(clampf(yaw, -head_max, head_max), clampf(asin(clampf(local.y, -1.0, 1.0)), -0.3, 0.3))
	else:
		_fig.set_look(0.0, 0.0)


## Is the hood turned toward you now (the tools)?
func watching() -> bool:
	return _seen


# --- The gate ------------------------------------------------------------------------

func _update_gate(map: PlanetData, pd: Vector3) -> void:
	var g := gate_site(map)
	if g.is_empty():
		return
	var dist := CubeSphere.surface_distance_m(g.dir, pd)
	if _gate == null and dist < GATE_BUILD_M:
		_gate = _build_gate(g)
	elif _gate != null and dist > GATE_BUILD_M + 120.0:
		NodeRelease.free_later(_gate)
		_gate = null
		if _tome != null and is_instance_valid(_tome):
			_tome.queue_free()
		_tome = null
	if _gate == null:
		return
	# The book he left (tomes.json tao, found_at pass_gate): only once its
	# text is in; once taken, gone (the keeper's camp remembers).
	var st: Dictionary = CampSim.instance.states.get(GATE_KEY, {}) if CampSim.instance != null else {}
	if _tome != null and not is_instance_valid(_tome):
		_tome = null
		if not st.is_empty():
			st.tome_taken = true
	if _tome == null and Tomes.ready("tao") and str(Tomes.entry("tao").get("found_at", "")) == "pass_gate" and not bool(st.get("tome_taken", false)):
		var door: Vector3 = g.door
		_tome = WorldItem.drop(Tomes.item("tao"), world, door, chunks.ground_height(door))


## The gatehouse: two stone towers astride the road with a lintel between
## them, and the keeper's hut beside it (its door toward the fire).
func _build_gate(g: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "PassGate"
	_root.add_child(n)
	var d: Vector3 = g.dir
	var fwd: Vector3 = g.fwd
	n.global_transform = Transform3D(Basis.looking_at(fwd, d), _ground(d))
	var body := StaticBody3D.new()
	n.add_child(body)
	var stone := Color(0.52, 0.5, 0.47)
	var right_l := n.global_basis.inverse() * ((g.right as Vector3).normalized())
	var rs := 1.0 if right_l.x >= 0.0 else -1.0
	# Towers 2.4 m square, 4.6 m tall, 2.2 m either side of the road's
	# middle; a lintel across at the top; a step of stone at each foot.
	for sx in [-1.0, 1.0]:
		var t := _block(n, Vector3(2.4, 4.6, 2.4), Vector3(sx * 3.4, 2.1, 0.0), stone)
		PropCollision.box(body, t.transform, Vector3(2.4, 4.6, 2.4))
		_block(n, Vector3(2.8, 0.4, 2.8), Vector3(sx * 3.4, 4.5, 0.0), stone.darkened(0.08))
	var lin := _block(n, Vector3(9.2, 0.7, 1.6), Vector3(0.0, 4.05, 0.0), stone.darkened(0.05))
	PropCollision.box(body, lin.transform, Vector3(9.2, 0.7, 1.6))
	# The keeper's hut: four walls of rough stone, a door toward the fire,
	# a slab roof.
	var hut := Node3D.new()
	hut.name = "KeepersHut"
	n.add_child(hut)
	hut.position = Vector3(rs * 19.5, 0.0, -4.0)
	hut.rotation.y = -rs * PI * 0.5
	var w := 4.2
	var dpt := 3.6
	var h := 2.4
	var hs := stone.darkened(0.12)
	_wall(hut, body, Vector3(0.0, h * 0.5, -dpt * 0.5), Vector3(w, h, 0.4), hs)
	_wall(hut, body, Vector3(-w * 0.5, h * 0.5, 0.0), Vector3(0.4, h, dpt), hs)
	_wall(hut, body, Vector3(w * 0.5, h * 0.5, 0.0), Vector3(0.4, h, dpt), hs)
	for sx in [-1.0, 1.0]:
		_wall(hut, body, Vector3(sx * (w * 0.5 - 0.8), h * 0.5, dpt * 0.5), Vector3(1.6, h, 0.4), hs)
	_wall(hut, body, Vector3(0.0, h + 0.15, 0.0), Vector3(w + 0.6, 0.3, dpt + 0.6), stone.darkened(0.2))
	return n


func _block(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = RuinBuilder.rock_mesh(size, hash([pos, size]), col, true)
	mi.material_override = RuinBuilder.material()
	mi.position = pos
	parent.add_child(mi)
	return mi


func _wall(parent: Node3D, body: StaticBody3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var b := _block(parent, size, pos, col)
	PropCollision.box(body, parent.transform * b.transform, size)
