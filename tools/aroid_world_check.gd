extends SceneTree
## The aroids living their cycles in the running game (AroidGarden,
## docs/design/AROID_LIFE.md): finds Amorphophallus near a tropical spot,
## then moves the clock through their year and checks what's drawn: the
## leaf hidden while the tuber rests, spikes, buds, blooms with their
## parts, pollen in the male phase, berries; the pollinators a bloom draws;
## the smell on the wind; a real cross between two plants in bloom; the
## HUD's name with the stage; berries as a sample. Also counts sports among
## all the plants placed round there.
##
##   STAMP=1 godot --headless --path . --fixed-fps 60 --script tools/aroid_world_check.gd

var main
var world
var fails := 0
var notes: Array[String] = []


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func goto(d: Vector3) -> void:
	var offset: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d) + 2.0)
	world.rebase(offset)
	main.player.global_position -= offset
	main.chunks.load_blocking(d)
	main.player.spawn_at(d)
	for k in 400:
		await process_frame
		if k > 60 and main.chunks._pending.is_empty():
			break


func _run() -> void:
	world = get_root().get_node("World")
	world.spawn_choice = 0
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	await frames(30)
	var garden: AroidGarden = main.aroid_garden
	ok(garden != null, "the game has an AroidGarden")
	garden.say = func(t: String) -> void: notes.append(t)
	# Somewhere with Amorphophallus: tropical forest and savanna cells.
	var map: PlanetData = world.planet
	var want := [BiomeTemplates.TROPICAL_RAINFOREST, BiomeTemplates.JUNGLE, BiomeTemplates.TROPICAL_DRY_FOREST, BiomeTemplates.SAVANNA]
	var cands: Array = []
	for c in map.biome.size():
		if map.biome[c] in want:
			cands.append(c)
	cands.shuffle()
	ok(cands.size() > 0, "the planet has tropical cells (%d)" % cands.size())
	var found := false
	for tries in mini(cands.size(), 25):
		var d: Vector3 = map.dir[cands[tries]]
		await goto(d)
		garden._scan()
		if not garden._entries.is_empty():
			found = true
			print("      aroids at %s after %d tries" % [str(d), tries + 1])
			break
	ok(found, "found Amorphophallus growing somewhere tropical")
	if not found:
		print("RESULT fails: %d" % fails)
		quit()
		return
	var names := {}
	var total := 0
	for id in garden._entries:
		var e: Dictionary = garden._entries[id]
		names[e.sp.name] = int(names.get(e.sp.name, 0)) + int(e.n)
		total += int(e.n)
	print("      %d plants: %s" % [total, str(names)])
	garden.update_now()
	# The year: step the clock a fortnight at a time over two years.
	var start: float = world.days
	var leaf_seen := 0
	var dormant_seen := 0
	var hidden_ok := true
	var shoot := 0
	var bud := 0
	var bloom := 0
	var fruit := 0
	var spathes := 0
	var spikes := 0
	for step in 52:
		world.days = start + step * 14.0
		garden.update_now()
		for id in garden._entries:
			var e: Dictionary = garden._entries[id]
			var buf: PackedFloat32Array = e.mmi.multimesh.buffer
			for i in int(e.n):
				var st: Dictionary = e.states[i]
				match str(st.leaf):
					"leaf":
						leaf_seen += 1
					"dormant":
						dormant_seen += 1
						var h := Vector3(buf[i * 20 + 1], buf[i * 20 + 5], buf[i * 20 + 9]).length()
						if h > 0.05:
							hidden_ok = false
					"shoot":
						shoot += 1
				match str(st.flower):
					"bud":
						bud += 1
					"bloom":
						bloom += 1
					"fruit":
						fruit += 1
			spathes += (e.parts.spathe as MultiMeshInstance3D).multimesh.instance_count
			spikes += (e.parts.spike as MultiMeshInstance3D).multimesh.instance_count
	print("      over two years: leaf %d, dormant %d, shoot %d, bud %d, bloom %d, fruit %d (plant-fortnights)" % [leaf_seen, dormant_seen, shoot, bud, bloom, fruit])
	ok(leaf_seen > 0 and dormant_seen > 0, "they're in leaf part of the year and rest underground part of it")
	ok(hidden_ok, "a resting plant's leaf isn't drawn (scaled away in its MultiMesh)")
	ok(shoot > 0, "shoots come up")
	ok(spikes > 0, "the shoot spikes are drawn")
	ok(bud + bloom + fruit > 0, "some bud, bloom or fruit in two years")
	# A bloom now: find one plant's next bloom and go there.
	var target := {}
	var ti := -1
	var tday := -1.0
	for id in garden._entries:
		var e: Dictionary = garden._entries[id]
		for i in int(e.n):
			for dd in range(0, 365 * 6, 1):
				var st := AroidLife.state(e.sp, e.keys[i], e.lat[i], e.lon[i], start + dd)
				if st.flower == "bloom":
					target = e
					ti = i
					tday = start + dd + 0.02
					break
			if ti >= 0:
				break
		if ti >= 0:
			break
	ok(ti >= 0, "a plant here blooms within six years")
	if ti >= 0:
		world.days = tday
		garden.update_now()
		var st0: Dictionary = target.states[ti]
		ok(st0.flower == "bloom", "on that day it's in bloom (%s, %.1f h open)" % [target.sp.name, float(st0.open_h)])
		ok((target.parts.spathe as MultiMeshInstance3D).multimesh.instance_count > 0, "its spathe is drawn")
		ok((target.parts.appendix as MultiMeshInstance3D).multimesh.instance_count > 0, "and its appendix")
		# Stand by it: the pollinators come, the smell carries.
		var xf: Transform3D = target.mmi.global_transform
		var base: PackedFloat32Array = target.base
		var p := xf * Vector3(base[ti * 20 + 3], base[ti * 20 + 7], base[ti * 20 + 11])
		var pd: Vector3 = world.dir_of(p)
		main.player.spawn_at(CubeSphere.north(pd).rotated(pd, 0.3) * 0.0 + (pd + CubeSphere.east(pd) * (4.0 / PlanetConst.RADIUS_M)).normalized())
		await frames(5)
		garden.update_now()
		var kind := str(target.sp.cycle.bloom.scent)
		if st0.open_h < float(target.sp.cycle.bloom.female_hours[1]) + 10.0:
			ok(garden._swarms.size() > 0, "its pollinators come (%s)" % str(target.sp.cycle.bloom.pollinators))
			if kind != "none":
				ok(notes.size() > 0, "and you smell it: \"%s\"" % (notes[0] if notes.size() > 0 else ""))
		# The HUD's name for it.
		var stage := AroidGarden.describe(target.mmi.get_instance_id(), ti)
		ok(stage.begins_with("in bloom"), "the HUD says where it is in its life (\"%s\")" % stage)
		ok(LookTarget.decorate("Amorphophallus x\nx · y", 2, "in bloom").ends_with("variegated sport · in bloom"), "a name with a sport and a stage")
		# The male phase: pollen.
		var bl: Dictionary = target.sp.cycle.bloom
		world.days = float(st0.open_day) + float(bl.male_after_hours[1]) / 24.0 + 0.05
		garden.update_now()
		var st1: Dictionary = target.states[ti]
		if st1.flower == "bloom":
			ok(st1.male and (target.parts.pollen as MultiMeshInstance3D).multimesh.instance_count > 0, "a day on, the pollen is out")
		# A real cross: a second plant of the kind in bloom as this one is
		# receptive.
		var other := -1
		for i in int(target.n):
			if i != ti and target.clumps[i] != target.clumps[ti]:
				other = i
				break
		if other >= 0:
			var fake_b := {"flower": "bloom", "male": true, "female": false, "event": 0, "open_h": 30.0}
			var fake_a := st0.duplicate()
			fake_a.female = true
			var pa := p
			var pb := xf * Vector3(base[other * 20 + 3], base[other * 20 + 7], base[other * 20 + 11])
			garden._donors.clear()
			garden._cross([[target, ti, fake_a, pa], [target, other, fake_b, pb]])
			ok(garden._donors.has(target.keys[ti]), "two plants in bloom together: a real cross")
			# In fruit: the berries carry the cross.
			var bud_d := float(target.sp.cycle.fruit.ripen_days[0])
			world.days = float(st0.open_day) + float(bl.open_days[1]) + bud_d * 0.9
			garden.update_now()
			var st2: Dictionary = target.states[ti]
			ok(st2.flower == "fruit", "it sets fruit")
			ok((target.parts.berries as MultiMeshInstance3D).multimesh.instance_count > 0, "the berries are drawn")
			var ex := garden.sample_extra(SpeciesDB.index_of(target.sp), p)
			ok(ex.get("part", "") == "berries" and ex.has("seed") and str(ex.get("cross", "")).contains("seen"), "taking a sample gives berries with the cross: %s -> %s" % [ex.get("cross", ""), ex.get("seed", "")])
	# Sports among everything placed round here.
	var n_all := 0
	var n_sport := 0
	var kinds := {}
	for c in main.chunks.chunks.values():
		var chunk := c as TerrainChunk
		if chunk == null:
			continue
		var stack: Array = [chunk]
		if chunk.detail_node != null:
			stack.append(chunk.detail_node)
		for parent in stack:
			for ch in (parent as Node).get_children():
				var mmi := ch as MultiMeshInstance3D
				if mmi == null or not mmi.has_meta("species") or mmi.multimesh == null:
					continue
				var b := mmi.multimesh.buffer
				for i in mmi.multimesh.instance_count:
					n_all += 1
					var s := PlantGenetics.decode_sport(b[i * 20 + 16])
					if s > 0:
						n_sport += 1
						kinds[PlantGenetics.kind_of(s)] = int(kinds.get(PlantGenetics.kind_of(s), 0)) + 1
					var moss := b[i * 20 + 16] - 2.0 * s
					if moss < -0.001 or moss > 1.001:
						ok(false, "moss stays 0-1 under the sport code")
						break
	print("      sports: %d of %d plants round here: %s" % [n_sport, n_all, str(kinds)])
	ok(n_all > 0, "plants placed round here (%d)" % n_all)
	print("RESULT fails: %d" % fails)
	quit()
