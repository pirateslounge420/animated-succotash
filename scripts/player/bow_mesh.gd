class_name BowMesh
## A simple recurve bow (the player's, the camp archers', and ones laid
## by the fire): wooden limbs curving back from a leather-wrapped grip,
## tips flicking forward, and a string. The bow stands along +Y with the
## string on its +Z side (the archer's side), about `length` m tall.
## set_draw() pulls the string back (0 rest .. 1 full draw).

const WOOD := Color(0.46, 0.3, 0.16)
const GRIP := Color(0.28, 0.18, 0.11)
const STRING := Color(0.86, 0.83, 0.74)


static func build(length := 1.25) -> Node3D:
	var root := Node3D.new()
	root.name = "Bow"
	var half := length * 0.5
	# Limbs: a chain of short tapering segments in a D: the grip farthest
	# forward (-Z, toward the target), the limbs sweeping back to the tips,
	# which flick forward again (a recurve).
	var segs := 6
	var depth := length * 0.1
	var curve := func(t: float) -> float:
		return -depth * cos(t * PI * 0.5) - depth * 0.3 * pow(t, 8.0)
	for side: float in [-1.0, 1.0]:
		var prev := Vector3(0, 0.07 * side, curve.call(0.0))
		for k in segs:
			var t := float(k + 1) / segs
			var p := Vector3(0, side * (0.07 + (half - 0.07) * t), curve.call(t))
			_segment(root, prev, p, lerpf(0.022, 0.009, float(k) / segs), lerpf(0.022, 0.009, t), WOOD)
			prev = p
	CreatureBodies.cone(root, 0.026, 0.026, 0.16, Vector3(0, 0, curve.call(0.0)), GRIP, 0.0, 6)
	# The string: two halves meeting at the nock, moved by set_draw().
	var tip_top := Vector3(0, half, curve.call(1.0))
	var tip_bot := Vector3(0, -half, curve.call(1.0))
	root.set_meta("tips", [tip_top, tip_bot])
	for k in 2:
		var s := CreatureBodies.cone(root, 0.004, 0.004, 1.0, Vector3.ZERO, STRING, 0.0, 4)
		s.name = "String%d" % k
	set_draw(root, 0.0)
	return root


## Pull the string back: 0 at rest (straight between the tips) .. 1 at
## full draw (the nock `length` * 0.45 back toward the archer, +Z).
static func set_draw(bow: Node3D, amount: float) -> void:
	var tips: Array = bow.get_meta("tips")
	var top: Vector3 = tips[0]
	var bot: Vector3 = tips[1]
	var nock := Vector3(0, 0, top.z + 0.01 + amount * top.y * 0.85)
	for k in 2:
		var s: Node3D = bow.get_node("String%d" % k)
		_place(s, top if k == 0 else bot, nock)
	bow.set_meta("nock", nock)


static func _segment(parent: Node3D, a: Vector3, b: Vector3, ra: float, rb: float, col: Color) -> void:
	var seg := CreatureBodies.cone(parent, ra, rb, 1.0, Vector3.ZERO, col, 0.0, 6)
	_place(seg, a, b)


## Stretch a unit-tall piece (along Y, centered) from a to b.
static func _place(n: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := maxf(d.length(), 1e-4)
	var y := d / len
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	n.transform = Transform3D(Basis(x, y * len, x.cross(y)), (a + b) * 0.5)


## An arrow, pointing along -Z from its tip at the origin, `length` m.
static func arrow(length := 0.75) -> Node3D:
	var root := Node3D.new()
	root.name = "Arrow"
	var shaft := CreatureBodies.cone(root, 0.007, 0.007, length, Vector3(0, 0, length * 0.5), Color(0.62, 0.48, 0.3), 0.0, 4)
	shaft.rotation.x = PI * 0.5
	var head := CreatureBodies.cone(root, 0.018, 0.0, 0.07, Vector3(0, 0, 0.0), Color(0.36, 0.36, 0.4), 0.0, 4)
	head.rotation.x = -PI * 0.5
	for k in 3:
		var f := CreatureBodies.box(root, Vector3(0.004, 0.035, 0.11), Vector3(0, 0, length - 0.08), Color(0.88, 0.86, 0.8) if k > 0 else Color(0.75, 0.2, 0.15))
		f.rotation.z = k * TAU / 3.0
		(f.get_child(0) as Node3D).position = Vector3(0, 0.02, 0)
	return root
