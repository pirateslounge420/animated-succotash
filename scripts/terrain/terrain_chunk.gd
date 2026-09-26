class_name TerrainChunk
extends Node3D
## One walkable patch of the planet surface (~260 m square), smooth shaded
## like GameCube-era terrain: shared vertices with normals averaged from
## the surrounding ground.
##
## Two levels of detail from one fine height grid (64 x 64 quads of ~4 m):
## chunks in the ring nearest the player show all of it, farther chunks
## every other vertex (32 x 32 quads of ~8 m). Along chunk edges the fine
## mesh's in-between vertices sit on the straight 8 m edge, so a fine chunk
## meets a coarse neighbor without cracks. Normals come from the fine grid
## padded one vertex past the chunk edge, so both chunks along an edge
## compute the same normal there and no seam shows. Heights for placing
## plants and creatures (height_at) and collision use the fine grid.
##
## Chunks tile the cube-sphere: face `face`, chunk (ci, cj) of
## CHUNKS_PER_FACE per face edge. Heights come from the same continuous
## TerrainField as the planet blueprint (plus the fine detail layer), so
## neighbors, including across cube-face edges, meet without seams.
##
## compute() is a pure function of read-only planet data so it can run on a
## worker thread; build_nodes() then turns its result into meshes on the
## main thread. Vertex positions are relative to the chunk's own anchor
## point, which keeps 32-bit float precision on a 64 km planet.
##
## Also carved in here: river channels and water ribbons (RiverNetwork),
## lake and sea surfaces, and ground color: the blend of nearby biome
## colors, plus local sand at the shore, bare rock on steep faces, and snow
## wherever it's below freezing at that exact height.

const CHUNKS_PER_FACE := 384
const QUADS := 32 # coarse quads per edge (~8 m); the data grids use these
const FINE := QUADS * 2 # fine quads per edge (~4 m), for the near mesh
const WATER_QUADS := 16
const BANK_M := 12.0

const SAND := Color(0.9, 0.84, 0.64)
const ROCK := Color(0.46, 0.45, 0.44)
const SNOW := Color(0.93, 0.95, 1.0)
const WET_BANK := Color(0.28, 0.3, 0.22)
const SEABED := Color(0.32, 0.42, 0.4)

var face: int
var ci: int
var cj: int
var center_dir: Vector3
var anchor_radius: float
## Per-vertex data kept for vegetation and creature placement (coarse
## grid), and the fine heights the ground is drawn and walked on.
var dirs := PackedVector3Array()
var heights := PackedFloat32Array()
var fine_heights := PackedFloat32Array()
var _coarse_mesh: MeshInstance3D
var _fine_mesh: MeshInstance3D
## What the plants are drawn at (PlantMeshes.LOD_*): trees start light.
var _plant_lod := PlantMeshes.LOD_FAR
## Ground collision (build_collision_part): triangles not yet built into
## it, the body, and how many strips it has.
const COLLISION_PARTS := 4
var _col_faces := PackedVector3Array()
var _col_body: StaticBody3D
var _col_parts := 0
## Canopy and emergent trees on this chunk: [local_position, height,
## species_index, instance]. Canopy-dwelling creatures attach to these.
var trees: Array = []
## species index -> the MultiMesh drawing that species' trees here.
var tree_mm := {}
## Raw compute() output and tree hosts, kept so the undergrowth layer can
## be computed later when the player comes close.
var data: Dictionary
var hosts: Array = []
var detail_node: Node3D

## Physics layer (bit value) of tree trunks, besides the default layer 1,
## so queries can look for trees alone.
const TREE_LAYER := 2
# Trunk colliders, only while the chunk is in the detail ring: one static
# body, one cylinder shape owner per tree, built a few hundred per frame.
var _tree_body: StaticBody3D
var _tree_next := 0
var _owner_tree := {} # shape owner id -> index in trees
static var _cylinders := {}


static func key_of(face_i: int, i: int, j: int) -> Vector3i:
	return Vector3i(face_i, i, j)


## Chunk under a surface direction.
static func key_at(d: Vector3) -> Vector3i:
	var f := CubeSphere.face_of(d)
	var uv := CubeSphere.face_uv(f, d)
	var i := clampi(int((uv.x + 1.0) * 0.5 * CHUNKS_PER_FACE), 0, CHUNKS_PER_FACE - 1)
	var j := clampi(int((uv.y + 1.0) * 0.5 * CHUNKS_PER_FACE), 0, CHUNKS_PER_FACE - 1)
	return Vector3i(f, i, j)


static func _uv(chunk: int, q: int) -> float:
	return -1.0 + 2.0 * float(chunk * QUADS + q) / float(CHUNKS_PER_FACE * QUADS)


static func _uvf(chunk: int, q: int) -> float:
	return -1.0 + 2.0 * float(chunk * FINE + q) / float(CHUNKS_PER_FACE * FINE)


static func center_of(key: Vector3i) -> Vector3:
	return CubeSphere.to_dir(key.x, _uv(key.y, QUADS / 2), _uv(key.z, QUADS / 2))


## Pure computation (thread-safe). Returns a Dictionary consumed by
## build_nodes() and VegetationPlacer.
static func compute(key: Vector3i, map: PlanetData, rivers: RiverNetwork) -> Dictionary:
	var n := QUADS + 1
	var nf := FINE + 1
	var dirs_out := PackedVector3Array()
	var h := PackedFloat32Array()
	var river_dist := PackedFloat32Array()
	var level := PackedFloat32Array()
	var salt := PackedByteArray()
	dirs_out.resize(n * n)
	h.resize(n * n)
	river_dist.resize(n * n)
	level.resize(n * n)
	salt.resize(n * n)
	var fine_d := PackedVector3Array()
	var fine_h := PackedFloat32Array()
	fine_d.resize(nf * nf)
	fine_h.resize(nf * nf)
	var center := center_of(key)
	var segs := rivers.segments_near(map, map.cell_at(center))
	# Fine heights on the grid padded by one vertex all round (for normals).
	var pn := nf + 2
	var pad_h := PackedFloat32Array()
	var pad_d := PackedVector3Array()
	pad_h.resize(pn * pn)
	pad_d.resize(pn * pn)

	for jj in range(-1, nf + 1):
		for ii in range(-1, nf + 1):
			var d := CubeSphere.to_dir(key.x, _uvf(key.y, ii), _uvf(key.z, jj))
			var e := map.terrain.elevation(d, true)
			var inside := ii >= 0 and jj >= 0 and ii < nf and jj < nf
			var coarse := inside and ii % 2 == 0 and jj % 2 == 0
			var wl := _standing_water(map, d) if coarse else Vector2.ZERO
			var nearest := 1e6
			for s in segs:
				# Distance first; the water level only where it matters.
				var dt := rivers.closest_dt(s, d)
				nearest = minf(nearest, dt.x)
				var half := rivers.width[s] * 0.5
				if dt.x < half + BANK_M:
					var lvl := rivers.level_at(s, dt.y)
					var bed := lvl - rivers.depth[s]
					# Through high ground the banks steepen into gorge walls.
					var bank := lerpf(BANK_M, 3.0, smoothstep(4.0, 14.0, e - bed))
					var f := 1.0 - smoothstep(half, half + bank, dt.x)
					e = lerpf(e, minf(e, bed) if dt.x > half else bed, f)
					if dt.x < half:
						wl = Vector2(maxf(wl.x, lvl), 1.0 if rivers.salty[s] == 1 else 0.0)
			var pi := (jj + 1) * pn + ii + 1
			pad_h[pi] = e
			pad_d[pi] = d
			if inside:
				fine_d[jj * nf + ii] = d
				fine_h[jj * nf + ii] = e
			if coarse:
				var i := (jj / 2) * n + ii / 2
				dirs_out[i] = d
				h[i] = e
				river_dist[i] = nearest
				level[i] = wl.x
				salt[i] = int(wl.y)

	var falls := []
	var fine_n := _smooth_normals(center, pad_d, pad_h, nf)
	_snap_edges(fine_h, fine_n, nf)
	var normals := PackedVector3Array()
	normals.resize(n * n)
	for jj in n:
		for ii in n:
			normals[jj * n + ii] = fine_n[(jj * 2) * nf + ii * 2]
	return {
		"key": key,
		"center": center,
		"dirs": dirs_out,
		"heights": h,
		"normals": normals,
		"fine_dirs": fine_d,
		"fine_heights": fine_h,
		"fine_normals": fine_n,
		"river_dist": river_dist,
		"water_level": level,
		"salt": salt,
		"colors": _vertex_colors(map, dirs_out, h, normals),
		"water": _water_quads(key, dirs_out, fine_h, level, salt),
		"rivers": _river_ribbons(key, center, rivers, segs, falls),
		"falls": falls,
	}


## The fine grid's in-between vertices along the chunk edges move onto the
## straight edge between their neighbors (height and normal), so the fine
## mesh meets a coarse neighbor's 8 m edge exactly.
static func _snap_edges(fh: PackedFloat32Array, fn: PackedVector3Array, nf: int) -> void:
	for k in range(1, nf - 1, 2):
		for idx in [[k, 0, 1, 0], [k, nf - 1, 1, 0], [0, k, 0, 1], [nf - 1, k, 0, 1]]:
			var i: int = idx[1] * nf + idx[0]
			var step: int = idx[2] + idx[3] * nf
			fh[i] = (fh[i - step] + fh[i + step]) * 0.5
			fn[i] = (fn[i - step] + fn[i + step]).normalized()


## Mesh arrays for one level of detail, positions relative to the chunk's
## anchor (center at `anchor_r` from the planet center). Worker-thread safe.
static func mesh_arrays(data: Dictionary, fine: bool, anchor_r: float) -> Array:
	var q := FINE if fine else QUADS
	var n := q + 1
	var d: PackedVector3Array = data.fine_dirs if fine else data.dirs
	var hh: PackedFloat32Array = data.fine_heights if fine else data.heights
	var nrm: PackedVector3Array = data.fine_normals if fine else data.normals
	var center: Vector3 = data.center
	var east := CubeSphere.east(center)
	var north := CubeSphere.north(center)
	var local := PackedVector3Array()
	var uvs := PackedVector2Array()
	local.resize(n * n)
	uvs.resize(n * n)
	for i in n * n:
		var r := PlanetConst.RADIUS_M + hh[i]
		# Differences in double precision before storing (float32 vectors).
		var p := Vector3(d[i].x * r - center.x * anchor_r, d[i].y * r - center.y * anchor_r, d[i].z * r - center.z * anchor_r)
		local[i] = p
		# Texture coordinates in meters on the chunk's tangent plane.
		uvs[i] = Vector2(p.dot(east), p.dot(north))
	var colors: PackedColorArray = data.colors
	if fine:
		# The coarse colors (with baked shade), interpolated.
		var cn := QUADS + 1
		var fc := PackedColorArray()
		fc.resize(n * n)
		for jj in n:
			for ii in n:
				var i0 := mini(ii / 2, QUADS - 1)
				var j0 := mini(jj / 2, QUADS - 1)
				var tx := ii * 0.5 - i0
				var ty := jj * 0.5 - j0
				var a := colors[j0 * cn + i0].lerp(colors[j0 * cn + i0 + 1], tx)
				var b := colors[(j0 + 1) * cn + i0].lerp(colors[(j0 + 1) * cn + i0 + 1], tx)
				fc[jj * n + ii] = a.lerp(b, ty)
		colors = fc
	var indices := PackedInt32Array()
	indices.resize(q * q * 6)
	var k := 0
	for jj in q:
		for ii in q:
			var i00 := jj * n + ii
			var i01 := i00 + n
			indices[k] = i00
			indices[k + 1] = i01 + 1
			indices[k + 2] = i00 + 1
			indices[k + 3] = i00
			indices[k + 4] = i01
			indices[k + 5] = i01 + 1
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = local
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


## Both meshes' arrays and the (fine) collision faces, computed on the
## worker after the canopy shade is baked into the colors.
static func prepare_meshes(data: Dictionary) -> void:
	var mid := (QUADS / 2) * (QUADS + 1) + QUADS / 2
	var anchor_r := PlanetConst.RADIUS_M + (data.heights as PackedFloat32Array)[mid]
	data["anchor_r"] = anchor_r
	data["mesh_coarse"] = mesh_arrays(data, false, anchor_r)
	var fine := mesh_arrays(data, true, anchor_r)
	data["mesh_fine"] = fine
	var local: PackedVector3Array = fine[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = fine[Mesh.ARRAY_INDEX]
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for k in indices.size():
		faces[k] = local[indices[k]]
	data["faces"] = faces


## Vertex normals from central differences on the padded grid (`pd`, `ph`
## are (n + 2)^2). Neighboring chunks sample the same points along their
## shared edge, so their normals there agree.
static func _smooth_normals(center: Vector3, pd: PackedVector3Array, ph: PackedFloat32Array, n: int) -> PackedVector3Array:
	var pn := n + 2
	var pos := PackedVector3Array()
	pos.resize(pn * pn)
	for i in pn * pn:
		# Relative to the chunk center, for float precision.
		pos[i] = (pd[i] - center) * PlanetConst.RADIUS_M + pd[i] * ph[i]
	var out := PackedVector3Array()
	out.resize(n * n)
	for jj in n:
		for ii in n:
			var c := (jj + 1) * pn + ii + 1
			var nrm := (pos[c + 1] - pos[c - 1]).cross(pos[c + pn] - pos[c - pn]).normalized()
			if nrm.dot(pd[c]) < 0.0:
				nrm = -nrm
			out[jj * n + ii] = nrm
	return out


## Standing water surface over a point: (level_m, salt 1/0). Lakes use their
## filled level; wetland biomes (swamp, marsh, bog, fen, salt marsh,
## mangrove) get a shallow water table just above the smooth terrain, so
## local dips become pools; everywhere else it's the sea, which only shows
## where the ground dips below sea level.
static func _standing_water(map: PlanetData, d: Vector3) -> Vector2:
	var cell := map.cell_at(d)
	var lake := _lake_level_near(map, cell)
	if not is_nan(lake):
		return Vector2(lake, 1.0 if map.salinity[cell] == PlanetData.Salinity.SALT else 0.0)
	var b := map.biome[cell]
	if b == BiomeTemplates.MANGROVE or b == BiomeTemplates.SALT_MARSH:
		return Vector2(PlanetConst.SEA_LEVEL_M + 0.4, 1.0)
	if b in WETLANDS:
		return Vector2(map.terrain.elevation(d, false) + 0.35, 0.0)
	return Vector2(PlanetConst.SEA_LEVEL_M, 1.0)


const WETLANDS := [
	BiomeTemplates.SWAMP, BiomeTemplates.FRESHWATER_MARSH, BiomeTemplates.WET_MEADOW,
	BiomeTemplates.BOG, BiomeTemplates.FEN, BiomeTemplates.FLOODPLAIN_FOREST,
]


static func _vertex_colors(map: PlanetData, d: PackedVector3Array, h: PackedFloat32Array, normals: PackedVector3Array) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(d.size())
	for i in d.size():
		var dir := d[i]
		# One set of interpolation weights for every per-cell value here.
		var w := map.weights_at(dir)
		var col := _biome_blend(map, dir, w)
		var e := h[i]
		# Snow wherever it's below freezing at this exact height.
		var t := map.sample_w(map.temp_c, w) + (map.sample_w(map.elevation, w) - e) * PlanetConst.LAPSE_RATE_C_PER_M
		col = col.lerp(SNOW, smoothstep(-0.5, -3.5, t))
		col = col.lerp(SAND, _sand_from(e, map.sample_w(map.coast_dist_km, w)) if e < 3.0 else 0.0)
		if e < 0.0:
			col = col.lerp(SEABED, smoothstep(0.0, -8.0, e))
		# Bare rock on steep ground (not under snow).
		var steep := 1.0 - normals[i].dot(dir)
		col = col.lerp(ROCK, smoothstep(0.3, 0.5, steep) * (1.0 - smoothstep(0.85, 0.95, col.b)))
		out[i] = col
	_bake_hollow_ao(h, out)
	return out


## 0-1 how much the ground at `d` (height `e`) is beach sand: low ground
## near the sea. VegetationPlacer keeps all but salt-tolerant plants off it.
static func sand_amount(map: PlanetData, d: Vector3, e: float) -> float:
	if e >= 3.0:
		return 0.0
	return _sand_from(e, map.sample(map.coast_dist_km, d))


static func _sand_from(e: float, coast_km: float) -> float:
	if e >= 3.0 or coast_km >= 1.5:
		return 0.0
	return smoothstep(3.0, 0.8, e)


## Baked ambient occlusion for hollows: a vertex lower than the ring of
## vertices around it (dips, gullies, river channels) is darkened, up to
## 35% for a 6 m deep hollow. Hard per-face darkening that fits the flat
## look and works in every renderer (there is no screen-space AO).
static func _bake_hollow_ao(h: PackedFloat32Array, cols: PackedColorArray) -> void:
	var n := QUADS + 1
	for jj in n:
		for ii in n:
			var sum := 0.0
			var cnt := 0
			for dj in [-1, 0, 1]:
				for di in [-1, 0, 1]:
					var x: int = ii + di
					var y: int = jj + dj
					if (di != 0 or dj != 0) and x >= 0 and y >= 0 and x < n and y < n:
						sum += h[y * n + x]
						cnt += 1
			var i := jj * n + ii
			var depth := sum / cnt - h[i]
			var k := 1.0 - clampf(depth / 6.0, 0.0, 1.0) * 0.35
			var c := cols[i]
			cols[i] = Color(c.r * k, c.g * k, c.b * k, c.a)


## Baked canopy shade: ground under tree crowns is darkened (called after
## the trees are placed, before the mesh is built). Worker-thread safe.
static func bake_canopy_shade(data: Dictionary, hosts: Array) -> void:
	var key: Vector3i = data.key
	var cols: PackedColorArray = data.colors
	var n := QUADS + 1
	var quad_m := PlanetConst.CIRCUMFERENCE_M / 4.0 / CHUNKS_PER_FACE / QUADS
	var shade := PackedFloat32Array()
	shade.resize(n * n)
	for host in hosts:
		var uv := CubeSphere.face_uv(key.x, host[0])
		var gx := (uv.x + 1.0) * 0.5 * CHUNKS_PER_FACE * QUADS - key.y * QUADS
		var gy := (uv.y + 1.0) * 0.5 * CHUNKS_PER_FACE * QUADS - key.z * QUADS
		var r: float = maxf(float(host[2]) * 0.3, 2.0) / quad_m # crown radius in quads
		for y in range(maxi(0, int(gy - r)), mini(n, int(gy + r) + 2)):
			for x in range(maxi(0, int(gx - r)), mini(n, int(gx + r) + 2)):
				var d := Vector2(x - gx, y - gy).length() / r
				if d < 1.0:
					shade[y * n + x] = maxf(shade[y * n + x], 1.0 - d * d)
	for i in n * n:
		if shade[i] > 0.0:
			var k := 1.0 - 0.3 * shade[i]
			var c := cols[i]
			cols[i] = Color(c.r * k, c.g * k, c.b * k, c.a)


## Bilinear blend of the four nearest blueprint cells' biome colors, so
## biome borders fade across the ground instead of snapping.
static func _biome_blend(map: PlanetData, d: Vector3, weights: Array = []) -> Color:
	var w := weights if not weights.is_empty() else map.weights_at(d)
	var cells: PackedInt32Array = w[0]
	var k: PackedFloat32Array = w[1]
	var col := Color(0, 0, 0)
	for i in cells.size():
		col += _ground_color(map, cells[i]) * k[i]
	col.a = 1.0
	return col


## Ground color of a cell: its biome color, except water cells borrow a
## muted shore tone (their water surface is drawn separately).
static func _ground_color(map: PlanetData, c: int) -> Color:
	var b := map.biome[c]
	if BiomeTemplates.is_ocean(b) or b == BiomeTemplates.FRESHWATER or b == BiomeTemplates.LAGOON:
		return Color(0.5, 0.55, 0.42)
	return BiomeTemplates.color_of(b)


## Water surface quads (sea, lakes, wetland pools) wherever the ground dips
## below the local standing-water level. Each is [d00, d10, d11, d01,
## radius, salt].
static func _water_quads(key: Vector3i, d: PackedVector3Array, fine_h: PackedFloat32Array,
		level: PackedFloat32Array, salt: PackedByteArray) -> Array:
	var quads := []
	var n := QUADS + 1
	var nf := FINE + 1
	var step := QUADS / WATER_QUADS
	for wj in WATER_QUADS:
		for wi in WATER_QUADS:
			var ii := wi * step
			var jj := wj * step
			var mid := (jj + step / 2) * n + (ii + step / 2)
			var wl := level[mid]
			var lowest := INF
			for dj in step * 2 + 1:
				for di in step * 2 + 1:
					lowest = minf(lowest, fine_h[(jj * 2 + dj) * nf + (ii * 2 + di)])
			if lowest >= wl:
				continue
			quads.append([
				d[jj * n + ii], d[jj * n + ii + step],
				d[(jj + step) * n + ii + step], d[(jj + step) * n + ii],
				PlanetConst.RADIUS_M + wl,
				salt[mid] == 1,
			])
	return quads


static func _lake_level_near(map: PlanetData, cell: int) -> float:
	if map.water[cell] == PlanetData.Water.LAKE:
		return map.water_level[cell]
	for k in 8:
		var nb := map.neighbors[cell * 8 + k]
		if map.water[nb] == PlanetData.Water.LAKE:
			return map.water_level[nb]
	return NAN


## River water ribbons crossing this chunk: array of [left_dirs,
## right_dirs, radii, width, brackish, white_water]; ribbons follow the
## river's water profile (RiverNetwork) and break at waterfalls. Falls
## inside the chunk go to `falls`: [left_dir, right_dir, top_radius,
## bottom_radius, width, brackish, downstream_dir].
static func _river_ribbons(key: Vector3i, center: Vector3, rivers: RiverNetwork, segs: PackedInt32Array, falls: Array) -> Array:
	var out := []
	var reach := (PlanetConst.CIRCUMFERENCE_M / 4.0 / CHUNKS_PER_FACE) * 0.85 / PlanetConst.RADIUS_M
	for s in segs:
		var pa := rivers.a[s]
		var pb := rivers.b[s]
		var prof := rivers.profile(s)
		var white := rivers.rapids(s)
		var n := prof.size() - 1
		var tangent := (pb - pa).normalized()
		var half := rivers.width[s] * 0.5 / PlanetConst.RADIUS_M
		var rb := [PackedVector3Array(), PackedVector3Array(), PackedFloat32Array(), PackedFloat32Array()]
		var emit := func() -> void:
			if (rb[0] as PackedVector3Array).size() >= 2:
				out.append([rb[0], rb[1], rb[2], rivers.width[s], rivers.salty[s], rb[3]])
			rb[0] = PackedVector3Array()
			rb[1] = PackedVector3Array()
			rb[2] = PackedFloat32Array()
			rb[3] = PackedFloat32Array()
		var add := func(t: float, level: float, foam: float) -> void:
			var p := pa.slerp(pb, t)
			var side := tangent.cross(p).normalized() * half
			(rb[0] as PackedVector3Array).append((p - side).normalized())
			(rb[1] as PackedVector3Array).append((p + side).normalized())
			(rb[2] as PackedFloat32Array).append(PlanetConst.RADIUS_M + level + 0.15)
			(rb[3] as PackedFloat32Array).append(foam)
		for i in n + 1:
			var t := float(i) / n
			var p := pa.slerp(pb, t)
			if CubeSphere.angle_between(p, center) > reach:
				emit.call()
				continue
			if i > 0 and prof[i - 1] - prof[i] >= RiverNetwork.FALL_MIN_M:
				# Waterfall: the upper ribbon ends at its lip, the lower one
				# starts at the plunge pool, and a falling sheet joins them.
				var tm := (i - 0.5) / n
				add.call(tm, prof[i - 1], white[i - 1])
				emit.call()
				var pm := pa.slerp(pb, tm)
				if key_at(pm) == key:
					var side := tangent.cross(pm).normalized() * half
					falls.append([(pm - side).normalized(), (pm + side).normalized(),
						PlanetConst.RADIUS_M + prof[i - 1] + 0.15, PlanetConst.RADIUS_M + prof[i] + 0.15,
						rivers.width[s], rivers.salty[s], (pb - pa).normalized()])
				add.call(tm, prof[i], 1.0)
			add.call(t, prof[i], white[i])
		emit.call()
	return out


# --- Main-thread node building --------------------------------------------

static var _terrain_mat: ShaderMaterial
static var _fall_mat: ShaderMaterial
static var _mist_mesh: QuadMesh
static var _salt_mat: ShaderMaterial
static var _fresh_mat: ShaderMaterial


static func materials() -> void:
	if _terrain_mat:
		return
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = preload("res://shaders/terrain.gdshader")
	_salt_mat = ShaderMaterial.new()
	_salt_mat.shader = preload("res://shaders/water.gdshader")
	_salt_mat.set_shader_parameter("deep_color", Color(0.01, 0.12, 0.48))
	_salt_mat.set_shader_parameter("shallow_color", Color(0.0, 0.6, 0.74))
	_fresh_mat = ShaderMaterial.new()
	_fresh_mat.shader = preload("res://shaders/water.gdshader")
	_fresh_mat.set_shader_parameter("deep_color", Color(0.02, 0.2, 0.36))
	_fresh_mat.set_shader_parameter("shallow_color", Color(0.05, 0.58, 0.55))
	_fall_mat = ShaderMaterial.new()
	_fall_mat.shader = preload("res://shaders/waterfall.gdshader")
	Look.register(_terrain_mat)
	Look.register(_fall_mat)
	Look.register(_salt_mat)
	Look.register(_fresh_mat)


static func terrain_material() -> ShaderMaterial:
	materials()
	return _terrain_mat


## [salt water, fresh water] materials (StormFX sets rain on them).
static func water_materials() -> Array[ShaderMaterial]:
	materials()
	return [_salt_mat, _fresh_mat]


## Turn compute() output into meshes, collision and water. `world` is the
## World autoload (floating origin).
func build_nodes(data: Dictionary, world: Node) -> void:
	materials()
	var key: Vector3i = data.key
	face = key.x
	ci = key.y
	cj = key.z
	name = "Chunk_%d_%d_%d" % [face, ci, cj]
	center_dir = data.center
	dirs = data.dirs
	heights = data.heights
	fine_heights = data.fine_heights
	anchor_radius = data.anchor_r
	var anchor: Vector3 = world.to_scene(center_dir, anchor_radius)
	position = anchor

	_coarse_mesh = _ground_mesh(data.mesh_coarse, "Ground")
	_fine_mesh = _ground_mesh(data.mesh_fine, "GroundFine")
	_fine_mesh.visible = false

	# Ground collision comes later, a strip at a time and only near the
	# player (build_collision_part): a trimesh's BVH is slow to build, and
	# Godot's physics server builds it on the main thread even when asked
	# from a worker.
	_col_faces = data.faces
	# Only needed once.
	data.erase("mesh_coarse")
	data.erase("mesh_fine")
	data.erase("faces")
	data.erase("fine_dirs")
	data.erase("fine_normals")

	_build_water(data.water, data.rivers, world, anchor)
	_build_falls(data.falls, world, anchor)


## Collision still to build (ChunkManager builds it for chunks near the
## player)?
func wants_collision() -> bool:
	return not _col_faces.is_empty()


## Build the next strip of the ground's collision: COLLISION_PARTS of them,
## one a frame, each a ConcavePolygonShape3D of a share of the fine
## triangles (~1.5 ms each instead of ~6 ms for the lot).
func build_collision_part() -> void:
	if _col_body == null:
		_col_body = StaticBody3D.new()
		_col_body.name = "Collision"
		add_child(_col_body)
	var tris := _col_faces.size() / 3
	var per := int(ceil(float(tris) / COLLISION_PARTS))
	var from := _col_parts * per * 3
	var to := mini((_col_parts + 1) * per * 3, _col_faces.size())
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_col_faces.slice(from, to))
	var cs := CollisionShape3D.new()
	cs.shape = shape
	_col_body.add_child(cs)
	_col_parts += 1
	if _col_parts >= COLLISION_PARTS or to >= _col_faces.size():
		_col_faces = PackedVector3Array()


func _ground_mesh(arrays: Array, node_name: String) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = _terrain_mat
	add_child(mi)
	return mi


## Near the player: the 4 m ground and full trees; farther out the 8 m
## ground and light trees. `hero`: one of the chunks right around the
## player, whose trees and undergrowth get their smoothest meshes.
func set_fine(fine: bool, hero := false) -> void:
	if _fine_mesh and _fine_mesh.visible != fine:
		_fine_mesh.visible = fine
		_coarse_mesh.visible = not fine
		if not fine and _tree_body:
			_tree_body.queue_free()
			_tree_body = null
			_tree_next = 0
			_owner_tree.clear()
	var lod := PlantMeshes.LOD_FAR
	if fine:
		lod = PlantMeshes.LOD_HERO if hero else PlantMeshes.LOD_NEAR
	if lod != _plant_lod:
		_plant_lod = lod
		_swap_plants(self)
		if detail_node:
			_swap_plants(detail_node)


## The plant detail level (PlantMeshes.LOD_*) for plants under `parent`:
## the chunk's own trees, or its undergrowth (never the far level: it's
## only there in the detail ring).
func plant_lod(parent: Node) -> int:
	if parent == self:
		return _plant_lod
	return PlantMeshes.LOD_HERO if _plant_lod == PlantMeshes.LOD_HERO else PlantMeshes.LOD_NEAR


func _swap_plants(parent: Node) -> void:
	var all := SpeciesDB.all()
	var lod := plant_lod(parent)
	for ch in parent.get_children():
		if ch is MultiMeshInstance3D and ch.has_meta("species"):
			ch.multimesh.mesh = PlantMeshes.mesh_for(all[ch.get_meta("species")], lod)


# --- Trees: trunk colliders and lookups -------------------------------------

## True while trees in the detail ring still lack trunk colliders.
func wants_tree_colliders() -> bool:
	return _fine_mesh != null and _fine_mesh.visible and _tree_next < trees.size()


## Give up to `budget` more trees a trunk collider (a cylinder sized from
## the species' shape). Returns how many were added.
func build_tree_colliders(budget: int) -> int:
	if _tree_body == null:
		_tree_body = StaticBody3D.new()
		_tree_body.name = "Trunks"
		_tree_body.collision_layer = 1 | TREE_LAYER
		_tree_body.collision_mask = 0
		add_child(_tree_body)
	var all := SpeciesDB.all()
	var used := 0
	while _tree_next < trees.size() and used < budget:
		var i := _tree_next
		_tree_next += 1
		used += 1
		var t: Array = trees[i]
		var h: float = t[1]
		var dims := PlantMeshes.tree_dims((all[t[2]] as PlantSpecies).shape)
		var r := clampf(dims.x * h * 0.85, 0.1, 1.6)
		var ch := maxf(dims.y * h, 2.0)
		var key := Vector2i(roundi(r * 20.0), roundi(ch * 2.0))
		if not _cylinders.has(key):
			var cyl := CylinderShape3D.new()
			cyl.radius = key.x / 20.0
			cyl.height = key.y / 2.0
			_cylinders[key] = cyl
		var upv := tree_up(i)
		var x := upv.cross(Vector3.FORWARD if absf(upv.z) < 0.9 else Vector3.RIGHT).normalized()
		var owner := _tree_body.create_shape_owner(_tree_body)
		_tree_body.shape_owner_add_shape(owner, _cylinders[key])
		_tree_body.shape_owner_set_transform(owner, Transform3D(Basis(x, upv, x.cross(upv)), (t[0] as Vector3) + upv * (ch * 0.5 - 0.3)))
		_owner_tree[owner] = i
	return used


func has_tree_colliders() -> bool:
	return _tree_body != null


## Index in `trees` of the tree a trunk-collider shape belongs to, or -1.
func tree_for_shape(body: Object, shape_idx: int) -> int:
	if body != _tree_body or _tree_body == null:
		return -1
	return _owner_tree.get(_tree_body.shape_find_owner(shape_idx), -1)


## A tree's foot in scene space, and its local up.
func tree_base(i: int) -> Vector3:
	return global_position + (trees[i][0] as Vector3)


func tree_up(i: int) -> Vector3:
	return (center_dir * anchor_radius + (trees[i][0] as Vector3)).normalized()


func tree_species(i: int) -> PlantSpecies:
	return SpeciesDB.all()[trees[i][2]]


func _build_water(quads: Array, ribbons: Array, world: Node, anchor: Vector3) -> void:
	# uv2.x: white water (rapids), 0 on still water.
	var salt := {"v": PackedVector3Array(), "uv": PackedVector2Array(), "uv2": PackedVector2Array()}
	var fresh := {"v": PackedVector3Array(), "uv": PackedVector2Array(), "uv2": PackedVector2Array()}
	var east := CubeSphere.east(center_dir)
	var north := CubeSphere.north(center_dir)
	for q in quads:
		var target: Dictionary = salt if q[5] else fresh
		var r: float = q[4]
		var corners := []
		for k in 4:
			corners.append(world.to_scene_relative(q[k], r, anchor))
		for idx in [0, 2, 1, 0, 3, 2]:
			var v: Vector3 = corners[idx]
			target.v.append(v)
			target.uv.append(Vector2(v.dot(east), v.dot(north)))
			target.uv2.append(Vector2.ZERO)
	for rb in ribbons:
		var lefts: PackedVector3Array = rb[0]
		var rights: PackedVector3Array = rb[1]
		var radii: PackedFloat32Array = rb[2]
		var w: float = rb[3]
		var target: Dictionary = salt if rb[4] == 1 else fresh
		var along := 0.0
		for k in lefts.size() - 1:
			var l0: Vector3 = world.to_scene_relative(lefts[k], radii[k], anchor)
			var r0: Vector3 = world.to_scene_relative(rights[k], radii[k], anchor)
			var l1: Vector3 = world.to_scene_relative(lefts[k + 1], radii[k + 1], anchor)
			var r1: Vector3 = world.to_scene_relative(rights[k + 1], radii[k + 1], anchor)
			var seg_len := l0.distance_to(l1)
			var quad := [l0, r0, r1, l1]
			var uvs := [Vector2(0, along), Vector2(w, along), Vector2(w, along + seg_len), Vector2(0, along + seg_len)]
			var foam: PackedFloat32Array = rb[5]
			var uv2s := [Vector2(foam[k], 1), Vector2(foam[k], 1), Vector2(foam[k + 1], 1), Vector2(foam[k + 1], 1)]
			for idx in [0, 2, 1, 0, 3, 2]:
				target.v.append(quad[idx])
				target.uv.append(uvs[idx])
				target.uv2.append(uv2s[idx])
			along += seg_len
	_water_mesh(salt, _salt_mat, "SaltWater")
	_water_mesh(fresh, _fresh_mat, "FreshWater")


## Waterfalls: a sheet of water arcing off the lip and falling to the
## plunge pool, with drifting mist at its foot.
func _build_falls(falls: Array, world: Node, anchor: Vector3) -> void:
	if falls.is_empty():
		return
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var rows := 6
	for f in falls:
		var top_r: float = f[2]
		var bot_r: float = f[3] - 0.4
		var h := top_r - bot_r
		var w: float = f[4]
		var mid_dir: Vector3 = ((f[0] as Vector3) + (f[1] as Vector3)).normalized()
		var down: Vector3 = f[6]
		down = (down - mid_dir * down.dot(mid_dir)).normalized()
		var base := v.size()
		for r in rows + 1:
			var t := float(r) / rows
			var radius := lerpf(top_r, bot_r, t)
			# Arcs out over the lip and lands clear of the cliff foot (the
			# 4 m ground can only make a jagged ramp there).
			var out := down * (1.0 + (2.0 + minf(h, 20.0) * 0.12) * sin(t * PI * 0.5))
			for side in 2:
				var d: Vector3 = f[side]
				v.append(world.to_scene_relative(d, radius, anchor) + out)
				uv.append(Vector2(w * side, h * t))
				uv2.append(Vector2(h, w))
		for r in rows:
			var i := base + r * 2
			idx.append_array([i, i + 2, i + 1, i + 1, i + 2, i + 3])
		_mist(world.to_scene_relative(mid_dir, bot_r + 0.6, anchor), mid_dir, w, h)
	var normals := PackedVector3Array()
	normals.resize(v.size())
	normals.fill(Vector3.ZERO)
	for t in range(0, idx.size(), 3):
		var fn := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
		for k in 3:
			normals[idx[t + k]] += fn
	for i in normals.size():
		normals[i] = normals[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Waterfalls"
	mi.mesh = mesh
	mi.material_override = _fall_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Spray drifting up (along `up`, the local vertical) from a plunge pool.
func _mist(at: Vector3, up: Vector3, w: float, h: float) -> void:
	if _mist_mesh == null:
		_mist_mesh = QuadMesh.new()
		_mist_mesh.size = Vector2(1.0, 1.0)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(0.85, 0.93, 1.0, 0.3)
		# Soft round puffs, not squares.
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 32
		tex.height = 32
		m.albedo_texture = tex
		_mist_mesh.material = m
	var p := CPUParticles3D.new()
	p.name = "Mist"
	p.mesh = _mist_mesh
	p.amount = clampi(int(w * 2.0), 12, 60)
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(w * 0.5, 0.3, w * 0.5)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.6 + h * 0.05
	p.scale_amount_min = 2.5
	p.scale_amount_max = 4.0 + minf(h, 20.0) * 0.2
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	p.color_ramp = ramp
	var x := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	p.transform = Transform3D(Basis(x, up, x.cross(up)), at)
	add_child(p)


func _water_mesh(data: Dictionary, mat: ShaderMaterial, node_name: String) -> void:
	var v: PackedVector3Array = data.v
	if v.is_empty():
		return
	var normals := PackedVector3Array()
	normals.resize(v.size())
	normals.fill(center_dir)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = data.uv
	arrays[Mesh.ARRAY_TEX_UV2] = data.uv2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Terrain height at a surface direction inside this chunk, matching the
## drawn 4 m ground (each quad is split along its 00-11 diagonal), so
## plants and creatures sit exactly on it.
func height_at(d: Vector3) -> float:
	var g := _grid(d) * 2.0
	return fine_height(fine_heights, g.x, g.y)


## Height on a fine grid at fine-grid coordinates (0..FINE).
static func fine_height(fh: PackedFloat32Array, fx: float, fy: float) -> float:
	var n := FINE + 1
	var i0 := clampi(int(fx), 0, FINE - 1)
	var j0 := clampi(int(fy), 0, FINE - 1)
	var tx := fx - i0
	var ty := fy - j0
	var h00 := fh[j0 * n + i0]
	var h10 := fh[j0 * n + i0 + 1]
	var h01 := fh[(j0 + 1) * n + i0]
	var h11 := fh[(j0 + 1) * n + i0 + 1]
	if tx > ty:
		return h00 + (h10 - h00) * tx + (h11 - h10) * ty
	return h00 + (h11 - h01) * tx + (h01 - h00) * ty


## Standing-water surface height (sea, lake, wetland pool or river) over a
## surface direction inside this chunk.
func water_at(d: Vector3) -> float:
	var g := _grid(d)
	var n := QUADS + 1
	var i0 := int(g.x)
	var j0 := int(g.y)
	var wl: PackedFloat32Array = data.water_level
	var a := lerpf(wl[j0 * n + i0], wl[j0 * n + i0 + 1], g.x - i0)
	var b := lerpf(wl[(j0 + 1) * n + i0], wl[(j0 + 1) * n + i0 + 1], g.x - i0)
	return lerpf(a, b, g.y - j0)


## The ground's color at a surface direction inside this chunk (the
## nearest coarse vertex: biome blend, sand, rock, snow; footsteps read
## what's underfoot from it).
func ground_color_at(d: Vector3) -> Color:
	var cols: PackedColorArray = data.get("colors", PackedColorArray())
	if cols.is_empty():
		return Color(0.4, 0.5, 0.3)
	var g := _grid(d)
	return cols[roundi(g.y) * (QUADS + 1) + roundi(g.x)]


## Chunk grid coordinates (0..QUADS) of a surface direction.
func _grid(d: Vector3) -> Vector2:
	var uv := CubeSphere.face_uv(face, d)
	return Vector2(
		clampf((uv.x + 1.0) * 0.5 * CHUNKS_PER_FACE * QUADS - ci * QUADS, 0.0, QUADS - 0.001),
		clampf((uv.y + 1.0) * 0.5 * CHUNKS_PER_FACE * QUADS - cj * QUADS, 0.0, QUADS - 0.001))
