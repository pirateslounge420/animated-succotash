class_name DevSpawn
extends Node
## The Phase 1 dev spawn key (spec Phase 1: "All rigs are testable on the
## stamp via a dev spawn key; nothing spawns in normal play until Phase
## 7"; agreed at Go: F7, the "dev_spawn" action). In dev mode only
## (data/dev.json) each press spawns the next rig beside the player, in
## turn:
##   Night Rider pair  NightRiderPair.debug_spawn(): riding across your
##                     view ~30 m ahead (the pair before rides off)
##   Pond Crawler      PondCrawler.debug_spawn(), in the nearest water it
##                     can wade within POOL_M (nearest_pool())
##   Gibbon            Gibbon.debug_spawn(), on the nearest wood it can
##                     hang from of a rainforest tree within GIBBON_M (the
##                     trees within ChunkManager.GRAPH_M have branch graphs)
## and prints what it spawned, or why it couldn't ("no rainforest trees
## within 200 m"). A rig that can't be placed doesn't stall the cycle: the
## next press goes on to the next rig. A new crawler or gibbon replaces
## the last one this key made. Main adds this node only in dev mode, and
## it checks again, so nothing spawns in normal play.
##
## Reads World (dev mode, planet), the chunks (water, ground), the branch
## graphs (BranchGraphs), the player; writes only the rigs it spawns.

const RIGS := ["night_riders", "pond_crawler", "gibbon"]
## How far to look for water to put a crawler in (m), on this grid (m).
const POOL_M := 120.0
const POOL_STEP_M := 3.0
## How far to look for a tree to hang a gibbon on (m).
const GIBBON_M := 200.0
## The gibbon's trees: the rainforest (spec R3's warm-wet band).
const GIBBON_BIOMES := ["TROPICAL_RAINFOREST", "JUNGLE"]

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var mythics: Mythics
var creatures: CreatureSpawner
## The rig the next press spawns (index into RIGS).
var next := 0

var _crawler: PondCrawler
var _gibbon: Gibbon


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer, p_mythics: Mythics, p_creatures: CreatureSpawner) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	mythics = p_mythics
	creatures = p_creatures
	# The gibbon's body builds now on a worker, so its F7 doesn't wait.
	GibbonBody.prewarm()


func _unhandled_input(event: InputEvent) -> void:
	if world == null or not world.dev_mode:
		return
	if event.is_action_pressed("dev_spawn") and not event.is_echo():
		get_viewport().set_input_as_handled()
		spawn_next()


## Spawn the next rig; returns what it printed.
func spawn_next() -> String:
	if not world.dev_mode:
		return ""
	var kind: String = RIGS[next]
	next = (next + 1) % RIGS.size()
	var line := ""
	match kind:
		"night_riders":
			line = _night_riders()
		"pond_crawler":
			line = _pond_crawler()
		"gibbon":
			line = _gibbon_spawn()
	print("[F7] ", line)
	return line


func _night_riders() -> String:
	if CreatureSpecies.find("Night rider") == null:
		return "no Night Rider pair: no \"Night rider\" in creatures.json"
	for pair in mythics.pairs:
		pair.dismiss()
	var pair := NightRiderPair.debug_spawn(mythics, player.surface_dir, -player.camera().global_basis.z)
	if pair == null or pair.riders.is_empty():
		return "no Night Rider pair: it couldn't be placed"
	return "Night Rider pair, %.0f m off, riding across your view" % pair.riders[0].distance_to(player.surface_dir)


func _pond_crawler() -> String:
	var sp := CreatureSpecies.find("Pond Crawler")
	if sp == null:
		return "no Pond Crawler: no \"Pond Crawler\" in creatures.json"
	var rw: Array = sp.data.get("rig", {}).get("wade_m", [0.08, 1.3])
	var wade := Vector2(float(rw[0]), float(rw[1]))
	var pool := nearest_pool(player.surface_dir, wade)
	if pool == Vector3.ZERO:
		return "no Pond Crawler: no water it can wade (%.2f-%.1f m deep) within %.0f m" % [wade.x, wade.y, POOL_M]
	if is_instance_valid(_crawler) and not _crawler.done:
		_crawler.leave()
	var map: PlanetData = world.planet
	var biome := map.biome[map.cell_at(pool)]
	var lock := sp.biome_ok(biome)
	var at: Vector3 = world.to_scene(pool, PlanetConst.RADIUS_M + chunks.water_level_at(pool))
	_crawler = PondCrawler.debug_spawn(creatures, pool, randi() & 0x7fffffff, lock, player.global_position - at)
	if _crawler == null:
		return "no Pond Crawler: it couldn't be placed"
	return "Pond Crawler in water %.2f m deep, %.0f m off (%s%s)" % [chunks.water_level_at(pool) - chunks.ground_height(pool),
		CubeSphere.surface_distance_m(player.surface_dir, pool), BiomeTemplates.name_of(biome), "" if lock else ", outside its swamp and bog"]


## The nearest spot within POOL_M of `near` (a surface direction) in water
## `wade` deep (about knee-deep or more, so its hands break the surface)
## with room round it (still wadeable 3 m off every way), searched in
## rings outward on a POOL_STEP_M grid; Vector3.ZERO if there's none.
## (PondCrawler.find_pool() scores every spot in the circle for the best
## one, which takes a minute over a big lake.)
func nearest_pool(near: Vector3, wade: Vector2) -> Vector3:
	var north := CubeSphere.north(near)
	var east := CubeSphere.east(near)
	var n := int(POOL_M / POOL_STEP_M)
	for ring in n + 1:
		for j in range(-ring, ring + 1):
			for i in range(-ring, ring + 1):
				if maxi(absi(i), absi(j)) != ring:
					continue
				var off := Vector2(i, j) * POOL_STEP_M
				if off.length() > POOL_M:
					continue
				var d := (near + (east * off.x + north * off.y) / PlanetConst.RADIUS_M).normalized()
				if chunks.chunk_at(d) == null or not _wadeable(d, wade, maxf(wade.x, 0.3)):
					continue
				var open := true
				for k in 8:
					var q := (d + north.rotated(d, k * TAU / 8.0) * 3.0 / PlanetConst.RADIUS_M).normalized()
					if not _wadeable(q, wade, wade.x):
						open = false
						break
				if open:
					return d
	return Vector3.ZERO


func _wadeable(d: Vector3, wade: Vector2, shallowest: float) -> bool:
	var depth := chunks.water_level_at(d) - chunks.ground_height(d)
	return depth >= shallowest and depth <= wade.y


func _gibbon_spawn() -> String:
	if BranchGraphs.count() == 0:
		return "no gibbon: no tree near you has a branch graph (they're built for trees within %.0f m)" % ChunkManager.GRAPH_M
	var map: PlanetData = world.planet
	var rain := PackedInt32Array()
	for k in GIBBON_BIOMES:
		rain.append(BiomeTemplates.id_of_key(k))
	var from := player.global_position + player.up * 8.0
	var found := []
	var hangable := 0
	for h in BranchGraphs.handholds_within(from, GIBBON_M, BranchGraph.MIN_RADIUS_M):
		var g: BranchGraph = h[0]
		var i: int = h[1]
		if not GibbonPlanner.hangable(g, i, g.frame().basis.y.normalized()):
			continue
		hangable += 1
		if rain.has(map.biome[map.cell_at(world.dir_of(g.base()))]):
			found = [g, i]
			break
	if found.is_empty():
		var here := BiomeTemplates.name_of(map.biome[map.cell_at(player.surface_dir)])
		if hangable == 0:
			return "no gibbon: no tree within %.0f m has wood it can hang from (%.1f-%.0f cm thick); you're in %s" % [GIBBON_M, BranchGraph.MIN_RADIUS_M * 100.0, GibbonPlanner.HANG_R_MAX * 100.0, here]
		return "no gibbon: no rainforest trees within %.0f m (you're in %s)" % [GIBBON_M, here]
	if is_instance_valid(_gibbon):
		_gibbon.queue_free()
	var g: BranchGraph = found[0]
	var i: int = found[1]
	_gibbon = Gibbon.debug_spawn(world.world_root, g.pos(i))
	if _gibbon == null:
		return "no gibbon: it couldn't be placed"
	_gibbon.player = player
	return "Gibbon hanging from handhold %d of a %s (%.0f m tall), %.0f m off, %.0f m up" % [i, SpeciesDB.all()[g.species].name, g.height_m,
		(g.base() - player.global_position).length(), (g.pos(i) - g.base()).dot(player.up)]
