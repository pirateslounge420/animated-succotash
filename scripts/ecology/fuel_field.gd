class_name FuelField
extends Node
## Fuel lying in the world (design 30 Sept §AX, data/fuel.json biomes):
## dead wood, fallen branches, brush, reeds, grass, dung, peat, driftwood,
## whatever the biome offers, laid as WorldItems (kind fuel, `fuel` the
## kind) in the chunks round the player, so many per chunk as the
## abundances add up to. Right click gathers one (carried: burden counts
## a log as two things, `carry_items`); gathered in rain or off soaked
## ground it is wet (`wet`, `wet_days`) and burns badly till it dries in
## the pack. Places are hashed from the chunk, so a piece lies where it
## lay; a piece taken stays taken (`taken`) for the session.

const PER_UNIT_ABUNDANCE := 5.0
const MAX_PER_CHUNK := 8
const RANGE_CHUNKS := 1

static var taken := {}

var world: Node
var chunks: ChunkManager
var player: Node3D
## chunk key -> the WorldItems laid there.
var _laid := {}
var _timer := 0.0


func setup(p_world: Node, p_chunks: ChunkManager, p_player: Node3D) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player


func _process(delta: float) -> void:
	if world == null or player == null or Tuning.profile() != "ambient":
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.7
	var pd: Vector3 = world.dir_of(player.global_position)
	var want := ChunkManager.keys_around(pd, RANGE_CHUNKS)
	for key in want:
		if _laid.has(key) or not chunks.chunks.has(key):
			continue
		var chunk: TerrainChunk = chunks.chunks[key]
		if chunk.data.is_empty():
			continue
		_laid[key] = _lay(key, chunk)
	for key in _laid.keys():
		if not want.has(key) or not chunks.chunks.has(key):
			for w in _laid[key]:
				if is_instance_valid(w):
					w.pick_up()
			_laid.erase(key)


## The fuel of one chunk: the biome's kinds, weighted by abundance, at
## hashed places on land.
func _lay(key, chunk: TerrainChunk) -> Array:
	var out: Array = []
	var off := FireStore.offers(world, chunk.center_dir)
	if off.is_empty() or chunk.dirs.is_empty():
		return out
	var total := 0.0
	for k in off:
		total += float(off[k])
	var n := mini(MAX_PER_CHUNK, roundi(total * PER_UNIT_ABUNDANCE))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, "fuel"])
	for i in n:
		var tag := "%s:%d" % [str(key), i]
		var d: Vector3 = chunk.dirs[rng.randi() % chunk.dirs.size()]
		d = CreatureSpawner._offset(d, rng.randf() * TAU, rng.randf() * 4.0)
		var r := rng.randf() * total
		var kind := ""
		for k in off:
			r -= float(off[k])
			kind = str(k)
			if r <= 0.0:
				break
		if taken.has(tag):
			continue
		var ground: float = chunks.ground_height(d)
		if ground <= chunks.water_level_at(d) + 0.2:
			continue
		var it := Inventory.make("fuel", {"fuel": kind, "title": FireStore.pretty(kind).capitalize(), "tag": tag,
			"carry_items": int((FireStore.KINDS.get(kind, {}) as Dictionary).get("carry_items", 1))})
		var w := WorldItem.drop(it, world, d, ground)
		out.append(w)
	return out


## Gathered (main._take_lying): remembered as taken, wet if the weather or
## the ground is.
static func gathered(it: Dictionary, wet: bool, days: float) -> void:
	if it.has("tag"):
		taken[str(it.tag)] = true
	if wet:
		it["wet"] = true
		it["wet_days"] = days
