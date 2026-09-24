class_name TerrainChunk
extends Node3D
## One walkable patch of the planet surface (~260 m square, 32 x 32 flat-
## shaded quads of ~8 m: the GameCube low-poly look).
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
const QUADS := 32
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
## Per-vertex data kept for vegetation and creature placement.
var dirs := PackedVector3Array()
var heights := PackedFloat32Array()
## Canopy and emergent trees on this chunk: [local_position, height,
## species_index]. Canopy-dwelling creatures attach to these.
var trees: Array = []
## Raw compute() output and tree hosts, kept so the undergrowth layer can
## be computed later when the player comes close.
var data: Dictionary
var hosts: Array = []
var detail_node: Node3D


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


static func center_of(key: Vector3i) -> Vector3:
	return CubeSphere.to_dir(key.x, _uv(key.y, QUADS / 2), _uv(key.z, QUADS / 2))


## Pure computation (thread-safe). Returns a Dictionary consumed by
## build_nodes() and VegetationPlacer.
static func compute(key: Vector3i, map: PlanetData, rivers: RiverNetwork) -> Dictionary:
	var n := QUADS + 1
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
	var center := center_of(key)
	var segs := rivers.segments_near(map, map.cell_at(center))

	for jj in n:
		for ii in n:
			var i := jj * n + ii
			var d := CubeSphere.to_dir(key.x, _uv(key.y, ii), _uv(key.z, jj))
			var e := map.terrain.elevation(d, true)
			var wl := _standing_water(map, d)
			var nearest := 1e6
			for s in segs:
				var info := rivers.closest(s, d)
				nearest = minf(nearest, info.x)
				var half := rivers.width[s] * 0.5
				if info.x < half + BANK_M:
					var f := 1.0 - smoothstep(half, half + BANK_M, info.x)
					var bed := info.z - rivers.depth[s]
					e = lerpf(e, minf(e, bed) if info.x > half else bed, f)
					if info.x < half:
						wl = Vector2(maxf(wl.x, info.z), 1.0 if rivers.salty[s] == 1 else 0.0)
			dirs_out[i] = d
			h[i] = e
			river_dist[i] = nearest
			level[i] = wl.x
			salt[i] = int(wl.y)

	return {
		"key": key,
		"center": center,
		"dirs": dirs_out,
		"heights": h,
		"river_dist": river_dist,
		"water_level": level,
		"salt": salt,
		"colors": _vertex_colors(map, dirs_out, h),
		"water": _water_quads(key, dirs_out, h, level, salt),
		"rivers": _river_ribbons(center, rivers, segs),
	}


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


static func _vertex_colors(map: PlanetData, d: PackedVector3Array, h: PackedFloat32Array) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(d.size())
	for i in d.size():
		var dir := d[i]
		var col := _biome_blend(map, dir)
		var e := h[i]
		# Snow wherever it's below freezing at this exact height.
		var t := map.sample(map.temp_c, dir) + (map.sample(map.elevation, dir) - e) * PlanetConst.LAPSE_RATE_C_PER_M
		col = col.lerp(SNOW, smoothstep(-0.5, -3.5, t))
		if e < 3.0 and map.sample(map.coast_dist_km, dir) < 1.5:
			col = col.lerp(SAND, smoothstep(3.0, 0.8, e))
		if e < 0.0:
			col = col.lerp(SEABED, smoothstep(0.0, -8.0, e))
		out[i] = col
	return out


## Bilinear blend of the four nearest blueprint cells' biome colors, so
## biome borders fade across the ground instead of snapping.
static func _biome_blend(map: PlanetData, d: Vector3) -> Color:
	var w := map.weights_at(d)
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
static func _water_quads(key: Vector3i, d: PackedVector3Array, h: PackedFloat32Array,
		level: PackedFloat32Array, salt: PackedByteArray) -> Array:
	var quads := []
	var n := QUADS + 1
	var step := QUADS / WATER_QUADS
	for wj in WATER_QUADS:
		for wi in WATER_QUADS:
			var ii := wi * step
			var jj := wj * step
			var mid := (jj + step / 2) * n + (ii + step / 2)
			var wl := level[mid]
			var lowest := INF
			for dj in step + 1:
				for di in step + 1:
					lowest = minf(lowest, h[(jj + dj) * n + (ii + di)])
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


## River water ribbons crossing this chunk: array of
## [left_dirs, right_dirs, radii, width, brackish].
static func _river_ribbons(center: Vector3, rivers: RiverNetwork, segs: PackedInt32Array) -> Array:
	var out := []
	var reach := (PlanetConst.CIRCUMFERENCE_M / 4.0 / CHUNKS_PER_FACE) * 0.85 / PlanetConst.RADIUS_M
	for s in segs:
		var pa := rivers.a[s]
		var pb := rivers.b[s]
		var length_m := CubeSphere.surface_distance_m(pa, pb)
		var steps := maxi(2, int(length_m / 8.0))
		var lefts := PackedVector3Array()
		var rights := PackedVector3Array()
		var radii := PackedFloat32Array()
		var tangent := (pb - pa).normalized()
		for k in steps + 1:
			var t := float(k) / steps
			var p := (pa + (pb - pa) * t).normalized()
			if CubeSphere.angle_between(p, center) > reach:
				if lefts.size() >= 2:
					out.append([lefts, rights, radii, rivers.width[s], rivers.salty[s]])
				lefts = PackedVector3Array()
				rights = PackedVector3Array()
				radii = PackedFloat32Array()
				continue
			var side := tangent.cross(p).normalized() * (rivers.width[s] * 0.5 / PlanetConst.RADIUS_M)
			lefts.append((p - side).normalized())
			rights.append((p + side).normalized())
			radii.append(PlanetConst.RADIUS_M + lerpf(rivers.level_a[s], rivers.level_b[s], t) + 0.15)
		if lefts.size() >= 2:
			out.append([lefts, rights, radii, rivers.width[s], rivers.salty[s]])
	return out


# --- Main-thread node building --------------------------------------------

static var _terrain_mat: ShaderMaterial
static var _salt_mat: ShaderMaterial
static var _fresh_mat: ShaderMaterial


static func materials() -> void:
	if _terrain_mat:
		return
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = preload("res://shaders/terrain.gdshader")
	_salt_mat = ShaderMaterial.new()
	_salt_mat.shader = preload("res://shaders/water.gdshader")
	_salt_mat.set_shader_parameter("deep_color", Color(0.02, 0.13, 0.3))
	_salt_mat.set_shader_parameter("shallow_color", Color(0.07, 0.4, 0.52))
	_fresh_mat = ShaderMaterial.new()
	_fresh_mat.shader = preload("res://shaders/water.gdshader")
	_fresh_mat.set_shader_parameter("deep_color", Color(0.03, 0.18, 0.2))
	_fresh_mat.set_shader_parameter("shallow_color", Color(0.12, 0.42, 0.36))


static func terrain_material() -> ShaderMaterial:
	materials()
	return _terrain_mat


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
	var n := QUADS + 1
	var mid := (QUADS / 2) * n + QUADS / 2
	anchor_radius = PlanetConst.RADIUS_M + heights[mid]
	var anchor: Vector3 = world.to_scene(center_dir, anchor_radius)
	position = anchor

	var local := PackedVector3Array()
	local.resize(n * n)
	for i in n * n:
		local[i] = world.to_scene_relative(dirs[i], PlanetConst.RADIUS_M + heights[i], anchor)

	var colors: PackedColorArray = data.colors
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	var up := center_dir
	for jj in QUADS:
		for ii in QUADS:
			var i00 := jj * n + ii
			var i10 := i00 + 1
			var i01 := i00 + n
			var i11 := i01 + 1
			_tri(local, colors, i00, i11, i10, up, verts, normals, cols)
			_tri(local, colors, i00, i01, i11, up, verts, normals, cols)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = _terrain_mat
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(verts)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

	_build_water(data.water, data.rivers, world, anchor)


## Flat-shaded triangle; its color is the average of its corners, turned to
## bare rock when the face is steep.
func _tri(p: PackedVector3Array, c: PackedColorArray, a: int, b: int, d: int, up: Vector3,
		verts: PackedVector3Array, normals: PackedVector3Array, cols: PackedColorArray) -> void:
	var pa := p[a]
	var pb := p[b]
	var pd := p[d]
	var nrm := (pb - pa).cross(pd - pa).normalized()
	if nrm.dot(up) < 0.0:
		nrm = -nrm
	var col := (c[a] + c[b] + c[d]) / 3.0
	var steep := 1.0 - nrm.dot(up)
	col = col.lerp(ROCK, smoothstep(0.3, 0.5, steep) * (1.0 - smoothstep(0.85, 0.95, col.b)))
	verts.append_array([pa, pb, pd])
	normals.append_array([nrm, nrm, nrm])
	cols.append_array([col, col, col])


func _build_water(quads: Array, ribbons: Array, world: Node, anchor: Vector3) -> void:
	var salt := {"v": PackedVector3Array(), "uv": PackedVector2Array()}
	var fresh := {"v": PackedVector3Array(), "uv": PackedVector2Array()}
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
			for idx in [0, 2, 1, 0, 3, 2]:
				target.v.append(quad[idx])
				target.uv.append(uvs[idx])
			along += seg_len
	_water_mesh(salt, _salt_mat, "SaltWater")
	_water_mesh(fresh, _fresh_mat, "FreshWater")


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
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Terrain height at a surface direction inside this chunk, matching the
## rendered triangle (each quad is split along its 00-11 diagonal), so
## plants and creatures sit exactly on the ground.
func height_at(d: Vector3) -> float:
	var g := _grid(d)
	var n := QUADS + 1
	var i0 := int(g.x)
	var j0 := int(g.y)
	var tx := g.x - i0
	var ty := g.y - j0
	var h00 := heights[j0 * n + i0]
	var h10 := heights[j0 * n + i0 + 1]
	var h01 := heights[(j0 + 1) * n + i0]
	var h11 := heights[(j0 + 1) * n + i0 + 1]
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


## Chunk grid coordinates (0..QUADS) of a surface direction.
func _grid(d: Vector3) -> Vector2:
	var uv := CubeSphere.face_uv(face, d)
	return Vector2(
		clampf((uv.x + 1.0) * 0.5 * CHUNKS_PER_FACE * QUADS - ci * QUADS, 0.0, QUADS - 0.001),
		clampf((uv.y + 1.0) * 0.5 * CHUNKS_PER_FACE * QUADS - cj * QUADS, 0.0, QUADS - 0.001))
