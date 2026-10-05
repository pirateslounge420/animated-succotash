class_name CampNeeds
## What every camp does every day, made visible (design 5 Oct §EI.1,
## camps.json → sim.needs; CampSim._needs keeps the count):
##   - water: at the sim's trip hours a folk walks from the fire to the
##     camp's water (water_spot(): the nearest fresh water the planet has
##     within needs.water.reach_m, else within loop.gather_reach_m, else a
##     seep at the lowest ground near; never the sea) with a pot on the
##     head, pauses (sim.jobs.pause_at_source_s), walks back. After the
##     camp's first trip the water pot stands by the hearth
##     (store.pieces.water_pot_by_hearth) and stays. Water is never short:
##     no store number moves.
##   - shelter: every needs.shelter.mend_job_days (CampSim's st.patches) a
##     folk carries a bundle of the shelter's own material (the people
##     file's shelter.materials) to the shelter's front and a patch goes
##     on: one visible patch a mend, the newest six shown.
## A trip is drawn only while the player is within sim.jobs.near_player_m
## of the camp; out of sight the pot and the patch simply appear.

static var N: Dictionary = (Tuning.section("camps", "sim").get("needs", {}) as Dictionary)
const PATCHES_SHOWN := 6


## The camp's water from fire direction `d`: {dir, kind} (kind river,
## lake or seep), the dry bank a step short of the water.
static func water_spot(world: Node, chunks: ChunkManager, d: Vector3) -> Dictionary:
	var map: PlanetData = world.get("planet")
	var reach := float((N.get("water", {}) as Dictionary).get("reach_m", 120.0))
	var far := float((CampSim.SIM.get("loop", {}) as Dictionary).get("gather_reach_m", 300.0))
	var r := 8.0
	while r <= far + 0.1:
		for k in 24:
			var p := CreatureSpawner._offset(d, TAU * k / 24.0 + r * 0.01, r)
			if chunks.water_level_at(p) > chunks.ground_height(p) + 0.05 and int(map.water[map.cell_at(p)]) != PlanetData.Water.OCEAN:
				# Back to the dry bank.
				var bank := p
				var back := r
				while back > 2.0 and chunks.water_level_at(bank) > chunks.ground_height(bank) + 0.02:
					back -= 1.0
					bank = CreatureSpawner._offset(d, TAU * k / 24.0 + r * 0.01, back)
				var kind := "lake" if int(map.water[map.cell_at(p)]) == PlanetData.Water.LAKE else "river"
				return {"dir": bank, "kind": kind, "within_reach": r <= reach}
		r += 8.0
	# A seep: the lowest ground near.
	var best := d
	var best_h := INF
	for k in 16:
		for rr: float in [30.0, 55.0, 80.0]:
			var p2 := CreatureSpawner._offset(d, TAU * k / 16.0, rr)
			var h := chunks.ground_height(p2)
			if h < best_h:
				best_h = h
				best = p2
	return {"dir": best, "kind": "seep", "within_reach": true}


## The water pot by the hearth: a dark, wet clay pot on the ring `r_m`
## from the fire, at the clearest angle of `avoid`.
static func pot(parent: Node3D, avoid: Array, r_m := 2.95) -> Node3D:
	var best := Vector3(r_m, 0, 0)
	var best_c := -INF
	for k in 24:
		var a := TAU * k / 24.0
		var p := Vector3(cos(a), 0, sin(a)) * r_m
		var c := INF
		for av in avoid:
			c = minf(c, p.distance_to(av[0] as Vector3) - float(av[1]))
		if c > best_c:
			best_c = c
			best = p
	var n := Node3D.new()
	n.name = "WaterPot"
	parent.add_child(n)
	n.position = best
	var b := Workshop.Build.new()
	b.ybox(Vector3(0, 0.2, 0), Vector3(0.36, 0.4, 0.36), 0.4, Color(0.36, 0.24, 0.17), Workshop.STONE)
	b.ybox(Vector3(0, 0.43, 0), Vector3(0.26, 0.06, 0.26), 0.4, Color(0.3, 0.2, 0.15), Workshop.STONE)
	n.add_child(b.node("Pot"))
	n.set_meta("piece", "water_pot_by_hearth")
	return n


## A shelter's patch: a piece of `material` laid on its front (the side
## to the fire), seeded by `i`.
static func patch(shelter: Node3D, i: int, material: String, pal: Array) -> void:
	var box := AABB()
	var first := true
	for c in shelter.get_children():
		if c is MeshInstance3D:
			var a: AABB = (c as MeshInstance3D).transform * (c as MeshInstance3D).get_aabb()
			box = a if first else box.merge(a)
			first = false
	if first:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([str(shelter.get_path()), i, "patch"])
	var x := lerpf(box.position.x, box.end.x, rng.randf_range(0.3, 0.7))
	var y := lerpf(box.position.y, box.end.y, rng.randf_range(0.3, 0.7))
	var z := box.position.z - 0.03
	var b := Workshop.Build.new()
	b.ybox(Vector3(x, y, z), Vector3(rng.randf_range(0.4, 0.6), rng.randf_range(0.3, 0.45), 0.06), rng.randf_range(-0.2, 0.2), Workshop.colour_of(material, pal).lightened(0.08), Workshop.THATCH)
	var mi := b.node("Patch%d" % i)
	shelter.add_child(mi)


## One folk's trip: from `from` to `to` (parent frame), carrying `carry`
## (pot or bundle), pausing, back; `on_arrive` ("" or "patch") fires at
## the far end. Its body is a cloaked figure of the camp's palette.
static func start_trip(parent: Node3D, from: Vector3, to: Vector3, carry: String, pal: Array, height: float, on_arrive := "") -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([str(parent.get_path()), from, to])
	var c0: Color = pal[0] if not pal.is_empty() else Color(0.5, 0.35, 0.25)
	var c1: Color = pal[1 % maxi(pal.size(), 1)] if not pal.is_empty() else Color(0.8, 0.7, 0.5)
	var b := CloakedFigure.build(height, c0, c1)
	var holder := Node3D.new()
	holder.name = "Carrier"
	parent.add_child(holder)
	var body: Node3D = b.root
	body.name = "Body"
	holder.add_child(body)
	var load: Node3D
	if carry == "pot":
		# On the head, steadied by a hand.
		load = CreatureBodies.box(holder, Vector3(0.3, 0.32, 0.3), Vector3(0, height + 0.12, 0), Color(0.48, 0.32, 0.22))
	else:
		load = CreatureBodies.box(holder, Vector3(0.5, 0.25, 0.25), Vector3(0.2, height * 0.82, 0.05), Color(0.6, 0.5, 0.3))
	load.name = "Load"
	holder.position = from
	holder.set_meta("from", from)
	holder.set_meta("to", to)
	holder.set_meta("leg", 0)
	holder.set_meta("t", 0.0)
	holder.set_meta("on_arrive", on_arrive)
	return holder


## Advance every trip under `parent` one frame (`ground`: Callable local
## point -> local ground y). Returns the on_arrive events that fired.
static func tick_trips(parent: Node3D, delta: float, ground: Callable) -> Array:
	var fired: Array = []
	var jobs: Dictionary = CampSim.SIM.get("jobs", {})
	var speed := float(jobs.get("walk_mps", 1.3))
	var pause := float(jobs.get("pause_at_source_s", 4.0))
	for c in parent.get_children():
		if not str(c.name).begins_with("Carrier") or not c.has_meta("leg"):
			continue
		var h: Node3D = c
		var leg := int(h.get_meta("leg"))
		var t := float(h.get_meta("t")) + delta
		h.set_meta("t", t)
		var body := h.get_node_or_null("Body")
		if leg == 1:
			if t >= pause:
				h.set_meta("leg", 2)
				h.set_meta("t", 0.0)
			continue
		var a: Vector3 = h.get_meta("from") if leg == 0 else h.get_meta("to")
		var b: Vector3 = h.get_meta("to") if leg == 0 else h.get_meta("from")
		var flat := Vector3(b.x - a.x, 0, b.z - a.z)
		var k := clampf(t * speed / maxf(flat.length(), 0.1), 0.0, 1.0)
		var p := a.lerp(b, k)
		if ground.is_valid():
			p.y = float(ground.call(p))
		h.position = p
		if flat.length() > 0.01:
			h.basis = Basis.looking_at(flat.normalized(), Vector3.UP)
		if body != null and body is PlayerBody:
			(body as PlayerBody).set_velocity(parent.global_basis * flat.normalized() * speed)
			(body as PlayerBody).set_motion(0.35, delta)
		if k >= 1.0:
			if leg == 0:
				h.set_meta("leg", 1)
				h.set_meta("t", 0.0)
				if str(h.get_meta("on_arrive", "")) != "":
					fired.append(str(h.get_meta("on_arrive")))
					var ld := h.get_node_or_null("Load")
					if ld != null:
						ld.queue_free()
			else:
				h.queue_free()
	return fired


## The needs at a built camp, every refresh (~1.5 s): `node` keeps the
## metas (the camp root, the opening camp's dressing); ctx: d (the fire's
## direction), world, chunks, shelter (Node3D or null), ground (Callable),
## near (the player within near_player_m), pal, height, avoid ([pos, r]
## round the fire), material (the shelter's first material).
static func live(node: Node3D, st: Dictionary, ctx: Dictionary) -> void:
	if st.is_empty() or str(st.get("state", "living")) != "living":
		return
	var w: Dictionary = st.get("water", {})
	var total := int(w.get("total", 0))
	if total > 0 and not node.has_meta("water_pot"):
		node.set_meta("water_pot", pot(node, ctx.get("avoid", [])))
	var near := bool(ctx.get("near", false))
	var seen := int(node.get_meta("water_seen", -1))
	if seen < 0:
		node.set_meta("water_seen", total)
	elif total > seen:
		node.set_meta("water_seen", total)
		if near and node.get_node_or_null("Carrier") == null:
			if not node.has_meta("water_spot"):
				node.set_meta("water_spot", water_spot(ctx.world, ctx.chunks, ctx.d))
			var ws: Dictionary = node.get_meta("water_spot")
			var wl: Vector3 = node.to_local((ctx.world as Node).call("to_scene", ws.dir, PlanetConst.RADIUS_M + (ctx.chunks as ChunkManager).ground_height(ws.dir)))
			var potn = node.get_meta("water_pot") if node.has_meta("water_pot") else null
			var from: Vector3 = (potn as Node3D).position if potn != null else Vector3(2.5, 0, 0)
			start_trip(node, from, wl, "pot", ctx.get("pal", []), float(ctx.get("height", 1.7)))
	# The shelter's patches.
	var shelter: Node3D = ctx.get("shelter", null)
	if shelter == null or not is_instance_valid(shelter):
		return
	var patches := int(st.get("patches", 0))
	var shown := int(node.get_meta("patches_shown", -1))
	var mat := str(ctx.get("material", "thatch"))
	if shown < 0:
		for i in range(maxi(patches - PATCHES_SHOWN, 0), patches):
			patch(shelter, i, mat, ctx.get("pal", []))
		node.set_meta("patches_shown", patches)
	elif patches > shown:
		node.set_meta("patches_shown", patches)
		if near:
			var front: Vector3 = shelter.position + (Vector3.ZERO - shelter.position).normalized() * 2.2
			var om: Array = (CampSim.SIM.get("loop", {}) as Dictionary).get("walk_out_m", [15, 35])
			var out: Vector3 = shelter.position.normalized() * float(om[0])
			node.set_meta("patch_next", patches - 1)
			start_trip(node, out, front, "bundle", ctx.get("pal", []), float(ctx.get("height", 1.7)), "patch")
		else:
			patch(shelter, patches - 1, mat, ctx.get("pal", []))


## A frame of the needs at a built camp: the trips walk; a mend that
## arrives lays its patch.
static func tick(node: Node3D, delta: float, shelter: Node3D, ground: Callable, mat: String, pal: Array) -> void:
	for ev in tick_trips(node, delta, ground):
		if ev == "patch" and shelter != null and is_instance_valid(shelter):
			patch(shelter, int(node.get_meta("patch_next", 0)), mat, pal)
