extends SceneTree
## Where mist lies (MistPlaces; Mike, 5 Oct), headless, full planet:
##   SEED=7731 godot --headless --path . --script tools/mist_check.gd
## Samples land points over the planet and asserts that mist is a place
## thing, not everywhere: most dry open ground holds little, wet country
## and the ground by water hold a lot.

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
	var rivers := Encampment.rivers_for(map)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var dry: Array = []
	var wet: Array = []
	var all: Array = []
	while all.size() < 1500:
		var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var c := map.cell_at(d)
		if map.water[c] != PlanetData.Water.NONE:
			continue
		var g := map.terrain.elevation(d, true)
		var sum := g
		for k in 16:
			sum += map.terrain.elevation(CreatureSpawner._offset(d, TAU * k / 16.0, 250.0), true)
		var s := MistPlaces.share(map, rivers, d, g, sum / 17.0)
		all.append(s)
		var key: String = BiomeTemplates.KEYS[map.biome[c]]
		if key in ["HOT_DESERT", "COLD_DESERT", "DUNES", "STEPPE", "SHORTGRASS_PRAIRIE", "SAVANNA", "THORN_SCRUB"]:
			dry.append(s)
		elif MistPlaces.WET_BIOMES.has(key):
			wet.append(s)
	var mean := func(a: Array) -> float:
		var t := 0.0
		for v in a:
			t += float(v)
		return t / maxf(a.size(), 1)
	var low := all.filter(func(v): return float(v) < 0.3).size()
	print("[mist] land points %d · mean share %.2f · under 0.3: %d%% · dry country %.2f (%d) · wet country %.2f (%d)" % [all.size(), mean.call(all), 100 * low / all.size(), mean.call(dry), dry.size(), mean.call(wet), wet.size()])
	ok(low > all.size() * 0.35, "mist is a place thing: over a third of the land holds little (%d%%)" % (100 * low / all.size()))
	ok(mean.call(dry) < 0.3, "dry open country holds little (%.2f)" % mean.call(dry))
	ok(wet.is_empty() or mean.call(wet) > 0.6, "wet country holds it (%.2f)" % mean.call(wet))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
