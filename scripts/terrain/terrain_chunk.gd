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

## Chunks are about CHUNK_M across whatever the planet's size: a walking
## scale (8 m ground quads, a tree layout's placement grid, the render
## distance's step), so a fixed length, not a share of the planet; 3,840
## per face edge on the 4,000 km planet, fewer on the dev postage stamp
## (fit_to_planet, called by PlanetConst.set_circumference). (It was
## derived from the full circumference, and grew tenfold, to 2.6 km, when
## the planet did.)
const CHUNK_M := 400000.0 / 4.0 / 384.0
static var CHUNKS_PER_FACE := roundi(PlanetConst.FULL_CIRCUMFERENCE_M / 4.0 / CHUNK_M)


static func fit_to_planet() -> void:
	CHUNKS_PER_FACE = maxi(4, roundi(PlanetConst.CIRCUMFERENCE_M / 4.0 / CHUNK_M))


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
## Canopy and emergent trees on this chunk, in placement order (trees[i]
## is hosts[i]): [local_position, height, species_index, instance, pick,
## layout_instance, rotation, vines, bare] (bare 1: dead). `instance` is the tree's index in
## tree_mm[species_index]; a branchy tree (TreeLayouts) also has a `pick`
## (its layout, maybe mirrored; -1 for other trees) and its index in
## layout_mm; `rotation` is its rigid rotation (radial up, yaw and lean,
## no scale). Canopy-dwelling creatures attach to these.
var trees: Array = []
## species index -> the MultiMesh drawing that species' trees here (for a
## branchy species, only beyond the detail ring).
var tree_mm := {}
## Vector2i(species index, layout) -> the MultiMesh drawing that layout's
## trees in the detail ring.
var layout_mm := {}
## Trees with a branch graph right now (registered with BranchGraphs;
## ChunkManager adds and drops them by distance): tree index -> the
## BranchGraph, or null for a tree with no wood to hold.
var graphs := {}
## Tree index -> the drawn vines hanging from it (_hang_vines()).
var _vine_nodes := {}
## Raw compute() output and tree hosts, kept so the undergrowth layer can
## be computed later when the player comes close.
var data: Dictionary
var hosts: Array = []
var detail_node: Node3D

## Physics layer (bit value) of tree trunks, besides the default layer 1,
## so queries can look for trees alone.
const TREE_LAYER := 2
# Tree colliders, only while the chunk is in the detail ring: one static
# body, one shape owner per collider (a trunk is up to four stacked
# cylinders), built a few dozen trees per frame; limb capsules join it for
# trees with a branch graph.
var _tree_body: StaticBody3D
var _tree_next := 0
var _owner_tree := {} # shape owner id -> index in trees
var _limb_owners := {} # tree index -> PackedInt32Array of shape owner ids
var _twig_owners := {} # the same for its order-3 twigs (within ChunkManager.TWIG_M)
## Shared collider shapes: Vector3i(radius cm, length dm, capsule) -> Shape3D.
static var _shapes := {}


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
	var in_river := PackedByteArray() # 1 where the water level is a river's
	dirs_out.resize(n * n)
	h.resize(n * n)
	river_dist.resize(n * n)
	level.resize(n * n)
	salt.resize(n * n)
	in_river.resize(n * n)
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
			var in_river_here := 0
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
						in_river_here = 1
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
				in_river[i] = in_river_here

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
		"water": _water_quads(key, dirs_out, fine_h, level, salt, in_river),
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
	var anchor_r := set_anchor(data)
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


## The chunk's anchor radius (its middle's ground), into data.anchor_r;
## the trees are placed relative to it before the meshes are made.
static func set_anchor(data: Dictionary) -> float:
	var mid := (QUADS / 2) * (QUADS + 1) + QUADS / 2
	var anchor_r := PlanetConst.RADIUS_M + (data.heights as PackedFloat32Array)[mid]
	data["anchor_r"] = anchor_r
	return anchor_r


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


## How wide the canopy shade's edge fades (data/look.json retro.canopy_feather_m).
static var CANOPY_FEATHER_M := float(Tuning.section("look", "retro").get("canopy_feather_m", 3.0))


## Baked canopy shade: ground under tree crowns is darkened a little, and
## how much canopy is overhead (0-1, weighted by how leafy each tree is,
## hosts' leaf amount) goes in the vertex color's alpha as 1 - canopy: the
## terrain shader breaks that shade into sun flecks, light through the gaps
## between the leaf clusters. Called after the trees are placed, before the
## mesh is built. Worker-thread safe.
static func bake_canopy_shade(data: Dictionary, hosts: Array) -> void:
	var key: Vector3i = data.key
	var cols: PackedColorArray = data.colors
	var n := QUADS + 1
	var quad_m := PlanetConst.CIRCUMFERENCE_M / 4.0 / CHUNKS_PER_FACE / QUADS
	var shade := PackedFloat32Array()
	shade.resize(n * n)
	var all := SpeciesDB.all()
	for host in hosts:
		# Trees grown from their architecture shade the ground through
		# their clusters instead (CanopyDapple, §AJ 3) — unless the shade
		# map is off (look.json dapple.mode "disc"): then they cast the
		# disc too.
		if CanopyDapple.stamped() and TreeArch.grows(all[int(host[3])]):
			continue
		var uv := CubeSphere.face_uv(key.x, host[0])
		var gx := (uv.x + 1.0) * 0.5 * CHUNKS_PER_FACE * QUADS - key.y * QUADS
		var gy := (uv.y + 1.0) * 0.5 * CHUNKS_PER_FACE * QUADS - key.z * QUADS
		var r: float = maxf(float(host[2]) * 0.3, 2.0) / quad_m # crown radius in quads
		var leaf: float = float(host[5]) if host.size() > 5 else 1.0
		# Full shade inside the crown, fading out across CANOPY_FEATHER_M
		# centred on its edge (design §AG 6).
		var f := CANOPY_FEATHER_M / quad_m * 0.5
		var reach := r + f
		for y in range(maxi(0, int(gy - reach)), mini(n, int(gy + reach) + 2)):
			for x in range(maxi(0, int(gx - reach)), mini(n, int(gx + reach) + 2)):
				var d := Vector2(x - gx, y - gy).length()
				if d < reach:
					shade[y * n + x] = maxf(shade[y * n + x], (1.0 - smoothstep(maxf(r - f, 0.0), reach, d)) * leaf)
	for i in n * n:
		if shade[i] > 0.0:
			var k := 1.0 - 0.12 * shade[i]
			var c := cols[i]
			cols[i] = Color(c.r * k, c.g * k, c.b * k, 1.0 - shade[i])


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
## corner radii, salt, corner UVs].
##
## Corners take the water level at that corner, so neighboring quads share
## their edges and the surface is one unbroken sheet (a quad at its own flat
## level left a hairline step to the next one, and the ground showed
## through it as a thin light line across the water). Only where the level
## really jumps (a lake's rim, a river dropping into the sea) does a quad
## keep its own flat level.
##
## UVs are meters on the cube face (the same everywhere on the face, so the
## water texture runs on unbroken from chunk to chunk), wrapped per quad by
## WATER_UV_WRAP_M, a whole number of the water shader's texture repeats.
static func _water_quads(key: Vector3i, d: PackedVector3Array, fine_h: PackedFloat32Array,
		level: PackedFloat32Array, salt: PackedByteArray, in_river: PackedByteArray) -> Array:
	var quads := []
	var n := QUADS + 1
	var nf := FINE + 1
	var step := QUADS / WATER_QUADS
	var cell_m := PlanetConst.CIRCUMFERENCE_M / 4.0 / float(CHUNKS_PER_FACE * QUADS)
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
			var idx := [jj * n + ii, jj * n + ii + step, (jj + step) * n + ii + step, (jj + step) * n + ii]
			# A river pool reaching over a waterfall (a corner well below):
			# left out, or its flat edge would hang out over the fall and
			# hide the crest. The river's own ribbon covers the water there.
			var over_fall := false
			if in_river[mid] == 1:
				for k in 4:
					if level[idx[k]] < wl - RiverNetwork.FALL_MIN_M * 0.5:
						over_fall = true
			if over_fall:
				continue
			var grid := [Vector2i(0, 0), Vector2i(step, 0), Vector2i(step, step), Vector2i(0, step)]
			var radii := PackedFloat32Array()
			var uvs := PackedVector2Array()
			var gx0 := float(key.y * QUADS + ii) * cell_m
			var gy0 := float(key.z * QUADS + jj) * cell_m
			var wrap := Vector2(floorf(gx0 / WATER_UV_WRAP_M), floorf(gy0 / WATER_UV_WRAP_M)) * WATER_UV_WRAP_M
			for k in 4:
				var cl: float = level[idx[k]]
				radii.append(PlanetConst.RADIUS_M + (cl if absf(cl - wl) < WATER_BLEND_M else wl))
				var g: Vector2i = grid[k]
				uvs.append(Vector2(gx0 + g.x * cell_m, gy0 + g.y * cell_m) - wrap)
			quads.append([d[idx[0]], d[idx[1]], d[idx[2]], d[idx[3]], radii, salt[mid] == 1, uvs])
	return quads


## Water corners within this of their quad's own level join the smooth
## sheet (see _water_quads).
const WATER_BLEND_M := 0.75
## Water UVs wrap every this many meters: 50 repeats of the water shader's
## 6 m layer and 40 of its 7.5 m layer (turned 3-4-5, so 24 x 32 of them),
## so the wrap never shows.
const WATER_UV_WRAP_M := 300.0


static func _lake_level_near(map: PlanetData, cell: int) -> float:
	if map.water[cell] == PlanetData.Water.LAKE:
		return map.water_level[cell]
	for k in 8:
		var nb := map.neighbors[cell * 8 + k]
		if map.water[nb] == PlanetData.Water.LAKE:
			return map.water_level[nb]
	return NAN


## River water ribbons crossing this chunk: array of [left_dirs,
## right_dirs, radii, half_widths, brackish, white_water, along_m];
## ribbons follow the river's water profile (RiverNetwork) and break at
## waterfalls. Falls inside the chunk go to `falls`: [left_dir, right_dir,
## top_radius, bottom_radius, width, brackish, downstream_dir].
##
## Drawn so no seam shows across the river:
## - each ~6 m stretch belongs to exactly one chunk (the one its middle is
##   in), so neighboring chunks' ribbons meet end to end instead of
##   overlapping (two see-through layers read as a band across the water);
## - where two segments meet, both ribbon ends share one edge (the average
##   of the two directions and widths), so there's no wedge gap or overlap
##   at a bend;
## - along_m is meters downstream measured from the river's end
##   (RiverNetwork.to_end_m), one continuous coordinate through chunks and
##   segment joints, wrapped per ribbon by WATER_UV_WRAP_M so it stays
##   precise.
static func _river_ribbons(key: Vector3i, _center: Vector3, rivers: RiverNetwork, segs: PackedInt32Array, falls: Array) -> Array:
	var out := []
	for s in segs:
		var pa := rivers.a[s]
		var pb := rivers.b[s]
		var prof := rivers.profile(s)
		var white := rivers.rapids(s)
		var n := prof.size() - 1
		var tangent := (pb - pa).normalized()
		var half := rivers.width[s] * 0.5
		var seg_m := CubeSphere.surface_distance_m(pa, pb)
		var start_m := -rivers.to_end_m[s] # meters downstream at pa
		# Shared joint edges with the segments upstream and downstream.
		var joint := func(other: int, at: Vector3) -> Array:
			if other < 0:
				return [tangent.cross(at).normalized(), half]
			var ot := (rivers.b[other] - rivers.a[other]).normalized()
			return [(tangent + ot).cross(at).normalized(), (half + rivers.width[other] * 0.5) * 0.5]
		var j0: Array = joint.call(rivers.up_seg[s], pa)
		var j1: Array = joint.call(rivers.down_seg[s], pb)
		# Plain Arrays while building: a packed array read back out of an
		# Array is a copy, so appending to it there is lost (why ribbons
		# used to come out empty and rivers showed only their flat pools).
		var rb := [[], [], [], [], [], []]
		var wrap := [0.0]
		var emit := func() -> void:
			if (rb[0] as Array).size() >= 2:
				out.append([PackedVector3Array(rb[0]), PackedVector3Array(rb[1]), PackedFloat32Array(rb[2]),
					PackedFloat32Array(rb[3]), rivers.salty[s], PackedFloat32Array(rb[4]), PackedFloat32Array(rb[5])])
			for k in rb.size():
				(rb[k] as Array).clear()
		var add := func(t: float, level: float, foam: float) -> void:
			var p := pa.slerp(pb, t)
			var side: Vector3
			var h: float
			if t <= 0.0:
				side = j0[0]
				h = j0[1]
			elif t >= 1.0:
				side = j1[0]
				h = j1[1]
			else:
				side = tangent.cross(p).normalized()
				h = half
			var off := side * h / PlanetConst.RADIUS_M
			var m := start_m + t * seg_m
			if (rb[0] as Array).is_empty():
				wrap[0] = floorf(m / WATER_UV_WRAP_M) * WATER_UV_WRAP_M
			(rb[0] as Array).append((p - off).normalized())
			(rb[1] as Array).append((p + off).normalized())
			(rb[2] as Array).append(PlanetConst.RADIUS_M + level + 0.15)
			(rb[3] as Array).append(h)
			(rb[4] as Array).append(foam)
			(rb[5] as Array).append(m - wrap[0])
		for i in range(1, n + 1):
			var t0 := float(i - 1) / n
			var t1 := float(i) / n
			if key_at(pa.slerp(pb, (t0 + t1) * 0.5)) != key:
				emit.call()
				continue
			if (rb[0] as Array).is_empty():
				add.call(t0, prof[i - 1], white[i - 1])
			if prof[i - 1] - prof[i] >= RiverNetwork.FALL_MIN_M:
				# Waterfall: the upper ribbon ends at its lip, the lower one
				# starts at the plunge pool, and a falling sheet joins them.
				var tm := (i - 0.5) / n
				add.call(tm, prof[i - 1], white[i - 1])
				emit.call()
				var pm := pa.slerp(pb, tm)
				var side := tangent.cross(pm).normalized() * half / PlanetConst.RADIUS_M
				falls.append([(pm - side).normalized(), (pm + side).normalized(),
					PlanetConst.RADIUS_M + prof[i - 1] + 0.15, PlanetConst.RADIUS_M + prof[i] + 0.15,
					rivers.width[s], rivers.salty[s], (pb - pa).normalized()])
				add.call(tm, prof[i], 1.0)
			add.call(t1, prof[i], white[i])
		emit.call()
	return out


# --- Main-thread node building --------------------------------------------

static var _terrain_mat: ShaderMaterial
static var _fall_mat: ShaderMaterial
static var _mist_mesh: QuadMesh
static var _salt_mat: ShaderMaterial
static var _fresh_mat: ShaderMaterial
## Day water: the reference's deep navy (data/look.json retro.colors.water,
## design §AG). Sea and fresh water share it: two blues met in a hard 16 m
## staircase at every river mouth.
static var WATER := Color(str((Tuning.section("look", "retro").get("colors", {}) as Dictionary).get("water", "#3B78FF")))


static func materials() -> void:
	if _terrain_mat:
		return
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = preload("res://shaders/terrain.gdshader")
	_salt_mat = ShaderMaterial.new()
	_salt_mat.shader = preload("res://shaders/water.gdshader")
	# Night colors are the shader's own (R1a).
	_salt_mat.set_shader_parameter("water_color", WATER)
	_fresh_mat = ShaderMaterial.new()
	_fresh_mat.shader = preload("res://shaders/water.gdshader")
	_fresh_mat.set_shader_parameter("water_color", WATER)
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

	var dapple: Image = data.get("dapple")
	var ground_mat := _terrain_mat
	if dapple != null:
		# This chunk's own copy of the ground material, with its dappled
		# canopy shade (CanopyDapple).
		ground_mat = _terrain_mat.duplicate()
		ground_mat.set_shader_parameter("dapple_tex", ImageTexture.create_from_image(dapple))
		ground_mat.set_shader_parameter("dapple_span", CanopyDapple.span_m())
		ground_mat.set_shader_parameter("dapple_on", true)
	_coarse_mesh = _ground_mesh(data.mesh_coarse, "Ground", ground_mat)
	_fine_mesh = _ground_mesh(data.mesh_fine, "GroundFine", ground_mat)
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


func _ground_mesh(arrays: Array, node_name: String, mat: ShaderMaterial) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	return mi


## Near the player: the 4 m ground and full trees; farther out the 8 m
## ground and light trees. `hero`: one of the chunks right around the
## player, whose trees and undergrowth get their smoothest meshes.
func set_fine(fine: bool, hero := false) -> void:
	if _fine_mesh and _fine_mesh.visible != fine:
		_fine_mesh.visible = fine
		_coarse_mesh.visible = not fine
		if not fine:
			remove_graphs()
		if not fine and _tree_body:
			_tree_body.queue_free()
			_tree_body = null
			_tree_next = 0
			_owner_tree.clear()
			_limb_owners.clear()
			_twig_owners.clear()
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


## Branchy trees show their layouts' MultiMeshes in the detail ring and
## their species' one (the far crown) beyond it; everything else swaps its
## mesh for the level.
func _swap_plants(parent: Node) -> void:
	var all := SpeciesDB.all()
	var lod := plant_lod(parent)
	for ch in parent.get_children():
		if not (ch is MultiMeshInstance3D and ch.has_meta("species")):
			continue
		var mmi := ch as MultiMeshInstance3D
		var sp: PlantSpecies = all[ch.get_meta("species")]
		plant_shadow(mmi, sp, lod)
		if ch.has_meta("layout"):
			mmi.visible = lod != PlantMeshes.LOD_FAR
			if mmi.visible:
				mmi.multimesh.mesh = PlantMeshes.mesh_for(sp, lod, ch.get_meta("layout"))
		elif ch.has_meta("far_only"):
			mmi.visible = lod == PlantMeshes.LOD_FAR
		elif ch.has_meta("young"):
			# Understory seedlings and saplings (design §AR).
			mmi.multimesh.mesh = PlantMeshes.young_mesh(sp, int(ch.get_meta("young")), PlantMeshes.LOD_NEAR)
		else:
			mmi.multimesh.mesh = PlantMeshes.mesh_for(sp, lod)


## Only plants in the hero chunks (ChunkManager.HERO_M, 120 m) cast
## shadows: the shadow map reaches look "light" shadow_max_m (50 m), so a
## tree farther out never lands a shadow in it, but it still costs the
## shadow pass its triangles (most of that pass's 17M on the full planet).
## Ground cover and epiphytes never cast (VegetationPlacer).
static func plant_shadow(mmi: MultiMeshInstance3D, sp: PlantSpecies, lod: int) -> void:
	if sp.tier == PlantSpecies.Tier.GROUND or sp.tier == PlantSpecies.Tier.EPIPHYTE:
		return
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == PlantMeshes.LOD_HERO else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _exit_tree() -> void:
	remove_graphs()


# --- Trees: colliders, branch graphs and lookups ------------------------------

## True while trees in the detail ring still lack trunk colliders.
func wants_tree_colliders() -> bool:
	return _fine_mesh != null and _fine_mesh.visible and _tree_next < trees.size()


## Give up to `budget` more trees their trunk colliders: stacked cylinders
## along the drawn trunk (TreeLayouts.collider_segments) that lean, turn
## and taper with it, a mangrove's stilt roots too, and nothing for plants
## whose wood stays below knee height. Returns how many trees were done.
func build_tree_colliders(budget: int) -> int:
	_ensure_tree_body()
	var used := 0
	while _tree_next < trees.size() and used < budget:
		var i := _tree_next
		_tree_next += 1
		used += 1
		var t: Array = trees[i]
		var pick: int = t[4]
		var sk := TreeLayouts.skeleton(t[2], TreeLayouts.layout_of(pick))
		var frame := tree_frame(i)
		for seg in TreeLayouts.collider_segments(sk, t[1], TreeLayouts.is_mirrored(pick), false):
			_add_wood_shape(frame, seg, i)
	return used


func _ensure_tree_body() -> void:
	if _tree_body == null:
		_tree_body = StaticBody3D.new()
		_tree_body.name = "Trunks"
		_tree_body.collision_layer = 1 | TREE_LAYER
		_tree_body.collision_mask = 0
		add_child(_tree_body)


## One collider shape (TreeLayouts.collider_segments' [a, b, radius,
## capsule], in the tree's frame) on the trees' body, for tree `i`.
## Returns its shape owner.
func _add_wood_shape(frame: Transform3D, seg: Array, i: int) -> int:
	var a: Vector3 = frame * (seg[0] as Vector3)
	var b: Vector3 = frame * (seg[1] as Vector3)
	var r: float = seg[2]
	var capsule: bool = seg[3]
	var length := a.distance_to(b)
	var up := (b - a) / length
	var x := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var key := Vector3i(maxi(roundi(r * 100.0), 1), maxi(roundi(length * 10.0), 1), 1 if capsule else 0)
	var shape: Shape3D = _shapes.get(key)
	if shape == null:
		if capsule:
			var cap := CapsuleShape3D.new()
			cap.radius = key.x / 100.0
			# Godot's capsule height includes its round ends.
			cap.height = key.y / 10.0 + cap.radius * 2.0
			shape = cap
		else:
			var cyl := CylinderShape3D.new()
			cyl.radius = key.x / 100.0
			cyl.height = key.y / 10.0
			shape = cyl
		_shapes[key] = shape
	var owner := _tree_body.create_shape_owner(_tree_body)
	_tree_body.shape_owner_add_shape(owner, shape)
	_tree_body.shape_owner_set_transform(owner, Transform3D(Basis(x, up, x.cross(up)), (a + b) * 0.5))
	_owner_tree[owner] = i
	return owner


func has_tree_colliders() -> bool:
	return _tree_body != null


## Index in `trees` of the tree a trunk- or limb-collider shape belongs
## to, or -1.
func tree_for_shape(body: Object, shape_idx: int) -> int:
	if body != _tree_body or _tree_body == null:
		return -1
	return _owner_tree.get(_tree_body.shape_find_owner(shape_idx), -1)


## Give tree `i` its branch graph (registered with BranchGraphs) and, for
## a branchy tree, capsule colliders on its limbs and thick branches, on
## the trunks' body and layers so arrows stick in them. A tree with no
## wood to hold (bamboo, cacti, rosettes) is marked done without one.
func add_graph(i: int) -> void:
	if graphs.has(i):
		return
	var t: Array = trees[i]
	var pick: int = t[4]
	var g := TreeLayouts.graph(t[2], pick, t[1])
	var sp: PlantSpecies = SpeciesDB.all()[int(t[2])]
	if g == null and sp.shape == PlantSpecies.Shape.BAMBOO:
		g = _culm_graph(int(t[2]), float(t[1]))
	if g != null:
		# Dead wood (drawn bare: custom alpha 1) is brittle to hold.
		g.dead = _tree_custom(i).a > 0.975
		g.key = graph_key(i)
		g.chunk = self
		g.xform = tree_frame(i)
		_hang_vines(i, g)
		BranchGraphs.add(g)
	graphs[i] = g
	if pick < 0 or _limb_owners.has(i):
		return
	_ensure_tree_body()
	var frame := tree_frame(i)
	var owners := PackedInt32Array()
	for seg in TreeLayouts.collider_segments(TreeLayouts.skeleton(t[2], TreeLayouts.layout_of(pick)), t[1], TreeLayouts.is_mirrored(pick), true):
		owners.append(_add_wood_shape(frame, seg, i))
	_limb_owners[i] = owners


## Tree `i`'s vines and bareness as drawn (custom data g and a, kept in
## its record: VegetationPlacer), as Color(0, vines, 0, bare).
func _tree_custom(i: int) -> Color:
	var t: Array = trees[i]
	if t.size() < 9:
		return Color(0, 0, 0, 0)
	return Color(0.0, float(t[7]), 0.0, float(t[8]))


## A bamboo clump's graph: one culm of handholds from 1 m up to near its
## top, a handhold every half metre, as thick as a giant culm (thin enough
## to catch and swing on, not to kick off).
func _culm_graph(sp_idx: int, h: float) -> BranchGraph:
	var g := BranchGraph.new()
	g.species = sp_idx
	g.height_m = h
	var r := clampf(h * 0.006, 0.035, 0.12)
	var y := 1.0
	while y < h * 0.92:
		var k := g.local.size()
		g.local.append(Vector3(0, y, 0))
		g.tangent.append(Vector3.UP)
		g.radius.append(r)
		g.limb.append(0)
		g.links.append(PackedInt32Array([k - 1]) if k > 0 else PackedInt32Array())
		if k > 0:
			g.links[k - 1].append(k)
		y += BranchGraph.SPACING_M
	return g if g.local.size() > 1 else null


## A tree hung with vines (wet, warm country: the vine amount drawn on it,
## movement table "vines"): a few vines hanging from its limbs as handholds
## on its branch graph (BranchGraph.add_vine()), for the player to catch
## and swing on, and drawn as thin strands.
func _hang_vines(i: int, g: BranchGraph) -> void:
	var amount := _tree_custom(i).g
	var v := Tuning.section("movement", "vines")
	if amount < float(v.get("min_vines", 0.3)):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = g.key
	var anchors := []
	for k in g.size():
		if g.limb[k] > 0 and not g.is_vine(k) and g.radius[k] >= 0.05 and g.local[k].y >= float(v.get("min_anchor_m", 3.0)):
			anchors.append(k)
	if anchors.is_empty():
		return
	var want := mini(int(ceil(amount * float(v.get("max_per_tree", 4)))), anchors.size())
	var lens: Array = v.get("len_m", [3.0, 7.0])
	var step := float(v.get("step_m", 0.5))
	var strands: Array = []
	for n in want:
		var a: int = anchors[rng.randi_range(0, anchors.size() - 1)]
		anchors.erase(a)
		var length := minf(rng.randf_range(float(lens[0]), float(lens[1])), g.local[a].y - 1.2)
		var count := int(length / step)
		if count < 2:
			continue
		var idx := g.add_vine(a, count, step, float(v.get("radius_m", 0.03)), n)
		strands.append([g.local[a], g.local[idx[idx.size() - 1]]])
		if anchors.is_empty():
			break
	if strands.is_empty():
		return
	# Drawn: a thin four-sided strand per vine, in the tree's frame.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := Color(0.2, 0.32, 0.12)
	for sd in strands:
		var top: Vector3 = sd[0]
		var bot: Vector3 = sd[1]
		for side in 4:
			var a0 := TAU * side / 4.0
			var a1 := TAU * (side + 1) / 4.0
			var o0 := Vector3(cos(a0), 0, sin(a0)) * 0.03
			var o1 := Vector3(cos(a1), 0, sin(a1)) * 0.03
			st.set_color(col)
			for p in [top + o0, bot + o0, bot + o1, top + o0, bot + o1, top + o1]:
				st.set_normal((o0 + o1).normalized())
				st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.name = "Vines_%d" % i
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mi.material_override = mat
	mi.transform = g.xform
	add_child(mi)
	_vine_nodes[i] = mi


## Is shape `shape_idx` of `body` one of a tree's limb colliders (not its
## trunk or roots)? (A limb is caught and swung on; a trunk kicked off.)
func is_limb_shape(body: Object, shape_idx: int) -> bool:
	if body != _tree_body or _tree_body == null:
		return false
	var owner := _tree_body.shape_find_owner(shape_idx)
	for i in _limb_owners:
		if owner in (_limb_owners[i] as PackedInt32Array):
			return true
	for i in _twig_owners:
		if owner in (_twig_owners[i] as PackedInt32Array):
			return true
	return false


## Drop tree `i`'s branch graph and limb colliders.
func remove_graph(i: int) -> void:
	if _vine_nodes.has(i):
		(_vine_nodes[i] as Node).queue_free()
		_vine_nodes.erase(i)
	if graphs.has(i):
		var g: BranchGraph = graphs[i]
		if g != null:
			BranchGraphs.remove(g.key)
		graphs.erase(i)
	if _limb_owners.has(i):
		if _tree_body != null:
			for owner in (_limb_owners[i] as PackedInt32Array):
				_tree_body.remove_shape_owner(owner)
				_owner_tree.erase(owner)
		_limb_owners.erase(i)
	remove_twigs(i)


## Capsules on tree `i`'s order-3 twigs thick enough to stand on (design
## §AM 1, TreeLayouts.TWIG_COLLIDER_R_M), near the player only.
func add_twigs(i: int) -> void:
	var t: Array = trees[i]
	var pick: int = t[4]
	if pick < 0 or _twig_owners.has(i) or _tree_body == null:
		return
	var frame := tree_frame(i)
	var owners := PackedInt32Array()
	for seg in TreeLayouts.collider_segments(TreeLayouts.skeleton(t[2], TreeLayouts.layout_of(pick)), t[1], TreeLayouts.is_mirrored(pick), true, true):
		owners.append(_add_wood_shape(frame, seg, i))
	_twig_owners[i] = owners


func has_twigs(i: int) -> bool:
	return _twig_owners.has(i)


func remove_twigs(i: int) -> void:
	if not _twig_owners.has(i):
		return
	if _tree_body != null:
		for owner in (_twig_owners[i] as PackedInt32Array):
			_tree_body.remove_shape_owner(owner)
			_owner_tree.erase(owner)
	_twig_owners.erase(i)


## Drop every branch graph (and limb collider) of this chunk's trees.
func remove_graphs() -> void:
	for i in graphs.keys():
		remove_graph(i)


## The key of tree `i`'s branch graph: the same tree gets the same key on
## every visit (its chunk and its place in placement order), and no two
## trees of a chunk share one.
func graph_key(i: int) -> int:
	return ((hash(Vector3i(face, ci, cj)) & 0x7FFFFFFF) << 20) | i


## A tree's foot in scene space.
func tree_base(i: int) -> Vector3:
	return global_position + (trees[i][0] as Vector3)


## Up the tree's trunk as it stands (leaning with it), in scene space.
func tree_up(i: int) -> Vector3:
	return (trees[i][6] as Basis).y


## The tree's own frame in the chunk: trunk base at the origin, +Y up the
## unleaned trunk, turned by its yaw and tilted by its lean; rotation and
## translation only (its meshes scale this by the tree's height). Branch
## graphs, colliders and handholds use it.
func tree_frame(i: int) -> Transform3D:
	return Transform3D(trees[i][6], trees[i][0])


## The MultiMesh drawing tree `i` right now and the tree's index in it,
## as [MultiMesh, index] (a branchy tree in the detail ring is drawn by its
## layout's MultiMesh), or [] if there is none. TreeContact shakes trees
## through it.
func tree_instance(i: int) -> Array:
	var t: Array = trees[i]
	var pick: int = t[4]
	if pick >= 0 and _plant_lod != PlantMeshes.LOD_FAR:
		var lmm: MultiMesh = layout_mm.get(Vector2i(t[2], TreeLayouts.layout_of(pick)))
		if lmm != null:
			return [lmm, t[5]]
	var mm: MultiMesh = tree_mm.get(t[2])
	return [mm, t[3]] if mm != null else []


func tree_species(i: int) -> PlantSpecies:
	return SpeciesDB.all()[trees[i][2]]


func _build_water(quads: Array, ribbons: Array, world: Node, anchor: Vector3) -> void:
	# uv: meters (standing water: across the cube face; rivers: across from
	# the centerline, and downstream). uv2.x: white water (rapids), 0 on
	# still water; uv2.y: on rivers, the ribbon's half width (m; the water
	# runs downstream and the edges fade into the pool beneath), else 0.
	var salt := {"v": PackedVector3Array(), "uv": PackedVector2Array(), "uv2": PackedVector2Array()}
	var fresh := {"v": PackedVector3Array(), "uv": PackedVector2Array(), "uv2": PackedVector2Array()}
	for q in quads:
		var target: Dictionary = salt if q[5] else fresh
		var radii: PackedFloat32Array = q[4]
		var quv: PackedVector2Array = q[6]
		var corners := []
		for k in 4:
			corners.append(world.to_scene_relative(q[k], radii[k], anchor))
		for idx in [0, 2, 1, 0, 3, 2]:
			target.v.append(corners[idx])
			target.uv.append(quv[idx])
			target.uv2.append(Vector2.ZERO)
	for rb in ribbons:
		var lefts: PackedVector3Array = rb[0]
		var rights: PackedVector3Array = rb[1]
		var radii: PackedFloat32Array = rb[2]
		var halves: PackedFloat32Array = rb[3]
		var target: Dictionary = salt if rb[4] == 1 else fresh
		var foam: PackedFloat32Array = rb[5]
		var along: PackedFloat32Array = rb[6]
		for k in lefts.size() - 1:
			var quad := [
				world.to_scene_relative(lefts[k], radii[k], anchor),
				world.to_scene_relative(rights[k], radii[k], anchor),
				world.to_scene_relative(rights[k + 1], radii[k + 1], anchor),
				world.to_scene_relative(lefts[k + 1], radii[k + 1], anchor),
			]
			var uvs := [Vector2(-halves[k], along[k]), Vector2(halves[k], along[k]),
				Vector2(halves[k + 1], along[k + 1]), Vector2(-halves[k + 1], along[k + 1])]
			var uv2s := [Vector2(foam[k], halves[k]), Vector2(foam[k], halves[k]),
				Vector2(foam[k + 1], halves[k + 1]), Vector2(foam[k + 1], halves[k + 1])]
			for idx in [0, 2, 1, 0, 3, 2]:
				target.v.append(quad[idx])
				target.uv.append(uvs[idx])
				target.uv2.append(uv2s[idx])
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
