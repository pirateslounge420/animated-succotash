class_name ThrownPot
extends Node3D
## A fire pot in the air (design 6 Oct night §FA.3; FirePots throws it):
## it lobs under gravity (fire_pots.json throw.gravity_mps2, straight down:
## the tomb is its own flat world), tumbling end over end, its wick alight
## all the way (a flare whatever can see reads: FirePots.flares). It bursts
## on the first thing it meets: one ray a physics step over the tomb's
## stone (PropCollision.WORLD_LAYER: walls, floors, the holders' stones),
## and the step tested against every fire target's body
## (FirePots.TARGET_GROUP: a sphere fire_radius_m round its middle, or a
## long body's own fire_distance, the snake's); or in
## the air when its fuse runs out (fuse_left; a fuse already spent in your
## hand waits for the impact, since cook_off_in_hand is null and it never
## goes off in your hand). Longer than throw.flight_max_s in the air, it
## bursts where it is. FirePots.burst does the rest.

var pots: FirePots
var oil := "tar"
var velocity := Vector3.ZERO
## Seconds of fuse left in the air (< 0: none, it bursts on impact).
var fuse_left := -1.0
var gravity := 9.8
var exclude: Array[RID] = []
## In the air (false once it has burst).
var flying := true
## Seconds in the air.
var life := 0.0
## Where it burst (checks): {"pos", "target", "why" (world, target, fuse,
## flight)}.
var burst_at := {}

var _pivot: Node3D
var _wick: Node3D
var _light: OmniLight3D
var _axis := Vector3.RIGHT
var _spin := 0.0
## The pot's middle above its foot (it tumbles about it).
const MID_Y := 0.06
## The wick's light rides this far above the pot.
const LIGHT_UP_M := 0.3


## Into the air from `from` (scene) at `vel`, `p_oil` in it, `p_fuse`
## seconds of fuse left (< 0 none), never meeting `p_exclude` (you).
func launch(p_pots: FirePots, from: Vector3, vel: Vector3, p_oil: String, p_fuse: float, p_exclude: Array[RID]) -> void:
	pots = p_pots
	oil = p_oil
	velocity = vel
	fuse_left = p_fuse
	exclude = p_exclude
	var T: Dictionary = FirePots.D.get("throw", {})
	gravity = float(T.get("gravity_mps2", 9.8))
	name = "ThrownPot"
	_pivot = Node3D.new()
	_pivot.name = "Tumble"
	add_child(_pivot)
	var pot := PotMesh.node(oil)
	pot.position = Vector3(0.0, -MID_Y, 0.0)
	_pivot.add_child(pot)
	# The wick's flame stays upright while the pot tumbles under it.
	var W: Dictionary = FirePots.D.get("wick", {})
	_wick = Torch.flame_node(float(W.get("flame_scale", 0.12)))
	_wick.name = "Wick"
	add_child(_wick)
	_light = OmniLight3D.new()
	_light.name = "WickLight"
	_light.light_color = Torch.fire_color()
	_light.light_energy = float(W.get("energy", 1.0))
	_light.omni_range = float(W.get("light_range_m", 4.0))
	_light.omni_attenuation = Campfire.ATTENUATION
	_light.shadow_enabled = false
	add_child(_light)
	global_position = from
	var flat := Vector3(vel.x, 0.0, vel.z)
	_axis = flat.cross(Vector3.UP).normalized() if flat.length() > 0.01 else Vector3.RIGHT
	_place_wick()


## The wick's tip now (scene): where the pot has tumbled it.
func wick_point() -> Vector3:
	return global_position + _pivot.basis * (PotMesh.wick_tip() - Vector3(0.0, MID_Y, 0.0))


func _place_wick() -> void:
	var tip := _pivot.basis * (PotMesh.wick_tip() - Vector3(0.0, MID_Y, 0.0))
	_wick.position = tip
	# Its light rides a little above it, so the clay isn't blown white.
	_light.position = Vector3(0.0, LIGHT_UP_M, 0.0)


func _physics_process(delta: float) -> void:
	if not flying:
		return
	life += delta
	if fuse_left >= 0.0:
		fuse_left -= delta
		if fuse_left <= 0.0:
			_burst(global_position, null, Vector3.UP, "fuse")
			return
	if life > float((FirePots.D.get("throw", {}) as Dictionary).get("flight_max_s", 6.0)):
		_burst(global_position, null, Vector3.UP, "flight")
		return
	velocity.y -= gravity * delta
	var a := global_position
	var b := a + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = exclude
	q.collision_mask = PropCollision.WORLD_LAYER
	var ray := get_world_3d().direct_space_state.intersect_ray(q)
	var seg := maxf((b - a).length(), 1e-6)
	var best := 2.0 if ray.is_empty() else ((ray.position as Vector3) - a).length() / seg
	var who: Node3D = null
	for t in FirePots.targets(get_tree()):
		var k := segment_sphere(a, b, FirePots.center_of(t), FirePots.radius_of(t))
		if k < 0.0 and t.has_method("fire_distance") and FirePots.distance_to(t, b) <= 0.0:
			# A long body (the snake's) under it by the step's end.
			k = 1.0
		if k >= 0.0 and k < best:
			best = k
			who = t
	if who != null:
		_burst(a.lerp(b, best), who, -velocity.normalized(), "target")
	elif not ray.is_empty():
		_burst(ray.position, null, ray.normal, "world")
	else:
		global_position = b
		_spin += delta * 9.0
		_pivot.basis = Basis(_axis, _spin)
		_place_wick()


## Where along a..b (0..1) it first meets a ball of `r` round `c`, or -1.
static func segment_sphere(a: Vector3, b: Vector3, c: Vector3, r: float) -> float:
	var d := b - a
	var f := a - c
	var aa := d.dot(d)
	if aa < 1e-12:
		return 0.0 if f.length() <= r else -1.0
	var bb := 2.0 * f.dot(d)
	var cc := f.dot(f) - r * r
	if cc <= 0.0:
		return 0.0
	var disc := bb * bb - 4.0 * aa * cc
	if disc < 0.0:
		return -1.0
	var k := (-bb - sqrt(disc)) / (2.0 * aa)
	return k if k >= 0.0 and k <= 1.0 else -1.0


func _burst(at: Vector3, who: Node3D, normal: Vector3, why: String) -> void:
	flying = false
	burst_at = {"pos": at, "target": who, "why": why}
	global_position = at
	pots.burst(at, oil, who, normal)
	pots.landed(self)
	queue_free()
