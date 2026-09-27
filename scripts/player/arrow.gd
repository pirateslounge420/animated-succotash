class_name Arrow
extends Node3D
## An arrow in flight (Bow): falls under the planet's gravity, points
## along its path, and on the first thing it meets (one physics ray per
## step, over every layer: the world, trees, and creatures' and people's
## hitbox parts, Hitboxes):
##   * a creature's part (Hitboxes.creature_of(): a Creature, or a rig of
##     its own such as the gibbon, anything with hurt()): hurts it and
##     sticks in that part (the collision shape itself, so it rides along
##     with that part as it moves; fireflies: it hurts the swarm and flies
##     on through);
##   * a camp person's part (Hitboxes.creature_of() names a holder with no
##     hurt()): a glancing shot they complain about (Camps.shot_at()), and
##     it bounces back off that part and drops;
##   * ground, trees, ruins: buries its head there and stays a while;
##   * water: splashes (Ripples) and sinks.
## Where it lands makes a noise wildlife hears (NoiseEvents, NOISE_M): a
## miss can spook the animal it lands by.
## Lives under World.world_root, so it moves with the floating origin.

static var GRAVITY := Tuning.num("combat", "arrow", "gravity_mps2")
static var STUCK_S := Tuning.num("combat", "arrow", "stuck_s")
static var MAX_FLIGHT_S := Tuning.num("combat", "arrow", "max_flight_s")
## How far off its landing is heard (NoiseEvents).
static var NOISE_M := Tuning.num("combat", "arrow", "noise_m")

## Arrows in flight (hitboxes near one wake up: Hitboxes.wanted_at()).
static var flying: Array[Arrow] = []
## Arrows stuck where they hit, which the player can take back (E).
static var stuck: Array[Arrow] = []
## How far from you a stuck arrow can be taken back (m).
static var PICK_M := Tuning.num("combat", "arrow", "pick_m")

var world: Node
var chunks: ChunkManager
var camps: Camps
var velocity := Vector3.ZERO
var damage := 10.0
var exclude: Array[RID] = []

var _stuck := false
## Glanced off a camp person already (a second touch isn't another hit).
var _glanced := false
var _life := 0.0
var _voice: AudioStreamPlayer3D
var _trail: AimArc.Trail


func launch(from: Vector3, vel: Vector3) -> void:
	add_child(BowMesh.arrow())
	global_position = from
	velocity = vel
	_voice = Audio3D.make("arrow", self)
	_trail = AimArc.Trail.new()
	add_child(_trail)
	_orient()
	flying.append(self)


func _exit_tree() -> void:
	flying.erase(self)
	stuck.erase(self)


## The stuck arrow nearest `pos` within `radius`, or null.
static func stuck_in_reach(pos: Vector3, radius: float) -> Arrow:
	var best: Arrow = null
	var best_d := radius
	for a in stuck:
		if not is_instance_valid(a):
			continue
		var d := a.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = a
	return best


## Taken back by the player: gone from where it was stuck.
func pick_up() -> void:
	stuck.erase(self)
	queue_free()


## Is an arrow in flight within `radius` m of `pos`?
static func near(pos: Vector3, radius: float) -> bool:
	for a in flying:
		if is_instance_valid(a) and a.global_position.distance_to(pos) < radius:
			return true
	return false


func _physics_process(delta: float) -> void:
	# A brief faint trail behind it in flight (AimArc.Trail).
	if _trail != null and _life < STUCK_S * 0.1:
		_trail.track(global_position, delta, not _stuck)
	_life += delta
	if _stuck:
		if _life > STUCK_S:
			queue_free()
		return
	if _life > MAX_FLIGHT_S:
		queue_free()
		return
	var up: Vector3 = world.dir_of(global_position)
	velocity -= up * GRAVITY * delta
	var a := global_position
	var b := a + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = exclude
	# The world, and creatures' and people's parts on their own layer
	# (Hitboxes; the default mask has every layer, this says so).
	q.collision_mask |= Hitboxes.LAYER
	var ray := get_world_3d().direct_space_state.intersect_ray(q)
	var hit_kind := ""
	var hit_obj: Node = null
	var hit_pos := b
	var hit_part: Node3D = null
	if not ray.is_empty():
		hit_kind = "world"
		hit_pos = ray.position
		# A creature's or a person's part (Hitboxes): who it belongs to.
		hit_obj = Hitboxes.creature_of(ray.collider)
		if hit_obj:
			hit_part = _shape_node(ray.collider, ray.shape)
			hit_kind = "creature" if hit_obj.has_method("hurt") else "folk"
	if hit_kind == "":
		# Water: sinks where it meets the surface.
		var d: Vector3 = world.dir_of(b)
		var water := chunks.water_level_at(d)
		if water > chunks.ground_height(d) and world.radius_of(b) < PlanetConst.RADIUS_M + water:
			global_position = b
			var surface: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + water)
			Ripples.splash(surface, RippleSim.contact("arrow_kg"), velocity.length())
			NoiseEvents.emit(surface, NOISE_M * 0.75)
			_stick()
			_life = STUCK_S - 3.0
			return
		# Past the ground's collision (it only exists near the player): the
		# ground itself, from its height.
		if world.radius_of(b) < PlanetConst.RADIUS_M + chunks.ground_height(d):
			hit_kind = "world"
			hit_pos = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))
	if hit_kind == "":
		global_position = b
		_orient()
		return
	NoiseEvents.emit(hit_pos, NOISE_M)
	match hit_kind:
		"creature":
			# Hurt in the part it met (Hits: head, eye, limb, body).
			Hits.strike(ray.collider, ray.shape, damage * clampf(velocity.length() / Bow.MAX_SPEED, 0.4, 1.0), a, hit_pos, camps)
			var cr := hit_obj as Creature
			if cr and cr.species.role == "swarm":
				# Through a cloud of fireflies: on it flies.
				exclude.append((ray.collider as CollisionObject3D).get_rid())
				global_position = b
				_orient()
				return
			# In the part it hit, a little way in, riding along with it.
			global_position = hit_pos + velocity.normalized() * 0.1
			_sound("arrow_hit")
			reparent(hit_part, true)
			_stick()
		"folk":
			# They complain (Camps.shot_at()); the hit reads like any other
			# (Hits), but no one's harmed. Only the first touch counts: a
			# glancing arrow that clips them again on the way down doesn't.
			if not _glanced:
				Hits.strike(ray.collider, ray.shape, damage * clampf(velocity.length() / Bow.MAX_SPEED, 0.4, 1.0), a, hit_pos, camps)
			_glanced = true
			# Off the part it hit, back the way it came, and down.
			exclude.append((ray.collider as CollisionObject3D).get_rid())
			global_position = hit_pos - velocity.normalized() * 0.03
			velocity *= -0.15
		"world":
			# Down through shallow water onto its bed in one step: it still
			# rings the water where it went in.
			_splash_crossing(a, hit_pos)
			# Bury the head a little along the flight.
			global_position = hit_pos + velocity.normalized() * 0.12
			_sound("arrow_hit")
			_stick()


## The node of the collision shape a ray met (`shape` of `collider`): the
## part itself, which follows its bone even when one body carries all of
## a creature's parts (GibbonHitboxes); else the body (a body per part,
## Hitboxes, where the body is the part).
static func _shape_node(collider: Object, shape: int) -> Node3D:
	var body := collider as CollisionObject3D
	if body == null or body.get_shape_owners().size() <= 1:
		return collider as Node3D
	var owner_node := body.shape_owner_get_owner(body.shape_find_owner(shape)) as Node3D
	return owner_node if owner_node != null else body


## A splash (Ripples) where the flight from `a` to `b` went down through
## the water's surface, if it did.
func _splash_crossing(a: Vector3, b: Vector3) -> void:
	var d: Vector3 = world.dir_of(b)
	var water := chunks.water_level_at(d)
	if water <= chunks.ground_height(d):
		return
	var surface := PlanetConst.RADIUS_M + water
	var ra: float = world.radius_of(a)
	var rb: float = world.radius_of(b)
	if ra < surface or rb >= surface:
		return
	var p := a.lerp(b, (ra - surface) / maxf(ra - rb, 1e-6))
	Ripples.splash(world.to_scene(world.dir_of(p), surface), RippleSim.contact("arrow_kg"), velocity.length())


func _stick() -> void:
	_stuck = true
	velocity = Vector3.ZERO
	flying.erase(self)
	stuck.append(self)


func _orient() -> void:
	if velocity.length_squared() < 1e-6:
		return
	var f := velocity.normalized()
	var up: Vector3 = world.dir_of(global_position)
	var hint := up if absf(f.dot(up)) < 0.98 else CubeSphere.north(up)
	global_basis = Basis.looking_at(f, hint)


func _sound(kind: String) -> void:
	_voice.stream = SoundSynth.stream(kind, randi())
	_voice.pitch_scale = randf_range(0.9, 1.1)
	_voice.play()
