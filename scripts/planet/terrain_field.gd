class_name TerrainField
extends RefCounted
## Continuous planet elevation (meters above sea level) at any unit
## direction. Seamless everywhere on the sphere because it samples 3D noise
## at the surface point, not per-face 2D noise.
##
## Both the coarse planet blueprint (PlanetGenerator, ~1 km cells) and the
## walkable terrain chunks (TerrainChunk, a few meters per cell) call this
## same function, so they always agree about where land, coast and
## mountains are. Chunks add a fine detail layer on top (detail = true).
##
## Layers:
##   continent  - big low-frequency shapes; its value decides land vs sea.
##                The land/sea threshold is calibrated at construction so
##                the planet ends up with exactly `ocean_fraction` ocean.
##   belts      - where mountain ranges are allowed (long linear belts).
##   ridges     - ridged noise inside the belts: the actual mountain crests.
##   hills      - rolling relief over all land.
##   hotspots   - a few seeded volcanic cones with craters (volcanic
##                fields, hot springs).
##   great ranges - a handful of long ranges (design 3 Oct §CR.4,
##                data/world_scale.json mountains: 4-7 a world, summits of
##                500-885 m) that keep real angles: flanks averaging about
##                FLANK_DEG, a crest that rises to one summit and dips to
##                passes, spurs and gullies down the flanks; at walking
##                scale (detail) part of each flank steps into sheer
##                faces (CLIFF_*), barriers with gaps between them where
##                the ways up go. The ordinary belts stay below them
##                (MAX_MOUNTAIN_M). Not on the dev postage stamp.
##   detail     - meter-scale roughness for walking; blueprint skips it.
##   roll       - gentle ~60 m swells (a couple of meters) so slopes roll
##                at walking scale; fades out near sea level so coastlines
##                keep their shape. Blueprint skips it too.
##   escarpments- in some inland regions, long winding cliff lines where
##                the land steps up ESCARP_M over ~10 m: cliff faces,
##                plateaus, rock shelters at their feet (Camps).
##   ravines    - in some hill country, narrow cuts RAVINE_M deep with
##                steep walls and a flat floor, meandering for km. Where
##                one crosses dry sandstone it pinches to a slot canyon a
##                few metres wide (design 1 Oct §CK, Nests.slot_at).
##   nests      - the cenote and doline stamps (design 1 Oct §CK,
##                Nests.stamp): a round shaft or bowl cut into karst, added
##                with `detail` unless `stamps` is false.
##                Escarpments and ravines are walking-scale detail too (a
##                1 km blueprint cell can't hold them): rivers cut through
##                them (TerrainChunk forces their beds), as gorges.

## Geographic layers are Earth-like heights times PlanetConst.HEIGHT_SCALE;
## the walking-scale layers (detail, shore wiggle, roll) aren't scaled:
## they're the feel of the ground underfoot, not geography.
##
## Sideways, the geographic layers (continents, belts, ridges, hills,
## hotspots, and the masks that say which regions have escarpments and
## ravines) are laid out at PlanetConst.GEO_RADIUS_M; the walking-scale
## layers (detail, shore, roll, the escarpment and ravine lines
## themselves) at the real radius. The same on the full planet; on the dev
## postage stamp the geography is a shrunk copy while the ground underfoot
## keeps its real grain.
const H := PlanetConst.HEIGHT_SCALE
## The ordinary belts' mountains: below the great ranges' 500 m (§CR.4).
const MAX_MOUNTAIN_M := 4000.0 * H
const MAX_PLATEAU_M := 700.0 * H
const HILLS_M := 170.0 * H
const MAX_DEPTH_M := 3800.0 * H
const SHELF_DEPTH_M := 140.0 * H
const DETAIL_M := 14.0
const ROLL_M := 2.0
const ESCARP_M := 14.0
const RAVINE_M := 12.0

const HOTSPOT_COUNT := 9
const HOTSPOT_HEIGHT_M := Vector2(700.0, 2000.0) * H
const HOTSPOT_RADIUS_M := Vector2(3500.0, 7000.0)

## The great ranges (§CR.4): how steep their flanks are on average, how
## long a range is (each way from its middle), its spurs, and the sheer
## faces cut into its flanks at walking scale: a staircase on the range's
## height, steps CLIFF_STEP_M tall whose risers take CLIFF_RISER of the
## way across and CLIFF_RISE of the height, where the cliff mask (a noise
## over the flank, CLIFF_MASK its threshold) says so.
const FLANK_DEG := 24.0
const RANGE_HALF_LEN_M := Vector2(7000.0, 13000.0)
const SPUR_SHARE := 0.12
const CLIFF_STEP_M := 40.0
const CLIFF_RISER := 0.18
const CLIFF_RISE := 0.975
const CLIFF_MASK := -0.7

var world_seed: int
var ocean_fraction: float
## The great ranges: [{"center", "axis", "side" (unit tangents),
## "half_len_m", "summit_m", "t0" (where the summit stands along the axis,
## -1..1), "summit" (its direction)}], seeded (data/world_scale.json
## mountains.great_ranges, summit_m_earth).
var great_ranges: Array = []
var sea_threshold := 0.0

## Hotspot directions and parameters, public so GeologyPass can mark
## volcanic rock around them.
var hotspot_dirs: Array[Vector3] = []
var hotspot_heights: PackedFloat32Array = PackedFloat32Array()
var hotspot_radii: PackedFloat32Array = PackedFloat32Array()

var _continent := FastNoiseLite.new()
var _belts := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _shore := FastNoiseLite.new()
var _roll := FastNoiseLite.new()
var _escarp := FastNoiseLite.new()
var _escarp_mask := FastNoiseLite.new()
var _ravine := FastNoiseLite.new()
var _ravine_mask := FastNoiseLite.new()
var _crest := FastNoiseLite.new()
var _spur := FastNoiseLite.new()
var _cliff := FastNoiseLite.new()


func _init(p_seed: int, p_ocean_fraction := 0.62) -> void:
	world_seed = p_seed
	ocean_fraction = p_ocean_fraction

	_setup(_continent, 0, 1.0 / 70000.0, 5)
	_setup(_belts, 1, 1.0 / 45000.0, 2)
	_setup(_ridges, 2, 1.0 / 30000.0, 3)
	_setup(_hills, 3, 1.0 / 8000.0, 3)
	_setup(_detail, 4, 1.0 / 180.0, 3)
	_setup(_shore, 5, 1.0 / 900.0, 2)
	_setup(_roll, 6, 1.0 / 60.0, 2)
	_setup(_escarp, 7, 1.0 / 2500.0, 2)
	_setup(_escarp_mask, 8, 1.0 / 20000.0, 1)
	_setup(_ravine, 9, 1.0 / 3000.0, 1)
	_setup(_ravine_mask, 10, 1.0 / 15000.0, 1)
	_setup(_crest, 11, 1.0 / 3000.0, 2)
	_setup(_spur, 12, 1.0 / 1400.0, 3)
	_setup(_cliff, 13, 1.0 / 900.0, 2)

	_calibrate_sea_threshold()
	_place_hotspots()
	_place_great_ranges()


func _setup(noise: FastNoiseLite, seed_offset: int, frequency: float, octaves: int) -> void:
	noise.seed = world_seed * 7919 + seed_offset
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves


## Samples the continent layer at many seeded random points and picks the
## value below which `ocean_fraction` of the planet lies.
func _calibrate_sea_threshold() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 11
	var samples := PackedFloat32Array()
	for i in 6000:
		samples.append(_continent_value(_random_dir(rng)))
	samples.sort()
	sea_threshold = samples[int(ocean_fraction * (samples.size() - 1))]


func _place_hotspots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 23
	for i in HOTSPOT_COUNT:
		hotspot_dirs.append(_random_dir(rng))
		hotspot_heights.append(rng.randf_range(HOTSPOT_HEIGHT_M.x, HOTSPOT_HEIGHT_M.y))
		hotspot_radii.append(rng.randf_range(HOTSPOT_RADIUS_M.x, HOTSPOT_RADIUS_M.y))


static func _random_dir(rng: RandomNumberGenerator) -> Vector3:
	# Uniform on the sphere.
	var z := rng.randf_range(-1.0, 1.0)
	var t := rng.randf_range(0.0, TAU)
	var r := sqrt(1.0 - z * z)
	return Vector3(r * cos(t), z, r * sin(t))


func _continent_value(dir: Vector3) -> float:
	var p := dir * PlanetConst.GEO_RADIUS_M
	return _continent.get_noise_3dv(p)


## How far inland a point is, in continent-noise units (> 0 is land).
func landness(dir: Vector3) -> float:
	return _continent_value(dir) - sea_threshold


## `roll` false leaves out the walking-scale roll layer (Ruins uses that to
## pick sites, so ruins don't move with 2 m of noise). `stamps` false
## leaves out the nests' stamps (design 1 Oct §CK): the sites passes (Ruins,
## Nests) read the ground as it was before any was cut.
func elevation(dir: Vector3, detail := false, roll := true, stamps := true) -> float:
	var p := dir * PlanetConst.GEO_RADIUS_M
	var x := _continent.get_noise_3dv(p) - sea_threshold
	var e: float
	if x > 0.0:
		var inland := smoothstep(0.0, 0.35, x)
		var plateau := MAX_PLATEAU_M * pow(inland, 1.5) + 2.0 * H
		var belt := smoothstep(0.05, 0.4, _belts.get_noise_3dv(p))
		# Soft absolute value rounds the ridge crest instead of a knife edge.
		var rn := _ridges.get_noise_3dv(p)
		var ridge := 1.0 - sqrt(rn * rn + 0.004)
		var mountains := MAX_MOUNTAIN_M * smoothstep(0.35, 1.0, ridge) * belt * smoothstep(0.02, 0.16, x)
		var hills := _hills.get_noise_3dv(p) * HILLS_M * (0.25 + inland) * smoothstep(0.0, 0.05, x)
		e = plateau + mountains + hills + _ranges_height(dir, detail) * smoothstep(0.0, 0.05, x)
	else:
		# Shallow continental shelf near the coast, then the drop to the deep.
		var shelf := SHELF_DEPTH_M * smoothstep(0.0, 0.06, -x)
		var deep := (MAX_DEPTH_M - SHELF_DEPTH_M) * pow(smoothstep(0.05, 0.4, -x), 1.2)
		e = -2.0 * H - shelf - deep
	e += _hotspot_height(dir)
	if detail:
		var pw := dir * PlanetConst.RADIUS_M # walking scale
		# Shore noise is small but wiggles the coastline at walking scale.
		e += _detail.get_noise_3dv(pw) * DETAIL_M + _shore.get_noise_3dv(pw) * 6.0
		if roll:
			e += _roll.get_noise_3dv(pw) * ROLL_M * smoothstep(1.5, 6.0, absf(e))
		if x > 0.06:
			e += _cliffs(dir, p, pw, x, e)
		if stamps and Nests.terrain == self:
			e = Nests.stamp(dir, e)
	return e


## Escarpments and ravines (see the class notes): the height to add at
## `p` (geographic point on the sphere) / `pw` (walking-scale point), `x`
## inland-ness, `e` so far.
func _cliffs(dir: Vector3, p: Vector3, pw: Vector3, x: float, e: float) -> float:
	var inland := smoothstep(0.06, 0.2, x)
	var add := 0.0
	var em := smoothstep(0.1, 0.35, _escarp_mask.get_noise_3dv(p)) * inland
	if em > 0.0:
		add += ESCARP_M * em * smoothstep(-0.0012, 0.0012, _escarp.get_noise_3dv(pw))
	var rm := smoothstep(0.05, 0.3, _ravine_mask.get_noise_3dv(p)) * inland * smoothstep(6.0, 14.0, e)
	if rm > 0.0:
		var n := absf(_ravine.get_noise_3dv(pw))
		if n < RAVINE_RIM_N:
			# Through dry sandstone the cut pinches to a slot (design 1 Oct
			# §CK slot_canyon): the floor a few metres wide, the walls near
			# sheer. Elsewhere the same profile as before.
			var slot := Nests.slot_at(dir) if Nests.terrain == self else 0.0
			var rim_n := lerpf(RAVINE_RIM_N, SLOT_RIM_N, slot)
			if n < rim_n:
				add -= minf(RAVINE_M, e - 3.0) * rm * smoothstep(rim_n, lerpf(RAVINE_FLOOR_N, SLOT_FLOOR_N, slot), n)
	return add


## The ravine layer's profile in its noise (|n|): full depth inside the
## floor value, the rim at the rim value; a slot canyon's narrower.
const RAVINE_RIM_N := 0.0105
const RAVINE_FLOOR_N := 0.0065
const SLOT_RIM_N := 0.0030
const SLOT_FLOOR_N := 0.0010


## 0-1 a slot canyon's sandy bed at `dir` (design 1 Oct §CK slot_canyon:
## "a floor of sand and gravel"), for the ground's colour; wide enough to
## show on the 8 m colour grid (the walls go to rock on their slope).
func slot_floor(dir: Vector3) -> float:
	if Nests.terrain != self:
		return 0.0
	var n := absf(line_noise(dir, "ravine"))
	if n >= SLOT_RIM_N * 1.5:
		return 0.0
	var s := Nests.slot_at(dir)
	if s <= 0.0:
		return 0.0
	return s * smoothstep(SLOT_RIM_N * 1.5, SLOT_FLOOR_N * 2.0, n) * smoothstep(0.3, 0.6, line_mask(dir, "ravine"))


## The walking-scale line noise at `dir` for the sites pass (Nests): the
## escarpment's ("escarp": its face where it crosses 0, the plateau on the
## + side) or the ravine's ("ravine": its floor's middle where it crosses
## 0, signed).
func line_noise(dir: Vector3, which: String) -> float:
	var pw := dir * PlanetConst.RADIUS_M
	return _escarp.get_noise_3dv(pw) if which == "escarp" else _ravine.get_noise_3dv(pw)


## How much of the escarpment's height (0-1, times ESCARP_M) or of the
## ravine's depth (times RAVINE_M) stands at `dir`: the regional masks
## _cliffs() applies, without the line itself.
func line_mask(dir: Vector3, which: String) -> float:
	var p := dir * PlanetConst.GEO_RADIUS_M
	var x := _continent.get_noise_3dv(p) - sea_threshold
	if x <= 0.06:
		return 0.0
	var inland := smoothstep(0.06, 0.2, x)
	if which == "escarp":
		return smoothstep(0.1, 0.35, _escarp_mask.get_noise_3dv(p)) * inland
	var e := elevation(dir, false)
	return smoothstep(0.05, 0.3, _ravine_mask.get_noise_3dv(p)) * inland * smoothstep(6.0, 14.0, e) * clampf((e - 3.0) / RAVINE_M, 0.0, 1.0)


## Seed the great ranges (§CR.4): 4-7 a world, each on land, apart from
## one another, its summit 500-885 m (summit_m_earth x HEIGHT_SCALE). On the
## dev postage stamp (geography a tenth the size) there are none.
func _place_great_ranges() -> void:
	great_ranges.clear()
	if PlanetConst.GEO_SCALE < 0.5:
		return
	var mt: Dictionary = Tuning.table("world_scale").get("mountains", {})
	var n_range: Array = mt.get("great_ranges", [4, 7])
	var sm: Array = mt.get("summit_m_earth", [5000, 8850])
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * 131 + 977
	var want := rng.randi_range(int(n_range[0]), int(n_range[1]))
	var tries := 0
	while great_ranges.size() < want and tries < 20000:
		tries += 1
		var c := _random_dir(rng)
		if landness(c) < 0.12:
			continue
		var far_enough := true
		for g in great_ranges:
			if CubeSphere.geo_distance_m(c, g.center) < 45000.0:
				far_enough = false
				break
		if not far_enough:
			continue
		var axis := CubeSphere.north(c).rotated(c, rng.randf() * TAU)
		var hl := rng.randf_range(RANGE_HALF_LEN_M.x, RANGE_HALF_LEN_M.y)
		# Both ends on land too.
		var e1 := (c + axis * hl / PlanetConst.GEO_RADIUS_M).normalized()
		var e2 := (c - axis * hl / PlanetConst.GEO_RADIUS_M).normalized()
		if landness(e1) < 0.04 or landness(e2) < 0.04:
			continue
		# The first range is the world's highest (an Everest-class summit);
		# the rest anywhere in the band.
		var top := float(sm[1]) if great_ranges.is_empty() else rng.randf_range(float(sm[0]), float(sm[1]))
		var t0 := rng.randf_range(-0.35, 0.35)
		# The summit's height above sea level is the target: the range
		# stands on what is there (plateau, hills), so it adds the rest.
		var at := (c + axis * t0 * hl / PlanetConst.GEO_RADIUS_M).normalized()
		var base := maxf(elevation(at, false), 0.0)
		var g := {"center": c, "axis": axis, "side": c.cross(axis).normalized(), "half_len_m": hl, "summit_m": maxf(top * H - base, top * H * 0.5), "summit_target_m": top * H, "t0": t0}
		great_ranges.append(g)
	for g in great_ranges:
		g["summit"] = _range_summit(g)


## Where a range's summit stands: up its crest from the summit's place.
func _range_summit(g: Dictionary) -> Vector3:
	var best: Vector3 = (g.center + g.axis * float(g.t0) * float(g.half_len_m) / PlanetConst.GEO_RADIUS_M).normalized()
	var bh := elevation(best, false)
	var step := 400.0
	while step > 5.0:
		var moved := false
		for k in 8:
			var a := k * TAU / 8.0
			var t: Vector3 = (g.axis * cos(a) + g.side * sin(a))
			var cand := (best + t * step / PlanetConst.GEO_RADIUS_M).normalized()
			var h := elevation(cand, false)
			if h > bh:
				bh = h
				best = cand
				moved = true
		if not moved:
			step *= 0.5
	return best


## The great ranges' height at `dir` (§CR.4): each range is a crest along
## its axis, highest at its summit, dipping to passes (crest noise),
## tapering at its ends; its flanks fall at FLANK_DEG on average, steeper
## near the crest (the profile's power), cut by spurs and gullies. With
## `detail`, sheer faces step part of each flank (CLIFF_*).
func _ranges_height(dir: Vector3, detail: bool) -> float:
	if great_ranges.is_empty():
		return 0.0
	var total := 0.0
	var rr := PlanetConst.GEO_RADIUS_M
	for g in great_ranges:
		var hl := float(g.half_len_m)
		var c: Vector3 = g.center
		var reach := (hl + float(g.summit_m) / tan(deg_to_rad(FLANK_DEG)) * 1.2) / rr
		if dir.dot(c) < cos(reach):
			continue
		var rel := dir - c * dir.dot(c)
		var along := rel.dot(g.axis) * rr
		var across := rel.dot(g.side) * rr
		var t := along / hl
		if absf(t) >= 1.0:
			continue
		var p := dir * rr
		# The crest: the summit's bump over a high ridge, passes where the
		# crest noise dips, the ends tapering.
		var t0 := float(g.t0)
		var bump := exp(-pow((t - t0) / 0.3, 2.0))
		var ridge := 0.5 + 0.12 * _crest.get_noise_3dv(p)
		var crest := float(g.summit_m) * (ridge + (1.0 - ridge) * bump) * smoothstep(1.0, 0.72, absf(t))
		var half_w := crest / tan(deg_to_rad(FLANK_DEG))
		if half_w <= 1.0:
			continue
		var u := absf(across) / half_w
		if u >= 1.0:
			continue
		var prof := pow(1.0 - u, 1.3)
		# Spurs and gullies down the flanks (none on the crest line).
		var spur := 1.0 + SPUR_SHARE * _spur.get_noise_3dv(p) * smoothstep(0.0, 0.25, u)
		var hr := crest * prof * spur
		if detail:
			hr = _cliff_steps(hr, dir, u)
		total = maxf(total, hr)
	return total


## Sheer faces (§CR.4, world_scale.json cliff_min_deg, cliff_share): where
## the cliff mask is up, the range's height `h` climbs in steps
## CLIFF_STEP_M tall: a riser taking CLIFF_RISER of each step's way across
## and CLIFF_RISE of its height (several times the flank's own grade,
## sheer), a gentle bench between. Not on the crest or at the foot (`u`,
## 0 at the crest, 1 at the foot).
func _cliff_steps(h: float, dir: Vector3, u: float) -> float:
	var m := smoothstep(CLIFF_MASK, CLIFF_MASK + 0.08, _cliff.get_noise_3dv(dir * PlanetConst.RADIUS_M)) * smoothstep(0.04, 0.1, u) * smoothstep(0.98, 0.9, u)
	if m <= 0.0:
		return h
	var k := h / CLIFF_STEP_M
	var f: float = k - floorf(k)
	# Over the step: the bench rises (1 - RISE) of the height over (1 -
	# RISER) of the way, the riser the rest.
	var bench := 1.0 - CLIFF_RISER
	var g: float
	if f < bench:
		g = f / bench * (1.0 - CLIFF_RISE)
	else:
		g = (1.0 - CLIFF_RISE) + (f - bench) / CLIFF_RISER * CLIFF_RISE
	var stepped: float = (floorf(k) + g) * CLIFF_STEP_M
	return lerpf(h, stepped, m)


func _hotspot_height(dir: Vector3) -> float:
	var total := 0.0
	for i in hotspot_dirs.size():
		var cos_angle := dir.dot(hotspot_dirs[i])
		# Cheap reject: only points within ~0.12 rad can be inside a cone.
		if cos_angle < 0.99:
			continue
		var dist := CubeSphere.geo_distance_m(dir, hotspot_dirs[i])
		var r := hotspot_radii[i]
		if dist >= r:
			continue
		var t := 1.0 - dist / r
		var cone := hotspot_heights[i] * pow(t, 1.6)
		# Crater: a bowl in the top 10% of the radius.
		var crater_r := r * 0.1
		if dist < crater_r:
			cone -= hotspot_heights[i] * 0.12 * (1.0 - dist / crater_r)
		total += cone
	return total


## Unit direction of the nearest hotspot and its distance in geographic
## meters (like its radius; CubeSphere.geo_distance_m).
func nearest_hotspot(dir: Vector3) -> Dictionary:
	var best := -1
	var best_dot := -2.0
	for i in hotspot_dirs.size():
		var d := dir.dot(hotspot_dirs[i])
		if d > best_dot:
			best_dot = d
			best = i
	return {
		"index": best,
		"distance_m": CubeSphere.geo_distance_m(dir, hotspot_dirs[best]),
		"radius_m": hotspot_radii[best],
	}
