class_name RiverNetwork
extends RefCounted
## Blueprint rivers as 3D segments for the walkable terrain. Each river
## cell links to its downstream cell (flow_to), giving a segment between
## the two cell centers. Terrain chunks carve a channel along nearby
## segments and lay a water ribbon on top.
##
## Water height along a segment comes from the blueprint's filled
## water_level, which only ever decreases downstream (priority flood), so
## rivers never run uphill. Width and depth grow with discharge.

const MIN_WIDTH_M := 7.0
const MAX_WIDTH_M := 55.0

var a := PackedVector3Array() # upstream end (unit dir)
var b := PackedVector3Array() # downstream end
var level_a := PackedFloat32Array()
var level_b := PackedFloat32Array()
var width := PackedFloat32Array()
var depth := PackedFloat32Array()
var salty := PackedByteArray() # brackish mouths

## blueprint cell -> segment indices touching it (either end)
var _by_cell := {}


func _init(map: PlanetData) -> void:
	for c in map.cell_count:
		if map.water[c] != PlanetData.Water.RIVER:
			continue
		var t := map.flow_to[c]
		if t < 0:
			continue
		var i := a.size()
		a.append(map.dir[c])
		b.append(map.dir[t])
		var la := map.water_level[c]
		var lb := map.water_level[t]
		if map.water[t] == PlanetData.Water.OCEAN:
			lb = PlanetConst.SEA_LEVEL_M
		level_a.append(la)
		level_b.append(minf(lb, la))
		var w := clampf(MIN_WIDTH_M + 3.0 * sqrt(map.flow_accum[c]), MIN_WIDTH_M, MAX_WIDTH_M)
		width.append(w)
		depth.append(1.2 + w * 0.05)
		salty.append(1 if map.salinity[c] == PlanetData.Salinity.BRACKISH else 0)
		_add(c, i)
		_add(t, i)


func _add(cell: int, seg: int) -> void:
	if not _by_cell.has(cell):
		_by_cell[cell] = PackedInt32Array()
	var arr: PackedInt32Array = _by_cell[cell]
	arr.append(seg)
	_by_cell[cell] = arr


## Segments touching a cell or its 8 neighbors.
func segments_near(map: PlanetData, cell: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var seen := {}
	for k in 9:
		var n := cell if k == 8 else map.neighbors[cell * 8 + k]
		if not _by_cell.has(n):
			continue
		for s in _by_cell[n]:
			if not seen.has(s):
				seen[s] = true
				out.append(s)
	return out


## Closest point info for a surface direction against one segment:
## Vector3(distance_m, t along segment, water level at that t).
func closest(seg: int, d: Vector3) -> Vector3:
	var pa := a[seg]
	var pb := b[seg]
	var ab := pb - pa
	var t := clampf((d - pa).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
	var p := (pa + ab * t).normalized()
	var dist := CubeSphere.surface_distance_m(p, d)
	return Vector3(dist, t, lerpf(level_a[seg], level_b[seg], t))
