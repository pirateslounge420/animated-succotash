class_name Footsteps
extends AudioStreamPlayer
## The player's footsteps: one per stride (shorter crouched, longer
## sprinting), in the sound of what's underfoot, louder the faster you go.
##
## Ground: wading in shallow water; else what the player stands on (ruin
## stone, a tree's roots); else the terrain's own color, read the way the
## terrain shader picks its texture (green: grass, grey: stone, pale grey:
## snow, beach sand, anything else: dirt). Sounds are synthesized
## (SoundSynth "step_<kind>").

const STRIDE_M := {"crouch": 0.5, "walk": 0.78, "sprint": 1.25}
const VOLUME_DB := {"crouch": -21.0, "walk": -11.0, "sprint": -4.0}

## What the last step landed on (grass, dirt, sand, stone, snow, wood,
## water).
var ground := "grass"

var _dist := 0.0
var _count := 0
var _air_s := 0.0


## Per physics frame. `moved` is the distance walked this frame.
func step_update(player: PlanetPlayer, moved: float, on_floor: bool, delta: float) -> void:
	var gait := "crouch" if player.crouching else ("sprint" if player.sprinting else "walk")
	# Brief hops over bumps (running downhill) still count as ground.
	if not on_floor:
		_air_s += delta
		if _air_s > 0.25:
			return
	elif _air_s > 0.25:
		# A landing, after a real jump or fall.
		if not player.climbing:
			_step(player, "sprint")
		_dist = 0.0
	if on_floor:
		_air_s = 0.0
	if player.swimming or player.climbing:
		return
	_dist += moved
	if _dist >= STRIDE_M[gait]:
		_dist = 0.0
		_step(player, gait)


func _step(player: PlanetPlayer, gait: String) -> void:
	ground = material_under(player)
	_count += 1
	stream = SoundSynth.stream("step_" + ground, _count)
	volume_db = VOLUME_DB[gait] + randf_range(-1.5, 1.5)
	pitch_scale = randf_range(0.92, 1.08)
	play()


## What the player is standing on.
static func material_under(player: PlanetPlayer) -> String:
	var d := player.surface_dir
	var chunks := player.chunks
	var ground_h := chunks.ground_height(d)
	var water := chunks.water_level_at(d)
	if water > ground_h + 0.05:
		return "water"
	var from := player.global_position + player.up * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from - player.up * 0.8)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider is CollisionObject3D:
		var body := hit.collider as CollisionObject3D
		if body.collision_layer & TerrainChunk.TREE_LAYER:
			return "wood"
		if body.get_parent() and body.get_parent().has_meta("site"):
			return "stone"
	var chunk := chunks.chunk_at(d)
	if chunk == null:
		return "dirt"
	var map: PlanetData = player.world.planet
	if TerrainChunk.sand_amount(map, d, ground_h) > 0.5:
		return "sand"
	var c := chunk.ground_color_at(d)
	var hi := maxf(c.r, maxf(c.g, c.b))
	var sat := hi - minf(c.r, minf(c.g, c.b))
	if sat < 0.06:
		return "snow" if hi > 0.8 else "stone"
	if c.g - maxf(c.r, c.b) * 0.92 > 0.03:
		return "grass"
	return "dirt"
