extends SceneTree
## Wood lit from the right side (Mike's 3 Oct 14:34 play, bug 4 in
## PROGRESS 15:00): every closed wood part's normals point outward.
##   godot --headless --path . --script tools/wood_normals_check.gd
## Builds every species' plant meshes (each level; every layout of the
## branchy trees) and, for each closed part of bark (UV2.x 0) or a bamboo
## culm (4), sums area x (normal . (face centre - the part's centre)) over
## its faces: the divergence theorem makes it 3 x the part's volume when the
## normals point out and minus that when they point in (open tube ends and
## caps only nudge it). Asserts every part's sum is positive. Also checks
## the faces' winding still runs the same way round as before (the shadow
## pass's far-face rule, foliage.gdshader, now reads the normal, not the
## winding, so a mirrored tree casts the same; this is reported, not asserted).
## SPECIES=n caps how many species (default all); ONLY=name checks the
## species whose names contain it.

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _run() -> void:
	var all := SpeciesDB.all()
	PlantMeshes.use_seed(42)
	var cap := int(OS.get_environment("SPECIES")) if OS.get_environment("SPECIES") != "" else all.size()
	var parts_n := {0: 0, 4: 0}
	var bad := {0: 0, 4: 0}
	var wound_in := 0
	var faces := 0
	var examples: Array[String] = []
	var only := OS.get_environment("ONLY")
	for i in mini(cap, all.size()):
		var sp: PlantSpecies = all[i]
		if only != "" and not sp.name.contains(only):
			continue
		var meshes: Array = []
		for lod in [PlantMeshes.LOD_NEAR, PlantMeshes.LOD_HERO]:
			if TreeLayouts.branchy(sp):
				for layout in TreeLayouts.COUNT:
					meshes.append(["%s L%d #%d" % [sp.name, lod, layout], PlantMeshes.arrays_for(sp, lod, layout)])
			else:
				meshes.append(["%s L%d" % [sp.name, lod], PlantMeshes.arrays_for(sp, lod)])
		for m in meshes:
			var arr: Array = m[1]
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
			if v.is_empty() or uv2.size() != v.size():
				continue
			# Faces by part: a part is a run of faces of one wood material
			# sharing vertices (the builder's smoothing groups aren't in
			# the arrays), so join faces that touch.
			var by_mat := {0: [], 4: []}
			for t in range(0, v.size(), 3):
				var mt := int(round(uv2[t].x))
				if mt == 0 or mt == 4:
					(by_mat[mt] as Array).append(t)
			for mt in by_mat:
				for part in _parts(v, by_mat[mt]):
					var centre := Vector3.ZERO
					var w := 0.0
					for t in part:
						var a := ((v[t + 1] - v[t]).cross(v[t + 2] - v[t])).length() * 0.5
						centre += (v[t] + v[t + 1] + v[t + 2]) / 3.0 * a
						w += a
					if w <= 1e-9:
						continue
					centre /= w
					var flux := 0.0
					var wind := 0.0
					for t in part:
						var c := (v[t] + v[t + 1] + v[t + 2]) / 3.0
						var fn := (v[t + 1] - v[t]).cross(v[t + 2] - v[t])
						var area := fn.length() * 0.5
						var nrm := (nn[t] + nn[t + 1] + nn[t + 2]).normalized()
						flux += area * nrm.dot(c - centre)
						wind += fn.dot(c - centre)
					parts_n[mt] = int(parts_n[mt]) + 1
					faces += part.size()
					if wind < 0.0:
						wound_in += 1
					if flux <= 0.0:
						bad[mt] = int(bad[mt]) + 1
						if examples.size() < 8:
							examples.append("%s (%s, %d faces)" % [m[0], "bark" if mt == 0 else "culm", part.size()])
	print("[wood] %d bark parts, %d culm parts, %d faces; %d parts wound with (b-a)x(c-a) pointing in" % [parts_n[0], parts_n[4], faces, wound_in])
	for e in examples:
		print("[wood]   inward: " + e)
	ok(int(bad[0]) == 0, "every bark part's normals point outward (%d of %d inward)" % [int(bad[0]), int(parts_n[0])])
	ok(int(bad[4]) == 0, "every bamboo culm's normals point outward (%d of %d inward)" % [int(bad[4]), int(parts_n[4])])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Join faces (start indices) that share a vertex position into parts.
func _parts(v: PackedVector3Array, tris: Array) -> Array:
	var owner := {}
	var parent := {}
	for t in tris:
		parent[t] = t
	for t in tris:
		for k in 3:
			var q := Vector3i(v[t + k] * 20000.0)
			if owner.has(q):
				_union(parent, t, owner[q])
			else:
				owner[q] = t
	var groups := {}
	for t in tris:
		var r := _find(parent, t)
		(groups.get_or_add(r, []) as Array).append(t)
	return groups.values()


func _find(parent: Dictionary, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


func _union(parent: Dictionary, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb
