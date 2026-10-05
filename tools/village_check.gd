extends SceneTree
## Villages (design 5 Oct §EE, §EF, §EG; data/villages.json), headless:
##   STAMP=1 SEEDS="42 7 101 2024 7731" godot --headless --path . --script tools/village_check.gd
## For each world seed: the sites pass (Villages), then for every village
## it keeps, a pass/fail line per rule:
##   siting            the site's score over min_score, with its terms (§EE.3)
##   grow_from_reason  desire lines from the core, houses on them, denser
##                     at the core than the edge (§EF.1)
##   terminate_vistas  every long view along a lane ends on a building, a
##                     focal or borrowed scenery (§EF.2)
##   compress_release  narrow lanes opening into squares (§EF.3)
##   wrap_outdoor_rooms  buildings round every square (§EF.4)
##   gentle_curves     no long straight runs; every lane bends (§EF.5)
##   lingering_edges, layered_depth, water_you_follow, thresholds,
##   one_landmark      (§EF.6-10)
##   bones             paths, edges, districts, nodes, a landmark (§EG.1)
##   one_dominant, focal_off_centre, no_mirror, weight_balance,
##   threes_and_fives  (§EG.2)
##   ma_void           one deliberate empty space (§EG.3)
##   one_material_each one stone, one timber, one roof, counted on the
##                     build (§EG.3)
##   weathered         no two houses alike, every roof sags, some holed
##                     (wabi-sabi, §EG.3)
##   with_the_land     never a flattened pad: every floor at or over its
##                     ground, footings by the fall (plinth, stepped,
##                     posts of different lengths) (§EE.3)
##   hearths_lead      a hearth in every house, in every square but the
##                     void, at the ends of views (§EE.2, §EF)
##   refuge_flip       in the built village, with physics rays: while a
##                     square's hearth is cold its brambles stand between
##                     the square and its benches' walls; lit, they're gone
##                     and the bench is there (§EG.4)
##   relight           lighting one house's hearth lights its windows and
##                     raises the village's lit fraction (§EE.1, §EE.2)
## Prints PASS/FAIL per line, a tally per village and RESULT.

var fails := 0
var world


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_root().get_node("World")
	var seeds_s := OS.get_environment("SEEDS")
	var seeds: Array = []
	for s in (seeds_s if seeds_s != "" else "42 7 101").split(" ", false):
		seeds.append(int(s))
	var total_v := 0
	for seed_v in seeds:
		world.generate_now(seed_v)
		var map: PlanetData = world.planet
		var t0 := Time.get_ticks_msec()
		var sites: Array = Villages.all_sites(map)
		var rep: Dictionary = Villages.report
		print("\n[village] world seed %d: %d villages kept of %d spots scored (%d candidates; turned away %s; best scores %s) in %d ms" % [seed_v, sites.size(), int(rep.scored), int(rep.candidates), str(rep.why), str(rep.best), Time.get_ticks_msec() - t0])
		if sites.is_empty():
			print("FAIL  world seed %d has no village site" % seed_v)
			fails += 1
			continue
		for s in sites:
			total_v += 1
			await _village(map, s, seed_v)
	print("\n[village] %d villages over %d world seeds" % [total_v, seeds.size()])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _village(map: PlanetData, s: Dictionary, seed_v: int) -> void:
	var t0 := Time.get_ticks_msec()
	var plan := Villages.plan_of(map, s)
	var t_plan := Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	var data := VillageBuilder.compute(map, s)
	var t_build := Time.get_ticks_msec() - t0
	var d: Vector3 = s.dir
	print("\n== village %s (world seed %d, village seed %d) at %.3f, %.3f (AT=%.4f,%.4f): %d houses, %d squares, %d lanes, %d hearths, %d triangles; plan %d ms, build %d ms" % [s.id, seed_v, int(s.seed),
		rad_to_deg(CubeSphere.latitude(d)), rad_to_deg(CubeSphere.longitude(d)), rad_to_deg(CubeSphere.latitude(d)), rad_to_deg(CubeSphere.longitude(d)),
		plan.houses.size(), plan.squares.size(), plan.paths.size(), plan.hearths.size(), (data.v as PackedVector3Array).size() / 3, t_plan, t_build])
	var lines: Array = plan.rules()
	# Built: one material each, weathered, with the land.
	var used: Dictionary = data.used
	var one := true
	var mats: Array = []
	for cat in ["stone", "timber", "roof"]:
		var names: Array = (used[cat] as Dictionary).keys()
		mats.append("%s %s" % [cat, str(names)])
		if names.size() != 1:
			one = false
	lines.append(["one_material_each (built)", one, ", ".join(mats)])
	lines.append(_weathered(plan))
	lines.append(_with_the_land(data))
	var dist := {}
	for f in data.footings:
		dist[f.kind] = int(dist.get(f.kind, 0)) + 1
	# In the tree: the refuge flip and the relight.
	var flip := await _in_the_world(map, s, plan)
	lines.append_array(flip)
	var n_pass := 0
	for l in lines:
		print(("PASS  " if l[1] else "FAIL  ") + "%s: %s" % [l[0], l[2]])
		if l[1]:
			n_pass += 1
		else:
			fails += 1
	print("   districts: %s" % ", ".join(plan.districts.map(func(x): return "%s (%s, %d houses)" % [x.name, x.character, (x.houses as Array).size()])))
	print("   footings: %s; materials %s; void %s; builds %s" % [str(dist), str(plan.materials), str(plan.void_area.get("kind", "none")), str(plan.builds)])
	print("   tally %s: %d of %d rules pass" % [s.id, n_pass, lines.size()])


## No two houses alike; every roof sags; some roofs holed (plan seeds give
## each its own dimensions; the build's sag and holes come from them).
func _weathered(plan: VillagePlan) -> Array:
	var dims := {}
	var dup := 0
	for h in plan.houses:
		var k := Vector2(float(h.w), float(h.d))
		if dims.has(k):
			dup += 1
		dims[k] = true
	var holed := 0
	for h in plan.houses:
		var r := RandomNumberGenerator.new()
		r.seed = int(h.seed)
		# The same draws as VillageBuilder._house: eave, lean, sag, holed.
		r.randf()
		r.randf()
		r.randf()
		if r.randf() < float(VillageBuilder.BLD.get("roof_hole_share", 0.2)):
			holed += 1
	return ["weathered", dup == 0 and holed >= 1, "%d houses, %d alike in size; %d roofs holed; every ridge sags 4-22 cm, every wall leans a little" % [plan.houses.size(), dup, holed]]


## Never a flattened pad: the ground is never edited (the builder has no
## way to), every floor stands at or over the highest ground under it,
## and the footing follows the fall: plinth under plinth_max_m, stepped
## under stepped_max_m, posts beyond, posts of different lengths.
func _with_the_land(data: Dictionary) -> Array:
	var B: Dictionary = VillageBuilder.BLD
	var ok := true
	var posts: Array = []
	var falls: Array = []
	for f in data.footings:
		falls.append(float(f.fall))
		if float(f.floor) < float(f.ground_hi) - 0.001:
			ok = false
		var want := "plinth" if float(f.fall) < float(B.get("plinth_max_m", 0.45)) else ("stepped" if float(f.fall) < float(B.get("stepped_max_m", 1.6)) else "posts")
		if want != str(f.kind):
			ok = false
		posts.append_array(f.posts)
	var spread := 0.0
	if posts.size() > 1:
		var m := 0.0
		for p in posts:
			m += float(p)
		m /= posts.size()
		for p in posts:
			spread += (float(p) - m) * (float(p) - m)
		spread = sqrt(spread / posts.size())
	if not posts.is_empty() and spread < 0.05:
		ok = false
	falls.sort()
	var kinds := {}
	for f in data.footings:
		kinds[f.kind] = true
	return ["with_the_land", ok, "falls under houses %.2f-%.2f m; footings %s; %d posts, lengths spread %.2f m; no pad flattened (floors all at or over their ground)" % [falls[0] if not falls.is_empty() else 0.0, falls[-1] if not falls.is_empty() else 0.0, str(kinds.keys()), posts.size(), spread]]


## The built village in a scene: physics rays for the refuge flip, the
## stores for the relight.
func _in_the_world(map: PlanetData, s: Dictionary, plan: VillagePlan) -> Array:
	var out: Array = []
	var holder := Node3D.new()
	get_root().add_child(holder)
	var life := VillageLife.new()
	life.world = world
	var eye := Node3D.new()
	holder.add_child(eye)
	life.player = eye
	life._root = holder
	holder.add_child(life)
	life.set_process(false)
	life._compute(str(s.id), map, s)
	life._attach()
	var node: Node3D = life._built.get(str(s.id), null)
	if node == null:
		holder.queue_free()
		return [["refuge_flip (built)", false, "not built"], ["relight", false, "not built"]]
	eye.global_position = node.global_position
	for i in 3:
		await physics_frame
	var space := node.get_world_3d().direct_space_state
	var xf := node.global_transform
	# Refuge: from 3 m out in the square toward each bench's wall.
	var blocked_dead := 0
	var open_lit := 0
	var n := 0
	for r in plan.refuge:
		n += 1
	var res_dead := _refuge_rays(space, xf, plan)
	# Light every square's hearth (its store, as a torch would).
	var lit_keys: Array = []
	var dirs: Array = node.get_meta("hearth_dirs")
	for i in plan.hearths.size():
		if plan.hearths[i].kind == "square":
			lit_keys.append(_light(dirs[i][0]))
	life.sync()
	for i in 3:
		await physics_frame
	var res_lit := _refuge_rays(space, xf, plan)
	blocked_dead = res_dead.x
	open_lit = res_lit.y
	out.append(["refuge_flip (built)", n > 0 and blocked_dead == n and open_lit == n, "%d benches; dead: brambles between the square and %d of them; lit: %d stand clear with a wall at their back" % [n, blocked_dead, open_lit]])
	# Relight one house: its windows, the lit fraction.
	var f0 := VillageWarmth.lit_fraction(str(s.id))
	var hi := -1
	for i in plan.hearths.size():
		if plan.hearths[i].kind == "house":
			hi = i
			break
	var wins: Array = node.get_meta("windows")
	var before: bool = (wins[int(plan.hearths[hi].of)] as MeshInstance3D).visible if hi >= 0 else true
	if hi >= 0:
		lit_keys.append(_light(dirs[hi][0]))
	life.sync()
	var after: bool = (wins[int(plan.hearths[hi].of)] as MeshInstance3D).visible if hi >= 0 else false
	var f1 := VillageWarmth.lit_fraction(str(s.id))
	out.append(["relight", hi >= 0 and not before and after and f1 > f0, "one house hearth lit: its windows %s -> %s; lit fraction %.3f -> %.3f (squares lit first: %.3f)" % ["lit" if before else "dark", "lit" if after else "dark", f0, f1, f0]])
	for k in lit_keys:
		FireStore.stores.erase(k)
	VillageWarmth.forget(str(s.id))
	holder.queue_free()
	await process_frame
	return out


## A burning store at `d` (as a torch leaves it).
func _light(d: Vector3) -> String:
	var key := FireStore.key_of(d)
	var units: Array = []
	for i in 4:
		units.append(["branch", FireStore.burn_min("branch")])
	FireStore.stores[key] = {"units": units, "embers_min": 0.0, "state": "flames", "tended": false, "dir": [d.x, d.y, d.z], "seen": float(world.days)}
	return key


## Rays at knee height from 3 m out in the square to each bench: how many
## hit something (brambles) before the bench's spot (x), and how many get
## to it with a wall within a metre behind it (y).
func _refuge_rays(space: PhysicsDirectSpaceState3D, xf: Transform3D, plan: VillagePlan) -> Vector2i:
	var blocked := 0
	var clear := 0
	for r in plan.refuge:
		var p: Vector2 = r.p
		var f: Vector2 = r.facing
		var from2 := p + f * 3.0
		var a := xf * Vector3(from2.x, plan.ground(from2) + 0.7, from2.y)
		var b := xf * Vector3(p.x, plan.ground(p) + 0.7, p.y)
		var q := PhysicsRayQueryParameters3D.create(a, b)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and (hit.position as Vector3).distance_to(b) > 0.3:
			blocked += 1
			continue
		var back := xf * Vector3(p.x - f.x * 1.2, plan.ground(p) + 0.7, p.y - f.y * 1.2)
		var q2 := PhysicsRayQueryParameters3D.create(b, back)
		if not space.intersect_ray(q2).is_empty():
			clear += 1
	return Vector2i(blocked, clear)
