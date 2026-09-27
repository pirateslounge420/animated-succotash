class_name BranchGraph
extends RefCounted
## One tree's climbable wood (spec Phase 1 (i)): handholds along the trunk
## and the limbs, and which handhold leads to which. The player climbs and
## monkeys brachiate only between handholds of these graphs.
##
## Built only for trees in NEAR range, deterministically from the world
## seed and the tree's position: the same tree has the same graph, and the
## same `key`, on every visit. The tree code owns the graphs and registers
## them with BranchGraphs; readers never change them.
##
## Handholds are kept in the tree's own frame, in meters: trunk base at the
## origin, +Y up the unleaned trunk. `xform` places that frame in the chunk
## (rotation and translation only, no scale), and the chunk moves with the
## floating origin, so pos() is always a current scene position. Thick wood
## doesn't sway in the wind (only leaves and twigs do), so a handhold stays
## put while the tree stands.

## Thinnest wood kept, as a radius (m): about a monkey's grip. The player
## needs thicker wood; readers filter on `radius`.
const MIN_RADIUS_M := 0.035
## Rough spacing of handholds along the wood (m).
const SPACING_M := 0.5

## Stable per tree: the same tree gets the same key on every visit.
var key := 0
## PlantSpecies index and the tree's height (m).
var species := -1
var height_m := 0.0
## The chunk the tree belongs to, and the tree's frame within the chunk.
var chunk: Node3D = null
var xform := Transform3D.IDENTITY

## Per handhold (all the same length): position in the tree frame (m),
var local := PackedVector3Array()
## the direction of the wood there (unit, tree frame: up the trunk, out
## along a limb),
var tangent := PackedVector3Array()
## the radius of the wood there (m),
var radius := PackedFloat32Array()
## which limb it's on (0 = the trunk),
var limb := PackedInt32Array()
## and the handholds reachable from it along the wood: the next one up or
## down the trunk, in or out along a limb, and across each fork (trunk to a
## limb's first handhold, limb to a branch's first handhold). Links go both
## ways. Reaching across open air, to another limb or another tree, isn't a
## link: readers find those with BranchGraphs.handholds_within().
var links: Array[PackedInt32Array] = []

# Bounding sphere of the handholds in the tree frame, computed on demand.
var _bound_c := Vector3.ZERO
var _bound_r := -1.0


func size() -> int:
	return local.size()


## False once the tree's chunk has been freed.
func valid() -> bool:
	return chunk != null and is_instance_valid(chunk)


## Scene transform of the tree frame.
func frame() -> Transform3D:
	return chunk.global_transform * xform


## Scene position of handhold `i`.
func pos(i: int) -> Vector3:
	return frame() * local[i]


## Scene direction of the wood at handhold `i` (unit).
func dir(i: int) -> Vector3:
	return (frame().basis * tangent[i]).normalized()


## Scene position of the trunk base.
func base() -> Vector3:
	return chunk.global_transform * xform.origin


## Scene-space bounding sphere of the handholds, as [center, radius].
func bounds() -> Array:
	if _bound_r < 0.0:
		var box := AABB()
		if local.size() > 0:
			box = AABB(local[0], Vector3.ZERO)
		for p in local:
			box = box.expand(p)
		_bound_c = box.get_center()
		_bound_r = box.size.length() * 0.5
	return [frame() * _bound_c, _bound_r]


## The handhold nearest `scene_pos` on wood at least `min_radius` thick,
## or -1 if there is none.
func nearest(scene_pos: Vector3, min_radius := 0.0) -> int:
	var p := frame().affine_inverse() * scene_pos
	var best := -1
	var best_d := INF
	for i in local.size():
		if radius[i] < min_radius:
			continue
		var d := local[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best
