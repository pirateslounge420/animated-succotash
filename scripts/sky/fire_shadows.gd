class_name FireShadows
extends Node
## Fire still casts shadows, cheaply (design 6 Oct §ER.1, Mike): of every
## fire and torch light (the group GROUP: campfires and hearths, Campfire;
## torches in hand, planted or on a shrine, Torch.light_node()), only the
## nearest `casters` to the eye within `reach_m` cast one, each a
## dual-paraboloid omni shadow (two half-sphere maps, cheaper than a cube),
## softened a little (rough and soft suits the look), fading out with
## distance into the light's own falloff; the rest light without shadows.
## The positional shadow atlas is kept small (project.godot,
## positional_shadow/atlas_size). Re-picked every PICK_S, not every frame.
## data/look.json "fire_shadows".

const GROUP := "fire_light"
const PICK_S := 0.25

static var F: Dictionary = Tuning.section("look", "fire_shadows")
## A game's own shadow kind for its casters ("" keeps the dual-paraboloid;
## "cube": six faces, true on big flat walls near the light). The crawler
## sets crawler.json look.fire_shadow_mode (§ET: its lights are always a
## step from a wall, where the paraboloids warp).
static var mode := ""

var _camera: Callable
var _t := 0.0
var _casting: Array[OmniLight3D] = []


## `camera`: returns the Camera3D the frame is drawn from.
func setup(camera: Callable) -> void:
	_camera = camera


## A light joins the fires that may cast (it starts without a shadow).
static func enlist(l: OmniLight3D) -> void:
	l.add_to_group(GROUP)
	l.shadow_enabled = false


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = PICK_S
	pick()


## Choose the casters now: the nearest `casters` lit fire lights within
## reach_m of the eye.
func pick() -> void:
	var cam: Camera3D = _camera.call() if _camera.is_valid() else null
	if cam == null:
		return
	var eye := cam.global_position
	var n := int(F.get("casters", 2))
	var reach := float(F.get("reach_m", 24.0))
	var near: Array = []
	for node in get_tree().get_nodes_in_group(GROUP):
		var l := node as OmniLight3D
		if l == null or not l.is_visible_in_tree() or l.light_energy <= 0.01:
			continue
		var d := l.global_position.distance_to(eye)
		if d <= reach:
			near.append([d, l])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var want: Array[OmniLight3D] = []
	for i in mini(n, near.size()):
		want.append(near[i][1])
	for l in _casting:
		if is_instance_valid(l) and not want.has(l):
			l.shadow_enabled = false
	for l in want:
		if not _casting.has(l):
			_cast(l, reach)
	_casting = want


func _cast(l: OmniLight3D, reach: float) -> void:
	l.omni_shadow_mode = OmniLight3D.SHADOW_CUBE if mode == "cube" else OmniLight3D.SHADOW_DUAL_PARABOLOID
	l.shadow_blur = float(F.get("blur", 1.5))
	l.shadow_bias = float(F.get("bias", 0.15))
	l.shadow_normal_bias = float(F.get("normal_bias", 1.5))
	# The shadow fades out from fade_from of the reach to the reach (over
	# distance_fade_length past distance_fade_shadow); the light itself
	# never fades (its distance_fade_begin far beyond anything drawn).
	var from := float(F.get("fade_from", 0.6))
	l.distance_fade_enabled = true
	l.distance_fade_begin = 1.0e5
	l.distance_fade_length = reach * (1.0 - from)
	l.distance_fade_shadow = reach * from
	l.shadow_enabled = true


## How many fire lights cast now (checks, the perf readout).
func casting() -> int:
	var k := 0
	for l in _casting:
		if is_instance_valid(l) and l.shadow_enabled:
			k += 1
	return k
