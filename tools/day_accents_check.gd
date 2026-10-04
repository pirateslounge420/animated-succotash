extends SceneTree
## Butterflies by day (design 3 Oct §DC, data/day_accents.json,
## DayAccents), headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/day_accents_check.gd
##  - a warm meadow (the prairie, 22 °C, a light air) at noon: 2-6
##    butterflies within 30 m;
##  - the same meadow at 02:00: none;
##  - a snowfield (a glacier or ice sheet) at noon: none;
##  - a closed jungle floor (sky visibility 0.1 at every flower): none;
##  - the wind at 8 m/s: every one on the ground, still;
##  - their material has no emission and they cast no shadow or light.

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
	for i in 10:
		await process_frame
	var da: DayAccents = main.day_accents
	var B := DayAccents.B()
	var cr: Array = B.get("count", [2, 6])
	var range_m := float(B.get("range_m", 30.0))

	# --- A warm meadow at noon. ---
	# A meadow with flowers: grassland cells nearest the camp, tried until
	# one has herbs or shrubs in the sun (some grasslands carry no plant
	# instances at all, only the ground's own grass).
	var meadow := Vector3.ZERO
	var tried: Array = []
	for d in _cells_of(["WET_MEADOW", "TALLGRASS_PRAIRIE", "ALPINE_MEADOW", "SHORTGRASS_PRAIRIE", "STEPPE"], 10):
		await _stand_at(d)
		await _detail()
		await _hour(d, 12.0)
		da.override = {"temp_c": 22.0, "wind_mps": 1.0, "snow": false}
		da.clear()
		da.refresh(da.gather())
		tried.append("%s %d" % [FireStore.biome_key(world, d), int(da.gate_state.get("flowers", 0))])
		if not da.flies.is_empty():
			meadow = d
			break
	print("   meadows tried (flowers in the sun): %s" % ", ".join(tried))
	if meadow != Vector3.ZERO:
		print("   the meadow: AT=%.3f,%.3f" % [rad_to_deg(CubeSphere.latitude(meadow)), rad_to_deg(CubeSphere.longitude(meadow))])
	ok(meadow != Vector3.ZERO, "a meadow with flowers on this planet")
	for i in 30:
		await process_frame
	var near := 0
	for f in da.flies:
		if da.to_global(f.pos).distance_to(main.player.global_position) <= range_m + 3.0:
			near += 1
	ok(da.flies.size() >= int(cr[0]) and da.flies.size() <= int(cr[1]) and near == da.flies.size(), "a warm meadow at noon (%s): %d butterflies, %d within %.0f m (%d flowers in the sun; %s)" % [FireStore.biome_key(world, meadow), da.flies.size(), near, range_m, int(da.gate_state.get("flowers", 0)), da.gate_state.get("why", "")])
	var flying := 0
	for f in da.flies:
		if float(f.speed) > 0.05:
			flying += 1
	ok(flying > 0, "they fly in a light air (%d of %d moving)" % [flying, da.flies.size()])
	# --- The wind at 8 m/s: down in the grass. ---
	da.override = {"temp_c": 22.0, "wind_mps": 8.0, "snow": false}
	da.refresh(da.gather())
	for i in 120:
		await process_frame
	var still := 0
	var low := 0
	var up: Vector3 = main.player.global_basis.y.normalized()
	for f in da.flies:
		if float(f.speed) < 0.001:
			still += 1
		var fl: Vector3 = da.to_global(f.flower)
		if (da.to_global(f.pos) - fl).dot(up) < 0.1:
			low += 1
	ok(da.flies.size() > 0 and still == da.flies.size() and low == da.flies.size(), "the wind at 8 m/s: %d of %d on the ground, %d still" % [low, da.flies.size(), still])
	# --- The same meadow at 02:00. ---
	await _hour(meadow, 2.0)
	da.override = {"temp_c": 22.0, "wind_mps": 1.0, "snow": false}
	da.refresh(da.gather())
	ok(da.flies.is_empty(), "the same meadow at 02:00: %d (%s)" % [da.flies.size(), da.gate_state.get("why", "")])
	# --- A closed jungle floor. ---
	await _hour(meadow, 12.0)
	da.override = {"temp_c": 26.0, "wind_mps": 1.0, "snow": false, "visibility": 0.1}
	da.clear()
	da.refresh(da.gather())
	ok(da.flies.is_empty(), "under closed crowns (sky visibility 0.1): %d (%s)" % [da.flies.size(), da.gate_state.get("why", "")])
	# --- A snowfield at noon. ---
	var snow := _cell_of(["GLACIER", "ICE_SHEET"])
	if snow == Vector3.ZERO:
		ok(true, "a snowfield: none on this planet (skipped)")
	else:
		da.override = {}
		await _stand_at(snow)
		await _hour(snow, 12.0)
		da.clear()
		da.refresh(da.gather())
		ok(da.flies.is_empty(), "a snowfield at noon (%s): %d (%s)" % [FireStore.biome_key(world, snow), da.flies.size(), da.gate_state.get("why", "")])
	# --- The material. ---
	var m: StandardMaterial3D = da._mat
	ok(not m.emission_enabled and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL, "their material has no emission and is lit by the scene (they give off no light, R8)")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Up to `n` land cells of `keys`, nearest the camp first, spread out (no
## two within 2 km).
func _cells_of(keys: Array, n: int) -> Array:
	var map: PlanetData = world.planet
	var ids := keys.map(func(k): return BiomeTemplates.id_of_key(str(k)))
	var camp: Vector3 = main.camp.site
	var all: Array = []
	for c in map.cell_count:
		if map.water[c] == PlanetData.Water.NONE and ids.has(map.biome[c]):
			all.append(map.dir[c])
	all.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.dot(camp) > b.dot(camp))
	var out: Array = []
	for d in all:
		if out.all(func(o: Vector3) -> bool: return CubeSphere.surface_distance_m(o, d) > 2000.0):
			out.append(d)
		if out.size() >= n:
			break
	return out


## The land cell of one of `keys` nearest the camp, or ZERO.
func _cell_of(keys: Array) -> Vector3:
	var map: PlanetData = world.planet
	var ids := keys.map(func(k): return BiomeTemplates.id_of_key(str(k)))
	var camp: Vector3 = main.camp.site
	var best := Vector3.ZERO
	for c in map.cell_count:
		if map.water[c] == PlanetData.Water.NONE and ids.has(map.biome[c]):
			if best == Vector3.ZERO or map.dir[c].dot(camp) > best.dot(camp):
				best = map.dir[c]
	return best


func _stand_at(d: Vector3) -> void:
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	main.player.global_position -= off
	main.chunks.load_blocking(d)
	main.player.spawn_at(d, CreatureSpawner._offset(d, 0.0, 10.0))
	for i in 20:
		await process_frame


## Wait for the near plants (the detail layer) round you.
func _detail() -> void:
	var ck: Vector3i = TerrainChunk.key_at(main.player.surface_dir)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		var c: TerrainChunk = main.chunks.chunks.get(ck, null)
		if c != null and c.detail_node != null and c.detail_node.get_child_count() > 0:
			return
		await process_frame


func _hour(d: Vector3, h: float) -> void:
	world.days = Astro.days_at_solar_hour(world.days, h, CubeSphere.longitude(d), CubeSphere.latitude(d))
	for i in 6:
		await process_frame
