extends SceneTree
## Haunted where the dead lie (design 3 Oct §DI.4, data/ruins.json haunt,
## Haunt), headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/haunt_check.gd
##  - 100 ten-minute visits to a haunted graveyard at night (the haunt's
##    clock stepped a second at a time): a ghost in roughly 10-25 % of
##    them, never more than once a visit, never twice in a row at one spot;
##  - the same at noon in the open: none; at an unhaunted ruin: none;
##  - one freed within half a second of leaving the camera's view;
##  - the dread meter and stage untouched; its material has no emission,
##    and it holds no Light3D.

var fails := 0
var main: Node
var world: Node


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var h: Haunt = main.haunt
	var map: PlanetData = world.planet
	var camp: Vector3 = main.camp.site
	# The shares on this world's graveyards and barrows.
	var n_k := 0
	var n_h := 0
	for c in CreatureSpawner._cells_around(camp, 60000.0, Ruins.CELL_M):
		var s := Ruins.find(map, c)
		if not s.is_empty() and int(s.kind) in [Ruins.Kind.GRAVEYARD, Ruins.Kind.BARROW]:
			n_k += 1
			if Haunt.haunted(s):
				n_h += 1
	# And over the planet (a sample of its cells).
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var pn := Ruins.cells_per_face()
	for i in 30000:
		var s := Ruins.find(map, Vector3i(rng.randi() % 6, rng.randi() % pn, rng.randi() % pn))
		if not s.is_empty() and int(s.kind) in [Ruins.Kind.GRAVEYARD, Ruins.Kind.BARROW]:
			n_k += 1
			if Haunt.haunted(s):
				n_h += 1
	print("   graveyards and barrows (within 60 km and a planet sample): %d, haunted %d (%.0f %%; share %.2f)" % [n_k, n_h, 100.0 * n_h / maxf(n_k, 1.0), float(Haunt.D.get("share", 0.4))])
	ok(absf(float(n_h) / maxf(n_k, 1.0) - float(Haunt.D.get("share", 0.4))) < 0.1, "about share of them haunted (%.2f)" % (float(n_h) / maxf(n_k, 1.0)))
	var yard := _ruin_where(map, camp, func(s: Dictionary) -> bool: return int(s.kind) == Ruins.Kind.GRAVEYARD and Haunt.haunted(s) and not Overrun.is_overrun(s))
	ok(not yard.is_empty(), "a haunted graveyard on this world")
	if yard.is_empty():
		_done()
		return
	var node: Node3D = await _stand_facing(yard)
	print("   the graveyard: %s AT=%.3f,%.3f" % [node.name if node else "?", rad_to_deg(CubeSphere.latitude(yard.dir)), rad_to_deg(CubeSphere.longitude(yard.dir))])
	h.set_process(false)
	# --- 100 visits at night. ---
	h.override = {"hour": "night"}
	var r := _visits(h, 100)
	print("   at night: %d of 100 visits saw one (%d appearances; most in one visit %d; same spot twice in a row %d)" % [r.visits_seen, r.total, r.most, r.repeats])
	ok(r.visits_seen >= 10 and r.visits_seen <= 25, "a ghost in %d %% of 100 ten-minute visits at night (10-25 %%)" % r.visits_seen)
	ok(r.most <= int(Haunt.D.get("per_visit_max", 1)), "never more than %d a visit (most %d)" % [int(Haunt.D.get("per_visit_max", 1)), r.most])
	ok(r.repeats == 0, "never twice in a row at one spot (%d)" % r.repeats)
	# --- At noon in the open. ---
	h.override = {"hour": "day", "visibility": 1.0}
	var noon := _visits(h, 100)
	ok(noon.total == 0, "at noon in the open: %d in 100 visits" % noon.total)
	# --- The ghost's own ways: freed out of view, no light, no dread. ---
	h.override = {"hour": "night"}
	var spot := {}
	for i in 60:
		spot = h.find_spot(node)
		if not spot.is_empty():
			break
	ok(not spot.is_empty(), "a spot in view with an occluder by it (%s)" % (("%.1f m off" % (spot.spot as Vector3).distance_to(main.player.global_position)) if not spot.is_empty() else "none"))
	if not spot.is_empty():
		var meter0: float = main.dread.meter
		var stage0: int = main.dread.stage
		h.appear(node, spot)
		var g: Node3D = h.ghost.node
		var lights := g.find_children("*", "Light3D", true, false).size()
		var emits := false
		var shadows := false
		for gi in g.find_children("*", "GeometryInstance3D", true, false):
			var geo := gi as GeometryInstance3D
			if geo.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadows = true
			var mi := gi as MeshInstance3D
			var mats: Array = []
			if mi != null:
				mats.append(mi.material_override)
				if mi.mesh != null:
					for si in mi.mesh.get_surface_count():
						mats.append(mi.get_active_material(si))
			for m in mats:
				if m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.code.contains("EMISSION"):
					emits = true
				if m is StandardMaterial3D and (m as StandardMaterial3D).emission_enabled:
					emits = true
		ok(lights == 0 and not emits and not shadows, "its material has no emission, it holds no Light3D (%d) and casts no shadow" % lights)
		ok(g.find_children("*", "CollisionObject3D", true, false).is_empty(), "it has no collision")
		h.set_process(true)
		for i in 30:
			await process_frame
		var alive_in_view := not h.ghost.is_empty()
		# Turn away: it is gone within half a second.
		var turned_at := Time.get_ticks_msec()
		main.player.set_view(0.0, main.player._yaw + PI)
		var frames := 0
		while not h.ghost.is_empty() and frames < 120:
			await process_frame
			frames += 1
		ok(alive_in_view, "it stood in view for its first half second")
		ok(h.ghost.is_empty() and frames <= 30, "freed %d frames (%.2f s) after the view left it" % [frames, frames / 60.0])
		ok(main.dread.meter == meter0 and main.dread.stage == stage0, "the dread untouched (meter %.4f -> %.4f, stage %d -> %d)" % [meter0, main.dread.meter, stage0, main.dread.stage])
		h.set_process(false)
	var src := FileAccess.get_file_as_string("res://scripts/landmarks/haunt.gd")
	ok(not src.contains("Dread.") and not src.contains("dread.") and not src.contains("GameLog") and not src.contains("AudioStreamPlayer"), "the haunt's code touches no dread, no log and no sound")
	# --- An unhaunted ruin. ---
	var plain := _ruin_where(map, camp, func(s: Dictionary) -> bool: return not Haunt.haunted(s) and not Haunt.tomb_haunted(s) and not Overrun.is_overrun(s))
	if not plain.is_empty():
		await _stand_facing(plain)
		h.override = {"hour": "night"}
		var none := _visits(h, 100)
		ok(none.total == 0, "at an unhaunted %s at night: %d in 100 visits" % [Ruins.KIND_NAMES[int(plain.kind)], none.total])
	_done()


func _done() -> void:
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## `n` visits of ten minutes, the haunt stepped a second at a time; each
## ghost freed at once (it slipped away). {"visits_seen", "total", "most",
## "repeats"}.
func _visits(h: Haunt, n: int) -> Dictionary:
	var seen := 0
	var total := 0
	var most := 0
	var repeats := 0
	var last := Vector3.INF
	for v in n:
		h.new_visit()
		var here := 0
		for s in 600:
			h.tick(1.0)
			if not h.ghost.is_empty():
				here += 1
				var sp: Vector3 = h.ghost.spot
				if last != Vector3.INF and sp.distance_to(last) < Haunt.SAME_SPOT_M:
					repeats += 1
				last = sp
				h.free_ghost()
		if here > 0:
			seen += 1
		total += here
		most = maxi(most, here)
	return {"visits_seen": seen, "total": total, "most": most, "repeats": repeats}


func _ruin_where(map: PlanetData, camp: Vector3, want: Callable) -> Dictionary:
	var best := {}
	var bd := INF
	for c in CreatureSpawner._cells_around(camp, 60000.0, Ruins.CELL_M):
		var s := Ruins.find(map, c)
		if s.is_empty() or not want.call(s):
			continue
		var dm := CubeSphere.surface_distance_m(s.dir, camp)
		if dm < bd:
			bd = dm
			best = s
	return best


## Stand 14 m off the ruin facing it; its collision built.
func _stand_facing(site: Dictionary) -> Node3D:
	var d := CreatureSpawner._offset(site.dir, 0.3, float(site.footprint_m) * 0.5 + 12.0)
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	main.player.global_position -= off
	main.chunks.load_blocking(d)
	main.player.spawn_at(d)
	main.landmarks.build_ruin_at(site.dir)
	for i in 240:
		await process_frame
	var target: Vector3 = world.to_scene(site.dir, PlanetConst.RADIUS_M + world.surface_elevation(site.dir) + 1.0)
	# The yaw (relative to the body's heading) that looks most at it.
	var best := 0.0
	var best_dot := -2.0
	for j in 36:
		var yw := TAU * j / 36.0
		main.player.set_view(0.0, yw)
		var cam: Camera3D = main.player.camera()
		var dt := (-cam.global_basis.z).dot((target - cam.global_position).normalized())
		if dt > best_dot:
			best_dot = dt
			best = yw
	main.player.set_view(0.0, best)
	for i in 10:
		await process_frame
	for c in main.landmarks._ruins:
		var nd: Node3D = main.landmarks._ruins[c]
		if is_instance_valid(nd) and (nd.get_meta("site", {}) as Dictionary).get("dir", Vector3.ZERO) == site.dir:
			return nd
	return null
