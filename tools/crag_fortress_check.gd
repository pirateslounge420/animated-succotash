extends SceneTree
## The crag fortress (design 3 Oct §DO, ruins.json styles.crag_fortress,
## CragFortress, RuinBuilder._crag_fortress), headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/crag_fortress_check.gd
##  - the sites pass keeps at most per_world_max, and every one stands
##    where its gate holds (biome, realm, altitude, a crag, not wet, not
##    warm, not on water); Ruins.find returns it in its cell;
##  - every one has a delve that climbs: a way in at the foot, flights no
##    steeper than 38 degrees, the heart (the top chapel) at the top, and
##    a way out onto the terrace;
##  - the builder's triangles per instance (the near mesh) are within a
##    castle's budget: no more than the largest castle's on this world
##    (a castle is the biggest ruin built before it).
## Prints each site (where, its rise and tiers, the realm) and the gate's
## tally of reasons, and AT= for the walkabout.

const CASTLE_BUDGET := 1.0

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.generate_now(seed_v)
	var map: PlanetData = world.planet
	Delves.setup_world(map)
	RealmMap.warm(seed_v)
	var t0 := Time.get_ticks_msec()
	var sites: Array = CragFortress.all_sites(map)
	var rep: Dictionary = CragFortress.report
	print("[crag] seed %d: %d ruin cells, %d passed the gate, %d won the roll (chance %.2f), %d kept (%d ms); turned away: %s" % [seed_v, int(rep.cells), int(rep.passed), int(rep.rolled), float(CragFortress.E.get("chance", 0.3)), sites.size(), Time.get_ticks_msec() - t0, str(rep.why)])
	var cap := int(CragFortress.E.get("per_world_max", 4))
	ok(sites.size() >= 1, "seed %d has at least one crag fortress (%d)" % [seed_v, sites.size()])
	ok(sites.size() <= cap, "never more than per_world_max %d (%d)" % [cap, sites.size()])
	var gate_ok := true
	var found_ok := true
	for s in sites:
		var d: Vector3 = s.dir
		var cell := map.cell_at(d)
		var e := map.terrain.elevation(d, true, false, false)
		var realm := RealmMap.realm(RealmMap.world_at(d), d, map.temp_c[cell], map.moisture[cell], e / PlanetConst.HEIGHT_SCALE)
		var g := CragFortress.gate(map, d)
		if g != "":
			gate_ok = false
		var c := _cell_of(d)
		var f := Ruins.find(map, c)
		if f.is_empty() or int(f.kind) != Ruins.Kind.CRAG_FORTRESS:
			found_ok = false
		print("   %s at %.2f°, %.2f° (AT=%.3f,%.3f): %s, realm %s, %.0f m up (%.0f real), moisture %.2f, %.1f °C, prominence %.1f m; rise %.0f m in %d tiers" % [Ruins.site_name(s), rad_to_deg(CubeSphere.latitude(d)), rad_to_deg(CubeSphere.longitude(d)), rad_to_deg(CubeSphere.latitude(d)), rad_to_deg(CubeSphere.longitude(d)),
			BiomeTemplates.KEYS[map.biome[cell]], realm, e, e / PlanetConst.HEIGHT_SCALE, map.moisture[cell], map.temp_c[cell], CragFortress.prominence(map, d), float(s.rise_m), int(s.tiers)])
	ok(gate_ok, "every one stands where its gate holds")
	ok(found_ok, "Ruins.find returns each in its cell")
	# Elsewhere the gate holds nowhere it shouldn't: a sample of other
	# ruin cells' finds are never crag fortresses unless kept.
	var stray := 0
	var n := Ruins.cells_per_face()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 600:
		var c := Vector3i(rng.randi() % 6, rng.randi() % n, rng.randi() % n)
		var f := Ruins.find(map, c)
		if not f.is_empty() and int(f.kind) == Ruins.Kind.CRAG_FORTRESS and CragFortress.site_in(map, c).is_empty():
			stray += 1
	ok(stray == 0, "no other cell holds one (600 sampled, %d stray)" % stray)
	# The delves.
	for s in sites:
		var lay := Delves.layout(map, s)
		var pieces: Array = lay.get("pieces", [])
		var kinds := pieces.map(func(p): return str(p.kind))
		var heart_i := int(lay.get("heart_i", -1))
		var heart: Dictionary = pieces[heart_i] if heart_i >= 0 else {}
		var p: Dictionary = lay.plan
		var steep := 0.0
		for pc in pieces:
			if str(pc.kind) == "stair":
				steep = maxf(steep, absf(float(pc.y1) - float(pc.y0)) / maxf(float(pc.len), 0.01))
		var exit: Dictionary = lay.get("exit", {})
		var first: Dictionary = pieces[0] if not pieces.is_empty() else {}
		ok(bool(lay.get("climbs", false)) and str(first.get("kind", "")) == "passage" and absf(float(first.y0) - float(p.g_f)) < 0.2,
			"%s: the way in at the foot (passage at %.1f m, the ground %.1f m)" % [_name(s), float(first.get("y0", NAN)), float(p.g_f)])
		ok(not heart.is_empty() and absf(float(heart.y0) - float(p.top_y)) < 0.01, "%s: the heart is the top chapel, %.0f m above the foot" % [_name(s), float(heart.get("y0", 0.0)) - float(p.g_f)])
		ok(not exit.is_empty() and str(exit.kind) == "exit" and absf(float(exit.y0) - float(p.top_y)) < 0.01, "%s: a way out from the chapel onto the top terrace" % _name(s))
		ok(steep <= CragFortress.MAX_SLOPE + 1e-4, "%s: %d flights, none steeper than %.0f° (steepest %.1f°); %d landings (%s)" % [_name(s), kinds.count("stair"), rad_to_deg(atan(CragFortress.MAX_SLOPE)), rad_to_deg(atan(steep)), kinds.count("room"), ", ".join((lay.landings as Array).map(func(l): return str(l.get("feature", "")))) ])
		ok((lay.get("braziers", []) as Array).size() >= 1 and lay.has("heart_hearth") and lay.has("hearth"), "%s: an old hearth in the first landing, %d braziers, the heart's fire-holder" % [_name(s), (lay.get("braziers", []) as Array).size()])
	# The triangles: the castles of this world against the fortress.
	var castle_max := 0
	var castles := 0
	for i in 4000:
		var c := Vector3i(rng.randi() % 6, rng.randi() % n, rng.randi() % n)
		var f := Ruins.find(map, c)
		if f.is_empty() or int(f.kind) != Ruins.Kind.CASTLE:
			continue
		var data := RuinBuilder.compute(map, f)
		castle_max = maxi(castle_max, (data.v as PackedVector3Array).size() / 3)
		castles += 1
		if castles >= 6:
			break
	ok(castles > 0, "castles on this world to measure against (%d, the largest %d triangles)" % [castles, castle_max])
	for s in sites:
		var data := RuinBuilder.compute(map, s)
		var tris := (data.v as PackedVector3Array).size() / 3
		var inside := (int(data.delve_to) - int(data.delve_from)) / 3
		var lod := (data.lv as PackedVector3Array).size() / 3
		ok(tris <= int(castle_max * CASTLE_BUDGET), "%s: %d triangles (%d of them the climb inside; far LOD %d), within %.0f castles (%d)" % [_name(s), tris, inside, lod, CASTLE_BUDGET, int(castle_max * CASTLE_BUDGET)])
		ok((data.camp_spot as Vector3) != Vector3.ZERO, "%s: a camp spot in the plaza at the foot" % _name(s))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _name(s: Dictionary) -> String:
	return "crag %d" % (int(s.seed) % 10000)


func _cell_of(d: Vector3) -> Vector3i:
	for c in CreatureSpawner._cells_around(d, 10.0, Ruins.CELL_M):
		var s := CragFortress.site_in(get_root().get_node("World").planet, c)
		if not s.is_empty() and (s.dir as Vector3).is_equal_approx(d):
			return c
	return Vector3i(-1, -1, -1)
