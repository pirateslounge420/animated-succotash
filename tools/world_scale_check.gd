extends SceneTree
## The world at 1/100 Earth, measured (design 3 Oct §CR; data/world_scale.json).
## For each seed, generates the full planet and prints, headless:
##   - the planet's size and the horizon from eye height (and how far a 30 m
##     tower, a 100 m hill and the highest summit show over the curve);
##   - slopes: the share of land steeper than 35°, 45° and 60°, measured on
##     the walking ground (TerrainField.elevation with its detail, across
##     SLOPE_STEP_M, the fine ground quad) at random land points; and the
##     same on mountain flanks (ground over FLANK_M);
##   - the ranges: high ground over RANGE_M joined cell to cell, each one's
##     summit (refined on the ground), and whether the summit has a way up
##     from its foot (FOOT_SHARE of its height) averaging under
##     route_mean_deg and never steeper than route_max_deg: the gentlest
##     route by its steepest step (a bottleneck search on a ROUTE_STEP_M
##     grid of the walking ground), its mean grade and length, and the
##     climb time by Tobler's pace (world_scale.json pace); the great ones
##     (summit at least summit_m_earth[0] x height_scale) counted;
##   - each biome's share of the land, its places (regions joined cell to
##     cell) and the biomes with fewer than floor_places places.
## Report lines start "[scale]"; the gate lines (PASS/FAIL) check what §CR
## locks once the ranges are built: 4-7 great ranges, every great summit
## with a route, cliffs on about cliff_share of the flanks.
##
##   ~/bin/godot --headless --path . --script tools/world_scale_check.gd
## SEEDS="42,7,1234,7731" (default), ROUTES=0 skips the route search,
## GATES=1 makes the gate lines count (exit 1 on a FAIL).

const SLOPE_STEP_M := 4.0
const FLANK_M := 150.0
const RANGE_M := 250.0
const FOOT_SHARE := 0.4
const ROUTE_STEP_M := 40.0
const ROUTE_RADIUS_M := 16000.0

var world: Node
var WS: Dictionary = Tuning.table("world_scale")
var fails := 0


func _initialize() -> void:
	world = get_root().get_node("World")
	_run.call_deferred()


func gate(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond and OS.get_environment("GATES") == "1":
		fails += 1


func _run() -> void:
	world._load_dev_settings()
	var seeds := (OS.get_environment("SEEDS") if OS.get_environment("SEEDS") != "" else "42,7,1234,7731").split(",")
	world.use_postage_stamp(OS.get_environment("STAMP") == "1")
	var mt: Dictionary = WS.get("mountains", {})
	var hs := float((WS.get("heights", {}) as Dictionary).get("height_scale", PlanetConst.HEIGHT_SCALE))
	var great_m := float((mt.get("summit_m_earth", [5000, 8850]) as Array)[0]) * hs
	var eye := PlanetPlayer.EYE_Y
	var r := PlanetConst.RADIUS_M
	print("[scale] planet %.0f km around (radius %.1f km), GEO_SCALE %.2f, heights x%.2f" % [PlanetConst.CIRCUMFERENCE_M / 1000.0, r / 1000.0, PlanetConst.GEO_SCALE, PlanetConst.HEIGHT_SCALE])
	print("[scale] horizon from eye height (%.2f m): %.0f m; a 30 m tower shows from %.1f km, a 100 m hill from %.1f km; the ground drops %.1f m over 1 km" % [
		eye, _horizon(eye), (_horizon(eye) + _horizon(30.0)) / 1000.0, (_horizon(eye) + _horizon(100.0)) / 1000.0, r - r * cos(1000.0 / r)])
	for s in seeds:
		var t0 := Time.get_ticks_msec()
		world.generate_now(int(s))
		var map: PlanetData = world.planet
		print("\n[scale] seed %s: %d cells of %.2f km, generated in %d ms" % [s, map.cell_count, map.cell_m() / 1000.0, Time.get_ticks_msec() - t0])
		_slopes(map, int(s))
		var ranges := _ranges(map)
		var top := 0.0
		for rg in ranges:
			top = maxf(top, float(rg.summit_m))
		var gres := _great(map, great_m)
		var great := int(gres.n)
		var routed := int(gres.routed)
		top = maxf(top, float(gres.top))
		print("[scale] seed %s: highest summit %.0f m; %d great ranges, %d of them with a way up; other summits of %.0f m or more: %d" % [s, top, great, routed, great_m, int(gres.others)])
		print("[scale] seed %s: from the highest summit (%.0f m) you see %.1f km; it shows from %.1f km away" % [s, top, _horizon(top + eye) / 1000.0, (_horizon(top) + _horizon(eye)) / 1000.0])
		var gr: Array = mt.get("great_ranges", [4, 7])
		gate(great >= int(gr[0]) and great <= int(gr[1]), "seed %s: %d great ranges (want %d-%d)" % [s, great, int(gr[0]), int(gr[1])])
		gate(great > 0 and routed == great, "seed %s: every great summit has a way up (%d of %d)" % [s, routed, great])
		_biomes(map, int(s))
	print("\nRESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _horizon(h: float) -> float:
	var r := PlanetConst.RADIUS_M
	return sqrt(2.0 * r * h + h * h)


# --- Slopes -------------------------------------------------------------------

func _slope_deg(t: TerrainField, d: Vector3, step: float) -> float:
	var n := CubeSphere.north(d)
	var e := CubeSphere.east(d)
	var r := PlanetConst.RADIUS_M
	var a := step / r
	var hx := t.elevation((d + e * a).normalized(), true) - t.elevation((d - e * a).normalized(), true)
	var hy := t.elevation((d + n * a).normalized(), true) - t.elevation((d - n * a).normalized(), true)
	return rad_to_deg(atan(Vector2(hx, hy).length() / (2.0 * step)))


func _slopes(map: PlanetData, sd: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd * 31 + 7
	var t := map.terrain
	var land := 0
	var over := [0, 0, 0]
	var flank := 0
	var f_over := [0, 0, 0]
	var lim := [35.0, 45.0, 60.0]
	var mt: Dictionary = WS.get("mountains", {})
	var cliff_deg := float(mt.get("cliff_min_deg", 60.0))
	var f_cliff := 0
	var tries := 0
	while land < 12000 and tries < 60000:
		tries += 1
		var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var c := map.cell_at(d)
		if map.water[c] == PlanetData.Water.OCEAN or map.water[c] == PlanetData.Water.LAKE:
			continue
		var h := t.elevation(d, true)
		if h <= 0.5:
			continue
		var sl := _slope_deg(t, d, SLOPE_STEP_M)
		land += 1
		for k in 3:
			if sl > lim[k]:
				over[k] += 1
		if t.elevation(d, false) > FLANK_M:
			flank += 1
			for k in 3:
				if sl > lim[k]:
					f_over[k] += 1
			if sl >= cliff_deg:
				f_cliff += 1
	print("[scale] seed %d slopes (walking ground, %.0f m steps, %d land points): steeper than 35° %.2f%%, 45° %.2f%%, 60° %.2f%%" % [
		sd, SLOPE_STEP_M, land, 100.0 * over[0] / maxf(land, 1), 100.0 * over[1] / maxf(land, 1), 100.0 * over[2] / maxf(land, 1)])
	print("[scale] seed %d mountain flanks (ground over %.0f m, %d points, %.1f%% of land): steeper than 35° %.2f%%, 45° %.2f%%, 60° %.2f%%" % [
		sd, FLANK_M, flank, 100.0 * flank / maxf(land, 1), 100.0 * f_over[0] / maxf(flank, 1), 100.0 * f_over[1] / maxf(flank, 1), 100.0 * f_over[2] / maxf(flank, 1)])


# --- Ranges and routes --------------------------------------------------------

func _ranges(map: PlanetData) -> Array:
	var seen := PackedByteArray()
	seen.resize(map.cell_count)
	var out: Array = []
	for c in map.cell_count:
		if seen[c] == 1 or map.elevation[c] < RANGE_M:
			continue
		var cells := PackedInt32Array()
		var stack := PackedInt32Array([c])
		seen[c] = 1
		var best := c
		while not stack.is_empty():
			var x := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			cells.append(x)
			if map.elevation[x] > map.elevation[best]:
				best = x
			for k in 8:
				var nb := map.neighbor(x, k)
				if nb >= 0 and seen[nb] == 0 and map.elevation[nb] >= RANGE_M:
					seen[nb] = 1
					stack.append(nb)
		var km2 := cells.size() * pow(map.cell_m() / 1000.0, 2.0)
		var top := _summit(map.terrain, map.dir[best], map.cell_m())
		out.append({"cells": cells.size(), "km2": km2, "summit": top, "summit_m": map.terrain.elevation(top, true)})
	out.sort_custom(func(a, b): return float(a.summit_m) > float(b.summit_m))
	var mt: Dictionary = WS.get("mountains", {})
	var hs := float((WS.get("heights", {}) as Dictionary).get("height_scale", PlanetConst.HEIGHT_SCALE))
	var great_m := float((mt.get("summit_m_earth", [5000, 8850]) as Array)[0]) * hs
	var i := 0
	for rg in out:
		i += 1
		var line := "[scale]   range %d: %.0f km2, summit %.0f m" % [i, float(rg.km2), float(rg.summit_m)]
		if OS.get_environment("ROUTES") == "all" and i <= 8:
			var rt := _route(map.terrain, rg.summit, float(rg.summit_m), float(rg.summit_m) * FOOT_SHARE)
			rg.merge(rt)
			if rt.has("max_deg"):
				line += "; the quickest way up from %.0f m: steepest step %.1f°, mean %.1f°, %.1f km, %.0f real min (%.1f game h) at Tobler's pace -> %s" % [
					float(rt.foot_m), float(rt.max_deg), float(rt.mean_deg), float(rt.len_m) / 1000.0, float(rt.real_min), float(rt.real_min) / 6.0, "a way up" if rt.route_ok else "no way up"]
			else:
				line += "; no route found within %.0f km" % (ROUTE_RADIUS_M / 1000.0)
		if i <= 12 or float(rg.summit_m) >= great_m:
			print(line)
	print("[scale] %d high areas over %.0f m (the great ranges among them)" % [out.size(), RANGE_M])
	return out


## The great ranges (TerrainField.great_ranges, §CR.4): each one's summit
## on the walking ground, its share of the land, its way up, and the sheer
## faces on its flanks.
func _great(map: PlanetData, great_m: float) -> Dictionary:
	var t := map.terrain
	var routed := 0
	var top := 0.0
	var mt: Dictionary = WS.get("mountains", {})
	var cliff_deg := float(mt.get("cliff_min_deg", 60.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var flank := 0
	var sheer := 0
	var steep45 := 0
	var fl_sum := 0.0
	var i := 0
	for g in t.great_ranges:
		i += 1
		var sd: Vector3 = g.summit
		var sm := t.elevation(sd, true)
		top = maxf(top, sm)
		var line := "[scale]   great range %d: %.0f km long, summit %.0f m (%.0f m Earth)" % [i, float(g.half_len_m) * 2.0 / 1000.0, sm, sm / PlanetConst.HEIGHT_SCALE]
		if OS.get_environment("ROUTES") != "0":
			var rt := _route(t, sd, sm, sm - float(g.summit_m) * 0.8)
			if rt.has("max_deg"):
				line += "; the quickest way up from %.0f m: steepest step %.1f°, mean %.1f°, %.1f km, %.0f real min (%.1f game h) at Tobler's pace -> %s" % [
					float(rt.foot_m), float(rt.max_deg), float(rt.mean_deg), float(rt.len_m) / 1000.0, float(rt.real_min), float(rt.real_min) / 6.0, "a way up" if rt.route_ok else "no way up"]
				if rt.route_ok:
					routed += 1
			else:
				line += "; no route found within %.0f km" % (ROUTE_RADIUS_M / 1000.0)
		print(line)
		# Its flanks: random points over it where the range stands 15 m or
		# more above what is under it.
		var hl := float(g.half_len_m)
		var hw := float(g.summit_m) / tan(deg_to_rad(TerrainField.FLANK_DEG))
		var n := 0
		while n < 1500:
			var a := rng.randf_range(-1.0, 1.0) * hl
			var b := rng.randf_range(-1.0, 1.0) * hw
			var d: Vector3 = (g.center + (g.axis * a + g.side * b) / PlanetConst.GEO_RADIUS_M).normalized()
			n += 1
			if t._ranges_height(d, false) < 15.0:
				continue
			flank += 1
			var sl := _slope_deg(t, d, SLOPE_STEP_M)
			if sl >= cliff_deg:
				sheer += 1
			if sl > 45.0:
				steep45 += 1
			fl_sum += sl
	# The ranges' share of the land.
	var land := 0
	var under := 0
	for c in map.cell_count:
		if map.water[c] == PlanetData.Water.OCEAN or map.water[c] == PlanetData.Water.LAKE:
			continue
		land += 1
		if t._ranges_height(map.dir[c], false) >= 15.0:
			under += 1
	print("[scale] the great ranges cover %.1f%% of the land; their flanks average %.1f°; %.1f%% is sheer (%.0f° or more) and %.1f%% steeper than 45° (%d points)" % [100.0 * under / maxf(land, 1), fl_sum / maxf(flank, 1), 100.0 * sheer / maxf(flank, 1), cliff_deg, 100.0 * steep45 / maxf(flank, 1), flank])
	if flank > 0:
		var want := float(mt.get("cliff_share", 0.15))
		gate(absf(float(sheer) / flank - want) <= want * 0.4, "sheer faces on %.1f%% of the great ranges' flanks (want about %.0f%%)" % [100.0 * sheer / flank, want * 100.0])
	# Summits of the great ranges' height elsewhere (the ordinary belts and
	# the volcanoes should stay below them).
	var others := 0
	for c in map.cell_count:
		if map.elevation[c] >= great_m and t._ranges_height(map.dir[c], false) < 15.0:
			others += 1
	return {"n": t.great_ranges.size(), "routed": routed, "top": top, "others": others}


## Climb to the top: hill-climb the ground from a cell's centre.
func _summit(t: TerrainField, d: Vector3, cell_m: float) -> Vector3:
	var step := cell_m * 0.5
	var best := d
	var bh := t.elevation(d, false)
	while step > 10.0:
		var moved := false
		for k in 8:
			var cand := CreatureSpawner._offset(best, k * TAU / 8.0, step)
			var h := t.elevation(cand, false)
			if h > bh:
				bh = h
				best = cand
				moved = true
		if not moved:
			step *= 0.5
	return best


## The quickest way up to `top` from its foot (any ground at `foot` m or
## lower), as a walker finds it: Dijkstra over a ROUTE_STEP_M grid of the
## walking ground, each step's time by Tobler's pace for its grade (going
## up), no step steeper than route_max_deg. Returns max_deg (its steepest
## step), mean_deg (the climb over the route's length), len_m, foot_m,
## real_min, route_ok (mean under route_mean_deg).
func _route(t: TerrainField, top: Vector3, top_m: float, foot: float) -> Dictionary:
	var g := ROUTE_STEP_M
	var n_half := int(ROUTE_RADIUS_M / g)
	var w := 2 * n_half + 1
	var nth := CubeSphere.north(top)
	var est := CubeSphere.east(top)
	var r := PlanetConst.RADIUS_M
	var mt: Dictionary = WS.get("mountains", {})
	var max_ok := tan(deg_to_rad(float(mt.get("route_max_deg", 35.0))))
	var pace: Dictionary = (WS.get("pace", {}) as Dictionary).get("tobler", {})
	var a := float(pace.get("a", 3.5))
	var bb := float(pace.get("b", 0.05))
	var cap := float(pace.get("max_factor", 1.0))
	var walk := float((WS.get("pace", {}) as Dictionary).get("flat_walk_mps", 4.3))
	var elev := {}
	var cost := {}
	var prev := {}
	var heap: Array = [] # [seconds, 0, idx]
	var start := n_half * w + n_half
	cost[start] = 0.0
	elev[start] = t.elevation(top, true)
	heap.append([0.0, 0.0, start])
	var goal := -1
	var visited := {}
	var dirs := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]
	while not heap.is_empty():
		var cur: Array = _pop(heap)
		var idx: int = cur[2]
		if visited.has(idx):
			continue
		visited[idx] = true
		if float(elev[idx]) <= foot:
			goal = idx
			break
		var ci := idx % w
		var cj := idx / w
		for dv in dirs:
			var ni: int = ci + dv[0]
			var nj: int = cj + dv[1]
			if ni < 0 or nj < 0 or ni >= w or nj >= w:
				continue
			var nidx := nj * w + ni
			if visited.has(nidx):
				continue
			if not elev.has(nidx):
				var dd := (top + (est * (ni - n_half) + nth * (nj - n_half)) * g / r).normalized()
				elev[nidx] = t.elevation(dd, true)
			var run := g * (1.41421356 if dv[0] != 0 and dv[1] != 0 else 1.0)
			# Walking up: from nidx (lower down the search) to idx.
			var s := (float(elev[idx]) - float(elev[nidx])) / run
			if absf(s) > max_ok:
				continue
			var f := minf(cap, exp(-a * absf(s + bb)) / exp(-a * bb))
			var secs := float(cur[0]) + run / (walk * maxf(f, 0.01))
			if not cost.has(nidx) or secs < float(cost[nidx]) - 1e-3:
				cost[nidx] = secs
				prev[nidx] = idx
				_push(heap, [secs, 0.0, nidx])
	if goal < 0:
		return {}
	var length := 0.0
	var steepest := 0.0
	var idx2 := goal
	while prev.has(idx2):
		var p: int = prev[idx2]
		var dx := absi(p % w - idx2 % w)
		var dy := absi(p / w - idx2 / w)
		var run2 := g * (1.41421356 if dx + dy == 2 else 1.0)
		steepest = maxf(steepest, rad_to_deg(atan(absf(float(elev[p]) - float(elev[idx2])) / run2)))
		length += run2
		idx2 = p
	var mean := rad_to_deg(atan((float(elev[start]) - float(elev[goal])) / maxf(length, 1.0)))
	return {"max_deg": steepest, "mean_deg": mean, "len_m": length, "foot_m": float(elev[goal]), "real_min": float(cost[goal]) / 60.0,
		"route_ok": steepest <= float(mt.get("route_max_deg", 35.0)) + 0.01 and mean <= float(mt.get("route_mean_deg", 22.0))}


func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if _less(heap[i], heap[p]):
			var tmp = heap[i]
			heap[i] = heap[p]
			heap[p] = tmp
			i = p
		else:
			break


func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		var n := heap.size()
		while true:
			var l := 2 * i + 1
			var rr := l + 1
			var m := i
			if l < n and _less(heap[l], heap[m]):
				m = l
			if rr < n and _less(heap[rr], heap[m]):
				m = rr
			if m == i:
				break
			var tmp = heap[i]
			heap[i] = heap[m]
			heap[m] = tmp
			i = m
	return top


func _less(x: Array, y: Array) -> bool:
	if float(x[0]) != float(y[0]):
		return float(x[0]) < float(y[0])
	return float(x[1]) < float(y[1])


# --- Biomes -------------------------------------------------------------------

func _biomes(map: PlanetData, sd: int) -> void:
	var bs: Dictionary = WS.get("biome_shares", {})
	var floor_n := int(bs.get("floor_places", 2))
	var floor_km2 := float(bs.get("floor_km2", 1.0))
	var km2 := pow(map.cell_m() / 1000.0, 2.0)
	var land := 0
	var count := {}
	for c in map.cell_count:
		if map.water[c] == PlanetData.Water.OCEAN or map.water[c] == PlanetData.Water.LAKE:
			continue
		land += 1
		count[map.biome[c]] = int(count.get(map.biome[c], 0)) + 1
	var seen := PackedByteArray()
	seen.resize(map.cell_count)
	var places := {}
	var big_places := {}
	for c in map.cell_count:
		if seen[c] == 1 or map.water[c] == PlanetData.Water.OCEAN or map.water[c] == PlanetData.Water.LAKE:
			continue
		var b := map.biome[c]
		var size := 0
		var stack := PackedInt32Array([c])
		seen[c] = 1
		while not stack.is_empty():
			var x := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			size += 1
			for k in 4:
				var nb := map.neighbor(x, k)
				if nb >= 0 and seen[nb] == 0 and map.biome[nb] == b and map.water[nb] != PlanetData.Water.OCEAN and map.water[nb] != PlanetData.Water.LAKE:
					seen[nb] = 1
					stack.append(nb)
		places[b] = int(places.get(b, 0)) + 1
		if size * km2 >= floor_km2:
			big_places[b] = int(big_places.get(b, 0)) + 1
	print("[scale] seed %d land: %.0f km2 (%d cells); biomes by share of land:" % [sd, land * km2, land])
	var ids := count.keys()
	ids.sort_custom(func(a, b): return int(count[a]) > int(count[b]))
	var short: Array[String] = []
	for id in ids:
		var name := BiomeTemplates.KEYS[int(id)] if int(id) < BiomeTemplates.KEYS.size() else str(id)
		print("[scale]   %-26s %5.2f%%  %7.0f km2  %3d places (%d of %.0f km2 or more)" % [name, 100.0 * int(count[id]) / maxf(land, 1), int(count[id]) * km2, int(places.get(id, 0)), int(big_places.get(id, 0)), floor_km2])
		if int(big_places.get(id, 0)) < floor_n:
			short.append(name)
	var absent: Array[String] = []
	for id in BiomeTemplates.KEYS.size():
		if not count.has(id) and not BiomeTemplates.is_ocean(id) and not str(BiomeTemplates.KEYS[id]) in ["LAKE", "RIVER", "FRESHWATER_LAKE"]:
			absent.append(BiomeTemplates.KEYS[id])
	print("[scale] seed %d: %d biomes with fewer than %d places of %.0f km2: %s" % [sd, short.size(), floor_n, floor_km2, ", ".join(short) if not short.is_empty() else "none"])
	if not absent.is_empty():
		print("[scale] seed %d: land biomes not on the planet at all: %s" % [sd, ", ".join(absent)])
