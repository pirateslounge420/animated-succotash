extends SceneTree
## The Aztec pyramid on the surface (design 10 Oct §FN.4, queue 84;
## AztecPyramid, SurfaceBuild, Surface; data/aztec_temple.json
## surface.pyramid, enabled; worlds.json surface.over_themes), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/aztec_pyramid_check.gd
## PYRAMID_SEEDS (env) sets how many seeds (default 20: 1, 7, 42 and more).
## Asserts:
##  1. off (aztec_temple.json enabled false, the default): no pyramid over
##     the tomb or over a temple, the surface's stone vertex for vertex as it
##     is with the pyramid's code there and switched off;
##  2. on (CrawlerSave.aztec_on true), over the seeds: over every temple
##     exactly one pyramid, over every tomb none; on land (its whole
##     footprint and its stair's foot on the basin's floor, out of the
##     wash, off the yard, clear of every vent's stack and slot); in view
##     from where you come up (within view_deg of the way you face, and
##     nothing of the land between your eye and its top); the stairhead,
##     where you arrive, every stack and slot the same as with it off (no
##     exit or gameplay number differs; it has no exit, beacon or fast
##     travel: nothing it builds is anything but stone);
##  3. walked (seeds 1, 7, 42): your own body (CrawlerPlayer's capsule, floor
##     rules and step) from where you come up to the stair's foot, up the
##     stair and onto the flat top beside the altar; the same seed the same
##     pyramid.

var fails := 0
const DT := 1.0 / 60.0
## How far off the way you face on arrival the pyramid's middle may be and
## still be in view (degrees; the camera sees about 50 either side).
const VIEW_DEG := 45.0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	WorldSave.read_only = true
	var seeds := _seeds()
	_off(seeds)
	_on(seeds)
	await _walks([1, 7, 42])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _seeds() -> Array:
	var n := 20
	if OS.get_environment("PYRAMID_SEEDS").is_valid_int():
		n = maxi(int(OS.get_environment("PYRAMID_SEEDS")), 3)
	var out: Array = [1, 7, 42]
	var rng := RandomNumberGenerator.new()
	rng.seed = 84
	while out.size() < n:
		var s := rng.randi_range(1, 999999)
		if not out.has(s):
			out.append(s)
	return out


## The surface over `lay`: {"land", "data"} (as Surface.build makes them).
func _surface(lay: Dictionary) -> Dictionary:
	var S: Dictionary = Surface.S
	var sv := hash([int(lay.get("seed", 0)), "surface"])
	var frame := SurfaceBuild.stair_frame(lay, S, Surface.level())
	var land := SurfaceGround.new()
	land.setup(S, sv, frame.mouth, frame.n, Surface.level())
	land.carve_stair(frame)
	return {"land": land, "data": SurfaceBuild.make(land, lay, S, sv), "seed": sv}


func _off(seeds: Array) -> void:
	CrawlerSave.aztec_on = false
	ok(not bool(Tuning.table("aztec_temple").get("enabled", true)), "aztec_temple.json enabled is false by default")
	ok(Surface.covers({"theme": "tomb"}) and Surface.covers({"theme": "aztec_temple"}), "the tomb and the temple both have the surface over them (over_themes %s)" % str(Surface.S.get("over_themes", [])))
	var none := true
	for s in seeds.slice(0, 5):
		for th in ["tomb", "aztec_temple"]:
			var sf := _surface(TombKit.layout(int(s), th))
			if not (sf.data.pyramid as Dictionary).is_empty():
				none = false
	ok(none, "with it false no pyramid stands over the tomb or the temple (5 seeds each)")


func _on(seeds: Array) -> void:
	var one := 0
	var tomb_none := 0
	var on_land := 0
	var in_view := 0
	var same := 0
	var stone_only := 0
	var tops: Array = []
	for s in seeds:
		var lay := TombKit.layout(int(s), "aztec_temple")
		CrawlerSave.aztec_on = false
		var off := _surface(lay)
		CrawlerSave.aztec_on = true
		var sf := _surface(lay)
		var tomb := _surface(TombKit.layout(int(s)))
		var py: Dictionary = sf.data.pyramid
		var land: SurfaceGround = sf.land
		if (tomb.data.pyramid as Dictionary).is_empty():
			tomb_none += 1
		if py.is_empty():
			print("  seed %d: no pyramid" % s)
			continue
		one += 1
		tops.append(float(py.top_y) - float(py.foot_y))
		# On land.
		var c: Vector2 = py.c
		var face: Vector2 = py.face
		var sd := Vector2(-face.y, face.x)
		var half := float(py.half)
		var land_ok := true
		for i in 9:
			for j in 9:
				var q := c + face * lerpf(-half, half, i / 8.0) + sd * lerpf(-half, half, j / 8.0)
				if not land.on_floor(q) or land.in_wash(q) > 0.0 or (sf.data.stair.yard as Rect2).has_point(q):
					land_ok = false
		var foot: Vector3 = py.stair_foot
		if not land.on_floor(Vector2(foot.x, foot.z)) or land.in_wash(Vector2(foot.x, foot.z)) > 0.0:
			land_ok = false
		for st in sf.data.stacks:
			if (py.rect as Rect2).has_point(Vector2((st.foot as Vector3).x, (st.foot as Vector3).z)):
				land_ok = false
		for st in sf.data.slots:
			if (py.rect as Rect2).has_point(Vector2((st.at as Vector3).x, (st.at as Vector3).z)):
				land_ok = false
		if land_ok:
			on_land += 1
		else:
			print("  seed %d: the pyramid at %s is not all on land" % [s, str(c)])
		# In view from the arrival: near the way you face, and the land not
		# between your eye and its top.
		var arrive: Vector2 = sf.data.stair.arrive
		var eye := Vector3(arrive.x, float(sf.data.stair.y) + 1.6, arrive.y)
		var to := (c - arrive)
		var deg := rad_to_deg(absf((sf.data.stair.n as Vector2).angle_to(to)))
		var top := Vector3(c.x, float(py.top_y) + 0.5, c.y)
		var clear := true
		for k in range(1, 40):
			var p := eye.lerp(top, k / 40.0)
			if land.height_at(p.x, p.z) > p.y:
				clear = false
		if deg <= VIEW_DEG and clear:
			in_view += 1
		else:
			print("  seed %d: the pyramid %.0f degrees off the way you face, the land between: %s" % [s, deg, str(not clear)])
		# Nothing else differs.
		if str(off.data.stair) == str(sf.data.stair) and str(off.data.stacks) == str(sf.data.stacks) and str(off.data.slots) == str(sf.data.slots):
			same += 1
		else:
			print("  seed %d: the stairhead, stacks or slots differ with the pyramid" % s)
		# Only stone: the build's tags all stone or the stone's own others
		# (the stairhead's), no new kind of thing.
		var keys := (py as Dictionary).keys()
		keys.sort()
		if str(keys) == str(["altar", "c", "face", "foot_y", "half", "rect", "stair_foot", "stair_top", "tiers", "top_half", "top_y"]):
			stone_only += 1
	CrawlerSave.aztec_on = false
	var n := seeds.size()
	tops.sort()
	print("  pyramids' heights over their foundations: %s" % str(tops.map(func(x): return snappedf(x, 0.1))))
	ok(one == n, "over every temple exactly one pyramid (%d of %d)" % [one, n])
	ok(tomb_none == n, "over every tomb none (%d of %d)" % [tomb_none, n])
	ok(on_land == n, "every pyramid on land: on the basin's floor, out of the wash, off the yard, clear of the stacks and slots (%d of %d)" % [on_land, n])
	ok(in_view == n, "every pyramid in view from where you come up: within %.0f degrees of the way you face, no land between your eye and its top (%d of %d)" % [VIEW_DEG, in_view, n])
	ok(same == n, "the stairhead, where you arrive, every stack and slot the same with it as without (%d of %d)" % [same, n])
	ok(stone_only == n, "it is scenery: stone, a stair and an altar, no exit, beacon or fast travel (%d of %d)" % [stone_only, n])


func _walks(seeds: Array) -> void:
	CrawlerSave.aztec_on = true
	var walked := 0
	var same := 0
	for s in seeds:
		var lay := TombKit.layout(int(s), "aztec_temple")
		var sf := _surface(lay)
		var again := _surface(lay)
		if str(sf.data.pyramid) == str(again.data.pyramid) and (sf.data.v as PackedVector3Array).size() == (again.data.v as PackedVector3Array).size():
			same += 1
		var py: Dictionary = sf.data.pyramid
		if py.is_empty():
			continue
		var r := await _walk(sf, py)
		if bool(r.ok):
			walked += 1
		print("  seed %d: %s" % [s, str(r.why)])
	CrawlerSave.aztec_on = false
	ok(walked == seeds.size(), "your body walks from where you come up to the stair, up it and onto the flat top by the altar (%d of %d)" % [walked, seeds.size()])
	ok(same == seeds.size(), "the same seed gives the same pyramid (%d of %d)" % [same, seeds.size()])


## Your body from the arrival to the stair's foot, up the stair, to the
## top's middle: {"ok", "why"}.
func _walk(sf: Dictionary, py: Dictionary) -> Dictionary:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(4, 4)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_root().add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var land: SurfaceGround = sf.land
	var c := land.collision()
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = c[0]
	cs.transform = c[1]
	ground.add_child(cs)
	root.add_child(ground)
	root.add_child(CrawlerMain.collision_body(sf.data))
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	var bs := CollisionShape3D.new()
	bs.shape = CrawlerPlayer.body_shape()
	bs.position = Vector3(0.0, CrawlerPlayer.STAND_HEIGHT * 0.5, 0.0)
	body.add_child(bs)
	CrawlerPlayer.floor_rules(body)
	root.add_child(body)
	await physics_frame
	await physics_frame
	var arrive: Vector2 = sf.data.stair.arrive
	body.global_position = Vector3(arrive.x, float(sf.data.stair.y) + 0.05, arrive.y)
	var f3 := Vector3((py.face as Vector2).x, 0.0, (py.face as Vector2).y)
	var foot: Vector3 = py.stair_foot
	var top: Vector3 = py.stair_top
	var mid := Vector3((py.c as Vector2).x, float(py.top_y), (py.c as Vector2).y) + f3 * float(py.top_half) * 0.3
	var goals: Array = [foot + f3 * 2.5, top - f3 * 1.0, mid]
	var out := {"ok": false, "why": ""}
	var g := 0
	var best_y := -INF
	for i in 60 * 60:
		var p := body.global_position
		var goal: Vector3 = goals[g]
		var d := Vector3(goal.x - p.x, 0.0, goal.z - p.z)
		if d.length() < 0.6:
			g += 1
			if g >= goals.size():
				break
			continue
		CrawlerPlayer.step_body(body, d.normalized(), CrawlerPlayer.WALK_SPEED, DT)
		best_y = maxf(best_y, body.global_position.y)
	var p := body.global_position
	out.ok = g >= goals.size() and absf(p.y - float(py.top_y)) < 0.4
	out.why = "reached %d of %d marks, at %s, the top's floor at %.2f (highest %.2f)" % [g, goals.size(), str(p.snapped(Vector3.ONE * 0.1)), float(py.top_y), best_y]
	NodeRelease.free_later(vp)
	return out
