class_name Uniques
## One-of-a-kind places (design 1 Oct §CL, data/uniques.json): each appears
## exactly once in a world. Built so far: the sacred fig, an ancient Ficus
## religiosa past the top of its species' band (VegetationPlacer grows it,
## the trees round it kept back), a ring of swept earth under it
## (TerrainChunk's ground colour), a few flat stones, and beneath it on the
## east side of the trunk, facing east, a figure on the shared cloaked rig
## (§0) seated cross-legged in meditation in an ochre robe (#CC7722),
## still but for its breath (PlayerBody pose "meditate"). Never a camp,
## never a ruin; nothing the player does changes it. The log says only
## "Someone sits beneath the old fig, very still." (no name in play, §BO).
## Not built yet: the faint path in from a road, the roots gripping old
## stone, the leaves' own flutter, the hood down (the rig has no bare head).

static var D: Dictionary = _load()
static var _fig := {}
static var _fig_terrain: TerrainField = null
static var _mutex := Mutex.new()
## How far round the trunk the earth is swept and other trees kept back.
const RING_M := 17.0
## Past the top of the species' band (uniques.json tree.size: "past the
## top of the species' band: about 30 m"; the band tops out at 30 m).
const FIG_PAST_BAND := 1.12


static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/uniques.json"))
	return parsed if parsed is Dictionary else {}


static func fig_entry() -> Dictionary:
	return (D.get("uniques", {}) as Dictionary).get("sacred_fig", {})


## The sacred fig's site in this world ({} if no biome on its list exists):
## {"dir", "biome", "figure" (dir), "facing" (bearing, east)}. Pure: the
## planet and its seed; cached per world.
static func sacred_fig(map: PlanetData) -> Dictionary:
	if map == null or map.biome.is_empty():
		return {}
	_mutex.lock()
	if _fig_terrain == map.terrain:
		var hit := _fig
		_mutex.unlock()
		return hit
	_mutex.unlock()
	var site := _find_fig(map)
	_mutex.lock()
	_fig = site
	_fig_terrain = map.terrain
	_mutex.unlock()
	return site


static func _find_fig(map: PlanetData) -> Dictionary:
	var where: Dictionary = fig_entry().get("where", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map.terrain.world_seed, "sacred_fig"])
	for key in where.get("biomes", []):
		var bid := BiomeTemplates.id_of_key(str(key))
		var cells := PackedInt32Array()
		for c in map.cell_count:
			if map.biome[c] == bid and map.water[c] == PlanetData.Water.NONE:
				cells.append(c)
		if cells.is_empty():
			continue
		var best := {}
		var best_score := -INF
		for i in mini(40, cells.size() * 2):
			var c := cells[rng.randi() % cells.size()]
			var p := CreatureSpawner._offset(map.dir[c], rng.randf() * TAU, sqrt(rng.randf()) * map.cell_m() * 0.4)
			if map.biome[map.cell_at(p)] != bid:
				continue
			var e := map.terrain.elevation(p, true, false, false)
			if e < 4.0:
				continue
			var slope := 0.0
			var ring := 0.0
			for k in 6:
				var q := CreatureSpawner._offset(p, k * TAU / 6.0, 20.0)
				slope = maxf(slope, absf(map.terrain.elevation(q, true, false, false) - e) / 20.0)
				ring += map.terrain.elevation(CreatureSpawner._offset(p, k * TAU / 6.0, 180.0), true, false, false)
			# Level, and on a low rise: higher than the ground round it.
			if slope > 0.08:
				continue
			if not Ruins.near(map, p, 80.0).is_empty():
				continue
			var score := (e - ring / 6.0) - slope * 40.0 + rng.randf()
			if score > best_score:
				best_score = score
				best = {"dir": p, "biome": str(key)}
		if not best.is_empty():
			var d: Vector3 = best.dir
			best.facing = PI * 0.5 # east
			best.figure = CreatureSpawner._offset(d, PI * 0.5, 4.2)
			return best
	return {}


## [dir, radius_m] the trees and undergrowth keep out of round the fig.
static func clearings_near(map: PlanetData, d: Vector3, radius: float) -> Array:
	var f := sacred_fig(map)
	if f.is_empty() or CubeSphere.surface_distance_m(f.dir, d) > radius + RING_M:
		return []
	return [[f.dir, RING_M]]


## 0-1 the swept earth under the fig at `d` (the ground's colour).
static func swept_at(map: PlanetData, d: Vector3) -> float:
	_mutex.lock()
	var f := _fig if _fig_terrain == map.terrain else {}
	_mutex.unlock()
	if f.is_empty():
		return 0.0
	var dir: Vector3 = f.dir
	if d.dot(dir) < cos((RING_M + 3.0) / PlanetConst.RADIUS_M):
		return 0.0
	return smoothstep(RING_M + 2.0, RING_M - 3.0, CubeSphere.surface_distance_m(dir, d))


## The fig tree itself, for the chunk it stands in (VegetationPlacer):
## [species index, dir, height_m] or [].
static func fig_tree(map: PlanetData, key: Vector3i) -> Array:
	var f := sacred_fig(map)
	if f.is_empty() or TerrainChunk.key_at(f.dir) != key:
		return []
	var tree: Dictionary = fig_entry().get("tree", {})
	var sp := Nests.species_of("%s %s" % [tree.get("genus", "Ficus"), tree.get("species", "religiosa")])
	if sp == null:
		return []
	return [SpeciesDB.index_of(sp), f.dir, maxf(sp.height_m.y, 28.0) * FIG_PAST_BAND]


## The figure and the flat stones under the fig (Landmarks, near it).
static func build(world: Node, chunks: ChunkManager, f: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "SacredFig"
	var fd: Vector3 = f.figure
	var at: Vector3 = world.to_scene(fd, PlanetConst.RADIUS_M + chunks.ground_height(fd))
	# The caller places the root at `xf` once it is in the tree; the
	# children are set in its frame.
	var xf := Transform3D(Basis.looking_at(CubeSphere.north(fd), fd), at)
	var inv := xf.affine_inverse()
	var robe: Dictionary = (fig_entry().get("figure", {}) as Dictionary).get("robe", {})
	var b := CloakedFigure.build(1.7, Color(str(robe.get("colour", "#CC7722"))), Color(str(robe.get("edge", "#A8601C"))), false)
	var body: PlayerBody = b.root
	body.name = "Figure"
	body.pose = "meditate"
	var holder := Node3D.new()
	holder.name = "Seated"
	root.add_child(holder)
	holder.add_child(body)
	# Facing east, away from the trunk (north is local -z here; east +x).
	holder.basis = Basis.looking_at(Vector3(1.0, 0.0, 0.0), Vector3.UP)
	BlobShadow.make(holder, 0.5, 0.5)
	# A few flat stones on the swept earth.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([fd, "fig_stones"])
	for k in 4:
		var a := rng.randf() * TAU
		var r := rng.randf_range(5.0, 11.0)
		var size := Vector3(rng.randf_range(0.7, 1.2), rng.randf_range(0.18, 0.3), rng.randf_range(0.6, 1.0))
		var rock := MeshInstance3D.new()
		rock.mesh = RuinBuilder.rock_mesh(size, rng.randi(), Color(0.55, 0.52, 0.48))
		rock.material_override = RuinBuilder.material()
		root.add_child(rock)
		var sd := CreatureSpawner._offset(f.dir, a, r)
		rock.position = inv * world.to_scene(sd, PlanetConst.RADIUS_M + chunks.ground_height(sd) + size.y * 0.15)
		rock.basis = Basis(Vector3.UP, rng.randf() * TAU)
	return root
