class_name FoliageCover
## Leaves are cover, not walls (design §AM 2-3): a tree grown from its
## architecture (TreeArch) has no collider on its leaves, but its leaf
## clusters (the skeleton's anchors, TreeLayouts) still hide what's in them
## and brush what flies through them.
##
## Each cluster is taken as a sphere as big as the cluster drawn
## (PlantMeshes.arch_tree: the card's middle a little out from its twig,
## its radius), in the tree's frame, shrunk with the leaf the tree carries
## (the season, LeafSeason.leaf_now for deciduous species, and the tree's
## own bareness). A line through a cluster:
##   * sight (see_through()): each cluster crossed lets it through with the
##     species' canopy.gap as the chance (a birch's 0.4 more than an oak's
##     0.25), so a line through three oak clusters is about 1.5 % clear;
##   * an arrow or the spear (clusters_on()): loses combat.foliage_drag of
##     its speed per cluster and rustles the tree; wood stops it as before.
##
## Trees are found by their trunk and limb colliders (TerrainChunk's tree
## body, TREE_LAYER) near the line, so only trees in the detail ring count
## (the ones near the player, where it matters). Cluster spheres are cached
## per (species, layout) in the unit frame.

static var DRAG := float(Tuning.table("combat").get("foliage_drag", 0.05))
## Largest crown radius looked for round a line (m).
const REACH_M := 16.0

static var _unit := {} # Vector2i(species, layout) -> PackedVector4Array (unit frame)
static var _lock := Mutex.new()


## A tree's clusters in scene space, as [center (Vector3), radius (m)]
## pairs flattened into a PackedVector4Array; empty for a tree with no
## skeleton clusters or no leaf.
static func clusters(chunk: TerrainChunk, i: int) -> PackedVector4Array:
	var t: Array = chunk.trees[i]
	var pick: int = t[4]
	var sp: PlantSpecies = chunk.tree_species(i)
	if pick < 0 or not TreeArch.grows(sp):
		return PackedVector4Array()
	var leaf := leaf_of(chunk, i)
	if leaf < 0.05:
		return PackedVector4Array()
	var unit := _unit_clusters(int(t[2]), TreeLayouts.layout_of(pick))
	var h: float = t[1]
	var mx := -1.0 if TreeLayouts.is_mirrored(pick) else 1.0
	var frame := Transform3D(t[6] as Basis, chunk.global_position + (t[0] as Vector3))
	var k := lerpf(0.6, 1.0, leaf) # the shader shrinks a sparse tree's clusters so
	var out := PackedVector4Array()
	out.resize(unit.size())
	for j in unit.size():
		var u := unit[j]
		var c := frame * (Vector3(u.x * mx, u.y, u.z) * h)
		out[j] = Vector4(c.x, c.y, c.z, u.w * h * k)
	return out


## How much leaf tree `i` carries now (0-1): its own (growth, a dry site;
## 0 dead) times the season's for a deciduous species.
static func leaf_of(chunk: TerrainChunk, i: int) -> float:
	var t: Array = chunk.trees[i]
	var bare := float(t[8]) if t.size() > 8 else 0.0
	var own := 1.0 - bare
	if bare > 0.975:
		return 0.0
	var sp: PlantSpecies = chunk.tree_species(i)
	return own * (LeafSeason.leaf_now if sp.deciduous else 1.0)


## Trees with a crown within REACH_M of the segment a-b: [[chunk, i], ...].
static func trees_near(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Array:
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = a.distance_to(b) * 0.5 + REACH_M
	q.shape = sphere
	q.transform = Transform3D(Basis(), (a + b) * 0.5)
	q.collision_mask = TerrainChunk.TREE_LAYER
	q.collide_with_areas = false
	var seen := {}
	var out: Array = []
	for hit in space.intersect_shape(q, 256):
		var body: Object = hit.collider
		var chunk := (body as Node).get_parent() as TerrainChunk if body is Node else null
		if chunk == null:
			continue
		var i := chunk.tree_for_shape(body, hit.shape)
		if i < 0:
			continue
		var key := Vector2i(chunk.get_instance_id(), i)
		if seen.has(key):
			continue
		seen[key] = true
		out.append([chunk, i])
	return out


## The clusters the segment a-b passes through, nearest first:
## [[chunk, i, t along a-b (0-1), gap, cluster index], ...].
static func clusters_on(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Array:
	var out: Array = []
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 1e-8)
	for tr in trees_near(space, a, b):
		var chunk: TerrainChunk = tr[0]
		var i: int = tr[1]
		var gap := float(chunk.tree_species(i).canopy.get("gap", 0.3))
		var cl := clusters(chunk, i)
		for j in cl.size():
			var c := cl[j]
			var p := Vector3(c.x, c.y, c.z)
			var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			if (a + ab * t).distance_squared_to(p) <= c.w * c.w:
				out.append([chunk, i, t, gap, j])
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[2] < y[2])
	return out


## How clear the line of sight from `eye` to `target` is through leaves
## (1 clear, 0 hidden): the product of the gap of every cluster it
## crosses. `near_target`: the clusters to test (clusters_round()), so a
## caller testing many eyes against one target finds them once.
static func see_through(eye: Vector3, target: Vector3, near_target: Array) -> float:
	var clear := 1.0
	var ab := target - eye
	var len2 := maxf(ab.length_squared(), 1e-8)
	for e in near_target:
		var cl: PackedVector4Array = e[0]
		var gap: float = e[1]
		for c in cl:
			var p := Vector3(c.x, c.y, c.z)
			var t := clampf((p - eye).dot(ab) / len2, 0.0, 1.0)
			if (eye + ab * t).distance_squared_to(p) <= c.w * c.w:
				clear *= gap
				if clear < 0.01:
					return 0.0
	return clear


## The clusters of the trees round `p` (within REACH_M), as
## [[PackedVector4Array, gap], ...], for see_through().
static func clusters_round(space: PhysicsDirectSpaceState3D, p: Vector3) -> Array:
	var out: Array = []
	for tr in trees_near(space, p, p):
		var chunk: TerrainChunk = tr[0]
		var i: int = tr[1]
		var cl := clusters(chunk, i)
		if not cl.is_empty():
			out.append([cl, float(chunk.tree_species(i).canopy.get("gap", 0.3))])
	return out


## A layout's cluster spheres in the unit frame (tree height 1): each
## anchor's cluster centre (out along its hang from the twig) and radius.
static func _unit_clusters(sp_idx: int, layout: int) -> PackedVector4Array:
	var key := Vector2i(sp_idx, layout)
	_lock.lock()
	var got = _unit.get(key)
	_lock.unlock()
	if got != null:
		return got
	var sk := TreeLayouts.skeleton(sp_idx, layout)
	var out := PackedVector4Array()
	for an in sk.anchors:
		var r: float = an[5]
		var c: Vector3 = (an[0] as Vector3) + (an[2] as Vector3) * r * 0.45
		out.append(Vector4(c.x, c.y, c.z, r * 0.9))
	_lock.lock()
	_unit[key] = out
	_lock.unlock()
	return out
