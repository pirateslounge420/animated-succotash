class_name PlanetData
extends RefCounted
## The planet "blueprint": coarse per-cell data over the whole cube-sphere
## (about 1 km cells at the default resolution). Each generation pass
## fills some of these arrays; see PlanetGenerator for the order.
##
## Cell index = face * res * res + j * res + i. Neighbor lists already
## cross face edges, so passes never need to special-case seams.

enum Water { NONE, OCEAN, LAKE, RIVER }

## Ocean is salt; rivers and most lakes are fresh. A lake in a hot, dry
## basin that evaporates more than it receives turns salt (salt flats);
## river mouths and lagoons are brackish.
enum Salinity { FRESH, BRACKISH, SALT }

## Rock/soil types (GeologyPass). Read by vegetation soil preferences and
## by the special-terrain biomes (volcanic fields, karst, badlands, ...).
enum Rock { GRANITE, BASALT_VOLCANIC, LIMESTONE_KARST, SANDSTONE, ALLUVIAL, COASTAL_SAND, CLAY_PEAT, GLACIAL_TILL }

var res: int
var cell_count: int
var terrain: TerrainField

var dir: PackedVector3Array
var lat: PackedFloat32Array # radians
var neighbors: PackedInt32Array # 8 per cell; first 4 are edge-adjacent

# Pass 1: terrain
var elevation: PackedFloat32Array # meters above sea level
var slope: PackedFloat32Array # rise over run (0 = flat, 1 = 45 degrees)

# Pass 2: hydrology
var water: PackedByteArray # Water
var water_level: PackedFloat32Array # surface elevation for lakes/rivers/ocean
var flow_to: PackedInt32Array # downstream cell, -1 if none
var flow_order: PackedInt32Array # cells from the sea upward; reverse it to go downstream
var flow_accum: PackedFloat32Array # upstream precipitation (discharge), in meters/yr over default ~1 km cells
var salinity: PackedByteArray # Salinity
var coast_dist_km: PackedFloat32Array # distance to ocean (0 in ocean)
var water_dist_km: PackedFloat32Array # distance to any water

# Pass 3: geology
var rock: PackedByteArray # Rock

# Pass 4: climate (long-term averages from the weather simulation)
var temp_c: PackedFloat32Array # mean temperature at this cell's elevation
var temp_swing_c: PackedFloat32Array # typical day-night swing
var precip_mm: PackedFloat32Array # annual-equivalent precipitation
var moisture: PackedFloat32Array # 0-1 effective moisture (precip vs heat)
var fog: PackedFloat32Array # 0-1 fog likelihood
var wind_avg: PackedVector3Array # mean wind, tangent to the surface (m/s)

# Pass 5: biome
var biome: PackedInt32Array # BiomeTemplates id


func _init(p_res: int, p_terrain: TerrainField) -> void:
	res = p_res
	terrain = p_terrain
	cell_count = 6 * res * res
	dir.resize(cell_count)
	lat.resize(cell_count)
	for f in 6:
		for j in res:
			for i in res:
				var d := CubeSphere.to_dir(f, _uv(i), _uv(j))
				var idx := index(f, i, j)
				dir[idx] = d
				lat[idx] = CubeSphere.latitude(d)
	_build_neighbors()

	elevation.resize(cell_count)
	slope.resize(cell_count)
	water_level.resize(cell_count)
	flow_accum.resize(cell_count)
	coast_dist_km.resize(cell_count)
	water_dist_km.resize(cell_count)
	temp_c.resize(cell_count)
	temp_swing_c.resize(cell_count)
	precip_mm.resize(cell_count)
	moisture.resize(cell_count)
	fog.resize(cell_count)
	water.resize(cell_count)
	salinity.resize(cell_count)
	rock.resize(cell_count)
	flow_to.resize(cell_count)
	biome.resize(cell_count)
	wind_avg.resize(cell_count)


func _uv(i: int) -> float:
	return (float(i) + 0.5) / float(res) * 2.0 - 1.0


func index(face: int, i: int, j: int) -> int:
	return face * res * res + j * res + i


## Nearest cell to a direction.
## Soil classes by name, in Rock order (data/soil.json "classes"; the
## names plant data uses).
const SOIL_NAMES: Array[String] = ["granite", "basalt", "karst", "sandstone", "alluvium", "sand", "clay_peat", "till"]
static var _soil_warp: FastNoiseLite
static var _soil_warp_cells := -1.0


static func soil_name(rock_class: int) -> String:
	return SOIL_NAMES[clampi(rock_class, 0, SOIL_NAMES.size() - 1)]


## The soil class (a Rock value) at any point: the geology pass's class
## for the cell there, looked up through a gentle noise warp of
## data/soil.json boundary_warp_cells of a cell, so soil borders wander
## instead of following the grid. What plant placement gates on.
func soil_at(d: Vector3) -> int:
	if _soil_warp == null:
		_soil_warp = FastNoiseLite.new()
		_soil_warp.seed = terrain.world_seed * 31 + 7 if terrain else 7
		_soil_warp.frequency = 1.0
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/soil.json")) if FileAccess.file_exists("res://data/soil.json") else null
		_soil_warp_cells = float(parsed.get("boundary_warp_cells", 0.6)) if parsed is Dictionary else 0.6
	# A cell spans about (PI / 2) / res radians.
	var cell := PI * 0.5 / res
	var f := 1.0 / cell
	var p := d * f
	var w := Vector3(_soil_warp.get_noise_3dv(p), _soil_warp.get_noise_3dv(p + Vector3(31.7, 0.0, 0.0)), _soil_warp.get_noise_3dv(p + Vector3(0.0, 47.3, 0.0)))
	return rock[cell_at((d + w * cell * _soil_warp_cells).normalized())]


func cell_at(d: Vector3) -> int:
	var f := CubeSphere.face_of(d)
	var uv := CubeSphere.face_uv(f, d)
	var i := clampi(int((uv.x + 1.0) * 0.5 * res), 0, res - 1)
	var j := clampi(int((uv.y + 1.0) * 0.5 * res), 0, res - 1)
	return index(f, i, j)


## Smooth sample of a per-cell float array at any direction (see
## weights_at), continuous across cube-face edges.
func sample(arr: PackedFloat32Array, d: Vector3) -> float:
	var w := weights_at(d)
	var cells: PackedInt32Array = w[0]
	var k: PackedFloat32Array = w[1]
	var v := 0.0
	for i in cells.size():
		v += arr[cells[i]] * k[i]
	return v


## sample() with weights already found (weights_at): several values at
## one spot for the price of one lookup.
func sample_w(arr: PackedFloat32Array, w: Array) -> float:
	var cells: PackedInt32Array = w[0]
	var k: PackedFloat32Array = w[1]
	var v := 0.0
	for i in cells.size():
		v += arr[cells[i]] * k[i]
	return v


## Interpolation weights at a surface direction: [cells, weights], weights
## summing to 1. Bilinear between the four surrounding cell centers inside
## a face. Within half a cell of a face edge there is no four-cell square
## on one face, so it switches to a tent kernel over the containing cell
## and its 8 neighbors (which cross the edge); the two agree along the
## line where they meet, so values and colors run on seamlessly across
## cube-face edges.
func weights_at(d: Vector3) -> Array:
	var f := CubeSphere.face_of(d)
	var uv := CubeSphere.face_uv(f, d)
	var x := (uv.x + 1.0) * 0.5 * res - 0.5
	var y := (uv.y + 1.0) * 0.5 * res - 0.5
	if x >= 0.0 and y >= 0.0 and x <= res - 1.0 and y <= res - 1.0:
		var i0 := mini(int(x), res - 2)
		var j0 := mini(int(y), res - 2)
		var tx := x - i0
		var ty := y - j0
		return [
			PackedInt32Array([index(f, i0, j0), index(f, i0 + 1, j0), index(f, i0, j0 + 1), index(f, i0 + 1, j0 + 1)]),
			PackedFloat32Array([(1.0 - tx) * (1.0 - ty), tx * (1.0 - ty), (1.0 - tx) * ty, tx * ty]),
		]
	var c := cell_at(d)
	var spacing := PI * 0.5 / res
	var cells := PackedInt32Array([c])
	var w := PackedFloat32Array([maxf(0.0, 1.0 - CubeSphere.angle_between(d, dir[c]) / spacing) + 1e-6])
	var total := w[0]
	for k in 8:
		var n := neighbors[c * 8 + k]
		if n < 0:
			continue
		var wn := maxf(0.0, 1.0 - CubeSphere.angle_between(d, dir[n]) / spacing)
		if wn > 0.0:
			cells.append(n)
			w.append(wn)
			total += wn
	for i in w.size():
		w[i] /= total
	return [cells, w]


func neighbor(cell: int, k: int) -> int:
	return neighbors[cell * 8 + k]


## Approximate cell width in km (cells vary ~40% in size across a face),
## in geographic km: the blueprint's distances (coast_dist_km,
## water_dist_km) are measured on the geography's full-size map, which on
## the dev postage stamp is larger than the real planet (see PlanetConst).
func cell_km() -> float:
	return PlanetConst.GEO_CIRCUMFERENCE_M / 4.0 / res / 1000.0


## Approximate cell width in real meters (walking scale).
func cell_m() -> float:
	return PlanetConst.CIRCUMFERENCE_M / 4.0 / res


## A cell's width relative to the default ~1 km cell (1 at
## PlanetGenerator.DEFAULT_RES; 2 at half that resolution). Rules written
## in whole default cells (minimum sea size, biome patch caps, relief
## between neighbors) scale by it, so a coarser blueprint, like the dev
## postage stamp's, keeps the same geography.
func cell_scale() -> float:
	return float(PlanetGenerator.DEFAULT_RES) / float(res)


## A count of default ~1 km cells, as a count of this blueprint's cells
## (same area; at least 1).
func cells_for(default_cells: float) -> int:
	return maxi(1, roundi(default_cells / (cell_scale() * cell_scale())))


func _build_neighbors() -> void:
	neighbors.resize(cell_count * 8)
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	for f in 6:
		for j in res:
			for i in res:
				var idx := index(f, i, j)
				for k in 8:
					var ni := i + offsets[k].x
					var nj := j + offsets[k].y
					var n: int
					if ni >= 0 and ni < res and nj >= 0 and nj < res:
						n = index(f, ni, nj)
					else:
						# Step off the face on the cube plane; the direction
						# lands on the adjacent face.
						n = cell_at(CubeSphere.to_dir(f, _uv(ni), _uv(nj)))
					neighbors[idx * 8 + k] = n
