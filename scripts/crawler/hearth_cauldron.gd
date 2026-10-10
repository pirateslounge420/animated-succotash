class_name HearthCauldron
extends Node3D
## The cauldron over the hearth (design 9 Oct §FM.6, the opening room: the
## shaman sits at the hearth "and now a cauldron hangs over the hearth, from
## the first moment"; crawler.json cauldron; queue 67). Every dungeon's one
## hearth (§EX.4) has one, built with the tomb (CrawlerMain._load_tomb), so
## it is there before the dark lifts on waking and in the next tomb the
## stand-in takes you to.
##
## An iron pot (§FL.1: metal is allowed again; the ruin's stone, clay or
## iron was Claude Code's call, and iron reads as a cauldron at 480 lines):
## round-bellied, a rolled lip, a lug on each side and a bail between them,
## hung by a short chain from a tripod of three poles lashed at the top,
## their feet on the hearth's kerb. Empty at rest: since queue 72 (§FM.7,
## Brew) the brew stands in it only while the shaman works a cutting.
##
## Where (cauldron.pot, tripod, chain): over the hearth's middle, its belly
## low over the flame (its bottom pot.bottom_m over the floor, the flame
## licking it), its bail's arch toward your mat (lay.wake) so it reads from
## where you wake. One pole stands straight across the fire from the mat,
## behind the flame; the other two at the mat's sides of the fire, so none
## stands between you and the fire or the shaman (lay.rescuer, round_deg
## off straight across), and none of their shadows falls on you or him.
## It doesn't move the mat, the bundle or the shaman (TombKit places them
## first and reads nothing of it).
##
## Painted per §ES: its light painted into its vertex colours (the iron
## blackened by soot toward the fire, the poles by the smoke toward the
## top, the occlusion inside the pot and under its lip baked toward navy:
## Prelit), drawn in the tomb's own lit material (RuinBuilder.material_lit:
## diffuse only, roughness 1, no normal maps; iron and poles alike its
## smooth matte, their paint in their vertex colours: the timber tile's
## grain striped the slanting poles), mid-poly (pot.sides round).
##
## The hearth's amber falls on it live, from the flame below it. The
## hearth's one light hangs a metre over the floor, a hand over the pot's
## mouth: there it would light the empty pot from inside and blow it out
## like a brazier. So the hearth's light passes the cauldron by (its cull
## mask leaves out LAYER, the cauldron's render layer, and nothing else:
## the room is lit as before, and the light field, which reads that light,
## is untouched) and the cauldron takes the same fire's light from where the
## flame is, under its belly: Firelight, cauldron.firelight at_m over the
## floor, lighting LAYER alone, without a shadow, its colour the hearth
## light's and its strength share of the hearth light's every frame, so it
## flickers and breathes with the fire. The belly glows from below; the
## rim, the inside and the tops of the poles fall away to the dark. Your
## torch lights it as it lights everything.
##
## Nothing of the pot, its bail or its chain casts a shadow (it hangs right
## under the hearth's light; its shadow would black out the floor round
## the hearth); the poles do. The pot has a collision hull round its belly
## (under its rim, inside the pit's guard: nothing you walk changes, and no
## line from the hearth's light to the floor past the kerb meets it); the
## poles and the chain have none (they stand inside the guard too).
##
## For code (Brew brews in it, queue 72): CrawlerMain.cauldron, the node
## "Cauldron", the group GROUP, mouth() and mouth_r().

static var D: Dictionary = Tuning.table("crawler").get("cauldron", {})

## The cauldron's render layer (layer 14): what the hearth's light leaves
## out and its Firelight lights alone.
const LAYER := 1 << 13
## Every cauldron in the scene (CrawlerMain's one).
const GROUP := "hearth_cauldron"
## The material (shaders/ruin.gdshader UV.x): its smooth matte (5), for
## the iron and the poles alike.
const MATTE := 5.0

## The pot, bail and chain (no shadow), the tripod (its shadow), the fire's
## light on them from below, the pot's collision.
var pot: MeshInstance3D
var tripod: MeshInstance3D
var firelight: OmniLight3D
var collision: StaticBody3D
## The hearth's light it follows, and the share of it.
var hearth_light: OmniLight3D
var share := 0.3
## The pot as built (local, from the hearth's middle on the floor): its
## mouth's height and radius, its bottom's, its belly's radius, the top of
## its collision.
var mouth_y := 0.78
var mouth_radius := 0.2
var bottom_y := 0.44
var belly_r := 0.26
var hull_top := 0.74
## The tripod's feet and apex (local).
var feet: Array[Vector3] = []
var apex := Vector3.ZERO
## Triangles drawn (checks).
var triangles := 0


## The cauldron over `lay`'s hearth, under `parent`, the hearth's fire
## `hearth` (CrawlerFires.hearth) lighting it from below.
static func make(parent: Node, lay: Dictionary, hearth: Node3D) -> HearthCauldron:
	var c := HearthCauldron.new()
	c.name = "Cauldron"
	c.add_to_group(GROUP)
	# After the fires each frame (CrawlerFires flickers the hearth's light),
	# so the Firelight takes this frame's.
	c.process_priority = 10
	var hp: Vector3 = lay.get("hearth", Vector3.ZERO)
	var w: Array = lay.get("wake", [hp + Vector3(0.0, 0.0, 2.4), 0.0])
	var v := Vector3((w[0] as Vector3).x - hp.x, 0.0, (w[0] as Vector3).z - hp.z)
	if v.length() < 0.01:
		v = Vector3.BACK
	c.position = hp
	# Its +z toward your mat.
	c.rotation = Vector3(0.0, atan2(v.x, v.z), 0.0)
	c.hearth_light = hearth.get_node_or_null("Light") as OmniLight3D if hearth != null else null
	c._build()
	parent.add_child(c)
	if c.hearth_light != null:
		c.hearth_light.light_cull_mask &= ~LAYER
	c._follow()
	return c


## The middle of the pot's mouth (scene).
func mouth() -> Vector3:
	return to_global(Vector3(0.0, mouth_y, 0.0))


## The pot's mouth's radius (m, inside its lip).
func mouth_r() -> float:
	return mouth_radius


## Is `l` a cauldron's Firelight (the hearth's own light on its belly)?
static func is_firelight(l: Node) -> bool:
	return l is OmniLight3D and l.name == "Firelight" and l.get_parent() is HearthCauldron


func _process(_delta: float) -> void:
	_follow()


## The fire's light on it: the hearth light's colour, share of its
## strength (0 when it is out or hidden).
func _follow() -> void:
	if firelight == null:
		return
	if hearth_light == null or not is_instance_valid(hearth_light) or not hearth_light.is_visible_in_tree():
		firelight.light_energy = 0.0
		return
	firelight.light_energy = hearth_light.light_energy * share
	firelight.light_color = hearth_light.light_color


# --- Building ----------------------------------------------------------------

func _build() -> void:
	var pd: Dictionary = D.get("pot", {})
	var td: Dictionary = D.get("tripod", {})
	var cd: Dictionary = D.get("chain", {})
	var fl: Dictionary = D.get("firelight", {})
	var cols: Dictionary = D.get("colors", {})
	var iron := Color(str(cols.get("iron", "#26262c")))
	var soot := Color(str(cols.get("soot", "#121216")))
	var wood := Color(str(cols.get("pole", "#5a4532")))
	var wood_soot := Color(str(cols.get("pole_soot", "#241c17")))
	var cord := Color(str(cols.get("cord", "#7a6644")))
	belly_r = maxf(float(pd.get("belly_r_m", 0.26)), 0.08)
	mouth_radius = clampf(float(pd.get("mouth_r_m", 0.2)), 0.05, belly_r)
	var h := maxf(float(pd.get("h_m", 0.34)), 0.1)
	bottom_y = float(pd.get("bottom_m", 0.44))
	mouth_y = bottom_y + h
	var wall := clampf(float(pd.get("wall_m", 0.016)), 0.004, 0.05)
	var lip := clampf(float(pd.get("lip_m", 0.024)), 0.0, 0.08)
	var sides := clampi(int(pd.get("sides", 14)), 6, 32)
	hull_top = minf(float(pd.get("hull_top_m", mouth_y - 0.04)), mouth_y)
	# The pot: one lathe, outside up from the middle of its bottom, over the
	# lip and down the inside to the middle of its floor.
	var prof := PackedVector2Array()
	var pcol := PackedColorArray()
	var b := bottom_y
	var r := belly_r
	var m := mouth_radius
	var outer := [Vector2(0.0, b), Vector2(0.45 * r, b + 0.004), Vector2(0.75 * r, b + 0.026), Vector2(0.93 * r, b + 0.08),
		Vector2(r, b + 0.16 * h / 0.34), Vector2(0.97 * r, b + 0.24 * h / 0.34), Vector2(lerpf(m, r, 0.45), b + h - 0.045),
		Vector2(m, b + h - 0.016), Vector2(m + lip, b + h - 0.006), Vector2(m + lip, b + h)]
	for q: Vector2 in outer:
		prof.append(q)
		# Soot up the belly from the fire, the iron's own grey by the
		# shoulder, the lip a little worn.
		var k := smoothstep(b, b + h * 0.75, q.y)
		var col := soot.lerp(iron, k)
		if q.y >= b + h - 0.02:
			col = iron.lightened(0.12)
		pcol.append(col)
	# Over the lip's top to the inside, then down the inside wall, a wall's
	# thickness in.
	var inner := [Vector2(m - wall * 0.5, b + h), Vector2(m - wall, b + h - 0.02), Vector2(lerpf(m, r, 0.45) - wall, b + h - 0.05),
		Vector2(0.97 * r - wall, b + 0.24 * h / 0.34), Vector2(r - wall, b + 0.16 * h / 0.34), Vector2(0.92 * r - wall, b + 0.085),
		Vector2(0.72 * r - wall, b + wall + 0.026), Vector2(0.42 * r, b + wall + 0.004), Vector2(0.0, b + wall)]
	for q: Vector2 in inner:
		prof.append(q)
		pcol.append(iron.darkened(0.25))
	var ps := new_arrays()
	lathe(ps, prof, pcol, sides, MATTE)
	# The lugs either side of the rim, where the bail turns.
	var lug_x := m + lip + 0.012
	for sx: float in [-1.0, 1.0]:
		_box(ps, Transform3D(Basis.IDENTITY, Vector3(sx * (m + lip * 0.5 + 0.006), b + h - 0.03, 0.0)), Vector3(0.036, 0.05, 0.034), iron, MATTE)
	# Painted occlusion: inside the pot, under its lip, round the lugs.
	Prelit.bake(ps.arrays, 12, 8, 1.0)
	# The bail: a half ring from lug to lug, up over the mouth, in the plane
	# facing your mat.
	var rod := clampf(float((D.get("bail", {}) as Dictionary).get("r_m", 0.011)), 0.003, 0.03)
	var hinge := Vector3(0.0, b + h - 0.03, 0.0)
	var arc := PackedVector3Array()
	var steps := 12
	for i in steps + 1:
		var a := PI * float(i) / float(steps)
		arc.append(hinge + Vector3(-cos(a) * lug_x, sin(a) * lug_x, 0.0))
	var bail_top := hinge.y + lug_x
	var bk := new_arrays()
	_rod(bk, arc, rod, iron.lightened(0.04), MATTE)
	# The chain from the apex down to the bail's top: links turned a
	# quarter each, every one through the next.
	var apex_y := maxf(float(td.get("apex_m", 1.62)), bail_top + 0.2)
	var link_m := clampf(float(cd.get("link_m", 0.085)), 0.03, 0.3)
	var link_w := link_m * 0.52
	var link_rod := clampf(float(cd.get("rod_m", 0.006)), 0.002, 0.02)
	var pitch := link_m - 2.0 * link_rod - 0.012
	var top := apex_y - 0.03
	var n_links := maxi(int(round((top - bail_top) / maxf(pitch, 0.01))), 1)
	pitch = (top - bail_top) / float(n_links)
	for i in n_links:
		var mid := Vector3(0.0, top - pitch * (float(i) + 0.5), 0.0)
		var turn := 0.0 if i % 2 == 0 else PI * 0.5
		var ring := PackedVector3Array()
		for k in 9:
			var a2 := TAU * float(k) / 8.0
			ring.append(mid + Vector3(cos(a2) * link_w * 0.5, sin(a2) * link_m * 0.5, 0.0).rotated(Vector3.UP, turn))
		_rod(bk, ring, link_rod, iron, MATTE)
	_merge(ps, bk)
	pot = _mesh("Pot", ps, false)
	# The tripod: three poles from the kerb to the apex and a little past,
	# lashed where they cross; their feet on the middle of the pit's kerb
	# (inside its guard), or among the old ring's stones on the floor where
	# the style has no pit.
	var pit := TombBuild.pit()
	var foot_y := 0.08 if pit.is_empty() else float(pit.proud)
	apex = Vector3(0.0, apex_y, 0.0)
	var pole_r := clampf(float(td.get("pole_r_m", 0.026)), 0.008, 0.08)
	var past := maxf(float(td.get("past_apex_m", 0.16)), 0.0)
	var psides := clampi(int(td.get("sides", 6)), 4, 12)
	var ts := new_arrays()
	feet.clear()
	for deg: float in [60.0, 180.0, 300.0]:
		var a3 := deg_to_rad(deg)
		var foot_r := _kerb_mid(pit, a3 + rotation.y)
		var f := Vector3(sin(a3) * foot_r, foot_y - 0.02, cos(a3) * foot_r)
		feet.append(f)
		var dir := (apex - f).normalized()
		var tip := apex + dir * past
		_pole(ts, f, tip, pole_r, pole_r * 0.8, psides, wood, wood_soot, apex_y)
	# The lashing: a few turns of cord round the crossing.
	var lash := PackedVector2Array([Vector2(0.0, apex_y - 0.05), Vector2(pole_r * 2.1, apex_y - 0.05), Vector2(pole_r * 2.3, apex_y), Vector2(pole_r * 2.1, apex_y + 0.05), Vector2(0.0, apex_y + 0.05)])
	var lcol := PackedColorArray()
	for i in lash.size():
		lcol.append(cord)
	lathe(ts, lash, lcol, 8, MATTE)
	tripod = _mesh("Tripod", ts, true)
	# The fire's light on it, from the flame under its belly.
	firelight = OmniLight3D.new()
	firelight.name = "Firelight"
	firelight.position = Vector3(0.0, float(fl.get("at_m", 0.1)), 0.0)
	firelight.omni_range = maxf(float(fl.get("range_m", 1.8)), 0.2)
	firelight.omni_attenuation = float(fl.get("attenuation", 1.0))
	firelight.light_cull_mask = LAYER
	firelight.shadow_enabled = false
	firelight.light_specular = 0.0
	firelight.light_color = Torch.fire_color()
	share = maxf(float(fl.get("share", 0.3)), 0.0)
	add_child(firelight)
	# The pot's collision: a hull round its belly, under its rim.
	collision = PropCollision.body(self)
	var pts := PackedVector3Array()
	for q: Vector2 in outer:
		var y := minf(q.y, hull_top)
		for k in sides:
			var a4 := TAU * float(k) / float(sides)
			pts.append(Vector3(cos(a4) * q.x, y, sin(a4) * q.x))
		if q.y >= hull_top:
			break
	PropCollision.hull(collision, pts)


## How far from the hearth's middle the middle of its kerb lies in the
## direction `yaw` (scene, as a node's yaw: 0 is +z): halfway between the
## kerb's lip over the pit and its outer edge (TombBuild.pit, pit_poly: a
## polygon with a side's middle at every TAU / sides from +x, so a corner
## lies further out than a side). Among the old ring's stones (0.62 m)
## where the style has no pit.
static func _kerb_mid(pit: Dictionary, yaw: float) -> float:
	if pit.is_empty():
		return 0.62
	var n := maxi(int(pit.sides), 3)
	var mid := (float(pit.r) - TombBuild.PIT_LIP_M + float(pit.r) + float(pit.kerb_w)) * 0.5
	# The direction's angle in x/z from +x (pit_poly's), and off the nearest
	# side's middle.
	var phi := atan2(cos(yaw), sin(yaw))
	var step := TAU / float(n)
	var off := phi - roundf(phi / step) * step
	return mid / cos(off)


func _mesh(nm: String, st: Dictionary, shadow: bool) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.arrays)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = RuinBuilder.material_lit()
	mi.layers = LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	triangles += (st.arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return mi


# --- Geometry (shared with the shaman's ladle, HearthFolk) -------------------

## Empty mesh arrays to fill (lathe(), the rods, the poles; the shaman's
## ladle builds on them too): {"arrays": [vertex, normal, colour, uv]}.
static func new_arrays() -> Dictionary:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	a[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	a[Mesh.ARRAY_COLOR] = PackedColorArray()
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	return {"arrays": a}


static func _merge(into: Dictionary, from: Dictionary) -> void:
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV]:
		var dst = into.arrays[k]
		dst.append_array(from.arrays[k])
		into.arrays[k] = dst


## One triangle, its corners' normals and colours, wound so the side its
## normals face is Godot's front (clockwise seen from there: the lit
## material draws both sides and turns a back face's normal round).
static func tri(st: Dictionary, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color, kind: float) -> void:
	var g := (b - a).cross(c - a)
	if g.length_squared() < 1e-14:
		return
	var arr: Array = st.arrays
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	if g.dot(na + nb + nc) > 0.0:
		v.append_array([a, c, b])
		n.append_array([na, nc, nb])
		col.append_array([ca, cc, cb])
	else:
		v.append_array([a, b, c])
		n.append_array([na, nb, nc])
		col.append_array([ca, cb, cc])
	var m := Vector2(kind, 0.0)
	uv.append_array([m, m, m])
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_TEX_UV] = uv


## A surface of revolution round local y (then placed by `xf`): `prof`
## [Vector2(r, y)...] from one end to the other, `sides` round, each point
## coloured from `cols`; normals smooth round and along the profile, from
## its own slope (out of the side the profile has on its right as it runs:
## outward going up the outside, inward coming down the inside). A point
## repeated is a crease.
static func lathe(st: Dictionary, prof: PackedVector2Array, cols: PackedColorArray, sides: int, kind: float, xf := Transform3D.IDENTITY) -> void:
	var np := prof.size()
	if np < 2:
		return
	var seg_n: Array[Vector2] = []
	for i in np - 1:
		var t := prof[i + 1] - prof[i]
		seg_n.append(Vector2(t.y, -t.x).normalized() if t.length() > 1e-6 else Vector2.ZERO)
	var pn: Array[Vector2] = []
	for i in np:
		var a := seg_n[i - 1] if i > 0 else Vector2.ZERO
		var c := seg_n[i] if i < np - 1 else Vector2.ZERO
		if i > 0 and i < np - 1 and (prof[i - 1].distance_to(prof[i]) < 1e-6 or prof[i + 1].distance_to(prof[i]) < 1e-6):
			pn.append(a if a != Vector2.ZERO else c)
		else:
			var s := a + c
			pn.append(s.normalized() if s.length() > 1e-6 else Vector2(0.0, 1.0))
	var bs := xf.basis
	for i in np - 1:
		if prof[i].distance_to(prof[i + 1]) < 1e-6:
			continue
		# A crease's own side: the segment's normal at both its ends.
		var n0 := pn[i]
		var n1 := pn[i + 1]
		if i > 0 and prof[i - 1].distance_to(prof[i]) < 1e-6:
			n0 = seg_n[i]
		if i + 2 < np and prof[i + 1].distance_to(prof[i + 2]) < 1e-6:
			n1 = seg_n[i]
		for j in sides:
			var a0 := TAU * float(j) / float(sides)
			var a1 := TAU * float(j + 1) / float(sides)
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			var p00 := xf * (d0 * prof[i].x + Vector3.UP * prof[i].y)
			var p01 := xf * (d1 * prof[i].x + Vector3.UP * prof[i].y)
			var p10 := xf * (d0 * prof[i + 1].x + Vector3.UP * prof[i + 1].y)
			var p11 := xf * (d1 * prof[i + 1].x + Vector3.UP * prof[i + 1].y)
			var m00 := (bs * (d0 * n0.x + Vector3.UP * n0.y)).normalized()
			var m01 := (bs * (d1 * n0.x + Vector3.UP * n0.y)).normalized()
			var m10 := (bs * (d0 * n1.x + Vector3.UP * n1.y)).normalized()
			var m11 := (bs * (d1 * n1.x + Vector3.UP * n1.y)).normalized()
			tri(st, p00, p10, p11, m00, m10, m11, cols[i], cols[i + 1], cols[i + 1], kind)
			tri(st, p00, p11, p01, m00, m11, m01, cols[i], cols[i + 1], cols[i], kind)


## A rod of square section `r` (half its side) along polyline `pts`, its
## faces flat.
static func _rod(st: Dictionary, pts: PackedVector3Array, r: float, col: Color, kind: float) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var ax := b - a
		if ax.length() < 1e-6:
			continue
		var u := ax.normalized()
		var s := u.cross(Vector3.UP if absf(u.y) < 0.9 else Vector3.RIGHT).normalized()
		var t := u.cross(s).normalized()
		var ring := [s * r + t * r, -s * r + t * r, -s * r - t * r, s * r - t * r]
		for k in 4:
			var o0: Vector3 = ring[k]
			var o1: Vector3 = ring[(k + 1) % 4]
			var nrm := (o0 + o1).normalized()
			tri(st, a + o0, b + o0, b + o1, nrm, nrm, nrm, col, col, col, kind)
			tri(st, a + o0, b + o1, a + o1, nrm, nrm, nrm, col, col, col, kind)


## A box `size` placed by `xf`, its faces flat.
static func _box(st: Dictionary, xf: Transform3D, size: Vector3, col: Color, kind: float) -> void:
	var h := size * 0.5
	for ax in 3:
		for sgn: float in [-1.0, 1.0]:
			var nrm := Vector3.ZERO
			nrm[ax] = sgn
			var u := Vector3.ZERO
			u[(ax + 1) % 3] = h[(ax + 1) % 3]
			var w := Vector3.ZERO
			w[(ax + 2) % 3] = h[(ax + 2) % 3]
			var c := nrm * h[ax]
			var p := [xf * (c - u - w), xf * (c + u - w), xf * (c + u + w), xf * (c - u + w)]
			var n := (xf.basis * nrm).normalized()
			tri(st, p[0], p[1], p[2], n, n, n, col, col, col, kind)
			tri(st, p[0], p[2], p[3], n, n, n, col, col, col, kind)


## A pole from `a` to `b`, `ra` thick at its foot and `rb` at its top,
## `sides` round, smooth round; its colour toward `dark` (the smoke's soot)
## above the apex's height less a metre; its top end capped.
static func _pole(st: Dictionary, a: Vector3, b: Vector3, ra: float, rb: float, sides: int, col: Color, dark: Color, apex_y: float) -> void:
	var u := (b - a).normalized()
	var s := u.cross(Vector3.UP if absf(u.y) < 0.9 else Vector3.RIGHT).normalized()
	var t := u.cross(s).normalized()
	var n_seg := 4
	for i in n_seg:
		var f0 := float(i) / float(n_seg)
		var f1 := float(i + 1) / float(n_seg)
		var c0 := a.lerp(b, f0)
		var c1 := a.lerp(b, f1)
		var r0 := lerpf(ra, rb, f0)
		var r1 := lerpf(ra, rb, f1)
		var k0 := col.lerp(dark, smoothstep(apex_y - 1.0, apex_y, c0.y))
		var k1 := col.lerp(dark, smoothstep(apex_y - 1.0, apex_y, c1.y))
		for j in sides:
			var a0 := TAU * float(j) / float(sides)
			var a1 := TAU * float(j + 1) / float(sides)
			var d0 := s * cos(a0) + t * sin(a0)
			var d1 := s * cos(a1) + t * sin(a1)
			tri(st, c0 + d0 * r0, c1 + d0 * r1, c1 + d1 * r1, d0, d0, d1, k0, k1, k1, MATTE)
			tri(st, c0 + d0 * r0, c1 + d1 * r1, c0 + d1 * r0, d0, d1, d1, k0, k1, k0, MATTE)
	var kt := col.lerp(dark, smoothstep(apex_y - 1.0, apex_y, b.y))
	for j in sides:
		var a0 := TAU * float(j) / float(sides)
		var a1 := TAU * float(j + 1) / float(sides)
		tri(st, b, b + (s * cos(a0) + t * sin(a0)) * rb, b + (s * cos(a1) + t * sin(a1)) * rb, u, u, u, kt, kt, kt, MATTE)
