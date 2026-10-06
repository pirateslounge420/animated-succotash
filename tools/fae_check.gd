extends SceneTree
## Beast heads, the empty hood, fairy rings and the fae (design 5 Oct
## §EO.1–§EO.5), headless:
##   STAMP=1 SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/fae_check.gd
##  - every zodiac animal has a head that fits in the hood (its snout at
##    most a few cm past the brim); every people is one of them; the dragon
##    is no people's and comes at about rare.dragon.chance_per_camp of
##    camps; the small folk keep the empty hood;
##  - the player's hood stays empty, even when asked to wear a head;
##  - every camp's folk wear its beast; the face fades into the hollow
##    between look.near_m and gone_m;
##  - rings: about chance_per_chunk of the loaded chunks hold one, none in
##    water; each a ring of mushrooms within its counts;
##  - sitting (crouched, still) inside a ring: nothing before
##    sit_seconds_min, then three uncloaked, glowing, lit fae shedding
##    specks; at trust 0 a flicker far off that leaves after stay_s[0];
##    trust grows once per grows_every_game_h, and the next visit comes
##    closer; standing up while they are out scatters them;
##  - the band: day fae with the sun up, night fae with it down and the
##    moon lit enough;
##  - the gifts are stubs (false).

var fails := 0
var world
var main
var F: Dictionary


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := DirAccess.open("user://worlds")
	if dir:
		for f in dir.get_files():
			dir.remove(f)
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	for i in 120:
		await physics_frame
	F = Tuning.table("fae")
	print("[fae] seed %d" % seed_v)
	_heads()
	await _camp_heads()
	_rings()
	await _sit()
	_bands()
	ok(not FaeRings.gift_light("v", world.days) and not FaeRings.lead_to_lair("v"), "the gifts (§EO.5) are stubs: no light given, no lair led to")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _heads() -> void:
	var Z: Dictionary = Tuning.table("zodiac_heads")
	var heads: Dictionary = Z.get("heads", {})
	ok(heads.size() == 12, "twelve zodiac animals (%d)" % heads.size())
	var bad: Array = []
	for a in heads:
		var m := BeastHeads.mesh(str(a))
		if m == null or int(m.get_meta("tris", 0)) <= 0:
			bad.append([a, "no mesh"])
			continue
		var bb := m.get_aabb()
		if bb.position.x < -0.125 or bb.end.x > 0.125 or bb.position.y < -0.03 or bb.end.y > 0.23 or bb.position.z < -0.195 or bb.end.z > 0.13:
			bad.append([a, bb])
	ok(bad.is_empty(), "every head fits under the hood, its snout at most 6.5 cm past the brim %s" % str(bad))
	var peoples: Array = []
	for f in DirAccess.get_files_at("res://data/peoples"):
		if f.ends_with(".json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/peoples/" + f))
			if d is Dictionary and d.has("id") and d.has("name"):
				peoples.append(str(d.id))
	var unmapped := peoples.filter(func(p): return not heads.has(BeastHeads.of_people(p)))
	ok(peoples.size() >= 17 and unmapped.is_empty(), "every people (%d) is one of the animals %s" % [peoples.size(), str(unmapped)])
	var used := {}
	for p in peoples:
		used[BeastHeads.of_people(p)] = true
	ok(not used.has("dragon") and used.size() == 11, "the dragon is no people's; the other eleven all are someone's (%d)" % used.size())
	var dragons := 0
	for s in 4000:
		if BeastHeads.for_camp("river", s, "human") == "dragon":
			dragons += 1
	var want := float(((Z.get("rare", {}) as Dictionary).get("dragon", {}) as Dictionary).get("chance_per_camp", 0.03))
	ok(absf(dragons / 4000.0 - want) < want * 0.35 + 0.002, "the dragon tribe at about %.3f of camps (%.4f)" % [want, dragons / 4000.0])
	ok(BeastHeads.for_camp("river", 1, "small_folk") == "" and BeastHeads.for_camp("river", 1, "human", false) == "rat", "the small folk keep the empty hood; the opening camp is never the dragon")


func _camp_heads() -> void:
	# The player: always the empty hood (§EO.2).
	var pb: PlayerBody = null
	for c in main.player.find_children("*", "PlayerBody", true, false):
		pb = c
	if pb != null:
		pb.set_beast("ox")
		ok(pb.is_player and pb.beast == "" and pb.head.get_node_or_null("Beast") == null, "the player's hood stays empty, even asked to wear the ox")
	else:
		ok(false, "the player's body found")
	# A camp's folk, built now.
	var at: Vector3 = main.player.global_position + main.player.global_basis.z * 30.0
	var d: Vector3 = world.dir_of(at)
	var root: Node3D = main.camps._build(world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d)), "tribal", 4242, "faecheck")
	for i in 3:
		await process_frame
	var want := str(root.get_meta("beast", ""))
	var bodies: Array = root.find_children("*", "PlayerBody", true, false)
	var wearing := bodies.filter(func(b): return (b as PlayerBody).beast == want)
	print("  a %s camp (%s): %d folk, %d wearing the %s" % [root.get_meta("people", ""), root.get_meta("kind", ""), bodies.size(), wearing.size(), want])
	ok(want != "" and bodies.size() > 0 and wearing.size() == bodies.size(), "every folk of a camp wears its beast")
	root.queue_free()
	# The opening camp.
	var ob: Array = main.camp.dressing.find_children("*", "PlayerBody", true, false) if main.camp.dressing != null else []
	var ow := str(main.camp.dressing.get_meta("beast", "")) if main.camp.dressing != null else ""
	ok(ow == BeastHeads.of_people(main.camp.people_id) and ob.size() > 0 and ob.all(func(b): return (b as PlayerBody).beast == ow), "the opening camp's %d folk wear the %s (%s)" % [ob.size(), ow, main.camp.people_id])
	var m := BeastHeads.material()
	var L: Dictionary = Tuning.table("zodiac_heads").get("look", {})
	ok(is_equal_approx(float(m.get_shader_parameter("near_m")), float(L.get("near_m", 4.0))) and is_equal_approx(float(m.get_shader_parameter("gone_m")), float(L.get("gone_m", 8.0))), "the face shows within %.0f m and is the hood's hollow past %.0f m" % [float(L.get("near_m", 4.0)), float(L.get("gone_m", 8.0))])


func _rings() -> void:
	var fr: FaeRings = main.fae_rings
	var seed_v := int(world.planet.terrain.world_seed)
	var n := 0
	var wet := 0
	var counts_bad := 0
	# The chunks round the player out to about 3 km (their middles from
	# the terrain function where they are not loaded).
	var keys := {}
	var pd: Vector3 = world.dir_of(main.player.global_position)
	for i in 30:
		for j in 30:
			var q := CreatureSpawner._offset(CreatureSpawner._offset(pd, 0.0, (i - 15) * TerrainChunk.CHUNK_M * 0.5), PI * 0.5, (j - 15) * TerrainChunk.CHUNK_M * 0.5)
			var k := TerrainChunk.key_at(q)
			if not keys.has(k):
				keys[k] = q
	for key in keys:
		var c: TerrainChunk = main.chunks.chunks.get(key)
		var s := FaeRings.spec_for(seed_v, key, c.center_dir if c != null else keys[key], main.chunks)
		if s.is_empty():
			continue
		n += 1
		if main.chunks.water_level_at(s.dir) > main.chunks.ground_height(s.dir) - 0.05:
			wet += 1
		var mm: Array = (F.get("ring_look", {}) as Dictionary).get("mushrooms", [11, 19])
		if int(s.n) < int(mm[0]) or int(s.n) > int(mm[1]):
			counts_bad += 1
	var share := n / float(maxi(keys.size(), 1))
	var chance := float((F.get("ring_look", {}) as Dictionary).get("chance_per_chunk", 0.12))
	print("  %d rings in %d chunks round the player (%.3f; chance %.2f, less the wet and steep: dropped %s)" % [n, keys.size(), share, chance, str(FaeRings.dropped)])
	var rolled := (n + int(FaeRings.dropped.wet) + int(FaeRings.dropped.steep)) / float(maxi(keys.size(), 1))
	ok(rolled > chance * 0.5 and rolled < chance * 1.5 and share <= rolled, "a ring is rolled in about chance_per_chunk of the chunks (%.3f), and kept only dry and flat (%.3f)" % [rolled, share])
	ok(wet == 0 and counts_bad == 0, "no ring in water; every ring's mushroom count in range")
	# Rings are built near the player.
	fr._refresh()
	var built := 0
	var tris := 0
	for id in fr.rings:
		built += 1
		tris = maxi(tris, int((fr.rings[id] as Node).get_meta("tris", 0)))
	print("  %d rings built within %.0f m; the biggest %d triangles" % [built, FaeRings.VIEW_M, tris])
	ok(built == 0 or tris < 3000, "a ring is one cheap mesh (%d triangles)" % tris)
	ok(Mushroom != null and _test_ring(fr) != null, "a mushroom ring builds where asked")


## A ring 6 m ahead of the player, a night ring, registered for the sit
## test.
func _test_ring(fr: FaeRings) -> Node3D:
	if fr.rings.has("test"):
		return fr.rings["test"]
	var p: Vector3 = main.player.global_position - main.player.global_basis.z * 6.0
	var s := {"id": "test", "dir": world.dir_of(p), "radius": 2.0, "n": 14, "cap": Color("#C8B08A"), "band": "night", "seed": 99}
	var n := FaeRings.build_ring(fr._root, s, world, main.chunks)
	fr.rings["test"] = n
	return n


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


func _sit() -> void:
	var fr: FaeRings = main.fae_rings
	var ring := _test_ring(fr)
	var s: Dictionary = ring.get_meta("spec")
	FaeRings.force_band = "any"
	fr._timer = 1.0e9 # (no refresh: the test ring stays)
	main.player.spawn_at(s.dir)
	await _wait(1.5)
	var sit_min := float((F.get("rings", {}) as Dictionary).get("sit_seconds_min", 10))
	Input.action_press("crouch")
	await _wait(sit_min - 1.0)
	ok(fr.visit.is_empty() and fr.sit_t > sit_min - 2.0, "sitting in the ring %.1f s: no fae yet (sitting %.1f s)" % [sit_min - 1.0, fr.sit_t])
	await _wait(1.5)
	ok(not fr.visit.is_empty() and (fr.visit.figs as Array).size() == 3, "after %.0f s three fae come" % sit_min)
	if fr.visit.is_empty():
		Input.action_release("crouch")
		return
	await _wait(0.5)
	var figs: Array = fr.visit.figs
	var lit := figs.all(func(f): return ((f as Node3D).get_meta("light") as OmniLight3D).light_energy > 0.05)
	var specks := figs.all(func(f): return ((f as Node3D).get_meta("specks") as CPUParticles3D).emitting)
	var cloaks := (fr.visit.node as Node).find_children("*", "PlayerBody", true, false).size()
	var glow := figs.all(func(f): return (f as Node3D).find_children("*", "MeshInstance3D", true, false).any(func(m): return (m as MeshInstance3D).material_override is StandardMaterial3D and ((m as MeshInstance3D).material_override as StandardMaterial3D).emission_enabled))
	ok(lit and specks and glow and cloaks == 0, "they glow, light the ground and shed specks, and wear no cloak")
	var T: Dictionary = F.get("trust", {})
	var r0 := float(fr.visit.r)
	var far0: float = (figs[0] as Node3D).position.length()
	ok(int(fr.visit.trust) == 0 and is_equal_approx(r0, float(T.get("far_m", 9.0))) and far0 > float(T.get("far_m", 9.0)) * 0.7, "the first time, a flicker far off (%.1f m)" % far0)
	await _wait(float((T.get("stay_s", [4.0, 45.0]) as Array)[0]) + 1.5)
	ok(fr.visit.is_empty(), "and gone again after stay_s[0]")
	ok(FaeRings.trust_of("test") == 1, "the ring's trust is 1 now (%d)" % FaeRings.trust_of("test"))
	# Sit again at once: they come, but the trust holds (once per grows_every_game_h).
	Input.action_release("crouch")
	await _wait(0.5)
	Input.action_press("crouch")
	await _wait(sit_min + 0.5)
	ok(not fr.visit.is_empty() and FaeRings.trust_of("test") == 1, "sitting again at once they come again, the trust unchanged")
	# Stand up while they are out: they scatter.
	Input.action_release("crouch")
	await _wait(0.2)
	ok(not fr.visit.is_empty() and bool(fr.visit.leaving) and bool(fr.visit.scatter), "standing up while they are out scatters them")
	await _wait(1.0)
	ok(fr.visit.is_empty(), "scattered, gone in a moment")
	# Later (past the cooldown), a closer visit.
	world.days += float(T.get("grows_every_game_h", 2.0)) / 24.0 + 0.01
	Input.action_press("crouch")
	await _wait(sit_min + 0.5)
	var r1 := float(fr.visit.get("r", 0.0)) if not fr.visit.is_empty() else 0.0
	ok(not fr.visit.is_empty() and int(fr.visit.trust) == 1 and r1 < r0 and FaeRings.trust_of("test") == 2, "a later visit comes closer (%.1f m, was %.1f m) and the trust is 2" % [r1, r0])
	Input.action_release("crouch")
	await _wait(1.5)
	FaeRings.force_band = ""


func _bands() -> void:
	var fr: FaeRings = main.fae_rings
	var up: Vector3 = main.player.up
	var day: bool = main.sky.sun_dir.dot(up) > 0.0
	var lit := Astro.moon_illumination(world.days)
	var min_lit := float((F.get("bands", {}) as Dictionary).get("night_moon_min_lit", 0.25))
	ok(fr.band_open({"band": "day"}) == day and fr.band_open({"band": "night"}) == (not day and lit >= min_lit), "day fae with the sun up, night fae with it down and the moon %.2f lit (sun %s)" % [lit, "up" if day else "down"])
