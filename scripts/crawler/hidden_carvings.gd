class_name HiddenCarvings
extends Node3D
## The Aztec temple's hidden carvings (design §FN.5, queue 83; data/brew.json
## plants.<id>.vision.carvings; visions.json rule.kept_inside): marks cut
## in the temple's stone from the start, that sober eyes miss. They are
## drawn only while a brew whose vision has a carvings block runs
## (BrewVision.reveal: easing in, held, fading with the vision), and while
## it runs they glow, multiply and change.
##
##   the calendar room  over each of the 20 day-sign panels' fields, a
##                      glyph cut fainter than the sign (kind 0), and on its
##                      left wall above the panels a frieze of history_panels
##                      panels read left to right: a short wordless
##                      picture-history of the temple's people (kinds 1-4,
##                      placeholders: footprints walking, reeds in water, a
##                      stepped temple, a rayed disc; the story itself is
##                      Claude (chat)'s to write), and on its right wall a
##                      frieze of glyph panels
##   the blood altar    a glyph on each of the round chamber's corner faces
##
## Bounds (§FN.5.3, §FM.3): really there, so it adds no creature, face or
## other thing; its glow is the paint's own (an unshaded material), so it
## casts no light, has no Light3D, touches no lit test (§FF.2), no boss and
## no dark; nothing about play reads it; no timer, no torch drain. Drawn in
## the temple's one stone colour (RuinStyle.tint), the glow its own.

## The panels laid ([{"room": "calendar"|"altar", "kind" (0 glyph, 1-4 the
## history), "at" (scene, its middle), "n" (out of the wall), "size"
## (Vector2)}]): the checks.
var panels: Array = []
## How far up they are now (0 none, 1 full).
var reveal := 0.0
var t := 0.0
var vision: BrewVision
var _mat: ShaderMaterial


## The carvings for dungeon `lay` (an Aztec temple: its calendar room and
## its blood altar chamber; none in any other ruin kind), read off by
## `p_vision` (the HUD's BrewVision). Null for a ruin with none.
static func make(lay: Dictionary, p_vision: BrewVision) -> HiddenCarvings:
	if RoomPool.ruin_kind(str(lay.get("theme", ""))) != "aztec_temple":
		return null
	var h := HiddenCarvings.new()
	h.name = "HiddenCarvings"
	h.vision = p_vision
	h._build(lay)
	return h


static func C() -> Dictionary:
	var plants: Dictionary = Brew.data().get("plants", {})
	for id in plants:
		var vb: Variant = ((plants[id] as Dictionary).get("vision", {}) as Dictionary).get("carvings")
		if vb is Dictionary:
			return vb
	return {}


func _build(lay: Dictionary) -> void:
	var D := C()
	var th := str(lay.get("theme", "aztec_temple"))
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/hidden_carvings.gdshader")
	_mat.set_shader_parameter("stone", RuinStyle.tint(th))
	_mat.set_shader_parameter("glow", Color(str(D.get("glow", "#80ffd0"))))
	_mat.set_shader_parameter("glow_amount", float(D.get("glow_amount", 0.75)))
	_mat.set_shader_parameter("breathe", float(D.get("breathe", 0.05)))
	_mat.set_shader_parameter("breathe_hz", float(D.get("breathe_hz", 0.12)))
	_mat.set_shader_parameter("change_s", float(D.get("change_s", 2.5)))
	_mat.set_shader_parameter("cells_max", float(D.get("cells_max", 3.0)))
	_mat.set_shader_parameter("reveal", 0.0)
	for pc in lay.get("pieces", []):
		var room := str((pc as Dictionary).get("big_room", ""))
		if room == "aztec_calendar_room":
			_calendar(pc, D)
		elif room == "aztec_blood_altar":
			_altar(pc, D)
	visible = false


## The calendar room: a hidden glyph over each day-sign panel's field (the
## same places AztecBuild.day_signs carves them), and its two friezes.
func _calendar(pc: Dictionary, D: Dictionary) -> void:
	var sd := {}
	for st in RoomPool.archetype(str(pc.big_room)).get("stands", []):
		if str((st as Dictionary).get("kind", "")) == "day_signs":
			sd = st
	if sd.is_empty():
		return
	var walls: Array = sd.get("walls", ["left", "right"])
	var per_row := maxi(int(sd.get("per_row", 5)), 1)
	var rows: Array = sd.get("rows_up_m", [2.15, 1.05])
	var size: Array = sd.get("panel_m", [0.95, 0.95])
	var length := float(pc.len)
	var signs := (Tuning.table("aztec_temple").get("calendar", {}) as Dictionary).get("day_signs", []) as Array
	var top := 0.0
	for r in rows:
		top = maxf(top, float(r))
	var i := 0
	var fw := 0.06
	for w in walls:
		for row in rows:
			for k in per_row:
				if i >= signs.size():
					break
				var off := length * float(k + 1) / float(per_row + 1) - length * 0.5
				var fp := TombKit.face_point(pc, str(w), off)
				var at: Vector2 = fp[0]
				var nv: Vector2 = fp[1]
				var n := Vector3(nv.x, 0.0, nv.y)
				var y := Delves.floor_of(pc, Delves.along_across(pc, at).x) + float(row)
				# In front of the sign's raised glyph (the slab's face 0.1 m
				# out, the glyph 5 cm proud of its field).
				var o := Vector3(at.x, y, at.y) + n * (0.1 + float(D.get("proud_m", 0.06)))
				_quad("calendar", 0, i, o, n, Vector2(float(size[0]) - 2.0 * fw, float(size[1]) - 2.0 * fw))
				i += 1
	# The friezes over the upper row.
	var fh := float(D.get("frieze_m", 0.55))
	var n_hist := maxi(int(D.get("history_panels", 4)), 1)
	for wi in walls.size():
		var w := str(walls[wi])
		for k in n_hist:
			var off := length * float(k + 1) / float(n_hist + 1) - length * 0.5
			var fp := TombKit.face_point(pc, w, off)
			var at: Vector2 = fp[0]
			var nv: Vector2 = fp[1]
			var n := Vector3(nv.x, 0.0, nv.y)
			var fl := Delves.floor_of(pc, Delves.along_across(pc, at).x)
			var y := minf(fl + top + float(size[1]) * 0.5 + 0.12 + fh * 0.5, fl + float(pc.get("h", 4.0)) - fh * 0.5 - 0.1)
			var o := Vector3(at.x, y, at.y) + n * float(D.get("proud_m", 0.06))
			var kind := (k % 4) + 1 if wi == 0 else 0
			_quad("calendar", kind, 100 + wi * 10 + k, o, n, Vector2(minf(length / float(n_hist + 1) * 0.9, 1.6), fh))


## The blood altar's round chamber: a glyph on each corner face (the faces
## AztecBuild.round_room lays across the corners; the walls' middles keep
## the doors and sconces).
func _altar(pc: Dictionary, D: Dictionary) -> void:
	var shape: Dictionary = RoomPool.archetype(str(pc.big_room)).get("shape", {})
	var sides4 := maxi(maxi(int(shape.get("sides", 12)), 8) / 4, 2) * 4
	var half := float(pc.half)
	var length := float(pc.len)
	var a := minf(half, length * 0.5)
	var ax := TombBuild._axes(pc)
	var u: Vector3 = ax[0]
	var v: Vector3 = ax[1]
	var q := RuinBuilder._pp(pc, length * 0.5, 0.0)
	var y0 := Delves.floor_of(pc, length * 0.5)
	var c := Vector3(q.x, y0, q.y)
	var step := TAU / float(sides4)
	var edge := 2.0 * a * tan(step * 0.5)
	var per_q := sides4 / 4
	for k in sides4:
		if k % per_q == 0:
			continue
		var phi := step * k
		var n := u * cos(phi) + v * sin(phi)
		# On the face (the blocks' inner face, a from the middle), facing in.
		var o := c + n * (a - float(D.get("proud_m", 0.06))) + Vector3.UP * float(D.get("altar_up_m", 1.6))
		_quad("altar", 0, 200 + k, o, -n, Vector2(edge * 0.7, 0.9))


## One panel: a quad at `o` facing `n` (out of its wall), `sz` wide and
## high, of `kind`, seeded `sd`.
func _quad(room: String, kind: int, sd: int, o: Vector3, n: Vector3, sz: Vector2) -> void:
	var m := QuadMesh.new()
	m.size = sz
	var mi := MeshInstance3D.new()
	mi.name = "Carving%d" % panels.size()
	mi.mesh = m
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var t3 := Vector3.UP.cross(n).normalized()
	mi.transform = Transform3D(Basis(t3, Vector3.UP, n), o)
	mi.set_instance_shader_parameter("kind", float(kind))
	mi.set_instance_shader_parameter("seed", float(sd))
	add_child(mi)
	panels.append({"room": room, "kind": kind, "at": o, "n": n, "size": sz})


## Follow the vision: drawn only while it is up, at its strength.
func _process(delta: float) -> void:
	var r := vision.reveal() if vision != null and is_instance_valid(vision) else 0.0
	set_reveal(r, delta)


func set_reveal(r: float, delta := 0.0) -> void:
	reveal = clampf(r, 0.0, 1.0)
	if reveal > 0.0:
		t += delta
	else:
		t = 0.0
	visible = reveal > 0.0
	_mat.set_shader_parameter("reveal", reveal)
	_mat.set_shader_parameter("t", t)
