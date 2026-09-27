class_name Mythics
extends Node
## The mythic creatures' Phase 1 pieces, before any of them spawns in play
## (creatures start spawning in Phase 7; data "spawn": "disabled"):
##
##   Biome cues. A species with a `biome_lock` and a "cue" entry announces
##   itself when you walk into its biome during its hours (or its hours
##   begin while you're there): the Night Rider's is distant hoofbeats
##   (NightRiderSounds "hoofbeats_far"), a pair walking somewhere off in
##   the forest a few hundred meters away ("distance_m"), in the direction
##   the biome runs deepest, moving across your line of hearing. It's a 3D
##   sound: it comes from that direction, pans as you turn and is muffled
##   by the distance. At most once per "cooldown_s". It reads the biome
##   under the player (the planet blueprint) and the sky's daylight, and
##   spawns nothing.
##
##   Debug spawn (dev mode only, data/dev.json): the shared dev spawn key
##   (F7, DevSpawn) brings a Night Rider pair past you in its turn
##   (NightRiderPair.debug_spawn()), riding across your view about 30 m
##   ahead and then patrolling (and, at night, coming for you: they're
##   aggressive); the pair before is sent away. The pairs it brings live
##   in `pairs`, ticked here. Tools spawn through spawn_night_riders()
##   (tools/night_rider_demo.gd).
##
## Reads World (planet, dev mode), the player's position and noise, the
## sky's daylight; writes only its own nodes (under World.world_root, so
## they move with the floating origin).

## Pairs this far from the player are dropped.
const DROP_M := 700.0

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var sky: SkySystem
var spawner: CreatureSpawner
var pairs: Array[NightRiderPair] = []

var _root: Node3D
var _cues: Array = [] # {"species", "inside", "next_ok"}
var _cue_voice: AudioStreamPlayer3D
var _cue_dir := Vector3.ZERO
var _cue_move := Vector3.ZERO
var _cue_left := 0.0
var _check_t := 0.0
var _time := 0.0


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer, p_sky: SkySystem, p_spawner: CreatureSpawner) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	sky = p_sky
	spawner = p_spawner
	_root = Node3D.new()
	_root.name = "Mythics"
	world.world_root.add_child(_root)
	for sp in CreatureSpecies.all():
		if not sp.biome_lock.is_empty() and sp.data.get("cue") is Dictionary:
			_cues.append({"species": sp, "inside": false, "next_ok": 0.0})
			# The cue takes a few seconds to synthesize: on a worker, now.
			NightRiderSounds.prewarm(str((sp.data.cue as Dictionary).get("sound", "hoofbeats_far")))
	_cue_voice = AudioStreamPlayer3D.new()
	_cue_voice.name = "BiomeCue"
	# Falloff and distance muffling: the table's "hoofbeats_far" (Audio3D).
	Audio3D.apply(_cue_voice, "hoofbeats_far")
	_cue_voice.volume_db = 3.0
	_root.add_child(_cue_voice)
	# Dev mode: the body mesh builds now on a worker, so F7 doesn't wait.
	var rider := CreatureSpecies.find("Night rider")
	if world.dev_mode and rider:
		NightRiderBody.prewarm(rider)


func _exit_tree() -> void:
	NightRiderBody.finish()
	NightRiderSounds.finish()


func _process(delta: float) -> void:
	if player == null:
		return
	_time += delta
	_update_cues(delta)
	if pairs.is_empty():
		return
	var ctx := {"player_dir": player.surface_dir, "player_noise": player.noise_level,
		"player_still": player.still_time, "daylight": sky.daylight if sky else 0.0}
	for pair in pairs.duplicate():
		pair.tick(delta, ctx)
		var far := true
		for r in pair.riders:
			far = far and r.distance_to(player.surface_dir) > DROP_M
		if pair.done or far:
			pair.free_now()
			pairs.erase(pair)


# --- Biome cues ----------------------------------------------------------------

func _update_cues(delta: float) -> void:
	_check_t -= delta
	if _check_t <= 0.0 and not _cues.is_empty():
		_check_t = 0.5
		var map: PlanetData = world.planet
		var biome := map.biome[map.cell_at(player.surface_dir)]
		var daylight := sky.daylight if sky else 1.0
		for c in _cues:
			var sp: CreatureSpecies = c.species
			var now_in := sp.biome_ok(biome) and sp.active_now(daylight)
			if now_in and not c.inside and _time >= float(c.next_ok):
				play_cue(sp)
				c.next_ok = _time + float((sp.data.cue as Dictionary).get("cooldown_s", 300.0))
			c.inside = now_in
	if _cue_left > 0.0:
		_cue_left -= delta
		# They're walking: the sound moves across at their pace.
		_cue_dir = (_cue_dir + _cue_move * 1.1 * delta / PlanetConst.RADIUS_M).normalized()
		_cue_voice.global_position = world.to_scene(_cue_dir, PlanetConst.RADIUS_M + chunks.ground_height(_cue_dir) + 1.2)


## Play a species' cue now: off in the direction its biome runs deepest
## from the player, "distance_m" away, moving across.
func play_cue(sp: CreatureSpecies) -> void:
	var cue: Dictionary = sp.data.cue
	var pd := player.surface_dir
	var map: PlanetData = world.planet
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map.cell_at(pd), int(_time)])
	var a0 := rng.randf() * TAU
	var best := -1
	var best_a := a0
	for k in 12:
		var a := a0 + k * TAU / 12.0
		var score := 0
		for m: float in [150.0, 300.0, 450.0, 600.0]:
			var c := map.cell_at(CreatureSpawner._offset(pd, a, m))
			if sp.biome_ok(map.biome[c]) and map.water[c] == PlanetData.Water.NONE:
				score += 1
		if score > best:
			best = score
			best_a = a
	var span: Array = cue.get("distance_m", [280, 420])
	_cue_dir = CreatureSpawner._offset(pd, best_a, rng.randf_range(float(span[0]), float(span[1])))
	var across := best_a + PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0)
	_cue_move = CubeSphere.north(_cue_dir) * cos(across) + CubeSphere.east(_cue_dir) * sin(across)
	_cue_voice.stream = NightRiderSounds.stream(str(cue.get("sound", "hoofbeats_far")), rng.randi())
	if _cue_voice.stream == null:
		return
	_cue_left = _cue_voice.stream.get_length()
	_cue_voice.global_position = world.to_scene(_cue_dir, PlanetConst.RADIUS_M + chunks.ground_height(_cue_dir) + 1.2)
	Audio3D.play(_cue_voice)


## The cue's source right now (scene position), or null when silent.
func cue_position() -> Variant:
	return _cue_voice.global_position if _cue_left > 0.0 else null


# --- Spawning (debug and tools) ---------------------------------------------------

## A Night Rider pair at surface direction `d`, riding along `heading`
## (the follower on the line behind). `route`: waypoints to walk first
## (then they patrol); `walking` > 0: already walking at that speed.
## Waits for the body mesh if it isn't built yet.
func spawn_night_riders(d: Vector3, heading: Vector3, route := [], walking := 0.0, aggressive := true) -> NightRiderPair:
	var sp := CreatureSpecies.find("Night rider")
	if sp == null:
		return null
	NightRiderBody.wait_ready(sp)
	var pair := NightRiderPair.spawn(sp, world, chunks, spawner, _root, d, heading, hash(d) & 0x7fffffff, walking)
	pair.aggressive = aggressive
	if not route.is_empty():
		pair.route = route.duplicate()
		pair.state = "route"
	pairs.append(pair)
	return pair

