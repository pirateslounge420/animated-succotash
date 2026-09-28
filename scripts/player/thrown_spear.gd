class_name ThrownSpear
extends Node3D
## The spear out in the world (Spear throws it): in flight it falls under
## the planet's gravity and points along its path, heavier and slower than
## an arrow so it arcs more. On the first thing it meets (one physics ray
## per step from its tip, over every layer: the world, trees, and the
## creatures' and people's hitbox parts, Hitboxes):
##   * a creature's part: hurts it and sticks in that part, riding along
##     with it (a swarm it flies on through); when the carcass fades, the
##     spear drops to the ground there;
##   * a camp person's part: a glancing blow they complain about
##     (Camps.shot_at()), and it bounces off and falls;
##   * ground, trees, ruins: buries its point there;
##   * water: splashes (Ripples) and floats on the surface.
## Wherever it lands makes a noise wildlife hears (NoiseEvents, NOISE_M).
## It stays until the player takes it back (Spear.pick_up()): there is
## only one. Lives under World.world_root (or the part it's stuck in), so
## it moves with the floating origin.

static var GRAVITY := Tuning.num("combat", "thrown_spear", "gravity_mps2")
## Longer than this in the air (off the edge of loaded ground): it drops
## where it is.
static var MAX_FLIGHT_S := Tuning.num("combat", "thrown_spear", "max_flight_s")
## How far off its landing is heard (NoiseEvents); in water, SPLASH_M.
static var NOISE_M := Tuning.num("combat", "thrown_spear", "noise_m")
static var SPLASH_M := Tuning.num("combat", "thrown_spear", "splash_m")
## The point sinks this far into what it hits.
static var BURY_M := Tuning.num("combat", "thrown_spear", "bury_m")

var world: Node
var chunks: ChunkManager
var camps: Camps
var velocity := Vector3.ZERO
var damage := 30.0
var exclude: Array[RID] = []
## A super shot (design §S, SuperMeter): every hit critical, the fall
## eased by gravity_scale, a red streak (combat "overcharge").
var super_shot := false
var gravity_scale := 1.0
## A super throw stuck in a creature (combat overcharge.spear.pin): it's
## pinned where it stands for as long as the shaft is in it.
var pinning := false
## Come to rest (stuck, lying or afloat): it can be taken back.
var landed := false
var afloat := false
## The creature it's stuck in, or null.
var host: Creature = null

var _life := 0.0
## Glanced off a camp person already (a second touch isn't another hit).
var _glanced := false
var _float_at := Vector3.ZERO
var _voice: AudioStreamPlayer3D
var _trail: AimArc.Trail


func launch(from: Vector3, vel: Vector3) -> void:
	name = "ThrownSpear"
	add_child(Spear.mesh())
	# Stuck in a creature whose parts are switched off (dead, far off:
	# Hitboxes.set_active()), it must still keep watch.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	global_position = from
	velocity = vel
	_voice = Audio3D.make("spear_impact", self)
	_trail = AimArc.Trail.new()
	if super_shot:
		var oc := SuperMeter.overcharge("")
		_trail.color = Color(str(oc.get("tracer_color", "#FF2A2A")))
		_trail.length_s = float(oc.get("tracer_s", 0.9))
	add_child(_trail)
	_orient()


func _physics_process(delta: float) -> void:
	# A brief faint trail behind it in flight (AimArc.Trail).
	if _trail != null:
		_trail.track(global_position, delta, not landed)
	if landed:
		_rest()
		return
	_life += delta
	if _life > MAX_FLIGHT_S:
		_lay_down()
		return
	var up: Vector3 = world.dir_of(global_position)
	velocity -= up * GRAVITY * gravity_scale * delta
	var a := global_position
	var b := a + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = exclude
	q.collision_mask |= Hitboxes.LAYER
	var ray := get_world_3d().direct_space_state.intersect_ray(q)
	if ray.is_empty():
		# Water: it meets the surface and floats.
		var d: Vector3 = world.dir_of(b)
		var water := chunks.water_level_at(d)
		if water > chunks.ground_height(d) and world.radius_of(b) < PlanetConst.RADIUS_M + water:
			var surface: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + water)
			Ripples.splash(surface, RippleSim.contact("spear_kg"), velocity.length())
			NoiseEvents.emit(surface, SPLASH_M)
			_sound(0.8)
			_float(d, water)
			return
		global_position = b
		_orient()
		return
	var hit_pos: Vector3 = ray.position
	var who := Hitboxes.creature_of(ray.collider)
	var part := ray.collider as Node3D
	if who and who.has_method("hurt"):
		# A creature, or a rig of its own such as the gibbon: hurt in the
		# part it met (Hits).
		var amount := damage * clampf(velocity.length() / Spear.MAX_SPEED, 0.4, 1.0)
		var oc := SuperMeter.overcharge("spear") if super_shot else {}
		if bool(oc.get("impact_kill", false)) and not Hits.mythic(who):
			# A super throw is the §K impact curve at full force: a kill
			# on anything not a mythic.
			amount = Hits.kill_amount(who, Hits.part_of(ray.collider, ray.shape), amount)
		Hits.force_critical = super_shot
		Hits.strike(ray.collider, ray.shape, amount, a, hit_pos, camps)
		Hits.force_critical = false
		var cr := who as Creature
		# And the shaft pins it where it stands while it's in it.
		pinning = bool(oc.get("pin", false)) and cr != null
		if cr and cr.species.role == "swarm":
			exclude.append((part as CollisionObject3D).get_rid())
			global_position = b
			_orient()
			return
		# In the part it hit (the collision shape itself), riding along with it.
		global_position = hit_pos + velocity.normalized() * BURY_M
		reparent(Arrow._shape_node(ray.collider, ray.shape), true)
		host = cr
		_land(hit_pos)
	elif who:
		# A camp person: they complain, no one's harmed (Hits.strike());
		# only the first touch counts as a hit.
		if not _glanced:
			Hits.strike(ray.collider, ray.shape, damage * clampf(velocity.length() / Spear.MAX_SPEED, 0.4, 1.0), a, hit_pos, camps)
		_glanced = true
		exclude.append((part as CollisionObject3D).get_rid())
		global_position = hit_pos - velocity.normalized() * 0.05
		velocity *= -0.15
		NoiseEvents.emit(hit_pos, NOISE_M * 0.5)
	else:
		_splash_crossing(a, hit_pos)
		global_position = hit_pos + velocity.normalized() * BURY_M
		_land(hit_pos)


## Stuck: at rest, and heard.
func _land(at: Vector3) -> void:
	landed = true
	velocity = Vector3.ZERO
	NoiseEvents.emit(at, NOISE_M)
	_sound(0.75)


## At rest: afloat, it rides the ripples; in a creature, it drops to the
## ground when the carcass fades (or the animal leaves).
func _rest() -> void:
	if afloat:
		global_position = _float_at + world.dir_of(_float_at) * Ripples.height_at(_float_at)
	elif host != null:
		if not is_instance_valid(host) or host.leaving or host.done:
			host = null
			reparent(world.world_root, true)
			_lay_down()
		elif pinning:
			host.pinned_t = maxf(host.pinned_t, 0.1)


## Lying on the ground (or afloat) where it is, along its length.
func _lay_down() -> void:
	var d: Vector3 = world.dir_of(global_position)
	var ground := chunks.ground_height(d)
	var water := chunks.water_level_at(d)
	if water > ground:
		_float(d, water)
		return
	landed = true
	velocity = Vector3.ZERO
	_flatten(d)
	global_position = world.to_scene(d, PlanetConst.RADIUS_M + ground + 0.04)


## Afloat on the water at `d`, lying along its flight.
func _float(d: Vector3, water: float) -> void:
	landed = true
	afloat = true
	_flatten(d)
	_float_at = world.to_scene(d, PlanetConst.RADIUS_M + water + 0.02)
	global_position = _float_at
	velocity = Vector3.ZERO


## Turn it level along the ground at `d`, keeping its heading.
func _flatten(d: Vector3) -> void:
	var f := -global_basis.z
	if velocity.length_squared() > 1e-4:
		f = velocity
	f = f - d * f.dot(d)
	if f.length_squared() < 1e-6:
		f = CubeSphere.north(d)
	global_basis = Basis.looking_at(f.normalized(), d)


## A splash (Ripples) where the flight from `a` to `b` went down through
## the water's surface, if it did (into shallow water onto its bed).
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
	Ripples.splash(world.to_scene(world.dir_of(p), surface), RippleSim.contact("spear_kg"), velocity.length())


func _orient() -> void:
	if velocity.length_squared() < 1e-6:
		return
	var f := velocity.normalized()
	var up: Vector3 = world.dir_of(global_position)
	var hint := up if absf(f.dot(up)) < 0.98 else CubeSphere.north(up)
	global_basis = Basis.looking_at(f, hint)


func _sound(pitch: float) -> void:
	_voice.stream = SoundSynth.stream("arrow_hit", randi())
	_voice.pitch_scale = pitch * randf_range(0.92, 1.08)
	_voice.play()
