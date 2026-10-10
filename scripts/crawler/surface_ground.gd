class_name SurfaceGround
extends RefCounted
## The ground of the surface pocket above the tomb (design 9 Oct §FM.7;
## §EW.1, §EW.7 step 2; data/worlds.json surface.ground and surface.edge;
## Surface builds it): one heightfield, generated from the surface's seed
## and the tomb's layout, the same every time for that game (§FK.2).
##
##   the basin    surface.across_m across (§EW.1's 1-2 km; Claude Code's
##                first guess 1.4 km), its floor at the tomb's surface level
##                (smoke.json vents.surface_y_m: where every vent's top
##                already ends), rolling gently (roll_m over roll_scale_m),
##                a faint ripple of wind on it, flat round the stairhead
##                (flat_round_stair_m)
##   the wash     a dry watercourse (wash) from just past the stairhead out
##                along the way out's direction toward the landmark, wander_m
##                either side of its line, depth_m deep and width_m wide:
##                the shot holds (§EW.1, §FK.5 call 1: a line running to a
##                landmark against the sky)
##   the edge     the land closes it, never an invisible wall (§DM, worlds.json
##                size.edge the_land): a bajada of talus rising talus_rise_m
##                over talus_width_m (walkable) to the foot of an escarpment
##                cliff_m high over cliff_width_m (far steeper than anything
##                you can walk, CrawlerPlayer.WALK_MAX_DEG: every cell of the
##                face is a wall), its line wandering `wander` of the radius;
##                beyond it the plateau, beyond_m of it, hidden behind the lip
##   the landmark a butte on the plateau straight out along the way out
##                (landmark: out_m past the cliff, radius_m, height_m over the
##                plateau), standing over the rim against the sky
##   far          a band of far ranges far_band.radius_m out (not walkable,
##                not collidable), lighter and bluer in the haze (the look's
##                fog): §EW.5's layers, near (this ground), mid (the rim) and
##                far (the band and the sky); no other world's landmark yet
##                (§EW.7 steps 3 and 4)
##
## The grid is cell_m apart, in blocks of BLOCK cells for drawing (the
## terrain material, TerrainChunk's: the vertex colour picks sand, dirt or
## stone), and the same grid is its collision (a HeightMapShape3D), so what
## you see is what you walk on: each cell split along the same diagonal
## (from its +x corner to its +z corner) in both.
##
## Compass: -z is north, +x east (the sun rises in the east, SkySystem's one
## clock).

## Cells per drawn block.
const BLOCK := 32

## The surface level (y): the basin's floor and the vents' tops.
var base_y := 9.0
## The pocket's middle (x/z): the stairhead.
var center := Vector2.ZERO
## The way out's direction (x/z, unit): the arrival faces it; the wash and
## the landmark lie that way.
var n := Vector2(0.0, 1.0)
## The basin's radius (m) before its edge wanders.
var r_in := 700.0
var cell := 4.0
## The grid: count x count heights from grid_min, cell apart.
var count := 0
var grid_min := Vector2.ZERO
var heights := PackedFloat32Array()
## The landmark butte's middle (x/z) and its top (y).
var landmark := Vector2.ZERO
var landmark_top := 0.0

var G: Dictionary = {}
var E: Dictionary = {}
var _roll := FastNoiseLite.new()
var _ripple := FastNoiseLite.new()
var _pave := FastNoiseLite.new()
var _rim := FastNoiseLite.new()
var _tall := FastNoiseLite.new()
var _high := FastNoiseLite.new()
var _bend := FastNoiseLite.new()
var _talus := FastNoiseLite.new()
## Cached edge values for the angle last asked (atan2 per point is cheap;
## the circle noises are not free).
var _flat_a := 16.0
var _flat_b := 36.0


## Lay the ground out: `p` worlds.json surface, `seed_value` the surface's
## own seed, `stair` (x/z) the stairhead, `out` the way out's direction,
## `level` the surface level.
func setup(p: Dictionary, seed_value: int, stair: Vector2, out: Vector2, level: float) -> void:
	G = p.get("ground", {})
	E = p.get("edge", {})
	base_y = level
	center = stair
	n = out.normalized() if out.length() > 0.01 else Vector2(0.0, 1.0)
	r_in = maxf(float(p.get("across_m", 1400.0)) * 0.5, 200.0)
	cell = clampf(float(G.get("cell_m", 4.0)), 1.0, 16.0)
	var fr: Array = G.get("flat_round_stair_m", [16.0, 36.0])
	_flat_a = float(fr[0])
	_flat_b = maxf(float(fr[1]), _flat_a + 1.0)
	var k := 0
	for nz: FastNoiseLite in [_roll, _ripple, _pave, _rim, _tall, _high, _bend, _talus]:
		nz.seed = hash([seed_value, "surface ground", k])
		nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		nz.fractal_type = FastNoiseLite.FRACTAL_NONE
		k += 1
	_roll.frequency = 1.0 / maxf(float(G.get("roll_scale_m", 170.0)), 10.0)
	_roll.fractal_type = FastNoiseLite.FRACTAL_FBM
	_roll.fractal_octaves = 3
	_ripple.frequency = 1.0 / maxf(float(G.get("ripple_scale_m", 24.0)), 2.0)
	_pave.frequency = 1.0 / 55.0
	_pave.fractal_type = FastNoiseLite.FRACTAL_FBM
	_pave.fractal_octaves = 2
	# The edge's noises run round a circle (seamless all the way round).
	_rim.frequency = 0.6
	_tall.frequency = 0.9
	_talus.frequency = 0.7
	_high.frequency = 1.0 / 90.0
	_high.fractal_type = FastNoiseLite.FRACTAL_FBM
	_high.fractal_octaves = 2
	_bend.frequency = 1.0 / 150.0
	_bend.fractal_type = FastNoiseLite.FRACTAL_FBM
	_bend.fractal_octaves = 2
	# The landmark: straight out along the way out, past the cliff.
	var L: Dictionary = E.get("landmark", {})
	var th := atan2(n.y, n.x)
	landmark = center + n * (edge_r(th) + float(E.get("cliff_width_m", 16.0)) + float(L.get("out_m", 120.0)))
	# The grid: square, whole blocks, round the stairhead, past the
	# plateau's own reach and the landmark.
	var reach := r_in * (1.0 + absf(float(E.get("wander", 0.07)))) + float(E.get("cliff_width_m", 16.0)) + float(E.get("beyond_m", 170.0))
	reach = maxf(reach, (landmark - center).length() + float(L.get("radius_m", 60.0)) + 40.0)
	var block_m := BLOCK * cell
	var half := ceilf(reach / block_m) * block_m
	count = int(round(2.0 * half / cell)) + 1
	grid_min = center - Vector2(half, half)
	heights.resize(count * count)
	for j in count:
		var z := grid_min.y + j * cell
		for i in count:
			heights[j * count + i] = raw(grid_min.x + i * cell, z)
	landmark_top = height_at(landmark.x, landmark.y)


## The grid's half size (m).
func half_m() -> float:
	return (count - 1) * cell * 0.5


## The stairwell cut down into the ground (SurfaceBuild.stair_frame
## `frame`): the grid's points on the stair's line, from just behind its
## foot to its mouth, sunk well below its steps, so no ground stands in the
## stairwell (the stairhead's yard of flags covers the dip round it). The
## grid is laid round the stairhead's mouth, so its lines run through it,
## and the way out is square to them (TombKit's plan): the line is a grid
## line.
func carve_stair(frame: Dictionary) -> void:
	var n2: Vector2 = frame.n
	var mouth: Vector2 = frame.mouth
	var from := -float(frame.run) - Delves.WALL - 0.6
	var low := float(frame.y) - float(frame.drop) - 3.0
	var s := 0.0
	while s >= from - 0.01:
		var q := mouth + n2 * s
		var gi := int(round((q.x - grid_min.x) / cell))
		var gj := int(round((q.y - grid_min.y) / cell))
		if gi >= 0 and gj >= 0 and gi < count and gj < count:
			heights[gj * count + gi] = minf(heights[gj * count + gi], low)
		s -= cell


# --- The shape -------------------------------------------------------------------

## Where the escarpment's foot stands at angle `th` (radians about the
## middle, atan2(z, x)): the basin's radius, wandering.
func edge_r(th: float) -> float:
	return r_in * (1.0 + float(E.get("wander", 0.07)) * _circle(_rim, th))


## The escarpment's height at angle `th` (cliff_m [lo, hi]).
func cliff_h(th: float) -> float:
	var c: Array = E.get("cliff_m", [38.0, 80.0])
	return lerpf(float(c[0]), float(c[1]), clampf(0.5 + 0.5 * _circle(_tall, th), 0.0, 1.0))


## The talus's rise at angle `th` (talus_rise_m [lo, hi]).
func talus_h(th: float) -> float:
	var c: Array = E.get("talus_rise_m", [8.0, 18.0])
	return lerpf(float(c[0]), float(c[1]), clampf(0.5 + 0.5 * _circle(_talus, th), 0.0, 1.0))


func _circle(nz: FastNoiseLite, th: float) -> float:
	return nz.get_noise_2d(cos(th) * 3.0, sin(th) * 3.0)


## The wash's line at `s` m out along the way out: its offset across it.
func wash_offset(s: float) -> float:
	var W: Dictionary = G.get("wash", {})
	var from := float(W.get("from_m", 30.0))
	return float(W.get("wander_m", 40.0)) * _bend.get_noise_1d(s) * smoothstep(from, from + 80.0, s)


## How far (m) `p` (x/z) is from the wash's line, and 0..1 how much of
## its run it is on (0 before it starts and once it fades under the
## talus): Vector2(distance, run).
func wash_at(p: Vector2) -> Vector2:
	var W: Dictionary = G.get("wash", {})
	var d := p - center
	var s := d.dot(n)
	var from := float(W.get("from_m", 30.0))
	if s < from:
		return Vector2(INF, 0.0)
	var lat := d.dot(Vector2(-n.y, n.x))
	var th := atan2(d.y, d.x)
	var end := edge_r(th) - float(E.get("talus_width_m", 90.0))
	var run := smoothstep(from, from + 20.0, s) * (1.0 - smoothstep(end - 60.0, end, d.length()))
	return Vector2(absf(lat - wash_offset(s)), run)


## 0..1 how far into the wash's bed `p` is (1 on its line).
func in_wash(p: Vector2) -> float:
	var W: Dictionary = G.get("wash", {})
	var w := wash_at(p)
	if w.y <= 0.0:
		return 0.0
	var half := float(W.get("width_m", 11.0)) * 0.5
	return (1.0 - smoothstep(half * 0.5, half, w.x)) * w.y


## The height the ground's shape gives at (x, z) (the grid samples it).
func raw(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p - center
	var r := d.length()
	var th := atan2(d.y, d.x)
	var h := base_y
	var re := edge_r(th)
	var tw := maxf(float(E.get("talus_width_m", 90.0)), 10.0)
	var t0 := re - tw
	# The basin's roll and ripple (gentler up the talus, where the rise
	# carries the shape).
	var on_floor := 1.0 - smoothstep(t0, re, r)
	h += float(G.get("roll_m", 2.6)) * _roll.get_noise_2dv(p) * lerpf(0.4, 1.0, on_floor)
	h += float(G.get("ripple_m", 0.3)) * _ripple.get_noise_2dv(p) * on_floor
	# The wash, cut into the floor.
	var W: Dictionary = G.get("wash", {})
	var w := wash_at(p)
	if w.y > 0.0:
		var half := float(W.get("width_m", 11.0)) * 0.5
		var cut := 1.0 - smoothstep(0.0, half, w.x)
		h -= float(W.get("depth_m", 1.4)) * cut * cut * (3.0 - 2.0 * cut) * w.y
	# Flat round the stairhead (the yard and the way out of it).
	var f := 1.0 - smoothstep(_flat_a, _flat_b, r)
	h = lerpf(h, base_y, f)
	# The edge: the talus, then the cliff, then the plateau.
	if r > t0:
		var t := clampf((r - t0) / tw, 0.0, 1.0)
		h += talus_h(th) * pow(t, 2.2)
	if r > re:
		var cw := maxf(float(E.get("cliff_width_m", 16.0)), 4.0)
		var c := clampf((r - re) / cw, 0.0, 1.0)
		h += cliff_h(th) * c * c * (3.0 - 2.0 * c)
		# The plateau's own lie, rising a little away from the lip so the
		# lip hides it from below.
		var beyond := maxf(r - re - cw, 0.0)
		h += smoothstep(0.0, 40.0, beyond) * (6.0 * _high.get_noise_2dv(p) + 0.03 * beyond)
	# The landmark butte, on the plateau.
	var L: Dictionary = E.get("landmark", {})
	var lr := float(L.get("radius_m", 60.0))
	var q := p.distance_to(landmark)
	if q < lr + 16.0:
		var k := 1.0 - smoothstep(lr - 10.0, lr + 4.0, q)
		h += float(L.get("height_m", 80.0)) * k
	return h


# --- Reading it ------------------------------------------------------------------

## The ground's height at (x, z): the grid's own triangles (the drawn mesh
## and the collision both), each cell split from its +x corner to its +z
## corner.
func height_at(x: float, z: float) -> float:
	if count < 2:
		return base_y
	var gx := clampf((x - grid_min.x) / cell, 0.0, count - 1.001)
	var gz := clampf((z - grid_min.y) / cell, 0.0, count - 1.001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var i00 := iz * count + ix
	var h00 := heights[i00]
	var h10 := heights[i00 + 1]
	var h01 := heights[i00 + count]
	if fx + fz <= 1.0:
		return h00 + (h10 - h00) * fx + (h01 - h00) * fz
	var h11 := heights[i00 + count + 1]
	return h11 + (h01 - h11) * (1.0 - fx) + (h10 - h11) * (1.0 - fz)


## The ground's slope (rise over run) at (x, z).
func slope_at(x: float, z: float) -> float:
	var e := cell
	var gx := (height_at(x + e, z) - height_at(x - e, z)) / (2.0 * e)
	var gz := (height_at(x, z + e) - height_at(x, z - e)) / (2.0 * e)
	return Vector2(gx, gz).length()


## Inside the basin at `p` (x/z): short of the talus by `margin` m.
func on_floor(p: Vector2, margin := 0.0) -> bool:
	var d := p - center
	return d.length() < edge_r(atan2(d.y, d.x)) - float(E.get("talus_width_m", 90.0)) - margin


## Short of the cliff's foot at `p` (x/z) by `margin` m: the walkable land.
func inside(p: Vector2, margin := 0.0) -> bool:
	var d := p - center
	return d.length() < edge_r(atan2(d.y, d.x)) - margin


## Which ground `p` is: "wash", "upland" (the bajada under the edge, within
## from_edge_m of the cliff's foot), "flats", or "edge" (the cliff and
## beyond).
func zone_at(p: Vector2, from_edge_m: float) -> String:
	var d := p - center
	var re := edge_r(atan2(d.y, d.x))
	var r := d.length()
	if r >= re - 2.0:
		return "edge"
	if in_wash(p) > 0.35 or wash_at(p).x < float((G.get("wash", {}) as Dictionary).get("width_m", 11.0)) * 0.5 + float((G.get("wash", {}) as Dictionary).get("bank_m", 9.0)):
		return "wash"
	if r > re - from_edge_m:
		return "upland"
	return "flats"


# --- Drawing it ------------------------------------------------------------------

## The vertex colour at grid point (i, j) (TerrainChunk's colours, read by
## the terrain shader as its textures: the biome's sand, the wash's paler
## sand, a darker gravel pavement, the talus's dirt, the cliffs' stone).
func _color(i: int, j: int, slope: float, ground_col: Color) -> Color:
	var p := grid_min + Vector2(i, j) * cell
	var d := p - center
	var r := d.length()
	var th := atan2(d.y, d.x)
	var re := edge_r(th)
	var tw := maxf(float(E.get("talus_width_m", 90.0)), 10.0)
	var col := ground_col
	# Desert pavement: gravel packed on the flats, darker than the sand.
	var pav := 0.5 + 0.5 * _pave.get_noise_2dv(p)
	var share := clampf(float(G.get("pavement_share", 0.35)), 0.0, 1.0)
	col = col.lerp(Color(ground_col.r * 0.74, ground_col.g * 0.7, ground_col.b * 0.66), smoothstep(1.0 - share, 1.0 - share + 0.12, pav))
	# The wash's bed: pale, loose sand.
	col = col.lerp(TerrainChunk.SAND, in_wash(p))
	# The talus: dirt and broken rock below the cliffs.
	var t := clampf((r - (re - tw)) / tw, 0.0, 1.0)
	col = col.lerp(TALUS, smoothstep(0.35, 1.0, t))
	# The plateau beyond: dirt and sand.
	if r > re:
		col = col.lerp(TALUS.lerp(ground_col, 0.4), smoothstep(re, re + 30.0, r))
	# Rock wherever it's too steep to hold sand.
	col = col.lerp(TerrainChunk.ROCK, smoothstep(0.75, 1.15, slope))
	col.a = 1.0
	return col


## The talus's dirt (reddish-brown, dark enough that the terrain shader
## reads it as dirt, not sand).
const TALUS := Color(0.46, 0.33, 0.24)


## Every drawn block's mesh arrays (TerrainChunk.GROUND_FORMAT: CUSTOM0 the
## road tread, none here): [[arrays, aabb]...]. `ground_col` the biome's.
func block_arrays(ground_col: Color) -> Array:
	var out: Array = []
	var cells := count - 1
	# Normals and colours once for the whole grid.
	var normals := PackedVector3Array()
	normals.resize(count * count)
	var colors := PackedColorArray()
	colors.resize(count * count)
	for j in count:
		for i in count:
			var hl := heights[j * count + maxi(i - 1, 0)]
			var hr := heights[j * count + mini(i + 1, count - 1)]
			var hd := heights[maxi(j - 1, 0) * count + i]
			var hu := heights[mini(j + 1, count - 1) * count + i]
			var dx := (hr - hl) / ((mini(i + 1, count - 1) - maxi(i - 1, 0)) * cell)
			var dz := (hu - hd) / ((mini(j + 1, count - 1) - maxi(j - 1, 0)) * cell)
			normals[j * count + i] = Vector3(-dx, 1.0, -dz).normalized()
			colors[j * count + i] = _color(i, j, Vector2(dx, dz).length(), ground_col)
	var tread := RoadNetwork.NO_TREAD
	for bj in range(0, cells, BLOCK):
		for bi in range(0, cells, BLOCK):
			var nb_i := mini(BLOCK, cells - bi)
			var nb_j := mini(BLOCK, cells - bj)
			var w := nb_i + 1
			var v := PackedVector3Array()
			var nr := PackedVector3Array()
			var cs := PackedColorArray()
			var uv := PackedVector2Array()
			var cu := PackedFloat32Array()
			v.resize(w * (nb_j + 1))
			nr.resize(v.size())
			cs.resize(v.size())
			uv.resize(v.size())
			cu.resize(v.size() * 4)
			var lo := Vector3(INF, INF, INF)
			var hi := Vector3(-INF, -INF, -INF)
			for jj in nb_j + 1:
				for ii in w:
					var gi := (bj + jj) * count + bi + ii
					var x := grid_min.x + (bi + ii) * cell
					var z := grid_min.y + (bj + jj) * cell
					var p := Vector3(x, heights[gi], z)
					var k := jj * w + ii
					v[k] = p
					nr[k] = normals[gi]
					cs[k] = colors[gi]
					uv[k] = Vector2(x, z)
					cu[k * 4] = tread.x
					cu[k * 4 + 1] = tread.y
					cu[k * 4 + 2] = tread.z
					cu[k * 4 + 3] = tread.w
					lo = lo.min(p)
					hi = hi.max(p)
			var idx := PackedInt32Array()
			idx.resize(nb_i * nb_j * 6)
			var q := 0
			for jj in nb_j:
				for ii in nb_i:
					var i00 := jj * w + ii
					var i10 := i00 + 1
					var i01 := i00 + w
					var i11 := i01 + 1
					# Clockwise seen from above (Godot's front face), split from
					# the +x corner to the +z corner as the collision is.
					idx[q] = i00
					idx[q + 1] = i10
					idx[q + 2] = i01
					idx[q + 3] = i10
					idx[q + 4] = i11
					idx[q + 5] = i01
					q += 6
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = v
			arrays[Mesh.ARRAY_NORMAL] = nr
			arrays[Mesh.ARRAY_COLOR] = cs
			arrays[Mesh.ARRAY_TEX_UV] = uv
			arrays[Mesh.ARRAY_CUSTOM0] = cu
			arrays[Mesh.ARRAY_INDEX] = idx
			out.append([arrays, AABB(lo, hi - lo)])
	return out


## The collision: one HeightMapShape3D of the whole grid, scaled up by
## cell_m (uniformly: its heights are stored over cell_m), standing at the
## grid's middle. [shape, transform].
func collision() -> Array:
	var shape := HeightMapShape3D.new()
	shape.map_width = count
	shape.map_depth = count
	var data := PackedFloat32Array()
	data.resize(heights.size())
	for i in heights.size():
		data[i] = heights[i] / cell
	shape.map_data = data
	var mid := grid_min + Vector2(half_m(), half_m())
	return [shape, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * cell), Vector3(mid.x, 0.0, mid.y))]


## The far band of ranges (far_band): a ring far out round the middle,
## its ridge from noise, lighter and bluer in the haze; the terrain
## material's arrays.
func far_band_arrays(p: Dictionary, seed_value: int) -> Array:
	var F: Dictionary = p.get("far_band", {})
	var radius := maxf(float(F.get("radius_m", 3400.0)), half_m() * 1.5)
	var hr: Array = F.get("height_m", [260.0, 620.0])
	var segs := clampi(int(F.get("segments", 240)), 32, 1024)
	var nz := FastNoiseLite.new()
	nz.seed = hash([seed_value, "far band"])
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	nz.fractal_octaves = 3
	nz.frequency = 0.9
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var cs := PackedColorArray()
	var uv := PackedVector2Array()
	var cu := PackedFloat32Array()
	var idx := PackedInt32Array()
	var tread := RoadNetwork.NO_TREAD
	var bottom := base_y - 40.0
	for k in segs + 1:
		var th := TAU * k / segs
		var dir := Vector2(cos(th), sin(th))
		var t := clampf(0.5 + 0.5 * nz.get_noise_2d(dir.x * 2.5, dir.y * 2.5), 0.0, 1.0)
		var top := base_y + lerpf(float(hr[0]), float(hr[1]), t * t)
		var foot := center + dir * radius
		var crest := center + dir * (radius + (top - base_y) * 0.6)
		v.append(Vector3(foot.x, bottom, foot.y))
		v.append(Vector3(crest.x, top, crest.y))
		# Facing in, toward the basin, tipped up a little.
		var nn := Vector3(-dir.x, 0.6, -dir.y).normalized()
		nr.append(nn)
		nr.append(nn)
		cs.append(TerrainChunk.ROCK)
		cs.append(TerrainChunk.ROCK.lerp(TALUS, 0.3))
		uv.append(Vector2(foot.x, foot.y) * 0.25)
		uv.append(Vector2(crest.x, crest.y + top) * 0.25)
		for c in 2:
			cu.append_array([tread.x, tread.y, tread.z, tread.w])
	for k in segs:
		var a := k * 2
		# Seen from inside the ring (clockwise from the middle).
		idx.append_array([a, a + 3, a + 2, a, a + 1, a + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nr
	arrays[Mesh.ARRAY_COLOR] = cs
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_CUSTOM0] = cu
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays
