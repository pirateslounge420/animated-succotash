class_name AztecPyramid
## The Aztec temple's twin on the surface (design 10 Oct §FN.4, queue 84;
## data/aztec_temple.json surface.pyramid; SurfaceBuild.make builds it):
## a step pyramid in the temple's one stone (§EX.1: masonry.json
## aztec_temple, RuinStyle), broad tiers stepping in, a stair up the face
## that looks toward where you come up, its balustrades either side, and a
## small altar on the flat top; weathered and crumbling (blocks settled and
## askew, the tiers' top courses broken at the corners, fallen blocks at the
## foot), overgrown only as the surface's climate allows (the builder's
## growth, dry in the desert). It stands on land, never in the wash, clear
## of the stairhead's yard and every vent's stack and slot, in view from
## where you come up: the eye is led to it.
##
## Scenery only: no fast travel, no beacon, no exit, no gameplay number;
## walking up its stair is just walking (its steps a slope under the block
## steps, as the tomb's stairs are walked). It stands only over the Aztec
## temple: the dungeon's ruin kind aztec_temple, with aztec_temple.json
## enabled (CrawlerSave.aztec_on). With that false nothing is built and
## nothing changes. The stair up from the dungeon comes out beside it for
## now (inside or beside is open, §FN.4).
##
## Static, on the builder's dice (SurfaceBuild.rng) after the stacks, and
## its place on its own (the surface's seed and "pyramid"), so the same game
## has the same pyramid.

## Its data (aztec_temple.json surface.pyramid), or {}.
static func data() -> Dictionary:
	return ((Tuning.table("aztec_temple").get("surface", {}) as Dictionary).get("pyramid", {}) as Dictionary)


## Does the surface over dungeon `lay` have the pyramid? The Aztec temple
## only, and only while it is in the game (aztec_temple.json enabled).
static func stands_over(lay: Dictionary) -> bool:
	return CrawlerSave.aztec_on and RoomPool.ruin_kind(str(lay.get("theme", ""))) == "aztec_temple" and not data().is_empty()


## Its shape from the data: {"tiers", "half" [each tier's half side],
## "tier_h", "inset", "stair_w", "slope", "altar" (Vector3 size)}.
static func shape() -> Dictionary:
	var d := data()
	var tiers := clampi(int(d.get("tiers", 5)), 1, 13)
	var base := clampf(float(d.get("base_m", 26.0)), 8.0, 80.0)
	var inset := clampf(float(d.get("inset_m", 1.8)), 0.6, 6.0)
	var halves: Array = []
	for k in tiers:
		halves.append(maxf(base * 0.5 - inset * k, 2.0))
	var al: Array = d.get("altar_m", [1.4, 0.8, 0.9])
	return {"tiers": tiers, "half": halves, "tier_h": clampf(float(d.get("tier_h_m", 2.0)), 0.8, 6.0), "inset": inset,
		"stair_w": clampf(float(d.get("stair_w_m", 4.0)), 1.6, base * 0.5), "slope": clampf(float(d.get("stair_slope", 0.6)), 0.3, 0.9),
		"altar": Vector3(float(al[0]), float(al[1]), float(al[2]))}


## Where it stands on ground `g`, the stairhead `st` (SurfaceBuild.stair)
## and the vents' tops `avoid` ([Vector2]): its middle (x/z) and its face
## (x/z, out of the stair's face toward where you come up), or {} where no
## place fits. Tried round the way out at the data's distances and angles
## off it (at_m, off_deg), each side, nearest first: the whole footprint
## and the stair's foot on the basin's floor, out of the wash, off the
## yard, clear of every stack and slot.
static func place(g: SurfaceGround, st: Dictionary, avoid: Array, seed_value: int) -> Dictionary:
	var d := data()
	var sh := shape()
	var half := float((sh.half as Array)[0])
	var at: Array = d.get("at_m", [34.0, 60.0])
	var off: Array = d.get("off_deg", [28.0, 70.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "pyramid"])
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var arrive: Vector2 = st.arrive
	var n: Vector2 = st.n
	var yard: Rect2 = st.yard
	var dist := float(at[0])
	while dist <= float(at[1]) + 0.01:
		var deg := float(off[0])
		while deg <= float(off[1]) + 0.01:
			for sg: float in [side, -side]:
				var dir := n.rotated(deg_to_rad(deg) * sg)
				var c := arrive + dir * dist
				var face := (arrive - c).normalized()
				if _fits(g, c, face, half, sh, yard, avoid):
					return {"c": c, "face": face}
			deg += 6.0
		dist += 4.0
	return {}


## The stair's run out from the top tier's edge (m): its rise at its slope.
static func _stair_run(sh: Dictionary) -> float:
	return float(sh.tier_h) * int(sh.tiers) / float(sh.slope)


static func _fits(g: SurfaceGround, c: Vector2, face: Vector2, half: float, sh: Dictionary, yard: Rect2, avoid: Array) -> bool:
	var s := Vector2(-face.y, face.x)
	var top_half := float((sh.half as Array)[-1])
	var foot := top_half + _stair_run(sh)
	var pts: Array = []
	for i in 7:
		for j in 7:
			pts.append(c + face * lerpf(-half, half, i / 6.0) + s * lerpf(-half, half, j / 6.0))
	for i in 5:
		pts.append(c + face * lerpf(half, foot + 1.0, i / 4.0) + s * float(sh.stair_w) * 0.6)
		pts.append(c + face * lerpf(half, foot + 1.0, i / 4.0) - s * float(sh.stair_w) * 0.6)
	for p: Vector2 in pts:
		if not g.on_floor(p, 12.0) or g.in_wash(p) > 0.0 or yard.grow(3.0).has_point(p):
			return false
	var r := maxf(half * 1.42, foot) + 3.0
	for a: Vector2 in avoid:
		if a.distance_to(c) < r:
			return false
	return true


## Build it with `b` (the surface's builder, its stone the dungeon's theme's
## style) over dungeon `lay`; {} when it doesn't stand there. Returns {"c"
## (x/z middle), "face" (x/z out of the stair's face), "foot_y" (its
## foundation), "top_y" (the top's floor), "top_half", "half" (the base's
## half side), "stair_foot" and "stair_top" (Vector3, the stair's line's
## ends on its slope), "altar" (Vector3, the altar's top middle), "rect"
## (x/z bounds, for what keeps clear of it)}.
static func build(b: SurfaceBuild, lay: Dictionary, seed_value: int) -> Dictionary:
	if not stands_over(lay):
		return {}
	var avoid: Array = []
	for s in b.stacks:
		avoid.append(Vector2((s.foot as Vector3).x, (s.foot as Vector3).z))
	for s in b.slots:
		avoid.append(Vector2((s.at as Vector3).x, (s.at as Vector3).z))
	var where := place(b.land, b.stair, avoid, seed_value)
	if where.is_empty():
		push_warning("AztecPyramid: no place on the basin's floor fits the pyramid (seed %d); none built" % seed_value)
		return {}
	var sh := shape()
	var c: Vector2 = where.c
	var face: Vector2 = where.face
	# Across the face, so (across, up, out) is a right-handed basis.
	var s2 := Vector2(face.y, -face.x)
	var f3 := Vector3(face.x, 0.0, face.y)
	var s3 := Vector3(s2.x, 0.0, s2.y)
	var bs := Basis(s3, Vector3.UP, f3)
	var halves: Array = sh.half
	var half := float(halves[0])
	var th := float(sh.tier_h)
	# The ground under it: its foundation under the lowest, its tiers
	# counted from the highest.
	var lo := INF
	var hi := -INF
	for i in 9:
		for j in 9:
			var q := c + face * lerpf(-half, half, i / 8.0) + s2 * lerpf(-half, half, j / 8.0)
			var gy := b.land.height_at(q.x, q.y)
			lo = minf(lo, gy)
			hi = maxf(hi, gy)
	var foot_y := lo - 0.5
	var crumble := clampf(float(data().get("crumble", 0.15)), 0.0, 0.6)
	var c3 := Vector3(c.x, 0.0, c.y)
	b._stone_mode()
	var was_solid := b.solid
	var was_foot := b.foot_y
	var bottom := foot_y
	for k in int(sh.tiers):
		var hk := float(halves[k])
		var top := hi + th * (k + 1)
		# Its body: collision only (the faces are its blocks).
		b._collision_box(Transform3D(bs, c3 + Vector3.UP * ((bottom + top) * 0.5)), Vector3(hk, (top - bottom) * 0.5, hk))
		b.solid = false
		_tier_faces(b, c3, f3, s3, hk, bottom, top, crumble, k == int(sh.tiers) - 1)
		# Its top: the ledge between it and the tier above, slabs.
		var inner := float(halves[k + 1]) if k + 1 < int(sh.tiers) else 0.0
		_ledge(b, c3, f3, s3, hk, inner, top)
		bottom = top
	var top_y := hi + th * int(sh.tiers)
	var top_half := float(halves[-1])
	# The stair up the face toward where you come up.
	var run := _stair_run(sh)
	var foot_g := b.land.height_at(c.x + face.x * (top_half + run), c.y + face.y * (top_half + run))
	var rise := top_y - foot_g
	run = maxf(rise / float(sh.slope), 1.0)
	var stair_top := c3 + f3 * top_half + Vector3.UP * top_y
	var stair_foot := c3 + f3 * (top_half + run) + Vector3.UP * foot_g
	_stair(b, stair_foot, stair_top, f3, s3, float(sh.stair_w), foot_y)
	# The altar on the flat top, back from the stair's head.
	var al: Vector3 = sh.altar
	var ap := c3 - f3 * (top_half * 0.35) + Vector3.UP * top_y
	b.solid = true
	b.foot_y = top_y
	var acol := RuinStyle.stone(b.rng)
	b.box(Transform3D(bs, ap + Vector3.UP * (al.y * 0.5)), al, acol, b._growth(0.1), 0.05, 0.02)
	b.solid = false
	# A carved band round it, cut in (toward navy, §ES).
	var cut: Color = acol if TombBuild.bare else Prelit.ao_tint(acol, 0.35)
	b.box(Transform3D(bs, ap + Vector3.UP * (al.y * 0.72)), Vector3(al.x + 0.012, 0.06, al.z + 0.012), cut, 0.0, 0.0, 0.0)
	# Fallen blocks at the foot of its corners.
	b._floor = lo
	for k in 3:
		var corner := c3 + (f3 * (1.0 if b.rng.randf() < 0.5 else -1.0) + s3 * (1.0 if b.rng.randf() < 0.5 else -1.0)) * (half + 1.2)
		b._floor = b.land.height_at(corner.x, corner.z)
		b.rubble(corner, 2.2, 6)
	b.solid = was_solid
	b.foot_y = was_foot
	var ext := maxf(half, top_half + run) + 1.0
	var rect := Rect2(c - Vector2(ext, ext), Vector2(2.0 * ext, 2.0 * ext))
	return {"c": c, "face": face, "foot_y": foot_y, "top_y": top_y, "top_half": top_half, "half": half, "stair_foot": stair_foot,
		"stair_top": stair_top, "altar": ap + Vector3.UP * al.y, "rect": rect, "tiers": int(sh.tiers)}


## One tier's four faces from `y0` up to `y1`, `h` from the middle: courses
## of squared blocks (the temple's coursed stone), each settled a little;
## a share `crumble` of the top course's blocks near a corner dropped,
## askew, or gone (the corner broken).
static func _tier_faces(b: SurfaceBuild, c3: Vector3, f3: Vector3, s3: Vector3, h: float, y0: float, y1: float, crumble: float, last: bool) -> void:
	var courses := maxi(int(round((y1 - y0) / 0.7)), 1)
	var ch := (y1 - y0) / courses
	var deep := 0.7
	for side in 4:
		var n: Vector3 = [f3, -f3, s3, -s3][side]
		var t := Vector3.UP.cross(n).normalized()
		var bs := Basis(t, Vector3.UP, n)
		for q in courses:
			var yc := y0 + ch * (q + 0.5)
			b.foot_y = y0 + ch * q
			var x := -h
			var top_course := q == courses - 1
			while x < h - 0.01:
				var l := b.rng.randf_range(1.2, 2.2)
				if h - (x + l) < 0.7:
					l = h - x
				var mid := x + l * 0.5
				var corner_k := 1.0 - clampf((h - absf(mid)) / 3.0, 0.0, 1.0)
				var drop := 0.0
				var yaw := b.rng.randf_range(-0.012, 0.012)
				if top_course and b.rng.randf() < crumble * (0.4 + 1.6 * corner_k):
					if b.rng.randf() < 0.4 and not last:
						x += l
						continue
					drop = b.rng.randf_range(0.08, 0.35)
					yaw += b.rng.randf_range(-0.08, 0.08)
				var p := c3 + n * (h - deep * 0.5) + t * mid + Vector3.UP * (yc - drop)
				b.box(Transform3D(bs.rotated(Vector3.UP, yaw), p), Vector3(l - 0.02, ch - 0.02, deep), RuinStyle.stone(b.rng), b._growth(0.12), 0.05, 0.02)
				x += l


## The ledge on a tier's top, from its edge `h` in to the next tier's
## `inner` (the whole top on the last): slabs, drawn.
static func _ledge(b: SurfaceBuild, c3: Vector3, f3: Vector3, s3: Vector3, h: float, inner: float, y: float) -> void:
	b.foot_y = y
	if inner <= 0.0:
		var n := maxi(int(ceil(2.0 * h / 2.0)), 1)
		var w := 2.0 * h / n
		for i in n:
			for j in n:
				var p := c3 + f3 * (-h + w * (i + 0.5)) + s3 * (-h + w * (j + 0.5)) + Vector3.UP * (y - 0.07)
				b.box(Transform3D(Basis(s3, Vector3.UP, f3), p), Vector3(w - 0.02, 0.14, w - 0.02), RuinStyle.stone(b.rng), b._growth(0.2), 0.03, 0.015)
		return
	var depth := h - inner + 0.3
	for side in 4:
		var n: Vector3 = [f3, -f3, s3, -s3][side]
		var t := Vector3.UP.cross(n).normalized()
		var p := c3 + n * (h - depth * 0.5) + Vector3.UP * (y - 0.07)
		b.box(Transform3D(Basis(t, Vector3.UP, n), p), Vector3(2.0 * h - 0.02, 0.14, depth), RuinStyle.stone(b.rng), b._growth(0.25), 0.03, 0.015)


## The stair from `foot` (on the ground) up to `top` (the top's edge) along
## `f3` (out of the face), `w` wide: block steps a slope's rise each 0.3 m,
## each a block from the foundation `base_y` up to its tread (drawn), the
## slope under them its collision (RuinBuilder._dramp, as the tomb's stairs
## are walked), and a balustrade either side.
static func _stair(b: SurfaceBuild, foot: Vector3, top: Vector3, f3: Vector3, s3: Vector3, w: float, base_y: float) -> void:
	var rise := top.y - foot.y
	var n := maxi(int(round(rise / 0.3)), 1)
	var flat := Vector2(top.x - foot.x, top.z - foot.z).length()
	var run := flat / n
	var bs := Basis(s3, Vector3.UP, f3)
	b.solid = false
	for k in n:
		# Step k's front is k + 0.5 runs in from the foot; its block reaches
		# back under the next steps to the face.
		var front := flat - (k + 0.5) * run
		var tread := foot.y + rise * (k + 1) / n
		var y0 := minf(base_y, foot.y - 0.4)
		var p := top + f3 * (front - run * 0.5)
		b.foot_y = y0
		b.box(Transform3D(bs.rotated(Vector3.UP, b.rng.randf_range(-0.006, 0.006)), Vector3(p.x, (y0 + tread) * 0.5, p.z)), Vector3(w, tread - y0, run + 0.02), RuinStyle.stone(b.rng), b._growth(0.1), 0.03, 0.012)
	# The balustrades (alfardas): a sloped block either side, drawn.
	var along := (top - foot)
	var ln := along.length()
	var dirv := along / ln
	# A right-handed basis (across, up the slope's normal, along it).
	var x := s3
	var up := dirv.cross(x).normalized()
	if up.y < 0.0:
		x = -x
		up = -up
	for sg: float in [-1.0, 1.0]:
		var p := (foot + top) * 0.5 + s3 * sg * (w * 0.5 + 0.3) + up * 0.15
		b.box(Transform3D(Basis(x, up, dirv), p), Vector3(0.6, 0.9, ln + 0.6), RuinStyle.stone(b.rng), b._growth(0.1), 0.04, 0.015)
	# Walked as a slope.
	b._dramp(foot, top, w)
