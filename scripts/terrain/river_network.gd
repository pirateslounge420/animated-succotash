class_name RiverNetwork
extends RefCounted
## Blueprint rivers as 3D segments for the walkable terrain. Each river
## cell links to its downstream cell (flow_to), giving a segment between
## the two cell centers. Terrain chunks carve a channel along nearby
## segments and lay a water ribbon on top.
##
## Water height along a segment follows the ground: a profile sampled
## every ~6 m that runs from the blueprint's filled level at the upstream
## cell down to the downstream cell's (priority flood: never uphill),
## dropping wherever the terrain under it drops (a running minimum), so the
## water never floats above the land. Where the profile falls sharply
## between two samples, the river pours over a waterfall. Width and depth
## grow with discharge.

const MIN_WIDTH_M := 7.0
const MAX_WIDTH_M := 55.0
const SAMPLE_M := 6.0
## A reach dropping this much in one sample (slope ~1:5) is steep.
const STEEP_M := 1.5
## A drop at least this tall between samples is drawn as a waterfall.
const FALL_MIN_M := 4.0
## The tallest single fall; steeper reaches get a chain of them.
const FALL_MAX_M := 35.0

var a := PackedVector3Array() # upstream end (unit dir)
var b := PackedVector3Array() # downstream end
var level_a := PackedFloat32Array()
var level_b := PackedFloat32Array()
var width := PackedFloat32Array()
var depth := PackedFloat32Array()
var salty := PackedByteArray() # brackish mouths

## blueprint cell -> segment indices touching it (either end)
var _by_cell := {}
var _map: PlanetData
## segment -> water level profile (computed on first use; chunk workers
## share it, hence the mutex)
var _profiles := {}
var _mutex := Mutex.new()


func _init(map: PlanetData) -> void:
	_map = map
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
	return Vector3(dist, t, level_at(seg, t))


## Water level at `t` (0 upstream end, 1 downstream) along a segment.
func level_at(seg: int, t: float) -> float:
	var prof := profile(seg)
	var x := t * (prof.size() - 1)
	var i := clampi(int(x), 0, prof.size() - 2)
	return lerpf(prof[i], prof[i + 1], x - i)


## The segment's water levels, one per ~6 m from upstream to downstream.
func profile(seg: int) -> PackedFloat32Array:
	_mutex.lock()
	var cached = _profiles.get(seg)
	_mutex.unlock()
	if cached != null:
		return cached
	var length := CubeSphere.surface_distance_m(a[seg], b[seg])
	var n := maxi(2, int(ceil(length / SAMPLE_M)))
	var prof := PackedFloat32Array()
	prof.resize(n + 1)
	var la := level_a[seg]
	var lb := level_b[seg]
	prof[0] = la
	for i in range(1, n + 1):
		var p := a[seg].slerp(b[seg], float(i) / n)
		# Half a meter under the ground beside it, never above upstream,
		# never below the downstream cell's level.
		var ground := _map.terrain.elevation(p, true) - 0.5
		prof[i] = clampf(minf(prof[i - 1], ground), lb, la)
	prof[n] = lb
	# Steep reaches pour over one fall at their head instead of a staircase
	# of small ones: the water below drops straight to the reach's foot,
	# and the channel (carved to follow it) cuts a gorge back into the
	# slope, the way real falls retreat upstream.
	# A long steep reach becomes a chain of falls, none taller than
	# FALL_MAX_M.
	var i := 1
	while i <= n:
		if prof[i - 1] - prof[i] >= STEEP_M:
			var top := prof[i - 1]
			var j := i
			while j < n and prof[j] - prof[j + 1] >= STEEP_M * 0.5 and top - prof[j + 1] <= FALL_MAX_M:
				j += 1
			for k in range(i, j + 1):
				prof[k] = prof[j]
			i = j + 1
		else:
			i += 1
	_mutex.lock()
	_profiles[seg] = prof
	_mutex.unlock()
	return prof


## Waterfalls on a segment: [[t, top_level, bottom_level], ...] where the
## profile drops at least FALL_MIN_M between two samples (t is midway).
func falls(seg: int) -> Array:
	var prof := profile(seg)
	var out := []
	var n := prof.size() - 1
	for i in range(1, n + 1):
		if prof[i - 1] - prof[i] >= FALL_MIN_M:
			out.append([(i - 0.5) / n, prof[i - 1], prof[i]])
	return out
