class_name VillageBuilder
extends RefCounted
## A village built from its plan (design 5 Oct §EE.3, §EG.3; data/villages.json
## build). Pure and thread-safe: compute() reads the planet and the plan
## and returns arrays (VillageLife runs it on a worker); make_node() turns
## them into nodes on the main thread.
##
## Built with the land, never on a flattened pad (§EE.3): the ground is
## never touched. Each house's floor is level at the top of its plot plus
## a step, and what holds it up follows the fall across its footprint:
##   under plinth_max_m   a stone plinth;
##   under stepped_max_m  stepped foundations (the footing steps down the
##                        slope in courses) with a dry-stone (mortarless)
##                        apron below, gaps left for water to weep through;
##   beyond               a timber floor on posts, each its own length,
##                        each on a foundation stone (posts on stones: one
##                        of the lost techniques, §EE.3).
## Steps up to every door that stands above its lane. One stone, one
## timber, one roof per village (§EG.3, plan.materials); every block
## varies a little in tone and lean, roofs sag, some are holed, moss
## climbs the walls, ivy hangs over doors: weathered, a thousand years old
## (wabi-sabi). The dead village's squares are choked with brambles along
## their walls (§EG.4) until their hearth burns; their benches come back
## when it does (VillageLife).
##
## Node frame: x and z the plan's, y up from the site's ground (the
## planet's curve taken off), placed like a ruin (placement()).

static var BLD: Dictionary = Tuning.section("villages", "build")

const STONE := 0
const WOOD := 1
const THATCH := 3
const LEAVES := 4

var plan: VillagePlan
var rng := RandomNumberGenerator.new()
var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _m := PackedVector2Array()
var _boxes: Array = [] # collision: [Transform3D, Vector3]
## What each piece was made of (§EG.3 check): category -> {name: pieces}.
var used := {"stone": {}, "timber": {}, "roof": {}}
var stone_col := Color(0.44, 0.48, 0.54)
var timber_col := Color(0.34, 0.27, 0.2)
var roof_col := Color(0.24, 0.27, 0.33)
var roof_kind := STONE
var moisture := 0.5
## Per house: {kind, fall, floor, posts: [lengths], chimney: Vector3}
var footings: Array = []
## Per hearth (plan.hearths order): its spot in the node frame.
var hearth_local: Array = []
var _win: Array = [] # per house: arrays of the lit windows
var _bramble: Array = [] # per square: [arrays, boxes]
var _benches: Array = [] # per square: arrays
var _wv := PackedVector3Array()
var _wuv := PackedVector2Array()
var _wuv2 := PackedVector2Array()


static func compute(map: PlanetData, site: Dictionary) -> Dictionary:
	var b := VillageBuilder.new()
	b.plan = Villages.plan_of(map, site)
	b.rng.seed = hash([site.seed, "build"])
	b._build()
	return {"v": b._v, "n": b._n, "c": b._c, "m": b._m, "boxes": b._boxes, "site": site, "used": b.used,
		"footings": b.footings, "hearths": b.hearth_local, "win": b._win, "bramble": b._bramble, "bench": b._benches,
		"water": {"v": b._wv, "uv": b._wuv, "uv2": b._wuv2}, "up": b.plan.up, "ex": b.plan.ex, "ez": b.plan.ez, "base_e": b.plan.base_e}


static func placement(data: Dictionary, world: Node) -> Transform3D:
	return Transform3D(Basis(data.ex, data.up, data.ez), world.to_scene(data.up, PlanetConst.RADIUS_M + float(data.base_e)))


# --- Ground ----------------------------------------------------------------------

## The ground at plan point `q` in the node's frame (the planet's curve off).
func gy(q: Vector2) -> float:
	return plan.true_ground(q) - q.length_squared() / (2.0 * PlanetConst.RADIUS_M)


# --- Primitives ------------------------------------------------------------------

func _tri(a: Vector3, b: Vector3, c: Vector3, nrm: Vector3, col: Color, kind: int) -> void:
	_v.append_array([a, b, c])
	_n.append_array([nrm, nrm, nrm])
	_c.append_array([col, col, col])
	var uv := Vector2(kind, 0.0)
	_m.append_array([uv, uv, uv])


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, kind: int) -> void:
	var nrm := (b - a).cross(c - a).normalized()
	_tri(a, b, c, nrm, col, kind)
	_tri(a, c, d, nrm, col, kind)


## A box: centre `o`, axes `x`, `y`, `z` (unit), full `size`; vertex alpha
## `moss`. Its outward normals; no bottom face unless `bottom`.
func box(o: Vector3, x: Vector3, y: Vector3, z: Vector3, size: Vector3, col: Color, kind: int, moss := 0.15, bottom := false, collide := false) -> void:
	var h := size * 0.5
	var c := col
	c.a = moss
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(o + x * (h.x if i & 1 else -h.x) + y * (h.y if i & 2 else -h.y) + z * (h.z if i & 4 else -h.z))
	# Faces as corner indices, each with its outward axis.
	var faces := [[[1, 3, 7, 5], x], [[0, 4, 6, 2], -x], [[2, 6, 7, 3], y], [[0, 1, 5, 4], -y], [[4, 5, 7, 6], z], [[0, 2, 3, 1], -z]]
	for f in faces:
		var nrm: Vector3 = f[1]
		if nrm == -y and not bottom:
			continue
		var q: Array = f[0]
		var shade := c
		# Contact shade low on the sides (RuinBuilder's cavity, roughly).
		_tri(corners[q[0]], corners[q[1]], corners[q[2]], nrm, shade, kind)
		_tri(corners[q[0]], corners[q[2]], corners[q[3]], nrm, shade, kind)
	if collide:
		_boxes.append([Transform3D(Basis(x, y, z), o), size])


## An upright box standing from `y0` to `y1` at plan point `q`, its width
## along `u` (plan) and depth along `v`.
func pillar(q: Vector2, u: Vector2, v: Vector2, w: float, d: float, y0: float, y1: float, col: Color, kind: int, moss := 0.15, collide := false, lean := 0.0) -> void:
	var x := Vector3(u.x, 0.0, u.y)
	var z := Vector3(v.x, 0.0, v.y)
	var y := Vector3.UP
	if lean != 0.0:
		y = y.rotated(x, lean)
		z = x.cross(y).normalized() * signf(z.dot(x.cross(Vector3.UP)) if z.dot(x.cross(Vector3.UP)) != 0.0 else 1.0)
	box(Vector3(q.x, (y0 + y1) * 0.5, q.y), x, y, z, Vector3(w, y1 - y0, d), col, kind, moss, false, collide)


func _jit(col: Color, amount := 0.06) -> Color:
	var k := 1.0 + rng.randf_range(-amount, amount)
	return Color(col.r * k, col.g * k, col.b * k, col.a)


func _use(cat: String, name: String) -> void:
	used[cat][name] = int(used[cat].get(name, 0)) + 1


# --- The village -----------------------------------------------------------------

func _build() -> void:
	var mat: Dictionary = plan.materials
	stone_col = Color(str((BLD.get("stones", {}) as Dictionary).get(mat.stone, "#6F7A8A")))
	timber_col = Color(str((BLD.get("timbers", {}) as Dictionary).get(mat.timber, "#59473A")))
	roof_col = Color(str((BLD.get("roofs", {}) as Dictionary).get(mat.roof, "#3C4553")))
	roof_kind = THATCH if mat.roof == "thatch" else STONE
	moisture = float(plan.map.moisture[plan.map.cell_at(plan.up)])
	for i in plan.houses.size():
		_house(i)
	_tower()
	_paving()
	_squares()
	_thresholds()
	_wall()
	_gutter()
	_focals()
	_edges()
	_rim_walls()
	_void()
	_mound()
	_hearth_spots()


## How much moss at height `y` over the ground (more low down, more in wet
## country: wabi-sabi).
func _moss(rise: float) -> float:
	return clampf((0.25 + moisture * 0.45) * (1.0 - rise / 4.0) + rng.randf_range(-0.08, 0.08), 0.02, 0.85)


func _house(i: int) -> void:
	var h: Dictionary = plan.houses[i]
	var c: Vector2 = h.c
	var u: Vector2 = h.u
	var v: Vector2 = h.v
	var w := float(h.w)
	var d := float(h.d)
	var hr := RandomNumberGenerator.new()
	hr.seed = int(h.seed)
	# The ground under it.
	var lo := INF
	var hi := -INF
	var samples := {}
	for sx: float in [-0.5, 0.0, 0.5]:
		for sz: float in [-0.5, 0.0, 0.5]:
			var q: Vector2 = c + u * w * sx + v * d * sz
			var g := gy(q)
			samples[Vector2(sx, sz)] = g
			lo = minf(lo, g)
			hi = maxf(hi, g)
	var fall := hi - lo
	var floor_y := hi + 0.15
	var kind := "plinth" if fall < float(BLD.get("plinth_max_m", 0.45)) else ("stepped" if fall < float(BLD.get("stepped_max_m", 1.6)) else "posts")
	var rec := {"kind": kind, "fall": fall, "floor": floor_y, "ground_lo": lo, "ground_hi": hi, "posts": []}
	var x3 := Vector3(u.x, 0, u.y)
	var z3 := Vector3(v.x, 0, v.y)
	match kind:
		"plinth":
			pillar(c, u, v, w + 0.2, d + 0.2, lo - 0.3, floor_y, _jit(stone_col.darkened(0.08)), STONE, _moss(0.0), true)
			_use("stone", plan.materials.stone)
		"stepped":
			# The footing steps down the slope: strips across the fall, each
			# down to its own ground.
			var gx := (float(samples[Vector2(0.5, 0.0)]) - float(samples[Vector2(-0.5, 0.0)]))
			var gz := (float(samples[Vector2(0.0, 0.5)]) - float(samples[Vector2(0.0, -0.5)]))
			var along_u := absf(gx) > absf(gz)
			var n := 3
			for k in n:
				var t := (k + 0.5) / n - 0.5
				var sc: Vector2 = c + (u * w * t if along_u else v * d * t)
				var slo := INF
				for e: float in [-0.5, 0.5]:
					var sq: Vector2 = sc + (u * w / n * e if along_u else v * d / n * e)
					for f: float in [-0.5, 0.5]:
						slo = minf(slo, gy(sq + (v * d * f if along_u else u * w * f)))
				var sw := (w / n + 0.05) if along_u else (w + 0.2)
				var sd := (d + 0.2) if along_u else (d / n + 0.05)
				pillar(sc, u, v, sw, sd, slo - 0.3, floor_y, _jit(stone_col.darkened(0.06)), STONE, _moss(0.0), true)
			# A dry-stone apron on the low side, coursed and gappy.
			var low_dir := (-u if gx > 0.0 else u) if along_u else (-v if gz > 0.0 else v)
			var side_len := d if along_u else w
			var side_ax := v if along_u else u
			var half := (w if along_u else d) * 0.5
			var base: Vector2 = c + low_dir * (half + 0.35)
			var courses := maxi(1, int((floor_y - (lo - 0.2)) / 0.32))
			for cr in courses:
				var y0 := lo - 0.2 + cr * 0.32
				var s := -side_len * 0.5
				while s < side_len * 0.5:
					var bl := hr.randf_range(0.45, 0.8)
					if hr.randf() > 0.07:
						var bq: Vector2 = base + side_ax * (s + bl * 0.5) - low_dir * cr * 0.04
						pillar(bq, side_ax, low_dir, bl - 0.04, 0.5, y0, y0 + 0.3, _jit(stone_col, 0.1), STONE, _moss(cr * 0.3))
					s += bl
			_use("stone", plan.materials.stone)
		"posts":
			# A timber deck on posts of their own lengths, each on a stone.
			var deck := 0.25
			pillar(c, u, v, w + 0.3, d + 0.3, floor_y - deck, floor_y, _jit(timber_col), WOOD, 0.1, true)
			_use("timber", plan.materials.timber)
			var nx := 3
			var nz := 3
			for a in nx:
				for b in nz:
					var pq: Vector2 = c + u * w * (float(a) / (nx - 1) - 0.5) * 0.92 + v * d * (float(b) / (nz - 1) - 0.5) * 0.92
					var g := gy(pq)
					var plen := floor_y - deck - g
					if plen < 0.15:
						continue
					rec.posts.append(plen)
					pillar(pq, u, v, 0.55, 0.55, g - 0.2, g + 0.12, _jit(stone_col), STONE, _moss(0.0))
					pillar(pq, u, v, 0.24, 0.24, g + 0.1, floor_y - deck, _jit(timber_col, 0.1), WOOD, 0.2, true, hr.randf_range(-0.02, 0.02))
			_use("stone", plan.materials.stone)
	# The floor inside.
	pillar(c, u, v, w - 0.5, d - 0.5, floor_y - 0.08, floor_y + 0.02, _jit(timber_col.darkened(0.15)), WOOD, 0.05)
	_use("timber", plan.materials.timber)
	# Walls: stone, 0.45 thick, the door on the front (toward the lane).
	var eave_r: Array = BLD.get("eave_m", [2.6, 3.1])
	var eave := hr.randf_range(float(eave_r[0]), float(eave_r[1])) + (float(BLD.get("focal_raise_m", 0.9)) if h.focal else 0.0)
	# A house that leads its view has an upper storey (VillagePlan's
	# hierarchy pass, §EG.2).
	var upper := int(h.get("storeys", 1)) == 2
	if upper:
		eave += 2.4
	# A quiet house beside a view's main one sits lower (§EG.2).
	if bool(h.get("quiet", false)):
		eave = maxf(eave - 0.35, 2.45)
	var top := floor_y + eave
	var t := 0.45
	var door_w := 1.2
	var door_h := 2.05
	var lean := hr.randf_range(-0.012, 0.012)
	var wall_col := _jit(stone_col)
	# Back and sides.
	pillar(c + v * (d * 0.5 - t * 0.5), u, v, w, t, floor_y, top, wall_col, STONE, _moss(0.5), true, lean)
	pillar(c - u * (w * 0.5 - t * 0.5), v, u, d - 2.0 * t, t, floor_y, top, wall_col, STONE, _moss(0.5), true)
	pillar(c + u * (w * 0.5 - t * 0.5), v, u, d - 2.0 * t, t, floor_y, top, wall_col, STONE, _moss(0.5), true)
	# Front, either side of the door, and over it.
	var fq: Vector2 = c - v * (d * 0.5 - t * 0.5)
	var side_w := (w - door_w) * 0.5
	pillar(fq - u * (door_w * 0.5 + side_w * 0.5), u, v, side_w, t, floor_y, top, wall_col, STONE, _moss(0.5), true)
	pillar(fq + u * (door_w * 0.5 + side_w * 0.5), u, v, side_w, t, floor_y, top, wall_col, STONE, _moss(0.5), true)
	pillar(fq, u, v, door_w + 0.1, t, floor_y + door_h, top, wall_col, STONE, _moss(0.3), true)
	# The lintel: a timber beam over the door.
	pillar(fq - v * 0.05, u, v, door_w + 0.6, t + 0.12, floor_y + door_h - 0.02, floor_y + door_h + 0.2, _jit(timber_col), WOOD, 0.2)
	_use("stone", plan.materials.stone)
	_use("timber", plan.materials.timber)
	# Windows: dark recesses with shutters gone; lit, they glow
	# (VillageLife). Front either side of the door when it is wide enough,
	# one on each side wall, one at the back.
	var wins: Array = []
	var wy := floor_y + 1.25
	if w >= 5.0:
		for sg: float in [-1.0, 1.0]:
			wins.append([fq + u * sg * (door_w * 0.5 + side_w * 0.5), -v, u])
	wins.append([c - u * (w * 0.5), -u, v])
	wins.append([c + u * (w * 0.5), u, v])
	if hr.randf() < 0.6:
		wins.append([c + v * (d * 0.5) + u * hr.randf_range(-w * 0.25, w * 0.25), v, u])
	if upper:
		for k in wins.size():
			var wu: Array = wins[k].duplicate()
			wu.append(2.5)
			wins.append(wu)
	var wv := PackedVector3Array()
	var wn := PackedVector3Array()
	for win in wins:
		var p: Vector2 = win[0]
		var out: Vector2 = win[1]
		var along: Vector2 = win[2]
		var o3 := Vector3(out.x, 0, out.y)
		var a3 := Vector3(along.x, 0, along.y)
		var ctr := Vector3(p.x, wy + (float(win[3]) if win.size() > 3 else 0.0), p.y) + o3 * 0.02
		var hw := 0.32
		var hh := 0.42
		# The dark recess (the stone's own colour, deep shade).
		_quad(ctr - a3 * hw - Vector3.UP * hh, ctr - a3 * hw + Vector3.UP * hh, ctr + a3 * hw + Vector3.UP * hh, ctr + a3 * hw - Vector3.UP * hh, Color(0.03, 0.03, 0.04, 0.0), WOOD)
		# A sill stone.
		box(ctr - Vector3.UP * (hh + 0.05) + o3 * 0.06, a3, Vector3.UP, o3, Vector3(hw * 2.0 + 0.2, 0.1, 0.18), _jit(stone_col.lightened(0.05)), STONE, 0.3)
		# The lit pane, a hair in front (its own mesh, shown when lit).
		var lc := ctr + o3 * 0.03
		for vtx in [lc - a3 * hw - Vector3.UP * hh, lc + a3 * hw + Vector3.UP * hh, lc - a3 * hw + Vector3.UP * hh,
				lc - a3 * hw - Vector3.UP * hh, lc + a3 * hw - Vector3.UP * hh, lc + a3 * hw + Vector3.UP * hh]:
			wv.append(vtx)
			wn.append(o3)
	_win.append({"v": wv, "n": wn})
	# The roof: a gable. Along the lane (eaves to it) for most; a focal
	# house turns its gable to the view that ends on it.
	var ridge_along_u := not bool(h.focal)
	var span := d if ridge_along_u else w
	var length := w if ridge_along_u else d
	var pitch := float(BLD.get("roof_pitch", 0.75))
	var over := float(BLD.get("eave_overhang_m", 0.55))
	var rise := span * 0.5 * pitch
	var ridge_ax: Vector2 = u if ridge_along_u else v
	var slope_ax: Vector2 = v if ridge_along_u else u
	var sag := hr.randf_range(0.04, 0.22)
	var holed := hr.randf() < float(BLD.get("roof_hole_share", 0.2))
	var rcol := _jit(roof_col, 0.08)
	var r3 := Vector3(ridge_ax.x, 0, ridge_ax.y)
	var segs := 3
	for sg: float in [-1.0, 1.0]:
		var s3 := Vector3(slope_ax.x, 0, slope_ax.y) * sg
		var half_run := span * 0.5 + over
		var slant := sqrt(half_run * half_run + (rise + over * pitch) * (rise + over * pitch))
		var dn := (s3 * half_run - Vector3.UP * (rise + over * pitch)).normalized()
		var nrm := r3.cross(dn).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		for k in segs:
			if holed and sg > 0.0 and k == 1:
				continue
			var tk := (k + 0.5) / segs - 0.5
			var mid := Vector3(c.x, top + rise, c.y) + r3 * (length + 0.5) * tk + dn * slant * 0.5
			# The ridge sags in the middle.
			mid.y -= sag * (1.0 - absf(tk) * 2.0)
			box(mid + nrm * 0.07, r3, nrm, dn, Vector3((length + 0.5) / segs + 0.02, 0.14, slant), rcol, roof_kind, 0.35 if roof_kind == STONE else 0.0)
	_use("roof", plan.materials.roof)
	# Gable ends: timber boarding in the triangle.
	for sg: float in [-1.0, 1.0]:
		var gq: Vector2 = c + ridge_ax * sg * (length * 0.5 - 0.2)
		var g3 := Vector3(gq.x, top, gq.y)
		var s3 := Vector3(slope_ax.x, 0, slope_ax.y)
		var nrm := Vector3(ridge_ax.x, 0, ridge_ax.y) * sg
		var a := g3 - s3 * span * 0.5
		var b := g3 + s3 * span * 0.5
		var tp := g3 + Vector3.UP * (rise - sag)
		_tri(a, b, tp, nrm, Color(timber_col.r, timber_col.g, timber_col.b, 0.15), WOOD)
		_tri(b, a, tp, -nrm, Color(timber_col.r, timber_col.g, timber_col.b, 0.15), WOOD)
	# The chimney, in the back wall over the hearth.
	var chq: Vector2 = c + v * (d * 0.5 - 0.35)
	var ch_top := top + rise + 0.7
	pillar(chq, u, v, 0.95, 0.75, floor_y + 1.9, ch_top, _jit(stone_col.darkened(0.1)), STONE, _moss(1.0))
	# Its sooted lip.
	pillar(chq, u, v, 1.05, 0.85, ch_top - 0.15, ch_top + 0.05, Color(0.06, 0.06, 0.08), STONE, 0.0)
	rec["chimney"] = Vector3(chq.x, ch_top + 0.05, chq.y)
	# Steps up to the door when it stands above its lane.
	var out_q: Vector2 = c - v * (d * 0.5 + 0.9)
	var gd := gy(out_q)
	var rise_door := floor_y - gd
	if rise_door > 0.22:
		var n_steps := clampi(int(ceil(rise_door / 0.28)), 1, 10)
		var step_h := rise_door / n_steps
		var run := 0.34
		for k in n_steps:
			var sq: Vector2 = c - v * (d * 0.5 + run * (n_steps - k - 0.5))
			pillar(sq, u, v, door_w + 0.3, run + 0.02, gd - 0.25, gd + step_h * (k + 1), _jit(stone_col.lightened(0.04)), STONE, _moss(0.2))
		# One ramp under them to walk on.
		var a3 := Vector3(c.x, 0, c.y) - z3 * (d * 0.5 + run * n_steps)
		a3.y = gd
		var b3 := Vector3(c.x, floor_y, c.y) - z3 * (d * 0.5)
		var along := (b3 - a3)
		var ln := along.length()
		var yy := along / ln
		var zz := x3.cross(yy).normalized()
		_boxes.append([Transform3D(Basis(x3, zz, -yy).orthonormalized(), (a3 + b3) * 0.5 - zz * 0.15), Vector3(door_w + 0.3, 0.3, ln)])
	# Ivy over the door and a patch on a wall (dead and overgrown).
	var ivy := Color(0.18, 0.27, 0.12, 0.0)
	for k in 5:
		var iq: Vector2 = fq - v * (t * 0.5 + 0.06) + u * hr.randf_range(-door_w * 0.7, door_w * 0.7)
		var hang := hr.randf_range(0.4, 1.1)
		pillar(iq, u, v, hr.randf_range(0.3, 0.6), 0.08, floor_y + door_h + 0.25 - hang, floor_y + door_h + 0.3, _jit(ivy, 0.15), LEAVES, 0.0)
	if hr.randf() < 0.6:
		var wq: Vector2 = c + u * sign(hr.randf() - 0.5) * (w * 0.5 + 0.05)
		pillar(wq, v, u, hr.randf_range(1.2, 2.6), 0.1, floor_y, floor_y + hr.randf_range(1.0, eave), _jit(ivy, 0.15), LEAVES, 0.0)
	footings.append(rec)


func _tower() -> void:
	var tw: Dictionary = plan.tower
	if tw.is_empty():
		return
	var c: Vector2 = tw.c
	var u: Vector2 = tw.u
	var v: Vector2 = tw.v
	var s := float(tw.size)
	var lo := INF
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			lo = minf(lo, gy(c + u * s * sx + v * s * sz))
	var base := gy(c)
	var hgt := base + float(tw.h)
	pillar(c, u, v, s + 0.5, s + 0.5, lo - 0.4, base + 0.9, _jit(stone_col.darkened(0.08)), STONE, _moss(0.0), true)
	pillar(c, u, v, s, s, base + 0.9, hgt, _jit(stone_col), STONE, _moss(1.5), true, rng.randf_range(-0.006, 0.006))
	# A string course and the belfry's openings near the top.
	pillar(c, u, v, s + 0.24, s + 0.24, hgt - 3.4, hgt - 3.15, _jit(stone_col.lightened(0.05)), STONE, 0.2)
	for ax in [u, -u, v, -v]:
		var o: Vector2 = c + ax * (s * 0.5 + 0.02)
		var along := Vector2(-ax.y, ax.x)
		var a3 := Vector3(along.x, 0, along.y)
		var o3 := Vector3(ax.x, 0, ax.y)
		for k: float in [-1.0, 1.0]:
			var ctr := Vector3(o.x, hgt - 1.6, o.y) + a3 * k * s * 0.22
			_quad(ctr - a3 * 0.38 - Vector3.UP * 0.9, ctr - a3 * 0.38 + Vector3.UP * 0.9, ctr + a3 * 0.38 + Vector3.UP * 0.9, ctr + a3 * 0.38 - Vector3.UP * 0.9, Color(0.02, 0.02, 0.03, 0.0), WOOD)
	# Its door to the square, blocked by a fallen beam.
	var dq: Vector2 = c - v * (s * 0.5 + 0.02)
	var d3 := Vector3(-v.x, 0, -v.y)
	var u3 := Vector3(u.x, 0, u.y)
	var dc := Vector3(dq.x, base + 0.9 + 1.15, dq.y)
	_quad(dc - u3 * 0.6 - Vector3.UP * 1.15, dc - u3 * 0.6 + Vector3.UP * 1.15, dc + u3 * 0.6 + Vector3.UP * 1.15, dc + u3 * 0.6 - Vector3.UP * 1.15, Color(0.02, 0.02, 0.03, 0.0), WOOD)
	box(dc + d3 * 0.15 - Vector3.UP * 0.4, u3.rotated(d3, 0.5), Vector3.UP.rotated(d3, 0.5), d3, Vector3(1.6, 0.2, 0.2), _jit(timber_col), WOOD, 0.3)
	# The pyramid roof.
	var rr := s * 0.5 + 0.4
	var apex := Vector3(c.x, hgt + s * 0.95, c.y)
	var cs: Array = []
	for k in 4:
		var q: Vector2 = c + (u * (1 if k == 0 or k == 3 else -1) + v * (1 if k < 2 else -1)) * rr
		cs.append(Vector3(q.x, hgt, q.y))
	for k in 4:
		var a: Vector3 = cs[k]
		var b: Vector3 = cs[(k + 1) % 4]
		var nrm := (b - a).cross(apex - a).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		_tri(a, b, apex, nrm, Color(roof_col.r, roof_col.g, roof_col.b, 0.3), roof_kind)
	_use("stone", plan.materials.stone)
	_use("roof", plan.materials.roof)


## Flags on the lanes and squares, sunk into the turf; about a third lost
## under it (more at the edge).
func _paving() -> void:
	var col := stone_col.lightened(0.06)
	for p in plan.paths:
		var pts: PackedVector2Array = p.pts
		var half := float(p.half)
		var i := 0
		while i < pts.size() - 1:
			var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var nrm := Vector2(-t.y, t.x)
			var lost := 0.3 if plan._ring(pts[i]) != "edge" else 0.6
			var across := -half + 0.45
			while across < half - 0.2:
				if rng.randf() > lost:
					var q := pts[i] + nrm * across + t * rng.randf_range(-0.05, 0.05)
					if plan.occ_at(q) == VillagePlan.PATH:
						_flag(q, t, nrm, col)
				across += rng.randf_range(0.75, 0.95)
			i += 1
	for s in plan.squares:
		var c: Vector2 = s.c
		var r := float(s.r)
		var lost := 0.3 if s.kind != "void" else 0.75
		var x := -r
		while x < r:
			var z := -r
			while z < r:
				var q := c + Vector2(x, z)
				if q.distance_to(c) < r - 0.3 and rng.randf() > lost:
					_flag(q, Vector2.RIGHT, Vector2.UP, col)
				z += rng.randf_range(0.8, 0.95)
			x += rng.randf_range(0.8, 0.95)
	_use("stone", plan.materials.stone)


func _flag(q: Vector2, t: Vector2, nrm: Vector2, col: Color) -> void:
	var g := gy(q)
	var x3 := Vector3(t.x, 0, t.y)
	var z3 := Vector3(nrm.x, 0, nrm.y)
	var a := rng.randf_range(-0.12, 0.12)
	box(Vector3(q.x, g - 0.07, q.y), x3.rotated(Vector3.UP, a), Vector3.UP, z3.rotated(Vector3.UP, a), Vector3(rng.randf_range(0.6, 0.85), 0.26, rng.randf_range(0.55, 0.8)), _jit(col, 0.09), STONE, rng.randf_range(0.2, 0.6))


## The squares: the core's well; benches (lit only) and brambles (dead
## only) in their own meshes.
func _squares() -> void:
	for si in plan.squares.size():
		var s: Dictionary = plan.squares[si]
		if s.has("well") and s.well != null:
			var wq: Vector2 = s.well
			var g := gy(wq)
			for k in 8:
				var a := k * TAU / 8.0
				var dirv := Vector2.from_angle(a)
				pillar(wq + dirv * 0.95, Vector2(-dirv.y, dirv.x), dirv, 0.82, 0.3, g - 0.2, g + 0.8, _jit(stone_col), STONE, _moss(0.3), true)
			var dark := Color(0.02, 0.02, 0.03, 0.0)
			_quad(Vector3(wq.x - 0.8, g + 0.5, wq.y - 0.8), Vector3(wq.x - 0.8, g + 0.5, wq.y + 0.8), Vector3(wq.x + 0.8, g + 0.5, wq.y + 0.8), Vector3(wq.x + 0.8, g + 0.5, wq.y - 0.8), dark, WOOD)
			for sg: float in [-1.0, 1.0]:
				pillar(wq + Vector2(sg * 1.05, 0), Vector2.RIGHT, Vector2.UP, 0.16, 0.16, g + 0.7, g + 2.3, _jit(timber_col), WOOD, 0.2)
			pillar(wq, Vector2.RIGHT, Vector2.UP, 2.4, 0.16, g + 2.25, g + 2.4, _jit(timber_col), WOOD, 0.2)
		var save := _swap()
		var boxes_before := _boxes.size()
		for b in plan.brambles:
			if int(b.square) != si:
				continue
			_bramble_strip(b)
		var br := _swap(save)
		var bboxes := _boxes.slice(boxes_before)
		_boxes.resize(boxes_before)
		_bramble.append({"mesh": br, "boxes": bboxes})
		save = _swap()
		for r in plan.refuge:
			if int(r.square) != si:
				continue
			_bench(r.p, r.facing)
		_benches.append(_swap(save))


func _bramble_strip(b: Dictionary) -> void:
	var a: Vector2 = b.a
	var e: Vector2 = b.b
	var out: Vector2 = b.out
	var m := float(b.m)
	var ln := a.distance_to(e)
	if ln < 0.3:
		return
	var t := (e - a) / ln
	var g := gy((a + e) * 0.5 + out * m * 0.5)
	var dark := Color(0.13, 0.19, 0.1, 0.0)
	var s := 0.0
	while s < ln:
		for k in 2:
			var q := a + t * (s + rng.randf_range(0.0, 0.5)) + out * rng.randf_range(0.25, m - 0.2)
			var sz := rng.randf_range(0.7, 1.2)
			var gq := gy(q)
			var ang := rng.randf() * TAU
			var x3 := Vector3(cos(ang), 0, sin(ang))
			box(Vector3(q.x, gq + sz * 0.45, q.y), x3, Vector3.UP, x3.cross(Vector3.UP), Vector3(sz, sz * rng.randf_range(0.8, 1.3), sz * 0.9), _jit(dark, 0.2), LEAVES, 0.0, true)
		s += 0.6
	_boxes.resize(_boxes.size()) # (the clumps' own boxes are dropped below)
	# One box for the thicket to push against.
	var mid := (a + e) * 0.5 + out * m * 0.5
	var x3 := Vector3(t.x, 0, t.y)
	var z3 := Vector3(out.x, 0, out.y)
	_boxes.append([Transform3D(Basis(x3, Vector3.UP, z3), Vector3(mid.x, g + 0.7, mid.y)), Vector3(ln, 1.6, m)])


func _bench(p: Vector2, facing: Vector2) -> void:
	var g := gy(p)
	var side := Vector2(-facing.y, facing.x)
	for sg: float in [-1.0, 1.0]:
		pillar(p + side * sg * 0.55, side, facing, 0.25, 0.4, g - 0.1, g + 0.38, _jit(stone_col), STONE, 0.3)
	pillar(p, side, facing, 1.5, 0.48, g + 0.38, g + 0.5, _jit(stone_col.lightened(0.05)), STONE, 0.25)


## Swap the main arrays for fresh ones (to build a piece of its own);
## returns what was there. With `back`, puts those back and returns the
## piece.
func _swap(back = null) -> Dictionary:
	var cur := {"v": _v, "n": _n, "c": _c, "m": _m}
	if back == null:
		_v = PackedVector3Array()
		_n = PackedVector3Array()
		_c = PackedColorArray()
		_m = PackedVector2Array()
	else:
		_v = back.v
		_n = back.n
		_c = back.c
		_m = back.m
	return cur


## Thresholds (§EF.9): an arch over a lane closed in by houses, else a
## band of kerb stones across it.
func _thresholds() -> void:
	for th in plan.thresholds:
		var p: Vector2 = th.p
		var t: Vector2 = th.t
		var nrm := Vector2(-t.y, t.x)
		var half := float(th.half) + 0.35
		if th.kind == "arch":
			var g := gy(p)
			for sg: float in [-1.0, 1.0]:
				pillar(p + nrm * sg * (half + 0.3), nrm, t, 0.6, 0.7, g - 0.3, g + 2.6, _jit(stone_col), STONE, _moss(0.5), true)
			# A round arch of seven voussoirs over the span (pure compression).
			var span := half + 0.3
			for k in 7:
				var a := PI * (k + 0.5) / 7.0
				var q := p + nrm * cos(a) * span
				var y := g + 2.6 + sin(a) * span * 0.8
				var tang := Vector3(nrm.x, 0, nrm.y) * -sin(a) + Vector3.UP * cos(a) * 0.8
				var rad := tang.cross(Vector3(t.x, 0, t.y)).normalized()
				box(Vector3(q.x, y, q.y), tang.normalized(), rad, Vector3(t.x, 0, t.y), Vector3(span * PI / 7.0 + 0.05, 0.42, 0.68), _jit(stone_col), STONE, _moss(1.2))
		else:
			var s := -half
			while s < half:
				var q := p + nrm * (s + 0.15)
				var g := gy(q)
				box(Vector3(q.x, g - 0.05, q.y), Vector3(nrm.x, 0, nrm.y), Vector3.UP, Vector3(t.x, 0, t.y), Vector3(0.28, 0.26, 0.32), _jit(stone_col.darkened(0.12)), STONE, 0.4)
				s += 0.31
	_use("stone", plan.materials.stone)


## The edge wall: dry stone, about a metre, following the ground.
func _wall() -> void:
	for seg in plan.wall:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var m := (a + b) * 0.5
		var t := (b - a).normalized()
		var g := minf(gy(a), gy(b))
		var top := maxf(gy(a), gy(b)) + rng.randf_range(0.75, 1.1)
		pillar(m, t, Vector2(-t.y, t.x), a.distance_to(b) + 0.05, 0.6, g - 0.3, top, _jit(stone_col, 0.1), STONE, _moss(0.3), true, rng.randf_range(-0.03, 0.03))
	_use("stone", plan.materials.stone)


## The gutter (§EF.8): a stone channel down the main street, its bed
## always falling (cut deeper where the street rises); dry and choked
## with leaves while the village is dead.
func _gutter() -> void:
	var gp := plan.gutter
	if gp.size() < 2:
		return
	var bed := INF
	for i in gp.size() - 1:
		var a := gp[i]
		var b := gp[i + 1]
		var m := (a + b) * 0.5
		var t := (b - a).normalized()
		var nrm := Vector2(-t.y, t.x)
		var g := gy(m)
		bed = minf(bed - 0.004, g - 0.22)
		for sg: float in [-1.0, 1.0]:
			pillar(m + nrm * sg * 0.26, t, nrm, a.distance_to(b) + 0.04, 0.14, bed - 0.05, g + 0.08, _jit(stone_col.darkened(0.05)), STONE, _moss(0.0))
		pillar(m, t, nrm, a.distance_to(b) + 0.04, 0.4, bed - 0.15, bed, _jit(stone_col.darkened(0.2)), STONE, 0.7)
		if rng.randf() < 0.3:
			pillar(m, t, nrm, 0.5, 0.36, bed, bed + 0.08, Color(0.3, 0.22, 0.12, 0.0), LEAVES, 0.0)
	# The spring house at its head: a stone hood over the dry source.
	var s := gp[0]
	var gs := gy(s)
	var tv := (gp[1] - gp[0]).normalized()
	pillar(s - tv * 0.6, Vector2(-tv.y, tv.x), tv, 1.6, 1.0, gs - 0.3, gs + 1.3, _jit(stone_col), STONE, _moss(0.5), true)
	_use("stone", plan.materials.stone)


## Vista focals (§EF.2) that are built: the cold vista hearths' stone
## surrounds and the shrines. (Feature trees are planted by
## VegetationPlacer: plan.tree_dirs().)
func _focals() -> void:
	for f in plan.focals:
		var p: Vector2 = f.p
		var g := gy(p)
		match str(f.kind):
			"hearth":
				for k in 10:
					var a := k * TAU / 10.0
					var dirv := Vector2.from_angle(a)
					pillar(p + dirv * 1.35, Vector2(-dirv.y, dirv.x), dirv, 0.75, 0.35, g - 0.2, g + 0.3, _jit(stone_col), STONE, _moss(0.0))
				# Two standing stones behind it.
				var back := (p - plan.core).normalized()
				for sg: float in [-1.0, 1.0]:
					pillar(p + back * 1.9 + Vector2(-back.y, back.x) * sg * 0.7, Vector2(-back.y, back.x), back, 0.5, 0.4, g - 0.2, g + rng.randf_range(1.3, 1.8), _jit(stone_col), STONE, _moss(0.5), true)
			"shrine":
				var fwd := (plan.core - p).normalized()
				var side := Vector2(-fwd.y, fwd.x)
				pillar(p, side, fwd, 1.3, 0.9, g - 0.3, g + 1.7, _jit(stone_col), STONE, _moss(0.4), true)
				var n3 := Vector3(fwd.x, 0, fwd.y)
				var s3 := Vector3(side.x, 0, side.y)
				var ctr := Vector3(p.x, g + 1.0, p.y) + n3 * 0.46
				_quad(ctr - s3 * 0.3 - Vector3.UP * 0.4, ctr - s3 * 0.3 + Vector3.UP * 0.4, ctr + s3 * 0.3 + Vector3.UP * 0.4, ctr + s3 * 0.3 - Vector3.UP * 0.4, Color(0.02, 0.02, 0.03, 0.0), WOOD)
				pillar(p, side, fwd, 1.6, 1.2, g + 1.7, g + 1.85, Color(roof_col.r, roof_col.g, roof_col.b), roof_kind, 0.3)
	_use("stone", plan.materials.stone)


## A square's rim wall (VillagePlan.rim_walls): dry stone to put your
## back to.
func _rim_walls() -> void:
	for rw in plan.garden_walls:
		var a: Vector2 = rw.a
		var b: Vector2 = rw.b
		var t := (b - a).normalized()
		pillar((a + b) * 0.5, t, Vector2(-t.y, t.x), a.distance_to(b), 0.55, minf(gy(a), gy(b)) - 0.3, maxf(gy(a), gy(b)) + 1.7, _jit(stone_col), STONE, _moss(0.4), true, rng.randf_range(-0.02, 0.02))
	for rw in plan.rim_walls:
		var a: Vector2 = rw.a
		var b: Vector2 = rw.b
		var t := (b - a).normalized()
		var m := (a + b) * 0.5
		var g := minf(gy(a), gy(b))
		pillar(m, t, Vector2(-t.y, t.x), a.distance_to(b), 0.6, g - 0.3, maxf(gy(a), gy(b)) + 1.25, _jit(stone_col), STONE, _moss(0.3), true)
	if not plan.rim_walls.is_empty() or not plan.garden_walls.is_empty():
		_use("stone", plan.materials.stone)


## Edges to linger on (§EF.6): a low wall at the rim and a bench behind it.
func _edges() -> void:
	for e in plan.edges:
		var p: Vector2 = e.p
		var f: Vector2 = e.facing
		var side := Vector2(-f.y, f.x)
		var g := gy(p + f * 0.8)
		pillar(p + f * 0.8, side, f, 2.6, 0.5, g - 0.3, g + 0.65, _jit(stone_col), STONE, _moss(0.3), true)
		_bench(p - f * 0.3, f)


## The ma (§EG.3): an empty square is just its paving; a still pool gets a
## raised stone kerb and still water; an unplanted bank, nothing at all.
func _void() -> void:
	var va: Dictionary = plan.void_area
	if va.is_empty() or str(va.kind) != "still_pool":
		return
	var c: Vector2 = va.c
	var r := float(va.r)
	var hi := -INF
	for k in 12:
		hi = maxf(hi, gy(c + Vector2.from_angle(k * TAU / 12.0) * r))
	var wl := hi + 0.25
	var n := 16
	for k in n:
		var a := (k + 0.5) * TAU / n
		var dirv := Vector2.from_angle(a)
		var q := c + dirv * (r + 0.25)
		pillar(q, Vector2(-dirv.y, dirv.x), dirv, TAU * (r + 0.25) / n + 0.08, 0.5, gy(q) - 0.3, wl + 0.2, _jit(stone_col), STONE, _moss(0.2), true)
	# A floor under the water.
	pillar(c, Vector2.RIGHT, Vector2.UP, r * 2.0, r * 2.0, wl - 0.6, wl - 0.45, Color(0.14, 0.16, 0.12), STONE, 0.8)
	# The water: a disc of fans (the river's water material; still).
	for k in n:
		var a0 := k * TAU / n
		var a1 := (k + 1) * TAU / n
		var p0 := Vector3(c.x, wl, c.y)
		var p1 := Vector3(c.x + cos(a0) * r, wl, c.y + sin(a0) * r)
		var p2 := Vector3(c.x + cos(a1) * r, wl, c.y + sin(a1) * r)
		for vv in [p0, p2, p1]:
			_wv.append(vv)
			_wuv.append(Vector2(vv.x - c.x, vv.z - c.y))
			_wuv2.append(Vector2(0.0, r))
	_use("stone", plan.materials.stone)


## A raised mound behind when the site lacks its ridge (§EE.3): a long
## turfed bank faced in dry stone.
func _mound() -> void:
	if not plan.builds.has("raised_mound_behind"):
		return
	var R := float(VillagePlan.PL.get("radius_m", 78.0))
	var c := plan.core + Vector2(0, -R * 0.92)
	var turf := Color(0.26, 0.34, 0.18, 0.4)
	var n := 12
	for k in n:
		var x := (k - n * 0.5 + 0.5) * 3.2
		var q := c + Vector2(x, 0.0)
		var g := gy(q)
		var h := 2.4 * sin(PI * (k + 0.5) / n)
		box(Vector3(q.x, g + h * 0.35, q.y), Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3(3.3, h, 5.0), _jit(turf, 0.1), THATCH, 0.0, true)
		pillar(q + Vector2(0, 2.6), Vector2.RIGHT, Vector2.UP, 3.2, 0.5, g - 0.2, g + h * 0.7, _jit(stone_col), STONE, _moss(0.0))


## Where each of the plan's hearths sits in the node: a house's on its
## floor under the chimney; a square's and a vista's on the ground.
func _hearth_spots() -> void:
	for h in plan.hearths:
		var p: Vector2 = h.p
		if h.kind == "house":
			var f: Dictionary = footings[int(h.of)]
			hearth_local.append(Vector3(p.x, float(f.floor) + 0.02, p.y))
		else:
			hearth_local.append(Vector3(p.x, gy(p), p.y))


# --- Nodes -----------------------------------------------------------------------

static var _win_mat: StandardMaterial3D = null


static func window_material() -> StandardMaterial3D:
	if _win_mat == null:
		_win_mat = StandardMaterial3D.new()
		_win_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_win_mat.albedo_color = Color(str(BLD.get("window_color", "#FFA654")))
		_win_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _win_mat


static func _mesh(arr: Dictionary, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if (arr.v as PackedVector3Array).is_empty():
		return mi
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = arr.v
	a[Mesh.ARRAY_NORMAL] = arr.n
	if arr.has("c"):
		a[Mesh.ARRAY_COLOR] = arr.c
		a[Mesh.ARRAY_TEX_UV] = arr.m
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	mi.mesh = mesh
	mi.material_override = mat
	return mi


## The village's nodes: the stone mesh, its collision, the still pool's
## water, per house its lit windows (hidden) and chimney mouth, per square
## its brambles (shown, with their collision) and benches (hidden).
static func make_node(data: Dictionary, world: Node) -> Node3D:
	var site: Dictionary = data.site
	var root := Node3D.new()
	root.name = "Village_" + str(site.id)
	root.set_meta("site", site)
	root.set_meta("village", str(site.id))
	var mi := _mesh(data, RuinBuilder.material())
	mi.name = "Stone"
	root.add_child(mi)
	var body := PropCollision.body(root, "Body")
	for b in data.boxes:
		PropCollision.box(body, b[0], b[1])
	var wd: Dictionary = data.water
	if not (wd.v as PackedVector3Array).is_empty():
		TerrainChunk.materials()
		var wn := PackedVector3Array()
		wn.resize((wd.v as PackedVector3Array).size())
		wn.fill(Vector3.UP)
		var warr := []
		warr.resize(Mesh.ARRAY_MAX)
		warr[Mesh.ARRAY_VERTEX] = wd.v
		warr[Mesh.ARRAY_NORMAL] = wn
		warr[Mesh.ARRAY_TEX_UV] = wd.uv
		warr[Mesh.ARRAY_TEX_UV2] = wd.uv2
		var wmesh := ArrayMesh.new()
		wmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, warr)
		var wmi := MeshInstance3D.new()
		wmi.name = "Water"
		wmi.mesh = wmesh
		wmi.material_override = WaterLook.material(FireStore.biome_key(world, site.dir), false)
		wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(wmi)
	var wins: Array = []
	for i in (data.win as Array).size():
		var w := _mesh(data.win[i], window_material())
		w.name = "Windows%d" % i
		w.visible = false
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(w)
		wins.append(w)
	root.set_meta("windows", wins)
	var stacks: Array = []
	for i in (data.footings as Array).size():
		var s := Node3D.new()
		s.name = "Chimney%d" % i
		s.position = data.footings[i].chimney
		s.set_meta("mouth", 0.0)
		root.add_child(s)
		stacks.append(s)
	root.set_meta("chimneys", stacks)
	var brs: Array = []
	for si in (data.bramble as Array).size():
		var bd: Dictionary = data.bramble[si]
		var bm := _mesh(bd.mesh, RuinBuilder.material())
		bm.name = "Brambles%d" % si
		root.add_child(bm)
		var bb := PropCollision.body(root, "BrambleBody%d" % si)
		for b in bd.boxes:
			PropCollision.box(bb, b[0], b[1])
		var bench := _mesh(data.bench[si], RuinBuilder.material())
		bench.name = "Benches%d" % si
		bench.visible = false
		root.add_child(bench)
		brs.append([bm, bb, bench])
	root.set_meta("squares", brs)
	root.set_meta("hearths", data.hearths)
	root.set_meta("footings", data.footings)
	root.set_meta("used", data.used)
	return root
