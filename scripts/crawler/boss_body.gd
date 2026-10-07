class_name BossBody
extends Node3D
## The snake's body as baked sprites (design 6 Oct §ET.8, §EY.5;
## bosses.json bosses.desert body): a creature body, not the cloaked rig,
## built as a little painted model (§ES: the light painted into its
## colours, the shade under it tinted navy, no shine) and rendered once, as
## FigureSprite renders the rescuer, from eight ways round at three
## heights: a head with its mouth shut, a head with its jaws open (the
## strike), and one length of body. In play the long body is a chain of
## those body sprites, each at its own place on the path the head took
## (Boss keeps it), each turned to its own heading, so the body bends
## through the corridors and lies in a coil (§EY.5's first guess). The last
## third tapers to the tail. A placeholder bake: chunky, in the era's way.

## bosses.json bosses.<world>.body.
var D: Dictionary = {}

## The sprites: the head shut and open, then the body, head end first.
var head_shut: FigureSprite
var head_open: FigureSprite
var segs: Array[FigureSprite] = []
var girth := 0.38
var spacing := 0.28
var head_len := 0.55
var baked := false

## The paint (§ES.2): an olive-brown back crossed every third length by a
## near-black band (so it reads as one long banded body against the tomb's
## sandy stone in the amber light), darker flanks, the belly pale in its
## own shade, the eye, the mouth.
const BACK := Color("#6e5c38")
const SADDLE := Color("#1e1810")
const FLANK := Color("#5b4a2c")
const BELLY := Color("#c0ad80")
## A dark band on every this many lengths of body.
const BAND_EVERY := 3
const EYE := Color("#0d0b08")
const EYE_RING := Color("#d6c48a")
const MOUTH := Color("#6e2626")
const FANG := Color("#ddd5bb")


## Build the chain for boss `def` (bosses.json bosses.<world>); the sheets
## come later (bake()).
func setup(def: Dictionary) -> void:
	var b: Dictionary = def.get("body", {})
	D = b
	girth = float(b.get("girth_m", 0.38))
	spacing = float(b.get("spacing_m", 0.28))
	head_len = float(b.get("head_m", 0.55))
	var length := float(b.get("length_m", 9.0))
	var n := maxi(int(round((length - head_len) / maxf(spacing, 0.05))), 4)
	head_shut = FigureSprite.new()
	head_shut.name = "Head"
	add_child(head_shut)
	head_open = FigureSprite.new()
	head_open.name = "HeadOpen"
	add_child(head_open)
	head_open.visible = false
	for i in n:
		var s := FigureSprite.new()
		s.name = "Seg%d" % i
		add_child(s)
		segs.append(s)
	visible = false


## How wide body length `i` is against the full girth: the last third
## tapers to the tail's tip.
func taper(i: int) -> float:
	var u := float(i) / maxf(segs.size() - 1, 1)
	return 1.0 if u < 0.62 else lerpf(1.0, 0.28, pow((u - 0.62) / 0.38, 0.9))


## The sheets: rendered in their own little worlds (FigureSprite.bake),
## one after another; blank sheets with no renderer (the checks).
func bake(host: Node) -> void:
	var seg_h := girth * 1.15
	var head_h := maxf(head_len * 1.1, girth * 1.7)
	var px_seg := int(D.get("px_seg", 28))
	var px_head := int(D.get("px_head", 40))
	var sheets: Array = []
	for part in [["seg", seg_h, px_seg], ["shut", head_h, px_head], ["open", head_h, px_head], ["band", seg_h, px_seg]]:
		var h := float(part[1])
		var px := int(part[2])
		var sheet: Image
		if DisplayServer.get_name() == "headless":
			var cols := int(FigureSprite.SP.get("around", 8))
			var rows := (FigureSprite.SP.get("rows_deg", [-25, 0, 30]) as Array).size()
			sheet = Image.create(int(round(px * 0.75)) * cols, px * rows, false, Image.FORMAT_RGBA8)
		else:
			var model := Node3D.new()
			match str(part[0]):
				"seg":
					model.add_child(_segment_mesh(false))
				"band":
					model.add_child(_segment_mesh(true))
				"shut":
					model.add_child(_head_mesh(false))
				"open":
					model.add_child(_head_mesh(true))
			sheet = await FigureSprite.bake(host, model, h, px, 1, Callable())
		sheets.append([sheet, h])
	# The body's eye height for the rows: its own middle. Every third length
	# banded.
	for i in segs.size():
		var sh: Array = sheets[3] if i % BAND_EVERY == BAND_EVERY - 1 else sheets[0]
		segs[i].setup(sh[0], float(sh[1]), 1, girth * 0.5, 0.0)
	head_shut.setup(sheets[1][0], float(sheets[1][1]), 1, girth * 0.6, 0.0)
	head_open.setup(sheets[2][0], float(sheets[2][1]), 1, girth * 0.6, 0.0)
	for i in segs.size():
		var k := taper(i)
		segs[i].scale = Vector3.ONE * k
	baked = true


## Place the chain: the head at `head` facing `head_dir` (flat), its mouth
## `open`; body length i at seg_pos[i] facing seg_dir[i].
func pose(head: Vector3, head_dir: Vector3, open: bool, seg_pos: Array, seg_dir: Array) -> void:
	var hy := atan2(-head_dir.x, -head_dir.z)
	for h: FigureSprite in [head_shut, head_open]:
		h.global_position = head
		h.yaw = hy
	head_shut.visible = not open
	head_open.visible = open
	for i in mini(segs.size(), seg_pos.size()):
		var s := segs[i]
		s.global_position = seg_pos[i]
		var d: Vector3 = seg_dir[i]
		s.yaw = atan2(-d.x, -d.z)


# --- The model (the bake's source) -------------------------------------------

## Painted (§ES.2): `c` lit from above as the bake's even light shows it:
## the top a little lighter, the underside in the scene's shade (navy).
static func _paint(c: Color, up: float) -> Color:
	var lit := c.lightened(0.12 * clampf(up, 0.0, 1.0))
	return Prelit.ao_tint(lit, clampf(0.62 + 0.38 * up, 0.0, 1.0))


static func _unshaded() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	# The paint is in sRGB, as every colour in the data is.
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## One length of body along z, lying on y 0: an eight-sided tube,
## flattened a little (snakes are); `band`: a dark band round its back and
## flanks across its middle.
func _segment_mesh(band: bool) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := girth * 0.5
	var h := girth * 0.44
	var cy := h
	# A little longer than thick: the lengths overlap two or three deep, so
	# the chain reads as one body.
	var l := girth * 0.95
	var sides := 8
	var ring := func(z: float, k: float) -> Array:
		var out: Array = []
		for s in sides:
			var a := TAU * (s + 0.5) / sides
			out.append(Vector3(cos(a) * w * k, cy + sin(a) * h * k, z))
		return out
	# Rounded off at both ends, so the overlapping lengths melt into one
	# body instead of a stack of drums.
	var rings: Array = [ring.call(-l * 0.5, 0.62), ring.call(-l * 0.3, 0.95), ring.call(0.0, 1.0), ring.call(l * 0.3, 0.95), ring.call(l * 0.5, 0.62)]
	var col := func(p: Vector3, z: float) -> Color:
		var up := clampf((p.y - cy) / h, -1.0, 1.0)
		var side := absf(p.x) / w
		var c: Color
		if up < -0.35:
			c = BELLY.darkened(0.15)
		elif band and up > -0.2 and absf(z) < l * 0.3:
			c = SADDLE
		elif up > 0.2:
			c = BACK
		else:
			c = FLANK.lerp(BACK, side * 0.3)
		return _paint(c, up * 0.5 + 0.5)
	for ri in rings.size() - 1:
		var a: Array = rings[ri]
		var b: Array = rings[ri + 1]
		for s in sides:
			var s2 := (s + 1) % sides
			for p: Vector3 in [a[s], b[s], b[s2], a[s], b[s2], a[s2]]:
				st.set_color(col.call(p, p.z))
				st.add_vertex(p)
	# The ends: flat caps (seen only end on).
	for capr: Array in [rings[0], rings[-1]]:
		var c3 := Vector3(0.0, cy, (capr[0] as Vector3).z)
		for s in sides:
			for p: Vector3 in [c3, capr[s], capr[(s + 1) % sides]]:
				st.set_color(col.call(p, 0.4 * l))
				st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _unshaded()
	return mi


## The head, snout toward -z, its back end at z +head_len*0.4: a broad
## flat wedge, wide at the jaw's hinge, the snout rounded; dark brows over
## small eyes with a pale ring. `open`: the lower jaw dropped and the head
## tipped up, the mouth's dull red inside and two fangs.
func _head_mesh(open: bool) -> Node3D:
	var root := Node3D.new()
	var L := head_len
	var W := girth * 1.15
	var H := girth * 0.62
	var y0 := girth * 0.18
	# The upper head: a wedge of quads, its sections from the back of the
	# head to the snout: [z, half width, height].
	var secs: Array = [[L * 0.4, W * 0.42, H * 0.95], [L * 0.1, W * 0.5, H], [-L * 0.25, W * 0.4, H * 0.82], [-L * 0.5, W * 0.24, H * 0.55], [-L * 0.6, W * 0.12, H * 0.36]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sec_pts := func(sc: Array) -> Array:
		var z := float(sc[0])
		var hw := float(sc[1])
		var hh := float(sc[2])
		# Top, upper side, lower side, bottom (the jaw line), each side.
		return [Vector3(-hw * 0.55, y0 + hh, z), Vector3(hw * 0.55, y0 + hh, z), Vector3(hw, y0 + hh * 0.45, z), Vector3(hw * 0.85, y0, z), Vector3(-hw * 0.85, y0, z), Vector3(-hw, y0 + hh * 0.45, z)]
	var paint := func(p: Vector3) -> Color:
		var up := clampf((p.y - y0) / H, 0.0, 1.0)
		var c := BACK if up > 0.6 else (FLANK if up > 0.2 else BELLY.darkened(0.2))
		if up > 0.55 and p.z > L * 0.18:
			# A dark band across the back of the head.
			c = SADDLE
		return _paint(c, up)
	for k in range(secs.size() - 1):
		var a: Array = sec_pts.call(secs[k])
		var b: Array = sec_pts.call(secs[k + 1])
		for s in 6:
			var s2 := (s + 1) % 6
			for p: Vector3 in [a[s], b[s], b[s2], a[s], b[s2], a[s2]]:
				st.set_color(paint.call(p))
				st.add_vertex(p)
	# The back of the head and the snout's tip, closed.
	for cap in [[secs[0], 1.0], [secs[-1], -1.0]]:
		var pts: Array = sec_pts.call(cap[0])
		var c3 := Vector3(0.0, y0 + float(cap[0][2]) * 0.5, float(cap[0][0]))
		for s in 6:
			for p: Vector3 in [c3, pts[s], pts[(s + 1) % 6]]:
				st.set_color(paint.call(p))
				st.add_vertex(p)
	var upper := MeshInstance3D.new()
	upper.mesh = st.commit()
	upper.material_override = _unshaded()
	root.add_child(upper)
	# The eyes: small, dark, a pale ring, under a dark brow, well forward.
	for sd: float in [-1.0, 1.0]:
		var e := Vector3(sd * W * 0.36, y0 + H * 0.7, -L * 0.2)
		CreatureBodies.box(root, Vector3(0.012, 0.05, 0.075), e + Vector3(sd * 0.005, 0.0, 0.0), _paint(EYE_RING, 0.8))
		CreatureBodies.box(root, Vector3(0.016, 0.034, 0.052), e + Vector3(sd * 0.009, 0.0, 0.0), EYE)
		CreatureBodies.box(root, Vector3(0.05, 0.022, 0.11), e + Vector3(sd * -0.006, 0.032, 0.0), _paint(BACK.darkened(0.3), 1.0))
	# The lower jaw: a flat wedge under the head; open, dropped and the
	# mouth's inside showing, two fangs hanging from the upper jaw.
	var jaw := Node3D.new()
	root.add_child(jaw)
	jaw.position = Vector3(0.0, y0, L * 0.3)
	CreatureBodies.box(jaw, Vector3(W * 0.78, girth * 0.12, L * 0.82), Vector3(0.0, -girth * 0.04, -L * 0.42), _paint(BELLY, 0.2))
	if open:
		jaw.rotation.x = -0.7
		CreatureBodies.box(root, Vector3(W * 0.7, 0.02, L * 0.7), Vector3(0.0, y0 - 0.005, -L * 0.18), _paint(MOUTH, 0.5))
		CreatureBodies.box(jaw, Vector3(W * 0.66, 0.02, L * 0.7), Vector3(0.0, girth * 0.03, -L * 0.4), _paint(MOUTH, 0.3))
		for sd2: float in [-1.0, 1.0]:
			CreatureBodies.cone(root, 0.016, 0.003, girth * 0.32, Vector3(sd2 * W * 0.2, y0 - girth * 0.13, -L * 0.42), FANG)
		root.rotation.x = 0.35
	# CreatureBodies' parts (the eyes, the brows, the jaw, the fangs) are lit
	# like the open world's creatures: shown flat instead, as painted.
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == upper:
			continue
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var src := mi.material_override
		if src is ShaderMaterial:
			var c: Variant = (src as ShaderMaterial).get_shader_parameter("albedo")
			if c is Color:
				sm.albedo_color = c
		elif src is StandardMaterial3D:
			sm.albedo_color = (src as StandardMaterial3D).albedo_color
		mi.material_override = sm
	return root
