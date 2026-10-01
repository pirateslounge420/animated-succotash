class_name Coppice
## Coppicing (design 30 Sept §BP, technique coppice): cut a hazel or an
## ash to the stool and it throws straight poles again, on PlantGrowth's
## own clock (the species' curve: poles at pole_fraction of full height,
## which for a hazel is a few years, not a season). The cut tree leaves
## the chunk (its instance hidden, its wood colliders and graph gone),
## a stool stands at its foot and poles_per_cut branches lie round it;
## the stool grows new poles that the player cuts again (right click it
## with the technique). Kept per world (WorldSave "stools") and applied
## to a chunk as it builds.

static var P: Dictionary = Techniques.params("coppice")
static var stools := {} # chunk key string -> Array of records
static var _nodes := {} # record id -> Node3D


static func load_saved() -> void:
	stools.clear()
	var saved = WorldSave.data.get("stools", null)
	if saved is Dictionary:
		for k in saved:
			stools[k] = saved[k]
	WorldSave.data["stools"] = stools


## Can this species be coppiced: the genera the technique names, else
## any broadleaf canopy tree under fallback_max_height_m.
static func coppiceable(sp: PlantSpecies) -> bool:
	if sp == null:
		return false
	for g in P.get("genera", []):
		if sp.genus == str(g):
			return true
	return sp.tier == PlantSpecies.Tier.CANOPY and sp.deciduous and sp.height_m.y <= float(P.get("fallback_max_height_m", 25.0)) and sp.leaf_type.find("needle") < 0


## Cut tree `i` of `chunk` to the stool (the technique known, main).
static func cut(chunk: TerrainChunk, i: int, world: Node, days: float) -> Node3D:
	var sp := chunk.tree_species(i)
	var t: Array = chunk.trees[i]
	var pos: Vector3 = t[0]
	var scene := chunk.to_global(pos)
	var d: Vector3 = world.dir_of(scene)
	var key := str(chunk.key())
	if not stools.has(key):
		stools[key] = []
	var rec := {"i": i, "sp": SpeciesDB.index_of(sp), "day": days, "dir": [d.x, d.y, d.z], "cut": 1}
	(stools[key] as Array).append(rec)
	WorldSave.mark_dirty()
	apply_one(chunk, rec, world)
	# The poles: branches round the stool.
	for k in int(P.get("poles_per_cut", 3)):
		var off := CreatureSpawner._offset(d, k * TAU / 3.0 + 0.4, 1.2)
		WorldItem.drop(Inventory.make("fuel", {"fuel": "branch", "title": "Branch", "carry_items": 1}), world, off, chunk.height_at(off) if chunk.has_method("height_at") else world.surface_elevation(off))
	GameLog.add("Cut a %s to the stool; it will throw poles again." % sp.name.to_lower(), "technique")
	return _nodes.get(_id(key, rec), null)


static func _id(key: String, rec: Dictionary) -> String:
	return "%s:%d" % [key, int(rec.i)]


## Every stool of a chunk, as it builds (ChunkManager).
static func apply(chunk: TerrainChunk, world: Node) -> void:
	var key := str(chunk.key())
	if not stools.has(key):
		return
	for rec in stools[key]:
		apply_one(chunk, rec, world)


## Hide the tree's instances and drop its wood; stand the stool.
static func apply_one(chunk: TerrainChunk, rec: Dictionary, world: Node) -> void:
	var i := int(rec.i)
	if i < 0 or i >= chunk.trees.size():
		return
	var t: Array = chunk.trees[i]
	var sp_idx := int(rec.sp)
	# The far instance and the near layout instance: scaled to nothing.
	var zero := Transform3D(Basis.from_scale(Vector3(0.001, 0.001, 0.001)), t[0])
	for mm_dict in [chunk.tree_mm, chunk.layout_mm]:
		for k in mm_dict:
			var mmi = mm_dict[k]
			if mmi is MultiMeshInstance3D and (mmi as MultiMeshInstance3D).multimesh != null:
				var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
				var idx := int(t[2]) if mm_dict == chunk.tree_mm else int(t[4])
				if mm_dict == chunk.tree_mm and int(k) != sp_idx:
					continue
				if idx >= 0 and idx < mm.instance_count:
					var tf := mm.get_instance_transform(idx)
					if tf.origin.distance_to(t[0]) < 0.5:
						mm.set_instance_transform(idx, zero)
	chunk.remove_graph(i)
	chunk.remove_trunk_shapes(i)
	# The stool: a wide stump, and the poles growing from it.
	var id := _id(str(chunk.key()), rec)
	if _nodes.has(id) and is_instance_valid(_nodes[id]):
		(_nodes[id] as Node).queue_free()
	var n := Node3D.new()
	n.name = "Stool"
	chunk.add_child(n)
	n.position = t[0]
	var d: Vector3 = world.dir_of(chunk.to_global(t[0]))
	n.global_basis = Basis.looking_at(CubeSphere.north(d), d)
	var sp: PlantSpecies = SpeciesDB.all()[sp_idx] if sp_idx >= 0 and sp_idx < SpeciesDB.all().size() else null
	var r := clampf(float(t[1]) * 0.03, 0.18, 0.5)
	CreatureBodies.cone(n, r, r * 0.9, 0.4, Vector3(0, 0.2, 0), (sp.accent if sp else Color(0.4, 0.3, 0.2)), 0.0, 10)
	n.set_meta("rec", rec)
	n.set_meta("chunk_key", str(chunk.key()))
	_nodes[id] = n
	refresh(n, world.days)


## The poles' growth: the species' own curve from the cut day.
static func pole_fraction(rec: Dictionary, days: float) -> float:
	var sp_idx := int(rec.sp)
	var all := SpeciesDB.all()
	if sp_idx < 0 or sp_idx >= all.size():
		return 0.0
	var sp: PlantSpecies = all[sp_idx]
	var age_y := (days - float(rec.day)) / 365.0
	return clampf(PlantGrowth.fraction(sp, age_y) / maxf(float(P.get("pole_fraction", 0.3)), 0.01), 0.0, 1.0)


static func refresh(n: Node3D, days: float) -> void:
	for c in n.get_children():
		if c.name.begins_with("Pole"):
			c.queue_free()
	var rec: Dictionary = n.get_meta("rec")
	var f := pole_fraction(rec, days)
	var sp_idx := int(rec.sp)
	var all := SpeciesDB.all()
	var col: Color = (all[sp_idx] as PlantSpecies).leaf_color if sp_idx >= 0 and sp_idx < all.size() else Color(0.3, 0.5, 0.25)
	for k in 5:
		var h := 0.3 + 2.6 * f
		var p := CreatureBodies.cone(n, 0.03 + 0.02 * f, 0.015, h, Vector3(cos(k * 1.26) * 0.2, 0.35 + h * 0.5, sin(k * 1.26) * 0.2), Color(0.5, 0.4, 0.26), 0.0, 5)
		p.name = "Pole%d" % k
		p.rotation = Vector3(0.12 * sin(k * 1.26), 0, -0.12 * cos(k * 1.26))
		if f > 0.3:
			var leaf := CreatureBodies.ball(n, Vector3(0.25, 0.3, 0.25) * f, Vector3(cos(k * 1.26) * 0.3, 0.35 + h, sin(k * 1.26) * 0.3), col)
			leaf.name = "PoleLeaf%d" % k
	n.set_meta("ready", f >= 1.0)


static func ready(n: Node3D) -> bool:
	return bool(n.get_meta("ready", false))


## Cut the stool's poles again (the technique known): branches round it,
## the clock restarts.
static func harvest(n: Node3D, world: Node, days: float) -> void:
	var rec: Dictionary = n.get_meta("rec")
	rec.day = days
	rec.cut = int(rec.get("cut", 1)) + 1
	WorldSave.mark_dirty()
	var a: Array = rec.dir
	var d := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
	for k in int(P.get("poles_per_cut", 3)):
		var off := CreatureSpawner._offset(d, k * TAU / 3.0 + 0.4, 1.2)
		WorldItem.drop(Inventory.make("fuel", {"fuel": "branch", "title": "Branch", "carry_items": 1}), world, off, world.surface_elevation(off))
	refresh(n, days)
	GameLog.add("Cut the stool's poles.", "technique")


## The stool within `radius` of `pos`, or null.
static func in_reach(pos: Vector3, radius: float) -> Node3D:
	for id in _nodes:
		var n = _nodes[id]
		if n is Node3D and is_instance_valid(n) and (n as Node3D).is_inside_tree() and (n as Node3D).global_position.distance_to(pos) < radius:
			return n
	return null
