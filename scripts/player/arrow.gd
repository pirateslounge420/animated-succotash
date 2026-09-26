class_name Arrow
extends Node3D
## An arrow in flight (Bow): falls under the planet's gravity, points
## along its path, and on the first thing it meets:
##   * a creature (CreatureSpawner.creature_on_segment): hurts it and
##     sticks in it, riding along;
##   * camp folk (Camps.folk_on_segment): a glancing shot they complain
##     about, and it drops;
##   * ground, trees, ruins (physics): buries its head there and stays a
##     while;
##   * water: sinks.
## Lives under World.world_root, so it moves with the floating origin.

const GRAVITY := 9.8
const STUCK_S := 60.0
const MAX_FLIGHT_S := 12.0

var world: Node
var chunks: ChunkManager
var spawner: CreatureSpawner
var camps: Camps
var velocity := Vector3.ZERO
var damage := 10.0
var exclude: Array[RID] = []

var _stuck := false
var _life := 0.0
var _voice: AudioStreamPlayer3D


func launch(from: Vector3, vel: Vector3) -> void:
	add_child(BowMesh.arrow())
	global_position = from
	velocity = vel
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 6.0
	_voice.max_distance = 60.0
	add_child(_voice)
	_orient()


func _physics_process(delta: float) -> void:
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
	# The nearest of: a creature, camp folk, the world.
	var hit_t := INF
	var hit_kind := ""
	var hit_obj = null
	var hit_pos := b
	var hit_normal := up
	if spawner:
		var c: Array = spawner.creature_on_segment(a, b)
		if not c.is_empty():
			hit_t = c[1]
			hit_kind = "creature"
			hit_obj = c[0]
	if camps:
		var f: Array = camps.folk_on_segment(a, b)
		if not f.is_empty() and f[1] < hit_t:
			hit_t = f[1]
			hit_kind = "folk"
			hit_obj = f[0]
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = exclude
	var ray := get_world_3d().direct_space_state.intersect_ray(q)
	if not ray.is_empty():
		var t := a.distance_to(ray.position) / maxf(a.distance_to(b), 1e-6)
		if t < hit_t:
			hit_t = t
			hit_kind = "world"
			hit_pos = ray.position
			hit_normal = ray.normal
	if hit_kind == "":
		# Water: sinks where it meets the surface.
		var d: Vector3 = world.dir_of(b)
		var water := chunks.water_level_at(d)
		if water > chunks.ground_height(d) and world.radius_of(b) < PlanetConst.RADIUS_M + water:
			global_position = b
			_stick()
			_life = STUCK_S - 3.0
			return
		global_position = b
		_orient()
		return
	match hit_kind:
		"creature":
			var cr := hit_obj as Creature
			global_position = a.lerp(b, hit_t)
			cr.hurt(damage * clampf(velocity.length() / Bow.MAX_SPEED, 0.4, 1.0), a)
			_sound("arrow_hit")
			reparent(cr, true)
			_stick()
		"folk":
			camps.shot_at(hit_obj)
			velocity *= -0.15
			global_position = a.lerp(b, hit_t)
		"world":
			# Bury the head a little along the flight.
			global_position = hit_pos + velocity.normalized() * 0.12
			_sound("arrow_hit")
			_stick()


func _stick() -> void:
	_stuck = true
	velocity = Vector3.ZERO


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
