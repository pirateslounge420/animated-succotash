class_name TreeLayouts
## The wood of a tree (spec Phase 1 (i)): where its trunk, limbs and
## branches run and where its leaf clumps sit, in the tree's unit-height
## frame (trunk base at the origin, +Y up the unleaned trunk, 1 unit tall;
## instances scale it by their height). Three things are built from the
## same skeleton, so they always agree:
##   * PlantMeshes draws a branchy tree's trunk, limbs, branches and clumps;
##   * TerrainChunk gives the trunk stacked cylinder colliders and, near
##     the player, the thick limbs and branches capsules;
##   * branch graphs (BranchGraph) lay their handholds along the wood.
##
## Branchy canopy and emergent trees (broadleaf, gnarled, emergent,
## umbrella, cypress shapes) grow COUNT layouts per species, from the world
## seed and the species alone. Each tree picks a layout, and whether it is
## mirrored, by hashing where it stands (pick()): the same tree grows the
## same way on every visit, neighbours differ, and the trees of a species
## still batch into a few MultiMeshes (one per layout). Other trees have one
## fixed skeleton each, traced from their meshes: a trunk (a mangrove's
## stilt roots too; cacti and rosettes are solid shapes only).
##
## Nothing is stored: everything regrows from the seed, and only caches
## are kept (behind a mutex: chunk workers build meshes in parallel).

const S := PlantSpecies.Shape
## Layouts per branchy species (the spec agreed "about 6").
const COUNT := 6

## What a piece of wood is. TRUNK, ROOT and SOLID always have colliders;
## LIMB and BRANCH get them only while the tree is in branch-graph range.
## Everything but SOLID carries handholds.
enum Kind { TRUNK, ROOT, LIMB, BRANCH, SOLID }

## Knee height (m): plants whose wood stays below it get no collider.
const KNEE_M := 0.5
## Limbs and branches at least this thick (radius, m) get a collider near
## the player, so arrows stick in them.
const LIMB_COLLIDER_R_M := 0.05
## Colliders sit just inside the drawn wood (its polygon's inner radius).
const COLLIDER_FIT := 0.92

static var _seed := 0
static var _skeletons := {} # Vector2i(species index, layout) -> Skeleton
static var _holds := {} # Vector3i(species index, layout, height step) -> Array
static var _mutex := Mutex.new()


## One piece of wood: a centerline through the unit frame with a radius at
## each point, what kind it is, which limb it belongs to (0 = the trunk; a
## branch has its limb's number) and the piece it grows from.
class Piece:
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var kind := 0
	var limb := 0
	var parent := -1
	## Where it meets its parent (its first point; a root's last).
	var join := Vector3.ZERO
	## Arc length (unit) from the first point to each point.
	var arc := PackedFloat32Array()

	func add(p: Vector3, r: float) -> void:
		pts.append(p)
		rad.append(r)

	func finish() -> void:
		arc.resize(pts.size())
		var total := 0.0
		for i in pts.size():
			if i > 0:
				total += pts[i].distance_to(pts[i - 1])
			arc[i] = total
		join = pts[pts.size() - 1] if kind == Kind.ROOT else pts[0]

	func length() -> float:
		return arc[arc.size() - 1]

	## [position, unit tangent, radius] at arc length `s`.
	func at(s: float) -> Array:
		var n := pts.size()
		var k := 0
		while k < n - 2 and arc[k + 1] < s:
			k += 1
		var seg := maxf(arc[k + 1] - arc[k], 1e-9)
		var f := clampf((s - arc[k]) / seg, 0.0, 1.0)
		return [pts[k].lerp(pts[k + 1], f), (pts[k + 1] - pts[k]).normalized(), lerpf(rad[k], rad[k + 1], f)]


## A tree's wood and leaf clumps, unit frame.
class Skeleton:
	var pieces: Array[Piece] = []
	## Leaf clumps: [center, radii, tone (0 the species color, 1 lighter, 2 darker)].
	var clumps: Array = []
	## How much the clumps sway (the old crown's value for the shape).
	var sway := 0.8
	## Hanging vine strands for the mesh.
	var vines := 5
	## Cypress: the buttress cone at the foot ([radius, height]; 0 = none).
	var buttress := Vector2.ZERO

	func add(p: Piece) -> int:
		p.finish()
		pieces.append(p)
		return pieces.size() - 1


## Clear the caches when the world seed changes (main thread, before any
## chunk worker runs; PlantMeshes.use_seed calls it). True if it changed.
static func use_seed(world_seed: int) -> bool:
	_mutex.lock()
	var changed := world_seed != _seed
	if changed:
		_seed = world_seed
		_skeletons.clear()
		_holds.clear()
	_mutex.unlock()
	return changed


## Does this species grow layouts (limbs, branches and leaf clumps)?
static func branchy(sp: PlantSpecies) -> bool:
	return (sp.tier == PlantSpecies.Tier.EMERGENT or sp.tier == PlantSpecies.Tier.CANOPY) \
		and sp.shape in [S.BROADLEAF, S.GNARLED, S.EMERGENT, S.UMBRELLA, S.CYPRESS]


## The layout a tree grows, from the world seed, its chunk and its surface
## direction: 0 .. 2 * COUNT - 1, the layout being pick % COUNT, mirrored
## (x -> -x in the unit frame) when pick >= COUNT.
static func pick(world_seed: int, chunk_key: Vector3i, dir: Vector3) -> int:
	return hash([world_seed, chunk_key, dir]) % (COUNT * 2)


## The layout a pick grows (-1: a tree without layouts, pick -1).
static func layout_of(pick_v: int) -> int:
	return pick_v % COUNT if pick_v >= 0 else -1


## Is a tree with this pick mirrored?
static func is_mirrored(pick_v: int) -> bool:
	return pick_v >= COUNT


## The skeleton of a species' layout (layout -1: its one fixed skeleton,
## for trees without layouts). Thread-safe; built once.
static func skeleton(sp_idx: int, layout: int) -> Skeleton:
	var key := Vector2i(sp_idx, layout)
	_mutex.lock()
	var cached = _skeletons.get(key)
	var seed_now := _seed
	_mutex.unlock()
	if cached != null:
		return cached
	var sp: PlantSpecies = SpeciesDB.all()[sp_idx]
	var sk: Skeleton
	if layout >= 0 and branchy(sp):
		sk = _grow(sp, sp_idx, layout, seed_now)
	else:
		sk = _fixed(sp)
	_mutex.lock()
	if not _skeletons.has(key):
		_skeletons[key] = sk
	var out: Skeleton = _skeletons[key]
	_mutex.unlock()
	return out


# --- Growing a branchy layout -------------------------------------------------

## Per shape: trunk radius, fork height range, trunk bend, crown envelope
## (center, radii: the old single crown's), crown kind, limb count range,
## clump count range, clump radii, clump sway, vines, how far limbs reach
## toward their clumps, how steeply they leave the trunk, kinks.
static func _params(shape: int) -> Dictionary:
	match shape:
		S.GNARLED:
			return {"r0": 0.075, "fork": Vector2(0.27, 0.34), "bend": 0.12, "top": 0.62,
				"c": Vector3(0.08, 0.66, 0), "r": Vector3(0.42, 0.2, 0.34), "crown": "dome",
				"limbs": Vector2i(3, 5), "clumps": Vector2i(8, 11), "clump": Vector3(0.13, 0.085, 0.13),
				"sway": 0.8, "vines": 6, "reach": Vector2(0.5, 0.68), "lift": 0.18, "kink": 0.03}
		S.EMERGENT:
			return {"r0": 0.03, "fork": Vector2(0.74, 0.79), "bend": 0.03, "top": 0.62,
				"c": Vector3(0, 0.91, 0), "r": Vector3(0.3, 0.07, 0.3), "crown": "plate",
				"limbs": Vector2i(3, 5), "clumps": Vector2i(7, 9), "clump": Vector3(0.095, 0.045, 0.095),
				"sway": 1.0, "vines": 4, "reach": Vector2(0.55, 0.72), "lift": 0.3, "kink": 0.008}
		S.UMBRELLA:
			return {"r0": 0.045, "fork": Vector2(0.36, 0.47), "bend": 0.06, "top": 0.62,
				"c": Vector3(0.04, 0.82, 0), "r": Vector3(0.6, 0.08, 0.55), "crown": "plate",
				"limbs": Vector2i(3, 5), "clumps": Vector2i(10, 13), "clump": Vector3(0.15, 0.05, 0.15),
				"sway": 1.0, "vines": 5, "reach": Vector2(0.6, 0.76), "lift": 0.34, "kink": 0.015}
		S.CYPRESS:
			return {"r0": 0.045, "fork": Vector2(0.9, 0.95), "bend": 0.0, "top": 0.22,
				"c": Vector3(0, 0.72, 0), "r": Vector3(0.17, 0.3, 0.17), "crown": "column",
				"limbs": Vector2i(3, 5), "clumps": Vector2i(0, 0), "clump": Vector3(0.075, 0.085, 0.075),
				"sway": 0.9, "vines": 4, "reach": Vector2(0.0, 0.0), "lift": 0.0, "kink": 0.006}
	# BROADLEAF
	return {"r0": 0.05, "fork": Vector2(0.35, 0.44), "bend": 0.04, "top": 0.62,
		"c": Vector3(0, 0.7, 0), "r": Vector3(0.36, 0.3, 0.36), "crown": "dome",
		"limbs": Vector2i(3, 5), "clumps": Vector2i(8, 11), "clump": Vector3(0.12, 0.1, 0.12),
		"sway": 0.8, "vines": 5, "reach": Vector2(0.5, 0.68), "lift": 0.25, "kink": 0.012}


## The trunk's rings, as fractions of its height, and how much the foot
## flares at each (the old trunk's hero rings).
const TRUNK_T := [0.0, 0.03, 0.08, 0.25, 0.5, 0.75, 1.0]
const TRUNK_FLARE := [1.75, 1.3, 1.08, 1.0, 1.0, 1.0, 1.0]
## Limb and branch centerline samples.
const LIMB_T := [0.0, 0.25, 0.5, 0.75, 1.0]


## Trunk centerline point at height fraction t of a trunk `h` tall that
## bends by `bend` (as the old meshes' trunks did).
static func _trunk_at(t: float, h: float, bend: float) -> Vector3:
	return Vector3(bend * t * t, t * h, bend * 0.3 * t * t)


static func _grow(sp: PlantSpecies, idx: int, layout: int, world_seed: int) -> Skeleton:
	var p := _params(sp.shape)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, idx, layout, "layout"])
	var sk := Skeleton.new()
	sk.sway = p.sway
	sk.vines = p.vines
	var r0: float = p.r0
	var fork := rng.randf_range(p.fork.x, p.fork.y)
	var bend: float = p.bend * rng.randf_range(0.7, 1.3)
	var top: float = p.top
	var trunk := Piece.new()
	trunk.kind = Kind.TRUNK
	for k in TRUNK_T.size():
		var t: float = TRUNK_T[k]
		var r := r0 * lerpf(1.0, top, t) * float(TRUNK_FLARE[k])
		trunk.add(_trunk_at(t, fork, bend), r)
	if p.crown == "column":
		# Bald cypress: a flared, buttressed foot (drawn as a cone).
		sk.buttress = Vector2(0.12, 0.25)
		for k in trunk.pts.size():
			var y := trunk.pts[k].y
			trunk.rad[k] = maxf(trunk.rad[k], 0.12 * (1.0 - y / 0.25) * 0.8)
	var trunk_i := sk.add(trunk)
	var up := Vector3.UP
	var env_c: Vector3 = p.c
	var env_r: Vector3 = p.r
	var clump_r: Vector3 = p.clump
	var n_limbs := rng.randi_range(p.limbs.x, p.limbs.y)
	var r_fork := trunk.rad[trunk.rad.size() - 1]
	var limb_r := r_fork * clampf(1.3 / sqrt(float(n_limbs)), 0.5, 0.8)

	if p.crown == "column":
		_grow_column(sk, trunk, trunk_i, rng, n_limbs, env_r, clump_r, r0)
		return sk

	# Leaf clumps spread over the crown: a golden-angle spiral, over the
	# upper shell of the envelope (dome) or across a disc (plate).
	var n_clumps := rng.randi_range(p.clumps.x, p.clumps.y)
	var spin := rng.randf() * TAU
	var centers: Array[Vector3] = []
	for k in n_clumps:
		var v := (k + 0.5) / n_clumps
		var az := spin + k * 2.39996 + rng.randf_range(-0.3, 0.3)
		var c: Vector3
		if p.crown == "dome":
			var z := lerpf(-0.3, 0.97, v)
			var el := asin(z)
			var s := rng.randf_range(0.64, 0.82)
			c = env_c + Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el)) * env_r * s
		else:
			var rr := sqrt(v) * 0.86
			c = env_c + Vector3(cos(az) * rr * env_r.x, env_r.y * (0.6 - rr * rr) + rng.randf_range(-0.3, 0.3) * env_r.y, sin(az) * rr * env_r.z)
		centers.append(c)
	# Limbs fan out at even bearings; each clump goes to the limb nearest in
	# bearing (clumps over the middle to whichever limb has the fewest).
	var limb_az: Array[float] = []
	var az0 := rng.randf() * TAU
	for l in n_limbs:
		limb_az.append(az0 + TAU * (l + rng.randf_range(-0.18, 0.18)) / n_limbs)
	var groups: Array = []
	for l in n_limbs:
		groups.append([])
	var middle: Array[int] = []
	var fork_p := trunk.pts[trunk.pts.size() - 1]
	for k in centers.size():
		var off := centers[k] - fork_p
		var horiz := Vector2(off.x, off.z)
		if horiz.length() < env_r.x * 0.22:
			middle.append(k)
			continue
		var best := 0
		var best_d := INF
		for l in n_limbs:
			var d := absf(angle_difference(horiz.angle(), limb_az[l]))
			if d < best_d:
				best_d = d
				best = l
		(groups[best] as Array).append(k)
	for k in middle:
		var fewest := 0
		for l in n_limbs:
			if (groups[l] as Array).size() < (groups[fewest] as Array).size():
				fewest = l
		(groups[fewest] as Array).append(k)
	# No bare limb: an empty one takes a clump from the fullest.
	for l in n_limbs:
		if (groups[l] as Array).is_empty():
			var fullest := 0
			for m in n_limbs:
				if (groups[m] as Array).size() > (groups[fullest] as Array).size():
					fullest = m
			if (groups[fullest] as Array).size() > 1:
				(groups[l] as Array).append((groups[fullest] as Array).pop_back())
	var tones := [0, 1, 2]
	for k in centers.size():
		var jitter := rng.randf_range(0.85, 1.15)
		sk.clumps.append([centers[k], clump_r * jitter, tones[k % 3]])

	var limb_no := 0
	for l in n_limbs:
		var group: Array = groups[l]
		if group.is_empty():
			continue
		limb_no += 1
		var centroid := Vector3.ZERO
		for k in group:
			centroid += centers[k]
		centroid /= group.size()
		# The limb leaves the trunk top (staggered a little below it), rises
		# steeply, then bends out toward its clumps and stops short of them.
		var root_t := 1.0 - rng.randf_range(0.0, 0.06)
		var root := _trunk_at(root_t, fork, bend)
		var reach := rng.randf_range(p.reach.x, p.reach.y)
		var end := root + (centroid - root) * reach
		var chord := end - root
		var ctrl := root + chord * 0.3 + up * chord.length() * float(p.lift)
		var limb := Piece.new()
		limb.kind = Kind.LIMB
		limb.limb = limb_no
		limb.parent = trunk_i
		var side := chord.cross(up).normalized() if chord.cross(up).length() > 1e-4 else Vector3.RIGHT
		for t in LIMB_T:
			var q := root.lerp(ctrl, t).lerp(ctrl.lerp(end, t), t)
			if t > 0.0 and t < 1.0:
				q += side * rng.randf_range(-1.0, 1.0) * float(p.kink) + up * rng.randf_range(-0.5, 0.5) * float(p.kink)
			limb.add(q, limb_r * lerpf(1.0, 0.55, t))
		var limb_i := sk.add(limb)
		# A branch from the outer half of the limb into each clump.
		for k in group:
			var c: Vector3 = centers[k]
			var j := 2
			var best_d := INF
			for m in range(2, limb.pts.size()):
				var d := limb.pts[m].distance_to(c)
				if d < best_d:
					best_d = d
					j = m
			var b_root := limb.pts[j]
			var b_end := c + (b_root - c).normalized() * clump_r.y * 0.3
			if b_root.distance_to(b_end) < 0.02:
				continue
			var branch := Piece.new()
			branch.kind = Kind.BRANCH
			branch.limb = limb_no
			branch.parent = limb_i
			var br := limb.rad[j] * 0.7
			var mid := b_root.lerp(b_end, 0.5) + up * b_root.distance_to(b_end) * 0.12
			branch.add(b_root, br)
			branch.add(mid, br * 0.75)
			branch.add(b_end, br * 0.45)
			sk.add(branch)
	return sk


## Cypress: the trunk runs on as a leader to the top; short limbs leave it
## at stepped heights, angled up, each ending in a clump or two; one clump
## crowns the leader.
static func _grow_column(sk: Skeleton, trunk: Piece, trunk_i: int, rng: RandomNumberGenerator, n_limbs: int,
		env_r: Vector3, clump_r: Vector3, r0: float) -> void:
	var top := trunk.pts[trunk.pts.size() - 1]
	sk.clumps.append([top + Vector3(0, 0.02, 0), clump_r * Vector3(0.85, 1.0, 0.85), 1])
	var az := rng.randf() * TAU
	for l in n_limbs:
		var y := lerpf(0.46, 0.84, (l + rng.randf_range(0.2, 0.8)) / n_limbs)
		az += 2.39996 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(az), 0.0, sin(az))
		# The trunk's centerline at that height.
		var root := Vector3(0, y, 0)
		var r_here := r0 * lerpf(1.0, 0.22, y / top.y)
		var reach := env_r.x * lerpf(0.85, 0.55, (y - 0.46) / 0.38) * rng.randf_range(0.85, 1.1)
		var end := root + out * reach + Vector3(0, reach * rng.randf_range(0.7, 1.1), 0)
		var ctrl := root + (end - root) * 0.35 + Vector3(0, reach * 0.25, 0)
		var limb := Piece.new()
		limb.kind = Kind.LIMB
		limb.limb = l + 1
		limb.parent = trunk_i
		for t in LIMB_T:
			limb.add(root.lerp(ctrl, t).lerp(ctrl.lerp(end, t), t), r_here * 0.6 * lerpf(1.0, 0.5, t))
		var limb_i := sk.add(limb)
		var tone: int = [0, 2, 1][l % 3]
		sk.clumps.append([end + Vector3(0, clump_r.y * 0.3, 0), clump_r * rng.randf_range(0.9, 1.15), tone])
		if rng.randf() < 0.6:
			# A second clump off a short branch, inward and lower.
			var c2 := root + out.rotated(Vector3.UP, rng.randf_range(-0.9, 0.9)) * reach * 0.8 + Vector3(0, reach * 0.3, 0)
			var b_root := limb.pts[2]
			var branch := Piece.new()
			branch.kind = Kind.BRANCH
			branch.limb = l + 1
			branch.parent = limb_i
			var br := limb.rad[2] * 0.7
			branch.add(b_root, br)
			branch.add(b_root.lerp(c2, 0.5) + Vector3(0, 0.01, 0), br * 0.75)
			branch.add(c2, br * 0.45)
			sk.add(branch)
			sk.clumps.append([c2, clump_r * rng.randf_range(0.8, 1.0), (tone + 1) % 3])


# --- Fixed skeletons: trees without layouts --------------------------------------

## The wood of today's meshes (PlantMeshes._build), for trees without
## layouts: the trunk as drawn, a mangrove's stilt roots, and for plants
## you can't climb, solid shapes only.
static func _fixed(sp: PlantSpecies) -> Skeleton:
	var sk := Skeleton.new()
	match sp.shape:
		S.CONIFER:
			sk.add(_old_trunk(0.04, 0.3, 0.0))
		S.BROADLEAF:
			sk.add(_old_trunk(0.05, 0.62, 0.04))
		S.GNARLED:
			sk.add(_old_trunk(0.075, 0.42, 0.12))
		S.EMERGENT:
			sk.add(_old_trunk(0.03, 0.9, 0.03))
		S.UMBRELLA:
			sk.add(_old_trunk(0.045, 0.7, 0.06))
		S.CYPRESS:
			var t := _old_trunk(0.045, 0.62, 0.0)
			for k in t.pts.size():
				t.rad[k] = maxf(t.rad[k], 0.12 * (1.0 - t.pts[k].y / 0.25) * 0.8)
			sk.add(t)
		S.PALM:
			var axis := Vector3(0.08, 1, 0).normalized()
			var palm := Piece.new()
			palm.kind = Kind.TRUNK
			for f in [0.0, 0.5, 1.0]:
				palm.add(axis * 0.92 * f, 0.03)
			sk.add(palm)
		S.MANGROVE:
			var stem := Piece.new()
			stem.kind = Kind.TRUNK
			stem.add(Vector3(0, 0.28, 0), 0.04)
			stem.add(Vector3(0, 0.68, 0), 0.04)
			var stem_i := sk.add(stem)
			for k in 5:
				var a := TAU * k / 5.0
				var root := Piece.new()
				root.kind = Kind.ROOT
				root.limb = k + 1
				root.parent = stem_i
				root.add(Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), 0.02)
				root.add(Vector3(0, 0.3, 0), 0.02)
				sk.add(root)
		S.BAMBOO:
			# The tight clump of culms, as one post.
			sk.add(_solid([Vector3.ZERO, Vector3(0, 0.6, 0)], 0.05))
		S.ROSETTE:
			sk.add(_solid([Vector3.ZERO, Vector3(0, 0.75, 0)], 0.07))
		S.SPIKE_ROSETTE:
			# The leafy ball at the foot (only its fat middle, so the flat
			# ends stay inside the round ball), then the tapering spike.
			sk.add(_solid([Vector3(0, 0.03, 0), Vector3(0, 0.2, 0)], 0.17))
			var spike := _solid([Vector3(0, 0.22, 0), Vector3(0, 0.5, 0), Vector3(0, 0.8, 0)], 0.066)
			spike.rad[1] = 0.044
			spike.rad[2] = 0.019
			sk.add(spike)
		S.CACTUS:
			sk.add(_solid([Vector3.ZERO, Vector3(0, 1.0, 0)], 0.07))
			sk.add(_solid([Vector3(0.06, 0.4, 0), Vector3(0.24, 0.43, 0), Vector3(0.24, 0.73, 0)], 0.04))
			sk.add(_solid([Vector3(-0.06, 0.55, 0), Vector3(-0.2, 0.58, 0), Vector3(-0.2, 0.8, 0)], 0.035))
		_:
			var dims := PlantMeshes.tree_dims(sp.shape)
			sk.add(_solid([Vector3.ZERO, Vector3(0, dims.y, 0)], dims.x))
	return sk


## The old meshes' trunk: `h` tall, `r` at the foot tapering to 0.45 of it,
## bending by `bend`, flared at the foot.
static func _old_trunk(r: float, h: float, bend: float) -> Piece:
	var trunk := Piece.new()
	trunk.kind = Kind.TRUNK
	for k in TRUNK_T.size():
		var t: float = TRUNK_T[k]
		trunk.add(_trunk_at(t, h, bend), r * lerpf(1.0, 0.45, t) * float(TRUNK_FLARE[k]))
	return trunk


static func _solid(pts: Array, r: float) -> Piece:
	var p := Piece.new()
	p.kind = Kind.SOLID
	for q in pts:
		p.add(q, r)
	return p


# --- Colliders ------------------------------------------------------------------

## Collider shapes for a tree `h` meters tall, in its frame (meters):
## [a, b, radius, capsule] per shape, a cylinder or capsule from a to b.
## `near`: the limbs and thick branches (while the tree is in branch-graph
## range) instead of the trunk, roots and solid shapes. None at all for
## plants whose wood stays below knee height.
static func collider_segments(sk: Skeleton, h: float, mirrored: bool, near: bool) -> Array:
	var out: Array = []
	var top := 0.0
	for pc in sk.pieces:
		for q in pc.pts:
			top = maxf(top, q.y)
	if top * h < KNEE_M:
		return out
	var mx := Vector3(-1, 1, 1) if mirrored else Vector3.ONE
	for pc in sk.pieces:
		var is_near := pc.kind == Kind.LIMB or pc.kind == Kind.BRANCH
		if is_near != near:
			continue
		var n := pc.pts.size()
		if is_near:
			# Capsules (round ends where limbs meet): limbs in two (they
			# curve), branches in one, only wood thick enough to matter.
			var mean_r := 0.0
			for r in pc.rad:
				mean_r += r
			mean_r /= n
			if mean_r * h < LIMB_COLLIDER_R_M:
				continue
			var cuts := [0, n / 2, n - 1] if pc.kind == Kind.LIMB and n >= 5 else [0, n - 1]
			for k in cuts.size() - 1:
				var i0: int = cuts[k]
				var i1: int = cuts[k + 1]
				var r := (pc.rad[i0] + pc.rad[i1]) * 0.5 * COLLIDER_FIT * h
				out.append([pc.pts[i0] * mx * h, pc.pts[i1] * mx * h, r, true])
			continue
		# Trunks, roots and solid shapes: stacked cylinders (flat ends, so
		# nothing pokes out past the drawn wood) following the bend and the
		# taper, a new one wherever the radius would change by more than
		# 30% along it or the wood turns (a cactus arm), at most four per
		# piece (a flared foot takes two), each as thick as the wood halfway
		# along.
		var i0 := 0
		var made := 0
		for k in range(1, n):
			var cut := k == n - 1
			if not cut and made < 3:
				var r_next := pc.rad[k + 1]
				cut = maxf(pc.rad[i0], r_next) / maxf(minf(pc.rad[i0], r_next), 1e-6) > 1.3
				var d0 := (pc.pts[k] - pc.pts[i0]).normalized()
				var d1 := (pc.pts[k + 1] - pc.pts[k]).normalized()
				cut = cut or d0.dot(d1) < 0.94
			if not cut:
				continue
			var s_mid := (pc.arc[i0] + pc.arc[k]) * 0.5
			var r := float(pc.at(s_mid)[2]) * COLLIDER_FIT * h
			var a := pc.pts[i0] * mx * h
			var b := pc.pts[k] * mx * h
			if r >= 0.02 and a.distance_to(b) > 0.05:
				out.append([a, b, r, false])
			i0 = k
			made += 1
	return out


# --- Branch graphs ----------------------------------------------------------------

## Handholds per layout, in the unit frame: laid every ~SPACING_M along the
## wood for a tree of about this height, cached per 10% height step so the
## spacing stays within ~5% of SPACING_M on every tree. Returns
## [local, tangent, radius, limb, links] (links: Array of PackedInt32Array).
static func unit_handholds(sp_idx: int, layout: int, h: float) -> Array:
	var step := roundi(log(maxf(h, 0.5)) / log(1.1))
	var key := Vector3i(sp_idx, layout, step)
	_mutex.lock()
	var cached = _holds.get(key)
	_mutex.unlock()
	if cached != null:
		return cached
	var built := _lay_handholds(skeleton(sp_idx, layout), pow(1.1, step))
	_mutex.lock()
	if _holds.size() > 4000:
		_holds.clear()
	_holds[key] = built
	_mutex.unlock()
	return built


static func _lay_handholds(sk: Skeleton, hb: float) -> Array:
	var spacing := BranchGraph.SPACING_M / hb
	var min_r := BranchGraph.MIN_RADIUS_M / hb
	var local := PackedVector3Array()
	var tangent := PackedVector3Array()
	var radius := PackedFloat32Array()
	var limb := PackedInt32Array()
	var links: Array = []
	var first := PackedInt32Array()
	var last := PackedInt32Array()
	for pi in sk.pieces.size():
		var pc: Piece = sk.pieces[pi]
		first.append(-1)
		last.append(-1)
		if pc.kind == Kind.SOLID:
			continue
		var s := 0.0
		match pc.kind:
			Kind.TRUNK:
				s = maxf(0.4 / hb - pc.pts[0].y, 0.0)
			Kind.ROOT:
				s = spacing * 0.5
			_:
				# Just outside the parent's wood.
				var parent: Piece = sk.pieces[pc.parent]
				s = _radius_near(parent, pc.join) + spacing * 0.25
		var total := pc.length()
		var prev := -1
		while s <= total + 1e-6:
			var q := pc.at(s)
			if float(q[2]) < min_r:
				break
			var i := local.size()
			local.append(q[0])
			tangent.append(q[1])
			radius.append(q[2])
			limb.append(pc.limb)
			links.append([])
			if prev >= 0:
				(links[prev] as Array).append(i)
				(links[i] as Array).append(prev)
			else:
				first[pi] = i
			last[pi] = i
			prev = i
			s += spacing
	# Across each fork: the child's handhold at the joint to the parent's
	# handhold nearest the joint.
	for pi in sk.pieces.size():
		var pc: Piece = sk.pieces[pi]
		if pc.parent < 0 or first[pi] < 0 or first[pc.parent] < 0:
			continue
		var mine := last[pi] if pc.kind == Kind.ROOT else first[pi]
		var best := -1
		var best_d := INF
		for i in range(first[pc.parent], last[pc.parent] + 1):
			var d := local[i].distance_squared_to(pc.join)
			if d < best_d:
				best_d = d
				best = i
		if best >= 0:
			(links[mine] as Array).append(best)
			(links[best] as Array).append(mine)
	var packed: Array = []
	for l in links:
		packed.append(PackedInt32Array(l))
	return [local, tangent, radius, limb, packed]


## The wood's radius on piece `pc` at its point nearest `p`.
static func _radius_near(pc: Piece, p: Vector3) -> float:
	var best := 0
	var best_d := INF
	for i in pc.pts.size():
		var d := pc.pts[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return pc.rad[best]


## A tree's branch graph: its layout's handholds scaled to its height
## (meters), mirrored if it is, thinner wood than MIN_RADIUS_M dropped.
## Null if it has no wood to hold. The caller sets key, chunk and xform.
static func graph(sp_idx: int, pick_v: int, h: float) -> BranchGraph:
	var layout := layout_of(pick_v)
	var mirrored := is_mirrored(pick_v)
	var unit := unit_handholds(sp_idx, layout, h)
	var u_local: PackedVector3Array = unit[0]
	var u_tan: PackedVector3Array = unit[1]
	var u_rad: PackedFloat32Array = unit[2]
	var u_limb: PackedInt32Array = unit[3]
	var u_links: Array = unit[4]
	if u_local.is_empty():
		return null
	var g := BranchGraph.new()
	g.species = sp_idx
	g.height_m = h
	var mx := Vector3(-1, 1, 1) if mirrored else Vector3.ONE
	var remap := PackedInt32Array()
	remap.resize(u_local.size())
	for i in u_local.size():
		if u_rad[i] * h < BranchGraph.MIN_RADIUS_M:
			remap[i] = -1
			continue
		remap[i] = g.local.size()
		g.local.append(u_local[i] * mx * h)
		g.tangent.append(u_tan[i] * mx)
		g.radius.append(u_rad[i] * h)
		g.limb.append(u_limb[i])
	if g.local.is_empty():
		return null
	for i in u_local.size():
		if remap[i] < 0:
			continue
		var out := PackedInt32Array()
		for j in (u_links[i] as PackedInt32Array):
			if remap[j] >= 0:
				out.append(remap[j])
		g.links.append(out)
	return g
