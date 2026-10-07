class_name SkeletonRig
extends Node3D
## The tomb's skeleton as a model to bake into its sprite sheet (design
## §FE.2; §ET.8 and §EY.5: creatures are sprites baked from a model, eight
## around by three heights; residents.json skeleton sprite). Tapered
## bones and balls on joints, the feet at the origin, facing -z; painted
## bone with navy shade underneath (shaders/bone_paint.gdshader, the
## light in the paint, §ES), the eye sockets and the nose dark. Posed for
## each frame of the sheet (POSES): resting in a niche (sitting hunched,
## knees drawn up, the way the Andes buried their dead) and in a grave
## (kneeling in its coffin, slumped over the end, Mike's frame 9), three
## steps of climbing out, a slow walk of four, the wind-up (the jaw drops
## open, the claws go back: §FA.2's tell), the strike, and the reel of a
## stagger (§FA.1).

const POSES := ["rest_niche", "rest_grave", "rise_a", "rise_b", "rise_c", "walk_0", "walk_1", "walk_2", "walk_3", "wind_up", "strike", "reel"]
## The rig's own height standing (m): the sheet is baked at height_m, the
## rig scaled to it.
const REF_H := 1.69
const BONE := Color(0.84, 0.8, 0.68)
const SOCKET := Color(0.03, 0.035, 0.08)

## Joints by name: pelvis, spine, neck, skull, jaw, sh_l/sh_r (shoulders),
## el_l/el_r (elbows), hip_l/hip_r, kn_l/kn_r (knees).
var joints := {}
var _bone: ShaderMaterial
var _dark: StandardMaterial3D

## Each pose: the pelvis's place (on the rig's frame, m) and each joint's
## turn in degrees (x forward or back, z out to the side; a limb hangs
## down, so x + swings it forward; the spine stands up, so x - leans it
## forward). Joints not named stand straight.
const POSE_DATA := {
	"stand": {"pelvis": Vector3(0.0, 0.93, 0.0)},
	# Hunched on its shelf, knees drawn up, arms round its shins, head bowed.
	"rest_niche": {"pelvis": Vector3(0.0, 0.08, 0.08), "spine": Vector3(-26, 0, 0), "neck": Vector3(-30, 0, 0), "skull": Vector3(-20, 0, 0), "jaw": Vector3(-6, 0, 0),
		"hip_l": Vector3(128, 0, -10), "kn_l": Vector3(-140, 0, 0), "hip_r": Vector3(128, 0, 10), "kn_r": Vector3(-140, 0, 0),
		"sh_l": Vector3(80, 0, -8), "el_l": Vector3(25, 0, 70), "sh_r": Vector3(80, 0, 8), "el_r": Vector3(25, 0, -70)},
	# Kneeling in its coffin, slumped over the end: the head past the rim,
	# one arm folded on it, the other hanging down the outside (frame 9).
	"rest_grave": {"pelvis": Vector3(0.0, 0.5, 0.0), "spine": Vector3(-50, 0, 0), "neck": Vector3(-30, 0, 0), "skull": Vector3(-20, 0, 0), "jaw": Vector3(-18, 0, 0),
		"hip_l": Vector3(-4, 0, -3), "kn_l": Vector3(-90, 0, 0), "hip_r": Vector3(-4, 0, 3), "kn_r": Vector3(-90, 0, 0),
		"sh_l": Vector3(74, 0, -4), "el_l": Vector3(66, 0, 40), "sh_r": Vector3(100, 0, 6), "el_r": Vector3(-25, 0, 0)},
	"rise_a": {"pelvis": Vector3(0.0, 0.5, 0.0), "spine": Vector3(-12, 0, 0), "neck": Vector3(6, 0, 0), "jaw": Vector3(-5, 0, 0),
		"hip_l": Vector3(-5, 0, -3), "kn_l": Vector3(-90, 0, 0), "hip_r": Vector3(-5, 0, 3), "kn_r": Vector3(-90, 0, 0),
		"sh_l": Vector3(50, 0, -8), "el_l": Vector3(25, 0, 0), "sh_r": Vector3(50, 0, 8), "el_r": Vector3(25, 0, 0)},
	"rise_b": {"pelvis": Vector3(0.0, 0.51, 0.0), "spine": Vector3(-22, 0, 0), "neck": Vector3(-5, 0, 0), "jaw": Vector3(-5, 0, 0),
		"hip_l": Vector3(85, 0, -4), "kn_l": Vector3(-85, 0, 0), "hip_r": Vector3(-10, 0, 3), "kn_r": Vector3(-80, 0, 0),
		"sh_l": Vector3(40, 0, -10), "el_l": Vector3(30, 0, 0), "sh_r": Vector3(60, 0, 10), "el_r": Vector3(20, 0, 0)},
	"rise_c": {"pelvis": Vector3(0.0, 0.88, 0.04), "spine": Vector3(-22, 0, 0), "neck": Vector3(-10, 0, 0), "skull": Vector3(-5, 0, 0),
		"hip_l": Vector3(18, 0, -2), "kn_l": Vector3(-30, 0, 0), "hip_r": Vector3(12, 0, 2), "kn_r": Vector3(-24, 0, 0),
		"sh_l": Vector3(30, 0, -6), "el_l": Vector3(25, 0, 0), "sh_r": Vector3(25, 0, 6), "el_r": Vector3(20, 0, 0)},
	"walk_0": {"pelvis": Vector3(0.0, 0.86, 0.0), "spine": Vector3(-14, 0, 0), "neck": Vector3(-8, 0, 0), "skull": Vector3(-4, 0, 0), "jaw": Vector3(-4, 0, 0),
		"hip_l": Vector3(24, 0, -2), "kn_l": Vector3(-8, 0, 0), "hip_r": Vector3(-18, 0, 2), "kn_r": Vector3(-28, 0, 0),
		"sh_l": Vector3(8, 0, -6), "el_l": Vector3(22, 0, 0), "sh_r": Vector3(38, 0, 6), "el_r": Vector3(30, 0, 0)},
	"walk_1": {"pelvis": Vector3(0.0, 0.89, 0.0), "spine": Vector3(-14, 0, 0), "neck": Vector3(-8, 0, 0), "skull": Vector3(-4, 0, 0), "jaw": Vector3(-4, 0, 0),
		"hip_l": Vector3(4, 0, -2), "kn_l": Vector3(-6, 0, 0), "hip_r": Vector3(22, 0, 2), "kn_r": Vector3(-50, 0, 0),
		"sh_l": Vector3(22, 0, -6), "el_l": Vector3(25, 0, 0), "sh_r": Vector3(22, 0, 6), "el_r": Vector3(25, 0, 0)},
	"walk_2": {"pelvis": Vector3(0.0, 0.86, 0.0), "spine": Vector3(-14, 0, 0), "neck": Vector3(-8, 0, 0), "skull": Vector3(-4, 0, 0), "jaw": Vector3(-4, 0, 0),
		"hip_l": Vector3(-18, 0, -2), "kn_l": Vector3(-28, 0, 0), "hip_r": Vector3(24, 0, 2), "kn_r": Vector3(-8, 0, 0),
		"sh_l": Vector3(38, 0, -6), "el_l": Vector3(30, 0, 0), "sh_r": Vector3(8, 0, 6), "el_r": Vector3(22, 0, 0)},
	"walk_3": {"pelvis": Vector3(0.0, 0.89, 0.0), "spine": Vector3(-14, 0, 0), "neck": Vector3(-8, 0, 0), "skull": Vector3(-4, 0, 0), "jaw": Vector3(-4, 0, 0),
		"hip_l": Vector3(22, 0, -2), "kn_l": Vector3(-50, 0, 0), "hip_r": Vector3(4, 0, 2), "kn_r": Vector3(-6, 0, 0),
		"sh_l": Vector3(22, 0, -6), "el_l": Vector3(25, 0, 0), "sh_r": Vector3(22, 0, 6), "el_r": Vector3(25, 0, 0)},
	"wind_up": {"pelvis": Vector3(0.0, 0.87, 0.03), "spine": Vector3(6, 0, 0), "neck": Vector3(10, 0, 0), "skull": Vector3(8, 0, 0), "jaw": Vector3(-42, 0, 0),
		"hip_l": Vector3(20, 0, -3), "kn_l": Vector3(-20, 0, 0), "hip_r": Vector3(-20, 0, 3), "kn_r": Vector3(-15, 0, 0),
		"sh_l": Vector3(-150, 0, -28), "el_l": Vector3(70, 0, 0), "sh_r": Vector3(-150, 0, 28), "el_r": Vector3(70, 0, 0)},
	"strike": {"pelvis": Vector3(0.0, 0.82, -0.08), "spine": Vector3(-25, 0, 0), "neck": Vector3(-4, 0, 0), "jaw": Vector3(-42, 0, 0),
		"hip_l": Vector3(38, 0, -3), "kn_l": Vector3(-38, 0, 0), "hip_r": Vector3(-28, 0, 3), "kn_r": Vector3(-12, 0, 0),
		"sh_l": Vector3(95, 0, 10), "el_l": Vector3(15, 0, 0), "sh_r": Vector3(95, 0, -10), "el_r": Vector3(15, 0, 0)},
	"reel": {"pelvis": Vector3(0.0, 0.86, 0.12), "spine": Vector3(24, 0, 0), "neck": Vector3(20, 0, 0), "skull": Vector3(10, 0, 0), "jaw": Vector3(-20, 0, 0),
		"hip_l": Vector3(12, 0, -3), "kn_l": Vector3(-10, 0, 0), "hip_r": Vector3(-28, 0, 3), "kn_r": Vector3(-20, 0, 0),
		"sh_l": Vector3(-40, 0, -70), "el_l": Vector3(35, 0, 0), "sh_r": Vector3(-40, 0, 70), "el_r": Vector3(35, 0, 0)},
}


## A skeleton `height_m` tall, standing.
static func build(height_m: float) -> SkeletonRig:
	var r := SkeletonRig.new()
	r.name = "SkeletonRig"
	r.scale = Vector3.ONE * (height_m / REF_H)
	r._make()
	r.pose("stand")
	return r


func _joint(parent: Node3D, n: String, at: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = n
	j.position = at
	parent.add_child(j)
	joints[n] = j
	return j


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, scl := Vector3.ONE, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.scale = scl
	mi.material_override = mat if mat != null else _bone
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A ball of radii `r` (CreatureBodies' shared sphere, radius 0.5).
func _ball(parent: Node3D, r: Vector3, at: Vector3, mat: Material = null) -> MeshInstance3D:
	return _mesh(parent, CreatureBodies._sphere(1), at, r * 2.0, mat)


## A bone hanging `length` down from `parent`'s origin, `thick` at its top.
func _limb(parent: Node3D, length: float, thick: float) -> void:
	_mesh(parent, CreatureBodies._limb_mesh(snappedf(length, 0.01), snappedf(thick * 0.5, 0.005), snappedf(thick * 0.32, 0.005)), Vector3.ZERO)


func _make() -> void:
	_bone = ShaderMaterial.new()
	_bone.shader = preload("res://shaders/bone_paint.gdshader")
	_bone.set_shader_parameter("albedo", BONE)
	_dark = StandardMaterial3D.new()
	_dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dark.albedo_color = SOCKET
	var pelvis := _joint(self, "pelvis", Vector3(0.0, 0.93, 0.0))
	_ball(pelvis, Vector3(0.15, 0.065, 0.08), Vector3.ZERO)
	var spine := _joint(pelvis, "spine", Vector3(0.0, 0.05, 0.0))
	for k in 6:
		_ball(spine, Vector3.ONE * 0.024, Vector3(0.0, 0.03 + k * 0.07, 0.035))
	# The ribs: five hoops, the widest in the middle, and the breastbone.
	for k in 5:
		var w := 0.135 - absf(k - 2.0) * 0.012
		_ball(spine, Vector3(w, 0.015, 0.095 - absf(k - 2.0) * 0.006), Vector3(0.0, 0.2 + k * 0.045, -0.005))
	_ball(spine, Vector3(0.02, 0.1, 0.015), Vector3(0.0, 0.3, -0.095))
	# The collarbones across the top.
	_ball(spine, Vector3(0.17, 0.016, 0.022), Vector3(0.0, 0.44, -0.02))
	var neck := _joint(spine, "neck", Vector3(0.0, 0.47, 0.01))
	for k in 2:
		_ball(neck, Vector3.ONE * 0.022, Vector3(0.0, 0.025 + k * 0.045, 0.0))
	var skull := _joint(neck, "skull", Vector3(0.0, 0.11, -0.01))
	_ball(skull, Vector3(0.085, 0.1, 0.105), Vector3(0.0, 0.025, 0.0))
	_ball(skull, Vector3(0.07, 0.05, 0.06), Vector3(0.0, -0.03, -0.05))
	for s: float in [-1.0, 1.0]:
		_ball(skull, Vector3.ONE * 0.026, Vector3(s * 0.034, 0.002, -0.088), _dark)
	_ball(skull, Vector3(0.012, 0.016, 0.01), Vector3(0.0, -0.035, -0.1), _dark)
	var jaw := _joint(skull, "jaw", Vector3(0.0, -0.06, -0.015))
	_ball(jaw, Vector3(0.062, 0.022, 0.055), Vector3(0.0, -0.018, -0.05))
	for s: float in [-1.0, 1.0]:
		var sd := "l" if s < 0.0 else "r"
		var sh := _joint(spine, "sh_" + sd, Vector3(s * 0.17, 0.42, 0.0))
		_limb(sh, 0.29, 0.045)
		var el := _joint(sh, "el_" + sd, Vector3(0.0, -0.29, 0.0))
		_limb(el, 0.26, 0.038)
		_ball(el, Vector3(0.035, 0.06, 0.02), Vector3(0.0, -0.3, -0.005))
		var hip := _joint(pelvis, "hip_" + sd, Vector3(s * 0.09, -0.03, 0.0))
		_limb(hip, 0.44, 0.06)
		var kn := _joint(hip, "kn_" + sd, Vector3(0.0, -0.44, 0.0))
		_limb(kn, 0.42, 0.05)
		_ball(kn, Vector3(0.04, 0.025, 0.09), Vector3(0.0, -0.44, -0.05))


## Set the named pose (POSE_DATA): the pelvis placed, every joint turned.
func pose(pose_name: String) -> void:
	var p: Dictionary = POSE_DATA.get(pose_name, POSE_DATA.stand)
	for n in joints:
		(joints[n] as Node3D).rotation_degrees = Vector3.ZERO
	(joints.pelvis as Node3D).position = p.get("pelvis", Vector3(0.0, 0.93, 0.0))
	for n in p:
		if n != "pelvis" and joints.has(n):
			(joints[n] as Node3D).rotation_degrees = p[n]


## The eye height over the feet in each pose (m, at REF_H; the sprite's
## row is picked by the camera's height against it).
const EYE := {"rest_niche": 0.62, "rest_grave": 0.86, "rise_a": 1.0, "rise_b": 1.0, "rise_c": 1.4, "walk_0": 1.5, "walk_1": 1.5, "walk_2": 1.5, "walk_3": 1.5, "wind_up": 1.55, "strike": 1.3, "reel": 1.5}
