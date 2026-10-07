class_name FittedStone
## Fitted-stone walls (design §EU.2-EU.5; data/masonry.json): a wall's seen
## face cut into irregular polygonal stones that share their edges with no
## mortar, the Inca way (Sacsayhuamán). The face's plane is a Voronoi
## partition: seed points laid in loose courses (presets stone_m, aspect,
## course_bias), relaxed partition.relax_steps times (Lloyd's way), each
## cell clipped to its neighbours' bisectors and to the wall's edge
## (corner_rule stop), so neighbours share their edges exactly. Every wall
## face takes its own seed (TombBuild), so nothing mirrors across a
## corridor. Each cell is one stone of real geometry, never a normal map:
##
##   its foot     the cell inset by half a joint, behind the wall's face,
##                down in the joint, darkened toward the scene's shade
##                (relief.joint_occlusion scene_shade: Prelit.ao_tint, navy,
##                olive on green; §ES.2)
##   its bevel    a rounded edge bevel_m wide rising to the face
##   its face     proud of the wall's face (rolled in proud_m), pillowed: a
##                middle ring higher, the middle highest (pillow_m), the
##                normals bending out from the middle so the torch rounds it
##
## Behind the stones, the joints' back (joint_depth_m behind the face), in
## the joints' shade. Settled (§EU.3): a share of stones moved out or in,
## turned a little in the wall's plane, now and then one dropped from its
## place. Overgrowth only where it would really grow (§EU.4): the place's
## climate (its world's biome; overgrowth.stand_in until §EW places it)
## through vines.json climate (VineCover.climate): moss in the joints and
## on the shaded lower wall, vines from the wall's top and from cracks;
## where it's dry, drifted sand and dust at the foot and in the corners.
## Everything goes into a RuinBuilder's arrays (TombBuild), drawn with the
## ruin material's fitted stone (kind 6: the stone's grain without the
## tile's painted cracks; the joints are real now).
##
## One ruin, one stone (design §EX.1, §EX.3; RuinStyle): every stone's
## colour is the ruin's style's stone (stone.tint, each stone lighter or
## darker by at most stone.spread), never RuinBuilder's palette, and the
## same cutter makes the rest of the kit: a wall face keeps its door frames
## and niches out (holes: each cell crossing one is cut along the hole's
## edges, so the stones round an opening are fitted to it), the floor is
## the cutter laid flat (flags: bigger stones, barely pillowed, the joints
## packed with grit, worn down the middle of a passage), and a ceiling's
## lintel slabs are drawn as its stones (slabs). TombBuild.bare (the
## checks) leaves the joints and feet the stone's own colour.

static var M: Dictionary = Tuning.table("masonry")
## The ruin material's kinds (shaders/ruin.gdshader, UV.x).
const FITTED_M := 6
const DUST_M := 5
## The theme being built (TombBuild sets it): picks the preset (by_theme)
## and the climate.
static var theme := "tomb"
## A preset to use whatever the theme (the checks; "" none).
static var preset_override := ""
static var _climates: Dictionary = {}


## The preset's name for the theme now: its style's walls.preset (§EX.1),
## else masonry.json by_theme (which must agree with it).
static func preset_name() -> String:
	if preset_override != "":
		return preset_override.replace("-", "_")
	var sp := str(RuinStyle.val("walls.preset", "", theme))
	if sp != "":
		return sp.replace("-", "_")
	var by: Dictionary = M.get("by_theme", {})
	return str(by.get(theme, by.get("default", "megalithic"))).replace("-", "_")


static func preset() -> Dictionary:
	var ps: Dictionary = M.get("presets", {})
	return ps.get(preset_name(), ps.get("megalithic", {}))


## relief, with the preset's own relief block over it.
static func relief() -> Dictionary:
	var r: Dictionary = (M.get("relief", {}) as Dictionary).duplicate()
	r.merge(preset().get("relief", {}), true)
	return r


static func overgrowth() -> Dictionary:
	return M.get("overgrowth", {})


## A [min, max] pair or one number, rolled.
static func _roll(v, rng: RandomNumberGenerator) -> float:
	if v is Array:
		return rng.randf_range(float(v[0]), float(v[1]))
	return float(v)


## The climate of theme `th`: {"moisture", "temp_c", "from"}: its world's
## biome (worlds.json worlds[*].theme -> biome -> data/biomes climate, the
## middle of its ranges), else the theme's own biome (crawler.json), else
## overgrowth.stand_in (a theme no world holds yet).
static func climate_of(th: String) -> Dictionary:
	if _climates.has(th):
		return _climates[th]
	var biome := ""
	for w in (_json("res://data/worlds.json").get("worlds", {}) as Dictionary).values():
		if str((w as Dictionary).get("theme", "")) == th:
			biome = str(w.get("biome", ""))
	if biome == "" or biome == "open":
		biome = str((Tuning.table("crawler").get("themes", {}).get(th, {}) as Dictionary).get("biome", ""))
	var out := {}
	if biome != "" and biome != "open":
		var dir := DirAccess.open("res://data/biomes")
		if dir != null:
			for f in dir.get_files():
				if not f.ends_with(".json"):
					continue
				var doc: Dictionary = _json("res://data/biomes/" + f)
				if str(doc.get("key", "")).to_lower() == biome.to_lower() and doc.get("climate") is Dictionary:
					var cl: Dictionary = doc.climate
					var mr: Array = cl.get("moisture", [0.5, 0.5])
					var tr: Array = cl.get("temp_c", [12, 12])
					out = {"moisture": (float(mr[0]) + float(mr[1])) * 0.5, "temp_c": (float(tr[0]) + float(tr[1])) * 0.5, "from": biome}
	if out.is_empty():
		var si: Dictionary = overgrowth().get("stand_in", {})
		out = {"moisture": float(si.get("moisture", 0.58)), "temp_c": float(si.get("temp_c", 14.0)), "from": "stand_in"}
	_climates[th] = out
	return out


## The climate at `pos` (scene) in theme `th`: Vector2(moisture, temp_c).
## The moisture wanders smoothly from place to place and rises each flight
## down (overgrowth.wet), so areas differ on their own.
static func climate_at(th: String, seed_value: int, pos: Vector3) -> Vector2:
	var cl := climate_of(th)
	var w: Dictionary = overgrowth().get("wet", {})
	var sc := maxf(float(w.get("scale_m", 16.0)), 1.0)
	var n := _noise(Vector2(pos.x, pos.z) / sc, seed_value) * 2.0 - 1.0
	var flights := maxf(-pos.y, 0.0) / maxf(float((Tuning.table("crawler").get("kit", {}) as Dictionary).get("stair_drop_m", 2.4)), 0.1)
	var m := clampf(float(cl.moisture) + float(w.get("vary", 0.15)) * n + float(w.get("per_flight", 0.02)) * flights, 0.0, 1.0)
	return Vector2(m, float(cl.temp_c))


static func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


## Smooth value noise 0-1 on a unit lattice.
static func _noise(p: Vector2, s: int) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	var a := _hash(i, s)
	var b := _hash(i + Vector2(1, 0), s)
	var c := _hash(i + Vector2(0, 1), s)
	var d := _hash(i + Vector2(1, 1), s)
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


static func _hash(p: Vector2, s: int) -> float:
	return float(posmod(hash([int(p.x), int(p.y), s]), 100000)) / 100000.0


## Moss share 0-1 for climate `cl` (moisture, temp_c) at shade 0-1
## (vines.json climate through VineCover.climate; overgrowth.density).
static func moss_of(cl: Vector2, shade := 1.0) -> float:
	return float(overgrowth().get("density", 1.0)) * VineCover.climate(cl.x, cl.y, shade)


## Dry (sand drifts) where the moisture is under vines.json climate's
## floor: 0 not dry, up to 1 bone dry.
static func dry_of(cl: Vector2) -> float:
	var m0 := float((VineCover.CLIM.get("moisture", [0.35, 0.85]) as Array)[0])
	if cl.x >= m0:
		return 0.0
	return clampf(1.0 - cl.x / maxf(m0, 0.01), 0.3, 1.0)


## The Voronoi cells of a `length` x `height` wall face (u along, v up from
## 0): [[site, polygon (PackedVector2Array, counter-clockwise)]...]. Seed
## points in loose courses (each course its own height, each stone its own
## width, both from stone_m; course_bias how true the courses run), then
## relax_steps of Lloyd's relaxation. `sizes` overrides the preset's
## stone_m, aspect and course_bias (the floor's flags).
static func cells(length: float, height: float, rng: RandomNumberGenerator, sizes: Dictionary = {}) -> Array:
	var p := preset().duplicate()
	p.merge(sizes, true)
	var sm: Array = p.get("stone_m", [0.9, 2.2])
	var s0 := maxf(float(sm[0]), 0.05)
	var s1 := maxf(float(sm[1]), s0)
	var aspect := maxf(float(p.get("aspect", 1.4)), 0.3)
	var jit := clampf(1.0 - float(p.get("course_bias", 0.3)), 0.0, 1.0)
	# The courses: heights rolled, then fitted to the wall exactly.
	var rows: Array[float] = []
	var tot := 0.0
	while tot < height - 0.01 or rows.is_empty():
		var hh := rng.randf_range(s0, s1) / aspect
		rows.append(hh)
		tot += hh
	var k := height / tot
	var sites := PackedVector2Array()
	var y := 0.0
	for hh in rows:
		var h := hh * k
		var cur := -rng.randf_range(0.0, s1) * 0.7
		while cur < length:
			var w := rng.randf_range(s0, s1)
			var cx := clampf(cur + w * 0.5 + rng.randf_range(-0.5, 0.5) * w * jit * 0.6, 0.02, length - 0.02)
			var cy := clampf(y + h * 0.5 + rng.randf_range(-0.5, 0.5) * h * jit * 0.8, 0.02, height - 0.02)
			sites.append(Vector2(cx, cy))
			cur += w
		y += h
	var out := _voronoi(sites, length, height, s1)
	var part: Dictionary = M.get("partition", {})
	for step in int(part.get("relax_steps", 0)):
		var moved := PackedVector2Array()
		for c in out:
			moved.append(_centroid(c[1]))
		out = _voronoi(moved, length, height, s1)
	return out


## The cells of `sites` on the `length` x `height` rectangle. A site's
## candidates come from a bucket grid; one farther than twice the cell's
## farthest corner can't cut it, so it is skipped.
static func _voronoi(sites: PackedVector2Array, length: float, height: float, size: float) -> Array:
	var bs := maxf(size, 0.1)
	var grid := {}
	for i in sites.size():
		var key := Vector2i(int(sites[i].x / bs), int(sites[i].y / bs))
		if not grid.has(key):
			grid[key] = []
		(grid[key] as Array).append(i)
	var out: Array = []
	for i in sites.size():
		var s := sites[i]
		var poly := PackedVector2Array([Vector2(0, 0), Vector2(length, 0), Vector2(length, height), Vector2(0, height)])
		var rmax := _reach(poly, s)
		var key := Vector2i(int(s.x / bs), int(s.y / bs))
		# Nearest buckets first, so the cell shrinks early and the far
		# candidates are skipped.
		for ring in 3:
			for gy in range(key.y - ring, key.y + ring + 1):
				for gx in range(key.x - ring, key.x + ring + 1):
					if maxi(absi(gx - key.x), absi(gy - key.y)) != ring:
						continue
					var cell = grid.get(Vector2i(gx, gy))
					if cell == null:
						continue
					for j in cell:
						if j == i:
							continue
						var o := sites[j]
						if s.distance_to(o) > 2.0 * rmax:
							continue
						poly = _clip(poly, (s + o) * 0.5, o - s)
						if poly.size() < 3:
							break
						rmax = _reach(poly, s)
		if poly.size() >= 3:
			out.append([s, poly])
	return out


## The farthest corner of `poly` from `s`.
static func _reach(poly: PackedVector2Array, s: Vector2) -> float:
	var r := 0.0
	for q in poly:
		r = maxf(r, s.distance_to(q))
	return r


## Convex polygon `poly` cut to the side of the line through `m` away from
## `toward` (Sutherland-Hodgman, one plane).
static func _clip(poly: PackedVector2Array, m: Vector2, toward: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var da := (a - m).dot(toward)
		var db := (b - m).dot(toward)
		if da <= 0.0:
			out.append(a)
		if (da <= 0.0) != (db <= 0.0):
			out.append(a + (b - a) * (da / (da - db)))
	return out


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var area := 0.0
	var c := Vector2.ZERO
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var cr := a.x * b.y - b.x * a.y
		area += cr
		c += (a + b) * cr
	if absf(area) < 1e-6:
		c = Vector2.ZERO
		for q in poly:
			c += q
		return c / poly.size()
	return c / (3.0 * area)


static func _area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	return absf(area) * 0.5


## The nearest edge from `c` inside `poly`.
static func _inradius(poly: PackedVector2Array, c: Vector2) -> float:
	var r := INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var e := (b - a)
		if e.length() < 1e-5:
			continue
		r = minf(r, absf((c - a).cross(e.normalized())))
	return r


## Dress one wall face with fitted stones. The face's plane: `o` (scene, at
## y 0) + `u` * along + up * y + `n` * out (n: out of the wall, into the
## room); `length` along, stones from y `y0` to `y1`, the floor at
## `floor_y`; `cl` the climate there (moisture, temp_c: climate_at).
## `holes`: openings kept out of it (convex polygons, counter-clockwise, in
## the face's own (along, y - y0)): a door's frame, a niche; `clear`: [from,
## to] stretches along it no vine hangs over and no drift lies in (the
## doorways, the niches). Returns the stones laid; `out` gets the face's
## "cells" (its stones' polygons as laid, cut round the holes: where its
## joints run) and "heights" (each one's face off the wall's face:
## Vector2(rim, pillowed middle)), for the beetles (WallLife).
static func face(b: RuinBuilder, o: Vector3, u: Vector3, n: Vector3, length: float, y0: float, y1: float, floor_y: float, cl: Vector2, rng: RandomNumberGenerator, holes: Array = [], clear: Array = [], out: Dictionary = {}) -> int:
	if length < 0.3 or y1 - y0 < 0.3:
		return 0
	var rl := relief()
	var st: Dictionary = M.get("settle", {})
	var og := overgrowth()
	var joint := float(rl.get("joint_m", 0.012))
	var jd := float(rl.get("joint_depth_m", 0.06))
	var bevel := float(rl.get("bevel_m", 0.05))
	var pillow := float(rl.get("pillow_m", 0.04))
	var shade_joints := str(rl.get("joint_occlusion", "scene_shade")) == "scene_shade"
	var bare := TombBuild.bare
	# Underground is all shade: the joints and the low wall full shade.
	var moss_k := moss_of(cl, 1.0)
	var jmoss := moss_k * float(og.get("joint_moss", 0.9)) if bool(og.get("moss_in_joints", true)) else 0.0
	var low_m := maxf(float(og.get("moss_low_wall_m", 1.2)), 0.1)
	var low_moss := float(og.get("low_moss", 0.65)) * moss_k
	var was_mat := b.mat
	b.mat = FITTED_M
	var fo := o + Vector3.UP * y0
	# The joints' back: behind the stones, in the joints' shade (one sheet,
	# the openings cut out of it where the face has them).
	var back: Color = RuinStyle.joint(0.3, bare) if shade_joints else RuinStyle.tint().darkened(0.5)
	back.a = jmoss
	var inside := o + Vector3.UP * (y0 + y1) * 0.5 - n * 2.0
	var parts: Array = []
	for cell in cells(length, y1 - y0, rng):
		if holes.is_empty():
			parts.append(cell)
		else:
			for piece in cut(cell[1], holes):
				parts.append([cell[0], piece])
	var whole := PackedVector2Array([Vector2(0, 0), Vector2(length, 0), Vector2(length, y1 - y0), Vector2(0, y1 - y0)])
	for poly in ([whole] if holes.is_empty() else cut(whole, holes)):
		_sheet(b, fo, u, Vector3.UP, n, poly, -jd, back, inside + u * length * 0.5)
	var laid := 0
	var share := float(st.get("share", 0.15))
	var offs: Array = st.get("offset_m", [-0.04, 0.06])
	var tilts: Array = st.get("tilt_deg", [0.0, 4.0])
	# Each stone's face off the wall's face: (its rim, its pillowed middle);
	# a sliver left as joint stays down at the joints' back.
	var heights := PackedVector2Array()
	heights.resize(parts.size())
	heights.fill(Vector2(-jd, -jd))
	for ci in parts.size():
		var poly: PackedVector2Array = parts[ci][1]
		if _area(poly) < 0.004:
			continue
		var c := _centroid(poly)
		var r_in := _inradius(poly, c)
		if r_in < joint * 0.5 + 0.01:
			continue
		var proud := _roll(rl.get("proud_m", [0.02, 0.06]), rng)
		# Settled: out or in, a slight turn; now and then one dropped.
		var off := 0.0
		var rot := 0.0
		var sink := 0.0
		if rng.randf() < share:
			off = rng.randf_range(float(offs[0]), float(offs[1]))
			rot = deg_to_rad(rng.randf_range(float(tilts[0]), float(tilts[1]))) * (1.0 if rng.randf() < 0.5 else -1.0)
		if rng.randf() < float(st.get("dropped_share", 0.02)):
			sink = float(st.get("dropped_m", 0.05))
			rot = deg_to_rad(float(tilts[1])) * 2.0 * (1.0 if rng.randf() < 0.5 else -1.0)
		heights[ci] = Vector2(proud + off, proud + off + pillow)
		# The style's one stone (§EX.1), each stone its own shade of it.
		var col := RuinStyle.stone(rng)
		var patch := rng.randf_range(0.5, 1.3)
		var foot_col: Color = col if bare else (Prelit.ao_tint(col, 0.55) if shade_joints else col.darkened(0.3))
		foot_col.a = jmoss * 0.85
		stone(b, fo, u, Vector3.UP, n, poly, col, foot_col, proud, pillow, bevel, joint, jd, off, rot, Vector2(0, sink), Vector3(floor_y, low_m, low_moss * patch))
		laid += 1
	b.mat = was_mat
	out["cells"] = parts
	out["heights"] = heights
	# Vines grow up the wall into half shade.
	_vines(b, o, u, n, length, y0, y1, moss_of(cl, 0.5), float((rl.get("proud_m", [0.02, 0.06]) as Array)[1]) + pillow, rng, clear)
	_dust(b, o, u, n, length, floor_y, dry_of(cl), rng, clear)
	return laid


## One stone of a fitted face: `poly` (counter-clockwise) in the face's
## plane fo + u * x + v * y, `n` out of the face. Its foot down in the
## joint (`foot_col`), its bevel rising to the face, its face `proud` out
## and pillowed by `pillow` (a middle ring higher, the middle highest, the
## normals bending out from the middle so the torch rounds it); moved `off`
## out (or in), turned `rot` in the plane, shifted `shift` (a dropped
## stone). Moss in its alpha: the lower wall's (`low`: the floor's y, how
## high it climbs, how much; walls only, v up) or `low.z` < 0 for none
## (the foot keeps its own alpha). `rings` false: the face one fan to its
## middle (a flag's, all but flat).
static func stone(b: RuinBuilder, fo: Vector3, u: Vector3, v: Vector3, n: Vector3, poly: PackedVector2Array, col: Color, foot_col: Color, proud: float, pillow: float, bevel: float, joint: float, jd: float, off: float, rot: float, shift: Vector2, low: Vector3, rings := true) -> void:
	var c := _centroid(poly)
	var r_in := _inradius(poly, c)
	var cs := c - shift
	var s0 := maxf(0.2, 1.0 - joint * 0.5 / r_in)
	var s1 := maxf(0.12, 1.0 - (joint * 0.5 + bevel) / r_in)
	# A small stone's face needs no middle ring (nor a flag's, barely pillowed).
	var ring := rings and r_in > 0.12
	var nv := poly.size()
	var r0: Array[Vector3] = []
	var r1: Array[Vector3] = []
	var rm: Array[Vector3] = []
	var n0: Array[Vector3] = []
	var n1: Array[Vector3] = []
	var nm: Array[Vector3] = []
	var c1: Array[Color] = []
	var cm: Array[Color] = []
	var mossy := low.z >= 0.0
	var flat := col
	flat.a = 0.0
	for k in nv:
		var d := (poly[k] - c).rotated(rot)
		var radial := (u * d.x + v * d.y).normalized()
		var p0 := cs + d * s0
		var p1 := cs + d * s1
		var pm := cs + d * s1 * 0.55
		r0.append(fo + u * p0.x + v * p0.y + n * (-jd * 0.45 + off))
		r1.append(fo + u * p1.x + v * p1.y + n * (proud + off))
		rm.append(fo + u * pm.x + v * pm.y + n * (proud + pillow * 0.72 + off))
		n0.append((n * 0.35 + radial).normalized())
		n1.append((n + radial * 0.6).normalized())
		nm.append((n + radial * 0.28).normalized())
		c1.append(_mossy(col, (r1[k] as Vector3).y - low.x, low.y, low.z) if mossy else flat)
		cm.append(_mossy(col, (rm[k] as Vector3).y - low.x, low.y, low.z) if mossy else flat)
	var top: Vector3 = fo + u * cs.x + v * cs.y + n * (proud + pillow + off)
	var ct := _mossy(col, top.y - low.x, low.y, low.z) if mossy else flat
	var behind := top - n * 1.0
	for k in nv:
		var k2 := (k + 1) % nv
		# The bevel, from the joint up to the face.
		b._tri_n(r0[k], r0[k2], r1[k2], n0[k], n0[k2], n1[k2], foot_col, foot_col, c1[k2], behind)
		b._tri_n(r0[k], r1[k2], r1[k], n0[k], n1[k2], n1[k], foot_col, c1[k2], c1[k], behind)
		if ring:
			# The face's outer ring and its pillowed middle.
			b._tri_n(r1[k], r1[k2], rm[k2], n1[k], n1[k2], nm[k2], c1[k], c1[k2], cm[k2], behind)
			b._tri_n(r1[k], rm[k2], rm[k], n1[k], nm[k2], nm[k], c1[k], cm[k2], cm[k], behind)
			b._tri_n(rm[k], rm[k2], top, nm[k], nm[k2], n, cm[k], cm[k2], ct, behind)
		else:
			b._tri_n(r1[k], r1[k2], top, n1[k], n1[k2], n, c1[k], c1[k2], ct, behind)


## A flat sheet over `poly` (the face's plane fo + u * x + v * y), `w` out
## along `n` (negative: behind the face): a stone's own joint back.
static func _sheet(b: RuinBuilder, fo: Vector3, u: Vector3, v: Vector3, n: Vector3, poly: PackedVector2Array, w: float, col: Color, inside: Vector3) -> void:
	var p0 := fo + u * poly[0].x + v * poly[0].y + n * w
	for i in range(1, poly.size() - 1):
		var p1 := fo + u * poly[i].x + v * poly[i].y + n * w
		var p2 := fo + u * poly[i + 1].x + v * poly[i + 1].y + n * w
		b._tri_n(p0, p1, p2, n, n, n, col, col, col, inside)


## Convex polygon `poly` less the convex `holes` (each counter-clockwise):
## convex pieces that tile what is left. Each hole's edges cut the
## polygon in turn: what lies outside an edge is a piece, the rest goes on
## to the next edge, and what is left after the last lies in the hole.
static func cut(poly: PackedVector2Array, holes: Array) -> Array:
	var parts: Array = [poly]
	for h in holes:
		var hole: PackedVector2Array = h
		var hb := _bounds(hole)
		var next: Array = []
		for part: PackedVector2Array in parts:
			var pb := _bounds(part)
			if pb.position.x >= hb.end.x or hb.position.x >= pb.end.x or pb.position.y >= hb.end.y or hb.position.y >= pb.end.y:
				next.append(part)
				continue
			var rest := part
			var nh := hole.size()
			for i in nh:
				var a := hole[i]
				var e := hole[(i + 1) % nh] - a
				var out := Vector2(e.y, -e.x)
				var piece := _clip(rest, a, -out)
				if piece.size() >= 3 and _area(piece) > 1e-6:
					next.append(piece)
				rest = _clip(rest, a, out)
				if rest.size() < 3:
					break
		parts = next
	return parts


## `poly` turned counter-clockwise if it isn't.
static func ccw(poly: PackedVector2Array) -> PackedVector2Array:
	var s := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	if s >= 0.0:
		return poly
	var out := PackedVector2Array()
	for i in range(poly.size() - 1, -1, -1):
		out.append(poly[i])
	return out


static func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		r = r.expand(q)
	return r


## A floor of fitted flags (design §EX.3 floor fitted_flags): the walls'
## cutter laid flat over `length` x `width` (the plane fo + u * x + v * y,
## up out of it), stones floor.stone_scale times the wall preset's, their
## pillow and proud times pillow_scale, the joints packed with grit to
## joint_fill of their depth (one sheet of grit, in the scene's shade), and
## worn: `wear` (a Callable of the flag's middle, x and y: 0-1, the middle
## of a passage where feet went) flattens a flag and takes its stone a
## little toward the light end of the spread (floor.wear amount, lighten).
## Settled like the walls, a little: a share sit a little high or low, or
## turned. Returns the flags laid.
static func flags(b: RuinBuilder, fo: Vector3, u: Vector3, v: Vector3, length: float, width: float, cl: Vector2, rng: RandomNumberGenerator, wear: Callable) -> int:
	if length < 0.3 or width < 0.3:
		return 0
	var fl: Dictionary = RuinStyle.val("floor", {}, theme)
	var p := preset()
	var rl := relief()
	var st: Dictionary = M.get("settle", {})
	var og := overgrowth()
	var bare := TombBuild.bare
	var k := maxf(float(fl.get("stone_scale", 2.0)), 0.2)
	var sm: Array = p.get("stone_m", [0.25, 0.6])
	var sizes := {"stone_m": [float(sm[0]) * k, float(sm[1]) * k]}
	var ps := clampf(float(fl.get("pillow_scale", 0.25)), 0.0, 1.0)
	var fill := clampf(float(fl.get("joint_fill", 0.7)), 0.0, 0.95)
	var wr: Dictionary = fl.get("wear", {})
	var amount := clampf(float(wr.get("amount", 0.6)), 0.0, 1.0)
	var lighten := clampf(float(wr.get("lighten", 0.6)), 0.0, 1.0)
	var joint := float(rl.get("joint_m", 0.012))
	var jd := float(rl.get("joint_depth_m", 0.06))
	var bevel := float(rl.get("bevel_m", 0.05))
	var pillow := float(rl.get("pillow_m", 0.04)) * ps
	var jmoss := moss_of(cl, 1.0) * float(og.get("joint_moss", 0.9)) if bool(og.get("moss_in_joints", true)) else 0.0
	var was_mat := b.mat
	b.mat = FITTED_M
	var n := Vector3.UP
	# The grit, packed into the joints up to joint_fill of their depth.
	var grit: Color = RuinStyle.joint(0.45, bare)
	grit.a = jmoss * 0.5
	var inside := fo - n * 1.0 + (u * length + v * width) * 0.5
	_sheet(b, fo, u, v, n, PackedVector2Array([Vector2(0, 0), Vector2(length, 0), Vector2(length, width), Vector2(0, width)]), -jd * (1.0 - fill), grit, inside)
	var share := float(st.get("share", 0.15))
	var offs: Array = st.get("offset_m", [-0.04, 0.06])
	var tilts: Array = st.get("tilt_deg", [0.0, 4.0])
	var laid := 0
	for cell in cells(length, width, rng, sizes):
		var poly: PackedVector2Array = cell[1]
		if _area(poly) < 0.004:
			continue
		var c := _centroid(poly)
		var r_in := _inradius(poly, c)
		if r_in < joint * 0.5 + 0.01:
			continue
		var w := clampf(float(wear.call(c.x, c.y)), 0.0, 1.0) * amount
		var proud := _roll(rl.get("proud_m", [0.02, 0.06]), rng) * ps * (1.0 - w)
		var off := 0.0
		var rot := 0.0
		if rng.randf() < share:
			off = rng.randf_range(float(offs[0]), float(offs[1])) * ps
			rot = deg_to_rad(rng.randf_range(float(tilts[0]), float(tilts[1]))) * (1.0 if rng.randf() < 0.5 else -1.0)
		if rng.randf() < float(st.get("dropped_share", 0.02)):
			off -= float(st.get("dropped_m", 0.05)) * ps
		var col := RuinStyle.worn(RuinStyle.stone(rng), w * lighten)
		var foot_col: Color = col if bare else Prelit.ao_tint(col, 0.55)
		foot_col.a = jmoss * 0.85 * (1.0 - w)
		stone(b, fo, u, v, n, poly, col, foot_col, proud, pillow * (1.0 - w), bevel, joint, jd, off, rot, Vector2.ZERO, Vector3(0, 0, -1), false)
		laid += 1
	b.mat = was_mat
	return laid


## A ceiling of lintel slabs (design §EX.3 ceiling lintel_slabs): each of
## `slab_cells` (convex, counter-clockwise, in the plane fo + u * x + v * y,
## `n` down out of it) one stone of the style, cut round `holes` (the vents'
## mouths), with the walls' bevel and a little pillow, settled like the
## walls (a share hang a little low, or sit turned a degree or two). Behind
## them, over `backs` (Rect2s in the same plane), the joints' back.
## Returns the slabs laid.
static func slabs(b: RuinBuilder, fo: Vector3, u: Vector3, v: Vector3, n: Vector3, slab_cells: Array, rng: RandomNumberGenerator, holes: Array, backs: Array) -> int:
	var rl := relief()
	var st: Dictionary = M.get("settle", {})
	var bare := TombBuild.bare
	var joint := float(rl.get("joint_m", 0.012))
	var jd := float(rl.get("joint_depth_m", 0.06))
	var bevel := float(rl.get("bevel_m", 0.05)) * 1.2
	var pillow := float(rl.get("pillow_m", 0.04)) * 0.5
	var was_mat := b.mat
	b.mat = FITTED_M
	var back: Color = RuinStyle.joint(0.3, bare)
	back.a = 0.0
	var inside := fo - n * 2.0
	for r: Rect2 in backs:
		_sheet(b, fo, u, v, n, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), -jd, back, inside)
	var share := float(st.get("share", 0.15))
	var offs: Array = st.get("offset_m", [-0.04, 0.06])
	var tilts: Array = st.get("tilt_deg", [0.0, 4.0])
	var laid := 0
	for cell: PackedVector2Array in slab_cells:
		var col := RuinStyle.stone(rng)
		var proud := _roll(rl.get("proud_m", [0.02, 0.06]), rng) * 0.6
		var off := 0.0
		var rot := 0.0
		if rng.randf() < share:
			off = rng.randf_range(0.0, maxf(float(offs[1]), 0.0))
			rot = deg_to_rad(rng.randf_range(float(tilts[0]), float(tilts[1]))) * 0.4 * (1.0 if rng.randf() < 0.5 else -1.0)
		var foot_col: Color = col if bare else Prelit.ao_tint(col, 0.55)
		foot_col.a = 0.0
		for poly: PackedVector2Array in (cut(cell, holes) if not holes.is_empty() else [cell]):
			if _area(poly) < 0.004:
				continue
			var r_in := _inradius(poly, _centroid(poly))
			if r_in < joint * 0.5 + 0.01:
				continue
			stone(b, fo, u, v, n, poly, col, foot_col, proud, pillow, minf(bevel, r_in * 0.4), joint, jd, off, rot, Vector2.ZERO, Vector3(0, 0, -1))
		laid += 1
	b.mat = was_mat
	return laid


## A stone's colour with the lower wall's moss in its alpha (the ruin
## shader's moss), fading up the wall.
static func _mossy(col: Color, above_floor: float, low_m: float, amount: float) -> Color:
	var c := col
	c.a = clampf(amount * (1.0 - smoothstep(0.0, low_m, above_floor)), 0.0, 1.0)
	return c


## Vines (where the climate allows, `moss_k`): from the wall's top under the
## ceiling, and from cracks in its upper half, hanging down; none over the
## `clear` stretches (the doorways, the niches). Generic ivy until a world
## gives its biome's own vine species (vines.json, §CS).
static func _vines(b: RuinBuilder, o: Vector3, u: Vector3, n: Vector3, length: float, y0: float, y1: float, moss_k: float, out_m: float, rng: RandomNumberGenerator, clear: Array = []) -> void:
	if moss_k < 0.05:
		return
	var og := overgrowth()
	var count := int(floor(length * float(og.get("vines_per_m", 0.4)) * moss_k + rng.randf()))
	var lens: Array = og.get("vine_len_m", [0.6, 2.2])
	var was := b.mat
	b.mat = RuinBuilder.LEAF_M
	for i in count:
		var along := rng.randf_range(0.2, maxf(length - 0.2, 0.25))
		var from_top := rng.randf() < 0.6
		var y := y1 - 0.05 if from_top else lerpf(y0 + (y1 - y0) * 0.45, y1 - 0.3, rng.randf())
		var l := rng.randf_range(float(lens[0]), float(lens[1])) * (0.5 + 0.5 * moss_k)
		l = minf(l, y - y0 - 0.1)
		if l < 0.3 or _in_clear(along, clear):
			continue
		var top := o + u * along + Vector3.UP * y + n * out_m
		vine(b, top, u, n, l, rng)
	b.mat = was


## One creeping vine from `top` down the wall (`u` along it, `n` out of
## it), `length` long: a thin stem wandering down over the stones in short
## steps, small leaves off it to either side, a few at its tip.
static func vine(b: RuinBuilder, top: Vector3, u: Vector3, n: Vector3, length: float, rng: RandomNumberGenerator) -> void:
	var steps := maxi(2, int(length / 0.22))
	var p := top
	var drift := rng.randf_range(-0.6, 0.6)
	var stem := RuinBuilder.IVY.darkened(0.25)
	var behind := top - n * 1.0
	for i in steps:
		drift = clampf(drift + rng.randf_range(-0.5, 0.5), -1.0, 1.0)
		var q := p + Vector3.UP * (-length / steps) + u * drift * 0.07 + n * rng.randf_range(-0.01, 0.01)
		var side := u * 0.022
		b._tri_n(p - side, p + side, q + side, n, n, n, stem, stem, stem, behind)
		b._tri_n(p - side, q + side, q - side, n, n, n, stem, stem, stem, behind)
		# Leaves: a small one to each side now and then, more near the tip.
		var k := float(i) / steps
		if rng.randf() < 0.55 + 0.35 * k:
			var sd := 1.0 if rng.randf() < 0.5 else -1.0
			var lc := RuinBuilder.IVY.lerp(RuinBuilder.IVY_LIGHT, rng.randf())
			var s := rng.randf_range(0.06, 0.11)
			var base := (p + q) * 0.5
			var tip := base + u * sd * s * 1.4 + Vector3.UP * s * 0.3 + n * 0.03
			b._tri_n(base, tip + Vector3.UP * s * 0.45, tip - Vector3.UP * s * 0.45, n, n, n, lc, lc.lightened(0.08), lc, behind)
		p = q


## Dust (dry only, `dry` 0-1: dry_of): sand and dust drifted against the
## foot of the wall, the biggest in its corners, reaching
## overgrowth.dry.drift_corner_m out from it; none in a doorway (`clear`).
static func _dust(b: RuinBuilder, o: Vector3, u: Vector3, n: Vector3, length: float, floor_y: float, dry: float, rng: RandomNumberGenerator, clear: Array = []) -> void:
	if dry <= 0.0:
		return
	var dr: Dictionary = overgrowth().get("dry", {})
	var reach := maxf(float(dr.get("drift_corner_m", 0.25)), 0.05)
	var hs: Array = dr.get("drift_h_m", [0.04, 0.16])
	var col := Color(str(dr.get("color", "#a89a7c")))
	var was_solid := b.solid
	var was_mat := b.mat
	# The face's own dice, not the builder's: a face never shifts what the
	# builder rolls after it (TombBuild's collision_only leaves the faces
	# out and must lay every other stone the same).
	var was_rng := b.rng
	b.rng = rng
	b.solid = false
	b.mat = DUST_M
	var spots: Array = [0.2, length - 0.2]
	var count := int(floor(length * float(dr.get("drifts_per_m", 0.35)) * dry + rng.randf()))
	for i in count:
		spots.append(rng.randf_range(0.3, maxf(length - 0.3, 0.35)))
	for i in spots.size():
		var corner := i < 2
		var h := rng.randf_range(float(hs[0]), float(hs[1])) * (1.6 if corner else 1.0) * (0.5 + 0.5 * dry)
		var depth := reach * (1.6 if corner else 1.0) * rng.randf_range(0.8, 1.2)
		var along := float(spots[i])
		var c := o + u * along + Vector3.UP * floor_y + n * depth * 0.5
		var size := Vector3(rng.randf_range(0.35, 0.8), h, depth)
		var dark := rng.randf_range(0.0, 0.12)
		if _in_clear(along, clear, size.x * 0.5):
			continue
		b.boulder(c, size, Basis(u, Vector3.UP, u.cross(Vector3.UP)).orthonormalized(), col.darkened(dark), 0.0)
	b.solid = was_solid
	b.mat = was_mat
	b.rng = was_rng


## Is `along` within `pad` of one of the `clear` stretches ([from, to])?
static func _in_clear(along: float, clear: Array, pad := 0.0) -> bool:
	for c in clear:
		if along > float(c[0]) - pad and along < float(c[1]) + pad:
			return true
	return false
