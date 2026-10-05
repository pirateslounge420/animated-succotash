extends SceneTree
## The columns (design 3 Oct §DX, landforms.json columnar_basalt), headless,
## full planet, no scene:
##   SEED=7731 godot --headless --path . --script tools/basalt_check.gd
##   SEEDS=7731,8,2 ... runs several worlds.
## Every columnar basalt nest on the planet (Nests, the sites pass) is
## found and asserts:
##  - it sits on basalt where its cause holds: the causeway and the sea cave
##    at the sea's edge (water within 20 m), the organ pipes on a river's
##    bank (a reach within 30 m) with basalt under the cliff or beside it;
##  - each form places at least once where its cause holds on the world
##    (a cell whose ground gives it a candidate, Nests.column_forms; else
##    SKIP);
##  - the causeway: its hearth spot above the high-water line plus the
##    spray, its cups hold water, its tops go under the sea; it can hold a
##    camp (water in the cups) and its seats are column tops;
##  - the organ pipes: the cliff 10-40 m, the fall's sheet and its pool,
##    the hearth at the foot by the pool and out of the spray;
##  - the sea cave: never a camp nor remains; its hearth spot on the
##    clifftop over the cave's back; a roof of column undersides over
##    water; the ledge and the den at its back; its boom a source;
##  - the boom plays only within its max_distance (Landmarks' tick, a
##    listener at 0.5x and 1.5x of it for a minute of swells);
##  - the stone's tile reads 16 texels a metre (look.json retro tile_px /
##    tile_m on stone), the hexagons are the columns themselves;
##  - each build's triangles, under BUDGET.

const BUDGET := 120000

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = get_root().get_node("World")
	var seeds: Array = []
	for s in (OS.get_environment("SEEDS") if OS.get_environment("SEEDS") != "" else (OS.get_environment("SEED") if OS.get_environment("SEED") != "" else "7731")).split(","):
		seeds.append(int(s))
	_tile()
	await _boom()
	for seed_v in seeds:
		world.generate_now(seed_v)
		var map: PlanetData = world.planet
		RealmMap.warm(seed_v)
		var rivers := Encampment.rivers_for(map)
		Nests.setup(map, rivers)
		_world(seed_v, map, rivers)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _tile() -> void:
	var look: Dictionary = Tuning.table("look")
	var retro: Dictionary = look.get("retro", {})
	var px = (retro.get("tile_px", {}) as Dictionary).get("stone", 64) if retro.get("tile_px") is Dictionary else retro.get("tile_px", 64)
	var tm := float((retro.get("tile_m", {}) as Dictionary).get("stone", 4.0))
	ok(absf(float(px) / tm - 16.0) < 0.01, "stone tile %s px over %.1f m = %.1f texels a metre (16)" % [str(px), tm, float(px) / tm])


## The boom's tick (Landmarks._tick_boom) with a listener inside and outside
## its max_distance.
func _boom() -> void:
	var lm := Landmarks.new()
	var holder := Node3D.new()
	get_root().add_child(holder)
	var node := Node3D.new()
	holder.add_child(node)
	node.set_meta("boom", Vector3.ZERO)
	var n := {"key": "nest:columnar_basalt:test", "kind": "columnar_basalt", "variant": "columned_sea_cave"}
	await process_frame
	var maxd := float(Audio3D.row("sea_cave_boom").get("max_distance", 0.0))
	ok(maxd > 0.0, "audio.json has a sea_cave_boom row (max_distance %.0f m)" % maxd)
	for f: float in [0.5, 1.5]:
		node.set_meta("booms", 0)
		node.set_meta("boom_t", 0.1)
		var pp := Vector3(maxd * f, 0.0, 0.0)
		for i in 600:
			lm._tick_boom(node, n, pp, 0.1)
		var booms := int(node.get_meta("booms", 0))
		if f < 1.0:
			ok(booms >= 4, "the boom plays with the swell within its reach (%d booms in 60 s at %.0f m)" % [booms, maxd * f])
		else:
			ok(booms == 0, "the boom is silent past its max_distance (%d booms at %.0f m)" % [booms, maxd * f])
	var st := SoundSynth.stream("boom", 3)
	ok(st != null and st.data.size() > 22050, "the boom's sound is made (%.1f s)" % (float(st.data.size()) / 2.0 / 22050.0 if st != null else 0.0))
	holder.queue_free()
	lm.free()


func _world(seed_v: int, map: PlanetData, rivers: RiverNetwork) -> void:
	var t0 := Time.get_ticks_msec()
	var nests: Array = []
	var cp := CreatureSpawner._cells_per_face(Nests.cell_m("columnar_basalt"))
	for f in 6:
		for i in cp:
			for j in cp:
				var n := Nests.find("columnar_basalt", Vector3i(f, i, j))
				if not n.is_empty():
					nests.append(n)
	print("[basalt] seed %d · %d nests (%d ms, the sites pass over %d cells)" % [seed_v, nests.size(), Time.get_ticks_msec() - t0, 6 * cp * cp])
	var by := {"": 0, "organ_pipes": 0, "columned_sea_cave": 0}
	for n in nests:
		by[str(n.variant)] = int(by.get(str(n.variant), 0)) + 1
	print("[basalt] causeway %d · organ pipes %d · sea cave %d" % [by[""], by.organ_pipes, by.columned_sea_cave])
	# Where each form's cause holds on this world: the cells whose ground
	# gives the form a candidate (Nests.column_forms), whichever the cell's
	# roll took.
	var cause := {"": 0, "columned_sea_cave": 0, "organ_pipes": 0}
	for f in 6:
		for i in cp:
			for j in cp:
				var fm := Nests.column_forms(Vector3i(f, i, j))
				cause[""] += 1 if int(fm.causeway) > 0 else 0
				cause.columned_sea_cave += 1 if int(fm.sea_cave) > 0 else 0
				cause.organ_pipes += 1 if int(fm.organ_pipes) > 0 else 0
	for form in [["", "the causeway"], ["columned_sea_cave", "the sea cave"], ["organ_pipes", "the organ pipes"]]:
		if int(cause[form[0]]) == 0:
			print("SKIP  %s: its cause holds nowhere on seed %d" % [form[1], seed_v])
		else:
			ok(int(by[form[0]]) >= 1, "%s places where its cause holds (seed %d: %d cells hold it, %d placed)" % [form[1], seed_v, cause[form[0]], by[form[0]]])
	var built := {}
	for n in nests:
		_one(map, rivers, n, built)


func _one(map: PlanetData, rivers: RiverNetwork, n: Dictionary, built: Dictionary) -> void:
	var v := str(n.variant)
	var name := Nests.name_of(n)
	var d: Vector3 = n.dir
	var sea := PlanetConst.SEA_LEVEL_M
	# On basalt: the nest's own ground or the cell beside it.
	var c := map.cell_at(d if v != "organ_pipes" else CreatureSpawner._offset(d, float(n.toward), float(n.face_m)))
	var basalt := map.rock[c] == PlanetData.Rock.BASALT_VOLCANIC
	for k in 8:
		var nb := map.neighbors[c * 8 + k]
		if nb >= 0 and map.rock[nb] == PlanetData.Rock.BASALT_VOLCANIC:
			basalt = true
	ok(basalt, "%s %s on basalt" % [name, n.key])
	if v == "organ_pipes":
		var rm := Nests._river_m(d)
		ok(rm < 30.0, "%s at a river's edge (%.1f m)" % [name, rm])
	else:
		var wet := Nests._e(CreatureSpawner._offset(d, float(n.facing), 20.0)) < sea
		ok(wet, "%s at the sea's edge (the sea within 20 m)" % name)
	# Only the first of each form is built (the meshes are slow headless).
	if built.has(v):
		ok(str(n.state) != "lived" or v != "columned_sea_cave", "%s holds no camp" % name)
		return
	built[v] = true
	var data := NestBuilder.compute_nest(map, n)
	var tris := (data.v as PackedVector3Array).size() / 3
	var ctris := (data.cv as PackedVector3Array).size() / 3
	print("[basalt] %s %s: %d columns, %d triangles (+%d far), %d collision, %d cups" % [name, n.key, int(data.columns), tris, (data.lv as PackedVector3Array).size() / 3, ctris, int(data.cups)])
	ok(tris > 0 and tris < BUDGET, "%s within the triangle budget (%d < %d)" % [name, tris, BUDGET])
	ok(ctris > 0, "%s has collision to walk on (%d triangles)" % [name, ctris])
	var base_e := float(data.base_e)
	var up: Vector3 = data.up
	var ex: Vector3 = data.ex
	var ez: Vector3 = data.ez
	var local := func(p: Vector3) -> Vector3:
		var off := (p - up * p.dot(up)) * PlanetConst.RADIUS_M
		return Vector3(off.dot(ex), 0.0, off.dot(ez))
	var hl: Vector3 = local.call(n.hearth)
	match v:
		"":
			var hg := Nests._e(n.hearth)
			ok(hg >= float(n.high_water_m) + Nests.COLUMN_SPRAY_M, "the causeway's hearth spot above the high water and the spray (%.2f m over the sea; line %.1f + %.1f)" % [hg - sea, Nests.COLUMN_HIGH_WATER_M, Nests.COLUMN_SPRAY_M])
			ok(int(data.cups) >= 10, "the causeway's cups hold water (%d)" % int(data.cups))
			var under := 0
			for p in data.v:
				if (p as Vector3).y + base_e < sea - 0.2:
					under += 1
			ok(under > 0, "the causeway's tops go down under the sea (%d vertices under)" % under)
			ok((n.gives as Array).has("water"), "the causeway can hold a camp (gives water: the cups)")
			ok(FireCircle.kinds_for("ROCKY_SHORE", "coast", "columns") == ["column_top"], "its seats are column tops, whoever lives there")
			print("[basalt] the causeway's state: %s (%s)" % [str(n.state), str(n.get("people", ""))])
		"organ_pipes":
			ok(float(n.cliff_m) >= 10.0 and float(n.cliff_m) <= 40.0, "the organ pipes' cliff 10-40 m (%.1f)" % float(n.cliff_m))
			ok(not (data.falls.v as PackedVector3Array).is_empty(), "the fall pours over the lip (its sheet)")
			ok(not (data.pools as Array).is_empty(), "the pool at the foot")
			var pool: Vector3 = (data.pools as Array)[0][0]
			var dp := Vector2(hl.x - pool.x, hl.z - pool.z).length()
			ok(dp > 4.0 and dp < 12.0, "the hearth at the foot by the pool, out of the spray (%.1f m from it)" % dp)
			ok(hl.z > -float(n.face_m), "the hearth stands in front of the face (z %.1f, face %.1f)" % [hl.z, -float(n.face_m)])
			ok(not (data.roar as Array).is_empty(), "the fall roars (a waterfall source)")
		"columned_sea_cave":
			ok(str(n.state) == "untouched" and str(n.get("raw_state", n.state)) == "untouched", "the sea cave holds no camp and no remains (%s)" % str(n.state))
			ok(not (n.gives as Array).has("water") and not (n.gives as Array).has("roof"), "the sea cave gives no camp water nor roof")
			# The clifftop at the hearth: the highest top within 1 m of it.
			var top := -INF
			var under_roof := 0
			var vs: PackedVector3Array = data.v
			var ns: PackedVector3Array = data.n
			for i in vs.size():
				var p := vs[i]
				if Vector2(p.x - hl.x, p.z - hl.z).length() < 1.0:
					top = maxf(top, p.y)
				if ns[i].y < -0.9 and p.y + base_e > sea + 3.0:
					under_roof += 1
			ok(top + base_e > sea + 6.0, "the sea cave's hearth spot on the clifftop (%.1f m over the sea)" % (top + base_e - sea))
			ok(hl.z < float(n.back_m) + 1.0, "the hearth over the cave's back, not its mouth (z %.1f, back %.1f)" % [hl.z, float(n.back_m)])
			ok(under_roof > 30, "a roof of column undersides (%d downward faces over the water)" % under_roof)
			var den: Vector3 = data.den
			var boom: Vector3 = data.boom
			ok(den != Vector3.INF and den.y + base_e > sea + 0.5, "the den on the ledge at the back (%.1f m over the sea)" % (den.y + base_e - sea if den != Vector3.INF else -1.0))
			ok(boom != Vector3.INF, "the boom's source at the cave's back")
			var sea_below := Nests._e(CreatureSpawner._offset(d, float(n.facing), float(n.reach_m) * 0.6)) < sea - 0.5
			ok(sea_below, "the sea runs in under the cave")
			var who := Overrun.cave_sleeper(map, d, str(n.key))
			print("[basalt] the sea cave's den holds: %s" % (str(who.creature) if str(who.creature) != "" else "nothing (empty)"))
			var sp := CreatureSpecies.find(str(who.creature)) if str(who.creature) != "" else null
			ok(sp == null or not sp.role in ["canopy", "swarm", "mythical"], "the sleeper is something that would den in a sea cave (%s)" % str(who.creature))
