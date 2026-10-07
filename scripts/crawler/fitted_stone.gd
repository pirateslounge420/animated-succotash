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


## The preset's name for the theme now (masonry.json by_theme).
static func preset_name() -> String:
	if preset_override != "":
		return preset_override.replace("-", "_")
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
## relax_steps of Lloyd's relaxation.
static func cells(length: float, height: float, rng: RandomNumberGenerator) -> Array:
	var p := preset()
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
## `floor_y`; `cl` the climate there (moisture, temp_c: climate_at). Returns
## the stones laid; `out` gets the face's "cells" (its stones' polygons,
## cells(): where its joints run) and "heights" (each one's face off the
## wall's face: Vector2(rim, pillowed middle)), for the beetles (WallLife).
static func face(b: RuinBuilder, o: Vector3, u: Vector3, n: Vector3, length: float, y0: float, y1: float, floor_y: float, cl: Vector2, rng: RandomNumberGenerator, out: Dictionary = {}) -> int:
	if length < 0.3 or y1 - y0 < 0.3:
		return 0
	var p := preset()
	var rl := relief()
	var st: Dictionary = M.get("settle", {})
	var og := overgrowth()
	var joint := float(rl.get("joint_m", 0.012))
	var jd := float(rl.get("joint_depth_m", 0.06))
	var bevel := float(rl.get("bevel_m", 0.05))
	var pillow := float(rl.get("pillow_m", 0.04))
	var shade_joints := str(rl.get("joint_occlusion", "scene_shade")) == "scene_shade"
	var tint_s := str(p.get("tint", "theme"))
	var tint := Color(tint_s) if tint_s.begins_with("#") else Color.WHITE
	# Underground is all shade: the joints and the low wall full shade.
	var moss_k := moss_of(cl, 1.0)
	var jmoss := moss_k * float(og.get("joint_moss", 0.9)) if bool(og.get("moss_in_joints", true)) else 0.0
	var low_m := maxf(float(og.get("moss_low_wall_m", 1.2)), 0.1)
	var low_moss := float(og.get("low_moss", 0.65)) * moss_k
	var was_mat := b.mat
	b.mat = FITTED_M
	var at := func(uv: Vector2, w: float) -> Vector3:
		return o + u * uv.x + Vector3.UP * (y0 + uv.y) + n * w
	# The joints' back: one sheet behind the stones, in the joints' shade.
	var back: Color = (b.palette[1] as Color).darkened(0.25)
	back = Prelit.ao_tint(back, 0.3) if shade_joints else back.darkened(0.5)
	back.a = jmoss
	var inside := o + Vector3.UP * (y0 + y1) * 0.5 - n * 2.0
	var q0: Vector3 = at.call(Vector2(0, 0), -jd)
	var q1: Vector3 = at.call(Vector2(length, 0), -jd)
	var q2: Vector3 = at.call(Vector2(length, y1 - y0), -jd)
	var q3: Vector3 = at.call(Vector2(0, y1 - y0), -jd)
	b._tri_n(q0, q1, q2, n, n, n, back, back, back, inside + u * length * 0.5)
	b._tri_n(q0, q2, q3, n, n, n, back, back, back, inside + u * length * 0.5)
	var laid := 0
	var share := float(st.get("share", 0.15))
	var offs: Array = st.get("offset_m", [-0.04, 0.06])
	var tilts: Array = st.get("tilt_deg", [0.0, 4.0])
	var all := cells(length, y1 - y0, rng)
	# Each stone's face off the wall's face: (its rim, its pillowed middle);
	# a sliver left as joint stays down at the joints' back.
	var heights := PackedVector2Array()
	heights.resize(all.size())
	heights.fill(Vector2(-jd, -jd))
	for ci in all.size():
		var cell: Array = all[ci]
		var poly: PackedVector2Array = cell[1]
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
		var cs := c - Vector2(0, sink)
		var s0 := maxf(0.2, 1.0 - joint * 0.5 / r_in)
		var s1 := maxf(0.12, 1.0 - (joint * 0.5 + bevel) / r_in)
		var col: Color = (b.palette[rng.randi() % b.palette.size()] as Color).darkened(rng.randf_range(0.0, 0.14))
		col = Color(col.r * tint.r, col.g * tint.g, col.b * tint.b)
		var patch := rng.randf_range(0.5, 1.3)
		var foot_col: Color = Prelit.ao_tint(col, 0.55) if shade_joints else col.darkened(0.3)
		foot_col.a = jmoss * 0.85
		# A small stone's face needs no middle ring.
		var ring := r_in > 0.12
		var nv := poly.size()
		var r0: Array[Vector3] = []
		var r1: Array[Vector3] = []
		var rm: Array[Vector3] = []
		var n0: Array[Vector3] = []
		var n1: Array[Vector3] = []
		var nm: Array[Vector3] = []
		var c1: Array[Color] = []
		var cm: Array[Color] = []
		for k in nv:
			var d := (poly[k] - c).rotated(rot)
			var radial := (u * d.x + Vector3.UP * d.y).normalized()
			r0.append(at.call(cs + d * s0, -jd * 0.45 + off))
			r1.append(at.call(cs + d * s1, proud + off))
			rm.append(at.call(cs + d * s1 * 0.55, proud + pillow * 0.72 + off))
			n0.append((n * 0.35 + radial).normalized())
			n1.append((n + radial * 0.6).normalized())
			nm.append((n + radial * 0.28).normalized())
			c1.append(_mossy(col, (r1[k] as Vector3).y - floor_y, low_m, low_moss * patch))
			cm.append(_mossy(col, (rm[k] as Vector3).y - floor_y, low_m, low_moss * patch))
		var top: Vector3 = at.call(cs, proud + pillow + off)
		var ct := _mossy(col, top.y - floor_y, low_m, low_moss * patch)
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
		laid += 1
	b.mat = was_mat
	out["cells"] = all
	out["heights"] = heights
	# Vines grow up the wall into half shade.
	_vines(b, o, u, n, length, y0, y1, moss_of(cl, 0.5), float((rl.get("proud_m", [0.02, 0.06]) as Array)[1]) + pillow, rng)
	_dust(b, o, u, n, length, floor_y, dry_of(cl), rng)
	return laid


## A stone's colour with the lower wall's moss in its alpha (the ruin
## shader's moss), fading up the wall.
static func _mossy(col: Color, above_floor: float, low_m: float, amount: float) -> Color:
	var c := col
	c.a = clampf(amount * (1.0 - smoothstep(0.0, low_m, above_floor)), 0.0, 1.0)
	return c


## Vines (where the climate allows, `moss_k`): from the wall's top under the
## ceiling, and from cracks in its upper half, hanging down. Generic ivy
## until a world gives its biome's own vine species (vines.json, §CS).
static func _vines(b: RuinBuilder, o: Vector3, u: Vector3, n: Vector3, length: float, y0: float, y1: float, moss_k: float, out_m: float, rng: RandomNumberGenerator) -> void:
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
		if l < 0.3:
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
## overgrowth.dry.drift_corner_m out from it.
static func _dust(b: RuinBuilder, o: Vector3, u: Vector3, n: Vector3, length: float, floor_y: float, dry: float, rng: RandomNumberGenerator) -> void:
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
		b.boulder(c, Vector3(rng.randf_range(0.35, 0.8), h, depth), Basis(u, Vector3.UP, u.cross(Vector3.UP)).orthonormalized(), col.darkened(rng.randf_range(0.0, 0.12)), 0.0)
	b.solid = was_solid
	b.mat = was_mat
	b.rng = was_rng
