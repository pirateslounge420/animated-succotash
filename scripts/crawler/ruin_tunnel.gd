class_name RuinTunnel
extends Node3D
## The shrine mouths and the tunnel between two ruins (design 11 Oct §FV.2,
## §FV.5; queue 100, amended by Mike 12 Oct: the second built culture is
## the Aztec temple; data/ruin_compass.json tunnel).
##
## Mike, 12 Oct: "you can go to the surface and head down another shrine on
## the cardinal direction of whatever you choose and youll go down that
## corridor and itll lead to a new biome ruin where you then emerge on the
## surface and then can go into the new biomes ruins".
##
## Which ruins join (tunnel.built_pair): the compass has no row of its own
## for the tomb (its "aztec" row is the tomb's stand-in, status
## built_as_the_tomb_open_call_1), so the two built ruins are not
## neighbours on it. They are joined anyway along the aztec row's
## north-south line: the Aztec temple's shrine stands at the south edge of
## its surface, and you come up at the north edge of the tomb's; the
## tomb's shrine at its north edge brings you up at the temple's south
## edge. A ruin only has a shrine while its neighbour is in the game (the
## temple: aztec_temple.json enabled); other edges stay closed by the land
## (§DM).
##
## Places (CrawlerSave): the first ruin is place 0 (§FJ.1, random from the
## roster), its neighbour across the tunnel place 1 (across(): 0 and 1, 2
## and 3, ...), its seed drawn from the game's seed (CrawlerSave.dungeon_
## seed) and its theme the neighbour's (CrawlerSave.theme_at), kept in the
## save like any dungeon you have been in: relit stays lit both ways, and
## Continue wakes you by the hearth of the ruin you were last in.
##
## The tunnel itself (this node, in play): one straight corridor run along
## the compass line, three stretches of tunnel.stretch_m (tunnel.stretches:
## this culture's stone, mixed, the next's), each stone cut by TombBuild in
## its own style (§EX.1); the mixed stretch takes each band of
## tunnel.mix_band_m from one style or the other, the next's the likelier
## the further along. Dark, no sconces, no boss, no residents
## (tunnel.residents is open, §FV.7 call 4: none for now), nothing gating
## it (tunnel.gated false). Its far end is the load seam (§EW.3): the dark
## comes, the next ruin and its surface are built behind it, and you stand
## at its shrine. Walk back to the near end and you come up at the shrine
## you went down.

static var RC: Dictionary = Surface._json("res://data/ruin_compass.json")
static var T: Dictionary = RC.get("tunnel", {})

const DIRS := {"north": Vector2(0.0, -1.0), "south": Vector2(0.0, 1.0), "east": Vector2(1.0, 0.0), "west": Vector2(-1.0, 0.0)}
const OPPOSITE := {"north": "south", "south": "north", "east": "west", "west": "east"}

## The run's theme at each end, its direction and length (m).
var from_theme := ""
var to_theme := ""
var dir := "north"
var length := 48.0
## Where it starts (the near end, on the floor) and the way along it.
var start := Vector3.ZERO
var along := Vector2(0.0, -1.0)
## Which style each band of the mixed stretch took (the checks): [0 own, 1 next].
var bands: Array = []
## The stone's triangles per stretch: [own, next] counts for each of three.
var tris := [[0, 0], [0, 0], [0, 0]]


# --- Which ruins join ------------------------------------------------------------------

## Is the tunnel in the game (tunnel.on)?
static func on() -> bool:
	return bool(T.get("on", true))


## A theme as the game names it ("" is the layout's own: the tomb).
static func norm(th: String) -> String:
	return th if th != "" else str(Tuning.table("crawler").get("opening", {}).get("first_theme", "tomb"))


## Is ruin `th` in the game (built, and switched on)?
static func playable(th: String) -> bool:
	var t := norm(th)
	if not (Tuning.table("crawler").get("themes", {}) as Dictionary).has(t):
		return false
	if t == "aztec_temple":
		return CrawlerSave.aztec_on
	return true


## The open shrine mouths over ruin `th`: [{"dir", "to"}], each neighbour in
## the game (tunnel.built_pair).
static func exits_of(th: String) -> Array:
	var out: Array = []
	if not on():
		return out
	var t := norm(th)
	if not playable(t):
		return out
	var pair: Dictionary = (T.get("built_pair", {}) as Dictionary).get(t, {})
	for d in pair:
		if DIRS.has(str(d)) and playable(str(pair[d])) and norm(str(pair[d])) != t:
			out.append({"dir": str(d), "to": norm(str(pair[d]))})
	return out


## The neighbour of ruin `th` across its first tunnel, or "".
static func neighbour(th: String) -> String:
	var ex := exits_of(th)
	return str(ex[0].to) if not ex.is_empty() else ""


## The compass bearings (degrees, north 0, east 90) of `th`'s shrines.
static func bearings(th: String) -> Array:
	var out: Array = []
	for e in exits_of(th):
		out.append(float({"north": 0.0, "east": 90.0, "south": 180.0, "west": 270.0}[e.dir]))
	return out


## The place across the tunnel from place `at` (0 and 1, 2 and 3, ...).
static func across(at: int) -> int:
	return at + 1 if at % 2 == 0 else at - 1


# --- The shrine mouths, on the surface ---------------------------------------------------

## Where the shrine toward `d` stands on `land`: {"dir", "pos" (its doorway's
## sill, Vector3), "n" (Vector2, the way out of its doorway: in toward the
## middle), "half" (the doorway's half width)}. At the foot of the edge's
## slope (the talus) on the compass line through the stairhead.
static func shrine_spot(land: SurfaceGround, d: String) -> Dictionary:
	var v: Vector2 = DIRS[d]
	var th := atan2(v.y, v.x)
	var back := float((T.get("shrine", {}) as Dictionary).get("in_from_talus_m", 6.0))
	var r := land.edge_r(th) - float(land.E.get("talus_width_m", 90.0)) - back
	r = maxf(r, 30.0)
	var p := land.center + v * r
	return {"dir": d, "pos": Vector3(p.x, land.height_at(p.x, p.y), p.y), "n": -v, "half": 0.75}


## The shrine (its own stone): a small house of the ruin's stone, its back
## to the edge, a doorway on the middle side, dark within, and a flight
## going down past it. One mesh of boxes (RuinBuilder's material, the
## stone's own tint) and its collision; the doorway open.
static func shrine_node(spot: Dictionary, th: String) -> Node3D:
	var node := Node3D.new()
	node.name = "Shrine_" + str(spot.dir)
	var S: Dictionary = T.get("shrine", {})
	var w := float(S.get("width_m", 3.4))
	var dp := float(S.get("depth_m", 3.2))
	var h := float(S.get("height_m", 3.0))
	var wall := 0.45
	var half := float(spot.half)
	var n: Vector2 = spot.n
	var z3 := Vector3(n.x, 0.0, n.y)
	var at: Vector3 = spot.pos
	node.transform = Transform3D(Basis(Vector3.UP.cross(z3), Vector3.UP, z3), at)
	# Local frame: +z out of the doorway (toward the middle), x across.
	var tint := RuinStyle.tint(norm(th))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var boxes: Array = []
	var foot := -1.2
	# Back wall, side walls, the front either side of the doorway, the lintel, the roof slab.
	boxes.append([Vector3(0.0, (foot + h) * 0.5, -dp + wall * 0.5), Vector3(w, h - foot, wall)])
	for sx in [-1.0, 1.0]:
		boxes.append([Vector3(sx * (w * 0.5 - wall * 0.5), (foot + h) * 0.5, -dp * 0.5), Vector3(wall, h - foot, dp)])
		var fw := (w * 0.5 - half)
		boxes.append([Vector3(sx * (half + fw * 0.5), (foot + h) * 0.5, -wall * 0.5), Vector3(fw, h - foot, wall)])
	var door_h := minf(2.3, h - 0.4)
	boxes.append([Vector3(0.0, (door_h + h) * 0.5, -wall * 0.5), Vector3(half * 2.0, h - door_h, wall)])
	boxes.append([Vector3(0.0, h + 0.15, -dp * 0.5), Vector3(w + 0.4, 0.3, dp + 0.4)])
	# The floor inside, a step down from the sill.
	boxes.append([Vector3(0.0, -0.2, -dp * 0.5), Vector3(w - wall * 2.0, 0.4, dp - wall)])
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = PropCollision.WORLD_LAYER
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([str(spot.dir), th, "shrine"])
	for b in boxes:
		var c: Vector3 = b[0]
		var sz: Vector3 = b[1]
		var col := RuinStyle.shifted(tint, rng.randf_range(-1.0, 1.0) * RuinStyle.spread(norm(th)))
		_box(st, c, sz, col)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		cs.shape = bs
		cs.position = c
		body.add_child(cs)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Stone"
	mi.mesh = st.commit()
	mi.material_override = RuinBuilder.material()
	node.add_child(mi)
	node.add_child(body)
	# The dark within: the way down, unlit.
	var dark := MeshInstance3D.new()
	dark.name = "Dark"
	var q := QuadMesh.new()
	q.size = Vector2(w - wall * 2.0 - 0.05, h - 0.05)
	dark.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.01, 0.01, 0.02)
	dark.material_override = m
	dark.position = Vector3(0.0, h * 0.5, -dp + wall + 0.02)
	node.add_child(dark)
	node.set_meta("dir", str(spot.dir))
	return node


static func _box(st: SurfaceTool, c: Vector3, sz: Vector3, col: Color) -> void:
	var hx := sz * 0.5
	var corners := []
	for i in 8:
		corners.append(c + Vector3(hx.x * (1 if i & 1 else -1), hx.y * (1 if i & 2 else -1), hx.z * (1 if i & 4 else -1)))
	var faces := [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
	for f in faces:
		var a: Vector3 = corners[f[0]]
		var b: Vector3 = corners[f[1]]
		var cc: Vector3 = corners[f[2]]
		var d: Vector3 = corners[f[3]]
		for v in [a, cc, b, a, d, cc]:
			st.set_color(col)
			st.add_vertex(v)


## Has `pos` (feet) gone in through the shrine's doorway (inside its walls,
## past the sill by in_at_m)?
static func stepped_in(spot: Dictionary, pos: Vector3) -> bool:
	var n: Vector2 = spot.n
	var p: Vector3 = spot.pos
	var rel := Vector2(pos.x - p.x, pos.z - p.z)
	var inward := -rel.dot(n)
	var lateral := absf(rel.dot(Delves.perp(n)))
	var at := float((T.get("shrine", {}) as Dictionary).get("in_at_m", 0.9))
	return inward > at and inward < 4.0 and lateral < 1.4 and absf(pos.y - p.y) < 2.5


## Where you stand coming up out of the shrine: in its doorway, facing the
## middle ({"pos", "yaw"}).
static func arrival(spot: Dictionary) -> Dictionary:
	var n: Vector2 = spot.n
	var p: Vector3 = spot.pos
	var out := float((T.get("shrine", {}) as Dictionary).get("out_m", 2.0))
	return {"pos": p + Vector3(n.x, 0.0, n.y) * out + Vector3(0.0, 0.05, 0.0), "yaw": atan2(-n.x, -n.y)}


# --- The tunnel, in play -----------------------------------------------------------------

## The stretches' length (m).
static func stretch_m() -> float:
	return maxf(float(T.get("stretch_m", 16.0)), 4.0)


## The run from `p_from` (going `p_dir`) to `p_to`, built from `seed_value`.
## The near end at the origin: you walk out along `along`.
func build(p_from: String, p_to: String, p_dir: String, seed_value: int) -> void:
	name = "Tunnel"
	from_theme = norm(p_from)
	to_theme = norm(p_to)
	dir = p_dir
	along = DIRS.get(dir, Vector2(0.0, -1.0))
	var sl := stretch_m()
	length = sl * 3.0
	start = Vector3.ZERO
	var half := float(T.get("half_m", 1.0))
	var h := float(T.get("height_m", 2.6))
	var built: Array = []
	for th in [from_theme, to_theme]:
		var lay := {"seed": seed_value, "theme": th, "module": 2.0, "pieces": [], "doors": [], "holders": [], "airways": [],
			"vents": [], "lair": {}, "tunnels": {}, "hearth": Vector3(0.0, -500.0, 0.0)}
		TombKit._add(lay, Delves.piece("corridor", Vector2.ZERO, along, length, half, 0.0, 0.0, h))
		built.append(TombBuild.build(lay))
	RuinStyle.theme = from_theme
	FittedStone.theme = from_theme
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "tunnel mix"])
	var band := maxf(float(T.get("mix_band_m", 1.6)), 0.4)
	var nb := ceili(sl / band)
	bands = []
	for i in nb:
		var t := (float(i) + 0.5) / float(nb)
		bands.append(1 if rng.randf() < t else 0)
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var c := PackedColorArray()
	var m := PackedVector2Array()
	for k in 2:
		var d: Dictionary = built[k]
		var bv: PackedVector3Array = d.v
		for t in range(0, bv.size() - 2, 3):
			var mid := (bv[t] + bv[t + 1] + bv[t + 2]) / 3.0
			var s := Vector2(mid.x, mid.z).dot(along)
			var st := clampi(floori(s / sl), 0, 2)
			var take := 0
			if st == 2:
				take = 1
			elif st == 1:
				take = int(bands[clampi(floori((s - sl) / band), 0, nb - 1)])
			if take != k:
				continue
			tris[st][k] += 1
			for q in 3:
				v.append(bv[t + q])
				nn.append((d.n as PackedVector3Array)[t + q])
				c.append((d.c as PackedColorArray)[t + q])
				m.append((d.m as PackedVector2Array)[t + q])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nn
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_TEX_UV] = m
	RuinBuilder._flip_winding(arrays)
	for part in CrawlerMain._chunks(arrays):
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part)
		var mi := MeshInstance3D.new()
		mi.name = "Stone"
		mi.mesh = mesh
		mi.material_override = RuinBuilder.material_lit()
		add_child(mi)
	add_child(CrawlerMain.collision_body(built[0]))
	# The ends: shut by stone, a dark doorway drawn on each (the way on, the
	# way back up), a step past the trigger.
	for e in [[-0.6, from_theme], [length + 0.6, to_theme]]:
		var at := Vector3(along.x, 0.0, along.y) * float(e[0])
		var cap := StaticBody3D.new()
		cap.collision_layer = PropCollision.WORLD_LAYER
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(half * 2.0 + 1.0, h + 1.0, 0.4)
		cs.shape = bs
		cap.add_child(cs)
		cap.transform = Transform3D(Basis.looking_at(Vector3(along.x, 0.0, along.y), Vector3.UP), at + Vector3(0.0, h * 0.5, 0.0))
		add_child(cap)
		var dark := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(half * 2.0, h)
		dark.mesh = q
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.01, 0.01, 0.02)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		dark.material_override = mat
		dark.transform = cap.transform
		add_child(dark)
	print("[tunnel] %s -> %s going %s: %d m in three stretches (%s, mixed %d of %d bands the next's, %s); triangles %s" % [from_theme, to_theme, dir, int(length), RuinStyle.style_name(from_theme), bands.count(1), bands.size(), RuinStyle.style_name(to_theme), str(tris)])


## How far along the run `pos` is (m).
func along_m(pos: Vector3) -> float:
	return Vector2(pos.x - start.x, pos.z - start.z).dot(along)


## Where you stand at the near end, facing along ({"pos", "yaw"}).
func near_spawn() -> Dictionary:
	var p := start + Vector3(along.x, 0.0, along.y) * 1.6
	return {"pos": p, "yaw": atan2(-along.x, -along.y)}


## Has `pos` reached the far end (the seam)?
func at_far(pos: Vector3) -> bool:
	return along_m(pos) > length - float(T.get("end_m", 1.0))


## Has `pos` walked back to the near end?
func at_near(pos: Vector3) -> bool:
	return along_m(pos) < float(T.get("end_m", 1.0)) * 0.5
