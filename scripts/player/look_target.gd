class_name LookTarget
extends Node
## What the crosshair rests on, named (the HUD shows it under the
## crosshair): the binomial of the animal, tree or plant you're looking at
## as you come near it ("Quercus robur", from the species tables' `genus`
## and `species`, spec D4).
##
## What it reads: the crosshair ray (PlanetPlayer.crosshair_point()'s
## start and direction); one physics ray for creatures' and people's
## hitbox parts (Hitboxes: the creature's species), tree trunks and limbs
## (TerrainChunk.tree_for_shape(): the tree's species) and the ground,
## which hides what's behind it; and, for the plants that have no collider
## (shrubs, ferns, grasses, epiphytes), their MultiMesh instances in the
## chunks round the player, each taken as an upright capsule as tall as the
## plant. Those are indexed once per MultiMesh into a coarse grid, a few
## thousand instances a frame, so a look is only a handful of cells.
## What it writes: `text` (and `kind`), and for a plant or tree its
## species index and the point looked at (`species_index`, `point`: E takes
## a sample, Inventory), nothing else.
##
## Animals are named out to ANIMAL_M from you, trees out to TREE_M, other
## plants out to PLANT_M; the name lingers LINGER_S after the crosshair
## leaves, so it doesn't flicker at a leaf's edge.

const ANIMAL_M := 40.0
const TREE_M := 20.0
const PLANT_M := 8.0
const LINGER_S := 0.35
const LOOK_EVERY_S := 0.1
## Grid cell (m) for the plant index, and instances indexed per frame.
const CELL_M := 6.0
const INDEX_BUDGET := 3000
## Chunks whose middle is this close to the player are indexed.
const CHUNK_NEAR_M := 220.0

## The binomial under the crosshair, or "".
var text := ""
## "animal", "tree", "plant" or "".
var kind := ""
## The plant's or tree's SpeciesDB index (-1 otherwise) and the point on
## it the crosshair rests on (scene position).
var species_index := -1
var point := Vector3.INF

var player: PlanetPlayer
var chunks: ChunkManager
var _timer := 0.0
var _linger := 0.0
## MultiMeshInstance3D instance id -> {mmi, sp, buf, n, next, cells}
var _index := {}
var _todo: Array = [] # ids still being indexed


func setup(p: PlanetPlayer, c: ChunkManager) -> void:
	player = p
	chunks = c


func _process(delta: float) -> void:
	if player == null or chunks == null:
		return
	_index_some()
	_timer -= delta
	_linger -= delta
	if _timer > 0.0:
		return
	_timer = LOOK_EVERY_S
	var found := _look()
	if found.is_empty():
		if _linger <= 0.0:
			text = ""
			kind = ""
			species_index = -1
			point = Vector3.INF
	else:
		text = found[0]
		kind = found[1]
		species_index = found[2] if found.size() > 2 else -1
		point = found[3] if found.size() > 3 else Vector3.INF
		_linger = LINGER_S


## [binomial, kind, species index (plants and trees, else -1), point]
## under the crosshair now, or [].
func _look() -> Array:
	var cam := player.camera()
	if cam == null:
		return []
	var from := cam.global_position + cam.global_basis.x * cam.h_offset + cam.global_basis.y * cam.v_offset
	var dir := -cam.global_basis.z
	var me := player.global_position
	var reach := from.distance_to(me) + ANIMAL_M
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach)
	q.exclude = [player.get_rid()]
	q.collision_mask |= Hitboxes.LAYER
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var block_t := reach
	var best := []
	if not hit.is_empty():
		var at: Vector3 = hit.position
		block_t = from.distance_to(at)
		var obj := Hitboxes.creature_of(hit.collider)
		if obj != null:
			var sp = obj.get("species")
			if sp == null and obj.get_parent() != null:
				sp = obj.get_parent().get("species")
			if sp is CreatureSpecies and at.distance_to(me) <= ANIMAL_M and (sp as CreatureSpecies).binomial() != "":
				best = [(sp as CreatureSpecies).binomial(), "animal"]
		else:
			var chunk := (hit.collider as Node).get_parent() as TerrainChunk if hit.collider is Node else null
			if chunk != null and at.distance_to(me) <= TREE_M:
				var i := chunk.tree_for_shape(hit.collider, int(hit.shape))
				if i >= 0:
					var tsp: PlantSpecies = SpeciesDB.all()[int(chunk.trees[i][2])]
					if tsp.binomial() != "":
						best = [tsp.binomial(), "tree"]
	# Plants without colliders, in front of whatever the ray hit: the
	# nearer of the two is what you're looking at.
	var plant := _plant_on_ray(from, dir, block_t + 0.3, me)
	if not plant.is_empty() and (best.is_empty() or float(plant[2]) < block_t):
		return [plant[0], plant[1], plant[3], from + dir * float(plant[2])]
	return best


## The nearest indexed plant (not a tree) the ray passes through within
## `length` of `from` and PLANT_M of the player, as [binomial, "plant",
## distance along the ray, species index].
func _plant_on_ray(from: Vector3, dir: Vector3, length: float, me: Vector3) -> Array:
	var best_t := INF
	var best_sp := -1
	for id in _index:
		var e: Dictionary = _index[id]
		var mmi: MultiMeshInstance3D = e.mmi
		if not is_instance_valid(mmi) or not mmi.is_visible_in_tree():
			continue
		var inv := mmi.global_transform.affine_inverse()
		var o := inv * from
		var d := (inv.basis * dir).normalized()
		var me_l := inv * me
		# Only the part of the ray within PLANT_M of the player.
		var t0 := maxf(0.0, (me_l - o).dot(d) - PLANT_M)
		var t1 := minf(length, (me_l - o).dot(d) + PLANT_M)
		if t1 <= t0:
			continue
		var a := o + d * t0
		var b := o + d * t1
		var lo := Vector3i(((a.min(b) - Vector3.ONE * 3.0) / CELL_M).floor())
		var hi := Vector3i(((a.max(b) + Vector3.ONE * 3.0) / CELL_M).floor())
		var cells: Dictionary = e.cells
		var buf: PackedFloat32Array = e.buf
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					var list = cells.get(Vector3i(x, y, z))
					if list == null:
						continue
					for k in (list as PackedInt32Array):
						var j := k * 20
						var base := Vector3(buf[j + 3], buf[j + 7], buf[j + 11])
						var up := Vector3(buf[j + 1], buf[j + 5], buf[j + 9]) # the scaled y column: height
						var h := up.length()
						var r := clampf(h * 0.4, 0.15, 2.5)
						var st := _segment_hit(o, d, t0, t1, base, base + up * 0.9, r)
						if st >= 0.0 and st < best_t and (o + d * st).distance_to(me_l) <= PLANT_M:
							best_t = st
							best_sp = e.sp
	if best_sp < 0:
		return []
	var sp: PlantSpecies = SpeciesDB.all()[best_sp]
	return [] if sp.binomial() == "" else [sp.binomial(), "plant", best_t, best_sp]


## Where along the ray (o + d t, t in [t0, t1], d unit) it passes within
## `r` of the segment p0-p1, as t; -1 if it doesn't.
static func _segment_hit(o: Vector3, d: Vector3, t0: float, t1: float, p0: Vector3, p1: Vector3, r: float) -> float:
	var u := p1 - p0
	var w := o - p0
	var b := d.dot(u)
	var c := u.dot(u)
	var dd := d.dot(w)
	var e := u.dot(w)
	var den := c - b * b
	var t := t0
	if den > 1e-6:
		t = (b * e - c * dd) / den
	t = clampf(t, t0, t1)
	var s := clampf((b * t + e) / maxf(c, 1e-6), 0.0, 1.0)
	# Refine the ray point for the clamped segment point.
	t = clampf((p0 + u * s - o).dot(d), t0, t1)
	var dist := (o + d * t).distance_to(p0 + u * s)
	return t if dist <= r else -1.0


## Index the plant MultiMeshes of the chunks round the player, a few
## thousand instances a frame; forget the ones that are gone.
func _index_some() -> void:
	for id in _index.keys():
		if not is_instance_valid(_index[id].mmi):
			_index.erase(id)
	if _todo.is_empty():
		_find_new()
	var budget := INDEX_BUDGET
	while budget > 0 and not _todo.is_empty():
		var id: int = _todo[0]
		if not _index.has(id) or not is_instance_valid(_index[id].mmi):
			_todo.pop_front()
			_index.erase(id)
			continue
		var e: Dictionary = _index[id]
		var buf: PackedFloat32Array = e.buf
		var n: int = e.n
		var cells: Dictionary = e.cells
		var k: int = e.next
		var stop := mini(n, k + budget)
		while k < stop:
			var j := k * 20
			var key := Vector3i((Vector3(buf[j + 3], buf[j + 7], buf[j + 11]) / CELL_M).floor())
			# Packed arrays are values: take it out, add to it, put it back.
			var list: PackedInt32Array = cells.get(key, PackedInt32Array())
			list.append(k)
			cells[key] = list
			k += 1
		budget -= stop - e.next
		e.next = k
		if k >= n:
			_todo.pop_front()


## New plant MultiMeshes (not trees) in the chunks near the player.
func _find_new() -> void:
	var me := player.global_position
	for c in chunks.chunks.values():
		var chunk := c as TerrainChunk
		if chunk == null or chunk.global_position.distance_to(me) > CHUNK_NEAR_M:
			continue
		var stack: Array = [chunk]
		if chunk.detail_node != null:
			stack.append(chunk.detail_node)
		for parent in stack:
			for ch in (parent as Node).get_children():
				var mmi := ch as MultiMeshInstance3D
				if mmi == null or not mmi.has_meta("species") or _index.has(mmi.get_instance_id()):
					continue
				var sp_idx: int = mmi.get_meta("species")
				var sp: PlantSpecies = SpeciesDB.all()[sp_idx]
				# Trees are named through their trunk colliders.
				if sp.tier == PlantSpecies.Tier.EMERGENT or sp.tier == PlantSpecies.Tier.CANOPY:
					continue
				var mm := mmi.multimesh
				if mm == null or mm.instance_count == 0 or not mm.use_custom_data or not mm.use_colors:
					continue
				_index[mmi.get_instance_id()] = {"mmi": mmi, "sp": sp_idx, "buf": mm.buffer, "n": mm.instance_count, "next": 0, "cells": {}}
				_todo.append(mmi.get_instance_id())
