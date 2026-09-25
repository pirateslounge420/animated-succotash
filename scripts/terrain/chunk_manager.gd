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
## radius of 3 chunks (~800 m) covers everything visible on flat ground;
## FarShell draws distant mountains. Undergrowth only exists close by and is
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
@export var max_attach_per_frame := 2
## Tree trunk colliders added per frame (detail ring only).
@export var tree_colliders_per_frame := 60

var world: Node
var map: PlanetData
var rivers: RiverNetwork
var chunks := {} # Vector3i -> TerrainChunk

var _pending := {} # Vector3i -> task id (base)
var _pending_detail := {} # Vector3i -> task id
var _done: Array = []
var _done_detail: Array = []
var _mutex := Mutex.new()
var _wanted := {}
var _wanted_detail := {}
## Rings around the chunk the player is in, cached per chunk.
var _rings_key := Vector3i(-1, -1, -1)
var _ring_view := {}
var _ring_detail := {}
var _ring_keep := {}
var _ring_keep_detail := {}


func setup(p_world: Node) -> void:
	world = p_world
	map = world.planet
	rivers = RiverNetwork.new(map)
	SpeciesDB.all() # load plant data on the main thread before workers need it
	BiomeTemplates.color_of(0) # same for the biome color table
	CreatureSpecies.all() # and creature data (vegetation keeps folk camps clear)
	TerrainChunk.materials()
	# Shared caches the worker threads read (RuinBuilder's boulders, plant
	# crowns): fill them here so no two threads race to write them.
	for level in 3:
		PlantMeshes.icosphere(level)
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


func update_around(player_dir: Vector3) -> void:
	# The rings only change when the player crosses into another chunk;
	# they're measured from that chunk's center, so they're recomputed only
	# then.
	var here := TerrainChunk.key_at(player_dir)
	if here != _rings_key:
		_rings_key = here
		var c := TerrainChunk.center_of(here)
		_ring_view = keys_around(c, view_radius_chunks)
		_ring_detail = keys_around(c, detail_radius_chunks)
		_ring_keep = keys_around(c, view_radius_chunks + 1)
		_ring_keep_detail = keys_around(c, detail_radius_chunks + 1)
	_wanted = _ring_view
	_wanted_detail = _ring_detail
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
			c.set_fine(_wanted_detail.has(key))

	_attach_base(max_attach_per_frame)
	_attach_detail(max_attach_per_frame)
	_build_tree_colliders(tree_colliders_per_frame)


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


func _compute_base(key: Vector3i) -> void:
	var data := TerrainChunk.compute(key, map, rivers)
	var trees := VegetationPlacer.compute_base(key, map, data)
	TerrainChunk.bake_canopy_shade(data, trees.hosts)
	TerrainChunk.prepare_meshes(data)
	data["plants"] = VegetationPlacer.prepare(trees.plants, data.center, data.anchor_r)
	data["hosts"] = trees.hosts
	_mutex.lock()
	_done.append(data)
	_mutex.unlock()


func _compute_detail(key: Vector3i, data: Dictionary, hosts: Array) -> void:
	var plants := VegetationPlacer.prepare(VegetationPlacer.compute_detail(key, map, data, hosts), data.center, data.anchor_r)
	_mutex.lock()
	_done_detail.append([key, plants])
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
		if not _wanted.has(key) or chunks.has(key):
			continue
		var chunk := TerrainChunk.new()
		chunk.build_nodes(data, world)
		chunk.data = data
		chunk.hosts = data.hosts
		VegetationPlacer.build_nodes(chunk, chunk, data.plants)
		world.world_root.add_child(chunk)
		chunk.set_fine(_wanted_detail.has(key))
		chunks[key] = chunk
		chunk_loaded.emit(chunk)
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
	var inner := keys_around(d, detail_radius_chunks)
	_wanted = keys_around(d, view_radius_chunks)
	_wanted_detail = inner
	_rings_key = Vector3i(-1, -1, -1) # the next update rebuilds the rings
	for key in inner:
		if not _pending.has(key) and not chunks.has(key):
			_pending[key] = WorkerThreadPool.add_task(_compute_base.bind(key))
	for key in inner:
		if _pending.has(key):
			WorkerThreadPool.wait_for_task_completion(_pending[key])
			_pending.erase(key)
	_attach_base(1000)
	for key in inner:
		var c: TerrainChunk = chunks.get(key)
		if c and c.detail_node == null:
			_pending_detail[key] = WorkerThreadPool.add_task(_compute_detail.bind(key, c.data, c.hosts))
	for key in _pending_detail.keys():
		WorkerThreadPool.wait_for_task_completion(_pending_detail[key])
	_pending_detail.clear()
	_attach_detail(1000)
	_build_tree_colliders(1 << 30)


## Chunk containing a surface direction, if loaded.
func chunk_at(d: Vector3) -> TerrainChunk:
	return chunks.get(TerrainChunk.key_at(d))


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
