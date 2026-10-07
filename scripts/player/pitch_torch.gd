class_name PitchTorch
## The pitch torch (design 6 Oct §EZ.2, data/torch.json pitch_head): every
## torch in Torchfire 1, in hand, planted and in the bundle by the hearth.
## The open world (Torchfire 2) keeps §CP's burnt end (Torch.ember_node).
## Bottom to top it is pitch, coal and flame:
##   - the wrap ("Wrap"): the stick's top wound in bands of fibre or bark
##     soaked in pine pitch or birch tar (§EH: no metal). Six flat sides
##     lined up with the stick's (never a ball, never rounded), swell times
##     the stick's radius and length_m long, straight, with a flat top. Each
##     band is a strip whose lower edge stands proud (STEP), so the bands
##     show as small steps in the silhouette, and a few drips of pitch run
##     down the stick below it (drips: count, length_m). Painted, not lit
##     (shaders/pitch_head.gdshader: light shows the paint, never shades
##     or shines on it, and in the dark it is dark; no specular, no normal
##     map): near-black pitch, each strip's edge a shade lighter, and while
##     lit the top band thins to dark amber, bubbling, under the coal
##     (colors);
##   - the coal ("Coal"): the glowing top of the wrap, the burnt end's
##     shader (shaders/torch_ember.gdshader: the fire's bands in its cracks
##     on the texel grid) breathing with the light (torch.json ember,
##     Torch.ember_glow), shown only while lit;
##   - the flame ("Flame"): the campfire's one flame card (§BZ,
##     Torch.flame_node: look.json fire.flame.torch's size and scroll) on a
##     texel grid flame.texel_scale times coarser than the campfire's, so
##     it reads chunky close in first person, with its couple of
##     single-pixel sparks; shown only while lit. It leans the way the air
##     goes past it (Lean: against your motion, toward an airway's draft)
##     and stretches at a sprint. Nothing about it can put the torch out
##     (§EZ.1).
## Unlit (the bundle, a doused torch with burn left) it is the wrap alone;
## burnt out, as built (the owner hides the head: a bare stick).

static var P: Dictionary = Tuning.table("torch").get("pitch_head", {})
static var H: Dictionary = P.get("head", {})
## How far each strip's lower edge stands proud of the wrap's radius, and
## its top tucks in (a share of the radius): the bands' steps.
const STEP := 0.07
## The coal is the top band's last two texel rows.
const COAL_ROWS := 2
## The coal stands this much proud of the wrap (a share of its radius, and
## metres over its flat top), so the two never fight for the same pixels.
const COAL_SWELL := 1.04
const COAL_PROUD_M := 0.0015
## The flame's half of the light's flicker at a stand; the coal's breath is
## the other half (torch.json light.flicker_amount; at a sprint the flame's
## share grows by light.sprint_flicker_scale).
const FLAME_FLICKER_SHARE := 0.5
## How far a torch burnt low collapses its flame toward the low fire's reds
## (look.json fire.flame.low; the snuff rules' warning takes it all the way).
const GUTTER_LOW := 0.6
## The wrap draws after a hearth's ground decals (Campfire._ground_glow:
## render_priority 0 and 1), which would paint the bundle lying by the
## fire orange (shaders/pitch_head.gdshader).
const WRAP_PRIORITY := 2


static func sides() -> int:
	return maxi(int(H.get("sides", 6)), 3)


## The wrap's length (m).
static func length_m() -> float:
	return float(H.get("length_m", 0.12))


static func bands() -> int:
	return maxi(int(H.get("bands", 4)), 1)


static func texels_m() -> float:
	return float(H.get("texels_m", 150.0))


## A band's height in texel rows (its proud edge and its pitch).
static func rows() -> int:
	return maxi(floori(length_m() / bands() * texels_m() + 0.5), COAL_ROWS + 2)


## The coal's height up the wrap (m): the top band's last COAL_ROWS rows.
static func coal_h() -> float:
	return length_m() / bands() * float(COAL_ROWS) / float(rows())


## The flame's size against the campfire's card: look.json
## fire.flame.torch.scale for a planted torch; `view`, the torch in hand,
## times flame.view_scale (drawn half a metre from the eye, a true-size
## flame would fill the right of the view and stream past your face when
## it leans back).
static func flame_size(view := false) -> float:
	var s := float((Campfire.FL.get("torch", {}) as Dictionary).get("scale", 0.32))
	if view:
		s *= float((P.get("flame", {}) as Dictionary).get("view_scale", 0.55))
	return s


## The flame card's texel grid: the campfire's (look.json fire.flame.texels)
## over flame.texel_scale.
static func flame_texels() -> Vector2:
	var tx: Array = Campfire.FL.get("texels", [32, 48])
	var k := maxf(float((P.get("flame", {}) as Dictionary).get("texel_scale", 1.6)), 0.1)
	return Vector2(maxf(roundf(float(tx[0]) / k), 4.0), maxf(roundf(float(tx[1]) / k), 4.0))


## Does an airway's draft lean the flame (lean.toward_draft)?
static func toward_draft() -> bool:
	return bool((P.get("lean", {}) as Dictionary).get("toward_draft", true))


## A pitch head for a stick `stick_r` m thick at its top (a six-sided
## stick, its corners where CylinderMesh puts them): "PitchHead", its
## origin where the wrap starts up the stick, +y up the stick to the wrap's
## flat top at length_m. With `fire`, the coal and the flame
## (`flame_size_v` times the campfire's card; flame_size() when not given),
## hidden until set_lit. Seeded by `seed_v`: no two wraps or drips alike.
static func head_node(stick_r: float, seed_v: int, fire := true, flame_size_v := -1.0) -> Node3D:
	var n := Node3D.new()
	n.name = "PitchHead"
	n.set_meta("pitch_head", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var phase := rng.randf() * 50.0
	var built := _build(stick_r, rng)
	var wrap := MeshInstance3D.new()
	wrap.name = "Wrap"
	wrap.mesh = built.wrap
	wrap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wrap.material_override = _wrap_material(phase)
	n.add_child(wrap)
	if fire:
		var coal := MeshInstance3D.new()
		coal.name = "Coal"
		coal.mesh = built.coal
		coal.position = Vector3(0.0, length_m() - coal_h(), 0.0)
		coal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		coal.material_override = _coal_material(phase, float(built.coal_len))
		coal.visible = false
		n.add_child(coal)
		var fl := Torch.flame_node(flame_size_v if flame_size_v > 0.0 else flame_size())
		# Its round foot sinks a little into the coal (§BZ's teardrop).
		fl.position = Vector3(0.0, length_m() - coal_h() * 0.25, 0.0)
		var card := fl.get_node_or_null("Card") as MeshInstance3D
		if card:
			(card.material_override as ShaderMaterial).set_shader_parameter("texels", flame_texels())
		fl.visible = false
		n.add_child(fl)
	n.set_meta("lit", false)
	return n


## Lit or not: the coal and the flame show, and the top band thins; put
## out, its smoke stops at once (the wrap stays in view, and the column
## with it, so it is hidden here; smoke() shows it again).
static func set_lit(head: Node3D, on: bool) -> void:
	if bool(head.get_meta("lit", false)) == on and head.has_meta("lit_set"):
		return
	head.set_meta("lit", on)
	head.set_meta("lit_set", true)
	for c in ["Coal", "Flame"]:
		var part := head.get_node_or_null(c) as Node3D
		if part:
			part.visible = on
	var col = head.get_meta("smoke_col") if head.has_meta("smoke_col") else null
	if not on and col != null and is_instance_valid(col):
		(col as Node3D).visible = false
	var wrap := head.get_node_or_null("Wrap") as MeshInstance3D
	if wrap and wrap.material_override is ShaderMaterial:
		(wrap.material_override as ShaderMaterial).set_shader_parameter("heat", 1.0 if on else 0.0)


## A burnt-out torch's embers (Torch, design 6 Oct §FJ.4; Mike, 7 Oct):
## the coal alone, glowing at `share` of a lit coal's glow, fading as they
## die; no flame; 0 hides it (a dead head).
static func set_embers(head: Node3D, share: float) -> void:
	var coal := head.get_node_or_null("Coal") as MeshInstance3D
	if coal == null:
		return
	coal.visible = share > 0.0
	var fl := head.get_node_or_null("Flame") as Node3D
	if fl:
		fl.visible = false
	if share > 0.0 and coal.material_override is ShaderMaterial:
		(coal.material_override as ShaderMaterial).set_shader_parameter("glow", share * float(Torch.EMBER.get("gutter_glow", 0.72)))


## The coal's glow now (Torch.ember_glow; guttering draws it lower, so
## fewer of its hot bands show: ember.gutter_glow), as Torch.set_glow does
## for the burnt end.
static func set_glow(head: Node3D, glow: float, it: Dictionary) -> void:
	var coal := head.get_node_or_null("Coal") as MeshInstance3D
	if coal and coal.material_override is ShaderMaterial:
		(coal.material_override as ShaderMaterial).set_shader_parameter("glow", glow * (float(Torch.EMBER.get("gutter_glow", 0.72)) if Torch.guttering(it) else 1.0))


## How far the flame has collapsed toward the low fire's reds and height
## (0 a full flame .. 1 a red flicker; look.json fire.flame.low): a
## guttering torch's flame gutters with its coal.
static func set_low(head: Node3D, low: float) -> void:
	low = clampf(low, 0.0, 1.0)
	if absf(float(head.get_meta("low", -1.0)) - low) < 1e-3:
		return
	head.set_meta("low", low)
	var card := head.get_node_or_null("Flame/Card") as MeshInstance3D
	if card and card.material_override is ShaderMaterial:
		(card.material_override as ShaderMaterial).set_shader_parameter("low", low)


## Stand the flame on the head this frame: upright along `up` (the world's,
## not the stick's: a flame rises however the torch is held), tipped by
## the lean, `lean.stretch` times its height, shorter as it gutters
## (set_low). The card turns to face the camera about that axis itself
## (shaders/flame.gdshader).
static func pose(head: Node3D, lean: Lean, up: Vector3) -> void:
	var fl := head.get_node_or_null("Flame") as Node3D
	if fl == null or not fl.visible:
		return
	var u := up.normalized()
	var d := lean.deg()
	if d > 1e-3:
		u = u.rotated(u.cross(lean.tilt / d).normalized(), deg_to_rad(d))
	var side := u.cross(Vector3.FORWARD if absf(u.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var low := float(head.get_meta("low", 0.0))
	var h := lean.stretch * lerpf(1.0, float((Campfire.FL.get("low", {}) as Dictionary).get("height_scale", 0.45)), low)
	fl.global_basis = Basis(side, u * h, side.cross(u))


## How far the flame leans from `up` now (degrees), as drawn.
static func drawn_lean_deg(head: Node3D, up: Vector3) -> float:
	var fl := head.get_node_or_null("Flame") as Node3D
	if fl == null:
		return 0.0
	return rad_to_deg(fl.global_basis.y.normalized().angle_to(up.normalized()))


## The flame's flicker on the light (§BZ: Campfire's two-layer value noise
## at light.flicker_hz), FLAME_FLICKER_SHARE of light.flicker_amount at a
## stand, more as the air reaches a sprint (light.sprint_flicker_scale);
## the coal's breath (Torch.ember_glow) multiplies on top. `seed_v` the
## torch's own, so no two flicker together.
static func flicker(t: float, seed_v: float, air_share: float) -> float:
	var L: Dictionary = Torch.L
	var hz := float(L.get("flicker_hz", 9.0))
	var amount := float(L.get("flicker_amount", 0.18)) * FLAME_FLICKER_SHARE * lerpf(1.0, float(L.get("sprint_flicker_scale", 2.0)), clampf(air_share, 0.0, 1.0))
	return 1.0 + amount * (0.7 * (Campfire._vnoise(t * hz, seed_v) * 2.0 - 1.0) + 0.3 * (Campfire._vnoise(t * hz * 2.7, seed_v + 11.0) * 2.0 - 1.0))


## The flame's smoke this frame (§CV, Smoke.tick_flame): as built for the
## torch (the embers row, by the torch flame's size, its foot at the top
## of the wrap, `air` the head's own motion so it trails), its colours
## pulled smoke.soot_scale toward soot (smoke.json outlets.soot: a
## navy-black, so it darkens and never goes a neutral grey, R3).
static func smoke(head: Node3D, up: Vector3, air := Vector3.ZERO) -> void:
	if not Smoke.ON:
		return
	var col = head.get_meta("smoke_col") if head.has_meta("smoke_col") else null
	if col == null or not is_instance_valid(col):
		col = Smoke.column(head, "Smoke", soot_colours())
		var m: ShaderMaterial = (col as Node3D).get_meta("mat")
		m.set_shader_parameter("colour_night", soot_night(m))
		head.set_meta("smoke_col", col)
	var top := head.global_transform * Vector3(0.0, length_m(), 0.0)
	Smoke.tick_flame(head, top + up * 0.04, up, flame_size(), "embers", air)


static func soot_share() -> float:
	return clampf(float((P.get("smoke", {}) as Dictionary).get("soot_scale", 0.25)), 0.0, 1.0)


static func soot_color() -> Color:
	return Color(str(((Smoke.D.get("outlets", {}) as Dictionary).get("soot", {}) as Dictionary).get("colour", "#0A0C20")))


## The smoke's day colours (smoke.json hearth.look), pulled toward soot.
static func soot_colours() -> Dictionary:
	var out := {}
	for key in ["colour_near", "colour_far", "colour_shade"]:
		out[key] = Color(str(Smoke.LOOK.get(key, "#8FA0C8"))).lerp(soot_color(), soot_share()).to_html(false)
	return out


## The smoke's moonlit colour (what it is underground, where it is always
## night), pulled toward soot: linear, for the shader's colour_night.
static func soot_night(m: ShaderMaterial) -> Vector3:
	var s := soot_color().srgb_to_linear()
	return smoke_night(m).lerp(Vector3(s.r, s.g, s.b), soot_share())


## The smoke shader's own moonlit colour (colour_night's default, linear;
## the headless renderer has no defaults, so the shader's value then).
static func smoke_night(m: ShaderMaterial) -> Vector3:
	var v: Variant = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), "colour_night")
	return v if v is Vector3 else Vector3(0.035, 0.042, 0.075)


## The flame's lean (§EZ.2, pitch_head.lean): it leans the way the air
## goes past it (against your motion; toward an airway's draft), per_mps
## degrees for each m/s up to max_deg (all of it in a strong airway's
## gust, §EZ.5), stretching toward sprint_stretch of its height as the air
## reaches a sprint, and it settles over settle_s. Only the flame moves:
## nothing here can put the torch out (§EZ.1).
class Lean:
	extends RefCounted
	## Across `up`, its length the lean in degrees, pointing where the
	## flame's top goes.
	var tilt := Vector3.ZERO
	## The flame's height against its own (1 still, sprint_stretch at a
	## sprint).
	var stretch := 1.0
	## The air past it against a sprint (0 still .. 1 a sprint): the light
	## flickers harder with it (PitchTorch.flicker).
	var air_share := 0.0

	## One frame: `air` the air's motion past the flame (scene m/s: an
	## airway's draft minus your velocity), `up` the world's up. `whip`: a
	## strong airway's gust has it, and it leans flat out at max_deg the
	## way the gust blows (§EZ.5); it holds.
	func step(air: Vector3, up: Vector3, delta: float, whip := false) -> void:
		var D: Dictionary = PitchTorch.P.get("lean", {})
		var flat := air - up * air.dot(up)
		var speed := flat.length()
		var deg_now := minf(speed * float(D.get("per_mps", 6.0)), float(D.get("max_deg", 50.0)))
		if whip:
			deg_now = float(D.get("max_deg", 50.0))
		var want := flat / speed * deg_now if speed > 1e-3 else Vector3.ZERO
		air_share = clampf(speed / maxf(PlanetPlayer.SPRINT_SPEED, 0.1), 0.0, 1.0)
		var want_s := lerpf(1.0, float(D.get("sprint_stretch", 1.3)), air_share)
		# Most of the way there in settle_s (three time constants).
		var k := 1.0 - exp(-3.0 * delta / maxf(float(D.get("settle_s", 0.4)), 0.01))
		tilt = tilt.lerp(want, k)
		stretch = lerpf(stretch, want_s, k)
		# Still air, a still flame: nothing left over once it has settled.
		if want == Vector3.ZERO and tilt.length() < 0.05:
			tilt = Vector3.ZERO
		if absf(stretch - want_s) < 1e-3:
			stretch = want_s

	func deg() -> float:
		return tilt.length()


# --- The meshes -------------------------------------------------------------------

## The wrap (surface 0), its drips (surface 1) and the coal, for a stick
## `stick_r` m thick: {"wrap", "coal" (ArrayMesh), "coal_len" (the coal
## mesh's height, m)}.
static func _build(stick_r: float, rng: RandomNumberGenerator) -> Dictionary:
	var n := sides()
	var L := length_m()
	var nb := bands()
	var bh := L / nb
	var R := stick_r * float(H.get("swell", 1.35))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# From the stick out to each strip's proud lower edge (a ledge facing
	# down), up its face to its tucked-in top; the next strip's edge stands
	# out again over it.
	var inner := stick_r
	var rb := R
	var rt := R
	for i in nb:
		var y0 := bh * i
		var y1 := y0 + bh
		rb = R * (1.0 + STEP + rng.randf_range(-0.015, 0.015))
		rt = R * (1.0 - STEP + rng.randf_range(-0.01, 0.01))
		for k in n:
			_quad(st, _ring(y0, inner, k, n), _ring(y0, inner, k + 1, n), _ring(y0, rb, k + 1, n), _ring(y0, rb, k, n), Vector3.DOWN)
			_quad(st, _ring(y0, rb, k, n), _ring(y0, rb, k + 1, n), _ring(y1, rt, k + 1, n), _ring(y1, rt, k, n), _out(k + 0.5, n))
		inner = rt
	# The flat top: no dome, no rounding (§CP, §EZ.2).
	for k in n:
		_tri(st, Vector3(0.0, L, 0.0), _ring(L, rt, k, n), _ring(L, rt, k + 1, n), Vector3.UP)
	var wrap := st.commit()
	var sd := SurfaceTool.new()
	sd.begin(Mesh.PRIMITIVE_TRIANGLES)
	_drips(sd, stick_r, n, rng)
	sd.commit(wrap)
	# The coal: the top band's last rows, a hair proud of them, and the top.
	var ch := coal_h()
	var clen := ch + COAL_PROUD_M
	var r0 := lerpf(rb, rt, (bh - ch) / bh) * COAL_SWELL
	var r1 := rt * COAL_SWELL
	var sc := SurfaceTool.new()
	sc.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in n:
		_quad(sc, _ring(0.0, r0, k, n), _ring(0.0, r0, k + 1, n), _ring(clen, r1, k + 1, n), _ring(clen, r1, k, n), _out(k + 0.5, n))
		_tri(sc, Vector3(0.0, clen, 0.0), _ring(clen, r1, k, n), _ring(clen, r1, k + 1, n), Vector3.UP)
	return {"wrap": wrap, "coal": sc.commit(), "coal_len": clen}


## A few runs of pitch down the stick's flat faces below the wrap
## (head.drips: count [min, max], each length_m [min, max]), each a thin
## strip proud of the face, narrowing, swelling to a drop near its end;
## at most one to a face.
static func _drips(st: SurfaceTool, stick_r: float, n: int, rng: RandomNumberGenerator) -> void:
	var D: Dictionary = H.get("drips", {})
	var cnt: Array = D.get("count", [2, 4])
	var lens: Array = D.get("length_m", [0.02, 0.07])
	var count := clampi(rng.randi_range(int(cnt[0]), int(cnt[1])), 0, n)
	var faces: Array[int] = []
	for k in n:
		faces.append(k)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := faces[i]
		faces[i] = faces[j]
		faces[j] = t
	var apo := stick_r * cos(PI / n)
	var half := stick_r * sin(PI / n)
	# Sized for the torch in hand's stick (0.018 m), scaled to the others.
	var kw := stick_r / 0.018
	for d in count:
		var a := TAU * (faces[d] + 0.5) / n
		var nrm := Vector3(sin(a), 0.0, cos(a))
		var tng := Vector3(cos(a), 0.0, -sin(a))
		var off := rng.randf_range(-0.35, 0.35) * half
		var run := rng.randf_range(float(lens[0]), float(lens[1]))
		# Down the run: [y, half its width, how far it stands off the face];
		# it starts inside the wrap.
		var stations := [[0.006, 0.0034, 0.0022], [-run * 0.55, 0.0023, 0.0017], [-run * 0.86, 0.0031, 0.0027], [-run, 0.0009, 0.001]]
		var prev: Array = []
		for s in stations:
			var c := nrm * apo + tng * off + Vector3(0.0, float(s[0]), 0.0)
			var w := float(s[1]) * kw
			var th := float(s[2]) * kw
			var pts := [c - nrm * 0.0006 - tng * w, c + nrm * th - tng * w, c + nrm * th + tng * w, c - nrm * 0.0006 + tng * w]
			if not prev.is_empty():
				_quad(st, prev[1], prev[2], pts[2], pts[1], nrm)
				_quad(st, prev[0], prev[1], pts[1], pts[0], -tng)
				_quad(st, prev[2], prev[3], pts[3], pts[2], tng)
			prev = pts
		_quad(st, prev[0], prev[1], prev[2], prev[3], Vector3.DOWN)


## Corner `k` of an `n`-sided ring `rad` m out at height `y`, where
## CylinderMesh puts a stick's corners (x sin, z cos), so the wrap's flat
## sides line up with the stick's.
static func _ring(y: float, rad: float, k: int, n: int) -> Vector3:
	var a := TAU * float(k) / float(n)
	return Vector3(sin(a) * rad, y, cos(a) * rad)


## Straight out through the middle of side `k` (k + 0.5 for the face).
static func _out(k: float, n: int) -> Vector3:
	var a := TAU * k / float(n)
	return Vector3(sin(a), 0.0, cos(a))


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, want: Vector3) -> void:
	_tri(st, a, b, c, want)
	_tri(st, a, c, d, want)


## One triangle with its own flat normal, turned to face `want` (Godot's
## front is clockwise, as Torch._flat_tri).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	var nrm := (c - a).cross(b - a)
	if nrm.length_squared() < 1e-14:
		return
	nrm = nrm.normalized()
	if nrm.dot(want) < 0.0:
		var t := b
		b = c
		c = t
		nrm = -nrm
	for p in [a, b, c]:
		st.set_normal(nrm)
		st.add_vertex(p)


# --- The materials ----------------------------------------------------------------

## The wrap's paint (shaders/pitch_head.gdshader): pitch_head.colors as
## on-screen colours (Campfire.emissive), on the head's texel grid.
static func _wrap_material(phase: float) -> ShaderMaterial:
	var C: Dictionary = P.get("colors", {})
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/pitch_head.gdshader")
	m.render_priority = WRAP_PRIORITY
	m.set_shader_parameter("look_grain_soft", Look.grain())
	m.set_shader_parameter("texels_m", texels_m())
	m.set_shader_parameter("length_m", length_m())
	m.set_shader_parameter("bands", float(bands()))
	m.set_shader_parameter("rows", float(rows()))
	m.set_shader_parameter("phase", phase)
	m.set_shader_parameter("heat", 0.0)
	m.set_shader_parameter("pitch_col", Campfire.emissive(C.get("pitch", "#17110C")))
	m.set_shader_parameter("thin_col", Campfire.emissive(C.get("thin", "#5C3010")))
	m.set_shader_parameter("edge_col", Campfire.emissive(C.get("band_edge", "#2A1C12")))
	return m


## The coal: the burnt end's shader and breath (torch.json ember; the
## fire's bands in its cracks, glowing most at the top), `len` m tall;
## where it isn't hot, the thinned pitch with its tar flecks, not the
## burnt stick's char and ash.
static func _coal_material(phase: float, len: float) -> ShaderMaterial:
	var E: Dictionary = Torch.EMBER
	var C: Dictionary = P.get("colors", {})
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/torch_ember.gdshader")
	m.set_shader_parameter("look_grain_soft", Look.grain())
	m.set_shader_parameter("phase", phase)
	m.set_shader_parameter("length_m", len)
	m.set_shader_parameter("texels_m", float(E.get("texels_m", 150.0)))
	m.set_shader_parameter("crawl", float(E.get("crawl", 0.06)))
	var bands_c: Array = Campfire.FL.get("bands", ["#FEFC54", "#FCA82C", "#E6552A", "#5A0A00"])
	var hdr: Array = Campfire.FL.get("hdr", [1.0, 1.0, 1.0, 1.0])
	for i in 4:
		m.set_shader_parameter("band%d" % i, Campfire.emissive(bands_c[mini(i, bands_c.size() - 1)], float(hdr[i]) if i < hdr.size() else 1.0))
	m.set_shader_parameter("char_col", Campfire.emissive(C.get("thin", "#5C3010")))
	m.set_shader_parameter("ash_col", Campfire.emissive(C.get("pitch", "#17110C")))
	return m
