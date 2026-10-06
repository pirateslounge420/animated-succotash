class_name Occluders
## Occlusion culling (design 6 Oct §ER.1, last): simple occluders the
## renderer rasterizes on the CPU to skip whatever stands fully behind
## them. Two kinds, never foliage:
##
##   * the ground: each chunk a coarse sheet of its terrain (a vertex every
##     STEP of its grid), every vertex the lowest ground within a step of it
##     and sunk SINK_M more, so the sheet stays under the real ground
##     everywhere and only hides what's behind a ridge or a hill;
##   * ruin walls: a box inside each run of standing wall columns
##     (RuinBuilder.wall()), up to the lowest column's top.
##
## data/look.json "occlusion": on (whether they're made and the viewport
## culls with them; OCCLUSION=0/1 in the environment overrides).

static var O: Dictionary = Tuning.section("look", "occlusion")
const STEP := 4
const SINK_M := 1.0


static func on() -> bool:
	var env := OS.get_environment("OCCLUSION")
	if env != "":
		return env != "0"
	return bool(O.get("on", false))


## The ground sheet's arrays for a chunk ([vertices, indices], chunk-local
## like its meshes), from its coarse grid (TerrainChunk.mesh_arrays()'s
## data). Thread-safe.
static func ground_sheet(data: Dictionary, quads: int, anchor_r: float) -> Array:
	var n := quads + 1
	var d: PackedVector3Array = data.dirs
	var hh: PackedFloat32Array = data.heights
	var center: Vector3 = data.center
	var m := quads / STEP + 1
	var verts := PackedVector3Array()
	verts.resize(m * m)
	for jj in m:
		for ii in m:
			var i0 := mini(ii * STEP, quads)
			var j0 := mini(jj * STEP, quads)
			var lo := INF
			for b in range(maxi(0, j0 - STEP), mini(n, j0 + STEP + 1)):
				for a in range(maxi(0, i0 - STEP), mini(n, i0 + STEP + 1)):
					lo = minf(lo, hh[b * n + a])
			var dd := d[j0 * n + i0]
			var r := PlanetConst.RADIUS_M + lo - SINK_M
			verts[jj * m + ii] = Vector3(dd.x * r - center.x * anchor_r, dd.y * r - center.y * anchor_r, dd.z * r - center.z * anchor_r)
	var idx := PackedInt32Array()
	for jj in m - 1:
		for ii in m - 1:
			var a := jj * m + ii
			idx.append_array([a, a + m, a + 1, a + 1, a + m, a + m + 1])
	return [verts, idx]


## An OccluderInstance3D for a sheet ([vertices, indices]).
static func sheet_node(sheet: Array) -> OccluderInstance3D:
	var occ := ArrayOccluder3D.new()
	occ.set_arrays(sheet[0], sheet[1])
	var oi := OccluderInstance3D.new()
	oi.name = "GroundOccluder"
	oi.occluder = occ
	return oi


## Box occluders under `parent` for [Transform3D, size] entries.
static func boxes(parent: Node3D, entries: Array) -> void:
	for e in entries:
		var b := BoxOccluder3D.new()
		b.size = e[1]
		var oi := OccluderInstance3D.new()
		oi.name = "WallOccluder"
		oi.occluder = b
		oi.transform = e[0]
		parent.add_child(oi)
