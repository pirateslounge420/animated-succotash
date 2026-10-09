extends SceneTree
## The shaman and the cauldron at the hearth (design 9 Oct §FM.6, queue 67),
## headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/hearth_cauldron_check.gd
## Asserts:
##  1. the data: crawler.json cauldron (iron, a tripod, empty) and rescuer
##     holds / ladle, each with its _help line;
##  2. over 20 seeds (1, 7, 42 and more from a fixed draw; env
##     CAULDRON_SEEDS sets how many), each dungeon's hearth room as
##     CrawlerMain builds it (TombKit's layout, the tomb's collision, its
##     fires, the one who found you, HearthFolk.make, and the cauldron,
##     HearthCauldron.make) in a world of its own: exactly one shaman figure
##     and one cauldron within the hearth's reach (its light's range); the
##     cauldron hanging over the hearth's middle, its pot low over the
##     flame and under the hearth's light, its collision inside the pit's
##     guard, the tripod's feet on the kerb; the shaman with his ladle in
##     his right hand; the wake spot
##     outside the cauldron's and the figure's collision (your capsule
##     there meets neither); walking from the wake spot straight at the
##     fire, your body stops at the guard (never the cauldron) and the
##     swing from there reaches the hearth's flame; and the hearth's light
##     field at 3 m (every square of floor 2.75-3.25 m from its middle)
##     unchanged within 1% with the cauldron there, cast with it and
##     without, the hearth's light at rest and at its flicker's eight
##     furthest jitters, and no square past the kerb changed at all;
##  3. in the game (SEED, then the two tombs the stand-in takes you to):
##     the cauldron there from the first moment (built with the tomb, the
##     dark not yet lifted); exactly one shaman and one cauldron in the
##     scene in each tomb, the last tomb's gone; the named nodes and
##     getters prompt 72 will use; you wake on the mat (the wake spot as
##     laid); your body walked from the mat at the fire stops at the guard,
##     a torch from the bundle there and the swing lights it at the hearth
##     (the game's own swing, Torch.pass_flame); the light field the
##     residents read, at 3 m, unchanged within 1%;
##  4. the look (§ES, §EX.6): the cauldron's materials diffuse only (no
##     specular, roughness 1, no normal map), its light painted in (inside
##     darker than outside, the belly sooted toward the fire), dark iron;
##     the hearth's light leaves out the cauldron's layer and nothing else;
##     the cauldron's Firelight in the flame under it, the one amber,
##     lighting the cauldron's layer alone, no shadow, its colour and
##     strength the hearth light's every frame (share of it), flickering
##     with it; the pot casts no shadow, the poles do; the camera sees it;
##  5. the shaman (§FM.6, §FM.3, §ED): the same rig (a seated PlayerBody
##     with its beast head), the ladle a child of his right forearm through
##     his fist, leaning out to his right, a little toward the fire, its bowl
##     open to the sky and tipped toward the fire, its top clear of his
##     head; painted as the rig
##     (diffuse only, its big texels, folk_3d.texels_per_m), casting the
##     fire's shadow; still one blocker; wordless (no line in the log from
##     him or the cauldron); the cauldron empty (no brew: prompt 72).

## Seeds checked offline beyond the first three (env CAULDRON_SEEDS sets
## the total).
const SEEDS := 20
## The ring the light field is compared on (m from the hearth's middle).
const RING_M := Vector2(2.75, 3.25)
## How much a square's light may change (share).
const LIGHT_TOL := 0.01

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	WorldSave.read_only = true
	Residents.stay_asleep = true
	_data()
	await _offline(_seeds())
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	# From the first moment: built with the tomb, before the dark lifts.
	ok(main.cauldron != null and main.cauldron.is_inside_tree() and not main.baked and main._fade.visible, "the cauldron is there from the first moment: built with the tomb, before the dark lifts on waking")
	while not main.baked:
		await process_frame
	for i in 10:
		await physics_frame
	var boss: Variant = main.get("boss")
	if boss is Boss:
		(boss as Boss).auto = false
	_in_game(main, 0)
	await _usual_spot(main)
	await _light_in_game(main)
	await _look(main)
	_shaman(main)
	# Two more tombs by the stand-in (exit.stand_in): one of each again, the
	# last tomb's gone.
	for k in 2:
		var old_c := main.cauldron
		var old_r := main.rescuer
		main.walk_out()
		while main.leaving:
			await process_frame
		for i in 10:
			await physics_frame
		ok(not is_instance_valid(old_c) or not old_c.is_inside_tree(), "tomb %d: the last tomb's cauldron is gone" % (k + 2))
		ok(not is_instance_valid(old_r) or not old_r.is_inside_tree(), "tomb %d: the last tomb's shaman is gone" % (k + 2))
		_in_game(main, k + 1)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _seeds() -> Array:
	var n := SEEDS
	if OS.get_environment("CAULDRON_SEEDS").is_valid_int():
		n = maxi(int(OS.get_environment("CAULDRON_SEEDS")), 1)
	var out: Array = [1, 7, 42]
	var rng := RandomNumberGenerator.new()
	rng.seed = 67
	while out.size() < n:
		var s := rng.randi_range(1, 999999)
		if not out.has(s):
			out.append(s)
	return out.slice(0, n)


# --- 1. The data ---------------------------------------------------------------

func _data() -> void:
	var t := Tuning.table("crawler")
	var help: Dictionary = t.get("_help", {})
	var c: Dictionary = t.get("cauldron", {})
	var r: Dictionary = t.get("rescuer", {})
	ok(str(c.get("material", "")) == "iron" and str(c.get("hangs_from", "")) == "tripod" and bool(c.get("empty", false)) and (c.get("pot", {}) as Dictionary).has("bottom_m") and (c.get("firelight", {}) as Dictionary).has("share"), "crawler.json cauldron: iron, hung from a tripod, empty, its pot, chain, tripod, firelight and colours (§FM.6)")
	ok(str(help.get("cauldron", "")).contains("§FM.6") and not str(help.get("cauldron", "")).begins_with("[NOT WIRED"), "its _help line, wired (§FM.6, queue 67)")
	ok(str(r.get("holds", "")) == "ladle" and (r.get("ladle", {}) as Dictionary).has("handle_m") and str(help.get("rescuer", "")).contains("§FM.6"), "crawler.json rescuer holds the ladle (rescuer.ladle), its _help line says so")


# --- 2. Twenty dungeons' hearth rooms -------------------------------------------

func _offline(seeds: Array) -> void:
	var world_node := get_root().get_node("World")
	var counts_ok := true
	var over_ok := true
	var ladle_ok := true
	var wake_ok := true
	var guard_ok := true
	var feet_ok := true
	var spot_ok := true
	var swing_ok := true
	var light_ok := true
	var past_kerb_ok := true
	var least_wake_c := INF
	var least_wake_f := INF
	var worst := 0.0
	var squares := 0
	var stops: Array = []
	var reach_seen := 0.0
	var t0 := Time.get_ticks_msec()
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
		# The hearth's light where the game's flicker holds it (light_y over
		# the fire), at rest.
		var hl := fires.hearth.get_node("Light") as OmniLight3D
		hl.position = Vector3(0.0, float(fires.hearth.get_meta("light_y", 1.0)), 0.0)
		# The one who found you, rolled as CrawlerMain rolls it, and the
		# cauldron, as CrawlerMain builds it.
		var seat: Array = lay.rescuer
		var rr := RandomNumberGenerator.new()
		rr.seed = hash([int(lay.seed), "rescuer"])
		var pal := CloakedFigure.roll_palette(rr, CloakedFigure.tribe_family(int(lay.seed)))
		var folk := HearthFolk.make(root, "Rescuer", seat[0], float(seat[1]), float(CrawlerMain.RES.get("height_m", 1.62)), pal, "")
		var c := HearthCauldron.make(root, lay, fires.hearth)
		await physics_frame
		await physics_frame
		var hp: Vector3 = lay.hearth
		var reach := float(LightField.fire_light(fires.hearth).range)
		reach_seen = reach
		# Exactly one of each within the hearth's reach.
		var n_folk := 0
		var n_c := 0
		for f in root.find_children("*", "HearthFolk", true, false):
			if _flat(f.global_position, hp) <= reach:
				n_folk += 1
		for f in root.find_children("*", "HearthCauldron", true, false):
			if _flat(f.global_position, hp) <= reach:
				n_c += 1
		if n_folk != 1 or n_c != 1:
			counts_ok = false
			print("  seed %d: %d shaman figures, %d cauldrons within %.1f m of the hearth" % [s, n_folk, n_c, reach])
		# Over the hearth's middle, low over the flame, under its light.
		var hl_y := hl.global_position.y
		if _flat(c.global_position, hp) > 0.01 or c.bottom_y < 0.2 or c.bottom_y > 0.7 or c.mouth().y >= hl_y:
			over_ok = false
			print("  seed %d: the cauldron %.2f m off the hearth's middle, its bottom %.2f m up, its mouth %.2f m (the hearth's light %.2f)" % [s, _flat(c.global_position, hp), c.bottom_y, c.mouth().y, hl_y])
		if folk.ladle == null or folk.ladle.get_parent() == null or folk.ladle.get_parent().name != "ElbowR":
			ladle_ok = false
		# The cauldron's collision inside the pit's guard (its lip).
		var pt := TombBuild.pit()
		var lip := (float(pt.r) - TombBuild.PIT_LIP_M) if not pt.is_empty() else 0.55
		var hull_r := _hull_r(c)
		if hull_r >= lip:
			guard_ok = false
			print("  seed %d: the cauldron's collision reaches %.2f m from the middle, the pit's lip %.2f" % [s, hull_r, lip])
		# The tripod's feet on the kerb, between its lip and its outer edge
		# measured square to its nearest side (inside the guard).
		if not pt.is_empty():
			var step := TAU / maxf(float(pt.sides), 3.0)
			for f: Vector3 in c.feet:
				var fw := c.to_global(f)
				var dv := Vector2(fw.x - hp.x, fw.z - hp.z)
				var phi := atan2(dv.y, dv.x)
				var square := dv.length() * cos(phi - roundf(phi / step) * step)
				if square < lip + 0.02 or square > float(pt.r) + float(pt.kerb_w) - 0.02 or absf(fw.y - (hp.y + float(pt.proud) - 0.02)) > 0.01:
					feet_ok = false
					print("  seed %d: a tripod foot %.2f m out square to the kerb (the kerb %.2f-%.2f), %.2f m up" % [s, square, lip, float(pt.r) + float(pt.kerb_w), fw.y - hp.y])
		# The wake spot: your capsule there meets neither.
		var space := vp.find_world_3d().direct_space_state
		var wk: Vector3 = (lay.wake as Array)[0]
		var hits := _capsule_hits(space, wk)
		var bodies := _bodies(c, folk)
		for hit in hits:
			if bodies.has(hit):
				wake_ok = false
				print("  seed %d: your capsule at the wake spot meets %s" % [s, str(instance_from_id(hit.get_id()))])
		least_wake_c = minf(least_wake_c, _flat(wk, hp) - c.belly_r - CrawlerPlayer.RADIUS_M)
		least_wake_f = minf(least_wake_f, _flat(wk, folk.global_position) - 0.24 - CrawlerPlayer.RADIUS_M)
		# The usual spot: your body from the mat straight at the fire.
		var stop := await _walk_at_fire(root, wk, hp)
		var d_stop := _flat(stop, hp)
		stops.append(d_stop)
		var guard_m := (float(pt.r) + float(pt.kerb_w)) if not pt.is_empty() else 0.71
		if d_stop < guard_m + CrawlerPlayer.RADIUS_M - 0.06 or d_stop > guard_m / cos(PI / maxf(float(pt.get("sides", 12)), 3.0)) + CrawlerPlayer.RADIUS_M + 0.12:
			spot_ok = false
			print("  seed %d: your body stopped %.2f m from the hearth's middle (the guard %.2f m out)" % [s, d_stop, guard_m])
		# The swing there (Torch.swing_point: your chest's height, 0.4 m on)
		# reaches the hearth's flame (Campfire.lit_near's test).
		var fwd := Vector3(hp.x - stop.x, 0.0, hp.z - stop.z).normalized()
		var swing := stop + Vector3.UP * 0.9 + fwd * 0.4
		if not FireStore.is_lit(fires.hearth) or fires.hearth.global_position.distance_to(swing) >= Torch.reach_m():
			swing_ok = false
			print("  seed %d: the swing from the usual spot is %.2f m from the hearth's fire (reach %.2f)" % [s, fires.hearth.global_position.distance_to(swing), Torch.reach_m()])
		# The light field at 3 m, with the cauldron and without.
		var nav := TombNav.build(lay, space, Residents.NAV_RADIUS)
		var lf := LightField.build(nav, fires, root)
		var src := LightField.fire_light(fires.hearth)
		var jm := float(((Campfire.L.get("flicker", {}) as Dictionary)).get("position_jitter_m", 0.06))
		var at: Array = [src.pos]
		for dx: float in [-jm, jm]:
			for dy: float in [-jm, jm]:
				for dz: float in [-jm, jm]:
					at.append((src.pos as Vector3) + Vector3(dx, dy, dz))
		for p in at:
			var sp: Dictionary = src.duplicate()
			sp.pos = p
			var with_c := _levels(lf._cast_fire(sp))
			c.collision.collision_layer = 0
			await physics_frame
			var without := _levels(lf._cast_fire(sp))
			c.collision.collision_layer = PropCollision.WORLD_LAYER
			await physics_frame
			var cmp := _compare(nav, hp, with_c, without, float(pt.r) + float(pt.kerb_w) if not pt.is_empty() else 0.8)
			worst = maxf(worst, float(cmp.worst))
			squares = maxi(squares, int(cmp.ring))
			if float(cmp.worst) > LIGHT_TOL or int(cmp.ring) == 0:
				light_ok = false
				print("  seed %d: the light at 3 m changed by up to %.2f%% (%d squares)" % [s, float(cmp.worst) * 100.0, int(cmp.ring)])
			if int(cmp.past_kerb) > 0:
				past_kerb_ok = false
				print("  seed %d: %d squares of floor past the kerb lit differently with the cauldron" % [s, int(cmp.past_kerb)])
		NodeRelease.free_later(vp)
	var n := seeds.size()
	stops.sort()
	ok(counts_ok, "%d seeds: every dungeon's hearth room has exactly one shaman figure and one cauldron within the hearth's reach (its light's range, %.1f m)" % [n, reach_seen])
	ok(over_ok, "the cauldron hangs over the hearth's middle every time, its pot low over the flame, its mouth under the hearth's light")
	ok(ladle_ok, "the shaman holds his ladle in his right hand every time")
	ok(guard_ok, "the cauldron's collision lies inside the pit's guard (inside its lip): nothing you walk changes")
	ok(feet_ok, "the tripod's three feet stand on the pit's kerb every time, inside its guard")
	ok(wake_ok, "the wake spot is inside neither the cauldron's collision nor the figure's: your capsule there meets neither (at least %.2f m clear of the cauldron, %.2f m of the shaman)" % [least_wake_c, least_wake_f])
	ok(spot_ok, "from the mat straight at the fire your body stops at the pit's guard, never at the cauldron (%.2f-%.2f m from its middle)" % [float(stops[0]) if not stops.is_empty() else 0.0, float(stops[-1]) if not stops.is_empty() else 0.0])
	ok(swing_ok, "a torch lights at the hearth from that usual spot: the swing reaches its flame every time")
	ok(light_ok, "the hearth's light field at 3 m unchanged within %.0f%% with the cauldron hanging there (worst %.3f%%, up to %d squares, the light at rest and at its flicker's furthest jitters)" % [LIGHT_TOL * 100.0, worst * 100.0, squares])
	ok(past_kerb_ok, "and no square of floor past the kerb lit any differently")
	print("  %d hearth rooms in %d s" % [n, (Time.get_ticks_msec() - t0) / 1000])


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## How far from the cauldron's middle its collision reaches (flat).
func _hull_r(c: HearthCauldron) -> float:
	var most := 0.0
	for cs in c.collision.get_children():
		var hull := (cs as CollisionShape3D).shape as ConvexPolygonShape3D
		if hull == null:
			continue
		for q in hull.points:
			most = maxf(most, Vector2(q.x, q.z).length())
	return most


## The cauldron's and the figure's bodies (their RIDs).
func _bodies(c: HearthCauldron, folk: HearthFolk) -> Array:
	var out: Array = [c.collision.get_rid()]
	for b in folk.find_children("*", "CollisionObject3D", true, false):
		out.append((b as CollisionObject3D).get_rid())
	return out


## The RIDs your standing capsule meets at `at` (on the floor).
func _capsule_hits(space: PhysicsDirectSpaceState3D, at: Vector3) -> Array:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = CrawlerPlayer.body_shape()
	q.collision_mask = PropCollision.WORLD_LAYER
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.1 + CrawlerPlayer.STAND_HEIGHT * 0.5, 0.0))
	var out: Array = []
	for h in space.intersect_shape(q, 32):
		out.append(h.rid)
	return out


## Your body (its capsule and floor rules) walked from `from` straight at
## `target` until it stops: where it stood.
func _walk_at_fire(root: Node3D, from: Vector3, target: Vector3) -> Vector3:
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	var cs := CollisionShape3D.new()
	cs.shape = CrawlerPlayer.body_shape()
	cs.position = Vector3(0.0, CrawlerPlayer.STAND_HEIGHT * 0.5, 0.0)
	body.add_child(cs)
	CrawlerPlayer.floor_rules(body)
	root.add_child(body)
	body.global_position = from + Vector3(0.0, 0.05, 0.0)
	await physics_frame
	var wish := Vector3(target.x - from.x, 0.0, target.z - from.z).normalized()
	var last := body.global_position
	var still := 0
	for i in 300:
		CrawlerPlayer.step_body(body, wish, CrawlerPlayer.WALK_SPEED, 1.0 / 60.0)
		if body.global_position.distance_to(last) < 0.002:
			still += 1
			if still > 12:
				break
		else:
			still = 0
		last = body.global_position
	var at := body.global_position
	body.queue_free()
	return at


## A cast's light by square: {index: light}.
func _levels(part: Dictionary) -> Dictionary:
	var out := {}
	var cells: PackedInt32Array = part.cells
	var lv: PackedFloat32Array = part.lv
	for k in cells.size():
		out[cells[k]] = lv[k]
	return out


## The hearth's light on the ring at 3 m with the cauldron and without:
## {"worst" (the biggest share any square changed by), "ring" (squares of
## floor on the ring), "past_kerb" (squares past the kerb changed at all)}.
func _compare(nav: TombNav, hp: Vector3, a: Dictionary, b: Dictionary, kerb_m: float) -> Dictionary:
	var worst := 0.0
	var ring := 0
	var past := 0
	var keys := {}
	for k in a:
		keys[k] = true
	for k in b:
		keys[k] = true
	for k in keys:
		var i := int(k)
		var c := Vector2i(i % nav.size.x, i / nav.size.x)
		var p := nav.point_of(c)
		var d := _flat(p, hp)
		var va := float(a.get(i, 0.0))
		var vb := float(b.get(i, 0.0))
		if d >= RING_M.x and d <= RING_M.y and nav.is_open(c):
			ring += 1
			worst = maxf(worst, absf(va - vb) / maxf(vb, 1e-6))
		if d > kerb_m + 0.05 and absf(va - vb) > 1e-6:
			past += 1
	return {"worst": worst, "ring": ring, "past_kerb": past}


# --- 3. In the game -------------------------------------------------------------

func _in_game(main: CrawlerMain, k: int) -> void:
	var lay := main.lay
	var hp: Vector3 = lay.hearth
	var n_folk := main.find_children("*", "HearthFolk", true, false).size()
	var n_c := get_nodes_in_group(HearthCauldron.GROUP).size()
	var c := main.cauldron
	ok(n_folk == 1 and n_c == 1 and c != null and main.shaman() != null, "tomb %d (seed %d): exactly one shaman and one cauldron in the scene (%d, %d)" % [k + 1, int(lay.seed), n_folk, n_c])
	if c == null or main.shaman() == null:
		return
	var reach := float(LightField.fire_light(main.fires.hearth).range)
	ok(_flat(c.global_position, hp) < 0.01 and _flat(main.shaman().global_position, hp) <= reach, "tomb %d: the cauldron over the hearth's middle, the shaman across the fire %.1f m off (within its reach, %.1f m)" % [k + 1, _flat(main.shaman().global_position, hp), reach])
	ok(main.get_node_or_null("Cauldron") == c and main.get_node_or_null("Rescuer") == main.shaman() and main.shaman() == main.rescuer and c.is_in_group(HearthCauldron.GROUP), "tomb %d: code finds them (CrawlerMain.cauldron, the node Cauldron, the group %s; CrawlerMain.shaman(), the node Rescuer)" % [k + 1, HearthCauldron.GROUP])
	var w: Array = lay.wake
	var p := main.player.global_position
	ok(_flat(p, w[0]) < 0.05 and absf(p.y) < 0.1, "tomb %d: you wake on the mat, the wake spot as laid (%.3f m off it)" % [k + 1, _flat(p, w[0])])


## The usual spot, in the game: your body from the mat straight at the fire
## (forward held), a torch from the bundle there, the swing lights it.
func _usual_spot(main: CrawlerMain) -> void:
	var p := main.player
	var hp: Vector3 = main.lay.hearth
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), -0.32)
	await physics_frame
	var to := Vector3(hp.x - p.global_position.x, 0.0, hp.z - p.global_position.z).normalized()
	var facing := -p.global_basis.z
	facing.y = 0.0
	ok(facing.normalized().dot(to) > 0.95, "you wake facing the fire")
	Input.action_press("move_forward")
	var last := p.global_position
	var still := 0
	for i in 360:
		await physics_frame
		if p.global_position.distance_to(last) < 0.002:
			still += 1
			if still > 20:
				break
		else:
			still = 0
		last = p.global_position
	Input.action_release("move_forward")
	await physics_frame
	var d := _flat(p.global_position, hp)
	var pt := TombBuild.pit()
	var guard_m := float(pt.r) + float(pt.kerb_w)
	ok(d >= guard_m + CrawlerPlayer.RADIUS_M - 0.06 and d > main.cauldron.belly_r + CrawlerPlayer.RADIUS_M + 0.3, "walking from the mat at the fire you stop at the pit's guard, %.2f m from its middle (the guard %.2f m out), not at the cauldron" % [d, guard_m])
	var took := main.take_torch()
	var t := p.torch
	var how := t.pass_flame()
	ok(took and how == "torch" and t.lit(), "a torch from the bundle there, and the swing lights it at the hearth (%s)" % how)
	t.put_out("stowed")
	p.spawn_flat(w[0], float(w[1]), -0.32)
	await physics_frame


## The light field the residents read, at 3 m, with the cauldron and
## without (the hearth's light where it hangs now).
func _light_in_game(main: CrawlerMain) -> void:
	var lf: LightField = main.residents.light
	ok(lf != null, "the residents' light field is built")
	if lf == null:
		return
	var src := LightField.fire_light(main.fires.hearth)
	var a := _levels(lf._cast_fire(src))
	main.cauldron.collision.collision_layer = 0
	await physics_frame
	var b := _levels(lf._cast_fire(src))
	main.cauldron.collision.collision_layer = PropCollision.WORLD_LAYER
	await physics_frame
	var pt := TombBuild.pit()
	var cmp := _compare(lf.nav, main.lay.hearth, a, b, float(pt.r) + float(pt.kerb_w))
	ok(float(cmp.worst) <= LIGHT_TOL and int(cmp.ring) > 0 and int(cmp.past_kerb) == 0, "in the game, the light field at 3 m from the hearth is unchanged within %.0f%% with the cauldron (worst %.3f%% over %d squares; %d squares past the kerb changed)" % [LIGHT_TOL * 100.0, float(cmp.worst) * 100.0, int(cmp.ring), int(cmp.past_kerb)])
	# The hearth's entry in it, as Campfire made the light.
	var hl := main.fires.hearth.get_node("Light") as OmniLight3D
	ok(absf(hl.global_position.y - (main.lay.hearth as Vector3).y - 1.0) < 0.1 and absf(float(src.att) - Campfire.ATTENUATION) < 1e-4 and absf(float(src.range) - Campfire.RANGE_M * lerpf(1.0, float(Campfire.L.get("night_range_scale", 1.6)), Campfire.night)) < 1e-3, "the hearth's entry in the light field is the hearth's light as built: a metre over the floor, its range %.1f m and falloff as before" % float(src.range))


# --- 4. The look ------------------------------------------------------------------

func _look(main: CrawlerMain) -> void:
	var c := main.cauldron
	var bad: Array = []
	var mats := 0
	for g in c.find_children("*", "GeometryInstance3D", true, false):
		var m := (g as GeometryInstance3D).material_override
		if m == null:
			continue
		mats += 1
		var why := _diffuse_only(m)
		if why != "":
			bad.append("%s: %s" % [g.name, why])
	ok(mats >= 2 and bad.is_empty(), "painted per §ES: no material on the cauldron has specular above 0, roughness under 1 or a normal map (%d checked)%s" % [mats, (": " + ", ".join(bad)) if not bad.is_empty() else ""])
	# Its light painted in: inside darker than outside, the belly sooted.
	var arr := (c.pot.mesh as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var inside := Vector2.ZERO
	var outside := Vector2.ZERO
	var low := Vector2.ZERO
	var high := Vector2.ZERO
	var h := c.mouth_y - c.bottom_y
	for i in v.size():
		var q := v[i]
		if q.y > c.mouth_y + 0.01 or q.y < c.bottom_y - 0.01:
			continue
		var radial := Vector2(q.x, q.z)
		if radial.length() < 0.05:
			continue
		var l := col[i].get_luminance()
		var outward := Vector2(n[i].x, n[i].z).dot(radial.normalized())
		if outward < -0.3 and q.y > c.bottom_y + 0.05 and q.y < c.mouth_y - 0.03:
			inside += Vector2(l, 1.0)
		elif outward > 0.3:
			outside += Vector2(l, 1.0)
			if q.y < c.bottom_y + 0.25 * h:
				low += Vector2(l, 1.0)
			elif q.y > c.bottom_y + 0.7 * h and q.y < c.mouth_y - 0.03:
				high += Vector2(l, 1.0)
	var li := inside.x / maxf(inside.y, 1.0)
	var lo := outside.x / maxf(outside.y, 1.0)
	var ll := low.x / maxf(low.y, 1.0)
	var lh := high.x / maxf(high.y, 1.0)
	print("  the pot's paint: inside %.3f, outside %.3f; the belly toward the fire %.3f, the shoulder %.3f" % [li, lo, ll, lh])
	ok(inside.y > 20 and li < lo * 0.85, "its light painted in: inside the pot darker than outside (%.3f against %.3f: the occlusion baked toward navy)" % [li, lo])
	ok(ll < lh, "the belly sooted toward the fire: darker low than at the shoulder (%.3f against %.3f)" % [ll, lh])
	var iron := Color(str(((HearthCauldron.D.get("colors", {}) as Dictionary)).get("iron", "#26262c")))
	var stone := RuinStyle.tint(str(main.lay.get("theme", "tomb")))
	ok(iron.get_luminance() < stone.get_luminance() * 0.6, "dark iron against the tomb's stone (%.2f against %.2f)" % [iron.get_luminance(), stone.get_luminance()])
	# The hearth's light leaves out the cauldron's layer, and nothing else.
	var hl := c.hearth_light
	ok(hl != null and hl == main.fires.hearth.get_node("Light") and hl.light_cull_mask == (0xFFFFFFFF & ~HearthCauldron.LAYER), "the hearth's light passes the cauldron by: its cull mask leaves out the cauldron's layer and nothing else (%x)" % (hl.light_cull_mask if hl else 0))
	var fl := c.firelight
	var amber := Torch.fire_color()
	ok(fl != null and fl.light_cull_mask == HearthCauldron.LAYER and not fl.shadow_enabled and not fl.is_in_group(FireShadows.GROUP) and Vector3(fl.light_color.r - amber.r, fl.light_color.g - amber.g, fl.light_color.b - amber.b).length() < 0.01, "its Firelight: the one amber (#%s), lighting the cauldron's layer alone, no shadow, not a fire of the fire rules" % fl.light_color.to_html(false))
	ok(fl.position.y < c.bottom_y and fl.position.y > -0.3 and _flat(fl.global_position, c.global_position) < 0.01, "in the flame, under the pot's belly (%.2f m over the floor, its bottom %.2f)" % [fl.position.y, c.bottom_y])
	var follows := true
	var lo_e := INF
	var hi_e := -INF
	for i in 30:
		await process_frame
		var want := hl.light_energy * c.share
		if absf(fl.light_energy - want) > 1e-3 * maxf(want, 1.0):
			follows = false
		lo_e = minf(lo_e, fl.light_energy)
		hi_e = maxf(hi_e, fl.light_energy)
	ok(follows and hi_e > lo_e and lo_e > 0.0, "the hearth's amber falls on it live: its strength the hearth light's times %.2f every frame, flickering with it (%.2f-%.2f)" % [c.share, lo_e, hi_e])
	ok(c.pot.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and c.tripod.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and c.pot.layers == HearthCauldron.LAYER and c.tripod.layers == HearthCauldron.LAYER, "the pot casts no shadow (it hangs right under the hearth's light), the poles do; both on the cauldron's layer")
	var cam := get_root().get_viewport().get_camera_3d()
	ok(cam != null and (cam.cull_mask & HearthCauldron.LAYER) != 0, "the camera sees the cauldron's layer")
	print("  the cauldron: %d triangles; its pot %.2f m across, bottom %.2f m, mouth %.2f m up; the tripod's apex %.2f m" % [c.triangles, c.belly_r * 2.0, c.bottom_y, c.mouth_y, c.apex.y])


## Diffuse only (§ES.2): "" if `m` has no specular above 0, no roughness
## under 1 and no normal map; else what's wrong (crawler_check's test).
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
			return "specular not disabled"
		for a in RegEx.create_from_string("ROUGHNESS\\s*=\\s*([^;]+);").search_all(code):
			if a.get_string(1).strip_edges() != "1.0":
				return "ROUGHNESS = %s" % a.get_string(1)
		for a in RegEx.create_from_string("SPECULAR\\s*=\\s*([^;]+);").search_all(code):
			if a.get_string(1).strip_edges() != "0.0":
				return "SPECULAR = %s" % a.get_string(1)
		if code.contains("NORMAL_MAP"):
			return "a normal map"
		return ""
	return "a %s" % m.get_class()


# --- 5. The shaman -----------------------------------------------------------------

func _shaman(main: CrawlerMain) -> void:
	var r := main.shaman()
	var body := r.body
	var beast_mi := body.head.get_node_or_null("Beast") as MeshInstance3D
	ok(body is PlayerBody and body.seated and r.beast != "" and beast_mi != null, "the shaman is the same rig: a seated PlayerBody, its beast head (%s)" % r.beast)
	var ld := r.ladle
	var elbow := (body.arms[1] as Node3D).get_node_or_null("ElbowR")
	ok(ld != null and ld.get_parent() == elbow and ld.position.distance_to(HearthFolk.FIST) < 1e-4, "his ladle is in his right hand: a child of his right forearm, through his fist")
	if ld == null:
		return
	var up := ld.global_basis.y.normalized()
	var front := r.front()
	var right := front.cross(Vector3.UP).normalized()
	var opens := (ld.global_basis * (ld.get_meta("opens", Vector3.ZERO) as Vector3)).normalized()
	print("  the ladle: up %.2f, out to his right %.2f, toward the fire %.2f; its bowl open to the sky %.2f, toward the fire %.2f" % [up.y, up.dot(right), up.dot(front), opens.y, opens.dot(front)])
	ok(up.y > 0.6 and up.dot(right) > 0.3 and up.dot(front) > 0.05, "it rises from his fist, out to his right and a little toward the fire")
	ok(opens.y > 0.7 and opens.dot(front) > 0.2, "its bowl open to the sky, tipped toward the fire: a scoop, not a disc held up")
	var top := ld.global_transform * Vector3(0.0, 0.7, 0.0)
	var head := body.head.global_position
	ok(Vector2(top.x - head.x, top.z - head.z).length() > 0.3, "its top clear of his head (%.2f m from it)" % Vector2(top.x - head.x, top.z - head.z).length())
	ok(_diffuse_only(ld.material_override) == "" and absf(float((ld.material_override as ShaderMaterial).get_shader_parameter("texel_m")) - float(HearthFolk.F3D.get("texels_per_m", 16.0))) < 0.01, "painted as the rig: diffuse only, its big texels (%.0f a metre, folk_3d.texels_per_m)" % float(HearthFolk.F3D.get("texels_per_m", 16.0)))
	ok(ld.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "it casts the fire's shadow with the rest of him")
	ok(r.find_children("Blocker", "StaticBody3D", true, false).size() == 1 and ld.find_children("*", "CollisionObject3D", true, false).is_empty(), "still one blocker round him, nothing to bump into on the ladle")
	var spoke := 0
	for e in GameLog.entries:
		var line := str(e.get("text", "")).to_lower()
		if line.contains("shaman") or line.contains("cauldron") or line.contains("ladle"):
			spoke += 1
	ok(spoke == 0, "wordless (§ED, §FM.3): no line in the log from him or the cauldron")
	var c := main.cauldron
	ok(bool(HearthCauldron.D.get("empty", false)) and c.find_children("Brew*", "", true, false).is_empty(), "the cauldron is empty: no brew yet (prompt 72)")
