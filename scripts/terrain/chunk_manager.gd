class_name ChunkManager
extends Node
## Streams the walkable planet around the player; nothing beyond the view
## radius exists as geometry. Two rings:
##
##   view ring   (view_radius_chunks)   ground (8 m quads), water and trees
##   detail ring (detail_radius_chunks) 4 m ground, plus shrubs, ground
##                                      cover and epiphytes
##
## A standing player's horizon on this planet is only ~465 m away, so a view
## radius of 3 chunks (~900 m) covers everything visible on flat ground;
## FarShell draws distant mountains. The view radius is the player's render
## distance setting (render_chunks(), 1-8 chunks), with the day haze scaled
## to match (fog_scale()). Undergrowth only exists close by and is
## dropped again as you walk away.
##
## All geometry and plant placement is computed on worker threads
## (TerrainChunk.compute, VegetationPlacer.compute_* are pure functions of
## the read-only planet blueprint); only node creation happens on the main
## thread, a few chunks per frame.

signal chunk_loaded(chunk: TerrainChunk)
signal chunk_unloaded(chunk: TerrainChunk)

@export var view_radius_chunks := 3
@export var detail_radius_chunks := 1
const DEFAULT_DETAIL_CHUNKS := 1
## The render distance setting (settings panel, "display.render_chunks";
## from play, like Minecraft's): how many chunks out the view ring goes,
## RENDER_MIN .. RENDER_MAX, DEFAULT_RENDER the one the look was tuned at.
## Changed live: the next update rebuilds the rings. SkySystem thins or
## thickens the day haze with it (fog_scale()).
const RENDER_MIN := 1
const RENDER_MAX := 8
const DEFAULT_RENDER := 3
@export var max_attach_per_frame := 2
## Tree trunk colliders added per frame (detail ring only).
@export var tree_colliders_per_frame := 60
## Chunks within this of the player draw their plants at their smoothest
## (PlantMeshes.LOD_HERO); the rest of the detail ring a step lighter.
const HERO_M := 120.0
## Trees within GRAPH_M of the player get a branch graph (BranchGraphs:
## handholds for climbing and monkeys) and colliders on their thick limbs;
## past GRAPH_OUT_M they lose both again (the gap keeps a tree at the edge
## from flickering in and out). Well inside HERO_M, so these trees always
## show their full limbs.
const GRAPH_M := 60.0
const GRAPH_OUT_M := 70.0
## Order-3 twigs thick enough to stand on get their capsules only this
## near (design §AM 5: the physics budget), dropped again past TWIG_OUT_M.
const TWIG_M := 30.0
const TWIG_OUT_M := 35.0
## Time per frame (ms) for building branch graphs and limb colliders,
## nearest trees first; at least one tree a frame (a 70 m emergent's graph
## takes ~0.6 ms, most trees' far less).
@export var graph_budget_ms := 1.0

var world: Node
var map: PlanetData
var rivers: RiverNetwork
## The trail network (design 30 Sept §BC), laid before plants.
var roads: RoadNetwork
var chunks := {} # Vector3i -> TerrainChunk

var _pending := {} # Vector3i -> task id (base)
var _pending_detail := {} # Vector3i -> task id
var _done: Array = []
var _done_detail: Array = []
var _mutex := Mutex.new()
var _wanted := {}
## Chunks whose queued work was abandoned when the player jumped elsewhere
## (load_blocking): their tasks skip it. Guarded by _mutex.
var _abandoned := {}
var _abandoned_detail := {}
var _wanted_detail := {}
## Rings around the chunk the player is in, cached per chunk.
var _rings_key := Vector3i(-1, -1, -1)
var _ring_view := {}
var _ring_detail := {}
var _ring_keep := {}
var _ring_keep_detail := {}
## The chunks within HERO_M of the player, and where that was measured.
var _hero := {}
var _hero_at := Vector3.ZERO
## Branch graphs: where the player stood (planet frame, m) at the last
## scan for trees coming into or leaving range, the trees still to get a
## graph ([chunk, tree index, distance], nearest last), and a rescan flag
## for when new chunks come in.
var _graph_from := Vector3.ZERO
var _graph_todo: Array = []
var _graph_rescan := true
var _graph_timer := 0.0


func setup(p_world: Node) -> void:
	world = p_world
	map = world.planet
	rivers = RiverNetwork.new(map)
	roads = RoadNetwork.new(map, rivers)
	SpeciesDB.all() # load plant data on the main thread before workers need it
	BiomeTemplates.color_of(0) # same for the biome color table
	CreatureSpecies.all() # and creature data (vegetation keeps folk camps clear)
	TerrainChunk.materials()
	# Shared caches the worker threads read (RuinBuilder's boulders, plant
	# crowns): fill them here so no two threads race to write them.
	for level in 3:
		PlantMeshes.icosphere(level)
	PlantMeshes.geosphere(3)
	# The branchy trees' layouts grow from the world seed.
	PlantMeshes.use_seed(map.terrain.world_seed)
	VegetationPlacer.warm(map.terrain.world_seed)


## Let running worker tasks finish before the scene goes away (they read
## the planet data and would otherwise outlive it).
func _exit_tree() -> void:
	for task in _pending.values():
		WorkerThreadPool.wait_for_task_completion(task)
	for task in _pending_detail.values():
		WorkerThreadPool.wait_for_task_completion(task)
	_pending.clear()
	_pending_detail.clear()


## The render distance in chunks: the setting (or RENDER_CHUNKS in the
## environment, for tools), clamped.
static func render_chunks() -> int:
	var env := OS.get_environment("RENDER_CHUNKS")
	var n := int(env) if env != "" else int(Settings.get_value("display.render_chunks", DEFAULT_RENDER))
	return clampi(n, RENDER_MIN, RENDER_MAX)


## How far the view ring reaches (m) at `n` chunks: its edge, from the
## player's chunk center.
static func render_reach_m(n: int) -> float:
	return (n + 0.5) * chunk_size_m()


## The day haze's density against the one the look was tuned at, so the
## ring's edge always fades out: thinner at a longer render distance (you
## see farther, like Minecraft), thicker at a shorter one.
static func fog_scale() -> float:
	return render_reach_m(DEFAULT_RENDER) / render_reach_m(render_chunks())


static func chunk_size_m() -> float:
	return PlanetConst.CIRCUMFERENCE_M / 4.0 / TerrainChunk.CHUNKS_PER_FACE


## Keys of every chunk within `radius` chunks of a surface direction.
static func keys_around(d: Vector3, radius: int) -> Dictionary:
	var out := {}
	var size := chunk_size_m()
	var reach := (radius + 0.5) * size
	var east := CubeSphere.east(d)
	var north := CubeSphere.north(d)
	var step := size * 0.5
	var k := int(ceil(reach / step))
	for a in range(-k, k + 1):
		for b in range(-k, k + 1):
			var off := Vector2(a, b) * step
			if off.length() > reach:
				continue
			var p := (d + (east * off.x + north * off.y) / PlanetConst.RADIUS_M).normalized()
			out[TerrainChunk.key_at(p)] = true
	return out


## Chunks overlapping the disc of HERO_M around `d` (sampled every
## 60 m).
static func _hero_keys(d: Vector3) -> Dictionary:
	var out := {}
	var east := CubeSphere.east(d)
	var north := CubeSphere.north(d)
	for a in range(-2, 3):
		for b in range(-2, 3):
			var off := Vector2(a, b) * (HERO_M * 0.5)
			if off.length() > HERO_M + 1.0:
				continue
			out[TerrainChunk.key_at((d + (east * off.x + north * off.y) / PlanetConst.RADIUS_M).normalized())] = true
	return out


func update_around(player_dir: Vector3) -> void:
	# The world clock for the chunk workers: plants are placed at their age
	# now (PlantGrowth).
	if world != null:
		PlantGrowth.now_days = world.days
	# The rings only change when the player crosses into another chunk
	# (they're measured from that chunk's center, so they're recomputed only
	# then) or the render distance setting changes.
	var want_view := render_chunks()
	var rings_stale := want_view != view_radius_chunks
	view_radius_chunks = want_view
	# At walking pace (the ambient profile, design 30 Sept §AU) the
	# streaming has time: the detail ring (leaf cards, shadows, the
	# undergrowth) reaches two chunks, so the far pictures start ~520 m
	# out, not ~260. DETAIL_CHUNKS= in the environment overrides (tools).
	var want_detail := DEFAULT_DETAIL_CHUNKS
	if OS.get_environment("DETAIL_CHUNKS") != "":
		want_detail = int(OS.get_environment("DETAIL_CHUNKS"))
	elif Tuning.profile() == "ambient":
		want_detail = 2
	rings_stale = rings_stale or want_detail != detail_radius_chunks
	detail_radius_chunks = mini(want_detail, view_radius_chunks)
	var here := TerrainChunk.key_at(player_dir)
	if here != _rings_key or rings_stale:
		_rings_key = here
		var c := TerrainChunk.center_of(here)
		_ring_view = keys_around(c, view_radius_chunks)
		_ring_detail = keys_around(c, detail_radius_chunks)
		_ring_keep = keys_around(c, view_radius_chunks + 1)
		_ring_keep_detail = keys_around(c, detail_radius_chunks + 1)
	_wanted = _ring_view
	_wanted_detail = _ring_detail
	if _hero_at == Vector3.ZERO or _hero_at.distance_to(player_dir) * PlanetConst.RADIUS_M > 15.0:
		_hero_at = player_dir
		_hero = _hero_keys(player_dir)
	for key in _wanted:
		if not chunks.has(key) and not _pending.has(key):
			_pending[key] = WorkerThreadPool.add_task(_compute_base.bind(key))

	var keep := _ring_keep
	var keep_detail := _ring_keep_detail
	for key in chunks.keys():
		var c: TerrainChunk = chunks[key]
		if not keep.has(key):
			chunks.erase(key)
			chunk_unloaded.emit(c)
			NodeRelease.free_later(c)
		elif not keep_detail.has(key) and c.detail_node:
			NodeRelease.free_later(c.detail_node)
			c.detail_node = null
		elif _wanted_detail.has(key) and c.detail_node == null and not _pending_detail.has(key):
			_pending_detail[key] = WorkerThreadPool.add_task(_compute_detail.bind(key, c.data, c.hosts))
		if chunks.has(key):
			c.set_fine(_wanted_detail.has(key), _hero.has(key))
			# Kept past the view ring (so stepping back and forth doesn't
			# reload them) but not drawn: the render distance is what's drawn.
			c.visible = _wanted.has(key)

	_attach_base(max_attach_per_frame)
	_attach_detail(max_attach_per_frame)
	_build_collision(1)
	_build_tree_colliders(tree_colliders_per_frame)
	_update_graphs(player_dir, graph_budget_ms)


## Ground collision for the chunks near the player (the detail ring), the
## player's own chunk first: `budget` strips this frame. Farther chunks
## never need it (creatures use heights, arrows fall short of them).
func _build_collision(budget: int) -> void:
	var here: TerrainChunk = chunks.get(_rings_key)
	while budget > 0 and here and here.wants_collision():
		here.build_collision_part()
		budget -= 1
	for key in _wanted_detail:
		if budget <= 0:
			return
		var c: TerrainChunk = chunks.get(key)
		while budget > 0 and c and c.wants_collision():
			c.build_collision_part()
			budget -= 1


## Trunk colliders for the detail ring, the player's own chunk first.
func _build_tree_colliders(budget: int) -> void:
	var here: TerrainChunk = chunks.get(_rings_key)
	if here and here.wants_tree_colliders():
		budget -= here.build_tree_colliders(budget)
	for key in _wanted_detail:
		if budget <= 0:
			return
		var c: TerrainChunk = chunks.get(key)
		if c and c.wants_tree_colliders():
			budget -= c.build_tree_colliders(budget)


## Branch graphs for the trees around the player (GRAPH_M): rescans which
## trees are in or out of range when the player has moved a few meters,
## new chunks came in, or a second has passed; then builds graphs, nearest
## first, for `budget_ms`. Distances are measured from the ground under the
## player, in the planet frame (floating origin doesn't matter).
func _update_graphs(player_dir: Vector3, budget_ms: float) -> void:
	var p := player_dir * (PlanetConst.RADIUS_M + ground_height(player_dir))
	_graph_timer -= get_process_delta_time()
	if _graph_rescan or _graph_timer <= 0.0 or _graph_from.distance_to(p) > 4.0:
		_graph_rescan = false
		_graph_timer = 1.0
		_graph_from = p
		_scan_graphs(p)
	var until := Time.get_ticks_usec() + int(budget_ms * 1000.0)
	var built := 0
	while not _graph_todo.is_empty() and (built == 0 or Time.get_ticks_usec() < until):
		var item: Array = _graph_todo.pop_back()
		var c: TerrainChunk = item[0]
		if not is_instance_valid(c) or not c.has_tree_colliders():
			continue
		if item.size() > 3:
			# A tree already holding its graph, come within TWIG_M.
			if c.graphs.has(item[1]):
				c.add_twigs(item[1])
				built += 1
		elif not c.graphs.has(item[1]):
			c.add_graph(item[1])
			built += 1


func _scan_graphs(p: Vector3) -> void:
	_graph_todo.clear()
	var reach := GRAPH_OUT_M + chunk_size_m() * 0.75
	var in2 := GRAPH_M * GRAPH_M
	var out2 := GRAPH_OUT_M * GRAPH_OUT_M
	for key in chunks:
		var c: TerrainChunk = chunks[key]
		var rel := c.center_dir * c.anchor_radius - p
		# Only chunks with trunk colliders (the detail ring) hold graphs.
		if rel.length() > reach or not c.has_tree_colliders():
			if not c.graphs.is_empty():
				c.remove_graphs()
			continue
		for i in c.trees.size():
			var d2 := (rel + (c.trees[i][0] as Vector3)).length_squared()
			if c.graphs.has(i):
				if d2 > out2:
					c.remove_graph(i)
				elif d2 < TWIG_M * TWIG_M and not c.has_twigs(i):
					_graph_todo.append([c, i, d2, true])
				elif d2 > TWIG_OUT_M * TWIG_OUT_M and c.has_twigs(i):
					c.remove_twigs(i)
			elif d2 < in2:
				_graph_todo.append([c, i, d2])
	_graph_todo.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])


## Worker: everything a chunk needs before its nodes can be built (not
## its collision: see TerrainChunk.build_collision_part). Work abandoned
## when the player jumped elsewhere (load_blocking) is skipped.
func _compute_base(key: Vector3i) -> void:
	_mutex.lock()
	var skip := _abandoned.has(key)
	if skip:
		_done.append({"key": key, "skipped": true})
	_mutex.unlock()
	if skip:
		return
	var data := TerrainChunk.compute(key, map, rivers)
	var trees := VegetationPlacer.compute_base(key, map, data)
	TerrainChunk.set_anchor(data)
	data["plants"] = VegetationPlacer.prepare(trees.plants, data.center, data.anchor_r, trees.hosts, key, map.terrain.world_seed)
	TerrainChunk.bake_canopy_shade(data, trees.hosts)
	data["dapple"] = CanopyDapple.bake(data.center, data.plants)
	TerrainChunk.prepare_meshes(data)
	data["hosts"] = trees.hosts
	# The trees' meshes, if this is the first time a species shows up, and
	# the young layouts its young trees grow (design §AR).
	PlantMeshes.warm(data.plants.keys())
	PlantMeshes.warm_layouts(data.plants)
	_mutex.lock()
	_done.append(data)
	_mutex.unlock()


func _compute_detail(key: Vector3i, data: Dictionary, hosts: Array) -> void:
	_mutex.lock()
	var skip := _abandoned_detail.has(key)
	_mutex.unlock()
	var plants := {}
	if not skip:
		plants = VegetationPlacer.prepare(VegetationPlacer.compute_detail(key, map, data, hosts), data.center, data.anchor_r)
		PlantMeshes.warm(plants.keys())
	_mutex.lock()
	_done_detail.append([key, plants, skip])
	_mutex.unlock()


func _attach_base(limit: int) -> void:
	var attached := 0
	while attached < limit:
		_mutex.lock()
		var data = _done.pop_front() if not _done.is_empty() else null
		_mutex.unlock()
		if data == null:
			return
		var key: Vector3i = data.key
		if _pending.has(key):
			WorkerThreadPool.wait_for_task_completion(_pending[key])
			_pending.erase(key)
		_mutex.lock()
		_abandoned.erase(key)
		_mutex.unlock()
		if data.get("skipped", false) or not _wanted.has(key) or chunks.has(key):
			continue
		var chunk := TerrainChunk.new()
		chunk.build_nodes(data, world)
		chunk.data = data
		chunk.hosts = data.hosts
		VegetationPlacer.build_nodes(chunk, chunk, data.plants)
		world.world_root.add_child(chunk)
		Coppice.apply(chunk, world)
		chunk.set_fine(_wanted_detail.has(key), _hero.has(key))
		chunks[key] = chunk
		chunk_loaded.emit(chunk)
		_graph_rescan = true
		attached += 1


func _attach_detail(limit: int) -> void:
	var attached := 0
	while attached < limit:
		_mutex.lock()
		var item = _done_detail.pop_front() if not _done_detail.is_empty() else null
		_mutex.unlock()
		if item == null:
			return
		var key: Vector3i = item[0]
		if _pending_detail.has(key):
			WorkerThreadPool.wait_for_task_completion(_pending_detail[key])
			_pending_detail.erase(key)
		_mutex.lock()
		_abandoned_detail.erase(key)
		_mutex.unlock()
		if item[2]:
			continue
		var chunk: TerrainChunk = chunks.get(key)
		if chunk == null or chunk.detail_node != null or not _wanted_detail.has(key):
			continue
		chunk.detail_node = Node3D.new()
		chunk.detail_node.name = "Undergrowth"
		chunk.add_child(chunk.detail_node)
		VegetationPlacer.build_nodes(chunk.detail_node, chunk, item[1])
		attached += 1


## Blocks until the chunks right around `d` (the detail ring, with
## undergrowth) are loaded, for the loading screen before spawning. The
## rest of the view ring then streams in over the next frames.
func load_blocking(d: Vector3) -> void:
	if world != null:
		PlantGrowth.now_days = world.days
	view_radius_chunks = render_chunks()
	detail_radius_chunks = mini(detail_radius_chunks, view_radius_chunks)
	var inner := keys_around(d, detail_radius_chunks)
	_wanted = keys_around(d, view_radius_chunks)
	_wanted_detail = inner
	_hero_at = d
	_hero = _hero_keys(d)
	_rings_key = Vector3i(-1, -1, -1) # the next update rebuilds the rings
	# Work still queued for where the player was is abandoned (those tasks
	# skip it), and the chunks needed now jump the queue.
	_mutex.lock()
	for key in _pending:
		if not _wanted.has(key):
			_abandoned[key] = true
	for key in _pending_detail:
		if not inner.has(key):
			_abandoned_detail[key] = true
	_mutex.unlock()
	for key in inner:
		if not _pending.has(key) and not chunks.has(key):
			_pending[key] = WorkerThreadPool.add_task(_compute_base.bind(key), true)
	for key in inner:
		if _pending.has(key):
			WorkerThreadPool.wait_for_task_completion(_pending[key])
			_pending.erase(key)
	_attach_base(1000)
	for key in inner:
		var c: TerrainChunk = chunks.get(key)
		if c and c.detail_node == null:
			_pending_detail[key] = WorkerThreadPool.add_task(_compute_detail.bind(key, c.data, c.hosts), true)
	for key in _pending_detail.keys():
		WorkerThreadPool.wait_for_task_completion(_pending_detail[key])
	_pending_detail.clear()
	_attach_detail(1000)
	_build_collision(1 << 30)
	_build_tree_colliders(1 << 30)
	_graph_rescan = true
	_update_graphs(d, 1e9)


## Chunk containing a surface direction, if loaded.
func chunk_at(d: Vector3) -> TerrainChunk:
	return chunks.get(TerrainChunk.key_at(d))


## The sky's share at a scene point through the canopy (§BD; 1 with no
## chunk or stamp there): TerrainChunk.sky_visibility_at.
func sky_visibility_at(scene_pos: Vector3) -> float:
	var c := chunk_at(world.dir_of(scene_pos))
	return c.sky_visibility_at(scene_pos) if c else 1.0


## Ground height at a surface direction if its chunk is loaded, else the
## continuous terrain function (identical away from rivers).
func ground_height(d: Vector3) -> float:
	var c := chunk_at(d)
	if c:
		return c.height_at(d)
	return map.terrain.elevation(d, true)


## Standing-water surface height at a surface direction (sea level where
## there's no lake, pool or river).
func water_level_at(d: Vector3) -> float:
	var c := chunk_at(d)
	if c and not c.data.is_empty():
		return c.water_at(d)
	return PlanetConst.SEA_LEVEL_M
