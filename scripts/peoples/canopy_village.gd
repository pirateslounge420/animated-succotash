class_name CanopyVillage
extends RefCounted
## The canopy folk's village (design 30 Sept §BT, data/peoples/canopy.json):
## platforms lashed in the crotches of the stand's giants 8–15 m up, vine
## bridges between them, a clay hearth box on the first deck (fire kept
## on wood), the woodpile a bundle under the eaves. No ladder comes down
## for a stranger: the player climbs the trunk (§AU) and lets go onto the
## deck; once the headman has met them the rope ladder hangs from the
## first deck (Camps shows it, Main climbs it). Everything is built in the
## camp root's frame (+Y up, the decks level with the ground) on the REAL
## giants of the chunk (TerrainChunk.trees), never a prop tree. The trunk
## passes through a hole in each deck, so the climb goes on past it.

## The site rule (biome_map.json canopy): giants within this of the site.
const SEARCH_M := 60.0
const MIN_GIANTS := 3
const MAX_DECKS := 4
## A vine bridge spans at most this; decks at least this apart.
const BRIDGE_MAX_M := 34.0
const DECK_MIN_APART_M := 7.0
## The deck's height up the trunk (m), by the tree's height, clamped.
const DECK_Y := Vector2(8.0, 15.0)
const PLANK_STEP_M := 0.55
const ROPE := Color(0.46, 0.38, 0.24)
const CLAY := Color(0.55, 0.42, 0.3)


## Giants within `radius_m` of scene point `at`, tallest first, each
## [chunk, i, height, base (scene)]. A giant is a branchy, climbable tree
## taller than its species' band (stand.json's giant roll) or over 26 m.
static func giants_near(chunks: ChunkManager, at: Vector3, radius_m: float) -> Array:
	var out: Array = []
	for key in chunks.chunks:
		var chunk: TerrainChunk = chunks.chunks[key]
		if chunk.trees.is_empty():
			continue
		for i in chunk.trees.size():
			var t: Array = chunk.trees[i]
			var base: Vector3 = chunk.global_position + (t[0] as Vector3)
			if base.distance_to(at) > radius_m:
				continue
			var h := float(t[1])
			if t.size() < 7 or int(t[4]) < 0:
				continue # no branch layout: nothing to lash to, nothing to climb
			var sp := chunk.tree_species(i)
			if not PlantMeshes.climbable(sp.shape):
				continue
			if h < sp.height_m.y * 1.02 and h < 26.0:
				continue
			out.append([chunk, i, h, base])
	out.sort_custom(func(a, b): return a[2] > b[2])
	return out


## Build the village under `root` (the camp's node, its basis north/up at
## the site) with collision on `body`. Returns {} when the stand has no
## three giants within reach (Camps then waits for the chunk's trees), else
## decks, the hearth and fire positions, seats ({pos, face}), the store
## positions, the ladder node (hidden) and its ends, all root-local.
static func build(root: Node3D, world: Node, chunks: ChunkManager, at: Vector3, pal: Array, rng: RandomNumberGenerator, biome_key: String, body: StaticBody3D) -> Dictionary:
	var giants := giants_near(chunks, at, SEARCH_M)
	var picked: Array = []
	for g in giants:
		if picked.size() >= MAX_DECKS:
			break
		var ok := picked.is_empty()
		for p in picked:
			var dm: float = (p[3] as Vector3).distance_to(g[3])
			if dm < DECK_MIN_APART_M:
				ok = false
				break
			if dm <= BRIDGE_MAX_M:
				ok = true
		if ok:
			picked.append(g)
	if picked.size() < MIN_GIANTS:
		return {}
	var inv := root.global_transform.affine_inverse()
	var wood := Color(0.45, 0.33, 0.2).lerp(pal[0] if pal.size() > 0 else Color(0.5, 0.4, 0.3), 0.35)
	var leaf := Color(0.3, 0.42, 0.2).lerp(pal[1] if pal.size() > 1 else Color(0.35, 0.45, 0.25), 0.3)
	var walls := biome_key in ["CLOUD_FOREST", "TEMPERATE_DECIDUOUS"]
	# The decks: where each trunk is at its deck's height, level with the
	# ground, a hole for the trunk.
	var decks: Array = []
	for g in picked:
		var chunk: TerrainChunk = g[0]
		var i: int = g[1]
		var h: float = g[2]
		var base: Vector3 = inv * (g[3] as Vector3)
		var up: Vector3 = (inv.basis * chunk.tree_up(i)).normalized()
		var y := clampf(h * 0.42, DECK_Y.x, DECK_Y.y) + rng.randf_range(-0.6, 0.6)
		var r_t := clampf(h * 0.016, 0.25, 1.1)
		decks.append({"center": base + up * y, "up": up, "r_t": r_t, "R": r_t + rng.randf_range(2.2, 2.8), "openings": [], "tree": [chunk, i], "base": base})
	# Round the ring by angle about their middle; bridges between
	# neighbours, the ring closed when the last gap is short enough.
	var mid := Vector3.ZERO
	for dk in decks:
		mid += dk.center
	mid /= decks.size()
	decks.sort_custom(func(a, b): return atan2((a.center - mid).z, (a.center - mid).x) < atan2((b.center - mid).z, (b.center - mid).x))
	var n := decks.size()
	var bridges := 0
	for k in n:
		var j := (k + 1) % n
		if j == 0 and n < 3:
			break
		var a: Dictionary = decks[k]
		var b: Dictionary = decks[j]
		var dv: Vector3 = b.center - a.center
		dv.y = 0.0
		if dv.length() > BRIDGE_MAX_M + 6.0:
			continue
		var dir := dv.normalized()
		var pa: Vector3 = a.center + dir * _edge(a, dir) + Vector3.UP * 0.07
		var pb: Vector3 = b.center - dir * _edge(b, -dir) + Vector3.UP * 0.07
		pa.y = float(a.center.y) + 0.07
		pb.y = float(b.center.y) + 0.07
		(a.openings as Array).append(dir)
		(b.openings as Array).append(-dir)
		_bridge(root, body, pa, pb, a, b, rng)
		bridges += 1
	for dk in decks:
		_deck(root, body, dk, wood, leaf, walls, rng)
	# The hearth box on the first deck, away from its first bridge; the
	# fire sits in it; seats round it; the store beside it, small.
	var first: Dictionary = decks[0]
	var open_dir: Vector3 = (first.openings as Array)[0] if not (first.openings as Array).is_empty() else Vector3(1, 0, 0)
	var back := -open_dir
	# Keep the hearth on a strip of the ring (toward a side, not a corner).
	if absf(back.x) > absf(back.z):
		back = Vector3(signf(back.x), 0, 0)
	else:
		back = Vector3(0, 0, signf(back.z))
	var hearth: Vector3 = (first.center as Vector3) + back * (float(first.r_t) + 1.25)
	hearth.y = float(first.center.y)
	var hb := CreatureBodies.box(root, Vector3(1.7, 0.3, 1.7), hearth + Vector3.UP * 0.21, CLAY)
	hb.name = "HearthBox"
	PropCollision.box(body, Transform3D(Basis(), hearth + Vector3.UP * 0.21), Vector3(1.7, 0.3, 1.7))
	var fire_pos := hearth + Vector3.UP * 0.36
	var perp := Vector3(-back.z, 0, back.x)
	var seats: Array = []
	for ang in [0.9, -0.9, 2.3, -2.3]:
		var off := (back * cos(ang) + perp * sin(ang)) * 1.15
		seats.append({"pos": hearth + off + Vector3.UP * 0.06, "face": -off.normalized()})
	for k in range(1, n):
		var dk: Dictionary = decks[k]
		var od: Vector3 = (dk.openings as Array)[0] if not (dk.openings as Array).is_empty() else Vector3(1, 0, 0)
		var bk := -od
		if absf(bk.x) > absf(bk.z):
			bk = Vector3(signf(bk.x), 0, 0)
		else:
			bk = Vector3(0, 0, signf(bk.z))
		var pp := Vector3(-bk.z, 0, bk.x)
		for s in [-0.8, 0.8]:
			var sp: Vector3 = dk.center + bk * (float(dk.r_t) + 1.3) + pp * s
			sp.y = float(dk.center.y) + 0.06
			var face: Vector3 = hearth - sp
			face.y = 0.0
			seats.append({"pos": sp, "face": face.normalized() if face.length() > 0.01 else bk})
	var store_pos := hearth + perp * 1.7 + Vector3.UP * 0.06
	var food_pos := hearth - perp * 1.7 + Vector3.UP * 0.06
	# The rope ladder from the hearth deck's outer edge, hidden until the
	# headman has met the player (Camps shows it).
	var edge: Vector3 = first.center + back * (float(first.R) - 0.15)
	edge.y = float(first.center.y)
	var gdir: Vector3 = world.dir_of(root.to_global(edge))
	var foot: Vector3 = inv * world.to_scene(gdir, PlanetConst.RADIUS_M + chunks.ground_height(gdir))
	var ladder := _ladder(root, foot, edge, back, rng)
	return {"decks": decks, "bridges": bridges, "hearth": hearth, "fire_pos": fire_pos, "seats": seats,
		"store_pos": store_pos, "food_pos": food_pos, "ladder": ladder, "ladder_foot": foot, "ladder_top": edge, "first": first.tree}


## How far from a deck's centre its square edge lies along `dir` (y ignored).
static func _edge(dk: Dictionary, dir: Vector3) -> float:
	var m := maxf(absf(dir.x), absf(dir.z))
	return float(dk.R) / maxf(m, 0.2)


## A deck: four plank strips round the trunk's hole, props down to the
## trunk, rail posts and rope rails (a gap where a bridge leaves), a leaf
## roof over the back half on posts, and bark walls there in the cold.
static func _deck(root: Node3D, body: StaticBody3D, dk: Dictionary, wood: Color, leaf: Color, walls: bool, rng: RandomNumberGenerator) -> void:
	var c: Vector3 = dk.center
	var r_t := float(dk.r_t) + 0.05
	var R := float(dk.R)
	var w := R - r_t
	var th := 0.12
	var strips := [
		[Vector3(0, 0, (R + r_t) * 0.5), Vector3(2.0 * R, th, w)],
		[Vector3(0, 0, -(R + r_t) * 0.5), Vector3(2.0 * R, th, w)],
		[Vector3((R + r_t) * 0.5, 0, 0), Vector3(w, th, 2.0 * r_t)],
		[Vector3(-(R + r_t) * 0.5, 0, 0), Vector3(w, th, 2.0 * r_t)],
	]
	for s in strips:
		var pos: Vector3 = c + (s[0] as Vector3) - Vector3.UP * th * 0.5
		var size: Vector3 = s[1]
		var mi := CreatureBodies.box(root, size, pos, wood.lightened(rng.randf_range(-0.05, 0.05)))
		mi.name = "Deck"
		PropCollision.box(body, Transform3D(Basis(), pos), size)
	# Props: from under the deck's corners and sides down to the trunk.
	var tup: Vector3 = dk.up
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var from := c + Vector3(cos(a), 0, sin(a)) * (R - 0.4) - Vector3.UP * th
		var to := c - tup * rng.randf_range(2.4, 3.2) + Vector3(cos(a), 0, sin(a)) * (r_t - 0.2)
		_pole(root, from, to, 0.06, wood.darkened(0.2))
	# Rails: posts at the corners and the sides' middles, rope between,
	# none across an opening.
	var posts: Array = []
	for k in 8:
		var a := TAU * k / 8.0
		var m := maxf(absf(cos(a)), absf(sin(a)))
		var p := c + Vector3(cos(a), 0, sin(a)) * (R - 0.12) / m
		posts.append(p)
		_pole(root, p, p + Vector3.UP * 0.95, 0.035, wood.darkened(0.1))
	for k in posts.size():
		var p0: Vector3 = posts[k]
		var p1: Vector3 = posts[(k + 1) % posts.size()]
		var m := (p0 + p1) * 0.5
		var open := false
		for od in dk.openings:
			var ep := c + (od as Vector3) * _edge(dk, od)
			if ep.distance_to(m) < R * 0.5:
				open = true
		if open:
			continue
		_rope(root, p0 + Vector3.UP * 0.92, p1 + Vector3.UP * 0.92)
		_rope(root, p0 + Vector3.UP * 0.5, p1 + Vector3.UP * 0.5)
	# The roof over the back half (away from the first opening), posts at
	# its corners; bark walls on its two outer sides in the cold.
	var od0: Vector3 = (dk.openings as Array)[0] if not (dk.openings as Array).is_empty() else Vector3(1, 0, 0)
	var bk := -od0
	if absf(bk.x) > absf(bk.z):
		bk = Vector3(signf(bk.x), 0, 0)
	else:
		bk = Vector3(0, 0, signf(bk.z))
	var pp := Vector3(-bk.z, 0, bk.x)
	var rc: Vector3 = c + bk * (r_t + w * 0.5)
	var roof_h := 2.15
	for sx in [-1.0, 1.0]:
		for sz in [0.15, 0.95]:
			var pcol: Vector3 = rc + pp * sx * (R * 0.92) + bk * (w * sz - w * 0.5)
			_pole(root, pcol, pcol + Vector3.UP * roof_h, 0.045, wood.darkened(0.15))
	var roof := CreatureBodies.box(root, Vector3(2.0 * R * 0.96, 0.08, w * 0.95), rc + Vector3.UP * (roof_h + 0.04), leaf)
	roof.name = "Roof"
	roof.rotation.x = -0.12 * signf(bk.z) if absf(bk.z) > 0.5 else 0.0
	roof.rotation.z = 0.12 * signf(bk.x) if absf(bk.x) > 0.5 else 0.0
	if walls:
		var bark := wood.darkened(0.3)
		var wall_c: Vector3 = rc + bk * (w * 0.5 - 0.06)
		CreatureBodies.box(root, Vector3(2.0 * R * 0.9, 1.0, 0.08) if absf(bk.z) > 0.5 else Vector3(0.08, 1.0, 2.0 * R * 0.9), wall_c + Vector3.UP * 0.5, bark)
		for sx in [-1.0, 1.0]:
			var side_c: Vector3 = rc + pp * sx * (R * 0.9)
			CreatureBodies.box(root, Vector3(0.08, 1.0, w * 0.9) if absf(bk.z) > 0.5 else Vector3(w * 0.9, 1.0, 0.08), side_c + Vector3.UP * 0.5, bark)


## A vine bridge from `a` to `b` (deck edges, root-local): planks along a
## sagging line, each with its collision, rope rails a metre up, a cable
## from each end up to the trunk above it.
static func _bridge(root: Node3D, body: StaticBody3D, a: Vector3, b: Vector3, da: Dictionary, db: Dictionary, rng: RandomNumberGenerator) -> void:
	var len_m := a.distance_to(b)
	var n := maxi(2, int(ceil(len_m / PLANK_STEP_M)))
	var sag := 0.05 * len_m + 0.2
	var flat := b - a
	flat.y = 0.0
	var side := flat.normalized().cross(Vector3.UP).normalized()
	var pts: Array = []
	for k in n + 1:
		var t := float(k) / n
		pts.append(a.lerp(b, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t))
	var plank := Color(0.5, 0.38, 0.22)
	for k in n:
		var p0: Vector3 = pts[k]
		var p1: Vector3 = pts[k + 1]
		var dv := p1 - p0
		var mid := (p0 + p1) * 0.5
		var basis := Basis.looking_at(dv.normalized(), Vector3.UP)
		var size := Vector3(0.9, 0.05, dv.length() + 0.03)
		var mi := CreatureBodies.box(root, size, mid, plank.lightened(rng.randf_range(-0.08, 0.08)))
		mi.name = "Plank"
		mi.basis = basis
		PropCollision.box(body, Transform3D(basis, mid), size)
		# Rails: rope every second plank, a drop to the plank every fourth.
		if k % 2 == 0 and k + 2 <= n:
			var p2: Vector3 = pts[k + 2]
			for s in [-0.45, 0.45]:
				_rope(root, p0 + side * s + Vector3.UP * 1.0, p2 + side * s + Vector3.UP * 1.0)
		if k % 4 == 2:
			for s in [-0.45, 0.45]:
				_rope(root, p0 + side * s + Vector3.UP * 0.02, p0 + side * s + Vector3.UP * 1.0)
	# Cables up to the trunks: the bridge hangs from above as much as it
	# bears on the decks.
	_rope(root, a + Vector3.UP * 1.0, (da.base as Vector3) + (da.up as Vector3) * (float(da.center.y) - float(da.base.y) + 4.5))
	_rope(root, b + Vector3.UP * 1.0, (db.base as Vector3) + (db.up as Vector3) * (float(db.center.y) - float(db.base.y) + 4.5))


## The rope ladder from the first deck's edge to the ground: two ropes, a
## rung every 0.4 m; hidden until the headman has met the player. Its
## node sits at the foot; meta top_local is the deck edge, in_local the
## way onto the deck.
static func _ladder(root: Node3D, foot: Vector3, top: Vector3, out_dir: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var lad := Node3D.new()
	lad.name = "RopeLadder"
	root.add_child(lad)
	# Hangs straight down from the edge, a little out from it.
	var hang_top := top + out_dir * 0.35
	var hang_foot := Vector3(hang_top.x, foot.y, hang_top.z)
	lad.position = hang_foot
	var h := hang_top.y - hang_foot.y
	var side := Vector3(-out_dir.z, 0, out_dir.x)
	for s in [-0.25, 0.25]:
		_rope(lad, side * s, side * s + Vector3.UP * h, 0.028)
	var y := 0.35
	while y < h - 0.2:
		var rung := CreatureBodies.box(lad, Vector3(0.6, 0.04, 0.05), Vector3.UP * y, Color(0.48, 0.36, 0.22).lightened(rng.randf_range(-0.05, 0.05)))
		rung.basis = Basis.looking_at(out_dir, Vector3.UP)
		y += 0.4
	lad.set_meta("top_local", Vector3.UP * h - out_dir * 1.1)
	lad.set_meta("foot_local", -out_dir * 0.7)
	lad.set_meta("height", h)
	lad.visible = false
	return lad


static func _pole(parent: Node3D, a: Vector3, b: Vector3, r: float, c: Color) -> void:
	var dv := b - a
	var l := dv.length()
	if l < 0.05:
		return
	var m := CreatureBodies.cone(parent, r, r * 0.85, snappedf(l, 0.1), (a + b) * 0.5, c, 0.0, 6)
	m.basis = _along(dv / l)


static func _rope(parent: Node3D, a: Vector3, b: Vector3, r := 0.022) -> void:
	var dv := b - a
	var l := dv.length()
	if l < 0.05:
		return
	var m := CreatureBodies.cone(parent, r, r, snappedf(l, 0.1), (a + b) * 0.5, ROPE, 0.0, 5)
	m.basis = _along(dv / l)


## A basis whose +Y runs along `dir`.
static func _along(dir: Vector3) -> Basis:
	var x := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(dir).normalized()
	return Basis(x, dir, z)
