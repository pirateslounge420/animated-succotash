class_name RiverPhases
extends RefCounted
## Reading the river (design 4 Oct §ED.2, data/water/phases.json): every
## stretch of a river is one of seven phases, read by eye: pool, glide,
## riffle, run, rapid, cascade, fall. Each sample of a segment's water
## profile (RiverNetwork.profile, one per ~6 m) is classified by its local
## slope (the water's drop over WINDOW samples either side), eased for a
## wide river (a big river runs calmer on the same slope) and for a narrow
## one the other way; a drop of RiverNetwork.FALL_MIN_M in one sample is a
## fall. The phase's index (0 pool .. 6 fall) goes to the water's look
## (TerrainChunk ribbons: vertex colour r), its sound (WaterSounds), the
## fishing line (fish hold only where `fish` is true) and the thrown spear
## (lost where `spear` is "lost").

static var D: Dictionary = Tuning.table("phases")
const WINDOW := 3
## A river this wide (m) reads its slope as it is; wider ones calmer.
const REF_WIDTH_M := 15.0

static var _cache := {}
static var _mutex := Mutex.new()


static func rows() -> Array:
	return D.get("phases", [])


static func count() -> int:
	return rows().size()


## The phase row at index `i` ({} when out of range).
static func row(i: int) -> Dictionary:
	var r := rows()
	return r[i] if i >= 0 and i < r.size() else {}


static func name_of(i: int) -> String:
	return str(row(i).get("name", ""))


## The phase for a slope (drop per metre), by the rows' slope_max.
static func of_slope(slope: float) -> int:
	var r := rows()
	for i in r.size():
		if slope <= float((r[i] as Dictionary).get("slope_max", 9.0)):
			return i
	return maxi(r.size() - 1, 0)


## Segment `s`'s phases, one per profile sample (cached; chunk workers share
## it, hence the mutex).
static func of_segment(rivers: RiverNetwork, s: int) -> PackedByteArray:
	var key := [rivers.get_instance_id(), s]
	_mutex.lock()
	var have = _cache.get(key)
	_mutex.unlock()
	if have != null:
		return have
	var prof := rivers.profile(s)
	var n := prof.size() - 1
	var out := PackedByteArray()
	out.resize(n + 1)
	var len_m := CubeSphere.surface_distance_m(rivers.a[s], rivers.b[s])
	var step := len_m / maxf(n, 1)
	var ease := clampf(sqrt(REF_WIDTH_M / maxf(rivers.width[s], 1.0)), 0.6, 1.4)
	var fall_i := maxi(count() - 1, 0)
	for i in n + 1:
		var lo := maxi(i - WINDOW, 0)
		var hi := mini(i + WINDOW, n)
		var slope := (prof[lo] - prof[hi]) / maxf((hi - lo) * step, 1.0) * ease
		var ph := of_slope(slope)
		# A fall: the drop between this sample and its neighbour.
		if (i > 0 and prof[i - 1] - prof[i] >= RiverNetwork.FALL_MIN_M) or (i < n and prof[i] - prof[i + 1] >= RiverNetwork.FALL_MIN_M):
			ph = fall_i
		elif ph == fall_i:
			ph = fall_i - 1
		out[i] = ph
	_mutex.lock()
	_cache[key] = out
	_mutex.unlock()
	return out


## The phase at fraction `t` along segment `s`.
static func at_t(rivers: RiverNetwork, s: int, t: float) -> int:
	var ph := of_segment(rivers, s)
	if ph.is_empty():
		return 0
	return ph[clampi(roundi(clampf(t, 0.0, 1.0) * (ph.size() - 1)), 0, ph.size() - 1)]


## The phase of the river water at `d` ({"phase": -1} off any river):
## {"phase", "name", "seg", "t", "dist_m"}.
static func at(rivers: RiverNetwork, map: PlanetData, d: Vector3) -> Dictionary:
	var none := {"phase": -1, "name": "", "seg": -1, "t": 0.0, "dist_m": INF}
	if rivers == null or map == null:
		return none
	var best := -1
	var best_dt := Vector2(INF, 0.0)
	for s in rivers.segments_near(map, map.cell_at(d)):
		var dt := rivers.closest_dt(s, d)
		if dt.x < best_dt.x:
			best_dt = dt
			best = s
	if best < 0 or best_dt.x > rivers.width[best] * 0.5 + 2.0:
		return none
	var ph := at_t(rivers, best, best_dt.y)
	return {"phase": ph, "name": name_of(ph), "seg": best, "t": best_dt.y, "dist_m": best_dt.x}


## Do fish hold here (phases.json fish)? Standing water (a lake, the sea:
## no river phase) always may.
static func fish_hold(rivers: RiverNetwork, map: PlanetData, d: Vector3) -> bool:
	var p := at(rivers, map, d)
	if int(p.phase) < 0:
		return true
	return bool(row(int(p.phase)).get("fish", true))


## Is a spear landing here carried off (phases.json spear "lost")?
static func takes_spear(rivers: RiverNetwork, map: PlanetData, d: Vector3) -> bool:
	var p := at(rivers, map, d)
	if int(p.phase) < 0:
		return false
	return str(row(int(p.phase)).get("spear", "recoverable")) == "lost"


## How loud the river sounds in this phase (0-1), from its sound word.
const LOUD := {"hush": 0.12, "low": 0.25, "chatter": 0.45, "rush": 0.65, "roar": 0.85, "thunder": 1.0}


static func loudness(i: int) -> float:
	return float(LOUD.get(str(row(i).get("sound", "low")), 0.3))
